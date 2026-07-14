#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-cli-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"

cleanup() {
  rm -rf "$FIXTURE_DIR"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  grep -Fq "$needle" <<< "$haystack" || fail "expected output to contain: $needle"
}

export XDG_CACHE_HOME="$FIXTURE_DIR/cache"
mkdir -p "$FAKE_BIN"
for command_name in pacman qemu-system-x86_64 qemu-img curl git; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done
export PATH="$FAKE_BIN:$PATH"
mkdir -p "$XDG_CACHE_HOME/ravnvm/snapshots"
touch "$XDG_CACHE_HOME/ravnvm/archbase.qcow2"
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2"

clean_output=$("$RAVNVM_SCRIPT" --clean)
assert_contains "$clean_output" "base image preserved"
[[ -f "$XDG_CACHE_HOME/ravnvm/archbase.qcow2" ]] || fail "cleanup removed the base image"
[[ ! -e "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2" ]] || fail "cleanup retained a snapshot"

touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-master.qcow2"
default_output=$(VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$default_output" "Starting RaVN VM (branch/commit: master)"

help_output=$("$RAVNVM_SCRIPT" --help)
assert_contains "$help_output" "Usage: ravnvm [OPTIONS] [BRANCH/COMMIT]"

list_output=$("$RAVNVM_SCRIPT" --list)
assert_contains "$list_output" "master"

touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2"
ephemeral_output=$(VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" dev 2>&1)
assert_contains "$ephemeral_output" "non-persistent mode"
assert_contains "$ephemeral_output" "branch/commit: dev"

persistent_output=$(VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" --persist dev 2>&1)
assert_contains "$persistent_output" "persistent mode"
assert_contains "$persistent_output" "branch/commit: dev"

printf 'PASS: RavnVM direct CLI\n'
