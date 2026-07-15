#!/usr/bin/env bash
#|---/ /+---------------------------+---/ /|#
#|--/ /-| RaVN desktop launchers    |--/ /-|#
#|-/ /--| webapps + TUIs installer  |-/ /--|#
#|/ /---+---------------------------+/ /---|#

set -uo pipefail

if [[ -z ${HOME:-} ]]; then
  HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
  export HOME
fi

if [[ -z ${HOME:-} || $HOME == / || ! -d $HOME || ! -w $HOME ]]; then
  echo "[launchers] error: unable to determine a writable home directory" >&2
  exit 1
fi

LAUNCHERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="${HOME}/.local/share/applications/icons"
APPS_DIR="${HOME}/.local/share/applications"
OMARCHY_BIN="${HOME}/.local/share/omarchy/bin"
ICON_SOURCE_DIR="${LAUNCHERS_DIR}/../../Configs_RaVN/.local/share/applications/icons"
ICON_MANIFEST="${LAUNCHERS_DIR}/restore_launchers.psv"

# RaVN launchers/bin is self-contained; omarchy bin is optional fallback
export PATH="${LAUNCHERS_DIR}/bin:${OMARCHY_BIN}:${PATH}"

# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/lib/reporting.sh"
ravn_launchers_reset

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    echo "[launchers] error: required command not found: $cmd" >&2
    exit 1
  fi
}

require_cmd omarchy-webapp-install  # vendored in launchers/bin
require_cmd omarchy-tui-install     # vendored in launchers/bin
require_cmd omarchy-launcher-install # vendored in launchers/bin
require_cmd omarchy-launch-webapp   # vendored in launchers/bin (runtime for webapps)

install_launcher_icons() {
  local flag=""
  local _destination=""
  local artifact=""
  local owner=""
  local source=""

  [[ -d $ICON_SOURCE_DIR ]] || {
    echo "[launchers] error: icon source directory not found: $ICON_SOURCE_DIR" >&2
    return 1
  }

  while IFS='|' read -r flag _destination artifact owner || [[ -n $flag ]]; do
    [[ $flag == P && $owner == launcher-icon && -n $artifact ]] || continue
    source="${ICON_SOURCE_DIR}/${artifact}"
    if [[ ! -f $source ]]; then
      echo "[launchers] error: declared launcher icon not found: $artifact" >&2
      return 1
    fi
    cp -- "$source" "${ICON_DIR}/${artifact}"
  done < "$ICON_MANIFEST"
}

mkdir -p "$ICON_DIR" "$APPS_DIR"
install_launcher_icons

if [[ ${RAVN_LAUNCHERS_ASSETS_ONLY:-0} == 1 ]]; then
  echo "[launchers] launcher assets installed"
  exit 0
fi

echo "[launchers] installing webapps..."
# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/webapps.sh"

echo "[launchers] installing TUIs..."
# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/tuis.sh"

echo "[launchers] installing edge webapps (second account)..."
# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/edge-webapps.sh"

if command -v update-desktop-database &> /dev/null; then
  update-desktop-database "$APPS_DIR"
fi

rm -f "${HOME}/.cache/rofi3.druncache" "${HOME}/.cache/rofi-4.runcache" 2> /dev/null || true

ravn_launchers_summary
