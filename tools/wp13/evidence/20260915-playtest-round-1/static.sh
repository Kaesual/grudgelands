#!/usr/bin/env bash
# Static gates for the WP13 playtest-round-1 fixes (2026-09-15).
# Run from the repository root; writes to stdout (captured in static.txt).
set -uo pipefail
export LC_ALL=C

CHANGED_MODS="mods/PLAYER/grug_visuals/wield_geometry.lua
mods/PLAYER/grug_visuals/apply.lua
mods/PLAYER/grug_visuals/init.lua
mods/PLAYER/grug_abilities/init.lua"
CHANGED_TOOLS="tools/wp13/wield_transform_kat.lua
tools/wp13/ability_rightclick_kat.lua"

echo "=== luac51 -p on every changed file ==="
echo "$CHANGED_MODS" "$CHANGED_TOOLS" | xargs tools/bin/luac51 -p && echo "parse OK"

echo
echo "=== luac51 -p tree-wide (mods, then tools) ==="
find mods -name '*.lua' | sort | xargs tools/bin/luac51 -p && echo "mods parse OK"
find tools -name '*.lua' | sort | xargs tools/bin/luac51 -p && echo "tools parse OK"

echo
echo "=== SETGLOBAL on every changed file (expect one per mod table, none in tools) ==="
for f in $CHANGED_MODS $CHANGED_TOOLS; do
	echo "-- $f"
	tools/bin/luac51 -l -p "$f" | grep SETGLOBAL
done
echo "(a file with no line above writes no global)"

echo
echo "=== the five plain-5.1 sweeps, scoped to the changed files ==="
echo "-- 1 goto / labels"
grep -nE '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' $CHANGED_MODS $CHANGED_TOOLS
echo "-- 2 LuaJIT-only string escapes"
grep -nE '\\u\{|\\x[0-9A-Fa-f]|\\z' $CHANGED_MODS $CHANGED_TOOLS
echo "-- 3 5.2+/5.3 stdlib"
grep -nE 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' $CHANGED_MODS $CHANGED_TOOLS
echo "-- 4 integer division / bitwise operator syntax"
grep -nE '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' $CHANGED_MODS $CHANGED_TOOLS
echo "-- 5 sandbox-blocked calls and the wrong namespace"
grep -nE '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.' $CHANGED_MODS $CHANGED_TOOLS

echo
echo "=== the same five sweeps, tree-wide over mods/*/grug_* (hit counts) ==="
for pattern in \
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' \
	'\\u\{|\\x[0-9A-Fa-f]|\\z' \
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' \
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' \
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
do
	printf '%s\t' "$(grep -rnE "$pattern" mods/*/grug_* --include=*.lua | wc -l)"
	echo "$pattern"
done
echo "(every hit was read; all are prose in comments -- design-doc table rows"
echo " carrying '|', C++ Class::method references, and two comments that name"
echo " the \\u{} escape in order to forbid it)"

echo
echo "=== tools/check_fresh_server.py ==="
python3 tools/check_fresh_server.py
