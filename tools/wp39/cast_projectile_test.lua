-- Plain-Lua-5.1 real-code test for hostile cast authority and Fireball use.

local repo = arg[1] or "."
local now = 0
local callbacks = {join = {}, leave = {}, die = {}, respawn = {}}
local ray_results = {}
local ray_calls = 0
local damage_events = {}
local heal_events = {}
local absorb_events = {}
local particle_events = 0
local radius_objects = {}
local root_events = {}
local slow_events = {}
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
	add_particle = function() particle_events = particle_events + 1 end,
	add_particlespawner = function() particle_events = particle_events + 1 end,
	get_objects_inside_radius = function() return radius_objects end,
	get_node_or_nil = function() return {name = "air"} end,
	colorize = function(_, text) return text end,
	chat_send_player = function() end,
}

local class_callbacks = {}
grug_classes = {
	-- Round 4 (WP11 phase 1): abilities and the HUD read talent bonuses; 0 = untalented.
	get_talent_bonus = function() return 0 end,
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
grug_mobs = {
	is_noncombatant = function(ent)
		return type(ent) == "table" and ent._grug_noncombatant == true
	end,
	root = function(ent)
		root_events[#root_events + 1] = ent
	end,
	slow = function(ent)
		slow_events[#slow_events + 1] = ent
	end,
}
grug_projectiles = {
	register = function(id, def) projectile_defs[id] = def end,
	spawn = function(id, params)
		projectile_spawns[#projectile_spawns + 1] = {id=id, params=params}
		return projectile_spawn_result
	end,
}

grug_core = {
	base_pool = function(level)
		return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
	end,
	baseline_weapon_damage = function(level)
		return math.floor(4 + 0.35 * level + 0.5)
	end,
	get_player_level = function(player) return player.level or 1 end,
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
	-- Round 4 (WP11 phase 1): Warded Wrath gates on the absorb; 0 = none up.
	get_absorb = function() return 0 end,
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
	set_absorb = function(target, amount, duration)
		absorb_events[#absorb_events + 1] = {
			target=target, amount=amount, duration=duration,
		}
	end,
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
	function obj:get_breath() return 10 end
	function obj:hud_set_flags() end -- round 4: the bars hide the builtin hearts
	function obj:hud_remove() end
	return obj
end

local function mob(name, faction, noncombatant)
	local ent = {name=name, _cmi_is_mob=true, _grug_faction=faction,
		health=20, attack_type="dogfight", taunted=0,
		_grug_noncombatant=noncombatant == true}
	function ent:do_attack() self.taunted = self.taunted + 1 end
	local obj = {ent=ent, pos={x=3,y=0,z=0}}
	function obj:is_player() return false end
	function obj:get_pos() return self.pos end
	function obj:get_luaentity() return self.ent end
	return obj
end

-- Round 4 (HUD bars): grug_abilities builds its bars from
-- grug_core.hud_layout at join; the real file calls nothing from core.
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/PLAYER/grug_abilities/init.lua")
assert(projectile_defs.fireball and projectile_defs.fireball.speed == 20)
assert(projectile_defs.fireball.max_distance == 20
	and projectile_defs.fireball.lifetime > 1
	and projectile_defs.fireball.active_limit == 8)

local EXPECTED_TARGET_KIND = {
	strike="hostile", charge="hostile", mighty_blow="hostile",
	hamstring="hostile", taunt="hostile", fireball="hostile",
	frost_nova="self", blink="self", smite="hostile",
	flash_heal="friendly", power_word_shield="friendly", renew="friendly",
}
for id, expected in pairs(EXPECTED_TARGET_KIND) do
	assert(grug_abilities.registered[id].target_kind == expected,
		id .. " target_kind is " .. tostring(grug_abilities.registered[id].target_kind))
end

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
assert(damage_events[1].amount == 12)
assert(grug_abilities.get_mana(mage) == mana_before - 1)
assert(not grug_abilities.ready(mage, "smite"))

-- Even a malformed combat-ray result cannot make a hostile ability accept a
-- friendly target: target_kind is revalidated by the ability layer.
local hostile_gate = player("hostile_gate", "priest", "accord")
local friendly_ray = player("friendly_ray", "warrior", "accord")
join(hostile_gate)
mana_before = grug_abilities.get_mana(hostile_gate)
local damage_before_friendly = #damage_events
ray_results = {{status="target", reason="hostile", target=friendly_ray,
	object_kind="player", relation="hostile", distance=3, range=20}}
grug_abilities.try_cast(hostile_gate, smite, nil)
assert(#damage_events == damage_before_friendly)
assert(grug_abilities.get_mana(hostile_gate) == mana_before)
assert(grug_abilities.ready(hostile_gate, "smite"))

-- A factionless civilian is never a hostile target, even if a malformed ray
-- labels it hostile. Charge must not move, grant rage, deal damage or arm its
-- cooldown; the same central predicate also owns hostile area selection.
local civilian = mob("test:civilian", nil, true)
local civilian_gate = player("civilian_gate", "warrior", "accord")
join(civilian_gate)
local civilian_pos = vector.new(civilian_gate:get_pos())
local damage_before_civilian = #damage_events
ray_results = {{status="target", reason="hostile", target=civilian,
	object_kind="mob", relation="hostile", distance=3, range=12}}
grug_abilities.try_cast(civilian_gate,
	grug_abilities.registered.charge, nil)
assert(grug_abilities.ready(civilian_gate, "charge"))
assert(grug_abilities.get_rage(civilian_gate) == 0)
assert(vector.distance(civilian_gate:get_pos(), civilian_pos) == 0)
assert(#damage_events == damage_before_civilian)

local nova_caster = player("civilian_nova", "mage", "accord")
local nova_hostile = mob("test:nova_hostile", "throng")
join(nova_caster)
radius_objects = {civilian, nova_hostile}
local roots_before = #root_events
local slows_before = #slow_events
grug_abilities.try_cast(nova_caster,
	grug_abilities.registered.frost_nova,
	{type="object", ref=civilian})
radius_objects = {}
assert(#root_events == roots_before + 1
	and root_events[#root_events] == nova_hostile.ent)
assert(#slow_events == slows_before + 1
	and slow_events[#slow_events] == nova_hostile.ent)

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

-- An explicitly supplied invalid object falls through to ally memory, then
-- self. All three friendly abilities share heal_target, so verify the
-- resolved target, resource spend and cooldown for both fallback paths.
local hostile_pointed = mob("test:hostile_heal_probe", "throng")
local friendly_cost = {flash_heal = 2, power_word_shield = 2, renew = 2}
local old_get_player_by_name = core.get_player_by_name
local friendly_players = {ally = ally}
core.get_player_by_name = function(name)
	return friendly_players[name]
end

local function assert_friendly_effect(id, target, heals_before,
		absorbs_before, particles_before)
	if id == "flash_heal" then
		assert(#heal_events == heals_before + 1
			and heal_events[#heal_events].target == target,
			id .. " did not heal the resolved target")
	elseif id == "power_word_shield" then
		assert(#absorb_events == absorbs_before + 1
			and absorb_events[#absorb_events].target == target,
			id .. " did not shield the resolved target")
	else
		local renew_heals_before = #heal_events
		globalsteps[#globalsteps](3)
		local found_target = false
		for index = renew_heals_before + 1, #heal_events do
			if heal_events[index].target == target then
				found_target = true
			end
		end
		assert(found_target, id .. " did not renew the resolved target")
	end
	assert(particle_events > particles_before,
		id .. " produced no effect particles")
end

for _, id in ipairs({"flash_heal", "power_word_shield", "renew"}) do
	local probe_priest = player("explicit_memory_" .. id,
		"priest", "accord")
	join(probe_priest)
	friendly_players[probe_priest:get_player_name()] = probe_priest
	grug_abilities.set_target(probe_priest, ally, true)
	local probe_mana = grug_abilities.get_mana(probe_priest)
	local heals_before_probe = #heal_events
	local absorbs_before_probe = #absorb_events
	local particles_before_probe = particle_events
	grug_abilities.try_cast(probe_priest, grug_abilities.registered[id],
		{type="object", ref=hostile_pointed})
	assert(grug_abilities.get_mana(probe_priest)
		== probe_mana - friendly_cost[id],
		id .. " did not spend mana after resolving ally memory")
	assert(not grug_abilities.ready(probe_priest, id),
		id .. " did not arm cooldown after resolving ally memory")
	assert_friendly_effect(id, ally, heals_before_probe,
		absorbs_before_probe, particles_before_probe)
end

for _, id in ipairs({"flash_heal", "power_word_shield", "renew"}) do
	local probe_priest = player("explicit_self_" .. id, "priest", "accord")
	join(probe_priest)
	friendly_players[probe_priest:get_player_name()] = probe_priest
	local probe_mana = grug_abilities.get_mana(probe_priest)
	local heals_before_probe = #heal_events
	local absorbs_before_probe = #absorb_events
	local particles_before_probe = particle_events
	grug_abilities.try_cast(probe_priest, grug_abilities.registered[id],
		{type="object", ref=hostile_pointed})
	assert(grug_abilities.get_mana(probe_priest)
		== probe_mana - friendly_cost[id],
		id .. " did not spend mana after resolving self")
	assert(not grug_abilities.ready(probe_priest, id),
		id .. " did not arm cooldown after resolving self")
	assert_friendly_effect(id, probe_priest, heals_before_probe,
		absorbs_before_probe, particles_before_probe)
end

-- A dead resolved self is the remaining refusal: no resource, cooldown or
-- observable effect is committed.
for _, id in ipairs({"flash_heal", "power_word_shield", "renew"}) do
	local probe_priest = player("explicit_dead_" .. id, "priest", "accord")
	probe_priest.hp = 0
	join(probe_priest)
	local probe_mana = grug_abilities.get_mana(probe_priest)
	local heals_before_probe = #heal_events
	local absorbs_before_probe = #absorb_events
	local particles_before_probe = particle_events
	grug_abilities.try_cast(probe_priest, grug_abilities.registered[id],
		{type="object", ref=hostile_pointed})
	assert(grug_abilities.get_mana(probe_priest) == probe_mana,
		id .. " spent mana on a dead resolved target")
	assert(grug_abilities.ready(probe_priest, id),
		id .. " armed cooldown on a dead resolved target")
	assert(#heal_events == heals_before_probe
		and #absorb_events == absorbs_before_probe
		and particle_events == particles_before_probe,
		id .. " affected a dead resolved target")
end
core.get_player_by_name = old_get_player_by_name
print("friendly_explicit_target_test: PASS invalid=memory-or-self dead=no-cost/no-cooldown")

-- Self-targeted abilities never receive client pointing context, even if a
-- future closure tries to inspect it.
local self_called, self_pointed = false, false
grug_abilities.register_ability({
	id="kat_self_target", class="mage", name="KAT Self Target", kind="cast",
	target_kind="self", description="fixture", color="#ffffff", cost={},
	cooldown=0, range=4,
	cast=function(_, pointed)
		self_called = true
		self_pointed = pointed
		return true
	end,
})
local self_caster = player("self_gate", "mage", "accord")
join(self_caster)
grug_abilities.try_cast(self_caster,
	grug_abilities.registered.kat_self_target,
	{type="object", ref=hostile_pointed})
assert(self_called, "self-targeted cast did not run")
assert(self_pointed == nil, "self-targeted cast received an external target")
print("target_kind_test: PASS friendly-falls-back hostile-refuses-friendly/noncombatant self-ignores-target")

-- Fireball snapshots eye/look/damage, runs no combat ray and costs 6% base mana on any
-- successfully spawned flight (air/wall/range are later projectile outcomes).
local function fire_once(name)
	local caster = player(name, "mage", "accord")
	join(caster)
	local rays = ray_calls
	local spawns = #projectile_spawns
	grug_abilities.try_cast(caster, grug_abilities.registered.fireball, nil)
	assert(ray_calls == rays and #projectile_spawns == spawns + 1)
	assert(grug_abilities.get_mana(caster) == 18)
	local spawn = projectile_spawns[#projectile_spawns]
	assert(spawn.id == "fireball" and spawn.params.owner == caster)
	assert(spawn.params.origin.y == 1.5 and spawn.params.direction.x == 1)
	assert(spawn.params.data.damage == 8)
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

-- Insufficient mana refuses before spawn. Ten L1 shots spend the 20-point
-- fixture pool; the eleventh input cannot create an entity.
local empty = player("fire_empty", "mage", "accord")
join(empty)
for _ = 1, 10 do
	grug_abilities.try_cast(empty, grug_abilities.registered.fireball, nil)
end
local spawn_count = #projectile_spawns
grug_abilities.try_cast(empty, grug_abilities.registered.fireball, nil)
assert(grug_abilities.get_mana(empty) == 0)
assert(#projectile_spawns == spawn_count)

-- The consumer applies only its payload snapshot; exactly-once invocation is
-- enforced by the real foundation in projectile_test.lua.
projectile_defs.fireball.on_hit(mage, enemy_ray, {damage=23})
assert(damage_events[#damage_events].amount == 23)

print("cast_projectile_test: ok")
