local A = grug_artisans
local C = "grug_artisans:"
local G = "grug_gear:"

local tiers = {
	{key = "seasoned", name = "Seasoned", gear = "bronze", grip = "light"},
	{key = "polished", name = "Polished", gear = "iron", grip = "cured"},
	{key = "hardened", name = "Hardened", gear = "steel", grip = "heavy"},
	{key = "inlaid", name = "Inlaid", gear = "silversteel", grip = "scaled",
		main_gem = "ruby", offhand_gem = "sapphire"},
	{key = "lacquered", name = "Lacquered", gear = "embersteel", grip = "sleek",
		main_gem = "diamond", offhand_gem = "ruby"},
	{key = "heartwood", name = "Heartwood", gear = "abyssal_steel",
		grip = "nightscale", main_gem = "sapphire", offhand_gem = "diamond"},
}

local reagents = {
	[1] = "default:coal_lump",
	[2] = "grug_mobs:venom_gland",
	[3] = "grug_mobs:slime_gel",
	[4] = "grug_mobs:croc_tooth",
	[5] = "grug_gathering:stormkelp",
	[6] = "grug_mobs:stone_core",
}

local families = {"wand", "scepter", "orb", "staff"}

A.register_ingredient("group:wood", 1)
A.register_ingredient("grug_materials:cut_diamond", 4)
A.register_ingredient("grug_materials:cut_sapphire", 4)
A.register_ingredient("grug_materials:cut_ruby", 4)

for tier = 1, #tiers do
	local row = tiers[tier]
	local wood = A.register_item(C .. row.key .. "_wood", row.name .. " Wood",
		"default_wood.png^[colorize:#" ..
			({"9b744d", "bb966d", "7f6547", "78644f", "5f493e", "392d35"})[tier] ..
			":90", {grug_profession_material = 1, grug_wood_grade = tier})
	A.register_ingredient(wood, tier)
	local material_inputs
	if tier == 1 then
		material_inputs = {{"group:wood", "group:wood"}}
	else
		material_inputs = {{C .. tiers[tier - 1].key .. "_wood", "group:wood"}}
	end
	core.clear_craft({output = wood})
	core.register_craft({output = wood, recipe = material_inputs})

	for family_index = 1, #families do
		local output = G .. families[family_index] .. "_" .. row.gear
		A.register_refinement(tier, output, wood)
		A.register_add_affix(tier, output, wood, reagents[tier])
	end

	if tier >= 2 then
		A.register_ingredient(reagents[tier], tier)
		local imbue = A.register_item(C .. "wood_oil_imbue_" .. row.key,
			row.name .. " Wood-Oil Imbue Kit",
			"default_papyrus.png^[colorize:#8b6c3e:115",
			{grug_upgrade_kit = 1, grug_wood_oil_imbue = tier})
		A.register_recipe("woodcarver", {tier = tier, station = "carving_bench",
			inputs = {{wood, reagents[tier]}}, output = imbue,
			hint = "Blend at a Carving Bench"})
	end
	if tier >= 3 then
		local temper = A.register_item(C .. "wood_oil_temper_" .. row.key,
			row.name .. " Wood-Oil Temper Kit",
			"default_papyrus.png^[colorize:#536878:125",
			{grug_upgrade_kit = 1, grug_wood_oil_temper = tier})
		A.register_recipe("woodcarver", {tier = tier, station = "carving_bench",
			inputs = {{wood, wood, reagents[tier]}}, output = temper,
			hint = "Blend at a Carving Bench"})
	end
end
