#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-interrupt-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"
QEMU_PID_FILE="$FIXTURE_DIR/qemu.pid"
QEMU_TERMINATED_FILE="$FIXTURE_DIR/qemu.terminated"

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

mkdir -p "$FAKE_BIN" "$FIXTURE_DIR/cache/ravnvm/snapshots"
touch "$FIXTURE_DIR/cache/ravnvm/archbase.qcow2"

for command_name in curl git pacman python python3 scp ssh; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done

cat > "$FAKE_BIN/ssh-keyscan" << 'FAKE_SSH_KEYSCAN'
#!/usr/bin/env bash
printf '127.0.0.1 ssh-ed25519 fixture-key\n'
FAKE_SSH_KEYSCAN

cat > "$FAKE_BIN/qemu-img" << 'FAKE_QEMU_IMG'
#!/usr/bin/env bash
touch "${@: -1}"
FAKE_QEMU_IMG

cat > "$FAKE_BIN/qemu-system-x86_64" << 'FAKE_QEMU'
#!/usr/bin/env bash

handle_interrupt() {
  touch "$RAVNVM_QEMU_TERMINATED_FILE"
  exit 0
}

trap handle_interrupt INT TERM
printf '%s\n' "$$" > "$RAVNVM_QEMU_PID_FILE"
if [[ ${RAVNVM_QEMU_EXIT_IMMEDIATELY:-false} == "true" ]]; then
  exit 0
fi
while true; do
  sleep 1
done
FAKE_QEMU

chmod +x "$FAKE_BIN/qemu-img" "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/ssh-keyscan"

export PATH="$FAKE_BIN:$PATH"
export RAVNVM_QEMU_PID_FILE="$QEMU_PID_FILE"
export RAVNVM_QEMU_TERMINATED_FILE="$QEMU_TERMINATED_FILE"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

"$RAVNVM_SCRIPT" dev > "$FIXTURE_DIR/ravnvm.output" 2>&1 &
ravnvm_pid=$!

for _ in {1..100}; do
  [[ -f $QEMU_PID_FILE ]] && break
  sleep 0.05
done

[[ -f $QEMU_PID_FILE ]] || fail "setup QEMU did not start"
[[ -f $XDG_CACHE_HOME/ravnvm/temp-setup.qcow2 ]] || fail "temporary setup disk was not created"
[[ -f $XDG_CACHE_HOME/ravnvm/setup.sh ]] || fail "temporary setup script was not created"

kill -TERM "$ravnvm_pid"
set +e
wait "$ravnvm_pid"
ravnvm_status=$?
set -e

[[ $ravnvm_status -eq 130 ]] || fail "RavnVM exited with $ravnvm_status instead of 130"
[[ -f $QEMU_TERMINATED_FILE ]] || fail "setup QEMU was not terminated"
[[ ! -e $XDG_CACHE_HOME/ravnvm/temp-setup.qcow2 ]] || fail "temporary setup disk was retained"
[[ ! -e $XDG_CACHE_HOME/ravnvm/setup.sh ]] || fail "temporary setup script was retained"
[[ -f $XDG_CACHE_HOME/ravnvm/archbase.qcow2 ]] || fail "cached base image was removed"

rm -f "$QEMU_PID_FILE" "$QEMU_TERMINATED_FILE"
touch "$XDG_CACHE_HOME/ravnvm/snapshots/ravn-dev.qcow2"
export RAVNVM_QEMU_EXIT_IMMEDIATELY=true
"$RAVNVM_SCRIPT" dev > "$FIXTURE_DIR/ephemeral.output" 2>&1

if find "$XDG_CACHE_HOME/ravnvm" -maxdepth 1 -name 'overlay.*.qcow2' -print -quit | grep -q .; then
  fail "ephemeral overlay was retained after QEMU exited"
fi

printf 'PASS: RavnVM interruption cleanup\n'
