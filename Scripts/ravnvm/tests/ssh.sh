#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-ssh-test.XXXXXX")"
SSH_CONFIG="$FIXTURE_DIR/home/.ssh/config"
FAKE_BIN="$FIXTURE_DIR/bin"
QEMU_TERMINATED_FILE="$FIXTURE_DIR/qemu.terminated"

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

mkdir -p "$FIXTURE_DIR/home"
printf 'Host existing-host\n    HostName example.com\n' > "$FIXTURE_DIR/existing-config"
mkdir -p "$(dirname "$SSH_CONFIG")"
cp "$FIXTURE_DIR/existing-config" "$SSH_CONFIG"

HOME="$FIXTURE_DIR/home" XDG_CACHE_HOME="$FIXTURE_DIR/cache" "$RAVNVM_SCRIPT" --install-ssh-alias
first_checksum=$(sha256sum "$SSH_CONFIG")
HOME="$FIXTURE_DIR/home" XDG_CACHE_HOME="$FIXTURE_DIR/cache" "$RAVNVM_SCRIPT" --install-ssh-alias
second_checksum=$(sha256sum "$SSH_CONFIG")

[[ $first_checksum == "$second_checksum" ]] || fail "SSH alias installation was not idempotent"
grep -Fq 'Host existing-host' "$SSH_CONFIG" || fail "existing SSH configuration was removed"

resolved_config=$(ssh -F "$SSH_CONFIG" -G ravnvm 2> /dev/null)
grep -Fqx 'hostname 127.0.0.1' <<< "$resolved_config" || fail "ravnvm hostname was not configured"
grep -Fqx 'user arch' <<< "$resolved_config" || fail "ravnvm user was not configured"
grep -Fqx 'port 2222' <<< "$resolved_config" || fail "ravnvm port was not configured"

mkdir -p "$FAKE_BIN" "$FIXTURE_DIR/cache/ravnvm/snapshots"
touch "$FIXTURE_DIR/cache/ravnvm/archbase.qcow2"

for command_name in curl git pacman python python3 scp ssh; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done

cat > "$FAKE_BIN/ssh-keyscan" << 'FAKE_SSH_KEYSCAN'
#!/usr/bin/env bash
exit 1
FAKE_SSH_KEYSCAN

cat > "$FAKE_BIN/qemu-img" << 'FAKE_QEMU_IMG'
#!/usr/bin/env bash
touch "${@: -1}"
FAKE_QEMU_IMG

cat > "$FAKE_BIN/qemu-system-x86_64" << 'FAKE_QEMU'
#!/usr/bin/env bash

if [[ ${RAVNVM_QEMU_MODE:-exit} == "exit" ]]; then
  exit 0
fi

handle_interrupt() {
  touch "$RAVNVM_QEMU_TERMINATED_FILE"
  exit 0
}

trap handle_interrupt INT TERM
while true; do
  sleep 1
done
FAKE_QEMU

chmod +x "$FAKE_BIN/qemu-img" "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/ssh-keyscan"

export PATH="$FAKE_BIN:$PATH"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

set +e
stopped_output=$(RAVNVM_QEMU_MODE=exit RAVNVM_SSH_READY_TIMEOUT=5 "$RAVNVM_SCRIPT" dev 2>&1)
stopped_status=$?
set -e

[[ $stopped_status -ne 0 ]] || fail "stopped setup VM returned success"
assert_contains "$stopped_output" "The setup VM stopped before SSH became available"
[[ ! -e $XDG_CACHE_HOME/ravnvm/temp-setup.qcow2 ]] || fail "stopped setup VM retained its temporary disk"
[[ ! -e $XDG_CACHE_HOME/ravnvm/setup.sh ]] || fail "stopped setup VM retained its setup script"

export RAVNVM_QEMU_TERMINATED_FILE="$QEMU_TERMINATED_FILE"
set +e
timeout_output=$(RAVNVM_QEMU_MODE=wait RAVNVM_SSH_READY_TIMEOUT=0 "$RAVNVM_SCRIPT" dev 2>&1)
timeout_status=$?
set -e

[[ $timeout_status -ne 0 ]] || fail "SSH timeout returned success"
assert_contains "$timeout_output" "Timed out waiting for the setup VM SSH server"
[[ -f $QEMU_TERMINATED_FILE ]] || fail "SSH timeout did not terminate the setup VM"
[[ ! -e $XDG_CACHE_HOME/ravnvm/temp-setup.qcow2 ]] || fail "SSH timeout retained its temporary disk"
[[ ! -e $XDG_CACHE_HOME/ravnvm/setup.sh ]] || fail "SSH timeout retained its setup script"

rm -f "$FAKE_BIN/ssh"
cat > "$FAKE_BIN/ssh" << 'FAKE_SSH'
#!/usr/bin/env bash
exit 255
FAKE_SSH
chmod +x "$FAKE_BIN/ssh"

disconnect_output=$(printf '10\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$disconnect_output" "SSH session ended; the VM may have stopped or become unavailable"
assert_not_contains "$disconnect_output" "Unable to connect to the running VM"

alias_menu_output=$(HOME="$FIXTURE_DIR/home" printf '11\n\nq\n' | HOME="$FIXTURE_DIR/home" "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$alias_menu_output" "SSH alias installed; connect with: ssh ravnvm"

make_output=$(make -s DRY_RUN=1 dev-vm-install-ssh-alias)
assert_contains "$make_output" "ravnvm.sh --install-ssh-alias"

set +e
default_make_output=$(HOME="$FIXTURE_DIR/home" make -s dev-vm-install-ssh-alias 2>&1)
default_make_status=$?
set -e
[[ $default_make_status -eq 0 ]] || fail "default Make target failed: $default_make_output"
assert_contains "$default_make_output" "SSH alias installed; connect with: ssh ravnvm"

printf 'PASS: RavnVM SSH behavior\n'
