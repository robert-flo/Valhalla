#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/make-git-worktrees.XXXXXX")"
REMOTE_DIR="$FIXTURE_DIR/remote.git"
SEED_DIR="$FIXTURE_DIR/seed"
BARE_DIR="$FIXTURE_DIR/bare.git"
WORKTREES_HOME="$FIXTURE_DIR/worktrees"
REPO_DIR="$WORKTREES_HOME/demo"
FAKE_BIN="$FIXTURE_DIR/bin"
SETUP_LOG="$FIXTURE_DIR/setup.log"

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

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

git init -q --bare "$REMOTE_DIR"
git init -q -b master "$SEED_DIR"
git -C "$SEED_DIR" config user.name 'RavnVM Test'
git -C "$SEED_DIR" config user.email 'ravnvm@example.test'
git -C "$SEED_DIR" config core.hooksPath /dev/null
git -C "$SEED_DIR" remote add origin "$REMOTE_DIR"
printf 'initial\n' > "$SEED_DIR/tracked.txt"
git -C "$SEED_DIR" add tracked.txt
git -C "$SEED_DIR" commit -q -m 'test: initial state'
git -C "$SEED_DIR" push -q -u origin master

git -C "$SEED_DIR" switch -q -c topic
printf 'topic\n' > "$SEED_DIR/topic.txt"
git -C "$SEED_DIR" add topic.txt
git -C "$SEED_DIR" commit -q -m 'test: topic change'
git -C "$SEED_DIR" push -q -u origin topic

git clone -q --bare "$REMOTE_DIR" "$BARE_DIR"
git --git-dir="$BARE_DIR" config user.name 'RavnVM Test'
git --git-dir="$BARE_DIR" config user.email 'ravnvm@example.test'
git --git-dir="$BARE_DIR" config core.hooksPath /dev/null
git --git-dir="$BARE_DIR" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git --git-dir="$BARE_DIR" fetch -q origin
git --git-dir="$BARE_DIR" branch --set-upstream-to=origin/master master
git --git-dir="$BARE_DIR" branch --set-upstream-to=origin/topic topic
mkdir -p "$REPO_DIR"
git --git-dir="$BARE_DIR" worktree add -q "$REPO_DIR/master" master
git --git-dir="$BARE_DIR" worktree add -q "$REPO_DIR/topic" topic

git -C "$SEED_DIR" switch -q master
printf 'base update\n' >> "$SEED_DIR/tracked.txt"
git -C "$SEED_DIR" add tracked.txt
git -C "$SEED_DIR" commit -q -m 'test: base update'
git -C "$SEED_DIR" push -q
new_base=$(git -C "$SEED_DIR" rev-parse HEAD)

sync_output=$(make -s -C "$ROOT_DIR" -f make/git.mk git-sync WORKTREES_HOME="$WORKTREES_HOME" REPO=demo)
assert_contains "$sync_output" 'origin/master'
git -C "$REPO_DIR/topic" merge-base --is-ancestor "$new_base" HEAD || fail 'topic was not rebased onto origin/master'
[[ -z $(git -C "$REPO_DIR/topic" rev-list --merges "$new_base"..HEAD) ]] || fail 'topic synchronization introduced a merge commit'

mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\ncat\n' > "$FAKE_BIN/hunk"
chmod +x "$FAKE_BIN/hunk"
diff_output=$(PATH="$FAKE_BIN:$PATH" make -s -C "$REPO_DIR/topic" -f "$ROOT_DIR/make/git.mk" git-diff-here BASE_BRANCH=master)
assert_contains "$diff_output" 'compare current worktree against master'

git --git-dir="$BARE_DIR" branch merged master
printf 'y\n' | make -s -C "$REPO_DIR/topic" -f "$ROOT_DIR/make/git.mk" git-clean > /dev/null
git --git-dir="$BARE_DIR" show-ref --verify --quiet refs/heads/merged && fail 'merged inactive branch was not deleted'
git --git-dir="$BARE_DIR" show-ref --verify --quiet refs/heads/master || fail 'active master worktree branch was deleted'
git --git-dir="$BARE_DIR" show-ref --verify --quiet refs/heads/topic || fail 'active topic worktree branch was deleted'

git --git-dir="$BARE_DIR" branch merged-dry master
make -s -C "$REPO_DIR/topic" -f "$ROOT_DIR/make/git.mk" DRY_RUN=1 git-prune-branches > /dev/null
git --git-dir="$BARE_DIR" show-ref --verify --quiet refs/heads/merged-dry || fail 'prune dry-run deleted a branch'

# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" > "$SETUP_LOG"\n' > "$FAKE_BIN/git-bare-clone"
chmod +x "$FAKE_BIN/git-bare-clone"
export SETUP_LOG
PATH="$FAKE_BIN:$PATH" make -s -C "$ROOT_DIR" -f make/git.mk git-setup REPO="$REMOTE_DIR" > /dev/null
[[ $(< "$SETUP_LOG") == "$REMOTE_DIR" ]] || fail 'git-setup did not delegate the repository to git-bare-clone'

rm "$SETUP_LOG"
PATH="$FAKE_BIN:$PATH" make -s -C "$ROOT_DIR" -f make/git.mk DRY_RUN=1 git-setup REPO="$REMOTE_DIR" > /dev/null
[[ ! -e $SETUP_LOG ]] || fail 'git-setup dry-run executed git-bare-clone'

printf 'PASS: Git Make worktree lifecycle\n'
