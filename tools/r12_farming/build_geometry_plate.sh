#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}
out=${2:?output path required}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
keys=(wild_grain carrot cassava wild_onion fire_pepper pumpkin blightberry sunberry jungle_berry frost_melon sugar_cane bamboo_shoot cave_cap salt_crust ember_moss potato corn)
tiles=()
height_for() {
	case "$1:$2" in
		sugar_cane:1) echo 1;; sugar_cane:2) echo 2;; sugar_cane:3) echo 3;; sugar_cane:4) echo 4;;
		bamboo_shoot:1|bamboo_shoot:2) echo 1;; bamboo_shoot:3) echo 2;; bamboo_shoot:4) echo 3;;
		corn:1|corn:2) echo 1;; corn:3) echo 2;; corn:4) echo 3;;
		*) echo 1;;
	esac
}
for key in "${keys[@]}"; do
	for stage in 1 2 3 4; do
		src="$repo/mods/ITEMS/grug_farming/textures/grug_farming_${key}_${stage}.png"
		dst="$tmpdir/${key}_${stage}.png"
		height=$(height_for "$key" "$stage")
		convert -size 144x528 xc:'#20252b' "$dst"
		for ((level=0; level<height; level++)); do
			y=$((384 - level * 128))
			segment_src=$src
			if [[ $key == corn && $stage -ge 3 ]]; then
				segment_src="$repo/mods/ITEMS/grug_farming/textures/grug_farming_corn_${stage}_segment_${level}.png"
			fi
			convert "$segment_src" -filter point -resize 128x128 "$tmpdir/sprite.png"
			convert "$dst" "$tmpdir/sprite.png" -geometry "+8+$y" -composite "$dst"
		done
		convert "$dst" -fill white -pointsize 12 -gravity south -annotate +0+4 "${key} ${stage} (${height}n)" "$dst"
		tiles+=("$dst")
	done
done
montage "${tiles[@]}" -tile 4x17 -geometry +2+2 -background '#101317' "$out"
