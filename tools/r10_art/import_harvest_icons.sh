#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out="$root/mods/ITEMS/grug_cooking/textures"
farm=/home/jan/projects/grudgelands/reference_projects/farming/textures
voxe=/home/jan/projects/grudgelands/reference_projects/VoxeLibre/textures
x=/home/jan/projects/grudgelands/reference_projects/x_farming/textures
gob=/home/jan/projects/grudgelands/reference_projects/goblins/textures
mkdir -p "$out"
copy() { cp "$2" "$out/grug_cooking_$1.png"; }
copy wild_grain "$farm/farming_wheat.png"
copy carrot "$farm/farming_carrot.png"
copy cassava "$farm/farming_potato.png"
copy wild_onion "$farm/crops_onion.png"
magick "$x/x_farming_carrot.png" -fill '#c02018' -colorize 40% -strip \
	"$out/grug_cooking_fire_pepper.png"
copy pumpkin "$x/x_farming_pumpkin_mash.png"
copy blightberry "$farm/farming_blackberry.png"
copy sunberry "$farm/ethereal_strawberry.png"
copy jungle_berry "$farm/farming_grapes.png"
copy frost_melon "$x/x_farming_melon.png"
copy sugar_cane "$voxe/mcl_core_reeds.png"
copy bamboo_shoot "$voxe/mcl_bamboo_bamboo_shoot.png"
copy cave_cap "$gob/goblins_mushroom_brown.png"
copy salt_crust "$x/x_farming_salt.png"
copy ember_moss "$x/x_farming_obsidian_wart_6.png"
