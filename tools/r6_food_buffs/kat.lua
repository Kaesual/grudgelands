-- Known-answer test for round 6 lane FU6. Loads the real HUD layout,
-- status registry and food mod under a minimal engine stub.

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

	-- Load the exact Resource API slice from the real ability mod. Keeping this
	-- in one chunk preserves the private mana ledger and hud_update upvalue while
	-- avoiding unrelated ability registrations in this focused fixture.
	local ability_path = repo .. "/mods/PLAYER/grug_abilities/init.lua"
	local ability_file = io.open(ability_path, "rb")
	check(ability_file ~= nil, "open real ability resource API")
	if ability_file then
		local source = ability_file:read("*a")
		ability_file:close()
		local first = source:find("local mana = {} --", 1, true)
		local last = first and source:find("--\n-- The rage ledger", first, true)
		check(first ~= nil and last ~= nil, "locate real ability resource API")
		if first and last then
			local resource_source = source:sub(first, last - 1) .. [[
hud_update = function(player)
	player.mana_hud_writes = (player.mana_hud_writes or 0) + 1
end
return grug_abilities
]]
			local resource_chunk, resource_error = loadstring(resource_source,
				"@mods/PLAYER/grug_abilities/init.lua#resource-api")
			check(resource_chunk ~= nil,
				"load real ability resource API: " .. tostring(resource_error))
			if resource_chunk then
				setfenv(resource_chunk, environment)
				local ok, result = pcall(resource_chunk)
				check(ok and result == grug_abilities_stub,
					"run real ability resource API: " .. tostring(result))
			end
		end
	end

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
	core_stub.get_player_by_name = function(name)
		for index = 1, #connected do
			if connected[index]:get_player_name() == name then
				return connected[index]
			end
		end
		return nil
	end
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
	function Player:get_properties() return {hp_max = max_hp} end
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

	local seam_player = new_player("seam", 100, 0)
	local restored_first = grug_abilities_stub.restore_mana(seam_player, 40)
	local restored_clamp = grug_abilities_stub.restore_mana(seam_player, 80)
	local restored_full = grug_abilities_stub.restore_mana(seam_player, 5)
	local restored_total = grug_abilities_stub.get_mana(seam_player)
	local restored_hud = seam_player.mana_hud_writes or 0
	check(restored_first == 40 and restored_clamp == 60 and
		restored_full == 0 and restored_total == 100 and restored_hud == 2,
		"restore_mana returns actual amounts, clamps and updates the HUD")
	local restore_row = ("first=%d\tclamp=%d\tfull=%d\tmana=%d\thud=%d")
		:format(restored_first, restored_clamp, restored_full,
			restored_total, restored_hud)

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
	local death_hp = player.hp
	for index = 1, #hooks.die do hooks.die[index](player) end
	now = 3 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](3) end
	check(grug_core_stub.get_status(player, "renew") == nil and
		player.hp == death_hp, "death clears Renew status and private record")
	local leaver = new_player("leaver", 10, 0)
	connected[2] = leaver
	for index = 1, #hooks.join do hooks.join[index](leaver) end
	local renewed_leaver = renew and renew.cast(leaver, nil, renew)
	for index = 1, #hooks.leave do hooks.leave[index](leaver) end
	now = 6 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](3) end
	check(renewed_leaver == true and leaver.hp == 10,
		"leave clears Renew private record")
	connected[2] = nil
	now = 0

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

	local mana_stack = stack(2)
	registered_items["grug_gathering:wild_cocoa"].on_use(mana_stack, player)
	check(mana_stack.count == 1, "raw mana food consumed by caster")
	now = 45 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(grug_abilities_stub.get_mana(player) == 2 and
		player.mana_hud_writes == 1, "raw mana food restores 2 percent")
	local mana_cooked = stack(1)
	environment.grug_food.eat(mana_cooked, player, "mana", "cooked")
	now = 55 * 1e6
	for index = 1, #hooks.globalstep do hooks.globalstep[index](1) end
	check(grug_abilities_stub.get_mana(player) == 7,
		"cooked mana food restores 5 percent")
	max_mana = 0
	local rage_stack = stack(1)
	registered_items["grug_gathering:wild_cocoa"].on_use(rage_stack, player)
	check(rage_stack.count == 1 and #chats == 1,
		"rage class refuses mana food without consuming")
	max_mana = 100

	max_hp = 10000
	now = 1000 * 1e6
	local full_duration = new_player("full_duration", 1, 0)
	connected[2] = full_duration
	environment.grug_food.eat(stack(1), full_duration, "hp", "raw")
	for tick = 1, 18 do
		now = (1000 + tick * 10) * 1e6
		for index = 1, #hooks.globalstep do hooks.globalstep[index](10) end
	end
	local duration_ticks = (full_duration.hp - 1) / 200
	check(duration_ticks == 18 and
		grug_core_stub.get_status(full_duration, "food") == nil,
		"food runs all 18 scheduled ticks through expiry")

	now = 2000 * 1e6
	local skipped_duration = new_player("skipped_duration", 1, 0)
	connected[2] = skipped_duration
	environment.grug_food.eat(stack(1), skipped_duration, "hp", "raw")
	for tick = 1, 18 do
		if tick == 1 then
			now = 2009 * 1e6
			grug_core_stub.mark_in_combat(skipped_duration)
		end
		now = (2000 + tick * 10) * 1e6
		for index = 1, #hooks.globalstep do hooks.globalstep[index](10) end
	end
	local skipped_ticks = (skipped_duration.hp - 1) / 200
	check(skipped_ticks == 17 and
		grug_core_stub.get_status(skipped_duration, "food") == nil,
		"one combat skip yields 17 ticks without make-up")
	connected[2] = nil
	max_hp = 100

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
	check(grug_core_stub.set_status(player, "tick_only", {
		label = "Tick only", duration = 10, on_tick = function() end,
	}) == nil, "registry rejects on_tick without interval")
	check(grug_core_stub.set_status(player, "interval_only", {
		label = "Interval only", duration = 10, interval = 1,
	}) == nil, "registry rejects interval without on_tick")
	check(grug_core_stub.set_status(player, "zero_interval", {
		label = "Zero interval", duration = 10, interval = 0,
		on_tick = function() end,
	}) == nil, "registry rejects a non-positive tick interval")
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
	local cocoa_mapping = "missing"
	local cooked_mana_items = 0
	for index = 1, #environment.grug_food.converted do
		local row = environment.grug_food.converted[index]
		tiers[#tiers + 1] = row.name .. "=" .. row.resource .. "/" .. row.quality
		if row.name == "grug_gathering:wild_cocoa" then
			cocoa_mapping = row.resource .. "/" .. row.quality .. "/" .. row.percent
		end
		if row.resource == "mana" and row.quality == "cooked" then
			cooked_mana_items = cooked_mana_items + 1
		end
	end
	local cocoa_groups = registered_items["grug_gathering:wild_cocoa"].groups
	check(cocoa_mapping == "mana/raw/2" and cocoa_groups.grug_food_mana == 1
		and not cocoa_groups.grug_food_hp, "wild cocoa is raw mana food only")
	check(cooked_mana_items == 0,
		"the registered cooked mana tier has no item yet")
	table.sort(tiers)
	return failures, table.concat(tiers, ","), cocoa_mapping,
		cooked_mana_items, restore_row, duration_ticks, skipped_ticks
end

local function format_result(repo)
	local failures, tiers, cocoa, cooked_mana, restore, duration_ticks,
		skipped_ticks = run(repo or ".")
	local digest = "r6_food_mapping\tcocoa=" .. cocoa ..
		"\tcooked_mana_items=" .. cooked_mana .. "\n" ..
		"r6_mana_restore\t" .. restore .. "\n" ..
		"r6_food_buffs_result\tfailures=" .. #failures ..
		"\tduration_ticks=" .. duration_ticks .. "/" .. skipped_ticks ..
		"\tticks=2%:1/2/6,5%:1/5/16,10%:2/10/32\titems=" .. tiers
	if #failures > 0 then
		return digest .. "\nFAIL " .. table.concat(failures, "; ") .. "\n"
	end
	return digest .. "\nPASS\n"
end

return function(repo)
	return format_result(repo or ".")
end
