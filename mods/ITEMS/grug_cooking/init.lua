-- R8 Cooking v1 content. This mod registers inventory items and recipes only;
-- R8-MAP-B owns every world-placement decision.

grug_cooking = {}

local PLANTS = {
	{name = "wild_grain", description = "Wild Grain", tier = 1,
		kind = "raw_food", image = "default_dry_grass_3.png^[colorize:#d7b85a:90"},
	{name = "carrot", description = "Carrot", tier = 1,
		kind = "raw_food", image = "default_clay_lump.png^[colorize:#e78532:150"},
	{name = "cassava", description = "Cassava", tier = 1,
		kind = "raw_food", image = "default_clay_lump.png^[colorize:#d8c18b:105"},
	{name = "wild_onion", description = "Wild Onion", tier = 1,
		kind = "spice", image = "default_apple.png^[colorize:#d8dfc0:165"},
	{name = "fire_pepper", description = "Fire Pepper", tier = 1,
		kind = "spice", image = "default_marram_grass_1.png^[colorize:#d83e25:155"},
	{name = "pumpkin", description = "Pumpkin", tier = 2,
		kind = "raw_food", image = "default_apple.png^[colorize:#e18a28:155"},
	{name = "blightberry", description = "Blightberry", tier = 2,
		kind = "raw_food", image = "default_blueberries.png^[colorize:#86569b:120"},
	{name = "sunberry", description = "Sunberry", tier = 2,
		kind = "raw_food", image = "default_blueberries.png^[colorize:#e0a62e:145"},
	{name = "jungle_berry", description = "Jungle Berry", tier = 2,
		kind = "raw_food", image = "default_blueberries.png^[colorize:#c84455:125"},
	{name = "frost_melon", description = "Frost Melon", tier = 3,
		kind = "raw_food", image = "default_apple.png^[colorize:#8fcfe0:145"},
	{name = "sugar_cane", description = "Sugar Cane", tier = 1,
		kind = "sweetener", image = "default_papyrus.png^[colorize:#d8e88a:90"},
	{name = "bamboo_shoot", description = "Bamboo Shoot", tier = 1,
		kind = "raw_food", image = "default_papyrus.png^[colorize:#7ea83d:135"},
	{name = "cave_cap", description = "Cave Cap", tier = 3,
		kind = "raw_food", image = "default_pine_bush_sapling.png^[colorize:#9f72b3:155"},
	{name = "salt_crust", description = "Salt Crust", tier = 5,
		kind = "salt", image = "default_clay_lump.png^[colorize:#f4efe2:155"},
	{name = "ember_moss", description = "Ember Moss", tier = 5,
		kind = "reagent", image = "default_fern_1.png^[colorize:#d9572c:150"},
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

local TIER_COLORS = {"#a97945", "#bb8055", "#8f6b52", "#72928a", "#667f91",
	"#80649b"}
local ROLE_IMAGES = {
	hearty = "default_clay_lump.png^[colorize:",
	caster = "default_apple.png^[colorize:",
	hunter = "grug_mobs_item_raw_fish.png^[colorize:",
}

local function dish(id, description, tier, role, inputs)
	return {id = id, item = "grug_cooking:" .. id, description = description,
		tier = tier, role = role, inputs = inputs, station = "grid",
		hint = "Crafting grid",
		image = ROLE_IMAGES[role] .. TIER_COLORS[tier] .. ":125"}
end

local G = "grug_gathering:"
local C = "grug_cooking:"
local MEAT = "mobs:meat_raw"
local FISH = "grug_mobs:raw_fish"

local DISHES = {
	dish("hearty_stew", "Hearty Stew", 1, "hearty",
		{MEAT, G .. "potato"}),
	dish("sweetroot_mash", "Sweetroot Mash", 1, "caster",
		{C .. "carrot", G .. "corn"}),
	dish("corn_crusted_fish", "Corn-Crusted Fish", 1, "hunter",
		{FISH, G .. "corn"}),
	dish("pumpkin_stew", "Pumpkin Stew", 2, "hearty",
		{C .. "pumpkin", MEAT, G .. "potato"}),
	dish("berry_preserve", "Berry Preserve", 2, "caster",
		{C .. "blightberry", C .. "blightberry", C .. "sugar_cane"}),
	dish("fruit_glazed_roast", "Fruit-Glazed Roast", 2, "hunter",
		{MEAT, C .. "sunberry"}),
	dish("foragers_pot", "Forager's Pot", 3, "hearty",
		{G .. "mushroom", MEAT, G .. "potato"}),
	dish("mushroom_skewer", "Mushroom Skewer", 3, "caster",
		{G .. "mushroom", G .. "mushroom"}),
	dish("onion_seared_steak", "Onion-Seared Steak", 3, "hunter",
		{MEAT, C .. "wild_onion", G .. "mushroom"}),
	dish("marsh_roast", "Marsh Roast", 4, "hearty",
		{MEAT, G .. "marshbloom", G .. "potato"}),
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
		{MEAT, G .. "wild_cocoa", C .. "fire_pepper"}),
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
	["default:apple"] = 2, ["default:blueberries"] = 2,
	[C .. "pumpkin"] = 2, [C .. "blightberry"] = 2,
	[C .. "sunberry"] = 2, [C .. "jungle_berry"] = 2,
	[C .. "sugar_cane"] = 2,
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
		inputs = {MEAT, G .. "potato", C .. "wild_grain"}},
	{tier = 2, id = "raw_pumpkin_pot", output = DISHES[4].item,
		inputs = {C .. "pumpkin", MEAT, G .. "corn"}},
	{tier = 3, id = "raw_foragers_pot", output = DISHES[7].item,
		inputs = {C .. "cave_cap", MEAT, G .. "potato"}},
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
		inventory_image = "default_clay_lump.png^[colorize:" ..
			TIER_COLORS[row.tier] .. ":175",
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
	inventory_image = "default_clay_lump.png^[colorize:#d8a552:145",
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
