#!/usr/bin/env bash

set -euo pipefail

changelog_file=${CHANGELOG_FILE:-CHANGELOG.md}
pr_number=${PR_NUMBER:-}
pr_url=${PR_URL:-}
pr_title=${PR_TITLE:-}
pr_labels=${PR_LABELS:-}

if [[ ! $pr_number =~ ^[0-9]+$ ]]; then
  echo 'PR_NUMBER must be a positive pull request number.' >&2
  exit 2
fi

if [[ -z $pr_url || -z $pr_title || $pr_title == *$'\n'* ]]; then
  echo 'PR_URL and a single-line PR_TITLE are required.' >&2
  exit 2
fi

if [[ ! -f $changelog_file ]]; then
  echo "Changelog not found: $changelog_file" >&2
  exit 2
fi

category=''
skip_entry=false
category_labels=()

while IFS= read -r label; do
  case $label in
    changelog:skip)
      skip_entry=true
      ;;
    changelog:added)
      category_labels+=('Added')
      ;;
    changelog:changed)
      category_labels+=('Changed')
      ;;
    changelog:fixed)
      category_labels+=('Fixed')
      ;;
    changelog:removed)
      category_labels+=('Removed')
      ;;
    changelog:security)
      category_labels+=('Security')
      ;;
    changelog:deprecated)
      category_labels+=('Deprecated')
      ;;
  esac
done <<< "$pr_labels"

if [[ $skip_entry == true ]] && ((${#category_labels[@]} > 0)); then
  echo 'changelog:skip cannot be combined with a changelog category.' >&2
  exit 2
fi

if ((${#category_labels[@]} > 1)); then
  echo 'Only one changelog category label may be applied.' >&2
  exit 2
fi

if [[ $skip_entry == false ]] && ((${#category_labels[@]} == 0)); then
  echo 'Exactly one changelog category label or changelog:skip is required.' >&2
  exit 2
fi

if ((${#category_labels[@]} == 1)); then
  category=${category_labels[0]}
fi

normalized_title=$(sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+-[[:space:]]+//' <<< "$pr_title")
if [[ -z ${normalized_title//[[:space:]]/} ]]; then
  echo 'PR_TITLE must contain text after an optional number prefix.' >&2
  exit 2
fi

if [[ $normalized_title == *'<!-- changelog-pr:'* ]]; then
  echo 'PR_TITLE must not contain a changelog marker.' >&2
  exit 2
fi

marker="<!-- changelog-pr:${pr_number} -->"
temporary_file=$(mktemp "${changelog_file}.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

if awk -v marker="$marker" '
  /^## Unreleased$/ { in_unreleased = 1; next }
  /^## / { in_unreleased = 0 }
  !in_unreleased && index($0, marker) { found = 1 }
  END { exit !found }
' "$changelog_file"; then
  echo "Pull request #${pr_number} is already in a released section; preserving it."
  exit 0
fi

awk -v marker="$marker" '
  /^## Unreleased$/ { in_unreleased = 1 }
  /^## / && $0 != "## Unreleased" { in_unreleased = 0 }
  in_unreleased && index($0, marker) != 0 {
    skip_following_blank = 1
    next
  }
  skip_following_blank && $0 == "" {
    skip_following_blank = 0
    next
  }
  {
    skip_following_blank = 0
    print
  }
' "$changelog_file" > "$temporary_file"
mv "$temporary_file" "$changelog_file"

if [[ $skip_entry == true ]]; then
  exit 0
fi

if ! awk -v heading="### $category" '
  /^## Unreleased$/ { in_unreleased = 1; next }
  /^## / { in_unreleased = 0 }
  in_unreleased && $0 == heading { found = 1 }
  END { exit !found }
' "$changelog_file"; then
  awk -v heading="### $category" '
    /^## Unreleased$/ && !inserted {
      print
      print ""
      print heading
      print ""
      inserted = 1
      next
    }
    { print }
    END { exit !inserted }
  ' "$changelog_file" > "$temporary_file"
  mv "$temporary_file" "$changelog_file"
fi

case $normalized_title in
  *[.!?]) suffix='' ;;
  *) suffix='.' ;;
esac
entry="- ${normalized_title} ([#${pr_number}](${pr_url}))${suffix} ${marker}"

awk -v heading="### $category" -v entry="$entry" '
  /^## Unreleased$/ { in_unreleased = 1 }
  /^## / && $0 != "## Unreleased" { in_unreleased = 0 }
  in_unreleased && $0 == heading && !inserted {
    print
    print ""
    print entry
    inserted = 1
    next
  }
  { print }
  END { exit !inserted }
' "$changelog_file" > "$temporary_file"
mv "$temporary_file" "$changelog_file"
