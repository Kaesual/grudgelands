#!/usr/bin/env bash
# Everything the four districts look like, for the user to look at.
#
# Three kinds of picture, and the difference between them matters:
#
#   * `renders/plot-*.png` -- one per plot, all 36, drawn from the COMPOSITION.
#     Flat ground, no terrain: this is the building, not the place.
#   * `renders/capital-<seed>.png` -- the whole capital on one plane, per gate
#     seed: the core, the four avenues, the ring street, the district lanes and
#     all 36 plots at the offsets THAT SEED's permutation gives them. This is
#     the plan, and it is the picture that shows which district took which
#     quadrant.
#   * `renders/built-*.png` -- read back out of the FINISHED MAP by the probe
#     (`tools/wp13/run_highcourt.sh <out> full <seed>`), so the terraces, the
#     river and the road as actually laid are in them.
#
# Usage: renders.sh [<engine output dir of a full run on the user seed>]
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-highcourt-districts"
built="${1:-}"
cd "$repo"
out="$here/renders"
tsv="$out/tsv"
rm -rf "$out"
mkdir -p "$tsv"

render() {
	python3 tools/wp13/render_blueprint.py "$1" -o "$2" --quiet "${@:3}"
}

echo "== every plot, from its composition =="
for plot in $(luajit tools/wp13/dump_highcourt.lua "$repo" plot --list); do
	luajit tools/wp13/dump_highcourt.lua "$repo" plot "$plot" --sockets \
		>"$tsv/plot-$plot.tsv"
	render "$tsv/plot-$plot.tsv" "$out/plot-$plot.png" --scale 12 \
		--max-pixels 1600
	printf '  %s\n' "$plot"
done

echo "== the whole capital, per gate seed =="
for seed in 531802985935182545 8675309; do
	luajit tools/wp13/dump_highcourt.lua "$repo" capital "$seed" \
		>"$tsv/capital-$seed.tsv"
	render "$tsv/capital-$seed.tsv" "$out/capital-$seed.png" --scale 4 \
		--max-pixels 6000
	printf '  %s\n' "$seed"
done

echo "== the core and one avenue run, from their compositions =="
luajit tools/wp13/dump_highcourt.lua "$repo" core >"$tsv/core.tsv"
render "$tsv/core.tsv" "$out/core.png" --scale 8 --max-pixels 3000
luajit tools/wp13/dump_highcourt.lua "$repo" avenue >"$tsv/avenue.tsv"
render "$tsv/avenue.tsv" "$out/avenue.png" --scale 10 --max-pixels 3000

if [[ -n "$built" && -d "$built" ]]; then
	echo "== as built, out of the finished map =="
	for index in 1 2 3 4; do
		source_tsv="$built/highcourt-plot-$index.tsv"
		[[ -f "$source_tsv" ]] || continue
		label="$(head -1 "$source_tsv" | sed 's/^# Highcourt district plot //;s/ .*//')"
		cp "$source_tsv" "$tsv/built-$label.tsv"
		render "$tsv/built-$label.tsv" "$out/built-$label.png" --scale 8 \
			--max-pixels 2400
		printf '  %s\n' "$label"
	done
	if [[ -f "$built/highcourt-avenue.tsv" ]]; then
		cp "$built/highcourt-avenue.tsv" "$tsv/built-avenue.tsv"
		render "$tsv/built-avenue.tsv" "$out/built-avenue.png" --scale 4 \
			--max-pixels 4000
		render "$tsv/built-avenue.tsv" "$out/built-avenue-night.png" --scale 4 \
			--max-pixels 4000 --light
	fi
fi

# The two capital plans and the core are fifteen and two megabytes of TSV that
# this script regenerates in seconds; what is KEPT is what an engine boot
# produced and nothing else can reproduce without one.
rm -f "$tsv/capital-"*.tsv "$tsv/core.tsv" "$tsv/avenue.tsv" "$tsv/plot-"*.tsv

find "$out" -name '*.png' | wc -l
