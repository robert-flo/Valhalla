#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/../Scripts/install_ravn.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravn-install-everything-test.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# shellcheck disable=SC1090
RAVN_INSTALLER_LIBRARY_ONLY=1 source "$INSTALLER"
calls=()

install_category() {
  local category="$1"
  calls+=("$category")
  # shellcheck disable=SC2034
  CATEGORY_RESULT=ok
  if [[ $category == binaries ]]; then
    return 1
  fi
}

set +e
output_file="$FIXTURE_DIR/output"
NO_COLOR=1 install_everything > "$output_file" 2>&1
status=$?
set -e
output=$(< "$output_file")

[[ $status -eq 1 ]] || {
  echo "FAIL: aggregate did not report failure" >&2
  exit 1
}
[[ ${calls[*]} == 'launchers binaries configurations applications' ]] || {
  echo "FAIL: categories did not run in order: ${calls[*]}" >&2
  exit 1
}
grep -Fq 'binaries:failed(1)' <<< "$output" || {
  echo "FAIL: failed category missing from summary" >&2
  exit 1
}
grep -Fq 'applications:ok' <<< "$output" || {
  echo "FAIL: later category missing from summary" >&2
  exit 1
}

echo "PASS: Install everything continues and summarizes failures"
