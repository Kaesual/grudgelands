#!/usr/bin/env bash
# The review renders of the Stillgrave increment, from the frozen bytes.
#
# `reference_projects/` is an unpopulated submodule inside a git worktree, so
# the vendored minetest_game textures are read from the main checkout with
# `--texture-root`; nothing is copied out of it.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-stillgrave/renders"
tsv="${TMPDIR:-/tmp}/stillgrave-cells.$$.tsv"
tex="${WP13_TEXTURE_ROOT:-/home/jan/projects/grudgelands/reference_projects/minetest_game/mods}"
luajit "$repo/tools/wp13/dump_blueprint.lua" \
	"$repo/mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua" >"$tsv"
render() { python3 "$repo/tools/wp13/render_blueprint.py" "$tsv" \
	--texture-root "$tex" "$@"; }

render -o "$out/overview-ne.png"
render --view sw -o "$out/overview-sw.png"
render --ymax 4 -o "$out/cutaway-ymax4.png"
render --light -o "$out/night.png"
render --region -14 -12 14 30 --scale 20 -o "$out/gravecourt.png"
render --region -12 -63 12 -48 --scale 20 -o "$out/gate-and-road.png"
render --region -8 9 8 30 --scale 26 -o "$out/gen-chapel-crypt-chapel.png"
render --region -8 9 8 30 --scale 26 --ymax 6 \
	-o "$out/gen-chapel-crypt-chapel-cutaway.png"
render --region 21 -10 42 10 --scale 26 -o "$out/gen-workshop-bone-works.png"
render --region -37 31 -24 46 --scale 30 -o "$out/gen-cottage-keepers-house.png"
render --region -21 31 -6 46 --scale 30 -o "$out/gen-cottage-warden-house.png"
render --region -1 31 13 46 --scale 30 -o "$out/gen-ruin-hollow-ruin.png"
render --region 15 31 31 46 --scale 30 -o "$out/gen-ruin-sunken-ruin.png"
render --region 2 -56 16 -42 --scale 30 -o "$out/gen-watchpost-watchtower.png"
render --region -52 -28 -24 -4 --scale 20 -o "$out/burial-ground-old.png"
rm -f "$tsv"
echo "renders written to $out"
