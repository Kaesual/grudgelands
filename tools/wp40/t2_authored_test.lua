local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local mode = arg[3] or "full"
assert(scratch:match("^/tmp/grudgelands%-wp40%-authored%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
assert(mode == "full" or mode == "kat" or mode == "emit", "invalid mode")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local compiled_schema = dofile(wp40 .. "/compiled_schema.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator = dofile(wp40 .. "/validation/t2_source.lua")
local vocabulary = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local new_authored = dofile(wp40 .. "/geometry/authored.lua")

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
	local execute_ok, execute_why, execute_code =
		os.execute("sha256sum " .. input .. " > " .. output)
	assert(execute_ok == 0 or execute_ok == true and execute_why == "exit" and
		execute_code == 0)
	file = assert(io.open(output, "rb"))
	local line = assert(file:read("*l"))
	assert(file:close())
	assert(os.remove(input))
	assert(os.remove(output))
	local digest = from_hex(assert(line:match("^([0-9a-f]+)")))
	assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

local function digest_node(node)
	return canonical.hex(canonical.checksum(node, raw_sha256))
end

local case_count = 0
local function check(condition, label)
	case_count = case_count + 1
	assert(case_count <= 201, "focused case count exceeded")
	assert(condition, label)
end

local function expect_error(fragment, callback)
	case_count = case_count + 1
	assert(case_count <= 201, "focused case count exceeded")
	local ok, message = pcall(callback)
	assert(not ok, "expected error containing " .. fragment)
	assert(tostring(message):find(fragment, 1, true), tostring(message))
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do
		result[deep_copy(key, seen)] = deep_copy(child, seen)
	end
	return result
end

local function deep_equal(a, b, seen)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	seen = seen or {}
	if seen[a] then return seen[a] == b end
	seen[a] = b
	for key, value in pairs(a) do
		if not deep_equal(value, b[key], seen) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

local source_tables = {}
local function mark_source_tables(value)
	if type(value) ~= "table" or source_tables[value] then return end
	source_tables[value] = true
	for key, child in pairs(value) do
		mark_source_tables(key)
		mark_source_tables(child)
	end
end
mark_source_tables(source)

local function check_output_graph(value, seen)
	local kind = type(value)
	assert(kind ~= "function" and kind ~= "userdata" and kind ~= "thread",
		"compiled output is not data-only")
	if kind ~= "table" then return end
	assert(getmetatable(value) == nil, "compiled output has a metatable")
	assert(not source_tables[value], "compiled output aliases Source")
	assert(not seen[value], "compiled output contains a cycle or mutable alias")
	seen[value] = true
	for key, child in pairs(value) do
		check_output_graph(key, seen)
		check_output_graph(child, seen)
	end
end

local function exact_keys(value, names)
	local expected = {}
	for index = 1, #names do expected[names[index]] = true end
	for key in pairs(value) do
		if type(key) ~= "string" or not expected[key] then return false end
	end
	for index = 1, #names do
		if value[names[index]] == nil then return false end
	end
	return true
end

local function exact_names(rows, names, value_field)
	if #rows ~= #names then return false end
	for index = 1, #names do
		local row = rows[index]
		if type(row) ~= "table" or getmetatable(row) ~= nil or
				row.name ~= names[index] or row[value_field] == nil then
			return false
		end
		local count = 0
		for key in pairs(row) do
			if key ~= "name" and key ~= value_field then return false end
			count = count + 1
		end
		if count ~= 2 then return false end
	end
	return true
end

local function named_value(record, bucket, name)
	for index = 1, #record[bucket] do
		local row = record[bucket][index]
		if row.name == name then return row.value end
	end
	error("missing named scalar " .. bucket .. ":" .. name)
end

local function named_values(record, bucket, name)
	for index = 1, #record[bucket] do
		local row = record[bucket][index]
		if row.name == name then return row.values end
	end
	error("missing named array " .. bucket .. ":" .. name)
end

local RECORD_FIELDS = {"attributes", "boolean_values", "candidates", "id",
	"numeric_id", "record_schema", "signed_arrays", "signed_values",
	"text_arrays", "text_values", "unsigned_arrays", "unsigned_values"}
local ZONE_ROSTER = {
	text_values = {"display_name", "faction", "primary_relief_id", "pvp_rule",
		"race_region", "territory_rule"},
	signed_values = {}, unsigned_values = {"level_max", "level_min"},
	boolean_values = {"civic_no_hostiles", "faction_present"},
	text_arrays = {"biome_ids"}, signed_arrays = {},
	unsigned_arrays = {"biome_shares"},
}
local LAND_ROUTE_ROSTER = {
	text_values = {"boundary_id", "boundary_interface_id", "class",
		"endpoint_a_id", "endpoint_b_id", "gate_ref_a", "gate_ref_b",
		"grade_phase", "station_a_id", "station_b_id", "zone_a", "zone_b"},
	signed_values = {}, unsigned_values = {"crossing_station"},
	boolean_values = {"gate_ref_a_present", "gate_ref_b_present"},
	text_arrays = {}, signed_arrays = {"centreline_xz"}, unsigned_arrays = {},
}
local BOAT_ROUTE_ROSTER = {
	text_values = {"from_zone", "landing_id", "to_zone"},
	signed_values = {"approach_z"}, unsigned_values = {"width"},
	boolean_values = {}, text_arrays = {}, signed_arrays = {},
	unsigned_arrays = {},
}
local BUCKETS = {"text_values", "signed_values", "unsigned_values",
	"boolean_values", "text_arrays", "signed_arrays", "unsigned_arrays"}

local accepting_validator = {validate = function() return true end}
local rejecting_validator = {validate = function()
	return nil, {invariant = "injected_stage1_failure", record_id = "source",
		expected = "accepted", observed = "rejected"}
end}

local function dependencies(source_value, validator)
	return {canonical = canonical, raw_sha256 = raw_sha256,
		source = source_value, source_validator = validator or source_validator,
		vocabulary = vocabulary}
end

local function compile(source_value, validator)
	local module = new_authored(dependencies(source_value, validator))
	check(exact_keys(module, {"compile"}), "authored API roster changed")
	return module.compile()
end

local source_before_compile = deep_copy(source)
local compiled = compile(source)
local families = compiled.families
check(deep_equal(source, source_before_compile), "D-1 mutated its Source input")
local graph_ok, graph_error = pcall(check_output_graph, compiled, {})
check(graph_ok, graph_error)
check(exact_keys(compiled, {"families"}), "compiled slice roster changed")
check(exact_keys(families, {"zones", "land_routes", "boat_routes"}),
	"compiled family roster changed")
check(families.island_routes == nil, "D-1 populated or exported island routes")
check(#families.zones == 38 and #families.land_routes == 57 and
	#families.boat_routes == 4, "compiled D-1 counts changed")

local class_counts = {primary = 0, secondary = 0, trail = 0}
for index = 1, #families.land_routes do
	local class = named_value(families.land_routes[index], "text_values", "class")
	class_counts[class] = assert(class_counts[class], "unknown route class") + 1
end
check(class_counts.primary == 30 and class_counts.secondary == 24 and
	class_counts.trail == 3, "compiled route class counts changed")

local record_count = 0
local function check_family_records(rows, schema, roster, id_prefix)
	for index = 1, #rows do
		local row = rows[index]
		record_count = record_count + 1
		assert(exact_keys(row, RECORD_FIELDS), "analytic record shape changed")
		assert(row.record_schema == schema, "analytic record schema changed")
		assert(row.numeric_id == index, "analytic numeric identity changed")
		if id_prefix then
			assert(row.id == (id_prefix .. "%03d"):format(index),
				"analytic string identity changed")
		end
		for _, bucket in ipairs(BUCKETS) do
			local value_field = bucket:find("arrays", 1, true) and "values" or "value"
			assert(exact_names(row[bucket], roster[bucket], value_field),
				bucket .. " roster changed")
		end
		assert(#row.candidates == 0 and next(row.attributes) == nil,
			"analytic record tail is not empty")
	end
end
check_family_records(families.zones, "grug_wp40_zone_v1", ZONE_ROSTER)
check_family_records(families.land_routes, "grug_wp40_land_route_v1",
	LAND_ROUTE_ROSTER, "route_")
check_family_records(families.boat_routes, "grug_wp40_boat_route_v1",
	BOAT_ROUTE_ROSTER)
check(record_count == 99, "focused record count changed")

local function reconstruct_zone(row)
	local ids = named_values(row, "text_arrays", "biome_ids")
	local shares = named_values(row, "unsigned_arrays", "biome_shares")
	assert(#ids == #shares)
	local biomes = {}
	for index = 1, #ids do biomes[index] = {id = ids[index], share = shares[index]} end
	local present = named_value(row, "boolean_values", "faction_present")
	local faction = named_value(row, "text_values", "faction")
	assert(present and faction ~= "" or not present and faction == "",
		"zone optional faction neutral representation changed")
	return {numeric_id = row.numeric_id, id = row.id,
		display_name = named_value(row, "text_values", "display_name"),
		race_region = named_value(row, "text_values", "race_region"),
		faction = present and faction or false,
		territory_rule = named_value(row, "text_values", "territory_rule"),
		pvp_rule = named_value(row, "text_values", "pvp_rule"),
		level_min = named_value(row, "unsigned_values", "level_min"),
		level_max = named_value(row, "unsigned_values", "level_max"),
		primary_relief_id = named_value(row, "text_values", "primary_relief_id"),
		biomes = biomes,
		civic_no_hostiles = named_value(row, "boolean_values",
			"civic_no_hostiles")}
end

local function reconstruct_land_route(row)
	local values = named_values(row, "signed_arrays", "centreline_xz")
	assert(#values % 2 == 0)
	local centreline = {}
	for index = 1, #values, 2 do
		centreline[#centreline + 1] = {x = values[index], z = values[index + 1]}
	end
	local gate_a_present = named_value(row, "boolean_values",
		"gate_ref_a_present")
	local gate_b_present = named_value(row, "boolean_values",
		"gate_ref_b_present")
	local gate_a = named_value(row, "text_values", "gate_ref_a")
	local gate_b = named_value(row, "text_values", "gate_ref_b")
	assert(gate_a_present and gate_a ~= "" or not gate_a_present and gate_a == "",
		"route optional gate A neutral representation changed")
	assert(gate_b_present and gate_b ~= "" or not gate_b_present and gate_b == "",
		"route optional gate B neutral representation changed")
	return {id = row.id, numeric_id = row.numeric_id,
		boundary_id = named_value(row, "text_values", "boundary_id"),
		zone_a = named_value(row, "text_values", "zone_a"),
		zone_b = named_value(row, "text_values", "zone_b"),
		class = named_value(row, "text_values", "class"), centreline = centreline,
		crossing_station = named_value(row, "unsigned_values", "crossing_station"),
		station_a_id = named_value(row, "text_values", "station_a_id"),
		station_b_id = named_value(row, "text_values", "station_b_id"),
		endpoint_a_id = named_value(row, "text_values", "endpoint_a_id"),
		endpoint_b_id = named_value(row, "text_values", "endpoint_b_id"),
		boundary_interface_id = named_value(row, "text_values",
			"boundary_interface_id"),
		grade_phase = named_value(row, "text_values", "grade_phase"),
		gate_ref_a = gate_a_present and gate_a or false,
		gate_ref_b = gate_b_present and gate_b or false}
end

local function reconstruct_boat_route(row)
	return {numeric_id = row.numeric_id, id = row.id,
		from_zone = named_value(row, "text_values", "from_zone"),
		to_zone = named_value(row, "text_values", "to_zone"),
		approach_z = named_value(row, "signed_values", "approach_z"),
		width = named_value(row, "unsigned_values", "width"),
		landing_id = named_value(row, "text_values", "landing_id")}
end

local function reconstruction_matches(compiled_rows, source_rows, reconstruct)
	for index = 1, #source_rows do
		if not deep_equal(reconstruct(compiled_rows[index]), source_rows[index]) then
			return false
		end
	end
	return true
end
check(reconstruction_matches(families.zones, source.zones, reconstruct_zone),
	"zone projection is not lossless")
check(reconstruction_matches(families.land_routes, source.routes,
	reconstruct_land_route), "land-route projection is not lossless")
check(reconstruction_matches(families.boat_routes, source.boat_edges,
	reconstruct_boat_route), "boat-route projection is not lossless")

local function expected_record(schema, id, numeric_id, fields)
	local function scalar_rows(names, values)
		local rows = {}
		for index = 1, #names do
			rows[index] = {name = names[index], value = values[index]}
		end
		return rows
	end
	local function array_rows(names, values)
		local rows = {}
		for index = 1, #names do
			rows[index] = {name = names[index], values = values[index]}
		end
		return rows
	end
	return {record_schema = schema, id = id, numeric_id = numeric_id,
		text_values = scalar_rows(fields.text_names or {}, fields.text or {}),
		signed_values = scalar_rows(fields.signed_names or {}, fields.signed or {}),
		unsigned_values = scalar_rows(fields.unsigned_names or {}, fields.unsigned or {}),
		boolean_values = scalar_rows(fields.boolean_names or {}, fields.boolean or {}),
		text_arrays = array_rows(fields.text_array_names or {}, fields.text_arrays or {}),
		signed_arrays = array_rows(fields.signed_array_names or {}, fields.signed_arrays or {}),
		unsigned_arrays = array_rows(fields.unsigned_array_names or {},
			fields.unsigned_arrays or {}), candidates = {}, attributes = {}}
end

local function zone_fixture(index, id, name, faction, relief, level_min,
		level_max, civic, biome_ids, biome_shares, race_region, territory, pvp)
	return expected_record("grug_wp40_zone_v1", id, index, {
		text_names = ZONE_ROSTER.text_values,
		text = {name, faction or "", relief, pvp, race_region, territory},
		unsigned_names = ZONE_ROSTER.unsigned_values,
		unsigned = {level_max, level_min},
		boolean_names = ZONE_ROSTER.boolean_values,
		boolean = {civic, faction ~= false},
		text_array_names = ZONE_ROSTER.text_arrays, text_arrays = {biome_ids},
		unsigned_array_names = ZONE_ROSTER.unsigned_arrays,
		unsigned_arrays = {biome_shares}})
end

local expected_zones = {
	zone_fixture(1, "elandor_hearthpine_vale", "Hearthpine Vale", "accord",
		"lowland", 1, 10, false, {"grug_pine_hills", "grug_crags"},
		{90, 10}, "dwarf", "accord_home", "peaceful"),
	zone_fixture(19, "kragmar_nhal_veyr", "Nhal Veyr", "throng", "plateau",
		20, 30, true, {"grug_blight", "grug_bone_forest"}, {75, 25},
		"undead", "throng_home", "peaceful"),
	zone_fixture(38, "front_stormscale_summit", "Stormscale Summit", false,
		"mountain", 60, 60, false, {"grug_deep_jungle", "grug_badlands_east",
			"grug_swamp", "grug_beach"}, {50, 20, 15, 15}, "troll",
		"contested_land", "contested"),
}
check(deep_equal(families.zones[1], expected_zones[1]) and
	deep_equal(families.zones[19], expected_zones[2]) and
	deep_equal(families.zones[38], expected_zones[3]),
	"first/middle/last complete zone fixtures changed")

local function route_fixture(index, boundary, zone_a, zone_b, class,
		centreline, station_a, station_b, gate_a, gate_b)
	local id = ("route_%03d"):format(index)
	return expected_record("grug_wp40_land_route_v1", id, index, {
		text_names = LAND_ROUTE_ROSTER.text_values,
		text = {boundary, id .. ":boundary_crossing", class,
			id .. ":endpoint_a", id .. ":endpoint_b", gate_a or "",
			gate_b or "", "class_default", station_a, station_b, zone_a, zone_b},
		unsigned_names = LAND_ROUTE_ROSTER.unsigned_values, unsigned = {3},
		boolean_names = LAND_ROUTE_ROSTER.boolean_values,
		boolean = {gate_a ~= false, gate_b ~= false},
		signed_array_names = LAND_ROUTE_ROSTER.signed_arrays,
		signed_arrays = {centreline}})
end
local expected_routes = {
	route_fixture(1, "land_001", "elandor_hearthpine_vale",
		"elandor_copperfell_foothills", "primary",
		{-1800,-2486,-1879,-2271,-1975,-2175,-2071,-2079,-1800,-2050},
		"station:elandor_hearthpine_vale:start_north",
		"station:elandor_copperfell_foothills:hub", "start:north", false),
	route_fixture(29, "land_029", "kragmar_whispering_reedlands",
		"kragmar_kezamba", "primary",
		{900,1500,1304,1500,1400,1500,1496,1500,1544,1500},
		"station:kragmar_whispering_reedlands:hub",
		"station:kragmar_kezamba:capital_west", false, "capital:west"),
	route_fixture(57, "land_057", "front_shattered_line",
		"front_skyglass_canopy", "trail",
		{750,0,1404,-125,1500,-125,1596,-125,2000,0},
		"station:front_shattered_line:hub",
		"station:front_skyglass_canopy:hub", false, false),
}
check(deep_equal(families.land_routes[1], expected_routes[1]) and
	deep_equal(families.land_routes[29], expected_routes[2]) and
	deep_equal(families.land_routes[57], expected_routes[3]),
	"first/middle/last complete land-route fixtures changed")

local expected_boats = {
	{"boat_wyrmglass_south", "front_gravesalt_escarpment",
		"wyrmglass_south_landing", "front_wyrmglass_crown", -125},
	{"boat_wyrmglass_north", "front_gravesalt_escarpment",
		"wyrmglass_north_landing", "front_wyrmglass_crown", 125},
	{"boat_stormscale_south", "front_skyglass_canopy",
		"stormscale_south_landing", "front_stormscale_summit", -125},
	{"boat_stormscale_north", "front_skyglass_canopy",
		"stormscale_north_landing", "front_stormscale_summit", 125},
}
for index = 1, #expected_boats do
	local row = expected_boats[index]
	local expected = expected_record("grug_wp40_boat_route_v1", row[1], index, {
		text_names = BOAT_ROUTE_ROSTER.text_values,
		text = {row[2], row[3], row[4]},
		signed_names = BOAT_ROUTE_ROSTER.signed_values, signed = {row[5]},
		unsigned_names = BOAT_ROUTE_ROSTER.unsigned_values, unsigned = {96}})
	check(deep_equal(families.boat_routes[index], expected),
		"complete boat-route fixture changed at " .. index)
end

local GEOMETRY_FAMILIES = {"zones", "land_boundaries", "land_routes",
	"boat_routes", "island_routes", "perimeters", "bays", "mouth_apertures",
	"closure_wings", "dry_faces", "relief_fields", "templates", "anchors",
	"route_profiles", "hydrology", "coast_shelf", "islands", "channels",
	"hard_protection", "claim_exclusions", "housing_masks"}
local function empty_record(id)
	return {record_schema = "grug_wp40_d1_shell_sentinel_v1", id = id,
		numeric_id = 0, text_values = {}, signed_values = {},
		unsigned_values = {}, boolean_values = {}, text_arrays = {},
		signed_arrays = {}, unsigned_arrays = {}, candidates = {}, attributes = {}}
end

local function shell_for(slice)
	local geometry = {}
	for index = 1, #GEOMETRY_FAMILIES do geometry[GEOMETRY_FAMILIES[index]] = {} end
	geometry.zones = slice.families.zones
	geometry.land_routes = slice.families.land_routes
	geometry.boat_routes = slice.families.boat_routes
	return {schema = schemas.compiled, algorithm_schema = schemas.compiled_algorithm,
		full_seed = "0", geometry = geometry,
		selectors = {logical_biomes = {}, nearest_features = {}, housing_centers = {}},
		spatial_index = {schema = schemas.index, cell_size = 128,
			min_cx = 0, max_cx = 0, min_cz = 0, max_cz = 0,
			layers = {}, candidates = {}, attributes = {}},
		coverage = {schema = schemas.coverage, geometry_volumes = {},
			resolver_interfaces = {}, pending = {t4 = {}, t6 = {}, t7 = {}}},
		release_fixtures = {seed_corpus = {}, extreme_slots = {},
			staging_seed = empty_record("staging_seed"),
			microcorpus_classes_1_9 = {},
			requester_trace = empty_record("requester_trace")}}
end

local function find_map_value(node, wanted)
	assert(node._wp40_type == "map")
	for index = 1, #node.value do
		local key, value = node.value[index][1], node.value[index][2]
		if key._wp40_type == "text" and key.value == wanted then return value end
	end
	error("canonical map key absent: " .. wanted)
end

local shell = shell_for(compiled)
check(#shell.geometry.island_routes == 0, "complete shell island family is not empty")
local shell_node = compiled_schema.canonicalize_compiled(shell, {}, canonical)
local data_node = find_map_value(shell_node, "data")
local geometry_node = find_map_value(data_node, "geometry")
local digests = {
	zones = digest_node(find_map_value(geometry_node, "zones")),
	land_routes = digest_node(find_map_value(geometry_node, "land_routes")),
	boat_routes = digest_node(find_map_value(geometry_node, "boat_routes")),
	shell = digest_node(shell_node),
}

local function roster_text(roster)
	local parts = {}
	for _, bucket in ipairs(BUCKETS) do
		parts[#parts + 1] = bucket .. "=" ..
			(#roster[bucket] == 0 and "-" or table.concat(roster[bucket], ","))
	end
	return table.concat(parts, "\t")
end

local fixture = table.concat({
	"schema\tgrug_wp40_t2_authored_fixture_v1",
	"source_sha256\t" .. source_validator.EXPECTED_SOURCE_CHECKSUM,
	"count\tzones\t38",
	"count\tland_routes\t57",
	"count\tboat_routes\t4",
	"route_classes\tprimary=30\tsecondary=24\ttrail=3",
	"record_schema\tzones\tgrug_wp40_zone_v1\t" .. roster_text(ZONE_ROSTER),
	"record_schema\tland_routes\tgrug_wp40_land_route_v1\t" ..
		roster_text(LAND_ROUTE_ROSTER),
	"record_schema\tboat_routes\tgrug_wp40_boat_route_v1\t" ..
		roster_text(BOAT_ROUTE_ROSTER),
	"representative\tzones\telandor_hearthpine_vale\tkragmar_nhal_veyr\tfront_stormscale_summit",
	"representative\tland_routes\troute_001\troute_029\troute_057",
	"representative\tboat_routes\tboat_wyrmglass_south\tboat_wyrmglass_north\tboat_stormscale_south\tboat_stormscale_north",
	"family_sha256\tzones\t" .. digests.zones,
	"family_sha256\tland_routes\t" .. digests.land_routes,
	"family_sha256\tboat_routes\t" .. digests.boat_routes,
	"complete_shell_sha256\t" .. digests.shell,
}, "\n") .. "\n"

if mode == "emit" then
	io.write(fixture)
	return
end

local fixture_path = repo .. "/tools/wp40/fixtures/t2_authored/digests-v1.tsv"
local fixture_file = assert(io.open(fixture_path, "rb"))
local expected_fixture = assert(fixture_file:read("*a"))
assert(fixture_file:close())
check(fixture == expected_fixture, "canonical authored fixture changed")

if mode == "full" then
	expect_error("unknown dependency", function()
		local invalid = dependencies(source)
		invalid.compiler = {}
		new_authored(invalid)
	end)

	local invalid = deep_copy(source)
	invalid.zones[1].display_name = nil
	expect_error("missing field display_name", function()
		compile(invalid, accepting_validator)
	end)
	invalid = deep_copy(source)
	invalid.zones[1].invented = true
	expect_error("unknown field invented", function()
		compile(invalid, accepting_validator)
	end)
	invalid = deep_copy(source)
	setmetatable(invalid.zones[1], {})
	expect_error("metatable", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[0] = invalid.routes[57]
	expect_error("not dense", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[1].centreline[2] = invalid.routes[1].centreline[1]
	expect_error("mutable alias", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[1].centreline[1] = invalid.routes[1]
	expect_error("cycle or mutable alias", function()
		compile(invalid, accepting_validator)
	end)
	invalid = deep_copy(source)
	invalid.zones[1].level_min = "1"
	expect_error("integer range", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.boat_edges[1].width = 4294967296
	expect_error("integer range", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[1], invalid.routes[2] = invalid.routes[2], invalid.routes[1]
	expect_error("numeric identity changed", function()
		compile(invalid, accepting_validator)
	end)
	invalid = deep_copy(source)
	invalid.routes[1].id = "route_002"
	expect_error("numeric identity changed", function()
		compile(invalid, accepting_validator)
	end)
	invalid = deep_copy(source)
	invalid.routes[1].gate_ref_a = 7
	expect_error("gate_ref_a", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[1].gate_ref_a = ""
	expect_error("non-empty text", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[57].boundary_id = "land_058"
	expect_error("boundary identity", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.routes[58] = deep_copy(source.island_routes[1])
	expect_error("count is not 57", function() compile(invalid, accepting_validator) end)
	invalid = deep_copy(source)
	invalid.zones = nil
	expect_error("injected_stage1_failure", function()
		compile(invalid, rejecting_validator)
	end)
	invalid = deep_copy(source)
	invalid.zones[1].display_name = "Hearthpine Vale altered"
	expect_error("exact_source_checksum", function() compile(invalid) end)
	local moved = compile(invalid, accepting_validator)
	local moved_node = compiled_schema.canonicalize_compiled(shell_for(moved), {},
		canonical)
	check(digest_node(moved_node) ~= digests.shell,
		"same-shape Source mutation did not move the shell digest")

	local broken_shell = deep_copy(shell)
	broken_shell.schema = "grug_wp40_compiled_world_v3"
	expect_error("compiled schema identity mismatch", function()
		compiled_schema.canonicalize_compiled(broken_shell, {}, canonical)
	end)
	broken_shell = deep_copy(shell)
	broken_shell.geometry.zones[1].unsigned_values[1].value = -1
	expect_error("unsigned", function()
		compiled_schema.canonicalize_compiled(broken_shell, {}, canonical)
	end)
	broken_shell = deep_copy(shell)
	broken_shell.geometry.zones[1].text_values[1],
		broken_shell.geometry.zones[1].text_values[2] =
		broken_shell.geometry.zones[1].text_values[2],
		broken_shell.geometry.zones[1].text_values[1]
	expect_error("names are not sorted unique", function()
		compiled_schema.canonicalize_compiled(broken_shell, {}, canonical)
	end)
	broken_shell = deep_copy(shell)
	broken_shell.geometry.zones[2].attributes =
		broken_shell.geometry.zones[1].attributes
	expect_error("cycle or mutable alias", function()
		compiled_schema.canonicalize_compiled(broken_shell, {}, canonical)
	end)
end

check(record_count + case_count <= 300,
	"focused record/case budget exceeded")
io.write(table.concat({"canonical", digests.zones, digests.land_routes,
	digests.boat_routes, digests.shell}, "\t") .. "\n")
io.write(("WP40 T2 authored %s passed records=%d cases=%d total=%d\n"):format(
	mode, record_count, case_count, record_count + case_count))
