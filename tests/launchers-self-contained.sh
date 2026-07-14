#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHERS_DIR="${SCRIPT_DIR}/../Scripts/launchers"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravn-launchers-test.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

HOME="$FIXTURE_DIR/home"
export HOME
mkdir -p "$HOME/.local/share/applications/icons" "$HOME/.local/share/applications"

RAVN_LAUNCHERS_ASSETS_ONLY=1 bash "$LAUNCHERS_DIR/install_launchers.sh" > "$FIXTURE_DIR/install.out"
[[ -f "$HOME/.local/share/applications/icons/ChatGPT.png" ]] || fail "declared launcher icon was not installed"

touch "$HOME/.local/share/applications/ChatGPT.desktop"
touch "$HOME/.local/share/applications/icons/ChatGPT.png"
printf 'yes\n' | bash "$LAUNCHERS_DIR/manage_launchers.sh" --clean > "$FIXTURE_DIR/clean.out"
[[ ! -e "$HOME/.local/share/applications/ChatGPT.desktop" ]] || fail "managed desktop entry was not removed"
[[ -f "$HOME/.local/share/applications/icons/ChatGPT.png" ]] || fail "reusable launcher icon was removed"

echo "PASS: self-contained launcher assets and scoped cleanup"
