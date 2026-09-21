grug_core.request_starts_preload = function() end
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
	core.after(0.1, function() core.request_shutdown("catalog captured", false, 0) end)
end)
