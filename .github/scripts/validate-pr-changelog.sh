#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
changelog_file=${CHANGELOG_FILE:-CHANGELOG.md}
guidance=${CHANGELOG_FAILURE_GUIDANCE:-Generate the changelog locally and commit the result before requesting review.}

if [[ ! -f $changelog_file ]]; then
  printf 'Error: Changelog not found: %s\n' "$changelog_file" >&2
  exit 2
fi

marker="<!-- changelog-pr:${PR_NUMBER:-} -->"
if awk -v marker="$marker" '
  /^## Unreleased$/ { in_unreleased = 1; next }
  /^## / { in_unreleased = 0 }
  !in_unreleased && index($0, marker) { found = 1 }
  END { exit !found }
' "$changelog_file"; then
  printf 'Error: Pull request #%s must remain under Unreleased until it is released.\n' "${PR_NUMBER:-unknown}" >&2
  printf 'Error: %s\n' "$guidance" >&2
  exit 1
fi

original_file=$(mktemp "${changelog_file}.validation.XXXXXX")

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
  cp -p "$original_file" "$changelog_file"
  rm -f "$original_file"
}

trap cleanup EXIT
cp -p "$changelog_file" "$original_file"

"$script_dir/update-pr-changelog.sh"

if cmp -s "$original_file" "$changelog_file"; then
  printf 'The committed changelog matches pull request #%s.\n' "$PR_NUMBER"
  exit 0
fi

diff -u "$original_file" "$changelog_file" || true
printf 'Error: %s\n' "$guidance" >&2
exit 1
