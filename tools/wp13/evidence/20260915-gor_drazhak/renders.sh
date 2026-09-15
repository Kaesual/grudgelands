#!/usr/bin/env bash
# Gor Drazhak as BUILT, drawn from the TSVs the engine probe read back out of
# the finished map (`renders/tsv/`, seed 531802985935182545) -- not from the
# composition, so what these pictures show is the capital the map has.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-gor_drazhak"
tsv="$here/renders/tsv"
out="$here/renders"
render() { python3 tools/wp13/render_blueprint.py "$@" --quiet; }

# The civic core from both diagonals, at a small scale and at night.
render "$tsv/gor_drazhak-core.tsv" -o "$out/core-ne.png" --view ne
render "$tsv/gor_drazhak-core.tsv" -o "$out/core-sw.png" --view sw
render "$tsv/gor_drazhak-core.tsv" -o "$out/core-night.png" --view ne --light

# The two quarters that carry this capital's identity: the muster court, and
# the warlord hall with the fighting platform on its forecourt.
render "$tsv/gor_drazhak-core.tsv" -o "$out/muster-court.png" --view nw \
	--region 18 0 47 47
render "$tsv/gor_drazhak-core.tsv" -o "$out/warlord-hall.png" --view ne \
	--region -20 0 20 40

# One district plot on its own terrace.
render "$tsv/gor_drazhak-plot.tsv" -o "$out/district-plot.png" --view ne

# An avenue down the terraces to the gate, by day and by night.
render "$tsv/gor_drazhak-avenue.tsv" -o "$out/avenue-east.png" --view ne
render "$tsv/gor_drazhak-avenue.tsv" -o "$out/avenue-east-night.png" --view ne \
	--light

# THE RAMPART: a stretch of bank and stockade crossing its terrace steps with a
# tower on it, and the gate with the road running through it.
render "$tsv/gor_drazhak-rampart.tsv" -o "$out/rampart-terrace.png" --view ne
render "$tsv/gor_drazhak-rampart.tsv" -o "$out/rampart-terrace-sw.png" --view sw
render "$tsv/gor_drazhak-rampart.tsv" -o "$out/rampart-night.png" --view ne \
	--light
render "$tsv/gor_drazhak-gate.tsv" -o "$out/gate.png" --view ne
render "$tsv/gor_drazhak-gate.tsv" -o "$out/gate-night.png" --view ne --light

# THE WHOLE CAPITAL ON ONE FLAT PLANE, which is the picture to compare one
# capital's density with another's by. It is not read out of the map: the
# ground is flat and the terraces are not in it, which is what makes it a PLAN.
# `dump_capital_plan.lua` is Lane D's generic dumper and it takes the world
# seed, so the quarters are the ones this world's permutation gives. Its TSV is
# 789 883 cells and 23 MB, so it is written to scratch and NOT committed -- the
# PNG is the evidence and this line is how to get the TSV back.
plan="${TMPDIR:-/tmp}/gor_drazhak-plan.tsv"
luajit tools/wp13/dump_capital_plan.lua . gor_drazhak 531802985935182545 >"$plan"
render "$plan" -o "$out/plan-whole-capital.png" --view ne
