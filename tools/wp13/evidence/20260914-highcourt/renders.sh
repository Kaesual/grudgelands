#!/usr/bin/env bash
# The review loop for the Highcourt pilot: the core whole, from two sides, cut
# open at the king's hall and at night; every district plot; and the avenue
# overlay on the synthetic terrace profile the KAT uses.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-highcourt/renders"
tmp="$out/tsv"
cd "$repo"
mkdir -p "$out" "$tmp"

luajit tools/wp13/dump_highcourt.lua "$repo" core >"$tmp/core.tsv"
luajit tools/wp13/dump_highcourt.lua "$repo" core --sockets 2>/dev/null |
	grep '^#socket' >"$out/../sockets.txt"
luajit tools/wp13/dump_highcourt.lua "$repo" avenue >"$tmp/avenue.tsv"

shot() { # <tsv> <name> [render options...]
	local tag="$1" name="$2"
	shift 2
	python3 tools/wp13/render_blueprint.py "$tmp/$tag.tsv" \
		-o "$out/$name.png" "$@"
}

# The whole core, from both diagonals, and at night.
shot core core-ne --scale 9
shot core core-sw --scale 9 --view sw
shot core core-night --scale 9 --light

# The king's hall: outside, cut open at the aisle head (the throne, the dais,
# the carpet approach and the arcades), and at night.
shot core hall --region -22 2 22 45 --scale 14
shot core hall-cutaway --region -22 2 22 45 --scale 14 --ymax 8
shot core hall-night --region -22 2 22 45 --scale 14 --light
shot core hall-sw --region -22 2 22 45 --scale 14 --view sw

# The four quarters at a legible scale.
shot core quarter-market --region -47 -47 -3 -3 --scale 12
shot core quarter-plaza --region 3 -47 47 -3 --scale 12
shot core quarter-service --region 3 3 47 47 --scale 12
shot core quarter-chapel --region -47 3 -3 47 --scale 12
shot core crossing --region -20 -24 20 10 --scale 14
shot core gate-south --region -20 -47 20 -30 --scale 14

# Every district plot, and one cutaway per plot that has a room.
for id in $(luajit tools/wp13/dump_highcourt.lua "$repo" plot --list); do
	luajit tools/wp13/dump_highcourt.lua "$repo" plot "$id" >"$tmp/$id.tsv"
	shot "$id" "plot-$id" --scale 14
done
shot market_granary plot-market_granary-cutaway --scale 14 --ymax 4
shot market_stable plot-market_stable-cutaway --scale 14 --ymax 4
shot market_counting_house plot-market_counting_house-cutaway --scale 14 --ymax 5
shot market_watch plot-market_watch-cutaway --scale 14 --ymax 4
shot market_workshop plot-market_workshop-cutaway --scale 14 --ymax 4
shot market_store plot-market_store-cutaway --scale 14 --ymax 4

# The avenue overlay over its terraces, from both diagonals and at night.
shot avenue avenue --scale 12
shot avenue avenue-sw --scale 12 --view sw
shot avenue avenue-night --scale 12 --light

ls "$out" | wc -l
