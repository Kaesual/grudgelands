-- Known-answer test for round 6 lane FU6. Loads the real HUD layout,
-- status registry and food mod under a minimal engine stub.

local M = {}

local function run(repo)
	local failures = {}
	local now = 0
	local connected = {}
	local hooks = {join = {}, leave = {}, die = {}, globalstep = {}}
	local chats = {}
	local registered_items = {}

	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end

	local function item(name, description)
		registered_items[name] = {description = description, groups = {}}
	end

	local current = {
		"default:apple", "default:blueberries", "mobs:meat_raw", "mobs:meat",
		"mobs:meatblock_raw", "mobs:meatblock", "grug_mobs:raw_fish",
		"grug_fishing:cooked_fish", "grug_gathering:corn",
		"grug_gathering:melon", "grug_gathering:mushroom",
		"grug_gathering:potato", "grug_gathering:rock_salt",
		"grug_gathering:wild_cocoa",
	}
	for index = 1, #current do
		item(current[index], current[index])
	end

	local core_stub = {
		registered_items = registered_items,
		get_us_time = function() return now end,
		get_connected_players = function() return connected end,
		register_on_joinplayer = function(fn) hooks.join[#hooks.join + 1] = fn end,
		register_on_leaveplayer = function(fn) hooks.leave[#hooks.leave + 1] = fn end,
		register_on_dieplayer = function(fn) hooks.die[#hooks.die + 1] = fn end,
		register_globalstep = function(fn)
			hooks.globalstep[#hooks.globalstep + 1] = fn
		end,
		chat_send_player = function(name, text)
			chats[#chats + 1] = name .. ":" .. text
		end,
		override_item = function(name, fields)
			local definition = registered_items[name]
			for key, value in pairs(fields) do
				definition[key] = value
			end
		end,
	}

	local grug_core_stub = {}
	local max_hp = 100
	local max_mana = 100
	local grug_classes_stub = {
		get_max_hp = function() return max_hp end,
		get_max_mana = function() return max_mana end,
		get_spell_power_bonus = function() return 0 end,
		get_talent_bonus = function() return 0 end,
	}
	local grug_abilities_stub = {registered = {}, RAGE_PER_SWING = 8}
	function grug_abilities_stub.register_ability(definition)
		grug_abilities_stub.registered[definition.id] = definition
	end
	function grug_abilities_stub.get_target() return nil end
	function grug_abilities_stub.valid_target() return true end
	function grug_abilities_stub.get_range(_, definition)
		return definition.range or 0
	end
	function grug_abilities_stub.set_target() end
	local grug_projectiles_stub = {register = function() end}
	local vector_stub = {}
	function vector_stub.new(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end
	function vector_stub.offset(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end
	function vector_stub.distance() return 0 end
	function vector_stub.direction() return {x = 0, y = 0, z = 0} end
	function vector_stub.add(a) return vector_stub.new(a) end
	function vector_stub.multiply(a) return vector_stub.new(a) end

	local gathering_rows = {
		{raw_item = "grug_gathering:corn", harvest_kind = "food"},
		{raw_item = "grug_gathering:melon", harvest_kind = "food"},
		{raw_item = "grug_gathering:mushroom", harvest_kind = "found_only_food"},
		{raw_item = "grug_gathering:potato", harvest_kind = "food"},
		{raw_item = "grug_gathering:rock_salt", harvest_kind = "found_only_food"},
		{raw_item = "grug_gathering:wild_cocoa", harvest_kind = "found_only_food"},
	}
	local grug_gathering_stub = {
		p9g_sources = function() return gathering_rows end,
	}

	local environment = {
		core = core_stub,
		grug_core = grug_core_stub,
		grug_classes = grug_classes_stub,
		grug_abilities = grug_abilities_stub,
		grug_gathering = grug_gathering_stub,
		grug_projectiles = grug_projectiles_stub,
		vector = vector_stub,
		math = math, string = string, table = table,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, rawget = rawget,
		assert = assert, error = error, pcall = pcall,
	}
	environment._G = environment

	local function load_production(path)
		local chunk, load_error = loadfile(repo .. "/" .. path)
		check(chunk ~= nil, "load " .. path .. ": " .. tostring(load_error))
		if not chunk then
			return
		end
		setfenv(chunk, environment)
		local ok, run_error = pcall(chunk)
		check(ok, "run " .. path .. ": " .. tostring(run_error))
	end

	load_production("mods/CORE/grug_core/hud_layout.lua")
	load_production("mods/CORE/grug_core/status.lua")
	core_stub.register_on_player_hpchange = function() end
	core_stub.add_particlespawner = function() end
	core_stub.add_particle = function() end
	core_stub.register_on_mods_loaded = function() end
	core_stub.get_player_by_name = function() return nil end
	load_production("mods/CORE/grug_core/combat.lua")
	load_production("mods/ITEMS/grug_food/init.lua")
	load_production("mods/PLAYER/grug_abilities/kits.lua")
	check(#environment.grug_food.converted == #current,
		"every current edible item converted")
	for index = 1, #current do
		local definition = registered_items[current[index]]
		check(definition.groups.grug_food == 1 and
			type(definition.on_use) == "function" and
			definition.description:find("every 10 s for 3 min", 1, true) ~= nil,
			"converted item contract " .. current[index])
	end

	local Player = {}
	Player.__index = Player
	local function new_player(name, hp, mana)
		return setmetatable({name = name, hp = hp, mana = mana, hud = {},
			hud_writes = 0, next_hud = 0}, Player)
	end
	function Player:is_player() return true end
	function Player:get_player_name() return self.name end
	function Player:get_hp() return self.hp end
	function Player:set_hp(value) self.hp = value end
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

	local Stack = {}
	Stack.__index = Stack
	local function stack(count)
		return setmetatable({count = count}, Stack)
	end
	function Stack:take_item(count)
		self.count = math.max(0, self.count - count)
		return self
	end

	local player = new_player("hero", 10, 0)
	connected[1] = player
	for index = 1, #hooks.join do hooks.join[index](player) end
	local renew = grug_abilities_stub.registered.renew
	check(renew ~= nil, "real Renew definition loaded")
	local renewed = renew and renew.cast(player, nil, renew)
	check(renewed == true and grug_core_stub.get_status(player, "renew") ~= nil,
		"Renew registers its timed status")
	grug_core_stub.clear_status(player, "renew")

	local expected = {
		[2] = {1, 2, 6},
		[5] = {1, 5, 16},
		[10] = {2, 10, 32},
	}
	local pools = {20, 100, 325}
	for percent, row in pairs(expected) do
		for index = 1, #pools do
			check(environment.grug_food.tick_amount(pools[index], percent) == row[index],
				("tick math %d x %d%%"):format(pools[index], percent))
		end
	end

	local raw_stack = stack(2)
	environment.grug_food.eat(raw_stack, player, "hp", "raw")
	check(raw_stack.count == 1, "health food consumed")
	local food = grug_core_stub.get_status(player, "food")
	check(food and food.expiry_us == 180 * 1e6, "food lasts 180 seconds")

	now = 9 * 1e6
	grug_core_stub.mark_in_combat(player)
	now = 10 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(player.hp == 10, "food tick skipped in combat")
	now = 20 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(player.hp == 12, "food tick resumes after combat")

	now = 25 * 1e6
	local cooked_stack = stack(1)
	environment.grug_food.eat(cooked_stack, player, "hp", "cooked")
	local replacement = grug_core_stub.get_status(player, "food")
	check(replacement and replacement.expiry_us == 205 * 1e6,
		"most recent food replaces and refreshes")
	now = 35 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(player.hp == 17, "replacement uses cooked percentage")

	local mana_ticks = 0
	check(environment.grug_food.register_mana_restorer(
		function(target, amount, maximum)
			local before = target.mana
			target.mana = math.min(maximum, target.mana + amount)
			mana_ticks = mana_ticks + 1
			return target.mana - before
		end), "mana restorer registered")
	local mana_stack = stack(2)
	environment.grug_food.eat(mana_stack, player, "mana", "raw")
	check(mana_stack.count == 1, "raw mana food consumed by caster")
	now = 45 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(player.mana == 2 and mana_ticks == 1, "raw mana food restores 2 percent")
	local mana_cooked = stack(1)
	environment.grug_food.eat(mana_cooked, player, "mana", "cooked")
	now = 55 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(player.mana == 7, "cooked mana food restores 5 percent")
	max_mana = 0
	local rage_stack = stack(1)
	environment.grug_food.eat(rage_stack, player, "mana", "raw")
	check(rage_stack.count == 1 and #chats == 1,
		"rage class refuses mana food without consuming")
	max_mana = 100

	for index = 1, #hooks.die do hooks.die[index](player) end
	now = 100 * 1e6
	local expired = 0
	grug_core_stub.set_status(player, "short", {
		label = "Short", duration = 2, kind = "buff",
		on_expire = function() expired = expired + 1 end,
	})
	check(grug_core_stub.get_status(player, "short") ~= nil, "registry set/get")
	now = 102 * 1e6
	check(grug_core_stub.get_status(player, "short") == nil and expired == 1,
		"registry expiry callback")
	grug_core_stub.set_status(player, "clear", {
		label = "Clear", duration = 10, kind = "buff",
	})
	check(grug_core_stub.clear_status(player, "clear") and
		grug_core_stub.get_status(player, "clear") == nil, "registry clear")
	local potion_left = 41
	environment.grug_traders = {
		potion_cooldown_left = function() return potion_left end,
	}
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(grug_core_stub.get_status(player, "potion_cooldown") ~= nil,
		"persistent potion cooldown mirrored")
	for index = 1, #hooks.die do hooks.die[index](player) end
	check(grug_core_stub.get_status(player, "potion_cooldown") == nil,
		"death clears runtime status entries")
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(grug_core_stub.get_status(player, "potion_cooldown") ~= nil,
		"potion meta source restores mirror after death")
	potion_left = 0
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(grug_core_stub.get_status(player, "potion_cooldown") == nil,
		"finished potion cooldown clears mirror")
	environment.grug_traders = nil

	now = 200 * 1e6
	for index = 1, 5 do
		grug_core_stub.set_status(player, "debuff" .. index, {
			label = "Debuff " .. index, duration = 100, kind = "debuff",
		})
		grug_core_stub.set_status(player, "buff" .. index, {
			label = "Buff " .. index, duration = 100, kind = "buff",
		})
	end
	local ordered = grug_core_stub.each_status(player)
	check(#ordered == 10 and ordered[1].kind == "buff" and
		ordered[5].kind == "buff" and ordered[6].kind == "debuff",
		"buffs sort before debuffs")
	local capped = grug_core_stub.status_text(player)
	local line_count = 1
	for _ in capped:gmatch("\n") do line_count = line_count + 1 end
	check(line_count == 8, "HUD list capped at eight lines")
	for index = 1, #hooks.die do hooks.die[index](player) end

	now = 300 * 1e6
	grug_core_stub.set_absorb(player, 12, 9, player)
	grug_core_stub.set_status(player, "food", {
		label = "Food", duration = 83, kind = "buff",
	})
	grug_core_stub.set_status(player, "potion_cooldown", {
		label = "Potion", duration = 41, kind = "debuff",
	})
	local expected_hud = "Food  1:23\nShield 12  0:09\nPotion  0:41"
	check(grug_core_stub.status_text(player) == expected_hud,
		"shield + food + potion HUD text")
	local writes_before = player.hud_writes
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	local writes_after_first = player.hud_writes
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(writes_after_first == writes_before + 1 and
		player.hud_writes == writes_after_first,
		"HUD text writes only when changed")

	local tiers = {}
	for index = 1, #environment.grug_food.converted do
		local row = environment.grug_food.converted[index]
		tiers[#tiers + 1] = row.name .. "=" .. row.quality
	end
	table.sort(tiers)
	return failures, table.concat(tiers, ",")
end

function M.run(repo)
	local failures, tiers = run(repo or ".")
	local digest = "r6_food_buffs_result\tfailures=" .. #failures ..
		"\tticks=2%:1/2/6,5%:1/5/16,10%:2/10/32\titems=" .. tiers
	if #failures > 0 then
		return digest .. "\nFAIL " .. table.concat(failures, "; ") .. "\n"
	end
	return digest .. "\nPASS\n"
end

return M
