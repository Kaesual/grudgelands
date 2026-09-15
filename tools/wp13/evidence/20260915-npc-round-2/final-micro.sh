#!/usr/bin/env bash
# The single bounded final-byte process for WP13 playtest round 2: every WP13
# fixture in one interpreter process, run once under LuaJIT and once under the
# engine's bundled PUC 5.1 build, with the exact input set hashed before and
# after so the two runs provably saw the same bytes.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260915-npc-round-2/final-micro"
cd "$repo"
rm -rf "$out"
mkdir -p "$out"

# The round's own touched Lua plus everything final_micro.lua reads.
INPUTS=(
	mods/CORE/grug_core/settlement_sockets.lua
	mods/ENTITIES/grug_mobs/init.lua
	mods/ENTITIES/grug_mobs/verbs.lua
	mods/ENTITIES/grug_mobs/levels.lua
	mods/ENTITIES/grug_mobs/patrol.lua
	mods/ENTITIES/grug_mobs/guard.lua
	mods/ENTITIES/grug_mobs/start_npcs.lua
	mods/ENTITIES/grug_mobs/start_villagers.lua
	mods/ENTITIES/grug_traders/vendors.lua
	mods/MAPGEN/grug_mapgen/wp13/dawnmere.lua
	mods/MAPGEN/grug_mapgen/wp13/hearthpine.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt.lua
	mods/MAPGEN/grug_mapgen/wp13/kapok.lua
	mods/MAPGEN/grug_mapgen/wp13/silverleaf.lua
	mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua
	mods/MAPGEN/grug_mapgen/wp13/sunscar.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_successor.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua
	tools/wp13/blueprint_kat.lua
	tools/wp13/final_micro.lua
	tools/wp13/highcourt_kat.lua
	tools/wp13/integration_fixture.lua
	tools/wp13/library_kat.lua
	tools/wp13/seam_kat.lua
	tools/wp13/settlement_sockets_kat.lua
	tools/wp13/start_npcs_kat.lua
	tools/wp13/stub_registry.lua
	/usr/bin/luajit
	tools/bin/lua51
)

sha256sum "${INPUTS[@]}" >"$out/inputs-before.sha256"
luajit tools/wp13/final_micro.lua "$repo" "$out/micro-luajit.tsv" luajit \
	>"$out/micro-luajit.log"
tools/bin/lua51 tools/wp13/final_micro.lua "$repo" "$out/micro-puc51.tsv" puc51 \
	>"$out/micro-puc51.log"
sha256sum "${INPUTS[@]}" >"$out/inputs-after.sha256"
cmp "$out/inputs-before.sha256" "$out/inputs-after.sha256"
cmp "$out/micro-luajit.tsv" "$out/micro-puc51.tsv"
( cd "$out" && sha256sum micro-luajit.tsv micro-puc51.tsv ) >"$out/digests.txt"
echo "WP13 FINAL MICRO PAIR BYTE-IDENTICAL"
cat "$out/digests.txt"
