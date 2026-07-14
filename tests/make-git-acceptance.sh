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

help_output=$(make -s -C "$ROOT_DIR" help-git)
for target in git-add git-commit git-cm git-push git-pull git-status git-diff git-log git-setup git-sync git-diff-here; do
  assert_contains "$help_output" "make $target"
  make -n -C "$ROOT_DIR" "$target" > /dev/null || fail "documented target did not resolve: $target"
  grep -Fq "$target" "$ROOT_DIR/docs/make/git.md" || fail "Git guide omitted target: $target"
done

alias_help=$(make -s -C "$ROOT_DIR" help-aliases)
assert_contains "$alias_help" 'vm                   dev-vm'
assert_contains "$alias_help" 'a / git-a            git-add'

for test_script in \
  make-git-integration.sh \
  make-git-local.sh \
  make-git-remote.sh \
  make-git-worktrees.sh; do
  "$ROOT_DIR/tests/$test_script" > /dev/null || fail "contract failed: $test_script"
done

printf 'PASS: complete Git Make experience\n'
