#!/usr/bin/env bash
# Dur Brannoc as BUILT after the wave-2 upgrade, drawn from the TSVs the engine
# probe read back out of the finished map (`renders/tsv/`, user gate seed
# 531802985935182545) -- not from the composition, so what these pictures show
# is the capital the map has.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-dur-brannoc-upgrade"
tsv="$here/renders/tsv"
out="$here/renders"
render() { python3 tools/wp13/render_blueprint.py "$@" --quiet; }

# THE WHOLE CAPITAL ON ONE PLANE, which is the picture a reader compares
# densities with -- Highcourt's evidence has the same one
# (`20260915-highcourt-districts/renders/capital-<seed>.png`) and the
# city-common table's "Highcourt standard" is not a number anybody can see.
# Drawn from the COMPOSITION on flat ground, not from the map: the terraces are
# not in it, and that is what makes it readable as a plan.
echo "== the whole capital, per gate seed =="
for seed in 531802985935182545 8675309; do
	luajit tools/wp13/dump_capital_plan.lua "$repo" dur_brannoc "$seed" \
		>"$tsv/capital-$seed.tsv"
	render "$tsv/capital-$seed.tsv" -o "$out/capital-$seed.png" --scale 4 \
		--max-pixels 6000
done

# THE FOUR DISTRICTS are what this package exists for, so the district band and
# the fill dressing come first: a quarter with lanes and buildings either side,
# and the open ground between the quarters.
render "$tsv/dur_brannoc-district.tsv" -o "$out/district-ne.png" --view ne
render "$tsv/dur_brannoc-district.tsv" -o "$out/district-sw.png" --view sw
render "$tsv/dur_brannoc-district.tsv" -o "$out/district-night.png" --view ne \
	--light
render "$tsv/dur_brannoc-fill.tsv" -o "$out/fill-ore-court.png" --view ne
render "$tsv/dur_brannoc-fill.tsv" -o "$out/fill-ore-court-sw.png" --view sw

# One district plot on its own terrace, and the civic core it stands outside of.
render "$tsv/dur_brannoc-plot.tsv" -o "$out/plot-first.png" --view ne
render "$tsv/dur_brannoc-core.tsv" -o "$out/core-overview.png" --view ne \
	--scale 6

# The gate approach: the east avenue down the terraces, and the gatehouse the
# road runs through.
render "$tsv/dur_brannoc-avenue.tsv" -o "$out/avenue-east.png" --view ne
render "$tsv/dur_brannoc-gate.tsv" -o "$out/gatehouse.png" --view ne

# The two plan TSVs are tens of megabytes and are re-derived in seconds by the
# loop above; the read-back dumps are the ones worth committing, because they
# are what an engine boot produced.
rm -f "$tsv/capital-"*.tsv
ls -la "$out"/*.png
