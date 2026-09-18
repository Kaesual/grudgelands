-- R8 Cooking v1 function-style KAT.
-- Usage: <lua> -e 'io.write(dofile(".../kat.lua")("/absolute/repo"))'

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"r8_cook KAT needs an absolute repository root")
	local failures = {}
	local report = {}
	local function check(value, message)
		if not value then failures[#failures + 1] = message end
	end
	local function row(...)
		report[#report + 1] = table.concat({...}, "\t")
	end

	local saved = {}
	for _, name in ipairs({"core", "grug_core", "grug_jobs", "grug_food",
			"grug_cooking", "grug_fishing", "grug_gathering", "grug_classes",
			"grug_abilities", "grug_xp", "mobs", "PcgRandom", "ItemStack",
			"vector"}) do
		saved[name] = rawget(_G, name)
	end
	local function restore()
		for name, value in pairs(saved) do rawset(_G, name, value) end
	end

	local crafts = {}
	local registered = {}
	local mods_loaded = {}
	local gathering_rows = {
		{key = "corn", raw_item = "grug_gathering:corn", harvest_kind = "food"},
		{key = "marshbloom", raw_item = "grug_gathering:marshbloom",
			harvest_kind = "spice"},
		{key = "melon", raw_item = "grug_gathering:melon", harvest_kind = "food"},
		{key = "mushroom", raw_item = "grug_gathering:mushroom",
			harvest_kind = "found_only_food"},
		{key = "potato", raw_item = "grug_gathering:potato", harvest_kind = "food"},
		{key = "rock_salt", raw_item = "grug_gathering:rock_salt",
			harvest_kind = "found_only_food"},
		{key = "stormkelp", raw_item = "grug_gathering:stormkelp",
			harvest_kind = "spice"},
		{key = "wild_cocoa", raw_item = "grug_gathering:wild_cocoa",
			harvest_kind = "found_only_food"},
	}

	core = {registered_items = registered, registered_nodes = {},
		registered_craft_predicts = {}, registered_on_crafts = {}}
	function core.get_current_modname() return "grug_fishing" end
	function core.get_modpath() return root .. "/mods/ITEMS/grug_fishing" end
	function core.register_craftitem(name, definition)
		registered[name] = definition
	end
	core.register_tool = core.register_craftitem
	function core.override_item(name, changes)
		local definition = assert(registered[name], "missing override " .. name)
		for key, value in pairs(changes) do definition[key] = value end
	end
	function core.register_craft(definition)
		crafts[#crafts + 1] = definition
	end
	function core.get_all_craft_recipes(output)
		local result = {}
		for index = 1, #crafts do
			local definition = crafts[index]
			local name = tostring(definition.output):match("^%s*([^%s]+)")
			if name == output then
				result[#result + 1] = {method = definition.type == "cooking" and
					"cooking" or "normal", items = definition.recipe,
					output = definition.output}
			end
		end
		return #result > 0 and result or nil
	end
	function core.get_item_group(name, group)
		local definition = registered[name]
		return definition and definition.groups and definition.groups[group] or 0
	end
	function core.item_eat() return function(stack) return stack end end
	function core.register_globalstep() end
	function core.register_on_leaveplayer() end
	function core.register_on_dieplayer() end
	function core.register_on_mods_loaded(fn) mods_loaded[#mods_loaded + 1] = fn end
	function core.register_craft_predict(fn)
		core.registered_craft_predicts[#core.registered_craft_predicts + 1] = fn
	end
	function core.register_on_craft(fn)
		core.registered_on_crafts[#core.registered_on_crafts + 1] = fn
	end
	function core.chat_send_player() end
	function core.log() end
	function core.get_gametime() return 0 end

	local base_items = {
		"default:apple", "default:blueberries", "default:stick", "default:papyrus",
		"mobs:meat_raw", "mobs:meat", "mobs:meatblock_raw", "mobs:meatblock",
		"grug_mobs:raw_fish", "grug_mobs:spider_silk",
	}
	for index = 1, #base_items do
		registered[base_items[index]] = {description = base_items[index], groups = {}}
	end
	registered["mobs:meat_raw"].groups.food_meat_raw = 1
	registered["grug_mobs:raw_fish"].groups.food_fish_raw = 1
	for index = 1, #gathering_rows do
		local source = gathering_rows[index]
		registered[source.raw_item] = {description = source.key, groups = {}}
	end
	core.register_craft({type = "cooking", output = "mobs:meat",
		recipe = "mobs:meat_raw", cooktime = 5})

	grug_core = {in_combat = function() return false end,
		set_status = function() return {} end}
	local fish_level = 1
	function grug_core.mob_level_at() return fish_level end
	function grug_core.get_player_level(player) return player.level end
	function grug_core.can_use_item_level(player, item)
		local name = type(item) == "string" and item or item:get_name()
		local required = registered[name] and registered[name]._grug_ilvl
		return not required or player.level >= required, required, player.level
	end
	grug_classes = {get_max_mana = function() return 100 end,
		get_max_hp = function() return 100 end}
	grug_abilities = {restore_mana = function() return 0 end}
	grug_xp = {get_level = function(player) return player.level end}
	grug_gathering = {p9g_sources = function() return gathering_rows end}
	mobs = {add_eatable = function(name)
		registered[name].groups = registered[name].groups or {}
		registered[name].groups.eatable = 1
	end}
	PcgRandom = function() return {next = function() return 0 end} end
	ItemStack = function(value)
		local name = tostring(value or ""):match("^%s*([^%s]+)") or ""
		return {get_name = function() return name end,
			get_count = function() return name == "" and 0 or 1 end,
			is_empty = function() return name == "" end}
	end
	vector = {distance = function() return 0 end}

	grug_jobs = {}
	dofile(root .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(root .. "/mods/PLAYER/grug_jobs/state.lua")
	grug_jobs.register_station("grid", {register_recipe = function(recipe)
		core.register_craft({output = recipe.output, recipe = recipe.inputs})
	end})
	grug_jobs.register_station("furnace", {register_recipe = function(recipe)
		core.register_craft({type = "cooking", output = recipe.output,
			recipe = recipe.flat_inputs[1], cooktime = recipe.time or 5})
	end})

	dofile(root .. "/mods/ITEMS/grug_fishing/init.lua")
	dofile(root .. "/mods/ITEMS/grug_food/init.lua")
	dofile(root .. "/mods/ITEMS/grug_cooking/init.lua")

	-- Independent contract oracle: do not derive these rows from the content
	-- tables. This pins every decided output, tier, role and ordered input list.
	local expected_dishes = {
		{"grug_cooking:hearty_stew", 1, "hearty",
			{"mobs:meat_raw", "group:grug_cooking_staple"}},
		{"grug_cooking:sweetroot_mash", 1, "caster",
			{"group:grug_cooking_root", "group:grug_cooking_staple"}},
		{"grug_cooking:corn_crusted_fish", 1, "hunter",
			{"grug_mobs:raw_fish", "grug_gathering:corn"}},
		{"grug_cooking:pumpkin_stew", 2, "hearty",
			{"grug_cooking:pumpkin", "mobs:meat_raw",
				"group:grug_cooking_staple"}},
		{"grug_cooking:berry_preserve", 2, "caster",
			{"group:grug_cooking_berry", "group:grug_cooking_berry",
				"grug_cooking:sugar_cane"}},
		{"grug_cooking:fruit_glazed_roast", 2, "hunter",
			{"mobs:meat_raw", "group:grug_cooking_fruit"}},
		{"grug_cooking:foragers_pot", 3, "hearty",
			{"grug_gathering:mushroom", "mobs:meat_raw",
				"group:grug_cooking_staple"}},
		{"grug_cooking:mushroom_skewer", 3, "caster",
			{"grug_gathering:mushroom", "grug_gathering:mushroom"}},
		{"grug_cooking:onion_seared_steak", 3, "hunter",
			{"mobs:meat_raw", "group:grug_cooking_early_spice",
				"grug_gathering:mushroom"}},
		{"grug_cooking:marsh_roast", 4, "hearty",
			{"mobs:meat_raw", "grug_gathering:marshbloom",
				"group:grug_cooking_staple"}},
		{"grug_cooking:marshbloom_chowder", 4, "caster",
			{"grug_mobs:raw_fish", "grug_gathering:marshbloom"}},
		{"grug_cooking:hunters_feast", 4, "hunter",
			{"mobs:meat_raw", "mobs:meat_raw", "grug_gathering:melon",
				"grug_gathering:mushroom"}},
		{"grug_cooking:kelp_wrapped_roast", 5, "hearty",
			{"mobs:meat_raw", "grug_gathering:stormkelp",
				"grug_gathering:rock_salt"}},
		{"grug_cooking:stormkelp_broth", 5, "caster",
			{"grug_gathering:stormkelp", "grug_mobs:raw_fish",
				"grug_gathering:melon"}},
		{"grug_cooking:salt_crusted_fish", 5, "hunter",
			{"grug_mobs:raw_fish", "grug_gathering:rock_salt"}},
		{"grug_cooking:grand_feast", 6, "hearty",
			{"mobs:meat_raw", "mobs:meat_raw", "grug_gathering:wild_cocoa",
				"grug_gathering:stormkelp"}},
		{"grug_cooking:jungle_cocoa", 6, "caster",
			{"grug_gathering:wild_cocoa", "grug_gathering:wild_cocoa",
				"grug_gathering:rock_salt"}},
		{"grug_cooking:cocoa_rubbed_game", 6, "hunter",
			{"mobs:meat_raw", "grug_gathering:wild_cocoa",
				"group:grug_cooking_early_spice"}},
	}
	local expected_raw_dishes = {
		{"grug_cooking:raw_stew_pot", 1, "hearty",
			{"mobs:meat_raw", "group:grug_cooking_staple",
				"grug_cooking:wild_grain"}, "grug_cooking:hearty_stew"},
		{"grug_cooking:raw_pumpkin_pot", 2, "hearty",
			{"grug_cooking:pumpkin", "mobs:meat_raw",
				"grug_cooking:wild_grain"}, "grug_cooking:pumpkin_stew"},
		{"grug_cooking:raw_foragers_pot", 3, "hearty",
			{"grug_cooking:cave_cap", "mobs:meat_raw",
				"group:grug_cooking_staple"}, "grug_cooking:foragers_pot"},
		{"grug_cooking:raw_marsh_roast", 4, "hearty",
			{"mobs:meat_raw", "grug_gathering:marshbloom",
				"grug_cooking:frost_melon"}, "grug_cooking:marsh_roast"},
		{"grug_cooking:raw_kelp_roast", 5, "hearty",
			{"mobs:meat_raw", "grug_gathering:stormkelp",
				"grug_cooking:salt_crust"}, "grug_cooking:kelp_wrapped_roast"},
		{"grug_cooking:raw_grand_feast", 6, "hearty",
			{"mobs:meat_raw", "mobs:meat_raw", "grug_gathering:wild_cocoa",
				"grug_cooking:salt_crust"}, "grug_cooking:grand_feast"},
	}
	local function exact_inputs(actual, expected)
		if #actual ~= #expected then return false end
		for index = 1, #expected do
			if actual[index] ~= expected[index] then return false end
		end
		return true
	end

	local mutation = tonumber(os.getenv("R8_COOK_MUTATION") or "") or 0
	if mutation == 1 then
		grug_jobs.ingredient_tier = function() return nil end
	elseif mutation == 2 then
		grug_cooking.RAW_ASSEMBLIES[3].output = "grug_cooking:mushroom_skewer"
	elseif mutation == 3 then
		registered["grug_gathering:mushroom"]._grug_tier = 1
	elseif mutation == 4 then
		grug_fishing.CATCH_TABLES[6][1].name = "missing:fish"
	elseif mutation == 5 then
		grug_core.can_use_item_level = function(player)
			return true, nil, player.level
		end
	elseif mutation == 6 then
		grug_cooking.DISHES[10].inputs[1] = "grug_mobs:raw_fish"
	end

	local role_count = {}
	for tier = 1, 6 do role_count[tier] = {} end
	check(#grug_cooking.DISHES == 18, "dish population differs")
	for index = 1, #grug_cooking.DISHES do
		local dish = grug_cooking.DISHES[index]
		local expected = expected_dishes[index]
		check(expected and dish.item == expected[1] and dish.tier == expected[2] and
			dish.role == expected[3] and exact_inputs(dish.inputs, expected[4]),
			"dish contract differs at row " .. index)
		local recipe = grug_jobs.recipe_for_output(dish.item, "grid")
		check(recipe ~= nil and recipe.tier == dish.tier and
			recipe.profession == "cooking", dish.item .. " grid recipe missing")
		local has_tier = false
		for input_index = 1, #dish.inputs do
			local ingredient_tier = grug_jobs.ingredient_tier(dish.inputs[input_index])
			if ingredient_tier == dish.tier then has_tier = true end
			check(not ingredient_tier or ingredient_tier <= dish.tier,
				dish.item .. " hides a higher-tier ingredient")
		end
		check(has_tier, dish.item .. " lacks its tier ingredient")
		local effect = grug_food.effect_for(dish.tier, "dish", dish.role)
		local definition = registered[dish.item]
		check(effect == grug_food.TIERS[dish.tier].dishes[dish.role],
			dish.item .. " effect is not tier-role data")
		check(definition.groups["grug_food_role_" .. dish.role] == 1 and
			definition.groups.grug_food_tier == dish.tier and
			definition._grug_ilvl == (dish.tier - 1) * 10 + 1,
			dish.item .. " food registration differs")
		role_count[dish.tier][dish.role] =
			(role_count[dish.tier][dish.role] or 0) + 1
	end
	for tier = 1, 6 do
		check(role_count[tier].hearty == 1 and role_count[tier].caster == 1 and
			role_count[tier].hunter == 1, "role coverage differs at T" .. tier)
	end
	local sweetroot = grug_jobs.recipe_for_output("grug_cooking:sweetroot_mash",
		"grid")
	check(grug_jobs.recipe_for_craft("grid", ItemStack(sweetroot.output_name),
		{ItemStack("grug_cooking:cassava"),
			ItemStack("grug_gathering:potato")}) == sweetroot,
		"Throng root/staple alternatives do not resolve to Sweetroot Mash")
	local steak = grug_jobs.recipe_for_output("grug_cooking:onion_seared_steak",
		"grid")
	check(grug_jobs.recipe_for_craft("grid", ItemStack(steak.output_name),
		{ItemStack("mobs:meat_raw"), ItemStack("grug_cooking:fire_pepper"),
			ItemStack("grug_gathering:mushroom")}) == steak,
		"Throng spice alternative does not resolve to Onion-Seared Steak")
	row("dishes", "18", "tiers=6", "roles=hearty,caster,hunter")

	check(#grug_cooking.RAW_ASSEMBLIES == 6, "raw assembly population differs")
	for tier = 1, 6 do
		local assembly = grug_cooking.RAW_ASSEMBLIES[tier]
		local expected = expected_raw_dishes[tier]
		local edible = registered[assembly.output]
		check(expected and assembly.item == expected[1] and
			assembly.tier == expected[2] and exact_inputs(assembly.inputs, expected[4]) and
			assembly.output == expected[5] and edible and edible.groups and
			edible.groups["grug_food_role_" .. expected[3]] == 1,
			"raw dish contract differs at row " .. tier)
		local grid_recipe = grug_jobs.recipe_for_output(assembly.item, "grid")
		local furnace_recipe = grug_jobs.recipe_for_output(assembly.output, "furnace")
		local direct_recipe = grug_jobs.recipe_for_output(assembly.output, "grid")
		check(grid_recipe and grid_recipe.tier == tier,
			"raw grid pattern missing at T" .. tier)
		check(furnace_recipe and furnace_recipe.flat_inputs[1] == assembly.item and
			direct_recipe and furnace_recipe.output_name == direct_recipe.output_name,
			"grid and furnace paths do not converge at T" .. tier)
		check(registered[assembly.item]._grug_ilvl == nil and
			registered[assembly.item].on_use == nil,
			"raw assembly became edible at T" .. tier)
	end
	check(#grug_cooking.REFINEMENTS == 3, "plain refinement population differs")
	for index = 1, #grug_cooking.REFINEMENTS do
		local refinement = grug_cooking.REFINEMENTS[index]
		local found = false
		for craft_index = 1, #crafts do
			local craft = crafts[craft_index]
			local output = tostring(craft.output):match("^%s*([^%s]+)")
			if craft.type == "cooking" and craft.recipe == refinement.input and
					output == refinement.output then found = true end
		end
		check(found, "plain furnace refinement missing for " .. refinement.input)
		check(grug_jobs.recipe_for_output(refinement.output, "furnace") == nil,
			"plain furnace refinement became profession-gated")
	end
	row("furnace", "raw_to_cooked=3", "assembled_to_dish=6", "converged=6")

	local raw_tiers = {
		["default:apple"] = 1, ["default:blueberries"] = 1,
		["mobs:meat_raw"] = 1, ["grug_mobs:raw_fish"] = 1,
		["grug_gathering:corn"] = 1, ["grug_gathering:potato"] = 1,
		["grug_gathering:melon"] = 1, ["grug_gathering:mushroom"] = 3,
		["grug_gathering:wild_cocoa"] = 6,
		["grug_cooking:wild_grain"] = 1, ["grug_cooking:carrot"] = 1,
		["grug_cooking:cassava"] = 1, ["grug_cooking:pumpkin"] = 2,
		["grug_cooking:blightberry"] = 2, ["grug_cooking:sunberry"] = 2,
		["grug_cooking:jungle_berry"] = 2, ["grug_cooking:frost_melon"] = 3,
		["grug_cooking:bamboo_shoot"] = 1, ["grug_cooking:cave_cap"] = 3,
	}
	local raw_count = 0
	for name, tier in pairs(raw_tiers) do
		raw_count = raw_count + 1
		local definition = registered[name]
		check(definition and definition._grug_tier == tier and
			definition.groups.grug_food_raw == 1,
			"raw tier differs for " .. name)
	end
	check(not registered["grug_gathering:rock_salt"].groups.grug_food and
		registered["grug_gathering:rock_salt"].on_use == nil,
		"rock salt remains edible")
	check(registered["grug_gathering:wild_cocoa"].groups.grug_food_role_hp == 1 and
		not registered["grug_gathering:wild_cocoa"].groups.grug_food_role_mana,
		"wild cocoa remains mana food")
	row("raw_tiers", tostring(raw_count), "rock_salt=inedible", "cocoa=hp")

	local fish_names = {}
	for band = 1, 6 do
		fish_level = (band - 1) * 10 + 1
		local catch_table = grug_fishing.table_for({x = band, y = 0, z = band})
		check(catch_table == grug_fishing.CATCH_TABLES[band],
			"level lookup chose wrong fish band " .. band)
		local total = 0
		local fish
		for index = 1, #catch_table do
			local entry = catch_table[index]
			total = total + entry.weight
			check(registered[entry.name] ~= nil,
				"catch table names unregistered item " .. entry.name)
			if core.get_item_group(entry.name, "food_fish_raw") > 0 then fish = entry.name end
		end
		check(total == 100 and fish ~= nil, "fish table incomplete at band " .. band)
		check(registered[fish] and registered[fish]._grug_tier == band,
			"fish raw tier differs at band " .. band)
		fish_names[#fish_names + 1] = fish
	end
	row("fish", table.concat(fish_names, ","), "salt=fresh")

	local values = {}
	local meta = {
		get_string = function(_, key) return values[key] or "" end,
		set_string = function(_, key, value) values[key] = tostring(value) end,
		get_int = function(_, key) return tonumber(values[key]) or 0 end,
		set_int = function(_, key, value) values[key] = tostring(value) end,
	}
	local level19 = {level = 19, get_meta = function() return meta end,
		get_player_name = function() return "level19" end}
	check(grug_jobs.learn(level19, "cooking"), "level-19 cook could not learn")
	local real_profession_level = grug_jobs.profession_level
	grug_jobs.profession_level = function(player, profession)
		if player == level19 and profession == "cooking" then return 3 end
		return real_profession_level(player, profession)
	end
	local tier3_recipe = grug_jobs.recipe_for_output(
		"grug_cooking:foragers_pot", "grid")
	local craft_allowed = grug_jobs.can_craft_recipe(level19, tier3_recipe)
	local eat_allowed, required = grug_core.can_use_item_level(level19,
		"grug_cooking:foragers_pot")
	check(craft_allowed == true and eat_allowed == false and required == 21,
		"craft and consumption level gates are not separate")
	row("level_gate", "L19/T3-cook=craft", "L21-food=refused")

	local collision_ok, collision_error = pcall(grug_jobs.validate_recipe_collisions)
	check(collision_ok, "final recipe collision audit failed: " ..
		tostring(collision_error))

	if #failures > 0 then
		restore()
		error("r8_cook KAT: " .. table.concat(failures, "; "), 0)
	end
	row("result", "PASS")
	restore()
	return table.concat(report, "\n") .. "\n"
end
