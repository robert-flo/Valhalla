#!/usr/bin/env bash

set -euo pipefail

mode=${1:-}

is_ignored_legacy_path() {
  case $1 in
    Configs/.config/uwsm/* | Configs/.config/waybar/* | \
      Configs/.config/hyde/wallbash/scripts/code.sh | Configs/.local/lib/* | \
      Configs/.local/share/wallbash/* | Configs/.local/share/waybar/* | \
      Scripts/chaotic_aur.sh | Scripts/extra/* | Scripts/global_fn.sh | \
      Scripts/ravn/global_fn.sh | Scripts/install_pre.sh | Scripts/install_pst.sh | \
      Scripts/restore_cfg.sh | Scripts/restore_shl.sh | Scripts/uninstall.sh)
      return 0
      ;;
  esac

  return 1
}

is_shell_file() {
  local file=$1
  local shebang

  [[ $file == *.sh ]] && return 0
  IFS= read -r shebang < "$file" || true
  [[ $shebang =~ ^\#![[:space:]]*/([^[:space:]]*/)?(env[[:space:]]+)?(bash|sh)([[:space:]]|$) ]]
}

check_file() {
  local file=$1

  [[ -f $file ]] || return 0
  is_shell_file "$file" || return 0
  shellcheck -f gcc -- "$file" || true
}

case $mode in
  changed)
    while IFS= read -r -d '' file; do
      is_ignored_legacy_path "$file" && continue
      check_file "$file"
    done < <(
      {
        git diff --name-only -z --diff-filter=ACMRT HEAD
        git ls-files --others --exclude-standard -z
      } | sort -zu
    )
    ;;
  full)
    while IFS= read -r -d '' file; do
      check_file "${file#./}"
    done < <(find . -type f -not -path './.git/*' -print0 | sort -z)
    ;;
  *)
    printf 'Usage: %s {changed|full}\n' "$0" >&2
    exit 2
    ;;
esac
