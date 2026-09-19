local P = grug_professions
local C = "grug_professions:"
local THREAD = C .. "thread"

local tiers = {
	{key = "light", name = "Light", output = "grug_mobs:light_leather",
		inputs = {"mobs:leather", THREAD}, recipe_tier = 1},
	{key = "cured", name = "Cured", output = C .. "cured_leather",
		inputs = {"grug_mobs:light_leather", THREAD}, recipe_tier = 1},
	{key = "heavy", name = "Heavy", output = "grug_mobs:heavy_leather",
		inputs = {C .. "cured_leather", THREAD}, recipe_tier = 2},
	{key = "scaled", name = "Scaled", output = "grug_mobs:scaled_hide",
		inputs = {"grug_mobs:heavy_leather", THREAD}, recipe_tier = 3},
	{key = "sleek", name = "Sleek", output = C .. "sleek_leather",
		inputs = {"grug_mobs:sleek_pelt", THREAD}, recipe_tier = 5},
	{key = "nightscale", name = "Nightscale", output = C .. "nightscale_leather",
		inputs = {"grug_mobs:scaled_hide", "grug_mobs:sleek_pelt"},
		recipe_tier = 5},
}

for tier = 1, #tiers do
	local row = tiers[tier]
	if not core.registered_items[row.output] then
		P.register_item(row.output, row.name .. " Leather",
			"mobs_leather.png^[colorize:#" ..
			({"b88b60", "9b7453", "785339", "6b704f", "51443d", "302c42"})[tier] ..
			":75", {grug_profession_material = 1, grug_leather_grade = tier})
	end
	P.register_ingredient(row.output, tier)
	if tier == 1 then
		P.register_ingredient("mobs:leather", tier)
	elseif tier == 5 then
		P.register_ingredient("grug_mobs:sleek_pelt", tier)
	end
	P.register_recipe("leatherworker", {tier = row.recipe_tier,
		station = "tanning_rack",
		inputs = {row.inputs}, output = row.output,
		hint = "Tan at a Tanning Rack"})

	local grip = P.register_item(C .. "weapon_grip_" .. row.key,
		row.name .. " Leather Weapon Grip",
		"mobs_leather.png^[colorize:#3d291d:105",
		{grug_profession_material = 1, grug_weapon_grip = tier})
	P.register_ingredient(grip, tier)
	P.register_recipe("leatherworker", {tier = tier, station = "tanning_rack",
		inputs = {{row.output, row.output}}, output = grip,
		hint = "Tan at a Tanning Rack"})

	if tier >= 2 then
		local imbue = P.register_item(C .. "leather_armor_imbue_" .. row.key,
			row.name .. " Leather-Armor Imbue Kit",
			"mobs_leather.png^[colorize:#8c6c45:115",
			{grug_upgrade_kit = 1, grug_leather_imbue = tier})
		P.register_recipe("leatherworker", {tier = tier, station = "tanning_rack",
			inputs = {{row.output, grip}}, output = imbue,
			hint = "Tan at a Tanning Rack"})
	end
	if tier >= 3 then
		local temper = P.register_item(C .. "leather_armor_temper_" .. row.key,
			row.name .. " Leather-Armor Temper Kit",
			"mobs_leather.png^[colorize:#555f6d:125",
			{grug_upgrade_kit = 1, grug_leather_temper = tier})
		P.register_recipe("leatherworker", {tier = tier, station = "tanning_rack",
			inputs = {{row.output, grip, "default:coal_lump"}}, output = temper,
			hint = "Tan at a Tanning Rack"})
	end
end
