#!/usr/bin/env bash
# The throne renders of playtest round 1.
#
# `render_blueprint.py` drew `grug_decor:xdecor_chair` as a generic inset box
# until this round, so a picture could not show which way a king faces and the
# defect the user reported was invisible to the review loop. The renderer now
# knows the chair's two load-bearing boxes -- seat and back -- and turns them
# with the facedir, so these three pictures are the evidence and not decoration:
#
#   throne-orientation-reference  a chair at param2 0 with a GOLD block one node
#                                 at +z and an OBSIDIAN block one node at +x, so
#                                 the view's axes are readable off the picture
#                                 itself: the back sits on the gold side
#   king_hall-throne-before       the hall's dais with the rejected facedir: the
#                                 back stands between the king and his hall
#   king_hall-throne-after        the same cells with the fix: the back is
#                                 against the masonry screen and the seat looks
#                                 down the carpet at the great door
#
# `before` is produced from a scratch copy of `wp13/` with one literal changed,
# because the point of the pair is that ONE cell moved.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260915-apron-and-throne/renders"
tmp="${1:?absent absolute scratch directory required}"
[[ "$tmp" == /* && ! -e "$tmp" ]] || exit 2
cd "$repo"
mkdir -p "$out/tsv" "$tmp/before/mods/MAPGEN/grug_mapgen/wp13"

# Highcourt builds the hall at its own depth (`highcourt.lua`'s HALL.d = 27),
# not at the generator's default 39, so the render is the hall the capital has.
luajit tools/wp13/dump_capital_part.lua "$repo" human king_hall d=27 \
	>"$out/tsv/human-king_hall-d27.tsv"

cp "$repo/mods/MAPGEN/grug_mapgen/wp13/"*.lua \
	"$tmp/before/mods/MAPGEN/grug_mapgen/wp13/"
sed -i 's/^\t\tlocal throne_look = 2 .*$/\t\tlocal throne_look = 0 -- BEFORE/' \
	"$tmp/before/mods/MAPGEN/grug_mapgen/wp13/capitals.lua"
grep -q 'throne_look = 0 -- BEFORE' \
	"$tmp/before/mods/MAPGEN/grug_mapgen/wp13/capitals.lua"
luajit tools/wp13/dump_capital_part.lua "$tmp/before" human king_hall d=27 \
	>"$tmp/hall-before.tsv"
# Exactly one cell may differ between the two, and it is the chair.
diff "$tmp/hall-before.tsv" "$out/tsv/human-king_hall-d27.tsv" \
	>"$out/tsv/before-after.diff" || true
[[ "$(grep -c '^[<>]' "$out/tsv/before-after.diff")" -eq 2 ]]

printf '0\t0\t0\tgrug_decor:xdecor_chair\t0\n0\t0\t3\tdefault:goldblock\t0\n3\t0\t0\tdefault:obsidian\t0\n0\t-1\t0\tdefault:stone\t0\n0\t-1\t3\tdefault:stone\t0\n3\t-1\t0\tdefault:stone\t0\n' \
	>"$out/tsv/orientation-reference.tsv"

render() { python3 tools/wp13/render_blueprint.py "$@"; }
render "$out/tsv/orientation-reference.tsv" \
	-o "$out/throne-orientation-reference.png" --view sw --scale 96
render "$tmp/hall-before.tsv" -o "$out/king_hall-throne-before.png" \
	--view sw --ymin 5 --ymax 6 --region 14 23 16 25 --scale 120
render "$out/tsv/human-king_hall-d27.tsv" \
	-o "$out/king_hall-throne-after.png" \
	--view sw --ymin 5 --ymax 6 --region 14 23 16 25 --scale 120
# The dais in context, so the throne is seen as the end of the approach.
render "$out/tsv/human-king_hall-d27.tsv" -o "$out/king_hall-dais-after.png" \
	--view sw --ymax 9 --region 12 19 18 26 --scale 48
rm -rf -- "$tmp"
ls "$out"
