# Pull Request and Branching Policy

This file is the canonical source for the repository's branch and pull-request
policy. Other contribution documents provide contextual instructions and link
back to this policy.

## Branch model

This repository uses `master` as its only permanent integration branch. It does
not use `dev` or `rc` branches.

All changes must follow this path:

```text
issue → temporary branch/worktree → pull request → master
```

## Rules for `master`

- Direct commits and pushes to `master` are not allowed.
- Every change must arrive through a pull request targeting `master`.
- The pull request must reference its issue and describe the validations run.
- Applicable CI checks must finish successfully before merge.
- Temporary branches are deleted after their pull requests are merged.
- Force pushes to `master` are not allowed.

Branch protection in GitHub is the enforcement mechanism for the pull-request
requirement. GitHub Actions validates changes but cannot prevent a direct push
after it has already occurred.

## CI events

The validation workflow runs twice during the normal lifecycle:

1. On a pull request targeting `master`, before merge, to validate the proposed
   diff.
2. On a push to `master`, after the pull request is merged, to validate the
   resulting commit.

The second run is post-merge verification. The pull-request run and branch
protection are what guard `master` before the change lands.
