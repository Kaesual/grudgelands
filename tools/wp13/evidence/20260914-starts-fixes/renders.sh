#!/usr/bin/env bash
# Overviews of the five starts this fix round moved, plus the one spot each
# review finding was about. `-before.png` files were rendered from the trees
# the fixes were applied to and are kept as the comparison.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-starts-fixes/renders"
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

# The fixed spot in each start.
python3 tools/wp13/render_blueprint.py "$tsv/dawnmere.tsv" \
	--region -22 -22 22 22 --scale 14 -o "$out/dawnmere-green-after.png" >/dev/null
python3 tools/wp13/render_blueprint.py "$tsv/stillgrave.tsv" \
	--region -54 -30 -22 -2 --ymax 6 --scale 16 \
	-o "$out/stillgrave-burial-walls-after.png" >/dev/null
python3 tools/wp13/render_blueprint.py "$tsv/silverleaf.tsv" \
	--region -26 -20 -12 -4 --view sw --scale 22 \
	-o "$out/silverleaf-terrace-back-after.png" >/dev/null
python3 tools/wp13/render_blueprint.py "$tsv/silverleaf.tsv" \
	--region -30 -26 -10 -2 --scale 18 \
	-o "$out/silverleaf-terrace-after.png" >/dev/null
python3 tools/wp13/render_blueprint.py "$tsv/sunscar.tsv" \
	--region 20 10 63 63 --scale 10 -o "$out/sunscar-outcrop-after.png" >/dev/null
python3 tools/wp13/render_blueprint.py "$tsv/kapok.tsv" \
	--region -12 -24 12 -12 --view sw --scale 22 \
	-o "$out/kapok-bridge-after.png" >/dev/null
rm -rf -- "$tsv"
echo "renders written to $out"
