#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="${SCRIPT_DIR}/../Scripts/binaries"
INSTALLER="${SCRIPT_DIR}/../Scripts/install_ravn.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravn-binaries-test.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

HOME="$FIXTURE_DIR/home"
export HOME

bash "$BINARIES_DIR/install_binaries.sh" > "$FIXTURE_DIR/install.out"
[[ -x "$HOME/.local/bin/ravn-dot" ]] || fail "declared binary was not installed"
printf '# undeclared\n' > "$HOME/.local/bin/keep-me"

bash "$BINARIES_DIR/manage_binaries.sh" --test > "$FIXTURE_DIR/test.out"
grep -Fq 'Present: 7' "$FIXTURE_DIR/test.out" || fail "binary audit did not report declared files"

printf 'yes\n' | bash "$BINARIES_DIR/manage_binaries.sh" --clean > "$FIXTURE_DIR/clean.out"
[[ ! -e "$HOME/.local/bin/ravn-dot" ]] || fail "declared binary was not cleaned"
[[ -f "$HOME/.local/bin/keep-me" ]] || fail "undeclared binary was cleaned"

NO_COLOR=1 "$INSTALLER" binaries > "$FIXTURE_DIR/dispatch.out"
grep -Fq 'installed declared RaVN binaries' "$FIXTURE_DIR/dispatch.out" || fail "main installer did not dispatch Binaries"

echo "PASS: manifest-driven RaVN binaries"
