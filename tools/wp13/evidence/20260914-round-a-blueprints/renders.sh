#!/usr/bin/env bash
# The six overviews plus a close-up of every spot the user's playtest named:
# a Sunscar parapet where the deck meets the breastwork, a Sunscar wain, and
# one of Dawnmere's fields. `-before.png` files were rendered the same way
# from the tree these fixes were applied to and are kept as the comparison.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-round-a-blueprints/renders"
tsv="$(mktemp -d)"
cd "$repo"
mkdir -p "$out"

for key in hearthpine dawnmere silverleaf stillgrave sunscar kapok; do
	luajit tools/wp13/dump_blueprint.lua \
		"mods/MAPGEN/grug_mapgen/wp40/r7_${key}_blueprint.lua" >"$tsv/$key.tsv"
	python3 tools/wp13/render_blueprint.py "$tsv/$key.tsv" \
		--scale 8 -o "$out/$key-overview-ne.png" >/dev/null
	python3 tools/wp13/render_blueprint.py "$tsv/$key.tsv" \
		--view sw --scale 8 -o "$out/$key-overview-sw.png" >/dev/null
done

# The three spots the playtest was about, rendered as close as the dimetric
# camera gets: a tall thin crop with `--ymin` at the wall head, so the wall,
# the deck course and the breastwork standing on it are the whole picture.
#
# 1. The warlord hall's south-east parapet. Wall head y = 7, deck y = 8,
#    breastwork y = 9, merlons y = 10; before this round the deck was a bottom
#    slab and the breastwork began half a node above its surface.
render_spot() {
	local key="$1" name="$2"
	shift 2
	python3 tools/wp13/render_blueprint.py "$tsv/$key.tsv" "$@" \
		-o "$out/$name" >/dev/null
}

render_spot sunscar sunscar-parapet-after.png \
	--region -2 24 8 32 --ymin 5 --view sw --scale 26
render_spot sunscar sunscar-parapet-tower-after.png \
	--region -15 -61 -5 -51 --ymin 8 --scale 22
# 2. A wain: three acacia bearers, a wheel leaning on each, and the sawn-board
#    load that used to ride half a node above them.
render_spot sunscar sunscar-wain-after.png \
	--region 24 5 30 11 --ymax 4 --scale 34
# 3. A crop field: furrows and planted rows, all of it tilled soil now.
render_spot dawnmere dawnmere-field-after.png \
	--region 42 -12 60 12 --ymax 4 --scale 14
rm -rf -- "$tsv"
echo "renders written to $out"
