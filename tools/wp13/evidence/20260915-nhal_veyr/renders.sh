#!/usr/bin/env bash
# Nhal Veyr as BUILT, drawn from the TSVs the engine probe read back out of the
# finished map (`renders/tsv/`, user seed 531802985935182545) -- not from the
# composition, so what these pictures show is the capital the map has.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-nhal_veyr"
tsv="$here/renders/tsv"
out="$here/renders"
mkdir -p "$out"
render() { python3 tools/wp13/render_blueprint.py "$@" --quiet; }

# The civic core: the whole precinct first, then both diagonals and a night
# pass, because the thing this capital is made of is candlelight.
render "$tsv/nhal_veyr-core.tsv" -o "$out/core-overview.png" --view ne --scale 6
render "$tsv/nhal_veyr-core.tsv" -o "$out/core-ne.png" --view ne
render "$tsv/nhal_veyr-core.tsv" -o "$out/core-sw.png" --view sw
render "$tsv/nhal_veyr-core.tsv" -o "$out/core-night.png" --view ne --light

# The two quarters that carry this capital's identity: the mausoleum on its
# podium and the ossuary court.
render "$tsv/nhal_veyr-core.tsv" -o "$out/mausoleum.png" --view ne \
	--region -20 4 20 40
render "$tsv/nhal_veyr-core.tsv" -o "$out/ossuary-court.png" --view nw \
	--region 18 0 47 47
render "$tsv/nhal_veyr-core.tsv" -o "$out/ossuary-court-night.png" --view nw \
	--region 18 0 47 47 --light
# The burial ground on the turf between the quarters, with the gravewoods in it.
render "$tsv/nhal_veyr-core.tsv" -o "$out/burial-ground.png" --view ne \
	--region -24 -47 20 -16

# One district plot on its own terrace.
render "$tsv/nhal_veyr-plot.tsv" -o "$out/plot.png" --view ne

# The gate approach: the east avenue down the terraces, by day and by night.
render "$tsv/nhal_veyr-avenue.tsv" -o "$out/avenue-east.png" --view ne
render "$tsv/nhal_veyr-avenue.tsv" -o "$out/avenue-east-night.png" --view ne \
	--light

# THE WALL: a stretch of curtain crossing its terrace steps with a turret on
# it, and the east gatehouse with the road running through it.
render "$tsv/nhal_veyr-rampart.tsv" -o "$out/wall-terrace.png" --view ne
render "$tsv/nhal_veyr-rampart.tsv" -o "$out/wall-terrace-sw.png" --view sw
render "$tsv/nhal_veyr-gate.tsv" -o "$out/gatehouse.png" --view ne
render "$tsv/nhal_veyr-gate.tsv" -o "$out/gatehouse-night.png" --view ne --light

ls -la "$out"/*.png
