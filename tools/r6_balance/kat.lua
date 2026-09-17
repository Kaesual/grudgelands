-- Round 6 Lane B known-answer test. The balance rows come from the production-
-- backed r5 progression measurement harness; tooltip checks load the real
-- ability registry under a minimal engine stub.
--
-- R6_BALANCE_MUTATION=1 shifts a class pool.
-- R6_BALANCE_MUTATION=2 changes percentage mana rounding.
-- R6_BALANCE_MUTATION=3 weakens Flash Heal by one percentage point.
-- R6_BALANCE_MUTATION=4 restores support double scaling.
-- R6_BALANCE_MUTATION=5 doubles the damage fit.
-- R6_BALANCE_MUTATION=6 removes the current-level mana amount from tooltips.
-- R6_BALANCE_MUTATION=7 corrupts the equipped-weapon effective value.

return function(repo)
	local mutation = tonumber(os.getenv("R6_BALANCE_MUTATION") or "") or 0
	local saved_arg = arg
	arg = {repo, "--r6-data"}
	local data = dofile(repo .. "/tools/r5_progression/ttk_measure.lua")
	arg = saved_arg

	local function fail(message)
		error("r6 balance: " .. message, 0)
	end

	local function equal(actual, expected, message)
		if actual ~= expected then
			fail(message .. ": expected " .. tostring(expected) ..
				", got " .. tostring(actual))
		end
	end

	local base_expected = {26, 136, 384, 1276, 2696}
	local levels = {1, 10, 20, 40, 60}
	local hp_expected = {
		warrior = {31, 163, 461, 1531, 3235},
		mage = {23, 122, 346, 1148, 2426},
		priest = {26, 136, 384, 1276, 2696},
	}
	if mutation == 1 then
		local original = data.classes.get_max_hp
		data.classes.get_max_hp = function(owner)
			return original(owner) + 1
		end
	end
	for index, level in ipairs(levels) do
		equal(data.core.base_pool(level), base_expected[index],
			"base pool at L" .. level)
		for _, class_id in ipairs({"warrior", "mage", "priest"}) do
			local player = data.player(level, class_id)
			equal(data.classes.get_max_hp(player), hp_expected[class_id][index],
				class_id .. " HP at L" .. level)
			local expected_mana = class_id == "warrior" and 0
				or base_expected[index]
			equal(data.classes.get_max_mana(player), expected_mana,
				class_id .. " mana at L" .. level)
		end
	end

	local function noop() end
	local function stub(fields)
		return setmetatable(fields or {}, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end
	local registered_items = {}
	local ability_env
	local core_stub = stub({
		registered_items = registered_items,
		registered_nodes = {},
		get_current_modname = function() return "grug_abilities" end,
		get_modpath = function()
			return repo .. "/mods/PLAYER/grug_abilities"
		end,
		register_tool = function(name, def) registered_items[name] = def end,
		get_us_time = function() return 0 end,
	})
	local core_api = stub({
		base_pool = data.core.base_pool,
		baseline_weapon_damage = data.core.baseline_weapon_damage,
		get_player_level = function(player) return player.level end,
		level_scale = data.core.level_scale,
		scale_player_value = data.core.scale_player_value,
		scale_player_damage = function(player, target, amount)
			return math.max(0, math.floor(amount * data.core.level_scale(player.level)))
		end,
		get_absorb = function() return 0 end,
		get_equipped_weapon = function() return nil end,
	})
	local class_defs = {
		warrior = {name = "Warrior", resource = "rage"},
		mage = {name = "Mage", resource = "mana"},
		priest = {name = "Priest", resource = "mana"},
	}
	local classes_stub = stub({registered_classes = class_defs})
	function classes_stub.get_class_def(player)
		return class_defs[player.class_id]
	end
	function classes_stub.get_talent_bonus() return 0 end
	function classes_stub.get_spell_power_bonus(player)
		local growth = player.class_id == "mage" and 3 or 2
		return math.floor((10 + growth * (player.level - 1)) / 10)
	end
	function classes_stub.get_melee_bonus(player)
		local growth = player.class_id == "warrior" and 3
			or player.class_id == "priest" and 1 or 0
		return math.floor((10 + growth * (player.level - 1)) / 10)
	end
	function classes_stub.get_max_mana(player)
		return player.class_id == "warrior" and 0
			or data.core.base_pool(player.level)
	end
	local projectiles_stub = stub({register = noop})
	ability_env = setmetatable({
		core = core_stub,
		minetest = core_stub,
		grug_core = core_api,
		grug_classes = classes_stub,
		grug_xp = stub({register_on_level_change = noop}),
		grug_projectiles = projectiles_stub,
		grug_factions = stub(),
		grug_mobs = stub(),
		grug_inventory = stub(),
		vector = stub(),
		ItemStack = function() return stub({is_empty = function() return true end}) end,
	}, {__index = _G})
	ability_env._G = ability_env
	ability_env.dofile = function(path)
		local chunk = assert(loadfile(path))
		setfenv(chunk, ability_env)
		return chunk()
	end
	local init_chunk = assert(loadfile(
		repo .. "/mods/PLAYER/grug_abilities/init.lua"))
	setfenv(init_chunk, ability_env)
	init_chunk()
	local abilities = ability_env.grug_abilities

	local function player(level, class_id)
		return {
			level = level,
			class_id = class_id,
			get_player_name = function() return class_id .. level end,
		}
	end
	if mutation == 2 then
		local original = abilities.mana_cost
		abilities.mana_cost = function(owner, percent)
			return original(owner, percent) + 1
		end
	end
	local cost_rows = {
		{percent = 5, l1 = 1, l60 = 135, casts_l1 = 26, casts_l60 = 19},
		{percent = 6, l1 = 2, l60 = 162, casts_l1 = 13, casts_l60 = 16},
		{percent = 8, l1 = 2, l60 = 216, casts_l1 = 13, casts_l60 = 12},
		{percent = 10, l1 = 3, l60 = 270, casts_l1 = 8, casts_l60 = 9},
	}
	for _, row in ipairs(cost_rows) do
		local l1 = abilities.mana_cost(player(1, "mage"), row.percent)
		local l60 = abilities.mana_cost(player(60, "mage"), row.percent)
		equal(l1, row.l1, row.percent .. "% mana at L1")
		equal(l60, row.l60, row.percent .. "% mana at L60")
		equal(math.floor(data.core.base_pool(1) / l1), row.casts_l1,
			row.percent .. "% full-pool casts at L1")
		equal(math.floor(data.core.base_pool(60) / l60), row.casts_l60,
			row.percent .. "% full-pool casts at L60")
	end

	local flash = abilities.registered.flash_heal
	if mutation == 3 then
		flash.values = function(owner)
			local base = data.core.base_pool(owner.level)
			local spell = classes_stub.get_spell_power_bonus(owner)
			return {heal = base * 24 / 100 * (1 + spell / 100)}
		end
	end
	local flash_l1 = flash.values(player(1, "priest")).heal
	local flash_l60 = flash.values(player(60, "priest")).heal
	equal(string.format("%.3f", flash_l1), "6.565", "Flash Heal at L1")
	equal(string.format("%.2f", flash_l60), "754.88", "Flash Heal at L60")
	local shield_l60 = abilities.registered.power_word_shield
		.values(player(60, "priest")).absorb
	equal(string.format("%.2f", shield_l60), "754.88", "Shield at L60")
	local renew_l60 = abilities.registered.renew
		.values(player(60, "priest")).heal
	equal(string.format("%.2f", renew_l60), "241.56", "Renew tick at L60")

	if mutation == 4 then
		core_api.scale_player_value = function(owner, amount)
			return amount * data.core.level_scale(owner.level)
		end
	end
	equal(core_api.scale_player_value(player(60, "priest"), flash_l60),
		flash_l60, "pool-derived support bypasses level_scale")

	if mutation == 5 then
		local original = data.core.level_scale
		data.core.level_scale = function(level) return original(level) * 2 end
	end
	local rows = mutation == 5 and data.measure() or data.rows
	for _, row in ipairs(rows) do
		local priest = row.class == "Priest"
		local normal_min = priest and 10.8 or 7.2
		local normal_max = priest and 17.6 or 13.2
		if row.normal_ttk < normal_min or row.normal_ttk > normal_max then
			fail(("%s L%d normal TTK %.1f outside %.1f..%.1f"):format(
				row.class, row.level, row.normal_ttk, normal_min, normal_max))
		end
		local elite_ratio = row.elite_ttk / row.normal_ttk
		if elite_ratio < 2.7 or elite_ratio > 4.4 then
			fail(("%s L%d elite ratio %.2f outside 2.7..4.4"):format(
				row.class, row.level, elite_ratio))
		end
		if row.ttd < 22.5 or row.ttd > 33 then
			fail(("%s L%d TTD %.1f outside 22.5..33.0"):format(
				row.class, row.level, row.ttd))
		end
	end

	if mutation == 6 then
		abilities.description_prefix = function(owner, def)
			return def.name .. "\n" .. def.cost.mana_percent .. "% base mana\n"
		end
	end
	local fireball = abilities.registered.fireball
	local description = abilities.description_prefix(player(60, "mage"), fireball)
		.. fireball.description_for(player(60, "mage"), fireball)
	if not description:find("6%% base mana %(162 mana%)") then
		fail("Fireball tooltip lacks percentage and L60 absolute mana")
	end
	if not description:find("337 damage", 1, true) then
		fail("Fireball tooltip lacks L60 effective damage")
	end
	local flash_description = abilities.description_prefix(
		player(60, "priest"), flash)
		.. flash.description_for(player(60, "priest"), flash)
	if not flash_description:find("8%% base mana %(216 mana%)") or
			not flash_description:find("for 754", 1, true) then
		fail("Flash Heal tooltip lacks L60 cost or heal")
	end

	local gear_items = {}
	local mods_loaded = {}
	local equipment_callbacks = {}
	local level_callbacks = {}
	local equipment_notices = 0
	local gear_core = stub({
		registered_items = gear_items,
		colorize = function(_, value) return value end,
		register_tool = function(name, def) gear_items[name] = def end,
		register_craftitem = function(name, def) gear_items[name] = def end,
		register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
		log = noop,
	})
	local gear_grug_core = stub({
		register_on_equipment_change = function(fn)
			equipment_callbacks[#equipment_callbacks + 1] = fn
		end,
		level_scale = data.core.level_scale,
		item_level_scale = function(level, ilvl)
			local value = data.core.item_level_scale(level, ilvl)
			return mutation == 7 and value + 0.1 or value
		end,
	})
	local gear_env = setmetatable({
		core = gear_core,
		grug_core = gear_grug_core,
		grug_classes = {get_melee_bonus = function() return 3 end},
		grug_xp = {
			get_level = function(owner) return owner.level end,
			register_on_level_change = function(fn)
				level_callbacks[#level_callbacks + 1] = fn
			end,
		},
		grug_inventory = {equipment_changed = function()
			equipment_notices = equipment_notices + 1
		end},
	}, {__index = _G})
	gear_env._G = gear_env
	local gear_chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_gear/init.lua"))
	setfenv(gear_chunk, gear_env)
	gear_chunk()
	for _, callback in ipairs(mods_loaded) do callback() end
	local weapon_name = gear_env.grug_gear.weapon_item("sword", 1)
	local weapon_def = gear_items[weapon_name]
	local strings = {}
	local weapon_stack = {}
	function weapon_stack:is_empty() return false end
	function weapon_stack:get_name() return weapon_name end
	function weapon_stack:get_definition() return weapon_def end
	function weapon_stack:get_tool_capabilities()
		return weapon_def.tool_capabilities
	end
	function weapon_stack:get_meta()
		return {
			get_string = function(_, key) return strings[key] or "" end,
			set_string = function(_, key, value) strings[key] = value end,
		}
	end
	local inventory_writes = 0
	local gear_inventory = {
		get_lists = function() return {grug_weapon = {weapon_stack}} end,
		get_stack = function() return weapon_stack end,
		set_stack = function() inventory_writes = inventory_writes + 1 end,
	}
	local gear_player = {level = 10}
	function gear_player:get_inventory()
		return gear_inventory
	end
	equipment_callbacks[1](gear_player, "grug_weapon")
	if not strings.description:find(
			"Effective at level 10: 9 damage per swing", 1, true) then
		fail("weapon tooltip lacks current-level effective damage")
	end
	equipment_callbacks[1](gear_player, "grug_weapon")
	equal(inventory_writes, 1, "unchanged weapon tooltip inventory writes")
	equal(equipment_notices, 1, "unchanged weapon tooltip notices")

	io.write("R6_CAST_COUNTS 5%=26/19 6%=13/16 8%=13/12 10%=8/9\n")
	io.write("R6_BALANCE_OK rows=15 pools=45 costs=8 support=4 tooltips=3\n")
end
