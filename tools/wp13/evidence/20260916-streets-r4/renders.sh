#!/usr/bin/env bash
# The three places playtest 6 named, before and after, drawn from the REAL
# terrain of THE USER'S OWN SEED -- the world the findings were made in.
#
#   * Lethariel ~1900,-1400 (anchor-relative 100, 100): the north-east ring
#     corner over the mere, where "two street ends meet on a bridge over water
#     and the rail of each protrudes into the other street";
#   * Lethariel ~1700,-1400 (anchor-relative -100, 100): the north-west corner,
#     where "two streets overlay each other with a 2-node offset across the
#     walking direction";
#   * Kezamba ~1800,1595 (anchor-relative 0, 95): the north crossing over
#     water, where "the side rails leave only a one-node gap into the crossing".
#
# Usage: renders.sh [<tree to draw as BEFORE>]
#   with no argument only the after pictures are drawn.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260916-streets-r4"
before_tree="${1:-}"
cd "$repo"
mkdir -p "$here/renders" "$here/renders/tsv"

SEED=15912857179583385436
# key:x1:z1:x2:z2:view:label
WINDOWS="
lethariel:82:82:116:116:ne:ring-corner-northeast-1900--1400
lethariel:-116:78:-82:140:ne:ring-corner-northwest-1700--1400
kezamba:-18:74:18:114:ne:north-crossing-1800-1595
"

draw() {
	local tree="$1" tag="$2" key="$3" x1="$4" z1="$5" x2="$6" z2="$7" \
		view="$8" label="$9"
	local tsv="$here/renders/tsv/$tag-$key-$label-$SEED.tsv"
	local dump="$here/street_dump.lua"
	# THE BEFORE TREE DRAWS ITSELF. Round 4's dump passes two run-spec fields
	# wave 3's did not, and a tree that carries neither simply builds the road
	# it used to -- but a `main` checkout has no copy of this file, so the
	# before half is drawn with the dump that lives in THIS package, pointed at
	# that tree.
	nice -n 19 luajit "$dump" "$tree" "$key" "$SEED" \
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
