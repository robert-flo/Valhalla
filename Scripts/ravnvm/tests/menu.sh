#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-test.XXXXXX")"
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

mkdir -p "$FAKE_BIN"
touch "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
chmod +x "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
ln -s /usr/bin/true "$FAKE_BIN/ssh"
export PATH="$FAKE_BIN:$PATH"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

menu_output=$(printf 'q\n' | "$RAVNVM_SCRIPT")
assert_contains "$menu_output" "Choose an action"
assert_contains "$menu_output" "Run master branch"
assert_contains "$menu_output" "Run dev branch"
assert_contains "$menu_output" "Run current branch"
assert_contains "$menu_output" "Run other branch or commit"
assert_contains "$menu_output" "Show RavnVM usage"
assert_contains "$menu_output" "Connect to VM via SSH"
assert_contains "$menu_output" "Install SSH alias"
assert_contains "$menu_output" "   Configure RAM and CPU"
assert_contains "$menu_output" "   Install SSH alias"
assert_contains "$menu_output" "Goodbye!"

invalid_output=$(printf 'x\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$invalid_output" "Invalid option: x"

revision_output=$(printf '1\nq\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$revision_output" "Choose VM mode"
assert_contains "$revision_output" "Ephemeral"
assert_contains "$revision_output" "Persistent"
assert_contains "$revision_output" "Back"

revision_choices_output=$(printf '2\nq\n3\nq\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$revision_choices_output" "Run dev branch"
assert_contains "$revision_choices_output" "Run current branch"

empty_revision_output=$(printf '4\n\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$empty_revision_output" "A branch or commit is required"

help_output=$("$RAVNVM_SCRIPT" --help)
assert_contains "$help_output" "Usage: ravnvm"

snapshot_output=$("$RAVNVM_SCRIPT" --list)
assert_contains "$snapshot_output" "Available RaVN snapshots"
assert_contains "$snapshot_output" "No snapshots found"

touch "$XDG_CACHE_HOME/ravnvm/archbase.qcow2"
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2"
clean_output=$("$RAVNVM_SCRIPT" --clean)
assert_contains "$clean_output" "base image preserved"
[[ -f "$XDG_CACHE_HOME/ravnvm/archbase.qcow2" ]] || fail "clean removed the base image"
[[ ! -e "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2" ]] || fail "clean retained a snapshot"

storage_output=$(printf 'q\n' | "$RAVNVM_SCRIPT")
assert_contains "$storage_output" "VM cache:"
assert_contains "$storage_output" "Disk:"
assert_contains "$storage_output" "Free:"

storage_menu_output=$(printf '5\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$storage_menu_output" "Storage"
assert_contains "$storage_menu_output" "VM cache:"

resource_defaults_output=$(printf '8\n\n\n\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$resource_defaults_output" "Configure VM resources"
assert_contains "$resource_defaults_output" "Session resources: 4G RAM, 2 CPUs"

resource_values_output=$(printf '8\n8G\n4\n\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$resource_values_output" "Session resources: 8G RAM, 4 CPUs"

resource_invalid_output=$(printf '8\n8G\n0\n\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$resource_invalid_output" "CPU count must be a positive integer"
if grep -Fq "Session resources: 8G RAM, 0 CPUs" <<< "$resource_invalid_output"; then
    fail "invalid CPU count was accepted"
fi

menu_help_output=$(printf '9\nq\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$menu_help_output" "Usage: ravnvm [OPTIONS] [BRANCH/COMMIT]"
assert_contains "$menu_help_output" "VM_MEMORY=4G"
assert_contains "$menu_help_output" "VM_QEMU_OVERRIDE"
assert_contains "$menu_help_output" "NixOS: automatically installs dependencies"

ssh_menu_output=$(printf '10\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$ssh_menu_output" "Connect to VM via SSH"

make_output=$(make -s DRY_RUN=1 dev-vm REF=dev)
assert_contains "$make_output" "ravnvm.sh dev"
make_persist_output=$(make -s DRY_RUN=1 dev-vm-persist REF=dev)
assert_contains "$make_persist_output" "ravnvm.sh --persist dev"
make_setup_output=$(make -s DRY_RUN=1 dev-vm-setup)
assert_contains "$make_setup_output" "ravnvm.sh --check-deps"
assert_contains "$make_setup_output" "ravnvm.sh --install-deps"
make_ssh_output=$(make -s DRY_RUN=1 dev-vm-ssh)
assert_contains "$make_ssh_output" "ravnvm.sh --ssh"
make_help_output=$(make -s help)
assert_contains "$make_help_output" "make dev-vm"
assert_contains "$make_help_output" "make dev-vm-ssh"

rm -f "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
for command_name in env bash realpath dirname clear awk df du find sed basename mktemp mkdir rm grep cat git curl python3; do
    ln -sf "$(command -v "$command_name")" "$FAKE_BIN/$command_name"
done
ln -sf "$FAKE_BIN/python3" "$FAKE_BIN/python"
recovery_output=$(PATH="$FAKE_BIN" printf 'q\n' | PATH="$FAKE_BIN" "$RAVNVM_SCRIPT")
assert_contains "$recovery_output" "Required dependencies missing"
assert_contains "$recovery_output" "Install dependencies"
if grep -Fq "Choose an action" <<< "$recovery_output"; then
    fail "dependency recovery opened the normal menu"
fi

printf 'PASS: RavnVM interaction surfaces\n'
