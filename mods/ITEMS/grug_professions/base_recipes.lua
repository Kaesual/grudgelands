-- Universal Basics recipes. Shapes mirror the familiar three-column tool and
-- armor layouts; profession catalogs only improve the resulting plain items.

local G = "grug_gear:"
local M = "grug_materials:"
local C = "grug_professions:"

local tiers = {
	{metal = "bronze", bar = M .. "bronze_bar", pick = "default:pick_bronze",
		axe = "default:axe_bronze", shovel = "default:shovel_bronze",
		cloth = "patch", leather = "light", wood = "seasoned"},
	{metal = "iron", bar = M .. "iron_bar", pick = M .. "pick_iron",
		axe = M .. "axe_iron", shovel = M .. "shovel_iron",
		cloth = "woven", leather = "cured", wood = "polished"},
	{metal = "steel", bar = M .. "steel_bar", pick = "default:pick_steel",
		axe = "default:axe_steel", shovel = "default:shovel_steel",
		cloth = "heavy", leather = "heavy", wood = "hardened"},
	{metal = "silversteel", bar = M .. "silversteel_bar",
		pick = M .. "pick_silversteel", axe = M .. "axe_silversteel",
		shovel = M .. "shovel_silversteel", cloth = "silkweave",
		leather = "scaled", wood = "inlaid"},
	{metal = "embersteel", bar = M .. "embersteel_bar",
		pick = M .. "pick_embersteel", axe = M .. "axe_embersteel",
		shovel = M .. "shovel_embersteel", cloth = "silk", leather = "sleek",
		wood = "lacquered"},
	{metal = "abyssal_steel", bar = M .. "abyssal_steel_bar",
		pick = M .. "pick_abyssal_steel", axe = M .. "axe_abyssal_steel",
		shovel = M .. "shovel_abyssal_steel", cloth = "stormweave",
		leather = "nightscale", wood = "heartwood"},
}

local occult_components = {
	"grug_mobs:boar_tusk",
	"grug_mobs:zombie_flesh",
	"grug_mobs:bone",
	"grug_mobs:bear_claw",
	"grug_mobs:sharp_feather",
	"grug_mobs:venom_sac",
}

local armor_shapes = {
	head = {{1, 1, 1}, {1, 0, 1}},
	chest = {{1, 0, 1}, {1, 1, 1}, {1, 1, 1}},
	legs = {{1, 1, 1}, {1, 0, 1}, {1, 0, 1}},
	feet = {{1, 0, 1}, {1, 0, 1}},
}

local function filled(shape, item)
	local recipe = {}
	for row = 1, #shape do
		recipe[row] = {}
		for column = 1, #shape[row] do
			recipe[row][column] = shape[row][column] == 1 and item or ""
		end
	end
	return recipe
end

local function register(output, recipe)
	core.clear_craft({output = output})
	core.register_craft({output = output, recipe = recipe})
end

-- VoxeLibre's familiar handle path uses two vertical planks for four sticks.
-- Replace Minetest Game's one-plank shortcut so the grid shape stays canonical.
core.clear_craft({output = "default:stick"})
core.register_craft({output = "default:stick 4", recipe = {
	{"group:wood"}, {"group:wood"},
}})

for tier = 1, #tiers do
	local row = tiers[tier]
	local rod = C .. "metal_rod_" .. row.metal
	grug_professions.register_item(rod, grug_gear.MATERIALS[tier].metal.name ..
		" Rod", "default_steel_ingot.png^[transformR90^[resize:8x16^[colorize:" ..
		grug_gear.BRACKET_TINT[tier] .. ":90", {grug_metal_rod = tier})
	core.register_craft({output = rod .. " 4", recipe = {{row.bar}, {row.bar}}})

	local sword = G .. "sword_" .. row.metal
	register(sword, {{row.bar}, {row.bar}, {"group:stick"}})
	core.register_craft({output = sword, recipe = {{row.bar}, {row.bar}, {rod}}})
	register(row.pick, {{row.bar, row.bar, row.bar}, {"", "group:stick", ""},
		{"", "group:stick", ""}})
	register(row.shovel, {{row.bar}, {"group:stick"}, {"group:stick"}})
	register(row.axe, {{row.bar, row.bar}, {row.bar, "group:stick"},
		{"", "group:stick"}})
	core.register_craft({output = row.axe, recipe = {
		{row.bar, row.bar}, {"group:stick", row.bar},
		{"group:stick", ""}}})

	local dagger = G .. "dagger_" .. row.metal
	register(dagger, {{"", row.bar, ""}, {"", "group:stick", ""}})
	core.register_craft({output = dagger,
		recipe = {{"", row.bar, ""}, {"", rod, ""}}})
	local greataxe = G .. "greataxe_" .. row.metal
	register(greataxe, {
		{row.bar, row.bar, row.bar}, {row.bar, "group:stick", row.bar},
		{"", "group:stick", ""}})
	core.register_craft({output = greataxe, recipe = {
		{row.bar, row.bar, row.bar}, {row.bar, rod, row.bar}, {"", rod, ""}}})
	local wand = G .. "wand_" .. row.metal
	local occult = occult_components[tier]
	register(wand, {{"", occult, ""}, {"", row.bar, ""},
		{"", "group:stick", ""}})
	register(G .. "staff_" .. row.metal, {{occult, row.bar, occult},
		{"", "group:stick", ""}, {"", "group:stick", ""}})
	local bow = G .. "bow_" .. row.metal
	register(bow, {{"", "group:stick", C .. "thread"},
		{row.bar, "", C .. "thread"}, {"", "group:stick", C .. "thread"}})
	core.register_craft({output = bow, recipe = {
		{C .. "thread", "group:stick", ""}, {C .. "thread", "", row.bar},
		{C .. "thread", "group:stick", ""}}})
	register(G .. "shield_" .. row.metal, {
		{"group:wood", row.bar, "group:wood"},
		{"group:wood", "group:wood", "group:wood"},
		{"", "group:wood", ""},
	})

	local materials = {
		metal = row.bar,
		cloth = C .. "bolt_" .. row.cloth,
		leather = tier == 1 and "grug_mobs:light_leather" or
			(tier == 3 and "grug_mobs:heavy_leather" or
			(tier == 4 and "grug_mobs:scaled_hide" or
			C .. row.leather .. "_leather")),
	}
	for line, material in pairs(materials) do
		for slot, shape in pairs(armor_shapes) do
			register(G .. slot .. "_" .. line .. "_" ..
				(line == "metal" and row.metal or row[line]), filled(shape, material))
		end
	end
end

core.clear_craft({output = G .. "arrow"})
core.register_craft({type = "shapeless", output = G .. "arrow 20", recipe = {
	M .. "iron_bar", "group:stick", "group:stick", "group:stick", "group:stick",
	"grug_mobs:sharp_feather", "grug_mobs:sharp_feather",
	"grug_mobs:sharp_feather", "grug_mobs:sharp_feather",
}})

if core.registered_items["grug_farming:hoe"] then
	register("grug_farming:hoe", {
		{"group:wood", "group:wood", ""},
		{"", "default:stick", ""}, {"", "default:stick", ""},
	})
	core.register_craft({output = "grug_farming:hoe", recipe = {
		{"", "group:wood", "group:wood"},
		{"", "default:stick", ""}, {"", "default:stick", ""},
	}})
end
