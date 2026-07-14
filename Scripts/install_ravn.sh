#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHERS_DIR="${SCRIPT_DIR}/launchers"
LAUNCHER_INSTALLER="${LAUNCHERS_DIR}/install_launchers.sh"
LAUNCHER_MANAGER="${LAUNCHERS_DIR}/manage_launchers.sh"

# shellcheck disable=SC1091
if ! source "${SCRIPT_DIR}/global_fn.sh"; then
  echo "Error: unable to source global_fn.sh..." >&2
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  print_error "Do not run install_ravn.sh as root or with sudo"
  exit 1
fi

press_enter_to_continue() {
  echo ""
  read -r -p "Press Enter to continue..." _
}

validate_launcher_sources() {
  local required_path=""

  for required_path in "$LAUNCHER_INSTALLER" "$LAUNCHER_MANAGER" "${LAUNCHERS_DIR}/restore_launchers.psv"; do
    if [[ ! -f $required_path ]]; then
      print_error "Required launcher source not found: ${required_path#"$SCRIPT_DIR"/}"
      return 1
    fi
  done
}

install_all_launchers() {
  if ! validate_launcher_sources; then
    return 1
  fi

  print_section "${ICON_BUILD} Install everything"
  print_info "Using the existing Desktop launcher implementation"
  if bash "$LAUNCHER_INSTALLER"; then
    print_success "Desktop launchers installed"
  else
    print_error "Desktop launcher installation failed"
    return 1
  fi
}

test_launchers() {
  if ! validate_launcher_sources; then
    return 1
  fi

  bash "$LAUNCHER_MANAGER" --test
}

clean_launchers() {
  if ! validate_launcher_sources; then
    return 1
  fi

  bash "$LAUNCHER_MANAGER" --clean
}

show_launchers_menu() {
  clear || true
  print_header "Desktop launchers"
  print_section "${RAVN_ICON[ui_command]} Choose an action"
  echo -e "  ${GREEN}1${NC}  ${RAVN_ICON[ui_package]}  Install everything"
  echo -e "  ${GREEN}2${NC}  ${RAVN_ICON[ui_check]}  Run tests"
  echo -e "  ${GREEN}3${NC}  ${ICON_CLEANING}  Clean launcher installed"
  echo -e "  ${GREEN}q${NC}  ${RAVN_ICON[ui_arrow_left]}  Back"
  echo ""
  printf '%b' "${LIGHT_GRAY}Selection:${NC} "
}

run_launchers_menu() {
  local choice=""

  while true; do
    show_launchers_menu
    read -r choice

    case "$choice" in
      1)
        install_all_launchers || true
        press_enter_to_continue
        ;;
      2)
        test_launchers || true
        press_enter_to_continue
        ;;
      3)
        clean_launchers || true
        press_enter_to_continue
        ;;
      q | Q)
        return 0
        ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

show_main_menu() {
  clear || true
  print_header "Ravn installer"
  print_section "${RAVN_ICON[ui_command]} Choose an installation step"
  echo -e "  ${GREEN}1${NC}  ${RAVN_ICON[ui_package]}  Desktop launchers"
  echo -e "  ${GREEN}q${NC}  ${RAVN_ICON[ui_close]}  Exit"
  echo ""
  printf '%b' "${LIGHT_GRAY}Selection:${NC} "
}

run_main_menu() {
  local choice=""

  while true; do
    show_main_menu
    read -r choice

    case "$choice" in
      1)
        run_launchers_menu
        ;;
      q | Q)
        echo ""
        print_goodbye "Goodbye, ${USER:-$(id -un)}!"
        echo ""
        return 0
        ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

run_main_menu
