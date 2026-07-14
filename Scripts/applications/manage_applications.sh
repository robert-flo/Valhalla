#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/pkg_ravn.lst"
RUN_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/ravn/applications"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../global_fn.sh"

packages() { awk 'NF && $1 !~ /^#/ {print $1}' "$MANIFEST"; }
is_installed() { pacman -Q "$1" &> /dev/null; }
is_available() { pacman -Si "$1" &> /dev/null; }

calculate_candidates() {
  local package=""
  while IFS= read -r package; do
    if is_installed "$package"; then
      print_info "Skipping installed package: $package"
    elif is_available "$package"; then
      print_info "Candidate: $package"
    else
      print_warn "Package unavailable: $package"
    fi
  done < <(packages)
}

install_applications() {
  local package=""
  local -a candidates=()
  local -a installed=()
  while IFS= read -r package; do
    if is_installed "$package"; then
      print_info "Skipping installed package: $package"
    elif is_available "$package"; then
      candidates+=("$package")
    else
      print_warn "Package unavailable: $package"
    fi
  done < <(packages)
  if ((${#candidates[@]} == 0)); then
    print_info "No new RaVN application packages to install"
    return 0
  fi
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    print_info "Dry run: no packages were installed"
    printf '%s\n' "${candidates[@]}"
    return 0
  fi
  sudo pacman -S --needed --noconfirm "${candidates[@]}"
  for package in "${candidates[@]}"; do
    if is_installed "$package"; then installed+=("$package"); fi
  done
  mkdir -p "$RUN_ROOT"
  local run_file=""
  run_file="$RUN_ROOT/$(date +'%y%m%d_%Hh%Mm%Ss').installed"
  printf '%s\n' "${installed[@]}" > "$run_file"
  print_success "Recorded ${#installed[@]} explicitly installed package(s): $run_file"
}

rollback_applications() {
  local run_file="${1:-}"
  local package=""
  [[ -f $run_file ]] || {
    print_error "Run record not found: $run_file"
    return 1
  }
  while IFS= read -r package; do
    [[ -n $package ]] || continue
    if is_installed "$package"; then
      print_info "Removing explicitly installed package: $package"
      sudo pacman -R --noconfirm "$package"
    else
      print_info "Already absent: $package"
    fi
  done < "$run_file"
}

case "${1:-test}" in
  test | --test) calculate_candidates ;;
  install | --install) install_applications ;;
  dry-run | --dry-run) DRY_RUN=1 install_applications ;;
  rollback | --rollback) rollback_applications "${2:-}" ;;
  help | --help | -h) echo "Usage: manage_applications.sh [test|install|dry-run|rollback RUN_FILE]" ;;
  *)
    print_error "Unknown command: $1"
    exit 2
    ;;
esac
