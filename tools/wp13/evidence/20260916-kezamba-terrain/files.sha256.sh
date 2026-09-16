#!/usr/bin/env bash
# Re-take `files.sha256`: the sources this package changed.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
sha256sum \
	mods/MAPGEN/grug_mapgen/wp40/height.lua \
	mods/MAPGEN/grug_mapgen/wp13/troll_palette.lua \
	mods/MAPGEN/grug_mapgen/wp13/kezamba_plot.lua \
	mods/MAPGEN/grug_mapgen/wp13/kezamba_districts.lua \
	mods/MAPGEN/grug_mapgen/wp13/kezamba_lots.lua \
	tools/wp13/kezamba_water.lua \
	tools/wp13/kezamba_lots.lua \
	tools/wp13/kezamba_kat.lua \
	tools/wp13/capital_terrain_fixture.lua \
	tools/wp13/evidence/20260916-kezamba-terrain/capital_fields.lua \
	tools/wp13/evidence/20260915-capital-terrain/kezamba/avenue-digest-531802985935182545.txt \
	docs/research/wp13-kezamba.md \
	>tools/wp13/evidence/20260916-kezamba-terrain/files.sha256
cat tools/wp13/evidence/20260916-kezamba-terrain/files.sha256
