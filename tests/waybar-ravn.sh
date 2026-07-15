#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
waybar_root="$repo_root/Configs_RaVN/.local/share/waybar"
restore_manifest="$repo_root/Scripts/configurations/restore_configurations.psv"

parse_jsonc() {
  perl -0777 -pe 's/^[ \t]*\/\/.*$//mg; s/,\s*([}\]])/$1/g' "$1" | jq empty
}

for file in \
  "$waybar_root"/layouts/hyprdots/*.jsonc \
  "$waybar_root"/modules/custom-{countdown,screenrecording,todo,weather}.jsonc; do
  parse_jsonc "$file"
done

for layout in "$waybar_root"/layouts/hyprdots/*.jsonc; do
  for module in \
    'group/pill#todo' \
    'group/pill#countdown' \
    'group/pill#spotify' \
    'custom/screenrecording' \
    'custom/weather'; do
    grep -Fq "$module" "$layout"
  done
done

grep -Fq 'wttrbar --location \"San Salvador, El Salvador\" --lang es' \
  "$waybar_root/modules/custom-weather.jsonc"
grep -Fq 'hyde-shell screenrecord --quit' \
  "$waybar_root/modules/custom-screenrecording.jsonc"
grep -Fq 'hyde-shell screenshot s' \
  "$waybar_root/modules/custom-screenrecording.jsonc"

find "$waybar_root/scripts" -type f -name '*.sh' -print0 |
  xargs -0 -n1 bash -n

smoke_home=$(mktemp -d)
trap 'rm -rf "$smoke_home"' EXIT

todo_output=$(
  HOME="$smoke_home" XDG_STATE_HOME="$smoke_home/state" \
    "$waybar_root/scripts/todo/todo.sh"
)
jq -e '.text == "  Add a task!"' <<< "$todo_output" > /dev/null

countdown_output=$(
  HOME="$smoke_home" XDG_STATE_HOME="$smoke_home/state" \
    "$waybar_root/scripts/countdown/countdown.sh"
)
jq -e '.text == "No Countdowns" and .percentage == 0' \
  <<< "$countdown_output" > /dev/null

awk -F'|' '$1 == "P" || $1 == "S" { entries++ } END { exit !(entries == 43) }' "$restore_manifest"

for source in \
  "$repo_root/Configs_RaVN/.config/waybar/config.jsonc" \
  "$repo_root/Configs_RaVN/.local/share/waybar/modules/custom-todo.jsonc" \
  "$repo_root/Configs_RaVN/.local/share/waybar/modules/custom-countdown.jsonc" \
  "$repo_root/Configs_RaVN/.local/share/waybar/modules/custom-screenrecording.jsonc"; do
  test -f "$source"
done
