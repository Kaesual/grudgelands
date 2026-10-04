-- Explicitly selected station operations never participate in grid matching.
-- Loaded by the first content catalog after Jobs and Quality are available.
local operations, by_id = {}, {}

-- Two kinds (Round 33): an "enchant" writes one stat of its tier into one
-- channel of an item of `family`; an "upgrade" lifts an item of one of its
-- `families` and of its material tier to the tier's top item level
-- (grug_quality operation_plan does both).
function grug_jobs.register_station_operation(definition)
	assert(type(definition) == "table", "station operation must be a table")
	local recipe = table.copy(definition)
	assert(type(recipe.id) == "string" and not by_id[recipe.id],
		"station operation id must be unique")
	assert(recipe.operation == "enchant" or recipe.operation == "upgrade",
		"station operation family differs")
	assert(type(recipe.tier) == "number" and recipe.tier % 1 == 0 and
		recipe.tier >= 1 and recipe.tier <= 6, "station operation tier differs")
	assert(grug_jobs.PROFESSIONS[recipe.profession], "station operation profession differs")
	assert(grug_jobs.station_info(recipe.station), "station operation station differs")
	if recipe.operation == "enchant" then
		assert(recipe.enchant_channel == "prefix" or recipe.enchant_channel == "suffix",
			"station operation channel differs")
		local pool = grug_items.enchant_pool(recipe.family, recipe.enchant_channel)
		assert(pool, "station operation family differs")
		local legal
		for _, stat in ipairs(pool) do
			if stat == recipe.enchant_stat then legal = true end
		end
		assert(legal, "station operation stat differs")
	else
		assert(type(recipe.families) == "table" and #recipe.families > 0,
			"station operation families missing")
		recipe.family_set = {}
		for _, family in ipairs(recipe.families) do
			assert(grug_items.enchant_pool(family, "prefix"), "station operation family differs")
			recipe.family_set[family] = true
		end
	end
	recipe.flat_inputs = grug_jobs._flatten_inputs(recipe.inputs)
	assert(#recipe.flat_inputs >= 2, "station operation materials missing")
	recipe.output_name = recipe.output
	recipe.in_place = true
	-- Keyed by id in the recipe books, never a recipe for its preview item.
	recipe.station_operation = true
	-- Every operation is a real recipe and awards progress (state.lua).
	recipe.progress = true
	operations[#operations + 1] = recipe
	by_id[recipe.id] = recipe
	return recipe
end

function grug_jobs.station_operation(id)
	return by_id[id]
end

function grug_jobs.station_operations(station)
	local result = {}
	for index = 1, #operations do
		local recipe = operations[index]
		if not station or recipe.station == station then result[#result + 1] = recipe end
	end
	return result
end

core.register_on_mods_loaded(function()
	for index = 1, #operations do
		local recipe = operations[index]
		assert(core.registered_items[recipe.output_name], "station operation preview item missing")
		local same_tier
		for _, item in ipairs(recipe.flat_inputs) do
			assert(core.registered_items[item], "station operation material missing: " .. item)
			if grug_jobs.ingredient_tier(item) == recipe.tier then same_tier = true end
		end
		assert(same_tier, "station operation needs an ingredient of its own tier")
	end
end)
