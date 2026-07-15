#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:?manifest path required}"
SOURCE_ROOT="${2:?source root required}"
CATEGORY="${3:?category name required}"
OVERWRITE="${4:-0}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/global_fn.sh"

if [[ $CATEGORY == configurations ]]; then
  backup_root="${HOME}/.config/ravn-backups/configurations/$(date +'%y%m%d_%Hh%Mm%Ss')"
else
  backup_root="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')-ravn-${CATEGORY,,}"
fi
print_info "Restoring declared RaVN ${CATEGORY}"
echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"

while IFS='|' read -r flag destination artifacts dependency || [[ -n $flag ]]; do
  [[ -z $flag || $flag == \#* ]] && continue
  [[ $flag == P || $flag == S ]] || continue
  [[ -n $destination && -n $artifacts && -n $dependency ]] || exit 1
  command -v "$dependency" > /dev/null 2>&1 || {
    print_warn "Skipping ${artifacts}: missing dependency ${dependency}"
    continue
  }
  destination="${destination//\$\{HOME\}/$HOME}"
  source_dir="${SOURCE_ROOT}/${destination#"$HOME"/}"
  mkdir -p "$destination"
  for artifact in $artifacts; do
    source="${source_dir}/${artifact}"
    target="${destination}/${artifact}"
    [[ -e $source ]] || {
                          print_error "Source not found: ${source}"
                                                                     exit 1
    }
    if [[ -e $target ]]; then
      mkdir -p "${backup_root}/${destination#"$HOME"/}"
      cp -a "$target" "${backup_root}/${destination#"$HOME"/}/"
      if [[ $OVERWRITE != 1 && $flag == P ]]; then
        print_info "Preserved ${target}"
        continue
      fi
      print_info "Backed up ${target}"
    fi
    cp -a "$source" "$destination/"
    print_success "Restored ${target}"
  done
done < "$MANIFEST"

echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
print_success "Declared RaVN ${CATEGORY} restored"
if [[ $CATEGORY == configurations ]]; then
  echo "[configurations] installed declared RaVN configuration overlay"
fi
