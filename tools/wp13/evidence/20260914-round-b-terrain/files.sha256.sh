#!/usr/bin/env bash
# The frozen-byte manifest for this round: every Lua input the checks above ran
# against, plus the evidence they produced.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260914-round-b-terrain"
{
	printf '%s\n' \
		mods/MAPGEN/grug_mapgen/wp40/height.lua \
		mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua \
		mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/simple_map.lua \
		mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua \
		mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua \
		tools/wp13/engine_cases.lua \
		tools/wp13/final_micro.lua \
		tools/wp13/run_engine.sh \
		tools/wp13/terrain_fixture.lua \
		tools/wp40/quality_geometry_micro_kat.lua \
		tools/wp40/road_polish/measure.lua \
		tools/wp40/r7/anchor_activation_kat.lua
	find mods/MAPGEN/grug_mapgen/wp13 -name '*.lua' -print
	find "$here" -type f ! -name files.sha256 -print
} | sort -u | xargs sha256sum >"$here/files.sha256"
wc -l <"$here/files.sha256"
