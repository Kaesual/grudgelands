-- R8 Cooking v1 content. This mod registers inventory items and recipes only;
-- R8-MAP-B owns every world-placement decision.

grug_cooking = {}

local PLANTS = {
	{name = "wild_grain", description = "Wild Grain", tier = 1,
		kind = "raw_food", image = "grug_cooking_wild_grain.png"},
	{name = "carrot", description = "Carrot", tier = 1,
		kind = "raw_food", image = "grug_cooking_carrot.png"},
	{name = "cassava", description = "Cassava", tier = 1,
		kind = "raw_food", image = "grug_cooking_cassava.png"},
	{name = "wild_onion", description = "Wild Onion", tier = 1,
		kind = "spice", image = "grug_cooking_wild_onion.png"},
	{name = "fire_pepper", description = "Fire Pepper", tier = 1,
		kind = "spice", image = "grug_cooking_fire_pepper.png"},
	{name = "pumpkin", description = "Pumpkin", tier = 2,
		kind = "raw_food", image = "grug_cooking_pumpkin.png"},
	{name = "blightberry", description = "Blightberry", tier = 2,
		kind = "raw_food", image = "grug_cooking_blightberry.png"},
	{name = "sunberry", description = "Sunberry", tier = 2,
		kind = "raw_food", image = "grug_cooking_sunberry.png"},
	{name = "jungle_berry", description = "Jungle Berry", tier = 2,
		kind = "raw_food", image = "grug_cooking_jungle_berry.png"},
	{name = "frost_melon", description = "Frost Melon", tier = 3,
		kind = "raw_food", image = "grug_cooking_frost_melon.png"},
	{name = "sugar_cane", description = "Sugar Cane", tier = 1,
		kind = "sweetener", image = "grug_cooking_sugar_cane.png"},
	{name = "bamboo_shoot", description = "Bamboo Shoot", tier = 1,
		kind = "raw_food", image = "grug_cooking_bamboo_shoot.png"},
	{name = "cave_cap", description = "Cave Cap", tier = 3,
		kind = "raw_food", image = "grug_cooking_cave_cap.png"},
	{name = "salt_crust", description = "Salt Crust", tier = 5,
		kind = "salt", image = "grug_cooking_salt_crust.png"},
	{name = "ember_moss", description = "Ember Moss", tier = 5,
		kind = "reagent", image = "grug_cooking_ember_moss.png"},
}

local kind_groups = {
	raw_food = {grug_plant_item = 1},
	spice = {grug_plant_item = 1, grug_spice = 1},
	sweetener = {grug_plant_item = 1, grug_sweetener = 1},
	salt = {grug_plant_item = 1, grug_salt = 1},
	reagent = {grug_plant_item = 1, grug_alchemy_reagent = 1},
}

for index = 1, #PLANTS do
	local row = PLANTS[index]
	row.item = "grug_cooking:" .. row.name
	core.register_craftitem(row.item, {
		description = row.description,
		inventory_image = row.image,
		groups = kind_groups[row.kind],
		_grug_tier = row.tier,
	})
	if row.kind == "raw_food" then
		assert(grug_food.register_item(row.item, row.tier, "raw", "hp"),
			"grug_cooking: failed to register raw food " .. row.item)
	end
end

grug_cooking.PLANTS = PLANTS

local function add_item_group(item, group)
	local definition = assert(core.registered_items[item],
		"grug_cooking: missing grouped ingredient " .. item)
	local groups = {}
	for name, value in pairs(definition.groups or {}) do groups[name] = value end
	groups[group] = 1
	core.override_item(item, {groups = groups})
end

local INGREDIENT_GROUPS = {
	grug_cooking_staple = {"grug_gathering:potato", "grug_gathering:corn"},
	grug_cooking_root = {"grug_cooking:carrot", "grug_cooking:cassava"},
	grug_cooking_berry = {"default:blueberries", "grug_cooking:blightberry",
		"grug_cooking:sunberry", "grug_cooking:jungle_berry"},
	grug_cooking_fruit = {"default:apple", "default:blueberries",
		"grug_cooking:blightberry", "grug_cooking:sunberry",
		"grug_cooking:jungle_berry"},
	grug_cooking_early_spice = {"grug_cooking:wild_onion",
		"grug_cooking:fire_pepper"},
}

for group, members in pairs(INGREDIENT_GROUPS) do
	for index = 1, #members do add_item_group(members[index], group) end
end

local function dish(id, description, tier, role, inputs)
	return {id = id, item = "grug_cooking:" .. id, description = description,
		tier = tier, role = role, inputs = inputs, station = "grid",
		hint = "Crafting grid",
		image = "grug_cooking_dish_" .. id .. ".png"}
end

local G = "grug_gathering:"
local C = "grug_cooking:"
local MEAT = "mobs:meat_raw"
local FISH = "grug_mobs:raw_fish"
local STAPLE = "group:grug_cooking_staple"
local ROOT = "group:grug_cooking_root"
local BERRY = "group:grug_cooking_berry"
local FRUIT = "group:grug_cooking_fruit"
local EARLY_SPICE = "group:grug_cooking_early_spice"

local DISHES = {
	dish("hearty_stew", "Hearty Stew", 1, "hearty",
		{MEAT, STAPLE}),
	dish("sweetroot_mash", "Sweetroot Mash", 1, "caster",
		{ROOT, STAPLE}),
	dish("corn_crusted_fish", "Corn-Crusted Fish", 1, "hunter",
		{FISH, G .. "corn"}),
	dish("pumpkin_stew", "Pumpkin Stew", 2, "hearty",
		{C .. "pumpkin", MEAT, STAPLE}),
	dish("berry_preserve", "Berry Preserve", 2, "caster",
		{BERRY, BERRY, C .. "sugar_cane"}),
	dish("fruit_glazed_roast", "Fruit-Glazed Roast", 2, "hunter",
		{MEAT, FRUIT}),
	dish("foragers_pot", "Forager's Pot", 3, "hearty",
		{G .. "mushroom", MEAT, STAPLE}),
	dish("mushroom_skewer", "Mushroom Skewer", 3, "caster",
		{G .. "mushroom", G .. "mushroom"}),
	dish("onion_seared_steak", "Onion-Seared Steak", 3, "hunter",
		{MEAT, EARLY_SPICE, G .. "mushroom"}),
	dish("marsh_roast", "Marsh Roast", 4, "hearty",
		{MEAT, G .. "marshbloom", STAPLE}),
	dish("marshbloom_chowder", "Marshbloom Chowder", 4, "caster",
		{FISH, G .. "marshbloom"}),
	dish("hunters_feast", "Hunter's Feast", 4, "hunter",
		{MEAT, MEAT, G .. "melon", G .. "mushroom"}),
	dish("kelp_wrapped_roast", "Kelp-Wrapped Roast", 5, "hearty",
		{MEAT, G .. "stormkelp", G .. "rock_salt"}),
	dish("stormkelp_broth", "Stormkelp Broth", 5, "caster",
		{G .. "stormkelp", FISH, G .. "melon"}),
	dish("salt_crusted_fish", "Salt-Crusted Fish", 5, "hunter",
		{FISH, G .. "rock_salt"}),
	dish("grand_feast", "Grand Feast", 6, "hearty",
		{MEAT, MEAT, G .. "wild_cocoa", G .. "stormkelp"}),
	dish("jungle_cocoa", "Jungle Cocoa", 6, "caster",
		{G .. "wild_cocoa", G .. "wild_cocoa", G .. "rock_salt"}),
	dish("cocoa_rubbed_game", "Cocoa-Rubbed Game", 6, "hunter",
		{MEAT, G .. "wild_cocoa", EARLY_SPICE}),
}

local function grid(inputs)
	local result = {}
	for index = 1, #inputs do
		local row = math.floor((index - 1) / 3) + 1
		local column = (index - 1) % 3 + 1
		result[row] = result[row] or {}
		result[row][column] = inputs[index]
	end
	for row = 1, #result do
		for column = 1, 3 do
			if result[row][column] == nil then result[row][column] = "" end
		end
	end
	return result
end

for index = 1, #DISHES do
	local row = DISHES[index]
	core.register_craftitem(row.item, {
		description = row.description,
		inventory_image = row.image,
		_grug_tier = row.tier,
	})
	assert(grug_food.register_item(row.item, row.tier, "dish", row.role),
		"grug_cooking: failed to register dish " .. row.item)
end

grug_cooking.DISHES = DISHES

local INGREDIENT_TIERS = {
	[MEAT] = 1, [FISH] = 1,
	[G .. "potato"] = 1, [G .. "corn"] = 1,
	[C .. "wild_grain"] = 1, [C .. "carrot"] = 1,
	[C .. "cassava"] = 1, [C .. "wild_onion"] = 1,
	[C .. "fire_pepper"] = 1, [C .. "bamboo_shoot"] = 1,
	[STAPLE] = 1, [ROOT] = 1, [EARLY_SPICE] = 1,
	["default:apple"] = 2, ["default:blueberries"] = 2,
	[C .. "pumpkin"] = 2, [C .. "blightberry"] = 2,
	[C .. "sunberry"] = 2, [C .. "jungle_berry"] = 2,
	[C .. "sugar_cane"] = 2,
	[BERRY] = 2, [FRUIT] = 2,
	[G .. "mushroom"] = 3, [C .. "cave_cap"] = 3,
	[G .. "melon"] = 4, [G .. "marshbloom"] = 4,
	[C .. "frost_melon"] = 4,
	[G .. "rock_salt"] = 5, [G .. "stormkelp"] = 5,
	[C .. "salt_crust"] = 5, [C .. "ember_moss"] = 5,
	[G .. "wild_cocoa"] = 6,
}

for item, tier in pairs(INGREDIENT_TIERS) do
	grug_jobs.register_ingredient_tier(item, tier)
end

for index = 1, #DISHES do
	local row = DISHES[index]
	grug_jobs.register_recipe({profession = "cooking", tier = row.tier,
		station = row.station, inputs = grid(row.inputs), output = row.item,
		hint = row.hint})
end

local RAW_ASSEMBLIES = {
	{tier = 1, id = "raw_stew_pot", output = DISHES[1].item,
		inputs = {MEAT, STAPLE, C .. "wild_grain"}},
	{tier = 2, id = "raw_pumpkin_pot", output = DISHES[4].item,
		inputs = {C .. "pumpkin", MEAT, C .. "wild_grain"}},
	{tier = 3, id = "raw_foragers_pot", output = DISHES[7].item,
		inputs = {C .. "cave_cap", MEAT, STAPLE}},
	{tier = 4, id = "raw_marsh_roast", output = DISHES[10].item,
		inputs = {MEAT, G .. "marshbloom", C .. "frost_melon"}},
	{tier = 5, id = "raw_kelp_roast", output = DISHES[13].item,
		inputs = {MEAT, G .. "stormkelp", C .. "salt_crust"}},
	{tier = 6, id = "raw_grand_feast", output = DISHES[16].item,
		inputs = {MEAT, MEAT, G .. "wild_cocoa", C .. "salt_crust"}},
}

for index = 1, #RAW_ASSEMBLIES do
	local row = RAW_ASSEMBLIES[index]
	row.item = C .. row.id
	row.station = "grid"
	row.hint = "Crafting grid — inedible until furnace-cooked"
	core.register_craftitem(row.item, {
		description = "Raw " .. core.registered_items[row.output].description:match("^[^\n]+") ..
			"\nInedible. Cook this assembled dish in a furnace.",
		inventory_image = "grug_cooking_" .. row.id .. ".png",
		groups = {grug_raw_dish = 1},
		_grug_tier = row.tier,
	})
	grug_jobs.register_ingredient_tier(row.item, row.tier)
	grug_jobs.register_recipe({profession = "cooking", tier = row.tier,
		station = "grid", inputs = grid(row.inputs), output = row.item,
		hint = row.hint})
	grug_jobs.register_recipe({profession = "cooking", tier = row.tier,
		station = "furnace", inputs = {row.item}, output = row.output,
		hint = "Furnace — cook assembled dish", time = 5})
end

grug_cooking.RAW_ASSEMBLIES = RAW_ASSEMBLIES
grug_cooking.INGREDIENT_TIERS = INGREDIENT_TIERS

core.register_craftitem("grug_cooking:bread", {
	description = "Bread",
	inventory_image = "grug_cooking_bread.png",
	_grug_tier = 1,
})
assert(grug_food.register_item("grug_cooking:bread", 1, "dish", "hearty"),
	"grug_cooking: failed to register bread")
core.register_craft({type = "cooking", output = "grug_cooking:bread",
	recipe = C .. "wild_grain", cooktime = 5})

grug_cooking.REFINEMENTS = {
	{tier = 1, input = MEAT, output = "mobs:meat", station = "furnace",
		hint = "Furnace"},
	{tier = 1, input = FISH, output = "grug_fishing:cooked_fish",
		station = "furnace", hint = "Furnace"},
	{tier = 1, input = C .. "wild_grain", output = "grug_cooking:bread",
		station = "furnace", hint = "Furnace"},
}

-- Simple meat, fish and bread conversions are universal Basics recipes.
-- Raw profession dishes award progress only during their grid preparation.
