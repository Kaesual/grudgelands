-- Real-code KAT for round 5 R12. The vendored mobs_redo api.lua is loaded
-- unchanged; a raw player tool punch must leave a grug_mobs mob untouched,
-- while an ability punch must still traverse the normal damage settlement.

local repo = arg[1] or "."

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end

table.copy = table.copy or copy

vector = {
	new = function(x, y, z)
		return type(x) == "table" and copy(x) or {x=x or 0, y=y or 0, z=z or 0}
	end,
	add = function(a, b) return {x=a.x+b.x, y=a.y+b.y, z=a.z+b.z} end,
	subtract = function(a, b) return {x=a.x-b.x, y=a.y-b.y, z=a.z-b.z} end,
	multiply = function(a, n) return {x=a.x*n, y=a.y*n, z=a.z*n} end,
	direction = function() return {x=1, y=0, z=0} end,
	distance = function() return 1 end,
}

local players = setmetatable({}, {__mode = "k"})
local registered_entities = {}
local function noop() end
local settings = {
	get = function() return nil end,
	get_bool = function(_, name) return name == "enable_damage" end,
}

core = {
	settings = settings,
	registered_aliases = {},
	registered_nodes = {air={groups={}}, ignore={groups={}}},
	registered_items = {},
	registered_entities = registered_entities,
	get_translator = function()
		return function(text) return text end
	end,
	formspec_escape = function(text) return text end,
	global_exists = function() return false end,
	get_modpath = function(name)
		if name == "mobs" then return repo .. "/mods/ENTITIES/mobs" end
	end,
	check_player_privs = function() return false end,
	is_player = function(obj) return players[obj] == true end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_on_player_receive_fields = noop,
	register_chatcommand = noop,
	register_globalstep = noop,
	log = noop,
	sound_play = noop,
	add_particlespawner = noop,
	after = noop,
	get_objects_inside_radius = function() return {} end,
}
minetest = core

assert(loadfile(repo .. "/mods/ENTITIES/mobs/api.lua"))()

local accepted = 0
local authoritative_token
local authoritative_settlements = 0
grug_mobs = {registered_cadence = {['test:mob'] = true}}
grug_core = {
	in_ability_punch = false,
	claim_authoritative_swing = function() return authoritative_token end,
	authoritative_swing_active = function() return false end,
	handle_native_swing_input = function() return false end,
	handle_ordinary_melee_input = noop,
	prepare_native_melee = function(_, _, fraction, token)
		if not token then return nil end
		assert(token == authoritative_token and fraction == 1,
			"authoritative swing token/fraction was not preserved")
		return {extra_damage = 0, token = token}
	end,
	roll_melee_crit = function(_, damage) return damage, 1, false end,
	get_melee_bonus = function() return 0 end,
	prepare_accumulated_melee = function()
		error("raw punch reached the removed proportional damage path")
	end,
	commit_accumulated_melee = function() return true end,
	finish_native_melee = function(context, result)
		if context then
			assert(context.token == authoritative_token and result.landed,
				"authoritative swing did not land its claimed transaction")
			authoritative_settlements = authoritative_settlements + 1
		end
	end,
	melee_wear_due = function() return false, false end,
	forget_melee_wear = noop,
}
function grug_mobs.accepted_player_punch()
	accepted = accepted + 1
end

local Stack = {}
Stack.__index = Stack
function Stack:get_definition() return {name="test:tool", type="tool"} end
function Stack:get_meta()
	return {get_string=function() return "" end}
end
function Stack:add_wear() end
function Stack:is_empty() return false end

local player_state = {name="kat", pos={x=0,y=0,z=0}}
local hitter = newproxy(true)
local hitter_meta = getmetatable(hitter)
hitter_meta.__index = {
	get_player_name = function() return player_state.name end,
	get_wielded_item = function() return setmetatable({}, Stack) end,
	set_wielded_item = noop,
	get_luaentity = function() return nil end,
	get_pos = function() return copy(player_state.pos) end,
}
players[hitter] = true

local object = {
	get_pos = function() return {x=1,y=0,z=0} end,
	get_armor_groups = function() return {fleshy=100} end,
	get_properties = function()
		return {collisionbox={-0.3, -1, -0.3, 0.3, 1, 0.3},
			damage_texture_modifier="", hp_max=20}
	end,
	get_velocity = function() return nil end,
}

local mob = setmetatable({
	name = "test:mob", object = object, health = 20, old_health = 20,
	protected = false,
	immune_to = {}, blood_amount = 0, blood_texture = "mobs_blood.png",
	knock_back = false, passive = true, friendly_fire = true,
	state = "stand", child = false, owner = "", sounds = {},
	texture_mods = "", order = "", runaway = false,
}, {__index = mobs.mob_class})

local caps = {full_punch_interval=1, punch_attack_uses=0,
	damage_groups={fleshy=7}, groupcaps={}}

local raw_result = mob:on_punch(hitter, 1, caps, {x=1,y=0,z=0}, 7)
assert(raw_result == true, "raw punch did not cancel")
assert(mob.health == 20, "raw punch changed mob health to " .. mob.health)
assert(accepted == 0, "raw punch reached accepted-hit side effects")

grug_core.in_ability_punch = true
local ability_result = mob:on_punch(hitter, 1, caps, {x=1,y=0,z=0}, 7)
grug_core.in_ability_punch = false
assert(ability_result == true, "ability punch did not complete")
assert(mob.health == 13, "ability punch dealt " .. (20 - mob.health) .. ", expected 7")
assert(accepted == 1, "ability punch missed accepted-hit settlement")

-- The server-owned swing uses a claimed opaque token, not the broader
-- in_ability_punch flag. Removing the explicit authoritative bypass from the
-- raw veto must make this case fail.
mob.health, mob.old_health, accepted = 20, 20, 0
authoritative_token = {id="kat-authoritative"}
local swing_result = mob:on_punch(hitter, 1, caps, {x=1,y=0,z=0}, 7)
assert(swing_result == true, "authoritative swing did not complete")
assert(mob.health == 13,
	"authoritative swing dealt " .. (20 - mob.health) .. ", expected 7")
assert(accepted == 1, "authoritative swing missed accepted-hit settlement")
assert(authoritative_settlements == 1,
	"authoritative swing transaction was not settled exactly once")
authoritative_token = nil

print("raw_mob_punch_veto_test: PASS raw_hp=20 ability_hp=13 swing_hp=13 swing_settled=1")
