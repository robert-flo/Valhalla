#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHERS_DIR="${SCRIPT_DIR}/launchers"
LAUNCHER_INSTALLER="${LAUNCHERS_DIR}/install_launchers.sh"
LAUNCHER_MANAGER="${LAUNCHERS_DIR}/manage_launchers.sh"
BINARIES_DIR="${SCRIPT_DIR}/binaries"
BINARIES_INSTALLER="${BINARIES_DIR}/install_binaries.sh"
BINARIES_MANAGER="${BINARIES_DIR}/manage_binaries.sh"
CONFIGURATIONS_DIR="${SCRIPT_DIR}/configurations"
CONFIGURATIONS_INSTALLER="${CONFIGURATIONS_DIR}/install_configurations.sh"
CONFIGURATIONS_MANAGER="${CONFIGURATIONS_DIR}/manage_configurations.sh"
APPLICATIONS_DIR="${SCRIPT_DIR}/applications"
APPLICATIONS_MANAGER="${APPLICATIONS_DIR}/manage_applications.sh"
readonly CATEGORY_BINARIES="Binaries"
readonly CATEGORY_CONFIGURATIONS="Configurations"
readonly CATEGORY_APPLICATIONS="Applications"

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

category_unavailable() {
  CATEGORY_RESULT="unavailable"
  print_warn "$1 are not available yet"
  print_info "This category is visible for discovery and did not change your system"
}

run_unavailable_category_menu() {
  local category="$1"
  local choice=""

  while true; do
    clear || true
    print_header "$category"
    print_section "${RAVN_ICON[ui_command]} Choose an action"
    echo -e "  ${GREEN}1${NC}  ${RAVN_ICON[ui_package]}  Install everything"
    echo -e "  ${GREEN}2${NC}  ${RAVN_ICON[ui_check]}  Run tests"
    echo -e "  ${GREEN}3${NC}  ${ICON_CLEANING}  Clean installed"
    echo -e "  ${GREEN}q${NC}  ${RAVN_ICON[ui_arrow_left]}  Back"
    echo ""
    printf '%b' "${LIGHT_GRAY}Selection:${NC} "
    read -r choice

    case "$choice" in
      1 | 2 | 3)
        category_unavailable "$category"
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

install_category() {
  CATEGORY_RESULT="failed"
  case "$1" in
    launchers)
      if install_all_launchers; then
        CATEGORY_RESULT="ok"
      else
        return 1
      fi
      ;;
    binaries)
      if install_all_binaries; then
        CATEGORY_RESULT="ok"
      else
        return 1
      fi
      ;;
    configurations)
      if install_all_configurations; then
        CATEGORY_RESULT="ok"
      else
        return 1
      fi
      ;;
    applications)
      if install_all_applications; then
        CATEGORY_RESULT="ok"
      else
        return 1
      fi
      ;;
    *)
      print_error "Unknown RaVN category: $1"
      return 2
      ;;
  esac
}

install_everything() {
  local category=""
  local failed=0
  local status=0
  local -a results=()

  print_header "Install everything"
  for category in launchers binaries configurations applications; do
    if install_category "$category"; then
      results+=("$category:${CATEGORY_RESULT}")
    else
      status=$?
      results+=("$category:failed($status)")
      ((failed += 1))
    fi
  done
  print_section "Installation summary"
  for status in "${results[@]}"; do
    if [[ $status == *:ok ]]; then
      print_success "$status"
    elif [[ $status == *:unavailable ]]; then
      print_warn "$status"
    else
      print_error "$status"
    fi
  done
  ((failed == 0))
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

validate_binary_sources() {
  local required_path=""
  for required_path in "$BINARIES_INSTALLER" "$BINARIES_MANAGER" "${BINARIES_DIR}/restore_binaries.psv"; do
    if [[ ! -f $required_path ]]; then
      print_error "Required binary source not found: ${required_path#"$SCRIPT_DIR"/}"
      return 1
    fi
  done
}

install_all_binaries() {
  validate_binary_sources || return 1
  print_section "${ICON_BUILD} Install Binaries"
  bash "$BINARIES_INSTALLER"
}

test_binaries() {
  validate_binary_sources || return 1
  bash "$BINARIES_MANAGER" --test
}

clean_binaries() {
  validate_binary_sources || return 1
  bash "$BINARIES_MANAGER" --clean
}

validate_configuration_sources() {
  local required_path=""
  for required_path in "$CONFIGURATIONS_INSTALLER" "$CONFIGURATIONS_MANAGER" "${CONFIGURATIONS_DIR}/restore_configurations.psv"; do
    if [[ ! -f $required_path ]]; then
      print_error "Required configuration source not found: ${required_path#"$SCRIPT_DIR"/}"
      return 1
    fi
  done
}

install_all_configurations() {
  validate_configuration_sources || return 1
  print_section "${ICON_BUILD} Install Configurations"
  bash "$CONFIGURATIONS_INSTALLER"
}

test_configurations() {
  validate_configuration_sources || return 1
  bash "$CONFIGURATIONS_MANAGER" --test
}

clean_configurations() {
  validate_configuration_sources || return 1
  bash "$CONFIGURATIONS_MANAGER" --clean
}

validate_application_sources() {
  [[ -f $APPLICATIONS_MANAGER && -f ${APPLICATIONS_DIR}/pkg_ravn.lst ]]
}

install_all_applications() {
  validate_application_sources || return 1
  print_section "${ICON_BUILD} Install Applications"
  bash "$APPLICATIONS_MANAGER" --install
}

test_applications() {
  validate_application_sources || return 1
  bash "$APPLICATIONS_MANAGER" --test
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

run_binaries_menu() {
  local choice=""
  while true; do
    clear || true
    print_header "$CATEGORY_BINARIES"
    print_section "${RAVN_ICON[ui_command]} Choose an action"
    echo -e "  ${GREEN}1${NC}  ${RAVN_ICON[ui_package]}  Install everything"
    echo -e "  ${GREEN}2${NC}  ${RAVN_ICON[ui_check]}  Run tests"
    echo -e "  ${GREEN}3${NC}  ${ICON_CLEANING}  Clean installed"
    echo -e "  ${GREEN}q${NC}  ${RAVN_ICON[ui_arrow_left]}  Back"
    printf '%b' "${LIGHT_GRAY}Selection:${NC} "
    read -r choice
    case "$choice" in
      1)
        install_all_binaries || true
        press_enter_to_continue
        ;;
      2)
        test_binaries || true
        press_enter_to_continue
        ;;
      3)
        clean_binaries || true
        press_enter_to_continue
        ;;
      q | Q) return 0 ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

run_configurations_menu() {
  local choice=""
  while true; do
    clear || true
    print_header "$CATEGORY_CONFIGURATIONS"
    print_section "${RAVN_ICON[ui_command]} Choose an action"
    echo -e "  ${GREEN}1${NC}  ${RAVN_ICON[ui_package]}  Install everything"
    echo -e "  ${GREEN}2${NC}  ${RAVN_ICON[ui_check]}  Run tests"
    echo -e "  ${GREEN}3${NC}  ${ICON_CLEANING}  Clean installed"
    echo -e "  ${GREEN}q${NC}  ${RAVN_ICON[ui_arrow_left]}  Back"
    printf '%b' "${LIGHT_GRAY}Selection:${NC} "
    read -r choice
    case "$choice" in
      1)
        install_all_configurations || true
        press_enter_to_continue
        ;;
      2)
        test_configurations || true
        press_enter_to_continue
        ;;
      3)
        clean_configurations || true
        press_enter_to_continue
        ;;
      q | Q) return 0 ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

run_applications_menu() {
  local choice=""
  while true; do
    clear || true
    print_header "$CATEGORY_APPLICATIONS"
    print_section "${RAVN_ICON[ui_command]} Choose an action"
    echo -e "  ${GREEN}1${NC}  ${RAVN_ICON[ui_package]}  Install everything"
    echo -e "  ${GREEN}2${NC}  ${RAVN_ICON[ui_check]}  Run tests"
    echo -e "  ${GREEN}3${NC}  ${ICON_CLEANING}  Rollback installed"
    echo -e "  ${GREEN}q${NC}  ${RAVN_ICON[ui_arrow_left]}  Back"
    printf '%b' "${LIGHT_GRAY}Selection:${NC} "
    read -r choice
    case "$choice" in
      1)
        install_all_applications || true
        press_enter_to_continue
        ;;
      2)
        test_applications || true
        press_enter_to_continue
        ;;
      3)
        print_info "Use manage_applications.sh rollback RUN_FILE to target a recorded run"
        press_enter_to_continue
        ;;
      q | Q) return 0 ;;
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
  echo -e "  ${GREEN}2${NC}  ${RAVN_ICON[ui_terminal]}  Binaries"
  echo -e "  ${GREEN}3${NC}  ${RAVN_ICON[ui_gear]}  Configurations"
  echo -e "  ${GREEN}4${NC}  ${RAVN_ICON[ui_package]}  Applications"
  echo -e "  ${GREEN}5${NC}  ${RAVN_ICON[ui_rocket]}  Install everything"
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
      2)
        run_binaries_menu
        ;;
      3)
        run_configurations_menu
        ;;
      4)
        run_applications_menu
        ;;
      5)
        install_everything || true
        press_enter_to_continue
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

print_usage() {
  cat << 'USAGE'
Usage: install_ravn.sh [COMMAND]

Commands:
  all, --all         Install all available RaVN categories
  launchers          Install all Desktop launchers
  binaries           Install the RaVN Binaries category
  configurations     Install the RaVN Configurations overlay
  applications       Install the RaVN Applications category
  rollback-applications <run-file>
                     Roll back explicitly installed packages from a run
  test, --test       Audit launcher artifacts declared in the manifest
  clean, --clean     Remove declared launcher artifacts after confirmation
  dry-run, --dry-run Show what installation would do without modifying $HOME
  help, --help       Show this help

With no command, the interactive installer menu is shown.
USAGE
}

run_dry_run() {
  validate_launcher_sources || return 1
  print_section "${ICON_BUILD} Dry run"
  print_info "Would run the existing Desktop launcher installer"
  print_info "Would write only artifacts declared by launchers/restore_launchers.psv"
  print_info "No files were modified"
}

main() {
  case "${1:-menu}" in
    all | --all)
      install_everything
      ;;
    launchers)
      install_category launchers
      ;;
    binaries)
      install_all_binaries
      ;;
    configurations)
      install_all_configurations
      ;;
    applications)
      install_all_applications
      ;;
    rollback-applications)
      bash "$APPLICATIONS_MANAGER" --rollback "${2:-}"
      ;;
    test | --test)
      test_launchers
      ;;
    clean | --clean)
      clean_launchers
      ;;
    dry-run | --dry-run)
      run_dry_run
      ;;
    help | --help | -h)
      print_usage
      ;;
    menu)
      run_main_menu
      ;;
    *)
      print_error "Unknown command: $1"
      print_usage
      return 2
      ;;
  esac
}

if [[ ${RAVN_INSTALLER_LIBRARY_ONLY:-0} != 1 ]]; then
  main "$@"
fi
