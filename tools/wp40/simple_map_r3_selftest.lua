-- Small production-independent smoke for the R3 harness and R2 preflight.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local ffi = rawget(_G, "wp40_ffi")
local injected_raw_sha256
if ffi then
	ffi.cdef[[
		unsigned char *SHA256(const unsigned char *data, size_t length,
			unsigned char *digest);
	]]
	local crypto = ffi.load("crypto")
	local digest_buffer = ffi.new("unsigned char[32]")
	injected_raw_sha256 = function(data)
		assert(crypto.SHA256(data, #data, digest_buffer) ~= nil, "SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
end

local common = dofile(repo .. "/tools/wp40/simple_map_r3_common.lua")
local offline = dofile(repo .. "/tools/wp40/simple_map_r3_offline.lua")(
	repo, scratch, injected_raw_sha256)
local r2 = common.verify_r2(repo, offline.raw_sha256)
assert(r2.body_sha256 == common.R2_BODY_SHA256)
assert(r2.file_sha256 == common.R2_FILE_SHA256)
assert(r2.coastal_reservation_counts.coastal_core_copperfell == 81254)
assert(r2.coastal_reservation_counts.coastal_core_mournfen == 81982)

assert(common.round_half_away(1, 2) == 1)
assert(common.round_half_away(-1, 2) == -1)
assert(common.round_half_away(1, 3) == 0)
local raster = common.raster_polyline({{x = -2, z = -1}, {x = 2, z = 1}})
assert(#raster == 5)
assert(raster[1].x == -2 and raster[1].z == -1)
assert(raster[5].x == 2 and raster[5].z == 1)

local builder = common.new_tsv()
builder.add("nil_tail", 1, nil)
common.add_evidence(builder, {z = {2, 3}, a = {flag = true}})
common.add_evidence_at(builder, "height/preflight/seed_01", {seed = "0"})
local bytes = builder.body()
assert(bytes:match("^nil_tail\t1\t%-\n"))
assert(bytes:find("evidence_map\theight", 1, true))
assert(bytes:find("evidence\theight/preflight/seed_01/seed\tstring\t0", 1, true))
assert(not pcall(builder.add_raw, "bad\nline"))

local empty_digest = common.digest_hex(offline.raw_sha256, "")
local kat_digest = common.digest_hex(offline.raw_sha256, "kat")
local evidence = {
	schema = "synthetic_r3_evidence_v1",
	height_schema = common.HEIGHT_SCHEMA,
	base_lattice_digest = empty_digest,
	relief_roots = {}, octave_lattices = {}, primary_profiles = {},
	landmarks = {}, stations = {}, anchors = {}, hard_protection = {}, routes = {},
	route_exact_pins = {}, route_water_lower_bounds = {},
	route_raise_witnesses = {}, ford_approaches = {},
	ford_approach_summaries = {}, named_water_operations = {},
	derived_water_runs = {}, landings = {}, tunnels = {},
	hydrology = {}, interfaces = {},
	exterior_witnesses = {
		{kind = "bay", x = 1, z = 1, terrain_y = -23, water_y = 1},
		{kind = "coastal_shelf", x = 2, z = 2, terrain_y = -23, water_y = 1},
		{kind = "deep_ocean", x = 3, z = 3, terrain_y = -23, water_y = 1},
		{kind = "immutable_dragon_channel", x = 4, z = 4,
			terrain_y = -23, water_y = 1},
	}, coastal_cores = {},
	source_cut_fill_limits_consumed = false,
	operation_counts = {tunnel_named_operation_overlap_columns = 0},
	operation_digest = empty_digest, route_digest = empty_digest,
	visible_surface_classification_digest = empty_digest,
}
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end
local mock = {}
function mock.relief_lattice_digest() return empty_digest end
function mock.canonical_kat() return "kat" end
function mock.canonical_kat_digest() return kat_digest end
function mock.artifact_evidence() return copy(evidence) end
function mock.metrics()
	return {query_sha256_calls = 0, query_lattice_constructions = 0}
end
for _, name in ipairs({"terrain_height_at", "water_surface_at",
	"functional_surface_values_at", "hydrology_transition_values_at",
	"selected_anchor_3d_by_id", "hard_protection_volumes"}) do
	mock[name] = function() return nil end
end
function mock.terrain_height_at() return -23 end
function mock.water_surface_at() return 1 end
local validator = dofile(repo .. "/tools/wp40/simple_map_r3_validate.lua")(common)
validator.validate_api(mock, offline.raw_sha256)
validator.validate_evidence(mock, {
	relief_profiles = {}, landmarks = {}, anchors = {}, hard_protection = {},
	anchor_profiles = {}, zones = {}, route_stations = {}, crossing_interfaces = {},
	routes = {}, poi_spurs = {}, island_routes = {}, hydrology = {},
	hydrology_interfaces = {}, coastal_housing_cores = {}, island_landings = {},
})

-- A transition-only waterfall supplies causeway clearance without inventing
-- an analytic scalar water surface. The same nil under any other transition
-- must remain fail-closed.
evidence.routes = {{id = "poi_spur_045", kind = "selected_poi_spur",
	node_count = 3, baseline_min_y = 65, baseline_max_y = 65,
	final_min_y = 65, final_max_y = 66, maximum_step = 1,
	exact_pin_count = 2, water_lower_bound_run_count = 1,
	water_lower_bound_column_count = 3, raised_run_count = 1,
	support_witness_count = 1, baseline_digest = empty_digest,
	final_grade_digest = empty_digest, exact_pin_digest = empty_digest,
	lower_bound_digest = empty_digest, classification_digest = empty_digest}}
evidence.route_exact_pins = {
	{path_id = "poi_spur_045", run = 1, pin_kind = "anchor_endpoint",
		source_id = "anchor_test", y = 65, baseline_y = 65, final_y = 65},
	{path_id = "poi_spur_045", run = 3, pin_kind = "station_endpoint",
		source_id = "zone_test", y = 65, baseline_y = 65, final_y = 65},
}
evidence.route_water_lower_bounds = {{path_id = "poi_spur_045", run = 2,
	column_count = 3, lower_y = 66, witness_x = 1990, witness_z = 2090,
	bound_kind = "ordinary_water"}}
evidence.route_raise_witnesses = {{path_id = "poi_spur_045", run = 2,
	baseline_y = 65, final_y = 66, support_run = 2, support_lower_y = 66,
	support_x = 1990, support_z = 2090, support_kind = "ordinary_water"}}
evidence.derived_water_runs = {{path_id = "poi_spur_045", run = 2,
	causeway_columns = 3, bridge_columns = 0, causeway_witness_x = 1990,
	causeway_witness_z = 2090, classification_digest = empty_digest}}
local transition_kind = "waterfall"
function mock.hydrology_transition_values_at()
	return transition_kind, "raincall_upper_fall", 65, 53, 32768
end
function mock.water_surface_at(x)
	if x == 1990 then return nil end
	return 1
end
function mock.terrain_height_at(x)
	if x == 1990 then return 66 end
	return -23
end
function mock.functional_surface_values_at(x)
	if x == 1990 then return "causeway", 66, "poi_spur_045", nil end
	return nil, nil, nil, nil
end
local causeway_source = {
	relief_profiles = {}, landmarks = {}, anchors = {}, hard_protection = {},
	anchor_profiles = {}, zones = {}, route_stations = {}, crossing_interfaces = {},
	routes = {},
	poi_spurs = {{id = "poi_spur_045"}}, island_routes = {}, hydrology = {},
	hydrology_interfaces = {}, coastal_housing_cores = {}, island_landings = {},
}
validator.validate_evidence(mock, causeway_source)
transition_kind = "rapid"
local accepted_rapid_nil = pcall(validator.validate_evidence, mock,
	causeway_source)
assert(not accepted_rapid_nil)

print("WP40 simple-map R3 harness selftest passed")
