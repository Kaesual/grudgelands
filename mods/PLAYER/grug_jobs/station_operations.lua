-- Station operations: enchants and upgrades, named by id, never matched from
-- ingredients. Loaded by the first content catalog after Jobs and Quality are
-- available.
--
-- Two kinds (Round 33, Round 45 lane EU): an "enchant" writes one stat of its
-- tier into one channel of an item of `family`; an "upgrade" adds item levels
-- to an item of one of its `families` and of its material tier, up to the
-- tier's cap 10 x tier (grug_quality operation_plan does both). Both run as
-- crafting jobs on the item in the Crafting tab's target slot
-- (operation_jobs.lua). `ingredients` (registry-style entries, from
-- `inputs`) are what one enchant or one upgrade level costs; an upgrade of a
-- weapon also takes `weapon_extra` per level (spec §2.32: a Stick).
local operations, by_id = {}, {}
local upgrades = {} -- profession -> tier -> upgrade operation

local function entry_list(list, label)
	assert(type(list) == "table", label .. " must be a list")
	for _, entry in ipairs(list) do
		assert(type(entry) == "table" and type(entry.item) == "string" and
			type(entry.n) == "number" and entry.n >= 1 and entry.n % 1 == 0, label .. " differs")
	end
	return list
end

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
		recipe.weapon_extra = entry_list(recipe.weapon_extra or {},
			"station operation weapon_extra")
		upgrades[recipe.profession] = upgrades[recipe.profession] or {}
		assert(not upgrades[recipe.profession][recipe.tier],
			"one upgrade per profession and tier")
		upgrades[recipe.profession][recipe.tier] = recipe
	end
	recipe.flat_inputs = grug_jobs._flatten_inputs(recipe.inputs)
	assert(#recipe.flat_inputs >= (recipe.operation == "enchant" and 2 or 1),
		"station operation materials missing")
	recipe.ingredients = grug_jobs.ingredient_list(recipe.flat_inputs)
	recipe.output_name = recipe.output
	recipe.in_place = true
	-- Keyed by id, never a recipe for its preview item.
	recipe.station_operation = true
	-- Enchants are counting crafts and award progress (state.lua); upgrades
	-- never do (spec §2.31: cheap upgrades are no XP farm).
	recipe.progress = recipe.operation == "enchant"
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

-- The upgrade of `profession` for items of material tier `tier`, or nil.
function grug_jobs.upgrade_operation(profession, tier)
	return (upgrades[profession] or {})[tier]
end

-- What one enchant, or one upgrade level, of `recipe` costs on `stack`: the
-- operation's ingredients, plus `weapon_extra` for an upgraded weapon.
function grug_jobs.operation_ingredients(recipe, stack)
	if recipe.operation ~= "upgrade" or #recipe.weapon_extra == 0 or not stack or
			core.get_item_group(ItemStack(stack):get_name(), "grug_equip_weapon") <= 0 then
		return recipe.ingredients
	end
	local list = {}
	for index, entry in ipairs(recipe.ingredients) do list[index] = entry end
	for _, extra in ipairs(recipe.weapon_extra) do
		local merged
		for index, entry in ipairs(list) do
			if entry.item == extra.item then
				list[index] = {item = entry.item, n = entry.n + extra.n}
				merged = true
			end
		end
		if not merged then list[#list + 1] = {item = extra.item, n = extra.n} end
	end
	return list
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
		for _, extra in ipairs(recipe.weapon_extra or {}) do
			assert(core.registered_items[extra.item],
				"station operation material missing: " .. extra.item)
		end
	end
end)
