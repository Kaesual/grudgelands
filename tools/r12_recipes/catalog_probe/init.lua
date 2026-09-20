local function item_name(value)
	return ItemStack(value):get_name()
end

local function maximum_index(value)
	local maximum = 0
	for index in pairs(value or {}) do
		if type(index) == "number" and index > maximum then maximum = index end
	end
	return maximum
end

local function display(items)
	local slots = {}
	for index = 1, maximum_index(items) do slots[index] = item_name(items[index]) end
	return slots
end

local function hex(value)
	return (value:gsub(".", function(char) return ("%02x"):format(char:byte()) end))
end

local function emit(station, output, method, width, shapeless, items, owner)
	local fields = {station, hex(output), method, tostring(width),
		shapeless and "1" or "0", owner or "general"}
	local slots = display(items)
	for index = 1, #slots do fields[#fields + 1] = hex(slots[index]) end
	core.log("action", "[r12recipe] " .. table.concat(fields, "\t"))
end

core.register_on_mods_loaded(function()
	core.log("action", "[r12recipe] runtime=" ..
		(rawget(_G, "jit") and jit.version or _VERSION))
	local names = {}
	for name in pairs(core.registered_items) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		local output = names[index]
		for _, recipe in ipairs(core.get_all_craft_recipes(output) or {}) do
			local station = recipe.method == "cooking" and "furnace" or
				(recipe.method == "normal" and "grid" or nil)
			if station then
				local width = tonumber(recipe.width) or 0
				local shapeless = recipe.method == "normal" and width == 0
				local owned = grug_jobs.recipe_for_craft(station, output,
					recipe.items or {})
				local owner = owned and owned.profession or "general"
				emit(station, output, recipe.method, width, shapeless,
					recipe.items or {}, owner)
			end
		end
	end
	if rawget(_G, "grug_smelting") then
		for _, recipe in ipairs(grug_smelting.RECIPES or {}) do
			local owned = grug_jobs.recipe_for_craft("dual_furnace", recipe.output,
				recipe.inputs)
			local owner = owned and owned.profession or "general"
			emit("dual_furnace", item_name(recipe.output), "dual_furnace", 2,
				true, recipe.inputs, owner)
		end
	end
	local basics = grug_jobs.book_records(nil, "general")
	assert(#basics == 596, "Basics route count differs: " .. #basics)
	local starter_count, dual_count = 0, 0
	local bronze_armor = {}
	for index = 1, #basics do
		local recipe = basics[index]
		local declaration = assert(recipe.basics_presentation)
		if declaration.starter then starter_count = starter_count + 1 end
		if recipe.station == "dual_furnace" then
			dual_count = dual_count + 1
			assert(declaration.main_material == recipe.flat_inputs[1],
				"dual-furnace main material differs: " .. recipe.output_name)
		end
		if recipe.output_name:match("^grug_gear:[a-z]+_metal_bronze$") then
			assert(declaration.starter, "Bronze armor route is not starter")
			bronze_armor[recipe.output_name] = true
		end
		assert(recipe.output_name ~= "grug_cooking:bread" and
			recipe.output_name ~= "mobs:meat" and
			recipe.output_name ~= "grug_fishing:cooked_fish",
			"Cooking-owned refinement leaked into Basics")
	end
	local armor_count = 0
	for _ in pairs(bronze_armor) do armor_count = armor_count + 1 end
	assert(dual_count == 5 and armor_count == 4 and starter_count == 63,
		("Basics anchors differ: dual=%d armor=%d starter=%d")
		:format(dual_count, armor_count, starter_count))
	local refinements = {}
	for _, recipe in ipairs(grug_jobs.book_records(nil, "cooking")) do
		if recipe.output_name == "grug_cooking:bread" or
				recipe.output_name == "mobs:meat" or
				recipe.output_name == "grug_fishing:cooked_fish" then
			refinements[recipe.output_name] = true
		end
	end
	assert(refinements["grug_cooking:bread"] and refinements["mobs:meat"] and
		refinements["grug_fishing:cooked_fish"],
		"Cooking refinement is absent from its owning book")
	local authorities = {
		{"grug_cooking:bread", "grug_cooking:wild_grain"},
		{"mobs:meat", "mobs:meat_raw"},
		{"grug_fishing:cooked_fish", "grug_mobs:raw_fish"},
	}
	for index = 1, #authorities do
		local recipe = grug_jobs.recipe_for_craft("furnace",
			authorities[index][1], {authorities[index][2]})
		assert(recipe and recipe.profession == "cooking" and recipe.tier == 1,
			"Cooking furnace authority differs: " .. authorities[index][1])
	end
	core.log("action", ("[r12recipe] AUDIT catalog=830 basics=%d starter=%d dual=%d bronze_armor=%d cooking_authority=3")
		:format(#basics, starter_count, dual_count, armor_count))
	core.log("action", "[r12recipe] DONE")
	core.request_shutdown("recipe catalog complete", false, 0)
end)
