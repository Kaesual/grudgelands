-- Plain-Lua-5.1 real-code test for hostile cast authority and Fireball use.

local repo = arg[1] or "."
local now = 0
local callbacks = {join = {}, leave = {}, die = {}, respawn = {}}
local ray_results = {}
local ray_calls = 0
local damage_events = {}
local heal_events = {}
local projectile_defs = {}
local projectile_spawns = {}
local projectile_spawn_result = true

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
function vector.add(a, b) return {x = a.x+b.x, y = a.y+b.y, z = a.z+b.z} end
function vector.subtract(a, b) return {x = a.x-b.x, y = a.y-b.y, z = a.z-b.z} end
function vector.multiply(a, n) return {x = a.x*n, y = a.y*n, z = a.z*n} end
function vector.offset(a, x, y, z) return {x = a.x+x, y = a.y+y, z = a.z+z} end
function vector.distance(a, b)
	local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z
	return math.sqrt(x*x+y*y+z*z)
end
function vector.length(a) return vector.distance(a, {x=0,y=0,z=0}) end
function vector.normalize(a)
	local length = vector.length(a)
	return length > 0 and {x=a.x/length,y=a.y/length,z=a.z/length}
		or {x=0,y=0,z=0}
end
function vector.direction(a, b) return vector.normalize(vector.subtract(b, a)) end
function vector.round(a) return vector.new(a) end

local Stack = {}
Stack.__index = Stack
function ItemStack(value)
	local stack = setmetatable({name = "", wear = 0, strings = {}, floats = {}}, Stack)
	if getmetatable(value) == Stack then
		stack.name, stack.wear, stack.caps = value.name, value.wear, value.caps
		for key, item in pairs(value.strings) do stack.strings[key] = item end
		for key, item in pairs(value.floats) do stack.floats[key] = item end
	elseif type(value) == "string" then
		stack.name = value
	end
	return stack
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:equals(other) return self.name == other.name end
function Stack:get_wear() return self.wear end
function Stack:set_wear(value) self.wear = value end
function Stack:get_definition() return core.registered_items[self.name] or {} end
function Stack:get_tool_capabilities()
	return self.caps or {full_punch_interval=0.9, damage_groups={fleshy=1}}
end
function Stack:get_meta()
	local owner = self
	return {
		get_string = function(_, key) return owner.strings[key] or "" end,
		set_string = function(_, key, value) owner.strings[key] = value end,
		get_float = function(_, key) return owner.floats[key] or 0 end,
		set_float = function(_, key, value) owner.floats[key] = value end,
		set_tool_capabilities = function(_, value) owner.caps = value end,
		set_wear_bar_params = function() end,
	}
end

local globalsteps = {}
core = {
	registered_items = {}, registered_nodes = {},
	get_us_time = function() return now end,
	get_current_modname = function() return "grug_abilities" end,
	get_modpath = function(name)
		if name == "grug_abilities" then
			return repo .. "/mods/PLAYER/grug_abilities"
		end
		return repo .. "/mods/CORE/grug_core"
	end,
	register_tool = function(name, def)
		def.type = "tool"
		core.registered_items[name] = def
	end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_respawnplayer = function(fn)
		callbacks.respawn[#callbacks.respawn + 1] = fn
	end,
	register_on_player_hpchange = function() end,
	register_on_punchplayer = function() end,
	register_on_mods_loaded = function() end,
	register_on_player_inventory_action = function() end,
	register_allow_player_inventory_action = function() end,
	get_connected_players = function() return {} end,
	get_player_by_name = function() return nil end,
	global_exists = function() return false end,
	after = function() end,
	log = function() end,
	add_particle = function() end,
	add_particlespawner = function() end,
	get_objects_inside_radius = function() return {} end,
	get_node_or_nil = function() return {name = "air"} end,
	colorize = function(_, text) return text end,
	chat_send_player = function() end,
}

local class_callbacks = {}
grug_classes = {
	registered_classes = {
		warrior={name="Warrior"}, mage={name="Mage"}, priest={name="Priest"},
	},
	get_class = function(player) return player.class end,
	get_class_def = function(player)
		return player.class == "warrior" and {resource="rage"}
			or (player.class and {resource="mana"} or nil)
	end,
	get_max_mana = function() return 20 end,
	get_race_perk = function() return nil end,
	get_melee_bonus = function() return 0 end,
	get_spell_power_bonus = function() return 4 end,
	register_on_class_chosen = function(fn) class_callbacks[#class_callbacks + 1] = fn end,
}

grug_factions = {
	get_faction = function(obj) return obj.faction end,
	same_faction = function(a, b)
		return a.faction ~= nil and a.faction == b.faction
	end,
	hostile = function(a, b)
		return a.faction ~= nil and b.faction ~= nil and a.faction ~= b.faction
	end,
}
grug_xp = {register_on_level_change = function() end}
grug_mobs = {slow = function() end, root = function() end}
grug_projectiles = {
	register = function(id, def) projectile_defs[id] = def end,
	spawn = function(id, params)
		projectile_spawns[#projectile_spawns + 1] = {id=id, params=params}
		return projectile_spawn_result
	end,
}

grug_core = {
	get_equipped_weapon = function() return ItemStack("") end,
	get_equipped_offhand = function() return ItemStack("") end,
	reset_accumulated_melee = function() end,
	register_native_melee_handler = function() end,
	register_native_swing_input_handler = function() end,
	register_ordinary_melee_input_handler = function() end,
	register_on_equipment_change = function() end,
	register_on_player_hit_mob = function() end,
	authoritative_swing_active = function() return false end,
	in_ability_punch = false,
	in_combat = function() return false end,
	invalidate_melee_target = function() end,
	combat_debug_enabled = function() return false end,
	combat_debug_due = function() error("disabled cast debug reached due gate") end,
	combat_debug_log = function() error("disabled cast debug logged") end,
	combat_ray = function()
		ray_calls = ray_calls + 1
		local result = table.remove(ray_results, 1)
		return result or {status="aim_miss", reason="empty", range=20}
	end,
	combat_eye_pos = function(player)
		return vector.offset(player:get_pos(), 0, 1.5, 0)
	end,
	deal_ability_damage = function(owner, target, amount)
		damage_events[#damage_events + 1] = {
			owner=owner, target=target, amount=amount,
		}
		return amount
	end,
	heal_player = function(owner, target, amount)
		heal_events[#heal_events + 1] = {owner=owner,target=target,amount=amount}
		return amount
	end,
	set_absorb = function() end,
	taunt = function() end,
	mark_in_combat = function() end,
}

local function inventory()
	local inv = {main = {}}
	for i = 1, 32 do inv.main[i] = ItemStack("") end
	function inv:get_lists() return {main=self.main} end
	function inv:get_list(name) return self[name] end
	function inv:get_size(name) return #self[name] end
	function inv:get_stack(name, index) return ItemStack(self[name][index]) end
	function inv:set_stack(name, index, stack) self[name][index] = ItemStack(stack) end
	function inv:add_item(name, stack)
		for i, current in ipairs(self[name]) do
			if current:is_empty() then self[name][i] = ItemStack(stack); return ItemStack("") end
		end
		return ItemStack(stack)
	end
	return inv
end

local function player(name, class, faction)
	local obj = {name=name, class=class, faction=faction, hp=20,
		pos={x=0,y=0,z=0}, dir={x=1,y=0,z=0}, inv=inventory(), hud=0}
	function obj:get_player_name() return self.name end
	function obj:get_hp() return self.hp end
	function obj:get_pos() return self.pos end
	function obj:set_pos(value) self.pos = vector.new(value) end
	function obj:get_properties() return {eye_height=1.5} end
	function obj:get_look_dir() return self.dir end
	function obj:is_player() return true end
	function obj:get_luaentity() return nil end
	function obj:get_inventory() return self.inv end
	function obj:get_wielded_item() return ItemStack("") end
	function obj:get_wield_index() return 1 end
	function obj:hud_add() self.hud=self.hud+1; return self.hud end
	function obj:hud_change() end
	return obj
end

local function mob(name, faction)
	local ent = {name=name, _cmi_is_mob=true, _grug_faction=faction,
		health=20, attack_type="dogfight", taunted=0}
	function ent:do_attack() self.taunted = self.taunted + 1 end
	local obj = {ent=ent, pos={x=3,y=0,z=0}}
	function obj:is_player() return false end
	function obj:get_pos() return self.pos end
	function obj:get_luaentity() return self.ent end
	return obj
end

dofile(repo .. "/mods/PLAYER/grug_abilities/init.lua")
assert(projectile_defs.fireball and projectile_defs.fireball.speed == 20)
assert(projectile_defs.fireball.max_distance == 20
	and projectile_defs.fireball.lifetime > 1)

local function join(obj)
	for _, callback in ipairs(callbacks.join) do callback(obj) end
end

local enemy_memory = mob("test:remembered", "throng")
local enemy_ray = mob("test:current", "throng")
local mage = player("smiter", "priest", "accord")
join(mage)
grug_abilities.set_target(mage, enemy_memory, false)

-- A remembered or client-pointed hostile cannot authorize Smite. The one
-- server ray misses, so try_cast spends nothing and arms no cooldown.
local smite = grug_abilities.registered.smite
local mana_before = grug_abilities.get_mana(mage)
ray_results = {{status="aim_miss", reason="empty", range=20}}
local before_rays = ray_calls
grug_abilities.try_cast(mage, smite, {type="object", ref=enemy_memory})
assert(ray_calls == before_rays + 1,
	"smite ray count " .. ray_calls .. " from " .. before_rays ..
	" mana=" .. grug_abilities.get_mana(mage))
assert(grug_abilities.get_mana(mage) == mana_before)
assert(grug_abilities.ready(mage, "smite") and #damage_events == 0)

-- Current ray target wins even when pointed_thing names a different target.
ray_results = {{status="target", reason="hostile", target=enemy_ray,
	object_kind="mob", relation="hostile", distance=3, range=20}}
grug_abilities.try_cast(mage, smite, {type="object", ref=enemy_memory})
assert(#damage_events == 1 and damage_events[1].target == enemy_ray)
assert(damage_events[1].amount == 8)
assert(grug_abilities.get_mana(mage) == mana_before - 4)
assert(not grug_abilities.ready(mage, "smite"))

-- Charge and Taunt each run one current ray; misses retain their cooldown.
local warrior = player("warrior", "warrior", "accord")
join(warrior)
local charge = grug_abilities.registered.charge
ray_results = {{status="aim_miss", reason="node", range=12}}
before_rays = ray_calls
grug_abilities.try_cast(warrior, charge, {type="object", ref=enemy_memory})
assert(ray_calls == before_rays + 1 and grug_abilities.ready(warrior, "charge"))
ray_results = {{status="target", reason="hostile", target=enemy_ray,
	object_kind="mob", relation="hostile", distance=3, range=12}}
grug_abilities.try_cast(warrior, charge, nil)
assert(not grug_abilities.ready(warrior, "charge"))

local taunter = player("taunter", "warrior", "accord")
join(taunter)
local taunt = grug_abilities.registered.taunt
ray_results = {{status="target", reason="hostile", target=enemy_ray,
	object_kind="mob", relation="hostile", distance=3, range=8}}
before_rays = ray_calls
grug_abilities.try_cast(taunter, taunt, nil)
assert(ray_calls == before_rays + 1 and enemy_ray.ent.taunted == 1)
assert(not grug_abilities.ready(taunter, "taunt"))

-- Friendly ally memory remains the implicit heal target.
local priest = player("priest", "priest", "accord")
local ally = player("ally", "warrior", "accord")
ally.pos = {x=4,y=0,z=0}
join(priest)
grug_abilities.set_target(priest, ally, true)
grug_abilities.try_cast(priest, grug_abilities.registered.flash_heal, nil)
assert(#heal_events == 1 and heal_events[1].target == ally)

-- Fireball snapshots eye/look/damage, runs no combat ray and costs 8 on any
-- successfully spawned flight (air/wall/range are later projectile outcomes).
local function fire_once(name)
	local caster = player(name, "mage", "accord")
	join(caster)
	local rays = ray_calls
	local spawns = #projectile_spawns
	grug_abilities.try_cast(caster, grug_abilities.registered.fireball, nil)
	assert(ray_calls == rays and #projectile_spawns == spawns + 1)
	assert(grug_abilities.get_mana(caster) == 12)
	local spawn = projectile_spawns[#projectile_spawns]
	assert(spawn.id == "fireball" and spawn.params.owner == caster)
	assert(spawn.params.origin.y == 1.5 and spawn.params.direction.x == 1)
	assert(spawn.params.data.damage == 10)
	return caster, spawn
end

fire_once("fire_air")
fire_once("fire_wall")
fire_once("fire_range")

-- A failed engine spawn is not a cast and costs zero.
local failed = player("fire_failed", "mage", "accord")
join(failed)
projectile_spawn_result = false
mana_before = grug_abilities.get_mana(failed)
grug_abilities.try_cast(failed, grug_abilities.registered.fireball, nil)
assert(grug_abilities.get_mana(failed) == mana_before)
projectile_spawn_result = true

-- Insufficient mana refuses before spawn. Two shots leave four mana; the
-- third input cannot create an entity.
local empty = player("fire_empty", "mage", "accord")
join(empty)
grug_abilities.try_cast(empty, grug_abilities.registered.fireball, nil)
grug_abilities.try_cast(empty, grug_abilities.registered.fireball, nil)
local spawn_count = #projectile_spawns
grug_abilities.try_cast(empty, grug_abilities.registered.fireball, nil)
assert(grug_abilities.get_mana(empty) == 4)
assert(#projectile_spawns == spawn_count)

-- The consumer applies only its payload snapshot; exactly-once invocation is
-- enforced by the real foundation in projectile_test.lua.
projectile_defs.fireball.on_hit(mage, enemy_ray, {damage=23})
assert(damage_events[#damage_events].amount == 23)

print("cast_projectile_test: ok")
