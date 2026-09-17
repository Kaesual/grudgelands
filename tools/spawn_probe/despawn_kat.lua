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
		get = function() return nil end,
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
core_stub.serialize = function(value) return value end
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

local removed = 0
local function entity_at(distance)
	local object = {
		get_pos = function() return origin end,
		remove = function() removed = removed + 1 end,
	}
	local entity = setmetatable({
		object = object,
		remove_ok = true,
		type = "monster",
		state = "stand",
		tamed = false,
		lifetimer = 180,
	}, {__index = env.mobs.mob_class})
	core_stub.get_connected_players = function() return {player_at(distance)} end
	return entity
end

local near = entity_at(40)
local near_data = near:mob_staticdata()
want(removed == 0, "near mob was removed by the production unload path")
want(type(near_data) == "table" and near_data.name == nil,
	"near mob did not serialize current state")

local far = entity_at(128)
local far_data = far:mob_staticdata()
want(removed == 1, "far mob was not removed by the production unload path")
want(type(far_data) == "table" and far_data.remove_ok == true and
		far_data.static_save == true, "far mob tombstone differs")

io.write("spawn_despawn\tPASS\tmin=48\tmax=128\tnearest-player\tunload-path\n")
