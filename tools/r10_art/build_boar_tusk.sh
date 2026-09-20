#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source="$root/docs/research/r10-visuals/sources/boar-tusk-imagegen.png"
output="$root/mods/ENTITIES/grug_mobs/textures/grug_mobs_item_boar_tusk.png"
magick "$source" -trim -filter point -resize 14x14 -gravity center \
	-background none -extent 16x16 -strip "$output"
