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
for command_name in pacman qemu-system-x86_64 curl git ssh scp; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done
touch "$FAKE_BIN/qemu-img" "$FAKE_BIN/ssh-keyscan"
chmod +x "$FAKE_BIN/qemu-img" "$FAKE_BIN/ssh-keyscan"
export PATH="$FAKE_BIN:$PATH"

cat > "$FAKE_BIN/qemu-img" << 'FAKE_QEMU_IMG'
#!/usr/bin/env bash
touch "${@: -1}"
FAKE_QEMU_IMG

cat > "$FAKE_BIN/ssh-keyscan" << 'FAKE_SSH_KEYSCAN'
#!/usr/bin/env bash
printf '127.0.0.1 ssh-rsa test-key\n'
FAKE_SSH_KEYSCAN
mkdir -p "$XDG_CACHE_HOME/ravnvm/snapshots"
touch "$XDG_CACHE_HOME/ravnvm/archbase.qcow2"
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2"

clean_output=$("$RAVNVM_SCRIPT" --clean)
assert_contains "$clean_output" "base image preserved"
[[ -f "$XDG_CACHE_HOME/ravnvm/archbase.qcow2" ]] || fail "cleanup removed the base image"
[[ ! -e "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2" ]] || fail "cleanup retained a snapshot"

touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-master-fc613b4dfd67.qcow2"
default_output=$(VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" master 2>&1)
assert_contains "$default_output" "Starting RaVN VM (branch/commit: master)"

help_output=$("$RAVNVM_SCRIPT" --help)
assert_contains "$help_output" "Usage: ravnvm [OPTIONS] [BRANCH/COMMIT]"

list_output=$("$RAVNVM_SCRIPT" --list)
assert_contains "$list_output" "master"

storage_output=$("$RAVNVM_SCRIPT" --storage)
assert_contains "$storage_output" "VM cache:"
assert_contains "$storage_output" "Disk:"

touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev-ef260e9aa3c6.qcow2"
ephemeral_output=$(VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" dev 2>&1)
assert_contains "$ephemeral_output" "non-persistent mode"
assert_contains "$ephemeral_output" "branch/commit: dev"

persistent_output=$(VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" --persist dev 2>&1)
assert_contains "$persistent_output" "persistent mode"
assert_contains "$persistent_output" "branch/commit: dev"

if VM_QEMU_OVERRIDE=true "$RAVNVM_SCRIPT" master dev > /dev/null 2>&1; then
  fail "multiple revisions were accepted"
fi

printf 'y\n' | VM_QEMU_OVERRIDE='sleep 0.2' "$RAVNVM_SCRIPT" 'feature/a' > /dev/null 2>&1
printf 'y\n' | VM_QEMU_OVERRIDE='sleep 0.2' "$RAVNVM_SCRIPT" 'feature_a' > /dev/null 2>&1
snapshot_count=$(find "$XDG_CACHE_HOME/ravnvm/snapshots" -name 'ravn-feature*' -type f | wc -l)
[[ $snapshot_count -eq 2 ]] || fail "distinct revisions shared one snapshot"

if printf 'n\n' | VM_QEMU_OVERRIDE='sleep 0.2' "$RAVNVM_SCRIPT" incomplete > /dev/null 2>&1; then
  fail "an unconfirmed setup was cached"
fi
if find "$XDG_CACHE_HOME/ravnvm/snapshots" -name 'ravn-incomplete-*' -type f | grep -q .; then
  fail "an unconfirmed setup left a revision snapshot"
fi
if find "$XDG_CACHE_HOME/ravnvm" -maxdepth 1 \( -name 'setup.*' -o -name 'overlay.*' -o -name '*.part' \) | grep -q .; then
  fail "a failed setup left temporary cache data"
fi

qemu_pid_file="$FIXTURE_DIR/qemu.pid"
interrupt_output="$FIXTURE_DIR/interrupt.out"
VM_QEMU_OVERRIDE="printf '%s\\n' \$\$ > '$qemu_pid_file'; exec sleep 30" \
  "$RAVNVM_SCRIPT" interrupted < /dev/null > "$interrupt_output" 2>&1 &
ravnvm_pid=$!
for _ in {1..50}; do
  [[ -s $qemu_pid_file ]] && break
  sleep 0.1
done
[[ -s $qemu_pid_file ]] || fail "the setup QEMU PID was not observable"
qemu_pid=$(< "$qemu_pid_file")
kill -TERM "$ravnvm_pid"
wait "$ravnvm_pid" 2> /dev/null || true
if kill -0 "$qemu_pid" 2> /dev/null; then
  kill "$qemu_pid" 2> /dev/null || true
  fail "interrupt left the setup QEMU process running"
fi

printf 'PASS: RavnVM direct CLI\n'
