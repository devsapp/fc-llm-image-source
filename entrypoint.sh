#!/bin/bash


set -Eeuo pipefail

function mount_file() {
  echo Mount $1 to $2

  SRC="$1"
  DST="$2"

  rm -rf "${DST}"

  if [ ! -f "${SRC}" ]; then 
    mkdir -pv "${SRC}"
  fi

  mkdir -pv "$(dirname "${DST}")"
  
  ln -sT "${SRC}" "${DST}"
}


NAS_DIR="/mnt/auto/llm"

# 内置模型准备
# 如果挂载了 NAS，软链接到 NAS 中
# 如果未挂载 NAS，则尝试直接将内置模型过载
NAS_MOUNTED=0
if [ -d "/mnt/auto" ]; then
  NAS_MOUNTED=1
fi

if [ "$NAS_MOUNTED" == "0" ]; then
  echo "without NAS, mount $LLM_BUILTIN to ${NAS_DIR}"
  mount_file "$LLM_BUILTIN" "${NAS_DIR}"
else
  mkdir -p "${NAS_DIR}"

  echo "with NAS, mount built-in files to ${NAS_DIR}"
  
  find ${LLM_BUILTIN} | while read -r file; do
    SRC="${file}"
    DST="${NAS_DIR}/${file#$LLM_BUILTIN/}"

    if [ ! -e "$DST" ] && [ ! -d "$SRC" ]; then
      mount_file "$SRC" "$DST"
    fi
  done


 
fi




declare -A MOUNTS


MOUNTS["${ROOT}/models"]="${NAS_DIR}/models"
MOUNTS["${ROOT}/app"]="${NAS_DIR}/app"



for to_path in "${!MOUNTS[@]}"; do
  mount_file "${MOUNTS[${to_path}]}" "${to_path}"
done

if [ -f "/mnt/auto/llm/startup.sh" ]; then
  pushd ${ROOT}
  . /mnt/auto/llm/startup.sh
  popd
fi
ENTRY_FILE="${ENTRY_FILE:-app/main.py}"


python3 ${ENTRY_FILE}