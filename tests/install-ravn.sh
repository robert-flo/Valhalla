#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/../Scripts/install_ravn.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-ravn-test.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq "$expected" "$file" || fail "expected output to contain: $expected"
}

HOME="$FIXTURE_DIR/home"
export HOME

NO_COLOR=1 "$INSTALLER" binaries > "$FIXTURE_DIR/binaries.out"
assert_contains "$FIXTURE_DIR/binaries.out" "installed declared RaVN binaries"
[[ -x "$HOME/.local/bin/ravn-dot" ]] || fail "Binaries dispatch did not install a declared binary"

NO_COLOR=1 "$INSTALLER" configurations > "$FIXTURE_DIR/configurations.out"
assert_contains "$FIXTURE_DIR/configurations.out" "installed declared RaVN configuration overlay"
[[ -f "$HOME/.config/waybar/config.jsonc" ]] || fail "Configurations dispatch did not install a declared resource"

NO_COLOR=1 "$INSTALLER" help > "$FIXTURE_DIR/help.out"
if grep -Fq 'install.sh' "$FIXTURE_DIR/help.out"; then
  fail "help output leaked an upstream installer dependency"
fi

echo "PASS: RaVN installer category dispatch"
