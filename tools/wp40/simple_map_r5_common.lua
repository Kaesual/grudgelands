-- Shared canonical, lineage and immutable-input helpers for WP40 R5 tools.

local common = {}

common.MAX_SAFE = 9007199254740991
common.R2_BODY_SHA256 =
	"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b"
common.R2_FILE_SHA256 =
	"ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b"
common.R3_BODY_SHA256 =
	"09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2"
common.R3_FILE_SHA256 =
	"c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65"
common.R4_HISTORICAL_BODY_SHA256 =
	"bb19948d6bcb2c9976eddc6358955407f8b4a3c4cd54fb7dce1165e22ed8edca"
common.R4_HISTORICAL_FILE_SHA256 =
	"23a05d2115fb6d3a1b286e09a17847793e23fc0a23817ade8ce8b812875d1b3c"
common.R4_REVIEW_FILE_SHA256 =
	"f0a8a59e43a678d388e92528f9d3bf4b3db49fa659548880ab094a5602070eab"
common.R4_REVIEW_VERDICT_SHA256 =
	"bd67757f881b3a2e1952214870f60b71ab3907022153edd26f99f23a0528f130"
common.R4_TARGETED_KAT_BODY_SHA256 =
	"72b9bd0e2d21cb82c4b1627031434eda1b83a2d8b8223fae22eb8f0e377ab5de"
common.R4_TARGETED_KAT_FILE_SHA256 =
	"14463a99810351439fdf5d65a02436e367db69df1c2efebaeb8bc1b495a90b39"
common.R4_SEED_0_KAT_SHA256 =
	"8b5145180dd8a4a6de01de47cbb8fc4560e2947d78cdb281016d5c3414b9b8aa"
common.R5_CONTRACT_SHA256 =
	"75e2552b6197c222a6ac09f68b4b91ba4605baf37e13b1ddec99f85ecd585040"
common.R4_ACCEPTED_COMMIT = "948689138c15c291544fe10927683da4183bfd8e"
common.R5_DRAFT_COMMIT = "8f9472e238626cd8dcb510490f9efe6047cee13c"
common.R5_AUDIT_FIX_COMMIT = "a4412651a34bfb361e517474c1be702267770709"
common.R5_R4_MERGE_COMMIT = "d718f020815b77f3c9282364998b6e3bf53ce047"
common.R5_BPLUS_COMMIT = "37bd94829d7a8c3d1a59688612a483f449fa63de"
common.DUNGEON_CORPUS_DIRECTORY_DIGEST =
	"256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7"
common.DUNGEON_CORPUS_RAW_PATH =
	"tools/wp40/dungeon_probe/evidence/256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7/raw.log"
common.DUNGEON_CORPUS_RAW_SHA256 =
	"5af86febe5bd509121df2ce46b2714e8d0c400cf2f37f219645c284e93adc7a4"
common.DUNGEON_CORPUS_SUMMARY_PATH =
	"tools/wp40/dungeon_probe/evidence/256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7/summary.json"
common.DUNGEON_CORPUS_SUMMARY_SHA256 =
	"047f74d4ae891e5e62dc5389a494ac44a9a925c680ad3d53f0966bd68ce911f6"

common.R2_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r2_artifact_v2"
common.R3_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r3_artifact_v1"
common.R5_SCHEMA = "grug_wp40_simple_map_r5_v1"
common.R5_STATUS_SCHEMA = "grug_wp40_simple_map_r5_status_v1"
common.R5_PLANNER_SOURCE_SCHEMA = "grug_wp40_r5_planner_source_v1"
common.R5_PLAN_SCHEMA = "grug_wp40_r5_column_run_plan_v1"
common.R5_CONTENT_CONTRACT_SCHEMA = "grug_wp40_r5_content_contract_v1"
common.R5_MAPGEN_CONTEXT_SCHEMA = "grug_wp40_r5_mapgen_context_v1"
common.R5_PAIRED_CONTEXT_REQUEST_SCHEMA =
	"grug_wp40_r5_paired_context_request_v1"
common.R5_MANIFEST_SCHEMA = "grug_wp40_r5_mapgen_manifest_v1"
common.R5_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r5_artifact_v1"
common.R5_PREFLIGHT_SCHEMA = "grug_wp40_r5_preflight_v1"
common.INPUT_MANIFEST_SCHEMA = "grug_wp40_r5_input_manifest_v1"
common.SOURCE_SCHEMA = "grug_wp40_simple_map_source_v2"
common.HORIZONTAL_SCHEMA = "grug_wp40_simple_map_v1"
common.HEIGHT_SCHEMA = "grug_wp40_simple_map_height_v1"
common.LAYOUT_ID = "wp40-simple-map-v1d"
common.LAYOUT_REVISION_ID = "wp40-simple-map-v1e"
common.WATER_LEVEL = 1
common.CANONICAL_SEEDS = {
	"0", "1", "9223372036854775808", "18446744073709551615",
}

common.OPCODES = {
	"BIOME_BED", "BIOME_FILLER", "BIOME_SHORE", "BIOME_TOP",
	"BRIDGE_CLEAR", "BRIDGE_DECK", "BRIDGE_SUPPORT", "CAUSEWAY_CULVERT",
	"CAUSEWAY_FILL", "CAUSEWAY_SURFACE", "CONTACT_FALL_CLEAR", "DECORATION",
	"FORD_BED", "FOUNDATION_CLEAR", "FOUNDATION_FILL", "FOUNDATION_SURFACE",
	"HYDROLOGY_BANK_SEAL", "HYDROLOGY_BED_SEAL", "ORDINARY_WATER",
	"PATH_CLEAR", "PATH_FILL", "PATH_SURFACE", "RECEIVER_OPEN",
	"RESOURCE_EXACT_HOST", "RIVER_WATER", "TERRAIN_CLEAR", "TERRAIN_FILL",
	"TERRAIN_SURFACE", "TUNNEL_FLOOR", "TUNNEL_LUMEN", "TUNNEL_ROOF",
	"TUNNEL_WALL",
}
common.TARGET_ROLES = {
	"AIR", "BRIDGE_DECK", "BRIDGE_SUPPORT", "CAUSEWAY_CORE",
	"CAUSEWAY_SURFACE", "FORD_SURFACE", "FOUNDATION_CORE",
	"FOUNDATION_SURFACE", "HYDROLOGY_SEAL", "ORDINARY_WATER_SOURCE",
	"PATH_CORE", "PATH_SURFACE", "RIVER_WATER_SOURCE", "STRATUM_AT_Y",
	"TUNNEL_FLOOR", "TUNNEL_WALL",
}
common.REPLACE_POLICIES = {
	"CUT_NATURAL", "DEEP_EXACT_HOST", "FILL_VOID", "OPEN_ENGINEERED",
	"SEAL_VOID", "SURFACE_EXACT", "WRITE_WATER",
}
common.CONTENT_CLASSES = {
	"AIR", "FOREIGN", "IGNORE", "LIQUID", "NATIVE_ORE", "NATURAL_HOST",
	"NATURAL_SURFACE", "NATURAL_VEGETATION", "UNKNOWN", "WP43_RESOURCE",
	"WP43_STRATUM",
}

common.FIXTURE_IDS = {
	"historical_r4", "seed_0", "worst_fixture", "matrix",
	"native_heightmap", "owner_order", "dungeon", "disabled",
}
common.LINEAGE_KEYS = {
	"r2_body_sha256", "r2_file_sha256", "r3_body_sha256", "r3_file_sha256",
	"r4_historical_body_sha256", "r4_historical_file_sha256",
	"r4_public_kat_bundle_sha256", "r4_seed_0_canonical_kat_sha256",
	"r4_accepted_targeted_kat_body_sha256",
	"r4_accepted_targeted_kat_file_sha256",
	"r4_accepted_implementation_commit", "r4_review_file_sha256",
	"r4_review_verdict_sha256", "contract_sha256",
}
common.DIGEST_KEYS = {
	"r4_public_kat_bundle", "planner_source_scalar", "planner_source_relations",
	"stable_refs", "seed_0_plan", "worst_fixture_plan", "candidate_shuffle",
	"repeat_plan", "mask_population", "replace_matrix", "conflict_matrix",
	"preservation", "ignore_matrix", "dirty_matrix", "vm_call_matrix",
	"light_matrix", "liquid_matrix", "mapgen_edge_formula",
	"native_heightmap_matrix", "plan_heightmap_invariance",
	"bplus_materialization", "owner_slice_matrix", "committed_neighbor_matrix",
	"order_ascending", "order_descending", "order_permuted",
	"adapter_double_apply", "dungeon_oracle", "disabled_source_audit",
}
common.PROOF_KEYS = {
	"public_r4_fields_equal", "public_r4_disabled_bytes_equal",
	"public_r4_per_seed_bytes_equal", "public_r4_bundle_bytes_equal",
	"logical_biome_passthrough", "no_biome_share_input",
	"one_horizontal_session", "one_height_session", "plan_identity_exact",
	"bounded_candidate_runs", "bounded_resolved_runs",
	"zero_hotpath_table_allocations", "zero_p7_p8_p9", "all_masks_closed",
	"same_priority_conflicts_reject", "foreign_unknown_ignore_reject",
	"project_native_policy_total", "native_caves_locally_preserved",
	"native_dungeons_disjoint", "native_strata_typed", "mapgen_edges_equal",
	"native_heightmap_exact_once", "native_heightmap_domain_closed",
	"native_heightmap_plan_independent", "ordinary_native_cave_air_preserved",
	"ordinary_native_cave_liquid_preserved", "ordinary_sky_void_filled",
	"exact_masks_override_local_cave_preservation",
	"topmost_authored_ground_solid_exact", "authored_water_exact",
	"no_unplanned_project_native_above_surface_cap",
	"no_operation_below_authored_floor", "owner_content_param2_only",
	"halo_content_param2_unchanged", "vertical_continuation_analytic",
	"committed_neighbor_plan_outcome_content_param2_equal",
	"adapter_double_apply_equal", "light_halo_restored", "canopy_seed_rule",
	"ignore_overtop_sunlight_exact", "per_state_lighting_exact",
	"liquid_owner_boundary_exact", "nonlighting_halo_unread",
	"liquid_queue_exact", "one_vm_transaction", "callback_absent",
	"global_publication_absent", "settings_mutation_absent",
	"legacy_writer_unchanged", "emerge_threads_offline_validated",
}
common.METRIC_KEYS = {
	"horizontal_session_count", "height_session_count", "planner_source_count",
	"planner_construction_count", "construction_table_allocations",
	"construction_array_tables", "construction_map_tables",
	"allocator_bootstrap_tables", "retained_numeric_capacity",
	"retained_map_key_capacity", "retained_map_key_count",
	"allocator_growth_events", "hotpath_entries", "hotpath_table_allocations",
	"plan_identity_count", "stable_ref_count", "plan_slice_table_allocations",
	"adapter_apply_table_allocations", "emerged_area_external_table_allocations",
	"heightmap_fetch_calls", "heightmap_entries_validated",
	"heightmap_external_table_allocations", "metrics_result_table_allocations",
	"peak_candidate_runs_per_column", "peak_resolved_runs_per_column",
	"peak_resolved_runs_per_slice", "peak_run_value_cells",
	"plan_buffer_reuse_calls", "classified_columns", "planned_columns",
	"modified_voxels", "content_dirty_columns", "param2_dirty_columns",
	"light_dirty_columns", "liquid_dirty_columns", "light_seed_runs",
	"peak_light_seed_runs", "vm_get_emerged_area_calls", "vm_get_data_calls",
	"vm_set_data_calls", "vm_get_param2_calls", "vm_set_param2_calls",
	"vm_get_light_calls", "vm_set_lighting_calls", "vm_calc_lighting_calls",
	"vm_set_light_data_calls", "vm_update_liquids_calls",
}

local function fail(message)
	error("WP40 simple-map R5 harness: " .. message, 0)
end
common.fail = fail

local function list_set(values, label)
	local result = {}
	local previous
	for index = 1, #values do
		local value = values[index]
		if type(value) ~= "string" or value == "" or
				(previous ~= nil and not (previous < value)) then
			fail(label .. " is not sorted and unique")
		end
		result[value] = true
		previous = value
	end
	return result
end

local function fixture_map(rows)
	local result = {}
	for fixture_id, keys in pairs(rows) do
		for index = 1, #keys do
			local key = keys[index]
			if result[key] then fail("duplicate fixture-owned key " .. key) end
			result[key] = fixture_id
		end
	end
	return result
end

common.DIGEST_FIXTURE_BY_KEY = fixture_map({
	historical_r4 = {"r4_public_kat_bundle"},
	seed_0 = {"planner_source_scalar", "planner_source_relations", "stable_refs",
		"seed_0_plan", "mask_population"},
	worst_fixture = {"worst_fixture_plan"},
	matrix = {"candidate_shuffle", "repeat_plan", "replace_matrix",
		"conflict_matrix", "preservation", "ignore_matrix", "dirty_matrix",
		"vm_call_matrix", "light_matrix", "liquid_matrix",
		"adapter_double_apply"},
	native_heightmap = {"mapgen_edge_formula", "native_heightmap_matrix",
		"plan_heightmap_invariance", "bplus_materialization"},
	owner_order = {"owner_slice_matrix", "committed_neighbor_matrix",
		"order_ascending", "order_descending", "order_permuted"},
	dungeon = {"dungeon_oracle"},
	disabled = {"disabled_source_audit"},
})
common.PROOF_FIXTURE_BY_KEY = fixture_map({
	historical_r4 = {"public_r4_fields_equal", "public_r4_disabled_bytes_equal",
		"public_r4_per_seed_bytes_equal", "public_r4_bundle_bytes_equal"},
	seed_0 = {"logical_biome_passthrough", "no_biome_share_input",
		"one_horizontal_session", "one_height_session", "zero_p7_p8_p9",
		"all_masks_closed", "vertical_continuation_analytic"},
	worst_fixture = {"bounded_candidate_runs", "bounded_resolved_runs",
		"zero_hotpath_table_allocations"},
	matrix = {"plan_identity_exact", "same_priority_conflicts_reject",
		"foreign_unknown_ignore_reject", "project_native_policy_total",
		"native_strata_typed", "adapter_double_apply_equal", "canopy_seed_rule",
		"ignore_overtop_sunlight_exact", "liquid_owner_boundary_exact",
		"liquid_queue_exact", "one_vm_transaction"},
	native_heightmap = {"mapgen_edges_equal", "native_heightmap_exact_once",
		"native_heightmap_domain_closed", "native_heightmap_plan_independent",
		"native_caves_locally_preserved", "ordinary_native_cave_air_preserved",
		"ordinary_native_cave_liquid_preserved", "ordinary_sky_void_filled",
		"exact_masks_override_local_cave_preservation",
		"topmost_authored_ground_solid_exact", "authored_water_exact",
		"no_unplanned_project_native_above_surface_cap",
		"no_operation_below_authored_floor"},
	owner_order = {"owner_content_param2_only", "halo_content_param2_unchanged",
		"committed_neighbor_plan_outcome_content_param2_equal",
		"nonlighting_halo_unread", "light_halo_restored",
		"per_state_lighting_exact"},
	dungeon = {"native_dungeons_disjoint"},
	disabled = {"callback_absent", "global_publication_absent",
		"settings_mutation_absent", "legacy_writer_unchanged",
		"emerge_threads_offline_validated"},
})

common.COUNT_KEYS = {}
for index = 1, #common.OPCODES do
	common.COUNT_KEYS[#common.COUNT_KEYS + 1] = "opcode/" .. common.OPCODES[index]
end
for priority = 2, 9 do
	common.COUNT_KEYS[#common.COUNT_KEYS + 1] = "priority/" .. priority
end
for _, key in ipairs({
	"foundation", "path", "ford", "bridge_clear", "bridge_support",
	"bridge_deck", "causeway", "culvert", "tunnel_floor", "tunnel_lumen",
	"tunnel_wall", "tunnel_roof", "bed_seal", "bank_seal", "receiver_open",
	"contact_fall_clear", "terrain_fill", "terrain_surface", "terrain_clear",
}) do
	common.COUNT_KEYS[#common.COUNT_KEYS + 1] = "mask/" .. key
end
table.sort(common.COUNT_KEYS)
common.COUNT_FIXTURE_BY_KEY = {}
for index = 1, #common.COUNT_KEYS do
	common.COUNT_FIXTURE_BY_KEY[common.COUNT_KEYS[index]] = "seed_0"
end

local WORST_METRICS = list_set({
	"adapter_apply_table_allocations", "allocator_bootstrap_tables",
	"allocator_growth_events", "construction_array_tables",
	"construction_map_tables", "construction_table_allocations",
	"hotpath_entries", "hotpath_table_allocations",
	"metrics_result_table_allocations", "peak_candidate_runs_per_column",
	"peak_resolved_runs_per_column", "peak_resolved_runs_per_slice",
	"peak_run_value_cells", "plan_slice_table_allocations",
	"retained_map_key_capacity", "retained_map_key_count",
	"retained_numeric_capacity",
}, "worst-fixture metric keys")
local MATRIX_METRICS = list_set({
	"emerged_area_external_table_allocations", "light_seed_runs",
	"peak_light_seed_runs", "vm_calc_lighting_calls", "vm_get_data_calls",
	"vm_get_emerged_area_calls", "vm_get_light_calls", "vm_get_param2_calls",
	"vm_set_data_calls", "vm_set_light_data_calls", "vm_set_lighting_calls",
	"vm_set_param2_calls", "vm_update_liquids_calls",
}, "matrix metric keys")
local HEIGHTMAP_METRICS = list_set({
	"heightmap_entries_validated", "heightmap_external_table_allocations",
	"heightmap_fetch_calls",
}, "heightmap metric keys")
common.METRIC_FIXTURES_BY_KEY = {}
for index = 1, #common.METRIC_KEYS do
	local key = common.METRIC_KEYS[index]
	local fixtures = {seed_0 = true}
	if WORST_METRICS[key] then fixtures.worst_fixture = true end
	if MATRIX_METRICS[key] then fixtures.matrix = true end
	if HEIGHTMAP_METRICS[key] then fixtures.native_heightmap = true end
	common.METRIC_FIXTURES_BY_KEY[key] = fixtures
end

common.VOCABULARY = {}
local function add_ordinal_vocabulary(domain, values)
	local previous
	for index = 1, #values do
		local value = values[index]
		if type(value) ~= "string" or value == "" then
			fail(domain .. " vocabulary token differs")
		end
		for byte_index = 1, #value do
			if string.byte(value, byte_index) > 127 then
				fail(domain .. " vocabulary token is not ASCII")
			end
		end
		if previous ~= nil and not (previous < value) then
			fail(domain .. " vocabulary is not strictly sorted and unique")
		end
		common.VOCABULARY[#common.VOCABULARY + 1] =
			{domain = domain, id = index, token = value}
		previous = value
	end
end
add_ordinal_vocabulary("opcode", common.OPCODES)
add_ordinal_vocabulary("target_role", common.TARGET_ROLES)
add_ordinal_vocabulary("replace_policy", common.REPLACE_POLICIES)
add_ordinal_vocabulary("content_class", common.CONTENT_CLASSES)
for _, row in ipairs({
	{"aux", 0, "AUX_NONE"},
	{"target_kind", 0, "air"}, {"target_kind", 1, "solid"},
	{"target_kind", 2, "water_source"},
	{"param2_mode", 0, "preserve"}, {"param2_mode", 1, "exact"},
	{"liquid_kind", 0, "none"}, {"liquid_kind", 1, "source"},
	{"liquid_kind", 2, "flowing"},
}) do
	common.VOCABULARY[#common.VOCABULARY + 1] =
		{domain = row[1], id = row[2], token = row[3]}
end

common.CONSTANTS = {
	R5_SCHEMA = {type = "ascii", value = common.R5_SCHEMA},
	R5_STATUS_SCHEMA = {type = "ascii", value = common.R5_STATUS_SCHEMA},
	R5_PLANNER_SOURCE_SCHEMA =
		{type = "ascii", value = common.R5_PLANNER_SOURCE_SCHEMA},
	R5_PLAN_SCHEMA = {type = "ascii", value = common.R5_PLAN_SCHEMA},
	R5_CONTENT_CONTRACT_SCHEMA =
		{type = "ascii", value = common.R5_CONTENT_CONTRACT_SCHEMA},
	R5_MAPGEN_CONTEXT_SCHEMA =
		{type = "ascii", value = common.R5_MAPGEN_CONTEXT_SCHEMA},
	R5_MANIFEST_SCHEMA = {type = "ascii", value = common.R5_MANIFEST_SCHEMA},
	R5_ARTIFACT_SCHEMA = {type = "ascii", value = common.R5_ARTIFACT_SCHEMA},
	project_water_level = {type = "integer", value = 1},
	mapgen_limit = {type = "integer", value = 31007},
	chunksize = {type = "integer", value = 5},
	max_central_axis_nodes = {type = "integer", value = 80},
	max_central_columns = {type = "integer", value = 6400},
	central_owner_y_min = {type = "integer", value = -30912},
	central_owner_y_max = {type = "integer", value = 30927},
	authored_floor = {type = "integer", value = -37},
	native_heightmap_entries = {type = "integer", value = 6400},
	native_heightmap_sentinel = {type = "integer", value = -31007},
	native_heightmap_order = {type = "ascii", value = "x_fast_z_outer"},
	functional_headroom_nodes = {type = "integer", value = 4},
	hydrology_bed_seal_layers = {type = "integer", value = 3},
	hydrology_bank_seal_nodes = {type = "integer", value = 2},
	causeway_culvert_radius_squared = {type = "integer", value = 1},
	max_candidate_runs_per_column = {type = "integer", value = 16},
	max_resolved_runs_per_column = {type = "integer", value = 31},
	run_stride = {type = "integer", value = 9},
	max_stable_refs = {type = "integer", value = 512},
	force_native_dungeon = {type = "boolean", value = false},
	emerge_threads = {type = "integer", value = 1},
	canonical_seed_1 = {type = "seed", value = common.CANONICAL_SEEDS[1]},
	canonical_seed_2 = {type = "seed", value = common.CANONICAL_SEEDS[2]},
	canonical_seed_3 = {type = "seed", value = common.CANONICAL_SEEDS[3]},
	canonical_seed_4 = {type = "seed", value = common.CANONICAL_SEEDS[4]},
}
common.MANIFEST = {
	schema = {type = "ascii", value = common.R5_MANIFEST_SCHEMA},
	engine_commit = {type = "git40",
		value = "df04879066de6eb94ca43996822a6dfacc74feca"},
	mg_name = {type = "ascii", value = "v7"},
	water_level = {type = "integer", value = 1},
	mapgen_limit = {type = "integer", value = 31007},
	chunksize = {type = "integer", value = 5},
	central_owner_y_min = {type = "integer", value = -30912},
	central_owner_y_max = {type = "integer", value = 30927},
	heightmap_entries = {type = "integer", value = 6400},
	heightmap_sentinel = {type = "integer", value = -31007},
	heightmap_order = {type = "ascii", value = "x_fast_z_outer"},
	emerge_threads = {type = "integer", value = 1},
	engine_emerge_setting = {type = "ascii", value = "num_emerge_threads"},
	mg_flags = {type = "token_set",
		value = "biomes,caves,decorations,dungeons,light,ores"},
	mgv7_spflags = {type = "token_set", value = "caverns,mountains,ridges"},
	mgv7_dungeon_ymin = {type = "integer", value = -31000},
	mgv7_dungeon_ymax = {type = "integer", value = -193},
	authored_floor = {type = "integer", value = -37},
	force_native_dungeon = {type = "boolean", value = false},
}

function common.read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

function common.write_file(path, bytes)
	if type(bytes) ~= "string" then fail("file content is not bytes") end
	local file = assert(io.open(path, "wb"))
	assert(file:write(bytes))
	assert(file:close())
	if common.read_file(path) ~= bytes then fail("file write verification failed") end
end

function common.hex(bytes)
	if type(bytes) ~= "string" then fail("hex input is not bytes") end
	return (bytes:gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

function common.digest_hex(raw_sha256, bytes)
	if type(raw_sha256) ~= "function" then fail("raw SHA-256 seam is missing") end
	if type(bytes) ~= "string" then fail("SHA-256 input is not bytes") end
	local digest = raw_sha256(bytes)
	if type(digest) ~= "string" or #digest ~= 32 then
		fail("SHA-256 seam did not return 32 bytes")
	end
	return common.hex(digest)
end

function common.require_sha256(value, label)
	if type(value) ~= "string" or #value ~= 64 or
			not value:match("^[0-9a-f]+$") then
		fail((label or "SHA-256") .. " is not lowercase 64-hex")
	end
	return value
end

function common.require_git40(value, label)
	if type(value) ~= "string" or #value ~= 40 or
			not value:match("^[0-9a-f]+$") then
		fail((label or "Git object") .. " is not lowercase 40-hex")
	end
	return value
end

function common.safe_integer(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or
			math.abs(value) > common.MAX_SAFE then
		fail((label or "value") .. " is not a safe integer")
	end
	return value
end

function common.nonnegative_integer(value, label)
	common.safe_integer(value, label)
	if value < 0 then fail((label or "value") .. " is negative") end
	return value
end

function common.integer_ascii(value, label)
	common.safe_integer(value, label)
	if value == 0 then return "0" end
	return string.format("%.0f", value)
end

function common.ascii20(value)
	common.nonnegative_integer(value, "ASCII20 value")
	local bytes = common.integer_ascii(value)
	if #bytes > 20 then fail("ASCII20 value exceeds 20 digits") end
	return string.rep("0", 20 - #bytes) .. bytes
end

function common.frame_r4_public_kat_bundle(seeds, kats)
	if type(seeds) ~= "table" or type(kats) ~= "table" or
			#seeds ~= 4 or #kats ~= 4 then
		fail("R4 public-KAT bundle population differs")
	end
	local parts = {"grug_wp40_r4_public_kat_bundle_v1\n"}
	for index = 1, 4 do
		if seeds[index] ~= common.CANONICAL_SEEDS[index] or
				type(kats[index]) ~= "string" then
			fail("R4 public-KAT bundle seed/bytes differ")
		end
		parts[#parts + 1] = common.ascii20(#seeds[index])
		parts[#parts + 1] = seeds[index]
		parts[#parts + 1] = common.ascii20(#kats[index])
		parts[#parts + 1] = kats[index]
	end
	return table.concat(parts)
end

function common.dense_count(value, label)
	if type(value) ~= "table" then fail((label or "value") .. " is not an array") end
	local count = #value
	for index = 1, count do
		if value[index] == nil then fail((label or "array") .. " has a hole") end
	end
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail((label or "array") .. " is not dense")
		end
	end
	return count
end

function common.sorted_keys(value)
	if type(value) ~= "table" then fail("sorted-key value is not a table") end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(left, right)
		if type(left) ~= type(right) then return type(left) < type(right) end
		return left < right
	end)
	return keys
end

local function deep_copy(value, active)
	if type(value) ~= "table" then return value end
	active = active or {}
	if active[value] then fail("cyclic value cannot be copied") end
	active[value] = true
	local result = {}
	for key, child in pairs(value) do
		result[deep_copy(key, active)] = deep_copy(child, active)
	end
	active[value] = nil
	return result
end
common.deep_copy = deep_copy

local function valid_utf8(value)
	local index = 1
	while index <= #value do
		local first = string.byte(value, index)
		if first <= 127 then
			index = index + 1
		elseif first >= 194 and first <= 223 then
			local second = string.byte(value, index + 1)
			if not second or second < 128 or second > 191 then return false end
			index = index + 2
		elseif first >= 224 and first <= 239 then
			local second, third = string.byte(value, index + 1, index + 2)
			if not second or not third or third < 128 or third > 191 or
					second < 128 or second > 191 or
					(first == 224 and second < 160) or
					(first == 237 and second > 159) then return false end
			index = index + 3
		elseif first >= 240 and first <= 244 then
			local second, third, fourth = string.byte(value, index + 1, index + 3)
			if not second or not third or not fourth or third < 128 or third > 191 or
					fourth < 128 or fourth > 191 or second < 128 or second > 191 or
					(first == 240 and second < 144) or
					(first == 244 and second > 143) then return false end
			index = index + 4
		else
			return false
		end
	end
	return true
end

local function safe_relative_path(path)
	if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or
			path:sub(-1) == "/" or path:find("[\t\r\n%z]") or
			path:find("/" .. "/", 1, true) or not valid_utf8(path) then
		fail("repository-relative path is unsafe")
	end
	local components = 0
	for component in path:gmatch("[^/]+") do
		components = components + 1
		if component == "." or component == ".." then
			fail("repository-relative path contains traversal")
		end
	end
	if components == 0 then fail("repository-relative path is empty") end
	return path
end

local function literal_path_byte(byte)
	return byte >= 65 and byte <= 90 or byte >= 97 and byte <= 122 or
		byte >= 48 and byte <= 57 or byte == 46 or byte == 95 or byte == 47 or
		byte == 58 or byte == 43 or byte == 45
end

function common.encode_path(path)
	path = safe_relative_path(path)
	local parts = {}
	for index = 1, #path do
		local byte = string.byte(path, index)
		parts[index] = literal_path_byte(byte) and string.char(byte) or
			string.format("%%%02X", byte)
	end
	return table.concat(parts)
end

function common.decode_path(encoded)
	if type(encoded) ~= "string" or encoded == "" then
		fail("encoded path is invalid")
	end
	local parts = {}
	local index = 1
	while index <= #encoded do
		local byte = string.byte(encoded, index)
		if byte == 37 then
			local pair = encoded:sub(index + 1, index + 2)
			if #pair ~= 2 or not pair:match("^[0-9A-F][0-9A-F]$") then
				fail("encoded path escape is not canonical")
			end
			local decoded = assert(tonumber(pair, 16))
			if literal_path_byte(decoded) then
				fail("encoded path escapes a literal byte")
			end
			parts[#parts + 1] = string.char(decoded)
			index = index + 3
		else
			if not literal_path_byte(byte) then
				fail("encoded path contains a nonliteral byte")
			end
			parts[#parts + 1] = string.char(byte)
			index = index + 1
		end
	end
	local path = safe_relative_path(table.concat(parts))
	if common.encode_path(path) ~= encoded then fail("encoded path is not canonical") end
	return path
end

local function row_scalar(value)
	local kind = type(value)
	if kind == "number" then return common.integer_ascii(value) end
	if kind == "boolean" then return value and "true" or "false" end
	if kind ~= "string" or value == "" or value:find("[\t\r\n]") then
		fail("canonical row field is invalid")
	end
	return value
end

function common.canonical_row(tag, ...)
	if type(tag) ~= "string" or tag == "" or tag:find("[\t\r\n]") then
		fail("canonical row tag is invalid")
	end
	local fields = {}
	for index = 1, select("#", ...) do
		fields[index] = row_scalar(select(index, ...))
	end
	return {tag = tag, fields = fields}
end

function common.render_canonical_rows(rows)
	local count = common.dense_count(rows, "canonical rows")
	if count == 0 then fail("canonical row population is empty") end
	local parts = {}
	for index = 1, count do
		local row = rows[index]
		if type(row) ~= "table" or type(row.tag) ~= "string" or row.tag == "" or
				row.tag:find("[\t\r\n]") or type(row.fields) ~= "table" then
			fail("canonical row object is invalid")
		end
		local object_fields = 0
		for key in pairs(row) do
			if key ~= "tag" and key ~= "fields" then
				fail("canonical row object has an unexpected field")
			end
			object_fields = object_fields + 1
		end
		if object_fields ~= 2 then fail("canonical row object field count differs") end
		local field_count = common.dense_count(row.fields,
			"canonical row fields")
		local line = {row.tag}
		for field_index = 1, field_count do
			local field = row.fields[field_index]
			if type(field) ~= "string" or field == "" or
					field:find("[\t\r\n]") then
				fail("canonical row field is invalid")
			end
			line[field_index + 1] = field
		end
		parts[index] = table.concat(line, "\t") .. "\n"
	end
	return table.concat(parts)
end

local TAG_RANK = {
	schema = 1, lineage = 2, constant = 3, manifest = 4, vocabulary = 5,
	input_sha256 = 6, seed_kat = 7, digest = 8, count = 9, proof = 10,
	metric = 11,
}

local function row_sort_key(row)
	if type(row) ~= "table" or not TAG_RANK[row.tag] or
			type(row.fields) ~= "table" then fail("canonical artifact row is invalid") end
	common.dense_count(row.fields, "artifact row fields")
	local fields = row.fields
	if row.tag == "vocabulary" then
		common.nonnegative_integer(tonumber(fields[2]), "vocabulary ID")
		return fields[1], tonumber(fields[2]), fields[3]
	elseif row.tag == "seed_kat" then
		common.nonnegative_integer(tonumber(fields[1]), "seed ordinal")
		return "", tonumber(fields[1]), ""
	elseif row.tag == "schema" then
		return "", 0, ""
	elseif row.tag == "lineage" or row.tag == "constant" or
			row.tag == "manifest" or row.tag == "input_sha256" then
		return fields[1], 0, ""
	elseif row.tag == "digest" or row.tag == "count" or
			row.tag == "proof" or row.tag == "metric" then
		return fields[1] .. "\t" .. fields[2], 0, ""
	end
	fail("canonical artifact row tag is unhandled")
end

function common.sort_artifact_rows(rows)
	common.dense_count(rows, "artifact rows")
	for index = 1, #rows do row_sort_key(rows[index]) end
	table.sort(rows, function(left, right)
		local left_rank, right_rank = TAG_RANK[left.tag], TAG_RANK[right.tag]
		if left_rank ~= right_rank then return left_rank < right_rank end
		local la, ln, lc = row_sort_key(left)
		local ra, rn, rc = row_sort_key(right)
		if la ~= ra then return la < ra end
		if ln ~= rn then return ln < rn end
		return lc < rc
	end)
	local previous
	for index = 1, #rows do
		local row = rows[index]
		local first, numeric, third = row_sort_key(row)
		local tuple = row.tag .. "\t" .. first .. "\t" ..
			common.integer_ascii(numeric) .. "\t" .. third
		if previous == tuple then fail("duplicate canonical artifact sort tuple") end
		previous = tuple
	end
	return rows
end

function common.new_artifact_builder()
	local rows = {}
	local builder = {}
	function builder.add(tag, ...)
		rows[#rows + 1] = common.canonical_row(tag, ...)
	end
	function builder.body()
		common.sort_artifact_rows(rows)
		if #rows == 0 or rows[1].tag ~= "schema" or #rows[1].fields ~= 1 or
				rows[1].fields[1] ~= common.R5_ARTIFACT_SCHEMA then
			fail("canonical artifact schema row differs")
		end
		local parts = {}
		for index = 1, #rows do
			parts[index] = rows[index].tag .. "\t" ..
				table.concat(rows[index].fields, "\t") .. "\n"
		end
		return table.concat(parts)
	end
	return builder
end

function common.finalize_artifact(raw_sha256, body)
	if type(body) ~= "string" or body == "" or body:sub(-1) ~= "\n" or
			body:find("\r", 1, true) then fail("artifact body bytes are invalid") end
	local digest = common.digest_hex(raw_sha256, body)
	return body .. "artifact_sha256\t" .. digest .. "\n", digest
end

function common.parse_finalized_artifact(raw_sha256, bytes, expected_body,
		expected_file, label)
	label = label or "artifact"
	if type(bytes) ~= "string" or bytes:find("\r", 1, true) then
		fail(label .. " bytes are invalid")
	end
	if expected_file and common.digest_hex(raw_sha256, bytes) ~=
			common.require_sha256(expected_file, label .. " file digest") then
		fail(label .. " complete-file SHA-256 differs")
	end
	local body, embedded = bytes:match("^(.*\n)artifact_sha256\t([0-9a-f]+)\n$")
	if not body or common.digest_hex(raw_sha256, body) ~= embedded then
		fail(label .. " embedded body SHA-256 differs")
	end
	common.require_sha256(embedded, label .. " embedded digest")
	if expected_body and embedded ~=
			common.require_sha256(expected_body, label .. " body digest") then
		fail(label .. " accepted body SHA-256 differs")
	end
	return {body = body, body_sha256 = embedded,
		file_sha256 = common.digest_hex(raw_sha256, bytes)}
end

local CURRENT_R4_PATHS = {
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
	"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
	"mods/MAPGEN/grug_mapgen/wp40/validation.lua",
	"mods/MAPGEN/grug_mapgen/wp40/index128.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/height.lua",
	"mods/MAPGEN/grug_mapgen/wp40/zones.lua",
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua",
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/init.lua",
}
local R5_MODIFIED_PARENT_PATHS = {
	"mods/MAPGEN/grug_mapgen/wp40/index128.lua",
	"mods/MAPGEN/grug_mapgen/wp40/zones.lua",
}
if #R5_MODIFIED_PARENT_PATHS ~= 2 or
		R5_MODIFIED_PARENT_PATHS[1] ~=
			"mods/MAPGEN/grug_mapgen/wp40/index128.lua" or
		R5_MODIFIED_PARENT_PATHS[2] ~=
			"mods/MAPGEN/grug_mapgen/wp40/zones.lua" then
	fail("modified-parent path roster differs")
end
local R5_PRODUCTION_PATHS = {
	"mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua",
	"mods/MAPGEN/grug_mapgen/wp40/counting_allocator.lua",
	"mods/MAPGEN/grug_mapgen/wp40/planner.lua",
	"mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua",
	"mods/MAPGEN/grug_mapgen/wp40/r5.lua",
}
local R5_TOOL_PATHS = {
	"tools/wp40/simple_map_r5_common.lua",
	"tools/wp40/simple_map_r5_offline.lua",
	"tools/wp40/simple_map_r5_validate.lua",
	"tools/wp40/simple_map_r5_kat.lua",
	"tools/wp40/simple_map_r5_vm.lua",
	"tools/wp40/simple_map_r5_artifact.lua",
	"tools/wp40/simple_map_r5_selftest.lua",
	"tools/wp40/run_simple_map_r5.sh",
}
local R5_OFFLINE_METHODS = {
	"raw_sha256", "sha256_call_count", "preflight", "input_manifest",
	"verify_input_manifest", "read_bound_input", "read_current_input", "loaded",
	"load_public", "load_r5",
}
if #R5_OFFLINE_METHODS ~= 10 then fail("offline loader method count differs") end
for index = 1, #R5_OFFLINE_METHODS do
	for previous = 1, index - 1 do
		if R5_OFFLINE_METHODS[previous] == R5_OFFLINE_METHODS[index] then
			fail("offline loader method roster contains a duplicate")
		end
	end
end
local MUST_NOT_CHANGE_PATHS = {
	"mods/MAPGEN/grug_mapgen/wp40/init.lua",
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/height.lua",
	"mods/MAPGEN/grug_mapgen/init.lua",
	"mods/MAPGEN/grug_mapgen/ocean_mask.lua",
	"mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua",
	"mods/MAPGEN/grug_mapgen/structures.lua",
	"game.conf",
}
local MUST_NOT_CHANGE_SHA256 = {
	["mods/MAPGEN/grug_mapgen/wp40/init.lua"] =
		"b3ac5bf31bcf52e5f1534b2521f7c3b1d18a9930fe6582cfddb8217e5c1c8951",
	["mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"] =
		"5d4e2726dabbb900e47e7a8bef2a225011e6b003f48de485f752cde88fc7c17f",
	["mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"] =
		"55e507a6e5b2d73bf23233d9ab5e515ad150dbce77c6dc6c158a6133f4e27dfc",
	["mods/MAPGEN/grug_mapgen/wp40/height.lua"] =
		"f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97",
	["mods/MAPGEN/grug_mapgen/init.lua"] =
		"4e89d6e5975f0f511e5107737c29694b8b6b19a44f50b69cc74ad7d0dbb95fd4",
	["mods/MAPGEN/grug_mapgen/ocean_mask.lua"] =
		"39658372e8525265e1be6289f48c2b329325bc6744f5a2119c3f62edecc1ce61",
	["mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua"] =
		"15572acfe6bd26f331220bbcb037c678cceb0ba7318f350099316fd5f20df16d",
	["mods/MAPGEN/grug_mapgen/structures.lua"] =
		"f02fef7b233a001ce5fec081d3a46c514aecbe990fe56f9ab8e0b19bb90c92de",
	["game.conf"] =
		"1c778404a49e1ecf48cbcd3c0a05a4868586a5126ace081a09ba9089e2dfc0f6",
}
local must_not_change_digest_count = 0
for path, digest in pairs(MUST_NOT_CHANGE_SHA256) do
	common.require_sha256(digest, "must-not-change digest for " .. path)
	must_not_change_digest_count = must_not_change_digest_count + 1
end
if must_not_change_digest_count ~= #MUST_NOT_CHANGE_PATHS then
	fail("must-not-change digest key count differs")
end
for index = 1, #MUST_NOT_CHANGE_PATHS do
	local path = MUST_NOT_CHANGE_PATHS[index]
	for previous = 1, index - 1 do
		if MUST_NOT_CHANGE_PATHS[previous] == path then
			fail("must-not-change path roster contains a duplicate")
		end
	end
	if MUST_NOT_CHANGE_SHA256[path] == nil then
		fail("must-not-change digest key set differs")
	end
end
for path in pairs(MUST_NOT_CHANGE_SHA256) do
	local found = false
	for index = 1, #MUST_NOT_CHANGE_PATHS do
		if MUST_NOT_CHANGE_PATHS[index] == path then found = true end
	end
	if not found then fail("must-not-change digest has an unlisted path") end
end
local AUTHORITY_PATHS = {
	"docs/design/world_zones.md",
	"docs/research/wp40-engineering-brief.md",
	"docs/research/wp40-simple-map-r5-contract.md",
	"docs/research/wp40-simple-map-r2-artifact.tsv",
	"docs/research/wp40-simple-map-r3-artifact.tsv",
	"docs/research/wp40-simple-map-r4-artifact.tsv",
	"docs/research/wp40-simple-map-r4-review.md",
}
local BOUND_AUTHORITY_PATHS = {
	common.DUNGEON_CORPUS_RAW_PATH,
	common.DUNGEON_CORPUS_SUMMARY_PATH,
}
local BOUND_AUTHORITY_DIGESTS = {
	[common.DUNGEON_CORPUS_RAW_PATH] = common.DUNGEON_CORPUS_RAW_SHA256,
	[common.DUNGEON_CORPUS_SUMMARY_PATH] = common.DUNGEON_CORPUS_SUMMARY_SHA256,
}
for path, digest in pairs(MUST_NOT_CHANGE_SHA256) do
	BOUND_AUTHORITY_DIGESTS[path] = digest
end
common.HISTORICAL_R4_KAT_PATHS = common.deep_copy(CURRENT_R4_PATHS)
common.R5_MODIFIED_PARENT_PATHS = common.deep_copy(R5_MODIFIED_PARENT_PATHS)
common.R5_PRODUCTION_PATHS = common.deep_copy(R5_PRODUCTION_PATHS)
common.R5_TOOL_PATHS = common.deep_copy(R5_TOOL_PATHS)
common.R5_OFFLINE_METHODS = common.deep_copy(R5_OFFLINE_METHODS)
common.MUST_NOT_CHANGE_PATHS = common.deep_copy(MUST_NOT_CHANGE_PATHS)
common.MUST_NOT_CHANGE_SHA256 = common.deep_copy(MUST_NOT_CHANGE_SHA256)
common.BOUND_AUTHORITY_PATHS = common.deep_copy(BOUND_AUTHORITY_PATHS)

function common.bound_input_sha256(path)
	return BOUND_AUTHORITY_DIGESTS[path]
end

local USED_PARENT_PATHS = {
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
	"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/height.lua",
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
}

function common.build_canonical_input_paths(r2_inputs, r3_inputs)
	if type(r2_inputs) ~= "table" or type(r3_inputs) ~= "table" then
		fail("accepted parent input maps are missing")
	end
	local set = {}
	local function add(path)
		path = safe_relative_path(path)
		set[path] = true
	end
	for index = 1, #USED_PARENT_PATHS do
		local path = USED_PARENT_PATHS[index]
		if r2_inputs[path] == nil and r3_inputs[path] == nil then
			fail("accepted parent input is unbound: " .. path)
		end
		add(path)
	end
	for _, paths in ipairs({CURRENT_R4_PATHS, R5_PRODUCTION_PATHS,
			R5_TOOL_PATHS, MUST_NOT_CHANGE_PATHS, AUTHORITY_PATHS,
			BOUND_AUTHORITY_PATHS}) do
		for index = 1, #paths do add(paths[index]) end
	end
	local result = common.sorted_keys(set)
	table.sort(result, function(left, right)
		return common.encode_path(left) < common.encode_path(right)
	end)
	return result
end

local function exact_manifest_fields(manifest)
	if type(manifest) ~= "table" then fail("input manifest is not a table") end
	local allowed = {schema = true, paths = true, digests = true, count = true,
		canonical_bytes = true, sha256 = true}
	local count = 0
	for key in pairs(manifest) do
		if not allowed[key] then fail("input manifest has unexpected field") end
		count = count + 1
	end
	if count ~= 6 then fail("input manifest field count differs") end
end

function common.capture_input_manifest(repo, raw_sha256, r2_inputs, r3_inputs)
	if type(repo) ~= "string" or repo:sub(1, 1) ~= "/" then
		fail("absolute repository root required")
	end
	local raw_paths = common.build_canonical_input_paths(r2_inputs, r3_inputs)
	local encoded_paths, digests, rows = {}, {}, {}
	for index = 1, #raw_paths do
		local path = raw_paths[index]
		local encoded = common.encode_path(path)
		encoded_paths[index] = encoded
		local digest = common.digest_hex(raw_sha256,
			common.read_file(repo .. "/" .. path))
		local bound = BOUND_AUTHORITY_DIGESTS[path]
		if bound ~= nil and digest ~= bound then
			fail("bound authority input changed: " .. path)
		end
		digests[path] = digest
		rows[index] = "input_sha256\t" .. encoded .. "\t" .. digest .. "\n"
	end
	local bytes = table.concat(rows)
	return {
		schema = common.INPUT_MANIFEST_SCHEMA,
		paths = encoded_paths,
		digests = digests,
		count = #encoded_paths,
		canonical_bytes = bytes,
		sha256 = common.digest_hex(raw_sha256, bytes),
	}
end

function common.parse_input_manifest(raw_sha256, bytes)
	if type(bytes) ~= "string" or bytes == "" or bytes:sub(-1) ~= "\n" or
			bytes:find("\r", 1, true) then fail("input manifest bytes are invalid") end
	local paths, digests, count, previous = {}, {}, 0, nil
	for line in bytes:gmatch("([^\n]+)\n") do
		local encoded, digest = line:match(
			"^input_sha256\t([^\t]+)\t([0-9a-f]+)$")
		if not encoded then fail("input manifest row is malformed") end
		common.require_sha256(digest, "input manifest row digest")
		if previous ~= nil and not (previous < encoded) then
			fail("input manifest paths are not sorted and unique")
		end
		local path = common.decode_path(encoded)
		if digests[path] ~= nil then fail("input manifest path is duplicated") end
		count = count + 1
		paths[count], digests[path], previous = encoded, digest, encoded
	end
	if count == 0 then fail("input manifest is empty") end
	return {
		schema = common.INPUT_MANIFEST_SCHEMA,
		paths = paths,
		digests = digests,
		count = count,
		canonical_bytes = bytes,
		sha256 = common.digest_hex(raw_sha256, bytes),
	}
end

function common.verify_input_manifest(repo, raw_sha256, manifest,
		r2_inputs, r3_inputs)
	exact_manifest_fields(manifest)
	if manifest.schema ~= common.INPUT_MANIFEST_SCHEMA then
		fail("input manifest schema differs")
	end
	common.require_sha256(manifest.sha256, "input manifest SHA-256")
	local expected_paths = common.build_canonical_input_paths(r2_inputs, r3_inputs)
	if common.dense_count(manifest.paths, "input manifest paths") ~=
			#expected_paths or type(manifest.digests) ~= "table" or
			manifest.count ~= #expected_paths then fail("input manifest population differs") end
	local rows = {}
	for index = 1, #expected_paths do
		local path = expected_paths[index]
		local encoded = common.encode_path(path)
		if manifest.paths[index] ~= encoded or common.decode_path(encoded) ~= path then
			fail("input manifest path order differs")
		end
		local expected = common.require_sha256(manifest.digests[path],
			"input manifest digest")
		local bound = BOUND_AUTHORITY_DIGESTS[path]
		if bound ~= nil and expected ~= bound then
			fail("bound authority manifest digest differs: " .. path)
		end
		local actual = common.digest_hex(raw_sha256,
			common.read_file(repo .. "/" .. path))
		if actual ~= expected then fail("immutable input changed: " .. path) end
		rows[index] = "input_sha256\t" .. encoded .. "\t" .. expected .. "\n"
	end
	local digest_count = 0
	for path in pairs(manifest.digests) do
		safe_relative_path(path)
		digest_count = digest_count + 1
	end
	if digest_count ~= #expected_paths then fail("input manifest digest map differs") end
	local bytes = table.concat(rows)
	if bytes ~= manifest.canonical_bytes or
			common.digest_hex(raw_sha256, bytes) ~= manifest.sha256 then
		fail("input manifest canonical bytes/digest differ")
	end
	return true
end

local function parse_parent_artifact(repo, raw_sha256, relative, spec)
	local parsed = common.parse_finalized_artifact(raw_sha256,
		common.read_file(repo .. "/" .. relative), spec.body_sha256,
		spec.file_sha256, spec.label)
	local inputs, bindings, input_count = {}, {}, 0
	for line in parsed.body:gmatch("([^\n]+)\n") do
		local path, digest = line:match("^input_sha256\t([^\t]+)\t([0-9a-f]+)$")
		if path then
			path = safe_relative_path(path)
			common.require_sha256(digest, spec.label .. " input digest")
			if inputs[path] then fail("duplicate parent input path " .. path) end
			inputs[path], input_count = digest, input_count + 1
		else
			local key, value = line:match("^([^\t]+)\t([^\t]+)$")
			if key and spec.required[key] ~= nil then
				if bindings[key] ~= nil then fail("duplicate parent binding " .. key) end
				bindings[key] = value
			end
		end
	end
	if input_count ~= spec.input_count then fail(spec.label .. " input count differs") end
	for key, expected in pairs(spec.required) do
		if bindings[key] ~= tostring(expected) then
			fail(spec.label .. " binding differs: " .. key)
		end
	end
	for path, expected in pairs(inputs) do
		local actual = common.digest_hex(raw_sha256,
			common.read_file(repo .. "/" .. path))
		if actual ~= expected then fail(spec.label .. " input changed: " .. path) end
	end
	parsed.inputs, parsed.input_count, parsed.bindings = inputs, input_count, bindings
	parsed.path = relative
	return parsed
end

function common.verify_parent_authority(repo, raw_sha256)
	local r2 = parse_parent_artifact(repo, raw_sha256,
		"docs/research/wp40-simple-map-r2-artifact.tsv", {
			label = "accepted R2 artifact", body_sha256 = common.R2_BODY_SHA256,
			file_sha256 = common.R2_FILE_SHA256, input_count = 15,
			required = {schema = common.R2_ARTIFACT_SCHEMA,
				layout_id = common.LAYOUT_ID,
				layout_revision_id = common.LAYOUT_REVISION_ID,
				source_schema = common.SOURCE_SCHEMA},
		})
	local r3 = parse_parent_artifact(repo, raw_sha256,
		"docs/research/wp40-simple-map-r3-artifact.tsv", {
			label = "accepted R3 artifact", body_sha256 = common.R3_BODY_SHA256,
			file_sha256 = common.R3_FILE_SHA256, input_count = 13,
			required = {schema = common.R3_ARTIFACT_SCHEMA,
				height_schema = common.HEIGHT_SCHEMA, layout_id = common.LAYOUT_ID,
				layout_revision_id = common.LAYOUT_REVISION_ID,
				source_schema = common.SOURCE_SCHEMA, seed = "0",
				project_water_level = "1", r2_body_sha256 = common.R2_BODY_SHA256,
				r2_file_sha256 = common.R2_FILE_SHA256},
		})
	local combined = {}
	for path, digest in pairs(r2.inputs) do combined[path] = digest end
	for path, digest in pairs(r3.inputs) do
		if combined[path] and combined[path] ~= digest then
			fail("R2/R3 input binding conflict: " .. path)
		end
		combined[path] = digest
	end
	local combined_count = 0
	for _ in pairs(combined) do combined_count = combined_count + 1 end
	if combined_count ~= 23 then fail("combined R2/R3 input population differs") end
	return {r2 = r2, r3 = r3, inputs = combined, input_count = combined_count}
end

return common
