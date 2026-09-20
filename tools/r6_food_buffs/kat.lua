-- Round 6 status/resource regressions retained after Food v2 replaced the old
-- quality contract. Loads the real registry, combat and Renew seams.

local function run(root)
	local failures = {}
	local now = 0
	local connected = {}
	local hooks = {join = {}, leave = {}, die = {}, step = {}, hp = {}}

	local function check(condition, message)
		if not condition then failures[#failures + 1] = message end
	end

	local core = {
		get_us_time = function() return now end,
		get_connected_players = function() return connected end,
		get_player_by_name = function(name)
			for index = 1, #connected do
				local player = connected[index]
				if player and player:get_player_name() == name then return player end
			end
			return nil
		end,
		register_on_joinplayer = function(fn) hooks.join[#hooks.join + 1] = fn end,
		register_on_leaveplayer = function(fn) hooks.leave[#hooks.leave + 1] = fn end,
		register_on_dieplayer = function(fn) hooks.die[#hooks.die + 1] = fn end,
		register_globalstep = function(fn) hooks.step[#hooks.step + 1] = fn end,
		register_on_player_hpchange = function(fn, modifier)
			hooks.hp[#hooks.hp + 1] = {fn = fn, modifier = modifier}
		end,
		register_on_mods_loaded = function() end,
		is_player = function(object)
			return object and object.is_player and object:is_player()
		end,
		get_objects_inside_radius = function() return {} end,
		add_particlespawner = function() end,
		add_particle = function() end,
	}

	local grug_core = {}
	local grug_classes = {
		get_max_hp = function() return 100 end,
		get_max_mana = function() return 100 end,
		get_spell_power_bonus = function() return 0 end,
		get_spell_damage_percent = function() return 0 end,
		get_talent_bonus = function() return 0 end,
	}
	local grug_abilities = {registered = {}, RAGE_PER_SWING = 8}
	function grug_abilities.register_ability(definition)
		grug_abilities.registered[definition.id] = definition
	end
	function grug_abilities.get_target() return nil end
	function grug_abilities.valid_target() return true end
	function grug_abilities.get_range(_, definition)
		return definition.range or 0
	end
	function grug_abilities.set_target() end

	local vector = {}
	function vector.new(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end
	function vector.offset(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end
	function vector.distance() return 0 end
	function vector.direction() return {x = 0, y = 0, z = 0} end
	function vector.add(value) return vector.new(value) end
	function vector.multiply(value) return vector.new(value) end

	local environment = {
		core = core,
		grug_core = grug_core,
		grug_classes = grug_classes,
		grug_abilities = grug_abilities,
		grug_projectiles = {register = function() end},
		vector = vector,
		math = math, string = string, table = table,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, rawget = rawget,
		assert = assert, error = error, pcall = pcall,
	}
	environment._G = environment

	local function load_production(path)
		local chunk, load_error = loadfile(root .. "/" .. path)
		check(chunk ~= nil, "load " .. path .. ": " .. tostring(load_error))
		if not chunk then return end
		setfenv(chunk, environment)
		local ok, run_error = pcall(chunk)
		check(ok, "run " .. path .. ": " .. tostring(run_error))
	end

	-- Load the exact Resource API slice while preserving its private mana table.
	local ability_file = assert(io.open(root ..
		"/mods/PLAYER/grug_abilities/init.lua", "rb"))
	local ability_source = ability_file:read("*a")
	ability_file:close()
	local resource_first = assert(ability_source:find("local mana = {} --", 1, true))
	local resource_last = assert(ability_source:find(
		"--\n-- The rage ledger", resource_first, true))
	local resource_chunk = assert(loadstring(
		ability_source:sub(resource_first, resource_last - 1) .. [[
hud_update = function(player)
	player.mana_hud_writes = (player.mana_hud_writes or 0) + 1
end
return grug_abilities
]]))
	setfenv(resource_chunk, environment)
	check(resource_chunk() == grug_abilities, "real resource API loaded")

	load_production("mods/CORE/grug_core/hud_layout.lua")
	load_production("mods/CORE/grug_core/status.lua")
	load_production("mods/CORE/grug_core/combat.lua")
	load_production("mods/PLAYER/grug_abilities/kits.lua")

	local Player = {}
	Player.__index = Player
	local function player(name, hp, mana)
		return setmetatable({name = name, hp = hp, mana = mana, hud = {},
			hud_writes = 0, next_hud = 0}, Player)
	end
	function Player:is_player() return true end
	function Player:get_player_name() return self.name end
	function Player:get_hp() return self.hp end
	function Player:set_hp(value) self.hp = value end
	function Player:get_properties() return {hp_max = self.hp_max or 100, eye_height = 1.5} end
	function Player:get_pos() return {x = 0, y = 0, z = 0} end
	function Player:hud_add(definition)
		self.next_hud = self.next_hud + 1
		self.hud[self.next_hud] = definition
		return self.next_hud
	end
	function Player:hud_change(id, field, value)
		self.hud[id][field] = value
		self.hud_writes = self.hud_writes + 1
	end
	function Player:hud_remove(id) self.hud[id] = nil end

	local mana_player = player("mana", 100, 0)
	local first = grug_abilities.restore_mana(mana_player, 40)
	local clamped = grug_abilities.restore_mana(mana_player, 80)
	local full = grug_abilities.restore_mana(mana_player, 5)
	local mana_total = grug_abilities.get_mana(mana_player)
	local mana_writes = mana_player.mana_hud_writes or 0
	check(first == 40 and clamped == 60 and full == 0 and
		mana_total == 100 and mana_writes == 2,
		"restore_mana returns actual amounts, clamps and updates the HUD")

	local hero = player("hero", 10, 0)
	connected[1] = hero
	for index = 1, #hooks.join do hooks.join[index](hero) end
	local damage_modifier
	for index = 1, #hooks.hp do
		if hooks.hp[index].modifier then damage_modifier = hooks.hp[index].fn end
	end
	local dodge_calls, armor_calls = 0, 0
	grug_core.get_dodge_chance = function() dodge_calls = dodge_calls + 1 return 1 end
	grug_core.get_armor_percent = function() armor_calls = armor_calls + 1 return 60 end
	check(damage_modifier and damage_modifier(hero, 0, {type = "fall"}) == 0,
		"zero native fall damage remains zero")
	hero.hp_max = 100
	check(damage_modifier(hero, -0.2, {type = "fall"}) == -1 and
		damage_modifier(hero, -5, {type = "fall"}) == -25,
		"fractional and five-point fall severities use ceiling pool scaling")
	hero.hp_max = 40
	check(damage_modifier(hero, -1, {type = "fall"}) == -2,
		"low maximum HP keeps the same fall percentage")
	hero.hp_max = 3000
	check(damage_modifier(hero, -1, {type = "fall"}) == -150 and
		damage_modifier(hero, -21, {type = "fall"}) == -3150,
		"high maximum HP scales equally and severe falls remain uncapped")
	check(dodge_calls == 0 and armor_calls == 0,
		"fall damage bypasses dodge and equipped armor")
	hero.hp_max = 100
	grug_core.get_race_perk = function(_, key)
		return key == "fall_damage_mult" and 0.8 or nil
	end
	check(damage_modifier and damage_modifier(hero, -5, {type = "fall"}) == -20,
		"Dwarf fall reduction resolves after pool scaling")
	grug_core.get_race_perk = function() return nil end

	local potion_left = 41
	environment.grug_traders = {
		potion_cooldown_left = function() return potion_left end,
	}
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(grug_core.get_status(hero, "potion_cooldown") ~= nil,
		"persistent potion cooldown mirrored")
	for index = 1, #hooks.die do hooks.die[index](hero) end
	check(grug_core.get_status(hero, "potion_cooldown") == nil,
		"death clears runtime potion mirror")
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(grug_core.get_status(hero, "potion_cooldown") ~= nil,
		"potion meta source restores mirror after death")
	potion_left = 0
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(grug_core.get_status(hero, "potion_cooldown") == nil,
		"finished potion cooldown clears mirror")
	environment.grug_traders = nil

	now = 100 * 1e6
	for index = 1, 5 do
		grug_core.set_status(hero, "debuff" .. index, {
			label = "Debuff " .. index, duration = 100, kind = "debuff",
		})
		grug_core.set_status(hero, "buff" .. index, {
			label = "Buff " .. index, duration = 100, kind = "buff",
		})
	end
	local ordered = grug_core.each_status(hero)
	check(#ordered == 10 and ordered[1].kind == "buff" and
		ordered[5].kind == "buff" and ordered[6].kind == "debuff",
		"buffs sort before debuffs")
	local text = grug_core.status_text(hero)
	local lines = text == "" and 0 or 1
	for _ in text:gmatch("\n") do lines = lines + 1 end
	check(lines == 8, "HUD list capped at eight lines")
	for index = 1, #hooks.die do hooks.die[index](hero) end

	now = 200 * 1e6
	grug_core.set_status(hero, "steady", {
		label = "Steady", duration = 60, kind = "buff",
	})
	local before = hero.hud_writes
	for index = 1, #hooks.step do hooks.step[index](1) end
	local after_first = hero.hud_writes
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(after_first == before + 1 and hero.hud_writes == after_first,
		"HUD text writes only when changed")
	local untimed = grug_core.set_status(hero, "mount", {
		label = "T1 Mount, +60% Speed", kind = "buff", untimed = true,
	})
	check(untimed and grug_core.status_text(hero):find(
		"T1 Mount, +60% Speed", 1, true) and not grug_core.status_text(hero):find(
		"T1 Mount, +60% Speed  ", 1, true),
		"runtime-only mount status has no countdown")
	check(not grug_core.set_status(hero, "bad_untimed", {
		label = "bad", untimed = true, modifiers = {armor = 1},
	}), "untimed UI status rejects modifiers")

	for index = 1, #hooks.die do hooks.die[index](hero) end
	local renew = grug_abilities.registered.renew
	check(renew ~= nil, "real Renew definition loaded")
	local renewed = renew and renew.cast(hero, nil, renew)
	local death_hp = hero.hp
	for index = 1, #hooks.die do hooks.die[index](hero) end
	now = 203 * 1e6
	for index = 1, #hooks.step do hooks.step[index](3) end
	check(renewed == true and grug_core.get_status(hero, "renew") == nil and
		hero.hp == death_hp, "death clears Renew status and private record")

	local leaver = player("leaver", 10, 0)
	connected[2] = leaver
	for index = 1, #hooks.join do hooks.join[index](leaver) end
	local renewed_leaver = renew and renew.cast(leaver, nil, renew)
	for index = 1, #hooks.leave do hooks.leave[index](leaver) end
	now = 206 * 1e6
	for index = 1, #hooks.step do hooks.step[index](3) end
	check(renewed_leaver == true and leaver.hp == 10,
		"leave clears Renew private record")

	return failures,
		("mana=%d/%d/%d/%d/hud%d status=%d/%d hud=%d renew=%d/%d"):format(
			first, clamped, full, mana_total, mana_writes, #ordered, lines,
			hero.hud_writes, hero.hp, leaver.hp)
end

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"r6 status KAT requires an absolute repository root")
	local failures, digest = run(root)
	local rows = {
		"r6_status_regressions\t" .. digest,
		"r6_status_result\tfailures=" .. #failures,
	}
	if #failures > 0 then
		rows[#rows + 1] = "FAIL " .. table.concat(failures, "; ")
	else
		rows[#rows + 1] = "PASS"
	end
	return table.concat(rows, "\n") .. "\n"
end
