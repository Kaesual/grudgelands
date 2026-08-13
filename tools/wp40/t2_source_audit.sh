#!/usr/bin/env bash
set -euo pipefail

repo=${1:-.}
cd "$repo"

scratch=$(mktemp -d /tmp/grudgelands-wp40-t2.XXXXXX)
trap 'rm -rf "$scratch"' EXIT

mapfile -t lua_files < <(find mods/MAPGEN/grug_mapgen/wp40/source \
	mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua \
	tools/wp40/t2_source_test.lua -type f -name '*.lua' -print | sort)

tools/bin/luac51 -p "${lua_files[@]}"

stage1=mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua
catalog=mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua
test_file=tools/wp40/t2_source_test.lua
grep -q '^function validator.validate(source,vocabulary)$' "$stage1"
grep -q 'engine_core.get_modpath("grug_mapgen")' "$stage1"
grep -q 'production_canonical=dofile(production_modpath.."/wp40/canonical.lua")' "$stage1"
grep -q 'return engine_sha256(data,true)' "$stage1"
grep -q '^local function canonicalize_source(source,canonical)$' "$stage1"
grep -q 'pcall(canonicalize_source,source,canonical)' "$stage1"
grep -q '^if engine_core==nil then$' "$stage1"
[[ $(grep -c '^source\.critical_source_manifest = {' "$catalog") -eq 1 ]]
grep -q '"critical_source_manifest", "constants"' "$catalog"
grep -q '^local function validate_critical_manifest(manifest)$' "$stage1"
grep -q 'validate_critical_manifest(source\.critical_source_manifest)' "$stage1"
grep -q 'changed_manifest_checksum~=checksum_a' "$test_file"
grep -q '^source\.face_arcs = {' "$catalog"
grep -q '^source\.zone_faces = {' "$catalog"
grep -q '^source\.bay_closure_wings = {' "$catalog"
[[ $(grep -c 'geometry_policy_id="strict_tapered_bay_closure_wing_v1"' "$catalog") -eq 1 ]]
grep -q 'closure_wing_membership="zero_less_equal_N_and_N_strictly_less_than_L' "$catalog"
if grep -qE 'head_continuation|dry_fan|fan_chord|head_closure_junction|side_edge_continuation' "$catalog"; then
	echo 'T2 source audit: superseded Bay head fan/continuation authority returned' >&2
	exit 1
fi
grep -q '^source\.surface_level_controls = {}' "$catalog"
grep -q '^source\.poi_spurs = {' "$catalog"
if grep -qE 'build_face_source|first_route_for_zone|final_coast_or_bay|control_zone_a_side' "$catalog"; then
	echo 'T2 source audit: rejected mechanical face/spur authority returned' >&2
	exit 1
fi
if grep -qE 'digest_input_encoding|domain_separator|seed_byte_rule|jittered_voronoi_sha256' "$catalog" ||
	grep -qE 'raw_sha256\([^)]*(biome|domain|seed|cell)' "$test_file"; then
	echo 'T2 source audit: logical-biome selector bypasses the T1 tagged hash seam' >&2
	exit 1
fi
grep -q '^source\.hydrology_profiles = {' "$catalog"
grep -q '^source\.hydrology_transition_profiles = {' "$catalog"
grep -q '^source\.hard_protection = {}' "$catalog"
grep -q '^source\.pending_static_reservations = {}' "$catalog"
grep -q '^source\.claim_exclusions = {}' "$catalog"
grep -q 'id="geometry_microcorpus_selector_v1"' "$catalog"
grep -q 'id="requester_trace_manifest_v1"' "$catalog"
grep -q 'id="geometry_extreme_seed_selector_v1"' "$catalog"
grep -q 'active_tick_last=3333,active_tick_count=3334' "$catalog"
grep -q 'record_max_displacement_times_Q_not_local_damped_amplitude' "$catalog"
if grep -qE 'fallback_to_next_candidate|local_damped_amplitude_times_Q|rare_patrols.*road_profile' "$catalog"; then
	echo 'T2 source audit: fixture/trace/extreme selector authority drift' >&2
	exit 1
fi
grep -q '005a37a211d9e07ce4b7d01b6988977625f618cc079750ef5c046c6d398ff710' "$stage1"
[[ $(grep -c '^\s*perimeter_attachment("perimeter_attachment:' "$catalog") -eq 8 ]]
grep -q 'geometry_authority="ordered_face_arc_authority_components_v2"' "$catalog"
grep -q 'bay_base_predicate_id="strict_rational_variable_width_capsule_union_v1"' "$catalog"
[[ $(grep -c '^\s*bay_mouth_aperture("bay_mouth_aperture:' "$catalog") -eq 4 ]]
grep -q '^source\.bay_mouth_apertures={' "$catalog"
grep -q 'geometry_rule="derive_from_referenced_bay_and_perimeter_no_copied_shape"' "$catalog"
grep -q 'owner_rule="same_exact_base_bay_projection_and_owner"' "$catalog"
grep -q 'bay_mouth_aperture_predicate="strict_rational_variable_width_capsule_union_v1_for_referenced_bay"' "$catalog"
grep -q 'row\.control~=nil or row\.position~=nil' "$stage1"
if grep -q 'analytic_cross_section_width' "$catalog"; then
	echo 'T2 source audit: copied aperture width returned' >&2
	exit 1
fi
if grep -qE 'simple_after_exact_outer_clip|preview_attachment_overlap|intersection_strictly_under_bay' "$stage1" "$test_file"; then
	echo 'T2 source audit: reviewed face/bay authority loophole returned' >&2
	exit 1
fi
grep -q $'^\tmg_name = "v7",$' "$catalog"
grep -q $'^\twater_level = 1,$' "$catalog"
grep -q $'^\tchunksize = 5,$' "$catalog"
grep -q $'^\tnum_emerge_threads = 1,$' "$catalog"
grep -q $'^\tmgv7_dungeon_ymin = -31000,$' "$catalog"
grep -q $'^\tmgv7_dungeon_ymax = -193,$' "$catalog"
grep -q $'^\tbroad_content_y_min = -37,$' "$catalog"
if grep -q 'nofloatlands' "$catalog"; then
	echo 'T2 source audit: incidental special-flag serialization in source' >&2
	exit 1
fi
if grep -q 'force_native_dungeon = true' "$catalog"; then
	echo 'T2 source audit: positive native-dungeon force authority in source' >&2
	exit 1
fi
if grep -nE '^function validator\.validate\([^)]*(canonical|sha|digest|project)' "$stage1"; then
	echo 'T2 source audit: production validate exposes a forgeable trust input' >&2
	exit 1
fi
if grep -RFn 'new_offline_test_adapter' mods/MAPGEN/grug_mapgen/wp40/source; then
	echo 'T2 source audit: offline adapter referenced by production source' >&2
	exit 1
fi
if grep -nE 'register_on_generated|register_mapgen_script|ipc_(set|get)|core\.settings|function [A-Za-z0-9_.:]*compile' "$catalog" "$stage1"; then
	echo 'T2 source audit: compiler/IPC/callback/settings authority leaked into T2a' >&2
	exit 1
fi

mapfile -t production_files < <(find mods/MAPGEN/grug_mapgen/wp40/source \
	mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua \
	-type f -name '*.lua' -print | sort)

if tools/bin/luac51 -l -p "${production_files[@]}" | grep -q 'SETGLOBAL'; then
	echo 'T2 source audit: forbidden SETGLOBAL found' >&2
	exit 1
fi

production_paths=(mods/MAPGEN/grug_mapgen/wp40/source \
	mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua)

# The five exact plain-Lua-5.1 sweeps from docs/research/luanti-lua.md.
patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	hits=$(grep -rnE "$pattern" "${production_paths[@]}" --include='*.lua' || true)
	if [[ -n "$hits" ]]; then
		printf '%s\n' "$hits"
		echo 'T2 source audit: forbidden production Lua construct found' >&2
		exit 1
	fi
done

# Offline harness exception: one exact reviewed os.execute line invokes
# sha256sum for an independent digest, as in T1. All five sweeps still run.
for pattern_index in 0 1 2 3 4; do
	hits=$(grep -nE "${patterns[$pattern_index]}" tools/wp40/t2_source_test.lua || true)
	if [[ $pattern_index -eq 4 ]]; then
		hits=$(printf '%s\n' "$hits" | grep -vF 'assert(os.execute("sha256sum " .. input .. " > " .. output) == 0)' || true)
	fi
	if [[ -n "$hits" ]]; then
		printf '%s\n' "$hits"
		echo 'T2 source audit: forbidden offline Lua construct found' >&2
		exit 1
	fi
done

tools/bin/lua51 tools/wp40/t2_source_test.lua "$repo" "$scratch"

bash -n tools/wp40/t2_source_audit.sh

echo 'WP40 T2 source audit passed'
