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

local cuts = {
	{key = "quartz", tier = 1, raw = M .. "quartz"},
	{key = "citrine", tier = 2, raw = M .. "rough_citrine"},
	{key = "garnet", tier = 2, raw = M .. "rough_garnet"},
	{key = "jade", tier = 2, raw = M .. "rough_jade"},
	{key = "diamond", tier = 4, raw = M .. "rough_diamond"},
	{key = "sapphire", tier = 4, raw = M .. "rough_sapphire"},
	{key = "ruby", tier = 4, raw = M .. "rough_ruby"},
}

for index = 1, #cuts do
	local row = cuts[index]
	local cut = M .. "cut_" .. row.key
	A.register_ingredient(row.raw, row.tier)
	A.register_ingredient(cut, row.tier)
	A.register_recipe("goldsmith", {tier = row.tier,
		station = "jewellers_bench", inputs = {{row.raw}}, output = cut,
		material = true, hint = "Cut at a Jeweller's Bench"})
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
	{key = "manawell", settings = 1, g1 = "citrine", g4 = "sapphire"},
	{key = "last_light", settings = 2, g1 = "jade", g4 = "sapphire"},
	{key = "battlebeat", settings = 3, g1 = "garnet", g4 = "ruby"},
	{key = "apothecary_loop", settings = 4, g1 = "jade", g4 = "ruby"},
	{key = "mercy_seal", settings = 5, g1 = "citrine", g4 = "sapphire"},
	{key = "reclaimers_mark", settings = 6, g1 = "garnet", g4 = "ruby"},
}

-- Round 9 ruling 39: the identity-specific Setting counts are a temporary
-- collision key for the input-authoritative station registry. Replace them
-- with station output selection or one authored per-identity ingredient.

local function trinket_gems(row, tier)
	if tier == 1 then return {M .. "cut_quartz"} end
	if tier <= 3 then return {M .. "cut_" .. row.g1} end
	if tier == 4 then return {M .. "cut_" .. row.g4} end
	if tier == 5 then return {M .. "cut_sapphire", M .. "cut_ruby"} end
	return {M .. "cut_diamond", M .. "cut_sapphire", M .. "cut_ruby"}
end

for tier = 1, 6 do
	local setting = settings[tier].item
	local book = "grug_gear:spellbook_" ..
		({"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"})[tier]
	A.register_recipe("goldsmith", {tier = tier,
		station = "jewellers_bench", inputs = {{setting, "grug_professions:parchment"}},
		output = book,
		mastery_required = 2, hint = "Bind at a Jeweller's Bench"})
	for identity_index = 1, #trinkets do
		local row = trinkets[identity_index]
		local inputs = {}
		for setting_index = 1, row.settings do inputs[#inputs + 1] = setting end
		local gems = trinket_gems(row, tier)
		for gem_index = 1, #gems do inputs[#inputs + 1] = gems[gem_index] end
		A.register_recipe("goldsmith", {tier = tier,
			station = "jewellers_bench", inputs = grid(inputs),
			output = grug_gear.trinket_item(row.key, tier),
			hint = "Assemble at a Jeweller's Bench"})
	end
end

local ornament_reagents = {
	[3] = "grug_mobs:slime_gel", [4] = "grug_mobs:croc_tooth",
	[5] = "grug_gathering:stormkelp", [6] = "grug_mobs:stone_core",
}
for tier = 3, 6 do
	local setting = settings[tier].item
	local reagent = ornament_reagents[tier]
	A.register_ingredient(reagent, tier)
	local ornament = A.register_item(C .. "ornament_components_t" .. tier,
		"Tier " .. tier .. " Ornament Components",
		"default_gold_ingot.png^[colorize:#a77a42:105",
		{grug_profession_material = 1, grug_ornament_components = tier})
	A.register_recipe("goldsmith", {tier = tier,
		station = "jewellers_bench",
		inputs = {{setting, M .. "gold_bar", reagent}}, output = ornament,
		hint = "Form at a Jeweller's Bench"})
end

function grug_artisans.settle_goldsmith_bonus(event, roll)
	if type(event) ~= "table" or type(event.resource) ~= "table" or
			(event.resource.grade ~= "G1" and event.resource.grade ~= "G2") or
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
	local inventory = player:get_inventory()
	if not inventory then return false end
	local leftover = inventory:add_item("main", event.raw_item)
	if leftover and not leftover:is_empty() then
		core.add_item(event.pos or player:get_pos(), leftover)
	end
	return true
end

grug_materials.register_on_harvest(function(event)
	grug_artisans.settle_goldsmith_bonus(event, math.random(1, 100))
end)
