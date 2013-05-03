#!/usr/bin/env bash

########## Functions #############

# 获取绝对路径
function abs {
  local dir filename
  # 绝对路径
  [ "$(echo $1 | cut -c 1)" == "/" ] && { echo $1; exit; }
  # 相对路径
  [ -n $2 ] && cd "$2"
  dir=$(dirname "$1")
  filename=$(basename "$1")
  echo $(cd "$dir"; echo "$(pwd)/$filename")
}
# 获取相对路径
function relative {
  local file filepath
  file="$1"
  filepath=$(abs "$2")
  filepath=${filepath%\/*}
  echo ${file#"$filepath"} | cut -c 2-
}

#
function parsepath {
  local str
  str="$1"
  str=${str// /\\ }
  str=${str//\[/\\\[}
  str=${str//\]/\\\]}
  str=${str//\{/\\\{}
  str=${str//\}/\\\}}
  str=${str//\(/\\\(}
  str=${str//\)/\\\)}
  echo $str
}
    
# 判断文件存在
function existsfile {
  local file comment
  file=$1
  if [ -z $2 ]; then
    comment=$1
  else
    comment=$2
  fi
  
  [ -f "$file" ] || {
  echo "当前路径中的 txt 文件：$(ls *.txt)"
    while read -p "${file} 不存在，请输入${comment}文件路径：" file; do
      [ -f "$file" ] && break
    done
  }
  echo $file
}

# 获得列表文件里的所有文件
function getlist {
  local file blob
  current=$(pwd)
  listpath=$(dirname "$1")
  listfile=$(basename "$1")
  cd "$listpath"
  cat "$listfile" | sed 's/^[[:blank:]]*//' | grep '^[^#]' | \
  while read blob; do 
    eval ls $(parsepath "$blob") | while read file; do
      [ -f "$file" ] || { echo "$file 文件不存在，请修改配置文件并重新运行脚本。"; cd "$current"; return 1; }
      echo $(abs "$file")
    done
  done
  cd "$current"
}

# autogrid4 glg 完整性验证
function verifyglg {
  echo $(tail -n 2 "$1" | head -n 1 | awk '{print $2}')
}

# autodock4 dlg 完整性验证
function verifydlg {
  echo $(tail -n 5 "$1" | head -n 1 | awk '{print $2}')
}

# dlg 完成时间
function finishtime {
  echo $(tail -n 10 "$1" | head -n 1 | cut -f4- )
}

# 获得 atomtypes
function getatoms {
  local allatoms
  allatoms=$(echo "$1" | while read file; do { cat "$file" | grep -E 'ATOM|HETATM' | tr -d '\r'; } done)
  echo "$allatoms" | awk '{atoms[$NF]} END{for (atom in atoms) {print atom;}}'
}

# 处理盒子文件
# 1 原盒子路径 2 受体路径 3 配体 atomtypes
function parsebox {
  local rec recatoms line key value
  rec=$(basename "$2" ".pdbqt")
  recatoms=$(getatoms "$2")
  cat "$1" | sed 's/^[[:blank:]]*//' | sed 's/^[[:blank:]]*//' | grep '^[^#]' | \
  while read line; do
    line=${line%%\#*}
    key=$(echo $line | awk '{print $1}')
    [ "$key" == "map" ] &&  continue
    value=$(echo $line | awk '{for (i=2;i<=NF;i++) {printf " %s", $i}}')
    [ "$key" == "gridfld" ] && value="${rec}.maps.fld"
    [ "$key" == "receptor" ] && value="${rec}.pdbqt"
    [ "$key" == "receptor_types" ] && value=$(echo $recatoms)
    [ "$key" == "ligand_types" ] && value=$(echo $3)
    [ "$key" == "elecmap" ] && value="${rec}.e.map"
    [ "$key" == "dsolvmap" ] && value="${rec}.d.map"
    echo "${key} ${value}"
  done
#  echo "$recatoms $3" | awk '{for (i=1;i<=NF;i++) {atoms[$i]}} END{for (atom in atoms) {print atom}}' | while read line; do
  for line in $3; do
    echo "map ${rec}.${line}.map"
  done
}

############## Functions End ################

############## Works ########################

# 读取配置文件

. settings.txt

# 准备
[ -x "${MGLHOME}/bin/pythonsh" ] || { echo "${MGLHOME}/bin/pythonsh 不存在或不可执行，请确认 MGLHOME 值是否设置正确。"; exit; }
[ -z $pop_size ] && pop_size=150
[ -z $num_evals ] && num_evals=2500000
[ -z $num_run ] && num_run=100
[ -z $rec_list ] && rec_list="receptors.txt"
[ -z $lig_list ] && lig_list="ligands.txt"
recfile=$(existsfile "$rec_list" "受体列表文件")
ligfile=$(existsfile "$lig_list" "配体列表文件")
unset rec_list lig_list
reclist=$(getlist $recfile) || { echo $reclist; exit 1; }
liglist=$(getlist $ligfile) || { echo $liglist; exit 1; }

# 确认盒子存在
echo "$reclist" | while read file; do
  box=${file%.*}".gpf"
  [ -f "$box" ] || { echo "[盒子]受体 ${file} 的盒子 ${box} 不存在，脚本退出。"; exit 2; }
done
unset file box

# 准备确认
echo "[受体]要进行对接的受体文件："
echo "$reclist" | while read file; do
  echo "- "$(relative "$file" "$recfile")
done
unset file
echo "[配体]要进行对接的配体文件："
echo "$liglist" | while read file; do
  echo "- "$(relative "$file" "$ligfile")
done
unset file

while read -p "请确认文件列表是否正确[y/n]：" confirm; do
  [ "$confirm" == "n" ] && { echo "脚本退出。"; exit 4; }
  [ "$confirm" == "y" ] && break
done
unset confirm

# 设定工作目录
echo "当前路径所有文件夹："$(ls -l | grep '^d' | awk '{printf $NF" " }' )
echo "请指定一个工作目录，所有的对接操作产生的文件及结果文件会在这个文件夹中生成。"
echo "如果是新的对接操作，指定一个新的文件夹；如果要继续以前的对接工作，指定原来的工作文件夹。"

while read -p "指定工作目录：" workdir; do
  [ -f $workdir ] && { echo "这是一个已存在的文件，请指定一个不存在或存在的文件夹（而不是文件）。"; continue; }
  if [ -d $workdir ]; then
    echo "$workdir 是一个已存在的文件夹，指定该文件夹代表你要继续以前的对接工作。"
    while read -p "请确认是否要继续 $workdir 的对接工作[y/n]：" confirm; do
      [ "$confirm" == "n" ] || [ "$confirm" == "y" ] && break
    done
    [ "$confirm" == "n" ] && continue
    unset confirm
  else
    mkdir $workdir
  fi
  break
done
workdir=$(abs "$workdir")
workdir=${workdir%[\/\\]}

# 获得所有配体 atomtype 列表
ligatoms=$(getatoms "$liglist")
# 当前目录
current=$(pwd)

# 开始工作
echo "$reclist" | while read rec; do
  # 不含后缀的文件名
  basename=`basename $rec .pdbqt`
  # 文件路径+不含后缀的文件名
  basepath=${rec%\.*}
  # 盒子路径
  boxfile="${basepath}.gpf"
  # 工作路径
  dest=$(relative "$basepath" "$recfile")
  dest=${dest//[\/\\]/_}
  dest="${workdir}/${dest}"
  mkdir -p "$dest"
  cd "$dest"
  cp -f "$rec" ./
  
  # autogrid4
  if [ -f "${dest}/box.glg" ] && [ "$(verifyglg ${dest}/box.glg)" == "Successful" ]; then
    echo "${basepath} 的 autogrid 工作已完成，不再重复进行。"
  else
    echo "[处理盒子]${dest}"
    parsebox "$boxfile" "$rec" "$ligatoms" > "${dest}/box.gpf"
    autogrid4 -p "${dest}/box.gpf" -l "${dest}/box.glg"
    glgstatus=$(verifyglg "${dest}/box.glg")
    [ "$glgstatus" == "Successful" ] && echo "处理成功。" || echo "盒子处理貌似失败了，请检查 ${dest}/box.glg "
  fi

  # prepare dpf & autodock4
  echo "$liglist" | while read lig; do
    filename=$(basename "$lig" ".pdbqt")_$(basename "$rec" ".pdbqt")
    if [ -f "${filename}.dlg" ] && [ "$(verifydlg ${filename}.dlg)" == "Successful" ]; then
      echo "该分子对接已完成于 $(finishtime "${filename}.dlg") ，将不再重复进行对接。"
    else
      echo "生成 ${filename}.dpf 中"
      cp -f "$lig" ./
      $MGLHOME/bin/pythonsh $MGLHOME/MGLToolsPckgs/AutoDockTools/Utilities24/prepare_dpf4.py -l "$lig" -r "$rec" -p ga_pop_size=$pop_size -p ga_num_evals=$num_evals -p ga_run=$num_run > /dev/null
      echo "${filename}.dpf 已生成，开始对接。"
      autodock4 -p "${filename}.dpf" -l "${filename}.dlg"
    fi
    
  done

  cd "$current"
done


############ Works End #################

