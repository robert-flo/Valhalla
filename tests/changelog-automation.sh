#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
updater="$repo_root/.github/scripts/update-pr-changelog.sh"
validator="$repo_root/.github/scripts/validate-pr-changelog.sh"
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

cat > "$fixture_root/CHANGELOG.md" << 'EOF'
# Changelog

## Unreleased

### Added

- Existing addition.

### Changed

- Existing change.

## 1.0.0

### Fixed

- Historical fix.
- Historical automated entry. <!-- changelog-pr:90 -->
EOF

run_updater() {
  CHANGELOG_FILE="$fixture_root/CHANGELOG.md" \
    PR_NUMBER="$1" \
    PR_URL="https://github.com/example/repo/pull/$1" \
    PR_TITLE="$2" \
    PR_LABELS="$3" \
    "$updater"
}

run_validator() {
  CHANGELOG_FILE="$fixture_root/CHANGELOG.md" \
    PR_NUMBER="$1" \
    PR_URL="https://github.com/example/repo/pull/$1" \
    PR_TITLE="$2" \
    PR_LABELS="$3" \
    "$validator"
}

run_updater 42 '42 - Add automatic changelog entries' 'changelog:added'
grep -Fq '### Added' "$fixture_root/CHANGELOG.md"
grep -Fq 'Add automatic changelog entries ([#42](https://github.com/example/repo/pull/42)). <!-- changelog-pr:42 -->' "$fixture_root/CHANGELOG.md"

run_updater 42 '42 - Add idempotent changelog entries' 'changelog:added'
test "$(grep -Fc 'changelog-pr:42' "$fixture_root/CHANGELOG.md")" -eq 1
grep -Fq 'Add idempotent changelog entries ([#42](https://github.com/example/repo/pull/42)). <!-- changelog-pr:42 -->' "$fixture_root/CHANGELOG.md"

before_idempotent_update=$(sha256sum "$fixture_root/CHANGELOG.md")
run_updater 42 '42 - Add idempotent changelog entries' 'changelog:added'
test "$before_idempotent_update" = "$(sha256sum "$fixture_root/CHANGELOG.md")"

before_validation=$(sha256sum "$fixture_root/CHANGELOG.md")
run_validator 42 '42 - Add idempotent changelog entries' 'changelog:added'
test "$before_validation" = "$(sha256sum "$fixture_root/CHANGELOG.md")"

if stale_output=$(run_validator 42 '42 - Stale changelog entry' 'changelog:added' 2>&1); then
  echo 'validation must reject a stale changelog entry' >&2
  exit 1
fi
grep -Fq 'Generate the changelog locally and commit the result before requesting review.' <<< "$stale_output"
test "$before_validation" = "$(sha256sum "$fixture_root/CHANGELOG.md")"

if missing_output=$(run_validator 49 '49 - Missing changelog entry' 'changelog:fixed' 2>&1); then
  echo 'validation must reject a missing changelog entry' >&2
  exit 1
fi
grep -Fq 'Generate the changelog locally and commit the result before requesting review.' <<< "$missing_output"
test "$before_validation" = "$(sha256sum "$fixture_root/CHANGELOG.md")"

if run_updater 43 'Improve contributor workflow' ''; then
  echo 'a changelog category or skip label must be required' >&2
  exit 1
fi

if run_updater 43 'Improve contributor workflow' 'changelog:typo'; then
  echo 'an unknown changelog label must not select a category' >&2
  exit 1
fi

run_updater 44 'Fix changelog routing' 'changelog:fixed'
grep -Fq '### Fixed' "$fixture_root/CHANGELOG.md"
grep -Fq 'Fix changelog routing ([#44](https://github.com/example/repo/pull/44)). <!-- changelog-pr:44 -->' "$fixture_root/CHANGELOG.md"
awk '
  /Fix changelog routing/ { found = 1 }
  /^## 1\.0\.0$/ { exit !found }
' "$fixture_root/CHANGELOG.md"

run_updater 42 'Ignored changelog entry' 'changelog:skip'
test "$(grep -Fc 'changelog-pr:42' "$fixture_root/CHANGELOG.md")" -eq 0

before_historical_update=$(sha256sum "$fixture_root/CHANGELOG.md")
run_updater 90 'Rewrite released entry' 'changelog:added'
test "$before_historical_update" = "$(sha256sum "$fixture_root/CHANGELOG.md")"

if released_output=$(run_validator 90 'Rewrite released entry' 'changelog:added' 2>&1); then
  echo 'validation must reject the current pull request marker in a released section' >&2
  exit 1
fi
grep -Fq 'Pull request #90 must remain under Unreleased until it is released.' <<< "$released_output"
grep -Fq 'Generate the changelog locally and commit the result before requesting review.' <<< "$released_output"
test "$before_historical_update" = "$(sha256sum "$fixture_root/CHANGELOG.md")"

if run_updater 45 'Conflicting categories' $'changelog:added\nchangelog:fixed'; then
  echo 'conflicting changelog categories must fail' >&2
  exit 1
fi

if run_updater 46 '46 - ' 'changelog:added'; then
  echo 'an empty normalized title must fail' >&2
  exit 1
fi

if run_updater 47 'Injected <!-- changelog-pr:42 --> marker' 'changelog:added'; then
  echo 'a pull request title must not contain a changelog marker' >&2
  exit 1
fi

if run_updater 48 'Skipped category conflict' $'changelog:skip\nchangelog:added'; then
  echo 'changelog:skip must not be combined with a category' >&2
  exit 1
fi
