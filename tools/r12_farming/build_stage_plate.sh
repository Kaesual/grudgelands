#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}
out=${2:?output path required}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
keys=(wild_grain carrot cassava wild_onion fire_pepper pumpkin blightberry sunberry jungle_berry frost_melon sugar_cane bamboo_shoot cave_cap salt_crust ember_moss potato corn)
tiles=()
for key in "${keys[@]}"; do
	for stage in 1 2 3 4; do
		src="$repo/mods/ITEMS/grug_farming/textures/grug_farming_${key}_${stage}.png"
		dst="$tmpdir/${key}_${stage}.png"
		convert "$src" -filter point -resize 128x128 -gravity south -background '#20252b' -extent 144x160 \
			-fill white -pointsize 12 -annotate +0+4 "${key} ${stage}" "$dst"
		tiles+=("$dst")
	done
done
montage "${tiles[@]}" -tile 4x17 -geometry +2+2 -background '#101317' "$out"
