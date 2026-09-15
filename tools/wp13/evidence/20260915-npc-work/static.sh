#!/usr/bin/env bash
# Static gates for the WP13 round-3 NPC-work increment, the same set the
# previous WP13 increments ran: parser and SETGLOBAL per changed file and
# tree-wide, the five plain-5.1 sweeps scoped to the changed Lua and then
# tree-wide over mods/*/grug_* and tools, the fresh-server audit, the two KATs
# under both interpreters, and the six start identities.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"
LUA51="$repo/tools/bin/lua51"

CHANGED=(
	mods/ENTITIES/grug_mobs/levels.lua
	mods/ENTITIES/grug_mobs/start_villagers.lua
	mods/ENTITIES/grug_mobs/start_npcs.lua
	mods/ENTITIES/grug_traders/vendors.lua
	mods/ENTITIES/grug_traders/stock.lua
	mods/ENTITIES/grug_traders/trade.lua
	mods/MAPGEN/grug_mapgen/wp13/hearthpine.lua
	mods/MAPGEN/grug_mapgen/wp13/dawnmere.lua
	mods/MAPGEN/grug_mapgen/wp13/silverleaf.lua
	mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua
	mods/MAPGEN/grug_mapgen/wp13/sunscar.lua
	mods/MAPGEN/grug_mapgen/wp13/kapok.lua
	tools/wp13/blueprint_kat.lua
	tools/wp13/start_npcs_kat.lua
	tools/wp13/npc_probe/init.lua
	tools/wp13/npc_load_probe/init.lua
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

echo "== the six start identities are untouched by the new sockets =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .

echo "== start_npcs_kat under both interpreters =="
luajit -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))' \
	>/tmp/npcwork-kat-jit.txt
"$LUA51" -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))' \
	>/tmp/npcwork-kat-puc.txt
diff /tmp/npcwork-kat-jit.txt /tmp/npcwork-kat-puc.txt &&
	echo "start_npcs_kat identical under both interpreters"
cat /tmp/npcwork-kat-jit.txt

echo "== blueprint_kat under both interpreters =="
luajit -e 'io.write(dofile("tools/wp13/blueprint_kat.lua")("."))' \
	>/tmp/npcwork-bp-jit.txt
"$LUA51" -e 'io.write(dofile("tools/wp13/blueprint_kat.lua")("."))' \
	>/tmp/npcwork-bp-puc.txt
diff /tmp/npcwork-bp-jit.txt /tmp/npcwork-bp-puc.txt &&
	echo "blueprint_kat identical under both interpreters"
cat /tmp/npcwork-bp-jit.txt

echo "== the neighbouring fixtures this increment must not move =="
for kat in settlement_sockets_kat seam_kat library_kat highcourt_kat \
		dur_brannoc_kat; do
	echo "-- $kat"
	luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" | tail -2
done
