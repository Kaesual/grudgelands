#!/usr/bin/env bash
# Static gates for the Highcourt pilot: parser and SETGLOBAL per file this lane
# touched and tree-wide, the five plain-5.1 sweeps scoped to those files and
# then to wp13/ and tools/wp13, and the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp13/avenue.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_district.lua
	tools/wp13/dump_highcourt.lua
	tools/wp13/final_micro.lua
	tools/wp13/highcourt_kat.lua
	tools/wp13/highcourt_timing.lua
)

echo "== parser and SETGLOBAL on every Lua file this lane touched =="
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

echo "== five plain-5.1 sweeps, scoped to the Lua this lane touched =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over wp13/ and tools/wp13 =="
sweeps mods/MAPGEN/grug_mapgen/wp13 tools/wp13

echo "== fresh server check =="
python3 tools/check_fresh_server.py
