local VIAL = "vessels:glass_bottle"
local G = "grug_gathering:"
local C = "grug_cooking:"
local M = "grug_mobs:"
local ROOT = "group:grug_cooking_root"

local ingredients = {
	[G .. "gravemoss"] = 1,
	[G .. "sunleaf"] = 1,
	[M .. "venom_gland"] = 2,
	[M .. "fang"] = 2,
	[G .. "dragonweed"] = 2,
	[G .. "crimson_lotus"] = 3,
	[G .. "wild_cocoa"] = 6,
	[M .. "slime_gel"] = 3,
	[M .. "bear_claw"] = 3,
	["grug_materials:steel_bar"] = 3,
	[M .. "croc_tooth"] = 4,
	[M .. "venom_sac"] = 4,
	[M .. "shiny_scale"] = 4,
	[G .. "stormkelp"] = 5,
	[M .. "stone_core"] = 6,
	[M .. "sharp_feather"] = 6,
}

for item, tier in pairs(ingredients) do
	grug_jobs.register_ingredient_tier(item, tier)
end

local function potion(id, name, tier, first, second, kind, cooldown, color)
	local cooldown_text = cooldown == grug_alchemy.GREATER_COOLDOWN and "45" or "60"
	grug_alchemy.register_consumable(id, {
		family = "potion", tier = tier, color = color,
		description = name .. "\nRestores 30% instantly. Shared " ..
			cooldown_text .. " second potion cooldown.",
		on_use = grug_alchemy.potion_use(kind, cooldown),
	})
	return {id = id, name = name, tier = tier, inputs = {first, second, VIAL},
		effect = "30% " .. (kind == "health" and "HP" or "Mana"),
		family = "potion"}
end

local function utility(id, name, tier, first, second, kind, duration, effect,
		color)
	grug_alchemy.register_consumable(id, {
		family = "potion", tier = tier, color = color,
		description = name .. "\n" .. effect .. ". Shared 60 second potion cooldown.",
		on_use = grug_alchemy.utility_use(kind, duration),
	})
	return {id = id, name = name, tier = tier, inputs = {first, second, VIAL},
		effect = effect, family = "potion"}
end

local function elixir(id, name, tier, first, second, modifier, value, duration,
		effect, color, kind)
	grug_alchemy.register_consumable(id, {
		family = "elixir", tier = tier, color = color,
		description = name .. "\n" .. effect .. ". Replaces your current elixir.",
		on_use = grug_alchemy.elixir_use({label = name, modifier = modifier,
			value = value, duration = duration, kind = kind}),
	})
	return {id = id, name = name, tier = tier, inputs = {first, second, VIAL},
		effect = effect, family = "elixir", modifier = modifier, value = value,
		duration = duration}
end

local catalog = {
	potion("potion_healing", "Healing Potion", 1, G .. "gravemoss",
		G .. "sunleaf", "health", grug_alchemy.POTION_COOLDOWN, "#d13b45"),
	potion("potion_mana", "Mana Potion", 1, G .. "gravemoss",
		ROOT, "mana", grug_alchemy.POTION_COOLDOWN, "#356ed1"),
	utility("potion_antivenom", "Antivenom", 2, G .. "dragonweed",
		M .. "venom_gland", "antivenom", 0, "Cures poison", "#63ba52"),
	utility("potion_swiftness", "Swiftness Draught", 2, G .. "dragonweed",
		M .. "fang", "swiftness", 5, "+10% movement speed for 5 seconds",
		"#e9c83b"),
	potion("potion_greater_healing", "Greater Healing Potion", 3,
		G .. "crimson_lotus", G .. "gravemoss", "health",
		grug_alchemy.GREATER_COOLDOWN, "#a81729"),
	potion("potion_greater_mana", "Greater Mana Potion", 3,
		G .. "crimson_lotus", C .. "sugar_cane", "mana",
		grug_alchemy.GREATER_COOLDOWN, "#253ea3"),
	utility("potion_cave", "Cave Draught", 3, C .. "cave_cap",
		M .. "slime_gel", "cave", 600, "Night vision for 10 minutes", "#804db5"),

	elixir("elixir_vigor_t3", "Elixir of Vigor III", 3,
		G .. "crimson_lotus", M .. "bear_claw", "hp_pool_percent", 5,
		900, "+5% maximum HP for 15 minutes", "#b43a32"),
	elixir("elixir_focus_t3", "Elixir of Focus III", 3,
		G .. "crimson_lotus", C .. "cave_cap", "mana_pool_percent", 5,
		900, "+5% maximum Mana for 15 minutes", "#375cb8"),
	elixir("elixir_precision_t3", "Elixir of Precision III", 3,
		G .. "crimson_lotus", M .. "fang", "crit_percent", 1,
		900, "+1 percentage point Crit for 15 minutes", "#d28a31"),

	elixir("elixir_vigor_t4", "Elixir of Vigor IV", 4,
		G .. "crimson_lotus", M .. "croc_tooth", "hp_pool_percent", 10,
		900, "+10% maximum HP for 15 minutes", "#a52c29"),
	elixir("elixir_focus_t4", "Elixir of Focus IV", 4,
		G .. "crimson_lotus", M .. "venom_sac", "mana_pool_percent", 10,
		900, "+10% maximum Mana for 15 minutes", "#2c4da1"),
	elixir("elixir_precision_t4", "Elixir of Precision IV", 4,
		G .. "crimson_lotus", M .. "shiny_scale", "crit_percent", 2,
		900, "+2 percentage points Crit for 15 minutes", "#be7627"),
	elixir("elixir_stoneskin", "Stoneskin Elixir", 4,
		M .. "shiny_scale", M .. "croc_tooth", "armor", 4,
		1800, "+4% armor for 30 minutes", "#747474"),

	elixir("elixir_vigor_t5", "Elixir of Vigor V", 5,
		G .. "crimson_lotus", C .. "ember_moss", "hp_pool_percent", 15,
		900, "+15% maximum HP for 15 minutes", "#922221"),
	elixir("elixir_focus_t5", "Elixir of Focus V", 5,
		C .. "cave_cap", C .. "ember_moss", "mana_pool_percent", 15,
		900, "+15% maximum Mana for 15 minutes", "#233f91"),
	elixir("elixir_precision_t5", "Elixir of Precision V", 5,
		M .. "shiny_scale", C .. "ember_moss", "crit_percent", 3,
		900, "+3 percentage points Crit for 15 minutes", "#a96720"),
	elixir("elixir_deepwater", "Deepwater Elixir", 5,
		G .. "stormkelp", M .. "slime_gel", nil, 0,
		600, "Water breathing for 10 minutes", "#269ca7", "deepwater"),

	elixir("elixir_vigor_t6", "Elixir of Vigor VI", 6,
		C .. "ember_moss", M .. "stone_core", "hp_pool_percent", 20,
		900, "+20% maximum HP for 15 minutes", "#761a1c"),
	elixir("elixir_focus_t6", "Elixir of Focus VI", 6,
		C .. "ember_moss", G .. "wild_cocoa", "mana_pool_percent", 20,
		900, "+20% maximum Mana for 15 minutes", "#1c337c"),
	elixir("elixir_precision_t6", "Elixir of Precision VI", 6,
		C .. "ember_moss", M .. "sharp_feather", "crit_percent", 4,
		900, "+4 percentage points Crit for 15 minutes", "#925618"),
}

grug_alchemy.CATALOG = catalog
grug_alchemy.INGREDIENT_TIERS = ingredients

for index = 1, #catalog do
	local row = catalog[index]
	grug_jobs.register_recipe({
		profession = "alchemist", tier = row.tier, station = "brewing_stand",
		inputs = row.inputs, output = "grug_alchemy:" .. row.id,
		hint = "Brew at a Brewing Stand", time = 5,
	})
end

-- Housing copy: still profession gated and settled by the existing grid
-- adapter. Steel is the declared T3 ingredient.
grug_jobs.register_recipe({
	profession = "alchemist", tier = 3, station = "grid",
	inputs = {
		{"grug_materials:steel_bar", "vessels:glass_bottle",
			"grug_materials:steel_bar"},
		{"", "default:furnace", ""},
		{"", "grug_materials:steel_bar", ""},
	},
	output = grug_brewing.NODE,
	hint = "Craft in the inventory grid",
})

grug_jobs.register_station("brewing_stand", {
	register_recipe = grug_brewing.register_recipe,
	can_use = function(player) return grug_jobs.has(player, "alchemist") end,
})

grug_gathering.register_herb_authorizer(function(player)
	if not player or not player.is_player or not player:is_player() then
		return false, "no_alchemist"
	end
	if grug_jobs.has(player, "alchemist") then return true, nil end
	return false, "no_alchemist"
end)

grug_traders.register_all_vendor_stock({item = VIAL, price = 3,
	category = "goods"})

-- Capital protection covers the station, so these six authored stations are
-- public while a player-placed stand continues to obey ordinary protection.
core.register_on_mods_loaded(function()
	local settlements = grug_core.settlement_socket_settlements()
	for index = 1, #settlements do
		local sockets = grug_core.settlement_sockets_at(settlements[index].key)
		for socket_index = 1, #sockets do
			local socket = sockets[socket_index]
			if socket.role == "public_station" and socket.tags and
					socket.tags[1] == "brewing_stand" then
				grug_brewing.register_public_position(socket.pos)
			end
		end
	end
end)
