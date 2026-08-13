local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-schema%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local wp40_dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local sha_cache = {}
local sha_counter = 0

local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end

local function raw_sha256(data)
	local cached = sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/sha-" .. sha_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data))
	assert(file:close())
	assert(os.execute("sha256sum " .. input .. " > " .. output) == 0)
	file = assert(io.open(output, "rb"))
	local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
	assert(file:close())
	assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok, "expected error containing " .. fragment)
	assert(tostring(message):find(fragment, 1, true), tostring(message))
end

local canonical = dofile(wp40_dir .. "/canonical.lua")
local validation = dofile(wp40_dir .. "/validation.lua")
local schemas = dofile(wp40_dir .. "/schemas.lua")
local schema = dofile(wp40_dir .. "/compiled_schema.lua")
local source = dofile(wp40_dir .. "/source/catalog.lua")

local geometry_families = {
	"zones", "land_boundaries", "land_routes", "boat_routes",
	"perimeters", "bays", "mouth_apertures", "closure_wings",
	"dry_faces", "relief_fields", "templates", "anchors",
	"route_profiles", "hydrology", "coast_shelf", "islands", "channels",
	"hard_protection", "claim_exclusions", "housing_masks",
}
local selector_families = {
	"logical_biomes", "nearest_features", "housing_centers",
}

local function record(id, signed_value)
	local signed_values = {}
	if signed_value ~= nil then
		signed_values[1] = {name = "x", value = signed_value}
	end
	return {
		record_schema = "grug_wp40_test_record_v1", id = id,
		numeric_id = 7,
		text_values = {{name = "kind", value = "probe"}},
		signed_values = signed_values,
		unsigned_values = {{name = "count", value = 0}},
		boolean_values = {{name = "enabled", value = false}},
		text_arrays = {{name = "ids", values = {}}},
		signed_arrays = {{name = "offsets", values = {1, 0, -1}}},
		unsigned_arrays = {{name = "indices", values = {0, 1}}},
		candidates = {}, attributes = {},
	}
end

local function new_fixture(reverse, signed_value)
	local geometry = {}
	if reverse then
		for i = #geometry_families, 1, -1 do geometry[geometry_families[i]] = {} end
	else
		for i = 1, #geometry_families do geometry[geometry_families[i]] = {} end
	end
	geometry.zones = {record("zone_probe", signed_value or 1)}
	local selectors = {}
	if reverse then
		for i = #selector_families, 1, -1 do selectors[selector_families[i]] = {} end
	else
		for i = 1, #selector_families do selectors[selector_families[i]] = {} end
	end
	local spatial_index
	if reverse then
		spatial_index = {attributes = {}, candidates = {}, layers = {},
			max_cz = 1, min_cz = -1, max_cx = 1, min_cx = -1,
			cell_size = 128, schema = schemas.index}
	else
		spatial_index = {schema = schemas.index, cell_size = 128,
			min_cx = -1, max_cx = 1, min_cz = -1, max_cz = 1,
			layers = {}, candidates = {}, attributes = {}}
	end
	return {
		schema = schemas.compiled,
		algorithm_schema = schemas.compiled_algorithm,
		full_seed = "9007199254740993",
		geometry = geometry,
		selectors = selectors,
		spatial_index = spatial_index,
		coverage = {schema = schemas.coverage, geometry_volumes = {},
			resolver_interfaces = {}, pending = {t4 = {}, t6 = {}, t7 = {}}},
		release_fixtures = {seed_corpus = {}, extreme_slots = {},
			staging_seed = record("staging_seed"),
			microcorpus_classes_1_9 = {},
			requester_trace = record("requester_trace")},
	}
end

local semantic_ids = {"default:stone", "grug_materials:bronze_ore"}
local fixture = new_fixture(false, 1)
local projected = schema.canonicalize_compiled(fixture, semantic_ids, canonical)
local encoded = canonical.encode(projected)
local reordered = canonical.encode(schema.canonicalize_compiled(
	new_fixture(true, 1), semantic_ids, canonical))
assert(encoded == reordered, "map insertion order changed compiled bytes")
assert(canonical.hex(raw_sha256(encoded)) ==
	canonical.hex(raw_sha256(reordered)), "compiled checksum identity failed")

local function find_map_value(node, wanted)
	assert(node._wp40_type == "map")
	for i = 1, #node.value do
		local key, value = node.value[i][1], node.value[i][2]
		if key._wp40_type == "text" and key.value == wanted then return value end
	end
	error("canonical map key absent: " .. wanted)
end

-- The same coordinate field retains the signed tag for positive, zero, and
-- negative values. Empty candidates/pending lists are arrays; attributes is a
-- legitimate explicitly typed empty map.
for _, value in ipairs({1, 0, -1}) do
	local root = schema.canonicalize_compiled(new_fixture(false, value),
		semantic_ids, canonical)
	local data = find_map_value(root, "data")
	local geometry = find_map_value(data, "geometry")
	local zones = find_map_value(geometry, "zones")
	local zone = zones.value[1]
	local signed_values = find_map_value(zone, "signed_values")
	local signed_row = signed_values.value[1]
	local value_node = find_map_value(signed_row, "value")
	assert(value_node._wp40_type == "signed" and value_node.value == value)
	assert(find_map_value(zone, "candidates")._wp40_type == "array")
	assert(#find_map_value(zone, "candidates").value == 0)
	assert(find_map_value(zone, "attributes")._wp40_type == "map")
	assert(#find_map_value(zone, "attributes").value == 0)
end
do
	local data = find_map_value(projected, "data")
	local zone = find_map_value(find_map_value(data, "geometry"), "zones").value[1]
	assert(find_map_value(zone, "numeric_id")._wp40_type == "unsigned")
	assert(find_map_value(find_map_value(zone, "text_values").value[1],
		"value")._wp40_type == "text")
	assert(find_map_value(find_map_value(zone, "unsigned_values").value[1],
		"value")._wp40_type == "unsigned")
	assert(find_map_value(find_map_value(zone, "boolean_values").value[1],
		"value")._wp40_type == "unsigned")
	local text_array = find_map_value(find_map_value(zone,
		"text_arrays").value[1], "values")
	assert(text_array._wp40_type == "array" and #text_array.value == 0)
	local signed_array = find_map_value(find_map_value(zone,
		"signed_arrays").value[1], "values")
	for i = 1, #signed_array.value do
		assert(signed_array.value[i]._wp40_type == "signed")
	end
	local unsigned_array = find_map_value(find_map_value(zone,
		"unsigned_arrays").value[1], "values")
	for i = 1, #unsigned_array.value do
		assert(unsigned_array.value[i]._wp40_type == "unsigned")
	end
	local index = find_map_value(data, "spatial_index")
	assert(find_map_value(index, "min_cx")._wp40_type == "signed")
	assert(find_map_value(index, "cell_size")._wp40_type == "unsigned")
	local pending = find_map_value(find_map_value(data, "coverage"), "pending")
	assert(find_map_value(pending, "t4")._wp40_type == "array")
end

local function reject(fragment, mutate)
	local broken = validation.copy_graph(fixture)
	mutate(broken)
	expect_error(fragment, function()
		schema.canonicalize_compiled(broken, semantic_ids, canonical)
	end)
end

local top_fields = {"schema", "algorithm_schema", "full_seed", "geometry",
	"selectors", "spatial_index", "coverage", "release_fixtures"}
for i = 1, #top_fields do
	local field = top_fields[i]
	reject("missing field " .. field, function(value) value[field] = nil end)
end
reject("unknown field", function(value) value.unknown = true end)
reject("compiled schema identity mismatch", function(value)
	value.schema = "grug_wp40_compiled_world_v2"
end)
reject("compiled algorithm identity mismatch", function(value)
	value.algorithm_schema = "grug_wp40_compiled_geometry_v2"
end)

for i = 1, #geometry_families do
	local field = geometry_families[i]
	reject("geometry is missing field " .. field,
		function(value) value.geometry[field] = nil end)
	reject("not an array", function(value) value.geometry[field] = "bad" end)
	reject("not a dense array", function(value)
		value.geometry[field] = {[2] = record(field)}
	end)
end
reject("geometry has unknown field", function(value)
	value.geometry.second_authority = {}
end)
for i = 1, #selector_families do
	local field = selector_families[i]
	reject("selectors is missing field " .. field,
		function(value) value.selectors[field] = nil end)
	reject("not an array", function(value) value.selectors[field] = false end)
end
reject("selectors has unknown field", function(value)
	value.selectors.second_selector = {}
end)

local index_fields = {"schema", "cell_size", "min_cx", "max_cx", "min_cz",
	"max_cz", "layers", "candidates", "attributes"}
for i = 1, #index_fields do
	local field = index_fields[i]
	reject("spatial_index is missing field " .. field,
		function(value) value.spatial_index[field] = nil end)
end
reject("spatial_index has unknown field", function(value)
	value.spatial_index.neighbors = {}
end)
reject("not signed integer", function(value) value.spatial_index.min_cx = "0" end)
reject("signed value", function(value) value.spatial_index.min_cx = 2147483648 end)
reject("unsigned value", function(value) value.spatial_index.cell_size = -1 end)

local coverage_fields = {"schema", "geometry_volumes", "resolver_interfaces",
	"pending"}
for i = 1, #coverage_fields do
	local field = coverage_fields[i]
	reject("coverage is missing field " .. field,
		function(value) value.coverage[field] = nil end)
end
for _, field in ipairs({"t4", "t6", "t7"}) do
	reject("coverage.pending is missing field " .. field,
		function(value) value.coverage.pending[field] = nil end)
	reject("not an array",
		function(value) value.coverage.pending[field] = "future" end)
end
reject("coverage.pending has unknown field", function(value)
	value.coverage.pending.t8 = {}
end)
reject("coverage has unknown field", function(value)
	value.coverage.fake_complete = true
end)
reject("coverage schema identity mismatch", function(value)
	value.coverage.schema = "grug_wp40_deferred_coverage_v2"
end)

local release_fields = {"seed_corpus", "extreme_slots", "staging_seed",
	"microcorpus_classes_1_9", "requester_trace"}
for i = 1, #release_fields do
	local field = release_fields[i]
	reject("release_fixtures is missing field " .. field,
		function(value) value.release_fixtures[field] = nil end)
end
reject("release_fixtures has unknown field", function(value)
	value.release_fixtures.production_seed = record("invented")
end)

local record_fields = {"record_schema", "id", "numeric_id", "text_values",
	"signed_values", "unsigned_values", "boolean_values", "text_arrays",
	"signed_arrays", "unsigned_arrays", "candidates", "attributes"}
for i = 1, #record_fields do
	local field = record_fields[i]
	reject("missing field " .. field, function(value)
		value.geometry.zones[1][field] = nil
	end)
end
reject("has unknown field", function(value)
	value.geometry.zones[1].raw = {x = 1}
end)
reject("is not signed integer", function(value)
	value.geometry.zones[1].signed_values[1].value = "1"
end)
reject("multiple canonical types", function(value)
	value.geometry.zones[1].unsigned_values = {{name = "x", value = 1}}
end)
reject("names are not sorted unique", function(value)
	value.geometry.zones[1].signed_values = {
		{name = "z", value = 0}, {name = "x", value = 0}}
end)
reject("is not text", function(value)
	value.geometry.zones[1].text_values = {{name = "bad", value = function() end}}
end)
reject("has a metatable", function(value)
	setmetatable(value.geometry.zones[1], {})
end)
reject("cycle or mutable alias", function(value)
	value.geometry.land_boundaries = value.geometry.zones
end)
reject("cycle or mutable alias", function(value)
	value.release_fixtures.requester_trace.attributes =
		value.release_fixtures.staging_seed.attributes
end)
local metatable_data = new_fixture(false, 1)
setmetatable(metatable_data, {})
expect_error("has a metatable", function()
	schema.canonicalize_compiled(metatable_data, semantic_ids, canonical)
end)

expect_error("semantic_ids is not a dense array", function()
	schema.canonicalize_compiled(fixture,
		{[1] = "default:stone", [3] = "grug_materials:bronze_ore"}, canonical)
end)
expect_error("semantic_ids are not sorted unique", function()
	schema.canonicalize_compiled(fixture,
		{"grug_materials:bronze_ore", "default:stone"}, canonical)
end)
expect_error("semantic_ids are not sorted unique", function()
	schema.canonicalize_compiled(fixture,
		{"default:stone", "default:stone"}, canonical)
end)

-- Independently loaded offline/main/mapgen projectors produce identical bytes.
local function isolated_projector(state_name)
	local environment = {error = error, getmetatable = getmetatable,
		pairs = pairs, table = table, tostring = tostring, type = type,
		_STATE_NAME = state_name}
	environment._G = environment
	local chunk = assert(loadfile(wp40_dir .. "/compiled_schema.lua"))
	setfenv(chunk, environment)
	return chunk()
end
for _, projector in ipairs({isolated_projector("offline"),
		isolated_projector("main"), isolated_projector("mapgen")}) do
	assert(canonical.encode(projector.canonicalize_compiled(fixture,
		semantic_ids, canonical)) == encoded)
end

-- Stage prepare and consume receive the exact same canonicalizer identity.
local canonicalizer = schema.canonicalize_compiled
local source_canonical = canonical.map({
	{canonical.text("schema"), canonical.text(schemas.geometry_source)}})
local pass = function() return true end
local payload = validation.prepare({canonical = canonical,
	raw_sha256 = raw_sha256, transport_schema = schemas.transport,
	algorithm_schema = schemas.compiled_algorithm,
	geometry_schema = schemas.geometry_source,
	seed_hash = canonical.hex(raw_sha256("seed")),
	source_canonical = source_canonical,
	canonicalize_compiled = canonicalizer, record_counts = {zones = 38},
	critical_manifest = {chunksize = "5", emerge_threads = "1"},
	semantic_ids = semantic_ids, registration_resolver = function() return true end,
	data = fixture, stage1_validators = {pass}, stage2_validators = {pass}})
local expected = {transport_schema = schemas.transport,
	algorithm_schema = schemas.compiled_algorithm,
	geometry_schema = schemas.geometry_source, seed_hash = payload.seed_hash,
	source_checksum = payload.source_checksum,
	compiled_checksum = payload.compiled_checksum, record_counts = {zones = 38},
	critical_manifest = {chunksize = "5", emerge_threads = "1"}}
local function new_ipc(initial)
	local stored = validation.copy_graph(initial)
	return {ipc_get = function() return validation.copy_graph(stored) end}
end
local consumed = validation.consume(new_ipc(payload), schemas.ipc_key,
	expected, canonical, raw_sha256, function() return true end, canonicalizer)
assert(consumed.compiled_checksum == payload.compiled_checksum)
local coherent = validation.copy_graph(payload)
coherent.data.spatial_index.min_cx = -2
coherent.compiled_checksum = canonical.hex(canonical.checksum(
	canonicalizer(coherent.data, coherent.semantic_ids, canonical), raw_sha256))
expect_error("compiled_checksum", function()
	validation.consume(new_ipc(coherent), schemas.ipc_key, expected, canonical,
		raw_sha256, function() return true end, canonicalizer)
end)

local function source_vocabulary()
	local resources, grades, cultures, woods = {}, {}, {}, {}
	local assignments = source.semantics.race_region_assignments
	for i = 1, #assignments do
		local row = assignments[i]
		resources[row.g1], resources[row.g2] = true, true
		grades[row.g1], grades[row.g2] = "G1", "G2"
		cultures[row.cultural], woods[row.signature_wood] = true, true
	end
	local function keys(values)
		local result = {}
		for key in pairs(values) do result[#result + 1] = key end
		table.sort(result)
		return result
	end
	local resource_keys = keys(resources)
	local resource_rows = {}
	for i = 1, #resource_keys do
		resource_rows[i] = {key = resource_keys[i], scope = "regional",
			grade = grades[resource_keys[i]]}
	end
	return {resource_keys = resource_keys, resource_rows = resource_rows,
		cultural_keys = keys(cultures), wood_keys = keys(woods)}
end
local vocabulary = source_vocabulary()

-- Engine-free compiler access is test-only. It executes the same private trust
-- path and then fails because fixed geometry remains unavailable.
local offline_compiler = dofile(wp40_dir .. "/compiler.lua")(wp40_dir)
assert(type(offline_compiler.new_offline_test_adapter) == "function")
local offline_adapter = offline_compiler.new_offline_test_adapter({
	raw_sha256 = raw_sha256})
expect_error("compiled_geometry_unavailable", function()
	offline_adapter.compile("42", vocabulary)
end)
expect_error("exactly", function()
	offline_adapter.compile("42", vocabulary, {})
end)
expect_error("unknown field", function()
	offline_compiler.new_offline_test_adapter({raw_sha256 = raw_sha256,
		geometry_impl = function() end})
end)

-- The production foundation exports only a wrapper around a privately captured
-- compile closure. Exercise the real SHA/Stage1/canonical trust path, overwrite
-- every public handle, then call the already-captured consumer wrapper again.
local previous_core = rawget(_G, "core")
local captured_sha_calls = 0
local forged_sha_calls = 0
local production_core = {
	get_modpath = function(name)
		assert(name == "grug_mapgen")
		return repo .. "/mods/MAPGEN/grug_mapgen"
	end,
	sha256 = function(data, raw)
		assert(raw == true)
		captured_sha_calls = captured_sha_calls + 1
		return raw_sha256(data)
	end,
}
rawset(_G, "core", production_core)
local production_foundation = dofile(wp40_dir .. "/init.lua")(wp40_dir)
rawset(_G, "core", previous_core)
assert(production_foundation.enabled == false)
assert(production_foundation.compiler == nil)
assert(production_foundation.compiled_schema == nil)
assert(production_foundation.canonicalize_compiled == nil)
assert(production_foundation.new_offline_test_adapter == nil)
assert(production_foundation.trust_probe == nil)
local captured_wrapper = production_foundation.compile
expect_error("compiled_geometry_unavailable", function()
	captured_wrapper("42", vocabulary)
end)
assert(captured_sha_calls >= 2, "captured SHA/source/canonical path was not run")
local first_sha_calls = captured_sha_calls

production_core.get_modpath = function() return "/forged" end
production_core.sha256 = function()
	forged_sha_calls = forged_sha_calls + 1
	return string.rep("x", 32)
end
production_foundation.compile = function() return {forged = true} end
production_foundation.compiler = {compile = production_foundation.compile}
production_foundation.canonicalize_compiled = function() return nil end
production_foundation.canonical.checksum = function()
	forged_sha_calls = forged_sha_calls + 1
	return string.rep("y", 32)
end
production_foundation.deterministic.validate_seed = function() return true end
production_foundation.validation.prepare = function() return {forged = true} end
production_foundation.schemas.compiled = "forged_schema"
rawset(_G, "core", production_core)
expect_error("compiled_geometry_unavailable", function()
	captured_wrapper("42", vocabulary)
end)
rawset(_G, "core", previous_core)
assert(captured_sha_calls > first_sha_calls,
	"captured production SHA did not run after public mutation")
assert(forged_sha_calls == 0, "mutated global SHA replaced captured authority")
assert(production_foundation.compile().forged == true,
	"public mutation fixture did not actually replace the table field")
assert(production_foundation.enabled == false)
assert(production_foundation.disabled_reason ==
	"T2 compiled geometry is not installed")

print("WP40 T2 schema/core tests passed")
