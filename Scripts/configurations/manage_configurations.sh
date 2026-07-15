#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/restore_configurations.psv"
SOURCE_ROOT="${SCRIPT_DIR}/../../Configs_RaVN"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../global_fn.sh"

manifest_paths() {
  local flag="" destination="" artifact="" _owner="" source="" relative=""
  while IFS='|' read -r flag destination artifact _owner || [[ -n $flag ]]; do
    [[ $flag == P || $flag == S ]] || continue
    destination="${destination//\$\{HOME\}/$HOME}"
    source="${SOURCE_ROOT}/${destination#"$HOME"/}/${artifact}"
    if [[ -d $source ]]; then
      while IFS= read -r relative; do
        printf '%s\n' "${destination}/${artifact}/${relative#"$source"/}"
      done < <(find "$source" -type f -o -type l)
    else
      printf '%s\n' "${destination}/${artifact}"
    fi
  done < "$MANIFEST"
}

audit_configurations() {
  local path="" present=0 missing=0
  print_section "${RAVN_ICON[ui_check]} Configuration manifest audit"
  while IFS= read -r path; do
    if [[ -e $path ]]; then
      print_success "${path#"$HOME"/}"
      ((present += 1))
    else
      print_warn "Missing: ${path#"$HOME"/}"
      ((missing += 1))
    fi
  done < <(manifest_paths)
  print_info "Present: $present"
  print_info "Missing: $missing"
  ((missing == 0))
}

clean_configurations() {
  local path="" answer=""
  local -a existing=()
  while IFS= read -r path; do
    [[ -e $path ]] && existing+=("$path")
  done < <(manifest_paths)
  if ((${#existing[@]} == 0)); then
    print_info "No managed configurations found"
    return 0
  fi
  for path in "${existing[@]}"; do print_info "${path#"$HOME"/}"; done
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    print_info "Dry run: no configurations were removed"
    return 0
  fi
  read -r -p "Type yes to continue: " answer
  [[ $answer == yes ]] || {
    print_info "Cleanup cancelled"
    return 0
  }
  for path in "${existing[@]}"; do rm -f -- "$path"; done
  print_success "Removed ${#existing[@]} declared configuration resource(s)"
}

case "${1:-test}" in
  test | --test) audit_configurations ;;
  clean | --clean) clean_configurations ;;
  dry-run | --dry-run) DRY_RUN=1 clean_configurations ;;
  help | --help | -h) echo "Usage: manage_configurations.sh [test|clean|dry-run]" ;;
  *)
    print_error "Unknown command: $1"
    exit 2
    ;;
esac
