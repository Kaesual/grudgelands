-- Round 51 lane LG portable test (LuaJIT or plain Lua 5.1): the land grounds
-- and nodes on the real default, grug_trees, grug_materials and grug_nodes
-- sources, through the Round 24 mining harness (tools/r24_mining/fixture.lua):
--   A. tiles: every 32 px ground face is {name, align_style = "world",
--      scale = 2} on the faces the rulings name, every 16 px face a plain
--      tile; every file exists with its size (32 or 16 square) and is the
--      picked art byte for byte (tools/r51_land);
--   B. the swamp moss: the moss soil's groups and sounds, drops mud, and is
--      in every non-mapgen host list (gathering catalog, natural ground
--      list, the three swamp mobs, the spawn-region ground, the root ground);
--   C. the clay bands: mesa clay's groups, drop mesa clay, natural ground;
--   D. the sand: default:sand and both rooted sand beds wear the 32 px sand,
--      and no registered node keeps default_sand.png;
--   E. hanging moss: the strand/end dig rule on a fake world (the end dug:
--      the strand above becomes the end, and on up; a middle piece dug: the
--      piece above becomes the end, the pieces below fall away, a protected
--      one stays), through the real nodes' after_dig_node; both decay with
--      gravewood; the world's swamp variants write strands above one end;
--   F. the closed node roster: 129 rows (T4 adds the ice) with LG's six and
--      their roles.
--
-- Usage (repo root): luajit tools/r51_lg/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local nodes, core = H.nodes, H.core
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

local function read(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local data = handle:read("*a")
	handle:close()
	return data
end
local function png_size(data)
	local function u32(at)
		local a, b, c, d = data:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end

-- A. tiles -------------------------------------------------------------------
local NODES_TEX = repo .. "/mods/ITEMS/grug_nodes/textures/"
local TREES_TEX = repo .. "/mods/ITEMS/grug_trees/textures/"
local ART = repo .. "/tools/r51_land/"
-- Every shipped file of the lane and the picked art it copies.
local COPIES = {
	{NODES_TEX .. "grug_nodes_wet_grass_top.png", "swamp/wet_grass_top_calm32.png", 32},
	{NODES_TEX .. "grug_nodes_wet_grass_side.png", "swamp/wet_grass_side_calm.png", 16},
	{NODES_TEX .. "grug_nodes_mud_mottled_top.png", "swamp/mud_mottled_top_calm32.png", 32},
	{NODES_TEX .. "grug_nodes_mud_mottled_side.png", "swamp/mud_mottled_side_calm.png", 16},
	{NODES_TEX .. "grug_nodes_mud.png", "swamp/mud_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_mud_dry_top.png", "swamp/mud_dry_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_moss_soil_top.png", "swamp/moss_soil_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_moss_soil_side.png", "swamp/moss_soil_side.png", 16},
	{NODES_TEX .. "grug_nodes_swamp_moss_top.png", "grounds/swamp_moss_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_swamp_moss_side.png", "grounds/swamp_moss_side.png", 16},
	{NODES_TEX .. "grug_nodes_silver_litter.png", "grounds/silver_litter_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_blight_dirt.png", "grounds/blight_dirt_32.png", 32},
	{NODES_TEX .. "grug_nodes_bone_litter.png", "grounds/bone_litter_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_mesa_clay.png", "grounds/mesa_clay_32.png", 32},
	{NODES_TEX .. "grug_nodes_canopy_litter.png", "grounds/canopy_litter_top_32.png", 32},
	{NODES_TEX .. "grug_nodes_clay_band_ochre.png", "grounds/clay_band_ochre_32.png", 32},
	{NODES_TEX .. "grug_nodes_clay_band_sienna.png", "grounds/clay_band_sienna_32.png", 32},
	{NODES_TEX .. "grug_nodes_clay_band_chalk.png", "grounds/clay_band_chalk_32.png", 32},
	{NODES_TEX .. "grug_nodes_clay_band_umber.png", "grounds/clay_band_umber_32.png", 32},
	{NODES_TEX .. "grug_nodes_sand.png", "grounds/sand_32.png", 32},
	{TREES_TEX .. "grug_trees_swamp_hanging_moss_strand.png", "swamp/hanging_moss_strand.png", 16},
}
local SIZE = {}
for _, row in ipairs(COPIES) do
	local shipped, art = read(row[1]), read(ART .. row[2])
	if check(shipped ~= nil and art ~= nil, row[1] .. " and its art exist") then
		check(shipped == art, row[1] .. " is " .. row[2] .. " byte for byte")
		local w, h = png_size(shipped)
		check(w == row[3] and h == row[3], row[1] .. " is " .. row[3] .. " px square")
	end
	SIZE[row[1]:match("([%w_]+%.png)$")] = row[3]
end

-- W(file) is a 32 px world-aligned face, P(file) a plain 16 px face.
local function W(file) return {world = file} end
local function P(file) return {plain = file} end
local DIRT = "default_dirt.png"
-- Expected tiles per node: top, bottom, side (a shorter list repeats its last).
local TILES = {
	["grug_nodes:dirt_with_silver_litter"] = {W("grug_nodes_silver_litter.png"), P(DIRT),
		P(DIRT .. "^grug_nodes_silver_litter_side.png")},
	["grug_nodes:dirt_with_bone_litter"] = {W("grug_nodes_bone_litter.png"), P(DIRT),
		P(DIRT .. "^grug_nodes_bone_litter_side.png")},
	["grug_nodes:dirt_with_canopy_litter"] = {W("grug_nodes_canopy_litter.png"), P(DIRT),
		P(DIRT .. "^grug_nodes_canopy_litter_side.png")},
	["grug_nodes:dirt_with_forest_litter"] = {P("grug_nodes_forest_litter.png"), P(DIRT),
		P(DIRT .. "^grug_nodes_forest_litter_side.png")},
	["grug_nodes:blight_dirt"] = {W("grug_nodes_blight_dirt.png")},
	["grug_nodes:mesa_clay"] = {W("grug_nodes_mesa_clay.png")},
	["grug_nodes:mud"] = {W("grug_nodes_mud.png")},
	["grug_nodes:mud_dry"] = {W("grug_nodes_mud_dry_top.png"), P("grug_nodes_mud_dry_side.png"),
		P("grug_nodes_mud_dry_side.png")},
	["grug_nodes:mud_mottled"] = {W("grug_nodes_mud_mottled_top.png"),
		P("grug_nodes_mud_mottled_side.png"), P("grug_nodes_mud_mottled_side.png")},
	["grug_nodes:mud_with_wet_grass"] = {W("grug_nodes_wet_grass_top.png"),
		P("grug_nodes_mud_mottled_side.png"), P("grug_nodes_wet_grass_side.png")},
	["grug_nodes:dirt_with_moss"] = {W("grug_nodes_moss_soil_top.png"), P(DIRT),
		P("grug_nodes_moss_soil_side.png")},
	["grug_nodes:swamp_moss"] = {W("grug_nodes_swamp_moss_top.png"), W("grug_nodes_mud.png"),
		P("grug_nodes_swamp_moss_side.png")},
	["grug_nodes:mud_with_reeds"] = {W("grug_nodes_mud.png")},
	["default:sand"] = {W("grug_nodes_sand.png")},
	["default:sand_with_kelp"] = {W("grug_nodes_sand.png")},
}
local CLAY = {"ochre", "sienna", "chalk", "umber"}
for _, colour in ipairs(CLAY) do
	TILES["grug_nodes:clay_band_" .. colour] = {W("grug_nodes_clay_band_" .. colour .. ".png")}
end
local function exists(file)
	for _, dir in ipairs({NODES_TEX, TREES_TEX, repo .. "/mods/BASE/default/textures/"}) do
		if read(dir .. file) then return true end
	end
	return false
end
for name, want in pairs(TILES) do
	local def = nodes[name]
	if check(def ~= nil, name .. " is registered") then
		check(#def.tiles == #want, name .. " has " .. #want .. " tiles")
		for face, spec in ipairs(want) do
			local tile = def.tiles[face]
			if spec.world then
				check(type(tile) == "table" and tile.name == spec.world and tile.align_style == "world" and
					tile.scale == 2, name .. " face " .. face .. " is " .. spec.world .. ", world-aligned, scale 2")
				check(SIZE[spec.world] == 32, spec.world .. " is a 32 px file of the lane")
			else
				local file = type(tile) == "table" and tile.name or tile
				check(file == spec.plain and (type(tile) ~= "table" or tile.align_style == nil),
					name .. " face " .. face .. " is the plain " .. spec.plain)
				for part in spec.plain:gmatch("([%w_]+%.png)") do
					check(exists(part), part .. " exists")
					if SIZE[part] then check(SIZE[part] == 16, part .. " is 16 px") end
				end
			end
		end
	end
end
-- The whole sides (no overlay over dirt) do not repeat vertically.
for _, name in ipairs({"grug_nodes:dirt_with_moss", "grug_nodes:swamp_moss",
		"grug_nodes:mud_with_wet_grass"}) do
	check(nodes[name].tiles[3].tileable_vertical == false, name .. "'s side does not tile vertically")
end
-- The freshwater waterweed (grug_mapgen, loaded by the engine only) binds
-- the same sand tile; its source is read.
local world_nodes = read(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")
check(world_nodes:find('tiles={{name="grug_nodes_sand.png",align_style="world",scale=2}}', 1, true) ~= nil,
	"the freshwater waterweed's bed is the world-aligned sand")
for name, def in pairs(nodes) do
	for _, tile in ipairs(def.tiles or {}) do
		local file = type(tile) == "table" and tile.name or tile
		check(type(file) ~= "string" or not file:find("default_sand.png", 1, true),
			name .. " does not keep default_sand.png")
	end
end

-- B. the swamp moss -----------------------------------------------------------
local moss, soil = nodes["grug_nodes:swamp_moss"], nodes["grug_nodes:dirt_with_moss"]
local function same_groups(a, b)
	for k, v in pairs(a) do if b[k] ~= v then return false end end
	for k, v in pairs(b) do if a[k] ~= v then return false end end
	return true
end
check(same_groups(moss.groups, soil.groups), "the swamp moss has the moss soil's groups")
check(moss.groups.soil == 1 and moss.groups.grug_natural == 1 and moss.groups.mud == nil,
	"the swamp moss is soil, natural ground, no mud marker")
check(moss.drop == "grug_nodes:mud", "the swamp moss drops mud")
check(moss.sounds.footstep.name == soil.sounds.footstep.name and
	moss.sounds.dug.name == soil.sounds.dug.name, "the swamp moss sounds like the moss soil")
local function time(name, item)
	local caps = ItemStack(item):get_tool_capabilities()
	local params = H.get_dig_params(nodes[name].groups, caps)
	if not params.diggable then params = H.get_dig_params(nodes[name].groups, ItemStack(""):get_tool_capabilities()) end
	return params.diggable and params.time or -1
end
for _, item in ipairs({"", "grug_materials:shovel_bronze", "grug_materials:pick_bronze"}) do
	check(time("grug_nodes:swamp_moss", item) == time("grug_nodes:dirt_with_moss", item) and
		time("grug_nodes:swamp_moss", item) >= 0, "the swamp moss digs like the moss soil with " .. item)
	for _, colour in ipairs(CLAY) do
		check(time("grug_nodes:clay_band_" .. colour, item) == time("grug_nodes:mesa_clay", item),
			colour .. " clay band digs like mesa clay with " .. item)
	end
end
-- the host lists
local function contains(list, value)
	for _, v in ipairs(list) do if v == value then return true end end
	return false
end
local M = grug_materials
check(contains(M.NATURAL_GROUND_NODES, "grug_nodes:swamp_moss"), "the swamp moss is natural ground")
local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
local with_soil, with_moss = 0, 0
for _, source in ipairs(catalog.p9g_sources()) do
	local soil_host, moss_host = false, false
	for _, host in ipairs(source.hosts or {}) do
		if host.biome == "grug_swamp" and host.support == "grug_nodes:dirt_with_moss" then soil_host = true end
		if host.biome == "grug_swamp" and host.support == "grug_nodes:swamp_moss" then moss_host = true end
	end
	if soil_host then with_soil = with_soil + 1 end
	if moss_host then with_moss = with_moss + 1 end
	check(soil_host == moss_host, source.id .. ": the swamp moss hosts where the moss soil does in the swamp")
end
check(with_soil > 0 and with_moss == with_soil, "gathering sources host on the swamp moss (" .. with_moss .. ")")
-- the swamp mobs: the spawn list naming the moss soil names the swamp moss
for _, file in ipairs({"bog_ooze", "bog_fowl", "crocodile"}) do
	local source = read(repo .. "/mods/ENTITIES/grug_mobs/" .. file .. ".lua")
	local list = source:match('nodes = (%b{})[^\n]*grug_swamp')
	check(list ~= nil and list:find('"grug_nodes:dirt_with_moss"', 1, true) and
		list:find('"grug_nodes:swamp_moss"', 1, true), file .. "'s swamp spawn takes the swamp moss")
end
local regions = read(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions.lua")
local ground = regions:match("local GROUND = (%b{})")
check(ground ~= nil and ground:find('"grug_nodes:swamp_moss"', 1, true), "spawn regions set mobs on the swamp moss")
for _, colour in ipairs(CLAY) do
	check(ground:find('"grug_nodes:clay_band_' .. colour .. '"', 1, true), "spawn regions take the " .. colour .. " band")
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local trees = dofile(wp40 .. "/tree_templates.lua")(dofile(wp40 .. "/treegen.lua"))
check(contains(trees.ROOT_GROUND, "grug_nodes:swamp_moss"), "roots stand in the swamp moss")

-- C. the clay bands ------------------------------------------------------------
local mesa = nodes["grug_nodes:mesa_clay"]
for _, colour in ipairs(CLAY) do
	local name = "grug_nodes:clay_band_" .. colour
	local def = nodes[name]
	check(same_groups(def.groups, mesa.groups), name .. " has mesa clay's groups")
	check(def.drop == "grug_nodes:mesa_clay", name .. " drops mesa clay")
	check(contains(M.NATURAL_GROUND_NODES, name), name .. " is natural ground")
	check((def.drawtype or "normal") == "normal" and def.is_ground_content ~= false, name .. " is a plain ground cube")
end

-- E. hanging moss ----------------------------------------------------------------
local STRAND, TIP = "grug_trees:swamp_hanging_moss_strand", "grug_trees:swamp_hanging_moss"
for _, name in ipairs({STRAND, TIP}) do
	local def = nodes[name]
	check(def.drawtype == "plantlike" and def.walkable == false and def.drop == "" and
		def.groups.leafdecay == 3 and type(def.on_timer) == "function",
		name .. ": plantlike, not walkable, drops nothing, decays with its tree")
	check(type(def.after_dig_node) == "function", name .. " keeps its run whole when dug")
end
check(nodes[STRAND].tiles[1] == "grug_trees_swamp_hanging_moss_strand.png", "the strand wears the picked strand")
check(nodes[TIP].tiles[1] == "grug_trees_swamp_hanging_moss.png", "the end keeps today's tapered moss")
check(grug_trees.hanging.pair(STRAND).tip == TIP and grug_trees.hanging.pair(TIP).strand == STRAND,
	"strand and end are one pair")

-- A fake world column: y 10 leaves, then the run downwards.
local world, protected = {}, {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local saved = {core.get_node, core.swap_node, core.remove_node, core.is_protected}
core.get_node = function(pos) return world[key(pos.x, pos.y, pos.z)] or {name = "air", param2 = 0} end
core.swap_node = function(pos, node) world[key(pos.x, pos.y, pos.z)] = {name = node.name, param2 = node.param2} end
core.remove_node = function(pos) world[key(pos.x, pos.y, pos.z)] = nil end
core.is_protected = function(pos) return protected[key(pos.x, pos.y, pos.z)] == true end
local digger = {get_player_name = function() return "tester" end}
local function column(n)
	world, protected = {}, {}
	world[key(0, 10, 0)] = {name = "grug_trees:swamp_leaves", param2 = 0}
	for i = 1, n do world[key(0, 10 - i, 0)] = {name = i == n and TIP or STRAND, param2 = 7} end
end
local function at(y) return (world[key(0, y, 0)] or {name = "air"}).name end
local function dig(y)
	local node = world[key(0, y, 0)]
	world[key(0, y, 0)] = nil
	nodes[node.name].after_dig_node({x = 0, y = y, z = 0}, node, nil, digger)
end
column(3) -- strand 9, strand 8, end 7
dig(7)
check(at(8) == TIP and at(9) == STRAND and at(7) == "air", "the end dug: the strand above is the new end")
check(world[key(0, 8, 0)].param2 == 7, "the new end keeps its param2")
dig(8)
check(at(9) == TIP and at(10) == "grug_trees:swamp_leaves", "and on up: the last strand becomes the end")
dig(9)
check(at(9) == "air" and at(10) == "grug_trees:swamp_leaves", "the last piece dug, the leaves stay")
column(4) -- strands 9, 8, 7, end 6
dig(8)
check(at(9) == TIP, "a middle piece dug: the piece above is the end")
check(at(7) == "air" and at(6) == "air", "the pieces below fall away")
column(4)
protected[key(0, 6, 0)] = true
dig(8)
check(at(7) == "air" and at(6) == TIP, "a protected piece below stays")
column(2)
world[key(0, 7, 0)] = {name = "default:dirt", param2 = 0}
dig(9)
check(at(8) == "air" and at(7) == "default:dirt", "the fall stops at the first other node")
column(2)
dig(9) -- a strand right below the leaves
check(at(8) == "air" and at(10) == "grug_trees:swamp_leaves", "the top piece dug takes the run, the leaves stay")
core.get_node, core.swap_node, core.remove_node, core.is_protected = saved[1], saved[2], saved[3], saved[4]

-- The world writes strands above one end: every swamp variant's moss runs.
check(contains(trees.names("swamp"), STRAND) and contains(trees.names("swamp"), TIP),
	"the swamp tree places the strand and the end")
local singles, strands, ends, ok = 0, 0, 0, true
for seed = 1, 64 do
	for _, cells in ipairs({(function()
		local v = trees.variant("swamp", seed)
		local list = {}
		for i = 1, v.count do list[i] = {x = v.x[i], y = v.y[i], z = v.z[i], name = v.name[i]} end
		return list
	end)(), (trees.tree("swamp", seed))}) do
		local by = {}
		for _, c in ipairs(cells) do by[key(c.x, c.y, c.z)] = c.name end
		for _, c in ipairs(cells) do
			local below = by[key(c.x, c.y - 1, c.z)]
			local above = by[key(c.x, c.y + 1, c.z)]
			if c.name == STRAND then
				strands = strands + 1
				if below ~= STRAND and below ~= TIP then ok = false end
			elseif c.name == TIP then
				ends = ends + 1
				if below == STRAND or below == TIP then ok = false end
				if above ~= STRAND then singles = singles + 1 end
			end
		end
	end
end
check(ok, "every moss run is strands above exactly one end (variants and grown trees)")
check(strands > 0 and ends > 0, "the swamp trees hang strands (" .. strands .. ") and ends (" .. ends .. ")")
for _, row in ipairs(trees.SPECIES) do
	if row.key ~= "swamp" then
		check(not contains(trees.names(row.key), STRAND), row.key .. " hangs no moss")
	end
end

-- F. the closed node roster ------------------------------------------------------
local content = read(wp40 .. "/r7_content.lua")
local roster = content:match("local ACCEPTED_R6_ROWS = (%b{})")
local rows, mask = 0, {}
for name, m in roster:gmatch('{"([^"]+)", (%d+)}') do
	rows = rows + 1
	mask[name] = tonumber(m)
end
check(rows == 129 and content:find("#ACCEPTED_R6_ROWS ~= 129", 1, true) ~= nil,
	"the roster holds 129 rows (Round 51 T4 adds the ice) and checks that count (" .. rows .. ")")
check(read(wp40 .. "/r7_p9g.lua"):find("#production.content_names ~= 129", 1, true) ~= nil,
	"the P9G successor checks the same count")
check(mask["grug_nodes:swamp_moss"] == 1, "the swamp moss is a surface row")
for _, colour in ipairs(CLAY) do
	check(mask["grug_nodes:clay_band_" .. colour] == 1, colour .. " band is a surface row")
end
check(mask[STRAND] == 8 and mask[TIP] == 8, "the strand is a decoration row like the end")

if failures > 0 then
	error(("%d FAILURES of %d checks"):format(failures, checks))
end
print(("PASS r51_lg: %d checks; 64 swamp seeds (variant and grown): %d moss runs, %d strands, %d one-node runs"):format(
	checks, ends, strands, singles))
