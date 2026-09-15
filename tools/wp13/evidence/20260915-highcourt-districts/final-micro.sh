#!/usr/bin/env bash
# The single bounded final-byte process for the Highcourt districts increment:
# every WP13 fixture in one interpreter process, run once under LuaJIT and once
# under the engine's bundled PUC 5.1 build, with the exact input set hashed
# before and after so the two runs provably saw the same bytes.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260915-highcourt-districts/final-micro"
cd "$repo"
rm -rf "$out"
mkdir -p "$out"

INPUTS=(
	mods/CORE/grug_core/settlement_sockets.lua
	mods/ENTITIES/grug_mobs/start_npcs.lua
	mods/ENTITIES/grug_traders/vendors.lua
	mods/ITEMS/grug_nodes/init.lua
	mods/MAPGEN/grug_mapgen/wp13/avenue.lua
	mods/MAPGEN/grug_mapgen/wp13/buildings.lua
	mods/MAPGEN/grug_mapgen/wp13/capitals.lua
	mods/MAPGEN/grug_mapgen/wp13/dawnmere.lua
	mods/MAPGEN/grug_mapgen/wp13/dressing.lua
	mods/MAPGEN/grug_mapgen/wp13/hearthpine.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_district.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_district_homes.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_district_lore.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_district_martial.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_districts.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_plot.lua
	mods/MAPGEN/grug_mapgen/wp13/highcourt_quadrants.lua
	mods/MAPGEN/grug_mapgen/wp13/interiors.lua
	mods/MAPGEN/grug_mapgen/wp13/kapok.lua
	mods/MAPGEN/grug_mapgen/wp13/layout.lua
	mods/MAPGEN/grug_mapgen/wp13/palette.lua
	mods/MAPGEN/grug_mapgen/wp13/parts.lua
	mods/MAPGEN/grug_mapgen/wp13/roofs.lua
	mods/MAPGEN/grug_mapgen/wp13/silverleaf.lua
	mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua
	mods/MAPGEN/grug_mapgen/wp13/sunscar.lua
	mods/MAPGEN/grug_mapgen/wp40/canonical.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_highcourt_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua
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
( cd "$repo" && sha256sum \
	tools/wp13/evidence/20260915-highcourt-districts/final-micro/micro-luajit.tsv \
	tools/wp13/evidence/20260915-highcourt-districts/final-micro/micro-puc51.tsv ) \
	>"$out/digests.txt"
echo "WP13 FINAL MICRO PAIR BYTE-IDENTICAL"
cat "$out/digests.txt"
