-- Round 45 playtest fix PT6 portable test (LuaJIT): the mount in first
-- person and the ride sounds. Loads the REAL grug_sounds/init.lua and the
-- REAL grug_mounts catalog.lua and entity.lua under a minimal `core` stub;
-- the engine's moveresult (touching_ground) is handed to the controller's
-- on_step like the engine does. Checks:
--   V  first person: the visible mount of a riding (land) and a flying mount
--      is attached to its rider with forced_visible, a boat's hull without;
--   G  the gallop: plays (stoppable, not ephemeral) while the mount runs on
--      the ground, paced by its interval; stops at once when the mount
--      stands; a short loss of ground contact (under 0.5 s) keeps it, a
--      longer one stops it, and landing plays it again at once; a dismount
--      stops it;
--   W  the wing beats: play while the flyer moves, stop at once when it
--      hovers and on a dismount;
--   S  grug_sounds.stop: only a stoppable event's kept play, once; it lifts
--      the interval; a non-stoppable event (the boat's splash) stays
--      ephemeral and is never stopped; a leaving player's handles go.
--
--   luajit tools/r45_pt6/portable_test.lua [REPO]
-- Prints "R45 PT6 PORTABLE PASS checks=<n>" or the failures.

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
-- Engine surface.
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

local clock_us = 1000000
local plays, fades = {}, {}
local next_handle = 0
local serial = {}
local callbacks = {hp = {}, die = {}, leave = {}, join = {}, shutdown = {}}
local registered_entities = {}

core = {
	registered_nodes = {air = {walkable = false, liquidtype = "none"}},
	get_us_time = function() return clock_us end,
	sound_play = function(spec, params, ephemeral)
		local handle
		if not ephemeral then
			next_handle = next_handle + 1
			handle = next_handle
		end
		plays[#plays + 1] = {spec = spec, params = params, ephemeral = ephemeral, handle = handle}
		return handle or -1
	end,
	sound_fade = function(handle, step, gain)
		fades[#fades + 1] = {handle = handle, step = step, gain = gain}
	end,
	get_item_group = function() return 0 end,
	get_node_or_nil = function() return {name = "air"} end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_on_player_hpchange = function(fn) callbacks.hp[#callbacks.hp + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_shutdown = function(fn) callbacks.shutdown[#callbacks.shutdown + 1] = fn end,
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
	function object:get_properties() return self.props end
	function object:set_attach(parent, bone, position, rotation, forced_visible)
		self.parent, self.forced_visible = parent, forced_visible
	end
	function object:get_attach() return self.parent end
	function object:set_animation() end
	function object:is_player() return false end
	if entity.on_activate then entity.on_activate(entity, staticdata, 0) end
	if not object.valid then return nil end
	return object
end
core.add_entity = function(pos, name, staticdata) return new_object(pos, name, staticdata) end

local function make_player(name, faction, race)
	local player = {name = name, pos = {x = 0, y = 10, z = 0}, hp = 20,
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
	function player:set_properties() end
	function player:get_properties() return {visual_size = {x = 1, y = 1}} end
	function player:get_look_horizontal() return self.look end
	function player:get_player_control() return self.control end
	function player:hud_remove() end
	players[name] = player
	return player
end

player_api = {player_attached = {}, set_animation = function() end}
grug_core = {
	FLIGHT_CEILING = 600,
	is_max_hp_clamp = function() return false end,
	in_combat = function() return false end,
	set_status = function() end,
	clear_status = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	feed = function() return true end,
}
grug_zones = {
	water_class_at = function() return "land" end,
	id_at = function() return "home" end,
	get = function() return {territory_rule = "accord_home"} end,
	terrain_height_at = function() return 0 end,
}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end,
}
grug_classes = {
	get_race = function(player) return player.race end,
	register_on_race_chosen = function() end,
}

dofile(ROOT .. "/mods/CORE/grug_sounds/init.lua")
grug_mounts = {}
dofile(ROOT .. "/mods/PLAYER/grug_mounts/catalog.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mounts/entity.lua")
local CONTROLLER = registered_entities["grug_mounts:mount"]
local S = grug_sounds

local DT = 0.05
-- The engine moves the object, reports ground contact, then calls on_step.
local function step(entity, grounded)
	local o = entity.object
	o.pos = {x = o.pos.x + o.velocity.x * DT, y = o.pos.y + o.velocity.y * DT,
		z = o.pos.z + o.velocity.z * DT}
	clock_us = clock_us + DT * 1000000
	CONTROLLER.on_step(entity, DT, {touching_ground = grounded ~= false,
		collides = grounded ~= false, standing_on_object = false, collisions = {}})
end
local function steps(entity, seconds, grounded)
	for _ = 1, math.floor(seconds / DT + 0.5) do step(entity, grounded) end
end
local function ride(player, tier)
	assert(grug_mounts.spawn_entity(player, tier, player:get_pos()))
	local record = grug_mounts.active[player:get_player_name()]
	return record.object:get_luaentity(), record
end
local function count(spec)
	local n = 0
	for _, p in ipairs(plays) do if p.spec == spec then n = n + 1 end end
	return n
end
local function last_play() return plays[#plays] end
local function last_fade() return fades[#fades] end

------------------------------------------------------------------------------
-- V: first person.
------------------------------------------------------------------------------
local ada = make_player("ada", "accord", "human")
for _, case in ipairs({{1, true, "Apprentice horse"}, {2, true, "Journeyman race mount"},
		{3, true, "Expert flyer"}, {4, true, "Master flyer"},
		{5, false, "Boat"}, {6, false, "Improved Boat"}}) do
	local _, record = ride(ada, case[1])
	eq(record.visual:get_attach(), ada, "V the visible mount rides on its rider: " .. case[3])
	eq(record.visual.forced_visible, case[2], "V forced_visible in first person: " .. case[3])
	grug_mounts.dismount(ada, "manual", false)
	check(not record.visual:is_valid() and not record.object:is_valid(),
		"V dismount removes both objects: " .. case[3])
end

------------------------------------------------------------------------------
-- G: the gallop.
------------------------------------------------------------------------------
local GALLOP = S.EVENTS.mount_gallop.name
eq(S.EVENTS.mount_gallop.stoppable, true, "G the gallop is stoppable")
eq(S.EVENTS.mount_wings.stoppable, true, "W the wing beats are stoppable")
check(not S.EVENTS.boat_splash.stoppable, "S the boat's splash is not")

plays, fades = {}, {}
local horse = ride(ada, 1)
steps(horse, 0.5)
eq(count(GALLOP), 0, "G no gallop while standing")
ada.control = {up = true}
steps(horse, 0.3)
eq(count(GALLOP), 1, "G the gallop starts once the horse runs")
local first = last_play()
eq(first.ephemeral, false, "G the gallop keeps a handle (not ephemeral)")
eq(first.params.object, horse.object, "G the gallop follows the mount")
steps(horse, 1.5)
eq(count(GALLOP), 1, "G its interval paces it (no repeat within 2.35 s)")
steps(horse, 1.0)
eq(count(GALLOP), 2, "G the next stride sequence after the interval")
local running = last_play().handle

ada.control = {}
step(horse)
eq(#fades, 1, "G standing stops the gallop in the same step")
eq(last_fade().handle, running, "G the playing clip is the one stopped")
eq(last_fade().gain, 0, "G faded to silence")
eq(last_fade().step, S.EVENTS.mount_gallop.gain / 0.1, "G over 0.1 s")
steps(horse, 0.5)
eq(#fades, 1, "G a standing mount stops once")

ada.control = {up = true}
local before = count(GALLOP)
steps(horse, 0.3)
eq(count(GALLOP), before + 1, "G running again plays at once (interval lifted by the stop)")

-- Off the ground: a short loss of contact (a step down) keeps the gallop.
local fades_before = #fades
steps(horse, 0.4, false)
eq(#fades, fades_before, "G 0.4 s off the ground keeps the gallop")
step(horse, true)
-- A jump or a fall: off the ground longer than 0.5 s stops it.
steps(horse, 0.6, false)
eq(#fades, fades_before + 1, "G more than 0.5 s off the ground stops the gallop")
before = count(GALLOP)
steps(horse, 0.5, false)
eq(count(GALLOP), before, "G no gallop while still in the air")
eq(#fades, fades_before + 1, "G stopped once in the air")
step(horse, true)
eq(count(GALLOP), before + 1, "G landing plays the gallop again at once")

-- A dismount stops the running gallop.
running = last_play().handle
fades_before = #fades
grug_mounts.dismount(ada, "manual", false)
eq(#fades, fades_before + 1, "G a dismount stops the gallop")
eq(last_fade().handle, running, "G the dismount stops the playing clip")
-- A dismount of a standing mount has nothing to stop.
horse = ride(ada, 1)
ada.control = {}
steps(horse, 0.3)
fades_before = #fades
grug_mounts.dismount(ada, "manual", false)
eq(#fades, fades_before, "G a dismount from standing stops nothing")

-- A damage dismount (the HP observer) stops it too.
horse = ride(ada, 1)
ada.control = {up = true}
steps(horse, 0.3)
fades_before = #fades
for _, fn in ipairs(callbacks.hp) do fn(ada, -3, {type = "punch"}) end
eq(grug_mounts.active.ada, nil, "G damage dismounts")
eq(#fades, fades_before + 1, "G a damage dismount stops the gallop")

------------------------------------------------------------------------------
-- W: the wing beats.
------------------------------------------------------------------------------
local WINGS = S.EVENTS.mount_wings.name
plays, fades = {}, {}
ada.control = {}
local flyer = ride(ada, 3)
steps(flyer, 0.3)
eq(count(WINGS), 0, "W no wing beats while hovering")
ada.control = {up = true}
step(flyer)
eq(count(WINGS), 1, "W wing beats when the flyer moves")
eq(last_play().ephemeral, false, "W the wing beats keep a handle")
ada.control = {}
step(flyer)
eq(#fades, 1, "W hovering stops the wing beats at once")
ada.control = {jump = true}
step(flyer)
eq(count(WINGS), 2, "W climbing plays them again at once")
fades = {}
grug_mounts.dismount(ada, "manual", false)
eq(#fades, 1, "W a dismount stops the wing beats")

------------------------------------------------------------------------------
-- S: grug_sounds.stop itself.
------------------------------------------------------------------------------
plays, fades = {}, {}
local mount = {get_pos = function() return {x = 0, y = 0, z = 0} end,
	is_player = function() return false end}
eq(S.stop("mount_gallop", mount), false, "S nothing to stop before a play")
eq(S.play("boat_splash", mount), true, "S the splash plays")
eq(last_play().ephemeral, true, "S the splash stays ephemeral")
eq(S.stop("boat_splash", mount), false, "S a non-stoppable event is never stopped")
eq(S.stop("no_such_event", mount), false, "S an unknown event stops nothing")
eq(S.play("mount_gallop", mount), true, "S gallop plays")
eq(S.play("mount_gallop", mount), false, "S its interval drops a repeat")
eq(S.stop("mount_gallop", mount), true, "S the kept play stops")
eq(S.stop("mount_gallop", mount), false, "S a second stop has nothing left")
eq(#fades, 1, "S one fade")
eq(S.play("mount_gallop", mount), true, "S after a stop the next play sounds at once")
local bob = make_player("bob", "accord", "human")
eq(S.play("mount_gallop", bob), true, "S a player target plays")
for _, fn in ipairs(callbacks.leave) do fn(bob) end
eq(S.stop("mount_gallop", bob), false, "S a leaving player's handle is forgotten")

if failures > 0 then
	print(("R45 PT6 PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R45 PT6 PORTABLE PASS checks=%d"):format(checks))
