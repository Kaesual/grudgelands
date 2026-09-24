#!/usr/bin/env bash
set -euo pipefail
command -v rg >/dev/null
parser=${GRUG_LUA51_PARSER:-tools/bin/luac51}
if [ "$#" -eq 0 ]; then
  echo 'Usage: check_lua.sh changed.lua ...' >&2
  exit 2
fi
for file in "$@"; do
  "$parser" -p "$file"
  printf 'parser PASS %s\n' "$file"
  "$parser" -l -p "$file" | rg SETGLOBAL || test "$?" -eq 1
done
patterns=(
  '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
  '\\u\{|\\x[0-9A-Fa-f]|\\z'
  'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
  '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
  '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
findings=0
for index in "${!patterns[@]}"; do
  if rg -n "${patterns[$index]}" "$@"; then
    printf 'sweep %s: inspect hits (comments may match)\n' "$((index+1))" >&2
    findings=1
  else
    test "$?" -eq 1
    printf 'sweep %s PASS\n' "$((index+1))"
  fi
done
exit "$findings"
