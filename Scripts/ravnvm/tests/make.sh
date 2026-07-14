#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-make-test.XXXXXX")"
FAKE_RAVNVM="$FIXTURE_DIR/ravnvm"
FAKE_GIT="$FIXTURE_DIR/git"
CALL_LOG="$FIXTURE_DIR/calls.log"

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

cat > "$FAKE_RAVNVM" << 'FAKE_RAVNVM_SCRIPT'
#!/usr/bin/env bash
printf 'memory=%s cpus=%s extra=%s qemu=%s args=%s\n' \
  "${VM_MEMORY:-}" "${VM_CPUS:-}" "${VM_EXTRA_ARGS:-}" "${VM_QEMU_OVERRIDE:-}" "$*" >> "$CALL_LOG"
[[ ${1:-} != --check-deps ]]
FAKE_RAVNVM_SCRIPT
chmod +x "$FAKE_RAVNVM"
export CALL_LOG

help_output=$(make -s -C "$ROOT_DIR" help)
for target in dev-vm dev-vm-persist dev-vm-list dev-vm-clean dev-vm-setup dev-vm-storage dev-vm-size dev-vm-ssh; do
  assert_contains "$help_output" "$target"
done

make -s -C "$ROOT_DIR" dev-vm RAVNVM="$FAKE_RAVNVM" REF=feature/test \
  VM_MEMORY=8G VM_CPUS=4 VM_EXTRA_ARGS=-nographic VM_QEMU_OVERRIDE=custom-qemu
assert_contains "$(< "$CALL_LOG")" "memory=8G cpus=4 extra=-nographic qemu=custom-qemu args=feature/test"

dollar='$'
vm_disk_override="qemu -drive file=${dollar}VM_DISK"
make -s -C "$ROOT_DIR" dev-vm RAVNVM="$FAKE_RAVNVM" REF=placeholder \
  VM_QEMU_OVERRIDE="$vm_disk_override"
assert_contains "$(< "$CALL_LOG")" "qemu=$vm_disk_override args=placeholder"

make -s -C "$ROOT_DIR" dev-vm-persist RAVNVM="$FAKE_RAVNVM" REF=dev
assert_contains "$(< "$CALL_LOG")" "args=--persist dev"

cat > "$FAKE_GIT" << 'FAKE_GIT_SCRIPT'
#!/usr/bin/env bash
if [[ ${1:-} == branch ]]; then
  exit 0
fi
printf 'deadbeef\n'
FAKE_GIT_SCRIPT
chmod +x "$FAKE_GIT"
make -s -C "$ROOT_DIR" dev-vm RAVNVM="$FAKE_RAVNVM" GIT="$FAKE_GIT"
assert_contains "$(< "$CALL_LOG")" "args=deadbeef"

declare -A target_options=(
     ["dev-vm-list"]=--list
    ["dev-vm-clean"]=--clean
    ["dev-vm-storage"]=--storage
    ["dev-vm-size"]=--storage
     ["dev-vm-ssh"]=--ssh
)
for target in "${!target_options[@]}"; do
  make -s -C "$ROOT_DIR" "$target" RAVNVM="$FAKE_RAVNVM"
  assert_contains "$(< "$CALL_LOG")" "args=${target_options[$target]}"
done

make -s -C "$ROOT_DIR" dev-vm-setup RAVNVM="$FAKE_RAVNVM"
assert_contains "$(< "$CALL_LOG")" "args=--check-deps"
assert_contains "$(< "$CALL_LOG")" "args=--install-deps"

: > "$CALL_LOG"
dry_run_output=$(make -s -C "$ROOT_DIR" dev-vm dev-vm-clean dev-vm-setup \
  RAVNVM="$FAKE_RAVNVM" REF=preview DRY_RUN=1 VM_MEMORY=8G VM_CPUS=4 \
  VM_EXTRA_ARGS=-nographic VM_QEMU_OVERRIDE="$vm_disk_override")
assert_contains "$dry_run_output" "$FAKE_RAVNVM preview"
assert_contains "$dry_run_output" "VM_MEMORY='8G'"
assert_contains "$dry_run_output" "VM_CPUS='4'"
assert_contains "$dry_run_output" "VM_EXTRA_ARGS='-nographic'"
assert_contains "$dry_run_output" "VM_QEMU_OVERRIDE='$vm_disk_override'"
assert_contains "$dry_run_output" "$FAKE_RAVNVM --clean"
assert_contains "$dry_run_output" "$FAKE_RAVNVM --check-deps"
assert_contains "$dry_run_output" "$FAKE_RAVNVM --install-deps"
[[ ! -s $CALL_LOG ]] || fail "DRY_RUN executed RavnVM"

printf 'PASS: RavnVM Make interface\n'
