#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/restore_launchers.psv"

# shellcheck disable=SC1091
if ! source "${SCRIPT_DIR}/../../Scripts/global_fn.sh"; then
  echo "Error: unable to source global_fn.sh..." >&2
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  print_error "Do not run launcher management as root or with sudo"
  exit 1
fi

resolve_path() {
  local path="$1"
  printf '%s\n' "${path//\$\{HOME\}/$HOME}"
}

load_manifest() {
  local flag=""
  local destination=""
  local artifact=""
  local _owner=""
  local resolved_path=""

  [[ -f $MANIFEST ]] || {
    print_error "Launcher manifest not found: ${MANIFEST}"
    return 1
  }

  while IFS='|' read -r flag destination artifact _owner || [[ -n $flag ]]; do
    [[ -z ${flag//[[:space:]]/} || $flag == \#* ]] && continue
    [[ $flag == P && -n $destination && -n $artifact ]] || continue
    # Icons are installation inputs; only generated desktop entries are managed.
    [[ $artifact == *.desktop ]] || continue

    destination="$(resolve_path "$destination")"
    resolved_path="$(realpath -m -- "$destination/$artifact")"
    case "$resolved_path" in
      "$HOME"/*) printf '%s\n' "$resolved_path" ;;
      *)
        print_error "Manifest path escapes HOME: ${destination}/${artifact}"
        return 1
        ;;
    esac
  done < "$MANIFEST"
}

display_path() {
  local path="$1"
  printf '%s\n' "${path#"$HOME"/}"
}

audit_launchers() {
  local launcher_path=""
  local present=0
  local missing=0

  print_section "${RAVN_ICON[ui_check]} Launcher manifest audit"
  while IFS= read -r launcher_path; do
    if [[ -e $launcher_path ]]; then
      print_success "$(display_path "$launcher_path")"
      ((present += 1))
    else
      print_warn "Missing: $(display_path "$launcher_path")"
      ((missing += 1))
    fi
  done < <(load_manifest)

  echo ""
  print_info "Present: ${present}"
  print_info "Missing: ${missing}"
  ((missing == 0))
}

clean_launchers() {
  local launcher_path=""
  local managed=()
  local existing=()
  local answer=""
  local dry_run="${DRY_RUN:-0}"

  print_section "${ICON_CLEANING} Clean managed launchers"
  while IFS= read -r launcher_path; do
    managed+=("$launcher_path")
    [[ -e $launcher_path ]] && existing+=("$launcher_path")
  done < <(load_manifest)

  if ((${#existing[@]} == 0)); then
    print_info "No managed launcher artifacts found"
    return 0
  fi

  print_warn "The following managed artifacts will be removed:"
  for launcher_path in "${existing[@]}"; do
    print_info "$(display_path "$launcher_path")"
  done
  echo ""
  print_info "Managed: ${#managed[@]}"
  print_info "Present: ${#existing[@]}"
  if [[ $dry_run == 1 ]]; then
    print_info "Dry run: no launcher artifacts were removed"
    return 0
  fi
  echo ""
  read -r -p "Type yes to continue: " answer
  if [[ $answer != yes ]]; then
    print_info "Cleanup cancelled"
    return 0
  fi

  for launcher_path in "${existing[@]}"; do
    if rm -f -- "$launcher_path"; then
      print_success "Removed $(display_path "$launcher_path")"
    else
      print_error "Unable to remove $(display_path "$launcher_path")"
    fi
  done
}

print_usage() {
  cat << 'USAGE'
Usage: manage_launchers.sh [COMMAND]

Commands:
  test, --test       Audit declared launcher artifacts in $HOME
  clean, --clean     Remove declared launcher artifacts after confirmation
  dry-run, --dry-run Show cleanup actions without modifying the system
  help, --help       Show this help
USAGE
}

case "${1:-test}" in
  test | --test)
    audit_launchers
    ;;
  clean | --clean)
    clean_launchers
    ;;
  dry-run | --dry-run)
    DRY_RUN=1 clean_launchers
    ;;
  help | --help | -h)
    print_usage
    ;;
  *)
    print_error "Unknown command: $1"
    print_usage
    exit 2
    ;;
esac
