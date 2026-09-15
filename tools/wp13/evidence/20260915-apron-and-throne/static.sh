#!/usr/bin/env bash
# Plain-5.1 parser, SETGLOBAL inspection and the five sweeps for this round's
# changed files, then the same over every shipped mod and over tools, then the
# fresh-server audit and both WP40 R7 gates.
#
# Unlike round B this round runs `tools/wp40/r7/run.sh static` for real: the
# coordinator refroze the changed-production roster at 157 rows, and all four
# production files this round touches are already on it, so the roster is NOT
# edited here and the count must come out unchanged.
#
# The source audit reads two files of the `reference_projects/luanti` submodule
# (`builtin/game/item.lua` and `builtin/game/register.lua`). An agent worktree
# deliberately does not initialise submodules -- they share `.git/modules` with
# the user's own checkout and moving a pinned commit as a side effect is
# forbidden -- so the recorded run made those two paths readable and removed
# them again afterwards; nothing was checked out and no pinned commit moved. In
# a checkout with the submodule present this script needs no such step.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
luac=tools/bin/luac51
changed=(
	mods/MAPGEN/grug_mapgen/wp13/capitals.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/simple_map.lua
	tools/wp13/highcourt_kat.lua
	tools/wp13/evidence/20260915-apron-and-throne/measure/apron_edge.lua
	tools/wp13/evidence/20260915-apron-and-throne/measure/ring_bands.lua
	tools/wp13/evidence/20260915-apron-and-throne/measure/road_shoulder.lua
)

echo "== parser, changed files"
"$luac" -p "${changed[@]}" && echo "luac51 -p PASS (${#changed[@]} files)"

echo "== parser, tree-wide"
mapfile -t all_lua < <(rg --files mods tools | rg '[.]lua$' | sort)
"$luac" -p "${all_lua[@]}" && echo "luac51 -p PASS (${#all_lua[@]} files)"

echo "== SETGLOBAL, changed files"
for file in "${changed[@]}"; do
	count="$("$luac" -l -p -o /dev/null "$file" | rg -c 'SETGLOBAL' || true)"
	printf '%s\t%s\n' "${count:-0}" "$file"
done

echo "== five plain-5.1 sweeps, changed files"
rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${changed[@]}"
rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${changed[@]}"
rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${changed[@]}"
rg -n 'io\.popen|os\.(execute|exit)|\bminetest\.' "${changed[@]}"
rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${changed[@]}"
echo "sweeps: no hits above means clean"

# The five sweeps are scoped to mods/*/grug_* (docs/research/luanti-lua.md);
# Lua under tools/ is checked explicitly, and only for the files this round
# touched, because the WP40 tool tree legitimately shells out with os.execute.
echo "== five plain-5.1 sweeps, mods/*/grug_*"
mapfile -t swept < <(rg --files mods | rg '/grug_[^/]+/.*[.]lua$' | sort)
rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${swept[@]}"
rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${swept[@]}" | rg -v '^[^:]+:[0-9]+:[[:space:]]*--'
rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${swept[@]}"
rg -n 'io\.popen|os\.(execute|exit)' "${swept[@]}"
rg -n '\bminetest\.' "${swept[@]}"
echo "mods/*/grug_* sweeps: the only expected hits are the three pre-existing"
echo "'minetest.conf' comment mentions in mods/CORE/grug_core, which this round"
echo "did not touch and which are a file name, not the deprecated alias"

echo "== fresh-server audit"
python3 tools/check_fresh_server.py

echo "== WP40 R7 unit"
bash tools/wp40/r7/run.sh unit

echo "== WP40 R7 static"
bash tools/wp40/r7/run.sh static
