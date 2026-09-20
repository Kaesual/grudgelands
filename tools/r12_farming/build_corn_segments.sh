#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}
textures="$repo/mods/ITEMS/grug_farming/textures"
for stage in 3 4; do
	if [[ $stage == 3 ]]; then height=2; else height=3; fi
	tmp=$(mktemp)
	convert "$textures/grug_farming_corn_${stage}.png" -filter point \
		-resize "16x$((height * 16))!" "$tmp"
	for ((segment=0; segment<height; segment++)); do
		# Image coordinates run top-down; segment 0 is the rooted bottom node.
		y=$(((height - segment - 1) * 16))
		convert "$tmp" -crop "16x16+0+$y" +repage \
			"$textures/grug_farming_corn_${stage}_segment_${segment}.png"
	done
	rm -f "$tmp"
done
