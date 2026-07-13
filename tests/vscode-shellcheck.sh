#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

fixture_repo="$fixture_root/repo"
mkdir -p "$fixture_repo/.vscode" "$fixture_repo/Scripts" "$fixture_repo/bin"
cp "$repo_root/.vscode/shellcheck.sh" "$fixture_repo/.vscode/shellcheck.sh"

cat > "$fixture_repo/tracked.sh" << 'EOF'
#!/usr/bin/env bash
printf 'tracked\n'
EOF

cat > "$fixture_repo/Scripts/restore_cfg.sh" << 'EOF'
#!/usr/bin/env bash
printf 'legacy\n'
EOF

git -C "$fixture_repo" init -q
git -C "$fixture_repo" config user.email test@example.invalid
git -C "$fixture_repo" config user.name Test
git -C "$fixture_repo" add .
git -C "$fixture_repo" commit -qm baseline

printf 'unused_value="changed"\n' >> "$fixture_repo/tracked.sh"
printf 'unused_value="legacy"\n' >> "$fixture_repo/Scripts/restore_cfg.sh"
cat > "$fixture_repo/bin/no-extension" << 'EOF'
#!/usr/bin/env bash
target=$1
printf 'new shell file\n'
echo $target
EOF

changed_output=$(cd "$fixture_repo" && .vscode/shellcheck.sh changed)
grep -Fq 'tracked.sh:1:1: warning:' <<< "$changed_output"
grep -Fq 'bin/no-extension:4:6: note:' <<< "$changed_output"
grep -Fq '[SC2034]' <<< "$changed_output"
grep -Fq '[SC2086]' <<< "$changed_output"
if grep -Fq 'Scripts/restore_cfg.sh:1:1: warning:' <<< "$changed_output"; then
  echo 'changed mode must exclude legacy paths' >&2
  exit 1
fi

full_output=$(cd "$fixture_repo" && .vscode/shellcheck.sh full)
grep -Fq 'Scripts/restore_cfg.sh:1:1: warning:' <<< "$full_output"
grep -Fq 'bin/no-extension:4:6: note:' <<< "$full_output"
