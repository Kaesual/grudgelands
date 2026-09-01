-- Canonical WP40 R7 runtime evidence over the production-private facade.
-- This tool never implements placement policy: it encodes and compares the
-- planner/settlement decisions returned by r7_runtime.build(..., true).

local module = {schema = "grug_wp40_r7_runtime_adapter_v1"}

local MAX_SAFE = 9007199254740991
local INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z = -32, -32
local MULTI_Y_OWNER_X, MULTI_Y_OWNER_Z = -32, 48
local OWNER_MIN_X, OWNER_MAX_X = -3792, 3728
local OWNER_MIN_Z, OWNER_MAX_Z = -3392, 3328
local QUERY_MIN_X, QUERY_MAX_X = -3740, 3740
local QUERY_MIN_Z, QUERY_MAX_Z = -3340, 3340
local SAMPLE_SCHEMA = "grug_wp40_r7_stratified_owner_sample_v1"
local SAMPLE_OWNER_COUNT = 128
local SAMPLE_LATTICE_COUNT = 104
local SAMPLE_RISK_COUNT = 24
local FRONTIER_ACCESS_SCHEMA = "grug_wp40_r7_frontier_access_roster_v1"
local FRONTIER_ACCESS_OWNER_COUNT = 458
local FRONTIER_ACCESS_COLUMN_COUNT = 2931200
local FRONTIER_ACCESS_SEED_SLOTS = {1, 6, 11, 17, 22, 27, 32}
local FRONTIER_ACCESS_SEED_SET = {}
for index = 1, #FRONTIER_ACCESS_SEED_SLOTS do
	FRONTIER_ACCESS_SEED_SET[FRONTIER_ACCESS_SEED_SLOTS[index]] = true
end
local FRONTIER_ACCESS_ENVELOPES = {
	{"front_gravesalt_escarpment", -2500, -1200, -250, 250},
	{"front_skyglass_canopy", 1200, 2500, -250, 250},
	{"front_stormscale_summit", 2800, 3500, -400, 390},
	{"front_wyrmglass_crown", -3500, -2800, -390, 380},
}
local FRONTIER_ACCESS_SOURCES = {
	"wp33_crimson_lotus_source_v1",
	"wp33_rock_salt_source_v1",
	"wp33_stormkelp_source_v1",
	"wp33_wild_cocoa_source_v1",
}
local FRONTIER_ACCESS_SOURCE_SET, FRONTIER_ACCESS_ZONE_SET = {}, {}
for index = 1, #FRONTIER_ACCESS_SOURCES do
	FRONTIER_ACCESS_SOURCE_SET[FRONTIER_ACCESS_SOURCES[index]] = true
end
for index = 1, #FRONTIER_ACCESS_ENVELOPES do
	FRONTIER_ACCESS_ZONE_SET[FRONTIER_ACCESS_ENVELOPES[index][1]] = true
end
local MAIN_PAIRED_ACCESS_SOURCE_SET = {
	wp33_dragonweed_source_v1 = true,
	wp33_gravemoss_source_v1 = true,
	wp33_marshbloom_source_v1 = true,
	wp33_sunleaf_source_v1 = true,
}
local SAMPLE_RISK_OWNERS = {
	{"cultural_dwarf_concentrated", -1712, -1152},
	{"cultural_dwarf_ordinary", -2032, -2992},
	{"cultural_elf_concentrated", 1328, -1152},
	{"cultural_elf_ordinary", 1728, -2992},
	{"cultural_human_concentrated", -432, -1152},
	{"cultural_human_ordinary", -192, -2992},
	{"cultural_orc_concentrated", -912, 208},
	{"cultural_orc_ordinary", -32, -272},
	{"cultural_troll_concentrated", 848, 208},
	{"cultural_troll_ordinary", 848, 608},
	{"cultural_undead_concentrated", -2432, 208},
	{"cultural_undead_ordinary", -2432, -272},
	{"boundary_northwest", -3792, -3392},
	{"boundary_northeast", 3728, -3392},
	{"boundary_southwest", -3792, 3328},
	{"boundary_southeast", 3728, 3328},
	{"integration_stage_ab", -32, -32},
	{"integration_multi_y", -32, 48},
	{"apex_wyrmglass", -3232, 48},
	{"apex_stormscale", 3168, 48},
	{"route_whitebridge_water", -432, -1552},
	{"route_broken_water", -432, -272},
	{"housing_copperfell_coast", -2272, -2272},
	{"housing_raincall_coast", 2288, 2128},
}
local ACCEPTED_R6_ARTIFACT_SHA256 =
	"bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4"
local P9G_REASONS = {
	"clipped_owner", "fixed_or_protected", "route_or_water",
	"housing_exclusion", "content_ignore", "wrong_zone", "wrong_biome",
	"wrong_shore", "wrong_support", "insufficient_clearance", "r6_occupancy",
}
local P9G_BRACKETS = {['1-10'] = true, ['11-20'] = true, ['21-30'] = true,
	['31-40'] = true, ['41-50'] = true, ['51-60'] = true}

local function fail(message)
	error("WP40 R7 runtime adapter: " .. message, 0)
end

local function integer(value, minimum, maximum, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum or math.abs(value) > MAX_SAFE then
		fail(label .. " is not an exact bounded integer")
	end
	return value
end

local function text(value, label)
	if type(value) ~= "string" or value == "" or
			value:find("\0", 1, true) or value:find("\t", 1, true) or
			value:find("\r", 1, true) or value:find("\n", 1, true) then
		fail(label .. " is not one nonempty TSV-safe string")
	end
	return value
end

local function digest(value, label)
	if type(value) ~= "string" or #value ~= 64 or
			not value:match("^[0-9a-f]+$") then
		fail(label .. " is not lowercase SHA-256")
	end
	return value
end

local function exact_fields(value, expected, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain table")
	end
	local actual_count, expected_count = 0, 0
	for key in pairs(value) do
		actual_count = actual_count + 1
		if not expected[key] then
			fail(label .. " has unknown field " .. tostring(key))
		end
	end
	for key in pairs(expected) do
		expected_count = expected_count + 1
		if rawget(value, key) == nil then fail(label .. " is missing " .. key) end
	end
	if actual_count ~= expected_count then fail(label .. " field count differs") end
	return value
end

local function dense(value, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain array")
	end
	local count = #value
	for index = 1, count do
		if value[index] == nil then fail(label .. " has a hole") end
	end
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not dense")
		end
		seen = seen + 1
	end
	if seen ~= count then fail(label .. " dense population differs") end
	return value
end

local function owner_column_count(owner_x, owner_z)
	integer(owner_x, OWNER_MIN_X, OWNER_MAX_X, "owner column-count x")
	integer(owner_z, OWNER_MIN_Z, OWNER_MAX_Z, "owner column-count z")
	if (owner_x - OWNER_MIN_X) % 80 ~= 0 or
			(owner_z - OWNER_MIN_Z) % 80 ~= 0 then
		fail("owner column-count coordinate is not aligned")
	end
	local width = math.min(owner_x + 79, QUERY_MAX_X) -
		math.max(owner_x, QUERY_MIN_X) + 1
	local depth = math.min(owner_z + 79, QUERY_MAX_Z) -
		math.max(owner_z, QUERY_MIN_Z) + 1
	if width < 1 or width > 80 or depth < 1 or depth > 80 then
		fail("owner column-count intersection is empty or oversized")
	end
	return width * depth
end

function module.owner_column_count_kat()
	local exact = {
		{OWNER_MIN_X, OWNER_MIN_Z, 784},
		{OWNER_MAX_X, OWNER_MIN_Z, 364},
		{OWNER_MIN_X, OWNER_MAX_Z, 364},
		{OWNER_MAX_X, OWNER_MAX_Z, 169},
		{OWNER_MIN_X, -32, 2240},
		{-32, OWNER_MIN_Z, 2240},
		{OWNER_MAX_X, -32, 1040},
		{-32, OWNER_MAX_Z, 1040},
		{-32, -32, 6400},
	}
	for index = 1, #exact do
		if owner_column_count(exact[index][1], exact[index][2]) ~= exact[index][3] then
			fail("owner column-count boundary KAT differs")
		end
	end
	local population, total = 0, 0
	for owner_z = OWNER_MIN_Z, OWNER_MAX_Z, 80 do
		for owner_x = OWNER_MIN_X, OWNER_MAX_X, 80 do
			population = population + 1
			total = total + owner_column_count(owner_x, owner_z)
		end
	end
	if population ~= 95 * 85 or total ~= 49980561 then
		fail("owner column-count closed population KAT differs")
	end
	for _, coordinates in ipairs({
		{OWNER_MIN_X + 1, OWNER_MIN_Z},
		{OWNER_MIN_X, OWNER_MIN_Z - 80},
		{OWNER_MAX_X + 80, OWNER_MAX_Z},
	}) do
		if pcall(owner_column_count, coordinates[1], coordinates[2]) then
			fail("owner column-count KAT accepted off-grid/outside coordinates")
		end
	end
	return true
end

local function less_bytes(left, right)
	local count = math.min(#left, #right)
	for index = 1, count do
		local a, b = string.byte(left, index), string.byte(right, index)
		if a ~= b then return a < b end
	end
	return #left < #right
end

local function scalar(value)
	if type(value) == "string" then
		-- This is a length-prefixed graph encoding, not a line format.  R6's
		-- production settlement maps deliberately use NUL-delimited composite
		-- keys, and every byte is unambiguous once the exact length is encoded.
		return "s" .. tostring(#value) .. ":" .. value
	elseif type(value) == "number" then
		integer(value, -MAX_SAFE, MAX_SAFE, "canonical number")
		return "n" .. string.format("%.0f", value) .. ";"
	elseif type(value) == "boolean" then
		return value and "b1;" or "b0;"
	end
	fail("canonical scalar type differs: " .. type(value))
end

local function graph(value, active)
	if type(value) ~= "table" then return scalar(value) end
	if getmetatable(value) ~= nil then fail("canonical graph has a metatable") end
	active = active or {}
	if active[value] then fail("canonical graph is cyclic") end
	active[value] = true
	local count, key_count, is_array = #value, 0, true
	for key in pairs(value) do
		key_count = key_count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			is_array = false
		end
	end
	if key_count ~= count then is_array = false end
	local result = {}
	if is_array then
		result[1] = "a" .. tostring(count) .. "["
		for index = 1, count do result[#result + 1] = graph(value[index], active) end
		result[#result + 1] = "]"
	else
		local entries = {}
		for key, child in pairs(value) do
			local encoded_key = graph(key, active)
			entries[#entries + 1] = encoded_key .. graph(child, active)
		end
		table.sort(entries, less_bytes)
		result[1] = "m" .. tostring(#entries) .. "{"
		for index = 1, #entries do result[#result + 1] = entries[index] end
		result[#result + 1] = "}"
	end
	active[value] = nil
	return table.concat(result)
end

local function raw_sha256(repo, bytes)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	return common.new_sha256()(bytes)
end

local function hex(bytes)
	return (bytes:gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

local function sha256(repo, bytes)
	return hex(raw_sha256(repo, bytes))
end

local function sample_owner_key(owner_x, owner_z)
	return tostring(owner_x) .. "/" .. tostring(owner_z)
end

local function build_sample_rows(seed_slot, risk_rows)
	integer(seed_slot, 1, 32, "sample seed slot")
	risk_rows = risk_rows or SAMPLE_RISK_OWNERS
	dense(risk_rows, "sample risk rows")
	local rows, seen = {}, {}
	local function append(class, label, owner_x, owner_z)
		text(class, "sample owner class")
		text(label, "sample owner label")
		local columns = owner_column_count(owner_x, owner_z)
		local key = sample_owner_key(owner_x, owner_z)
		if not seen[key] then
			seen[key] = true
			rows[#rows + 1] = {class = class, label = label, owner_x = owner_x,
				owner_z = owner_z, columns = columns}
		end
	end
	for z_slot = 0, 7 do
		local z_index = 3 + math.floor((z_slot * 78 + 3) / 7)
		for x_slot = 0, 12 do
			local x_index = 3 + math.floor((x_slot * 88 + 6) / 12)
			append("lattice", string.format("lattice_%02d_%02d", z_slot + 1,
				x_slot + 1), OWNER_MIN_X + x_index * 80,
				OWNER_MIN_Z + z_index * 80)
		end
	end
	if #rows ~= SAMPLE_LATTICE_COUNT then fail("sample lattice population differs") end
	for index = 1, #risk_rows do
		local row = risk_rows[index]
		if type(row) ~= "table" or getmetatable(row) ~= nil or #row ~= 3 then
			fail("sample risk row differs")
		end
		append("risk", row[1], row[2], row[3])
	end
	local fill_start, fill_step, fill_index = (seed_slot * 7919) % (95 * 85),
		7919, 0
	while #rows < SAMPLE_OWNER_COUNT and fill_index < 95 * 85 do
		local ordinal = (fill_start + fill_index * fill_step) % (95 * 85)
		local x_index, z_index = ordinal % 95, math.floor(ordinal / 95)
		append("fill", string.format("fill_%04d", fill_index + 1),
			OWNER_MIN_X + x_index * 80, OWNER_MIN_Z + z_index * 80)
		fill_index = fill_index + 1
	end
	if #rows ~= SAMPLE_OWNER_COUNT then fail("sample owner population differs") end
	table.sort(rows, function(left, right)
		if left.owner_z ~= right.owner_z then return left.owner_z < right.owner_z end
		if left.owner_x ~= right.owner_x then return left.owner_x < right.owner_x end
		return less_bytes(left.label, right.label)
	end)
	local columns, classes = 0, {lattice = 0, risk = 0, fill = 0}
	for index = 1, #rows do
		rows[index].ordinal = index
		columns = columns + rows[index].columns
		classes[rows[index].class] = classes[rows[index].class] + 1
	end
	return rows, columns, classes
end

local function sample_owner_bytes(row, index)
	return table.concat({"sample_owner", tostring(index), row.class, row.label,
		tostring(row.owner_x), tostring(row.owner_z), tostring(row.columns)}, "\t") .. "\n"
end

local function sample_roster_bytes(seed_slot, rows)
	local output = {"schema\t", SAMPLE_SCHEMA, "\nseed_slot\t",
		tostring(seed_slot), "\n"}
	for index = 1, #rows do
		output[#output + 1] = sample_owner_bytes(rows[index], index)
	end
	return table.concat(output)
end

local function sample_roster(repo, seed_slot)
	local rows, columns, classes = build_sample_rows(seed_slot)
	local bytes = sample_roster_bytes(seed_slot, rows)
	return {schema = SAMPLE_SCHEMA, rows = rows, columns = columns,
		classes = classes, bytes = bytes, sha256 = sha256(repo, bytes)}
end

function module.sample_roster_kat()
	local rows, columns, classes = build_sample_rows(1)
	if #rows ~= 128 or columns ~= 795281 or classes.lattice ~= 104 or
			classes.risk ~= 24 or classes.fill ~= 0 then
		fail("sample roster closed population KAT differs")
	end
	local seen, previous_z, previous_x, labels = {}, nil, nil, {}
	for index = 1, #rows do
		local row, key = rows[index], sample_owner_key(rows[index].owner_x,
			rows[index].owner_z)
		if seen[key] or row.ordinal ~= index or row.columns ~=
				owner_column_count(row.owner_x, row.owner_z) or
				(previous_z and (row.owner_z < previous_z or
					(row.owner_z == previous_z and row.owner_x <= previous_x))) then
			fail("sample roster canonical owner KAT differs")
		end
		seen[key], labels[row.label], previous_z, previous_x = true, true,
			row.owner_z, row.owner_x
	end
	for index = 1, #SAMPLE_RISK_OWNERS do
		if not labels[SAMPLE_RISK_OWNERS[index][1]] then
			fail("sample roster risk label is absent")
		end
	end
	local duplicates = {}
	for index = 1, SAMPLE_RISK_COUNT do
		duplicates[index] = {"duplicate_" .. tostring(index),
			OWNER_MIN_X + 3 * 80, OWNER_MIN_Z + 3 * 80}
	end
	local filled, _, filled_classes = build_sample_rows(32, duplicates)
	if #filled ~= 128 or filled_classes.lattice ~= 104 or
			filled_classes.risk ~= 0 or filled_classes.fill ~= 24 then
		fail("sample roster deterministic fill KAT differs")
	end
	if sample_roster_bytes(1, rows) == sample_roster_bytes(32, filled) then
		fail("sample roster seed binding KAT differs")
	end
	return true
end

function module.sample_assignment(repo)
	text(repo, "sample assignment repository")
	local output = {"schema\tgrug_wp40_r7_sample_assignment_v1\n",
		"sample_schema\t", SAMPLE_SCHEMA, "\n",
		"seed_population\t32\n",
		"owner_population_per_seed\t128\n",
		"case_population\t4096\n"}
	for slot = 1, 32 do
		local roster = sample_roster(repo, slot)
		output[#output + 1] = table.concat({"seed", tostring(slot), roster.sha256,
			tostring(#roster.rows), tostring(roster.columns),
			tostring(roster.classes.lattice), tostring(roster.classes.risk),
			tostring(roster.classes.fill)}, "\t") .. "\n"
	end
	return table.concat(output)
end

local function frontier_access_geometry(repo)
	local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	if source.warp.maximum ~= 60 or source.holy_grounds.min_x ~= -2500 or
			source.holy_grounds.max_x ~= 2500 or source.holy_grounds.min_z ~= -250 or
			source.holy_grounds.max_z ~= 250 then
		fail("frontier access source geometry differs")
	end
	local expected_zones = {
		front_wyrmglass_crown = {33, "wyrmglass_island", -3150, 0},
		front_gravesalt_escarpment = {34, "holy_grounds", -2000, 0},
		front_broken_causeway = {35, "holy_grounds", -750, 0},
		front_shattered_line = {36, "holy_grounds", 750, 0},
		front_skyglass_canopy = {37, "holy_grounds", 2000, 0},
		front_stormscale_summit = {38, "stormscale_island", 3150, 0},
	}
	local holy_count = 0
	for index = 1, #source.zones do
		local zone, expected = source.zones[index], expected_zones[source.zones[index].id]
		if zone.macro_region == "holy_grounds" then holy_count = holy_count + 1 end
		if expected then
			if zone.numeric_id ~= expected[1] or zone.macro_region ~= expected[2] or
					zone.hub.x ~= expected[3] or zone.hub.z ~= expected[4] or zone.bias ~= 0 then
				fail("frontier access zone geometry differs")
			end
			expected_zones[zone.id] = false
		elseif zone.macro_region == "holy_grounds" then
			fail("frontier access holy-ground zone population differs")
		end
	end
	if holy_count ~= 4 then fail("frontier access holy-ground zone count differs") end
	for _, value in pairs(expected_zones) do
		if value ~= false then fail("frontier access zone is absent") end
	end
	local island_bounds = {
		island_wyrmglass = {"wyrmglass_island", 33, -3440, -2860, -330, 320},
		island_stormscale = {"stormscale_island", 38, 2860, 3440, -340, 330},
	}
	if #source.islands ~= 2 then fail("frontier access island population differs") end
	for index = 1, #source.islands do
		local island, expected = source.islands[index], island_bounds[source.islands[index].id]
		if not expected or island.region ~= expected[1] or
				island.zone_numeric_id ~= expected[2] then
			fail("frontier access island identity differs")
		end
		local min_x, max_x, min_z, max_z = math.huge, -math.huge,
			math.huge, -math.huge
		for point = 1, #island.polygon do
			local value = island.polygon[point]
			min_x, max_x = math.min(min_x, value.x), math.max(max_x, value.x)
			min_z, max_z = math.min(min_z, value.z), math.max(max_z, value.z)
		end
		if min_x ~= expected[3] or max_x ~= expected[4] or
				min_z ~= expected[5] or max_z ~= expected[6] then
			fail("frontier access island geometry differs")
		end
		island_bounds[island.id] = false
	end
	for _, value in pairs(island_bounds) do
		if value ~= false then fail("frontier access island is absent") end
	end
	return source
end

local function build_frontier_access_rows(repo)
	frontier_access_geometry(repo)
	local rows, columns = {}, 0
	for owner_z = OWNER_MIN_Z, OWNER_MAX_Z, 80 do
		for owner_x = OWNER_MIN_X, OWNER_MAX_X, 80 do
			local envelope_id
			for index = 1, #FRONTIER_ACCESS_ENVELOPES do
				local envelope = FRONTIER_ACCESS_ENVELOPES[index]
				if owner_x <= envelope[3] and owner_x + 79 >= envelope[2] and
						owner_z <= envelope[5] and owner_z + 79 >= envelope[4] then
					if envelope_id then fail("frontier access envelopes overlap") end
					envelope_id = envelope[1]
				end
			end
			if envelope_id then
				local count = owner_column_count(owner_x, owner_z)
				rows[#rows + 1] = {envelope_id = envelope_id, owner_x = owner_x,
					owner_z = owner_z, columns = count, ordinal = #rows + 1}
				columns = columns + count
			end
		end
	end
	if #rows ~= FRONTIER_ACCESS_OWNER_COUNT or
			columns ~= FRONTIER_ACCESS_COLUMN_COUNT then
		fail("frontier access closed owner/column population differs")
	end
	return rows, columns
end

local function frontier_access_owner_bytes(row, index)
	return table.concat({"frontier_access_owner", tostring(index), row.envelope_id,
		tostring(row.owner_x), tostring(row.owner_z), tostring(row.columns)}, "\t") .. "\n"
end

local function frontier_access_roster_bytes(rows)
	local output = {"schema\t", FRONTIER_ACCESS_SCHEMA, "\n"}
	for index = 1, #FRONTIER_ACCESS_ENVELOPES do
		local row = FRONTIER_ACCESS_ENVELOPES[index]
		output[#output + 1] = table.concat({"envelope", row[1], tostring(row[2]),
			tostring(row[3]), tostring(row[4]), tostring(row[5])}, "\t") .. "\n"
	end
	for index = 1, #rows do
		output[#output + 1] = frontier_access_owner_bytes(rows[index], index)
	end
	return table.concat(output)
end

local function frontier_access_roster(repo)
	local rows, columns = build_frontier_access_rows(repo)
	local bytes = frontier_access_roster_bytes(rows)
	return {schema = FRONTIER_ACCESS_SCHEMA, rows = rows, columns = columns,
		bytes = bytes, sha256 = sha256(repo, bytes)}
end

function module.frontier_access_roster_kat(repo)
	local roster = frontier_access_roster(repo)
	local counts, seen, previous_z, previous_x = {}, {}, nil, nil
	for index = 1, #roster.rows do
		local row = roster.rows[index]
		local key = sample_owner_key(row.owner_x, row.owner_z)
		if seen[key] or row.ordinal ~= index or row.columns ~= 6400 or
				(previous_z and (row.owner_z < previous_z or
					(row.owner_z == previous_z and row.owner_x <= previous_x))) then
			fail("frontier access canonical owner KAT differs")
		end
		seen[key], counts[row.envelope_id] = true, (counts[row.envelope_id] or 0) + 1
		previous_z, previous_x = row.owner_z, row.owner_x
	end
	if counts.front_gravesalt_escarpment ~= 119 or
			counts.front_skyglass_canopy ~= 119 or
			counts.front_stormscale_summit ~= 110 or
			counts.front_wyrmglass_crown ~= 110 then
		fail("frontier access envelope population KAT differs")
	end
	return true
end

function module.frontier_access_assignment(repo)
	local roster = frontier_access_roster(repo)
	return table.concat({
		"schema\tgrug_wp40_r7_frontier_access_assignment_v2\n",
		"frontier_access_schema\t", roster.schema, "\n",
		"seed_population\t7\n",
		"seed_slots\t1,6,11,17,22,27,32\n",
		"owner_population_per_seed\t", tostring(#roster.rows), "\n",
		"case_population\t", tostring(7 * #roster.rows), "\n",
		"column_population_per_seed\t", tostring(roster.columns), "\n",
		"column_visit_population\t", tostring(7 * roster.columns), "\n",
		"source_population\t4\nzone_population\t4\nsource_faction_gate_population\t8\n",
		"roster_sha256\t", roster.sha256, "\n",
	})
end

local function diagnostic_string(value, maximum)
	local parts, used = {}, 0
	for index = 1, #value do
		local byte = string.byte(value, index)
		local piece
		if byte == 0 then piece = "\\0"
		elseif byte == 9 then piece = "\\t"
		elseif byte == 10 then piece = "\\n"
		elseif byte == 13 then piece = "\\r"
		elseif byte == 92 then piece = "\\\\"
		elseif byte >= 32 and byte <= 126 then piece = string.char(byte)
		else piece = string.format("\\x%02x", byte) end
		if used + #piece > maximum then parts[#parts + 1] = "..." break end
		parts[#parts + 1], used = piece, used + #piece
	end
	return table.concat(parts)
end

local function diagnostic_digest(repo, value)
	if value == nil then return "absent" end
	return sha256(repo, graph(value))
end

local function diagnostic_value(repo, value)
	local kind = type(value)
	if kind == "nil" then return "nil" end
	if kind == "string" then
		return "string(len=" .. tostring(#value) .. ",value=" ..
			diagnostic_string(value, 64) .. ")"
	end
	if kind == "number" then return "number(" .. string.format("%.0f", value) .. ")" end
	if kind == "boolean" then return value and "boolean(true)" or "boolean(false)" end
	if kind == "table" then
		local count = 0
		for _ in pairs(value) do count = count + 1 end
		return "table(fields=" .. tostring(count) .. ")"
	end
	return kind
end

local function diagnostic_key(repo, key)
	if type(key) == "string" and key:match("^[A-Za-z_][A-Za-z0-9_]*$") then
		return "." .. key
	end
	if type(key) == "number" then
		return "[" .. string.format("%.0f", key) .. "]"
	end
	local encoded = graph(key)
	return "[" .. diagnostic_string(encoded, 72) .. ";sha256=" ..
		sha256(repo, encoded):sub(1, 16) .. "]"
end

local function first_difference(repo, actual, expected, path, active)
	if rawequal(actual, expected) then return nil end
	local actual_type, expected_type = type(actual), type(expected)
	if actual_type ~= expected_type then
		return {path = path, actual = diagnostic_value(repo, actual),
			expected = diagnostic_value(repo, expected),
			actual_sha256 = diagnostic_digest(repo, actual),
			expected_sha256 = diagnostic_digest(repo, expected)}
	end
	if actual_type ~= "table" then
		if actual ~= expected then
			return {path = path, actual = diagnostic_value(repo, actual),
				expected = diagnostic_value(repo, expected),
				actual_sha256 = diagnostic_digest(repo, actual),
				expected_sha256 = diagnostic_digest(repo, expected)}
		end
		return nil
	end
	if getmetatable(actual) ~= nil or getmetatable(expected) ~= nil then
		fail("first-difference input has a metatable")
	end
	active = active or {}
	if active[actual] or active[expected] then fail("first-difference input is cyclic") end
	active[actual], active[expected] = true, true
	local function keys(value)
		local result = {}
		for key in pairs(value) do
			local encoded = graph(key)
			result[#result + 1] = {key = key, encoded = encoded}
		end
		table.sort(result, function(left, right)
			return less_bytes(left.encoded, right.encoded)
		end)
		return result
	end
	local actual_keys, expected_keys = keys(actual), keys(expected)
	local ai, ei = 1, 1
	while ai <= #actual_keys or ei <= #expected_keys do
		local left, right = actual_keys[ai], expected_keys[ei]
		if not left or (right and less_bytes(right.encoded, left.encoded)) then
			local child_path = path .. diagnostic_key(repo, right.key)
			active[actual], active[expected] = nil, nil
			return {path = child_path, actual = "nil",
				expected = diagnostic_value(repo, expected[right.key]),
				actual_sha256 = "absent",
				expected_sha256 = diagnostic_digest(repo, expected[right.key])}
		elseif not right or less_bytes(left.encoded, right.encoded) then
			local child_path = path .. diagnostic_key(repo, left.key)
			active[actual], active[expected] = nil, nil
			return {path = child_path, actual = diagnostic_value(repo, actual[left.key]),
				expected = "nil", actual_sha256 = diagnostic_digest(repo, actual[left.key]),
				expected_sha256 = "absent"}
		end
		local difference = first_difference(repo, actual[left.key], expected[right.key],
			path .. diagnostic_key(repo, left.key), active)
		if difference then
			active[actual], active[expected] = nil, nil
			return difference
		end
		ai, ei = ai + 1, ei + 1
	end
	active[actual], active[expected] = nil, nil
	return nil
end

local function difference_message(difference)
	return "path=" .. difference.path .. " actual=" .. difference.actual ..
		" expected=" .. difference.expected .. " actual_sha256=" ..
		difference.actual_sha256 .. " expected_sha256=" .. difference.expected_sha256
end

local function integer_row_bytes(row, width, label)
	if type(row) ~= "table" or #row ~= width then return label .. "=absent" end
	local fields = {}
	for index = 1, width do
		integer(row[index], -MAX_SAFE, MAX_SAFE, label .. " field")
		fields[index] = string.format("%.0f", row[index])
	end
	return label .. "=" .. table.concat(fields, ",")
end

local function stage_b_row_diagnostic(runtime_fixture, binding, path, source_rows,
		normalized_rows, accepted_rows)
	local index_text = path:match("^settlement%.direct_rows%[(%d+)%]")
	if not index_text then return "" end
	local index = tonumber(index_text)
	if not index or index % 1 ~= 0 or index < 1 then return "" end
	local source, normalized, accepted = source_rows[index], normalized_rows[index],
		accepted_rows[index]
	local source_name = source and runtime_fixture.name_by_cid[source[4]] or nil
	local accepted_ref = normalized and normalized[10] ~= 0 and
		math.floor(normalized[10] / 256) + 1 or 0
	local accepted_content = accepted_ref ~= 0 and binding.rows[accepted_ref] or nil
	return " row_fields=x,y,z,cid,param2,occupancy,opcode,feature,interface,aux " ..
		integer_row_bytes(source, 10, "source_row") .. " " ..
		integer_row_bytes(normalized, 10, "normalized_row") .. " " ..
		integer_row_bytes(accepted, 10, "accepted_row") ..
		" source_name=" .. diagnostic_string(source_name or "absent", 80) ..
		" normalized_ref=" .. tostring(accepted_ref) ..
		" accepted_name=" .. diagnostic_string(
			accepted_content and accepted_content.name or "absent", 80) ..
		" accepted_role_mask=" .. tostring(
			accepted_content and accepted_content.mask or "absent")
end

local function sha_stream(repo)
	local ffi = rawget(_G, "wp40_ffi")
	if not ffi then fail("LuaJIT FFI injection is required") end
	return dofile(repo .. "/tools/wp40/r6/sha256_stream.lua")(ffi)
end

local function row_key(row)
	return tostring(row[1]) .. "/" .. tostring(row[2]) .. "/" .. tostring(row[3])
end

local function population_key(source_id, zone_id, biome, faction, bracket)
	return table.concat({source_id, zone_id, biome, faction, bracket}, "\0")
end

local function validate_evidence_rows(rows, label)
	dense(rows, label)
	local previous
	for index = 1, #rows do
		local row = dense(rows[index], label .. " row " .. index)
		if #row ~= 10 then fail(label .. " row width differs") end
		for field = 1, 10 do
			integer(row[field], -MAX_SAFE, MAX_SAFE,
				label .. " row " .. index .. " field " .. field)
		end
		local key = row_key(row)
		if previous and not (rows[index - 1][3] < row[3] or
				(rows[index - 1][3] == row[3] and
					(rows[index - 1][1] < row[1] or
						(rows[index - 1][1] == row[1] and
							rows[index - 1][2] < row[2])))) then
			fail(label .. " rows are not canonical z/x/y unique")
		end
		previous = key
	end
	return rows
end

local function evidence_row_bytes(rows)
	validate_evidence_rows(rows, "evidence rows")
	local output = {"schema\tgrug_wp40_r7_private_buffer_projection_v1\n"}
	for index = 1, #rows do
		local row, fields = rows[index], {}
		for field = 1, 10 do fields[field] = string.format("%.0f", row[field]) end
		output[#output + 1] = "row\t" .. table.concat(fields, "\t") .. "\n"
	end
	return table.concat(output)
end

local function production_run_bytes(runs)
	dense(runs, "production evidence runs")
	local output = {"schema\tgrug_wp40_r7_production_run_projection_v1\n"}
	for index = 1, #runs do
		local row = dense(runs[index], "production evidence run " .. index)
		if #row ~= 11 then fail("production evidence run width differs") end
		local fields = {}
		for field = 1, 11 do
			integer(row[field], -MAX_SAFE, MAX_SAFE,
				"production evidence run field")
			fields[field] = string.format("%.0f", row[field])
		end
		output[#output + 1] = "run\t" .. table.concat(fields, "\t") .. "\n"
	end
	return table.concat(output)
end

local OPERATION_FIELDS = {
	"source_id", "cell_x", "cell_z", "root_x", "root_y", "root_z",
	"zone_id", "biome", "faction", "bracket", "candidate_sha256",
	"original_cid", "original_param2", "prior_cid", "prior_param2",
	"prior_occupancy", "prior_opcode", "prior_feature", "prior_interface",
	"prior_aux", "support_mode", "support_cid", "support_param2",
	"support_occupancy", "support_opcode", "support_feature",
	"support_interface", "support_aux", "final_cid", "final_param2",
	"final_occupancy", "final_opcode", "final_feature", "final_interface",
	"final_aux", "accepted", "reason",
}
local OPERATION_KEYS = {}
local OPERATION_COLUMN = {}
for index = 1, #OPERATION_FIELDS do
	OPERATION_KEYS[OPERATION_FIELDS[index]] = true
	OPERATION_COLUMN[OPERATION_FIELDS[index]] = index + 1
end

local function same_tuple(row, operation, prefix)
	return row[4] == operation[prefix .. "cid"] and
		row[5] == operation[prefix .. "param2"] and
		row[6] == operation[prefix .. "occupancy"] and
		row[7] == operation[prefix .. "opcode"] and
		row[8] == operation[prefix .. "feature"] and
		row[9] == operation[prefix .. "interface"] and
		row[10] == operation[prefix .. "aux"]
end

local function operation_bytes(operation, row_type)
	exact_fields(operation, OPERATION_KEYS, "P9G operation")
	row_type = row_type or "operation"
	if row_type ~= "operation" and row_type ~= "frontier_access_operation" then
		fail("P9G operation row type differs")
	end
	text(operation.source_id, "P9G source ID")
	text(operation.zone_id, "P9G zone ID")
	text(operation.biome, "P9G biome")
	text(operation.faction, "P9G faction")
	text(operation.bracket, "P9G bracket")
	digest(operation.candidate_sha256, "P9G candidate digest")
	if type(operation.accepted) ~= "boolean" then fail("P9G acceptance differs") end
	text(operation.reason, "P9G reason")
	local values = {}
	for index = 1, #OPERATION_FIELDS do
		local value = operation[OPERATION_FIELDS[index]]
		if type(value) == "number" then
			integer(value, -MAX_SAFE, MAX_SAFE, "P9G operation integer")
			value = string.format("%.0f", value)
		elseif type(value) == "boolean" then
			value = value and "true" or "false"
		end
		values[index] = value
	end
	return row_type .. "\t" .. table.concat(values, "\t") .. "\n"
end

local function validate_scan(scan, owner_x, owner_z, successor)
	exact_fields(scan, {schema = true, owner_x = true, owner_z = true,
		column_count = true, groups = true, coverage = true, candidates = true,
		settlement = true},
		"horizontal owner evidence")
	if scan.schema ~= "grug_wp40_r7_horizontal_owner_evidence_v1" or
			scan.owner_x ~= owner_x or scan.owner_z ~= owner_z or
			scan.column_count ~= owner_column_count(owner_x, owner_z) then
		fail("horizontal owner evidence identity differs")
	end
	dense(scan.groups, "owner groups")
	dense(scan.coverage, "owner coverage")
	exact_fields(scan.candidates, {cultural = true, decorations = true},
		"owner candidates")
	dense(scan.candidates.cultural, "owner Cultural candidates")
	dense(scan.candidates.decorations, "owner decoration candidates")
	local expected = {cultural = true, decorations = true, rejections = true,
		witnesses = true, apex_overlaps = true, direct_rows = true,
		direct_runs = true}
	if successor then expected.p9g, expected.final_rows, expected.final_runs =
		true, true, true end
	exact_fields(scan.settlement, expected, "owner settlement")
	validate_evidence_rows(scan.settlement.direct_rows, "owner direct rows")
	production_run_bytes(scan.settlement.direct_runs)
	if successor then validate_evidence_rows(scan.settlement.final_rows,
		"owner final rows"); production_run_bytes(scan.settlement.final_runs) end
	if scan.settlement.apex_overlaps ~= 0 then fail("owner overlaps an apex socket") end
	return scan
end

local function validate_ledger(ledger)
	exact_fields(ledger, {schema = true, groups = true, populations = true,
		operations = true, rejections = true, accepted = true, planned = true,
		eligible = true, manifest_sha256 = true}, "P9G ledger")
	if ledger.schema ~= "grug_wp40_r7_p9g_ledger_v1" then
		fail("P9G ledger schema differs")
	end
	dense(ledger.groups, "P9G groups")
	dense(ledger.populations, "P9G populations")
	dense(ledger.operations, "P9G operations")
	digest(ledger.manifest_sha256, "P9G manifest digest")
	integer(ledger.accepted, 0, MAX_SAFE, "P9G accepted")
	integer(ledger.planned, 0, MAX_SAFE, "P9G planned")
	integer(ledger.eligible, 0, MAX_SAFE, "P9G eligible")
	if #ledger.operations ~= ledger.planned then fail("P9G operation population differs") end
	local function rejection_map(value, label)
		local keys = {}
		for index = 1, #P9G_REASONS do keys[P9G_REASONS[index]] = true end
		exact_fields(value, keys, label)
		for index = 1, #P9G_REASONS do
			integer(value[P9G_REASONS[index]], 0, MAX_SAFE,
				label .. " " .. P9G_REASONS[index])
		end
	end
	rejection_map(ledger.rejections, "P9G ledger rejections")
	local group_sums = {eligible = 0, budget = 0, accepted = 0, rejections = {}}
	local population_sums = {eligible = 0, budget = 0, accepted = 0, rejections = {}}
	for index = 1, #P9G_REASONS do
		group_sums.rejections[P9G_REASONS[index]] = 0
		population_sums.rejections[P9G_REASONS[index]] = 0
	end
	for index = 1, #ledger.groups do
		local row = exact_fields(ledger.groups[index], {source_id = true, cell_x = true,
			cell_z = true, eligible = true, budget = true, accepted = true,
			rejections = true}, "P9G group")
		text(row.source_id, "P9G group source")
		integer(row.cell_x, -1932, 1932, "P9G group cell x")
		integer(row.cell_z, -1932, 1932, "P9G group cell z")
		for _, field in ipairs({"eligible", "budget", "accepted"}) do
			integer(row[field], 0, MAX_SAFE, "P9G group " .. field)
			group_sums[field] = group_sums[field] + row[field]
		end
		rejection_map(row.rejections, "P9G group rejections")
		for reason = 1, #P9G_REASONS do
			local name = P9G_REASONS[reason]
			group_sums.rejections[name] = group_sums.rejections[name] +
				row.rejections[name]
		end
	end
	for index = 1, #ledger.populations do
		local row = exact_fields(ledger.populations[index], {source_id = true,
			zone_id = true, biome = true, faction = true, bracket = true,
			eligible = true, budget = true, accepted = true, rejections = true},
			"P9G population")
		for _, field in ipairs({"source_id", "zone_id", "biome", "faction", "bracket"}) do
			text(row[field], "P9G population " .. field)
		end
		for _, field in ipairs({"eligible", "budget", "accepted"}) do
			integer(row[field], 0, MAX_SAFE, "P9G population " .. field)
			population_sums[field] = population_sums[field] + row[field]
		end
		rejection_map(row.rejections, "P9G population rejections")
		for reason = 1, #P9G_REASONS do
			local name = P9G_REASONS[reason]
			population_sums.rejections[name] = population_sums.rejections[name] +
				row.rejections[name]
		end
	end
	for _, sums in ipairs({group_sums, population_sums}) do
		if sums.eligible ~= ledger.eligible or sums.budget ~= ledger.planned or
				sums.accepted ~= ledger.accepted then
			fail("P9G group/population totals differ")
		end
		for reason = 1, #P9G_REASONS do
			local name = P9G_REASONS[reason]
			if sums.rejections[name] ~= ledger.rejections[name] then
				fail("P9G group/population rejection totals differ")
			end
		end
	end
	local accepted = 0
	local operation_rejections = {}
	for index = 1, #P9G_REASONS do operation_rejections[P9G_REASONS[index]] = 0 end
	local previous
	for index = 1, #ledger.operations do
		local operation = ledger.operations[index]
		operation_bytes(operation)
		if operation.accepted then accepted = accepted + 1
		else
			if operation_rejections[operation.reason] == nil then
				fail("P9G operation rejection reason differs")
			end
			operation_rejections[operation.reason] =
				operation_rejections[operation.reason] + 1
		end
		local key = table.concat({operation.root_z, operation.root_x,
			operation.root_y, operation.source_id}, "\0")
		if previous then
			local old = ledger.operations[index - 1]
			if not (old.root_z < operation.root_z or
					(old.root_z == operation.root_z and
						(old.root_x < operation.root_x or
							(old.root_x == operation.root_x and
								(old.root_y < operation.root_y or
									(old.root_y == operation.root_y and
										less_bytes(old.source_id, operation.source_id))))))) then
				fail("P9G operations are not coordinate/source ordered")
			end
		end
		previous = key
	end
	if accepted ~= ledger.accepted then fail("P9G accepted count differs") end
	for index = 1, #P9G_REASONS do
		local name = P9G_REASONS[index]
		if operation_rejections[name] ~= ledger.rejections[name] then
			fail("P9G operation rejection partition differs")
		end
	end
	return ledger
end

local function copy_rows(rows)
	local result = {}
	for index = 1, #rows do
		result[index] = {}
		for field = 1, 10 do result[index][field] = rows[index][field] end
	end
	return result
end

local function stage_a_owner(repo, fixture, successor, direct)
	validate_scan(successor, successor.owner_x, successor.owner_z, true)
	validate_scan(direct, successor.owner_x, successor.owner_z, false)
	if graph(successor.groups) ~= graph(direct.groups) or
			graph(successor.coverage) ~= graph(direct.coverage) or
			graph(successor.candidates) ~= graph(direct.candidates) or
			evidence_row_bytes(successor.settlement.direct_rows) ~=
				evidence_row_bytes(direct.settlement.direct_rows) or
			production_run_bytes(successor.settlement.direct_runs) ~=
				production_run_bytes(direct.settlement.direct_runs) then
		fail("successor Direct-83 projection differs from independent direct scan")
	end
	local ledger = validate_ledger(successor.settlement.p9g)
	local final_by_key, direct_by_key = {}, {}
	for index = 1, #successor.settlement.final_rows do
		local row = successor.settlement.final_rows[index]
		final_by_key[row_key(row)] = row
	end
	for index = 1, #direct.settlement.direct_rows do
		local row = direct.settlement.direct_rows[index]
		direct_by_key[row_key(row)] = row
	end
	local restored = copy_rows(successor.settlement.final_rows)
	local restored_by_key = {}
	for index = 1, #restored do restored_by_key[row_key(restored[index])] = index end
	local operation_lines, accepted, rejected = {}, 0, 0
	local air_cid = fixture.cid_by_name.air
	for index = 1, #ledger.operations do
		local operation = ledger.operations[index]
		operation_lines[index] = operation_bytes(operation)
		local key = tostring(operation.root_x) .. "/" .. tostring(operation.root_y) ..
			"/" .. tostring(operation.root_z)
		local final_row = final_by_key[key]
		if operation.accepted then
			accepted = accepted + 1
			if not final_row or not same_tuple(final_row, operation, "final_") or
				operation.reason ~= "accepted" or operation.final_opcode ~= 35 or
				operation.final_occupancy ~= -2 then
				fail("accepted P9G final tuple differs")
			end
			local direct_row = direct_by_key[key]
			if direct_row then
				if not same_tuple(direct_row, operation, "prior_") then
					fail("accepted P9G prior tuple differs from direct row")
				end
				restored[restored_by_key[key]] = copy_rows({direct_row})[1]
			else
				if operation.prior_cid ~= air_cid or operation.prior_param2 ~= 0 or
						operation.prior_occupancy ~= 0 or operation.prior_opcode ~= 0 or
						operation.prior_feature ~= 0 or operation.prior_interface ~= 0 or
						operation.prior_aux ~= 0 then
					fail("accepted P9G prior tuple is not independent implicit air")
				end
				restored[restored_by_key[key]] = false
			end
		else
			rejected = rejected + 1
			if operation.reason == "accepted" then fail("rejected P9G reason differs") end
			if operation.final_cid ~= -1 and
					(operation.final_cid ~= operation.prior_cid or
					operation.final_param2 ~= operation.prior_param2 or
					operation.final_occupancy ~= operation.prior_occupancy or
					operation.final_opcode ~= operation.prior_opcode or
					operation.final_feature ~= operation.prior_feature or
					operation.final_interface ~= operation.prior_interface or
					operation.final_aux ~= operation.prior_aux) then
				fail("rejected P9G operation changed the full prior tuple")
			end
		end
	end
	local compact = {}
	for index = 1, #restored do
		if restored[index] then compact[#compact + 1] = restored[index] end
	end
	table.sort(compact, function(left, right)
		if left[3] ~= right[3] then return left[3] < right[3] end
		if left[1] ~= right[1] then return left[1] < right[1] end
		return left[2] < right[2]
	end)
	local restored_buffers, direct_buffers = evidence_row_bytes(compact),
		evidence_row_bytes(direct.settlement.direct_rows)
	local restored_run_rows, p9g_run_count = {}, 0
	for index = 1, #successor.settlement.final_runs do
		local row = successor.settlement.final_runs[index]
		if row[6] == 35 then
			p9g_run_count = p9g_run_count + 1
			if row[3] ~= row[4] or row[5] ~= 10 or row[7] ~= 17 or
					row[8] ~= 11 or row[10] ~= 0 then
				fail("P9G production run identity differs")
			end
		else
			restored_run_rows[#restored_run_rows + 1] = row
		end
	end
	if p9g_run_count ~= accepted then fail("P9G accepted/run population differs") end
	local restored_runs = production_run_bytes(restored_run_rows)
	local direct_runs = production_run_bytes(direct.settlement.direct_runs)
	if restored_buffers ~= direct_buffers or restored_runs ~= direct_runs then
		fail("Stage-A restored Direct-83 state differs")
	end
	return {accepted = accepted, rejected = rejected,
		operation_count = #ledger.operations, operation_bytes = table.concat(operation_lines),
		ledger = ledger,
		restored_buffers = restored_buffers, direct_buffers = direct_buffers,
		restored_runs = restored_runs, direct_runs = direct_runs}
end

local function fixture(repo, seed, evidence_mode)
	if evidence_mode == nil or evidence_mode == true then
		return dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(repo, seed)
	end
	if evidence_mode ~= "horizontal" then fail("runtime fixture mode differs") end
	local constructor = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")
	local base = constructor(repo, seed, true)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local runtime = dofile(wp40 .. "/r7_runtime.lua")(base.core, wp40,
		repo .. "/mods/BASE/default/schematics", base.projection, base.catalog)
	base.built = runtime.build(base.native_identities, nil, "horizontal")
	base.catalog_manifest = base.catalog.manifest()
	base.schema = "grug_wp40_r7_runtime_fixture_v1"
	return base
end

local PROJECTION_FAMILIES = {
	surface_coverage = true, cultural_candidate = true, cultural_slot = true,
	decoration_candidate = true, decoration_settlement = true,
}

local cultural_name_set

local function artifact_content_binding(repo, runtime_fixture, seed_slot)
	local path = repo .. "/docs/research/wp40-simple-map-r6-artifact.tsv"
	local stream = sha_stream(repo)
	local hasher = stream.new()
	local codec = dofile(repo .. "/tools/wp40/r6/artifact_codec.lua")
	local file = assert(io.open(path, "rb"), "cannot open accepted R6 artifact")
	local header = file:read("*l")
	if header ~= codec.header_line() then fail("accepted R6 artifact header differs") end
	hasher.update(header .. "\n")
	local content, projection_records, cultural_access = {}, {}, {}
	local expected_cultural = {dwarf = "runeslate", elf = "moonresin",
		human = "sunwax", orc = "red_ochre", troll = "spirit_resin",
		undead = "gravesalt"}
	while true do
		local line = file:read("*l")
		if not line then break end
		if line:find("\r", 1, true) then fail("accepted R6 artifact has CR bytes") end
		hasher.update(line .. "\n")
		if line:find("^content\t") then
			local fields = codec.parse_data_line(line, "accepted R6 content row")
			local ref = tonumber(fields[2])
			if not ref or ref % 1 ~= 0 or ref < 1 or ref > 77 or content[ref] then
				fail("accepted R6 content ref differs")
			end
			content[ref] = {name = fields[12], cid = tonumber(fields[13]),
				mask = tonumber(fields[14]), line = line .. "\n"}
		elseif line:find("^access\taccess_cultural\t") then
			local access = codec.parse_data_line(line, "accepted R6 Cultural access row")
			local race, key, rate = access[3], access[4], access[5]
			local identity = tostring(race) .. "\0" .. tostring(key) .. "\0" ..
				tostring(rate)
			if expected_cultural[race] ~= key or
					(rate ~= "ordinary" and rate ~= "concentrated") or
					access[12] ~= "true" or cultural_access[identity] then
				fail("accepted R6 Cultural access identity differs")
			end
			cultural_access[identity] = true
		elseif seed_slot and (PROJECTION_FAMILIES[line:match("^([^\t]+)")] or
				line:find("^rejection\t")) then
			local fields = codec.parse_data_line(line, "accepted R6 projection row")
			local family = fields[1]
			if tonumber(fields[2]) == seed_slot and
					(family ~= "rejection" or fields[3] == "cultural" or
						fields[3] == "decoration") then
				projection_records[#projection_records + 1] = {fields = fields,
					bytes = line .. "\n"}
			end
		end
	end
	assert(file:close())
	local cultural_access_count = 0
	for race, key in pairs(expected_cultural) do
		for _, rate in ipairs({"ordinary", "concentrated"}) do
			if not cultural_access[race .. "\0" .. key .. "\0" .. rate] then
				fail("accepted R6 Cultural access row is absent")
			end
			cultural_access_count = cultural_access_count + 1
		end
	end
	if cultural_access_count ~= 12 then fail("accepted R6 Cultural access count differs") end
	local file_digest = hasher.final_hex()
	if file_digest ~= ACCEPTED_R6_ARTIFACT_SHA256 or
			runtime_fixture.built.manifest.values.r6_artifact_sha256 ~= file_digest then
		fail("accepted R6 artifact file digest differs")
	end
	local accepted_rows = runtime_fixture.built.content.accepted_r6_rows()
	dense(accepted_rows, "accepted R6 content rows")
	if #accepted_rows ~= 77 then fail("accepted R6 content population differs") end
	local by_name = {}
	for index = 1, 77 do
		local expected, actual = accepted_rows[index], content[index]
		if type(expected) ~= "table" or #expected ~= 2 or not actual or
				actual.name ~= expected[1] or actual.mask ~= expected[2] or
				actual.cid ~= 999 + index or by_name[actual.name] then
			fail("accepted R6 content row differs at ref " .. tostring(index))
		end
		by_name[actual.name] = {ref = index, cid = actual.cid, mask = actual.mask}
	end
	if seed_slot then
		table.sort(projection_records, function(left, right)
			return codec.compare(left.fields, right.fields)
		end)
		if #projection_records ~= 104 + 12 + 12 + 48 + 48 + 36 + 480 then
			fail("accepted R6 horizontal aggregate row population differs")
		end
	end
	local cultural = cultural_name_set(runtime_fixture)
	return {sha256 = file_digest, by_name = by_name, rows = content,
		projection_records = projection_records, codec = codec, cultural = cultural,
		inherited_cultural_access_count = cultural_access_count}
end

cultural_name_set = function(runtime_fixture)
	local set, rows = {}, runtime_fixture.catalog.cultural_sources()
	dense(rows, "cultural source catalog")
	if #rows ~= 6 then fail("cultural source population differs") end
	for index = 1, #rows do
		local name = rows[index].source_node
		text(name, "cultural source node")
		if set[name] then fail("duplicate cultural source node") end
		set[name] = true
	end
	return set
end

local function normalize_content_row(runtime_fixture, binding, cultural, source)
	local row = {}
	for field = 1, 10 do row[field] = source[field] end
	local name = runtime_fixture.name_by_cid[source[4]]
	if not name then fail("Direct-83 row CID has no registered name") end
	local opcode = integer(source[7], 0, 35, "Direct-83 row opcode")
	local param2 = integer(source[5], 0, 255, "Direct-83 row param2")
	local aux = integer(source[10], 0, MAX_SAFE, "Direct-83 row aux")
	if opcode == 0 then
		if aux ~= 0 then fail("zero-intent Direct-83 row has nonzero aux") end
		if name == "air" then
			if source[4] ~= runtime_fixture.cid_by_name.air then
				fail("Direct-83 air reservation CID differs")
			end
			return row, false
		end
		local target = binding.by_name[name]
		if cultural[name] then
			fail("Cultural target substitution escaped opcode 34")
		elseif not target then
			fail("zero-intent Direct-83 row has no accepted CID mapping: " .. name)
		end
		row[4], row[10] = target.cid, 0
		return row, false
	end

	-- For an operation, aux is the production content authority.  Aux zero is
	-- valid for production ref 1 with param2 zero, so opcode—not aux truthiness—
	-- distinguishes it from a structural reservation.
	local production_ref = math.floor(aux / 256) + 1
	local aux_param2 = aux % 256
	local production_names = runtime_fixture.built.content.production.content_names
	local aux_name = production_names[production_ref]
	if not aux_name then fail("Direct-83 operation aux ref is outside production content") end
	if aux_name ~= name then fail("Direct-83 operation aux name/CID name differ") end
	if aux_param2 ~= param2 then fail("Direct-83 operation aux/row param2 differ") end
	local target, substituted = binding.by_name[aux_name], false
	if cultural[aux_name] then
		if opcode ~= 34 then fail("Cultural target substitution escaped opcode 34") end
		target, substituted = assert(binding.by_name["grug_nodes:bone_pile"]), true
	elseif not target then
		fail("Direct-83 operation aux name has no accepted mapping: " .. aux_name)
	end
	row[4] = target.cid
	row[10] = (target.ref - 1) * 256 + aux_param2
	return row, substituted
end

local function normalize_rows(runtime_fixture, binding, rows)
	local cultural = binding.cultural or cultural_name_set(runtime_fixture)
	if not binding.total_map_checked then
		local names = runtime_fixture.built.content.production.content_names
		if #names ~= 83 then fail("Direct-83 name-map population differs") end
		local previous, accepted_count, cultural_count = nil, 0, 0
		for index = 1, #names do
			local name = names[index]
			if previous and not less_bytes(previous, name) then
				fail("Direct-83 names are not ASCII unique")
			end
			if binding.by_name[name] then accepted_count = accepted_count + 1
			elseif cultural[name] then cultural_count = cultural_count + 1
			else fail("Direct-83 name escapes total accepted map: " .. name) end
			previous = name
		end
		if accepted_count ~= 77 or cultural_count ~= 6 then
			fail("Direct-83 accepted/Cultural partition differs")
		end
		binding.cultural, binding.total_map_checked = cultural, true
	end
	local output, substitutions = {}, 0
	for index = 1, #rows do
		local row, substituted = normalize_content_row(runtime_fixture, binding,
			cultural, rows[index])
		output[index] = row
		if substituted then substitutions = substitutions + 1 end
	end
	return output, substitutions
end

function module.normalize_rows_kat()
	local leaf = "default:acacia_bush_leaves"
	local cultural_name = "grug_gathering:runeslate_source"
	local runtime_fixture = {
		cid_by_name = {air = 0},
		name_by_cid = {[144] = "default:stone", [200] = leaf,
			[201] = cultural_name},
		built = {content = {production = {content_names = {leaf, cultural_name}}}},
	}
	local binding = {by_name = {
		["default:stone"] = {ref = 45, cid = 1044},
		[leaf] = {ref = 1, cid = 1000},
		["grug_nodes:bone_pile"] = {ref = 5, cid = 1004},
	}}
	local cultural = {[cultural_name] = true}
	local measured = {36, 84, -19, 144, 0, -1, 0, 0, 0, 0}
	local normalized, substituted = normalize_content_row(runtime_fixture, binding,
		cultural, measured)
	if substituted or graph(normalized) ~= graph(
			{36, 84, -19, 1044, 0, -1, 0, 0, 0, 0}) then
		fail("measured zero-intent natural-CID normalization differs")
	end
	local ref_one = {1, 2, 3, 200, 0, -1, 12, 4, 0, 0}
	local ref_one_normalized, ref_one_substituted = normalize_content_row(
		runtime_fixture, binding, cultural, ref_one)
	if ref_one_substituted or graph(ref_one_normalized) ~= graph(
			{1, 2, 3, 1000, 0, -1, 12, 4, 0, 0}) then
		fail("operation ref-1 zero-aux normalization differs")
	end
	local cultural_operation = {4, 5, 6, 201, 0, 1, 34, 7, 0, 256}
	local cultural_normalized, cultural_substituted = normalize_content_row(
		runtime_fixture, binding, cultural, cultural_operation)
	if not cultural_substituted or graph(cultural_normalized) ~= graph(
			{4, 5, 6, 1004, 0, 1, 34, 7, 0, 1024}) then
		fail("Cultural operation normalization differs")
	end
	local function rejected(row, fragment)
		local ok, message = pcall(normalize_content_row, runtime_fixture, binding,
			cultural, row)
		if ok or type(message) ~= "string" or not message:find(fragment, 1, true) then
			fail("normalization negative KAT differs: " .. fragment)
		end
	end
	rejected({36, 84, -19, 144, 0, -1, 0, 0, 0, 256},
		"zero-intent Direct-83 row has nonzero aux")
	rejected({1, 2, 3, 144, 0, -1, 12, 4, 0, 0},
		"aux name/CID name differ")
	rejected({1, 2, 3, 200, 1, -1, 12, 4, 0, 0},
		"aux/row param2 differ")
	rejected({4, 5, 6, 201, 0, 1, 12, 7, 0, 256},
		"Cultural target substitution escaped opcode 34")
	return true
end

local function normalize_runs(runtime_fixture, binding, runs)
	local cultural = binding.cultural or cultural_name_set(runtime_fixture)
	local bone = assert(binding.by_name["grug_nodes:bone_pile"])
	local names = runtime_fixture.built.content.production.content_names
	local output = {}
	for index = 1, #runs do
		local source, row = runs[index], {}
		for field = 1, 11 do row[field] = source[field] end
		local ref = math.floor(source[11] / 256) + 1
		local param2 = source[11] % 256
		local name, target = names[ref], names[ref] and binding.by_name[names[ref]]
		if not target and name and cultural[name] then
			if source[6] ~= 34 then
				fail("Cultural run substitution escaped opcode 34")
			end
			target = bone
		elseif not target then
			fail("Direct-83 run has no total accepted name mapping")
		end
		row[11] = (target.ref - 1) * 256 + param2
		output[index] = row
	end
	return output
end

local function scan_accepted_loaded(loaded, owner_x, owner_z)
	local cultural, decorations, groups, coverage, columns = {}, {}, {}, {}, 0
	for cell_z = owner_z / 16, owner_z / 16 + 4 do
		for cell_x = owner_x / 16, owner_x / 16 + 4 do
			local c, d, g, v, n = loaded.planner_fixture.build_cell(cell_x, cell_z)
			columns = columns + n
			for index = 1, #c do cultural[#cultural + 1] = c[index] end
			for index = 1, #d do decorations[#decorations + 1] = d[index] end
			for index = 1, #g do groups[#groups + 1] = g[index] end
			for index = 1, #v do coverage[#coverage + 1] = v[index] end
		end
	end
	if columns ~= owner_column_count(owner_x, owner_z) then
		fail("accepted R6 owner column population differs")
	end
	return {groups = groups, coverage = coverage,
		candidates = {cultural = cultural, decorations = decorations},
		settlement = loaded.settlement_fixture.scan_horizontal_owner(owner_x, owner_z,
			cultural, decorations)}
end

local function accepted_owner_scan(repo, seed, owner_x, owner_z)
	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	return scan_accepted_loaded(offline.new_evidence(seed, true), owner_x, owner_z)
end

local function settlement_decision_value(settlement, rows, runs)
	return {cultural = settlement.cultural,
		decorations = settlement.decorations, rejections = settlement.rejections,
		witnesses = settlement.witnesses, apex_overlaps = settlement.apex_overlaps,
		direct_rows = rows, direct_runs = runs}

end

local function settlement_decisions(settlement, rows, runs)
	return graph(settlement_decision_value(settlement, rows, runs))
end

function module.canonical_graph_nul_kat()
	-- Exact key forms emitted by r6_settlement.scan_horizontal_owner().  This
	-- catches the integration failure before constructing a production runtime.
	local aggregate_key = "runeslate\0ordinary"
	local rejection_key = "cultural\0runeslate\0wrong_support"
	local encoded = settlement_decisions({
		cultural = {[aggregate_key] = {accepted = 1, reserved = 225}},
		decorations = {}, rejections = {[rejection_key] = 1},
		witnesses = {[aggregate_key] = {zone_id = "front_shattered_line",
			x = -32, y = 23, z = -32}}, apex_overlaps = 0,
	}, {{-32, 23, -32, 1000, 0, 1, 34, 1, 0, 0}},
		{{-32, -32, 23, 23, 9, 34, 16, 10, 0}})
	local aggregate_scalar = "s" .. tostring(#aggregate_key) .. ":" .. aggregate_key
	local rejection_scalar = "s" .. tostring(#rejection_key) .. ":" .. rejection_key
	if not encoded:find(aggregate_scalar, 1, true) or
			not encoded:find(rejection_scalar, 1, true) then
		fail("canonical graph lost a production NUL-delimited key")
	end
	local distinct = settlement_decisions({cultural = {}, decorations = {},
		rejections = {[rejection_key .. "x"] = 1}, witnesses = {}, apex_overlaps = 0},
		{}, {})
	if encoded == distinct then fail("canonical graph key framing is ambiguous") end
	return true
end

function module.first_difference_kat(repo)
	local aggregate_key = "runeslate\0ordinary"
	local actual = {cultural = {[aggregate_key] = {accepted = 1, reserved = 225}},
		direct_rows = {{-32, 23, -32, 1000, 0, 1, 34, 4, 0, 768}}}
	local expected = {cultural = {[aggregate_key] = {accepted = 1, reserved = 225}},
		direct_rows = {{-32, 23, -32, 1000, 0, 1, 34, 4, 0, 512}}}
	local difference = first_difference(repo, actual, expected, "settlement")
	if not difference or difference.path ~= "settlement.direct_rows[1][10]" or
			difference.actual ~= "number(768)" or
			difference.expected ~= "number(512)" or
			#difference_message(difference) > 320 then
		fail("bounded first-difference diagnostic KAT differs")
	end
	local missing = first_difference(repo, actual, {cultural = {},
		direct_rows = actual.direct_rows}, "settlement")
	if not missing or not missing.path:find("\\0", 1, true) or
			#difference_message(missing) > 420 then
		fail("NUL-key first-difference diagnostic KAT differs")
	end
	return true
end

function module.stage_b_row_diagnostic_kat()
	local source = {{-17, 8, 23, 144, 0, -1, 0, 0, 0, 0}}
	local normalized = {{-17, 8, 23, 1044, 0, -1, 0, 0, 0, 11264}}
	local accepted = {{-17, 8, 23, 1044, 0, -1, 0, 0, 0, 0}}
	local runtime_fixture = {name_by_cid = {[144] = "default:stone"}}
	local binding = {rows = {[45] = {name = "default:stone", mask = 1}}}
	local message = stage_b_row_diagnostic(runtime_fixture, binding,
		"settlement.direct_rows[1][10]", source, normalized, accepted)
	if not message:find("source_row=-17,8,23,144,0,-1,0,0,0,0", 1, true) or
			not message:find("normalized_row=-17,8,23,1044,0,-1,0,0,0,11264", 1,
				true) or
			not message:find("accepted_row=-17,8,23,1044,0,-1,0,0,0,0", 1, true) or
			not message:find("source_name=default:stone normalized_ref=45 " ..
				"accepted_name=default:stone accepted_role_mask=1", 1, true) or
			#message > 720 then
		fail("Stage-B bounded row diagnostic KAT differs")
	end
	return true
end

local function stage_b_owner(repo, runtime_fixture, binding, direct, accepted)
	local normalized, substitutions = normalize_rows(runtime_fixture, binding,
		direct.settlement.direct_rows)
	local normalized_runs = normalize_runs(runtime_fixture, binding,
		direct.settlement.direct_runs)
	if graph(direct.groups) ~= graph(accepted.groups) or
			graph(direct.coverage) ~= graph(accepted.coverage) then
		fail("Stage-B planner candidate projection differs")
	end
	if graph(direct.candidates) ~= graph(accepted.candidates) then
		fail("Stage-B planner candidate coordinates differ")
	end
	local production_settlement = settlement_decision_value(direct.settlement,
		normalized, normalized_runs)
	local predecessor_settlement = settlement_decision_value(accepted.settlement,
		accepted.settlement.direct_rows, accepted.settlement.direct_runs)
	local production = graph({groups = direct.groups, coverage = direct.coverage,
		candidates = direct.candidates,
		settlement = graph(production_settlement)})
	local predecessor = graph({groups = accepted.groups, coverage = accepted.coverage,
		candidates = accepted.candidates,
		settlement = graph(predecessor_settlement)})
	if production ~= predecessor then
		local difference = first_difference(repo, production_settlement,
			predecessor_settlement, "settlement")
		if not difference then fail("Stage-B graph parity differs without a value diff") end
		fail("Stage-B normalized placement decisions differ from accepted R6: " ..
			difference_message(difference) .. stage_b_row_diagnostic(runtime_fixture,
				binding, difference.path, direct.settlement.direct_rows, normalized,
				accepted.settlement.direct_rows))
	end
	return {bytes = production, accepted_bytes = predecessor,
		substitutions = substitutions}
end

local function probe_rejections(runtime_fixture)
	local evidence, built = runtime_fixture.built.evidence, runtime_fixture.built
	local catalog = runtime_fixture.catalog.p9g_sources()
	local ordinary_index, shore_index
	for index = 1, #catalog do
		if catalog[index].shore_predicate == "none" and not ordinary_index then
			ordinary_index = index
	elseif catalog[index].shore_predicate ~= "none" and not shore_index then
			shore_index = index
	end
	end
	if not ordinary_index or not shore_index then fail("P9G probe catalog classes differ") end
	local function context(index, mode)
		local row = catalog[index]
		local zone, host = row.zones[1], row.hosts[1]
		local support_name = host.support
		local support_ref
		for ref = 1, #built.content.production.content_names do
			if built.content.production.content_names[ref] == support_name then
				support_ref = ref break
			end
		end
		if not support_ref then fail("P9G probe support ref is absent") end
		local support_cid = built.content.production.content_cids[support_ref]
		local air_cid = runtime_fixture.cid_by_name.air
		local ignore_cid = built.content.production.ignore_cid
		return {
			inside_owner = function() return mode ~= "clipped_owner" end,
			original_at = function()
				return mode == "content_ignore" and ignore_cid or air_cid, 0
			end,
			settled_at = function(_, y)
				if mode == "insufficient_clearance" and y == 11 then
					return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
				elseif mode == "r6_occupancy" and y == 11 then
					return air_cid, 0, 1, 0, 0, 0, 0
				elseif y == 11 then
					return air_cid, 0, 0, 0, 0, 0, 0
				end
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end,
			production_content = function(name)
				for ref = 1, #built.content.production.content_names do
					if built.content.production.content_names[ref] == name then
						return ref, built.content.production.content_cids[ref]
					end
				end
				return nil, nil
			end,
			analytic_p7_ref = function()
				return mode == "wrong_support" and support_ref + 1 or support_ref
			end,
			analytic_p7_tuple = function()
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end,
			exclusion_at = function()
				if mode == "fixed_or_protected" or mode == "route_or_water" then
					return mode
				elseif mode == "dry_wyrmglass_coast" then
					return "route_or_water", "exclude:coast:island_wyrmglass"
				elseif mode == "dry_stormscale_coast" or
						mode == "wet_stormscale_coast" then
					return "route_or_water", "exclude:coast:island_stormscale"
				elseif mode == "unknown_coast" then
					return "route_or_water", "exclude:coast:unknown"
				end
				return nil
			end,
			housing_excluded_at = function() return mode == "housing_exclusion" end,
			column_values_at = function(x, z)
				local actual_zone = mode == "wrong_zone" and "not_a_zone" or zone
				local biome = mode == "wrong_biome" and "not_a_biome" or host.biome
				local water = mode == "wet_stormscale_coast" and
					"immutable_dragon_channel" or "land"
				if index == shore_index and mode ~= "wrong_shore" and
						(x ~= 10 or z ~= 10) then
					water = row.shore_water_classes[1]
				end
				return water, 1, actual_zone, biome, "human", 10, nil
			end,
		}
	end
	local reasons = {"clipped_owner", "fixed_or_protected", "route_or_water",
		"housing_exclusion", "content_ignore", "wrong_zone", "wrong_biome",
		"wrong_support", "insufficient_clearance", "r6_occupancy"}
	for index = 1, #reasons do
		local reason = evidence.probe_p9g_reason(context(ordinary_index, reasons[index]),
			ordinary_index, 10, 11, 10)
		if reason ~= reasons[index] then
			fail("P9G rejection probe differs for " .. reasons[index] .. ": " .. reason)
		end
	end
	local shore_reason = evidence.probe_p9g_reason(context(shore_index, "wrong_shore"),
		shore_index, 10, 11, 10)
	if shore_reason ~= "wrong_shore" then fail("P9G wrong-shore probe differs") end
	local accepted = evidence.probe_p9g_reason(context(ordinary_index, "accepted"),
		ordinary_index, 10, 11, 10)
	if accepted ~= "accepted" then fail("P9G accepted probe differs") end
	for _, mode in ipairs({"dry_wyrmglass_coast", "dry_stormscale_coast"}) do
		local island = evidence.probe_p9g_reason(context(ordinary_index, mode),
			ordinary_index, 10, 11, 10)
		if island ~= "accepted" then
			fail("P9G dry island-coast probe differs for " .. mode)
		end
	end
	for _, mode in ipairs({"wet_stormscale_coast", "unknown_coast"}) do
		local blocked = evidence.probe_p9g_reason(context(ordinary_index, mode),
			ordinary_index, 10, 11, 10)
		if blocked ~= "route_or_water" then
			fail("P9G island-coast fail-closed probe differs for " .. mode)
		end
	end
	return true
end

local function owner_minimum(value)
	return -30912 + math.floor((value + 30912) / 80) * 80
end

local HEIGHTMAP_SENTINEL = -31007

local function heightmap_for_band(raw, min_y, max_y)
	dense(raw, "raw analytic heightmap")
	if #raw ~= 6400 then fail("raw analytic heightmap population differs") end
	integer(min_y, -31007, 31007, "heightmap owner minimum")
	integer(max_y, -31007, 31007, "heightmap owner maximum")
	if max_y ~= min_y + 79 or owner_minimum(min_y) ~= min_y then
		fail("heightmap owner band differs")
	end
	local projected = {}
	for index = 1, 6400 do
		local value = integer(raw[index], -31007, 31007,
			"raw analytic heightmap value")
		if value >= min_y and value <= max_y then
			projected[index] = value
		else
			projected[index] = HEIGHTMAP_SENTINEL
		end
	end
	return projected
end

function module.heightmap_projection_kat()
	local min_y, max_y = -32, 47
	local raw = {}
	for index = 1, 6400 do raw[index] = min_y + 7 end
	raw[1], raw[2], raw[3], raw[4] = min_y - 1, min_y, max_y, max_y + 1
	local before = graph(raw)
	local projected = heightmap_for_band(raw, min_y, max_y)
	if #projected ~= 6400 or projected[1] ~= HEIGHTMAP_SENTINEL or
			projected[2] ~= min_y or projected[3] ~= max_y or
			projected[4] ~= HEIGHTMAP_SENTINEL then
		fail("heightmap projection boundary/order KAT differs")
	end
	for index = 5, 6400 do
		if projected[index] ~= min_y + 7 then
			fail("heightmap projection ordering KAT differs")
		end
	end
	if graph(raw) ~= before then fail("heightmap projection mutated raw input") end
	local short = {}
	for index = 1, 6399 do short[index] = min_y end
	local ok = pcall(heightmap_for_band, short, min_y, max_y)
	if ok then fail("heightmap projection accepted a short input") end
	return true
end

local function validate_vm_commit(result, snapshot, label)
	if type(result) ~= "string" or not result:find("^applied_") then
		fail(label .. " did not commit one transaction")
	end
	local suffix = result:match("^applied_([cplq]+)$")
	if not suffix then fail(label .. " result vocabulary differs") end
	local calls = snapshot.calls
	local function changed(letter) return suffix:find(letter, 1, true) ~= nil end
	for _, name in ipairs({"get_emerged_area", "get_data", "get_param2_data"}) do
		if calls[name] ~= 1 then fail(label .. " call count differs for " .. name) end
	end
	if calls.get_light_data ~= (changed("l") and 2 or 0) or
			calls.set_data ~= (changed("c") and 1 or 0) or
			calls.set_param2_data ~= (changed("p") and 1 or 0) or
			calls.calc_lighting ~= (changed("l") and 1 or 0) or
			calls.set_light_data ~= (changed("l") and 1 or 0) or
			calls.update_liquids ~= (changed("q") and 1 or 0) then
		fail(label .. " conditional VM call counts differ")
	end
	if (changed("l") and (calls.set_lighting < 1 or calls.set_lighting > 6401)) or
			(not changed("l") and calls.set_lighting ~= 0) then
		fail(label .. " lighting seed-call bound differs")
	end
	if snapshot.inactive_tail_unchanged ~= true then
		fail(label .. " retained inactive tail changed")
	end
	return suffix
end

local function compare_vm_arrays(left, right, label)
	for _, field in ipairs({"data", "param2", "light"}) do
		if #left[field] ~= #right[field] then fail(label .. " " .. field .. " shape differs") end
		for index = 1, #left[field] do
			if left[field][index] ~= right[field][index] then
				fail(label .. " " .. field .. " differs at VM index " .. tostring(index))
			end
		end
	end
end

local function snapshot_index(snapshot, x, y, z)
	if x < snapshot.emin.x or x > snapshot.emax.x or
			y < snapshot.emin.y or y > snapshot.emax.y or
			z < snapshot.emin.z or z > snapshot.emax.z then
		return nil
	end
	local axis_x = snapshot.emax.x - snapshot.emin.x + 1
	local axis_y = snapshot.emax.y - snapshot.emin.y + 1
	return (z - snapshot.emin.z) * axis_x * axis_y +
		(y - snapshot.emin.y) * axis_x + (x - snapshot.emin.x) + 1
end

local function actual_run_bytes(values, count, drop_opcode, normalize)
	dense(values, "actual settlement run values")
	integer(count, 0, MAX_SAFE, "actual settlement run count")
	if #values ~= count * 9 then fail("actual settlement run shape differs") end
	local output = {"schema\tgrug_wp40_r7_actual_run_projection_v1\n"}
	local dropped = 0
	for run = 1, count do
		local base, row = (run - 1) * 9, {}
		for field = 1, 9 do
			row[field] = integer(values[base + field], -MAX_SAFE, MAX_SAFE,
				"actual settlement run field")
		end
		if normalize then row = normalize(row) end
		if drop_opcode and row[4] == drop_opcode then
			dropped = dropped + 1
		else
			local fields = {}
			for field = 1, 9 do fields[field] = tostring(row[field]) end
			output[#output + 1] = "run\t" .. table.concat(fields, "\t") .. "\n"
		end
	end
	return table.concat(output), dropped
end

local PRIVATE_CAPTURE_FIELDS = {
	schema = true, min_x = true, min_y = true, min_z = true,
	max_x = true, max_y = true, max_z = true, tuple_order = true,
	tuple_stride = true, tuple_count = true, tuple_values = true,
	tuple_sha256 = true, run_stride = true, run_count = true,
	run_values = true, run_sha256 = true, run_checksum_a = true,
	run_checksum_b = true, ledger = true, ledger_sha256 = true,
	metrics = true,
}

local PRIVATE_CAPTURE_METRIC_FIELDS = {
	schema = true, tuple_count = true, tuple_scalar_count = true,
	tuple_encoded_bytes = true, run_count = true, run_scalar_count = true,
	run_encoded_bytes = true, run_checksum_a = true, run_checksum_b = true,
	ledger_encoded_bytes = true,
}

local function private_tuple_header(capture)
	return table.concat({
		"schema\tgrug_wp40_r7_private_tuple_tsv_v1\n",
		"bounds\t", string.format("%.0f", capture.min_x), "\t",
		string.format("%.0f", capture.min_y), "\t",
		string.format("%.0f", capture.min_z), "\t",
		string.format("%.0f", capture.max_x), "\t",
		string.format("%.0f", capture.max_y), "\t",
		string.format("%.0f", capture.max_z), "\n",
		"order\tz_outer_x_middle_y_inner\n",
		"fields\tdata\tparam2\toccupancy\topcode\tfeature\tinterface\taux\n",
	})
end

local function private_run_header()
	return table.concat({
		"schema\tgrug_wp40_r7_private_run_tsv_v1\n",
		"fields\tymin\tymax\tclass\topcode\tkind\tpolicy\tfeature\tinterface\taux\n",
	})
end

local function validate_private_capture(repo, capture, minp, maxp, expect_ledger,
		label)
	exact_fields(capture, PRIVATE_CAPTURE_FIELDS, label .. " private capture")
	if capture.schema ~= "grug_wp40_r7_private_buffer_capture_v1" or
			capture.tuple_order ~= "z_outer_x_middle_y_inner" or
			capture.tuple_stride ~= 7 or capture.run_stride ~= 9 then
		fail(label .. " private capture identity differs")
	end
	for _, axis in ipairs({"x", "y", "z"}) do
		if capture["min_" .. axis] ~= minp[axis] or
				capture["max_" .. axis] ~= maxp[axis] then
			fail(label .. " private capture bounds differ")
		end
	end
	local tuple_count = (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) *
		(maxp.z - minp.z + 1)
	integer(capture.tuple_count, 1, MAX_SAFE, label .. " tuple count")
	dense(capture.tuple_values, label .. " tuple values")
	if capture.tuple_count ~= tuple_count or #capture.tuple_values ~= tuple_count * 7 then
		fail(label .. " private tuple shape differs")
	end
	digest(capture.tuple_sha256, label .. " tuple digest")
	integer(capture.run_count, 0, MAX_SAFE, label .. " run count")
	dense(capture.run_values, label .. " run values")
	if #capture.run_values ~= capture.run_count * 9 then
		fail(label .. " private run shape differs")
	end
	digest(capture.run_sha256, label .. " run digest")
	digest(capture.ledger_sha256, label .. " ledger digest")
	integer(capture.run_checksum_a, 0, 6700416, label .. " run checksum A")
	integer(capture.run_checksum_b, 0, 15485862, label .. " run checksum B")

	local stream = sha_stream(repo)
	local tuple_hasher, tuple_bytes = stream.new(), 0
	local function tuple_update(bytes)
		tuple_hasher.update(bytes); tuple_bytes = tuple_bytes + #bytes
	end
	tuple_update(private_tuple_header(capture))
	local rows = {}
	for tuple = 1, capture.tuple_count do
		local base, fields = (tuple - 1) * 7, {}
		for field = 1, 7 do
			local value = integer(capture.tuple_values[base + field], -MAX_SAFE,
				MAX_SAFE, label .. " private tuple scalar")
			fields[field] = string.format("%.0f", value)
		end
		rows[#rows + 1] = "tuple\t" .. table.concat(fields, "\t") .. "\n"
		if #rows == 4096 then tuple_update(table.concat(rows)); rows = {} end
	end
	if #rows > 0 then tuple_update(table.concat(rows)) end
	if tuple_hasher.final_hex() ~= capture.tuple_sha256 then
		fail(label .. " private tuple digest differs")
	end

	local run_hasher, run_bytes = stream.new(), 0
	local function run_update(bytes)
		run_hasher.update(bytes); run_bytes = run_bytes + #bytes
	end
	run_update(private_run_header())
	local checksum_a, checksum_b = 1, 7
	for run = 1, capture.run_count do
		local base, fields = (run - 1) * 9, {}
		for field = 1, 9 do
			local value = integer(capture.run_values[base + field], -MAX_SAFE,
				MAX_SAFE, label .. " private run scalar")
			fields[field] = string.format("%.0f", value)
			checksum_a = (checksum_a * 131 + (value + 31012)) % 6700417
			checksum_b = (checksum_b * 257 + (value + 31012)) % 15485863
		end
		run_update("run\t" .. table.concat(fields, "\t") .. "\n")
	end
	if run_hasher.final_hex() ~= capture.run_sha256 or
			checksum_a ~= capture.run_checksum_a or
			checksum_b ~= capture.run_checksum_b then
		fail(label .. " private run authority differs")
	end

	local ledger_bytes
	if expect_ledger then
		if type(capture.ledger) ~= "table" or type(capture.ledger.p9g) ~= "table" then
			fail(label .. " private successor ledger is absent")
		end
		validate_ledger(capture.ledger.p9g)
		ledger_bytes = "schema\tgrug_wp40_r7_private_ledger_graph_v1\nledger\t" ..
			graph(capture.ledger) .. "\n"
	else
		if capture.ledger ~= false then fail(label .. " private direct ledger differs") end
		ledger_bytes = "schema\tgrug_wp40_r7_private_ledger_graph_v1\nnone\n"
	end
	if sha256(repo, ledger_bytes) ~= capture.ledger_sha256 then
		fail(label .. " private ledger digest differs")
	end

	local metrics = exact_fields(capture.metrics, PRIVATE_CAPTURE_METRIC_FIELDS,
		label .. " private capture metrics")
	if metrics.schema ~= "grug_wp40_r7_private_buffer_capture_metrics_v1" or
			metrics.tuple_count ~= capture.tuple_count or
			metrics.tuple_scalar_count ~= #capture.tuple_values or
			metrics.tuple_encoded_bytes ~= tuple_bytes or
			metrics.run_count ~= capture.run_count or
			metrics.run_scalar_count ~= #capture.run_values or
			metrics.run_encoded_bytes ~= run_bytes or
			metrics.run_checksum_a ~= capture.run_checksum_a or
			metrics.run_checksum_b ~= capture.run_checksum_b or
			metrics.ledger_encoded_bytes ~= #ledger_bytes then
		fail(label .. " private capture metrics differ")
	end
	return capture
end

local function capture_tuple_base(capture, x, y, z)
	if x < capture.min_x or x > capture.max_x or y < capture.min_y or
			y > capture.max_y or z < capture.min_z or z > capture.max_z then
		return nil
	end
	local x_count, y_count = capture.max_x - capture.min_x + 1,
		capture.max_y - capture.min_y + 1
	local tuple = (z - capture.min_z) * x_count * y_count +
		(x - capture.min_x) * y_count + (y - capture.min_y)
	return tuple * 7
end

local function same_capture_runs(left, right, label)
	if left.run_count ~= right.run_count or #left.run_values ~= #right.run_values then
		fail(label .. " private run population differs")
	end
	for index = 1, #left.run_values do
		if left.run_values[index] ~= right.run_values[index] then
			fail(label .. " private run scalar differs at " .. tostring(index))
		end
	end
end

local function fixture_runs_match_capture(fixture, capture, label)
	local values, count = fixture.run_values()
	if count ~= capture.run_count or #values ~= #capture.run_values then
		fail(label .. " capture/fixture run population differs")
	end
	for index = 1, #values do
		if values[index] ~= capture.run_values[index] then
			fail(label .. " capture/fixture run scalar differs")
		end
	end
end

local function normalize_actual_run(runtime_fixture, binding, source)
	local row = {}
	for field = 1, 9 do row[field] = source[field] end
	local names = runtime_fixture.built.content.production.content_names
	local ref = math.floor(source[9] / 256) + 1
	local param2 = source[9] % 256
	local name, target = names[ref], names[ref] and binding.by_name[names[ref]]
	if not target and name and binding.cultural[name] then
		if source[4] ~= 34 then
			fail("full-VM Cultural run substitution escaped opcode 34")
		end
		target = assert(binding.by_name["grug_nodes:bone_pile"])
	elseif not target then
		fail("full-VM Direct-83 run has no accepted content mapping")
	end
	row[9] = (target.ref - 1) * 256 + param2
	return row
end

local function normalize_direct_snapshot(runtime_fixture, binding, direct_scan,
		accepted_scan, accepted_loaded, snapshot)
	local accepted_rows, cultural_positions = {}, {}
	for index = 1, #accepted_scan.settlement.direct_rows do
		local row = accepted_scan.settlement.direct_rows[index]
		accepted_rows[row_key(row)] = row
	end
	local bone = assert(binding.by_name["grug_nodes:bone_pile"])
	for index = 1, #direct_scan.settlement.direct_rows do
		local row = direct_scan.settlement.direct_rows[index]
		local name = runtime_fixture.name_by_cid[row[4]]
		if name and binding.cultural[name] then
			local accepted = accepted_rows[row_key(row)]
			if row[7] ~= 34 or not accepted or accepted[7] ~= 34 or
					accepted[8] ~= row[8] or accepted[4] ~= bone.cid then
				fail("full-VM Cultural coordinate/opcode/feature mapping differs")
			end
			cultural_positions[row_key(row)] = true
		end
	end
	local axis_x = snapshot.emax.x - snapshot.emin.x + 1
	local axis_y = snapshot.emax.y - snapshot.emin.y + 1
	for index = 1, #snapshot.data do
		local offset = index - 1
		local z_offset = math.floor(offset / (axis_x * axis_y))
		offset = offset - z_offset * axis_x * axis_y
		local y_offset = math.floor(offset / axis_x)
		local x_offset = offset - y_offset * axis_x
		local key = tostring(snapshot.emin.x + x_offset) .. "/" ..
			tostring(snapshot.emin.y + y_offset) .. "/" ..
			tostring(snapshot.emin.z + z_offset)
		local cid = snapshot.data[index]
		local name = runtime_fixture.name_by_cid[cid]
		local target
		if name and binding.cultural[name] then
			if not cultural_positions[key] then
				fail("full-VM Cultural CID escaped an exact Cultural placement")
			end
			target = bone.cid
		elseif name == "ignore" then
			target = accepted_loaded.content_contract.ignore_cid
		elseif name then
			target = accepted_loaded.cid_by_name[name]
			if binding.by_name[name] and target ~= binding.by_name[name].cid then
				fail("accepted full-VM content CID differs from artifact")
			end
		end
		if target == nil then
			fail("full-VM Direct-83 CID has no accepted mapping: " .. tostring(name))
		end
		snapshot.data[index] = target
	end
end

local function compare_stage_a_captures(repo, successor, direct)
	if successor.tuple_count ~= direct.tuple_count or
			private_tuple_header(successor) ~= private_tuple_header(direct) then
		fail("Stage-A private capture shape differs")
	end
	local ledger = validate_ledger(successor.ledger.p9g)
	local accepted_by_base, accepted = {}, 0
	for index = 1, #ledger.operations do
		local operation = ledger.operations[index]
		if operation.accepted then
			local base = capture_tuple_base(successor, operation.root_x,
				operation.root_y, operation.root_z)
			if base == nil or accepted_by_base[base] then
				fail("Stage-A accepted P9G capture root differs")
			end
			accepted_by_base[base] = operation
			accepted = accepted + 1
			local finals = {operation.final_cid, operation.final_param2,
				operation.final_occupancy, operation.final_opcode,
				operation.final_feature, operation.final_interface, operation.final_aux}
			for field = 1, 7 do
				if successor.tuple_values[base + field] ~= finals[field] then
					fail("Stage-A private final tuple differs at accepted root")
				end
			end
		end
	end
	local prior_fields = {"prior_cid", "prior_param2", "prior_occupancy",
		"prior_opcode", "prior_feature", "prior_interface", "prior_aux"}
	for tuple = 1, successor.tuple_count do
		local base = (tuple - 1) * 7
		local operation = accepted_by_base[base]
		for field = 1, 7 do
			local restored = operation and operation[prior_fields[field]] or
				successor.tuple_values[base + field]
			if restored ~= direct.tuple_values[base + field] then
				fail("Stage-A restored private tuple differs at tuple " ..
					tostring(tuple) .. " field " .. tostring(field))
			end
		end
	end
	local restored_runs, dropped = actual_run_bytes(successor.run_values,
		successor.run_count, 35)
	local direct_runs = actual_run_bytes(direct.run_values, direct.run_count)
	if dropped ~= accepted or restored_runs ~= direct_runs then
		fail("Stage-A restored private production runs differ")
	end
	return {accepted = accepted, tuple_sha256 = direct.tuple_sha256,
		run_sha256 = direct.run_sha256,
		restored_run_projection_sha256 = sha256(repo, restored_runs)}
end

local function accepted_content_target(runtime_fixture, binding, accepted_loaded,
		name, opcode, accepted_values, accepted_base)
	local target_name = name
	if name and binding.cultural[name] then
		if opcode ~= 34 or accepted_values[accepted_base + 4] ~= 34 or
				accepted_values[accepted_base + 5] == nil then
			fail("Stage-B private Cultural substitution escaped opcode 34")
		end
		target_name = "grug_nodes:bone_pile"
	end
	local cid
	if target_name == "air" then cid = 0
	elseif target_name == "ignore" then cid = accepted_loaded.content_contract.ignore_cid
	else cid = accepted_loaded.cid_by_name[target_name] end
	if cid == nil then
		fail("Stage-B private CID has no accepted mapping: " .. tostring(name))
	end
	if binding.by_name[target_name] and
			cid ~= binding.by_name[target_name].cid then
		fail("Stage-B private accepted CID differs from artifact")
	end
	return target_name, cid
end

local function compare_stage_b_captures(repo, runtime_fixture, binding,
		accepted_loaded, direct, accepted)
	if direct.tuple_count ~= accepted.tuple_count or
			private_tuple_header(direct) ~= private_tuple_header(accepted) then
		fail("Stage-B private capture shape differs")
	end
	local stream, tuple_hasher, tuple_bytes = sha_stream(repo), nil, 0
	tuple_hasher = stream.new()
	local function tuple_update(bytes)
		tuple_hasher.update(bytes); tuple_bytes = tuple_bytes + #bytes
	end
	tuple_update(private_tuple_header(accepted))
	local rows, substitutions = {}, 0
	local production_names = runtime_fixture.built.content.production.content_names
	for tuple = 1, direct.tuple_count do
		local base, normalized = (tuple - 1) * 7, {}
		for field = 1, 7 do normalized[field] = direct.tuple_values[base + field] end
		local name = runtime_fixture.name_by_cid[normalized[1]]
		local target_name, target_cid = accepted_content_target(runtime_fixture,
			binding, accepted_loaded, name, normalized[4], accepted.tuple_values, base)
		if binding.cultural[name] then
			if accepted.tuple_values[base + 5] ~= normalized[5] then
				fail("Stage-B private Cultural feature differs")
			end
			substitutions = substitutions + 1
		end
		normalized[1] = target_cid
		if normalized[7] ~= 0 or target_name ~= "air" then
			local ref = math.floor(normalized[7] / 256) + 1
			local param2 = normalized[7] % 256
			local aux_name = production_names[ref]
			if not aux_name then
				fail("Stage-B private aux ref escaped production content")
			end
			local aux_target = aux_name
			if binding.cultural[aux_name] then
				if normalized[4] ~= 34 then
					fail("Stage-B private Cultural aux escaped opcode 34")
				end
				aux_target = "grug_nodes:bone_pile"
			end
			local accepted_ref = accepted_loaded.ref_by_name[aux_target]
			if not accepted_ref then fail("Stage-B private aux has no accepted ref") end
			normalized[7] = (accepted_ref - 1) * 256 + param2
		end
		local fields = {}
		for field = 1, 7 do
			if normalized[field] ~= accepted.tuple_values[base + field] then
				fail("Stage-B normalized private tuple differs at tuple " ..
					tostring(tuple) .. " field " .. tostring(field))
			end
			fields[field] = string.format("%.0f", normalized[field])
		end
		rows[#rows + 1] = "tuple\t" .. table.concat(fields, "\t") .. "\n"
		if #rows == 4096 then tuple_update(table.concat(rows)); rows = {} end
	end
	if #rows > 0 then tuple_update(table.concat(rows)) end
	local normalized_tuple_sha = tuple_hasher.final_hex()
	if normalized_tuple_sha ~= accepted.tuple_sha256 or
			tuple_bytes ~= accepted.metrics.tuple_encoded_bytes then
		fail("Stage-B normalized private tuple digest differs")
	end

	if direct.run_count ~= accepted.run_count then
		fail("Stage-B private run population differs")
	end
	local run_hasher, run_bytes = stream.new(), 0
	local function run_update(bytes)
		run_hasher.update(bytes); run_bytes = run_bytes + #bytes
	end
	run_update(private_run_header())
	for run = 1, direct.run_count do
		local base, row = (run - 1) * 9, {}
		for field = 1, 9 do row[field] = direct.run_values[base + field] end
		if row[9] == 0 then
			local structural = true
			for field = 1, 8 do
				if row[field] ~= accepted.run_values[base + field] then structural = false end
			end
			if accepted.run_values[base + 9] ~= 0 then structural = false end
			if not structural then
				row = normalize_actual_run(runtime_fixture, binding, row)
			end
		else
			row = normalize_actual_run(runtime_fixture, binding, row)
		end
		local fields = {}
		for field = 1, 9 do
			if row[field] ~= accepted.run_values[base + field] then
				fail("Stage-B normalized private run differs at run " ..
					tostring(run) .. " field " .. tostring(field))
			end
			fields[field] = string.format("%.0f", row[field])
		end
		run_update("run\t" .. table.concat(fields, "\t") .. "\n")
	end
	local normalized_run_sha = run_hasher.final_hex()
	if normalized_run_sha ~= accepted.run_sha256 or
			run_bytes ~= accepted.metrics.run_encoded_bytes then
		fail("Stage-B normalized private run digest differs")
	end
	return {substitutions = substitutions, tuple_sha256 = normalized_tuple_sha,
		run_sha256 = normalized_run_sha}
end

local function sorted_operations(operations)
	table.sort(operations, function(left, right)
		if left.root_z ~= right.root_z then return left.root_z < right.root_z end
		if left.root_x ~= right.root_x then return left.root_x < right.root_x end
		if left.root_y ~= right.root_y then return left.root_y < right.root_y end
		return less_bytes(left.source_id, right.source_id)
	end)
	return operations
end

local function multi_y_owner_kat(repo, runtime_fixture, horizontal)
	if horizontal.owner_x ~= MULTI_Y_OWNER_X or
			horizontal.owner_z ~= MULTI_Y_OWNER_Z then
		fail("multi-y KAT owner identity differs")
	end
	local heights = {}
	for z = horizontal.owner_z, horizontal.owner_z + 79 do
		for x = horizontal.owner_x, horizontal.owner_x + 79 do
			heights[#heights + 1] =
				runtime_fixture.built.zones_session.terrain_height_at(x, z)
		end
	end
	if #heights ~= 6400 then fail("multi-y KAT height population differs") end
	local bands, ordered_bands = {}, {}
	for index = 1, #heights do
		local band = owner_minimum(heights[index] + 1)
		if not bands[band] then bands[band] = true; ordered_bands[#ordered_bands + 1] = band end
	end
	table.sort(ordered_bands)
	if #ordered_bands < 2 then
		fail("multi-y KAT owner surfaces do not span two vertical owners")
	end
	local horizontal_ledger = validate_ledger(horizontal.settlement.p9g)
	local active_bands, ordered_active_bands, active_count = {}, {}, 0
	for index = 1, #horizontal_ledger.operations do
		local band = owner_minimum(horizontal_ledger.operations[index].root_y)
		if not active_bands[band] then
			active_bands[band] = true
			ordered_active_bands[#ordered_active_bands + 1] = band
			active_count = active_count + 1
		end
	end
	table.sort(ordered_active_bands)
	if active_count < 2 then
		fail("multi-y KAT lacks two active P9G vertical owners")
	end
	if #horizontal_ledger.operations ~= 5 or active_count ~= 2 or
			ordered_active_bands[1] ~= -32 or ordered_active_bands[2] ~= 48 then
		fail("multi-y KAT frozen discovery criteria differ")
	end
	local aggregate = {eligible = 0, planned = 0, accepted = 0,
		rejections = {}, groups = {}, populations = {}, operations = {}, roots = {}}
	for index = 1, #P9G_REASONS do aggregate.rejections[P9G_REASONS[index]] = 0 end
	local consumed = {}
	local function consume(capture, band)
		if consumed[band] then fail("multi-y KAT repeated one vertical owner") end
		consumed[band] = true
		local ledger = validate_ledger(capture.ledger.p9g)
		if ledger.manifest_sha256 ~= horizontal_ledger.manifest_sha256 or
				ledger.rejections.clipped_owner ~= 0 then
			fail("multi-y KAT manifest/artificial clipping differs")
		end
		for _, field in ipairs({"eligible", "planned", "accepted"}) do
			aggregate[field] = aggregate[field] + ledger[field]
		end
		for index = 1, #P9G_REASONS do
			local reason = P9G_REASONS[index]
			aggregate.rejections[reason] = aggregate.rejections[reason] +
				ledger.rejections[reason]
		end
		for index = 1, #ledger.groups do
			local row = ledger.groups[index]
			local key = table.concat({row.source_id, row.cell_x, row.cell_z}, "\0")
			local target = aggregate.groups[key]
			if not target then
				target = {source_id = row.source_id, cell_x = row.cell_x,
					cell_z = row.cell_z, eligible = 0, budget = 0, accepted = 0,
					rejections = {}}
				for reason = 1, #P9G_REASONS do
					target.rejections[P9G_REASONS[reason]] = 0
				end
				aggregate.groups[key] = target
			end
			for _, field in ipairs({"eligible", "budget", "accepted"}) do
				target[field] = target[field] + row[field]
			end
			for reason = 1, #P9G_REASONS do
				local name = P9G_REASONS[reason]
				target.rejections[name] = target.rejections[name] + row.rejections[name]
			end
		end
		for index = 1, #ledger.populations do
			local row = ledger.populations[index]
			local key = population_key(row.source_id, row.zone_id, row.biome,
				row.faction, row.bracket)
			local target = aggregate.populations[key]
			if not target then
				target = {source_id = row.source_id, zone_id = row.zone_id,
					biome = row.biome, faction = row.faction, bracket = row.bracket,
					eligible = 0, budget = 0, accepted = 0, rejections = {}}
				for reason = 1, #P9G_REASONS do
					target.rejections[P9G_REASONS[reason]] = 0
				end
				aggregate.populations[key] = target
			end
			for _, field in ipairs({"eligible", "budget", "accepted"}) do
				target[field] = target[field] + row[field]
			end
			for reason = 1, #P9G_REASONS do
				local name = P9G_REASONS[reason]
				target.rejections[name] = target.rejections[name] + row.rejections[name]
			end
		end
		for index = 1, #ledger.operations do
			local operation = ledger.operations[index]
			if owner_minimum(operation.root_y) ~= band then
				fail("multi-y KAT operation escaped its vertical owner")
			end
			local root = table.concat({operation.root_x, operation.root_y,
				operation.root_z, operation.source_id}, "/")
			if aggregate.roots[root] then fail("multi-y KAT operation settled twice") end
			aggregate.roots[root] = true
			aggregate.operations[#aggregate.operations + 1] = operation
		end
	end

	for index = 1, #ordered_bands do
		local band = ordered_bands[index]
		local minp = {x = horizontal.owner_x, y = band, z = horizontal.owner_z}
		local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
		runtime_fixture.set_heightmap(heightmap_for_band(heights, minp.y, maxp.y))
		local vm, _, observer = runtime_fixture.new_vm(minp, maxp)
		local plan, generation = runtime_fixture.built.session.plan_slice(minp, maxp)
		runtime_fixture.built.settlement_fixture.arm_private_capture()
		local result = runtime_fixture.built.writer.apply(vm, minp, maxp,
			plan, generation)
		local capture = runtime_fixture.built.settlement_fixture.take_private_capture()
		validate_vm_commit(result, observer.snapshot(),
			"multi-y R7 production writer")
		validate_private_capture(repo, capture, minp, maxp, true,
			"multi-y R7 production writer")
		fixture_runs_match_capture(runtime_fixture.built.settlement_fixture, capture,
			"multi-y R7 production writer")
		consume(capture, band)
		capture = nil
		collectgarbage("collect")
	end
	for index = 1, #ordered_bands do
		if not consumed[ordered_bands[index]] then fail("multi-y KAT missed a vertical owner") end
	end
	if aggregate.eligible ~= horizontal_ledger.eligible or
			aggregate.planned ~= horizontal_ledger.planned or
			aggregate.accepted ~= horizontal_ledger.accepted or
			graph(aggregate.rejections) ~= graph(horizontal_ledger.rejections) then
		fail("multi-y KAT E/B/accepted/reasons union differs")
	end
	local function compare_aggregate(expected, actual, key_fn, label)
		local seen = {}
		for index = 1, #expected do
			local key = key_fn(expected[index])
			if seen[key] or not actual[key] or graph(expected[index]) ~= graph(actual[key]) then
				fail("multi-y KAT " .. label .. " union differs")
			end
			seen[key] = true
		end
		for key in pairs(actual) do
			if not seen[key] then fail("multi-y KAT extra " .. label .. " union row") end
		end
	end
	compare_aggregate(horizontal_ledger.groups, aggregate.groups, function(row)
		return table.concat({row.source_id, row.cell_x, row.cell_z}, "\0")
	end, "group")
	compare_aggregate(horizontal_ledger.populations, aggregate.populations, function(row)
		return population_key(row.source_id, row.zone_id, row.biome, row.faction,
			row.bracket)
	end, "population")
	if graph(sorted_operations(aggregate.operations)) ~=
			graph(horizontal_ledger.operations) then
		fail("multi-y KAT operation union differs")
	end
	return {owner_x = horizontal.owner_x, owner_z = horizontal.owner_z,
		band_count = #ordered_bands, bands = table.concat(ordered_bands, ","),
		active_band_count = active_count,
		active_bands = table.concat(ordered_active_bands, ","),
		operation_count = #horizontal_ledger.operations,
		eligible = aggregate.eligible, planned = aggregate.planned,
		accepted = aggregate.accepted}
end

local function full_vm_integration(repo, runtime_fixture, successor, direct_scan,
		accepted_scan, multi_y_horizontal, binding, seed)
	local root_y
	for index = 1, #successor.settlement.p9g.operations do
		local operation = successor.settlement.p9g.operations[index]
		if operation.accepted then root_y = operation.root_y break end
	end
	if not root_y then fail("full VM KAT lacks an accepted P9G root") end
	local minp = {x = successor.owner_x, y = owner_minimum(root_y),
		z = successor.owner_z}
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local heights = {}
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			heights[#heights + 1] = runtime_fixture.built.zones_session.terrain_height_at(x, z)
		end
	end
	if #heights ~= 6400 then fail("full VM heightmap population differs") end
	local owner_heightmap = heightmap_for_band(heights, minp.y, maxp.y)
	runtime_fixture.set_heightmap(owner_heightmap)
	local successor_snapshot, successor_result, successor_capture
	local before = runtime_fixture.built.session.metrics()
	do
		local vm, _, observer = runtime_fixture.new_vm(minp, maxp)
		if type(vm) ~= "table" or type(observer) ~= "table" or
				type(observer.snapshot) ~= "function" then
			fail("full VM fixture seam differs")
		end
		local plan, generation = runtime_fixture.built.session.plan_slice(minp, maxp)
		runtime_fixture.built.settlement_fixture.arm_private_capture()
		successor_result = runtime_fixture.built.writer.apply(vm, minp, maxp,
			plan, generation)
		successor_capture = runtime_fixture.built.settlement_fixture.take_private_capture()
		successor_snapshot = observer.snapshot()
		validate_vm_commit(successor_result, successor_snapshot, "R7 production writer")
	end
	validate_private_capture(repo, successor_capture, minp, maxp, true,
		"R7 production writer")
	fixture_runs_match_capture(runtime_fixture.built.settlement_fixture,
		successor_capture, "R7 production writer")
	local metrics = runtime_fixture.built.session.metrics()
	if metrics.settlement.apply_calls - before.settlement.apply_calls ~= 1 or
			metrics.settlement.replay_count - before.settlement.replay_count ~= 1 or
			metrics.p9g.settle_calls - before.p9g.settle_calls ~= 1 or
			metrics.p9g.replay_calls - before.p9g.replay_calls ~= 1 or
			metrics.p9g.accepted - before.p9g.accepted < 1 then
		fail("production writer/replay/P9G metrics differ")
	end
	local direct_snapshot, direct_result, direct_capture
	do
		local vm, _, observer = runtime_fixture.new_vm(minp, maxp)
		local plan, generation = runtime_fixture.built.direct_session.plan_slice(minp, maxp)
		runtime_fixture.built.direct_fixture.arm_private_capture()
		direct_result = runtime_fixture.built.direct_session.apply_fixture(vm, minp, maxp,
			plan, generation)
		direct_capture = runtime_fixture.built.direct_fixture.take_private_capture()
		direct_snapshot = observer.snapshot()
		validate_vm_commit(direct_result, direct_snapshot, "independent Direct-83 writer")
	end
	validate_private_capture(repo, direct_capture, minp, maxp, false,
		"independent Direct-83 writer")
	fixture_runs_match_capture(runtime_fixture.built.direct_fixture, direct_capture,
		"independent Direct-83 writer")
	local stage_a_capture = compare_stage_a_captures(repo, successor_capture,
		direct_capture)

	local restored_count = 0
	for index = 1, #successor_capture.ledger.p9g.operations do
		local operation = successor_capture.ledger.p9g.operations[index]
		if operation.accepted then
			local vm_index = snapshot_index(successor_snapshot, operation.root_x,
				operation.root_y, operation.root_z)
			if not vm_index or operation.root_x < minp.x or operation.root_x > maxp.x or
					operation.root_y < minp.y or operation.root_y > maxp.y or
					operation.root_z < minp.z or operation.root_z > maxp.z then
				fail("accepted integration P9G root escaped the owner VM")
			end
			if successor_snapshot.data[vm_index] ~= operation.final_cid or
					successor_snapshot.param2[vm_index] ~= operation.final_param2 then
				fail("full-VM P9G final tuple differs from production ledger")
			end
			successor_snapshot.data[vm_index] = operation.prior_cid
			successor_snapshot.param2[vm_index] = operation.prior_param2
			restored_count = restored_count + 1
		end
	end
	compare_vm_arrays(successor_snapshot, direct_snapshot,
		"Stage-A restored successor/direct83 VM")
	if restored_count ~= stage_a_capture.accepted then
		fail("Stage-A private/VM restored population differs")
	end
	successor_snapshot = nil
	collectgarbage("collect")

	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	local accepted_loaded = offline.new_capture(seed, owner_heightmap, true)
	if type(accepted_loaded.settlement_fixture) ~= "table" then
		fail("accepted R6 full-VM settlement fixture is absent")
	end
	local accepted_snapshot, accepted_result, accepted_capture
	do
		local volume = (maxp.x - minp.x + 33) * (maxp.y - minp.y + 33) *
			(maxp.z - minp.z + 33)
		local data, param2, light = {}, {}, {}
		for index = 1, volume do data[index], param2[index], light[index] = 0, 0, 0 end
		local vm, _, observer = offline.vm_module.new({minp = minp, maxp = maxp,
			data = data, param2 = param2, light = light, heightmap = owner_heightmap,
			content_contract = accepted_loaded.content_contract, water_level = 1,
			ignore_cid = accepted_loaded.content_contract.ignore_cid,
			verify_inactive_tail = false})
		local plan, generation = accepted_loaded.session.plan_slice(minp, maxp)
		accepted_loaded.settlement_fixture.arm_private_capture()
		accepted_result = accepted_loaded.session.apply_fixture(vm, minp, maxp,
			plan, generation)
		accepted_capture = accepted_loaded.settlement_fixture.take_private_capture()
		accepted_snapshot = observer.snapshot()
		validate_vm_commit(accepted_result, accepted_snapshot, "accepted R6 writer")
	end
	validate_private_capture(repo, accepted_capture, minp, maxp, false,
		"accepted R6 writer")
	fixture_runs_match_capture(accepted_loaded.settlement_fixture, accepted_capture,
		"accepted R6 writer")
	local stage_b_capture = compare_stage_b_captures(repo, runtime_fixture, binding,
		accepted_loaded, direct_capture, accepted_capture)
	normalize_direct_snapshot(runtime_fixture, binding, direct_scan, accepted_scan,
		accepted_loaded, direct_snapshot)
	compare_vm_arrays(direct_snapshot, accepted_snapshot,
		"Stage-B normalized Direct-83/accepted-R6 VM")
	local successor_run_count, direct_run_count, accepted_run_count =
		successor_capture.run_count, direct_capture.run_count, accepted_capture.run_count
	local capture_proof = {
		private_tuple_count = successor_capture.tuple_count,
		successor_tuple_sha256 = successor_capture.tuple_sha256,
		direct_tuple_sha256 = direct_capture.tuple_sha256,
		accepted_tuple_sha256 = accepted_capture.tuple_sha256,
		successor_run_sha256 = successor_capture.run_sha256,
		direct_run_sha256 = direct_capture.run_sha256,
		accepted_run_sha256 = accepted_capture.run_sha256,
		successor_run_checksum_a = successor_capture.run_checksum_a,
		successor_run_checksum_b = successor_capture.run_checksum_b,
		direct_run_checksum_a = direct_capture.run_checksum_a,
		direct_run_checksum_b = direct_capture.run_checksum_b,
		accepted_run_checksum_a = accepted_capture.run_checksum_a,
		accepted_run_checksum_b = accepted_capture.run_checksum_b,
	}
	direct_snapshot, accepted_snapshot = nil, nil
	successor_capture, direct_capture, accepted_capture = nil, nil, nil
	collectgarbage("collect")
	local multi_y = multi_y_owner_kat(repo, runtime_fixture, multi_y_horizontal)
	return {successor_result = successor_result, direct_result = direct_result,
		accepted_result = accepted_result, restored_p9g = restored_count,
		proof_scope = "full_owner_7_private_buffers_pre_replay",
		private_tuple_count = capture_proof.private_tuple_count,
		successor_run_count = successor_run_count,
		direct_run_count = direct_run_count,
		accepted_run_count = accepted_run_count,
		successor_tuple_sha256 = capture_proof.successor_tuple_sha256,
		direct_tuple_sha256 = capture_proof.direct_tuple_sha256,
		accepted_tuple_sha256 = capture_proof.accepted_tuple_sha256,
		successor_run_sha256 = capture_proof.successor_run_sha256,
		direct_run_sha256 = capture_proof.direct_run_sha256,
		accepted_run_sha256 = capture_proof.accepted_run_sha256,
		successor_run_checksum_a = capture_proof.successor_run_checksum_a,
		successor_run_checksum_b = capture_proof.successor_run_checksum_b,
		direct_run_checksum_a = capture_proof.direct_run_checksum_a,
		direct_run_checksum_b = capture_proof.direct_run_checksum_b,
		accepted_run_checksum_a = capture_proof.accepted_run_checksum_a,
		accepted_run_checksum_b = capture_proof.accepted_run_checksum_b,
		stage_a_tuple_sha256 = stage_a_capture.tuple_sha256,
		stage_a_run_sha256 = stage_a_capture.run_sha256,
		stage_b_tuple_sha256 = stage_b_capture.tuple_sha256,
		stage_b_run_sha256 = stage_b_capture.run_sha256,
		stage_b_substitutions = stage_b_capture.substitutions,
		multi_y_owner_x = multi_y.owner_x, multi_y_owner_z = multi_y.owner_z,
		multi_y_band_count = multi_y.band_count, multi_y_bands = multi_y.bands,
		multi_y_active_band_count = multi_y.active_band_count,
		multi_y_active_bands = multi_y.active_bands,
		multi_y_operation_count = multi_y.operation_count,
		multi_y_eligible = multi_y.eligible, multi_y_planned = multi_y.planned,
		multi_y_accepted = multi_y.accepted}
end

function module.integration_kat(repo)
	text(repo, "repository path")
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local seeds = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	seeds.verify(function(bytes) return raw_sha256(repo, bytes) end)
	local runtime_fixture = fixture(repo, seeds.fixed[1])
	local built = runtime_fixture.built
	if built.schema ~= "grug_wp40_r7_runtime_v1" or
		built.evidence.schema ~= "grug_wp40_r7_private_evidence_v1" or
		built.manifest.values.production_enabled ~= true or
		built.manifest.values.writer_schema ~= "grug_wp40_r7_single_vm_writer_v1" or
		built.manifest.values.p9g_order ~= "after_r6_p9_before_run_derivation" or
		built.manifest.values.p9g_overwrite ~= false or
		#built.content.production.content_names ~= 83 or
		#built.content.p9g.content_names ~= 12 then
		fail("production runtime identity differs")
	end
	local binding = artifact_content_binding(repo, runtime_fixture)
	local successor = validate_scan(built.evidence.scan_owner(
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z), INTEGRATION_OWNER_X,
		INTEGRATION_OWNER_Z, true)
	local direct = validate_scan(built.evidence.scan_direct_owner(
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z), INTEGRATION_OWNER_X,
		INTEGRATION_OWNER_Z, false)
	local stage_a = stage_a_owner(repo, runtime_fixture, successor, direct)
	if stage_a.operation_count == 0 or stage_a.accepted == 0 then
		fail("integration owner does not exercise P9G acceptance")
	end
	local accepted = accepted_owner_scan(repo, seeds.fixed[1],
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z)
	local stage_b = stage_b_owner(repo, runtime_fixture, binding, direct, accepted)
	local replay = validate_scan(built.evidence.scan_owner(
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z), INTEGRATION_OWNER_X,
		INTEGRATION_OWNER_Z, true)
	if graph(successor) ~= graph(replay) then fail("production owner replay differs") end
	local multi_y_horizontal = validate_scan(built.evidence.scan_owner(
		MULTI_Y_OWNER_X, MULTI_Y_OWNER_Z), MULTI_Y_OWNER_X,
		MULTI_Y_OWNER_Z, true)
	probe_rejections(runtime_fixture)
	local full_vm = full_vm_integration(repo, runtime_fixture, successor, direct,
		accepted, multi_y_horizontal, binding, seeds.fixed[1])

	local catalog_manifest = runtime_fixture.catalog_manifest
	if catalog_manifest.population.new_p9g_source ~= 12 or
		catalog_manifest.population.reuse_r6_source ~= 8 or
		catalog_manifest.population.r6_cultural_slot ~= 6 or
		catalog_manifest.sha256 ~= built.manifest.values.gathering_sha256 then
		fail("gathering manifest binding differs")
	end
	for _, name in ipairs({"at", "id_at", "biome_at", "race_region_at",
		"faction_at", "territory_rule_at", "pvp_rule_at", "surface_mob_level_at",
		"mob_level_at", "guard_level_at", "terrain_height_at", "water_class_at",
		"housing_eligible_at"}) do
		if type(built.zones_session[name]) ~= "function" then
			fail("zones/query adapter lacks " .. name)
		end
	end
	if type(built.session.plan_slice) ~= "function" or
			type(built.writer.apply) ~= "function" then
		fail("single transaction API differs")
	end
	local ok = pcall(fixture, repo, "not-a-decimal-seed")
	if ok then fail("runtime initialization did not fail closed") end

	local cases = {}
	for _, name in ipairs(contract.integration_cases()) do cases[name] = true end
	local receipt = {
		schema = "grug_wp40_r7_integration_kat_receipt_v1",
		r7_manifest_sha256 = built.manifest.sha256,
		production_r6_content_sha256 = built.manifest.values.production_r6_content_sha256,
		p9g_content_sha256 = built.manifest.values.p9g_content_sha256,
		catalog_sha256 = catalog_manifest.sha256,
		proof_scope = full_vm.proof_scope,
		private_tuple_count = full_vm.private_tuple_count,
		successor_tuple_sha256 = full_vm.successor_tuple_sha256,
		direct_tuple_sha256 = full_vm.direct_tuple_sha256,
		accepted_tuple_sha256 = full_vm.accepted_tuple_sha256,
		successor_run_count = full_vm.successor_run_count,
		direct_run_count = full_vm.direct_run_count,
		accepted_run_count = full_vm.accepted_run_count,
		successor_run_sha256 = full_vm.successor_run_sha256,
		direct_run_sha256 = full_vm.direct_run_sha256,
		accepted_run_sha256 = full_vm.accepted_run_sha256,
		successor_run_checksum_a = full_vm.successor_run_checksum_a,
		successor_run_checksum_b = full_vm.successor_run_checksum_b,
		direct_run_checksum_a = full_vm.direct_run_checksum_a,
		direct_run_checksum_b = full_vm.direct_run_checksum_b,
		accepted_run_checksum_a = full_vm.accepted_run_checksum_a,
		accepted_run_checksum_b = full_vm.accepted_run_checksum_b,
		stage_a_tuple_sha256 = full_vm.stage_a_tuple_sha256,
		stage_a_run_sha256 = full_vm.stage_a_run_sha256,
		stage_b_tuple_sha256 = full_vm.stage_b_tuple_sha256,
		stage_b_run_sha256 = full_vm.stage_b_run_sha256,
		multi_y_owner_x = full_vm.multi_y_owner_x,
		multi_y_owner_z = full_vm.multi_y_owner_z,
		multi_y_band_count = full_vm.multi_y_band_count,
		multi_y_bands = full_vm.multi_y_bands,
		multi_y_active_band_count = full_vm.multi_y_active_band_count,
		multi_y_active_bands = full_vm.multi_y_active_bands,
		multi_y_operation_count = full_vm.multi_y_operation_count,
		multi_y_eligible = full_vm.multi_y_eligible,
		multi_y_planned = full_vm.multi_y_planned,
		multi_y_accepted = full_vm.multi_y_accepted,
		cases = cases,
	}
	contract.validate_integration_receipt(receipt)
	if binding.sha256 ~= ACCEPTED_R6_ARTIFACT_SHA256 or
		sha256(repo, stage_a.direct_buffers) ~= sha256(repo, stage_a.restored_buffers) or
		sha256(repo, stage_b.bytes) ~= sha256(repo, stage_b.accepted_bytes) then
		fail("integration proof digest parity differs")
	end
	return receipt
end

local function add(map, key, value)
	map[key] = (map[key] or 0) + value
end

local function new_horizontal_aggregate(offline)
	local result = {coverage = {}, cultural_candidates = {}, cultural_slots = {},
		decoration_candidates = {}, decoration_settlement = {}, rejections = {}}
	for index = 1, #offline.fixtures.cultural do
		local key = offline.fixtures.cultural[index].key
		for _, rate in ipairs({"concentrated", "ordinary"}) do
			result.cultural_candidates[key .. "\0" .. rate] =
				{eligible = 0, budget = 0, candidates = 0}
			result.cultural_slots[key .. "\0" .. rate] =
				{accepted = 0, reserved = 0}
		end
	end
	for index = 1, #offline.fixtures.decorations do
		local id = offline.fixtures.decorations[index].id
		result.decoration_candidates[id] =
			{eligible = 0, budget = 0, candidates = 0}
		result.decoration_settlement[id] =
			{accepted = 0, emitted = 0, reserved = 0}
	end
	return result
end

local function merge_horizontal(aggregate, offline, scan)
	for index = 1, #scan.coverage do
		local row = scan.coverage[index]
		add(aggregate.coverage, row.zone_id .. "\0" .. row.biome, row.count)
	end
	for index = 1, #scan.groups do
		local group = scan.groups[index]
		if group.kind == 1 then
			local definition = offline.fixtures.cultural[group.catalog]
			if not definition then fail("unknown Cultural planner catalog") end
			local rate = group.parameter == 1024 and "concentrated" or
				(group.parameter == 4096 and "ordinary" or nil)
			if not rate then fail("Cultural planner denominator differs") end
			local target = aggregate.cultural_candidates[
				definition.key .. "\0" .. rate]
			target.eligible = target.eligible + group.eligible
			target.budget = target.budget + group.budget
			target.candidates = target.candidates + group.candidates
		elseif group.kind == 2 then
			local definition = offline.fixtures.decorations[group.catalog]
			if not definition then fail("unknown decoration planner catalog") end
			local target = aggregate.decoration_candidates[definition.id]
			target.eligible = target.eligible + group.eligible
			target.budget = target.budget + group.budget
			target.candidates = target.candidates + group.candidates
		else
			fail("planner group kind differs")
		end
	end
	for key, row in pairs(scan.settlement.cultural) do
		local target = aggregate.cultural_slots[key]
		if not target then fail("unknown Cultural settlement key") end
		target.accepted = target.accepted + row.accepted
		target.reserved = target.reserved + row.reserved
	end
	for id, row in pairs(scan.settlement.decorations) do
		local target = aggregate.decoration_settlement[id]
		if not target then fail("unknown decoration settlement key") end
		target.accepted = target.accepted + row.accepted
		target.emitted = target.emitted + row.emitted
		target.reserved = target.reserved + row.reserved
	end
	for key, count in pairs(scan.settlement.rejections) do
		add(aggregate.rejections, key, count)
	end
end

local function split_nul(value)
	local fields, first = {}, 1
	while true do
		local delimiter = value:find("\0", first, true)
		if not delimiter then
			fields[#fields + 1] = value:sub(first)
			return fields
		end
		fields[#fields + 1] = value:sub(first, delimiter - 1)
		first = delimiter + 1
	end
end

local function aggregate_projection(binding, offline, seed_slot, aggregate)
	local codec, records = binding.codec, {}
	local function emit(row_type, keys, values)
		local bytes = codec.encode_data_row(row_type, keys, values)
		records[#records + 1] = {bytes = bytes,
			fields = codec.parse_data_line(bytes:sub(1, -2),
				"normalized R6 projection row")}
	end
	local allowed = {}
	for zone_index = 1, #offline.source.zones do
		local zone = offline.source.zones[zone_index]
		for biome_index = 1, #zone.biomes do
			allowed[zone.id .. "\0" .. zone.biomes[biome_index].id] = true
		end
	end
	for key in pairs(allowed) do
		local fields, count = split_nul(key), aggregate.coverage[key]
		emit("surface_coverage", {seed_slot, fields[1], fields[2],
			count and "occurring" or "catalog_zero"}, {count or 0})
	end
	for index = 1, #offline.fixtures.cultural do
		local id = offline.fixtures.cultural[index].key
		for _, rate in ipairs({"concentrated", "ordinary"}) do
			local key = id .. "\0" .. rate
			local candidate, settled = aggregate.cultural_candidates[key],
				aggregate.cultural_slots[key]
			emit("cultural_candidate", {seed_slot, id, rate},
				{candidate.eligible, candidate.budget, candidate.candidates})
			emit("cultural_slot", {seed_slot, id, rate},
				{settled.accepted, settled.reserved})
		end
	end
	for index = 1, #offline.fixtures.decorations do
		local definition = offline.fixtures.decorations[index]
		local candidate = aggregate.decoration_candidates[definition.id]
		local settled = aggregate.decoration_settlement[definition.id]
		emit("decoration_candidate", {seed_slot, definition.id,
			definition.settlement_class},
			{candidate.eligible, candidate.budget, candidate.candidates})
		emit("decoration_settlement", {seed_slot, definition.id,
			definition.settlement_class},
			{settled.accepted, settled.emitted, settled.reserved})
	end
	local cultural_reasons = {"clipped_owner", "fixed_or_protected",
		"route_or_water", "content_ignore", "wrong_support", "cultural_collision"}
	for index = 1, #offline.fixtures.cultural do
		local id = offline.fixtures.cultural[index].key
		for reason_index = 1, #cultural_reasons do
			local reason = cultural_reasons[reason_index]
			emit("rejection", {seed_slot, "cultural", id, reason},
				{aggregate.rejections["cultural\0" .. id .. "\0" .. reason] or 0})
		end
	end
	local decoration_reasons = {"clipped_owner", "content_ignore",
		"fixed_or_protected", "route_or_water", "wrong_host",
		"insufficient_clearance", "cultural_collision", "resource_collision",
		"decoration_collision", "forbidden_old_class"}
	for index = 1, #offline.fixtures.decorations do
		local id = offline.fixtures.decorations[index].id
		for reason_index = 1, #decoration_reasons do
			local reason = decoration_reasons[reason_index]
			emit("rejection", {seed_slot, "decoration", id, reason},
				{aggregate.rejections["decoration\0" .. id .. "\0" .. reason] or 0})
		end
	end
	table.sort(records, function(left, right) return codec.compare(left.fields, right.fields) end)
	if #records ~= #binding.projection_records then
		fail("normalized/accepted R6 aggregate population differs")
	end
	local normalized, accepted = {}, {}
	for index = 1, #records do
		normalized[index] = records[index].bytes
		accepted[index] = binding.projection_records[index].bytes
		if normalized[index] ~= accepted[index] then
			fail("normalized Direct-83 aggregate differs from accepted R6 at row " ..
				tostring(index))
		end
	end
	return table.concat(normalized), table.concat(accepted)
end

local function new_p9g_aggregate(reasons)
	local result = {populations = {}, rejections = {}}
	for index = 1, #reasons do result.rejections[reasons[index]] = 0 end
	return result
end

local function merge_p9g(aggregate, reasons, ledger)
	for index = 1, #ledger.populations do
		local row = ledger.populations[index]
		local key = table.concat({row.source_id, row.zone_id, row.biome,
			row.faction, row.bracket}, "\0")
		local target = aggregate.populations[key]
		if not target then
			target = {source_id = row.source_id, zone_id = row.zone_id,
				biome = row.biome, faction = row.faction, bracket = row.bracket,
				eligible = 0, budget = 0, accepted = 0, rejections = {}}
			for reason = 1, #reasons do target.rejections[reasons[reason]] = 0 end
			aggregate.populations[key] = target
		end
		target.eligible = target.eligible + row.eligible
		target.budget = target.budget + row.budget
		target.accepted = target.accepted + row.accepted
		for reason = 1, #reasons do
			local name = reasons[reason]
			target.rejections[name] = target.rejections[name] + row.rejections[name]
		end
	end
	for index = 1, #reasons do
		local name = reasons[index]
		aggregate.rejections[name] = aggregate.rejections[name] +
			ledger.rejections[name]
	end
end

local function merge_frontier_access(aggregate, reasons, ledger)
	for index = 1, #ledger.populations do
		local row = ledger.populations[index]
		if FRONTIER_ACCESS_SOURCE_SET[row.source_id] then
			if not FRONTIER_ACCESS_ZONE_SET[row.zone_id] then
				fail("frontier access population escaped the closed zone set")
			end
			local key = table.concat({row.source_id, row.zone_id, row.biome,
				row.faction, row.bracket}, "\0")
			local target = aggregate.populations[key]
			if not target then
				target = {source_id = row.source_id, zone_id = row.zone_id,
					biome = row.biome, faction = row.faction, bracket = row.bracket,
					eligible = 0, budget = 0, accepted = 0, rejections = {}}
				for reason = 1, #reasons do target.rejections[reasons[reason]] = 0 end
				aggregate.populations[key] = target
			end
			target.eligible = target.eligible + row.eligible
			target.budget = target.budget + row.budget
			target.accepted = target.accepted + row.accepted
			for reason = 1, #reasons do
				local name = reasons[reason]
				target.rejections[name] = target.rejections[name] + row.rejections[name]
			end
		end
	end
end

local function p9g_aggregate_bytes(aggregate, reasons, row_type)
	row_type = row_type or "population"
	if row_type ~= "population" and row_type ~= "frontier_access_population" then
		fail("P9G population row type differs")
	end
	local rows = {}
	local population_keys = {}
	for key in pairs(aggregate.populations) do population_keys[#population_keys + 1] = key end
	table.sort(population_keys, less_bytes)
	for index = 1, #population_keys do
		local row = aggregate.populations[population_keys[index]]
		local values = {row.source_id, row.zone_id, row.biome, row.faction,
			row.bracket, row.eligible, row.budget, row.accepted}
		for reason = 1, #reasons do
			values[#values + 1] = row.rejections[reasons[reason]]
		end
		for field = 6, #values do values[field] = tostring(values[field]) end
		rows[#rows + 1] = row_type .. "\t" .. table.concat(values, "\t") .. "\n"
	end
	return table.concat(rows)
end

local function prefix_lines(prefix, bytes)
	local rows = {}
	for line in bytes:gmatch("([^\n]+)\n") do
		rows[#rows + 1] = prefix .. line .. "\n"
	end
	return table.concat(rows)
end

local function unopened_output(path)
	text(path, "seed output path")
	local probe = io.open(path, "rb")
	if probe then probe:close(); fail("seed output already exists") end
	return assert(io.open(path, "wb"), "cannot create seed output")
end

-- The pragmatic seed encoder writes both ledgers incrementally. Every main-
-- sample owner executes all three production-owned projections. The separate,
-- preselected Frontier lane executes only authentic successor settlement and
-- never contributes to Stage A/B, density or parity.
function module.run_seed(repo, seed_slot, output_path)
	integer(seed_slot, 1, 32, "seed slot")
	local frontier_access_enabled = FRONTIER_ACCESS_SEED_SET[seed_slot] == true
	local output = unopened_output(output_path)
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local seeds = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	local seed = seeds.fixed[seed_slot]
	local runtime_fixture = fixture(repo, seed, "horizontal")
	local binding = artifact_content_binding(repo, runtime_fixture, nil)
	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	local accepted_loaded = offline.new_evidence(seed, true)
	local aggregate = new_horizontal_aggregate(offline)
	local roster = sample_roster(repo, seed_slot)
	local access_roster = frontier_access_roster(repo)
	local access_owner_set = {}
	if frontier_access_enabled then
		for index = 1, #access_roster.rows do
			local row = access_roster.rows[index]
			access_owner_set[sample_owner_key(row.owner_x, row.owner_z)] = true
		end
	end
	local stream = sha_stream(repo)
	local output_hasher, output_bytes = stream.new(), 0
	local function write(bytes)
		if type(bytes) ~= "string" or bytes == "" then fail("empty seed output write") end
		assert(output:write(bytes))
		output_hasher.update(bytes)
		output_bytes = output_bytes + #bytes
	end
	write("schema\tgrug_wp40_r7_seed_evidence_v3\n")
	write("seed_slot\t" .. tostring(seed_slot) .. "\n")
	write("seed_identity\t" .. seed .. "\n")
	write("sample_schema\t" .. roster.schema .. "\n")
	write("sample_roster_sha256\t" .. roster.sha256 .. "\n")
	write("sample_owner_count\t" .. tostring(#roster.rows) .. "\n")
	write("sample_column_count\t" .. tostring(roster.columns) .. "\n")
	for index = 1, #roster.rows do write(sample_owner_bytes(roster.rows[index], index)) end
	write("frontier_access_schema\t" .. access_roster.schema .. "\n")
	write("frontier_access_roster_sha256\t" .. access_roster.sha256 .. "\n")
	write("frontier_access_enabled\t" .. tostring(frontier_access_enabled) .. "\n")
	write("frontier_access_owner_count\t" ..
		tostring(frontier_access_enabled and #access_roster.rows or 0) .. "\n")
	write("frontier_access_column_count\t" ..
		tostring(frontier_access_enabled and access_roster.columns or 0) .. "\n")
	if frontier_access_enabled then
		for index = 1, #access_roster.rows do
			write(frontier_access_owner_bytes(access_roster.rows[index], index))
		end
	end
	local restored_buffers, direct_buffers = stream.new(), stream.new()
	local restored_runs, direct_runs = stream.new(), stream.new()
	local candidate, accepted_candidate = stream.new(), stream.new()
	local reasons = contract.rejection_reasons()
	if graph(reasons) ~= graph(P9G_REASONS) then
		fail("runtime/contract P9G rejection order differs")
	end
	local p9g_aggregate = new_p9g_aggregate(reasons)
	local operation_count, accepted_count, rejected_count = 0, 0, 0
	local substitutions = 0
	local successor_cache = {}
	for owner_index = 1, #roster.rows do
		local owner_x, owner_z = roster.rows[owner_index].owner_x,
			roster.rows[owner_index].owner_z
			local successor = validate_scan(runtime_fixture.built.evidence.scan_owner(
				owner_x, owner_z), owner_x, owner_z, true)
			local owner_key = sample_owner_key(owner_x, owner_z)
			if access_owner_set[owner_key] then successor_cache[owner_key] = successor end
			local direct = validate_scan(runtime_fixture.built.evidence.scan_direct_owner(
				owner_x, owner_z), owner_x, owner_z, false)
			local a = stage_a_owner(repo, runtime_fixture, successor, direct)
			restored_buffers.update(a.restored_buffers)
			direct_buffers.update(a.direct_buffers)
			restored_runs.update(a.restored_runs)
			direct_runs.update(a.direct_runs)
			operation_count = operation_count + a.operation_count
			accepted_count = accepted_count + a.accepted
			rejected_count = rejected_count + a.rejected
			if a.operation_bytes ~= "" then write(a.operation_bytes) end
			merge_p9g(p9g_aggregate, reasons, a.ledger)
			local accepted = scan_accepted_loaded(accepted_loaded, owner_x, owner_z)
			local b = stage_b_owner(repo, runtime_fixture, binding, direct, accepted)
			substitutions = substitutions + b.substitutions
			candidate.update(b.bytes)
			accepted_candidate.update(b.accepted_bytes)
			merge_horizontal(aggregate, offline, direct)
	end
	local stage_a = {
		schema = "grug_wp40_r7_stage_a_receipt_v1", seed_slot = seed_slot,
		seed_identity = seed,
		production_r6_content_sha256 =
			runtime_fixture.built.manifest.values.production_r6_content_sha256,
		p9g_content_sha256 = runtime_fixture.built.manifest.values.p9g_content_sha256,
		p9g_delta_sha256 = runtime_fixture.built.manifest.values.p9g_delta_sha256,
		operation_count = operation_count, accepted_count = accepted_count,
		rejected_count = rejected_count,
		restored_buffers_sha256 = restored_buffers.final_hex(),
		direct_buffers_sha256 = direct_buffers.final_hex(),
		restored_runs_sha256 = restored_runs.final_hex(),
		direct_runs_sha256 = direct_runs.final_hex(), equal = true,
	}
	contract.validate_stage_a(stage_a)
	local candidate_sha, accepted_candidate_sha = candidate.final_hex(),
		accepted_candidate.final_hex()
	local stage_b = {
		schema = "grug_wp40_r7_stage_b_receipt_v1", seed_slot = seed_slot,
		seed_identity = seed,
		production_r6_content_sha256 =
			runtime_fixture.built.manifest.values.production_r6_content_sha256,
		accepted_r6_projection_sha256 = accepted_candidate_sha,
		name_map_population = 83, cultural_name_map_population = 6,
		cultural_substitution_count = substitutions,
		inherited_cultural_access_count = binding.inherited_cultural_access_count,
		normalized_artifact_sha256 = candidate_sha,
		candidate_decisions_sha256 = candidate_sha,
		accepted_candidate_decisions_sha256 = accepted_candidate_sha, equal = true,
	}
	contract.validate_stage_b(stage_b)
	write(p9g_aggregate_bytes(p9g_aggregate, reasons))
	local coverage_keys = {}
	for key in pairs(aggregate.coverage) do coverage_keys[#coverage_keys + 1] = key end
	table.sort(coverage_keys, less_bytes)
	for index = 1, #coverage_keys do
		local fields = split_nul(coverage_keys[index])
		write(table.concat({"sample_coverage", fields[1], fields[2],
			tostring(aggregate.coverage[coverage_keys[index]])}, "\t") .. "\n")
	end
	local frontier_aggregate = new_p9g_aggregate(reasons)
	local frontier_operations, frontier_accepted, frontier_rejected = 0, 0, 0
	if frontier_access_enabled then
		for owner_index = 1, #access_roster.rows do
			local row = access_roster.rows[owner_index]
			local key = sample_owner_key(row.owner_x, row.owner_z)
			local successor = successor_cache[key]
			if not successor then
				successor = validate_scan(runtime_fixture.built.evidence.scan_owner(
					row.owner_x, row.owner_z), row.owner_x, row.owner_z, true)
			end
			local ledger = validate_ledger(successor.settlement.p9g)
			for operation_index = 1, #ledger.operations do
				local operation = ledger.operations[operation_index]
				if FRONTIER_ACCESS_SOURCE_SET[operation.source_id] then
					if not FRONTIER_ACCESS_ZONE_SET[operation.zone_id] then
						fail("frontier access operation escaped the closed zone set")
					end
					write(operation_bytes(operation, "frontier_access_operation"))
					frontier_operations = frontier_operations + 1
					if operation.accepted then frontier_accepted = frontier_accepted + 1
					else frontier_rejected = frontier_rejected + 1 end
				end
			end
			merge_frontier_access(frontier_aggregate, reasons, ledger)
		end
		write(p9g_aggregate_bytes(frontier_aggregate, reasons,
			"frontier_access_population"))
	end
	local stage_a_bytes, stage_b_bytes = contract.stage_a_bytes(stage_a),
		contract.stage_b_bytes(stage_b)
	assert(output:close())
	return {schema = "grug_wp40_r7_seed_result_v2", seed_slot = seed_slot,
		seed_identity = seed, manifest_sha256 = runtime_fixture.built.manifest.sha256,
		accepted_r6_artifact_sha256 = binding.sha256, stage_a = stage_a,
		stage_b = stage_b, path = output_path, sha256 = output_hasher.final_hex(),
		bytes = output_bytes, stage_a_sha256 = sha256(repo, stage_a_bytes),
		stage_b_sha256 = sha256(repo, stage_b_bytes),
		sample_roster_sha256 = roster.sha256, sample_owner_count = #roster.rows,
		sample_column_count = roster.columns,
		frontier_access_roster_sha256 = access_roster.sha256,
		frontier_access_enabled = frontier_access_enabled,
		frontier_access_owner_count = frontier_access_enabled and #access_roster.rows or 0,
		frontier_access_column_count = frontier_access_enabled and access_roster.columns or 0,
		frontier_access_operation_count = frontier_operations,
		frontier_access_accepted_count = frontier_accepted,
		frontier_access_rejected_count = frontier_rejected}
end

function module.pilot(repo, scratch, seed_slot)
	text(scratch, "pilot scratch")
	local result = module.run_seed(repo, seed_slot,
		scratch .. "-seed-" .. string.format("%02d", seed_slot) .. ".tsv")
	return {
		schema = "grug_wp40_r7_pilot_result_v3", seed_slot = seed_slot,
		seed_identity = result.seed_identity,
		canonical_output_sha256 = result.sha256,
		canonical_output_bytes = result.bytes,
		stage_a_sha256 = result.stage_a_sha256,
		stage_b_sha256 = result.stage_b_sha256,
		p9g_delta_sha256 = result.stage_a.p9g_delta_sha256,
		frontier_access_roster_sha256 = result.frontier_access_roster_sha256,
		frontier_access_enabled = result.frontier_access_enabled,
		frontier_access_owner_count = result.frontier_access_owner_count,
		frontier_access_column_count = result.frontier_access_column_count,
	}
end

function module.worker(repo, scratch, first_slot, last_slot, projection_sha256)
	text(scratch, "worker scratch")
	integer(first_slot, 1, 32, "worker first slot")
	integer(last_slot, first_slot, 32, "worker last slot")
	digest(projection_sha256, "approved projection digest")
	local rows = {"schema\tgrug_wp40_r7_worker_receipt_v3\n",
		"projection_sha256\t" .. projection_sha256 .. "\n",
		"first_slot\t" .. tostring(first_slot) .. "\n",
		"last_slot\t" .. tostring(last_slot) .. "\n"}
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	for slot = first_slot, last_slot do
		local path = scratch .. "/seed-" .. string.format("%02d", slot) .. ".tsv"
		local result = module.run_seed(repo, slot, path)
		rows[#rows + 1] = table.concat({"seed", slot, result.seed_identity,
			result.path, result.sha256, result.bytes, result.manifest_sha256,
			result.accepted_r6_artifact_sha256, result.stage_a_sha256,
			result.stage_b_sha256, result.stage_a.p9g_delta_sha256,
			result.sample_roster_sha256, result.sample_owner_count,
			result.sample_column_count, result.frontier_access_roster_sha256,
			tostring(result.frontier_access_enabled), result.frontier_access_owner_count,
			result.frontier_access_column_count,
			result.frontier_access_operation_count,
			result.frontier_access_accepted_count,
			result.frontier_access_rejected_count}, "\t") .. "\n"
		rows[#rows + 1] = "stage_a\t" .. tostring(slot) .. "\t" ..
			hex(contract.stage_a_bytes(result.stage_a)) .. "\n"
		rows[#rows + 1] = "stage_b\t" .. tostring(slot) .. "\t" ..
			hex(contract.stage_b_bytes(result.stage_b)) .. "\n"
	end
	return table.concat(rows)
end

local function split_tabs(line)
	local fields = {}
	for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
	return fields
end

local function unhex(value)
	if type(value) ~= "string" or #value % 2 ~= 0 or
			not value:match("^[0-9a-f]+$") then fail("hex payload differs") end
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end

local function parse_receipt_bytes(bytes, stage)
	local result = {}
	for line in bytes:gmatch("([^\n]+)\n") do
		local fields = split_tabs(line)
		if #fields ~= 2 or result[fields[1]] ~= nil then
			fail(stage .. " receipt bytes differ")
		end
		local value = fields[2]
		if fields[1] == "seed_slot" or fields[1]:find("_count$") or
				fields[1]:find("_population$") then
			value = tonumber(value)
		elseif fields[1] == "equal" then value = value == "true" end
		result[fields[1]] = value
	end
	return result
end

local function read_file(path)
	local file = assert(io.open(path, "rb"), "cannot open " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local function worker_descriptors(repo, path, contract, stream)
	local bytes = read_file(path)
	local lines, first = {}, true
	local projection, first_slot, last_slot
	local seeds, stage_a, stage_b = {}, {}, {}
	for line in bytes:gmatch("([^\n]+)\n") do
		local fields = split_tabs(line)
		if first then
			if line ~= "schema\tgrug_wp40_r7_worker_receipt_v3" then
				fail("worker receipt schema differs")
			end
			first = false
		elseif fields[1] == "projection_sha256" and #fields == 2 and not projection then
			projection = digest(fields[2], "worker projection digest")
		elseif fields[1] == "first_slot" and #fields == 2 and not first_slot then
			first_slot = tonumber(fields[2])
		elseif fields[1] == "last_slot" and #fields == 2 and not last_slot then
			last_slot = tonumber(fields[2])
		elseif fields[1] == "seed" and #fields == 21 then
			local slot = tonumber(fields[2])
			if not slot or seeds[slot] then fail("worker seed descriptor differs") end
			seeds[slot] = {slot = slot, identity = fields[3], path = fields[4],
				sha256 = fields[5], bytes = tonumber(fields[6]), manifest_sha256 = fields[7],
				accepted_r6_artifact_sha256 = fields[8], stage_a_sha256 = fields[9],
				stage_b_sha256 = fields[10], p9g_delta_sha256 = fields[11],
				sample_roster_sha256 = fields[12], sample_owner_count = tonumber(fields[13]),
				sample_column_count = tonumber(fields[14]),
				frontier_access_roster_sha256 = fields[15],
				frontier_access_enabled = fields[16] == "true",
				frontier_access_enabled_text = fields[16],
				frontier_access_owner_count = tonumber(fields[17]),
				frontier_access_column_count = tonumber(fields[18]),
				frontier_access_operation_count = tonumber(fields[19]),
				frontier_access_accepted_count = tonumber(fields[20]),
				frontier_access_rejected_count = tonumber(fields[21])}
		elseif fields[1] == "stage_a" and #fields == 3 then
			local slot = assert(tonumber(fields[2]))
			if stage_a[slot] then fail("duplicate worker Stage-A row") end
			stage_a[slot] = unhex(fields[3])
		elseif fields[1] == "stage_b" and #fields == 3 then
			local slot = assert(tonumber(fields[2]))
			if stage_b[slot] then fail("duplicate worker Stage-B row") end
			stage_b[slot] = unhex(fields[3])
		else fail("worker receipt row differs") end
	end
	if first or not projection then fail("worker receipt is incomplete") end
	integer(first_slot, 1, 32, "worker first slot")
	integer(last_slot, first_slot, 32, "worker last slot")
	local expected_count, seed_count, stage_a_count, stage_b_count =
		last_slot - first_slot + 1, 0, 0, 0
	for slot in pairs(seeds) do
		if slot < first_slot or slot > last_slot then fail("worker seed escaped assignment") end
		seed_count = seed_count + 1
	end
	for slot in pairs(stage_a) do
		if slot < first_slot or slot > last_slot then fail("worker Stage-A escaped assignment") end
		stage_a_count = stage_a_count + 1
	end
	for slot in pairs(stage_b) do
		if slot < first_slot or slot > last_slot then fail("worker Stage-B escaped assignment") end
		stage_b_count = stage_b_count + 1
	end
	if seed_count ~= expected_count or stage_a_count ~= expected_count or
			stage_b_count ~= expected_count then
		fail("worker evidence population differs")
	end
	for slot = first_slot, last_slot do
		local row = seeds[slot]
		if not row or not stage_a[slot] or not stage_b[slot] then
			fail("worker seed evidence is incomplete")
		end
		digest(row.sha256, "seed file digest")
		integer(row.bytes, 1, MAX_SAFE, "seed file bytes")
		for _, field in ipairs({"manifest_sha256", "accepted_r6_artifact_sha256",
				"stage_a_sha256", "stage_b_sha256", "p9g_delta_sha256",
				"sample_roster_sha256", "frontier_access_roster_sha256"}) do
			digest(row[field], "seed descriptor " .. field)
		end
		integer(row.sample_owner_count, SAMPLE_OWNER_COUNT, SAMPLE_OWNER_COUNT,
			"seed sample owner count")
		integer(row.sample_column_count, 1, 49980561, "seed sample column count")
		local expected_roster = sample_roster(repo, slot)
		if row.sample_roster_sha256 ~= expected_roster.sha256 or
				row.sample_column_count ~= expected_roster.columns then
			fail("worker seed sample roster binding differs")
		end
		local expected_access = frontier_access_roster(repo)
		local expected_access_enabled = FRONTIER_ACCESS_SEED_SET[slot] == true
		if (row.frontier_access_enabled_text ~= "true" and
				row.frontier_access_enabled_text ~= "false") or
				row.frontier_access_enabled ~= expected_access_enabled then
			fail("worker seed frontier access selection differs")
		end
		local expected_access_owners = expected_access_enabled and
			FRONTIER_ACCESS_OWNER_COUNT or 0
		local expected_access_columns = expected_access_enabled and
			FRONTIER_ACCESS_COLUMN_COUNT or 0
		integer(row.frontier_access_owner_count, expected_access_owners,
			expected_access_owners, "seed frontier access owner count")
		integer(row.frontier_access_column_count, expected_access_columns,
			expected_access_columns, "seed frontier access column count")
		for _, field in ipairs({"frontier_access_operation_count",
				"frontier_access_accepted_count", "frontier_access_rejected_count"}) do
			integer(row[field], 0, MAX_SAFE, "seed " .. field)
		end
		if row.frontier_access_roster_sha256 ~= expected_access.sha256 then
			fail("worker seed frontier access roster binding differs")
		end
		if not expected_access_enabled and
				(row.frontier_access_operation_count ~= 0 or
				row.frontier_access_accepted_count ~= 0 or
				row.frontier_access_rejected_count ~= 0) then
			fail("worker main-only seed emitted frontier access evidence")
		end
		if row.frontier_access_operation_count ~=
				row.frontier_access_accepted_count + row.frontier_access_rejected_count then
			fail("worker seed frontier access operation partition differs")
		end
		local actual_sha, actual_bytes = stream.file(row.path)
		if actual_sha ~= row.sha256 or actual_bytes ~= row.bytes or
				sha256(repo, stage_a[slot]) ~= row.stage_a_sha256 or
				sha256(repo, stage_b[slot]) ~= row.stage_b_sha256 then
			fail("worker seed descriptor binding differs")
		end
		local a, b = parse_receipt_bytes(stage_a[slot], "Stage-A"),
			parse_receipt_bytes(stage_b[slot], "Stage-B")
		contract.validate_stage_a(a); contract.validate_stage_b(b)
		if a.seed_slot ~= slot or b.seed_slot ~= slot or
				a.seed_identity ~= row.identity or b.seed_identity ~= row.identity or
				a.p9g_delta_sha256 ~= row.p9g_delta_sha256 then
			fail("worker seed receipt identity differs")
		end
		row.stage_a, row.stage_b = stage_a[slot], stage_b[slot]
		row.stage_a_receipt, row.stage_b_receipt = a, b
	end
	return projection, first_slot, last_slot, seeds
end

local function new_final_output(path, stream)
	text(path, "finalizer output path")
	local probe = io.open(path, "rb")
	if probe then probe:close(); fail("finalizer output already exists") end
	local file = assert(io.open(path, "wb"), "cannot create finalizer output")
	local hasher, byte_count, closed = stream.new(), 0, false
	local output = {}
	function output.write(bytes)
		if closed or type(bytes) ~= "string" or bytes == "" then
			fail("finalizer output write differs")
		end
		assert(file:write(bytes))
		hasher.update(bytes)
		byte_count = byte_count + #bytes
	end
	function output.close()
		if closed then fail("finalizer output closed twice") end
		assert(file:close())
		closed = true
		return {path = path, sha256 = hasher.final_hex(), bytes = byte_count}
	end
	return output
end

local function parsed_integer(value, minimum, maximum, label)
	local number = tonumber(value)
	if not number or tostring(number) == "nan" then fail(label .. " is not numeric") end
	return integer(number, minimum, maximum, label)
end

function module.finalizer_authority_kat(repo)
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local source = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	local zones, faction = {}, {dwarf = "accord", human = "accord", elf = "accord",
		undead = "throng", orc = "throng", troll = "throng"}
	for index = 1, #source.zones do zones[source.zones[index].id] = source.zones[index] end
	local contested = {accord = 0, throng = 0}
	for _, row in ipairs(catalog.p9g_sources()) do
		for index = 1, #row.zones do
			local zone = zones[row.zones[index]]
			if not zone or not faction[zone.race_region] then
				fail("finalizer authority KAT source zone differs")
			end
			local minimum = math.floor((zone.difficulty_target - 1) / 10) * 10 + 1
			if not P9G_BRACKETS[tostring(minimum) .. "-" .. tostring(minimum + 9)] then
				fail("finalizer authority KAT bracket differs")
			end
			if zone.faction == false then
				contested[faction[zone.race_region]] = contested[faction[zone.race_region]] + 1
			elseif zone.faction ~= faction[zone.race_region] then
				fail("finalizer authority KAT home faction differs")
			end
		end
		for index = 1, #row.hosts do
			if type(row.hosts[index].biome) ~= "string" or
					type(row.hosts[index].support) ~= "string" then
				fail("finalizer authority KAT host differs")
			end
		end
	end
	if contested.accord == 0 or contested.throng == 0 then
		fail("finalizer authority KAT lacks both contested factions")
	end
	return true
end

function module.finalize(repo, scratch, worker_paths)
	text(scratch, "finalizer scratch")
	dense(worker_paths, "worker paths")
	if #worker_paths ~= 7 then fail("finalizer worker population differs") end
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local stream = sha_stream(repo)
	local all, projection, ranges = {}, nil, {}
	local allowed_ranges = {['1/5'] = true, ['6/10'] = true, ['11/15'] = true,
		['16/20'] = true, ['21/24'] = true, ['25/28'] = true, ['29/32'] = true}
	for index = 1, 7 do
		local worker_projection, first_slot, last_slot, seeds =
			worker_descriptors(repo, worker_paths[index], contract, stream)
		local range = tostring(first_slot) .. "/" .. tostring(last_slot)
		if not allowed_ranges[range] or ranges[range] or
				(projection and projection ~= worker_projection) then
			fail("worker assignment/projection differs")
		end
		ranges[range], projection = true, worker_projection
		for slot = first_slot, last_slot do
			if all[slot] then fail("duplicate finalizer seed slot") end
			all[slot] = seeds[slot]
		end
	end

	local seeds = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local map_source = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	local content_fixture = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(
		repo, seeds.fixed[1], true)
	local source_rows, source_by_id, source_index = catalog.p9g_sources(), {}, {}
	if #source_rows ~= 12 then fail("finalizer P9G source population differs") end
	for index = 1, #source_rows do
		local row = source_rows[index]
		if source_by_id[row.id] then fail("finalizer duplicate P9G source") end
		source_by_id[row.id], source_index[row.id] = row, index
	end
	local zone_by_id, faction_by_race = {}, {dwarf = "accord", human = "accord",
		elf = "accord", undead = "throng", orc = "throng", troll = "throng"}
	for index = 1, #map_source.zones do
		local zone = map_source.zones[index]
		local regional_faction = faction_by_race[zone.race_region]
		if zone_by_id[zone.id] or not regional_faction or
				(zone.faction ~= false and zone.faction ~= regional_faction) then
			fail("finalizer R4 zone/faction authority differs")
		end
		zone_by_id[zone.id] = zone
	end
	local function source_semantics(source_id, zone_id, biome, faction, bracket)
		local source, zone = source_by_id[source_id], zone_by_id[zone_id]
		if not source or not zone then fail("P9G source/zone identity differs") end
		local zone_allowed = false
		for index = 1, #source.zones do
			if source.zones[index] == zone_id then zone_allowed = true break end
		end
		local support
		for index = 1, #source.hosts do
			if source.hosts[index].biome == biome then
				support = source.hosts[index].support break
			end
		end
		-- Production derives the bracket from the smoothed positional
		-- surface_mob_level_at(), not from the zone's authored target.  Keep the
		-- finalizer independent of that calculation: validate the closed bracket
		-- vocabulary here and reconcile every budgeted population against its
		-- exact operation key below.
		if not zone_allowed or not support or
				faction ~= faction_by_race[zone.race_region] or
				not P9G_BRACKETS[bracket] then
			fail("P9G source/zone/biome/faction/bracket semantics differ")
		end
		return source, support
	end
	local reason_set = {}
	for index = 1, #P9G_REASONS do reason_set[P9G_REASONS[index]] = true end
	local source_totals, access, parity, source_final_tuple = {}, {}, {}, {}
	for index = 1, #source_rows do
		local id = source_rows[index].id
		source_totals[id] = {eligible = 0, budget = 0, accepted = 0}
		access[id] = {accord = 0, throng = 0}
		parity[id] = {}
	end
	local frontier_source_totals, frontier_access = {}, {}
	for index = 1, #FRONTIER_ACCESS_SOURCES do
		local id = FRONTIER_ACCESS_SOURCES[index]
		if not source_by_id[id] then fail("frontier access source identity is absent") end
		frontier_source_totals[id] = {eligible = 0, budget = 0, accepted = 0}
		frontier_access[id] = {
			accord = {eligible = 0, budget = 0, accepted = 0},
			throng = {eligible = 0, budget = 0, accepted = 0},
		}
	end
	local expected_access = frontier_access_roster(repo)

	local artifact = new_final_output(scratch .. "/artifact.tsv", stream)
	local stage_a = new_final_output(scratch .. "/stage-a.tsv", stream)
	local stage_b = new_final_output(scratch .. "/stage-b.tsv", stream)
	local p9g = new_final_output(scratch .. "/p9g.tsv", stream)
	local frontier = new_final_output(scratch .. "/frontier-access.tsv", stream)
	artifact.write("schema\tgrug_wp40_r7_artifact_v1\n")
	artifact.write("acceptance_scope\t32_seed_stratified_4096_owner_sample\n")
	artifact.write("projection_sha256\t" .. projection .. "\n")
	artifact.write("accepted_r6_artifact_sha256\t" ..
		ACCEPTED_R6_ARTIFACT_SHA256 .. "\n")
	stage_a.write("schema\tgrug_wp40_r7_stage_a_aggregate_v1\n")
	stage_a.write("acceptance_scope\t32_seed_stratified_4096_owner_sample\n")
	stage_b.write("schema\tgrug_wp40_r7_stage_b_aggregate_v1\n")
	stage_b.write("acceptance_scope\t32_seed_stratified_4096_owner_sample\n")
	p9g.write("schema\tgrug_wp40_r7_p9g_ledger_v1\n")
	p9g.write("acceptance_scope\t32_seed_stratified_4096_owner_sample\n")
	frontier.write("schema\tgrug_wp40_r7_frontier_access_ledger_v2\n")
	frontier.write("acceptance_scope\t7_seed_stratified_static_frontier_successor_only\n")
	frontier.write("seed_population\t7\n")
	frontier.write("seed_slots\t1,6,11,17,22,27,32\n")
	frontier.write("owner_population_per_seed\t458\n")
	frontier.write("case_population\t3206\n")
	frontier.write("column_visit_population\t20518400\n")
	frontier.write("roster_sha256\t" .. expected_access.sha256 .. "\n")

	local production_content_sha, p9g_content_sha, p9g_delta_sha
	local total_operations, total_accepted, total_rejected = 0, 0, 0
	local total_frontier_operations, total_frontier_accepted,
		total_frontier_rejected = 0, 0, 0
	local total_sample_cases, total_sample_columns, total_sample_surface_columns =
		0, 0, 0
	local total_frontier_cases, total_frontier_columns = 0, 0
	local sampled_coverage = {}
	for slot = 1, 32 do
		local descriptor = all[slot]
		if not descriptor or descriptor.identity ~= seeds.fixed[slot] or
				descriptor.accepted_r6_artifact_sha256 ~= ACCEPTED_R6_ARTIFACT_SHA256 then
			fail("finalizer seed identity/artifact binding differs")
		end
		local a, b = descriptor.stage_a_receipt, descriptor.stage_b_receipt
		if a.production_r6_content_sha256 ~= b.production_r6_content_sha256 or
				b.inherited_cultural_access_count ~= 12 or
				(production_content_sha and
					production_content_sha ~= a.production_r6_content_sha256) or
				(p9g_content_sha and p9g_content_sha ~= a.p9g_content_sha256) or
				(p9g_delta_sha and p9g_delta_sha ~= a.p9g_delta_sha256) then
			fail("finalizer Stage-A/B content identity differs")
		end
		production_content_sha, p9g_content_sha, p9g_delta_sha =
			a.production_r6_content_sha256, a.p9g_content_sha256, a.p9g_delta_sha256
		artifact.write(table.concat({"seed", tostring(slot), descriptor.identity,
			descriptor.manifest_sha256, descriptor.sha256, tostring(descriptor.bytes),
			descriptor.stage_a_sha256, descriptor.stage_b_sha256,
			descriptor.p9g_delta_sha256, descriptor.sample_roster_sha256,
			tostring(descriptor.sample_owner_count),
			tostring(descriptor.sample_column_count)}, "\t") .. "\n")
		stage_a.write(prefix_lines("seed\t" .. tostring(slot) .. "\t", descriptor.stage_a))
		stage_b.write(prefix_lines("seed\t" .. tostring(slot) .. "\t", descriptor.stage_b))

		local file = assert(io.open(descriptor.path, "rb"), "cannot open seed evidence")
		local final_byte
		if assert(file:seek("end", -1)) then final_byte = file:read(1) end
		if final_byte ~= "\n" then fail("seed evidence lacks canonical final LF") end
		assert(file:seek("set", 0))
		local line_number, seed_slot, seed_identity = 0, nil, nil
		local sample_schema, sample_roster_sha, sample_owner_population,
			sample_column_population
		local frontier_schema, frontier_roster_sha, frontier_enabled,
			frontier_enabled_seen,
			frontier_owner_population,
			frontier_column_population
		local operations, accepted_count, rejected_count, population_count = 0, 0, 0, 0
		local frontier_operations, frontier_accepted_count,
			frontier_rejected_count, frontier_population_count = 0, 0, 0, 0
		local sample_owner_rows, sample_coverage_rows, sample_coverage_columns = 0, 0, 0
		local frontier_owner_rows = 0
		local operations_by_population, populations_seen, accepted_roots = {}, {}, {}
		local frontier_operations_by_population, frontier_populations_seen,
			frontier_accepted_roots = {}, {}, {}
		local previous_operation, previous_population, previous_coverage
		local previous_frontier_operation, previous_frontier_population
		local expected_sample = sample_roster(repo, slot)
		for line in file:lines() do
			line_number = line_number + 1
			if line:find("\r", 1, true) then fail("seed evidence has CR bytes") end
			if line_number == 1 then
				if line ~= "schema\tgrug_wp40_r7_seed_evidence_v3" then
					fail("seed evidence schema differs")
				end
			elseif line:find("^seed_slot\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or seed_slot ~= nil then fail("seed slot row differs") end
				seed_slot = parsed_integer(fields[2], 1, 32, "seed slot")
			elseif line:find("^seed_identity\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or seed_identity ~= nil then fail("seed identity row differs") end
				seed_identity = text(fields[2], "seed identity")
			elseif line:find("^sample_schema\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or sample_schema ~= nil then
					fail("seed sample schema row differs")
				end
				sample_schema = text(fields[2], "seed sample schema")
			elseif line:find("^sample_roster_sha256\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or sample_roster_sha ~= nil then
					fail("seed sample roster digest row differs")
				end
				sample_roster_sha = digest(fields[2], "seed sample roster digest")
			elseif line:find("^sample_owner_count\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or sample_owner_population ~= nil then
					fail("seed sample owner-count row differs")
				end
				sample_owner_population = parsed_integer(fields[2], SAMPLE_OWNER_COUNT,
					SAMPLE_OWNER_COUNT, "seed sample owner count")
			elseif line:find("^sample_column_count\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or sample_column_population ~= nil then
					fail("seed sample column-count row differs")
				end
				sample_column_population = parsed_integer(fields[2], 1, 49980561,
					"seed sample column count")
			elseif line:find("^sample_owner\t") then
				local fields = split_tabs(line)
				if #fields ~= 7 then fail("seed sample owner row width differs") end
				local ordinal = parsed_integer(fields[2], 1, SAMPLE_OWNER_COUNT,
					"seed sample owner ordinal")
				sample_owner_rows = sample_owner_rows + 1
				local expected = expected_sample.rows[sample_owner_rows]
				if ordinal ~= sample_owner_rows or not expected or
						fields[3] ~= expected.class or fields[4] ~= expected.label or
						parsed_integer(fields[5], OWNER_MIN_X, OWNER_MAX_X,
							"seed sample owner x") ~= expected.owner_x or
						parsed_integer(fields[6], OWNER_MIN_Z, OWNER_MAX_Z,
							"seed sample owner z") ~= expected.owner_z or
						parsed_integer(fields[7], 1, 6400,
							"seed sample owner columns") ~= expected.columns then
					fail("seed sample owner roster differs")
				end
			elseif line:find("^frontier_access_schema\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or frontier_schema ~= nil then
					fail("seed frontier access schema row differs")
				end
				frontier_schema = text(fields[2], "seed frontier access schema")
			elseif line:find("^frontier_access_roster_sha256\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or frontier_roster_sha ~= nil then
					fail("seed frontier access roster digest row differs")
				end
				frontier_roster_sha = digest(fields[2],
					"seed frontier access roster digest")
			elseif line:find("^frontier_access_enabled\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or frontier_enabled_seen or
						(fields[2] ~= "true" and fields[2] ~= "false") then
					fail("seed frontier access selection row differs")
				end
				frontier_enabled, frontier_enabled_seen = fields[2] == "true", true
			elseif line:find("^frontier_access_owner_count\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or frontier_owner_population ~= nil then
					fail("seed frontier access owner-count row differs")
				end
				frontier_owner_population = parsed_integer(fields[2], 0,
					FRONTIER_ACCESS_OWNER_COUNT, "seed frontier access owner count")
			elseif line:find("^frontier_access_column_count\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or frontier_column_population ~= nil then
					fail("seed frontier access column-count row differs")
				end
				frontier_column_population = parsed_integer(fields[2], 0,
					FRONTIER_ACCESS_COLUMN_COUNT, "seed frontier access column count")
			elseif line:find("^frontier_access_owner\t") then
				local fields = split_tabs(line)
				if #fields ~= 6 then fail("seed frontier access owner row width differs") end
				frontier_owner_rows = frontier_owner_rows + 1
				local expected = expected_access.rows[frontier_owner_rows]
				if parsed_integer(fields[2], 1, FRONTIER_ACCESS_OWNER_COUNT,
						"seed frontier access owner ordinal") ~= frontier_owner_rows or
						not expected or fields[3] ~= expected.envelope_id or
						parsed_integer(fields[4], OWNER_MIN_X, OWNER_MAX_X,
							"seed frontier access owner x") ~= expected.owner_x or
						parsed_integer(fields[5], OWNER_MIN_Z, OWNER_MAX_Z,
							"seed frontier access owner z") ~= expected.owner_z or
						parsed_integer(fields[6], 1, 6400,
							"seed frontier access owner columns") ~= expected.columns then
					fail("seed frontier access owner roster differs")
				end
			elseif line:find("^operation\t") then
				local fields = split_tabs(line)
				if #fields ~= #OPERATION_FIELDS + 1 then fail("P9G operation TSV width differs") end
				local function value(name) return fields[OPERATION_COLUMN[name]] end
				local source_id, zone_id, biome = text(value("source_id"), "operation source"),
					text(value("zone_id"), "operation zone"), text(value("biome"), "operation biome")
				local faction, bracket = text(value("faction"), "operation faction"),
					text(value("bracket"), "operation bracket")
				if not source_by_id[source_id] or (faction ~= "accord" and faction ~= "throng") or
					not P9G_BRACKETS[bracket] then
					fail("P9G operation population identity differs")
				end
				local source_definition, support_name
				digest(value("candidate_sha256"), "operation candidate digest")
				for _, name in ipairs({"cell_x", "cell_z", "root_x", "root_y", "root_z",
						"original_cid", "original_param2", "prior_cid", "prior_param2",
						"prior_occupancy", "prior_opcode", "prior_feature", "prior_interface",
						"prior_aux", "support_cid", "support_param2", "support_occupancy",
						"support_opcode", "support_feature", "support_interface", "support_aux",
						"final_cid", "final_param2", "final_occupancy", "final_opcode",
						"final_feature", "final_interface", "final_aux"}) do
					parsed_integer(value(name), -MAX_SAFE, MAX_SAFE, "operation " .. name)
				end
				text(value("support_mode"), "operation support mode")
				local accepted = value("accepted")
				local reason = text(value("reason"), "operation reason")
				if accepted ~= "true" and accepted ~= "false" then
					fail("operation acceptance encoding differs")
				end
				local key = population_key(source_id, zone_id, biome, faction, bracket)
				local target = operations_by_population[key]
				if not target then
					target = {budget = 0, accepted = 0, rejections = {}}
					for index = 1, #P9G_REASONS do target.rejections[P9G_REASONS[index]] = 0 end
					operations_by_population[key] = target
				end
				target.budget = target.budget + 1
				local root_x = parsed_integer(value("root_x"), -31007, 31007, "operation root x")
				local root_y = parsed_integer(value("root_y"), -31007, 31007, "operation root y")
				local root_z = parsed_integer(value("root_z"), -31007, 31007, "operation root z")
				source_definition, support_name = source_semantics(source_id, zone_id,
					biome, faction, bracket)
				local order = {owner_minimum(root_z), owner_minimum(root_x), root_z,
					root_x, root_y, source_id}
				if previous_operation then
					local less = false
					for field = 1, 5 do
						if previous_operation[field] ~= order[field] then
							less = previous_operation[field] < order[field]
							break
						end
					end
					if not less and previous_operation[1] == order[1] and
							previous_operation[2] == order[2] and
							previous_operation[3] == order[3] and
							previous_operation[4] == order[4] and
							previous_operation[5] == order[5] then
						less = less_bytes(previous_operation[6], order[6])
					end
					if not less then fail("seed P9G operations are not canonical/unique") end
				end
				previous_operation = order
				if accepted == "true" then
					local root = table.concat({root_x, root_y, root_z}, "/")
					local final_cid = parsed_integer(value("final_cid"), 0, MAX_SAFE,
						"final CID")
					local final_feature = parsed_integer(value("final_feature"), 0,
						MAX_SAFE, "final feature")
					local final_interface = parsed_integer(value("final_interface"), 0,
						MAX_SAFE, "final interface")
					if reason ~= "accepted" or accepted_roots[root] or
							final_cid ~= content_fixture.cid_by_name[source_definition.source_node] or
							parsed_integer(value("final_param2"), 0, 255, "final param2") ~= 0 or
							parsed_integer(value("final_occupancy"), -MAX_SAFE, MAX_SAFE,
								"final occupancy") ~= -2 or
							parsed_integer(value("final_opcode"), 0, MAX_SAFE,
								"final opcode") ~= 35 or
							final_feature ~= source_index[source_id] or final_interface ~= 0 or
							parsed_integer(value("final_aux"), 0, MAX_SAFE, "final aux") ~=
								(82 + source_index[source_id]) * 256 then
						fail("accepted P9G operation tuple/uniqueness differs")
					end
					local support_mode = value("support_mode")
					if (support_mode ~= "settled_owner" and
							support_mode ~= "analytic_lower_owner") or
							parsed_integer(value("original_cid"), 0, MAX_SAFE,
								"original CID") == content_fixture.cid_by_name.ignore or
							parsed_integer(value("prior_cid"), 0, MAX_SAFE, "prior CID") ~=
								content_fixture.cid_by_name.air or
							parsed_integer(value("prior_param2"), 0, 255, "prior param2") ~= 0 or
							parsed_integer(value("prior_occupancy"), -MAX_SAFE, MAX_SAFE,
								"prior occupancy") ~= 0 or
							parsed_integer(value("prior_opcode"), -MAX_SAFE, MAX_SAFE,
								"prior opcode") ~= 0 or
							parsed_integer(value("prior_feature"), -MAX_SAFE, MAX_SAFE,
								"prior feature") ~= 0 or
							parsed_integer(value("prior_interface"), -MAX_SAFE, MAX_SAFE,
								"prior interface") ~= 0 or
							parsed_integer(value("prior_aux"), -MAX_SAFE, MAX_SAFE,
								"prior aux") ~= 0 or
							parsed_integer(value("support_cid"), 0, MAX_SAFE, "support CID") ~=
								content_fixture.cid_by_name[support_name] or
							parsed_integer(value("support_param2"), 0, 255,
								"support param2") ~= 0 or
							parsed_integer(value("support_opcode"), 1, 4,
								"support opcode") < 1 then
						fail("accepted P9G prior/support authority differs")
					end
					local identity = table.concat({final_cid, final_feature,
						final_interface, value("final_aux")}, "/")
					if source_final_tuple[source_id] and
							source_final_tuple[source_id] ~= identity then
						fail("accepted P9G source final tuple differs")
					end
					source_final_tuple[source_id] = identity
					accepted_roots[root], target.accepted = true, target.accepted + 1
					accepted_count = accepted_count + 1
				else
					if not reason_set[reason] then fail("operation rejection reason differs") end
					for _, field in ipairs({"cid", "param2", "occupancy", "opcode",
							"feature", "interface", "aux"}) do
						if value("final_" .. field) ~= value("prior_" .. field) then
							fail("rejected P9G operation changed its prior tuple")
						end
					end
					target.rejections[reason] = target.rejections[reason] + 1
					rejected_count = rejected_count + 1
				end
				operations = operations + 1
				p9g.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			elseif line:find("^population\t") then
				local fields = split_tabs(line)
				if #fields ~= 9 + #P9G_REASONS then fail("P9G population TSV width differs") end
				local source_id, zone_id, biome = text(fields[2], "population source"),
					text(fields[3], "population zone"), text(fields[4], "population biome")
				local faction, bracket = text(fields[5], "population faction"),
					text(fields[6], "population bracket")
				if not source_by_id[source_id] or (faction ~= "accord" and faction ~= "throng") or
						not P9G_BRACKETS[bracket] then
					fail("P9G population identity differs")
				end
				source_semantics(source_id, zone_id, biome, faction, bracket)
				local key = population_key(source_id, zone_id, biome, faction, bracket)
				if populations_seen[key] or (previous_population and
						not less_bytes(previous_population, key)) then
					fail("seed P9G populations are not canonical/unique")
				end
				populations_seen[key], previous_population = true, key
				local eligible = parsed_integer(fields[7], 0, MAX_SAFE, "population eligible")
				local budget = parsed_integer(fields[8], 0, MAX_SAFE, "population budget")
				local accepted = parsed_integer(fields[9], 0, MAX_SAFE, "population accepted")
				local rejected, operation = 0, operations_by_population[key]
				if not operation then
					operation = {budget = 0, accepted = 0, rejections = {}}
					for index = 1, #P9G_REASONS do
						operation.rejections[P9G_REASONS[index]] = 0
					end
				end
				for index = 1, #P9G_REASONS do
					local count = parsed_integer(fields[9 + index], 0, MAX_SAFE,
						"population rejection")
					rejected = rejected + count
					if count ~= operation.rejections[P9G_REASONS[index]] then
						fail("population/operation rejection partition differs")
					end
				end
				if budget > eligible or accepted + rejected ~= budget or
						operation.budget ~= budget or operation.accepted ~= accepted then
					fail("population E/B/accepted invariant differs")
				end
				operations_by_population[key] = nil
				local totals = source_totals[source_id]
				totals.eligible, totals.budget, totals.accepted = totals.eligible + eligible,
					totals.budget + budget, totals.accepted + accepted
				access[source_id][faction] = access[source_id][faction] + accepted
				local bracket_row = parity[source_id][bracket]
				if not bracket_row then
					bracket_row = {accord = {eligible = 0, budget = 0},
						throng = {eligible = 0, budget = 0}}
					parity[source_id][bracket] = bracket_row
				end
				bracket_row[faction].eligible = bracket_row[faction].eligible + eligible
				bracket_row[faction].budget = bracket_row[faction].budget + budget
				population_count = population_count + 1
				p9g.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			elseif line:find("^frontier_access_operation\t") then
				local fields = split_tabs(line)
				if #fields ~= #OPERATION_FIELDS + 1 then
					fail("frontier access operation TSV width differs")
				end
				local function value(name) return fields[OPERATION_COLUMN[name]] end
				local source_id = text(value("source_id"), "frontier access operation source")
				local zone_id = text(value("zone_id"), "frontier access operation zone")
				local biome = text(value("biome"), "frontier access operation biome")
				local faction = text(value("faction"), "frontier access operation faction")
				local bracket = text(value("bracket"), "frontier access operation bracket")
				if not FRONTIER_ACCESS_SOURCE_SET[source_id] or
						not FRONTIER_ACCESS_ZONE_SET[zone_id] or
						(faction ~= "accord" and faction ~= "throng") or
						not P9G_BRACKETS[bracket] then
					fail("frontier access operation identity differs")
				end
				local source_definition, support_name = source_semantics(source_id,
					zone_id, biome, faction, bracket)
				digest(value("candidate_sha256"), "frontier access candidate digest")
				for _, name in ipairs({"cell_x", "cell_z", "root_x", "root_y", "root_z",
						"original_cid", "original_param2", "prior_cid", "prior_param2",
						"prior_occupancy", "prior_opcode", "prior_feature", "prior_interface",
						"prior_aux", "support_cid", "support_param2", "support_occupancy",
						"support_opcode", "support_feature", "support_interface", "support_aux",
						"final_cid", "final_param2", "final_occupancy", "final_opcode",
						"final_feature", "final_interface", "final_aux"}) do
					parsed_integer(value(name), -MAX_SAFE, MAX_SAFE,
						"frontier access operation " .. name)
				end
				text(value("support_mode"), "frontier access operation support mode")
				local accepted, reason = value("accepted"),
					text(value("reason"), "frontier access operation reason")
				if accepted ~= "true" and accepted ~= "false" then
					fail("frontier access acceptance encoding differs")
				end
				local key = population_key(source_id, zone_id, biome, faction, bracket)
				local target = frontier_operations_by_population[key]
				if not target then
					target = {budget = 0, accepted = 0, rejections = {}}
					for index = 1, #P9G_REASONS do
						target.rejections[P9G_REASONS[index]] = 0
					end
					frontier_operations_by_population[key] = target
				end
				target.budget = target.budget + 1
				local root_x = parsed_integer(value("root_x"), -31007, 31007,
					"frontier access root x")
				local root_y = parsed_integer(value("root_y"), -31007, 31007,
					"frontier access root y")
				local root_z = parsed_integer(value("root_z"), -31007, 31007,
					"frontier access root z")
				local order = {owner_minimum(root_z), owner_minimum(root_x), root_z,
					root_x, root_y, source_id}
				if previous_frontier_operation then
					local less = false
					for field = 1, 5 do
						if previous_frontier_operation[field] ~= order[field] then
							less = previous_frontier_operation[field] < order[field]
							break
						end
					end
					if not less and previous_frontier_operation[1] == order[1] and
							previous_frontier_operation[2] == order[2] and
							previous_frontier_operation[3] == order[3] and
							previous_frontier_operation[4] == order[4] and
							previous_frontier_operation[5] == order[5] then
						less = less_bytes(previous_frontier_operation[6], order[6])
					end
					if not less then
						fail("frontier access operations are not canonical/unique")
					end
				end
				previous_frontier_operation = order
				if accepted == "true" then
					local root = table.concat({root_x, root_y, root_z}, "/")
					local final_cid = parsed_integer(value("final_cid"), 0, MAX_SAFE,
						"frontier access final CID")
					local final_feature = parsed_integer(value("final_feature"), 0, MAX_SAFE,
						"frontier access final feature")
					local final_interface = parsed_integer(value("final_interface"), 0,
						MAX_SAFE, "frontier access final interface")
					if reason ~= "accepted" or frontier_accepted_roots[root] or
							final_cid ~= content_fixture.cid_by_name[source_definition.source_node] or
							parsed_integer(value("final_param2"), 0, 255,
								"frontier access final param2") ~= 0 or
							parsed_integer(value("final_occupancy"), -MAX_SAFE, MAX_SAFE,
								"frontier access final occupancy") ~= -2 or
							parsed_integer(value("final_opcode"), 0, MAX_SAFE,
								"frontier access final opcode") ~= 35 or
							final_feature ~= source_index[source_id] or final_interface ~= 0 or
							parsed_integer(value("final_aux"), 0, MAX_SAFE,
								"frontier access final aux") ~= (82 + source_index[source_id]) * 256 then
					fail("accepted frontier access final tuple/uniqueness differs")
					end
					local support_mode = value("support_mode")
					if (support_mode ~= "settled_owner" and
							support_mode ~= "analytic_lower_owner") or
							parsed_integer(value("original_cid"), 0, MAX_SAFE,
								"frontier access original CID") == content_fixture.cid_by_name.ignore or
							parsed_integer(value("prior_cid"), 0, MAX_SAFE,
								"frontier access prior CID") ~= content_fixture.cid_by_name.air or
							parsed_integer(value("prior_param2"), 0, 255,
								"frontier access prior param2") ~= 0 or
							parsed_integer(value("prior_occupancy"), -MAX_SAFE, MAX_SAFE,
								"frontier access prior occupancy") ~= 0 or
							parsed_integer(value("prior_opcode"), -MAX_SAFE, MAX_SAFE,
								"frontier access prior opcode") ~= 0 or
							parsed_integer(value("prior_feature"), -MAX_SAFE, MAX_SAFE,
								"frontier access prior feature") ~= 0 or
							parsed_integer(value("prior_interface"), -MAX_SAFE, MAX_SAFE,
								"frontier access prior interface") ~= 0 or
							parsed_integer(value("prior_aux"), -MAX_SAFE, MAX_SAFE,
								"frontier access prior aux") ~= 0 or
							parsed_integer(value("support_cid"), 0, MAX_SAFE,
								"frontier access support CID") ~=
								content_fixture.cid_by_name[support_name] or
							parsed_integer(value("support_param2"), 0, 255,
								"frontier access support param2") ~= 0 or
							parsed_integer(value("support_opcode"), 1, 4,
								"frontier access support opcode") < 1 then
						fail("accepted frontier access prior/support authority differs")
					end
					local identity = table.concat({final_cid, final_feature,
						final_interface, value("final_aux")}, "/")
					if source_final_tuple[source_id] and
							source_final_tuple[source_id] ~= identity then
						fail("accepted frontier source final tuple differs")
					end
					source_final_tuple[source_id] = identity
					frontier_accepted_roots[root], target.accepted = true, target.accepted + 1
					frontier_accepted_count = frontier_accepted_count + 1
				else
					if not reason_set[reason] then
						fail("frontier access rejection reason differs")
					end
					for _, field in ipairs({"cid", "param2", "occupancy", "opcode",
							"feature", "interface", "aux"}) do
						if value("final_" .. field) ~= value("prior_" .. field) then
							fail("rejected frontier access operation changed its prior tuple")
						end
					end
					target.rejections[reason] = target.rejections[reason] + 1
					frontier_rejected_count = frontier_rejected_count + 1
				end
				frontier_operations = frontier_operations + 1
				frontier.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			elseif line:find("^frontier_access_population\t") then
				local fields = split_tabs(line)
				if #fields ~= 9 + #P9G_REASONS then
					fail("frontier access population TSV width differs")
				end
				local source_id = text(fields[2], "frontier access population source")
				local zone_id = text(fields[3], "frontier access population zone")
				local biome = text(fields[4], "frontier access population biome")
				local faction = text(fields[5], "frontier access population faction")
				local bracket = text(fields[6], "frontier access population bracket")
				if not FRONTIER_ACCESS_SOURCE_SET[source_id] or
						not FRONTIER_ACCESS_ZONE_SET[zone_id] or
						(faction ~= "accord" and faction ~= "throng") or
						not P9G_BRACKETS[bracket] then
					fail("frontier access population identity differs")
				end
				source_semantics(source_id, zone_id, biome, faction, bracket)
				local key = population_key(source_id, zone_id, biome, faction, bracket)
				if frontier_populations_seen[key] or (previous_frontier_population and
						not less_bytes(previous_frontier_population, key)) then
					fail("frontier access populations are not canonical/unique")
				end
				frontier_populations_seen[key], previous_frontier_population = true, key
				local eligible = parsed_integer(fields[7], 0, MAX_SAFE,
					"frontier access population eligible")
				local budget = parsed_integer(fields[8], 0, MAX_SAFE,
					"frontier access population budget")
				local accepted = parsed_integer(fields[9], 0, MAX_SAFE,
					"frontier access population accepted")
				local rejected, operation = 0, frontier_operations_by_population[key]
				if not operation then
					operation = {budget = 0, accepted = 0, rejections = {}}
					for index = 1, #P9G_REASONS do
						operation.rejections[P9G_REASONS[index]] = 0
					end
				end
				for index = 1, #P9G_REASONS do
					local count = parsed_integer(fields[9 + index], 0, MAX_SAFE,
						"frontier access population rejection")
					rejected = rejected + count
					if count ~= operation.rejections[P9G_REASONS[index]] then
						fail("frontier access population/operation rejection partition differs")
					end
				end
				if budget > eligible or accepted + rejected ~= budget or
						operation.budget ~= budget or operation.accepted ~= accepted then
					fail("frontier access population E/B/accepted invariant differs")
				end
				frontier_operations_by_population[key] = nil
				local totals, pair = frontier_source_totals[source_id],
					frontier_access[source_id][faction]
				totals.eligible, totals.budget, totals.accepted = totals.eligible + eligible,
					totals.budget + budget, totals.accepted + accepted
				pair.eligible, pair.budget, pair.accepted = pair.eligible + eligible,
					pair.budget + budget, pair.accepted + accepted
				frontier_population_count = frontier_population_count + 1
				frontier.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			elseif line:find("^sample_coverage\t") then
				local fields = split_tabs(line)
				if #fields ~= 4 then fail("sample coverage TSV width differs") end
				local zone_id, biome = text(fields[2], "sample coverage zone"),
					text(fields[3], "sample coverage biome")
				local zone, allowed = zone_by_id[zone_id], false
				if zone then
					for index = 1, #zone.biomes do
						if zone.biomes[index].id == biome then allowed = true break end
					end
				end
				local count = parsed_integer(fields[4], 1, 49980561,
					"sample coverage columns")
				local key = zone_id .. "\0" .. biome
				if not allowed or (previous_coverage and
						not less_bytes(previous_coverage, key)) then
					fail("sample coverage identity/order differs")
				end
				previous_coverage = key
				sampled_coverage[key] = (sampled_coverage[key] or 0) + count
				sample_coverage_rows = sample_coverage_rows + 1
				sample_coverage_columns = sample_coverage_columns + count
				p9g.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			else
				fail("seed evidence row differs")
			end
		end
		assert(file:close())
		for key in pairs(operations_by_population) do
			fail("operation population is absent: " .. key)
		end
		for key in pairs(frontier_operations_by_population) do
			fail("frontier access operation population is absent: " .. key)
		end
		if line_number < 4 or seed_slot ~= slot or seed_identity ~= descriptor.identity or
				sample_schema ~= SAMPLE_SCHEMA or
				sample_roster_sha ~= expected_sample.sha256 or
				sample_roster_sha ~= descriptor.sample_roster_sha256 or
				sample_owner_population ~= SAMPLE_OWNER_COUNT or
				sample_owner_rows ~= SAMPLE_OWNER_COUNT or
				sample_column_population ~= expected_sample.columns or
				sample_column_population ~= descriptor.sample_column_count or
				sample_coverage_rows < 1 or sample_coverage_columns < 1 or
				sample_coverage_columns > sample_column_population or
				population_count < 1 or operations ~= a.operation_count or
				accepted_count ~= a.accepted_count or rejected_count ~= a.rejected_count then
			fail("seed P9G ledger population/Stage-A identity differs")
		end
		local expected_frontier_enabled = FRONTIER_ACCESS_SEED_SET[slot] == true
		local expected_frontier_owners = expected_frontier_enabled and
			FRONTIER_ACCESS_OWNER_COUNT or 0
		local expected_frontier_columns = expected_frontier_enabled and
			FRONTIER_ACCESS_COLUMN_COUNT or 0
		if frontier_schema ~= FRONTIER_ACCESS_SCHEMA or
				frontier_roster_sha ~= expected_access.sha256 or
				frontier_roster_sha ~= descriptor.frontier_access_roster_sha256 or
				not frontier_enabled_seen or
				frontier_enabled ~= expected_frontier_enabled or
				frontier_enabled ~= descriptor.frontier_access_enabled or
				frontier_owner_population ~= expected_frontier_owners or
				frontier_owner_rows ~= expected_frontier_owners or
				frontier_owner_population ~= descriptor.frontier_access_owner_count or
				frontier_column_population ~= expected_frontier_columns or
				frontier_column_population ~= descriptor.frontier_access_column_count or
				(expected_frontier_enabled and frontier_population_count < 1) or
				(not expected_frontier_enabled and frontier_population_count ~= 0) or
				frontier_operations ~= descriptor.frontier_access_operation_count or
				frontier_accepted_count ~= descriptor.frontier_access_accepted_count or
				frontier_rejected_count ~= descriptor.frontier_access_rejected_count or
				frontier_operations ~= frontier_accepted_count + frontier_rejected_count then
			fail("seed frontier access ledger/roster identity differs")
		end
		total_sample_cases = total_sample_cases + sample_owner_rows
		total_sample_columns = total_sample_columns + sample_column_population
		total_sample_surface_columns = total_sample_surface_columns +
			sample_coverage_columns
		total_operations, total_accepted, total_rejected = total_operations + operations,
			total_accepted + accepted_count, total_rejected + rejected_count
		total_frontier_cases = total_frontier_cases + frontier_owner_rows
		total_frontier_columns = total_frontier_columns + frontier_column_population
		total_frontier_operations = total_frontier_operations + frontier_operations
		total_frontier_accepted = total_frontier_accepted + frontier_accepted_count
		total_frontier_rejected = total_frontier_rejected + frontier_rejected_count
	end

	local nonzero_sources, required_main_sources, access_gates, parity_gates = 0, 0, 0, 0
	local parity_advisory_failures, parity_advisory_insufficient = 0, 0
	local bracket_order = {"1-10", "11-20", "21-30", "31-40", "41-50", "51-60"}
	local function safe_product(left, right, label)
		integer(left, 0, MAX_SAFE, label .. " left")
		integer(right, 0, MAX_SAFE, label .. " right")
		if left ~= 0 and right > math.floor(MAX_SAFE / left) then
			fail(label .. " exceeds exact-double integer range")
		end
		return left * right
	end
	for index = 1, #source_rows do
		local row, totals = source_rows[index], source_totals[source_rows[index].id]
		local complete = totals.eligible > 0 and totals.budget > 0 and totals.accepted > 0
		if not FRONTIER_ACCESS_SOURCE_SET[row.id] and not complete then
			fail("P9G source lacks nonzero E/B/accepted: " .. row.id)
		end
		if complete then nonzero_sources = nonzero_sources + 1 end
		if not FRONTIER_ACCESS_SOURCE_SET[row.id] then
			required_main_sources = required_main_sources + 1
		end
		p9g.write(table.concat({"advisory", "source_totals", row.id,
			tostring(totals.eligible), tostring(totals.budget),
			tostring(totals.accepted)}, "\t") .. "\n")
		if MAIN_PAIRED_ACCESS_SOURCE_SET[row.id] then
			for _, faction in ipairs({"accord", "throng"}) do
				if access[row.id][faction] <= 0 then
					fail("P9G required faction access is zero: " .. row.id .. "/" .. faction)
				end
				access_gates = access_gates + 1
			end
		end
		if row.harvest_kind == "healing_herb" or row.harvest_kind == "spice" then
			for bracket_index = 1, #bracket_order do
				local bracket = bracket_order[bracket_index]
				local factions = parity[row.id][bracket]
				if factions then
					local accord, throng, status = factions.accord, factions.throng, "pass"
					if accord.eligible <= 0 or throng.eligible <= 0 then
						status = "insufficient_faction_sample"
						parity_advisory_insufficient = parity_advisory_insufficient + 1
					else
						local left = safe_product(accord.budget, throng.eligible,
							"P9G parity cross-product")
						local right = safe_product(throng.budget, accord.eligible,
							"P9G parity cross-product")
						local high, low = math.max(left, right), math.min(left, right)
						if high - low > math.floor(low / 10) then
							status = "outside_10_percent"
							parity_advisory_failures = parity_advisory_failures + 1
						end
					end
					parity_gates = parity_gates + 1
					p9g.write(table.concat({"advisory", "parity", row.id, bracket,
						status, tostring(accord.eligible), tostring(accord.budget),
						tostring(throng.eligible), tostring(throng.budget)}, "\t") .. "\n")
				end
			end
		end
	end
	local frontier_access_gates = 0
	for index = 1, #FRONTIER_ACCESS_SOURCES do
		local id, totals = FRONTIER_ACCESS_SOURCES[index],
			frontier_source_totals[FRONTIER_ACCESS_SOURCES[index]]
		if totals.eligible <= 0 or totals.budget <= 0 or totals.accepted <= 0 then
			fail("frontier source lacks nonzero E/B/accepted: " .. id)
		end
		frontier.write(table.concat({"source_totals", id, tostring(totals.eligible),
			tostring(totals.budget), tostring(totals.accepted)}, "\t") .. "\n")
		for _, faction in ipairs({"accord", "throng"}) do
			local pair = frontier_access[id][faction]
			if pair.eligible <= 0 or pair.budget <= 0 or pair.accepted <= 0 then
				fail("frontier source/faction lacks E/B/accepted: " .. id .. "/" .. faction)
			end
			frontier_access_gates = frontier_access_gates + 1
			frontier.write(table.concat({"gate", id, faction,
				tostring(pair.eligible), tostring(pair.budget), tostring(pair.accepted),
				"pass"}, "\t") .. "\n")
		end
	end
	local sampled_coverage_population = 0
	for _ in pairs(sampled_coverage) do sampled_coverage_population =
		sampled_coverage_population + 1 end
	if required_main_sources ~= 8 or nonzero_sources < 8 or
			total_operations ~= total_accepted + total_rejected or
			total_sample_cases ~= 32 * SAMPLE_OWNER_COUNT or
			total_sample_columns ~= 32 * 795281 or sampled_coverage_population < 1 or
			total_frontier_cases ~= 7 * FRONTIER_ACCESS_OWNER_COUNT or
			total_frontier_columns ~= 7 * FRONTIER_ACCESS_COLUMN_COUNT or
			total_frontier_operations ~= total_frontier_accepted +
				total_frontier_rejected or frontier_access_gates ~= 8 then
		fail("fleet P9G closed totals differ")
	end

	local artifact_result, stage_a_result, stage_b_result, p9g_result,
		frontier_result = artifact.close(), stage_a.close(), stage_b.close(),
		p9g.close(), frontier.close()
	local receipt = new_final_output(scratch .. "/run-receipt.tsv", stream)
	receipt.write(table.concat({
		"schema\tgrug_wp40_r7_run_receipt_v3\n",
		"proof_scope_fleet\t32_seed_stratified_4096_owner_main_plus_7_seed_3206_owner_frontier_access\n",
		"acceptance_scope\t32_seed_main_plus_7_seed_static_frontier_successor_lane_not_exhaustive\n",
		"projection_sha256\t", projection, "\n",
		"accepted_r6_artifact_sha256\t", ACCEPTED_R6_ARTIFACT_SHA256, "\n",
		"production_r6_content_sha256\t", production_content_sha, "\n",
		"p9g_content_sha256\t", p9g_content_sha, "\n",
		"p9g_delta_sha256\t", p9g_delta_sha, "\n",
		"seed_population\t32\n",
		"sample_owner_population_per_seed\t128\n",
		"sample_case_population\t", tostring(total_sample_cases), "\n",
		"sample_column_visit_population\t", tostring(total_sample_columns), "\n",
		"sample_surface_coverage_column_population\t",
			tostring(total_sample_surface_columns), "\n",
		"sample_zone_biome_population\t", tostring(sampled_coverage_population), "\n",
		"p9g_source_population\t12\n",
		"inherited_cultural_access_count\t12\n",
		"p9g_nonzero_source_population\t", tostring(nonzero_sources), "\n",
		"p9g_operation_count\t", tostring(total_operations), "\n",
		"p9g_accepted_count\t", tostring(total_accepted), "\n",
		"p9g_rejected_count\t", tostring(total_rejected), "\n",
		"p9g_access_gate_count\t", tostring(access_gates), "\n",
		"p9g_parity_gate_count\t", tostring(parity_gates), "\n",
		"p9g_parity_policy\tadvisory_non_blocking\n",
		"p9g_parity_advisory_failure_count\t",
			tostring(parity_advisory_failures), "\n",
		"p9g_parity_advisory_insufficient_count\t",
			tostring(parity_advisory_insufficient), "\n",
		"frontier_access_schema\t", FRONTIER_ACCESS_SCHEMA, "\n",
		"frontier_access_roster_sha256\t", expected_access.sha256, "\n",
		"frontier_access_seed_population\t7\n",
		"frontier_access_seed_slots\t1,6,11,17,22,27,32\n",
		"frontier_access_owner_population_per_seed\t",
			tostring(FRONTIER_ACCESS_OWNER_COUNT), "\n",
		"frontier_access_case_population\t", tostring(total_frontier_cases), "\n",
		"frontier_access_column_visit_population\t",
			tostring(total_frontier_columns), "\n",
		"frontier_access_zone_population\t4\n",
		"frontier_access_source_population\t4\n",
		"frontier_access_source_faction_gate_population\t",
			tostring(frontier_access_gates), "\n",
		"frontier_access_operation_count\t", tostring(total_frontier_operations), "\n",
		"frontier_access_accepted_count\t", tostring(total_frontier_accepted), "\n",
		"frontier_access_rejected_count\t", tostring(total_frontier_rejected), "\n",
		"canonical_worker_order\tseed_slot\n",
		"artifact_sha256\t", artifact_result.sha256, "\n",
		"stage_a_sha256\t", stage_a_result.sha256, "\n",
		"stage_b_sha256\t", stage_b_result.sha256, "\n",
		"p9g_sha256\t", p9g_result.sha256, "\n",
		"frontier_access_sha256\t", frontier_result.sha256, "\n",
	}))
	local receipt_result = receipt.close()
	return {artifact = artifact_result, stage_a = stage_a_result,
		stage_b = stage_b_result, p9g = p9g_result,
		frontier_access = frontier_result, run_receipt = receipt_result}
end

return module
