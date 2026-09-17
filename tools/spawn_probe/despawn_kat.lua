-- Lane S known-answer test for the real mobs_redo despawn implementation.
-- Plain Lua 5.1; the production api.lua is loaded in an isolated engine stub.

local repo = arg[1] or "."

local function fail(message)
	error("spawn despawn KAT: " .. message, 0)
end

local function want(condition, message)
	if not condition then fail(message) end
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end

local function noop() end
local env = setmetatable({}, {__index = _G})
env._G = env
env.table = copy(table)
env.table.copy = copy

local core_stub = {
	LIGHT_MAX = 14,
	registered_aliases = {},
	registered_entities = {},
	registered_items = {},
	registered_nodes = {
		air = {walkable = false, groups = {}},
		ignore = {walkable = false, groups = {}},
	},
	registered_tools = {},
	registered_craftitems = {},
	settings = {
		get = function(_, name)
			if name == "mob_active_limit" then return "600" end
			return nil
		end,
		get_bool = function(_, name)
			return name == "enable_damage" or name == "remove_far_mobs"
		end,
	},
}
env.core = core_stub
env.minetest = core_stub

core_stub.get_translator = function()
	return function(text) return text end
end
core_stub.global_exists = function(name)
	return rawget(env, name) ~= nil
end
core_stub.get_modpath = function() return nil end
core_stub.check_player_privs = function() return false end
core_stub.formspec_escape = function(text) return text end
core_stub.sound_play = noop
core_stub.serialize = copy
core_stub.deserialize = function(value)
	if value == nil or value == "" then return nil end
	return copy(value)
end
core_stub.get_connected_players = function() return {} end
core_stub.register_entity = function(name, def)
	core_stub.registered_entities[name:gsub("^:", "")] = def
end
core_stub.register_craftitem = function(name, def)
	core_stub.registered_craftitems[name:gsub("^:", "")] = def
end
core_stub.register_tool = function(name, def)
	core_stub.registered_tools[name:gsub("^:", "")] = def
end
core_stub.register_chatcommand = noop
core_stub.register_privilege = noop
core_stub.register_abm = noop
core_stub.register_lbm = noop
core_stub.register_on_joinplayer = noop
core_stub.register_on_leaveplayer = noop
core_stub.register_on_player_receive_fields = noop
core_stub.register_on_dieplayer = noop
core_stub.register_on_shutdown = noop
core_stub.register_globalstep = noop

setmetatable(core_stub, {
	__index = function(_, name)
		if name:match("^register_") then return noop end
		return noop
	end,
})

env.vector = {
	direction = noop,
	multiply = noop,
	subtract = noop,
	add = noop,
}
env.ItemStack = function()
	return {
		get_name = function() return "" end,
		get_definition = function() return {} end,
	}
end

setfenv(assert(loadfile(repo .. "/mods/ENTITIES/mobs/api.lua")), env)()

local decision = env.mobs.despawn_distance_decision
want(type(decision) == "function", "production decision function missing")

local function player_at(x)
	return {get_pos = function() return {x = x, y = 0, z = 0} end}
end

local origin = {x = 0, y = 0, z = 0}
local function decide(distance, roll)
	return decision(env.mobs, origin, {player_at(distance)}, roll)
end

want(decide(20, 0) == false, "20-node stag is not protected")
want(decide(40, 0) == false, "40-node stag is not protected")
want(decide(48, 0) == false, "minimum boundary must be protected")
want(decide(49, 0) == true, "transition band never permits despawn")
want(decide(49, 1) == false, "transition band always despawns")
want(decide(88, 0.49) == true, "midpoint roll below 0.5 must despawn")
want(decide(88, 0.50) == false, "midpoint roll at 0.5 must persist")
want(decide(127, 1) == false, "upper transition boundary lost")
want(decide(128, 1) == true, "maximum boundary must permit despawn")
want(decision(env.mobs, origin, {player_at(200), player_at(30)}, 0) == false,
	"nearest player does not win")
want(decision(env.mobs, origin, {}, 1) == true,
	"no-player unload must remain eligible")

local function active_mob_count()
	return env.mobs:get_active_mob_count()
end

local function entity_at(distance, fields)
	local object = {
		removed = 0,
		properties = {hp_max = 10},
		rotation = {x = 0, y = 0, z = 0},
		get_pos = function() return origin end,
	}
	function object:remove()
		self.removed = self.removed + 1
	end
	function object:set_properties(properties)
		for key, value in pairs(properties) do self.properties[key] = value end
	end
	function object:get_properties()
		return self.properties
	end
	function object:set_armor_groups(armor)
		self.armor_groups = armor
	end
	function object:get_rotation()
		return copy(self.rotation)
	end
	function object:set_rotation(rotation)
		self.rotation = copy(rotation)
	end
	function object:set_texture_mod(texture_mod)
		self.texture_mod = texture_mod
	end
	local entity = setmetatable({
		object = object,
		name = "grug_mobs:stag",
		type = "monster",
		state = "stand",
		tamed = false,
		lifetimer = 180,
		health = 10,
		hp_min = 10,
		armor = 100,
		base_texture = {"stag.png"},
		base_mesh = "stag.b3d",
		base_size = {x = 1, y = 1},
		base_colbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		base_selbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		texture_mods = "",
		rotate = 0,
	}, {__index = env.mobs.mob_class})
	for key, value in pairs(fields or {}) do entity[key] = value end
	core_stub.get_connected_players = function() return {player_at(distance)} end
	return entity
end

local function engine_store(entity, deactivate)
	local stored = entity:mob_staticdata()
	if deactivate then
		entity:on_deactivate(false)
		entity.object.deactivated = true
	end
	return copy(stored)
end

-- A new object is counted on its initial engine static-data store.
local stag = entity_at(40)
stag:mob_activate({}, {}, 0)
local created_data = engine_store(stag, false)
want(active_mob_count() == 1, "create did not increment active_mobs once")
want(created_data.active_toggle == -1 and created_data.remove_ok == true,
	"create store did not prepare unload accounting")

-- The protected unload debits once, persists the ordinary entity, and does
-- not call ObjectRef:remove(). The engine stores the callback result first
-- and only then deactivates the object.
local protected_data = engine_store(stag, true)
want(active_mob_count() == 0,
	"protected unload did not debit active_mobs exactly once")
want(stag.object.removed == 0, "protected unload removed the stag")
want(protected_data.name == "grug_mobs:stag" and
		protected_data._grug_despawn_terminal == nil,
	"protected unload did not persist the ordinary stag")

-- Luanti reloads only through on_activate; it does not ask for static data
-- again. Production mob_activate must count this normal reload exactly once
-- and prepare the next real unload for a debit.
stag = entity_at(40)
stag:mob_activate(protected_data, {}, 1)
want(active_mob_count() == 1,
	"protected reload did not restore active_mobs exactly once")
want(stag.active_toggle == -1,
	"protected reload did not prepare the next unload debit")

-- A far unload debits through active_toggle only. Its terminal callback result
-- is stored before deactivation; it must not remove or debit inside the
-- callback, because Luanti has not yet finished storing that result.
core_stub.get_connected_players = function() return {player_at(128)} end
local terminal_data = engine_store(stag, true)
want(active_mob_count() == 0,
	"far unload did not debit active_mobs exactly once")
want(stag.object.removed == 0,
	"far unload removed the object before storing its terminal marker")
want(terminal_data._grug_despawn_terminal == true and
		terminal_data.name == nil,
	"far unload did not store the exact terminal marker")

-- Loading that stored marker creates a transient Lua entity. Production
-- mob_activate must disable static saving and remove it immediately without a
-- second counter debit, leaving no entity to save or reactivate again.
local terminal = entity_at(128)
terminal:mob_activate(terminal_data, {}, 1)
terminal:on_deactivate(true)
want(terminal.object.removed == 1,
	"terminal marker was not consumed on activation")
want(terminal.object.properties.static_save == false,
	"terminal removal remained eligible for another static save")
want(active_mob_count() == 0,
	"terminal activation debited active_mobs a second time")

io.write("spawn_despawn\tPASS\tmin=48\tmax=128\t" ..
	"create=1\tprotected_unload=0\tprotected_reload=1\tfar=0\t" ..
	"terminal_absent\n")
