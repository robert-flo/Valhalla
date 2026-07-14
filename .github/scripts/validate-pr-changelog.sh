#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
changelog_file=${CHANGELOG_FILE:-CHANGELOG.md}
guidance=${CHANGELOG_FAILURE_GUIDANCE:-Generate the changelog locally and commit the result before requesting review.}
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
