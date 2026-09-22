-- Bounded real-module checks for the Round 16 XP command and kill settlement.

local root = arg[1] or "."
local commands, players, callbacks = {}, {}, {die = {}, join = {}, leave = {}}
local function noop() end

core = {
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_chatcommand = function(name, def) commands[name] = def end,
	get_player_by_name = function(name) return players[name] end,
	check_player_privs = function(name) return name == "admin" end,
	chat_send_player = noop,
	colorize = function(_, text) return text end,
	is_player = function(object) return object and object:is_player() end,
	get_mod_storage = function() return {} end,
	get_current_modname = function() return "grug_mobs" end,
	get_modpath = function(name) return root .. "/mods/ENTITIES/" .. name end,
}
setmetatable(core, {__index = function(target, key)
	rawset(target, key, noop)
	return noop
end})

grug_core = {
	hud_layout = {
		XP_WIDTH = 360, COLOR = {track = 0, xp = 0},
		rows = {xp = {height = 6}},
		bar_fill = function(value, maximum, width)
			return math.floor(value / maximum * width + 0.5)
		end,
		bar_element = function() return {} end,
		xp_label = function(text) return {text = text} end,
	},
	zone_authority_installed = function() return true end,
	register_on_effective_heal = noop,
	register_tag_visibility = noop,
	remove_tag_carrier = noop,
	create_tag_carrier = function() return nil end,
}
grug_classes = {get_xp_bonus = function(_, source)
	return source == "kill" and 1.1 or 1
end}

local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return self[key] or 0 end
function Meta:set_int(key, value) self[key] = value end

local function player(name, xp, pos, faction)
	local result = {name = name, meta = setmetatable({}, Meta), pos = pos,
		faction = faction}
	result.meta["grug_xp:xp"] = xp
	function result:is_player() return true end
	function result:get_player_name() return self.name end
	function result:get_meta() return self.meta end
	function result:get_pos() return self.pos end
	function result:hud_change() end
	function result:hud_add(definition)
		self.hud = self.hud or {}
		self.hud[#self.hud + 1] = definition
		return #self.hud
	end
	players[name] = result
	return result
end

dofile(root .. "/mods/PLAYER/grug_xp/init.lua")
local admin = player("admin", 0, {x = 0, y = 0, z = 0}, "accord")
local recipient = player("recipient", 100, {x = 0, y = 0, z = 0}, "accord")
local command = assert(commands.xp)
local ok = command.func("admin", "give recipient 25")
assert(ok and grug_xp.get_xp(recipient) == 125)
callbacks.join[1](recipient)
assert(recipient.hud[3].text == "Lv 2 (25/300)")
assert(not command.func("recipient", "give admin 25"))
assert(not command.func("admin", "give recipient 1.5"))
assert(not command.func("admin", "give missing 1"))

local mobs = {mob_class = {}}
local mob_env
local function mob_dofile(path)
	if path == root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua" then
		local spawn_chunk = assert(loadfile(path))
		setfenv(spawn_chunk, mob_env)
		return spawn_chunk()
	end
end
mob_env = setmetatable({
	core = core, mobs = mobs, vector = {}, grug_core = grug_core,
	grug_xp = grug_xp,
	grug_factions = {same_faction = function(target, object)
		local entity = object:get_luaentity()
		return target.faction == entity._grug_faction
	end},
	dofile = mob_dofile,
}, {__index = _G})
local chunk = assert(loadfile(root .. "/mods/ENTITIES/grug_mobs/init.lua"))
setfenv(chunk, mob_env)
chunk()
local api = mob_env.grug_mobs
api.kill_xp = function() return 100 end

local alice = player("alice", 8100, {x = 0, y = 0, z = 0}, "accord")
local bob = player("bob", 8100, {x = 2, y = 0, z = 0}, "accord")
local far = player("far", 8100, {x = 41, y = 0, z = 0}, "accord")
local quest_credit = 0
api.register_on_eligible_kill(function() quest_credit = quest_credit + 1 end)
local entity = {_grug_level = 10, _grug_faction = "throng", temp = {
	grug_xp_participants = {alice = true, bob = true, far = true}}}
entity.object = {
	get_pos = function() return {x = 0, y = 0, z = 0} end,
	get_luaentity = function() return entity end,
}
assert(api.award_kill_xp(entity))
-- 100 * 1.5 / two eligible recipients = 75, then the existing 10% racial bonus.
assert(grug_xp.get_xp(alice) == 8183 and grug_xp.get_xp(bob) == 8183)
assert(grug_xp.get_xp(far) == 8100 and quest_credit == 2)
assert(not api.award_kill_xp(entity))

local gray = player("gray", 10000, {x = 0, y = 0, z = 0}, "accord")
local gray_entity = {_grug_level = 1, _grug_faction = "throng", temp = {
	grug_xp_participants = {gray = true}}}
gray_entity.object = {
	get_pos = function() return {x = 0, y = 0, z = 0} end,
	get_luaentity = function() return gray_entity end,
}
assert(api.award_kill_xp(gray_entity) and grug_xp.get_xp(gray) == 10000)

io.write("runtime=admin+kill;grant=25;split=75;racial=83;eligible=2;gray=0\n")
