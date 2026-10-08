local A = grug_artisans
local C = "grug_artisans:"
local M = "grug_materials:"

local function grid(inputs)
	local result = {}
	for index = 1, #inputs do
		local row = math.floor((index - 1) / 3) + 1
		local column = (index - 1) % 3 + 1
		result[row] = result[row] or {}
		result[row][column] = inputs[index]
	end
	return result
end

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
		A.register_recipe("goldsmith", {tier = tier,
			station = "jewellers_bench", inputs = {{resource.raw_item}},
			output = resource.cut_item, material = true,
			hint = "Cut at a Jeweller's Bench"})
		if resource.gem then gem_by_tier[tier] = resource.cut_item end
	end
end

-- Cut-gem storage blocks (Round 33): a plain 9 <-> 1 Basics recipe anyone may
-- use, so the blocks serve as building accents. The unpack is no second
-- route to a cut gem (grug_jobs registry.lua storage_unpack).
for _, resource in ipairs(grug_materials.RESOURCES) do
	if resource.gem and resource.cut_item and resource.block_node then
		local cut = resource.cut_item
		core.register_craft({output = resource.block_node,
			recipe = {{cut, cut, cut}, {cut, cut, cut}, {cut, cut, cut}}})
		core.register_craft({output = cut .. " 9", recipe = {{resource.block_node}}})
	end
end

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
	A.register_recipe("goldsmith", {tier = tier, station = "jewellers_bench",
		inputs = {row.inputs}, output = row.item, material = true,
		hint = "Form at a Jeweller's Bench"})
end

local trinkets = {
	{key = "manawell", settings = 1},
	{key = "last_light", settings = 2},
	{key = "battlebeat", settings = 3},
	{key = "apothecary_loop", settings = 4},
	{key = "mercy_seal", settings = 5},
	{key = "reclaimers_mark", settings = 6},
}

-- Round 9 ruling 39: the identity-specific Setting counts are a temporary
-- collision key for the input-authoritative station registry. Replace them
-- with station output selection or one authored per-identity ingredient.

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
			station = "jewellers_bench", inputs = grid(inputs),
			output = grug_gear.trinket_item(row.key, tier),
			hint = "Assemble at a Jeweller's Bench"})
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
