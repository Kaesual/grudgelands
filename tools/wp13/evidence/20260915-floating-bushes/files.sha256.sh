#!/usr/bin/env bash
# The sources this lane changed or added, hashed.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
sha256sum \
	mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua \
	tools/wp40/r6/common.lua \
	tools/wp13/decoration_anchor_kat.lua \
	tools/wp13/run_bush_probe.sh \
	tools/wp13/bush_probe/init.lua \
	tools/wp13/bush_probe/mod.conf \
	tools/wp13/evidence/20260915-floating-bushes/static.sh \
	tools/wp13/evidence/20260915-floating-bushes/kat.sh \
	tools/wp13/evidence/20260915-floating-bushes/engine.sh \
	tools/wp13/evidence/20260915-floating-bushes/section.py \
	docs/research/wp13-floating-bushes.md
