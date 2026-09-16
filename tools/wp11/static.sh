#!/usr/bin/env bash
# Static gates for WP11 lanes X1 + X2, the same set every WP13 increment ran:
# parser and SETGLOBAL per changed file and tree-wide, the five plain-5.1
# sweeps scoped to the changed Lua and then tree-wide over mods/*/grug_* and
# tools, and the fresh-server audit.
#
# Usage (from the repository root):  bash tools/wp11/static.sh
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/PLAYER/grug_classes/talents.lua
	mods/PLAYER/grug_classes/init.lua
	mods/PLAYER/grug_classes/stats.lua
	mods/PLAYER/grug_classes/selection.lua
	mods/PLAYER/grug_abilities/init.lua
	mods/PLAYER/grug_abilities/kits.lua
	mods/PLAYER/grug_inventory/equipment.lua
	mods/CORE/grug_core/combat.lua
	tools/wp11/talent_tree_kat.lua
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
python3 tools/check_fresh_server.py && echo "check_fresh_server PASS"

echo "== the WP40 unit suite is untouched by this lane =="
bash tools/wp40/r7/run.sh unit

echo "== the talent KAT, under both interpreters =="
# Scratch under common.md's /tmp/grug-w4-<lane>-* convention, and removed
# again: /tmp is a quota'd tmpfs shared by every lane.
scratch="$(mktemp -d /tmp/grug-w4-w1-static.XXXXXX)"
trap 'rm -rf "$scratch"' EXIT
luajit -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))' \
	> "$scratch/kat-luajit.txt"
"$repo/tools/bin/lua51" -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))' \
	> "$scratch/kat-puc.txt"
tail -1 "$scratch/kat-luajit.txt"
if cmp -s "$scratch/kat-luajit.txt" "$scratch/kat-puc.txt"; then
	echo "KAT byte-identical under LuaJIT and PUC 5.1: $(sha256sum < "$scratch/kat-luajit.txt")"
else
	echo "KAT INTERPRETER DRIFT"
	diff "$scratch/kat-luajit.txt" "$scratch/kat-puc.txt"
fi

echo "== ruling 19: no class carries more than Strike + 3 in its base kit =="
grep -c 'talent_gated = true' mods/PLAYER/grug_abilities/kits.lua

echo "== ruling 20: /class is gone, /race is not =="
grep -n 'register_set_command("' mods/PLAYER/grug_classes/selection.lua
