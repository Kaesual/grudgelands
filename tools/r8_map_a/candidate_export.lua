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
		io.write("{cell_x=", row.cell_x, ",cell_z=", row.cell_z,
			",zone_id=", lua_string(row.zone_id),
			",mouth_x=", row.mouth_x, ",mouth_y=", row.mouth_y,
			",mouth_z=", row.mouth_z, ",direction_x=", row.direction_x,
			",direction_z=", row.direction_z, ",length=", row.length,
			",radius=", row.radius, ",minimum_y=", row.minimum_y,
			",search_radius=", row.search_radius or row.radius,
			",maximum_depth=", row.maximum_depth or 12,
			",kind=", lua_string(row.kind or "hillside"), "},\n")
	end
	io.write("}},\n")
end
io.write("}}\n")
