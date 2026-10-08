-- Gear recipes (Round 45, spec §2.23 and §2.34): every weapon, armour piece
-- and offhand is a recipe of the profession that owns its family
-- (grug_professions.FAMILY_OWNERS), with the ingredients the universal
-- crafting grid used (counted from its shapes), the profession tier equal to
-- the item's tier, the profession's station nearby and 3 s per item. Tools,
-- metal rods, arrows, sticks and the hoe stay Basic recipes
-- (grug_jobs/basic_recipes.lua).

local G = "grug_gear:"
local M = "grug_materials:"
local C = "grug_professions:"

local tiers = {
	{metal = "bronze", bar = M .. "bronze_bar", cloth = "patch", leather = "light"},
	{metal = "iron", bar = M .. "iron_bar", cloth = "woven", leather = "cured"},
	{metal = "steel", bar = M .. "steel_bar", cloth = "heavy", leather = "heavy"},
	{metal = "silversteel", bar = M .. "silversteel_bar", cloth = "silkweave",
		leather = "scaled"},
	{metal = "embersteel", bar = M .. "embersteel_bar", cloth = "silk",
		leather = "sleek"},
	{metal = "abyssal_steel", bar = M .. "abyssal_steel_bar", cloth = "stormweave",
		leather = "nightscale"},
}

local occult_components = {
	"grug_mobs:boar_tusk",
	"grug_mobs:zombie_flesh",
	"grug_mobs:bone",
	"grug_mobs:bear_claw",
	"grug_mobs:sharp_feather",
	"grug_mobs:venom_sac",
}

-- The material count of each armour slot (the grid shapes: a helmet of 5, a
-- chestpiece of 8, leggings of 7, boots of 4).
local ARMOR_COUNTS = {head = 5, chest = 8, legs = 7, feet = 4}

-- One gear recipe: the owning profession from the output's family, the tier
-- from its bracket.
local function gear(output, tier, ingredients)
	local family = grug_items.family_for(ItemStack(output))
	local profession = family and grug_professions.family_owner(family)
	if not profession then
		error("grug_professions: no profession makes " .. output, 0)
	end
	grug_professions.register_recipe(profession, {output = output, tier = tier,
		ingredients = ingredients, time = grug_jobs.DURATIONS.gear})
end

local function item(name, n) return {item = name, n = n} end
local function group(name, n) return {group = name, n = n} end

for tier = 1, #tiers do
	local row = tiers[tier]
	local bar = row.bar
	local rod = C .. "metal_rod_" .. row.metal
	grug_professions.register_item(rod, grug_gear.MATERIALS[tier].metal.name ..
		" Rod", "default_steel_ingot.png^[transformR90^[resize:8x16^[colorize:" ..
		grug_gear.BRACKET_TINT[tier] .. ":90", {grug_metal_rod = tier})

	-- A handle is two sticks, or one metal rod per stick.
	local sword, dagger, greataxe = G .. "sword_" .. row.metal,
		G .. "dagger_" .. row.metal, G .. "greataxe_" .. row.metal
	gear(sword, tier, {item(bar, 2), group("stick", 1)})
	gear(sword, tier, {item(bar, 2), item(rod, 1)})
	gear(dagger, tier, {item(bar, 1), group("stick", 1)})
	gear(dagger, tier, {item(bar, 1), item(rod, 1)})
	gear(greataxe, tier, {item(bar, 5), group("stick", 2)})
	gear(greataxe, tier, {item(bar, 5), item(rod, 2)})
	local occult = occult_components[tier]
	gear(G .. "wand_" .. row.metal, tier,
		{item(occult, 1), item(bar, 1), group("stick", 1)})
	gear(G .. "staff_" .. row.metal, tier,
		{item(occult, 2), item(bar, 1), group("stick", 2)})
	gear(G .. "bow_" .. row.metal, tier,
		{group("stick", 2), item(C .. "thread", 3), item(bar, 1)})
	gear(G .. "shield_" .. row.metal, tier, {group("wood", 6), item(bar, 1)})

	local materials = {
		metal = {bar, row.metal},
		cloth = {C .. "bolt_" .. row.cloth, row.cloth},
		leather = {tier == 1 and "grug_mobs:light_leather" or
			(tier == 3 and "grug_mobs:heavy_leather" or
			(tier == 4 and "grug_mobs:scaled_hide" or
			C .. row.leather .. "_leather")), row.leather},
	}
	for _, line in ipairs({"metal", "cloth", "leather"}) do
		local material, key = materials[line][1], materials[line][2]
		for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
			gear(G .. slot .. "_" .. line .. "_" .. key, tier,
				{item(material, ARMOR_COUNTS[slot])})
		end
	end
end
