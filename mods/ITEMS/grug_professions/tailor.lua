local P = grug_professions
local C = "grug_professions:"

-- The six cloth bolts. Each bolt's recipe (two cloths or silks and a
-- Thread) is Basic (grug_jobs/basic_recipes.lua).
local tiers = {
	{key = "patch", name = "Patch", source = "grug_mobs:linen_scrap"},
	{key = "woven", name = "Woven", source = "grug_mobs:linen_cloth"},
	{key = "heavy", name = "Heavy", source = "grug_mobs:heavy_cloth"},
	{key = "silkweave", name = "Silkweave", source = "grug_mobs:spider_silk"},
	{key = "silk", name = "Silk"},
	{key = "stormweave", name = "Stormweave"},
}

for tier = 1, #tiers do
	local row = tiers[tier]
	local bolt = P.register_item(C .. "bolt_" .. row.key, row.name .. " Bolt",
		"default_paper.png^[colorize:#" ..
		({"a88b70", "cab795", "8c735e", "9278a4", "d0b8c8", "596b91"})[tier] ..
		":105", {grug_profession_material = 1, grug_tailor_bolt = tier})
	if tier <= 4 then
		P.register_ingredient(row.source, tier)
	elseif tier == 6 then
		P.register_ingredient("grug_gathering:stormkelp", 5)
	end
	P.register_ingredient(bolt, tier)
end

local woven_bundle = P.register_item(C .. "woven_bolt_bundle",
	"Bundle of Four Woven Bolts",
	"default_paper.png^[colorize:#cab795:105", {grug_tailor_bundle = 4})
P.register_ingredient(woven_bundle, 2)
P.register_recipe("tailor", {tier = 2, output = woven_bundle,
	ingredients = {{item = C .. "bolt_woven", n = 4}}, material = true,
	time = grug_jobs.DURATIONS.material})

local heavy_bundle = P.register_item(C .. "heavy_bolt_bundle",
	"Bundle of Five Heavy Bolts",
	"default_paper.png^[colorize:#8c735e:105", {grug_tailor_bundle = 5})
P.register_ingredient(heavy_bundle, 3)
P.register_recipe("tailor", {tier = 3, output = heavy_bundle,
	ingredients = {{item = C .. "bolt_heavy", n = 5}}, material = true,
	time = grug_jobs.DURATIONS.material})

-- Cloth bags give profession XP and need only the profession tier (Round 45
-- rulings 7 and 8).
local function bag(tier, output, ingredients)
	P.register_recipe("tailor", {tier = tier, output = output,
		ingredients = ingredients, time = grug_jobs.DURATIONS.bag})
end
bag(1, "grug_inventory:bag_small", {{item = C .. "bolt_patch", n = 6},
	{item = "grug_mobs:light_leather", n = 2}})
bag(2, "grug_inventory:bag_medium", {{item = woven_bundle, n = 2},
	{item = C .. "cured_leather", n = 2}})
bag(4, "grug_inventory:bag_large", {{item = heavy_bundle, n = 2},
	{item = "grug_mobs:spider_silk", n = 4}, {item = "grug_mobs:heavy_leather", n = 2}})
bag(5, "grug_inventory:bag_great", {{item = C .. "bolt_silk", n = 8},
	{item = "grug_mobs:spider_silk", n = 1}})

-- The spellbook (Round 33, item_tiers.md §3.3; from the Goldsmith): two bolts
-- of the tier and a Parchment, gear like every offhand.
local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
for tier = 1, #tiers do
	local bolt = C .. "bolt_" .. tiers[tier].key
	P.register_recipe("tailor", {tier = tier,
		output = "grug_gear:spellbook_" .. METALS[tier],
		ingredients = {{item = bolt, n = 2}, {item = C .. "parchment", n = 1}},
		time = grug_jobs.DURATIONS.gear})
end
