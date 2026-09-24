-- Disposable registration probe, staged only by tools/luanti_headless.sh.
core.register_on_mods_loaded(function()
	assert(core.registered_entities["grug_mobs:reed_angelfish"], "fish entity missing")
	assert(grug_mobs.disposition("grug_mobs:reed_angelfish") == "critter")
	local found = false
	for _, recipe in ipairs(grug_jobs.book_records(nil, "general")) do
		if recipe.output_name == "grug_gear:arrow" then
			assert(recipe.basics_presentation.starter == true, "arrows not a starter route")
			assert(grug_jobs.recipe_discovered(nil, recipe), "arrows require material discovery")
			found = true
		end
	end
	assert(found, "arrows absent from Basics")
	local items = {}
	for i, name in ipairs({"", "", "grug_materials:bronze_bar", "", "default:stick", "",
		"default:stick", "", ""}) do items[i] = ItemStack(name) end
	local result = core.get_craft_result({method = "normal", width = 3, items = items})
	assert(result.item:get_name() == "grug_gear:arrow" and result.item:get_count() == 200,
		"Bronze arrow recipe mismatch")
	core.log("action", "[r21_startup] PASS fish=critter Basics=starter Bronze-arrows=200")
	core.request_shutdown("Round 21 startup registration checks passed", false, 0)
end)
