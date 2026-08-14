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
grep -q '^source\.bay_bank_components={' "$catalog"
[[ $(grep -c '^\s*bank("bay_bank:' "$catalog") -eq 20 ]]
if grep -q 'lc("bay_shore"' "$catalog"; then
	echo 'T2 source audit: superseded literal Bay-shore authority returned' >&2
	exit 1
fi
grep -q 'bay_bank_candidate="final_classifier_dry_mainland_column' "$catalog"
grep -q 'bay_bank_trace_state="bounded_depth_first_search_state_previous_current_plus_seen_directed_state_set' "$catalog"
grep -q 'bay_bank_neighbor_order="base_clockwise_east_southeast_south_southwest_west_northwest_north_northeast' "$catalog"
grep -q 'bay_bank_branch_rule="evaluate_admissible_successors_in_the_fixed_Moore_order_and_select_the_first_with_a_complete_valid_path_to_the_declared_terminal' "$catalog"
grep -q 'bay_bank_reachability_bound="per_successor_bounded_DFS_counts_every_pushed_frame_including_the_start' "$catalog"
grep -q 'bay_bank_aperture_terminal_order="deduplicated_final_authored_declared_perimeter_integer_raster_order_separate_from_the_canonical_mouth_aperture_membership_indices_payload_and_attachment_tie"' "$catalog"
grep -q 'bay_bank_water_side="for_each_proposed_materialized_bank_step_current_to_successor' "$catalog"
grep -q 'bay_bank_wing_k_set="all_final_dry_candidates_in_the_declared_wing_bbox_with_a_cardinal_neighbor_in_strict_water_owned_by_that_referenced_closure_wing' "$catalog"
grep -q 'bay_bank_wing_k_rank="greatest_exact_wing_axis_projection_N_then_lexicographically_least_x_then_z' "$catalog"
grep -q 'bay_bank_edge_transition_identity="for_each_of_eight_transitions_the_inward_candidate_scan_offset_from_the_declared_final_endpoint_must_equal_zero' "$catalog"
grep -q 'bay_bank_tail_pair_selection="enumerate_all_complete_path_pairs_filter_interior_disjoint_distinct_J_predecessor' "$catalog"
grep -q 'then_apply_wedge_validity_then_lexicographically_least_full_negative_path_coordinate_sequence' "$catalog"
grep -q 'bay_bank_tail_wedge_polygon="analysis_only_exact_polygon_follows_negative_Kminus_to_J_then_reverse_positive_J_to_Kplus_then_direct_exact_chord_Kplus_to_Kminus' "$catalog"
grep -q 'bay_bank_tail_wedge_radius="R_equals_one_plus_maximum_Chebyshev_Kminus_to_J_or_Kplus_to_J_scan_inclusive_J_centered_R_bbox_current_source_R_at_most_five"' "$catalog"
grep -q 'bay_bank_tail_wedge_scan="for_each_integer_column_in_the_inclusive_J_centered_R_bbox_with_exact_polygon_class_greater_equal_zero_exempt_only_exact_negative_or_positive_tail_stations' "$catalog"
grep -q 'bay_bank_tail_wedge_chord="direct_exact_chord_Kplus_to_Kminus_is_analysis_only_and_never_rastered_materialized_serialized_or_used_for_ownership"' "$catalog"
grep -q 'bay_bank_materialization="resolve_each_terminal_and_each_joint_wing_tail_pair_once_then_materialize_one_shared_integer_column_chain_per_component' "$catalog"
grep -q 'raw_dry_multiplicity_rule="outside_final_planned_water_raw_dry_face_multiplicity_at_least_one_multiples_only_on_declared_shared_edge_or_junction_with_canonical_half_open_owner_inside_final_planned_water_has_no_raw_dry_face_requirement"' "$catalog"
grep -q 'WP40 T2 R15 Wing-wedge oracle passed: 100 raw pairs, 8 wedge pairs, ' "$test_file"
grep -q 'R15 all-Wing 100/8 and 15-to-0 corpus drift' "$test_file"
grep -q 'R15 dry nonterminal chord-column mutation was accepted' "$test_file"
grep -q 'R15 self-intersecting wedge mutation was accepted' "$test_file"
grep -q 'R15 multiple wedge-valid pairs did not select lexicographically first' "$test_file"
for invariant in bay_bank_component_fields bay_bank_terminal_fields \
	bay_bank_incidence_fields bay_bank_component_contract \
	bay_bank_component_incidence face_arc_fields face_arc_component_fields \
	face_arc_source_projection face_arc_kind_composition \
	perimeter_bank_terminal_fields; do
	grep -q "\"$invariant\"" "$stage1"
	grep -q "expect_failure(\"$invariant\"" "$test_file"
done
grep -q 'R11 Bay-bank Reality correction' docs/research/wp40-engineering-brief.md
grep -q 'exactly 20' docs/design/world_zones.md
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
grep -q '9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68' "$stage1"
grep -q '3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140' "$stage1"
grep -q 'e5c17a5a084b0f13a5779b7c84aa823c8dae64e711020be5f46087db80a24693' "$stage1"
grep -q 'b983c61c6740dfea9ff7821a3bfbda0da08c3475d4965995814cb71fff53f255' "$stage1"
grep -q 'id="shared_polyline_normal_displacement_t1_hash_v3",schema_version=3' "$catalog"
grep -q 'step_left_normal_rule="normal_x_q_equals_t1_qdiv_minus_dz_times_Q_by_step_length_q_normal_z_q_equals_t1_qdiv_dx_times_Q_by_step_length_q"' "$catalog"
grep -q 'clip_loop_rule="test_exact_damped_scalar_first_if_outside_scan_integer_magnitude_nodes' "$catalog"
grep -q 'topology_ceiling_policy_id="record_uniform_integer_magnitude_ceiling_v1"' "$catalog"
grep -q 'topology_ceiling_domain="integer_C_descending_from_record_max_displacement_through_zero_inclusive"' "$catalog"
grep -q 'topology_ceiling_candidate_order="strictly_descending_C_no_binary_search_or_monotonicity_assumption"' "$catalog"
grep -q 'topology_ceiling_output_field="compiled_record_unsigned_topology_ceiling_nodes"' "$catalog"
grep -q 'mainland_fixed_closure_policy_id="referenced_fixed_holy_edge_union_r7_v1"' "$catalog"
grep -q 'mainland_fixed_closure_resolution="route_raster_each_referenced_land_edge_in_declared_direction' "$catalog"
grep -q 'mainland_fixed_closure_remap="for_each_equivalent_authored_control_rotation_or_reversal_refind_the_unique_complete_source_segment_by_full_union_byte_sequence' "$catalog"
grep -q 'mainland_fixed_closure_scalar="inside_the_ordinary_local_scalar_loop_every_tagged_closure_row_has_local_scalar_q_exactly_zero_and_both_closure_to_ordinary_coast_ring_joins' "$catalog"
grep -q 'mainland_fixed_closure_topology="one_unchanged_record_wide_C_and_one_candidate_validity_and_final_reraster' "$catalog"
grep -q 'mainland_fixed_closure_forbidden="no_post_R7_replace_snap_owner_fallback' "$catalog"
[[ $(grep -c 'r7_fixed_closure = {kind="fixed_holy_land_edge_union"' "$catalog") -eq 2 ]]
[[ $(grep -c '{edge_id="land_0[45][0-9]",direction="reverse"}' "$catalog") -eq 12 ]]
grep -q 'ordered_outer_components=true,edge_refs=true' "$stage1"
grep -q 'WP40 T2 H55 fixed-closure oracle passed: 2 x 6 refs, 5001 stations each' "$test_file"
grep -q 'bf7880fea20624378a8c177e513af637b61b8f169be6cf1e03a45a86fe538534' "$test_file"
for invariant in perimeter_fixed_closure_fields \
		perimeter_fixed_closure_ref_fields perimeter_fixed_closure_contract \
		perimeter_fixed_closure_ref perimeter_fixed_closure_fixed_edge \
		perimeter_fixed_closure_join perimeter_fixed_closure_repeat \
		perimeter_fixed_closure_scope perimeter_fixed_closure_projection \
	perimeter_fixed_closure_geometry; do
	grep -q "\"$invariant\"" "$stage1"
	grep -q "expect_failure(\"$invariant\"" "$test_file"
done
grep -q 'final_raster_rule="route_raster_once_between_consecutive_shifted_controls' "$catalog"
grep -q 'rejects_seed_without_second_clip_snap_or_seed_fallback' "$catalog"
grep -q 'closed_centered_axis_aligned_record_authoring_rectangle' "$catalog"
grep -q 'base_bay_symmetric_effective_half_width_uses_world_partition_policy_not_polyline_normal_displacement' "$catalog"
grep -q 'pre_displacement_canonical_source_segment_raster_only_never_final_reraster_stations' "$catalog"
grep -q 'perimeter_span_overlap_never_duplicates_a_source_segment_or_station_in_the_union' "$catalog"
grep -q 'provisional_E_perimeter_A_discarded_prefix_suffix_and_inserted_final_reraster_stations_never_enter_selector_sequence' "$catalog"
grep -q 'post_noise_damping_local_clip_selected_topology_ceiling_pre_component_scalar_q_exactly_once' "$catalog"
grep -q 'id="face_partition_with_bay_capsule_water_v2"' "$catalog"
grep -q 'outside_every_final_mainland_island_and_fixed_holy_grounds_closed_footprint' "$catalog"
grep -q 'strict_exterior_closed_integer_polygon_channel_v1' "$catalog"
grep -q 'exact_rational_nearest_allowed_outer_coast_component_v1' "$catalog"
grep -q 'face_arc:gravesalt:holy_west' "$catalog"
grep -q 'face_arc:skyglass:holy_east' "$catalog"
grep -q 'lower_zone_numeric_id_then_stable_component_id_then_zero_based_compiled_component_segment_index' "$catalog"
if grep -q 'math\.sqrt' "$catalog" "$stage1" "$test_file"; then
	echo 'T2 source audit: host floating square root entered R7-R9 authority/oracle' >&2
	exit 1
fi
grep -q '^source\.relief_junctions={' "$catalog"
[[ $(grep -c '^\s*relief_junction(' "$catalog") -eq 38 ]]
grep -q '^source\.junction_departures={' "$catalog"
[[ $(grep -c '^\s*junction_departure("land_' "$catalog") -eq 4 ]]
grep -q 'junction_departure_policy_id="derived_diagonal_endpoint_precontrol_v1"' "$catalog"
grep -q 'junction_departure_application="copy_the_original_land_edge_control_array_insert_fixed_D_at_position_two' "$catalog"
grep -q 'junction_departure_safe_arithmetic="compare_adjacent_and_endpoint_coordinates_without_subtraction' "$catalog"
grep -q 'expect_failure("exact_count_junction_departures"' "$test_file"
grep -q 'independent R13 38-junction/102-pair raster oracle drift' "$test_file"
for invariant in junction_departure_fields junction_departure_contract \
	junction_departure_duplicate junction_departure_reference \
	junction_departure_incidence junction_departure_diagonal \
	junction_departure_safe_arithmetic junction_departure_derived_station \
	junction_pair_base_overlap junction_pair_base_x_cross; do
	grep -q "\"$invariant\"" "$stage1"
	grep -q "expect_failure(\"$invariant\"" "$test_file"
done
grep -q 'junction_candidate_eligibility="strictly_positive_weight_only_all_quantized_zero_weights_excluded_including_distance_96"' "$catalog"
grep -q 'junction_zero_weight_rule="return_post_landmark_H_exactly_without_division"' "$catalog"
grep -q 'junction_seed_rule="intersection_band_uses_domain_relief_junction_v1_feature_junction_x_z_coordinates_x_z_candidate_zero_lane_two_full_seed_unbiased_singleton_midpoint_uses_no_hash"' "$catalog"
grep -q 'junction_candidate_edge_dedup="one_candidate_per_unique_land_edge_from_ordinary_nearest_segment_and_projection_tie_never_one_pair_per_junction_endpoint"' "$catalog"
grep -q 'junction_endpoint_support_proof="stage1_raw_control_endpoint_chebyshev_minimum_400_and_undisplaced_attachment_joint_raster_minimum_297_steps_are_baseline_KATs_only_stage2_measures_each_final_raster_and_hard_rejects_station_steps_below_192_before_endpoint_support"' "$catalog"
grep -q 'junction_final_edge_short_rule="stage2_hard_reject_final_edge_raster_station_steps_less_than_192"' "$catalog"
grep -q 'hash_domain="relief_junction_v1"' "$catalog"
grep -q 'hash_feature_id="junction:"..x..":"..z' "$catalog"
grep -q 'hash_candidate_index=0' "$catalog"
grep -q 'hash_lane=2' "$catalog"
grep -q 'raw_height_delta="max_above_water_minus_min_above_water_not_inclusive_value_count"' "$catalog"
grep -q 'raw_noise_input="clamp_noise_q_to_minus_Q_through_plus_Q_before_height_product"' "$catalog"
grep -q 'effective_width_square_max_4243584391840000_actual_guarded_cross_square_times_L_max_4251571423760000_and_conservative_early_cross_bound_4251754341463400' "$catalog"
grep -q 'minimum_exact_squared_euclidean_distance_to_canonical_stations_of_evaluated_authored_segment' "$catalog"
grep -q 'joint_perimeter_station_endpoint_before_final_raster_v1' "$catalog"
if grep -qE 'bay_displacement_lanes|side_half_width_q16|left_lane|right_lane|nearest_perimeter_station_then_snap' "$catalog"; then
	echo 'T2 source audit: superseded asymmetric Bay or attachment authority returned' >&2
	exit 1
fi
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
		hits=$(printf '%s\n' "$hits" | grep -vF 'os.execute("sha256sum " .. input .. " > " .. output)' || true)
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
