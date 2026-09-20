#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v rg >/dev/null
parser="${LUAC51:-/home/jan/projects/grudgelands/tools/bin/luac51}"
files=(mods/PLAYER/grug_jobs/{automatic,workspaces,registry,state,station_nodes,stations}.lua mods/ITEMS/grug_{alchemy/recipes,brewing/node,cooking/init,smelting/node}.lua tools/r13_stations/probe/{init,scenarios}.lua)
for file in "${files[@]}"; do
  "$parser" -p "$file"
  printf 'PARSER PASS %s\n' "$file"
  "$parser" -l -p "$file" | rg SETGLOBAL || [[ $? == 1 ]]
done
patterns=('(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' '\\u\{|\\x[0-9A-Fa-f]|\\z' 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.')
for pattern in "${patterns[@]}"; do
  printf 'CHANGED SWEEP %s\n' "$pattern"
  rg -n "$pattern" "${files[@]}" || [[ $? == 1 ]]
  printf 'TREE SWEEP %s\n' "$pattern"
  rg -n --glob '*.lua' "$pattern" mods/*/grug_* || [[ $? == 1 ]]
done
