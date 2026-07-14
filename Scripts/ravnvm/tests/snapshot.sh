#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-snapshot-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"
SNAPSHOT_PATH="$FIXTURE_DIR/cache/ravnvm/snapshots/ravn-dev.qcow2"

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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if grep -Fq "$needle" <<< "$haystack"; then
    fail "expected output not to contain: $needle"
  fi
}

mkdir -p "$FAKE_BIN" "$FIXTURE_DIR/cache/ravnvm/snapshots"
touch "$FIXTURE_DIR/cache/ravnvm/archbase.qcow2"

for command_name in curl git pacman python python3 scp ssh; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done

cat > "$FAKE_BIN/ssh-keyscan" << 'FAKE_SSH_KEYSCAN'
#!/usr/bin/env bash
printf '127.0.0.1 ssh-ed25519 fixture-key\n'
FAKE_SSH_KEYSCAN

cat > "$FAKE_BIN/qemu-system-x86_64" << 'FAKE_QEMU'
#!/usr/bin/env bash
exit 0
FAKE_QEMU

cat > "$FAKE_BIN/qemu-img" << 'FAKE_QEMU_IMG'
#!/usr/bin/env bash

output_path="${@: -1}"
touch "$output_path"
if [[ $1 == "convert" && ${RAVNVM_FAIL_CONVERSION:-false} == "true" ]]; then
  exit 1
fi
FAKE_QEMU_IMG

chmod +x "$FAKE_BIN/qemu-img" "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/ssh-keyscan"

export PATH="$FAKE_BIN:$PATH"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

set +e
declined_output=$(printf 'n\n' | "$RAVNVM_SCRIPT" dev 2>&1)
declined_status=$?
set -e

[[ $declined_status -ne 0 ]] || fail "declined setup returned success"
assert_contains "$declined_output" "Setup was not confirmed; no snapshot was cached"
[[ ! -e $SNAPSHOT_PATH ]] || fail "declined setup cached a snapshot"
[[ ! -e $XDG_CACHE_HOME/ravnvm/temp-setup.qcow2 ]] || fail "declined setup retained its temporary disk"
[[ ! -e $XDG_CACHE_HOME/ravnvm/setup.sh ]] || fail "declined setup retained its setup script"

interactive_output=$(printf '1\n2\nn\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$interactive_output" "Setup was not confirmed; no snapshot was cached"
assert_not_contains "$interactive_output" "Running in persistent mode"
assert_not_contains "$interactive_output" "Starting RaVN VM"

export RAVNVM_FAIL_CONVERSION=true
set +e
failed_output=$(printf 'y\n' | "$RAVNVM_SCRIPT" dev 2>&1)
failed_status=$?
set -e

[[ $failed_status -ne 0 ]] || fail "failed conversion returned success"
assert_contains "$failed_output" "Unable to create the revision snapshot"
[[ ! -e $SNAPSHOT_PATH ]] || fail "failed conversion retained a partial snapshot"
[[ ! -e $XDG_CACHE_HOME/ravnvm/temp-setup.qcow2 ]] || fail "failed conversion retained its temporary disk"
[[ ! -e $XDG_CACHE_HOME/ravnvm/setup.sh ]] || fail "failed conversion retained its setup script"
[[ -f $XDG_CACHE_HOME/ravnvm/archbase.qcow2 ]] || fail "snapshot failure removed the cached base image"

printf 'PASS: RavnVM snapshot confirmation\n'
