-- World-aligned 128x128 candidate grid of half-open footprint boxes. Exact
-- shape membership remains with the caller; this module only compiles the
-- candidates and returns them per column.

local index128 = {}

local CELL_SIZE = 128
local MAX_SAFE = 9007199254740991
local EMPTY_CANDIDATES = {}

local function fail(message)
	error("WP40 index128: " .. message, 0)
end

local function integer(value, label, minimum, maximum)
	minimum = minimum or -MAX_SAFE
	maximum = maximum or MAX_SAFE
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail(label .. " is not an integer")
	end
	return value
end

local function floor_div(value)
	return math.floor(value / CELL_SIZE)
end

local function exact_fields(value, fields, label)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	local expected = {}
	for i = 1, #fields do expected[fields[i]] = true end
	for key in pairs(value) do
		if not expected[key] then fail(label .. " has unknown field " .. tostring(key)) end
	end
	for i = 1, #fields do
		if value[fields[i]] == nil then fail(label .. " is missing field " .. fields[i]) end
	end
	return value
end

local function text_id(value, label)
	if type(value) ~= "string" or value == "" then
		fail(label .. " is not non-empty text")
	end
	return value
end

local function safe_add(a, b, label)
	integer(a, label .. " left")
	integer(b, label .. " right")
	if (b > 0 and a > MAX_SAFE - b) or (b < 0 and a < -MAX_SAFE - b) then
		fail(label .. " is outside the exact Lua integer range")
	end
	return a + b
end

local function dense_count(values, label)
	if type(values) ~= "table" then fail(label .. " is not an array") end
	local count = #values
	for i = 1, count do
		if values[i] == nil then fail(label .. " has a hole") end
	end
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	return count
end

local function validate_bbox(bbox)
	if type(bbox) ~= "table" then fail("record bbox missing") end
	integer(bbox.min_x, "bbox min_x")
	integer(bbox.max_x, "bbox max_x")
	integer(bbox.min_z, "bbox min_z")
	integer(bbox.max_z, "bbox max_z")
	if bbox.min_x >= bbox.max_x or bbox.min_z >= bbox.max_z then
		fail("record bbox is not half-open and non-empty")
	end
end

local function sparse_bounds(definition, label)
	local min_x = integer(definition.min_x, label .. " min_x")
	local max_x = integer(definition.max_x, label .. " max_x")
	local min_z = integer(definition.min_z, label .. " min_z")
	local max_z = integer(definition.max_z, label .. " max_z")
	if min_x > max_x or min_z > max_z then fail(label .. " bounds are empty") end
	safe_add(max_x, 1, label .. " max_x half-open bound")
	safe_add(max_z, 1, label .. " max_z half-open bound")
	return min_x, max_x, min_z, max_z
end

local function new_sparse_cells(min_x, max_x, min_z, max_z)
	return {}, floor_div(min_x), floor_div(max_x), floor_div(min_z),
		floor_div(max_z)
end

local function add_sparse_candidate(compiled, cx, cz, candidate)
	local column = compiled.cells[cx]
	if not column then
		column = {}
		compiled.cells[cx] = column
	end
	local cell = column[cz]
	if not cell then
		cell = {}
		column[cz] = cell
		compiled.metrics.populated_cells = compiled.metrics.populated_cells + 1
	end
	cell[#cell + 1] = candidate
	compiled.metrics.candidate_references =
		compiled.metrics.candidate_references + 1
end

local function check_sparse_schema(definition, expected_schema, label)
	if type(expected_schema) ~= "string" or expected_schema == "" then
		fail("expected " .. label .. " schema missing")
	end
	if definition.schema ~= expected_schema then fail(label .. " schema mismatch") end
end

-- Compile complete half-open footprint bboxes. Exact shape membership remains
-- with the caller; this layer only returns borrowed, read-only candidate IDs.
function index128.compile_footprints(definition, expected_schema)
	exact_fields(definition, {"schema", "min_x", "max_x", "min_z", "max_z",
		"records"}, "footprint definition")
	check_sparse_schema(definition, expected_schema, "footprint")
	local min_x, max_x, min_z, max_z = sparse_bounds(definition, "footprint")
	local cells, min_cx, max_cx, min_cz, max_cz =
		new_sparse_cells(min_x, max_x, min_z, max_z)
	local compiled = {
		_index128_kind = "footprints",
		schema = definition.schema,
		cell_size = CELL_SIZE,
		min_x = min_x, max_x = max_x, min_z = min_z, max_z = max_z,
		min_cx = min_cx, max_cx = max_cx,
		min_cz = min_cz, max_cz = max_cz,
		cells = cells,
		metrics = {record_count = 0, populated_cells = 0,
			candidate_references = 0, maximum_candidates = 0},
	}
	local record_count = dense_count(definition.records, "footprint records")
	local ids = {}
	for record_index = 1, record_count do
		local input = exact_fields(definition.records[record_index], {"id", "bbox"},
			"footprint record")
		local id = text_id(input.id, "footprint id")
		if ids[id] then fail("duplicate footprint id " .. id) end
		ids[id] = true
		exact_fields(input.bbox, {"min_x", "max_x", "min_z", "max_z"},
			"footprint bbox")
		validate_bbox(input.bbox)
		if input.bbox.min_x < min_x or input.bbox.max_x > max_x + 1 or
				input.bbox.min_z < min_z or input.bbox.max_z > max_z + 1 then
			fail("footprint bbox is outside query bounds")
		end
		local first_cx, last_cx = floor_div(input.bbox.min_x),
			floor_div(input.bbox.max_x - 1)
		local first_cz, last_cz = floor_div(input.bbox.min_z),
			floor_div(input.bbox.max_z - 1)
		for cx = first_cx, last_cx do
			for cz = first_cz, last_cz do
				add_sparse_candidate(compiled, cx, cz, id)
			end
		end
	end
	for _, column in pairs(compiled.cells) do
		for _, candidates in pairs(column) do
			table.sort(candidates)
			for index = 2, #candidates do
				if candidates[index - 1] == candidates[index] then
					fail("duplicate footprint cell candidate")
				end
			end
			compiled.metrics.maximum_candidates = math.max(
				compiled.metrics.maximum_candidates, #candidates)
		end
	end
	compiled.metrics.record_count = record_count
	return compiled
end

-- The candidate ids of a column (a borrowed, read-only list). The callers
-- (zones.lua per planner column, world_protection.lua) pass integer node
-- coordinates, so the hot path does not validate them again.
function index128.footprint_candidates(compiled, x, z)
	if x < compiled.min_x or x > compiled.max_x or
			z < compiled.min_z or z > compiled.max_z then
		return EMPTY_CANDIDATES
	end
	local column = compiled.cells[floor_div(x)]
	if not column then return EMPTY_CANDIDATES end
	return column[floor_div(z)] or EMPTY_CANDIDATES
end

function index128.sparse_metrics(compiled)
	if type(compiled) ~= "table" or compiled._index128_kind ~= "footprints" then
		fail("compiled sparse index is invalid")
	end
	local result = {kind = compiled._index128_kind, schema = compiled.schema,
		cell_size = CELL_SIZE, min_x = compiled.min_x, max_x = compiled.max_x,
		min_z = compiled.min_z, max_z = compiled.max_z}
	for key, value in pairs(compiled.metrics) do result[key] = value end
	return result
end

return index128
