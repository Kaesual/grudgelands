#!/usr/bin/env bash
# The frozen-byte manifest for WP13 playtest round 2: every production and tool
# file this round changed or ran against, plus the evidence it produced. Run it
# LAST -- it hashes this directory's own contents.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-npc-round-2"
{
	find tools/wp13/npc_probe -type f -print
	printf '%s\n' \
		AGENTS.md \
		VENDOR.md \
		docs/design/settlements.md \
		docs/design/world.md \
		docs/research/wp13-npc-round-2.md \
		docs/research/wp13-npc-sockets-contract.md \
		mods/CORE/grug_core/settlement_sockets.lua \
		mods/ENTITIES/grug_mobs/guard.lua \
		mods/ENTITIES/grug_mobs/init.lua \
		mods/ENTITIES/grug_mobs/start_npcs.lua \
		mods/ENTITIES/grug_mobs/start_villagers.lua \
		mods/ENTITIES/grug_mobs/verbs.lua \
		mods/ENTITIES/grug_traders/vendors.lua \
		mods/ENTITIES/mobs/api.lua \
		mods/MAPGEN/grug_mapgen/wp13/dawnmere.lua \
		mods/MAPGEN/grug_mapgen/wp13/hearthpine.lua \
		mods/MAPGEN/grug_mapgen/wp13/highcourt.lua \
		mods/MAPGEN/grug_mapgen/wp13/kapok.lua \
		mods/MAPGEN/grug_mapgen/wp13/silverleaf.lua \
		mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua \
		mods/MAPGEN/grug_mapgen/wp13/sunscar.lua \
		tools/luanti_headless.sh \
		tools/wp13/blueprint_kat.lua \
		tools/wp13/final_micro.lua \
		tools/wp13/highcourt_kat.lua \
		tools/wp13/integration_fixture.lua \
		tools/wp13/library_kat.lua \
		tools/wp13/run_npc_probe.sh \
		tools/wp13/seam_kat.lua \
		tools/wp13/settlement_sockets_kat.lua \
		tools/wp13/start_npcs_kat.lua \
		tools/wp13/stub_registry.lua
	find "$here" -type f ! -name files.sha256 -print
} | sort -u | xargs sha256sum >"$here/files.sha256"
wc -l <"$here/files.sha256"
