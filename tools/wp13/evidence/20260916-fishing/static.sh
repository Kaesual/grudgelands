#!/usr/bin/env bash
# Static gates for the WP13 wave-3 fishing/axe-orientation increment: the same
# set every WP13 increment runs -- parser and SETGLOBAL per changed file and
# tree-wide, the five plain-5.1 sweeps scoped and then tree-wide, the
# fresh-server audit, the LICENSE-media row check for every shipped PNG -- plus
# two measurements this lane's claims rest on:
#
#   * the rod sprite is already in the game's diagonal convention (an opaque
#     pixel under the fist at image (3, 12)), and
#   * which held sprites the new wield roll can move at all.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/PLAYER/grug_visuals/wield_geometry.lua
	mods/PLAYER/grug_visuals/apply.lua
	mods/ITEMS/grug_fishing/init.lua
	mods/ITEMS/grug_fishing/catch.lua
	mods/ENTITIES/grug_mobs/start_villagers.lua
	tools/wp13/wield_transform_kat.lua
	tools/wp13/fishing_kat.lua
	tools/wp13/start_npcs_kat.lua
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

echo "== every media file of the new mod has a LICENSE-media.md row =="
missing=0
for png in mods/ITEMS/grug_fishing/textures/*.png; do
	name="$(basename "$png")"
	if grep -qF "\`$name\`" mods/ITEMS/grug_fishing/LICENSE-media.md; then
		echo "$name licensed"
	else
		echo "$name MISSING FROM LICENSE-media.md"
		missing=$((missing + 1))
	fi
done
echo "media rows missing: $missing"

echo "== the imported rod is byte-identical to its upstream =="
sha256sum mods/ITEMS/grug_fishing/textures/grug_fishing_rod.png
sha256sum reference_projects/VoxeLibre/textures/mcl_fishing_fishing_rod.png ||
	echo "(submodule not checked out in this worktree; the hash in" \
		"LICENSE-media.md is the row to compare against)"

echo "== held-sprite measurements (the two numbers section 10 rests on) =="
python3 tools/wp13/evidence/20260916-fishing/sprite_axis.py
