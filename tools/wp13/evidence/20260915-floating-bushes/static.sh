#!/usr/bin/env bash
# Static gates for WP13 playtest round 3 lane 2 (floating decorations), the same
# set every WP13 increment runs: parser and SETGLOBAL per changed file and
# tree-wide, the five plain-5.1 sweeps scoped to the changed Lua and then
# tree-wide over mods/*/grug_* and tools, and the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="${WP13_LUAC:-$repo/tools/bin/luac51}"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua
	tools/wp13/decoration_anchor_kat.lua
	tools/wp13/bush_probe/init.lua
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

echo "== the probe's render mode writes no game file =="
grep -n 'core.set_node\|core.place_schematic\|io.open' tools/wp13/bush_probe/init.lua ||
	echo "the probe only reads the map"

echo "== the decoration anchor KAT, both interpreters =="
"${WP13_LUAJIT:-luajit}" -e \
	'io.write(dofile("tools/wp13/decoration_anchor_kat.lua")("."))' |
	tail -1
"${WP13_PUC:-$repo/tools/bin/lua51}" -e \
	'io.write(dofile("tools/wp13/decoration_anchor_kat.lua")("."))' |
	tail -1
