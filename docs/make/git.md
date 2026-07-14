# Git operations through Make

The Git Make interface provides a consistent terminal presentation for common
repository operations. Run `make help-git` for the current target list and
`make help-aliases` for the compatibility shortcuts that are available today.

## Local workflow

The local commit cycle is available through these targets:

- `git-add` stages every change in the working tree.
- `git-commit` stages every change and creates a timestamped, signed-off commit.
- `git-cm MSG="message"` stages every change and preserves the supplied message.
- `git-add-commit` combines staging and the timestamped commit.
- `git-add-fuzzy` uses `fzf` to select individual files.
- `git-amend` amends the last commit, optionally using `MSG` as its new message.

These commands intentionally operate on all changes unless the fuzzy staging
target is selected. Inspect the repository with `git-status` and `git-diff`
before committing when unrelated work may be present.

## Remote workflow

`git-push` publishes the current branch. Its first push establishes
`origin/<branch>` as the upstream; later pushes use that tracking relationship.
`git-pull` updates the current branch from its configured upstream.

Set `DRY_RUN=1` to preview `git-add`, commit, push, pull, amend, setup, and prune
operations without performing their mutation.

## Inspection

- `git-status` reports the branch, upstream distance, worktree state, and recent
  commits.
- `git-diff` displays unstaged changes, preferring `hunk` when installed.
- `git-log` shows recent history.
- `git-diff-fuzzy` uses `fzf` or `peco` to select a commit.
- `git-search CODE="text"` searches code changes and `git-search MSG="text"`
  searches commit messages.

## Bare repositories and worktrees

`git-setup REPO=<url>` delegates bare cloning and worktree creation to
`git-bare-clone`. `BARE_HOME` and `WORKTREES_HOME` override its storage roots.

`git-sync REPO=<name>` scans the repository's worktrees and rebases topic
branches onto `origin/master`. Override `GIT_REMOTE`, `BASE_BRANCH`, or
`PROTECTED_BRANCHES` when another repository has different conventions.
Protected branches are skipped.

`git-diff-here` compares the current worktree with `BASE_BRANCH`. The historical
`git-diff-dev` and `git-diff-rc` comparisons remain available for repositories
that still use those branches.

`git-prune-branches` deletes only branches already merged into the current
history. Protected branches and branches active in any worktree are preserved.

## Requirements

Git and GNU Make are required. The following commands are optional:

- `fzf` or `peco` for interactive selection;
- `hunk` for enhanced diff rendering;
- `git-bare-clone` for `git-setup`.
