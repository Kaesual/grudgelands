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

if failures > 0 then error(failures .. " FAILURES of " .. checks .. " checks", 0) end
print("PASS r47_sw: " .. checks .. " checks, " .. #ALL .. " swamp nodes")
