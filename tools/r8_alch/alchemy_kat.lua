return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("absolute repository root required", 0)
	end
	local mutation = os.getenv("R8_ALCH_MUTATION") or ""
	local function check(ok, label)
		if not ok then error("R8-ALCH alchemy KAT: " .. label, 0) end
	end

	local craftitems, recipes, ingredient_tiers = {}, {}, {}
	local callbacks = {}
	core = {
		registered_items = craftitems,
		get_us_time = function() return 1000000 end,
		register_craftitem = function(name, def) craftitems[name] = def end,
		register_on_dieplayer = function(fn) callbacks.die = fn end,
		register_on_leaveplayer = function(fn) callbacks.leave = fn end,
		register_on_joinplayer = function() end,
		register_on_respawnplayer = function() end,
		register_globalstep = function() end,
		register_on_mods_loaded = function(fn) callbacks.mods_loaded = fn end,
		chat_send_player = function() end,
		get_item_group = function(name, group)
			return name == "test:apothecary" and group == "grug_apothecary" and 1 or 0
		end,
	}
	grug_core = {}
	dofile(root .. "/mods/CORE/grug_core/status.lua")
	grug_core.get_player_level = function(player) return player.level end
	grug_core.can_use_item_level = function(player, stack)
		local def = craftitems[stack:get_name()]
		local required = def and def._grug_ilvl
		return not required or player.level >= required, required, player.level
	end
	grug_core.heal_player = function(_, player, amount)
		player.hp = math.min(100, player.hp + amount)
	end
	grug_core.set_move_modifier = function(player, id, effect, duration)
		player.move = {id = id, speed = effect.speed, duration = duration}
	end

	grug_classes = {
		get_max_hp = function() return 100 end,
		get_max_mana = function() return 100 end,
	}
	grug_abilities = {restore_mana = function(player, amount)
		local before = player.mana
		player.mana = math.min(100, player.mana + amount)
		return player.mana - before
	end}
	grug_inventory = {equipment_slots = {
		{list = "head"}, {list = "chest"}, {list = "feet"},
	}}
	grug_mobs = {clear_poison = function(player)
		local old = player.poisoned
		player.poisoned = false
		return old == true
	end}
	grug_traders = {
		potion_cooldown_left = function(player) return player.cooldown or 0 end,
		start_potion_cooldown = function(player, seconds)
			player.cooldown = seconds
		end,
		register_stock = function(def) callbacks.stock = def end,
	}
	local herb_authorizer
	grug_gathering = {register_herb_authorizer = function(fn)
		herb_authorizer = fn
	end}
	grug_brewing = {
		NODE = "grug_brewing:brewing_stand",
		register_recipe = function() end,
		register_public_position = function() end,
	}
	grug_jobs = {
		register_ingredient_tier = function(item, tier)
			ingredient_tiers[item] = tier
		end,
		register_recipe = function(def)
			local flat = {}
			local function add(value)
				if type(value) == "string" then
					if value ~= "" then flat[#flat + 1] = value end
				elseif type(value) == "table" then
					for index = 1, #value do add(value[index]) end
				end
			end
			add(def.inputs)
			def.flat_inputs = flat
			def.output_name = def.output
			recipes[#recipes + 1] = def
			return def
		end,
		register_station = function(_, def) callbacks.station = def end,
		has = function(player) return player.alchemist == true end,
	}
	grug_core.settlement_socket_settlements = function() return {} end
	grug_core.settlement_sockets_at = function() return {} end

	grug_alchemy = {}
	dofile(root .. "/mods/ITEMS/grug_alchemy/effects.lua")
	dofile(root .. "/mods/ITEMS/grug_alchemy/recipes.lua")

	local brewing_count = 0
	for index = 1, #recipes do
		local recipe = recipes[index]
		if recipe.station == "brewing_stand" then
			brewing_count = brewing_count + 1
			local exact = false
			for input_index = 1, #recipe.flat_inputs do
				if ingredient_tiers[recipe.flat_inputs[input_index]] == recipe.tier then
					exact = true
				end
			end
			if mutation == "recipe_tier" and brewing_count == 1 then exact = false end
			check(#recipe.flat_inputs == 3 and exact, "tier-N brewing recipe")
		end
	end
	check(brewing_count == 21, "brewing recipe count")

	local function stack(name, count)
		return {
			name = name, count = count or 1,
			get_name = function(self) return self.name end,
			take_item = function(self, amount) self.count = self.count - amount end,
		}
	end
	local player = {
		name = "tester", hp = 50, mana = 50, level = 60, alchemist = true,
		gear = {},
		is_player = function() return true end,
		get_player_name = function(self) return self.name end,
		get_hp = function(self) return self.hp end,
		get_inventory = function(self)
			return {get_stack = function(_, listname)
				return stack(self.gear[listname] or "")
			end}
		end,
		get_properties = function() return {breath_max = 10} end,
		set_breath = function(self, value) self.breath = value end,
		override_day_night_ratio = function(self, value) self.light = value end,
	}

	local healing = craftitems["grug_alchemy:potion_healing"]
	local mana = craftitems["grug_alchemy:potion_mana"]
	local first = stack("grug_alchemy:potion_healing")
	healing.on_use(first, player)
	check(player.cooldown == 60 and first.count == 0, "Healing starts shared cooldown")
	local second = stack("grug_alchemy:potion_mana")
	mana.on_use(second, player)
	if mutation == "shared_cooldown" then second.count = 0 end
	check(second.count == 1, "Mana observes Healing cooldown")
	player.cooldown, player.mana = 0, 100
	local full = stack("grug_alchemy:potion_mana")
	mana.on_use(full, player)
	check(full.count == 0 and player.cooldown == 60,
		"full-mana potion still consumes")
	player.cooldown, player.hp = 0, 50
	local greater = stack("grug_alchemy:potion_greater_healing")
	craftitems[greater.name].on_use(greater, player)
	local healing_cooldown = player.cooldown
	player.cooldown, player.mana = 0, 50
	greater = stack("grug_alchemy:potion_greater_mana")
	craftitems[greater.name].on_use(greater, player)
	local mana_cooldown = player.cooldown
	if mutation == "greater_cooldown" then mana_cooldown = 60 end
	check(healing_cooldown == 45 and mana_cooldown == 45,
		"Greater pair cooldown")

	player.cooldown = 37
	grug_core.set_status(player, "food", {label = "Food", duration = 180,
		modifiers = {hp_pool_percent = 2}})
	local vigor = stack("grug_alchemy:elixir_vigor_t3")
	craftitems[vigor.name].on_use(vigor, player)
	local stacked = grug_core.status_modifier_sum(player, "hp_pool_percent")
	if mutation == "food_stack" then stacked = 5 end
	check(stacked == 7, "food and elixir stack")
	if mutation == "elixir_clock" then player.cooldown = 0 end
	check(player.cooldown == 37, "elixir leaves potion clock unchanged")
	local focus = stack("grug_alchemy:elixir_focus_t3")
	craftitems[focus.name].on_use(focus, player)
	local hp_sum = grug_core.status_modifier_sum(player, "hp_pool_percent")
	local mana_sum = grug_core.status_modifier_sum(player, "mana_pool_percent")
	if mutation == "elixir_exclusive" then hp_sum = hp_sum + 5 end
	check(hp_sum == 2 and mana_sum == 5, "one elixir replaces another")

	player.gear = {head = "test:apothecary", chest = "test:apothecary",
		feet = "test:apothecary"}
	vigor = stack("grug_alchemy:elixir_vigor_t3")
	craftitems[vigor.name].on_use(vigor, player)
	local boosted = grug_core.get_status(player, "elixir")
	local boosted_value = boosted.modifiers.hp_pool_percent
	local boosted_duration = (boosted.expiry_us - core.get_us_time()) / 1e6
	if mutation == "apothecary_cap" then boosted_value = boosted_value + 1 end
	check(boosted_value == 7 and boosted_duration == 1080,
		"Apothecary bonus caps at two pieces")

	for index = 1, #grug_alchemy.CATALOG do
		local row = grug_alchemy.CATALOG[index]
		local level = craftitems["grug_alchemy:" .. row.id]._grug_ilvl
		if mutation == "item_level" and index == 1 then level = 2 end
		check(level == grug_alchemy.TIER_LEVELS[row.tier], "tier item level")
	end

	player.alchemist = false
	local allowed, reason = herb_authorizer(player, "gravemoss", 1)
	if mutation == "authorizer" then allowed = true end
	check(not allowed and reason == "no_alchemist", "non-Alchemist herb refusal")
	player.alchemist = true
	allowed = herb_authorizer(player, "ember_moss", 5)
	if mutation == "authorizer_allow" then allowed = false end
	check(allowed, "Alchemist herb permission")

	local harvest_factory = dofile(root ..
		"/mods/ITEMS/grug_gathering/harvest.lua")
	local harvest = harvest_factory({core = core, materials = {}})
	harvest.register_herb_authorizer(herb_authorizer)
	player.alchemist = false
	allowed = harvest.decision({x = 0, y = 0, z = 0}, player, {
		placement_class = "new_p9g_source", key = "cave_cap",
		harvest_kind = "food", required_group = 0,
	})
	if mutation == "cave_cap" then allowed = false end
	check(allowed, "Cave Cap remains food-grade")

	return "R8-ALCH alchemy KAT PASS recipes=21 cooldown=60/45 elixir=exclusive+food+clock gear=2 ilvl=1,11,21,31,41,51 herbs=closed\n"
end
