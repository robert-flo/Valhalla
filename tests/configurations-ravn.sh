#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../Scripts/configurations"
INSTALLER="${SCRIPT_DIR}/../Scripts/install_ravn.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravn-configurations-test.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

HOME="$FIXTURE_DIR/home"
export HOME
mkdir -p "$HOME/.config/waybar" "$HOME/.local/share/waybar"
printf 'user\n' > "$HOME/.config/waybar/style.css"
printf 'undeclared\n' > "$HOME/.local/share/waybar/keep-me.txt"

bash "$CONFIG_DIR/install_configurations.sh" > "$FIXTURE_DIR/install.out"
[[ $(cat "$HOME/.config/waybar/style.css") == user ]] || fail "P policy overwrote existing configuration"
[[ -f "$HOME/.config/waybar/config.jsonc" ]] || fail "declared configuration was not installed"
[[ -d "$HOME/.config/ravn-backups/configurations" ]] || fail "existing configuration was not backed up"

bash "$CONFIG_DIR/manage_configurations.sh" --test > "$FIXTURE_DIR/test.out"
grep -Fq 'Missing: 0' "$FIXTURE_DIR/test.out" || fail "configuration audit did not report declared resources"

printf 'yes\n' | bash "$CONFIG_DIR/manage_configurations.sh" --clean > "$FIXTURE_DIR/clean.out"
[[ ! -e "$HOME/.config/waybar/config.jsonc" ]] || fail "declared configuration was not cleaned"
[[ -f "$HOME/.local/share/waybar/keep-me.txt" ]] || fail "undeclared configuration was cleaned"

NO_COLOR=1 "$INSTALLER" configurations > "$FIXTURE_DIR/dispatch.out"
grep -Fq 'installed declared RaVN configuration overlay' "$FIXTURE_DIR/dispatch.out" || fail "main installer did not dispatch Configurations"

echo "PASS: RaVN configuration overlay lifecycle"
