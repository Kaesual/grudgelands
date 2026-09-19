local P = grug_professions
local C = "grug_professions:"
local G = "grug_gear:"
local THREAD = C .. "thread"

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

local tiers = {
	{key = "patch", name = "Patch", source = "grug_mobs:linen_scrap",
		inputs = {"grug_mobs:linen_scrap", "grug_mobs:linen_scrap", THREAD}},
	{key = "woven", name = "Woven", source = "grug_mobs:linen_cloth",
		inputs = {"grug_mobs:linen_cloth", "grug_mobs:linen_cloth", THREAD}},
	{key = "heavy", name = "Heavy", source = "grug_mobs:heavy_cloth",
		inputs = {"grug_mobs:heavy_cloth", "grug_mobs:heavy_cloth", THREAD}},
	{key = "silkweave", name = "Silkweave", source = "grug_mobs:spider_silk",
		inputs = {C .. "bolt_heavy", "grug_mobs:spider_silk", THREAD}},
	{key = "silk", name = "Silk", recipe_tier = 5, material = true,
		inputs = {"grug_mobs:spider_silk", "grug_mobs:spider_silk", THREAD}},
	{key = "stormweave", name = "Stormweave", recipe_tier = 6, material = true,
		inputs = {"grug_mobs:spider_silk", "grug_gathering:stormkelp", THREAD}},
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
	P.register_recipe("tailor", {tier = row.recipe_tier or tier,
		station = "tailor_bench",
		inputs = grid(row.inputs), output = bolt,
		material = row.material,
		hint = "Weave at a Tailor Bench"})

	for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
		P.register_refinement("tailor", tier, "cloth_armor",
			G .. slot .. "_cloth_" .. row.key, bolt)
	end

	if tier >= 2 then
		local imbue = P.register_item(C .. "embroidery_imbue_" .. row.key,
			row.name .. " Embroidery Imbue Kit",
			"default_paper.png^[colorize:#8d568f:125",
			{grug_upgrade_kit = 1, grug_embroidery_imbue = tier})
		P.register_recipe("tailor", {tier = tier, station = "tailor_bench",
			inputs = {{bolt, C .. "parchment"}}, output = imbue,
			hint = "Weave at a Tailor Bench"})
	end
	if tier >= 3 then
		local temper = P.register_item(C .. "embroidery_temper_" .. row.key,
			row.name .. " Embroidery Temper Kit",
			"default_paper.png^[colorize:#58647f:135",
			{grug_upgrade_kit = 1, grug_embroidery_temper = tier})
		P.register_recipe("tailor", {tier = tier, station = "tailor_bench",
			inputs = {{bolt, C .. "parchment", THREAD}}, output = temper,
			hint = "Weave at a Tailor Bench"})
	end
end

local woven_bundle = P.register_item(C .. "woven_bolt_bundle",
	"Bundle of Four Woven Bolts",
	"default_paper.png^[colorize:#cab795:105", {grug_tailor_bundle = 4})
P.register_ingredient(woven_bundle, 2)
P.register_recipe("tailor", {tier = 2, station = "tailor_bench",
	inputs = {{C .. "bolt_woven", C .. "bolt_woven", C .. "bolt_woven"},
		{C .. "bolt_woven", "", ""}}, output = woven_bundle,
	hint = "Bundle at a Tailor Bench"})

local heavy_bundle = P.register_item(C .. "heavy_bolt_bundle",
	"Bundle of Five Heavy Bolts",
	"default_paper.png^[colorize:#8c735e:105", {grug_tailor_bundle = 5})
P.register_ingredient(heavy_bundle, 3)
P.register_recipe("tailor", {tier = 3, station = "tailor_bench",
	inputs = {{C .. "bolt_heavy", C .. "bolt_heavy", C .. "bolt_heavy"},
		{C .. "bolt_heavy", C .. "bolt_heavy", ""}}, output = heavy_bundle,
	hint = "Bundle at a Tailor Bench"})

P.register_recipe("tailor", {tier = 1, station = "tailor_bench",
	inputs = {{C .. "bolt_patch", C .. "bolt_patch", C .. "bolt_patch"},
		{C .. "bolt_patch", "grug_mobs:light_leather", C .. "bolt_patch"},
		{C .. "bolt_patch", "grug_mobs:light_leather", ""}},
	output = "grug_inventory:bag_small", hint = "Sew at a Tailor Bench"})
P.register_recipe("tailor", {tier = 2, station = "tailor_bench",
	inputs = {{woven_bundle, woven_bundle, C .. "cured_leather"},
		{"", C .. "cured_leather", ""}},
	output = "grug_inventory:bag_medium", hint = "Sew at a Tailor Bench"})
P.register_recipe("tailor", {tier = 4, station = "tailor_bench",
	inputs = {{heavy_bundle, heavy_bundle, "grug_mobs:spider_silk"},
		{"grug_mobs:spider_silk", "grug_mobs:heavy_leather",
			"grug_mobs:spider_silk"},
		{"grug_mobs:heavy_leather", "grug_mobs:spider_silk", ""}},
	output = "grug_inventory:bag_large", hint = "Sew at a Tailor Bench"})
