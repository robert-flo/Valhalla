#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-session-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"
QEMU_PID_FILE="$FIXTURE_DIR/qemu.pid"
QEMU_RUNNING_DIRECTORY="$FIXTURE_DIR/qemu-running"

cleanup() {
  if [[ -f $QEMU_PID_FILE ]]; then
    local qemu_pid=""
    qemu_pid=$(< "$QEMU_PID_FILE")
    kill "$qemu_pid" 2> /dev/null || true
  fi
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

mkdir -p "$FAKE_BIN" "$FIXTURE_DIR/cache/ravnvm/snapshots"
touch "$FIXTURE_DIR/cache/ravnvm/archbase.qcow2"
touch "$FIXTURE_DIR/cache/ravnvm/snapshots/ravn-dev.qcow2"

for command_name in curl git pacman python python3 scp ssh; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done

cat > "$FAKE_BIN/qemu-img" << 'FAKE_QEMU_IMG'
#!/usr/bin/env bash
touch "${@: -1}"
FAKE_QEMU_IMG

cat > "$FAKE_BIN/qemu-system-x86_64" << 'FAKE_QEMU'
#!/usr/bin/env bash

if [[ ${RAVNVM_QEMU_EXIT_IMMEDIATELY:-false} == "true" ]]; then
  exit 0
fi

if ! mkdir "$RAVNVM_QEMU_RUNNING_DIRECTORY" 2> /dev/null; then
  exit 0
fi

handle_exit() {
  rmdir "$RAVNVM_QEMU_RUNNING_DIRECTORY" 2> /dev/null || true
  exit 0
}

trap handle_exit INT TERM
printf '%s\n' "$$" > "$RAVNVM_QEMU_PID_FILE"
while true; do
  sleep 1
done
FAKE_QEMU

chmod +x "$FAKE_BIN/qemu-img" "$FAKE_BIN/qemu-system-x86_64"

export PATH="$FAKE_BIN:$PATH"
export RAVNVM_QEMU_PID_FILE="$QEMU_PID_FILE"
export RAVNVM_QEMU_RUNNING_DIRECTORY="$QEMU_RUNNING_DIRECTORY"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

"$RAVNVM_SCRIPT" dev > "$FIXTURE_DIR/first.output" 2>&1 &
first_ravnvm_pid=$!

for _ in {1..100}; do
  [[ -f $QEMU_PID_FILE ]] && break
  sleep 0.05
done
[[ -f $QEMU_PID_FILE ]] || fail "first RavnVM session did not start"

set +e
second_output=$("$RAVNVM_SCRIPT" dev 2>&1)
second_status=$?
set -e

[[ $second_status -ne 0 ]] || fail "second RavnVM session returned success"
assert_contains "$second_output" "Another RavnVM session is already active; close it before starting a new VM"

list_output=$("$RAVNVM_SCRIPT" --list)
assert_contains "$list_output" "Available RaVN snapshots"

"$RAVNVM_SCRIPT" --clean > "$FIXTURE_DIR/clean.output"
touch "$FIXTURE_DIR/cache/ravnvm/snapshots/ravn-dev.qcow2"
set +e
after_clean_output=$("$RAVNVM_SCRIPT" dev 2>&1)
after_clean_status=$?
set -e
[[ $after_clean_status -ne 0 ]] || fail "cache cleanup removed the active session lock"
assert_contains "$after_clean_output" "Another RavnVM session is already active; close it before starting a new VM"

qemu_pid=$(< "$QEMU_PID_FILE")
kill -TERM "$qemu_pid"
wait "$first_ravnvm_pid"

RAVNVM_QEMU_EXIT_IMMEDIATELY=true "$RAVNVM_SCRIPT" dev > "$FIXTURE_DIR/third.output" 2>&1

printf 'PASS: RavnVM single active session\n'
