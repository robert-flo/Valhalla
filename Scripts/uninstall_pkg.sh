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

while IFS= read -r pkg; do
  pkg="${pkg%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -n $pkg ]] || continue
  if pacman -Q "$pkg" &> /dev/null; then
    print_log -b "[remove] " "$pkg"
    sudo pacman -R --noconfirm "$pkg"
  else
    print_log -y "[skip] " "$pkg (not installed)"
  fi
done < "$listPkg"
