#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v rg >/dev/null
parser=tools/bin/luac51
files=(mods/MAPGEN/grug_mapgen/wp40/r14_poi_blueprint.lua tools/r15_poi/poi_micro_kat.lua)
"$parser" -p "${files[@]}"
for file in "${files[@]}"; do
  echo "SETGLOBAL $file"
  "$parser" -l -p "$file" | rg SETGLOBAL || test "$?" = 1
done
# The fixture deliberately installs one engine stub global, core.
patterns=(
 '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
 '\\u\{|\\x[0-9A-Fa-f]|\\z'
 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
 '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
 '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for index in "${!patterns[@]}"; do
  echo "SWEEP $((index + 1))"
  if rg -n "${patterns[$index]}" "${files[@]}"; then
    echo 'Unexpected source sweep hit' >&2
    exit 1
  else
    test "$?" = 1
  fi
done
