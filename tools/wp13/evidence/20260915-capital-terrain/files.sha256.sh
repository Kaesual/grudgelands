#!/usr/bin/env bash
# The frozen-byte manifest of this package: every source file it changed, every
# tool it added or moved, and every artefact in this directory.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="tools/wp13/evidence/20260915-capital-terrain"
cd "$repo"
{
	sha256sum \
		mods/MAPGEN/grug_mapgen/wp13/highcourt_quadrants.lua \
		mods/MAPGEN/grug_mapgen/wp40/height.lua \
		mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua \
		mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua \
		mods/MAPGEN/grug_mapgen/wp40/simple_map.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_anchor_activation.lua \
		tools/wp13/capital_anchor_fixture.lua \
		tools/wp13/capital_terrain_fixture.lua \
		tools/wp13/highcourt_kat.lua \
		tools/wp13/highcourt_plots.lua \
		tools/wp13/highcourt_probe/init.lua \
		tools/wp13/render_terraces.py \
		tools/wp13/run_capital.sh \
		tools/wp13/run_highcourt.sh \
		tools/wp40/planner_throughput/fixture.lua \
		docs/research/wp13-capital-terrain.md
	find "$here" -type f ! -name files.sha256 -print0 | sort -z |
		xargs -0 sha256sum
} >"$here/files.sha256"
wc -l "$here/files.sha256"
