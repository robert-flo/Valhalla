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

category='Changed'
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

if ((${#category_labels[@]} == 1)); then
  category=${category_labels[0]}
fi

marker="<!-- changelog-pr:${pr_number} -->"
temporary_file=$(mktemp "${changelog_file}.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

awk -v marker="$marker" 'index($0, marker) == 0 { print }' "$changelog_file" > "$temporary_file"
mv "$temporary_file" "$changelog_file"

if [[ $skip_entry == true ]]; then
  exit 0
fi

if ! grep -Fxq "### $category" "$changelog_file"; then
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

normalized_title=$(sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+-[[:space:]]+//' <<< "$pr_title")
case $normalized_title in
  *[.!?]) suffix='' ;;
  *) suffix='.' ;;
esac
entry="- ${normalized_title} ([#${pr_number}](${pr_url}))${suffix} ${marker}"

awk -v heading="### $category" -v entry="$entry" '
  $0 == heading && !inserted {
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
