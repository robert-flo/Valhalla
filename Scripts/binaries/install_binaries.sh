#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/restore_binaries.psv"
SOURCE_DIR="${SCRIPT_DIR}/../../Configs_RaVN/.local/bin"
DESTINATION="${HOME}/.local/bin"

load_manifest() {
  local flag=""
  local _destination=""
  local artifact=""
  local owner=""

  while IFS='|' read -r flag _destination artifact owner || [[ -n $flag ]]; do
    [[ $flag == P && $owner == ravn-binary && -n $artifact ]] || continue
    printf '%s\n' "$artifact"
  done < "$MANIFEST"
}

mkdir -p "$DESTINATION"
while IFS= read -r artifact; do
  source="${SOURCE_DIR}/${artifact}"
  if [[ ! -f $source ]]; then
    echo "[binaries] error: declared binary not found: $artifact" >&2
    exit 1
  fi
  cp -p -- "$source" "${DESTINATION}/${artifact}"
done < <(load_manifest)

echo "[binaries] installed declared RaVN binaries"
