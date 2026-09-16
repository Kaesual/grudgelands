-- Every cell of a capital's whole curtain wall, out of the real WP40 height
-- session, as text -- so two trees can be diffed cell for cell.
--
--     luajit wall_cells.lua <repo> <seed> <key> <out.tsv>
--
-- The four runs are built whole (not per mapchunk) through `wall.run` with the
-- capital's own `wall_plan`, over the same surface `r7_settlement.lua` hands the
-- overlay in the engine: the walkable height of a column, which is the ground
-- or the water standing on it.
local repo = assert(arg[1])
local seed = assert(arg[2])
local key = assert(arg[3])
local out_path = assert(arg[4])

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = schemas, canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local wall = dofile(wp13 .. "/wall.lua")(wp13)
local capital = dofile(wp13 .. "/" .. key .. ".lua")(wp13)
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)

-- The anchor and the race, out of the roster the WP40 source publishes.
local anchor_x, anchor_z, race
for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	if anchor.slot_id == "capital" then
		local zone = source.zones[anchor.zone_numeric_id]
		if zone.id:match("_" .. key .. "$") then
			anchor_x, anchor_z = anchor.position.x, anchor.position.z
			race = zone.race_region
		end
	end
end
assert(anchor_x, "no capital anchor for " .. key)
local palette = palettes.new(race)

local function walkable(x, z)
	local terrain_y = height.terrain_height_at(anchor_x + x, anchor_z + z)
	local water_y = height.water_surface_at(anchor_x + x, anchor_z + z)
	if type(water_y) == "number" and water_y > terrain_y then return water_y end
	return terrain_y
end

local rows = {("# %s curtain, seed %s, anchor %d,%d, anchor-relative\n")
	:format(key, seed, anchor_x, anchor_z)}
local total, corners = 0, 0
for _, spec in ipairs(capital.wall) do
	local plan = assert(capital.wall_plan[spec.id])
	local piece = wall.run(palette, {id = spec.id, axis = spec.axis,
		at = spec.at, from = spec.from, to = spec.to, width = avenue.WIDTH,
		lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.from,
		reach = avenue.REACH}, walkable, plan)
	corners = corners + (piece.corners or 0)
	local cells = piece.cells
	table.sort(cells, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		if a.z ~= b.z then return a.z < b.z end
		if a.y ~= b.y then return a.y < b.y end
		return a.name < b.name
	end)
	for index = 1, #cells do
		local cell = cells[index]
		rows[#rows + 1] = table.concat({spec.id, cell.x, cell.y, cell.z,
			cell.name, cell.param2 or 0}, "\t") .. "\n"
	end
	total = total + #cells
end
local file = assert(io.open(out_path, "wb"))
file:write(table.concat(rows))
assert(file:close())
io.write(("%s seed=%s cells=%d corners=%d\n"):format(key, seed, total, corners))
