#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:-${SCRIPT_DIR}/restore_binaries.psv}"
SOURCE_ROOT="${2:-${SCRIPT_DIR}/../../Configs_RaVN}"

resolve_path() {
  printf '%s\n' "${1//\$\{HOME\}/$HOME}"
}

backup_root="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')-ravn-binaries"

while IFS='|' read -r flag destination artifacts dependency || [[ -n $flag ]]; do
  [[ -z $flag || $flag == \#* ]] && continue
  [[ $flag == P || $flag == S ]] || continue
  [[ -n $destination && -n $artifacts && -n $dependency ]] || {
    printf '[binaries] invalid manifest entry\n' >&2
    exit 1
  }

  if ! command -v "$dependency" > /dev/null 2>&1; then
    printf '[binaries] [skip] %s: missing dependency %s\n' "$artifacts" "$dependency"
    continue
  fi

  destination="$(resolve_path "$destination")"
  source_dir="${SOURCE_ROOT}/${destination#"$HOME"/}"
  mkdir -p "$destination"

  for artifact in $artifacts; do
    source="${source_dir}/${artifact}"
    target="${destination}/${artifact}"
    [[ -f $source ]] || {
      printf '[binaries] source not found: %s\n' "$source" >&2
      exit 1
    }

    if [[ -e $target ]]; then
      mkdir -p "${backup_root}/${destination#"$HOME"/}"
      cp -p -- "$target" "${backup_root}/${destination#"$HOME"/}/"
      if [[ $flag == P ]]; then
        printf '[deploy] [preserved] %s\n' "$target"
        continue
      fi
    fi

    cp -p -- "$source" "$target"
    printf '[deploy] [restore] %s\n' "$target"
  done
done < "$MANIFEST"
