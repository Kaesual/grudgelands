#!/usr/bin/env bash
# The frozen-byte manifest for the Gor Drazhak package: every source this
# package's checks ran against, plus the evidence they produced.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-gor_drazhak"
{
	find mods/MAPGEN/grug_mapgen/wp13 -name '*.lua' -print
	find tools/wp13 -maxdepth 1 -name 'gor_drazhak*.lua' -print
	find tools/wp13/capital_probe -type f -print
	printf '%s\n' \
		mods/CORE/grug_core/settlement_sockets.lua \
		mods/ENTITIES/grug_mobs/start_npcs.lua \
		mods/ENTITIES/grug_traders/vendors.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_gor_drazhak_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua \
		tools/wp13/capital_wall.lua \
		tools/wp13/final_micro.lua \
		tools/wp13/run_capital.sh \
		docs/research/wp13-gor_drazhak.md
	find "$here" -type f ! -name 'files.sha256' -print
} | sort -u | xargs sha256sum
