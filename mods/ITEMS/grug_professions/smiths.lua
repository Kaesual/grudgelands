local P = grug_professions
local M = "grug_materials:"
local C = "grug_professions:"

local tiers = {
	{key = "bronze", name = "Bronze", bar = M .. "bronze_bar"},
	{key = "iron", name = "Iron", bar = M .. "iron_bar"},
	{key = "steel", name = "Steel", bar = M .. "steel_bar"},
	{key = "silversteel", name = "Silversteel", bar = M .. "silversteel_bar"},
	{key = "embersteel", name = "Embersteel", bar = M .. "embersteel_bar"},
	{key = "abyssal_steel", name = "Abyssal Steel", bar = M .. "abyssal_steel_bar"},
}

for tier = 1, #tiers do
	local row = tiers[tier]
	P.register_ingredient(row.bar, tier)
	local fitting = P.register_item(C .. "metal_fittings_" .. row.key,
		row.name .. " Metal Fittings",
		"default_steel_ingot.png^[colorize:#6f553d:" .. (35 + tier * 12),
		{grug_profession_material = 1, grug_weaponsmith_fitting = tier})
	P.register_ingredient(fitting, tier)
	P.register_recipe("weaponsmith", {tier = tier, station = "forge",
		inputs = {{row.bar, row.bar}}, output = fitting,
		hint = "Forge at a Forge"})

end
