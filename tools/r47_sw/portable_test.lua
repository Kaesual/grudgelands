-- Round 47 lane SW portable test (LuaJIT or plain Lua 5.1): the swamp nodes
-- of build step 1 (tools/r47_sw/DESIGN.md) on the real default, grug_trees,
-- grug_materials and grug_nodes sources, through the Round 24 mining harness
-- (tools/r24_mining/fixture.lua: a stub engine with Luanti's getDigParams):
--   A. every new node is registered with its drawtype and the fields the
--      design gives it (carpet box, rooted reeds leveled, liquids-safe
--      flags), and every texture it names exists in a mod's textures;
--   B. groups and drops: the mud variants and the wet grass are soil, mud,
--      natural loose ground and drop mud (lane TA's root ground list takes
--      every `soil` node); the plants are snappy and drop themselves; the
--      swamp leaves and the hanging moss drop nothing, like gravewood's
--      leaves; no new node is an attached_node = 4;
--   C. digging: hand and shovel need the same time as on mud for the three
--      grounds, the rooted reeds as on mud too, the plants as papyrus, the
--      swamp leaves and the moss as gravewood leaves;
--   D. leaf decay: digging a gravewood log starts the timers of gravewood
--      leaves, swamp leaves and hanging moss alike, and each of the three
--      decays when no gravewood log is within 3 and stays when one is.
-- Build step 2 (the swamp in the world):
--   E. the pool rule (wp40/swamp_pools.lua) on a synthetic planner source:
--      flat, gentle and steep swamp, a town (static exclusion), a lake, a
--      road, a surface cave and a coast. Pools lie on flat and gentle
--      ground, none on steep ground, none within the claim, the road, the
--      coast or the cave's 3 x 3, none within 2 of the lake; a kept column's
--      ground is its level or one above (at most one node levelled), its 5 x 5
--      window differs by at most 1; and on the final terrain (the pools
--      written) every water node has, on its four sides and below, ground or
--      water of its own level: no water can flow. The guard and the near
--      ring cover the pools.
--   F. the swamp pass (wp40/swamp_writer.lua) on a fake successor context:
--      water at the level, the top node of a column one above it removed,
--      a column with a log standing on it keeps its top and its mud (no
--      water hidden under it), plants only over air, lilies on water,
--      nothing outside the owner.
--
-- Usage (repo root): luajit tools/r47_sw/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local nodes = H.nodes
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end

local GROUNDS = {"grug_nodes:mud_dry", "grug_nodes:mud_mottled", "grug_nodes:mud_with_wet_grass"}
local PLANTS = {"grug_nodes:reeds", "grug_nodes:cattails", "grug_nodes:moss_carpet"}
local TREE = {"grug_trees:swamp_leaves", "grug_trees:swamp_hanging_moss"}
local ALL = {"grug_nodes:mud_with_reeds"}
for _, list in ipairs({GROUNDS, PLANTS, TREE}) do
	for _, name in ipairs(list) do ALL[#ALL + 1] = name end
end

-- A. registration and textures
local DRAW = {
	["grug_nodes:mud_dry"] = "normal", ["grug_nodes:mud_mottled"] = "normal",
	["grug_nodes:mud_with_wet_grass"] = "normal", ["grug_nodes:moss_carpet"] = "nodebox",
	["grug_nodes:reeds"] = "plantlike", ["grug_nodes:mud_with_reeds"] = "plantlike_rooted",
	["grug_nodes:cattails"] = "plantlike", ["grug_trees:swamp_leaves"] = "allfaces_optional",
	["grug_trees:swamp_hanging_moss"] = "plantlike",
}
local TEXTURE_DIRS = {}
for _, dir in ipairs({"mods/BASE/default/textures", "mods/ITEMS/grug_nodes/textures",
		"mods/ITEMS/grug_trees/textures"}) do
	TEXTURE_DIRS[#TEXTURE_DIRS + 1] = repo .. "/" .. dir .. "/"
end
local function exists(file)
	for _, dir in ipairs(TEXTURE_DIRS) do
		local handle = io.open(dir .. file, "rb")
		if handle then handle:close(); return true end
	end
	return false
end
local function textures_of(def)
	local list = {}
	local function add(tile)
		if type(tile) == "table" then tile = tile.name end
		if type(tile) == "string" then
			for file in tile:gmatch("([%w_]+%.png)") do list[#list + 1] = file end
		end
	end
	for _, tile in ipairs(def.tiles or {}) do add(tile) end
	for _, tile in ipairs(def.special_tiles or {}) do add(tile) end
	add(def.inventory_image); add(def.wield_image)
	return list
end
for _, name in ipairs(ALL) do
	local def = nodes[name]
	check(def ~= nil, name .. " is registered")
	if def then
		check((def.drawtype or "normal") == DRAW[name], name .. " drawtype " .. tostring(def.drawtype))
		local files = textures_of(def)
		check(#files > 0, name .. " names a texture")
		for _, file in ipairs(files) do check(exists(file), name .. " texture " .. file .. " exists") end
		check((def.groups.attached_node or 0) ~= 4, name .. " is no ceiling-attached node")
	end
end
local carpet = nodes["grug_nodes:moss_carpet"]
local box = carpet.node_box.fixed
check(box[2] == -0.5 and box[5] == -7 / 16, "the carpet is 1/16 high")
check(carpet.buildable_to == true and carpet.floodable == true and carpet.walkable == false and
	carpet.groups.attached_node == 3, "the carpet is buildable to, floodable, not walkable, attached below")
check(carpet.use_texture_alpha == "clip", "the carpet's gaps are see-through")
local rooted = nodes["grug_nodes:mud_with_reeds"]
check(rooted.paramtype2 == "leveled" and rooted.special_tiles[1].tileable_vertical == true,
	"rooted reeds: leveled height, the reed texture tiles up")
check(rooted.tiles[1] == "grug_nodes_mud.png", "rooted reeds stand in a mud bed")
check(nodes["grug_nodes:reeds"].after_dig_node ~= nil, "a reed takes the one above it")
for _, name in ipairs({"grug_nodes:reeds", "grug_nodes:cattails", "grug_trees:swamp_hanging_moss"}) do
	check(nodes[name].walkable == false and nodes[name].sunlight_propagates == true, name .. " lets you and light through")
end
local leaves = nodes["grug_trees:swamp_leaves"]
check(leaves.tiles[1] == "grug_trees_swamp_leaves.png", "swamp leaves wear lane ART's olive leaves")

-- B. groups and drops
local mud = nodes["grug_nodes:mud"]
for _, name in ipairs(GROUNDS) do
	local g = nodes[name].groups
	check(g.soil == 1 and g.mud == 1 and g.grug_natural == 1 and g.crumbly == mud.groups.crumbly and
		g.grug_loose == g.crumbly, name .. " has the mud's groups (soil: lane TA's root ground list)")
	check(nodes[name].drop == "grug_nodes:mud", name .. " drops mud")
end
check(rooted.drop == "grug_nodes:mud" and (rooted.groups.soil or 0) == 0, "the rooted bed drops mud and is no soil")
for _, name in ipairs(PLANTS) do
	check(nodes[name].drop == nil and nodes[name].groups.snappy == 3, name .. " is snappy and drops itself")
end
for _, name in ipairs(TREE) do
	check(nodes[name].drop == "" and nodes[name].drop == nodes["grug_trees:gravewood_leaves"].drop,
		name .. " drops what gravewood leaves drop (nothing)")
	check(nodes[name].groups.leafdecay == 3, name .. " is in the leaf decay group")
end

-- C. digging, by the hand and a shovel / an axe
local function caps(item) return ItemStack(item):get_tool_capabilities() end
local function time(name, item)
	local params = H.get_dig_params(nodes[name].groups, caps(item))
	if not params.diggable then params = H.get_dig_params(nodes[name].groups, caps("")) end
	return params.diggable and params.time or -1
end
local function same(a, b, item)
	check(time(a, item) == time(b, item) and time(a, item) >= 0,
		a .. " digs like " .. b .. " with " .. (item == "" and "the hand" or item))
end
for _, item in ipairs({"", "grug_materials:shovel_bronze"}) do
	for _, name in ipairs(GROUNDS) do same(name, "grug_nodes:mud", item) end
	same("grug_nodes:mud_with_reeds", "grug_nodes:mud", item)
end
for _, name in ipairs(PLANTS) do same(name, "default:papyrus", "") end
for _, name in ipairs(TREE) do same(name, "grug_trees:gravewood_leaves", "") end

-- D. leaf decay
local core = H.core
local found_area, timers = nil, {}
local saved = {core.find_nodes_in_area, core.get_node, core.get_node_timer, core.find_node_near,
	core.remove_node, core.add_item, core.check_for_falling, core.add_particlespawner, core.get_node_drops}
local world_node = "grug_trees:swamp_leaves"
core.find_nodes_in_area = function(_, _, names)
	found_area = names
	return {{x = 1, y = 1, z = 1}}
end
core.get_node = function() return {name = world_node, param2 = 0} end
core.get_node_timer = function(pos)
	return {is_started = function() return false end,
		start = function(_, t) timers[#timers + 1] = t end}
end
-- default's leaf decay subtracts a number from a position
local vadd, vsub = vector.add, vector.subtract
local function scalar(f)
	return function(a, b)
		if type(b) == "number" then b = {x = b, y = b, z = b} end
		return f(a, b)
	end
end
vector.add, vector.subtract = scalar(vadd), scalar(vsub)
local log = nodes["grug_trees:gravewood_tree"]
check(type(log.after_destruct) == "function", "a gravewood log starts leaf decay when it goes")
log.after_destruct({x = 0, y = 0, z = 0}, {name = "grug_trees:gravewood_tree"})
local listed = {}
for _, name in ipairs(found_area or {}) do listed[name] = true end
check(listed["grug_trees:gravewood_leaves"] and listed["grug_trees:swamp_leaves"] and
	listed["grug_trees:swamp_hanging_moss"], "digging a gravewood log wakes gravewood leaves, swamp leaves and moss")
check(#timers == 1, "the decay timer starts")
local near_names
local removed
core.remove_node = function() removed = true end
core.add_item = function() end
core.check_for_falling = function() end
core.add_particlespawner = function() end
core.get_node_drops = function() return {} end
for _, name in ipairs({"grug_trees:gravewood_leaves", "grug_trees:swamp_leaves", "grug_trees:swamp_hanging_moss"}) do
	world_node = name
	local on_timer = nodes[name].on_timer
	check(type(on_timer) == "function", name .. " has the decay timer")
	for _, wood_near in ipairs({true, false}) do
		removed = false
		core.find_node_near = function(_, radius, names)
			near_names = {radius = radius, names = names}
			return wood_near and {x = 0, y = 0, z = 0} or nil
		end
		on_timer({x = 1, y = 1, z = 1})
		check(removed == not wood_near, name .. (wood_near and " stays beside wood" or " decays without wood"))
		local trunk = false
		for _, n in ipairs(near_names.names) do if n == "grug_trees:gravewood_tree" then trunk = true end end
		check(trunk and near_names.radius == 3, name .. " looks for gravewood wood within 3")
	end
end
core.find_nodes_in_area, core.get_node, core.get_node_timer, core.find_node_near,
	core.remove_node, core.add_item, core.check_for_falling, core.add_particlespawner,
	core.get_node_drops = unpack(saved)
vector.add, vector.subtract = vadd, vsub

-- E. the pool rule on a synthetic world
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local pools_factory = dofile(wp40 .. "/swamp_pools.lua")
-- x < 0 flat (y 6), 0..89 a gentle slope (one up every 7), 90.. steep
-- (two up per node); the town is x -60..-40, z 0..20; the lake column at
-- (-20, 40); a road along z = -30; a surface cave at (-30, 60); the coast
-- at x -90 and below. Swamp everywhere but the town.
local function ground(x, z)
	if x < 0 then return 6 end
	if x < 90 then return 6 + math.floor(x / 7) end
	return 6 + math.floor(90 / 7) + 2 * (x - 89)
end
local function in_town(x, z) return x >= -60 and x <= -40 and z >= 0 and z <= 20 end
local planner = {}
function planner.column_values_at(x, z)
	local water_y = (x == -20 and z == 40) and ground(x, z) + 1 or nil
	return "land", 1, "zone", in_town(x, z) and "grug_meadows" or "grug_swamp", "race",
		ground(x, z) - (water_y and 1 or 0), water_y, water_y and "lake:1" or nil, nil,
		nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
end
function planner.overlay_exclusion_at(x, z) return z == -30 and "road_corridor" or nil end
function planner.static_exclusion_values_at(x, z)
	return in_town(x, z) and "exclude:anchor" or nil
end
function planner.surface_cave_run_at(x, z)
	if x == -30 and z == 60 then return 1, 4 end
	return nil
end
function planner.coast_material_at(x, z) return x <= -90 and "sand" or nil end
local pools = pools_factory("12345", planner)
local AREA = {min_x = -120, max_x = 140, min_z = -60, max_z = 100}
local final, kept = {}, {}
local counts = {flat = 0, gentle = 0, steep = 0, levelled = 0, deep = 0}
for z = AREA.min_z - 1, AREA.max_z + 1 do
	for x = AREA.min_x - 1, AREA.max_x + 1 do
		local level, depth, g = pools.at(x, z)
		local key = x .. "," .. z
		local inner = x >= AREA.min_x and x <= AREA.max_x and z >= AREA.min_z and z <= AREA.max_z
		if level and not inner then
			final[key] = {bed = level - depth, water = level}
		elseif level then
			kept[key] = {level = level, depth = depth}
			final[key] = {bed = level - depth, water = level}
			check(g == ground(x, z), "pool ground is the column's")
			check(g == level or g == level + 1, "at most one node levelled at " .. key)
			if g == level + 1 then counts.levelled = counts.levelled + 1 end
			if depth == 2 then counts.deep = counts.deep + 1 end
			local low, high = math.huge, -math.huge
			for dz = -2, 2 do
				for dx = -2, 2 do
					local y = ground(x + dx, z + dz)
					low, high = math.min(low, y), math.max(high, y)
				end
			end
			check(high - low <= 1, "a pool's window is gentle at " .. key)
			check(low == level, "the level is the window's lowest ground at " .. key)
			if x < 0 then counts.flat = counts.flat + 1
			elseif x < 90 then counts.gentle = counts.gentle + 1
			else counts.steep = counts.steep + 1 end
			for dz = -1, 1 do
				for dx = -1, 1 do
					check(not in_town(x + dx, z + dz), "no pool at the town at " .. key)
					check(z + dz ~= -30, "no pool at the road at " .. key)
					check(not (x + dx == -30 and z + dz == 60), "no pool at the cave at " .. key)
					check(x + dx > -90, "no pool on the coast at " .. key)
				end
			end
			check(math.abs(x + 20) > 2 or math.abs(z - 40) > 2, "no pool within 2 of the lake at " .. key)
		else
			local _, _, _, _, _, terrain_y, water_y = planner.column_values_at(x, z)
			final[key] = {bed = terrain_y, water = water_y}
		end
	end
end
check(counts.flat > 50 and counts.gentle > 50, ("pools on flat (%d) and gentle (%d) ground"):format(
	counts.flat, counts.gentle))
check(counts.steep == 0, "no pool on steep ground")
check(counts.levelled > 0, "gentle ground is levelled for some pools (" .. counts.levelled .. ")")
check(counts.deep > 0, "some pools are 2 deep (" .. counts.deep .. ")")
-- the final terrain: every water node of a pool has ground or water of its
-- own level on its four sides and below
local flows = 0
for key, cell in pairs(kept) do
	local x, z = key:match("^(%-?%d+),(%-?%d+)$")
	x, z = tonumber(x), tonumber(z)
	for y = cell.level - cell.depth + 1, cell.level do
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local n = final[(x + d[1]) .. "," .. (z + d[2])]
			local solid = y <= n.bed
			local water = n.water and y > n.bed and y <= n.water
			if not solid and not water then flows = flows + 1 end
			if water and n.water ~= cell.level then flows = flows + 1 end
		end
	end
end
check(flows == 0, "no pool water can flow (" .. flows .. " open sides)")
for key in pairs(kept) do
	local x, z = key:match("^(%-?%d+),(%-?%d+)$")
	x, z = tonumber(x), tonumber(z)
	check(pools.guard(x, z) and pools.guard(x + 1, z - 1), "the guard covers a pool and its ring")
	check(pools.near(x + 2, z), "the near ring reaches 2")
end
check(not pools.guard(-100, -55) and not pools.near(130, 90), "guard and near stay away from no pool")

-- F. the swamp pass on a fake successor context
local swamp = dofile(wp40 .. "/swamp_writer.lua")
-- grug_mapgen's world nodes are not in the harness: the lily stands in
local fake = {registered_nodes = setmetatable({["grug_mapgen:freshwater_waterlily"] =
	{walkable = false}}, {__index = H.nodes}), CONTENT_AIR = 1}
local cids, names = {air = 1}, {"air"}
function fake.get_content_id(name)
	if not cids[name] then
		names[#names + 1] = name
		cids[name] = #names
	end
	return cids[name]
end
function fake.get_name_from_content_id(c) return names[c] end
local pass = swamp.config(fake).new({full_seed_string = "12345", planner_source = planner,
	content = {swamp_pools = function() return pools end}})
-- a world: ground filled with mud, air above; a log on one levelled pool
local world = {}
local function wkey(x, y, z) return x .. "," .. y .. "," .. z end
local MUD = fake.get_content_id("grug_nodes:mud")
-- the first levelled pool inside the owner (z, then x) gets the log
local log_column
for z = -20, 59 do
	for x = -40, 79 do
		local cell = kept[x .. "," .. z]
		if not log_column and cell and ground(x, z) == cell.level + 1 then log_column = {x, z} end
	end
end
local function settled(x, y, z)
	local c = world[wkey(x, y, z)]
	if c then return c end
	local _, _, _, _, _, terrain_y = planner.column_values_at(x, z)
	return y <= terrain_y and MUD or 1
end
local TREE = fake.get_content_id("grug_trees:gravewood_tree")
world[wkey(log_column[1], ground(log_column[1], log_column[2]) + 1, log_column[2])] = TREE
local OWNER = {min_x = -40, max_x = 79, min_z = -20, max_z = 59, min_y = -32, max_y = 47}
local writes, outside = {}, 0
local context = {min_x = OWNER.min_x, max_x = OWNER.max_x, min_z = OWNER.min_z,
	max_z = OWNER.max_z, min_y = OWNER.min_y, max_y = OWNER.max_y,
	column_values_at = planner.column_values_at}
function context.inside_owner(x, y, z)
	return x >= OWNER.min_x and x <= OWNER.max_x and y >= OWNER.min_y and y <= OWNER.max_y and
		z >= OWNER.min_z and z <= OWNER.max_z
end
function context.settled_at(x, y, z) return settled(x, y, z), 0 end
function context.write_road(x, y, z, c, param2)
	if not context.inside_owner(x, y, z) then outside = outside + 1 end
	world[wkey(x, y, z)] = c
	writes[#writes + 1] = {x, y, z, c, param2}
end
local pool_columns = pass.dress(context)
check(pool_columns > 0, "the pass writes pools (" .. pool_columns .. " columns)")
check(outside == 0, "nothing is written outside the owner")
local WATER, LILY = fake.get_content_id("default:water_source"),
	fake.get_content_id("grug_mapgen:freshwater_waterlily")
local wrong, lilies, reeds = 0, 0, 0
for key, cell in pairs(kept) do
	local x, z = key:match("^(%-?%d+),(%-?%d+)$")
	x, z = tonumber(x), tonumber(z)
	if context.inside_owner(x, cell.level, z) then
		local g = ground(x, z)
		local logged = log_column[1] == x and log_column[2] == z
		if logged then
			-- the top stays, and so does the mud under it: no hidden water
			check(settled(x, g, z) == MUD, "a column with a log on it keeps its top")
			for y = cell.level - cell.depth + 1, cell.level do
				check(settled(x, y, z) == MUD, "no water under a kept top")
			end
			check(settled(x, cell.level - cell.depth, z) == MUD, "no rooted reeds under a kept top")
		else
			if settled(x, cell.level, z) ~= WATER then wrong = wrong + 1 end
			if g == cell.level + 1 then
				local top = settled(x, g, z)
				if top ~= 1 and top ~= LILY then wrong = wrong + 1 end
			end
		end
		if settled(x, cell.level + 1, z) == LILY then lilies = lilies + 1 end
	end
end
for _, w in ipairs(writes) do
	if w[4] == fake.get_content_id("grug_nodes:reeds") then reeds = reeds + 1 end
end
check(wrong == 0, "every pool column holds its water and lost its raised top (" .. wrong .. ")")
check(lilies > 0 and reeds > 0, ("lilies (%d) and bank reeds (%d)"):format(lilies, reeds))

if failures > 0 then error(failures .. " FAILURES of " .. checks .. " checks", 0) end
print(("PASS r47_sw: %d checks, %d swamp nodes; pools flat %d, gentle %d (levelled %d, 2 deep %d)")
	:format(checks, #ALL, counts.flat, counts.gentle, counts.levelled, counts.deep))
