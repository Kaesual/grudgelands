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

# THE WHOLE CAPITAL ON ONE PLANE, which is the only picture that answers "how
# dense is this city" by eye. `tools/wp13/dump_capital_plan.lua` lays the core,
# all 52 plots at the offsets THIS WORLD'S permutation gives them, and every
# overlay run -- avenues, ring, the eight lanes, the curtain and its four gates
# -- on flat ground, so the terraces are out of the way and the plan is the
# subject. The seed is passed, so the quarters are labelled with the assignment
# the map really has and not the canonical one.
luajit tools/wp13/dump_capital_plan.lua . nhal_veyr 531802985935182545 \
	>"$tsv/nhal_veyr-plan.tsv"
render "$tsv/nhal_veyr-plan.tsv" -o "$out/capital-plan.png" --view ne --scale 2
render "$tsv/nhal_veyr-plan.tsv" -o "$out/capital-plan-night.png" --view ne \
	--scale 2 --light

# THE NORTH GATE APPROACH, read back out of the finished map: the axis whose
# ground falls fastest, out to the gate point at 261, which is the stretch the
# wave-2 review found the road standing over. `<key>-approach.tsv` is the region
# `capital_probe` added for it.
if [[ -f "$tsv/nhal_veyr-approach.tsv" ]]; then
	render "$tsv/nhal_veyr-approach.tsv" -o "$out/gate-approach.png" --view ne
	render "$tsv/nhal_veyr-approach.tsv" -o "$out/gate-approach-sw.png" --view sw
	render "$tsv/nhal_veyr-approach.tsv" -o "$out/gate-approach-night.png" \
		--view ne --light
fi

# A CORNER OF THE CURTAIN ON ITS REAL GROUND, where two runs' walks meet: the
# picture that goes with `wall.lua` section 1b. The probe's rampart dump is the
# east curtain either side of the anchor and carries no corner, so this one is
# built offline out of the same WP40 height session the corner proof uses
# (`corners/wall_cells.lua`) and cut to the north-east corner.
luajit "$here/corners/wall_cells.lua" . 531802985935182545 nhal_veyr \
	"$tsv/nhal_veyr-curtain.tsv"
awk -F'\t' 'NR > 1 && $2 >= 225 && $2 <= 262 && $4 >= 225 && $4 <= 262 \
	{ print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 }' \
	"$tsv/nhal_veyr-curtain.tsv" >"$tsv/nhal_veyr-corner.tsv"
rm -f "$tsv/nhal_veyr-curtain.tsv"
render "$tsv/nhal_veyr-corner.tsv" -o "$out/wall-corner.png" --view sw --scale 8

ls -la "$out"/*.png
