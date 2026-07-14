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

NO_COLOR=1 "$INSTALLER" binaries > "$FIXTURE_DIR/binaries.out"
assert_contains "$FIXTURE_DIR/binaries.out" "Binaries are not available yet"
assert_contains "$FIXTURE_DIR/binaries.out" "did not change your system"

NO_COLOR=1 "$INSTALLER" configurations > "$FIXTURE_DIR/configurations.out"
assert_contains "$FIXTURE_DIR/configurations.out" "Configurations are not available yet"

NO_COLOR=1 "$INSTALLER" help > "$FIXTURE_DIR/help.out"
if grep -Fq 'install.sh' "$FIXTURE_DIR/help.out"; then
  fail "help output leaked an upstream installer dependency"
fi

echo "PASS: RaVN installer category dispatch"
