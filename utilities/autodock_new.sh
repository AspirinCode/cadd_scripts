#!/usr/bin/env bash

#------------------ Functions -----------------------#

#______________________ Bug Me ______________________

function contactMe {
  echo "Any problem? BUG me plz. Qichao Yang <imkafei[AT]gmail.com>."
  return 2
}

#______________________ Extract Paths ______________________

function blob {
  local file
  file="$1"
  file="\"${file}\""
  file="${file//\*/\"*\"}"
  file="${file//\?/\"?\"}"
  eval ls "$file"
}

#______________________ Get Extension ______________________

function getExt {
  echo ${1##*.}
}

#______________________ Replace Blank ______________________

function noBlank {
  echo ${1//[[:blank:]]/_}
}

#______________________ File List ______________________

function getFileList {
  local tmp content line
  content=$(< "$1")
  echo "$content" | while read line; do
    tmp=$(blob "$line")
    echo "$tmp"
  done
}

#______________________ List File ______________________

function checkRecLigListFile {
  local list_path
  # 1=Option Value, 2=Option, 3=Setting File
  [ -z "$1" ] && {
    echo "Error. Plz set \`$2' in $3."
    return 1
  }
  [ -f "$1" ] || {
    echo "Error. $2 file \`$1' doesn't exist."
    return 1
  }
  list_path=$(dirname "$1")
  [ "$list_path" = "." ] || {
    echo "Error. \`"$(basename "$1")"' and \`"$(basename "$3")"' must be in the same directory."
    return 1
  }
}

#______________________ Get Atom Types ______________________

function getAtomTypes {
  local atom_types
  atom_types=$(cat "$1" | grep -E 'ATOM|HETATM' | tr -d '\r')
  echo "$atom_types" | awk '{atoms[$NF]} END{for (atom in atoms) {print atom;}}'
}

#______________________ Parse Box ______________________

# 1 原盒子路径 2 受体名 3 配体 atomtypes 4 受体 atomtypes
function parseBox {
  local atom key value line
  cat "$1" | sed '/^$/d' | cut -d '#' -f 1 |
  while read line; do
    key=$(echo "$line" | awk '{printf "%s", $1}')
    [ "$key" == "map" ] &&  continue
    value=$(echo "$line" | awk '{for (i=2;i<=NF;i++) {printf " %s", $i}}')
    [ "$key" == "gridfld" ] && value="${2}.maps.fld"
    [ "$key" == "receptor" ] && value="${2}.pdbqt"
    [ "$key" == "receptor_types" ] && value=$(echo $4)
    [ "$key" == "ligand_types" ] && value=$(echo $3)
    [ "$key" == "elecmap" ] && value="${2}.e.map"
    [ "$key" == "dsolvmap" ] && value="${2}.d.map"
    echo "${key} ${value}"
  done
  for atom in $3; do
    echo "map ${2}.${atom}.map"
  done
}

#______________________ Find Successful ______________________

function findSuccessful {
  local line
  line=$(tail -n 10 "$1" | grep "Successful Completion")
  if [ "$line" = "" ]; then
    echo "false"
  else
    echo "true"
  fi
}

#------------------ Main -----------------------#

#____________________ Load Global Settings ______________________

GLOBALSETTING="global.txt"

[ -f "$GLOBALSETTING" ] && source $GLOBALSETTING

[ -z "${MGLHOME}" ] && {
  echo "Error. Is AutoDock Tools installed? Plz set MGLHOME in ${GLOBALSETTING}."
  exit 1
}

[ -f "${MGLHOME}/bin/pythonsh" ] || {
  echo "Error. ${MGLHOME}/bin/pythonsh doesn't exist."
  exit 1
}

PYTHON="${MGLHOME}/bin/pythonsh"
MGLUTIL="${MGLHOME}/MGLToolsPckgs/AutoDockTools/Utilities24"

#______________________ Load Personal Settings ______________________

[ -z "$1" ] && {
  echo "Error. 1 argument is supposed and 0 is given. Plz assign a personal setting file."
  exit 1
}

[ -f "$1" ] || {
  echo "Error. $1 doesn't exist."
  exit 1
}

source "$1"

CURRENTDIR=$(pwd)
WORKDIR=$(dirname "$1")

cd "$WORKDIR"
WORKDIR=$(pwd)

pop_size=${pop_size:-150}
num_evals=${num_evals:-2500000}
num_run=${num_run:-100}

checkRecLigListFile "$rec_list" "rec_list" "$1" || exit 1
checkRecLigListFile "$lig_list" "lig_list" "$1" || exit 1

[ -z "$target" ] && {
  echo "Error. Plz set \`target' in $1."
  exit 1
}

cd "$CURRENTDIR"

#______________________ Get Receptor & Ligand List ______________________

cd "$WORKDIR"
rec_files=$(getFileList "$rec_list")
rec_num=$(echo "$rec_files" | sed '/^$/d' | wc -l)
lig_files=$(getFileList "$lig_list")
lig_num=$(echo "$lig_files" | sed '/^$/d' | wc -l)

#______________________ Confirm ______________________

echo "####################### Receptor list ########################"
echo "$rec_files" | while read line; do
  [ ! "$line" = "" ] && echo "# - $line"
done
echo "####################### Ligand list ########################"
echo "$lig_files" | while read line; do
  [ ! "$line" = "" ] && echo "# - $line"
done
echo "####################### Total ########################"
echo "# Receptor(s):  $rec_num"
echo "# Ligand(s):    $lig_num"
echo "####################### Options ########################"
echo "# AutoDock Tools Path:      $MGLHOME"
echo "# Population Size:          $pop_size"
echo "# Maximum Number of evals:  $num_evals"
echo "# Number of GA Runs:        $num_run"
echo "# Directory to Output:      $target"
[ -d "$target" ] && echo "# * * * Caution: Directory \`${target}' exists already. * * *"
echo "####################### Confirm ########################"
while read -p "# Confirm? [yes/no]: " confirm; do
  [ "$confirm" = "no" ] && { echo "Aborted by user."; exit; }
  [ "$confirm" = "yes" ] && break
done

#______________________ Start Work ______________________

ALLDONE=1

cd "$WORKDIR"
mkdir -p "$target"
mkdir -p "${target}/dict"
mkdir -p "${target}/ligands"
mkdir -p "${target}/receptors"
mkdir -p "${target}/docking"
mkdir -p "${target}/docked"
mkdir -p "${target}/lock"

echo "$lig_files" | while read lig; do
  lig_name_orig=$(basename "$lig")
  lig_name=$(noBlank "$lig_name_orig")
  lig_ext=$(getExt "$lig_name")
  lig_basename=$(basename "$lig_name" ".${lig_ext}")

  # skip locked ligand
  [ -f "${target}/lock/${lig_basename}.lock" ] && {
    echo "Skip ${lig_name_orig}. ( ${target}/lock/${lig_basename}.lock exists )"
    continue
  }

  # prepare ligand
  [ -f "${target}/dict/dict${lig_basename}.py" ] && [ -f "${target}/ligands/${lig_basename}.pdbqt" ] || {
    if [ "$lig_ext" = "pdbqt" ]; then
      "cp" "-f" "$lig" "${target}/ligands/${lig_basename}.pdbqt"
      "sh" "$PYTHON" "${MGLUTIL}/prepare_ligand_dict.py" "-l" "$lig" "-d" "${target}/dict/dict${lig_basename}.py"
    else
      "sh" "$PYTHON" "${MGLUTIL}/prepare_ligand4.py" "-l" "$lig" "-o" "${target}/ligands/${lig_basename}.pdbqt" "-d" "${target}/dict/dict${lig_basename}.py" "-A" "hydrogens"
    fi
  }

  # check ligand (torsion and atom)
  cd "${target}/dict"
  lig_info=$("python" "-c" "from dict${lig_basename} import summary; k = summary['${lig_basename}']; print '%d' % k['rbonds']; print '\n'.join(k['atom_types'])")
  cd "${WORKDIR}"

  lig_torsion=$(echo "$lig_info" | head -n 1)
  lig_atom_number=$(echo "$lig_info" | sed '/^$/d' | wc -l)
  lig_atom_number=$(expr ${lig_atom_number} - 1)
  lig_atom_types=$(echo "$lig_info" | tail -n ${lig_atom_number})
  
  # skip ligand who has too much torsions
  [ ${lig_torsion} -gt 32 ] && {
    echo "Skip. Torsions number of ${lig_name_orig} is larger than 32. ( $lig_torsion now )"
    touch "${target}/lock/${lig_basename}.lock"
    continue
  }

  # skip ligand who has too much atom_types
  [ ${lig_atom_number} -gt 14 ] && {
    echo "Skip. Atom_types number of ${lig_name_orig} is larger than 14. ( $lig_atom_number now )"
    touch "${target}/lock/${lig_basename}.lock"
    continue
  }

  # Receptor and dock
  echo "$rec_files" | while read rec; do
    rec_name_orig=$(basename "$rec")
    rec_name=$(noBlank "$rec_name_orig")
    rec_ext=$(getExt "$rec_name")
    rec_basename=$(basename "$rec_name" ".${rec_ext}")
    box="${rec%.*}.gpf"

    dock_basename="${lig_basename}--____--${rec_basename}"

    # skip locked dock
    [ -f "${target}/lock/${dock_basename}.lock" ] && {
      echo "Skip dock of ${lig_name_orig} and ${rec_name_orig}. ( ${target}/lock/${dock_basename}.lock exists )"
      continue
    }

    ALLDONE=0

    [ -f "${target}/lock/${dock_basename}.docking" ] && {
      PID=$(ps aux | grep "${dock_basename}.command" | grep -v grep | awk '{print $2}')
      [ "$PID" = "" ] || { echo "Skip. ${lig_name_orig} and ${rec_name_orig} is docking."; continue; }
    }

    # prepare receptor
    [ -f "${target}/receptors/${rec_basename}.pdbqt" ] || {
      if [ "$rec_ext" = "pdbqt" ]; then
        "cp" "-f" "$rec" "${target}/receptors/${rec_basename}.pdbqt"
      else
        "sh" "$PYTHON" "$MGLUTIL/prepare_receptor4.py" "-r" "$rec" "-o" "${target}/receptors/${rec_basename}.pdbqt" "-A" "checkhydrogens"
      fi
    }
    rec_atom_types=$(getAtomTypes "$rec")

    # Prepare Docking
    mkdir -p "${target}/docking/${dock_basename}"
    "cp" "-f" "${target}/ligands/${lig_basename}.pdbqt" "${target}/receptors/${rec_basename}.pdbqt" "${target}/docking/${dock_basename}/"

    "parseBox" "$box" "$rec_basename" "$lig_atom_types" "$rec_atom_types" > "${target}/docking/${dock_basename}/${dock_basename}.gpf"
    cd "${target}/docking/${dock_basename}"
    
    [ -f "${dock_basename}.dlg" ] && ISSUCCESS=$(findSuccessful "${dock_basename}.dlg")
    [ "$ISSUCCESS" = "true" ] || {
      echo "" > "${dock_basename}.command"
      echo "sh" "'$PYTHON'" "'$MGLUTIL/prepare_dpf4.py'" "-l" "'${lig_basename}.pdbqt'" "-r" "'${rec_basename}.pdbqt'" "-o" "'${dock_basename}.dpf'" "-p" "'ga_pop_size=$pop_size'" "-p" "'ga_num_evals=$num_evals'" "-p" "'ga_run=$num_run'" >> "${dock_basename}.command"
      if [ "$(uname -s)" = "Darwin" ]; then
        echo "sed" "-i" "''" "'s/[[:blank:]]*#.*$//'" "\"${dock_basename}.dpf\"" >> "${dock_basename}.command"
      else
        echo "sed" "-i''" "'s/[[:blank:]]*#.*$//'" "\"${dock_basename}.dpf\"" >> "${dock_basename}.command"
      fi
      echo "autogrid4" "-p" "'${dock_basename}.gpf'" "-l" "'${dock_basename}.glg'" >> "${dock_basename}.command"
      echo "autodock4" "-p" "'${dock_basename}.dpf'" "-l" "'${dock_basename}.dlg'" >> "${dock_basename}.command"
      cd "${WORKDIR}"

      # Start Docking!!!!
      echo "####################### Dock ${lig_name_orig} and ${rec_name_orig} ########################"
      touch "${target}/lock/${dock_basename}.docking"
      cd "${target}/docking/${dock_basename}"
      "sh" "${dock_basename}.command"
    }

    # Dock stop
    ISSUCCESS="false" # reset ISSUCCESS
    [ -f "${dock_basename}.dlg" ] && ISSUCCESS=$(findSuccessful "${dock_basename}.dlg")
    cd "$WORKDIR"
    [ "$ISSUCCESS" = "true" ] && {
      cp -f "${target}/docking/${dock_basename}/${dock_basename}.dlg" "${target}/docked/"
      touch "${target}/lock/${dock_basename}.lock"
    }
    rm -f "${target}/lock/${dock_basename}.docking"
    [ ! "${dock_basename}" = "" ] && rm -rf "${target}/docking/${dock_basename}"

    cd "${WORKDIR}"
  done

done

#______________________ Hello World! ______________________

[ "$ALLDONE" -eq 1 ] && {
  cd "${target}/docked"
  ln -sf "${CURRENTDIR}/result.py" "result.py"
  "sh" "$PYTHON" "result.py"
}
exit 0
