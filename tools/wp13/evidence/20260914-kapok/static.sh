#!/usr/bin/env bash
# Static gates for the WP13 Kapok Cradle increment, exactly the set the
# previous two increments' evidence ran: parser and SETGLOBAL per changed file
# and tree-wide, the five plain-5.1 sweeps scoped to the changed Lua and then
# tree-wide over mods/*/grug_* and tools, and the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp13/buildings.lua
	mods/MAPGEN/grug_mapgen/wp13/dressing.lua
	mods/MAPGEN/grug_mapgen/wp13/interiors.lua
	mods/MAPGEN/grug_mapgen/wp13/kapok.lua
	mods/MAPGEN/grug_mapgen/wp13/layout.lua
	mods/MAPGEN/grug_mapgen/wp13/palette.lua
	mods/MAPGEN/grug_mapgen/wp13/parts.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	tools/wp13/blueprint_kat.lua
	tools/wp13/engine_cases.lua
	tools/wp13/library_kat.lua
	tools/wp13/stub_registry.lua
)

echo "== parser and SETGLOBAL on every Lua file changed by this increment =="
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
