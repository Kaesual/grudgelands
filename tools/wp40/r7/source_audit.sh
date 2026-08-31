#!/usr/bin/env bash
set -euo pipefail

repo="${1:?repository root required}"
receipt="${2:?receipt path required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mapgen="$repo/mods/MAPGEN/grug_mapgen"
gathering="$repo/mods/ITEMS/grug_gathering"
native="$mapgen/wp40/r7_native.lua"
emerge="$mapgen/wp40/r7_mapgen.lua"
partial="${receipt}.partial"

for command_name in rg sha256sum awk sort dirname mkdir rm mv; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "WP40 R7 source audit: missing command $command_name" >&2
		exit 1
	}
done
[[ -d "$repo/.git" || -f "$repo/.git" ]] || {
	echo "WP40 R7 source audit: repository root differs" >&2
	exit 1
}
[[ -f "$native" && -d "$gathering" ]] || {
	echo "WP40 R7 source audit: native or gathering package is not integrated" >&2
	exit 1
}
mkdir -p -- "$(dirname "$receipt")"

count_lines() {
	awk 'END { print NR + 0 }'
}

require_zero() {
	local label="$1" pattern="$2"
	shift 2
	local -a lines
	mapfile -t lines < <(rg -n "$pattern" "$@" 2>/dev/null || true)
	if [[ "${#lines[@]}" -ne 0 ]]; then
		printf '%s\n' "${lines[@]}" >&2
		echo "WP40 R7 source audit: $label is not zero" >&2
		exit 1
	fi
}

mapfile -t mutation_lines < <(rg -n --glob '*.lua' \
	'^[[:space:]]*(core|minetest)\.(set_mapgen_setting[[:alnum:]_]*|set_mapgen_params|set_noiseparams)[[:space:]]*\(' \
	"$repo/mods" || true)
[[ "${#mutation_lines[@]}" -eq 6 ]] || {
	printf '%s\n' "${mutation_lines[@]}" >&2
	echo "WP40 R7 source audit: mapgen-setting mutation population differs" >&2
	exit 1
}
expected_noise=(mgv7_np_terrain_base mgv7_np_terrain_alt mg_biome_np_heat \
	mg_biome_np_humidity mg_biome_np_heat_blend mg_biome_np_humidity_blend)
for index in 0 1 2 3 4 5; do
	line="${mutation_lines[$index]}"
	[[ "$line" == "$native:"* && "$line" == *'core.set_mapgen_setting_noiseparams('* &&
		"$line" == *"\"${expected_noise[$index]}\""* ]] || {
		echo "$line" >&2
		echo "WP40 R7 source audit: noise setter path/name/order differs" >&2
		exit 1
	}
done

mapfile -t biome_lines < <(rg -n --glob '*.lua' \
	'^[[:space:]]*core\.register_biome[[:space:]]*\(' "$mapgen" || true)
mapfile -t decoration_lines < <(rg -n --glob '*.lua' \
	'^[[:space:]]*core\.register_decoration[[:space:]]*\(' "$mapgen" || true)
[[ "${#biome_lines[@]}" -eq 0 && "${#decoration_lines[@]}" -eq 0 ]] || {
	printf '%s\n' "${biome_lines[@]}" "${decoration_lines[@]}" >&2
	echo "WP40 R7 source audit: Lua biome/decoration registration remains" >&2
	exit 1
}

mapfile -t ore_lines < <(rg -n --glob '*.lua' \
	'^[[:space:]]*handles\[[1-6]\][[:space:]]*=[[:space:]]*core\.register_ore[[:space:]]*\(' \
	"$mapgen" || true)
[[ "${#ore_lines[@]}" -eq 6 ]] || {
	printf '%s\n' "${ore_lines[@]}" >&2
	echo "WP40 R7 source audit: native ore call population differs" >&2
	exit 1
}
for line in "${ore_lines[@]}"; do
	[[ "$line" == "$native:"* ]] || {
		echo "$line" >&2
		echo "WP40 R7 source audit: ore call escaped the native allowlist" >&2
		exit 1
	}
done

require_zero "dormant default registration calls" \
	'^[[:space:]]*default\.register_(biomes|ores|decorations)[[:space:]]*\(' \
	"$repo/mods" --glob '*.lua'

mapfile -t loader_lines < <(rg -n --glob '*.lua' \
	'^[[:space:]]*core\.register_mapgen_script[[:space:]]*\(' "$mapgen" || true)
mapfile -t callback_lines < <(rg -n --glob '*.lua' \
	'^[[:space:]]*core\.register_on_generated[[:space:]]*\(' "$mapgen" || true)
[[ "${#loader_lines[@]}" -eq 1 && "${#callback_lines[@]}" -eq 1 ]] || {
	printf '%s\n' "${loader_lines[@]}" "${callback_lines[@]}" >&2
	echo "WP40 R7 source audit: loader/callback population differs" >&2
	exit 1
}
[[ "${loader_lines[0]}" == *'/wp40/r7_mapgen.lua'* ]] || {
	echo "${loader_lines[0]}" >&2
	echo "WP40 R7 source audit: sole loader does not name the closed emerge script" >&2
	exit 1
}
[[ "${callback_lines[0]}" == "$emerge:"* ]] || {
	echo "${callback_lines[0]}" >&2
	echo "WP40 R7 source audit: sole callback is not in the emerge script" >&2
	exit 1
}

require_zero "legacy ocean writer/healer" \
	'ocean_mask_mapgen\.lua|grug_mapgen:continent|grug_mapgen:ocean_mask_heal' \
	"$mapgen" --glob '*.lua'
require_zero "legacy ocean/structure loader" \
	'dofile\(path \.\. "/(ocean_mask|structures)\.lua"\)' \
	"$mapgen/init.lua"
require_zero "legacy height authority" \
	'core\.get_spawn_level[[:space:]]*\(|get_mapgen_object[[:space:]]*\([[:space:]]*"heightmap"' \
	"$repo/mods/CORE/grug_core" "$mapgen" --glob '*.lua'
require_zero "legacy direct/runtime map writer" \
	'core\.(bulk_set_node|set_node)[[:space:]]*\(|[[:alnum:]_]+:write_to_map[[:space:]]*\(' \
	"$mapgen" --glob '*.lua'
require_zero "legacy platform authority" \
	'grug_core\.(capitals|get_spawn_pos|outpost_anchors|bandit_camp_anchors|get_camp_platform_y|set_camp_platform_y|request_camp_platform|ensure_camp_platform_built|CAMP_(HALF|PLATFORM_Y|PLATFORM_MAX_Y|CLEAR_HEIGHT|PROBE_TOP|PROBE_BOTTOM|SAMPLE_RADIUS))\b|camp_platform_y:|platform_(pending|attempts|built|decided)\b|MAX_PLATFORM_ATTEMPTS\b|in_capital_zone\b|protected_zone_in_box\b' \
	"$repo/mods" --glob '*.lua'

require_zero "WP33 placement/writer API" \
	'core\.register_(biome|ore|decoration|on_generated|mapgen_script|lbm)[[:space:]]*\(|core\.(bulk_set_node|set_node)[[:space:]]*\(|VoxelManip|write_to_map[[:space:]]*\(' \
	"$gathering" --glob '*.lua'

settlement="$mapgen/wp40/r6_settlement.lua"
data_setters="$(rg -n 'pcall\(vm\.set_data,' "$settlement" | count_lines)"
param2_setters="$(rg -n 'pcall\(vm\.set_param2_data,' "$settlement" | count_lines)"
liquid_updates="$(rg -n 'pcall\(vm\.update_liquids,' "$settlement" | count_lines)"
[[ "$data_setters" -eq 1 && "$param2_setters" -eq 1 && "$liquid_updates" -eq 1 ]] || {
	echo "WP40 R7 source audit: shared transaction setter population differs" >&2
	exit 1
}

input_hashes="${partial}.inputs"
mapfile -t input_files < <(rg --files "$repo/mods/CORE/grug_core" \
	"$repo/mods/PLAYER/grug_factions" "$repo/mods/ENTITIES/grug_mobs" \
	"$mapgen" "$gathering" "$script_dir" | sort)
input_files+=(
	"$repo/docs/research/wp33-gathering-contract-candidate.md"
	"$repo/docs/research/wp40-r7-implementation-contract.md"
	"$repo/docs/research/wp40-r7-native-contract-candidate.md"
	"$repo/docs/research/wp40-simple-map-r6-artifact.tsv"
	"$repo/docs/research/wp40-simple-map-r6-run-receipt.tsv"
	"$repo/docs/research/wp40-simple-map-r6-seed-corpus.tsv"
)
mapfile -t input_files < <(printf '%s\n' "${input_files[@]}" | sort)
[[ "${#input_files[@]}" -gt 0 ]] || {
	echo "WP40 R7 source audit: source input population is empty" >&2
	exit 1
}
for file in "${input_files[@]}"; do
	[[ -f "$file" ]] || {
		echo "WP40 R7 source audit: bound input is absent: $file" >&2
		exit 1
	}
	digest="$(sha256sum "$file" | awk '{print $1}')"
	printf '%s  %s\n' "$digest" "${file#"$repo/"}"
done >"$input_hashes"
source_set_sha256="$(sha256sum "$input_hashes" | awk '{print $1}')"
rm -f -- "$input_hashes"

{
	printf 'schema\tgrug_wp40_r7_source_audit_receipt_v1\n'
	printf 'gate\tclosed_noise_setters\ttrue\n'
	printf 'gate\tclosed_native_allowlist\ttrue\n'
	printf 'gate\tone_loader_callback\ttrue\n'
	printf 'gate\tzero_legacy_paths\ttrue\n'
	printf 'gate\tzero_wp33_writer\ttrue\n'
	printf 'gate\tone_shared_transaction\ttrue\n'
	printf 'count\tnoise_setters\t6\n'
	printf 'count\tregister_biome\t0\n'
	printf 'count\tregister_ore\t6\n'
	printf 'count\tregister_decoration\t0\n'
	printf 'count\tregister_mapgen_script\t1\n'
	printf 'count\tregister_on_generated\t1\n'
	printf 'count\tvm_set_data\t1\n'
	printf 'count\tvm_set_param2_data\t1\n'
	printf 'count\tvm_update_liquids\t1\n'
	printf 'input_file_population\t%s\n' "${#input_files[@]}"
	printf 'input_set_sha256\t%s\n' "$source_set_sha256"
} >"$partial"
mv -- "$partial" "$receipt"
printf 'WP40 R7 source audit PASS source_set_sha256=%s\n' "$source_set_sha256"
