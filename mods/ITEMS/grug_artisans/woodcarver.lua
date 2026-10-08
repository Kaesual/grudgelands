local A = grug_artisans
local C = "grug_artisans:"

local tiers = {
	{key = "seasoned", name = "Seasoned", gear = "bronze", grip = "light"},
	{key = "polished", name = "Polished", gear = "iron", grip = "cured"},
	{key = "hardened", name = "Hardened", gear = "steel", grip = "heavy"},
	{key = "inlaid", name = "Inlaid", gear = "silversteel", grip = "scaled"},
	{key = "lacquered", name = "Lacquered", gear = "embersteel", grip = "sleek"},
	{key = "heartwood", name = "Heartwood", gear = "abyssal_steel",
		grip = "nightscale"},
}

A.register_ingredient("group:wood", 1)

-- The six wood grades. Each grade's recipe (the grade below, or two planks,
-- and a plank) is Basic (grug_jobs/basic_recipes.lua).
for tier = 1, #tiers do
	local row = tiers[tier]
	local wood = A.register_item(C .. row.key .. "_wood", row.name .. " Wood",
		"default_wood.png^[colorize:#" ..
			({"9b744d", "bb966d", "7f6547", "78644f", "5f493e", "392d35"})[tier] ..
			":90", {grug_profession_material = 1, grug_wood_grade = tier})
	A.register_ingredient(wood, tier)
end
