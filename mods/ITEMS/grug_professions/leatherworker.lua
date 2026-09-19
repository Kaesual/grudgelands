local P = grug_professions
local C = "grug_professions:"
local THREAD = C .. "thread"

local tiers = {
	{key = "light", name = "Light", output = "grug_mobs:light_leather",
		inputs = {"mobs:leather", THREAD}},
	{key = "cured", name = "Cured", output = C .. "cured_leather"},
	{key = "heavy", name = "Heavy", output = "grug_mobs:heavy_leather",
	},
	{key = "scaled", name = "Scaled", output = "grug_mobs:scaled_hide",
	},
	{key = "sleek", name = "Sleek", output = C .. "sleek_leather",
		inputs = {"grug_mobs:sleek_pelt", THREAD}},
	{key = "nightscale", name = "Nightscale", output = C .. "nightscale_leather"},
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
	elseif tier == 2 then
		row.inputs = {P.register_ingredient_role("grug_mobs:light_leather",
			"grug_leather_curing_hide", tier), THREAD}
	elseif tier == 3 then
		row.inputs = {P.register_ingredient_role(C .. "cured_leather",
			"grug_leather_heavy_hide", tier), THREAD}
	elseif tier == 4 then
		row.inputs = {P.register_ingredient_role("grug_mobs:heavy_leather",
			"grug_leather_scaled_hide", tier), THREAD}
	elseif tier == 5 then
		P.register_ingredient("grug_mobs:sleek_pelt", tier)
	else
		row.inputs = {P.register_ingredient_role("grug_mobs:scaled_hide",
			"grug_leather_nightscale_hide", tier), C .. "sleek_leather"}
	end
	P.register_recipe("leatherworker", {tier = tier, station = "tanning_rack",
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
