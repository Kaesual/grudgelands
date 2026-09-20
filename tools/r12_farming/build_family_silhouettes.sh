#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}
refs=${2:?reference-project root required}
out="$repo/mods/ITEMS/grug_farming/textures"
farm="$refs/farming/textures"
voxel="$refs/VoxeLibre/textures"
papyrus="$refs/minetest_game/mods/default/textures/default_papyrus.png"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for stage in 1 2 3 4; do
	cp "$farm/farming_blackberry_${stage}.png" "$out/grug_farming_blightberry_${stage}.png"
	cp "$voxel/mcl_farming_sweet_berry_bush_$((stage - 1)).png" \
		"$out/grug_farming_jungle_berry_${stage}.png"
done
for spec in "1:10:8" "2:12:10" "3:14:13" "4:16:15"; do
	IFS=: read -r stage width height <<<"$spec"
	convert "$farm/farming_raspberry_${stage}.png" -filter point \
		-resize "${width}x${height}!" -gravity south -background none -extent 16x16 \
		"$out/grug_farming_sunberry_${stage}.png"
done

# Full-family sprites remain useful for wild sources and catalogue plates.
# Cultivated multi-node plants below use the matching exact vertical slices.
for spec in "1:8:9" "2:10:12" "3:13:15" "4:16:16"; do
	IFS=: read -r stage width height <<<"$spec"
	convert "$papyrus" -filter point -resize "${width}x${height}!" \
		-gravity south -background none -extent 16x16 \
		"$out/grug_farming_sugar_cane_${stage}.png"
done
for spec in "1:7:8" "2:12:14"; do
	IFS=: read -r stage width height <<<"$spec"
	convert "$voxel/mcl_bamboo_bamboo_shoot.png" -filter point \
		-resize "${width}x${height}!" -gravity south -background none -extent 16x16 \
		"$out/grug_farming_bamboo_shoot_${stage}.png"
done
convert "$papyrus" -filter point -resize 10x16! -modulate 88,125,100 \
	-gravity south -background none -extent 16x16 "$tmpdir/bamboo_3.png"
convert "$voxel/mcl_bamboo_bamboo_shoot.png" -filter point -resize 9x9! \
	"$tmpdir/bamboo_leaf.png"
convert "$tmpdir/bamboo_3.png" "$tmpdir/bamboo_leaf.png" -geometry +7+0 \
	-composite "$out/grug_farming_bamboo_shoot_3.png"
convert "$papyrus" -filter point -resize 14x16! -modulate 82,135,100 \
	-gravity south -background none -extent 16x16 "$tmpdir/bamboo_4.png"
convert "$voxel/mcl_bamboo_bamboo_shoot.png" -filter point -resize 10x10! \
	"$tmpdir/bamboo_leaf.png"
convert "$tmpdir/bamboo_4.png" "$tmpdir/bamboo_leaf.png" -geometry +6+0 \
	-composite "$tmpdir/bamboo_4a.png"
convert "$tmpdir/bamboo_leaf.png" -flop "$tmpdir/bamboo_leaf_flop.png"
convert "$tmpdir/bamboo_4a.png" "$tmpdir/bamboo_leaf_flop.png" -geometry +0+2 \
	-composite "$out/grug_farming_bamboo_shoot_4.png"

slice_family() {
	local key=$1 stage=$2 height=$3 src=$4
	convert "$src" -filter point -resize "16x$((height * 16))!" "$tmpdir/tall.png"
	for ((level=0; level<height; level++)); do
		local y=$(((height - level - 1) * 16))
		convert "$tmpdir/tall.png" -crop "16x16+0+$y" +repage \
			"$out/grug_farming_${key}_${stage}_segment_${level}.png"
	done
}

for stage in 1 2 3 4; do
	slice_family sugar_cane "$stage" "$stage" \
		"$out/grug_farming_sugar_cane_${stage}.png"
done
slice_family bamboo_shoot 1 1 "$out/grug_farming_bamboo_shoot_1.png"
slice_family bamboo_shoot 2 1 "$out/grug_farming_bamboo_shoot_2.png"
slice_family bamboo_shoot 3 2 "$out/grug_farming_bamboo_shoot_3.png"
slice_family bamboo_shoot 4 3 "$out/grug_farming_bamboo_shoot_4.png"
