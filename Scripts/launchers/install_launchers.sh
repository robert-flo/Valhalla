#!/usr/bin/env bash
#|---/ /+---------------------------+---/ /|#
#|--/ /-| RaVN desktop launchers    |--/ /-|#
#|-/ /--| webapps + TUIs installer  |-/ /--|#
#|/ /---+---------------------------+/ /---|#

set -uo pipefail

LAUNCHERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="${HOME}/.local/share/applications/icons"
APPS_DIR="${HOME}/.local/share/applications"
OMARCHY_BIN="${HOME}/.local/share/omarchy/bin"

# RaVN launchers/bin is self-contained; omarchy bin is optional fallback
export PATH="${LAUNCHERS_DIR}/bin:${OMARCHY_BIN}:${PATH}"

# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/lib/reporting.sh"
ravn_launchers_reset

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    echo "[launchers] error: required command not found: $cmd" >&2
    exit 1
  fi
}

require_cmd omarchy-webapp-install  # vendored in launchers/bin
require_cmd omarchy-tui-install     # vendored in launchers/bin
require_cmd omarchy-launcher-install # vendored in launchers/bin
require_cmd omarchy-launch-webapp   # vendored in launchers/bin (runtime for webapps)

mkdir -p "$ICON_DIR" "$APPS_DIR"

echo "[launchers] installing webapps..."
# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/webapps.sh"

echo "[launchers] installing TUIs..."
# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/tuis.sh"

echo "[launchers] installing edge webapps (second account)..."
# shellcheck disable=SC1091
source "${LAUNCHERS_DIR}/edge-webapps.sh"

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APPS_DIR"
fi

rm -f "${HOME}/.cache/rofi3.druncache" "${HOME}/.cache/rofi-4.runcache" 2>/dev/null || true

ravn_launchers_summary