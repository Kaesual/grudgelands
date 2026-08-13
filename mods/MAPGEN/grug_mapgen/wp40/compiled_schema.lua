-- Field-typed canonical projection for the immutable T2 compiled world. This
-- module owns the one compiled-data projection used by Stage 1/2 preparation
-- and Stage 3 consumption. It constructs T1 canonical nodes only.

local compiled_schema = {}

local EXPECTED_COMPILED_SCHEMA = "grug_wp40_compiled_world_v1"
local EXPECTED_ALGORITHM_SCHEMA = "grug_wp40_compiled_geometry_v1"
local EXPECTED_COVERAGE_SCHEMA = "grug_wp40_deferred_coverage_v1"

local GEOMETRY_FAMILIES = {
	"zones", "land_boundaries", "land_routes", "boat_routes",
	"perimeters", "bays", "mouth_apertures", "closure_wings",
	"dry_faces", "relief_fields", "templates", "anchors",
	"route_profiles", "hydrology", "coast_shelf", "islands", "channels",
	"hard_protection", "claim_exclusions", "housing_masks",
}

local SELECTOR_FAMILIES = {
	"logical_biomes", "nearest_features", "housing_centers",
}

local function fail(message)
	error("WP40 compiled schema: " .. message, 0)
end

local function scalar(kind)
	return {kind = kind}
end

local function array(element)
	return {kind = "array", element = element}
end

local function map(fields)
	local order = {}
	for i = 1, #fields do order[i] = fields[i][1] end
	return {kind = "map", fields = fields, order = order}
end

local TEXT = scalar("text")
local SIGNED = scalar("signed")
local UNSIGNED = scalar("unsigned")
local BOOLEAN = scalar("boolean")

local NAMED_TEXT = map({{"name", TEXT}, {"value", TEXT}})
local NAMED_SIGNED = map({{"name", TEXT}, {"value", SIGNED}})
local NAMED_UNSIGNED = map({{"name", TEXT}, {"value", UNSIGNED}})
local NAMED_BOOLEAN = map({{"name", TEXT}, {"value", BOOLEAN}})
local NAMED_TEXT_ARRAY = map({{"name", TEXT}, {"values", array(TEXT)}})
local NAMED_SIGNED_ARRAY = map({{"name", TEXT}, {"values", array(SIGNED)}})
local NAMED_UNSIGNED_ARRAY = map({{"name", TEXT}, {"values", array(UNSIGNED)}})

-- Compiled analytic families use a normalized, relational record. The bucket
-- holding a field fixes its canonical type; neither sign nor table contents
-- select a tag. Geometry slices add rows and references, not executable or
-- value-inferred subgraphs. `attributes` is an explicitly typed empty map.
local ANALYTIC_RECORD = map({
	{"record_schema", TEXT},
	{"id", TEXT},
	{"numeric_id", UNSIGNED},
	{"text_values", array(NAMED_TEXT)},
	{"signed_values", array(NAMED_SIGNED)},
	{"unsigned_values", array(NAMED_UNSIGNED)},
	{"boolean_values", array(NAMED_BOOLEAN)},
	{"text_arrays", array(NAMED_TEXT_ARRAY)},
	{"signed_arrays", array(NAMED_SIGNED_ARRAY)},
	{"unsigned_arrays", array(NAMED_UNSIGNED_ARRAY)},
	{"candidates", array(UNSIGNED)},
	{"attributes", map({})},
})

local function family_fields(names)
	local result = {}
	for i = 1, #names do result[i] = {names[i], array(ANALYTIC_RECORD)} end
	return result
end

local GEOMETRY = map(family_fields(GEOMETRY_FAMILIES))
local SELECTORS = map(family_fields(SELECTOR_FAMILIES))

local SPATIAL_INDEX = map({
	{"schema", TEXT},
	{"cell_size", UNSIGNED},
	{"min_cx", SIGNED}, {"max_cx", SIGNED},
	{"min_cz", SIGNED}, {"max_cz", SIGNED},
	{"layers", array(ANALYTIC_RECORD)},
	{"candidates", array(UNSIGNED)},
	{"attributes", map({})},
})

local COVERAGE = map({
	{"schema", TEXT},
	{"geometry_volumes", array(ANALYTIC_RECORD)},
	{"resolver_interfaces", array(ANALYTIC_RECORD)},
	{"pending", map({
		{"t4", array(ANALYTIC_RECORD)},
		{"t6", array(ANALYTIC_RECORD)},
		{"t7", array(ANALYTIC_RECORD)},
	})},
})

local RELEASE_FIXTURES = map({
	{"seed_corpus", array(ANALYTIC_RECORD)},
	{"extreme_slots", array(ANALYTIC_RECORD)},
	{"staging_seed", ANALYTIC_RECORD},
	{"microcorpus_classes_1_9", array(ANALYTIC_RECORD)},
	{"requester_trace", ANALYTIC_RECORD},
})

local COMPILED = map({
	{"schema", TEXT},
	{"algorithm_schema", TEXT},
	{"full_seed", TEXT},
	{"geometry", GEOMETRY},
	{"selectors", SELECTORS},
	{"spatial_index", SPATIAL_INDEX},
	{"coverage", COVERAGE},
	{"release_fixtures", RELEASE_FIXTURES},
})

local ROOT = map({
	{"data", COMPILED},
	{"semantic_ids", array(TEXT)},
})

local function exact_fields(value, descriptor, label)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
	local allowed = {}
	for i = 1, #descriptor.fields do allowed[descriptor.fields[i][1]] = true end
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then
			fail(label .. " has unknown field " .. tostring(key))
		end
	end
	for i = 1, #descriptor.fields do
		local field = descriptor.fields[i][1]
		if value[field] == nil then fail(label .. " is missing field " .. field) end
	end
end

local function dense_count(value, label)
	if type(value) ~= "table" then fail(label .. " is not an array") end
	if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
	local count = #value
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	for i = 1, count do
		if value[i] == nil then fail(label .. " has a hole") end
	end
	return count
end

local function project(value, descriptor, canonical, seen, label)
	local kind = descriptor.kind
	if kind == "text" then
		if type(value) ~= "string" then fail(label .. " is not text") end
		return canonical.text(value)
	elseif kind == "signed" then
		if type(value) ~= "number" then fail(label .. " is not signed integer") end
		return canonical.signed(value)
	elseif kind == "unsigned" then
		if type(value) ~= "number" then fail(label .. " is not unsigned integer") end
		return canonical.unsigned(value)
	elseif kind == "boolean" then
		if type(value) ~= "boolean" then fail(label .. " is not boolean") end
		return canonical.boolean(value)
	end
	if type(value) ~= "table" then fail(label .. " is not a table") end
	if seen[value] then fail(label .. " contains a cycle or mutable alias") end
	seen[value] = true
	if kind == "array" then
		local count = dense_count(value, label)
		local children = {}
		for i = 1, count do
			children[i] = project(value[i], descriptor.element, canonical, seen,
				label .. "[" .. i .. "]")
		end
		return canonical.array(children)
	elseif kind == "map" then
		exact_fields(value, descriptor, label)
		local rows = {}
		for i = 1, #descriptor.fields do
			local field = descriptor.fields[i]
			rows[i] = {canonical.text(field[1]), project(value[field[1]], field[2],
				canonical, seen, label .. "." .. field[1])}
		end
		return canonical.map(rows)
	end
	fail(label .. " has unknown schema descriptor " .. tostring(kind))
end

local function validate_named_fields(record, label)
	local lists = {
		{"text_values", "text"}, {"signed_values", "signed"},
		{"unsigned_values", "unsigned"}, {"boolean_values", "boolean"},
		{"text_arrays", "text_array"}, {"signed_arrays", "signed_array"},
		{"unsigned_arrays", "unsigned_array"},
	}
	local seen = {}
	for list_index = 1, #lists do
		local field, field_kind = lists[list_index][1], lists[list_index][2]
		local rows = record[field]
		local count = dense_count(rows, label .. "." .. field)
		local previous
		for i = 1, count do
			local row = rows[i]
			if type(row) ~= "table" or type(row.name) ~= "string" or
					row.name == "" then
				fail(label .. "." .. field .. " has invalid field name")
			end
			if previous ~= nil and previous >= row.name then
				fail(label .. "." .. field .. " names are not sorted unique")
			end
			if seen[row.name] then
				fail(label .. " field " .. row.name .. " has multiple canonical types")
			end
			seen[row.name] = field_kind
			previous = row.name
		end
	end
end

local function validate_analytic_records(value, descriptor, label)
	if descriptor == ANALYTIC_RECORD then
		exact_fields(value, ANALYTIC_RECORD, label)
		validate_named_fields(value, label)
		if value.record_schema == "" or value.id == "" then
			fail(label .. " record identities are empty")
		end
	end
	if descriptor.kind == "array" then
		local count = dense_count(value, label)
		for i = 1, count do
			validate_analytic_records(value[i], descriptor.element,
				label .. "[" .. i .. "]")
		end
	elseif descriptor.kind == "map" then
		exact_fields(value, descriptor, label)
		for i = 1, #descriptor.fields do
			local field = descriptor.fields[i]
			validate_analytic_records(value[field[1]], field[2],
				label .. "." .. field[1])
		end
	end
end

function compiled_schema.canonicalize_compiled(data, semantic_ids, canonical)
	if type(canonical) ~= "table" or type(canonical.map) ~= "function" or
			type(canonical.array) ~= "function" or
			type(canonical.text) ~= "function" or
			type(canonical.signed) ~= "function" or
			type(canonical.unsigned) ~= "function" or
			type(canonical.boolean) ~= "function" then
		fail("T1 canonical module is unavailable")
	end
	if type(data) ~= "table" then fail("compiled data is not a table") end
	exact_fields(data, COMPILED, "compiled root.data")
	if data.schema ~= EXPECTED_COMPILED_SCHEMA then
		fail("compiled schema identity mismatch")
	end
	if data.algorithm_schema ~= EXPECTED_ALGORITHM_SCHEMA then
		fail("compiled algorithm identity mismatch")
	end
	if type(data.full_seed) ~= "string" or data.full_seed == "" then
		fail("compiled full seed is not non-empty text")
	end
	exact_fields(data.coverage, COVERAGE, "compiled root.data.coverage")
	if data.coverage.schema ~= EXPECTED_COVERAGE_SCHEMA then
		fail("coverage schema identity mismatch")
	end
	local root = {data = data, semantic_ids = semantic_ids}
	validate_analytic_records(root, ROOT, "compiled root")
	local count = dense_count(semantic_ids, "semantic_ids")
	local previous
	for i = 1, count do
		local id = semantic_ids[i]
		if type(id) ~= "string" or id == "" or
				(previous ~= nil and previous >= id) then
			fail("semantic_ids are not sorted unique non-empty text")
		end
		previous = id
	end
	return project(root, ROOT, canonical, {}, "compiled root")
end

return compiled_schema
