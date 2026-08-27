-- Shared canonical and authority helpers for the WP40 simple-map R4 tools.

local common = {}

common.R2_BODY_SHA256 =
	"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b"
common.R2_FILE_SHA256 =
	"ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b"
common.R3_BODY_SHA256 =
	"09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2"
common.R3_FILE_SHA256 =
	"c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65"
common.R2_INPUT_COUNT = 15
common.R3_INPUT_COUNT = 13
common.AUTHORITY_INPUT_COUNT = 23
common.R2_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r2_artifact_v2"
common.R3_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r3_artifact_v1"
common.R4_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r4_artifact_v1"
common.SOURCE_SCHEMA = "grug_wp40_simple_map_source_v2"
common.HORIZONTAL_SCHEMA = "grug_wp40_simple_map_v1"
common.HEIGHT_SCHEMA = "grug_wp40_simple_map_height_v1"
common.ZONES_SCHEMA = "grug_wp40_zones_v1"
common.SPARSE_INDEX_SCHEMA = "grug_wp40_sparse_feature_index_v1"
common.LAYOUT_ID = "wp40-simple-map-v1d"
common.LAYOUT_REVISION_ID = "wp40-simple-map-v1e"
common.WATER_LEVEL = 1
common.MIN_X = -3740
common.MAX_X = 3740
common.MIN_Z = -3340
common.MAX_Z = 3340
common.COLUMN_COUNT = 49980561
common.MAX_SAFE = 9007199254740991
common.HOUSING_RESULT_SHA256 =
	"4e5676d86ba5226642476751509f78c5152ecbc429a8d1f4bb94e415289f26ec"
common.CANONICAL_SEEDS = {
	"0", "1", "9223372036854775808", "18446744073709551615",
}

local function fail(message)
	error("WP40 simple-map R4 harness: " .. message, 0)
end
common.fail = fail

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
		return ("%02x"):format(char:byte())
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

function common.digest(value, label)
	if type(value) ~= "string" or #value ~= 64 or
			not value:match("^[0-9a-f]+$") then
		fail((label or "digest") .. " is not lower-case SHA-256 hex")
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

function common.finite_number(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or math.abs(value) > common.MAX_SAFE then
		fail((label or "value") .. " is not a finite safe-range number")
	end
	return value
end

function common.normalize_node(value, label)
	common.finite_number(value, label or "coordinate")
	local base, result
	if value >= 0 then
		base = math.floor(value)
		result = value - base >= 0.5 and base + 1 or base
	else
		base = math.ceil(value)
		result = base - value >= 0.5 and base - 1 or base
	end
	return common.safe_integer(result, label or "normalized coordinate")
end

function common.normalize_xz(x, z)
	return common.normalize_node(x, "x"), common.normalize_node(z, "z")
end

function common.normalize_pos(pos)
	if type(pos) ~= "table" then fail("position is not a table") end
	return {
		x = common.normalize_node(pos.x, "position x"),
		y = common.normalize_node(pos.y, "position y"),
		z = common.normalize_node(pos.z, "position z"),
	}
end

function common.floor_div(value, divisor)
	common.safe_integer(value, "floor-div value")
	common.safe_integer(divisor, "floor-div divisor")
	if divisor <= 0 then fail("floor-div divisor is not positive") end
	return math.floor(value / divisor)
end

function common.round_ratio(numerator, denominator)
	common.safe_integer(numerator, "round numerator")
	common.safe_integer(denominator, "round denominator")
	if denominator <= 0 then fail("round denominator is not positive") end
	local sign = numerator < 0 and -1 or 1
	local magnitude = math.abs(numerator)
	local quotient = math.floor(magnitude / denominator)
	local remainder = magnitude - quotient * denominator
	if remainder >= denominator - remainder then quotient = quotient + 1 end
	return sign * quotient
end

function common.sorted_keys(value)
	if type(value) ~= "table" then fail("sorted-key value is not a table") end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		if ta == "number" or ta == "string" then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

function common.dense_count(value, label)
	if type(value) ~= "table" then
		fail((label or "value") .. " is not an array")
	end
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

local function canonical_number(value)
	common.finite_number(value, "canonical number")
	if value == 0 then return "0" end
	if value % 1 == 0 then return ("%.0f"):format(value) end
	return ("%.17g"):format(value)
end
common.canonical_number = canonical_number

local function scalar(value)
	if value == nil then return "-" end
	local kind = type(value)
	if kind == "boolean" then return value and "true" or "false" end
	if kind == "number" then
		common.safe_integer(value, "artifact number")
		return ("%.0f"):format(value)
	end
	if kind ~= "string" then fail("artifact scalar has unsupported type") end
	if value:find("[\t\r\n]") then fail("artifact scalar contains a separator") end
	return value
end
common.scalar = scalar

function common.new_tsv()
	local lines = {}
	local builder = {}
	function builder.add(...)
		local count = select("#", ...)
		local values = {}
		for index = 1, count do values[index] = scalar(select(index, ...)) end
		lines[#lines + 1] = table.concat(values, "\t")
	end
	function builder.add_raw(line)
		if type(line) ~= "string" or line == "" or line:find("[\r\n]") then
			fail("raw artifact line is invalid")
		end
		lines[#lines + 1] = line
	end
	function builder.body()
		return table.concat(lines, "\n") .. "\n"
	end
	return builder
end

function common.sort_canonical_rows(rows, label)
	common.dense_count(rows, label or "canonical rows")
	local decorated = {}
	for row_index = 1, #rows do
		local row = rows[row_index]
		local count = common.dense_count(row, label or "canonical row")
		local values = {}
		for index = 1, count do values[index] = scalar(row[index]) end
		decorated[row_index] = {
			key = table.concat(values, "\t"),
			index = row_index,
			row = row,
		}
	end
	table.sort(decorated, function(a, b)
		if a.key ~= b.key then return a.key < b.key end
		return a.index < b.index
	end)
	for row_index = 1, #decorated do
		rows[row_index] = decorated[row_index].row
	end
	return rows
end

local function path_component(value)
	value = tostring(value)
	value = value:gsub("%%", "%%25")
	value = value:gsub("/", "%%2f")
	value = value:gsub("\t", "%%09")
	value = value:gsub("\r", "%%0d")
	value = value:gsub("\n", "%%0a")
	return value
end
common.path_component = path_component

local function flatten(builder, path, value, active)
	local kind = type(value)
	if kind ~= "table" then
		if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then
			fail("unsupported evidence scalar at " .. path)
		end
		builder.add("evidence", path, kind, value)
		return
	end
	if active[value] then fail("cyclic artifact evidence at " .. path) end
	active[value] = true
	local count = #value
	local dense = true
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			dense = false
			break
		end
	end
	if dense then
		builder.add("evidence_array", path, count)
		for index = 1, count do
			flatten(builder, path .. "/" .. ("%06d"):format(index),
				value[index], active)
		end
	else
		local keys = common.sorted_keys(value)
		builder.add("evidence_map", path, #keys)
		for index = 1, #keys do
			local key = keys[index]
			if type(key) ~= "string" then
				fail("evidence map key is not text at " .. path)
			end
			flatten(builder, path .. "/" .. path_component(key), value[key], active)
		end
	end
	active[value] = nil
end

function common.add_evidence_at(builder, path, evidence)
	if type(builder) ~= "table" or type(builder.add) ~= "function" then
		fail("evidence builder is invalid")
	end
	if type(path) ~= "string" or path == "" or path:find("[\t\r\n]") then
		fail("evidence path is invalid")
	end
	flatten(builder, path, evidence, {})
end

function common.add_evidence(builder, evidence)
	common.add_evidence_at(builder, "zones", evidence)
end

function common.finalize_artifact(raw_sha256, body)
	if type(body) ~= "string" or body == "" or body:sub(-1) ~= "\n" then
		fail("artifact body is not a non-empty newline-terminated string")
	end
	local digest = common.digest_hex(raw_sha256, body)
	return body .. "artifact_sha256\t" .. digest .. "\n", digest
end

local function divmod_nonnegative(numerator, denominator)
	local quotient = math.floor(numerator / denominator)
	local product = quotient * denominator
	while product > numerator do
		quotient = quotient - 1
		product = product - denominator
	end
	while numerator - product >= denominator do
		quotient = quotient + 1
		product = product + denominator
	end
	return quotient, numerator - product
end

function common.rational_compare(a, b, c, d)
	for _, row in ipairs({{a, "left numerator"}, {b, "left denominator"},
			{c, "right numerator"}, {d, "right denominator"}}) do
		common.safe_integer(row[1], row[2])
	end
	if a < 0 or c < 0 or b <= 0 or d <= 0 then
		fail("rational comparator requires non-negative numerators and positive denominators")
	end
	local direction = 1
	while true do
		local left, left_remainder = divmod_nonnegative(a, b)
		local right, right_remainder = divmod_nonnegative(c, d)
		if left < right then return -direction end
		if left > right then return direction end
		if left_remainder == 0 or right_remainder == 0 then
			if left_remainder == right_remainder then return 0 end
			return (left_remainder == 0 and -1 or 1) * direction
		end
		a, b = b, left_remainder
		c, d = d, right_remainder
		direction = -direction
	end
end

function common.raster_polyline(points)
	common.dense_count(points, "polyline")
	if #points < 2 then fail("polyline has fewer than two points") end
	local result = {}
	for segment = 1, #points - 1 do
		local a, b = points[segment], points[segment + 1]
		if type(a) ~= "table" or type(b) ~= "table" then
			fail("polyline point is not a table")
		end
		local ax = common.safe_integer(a.x, "polyline x")
		local az = common.safe_integer(a.z, "polyline z")
		local bx = common.safe_integer(b.x, "polyline x")
		local bz = common.safe_integer(b.z, "polyline z")
		local dx, dz = bx - ax, bz - az
		local steps = math.max(math.abs(dx), math.abs(dz))
		if steps == 0 then fail("polyline has a coincident segment") end
		local first = segment == 1 and 0 or 1
		for step = first, steps do
			result[#result + 1] = {
				x = ax + common.round_ratio(dx * step, steps),
				z = az + common.round_ratio(dz * step, steps),
			}
		end
	end
	return result
end

local function safe_relative_path(path)
	if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or
			path:find("\\", 1, true) or path:find("/" .. "/", 1, true) or
			path:find("[\t\r\n%z]") then
		fail("artifact input path is unsafe")
	end
	for component in path:gmatch("[^/]+") do
		if component == "." or component == ".." then
			fail("artifact input path contains traversal")
		end
	end
	return path
end

local function parse_artifact_bytes(raw_sha256, bytes, spec)
	if type(spec) ~= "table" then fail("artifact specification is missing") end
	if type(bytes) ~= "string" or bytes:find("\r", 1, true) then
		fail((spec.label or "artifact") .. " bytes are invalid")
	end
	common.digest(spec.body_sha256, (spec.label or "artifact") .. " body digest")
	common.digest(spec.file_sha256, (spec.label or "artifact") .. " file digest")
	if common.digest_hex(raw_sha256, bytes) ~= spec.file_sha256 then
		fail((spec.label or "artifact") .. " complete-file SHA-256 differs")
	end
	local body, embedded = bytes:match("^(.*\n)artifact_sha256\t([0-9a-f]+)\n$")
	if not body or embedded ~= spec.body_sha256 or
			common.digest_hex(raw_sha256, body) ~= spec.body_sha256 then
		fail((spec.label or "artifact") .. " body SHA-256 differs")
	end
	local inputs, input_count, bindings = {}, 0, {}
	local required = spec.required or {}
	for line in body:gmatch("([^\n]+)\n") do
		local path, expected = line:match(
			"^input_sha256\t([^\t]+)\t([0-9a-f]+)$")
		if path then
			safe_relative_path(path)
			common.digest(expected, (spec.label or "artifact") .. " input digest")
			if inputs[path] then fail("duplicate artifact input path " .. path) end
			inputs[path] = expected
			input_count = input_count + 1
		else
			local key, value = line:match("^([^\t]+)\t([^\t]+)$")
			if key and required[key] ~= nil then
				if bindings[key] ~= nil then
					fail("duplicate " .. (spec.label or "artifact") ..
						" binding " .. key)
				end
				bindings[key] = value
			end
		end
	end
	if input_count ~= spec.input_count then
		fail((spec.label or "artifact") .. " input population differs")
	end
	for key, expected in pairs(required) do
		if bindings[key] ~= tostring(expected) then
			fail((spec.label or "artifact") .. " binding differs: " .. key)
		end
	end
	return {inputs = inputs, input_count = input_count, bindings = bindings}
end
common.parse_artifact_bytes = parse_artifact_bytes

local R2_SPEC = {
	label = "accepted R2 artifact",
	body_sha256 = common.R2_BODY_SHA256,
	file_sha256 = common.R2_FILE_SHA256,
	input_count = common.R2_INPUT_COUNT,
	required = {
		schema = common.R2_ARTIFACT_SCHEMA,
		layout_id = common.LAYOUT_ID,
		layout_revision_id = common.LAYOUT_REVISION_ID,
		source_schema = common.SOURCE_SCHEMA,
		housing_result_sha256 = common.HOUSING_RESULT_SHA256,
	},
}

local R3_SPEC = {
	label = "accepted R3 artifact",
	body_sha256 = common.R3_BODY_SHA256,
	file_sha256 = common.R3_FILE_SHA256,
	input_count = common.R3_INPUT_COUNT,
	required = {
		schema = common.R3_ARTIFACT_SCHEMA,
		height_schema = common.HEIGHT_SCHEMA,
		layout_id = common.LAYOUT_ID,
		layout_revision_id = common.LAYOUT_REVISION_ID,
		source_schema = common.SOURCE_SCHEMA,
		seed = "0",
		project_water_level = tostring(common.WATER_LEVEL),
		r2_body_sha256 = common.R2_BODY_SHA256,
		r2_file_sha256 = common.R2_FILE_SHA256,
	},
}

local function verify_artifact(repo, raw_sha256, relative, spec)
	if type(repo) ~= "string" or repo:sub(1, 1) ~= "/" then
		fail("absolute repository root required")
	end
	local result = parse_artifact_bytes(raw_sha256,
		common.read_file(repo .. "/" .. relative), spec)
	for path, expected in pairs(result.inputs) do
		local actual = common.digest_hex(raw_sha256,
			common.read_file(repo .. "/" .. path))
		if actual ~= expected then
			fail((spec.label or "artifact") .. " input changed: " .. path)
		end
	end
	result.body_sha256 = spec.body_sha256
	result.file_sha256 = spec.file_sha256
	result.path = relative
	return result
end

function common.verify_r2(repo, raw_sha256)
	return verify_artifact(repo, raw_sha256,
		"docs/research/wp40-simple-map-r2-artifact.tsv", R2_SPEC)
end

function common.verify_r3(repo, raw_sha256)
	return verify_artifact(repo, raw_sha256,
		"docs/research/wp40-simple-map-r3-artifact.tsv", R3_SPEC)
end

function common.verify_authority(repo, raw_sha256)
	local r2 = common.verify_r2(repo, raw_sha256)
	local r3 = common.verify_r3(repo, raw_sha256)
	local inputs = {}
	for path, expected in pairs(r2.inputs) do inputs[path] = expected end
	for path, expected in pairs(r3.inputs) do
		if inputs[path] ~= nil and inputs[path] ~= expected then
			fail("R2/R3 input binding conflict: " .. path)
		end
		inputs[path] = expected
	end
	local input_count = 0
	for _ in pairs(inputs) do input_count = input_count + 1 end
	if input_count ~= common.AUTHORITY_INPUT_COUNT then
		fail("combined R2/R3 input population differs")
	end
	local visible = {
		["mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"] =
			"5d4e2726dabbb900e47e7a8bef2a225011e6b003f48de485f752cde88fc7c17f",
		["mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"] =
			"55e507a6e5b2d73bf23233d9ab5e515ad150dbce77c6dc6c158a6133f4e27dfc",
		["mods/MAPGEN/grug_mapgen/wp40/height.lua"] =
			"f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97",
		["mods/MAPGEN/grug_mapgen/wp40/schemas.lua"] =
			"1f3825d1b77972637c850fad32a56a3a0fe08962b14b6c1b107846b7b0004166",
	}
	for path, expected in pairs(visible) do
		if inputs[path] ~= expected then fail("accepted visible input differs: " .. path) end
	end
	return {
		r2 = r2,
		r3 = r3,
		inputs = inputs,
		input_count = input_count,
		water_level = common.WATER_LEVEL,
		layout_id = common.LAYOUT_ID,
		layout_revision_id = common.LAYOUT_REVISION_ID,
		source_schema = common.SOURCE_SCHEMA,
		horizontal_schema = common.HORIZONTAL_SCHEMA,
		height_schema = common.HEIGHT_SCHEMA,
	}
end

return common
