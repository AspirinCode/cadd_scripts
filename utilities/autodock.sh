#!/usr/bin/env bash

# 判断文件存在
function existsfile {
  local file comment
  file=$1
  if [ -z $2 ]; then
    comment=$1
  else
    comment=$2
  fi
  
  [ -f $file ] || {
  echo "当前路径中的 txt 文件：$(ls *.txt)"
    while read -p "${file} 不存在，请输入${comment}文件路径：" file; do
      [ -f $file ] && break
    done
  }
  echo $file
}

# 获得列表文件里的所有文件
function getlist {
  local file list
  list=$1
  list=$(cat $list | tr -d '\r' | sed 's/^[[:blank:]]*//' | grep '^[^#]')
  for file in $list; do 
    [ -f $file ] || { echo "$file 文件不存在，请修改配置文件并重新运行脚本。"; return 1; }
  done
  echo $list  
}

# autogrid4 glg 完整性验证
function verifyglg {
  local file
  file=$1
  status=$(tail -n 2 $file | head -n 1 | awk '{print $2}')
  echo $status
}
# 获得 atomtypes
function getatoms {
  echo $(grep -E 'ATOM|HETATM' $1 | tr -d '\r' | awk '{atoms[$NF]} END{for (atom in atoms) {print atom;}}')
}

# 处理盒子文件
# 1 原盒子路径 2 受体路径 3 配体 atomtypes
function parsebox {
  local content line key value
  recatoms=$(getatoms $2)
  cat $1 | sed 's/^[[:blank:]]*//' | sed 's/^[[:blank:]]*//' | grep '^[^#]'  | while read line; do
    line=${line%%\#*}
    key=$(echo $line | awk '{print $1}')
    [ "$key" == "map" ] &&  continue
    value=$(echo $line | awk '{for (i=2;i<=NF;i++) {printf " %s", $i}}')
    [ "$key" == "receptor" ] && value=$2
    [ "$key" == "receptor_types" ] && value=$recatoms
    [ "$key" == "ligand_types" ] && value=$3
    echo "${key} ${value}"
  done
  echo "$recatoms $3" | awk '{for (i=1;i<=NF;i++) {atoms[$i]}} END{for (atom in atoms) {print atom}}' | while read line; do
    echo "map atom.${line}.map"
  done
}

# 准备
recfile=$(existsfile receptors.txt "受体列表文件")
ligfile=$(existsfile ligands.txt "配体列表文件")
reclist=$(getlist $recfile) || { echo $reclist; exit 1; }
liglist=$(getlist $ligfile) || { echo $liglist; exit 1; }

# 确认盒子存在
for file in $reclist; do
  box=${file%.*}".gpf"
  [ -f $box ] || { echo "[盒子]受体 ${file} 的盒子 ${box} 不存在，脚本退出。"; exit 2; }
done
unset file box

# 准备确认
echo "[受体]要进行对接的受体文件："
for file in $reclist; do
  echo "- ${file}"
done
unset file
echo "[配体]要进行对接的配体文件："
for file in $liglist; do
  echo "- ${file}"
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

# 获得所有配体 atomtype 列表
ligatoms=$(getatoms $liglist)
echo $ligatoms

# autogrid
for rec in $reclist; do
  # 不含后缀的文件名
  basename=`basename $rec .pdbqt`
  # 文件路径+不含后缀的文件名
  basepath=${rec%\.*}
  # 盒子路径
  boxfile="${basepath}.gpf"
  # 工作路径
  dest=${basepath//[\/\\]/_}
  dest="${workdir}/${dest}"
  mkdir -p $dest
  
  if [ -f "${dest}/box.glg" ] && [ "$(verifyglg ${dest}/box.glg)" == "Successful" ]; then
    echo "${basepath} 的 autogrid 工作已完成，不再重复进行。"
  else
    # 处理盒子文件
    echo $dest
    parsebox $boxfile $rec "$ligatoms" > ${dest}/box.gpf
        
  fi
  
done
