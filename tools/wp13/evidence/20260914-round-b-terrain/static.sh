#!/usr/bin/env bash
# Plain-5.1 parser, SETGLOBAL inspection and the five sweeps for this round's
# changed files, then the same over every shipped mod and over tools, then the
# fresh-server audit and the WP40 R7 changed-production roster step.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
luac=tools/bin/luac51
changed=(
	mods/MAPGEN/grug_mapgen/wp40/height.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/simple_map.lua
	mods/MAPGEN/grug_mapgen/wp40/zones.lua
	mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua
	tools/wp13/engine_cases.lua
	tools/wp13/terrain_fixture.lua
	tools/wp40/r7/anchor_activation_kat.lua
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

# Reported, not asserted: the roster and `source_audit.sh`'s frozen count are
# WP40-lane state, and main is several files further from 142 than this round is
# (the visuals and start-NPC lanes, plus round A's starts_preload.lua). The
# coordinator resyncs the roster in one commit after the wave.
echo "== WP40 R7 changed-production roster"
git diff --name-only --diff-filter=AM d6002a2 -- mods | rg '[.]lua$' | sort \
	>/tmp/grug-wp13-round-b-derived.txt
diff <(sort tools/wp40/r7/changed_production_lua.txt) \
	/tmp/grug-wp13-round-b-derived.txt
printf 'roster rows %s, derived rows %s\n' \
	"$(wc -l <tools/wp40/r7/changed_production_lua.txt)" \
	"$(wc -l </tmp/grug-wp13-round-b-derived.txt)"
rm -f /tmp/grug-wp13-round-b-derived.txt
