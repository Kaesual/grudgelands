#!/usr/bin/env bash
# The frozen-byte manifest for the Dur Brannoc upgrade: every Lua, Python and
# JSON input the checks above ran against, plus the evidence they produced.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-dur-brannoc-upgrade"
{
	find mods/MAPGEN/grug_mapgen/wp13 -name '*.lua' -print
	find tools/wp13/capital_probe -type f -print
	printf '%s\n' \
		mods/CORE/grug_core/settlement_sockets.lua \
		mods/ENTITIES/grug_mobs/start_npcs.lua \
		mods/ENTITIES/grug_traders/vendors.lua \
		mods/ITEMS/grug_nodes/init.lua \
		mods/MAPGEN/grug_mapgen/wp40/canonical.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_anchor_roster.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_content.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_dur_brannoc_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_highcourt_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_successor.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua \
		tools/wp13/blueprint_kat.lua \
		tools/wp13/capital_anchor_fixture.lua \
		tools/wp13/capital_lots.lua \
		tools/wp13/capital_plots.lua \
		tools/wp13/capital_timing.lua \
		tools/wp13/capital_wall.lua \
		tools/wp13/dur_brannoc_kat.lua \
		tools/wp13/engine_cases.lua \
		tools/wp13/final_micro.lua \
		tools/wp13/highcourt_identities.lua \
		tools/wp13/highcourt_kat.lua \
		tools/wp13/highcourt_plots.lua \
		tools/wp13/highcourt_timing.lua \
		tools/wp13/integration_fixture.lua \
		tools/wp13/library_kat.lua \
		tools/wp13/node_tiles.json \
		tools/wp13/render_blueprint.py \
		tools/wp13/run_capital.sh \
		tools/wp13/run_highcourt.sh \
		tools/wp13/seam_kat.lua \
		tools/wp13/settlement_sockets_kat.lua \
		tools/wp13/start_npcs_kat.lua \
		tools/wp13/stub_registry.lua
	find "$here" -type f ! -name files.sha256 -print
} | sort -u | xargs sha256sum >"$here/files.sha256"
wc -l <"$here/files.sha256"
