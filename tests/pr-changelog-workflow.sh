#!/usr/bin/env bash
# shellcheck disable=SC2016 # Match literal GitHub Actions expressions.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
workflow="$repo_root/.github/workflows/update-pr-changelog.yml"

grep -Fq 'pull_request_target:' "$workflow"
grep -Fq '      - master' "$workflow"
grep -Fq 'contents: read' "$workflow"
grep -Fq 'group: pr-changelog-${{ github.event.pull_request.number }}' "$workflow"
grep -Fq 'ref: ${{ github.event.pull_request.base.sha }}' "$workflow"
grep -Fq 'ref: ${{ github.event.pull_request.head.sha }}' "$workflow"
grep -Fq 'persist-credentials: false' "$workflow"
grep -Fq 'CHANGELOG_FILE: source/CHANGELOG.md' "$workflow"
grep -Fq 'run: automation/.github/scripts/validate-pr-changelog.sh' "$workflow"
grep -Fq 'Generate the changelog locally and commit the result before requesting review.' "$workflow"
grep -Fq '      - synchronize' "$workflow"

if grep -Eq 'contents: write|git commit|git push|GITHUB_TOKEN' "$workflow"; then
  echo 'the changelog workflow must not write to the pull request branch' >&2
  exit 1
fi
