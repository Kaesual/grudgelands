-- Disposable full-game registration/catalog probe. No map emergence or players.
local storage = core.get_mod_storage()
core.register_on_mods_loaded(function()
	core.after(0, function()
		assert(jit and jit.version, "Round12 native probe requires LuaJIT")
		core.log("action", "ROUND12 runtime " .. jit.version)
		local inventory = core.create_detached_inventory("r12_probe_owned", {})
		inventory:set_size("main", 32)
		inventory:set_size("craft", 9)
		inventory:set_size("grug_bag1_content", 8)
		local actor = {get_player_name = function() return "r12_probe" end,
			get_inventory = function() return inventory end,
			get_meta = function() return storage end,
			is_player = function() return true end}
		local records = grug_jobs.book_records(actor, "general")
		local count, starters, late_sword, tier_one_armor = 0, 0, nil, 0
		for _, recipe in ipairs(records) do
			count = count + 1
			assert(recipe.basics_presentation, "route without presentation " .. recipe.output_name)
			assert(recipe.output_name ~= "grug_cooking:bread" and
				recipe.output_name ~= "mobs:meat" and
				recipe.output_name ~= "grug_fishing:cooked_fish", "Cooking leaked into Basics")
			if recipe.basics_presentation.starter then starters = starters + 1 end
			if recipe.output_name == "grug_gear:sword_abyssal_steel" then late_sword = recipe end
			if recipe.output_name:match("^grug_gear:%a+_metal_bronze$") then
				assert(grug_jobs.recipe_discovered(actor, recipe), "Bronze armor hidden at start")
				tier_one_armor = tier_one_armor + 1
			end
		end
		assert(count > 50 and starters > 10 and tier_one_armor >= 4 and late_sword)
		assert(not grug_jobs.recipe_discovered(actor, late_sword), "late recipe initially visible")
		inventory:set_stack("grug_bag1_content", 1, "grug_materials:abyssal_steel_bar")
		assert(grug_jobs._scan_discovery(actor), "bag acquisition not recorded")
		assert(grug_jobs.recipe_discovered(actor, late_sword), "main material alone did not reveal sword")
		local craft = core.get_craft_result({method = "normal", width = 3, items = {
			"", "grug_materials:abyssal_steel_bar", "",
			"", "grug_materials:abyssal_steel_bar", "",
			"", "default:stick", ""}})
		assert(craft.item:get_name() == "grug_gear:sword_abyssal_steel", "universal sword craft changed")
		assert(grug_food.DURATION == 300)
		assert(sfinv.pages["grug_skills:skills"] and sfinv.pages["creative:food"])
		creative.init_creative_inventory(actor)
		local food_page = sfinv.pages["creative:food"]
		local form = food_page:get(actor, {nav_titles = {"Food"}, nav_idx = 1})
		assert(form:find("size[10.4,11.1]", 1, true) and form:find("1.2,7.2;8,1", 1, true))
		local food_inventory = core.get_inventory({type = "detached", name = "creative_r12_probe"})
		assert(food_inventory:contains_item("main", "grug_cooking:jungle_cocoa"), "Food omitted Jungle Cocoa")
		assert(food_inventory:contains_item("main", "grug_cooking:carrot"), "Food omitted raw carrot")
		for _, id in ipairs({"hold_ground", "cinderfall", "glacial_ward", "word_of_ruin"}) do
			assert(grug_abilities.registered[id] and grug_abilities.registered[id].talent_gated)
		end
		grug_skills.guard_destinations()
		for name, callbacks in pairs(core.detached_inventories) do
			assert(name:match("^grug_skills_") or callbacks._grug_bound_guard,
				"unguarded detached inventory " .. name)
		end
		core.log("action", ("ROUND12 RESULT PASS routes=%d starters=%d foods=%d armor=%d")
			:format(count, starters, food_inventory:get_size("main"), tier_one_armor))
	end)
end)
