#!/usr/bin/env bash
# Static gates for the WP13 start-NPC increment: parser and SETGLOBAL per file
# this round touched and tree-wide, the five plain-5.1 sweeps scoped to those
# files and then to the whole WP13 surface, the settlement identity check and
# the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/CORE/grug_core/init.lua
	mods/CORE/grug_core/settlement_sockets.lua
	mods/ENTITIES/grug_mobs/guard.lua
	mods/ENTITIES/grug_mobs/init.lua
	mods/ENTITIES/grug_mobs/patrol.lua
	mods/ENTITIES/grug_mobs/start_npcs.lua
	mods/ENTITIES/grug_mobs/start_villagers.lua
	mods/ENTITIES/grug_traders/vendors.lua
	mods/MAPGEN/grug_mapgen/wp13/dawnmere.lua
	mods/MAPGEN/grug_mapgen/wp13/hearthpine.lua
	mods/MAPGEN/grug_mapgen/wp13/kapok.lua
	mods/MAPGEN/grug_mapgen/wp13/silverleaf.lua
	mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua
	mods/MAPGEN/grug_mapgen/wp13/sunscar.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua
	tools/wp13/blueprint_kat.lua
	tools/wp13/final_micro.lua
	tools/wp13/settlement_sockets_kat.lua
)

echo "== parser and SETGLOBAL on every Lua file this round touched =="
echo "   (the two expected SETGLOBALs are the one-global-per-mod declarations"
echo "    grug_core = {} and grug_mobs = {} in the two init.lua files)"
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

echo "== five plain-5.1 sweeps, scoped to the Lua this round touched =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over the whole WP13 surface =="
echo "   Every hit here is pre-existing and none is a plain-5.1 problem; they"
echo "   are all PROSE or tool-only code, which is why the scoped run above is"
echo "   the one that has to be empty:"
echo "    * sweep 2: two comments that say \\u{} escapes are LuaJIT-only"
echo "    * sweep 4: design-doc tables quoted in comments, written with '|'"
echo "    * sweep 5: comments naming minetest.conf, and os.exit in"
echo "      tools/wp13/dump_blueprint.lua, which never runs inside the engine"
sweeps mods/CORE/grug_core mods/ENTITIES/grug_mobs mods/ENTITIES/grug_traders \
	mods/MAPGEN/grug_mapgen/wp13 tools/wp13

echo "== the six settlement identities did not move =="
bash "$repo/tools/wp13/evidence/20260914-start-npcs/dump.sh" "$repo" \
	>"/tmp/wp13-start-npcs-dumps.txt"
if diff "$repo/tools/wp13/evidence/20260914-round-a-blueprints/dumps.txt" \
		"/tmp/wp13-start-npcs-dumps.txt"; then
	echo "blueprint cell bytes UNCHANGED against the round-A record"
fi
rm -f -- /tmp/wp13-start-npcs-dumps.txt

echo "== fresh server check =="
python3 tools/check_fresh_server.py
