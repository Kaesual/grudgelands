#!/usr/bin/env bash
# Rewrite files.sha256: every source file lane R changed or added.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
sha256sum \
	mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua \
	mods/MAPGEN/grug_mapgen/wp40/simple_map.lua \
	mods/MAPGEN/grug_mapgen/wp40/height.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_anchor_activation.lua \
	tools/wp40/r7/anchor_activation_kat.lua \
	tools/wp40/simple_map_r3_validate.lua \
	tools/wp40/simple_map_r3_selftest.lua \
	tools/wp13/route_gates.lua \
	tools/wp13/route_gates_kat.lua \
	tools/wp13/final_micro.lua \
	tools/wp13/evidence/20260915-route-gates/feature_map.lua \
	tools/wp13/evidence/20260915-route-gates/render_gate_approach.py \
	tools/wp13/evidence/20260915-route-gates/measure.sh \
	tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/avenue-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/avenue-digest-8675309.txt \
	tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/rampart-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/rampart-digest-8675309.txt \
	tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/gate-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/gate-digest-8675309.txt \
	tools/wp13/evidence/20260915-highcourt-fill/highcourt/avenue-digest-531802985935182545.txt \
	tools/wp13/evidence/20260915-highcourt-fill/highcourt/avenue-digest-8675309.txt \
	docs/research/wp13-route-gates.md \
	docs/research/wp13-capitals-pois-contract.md \
	tools/wp13/evidence/20260915-capital-terrain/README.md \
	tools/wp13/evidence/20260915-highcourt-fill/README.md \
	>tools/wp13/evidence/20260915-route-gates/files.sha256
echo "files.sha256 rewritten"
