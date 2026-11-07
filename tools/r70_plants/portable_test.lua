-- Round 70 lane PLANTS portable test (LuaJIT): the decorative plants drop
-- themselves and can be placed (round70-plan.md §2.3), on the whole game's
-- real registrations (tools/r57_details/game_harness.lua) and a small world:
--   A. every plant of the ruling: what its node drops (variants and strands
--      the carried item), no gathering source, the tooltip's decoration
--      line, group and tier, the sale of 1c per 50, a place to put it;
--   B. ordinary placement: fern, lichen variants through core.item_place;
--   C. the waterlily: on source water only, in the air above it, never on
--      flowing water or the ground, protected water refused and reported,
--      liquids pointable, the stack spent;
--   D. seagrass and waterweed: on a plain sand bed under source water only,
--      weed heights under the surface, too shallow refused, protected bed or
--      top refused, digging leaves the sand bed; a node with a right-click
--      takes the click;
--   E. liana and moss: under a block or leaves only, joining a run at its
--      bottom, digging moves the end up and every fallen piece gives one, a
--      protected piece stays and blocks a join, a placed piece has param2 1;
--   F. leaf decay drops nothing for the foliage and the hanging plants;
--   G. no recipe or craft takes one of them, apart from default's fuel rows
--      (what the tooltip promises).
--
-- Usage (repo root): luajit tools/r70_plants/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local nodes = game.nodes

-- The carried item of each plant of the ruling, and what else drops it.
local PLANTS = {
	["grug_nodes:flower_ruby_fan"] = {}, ["grug_nodes:flower_ember_star"] = {},
	["grug_nodes:flower_violet_fan"] = {}, ["grug_nodes:flower_blush_star"] = {},
	["grug_nodes:flower_lilac_bells"] = {}, ["grug_nodes:flower_cream_cups"] = {},
	["grug_nodes:alpine_cushion"] = {}, ["grug_nodes:alpine_windshrub"] = {},
	["grug_nodes:lichen_carpet"] = {"grug_nodes:lichen_carpet_b"},
	["default:fern_1"] = {"default:fern_2", "default:fern_3"},
	["default:marram_grass_1"] = {"default:marram_grass_2", "default:marram_grass_3"},
	["grug_nodes:jungle_bush_leaves"] = {}, ["grug_nodes:withered_bush_leaves"] = {},
	["grug_trees:gravewood_leaves"] = {}, ["grug_trees:swamp_leaves"] = {},
	["grug_mapgen:freshwater_waterlily"] = {}, ["grug_mapgen:freshwater_waterweed"] = {},
	["grug_mapgen:seagrass_1"] = {"grug_mapgen:seagrass_2", "grug_mapgen:seagrass_3"},
	["grug_trees:liana"] = {"grug_trees:liana_strand"},
	["grug_trees:swamp_hanging_moss"] = {"grug_trees:swamp_hanging_moss_strand"},
	["default:coral_brown"] = {}, ["default:coral_orange"] = {},
	["default:coral_cyan"] = {}, ["default:coral_green"] = {}, ["default:coral_pink"] = {},
}

-- A. the plants -------------------------------------------------------------
check(pcall(grug_traders.resolve_prices), "A the prices resolve")
local function drops(name)
	local drop = nodes[name].drop
	return drop == nil and name or drop
end
local plant_count = 0
for item, others in pairs(PLANTS) do
	plant_count = plant_count + 1
	local def = nodes[item]
	if check(def ~= nil, "A " .. item .. " is registered") then
		eq(drops(item), item, "A " .. item .. " drops itself")
		for _, other in ipairs(others) do
			eq(drops(other), item, "A " .. other .. " drops the carried " .. item)
			check((nodes[other].groups.not_in_creative_inventory or 0) > 0,
				"A " .. other .. " stays out of the creative inventory")
			eq(nodes[other].groups.grug_decor_plant, nil, "A " .. other .. " is never carried")
		end
		check((def.groups.grug_gathering_source or 0) == 0, "A " .. item .. " is no gathering source")
		eq((def.groups.not_in_creative_inventory or 0), 0, "A " .. item .. " shows in creative")
		check(def.description:find("\nDecoration: no recipe uses it.\n", 1, true) ~= nil,
			"A " .. item .. " says it is decoration")
		eq(def.groups.grug_decor_plant, 1, "A " .. item .. " has the decoration group")
		eq(grug_traders.item_tier(item), 1, "A " .. item .. " is tier 1")
		eq(grug_traders.sell_value(item), 20, "A " .. item .. " is worth 20 mc")
		local copper, lot = grug_traders.sell_offer(ItemStack(item .. " 99"))
		check(copper == 1 and lot == 50, "A " .. item .. " sells 1c per 50")
	end
end
eq(plant_count, 25, "A every plant of the ruling")
eq(nodes["default:coral_skeleton"].drop, nil, "A the skeleton still drops itself")

-- The small world ------------------------------------------------------------
local world, protected, violations, given = {}, {}, {}, {}
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local function P(x, y, z) return {x = x, y = y, z = z} end
local function put(pos, name, param2) world[key(pos)] = {name = name, param2 = param2 or 0} end
core.get_node = function(pos) return world[key(pos)] or {name = "air", param2 = 0} end
core.get_node_or_nil = core.get_node
core.set_node = function(pos, node)
	world[key(pos)] = {name = node.name, param2 = node.param2 or 0}
end
core.swap_node = core.set_node
core.remove_node = function(pos) world[key(pos)] = nil end
core.is_protected = function(pos) return protected[key(pos)] == true end
core.record_protection_violation = function(pos) violations[#violations + 1] = key(pos) end
core.is_creative_enabled = function() return false end
core.handle_node_drops = function(_, list)
	for _, item in ipairs(list) do given[#given + 1] = item end
end
core.get_item_group = function(name, group)
	local def = core.registered_items[name]
	return def and def.groups and def.groups[group] or 0
end
local sneaking = false
local player = {get_player_name = function() return "tester" end, is_player = function() return true end,
	get_player_control = function() return {sneak = sneaking} end}
-- builtin core.item_place and core.item_place_node, reduced to what the
-- plants need: right-click, the buildable test, protection, after_place_node.
core.item_place = function(stack, placer, pointed)
	local under = core.get_node(pointed.under)
	local under_def = nodes[under.name]
	if not sneaking and under_def and under_def.on_rightclick then
		return under_def.on_rightclick(pointed.under, under, placer, stack, pointed) or stack, nil
	end
	local pos = pointed.above
	local here = nodes[core.get_node(pos).name]
	if here and not here.buildable_to then return stack, nil end
	if core.is_protected(pos, "tester") then
		core.record_protection_violation(pos, "tester")
		return stack, nil
	end
	local name = stack:get_name()
	core.set_node(pos, {name = name})
	if nodes[name].after_place_node then
		nodes[name].after_place_node(pos, placer, stack, pointed)
	end
	stack:take_item()
	return stack, pos
end
default.after_place_leaves = function(pos, placer)
	if placer then
		local node = core.get_node(pos)
		node.param2 = 1
		core.set_node(pos, node)
	end
end
local WATER, FLOWING, SAND = "default:water_source", "default:water_flowing", "default:sand"
local function stack_of(name, count) return ItemStack(name .. " " .. (count or 5)) end
local function place(name, under, above, count)
	local stack = stack_of(name, count)
	local pointed = {type = "node", under = under, above = above or P(under.x, under.y + 1, under.z)}
	return nodes[name].on_place(stack, player, pointed)
end

-- B. ordinary placement -----------------------------------------------------
put(P(0, 0, 0), "default:dirt")
local seen = {}
for _ = 1, 60 do
	core.remove_node(P(0, 1, 0))
	local left = place("grug_nodes:lichen_carpet", P(0, 0, 0))
	eq(left:get_name(), "grug_nodes:lichen_carpet", "B the stack stays the first lichen")
	eq(left:get_count(), 4, "B one lichen is spent")
	seen[core.get_node(P(0, 1, 0)).name] = true
end
check(seen["grug_nodes:lichen_carpet"] and seen["grug_nodes:lichen_carpet_b"], "B both lichens grow")
protected[key(P(0, 1, 0))] = true
core.remove_node(P(0, 1, 0))
eq(place("grug_nodes:lichen_carpet", P(0, 0, 0)):get_count(), 5, "B a protected lichen keeps the stack")
protected = {}

-- C. the waterlily ----------------------------------------------------------
local LILY = "grug_mapgen:freshwater_waterlily"
check(nodes[LILY].liquids_pointable == true, "C the lily points at water")
eq(nodes[LILY].node_placement_prediction, "", "C no client guess of the spot")
world = {}
put(P(0, 0, 0), WATER)
local left = place(LILY, P(0, 0, 0))
eq(core.get_node(P(0, 1, 0)).name, LILY, "C the lily stands over source water")
eq(core.get_node(P(0, 0, 0)).name, WATER, "C the water stays")
eq(left:get_count(), 4, "C one lily is spent")
eq(place(LILY, P(0, 0, 0)):get_count(), 5, "C one lily per spot")
put(P(1, 0, 0), FLOWING)
eq(place(LILY, P(1, 0, 0)):get_count(), 5, "C not on flowing water")
put(P(2, 0, 0), "default:dirt")
eq(place(LILY, P(2, 0, 0)):get_count(), 5, "C not on the ground")
eq(core.get_node(P(2, 1, 0)).name, "air", "C nothing placed on the ground")
put(P(3, 0, 0), WATER)
protected[key(P(3, 1, 0))] = true
violations = {}
eq(place(LILY, P(3, 0, 0)):get_count(), 5, "C protected water keeps the stack")
eq(#violations, 1, "C the refusal reports")
protected = {}
eq(nodes[LILY].on_place(stack_of(LILY), player, {type = "nothing"}):get_count(), 5, "C pointing at nothing")

-- D. the rooted plants ------------------------------------------------------
local WEED, GRASS = "grug_mapgen:freshwater_waterweed", "grug_mapgen:seagrass_1"
local function bed(x, depth)
	put(P(x, 0, 0), SAND)
	for y = 1, depth do put(P(x, y, 0), WATER) end
end
world = {}
bed(0, 1)
local grown = {}
for _ = 1, 40 do
	put(P(0, 0, 0), SAND)
	eq(place(GRASS, P(0, 0, 0)):get_count(), 4, "D seagrass is spent")
	grown[core.get_node(P(0, 0, 0)).name] = true
end
check(grown["grug_mapgen:seagrass_1"] and grown["grug_mapgen:seagrass_2"] and
	grown["grug_mapgen:seagrass_3"], "D every seagrass variant grows")
put(P(1, 0, 0), SAND)
eq(place(GRASS, P(1, 0, 0)):get_count(), 5, "D seagrass needs water above its bed")
put(P(2, 0, 0), "default:dirt")
put(P(2, 1, 0), WATER)
eq(place(GRASS, P(2, 0, 0)):get_count(), 5, "D seagrass needs the sand bed")
bed(3, 1)
eq(place(WEED, P(3, 0, 0)):get_count(), 5, "D waterweed refuses water 1 deep")
for depth = 2, 6 do
	world = {}
	bed(4, depth)
	for _ = 1, 30 do
		put(P(4, 0, 0), SAND)
		eq(place(WEED, P(4, 0, 0)):get_count(), 4, "D weed is spent at depth " .. depth)
		local node = core.get_node(P(4, 0, 0))
		eq(node.name, WEED, "D the weed replaces the bed")
		local height = node.param2 / 16
		check(height % 1 == 0 and height >= 1 and height <= 4 and height <= depth - 1,
			"D weed " .. height .. " tall under the surface at depth " .. depth)
	end
end
world = {}
bed(5, 3)
protected[key(P(5, 0, 0))] = true
violations = {}
eq(place(GRASS, P(5, 0, 0)):get_count(), 5, "D a protected bed keeps the stack")
eq(#violations, 1, "D the refusal reports")
protected = {}
protected[key(P(5, 1, 0))] = true
eq(place(GRASS, P(5, 0, 0)):get_count(), 5, "D protected water above keeps the stack")
protected = {}
for _, name in ipairs({GRASS, "grug_mapgen:seagrass_3", WEED}) do
	put(P(6, 0, 0), name)
	nodes[name].after_dig_node(P(6, 0, 0))
	eq(core.get_node(P(6, 0, 0)).name, SAND, "D digging " .. name .. " leaves the sand bed")
	eq(nodes[name].node_dig_prediction, SAND, "D the client expects the sand bed of " .. name)
end
-- a node with a right-click takes the click, sneaking places
local clicked = 0
nodes["default:sand"].on_rightclick = function(_, _, _, stack)
	clicked = clicked + 1
	return stack
end
world = {}
bed(7, 2)
eq(place(GRASS, P(7, 0, 0)):get_count(), 5, "D the right-click keeps the stack")
eq(clicked, 1, "D the right-click reaches the node")
sneaking = true
eq(place(GRASS, P(7, 0, 0)):get_count(), 4, "D sneaking places")
sneaking = false
nodes["default:sand"].on_rightclick = nil

-- E. the hanging plants -----------------------------------------------------
local LIANA, STRAND = "grug_trees:liana", "grug_trees:liana_strand"
for _, name in ipairs({LIANA, "grug_trees:swamp_hanging_moss"}) do
	eq(nodes[name].node_placement_prediction, "", "E no client guess of the spot for " .. name)
end
world = {}
put(P(0, 10, 0), "default:jungleleaves")
local below_it = P(0, 9, 0)
eq(place(LIANA, P(0, 10, 0), P(0, 11, 0)):get_count(), 5, "E not on top of a block")
eq(place(LIANA, P(0, 10, 0), P(1, 10, 0)):get_count(), 5, "E not on its side")
eq(place(LIANA, P(0, 10, 0), below_it):get_count(), 4, "E one liana hangs under the leaves")
eq(core.get_node(below_it).name, LIANA, "E an end")
eq(core.get_node(below_it).param2, 1, "E a placed piece never decays")
place(LIANA, below_it, P(1, 9, 0)) -- pointed at the run from its side
eq(core.get_node(P(0, 8, 0)).name, LIANA, "E it joins the bottom as the new end")
eq(core.get_node(below_it).name, STRAND, "E the old end becomes a strand")
eq(core.get_node(below_it).param2, 1, "E the strand keeps its param2")
place(LIANA, P(0, 8, 0), P(0, 7, 0))
place(LIANA, below_it, P(-1, 9, 0)) -- the top piece still joins the bottom
eq(core.get_node(P(0, 6, 0)).name, LIANA, "E a run of four")
eq(core.get_node(P(0, 7, 0)).name, STRAND, "E strands above one end")
-- blocked below
put(P(0, 5, 0), "default:dirt")
eq(place(LIANA, below_it, P(1, 9, 0)):get_count(), 5, "E a blocked run keeps the stack")
core.remove_node(P(0, 5, 0))
-- a protected end refuses the join, and does not change
protected[key(P(0, 6, 0))] = true
violations = {}
eq(place(LIANA, P(0, 6, 0), P(0, 5, 0)):get_count(), 5, "E a protected end refuses")
eq(#violations, 1, "E the refusal reports")
protected = {}
-- dig the second piece: the first turns into the end, the two below fall,
-- each piece gives one (the dug one's own item is the engine's drop)
world[key(P(0, 8, 0))] = nil
given = {}
nodes[STRAND].after_dig_node(P(0, 8, 0), {name = STRAND}, {}, player)
eq(core.get_node(below_it).name, LIANA, "E the end moves up")
eq(core.get_node(P(0, 7, 0)).name, "air", "E the strand below falls")
eq(core.get_node(P(0, 6, 0)).name, "air", "E the end below falls")
eq(#given, 2, "E both fallen pieces give one")
eq(given[1], LIANA, "E a fallen strand gives the carried liana")
-- a protected piece stays
put(P(2, 9, 0), STRAND)
put(P(2, 8, 0), STRAND)
put(P(2, 7, 0), LIANA)
protected[key(P(2, 7, 0))] = true
given = {}
world[key(P(2, 9, 0))] = nil
nodes[STRAND].after_dig_node(P(2, 9, 0), {name = STRAND}, {}, player)
eq(core.get_node(P(2, 7, 0)).name, LIANA, "E a protected piece stays")
eq(#given, 1, "E only the free piece gives one")
protected = {}
-- moss is the same rule, and a liana does not join moss
world = {}
local MOSS = "grug_trees:swamp_hanging_moss"
put(P(0, 10, 0), "default:stone")
place(MOSS, P(0, 10, 0), P(0, 9, 0))
eq(core.get_node(P(0, 9, 0)).name, MOSS, "E moss hangs under stone")
eq(place(LIANA, P(0, 9, 0), P(0, 8, 0)):get_count(), 5, "E a liana does not join moss")
put(P(3, 10, 0), "default:torch")
nodes["default:torch"] = nodes["default:torch"] or {walkable = false}
eq(place(LIANA, P(3, 10, 0), P(3, 9, 0)):get_count(), 5, "E not under a plant or a torch")

-- F. leaf decay drops nothing -----------------------------------------------
local added_items = 0
core.add_item = function() added_items = added_items + 1 end
core.find_node_near = function() return nil end
core.check_for_falling = function() end
core.add_particlespawner = function() end
core.get_node_drops = function(name)
	local drop = nodes[name].drop
	return {drop == nil and name or drop}
end
for _, name in ipairs({"grug_trees:gravewood_leaves", "grug_trees:swamp_leaves",
		"grug_nodes:jungle_bush_leaves", "grug_nodes:withered_bush_leaves", LIANA, STRAND, MOSS,
		"grug_trees:swamp_hanging_moss_strand"}) do
	world = {}
	put(P(0, 0, 0), name)
	if check(type(nodes[name].on_timer) == "function", "F " .. name .. " decays") then
		nodes[name].on_timer(P(0, 0, 0))
		eq(core.get_node(P(0, 0, 0)).name, "air", "F " .. name .. " goes")
		eq(added_items, 0, "F " .. name .. " drops nothing when it decays")
	end
end

-- G. no recipe takes a plant ------------------------------------------------
local FUEL = {["default:fern_1"] = true, ["default:marram_grass_1"] = true}
local function takes(recipe, found)
	if type(recipe) == "string" then
		found[recipe:match("^%S*")] = true
	elseif type(recipe) == "table" then
		for _, entry in pairs(recipe) do takes(entry, found) end
	end
	return found
end
for _, recipe in ipairs(grug_jobs.recipes) do
	for _, entry in ipairs(recipe.ingredients) do
		local token = grug_jobs.ingredient_token(entry)
		check(PLANTS[token] == nil, "G no profession recipe takes " .. token)
	end
end
check(#grug_jobs.recipes > 100, "G the recipe registry is the game's")
for _, craft in ipairs(game.crafts) do
	for item in pairs(takes(craft.recipe, {})) do
		check(PLANTS[item] == nil or (craft.type == "fuel" and FUEL[item]),
			"G no craft takes " .. item)
	end
end

if failures > 0 then
	error("R70 PLANTS PORTABLE FAIL " .. failures .. " of " .. checks, 0)
end
print("R70 PLANTS PORTABLE PASS checks=" .. checks)
