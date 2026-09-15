#!/usr/bin/env bash
# Lane R static gates: the same set every WP13 increment runs
# (tools/wp13/evidence/20260914-character-visuals/static.sh), scoped to the Lua
# this lane changed.
set -uo pipefail
export LC_ALL=C
repo="${1:?repo}"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua
	mods/MAPGEN/grug_mapgen/wp40/simple_map.lua
	mods/MAPGEN/grug_mapgen/wp40/height.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_anchor_activation.lua
	tools/wp40/r7/anchor_activation_kat.lua
	tools/wp40/simple_map_r3_validate.lua
	tools/wp40/simple_map_r3_selftest.lua
	tools/wp13/route_gates.lua
	tools/wp13/route_gates_kat.lua
	tools/wp13/final_micro.lua
)

echo "== parser and SETGLOBAL on every Lua file this lane changed =="
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

echo "== five plain-5.1 sweeps, scoped to the Lua this lane changed =="
sweeps "${CHANGED[@]}"

echo "== fresh-server audit =="
python3 tools/check_fresh_server.py
echo "check_fresh_server exit=$?"
