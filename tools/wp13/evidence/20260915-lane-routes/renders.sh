#!/usr/bin/env bash
# Every route crossing of the two gate seeds, read back out of the FINISHED
# MAP, before this lane and after it.
#
# The two halves are two engine passes of the same runner on the same seed with
# the same crossing boxes; the only difference is whether
# `mods/MAPGEN/grug_mapgen/wp13/avenue.lua` is this lane's or `main`'s. So the
# terrain, the river, the bridge and the rest of the capital are identical
# between a pair of pictures and the road is the only thing that moved.
#
# Usage: renders.sh <before engine dir A> <after engine dir A> \
#                   <before engine dir B> <after engine dir B>
#
# Each directory is the output of
#   WP13_HIGHCOURT_CROSSING=<boxes> tools/wp13/run_highcourt.sh <out> full <seed>
# with the boxes recorded in README.md.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-lane-routes"
cd "$repo"
out="$here/renders"
rm -rf "$out"
mkdir -p "$out"

render() {
	python3 tools/wp13/render_blueprint.py "$1" -o "$2" --quiet "${@:3}"
}

pair() {
	local seed_label="$1" when="$2" dir="$3"
	local index
	for index in 1 2 3 4; do
		local tsv="$dir/highcourt-crossing-$index.tsv"
		[[ -f "$tsv" ]] || continue
		# Two views of every crossing. The whole box shows the road in its
		# valley; the `--ymin` cut drops the bedrock under the river so the
		# deck, the air under it and the road are the only things left.
		render "$tsv" "$out/crossing-$seed_label-$index-$when.png" \
			--scale 10 --max-pixels 3000
		render "$tsv" "$out/crossing-$seed_label-$index-$when-cut.png" \
			--scale 12 --max-pixels 3000 --ymin -8 --view sw
		printf '  %s crossing %s %s\n' "$seed_label" "$index" "$when"
	done
}

pair user before "$1"
pair user after "$2"
pair boundary before "$3"
pair boundary after "$4"

find "$out" -name '*.png' | wc -l
