#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RAVNVM_SCRIPT="$SCRIPT_DIR/ravnvm.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravnvm-download-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"
BASE_IMAGE="$FIXTURE_DIR/cache/ravnvm/archbase.qcow2"

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

for command_name in git pacman python python3 scp ssh; do
  ln -s /usr/bin/true "$FAKE_BIN/$command_name"
done

cat > "$FAKE_BIN/curl" << 'FAKE_CURL'
#!/usr/bin/env bash

output_path=""
while (($#)); do
  if [[ $1 == "-o" ]]; then
    output_path="$2"
    break
  fi
  shift
done

[[ -n $output_path ]] || exit 2
if [[ ${RAVNVM_FAIL_DOWNLOAD:-false} == "true" ]]; then
  printf 'partial-image' > "$output_path"
  exit 22
fi

printf 'complete-image' > "$output_path"
FAKE_CURL

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
touch "${@: -1}"
FAKE_QEMU_IMG

chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/qemu-img" "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/ssh-keyscan"

export PATH="$FAKE_BIN:$PATH"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"
export RAVNVM_FAIL_DOWNLOAD=true

failed_output=$(printf '1\n1\n\nq\n' | "$RAVNVM_SCRIPT" 2>&1)
assert_contains "$failed_output" "Unable to download the Arch Linux base image"
if grep -Fq "Creating RaVN snapshot" <<< "$failed_output"; then
  fail "failed download continued to snapshot creation"
fi
[[ ! -e $BASE_IMAGE ]] || fail "failed download was promoted to the base image"
[[ ! -e ${BASE_IMAGE}.part ]] || fail "failed download retained its partial image"

unset RAVNVM_FAIL_DOWNLOAD
set +e
successful_output=$(printf 'n\n' | "$RAVNVM_SCRIPT" dev 2>&1)
successful_status=$?
set -e

[[ $successful_status -ne 0 ]] || fail "declined setup unexpectedly returned success"
assert_contains "$successful_output" "Base image downloaded successfully"
[[ $(< "$BASE_IMAGE") == "complete-image" ]] || fail "completed download was not promoted"
[[ ! -e ${BASE_IMAGE}.part ]] || fail "completed download retained its partial image"

printf 'PASS: RavnVM atomic base download\n'
