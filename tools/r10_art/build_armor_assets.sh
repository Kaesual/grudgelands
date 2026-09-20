#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
refs=/home/jan/projects/grudgelands/reference_projects
gear="$root/mods/ITEMS/grug_gear/textures"
visuals="$root/mods/PLAYER/grug_visuals/textures"
voxe="$refs/VoxeLibre/textures"
lott="$refs/Lord-of-the-Test/mods/lottclothes/textures"

copy_pair() {
	line=$1 slot=$2 grade=$3 inv=$4 worn=$5
	cp "$inv" "$gear/grug_gear_item_${slot}_${line}_${grade}.png"
	cp "$worn" "$visuals/grug_visuals_${line}_${slot}_${grade}.png"
}

# Six visibly distinct familiar metal sets. The bronze and embersteel grades use
# gold silhouettes; embersteel receives a red material grade during composition.
for spec in \
	"bronze gold" "iron iron" "steel chain" "silversteel diamond" \
	"embersteel gold" "abyssal_steel netherite"
do
	set -- $spec; grade=$1 material=$2
	for pair in "head helmet" "chest chestplate" "legs leggings" "feet boots"
	do
		set -- $pair; slot=$1 part=$2
		copy_pair metal "$slot" "$grade" \
			"$voxe/mcl_armor_inv_${part}_${material}.png" \
			"$voxe/mcl_armor_${part}_${material}.png"
	done
done

# The two grades share Minecraft's forged silhouette but not its material.
# Bake their copper and ember palettes into both inventory and worn media.
for slot in head chest legs feet
do
	for target in \
		"$gear/grug_gear_item_${slot}_metal_bronze.png" \
		"$visuals/grug_visuals_metal_${slot}_bronze.png"
	do
		convert "$target" -fill '#b56f32' -colorize 42% "$target"
	done
	for target in \
		"$gear/grug_gear_item_${slot}_metal_embersteel.png" \
		"$visuals/grug_visuals_metal_${slot}_embersteel.png"
	do
		convert "$target" -fill '#9f3528' -colorize 58% "$target"
	done
done

# Cloth uses complete Lord of the Test clothing sets rather than recoloured
# metal outlines. Each grade is a coherent authored outfit.
cloth_sources='patch hood_ettenmoor robe_ettenmoor pants_midgewater boots_midgewater
woven cap_chetwood jacket_chetwood pants_chetwood boots_chetwood
heavy hood_wizard_blue robe_wizard_grey pants_midgewater boots_dwarf
silkweave hood_elven shirt_elven pants_chetwood shoes_elven
silk hood_wizard_white robe_wizard_white pants_midgewater shoes_hobbit_white
stormweave hood_ettenmoor cloak_mordor pants_chetwood boots_dwarf'
echo "$cloth_sources" | while read grade head chest legs feet
do
	[ -n "$grade" ] || continue
	copy_pair cloth head "$grade" "$lott/lottclothes_inv_${head}.png" "$lott/lottclothes_${head}.png"
	copy_pair cloth chest "$grade" "$lott/lottclothes_inv_${chest}.png" "$lott/lottclothes_${chest}.png"
	copy_pair cloth legs "$grade" "$lott/lottclothes_inv_${legs}.png" "$lott/lottclothes_${legs}.png"
	copy_pair cloth feet "$grade" "$lott/lottclothes_inv_${feet}.png" "$lott/lottclothes_${feet}.png"
done

# Leather keeps the readable VoxeLibre leather cut. Distinct trim patterns are
# mechanically composited for the six grades, so progression is not colour-only.
for spec in \
	"light sentry" "cured dune" "heavy wild" "scaled coast" \
	"sleek eye" "nightscale silence"
do
	set -- $spec; grade=$1 trim=$2
	case "$grade" in
		cured) leather_tint='#9b7148' ;;
		heavy) leather_tint='#6f4a2f' ;;
		scaled) leather_tint='#68784a' ;;
		sleek) leather_tint='#4e505b' ;;
		nightscale) leather_tint='#342c45' ;;
		*) leather_tint='#9a704c' ;;
	esac
	for pair in "head helmet" "chest chestplate" "legs leggings" "feet boots"
	do
		set -- $pair; slot=$1 part=$2
		if [ "$grade" = light ]; then
			cp "$voxe/mcl_armor_inv_${part}_leather.png" \
				"$gear/grug_gear_item_${slot}_leather_${grade}.png"
		else
			convert "$voxe/mcl_armor_inv_${part}_leather.png" \
				"$voxe/${part}_trim.png" -compose over -composite \
				-fill "$leather_tint" -colorize 26% \
				"$gear/grug_gear_item_${slot}_leather_${grade}.png"
		fi
		convert "$voxe/mcl_armor_${part}_leather.png" \
			"$voxe/${trim}_${part}.png" -compose over -composite \
			-fill "$leather_tint" -colorize 18% \
			"$visuals/grug_visuals_leather_${slot}_${grade}.png"
	done
done

# EQUIP's generic activated bindings remain valid and resolve to the T1 art.
for slot in head chest legs feet
do
	cp "$gear/grug_gear_item_${slot}_leather_light.png" \
		"$gear/grug_gear_item_${slot}_leather.png"
done
