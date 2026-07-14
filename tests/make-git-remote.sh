#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/make-git-remote.XXXXXX")"
REPO_DIR="$FIXTURE_DIR/repo"
REMOTE_DIR="$FIXTURE_DIR/remote.git"
WRITER_DIR="$FIXTURE_DIR/writer"

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

mkdir -p "$REPO_DIR"
git init -q --bare "$REMOTE_DIR"
git -C "$REPO_DIR" init -q -b topic
git -C "$REPO_DIR" config user.name 'RavnVM Test'
git -C "$REPO_DIR" config user.email 'ravnvm@example.test'
git -C "$REPO_DIR" config core.hooksPath /dev/null
git -C "$REPO_DIR" remote add origin "$REMOTE_DIR"

printf 'include %s/make/git.mk\n' "$ROOT_DIR" > "$REPO_DIR/Makefile"
printf 'Makefile\n' >> "$REPO_DIR/.git/info/exclude"
printf 'initial\n' > "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
git -C "$REPO_DIR" commit -q -m 'test: initial state'

make -s -C "$REPO_DIR" git-push > /dev/null
[[ $(git -C "$REPO_DIR" rev-parse --abbrev-ref '@{upstream}') == 'origin/topic' ]] || fail 'first push did not establish the upstream'
[[ $(git --git-dir="$REMOTE_DIR" rev-parse refs/heads/topic) == "$(git -C "$REPO_DIR" rev-parse HEAD)" ]] || fail 'first push did not publish the topic branch'

printf 'second\n' >> "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
git -C "$REPO_DIR" commit -q -m 'test: second commit'
make -s -C "$REPO_DIR" git-push > /dev/null
[[ $(git --git-dir="$REMOTE_DIR" rev-parse refs/heads/topic) == "$(git -C "$REPO_DIR" rev-parse HEAD)" ]] || fail 'tracked branch push did not update the remote'

printf 'dry push\n' >> "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
git -C "$REPO_DIR" commit -q -m 'test: dry push'
remote_before_dry_run=$(git --git-dir="$REMOTE_DIR" rev-parse refs/heads/topic)
make -s -C "$REPO_DIR" DRY_RUN=1 git-push > /dev/null
[[ $(git --git-dir="$REMOTE_DIR" rev-parse refs/heads/topic) == "$remote_before_dry_run" ]] || fail 'push dry-run changed the remote'
git -C "$REPO_DIR" reset -q --hard origin/topic

git clone -q --branch topic "$REMOTE_DIR" "$WRITER_DIR"
git -C "$WRITER_DIR" config user.name 'Remote Writer'
git -C "$WRITER_DIR" config user.email 'writer@example.test'
git -C "$WRITER_DIR" config core.hooksPath /dev/null
printf 'remote\n' >> "$WRITER_DIR/tracked.txt"
git -C "$WRITER_DIR" add tracked.txt
git -C "$WRITER_DIR" commit -q -m 'test: remote update'
git -C "$WRITER_DIR" push -q

head_before_dry_pull=$(git -C "$REPO_DIR" rev-parse HEAD)
make -s -C "$REPO_DIR" DRY_RUN=1 git-pull > /dev/null
[[ $(git -C "$REPO_DIR" rev-parse HEAD) == "$head_before_dry_pull" ]] || fail 'pull dry-run changed local history'

make -s -C "$REPO_DIR" git-pull > /dev/null
[[ $(git -C "$REPO_DIR" rev-parse HEAD) == "$(git --git-dir="$REMOTE_DIR" rev-parse refs/heads/topic)" ]] || fail 'pull did not update the local branch'

printf 'PASS: Git Make remote synchronization\n'
