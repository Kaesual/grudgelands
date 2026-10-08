local A = grug_artisans
local C = "grug_artisans:"
local M = "grug_materials:"

-- The six depth-tiered gems (economy plan §6): each cuts at the tier it is
-- mined at, and its raw and cut forms are ingredients of that tier. Raw
-- Quartz is a T1 enchant input, a mineral without a cut form (Round 33).
A.register_ingredient(M .. "quartz", 1)
local gem_by_tier = {}
for _, resource in ipairs(grug_materials.RESOURCES) do
	if resource.cut_item then
		local tier = resource.harvest_tier
		A.register_ingredient(resource.raw_item, tier)
		A.register_ingredient(resource.cut_item, tier)
		A.register_recipe("goldsmith", {tier = tier, output = resource.cut_item,
			ingredients = {{item = resource.raw_item, n = 1}}, material = true,
			time = grug_jobs.DURATIONS.material})
		if resource.gem then gem_by_tier[tier] = resource.cut_item end
	end
end

-- Cut-gem storage blocks (Round 33): a plain 9 <-> 1 Basic recipe anyone may
-- use, so the blocks serve as building accents (grug_jobs/basic_recipes.lua).
-- The unpack only returns what was packed: no second route to a cut gem.

local settings = {
	{key = "tin", name = "Tin Setting", inputs = {M .. "tin_bar", M .. "tin_bar"}},
	{key = "iron", name = "Iron Setting", inputs = {M .. "iron_bar", M .. "iron_bar"}},
	{key = "copper_inlaid_steel", name = "Copper-inlaid Steel Setting",
		inputs = {M .. "steel_bar", M .. "copper_bar"}},
	{key = "gold", name = "Gold Setting", inputs = {M .. "gold_bar", M .. "gold_bar"}},
	{key = "gold_filigreed_embersteel", name = "Gold-filigreed Embersteel Setting",
		inputs = {M .. "embersteel_bar", M .. "gold_bar"}},
	{key = "gold_filigreed_abyssal_steel",
		name = "Gold-filigreed Abyssal Steel Setting",
		inputs = {M .. "abyssal_steel_bar", M .. "gold_bar"}},
}

local setting_sources = {
	[M .. "tin_bar"] = 1,
	[M .. "copper_bar"] = 1,
	[M .. "iron_bar"] = 2,
	[M .. "gold_bar"] = 2,
	[M .. "steel_bar"] = 3,
	[M .. "embersteel_bar"] = 5,
	[M .. "abyssal_steel_bar"] = 6,
}
for item, tier in pairs(setting_sources) do A.register_ingredient(item, tier) end

for tier = 1, #settings do
	local row = settings[tier]
	row.item = A.register_item(C .. "setting_" .. row.key, row.name,
		"default_gold_ingot.png^[colorize:#" ..
			({"b7a289", "8c8c86", "6f7781", "ddb64d", "9e633e", "59436f"})[tier] ..
			":100", {grug_profession_material = 1, grug_jewellery_setting = tier})
	A.register_ingredient(row.item, tier)
	A.register_recipe("goldsmith", {tier = tier, output = row.item,
		ingredients = grug_jobs.ingredient_list(row.inputs), material = true,
		time = grug_jobs.DURATIONS.material})
end

local trinkets = {
	{key = "manawell", settings = 1},
	{key = "last_light", settings = 2},
	{key = "battlebeat", settings = 3},
	{key = "apothecary_loop", settings = 4},
	{key = "mercy_seal", settings = 5},
	{key = "reclaimers_mark", settings = 6},
}

-- Round 9 ruling 39 made the Setting count (1 to 6) tell the identities
-- apart in the old input-matched registry. Since Round 45 a craft names its
-- recipe, so that reason is gone; the counts stay as today's ingredients
-- (spec §2.34).

-- The cut gem of the recipe tier (Citrine at T1 ... Diamond at T6, as in the
-- mines), plus the T4 gem at T5 and the T5 and T4 gems at T6.
local function trinket_gems(tier)
	local gems = {gem_by_tier[tier]}
	for lower = tier - 1, 4, -1 do gems[#gems + 1] = gem_by_tier[lower] end
	return gems
end

for tier = 1, 6 do
	local setting = settings[tier].item
	for identity_index = 1, #trinkets do
		local row = trinkets[identity_index]
		local inputs = {}
		for setting_index = 1, row.settings do inputs[#inputs + 1] = setting end
		local gems = trinket_gems(tier)
		for gem_index = 1, #gems do inputs[#inputs + 1] = gems[gem_index] end
		A.register_recipe("goldsmith", {tier = tier,
			output = grug_gear.trinket_item(row.key, tier),
			ingredients = grug_jobs.ingredient_list(inputs),
			time = grug_jobs.DURATIONS.gear})
	end
end

function grug_artisans.settle_goldsmith_bonus(event, roll)
	if type(event) ~= "table" or type(event.resource) ~= "table" or
			not event.resource.gem or
			type(event.raw_item) ~= "string" then
		return false
	end
	local player = event.digger
	if not player or not player.is_player or not player:is_player() or
			not grug_jobs.has(player, "goldsmith") then
		return false
	end
	local chance = grug_items.mastery_band(player) >= 2 and 20 or 10
	roll = math.floor(tonumber(roll) or 101)
	if roll < 1 or roll > chance then return false end
	if not player:get_inventory() then return false end
	local leftover = grug_inventory.give(player, event.raw_item)
	if leftover and not leftover:is_empty() then
		core.add_item(event.pos or player:get_pos(), leftover)
	end
	return true
end

grug_materials.register_on_harvest(function(event)
	grug_artisans.settle_goldsmith_bonus(event, math.random(1, 100))
end)
