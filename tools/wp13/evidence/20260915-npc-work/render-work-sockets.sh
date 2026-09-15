#!/usr/bin/env bash
# One render per `work` socket of the six starts, so the user can see WHERE
# each worker stands and WHAT it is facing without opening the game.
#
# The renderer draws NODES; it cannot draw an entity, let alone an animated
# one. So these are not screenshots of a smith hammering -- the animation is
# documented by frame range and speed in docs/research/wp13-npc-work.md -- they
# are the place the smith stands and the anvil it looks at. The socket itself
# is the centre of each crop.
#
# Usage: render-work-sockets.sh [OUT_DIR]   (default: this directory/renders)
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../../.." && pwd -P)"
out="${1:-$here/renders}"
mkdir -p "$out"
cd "$repo"

# start  id  activity  x  z  view
rows=(
	"hearthpine work_woodpile chop -12 -13 ne"
	"hearthpine work_garden tend -19 21 ne"
	"dawnmere work_field farm 18 31 nw"
	"dawnmere work_green_seat sit -5 15 ne"
	"silverleaf work_planters tend 4 11 ne"
	"silverleaf work_market stall -33 5 se"
	"stillgrave work_gravewood chop 10 -6 ne"
	"stillgrave work_blightbed tend -22 -8 ne"
	"sunscar work_forge smith -34 2 ne"
	"sunscar work_acacia chop -14 -1 ne"
	"kapok work_jungle chop -29 13 ne"
	"kapok work_terrace sit -16 24 ne"
)

for row in "${rows[@]}"; do
	read -r start id activity x z view <<<"$row"
	x1=$((x - 9)); z1=$((z - 9)); x2=$((x + 9)); z2=$((z + 9))
	python3 tools/wp13/render_blueprint.py \
		"mods/MAPGEN/grug_mapgen/wp40/r7_${start}_blueprint.lua" \
		--region "$x1" "$z1" "$x2" "$z2" --view "$view" --scale 24 \
		--ymax 3 \
		-o "$out/${start}-${id}-${activity}.png"
	echo "rendered $start $id ($activity) at ($x, $z)"
done
