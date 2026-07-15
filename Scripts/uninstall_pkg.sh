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
print_info "Run record: $listPkg"
echo ""
print_info "Only packages recorded by this RaVN installation run may be removed"
print_section "Packages being removed"
while IFS= read -r pkg; do
  pkg="${pkg%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -n $pkg ]] || continue
  if pacman -Q "$pkg" &> /dev/null; then
    print_info "Removing explicitly installed package: $pkg"
    echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
    print_info "Package manager output"
    echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
    sudo pacman -R --noconfirm "$pkg"
    echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
    print_info "End of package manager output"
    ((removed += 1))
  else
    print_info "Already absent; leaving unchanged: $pkg"
    ((skipped += 1))
  fi
done < "$listPkg"
print_section "Rollback result"
if ((removed == 0)); then
  print_success "Rollback not required: no packages from this run are currently installed"
else
  print_success "Rollback completed: only packages from this run were removed"
fi
print_info "Technical summary: removed=$removed, already absent=$skipped"
