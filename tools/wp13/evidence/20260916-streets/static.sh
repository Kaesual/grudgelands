#!/usr/bin/env bash
# The five plain-5.1 sweeps and the SETGLOBAL check of
# tools/wp13/evidence/20260914-character-visuals/static.sh, scoped to the Lua
# Lane S of WP13 wave 3 changed, and then tree-wide.
set -uo pipefail
export LC_ALL=C
repo="$1"
cd "$repo" || exit 1
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp13/avenue.lua
	mods/MAPGEN/grug_mapgen/wp13/street_plan.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak.lua
	mods/MAPGEN/grug_mapgen/wp13/lethariel.lua
	mods/MAPGEN/grug_mapgen/wp13/kezamba.lua
	mods/MAPGEN/grug_mapgen/wp13/nhal_veyr.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	tools/wp13/street_geometry.lua
	tools/wp13/street_kat.lua
	tools/wp13/highcourt_kat.lua
	tools/wp13/dur_brannoc_kat.lua
	tools/wp13/gor_drazhak_kat.lua
	tools/wp13/lethariel_kat.lua
	tools/wp13/nhal_veyr_kat.lua
	tools/wp13/lane_crossing_kat.lua
	tools/wp13/integration_fixture.lua
)

echo "== parser and SETGLOBAL on every Lua file this lane changed =="
for file in "${CHANGED[@]}"; do
	[ -f "$file" ] || { echo "$file (absent)"; continue; }
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

echo "== five plain-5.1 sweeps, scoped to the Lua this lane changed =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over all of mods/*/grug_* and tools =="
sweeps mods/*/grug_* tools

echo "== fresh server check =="
python3 tools/check_fresh_server.py
