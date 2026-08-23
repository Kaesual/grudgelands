-- Private WP40 D-1 projection of the checksum-validated authored zone and
-- public-route source rows into the common typed analytic-record shape.  This
-- module is engine-free.  It owns no seed, raster, relief, route-profile,
-- island-route, compiler-wiring, or runtime semantics.

local function fail(message)
	error("WP40 authored geometry: " .. message, 0)
end

local function exact_dependencies(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {canonical = true, raw_sha256 = true, source = true,
		source_validator = true, vocabulary = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unknown dependency " .. tostring(key)) end
	end
	for _, key in ipairs({"canonical", "source", "source_validator",
			"vocabulary"}) do
		if type(value[key]) ~= "table" or getmetatable(value[key]) ~= nil then
			fail(key .. " dependency is not a plain table")
		end
	end
	if type(value.raw_sha256) ~= "function" then
		fail("raw SHA dependency missing")
	end
	if type(value.source_validator.validate) ~= "function" and
			type(value.source_validator.new_offline_test_adapter) ~= "function" then
		fail("source-validator dependency is unavailable")
	end
end

local function integer(value, minimum, maximum, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail(label .. " is outside its integer range")
	end
	return value
end

local function text(value, label, allow_empty)
	if type(value) ~= "string" or not allow_empty and value == "" then
		fail(label .. " is not " .. (allow_empty and "text" or "non-empty text"))
	end
	return value
end

local function boolean(value, label)
	if type(value) ~= "boolean" then fail(label .. " is not boolean") end
	return value
end

local function dense_count(value, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain array")
	end
	local count = #value
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not dense")
		end
	end
	for index = 1, count do
		if value[index] == nil then fail(label .. " has a hole") end
	end
	return count
end

local function exact_fields(value, fields, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain table")
	end
	local allowed = {}
	for index = 1, #fields do
		allowed[fields[index]] = true
		if value[fields[index]] == nil then
			fail(label .. " is missing field " .. fields[index])
		end
	end
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then
			fail(label .. " has unknown field " .. tostring(key))
		end
	end
end

local function plain_tree(value, label, seen)
	local kind = type(value)
	if kind == "function" or kind == "userdata" or kind == "thread" then
		fail(label .. " is not data-only")
	end
	if kind ~= "table" then return end
	if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
	if seen[value] then fail(label .. " contains a cycle or mutable alias") end
	seen[value] = true
	for key, child in pairs(value) do
		plain_tree(key, label, seen)
		plain_tree(child, label, seen)
	end
end

local function named_scalar(values)
	local names = {}
	for name in pairs(values) do names[#names + 1] = name end
	table.sort(names)
	local rows = {}
	for index = 1, #names do
		local name = names[index]
		rows[index] = {name = name, value = values[name]}
	end
	return rows
end

local function named_array(values)
	local names = {}
	for name in pairs(values) do names[#names + 1] = name end
	table.sort(names)
	local rows = {}
	for index = 1, #names do
		local name = names[index]
		rows[index] = {name = name, values = values[name]}
	end
	return rows
end

local function record(schema, id, numeric_id, fields)
	return {
		record_schema = schema,
		id = id,
		numeric_id = numeric_id,
		text_values = named_scalar(fields.text or {}),
		signed_values = named_scalar(fields.signed or {}),
		unsigned_values = named_scalar(fields.unsigned or {}),
		boolean_values = named_scalar(fields.boolean or {}),
		text_arrays = named_array(fields.text_arrays or {}),
		signed_arrays = named_array(fields.signed_arrays or {}),
		unsigned_arrays = named_array(fields.unsigned_arrays or {}),
		candidates = {},
		attributes = {},
	}
end

local ZONE_FIELDS = {"biomes", "civic_no_hostiles", "display_name",
	"faction", "id", "level_max", "level_min", "numeric_id",
	"primary_relief_id", "pvp_rule", "race_region", "territory_rule"}
local BIOME_FIELDS = {"id", "share"}
local ROUTE_FIELDS = {"boundary_id", "boundary_interface_id", "centreline",
	"class", "crossing_station", "endpoint_a_id", "endpoint_b_id",
	"gate_ref_a", "gate_ref_b", "grade_phase", "id", "numeric_id", "station_a_id",
	"station_b_id", "zone_a", "zone_b"}
local POINT_FIELDS = {"x", "z"}
local BOAT_FIELDS = {"approach_z", "from_zone", "id", "landing_id",
	"numeric_id", "to_zone", "width"}

return function(dependencies)
	exact_dependencies(dependencies)
	local source = dependencies.source
	local authored = {}

	local function check_source_authority()
		local validator = dependencies.source_validator
		if type(validator.new_offline_test_adapter) == "function" then
			validator = validator.new_offline_test_adapter(dependencies.canonical,
				dependencies.raw_sha256)
		end
		if type(validator) ~= "table" or type(validator.validate) ~= "function" then
			fail("source-validator dependency is unavailable")
		end
		local accepted, diagnostic = validator.validate(source,
			dependencies.vocabulary)
		if not accepted then
			fail("checksum-validated source rejected: " ..
				tostring(diagnostic and diagnostic.invariant) .. " at " ..
				tostring(diagnostic and diagnostic.record_id) .. " expected " ..
				tostring(diagnostic and diagnostic.expected) .. " observed " ..
				tostring(diagnostic and diagnostic.observed))
		end
	end

	local function check_relevant_source()
		if type(source) ~= "table" or getmetatable(source) ~= nil then
			fail("Source is not a plain table")
		end
		local zone_count = dense_count(source.zones, "Source zones")
		local route_count = dense_count(source.routes, "Source land routes")
		local boat_count = dense_count(source.boat_edges, "Source boat routes")
		if zone_count ~= 38 then fail("Source zone count is not 38") end
		if route_count ~= 57 then fail("Source land-route count is not 57") end
		if boat_count ~= 4 then fail("Source boat-route count is not 4") end
		local seen = {}
		plain_tree(source.zones, "Source zones", seen)
		plain_tree(source.routes, "Source land routes", seen)
		plain_tree(source.boat_edges, "Source boat routes", seen)
	end

	local function compile_zones()
		local result = {}
		for index = 1, #source.zones do
			local row = source.zones[index]
			local label = "Source zone[" .. index .. "]"
			exact_fields(row, ZONE_FIELDS, label)
			integer(row.numeric_id, 1, 38, label .. " numeric_id")
			if row.numeric_id ~= index then fail(label .. " numeric identity changed") end
			text(row.id, label .. " id")
			text(row.display_name, label .. " display_name")
			text(row.race_region, label .. " race_region")
			if row.faction ~= false then text(row.faction, label .. " faction") end
			text(row.territory_rule, label .. " territory_rule")
			text(row.pvp_rule, label .. " pvp_rule")
			text(row.primary_relief_id, label .. " primary_relief_id")
			integer(row.level_min, 0, 4294967295, label .. " level_min")
			integer(row.level_max, row.level_min, 4294967295,
				label .. " level_max")
			boolean(row.civic_no_hostiles, label .. " civic_no_hostiles")
			local biome_count = dense_count(row.biomes, label .. " biomes")
			if biome_count == 0 then fail(label .. " biomes are empty") end
			local biome_ids, biome_shares = {}, {}
			local biome_seen = {}
			for biome_index = 1, biome_count do
				local biome = row.biomes[biome_index]
				exact_fields(biome, BIOME_FIELDS,
					label .. " biome[" .. biome_index .. "]")
				local biome_id = text(biome.id,
					label .. " biome[" .. biome_index .. "] id")
				if biome_seen[biome_id] then fail(label .. " biome IDs are not unique") end
				biome_seen[biome_id] = true
				biome_ids[biome_index] = biome_id
				biome_shares[biome_index] = integer(biome.share, 0, 4294967295,
					label .. " biome[" .. biome_index .. "] share")
			end
			local faction_present = row.faction ~= false
			result[index] = record("grug_wp40_zone_v1", row.id, row.numeric_id, {
				text = {display_name = row.display_name,
					faction = faction_present and row.faction or "",
					primary_relief_id = row.primary_relief_id,
					pvp_rule = row.pvp_rule, race_region = row.race_region,
					territory_rule = row.territory_rule},
				unsigned = {level_max = row.level_max, level_min = row.level_min},
				boolean = {civic_no_hostiles = row.civic_no_hostiles,
					faction_present = faction_present},
				text_arrays = {biome_ids = biome_ids},
				unsigned_arrays = {biome_shares = biome_shares},
			})
		end
		return result
	end

	local function compile_land_routes()
		local result = {}
		for index = 1, #source.routes do
			local row = source.routes[index]
			local label = "Source land route[" .. index .. "]"
			exact_fields(row, ROUTE_FIELDS, label)
			local expected_id = ("route_%03d"):format(index)
			local expected_boundary = ("land_%03d"):format(index)
			integer(row.numeric_id, 1, 57, label .. " numeric_id")
			if row.numeric_id ~= index then fail(label .. " numeric identity changed") end
			if row.id ~= expected_id then fail(label .. " numeric identity changed") end
			if row.boundary_id ~= expected_boundary then
				fail(label .. " boundary identity is not its routed land edge")
			end
			for _, field in ipairs({"id", "boundary_id", "boundary_interface_id",
					"class", "endpoint_a_id", "endpoint_b_id", "grade_phase",
					"station_a_id", "station_b_id", "zone_a", "zone_b"}) do
				text(row[field], label .. " " .. field)
			end
			integer(row.crossing_station, 1, 4294967295,
				label .. " crossing_station")
			local point_count = dense_count(row.centreline, label .. " centreline")
			if point_count < 2 or row.crossing_station > point_count then
				fail(label .. " crossing_station is outside its centreline")
			end
			local centreline_xz = {}
			for point_index = 1, point_count do
				local point = row.centreline[point_index]
				exact_fields(point, POINT_FIELDS,
					label .. " centreline[" .. point_index .. "]")
				centreline_xz[#centreline_xz + 1] = integer(point.x, -2147483648,
					2147483647, label .. " centreline x")
				centreline_xz[#centreline_xz + 1] = integer(point.z, -2147483648,
					2147483647, label .. " centreline z")
			end
			local gate_a_present = row.gate_ref_a ~= false
			local gate_b_present = row.gate_ref_b ~= false
			if gate_a_present then text(row.gate_ref_a, label .. " gate_ref_a") end
			if gate_b_present then text(row.gate_ref_b, label .. " gate_ref_b") end
			result[index] = record("grug_wp40_land_route_v1", row.id, row.numeric_id, {
				text = {boundary_id = row.boundary_id,
					boundary_interface_id = row.boundary_interface_id,
					class = row.class, endpoint_a_id = row.endpoint_a_id,
					endpoint_b_id = row.endpoint_b_id,
					gate_ref_a = gate_a_present and row.gate_ref_a or "",
					gate_ref_b = gate_b_present and row.gate_ref_b or "",
					grade_phase = row.grade_phase, station_a_id = row.station_a_id,
					station_b_id = row.station_b_id, zone_a = row.zone_a,
					zone_b = row.zone_b},
				unsigned = {crossing_station = row.crossing_station},
				boolean = {gate_ref_a_present = gate_a_present,
					gate_ref_b_present = gate_b_present},
				signed_arrays = {centreline_xz = centreline_xz},
			})
		end
		return result
	end

	local function compile_boat_routes()
		local result = {}
		for index = 1, #source.boat_edges do
			local row = source.boat_edges[index]
			local label = "Source boat route[" .. index .. "]"
			exact_fields(row, BOAT_FIELDS, label)
			integer(row.numeric_id, 1, 4, label .. " numeric_id")
			if row.numeric_id ~= index then fail(label .. " numeric identity changed") end
			for _, field in ipairs({"id", "from_zone", "landing_id", "to_zone"}) do
				text(row[field], label .. " " .. field)
			end
			integer(row.approach_z, -2147483648, 2147483647,
				label .. " approach_z")
			integer(row.width, 0, 4294967295, label .. " width")
			result[index] = record("grug_wp40_boat_route_v1", row.id,
				row.numeric_id, {text = {from_zone = row.from_zone,
					landing_id = row.landing_id, to_zone = row.to_zone},
					signed = {approach_z = row.approach_z},
					unsigned = {width = row.width}})
		end
		return result
	end

	local function compile()
		-- Stage 1 owns world semantics and checksum closure.  Package-local shape
		-- checks run only after that authority has accepted the complete Source.
		check_source_authority()
		check_relevant_source()
		return {families = {zones = compile_zones(),
			land_routes = compile_land_routes(),
			boat_routes = compile_boat_routes()}}
	end

	authored.compile = compile
	return authored
end
