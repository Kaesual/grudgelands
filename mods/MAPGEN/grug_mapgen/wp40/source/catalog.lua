-- WP40 authored world source. This module is intentionally engine-free: it
-- contains only ordered, integer/rational source records for the later T2
-- geometry compiler. It does not compile displacement, evaluate H, or place
-- content.

local function point(x, z)
	return {x = x, z = z}
end

local function fraction(numerator, denominator)
	return {numerator = numerator, denominator = denominator}
end

local function palette(...)
	return {...}
end

local function biome(id, share)
	return {id = id, share = share}
end

local function zone(numeric_id, id, name, race_region, faction,
		territory_rule, pvp_rule, level_min, level_max, relief_id,
		biomes, civic)
	return {
		numeric_id = numeric_id,
		id = id,
		display_name = name,
		race_region = race_region,
		faction = faction,
		territory_rule = territory_rule,
		pvp_rule = pvp_rule,
		level_min = level_min,
		level_max = level_max,
		primary_relief_id = relief_id,
		biomes = biomes,
		civic_no_hostiles = civic,
	}
end

local source = {
	schema = "grug_wp40_authored_source_v1",
	section_order = {
		"critical_source_manifest", "constants", "geometry_policies",
		"relief_profiles",
		"route_classes", "water_classes",
		"landmark_role_vocabulary", "template_primitives", "zones",
		"land_edges", "relief_junctions", "perimeter_attachments", "perimeter_spans", "face_arcs", "zone_faces",
		"route_stations", "routes", "route_interfaces", "surface_level_controls",
		"route_crossing_interfaces", "boat_edges", "island_landings",
		"island_route_stations", "island_routes", "island_route_interfaces",
		"perimeters", "bays", "bay_mouth_apertures", "bay_closure_wings",
		"islands", "channels", "landmarks", "anchors", "templates",
		"poi_spurs", "template_compositions", "hydrology_profiles",
		"hydrology_transition_profiles", "hydrology", "hydrology_interfaces",
		"hard_protection_recipes", "hard_protection",
		"pending_static_recipes", "pending_static_reservations",
		"claim_exclusion_recipes", "claim_exclusions",
		"housing_masks", "coastal_housing_cores", "semantics",
	},
}

-- Semantic source authority for the engine-facing settings that participate
-- in the vertical native-dungeon preservation proof. Flag records model the
-- closed bitsets themselves; they intentionally do not copy negative
-- settings-string spellings.
source.critical_source_manifest = {
	id = "critical_source_manifest",
	schema = "grug_wp40_critical_source_manifest_v1",
	mg_name = "v7",
	water_level = 1,
	chunksize = 5,
	num_emerge_threads = 1,
	mg_flags = {
		"dungeons", "biomes", "caves", "ores", "decorations", "light",
	},
	mgv7_special_flags = {
		{id = "mountains", enabled = true},
		{id = "ridges", enabled = true},
		{id = "floatlands", enabled = false},
		{id = "caverns", enabled = true},
	},
	mgv7_dungeon_ymin = -31000,
	mgv7_dungeon_ymax = -193,
	mgv7_np_dungeons = {
		offset = fraction(9, 10),
		scale = fraction(1, 2),
		spread = {x = 500, y = 500, z = 500},
		seed = 0,
		octaves = 2,
		persistence = fraction(4, 5),
		lacunarity = 2,
		flags = {"defaults"},
	},
	broad_content_y_min = -37,
	force_native_dungeon = false,
}

source.constants = {
	q = 65536,
	mainland_frame = {min_x = -2600, max_x = 2600, min_z = -3000, max_z = 3000},
	holy_grounds = {min_x = -2500, max_x = 2500, min_z = -250, max_z = 250},
	holy_junction_x = {-1500, 0, 1500},
	elandor_belt = {min_z = -1900, max_z = -1100},
	kragmar_belt = {min_z = 1100, max_z = 1900},
	elandor_frontier = {min_z = -1100, max_z = -250},
	kragmar_frontier = {min_z = 250, max_z = 1100},
	ordinary_boundary_displacement = 64,
	peace_contested_displacement = 32,
	coast_displacement = 96,
	bay_displacement = 48,
	boundary_min_wavelength = 256,
	anchor_no_jitter_radius = 96,
	minimum_zone_core = 256,
	minimum_travel_corridor = 96,
	coastal_shelf_width = 80,
	flight_warning_width = 48,
	minimum_dragon_channel = 200,
	minimum_hard_flight_width = 104,
	dragon_approach_width = 96,
	dragon_approach_z = {-125, 125},
	shallow_protection_floor = -700,
	contested_deep_ceiling = -701,
	spatial_index_cell = 128,
	native_displacement_limit = 16,
	surface_repair_clearance = 16,
	decoration_light_radius = 15,
	authored_vein_cell = 16,
	housing_reservation_width = 101,
	housing_reservation_radius = 50,
	housing_relief_limit = 12,
	housing_frontage_min = 600,
	housing_depth_min = 300,
	capital_build_width = 512,
	capital_blend_width = 704,
	capital_civic_core_width = 96,
	capital_gate_width = 32,
	capital_protection_apron = 10,
	start_build_width = 128,
	start_blend_width = 256,
	start_dry_core_width = 600,
	start_dry_core_depth = 500,
	island_envelope_width = 600,
	island_envelope_depth = 700,
	island_route_parity = fraction(1, 10),
	outer_coast_noise_period = 512,
	ordinary_boundary_noise_period = 384,
	bay_noise_period = 256,
	island_coast_displacement = 48,
}

-- These records bind every selectable source parameter while leaving the one
-- schema-versioned Q16.16 evaluator to T2b. They are data, not alternate
-- implementations of the common noise, footprint, or blend algorithms.
source.geometry_policies = {
	id = "geometry_policies",
	schema = "grug_wp40_geometry_source_v1",
	template_footprint = {
		id = "centered_half_open_square_v1",
		shape = "square",
		coordinate_space = "anchor_relative",
		interval_rule = "centered_half_open_total_width",
		blend_distance = "chebyshev_outward",
	},
	relief_composition = {
		id = "relief_composition_v1",
		secondary_blend_width = 64,
		boundary_blend_width = 96,
		boundary_gate_half_width = 96,
		boundary_gate_rule = "shared_smootherstep_height",
		landmark_overlap_rule = "highest_priority_replace_profile",
		landmark_priority_order="greater_integer_priority_wins",
		landmark_priority_tie = "reject",
		evaluation_order={"raw_owning_zone_profile",
			"highest_priority_landmark_replacement_and_64_node_blend",
			"shared_edge_G_and_96_node_blend"},
		evaluation_tie_rule="landmark_priority_reject_then_lower_edge_numeric_id_then_segment_index",
	},
	poi_spur = {
		id = "candidate_specific_to_fixed_station_v1",
		coordinate_space = "candidate_specific_relative_to_fixed_world_station",
		candidate_endpoint_offset = point(0, 0),
		path_rule = "use_exact_authored_candidate_path",
		tie_rule = "selected_candidate_index",
	},
	surface_level_interpolation = {
		id = "inverse_distance_squared_q16_v1", schema_version = 1,
		control_selection = "all_controls_owned_by_zone",
		distance_metric = "squared_euclidean_xz",
		exact_control_rule = "exact_position_level_or_reject_conflict",
		weight_rule = "floor_q_squared_div_distance_squared",
		gcd_reduction = "reduce_weighted_sum_before_multiply",
		max_coordinate_delta = 8192,
		max_control_count = 16,
		overflow_rule = "reject_outside_safe_double_integer_range",
		weighted_rounding = "nearest_integer_ties_lower",
		edge_vertex_rule = "owning_face_then_lower_zone_numeric_tie",
		outside_rule = "reject_outside_owning_face",
		clamp_rule = "published_zone_level_bracket",
	},
	-- Reviewed WP40 implementation policy: a globally stable jittered Voronoi
	-- field supplies coherent patches, while the owning zone alone supplies
	-- the ordered weighted palette. No T6 material or decoration is selected
	-- here.
	logical_biome_selector = {
		id = "zone_palette_jittered_voronoi_t1_hash_v1",
		schema_version = 1,
		coordinate_space = "world_xz_integer_columns",
		seed_input = "t1_canonical_unsigned_u64_decimal_text",
		hash_api = "deterministic.new_hash",
		hash_schema = "grug_wp40_geometry_source_v1",
		hash_domain = "logical_biome_patch_v1",
		hash_feature_id = "",
		hash_coordinates = "signed_cell_x_z",
		hash_candidate_index = 0,
		hash_lanes = {site_x=0,site_z=1,palette=2},
		cell_size = 192,
		cell_index_rule = "mathematical_floor_coordinate_div_cell_size",
		candidate_neighborhood = "own_and_eight_adjacent_cells",
		site_offset_min = 32,
		site_offset_span = 128,
		site_offset_rule = "min_plus_t1_unbiased_range_lane",
		distance_rule = "squared_euclidean_integer_world_xz",
		nearest_tie_rule = "lowest_cell_x_then_lowest_cell_z",
		palette_roll_rule = "t1_unbiased_range_lane_size_100",
		palette_mapping_rule = "first_authored_cumulative_share_strictly_greater_than_roll",
		ownership_rule = "resolve_zone_first_and_use_only_owning_zone_palette",
		arithmetic_rule = "t1_safe_integer_and_floor_division",
		share_audit_domain = "ordinary_land_columns_after_fixed_roads_and_structures",
		share_audit_tolerance_percentage_points = 5,
	},
	primitive_evaluator = {
		id="template_primitive_q16_composition_v1",schema_version=1,
		initial_accumulator_q16=0,
		initial_accumulator_rule="zero_height_offset_at_every_fitting_envelope_column",
		default_weight_rule="Q_inside_support_zero_outside_unless_formula_weight_rule_present",
		coordinate_rule="world_column_minus_anchor_center_to_signed_q16",
		parameter_rule="authored_integer_or_exact_fraction_to_q16",
		primitive_result="signed_offset_q16_plus_signed_distance_q16",
		inside_rule="signed_distance_q16_less_than_or_equal_zero",
		distance_tie_rule="boundary_is_inside",
		composition_order="authored_operations_left_to_right",
		first_operation="apply",
		apply_rule="replace_accumulator_with_primitive_offset_inside_support",
		overlay_rule="maximum_accumulator_and_primitive_offset_inside_support",
		subtract_rule="accumulator_minus_absolute_primitive_offset_inside_support",
		blend_rule="qlerp_accumulator_to_primitive_by_primitive_weight_q16_inside_support",
		outside_rule="leave_accumulator_unchanged",
		precedence_rule="later_operation_observes_previous_accumulator",
		q_arithmetic="t1_qmul_qdiv_qlerp_half_away_from_zero",
		final_rounding="t1_qround_half_away_from_zero",
		feature_blend_source="composition_fitting_footprint_signed_chebyshev_q16",
		feature_blend_width="template_blend_width_minus_fitting_width_div_two_per_side",
		feature_blend_rule="Q_inside_fitting_then_one_minus_t1_smootherstep_outward_distance_over_per_side_blend_width",
		feature_blend_endpoints="composition_offset_at_fitting_boundary_zero_offset_at_blend_envelope_boundary",
		axis_frame={id="canonical_oriented_tangent_frame_q16_v1",
			route_source="canonical_route_raster_station_sequence",
			route_endpoint_rule="first_to_second_or_penultimate_to_last_distinct_station",
			route_interior_rule="previous_distinct_to_next_distinct_station",
			anchor_trail_source="selected_candidate_path_first_to_next_distinct_offset_toward_fixed_target",
			anchor_patrol_source="selected_candidate_plus_first_patrol_offset_to_next_distinct_patrol_offset",
			turn_rule="normalize_sum_incoming_and_outgoing_q16_unit_tangents",
			opposite_turn_tie="use_outgoing_tangent",zero_segment_rule="skip_to_nearest_distinct_station",
			orientation_rule="tangent_as_authored_then_left_normal_minus_dz_plus_dx",
			normalization="t1_isqrt_length_then_qdiv_components_half_away_from_zero"},
	},
	primitive_formulas = {
		id="template_primitive_formulas_v1",schema_version=1,
		formulas={
			{id="flat",formula_id="primitive_flat_q16_v1",support="composition_fitting_footprint",offset_q_rule="height_offset_times_Q",signed_distance_rule="footprint_signed_chebyshev_q16"},
			{id="tilt",formula_id="primitive_tilt_q16_v1",support="composition_fitting_footprint",axis_rule="integer_axis_manhattan_norm_equals_one",offset_q_rule="qdiv_axis_dot_local_times_rise_Q_by_run",signed_distance_rule="footprint_signed_chebyshev_q16"},
			{id="terrace",formula_id="primitive_terrace_q16_v2",support="composition_fitting_footprint",offset_q_rule="minimum_rings_minus_one_and_floor_radius_q16_div_step_run_times_step_height_Q",signed_distance_rule="footprint_signed_chebyshev_q16",continuity_rule="capped_outer_terrace_reaches_fitting_boundary_then_generic_feature_blend_returns_offset_to_zero"},
			{id="plateau",formula_id="primitive_plateau_q16_v1",support="euclidean_inner_plus_shoulder",offset_q_rule="zero_flat_offset",signed_distance_rule="radius_q16_minus_inner_plus_shoulder_Q",weight_rule="one_inside_inner_then_one_minus_smootherstep_across_shoulder"},
			{id="basin",formula_id="primitive_basin_q16_v1",support="euclidean_inner_plus_rim",offset_q_rule="negative_depth_Q_inside_then_qlerp_negative_depth_to_zero_across_rim",signed_distance_rule="radius_q16_minus_inner_plus_rim_Q"},
			{id="rim",formula_id="primitive_continuous_rim_q16_v1",support="euclidean_outer_radius",offset_q_rule="zero_through_inner_radius_then_height_Q_times_smootherstep_to_peak_radius_then_height_Q_times_one_minus_smootherstep_to_outer_radius_then_zero",signed_distance_rule="radius_q16_minus_outer_radius_Q",continuity_rule="zero_at_inner_and_outer_support_boundaries_height_at_peak"},
			{id="causeway",formula_id="primitive_causeway_q16_v1",axis_frame_policy_ref="geometry_policies.primitive_evaluator.axis_frame",support="absolute_lateral_q16_less_equal_surface_half_width_Q",offset_q_rule="zero_surface_offset",volume_rule="solid_backing_base_y_minus_one_through_base_y_minus_backing_depth"},
			{id="cross_section",formula_id="primitive_cross_section_q16_v1",axis_frame_policy_ref="geometry_policies.primitive_evaluator.axis_frame",support="absolute_lateral_q16_less_equal_corridor_half_width_Q",offset_q_rule="zero_surface_offset",weight_rule="one_inside_surface_half_width_then_one_minus_smootherstep_to_corridor_half_width"},
			{id="housing_smoothing",formula_id="primitive_housing_smoothing_q16_v1",support="every_integer_column_of_owning_coastal_core",neighborhood_rule="for_each_core_column_p_all_world_H_columns_in_p_plus_centered_half_open_101_by_101_square",base_rule="base_y_at_p_equals_lower_median_H_in_canonical_z_then_x_sample_order",target_rule="one_unique_T_at_p_equals_clamp_H_p_to_base_y_at_p_minus_6_through_base_y_at_p_plus_6",offset_q_rule="T_at_p_minus_base_y_at_p_times_Q",signed_distance_rule="coastal_core_policy_signed_distance_q16"},
		},
		radius_rule="t1_isqrt_of_q16_squared_distance_with_lower_integer_root",
		division_rounding="t1_qdiv_half_away_from_zero",
		boundary_rule="support_distance_zero_is_inside",
	},
	boundary_displacement = {
		id="shared_polyline_normal_displacement_t1_hash_v2",schema_version=2,
		input_rule="literal_control_polyline_authored_order_retained_only_for_final_output_mapping",
		sampling_rule="one_route_raster_policy_integer_sequence_with_consecutive_join_duplicates_suppressed",
		open_orientation_rule="lexicographically_smaller_complete_station_sequence_of_forward_and_reverse_is_calculation_order",
		closed_orientation_rule="remove_repeated_terminal_station_rotate_each_direction_to_lexicographically_lowest_x_then_z_station_then_choose_lexicographically_smaller_cycle",
		orientation_restore_rule="map_displaced_controls_back_to_authored_rotation_and_direction_only_after_all_scalar_and_component_results_exist",
		reversal_identity_rule="canonical_calculation_order_makes_reversal_change_only_output_order_never_displaced_world_columns",
		normal_and_scalar_orientation="canonical_calculation_direction_exclusively_authored_direction_never_changes_normal_or_scalar_sign",
		step_rule="incoming_equals_current_minus_previous_distinct_outgoing_equals_next_distinct_minus_current_each_component_minus_one_zero_or_one",
		step_length_q_rule="t1_isqrt_of_dx_squared_plus_dz_squared_times_Q_squared",
		step_left_normal_rule="normal_x_q_equals_t1_qdiv_minus_dz_times_Q_by_step_length_q_normal_z_q_equals_t1_qdiv_dx_times_Q_by_step_length_q",
		endpoint_normal_rule="single_available_directed_step_left_unit_normal",
		joint_rule="sum_incoming_and_outgoing_left_unit_q16_normals_then_t1_isqrt_sum_squares_and_t1_qdiv_each_sum_component_by_sum_length_q",
		joint_degenerate_rule="reject_zero_length_step_or_zero_opposite_joint_sum",
		normal_safe_bounds="step_length_radicand_at_most_8589934592_joint_sum_square_at_most_34359738368",
		hash_api="deterministic.new_hash",hash_schema="grug_wp40_geometry_source_v1",
		hash_domain_rule="record_noise_domain",hash_feature_id="",
		hash_coordinates="signed_lattice_x_z",
		hash_candidate_index=0,hash_lanes={coarse=0,fine=1},
		period_rule="kind_period_then_twice_kind_period",
		period_by_kind={land_edge=384,mainland_coast=512,bay=256,
			island_coast=256,fixed=0},
		amplitudes={fraction(2,3),fraction(1,3)},
		noise_rule="t1_value_noise_q16_sum_clamped_minus_q_to_plus_q",
		raw_scalar_rule="raw_scalar_q_equals_t1_qmul_clamped_noise_q_and_record_max_displacement_times_Q",
		control_taper_distance=96,
		control_taper_metric="canonical_eight_connected_segment_station_steps_equal_chebyshev_arclength",
		control_taper_rule="smootherstep_clamped_min_station_steps_from_segment_ends_div_96",
		control_taper_metadata="each_base_station_retains_authored_source_segment_numeric_index_zero_based_local_station_index_and_local_last_index",
		control_join_taper="deduplicated_shared_control_join_has_zero_taper_for_both_incident_segments",
		control_orientation_remap="open_reverse_and_closed_rotate_or_reverse_remap_segment_and_local_station_metadata_with_points_never_rederive_segment_boundaries_from_canonical_whole_sequence",
		no_jitter_distance=96,
		no_jitter_metric="exact_world_chebyshev_distance_to_source_point",
		no_jitter_transition_distance=96,
		no_jitter_rule="zero_through_distance_96_then_smootherstep_distance_minus_96_div_96_full_at_192",
		no_jitter_sources={"all_literal_polyline_control_vertices",
			"all_route_interface_positions","all_fixed_anchor_positions",
			"holy_rectangle_corners_and_junctions"},
		no_jitter_aggregation="minimum_damping_q16_over_all_sources",
		damping_rule="t1_qmul_control_taper_q16_and_no_jitter_minimum_q16",
		damped_scalar_rule="damped_scalar_q_equals_t1_qmul_raw_scalar_q_and_damping_q",
		clip_envelope_by_kind={
			land_edge="closed_chebyshev_square_about_base_station_with_radius_record_max_displacement",
			mainland_coast="closed_constants_mainland_frame_rectangle",
			island_coast="closed_authored_island_ellipse",
			fixed="exact_base_station_only"},
		land_edge_envelope_predicate="absolute_candidate_x_minus_base_x_less_equal_record_max_displacement_and_absolute_candidate_z_minus_base_z_less_equal_record_max_displacement",
		mainland_coast_envelope_predicate="mainland_frame_min_x_less_equal_candidate_x_less_equal_max_x_and_min_z_less_equal_candidate_z_less_equal_max_z",
		island_coast_envelope_predicate="reject_absolute_dx_greater_radius_x_or_absolute_dz_greater_radius_z_before_products_else_dx_squared_times_radius_z_squared_plus_dz_squared_times_radius_x_squared_less_equal_radius_x_squared_times_radius_z_squared",
		fixed_envelope_predicate="candidate_x_equals_base_x_and_candidate_z_equals_base_z",
		envelope_boundary_tie="equality_inside_for_every_kind",
		envelope_arithmetic="checked_exact_integer_products_no_face_polygon_final_geometry_or_float_dependency",
		envelope_safe_bounds="land_and_frame_use_comparisons_island_axis_reject_makes_each_term_and_right_side_at_most_11025000000",
		excluded_parameterized_geometry={"base_bay_symmetric_effective_half_width_uses_world_partition_policy_not_polyline_normal_displacement"},
		clip_loop_rule="test_exact_damped_scalar_first_if_outside_scan_integer_magnitude_nodes_from_minimum_record_max_displacement_and_floor_absolute_damped_scalar_q_div_Q_down_to_zero_with_fixed_damped_sign",
		clip_probe_rule="for_each_magnitude_m_probe_station_plus_qround_qmul_normal_x_q_sign_m_Q_and_qround_qmul_normal_z_q_sign_m_Q",
		clip_selection_rule="exact_damped_scalar_if_its_probe_is_inside_else_first_integer_probe_is_greatest_tested_admissible_not_exceeding_desired_magnitude_no_monotonicity_assumption",
		clip_scalar_rule="displacement_scalar_q_equals_exact_damped_scalar_or_sign_damped_times_selected_integer_magnitude_times_Q_zero_damped_skips_loop_and_returns_zero_no_untested_fractional_result",
		component_rule="dx_equals_t1_qround_t1_qmul_normal_x_q_displacement_scalar_q_then_dz_analogously",
		component_rounding="qmul_half_away_to_Q16_then_qround_half_away_to_integer_in_that_order_including_positive_and_negative_half_ties",
		scalar_component_product_bound_decimal="412316860416",
		shifted_station_rule="every_shifted_base_raster_station_is_a_final_reraster_control_not_a_final_emitted_station",
		final_raster_rule="route_raster_once_between_consecutive_shifted_controls_closed_cycle_also_last_to_first_suppress_only_consecutive_duplicates_remove_repeated_cycle_terminal",
		final_validation_rule="no_second_displacement_clip_or_snap_final_raster_envelope_topology_width_or_connectivity_failure_rejects_seed",
		displacement_scalar_authority="sole_final_signed_Q16_value_after_noise_damping_and_local_magnitude_clip_before_component_rounding",
		shared_boundary_clip_policy_id="canonical_integer_land_run_prefix_suffix_v1",
		shared_boundary_clip_raster="route_raster_policy_integer_sequence",
		shared_boundary_clip_classifier="final_literal_perimeter_land_mask_after_displacement",
		shared_boundary_clip_retained_rule="exactly_one_consecutive_retained_station_interval",
		shared_boundary_clip_endpoint_rule="nonattached_first_and_last_retained_integer_stations_attached_endpoint_uses_joint_station",
		shared_boundary_attachment_policy_id="joint_perimeter_station_endpoint_before_final_raster_v1",
		shared_boundary_attachment_candidate="final_displaced_perimeter_then_provisional_edge_selection_only_run_yields_E_then_final_displaced_declared_perimeter_segment_yields_A",
		shared_boundary_attachment_selection="minimum_chebyshev_E_to_A_then_lower_canonical_perimeter_index_tie_distance_at_most_one",
		shared_boundary_attachment_final="discarded_prefix_or_suffix_controls_are_removed_A_is_zero_displacement_terminal_control_and_both_span_boundaries_before_sole_final_edge_raster_provisional_run_not_exported",
		shared_boundary_attachment_interior="all_final_stations_after_A_strict_footprint_interior_eight_connected_one_run",
		shared_boundary_clip_reject="empty_run_interior_rejection_or_second_retained_run",
		shared_boundary_clip_forbidden="emitted_E_to_A_connector_post_raster_snap_inserted_float_or_rational_intersection_and_private_connector_geometry",
	},
	route_raster = {
		id="symmetric_bresenham_8_connected_stations_v1",schema_version=1,
		coordinate_space="integer_world_xz",
		segment_order="authored_polyline_order",
		canonical_endpoint_order="lower_x_then_lower_z",
		canonical_execution_rule="raster_once_from_lexicographically_lower_endpoint_to_higher_endpoint",
		authored_reversal_rule="reverse_finished_canonical_point_sequence_when_authored_direction_is_opposite",
		major_axis_rule="greater_absolute_delta_x_major_tie_x_major",
		error_rule="two_minor_minus_major_step_minor_when_greater_or_equal_zero",
		state="current_x_current_z_error_step_index",
		initial_state="endpoint_a_x_endpoint_a_z_two_minor_minus_major_zero",
		loop_rule="emit_current_then_if_not_endpoint_step_major_test_error_step_minor_update_error",
		termination_rule="stop_immediately_after_emitting_exact_endpoint_b",
		reversal_identity="guaranteed_by_canonical_endpoint_execution_then_whole_sequence_reversal",
		diagonal_rule="one_major_and_optional_one_minor_step_per_station",
		endpoint_rule="include_both_segment_endpoints",
		joint_rule="suppress_only_consecutive_duplicate_world_columns",
		station_rule="retain_authored_vertices_endpoints_gates_and_crossings_in_sequence",
		chunk_width=80,chunk_origin=-32,
		chunk_owner_rule="floor_world_coordinate_minus_origin_div_chunk_width_per_axis",
		chunk_intersection_rule="each_owner_renders_only_its_central_slice_of_global_station_sequence",
	},
	route_profile_solver = {
		id="route_profile_dynamic_program_v1",schema_version=1,
		station_source="route_raster_global_ordered_station_sequence",
		station_footprint_policy_id="route_class_cross_section_full_integer_columns_v1",
		cross_section_policy_ref="route_classes.cross_section_id_and_lateral_blend_width",
		cross_section_axis_source="canonical_route_raster_station_tangent_frame",
		corridor_total_width_source="route_class.exclusion_width",
		visible_total_width_source="route_class.visible_width",
		lateral_index_domain="minus_floor_total_width_div_two_through_ceil_total_width_div_two_minus_one",
		even_width_tie="negative_side_owns_the_extra_boundary_column_in_centered_half_open_interval",
		lateral_distance_rule="absolute_signed_integer_lateral_index_times_Q",
		cross_section_weight_rule="Q_inside_visible_total_width_over_two_then_one_minus_smootherstep_to_corridor_total_width_over_two",
		cross_section_weight_boundary="zero_at_corridor_half_width_Q",
		final_target_rule="qround_qlerp_H_to_route_y_Q_by_cross_section_weight_half_away_from_zero",
		world_column_enumeration="all_integer_x_z_in_route_segment_corridor_bounding_box_expanded_by_ceil_corridor_total_width_div_two",
		world_column_projection="clamped_q16_projection_to_each_canonical_raster_station_segment",
		world_column_membership="signed_lateral_q16_greater_equal_minus_floor_width_div_two_Q_and_strictly_less_than_ceil_width_div_two_Q",
		world_column_segment_tie="lower_canonical_segment_index",
		world_column_station_owner="nearest_endpoint_station_by_projection_parameter_half_tie_lower_station_index",
		world_column_lateral_sign="signed_cross_of_owned_segment_tangent_and_column_minus_projection",
		world_column_lateral_distance="t1_isqrt_lower_root_of_squared_q16_distance",
		world_column_lateral_tie="negative_side_then_lower_world_x_then_lower_world_z",
		bend_column_owner="single_nearest_segment_then_lower_canonical_segment_index",
		transition_spacing_unit="canonical_route_raster_station_steps",
		interface_phase_ref="route_interfaces.grade_phase_and_grade_limit",
		state="station_index_integer_y_previous_nonzero_transition_index_previous_delta",
		candidate_interval_rule="intersection_zone_bracket_H_cut_fill_fixed_interface_and_envelope_limits",
		lateral_sample_rule="every_unique_owned_integer_world_column_in_segment_corridor_union",
		cut_fill_rule="final_rounded_cross_section_target_minus_H_negative_is_cut_positive_is_fill",
		feasibility_rule="absolute_negative_cut_at_most_max_cut_and_positive_fill_at_most_max_fill",
		earthwork_rule="absolute_final_rounded_cross_section_target_minus_H_at_owned_lateral_column",
		station_earthwork_rule="sum_owned_world_column_earthwork_in_signed_lateral_distance_then_x_then_z_order",
		maximum_earthwork_rule="maximum_all_station_lateral_samples",
		total_earthwork_rule="sum_station_earthwork_in_station_order",
		delta_rule="candidate_y_current_minus_candidate_y_previous",
		transition_rule="delta_is_minus_one_zero_or_plus_one",
		spacing_rule="nonzero_transitions_separated_by_route_class_minimum_transition_run",
		interface_phase_rule="for_interface_station_i_flat_run_12_requires_delta_j_zero_for_j=max_2_i-11_through_min_last_i_plus_11",
		curvature_rule="sum_absolute_current_delta_minus_previous_delta",
		cost_tuple={"maximum_earthwork","total_earthwork","curvature","canonical_integer_y_sequence"},
		cost_compare="lexicographic_signed_integer",
		station_tie_rule="lower_integer_y_first",
		failure_rule="reject_complete_route_without_valid_terminal_state",
	},
	relief_field = {
		id="shared_edge_gate_relief_q16_v1",schema_version=1,
		raw_noise_api="deterministic.value_noise_2d",
		raw_hash_schema="grug_wp40_geometry_source_v1",
		raw_feature_id="",raw_candidate_index=0,
		raw_octave_rule="relief_profile_ordered_period_and_exact_fraction_amplitudes",
		raw_noise_range="minus_Q_through_plus_Q",
		raw_noise_input="clamp_noise_q_to_minus_Q_through_plus_Q_before_height_product",
		raw_height_equation_id="relief_noise_to_inclusive_height_delta_floor_v2",
		raw_height_delta="max_above_water_minus_min_above_water_not_inclusive_value_count",
		raw_height_rule="water_level_plus_min_plus_floor_div_clamped_noise_plus_Q_times_delta_by_two_Q",
		raw_height_tie="floor_toward_negative_infinity",
		raw_height_product_guard="clamped_noise_plus_Q_times_delta_at_most_2_pow_53_minus_1",
		gate_domain_rule="edge_noise_domain_colon_shared_gate",
		gate_coordinate_rule="route_raster_station_world_xz",
		gate_lane=2,
		gate_band_rule="authored_edge_inclusive_offsets_above_water",
		nonoverlap_transition_rule="explicit_single_lower_midpoint_owned_by_96_node_G_blend",
		gate_height_rule="band_min_plus_t1_unbiased_range_lane_inclusive_band_size",
		gate_along_edge_interpolation="qlerp_segment_endpoint_G_by_clamped_nearest_segment_projection_q16",
		gate_along_edge_rounding="t1_qlerp_half_away_from_zero",
		gate_identity_rule="one_G_per_shared_edge_station_consumed_by_both_incident_faces",
		junction_policy_id="shared_relief_junction_gate_v1",
		junction_source="one_checksum_covered_record_per_multi_edge_endpoint",
		junction_seed_rule="intersection_band_uses_domain_relief_junction_v1_feature_junction_x_z_coordinates_x_z_candidate_zero_lane_two_full_seed_unbiased_singleton_midpoint_uses_no_hash",
		junction_empty_rule="lower_midpoint_floor_max_incident_min_plus_min_incident_max_div_two",
		junction_transition_distance=96,
		junction_transition_metric="canonical_incident_edge_raster_station_steps_from_endpoint",
		junction_edge_gate_rule="qlerp_junction_G_to_ordinary_edge_G_by_smootherstep_clamped_station_steps_div_96",
		junction_candidate_weight="one_minus_smootherstep_clamped_exact_edge_distance_div_96",
		junction_candidate_edge_dedup="one_candidate_per_unique_land_edge_from_ordinary_nearest_segment_and_projection_tie_never_one_pair_per_junction_endpoint",
		junction_projection_station="on_selected_nearest_segment_exact_rational_nearest_canonical_raster_station_to_projection_lower_global_station_index_tie",
		junction_endpoint_support="select_start_if_zero_based_global_station_s_less_than_96_else_end_if_total_steps_minus_s_less_than_96_else_no_local_junction",
		junction_raw_endpoint_minimum_chebyshev=400,
		junction_undisplaced_attachment_minimum_station_steps=297,
		junction_final_edge_minimum_station_steps=192,
		junction_endpoint_support_proof="stage1_raw_control_endpoint_chebyshev_minimum_400_and_undisplaced_attachment_joint_raster_minimum_297_steps_are_baseline_KATs_only_stage2_measures_each_final_raster_and_hard_rejects_station_steps_below_192_before_endpoint_support",
		junction_final_edge_short_rule="stage2_hard_reject_final_edge_raster_station_steps_less_than_192",
		junction_unsupported_edge_gate="ordinary_native_edge_G_without_separate_far_endpoint_junction_candidate",
		junction_candidate_eligibility="strictly_positive_weight_only_all_quantized_zero_weights_excluded_including_distance_96",
		junction_candidate_aggregation="ordered_checked_Q16_weighted_sum_all_positive_weight_incident_candidates",
		junction_candidate_average="t1_qdiv_ordered_sum_qmul_effective_gate_q_and_weight_q_by_ordered_sum_weight_q",
		junction_zero_weight_rule="return_post_landmark_H_exactly_without_division",
		junction_boundary_strength="maximum_candidate_weight_q16",
		junction_final_rule="qlerp_ordinary_relief_to_weighted_junction_candidates_by_boundary_strength",
		junction_candidate_order="unique_land_edge_numeric_id",
		junction_band_exception="empty_intersection_midpoint_is_bounded_shared_transition_and_may_be_outside_incident_raw_profile_band",
		nearest_edge_distance="minimum_exact_squared_q16_distance_to_closed_displaced_edge_segment",
		nearest_edge_projection="clamped_dot_over_segment_length_squared_q16_half_away_from_zero",
		nearest_edge_tie="lower_land_edge_numeric_id_then_lower_segment_index",
		boundary_blend_width=96,
		blend_direction="raw_zone_height_at_outer_edge_to_shared_G_at_edge",
		blend_weight="one_minus_t1_smootherstep_clamped_distance_div_96_q16",
		blend_rounding="t1_qlerp_then_qround_half_away_from_zero",
	},
	landmark_masks = {
		id="landmark_masks_and_replacement_blend_v1",schema_version=1,
		rectangle_formula_id="mask_rectangle_signed_distance_q16_v1",
		rectangle_membership="absolute_dx_less_equal_radius_x_and_absolute_dz_less_equal_radius_z",
		rectangle_signed_distance="maximum_absolute_dx_minus_radius_x_and_absolute_dz_minus_radius_z_q16",
		ellipse_formula_id="mask_ellipse_signed_distance_q16_v1",
		ellipse_membership="dx_squared_radius_z_squared_plus_dz_squared_radius_x_squared_less_equal_radius_x_squared_radius_z_squared",
		ellipse_signed_distance="u_q16=qdiv(dx_Q,radius_x_Q);v_q16=qdiv(dz_Q,radius_z_Q);rho_q16=isqrt_Q(qmul(u,u)+qmul(v,v));sd_node_q16=qmul(rho_q16-Q,min_radius_Q)",
		distance_unit="all_shape_signed_distances_are_world_node_Q16",
		capsule_formula_id="mask_capsule_signed_distance_q16_v1",
		capsule_axis_rule="longer_radius_axis_tie_x",
		capsule_membership="distance_to_axis_segment_less_equal_short_radius",
		capsule_signed_distance="q16_distance_to_axis_segment_minus_short_radius_Q",
		boundary_rule="signed_distance_zero_is_inside",
		unsigned_distance_rule="maximum_zero_and_signed_distance_q16",
		replacement_rule="highest_priority_replace_profile_height",
		replacement_noise_domain="landmark_record_noise_domain",
		replacement_profile="landmark_secondary_relief_id_ordered_octaves_and_inclusive_band",
		replacement_hash_binding="feature_empty_candidate_zero_with_landmark_noise_domain",
		priority_tie_rule="reject",
		blend_width=64,
		blend_rule="qlerp_previous_H_to_replacement_H_by_Q_minus_smootherstep(max_zero_sd_node_q16_div_64Q)",
		blend_endpoints="replacement_at_inside_and_boundary_previous_at_64_nodes_outside",
		blend_rounding="t1_qlerp_then_qround_half_away_from_zero",
	},
	coastal_housing_core = {
		id="displaced_coast_interval_inward_core_v1",schema_version=1,
		station_source="final_displaced_face_arc_segment_station_sequence",
		interval_rule="inclusive_start_segment_start_through_end_segment_end_in_arc_direction",
		frontage_distance="sum_integer_station_euclidean_q16_in_interval",
		frontage_minimum=600,inland_depth=300,
		inward_side_rule="authored_face_arc_zone_inside_side",
		normal_rule="left_q16_normal_of_final_displaced_directed_coast_station_tangent",
		joint_rule="normalize_sum_incoming_outgoing_left_q16_normals",
		joint_tie_rule="lower_arc_segment_index",
		endpoint_cap_rule="closed_half_discs_radius_inland_depth_at_both_interval_endpoints",
		membership_rule="distance_to_interval_station_polyline_less_equal_inland_depth_on_inward_side_or_endpoint_cap",
		distance_rule="minimum_q16_distance_to_segment_with_lower_segment_index_tie",
		rounding_rule="t1_isqrt_lower_root_for_distance_q16",
		column_target_rule="one_unique_T_per_integer_core_column_from_its_own_world_H_neighborhood",
		window_rule="candidate_center_accepted_only_when_every_centered_half_open_101_by_101_column_passes_final_positive_and_static_exclusion_masks",
		stage2_window_oracle="accepted_window_final_T_max_minus_min_at_most_12_and_each_column_absolute_T_minus_H_at_most_6",
		smoothing_composition_id="compose_coastal_housing_core",relief_limit=12,
	},
	world_partition = {
		id="face_partition_with_bay_capsule_water_v2",schema_version=2,
		bay_mask_authority="unchanged_four_sample_round_capsule_union_then_two_literal_head_closure_wings",
		bay_base_predicate_id="strict_rational_variable_width_capsule_union_v1",
		bay_base_terms="v_equals_B_minus_A_L_equals_dot_v_v_N_equals_dot_P_minus_A_v_C_equals_cross_v_P_minus_A_width_num_equals_rA_times_L_minus_N_plus_rB_times_N",
		bay_base_segment_membership="zero_strictly_less_N_and_N_strictly_less_L_and_C_squared_times_L_strictly_less_than_width_num_squared",
		bay_base_cap_membership="N_less_equal_zero_uses_strict_squared_distance_to_A_less_than_rA_squared_N_greater_equal_L_uses_B_and_rB",
		bay_base_early_reject="for_segment_body_absolute_C_greater_equal_max_r_times_ceil_isqrt_L_is_outside_before_products",
		bay_base_product_guard="each_segment_max_r_squared_times_L_squared_and_guarded_cross_bound_squared_times_L_at_most_2_pow_53_minus_1",
		bay_base_arithmetic="exact_safe_integer_products_only_no_q16_projection_width_rounding_or_float_division",
		bay_displacement_source="bay_record_noise_domain_and_max_displacement",
		bay_displacement_hash="deterministic.new_hash_grug_wp40_geometry_source_v1_empty_feature_candidate_zero",
		bay_displacement_lane=0,
		bay_displacement_symmetry="one_radius_delta_applied_equally_to_both_banks_unchanged_centreline",
		bay_displacement_projection_station="minimum_exact_squared_euclidean_distance_to_canonical_stations_of_evaluated_authored_segment_lower_canonical_station_index_tie",
		bay_displacement_projection_kat="bay_elandor_west_segment_1_point_minus1376_minus2846_selects_zero_based_station_2_minus980_minus2938_not_parametric_round_station_1",
		bay_displacement_octave_periods={256,512},
		bay_displacement_octave_hash_lanes={0,1},
		bay_displacement_octave_amplitudes={fraction(2,3),fraction(1,3)},
		bay_displacement_noise="ordered_two_octave_t1_value_noise_q16_sum_clamped_minus_Q_to_plus_Q_at_selected_station",
		bay_displacement_taper_metric="canonical_segment_station_steps_to_nearest_authored_sample",
		bay_displacement_taper="smootherstep_clamped_min_station_steps_from_segment_ends_div_96_zero_at_every_sample",
		bay_displacement_delta_rule="delta_nodes_equals_qround_qmul_qmul_noise_q_max_displacement_times_Q_taper_q",
		bay_displacement_exact_body="effective_width_num_equals_base_width_num_plus_delta_nodes_times_L_then_C_squared_times_L_strictly_less_effective_width_num_squared",
		bay_displacement_product_guard="effective_width_square_max_4243584391840000_actual_guarded_cross_square_times_L_max_4251571423760000_and_conservative_early_cross_bound_4251754341463400_all_below_2_pow_53_minus_1",
		bay_displacement_clip="clip_open_mouth_to_literal_perimeter_and_reject_head_width_below_64_or_topology_change",
		bay_join_cap_rule="round_union_at_vertices_and_head; mouth_open_at_perimeter_projection",
		bay_mask_membership="strict_rational_variable_width_capsule_union_v1",
		bay_boundary_tie="analytic_bank_and_cap_equality_belongs_to_adjacent_dry_face",
		closure_wing_policy_id="strict_tapered_bay_closure_wing_v1",
		closure_wing_source="exactly_two_literal_bay_closure_wings_per_bay",
		closure_wing_axis="A_equals_fixed_fourth_centreline_head_sample_C_and_B_equals_declared_existing_triple_junction",
		closure_wing_radius="r_equals_80_at_A_linearly_tapered_to_zero_at_B",
		closure_wing_terms="v_equals_B_minus_A_L_equals_dot_v_v_N_equals_dot_P_minus_A_v_cross_equals_cross_v_P_minus_A_M_equals_L_minus_N",
		closure_wing_early_reject="absolute_cross_greater_equal_r_times_ceil_isqrt_L_is_outside_before_any_square_product",
		closure_wing_membership="zero_less_equal_N_and_N_strictly_less_than_L_and_cross_squared_times_L_strictly_less_than_r_squared_times_M_squared",
		closure_wing_product_guard="r_squared_times_L_squared_and_open_bound_square_times_L_must_not_exceed_2_pow_53_minus_1",
		closure_wing_jitter="zero",
		closure_wing_boundary_tie="side_equality_and_zero_width_terminal_junction_are_dry",
		closure_wing_owner_rule="signed_cross_selects_literal_left_or_right_zone_cross_zero_lower_numeric_zone",
		closure_wing_overlap_oracle="stage2_no_integer_column_in_two_wings_outside_unchanged_base_mask",
		bay_owner_projection_segment="minimum_exact_rational_segment_distance_compare_cross_squared_over_L_with_caps",
		bay_owner_distance_compare="reduce_cross_squared_times_other_L_by_gcd_before_safe_product_compare_caps_use_squared_integer_distance",
		bay_owner_side_rule="signed_integer_cross_C_of_selected_authored_segment_and_point",
		bay_owner_policy_id="exact_rational_minimum_segment_set_owner_v1",
		bay_owner_rule="literal_owner_span_for_each_exact_nearest_segment_then_lower_numeric_candidate_zone",
		bay_owner_segment_tie="exact_equal_rational_distance_collect_each_segment_candidate_owner_then_lower_numeric_zone_id",
		bay_owner_side_zero_rule="lower_zone_numeric_id_of_left_and_right_span_owners",
		bay_owner_failure="reject_uncovered_segment_or_unlisted_shore_zone",
		classification_precedence={"planned_base_bay_water_in_strict_mainland_interior_or_own_mouth_aperture_equality_then_closure_wing_water_in_strict_mainland_interior_only",
			"mainland_island_or_fixed_holy_land_strict_interior_or_remaining_perimeter_equality_owner",
			"strict_exterior_closed_dragon_channel_including_own_polygon_boundary",
			"strict_exterior_coastal_shelf_or_deep_ocean"},
		strict_exterior_rule="outside_every_final_mainland_island_and_fixed_holy_grounds_closed_footprint_after_all_planned_water_and_dry_land_equality_resolution",
		holy_land_authority="constants_holy_grounds_closed_rectangle_and_its_four_zone_face_partition_including_rectangle_equality",
		channel_policy_id="strict_exterior_closed_integer_polygon_channel_v1",
		channel_membership="nonzero_integer_winding_or_exact_channel_segment_equality",
		channel_boundary_rule="channel_polygon_boundary_is_included_only_when_point_is_already_strict_exterior",
		channel_precedence_rule="never_preempts_mainland_island_or_fixed_holy_interior_perimeter_aperture_base_bay_or_closure_wing_equality",
		coast_source_policy_id="exact_rational_nearest_allowed_outer_coast_component_v1",
		coast_source_role="dressing_and_policy_inheritance_only_never_zone_membership_race_region_territory_or_adjacency",
		coast_source_allowed_component_ids={
			"perimeter_span:elandor:stormvault","perimeter_span:elandor:frostbarrow",
			"perimeter_span:elandor:copperfell","perimeter_span:elandor:hearthpine",
			"perimeter_span:elandor:dawnmere","perimeter_span:elandor:silverleaf",
			"perimeter_span:elandor:starbough","perimeter_span:elandor:moonfall",
			"perimeter_span:elandor:glassroot","perimeter_span:kragmar:blackwind",
			"perimeter_span:kragmar:ossuary","perimeter_span:kragmar:mournfen",
			"perimeter_span:kragmar:stillgrave","perimeter_span:kragmar:sunscar",
			"perimeter_span:kragmar:kapok","perimeter_span:kragmar:raincall",
			"perimeter_span:kragmar:totemwater","perimeter_span:kragmar:thunderroot",
			"face_arc:gravesalt:holy_west","face_arc:skyglass:holy_east",
			"face_arc:wyrmglass:island","face_arc:stormscale:island",
		},
		coast_source_component_owner="compiled_perimeter_span_zone_id_or_compiled_outer_coast_face_arc_zone_id_including_fixed_holy_and_island_arcs",
		coast_source_segment_distance="for_projection_N_less_equal_zero_endpoint_A_squared_distance_over_one_N_greater_equal_L_endpoint_B_else_cross_C_squared_over_L",
		coast_source_minimum_rule="collect_every_exact_minimum_using_gcd_reduced_positive_rational_cross_multiplication_before_ownership_ties",
		coast_source_tie_rule="lower_zone_numeric_id_then_stable_component_id_then_zero_based_compiled_component_segment_index",
		coast_source_query_domain="compiled_interesting_extent_only_nil_outside",
		coast_source_max_coordinate_delta=8192,
		coast_source_max_compiled_segment_delta=1,
		coast_source_safe_bounds="endpoint_distance_squared_at_most_134217728_cross_squared_at_most_268435456_reduced_compare_product_at_most_536870912",
		outer_footprint_authority="literal_perimeter_polygon_after_sole_boundary_displacement",
		perimeter_equality_rule="inside_footprint_and_dry_except_matching_base_bay_mouth_aperture",
		perimeter_equality_span_owner="incident_perimeter_span_zone_id",
		perimeter_equality_attachment_precedence="shared_edge_half_open_lower_numeric_incident_zone_before_span_owner",
		perimeter_equality_vertex_tie="lower_numeric_zone_id_among_two_incident_unattached_spans",
		bay_mouth_aperture_policy_id="maximal_contiguous_nonwrapping_half_open_exact_base_bay_perimeter_stations_v1",
		bay_mouth_aperture_station_order="canonical_deduplicated_final_perimeter_integer_raster_order",
		bay_mouth_aperture_interval="first_station_included_through_station_before_end_station_included_end_station_excluded",
		bay_mouth_aperture_predicate="strict_rational_variable_width_capsule_union_v1_for_referenced_bay",
		bay_mouth_aperture_outside="preceding_start_and_excluded_end_fail_base_predicate_and_use_dry_perimeter_tie",
		bay_mouth_aperture_shelf="immediate_strictly_outside_neighbor_is_coastal_shelf",
		wing_footprint_clip="strict_footprint_interior_only_never_mouth_aperture_equality",
		dry_face_clip_rule="clip_dry_faces_and_bay_masks_to_final_literal_perimeter",
		outer_footprint_rule="independent_final_literal_perimeter_not_face_union",
		shelf_rule="outward_from_outer_footprint_never_from_internal_bay_shore",
		ordered_component_oracle="stage2_composed_union_outer_boundary_equals_perimeter_ordered_outer_components",
		stage2_partition_oracle="every_finite_footprint_column_exactly_one_dry_face_or_bay_water_owner",
		raw_dry_multiplicity_rule="exactly_one_outside_strict_final_bay_masks_at_least_one_inside",
		cross_face_intersection_rule="forbidden_outside_strict_final_bay_masks_allowed_under_bay_precedence",
		dual_graph_rule="derive_only_from_the_61_shared_land_edges_never_from_underwater_raw_face_overlap",
		stage2_mouth_oracle="each_mouth_open_at_projection_head_closed_positive_width",
		stage2_water_class_oracle="bay_always_planned_water_never_shelf_or_deep",
	},
	geometry_fixture_selector = {
		id="geometry_microcorpus_selector_v1",schema_version=1,
		coordinate_space="signed_mapchunk_coordinates",
		mapchunk_width=80,candidate_min=-40,candidate_max=39,
		candidate_extent_rule="centered_half_open_80_by_80_by_80_mapchunk_cube",
		candidate_iteration_order={"cy","cz","cx"},
		vertical_slice_rule="candidate_mapchunk_must_intersect_the_complete_closed_y_extent_of_every_required_family_named_by_the_class",
		classes={
			{id=1,predicate_id="deep_noop_outside_all_wp40_operation_extents",feature_family_ids={"compiled_operation_envelopes"},score={{"minimum_vertical_clearance_to_any_operation_extent","greatest"}}},
			{id=2,predicate_id="ordinary_inland_surface_without_other_required_family",feature_family_ids={"zone_faces"},score={{"minimum_distance_to_any_non_zone_surface_feature","greatest"}}},
			{id=3,predicate_id="ordinary_shared_zone_boundary_intersection",feature_family_ids={"land_edges"},score={{"intersected_boundary_count","greatest"},{"center_squared_distance_to_nearest_boundary","least"}}},
			{id=4,predicate_id="outer_coast_shelf_deep_transition_intersection",feature_family_ids={"perimeters","islands"},score={{"distinct_water_class_count","greatest"},{"center_squared_distance_to_outer_coast","least"}}},
			{id=5,predicate_id="holy_boundary_surface_or_shallow_floor_transition",feature_family_ids={"perimeter_holy_grounds","shallow_floor_transition"},score={{"distinct_holy_transition_class_count","greatest"},{"center_squared_distance_to_holy_boundary","least"}}},
			{id=6,predicate_id="capital_or_start_blend_envelope_intersection",feature_family_ids={"hard_protection"},score={{"intersected_capital_start_envelope_count","greatest"},{"center_squared_distance_to_envelope_center","least"}}},
			{id=7,predicate_id="route_hydrology_or_fixed_interface_intersection",feature_family_ids={"routes","island_routes","poi_spurs","hydrology","route_crossing_interfaces"},score={{"distinct_required_feature_kind_count","greatest"},{"intersected_feature_count","greatest"}}},
			{id=8,predicate_id="large_mandatory_structure_envelope_intersection",feature_family_ids={"claim_exclusions"},score={{"intersected_envelope_area","greatest"},{"source_anchor_numeric_id","least"}}},
			{id=9,predicate_id="dragon_island_landing_and_channel_intersection",feature_family_ids={"islands","island_landings","channels","island_routes"},score={{"distinct_required_feature_kind_count","greatest"},{"center_squared_distance_to_island_center","least"}}},
		},
		final_tie_order={"cy_least","cz_least","cx_least","feature_numeric_id_least"},
		append_only_later_classes={10,11},
	},
	requester_trace = {
		id="requester_trace_manifest_v1",schema_version=1,
		requester_count=100,requester_index_min=0,requester_index_max=99,
		road_profile_family_ids={"routes","island_routes","poi_spurs"},
		road_profile_inclusion="every_compiled_non_patrol_land_route_profile",
		road_profile_sort_key={"family_numeric_order","record_numeric_id","stable_id"},
		legal_land_profile_source="same_sorted_road_profiles_filtered_by_every_sampled_column_flight_legal",
		flight_legal_predicate_id="not_holy_not_warning_not_hard_no_flight_and_inside_compiled_land",
		stable_anchor_family_id="anchors",stable_anchor_sort_key={"numeric_id","stable_id"},
		active_tick_first=0,active_tick_last=3333,active_tick_count=3334,
		active_time_rule="t_equals_9_times_k_div_100_and_t_less_than_300",
		recovery_tick_count=2000,recovery_dtime=fraction(9,100),
		recovery_duration_seconds=180,
		requester_groups={{0,14,"road",4},{15,29,"road",6},{30,44,"road",8},
			{45,59,"legal_land_flight",7},{60,74,"legal_land_flight",10},
			{75,99,"anchor_jump_every_10_seconds",0}},
		profile_assignment="round_robin_by_requester_index",
		phase_rule="equal_rational_arc_length_phases_in_requester_index_order",
		position_q="Q16_16",request_position_rounding="floor_each_coordinate",
		request_box_half_extent=80,mapblock_transition_width=16,
	},
	geometry_extreme_selector = {
		id="geometry_extreme_seed_selector_v1",schema_version=1,
		candidate_label_rule="grudgelands-wp40-extreme-plus-four_zero_padded_decimal_digits_0000_through_4095",
		candidate_seed_rule="unsigned_big_endian_first_eight_sha256_bytes_as_canonical_unsigned_decimal",
		candidate_count=4096,score_all_candidates_before_stage2=true,
		skip_rule="only_duplicate_fixed_corpus_seed_or_seed_already_selected_for_prior_slot",
		coast_sample_families={"outer_coast_face_arc_spans","island_coast_face_arc_spans"},
		noncoast_sample_families={"all_positive_displacement_shared_land_edges"},
		sample_filter="record_max_displacement_strictly_positive",
		sample_sequence="pre_displacement_canonical_source_segment_raster_only_never_final_reraster_stations",
		coast_mainland_sequence="union_of_eligible_outer_source_perimeter_segments_in_perimeter_id_then_zero_based_source_segment_then_local_station_order",
		coast_mainland_identity="perimeter_id_zero_based_source_segment_index_zero_based_local_station_index",
		coast_mainland_overlap_rule="perimeter_span_overlap_never_duplicates_a_source_segment_or_station_in_the_union",
		island_sequence="eligible_island_outer_arc_id_then_zero_based_source_segment_then_local_station_order",
		island_identity="arc_id_zero_based_source_segment_index_zero_based_local_station_index",
		noncoast_sequence="eligible_positive_shared_land_edge_numeric_id_then_zero_based_source_segment_then_local_station_order",
		noncoast_identity="edge_id_zero_based_source_segment_index_zero_based_local_station_index",
		source_join_dedup="duplicate_segment_join_and_closed_seam_station_keeps_the_stable_earlier_identity_in_the_declared_sequence",
		scalar_sample_rule="each_unique_source_station_scores_its_post_noise_damping_local_clip_pre_component_scalar_q_exactly_once",
		attachment_rule="provisional_E_perimeter_A_discarded_prefix_suffix_and_inserted_final_reraster_stations_never_enter_selector_sequence",
		no_interpolation_rule="never_interpolate_resample_or_rehash_a_selector_scalar",
		scalar_stage="final_signed_q16_after_noise_damping_and_local_magnitude_clip_before_x_z_component_rounding",
		normalization_denominator="record_max_displacement_times_Q_not_local_damped_amplitude",
		score_rule="exact_mean_of_normalized_signed_q16_scalars",
		exact_sum_rule="gcd_reduce_each_term_and_accumulator_before_cross_multiply",
		safe_integer_proof="each_reduced_cross_product_and_sum_must_be_within_2_pow_53_minus_1_or_selector_rejects",
		slots={{"greatest_coast","coast","greatest"},{"least_coast","coast","least"},
			{"greatest_noncoast","noncoast","greatest"},{"least_noncoast","noncoast","least"}},
		score_tie="numerically_smaller_unsigned_decimal_seed",
		selected_stage2_rule="compile_and_validate_four_selected_seeds_invalid_selected_seed_fails_without_fallback",
	},
	hydrology_mask = {
		id="analytic_reach_round_union_sealed_v1",schema_version=1,
		centreline_policy_ref="hydrology.centreline",
		width_source_ref="hydrology.centreline.half_width",
		profile_source_ref="hydrology_profiles.depth_bed_seal_layers_bank_seal_nodes_bank_blend_width",
		transition_source_ref="hydrology_transition_profiles.open_face_and_seal_semantic_id",
		interface_axis_rule="last_distinct_upper_reach_station_to_first_distinct_lower_reach_station",
		interface_raster_rule="route_raster_policy_canonical_endpoint_sequence_in_authored_flow_direction",
		rapid_run_interval="floor_run_div_two_stations_upstream_plus_interface_plus_remaining_stations_downstream",
		rapid_level_rule="qlerp_upper_W_to_lower_W_by_raster_station_index_over_run_then_qround_half_away_from_zero",
		rapid_width_rule="qlerp_upper_endpoint_width_to_lower_endpoint_width_by_same_station_fraction",
		waterfall_axis_rule="upper_reach_last_distinct_station_through_position_to_lower_reach_first_distinct_station",
		centreline_rule="authored_polyline_segment_union",
		width_rule="qlerp_endpoint_half_width_by_clamped_segment_projection_q16",
		projection_tie_rule="lowest_authored_segment_index",
		mask_rule="squared_distance_less_than_or_equal_interpolated_half_width_squared",
		join_rule="round_union_at_every_authored_vertex",
		cap_rule="round_cap_at_open_reach_endpoints",
		bed_rule="bed_y_equals_W_minus_profile_depth",
		water_rule="source_nodes_bed_y_plus_one_through_W_inclusive",
		bank_crest_rule="maximum_H_and_W_plus_one",
		bank_skirt_horizontal_nodes=2,
		bank_skirt_vertical_rule="bank_crest_through_bed_y_minus_three_inclusive",
		bank_blend_rule="profile_width_one_minus_t1_smootherstep_to_H",
		bed_rounding="t1_qround_half_away_from_zero",
		transition_volume_rule="union_profile_seals_then_remove_only_declared_open_faces",
		seal_rule="three_bed_layers_two_horizontal_bank_nodes_no_native_widening",
	},
	route_vertical_interfaces = {
		id="route_water_vertical_interfaces_v1",schema_version=1,
		bridge={id="bridge_clearance_v1",minimum_clearance_nodes=3,
			deck_y_rule="W_plus_minimum_clearance_plus_one",open_volume_rule="W_plus_one_through_deck_y_minus_one"},
		ford={id="ford_bed_v1",road_y_rule="W_minus_profile_depth",
			water_rule="surface_water_source_at_W_above_road"},
		causeway={id="causeway_culvert_v1",deck_y_rule="W_plus_one",
			culvert_rule="open_bed_y_plus_one_through_W_below_deck",
			cross_section_rule="closed_bed_and_bank_seals_except_culvert"},
		tunnel={id="tunnel_lumen_v1",road_y_rule="route_profile_y",
			clear_nodes_above_road=5,roof_inner_y_rule="road_y_plus_six",
			lining_thickness=2,portal_length=16,
			portal_rule="open_only_two_declared_end_faces"},
	},
	anchor_connection_policy = {
		{id="start",connection="land_route",class="primary"},
		{id="capital",connection="land_route",class="primary"},
		{id="village",connection="poi_spur",class="secondary"},
		{id="outpost",connection="poi_spur",class="secondary"},
		{id="mine",connection="poi_spur",class="secondary"},
		{id="bandit",connection="minor_poi",class="trail"},
		{id="mirefolk",connection="minor_poi",class="trail"},
		{id="clash",connection="local_war_anchor",class="trail"},
		{id="rare",connection="patrol_offsets",class="trail"},
		{id="dragon",connection="island_route",class="secondary"},
		{id="apex_mine",connection="island_route",class="secondary"},
	},
}

source.relief_profiles = {
	{id = "wetland_delta", min_above_water = 2, max_above_water = 24,
		noise_domain = "relief_wetland_delta", octaves = {
			{period = 512, amplitude = fraction(3, 5)},
			{period = 256, amplitude = fraction(2, 5)},
		}},
	{id = "lowland", min_above_water = 8, max_above_water = 56,
		noise_domain = "relief_lowland", octaves = {
			{period = 768, amplitude = fraction(2, 3)},
			{period = 256, amplitude = fraction(1, 3)},
		}},
	{id = "rolling_hills", min_above_water = 24, max_above_water = 96,
		noise_domain = "relief_rolling_hills", octaves = {
			{period = 768, amplitude = fraction(3, 5)},
			{period = 384, amplitude = fraction(2, 5)},
		}},
	{id = "plateau", min_above_water = 56, max_above_water = 144,
		noise_domain = "relief_plateau", octaves = {
			{period = 1024, amplitude = fraction(3, 4)},
			{period = 384, amplitude = fraction(1, 4)},
		}},
	{id = "highland", min_above_water = 96, max_above_water = 224,
		noise_domain = "relief_highland", octaves = {
			{period = 1024, amplitude = fraction(2, 3)},
			{period = 512, amplitude = fraction(1, 3)},
		}},
	{id = "mountain", min_above_water = 160, max_above_water = 360,
		noise_domain = "relief_mountain", octaves = {
			{period = 1280, amplitude = fraction(3, 5)},
			{period = 640, amplitude = fraction(3, 10)},
			{period = 320, amplitude = fraction(1, 10)},
		}},
}

source.route_classes = {
	{id = "primary", visible_width = 7, exclusion_width = 16,
		max_cut = 8, max_fill = 6, tunnel_lumen_width = 9,
		tunnel_clear_height = 5, max_grade = fraction(1,12),
		minimum_transition_run = 12, grade_step = 1,
		grade_phase_rule = "flat_run_at_fixed_interface",
		cross_section_id = "road_primary_v1", lateral_blend_width = 8,
		transition_semantic_id = "road_climb_stair_v1"},
	{id = "secondary", visible_width = 5, exclusion_width = 12,
		max_cut = 6, max_fill = 4, tunnel_lumen_width = 7,
		tunnel_clear_height = 5, max_grade = fraction(1,8),
		minimum_transition_run = 8, grade_step = 1,
		grade_phase_rule = "flat_run_at_fixed_interface",
		cross_section_id = "road_secondary_v1", lateral_blend_width = 6,
		transition_semantic_id = "road_climb_stair_v1"},
	{id = "trail", visible_width = 3, exclusion_width = 8,
		max_cut = 3, max_fill = 2, tunnel_lumen_width = 5,
		tunnel_clear_height = 5, max_grade = fraction(1,4),
		minimum_transition_run = 4, grade_step = 1,
		grade_phase_rule = "flat_run_at_fixed_interface",
		cross_section_id = "road_trail_v1", lateral_blend_width = 4,
		transition_semantic_id = "road_climb_stair_v1"},
}

source.water_classes = {
	{id = "land", authored_source = false, full_column_immutable = false},
	{id = "planned_water", authored_source = true, full_column_immutable = false},
	{id = "coastal_shelf", authored_source = true, full_column_immutable = false},
	{id = "deep_ocean", authored_source = true, full_column_immutable = true},
	{id = "immutable_dragon_channel", authored_source = true,
		full_column_immutable = true},
}

source.landmark_role_vocabulary = {
	"base_H", "target_T", "hydrology", "route", "interface", "dressing",
}

source.template_primitives = {
	{id="flat",version=1,parameters={"height_offset"}},
	{id="tilt",version=1,parameters={"axis_x","axis_z","rise","run"}},
	{id="terrace",version=1,parameters={"step_height","step_run","rings"}},
	{id="plateau",version=1,parameters={"inner_radius","shoulder_width"}},
	{id="basin",version=1,parameters={"inner_radius","depth","rim_width"}},
	{id="rim",version=1,parameters={"inner_radius","peak_radius","outer_radius","height"}},
	{id="causeway",version=1,parameters={"surface_width","backing_depth"}},
	{id="cross_section",version=1,parameters={"surface_width","corridor_width"}},
	{id="housing_smoothing",version=1,parameters={"radius","relief_limit"}},
}

source.zones = {
	zone(1, "elandor_hearthpine_vale", "Hearthpine Vale", "dwarf", "accord", "accord_home", "peaceful", 1, 10, "lowland", palette(biome("grug_pine_hills", 90), biome("grug_crags", 10)), false),
	zone(2, "elandor_copperfell_foothills", "Copperfell Foothills", "dwarf", "accord", "accord_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_pine_hills", 75), biome("grug_crags", 25)), false),
	zone(3, "elandor_dur_brannoc", "Dur Brannoc", "dwarf", "accord", "accord_home", "peaceful", 20, 30, "plateau", palette(biome("grug_pine_hills", 60), biome("grug_crags", 40)), true),
	zone(4, "elandor_frostbarrow_shelf", "Frostbarrow Shelf", "dwarf", "accord", "accord_home", "peaceful", 21, 30, "plateau", palette(biome("grug_pine_hills", 55), biome("grug_crags", 40), biome("grug_swamp", 5)), false),
	zone(5, "elandor_stormvault_heights", "Stormvault Heights", "dwarf", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_crags", 75), biome("grug_crags_snowy", 25)), false),
	zone(6, "elandor_dawnmere_fields", "Dawnmere Fields", "human", "accord", "accord_home", "peaceful", 1, 10, "lowland", palette(biome("grug_meadows", 85), biome("grug_deep_forest", 5), biome("grug_swamp", 10)), false),
	zone(7, "elandor_goldmead_vale", "Goldmead Vale", "human", "accord", "accord_home", "peaceful", 11, 20, "lowland", palette(biome("grug_meadows", 65), biome("grug_deep_forest", 20), biome("grug_swamp", 15)), false),
	zone(8, "elandor_highcourt", "Highcourt", "human", "accord", "accord_home", "peaceful", 20, 30, "rolling_hills", palette(biome("grug_meadows", 80), biome("grug_deep_forest", 20)), true),
	zone(9, "elandor_whitebridge_shire", "Whitebridge Shire", "human", "accord", "accord_home", "peaceful", 21, 30, "lowland", palette(biome("grug_meadows", 50), biome("grug_deep_forest", 35), biome("grug_swamp", 15)), false),
	zone(10, "elandor_ashenward_march", "Ashenward March", "human", false, "contested_land", "contested", 31, 40, "rolling_hills", palette(biome("grug_deep_forest", 50), biome("grug_meadows", 30), biome("grug_swamp", 20)), false),
	zone(11, "elandor_silverleaf_glades", "Silverleaf Glades", "elf", "accord", "accord_home", "peaceful", 1, 10, "lowland", palette(biome("grug_elf_forest", 95), biome("grug_deep_forest", 5)), false),
	zone(12, "elandor_starbough_vale", "Starbough Vale", "elf", "accord", "accord_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_elf_forest", 80), biome("grug_deep_forest", 20)), false),
	zone(13, "elandor_lethariel", "Lethariel", "elf", "accord", "accord_home", "peaceful", 20, 30, "rolling_hills", palette(biome("grug_elf_forest", 90), biome("grug_deep_forest", 10)), true),
	zone(14, "elandor_lorindor", "Lorindor", "elf", "accord", "accord_home", "peaceful", 21, 30, "rolling_hills", palette(biome("grug_elf_forest", 50), biome("grug_deep_forest", 30), biome("grug_swamp", 20)), false),
	zone(15, "elandor_moonfall_wood", "Moonfall Wood", "elf", "accord", "accord_home", "peaceful", 21, 30, "lowland", palette(biome("grug_elf_forest", 40), biome("grug_deep_forest", 45), biome("grug_swamp", 15)), false),
	zone(16, "elandor_glassroot_wilds", "Glassroot Wilds", "elf", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_deep_forest", 45), biome("grug_jungle_fringe", 35), biome("grug_elf_forest", 10), biome("grug_swamp", 10)), false),
	zone(17, "kragmar_stillgrave_hollow", "Stillgrave Hollow", "undead", "throng", "throng_home", "peaceful", 1, 10, "lowland", palette(biome("grug_blight", 90), biome("grug_bone_forest", 5), biome("grug_swamp", 5)), false),
	zone(18, "kragmar_mournfen", "Mournfen", "undead", "throng", "throng_home", "peaceful", 11, 20, "wetland_delta", palette(biome("grug_blight", 60), biome("grug_bone_forest", 10), biome("grug_swamp", 30)), false),
	zone(19, "kragmar_nhal_veyr", "Nhal Veyr", "undead", "throng", "throng_home", "peaceful", 20, 30, "plateau", palette(biome("grug_blight", 75), biome("grug_bone_forest", 25)), true),
	zone(20, "kragmar_ossuary_reach", "Ossuary Reach", "undead", "throng", "throng_home", "peaceful", 21, 30, "rolling_hills", palette(biome("grug_blight", 40), biome("grug_bone_forest", 50), biome("grug_swamp", 10)), false),
	zone(21, "kragmar_blackwind_rise", "Blackwind Rise", "undead", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_bone_forest", 65), biome("grug_blight", 30), biome("grug_swamp", 5)), false),
	zone(22, "kragmar_sunscar_flats", "Sunscar Flats", "orc", "throng", "throng_home", "peaceful", 1, 10, "lowland", palette(biome("grug_savanna", 95), biome("grug_badlands", 5)), false),
	zone(23, "kragmar_redtusk_savanna", "Redtusk Savanna", "orc", "throng", "throng_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_savanna", 75), biome("grug_badlands", 25)), false),
	zone(24, "kragmar_gor_drazhak", "Gor Drazhak", "orc", "throng", "throng_home", "peaceful", 20, 30, "plateau", palette(biome("grug_savanna", 60), biome("grug_badlands", 40)), true),
	zone(25, "kragmar_speargrass_reach", "Speargrass Reach", "orc", "throng", "throng_home", "peaceful", 21, 30, "rolling_hills", palette(biome("grug_savanna", 55), biome("grug_badlands", 40), biome("grug_swamp", 5)), false),
	zone(26, "kragmar_bannerbreak_mesa", "Bannerbreak Mesa", "orc", false, "contested_land", "contested", 31, 40, "plateau", palette(biome("grug_badlands", 70), biome("grug_savanna", 25), biome("grug_swamp", 5)), false),
	zone(27, "kragmar_kapok_cradle", "Kapok Cradle", "troll", "throng", "throng_home", "peaceful", 1, 10, "lowland", palette(biome("grug_jungle_edge", 90), biome("grug_swamp", 10)), false),
	zone(28, "kragmar_raincall_basin", "Raincall Basin", "troll", "throng", "throng_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_jungle_edge", 65), biome("grug_deep_jungle", 15), biome("grug_swamp", 20)), false),
	zone(29, "kragmar_kezamba", "Kezamba", "troll", "throng", "throng_home", "peaceful", 20, 30, "plateau", palette(biome("grug_jungle_edge", 75), biome("grug_deep_jungle", 20), biome("grug_swamp", 5)), true),
	zone(30, "kragmar_whispering_reedlands", "Whispering Reedlands", "troll", "throng", "throng_home", "peaceful", 21, 30, "wetland_delta", palette(biome("grug_jungle_edge", 45), biome("grug_deep_jungle", 25), biome("grug_swamp", 30)), false),
	zone(31, "kragmar_totemwater_reach", "Totemwater Reach", "troll", "throng", "throng_home", "peaceful", 21, 30, "wetland_delta", palette(biome("grug_jungle_edge", 35), biome("grug_deep_jungle", 45), biome("grug_swamp", 20)), false),
	zone(32, "kragmar_thunderroot_wilds", "Thunderroot Wilds", "troll", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_deep_jungle", 55), biome("grug_badlands_east", 30), biome("grug_swamp", 15)), false),
	zone(33, "front_wyrmglass_crown", "The Wyrmglass Crown", "dwarf", false, "contested_land", "contested", 60, 60, "mountain", palette(biome("grug_crags", 55), biome("grug_crags_snowy", 30), biome("grug_beach", 15)), false),
	zone(34, "front_gravesalt_escarpment", "Gravesalt Escarpment", "undead", false, "holy_grounds", "contested", 51, 59, "highland", palette(biome("grug_bone_forest", 55), biome("grug_blight", 15), biome("grug_swamp", 15), biome("grug_beach", 15)), false),
	zone(35, "front_broken_causeway", "The Broken Causeway", "human", false, "holy_grounds", "contested", 31, 40, "wetland_delta", palette(biome("grug_meadows", 40), biome("grug_deep_forest", 25), biome("grug_swamp", 35)), false),
	zone(36, "front_shattered_line", "The Shattered Line", "orc", false, "holy_grounds", "contested", 41, 50, "plateau", palette(biome("grug_badlands", 65), biome("grug_savanna", 20), biome("grug_swamp", 15)), false),
	zone(37, "front_skyglass_canopy", "The Skyglass Canopy", "elf", false, "holy_grounds", "contested", 51, 59, "highland", palette(biome("grug_jungle_fringe", 60), biome("grug_deep_forest", 25), biome("grug_elf_forest", 15)), false),
	zone(38, "front_stormscale_summit", "Stormscale Summit", "troll", false, "contested_land", "contested", 60, 60, "mountain", palette(biome("grug_deep_jungle", 50), biome("grug_badlands_east", 20), biome("grug_swamp", 15), biome("grug_beach", 15)), false),
}

local function edge(numeric_id, a, b, route_class, displacement, controls)
	return {
		numeric_id = numeric_id,
		id = ("land_%03d"):format(numeric_id),
		zone_a = a,
		zone_b = b,
		max_displacement = displacement,
		noise_domain = ("boundary_land_%03d"):format(numeric_id),
		control = controls,
	}
end

-- Land boundaries own adjacency and boundary shape only. Route class and road
-- geometry are separate authorities below; the fourth literal argument above
-- is retained solely to make the fixed §9.4 class list readable beside the
-- fixed adjacency list and is deliberately not copied into a boundary record.

source.land_edges = {
	-- Six race spines. The start/home records retain every fixed §7 vertex.
	edge(1, "elandor_hearthpine_vale", "elandor_copperfell_foothills", "primary", 64, {point(-2700,-2760),point(-2310,-2570),point(-2150,-2210),point(-1800,-2140),point(-1450,-2210),point(-1050,-2250)}),
	edge(2, "elandor_copperfell_foothills", "elandor_dur_brannoc", "primary", 64, {point(-2200,-1900),point(-1400,-1900)}),
	edge(3, "elandor_dur_brannoc", "elandor_stormvault_heights", "primary", 32, {point(-2200,-1100),point(-1400,-1100)}),
	edge(4, "elandor_dawnmere_fields", "elandor_goldmead_vale", "primary", 64, {point(-1050,-2250),point(-650,-2230),point(-350,-2170),point(0,-2120),point(350,-2180),point(650,-2240),point(950,-2250)}),
	edge(5, "elandor_goldmead_vale", "elandor_highcourt", "primary", 64, {point(-400,-1900),point(400,-1900)}),
	edge(6, "elandor_highcourt", "elandor_ashenward_march", "primary", 32, {point(-400,-1100),point(400,-1100)}),
	edge(7, "elandor_silverleaf_glades", "elandor_starbough_vale", "primary", 64, {point(950,-2250),point(1450,-2210),point(1800,-2150),point(2150,-2230),point(2310,-2580),point(2700,-2740)}),
	edge(8, "elandor_starbough_vale", "elandor_lethariel", "primary", 64, {point(1400,-1900),point(2200,-1900)}),
	edge(9, "elandor_lethariel", "elandor_glassroot_wilds", "primary", 32, {point(1400,-1100),point(2200,-1100)}),
	edge(10, "kragmar_stillgrave_hollow", "kragmar_mournfen", "primary", 64, {point(-2700,2740),point(-2320,2580),point(-2160,2210),point(-1800,2140),point(-1440,2200),point(-970,2260)}),
	edge(11, "kragmar_mournfen", "kragmar_nhal_veyr", "primary", 64, {point(-2200,1900),point(-1400,1900)}),
	edge(12, "kragmar_nhal_veyr", "kragmar_blackwind_rise", "primary", 32, {point(-2200,1100),point(-1400,1100)}),
	edge(13, "kragmar_sunscar_flats", "kragmar_redtusk_savanna", "primary", 64, {point(-970,2260),point(-660,2240),point(-360,2180),point(0,2130),point(360,2190),point(680,2230),point(1020,2250)}),
	edge(14, "kragmar_redtusk_savanna", "kragmar_gor_drazhak", "primary", 64, {point(-400,1900),point(400,1900)}),
	edge(15, "kragmar_gor_drazhak", "kragmar_bannerbreak_mesa", "primary", 32, {point(-400,1100),point(400,1100)}),
	edge(16, "kragmar_kapok_cradle", "kragmar_raincall_basin", "primary", 64, {point(1020,2250),point(1440,2200),point(1800,2140),point(2160,2210),point(2320,2590),point(2700,2760)}),
	edge(17, "kragmar_raincall_basin", "kragmar_kezamba", "primary", 64, {point(1400,1900),point(2200,1900)}),
	edge(18, "kragmar_kezamba", "kragmar_thunderroot_wilds", "primary", 32, {point(1400,1100),point(2200,1100)}),
	-- The two six-edge capital axes.
	edge(19, "elandor_frostbarrow_shelf", "elandor_dur_brannoc", "primary", 64, {point(-2200,-1900),point(-2200,-1100)}),
	edge(20, "elandor_dur_brannoc", "elandor_whitebridge_shire", "primary", 64, {point(-1400,-1900),point(-1400,-1100)}),
	edge(21, "elandor_whitebridge_shire", "elandor_highcourt", "primary", 64, {point(-400,-1900),point(-400,-1100)}),
	edge(22, "elandor_highcourt", "elandor_lorindor", "primary", 64, {point(400,-1900),point(400,-1100)}),
	edge(23, "elandor_lorindor", "elandor_lethariel", "primary", 64, {point(1400,-1900),point(1400,-1100)}),
	edge(24, "elandor_lethariel", "elandor_moonfall_wood", "primary", 64, {point(2200,-1900),point(2200,-1100)}),
	edge(25, "kragmar_ossuary_reach", "kragmar_nhal_veyr", "primary", 64, {point(-2200,1100),point(-2200,1900)}),
	edge(26, "kragmar_nhal_veyr", "kragmar_speargrass_reach", "primary", 64, {point(-1400,1100),point(-1400,1900)}),
	edge(27, "kragmar_speargrass_reach", "kragmar_gor_drazhak", "primary", 64, {point(-400,1100),point(-400,1900)}),
	edge(28, "kragmar_gor_drazhak", "kragmar_whispering_reedlands", "primary", 64, {point(400,1100),point(400,1900)}),
	edge(29, "kragmar_whispering_reedlands", "kragmar_kezamba", "primary", 64, {point(1400,1100),point(1400,1900)}),
	edge(30, "kragmar_kezamba", "kragmar_totemwater_reach", "primary", 64, {point(2200,1100),point(2200,1900)}),
	-- Heartland/front cross-links. The separator polylines preserve all fixed
	-- belt/front/Holy vertices and are shared by their incident zones.
	edge(31, "elandor_frostbarrow_shelf", "elandor_stormvault_heights", "secondary", 32, {point(-2600,-1100),point(-2200,-1100)}),
	edge(32, "elandor_whitebridge_shire", "elandor_ashenward_march", "secondary", 32, {point(-1400,-1100),point(-400,-1100)}),
	edge(33, "elandor_lorindor", "elandor_glassroot_wilds", "secondary", 32, {point(400,-1100),point(1400,-1100)}),
	edge(34, "elandor_moonfall_wood", "elandor_glassroot_wilds", "secondary", 32, {point(2200,-1100),point(2600,-1100)}),
	edge(35, "elandor_stormvault_heights", "elandor_ashenward_march", "secondary", 64, {point(-1400,-1100),point(-900,-900),point(-750,-250)}),
	edge(36, "elandor_ashenward_march", "elandor_glassroot_wilds", "secondary", 64, {point(400,-1100),point(900,-900),point(750,-250)}),
	edge(37, "kragmar_ossuary_reach", "kragmar_blackwind_rise", "secondary", 32, {point(-2600,1100),point(-2200,1100)}),
	edge(38, "kragmar_speargrass_reach", "kragmar_bannerbreak_mesa", "secondary", 32, {point(-1400,1100),point(-400,1100)}),
	edge(39, "kragmar_whispering_reedlands", "kragmar_thunderroot_wilds", "secondary", 32, {point(400,1100),point(1400,1100)}),
	edge(40, "kragmar_totemwater_reach", "kragmar_thunderroot_wilds", "secondary", 32, {point(2200,1100),point(2600,1100)}),
	edge(41, "kragmar_blackwind_rise", "kragmar_bannerbreak_mesa", "secondary", 64, {point(-1400,1100),point(-900,900),point(-750,250)}),
	edge(42, "kragmar_bannerbreak_mesa", "kragmar_thunderroot_wilds", "secondary", 64, {point(400,1100),point(900,900),point(750,250)}),
	-- Twelve fixed mainland/Holy contacts. Their z = +/-250 geometry has no
	-- jitter because it is the exact no-jitter Holy rectangle boundary.
	edge(43, "elandor_stormvault_heights", "front_gravesalt_escarpment", "secondary", 0, {point(-2500,-250),point(-1500,-250)}),
	edge(44, "elandor_stormvault_heights", "front_broken_causeway", "secondary", 0, {point(-1500,-250),point(-750,-250)}),
	edge(45, "elandor_ashenward_march", "front_broken_causeway", "secondary", 0, {point(-750,-250),point(0,-250)}),
	edge(46, "elandor_ashenward_march", "front_shattered_line", "secondary", 0, {point(0,-250),point(750,-250)}),
	edge(47, "elandor_glassroot_wilds", "front_shattered_line", "secondary", 0, {point(750,-250),point(1500,-250)}),
	edge(48, "elandor_glassroot_wilds", "front_skyglass_canopy", "secondary", 0, {point(1500,-250),point(2500,-250)}),
	edge(49, "kragmar_blackwind_rise", "front_gravesalt_escarpment", "secondary", 0, {point(-2500,250),point(-1500,250)}),
	edge(50, "kragmar_blackwind_rise", "front_broken_causeway", "secondary", 0, {point(-1500,250),point(-750,250)}),
	edge(51, "kragmar_bannerbreak_mesa", "front_broken_causeway", "secondary", 0, {point(-750,250),point(0,250)}),
	edge(52, "kragmar_bannerbreak_mesa", "front_shattered_line", "secondary", 0, {point(0,250),point(750,250)}),
	edge(53, "kragmar_thunderroot_wilds", "front_shattered_line", "secondary", 0, {point(750,250),point(1500,250)}),
	edge(54, "kragmar_thunderroot_wilds", "front_skyglass_canopy", "secondary", 0, {point(1500,250),point(2500,250)}),
	-- The three internal Holy boundaries carry the required west/east trails.
	edge(55, "front_gravesalt_escarpment", "front_broken_causeway", "trail", 64, {point(-1500,-250),point(-1500,0),point(-1500,250)}),
	edge(56, "front_broken_causeway", "front_shattered_line", "trail", 64, {point(0,-250),point(0,0),point(0,250)}),
	edge(57, "front_shattered_line", "front_skyglass_canopy", "trail", 64, {point(1500,-250),point(1500,0),point(1500,250)}),
	-- Reviewed boundary-only coast connectors. These close the four outer
	-- mainland sectors without creating a road, station, or interface.
	edge(58, "elandor_copperfell_foothills", "elandor_frostbarrow_shelf", false, 0, {point(-2600,-1900),point(-2200,-1900)}),
	edge(59, "elandor_starbough_vale", "elandor_moonfall_wood", false, 0, {point(2200,-1900),point(2600,-1900)}),
	edge(60, "kragmar_mournfen", "kragmar_ossuary_reach", false, 0, {point(-2600,1900),point(-2200,1900)}),
	edge(61, "kragmar_raincall_basin", "kragmar_totemwater_reach", false, 0, {point(2200,1900),point(2600,1900)}),
}
for boundary_index=58,61 do
	source.land_edges[boundary_index].boundary_only=true
end

-- A shared edge is the sole authority for both incident faces. This reviewed
-- literal table is deliberately independent of route order and zone_a/zone_b
-- storage order. Each probe lies strictly on the declared side of the first
-- directed control segment, giving Stage 1 an independent cross-product
-- oracle for left/right ownership.
local zone_numeric_by_id = {}
for zone_index = 1, #source.zones do
	zone_numeric_by_id[source.zones[zone_index].id] = zone_index
end
local edge_side_authority = {
	{"land_001","elandor_copperfell_foothills","elandor_hearthpine_vale",-2521,-2633,-2489,-2697},{"land_002","elandor_dur_brannoc","elandor_copperfell_foothills",-1800,-1868,-1800,-1932},{"land_003","elandor_stormvault_heights","elandor_dur_brannoc",-1800,-1068,-1800,-1132},
	{"land_004","elandor_goldmead_vale","elandor_dawnmere_fields",-852,-2208,-848,-2272},{"land_005","elandor_highcourt","elandor_goldmead_vale",0,-1868,0,-1932},{"land_006","elandor_ashenward_march","elandor_highcourt",0,-1068,0,-1132},
	{"land_007","elandor_starbough_vale","elandor_silverleaf_glades",1197,-2198,1203,-2262},{"land_008","elandor_lethariel","elandor_starbough_vale",1800,-1868,1800,-1932},{"land_009","elandor_glassroot_wilds","elandor_lethariel",1800,-1068,1800,-1132},
	{"land_010","kragmar_stillgrave_hollow","kragmar_mournfen",-2497,2692,-2523,2628},{"land_011","kragmar_mournfen","kragmar_nhal_veyr",-1800,1932,-1800,1868},{"land_012","kragmar_nhal_veyr","kragmar_blackwind_rise",-1800,1132,-1800,1068},
	{"land_013","kragmar_sunscar_flats","kragmar_redtusk_savanna",-813,2282,-817,2218},{"land_014","kragmar_redtusk_savanna","kragmar_gor_drazhak",0,1932,0,1868},{"land_015","kragmar_gor_drazhak","kragmar_bannerbreak_mesa",0,1132,0,1068},
	{"land_016","kragmar_kapok_cradle","kragmar_raincall_basin",1234,2257,1226,2193},{"land_017","kragmar_raincall_basin","kragmar_kezamba",1800,1932,1800,1868},{"land_018","kragmar_kezamba","kragmar_thunderroot_wilds",1800,1132,1800,1068},
	{"land_019","elandor_frostbarrow_shelf","elandor_dur_brannoc",-2232,-1500,-2168,-1500},{"land_020","elandor_dur_brannoc","elandor_whitebridge_shire",-1432,-1500,-1368,-1500},{"land_021","elandor_whitebridge_shire","elandor_highcourt",-432,-1500,-368,-1500},
	{"land_022","elandor_highcourt","elandor_lorindor",368,-1500,432,-1500},{"land_023","elandor_lorindor","elandor_lethariel",1368,-1500,1432,-1500},{"land_024","elandor_lethariel","elandor_moonfall_wood",2168,-1500,2232,-1500},
	{"land_025","kragmar_ossuary_reach","kragmar_nhal_veyr",-2232,1500,-2168,1500},{"land_026","kragmar_nhal_veyr","kragmar_speargrass_reach",-1432,1500,-1368,1500},{"land_027","kragmar_speargrass_reach","kragmar_gor_drazhak",-432,1500,-368,1500},
	{"land_028","kragmar_gor_drazhak","kragmar_whispering_reedlands",368,1500,432,1500},{"land_029","kragmar_whispering_reedlands","kragmar_kezamba",1368,1500,1432,1500},{"land_030","kragmar_kezamba","kragmar_totemwater_reach",2168,1500,2232,1500},
	{"land_031","elandor_stormvault_heights","elandor_frostbarrow_shelf",-2400,-1068,-2400,-1132},{"land_032","elandor_ashenward_march","elandor_whitebridge_shire",-900,-1068,-900,-1132},{"land_033","elandor_glassroot_wilds","elandor_lorindor",900,-1068,900,-1132},
	{"land_034","elandor_glassroot_wilds","elandor_moonfall_wood",2400,-1068,2400,-1132},{"land_035","elandor_stormvault_heights","elandor_ashenward_march",-1163,-968,-1137,-1032},{"land_036","elandor_ashenward_march","elandor_glassroot_wilds",637,-968,663,-1032},
	{"land_037","kragmar_ossuary_reach","kragmar_blackwind_rise",-2400,1132,-2400,1068},{"land_038","kragmar_speargrass_reach","kragmar_bannerbreak_mesa",-900,1132,-900,1068},{"land_039","kragmar_whispering_reedlands","kragmar_thunderroot_wilds",900,1132,900,1068},
	{"land_040","kragmar_totemwater_reach","kragmar_thunderroot_wilds",2400,1132,2400,1068},{"land_041","kragmar_bannerbreak_mesa","kragmar_blackwind_rise",-1137,1032,-1163,968},{"land_042","kragmar_thunderroot_wilds","kragmar_bannerbreak_mesa",663,1032,637,968},
	{"land_043","front_gravesalt_escarpment","elandor_stormvault_heights",-2000,-218,-2000,-282},{"land_044","front_broken_causeway","elandor_stormvault_heights",-1125,-218,-1125,-282},{"land_045","front_broken_causeway","elandor_ashenward_march",-375,-218,-375,-282},
	{"land_046","front_shattered_line","elandor_ashenward_march",375,-218,375,-282},{"land_047","front_shattered_line","elandor_glassroot_wilds",1125,-218,1125,-282},{"land_048","front_skyglass_canopy","elandor_glassroot_wilds",2000,-218,2000,-282},
	{"land_049","kragmar_blackwind_rise","front_gravesalt_escarpment",-2000,282,-2000,218},{"land_050","kragmar_blackwind_rise","front_broken_causeway",-1125,282,-1125,218},{"land_051","kragmar_bannerbreak_mesa","front_broken_causeway",-375,282,-375,218},
	{"land_052","kragmar_bannerbreak_mesa","front_shattered_line",375,282,375,218},{"land_053","kragmar_thunderroot_wilds","front_shattered_line",1125,282,1125,218},{"land_054","kragmar_thunderroot_wilds","front_skyglass_canopy",2000,282,2000,218},
	{"land_055","front_gravesalt_escarpment","front_broken_causeway",-1532,-125,-1468,-125},{"land_056","front_broken_causeway","front_shattered_line",-32,-125,32,-125},{"land_057","front_shattered_line","front_skyglass_canopy",1468,-125,1532,-125},
	{"land_058","elandor_frostbarrow_shelf","elandor_copperfell_foothills",-2400,-1868,-2400,-1932},
	{"land_059","elandor_moonfall_wood","elandor_starbough_vale",2400,-1868,2400,-1932},
	{"land_060","kragmar_mournfen","kragmar_ossuary_reach",-2400,1932,-2400,1868},
	{"land_061","kragmar_raincall_basin","kragmar_totemwater_reach",2400,1932,2400,1868},
}
-- Reviewed shared-edge gate bands, expressed as offsets above water. When two
-- raw relief bands overlap this is their exact intersection. When they do not,
-- the single lower midpoint is explicit transition implementation data; the
-- 96-node G blend owns that transition and both faces consume the same value.
local edge_gate_authority = {
	{"land_001",24,56},{"land_002",56,96},{"land_003",96,144},
	{"land_004",8,56},{"land_005",24,56},{"land_006",24,96},
	{"land_007",24,56},{"land_008",24,96},{"land_009",96,96},
	{"land_010",8,24},{"land_011",40,40},{"land_012",96,144},
	{"land_013",24,56},{"land_014",56,96},{"land_015",56,144},
	{"land_016",24,56},{"land_017",56,96},{"land_018",96,144},
	{"land_019",56,144},{"land_020",56,56},{"land_021",24,56},
	{"land_022",24,96},{"land_023",24,96},{"land_024",24,56},
	{"land_025",56,96},{"land_026",56,96},{"land_027",56,96},
	{"land_028",40,40},{"land_029",40,40},{"land_030",40,40},
	{"land_031",96,144},{"land_032",24,56},{"land_033",96,96},
	{"land_034",76,76},{"land_035",96,96},{"land_036",96,96},
	{"land_037",96,96},{"land_038",56,96},{"land_039",60,60},
	{"land_040",60,60},{"land_041",96,144},{"land_042",96,144},
	{"land_043",96,224},{"land_044",60,60},{"land_045",24,24},
	{"land_046",56,96},{"land_047",96,144},{"land_048",96,224},
	{"land_049",96,224},{"land_050",60,60},{"land_051",40,40},
	{"land_052",56,144},{"land_053",96,144},{"land_054",96,224},
	{"land_055",60,60},{"land_056",40,40},{"land_057",96,144},
	{"land_058",56,96},{"land_059",24,56},{"land_060",24,24},{"land_061",24,24},
}
local edge_by_id = {}
local function junction_id(p) return "junction:" .. p.x .. ":" .. p.z end
for edge_index = 1, #source.land_edges do
	local row = source.land_edges[edge_index]
	edge_by_id[row.id] = row
	row.from_junction_id = junction_id(row.control[1])
	row.to_junction_id = junction_id(row.control[#row.control])
end
for side_index = 1, #edge_side_authority do
	local authority = edge_side_authority[side_index]
	local row = edge_by_id[authority[1]]
	row.left_zone, row.right_zone = authority[2], authority[3]
	row.left_probe, row.right_probe = point(authority[4],authority[5]),
		point(authority[6],authority[7])
	row.probe_segment_index = 1
	row.tie_rule = "lower_zone_numeric_id"
	row.tie_zone_id = zone_numeric_by_id[row.zone_a] < zone_numeric_by_id[row.zone_b]
		and row.zone_a or row.zone_b
end
for gate_index=1,#edge_gate_authority do local gate=edge_gate_authority[gate_index]
	local row=edge_by_id[gate[1]]
	row.gate_selector_id="shared_edge_gate_relief_q16_v1"
	row.gate_min_above_water=gate[2]
	row.gate_max_above_water=gate[3]
end

-- Every coordinate shared by two or more land-edge endpoints has one relief
-- value. A non-empty band is selected by the reviewed junction hash tuple;
-- an empty intersection uses the reviewed lower midpoint transition value.
-- Incident edge ids are numeric-sorted and are the complete incidence proof.
local function relief_junction(x,z,incident_edge_ids,band_min,band_max,midpoint)
	return {
		id="relief_junction:"..x..":"..z,
		position=point(x,z),
		incident_edge_ids=incident_edge_ids,
		gate_min_above_water=band_min,
		gate_max_above_water=band_max,
		empty_intersection=midpoint~=false,
		transition_midpoint_above_water=midpoint,
		hash_domain="relief_junction_v1",
		hash_feature_id="junction:"..x..":"..z,
		hash_coordinates="position_x_z",
		hash_candidate_index=0,
		hash_lane=2,
		transition_station_steps=96,
		policy_id="shared_relief_junction_gate_v1",
	}
end
source.relief_junctions={
	relief_junction(-1050,-2250,{"land_001","land_004"},24,56,false),
	relief_junction(950,-2250,{"land_004","land_007"},24,56,false),
	relief_junction(-2200,-1900,{"land_002","land_019","land_058"},56,96,false),
	relief_junction(-1400,-1900,{"land_002","land_020"},56,56,false),
	relief_junction(-400,-1900,{"land_005","land_021"},24,56,false),
	relief_junction(400,-1900,{"land_005","land_022"},24,56,false),
	relief_junction(1400,-1900,{"land_008","land_023"},24,96,false),
	relief_junction(2200,-1900,{"land_008","land_024","land_059"},24,56,false),
	relief_junction(-2200,-1100,{"land_003","land_019","land_031"},96,144,false),
	relief_junction(-1400,-1100,{"land_003","land_020","land_032","land_035"},96,56,76),
	relief_junction(-400,-1100,{"land_006","land_021","land_032"},24,56,false),
	relief_junction(400,-1100,{"land_006","land_022","land_033","land_036"},96,96,false),
	relief_junction(1400,-1100,{"land_009","land_023","land_033"},96,96,false),
	relief_junction(2200,-1100,{"land_009","land_024","land_034"},96,56,76),
	relief_junction(-1500,-250,{"land_043","land_044","land_055"},96,60,78),
	relief_junction(-750,-250,{"land_035","land_044","land_045"},96,24,60),
	relief_junction(0,-250,{"land_045","land_046","land_056"},56,24,40),
	relief_junction(750,-250,{"land_036","land_046","land_047"},96,96,false),
	relief_junction(1500,-250,{"land_047","land_048","land_057"},96,144,false),
	relief_junction(-1500,250,{"land_049","land_050","land_055"},96,60,78),
	relief_junction(-750,250,{"land_041","land_050","land_051"},96,40,68),
	relief_junction(0,250,{"land_051","land_052","land_056"},56,40,48),
	relief_junction(750,250,{"land_042","land_052","land_053"},96,144,false),
	relief_junction(1500,250,{"land_053","land_054","land_057"},96,144,false),
	relief_junction(-2200,1100,{"land_012","land_025","land_037"},96,96,false),
	relief_junction(-1400,1100,{"land_012","land_026","land_038","land_041"},96,96,false),
	relief_junction(-400,1100,{"land_015","land_027","land_038"},56,96,false),
	relief_junction(400,1100,{"land_015","land_028","land_039","land_042"},96,40,68),
	relief_junction(1400,1100,{"land_018","land_029","land_039"},96,40,68),
	relief_junction(2200,1100,{"land_018","land_030","land_040"},96,40,68),
	relief_junction(-2200,1900,{"land_011","land_025","land_060"},56,24,40),
	relief_junction(-1400,1900,{"land_011","land_026"},56,40,48),
	relief_junction(-400,1900,{"land_014","land_027"},56,96,false),
	relief_junction(400,1900,{"land_014","land_028"},56,40,48),
	relief_junction(1400,1900,{"land_017","land_029"},56,40,48),
	relief_junction(2200,1900,{"land_017","land_030","land_061"},56,24,40),
	relief_junction(1020,2250,{"land_013","land_016"},24,56,false),
	relief_junction(-970,2260,{"land_010","land_013"},24,24,false),
}

-- The literal perimeter polygons are the sole outer-footprint and shelf
-- authority. Face arcs below may consume only structured directed slices of
-- these polygons; they never carry a second handwritten coast polyline.
source.perimeters = {
	{id = "perimeter_elandor_mainland", kind = "planned_mainland_footprint",
		continent = "elandor", orientation = "counterclockwise",
		noise_domain = "coast_elandor_independent", max_displacement = 96,
		polygon = {
			point(-2500,-250),point(-2470,-650),point(-2490,-1050),point(-2560,-1500),point(-2600,-1900),point(-2580,-2200),point(-2600,-2500),point(-2470,-2760),point(-2250,-2920),point(-1800,-2960),point(-1350,-2920),point(-980,-2940),point(-520,-2910),point(0,-2960),point(460,-2930),point(900,-2920),point(1320,-2930),point(1800,-2950),point(2240,-2925),point(2470,-2740),point(2600,-2500),point(2580,-2200),point(2600,-1900),point(2550,-1500),point(2490,-1050),point(2530,-650),point(2500,-250),point(-2500,-250),
		}},
	{id = "perimeter_kragmar_mainland", kind = "planned_mainland_footprint",
		continent = "kragmar", orientation = "clockwise",
		noise_domain = "coast_kragmar_independent", max_displacement = 96,
		polygon = {
			point(-2500,250),point(-2540,620),point(-2480,1050),point(-2560,1480),point(-2600,1900),point(-2580,2200),point(-2600,2500),point(-2480,2750),point(-2260,2920),point(-1800,2960),point(-1440,2940),point(-1080,2930),point(-560,2940),point(0,2970),point(440,2920),point(820,2960),point(1280,2920),point(1800,2960),point(2250,2920),point(2480,2760),point(2600,2500),point(2580,2200),point(2600,1900),point(2540,1500),point(2500,1000),point(2550,600),point(2500,250),point(-2500,250),
		}},
	{id = "perimeter_holy_grounds", kind = "fixed_land_band",
		continent = "front", orientation = "counterclockwise",
		noise_domain = "fixed", max_displacement = 0,
		polygon = {point(-2500,-250),point(2500,-250),point(2500,250),point(-2500,250),point(-2500,-250)}},
}
local perimeter_by_id_source={}
for perimeter_index=1,#source.perimeters do
	perimeter_by_id_source[source.perimeters[perimeter_index].id]=source.perimeters[perimeter_index]
end

local function perimeter_attachment(id,edge_id,endpoint,perimeter_id,
		perimeter_segment_index,retained_run,canonical_before_span_id,
		canonical_after_span_id)
	return {id=id,edge_id=edge_id,edge_endpoint=endpoint,
		perimeter_id=perimeter_id,perimeter_segment_index=perimeter_segment_index,
		retained_run=retained_run,
		canonical_before_span_id=canonical_before_span_id,
		canonical_after_span_id=canonical_after_span_id,
		clip_policy_id="joint_perimeter_station_endpoint_before_final_raster_v1",
		geometry_rule="symbolic_edge_to_perimeter_joint_station_no_connector_or_snap",
		selection_station_rule="first_or_last_retained_candidate_station_E_stage2_only",
		joint_station_rule="final_displaced_declared_perimeter_segment_station_A_min_chebyshev_to_E_lower_canonical_index_tie_max_one",
		compiled_endpoint_rule="discard_outside_terminal_controls_A_is_shared_zero_displacement_terminal_control_before_sole_final_edge_raster_provisional_run_not_exported"}
end
source.perimeter_attachments={
	perimeter_attachment("perimeter_attachment:elandor:land_031","land_031","from","perimeter_elandor_mainland",3,"suffix","perimeter_span:elandor:stormvault","perimeter_span:elandor:frostbarrow"),
	perimeter_attachment("perimeter_attachment:elandor:land_001","land_001","from","perimeter_elandor_mainland",7,"suffix","perimeter_span:elandor:copperfell","perimeter_span:elandor:hearthpine"),
	perimeter_attachment("perimeter_attachment:elandor:land_007","land_007","to","perimeter_elandor_mainland",20,"prefix","perimeter_span:elandor:silverleaf","perimeter_span:elandor:starbough"),
	perimeter_attachment("perimeter_attachment:elandor:land_034","land_034","to","perimeter_elandor_mainland",24,"prefix","perimeter_span:elandor:moonfall","perimeter_span:elandor:glassroot"),
	perimeter_attachment("perimeter_attachment:kragmar:land_037","land_037","from","perimeter_kragmar_mainland",3,"suffix","perimeter_span:kragmar:blackwind","perimeter_span:kragmar:ossuary"),
	perimeter_attachment("perimeter_attachment:kragmar:land_010","land_010","from","perimeter_kragmar_mainland",7,"suffix","perimeter_span:kragmar:mournfen","perimeter_span:kragmar:stillgrave"),
	perimeter_attachment("perimeter_attachment:kragmar:land_016","land_016","to","perimeter_kragmar_mainland",20,"prefix","perimeter_span:kragmar:kapok","perimeter_span:kragmar:raincall"),
	perimeter_attachment("perimeter_attachment:kragmar:land_040","land_040","to","perimeter_kragmar_mainland",24,"prefix","perimeter_span:kragmar:totemwater","perimeter_span:kragmar:thunderroot"),
}

local function vertex_boundary(perimeter_id,index)
	return {kind="perimeter_vertex",perimeter_id=perimeter_id,index=index}
end
local function attachment_boundary(id)
	return {kind="perimeter_attachment",attachment_id=id}
end
local function perimeter_span(id,zone_id,perimeter_id,first_segment,last_segment,
		face_direction,start_boundary,end_boundary)
	return {id=id,zone_id=zone_id,perimeter_id=perimeter_id,
		first_segment=first_segment,last_segment=last_segment,
		face_direction=face_direction,start_boundary=start_boundary,
		end_boundary=end_boundary,
		geometry_authority="directed_canonical_perimeter_segment_span_v2",
		displacement_source_ref=perimeter_id,
		tie_rule="perimeter_station_then_lower_zone_numeric_id"}
end
local EA="perimeter_attachment:elandor:"
local KA="perimeter_attachment:kragmar:"
local EP="perimeter_elandor_mainland"
local KP="perimeter_kragmar_mainland"
source.perimeter_spans={
	perimeter_span("perimeter_span:elandor:stormvault","elandor_stormvault_heights",EP,1,3,"forward",vertex_boundary(EP,1),attachment_boundary(EA.."land_031")),
	perimeter_span("perimeter_span:elandor:frostbarrow","elandor_frostbarrow_shelf",EP,3,4,"forward",attachment_boundary(EA.."land_031"),vertex_boundary(EP,5)),
	perimeter_span("perimeter_span:elandor:copperfell","elandor_copperfell_foothills",EP,5,7,"forward",vertex_boundary(EP,5),attachment_boundary(EA.."land_001")),
	perimeter_span("perimeter_span:elandor:hearthpine","elandor_hearthpine_vale",EP,7,11,"forward",attachment_boundary(EA.."land_001"),vertex_boundary(EP,12)),
	perimeter_span("perimeter_span:elandor:dawnmere","elandor_dawnmere_fields",EP,12,15,"forward",vertex_boundary(EP,12),vertex_boundary(EP,16)),
	perimeter_span("perimeter_span:elandor:silverleaf","elandor_silverleaf_glades",EP,16,20,"forward",vertex_boundary(EP,16),attachment_boundary(EA.."land_007")),
	perimeter_span("perimeter_span:elandor:starbough","elandor_starbough_vale",EP,20,22,"forward",attachment_boundary(EA.."land_007"),vertex_boundary(EP,23)),
	perimeter_span("perimeter_span:elandor:moonfall","elandor_moonfall_wood",EP,23,24,"forward",vertex_boundary(EP,23),attachment_boundary(EA.."land_034")),
	perimeter_span("perimeter_span:elandor:glassroot","elandor_glassroot_wilds",EP,24,26,"forward",attachment_boundary(EA.."land_034"),vertex_boundary(EP,27)),
	perimeter_span("perimeter_span:kragmar:blackwind","kragmar_blackwind_rise",KP,1,3,"reverse",vertex_boundary(KP,1),attachment_boundary(KA.."land_037")),
	perimeter_span("perimeter_span:kragmar:ossuary","kragmar_ossuary_reach",KP,3,4,"reverse",attachment_boundary(KA.."land_037"),vertex_boundary(KP,5)),
	perimeter_span("perimeter_span:kragmar:mournfen","kragmar_mournfen",KP,5,7,"reverse",vertex_boundary(KP,5),attachment_boundary(KA.."land_010")),
	perimeter_span("perimeter_span:kragmar:stillgrave","kragmar_stillgrave_hollow",KP,7,11,"reverse",attachment_boundary(KA.."land_010"),vertex_boundary(KP,12)),
	perimeter_span("perimeter_span:kragmar:sunscar","kragmar_sunscar_flats",KP,12,15,"reverse",vertex_boundary(KP,12),vertex_boundary(KP,16)),
	perimeter_span("perimeter_span:kragmar:kapok","kragmar_kapok_cradle",KP,16,20,"reverse",vertex_boundary(KP,16),attachment_boundary(KA.."land_016")),
	perimeter_span("perimeter_span:kragmar:raincall","kragmar_raincall_basin",KP,20,22,"reverse",attachment_boundary(KA.."land_016"),vertex_boundary(KP,23)),
	perimeter_span("perimeter_span:kragmar:totemwater","kragmar_totemwater_reach",KP,23,24,"reverse",vertex_boundary(KP,23),attachment_boundary(KA.."land_040")),
	perimeter_span("perimeter_span:kragmar:thunderroot","kragmar_thunderroot_wilds",KP,24,26,"reverse",attachment_boundary(KA.."land_040"),vertex_boundary(KP,27)),
}
local perimeter_span_by_id_source={}
for span_index=1,#source.perimeter_spans do local span=source.perimeter_spans[span_index]
	perimeter_span_by_id_source[span.id]=span
end

-- Face arcs are ordered authority-component graphs. Literal bay/Holy/island
-- sub-polylines remain source geometry; outer coast components reference the
-- canonical perimeter span directly. A symbolic attachment never materializes
-- a connector or a pre-Stage-2 intersection coordinate.
local function boundary_id(boundary)
	if boundary.kind=="perimeter_attachment" then return boundary.attachment_id end
	local perimeter=perimeter_by_id_source[boundary.perimeter_id]
	return junction_id(perimeter.polygon[boundary.index])
end
local function perimeter_component(span_id)
	local span=perimeter_span_by_id_source[span_id]
	local first,last=span.start_boundary,span.end_boundary
	if span.face_direction=="reverse" then first,last=last,first end
	return {kind="perimeter_span",ref_id=span_id,direction=span.face_direction,
		from_boundary_id=boundary_id(first),to_boundary_id=boundary_id(last)}
end
local function literal_component(role,source_ref,control)
	return {kind="literal_arc",boundary_role=role,source_ref=source_ref,
		control=control,from_boundary_id=junction_id(control[1]),
		to_boundary_id=junction_id(control[#control])}
end
local function face_arc(id,zone_id,kind,refs,components)
	return {id=id,zone_id=zone_id,kind=kind,geometry_ref=id,
		source_refs=refs,authority_components=components,
		geometry_authority="ordered_face_arc_authority_components_v2",
		from_boundary_id=components[1].from_boundary_id,
		to_boundary_id=components[#components].to_boundary_id,
		shore_owner_zone_id=zone_id,shore_tie_rule="lower_zone_numeric_id",
		projection_rule="zone_inside_coast_outside"}
end
local function pc(id) return perimeter_component(id) end
local function lc(role,ref,control) return literal_component(role,ref,control) end
source.face_arcs = {
	face_arc("face_arc:hearthpine:outer","elandor_hearthpine_vale","coast_bay_shore",{"perimeter_elandor_mainland","bay_elandor_west"},{pc("perimeter_span:elandor:hearthpine"),lc("bay_shore","bay_elandor_west",{point(-980,-2940),point(-900,-2600),point(-1040,-2300),point(-1050,-2250)})}),
	face_arc("face_arc:copperfell:bay","elandor_copperfell_foothills","bay_shore",{"bay_elandor_west"},{lc("bay_shore","bay_elandor_west",{point(-1050,-2250),point(-1040,-2300),point(-980,-2000),point(-1400,-1900)})}),
	face_arc("face_arc:copperfell:coast","elandor_copperfell_foothills","coast_shore",{"perimeter_elandor_mainland"},{pc("perimeter_span:elandor:copperfell")}),
	face_arc("face_arc:frostbarrow:coast","elandor_frostbarrow_shelf","coast_shore",{"perimeter_elandor_mainland"},{pc("perimeter_span:elandor:frostbarrow")}),
	face_arc("face_arc:stormvault:coast","elandor_stormvault_heights","coast_shore",{"perimeter_elandor_mainland"},{pc("perimeter_span:elandor:stormvault")}),
	face_arc("face_arc:dawnmere:outer","elandor_dawnmere_fields","coast_bay_shore",{"bay_elandor_west","perimeter_elandor_mainland","bay_elandor_east"},{lc("bay_shore","bay_elandor_west",{point(-1050,-2250),point(-1040,-2300),point(-900,-2600),point(-980,-2940)}),pc("perimeter_span:elandor:dawnmere"),lc("bay_shore","bay_elandor_east",{point(900,-2920),point(1080,-2580),point(920,-2280),point(950,-2250)})}),
	face_arc("face_arc:goldmead:east_bay","elandor_goldmead_vale","bay_shore",{"bay_elandor_east"},{lc("bay_shore","bay_elandor_east",{point(950,-2250),point(1020,-1990),point(400,-1900)})}),
	face_arc("face_arc:goldmead:west_bay","elandor_goldmead_vale","bay_shore",{"bay_elandor_west"},{lc("bay_shore","bay_elandor_west",{point(-400,-1900),point(-980,-2000),point(-1050,-2250)})}),
	face_arc("face_arc:whitebridge:bay_head","elandor_whitebridge_shire","bay_shore",{"bay_elandor_west"},{lc("bay_shore","bay_elandor_west",{point(-1400,-1900),point(-980,-2000),point(-400,-1900)})}),
	face_arc("face_arc:silverleaf:outer","elandor_silverleaf_glades","coast_bay_shore",{"bay_elandor_east","perimeter_elandor_mainland"},{lc("bay_shore","bay_elandor_east",{point(950,-2250),point(920,-2280),point(1080,-2580),point(900,-2920)}),pc("perimeter_span:elandor:silverleaf")}),
	face_arc("face_arc:starbough:coast","elandor_starbough_vale","coast_shore",{"perimeter_elandor_mainland"},{pc("perimeter_span:elandor:starbough")}),
	face_arc("face_arc:starbough:bay","elandor_starbough_vale","bay_shore",{"bay_elandor_east"},{lc("bay_shore","bay_elandor_east",{point(1400,-1900),point(1020,-1990),point(920,-2280),point(950,-2250)})}),
	face_arc("face_arc:lorindor:bay_head","elandor_lorindor","bay_shore",{"bay_elandor_east"},{lc("bay_shore","bay_elandor_east",{point(400,-1900),point(1020,-1990),point(1400,-1900)})}),
	face_arc("face_arc:moonfall:coast","elandor_moonfall_wood","coast_shore",{"perimeter_elandor_mainland"},{pc("perimeter_span:elandor:moonfall")}),
	face_arc("face_arc:glassroot:coast","elandor_glassroot_wilds","coast_shore",{"perimeter_elandor_mainland"},{pc("perimeter_span:elandor:glassroot")}),
	face_arc("face_arc:stillgrave:outer","kragmar_stillgrave_hollow","coast_bay_shore",{"perimeter_kragmar_mainland","bay_kragmar_west"},{lc("bay_shore","bay_kragmar_west",{point(-970,2260),point(-940,2300),point(-1200,2620),point(-1080,2930)}),pc("perimeter_span:kragmar:stillgrave")}),
	face_arc("face_arc:mournfen:bay","kragmar_mournfen","bay_shore",{"bay_kragmar_west"},{lc("bay_shore","bay_kragmar_west",{point(-1400,1900),point(-1060,2010),point(-940,2300),point(-970,2260)})}),
	face_arc("face_arc:mournfen:coast","kragmar_mournfen","coast_shore",{"perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:mournfen")}),
	face_arc("face_arc:ossuary:coast","kragmar_ossuary_reach","coast_shore",{"perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:ossuary")}),
	face_arc("face_arc:blackwind:coast","kragmar_blackwind_rise","coast_shore",{"perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:blackwind")}),
	face_arc("face_arc:sunscar:outer","kragmar_sunscar_flats","coast_bay_shore",{"bay_kragmar_east","perimeter_kragmar_mainland","bay_kragmar_west"},{lc("bay_shore","bay_kragmar_east",{point(1020,2250),point(1050,2320),point(700,2630),point(820,2960)}),pc("perimeter_span:kragmar:sunscar"),lc("bay_shore","bay_kragmar_west",{point(-1080,2930),point(-1200,2620),point(-940,2300),point(-970,2260)})}),
	face_arc("face_arc:redtusk:west_bay","kragmar_redtusk_savanna","bay_shore",{"bay_kragmar_west"},{lc("bay_shore","bay_kragmar_west",{point(-970,2260),point(-1060,2010),point(-400,1900)})}),
	face_arc("face_arc:redtusk:east_bay","kragmar_redtusk_savanna","bay_shore",{"bay_kragmar_east"},{lc("bay_shore","bay_kragmar_east",{point(400,1900),point(900,1980),point(1020,2250)})}),
	face_arc("face_arc:speargrass:bay_head","kragmar_speargrass_reach","bay_shore",{"bay_kragmar_west"},{lc("bay_shore","bay_kragmar_west",{point(-400,1900),point(-1060,2010),point(-1400,1900)})}),
	face_arc("face_arc:kapok:outer","kragmar_kapok_cradle","coast_bay_shore",{"bay_kragmar_east","perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:kapok"),lc("bay_shore","bay_kragmar_east",{point(820,2960),point(700,2630),point(1050,2320),point(1020,2250)})}),
	face_arc("face_arc:raincall:bay","kragmar_raincall_basin","bay_shore",{"bay_kragmar_east"},{lc("bay_shore","bay_kragmar_east",{point(1020,2250),point(1050,2320),point(900,1980),point(1400,1900)})}),
	face_arc("face_arc:raincall:coast","kragmar_raincall_basin","coast_shore",{"perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:raincall")}),
	face_arc("face_arc:whispering:bay_head","kragmar_whispering_reedlands","bay_shore",{"bay_kragmar_east"},{lc("bay_shore","bay_kragmar_east",{point(1400,1900),point(900,1980),point(400,1900)})}),
	face_arc("face_arc:totemwater:coast","kragmar_totemwater_reach","coast_shore",{"perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:totemwater")}),
	face_arc("face_arc:thunderroot:coast","kragmar_thunderroot_wilds","coast_shore",{"perimeter_kragmar_mainland"},{pc("perimeter_span:kragmar:thunderroot")}),
	face_arc("face_arc:gravesalt:holy_west","front_gravesalt_escarpment","fixed_holy_arc",{"perimeter_holy_grounds"},{lc("fixed_holy","perimeter_holy_grounds",{point(-2500,250),point(-2500,-250)})}),
	face_arc("face_arc:skyglass:holy_east","front_skyglass_canopy","fixed_holy_arc",{"perimeter_holy_grounds"},{lc("fixed_holy","perimeter_holy_grounds",{point(2500,-250),point(2500,250)})}),
	face_arc("face_arc:wyrmglass:island","front_wyrmglass_crown","island_perimeter_arc",{"island_wyrmglass"},{lc("island_coast","island_wyrmglass",{point(-3430,-80),point(-3360,-260),point(-3160,-330),point(-2940,-250),point(-2860,-80),point(-2890,150),point(-3060,320),point(-3290,280),point(-3440,100),point(-3430,-80)})}),
	face_arc("face_arc:stormscale:island","front_stormscale_summit","island_perimeter_arc",{"island_stormscale"},{lc("island_coast","island_stormscale",{point(2870,-130),point(2970,-310),point(3200,-340),point(3400,-220),point(3440,20),point(3370,260),point(3150,330),point(2940,230),point(2860,60),point(2870,-130)})}),
}

-- Face-arc controls are the sole zone-face and dry-land/exterior partition
-- authority. Bay centreline/half-width capsules separately own planned-water
-- masks; bay-shore arcs express only the resulting zone-face boundary.

local edge_attachment_id = {
	land_001=EA.."land_001",land_007=EA.."land_007",
	land_010=KA.."land_010",land_016=KA.."land_016",
	land_031=EA.."land_031",land_034=EA.."land_034",
	land_037=KA.."land_037",land_040=KA.."land_040",
}
local function er(id,direction)
	return {kind="shared_edge",ref_id=id,direction=direction,
		clip_attachment_id=edge_attachment_id[id] or false}
end
local function ar(id) return {kind="arc",ref_id=id,direction="forward"} end
local function face(zone_id,cycle) return {id="zone_face:"..zone_id,zone_id=zone_id,
	orientation="counterclockwise",tie_rule="lower_zone_numeric_id",cycle=cycle} end
source.zone_faces = {
	face("elandor_hearthpine_vale",{er("land_001","reverse"),ar("face_arc:hearthpine:outer")}),
	face("elandor_copperfell_foothills",{er("land_001","forward"),ar("face_arc:copperfell:bay"),er("land_002","reverse"),er("land_058","reverse"),ar("face_arc:copperfell:coast")}),
	face("elandor_dur_brannoc",{er("land_002","forward"),er("land_020","forward"),er("land_003","reverse"),er("land_019","reverse")}),
	face("elandor_frostbarrow_shelf",{er("land_019","forward"),er("land_031","reverse"),ar("face_arc:frostbarrow:coast"),er("land_058","forward")}),
	face("elandor_stormvault_heights",{er("land_031","forward"),er("land_003","forward"),er("land_035","forward"),er("land_044","reverse"),er("land_043","reverse"),ar("face_arc:stormvault:coast")}),
	face("elandor_dawnmere_fields",{er("land_004","reverse"),ar("face_arc:dawnmere:outer")}),
	face("elandor_goldmead_vale",{er("land_004","forward"),ar("face_arc:goldmead:east_bay"),er("land_005","reverse"),ar("face_arc:goldmead:west_bay")}),
	face("elandor_highcourt",{er("land_005","forward"),er("land_022","forward"),er("land_006","reverse"),er("land_021","reverse")}),
	face("elandor_whitebridge_shire",{er("land_021","forward"),er("land_032","reverse"),er("land_020","reverse"),ar("face_arc:whitebridge:bay_head")}),
	face("elandor_ashenward_march",{er("land_032","forward"),er("land_006","forward"),er("land_036","forward"),er("land_046","reverse"),er("land_045","reverse"),er("land_035","reverse")}),
	face("elandor_silverleaf_glades",{er("land_007","reverse"),ar("face_arc:silverleaf:outer")}),
	face("elandor_starbough_vale",{er("land_007","forward"),ar("face_arc:starbough:coast"),er("land_059","reverse"),er("land_008","reverse"),ar("face_arc:starbough:bay")}),
	face("elandor_lethariel",{er("land_008","forward"),er("land_024","forward"),er("land_009","reverse"),er("land_023","reverse")}),
	face("elandor_lorindor",{er("land_023","forward"),er("land_033","reverse"),er("land_022","reverse"),ar("face_arc:lorindor:bay_head")}),
	face("elandor_moonfall_wood",{er("land_034","reverse"),er("land_024","reverse"),er("land_059","forward"),ar("face_arc:moonfall:coast")}),
	face("elandor_glassroot_wilds",{er("land_033","forward"),er("land_009","forward"),er("land_034","forward"),ar("face_arc:glassroot:coast"),er("land_048","reverse"),er("land_047","reverse"),er("land_036","reverse")}),
	face("kragmar_stillgrave_hollow",{er("land_010","forward"),ar("face_arc:stillgrave:outer")}),
	face("kragmar_mournfen",{er("land_011","forward"),ar("face_arc:mournfen:bay"),er("land_010","reverse"),ar("face_arc:mournfen:coast"),er("land_060","forward")}),
	face("kragmar_nhal_veyr",{er("land_012","forward"),er("land_026","forward"),er("land_011","reverse"),er("land_025","reverse")}),
	face("kragmar_ossuary_reach",{er("land_037","forward"),er("land_025","forward"),er("land_060","reverse"),ar("face_arc:ossuary:coast")}),
	face("kragmar_blackwind_rise",{er("land_049","forward"),er("land_050","forward"),er("land_041","reverse"),er("land_012","reverse"),er("land_037","reverse"),ar("face_arc:blackwind:coast")}),
	face("kragmar_sunscar_flats",{er("land_013","forward"),ar("face_arc:sunscar:outer")}),
	face("kragmar_redtusk_savanna",{er("land_014","forward"),ar("face_arc:redtusk:east_bay"),er("land_013","reverse"),ar("face_arc:redtusk:west_bay")}),
	face("kragmar_gor_drazhak",{er("land_015","forward"),er("land_028","forward"),er("land_014","reverse"),er("land_027","reverse")}),
	face("kragmar_speargrass_reach",{er("land_038","forward"),er("land_027","forward"),ar("face_arc:speargrass:bay_head"),er("land_026","reverse")}),
	face("kragmar_bannerbreak_mesa",{er("land_041","forward"),er("land_051","forward"),er("land_052","forward"),er("land_042","reverse"),er("land_015","reverse"),er("land_038","reverse")}),
	face("kragmar_kapok_cradle",{er("land_016","forward"),ar("face_arc:kapok:outer")}),
	face("kragmar_raincall_basin",{er("land_017","forward"),er("land_061","forward"),ar("face_arc:raincall:coast"),er("land_016","reverse"),ar("face_arc:raincall:bay")}),
	face("kragmar_kezamba",{er("land_018","forward"),er("land_030","forward"),er("land_017","reverse"),er("land_029","reverse")}),
	face("kragmar_whispering_reedlands",{er("land_039","forward"),er("land_029","forward"),ar("face_arc:whispering:bay_head"),er("land_028","reverse")}),
	face("kragmar_totemwater_reach",{er("land_040","forward"),ar("face_arc:totemwater:coast"),er("land_061","reverse"),er("land_030","reverse")}),
	face("kragmar_thunderroot_wilds",{er("land_042","forward"),er("land_053","forward"),er("land_054","forward"),ar("face_arc:thunderroot:coast"),er("land_040","reverse"),er("land_018","reverse"),er("land_039","reverse")}),
	face("front_wyrmglass_crown",{ar("face_arc:wyrmglass:island")}),
	face("front_gravesalt_escarpment",{er("land_043","forward"),er("land_055","forward"),er("land_049","reverse"),ar("face_arc:gravesalt:holy_west")}),
	face("front_broken_causeway",{er("land_044","forward"),er("land_045","forward"),er("land_056","forward"),er("land_051","reverse"),er("land_050","reverse"),er("land_055","reverse")}),
	face("front_shattered_line",{er("land_046","forward"),er("land_047","forward"),er("land_057","forward"),er("land_053","reverse"),er("land_052","reverse"),er("land_056","reverse")}),
	face("front_skyglass_canopy",{er("land_048","forward"),ar("face_arc:skyglass:holy_east"),er("land_054","reverse"),er("land_057","reverse")}),
	face("front_stormscale_summit",{ar("face_arc:stormscale:island")}),
}

local function station(id, zone_id, kind, x, z, gate_ref)
	return {id=id,zone_id=zone_id,kind=kind,position=point(x,z),
		gate_ref=gate_ref or false}
end

-- Stable route stations are the complete route endpoints. Ordinary zone hubs
-- are conservative implementation data near the authored zone cores. Start
-- and capital routes terminate at their exact external gate stations instead
-- of allowing the later compiler to choose an approach from terrain.
source.route_stations = {
	station("station:elandor_hearthpine_vale:hub","elandor_hearthpine_vale","hub",-1800,-2550),
	station("station:elandor_copperfell_foothills:hub","elandor_copperfell_foothills","hub",-1800,-2050),
	station("station:elandor_dur_brannoc:hub","elandor_dur_brannoc","hub",-1800,-1500),
	station("station:elandor_frostbarrow_shelf:hub","elandor_frostbarrow_shelf","hub",-2400,-1500),
	station("station:elandor_stormvault_heights:hub","elandor_stormvault_heights","hub",-1800,-700),
	station("station:elandor_dawnmere_fields:hub","elandor_dawnmere_fields","hub",0,-2550),
	station("station:elandor_goldmead_vale:hub","elandor_goldmead_vale","hub",0,-2050),
	station("station:elandor_highcourt:hub","elandor_highcourt","hub",0,-1500),
	station("station:elandor_whitebridge_shire:hub","elandor_whitebridge_shire","hub",-900,-1500),
	station("station:elandor_ashenward_march:hub","elandor_ashenward_march","hub",0,-700),
	station("station:elandor_silverleaf_glades:hub","elandor_silverleaf_glades","hub",1800,-2550),
	station("station:elandor_starbough_vale:hub","elandor_starbough_vale","hub",1800,-2050),
	station("station:elandor_lethariel:hub","elandor_lethariel","hub",1800,-1500),
	station("station:elandor_lorindor:hub","elandor_lorindor","hub",900,-1500),
	station("station:elandor_moonfall_wood:hub","elandor_moonfall_wood","hub",2400,-1500),
	station("station:elandor_glassroot_wilds:hub","elandor_glassroot_wilds","hub",1800,-700),
	station("station:kragmar_stillgrave_hollow:hub","kragmar_stillgrave_hollow","hub",-1800,2550),
	station("station:kragmar_mournfen:hub","kragmar_mournfen","hub",-1800,2050),
	station("station:kragmar_nhal_veyr:hub","kragmar_nhal_veyr","hub",-1800,1500),
	station("station:kragmar_ossuary_reach:hub","kragmar_ossuary_reach","hub",-2400,1500),
	station("station:kragmar_blackwind_rise:hub","kragmar_blackwind_rise","hub",-1800,700),
	station("station:kragmar_sunscar_flats:hub","kragmar_sunscar_flats","hub",0,2550),
	station("station:kragmar_redtusk_savanna:hub","kragmar_redtusk_savanna","hub",0,2050),
	station("station:kragmar_gor_drazhak:hub","kragmar_gor_drazhak","hub",0,1500),
	station("station:kragmar_speargrass_reach:hub","kragmar_speargrass_reach","hub",-900,1500),
	station("station:kragmar_bannerbreak_mesa:hub","kragmar_bannerbreak_mesa","hub",0,700),
	station("station:kragmar_kapok_cradle:hub","kragmar_kapok_cradle","hub",1800,2550),
	station("station:kragmar_raincall_basin:hub","kragmar_raincall_basin","hub",1800,2050),
	station("station:kragmar_kezamba:hub","kragmar_kezamba","hub",1800,1500),
	station("station:kragmar_whispering_reedlands:hub","kragmar_whispering_reedlands","hub",900,1500),
	station("station:kragmar_totemwater_reach:hub","kragmar_totemwater_reach","hub",2400,1500),
	station("station:kragmar_thunderroot_wilds:hub","kragmar_thunderroot_wilds","hub",1800,700),
	station("station:front_wyrmglass_crown:hub","front_wyrmglass_crown","hub",-3150,0),
	station("station:front_gravesalt_escarpment:hub","front_gravesalt_escarpment","hub",-2000,0),
	station("station:front_broken_causeway:hub","front_broken_causeway","hub",-750,0),
	station("station:front_shattered_line:hub","front_shattered_line","hub",750,0),
	station("station:front_skyglass_canopy:hub","front_skyglass_canopy","hub",2000,0),
	station("station:front_stormscale_summit:hub","front_stormscale_summit","hub",3150,0),
	station("station:elandor_hearthpine_vale:start_north","elandor_hearthpine_vale","start_gate",-1800,-2486,"start:north"),
	station("station:elandor_dawnmere_fields:start_north","elandor_dawnmere_fields","start_gate",0,-2486,"start:north"),
	station("station:elandor_silverleaf_glades:start_north","elandor_silverleaf_glades","start_gate",1800,-2486,"start:north"),
	station("station:kragmar_stillgrave_hollow:start_south","kragmar_stillgrave_hollow","start_gate",-1800,2486,"start:south"),
	station("station:kragmar_sunscar_flats:start_south","kragmar_sunscar_flats","start_gate",0,2486,"start:south"),
	station("station:kragmar_kapok_cradle:start_south","kragmar_kapok_cradle","start_gate",1800,2486,"start:south"),
}

local capital_centers={{"elandor_dur_brannoc",-1800,-1500},{"elandor_highcourt",0,-1500},{"elandor_lethariel",1800,-1500},{"kragmar_nhal_veyr",-1800,1500},{"kragmar_gor_drazhak",0,1500},{"kragmar_kezamba",1800,1500}}
for capital_index=1,#capital_centers do local row=capital_centers[capital_index]
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_north",row[1],"capital_gate",row[2],row[3]+256,"capital:north")
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_south",row[1],"capital_gate",row[2],row[3]-256,"capital:south")
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_east",row[1],"capital_gate",row[2]+256,row[3],"capital:east")
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_west",row[1],"capital_gate",row[2]-256,row[3],"capital:west")
end

local endpoint_gate_refs = {
	elandor_hearthpine_vale="start:north",elandor_dawnmere_fields="start:north",
	elandor_silverleaf_glades="start:north",kragmar_stillgrave_hollow="start:south",
	kragmar_sunscar_flats="start:south",kragmar_kapok_cradle="start:south",
}
local capital_gate_refs={
	["elandor_dur_brannoc\0elandor_copperfell_foothills"]="capital:south",["elandor_dur_brannoc\0elandor_stormvault_heights"]="capital:north",["elandor_dur_brannoc\0elandor_frostbarrow_shelf"]="capital:west",["elandor_dur_brannoc\0elandor_whitebridge_shire"]="capital:east",
	["elandor_highcourt\0elandor_goldmead_vale"]="capital:south",["elandor_highcourt\0elandor_ashenward_march"]="capital:north",["elandor_highcourt\0elandor_whitebridge_shire"]="capital:west",["elandor_highcourt\0elandor_lorindor"]="capital:east",
	["elandor_lethariel\0elandor_starbough_vale"]="capital:south",["elandor_lethariel\0elandor_glassroot_wilds"]="capital:north",["elandor_lethariel\0elandor_lorindor"]="capital:west",["elandor_lethariel\0elandor_moonfall_wood"]="capital:east",
	["kragmar_nhal_veyr\0kragmar_mournfen"]="capital:north",["kragmar_nhal_veyr\0kragmar_blackwind_rise"]="capital:south",["kragmar_nhal_veyr\0kragmar_ossuary_reach"]="capital:west",["kragmar_nhal_veyr\0kragmar_speargrass_reach"]="capital:east",
	["kragmar_gor_drazhak\0kragmar_redtusk_savanna"]="capital:north",["kragmar_gor_drazhak\0kragmar_bannerbreak_mesa"]="capital:south",["kragmar_gor_drazhak\0kragmar_speargrass_reach"]="capital:west",["kragmar_gor_drazhak\0kragmar_whispering_reedlands"]="capital:east",
	["kragmar_kezamba\0kragmar_raincall_basin"]="capital:north",["kragmar_kezamba\0kragmar_thunderroot_wilds"]="capital:south",["kragmar_kezamba\0kragmar_whispering_reedlands"]="capital:west",["kragmar_kezamba\0kragmar_totemwater_reach"]="capital:east",
}

local function sign_direction(dx, dz)
	local east_west = dx > 0 and "east" or (dx < 0 and "west" or "")
	local north_south = dz > 0 and "north" or (dz < 0 and "south" or "")
	if east_west ~= "" and north_south ~= "" then
		return north_south .. "_" .. east_west
	end
	return east_west ~= "" and east_west or north_south
end

-- Authored route crossings are independent source geometry. Each crossing is
-- joined to its two explicit stable stations below, producing the complete
-- ordered control path consumed by one-node station rasterization. No later
-- compiler chooses endpoints, follows a boundary, or invents an approach.
local route_geometry = {
	{crossing=point(-1975,-2175),approach_dx=96,approach_dz=-96},{crossing=point(-1800,-1900),approach_dx=0,approach_dz=-96},{crossing=point(-1800,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-175,-2145),approach_dx=96,approach_dz=-96},{crossing=point(0,-1900),approach_dx=0,approach_dz=-96},{crossing=point(0,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(1975,-2190),approach_dx=-96,approach_dz=-96},{crossing=point(1800,-1900),approach_dx=0,approach_dz=-96},{crossing=point(1800,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-1980,2175),approach_dx=-96,approach_dz=-96},{crossing=point(-1800,1900),approach_dx=0,approach_dz=-96},{crossing=point(-1800,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-180,2155),approach_dx=-96,approach_dz=-96},{crossing=point(0,1900),approach_dx=0,approach_dz=-96},{crossing=point(0,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(1980,2175),approach_dx=96,approach_dz=-96},{crossing=point(1800,1900),approach_dx=0,approach_dz=-96},{crossing=point(1800,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-2200,-1500),approach_dx=96,approach_dz=0},{crossing=point(-1400,-1500),approach_dx=96,approach_dz=0},{crossing=point(-400,-1500),approach_dx=96,approach_dz=0},
	{crossing=point(400,-1500),approach_dx=96,approach_dz=0},{crossing=point(1400,-1500),approach_dx=96,approach_dz=0},{crossing=point(2200,-1500),approach_dx=96,approach_dz=0},
	{crossing=point(-2200,1500),approach_dx=96,approach_dz=0},{crossing=point(-1400,1500),approach_dx=96,approach_dz=0},{crossing=point(-400,1500),approach_dx=96,approach_dz=0},
	{crossing=point(400,1500),approach_dx=96,approach_dz=0},{crossing=point(1400,1500),approach_dx=96,approach_dz=0},{crossing=point(2200,1500),approach_dx=96,approach_dz=0},
	{crossing=point(-2400,-1100),approach_dx=0,approach_dz=-96},{crossing=point(-900,-1100),approach_dx=0,approach_dz=-96},{crossing=point(900,-1100),approach_dx=0,approach_dz=-96},{crossing=point(2400,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-1150,-1000),approach_dx=96,approach_dz=-96},{crossing=point(650,-1000),approach_dx=96,approach_dz=-96},
	{crossing=point(-2400,1100),approach_dx=0,approach_dz=-96},{crossing=point(-900,1100),approach_dx=0,approach_dz=-96},{crossing=point(900,1100),approach_dx=0,approach_dz=-96},{crossing=point(2400,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-1150,1000),approach_dx=-96,approach_dz=-96},{crossing=point(650,1000),approach_dx=-96,approach_dz=-96},
	{crossing=point(-2000,-250),approach_dx=0,approach_dz=-96},{crossing=point(-1125,-250),approach_dx=0,approach_dz=-96},{crossing=point(-375,-250),approach_dx=0,approach_dz=-96},{crossing=point(375,-250),approach_dx=0,approach_dz=-96},{crossing=point(1125,-250),approach_dx=0,approach_dz=-96},{crossing=point(2000,-250),approach_dx=0,approach_dz=-96},
	{crossing=point(-2000,250),approach_dx=0,approach_dz=-96},{crossing=point(-1125,250),approach_dx=0,approach_dz=-96},{crossing=point(-375,250),approach_dx=0,approach_dz=-96},{crossing=point(375,250),approach_dx=0,approach_dz=-96},{crossing=point(1125,250),approach_dx=0,approach_dz=-96},{crossing=point(2000,250),approach_dx=0,approach_dz=-96},
	{crossing=point(-1500,-125),approach_dx=96,approach_dz=0},{crossing=point(0,-125),approach_dx=96,approach_dz=0},{crossing=point(1500,-125),approach_dx=96,approach_dz=0},
}

local route_class_order={}
for route_index=1,30 do route_class_order[route_index]="primary" end
for route_index=31,54 do route_class_order[route_index]="secondary" end
for route_index=55,57 do route_class_order[route_index]="trail" end

local station_by_id={}
for station_index=1,#source.route_stations do
	station_by_id[source.route_stations[station_index].id]=source.route_stations[station_index]
end

local function endpoint_station_id(zone_id,gate_ref)
	if gate_ref then
		return "station:"..zone_id..":"..gate_ref:gsub(":","_")
	end
	return "station:"..zone_id..":hub"
end

source.routes = {}
source.route_interfaces = {}
for route_index = 1, 57 do
	local boundary = source.land_edges[route_index]
	local geometry=route_geometry[route_index]
	local crossing=geometry.crossing
	local route_id = ("route_%03d"):format(route_index)
	local interface_a = route_id .. ":endpoint_a"
	local interface_b = route_id .. ":endpoint_b"
	local crossing_id = route_id .. ":boundary_crossing"
	local gate_ref_a=endpoint_gate_refs[boundary.zone_a] or capital_gate_refs[boundary.zone_a.."\0"..boundary.zone_b] or false
	local gate_ref_b=endpoint_gate_refs[boundary.zone_b] or capital_gate_refs[boundary.zone_b.."\0"..boundary.zone_a] or false
	local station_a_id=endpoint_station_id(boundary.zone_a,gate_ref_a)
	local station_b_id=endpoint_station_id(boundary.zone_b,gate_ref_b)
	local station_a=station_by_id[station_a_id]
	local station_b=station_by_id[station_b_id]
	local minus=point(crossing.x-geometry.approach_dx,crossing.z-geometry.approach_dz)
	local plus=point(crossing.x+geometry.approach_dx,crossing.z+geometry.approach_dz)
	local minus_distance=(minus.x-station_a.position.x)*(minus.x-station_a.position.x)+(minus.z-station_a.position.z)*(minus.z-station_a.position.z)
	local plus_distance=(plus.x-station_a.position.x)*(plus.x-station_a.position.x)+(plus.z-station_a.position.z)*(plus.z-station_a.position.z)
	local approach_a,approach_b=minus,plus
	if plus_distance<minus_distance then approach_a,approach_b=plus,minus end
	source.routes[route_index] = {
		id=route_id,boundary_id=boundary.id,zone_a=boundary.zone_a,
		zone_b=boundary.zone_b,class=route_class_order[route_index],
		centreline={point(station_a.position.x,station_a.position.z),approach_a,
			point(crossing.x,crossing.z),approach_b,
			point(station_b.position.x,station_b.position.z)},
		crossing_station=3,
		station_a_id=station_a_id,station_b_id=station_b_id,
		endpoint_a_id=interface_a,endpoint_b_id=interface_b,
		boundary_interface_id=crossing_id,grade_phase="class_default",
		gate_ref_a=gate_ref_a,gate_ref_b=gate_ref_b,
	}
	source.route_interfaces[#source.route_interfaces+1]={id=interface_a,
		route_id=route_id,kind="endpoint",zone_id=boundary.zone_a,
		position=source.routes[route_index].centreline[1],
		station_id=station_a_id,
		direction=sign_direction(crossing.x-station_a.position.x,crossing.z-station_a.position.z),
		grade_limit=fraction(1,12),grade_phase="flat_run_12",
		transition_semantic_id="road_climb_stair_v1"}
	source.route_interfaces[#source.route_interfaces+1]={id=interface_b,
		route_id=route_id,kind="endpoint",zone_id=boundary.zone_b,
		position=source.routes[route_index].centreline[5],
		station_id=station_b_id,
		direction=sign_direction(crossing.x-station_b.position.x,crossing.z-station_b.position.z),
		grade_limit=fraction(1,12),grade_phase="flat_run_12",
		transition_semantic_id="road_climb_stair_v1"}
	source.route_interfaces[#source.route_interfaces+1]={id=crossing_id,
		route_id=route_id,kind="boundary_crossing",boundary_id=boundary.id,
		position=point(crossing.x,crossing.z),direction=sign_direction(station_b.position.x-station_a.position.x,station_b.position.z-station_a.position.z),
		grade_limit=fraction(1,12),grade_phase="flat_run_12",
		transition_semantic_id="road_climb_stair_v1"}
end

-- Surface progression is authored at every zone core and every road endpoint.
-- The compiler interpolates these controls with the closed inverse-distance
-- Q16 rule; it may not derive levels from zone or route array order.
source.surface_level_controls = {}
local surface_route_by_id={}
for route_index=1,#source.routes do surface_route_by_id[source.routes[route_index].id]=source.routes[route_index] end
local surface_core_levels = {
	{"elandor_hearthpine_vale",5},{"elandor_copperfell_foothills",15},{"elandor_dur_brannoc",25},{"elandor_frostbarrow_shelf",25},{"elandor_stormvault_heights",35},
	{"elandor_dawnmere_fields",5},{"elandor_goldmead_vale",15},{"elandor_highcourt",25},{"elandor_whitebridge_shire",25},{"elandor_ashenward_march",35},
	{"elandor_silverleaf_glades",5},{"elandor_starbough_vale",15},{"elandor_lethariel",25},{"elandor_lorindor",25},{"elandor_moonfall_wood",25},{"elandor_glassroot_wilds",35},
	{"kragmar_stillgrave_hollow",5},{"kragmar_mournfen",15},{"kragmar_nhal_veyr",25},{"kragmar_ossuary_reach",25},{"kragmar_blackwind_rise",35},
	{"kragmar_sunscar_flats",5},{"kragmar_redtusk_savanna",15},{"kragmar_gor_drazhak",25},{"kragmar_speargrass_reach",25},{"kragmar_bannerbreak_mesa",35},
	{"kragmar_kapok_cradle",5},{"kragmar_raincall_basin",15},{"kragmar_kezamba",25},{"kragmar_whispering_reedlands",25},{"kragmar_totemwater_reach",25},{"kragmar_thunderroot_wilds",35},
	{"front_wyrmglass_crown",60},{"front_gravesalt_escarpment",55},{"front_broken_causeway",35},{"front_shattered_line",45},{"front_skyglass_canopy",55},{"front_stormscale_summit",60},
}
for core_index=1,#surface_core_levels do local row=surface_core_levels[core_index]
	source.surface_level_controls[#source.surface_level_controls+1]={
		id="surface_level:core:"..row[1],zone_id=row[1],kind="zone_core",
		station_id="station:"..row[1]..":hub",level=row[2],
		interpolation_id="inverse_distance_squared_q16_v1"}
end
local function level_gate(route_number,zone_a,level_a,role_a,zone_b,level_b,
		role_b,endgame_exception)
	local route_id=("route_%03d"):format(route_number)
	local route=surface_route_by_id[route_id]
	source.surface_level_controls[#source.surface_level_controls+1]={
		id="surface_level:"..route_id..":a",zone_id=zone_a,kind="road_gate",
		route_id=route_id,interface_id=route_id..":endpoint_a",level=level_a,
		position=point(route.centreline[2].x,route.centreline[2].z),
		progression_role=role_a,endgame_exception=endgame_exception,
		interpolation_id="inverse_distance_squared_q16_v1"}
	source.surface_level_controls[#source.surface_level_controls+1]={
		id="surface_level:"..route_id..":b",zone_id=zone_b,kind="road_gate",
		route_id=route_id,interface_id=route_id..":endpoint_b",level=level_b,
		position=point(route.centreline[#route.centreline-1].x,
			route.centreline[#route.centreline-1].z),
		progression_role=role_b,endgame_exception=endgame_exception,
		interpolation_id="inverse_distance_squared_q16_v1"}
end
level_gate(1,"elandor_hearthpine_vale",10,"front_high","elandor_copperfell_foothills",11,"home_low",false)
level_gate(2,"elandor_copperfell_foothills",20,"front_high","elandor_dur_brannoc",20,"home_low",false)
level_gate(3,"elandor_dur_brannoc",30,"front_high","elandor_stormvault_heights",31,"home_low",false)
level_gate(4,"elandor_dawnmere_fields",10,"front_high","elandor_goldmead_vale",11,"home_low",false)
level_gate(5,"elandor_goldmead_vale",20,"front_high","elandor_highcourt",20,"home_low",false)
level_gate(6,"elandor_highcourt",30,"front_high","elandor_ashenward_march",31,"home_low",false)
level_gate(7,"elandor_silverleaf_glades",10,"front_high","elandor_starbough_vale",11,"home_low",false)
level_gate(8,"elandor_starbough_vale",20,"front_high","elandor_lethariel",20,"home_low",false)
level_gate(9,"elandor_lethariel",30,"front_high","elandor_glassroot_wilds",31,"home_low",false)
level_gate(10,"kragmar_stillgrave_hollow",10,"front_high","kragmar_mournfen",11,"home_low",false)
level_gate(11,"kragmar_mournfen",20,"front_high","kragmar_nhal_veyr",20,"home_low",false)
level_gate(12,"kragmar_nhal_veyr",30,"front_high","kragmar_blackwind_rise",31,"home_low",false)
level_gate(13,"kragmar_sunscar_flats",10,"front_high","kragmar_redtusk_savanna",11,"home_low",false)
level_gate(14,"kragmar_redtusk_savanna",20,"front_high","kragmar_gor_drazhak",20,"home_low",false)
level_gate(15,"kragmar_gor_drazhak",30,"front_high","kragmar_bannerbreak_mesa",31,"home_low",false)
level_gate(16,"kragmar_kapok_cradle",10,"front_high","kragmar_raincall_basin",11,"home_low",false)
level_gate(17,"kragmar_raincall_basin",20,"front_high","kragmar_kezamba",20,"home_low",false)
level_gate(18,"kragmar_kezamba",30,"front_high","kragmar_thunderroot_wilds",31,"home_low",false)
level_gate(19,"elandor_frostbarrow_shelf",25,"lateral_neighbor","elandor_dur_brannoc",25,"lateral_neighbor",false)
level_gate(20,"elandor_dur_brannoc",25,"lateral_neighbor","elandor_whitebridge_shire",25,"lateral_neighbor",false)
level_gate(21,"elandor_whitebridge_shire",25,"lateral_neighbor","elandor_highcourt",25,"lateral_neighbor",false)
level_gate(22,"elandor_highcourt",25,"lateral_neighbor","elandor_lorindor",25,"lateral_neighbor",false)
level_gate(23,"elandor_lorindor",25,"lateral_neighbor","elandor_lethariel",25,"lateral_neighbor",false)
level_gate(24,"elandor_lethariel",25,"lateral_neighbor","elandor_moonfall_wood",25,"lateral_neighbor",false)
level_gate(25,"kragmar_ossuary_reach",25,"lateral_neighbor","kragmar_nhal_veyr",25,"lateral_neighbor",false)
level_gate(26,"kragmar_nhal_veyr",25,"lateral_neighbor","kragmar_speargrass_reach",25,"lateral_neighbor",false)
level_gate(27,"kragmar_speargrass_reach",25,"lateral_neighbor","kragmar_gor_drazhak",25,"lateral_neighbor",false)
level_gate(28,"kragmar_gor_drazhak",25,"lateral_neighbor","kragmar_whispering_reedlands",25,"lateral_neighbor",false)
level_gate(29,"kragmar_whispering_reedlands",25,"lateral_neighbor","kragmar_kezamba",25,"lateral_neighbor",false)
level_gate(30,"kragmar_kezamba",25,"lateral_neighbor","kragmar_totemwater_reach",25,"lateral_neighbor",false)
level_gate(31,"elandor_frostbarrow_shelf",30,"front_high","elandor_stormvault_heights",31,"home_low",false)
level_gate(32,"elandor_whitebridge_shire",30,"front_high","elandor_ashenward_march",31,"home_low",false)
level_gate(33,"elandor_lorindor",30,"front_high","elandor_glassroot_wilds",31,"home_low",false)
level_gate(34,"elandor_moonfall_wood",30,"front_high","elandor_glassroot_wilds",31,"home_low",false)
level_gate(35,"elandor_stormvault_heights",35,"lateral_neighbor","elandor_ashenward_march",35,"lateral_neighbor",false)
level_gate(36,"elandor_ashenward_march",35,"lateral_neighbor","elandor_glassroot_wilds",35,"lateral_neighbor",false)
level_gate(37,"kragmar_ossuary_reach",30,"front_high","kragmar_blackwind_rise",31,"home_low",false)
level_gate(38,"kragmar_speargrass_reach",30,"front_high","kragmar_bannerbreak_mesa",31,"home_low",false)
level_gate(39,"kragmar_whispering_reedlands",30,"front_high","kragmar_thunderroot_wilds",31,"home_low",false)
level_gate(40,"kragmar_totemwater_reach",30,"front_high","kragmar_thunderroot_wilds",31,"home_low",false)
level_gate(41,"kragmar_blackwind_rise",35,"lateral_neighbor","kragmar_bannerbreak_mesa",35,"lateral_neighbor",false)
level_gate(42,"kragmar_bannerbreak_mesa",35,"lateral_neighbor","kragmar_thunderroot_wilds",35,"lateral_neighbor",false)
level_gate(43,"elandor_stormvault_heights",40,"front_high","front_gravesalt_escarpment",51,"home_low",true)
level_gate(44,"elandor_stormvault_heights",35,"lateral_neighbor","front_broken_causeway",35,"lateral_neighbor",false)
level_gate(45,"elandor_ashenward_march",35,"lateral_neighbor","front_broken_causeway",35,"lateral_neighbor",false)
level_gate(46,"elandor_ashenward_march",40,"front_high","front_shattered_line",41,"home_low",false)
level_gate(47,"elandor_glassroot_wilds",40,"front_high","front_shattered_line",41,"home_low",false)
level_gate(48,"elandor_glassroot_wilds",40,"front_high","front_skyglass_canopy",51,"home_low",true)
level_gate(49,"kragmar_blackwind_rise",40,"front_high","front_gravesalt_escarpment",51,"home_low",true)
level_gate(50,"kragmar_blackwind_rise",35,"lateral_neighbor","front_broken_causeway",35,"lateral_neighbor",false)
level_gate(51,"kragmar_bannerbreak_mesa",35,"lateral_neighbor","front_broken_causeway",35,"lateral_neighbor",false)
level_gate(52,"kragmar_bannerbreak_mesa",40,"front_high","front_shattered_line",41,"home_low",false)
level_gate(53,"kragmar_thunderroot_wilds",40,"front_high","front_shattered_line",41,"home_low",false)
level_gate(54,"kragmar_thunderroot_wilds",40,"front_high","front_skyglass_canopy",51,"home_low",true)
level_gate(55,"front_gravesalt_escarpment",51,"home_low","front_broken_causeway",40,"front_high",true)
level_gate(56,"front_broken_causeway",40,"front_high","front_shattered_line",41,"home_low",false)
level_gate(57,"front_shattered_line",50,"front_high","front_skyglass_canopy",51,"home_low",true)

-- Named physical interfaces are explicit because route priority alone may
-- never decide a water/terrain overlap.
source.route_crossing_interfaces = {
	{id="whitebridge_bridge",route_id="route_021",kind="bridge",vertical_rule_id="bridge_clearance_v1",position=point(-400,-1500),direction="east",span=48,width=9,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",hydrology_id="hydro_whitebridge_main",alternate_id="whitebridge_ford",hard_protected=false},
	{id="whitebridge_ford",route_id="route_032",kind="ford",vertical_rule_id="ford_bed_v1",position=point(-900,-1100),direction="north",span=32,width=9,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",hydrology_id="hydro_whitebridge_ford",alternate_id="whitebridge_bridge",hard_protected=false},
	{id="broken_causeway",route_id="route_045",kind="causeway",vertical_rule_id="causeway_culvert_v1",position=point(-375,-250),direction="north",span=96,width=9,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",hydrology_id="hydro_broken_marsh",alternate_id="broken_ford",hard_protected=false},
	{id="broken_ford",route_id="route_050",kind="ford",vertical_rule_id="ford_bed_v1",position=point(-1125,250),direction="south",span=48,width=9,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",hydrology_id="hydro_broken_marsh",alternate_id="broken_aqueduct",hard_protected=false},
	{id="broken_aqueduct",route_id="route_055",kind="bridge",vertical_rule_id="bridge_clearance_v1",position=point(-1500,-125),direction="east",span=64,width=7,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",hydrology_id="hydro_broken_marsh",alternate_id="broken_causeway",hard_protected=false},
	{id="gravesalt_tomb_tunnel",route_id="route_043",kind="tunnel",vertical_rule_id="tunnel_lumen_v1",position=point(-2000,-100),direction="north",span=96,width=7,portal_length=16,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",landmark_id="gravesalt_tombways",alternate_id="route_044",hard_protected=false},
	{id="skyglass_cliff_tunnel",route_id="route_048",kind="tunnel",vertical_rule_id="tunnel_lumen_v1",position=point(2000,-100),direction="north",span=96,width=7,portal_length=16,grade_limit=fraction(1,12),grade_phase="flat_run_12",transition_semantic_id="road_climb_stair_v1",landmark_id="skyglass_escarpment",alternate_id="route_047",hard_protected=false},
}

source.boat_edges = {
	{numeric_id = 1, id = "boat_wyrmglass_south", from_zone = "front_gravesalt_escarpment", to_zone = "front_wyrmglass_crown", approach_z = -125, width = 96, landing_id = "wyrmglass_south_landing"},
	{numeric_id = 2, id = "boat_wyrmglass_north", from_zone = "front_gravesalt_escarpment", to_zone = "front_wyrmglass_crown", approach_z = 125, width = 96, landing_id = "wyrmglass_north_landing"},
	{numeric_id = 3, id = "boat_stormscale_south", from_zone = "front_skyglass_canopy", to_zone = "front_stormscale_summit", approach_z = -125, width = 96, landing_id = "stormscale_south_landing"},
	{numeric_id = 4, id = "boat_stormscale_north", from_zone = "front_skyglass_canopy", to_zone = "front_stormscale_summit", approach_z = 125, width = 96, landing_id = "stormscale_north_landing"},
}

source.island_landings = {
	{id="wyrmglass_south_landing",island_id="island_wyrmglass",zone_id="front_wyrmglass_crown",boat_edge_id="boat_wyrmglass_south",station_id="island_station_wyrmglass_south",position=point(-2890,-125)},
	{id="wyrmglass_north_landing",island_id="island_wyrmglass",zone_id="front_wyrmglass_crown",boat_edge_id="boat_wyrmglass_north",station_id="island_station_wyrmglass_north",position=point(-2890,125)},
	{id="stormscale_south_landing",island_id="island_stormscale",zone_id="front_stormscale_summit",boat_edge_id="boat_stormscale_south",station_id="island_station_stormscale_south",position=point(2890,-125)},
	{id="stormscale_north_landing",island_id="island_stormscale",zone_id="front_stormscale_summit",boat_edge_id="boat_stormscale_north",station_id="island_station_stormscale_north",position=point(2900,125)},
}

source.island_route_stations = {
	{id="island_station_wyrmglass_south",island_id="island_wyrmglass",kind="landing",position=point(-2890,-125)},
	{id="island_station_wyrmglass_north",island_id="island_wyrmglass",kind="landing",position=point(-2890,125)},
	{id="island_station_wyrmglass_junction",island_id="island_wyrmglass",kind="junction",position=point(-3100,0)},
	{id="island_station_wyrmglass_dragon",island_id="island_wyrmglass",kind="dragon",anchor_id="anchor_087",position=point(-3260,-40)},
	{id="island_station_wyrmglass_apex",island_id="island_wyrmglass",kind="apex_mine",anchor_id="anchor_089",position=point(-3200,80)},
	{id="island_station_stormscale_south",island_id="island_stormscale",kind="landing",position=point(2890,-125)},
	{id="island_station_stormscale_north",island_id="island_stormscale",kind="landing",position=point(2900,125)},
	{id="island_station_stormscale_junction",island_id="island_stormscale",kind="junction",position=point(3100,0)},
	{id="island_station_stormscale_dragon",island_id="island_stormscale",kind="dragon",anchor_id="anchor_088",position=point(3260,-40)},
	{id="island_station_stormscale_apex",island_id="island_stormscale",kind="apex_mine",anchor_id="anchor_090",position=point(3200,80)},
}
for station_index=1,#source.island_route_stations do local station=source.island_route_stations[station_index]
	local zone_id=station.island_id=="island_wyrmglass" and
		"front_wyrmglass_crown" or "front_stormscale_summit"
	source.surface_level_controls[#source.surface_level_controls+1]={
		id="surface_level:island:"..station.id,zone_id=zone_id,
		kind="level_60_endpoint",island_station_id=station.id,level=60,
		interpolation_id="flat_level_60_v1"}
end

local function island_route(id,island_id,from_id,to_id,points)
	return {id=id,island_id=island_id,class="secondary",from_station_id=from_id,
		to_station_id=to_id,centreline=points}
end
source.island_routes = {
	island_route("island_route_wyrmglass_south_junction","island_wyrmglass","island_station_wyrmglass_south","island_station_wyrmglass_junction",{point(-2890,-125),point(-2990,-90),point(-3100,0)}),
	island_route("island_route_wyrmglass_north_junction","island_wyrmglass","island_station_wyrmglass_north","island_station_wyrmglass_junction",{point(-2890,125),point(-2990,90),point(-3100,0)}),
	island_route("island_route_wyrmglass_junction_dragon","island_wyrmglass","island_station_wyrmglass_junction","island_station_wyrmglass_dragon",{point(-3100,0),point(-3180,-10),point(-3260,-40)}),
	island_route("island_route_wyrmglass_junction_apex","island_wyrmglass","island_station_wyrmglass_junction","island_station_wyrmglass_apex",{point(-3100,0),point(-3140,50),point(-3200,80)}),
	island_route("island_route_stormscale_south_junction","island_stormscale","island_station_stormscale_south","island_station_stormscale_junction",{point(2890,-125),point(2990,-90),point(3100,0)}),
	island_route("island_route_stormscale_north_junction","island_stormscale","island_station_stormscale_north","island_station_stormscale_junction",{point(2900,125),point(2990,90),point(3100,0)}),
	island_route("island_route_stormscale_junction_dragon","island_stormscale","island_station_stormscale_junction","island_station_stormscale_dragon",{point(3100,0),point(3180,-10),point(3260,-40)}),
	island_route("island_route_stormscale_junction_apex","island_stormscale","island_station_stormscale_junction","island_station_stormscale_apex",{point(3100,0),point(3140,50),point(3200,80)}),
}

source.island_route_interfaces = {}
for island_route_index=1,#source.island_routes do local row=source.island_routes[island_route_index]
	source.island_route_interfaces[#source.island_route_interfaces+1]={id=row.id..":from",route_id=row.id,station_id=row.from_station_id,kind="endpoint",position=point(row.centreline[1].x,row.centreline[1].z)}
	source.island_route_interfaces[#source.island_route_interfaces+1]={id=row.id..":to",route_id=row.id,station_id=row.to_station_id,kind="endpoint",position=point(row.centreline[#row.centreline].x,row.centreline[#row.centreline].z)}
end

source.bays = {
	{id = "bay_elandor_west", continent = "elandor",
		noise_domain = "bay_elandor_west", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id",
		shore_zone_ids = {"elandor_hearthpine_vale","elandor_copperfell_foothills",
			"elandor_dawnmere_fields","elandor_goldmead_vale"},
		perimeter_projection = {perimeter_id="perimeter_elandor_mainland",
			mouth_vertex_index=12,coast_left_zone_id="elandor_hearthpine_vale",
			coast_right_zone_id="elandor_dawnmere_fields"}, centreline = {
			{x=-980,z=-2940,half_width=360},{x=-900,z=-2600,half_width=280},{x=-1040,z=-2300,half_width=190},{x=-980,z=-2000,half_width=80},
		}},
	{id = "bay_elandor_east", continent = "elandor",
		noise_domain = "bay_elandor_east", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id",
		shore_zone_ids = {"elandor_dawnmere_fields","elandor_goldmead_vale",
			"elandor_silverleaf_glades","elandor_starbough_vale"},
		perimeter_projection = {perimeter_id="perimeter_elandor_mainland",
			mouth_vertex_index=16,coast_left_zone_id="elandor_dawnmere_fields",
			coast_right_zone_id="elandor_silverleaf_glades"}, centreline = {
			{x=900,z=-2920,half_width=330},{x=1080,z=-2580,half_width=250},{x=920,z=-2280,half_width=180},{x=1020,z=-1990,half_width=80},
		}},
	{id = "bay_kragmar_west", continent = "kragmar",
		noise_domain = "bay_kragmar_west", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id",
		shore_zone_ids = {"kragmar_stillgrave_hollow","kragmar_mournfen",
			"kragmar_sunscar_flats","kragmar_redtusk_savanna"},
		perimeter_projection = {perimeter_id="perimeter_kragmar_mainland",
			mouth_vertex_index=12,coast_left_zone_id="kragmar_stillgrave_hollow",
			coast_right_zone_id="kragmar_sunscar_flats"}, centreline = {
			{x=-1080,z=2930,half_width=320},{x=-1200,z=2620,half_width=260},{x=-940,z=2300,half_width=190},{x=-1060,z=2010,half_width=80},
		}},
	{id = "bay_kragmar_east", continent = "kragmar",
		noise_domain = "bay_kragmar_east", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id",
		shore_zone_ids = {"kragmar_sunscar_flats","kragmar_redtusk_savanna",
			"kragmar_kapok_cradle","kragmar_raincall_basin"},
		perimeter_projection = {perimeter_id="perimeter_kragmar_mainland",
			mouth_vertex_index=16,coast_left_zone_id="kragmar_sunscar_flats",
			coast_right_zone_id="kragmar_kapok_cradle"}, centreline = {
			{x=820,z=2960,half_width=370},{x=700,z=2630,half_width=250},{x=1050,z=2320,half_width=170},{x=900,z=1980,half_width=80},
		}},
}

-- A mouth aperture adds no geometry: it binds the first existing Bay sample
-- to its one perimeter vertex and two incident canonical spans. Stage 2 alone
-- derives the maximal half-open integer-station interval after displacement.
local function bay_mouth_aperture(id,bay_id,perimeter_id,mouth_vertex_index,
		before_span_id,after_span_id)
	return {id=id,bay_id=bay_id,mouth_sample_index=1,
		perimeter_id=perimeter_id,mouth_vertex_index=mouth_vertex_index,
		before_span_id=before_span_id,after_span_id=after_span_id,
		policy_id="maximal_contiguous_nonwrapping_half_open_exact_base_bay_perimeter_stations_v1",
		station_order="canonical_deduplicated_final_perimeter_integer_raster_order",
		geometry_rule="derive_from_referenced_bay_and_perimeter_no_copied_shape",
		owner_rule="same_exact_base_bay_projection_and_owner",
		boundary_tie="first_and_last_included_end_and_preceding_start_excluded_dry"}
end
source.bay_mouth_apertures={
	bay_mouth_aperture("bay_mouth_aperture:elandor_west","bay_elandor_west",EP,12,
		"perimeter_span:elandor:hearthpine","perimeter_span:elandor:dawnmere"),
	bay_mouth_aperture("bay_mouth_aperture:elandor_east","bay_elandor_east",EP,16,
		"perimeter_span:elandor:dawnmere","perimeter_span:elandor:silverleaf"),
	bay_mouth_aperture("bay_mouth_aperture:kragmar_west","bay_kragmar_west",KP,12,
		"perimeter_span:kragmar:stillgrave","perimeter_span:kragmar:sunscar"),
	bay_mouth_aperture("bay_mouth_aperture:kragmar_east","bay_kragmar_east",KP,16,
		"perimeter_span:kragmar:sunscar","perimeter_span:kragmar:kapok"),
}
for aperture_index=1,#source.bay_mouth_apertures do
	source.bays[aperture_index].mouth_aperture_id=source.bay_mouth_apertures[aperture_index].id
end

-- Reviewed implementation polylines close the positive-width head shoulders
-- against the two already-authored dry triple junctions.  They do not alter
-- the four binding centreline samples, the 57 pre-existing land-edge
-- authorities, the four boundary-only additions, or the land dual graph.
-- The analytic mask is strict: its side boundary and its
-- zero-width terminal junction remain dry.
source.bay_closure_wings = {
	{id="bay_wing:elandor_west:left",bay_id="bay_elandor_west",
		head_sample_index=4,head=point(-980,-2000),head_half_width=80,
		junction=point(-1400,-1900),junction_ref="junction:-1400:-1900",
		junction_edge_ids={"land_002","land_020"},
		left_zone_id="elandor_copperfell_foothills",right_zone_id="elandor_whitebridge_shire",
		left_probe=point(-1195,-1971),right_probe=point(-1185,-1929),
		tie_zone_id="elandor_copperfell_foothills"},
	{id="bay_wing:elandor_west:right",bay_id="bay_elandor_west",
		head_sample_index=4,head=point(-980,-2000),head_half_width=80,
		junction=point(-400,-1900),junction_ref="junction:-400:-1900",
		junction_edge_ids={"land_005","land_021"},
		left_zone_id="elandor_whitebridge_shire",right_zone_id="elandor_goldmead_vale",
		left_probe=point(-695,-1921),right_probe=point(-685,-1979),
		tie_zone_id="elandor_goldmead_vale"},
	{id="bay_wing:elandor_east:left",bay_id="bay_elandor_east",
		head_sample_index=4,head=point(1020,-1990),head_half_width=80,
		junction=point(400,-1900),junction_ref="junction:400:-1900",
		junction_edge_ids={"land_005","land_022"},
		left_zone_id="elandor_goldmead_vale",right_zone_id="elandor_lorindor",
		left_probe=point(706,-1975),right_probe=point(714,-1915),
		tie_zone_id="elandor_goldmead_vale"},
	{id="bay_wing:elandor_east:right",bay_id="bay_elandor_east",
		head_sample_index=4,head=point(1020,-1990),head_half_width=80,
		junction=point(1400,-1900),junction_ref="junction:1400:-1900",
		junction_edge_ids={"land_008","land_023"},
		left_zone_id="elandor_lorindor",right_zone_id="elandor_starbough_vale",
		left_probe=point(1206,-1926),right_probe=point(1214,-1964),
		tie_zone_id="elandor_starbough_vale"},
	{id="bay_wing:kragmar_west:left",bay_id="bay_kragmar_west",
		head_sample_index=4,head=point(-1060,2010),head_half_width=80,
		junction=point(-1400,1900),junction_ref="junction:-1400:1900",
		junction_edge_ids={"land_011","land_026"},
		left_zone_id="kragmar_speargrass_reach",right_zone_id="kragmar_mournfen",
		left_probe=point(-1219,1921),right_probe=point(-1241,1989),
		tie_zone_id="kragmar_mournfen"},
	{id="bay_wing:kragmar_west:right",bay_id="bay_kragmar_west",
		head_sample_index=4,head=point(-1060,2010),head_half_width=80,
		junction=point(-400,1900),junction_ref="junction:-400:1900",
		junction_edge_ids={"land_014","land_027"},
		left_zone_id="kragmar_redtusk_savanna",right_zone_id="kragmar_speargrass_reach",
		left_probe=point(-725,1985),right_probe=point(-735,1925),
		tie_zone_id="kragmar_redtusk_savanna"},
	{id="bay_wing:kragmar_east:left",bay_id="bay_kragmar_east",
		head_sample_index=4,head=point(900,1980),head_half_width=80,
		junction=point(400,1900),junction_ref="junction:400:1900",
		junction_edge_ids={"land_014","land_028"},
		left_zone_id="kragmar_whispering_reedlands",right_zone_id="kragmar_redtusk_savanna",
		left_probe=point(655,1910),right_probe=point(645,1970),
		tie_zone_id="kragmar_redtusk_savanna"},
	{id="bay_wing:kragmar_east:right",bay_id="bay_kragmar_east",
		head_sample_index=4,head=point(900,1980),head_half_width=80,
		junction=point(1400,1900),junction_ref="junction:1400:1900",
		junction_edge_ids={"land_017","land_029"},
		left_zone_id="kragmar_raincall_basin",right_zone_id="kragmar_whispering_reedlands",
		left_probe=point(1155,1970),right_probe=point(1145,1910),
		tie_zone_id="kragmar_raincall_basin"},
}
for wing_index=1,#source.bay_closure_wings do local wing=source.bay_closure_wings[wing_index]
	wing.numeric_id=wing_index
	wing.geometry_policy_id="strict_tapered_bay_closure_wing_v1"
	wing.noise_domain="fixed"
	wing.max_displacement=0
end
local bay_owner_span_authority={
	bay_elandor_west={{1,1,"elandor_hearthpine_vale","elandor_dawnmere_fields"},
		{2,3,"elandor_copperfell_foothills","elandor_goldmead_vale"}},
	bay_elandor_east={{1,1,"elandor_dawnmere_fields","elandor_silverleaf_glades"},
		{2,3,"elandor_goldmead_vale","elandor_starbough_vale"}},
	bay_kragmar_west={{1,1,"kragmar_sunscar_flats","kragmar_stillgrave_hollow"},
		{2,3,"kragmar_redtusk_savanna","kragmar_mournfen"}},
	bay_kragmar_east={{1,1,"kragmar_kapok_cradle","kragmar_sunscar_flats"},
		{2,3,"kragmar_raincall_basin","kragmar_redtusk_savanna"}},
}
for bay_index=1,#source.bays do local bay=source.bays[bay_index]
	bay.owner_spans={}
	local spans=bay_owner_span_authority[bay.id]
	for span_index=1,#spans do local span=spans[span_index]
		bay.owner_spans[span_index]={first_segment=span[1],last_segment=span[2],
			left_zone_id=span[3],right_zone_id=span[4]}
	end
	bay.owner_span_transition_rule="adjacent_spans_meet_at_authored_centreline_station"
	bay.owner_span_transition_tie="lower_zone_numeric_id_on_selected_side"
	bay.closure_wing_ids={"bay_wing:"..bay.id:sub(5)..":left",
		"bay_wing:"..bay.id:sub(5)..":right"}
end

source.islands = {
	{id = "island_wyrmglass", zone_id = "front_wyrmglass_crown",
		center = point(-3150,0), envelope = {radius_x=300,radius_z=350},
		orientation = "counterclockwise", noise_domain = "coast_wyrmglass",
		max_displacement = 48,
		polygon = {point(-3430,-80),point(-3360,-260),point(-3160,-330),point(-2940,-250),point(-2860,-80),point(-2890,150),point(-3060,320),point(-3290,280),point(-3440,100),point(-3430,-80)}},
	{id = "island_stormscale", zone_id = "front_stormscale_summit",
		center = point(3150,0), envelope = {radius_x=300,radius_z=350},
		orientation = "counterclockwise", noise_domain = "coast_stormscale",
		max_displacement = 48,
		polygon = {point(2870,-130),point(2970,-310),point(3200,-340),point(3400,-220),point(3440,20),point(3370,260),point(3150,330),point(2940,230),point(2860,60),point(2870,-130)}},
}
for record_index=1,#source.perimeters do local row=source.perimeters[record_index]
	row.geometry_authority="literal_perimeter_polygon_after_sole_boundary_displacement"
	row.source_geometry_role="independent_outer_footprint_and_shelf_authority"
end
source.perimeters[1].ordered_outer_components={
	"perimeter_span:elandor:stormvault:canonical_forward","perimeter_span:elandor:frostbarrow:canonical_forward",
	"perimeter_span:elandor:copperfell:canonical_forward","perimeter_span:elandor:hearthpine:canonical_forward",
	"perimeter_span:elandor:dawnmere:canonical_forward","perimeter_span:elandor:silverleaf:canonical_forward",
	"perimeter_span:elandor:starbough:canonical_forward","perimeter_span:elandor:moonfall:canonical_forward",
	"perimeter_span:elandor:glassroot:canonical_forward","land_048:reverse","land_047:reverse",
	"land_046:reverse","land_045:reverse","land_044:reverse","land_043:reverse",
}
source.perimeters[1].component_rule="canonical_perimeter_spans_cover_segments_1_through_26_once_then_fixed_holy_shared_edges"
source.perimeters[2].ordered_outer_components={
	"perimeter_span:kragmar:blackwind:canonical_forward","perimeter_span:kragmar:ossuary:canonical_forward",
	"perimeter_span:kragmar:mournfen:canonical_forward","perimeter_span:kragmar:stillgrave:canonical_forward",
	"perimeter_span:kragmar:sunscar:canonical_forward","perimeter_span:kragmar:kapok:canonical_forward",
	"perimeter_span:kragmar:raincall:canonical_forward","perimeter_span:kragmar:totemwater:canonical_forward",
	"perimeter_span:kragmar:thunderroot:canonical_forward","land_054:reverse","land_053:reverse",
	"land_052:reverse","land_051:reverse","land_050:reverse","land_049:reverse",
}
source.perimeters[2].component_rule=source.perimeters[1].component_rule
source.perimeters[3].ordered_outer_components={
	"land_043:forward","land_044:forward","land_045:forward","land_046:forward",
	"land_047:forward","land_048:forward","face_arc:skyglass:holy_east#1-1:forward",
	"land_054:reverse","land_053:reverse","land_052:reverse","land_051:reverse",
	"land_050:reverse","land_049:reverse","face_arc:gravesalt:holy_west#1-1:forward",
}
source.perimeters[3].component_rule="fixed_holy_shared_edges_and_fixed_holy_face_arc_spans"
for record_index=1,#source.bays do local row=source.bays[record_index]
	row.geometry_authority="unchanged_base_bay_centreline_half_width_round_capsule_union"
	row.source_geometry_role="sole_base_planned_water_mask_and_owner_seam"
	row.mouth_closure_rule="open_round_capsule_intersection_with_projected_outer_perimeter"
	row.head_closure_rule="closed_round_cap_at_final_centreline_sample"
	row.ordered_component_rule="authored_centreline_segments_in_array_order"
end
for record_index=1,#source.islands do local row=source.islands[record_index]
	row.geometry_authority="closed_island_face_arc"
	row.source_geometry_role="constraint_projection_and_envelope_only"
	row.closed_arc_id=record_index==1 and "face_arc:wyrmglass:island" or
		"face_arc:stormscale:island"
	row.ordered_component_rule="closed_face_arc_forward"
end

source.channels = {
	{id = "channel_wyrmglass", island_id = "island_wyrmglass",
		mainland_zone_id = "front_gravesalt_escarpment",
		orientation = "counterclockwise", warning_width = 48,
		minimum_hard_width = 104,
		classification_policy_id="strict_exterior_closed_integer_polygon_channel_v1",
		membership_rule="nonzero_integer_winding_or_exact_segment_equality_after_strict_exterior",
		boundary_rule="included_channel_only_after_land_and_planned_water_precedence",
		polygon = {point(-2850,-350),point(-2500,-350),point(-2500,350),point(-2850,350),point(-2850,-350)},
		approach_edge_ids = {"boat_wyrmglass_south","boat_wyrmglass_north"}},
	{id = "channel_stormscale", island_id = "island_stormscale",
		mainland_zone_id = "front_skyglass_canopy",
		orientation = "counterclockwise", warning_width = 48,
		minimum_hard_width = 104,
		classification_policy_id="strict_exterior_closed_integer_polygon_channel_v1",
		membership_rule="nonzero_integer_winding_or_exact_segment_equality_after_strict_exterior",
		boundary_rule="included_channel_only_after_land_and_planned_water_precedence",
		polygon = {point(2500,-350),point(2860,-350),point(2860,350),point(2500,350),point(2500,-350)},
		approach_edge_ids = {"boat_stormscale_south","boat_stormscale_north"}},
}

local function landmark(numeric_id, id, zone_id, primitive, x, z, radius_x,
		radius_z, relief_id)
	return {
		numeric_id = numeric_id,
		id = id,
		zone_id = zone_id,
		primitive = primitive,
		center = point(x, z),
		radius_x = radius_x,
		radius_z = radius_z,
		secondary_relief_id = relief_id,
		noise_domain = "landmark_" .. id,
	}
end

source.landmarks = {
	landmark(1,"hearthpine_bowl","elandor_hearthpine_vale","ellipse",-1800,-2520,290,220,"lowland"),
	landmark(2,"copperfell_drainage","elandor_copperfell_foothills","capsule",-2050,-2050,180,260,"highland"),
	landmark(3,"copperfell_coastal_terraces","elandor_copperfell_foothills","rectangle",-2430,-2200,150,300,"lowland"),
	landmark(4,"dur_brannoc_granite_terrace","elandor_dur_brannoc","rectangle",-1800,-1500,352,352,"plateau"),
	landmark(5,"dur_brannoc_forge_chasm","elandor_dur_brannoc","capsule",-1800,-1500,55,120,"highland"),
	landmark(6,"frostbarrow_escarpment","elandor_frostbarrow_shelf","capsule",-2420,-1450,120,300,"highland"),
	landmark(7,"frostbarrow_tarns","elandor_frostbarrow_shelf","ellipse",-2350,-1740,150,100,"plateau"),
	landmark(8,"stormvault_arch","elandor_stormvault_heights","ellipse",-1820,-650,180,130,"mountain"),
	landmark(9,"dawnmere_headwaters","elandor_dawnmere_fields","capsule",0,-2500,230,150,"wetland_delta"),
	landmark(10,"goldmead_millriver","elandor_goldmead_vale","capsule",0,-2020,110,260,"lowland"),
	landmark(11,"goldmead_orchard_slopes","elandor_goldmead_vale","ellipse",-280,-2050,210,150,"rolling_hills"),
	landmark(12,"highcourt_riverfork","elandor_highcourt","capsule",0,-1500,280,352,"lowland"),
	landmark(13,"whitebridge_crossing","elandor_whitebridge_shire","capsule",-900,-1500,250,70,"lowland"),
	landmark(14,"whitebridge_ford","elandor_whitebridge_shire","capsule",-720,-1260,180,60,"wetland_delta"),
	landmark(15,"ashenward_burnscar","elandor_ashenward_march","capsule",0,-720,260,90,"rolling_hills"),
	landmark(16,"ashenward_trenchbelt","elandor_ashenward_march","rectangle",0,-470,330,120,"wetland_delta"),
	landmark(17,"silverleaf_gladechain","elandor_silverleaf_glades","capsule",1800,-2520,250,180,"lowland"),
	landmark(18,"starbough_canopy_steps","elandor_starbough_vale","ellipse",1950,-2050,230,180,"highland"),
	landmark(19,"starbough_coastal_gardens","elandor_starbough_vale","rectangle",2430,-2200,150,300,"lowland"),
	landmark(20,"lethariel_crownlake","elandor_lethariel","ellipse",1800,-1500,260,220,"lowland"),
	landmark(21,"lorindor_silverorchards","elandor_lorindor","ellipse",900,-1500,280,190,"rolling_hills"),
	landmark(22,"lorindor_berrymarsh","elandor_lorindor","ellipse",1080,-1740,150,110,"wetland_delta"),
	landmark(23,"moonfall_crescent","elandor_moonfall_wood","ellipse",2400,-1500,150,230,"wetland_delta"),
	landmark(24,"glassroot_pale_cliffs","elandor_glassroot_wilds","capsule",1550,-650,170,300,"mountain"),
	landmark(25,"glassroot_rootways","elandor_glassroot_wilds","capsule",2050,-520,260,120,"highland"),
	landmark(26,"stillgrave_basin","kragmar_stillgrave_hollow","ellipse",-1800,2520,290,220,"lowland"),
	landmark(27,"stillgrave_ringbarrows","kragmar_stillgrave_hollow","ellipse",-1800,2520,330,250,"rolling_hills"),
	landmark(28,"mournfen_drowned_roads","kragmar_mournfen","capsule",-2050,2100,180,260,"wetland_delta"),
	landmark(29,"mournfen_dryward","kragmar_mournfen","rectangle",-2430,2200,150,300,"lowland"),
	landmark(30,"nhal_veyr_necropolis","kragmar_nhal_veyr","rectangle",-1800,1500,352,352,"plateau"),
	landmark(31,"ossuary_spine","kragmar_ossuary_reach","capsule",-2400,1450,130,300,"highland"),
	landmark(32,"ossuary_gravewoods","kragmar_ossuary_reach","ellipse",-2320,1730,170,120,"rolling_hills"),
	landmark(33,"blackwind_bonearches","kragmar_blackwind_rise","ellipse",-1850,650,220,150,"highland"),
	landmark(34,"blackwind_ashcuts","kragmar_blackwind_rise","capsule",-1350,520,240,110,"plateau"),
	landmark(35,"sunscar_open_flats","kragmar_sunscar_flats","rectangle",0,2520,290,220,"lowland"),
	landmark(36,"sunscar_waterholes","kragmar_sunscar_flats","ellipse",260,2450,130,90,"wetland_delta"),
	landmark(37,"redtusk_gullies","kragmar_redtusk_savanna","capsule",-120,2050,250,120,"plateau"),
	landmark(38,"redtusk_wellchain","kragmar_redtusk_savanna","capsule",180,2040,180,80,"rolling_hills"),
	landmark(39,"gor_drazhak_crossmesa","kragmar_gor_drazhak","rectangle",0,1500,352,352,"plateau"),
	landmark(40,"speargrass_dryriver","kragmar_speargrass_reach","capsule",-900,1500,280,90,"rolling_hills"),
	landmark(41,"speargrass_hunting_stones","kragmar_speargrass_reach","ellipse",-700,1750,180,100,"plateau"),
	landmark(42,"bannerbreak_crowned_mesa","kragmar_bannerbreak_mesa","ellipse",0,650,290,220,"highland"),
	landmark(43,"bannerbreak_siegeramps","kragmar_bannerbreak_mesa","capsule",0,430,330,100,"plateau"),
	landmark(44,"kapok_worldtree_basin","kragmar_kapok_cradle","ellipse",1800,2520,290,220,"wetland_delta"),
	landmark(45,"raincall_falls","kragmar_raincall_basin","capsule",2020,2080,210,260,"highland"),
	landmark(46,"raincall_coastal_steps","kragmar_raincall_basin","rectangle",2430,2200,150,300,"lowland"),
	landmark(47,"kezamba_cenote","kragmar_kezamba","ellipse",1800,1500,250,220,"wetland_delta"),
	landmark(48,"whispering_reedmaze","kragmar_whispering_reedlands","rectangle",900,1500,300,230,"wetland_delta"),
	landmark(49,"whispering_totemways","kragmar_whispering_reedlands","capsule",900,1500,300,80,"lowland"),
	landmark(50,"totemwater_delta","kragmar_totemwater_reach","capsule",2400,1500,160,300,"wetland_delta"),
	landmark(51,"totemwater_colossi","kragmar_totemwater_reach","ellipse",2380,1750,160,110,"lowland"),
	landmark(52,"thunderroot_exposures","kragmar_thunderroot_wilds","capsule",2050,520,260,120,"highland"),
	landmark(53,"thunderroot_ochresteps","kragmar_thunderroot_wilds","ellipse",1550,680,210,180,"plateau"),
	landmark(54,"wyrmglass_ring","front_wyrmglass_crown","ellipse",-3150,0,250,300,"mountain"),
	landmark(55,"wyrmglass_faultfields","front_wyrmglass_crown","rectangle",-3200,60,150,120,"highland"),
	landmark(56,"wyrmglass_dragonspire","front_wyrmglass_crown","ellipse",-3260,-40,100,90,"mountain"),
	landmark(57,"gravesalt_whitewall","front_gravesalt_escarpment","capsule",-2050,0,350,120,"mountain"),
	landmark(58,"gravesalt_tombways","front_gravesalt_escarpment","rectangle",-1800,0,260,160,"highland"),
	landmark(59,"gravesalt_warcoast","front_gravesalt_escarpment","capsule",-2450,0,80,230,"highland"),
	landmark(60,"broken_threeways","front_broken_causeway","rectangle",-750,0,520,180,"lowland"),
	landmark(61,"broken_marsh","front_broken_causeway","rectangle",-750,0,650,220,"wetland_delta"),
	landmark(62,"shattered_breachwall","front_shattered_line","capsule",750,0,620,70,"plateau"),
	landmark(63,"shattered_noman","front_shattered_line","rectangle",750,0,650,210,"rolling_hills"),
	landmark(64,"shattered_siegeramp","front_shattered_line","capsule",1250,60,180,80,"plateau"),
	landmark(65,"skyglass_escarpment","front_skyglass_canopy","capsule",2050,0,350,120,"mountain"),
	landmark(66,"skyglass_hangingways","front_skyglass_canopy","rectangle",1800,0,260,160,"rolling_hills"),
	landmark(67,"skyglass_warcoast","front_skyglass_canopy","capsule",2450,0,80,230,"highland"),
	landmark(68,"stormscale_caldera","front_stormscale_summit","ellipse",3150,0,250,300,"mountain"),
	landmark(69,"stormscale_gemterraces","front_stormscale_summit","rectangle",3200,60,150,120,"highland"),
	landmark(70,"stormscale_dragonroost","front_stormscale_summit","ellipse",3260,-40,100,90,"mountain"),
}

local hydrology_landmarks = {
	copperfell_drainage=true,frostbarrow_tarns=true,dawnmere_headwaters=true,
	goldmead_millriver=true,highcourt_riverfork=true,whitebridge_crossing=true,
	whitebridge_ford=true,lethariel_crownlake=true,lorindor_berrymarsh=true,
	moonfall_crescent=true,mournfen_drowned_roads=true,sunscar_waterholes=true,
	speargrass_dryriver=true,raincall_falls=true,kezamba_cenote=true,
	whispering_reedmaze=true,totemwater_delta=true,gravesalt_whitewall=true,
	broken_marsh=true,
}
local route_landmarks = {
	stormvault_arch=true,whitebridge_crossing=true,whitebridge_ford=true,
	ashenward_trenchbelt=true,glassroot_rootways=true,mournfen_drowned_roads=true,
	blackwind_bonearches=true,redtusk_gullies=true,speargrass_dryriver=true,
	bannerbreak_siegeramps=true,whispering_totemways=true,
	thunderroot_exposures=true,wyrmglass_ring=true,gravesalt_whitewall=true,
	gravesalt_tombways=true,gravesalt_warcoast=true,broken_threeways=true,
	shattered_breachwall=true,shattered_siegeramp=true,skyglass_escarpment=true,
	skyglass_hangingways=true,skyglass_warcoast=true,stormscale_caldera=true,
}
local target_landmarks = {
	copperfell_coastal_terraces=true,dur_brannoc_granite_terrace=true,
	dur_brannoc_forge_chasm=true,starbough_coastal_gardens=true,
	lethariel_crownlake=true,nhal_veyr_necropolis=true,mournfen_dryward=true,
	gor_drazhak_crossmesa=true,raincall_coastal_steps=true,kezamba_cenote=true,
	wyrmglass_faultfields=true,wyrmglass_dragonspire=true,
	stormscale_gemterraces=true,stormscale_dragonroost=true,
}
for landmark_index = 1, #source.landmarks do
	local row = source.landmarks[landmark_index]
	local roles = {"base_H"}
	if target_landmarks[row.id] then roles[#roles+1]="target_T" end
	if hydrology_landmarks[row.id] then roles[#roles+1]="hydrology" end
	if route_landmarks[row.id] then
		roles[#roles+1]="route"
		roles[#roles+1]="interface"
	end
	roles[#roles+1]="dressing"
	row.roles=roles
	row.base_h_priority=landmark_index
	row.base_h_composition="replace_profile_height"
	row.base_h_blend_width=64
end

local function fixed_anchor(numeric_id, zone_id, slot_id, x, z, template_id)
	return {
		numeric_id = numeric_id,
		id = ("anchor_%03d"):format(numeric_id),
		zone_id = zone_id,
		slot_id = slot_id,
		placement_mode = "fixed",
		template_id = template_id,
		position = point(x, z),
	}
end

local function candidate_anchor(numeric_id, zone_id, slot_id, x, z,
		template_id)
	-- Flexible slots use one conservative three-point authored set. The small
	-- offsets keep every fallback inside the same reserved envelope; T2b must
	-- still reject the seed if none passes the complete solver.
	return {
		numeric_id = numeric_id,
		id = ("anchor_%03d"):format(numeric_id),
		zone_id = zone_id,
		slot_id = slot_id,
		placement_mode = "candidate_set",
		template_id = template_id,
		candidates = {point(x,z),point(x+32,z-16),point(x-24,z+24)},
	}
end

local function rare_anchor(numeric_id, zone_id, slot_id, x, z,
		patrol_offsets)
	local row = candidate_anchor(numeric_id, zone_id, slot_id, x, z,
		"rare_route")
	-- Named-rare routes move with the first valid candidate. These ordered
	-- offsets are the complete authored route authority; the compiler adds
	-- them to the selected candidate and does not consult candidate 1 again.
	row.patrol_coordinate_space = "selected_candidate_relative"
	row.patrol_offsets = patrol_offsets
	return row
end


source.anchors = {
	-- Six starts and six capitals retain the exact fixed §7 coordinates.
	fixed_anchor(1,"elandor_hearthpine_vale","start",-1800,-2550,"start"),
	fixed_anchor(2,"elandor_dawnmere_fields","start",0,-2550,"start"),
	fixed_anchor(3,"elandor_silverleaf_glades","start",1800,-2550,"start"),
	fixed_anchor(4,"kragmar_stillgrave_hollow","start",-1800,2550,"start"),
	fixed_anchor(5,"kragmar_sunscar_flats","start",0,2550,"start"),
	fixed_anchor(6,"kragmar_kapok_cradle","start",1800,2550,"start"),
	fixed_anchor(7,"elandor_dur_brannoc","capital",-1800,-1500,"capital_dwarf"),
	fixed_anchor(8,"elandor_highcourt","capital",0,-1500,"capital_human"),
	fixed_anchor(9,"elandor_lethariel","capital",1800,-1500,"capital_elf"),
	fixed_anchor(10,"kragmar_nhal_veyr","capital",-1800,1500,"capital_undead"),
	fixed_anchor(11,"kragmar_gor_drazhak","capital",0,1500,"capital_orc"),
	fixed_anchor(12,"kragmar_kezamba","capital",1800,1500,"capital_troll"),
	-- Twelve villages: exactly two per race region.
	candidate_anchor(13,"elandor_copperfell_foothills","village_1",-1900,-2020,"village"),
	candidate_anchor(14,"elandor_frostbarrow_shelf","village_1",-2380,-1600,"village"),
	candidate_anchor(15,"elandor_goldmead_vale","village_1",-120,-2020,"village"),
	candidate_anchor(16,"elandor_whitebridge_shire","village_1",-900,-1580,"village"),
	candidate_anchor(17,"elandor_starbough_vale","village_1",1900,-2020,"village"),
	candidate_anchor(18,"elandor_lorindor","village_1",900,-1580,"village"),
	candidate_anchor(19,"kragmar_mournfen","village_1",-1900,2020,"village"),
	candidate_anchor(20,"kragmar_ossuary_reach","village_1",-2380,1600,"village"),
	candidate_anchor(21,"kragmar_redtusk_savanna","village_1",-120,2020,"village"),
	candidate_anchor(22,"kragmar_speargrass_reach","village_1",-900,1580,"village"),
	candidate_anchor(23,"kragmar_raincall_basin","village_1",1900,2020,"village"),
	candidate_anchor(24,"kragmar_whispering_reedlands","village_1",900,1580,"village"),
	-- Twenty-four ordinary outposts: exactly four per race region.
	candidate_anchor(25,"elandor_copperfell_foothills","outpost_1",-2100,-2100,"outpost"),
	candidate_anchor(26,"elandor_frostbarrow_shelf","outpost_1",-2300,-1250,"outpost"),
	candidate_anchor(27,"elandor_stormvault_heights","outpost_1",-2050,-850,"outpost"),
	candidate_anchor(28,"elandor_stormvault_heights","outpost_2",-1500,-450,"outpost"),
	candidate_anchor(29,"elandor_goldmead_vale","outpost_1",200,-2050,"outpost"),
	candidate_anchor(30,"elandor_whitebridge_shire","outpost_1",-650,-1250,"outpost"),
	candidate_anchor(31,"elandor_ashenward_march","outpost_1",-350,-850,"outpost"),
	candidate_anchor(32,"elandor_ashenward_march","outpost_2",300,-450,"outpost"),
	candidate_anchor(33,"elandor_starbough_vale","outpost_1",2100,-2100,"outpost"),
	candidate_anchor(34,"elandor_lorindor","outpost_1",650,-1250,"outpost"),
	candidate_anchor(35,"elandor_moonfall_wood","outpost_1",2400,-1350,"outpost"),
	candidate_anchor(36,"elandor_glassroot_wilds","outpost_1",1900,-550,"outpost"),
	candidate_anchor(37,"kragmar_mournfen","outpost_1",-2100,2100,"outpost"),
	candidate_anchor(38,"kragmar_ossuary_reach","outpost_1",-2300,1250,"outpost"),
	candidate_anchor(39,"kragmar_blackwind_rise","outpost_1",-2050,850,"outpost"),
	candidate_anchor(40,"kragmar_blackwind_rise","outpost_2",-1500,450,"outpost"),
	candidate_anchor(41,"kragmar_redtusk_savanna","outpost_1",200,2050,"outpost"),
	candidate_anchor(42,"kragmar_speargrass_reach","outpost_1",-650,1250,"outpost"),
	candidate_anchor(43,"kragmar_bannerbreak_mesa","outpost_1",-350,850,"outpost"),
	candidate_anchor(44,"kragmar_bannerbreak_mesa","outpost_2",300,450,"outpost"),
	candidate_anchor(45,"kragmar_raincall_basin","outpost_1",2100,2100,"outpost"),
	candidate_anchor(46,"kragmar_whispering_reedlands","outpost_1",650,1250,"outpost"),
	candidate_anchor(47,"kragmar_totemwater_reach","outpost_1",2400,1350,"outpost"),
	candidate_anchor(48,"kragmar_thunderroot_wilds","outpost_1",1900,550,"outpost"),
	-- Twelve fixed-budget bandit slots: one home and one frontier per race.
	candidate_anchor(49,"elandor_copperfell_foothills","bandit_1",-1600,-2050,"bandit_home"),
	candidate_anchor(50,"elandor_stormvault_heights","bandit_1",-1800,-430,"bandit_frontier"),
	candidate_anchor(51,"elandor_goldmead_vale","bandit_1",320,-1980,"bandit_home"),
	candidate_anchor(52,"elandor_ashenward_march","bandit_1",0,-430,"bandit_frontier"),
	candidate_anchor(53,"elandor_starbough_vale","bandit_1",1600,-2050,"bandit_home"),
	candidate_anchor(54,"elandor_glassroot_wilds","bandit_1",1800,-430,"bandit_frontier"),
	candidate_anchor(55,"kragmar_mournfen","bandit_1",-1600,2050,"bandit_home"),
	candidate_anchor(56,"kragmar_blackwind_rise","bandit_1",-1800,430,"bandit_frontier"),
	candidate_anchor(57,"kragmar_redtusk_savanna","bandit_1",320,1980,"bandit_home"),
	candidate_anchor(58,"kragmar_bannerbreak_mesa","bandit_1",0,430,"bandit_frontier"),
	candidate_anchor(59,"kragmar_raincall_basin","bandit_1",1600,2050,"bandit_home"),
	candidate_anchor(60,"kragmar_thunderroot_wilds","bandit_1",1800,430,"bandit_frontier"),
	-- Six peaceful regional mines and four Mirefolk camps.
	candidate_anchor(61,"elandor_frostbarrow_shelf","mine",-2450,-1280,"mine"),
	candidate_anchor(62,"elandor_whitebridge_shire","mine",-1050,-1280,"mine"),
	candidate_anchor(63,"elandor_lorindor","mine",1050,-1280,"mine"),
	candidate_anchor(64,"kragmar_ossuary_reach","mine",-2450,1280,"mine"),
	candidate_anchor(65,"kragmar_speargrass_reach","mine",-1050,1280,"mine"),
	candidate_anchor(66,"kragmar_whispering_reedlands","mine",1050,1280,"mine"),
	candidate_anchor(67,"elandor_whitebridge_shire","mirefolk",-620,-1760,"mirefolk"),
	candidate_anchor(68,"elandor_lorindor","mirefolk",1120,-1740,"mirefolk"),
	candidate_anchor(69,"kragmar_mournfen","mirefolk",-2050,2250,"mirefolk"),
	candidate_anchor(70,"kragmar_whispering_reedlands","mirefolk",1120,1740,"mirefolk"),
	-- Sixteen dedicated clash anchors.
	candidate_anchor(71,"elandor_ashenward_march","clash_1",-250,-320,"clash"),
	candidate_anchor(72,"elandor_ashenward_march","clash_2",250,-320,"clash"),
	candidate_anchor(73,"kragmar_bannerbreak_mesa","clash_1",-250,320,"clash"),
	candidate_anchor(74,"kragmar_bannerbreak_mesa","clash_2",250,320,"clash"),
	candidate_anchor(75,"front_wyrmglass_crown","clash_1",-3000,170,"clash"),
	candidate_anchor(76,"front_gravesalt_escarpment","clash_1",-2200,-80,"clash"),
	candidate_anchor(77,"front_gravesalt_escarpment","clash_2",-1800,80,"clash"),
	candidate_anchor(78,"front_broken_causeway","clash_1",-1250,-100,"clash"),
	candidate_anchor(79,"front_broken_causeway","clash_2",-750,100,"clash"),
	candidate_anchor(80,"front_broken_causeway","clash_3",-250,-100,"clash"),
	candidate_anchor(81,"front_shattered_line","clash_1",250,100,"clash"),
	candidate_anchor(82,"front_shattered_line","clash_2",750,-100,"clash"),
	candidate_anchor(83,"front_shattered_line","clash_3",1250,100,"clash"),
	candidate_anchor(84,"front_skyglass_canopy","clash_1",1800,-80,"clash"),
	candidate_anchor(85,"front_skyglass_canopy","clash_2",2200,80,"clash"),
	candidate_anchor(86,"front_stormscale_summit","clash_1",3000,170,"clash"),
	-- Two dragon arenas and two all-six-gem apex mines.
	fixed_anchor(87,"front_wyrmglass_crown","dragon",-3260,-40,"dragon"),
	fixed_anchor(88,"front_stormscale_summit","dragon",3260,-40,"dragon"),
	fixed_anchor(89,"front_wyrmglass_crown","apex_mine",-3200,80,"apex_mine"),
	fixed_anchor(90,"front_stormscale_summit","apex_mine",3200,80,"apex_mine"),
	-- Ten stable named-rare route instances; Captain Bonerattle owns one
	-- instance in each of its two published route zones. Route points are
	-- explicit candidate-relative offsets because these slots are relocatable,
	-- unlike the fixed island targets above.
	rare_anchor(91,"elandor_goldmead_vale","rare_grimtusk",120,-2100,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(92,"elandor_ashenward_march","rare_old_whitefang",-180,-650,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(93,"elandor_stormvault_heights","rare_korgans_bane",-1850,-620,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(94,"front_skyglass_canopy","rare_silkfang",2050,70,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(95,"kragmar_blackwind_rise","rare_marrowclaw",-1850,620,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(96,"kragmar_bannerbreak_mesa","rare_dustwing",180,650,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(97,"front_stormscale_summit","rare_emerald_coil",3000,-120,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(98,"kragmar_redtusk_savanna","rare_ashmaw",120,2100,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(99,"front_broken_causeway","rare_captain_bonerattle",-600,80,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(100,"front_shattered_line","rare_captain_bonerattle",600,-80,
		{point(-48,-24),point(16,40),point(56,-16)}),
}

-- These are WP40's exact per-node apex socket placements. They reserve stable
-- semantic positions only: no node, refill behavior, or future camp footprint
-- becomes active in T2. WP34 later activates each reservation explicitly.
local apex_socket_species = {
	"citrine","citrine","garnet","garnet","jade","jade",
	"diamond","diamond","sapphire","sapphire","ruby","ruby",
}
local apex_socket_offsets = {
	point(-24,-16),point(-8,-16),point(8,-16),point(24,-16),
	point(-24,0),point(-8,0),point(8,0),point(24,0),
	point(-24,16),point(-8,16),point(8,16),point(24,16),
}
for _, anchor_index in ipairs({89,90}) do
	local anchor = source.anchors[anchor_index]
	anchor.socket_coordinate_space = "anchor_relative"
	anchor.socket_reservations = {}
	for socket_index = 1, 12 do
		local offset=apex_socket_offsets[socket_index]
		anchor.socket_reservations[socket_index] = {
			id = ("apex_socket:%s:%02d"):format(anchor.id, socket_index),
			resource_key = apex_socket_species[socket_index],
			offset = point(offset.x,offset.z),
			position = point(anchor.position.x+offset.x,anchor.position.z+offset.z),
			implementation_owner = "WP40", refill_owner = "WP34",
			approach_route_id = anchor_index==89 and
				"island_route_wyrmglass_junction_apex" or
				"island_route_stormscale_junction_apex",
			status = "active", active = true,
		}
	end
end

-- Each major POI has three fully authored candidate-relative alternatives.
-- The terminal offset resolves to the literal world station below; source
-- route order is irrelevant and no generic direction template is applied.
local function spur_binding(anchor_id,route_id,station_id,interface_id,
		target_position,candidate_paths)
	return {id="poi_spur:"..anchor_id,anchor_id=anchor_id,class="secondary",
		coordinate_space="candidate_specific_relative_to_fixed_world_station",
		candidate_paths=candidate_paths,target_route_id=route_id,
		target_station_id=station_id,target_interface_id=interface_id,
		target_position=target_position,terminal_rule="fixed_station_exact"}
end
local function trail_spur_binding(anchor_id,route_id,station_id,interface_id,
		target_position,candidate_paths)
	local row=spur_binding(anchor_id,route_id,station_id,interface_id,
		target_position,candidate_paths)
	row.class="trail"
	return row
end
source.poi_spurs = {
	spur_binding("anchor_013","route_001","station:elandor_copperfell_foothills:hub","route_001:endpoint_b",point(-1800,-2050),{{point(0,0),point(14,21),point(100,-30)},{point(0,0),point(10,17),point(68,-14)},{point(0,0),point(50,-15),point(124,-54)}}),
	spur_binding("anchor_014","route_019","station:elandor_frostbarrow_shelf:hub","route_019:endpoint_a",point(-2400,-1500),{{point(0,0),point(-34,74),point(-20,100)},{point(0,0),point(-38,70),point(-52,116)},{point(0,0),point(2,38),point(4,76)}}),
	spur_binding("anchor_015","route_004","station:elandor_goldmead_vale:hub","route_004:endpoint_b",point(0,-2050),{{point(0,0),point(48,-3),point(120,-30)},{point(0,0),point(44,-7),point(88,-14)},{point(0,0),point(84,-39),point(144,-54)}}),
	spur_binding("anchor_016","route_020","station:elandor_whitebridge_shire:hub","route_020:endpoint_b",point(-900,-1500),{{point(0,0),point(0,40),point(0,80)},{point(0,0),point(-4,36),point(-32,96)},{point(0,0),point(36,4),point(24,56)}}),
	spur_binding("anchor_017","route_007","station:elandor_starbough_vale:hub","route_007:endpoint_b",point(1800,-2050),{{point(0,0),point(-38,-27),point(-100,-30)},{point(0,0),point(-42,-31),point(-132,-14)},{point(0,0),point(-2,-63),point(-76,-54)}}),
	spur_binding("anchor_018","route_022","station:elandor_lorindor:hub","route_022:endpoint_b",point(900,-1500),{{point(0,0),point(24,16),point(0,80)},{point(0,0),point(20,12),point(-32,96)},{point(0,0),point(-24,64),point(24,56)}}),
	spur_binding("anchor_019","route_010","station:kragmar_mournfen:hub","route_010:endpoint_b",point(-1800,2050),{{point(0,0),point(86,-21),point(100,30)},{point(0,0),point(-2,59),point(68,46)},{point(0,0),point(38,27),point(124,6)}}),
	spur_binding("anchor_020","route_025","station:kragmar_ossuary_reach:hub","route_025:endpoint_a",point(-2400,1500),{{point(0,0),point(-46,-14),point(-20,-100)},{point(0,0),point(-50,-18),point(-52,-84)},{point(0,0),point(-10,-50),point(4,-124)}}),
	spur_binding("anchor_021","route_013","station:kragmar_redtusk_savanna:hub","route_013:endpoint_b",point(0,2050),{{point(0,0),point(36,39),point(120,30)},{point(0,0),point(32,35),point(88,46)},{point(0,0),point(72,3),point(144,6)}}),
	spur_binding("anchor_022","route_026","station:kragmar_speargrass_reach:hub","route_026:endpoint_b",point(-900,1500),{{point(0,0),point(-12,-28),point(0,-80)},{point(0,0),point(-16,-32),point(-32,-64)},{point(0,0),point(24,-64),point(24,-104)}}),
	spur_binding("anchor_023","route_016","station:kragmar_raincall_basin:hub","route_016:endpoint_b",point(1800,2050),{{point(0,0),point(-50,15),point(-100,30)},{point(0,0),point(-54,11),point(-132,46)},{point(0,0),point(-14,-21),point(-76,6)}}),
	spur_binding("anchor_024","route_028","station:kragmar_whispering_reedlands:hub","route_028:endpoint_b",point(900,1500),{{point(0,0),point(12,-52),point(0,-80)},{point(0,0),point(8,-56),point(-32,-64)},{point(0,0),point(48,-88),point(24,-104)}}),
	spur_binding("anchor_025","route_001","station:elandor_copperfell_foothills:hub","route_001:endpoint_b",point(-1800,-2050),{{point(0,0),point(174,1),point(300,50)},{point(0,0),point(170,-3),point(268,66)},{point(0,0),point(126,49),point(324,26)}}),
	spur_binding("anchor_026","route_019","station:elandor_frostbarrow_shelf:hub","route_019:endpoint_a",point(-2400,-1500),{{point(0,0),point(-14,-161),point(-100,-250)},{point(0,0),point(-102,-81),point(-132,-234)},{point(0,0),point(-62,-113),point(-76,-274)}}),
	spur_binding("anchor_027","route_003","station:elandor_stormvault_heights:hub","route_003:endpoint_b",point(-1800,-700),{{point(0,0),point(89,111),point(250,150)},{point(0,0),point(85,107),point(218,166)},{point(0,0),point(125,75),point(274,126)}}),
	spur_binding("anchor_028","route_044","station:elandor_stormvault_heights:hub","route_044:endpoint_a",point(-1800,-700),{{point(0,0),point(-174,-101),point(-300,-250)},{point(0,0),point(-178,-105),point(-332,-234)},{point(0,0),point(-138,-137),point(-276,-274)}}),
	spur_binding("anchor_029","route_004","station:elandor_goldmead_vale:hub","route_004:endpoint_b",point(0,-2050),{{point(0,0),point(-112,12),point(-200,0)},{point(0,0),point(-116,8),point(-232,16)},{point(0,0),point(-76,-24),point(-176,-24)}}),
	spur_binding("anchor_030","route_020","station:elandor_whitebridge_shire:hub","route_020:endpoint_b",point(-900,-1500),{{point(0,0),point(-125,-125),point(-250,-250)},{point(0,0),point(-129,-129),point(-282,-234)},{point(0,0),point(-89,-161),point(-226,-274)}}),
	spur_binding("anchor_031","route_006","station:elandor_ashenward_march:hub","route_006:endpoint_b",point(0,-700),{{point(0,0),point(187,63),point(350,150)},{point(0,0),point(183,59),point(318,166)},{point(0,0),point(223,27),point(374,126)}}),
	spur_binding("anchor_032","route_046","station:elandor_ashenward_march:hub","route_046:endpoint_a",point(0,-700),{{point(0,0),point(-126,-149),point(-300,-250)},{point(0,0),point(-130,-153),point(-332,-234)},{point(0,0),point(-174,-101),point(-276,-274)}}),
	spur_binding("anchor_033","route_007","station:elandor_starbough_vale:hub","route_007:endpoint_b",point(1800,-2050),{{point(0,0),point(-114,-11),point(-300,50)},{point(0,0),point(-202,69),point(-332,66)},{point(0,0),point(-162,37),point(-276,26)}}),
	spur_binding("anchor_034","route_022","station:elandor_lorindor:hub","route_022:endpoint_b",point(900,-1500),{{point(0,0),point(89,-89),point(250,-250)},{point(0,0),point(85,-93),point(218,-234)},{point(0,0),point(125,-125),point(274,-274)}}),
	spur_binding("anchor_035","route_024","station:elandor_moonfall_wood:hub","route_024:endpoint_b",point(2400,-1500),{{point(0,0),point(-24,-51),point(0,-150)},{point(0,0),point(-28,-55),point(-32,-134)},{point(0,0),point(12,-87),point(24,-174)}}),
	spur_binding("anchor_036","route_009","station:elandor_glassroot_wilds:hub","route_009:endpoint_b",point(1800,-700),{{point(0,0),point(-62,-63),point(-100,-150)},{point(0,0),point(-66,-67),point(-132,-134)},{point(0,0),point(-26,-99),point(-76,-174)}}),
	spur_binding("anchor_037","route_010","station:kragmar_mournfen:hub","route_010:endpoint_b",point(-1800,2050),{{point(0,0),point(150,-25),point(300,-50)},{point(0,0),point(146,-29),point(268,-34)},{point(0,0),point(186,-61),point(324,-74)}}),
	spur_binding("anchor_038","route_025","station:kragmar_ossuary_reach:hub","route_025:endpoint_a",point(-2400,1500),{{point(0,0),point(-38,113),point(-100,250)},{point(0,0),point(-42,109),point(-132,266)},{point(0,0),point(-2,77),point(-76,226)}}),
	spur_binding("anchor_039","route_012","station:kragmar_blackwind_rise:hub","route_012:endpoint_b",point(-1800,700),{{point(0,0),point(149,-99),point(250,-150)},{point(0,0),point(145,-103),point(218,-134)},{point(0,0),point(101,-51),point(274,-174)}}),
	spur_binding("anchor_040","route_050","station:kragmar_blackwind_rise:hub","route_050:endpoint_a",point(-1800,700),{{point(0,0),point(-114,89),point(-300,250)},{point(0,0),point(-202,169),point(-332,266)},{point(0,0),point(-162,137),point(-276,226)}}),
	spur_binding("anchor_041","route_013","station:kragmar_redtusk_savanna:hub","route_013:endpoint_b",point(0,2050),{{point(0,0),point(-136,36),point(-200,0)},{point(0,0),point(-140,32),point(-232,16)},{point(0,0),point(-100,0),point(-176,-24)}}),
	spur_binding("anchor_042","route_026","station:kragmar_speargrass_reach:hub","route_026:endpoint_b",point(-900,1500),{{point(0,0),point(-149,149),point(-250,250)},{point(0,0),point(-153,145),point(-282,266)},{point(0,0),point(-113,113),point(-226,226)}}),
	spur_binding("anchor_043","route_015","station:kragmar_bannerbreak_mesa:hub","route_015:endpoint_b",point(0,700),{{point(0,0),point(163,-63),point(350,-150)},{point(0,0),point(159,-67),point(318,-134)},{point(0,0),point(199,-99),point(374,-174)}}),
	spur_binding("anchor_044","route_052","station:kragmar_bannerbreak_mesa:hub","route_052:endpoint_a",point(0,700),{{point(0,0),point(-150,125),point(-300,250)},{point(0,0),point(-154,121),point(-332,266)},{point(0,0),point(-114,89),point(-276,226)}}),
	spur_binding("anchor_045","route_016","station:kragmar_raincall_basin:hub","route_016:endpoint_b",point(1800,2050),{{point(0,0),point(-138,-37),point(-300,-50)},{point(0,0),point(-142,-41),point(-332,-34)},{point(0,0),point(-102,-73),point(-276,-74)}}),
	spur_binding("anchor_046","route_028","station:kragmar_whispering_reedlands:hub","route_028:endpoint_b",point(900,1500),{{point(0,0),point(149,101),point(250,250)},{point(0,0),point(145,97),point(218,266)},{point(0,0),point(101,149),point(274,226)}}),
	spur_binding("anchor_047","route_030","station:kragmar_totemwater_reach:hub","route_030:endpoint_b",point(2400,1500),{{point(0,0),point(36,39),point(0,150)},{point(0,0),point(-52,119),point(-32,166)},{point(0,0),point(-12,87),point(24,126)}}),
	spur_binding("anchor_048","route_018","station:kragmar_thunderroot_wilds:hub","route_018:endpoint_b",point(1800,700),{{point(0,0),point(-86,111),point(-100,150)},{point(0,0),point(-90,107),point(-132,166)},{point(0,0),point(-50,75),point(-76,126)}}),
	spur_binding("anchor_061","route_019","station:elandor_frostbarrow_shelf:hub","route_019:endpoint_a",point(-2400,-1500),{{point(0,0),point(61,-146),point(50,-220)},{point(0,0),point(-27,-66),point(18,-204)},{point(0,0),point(13,-98),point(74,-244)}}),
	spur_binding("anchor_062","route_020","station:elandor_whitebridge_shire:hub","route_020:endpoint_b",point(-900,-1500),{{point(0,0),point(39,-74),point(150,-220)},{point(0,0),point(35,-78),point(118,-204)},{point(0,0),point(75,-110),point(174,-244)}}),
	spur_binding("anchor_063","route_022","station:elandor_lorindor:hub","route_022:endpoint_b",point(900,-1500),{{point(0,0),point(-99,-86),point(-150,-220)},{point(0,0),point(-103,-90),point(-182,-204)},{point(0,0),point(-63,-122),point(-126,-244)}}),
	spur_binding("anchor_064","route_025","station:kragmar_ossuary_reach:hub","route_025:endpoint_a",point(-2400,1500),{{point(0,0),point(13,122),point(50,220)},{point(0,0),point(9,118),point(18,236)},{point(0,0),point(49,86),point(74,196)}}),
	spur_binding("anchor_065","route_026","station:kragmar_speargrass_reach:hub","route_026:endpoint_b",point(-900,1500),{{point(0,0),point(75,110),point(150,220)},{point(0,0),point(71,106),point(118,236)},{point(0,0),point(111,74),point(174,196)}}),
	spur_binding("anchor_066","route_028","station:kragmar_whispering_reedlands:hub","route_028:endpoint_b",point(900,1500),{{point(0,0),point(-63,98),point(-150,220)},{point(0,0),point(-67,94),point(-182,236)},{point(0,0),point(-27,62),point(-126,196)}}),
	trail_spur_binding("anchor_049","route_001","station:elandor_copperfell_foothills:hub","route_001:endpoint_b",point(-1800,-2050),{{point(0,0),point(-108,5),point(-200,0)},{point(0,0),point(-113,18),point(-232,16)},{point(0,0),point(-99,-22),point(-176,-24)}}),
	trail_spur_binding("anchor_050","route_003","station:elandor_stormvault_heights:hub","route_003:endpoint_b",point(-1800,-700),{{point(0,0),point(-1,-142),point(0,-270)},{point(0,0),point(-6,-129),point(-32,-254)},{point(0,0),point(8,-144),point(24,-294)}}),
	trail_spur_binding("anchor_051","route_004","station:elandor_goldmead_vale:hub","route_004:endpoint_b",point(0,-2050),{{point(0,0),point(-154,-29),point(-320,-70)},{point(0,0),point(-184,-16),point(-352,-54)},{point(0,0),point(-145,-56),point(-296,-94)}}),
	trail_spur_binding("anchor_052","route_006","station:elandor_ashenward_march:hub","route_006:endpoint_b",point(0,-700),{{point(0,0),point(-12,-141),point(0,-270)},{point(0,0),point(-17,-128),point(-32,-254)},{point(0,0),point(22,-143),point(24,-294)}}),
	trail_spur_binding("anchor_053","route_007","station:elandor_starbough_vale:hub","route_007:endpoint_b",point(1800,-2050),{{point(0,0),point(95,7),point(200,0)},{point(0,0),point(90,20),point(168,16)},{point(0,0),point(104,-20),point(224,-24)}}),
	trail_spur_binding("anchor_054","route_009","station:elandor_glassroot_wilds:hub","route_009:endpoint_b",point(1800,-700),{{point(0,0),point(2,-140),point(0,-270)},{point(0,0),point(-28,-127),point(-32,-254)},{point(0,0),point(11,-142),point(24,-294)}}),
	trail_spur_binding("anchor_055","route_010","station:kragmar_mournfen:hub","route_010:endpoint_b",point(-1800,2050),{{point(0,0),point(-91,8),point(-200,0)},{point(0,0),point(-121,-4),point(-232,16)},{point(0,0),point(-82,-19),point(-176,-24)}}),
	trail_spur_binding("anchor_056","route_012","station:kragmar_blackwind_rise:hub","route_012:endpoint_b",point(-1800,700),{{point(0,0),point(-9,131),point(0,270)},{point(0,0),point(-14,144),point(-32,286)},{point(0,0),point(0,129),point(24,246)}}),
	trail_spur_binding("anchor_057","route_013","station:kragmar_redtusk_savanna:hub","route_013:endpoint_b",point(0,2050),{{point(0,0),point(-162,44),point(-320,70)},{point(0,0),point(-167,32),point(-352,86)},{point(0,0),point(-153,17),point(-296,46)}}),
	trail_spur_binding("anchor_058","route_015","station:kragmar_bannerbreak_mesa:hub","route_015:endpoint_b",point(0,700),{{point(0,0),point(5,132),point(0,270)},{point(0,0),point(-25,145),point(-32,286)},{point(0,0),point(14,130),point(24,246)}}),
	trail_spur_binding("anchor_059","route_016","station:kragmar_raincall_basin:hub","route_016:endpoint_b",point(1800,2050),{{point(0,0),point(112,10),point(200,0)},{point(0,0),point(82,-2),point(168,16)},{point(0,0),point(121,-17),point(224,-24)}}),
	trail_spur_binding("anchor_060","route_018","station:kragmar_thunderroot_wilds:hub","route_018:endpoint_b",point(1800,700),{{point(0,0),point(-6,133),point(0,270)},{point(0,0),point(-11,146),point(-32,286)},{point(0,0),point(3,131),point(24,246)}}),
	trail_spur_binding("anchor_067","route_020","station:elandor_whitebridge_shire:hub","route_020:endpoint_b",point(-900,-1500),{{point(0,0),point(-147,119),point(-280,260)},{point(0,0),point(-152,132),point(-312,276)},{point(0,0),point(-138,117),point(-256,236)}}),
	trail_spur_binding("anchor_068","route_022","station:elandor_lorindor:hub","route_022:endpoint_b",point(900,-1500),{{point(0,0),point(-110,122),point(-220,240)},{point(0,0),point(-115,135),point(-252,256)},{point(0,0),point(-101,120),point(-196,216)}}),
	trail_spur_binding("anchor_069","route_010","station:kragmar_mournfen:hub","route_010:endpoint_b",point(-1800,2050),{{point(0,0),point(132,-110),point(250,-200)},{point(0,0),point(102,-97),point(218,-184)},{point(0,0),point(141,-112),point(274,-224)}}),
	trail_spur_binding("anchor_070","route_028","station:kragmar_whispering_reedlands:hub","route_028:endpoint_b",point(900,1500),{{point(0,0),point(-121,-117),point(-220,-240)},{point(0,0),point(-126,-104),point(-252,-224)},{point(0,0),point(-87,-144),point(-196,-264)}}),
	trail_spur_binding("anchor_071","route_006","station:elandor_ashenward_march:hub","route_006:endpoint_b",point(0,-700),{{point(0,0),point(121,-199),point(250,-380)},{point(0,0),point(116,-186),point(218,-364)},{point(0,0),point(130,-201),point(274,-404)}}),
	trail_spur_binding("anchor_072","route_006","station:elandor_ashenward_march:hub","route_006:endpoint_b",point(0,-700),{{point(0,0),point(-122,-186),point(-250,-380)},{point(0,0),point(-152,-173),point(-282,-364)},{point(0,0),point(-113,-213),point(-226,-404)}}),
	trail_spur_binding("anchor_073","route_015","station:kragmar_bannerbreak_mesa:hub","route_015:endpoint_b",point(0,700),{{point(0,0),point(135,182),point(250,380)},{point(0,0),point(105,195),point(218,396)},{point(0,0),point(144,180),point(274,356)}}),
	trail_spur_binding("anchor_074","route_015","station:kragmar_bannerbreak_mesa:hub","route_015:endpoint_b",point(0,700),{{point(0,0),point(-133,195),point(-250,380)},{point(0,0),point(-138,208),point(-282,396)},{point(0,0),point(-124,168),point(-226,356)}}),
	trail_spur_binding("anchor_075","island_route_wyrmglass_north_junction","island_station_wyrmglass_north","island_route_wyrmglass_north_junction:from",point(-2890,125),{{point(0,0),point(49,-17),point(110,-45)},{point(0,0),point(42,-8),point(78,-29)},{point(0,0),point(61,-39),point(134,-69)}}),
	trail_spur_binding("anchor_076","route_043","station:front_gravesalt_escarpment:hub","route_043:endpoint_b",point(-2000,0),{{point(0,0),point(106,46),point(200,80)},{point(0,0),point(76,59),point(168,96)},{point(0,0),point(115,19),point(224,56)}}),
	trail_spur_binding("anchor_077","route_043","station:front_gravesalt_escarpment:hub","route_043:endpoint_b",point(-2000,0),{{point(0,0),point(-112,-46),point(-200,-80)},{point(0,0),point(-117,-33),point(-232,-64)},{point(0,0),point(-78,-48),point(-176,-104)}}),
	trail_spur_binding("anchor_078","route_044","station:front_broken_causeway:hub","route_044:endpoint_b",point(-750,0),{{point(0,0),point(245,57),point(500,100)},{point(0,0),point(240,70),point(468,116)},{point(0,0),point(254,30),point(524,76)}}),
	trail_spur_binding("anchor_079","route_044","station:front_broken_causeway:hub","route_044:endpoint_b",point(-750,0),{{point(0,0),point(2,-55),point(0,-100)},{point(0,0),point(-28,-42),point(-32,-84)},{point(0,0),point(11,-57),point(24,-124)}}),
	trail_spur_binding("anchor_080","route_044","station:front_broken_causeway:hub","route_044:endpoint_b",point(-750,0),{{point(0,0),point(-241,58),point(-500,100)},{point(0,0),point(-271,46),point(-532,116)},{point(0,0),point(-232,31),point(-476,76)}}),
	trail_spur_binding("anchor_081","route_046","station:front_shattered_line:hub","route_046:endpoint_b",point(750,0),{{point(0,0),point(241,-54),point(500,-100)},{point(0,0),point(236,-41),point(468,-84)},{point(0,0),point(250,-56),point(524,-124)}}),
	trail_spur_binding("anchor_082","route_046","station:front_shattered_line:hub","route_046:endpoint_b",point(750,0),{{point(0,0),point(-2,59),point(0,100)},{point(0,0),point(-7,47),point(-32,116)},{point(0,0),point(7,32),point(24,76)}}),
	trail_spur_binding("anchor_083","route_046","station:front_shattered_line:hub","route_046:endpoint_b",point(750,0),{{point(0,0),point(-245,-53),point(-500,-100)},{point(0,0),point(-275,-40),point(-532,-84)},{point(0,0),point(-236,-55),point(-476,-124)}}),
	trail_spur_binding("anchor_084","route_048","station:front_skyglass_canopy:hub","route_048:endpoint_b",point(2000,0),{{point(0,0),point(112,50),point(200,80)},{point(0,0),point(82,38),point(168,96)},{point(0,0),point(121,23),point(224,56)}}),
	trail_spur_binding("anchor_085","route_048","station:front_skyglass_canopy:hub","route_048:endpoint_b",point(2000,0),{{point(0,0),point(-106,-42),point(-200,-80)},{point(0,0),point(-111,-29),point(-232,-64)},{point(0,0),point(-97,-44),point(-176,-104)}}),
	trail_spur_binding("anchor_086","island_route_stormscale_north_junction","island_station_stormscale_north","island_route_stormscale_north_junction:from",point(2900,125),{{point(0,0),point(-44,-18),point(-100,-45)},{point(0,0),point(-72,-7),point(-132,-29)},{point(0,0),point(-35,-40),point(-76,-69)}}),
}

source.templates = {
	{id="start", shape="flat", fitting_width=128, blend_width=256, max_cut=8, max_fill=8, force_native_dungeon=false},
	{id="capital_dwarf", shape="granite_terrace", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_human", shape="river_plateau", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_elf", shape="terraced_grove", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_undead", shape="raised_necropolis", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_orc", shape="mesa_shelf", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_troll", shape="cenote_terrace", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="village", shape="gentle_grade", fitting_width=96, blend_width=160, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="outpost", shape="gentle_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="bandit_home", shape="gentle_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="bandit_frontier", shape="gentle_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="mine", shape="gentle_grade", fitting_width=80, blend_width=128, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="mirefolk", shape="shallow_marsh_island", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="clash", shape="battlefield_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="dragon", shape="arena_terrace", fitting_width=96, blend_width=160, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="apex_mine", shape="mine_terrace", fitting_width=96, blend_width=160, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="rare_route", shape="patrol_route", fitting_width=32, blend_width=64, max_cut=3, max_fill=2, force_native_dungeon=false},
}

source.template_compositions = {
	{id="compose_start",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}}}},
	{id="compose_capital_dwarf",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=256,shoulder_width=96}},{op="overlay",primitive_id="terrace",parameters={step_height=4,step_run=48,rings=5}}}},
	{id="compose_capital_human",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=240,shoulder_width=112}},{op="overlay",primitive_id="tilt",parameters={axis_x=0,axis_z=1,rise=2,run=352}}}},
	{id="compose_capital_elf",version=1,operations={{op="apply",primitive_id="terrace",parameters={step_height=3,step_run=56,rings=5}}}},
	{id="compose_capital_undead",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=240,shoulder_width=112}},{op="overlay",primitive_id="terrace",parameters={step_height=3,step_run=48,rings=5}}}},
	{id="compose_capital_orc",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=256,shoulder_width=96}},{op="overlay",primitive_id="rim",parameters={inner_radius=208,peak_radius=232,outer_radius=256,height=8}}}},
	{id="compose_capital_troll",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=256,shoulder_width=96}},{op="subtract",primitive_id="basin",parameters={inner_radius=72,depth=12,rim_width=24}}}},
	{id="compose_village",version=1,operations={{op="apply",primitive_id="tilt",parameters={axis_x=1,axis_z=0,rise=1,run=96}}}},
	{id="compose_outpost",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}}}},
	{id="compose_bandit_home",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}}}},
	{id="compose_bandit_frontier",version=1,operations={{op="apply",primitive_id="tilt",parameters={axis_x=0,axis_z=1,rise=1,run=64}}}},
	{id="compose_mine",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=32,shoulder_width=24}}}},
	{id="compose_mirefolk",version=1,operations={{op="apply",primitive_id="causeway",axis_source="selected_candidate_trail_spur_endpoint_tangent",parameters={surface_width=32,backing_depth=3}}}},
	{id="compose_clash",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}},{op="overlay",primitive_id="cross_section",axis_source="selected_candidate_trail_spur_endpoint_tangent",parameters={surface_width=32,corridor_width=48}}}},
	{id="compose_dragon",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=48,shoulder_width=32}},{op="overlay",primitive_id="rim",parameters={inner_radius=36,peak_radius=42,outer_radius=48,height=4}}}},
	{id="compose_apex_mine",version=1,operations={{op="apply",primitive_id="terrace",parameters={step_height=2,step_run=16,rings=4}}}},
	{id="compose_rare_route",version=1,operations={{op="apply",primitive_id="cross_section",axis_source="selected_candidate_patrol_first_segment_tangent",parameters={surface_width=3,corridor_width=8}}}},
	{id="compose_coastal_housing_core",version=1,operations={{op="apply",primitive_id="housing_smoothing",parameters={radius=50,relief_limit=12}}}},
}
for template_index=1,#source.templates do
	source.templates[template_index].composition_id="compose_"..source.templates[template_index].id
end

source.hydrology_profiles = {
	{id="dry_channel",depth=0,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=8,mask_semantic_id="hydro_dry_channel_v1"},
	{id="ford",depth=1,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=8,mask_semantic_id="hydro_ford_v1"},
	{id="shallow_marsh",depth=1,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=8,mask_semantic_id="hydro_shallow_marsh_v1"},
	{id="stream",depth=2,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=8,mask_semantic_id="hydro_stream_v1"},
	{id="spring",depth=2,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=8,mask_semantic_id="hydro_spring_v1"},
	{id="shallow_pond",depth=2,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=8,mask_semantic_id="hydro_shallow_pond_v1"},
	{id="river",depth=4,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=12,mask_semantic_id="hydro_river_v1"},
	{id="delta_arm",depth=4,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=12,mask_semantic_id="hydro_delta_arm_v1"},
	{id="ordinary_lake",depth=8,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=16,mask_semantic_id="hydro_ordinary_lake_v1"},
	{id="plunge_pool",depth=12,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=16,mask_semantic_id="hydro_plunge_pool_v1"},
	{id="deep_cenote",depth=12,bed_seal_layers=3,bank_seal_nodes=2,
		bank_blend_width=16,mask_semantic_id="hydro_deep_cenote_v1"},
}

source.hydrology_transition_profiles = {
	{id="river_confluence_exact",kind="confluence",run=0,drop=0,
		open_face="outgoing_reach",seal_semantic_id="hydro_confluence_seal_v1"},
	{id="bridge_clearance",kind="bridge",run=12,drop=0,
		vertical_rule_id="bridge_clearance_v1",minimum_clearance_nodes=3,
		open_face="bridge_lumen",seal_semantic_id="hydro_bridge_seal_v1"},
	{id="ford_bed",kind="ford",run=12,drop=0,
		vertical_rule_id="ford_bed_v1",road_y_offset_from_bed=0,
		open_face="water_surface",seal_semantic_id="hydro_ford_seal_v1"},
	{id="rapid_drop",kind="rapid",run=1,drop=1,
		open_face="downstream",seal_semantic_id="hydro_rapid_seal_v1"},
	{id="waterfall_drop",kind="waterfall",run=1,drop=1,
		open_face="fall_face",seal_semantic_id="hydro_waterfall_seal_v1"},
	{id="causeway_deck",kind="causeway",run=12,drop=0,
		vertical_rule_id="causeway_culvert_v1",deck_y_offset_from_W=1,
		open_face="water_surface",seal_semantic_id="hydro_causeway_seal_v1"},
}

local function hydro(id,landmark_id,zone_id,profile_id,offset,centreline,
		from_id,to_id)
	return {id=id,landmark_id=landmark_id,zone_id=zone_id,
		profile_id=profile_id,water_surface_reference="mapgen_water_level",
		water_surface_offset=offset,centreline=centreline,from_id=from_id,
		to_id=to_id,water_node_semantic="surface_water"}
end

-- Every reach is authored explicitly. In particular, crossings below are
-- vertices of their referenced reach; no compiler may synthesize or widen a
-- generic landmark-centred line to make an interface fit.
source.hydrology = {
	hydro("hydro_copperfell_streams","copperfell_drainage","elandor_copperfell_foothills","stream",18,{{x=-2114,z=-2050,half_width=12},{x=-1986,z=-2050,half_width=12}},"copperfell_spring","copperfell_sink"),
	hydro("hydro_frostbarrow_tarns","frostbarrow_tarns","elandor_frostbarrow_shelf","shallow_pond",62,{{x=-2414,z=-1740,half_width=12},{x=-2286,z=-1740,half_width=12}},"frostbarrow_inflow","frostbarrow_basin"),
	hydro("hydro_dawnmere_headwaters","dawnmere_headwaters","elandor_dawnmere_fields","spring",12,{{x=-64,z=-2500,half_width=12},{x=64,z=-2500,half_width=12}},"dawnmere_spring","dawnmere_outflow"),
	hydro("hydro_goldmead_millriver","goldmead_millriver","elandor_goldmead_vale","river",16,{{x=-64,z=-2020,half_width=12},{x=64,z=-2020,half_width=12}},"goldmead_upstream","goldmead_downstream"),
	hydro("hydro_highcourt_fork_west","highcourt_riverfork","elandor_highcourt","river",34,{{x=-300,z=-1750,half_width=18},{x=-120,z=-1550,half_width=22},{x=0,z=-1320,half_width=18}},"highcourt_west_source","highcourt_fork_join"),
	hydro("hydro_highcourt_fork_east","highcourt_riverfork","elandor_highcourt","river",34,{{x=300,z=-1750,half_width=16},{x=140,z=-1510,half_width=20},{x=0,z=-1320,half_width=18}},"highcourt_east_source","highcourt_fork_join"),
	hydro("hydro_highcourt_outflow","highcourt_riverfork","elandor_highcourt","river",34,{{x=0,z=-1320,half_width=18},{x=0,z=-1180,half_width=18}},"highcourt_fork_join","highcourt_outflow"),
	hydro("hydro_whitebridge_main","whitebridge_crossing","elandor_whitebridge_shire","river",16,{{x=-964,z=-1500,half_width=12},{x=-700,z=-1500,half_width=12},{x=-400,z=-1500,half_width=12}},"whitebridge_upstream","whitebridge_downstream"),
	hydro("hydro_whitebridge_ford","whitebridge_ford","elandor_whitebridge_shire","ford",16,{{x=-900,z=-1100,half_width=12},{x=-820,z=-1180,half_width=12},{x=-720,z=-1260,half_width=12}},"whitebridge_ford_upstream","whitebridge_ford_downstream"),
	hydro("hydro_lethariel_lake","lethariel_crownlake","elandor_lethariel","ordinary_lake",34,{{x=1736,z=-1500,half_width=12},{x=1864,z=-1500,half_width=12}},"lethariel_inflow","lethariel_outflow"),
	hydro("hydro_lorindor_marsh","lorindor_berrymarsh","elandor_lorindor","shallow_marsh",28,{{x=1016,z=-1740,half_width=12},{x=1144,z=-1740,half_width=12}},"lorindor_inflow","lorindor_sink"),
	hydro("hydro_moonfall_lake","moonfall_crescent","elandor_moonfall_wood","ordinary_lake",18,{{x=2336,z=-1500,half_width=12},{x=2464,z=-1500,half_width=12}},"moonfall_inflow","moonfall_outflow"),
	hydro("hydro_mournfen_marsh","mournfen_drowned_roads","kragmar_mournfen","shallow_marsh",8,{{x=-2114,z=2100,half_width=12},{x=-1986,z=2100,half_width=12}},"mournfen_inflow","mournfen_sink"),
	hydro("hydro_sunscar_waterholes","sunscar_waterholes","kragmar_sunscar_flats","shallow_pond",12,{{x=196,z=2450,half_width=12},{x=324,z=2450,half_width=12}},"sunscar_seep","sunscar_basin"),
	hydro("hydro_speargrass_dryriver","speargrass_dryriver","kragmar_speargrass_reach","dry_channel",28,{{x=-964,z=1500,half_width=12},{x=-836,z=1500,half_width=12}},"speargrass_dry_head","speargrass_dry_mouth"),
	hydro("hydro_raincall_headwater","raincall_falls","kragmar_raincall_basin","shallow_pond",72,{{x=1900,z=2200,half_width=24},{x=1960,z=2140,half_width=26}},"raincall_headwater","raincall_upper_rapid"),
	hydro("hydro_raincall_upper_lip","raincall_falls","kragmar_raincall_basin","shallow_pond",68,{{x=1960,z=2140,half_width=26},{x=1990,z=2110,half_width=28}},"raincall_upper_rapid","raincall_upper_lip"),
	hydro("hydro_raincall_middle_upper","raincall_falls","kragmar_raincall_basin","shallow_pond",56,{{x=1990,z=2070,half_width=24},{x=2020,z=2040,half_width=26}},"raincall_upper_drop","raincall_middle_rapid"),
	hydro("hydro_raincall_middle_lip","raincall_falls","kragmar_raincall_basin","shallow_pond",52,{{x=2020,z=2040,half_width=26},{x=2050,z=2010,half_width=28}},"raincall_middle_rapid","raincall_lower_lip"),
	hydro("hydro_raincall_plunge","raincall_falls","kragmar_raincall_basin","plunge_pool",44,{{x=2050,z=1970,half_width=30},{x=2130,z=1900,half_width=34}},"raincall_lower_drop","raincall_outflow"),
	hydro("hydro_kezamba_cenote","kezamba_cenote","kragmar_kezamba","deep_cenote",64,{{x=1736,z=1500,half_width=12},{x=1864,z=1500,half_width=12}},"kezamba_inflow","kezamba_cenote_sink"),
	hydro("hydro_whispering_reedmaze","whispering_reedmaze","kragmar_whispering_reedlands","shallow_marsh",8,{{x=836,z=1500,half_width=12},{x=964,z=1500,half_width=12}},"reedmaze_inflow","reedmaze_outflow"),
	hydro("hydro_totemwater_delta","totemwater_delta","kragmar_totemwater_reach","delta_arm",8,{{x=2336,z=1500,half_width=12},{x=2464,z=1500,half_width=12}},"totemwater_upstream","totemwater_mouth"),
	hydro("hydro_gravesalt_pans","gravesalt_whitewall","front_gravesalt_escarpment","shallow_marsh",100,{{x=-2114,z=0,half_width=12},{x=-1986,z=0,half_width=12}},"gravesalt_seep","gravesalt_pan"),
	hydro("hydro_broken_marsh","broken_marsh","front_broken_causeway","ordinary_lake",8,{{x=-1125,z=250,half_width=12},{x=-1500,z=-125,half_width=12},{x=-750,z=-100,half_width=12},{x=-375,z=-250,half_width=12}},"broken_marsh_inflow","broken_marsh_outflow"),
}

source.hydrology_interfaces = {
	{id="highcourt_fork_join",kind="confluence",
		from_ids={"hydro_highcourt_fork_west","hydro_highcourt_fork_east"},
		outgoing_reach_id="hydro_highcourt_outflow",position=point(0,-1320),
		transition_profile_id="river_confluence_exact",sealed=true},
	{id="whitebridge_bridge_water",kind="bridge",hydrology_id="hydro_whitebridge_main",route_interface_id="whitebridge_bridge",position=point(-400,-1500),transition_profile_id="bridge_clearance",sealed=true},
	{id="whitebridge_ford_water",kind="ford",hydrology_id="hydro_whitebridge_ford",route_interface_id="whitebridge_ford",position=point(-900,-1100),transition_profile_id="ford_bed",sealed=true},
	{id="raincall_upper_rapid",kind="rapid",
		upper_id="hydro_raincall_headwater",lower_id="hydro_raincall_upper_lip",
		upper_level_offset=72,lower_level_offset=68,position=point(1960,2140),
		transition_profile_id="rapid_drop",run=48,drop=4,width=12,
		bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="raincall_upper_fall",kind="waterfall",
		upper_id="hydro_raincall_upper_lip",lower_id="hydro_raincall_middle_upper",
		upper_level_offset=68,lower_level_offset=56,position=point(1990,2090),
		lip_id="raincall_upper_lip",drop_id="raincall_upper_drop",
		plunge_id="raincall_upper_plunge",transition_profile_id="waterfall_drop",
		drop=12,drop_height=12,drop_mask_width=10,drop_mask_length=40,
		plunge_profile_id="shallow_pond",plunge_width=48,plunge_length=40,
		bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="raincall_middle_rapid",kind="rapid",
		upper_id="hydro_raincall_middle_upper",lower_id="hydro_raincall_middle_lip",
		upper_level_offset=56,lower_level_offset=52,position=point(2020,2040),
		transition_profile_id="rapid_drop",run=40,drop=4,width=12,
		bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="raincall_lower_fall",kind="waterfall",
		upper_id="hydro_raincall_middle_lip",lower_id="hydro_raincall_plunge",
		upper_level_offset=52,lower_level_offset=44,position=point(2050,1990),
		lip_id="raincall_lower_lip",drop_id="raincall_lower_drop",
		plunge_id="raincall_lower_plunge",transition_profile_id="waterfall_drop",
		drop=8,drop_height=8,drop_mask_width=12,drop_mask_length=40,
		plunge_profile_id="plunge_pool",plunge_width=60,plunge_length=48,
		bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="broken_causeway_water",kind="causeway",hydrology_id="hydro_broken_marsh",route_interface_id="broken_causeway",position=point(-375,-250),transition_profile_id="causeway_deck",sealed=true},
	{id="broken_ford_water",kind="ford",hydrology_id="hydro_broken_marsh",route_interface_id="broken_ford",position=point(-1125,250),transition_profile_id="ford_bed",sealed=true},
	{id="broken_aqueduct_water",kind="bridge",hydrology_id="hydro_broken_marsh",route_interface_id="broken_aqueduct",position=point(-1500,-125),transition_profile_id="bridge_clearance",sealed=true},
}

-- Active hard protection is deliberately tiny and exact. Holy Grounds is a
-- separate 3D territory policy, and every present route crossing declares
-- hard_protected=false above. Pending future content is recorded below but is
-- never copied into this active family.
source.hard_protection_recipes = {
	{id="hard_capital_build_plus_apron_v1",shape="centered_half_open_square",
		footprint_policy_id="centered_half_open_square_v1",total_width=532,
		y_policy_id="shallow_land_upward_to_world_top",y_min=-700,
		upward_unbounded=true},
	{id="hard_start_core_v1",shape="centered_half_open_square",
		footprint_policy_id="centered_half_open_square_v1",total_width=128,
		y_policy_id="shallow_land_upward_to_world_top",y_min=-700,
		upward_unbounded=true},
	{id="hard_apex_socket_column_v1",shape="exact_column",
		footprint_policy_id="exact_column_v1",column_count=1,
		y_policy_id="shallow_land_upward_to_world_top",y_min=-700,
		upward_unbounded=true},
}
source.hard_protection = {}
for anchor_index = 1, 12 do
	local anchor = source.anchors[anchor_index]
	local capital = anchor.slot_id == "capital"
	source.hard_protection[#source.hard_protection + 1] = {
		id = "hard:" .. anchor.id, source_anchor_id = anchor.id,
		recipe_id = capital and "hard_capital_build_plus_apron_v1" or
			"hard_start_core_v1",
		center = point(anchor.position.x, anchor.position.z), active = true,
		activation_owner = "WP40", status = "active",
	}
end
for _, anchor_index in ipairs({89,90}) do local anchor=source.anchors[anchor_index]
	for socket_index=1,#anchor.socket_reservations do local socket=anchor.socket_reservations[socket_index]
		source.hard_protection[#source.hard_protection+1]={
			id="hard:"..socket.id,source_anchor_id=anchor.id,
			socket_reservation_id=socket.id,resource_key=socket.resource_key,
			recipe_id="hard_apex_socket_column_v1",
			center=point(socket.position.x,socket.position.z),active=true,
			activation_owner="WP40",status="active"}
	end
end

source.pending_static_recipes = {
	{id="pending_wp13_functional_anchor_v1",activation_owner="WP13",
		status="pending",geometry_authority="activation_owner"},
	{id="pending_wp17_navigation_v1",activation_owner="WP17",
		status="pending",geometry_authority="activation_owner"},
	{id="pending_wp34_refill_v1",activation_owner="WP34",
		status="pending",geometry_authority="activation_owner"},
}
source.pending_static_reservations = {}
for _, anchor_index in ipairs({61,62,63,64,65,66,89,90}) do
	local anchor=source.anchors[anchor_index]
	local containment_ids={"exclude:anchor:" .. anchor.id .. ":01"}
	if anchor.placement_mode=="candidate_set" then
		containment_ids={"exclude:anchor:"..anchor.id..":01",
			"exclude:anchor:"..anchor.id..":02","exclude:anchor:"..anchor.id..":03"}
	end
	source.pending_static_reservations[#source.pending_static_reservations + 1] = {
		id = "pending:wp13:functional:" .. anchor.id,
		recipe_id = "pending_wp13_functional_anchor_v1", anchor_id = anchor.id,
		containment_exclusion_ids = containment_ids,
		reservation_kind = "mining_camp_functional_anchor", activation_owner = "WP13",
		status = "pending", active = false,
	}
end
for anchor_index = 1, 12 do
	local anchor = source.anchors[anchor_index]
	for _, kind in ipairs({"waypoint","graveyard","quest_platform","sightline"}) do
			source.pending_static_reservations[#source.pending_static_reservations + 1] = {
			id = "pending:wp17:" .. kind .. ":" .. anchor.id,
				recipe_id = "pending_wp17_navigation_v1", anchor_id = anchor.id,
				containment_exclusion_ids = {"exclude:anchor:" .. anchor.id .. ":01"},
			reservation_kind = kind, activation_owner = "WP17",
			status = "pending", active = false,
		}
	end
end
for anchor_index = 61, 66 do
	local anchor = source.anchors[anchor_index]
	source.pending_static_reservations[#source.pending_static_reservations + 1] = {
		id = "pending:wp34:refill:" .. anchor.id,
		recipe_id = "pending_wp34_refill_v1", anchor_id = anchor.id,
		containment_exclusion_ids = {"exclude:anchor:"..anchor.id..":01",
			"exclude:anchor:"..anchor.id..":02","exclude:anchor:"..anchor.id..":03"},
		reservation_kind = "renewable_refill", activation_owner = "WP34",
		status = "pending", active = false,
	}
end
for _, anchor_index in ipairs({89,90}) do
	local anchor = source.anchors[anchor_index]
	for socket_index = 1, #anchor.socket_reservations do
		local socket = anchor.socket_reservations[socket_index]
		source.pending_static_reservations[#source.pending_static_reservations + 1] = {
			id = "pending:wp34:refill:" .. socket.id,
			recipe_id = "pending_wp34_refill_v1", anchor_id = anchor.id,
			socket_reservation_id = socket.id,
			containment_exclusion_ids = {"exclude:active:hard:" .. socket.id},
			reservation_kind = "renewable_socket_refill",
			activation_owner = "WP34", status = "pending", active = false,
		}
	end
end

source.claim_exclusion_recipes = {
	{id="exclude_anchor_blend_v1",kind="anchor_blend_envelope",
		footprint_policy_id="centered_half_open_square_v1"},
	{id="exclude_route_corridor_v1",kind="route_corridor",
		footprint_policy_id="route_class_corridor_v1"},
	{id="exclude_planned_water_v1",kind="planned_water",
		footprint_policy_id="analytic_water_mask_v1"},
	{id="exclude_coast_v1",kind="coast",
		footprint_policy_id="analytic_coast_mask_v1"},
	{id="exclude_boundary_v1",kind="boundary",
		footprint_policy_id="shared_boundary_buffer_v1"},
	{id="exclude_active_core_v1",kind="active_core",
		footprint_policy_id="active_hard_footprint_v1"},
}

local template_by_id = {}
for template_index = 1, #source.templates do
	template_by_id[source.templates[template_index].id] = source.templates[template_index]
end
source.claim_exclusions = {}
local function add_exclusion(row)
	source.claim_exclusions[#source.claim_exclusions + 1] = row
end
for anchor_index = 1, #source.anchors do
	local anchor = source.anchors[anchor_index]
	local template = template_by_id[anchor.template_id]
	local candidates = anchor.placement_mode == "fixed" and {anchor.position} or
		anchor.candidates
	for candidate_index = 1, #candidates do
		add_exclusion({id=("exclude:anchor:%s:%02d"):format(anchor.id,candidate_index),
			recipe_id="exclude_anchor_blend_v1",source_id=anchor.id,
			candidate_index=candidate_index,center=point(candidates[candidate_index].x,
				candidates[candidate_index].z),total_width=template.blend_width,
			coverage="complete_fitting_plus_blend_envelope"})
	end
end
for route_index = 1, #source.routes do
	local route = source.routes[route_index]
	local class = source.route_classes[route.class == "primary" and 1 or
		(route.class == "secondary" and 2 or 3)]
	add_exclusion({id="exclude:route:"..route.id,
		recipe_id="exclude_route_corridor_v1",source_id=route.id,
		corridor_width=class.exclusion_width,coverage="complete_centreline"})
end
for route_index = 1, #source.island_routes do
	local route = source.island_routes[route_index]
	add_exclusion({id="exclude:route:"..route.id,
		recipe_id="exclude_route_corridor_v1",source_id=route.id,
		corridor_width=12,coverage="complete_centreline"})
end
for spur_index = 1, #source.poi_spurs do
	local spur = source.poi_spurs[spur_index]
	add_exclusion({id="exclude:route:"..spur.id,
		recipe_id="exclude_route_corridor_v1",source_id=spur.id,
		corridor_width=spur.class=="trail" and 8 or 12,
		coverage="candidate_path_and_fixed_terminal"})
end
for hydro_index = 1, #source.hydrology do
	add_exclusion({id="exclude:water:"..source.hydrology[hydro_index].id,
		recipe_id="exclude_planned_water_v1",
		source_id=source.hydrology[hydro_index].id,coverage="complete_analytic_mask"})
end
for bay_index = 1, #source.bays do
	add_exclusion({id="exclude:water:"..source.bays[bay_index].id,
		recipe_id="exclude_planned_water_v1",source_id=source.bays[bay_index].id,
		coverage="complete_analytic_mask"})
end
for _, collection in ipairs({source.perimeters,source.islands,source.channels}) do
	for record_index = 1, #collection do
		add_exclusion({id="exclude:coast:"..collection[record_index].id,
			recipe_id="exclude_coast_v1",source_id=collection[record_index].id,
			coverage="coast_water_and_projection"})
	end
end
for edge_index = 1, #source.land_edges do
	add_exclusion({id="exclude:boundary:"..source.land_edges[edge_index].id,
		recipe_id="exclude_boundary_v1",source_id=source.land_edges[edge_index].id,
		coverage="complete_shared_boundary_buffer"})
end
for hard_index = 1, #source.hard_protection do
	add_exclusion({id="exclude:active:"..source.hard_protection[hard_index].id,
		recipe_id="exclude_active_core_v1",
		source_id=source.hard_protection[hard_index].id,
		coverage="exact_active_hard_footprint"})
end

source.housing_masks = {
	{id="housing_elandor_copperfell",zone_id="elandor_copperfell_foothills",primitive="polygon",orientation="counterclockwise",polygon={point(-2520,-2470),point(-2220,-2470),point(-2180,-1930),point(-2520,-1930),point(-2520,-2470)}},
	{id="housing_elandor_goldmead",zone_id="elandor_goldmead_vale",primitive="polygon",orientation="counterclockwise",polygon={point(-600,-2260),point(600,-2260),point(560,-1910),point(-560,-1910),point(-600,-2260)}},
	{id="housing_elandor_starbough",zone_id="elandor_starbough_vale",primitive="polygon",orientation="counterclockwise",polygon={point(2220,-2470),point(2520,-2470),point(2520,-1930),point(2180,-1930),point(2220,-2470)}},
	{id="housing_elandor_whitebridge",zone_id="elandor_whitebridge_shire",primitive="polygon",orientation="counterclockwise",polygon={point(-1360,-1860),point(-440,-1860),point(-440,-1140),point(-1360,-1140),point(-1360,-1860)}},
	{id="housing_elandor_lorindor",zone_id="elandor_lorindor",primitive="polygon",orientation="counterclockwise",polygon={point(440,-1860),point(1360,-1860),point(1360,-1140),point(440,-1140),point(440,-1860)}},
	{id="housing_kragmar_mournfen",zone_id="kragmar_mournfen",primitive="polygon",orientation="counterclockwise",polygon={point(-2520,1930),point(-2180,1930),point(-2220,2470),point(-2520,2470),point(-2520,1930)}},
	{id="housing_kragmar_redtusk",zone_id="kragmar_redtusk_savanna",primitive="polygon",orientation="counterclockwise",polygon={point(-560,1910),point(560,1910),point(600,2260),point(-600,2260),point(-560,1910)}},
	{id="housing_kragmar_raincall",zone_id="kragmar_raincall_basin",primitive="polygon",orientation="counterclockwise",polygon={point(2180,1930),point(2520,1930),point(2520,2470),point(2220,2470),point(2180,1930)}},
	{id="housing_kragmar_speargrass",zone_id="kragmar_speargrass_reach",primitive="polygon",orientation="counterclockwise",polygon={point(-1360,1140),point(-440,1140),point(-440,1860),point(-1360,1860),point(-1360,1140)}},
	{id="housing_kragmar_whispering",zone_id="kragmar_whispering_reedlands",primitive="polygon",orientation="counterclockwise",polygon={point(440,1140),point(1360,1140),point(1360,1860),point(440,1860),point(440,1140)}},
}

source.coastal_housing_cores = {
	{id="coastal_core_copperfell",zone_id="elandor_copperfell_foothills",housing_mask_id="housing_elandor_copperfell",composition_id="compose_coastal_housing_core",policy_id="displaced_coast_interval_inward_core_v1",perimeter_span_id="perimeter_span:elandor:copperfell",start_segment=1,end_segment=3,direction="forward",inward_side="left",frontage_min=600,inland_depth_min=300,relief_max=12},
	{id="coastal_core_starbough",zone_id="elandor_starbough_vale",housing_mask_id="housing_elandor_starbough",composition_id="compose_coastal_housing_core",policy_id="displaced_coast_interval_inward_core_v1",perimeter_span_id="perimeter_span:elandor:starbough",start_segment=2,end_segment=4,direction="forward",inward_side="left",frontage_min=600,inland_depth_min=300,relief_max=12},
	{id="coastal_core_mournfen",zone_id="kragmar_mournfen",housing_mask_id="housing_kragmar_mournfen",composition_id="compose_coastal_housing_core",policy_id="displaced_coast_interval_inward_core_v1",perimeter_span_id="perimeter_span:kragmar:mournfen",start_segment=2,end_segment=4,direction="forward",inward_side="left",frontage_min=600,inland_depth_min=300,relief_max=12},
	{id="coastal_core_raincall",zone_id="kragmar_raincall_basin",housing_mask_id="housing_kragmar_raincall",composition_id="compose_coastal_housing_core",policy_id="displaced_coast_interval_inward_core_v1",perimeter_span_id="perimeter_span:kragmar:raincall",start_segment=1,end_segment=3,direction="forward",inward_side="left",frontage_min=600,inland_depth_min=300,relief_max=12},
}

source.semantics = {
	semantic_water_node = "surface_water",
	footprint_policy_ids = {"centered_half_open_square_v1","exact_column_v1",
		"route_class_corridor_v1","analytic_water_mask_v1",
		"analytic_coast_mask_v1","shared_boundary_buffer_v1",
		"active_hard_footprint_v1"},
	relief_ids = {"wetland_delta","lowland","rolling_hills","plateau",
		"highland","mountain"},
	template_shape_ids = {"flat","granite_terrace","river_plateau",
		"terraced_grove","raised_necropolis","mesa_shelf","cenote_terrace",
		"gentle_grade","shallow_marsh_island","battlefield_grade",
		"arena_terrace","mine_terrace","patrol_route"},
	route_semantic_ids = {"road_primary_v1","road_secondary_v1",
		"road_trail_v1","road_climb_stair_v1"},
	water_class_ids = {"land","planned_water","coastal_shelf","deep_ocean",
		"immutable_dragon_channel"},
	hydrology_profile_ids = {"dry_channel","ford","shallow_marsh","stream",
		"spring","shallow_pond","river","delta_arm","ordinary_lake",
		"plunge_pool","deep_cenote"},
	protection_recipe_ids = {"hard_capital_build_plus_apron_v1",
		"hard_start_core_v1","hard_apex_socket_column_v1"},
	exclusion_recipe_ids = {"exclude_anchor_blend_v1",
		"exclude_route_corridor_v1","exclude_planned_water_v1",
		"exclude_coast_v1","exclude_boundary_v1","exclude_active_core_v1"},
	race_regions = {"dwarf","human","elf","undead","orc","troll"},
	regional_resource_keys = {"citrine","garnet","jade","diamond","sapphire","ruby"},
	cultural_material_keys = {"runeslate","sunwax","moonresin","gravesalt","red_ochre","spirit_resin"},
	signature_wood_keys = {"mountain_pine","oak","silverwood","gravewood","spikethorn_acacia","kapok"},
	-- Stable assignments only. All resource species, node names, harvest tiers,
	-- depths and density values remain owned and resolved by WP43.
	race_region_assignments = {
		{race_region="dwarf",g1="garnet",g2="sapphire",cultural="runeslate",signature_wood="mountain_pine"},
		{race_region="human",g1="citrine",g2="diamond",cultural="sunwax",signature_wood="oak"},
		{race_region="elf",g1="jade",g2="sapphire",cultural="moonresin",signature_wood="silverwood"},
		{race_region="undead",g1="citrine",g2="ruby",cultural="gravesalt",signature_wood="gravewood"},
		{race_region="orc",g1="garnet",g2="diamond",cultural="red_ochre",signature_wood="spikethorn_acacia"},
		{race_region="troll",g1="jade",g2="ruby",cultural="spirit_resin",signature_wood="kapok"},
	},
}

-- Numeric ids are the canonical one-based positions in every ordered record
-- family. They are installed in one deterministic pass so records with large
-- literal bodies cannot accidentally drift away from their array position.
local numeric_collections = {
	source.relief_profiles, source.route_classes, source.water_classes,
	source.template_primitives, source.zones, source.land_edges,
	source.relief_junctions,
	source.perimeter_attachments,source.perimeter_spans,
	source.face_arcs,source.zone_faces,
	source.route_stations,source.routes,source.route_interfaces,
	source.surface_level_controls,
	source.route_crossing_interfaces,
	source.boat_edges,source.island_landings,source.island_route_stations,
	source.island_routes,source.island_route_interfaces,source.perimeters,
	source.bays,source.bay_mouth_apertures, source.islands, source.channels, source.landmarks,
	source.anchors, source.templates,source.poi_spurs,source.template_compositions,
	source.hydrology_profiles,source.hydrology_transition_profiles,
	source.hydrology,source.hydrology_interfaces,
	source.hard_protection_recipes,source.hard_protection,
	source.pending_static_recipes,source.pending_static_reservations,
	source.claim_exclusion_recipes,source.claim_exclusions,source.housing_masks,
	source.coastal_housing_cores, source.semantics.race_region_assignments,
}
for collection_index = 1, #numeric_collections do
	local collection = numeric_collections[collection_index]
	for record_index = 1, #collection do
		collection[record_index].numeric_id = record_index
	end
end

return source
