#!/usr/bin/env bash
# Highcourt as BUILT, drawn from the TSVs the engine probe read back out of the
# finished map (`renders/tsv/`, user seed 531802985935182545) -- not from the
# composition, so what these pictures show is the capital the map has.
#
# Plus one picture that is NOT read back: the capital PLAN, drawn from
# `dump_highcourt.lua capital` over flat ground, because "from above" over 500
# nodes of terraced terrain is the one view the read-back dumps cannot give
# (they are cut per feature).
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-highcourt-fill"
tsv="$here/renders/tsv"
out="$here/renders"
render() { python3 tools/wp13/render_blueprint.py "$@" --quiet; }

# FROM ABOVE: the whole capital as a plan -- the wall ring with its turrets and
# four gates, the four districts on their lot grids, and the sixteen dressings
# between them.
#
# NOT KEPT. The plan dump is three quarters of a million cells (the capital plus
# the 501-node ground plane it is drawn on), which is twenty megabytes of TSV
# for two pictures; it is a pure function of the tree and this line regenerates
# it, so it lives in a scratch file for the length of the run.
plan="$(mktemp -t highcourt-plan.XXXXXX.tsv)"
trap 'rm -f "$plan"' EXIT
luajit tools/wp13/dump_highcourt.lua . capital 531802985935182545 >"$plan"
render "$plan" -o "$out/plan.png" --view ne --scale 2
render "$plan" -o "$out/plan-quarter.png" --view ne --scale 4 \
	--region 40 -250 250 -40

# AT EYE LEVEL, from the map: the four things the user asked to see.
render "$tsv/highcourt-plot-5.tsv" -o "$out/pond.png" --view ne
render "$tsv/highcourt-plot-5.tsv" -o "$out/pond-sw.png" --view sw
render "$tsv/highcourt-plot-6.tsv" -o "$out/orchard.png" --view ne
render "$tsv/highcourt-plot-7.tsv" -o "$out/chapel-yard.png" --view ne
render "$tsv/highcourt-plot-7.tsv" -o "$out/chapel-yard-night.png" --view ne \
	--light
render "$tsv/highcourt-plot-8.tsv" -o "$out/smithy.png" --view ne

# THE WALL RING: a stretch of curtain over its terrace steps with a turret on
# it, and the east gatehouse with the avenue running through it.
render "$tsv/highcourt-wall.tsv" -o "$out/wall-turret.png" --view ne
render "$tsv/highcourt-wall.tsv" -o "$out/wall-turret-sw.png" --view sw
render "$tsv/highcourt-gate.tsv" -o "$out/gatehouse.png" --view ne
render "$tsv/highcourt-gate.tsv" -o "$out/gatehouse-night.png" --view ne --light

# One district plot on its own terrace, and the core, for context.
render "$tsv/highcourt-plot-1.tsv" -o "$out/plot-market.png" --view ne
render "$tsv/highcourt-core.tsv" -o "$out/core.png" --view ne --scale 4
ls -la "$out"/*.png
