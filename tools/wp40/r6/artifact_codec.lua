-- Strict codec for the fixed 23-column WP40 R6 artifact ledger.

local codec = {}

local MAX_SAFE = 9007199254740991
local MAX_DATA_ROWS = 900000
local MAX_FILE_BYTES = 512 * 1024 * 1024
local TRAILER_TYPE = "artifact_body_sha256"

local HEADER = {
	"row_type", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8",
	"k9", "k10", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8",
	"v9", "v10", "v11", "v12",
}
local HEADER_LINE = table.concat(HEADER, "\t")

local function fail(message)
	error("WP40 R6 fail_ledger: " .. message, 0)
end

local function less_bytes(left, right)
	local count = math.min(#left, #right)
	for index = 1, count do
		local left_byte, right_byte = string.byte(left, index), string.byte(right, index)
		if left_byte ~= right_byte then return left_byte < right_byte end
	end
	return #left < #right
end

local function safe_scalar(value, label)
	if type(value) ~= "string" or value:find("\0", 1, true) or
			value:find("\t", 1, true) or value:find("\r", 1, true) or
			value:find("\n", 1, true) then
		fail(label .. " is not a length-safe scalar")
	end
	return value
end

local function nonempty(value, label)
	safe_scalar(value, label)
	if value == "" then fail(label .. " is empty") end
	return value
end

local function unsigned(value, label)
	nonempty(value, label)
	if value ~= "0" and not value:match("^[1-9][0-9]*$") then
		fail(label .. " is not minimal unsigned decimal")
	end
	return value
end

local function signed(value, label)
	nonempty(value, label)
	if value ~= "0" and not value:match("^-?[1-9][0-9]*$") then
		fail(label .. " is not minimal signed decimal")
	end
	return value
end

local function positive(value, label)
	unsigned(value, label)
	if value == "0" then fail(label .. " is not positive") end
	return value
end

local function boolean(value, label)
	if value ~= "true" and value ~= "false" then
		fail(label .. " is not canonical boolean text")
	end
	return value
end

local function sha256(value, label)
	if type(value) ~= "string" or not value:match("^[0-9a-f]+$") or
			#value ~= 64 then
		fail(label .. " is not lowercase SHA-256")
	end
	return value
end

local function gcd(a, b)
	while b ~= 0 do a, b = b, a % b end
	return a
end

local function ratio(value, label)
	nonempty(value, label)
	local numerator_text, denominator_text = value:match("^(-?[0-9]+)/([0-9]+)$")
	if not numerator_text or not denominator_text then
		fail(label .. " is not a canonical ratio")
	end
	signed(numerator_text, label .. " numerator")
	positive(denominator_text, label .. " denominator")
	local numerator = tonumber(numerator_text)
	local denominator = tonumber(denominator_text)
	if not numerator or not denominator or math.abs(numerator) > MAX_SAFE or
			denominator > MAX_SAFE then
		fail(label .. " ratio exceeds exact integer bounds")
	end
	if numerator == 0 then
		if denominator ~= 1 then fail(label .. " zero ratio is not reduced") end
	elseif gcd(math.abs(numerator), denominator) ~= 1 then
		fail(label .. " ratio is not reduced")
	end
	return value
end

local function optional(validator)
	return function(value, label)
		if value == "" then return value end
		return validator(value, label)
	end
end

local function one_of(values)
	local accepted = {}
	for index = 1, #values do accepted[values[index]] = true end
	return function(value, label)
		if not accepted[value] then fail(label .. " has an unknown token") end
		return value
	end
end

local scalar = nonempty
local text = nonempty
local opt_text = optional(nonempty)
local opt_unsigned = optional(unsigned)
local opt_signed = optional(signed)
local opt_sha256 = optional(sha256)
local metric = function(value, label)
	nonempty(value, label)
	if value == "true" or value == "false" then return boolean(value, label) end
	if value:find("/", 1, true) then return ratio(value, label) end
	return signed(value, label)
end

local function spec(keys, values)
	return {keys = keys, values = values}
end

local FAMILY_SPECS = {
	identity = spec({text}, {scalar}),
	input_sha256 = spec({text}, {sha256, unsigned}),
	vocabulary = spec({text, unsigned}, {text}),
	content = spec({unsigned}, {text, unsigned, unsigned}),
	template = spec({unsigned, text, unsigned},
		{sha256, positive, positive, positive, positive}),
	fixed_projection = spec({text}, {sha256, sha256, unsigned}),
	seed = spec({positive}, {text, unsigned, text, scalar}),
	census_cell = spec({text, one_of({"lower", "frontier"}), signed, signed},
		{sha256, text, unsigned, unsigned}),
	substrate_class = spec({positive, text, one_of({"lower", "frontier"}),
		signed, signed, signed, text}, {unsigned, sha256}),
	-- The contract fixes the catalog_zero token but does not assign a literal
	-- token to a positive occurrence; the manifest validator closes that value.
	surface_coverage = spec({positive, text, text, text}, {unsigned}),
	resource_host = spec({positive, text, text, signed, signed, signed, text,
		text, text}, {unsigned}),
	resource_budget = spec({positive, text, text, signed, signed, signed, text,
		text, text}, {unsigned, positive, unsigned, unsigned, sha256}),
	resource_vein = spec({positive, text, text, signed, signed, signed, text,
		text, text}, {unsigned, unsigned, unsigned, unsigned}),
	resource_node = spec({positive, text, text, signed, signed, signed, text,
		text, text}, {unsigned, unsigned}),
	region_host = spec({positive, text, signed, signed, signed, text, text},
		{unsigned}),
	cultural_candidate = spec({positive, text,
		one_of({"ordinary", "concentrated"})}, {unsigned, unsigned, unsigned}),
	cultural_slot = spec({positive, text,
		one_of({"ordinary", "concentrated"})}, {unsigned, unsigned}),
	decoration_candidate = spec({positive, text, positive},
		{unsigned, unsigned, unsigned}),
	decoration_settlement = spec({positive, text, positive},
		{unsigned, unsigned, unsigned}),
	region_denominator = spec({text}, {positive}),
	region_opportunity = spec({text}, {unsigned, unsigned, boolean}),
	region_parity = spec({text, text},
		{unsigned, positive, unsigned, positive, unsigned, unsigned, boolean}),
	access = spec({text, text, opt_text, opt_text},
		{boolean, opt_unsigned, opt_text, opt_signed, opt_signed, opt_signed,
			opt_text}),
	rejection = spec({positive, text, text, text}, {unsigned}),
	allocation_metric = spec({text, text, text}, {metric, metric, boolean}),
	vm_metric = spec({text, text, text}, {metric, metric, boolean}),
	kat = spec({text, text}, {sha256, sha256, boolean}),
	gate = spec({text}, {boolean, sha256}),
}

local FAMILY_ORDER = {
	"identity", "input_sha256", "vocabulary", "content", "template",
	"fixed_projection", "seed", "census_cell", "substrate_class",
	"surface_coverage", "resource_host", "resource_budget", "resource_vein",
	"resource_node", "region_host", "cultural_candidate", "cultural_slot",
	"decoration_candidate", "decoration_settlement", "region_denominator",
	"region_opportunity", "region_parity", "access", "rejection",
	"allocation_metric", "vm_metric", "kat", "gate",
}

-- Closed R6 artifact population. Dynamic implementation inventories are frozen
-- by the accepted input/static manifests, so validation never degrades to a
-- merely nonempty-family check.
local EXPECTED_FAMILY_COUNTS = {
	identity = 20, input_sha256 = 38, vocabulary = 107, content = 77,
	template = 76, fixed_projection = 6, seed = 32, census_cell = 48,
	substrate_class = 32 * 384 * 4, surface_coverage = 32 * 104,
	resource_host = 32 * 384 * 15, resource_budget = 32 * 384 * 15,
	resource_vein = 32 * 384 * 15, resource_node = 32 * 384 * 15,
	region_host = 32 * 384, cultural_candidate = 32 * 6 * 2,
	cultural_slot = 32 * 6 * 2, decoration_candidate = 32 * 48,
	decoration_settlement = 32 * 48, region_denominator = 6,
	region_opportunity = 6, region_parity = 1, access = 52,
	rejection = 32 * (6 * 6 + 48 * 10 + 15 * 3), allocation_metric = 16,
	vm_metric = 38, kat = 3, gate = 20,
}

local MANDATORY_GATES = {
	"input_manifest", "vocabulary_manifest", "p7_p9_schema_fixture",
	"r2_r5_projection", "complete_ledgers", "region_natural_density_parity",
	"ordinary_camp_equality", "access_native_region",
	"access_opposing_frontier", "access_deep_cross_border",
	"access_island_apex", "access_cultural", "content_coverage",
	"apex_nonoverlap", "fixed_housing_projection", "allocation_bounds",
	"disabled_single_writer", "static_gates", "micro_kat_parity",
	"not_owned_not_evaluated",
}
local MANDATORY_GATE_SET = {}
for index = 1, #MANDATORY_GATES do
	MANDATORY_GATE_SET[MANDATORY_GATES[index]] = true
end

local function split_line(line, label)
	if type(line) ~= "string" or line:find("\0", 1, true) or
			line:find("\r", 1, true) or line:find("\n", 1, true) then
		fail(label .. " is not one LF-delimited TSV line")
	end
	local fields = {}
	local start = 1
	for index = 1, 22 do
		local stop = line:find("\t", start, true)
		if not stop then fail(label .. " has fewer than 23 columns") end
		fields[index] = line:sub(start, stop - 1)
		start = stop + 1
	end
	if line:find("\t", start, true) then
		fail(label .. " has more than 23 columns")
	end
	fields[23] = line:sub(start)
	return fields
end

local function validate_data_fields(fields, label)
	if type(fields) ~= "table" or #fields ~= 23 then
		fail(label .. " does not contain 23 fields")
	end
	for index = 1, 23 do safe_scalar(fields[index], label .. " field " .. index) end
	local row_type = fields[1]
	local family = FAMILY_SPECS[row_type]
	if not family then fail(label .. " has unknown row family " .. row_type) end
	for index = 1, 10 do
		local value = fields[index + 1]
		local validator = family.keys[index]
		if validator then validator(value, label .. " k" .. index)
		elseif value ~= "" then fail(label .. " has a nonempty unused key") end
	end
	for index = 1, 12 do
		local value = fields[index + 11]
		local validator = family.values[index]
		if validator then validator(value, label .. " v" .. index)
		elseif value ~= "" then fail(label .. " has a nonempty unused value") end
	end
	return fields
end

local function dense_exact(values, count, label)
	if type(values) ~= "table" or #values ~= count then
		fail(label .. " population differs")
	end
	for index = 1, count do
		if values[index] == nil then fail(label .. " has a hole") end
	end
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	return values
end

local function decimal_number(value, label)
	if value ~= value or value == math.huge or value == -math.huge or
			value % 1 ~= 0 or math.abs(value) > MAX_SAFE then
		fail(label .. " number is not an exact safe integer")
	end
	return string.format("%.0f", value)
end

local function encode_scalar(value, label)
	if type(value) == "string" then return safe_scalar(value, label) end
	if type(value) == "boolean" then return value and "true" or "false" end
	if type(value) == "number" then return decimal_number(value, label) end
	fail(label .. " has unsupported scalar type")
end

function codec.header_line()
	return HEADER_LINE
end

function codec.header_bytes()
	return HEADER_LINE .. "\n"
end

function codec.parse_data_line(line, label)
	label = label or "artifact row"
	return validate_data_fields(split_line(line, label), label)
end

function codec.encode_data_row(row_type, keys, values)
	local family = FAMILY_SPECS[row_type]
	if not family then fail("cannot encode unknown row family " .. tostring(row_type)) end
	dense_exact(keys, #family.keys, row_type .. " keys")
	dense_exact(values, #family.values, row_type .. " values")
	local fields = {row_type}
	for index = 1, 10 do
		fields[index + 1] = index <= #keys and
			encode_scalar(keys[index], row_type .. " k" .. index) or ""
	end
	for index = 1, 12 do
		fields[index + 11] = index <= #values and
			encode_scalar(values[index], row_type .. " v" .. index) or ""
	end
	validate_data_fields(fields, row_type .. " encoded row")
	return table.concat(fields, "\t") .. "\n"
end

function codec.compare(left, right)
	for index = 1, 11 do
		if left[index] ~= right[index] then
			return less_bytes(left[index], right[index])
		end
	end
	return false
end

function codec.same_key(left, right)
	for index = 1, 11 do
		if left[index] ~= right[index] then return false end
	end
	return true
end


function codec.trailer_line(body_sha256)
	sha256(body_sha256, "artifact body SHA-256")
	local fields = {TRAILER_TYPE}
	for index = 1, 10 do fields[#fields + 1] = "" end
	fields[#fields + 1] = body_sha256
	for index = 2, 12 do fields[#fields + 1] = "" end
	return table.concat(fields, "\t") .. "\n"
end

function codec.parse_trailer_line(line)
	local fields = split_line(line, "artifact trailer")
	if fields[1] ~= TRAILER_TYPE then fail("final row is not the artifact trailer") end
	for index = 2, 11 do
		if fields[index] ~= "" then fail("artifact trailer key is nonempty") end
	end
	sha256(fields[12], "artifact trailer digest")
	for index = 13, 23 do
		if fields[index] ~= "" then fail("artifact trailer tail is nonempty") end
	end
	return fields[12]
end

function codec.new_inventory()
	local families = {}
	for index = 1, #FAMILY_ORDER do families[FAMILY_ORDER[index]] = 0 end
	return {families = families, gates = {}, seeds = {}, data_rows = 0}
end

function codec.observe(inventory, fields)
	local row_type = fields[1]
	inventory.data_rows = inventory.data_rows + 1
	if inventory.data_rows > MAX_DATA_ROWS then fail("artifact data-row bound exceeded") end
	inventory.families[row_type] = inventory.families[row_type] + 1
	if row_type == "gate" then
		local gate_id = fields[2]
		if not MANDATORY_GATE_SET[gate_id] then fail("unknown gate ID " .. gate_id) end
		if inventory.gates[gate_id] then fail("duplicate gate ID " .. gate_id) end
		if fields[12] ~= "true" then fail("mandatory gate is not passing: " .. gate_id) end
		inventory.gates[gate_id] = true
	elseif row_type == "seed" then
		local slot = tonumber(fields[2])
		if not slot or slot < 1 or slot > 32 or slot % 1 ~= 0 then
			fail("seed slot is outside 1..32")
		end
		if inventory.seeds[slot] then fail("duplicate seed slot " .. fields[2]) end
		inventory.seeds[slot] = true
	end
end

function codec.validate_complete(inventory)
	for index = 1, #FAMILY_ORDER do
		local family = FAMILY_ORDER[index]
		if inventory.families[family] ~= EXPECTED_FAMILY_COUNTS[family] then
			fail("required row family population differs: " .. family)
		end
	end
	for index = 1, #MANDATORY_GATES do
		local gate_id = MANDATORY_GATES[index]
		if not inventory.gates[gate_id] then fail("mandatory gate is absent: " .. gate_id) end
	end
	for slot = 1, 32 do
		if not inventory.seeds[slot] then fail("seed row is absent for slot " .. slot) end
	end
	return true
end

codec.MAX_DATA_ROWS = MAX_DATA_ROWS
codec.MAX_FILE_BYTES = MAX_FILE_BYTES
codec.TRAILER_TYPE = TRAILER_TYPE
codec.FAMILY_ORDER = FAMILY_ORDER
codec.EXPECTED_FAMILY_COUNTS = EXPECTED_FAMILY_COUNTS
codec.MANDATORY_GATES = MANDATORY_GATES

return codec
