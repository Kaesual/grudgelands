-- Plain-Lua-5.1 integration test for WP39's real Core + ability combat paths.
-- Engine APIs and lower/adjacent mods are mocked; combat.lua, combat_ray.lua,
-- grug_abilities/init.lua and kits.lua are loaded unchanged.

local repo = arg[1] or "."
local now = 0
local connected = {}
local players_by_name = {}
local ray_queue = {}
local ray_calls = 0
local globalsteps = {}
local logs = {}
local callbacks = {
	join = {}, leave = {}, die = {}, respawn = {}, hpchange = {},
	punchplayer = {}, mods_loaded = {}, equipment = {},
}

local function copy_table(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		if type(value) == "table" then
			copy[key] = copy_table(value)
		else
			copy[key] = value
		end
	end
	return copy
end

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then
		return {x = x.x, y = x.y, z = x.z}
	end
	return {x = x, y = y, z = z}
end
function vector.add(a, b)
	return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end
function vector.subtract(a, b)
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
end
function vector.multiply(a, number)
	return {x = a.x * number, y = a.y * number, z = a.z * number}
end
function vector.offset(a, x, y, z)
	return {x = a.x + x, y = a.y + y, z = a.z + z}
end
function vector.distance(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end
function vector.length(a)
	return vector.distance(a, {x = 0, y = 0, z = 0})
end
function vector.normalize(a)
	local length = vector.length(a)
	if length <= 0 then
		return {x = 0, y = 0, z = 0}
	end
	return {x = a.x / length, y = a.y / length, z = a.z / length}
end
function vector.direction(a, b)
	return vector.normalize(vector.subtract(b, a))
end
function vector.round(a)
	return vector.new(a)
end
function vector.equals(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z
end

local Stack = {}
Stack.__index = Stack

function ItemStack(value)
	local stack = setmetatable({name = "", wear = 0, meta = {}}, Stack)
	if getmetatable(value) == Stack then
		stack.name = value.name
		stack.wear = value.wear
		stack.meta = copy_table(value.meta)
		stack.caps = value.caps and copy_table(value.caps) or nil
	elseif type(value) == "string" then
		stack.name = value
	end
	return stack
end

function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:set_wear(value) self.wear = value end
function Stack:get_definition() return core.registered_items[self.name] or {} end
function Stack:get_tool_capabilities()
	local def = self:get_definition()
	return self.caps or def.tool_capabilities or {
		full_punch_interval = 0.9,
		damage_groups = {fleshy = 1},
	}
end
function Stack:equals(other)
	return self.name == other.name and self.wear == other.wear
		and (self.meta.variant or "") == (other.meta.variant or "")
end
function Stack:get_meta()
	local owner = self
	return {
		get_string = function(_, key) return owner.meta[key] or "" end,
		set_string = function(_, key, value) owner.meta[key] = value end,
		get_float = function(_, key) return tonumber(owner.meta[key]) or 0 end,
		set_float = function(_, key, value) owner.meta[key] = value end,
		set_tool_capabilities = function(_, caps) owner.caps = copy_table(caps) end,
		set_wear_bar_params = function(_, params)
			owner.meta.wear_bar = copy_table(params)
		end,
	}
end

local function ray_iterator(hits)
	local index = 0
	local function next_hit()
		index = index + 1
		return hits[index]
	end
	return setmetatable({}, {
		__call = function() return next_hit() end,
		__index = {next = next_hit},
	})
end

core = {
	registered_items = {
		[""] = {type = "none", tool_capabilities = {
			full_punch_interval = 0.9, damage_groups = {fleshy = 1},
		}},
		["test:weapon_a"] = {type = "tool", inventory_image = "a.png",
			tool_capabilities = {full_punch_interval = 1,
				damage_groups = {fleshy = 6}}},
		["test:weapon_b"] = {type = "tool", inventory_image = "b.png",
			tool_capabilities = {full_punch_interval = 1.5,
				damage_groups = {fleshy = 8}}},
		["test:ordinary"] = {type = "tool", inventory_image = "tool.png",
			tool_capabilities = {full_punch_interval = 1,
				damage_groups = {fleshy = 1}}},
	},
	registered_nodes = {
		air = {walkable = false},
		stone = {walkable = true},
	},
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
	register_on_player_hpchange = function(fn, modifier)
		callbacks.hpchange[#callbacks.hpchange + 1] = {
			fn = fn, modifier = modifier == true,
		}
	end,
	register_on_punchplayer = function(fn)
		callbacks.punchplayer[#callbacks.punchplayer + 1] = fn
	end,
	register_on_mods_loaded = function(fn)
		callbacks.mods_loaded[#callbacks.mods_loaded + 1] = fn
	end,
	register_on_player_inventory_action = function() end,
	register_allow_player_inventory_action = function() end,
	get_connected_players = function() return connected end,
	get_player_by_name = function(name) return players_by_name[name] end,
	global_exists = function() return false end,
	is_player = function(obj) return obj and obj:is_player() or false end,
	raycast = function()
		ray_calls = ray_calls + 1
		return ray_iterator(table.remove(ray_queue, 1) or {})
	end,
	get_node_or_nil = function(pos) return {name = pos.name or "stone"} end,
	line_of_sight = function() return true end,
	get_objects_inside_radius = function() return {} end,
	after = function() end,
	chat_send_player = function() end,
	colorize = function(_, text) return text end,
	add_particle = function() end,
	add_particlespawner = function() end,
	log = function(level, message)
		logs[#logs + 1] = level .. ":" .. message
	end,
}

grug_core = {}

local class_callbacks = {}
grug_classes = {
	registered_classes = {
		warrior = {name = "Warrior"},
		mage = {name = "Mage"},
		priest = {name = "Priest"},
	},
	get_class = function(player) return player.class_id end,
	get_class_def = function(player)
		local resource = player.class_id == "warrior" and "rage" or "mana"
		return {resource = resource}
	end,
	get_max_mana = function() return 100 end,
	get_race_perk = function() return nil end,
	get_melee_bonus = function() return 0 end,
	get_spell_power_bonus = function() return 0 end,
	register_on_class_chosen = function(fn)
		class_callbacks[#class_callbacks + 1] = fn
	end,
}

grug_factions = {}
function grug_factions.get_faction(obj) return obj and obj.faction or nil end
function grug_factions.same_faction(a, b)
	return a and b and a.faction ~= nil and a.faction == b.faction
end
function grug_factions.hostile(a, b)
	return a and b and a.faction ~= nil and b.faction ~= nil
		and a.faction ~= b.faction
end

grug_xp = {register_on_level_change = function() end}
local slows = 0
grug_mobs = {
	slow = function() slows = slows + 1 end,
	root = function() end,
}
-- T5's projectile implementation has its own real-code test. This integration
-- loader stubs only its public consumer boundary so the ability kit can load.
local projectile_defs = {}
local projectile_spawns = {}
local projectile_spawn_ok = true
grug_projectiles = {
	spawn = function(id, params)
		projectile_spawns[#projectile_spawns + 1] = {id = id, params = params}
		return projectile_spawn_ok
	end,
	register = function(id, def) projectile_defs[id] = def end,
}

local Inventory = {}
Inventory.__index = Inventory
local function new_inventory()
	local inv = setmetatable({main = {}, writes = 0}, Inventory)
	for i = 1, 32 do inv.main[i] = ItemStack("") end
	return inv
end
function Inventory:get_size(name) return #(self[name] or {}) end
function Inventory:get_stack(name, index)
	return ItemStack((self[name] or {})[index] or "")
end
function Inventory:set_stack(name, index, stack)
	self.writes = self.writes + 1
	self[name][index] = ItemStack(stack)
end
function Inventory:get_list(name)
	local result = {}
	for i, stack in ipairs(self[name] or {}) do result[i] = ItemStack(stack) end
	return result
end
function Inventory:get_lists()
	return {main = self:get_list("main")}
end
function Inventory:add_item(name, stack)
	for i = 1, #self[name] do
		if self[name][i]:is_empty() then
			self:set_stack(name, i, stack)
			return ItemStack("")
		end
	end
	return ItemStack(stack)
end

local Player = {}
Player.__index = Player
local function new_player(name, class_id, faction)
	local player = setmetatable({
		name = name, class_id = class_id, faction = faction, hp = 40,
		position = {x = 0, y = 0, z = 0}, look = {x = 0, y = 0, z = 1},
		dig = false, wield = 1, inventory = new_inventory(), huds = {},
		hud_changes = 0, dodge = 0, armor = 0,
	}, Player)
	players_by_name[name] = player
	return player
end
function Player:get_player_name() return self.name end
function Player:get_guid() return "player:" .. self.name end
function Player:is_player() return true end
function Player:get_hp() return self.hp end
function Player:get_pos() return self.position and vector.new(self.position) end
function Player:get_properties() return {eye_height = 1.5, hp_max = 40} end
function Player:get_eye_offset() return vector.new(0, 0, 0) end
function Player:get_look_dir() return vector.new(self.look) end
function Player:get_look_horizontal() return 0 end
function Player:get_player_control() return {dig = self.dig} end
function Player:get_inventory() return self.inventory end
function Player:get_wield_index() return self.wield end
function Player:get_wielded_item()
	return self.inventory:get_stack("main", self.wield)
end
function Player:set_pos(pos) self.position = vector.new(pos) end
function Player:set_physics_override() end
function Player:hud_add(def)
	local id = #self.huds + 1
	self.huds[id] = copy_table(def)
	return id
end
function Player:hud_change(id, key, value)
	self.hud_changes = self.hud_changes + 1
	self.huds[id][key] = value
end
function Player:set_hp(wanted, reason)
	local old = self.hp
	local change = wanted - old
	reason = reason or {type = "set_hp"}
	for _, entry in ipairs(callbacks.hpchange) do
		if entry.modifier then
			change = entry.fn(self, change, reason)
		end
	end
	self.hp = old + change
	for _, entry in ipairs(callbacks.hpchange) do
		if not entry.modifier then entry.fn(self, change, reason) end
	end
end
function Player:punch(hitter, tflp, caps, dir)
	if self.refuse_punch then return end
	for _, fn in ipairs(callbacks.punchplayer) do
		fn(self, hitter, tflp, caps, dir,
			(caps.damage_groups and caps.damage_groups.fleshy) or 0)
	end
end

local function selected_index(player, itemname)
	for index, stack in ipairs(player.inventory.main) do
		if stack:get_name() == itemname then return index end
	end
	error("missing kit item " .. itemname)
end

local Mob = {}
Mob.__index = Mob
local function new_mob(name, faction)
	local mob = setmetatable({
		name = name, faction = faction, position = {x = 0, y = 1, z = 3},
		punches = 0, mode = "accepted", last_context = nil,
	}, Mob)
	mob.entity = {
		name = name, _cmi_is_mob = true, _grug_faction = faction,
		health = 100, object = mob, attack_type = "dogfight",
		temp = {},
	}
	function mob.entity:do_attack(target)
		self.attack = target
		mob.taunts = (mob.taunts or 0) + 1
	end
	return mob
end
function Mob:get_guid() return "mob:" .. self.name end
function Mob:get_pos() return self.position and vector.new(self.position) end
function Mob:is_player() return false end
function Mob:get_luaentity() return self.entity end
function Mob:punch(hitter, _, caps)
	self.punches = self.punches + 1
	if grug_core.in_ability_punch then
		self.entity.health = self.entity.health
			- ((caps.damage_groups and caps.damage_groups.fleshy) or 0)
		return
	end
	local token = grug_core.claim_authoritative_swing(hitter, self)
	if not token then return end
	local context = grug_core.prepare_native_melee(hitter, self, 1, token)
	self.last_context = context
	if self.mode == "cancel" then return end
	local landed = self.mode ~= "immune"
	if landed then
		self.entity.health = self.entity.health
			- math.floor((caps.damage_groups and caps.damage_groups.fleshy) or 0)
	end
	grug_core.finish_native_melee(context, {
		landed = landed,
		cancelled = self.mode == "cancel",
		damage = (caps.damage_groups and caps.damage_groups.fleshy) or 0,
		mob = self.entity,
		grant_rage = true,
	})
end

local function pointed(obj, distance)
	return {
		type = "object", ref = obj,
		intersection_point = {x = 0, y = 1.5, z = distance or 2},
	}
end
local function node_point(distance)
	return {
		type = "node", under = {name = "stone"},
		intersection_point = {x = 0, y = 1.5, z = distance or 2},
	}
end
local function queue_ray(hits) ray_queue[#ray_queue + 1] = hits end

-- Load the real lower combat contract, then install the test's dependency
-- overrides before loading the real ability mod and its real kit.
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")
grug_core.get_player_faction = function(name)
	local player = players_by_name[name]
	return player and player.faction or nil
end
grug_core.get_equipped_weapon = function(player)
	return ItemStack(player.equipped_weapon or "")
end
grug_core.get_equipped_offhand = function() return ItemStack("") end
grug_core.get_crit_chance = function(player) return player.crit or 0 end
grug_core.get_dodge_chance = function(player) return player.dodge or 0 end
grug_core.get_armor_percent = function(player) return player.armor or 0 end
grug_core.get_melee_bonus = grug_classes.get_melee_bonus
grug_core.combat_debug_enabled = function() return false end
grug_core.combat_debug_due = function() return false end
grug_core.combat_debug_log = function() error("disabled debug formatted") end

dofile(repo .. "/mods/PLAYER/grug_abilities/init.lua")
for _, fn in ipairs(callbacks.mods_loaded) do fn() end

local hero = new_player("hero", "warrior", "accord")
hero.equipped_weapon = "test:weapon_a"
local enemy_a = new_mob("enemy_a", "throng")
local enemy_b = new_mob("enemy_b", "throng")
local ally = new_player("ally", "priest", "accord")
local hostile_player = new_player("hostile", "mage", "throng")
connected = {hero, ally, hostile_player}
for _, player in ipairs(connected) do
	for _, fn in ipairs(callbacks.join) do fn(player) end
end
hero.inventory.writes = 0
ally.inventory.writes = 0
hostile_player.inventory.writes = 0

local function select_item(player, itemname)
	player.wield = selected_index(player, itemname)
end
local function swing_pass(dtime)
	globalsteps[1](dtime or 0.05)
end
local function reticle(player)
	for _, def in ipairs(player.huds) do
		if def.type == "image" and def.z_index == 1 then return def end
	end
	error("missing ready reticle")
end

-- Core transaction identity is exact attacker + ray target and claim-once.
local transaction = grug_core.begin_authoritative_swing(hero, enemy_a, {})
assert(transaction)
assert(grug_core.claim_authoritative_swing(hero, enemy_b) == nil)
assert(grug_core.claim_authoritative_swing(ally, enemy_a) == nil)
assert(grug_core.claim_authoritative_swing(hero, enemy_a) == transaction)
assert(grug_core.claim_authoritative_swing(hero, enemy_a) == nil)
assert(grug_core.valid_authoritative_swing(transaction, hero, enemy_a))
assert(not grug_core.valid_authoritative_swing(transaction, hero, enemy_b))
assert(grug_core.end_authoritative_swing(transaction))

-- Ordinary remainder and its pending rage fraction are target-keyed. A->B->A
-- cannot resume A's old partial contribution.
local preview = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.4, 0.4)
assert(preview.applied == 0 and grug_core.commit_accumulated_melee(preview))
preview = grug_core.prepare_accumulated_melee(hero, enemy_b, 0.4, 0.4)
assert(preview.applied == 0 and grug_core.commit_accumulated_melee(preview))
preview = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.6, 0.6)
assert(preview.applied == 0 and grug_core.commit_accumulated_melee(preview))
preview = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.4, 0.4)
assert(preview.applied == 1 and preview.committed_fraction == 1)
assert(grug_core.commit_accumulated_melee(preview))
grug_core.reset_accumulated_melee(hero)

-- Remembered enemy is UI state only: ready held aim into empty space does not
-- hit it and leaves the ring ready. The later current ray selects B, not A.
select_item(hero, "grug_abilities:strike")
grug_abilities.set_target(hero, enemy_a, false)
hero.dig = true
queue_ray({}) -- fresh-press loot bridge
queue_ray({}) -- due combat aim
swing_pass()
assert(enemy_a.punches == 0 and enemy_b.punches == 0)
assert(grug_abilities.get_target(hero, false) == enemy_a)
assert(reticle(hero).text == "grug_abilities_weapon_ready.png")
queue_ray({pointed(enemy_b)})
now = 50000
swing_pass()
assert(enemy_a.punches == 0 and enemy_b.punches == 1)
assert(reticle(hero).text == "")
assert(grug_abilities.get_rage(hero) == 12)
assert(hero.inventory.writes == 0,
	"ready/aim/settlement reticle transitions must not rewrite inventory")

-- Switching swing skills does not reset the due time. Early input casts no ray;
-- once due the newly selected Mighty Blow is prepared live and settles once.
grug_abilities.add_rage(hero, 30)
select_item(hero, "grug_abilities:mighty_blow")
local before_rays = ray_calls
queue_ray({pointed(enemy_a)})
now = 500000
swing_pass()
assert(ray_calls == before_rays and enemy_a.punches == 0)
now = 1050000
swing_pass()
assert(enemy_a.punches == 1)
assert(enemy_a.last_context.proc.id == "mighty_blow")
assert(enemy_a.last_context.extra_damage == 3) -- floor(6 * 1.5) - 6
assert(grug_abilities.get_rage(hero) == 29) -- 42 - 25 + 12
assert((enemy_a.entity.temp.grug_threat.hero or 0) > 0)

-- A valid-ray combat miss consumes cadence but pays no proc cost/rage/effect.
-- No second held pass can retry it before the next equipped FPI.
now = 2050000
enemy_a.mode = "cancel"
local rage_before = grug_abilities.get_rage(hero)
local threat_before = enemy_a.entity.temp.grug_threat.hero
queue_ray({pointed(enemy_a)})
swing_pass()
assert(enemy_a.punches == 2 and grug_abilities.get_rage(hero) == rage_before)
assert(enemy_a.entity.temp.grug_threat.hero == threat_before)
before_rays = ray_calls
now = 2100000
swing_pass()
assert(enemy_a.punches == 2 and ray_calls == before_rays)
enemy_a.mode = "accepted"

-- Hamstring's post effect, cost and charge reset are all accepted-settlement
-- effects. An immune attempt leaves all three armed and unpaid.
select_item(hero, "grug_abilities:hamstring")
grug_abilities.add_rage(hero, 40)
local hamstring = grug_abilities.registered.hamstring
now = 3050000
enemy_a.mode = "immune"
queue_ray({pointed(enemy_a)})
rage_before = grug_abilities.get_rage(hero)
swing_pass()
assert(slows == 0 and grug_abilities.get_rage(hero) == rage_before)
assert(grug_abilities.charge_ready(hero, hamstring))
now = 4050000
enemy_a.mode = "accepted"
queue_ray({pointed(enemy_a)})
swing_pass()
assert(slows == 1)
assert(grug_abilities.get_rage(hero) == rage_before - 10 + 12)
assert(not grug_abilities.charge_ready(hero, hamstring))

-- Concrete weapon replacement starts one full NEW interval and hides the
-- ring. No valid target is even raycast before weapon B's 1.5 s FPI expires.
now = 5000000
hero.equipped_weapon = "test:weapon_b"
grug_core.notify_equipment_change(hero, "grug_weapon")
assert(reticle(hero).text == "")
before_rays = ray_calls
queue_ray({pointed(enemy_a)})
now = 6400000
swing_pass()
assert(ray_calls == before_rays)
now = 6500000
swing_pass()
assert(enemy_a.punches == 5)

-- One ordinary packet pushes the ability stream one equipped FPI out. The
-- ordinary bank survives consecutive packets, then is discarded once when a
-- swing path resumes.
local p = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.6, 0.6)
assert(grug_core.commit_accumulated_melee(p))
grug_core.handle_ordinary_melee_input(hero, enemy_a)
p = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.4, 0.4)
assert(p.applied == 0 and grug_core.commit_accumulated_melee(p))
grug_core.handle_ordinary_melee_input(hero, enemy_a)
p = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.6, 0.6)
assert(p.applied == 1 and grug_core.commit_accumulated_melee(p))
before_rays = ray_calls
queue_ray({pointed(enemy_a)})
now = 7900000
swing_pass()
assert(ray_calls == before_rays)
now = 8000000
swing_pass()
-- The first resumed swing cleared the ordinary remainder before attacking.
p = grug_core.prepare_accumulated_melee(hero, enemy_a, 0.4, 0.4)
assert(p.applied == 0 and grug_core.commit_accumulated_melee(p))
grug_core.reset_accumulated_melee(hero)

-- Hostile PvP uses the same current-ray authoritative transaction. Refusal,
-- dodge and full absorb consume the weapon cadence but grant no rage; a
-- partial absorb with real HP loss settles normally.
select_item(hero, "grug_abilities:strike")
grug_abilities.add_rage(hero, -100)
hero.dig = true
hostile_player.refuse_punch = true
local hostile_hp = hostile_player:get_hp()
now = 10000000
queue_ray({pointed(hostile_player)})
swing_pass()
assert(hostile_player:get_hp() == hostile_hp)
assert(grug_abilities.get_rage(hero) == 0 and reticle(hero).text == "")
before_rays = ray_calls
now = 10100000
swing_pass()
assert(ray_calls == before_rays, "PvP refusal must consume cadence")

hostile_player.refuse_punch = false
hostile_player.dodge = 1
now = 11500000
queue_ray({pointed(hostile_player)})
swing_pass()
assert(hostile_player:get_hp() == hostile_hp)
assert(grug_abilities.get_rage(hero) == 0)

hostile_player.dodge = 0
grug_core.set_absorb(hostile_player, 20, 10)
now = 13000000
queue_ray({pointed(hostile_player)})
swing_pass()
assert(hostile_player:get_hp() == hostile_hp)
assert(grug_abilities.get_rage(hero) == 0)

grug_core.set_absorb(hostile_player, 2, 10)
now = 14500000
queue_ray({pointed(hostile_player)})
swing_pass()
assert(hostile_player:get_hp() == hostile_hp - 6)
assert(grug_abilities.get_rage(hero) == 12)

-- The full authoritative PvP equivalent resolves crit before armor, then one
-- integer HP change. Weapon B: 8 * 1.5 crit -> 12 -> 50% armor = 6.
hero.crit = 1
hostile_player.armor = 50
grug_abilities.add_rage(hero, -100)
hostile_hp = hostile_player:get_hp()
now = 16000000
queue_ray({pointed(hostile_player)})
swing_pass()
assert(hostile_player:get_hp() == hostile_hp - 6)
assert(grug_abilities.get_rage(hero) == 12)
hero.crit = 0
hostile_player.armor = 0

-- Drive the real ordinary hostile-PvP callback. A target switch forfeits both
-- damage remainder and pending rage; bank-only packets pay nothing. Dodge and
-- full absorb consume the committed credit, while partial absorb + HP loss
-- pays exactly 12 for a total fraction of one.
local hostile_two = new_player("hostile_two", "mage", "throng")
hero.inventory:set_stack("main", 20, ItemStack("test:ordinary"))
hero.wield = 20
local ordinary_caps = core.registered_items["test:ordinary"].tool_capabilities
local function ordinary_punch(target, fraction)
	local handled
	for _, fn in ipairs(callbacks.punchplayer) do
		handled = fn(target, hero, fraction, ordinary_caps,
			{x = 0, y = 0, z = 1}, 1) or handled
	end
	assert(handled == true)
end

grug_abilities.add_rage(hero, -100)
local hp_one = hostile_player:get_hp()
local hp_two = hostile_two:get_hp()
ordinary_punch(hostile_player, 0.4)
ordinary_punch(hostile_two, 0.4)
ordinary_punch(hostile_player, 0.6)
assert(hostile_player:get_hp() == hp_one and hostile_two:get_hp() == hp_two)
assert(grug_abilities.get_rage(hero) == 0)
ordinary_punch(hostile_player, 0.4)
assert(hostile_player:get_hp() == hp_one - 1)
assert(grug_abilities.get_rage(hero) == 12)

grug_core.reset_accumulated_melee(hero)
grug_abilities.add_rage(hero, -100)
hostile_two.dodge = 1
ordinary_punch(hostile_two, 0.5)
ordinary_punch(hostile_two, 0.5)
assert(hostile_two:get_hp() == hp_two and grug_abilities.get_rage(hero) == 0)

hostile_two.dodge = 0
grug_core.set_absorb(hostile_two, 1, 10)
ordinary_punch(hostile_two, 0.5)
ordinary_punch(hostile_two, 0.5)
assert(hostile_two:get_hp() == hp_two and grug_abilities.get_rage(hero) == 0)

grug_core.set_absorb(hostile_two, 0.5, 10)
ordinary_punch(hostile_two, 0.5)
ordinary_punch(hostile_two, 0.5)
assert(hostile_two:get_hp() == hp_two - 0.5)
assert(grug_abilities.get_rage(hero) == 12)

-- Hostile casts share the current server ray and never read enemy memory or
-- trust their client pointed argument. Empty/blocking/friendly/out-of-range
-- aim spends nothing and starts no cooldown; the first valid current ray does.
local smite = grug_abilities.registered.smite
grug_abilities.set_target(ally, enemy_a, false)
local mana_before = grug_abilities.get_mana(ally)
local enemy_health = enemy_a.entity.health
queue_ray({})
grug_abilities.try_cast(ally, smite, pointed(enemy_a))
assert(grug_abilities.get_mana(ally) == mana_before)
assert(grug_abilities.ready(ally, smite.id))
assert(enemy_a.entity.health == enemy_health)

queue_ray({pointed(enemy_a, 3), node_point(2)})
grug_abilities.try_cast(ally, smite, pointed(enemy_a))
assert(grug_abilities.get_mana(ally) == mana_before)
assert(grug_abilities.ready(ally, smite.id))

queue_ray({pointed(hero, 2)})
grug_abilities.try_cast(ally, smite, pointed(enemy_a))
assert(grug_abilities.get_mana(ally) == mana_before)
assert(grug_abilities.ready(ally, smite.id))

queue_ray({pointed(enemy_a, 20.1)})
grug_abilities.try_cast(ally, smite, pointed(enemy_a))
assert(grug_abilities.get_mana(ally) == mana_before)
assert(grug_abilities.ready(ally, smite.id))

local enemy_b_health = enemy_b.entity.health
queue_ray({pointed(enemy_b, 3)})
grug_abilities.try_cast(ally, smite, pointed(enemy_a))
assert(grug_abilities.get_mana(ally) == mana_before - 4)
assert(not grug_abilities.ready(ally, smite.id))
assert(enemy_a.entity.health == enemy_health)
assert(enemy_b.entity.health == enemy_b_health - 4)
assert(grug_abilities.get_target(ally, false) == enemy_b)

-- Charge also refuses a remembered/client-pointed enemy without a current ray;
-- Taunt takes the current ray target and arms its own cooldown.
local charge = grug_abilities.registered.charge
grug_abilities.set_target(hero, enemy_b, false)
local hero_rage = grug_abilities.get_rage(hero)
local hero_pos = hero:get_pos()
queue_ray({})
grug_abilities.try_cast(hero, charge, pointed(enemy_b))
assert(grug_abilities.get_rage(hero) == hero_rage)
assert(grug_abilities.ready(hero, charge.id))
assert(vector.equals(hero:get_pos(), hero_pos))

local taunt = grug_abilities.registered.taunt
local taunts_before = enemy_a.taunts or 0
queue_ray({pointed(enemy_a, 3)})
grug_abilities.try_cast(hero, taunt, pointed(enemy_b))
assert(enemy_a.taunts == taunts_before + 1 and enemy_b.taunts == nil)
assert(not grug_abilities.ready(hero, taunt.id))

-- Friendly heal and shield casts retain the separate ally-memory fallback;
-- they do not need or consume a hostile combat ray.
hero.hp = 20
grug_abilities.set_target(ally, hero, true)
before_rays = ray_calls
grug_abilities.try_cast(ally, grug_abilities.registered.flash_heal, nil)
assert(hero:get_hp() == 28)
assert(grug_abilities.get_mana(ally) == mana_before - 12)
grug_abilities.try_cast(ally, grug_abilities.registered.power_word_shield, nil)
assert(grug_core.get_absorb(hero) == 8)
assert(grug_abilities.get_mana(ally) == mana_before - 20)
assert(ray_calls == before_rays)

-- Fireball is directional: it snapshots eye/look and spends 8 mana even with
-- no target/memory hit. Spawn failure and empty mana refuse without payment;
-- clicking a dropped item invokes pickup and does not cast.
assert(projectile_defs.fireball.speed == 20)
assert(projectile_defs.fireball.max_distance == 20)
local fireball = grug_abilities.registered.fireball
grug_abilities.set_target(hostile_player, enemy_a, false)
before_rays = ray_calls
local spawn_before = #projectile_spawns
grug_abilities.try_cast(hostile_player, fireball, pointed(enemy_a))
assert(#projectile_spawns == spawn_before + 1)
local shot = projectile_spawns[#projectile_spawns]
assert(shot.id == "fireball" and shot.params.owner == hostile_player)
assert(vector.equals(shot.params.direction, hostile_player:get_look_dir()))
assert(shot.params.data.damage == 6)
assert(grug_abilities.get_mana(hostile_player) == 92)
assert(ray_calls == before_rays)

projectile_spawn_ok = false
spawn_before = #projectile_spawns
grug_abilities.try_cast(hostile_player, fireball, nil)
assert(#projectile_spawns == spawn_before + 1)
assert(grug_abilities.get_mana(hostile_player) == 92)
projectile_spawn_ok = true

local cast_drop_ent = {name = "__builtin:item", picked = 0}
function cast_drop_ent:on_punch() self.picked = self.picked + 1 end
local cast_drop = {}
function cast_drop:get_luaentity() return cast_drop_ent end
spawn_before = #projectile_spawns
core.registered_items["grug_abilities:fireball"].on_use(
	ItemStack("grug_abilities:fireball"), hostile_player,
	{type = "object", ref = cast_drop})
assert(cast_drop_ent.picked == 1 and #projectile_spawns == spawn_before)
assert(grug_abilities.get_mana(hostile_player) == 92)

for _ = 1, 11 do grug_abilities.try_cast(hostile_player, fireball, nil) end
assert(grug_abilities.get_mana(hostile_player) == 4)
spawn_before = #projectile_spawns
grug_abilities.try_cast(hostile_player, fireball, nil)
assert(#projectile_spawns == spawn_before)
assert(grug_abilities.get_mana(hostile_player) == 4)

-- The reticle is absent for casts and is hidden synchronously by death.
select_item(hero, "grug_abilities:charge")
swing_pass()
assert(reticle(hero).text == "")
select_item(hero, "grug_abilities:strike")
hero.dig = true
now = 18000000
queue_ray({})
swing_pass()
assert(reticle(hero).text == "grug_abilities_weapon_ready.png")
for _, fn in ipairs(callbacks.die) do fn(hero) end
assert(reticle(hero).text == "")

-- Swing item registrations hard-block hand/dig_immediate nodes and carry no
-- on_use, so a lethal held sequence cannot turn into a native node dig.
local strike_item = core.registered_items["grug_abilities:strike"]
assert(strike_item.on_use == nil)
assert(strike_item.pointabilities.nodes["group:crumbly"] == "blocking")
assert(strike_item.pointabilities.nodes["group:snappy"] == "blocking")
assert(strike_item.pointabilities.nodes["group:oddly_breakable_by_hand"]
	== "blocking")
assert(strike_item.pointabilities.nodes["group:dig_immediate"] == "blocking")

-- Fresh-press loot remains bounded and is not auto-loot while held. The
-- biased object-before-node regression is exercised in swing_aim_test after
-- the physical-order fix; here an ordinary object blocks a later drop.
local drop_ent = {name = "__builtin:item", picked = 0}
function drop_ent:on_punch() self.picked = self.picked + 1 end
local drop = {position = {x = 0, y = 0, z = 2}}
function drop:get_pos() return self.position end
function drop:is_player() return false end
function drop:get_luaentity() return drop_ent end
local blocker = new_mob("blocker", "accord")
for _, fn in ipairs(callbacks.respawn) do fn(hero) end
select_item(hero, "grug_abilities:strike")
hero.dig = true
local writes_before_loot = hero.inventory.writes
queue_ray({pointed(blocker, 1), pointed(drop, 2)})
swing_pass()
assert(drop_ent.picked == 0)
local calls_after_press = ray_calls
queue_ray({pointed(drop, 2)})
swing_pass()
assert(drop_ent.picked == 0 and ray_calls == calls_after_press + 1)

assert(hero.inventory.writes == writes_before_loot,
	"held loot/combat passes must not rewrite inventory")
print("combat_integration_test: ok")
