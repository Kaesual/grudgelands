-- Round 56 lane MOUNT portable test (LuaJIT): land mounts fall and jump like
-- a player, +5 nodes of fall tolerance, no dismount on a fall (rulings 4-7).
-- Loads the REAL grug_mounts catalog.lua, flight.lua and entity.lua and the
-- REAL fall branch of grug_core/combat.lua's HP modifier under a minimal
-- `core` stub; set_hp runs the modifier, then the observers, like the engine.
-- The engine's object move is integrated like collision.cpp (average speed
-- over the step, then the acceleration), against a floor. Checks:
--   G  a ground mount accelerates at the player's gravity (19.62); a boat off
--      the water keeps 9.81 and a flyer no gravity (their own physics);
--   J  the jump: the impulse's apex v^2 / 2g is at least 2 nodes and under
--      3, and the integrated flight reaches over 2 nodes and lands again;
--   F  the damage table: drops of 5, 10, 11, 13, 20 and 30 nodes cost 0, 0,
--      5, 20, 50 and 85 % of the pool (native 0, 0, 1, 4, 10, 17), the same
--      share for a larger pool; every fall keeps the rider mounted;
--   D  a mob's punch on the mount and a direct punch dismount the rider.
--
--   luajit tools/r56_mount/portable_test.lua [REPO]
-- Prints "R56 MOUNT PORTABLE PASS checks=<n>" or the failures.

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

local function read(path)
	local file = assert(io.open(ROOT .. "/" .. path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

-- Floor nodes at y = -1 (top at -0.5), air above.
local function world_node(pos)
	return math.floor(pos.y + 0.5) == -1 and "floor" or "air"
end

local serial = {}
local callbacks = {hp = {}, die = {}}
local registered_entities = {}
core = {
	registered_nodes = {
		air = {walkable = false, liquidtype = "none"},
		floor = {walkable = true, liquidtype = "none"},
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
	register_on_player_hpchange = function(fn) callbacks.hp[#callbacks.hp + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function() end,
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

-- The fall branch of the shared HP modifier, cut from grug_core/combat.lua.
local combat = read("mods/CORE/grug_core/combat.lua")
local fall_branch = combat:match("\n(\tif reason%.type == \"fall\" then\n.-\n\tend)\n")
assert(fall_branch, "the fall branch of combat.lua's modifier")
local fall_modifier = assert(loadstring("return function(player, hp_change, reason)\n" ..
	fall_branch .. "\nreturn hp_change\nend"))()

local function make_player(name)
	local player = {name = name, pos = {x = 0, y = -0.49, z = 0}, hp = 100, hp_max = 100,
		reasons = {}, armor = {}, control = {}, look = 0, faction = "accord", race = "human"}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_pos()
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function player:set_pos(p) self.pos = copy(p) end
	function player:get_hp() return self.hp end
	-- The modifier, then the observers, like the engine.
	function player:set_hp(hp, reason)
		self.reasons[#self.reasons + 1] = reason
		local change = fall_modifier(self, hp - self.hp, reason)
		for _, fn in ipairs(callbacks.hp) do fn(self, change, reason) end
		self.hp = self.hp + change
	end
	function player:punch(puncher)
		self:set_hp(self.hp - 10, {type = "punch", object = puncher})
		return 0
	end
	function player:get_armor_groups() return self.armor end
	function player:set_attach(parent) self.parent = parent end
	function player:set_detach() self.parent = nil end
	function player:get_attach() return self.parent end
	function player:set_eye_offset() end
	function player:set_properties() end
	function player:get_properties() return {hp_max = self.hp_max, visual_size = {x = 1, y = 1}} end
	function player:get_look_horizontal() return self.look end
	function player:get_player_control() return self.control end
	function player:hud_remove() end
	players[name] = player
	return player
end

player_api = {player_attached = {}, set_animation = function() end,
	get_animation = function() return {animation = "sit"} end}
grug_core = {
	FLIGHT_CEILING = 600,
	is_max_hp_clamp = function() return false end,
	in_combat = function() return false end,
	set_status = function() end,
	clear_status = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	feed = function() return true end,
}
grug_sounds = {play = function() return false end, stop = function() return false end}
grug_zones = {
	water_class_at = function() return "land" end,
	id_at = function() return "home" end,
	get = function() return {territory_rule = "accord_home"} end,
	terrain_height_at = function() return -10 end,
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

-- A mount standing on the floor has its origin at -0.49 (box bottom -0.01).
local GROUND = -0.49
local DT = 0.09 -- the dedicated server step
-- The engine's move (collision.cpp: the average speed over the step, then
-- the acceleration), stopped by the floor, then on_step with the contact.
local function step(entity)
	local o = entity.object
	local ay = o.acceleration.y
	local y = o.pos.y + (o.velocity.y + ay * 0.5 * DT) * DT
	local vy = o.velocity.y + ay * DT
	local grounded = false
	if y <= GROUND then y, vy, grounded = GROUND, 0, true end
	o.pos = {x = o.pos.x, y = y, z = o.pos.z}
	o.velocity = {x = o.velocity.x, y = vy, z = o.velocity.z}
	CONTROLLER.on_step(entity, DT, {touching_ground = grounded, collides = grounded,
		standing_on_object = false, collisions = {}})
end
local function ride(player, tier, pos)
	player.pos = copy(pos or {x = 0, y = GROUND, z = 0})
	player.control = {}
	assert(grug_mounts.spawn_entity(player, tier, player:get_pos()))
	local record = grug_mounts.active[player:get_player_name()]
	return record.object:get_luaentity(), record
end

local ada = make_player("ada")

------------------------------------------------------------------------------
-- G: gravity.
------------------------------------------------------------------------------
local horse, record = ride(ada, 1)
step(horse)
eq(horse.object.acceleration.y, -19.62, "G a ground mount falls at the player's gravity")
eq(horse.object.pos.y, GROUND, "G it stands on the floor")
grug_mounts.dismount(ada, "manual", false)
local _, journeyman = ride(ada, 2)
step(journeyman.object:get_luaentity())
eq(journeyman.object.acceleration.y, -19.62, "G the journeyman mount too")
grug_mounts.dismount(ada, "manual", false)
-- A boat off the water: its own 9.81 (no water anywhere in this world).
local boat = ride(ada, 5, {x = 0, y = 3, z = 0})
CONTROLLER.on_step(boat, DT, {touching_ground = false, collides = false, collisions = {}})
eq(boat.object.acceleration.y, -9.81, "G a boat off the water keeps its own 9.81")
grug_mounts.dismount(ada, "manual", false)
local flyer = ride(ada, 3, {x = 0, y = 3, z = 0})
CONTROLLER.on_step(flyer, DT, {touching_ground = false, collides = false, collisions = {}})
eq(flyer.object.acceleration.y, 0, "G a flyer keeps no gravity")
grug_mounts.dismount(ada, "manual", false)

------------------------------------------------------------------------------
-- J: the jump.
------------------------------------------------------------------------------
horse = ride(ada, 1)
step(horse)
ada.control = {jump = true}
step(horse)
ada.control = {}
local impulse = horse.object.velocity.y
local apex = impulse * impulse / (2 * 19.62)
check(apex >= 2 and apex < 3, ("J the impulse %.2f reaches %.3f nodes (>= 2, < 3)"):format(impulse, apex))
local top, landed = GROUND, false
for _ = 1, 40 do
	step(horse)
	top = math.max(top, horse.object.pos.y)
	if horse.object.pos.y == GROUND then landed = true break end
end
check(top - GROUND > 2, ("J the integrated jump clears 2 nodes (%.3f)"):format(top - GROUND))
check(landed, "J the mount lands again")
print(("J impulse %.2f nodes/s, apex %.3f nodes, sampled apex at %.2f s steps %.3f nodes"):format(
	impulse, apex, DT, top - GROUND))
grug_mounts.dismount(ada, "manual", false)

------------------------------------------------------------------------------
-- F: the damage table; a fall never dismounts.
------------------------------------------------------------------------------
-- A drop from `height`: in the air on the way down, then the landing.
local function fall(entity, height)
	entity.object.pos = {x = 0, y = GROUND + height, z = 0}
	entity.object.velocity = {x = 0, y = 0, z = 0}
	CONTROLLER.on_step(entity, DT, {touching_ground = false, collides = false, collisions = {}})
	entity.object.pos = {x = 0, y = GROUND, z = 0}
	CONTROLLER.on_step(entity, DT, {touching_ground = true, collides = true, collisions = {}})
end
local TABLE = {{5, 0, 0}, {10, 0, 0}, {11, 1, 5}, {13, 4, 20}, {20, 10, 50}, {30, 17, 85}}
for _, pool in ipairs({100, 360}) do
	ada.hp_max = pool
	horse, record = ride(ada, 1)
	step(horse)
	for _, row in ipairs(TABLE) do
		local drop, native, share = row[1], row[2], row[3]
		ada.hp = pool
		local before = #ada.reasons
		fall(horse, drop)
		local lost = pool - ada.hp
		eq(lost, share * pool / 100, ("F pool %d: a %d-node drop costs %d %%"):format(pool, drop, share))
		if native > 0 then
			local reason = ada.reasons[before + 1]
			eq(reason and reason.type, "fall", ("F pool %d, %d nodes: reason type fall"):format(pool, drop))
			eq(ada.hp, pool - share * pool / 100, "F (HP after)")
		else
			eq(#ada.reasons, before, ("F pool %d, %d nodes: no damage call"):format(pool, drop))
		end
		eq(grug_mounts.active.ada, record, ("F pool %d, %d nodes: still mounted"):format(pool, drop))
		eq(ada:get_attach(), record.object, ("F pool %d, %d nodes: still attached"):format(pool, drop))
		if pool == 100 then
			print(("F drop %2d nodes: native %2d, %3d %% of the pool, mounted %s"):format(
				drop, native, lost, tostring(grug_mounts.active.ada == record)))
		end
	end
	grug_mounts.dismount(ada, "manual", false)
end
ada.hp_max, ada.hp = 100, 100

------------------------------------------------------------------------------
-- D: other damage still dismounts.
------------------------------------------------------------------------------
-- A mob's swing lands on the mount (mobs_redo hits the attachment parent).
local wolf = {is_player = function() return false end}
horse, record = ride(ada, 1)
CONTROLLER.on_punch(horse, wolf, 1, {}, {x = 1, y = 0, z = 0})
eq(grug_mounts.active.ada, nil, "D a punch on the mount dismounts the rider")
eq(ada.hp, 90, "D the rider takes the swing")
check(not record.object:is_valid(), "D the mount is gone")
-- A punch on the rider directly (a player's hit).
horse, record = ride(ada, 1)
ada:set_hp(ada.hp - 5, {type = "punch", object = make_player("bob")})
eq(grug_mounts.active.ada, nil, "D a direct punch dismounts the rider")
-- Other damage (a mod's set_hp) still dismounts too.
horse, record = ride(ada, 1)
ada:set_hp(ada.hp - 5, {type = "set_hp", from = "mod"})
eq(grug_mounts.active.ada, nil, "D other damage dismounts the rider")

if failures > 0 then
	print(("R56 MOUNT PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R56 MOUNT PORTABLE PASS checks=%d"):format(checks))
