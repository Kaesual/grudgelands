#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out="$root/mods/ITEMS/grug_farming/textures"
x=/home/jan/projects/grudgelands/reference_projects/x_farming/textures
gob=/home/jan/projects/grudgelands/reference_projects/goblins/textures
mkdir -p "$out"
copy4() { key=$1; stem=$2; a=$3; b=$4; c=$5; d=$6; for pair in "1:$a" "2:$b" "3:$c" "4:$d"; do stage=${pair%%:*}; n=${pair#*:}; cp "$x/x_farming_${stem}_${n}.png" "$out/grug_farming_${key}_${stage}.png"; done; }
tint4() { key=$1; stem=$2; color=$3; a=$4; b=$5; c=$6; d=$7; for pair in "1:$a" "2:$b" "3:$c" "4:$d"; do stage=${pair%%:*}; n=${pair#*:}; convert "$x/x_farming_${stem}_${n}.png" -fill "$color" -colorize 22% "$out/grug_farming_${key}_${stage}.png"; done; }
copy4 wild_grain barley 1 3 5 8
copy4 carrot carrot 1 3 5 8
copy4 cassava potato 1 3 6 8
copy4 wild_onion beetroot 1 3 5 8
copy4 fire_pepper coffee 1 2 4 5
copy4 pumpkin pumpkin 1 3 5 8
tint4 blightberry strawberry '#765080' 1 2 3 4
tint4 sunberry strawberry '#d4a12d' 1 2 3 4
tint4 jungle_berry strawberry '#a63848' 1 2 3 4
copy4 frost_melon melon 1 3 5 8
for stage in 1 2 3 4; do cp "$root/mods/BASE/default/textures/default_papyrus.png" "$out/grug_farming_sugar_cane_${stage}.png"; convert "$root/mods/BASE/default/textures/default_papyrus.png" -fill '#6f9638' -colorize 28% "$out/grug_farming_bamboo_shoot_${stage}.png"; cp "$gob/goblins_mushroom_brown${stage#1}.png" "$out/grug_farming_cave_cap_${stage}.png" 2>/dev/null || cp "$gob/goblins_mushroom_brown.png" "$out/grug_farming_cave_cap_${stage}.png"; done
for stage in 1 2 3 4; do cp "$x/x_farming_salt.png" "$out/grug_farming_salt_crust_${stage}.png"; done
copy4 ember_moss obsidian_wart 1 2 4 6
copy4 potato potato 1 3 6 8
copy4 corn corn 1 4 7 10
