-- Deterministic balance table for round-5 Lane P. Current weapon, class,
-- ability, mob and scalar values are loaded from production modules; only the
-- exact pre-lane comparison formulas remain historical locals.

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
	local bracket = gear_api.bracket_for_level(level)
	local name = assert(gear_api.weapon_item("sword", bracket),
		"missing production sword name")
	local def = assert(gear_items[name], "missing production sword " .. name)
	return def.tool_capabilities.damage_groups.fleshy
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

local function old_mob_hp(level)
	return 15 + 5 * level
end

local function old_mob_damage(level)
	return 2 + 0.4 * level
end

local function old_player_hp(level, strength_growth)
	local strength = 10 + strength_growth * (level - 1)
	return 20 + 2 * (level - 1) + strength
end

local function old_warrior_hit(level)
	local old_sword = { [1] = 5, [10] = 5, [20] = 8, [40] = 15, [60] = 22 }
	return old_sword[level] + math.floor((10 + 3 * (level - 1)) / 10)
end

local function old_fireball_hit(level)
	return 6 + math.floor((10 + 3 * (level - 1)) / 10)
end

local function old_smite_hit(level)
	return 4 + math.floor((10 + 2 * (level - 1)) / 10)
end

local function hit_damage(amount, armor_factor)
	return math.max(1, math.floor(amount * armor_factor))
end

local function ttk(hp, amount, armor_factor, interval)
	return math.ceil(hp / hit_damage(amount, armor_factor)) * interval
end

local function pair(old_value, new_value)
	return tostring(old_value) .. "→" .. tostring(new_value)
end

local maximum_ratio = 0
local maximum_label = ""

io.write("Player-to-mob TTK (seconds; deterministic non-crit hits; Warrior " ..
	"sword 1.0 s, Fireball normalized to one cast/s, Smite 2.0 s)\n\n")
io.write("| L | HP normal/elite | Raw DPS W/F/S old→new | Warrior N/E old→new | Fireball N/E old→new | " ..
	"Smite N/E old→new |\n")
io.write("|---:|---:|---:|---:|---:|---:|\n")
for _, level in ipairs(levels) do
	local old_hp = old_mob_hp(level)
	local new_hp = grug_mobs.stats_for(level, "normal")
	local warrior = production_player(level, "warrior")
	local target = {
		is_player = function() return false end,
		get_luaentity = function() return {_grug_level = level} end,
	}
	local outputs = {
		{name = "Warrior", old = old_warrior_hit(level), interval = 1,
			raw = sword_damage(level) + class_api.get_melee_bonus(warrior)},
		{name = "Fireball", old = old_fireball_hit(level), interval = 1,
			raw = ability_damage(level, "mage", "fireball")},
		{name = "Smite", old = old_smite_hit(level), interval = 2,
			raw = ability_damage(level, "priest", "smite")},
	}
	local cells = {tostring(level), new_hp .. "/" .. (new_hp * 3)}
	local dps = {}
	for _, output in ipairs(outputs) do
		local new_amount = grug_core.scale_player_damage(warrior, target,
			output.raw)
		dps[#dps + 1] = pair(string.format("%.1f", output.old / output.interval),
			string.format("%.1f", new_amount / output.interval))
	end
	cells[#cells + 1] = table.concat(dps, "/")
	for _, output in ipairs(outputs) do
		local new_amount = grug_core.scale_player_damage(warrior, target,
			output.raw)
		local old_normal = ttk(old_hp, output.old, 1, output.interval)
		local new_normal = ttk(new_hp, new_amount, 1, output.interval)
		local old_elite = ttk(old_hp * 3, output.old, 0.8, output.interval)
		local new_elite = ttk(new_hp * 3, new_amount, 0.8, output.interval)
		cells[#cells + 1] = pair(old_normal, new_normal) .. " / " ..
			pair(old_elite, new_elite)
		for _, values in ipairs({{old_normal, new_normal, "normal"},
				{old_elite, new_elite, "elite"}}) do
			local ratio = values[2] / values[1]
			if ratio > maximum_ratio then
				maximum_ratio = ratio
				maximum_label = output.name .. " L" .. level .. " " .. values[3]
			end
		end
	end
	io.write("| ", table.concat(cells, " | "), " |\n")
end
if maximum_ratio > 2 then
	error(string.format("TTK stop criterion exceeded: %.3f at %s",
		maximum_ratio, maximum_label), 0)
end
io.write(string.format("\nMaximum new/old TTK ratio: %.3f at %s (PASS <= 2.000).\n\n",
	maximum_ratio, maximum_label))

io.write("Mob-to-player raw TTD (seconds at one hit/s; before dodge/armor/absorb)\n\n")
io.write("| L | Mob damage N/E old→new | Warrior HP TTD N/E old→new | " ..
	"Mage HP TTD N/E old→new | Priest HP TTD N/E old→new |\n")
io.write("|---:|---:|---:|---:|---:|\n")
for _, level in ipairs(levels) do
	local old_normal = old_mob_damage(level)
	local _, new_normal = grug_mobs.stats_for(level, "normal")
	local old_elite = math.floor(old_normal * 1.8 * 10 + 0.5) / 10
	local _, new_elite = grug_mobs.stats_for(level, "elite")
	local cells = {tostring(level), string.format("%.1f→%.1f / %.1f→%.1f",
		old_normal, new_normal, old_elite, new_elite)}
	for _, class in ipairs({{"Warrior", "warrior", 3}, {"Mage", "mage", 0},
			{"Priest", "priest", 1}}) do
		local hp = class_api.get_max_hp(production_player(level, class[2]))
		assert(hp == old_player_hp(level, class[3]),
			"production player HP drift for " .. class[1] .. " L" .. level)
		cells[#cells + 1] = string.format("%d; %.1f→%.1f / %.1f→%.1f", hp,
			hp / old_normal, hp / new_normal, hp / old_elite, hp / new_elite)
	end
	io.write("| ", table.concat(cells, " | "), " |\n")
end

return true
