local A = grug_artisans
local C = "grug_artisans:"

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

end
