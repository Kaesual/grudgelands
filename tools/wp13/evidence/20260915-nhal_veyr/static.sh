#!/usr/bin/env bash
# Static gates for the Nhal Veyr increment: the same set every WP13 increment
# runs. Parser and SETGLOBAL per changed file and tree-wide, the five plain-5.1
# sweeps scoped to the changed Lua and then tree-wide over mods/*/grug_* and
# tools, and the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_plot.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_quadrants.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_districts.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_martial.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_lore.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_homes.lua
	mods/MAPGEN/grug_mapgen/wp13/undead_parts.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_nhal_veyr_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	tools/wp13/nhal_veyr_kat.lua
	tools/wp13/nhal_veyr_plots.lua
	tools/wp13/final_micro.lua
	mods/MAPGEN/grug_mapgen/wp13/wall.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc.lua
	tools/wp13/capital_wall.lua
	tools/wp13/capital_probe/init.lua
	tools/wp13/route_gates.lua
	tools/wp13/kezamba_kat.lua
)

echo "== parser and SETGLOBAL on every Lua file this increment changed =="
for file in "${CHANGED[@]}"; do
	if "$LUAC" -p "$file" >/dev/null 2>&1; then
		globals="$("$LUAC" -p -l "$file" | grep -c SETGLOBAL)"
		echo "$file parser PASS; SETGLOBAL [$globals]"
	else
		echo "$file parser FAIL"
	fi
done

echo "== whole tree parses =="
find mods -name '*.lua' -path 'mods/*/grug_*' -print0 |
	xargs -0 "$LUAC" -p && echo "mods/*/grug_* parser PASS"
find tools -name '*.lua' -print0 | xargs -0 "$LUAC" -p &&
	echo "tools parser PASS"

sweeps() {
	local index=1
	for pattern in \
		'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' \
		'\\u\{|\\x[0-9A-Fa-f]|\\z' \
		'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' \
		'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' \
		'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'; do
		echo "SWEEP $index"
		grep -rnE "$pattern" "$@" --include=*.lua
		index=$((index + 1))
	done
	echo "SWEEPS DONE (no output above a SWEEP line means zero hits)"
}

echo "== five plain-5.1 sweeps, scoped to the Lua this increment changed =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over all of mods/*/grug_* and tools =="
sweeps mods/*/grug_* tools

echo "== fresh server check =="
python3 tools/check_fresh_server.py
