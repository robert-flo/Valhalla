#!/usr/bin/env bash

set -Eeuo pipefail

scrDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
listPkg="${1:-}"

if [[ -z $listPkg || ! -f $listPkg ]]; then
  printf 'Usage: %s RUN_FILE\n' "${0##*/}" >&2
  exit 2
fi

# shellcheck disable=SC1091
source "${scrDir}/global_fn.sh"

removed=0
skipped=0
print_section "${ICON_CLEANING} RaVN package rollback"
print_info "Run record: ${listPkg##*/}"
while IFS= read -r pkg; do
  pkg="${pkg%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -n $pkg ]] || continue
  if pacman -Q "$pkg" &> /dev/null; then
    print_log -b "[remove] " "$pkg"
    sudo pacman -R --noconfirm "$pkg"
    ((removed += 1))
  else
    print_log -y "[skip] " "$pkg (not installed)"
    ((skipped += 1))
  fi
done < "$listPkg"
print_info "Rollback summary: removed=$removed, already absent=$skipped"
if ((removed == 0)); then
  print_info "No installed packages from this run remained to remove"
fi
