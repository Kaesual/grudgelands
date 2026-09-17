-- Lane S known-answer test for the real mobs_redo despawn implementation.
-- Plain Lua 5.1; the production api.lua is loaded in an isolated engine stub.

local repo = arg[1] or "."
local start_npcs_path = arg[2] or
	repo .. "/mods/ENTITIES/grug_mobs/start_npcs.lua"

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
		deactivation_calls = 0,
		properties = {hp_max = 10},
		rotation = {x = 0, y = 0, z = 0},
		pos_reads = 0,
	}
	function object:get_pos()
		self.pos_reads = self.pos_reads + 1
		return origin
	end
	function object:remove()
		self.removed = self.removed + 1
		-- Luanti dispatches on_deactivate(true) once before marking the
		-- active object gone. Repeated remove calls do not dispatch it again.
		if not self.deactivated and self.entity then
			self.deactivation_calls = self.deactivation_calls + 1
			self.entity:on_deactivate(true)
			self.deactivated = true
		end
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
	object.entity = entity
	core_stub.get_connected_players = function() return {player_at(distance)} end
	return entity
end

local function engine_staticdata(entity)
	return copy(entity:mob_staticdata())
end

local function engine_deactivate(entity, removal)
	if entity.object.deactivated then return end
	entity.object.deactivation_calls = entity.object.deactivation_calls + 1
	entity:on_deactivate(removal == true)
	entity.object.deactivated = true
end

local function engine_unload(entity)
	local stored = engine_staticdata(entity)
	engine_deactivate(entity, false)
	return stored
end

-- Every accepted activation counts immediately. The engine's initial static
-- data store and a later active resave must both be counter-neutral.
local stag = entity_at(40)
stag:mob_activate("", {}, 0)
want(active_mob_count() == 1, "create did not increment active_mobs once")
local created_data = engine_staticdata(stag)
want(active_mob_count() == 1, "initial staticdata changed active_mobs")
want(created_data.remove_ok == true,
	"initial staticdata did not persist the ordinary stag")
local resaved_data = engine_staticdata(stag)
want(active_mob_count() == 1, "active resave changed active_mobs")
want(resaved_data.name == "grug_mobs:stag",
	"active resave did not persist the ordinary stag")

-- The protected unload debits once, persists the ordinary entity, and does
-- not call ObjectRef:remove(). The engine stores the callback result first
-- and only then deactivates the object.
local protected_data = engine_unload(stag)
want(active_mob_count() == 0,
	"protected unload did not debit active_mobs exactly once")
want(stag.object.removed == 0, "protected unload removed the stag")
want(protected_data.name == "grug_mobs:stag" and
		protected_data._grug_despawn_terminal == nil,
	"protected unload did not persist the ordinary stag")

-- Luanti can reload a static object with dtime_s == 0. It invokes only
-- on_activate, so production mob_activate must count it regardless of dtime.
stag = entity_at(40)
stag:mob_activate(protected_data, {}, 0)
want(active_mob_count() == 1,
	"protected reload did not restore active_mobs exactly once")

-- A far resave stores its terminal result before deactivation but cannot
-- change the count. The following real deactivation performs the sole debit.
core_stub.get_connected_players = function() return {player_at(128)} end
local terminal_data = engine_staticdata(stag)
want(active_mob_count() == 1,
	"far staticdata changed active_mobs before deactivation")
engine_deactivate(stag, false)
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
engine_deactivate(terminal, true)
want(terminal.object.removed == 1,
	"terminal marker was not consumed on activation")
want(terminal.object.properties.static_save == false,
	"terminal removal remained eligible for another static save")
want(active_mob_count() == 0,
	"terminal activation debited active_mobs a second time")

-- Public removal reaches the real remove_mob helper. ObjectRef:remove then
-- dispatches production on_deactivate(true), which performs the sole debit.
local explicit = entity_at(40)
explicit:mob_activate("", {}, 0)
env.mobs:remove(explicit, true)
want(explicit.object.removed == 1 and
		explicit.object.deactivation_calls == 1,
	"mobs:remove did not dispatch one engine deactivation")
want(active_mob_count() == 0,
	"mobs:remove did not debit active_mobs exactly once")

-- The ordinary no-animation death fallback reaches the same real remove_mob
-- helper through production check_for_death.
local dead = entity_at(40)
dead:mob_activate("", {}, 0)
dead.health = 0
want(dead:check_for_death({type = "unknown"}) == true,
	"check_for_death did not accept the lethal state")
want(dead.object.removed == 1 and dead.object.deactivation_calls == 1,
	"check_for_death did not dispatch one engine deactivation")
want(active_mob_count() == 0,
	"check_for_death did not debit active_mobs exactly once")

-- Fill the configured limit with accepted activations. A further creation is
-- rejected before it can be counted; the engine's subsequent initial
-- staticdata call and on_deactivate remain neutral for that rejected object.
local accepted = {}
for index = 1, 600 do
	accepted[index] = entity_at(40)
	accepted[index]:mob_activate("", {}, 0)
end
want(active_mob_count() == 600, "accepted creations did not reach the limit")
local rejected = entity_at(40)
rejected:mob_activate("", {}, 0)
want(rejected.object.removed == 1, "over-limit creation was not rejected")
rejected:mob_staticdata()
want(active_mob_count() == 600, "rejected creation changed active_mobs")
engine_deactivate(rejected, true)
want(active_mob_count() == 600,
	"rejected creation deactivation changed active_mobs")
for index = 1, #accepted do engine_deactivate(accepted[index], true) end
want(active_mob_count() == 0, "accepted creation cleanup leaked active_mobs")

-- Load Lane P's real settlement-NPC wrapper around the already-loaded shared
-- mob callback. One claimed socket is enough to make track_deactivation read
-- the object's position; the shared callback then cleans XP and debits count.
local mods_loaded = {}
core_stub.register_on_mods_loaded = function(callback)
	mods_loaded[#mods_loaded + 1] = callback
end
core_stub.register_globalstep = noop
core_stub.after = noop
core_stub.log = noop
core_stub.pos_to_string = function() return "(0,0,0)" end
core_stub.registered_entities["grug_mobs:villager_human"] = {}

local storage = {
	get_string = function() return "" end,
	set_string = noop,
}
local cleanup_calls = 0
env.grug_mobs = {
	storage = storage,
	registered_cadence = {["grug_mobs:villager_human"] = true},
	cleanup_xp_participants = function()
		cleanup_calls = cleanup_calls + 1
	end,
}
env.grug_core = {
	start_identities = function()
		return {{race_id = "human", faction_id = "accord"}}
	end,
	settlement_socket_settlements = function()
		return {{key = "kat_start", race_id = "human", anchor = origin}}
	end,
	settlement_sockets_at = function()
		return {{id = "kat_socket", role = "idle", spawn = true,
			pos = origin, yaw = 0}}
	end,
	start_anchor = function() return origin end,
	capital_anchor = function() return nil end,
	register_on_starts_progress = noop,
	start_ready = function() return false end,
}
setfenv(assert(loadfile(start_npcs_path)), env)()
want(#mods_loaded == 1, "start_npcs did not register its production loader")
mods_loaded[1]()

local wrapped = entity_at(40, {name = "grug_mobs:villager_human",
	_grug_start = "kat_start", _grug_socket = "kat_socket"})
wrapped:mob_activate("", {}, 0)
want(env.grug_mobs.start_npc_claim(wrapped) == true,
	"wrapper fixture could not claim its production socket")
wrapped.object.pos_reads = 0
engine_deactivate(wrapped, false)
want(wrapped.object.pos_reads == 1,
	"start_npcs tracking did not run exactly once")
want(cleanup_calls == 1,
	"shared XP cleanup did not run exactly once through start_npcs")
want(wrapped.object.deactivation_calls == 1 and active_mob_count() == 0,
	"counter debit did not run exactly once through start_npcs")

io.write("spawn_despawn\tPASS\tmin=48\tmax=128\t" ..
	"create=1\tresave=1\tprotected_unload=0\treload_zero=1\t" ..
	"far=0\tremove=0\tdeath=0\trejected_limit=600\t" ..
	"wrapper_track=1\twrapper_xp=1\twrapper_debit=1\t" ..
	"terminal_absent\n")
