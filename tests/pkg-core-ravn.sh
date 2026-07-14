#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
package_manifest="$repo_root/Scripts/pkg_core.lst"

assert_single_ravn_package() {
  local package=$1

  awk -v package="$package" '
        /^# --------------------------------------------------- \/\/ RaVN$/ {
            in_ravn = 1
            next
        }
        $1 == package {
            total++
            if (in_ravn) ravn++
        }
        END {
            exit !(total == 1 && ravn == 1)
        }
    ' "$package_manifest"
}

for package in \
  actionlint \
  bc \
  grep \
  pre-commit \
  qemu-desktop \
  ripgrep \
  yamllint; do
  assert_single_ravn_package "$package"
done

if grep -Eq '^rg([[:space:]]|$)' "$package_manifest"; then
  echo "Use the Arch package name 'ripgrep'; do not add an 'rg' alias." >&2
  exit 1
fi
