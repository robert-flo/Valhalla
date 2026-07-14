#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/restore_configurations.psv"
SOURCE_ROOT="${SCRIPT_DIR}/../../Configs"
BACKUP_ROOT="${HOME}/.config/ravn-backups/configurations/$(date +'%y%m%d_%Hh%Mm%Ss')"

while IFS='|' read -r flag destination artifact owner || [[ -n $flag ]]; do
  [[ $flag == P || $flag == S ]] || continue
  [[ $owner == ravn-configuration ]] || continue
  destination="${destination//\$\{HOME\}/$HOME}"
  source="${SOURCE_ROOT}/${destination#"$HOME"/}/${artifact}"
  target="${destination}/${artifact}"
  [[ -e $source ]] || {
    echo "[configurations] error: source missing: $source" >&2
    exit 1
  }
  mkdir -p "$destination"
  if [[ -e $target ]]; then
    mkdir -p "${BACKUP_ROOT}/${destination#"$HOME"/}"
    cp -a "$target" "${BACKUP_ROOT}/${destination#"$HOME"/}/"
  fi
  if [[ $flag == P ]]; then
    cp -an "$source" "$destination/"
  else
    cp -a "$source" "$destination/"
  fi
done < "$MANIFEST"

echo "[configurations] installed declared RaVN configuration overlay"
