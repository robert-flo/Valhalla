#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/restore_binaries.psv"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../global_fn.sh"

resolve_path() {
  printf '%s\n' "${1//\$\{HOME\}/$HOME}"
}

load_paths() {
  local flag=""
  local destination=""
  local artifact=""
  local owner=""
  local resolved=""

  while IFS='|' read -r flag destination artifact owner || [[ -n $flag ]]; do
    [[ $flag == P && $owner == ravn-binary && -n $destination && -n $artifact ]] || continue
    destination="$(resolve_path "$destination")"
    resolved="$(realpath -m -- "$destination/$artifact")"
    case "$resolved" in
      "$HOME"/*) printf '%s\n' "$resolved" ;;
      *)
        print_error "Manifest path escapes HOME: $destination/$artifact"
        return 1
        ;;
    esac
  done < "$MANIFEST"
}

audit_binaries() {
  local path=""
  local present=0
  local missing=0

  print_section "${RAVN_ICON[ui_check]} Binary manifest audit"
  while IFS= read -r path; do
    if [[ -f $path ]]; then
      print_success "${path#"$HOME"/}"
      ((present += 1))
    else
      print_warn "Missing: ${path#"$HOME"/}"
      ((missing += 1))
    fi
  done < <(load_paths)
  echo ""
  echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
  print_info "Present: $present"
  print_info "Missing: $missing"
  ((missing == 0))
}

clean_binaries() {
  local path=""
  local answer=""
  local existing=()

  print_section "${ICON_CLEANING} Clean managed binaries"
  while IFS= read -r path; do
    [[ -e $path ]] && existing+=("$path")
  done < <(load_paths)
  if ((${#existing[@]} == 0)); then
    print_info "No managed binaries found"
    return 0
  fi
  for path in "${existing[@]}"; do print_info "${path#"$HOME"/}"; done
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    print_info "Dry run: no binaries were removed"
    return 0
  fi
  echo ""
  echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
  read -r -p "Type yes to continue: " answer
  [[ $answer == yes ]] || {
    print_info "Cleanup cancelled"
    return 0
  }
  for path in "${existing[@]}"; do
    rm -f -- "$path"
    print_success "Removed ${path#"$HOME"/}"
  done
  echo ""
  echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
}

case "${1:-test}" in
  test | --test) audit_binaries ;;
  clean | --clean) clean_binaries ;;
  dry-run | --dry-run) DRY_RUN=1 clean_binaries ;;
  help | --help | -h) echo "Usage: manage_binaries.sh [test|clean|dry-run]" ;;
  *)
    print_error "Unknown command: $1"
    exit 2
    ;;
esac
