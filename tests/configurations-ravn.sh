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
RAVN_STYLE_SOURCE="${SCRIPT_DIR}/../Configs_RaVN/.config/waybar2/style.css"
mkdir -p "$HOME/.config/waybar2" "$HOME/.local/share/waybar"
printf 'preexisting upstream content\n' > "$HOME/.config/waybar2/style.css"
printf 'undeclared\n' > "$HOME/.local/share/waybar/keep-me.txt"

bash "$CONFIG_DIR/install_configurations.sh" > "$FIXTURE_DIR/install.out"
diff -q "$HOME/.config/waybar2/style.css" "$RAVN_STYLE_SOURCE" > /dev/null ||
  fail "RaVN did not take precedence over the existing configuration"
[[ -f "$HOME/.config/waybar2/config.jsonc" ]] || fail "declared configuration was not installed"
[[ -d "$HOME/.config/ravn-backups/configurations" ]] || fail "existing configuration was not backed up"
backed_up_style="$(find "$HOME/.config/ravn-backups/configurations" -name style.css -print -quit)"
[[ -n $backed_up_style ]] || fail "existing style.css was not backed up"
[[ $(cat "$backed_up_style") == "preexisting upstream content" ]] ||
  fail "backup did not preserve the prior configuration content"

bash "$CONFIG_DIR/manage_configurations.sh" --test > "$FIXTURE_DIR/test.out"
grep -Fq 'Missing: 0' "$FIXTURE_DIR/test.out" || fail "configuration audit did not report declared resources"

printf 'yes\n' | bash "$CONFIG_DIR/manage_configurations.sh" --clean > "$FIXTURE_DIR/clean.out"
[[ ! -e "$HOME/.config/waybar2/config.jsonc" ]] || fail "declared configuration was not cleaned"
[[ -f "$HOME/.local/share/waybar/keep-me.txt" ]] || fail "undeclared configuration was cleaned"

NO_COLOR=1 "$INSTALLER" configurations > "$FIXTURE_DIR/dispatch.out"
grep -Fq 'installed declared RaVN configuration overlay' "$FIXTURE_DIR/dispatch.out" || fail "main installer did not dispatch Configurations"

echo "PASS: RaVN configuration overlay lifecycle"
