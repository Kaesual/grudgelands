-- The six capitals as the R7 seam sees them (Round 22 capital planner, plan
-- D60, D69, D70, D72): a SOURCE declaring three kinds of blueprint
-- (`r7_settlement.lua`, contract section 2.2.3):
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start, unchanged;
--   * the district plots, each placed by this world's capital layout
--     (`capital_planner.lua`): an offset from the anchor, quarter turns so its
--     entry faces its street, and a base height;
--   * ONE overlay, the city edge on the planner's outline (`wp13/city_edge.
--     lua`): the stone curtain or the palisade in the race's style, with a
--     gatehouse at each of the four gates.
--
-- The streets, lanes and connectors are not blueprints: they are road-module
-- roads in the road layout (`height.lua` add_roads), rastered like every road.
--
-- `M.kit(key)` is the plan-independent part (the core and the district plot
-- rosters in a fixed order); `M.source(key, layout)` the source of one world,
-- built from the DESERIALIZED capital layout in main and emerge alike.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local info = debug and debug.getinfo and debug.getinfo(1, "S")
local here = type(info) == "table" and type(info.source) == "string" and
	info.source:sub(1, 1) == "@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not here or here == "" then here = core.get_modpath("grug_mapgen") .. "/wp40" end

local library = dofile(here .. "/r7_wp13_library.lua")
local planner = dofile(here .. "/capital_planner.lua")

local M = {}

-- Per capital: the composition and district roster in the WP13 library, the
-- race (palettes, road materials, the edge's style) and the edge kind, a key
-- of `capital_planner.lua` M.EDGE (D69: stone curtain for Highcourt, Dur
-- Brannoc and Nhal Veyr, the palisade for Gor Drazhak; Round 23: Lethariel's
-- light curtain and Kezamba's timber palisade on the narrow footprint their
-- planted belts had). `pin` names the district that stays beside the
-- capital's civic lake (D72), `lake` that lake's authored water row, `canal`
-- the one-level quay canal (Highcourt, D58).
M.CAPITALS = {
	highcourt = {race = "human", edge = "stone", canal = true},
	dur_brannoc = {race = "dwarf", edge = "stone"},
	lethariel = {race = "elf", edge = "stone_narrow", lake = "lethariel_crown_lake", pin = "mere"},
	nhal_veyr = {race = "undead", edge = "stone"},
	gor_drazhak = {race = "orc", edge = "palisade"},
	kezamba = {race = "troll", edge = "palisade_narrow", lake = "kezamba_cenote", pin = "shore"},
}

-- The plan-independent kit of a capital: the core blueprint and the plot
-- roster {id, district, role, kind ("plot" or "fill"), schema, build}, in the
-- districts' fixed order.
function M.kit(key)
	local cfg = M.CAPITALS[key]
	if not cfg then error("WP13 capital source: unknown capital " .. tostring(key), 0) end
	local path = library.path()
	local composition = library.composition(key)
	if type(composition) ~= "table" or type(composition.core) ~= "function" then
		error("WP13 capital source: the " .. key .. " composition seam differs", 0)
	end
	local districts = dofile(path .. "/" .. key .. "_districts.lua")(path)
	local plots = {}
	for _, plot in ipairs(districts.plots()) do
		plots[#plots + 1] = {id = plot.id, district = plot.district, role = plot.role,
			kind = plot.kind,
			schema = "grug_wp13_" .. key .. "_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end
	return {core = {schema = "grug_wp13_" .. key .. "_core_v1", build = composition.core},
		plots = plots, cfg = cfg}
end

-- The edge's own payload lines (kind, gates, wall points, turrets): the part
-- of the layout the city edge overlay is a function of, and its identity.
local function edge_spec(text)
	local lines = {}
	for line in text:gmatch("[^\n]+") do
		local tag = line:sub(1, 2)
		if tag == "k " or tag == "g " or tag == "w " or tag == "t " then
			lines[#lines + 1] = line
		end
	end
	return table.concat(lines, "\n") .. "\n"
end

-- The capital source of one world. `layout` is the capital's deserialized
-- layout (`capital_planner.deserialize`) and `text` its payload text.
function M.source(key, layout, text, kit)
	kit = kit or M.kit(key)
	local cfg = kit.cfg
	if layout.kind ~= cfg.edge then
		error("WP13 capital source: " .. key .. " edge kind differs", 0)
	end
	local by_id = {}
	for _, plot in ipairs(kit.plots) do by_id[plot.id] = plot end
	local plots = {}
	for index, placed in ipairs(layout.plots) do
		local plot = by_id[placed.id]
		if not plot then
			error("WP13 capital source: " .. key .. " layout names an unknown plot " ..
				placed.id, 0)
		end
		plots[index] = {id = plot.id, x = placed.x, z = placed.z,
			turns = placed.turns, y = placed.y, schema = plot.schema,
			build = plot.build}
	end
	local path = library.path()
	local city_edge = dofile(path .. "/city_edge.lua")(path)
	-- The overlay's names are the edge's plus what the plot collars and
	-- approaches write (`r7_settlement.lua`, `wp13/plot_approach.lua`): the
	-- race's ground, subsoil, path paving and stair. They reach the shared
	-- settlement palette through this list, whichever plots a world places.
	local dims = planner.EDGE[cfg.edge]
	local names = {}
	do
		local palettes = dofile(path .. "/palette.lua")
		local parts = dofile(path .. "/parts.lua")
		local p = palettes.new(cfg.race)
		local seen = {}
		local list = city_edge.names(cfg.race, dims.model)
		for _, name in ipairs({p.node("ground"), p.node("subsoil"),
				p.maybe("castle_paving") or p.node("plaza"),
				p.maybe("castle_wall_stair") or p.node("roof_stair")}) do
			list[#list + 1] = name
		end
		for _, name in ipairs(list) do
			if not seen[name] then seen[name] = true; names[#names + 1] = name end
		end
		table.sort(names, parts.less_bytes)
	end
	-- the reach of the edge: every wall point, gate box and turret disc
	local extra = math.max(dims.depth, dims.width, dims.turret or 0) + dims.half + 2
	local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
	local function stretch(x, z)
		if x < min_x then min_x = x end
		if x > max_x then max_x = x end
		if z < min_z then min_z = z end
		if z > max_z then max_z = z end
	end
	for _, p in ipairs(layout.wall.pts) do stretch(p[1], p[2]) end
	for c = 1, 4 do stretch(layout.gates[c].x, layout.gates[c].z) end
	-- the heights the edge stands between (full-world preparation bounds):
	-- piers, piles and footings reach down to the ground or a river bed
	-- below the walk (no wall stands in a civic lake), gatehouses, turrets,
	-- merlons and turret lamps rise at most 8 above the highest walk or 13
	-- above a gate floor
	local y_low, y_high = math.huge, -math.huge
	for _, w in ipairs(layout.wall.walk) do
		y_low, y_high = math.min(y_low, w / 2), math.max(y_high, w / 2)
	end
	for c = 1, 4 do
		y_low = math.min(y_low, layout.gates[c].y)
		y_high = math.max(y_high, layout.gates[c].y + 9)
	end
	return {
		schema = "grug_wp13_capital_source_v1",
		core = kit.core,
		plots = plots,
		overlay = {
			schema = "grug_wp13_" .. key .. "_city_v1",
			spec = edge_spec(text),
			count = #layout.wall.pts,
			reach = {min_x = math.floor(min_x - extra), max_x = math.ceil(max_x + extra),
				min_z = math.floor(min_z - extra), max_z = math.ceil(max_z + extra)},
			y_min = math.floor(y_low) - 24, y_max = math.ceil(y_high) + 8,
			names = names,
			make = function(anchor)
				return city_edge.new(cfg.race, dims.model, layout, dims, anchor)
			end,
		},
	}
end

return M
