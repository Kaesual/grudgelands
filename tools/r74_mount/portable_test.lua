-- Round 74 lane MOUNT portable test (LuaJIT): flight over friendly coast and
-- the ride restored at login (docs/planning/round74-plan.md §4 MOUNT, user
-- rulings 2026-11-10). Loads the REAL grug_mounts catalog.lua, state.lua,
-- flight.lua, entity.lua and restore.lua under a minimal `core` stub with a
-- clock for core.after. Checks:
--   F  the flight rule per water class and owning zone: the coastal belt in
--      front of the own home and of contested land is flyable, in front of
--      the enemy's home and of a dragon island not; the open sea and the
--      dragon channels stay "ocean" and are never asked for a zone; land and
--      planned water unchanged;
--   S  save: a logout (and a shutdown, then the leave) on a flyer, a ground
--      mount and a boat saves the tier and keeps the teardown dismount (no
--      animation, no appearance restored, the rider where the mount was); a
--      logout on foot saves nothing;
--   R  restore: at the join the key is cleared and the player held (no
--      movement, no gravity) until the block is active; then the same tier
--      is summoned at the saved seat and the rider seated, the hold
--      released: a flyer in the air (no fall), a ground mount, a boat;
--   B  fallbacks: a flyer refused (over enemy land) is set down on the
--      ground below its column after the column's emerge, unhurt, released,
--      with one feed line; a block not active within the wait sets a flyer
--      down too and releases a ground rider where it stands; a ground mount
--      in an enemy town and a boat off the water are released unmounted;
--      a dead player, a tier not owned and a join without the key are not
--      held; a leave while held keeps the key, and the next join restores.
--
--   luajit tools/r74_mount/portable_test.lua [REPO]
-- Prints "R74 MOUNT PORTABLE PASS checks=<n>" or the failures.

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
-- The world, by column x: Accord home land (x < 100), Throng home land
-- (100..199); the coastal belt in front of the Accord home (200..299, z < 0)
-- and of the Throng home (z >= 0), of contested land (300..399), of a dragon
-- island (400..499); a dragon channel (500..599); the open sea (x >= 600).
-- A lake (planned water) at x 10..20, z -5..5: water at y -1 and 0. Ground:
-- the floor's top at y -0.5 (a floor node at y -1) on land, the sea floor at
-- y -10 under the belt and the open sea. An Accord start town round (50,
-- 50), half width 10.
------------------------------------------------------------------------------
local ZONES = {
	home_a = {territory_rule = "accord_home"},
	home_t = {territory_rule = "throng_home"},
	front = {territory_rule = "contested_land"},
	front_wyrmglass_crown = {territory_rule = "contested_land"},
}
local function rounded(v) return math.floor(v + 0.5) end
local function lake(x, z) return x >= 10 and x <= 20 and z >= -5 and z <= 5 end
local function water_class(x, z)
	x, z = rounded(x), rounded(z)
	if lake(x, z) then return "planned_water" end
	if x < 200 then return "land" end
	if x < 500 then return "coastal_shelf" end
	if x < 600 then return "immutable_dragon_channel" end
	return "deep_ocean"
end
local zone_asks = 0
local function zone_id(x, z)
	zone_asks = zone_asks + 1
	x, z = rounded(x), rounded(z)
	if x < 100 then return "home_a" end
	if x < 200 then return "home_t" end
	if x < 300 then return z < 0 and "home_a" or "home_t" end
	if x < 400 then return "front" end
	if x < 600 then return "front_wyrmglass_crown" end
	return nil
end
-- Set-down ground in the Throng home (no fly for the Accord): a ravine (x
-- 150..155, z 20..25) floored at y -61; a shaft at (170, 20) floored at y
-- -300; a column (180, 20) not loaded below y 0 until `ignore_left` emerges
-- answered; lava as the floor at (190, 0) and in a lake (x 156..168, z
-- 40..60).
-- Under ground with a cave (x 140..145, z 20..25, and round a lava column at
-- (195, 30)): the floor at y -1, rock down to -50, the cave -51..-53, its
-- floor at -54.
local ignore_left = 0
local function cave(x, z)
	return (x >= 140 and x <= 145 and z >= 20 and z <= 25) or
		(x >= 193 and x <= 197 and z >= 28 and z <= 32)
end
local function world_node(pos)
	local x, y, z = rounded(pos.x), rounded(pos.y), rounded(pos.z)
	if x == 195 and z == 30 and y == -1 then return "lava" end
	if x >= 146 and x <= 148 and z >= 20 and z <= 22 and y >= 2 and y <= 10 then return "floor" end
	if cave(x, z) then
		if y >= 0 or (y <= -51 and y >= -53) then return "air" end
		return y >= -54 and "floor" or "air"
	end
	if x >= 150 and x <= 155 and z >= 20 and z <= 25 then return y == -61 and "floor" or "air" end
	if x == 170 and z == 20 then return y == -300 and "floor" or "air" end
	if x == 180 and z == 20 and y < 0 and ignore_left > 0 then return "ignore" end
	if y == -1 and ((x == 190 and z == 0) or (x >= 156 and x <= 168 and z >= 40 and z <= 60)) then
		return "lava"
	end
	if lake(x, z) then
		if y == -1 or y == 0 then return "water" end
		return y == -2 and "floor" or "air"
	end
	if x >= 200 then
		if y > -10 and y <= 0 then return "water" end
		return y == -10 and "floor" or "air"
	end
	return y == -1 and "floor" or "air"
end

------------------------------------------------------------------------------
-- Engine surface (as tools/r72_mounts), with a clock for core.after.
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

local now, timers = 0, {}
local function run_until(t)
	while true do
		local best
		for index, timer in ipairs(timers) do
			if timer.at <= t and (not best or timer.at < timers[best].at) then best = index end
		end
		if not best then break end
		local timer = table.remove(timers, best)
		now = timer.at
		timer.fn()
	end
	now = t
end
local function advance(dt) run_until(now + dt) end

local serial = {}
local registered_entities = {}
local callbacks = {join = {}, leave = {}, shutdown = {}}
local block_active = true
local emerges = {}
local animations = 0
core = {
	registered_nodes = {
		air = {walkable = false, liquidtype = "none"},
		floor = {walkable = true, liquidtype = "none"},
		water = {walkable = false, liquidtype = "source", groups = {water = 3}},
		lava = {walkable = false, liquidtype = "source", damage_per_second = 8, groups = {lava = 3}},
		ignore = {walkable = false, liquidtype = "none"},
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
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_shutdown = function(fn) callbacks.shutdown[#callbacks.shutdown + 1] = fn end,
	after = function(delay, fn) timers[#timers + 1] = {at = now + delay, fn = fn} end,
	get_us_time = function() return now * 1e6 end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_window_information = function() return nil end,
	compare_block_status = function(_, condition)
		assert(condition == "active")
		return block_active
	end,
	-- The emerge answers 0.5 s later, its last block done.
	emerge_area = function(minp, maxp, fn)
		emerges[#emerges + 1] = {minp = copy(minp), maxp = copy(maxp)}
		core.after(0.5, function()
			ignore_left = math.max(0, ignore_left - 1)
			fn({x = 0, y = 0, z = 0}, 0, 0)
		end)
	end,
}
local players = {}
core.get_player_by_name = function(name) return players[name] end
core.get_connected_players = function()
	local list = {}
	for _, player in pairs(players) do list[#list + 1] = player end
	return list
end

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
		control = {}, look = 0, faction = faction, race = race, meta = {}, hurt = 0}
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
	function player:get_meta()
		local meta = self.meta
		return {
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = tostring(v) end,
			get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v ~= "" and v or nil end,
		}
	end
	players[name] = player
	return player
end

local feed = {}
local holds = {}
player_api = {player_attached = {},
	set_animation = function() animations = animations + 1 end,
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
		return {{race_id = "human", faction_id = "accord"}, {race_id = "orc", faction_id = "throng"}}
	end,
	settlement_socket_settlements = function()
		return {{race_id = "human", anchor = {x = 50, y = 0, z = 50}}}
	end,
	-- The ground of a land column is the floor's top, of a wet one the sea's
	-- surface (y 0).
	depth_below_surface = function(pos)
		local ref = rounded(pos.x) >= 200 and 0 or -1
		return ref + 0.5 - pos.y
	end,
	hold_movement = function(player, name) holds[player:get_player_name()] = name end,
	release_movement = function(player, name)
		if holds[player:get_player_name()] == name then holds[player:get_player_name()] = nil end
	end,
	player_in_creation_stasis = function() return false end,
}
grug_visuals = {apply = function() animations = animations + 1 end}
grug_mobs = {box_blocked = function() return false end}
grug_sounds = {play = function() return false end, stop = function() return false end}
grug_zones = {
	water_class_at = water_class,
	id_at = zone_id,
	get = function(id) return ZONES[id] and copy(ZONES[id]) end,
	terrain_height_at = function() return -1 end,
	hard_footprint_in = function(x, z)
		if math.abs(x - 50) <= 10 and math.abs(z - 50) <= 10 then return "dawn", "town" end
		return nil
	end,
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
dofile(ROOT .. "/mods/PLAYER/grug_mounts/state.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/flight.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/entity.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/restore.lua")
local KEY = grug_mounts.LOGOUT_RIDE_KEY
eq(KEY, "grug_mounts:logout_ride", "the saved ride's meta key")

------------------------------------------------------------------------------
-- F: the flight rule.
------------------------------------------------------------------------------
local function rule(faction, x, z) return grug_mounts.column_flight_state(faction, x, z) end
local function legal(faction, x, z, expected_legal, expected_why, label)
	local ok, why = rule(faction, x, z)
	eq(ok, expected_legal, "F " .. label .. ": " .. tostring(faction) .. " flies")
	eq(why, expected_why, "F " .. label .. ": " .. tostring(faction) .. "'s reason")
end
legal("accord", 250, -10, true, nil, "the belt before the own home")
legal("throng", 250, -10, false, "enemy", "the belt before the enemy home")
legal("throng", 250, 10, true, nil, "the belt before the own home")
legal("accord", 250, 10, false, "enemy", "the belt before the enemy home")
legal("accord", 350, 0, true, nil, "the belt before contested land")
legal("throng", 350, 0, true, nil, "the belt before contested land")
legal("accord", 450, 0, false, "island", "the belt before a dragon island")
legal("throng", 450, 0, false, "island", "the belt before a dragon island")
legal("accord", 550, 0, false, "ocean", "a dragon channel")
legal("accord", 700, 0, false, "ocean", "the open sea")
legal("throng", 700, 0, false, "ocean", "the open sea")
legal("accord", 50, 0, true, nil, "own home land")
legal("throng", 50, 0, false, "enemy", "enemy home land")
legal("accord", 15, 0, true, nil, "planned water at home")
legal("accord", 250, -10, true, nil, "the belt before the own home")
legal(nil, 250, -10, false, "enemy", "no faction")
zone_asks = 0
rule("accord", 550, 0)
rule("accord", 700, 0)
eq(zone_asks, 0, "F the channel and the open sea ask no zone")
rule("accord", 250, 0)
eq(zone_asks, 1, "F the belt asks its zone once")
-- The minimap overlay asks the same rule with pass 1's class and zone.
eq(grug_mounts.flight_rule("accord", "coastal_shelf", "home_a"), true, "F overlay: the own belt")
eq(grug_mounts.flight_rule("accord", "coastal_shelf", "home_t"), false, "F overlay: the enemy belt")
eq(grug_mounts.flight_rule("accord", "deep_ocean", false), false, "F overlay: the open sea")

------------------------------------------------------------------------------
-- S and R: save and restore.
------------------------------------------------------------------------------
local ada = make_player("ada", "accord", "human")
local orm = make_player("orm", "throng", "orc")
-- Ada owns the second land tier, the master flyer and the second boat; Orm
-- the first of each.
ada.meta["grug_mounts:land_tier"] = "2"
ada.meta["grug_mounts:flight_tier"] = "4"
ada.meta["grug_mounts:water_tier"] = "6"
orm.meta["grug_mounts:land_tier"] = "1"
orm.meta["grug_mounts:flight_tier"] = "3"
orm.meta["grug_mounts:water_tier"] = "5"

local function leave(player)
	for _, fn in ipairs(callbacks.leave) do fn(player) end
	players[player.name] = nil
end
local function shutdown()
	for _, fn in ipairs(callbacks.shutdown) do fn() end
end
local function join(player)
	players[player.name] = player
	feed = {}
	for _, fn in ipairs(callbacks.join) do fn(player) end
end
local function riding(player)
	local record = grug_mounts.active[player.name]
	return record and record.tier or nil
end
-- Mount `tier` at `pos` (feet), then move the mount to `seat`.
local function ride(player, tier, pos, seat)
	player.pos = copy(pos)
	local ok, message = grug_mounts.mount(player, tier)
	check(ok, "setup: " .. player.name .. " mounts tier " .. tier .. " (" .. tostring(message) .. ")")
	if seat then grug_mounts.active[player.name].object:set_pos(seat) end
end

-- S: a flyer 40 nodes up over the own belt (the old fall to death).
ride(ada, 3, {x = 250, y = 5, z = -10}, {x = 250, y = 40, z = -10})
animations = 0
leave(ada)
eq(ada.meta[KEY], "3", "S a flyer's logout saves its tier (the one ridden, not the highest)")
eq(riding(ada), nil, "S the logout dismounts")
eq(ada.parent, nil, "S the rider is detached")
eq(ada.pos.y, 40, "S the rider is where the mount was")
eq(animations, 0, "S the teardown restores no animation and no appearance")

-- R: the flyer comes back in the air.
block_active = false
join(ada)
eq(ada.meta[KEY], nil, "R the join clears the key")
eq(holds.ada, "grug_mounts:restore", "R the player is held")
eq(riding(ada), nil, "R nothing summoned at the join")
advance(1)
eq(riding(ada), nil, "R nothing summoned before the block is active")
eq(holds.ada, "grug_mounts:restore", "R still held while the block loads")
block_active = true
advance(0.3)
eq(riding(ada), 3, "R the same flyer summoned once the block is active")
eq(ada.parent ~= nil, true, "R the rider seated")
eq(ada:get_pos().y, 40, "R in the air where the mount was, no fall")
eq(holds.ada, nil, "R the hold released")
eq(#feed, 0, "R no notice")

-- S: a shutdown, then the leave the engine sends after it.
shutdown()
leave(ada)
eq(ada.meta[KEY], "3", "S a shutdown saves the tier and the later leave keeps it")
eq(riding(ada), nil, "S the shutdown dismounts")
join(ada)
advance(0.3)
eq(riding(ada), 3, "R after a restart the flyer is back")
grug_mounts.dismount(ada, "manual", false)

-- S/R: a ground mount.
ride(ada, 2, {x = 40, y = -0.49, z = 0})
leave(ada)
eq(ada.meta[KEY], "2", "S a ground mount's tier saved")
join(ada)
advance(0.3)
eq(riding(ada), 2, "R the ground mount is back")
eq(holds.ada, nil, "R released")
grug_mounts.dismount(ada, "manual", false)

-- S/R: a boat on the lake's surface.
ride(ada, 6, {x = 15, y = 0, z = 0})
local boat_pos = ada:get_pos()
leave(ada)
eq(ada.meta[KEY], "6", "S a boat's tier saved")
eq(ada.pos.y, boat_pos.y, "S the rider at the boat's seat")
join(ada)
advance(0.3)
eq(riding(ada), 6, "R the boat is back")
eq(ada:get_pos().y, boat_pos.y, "R on the same surface")
grug_mounts.dismount(ada, "manual", false)

-- S: on foot nothing is saved.
ada.pos = {x = 40, y = -0.49, z = 0}
leave(ada)
eq(ada.meta[KEY], nil, "S a logout on foot saves nothing")
join(ada)
eq(holds.ada, nil, "B a join without the key holds nobody")

------------------------------------------------------------------------------
-- B: fallbacks.
------------------------------------------------------------------------------
-- A flyer saved over the Throng home (moved there while away): set down.
ride(ada, 4, {x = 250, y = 5, z = -10}, {x = 250, y = 30, z = -10})
leave(ada)
ada.pos = {x = 150, y = 30, z = 0}
emerges = {}
join(ada)
advance(0.3)
eq(riding(ada), nil, "B a flyer over enemy land is not summoned")
eq(holds.ada, "grug_mounts:restore", "B held while the column below emerges")
eq(#emerges, 1, "B the column is emerged")
eq(emerges[1] and emerges[1].minp.y, -128, "B the first stage 128 below the ground")
eq(emerges[1] and emerges[1].maxp.y, 32, "B up to the rider's head")
eq(emerges[1] and emerges[1].minp.x, 146, "B the columns round it within 4 too")
eq(#feed, 1, "B one notice")
eq(feed[1] and feed[1].text, "Flying mounts are forbidden here.", "B the summon's refusal")
advance(1)
eq(ada.pos.y, -0.5, "B set down on the ground below")
eq(ada.pos.x, 150, "B in the same column")
eq(holds.ada, nil, "B then released")
eq(ada.meta[KEY], nil, "B the key cleared")

-- A flyer over the sea in front of enemy land is set down on the water.
ada.meta[KEY] = "4"
ada.pos = {x = 250, y = 30, z = 10}
join(ada)
advance(2)
eq(riding(ada), nil, "B a flyer over the enemy belt is not summoned")
eq(ada.pos.y, 0.5, "B set down on the water's surface")
eq(holds.ada, nil, "B released")

-- Set-down ground deeper than the old 16 nodes, not loaded yet, or lava.
local function refused_flyer(x, z)
	ada.meta[KEY] = "4"
	ada.pos = {x = x, y = 30, z = z}
	join(ada)
end
refused_flyer(152, 22)
advance(2)
eq(ada.pos.y, -60.5, "B a ravine 60 below: set down on its floor")
eq(holds.ada, nil, "B released")
refused_flyer(170, 20)
advance(2)
eq(holds.ada, "grug_mounts:restore", "B a shaft 300 deep: held while the stages go down")
eq(ada.pos.y, 30, "B still where it was")
advance(5)
eq(ada.pos.y, -299.5, "B set down on the shaft's floor (third stage)")
eq(holds.ada, nil, "B released")
ignore_left = 2
refused_flyer(180, 20)
advance(1)
eq(holds.ada, "grug_mounts:restore", "B a column not loaded yet: held")
eq(ada.pos.y, 30, "B not dropped")
advance(3)
eq(ada.pos.y, -0.5, "B set down once it is loaded")
eq(holds.ada, nil, "B released")
refused_flyer(190, 0)
advance(2)
eq(ada.pos.y, -0.5, "B lava under the rider: set down beside it")
eq(ada.pos.x == 190 and ada.pos.z == 0, false, "B not on the lava column")
eq(math.abs(ada.pos.x - 190) + math.abs(ada.pos.z), 1, "B on the nearest column")
eq(holds.ada, nil, "B released")
-- A refused flyer standing on its ground, a cave below: set on that ground,
-- not through the rock into the cave (delta review); the same beside lava.
local function grounded_flyer(x, z)
	ada.meta[KEY] = "4"
	ada.pos = {x = x, y = -0.5, z = z}
	join(ada)
end
grounded_flyer(142, 22)
advance(2)
eq(ada.pos.y, -0.5, "B a grounded flyer over a cave: set on its own ground")
eq(holds.ada, nil, "B released")
grounded_flyer(195, 30)
advance(2)
eq(ada.pos.y, -0.5, "B a grounded flyer on lava over caves: set beside it on the ground")
eq(math.abs(ada.pos.x - 195) + math.abs(ada.pos.z - 30), 1, "B on the nearest column")
eq(holds.ada, nil, "B released")
-- A low ceiling over a grounded rider (two open cells, rock from y 2): the
-- ground still.
grounded_flyer(147, 21)
advance(2)
eq(ada.pos.y, -0.5, "B a grounded flyer under a low ceiling: set on its ground")
eq(holds.ada, nil, "B released")
refused_flyer(162, 50)
advance(10)
eq(holds.ada, "grug_mounts:restore", "B lava all round: held, never set into it")
eq(ada.pos.y, 30, "B still in the air")
advance(25)
eq(holds.ada, nil, "B released at the last resort (30 s)")

-- A block not active within the wait: a flyer set down, a ground rider
-- released where it stands.
block_active = false
ada.meta[KEY] = "3"
ada.pos = {x = 40, y = 25, z = 0}
join(ada)
advance(4.9)
eq(holds.ada, "grug_mounts:restore", "B held for the wait")
advance(1)
eq(riding(ada), nil, "B no flyer without an active block")
eq(feed[1] and feed[1].text, "Your mount could not be summoned here.", "B the notice")
advance(1)
eq(ada.pos.y, -0.5, "B the flyer's rider set down")
eq(holds.ada, nil, "B released after the wait")
ada.meta[KEY] = "2"
ada.pos = {x = 40, y = -0.49, z = 0}
join(ada)
advance(6)
eq(riding(ada), nil, "B no ground mount without an active block")
eq(ada.pos.y, -0.49, "B the ground rider stays")
eq(holds.ada, nil, "B and is released")
block_active = true

-- The quickbar during the hold: that ride stays, no second mount.
block_active = false
ada.meta[KEY] = "3"
ada.pos = {x = 40, y = -0.49, z = 0}
join(ada)
check(grug_mounts.toggle(ada, 2), "Q a quickbar summon while held")
local quick = grug_mounts.active.ada
block_active = true
advance(1)
eq(riding(ada), 2, "Q the quickbar's ride stays")
eq(grug_mounts.active.ada == quick and quick.object:is_valid() and quick.visual:is_valid(), true,
	"Q the same controller and visual, no second mount")
eq(holds.ada, nil, "Q released")
grug_mounts.dismount(ada, "manual", false)
-- ... and a leave in that window saves the ride the player was on.
block_active = false
ada.meta[KEY] = "3"
ada.pos = {x = 40, y = -0.49, z = 0}
join(ada)
grug_mounts.toggle(ada, 2)
leave(ada)
eq(ada.meta[KEY], "2", "Q a leave while held on the quickbar's ride saves that ride")
block_active = true
advance(2)
-- A summon over a ride replaces it: the old controller and visual go.
players.ada = ada
ada.pos = {x = 40, y = -0.49, z = 0}
ada.meta[KEY] = nil
check(grug_mounts.mount(ada, 2), "Q mounted")
local old = grug_mounts.active.ada
check(grug_mounts.spawn_entity(ada, 1, {x = 40, y = -0.49, z = 0}), "Q a second summon")
eq(old.object:is_valid() or old.visual:is_valid(), false, "Q the first ride's controller and visual removed")
eq(riding(ada), 1, "Q on the new ride")
grug_mounts.dismount(ada, "manual", false)

-- A ground mount in an enemy town: released unmounted.
orm.meta[KEY] = "1"
orm.pos = {x = 50, y = -0.49, z = 50}
join(orm)
advance(0.3)
eq(riding(orm), nil, "B no ground mount in an enemy town")
eq(feed[1] and feed[1].text, "Mounts and boats are forbidden in enemy towns.", "B the town refusal")
eq(holds.orm, nil, "B released")
eq(orm.pos.y, -0.49, "B where it stood")

-- A boat off the water (the lake drained meanwhile: here, dry land).
orm.meta[KEY] = "5"
orm.pos = {x = 40, y = 0, z = 0}
join(orm)
advance(0.3)
eq(riding(orm), nil, "B no boat off the water")
eq(holds.orm, nil, "B released")

-- Not restored, not held: dead, a tier not owned.
orm.meta[KEY] = "3"
orm.hp = 0
join(orm)
eq(holds.orm, nil, "B a dead player is not held")
eq(orm.meta[KEY], nil, "B the key cleared")
orm.hp = 100
orm.meta[KEY] = "4"
orm.pos = {x = 150, y = 20, z = 0}
join(orm)
eq(holds.orm, nil, "B a tier not owned is not restored")
eq(orm.meta[KEY], nil, "B the key cleared")

-- A leave while held keeps the ride for the next login.
block_active = false
orm.meta[KEY] = "3"
join(orm)
advance(1)
leave(orm)
eq(orm.meta[KEY], "3", "B a leave while held keeps the key")
block_active = true
advance(10)
eq(riding(orm), nil, "B the stale restore does nothing after the leave")
join(orm)
advance(0.3)
eq(riding(orm), 3, "B the next join restores the flyer")
eq(orm:get_pos().y, 20, "B in the air")
eq(holds.orm, nil, "B released")
-- A rejoin while a restore waits replaces it: one summon.
grug_mounts.dismount(orm, "manual", false)
block_active = false
orm.meta[KEY] = "3"
join(orm)
advance(0.5)
leave(orm)
join(orm)
block_active = true
advance(2)
eq(riding(orm), 3, "B a rejoin restores once")

if failures > 0 then
	error(("R74 MOUNT PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print("R74 MOUNT PORTABLE PASS checks=" .. checks)
