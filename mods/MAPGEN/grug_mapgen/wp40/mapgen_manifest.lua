-- Pure offline manifest authority for the disabled WP40 R5 adapter.

local MAX_SAFE = 9007199254740991
local VALIDATED_MARKER = "grug_wp40_r5_validated_manifest_v1"
local VALIDATED_METATABLE = {__metatable = VALIDATED_MARKER}
local validated_objects = setmetatable({}, {__mode = "k"})

local FIELD_ORDER = {
	"schema",
	"engine_commit",
	"mg_name",
	"water_level",
	"mapgen_limit",
	"chunksize",
	"central_owner_y_min",
	"central_owner_y_max",
	"heightmap_entries",
	"heightmap_sentinel",
	"heightmap_order",
	"emerge_threads",
	"engine_emerge_setting",
	"mg_flags",
	"mgv7_spflags",
	"mgv7_dungeon_ymin",
	"mgv7_dungeon_ymax",
	"authored_floor",
	"force_native_dungeon",
}

local EXPECTED = {
	schema = "grug_wp40_r5_mapgen_manifest_v1",
	engine_commit = "df04879066de6eb94ca43996822a6dfacc74feca",
	mg_name = "v7",
	water_level = 1,
	mapgen_limit = 31007,
	chunksize = 5,
	central_owner_y_min = -30912,
	central_owner_y_max = 30927,
	heightmap_entries = 6400,
	heightmap_sentinel = -31007,
	heightmap_order = "x_fast_z_outer",
	emerge_threads = 1,
	engine_emerge_setting = "num_emerge_threads",
	mg_flags = "biomes,caves,decorations,dungeons,light,ores",
	mgv7_spflags = "caverns,mountains,ridges",
	mgv7_dungeon_ymin = -31000,
	mgv7_dungeon_ymax = -193,
	authored_floor = -37,
	force_native_dungeon = false,
}

local function fail(message)
	error("fail_manifest: " .. message, 0)
end

local function integer(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or
			math.abs(value) > MAX_SAFE then
		fail(label .. " is not a finite safe integer")
	end
	return value
end

local function edge_formula(mapgen_limit, chunksize)
	local block_size = 16
	local maximum_mapgen_limit = 31007
	local limited = math.max(0, math.min(mapgen_limit,
		maximum_mapgen_limit))
	local limit_blocks = math.floor(limited / block_size)
	local limit_min = -limit_blocks * block_size
	local limit_max = (limit_blocks + 1) * block_size - 1
	-- C++ signed integer division truncates `-chunksize / 2` toward zero.
	local central_offset_blocks = math.ceil(-chunksize / 2)
	local chunk_nodes = chunksize * block_size
	local central_min = central_offset_blocks * block_size
	local central_max = central_min + chunk_nodes - 1
	local full_min = central_min - block_size
	local full_max = central_max + block_size
	local count_min = math.max(math.floor((full_min - limit_min) /
		chunk_nodes), 0)
	local count_max = math.max(math.floor((limit_max - full_max) /
		chunk_nodes), 0)
	return central_min - count_min * chunk_nodes,
		central_max + count_max * chunk_nodes
end

local function validate_values(values)
	if type(values) ~= "table" then fail("values are not a table") end
	local expected_fields = 0
	for index = 1, #FIELD_ORDER do
		local key = FIELD_ORDER[index]
		expected_fields = expected_fields + 1
		local value = rawget(values, key)
		local expected = EXPECTED[key]
		if value == nil then fail("missing field " .. key) end
		if type(value) ~= type(expected) or value ~= expected then
			fail("field " .. key .. " differs")
		end
		if type(value) == "number" then integer(value, key) end
	end
	local actual_fields = 0
	for key in pairs(values) do
		actual_fields = actual_fields + 1
		if EXPECTED[key] == nil then fail("unknown field " .. tostring(key)) end
	end
	if actual_fields ~= expected_fields then fail("field coverage differs") end
	local owner_min, owner_max = edge_formula(values.mapgen_limit,
		values.chunksize)
	if owner_min ~= values.central_owner_y_min or
			owner_max ~= values.central_owner_y_max or owner_min ~= -30912 or
			owner_max ~= 30927 then
		fail("pinned mapgen edge formula differs")
	end
	return true
end

local function validate(values)
	validate_values(values)
	local result = {}
	for index = 1, #FIELD_ORDER do
		local key = FIELD_ORDER[index]
		result[key] = values[key]
	end
	setmetatable(result, VALIDATED_METATABLE)
	validated_objects[result] = true
	return result
end

local function canonical_scalar(value)
	local kind = type(value)
	if kind == "string" then return value end
	if kind == "boolean" then return value and "true" or "false" end
	if kind == "number" then
		integer(value, "canonical manifest value")
		return string.format("%.0f", value)
	end
	fail("canonical manifest value is not scalar")
end

local function canonical_bytes(values)
	if not validated_objects[values] or
			getmetatable(values) ~= VALIDATED_MARKER then
		fail("validated manifest identity differs")
	end
	validate_values(values)
	local rows = {}
	for index = 1, #FIELD_ORDER do
		local key = FIELD_ORDER[index]
		rows[index] = key .. "\t" .. canonical_scalar(values[key]) .. "\n"
	end
	return table.concat(rows)
end

return {
	validate = validate,
	canonical_bytes = canonical_bytes,
}
