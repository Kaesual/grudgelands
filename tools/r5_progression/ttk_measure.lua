-- Deterministic balance table for round-6 Lane B. Weapon, class, ability, mob
-- and scalar values are loaded from production modules.

local repo = arg[1] or "."
dofile(repo .. "/tools/r5_progression/progression_kat.lua")
grug_core.get_player_level = function(player) return player.level end

local levels = {1, 10, 20, 40, 60}

local function load_in(path, env)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	return chunk()
end

-- Read the generated sword definitions, including their actual bracket
-- selection and registered tool capabilities.
local gear_items = {}
local gear_env = setmetatable({
	core = {
		registered_items = gear_items,
		colorize = function(_, text) return text end,
		register_tool = function(name, def) gear_items[name] = def end,
		register_craftitem = function(name, def) gear_items[name] = def end,
		register_on_mods_loaded = function() end,
		log = function() end,
	},
}, {__index = _G})
load_in(repo .. "/mods/ITEMS/grug_gear/init.lua", gear_env)
local gear_api = gear_env.grug_gear

-- Load the production class registry and its real stats calculator. The three
-- unrelated class submodules are registration/UI concerns and remain inert in
-- this calculator fixture.
local class_env
class_env = setmetatable({
	core = {
		get_current_modname = function() return "grug_classes" end,
		get_modpath = function()
			return repo .. "/mods/PLAYER/grug_classes"
		end,
		get_player_by_name = function() return nil end,
		register_on_joinplayer = function() end,
	},
	grug_core = {
		register_on_equipment_change = function() end,
		base_pool = grug_core.base_pool,
	},
	grug_xp = {
		get_level = function(player) return player.level end,
		register_on_level_change = function() end,
	},
	grug_factions = {get_faction = function(player) return player.faction end},
}, {__index = _G})
class_env.dofile = function(path)
	if path:match("/stats%.lua$") then
		return load_in(path, class_env)
	end
end
load_in(repo .. "/mods/PLAYER/grug_classes/init.lua", class_env)
local class_api = class_env.grug_classes
class_api.get_talent_bonus = function() return 0 end

local function production_player(level, class_id)
	local meta = {get_string = function(_, key)
		if key == "grug_classes:class" then return class_id end
		return ""
	end}
	return {
		level = level,
		get_meta = function() return meta end,
		get_player_name = function() return class_id .. tostring(level) end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_properties = function() return {eye_height = 1.5} end,
		get_look_dir = function() return {x = 0, y = 0, z = 1} end,
		get_hp = function() return 100 end,
		is_player = function() return true end,
	}
end

-- Load the registered production casts. Fireball exposes its raw amount in
-- projectile data; Smite exposes it at deal_ability_damage. Both therefore
-- exercise the actual ability-base + spell-power assembly without copying it.
local ability_defs = {}
local spawned
local dealt
local ability_target = {
	is_player = function() return false end,
	get_pos = function() return {x = 0, y = 0, z = 3} end,
	get_luaentity = function() return {_cmi_is_mob = true, _grug_level = 1} end,
}
local vec = {}
function vec.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end
function vec.offset(a, x, y, z)
	return {x = a.x + x, y = a.y + y, z = a.z + z}
end
function vec.add(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end
function vec.multiply(a, n) return {x = a.x * n, y = a.y * n, z = a.z * n} end
function vec.distance(a, b)
	local x, y, z = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(x * x + y * y + z * z)
end
function vec.direction(a, b)
	local d = vec.distance(a, b)
	return {x = (b.x - a.x) / d, y = (b.y - a.y) / d,
		z = (b.z - a.z) / d}
end
local ability_env = setmetatable({
	core = {
		add_particle = function() end,
		add_particlespawner = function() end,
		get_objects_inside_radius = function() return {} end,
		after = function() end,
	},
	vector = vec,
	grug_abilities = {
		RAGE_PER_SWING = 12,
		register_ability = function(def) ability_defs[def.id] = def end,
		get_range = function(_, def) return def.range or 4 end,
		valid_target = function() return true end,
		set_target = function() end,
		get_target = function() return nil end,
	},
	grug_projectiles = {
		register = function() end,
		spawn = function(id, params) spawned = {id = id, params = params}; return true end,
	},
	grug_classes = class_api,
	grug_core = {
		base_pool = grug_core.base_pool,
		baseline_weapon_damage = grug_core.baseline_weapon_damage,
		get_player_level = grug_core.get_player_level,
		combat_eye_pos = function(user) return user:get_pos() end,
		combat_ray = function()
			return {status = "target", target = ability_target}
		end,
		combat_debug_enabled = function() return false end,
		get_absorb = function() return 0 end,
		deal_ability_damage = function(_, _, amount) dealt = amount end,
		set_move_modifier = function() end,
	},
	grug_factions = {same_faction = function() return false end},
	grug_mobs = {root = function() end, slow = function() end},
}, {__index = _G})
setmetatable(ability_env.core, {__index = function(table_value, key)
	local noop = function() end
	rawset(table_value, key, noop)
	return noop
end})
load_in(repo .. "/mods/PLAYER/grug_abilities/kits.lua", ability_env)

local function sword_damage(level)
	return gear_api.weapon_damage_at_level(level, "sword")
end

local function ability_damage(level, class_id, ability_id)
	local player = production_player(level, class_id)
	spawned, dealt = nil, nil
	local ok = ability_defs[ability_id].cast(player, nil, ability_defs[ability_id])
	assert(ok, "production " .. ability_id .. " cast failed")
	if ability_id == "fireball" then
		return spawned.params.data.damage
	end
	return dealt
end

local function hit_damage(amount, armor_factor)
	return math.max(1, math.floor(amount * armor_factor))
end

local function ttk(hp, amount, armor_factor, interval)
	return math.ceil(hp / hit_damage(amount, armor_factor)) * interval
end

local function current_rows()
	local rows = {}
	for _, level in ipairs(levels) do
		local normal_hp = grug_mobs.stats_for(level, "normal")
		local _, normal_damage = grug_mobs.stats_for(level, "normal")
		local target = {
			is_player = function() return false end,
			get_luaentity = function() return {_grug_level = level} end,
		}
		local classes = {
			{label = "Warrior", id = "warrior", attack = "Sword",
				interval = 1, raw = function(player)
					return sword_damage(level) + class_api.get_melee_bonus(player)
				end},
			{label = "Mage", id = "mage", attack = "Fireball",
				interval = 1, raw = function()
					return ability_damage(level, "mage", "fireball")
				end},
			{label = "Priest", id = "priest", attack = "Smite",
				interval = 2, raw = function()
					return ability_damage(level, "priest", "smite")
				end},
		}
		for _, class in ipairs(classes) do
			local player = production_player(level, class.id)
			local hit = grug_core.scale_player_damage(player, target,
				class.raw(player))
			local hp = class_api.get_max_hp(player)
			local incoming_hit = math.max(1, math.ceil(normal_damage *
				(grug_core.mob_pressure_scale and
					grug_core.mob_pressure_scale(level) or 1)))
			rows[#rows + 1] = {
				level = level,
				class = class.label,
				attack = class.attack,
				hp = hp,
				mana = class_api.get_max_mana(player),
				hit = hit,
				normal_ttk = ttk(normal_hp, hit, 1, class.interval),
				elite_ttk = ttk(normal_hp * 3, hit, 0.8, class.interval),
				ttd = math.ceil(hp / incoming_hit),
			}
		end
	end
	return rows
end

local function write_current_table()
	io.write("| Level | Class | Baseline attack | HP | Mana | Effective hit | " ..
		"Normal TTK (s) | Elite TTK (s) | Raw TTD (s) |\n")
	io.write("|---:|---|---|---:|---:|---:|---:|---:|---:|\n")
	for _, row in ipairs(current_rows()) do
		io.write(string.format("| %d | %s | %s | %d | %d | %d | %d | %d | %.1f |\n",
			row.level, row.class, row.attack, row.hp, row.mana, row.hit,
			row.normal_ttk, row.elite_ttk, row.ttd))
	end
end

-- Machine-readable seam for the Round 6 KAT. It returns the same production-
-- backed rows printed by the ordinary command plus the loaded APIs needed for
-- focused pool and support assertions.
if arg[2] == "--r6-data" then
	return {
		rows = current_rows(),
		measure = current_rows,
		core = grug_core,
		classes = class_api,
		abilities = ability_defs,
		player = production_player,
	}
end

write_current_table()
return true
