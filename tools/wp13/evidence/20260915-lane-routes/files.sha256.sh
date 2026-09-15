#!/usr/bin/env bash
# The frozen-byte manifest for the lane/route crossing rule: every input the
# checks above ran against, plus the evidence they produced.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-lane-routes"
{
	printf '%s\n' \
		mods/MAPGEN/grug_mapgen/wp13/avenue.lua \
		mods/MAPGEN/grug_mapgen/wp13/dur_brannoc.lua \
		mods/MAPGEN/grug_mapgen/wp13/highcourt.lua \
		mods/MAPGEN/grug_mapgen/wp13/highcourt_quadrants.lua \
		mods/MAPGEN/grug_mapgen/wp13/palette.lua \
		mods/MAPGEN/grug_mapgen/wp13/parts.lua \
		mods/MAPGEN/grug_mapgen/wp13/wall.lua \
		mods/MAPGEN/grug_mapgen/wp40/height.lua \
		mods/MAPGEN/grug_mapgen/wp40/planner.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/zones.lua \
		docs/research/wp13-lane-routes.md \
		tools/wp13/final_micro.lua \
		tools/wp13/lane_crossing_kat.lua \
		tools/wp13/lane_routes.lua \
		tools/wp13/run_capital.sh \
		tools/wp13/run_highcourt.sh
	find tools/wp13/highcourt_probe -type f -print
	find "$here" -type f ! -name files.sha256 -print
} | sort | xargs sha256sum >"$here/files.sha256"
wc -l <"$here/files.sha256"
