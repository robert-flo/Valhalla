#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_INSTALLER="${SCRIPT_DIR}/../install_pkg.sh"
PACKAGE_LIST="${SCRIPT_DIR}/../configurationspkg_core_RaVN.lst"
RUN_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/ravn/applications"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../global_fn.sh"

print_application_test_context() {
  print_section "${RAVN_ICON[ui_check]} RaVN application package audit"
  print_info "Manifest: ${PACKAGE_LIST#"${SCRIPT_DIR}/../"}"
  print_info "Mode: dry-run; no packages will be installed or removed"
  print_info "[skip] means the package is already installed"
  print_info "[queue] means the package is available and would be installed"
  print_info "To install queued packages, choose option 1: Install everything"
  print_section "Existing package installer audit"
}

if [[ ! -x $PACKAGE_INSTALLER ]]; then
  echo "Applications installer not found: ${PACKAGE_INSTALLER}" >&2
  exit 1
fi

case "${1:-test}" in
  test | --test)
    print_application_test_context
    if flg_DryRun=1 bash "$PACKAGE_INSTALLER" "$PACKAGE_LIST"; then
      echo ""
      print_success "Audit finished; no packages were changed"
      print_info "To install queued packages, choose option 1: Install everything"
    else
      echo ""
      print_error "Package audit failed"
      exit 1
    fi
    ;;
  install | --install)
    before_file="$(mktemp)"
    trap 'rm -f "$before_file"' EXIT
    while IFS= read -r package; do
      pacman -Q "$package" &> /dev/null && printf '%s\n' "$package" >> "$before_file"
    done < <(cut -d '#' -f 1 "$PACKAGE_LIST" | awk '{$1=$1; if ($1 != "") print $1}')
    bash "$PACKAGE_INSTALLER" "$PACKAGE_LIST"
    run_file="$RUN_ROOT/$(date +'%y%m%d_%Hh%Mm%Ss').installed"
    mkdir -p "$RUN_ROOT"
    : > "$run_file"
    while IFS= read -r package; do
      pacman -Q "$package" &> /dev/null || continue
      grep -Fxq "$package" "$before_file" || printf '%s\n' "$package" >> "$run_file"
    done < <(cut -d '#' -f 1 "$PACKAGE_LIST" | awk '{$1=$1; if ($1 != "") print $1}')
    [[ -s $run_file ]] || rm -f "$run_file"
    ;;
  dry-run | --dry-run)
    flg_DryRun=1 bash "$PACKAGE_INSTALLER" "$PACKAGE_LIST"
    ;;
  rollback | --rollback)
    run_file="${2:-}"
    [[ -f $run_file ]] || {
                            echo "Run record not found: $run_file" >&2
                                                                        exit 1
    }
    while IFS= read -r package; do
      [[ -n $package ]] && sudo pacman -R --noconfirm "$package"
    done < "$run_file"
    ;;
  help | --help | -h)
    printf '%s\n' "Usage: manage_applications.sh [test|install|dry-run|rollback RUN_FILE|help]"
    ;;
  *)
    printf 'Unknown command: %s\n' "$1" >&2
    exit 2
    ;;
esac
