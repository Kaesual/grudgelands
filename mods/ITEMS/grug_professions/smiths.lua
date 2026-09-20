local P = grug_professions
local M = "grug_materials:"
local G = "grug_gear:"
local C = "grug_professions:"

local tiers = {
	{key = "bronze", name = "Bronze", bar = M .. "bronze_bar"},
	{key = "iron", name = "Iron", bar = M .. "iron_bar"},
	{key = "steel", name = "Steel", bar = M .. "steel_bar"},
	{key = "silversteel", name = "Silversteel", bar = M .. "silversteel_bar"},
	{key = "embersteel", name = "Embersteel", bar = M .. "embersteel_bar"},
	{key = "abyssal_steel", name = "Abyssal Steel", bar = M .. "abyssal_steel_bar"},
}

local reagents = {
	[1] = "default:coal_lump",
	[2] = "grug_mobs:venom_gland",
	[3] = "grug_mobs:slime_gel",
	[4] = "grug_mobs:croc_tooth",
	[5] = "grug_gathering:stormkelp",
	[6] = "grug_mobs:stone_core",
}

local picks = {
	"default:pick_bronze",
	"grug_materials:pick_iron",
	"default:pick_steel",
	"grug_materials:pick_silversteel",
	"grug_materials:pick_embersteel",
	"grug_materials:pick_abyssal_steel",
}

local axes = {
	"default:axe_bronze", "grug_materials:axe_iron", "default:axe_steel",
	"grug_materials:axe_silversteel", "grug_materials:axe_embersteel",
	"grug_materials:axe_abyssal_steel",
}

local shovels = {
	"default:shovel_bronze", "grug_materials:shovel_iron", "default:shovel_steel",
	"grug_materials:shovel_silversteel", "grug_materials:shovel_embersteel",
	"grug_materials:shovel_abyssal_steel",
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

	for _, family in ipairs({"sword", "dagger", "greataxe"}) do
		local item = G .. family .. "_" .. row.key
		P.register_refinement("weaponsmith", tier, "weapon", item, fitting)
		P.register_add_affix("weaponsmith", tier, "weapon", item, fitting,
			reagents[tier])
	end
	for _, item in ipairs({picks[tier], shovels[tier]}) do
		P.register_refinement("weaponsmith", tier, "tool", item, fitting)
	end
	P.register_refinement("weaponsmith", tier, "weapon", axes[tier], fitting)
	if tier == 1 and core.registered_items["grug_farming:hoe"] then
		P.register_refinement("weaponsmith", tier, "tool", "grug_farming:hoe",
			fitting)
	end
	for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
		local item = G .. slot .. "_metal_" .. row.key
		P.register_refinement("armorsmith", tier, "metal_armor", item, row.bar)
		P.register_add_affix("armorsmith", tier, "metal_armor", item, row.bar,
			reagents[tier])
	end

	if tier >= 2 then
		P.register_ingredient(reagents[tier], tier)
		local imbue = P.register_item(C .. "whetstone_imbue_" .. row.key,
			row.name .. " Whetstone Imbue Kit",
			"default_stone.png^[colorize:#91806b:115",
			{grug_upgrade_kit = 1, grug_whetstone_imbue = tier})
		P.register_recipe("weaponsmith", {tier = tier, station = "forge",
			inputs = {{fitting, reagents[tier], C .. "whetstone_blank"}},
			output = imbue,
			hint = "Forge at a Forge"})
	end
	if tier >= 3 then
		local temper = P.register_item(C .. "whetstone_temper_" .. row.key,
			row.name .. " Whetstone Temper Kit",
			"default_stone.png^[colorize:#6b7684:125",
			{grug_upgrade_kit = 1, grug_whetstone_temper = tier})
		local polish = P.register_item(C .. "armor_polish_imbue_" .. row.key,
			row.name .. " Armor-Polish Imbue Kit",
			"default_clay_lump.png^[colorize:#9b8570:105",
			{grug_upgrade_kit = 1, grug_armor_polish_imbue = tier})
		P.register_recipe("weaponsmith", {tier = tier, station = "forge",
			inputs = {{fitting, reagents[tier], C .. "whetstone_blank"},
				{C .. "whetstone_blank", "", ""}},
			output = temper,
			hint = "Forge at a Forge"})
		P.register_recipe("armorsmith", {tier = tier, station = "forge",
			inputs = {{fitting, reagents[tier], "default:clay_lump"}}, output = polish,
			hint = "Forge at a Forge"})
	end
	if tier >= 5 then
		local polish = P.register_item(C .. "armor_polish_temper_" .. row.key,
			row.name .. " Armor-Polish Temper Kit",
			"default_clay_lump.png^[colorize:#5f6875:125",
			{grug_upgrade_kit = 1, grug_armor_polish_temper = tier})
		P.register_recipe("armorsmith", {tier = tier, station = "forge",
			inputs = {{fitting, reagents[tier], C .. "flux"}}, output = polish,
			hint = "Forge at a Forge"})
	end
end
