#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
waybar_root="$repo_root/Configs/.local/share/waybar"
restore_manifest="$repo_root/Scripts/restore_cfg.psv"

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
		rg -Fq "$module" "$layout"
	done
done

rg -Fq 'wttrbar --location \"San Salvador, El Salvador\" --lang es' \
	"$waybar_root/modules/custom-weather.jsonc"
rg -Fq 'hyde-shell screenrecord --quit' \
	"$waybar_root/modules/custom-screenrecording.jsonc"
rg -Fq 'hyde-shell screenshot s' \
	"$waybar_root/modules/custom-screenrecording.jsonc"

find "$waybar_root/scripts" -type f -name '*.sh' -print0 |
	xargs -0 -n1 bash -n

smoke_home=$(mktemp -d)
trap 'rm -rf "$smoke_home"' EXIT

todo_output=$(
	HOME="$smoke_home" XDG_STATE_HOME="$smoke_home/state" \
		"$waybar_root/scripts/todo/todo.sh"
)
jq -e '.text == "  Add a task!"' <<<"$todo_output" >/dev/null

countdown_output=$(
	HOME="$smoke_home" XDG_STATE_HOME="$smoke_home/state" \
		"$waybar_root/scripts/countdown/countdown.sh"
)
jq -e '.text == "No Countdowns" and .percentage == 0' \
	<<<"$countdown_output" >/dev/null

awk '
    /^# --------------------------------------------------- \/\/ RaVN$/ { in_ravn = 1; next }
    /\/waybar\||\|waybar$/ {
        if (!in_ravn) exit 1
        waybar_entries++
    }
    END { exit !(in_ravn && waybar_entries == 3) }
' "$restore_manifest"

for source in \
	"$repo_root/Configs/.config/waybar/config.jsonc" \
	"$repo_root/Configs/.local/share/waybar/modules/custom-todo.jsonc" \
	"$repo_root/Configs/.local/share/waybar/modules/custom-countdown.jsonc" \
	"$repo_root/Configs/.local/share/waybar/modules/custom-screenrecording.jsonc"; do
	test -f "$source"
done
