#!/usr/bin/env bash
# Dur Brannoc as BUILT, drawn from the TSVs the engine probe read back out of
# the finished map (`renders/tsv/`, user seed 531802985935182545) -- not from
# the composition, so what these pictures show is the capital the map has.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-dur-brannoc"
tsv="$here/renders/tsv"
out="$here/renders"
render() { python3 tools/wp13/render_blueprint.py "$@" --quiet; }

# The civic core from both diagonals, and the forge court close up.
render "$tsv/dur_brannoc-core.tsv" -o "$out/core-ne.png" --view ne
render "$tsv/dur_brannoc-core.tsv" -o "$out/core-sw.png" --view sw
render "$tsv/dur_brannoc-core.tsv" -o "$out/core-night.png" --view ne --light
render "$tsv/dur_brannoc-core.tsv" -o "$out/forge-court.png" --view nw \
	--region 18 0 47 47
render "$tsv/dur_brannoc-core.tsv" -o "$out/kings-hall.png" --view ne \
	--region -20 4 20 40

# One district plot on its own terrace.
render "$tsv/dur_brannoc-plot.tsv" -o "$out/plot-charcoal.png" --view ne

# The east avenue down the terraces to the gate, by day and by night.
render "$tsv/dur_brannoc-avenue.tsv" -o "$out/avenue-east.png" --view ne
render "$tsv/dur_brannoc-avenue.tsv" -o "$out/avenue-east-night.png" --view ne \
	--light

# THE WALL: a stretch of curtain crossing its terrace steps with a turret on
# it, and the east gatehouse with the road running through it.
render "$tsv/dur_brannoc-rampart.tsv" -o "$out/wall-terrace.png" --view ne
render "$tsv/dur_brannoc-rampart.tsv" -o "$out/wall-terrace-sw.png" --view sw
render "$tsv/dur_brannoc-gate.tsv" -o "$out/gatehouse.png" --view ne
render "$tsv/dur_brannoc-gate.tsv" -o "$out/gatehouse-night.png" --view ne \
	--light

# Top-down-ish overviews: the whole core from a high scale, and the gate.
render "$tsv/dur_brannoc-core.tsv" -o "$out/core-overview.png" --view ne \
	--scale 6
ls -la "$out"/*.png
