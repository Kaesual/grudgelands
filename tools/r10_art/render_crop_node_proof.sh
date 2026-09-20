#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch=${TMPDIR:-/tmp}/grudgelands-r10-crop-proof
rm -rf "$scratch"; mkdir -p "$scratch"; trap 'rm -rf "$scratch"' EXIT HUP INT TERM
for stage in 1 2 3 4; do
	magick "$root/mods/ITEMS/grug_farming/textures/grug_farming_salt_crust_${stage}.png" -crop 16x16+0+0 +repage "$scratch/salt_top_${stage}.png"
done
export GRUG_ROOT="$root" GRUG_CROP_PROOF="$scratch" HOME="$scratch"
timeout --kill-after=5s 70s blender --background --python "$root/tools/r10_art/render_crop_node_proof.py" ||
	test -s "$scratch/salt_crust_4.png"
for family in sugar_cane bamboo_shoot salt_crust; do
	magick montage "$scratch/${family}_1.png" "$scratch/${family}_2.png" "$scratch/${family}_3.png" "$scratch/${family}_4.png" -tile 4x1 -geometry 192x192+4+22 -pointsize 18 -set label '%t' "$scratch/${family}.png"
done
magick montage "$scratch/sugar_cane.png" "$scratch/bamboo_shoot.png" "$scratch/salt_crust.png" -tile 1x3 -geometry +0+8 "$root/docs/research/r10-visuals/crop-node-visual-proof.png"
