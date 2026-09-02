#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="${1:?repository root required}"
receipt="${2:?receipt path required}"
phase="${3:?source-audit phase required (prefreeze or final)}"
[[ "$phase" == prefreeze || "$phase" == final ]] || {
	echo "WP40 R7 source audit: phase must be prefreeze or final" >&2
	exit 2
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mapgen="$repo/mods/MAPGEN/grug_mapgen"
gathering="$repo/mods/ITEMS/grug_gathering"
native="$mapgen/wp40/r7_native.lua"
emerge="$mapgen/wp40/r7_mapgen.lua"
partial="${receipt}.partial"

for command_name in rg sha256sum awk sort dirname mkdir rm mv tr cat git cmp wc; do
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

changed_roster="$repo/tools/wp40/r7/changed_production_lua.txt"
derived_changed="${partial}.changed-lua"
{
	git -C "$repo" diff --name-only --diff-filter=AM d6002a2 -- mods
	git -C "$repo" ls-files --others --exclude-standard -- mods
} | sort -u | rg '[.]lua$' >"$derived_changed"
[[ "$(awk 'END {print NR + 0}' "$derived_changed")" -eq 70 ]] || {
	echo "WP40 R7 source audit: baseline-derived changed Lua population differs" >&2
	exit 1
}
cmp -s "$changed_roster" "$derived_changed" || {
	echo "WP40 R7 source audit: frozen changed-production roster differs from baseline" >&2
	exit 1
}
deleted_lua_count="$(git -C "$repo" diff --name-only --diff-filter=D d6002a2 -- mods | \
	rg '[.]lua$' | awk 'END {print NR + 0}')"
[[ "$deleted_lua_count" -eq 7 ]] || {
	echo "WP40 R7 source audit: deleted legacy Lua population differs" >&2
	exit 1
}
rm -f -- "$derived_changed"

config="$repo/minetest.conf"
[[ -f "$config" ]] || {
	echo "WP40 R7 source audit: game default minetest.conf is absent" >&2
	exit 1
}
config_value() {
	local key="$1"
	awk -F '=' -v wanted="$key" '
		$0 !~ /^[[:space:]]*#/ {
			name = $1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
			if (name == wanted) {
				value = substr($0, index($0, "=") + 1)
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
				count++; result = value
			}
		}
		END {if (count != 1) exit 2; print result}' "$config"
}
config_keys=(water_level mapgen_limit chunksize num_emerge_threads mg_flags \
	mgv7_spflags mgv7_dungeon_ymin mgv7_dungeon_ymax)
config_values=(1 31007 5 1 biomes,caves,decorations,dungeons,light,ores \
	mountains,ridges,caverns,nofloatlands -31000 -193)
for index in 0 1 2 3 4 5 6 7; do
	actual="$(config_value "${config_keys[$index]}")" || {
		echo "WP40 R7 source audit: config key population differs: ${config_keys[$index]}" >&2
		exit 1
	}
	[[ "$actual" == "${config_values[$index]}" ]] || {
		echo "WP40 R7 source audit: config value differs: ${config_keys[$index]}=$actual" >&2
		exit 1
	}
done
for key in allowed_mapgens default_mapgen; do
	[[ "$(awk -F '=' -v wanted="$key" '$0 !~ /^[[:space:]]*#/ {
		name=$1; gsub(/[[:space:]]/, "", name)
		if (name == wanted) {value=$2; gsub(/[[:space:]]/, "", value); count++; result=value}}
		END {if (count == 1) print result}' "$repo/game.conf")" == v7 ]] || {
		echo "WP40 R7 source audit: game mapgen key is not exactly v7: $key" >&2
		exit 1
	}
done
for key in first_mod last_mod; do
	[[ "$(awk -F '=' -v wanted="$key" '$0 !~ /^[[:space:]]*#/ {
		name=$1; gsub(/[[:space:]]/, "", name)
		if (name == wanted) {value=$2; gsub(/[[:space:]]/, "", value); count++; result=value}}
		END {if (count == 0) print "absent"; else if (count == 1) print result}' \
		"$repo/game.conf")" == absent ]] || {
		echo "WP40 R7 source audit: game-level mod ordering overrides dependency DAG: $key" >&2
		exit 1
	}
done

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
	'^[[:space:]]*(core|core_api)\.register_mapgen_script[[:space:]]*\(' \
	"$mapgen" || true)
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
[[ "${loader_lines[0]}" == "$mapgen/wp40/r7_loader.lua:"* ]] || {
	echo "${loader_lines[0]}" >&2
	echo "WP40 R7 source audit: sole loader registration escaped R7 loader" >&2
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

# Parse the installed mod graph rather than inferring load order from directory
# names. Required dependencies must exist; installed optional dependencies are
# edges too, because Luanti uses both when ordering the active game graph.
mapfile -t mod_conf_files < <(rg --files "$repo/mods" | rg '/mod[.]conf$' | sort)
declare -A mod_file mod_required mod_optional
for file in "${mod_conf_files[@]}"; do
	name="$(awk -F '=' '$1 ~ /^[[:space:]]*name[[:space:]]*$/ {
		value=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); count++; result=value}
		END {if (count == 1) print result}' "$file")"
	[[ -n "$name" && -z "${mod_file[$name]+present}" ]] || {
		echo "WP40 R7 source audit: mod name is absent or duplicated: $file" >&2
		exit 1
	}
	mod_file[$name]="$file"
	mod_required[$name]="$(awk -F '=' '$1 ~ /^[[:space:]]*depends[[:space:]]*$/ {
		value=substr($0,index($0,"=")+1); gsub(/[[:space:]]/,"",value); print value}' "$file")"
	mod_optional[$name]="$(awk -F '=' '$1 ~ /^[[:space:]]*optional_depends[[:space:]]*$/ {
		value=substr($0,index($0,"=")+1); gsub(/[[:space:]]/,"",value); print value}' "$file")"
done
has_required_dependency() {
	local owner="$1" wanted="$2" token
	IFS=',' read -r -a tokens <<<"${mod_required[$owner]}"
	for token in "${tokens[@]}"; do [[ "$token" == "$wanted" ]] && return 0; done
	return 1
}
for edge in \
	'grug_gathering:default' 'grug_gathering:grug_core' \
	'grug_gathering:grug_materials' 'grug_gathering:grug_nodes' \
	'grug_gathering:grug_trees' 'grug_mapgen:grug_core' \
	'grug_mapgen:grug_gathering' 'grug_factions:grug_core' \
	'grug_factions:grug_mapgen' 'grug_mobs:grug_core' \
	'grug_mobs:grug_mapgen' 'grug_mobs:grug_factions' \
	'grug_traders:grug_core' 'grug_traders:grug_mobs' \
	'grug_traders:grug_factions'; do
	owner="${edge%%:*}" dependency="${edge#*:}"
	[[ -n "${mod_file[$owner]+present}" && -n "${mod_file[$dependency]+present}" ]] &&
		has_required_dependency "$owner" "$dependency" || {
		echo "WP40 R7 source audit: required load-order edge is absent: $edge" >&2
		exit 1
	}
done
dependency_graph="${partial}.dependencies"
for name in "${!mod_file[@]}"; do printf 'node\t%s\n' "$name"; done | sort >"$dependency_graph"
dependency_edge_count=0
for name in "${!mod_file[@]}"; do
	for class in required optional; do
		values="${mod_required[$name]}"
		[[ "$class" == optional ]] && values="${mod_optional[$name]}"
		IFS=',' read -r -a tokens <<<"$values"
		for token in "${tokens[@]}"; do
			[[ -z "$token" ]] && continue
			if [[ -z "${mod_file[$token]+present}" ]]; then
				[[ "$class" == optional ]] && continue
				echo "WP40 R7 source audit: required dependency is absent: $name -> $token" >&2
				exit 1
			fi
			printf 'edge\t%s\t%s\n' "$token" "$name" >>"$dependency_graph"
			dependency_edge_count=$((dependency_edge_count + 1))
		done
	done
done
sort -u -o "$dependency_graph" "$dependency_graph"
awk -F '\t' '
	$1 == "node" {node[$2]=1; next}
	$1 == "edge" {key=$2 SUBSEP $3; if (!edge[key]++) indegree[$3]++; next}
	END {
		for (name in node) count++
		while (removed < count) {
			picked=""
			for (name in node) if (!done[name] && indegree[name] == 0 &&
				(picked == "" || name < picked)) picked=name
			if (picked == "") exit 2
			done[picked]=1; removed++
			for (key in edge) {
				split(key, pair, SUBSEP)
				if (pair[1] == picked) indegree[pair[2]]--
			}
		}
	}' "$dependency_graph" || {
	echo "WP40 R7 source audit: installed mod dependency graph is cyclic" >&2
	exit 1
}
dependency_node_count="${#mod_conf_files[@]}"
dependency_edge_count="$(awk -F '\t' '$1 == "edge" {count++} END {print count + 0}' \
	"$dependency_graph")"
rm -f -- "$dependency_graph"

settlement="$mapgen/wp40/r6_settlement.lua"
data_setters="$(rg -n 'pcall\(vm\.set_data,' "$settlement" | count_lines)"
param2_setters="$(rg -n 'pcall\(vm\.set_param2_data,' "$settlement" | count_lines)"
liquid_updates="$(rg -n 'pcall\(vm\.update_liquids,' "$settlement" | count_lines)"
[[ "$data_setters" -eq 1 && "$param2_setters" -eq 1 && "$liquid_updates" -eq 1 ]] || {
	echo "WP40 R7 source audit: shared transaction setter population differs" >&2
	exit 1
}

micro_receipt="$repo/docs/research/wp40-r7-micro-kat-receipt.tsv"
micro_output="$repo/docs/research/wp40-r7-micro-kat-output.tsv"
micro_lj_log="$repo/docs/research/wp40-r7-micro-kat-luajit.log"
micro_puc_log="$repo/docs/research/wp40-r7-micro-kat-puc51.log"
micro_output_sha="not_frozen"
if [[ "$phase" == final ]]; then
	[[ -f "$micro_receipt" && -f "$micro_output" && -f "$micro_lj_log" &&
		-f "$micro_puc_log" ]] || {
	echo "WP40 R7 source audit: durable final-byte micro-KAT evidence is absent" >&2
	exit 1
}
micro_field() {
	local key="$1"
	awk -F '\t' -v wanted="$key" '$1 == wanted {count++; result=$2}
		END {if (count != 1 || NF < 2) exit 2; print result}' "$micro_receipt"
}
[[ "$(micro_field schema)" == grug_wp40_r7_micro_kat_receipt_v1 &&
	"$(micro_field byte_identical)" == true ]] || {
	echo "WP40 R7 source audit: micro-KAT receipt schema/parity differs" >&2
	exit 1
}
micro_lj_sha="$(micro_field luajit_output_sha256)"
micro_puc_sha="$(micro_field puc51_output_sha256)"
micro_output_sha="$(micro_field canonical_output_sha256)"
micro_input_sha="$(micro_field input_set_sha256)"
micro_output_bytes="$(micro_field canonical_output_bytes)"
for value in "$micro_lj_sha" "$micro_puc_sha" "$micro_output_sha" "$micro_input_sha"; do
	[[ "$value" =~ ^[0-9a-f]{64}$ ]] || {
		echo "WP40 R7 source audit: micro-KAT digest differs" >&2
		exit 1
	}
done
[[ "$micro_lj_sha" == "$micro_puc_sha" && "$micro_lj_sha" == "$micro_output_sha" &&
	"$micro_output_bytes" =~ ^[1-9][0-9]*$ ]] || {
	echo "WP40 R7 source audit: micro-KAT canonical byte parity differs" >&2
	exit 1
}
micro_roster="$repo/tools/wp40/r7/micro_inputs.txt"
changed_lua_roster="$repo/tools/wp40/r7/changed_production_lua.txt"
changed_lua_sha="$(sha256sum "$changed_lua_roster" | awk '{print $1}')"
[[ "$(micro_field executed_module_population)" == 70 &&
	"$(micro_field executed_module_roster_sha256)" == "$changed_lua_sha" &&
	"$(micro_field canonical_output_filename)" == wp40-r7-micro-kat-output.tsv &&
	"$(micro_field luajit_log_filename)" == wp40-r7-micro-kat-luajit.log &&
	"$(micro_field puc51_log_filename)" == wp40-r7-micro-kat-puc51.log &&
	"$(micro_field luajit_exit_status)" == 0 &&
	"$(micro_field puc51_exit_status)" == 0 ]] || {
	echo "WP40 R7 source audit: micro-KAT executed/output/log schema differs" >&2
	exit 1
}
actual_micro_output_sha="$(sha256sum "$micro_output" | awk '{print $1}')"
actual_micro_output_bytes="$(wc -c <"$micro_output" | tr -d '[:space:]')"
actual_micro_lj_log_sha="$(sha256sum "$micro_lj_log" | awk '{print $1}')"
actual_micro_lj_log_bytes="$(wc -c <"$micro_lj_log" | tr -d '[:space:]')"
actual_micro_puc_log_sha="$(sha256sum "$micro_puc_log" | awk '{print $1}')"
actual_micro_puc_log_bytes="$(wc -c <"$micro_puc_log" | tr -d '[:space:]')"
[[ "$actual_micro_output_sha" == "$micro_output_sha" &&
	"$actual_micro_output_bytes" == "$micro_output_bytes" &&
	"$(micro_field luajit_log_sha256)" == "$actual_micro_lj_log_sha" &&
	"$(micro_field luajit_log_bytes)" == "$actual_micro_lj_log_bytes" &&
	"$(micro_field puc51_log_sha256)" == "$actual_micro_puc_log_sha" &&
	"$(micro_field puc51_log_bytes)" == "$actual_micro_puc_log_bytes" ]] || {
	echo "WP40 R7 source audit: micro-KAT durable output/log bytes differ" >&2
	exit 1
}
micro_internal_sha="$(awk -F '\t' '$1 == "output_sha256" {count++; result=$2}
	END {if (count == 1) print result}' "$micro_output")"
expected_lj_log="WP40 R7 final micro PASS interpreter=luajit output_sha256=$micro_internal_sha"
expected_puc_log="WP40 R7 final micro PASS interpreter=puc51 output_sha256=$micro_internal_sha"
[[ "$micro_internal_sha" =~ ^[0-9a-f]{64}$ &&
	"$(awk 'END {print NR + 0}' "$micro_lj_log")" -eq 1 &&
	"$(awk 'END {print NR + 0}' "$micro_puc_log")" -eq 1 &&
	"$(cat "$micro_lj_log")" == "$expected_lj_log" &&
	"$(cat "$micro_puc_log")" == "$expected_puc_log" ]] || {
	echo "WP40 R7 source audit: micro-KAT interpreter PASS log differs" >&2
	exit 1
}
executed_rows="${partial}.executed-modules"
awk -F '\t' '$1 == "executed_module" && NF == 2 {print $2}' "$micro_output" \
	| sort >"$executed_rows"
[[ "$(awk -F '\t' '$1 == "source/executed_module_count" && $2 == "70" {
	count++} END {print count + 0}' "$micro_output")" -eq 1 &&
	"$(awk -F '\t' -v sha="$changed_lua_sha" \
	'$1 == "source/executed_module_roster_sha256" && $2 == sha {count++}
	END {print count + 0}' "$micro_output")" -eq 1 ]] &&
	cmp -s "$executed_rows" "$changed_lua_roster" || {
	echo "WP40 R7 source audit: canonical executed-module roster differs" >&2
	exit 1
}
rm -f -- "$executed_rows"
mapfile -t micro_inputs < <(printf '%s\n' "$(cat "$micro_roster")" \
	"$(cat "$changed_lua_roster")" | awk 'NF' | sort -u)
[[ "${#micro_inputs[@]}" -gt 70 ]] || {
	echo "WP40 R7 source audit: micro-KAT input roster differs" >&2
	exit 1
}
micro_input_rows="${partial}.micro-inputs"
for file in "${micro_inputs[@]}"; do
	[[ -f "$repo/$file" ]] || {
		echo "WP40 R7 source audit: micro-KAT input is absent: $file" >&2
		exit 1
	}
	actual_sha="$(sha256sum "$repo/$file" | awk '{print $1}')"
	receipt_sha="$(awk -F '\t' -v path="$file" '$1 == "input" && $2 == path {
		count++; result=$3} END {if (count != 1) exit 2; print result}' "$micro_receipt")" || {
		echo "WP40 R7 source audit: micro-KAT input row differs: $file" >&2
		exit 1
	}
	[[ "$receipt_sha" == "$actual_sha" ]] || {
		echo "WP40 R7 source audit: micro-KAT input changed: $file" >&2
		exit 1
	}
	printf '%s\t%s\n' "$file" "$actual_sha"
done >"$micro_input_rows"
micro_receipt_input_count="$(awk -F '\t' '$1 == "input" {count++}
	END {print count + 0}' "$micro_receipt")"
micro_recomputed_input_sha="$(sha256sum "$micro_input_rows" | awk '{print $1}')"
[[ "$micro_receipt_input_count" -eq "${#micro_inputs[@]}" &&
	"$micro_recomputed_input_sha" == "$micro_input_sha" ]] || {
	echo "WP40 R7 source audit: micro-KAT exact input set differs" >&2
	exit 1
}
rm -f -- "$micro_input_rows"
[[ "$(micro_field input_population)" == "${#micro_inputs[@]}" &&
	"$(micro_field luajit_binary_sha256)" == \
		"$(sha256sum "${WP40_LUA_BIN:-/usr/bin/luajit}" | awk '{print $1}')" &&
	"$(micro_field puc51_binary_sha256)" == \
		"$(sha256sum "${WP40_PUC51_BIN:-$repo/tools/bin/lua51}" | awk '{print $1}')" ]] || {
	echo "WP40 R7 source audit: micro-KAT population/interpreter binding differs" >&2
	exit 1
}
fi

input_hashes="${partial}.inputs"
mapfile -t code_input_files < <(rg --files "$repo/mods" "$script_dir" | sort)
code_input_files+=(
	"$repo/game.conf"
	"$repo/minetest.conf"
	"$repo/reference_projects/luanti/builtin/game/item.lua"
	"$repo/reference_projects/luanti/builtin/game/register.lua"
	"$repo/docs/research/wp33-gathering-contract-candidate.md"
	"$repo/docs/research/wp40-r7-implementation-contract.md"
	"$repo/docs/research/wp40-r7-native-contract-candidate.md"
	"$repo/docs/research/wp40-simple-map-r6-artifact.tsv"
	"$repo/docs/research/wp40-simple-map-r6-run-receipt.tsv"
	"$repo/docs/research/wp40-simple-map-r6-seed-corpus.tsv"
	"$repo/docs/research/wp40-simple-map-r5-contract.md"
)
mapfile -t code_input_files < <(printf '%s\n' "${code_input_files[@]}" | sort)
code_input_hashes="${partial}.code-inputs"
for file in "${code_input_files[@]}"; do
	[[ -f "$file" ]] || {
		echo "WP40 R7 source audit: code input is absent: $file" >&2
		exit 1
	}
	printf '%s  %s\n' "$(sha256sum "$file" | awk '{print $1}')" "${file#"$repo/"}"
done >"$code_input_hashes"
code_input_set_sha256="$(sha256sum "$code_input_hashes" | awk '{print $1}')"
rm -f -- "$code_input_hashes"
input_files=("${code_input_files[@]}")
if [[ "$phase" == final ]]; then
	integration_receipt="$repo/docs/research/wp40-r7-integration-receipt.tsv"
	integration_log="$repo/docs/research/wp40-r7-integration.log"
	integration_binding="$repo/docs/research/wp40-r7-integration-binding.tsv"
	prefreeze_receipt="$repo/docs/research/wp40-r7-source-audit-prefreeze.tsv"
	[[ -f "$integration_receipt" && -f "$integration_log" &&
			-f "$integration_binding" && -f "$prefreeze_receipt" ]] || {
		echo "WP40 R7 source audit: durable integration evidence is incomplete" >&2
		exit 1
	}
	binding_field() {
		local key="$1"
		awk -F '\t' -v wanted="$key" '$1 == wanted {count++; result=$2}
			END {if (count == 1) print result}' "$integration_binding"
	}
	integration_receipt_sha="$(sha256sum "$integration_receipt" | awk '{print $1}')"
	integration_log_sha="$(sha256sum "$integration_log" | awk '{print $1}')"
	prefreeze_receipt_sha="$(sha256sum "$prefreeze_receipt" | awk '{print $1}')"
	[[ "$(binding_field schema)" == grug_wp40_r7_integration_binding_v1 &&
		"$(binding_field code_input_set_sha256)" == "$code_input_set_sha256" &&
		"$(binding_field integration_receipt_sha256)" == "$integration_receipt_sha" &&
		"$(binding_field integration_log_sha256)" == "$integration_log_sha" &&
		"$(binding_field prefreeze_source_audit_sha256)" == "$prefreeze_receipt_sha" ]] || {
		echo "WP40 R7 source audit: durable integration/code binding differs" >&2
		exit 1
	}
	input_files+=(
		"$micro_receipt"
		"$micro_output"
		"$micro_lj_log"
		"$micro_puc_log"
		"$integration_receipt"
		"$integration_log"
		"$integration_binding"
		"$prefreeze_receipt"
	)
fi
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
	if [[ "$phase" == final ]]; then
		printf 'schema\tgrug_wp40_r7_source_audit_receipt_v1\n'
	else
		printf 'schema\tgrug_wp40_r7_source_audit_prefreeze_v1\n'
	fi
	printf 'phase\t%s\n' "$phase"
	printf 'gate\tclosed_noise_setters\ttrue\n'
	printf 'gate\tclosed_native_allowlist\ttrue\n'
	printf 'gate\tone_loader_callback\ttrue\n'
	printf 'gate\tzero_legacy_paths\ttrue\n'
	printf 'gate\tzero_wp33_writer\ttrue\n'
	printf 'gate\tone_shared_transaction\ttrue\n'
	printf 'gate\texact_game_mapgen_defaults\ttrue\n'
	printf 'gate\tacyclic_mod_dependencies\ttrue\n'
	printf 'gate\tfinal_micro_kat_parity\t%s\n' \
		"$([[ "$phase" == final ]] && printf true || printf not_frozen)"
	printf 'count\tnoise_setters\t6\n'
	printf 'count\tregister_biome\t0\n'
	printf 'count\tregister_ore\t6\n'
	printf 'count\tregister_decoration\t0\n'
	printf 'count\tregister_mapgen_script\t1\n'
	printf 'count\tregister_on_generated\t1\n'
	printf 'count\tvm_set_data\t1\n'
	printf 'count\tvm_set_param2_data\t1\n'
	printf 'count\tvm_update_liquids\t1\n'
	printf 'count\tmapgen_default_settings\t8\n'
	printf 'count\tchanged_production_lua\t70\n'
	printf 'count\tdeleted_legacy_lua\t7\n'
	printf 'count\tmod_dependency_nodes\t%s\n' "$dependency_node_count"
	printf 'count\tmod_dependency_edges\t%s\n' "$dependency_edge_count"
	if [[ "$phase" == final ]]; then
		printf 'micro_kat_receipt_sha256\t%s\n' \
			"$(sha256sum "$micro_receipt" | awk '{print $1}')"
	fi
	printf 'micro_kat_output_sha256\t%s\n' "$micro_output_sha"
	printf 'input_file_population\t%s\n' "${#input_files[@]}"
	printf 'code_input_file_population\t%s\n' "${#code_input_files[@]}"
	printf 'code_input_set_sha256\t%s\n' "$code_input_set_sha256"
	printf 'input_set_sha256\t%s\n' "$source_set_sha256"
} >"$partial"
mv -- "$partial" "$receipt"
printf 'WP40 R7 source audit PASS source_set_sha256=%s\n' "$source_set_sha256"
