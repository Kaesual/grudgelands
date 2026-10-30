-- Round 67 lane WORLD portable test (LuaJIT): flight underground, vertical
-- flight speed, nametags, wide mobs with room (round67-plan.md §2 rulings
-- 23-26, §6 "WORLD").
--
-- Loads the REAL grug_mobs room.lua, dawn.lua (its bound list) and
-- levels.lua, mobs_redo's scale_mob (cut out of api.lua) with grug_obstacle,
-- and the REAL grug_mounts catalog.lua, flight.lua and entity.lua, under a
-- minimal `core` stub whose map is a dictionary of nodes with real
-- collision boxes (full nodes, a slab, a stair, a snow layer). Checks:
--   R  the room test: a spider (2.1 wide) in a one-node pocket and in rock
--      is blocked; on a snow layer, a slab or a stair's step, beside a slab,
--      and with its box face touching a wall it is not;
--   S  a wide mob's spawn row is refused where its body does not fit and
--      allowed in an open cave; a narrow mob is never asked;
--   T  the elite/rare scale re-check: an elite spider keeps its base size
--      where 1.4x does not fit and grows in the open (levels.lua: the scale
--      applied is recorded, the feet stay on the ground);
--   K  the stuck cleanup: a spider stuck in rock is flagged at the give-up,
--      stays while a player watches, is removed once nobody does; one that
--      moved free is let go; snow, slab and stair footing is never stuck; a
--      bound mob (an NPC, a named rare) is never flagged;
--   N  the nametag decision: none on a critter or an idle/work citizen,
--      every other role and disposition keeps it; a critter's update_tag
--      makes no carrier;
--   M  a flyer is summoned underground, refused in a no-fly column and
--      where its body has no room (a ground mount comes there); a slab
--      under the feet is footing;
--   V  the vertical flight speed per tier (8 and 12, the horizontal speed
--      by default).
--
--   luajit tools/r67_world/portable_test.lua [REPO]
-- Prints "R67 WORLD PORTABLE PASS checks=<n>" or the failures.

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
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
	new = function(x, y, z) return {x = x, y = y, z = z} end,
	round = function(p) return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5),
		z = math.floor(p.z + 0.5)} end,
}
function math.round(x)
	if x < 0 then return math.ceil(x - 0.5) end
	return math.floor(x + 0.5)
end

------------------------------------------------------------------------------
-- The map: a dictionary of nodes, air elsewhere.
------------------------------------------------------------------------------
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local NODES = {
	air = {walkable = false, liquidtype = "none"},
	stone = {walkable = true, liquidtype = "none"},
	slab = {walkable = true, liquidtype = "none",
		boxes = {{-0.5, -0.5, -0.5, 0.5, 0, 0.5}}},
	snow = {walkable = true, liquidtype = "none",
		boxes = {{-0.5, -0.5, -0.5, 0.5, -0.25, 0.5}}},
	-- A stair facing -z: the lower step, the upper half at the back.
	stair = {walkable = true, liquidtype = "none",
		boxes = {{-0.5, -0.5, -0.5, 0.5, 0, 0.5}, {-0.5, 0, 0, 0.5, 0.5, 0.5}}},
	water = {walkable = false, liquidtype = "source", groups = {water = 3}},
}
local world = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name) world[key(x, y, z)] = name end
local function clear() world = {} end
local function fill(x1, y1, z1, x2, y2, z2, name)
	for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do set(x, y, z, name) end end end
end
local function node_at(pos)
	return world[key(math.floor(pos.x + 0.5), math.floor(pos.y + 0.5),
		math.floor(pos.z + 0.5))] or "air"
end

local serial = {}
local registered_entities = {}
local logs = {}
core = {
	registered_nodes = NODES,
	registered_entities = registered_entities,
	settings = {get = function() return nil end,
		get_bool = function(_, _, default) return default end},
	log = function(_, text) logs[#logs + 1] = text end,
	pos_to_string = function(p) return "(" .. p.x .. "," .. p.y .. "," .. p.z .. ")" end,
	get_item_group = function(name, group)
		local def = NODES[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_node_or_nil = function(pos) return {name = node_at(pos)} end,
	get_node_boxes = function(box_type, pos, node)
		assert(box_type == "collision_box", "the room test reads collision boxes")
		return copy(NODES[node.name].boxes or FULL)
	end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_on_player_hpchange = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_shutdown = function() end,
	register_globalstep = function() end,
	after = function() end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_window_information = function() return nil end,
	get_connected_players = function() return {} end,
}

-- Watchers for the stuck cleanup: grug_core's shared player snapshot.
local watchers = {}
grug_core = {
	FLIGHT_CEILING = 600,
	format_k = function(v) return tostring(v) end,
	nearest_tag_player_d2 = function(pos)
		local best
		for _, p in ipairs(watchers) do
			local dx, dy, dz = pos.x - p.x, pos.y - p.y, pos.z - p.z
			local d2 = dx * dx + dy * dy + dz * dz
			if not best or d2 < best then best = d2 end
		end
		return best
	end,
	sync_tag_carrier_box = function() return true end,
	set_tag_carrier_text = function() return true end,
	is_max_hp_clamp = function() return false end,
	in_combat = function() return false end,
	set_status = function() end,
	clear_status = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	feed = function() return true end,
}
grug_xp = {mob_xp = function(level) return 25 + 5 * level end, LEVEL_OFFSET = 5}
grug_zones = {mob_level_at = function() return 10 end, guard_level_at = function() return 60 end}

-- mobs_redo: the real scale_mob (with grug_obstacle's physics box) and a
-- removal that marks the object.
local removed = {}
local api = assert(io.open(ROOT .. "/mods/ENTITIES/mobs/api.lua")):read("*a")
local scale_src = api:match("\nfunction mobs:scale_mob%(.-\nend\n")
assert(scale_src, "mobs:scale_mob not found in api.lua")
mobs = {}
grug_obstacle = dofile(ROOT .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
mobs.grug_obstacle = grug_obstacle
assert(loadstring(scale_src))()
function mobs:remove(self) removed[#removed + 1] = self; self.object.valid = false end

grug_mobs = {ensure_tag_carrier = function() return nil end}
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/room.lua")
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/dawn.lua")
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/levels.lua")

local SPIDER = {-1.05, -0.75, -1.05, 1.05, 0, 1.05}
local WOLF = {-0.3, -0.01, -0.3, 0.3, 0.84, 0.3}
registered_entities["grug_mobs:giant_spider"] = {base_colbox = SPIDER}
registered_entities["grug_mobs:wolf"] = {base_colbox = WOLF}

-- A live mob: an object at `pos` with its box (the physics box mobs_redo
-- keeps in `_grug_cbox`).
local function new_mob(name, pos, box, fields)
	local object = {pos = copy(pos), valid = true, props = {collisionbox = copy(box),
		visual_size = {x = 1, y = 1}, selectionbox = copy(box)}}
	local mob = {name = name, object = object, base_colbox = copy(box),
		base_selbox = copy(box), base_size = {x = 1, y = 1}, _grug_cbox = copy(box)}
	for k, v in pairs(fields or {}) do mob[k] = v end
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:set_pos(p) self.pos = copy(p) end
	function object:get_properties() return self.props end
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:set_armor_groups() end
	function object:is_valid() return self.valid end
	function object:get_luaentity() return mob end
	return mob
end
-- A spider's origin when its feet stand at height `feet`.
local function spider_at(x, feet, z)
	return {x = x, y = feet - SPIDER[2], z = z}
end

------------------------------------------------------------------------------
-- R: the room test.
------------------------------------------------------------------------------
local blocked = grug_mobs.box_blocked
clear()
fill(-3, -1, -3, 3, -1, 3, "stone") -- a floor, top at -0.5
check(not blocked(spider_at(0, -0.5, 0), SPIDER), "R a spider on open ground has room")
-- A one-node pocket: rock all round the column above (0, -1, 0).
fill(-3, 0, -3, 3, 0, 3, "stone")
set(0, 0, 0, "air")
check(blocked(spider_at(0, -0.5, 0), SPIDER), "R a spider in a one-node pocket is blocked")
-- In rock: the floor's level raised, the spider's body inside it.
check(blocked(spider_at(2, -0.5, 2), SPIDER), "R a spider inside rock is blocked")
-- Its box face touching a wall (the wall's face at x = 1.5).
clear()
fill(-3, -1, -3, 3, -1, 3, "stone")
fill(2, 0, -3, 2, 1, 3, "stone")
check(not blocked(spider_at(1.5 - 1.05, -0.5, 0), SPIDER), "R a box touching a wall is not blocked")
check(blocked(spider_at(1.5 - 1.05 + 0.2, -0.5, 0), SPIDER), "R a box 0.2 into the wall is")
-- Footing: a snow layer floor, a slab beside the feet, standing on a slab,
-- on a stair's lower step (its upper half beside the body).
clear()
fill(-3, -1, -3, 3, -1, 3, "stone")
fill(-3, 0, -3, 3, 0, 3, "snow")
check(not blocked(spider_at(0, -0.25, 0), SPIDER), "R a spider standing on snow layers")
check(not blocked(spider_at(0, -0.5, 0), SPIDER), "R snow layers under and beside the feet are footing")
clear()
fill(-3, -1, -3, 3, -1, 3, "stone")
set(1, 0, 0, "slab")
check(not blocked(spider_at(0, -0.5, 0), SPIDER), "R a slab beside the feet is footing")
fill(-3, 0, -3, 3, 0, 3, "slab")
check(not blocked(spider_at(0, 0, 0), SPIDER), "R a spider standing on slabs")
clear()
fill(-3, -1, -3, 3, -1, 3, "stone")
fill(-3, 0, -3, 3, 0, 3, "stair")
check(not blocked(spider_at(0, 0, 0), SPIDER), "R a spider on a stair's step, its upper half beside it")
-- A full node beside the feet is no footing.
clear()
fill(-3, -1, -3, 3, -1, 3, "stone")
set(1, 0, 0, "stone")
check(blocked(spider_at(0, -0.5, 0), SPIDER), "R a full node in the body is an obstacle")
-- Unknown and unloaded count as solid.
NODES.mystery = nil
set(1, 0, 0, "mystery")
check(blocked(spider_at(0, -0.5, 0), SPIDER), "R an unknown node is solid")

------------------------------------------------------------------------------
-- S: the spawn rows of wide mobs.
------------------------------------------------------------------------------
clear()
fill(-3, -1, -3, 3, -1, 3, "stone")
fill(-3, 0, -3, 3, 0, 3, "stone")
set(0, 0, 0, "air")
local matched = {x = 0, y = -1, z = 0}
eq(grug_mobs.spawn_room_refused("grug_mobs:giant_spider", matched), true,
	"S a spider row is refused in a one-node pocket")
eq(grug_mobs.spawn_room_refused("grug_mobs:wolf", matched), false,
	"S a wolf (one node wide) is not asked")
fill(-1, 0, -1, 1, 1, 1, "air")
eq(grug_mobs.spawn_room_refused("grug_mobs:giant_spider", matched), false,
	"S a spider row spawns in an open cave")
eq(grug_mobs.spawn_room_refused("grug_mobs:unknown", matched), false,
	"S an unregistered name is not refused here")

------------------------------------------------------------------------------
-- T: the scale re-check.
------------------------------------------------------------------------------
-- A cave three nodes wide (x and z -1..1, walls from x = 1.5) and a spider
-- 0.4 off its middle: 2.1 fits (to x = 1.45), 2.94 (elite 1.4) reaches
-- x = 1.87, 2.1 (rare 2) x = 2.5.
clear()
fill(-4, -1, -4, 4, -1, 4, "stone")
fill(-4, 0, -4, 4, 2, 4, "stone")
fill(-1, 0, -1, 1, 2, 1, "air")
local narrow = new_mob("grug_mobs:giant_spider", spider_at(0.4, -0.5, 0), SPIDER)
eq(grug_mobs.tier_scale(narrow, 1, 1.4), 1, "T an elite spider keeps its size in a narrow cave")
eq(grug_mobs.tier_scale(narrow, 1, 2), 1, "T a rare one too")
eq(grug_mobs.tier_scale(narrow, 1.4, 1), 1, "T shrinking always fits")
fill(-4, 0, -4, 4, 2, 4, "air")
eq(grug_mobs.tier_scale(narrow, 1, 1.4), 1.4, "T in the open it grows to 1.4")
eq(grug_mobs.tier_scale(narrow, 1, 2), 2, "T and to 2")
-- Through levels.lua: set_tier on a levelled spider.
grug_mobs.register_level_cfg("grug_mobs:giant_spider", {})
local function levelled(pos)
	local mob = new_mob("grug_mobs:giant_spider", pos, SPIDER,
		{_grug_level = 10, _grug_tier = "normal", hp_max = 10, health = 10})
	return mob
end
fill(-4, 0, -4, 4, 2, 4, "stone")
fill(-1, 0, -1, 1, 2, 1, "air")
local kept = levelled(spider_at(0.4, -0.5, 0))
grug_mobs.set_tier(kept, "elite")
eq(kept._grug_tier, "elite", "T the elite tier is set in the narrow cave")
eq(kept._grug_visual_scale, 1, "T at its base size, recorded")
near(kept.base_colbox[4], 1.05, "T the box is unscaled")
fill(-4, 0, -4, 4, 2, 4, "air")
local grown = levelled(spider_at(0, -0.5, 0))
grug_mobs.set_tier(grown, "elite")
eq(grown._grug_visual_scale, 1.4, "T in the open the elite is scaled")
near(grown.base_colbox[4], 1.05 * 1.4, "T its box is 1.4x")
near(grown.object.pos.y + grown.base_colbox[2], -0.5, "T its feet stay on the ground")
-- A mob saved before Round 67 (no recorded scale) scales from its tier's.
local old = levelled(spider_at(0, -0.5, 0))
old._grug_tier, old._grug_visual_tier = "elite", "elite"
grug_mobs.set_tier(old, "rare")
near(old.base_colbox[4], 1.05 * 2 / 1.4, "T an old elite becomes a rare by 2 / 1.4")

------------------------------------------------------------------------------
-- K: the stuck cleanup.
------------------------------------------------------------------------------
clear()
fill(-6, -1, -6, 6, -1, 6, "stone")
fill(-6, 0, -6, 6, 0, 6, "stone")
set(0, 0, 0, "air")
local stuck = new_mob("grug_mobs:giant_spider", spider_at(0, -0.5, 0), SPIDER, {type = "monster"})
check(grug_mobs.mob_stuck(stuck), "K a spider in a one-node pocket is stuck")
watchers = {{x = 10, y = 0, z = 0}}
eq(grug_mobs.give_up_stuck(stuck), true, "K the give-up flags it")
eq(grug_mobs.stuck_tick(stuck, 0.1), false, "K a watched stuck mob stays")
eq(grug_mobs.stuck_tick(stuck, 1), false, "K still watched a second later")
watchers = {{x = 40, y = 0, z = 0}}
eq(grug_mobs.stuck_tick(stuck, 0.5), false, "K the check waits for its second")
eq(grug_mobs.stuck_tick(stuck, 0.5), true, "K nobody watching: removed")
eq(removed[#removed], stuck, "K through mobs:remove")
eq(grug_mobs.stuck_stats.removed, 1, "K counted")
-- Removed on the next step when nobody watches at the give-up.
local lone = new_mob("grug_mobs:giant_spider", spider_at(0, -0.5, 0), SPIDER, {type = "monster"})
grug_mobs.give_up_stuck(lone)
eq(grug_mobs.stuck_tick(lone, 0.05), true, "K an unwatched stuck mob leaves on its next step")
-- A flagged mob that moved free is let go.
watchers = {{x = 2, y = 0, z = 0}}
local freed = new_mob("grug_mobs:giant_spider", spider_at(0, -0.5, 0), SPIDER, {type = "monster"})
grug_mobs.give_up_stuck(freed)
fill(-1, 0, -1, 1, 0, 1, "air")
eq(grug_mobs.stuck_tick(freed, 1), false, "K a mob that moved free stays")
eq(freed.temp.grug_stuck, nil, "K and its flag is cleared")
eq(grug_mobs.stuck_tick(freed, 5), false, "K one field test afterwards")
-- Footing is never stuck.
watchers = {}
for _, ground in ipairs({"snow", "slab", "stair"}) do
	clear()
	fill(-3, -1, -3, 3, -1, 3, "stone")
	fill(-3, 0, -3, 3, 0, 3, ground)
	local feet = ground == "snow" and -0.25 or 0
	local mob = new_mob("grug_mobs:giant_spider", spider_at(0, feet, 0), SPIDER, {type = "monster"})
	eq(grug_mobs.give_up_stuck(mob), false, "K a spider on " .. ground .. " is not stuck")
	local wolf = new_mob("grug_mobs:wolf", {x = 0, y = feet + 0.01, z = 0}, WOLF, {type = "monster"})
	eq(grug_mobs.mob_stuck(wolf), false, "K a wolf on " .. ground .. " is not stuck")
end
-- Bound mobs stay.
clear()
fill(-3, -1, -3, 3, 0, 3, "stone")
set(0, 0, 0, "air")
local npc = new_mob("grug_mobs:giant_spider", spider_at(0, -0.5, 0), SPIDER, {type = "npc"})
eq(grug_mobs.give_up_stuck(npc), false, "K an NPC is never flagged")
local rare = new_mob("grug_mobs:giant_spider", spider_at(0, -0.5, 0), SPIDER,
	{type = "monster", _grug_rare_id = "silkfang"})
eq(grug_mobs.give_up_stuck(rare), false, "K a named rare is never flagged")

------------------------------------------------------------------------------
-- N: the nametag decision.
------------------------------------------------------------------------------
local wants = grug_mobs.wants_nametag
eq(wants({_grug_disposition = "critter"}), false, "N no tag on a critter")
eq(wants({_grug_disposition = "neutral"}), true, "N a neutral mob keeps it")
eq(wants({_grug_disposition = "aggressive"}), true, "N a hostile mob keeps it")
eq(wants({}), true, "N a guard (no disposition) keeps it")
eq(wants({_grug_socket_role = "idle"}), false, "N no tag on an idle citizen")
eq(wants({_grug_socket_role = "work"}), false, "N no tag on a working citizen")
for _, role in ipairs({"guard_post", "guard_patrol", "king", "quest", "vendor",
		"trainer", "innkeeper", "riding_trainer", "shipwright", "housing_manager",
		"guild_exchange", "captain"}) do
	eq(wants({_grug_socket_role = role}), true, "N the " .. role .. " keeps its tag")
end
-- A critter's tag update makes no carrier.
local carriers = 0
grug_mobs.ensure_tag_carrier = function() carriers = carriers + 1 end
local rabbit = new_mob("grug_mobs:rabbit", {x = 0, y = 0, z = 0}, WOLF,
	{_grug_disposition = "critter", _grug_level = 1, _grug_tier = "critter"})
grug_mobs.update_tag(rabbit)
eq(carriers, 0, "N a critter's update_tag makes no carrier")
local fox = new_mob("grug_mobs:fox", {x = 0, y = 0, z = 0}, WOLF,
	{_grug_disposition = "aggressive", _grug_level = 1})
grug_mobs.update_tag(fox)
eq(carriers, 1, "N a hostile mob's does")

------------------------------------------------------------------------------
-- M, V: the mounts.
------------------------------------------------------------------------------
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

local function make_player(name, faction)
	local player = {name = name, pos = {x = 0, y = 0, z = 0}, hp = 100, control = {},
		look = 0, faction = faction or "accord", race = "human"}
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
	function player:get_properties() return {hp_max = 100, visual_size = {x = 1, y = 1}} end
	function player:get_look_horizontal() return self.look end
	function player:get_player_control() return self.control end
	function player:hud_remove() end
	players[name] = player
	return player
end

player_api = {player_attached = {}, set_animation = function() end,
	get_animation = function() return {animation = "sit"} end}
grug_sounds = {play = function() return false end, stop = function() return false end}
-- The enemy's home is x > 100; terrain stands at y = 50 everywhere.
grug_zones.water_class_at = function() return "land" end
grug_zones.id_at = function(x) return x > 100 and "throng_land" or "accord_land" end
grug_zones.get = function(id)
	return {territory_rule = id == "throng_land" and "throng_home" or "accord_home"}
end
grug_zones.terrain_height_at = function() return 50 end
grug_factions = {get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end}
grug_classes = {get_race = function(player) return player.race end,
	register_on_race_chosen = function() end}

grug_mounts = {}
dofile(ROOT .. "/mods/PLAYER/grug_mounts/catalog.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/flight.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/entity.lua")
local CONTROLLER = registered_entities["grug_mounts:mount"]

-- A cave room 40 nodes under the terrain: floor top at y = -40.5.
local function cave(x0)
	clear()
	fill(x0 - 4, -41, -4, x0 + 4, -41, 4, "stone")
	fill(x0 - 4, -40, -4, x0 + 4, -37, 4, "stone")
	fill(x0 - 2, -40, -2, x0 + 2, -38, 2, "air")
end
local ada = make_player("ada")
local function summon(player, tier, pos)
	player.pos = copy(pos)
	player.parent = nil
	return grug_mounts.mount(player, tier)
end
local FEET = -40.5
cave(0)
local ok, message = summon(ada, 3, {x = 0, y = FEET, z = 0})
check(ok, "M a flyer is summoned underground: " .. tostring(message))
eq(grug_mounts.active.ada and grug_mounts.active.ada.mode, "flight", "M (flying)")
grug_mounts.dismount(ada, "manual", true)
-- Below enemy home territory the column rule still forbids it.
cave(150)
ok, message = summon(ada, 4, {x = 150, y = FEET, z = 0})
check(not ok and message == "Flying mounts are forbidden here.",
	"M refused in a no-fly column underground: " .. tostring(message))
-- A one-node tunnel: no room for the flyer, the horse comes.
clear()
fill(-4, -41, -4, 4, -37, 4, "stone")
fill(0, -40, -4, 0, -39, 4, "air")
ok, message = summon(ada, 3, {x = 0, y = FEET, z = 0})
check(not ok and message == "There is not enough room here for a flying mount.",
	"M no flyer without room: " .. tostring(message))
eq(grug_mounts.active.ada, nil, "M (nothing summoned)")
ok, message = summon(ada, 1, {x = 0, y = FEET, z = 0})
check(ok, "M a ground mount comes in the tunnel: " .. tostring(message))
grug_mounts.dismount(ada, "manual", true)
-- On the surface a slab under the feet is footing.
clear()
fill(-4, 49, -4, 4, 49, 4, "stone")
fill(-4, 50, -4, 4, 50, 4, "slab")
ok, message = summon(ada, 4, {x = 0, y = 50, z = 0})
check(ok, "M a flyer on slabs: " .. tostring(message))
local flyer = grug_mounts.active.ada.object:get_luaentity()
-- A slab or a stair's lower step one node beside the feet is footing too
-- (the stair diagonal, so the body reaches only its lower front step).
for _, beside in ipairs({{"slab", 0}, {"stair", 1}}) do
	local other = make_player("beside_" .. beside[1])
	clear()
	fill(-4, 49, -4, 4, 49, 4, "stone")
	set(1, 50, beside[2], beside[1])
	beside = beside[1]
	ok, message = summon(other, 3, {x = 0, y = 49.5, z = 0})
	check(ok, "M a flyer beside a " .. beside .. ": " .. tostring(message))
	grug_mounts.dismount(other, "manual", true)
end
-- A full node beside the feet is no footing.
local walled = make_player("walled")
set(1, 50, 0, "stone")
ok, message = summon(walled, 3, {x = 0, y = 49.5, z = 0})
check(not ok and message == "There is not enough room here for a flying mount.",
	"M no flyer with a full node beside the feet: " .. tostring(message))

-- V: the climb and sink speed.
eq(grug_mounts.TIERS[3].vertical_speed, 8, "V Expert climbs at 8")
eq(grug_mounts.TIERS[4].vertical_speed, 12, "V Master climbs at 12")
local function vertical(entity, control)
	ada.control = control
	CONTROLLER.on_step(entity, 0.09, {touching_ground = false, collides = false, collisions = {}})
	return entity.object.velocity.y
end
eq(vertical(flyer, {jump = true}), 12, "V a Master flyer climbs at its vertical speed")
eq(vertical(flyer, {sneak = true}), -12, "V and sinks at it")
eq(vertical(flyer, {}), 0, "V and hovers")
grug_mounts.TIERS[4].vertical_speed = nil
eq(vertical(flyer, {jump = true}), grug_mounts.TIERS[4].speed,
	"V without the field the horizontal speed")
grug_mounts.TIERS[4].vertical_speed = 12
grug_mounts.dismount(ada, "manual", true)
ok = summon(ada, 3, {x = 0, y = 50, z = 0})
check(ok, "V an Expert flyer")
eq(vertical(grug_mounts.active.ada.object:get_luaentity(), {jump = true}), 8,
	"V an Expert flyer climbs at 8")
grug_mounts.dismount(ada, "manual", true)

if failures > 0 then
	error(("R67 WORLD PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R67 WORLD PORTABLE PASS checks=%d"):format(checks))
