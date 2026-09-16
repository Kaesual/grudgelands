#!/usr/bin/env bash
# The three pictures playtest 5 asked for, before and after, drawn from the
# REAL terrain of the gate seed with `street_dump.lua` and
# `tools/wp13/render_blueprint.py`.
#
#   * a Dur Brannoc district lane where the blend band makes the road leave the
#     ground -- the wall the user saw, and the viaduct that replaces it;
#   * the Lethariel junction at 1894,-1405, which is the ring street's
#     north-east corner in anchor-relative coordinates (94, 95);
#   * a Highcourt river crossing on the east avenue.
#
# Usage: renders.sh [<tree to draw as BEFORE>]
#   with no argument only the after pictures are drawn.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260916-streets"
before_tree="${1:-}"
cd "$repo"
mkdir -p "$here/renders" "$here/renders/tsv"

SEED=8675309
# key  x1 z1 x2 z2  view  label
WINDOWS="
dur_brannoc:60:-14:130:14:ne:lane-on-the-slope
lethariel:72:74:118:118:ne:ring-corner-1894--1405
highcourt:150:-14:220:14:ne:river-crossing
"

draw() {
	local tree="$1" tag="$2" key="$3" x1="$4" z1="$5" x2="$6" z2="$7" \
		view="$8" label="$9"
	local tsv="$here/renders/tsv/$tag-$key-$label-$SEED.tsv"
	nice -n 19 luajit "$here/street_dump.lua" "$tree" "$key" "$SEED" \
		"$x1" "$z1" "$x2" "$z2" "$tsv"
	nice -n 19 python3 tools/wp13/render_blueprint.py "$tsv" \
		--view "$view" --scale 10 --max-pixels 3200 \
		-o "$here/renders/$tag-$key-$label.png" --quiet
}

for window in $WINDOWS; do
	IFS=: read -r key x1 z1 x2 z2 view label <<<"$window"
	draw "$repo" after "$key" "$x1" "$z1" "$x2" "$z2" "$view" "$label"
	if [[ -n "$before_tree" ]]; then
		draw "$before_tree" before "$key" "$x1" "$z1" "$x2" "$z2" "$view" \
			"$label"
	fi
done
echo "renders in $here/renders"
