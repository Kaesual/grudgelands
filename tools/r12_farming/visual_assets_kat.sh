#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}
textures="$repo/mods/ITEMS/grug_farming/textures"
mask_hash() {
	convert "$1" -alpha extract txt:- 2>/dev/null | sha256sum | awk '{print $1}'
}

blight=$(mask_hash "$textures/grug_farming_blightberry_4.png")
sun=$(mask_hash "$textures/grug_farming_sunberry_4.png")
jungle=$(mask_hash "$textures/grug_farming_jungle_berry_4.png")
[[ $blight != "$sun" && $blight != "$jungle" && $sun != "$jungle" ]]

for key in sugar_cane bamboo_shoot; do
	declare -A seen=()
	for stage in 1 2 3 4; do
		hash=$(mask_hash "$textures/grug_farming_${key}_${stage}.png")
		[[ -z ${seen[$hash]+x} ]]
		seen[$hash]=1
	done
	unset seen
done

printf 'r12_farming_visual_assets\tPASS\nberry_mature_masks\t3\nvertical_stage_masks\t8\n'
