#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLICATIONS_DIR="${SCRIPT_DIR}/../Scripts/applications"
INSTALLER="${SCRIPT_DIR}/../Scripts/install_ravn.sh"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ravn-applications-test.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

FAKE_BIN="$FIXTURE_DIR/bin"
PACKAGE_STATE="$FIXTURE_DIR/packages"
export PACKAGE_STATE
mkdir -p "$FAKE_BIN"
printf 'ncdu\n' > "$PACKAGE_STATE"
cat > "$FAKE_BIN/pacman" << 'FAKE_PACMAN'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$1" in
-Q) grep -Fxq "$2" "$PACKAGE_STATE" ;;
-Si) grep -Fxq "$2" <(printf 'ncdu\ndua-cli\nlibqalculate\ngum\n') ;;
-S)
  shift
  for arg in "$@"; do [[ $arg == -* ]] || printf '%s\n' "$arg" >>"$PACKAGE_STATE"; done
  ;;
-R)
  shift
  for arg in "$@"; do [[ $arg == -* ]] || sed -i "\\|^${arg}$|d" "$PACKAGE_STATE"; done
  ;;
*) exit 2 ;;
esac
FAKE_PACMAN
cat > "$FAKE_BIN/sudo" << 'FAKE_SUDO'
#!/usr/bin/env bash
exec "$@"
FAKE_SUDO
chmod +x "$FAKE_BIN/pacman" "$FAKE_BIN/sudo"

export PATH="$FAKE_BIN:$PATH"
export HOME="$FIXTURE_DIR/home"
export XDG_STATE_HOME="$FIXTURE_DIR/state"
mkdir -p "$HOME"

NO_COLOR=1 bash "$APPLICATIONS_DIR/manage_applications.sh" --test > "$FIXTURE_DIR/test.out"
grep -Fq 'Candidate: dua-cli' "$FIXTURE_DIR/test.out" || fail "test did not report a candidate"
grep -Fq 'Skipping installed package: ncdu' "$FIXTURE_DIR/test.out" || fail "test did not skip installed package"
NO_COLOR=1 bash "$APPLICATIONS_DIR/manage_applications.sh" --dry-run > "$FIXTURE_DIR/dry-run.out"
grep -Fq 'Dry run: no packages were installed' "$FIXTURE_DIR/dry-run.out" || fail "dry-run reported installation"

bash "$APPLICATIONS_DIR/manage_applications.sh" --install > "$FIXTURE_DIR/install.out"
[[ $(grep -c '^' "$PACKAGE_STATE") -eq 4 ]] || fail "install did not record explicit packages"
run_file=$(find "$XDG_STATE_HOME" -name '*.installed' -print -quit)
[[ -f $run_file ]] || fail "installation run record was not created"
bash "$APPLICATIONS_DIR/manage_applications.sh" --rollback "$run_file"
[[ $(grep -c '^' "$PACKAGE_STATE") -eq 1 ]] || fail "rollback changed the wrong packages"
grep -Fxq ncdu "$PACKAGE_STATE" || fail "rollback removed a preexisting package"

NO_COLOR=1 bash "$INSTALLER" applications > "$FIXTURE_DIR/dispatch.out"
grep -Fq 'Recorded' "$FIXTURE_DIR/dispatch.out" || fail "main installer did not dispatch Applications"
echo "PASS: conservative RaVN applications lifecycle"
