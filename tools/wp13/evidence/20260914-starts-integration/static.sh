#!/usr/bin/env bash
# Static gates for the WP13 starts integration branch: parser and SETGLOBAL per
# file the integration touched and tree-wide, the five plain-5.1 sweeps scoped
# to those files and then to wp13/, the changed wp40 files and tools/wp13, and
# the fresh-server audit.
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
	mods/MAPGEN/grug_mapgen/wp13/roofs.lua
	mods/MAPGEN/grug_mapgen/wp13/silverleaf.lua
	mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua
	mods/MAPGEN/grug_mapgen/wp13/sunscar.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua
	tools/wp13/blueprint_kat.lua
	tools/wp13/engine_cases.lua
	tools/wp13/library_kat.lua
	tools/wp13/stub_registry.lua
)

echo "== parser and SETGLOBAL on every Lua file this integration touched =="
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

echo "== five plain-5.1 sweeps, scoped to the Lua this integration touched =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over wp13/, the changed wp40 files and tools/wp13 =="
sweeps mods/MAPGEN/grug_mapgen/wp13 tools/wp13 \
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua

echo "== the changed Python file compiles =="
python3 -m py_compile tools/wp13/extract_tiles.py &&
	echo "tools/wp13/extract_tiles.py py_compile PASS"

echo "== node_tiles.json parses =="
python3 -c "import json; d = json.load(open('tools/wp13/node_tiles.json')); print('node_tiles.json nodes', len(d['nodes']))"

echo "== fresh server check =="
python3 tools/check_fresh_server.py
