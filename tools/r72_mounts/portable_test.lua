-- Round 72 lane MOUNTS portable test (LuaJIT): no mount or boat in an enemy
-- start town or capital (docs/planning/round72-plan.md §2.7, §6 MOUNTS).
-- Loads the REAL grug_mounts catalog.lua, flight.lua and entity.lua under a
-- minimal `core` stub, on a small world: an Accord start town and capital
-- (human), a Throng start town and capital (orc), each a hard "town"
-- footprint round its settlement's anchor, a village without one, a lake in
-- the Throng start town and one in the Accord capital. Checks:
--   S  summons: an Accord character is refused a land mount and a boat in
--      the Throng start town and capital, and a Throng character in the
--      Accord ones, with the refusal; both summon in their own towns, on the
--      land outside (one column from the line, the village) and on the lake
--      outside; a factionless character at the start position summons;
--   D  dismount at the line: a horse ridden into the Throng start town is
--      dismounted at its first column, one feed line, the rider where the
--      mount was; a boat sailing into the town's lake is dismounted and its
--      rider stays in the water; riding through an own town, along the line
--      outside and as a factionless rider dismounts nobody;
--   C  cost: the footprint is asked once per column the mount enters (the
--      first step too), never on a step within the same column, and never
--      for a factionless rider.
--
--   luajit tools/r72_mounts/portable_test.lua [REPO]
-- Prints "R72 MOUNTS PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
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

------------------------------------------------------------------------------
-- The world: towns as squares (half width 40) round their anchors.
------------------------------------------------------------------------------
local HALF = 40
local TOWNS = {
	{id = "accord_start", x = 0, z = 0},
	{id = "accord_capital", x = 0, z = 1000},
	{id = "throng_start", x = 1000, z = 0},
	{id = "throng_capital", x = 1000, z = 1000},
}
local SETTLEMENTS = {
	{key = "dawn", slot = "start", race_id = "human", anchor = {x = 0, y = 0, z = 0}},
	{key = "crown", slot = "capital", race_id = "human", anchor = {x = 0, y = 0, z = 1000}},
	{key = "ash", slot = "start", race_id = "orc", anchor = {x = 1000, y = 0, z = 0}},
	{key = "maw", slot = "capital", race_id = "orc", anchor = {x = 1000, y = 0, z = 1000}},
	{key = "hamlet", slot = "village", race_id = "orc", anchor = {x = 500, y = 0, z = 500}},
}
-- Lakes (water at y = -1 and 0, floor below): in the Throng start town at
-- x 1010..1030 (it reaches past the line at x = 1040 to x = 1060), and in
-- the Accord capital.
local function lake(x, z)
	return (x >= 1010 and x <= 1060 and z >= -5 and z <= 5) or
		(x >= 10 and x <= 20 and z >= 990 and z <= 1010)
end
local function rounded(v) return math.floor(v + 0.5) end
local function world_node(pos)
	local x, y, z = rounded(pos.x), rounded(pos.y), rounded(pos.z)
	if lake(x, z) then
		if y == -1 or y == 0 then return "water" end
		return y == -2 and "floor" or "air"
	end
	-- A cave floor 30 nodes down (U: below a town).
	return (y == -1 or y == -31) and "floor" or "air"
end

local footprint_queries = 0
local function hard_footprint_in(min_x, min_z, max_x, max_z)
	footprint_queries = footprint_queries + 1
	assert(min_x % 1 == 0 and min_z % 1 == 0, "the footprint is asked for whole columns")
	for _, town in ipairs(TOWNS) do
		if max_x >= town.x - HALF and min_x <= town.x + HALF and
				max_z >= town.z - HALF and min_z <= town.z + HALF then
			return town.id, "town"
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- Engine surface (as tools/r56_mount).
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
}

local serial = {}
local registered_entities = {}
core = {
	registered_nodes = {
		air = {walkable = false, liquidtype = "none"},
		floor = {walkable = true, liquidtype = "none"},
		water = {walkable = false, liquidtype = "source", groups = {water = 3}},
	},
	get_item_group = function(name, group)
		local def = core.registered_nodes[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_node_or_nil = function(pos) return {name = world_node(pos)} end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_on_player_hpchange = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	after = function() end,
	register_on_shutdown = function() end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_window_information = function() return nil end,
}
local players = {}
core.get_player_by_name = function(name) return players[name] end

local function new_object(pos, name, staticdata)
	local def = registered_entities[name]
	local object = {pos = copy(pos), velocity = {x = 0, y = 0, z = 0},
		acceleration = {x = 0, y = 0, z = 0}, valid = true, props = {}}
	local entity = setmetatable({object = object, name = name}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:set_pos(p) self.pos = copy(p) end
	function object:get_velocity() return copy(self.velocity) end
	function object:set_velocity(v) self.velocity = copy(v) end
	function object:set_acceleration(a) self.acceleration = copy(a) end
	function object:set_yaw(y) self.yaw = y end
	function object:get_yaw() return self.yaw or 0 end
	function object:is_valid() return self.valid end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:set_armor_groups(g) self.armor = g end
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:set_attach(parent) self.parent = parent end
	function object:get_attach() return self.parent end
	function object:set_animation() end
	function object:is_player() return false end
	if entity.on_activate then entity.on_activate(entity, staticdata, 0) end
	if not object.valid then return nil end
	return object
end
core.add_entity = function(pos, name, staticdata) return new_object(pos, name, staticdata) end

local function make_player(name, faction, race)
	local player = {name = name, pos = {x = 0, y = -0.49, z = 0}, hp = 100,
		control = {}, look = 0, faction = faction, race = race}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_pos()
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function player:set_pos(p) self.pos = copy(p) end
	function player:get_hp() return self.hp end
	function player:set_attach(parent) self.parent = parent end
	function player:set_detach() self.parent = nil end
	function player:get_attach() return self.parent end
	function player:set_eye_offset() end
	function player:set_camera() end
	function player:set_properties() end
	function player:get_properties() return {visual_size = {x = 1, y = 1}} end
	function player:get_look_horizontal() return self.look end
	function player:get_player_control() return self.control end
	function player:hud_remove() end
	players[name] = player
	return player
end

local feed = {}
player_api = {player_attached = {}, set_animation = function() end,
	get_animation = function() return {animation = "sit"} end}
grug_core = {
	FLIGHT_CEILING = 600,
	is_max_hp_clamp = function() return false end,
	in_combat = function() return false end,
	set_status = function() end,
	clear_status = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	feed = function(player, kind, text, key)
		feed[#feed + 1] = {name = player:get_player_name(), kind = kind, text = text, key = key}
		return true
	end,
	zone_authority_installed = function() return true end,
	start_identities = function()
		return {{race_id = "human", faction_id = "accord", anchor = {x = 0, y = 0, z = 0}},
			{race_id = "orc", faction_id = "throng", anchor = {x = 1000, y = 0, z = 0}}}
	end,
	settlement_socket_settlements = function() return copy(SETTLEMENTS) end,
}
grug_sounds = {play = function() return false end, stop = function() return false end}
grug_zones = {
	water_class_at = function() return "land" end,
	id_at = function() return "home" end,
	-- Flight is legal everywhere here: only the town rule is under test.
	get = function() return {territory_rule = "contested_land"} end,
	terrain_height_at = function() return -10 end,
	hard_footprint_in = hard_footprint_in,
}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end,
}
grug_classes = {
	get_race = function(player) return player.race end,
	register_on_race_chosen = function() end,
}

grug_mounts = {}
dofile(ROOT .. "/mods/PLAYER/grug_mounts/catalog.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/flight.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/entity.lua")
local CONTROLLER = registered_entities["grug_mounts:mount"]

local GROUND = -0.49
local DT = 0.09
local REFUSAL = "Mounts and boats are forbidden in enemy towns."
local DISMOUNT = "You entered an enemy town and were dismounted."

local ada = make_player("ada", "accord", "human")
local orm = make_player("orm", "throng", "orc")
local nil_player = make_player("nobody", nil, "human")

-- Feet on land at column (x, z), or in a lake's top water node.
local function land(x, z) return {x = x, y = GROUND, z = z} end
local function water(x, z) return {x = x, y = 0, z = z} end

local function summon(player, tier, pos)
	player.pos = copy(pos)
	feed = {}
	local ok, message = grug_mounts.mount(player, tier)
	if ok then grug_mounts.dismount(player, nil, true) end
	return ok, message
end

------------------------------------------------------------------------------
-- S: summons.
------------------------------------------------------------------------------
local refused = {
	{ada, "throng start town", land(1000, 0), water(1020, 0)},
	{ada, "throng capital", land(1000 - HALF, 1000 + HALF), nil},
	{orm, "accord start town", land(HALF, -HALF), nil},
	{orm, "accord capital", land(0, 1000), water(15, 1000)},
}
for _, row in ipairs(refused) do
	local player, where = row[1], row[2]
	for _, tier in ipairs({1, 2}) do
		local ok, message = summon(player, tier, row[3])
		check(not ok, ("S %s: tier %d refused in the %s"):format(player.name, tier, where))
		eq(message, REFUSAL, ("S %s: tier %d refusal in the %s"):format(player.name, tier, where))
	end
	if row[4] then
		for _, tier in ipairs({5, 6}) do
			local ok, message = summon(player, tier, row[4])
			check(not ok, ("S %s: boat tier %d refused on the %s's lake"):format(player.name, tier, where))
			eq(message, REFUSAL, ("S %s: boat tier %d refusal"):format(player.name, tier))
		end
	end
end
-- The Throng capital and Accord start town have no lake: a boat summoned on
-- their dry land is refused for the town, not for the missing water.
local _, message = summon(ada, 5, land(1000, 1000))
eq(message, REFUSAL, "S a boat on the enemy capital's dry land: the town refusal first")

local allowed = {
	{ada, "own start town", land(0, 0), nil},
	{ada, "own capital", land(-HALF, 1000), water(15, 1000)},
	{orm, "own start town", land(1000, 0), water(1020, 0)},
	{orm, "own capital", land(1000, 1000), nil},
	{ada, "land one column outside the throng start town", land(1000 - HALF - 1, 0), nil},
	{ada, "land one column outside the throng capital", land(1000, 1000 + HALF + 1), nil},
	{ada, "village (no footprint)", land(500, 500), nil},
	{ada, "lake outside the throng start town", nil, water(1000 + HALF + 1, 0)},
	{orm, "land outside the accord capital", land(0, 1000 - HALF - 1), nil},
}
for _, row in ipairs(allowed) do
	local player, where = row[1], row[2]
	if row[3] then
		for _, tier in ipairs({1, 2}) do
			check((summon(player, tier, row[3])), ("S %s: tier %d in the %s"):format(player.name, tier, where))
		end
	end
	if row[4] then
		check((summon(player, 5, row[4])), ("S %s: a boat on the %s"):format(player.name, where))
	end
end
-- A character without a faction at the start position (the Accord start
-- town; tier 1's look needs a faction, the race mount does not).
check((summon(nil_player, 2, land(0, 0))), "S factionless: a race mount at the start position")
check((summon(nil_player, 2, land(1000, 0))), "S factionless: a race mount in the throng start town")
check((summon(nil_player, 5, water(1020, 0))), "S factionless: a boat on the throng start town's lake")

------------------------------------------------------------------------------
-- D: the dismount at the line.
------------------------------------------------------------------------------
local function ride(player, tier, pos)
	player.pos = copy(pos)
	player.control = {}
	assert(grug_mounts.spawn_entity(player, tier, player:get_pos()))
	local record = grug_mounts.active[player:get_player_name()]
	return record.object:get_luaentity(), record
end
-- One step with the mount moved to `pos` first (the engine's move).
local function step_at(entity, pos)
	entity.object.pos = copy(pos)
	entity.object.velocity = {x = 0, y = 0, z = 0}
	CONTROLLER.on_step(entity, DT, {touching_ground = true, collides = true,
		standing_on_object = false, collisions = {}})
end
local function town_lines(name)
	local count = 0
	for _, line in ipairs(feed) do
		if line.name == name and line.text == DISMOUNT then
			count = count + 1
			eq(line.key, "mount", "D the line is the mount notice")
		end
	end
	return count
end

-- A horse ridden east into the Throng start town (its first column x = 960).
feed = {}
local horse = ride(ada, 2, land(940, 10))
local entered
for x = 940, 975, 0.5 do
	step_at(horse, land(x, 10))
	if not grug_mounts.active.ada then entered = x break end
end
eq(entered, 959.5, "D the horse is dismounted at the town's first column (960)")
eq(town_lines("ada"), 1, "D one feed line")
eq(#feed, 1, "D and nothing else")
eq(ada.parent, nil, "D the rider is off")
eq(ada.pos.x, 959.5, "D the rider stays where the mount was (x)")
eq(ada.pos.z, 10, "D the rider stays where the mount was (z)")

-- A boat sailing west into the town's lake from outside (its last column x = 1040).
feed = {}
local boat = ride(ada, 5, {x = 1058, y = 0.5, z = 0})
entered = nil
for x = 1058, 1030, -0.5 do
	step_at(boat, {x = x, y = 0.5, z = 0})
	if not grug_mounts.active.ada then entered = x break end
end
eq(entered, 1040, "D the boat is dismounted at the town's first column")
eq(town_lines("ada"), 1, "D one feed line for the boat")
eq(ada.pos.x, 1040, "D the boat's rider stays where the boat was")
eq(ada.pos.y, 0.5, "D (on the surface)")
eq(world_node({x = ada.pos.x, y = ada.pos.y - 0.5, z = ada.pos.z}), "water",
	"D the boat's rider is in the water (the hull's node, as water_step reads it)")

-- An Improved Boat too, and an Apprentice mount into the Throng capital.
feed = {}
boat = ride(ada, 6, {x = 1042, y = 0.5, z = 2})
step_at(boat, {x = 1042, y = 0.5, z = 2})
check(grug_mounts.active.ada ~= nil, "D an improved boat just outside rides on")
step_at(boat, {x = 1039.6, y = 0.5, z = 2})
eq(grug_mounts.active.ada, nil, "D an improved boat is dismounted at the line")
eq(town_lines("ada"), 1, "D (its line)")
feed = {}
horse = ride(ada, 1, land(1000, 950))
step_at(horse, land(1000, 960))
eq(grug_mounts.active.ada, nil, "D an apprentice mount is dismounted entering the throng capital")
eq(town_lines("ada"), 1, "D (its line)")

-- Rides that dismount nobody: through an own town, along the enemy line
-- outside it, and a factionless rider through the Throng start town.
local function ride_through(player, tier, from_x, to_x, z)
	feed = {}
	local mount = ride(player, tier, land(from_x, z))
	local stepped = 0
	for x = from_x, to_x, from_x < to_x and 0.5 or -0.5 do
		step_at(mount, land(x, z))
		stepped = stepped + 1
		if not grug_mounts.active[player.name] then return false, stepped end
	end
	grug_mounts.dismount(player, nil, true)
	return true, stepped
end
check((ride_through(ada, 2, -60, 60, 0)), "D an Accord rider crosses the own start town")
check((ride_through(orm, 1, 940, 1060, 20)), "D a Throng rider crosses the own start town")
check((ride_through(ada, 2, 900, 1100, 1000 - HALF - 1)), "D along the throng capital's line, outside")
check((ride_through(nil_player, 2, 940, 1060, 10)), "D a factionless rider crosses the throng start town")
eq(town_lines("nobody"), 0, "D (no line for the factionless rider)")

------------------------------------------------------------------------------
-- U: below a town (user ruling 2026-11-08): more than 16 nodes under its
-- anchor riding is free; the town begins 16 nodes down.
------------------------------------------------------------------------------
local function cave(x, z) return {x = x, y = GROUND - 30, z = z} end
check((summon(ada, 2, cave(1000, 0))), "U a mount summoned in a cave 30 below the throng start town")
feed = {}
horse = ride(ada, 2, cave(940, 10))
for x = 940, 1060, 0.5 do
	step_at(horse, cave(x, 10))
	if not grug_mounts.active.ada then break end
end
check(grug_mounts.active.ada ~= nil, "U a rider crosses under the throng start town, 30 down")
eq(town_lines("ada"), 0, "U (no line)")
-- Up a shaft in the same column: at 17 down still free, at 16 down the town.
step_at(horse, {x = 1000, y = -17, z = 10})
check(grug_mounts.active.ada ~= nil, "U 17 below the anchor: still under the town")
step_at(horse, {x = 1000, y = -16, z = 10})
eq(grug_mounts.active.ada, nil, "U 16 below the anchor: in the town, dismounted in the same column")
eq(town_lines("ada"), 1, "U (its line)")
eq(grug_mounts.enemy_town_at("accord", 1000, 0, -16), true, "U the town's floor is 16 below its anchor")
eq(grug_mounts.enemy_town_at("accord", 1000, 0, -17), false, "U one deeper is under it")
eq(grug_mounts.enemy_town_at("accord", 1000, 0), true, "U without y the column alone")

------------------------------------------------------------------------------
-- C: cost.
------------------------------------------------------------------------------
-- 41 columns at half-node steps: one query per column entered, the first
-- step's column included; steps inside a column ask nothing.
footprint_queries = 0
local ok, steps = ride_through(ada, 2, 400, 440, 0)
check(ok, "C a ride on open land")
eq(steps, 81, "C (81 steps)")
eq(footprint_queries, 41, "C one footprint query per column entered")
print(("C 81 steps over 41 columns: %d footprint queries"):format(footprint_queries))
footprint_queries = 0
horse = ride(ada, 2, land(400, 0))
for _ = 1, 50 do step_at(horse, land(400.2, 0)) end
eq(footprint_queries, 1, "C a rider standing still asks once")
grug_mounts.dismount(ada, nil, true)
footprint_queries = 0
ride_through(nil_player, 2, 400, 440, 0)
eq(footprint_queries, 0, "C a factionless rider asks nothing")

if failures > 0 then
	print(("R72 MOUNTS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R72 MOUNTS PORTABLE PASS checks=%d"):format(checks))
