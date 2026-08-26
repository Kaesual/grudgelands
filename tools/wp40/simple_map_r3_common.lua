-- Shared canonical helpers for the WP40 simple-map R3 evidence harness.

local common = {}

common.R2_BODY_SHA256 =
	"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b"
common.R2_FILE_SHA256 =
	"ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b"
common.R2_INPUT_COUNT = 15
common.R2_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r2_artifact_v2"
common.R2_SOURCE_SCHEMA = "grug_wp40_simple_map_source_v2"
common.LAYOUT_ID = "wp40-simple-map-v1d"
common.LAYOUT_REVISION_ID = "wp40-simple-map-v1e"
common.R3_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r3_artifact_v1"
common.V1E_R3_PREFLIGHT_SCHEMA = "grug_wp40_simple_map_v1e_r3_preflight_v1"
common.HEIGHT_SCHEMA = "grug_wp40_simple_map_height_v1"
common.WATER_LEVEL = 1
common.MAX_SAFE = 9007199254740991

local function fail(message)
	error("WP40 simple-map R3 harness: " .. message, 0)
end

function common.read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

function common.write_file(path, bytes)
	local file = assert(io.open(path, "wb"))
	assert(file:write(bytes))
	assert(file:close())
	assert(common.read_file(path) == bytes, "artifact write verification failed")
end

function common.hex(bytes)
	if type(bytes) ~= "string" then fail("hex input is not bytes") end
	return (bytes:gsub(".", function(char)
		return ("%02x"):format(char:byte())
	end))
end

function common.digest_hex(raw_sha256, bytes)
	local digest = raw_sha256(bytes)
	if type(digest) ~= "string" or #digest ~= 32 then
		fail("SHA-256 seam did not return 32 bytes")
	end
	return common.hex(digest)
end

function common.safe_integer(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or
			math.abs(value) > common.MAX_SAFE then
		fail((label or "value") .. " is not a safe integer")
	end
	return value
end

function common.digest(value, label)
	if type(value) ~= "string" or not value:match("^[0-9a-f]+$") or
			#value ~= 64 then
		fail((label or "digest") .. " is not lower-case SHA-256 hex")
	end
	return value
end

function common.sorted_keys(value)
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		if ta == "number" then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
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

local function scalar(value)
	if value == nil then return "-" end
	if type(value) == "boolean" then return value and "true" or "false" end
	if type(value) == "number" then
		common.safe_integer(value, "artifact number")
	end
	local result = tostring(value)
	if result:find("[\t\r\n]") then fail("artifact scalar contains a line break") end
	return result
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

local function path_component(value)
	value = tostring(value)
	value = value:gsub("%%", "%%25")
	value = value:gsub("/", "%%2f")
	value = value:gsub("\t", "%%09")
	value = value:gsub("\r", "%%0d")
	value = value:gsub("\n", "%%0a")
	return value
end

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
			flatten(builder, path .. "/" .. ("%06d"):format(index), value[index], active)
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

function common.add_evidence(builder, evidence)
	flatten(builder, "height", evidence, {})
end

function common.add_evidence_at(builder, path, evidence)
	if type(path) ~= "string" or path == "" or path:find("[\t\r\n]") then
		fail("evidence path is invalid")
	end
	flatten(builder, path, evidence, {})
end

function common.verify_r2(repo, raw_sha256)
	local relative = "docs/research/wp40-simple-map-r2-artifact.tsv"
	local bytes = common.read_file(repo .. "/" .. relative)
	local file_digest = common.digest_hex(raw_sha256, bytes)
	if file_digest ~= common.R2_FILE_SHA256 then
		fail("accepted R2 artifact complete-file SHA-256 differs")
	end
	local body, embedded = bytes:match(
		"^(.*\n)artifact_sha256\t([0-9a-f]+)\n$")
	if not body or embedded ~= common.R2_BODY_SHA256 or
			common.digest_hex(raw_sha256, body) ~= common.R2_BODY_SHA256 then
		fail("accepted R2 artifact body SHA-256 differs")
	end
	local inputs, input_count = {}, 0
	local coastal_counts = {}
	local bound = {}
	for line in body:gmatch("([^\n]+)\n") do
		local path, expected = line:match(
			"^input_sha256\t([^\t]+)\t([0-9a-f]+)$")
		if path then
			if inputs[path] then fail("duplicate R2 input path " .. path) end
			common.digest(expected, "R2 input digest")
			local actual = common.digest_hex(raw_sha256,
				common.read_file(repo .. "/" .. path))
			if actual ~= expected then fail("accepted R2 input changed: " .. path) end
			inputs[path] = expected
			input_count = input_count + 1
		else
			local key, value = line:match("^([^\t]+)\t([^\t]+)$")
			if key == "schema" or key == "layout_id" or
					key == "layout_revision_id" or key == "source_schema" or
					key == "baseline_path_contact_roster_sha256" or
					key == "final_path_contact_roster_sha256" or
					key == "hydrology_contact_roster_sha256" or
					key == "claim_exclusion_roster_sha256" or
					key == "fixed_anchor_spur_roster_sha256" or
					key == "housing_result_sha256" then
				if bound[key] then fail("duplicate R2 binding " .. key) end
				bound[key] = value
			end
			local metric, metric_value = line:match(
				"^contact_metric\t([^\t]+)\t([^\t]+)$")
			if metric then bound["contact_metric:" .. metric] = metric_value end
			local id, reservations = line:match(
				"^coastal_core\t([^\t]+)\t[^\n]*\t([0-9]+)$")
			if id then coastal_counts[id] = assert(tonumber(reservations)) end
		end
	end
	if input_count ~= common.R2_INPUT_COUNT then
		fail("accepted R2 artifact does not bind exactly 15 inputs")
	end
	if bound.schema ~= common.R2_ARTIFACT_SCHEMA or
			bound.layout_id ~= common.LAYOUT_ID or
			bound.layout_revision_id ~= common.LAYOUT_REVISION_ID or
			bound.source_schema ~= common.R2_SOURCE_SCHEMA then
		fail("accepted R2 schema/layout binding differs")
	end
	if bound["contact_metric:new_contact_pairs"] ~= "0" or
			bound["contact_metric:final_contact_pairs"] ~= "532" or
			bound["contact_metric:baseline_contact_pairs"] ~= "533" then
		fail("accepted R2 path-contact result differs")
	end
	for _, key in ipairs({"baseline_path_contact_roster_sha256",
			"final_path_contact_roster_sha256","hydrology_contact_roster_sha256",
			"claim_exclusion_roster_sha256",
			"fixed_anchor_spur_roster_sha256","housing_result_sha256"}) do
		common.digest(bound[key], "R2 " .. key)
	end
	return {
		body_sha256 = common.R2_BODY_SHA256,
		file_sha256 = common.R2_FILE_SHA256,
		inputs = inputs,
		coastal_reservation_counts = coastal_counts,
		bindings = bound,
	}
end

function common.round_half_away(numerator, denominator)
	common.safe_integer(numerator, "round numerator")
	common.safe_integer(denominator, "round denominator")
	if denominator <= 0 then fail("round denominator is not positive") end
	local sign = numerator < 0 and -1 or 1
	local magnitude = math.abs(numerator)
	local quotient = math.floor(magnitude / denominator)
	local remainder = magnitude - quotient * denominator
	if remainder * 2 >= denominator then quotient = quotient + 1 end
	return sign * quotient
end

function common.raster_polyline(points)
	common.dense_count(points, "polyline")
	if #points < 2 then fail("polyline has fewer than two points") end
	local result = {}
	for segment = 1, #points - 1 do
		local a, b = points[segment], points[segment + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local steps = math.max(math.abs(dx), math.abs(dz))
		if steps == 0 then fail("polyline has a coincident segment") end
		local first = segment == 1 and 0 or 1
		for step = first, steps do
			result[#result + 1] = {
				x = a.x + common.round_half_away(dx * step, steps),
				z = a.z + common.round_half_away(dz * step, steps),
			}
		end
	end
	return result
end

return common
