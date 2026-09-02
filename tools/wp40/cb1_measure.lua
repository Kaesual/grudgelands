local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "output directory required")
local tested_commit = assert(arg[4], "tested commit required")
local tested_tree = assert(arg[5], "tested tree required")
assert(tested_commit == "64592fe24e092997bf676cc2e245ff9181b5ae93",
	"WP40 CB-1: wrong base commit")
assert(tested_tree == "3e6fa09835193862d498d17fb1ff2dd749573ad2",
	"WP40 CB-1: wrong base tree")
local common = dofile(repo .. "/tools/wp40/cb1_common.lua")(repo, scratch)

local function measure()
	local stages = {
		{"roster", "route-roster.tsv", "cb1_roster.lua"},
		{"profile", "profile-feasibility.tsv", "cb1_profile_feasibility.lua"},
		{"island", "island-deficits.tsv", "cb1_island_deficits.lua"},
		{"route_reach", "route-reach-intersections.tsv", "cb1_route_reach.lua"},
		{"hydrology", "hydrology-audit.tsv", "cb1_hydrology_audit.lua"},
	}

	local metrics, summaries = {}, {}
	for index = 1, #stages do
		local stage = stages[index]
		local started = os.clock()
		local first, rows, summary = dofile(repo .. "/tools/wp40/" .. stage[3])(
			common, output .. "/" .. stage[2])
		if first > 300 then
			error("WP40 CB-1: top-level case budget exceeded", 0)
		end
		summaries[stage[1]] = summary or {}
		metrics[#metrics + 1] = {stage = stage[1], top_level_cases = first,
			artifact_rows = rows or first, cpu_seconds = string.format("%.3f",
				os.clock() - started)}
	end

	assert(metrics[1].artifact_rows == 65 and metrics[2].artifact_rows == 570 and
		metrics[3].artifact_rows == 40 and metrics[4].artifact_rows == 25 and
		metrics[5].artifact_rows == 44, "WP40 CB-1: evidence row accounting moved")
	assert(metrics[4].top_level_cases == 65,
		"WP40 CB-1: route/reach scope no longer covers all 65 routes")
	assert(summaries.roster.route_011_bridgeable_delta == 36,
		"WP40 CB-1: route_011 capacity moved")
	assert(summaries.profile.singleton_rows == 190 and
		summaries.profile.range_rows == 380,
		"WP40 CB-1: gate certainty accounting moved")
	assert(summaries.route_reach.declared == 5 and
		summaries.route_reach.undeclared == 20 and
		summaries.route_reach.raster_disagreements == 0 and
		summaries.route_reach.island_contacts == 0,
		"WP40 CB-1: route/reach accounting moved")
	assert(summaries.hydrology.water_stations == 8 and
		summaries.hydrology.dry_stations == 1 and
		summaries.hydrology.W_below_band == 1 and
		summaries.hydrology.W_below_landmark_band == 7 and
		summaries.hydrology.W_above_landmark_band == 2 and
		summaries.hydrology.W_above_landmark_band_by_reach[
			"hydro_kezamba_cenote"] == 40 and
		summaries.hydrology.W_above_landmark_band_by_reach[
			"hydro_lorindor_marsh"] == 4 and
		summaries.hydrology.direction_audited == 1 and
		summaries.hydrology.direction_conflicts == 1,
		"WP40 CB-1: hydrology accounting moved")

	common.write_tsv(output .. "/findings.tsv", {"classification", "id", "value",
		"scope"}, {
		{classification = "measured_fact", id = "route_profile_roster", value = 65,
			scope = "57_mainland_plus_8_island"},
		{classification = "measured_fact", id = "route_011_bridgeable_delta",
			value = summaries.roster.route_011_bridgeable_delta,
			scope = "exact_current_phase_windows_first_transition_free"},
		{classification = "measured_fact", id = "H1_capacity_variant_differences",
			value = summaries.roster.h1_capacity_differences,
			scope = "current_8_island_routes_no_ruling"},
		{classification = "measured_fact", id = "raw_local_optimistic_negative_rows",
			value = summaries.profile.raw_optimistic_negative,
			scope = "570_side_rows_pre_ca2_local_upper_bound"},
		{classification = "proof", id = "raw_exact_singleton_negative_rows",
			value = summaries.profile.raw_singleton_negative,
			scope = "190_rows_exact_G_not_gate_range_bound"},
		{classification = "measured_fact",
			id = "raw_range_optimistic_negative_rows",
			value = summaries.profile.raw_range_optimistic_negative,
			scope = "380_rows_unknown_hashed_G_optimistic_band_bound"},
		{classification = "measured_fact",
			id = "unclipped_local_optimistic_negative_rows",
			value = summaries.profile.all_optimistic_negative,
			scope = "570_side_rows_pre_ca2_no_edge_G_or_junction_not_final_H"},
		{classification = "proof", id = "unclipped_exact_singleton_negative_rows",
			value = summaries.profile.all_singleton_negative,
			scope = "190_rows_exact_G_no_edge_G_or_junction_not_final_H"},
		{classification = "measured_fact",
			id = "unclipped_range_optimistic_negative_rows",
			value = summaries.profile.all_range_optimistic_negative,
			scope = "380_rows_unknown_hashed_G_optimistic_band_bound"},
		{classification = "measured_fact", id = "island_unclipped_positive_deficits",
			value = summaries.island.all_positive,
			scope = "40_route_seed_rows_endpoint_only_not_final_H"},
		{classification = "proof", id = "route_reach_analytic_contacts",
			value = summaries.route_reach.declared + summaries.route_reach.undeclared,
			scope = "65_routes_exact_authored_segment_intersection"},
		{classification = "proof", id = "route_reach_raster_disagreements",
			value = summaries.route_reach.raster_disagreements,
			scope = "analytic_authority_vs_canonical_raster_crosscheck"},
		{classification = "proof", id = "island_route_reach_contacts",
			value = summaries.route_reach.island_contacts,
			scope = "8_island_routes_exact_authored_segment_intersection"},
		{classification = "measured_fact", id = "undeclared_analytic_contacts",
			value = summaries.route_reach.undeclared,
			scope = "exact_authored_segment_intersection"},
		{classification = "proof", id = "route_stations_inside_planned_water",
			value = summaries.hydrology.water_stations,
			scope = "analytic_centreline_zero_distance_with_positive_recorded_width"},
		{classification = "proof", id = "route_stations_on_dry_channel",
			value = summaries.hydrology.dry_stations,
			scope = "analytic_centreline_no_water_claim"},
		{classification = "proof", id = "design_flow_direction_conflicts",
			value = summaries.hydrology.direction_conflicts,
			scope = "source_delta_and_from_to_roles_vs_declared_zone_design_rule"},
		{classification = "measured_fact", id = "reach_W_below_zone_primary_band",
			value = summaries.hydrology.W_below_band,
			scope = "source_W_vs_primary_zone_relief_band"},
		{classification = "measured_fact",
			id = "reach_W_below_landmark_secondary_band",
			value = summaries.hydrology.W_below_landmark_band,
			scope = "source_W_vs_reach_landmark_secondary_relief_band"},
		{classification = "measured_fact",
			id = "reach_W_above_landmark_secondary_band",
			value = summaries.hydrology.W_above_landmark_band,
			scope = "25_reaches_source_W_vs_reach_landmark_secondary_relief_band"},
		{classification = "measured_fact",
			id = "hydro_kezamba_cenote_W_above_landmark_secondary_band",
			value = summaries.hydrology.W_above_landmark_band_by_reach[
				"hydro_kezamba_cenote"],
			scope = "source_W_minus_reach_landmark_secondary_band_high"},
		{classification = "measured_fact",
			id = "hydro_lorindor_marsh_W_above_landmark_secondary_band",
			value = summaries.hydrology.W_above_landmark_band_by_reach[
				"hydro_lorindor_marsh"],
			scope = "source_W_minus_reach_landmark_secondary_band_high"},
		{classification = "inference", id = "source_ruling_round_needed", value = true,
			scope = "diagnostics_identify_questions_no_geometry_change_authorized"},
		{classification = "deferred", id = "final_owner_containment", value = false,
			scope = "unavailable_until_reviewed_ca2_provider"},
		{classification = "deferred", id = "final_H_profile_acceptance", value = false,
			scope = "unavailable_until_reviewed_ca2_provider"},
	})

	common.write_tsv(output .. "/runtime.tsv",
		{"stage", "top_level_cases", "artifact_rows", "cpu_seconds"}, metrics)
	local stats = common.hasher.stats()
	common.write_tsv(output .. "/manifest.tsv", {"key", "value"}, {
		{key = "schema", value = "grug_wp40_t2_cb1_measurement_v1"},
		{key = "base_commit", value = tested_commit},
		{key = "base_tree", value = tested_tree},
		{key = "source_catalog_sha256", value = common.file_sha256(repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")},
		{key = "canonical_sha256", value = common.file_sha256(repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/canonical.lua")},
		{key = "deterministic_sha256", value = common.file_sha256(repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")},
		{key = "exact_sha256", value = common.file_sha256(repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")},
		{key = "raster_sha256", value = common.file_sha256(repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua")},
		{key = "relief_sha256", value = common.file_sha256(repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/geometry/relief.lua")},
		{key = "winner_gate_sha256", value = common.file_sha256(repo ..
			"/tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua")},
		{key = "world_zones_design_sha256", value = common.file_sha256(repo ..
			"/docs/design/world_zones.md")},
		{key = "pre_ca2", value = true},
		{key = "interpreter_strategy", value =
			"LuaJIT_measurement_plus_full_targeted_PUC51_byte_parity"},
		{key = "dual_runtime_comparison", value =
			"seven_deterministic_artifacts_byte_identical_required_and_verified"},
		{key = "seed_0", value = "0"},
		{key = "winner_2192_seed", value = "5270046902118333881"},
		{key = "winner_1713_seed", value = "16178445837170081103"},
		{key = "winner_1047_seed", value = "15219119262482319357"},
		{key = "winner_3438_seed", value = "17842018860885445630"},
		{key = "final_owner_provider", value =
			"unavailable_deferred_until_reviewed_ca2"},
		{key = "final_H_provider", value =
			"unavailable_deferred_until_reviewed_ca2"},
		{key = "hydrology_mask_implementation", value =
			"unavailable_route_reach_claims_are_exact_centreline_only"},
		{key = "h_composition_scope", value =
			"raw_plus_landmarks_only_no_shared_edge_G_or_junction_blend"},
		{key = "profile_claim", value =
			"raw_and_unclipped_local_diagnostics_not_final_acceptance"},
		{key = "route_reach_scope", value =
			"57_mainland_plus_8_island_exact_authored_segment_intersections"},
		{key = "h1_status", value =
			"literal_and_symmetric_seven_delta_variants_measured_no_ruling"},
		{key = "top_level_case_unit", value =
			"one_route_seed_or_one_route_or_one_reach_with_bounded_inner_checks"},
		{key = "sha_calls", value = stats.calls},
		{key = "sha_misses", value = stats.misses},
	})
	print("WP40 CB-1 measurement complete")
end

local ok, message = pcall(measure)
common.close()
if not ok then error(message, 0) end
