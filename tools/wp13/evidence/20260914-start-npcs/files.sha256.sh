#!/usr/bin/env bash
# The frozen-byte manifest for this round: every Lua and shell input the checks
# above ran against, plus the evidence they produced.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260914-start-npcs"
{
	find mods/MAPGEN/grug_mapgen/wp13 -name '*.lua' -print
	printf '%s\n' \
		docs/design/settlements.md \
		docs/research/wp13-npc-sockets-contract.md \
		docs/research/wp13-start-npcs.md \
		mods/CORE/grug_core/init.lua \
		mods/CORE/grug_core/settlement_sockets.lua \
		mods/CORE/grug_core/starts_preload.lua \
		mods/CORE/grug_core/zone_authority.lua \
		mods/ENTITIES/grug_mobs/aggro.lua \
		mods/ENTITIES/grug_mobs/camps.lua \
		mods/ENTITIES/grug_mobs/guard.lua \
		mods/ENTITIES/grug_mobs/init.lua \
		mods/ENTITIES/grug_mobs/patrol.lua \
		mods/ENTITIES/grug_mobs/start_npcs.lua \
		mods/ENTITIES/grug_mobs/start_villagers.lua \
		mods/ENTITIES/grug_traders/vendors.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua \
		tools/luanti_headless.sh \
		tools/wp13/blueprint_kat.lua \
		tools/wp13/dump_blueprint.lua \
		tools/wp13/final_micro.lua \
		tools/wp13/integration_fixture.lua \
		tools/wp13/library_kat.lua \
		tools/wp13/settlement_sockets_kat.lua \
		tools/wp13/stub_registry.lua
	find "$here" -type f ! -name files.sha256 -print
} | sort -u | xargs sha256sum >"$here/files.sha256"
wc -l <"$here/files.sha256"
