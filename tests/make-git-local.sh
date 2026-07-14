#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/make-git-local.XXXXXX")"
REPO_DIR="$FIXTURE_DIR/repo"
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

mkdir -p "$REPO_DIR" "$FAKE_BIN"
git -C "$REPO_DIR" init -q -b topic
git -C "$REPO_DIR" config user.name 'RavnVM Test'
git -C "$REPO_DIR" config user.email 'ravnvm@example.test'
git -C "$REPO_DIR" config core.hooksPath /dev/null

printf 'include %s/make/git.mk\n' "$ROOT_DIR" > "$REPO_DIR/Makefile"
printf 'Makefile\n' >> "$REPO_DIR/.git/info/exclude"
printf 'initial\n' > "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
git -C "$REPO_DIR" commit -q -m 'test: initial state'

printf 'stage me\n' > "$REPO_DIR/staged.txt"
make -s -C "$REPO_DIR" git-add > /dev/null
git -C "$REPO_DIR" diff --cached --quiet -- staged.txt && fail 'git-add did not stage the new file'

make -s -C "$REPO_DIR" git-commit > /dev/null
assert_contains "$(git -C "$REPO_DIR" log -1 --format=%B)" 'Signed-off-by: RavnVM Test <ravnvm@example.test>'

printf 'custom\n' >> "$REPO_DIR/tracked.txt"
make -s -C "$REPO_DIR" git-cm MSG='feat: preserve custom message' > /dev/null
[[ $(git -C "$REPO_DIR" log -1 --format=%s) == 'feat: preserve custom message' ]] || fail 'git-cm changed the custom message'

printf 'combined\n' > "$REPO_DIR/combined.txt"
make -s -C "$REPO_DIR" git-add-commit > /dev/null
git -C "$REPO_DIR" show --quiet --format=%B HEAD | grep -Fq 'Signed-off-by:' || fail 'git-add-commit omitted the signoff'
git -C "$REPO_DIR" ls-files --error-unmatch combined.txt > /dev/null || fail 'git-add-commit did not commit the new file'

printf 'amended\n' >> "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
commit_count=$(git -C "$REPO_DIR" rev-list --count HEAD)
make -s -C "$REPO_DIR" git-amend MSG='test: amended snapshot' > /dev/null
[[ $(git -C "$REPO_DIR" rev-list --count HEAD) == "$commit_count" ]] || fail 'git-amend created an additional commit'
[[ $(git -C "$REPO_DIR" log -1 --format=%s) == 'test: amended snapshot' ]] || fail 'git-amend did not update the message'

printf '#!/usr/bin/env bash\nhead -n 1\n' > "$FAKE_BIN/fzf"
chmod +x "$FAKE_BIN/fzf"
printf 'fuzzy\n' > "$REPO_DIR/fuzzy.txt"
PATH="$FAKE_BIN:$PATH" make -s -C "$REPO_DIR" git-add-fuzzy > /dev/null
git -C "$REPO_DIR" diff --cached --quiet -- fuzzy.txt && fail 'git-add-fuzzy did not stage the selected file'
git -C "$REPO_DIR" reset -q

printf 'dry run\n' > "$REPO_DIR/dry-run.txt"
before_status=$(git -C "$REPO_DIR" status --porcelain)
before_head=$(git -C "$REPO_DIR" rev-parse HEAD)
make -s -C "$REPO_DIR" DRY_RUN=1 git-add git-cm MSG='test: dry run' git-amend > /dev/null
[[ $(git -C "$REPO_DIR" status --porcelain) == "$before_status" ]] || fail 'dry-run changed the index or working tree'
[[ $(git -C "$REPO_DIR" rev-parse HEAD) == "$before_head" ]] || fail 'dry-run changed commit history'

rm "$REPO_DIR/dry-run.txt" "$REPO_DIR/fuzzy.txt"
clean_output=$(make -s -C "$REPO_DIR" git-commit)
assert_contains "$clean_output" 'nothing to commit'

printf 'PASS: Git Make local stage and commit cycle\n'
