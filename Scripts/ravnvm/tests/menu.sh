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

mkdir -p "$XDG_CACHE_HOME/ravnvm/snapshots"
touch "$XDG_CACHE_HOME/ravnvm/archbase.qcow2"
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-master-fc613b4dfd67.qcow2"
menu_output=$(printf 'q\n' | VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT")
assert_contains "$menu_output" "Choose an action"
assert_contains "$menu_output" "Run master branch"
assert_contains "$menu_output" "Run dev branch"
assert_contains "$menu_output" "Run current branch"
assert_contains "$menu_output" "Run other branch or commit"
assert_contains "$menu_output" "Show RavnVM usage"
assert_contains "$menu_output" "Connect to VM via SSH"
assert_contains "$menu_output" "Goodbye!"
rm -rf "$XDG_CACHE_HOME/ravnvm"

invalid_output=$(printf 'x\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$invalid_output" "Invalid option: x"

revision_output=$(printf '1\nq\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$revision_output" "Choose VM mode"
assert_contains "$revision_output" "Ephemeral"
assert_contains "$revision_output" "Persistent"
assert_contains "$revision_output" "Back"

revision_choices_output=$(printf '2\nq\n3\nq\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$revision_choices_output" "Run dev branch"
assert_contains "$revision_choices_output" "Run current branch"

empty_revision_output=$(printf '4\n\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
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

touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-master-fc613b4dfd67.qcow2"
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev-ef260e9aa3c6.qcow2"
ephemeral_output=$(printf '1\n1\n\nq\n' | VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT")
assert_contains "$ephemeral_output" "non-persistent mode"
assert_contains "$ephemeral_output" "branch/commit: master"
persistent_output=$(printf '2\n2\n\nq\n' | VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT")
assert_contains "$persistent_output" "persistent mode"
assert_contains "$persistent_output" "branch/commit: dev"
current_branch=$(git -C "$SCRIPT_DIR/../.." branch --show-current)
current_slug="${current_branch//[^a-zA-Z0-9._-]/_}"
current_digest=$(printf '%s' "$current_branch" | sha256sum | cut -c 1-12)
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-${current_slug}-${current_digest}.qcow2"
current_output=$(printf '3\n1\n\nq\n' | VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT")
assert_contains "$current_output" "branch/commit: $current_branch"
custom_output=$(printf '4\ndev\n1\n\nq\n' | VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT")
assert_contains "$custom_output" "branch/commit: dev"

storage_output=$(printf 'q\n' | "$RAVNVM_SCRIPT")
assert_contains "$storage_output" "VM cache:"
assert_contains "$storage_output" "Disk:"
assert_contains "$storage_output" "Free:"

storage_menu_output=$(printf '5\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$storage_menu_output" "Storage"
assert_contains "$storage_menu_output" "VM cache:"

resource_defaults_output=$(printf '8\n\n\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$resource_defaults_output" "Configure VM resources"
assert_contains "$resource_defaults_output" "Session resources: 4G RAM, 2 CPUs"

resource_values_output=$(printf '8\n8G\n4\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$resource_values_output" "Session resources: 8G RAM, 4 CPUs"

resource_invalid_output=$(printf '8\n8G\n0\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$resource_invalid_output" "CPU count must be a positive integer"
if grep -Fq "Session resources: 8G RAM, 0 CPUs" <<< "$resource_invalid_output"; then
    fail "invalid CPU count was accepted"
fi

memory_invalid_output=$(printf '8\ngarbage\n4\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$memory_invalid_output" "RAM must be a positive number"
if grep -Fq "Session resources: garbage RAM" <<< "$memory_invalid_output"; then
  fail "invalid RAM was accepted"
fi

menu_help_output=$(printf '9\nq\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$menu_help_output" "Usage: ravnvm [OPTIONS] [BRANCH/COMMIT]"
assert_contains "$menu_help_output" "VM_MEMORY=4G"
assert_contains "$menu_help_output" "VM_QEMU_OVERRIDE"
assert_contains "$menu_help_output" "RAVN_REPO"

ssh_menu_output=$(printf '10\n\nq\n' | "$RAVNVM_SCRIPT")
assert_contains "$ssh_menu_output" "Connect to VM via SSH"

rm -f "$FAKE_BIN/ssh"
ln -s /usr/bin/false "$FAKE_BIN/ssh"
ssh_failure_output=$(printf '10\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$ssh_failure_output" "Unable to connect to the running VM"
rm -f "$FAKE_BIN/ssh"
ln -s /usr/bin/true "$FAKE_BIN/ssh"

cat > "$FAKE_BIN/find" << 'FAKE_FIND'
#!/usr/bin/env bash
exit 1
FAKE_FIND
chmod +x "$FAKE_BIN/find"
cleanup_failure_output=$(printf '6\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$cleanup_failure_output" "Unable to clean RavnVM cache"
if grep -Fq "Cache cleaned" <<< "$cleanup_failure_output"; then
  fail "failed cleanup was reported as successful"
fi
rm -f "$FAKE_BIN/find"

readonly_cache="$FIXTURE_DIR/readonly-cache"
mkdir -p "$readonly_cache/ravnvm/snapshots"
chmod 500 "$readonly_cache/ravnvm" "$readonly_cache/ravnvm/snapshots"
unwritable_output=$(XDG_CACHE_HOME="$readonly_cache" printf 'q\n' | XDG_CACHE_HOME="$readonly_cache" "$RAVNVM_SCRIPT" 2>&1)
chmod 700 "$readonly_cache/ravnvm" "$readonly_cache/ravnvm/snapshots"
assert_contains "$unwritable_output" "cache directory is not writable"
if grep -Fq "Choose an action" <<< "$unwritable_output"; then
  fail "unwritable cache opened the normal menu"
fi

cat > "$FAKE_BIN/df" << 'FAKE_DF'
#!/usr/bin/env bash
printf 'Filesystem 1-blocks Used Available Use%% Mounted on\n'
printf 'fixture 100 85 15 85%% /\n'
FAKE_DF
chmod +x "$FAKE_BIN/df"
storage_warning_output=$(printf '5\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$storage_warning_output" "High usage"
assert_contains "$storage_warning_output" "Storage usage is high"
rm -f "$FAKE_BIN/df"

interrupt_output="$FIXTURE_DIR/interrupt.out"
if timeout --foreground --preserve-status --signal=INT 0.5 \
  "$RAVNVM_SCRIPT" < <(sleep 5) > "$interrupt_output" 2>&1; then
  fail "Ctrl-C returned success"
else
  interrupt_status=$?
fi
[[ $interrupt_status -eq 130 ]] || fail "Ctrl-C returned $interrupt_status instead of 130"
assert_contains "$(< "$interrupt_output")" "RavnVM interrupted"

rm -f "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
for command_name in env bash clear awk df du find sed basename mktemp mkdir rm grep cat git curl; do
  ln -sf "$(command -v "$command_name")" "$FAKE_BIN/$command_name"
done
recovery_output=$(PATH="$FAKE_BIN" printf 'q\n' | PATH="$FAKE_BIN" "$RAVNVM_SCRIPT")
assert_contains "$recovery_output" "Required dependencies missing"
assert_contains "$recovery_output" "Install dependencies"
if grep -Fq "Choose an action" <<< "$recovery_output"; then
    fail "dependency recovery opened the normal menu"
fi

printf 'PASS: RavnVM interaction surfaces\n'
