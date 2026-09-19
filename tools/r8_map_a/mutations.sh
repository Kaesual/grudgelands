#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d /tmp/grug-r8-map-a-mutations.XXXXXX)"
trap 'rm -rf -- "$tmp"' EXIT

reset_tree() {
	rm -rf -- "$tmp/tree"
	mkdir -p "$tmp/tree/mods/MAPGEN/grug_mapgen/wp40" \
		"$tmp/tree/tools/r8_map_a/engine_probe"
	cp "$repo/mods/MAPGEN/grug_mapgen/wp40/height.lua" \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/r6_content.lua" \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua" \
		"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/"
	cp "$repo/tools/r8_map_a/writer_kat.lua" \
		"$repo/tools/r8_map_a/mutation_probe.lua" "$tmp/tree/tools/r8_map_a/"
	cp "$repo/tools/r8_map_a/engine_probe/volume.lua" \
		"$tmp/tree/tools/r8_map_a/engine_probe/"
}

expect_rejected() {
	local rule="$1"
	if luajit "$tmp/tree/tools/r8_map_a/mutation_probe.lua" \
			"$tmp/tree" "$rule" >"$tmp/$rule.out" 2>"$tmp/$rule.err"; then
		echo "mutation unexpectedly survived: $rule" >&2
		exit 1
	fi
	local line
	line="$(head -n 1 "$tmp/$rule.err")"
	printf 'mutation\t%s\trejected\t%s\n' "$rule" "$line"
}

reset_tree
sed -i 's|"/" .. run_class|""|' \
	"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/height.lua"
expect_rejected run_stability

reset_tree
sed -i 's/if y < context.floor_y then/if false then/' \
	"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua"
expect_rejected floor_guard

reset_tree
sed -i 's/context.original_data\[index\] == context.stone_cid then/context.original_data[index] == context.stone_cid or context.original_data[index] == context.gravel_cid then/' \
	"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua"
expect_rejected ore_preservation

reset_tree
sed -i -e 's/if continues and not touches_sky and/if not touches_sky and/' \
	-e 's/outside_count >= R8_CAVE_COMPONENT_MINIMUM/outside_count >= 1/' \
	"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua"
expect_rejected cave_connection

reset_tree
sed -i 's/return complete/return true/' \
	"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua"
expect_rejected proof_box_edge

reset_tree
sed -i 's/unexpected_voxels = actual_count/unexpected_voxels = 0/' \
	"$tmp/tree/tools/r8_map_a/engine_probe/volume.lua"
expect_rejected checker_unexpected

reset_tree
sed -i \
	-e 's/if baseline_solid\[position_key\] then/if baseline_solid[position_key] and node_name(row[1], row[2], row[3]) == "air" then/' \
	-e 's/if expected_air and #change_rows > 0/if #change_rows > 0/' \
	"$tmp/tree/tools/r8_map_a/engine_probe/volume.lua"
expect_rejected checker_partial_lumen

reset_tree
sed -i 's/candidate_id = id,/candidate_id = id .. "\/" .. option_index,/' \
	"$tmp/tree/tools/r8_map_a/engine_probe/volume.lua"
expect_rejected checker_dual_lumen

reset_tree
sed -i 's/return {bed, "default:sand",/return {bed, bed,/' \
	"$tmp/tree/mods/MAPGEN/grug_mapgen/wp40/r6_content.lua"
expect_rejected surface_integration
