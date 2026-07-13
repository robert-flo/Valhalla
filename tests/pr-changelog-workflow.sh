#!/usr/bin/env bash
# shellcheck disable=SC2016 # Match literal GitHub Actions expressions.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
workflow="$repo_root/.github/workflows/update-pr-changelog.yml"

grep -Fq 'pull_request_target:' "$workflow"
grep -Fq '      - master' "$workflow"
grep -Fq 'group: pr-changelog-${{ github.event.pull_request.number }}' "$workflow"
grep -Fq "github.event.pull_request.head.repo.full_name == github.repository" "$workflow"
grep -Fq "github.event.pull_request.head.ref != 'master'" "$workflow"
grep -Fq 'ref: ${{ github.event.pull_request.base.sha }}' "$workflow"
grep -Fq 'ref: ${{ github.event.pull_request.head.ref }}' "$workflow"
grep -Fq 'persist-credentials: false' "$workflow"
grep -Fq 'CHANGELOG_FILE: source/CHANGELOG.md' "$workflow"
grep -Fq 'run: automation/.github/scripts/update-pr-changelog.sh' "$workflow"
grep -Fq 'HEAD:${PR_BRANCH}' "$workflow"
grep -Fq 'Check branch protection, a concurrent update, or GitHub Actions contents: write permission.' "$workflow"
if grep -Fq 'synchronize' "$workflow"; then
  echo 'Bot commits must not retrigger changelog updates through synchronize.' >&2
  exit 1
fi
