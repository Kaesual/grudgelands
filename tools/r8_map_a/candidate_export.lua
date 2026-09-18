-- LuaJIT-only candidate exporter for the bounded engine mouth measurement.
-- Usage: luajit candidate_export.lua ABS_ROOT SEED REVISION

local root, seed, revision = assert(arg[1]), assert(arg[2]), assert(arg[3])
assert(revision:match("^[0-9a-f]+$") or revision == "before",
	"revision differs")

local offline = dofile(root .. "/tools/wp40/r6/offline.lua")(root)
local loaded = offline.new_evidence(seed, false)
local _, cave_factory = dofile(root ..
	"/mods/MAPGEN/grug_mapgen/wp40/zones.lua")
local caves = cave_factory({full_seed_string = seed,
	column_values_at = loaded.planner_source.column_values_at,
	static_exclusion_values_at = loaded.horizontal.static_exclusion_values_at,
	housing_mask_id_at = loaded.horizontal.housing_mask_id_at})

local regions = {
	{id = "hearthpine_start_1000", min_x = -2300, max_x = -1301,
		min_z = -3050, max_z = -2051},
	{id = "lethariel_capital_1000", min_x = 1300, max_x = 2299,
		min_z = -2000, max_z = -1001},
}

local cell_size, cell_origin = 192, 0
if type(caves.constants) == "function" then
	cell_size, cell_origin = caves.constants()
end
local function first_cell(value)
	return math.floor((value - cell_origin) / cell_size)
end
local function lua_string(value)
	return string.format("%q", value)
end

local function owner_minimum(value)
	return -30912 + math.floor((value + 30912) / 80) * 80
end

-- Freeze the writer's horizontal eligibility inputs into the revision-bound
-- candidate record.  The engine checker therefore does not call the writer or
-- infer routes/housing from the carved result; it independently replays the
-- predicate from immutable offline bytes.
local function excluded_columns(row)
	local extent = (row.kind == "sinkhole" and
		(row.search_radius or row.radius) or row.length - 1) + row.radius
	local min_x, max_x = row.mouth_x - extent, row.mouth_x + extent
	local min_z, max_z = row.mouth_z - extent, row.mouth_z + extent
	if row.kind == "hillside" then
		local last_x = row.mouth_x + row.direction_x * (row.length - 1)
		local last_z = row.mouth_z + row.direction_z * (row.length - 1)
		min_x, max_x = math.min(row.mouth_x, last_x) - row.radius,
			math.max(row.mouth_x, last_x) + row.radius
		min_z, max_z = math.min(row.mouth_z, last_z) - row.radius,
			math.max(row.mouth_z, last_z) + row.radius
	end
	local excluded = {}
	for z = min_z, max_z do for x = min_x, max_x do
		local water_class, _, zone_id, biome, _, _, water_y, hydrology_id, _,
			functional_kind, _, _, _, transition_kind, _, _, _, _, _, hard =
				loaded.planner_source.column_values_at(x, z)
		local allowed = water_class == "land" and zone_id == row.zone_id and biome and
			water_y == nil and hydrology_id == nil and functional_kind == nil and
			transition_kind == nil and not hard and
			loaded.horizontal.static_exclusion_values_at(x, z) == nil and
			loaded.horizontal.housing_mask_id_at(x, z) == nil
		if not allowed then
			excluded[#excluded + 1] = (x - row.mouth_x) .. "/" ..
				(z - row.mouth_z)
		end
	end end
	return excluded
end

io.write("return {schema=\"grug_r8_map_a_engine_cases_v2\",revision=",
	lua_string(revision), ",seed=", lua_string(seed), ",regions={\n")
for region_index = 1, #regions do
	local region = regions[region_index]
	local records = {}
	for cell_z = first_cell(region.min_z), first_cell(region.max_z) do
		for cell_x = first_cell(region.min_x), first_cell(region.max_x) do
			local record = caves.candidate_record_at_cell(cell_x, cell_z)
			if record and record.mouth_x >= region.min_x and
					record.mouth_x <= region.max_x and record.mouth_z >= region.min_z and
					record.mouth_z <= region.max_z then
				records[#records + 1] = record
			end
		end
	end
	table.sort(records, function(a, b)
		if a.cell_z ~= b.cell_z then return a.cell_z < b.cell_z end
		return a.cell_x < b.cell_x
	end)
	io.write("{id=", lua_string(region.id), ",bounds={", region.min_x, ",",
		region.max_x, ",", region.min_z, ",", region.max_z, "},candidates={\n")
	for index = 1, #records do
		local row = records[index]
		local excluded = excluded_columns(row)
		io.write("{cell_x=", row.cell_x, ",cell_z=", row.cell_z,
			",zone_id=", lua_string(row.zone_id),
			",mouth_x=", row.mouth_x, ",mouth_y=", row.mouth_y,
			",mouth_z=", row.mouth_z, ",direction_x=", row.direction_x,
			",direction_z=", row.direction_z, ",length=", row.length,
			",radius=", row.radius, ",minimum_y=", row.minimum_y,
			",search_radius=", row.search_radius or row.radius,
			",maximum_depth=", row.maximum_depth or 12,
			",owner_min_x=", owner_minimum(row.mouth_x),
			",owner_min_y=", owner_minimum(row.mouth_y),
			",owner_min_z=", owner_minimum(row.mouth_z),
			",kind=", lua_string(row.kind or "hillside"), ",excluded={")
		for excluded_index = 1, #excluded do
			io.write(lua_string(excluded[excluded_index]), ",")
		end
		io.write("}},\n")
	end
	io.write("}},\n")
end
io.write("}}\n")
