#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v rg >/dev/null
files=(mods/PLAYER/grug_parties/init.lua tools/r14_parties/core_kat.lua)
for file in "${files[@]}"; do
  tools/bin/luac51 -p "$file"
  printf 'parser PASS %s\n' "$file"
  globals=$(tools/bin/luac51 -l -p "$file" | rg 'SETGLOBAL' || true)
  printf 'global writes %s: %s\n' "$file" "${globals:-none}"
done
patterns=(
  '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
  '\\u\{|\\x[0-9A-Fa-f]|\\z'
  'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
  '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
  '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for i in "${!patterns[@]}"; do
  if rg -n "${patterns[$i]}" "${files[@]}"; then
    printf 'sweep %s FAIL\n' "$((i+1))"
    exit 1
  else
    status=$?
    test "$status" -eq 1
    printf 'sweep %s PASS\n' "$((i+1))"
  fi
done
