#!/usr/bin/env bash
# The frozen-byte manifest for this lane: every Lua and JSON input the checks
# ran against, plus the evidence they produced.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260914-highcourt"
{
	find mods/MAPGEN/grug_mapgen/wp13 -name '*.lua' -print
	printf '%s\n' \
		docs/research/wp13-capital-library.md \
		docs/research/wp13-capitals-pois-contract.md \
		docs/research/wp13-highcourt.md \
		docs/research/wp13-npc-sockets-contract.md \
		mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_successor.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua \
		tools/wp13/blueprint_kat.lua \
		tools/wp13/dump_blueprint.lua \
		tools/wp13/dump_capital_part.lua \
		tools/wp13/dump_highcourt.lua \
		tools/wp13/final_micro.lua \
		tools/wp13/highcourt_kat.lua \
		tools/wp13/highcourt_timing.lua \
		tools/wp13/integration_fixture.lua \
		tools/wp13/library_kat.lua \
		tools/wp13/node_tiles.json \
		tools/wp13/render_blueprint.py \
		tools/wp13/stub_registry.lua
	find "$here" -type f ! -name files.sha256 -print
} | sort -u | xargs sha256sum >"$here/files.sha256"
wc -l <"$here/files.sha256"
