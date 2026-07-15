#!/usr/bin/env bash

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
APPLICATIONS_RUN_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/ravn/applications"
# shellcheck disable=SC2034
if ! declare -p CATEGORY_BINARIES &> /dev/null; then readonly CATEGORY_BINARIES="Binaries"; fi
# shellcheck disable=SC2034
if ! declare -p CATEGORY_CONFIGURATIONS &> /dev/null; then readonly CATEGORY_CONFIGURATIONS="Configurations"; fi
# shellcheck disable=SC2034
if ! declare -p CATEGORY_APPLICATIONS &> /dev/null; then readonly CATEGORY_APPLICATIONS="Applications"; fi

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/global_fn.sh"

validate_launcher_sources() {
  local path=""
  for path in "$LAUNCHER_INSTALLER" "$LAUNCHER_MANAGER" "${LAUNCHERS_DIR}/restore_launchers.psv"; do
    [[ -f $path ]] || {
                        print_error "Required launcher source not found: ${path#"$SCRIPT_DIR"/}"
                                                                                                  return 1
    }
  done
}

install_all_launchers() {
                          validate_launcher_sources || return 1
                                                                 print_section "${ICON_BUILD} Install Desktop launchers"
                                                                                                                          bash "$LAUNCHER_INSTALLER"
}
test_launchers() {
                   validate_launcher_sources || return 1
                                                          bash "$LAUNCHER_MANAGER" --test
}
clean_launchers() {
                    validate_launcher_sources || return 1
                                                           bash "$LAUNCHER_MANAGER" --clean
}

validate_binary_sources() { [[ -f $BINARIES_INSTALLER && -f $BINARIES_MANAGER && -f ${BINARIES_DIR}/restore_binaries.psv ]]; }
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

validate_configuration_sources() { [[ -f $CONFIGURATIONS_INSTALLER && -f $CONFIGURATIONS_MANAGER && -f ${CONFIGURATIONS_DIR}/restore_configurations.psv ]]; }
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

validate_application_sources() { [[ -f $APPLICATIONS_MANAGER && -f ${SCRIPT_DIR}/install_pkg.sh && -f ${SCRIPT_DIR}/configurationspkg_core_RaVN.lst ]]; }
install_all_applications() {
                             validate_application_sources || return 1
                                                                       print_section "${ICON_BUILD} Install Applications"
                                                                                                                           bash "$APPLICATIONS_MANAGER" --install
}
test_applications() {
                      validate_application_sources || return 1
                                                                bash "$APPLICATIONS_MANAGER" --test
}

rollback_applications_from_menu() {
  local run_file=""
  run_file="$(find "$APPLICATIONS_RUN_ROOT" -maxdepth 1 -type f -name '*.installed' -printf '%T@ %p\n' 2> /dev/null | sort -nr | sed -n '1s/^[^ ]* //p')"
  [[ -n $run_file ]] || {
                          print_info "No application installation run is available to roll back"
                                                                                                  return 0
  }
  print_section "${ICON_CLEANING} Rollback application run"
  print_info "Rolling back the latest Applications Install everything run"
  print_info "Run record: $run_file"
  print_info "Only the packages listed below will be affected; no other packages will be touched"
  print_section "Packages selected for rollback"
  sed 's/^/  /' "$run_file"
  echo ""
  echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
  printf '%b' "  ${LIGHT_GRAY}Continue? [y/N] ${NC}"
  read -r choice
  [[ $choice == y || $choice == Y ]] || {
                                          print_info "Rollback cancelled"
                                                                           return 0
  }
  bash "$APPLICATIONS_MANAGER" --rollback "$run_file"
}

install_category() {
  case "$1" in
    launchers) install_all_launchers ;;
    binaries) install_all_binaries ;;
    configurations) install_all_configurations ;;
    applications) install_all_applications ;;
    *)
       print_error "Unknown RaVN category: $1"
                                                return 2
                                                         ;;
  esac
}

install_everything() {
  local category="" status=0 failed=0
  local -a results=()
  print_header "Install everything"
  for category in applications binaries configurations launchers; do
    if install_category "$category"; then results+=("$category:ok"); else
                                                                          status=$?
                                                                                     results+=("$category:failed($status)")
                                                                                                                             ((failed += 1))
    fi
  done
  print_section "Installation summary"
  for status in "${results[@]}"; do
    if [[ $status == *:ok ]]; then print_success "$status"; else print_error "$status"; fi
  done
  ((failed == 0))
}
