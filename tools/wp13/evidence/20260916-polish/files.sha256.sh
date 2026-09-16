#!/usr/bin/env bash
# The sources this lane added or changed against main f37a0c5b, hashed.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
sha256sum \
	mods/MAPGEN/grug_mapgen/wp13/elf_parts.lua \
	mods/MAPGEN/grug_mapgen/wp13/parts.lua \
	mods/MAPGEN/grug_mapgen/wp13/troll_palette.lua \
	mods/MAPGEN/grug_mapgen/wp13/highcourt.lua \
	mods/MAPGEN/grug_mapgen/wp13/highcourt_quadrants.lua \
	tools/wp13/lethariel_kat.lua \
	tools/wp13/kezamba_kat.lua \
	tools/wp13/capital_lots.lua \
	tools/wp13/capital_probe/init.lua \
	tools/wp13/npc_load_probe/init.lua \
	tools/wp13/run_npc_load.sh \
	tools/wp13/evidence/20260915-capital-terrain/gor_drazhak/corner-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/highcourt/avenue-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/highcourt/rampart-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/highcourt/corner-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/highcourt/gate-digest-531802985935182545.txt \
	docs/research/wp13-polish-wave3.md
