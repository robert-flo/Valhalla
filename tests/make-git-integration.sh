#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  grep -Fq "$needle" <<< "$haystack" || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if grep -Fq "$needle" <<< "$haystack"; then
    fail "expected output not to contain: $needle"
  fi
}

before_status=$(git -C "$ROOT_DIR" status --porcelain)

help_output=$(make -s -C "$ROOT_DIR" help-aliases)
assert_contains "$help_output" "vm                   dev-vm"
assert_contains "$help_output" "a / git-a            git-add"
assert_contains "$help_output" "st/s / git-st/s      git-status"
assert_not_contains "$help_output" "switch               sys-apply"
assert_not_contains "$help_output" "format / fmt-c"

for target in git-status git-st st s git-push git-p p git-cm cm dev-vm vm; do
  make -n -C "$ROOT_DIR" "$target" > /dev/null || fail "target did not resolve: $target"
done

custom_commit_output=$(make -n -C "$ROOT_DIR" cm integration message)
assert_contains "$custom_commit_output" 'integration message'

for pending_target in switch update format docs-local; do
  if make -n -C "$ROOT_DIR" "$pending_target" > /dev/null 2>&1; then
    fail "pending alias unexpectedly resolved: $pending_target"
  fi
done

after_status=$(git -C "$ROOT_DIR" status --porcelain)
[[ $before_status == "$after_status" ]] || fail "contract checks changed the working tree"

printf 'PASS: Git Make integration and alias routing\n'
