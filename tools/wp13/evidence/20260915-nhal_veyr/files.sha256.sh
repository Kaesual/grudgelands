#!/usr/bin/env bash
# The frozen-byte manifest of this increment: every source it changed, every
# tool it added, and every artefact in this directory, so a reviewer can tell
# which bytes produced which numbers.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-nhal_veyr"
{
	echo "== sources this increment changed"
	sha256sum \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_plot.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_quadrants.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_districts.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_martial.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_lore.lua \
		mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_homes.lua \
		mods/MAPGEN/grug_mapgen/wp13/undead_parts.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_nhal_veyr_blueprint.lua \
		mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
		tools/wp13/nhal_veyr_kat.lua \
		tools/wp13/nhal_veyr_plots.lua \
		tools/wp13/final_micro.lua \
		docs/research/wp13-nhal_veyr.md \
		docs/design/settlements.md

	echo "== the shared library this increment did NOT change"
	sha256sum \
		mods/MAPGEN/grug_mapgen/wp13/parts.lua \
		mods/MAPGEN/grug_mapgen/wp13/palette.lua \
		mods/MAPGEN/grug_mapgen/wp13/buildings.lua \
		mods/MAPGEN/grug_mapgen/wp13/capitals.lua \
		mods/MAPGEN/grug_mapgen/wp13/dressing.lua \
		mods/MAPGEN/grug_mapgen/wp13/interiors.lua \
		mods/MAPGEN/grug_mapgen/wp13/layout.lua \
		mods/MAPGEN/grug_mapgen/wp13/roofs.lua \
		mods/MAPGEN/grug_mapgen/wp13/avenue.lua \
		mods/MAPGEN/grug_mapgen/wp13/wall.lua \
		mods/MAPGEN/grug_mapgen/wp13/highcourt_plot.lua \
		mods/MAPGEN/grug_mapgen/wp13/highcourt_quadrants.lua

	echo "== the harness"
	find tools/wp13/capital_probe tools/wp13/run_capital.sh -type f |
		sort | xargs sha256sum

	echo "== the artefacts of this directory"
	find "$here" -type f ! -name files.sha256 | sort | xargs sha256sum
} > "$here/files.sha256"
wc -l "$here/files.sha256"
