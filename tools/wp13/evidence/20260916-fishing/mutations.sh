#!/usr/bin/env bash
# Break each shipped property ON PURPOSE and show the fixture going red.
#
# A KAT that has never been seen to fail is a KAT nobody has tested. Each case
# below edits ONE shipped source with `sed`, runs the fixture that is supposed
# to notice, prints its result line and its failures, and then restores the file
# from the commit -- so the tree is byte-identical afterwards, which the final
# `git status` line shows.
#
# Run from the repository root, on a clean tree:
#   bash tools/wp13/evidence/20260916-fishing/mutations.sh
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"

GEOMETRY=mods/PLAYER/grug_visuals/wield_geometry.lua
CATCH=mods/ITEMS/grug_fishing/catch.lua
INIT=mods/ITEMS/grug_fishing/init.lua

if [[ -n "$(git status --porcelain -- "$GEOMETRY" "$CATCH" "$INIT")" ]]; then
	echo "refusing to mutate a dirty tree" >&2
	exit 2
fi

run_kat() {
	# $1 = fixture path. Prints the result row and every failure row.
	luajit -e "io.write(dofile('$1')('.'))" 2>&1 |
		grep -E "_result|_failure" | head -8
}

case_() {
	# $1 = label, $2 = file, $3 = sed script, $4 = fixture
	echo
	echo "== $1"
	echo "-- mutation: sed '$3' $2"
	sed -i "$3" "$2"
	if git diff --quiet -- "$2"; then
		echo "!! the sed changed nothing -- this case is checking nothing"
	fi
	run_kat "$4"
	git checkout -- "$2"
}

echo "baseline"
run_kat tools/wp13/wield_transform_kat.lua
run_kat tools/wp13/fishing_kat.lua

case_ "M1 the axe pose is no longer a roll (spin stays +90)" \
	"$GEOMETRY" 's/^\t\tspin = -90$/\t\tspin = 90/' \
	tools/wp13/wield_transform_kat.lua

# M2 IS EXPECTED TO PASS, and is here to say so out loud. `tilt_sign` decides
# how the rolled pose treats TILT_UP, and TILT_UP is 0 -- so the sign is inert
# for every byte this lane ships and no fixture can see it. It is the same
# class of finding the round-2 review recorded for `e2_z`, and it is written
# down in docs/research/wp13-fishing.md rather than pretended away. Raise
# TILT_UP above 0 and this case has to start failing.
case_ "M2 the rolled pose ignores the tilt (EXPECTED PASS: TILT_UP is 0)" \
	"$GEOMETRY" 's/^\t\ttilt_sign = -1$/\t\ttilt_sign = 1/' \
	tools/wp13/wield_transform_kat.lua

case_ "M3 no family asks for the rolled pose" \
	"$GEOMETRY" 's/^local EDGE_DOWN_GROUP = {"axe"}$/local EDGE_DOWN_GROUP = {}/' \
	tools/wp13/wield_transform_kat.lua

case_ "M4 the rod is not a diagonal tool any more" \
	"$GEOMETRY" 's/"fishing_rod", "grug_equip_weapon"}/"grug_equip_weapon"}/' \
	tools/wp13/wield_transform_kat.lua

case_ "M5 the catch weights no longer sum to 100" \
	"$CATCH" 's/count = 1, weight = 78}/count = 1, weight = 77}/' \
	tools/wp13/fishing_kat.lua

case_ "M6 the bite is instant" \
	"$CATCH" 's/^local MIN_WAIT = 3$/local MIN_WAIT = 0/' \
	tools/wp13/fishing_kat.lua

case_ "M7 a second table is handed out on the other continent" \
	"$CATCH" 's/^\treturn WORLD$/\tif pos and pos.z < 0 then return {WORLD[1]} end\n\treturn WORLD/' \
	tools/wp13/fishing_kat.lua

case_ "M8 an angler may wander away from the line" \
	"$INIT" 's/^local REEL_RANGE = 8$/local REEL_RANGE = 100000/' \
	tools/wp13/fishing_kat.lua

case_ "M9 the rod cannot point at water" \
	"$INIT" 's/^\tliquids_pointable = true,$/\tliquids_pointable = false,/' \
	tools/wp13/fishing_kat.lua

case_ "M10 the catch is handed out without reading the clock" \
	"$INIT" 's/^\t\tif clock >= cast.due then$/\t\tif true then/' \
	tools/wp13/fishing_kat.lua

case_ "M11 a full pack silently eats the catch" \
	"$INIT" 's/^\t\tcore.add_item(player:get_pos(), left)$/\t\tleft = left/' \
	tools/wp13/fishing_kat.lua

echo
echo "== tree restored =="
git status --porcelain -- "$GEOMETRY" "$CATCH" "$INIT"
echo "(no lines above means byte-identical to the commit)"
