-- Potions and elixirs T1-T6 (item_tiers.md §5): healing and mana potions
-- restore fixed amounts, elixirs give two enchants' worth of their stat at the
-- tier's top level (Stoneskin one armor enchant). Ingredients are herbs and
-- signatures of both factions' zones, never above the recipe tier.

local VIAL = "vessels:glass_bottle"
local G = "grug_gathering:"
local C = "grug_cooking:"
local M = "grug_mobs:"
local ROOT = "group:grug_cooking_root"

-- Herb tiers; the cooking goods carry theirs from grug_cooking, the mob loot
-- its catalogue tier (registered below).
local ingredients = {
	[G .. "gravemoss"] = 1,
	[G .. "sunleaf"] = 1,
	[G .. "dragonweed"] = 2,
	[G .. "crimson_lotus"] = 3,
	[G .. "stormkelp"] = 5,
	[G .. "wild_cocoa"] = 6,
}

local ROMAN = {"I", "II", "III", "IV", "V", "VI"}
grug_alchemy.POTION_AMOUNTS = {70, 200, 400, 650, 1000, 1350}

-- Elixir values per tier (item_tiers.md §5): Vigor, Focus and Precision two
-- enchants at the tier's top level, Stoneskin one armor enchant.
local ELIXIRS = {
	{key = "vigor", name = "Elixir of Vigor", modifier = "hp_pool_percent",
		values = {4.0, 4.8, 5.6, 6.4, 7.2, 8.0}, duration = 900,
		text = "+%.1f%% maximum HP for 15 minutes",
		colors = {"#c4483e", "#b43a32", "#a52c29", "#922221", "#82201f", "#761a1c"}},
	{key = "focus", name = "Elixir of Focus", modifier = "mana_pool_percent",
		values = {5.0, 5.6, 6.2, 6.8, 7.4, 8.0}, duration = 900,
		text = "+%.1f%% maximum Mana for 15 minutes",
		colors = {"#4269c4", "#375cb8", "#2c4da1", "#233f91", "#203886", "#1c337c"}},
	{key = "precision", name = "Elixir of Precision", modifier = "crit_percent",
		values = {4.2, 5.2, 6.0, 7.0, 7.8, 8.6}, duration = 900,
		text = "+%.1f percentage points Crit for 15 minutes",
		colors = {"#e19a3d", "#d28a31", "#be7627", "#a96720", "#9c5e1c", "#925618"}},
	{key = "stoneskin", name = "Stoneskin Elixir", modifier = "armor",
		values = {0.8, 1.6, 2.4, 3.2, 4.0, 4.8}, duration = 1800,
		text = "+%.1f armor rating for 30 minutes",
		colors = {"#8a8a8a", "#808080", "#747474", "#686868", "#5c5c5c", "#505050"}},
}
local HEALING_COLORS = {"#d13b45", "#c3313b", "#b42631", "#a81729", "#961222", "#850e1c"}
local MANA_COLORS = {"#356ed1", "#2f63c2", "#2a57b2", "#253ea3", "#203893", "#1b3184"}

-- The two ingredients (plus a Glass Bottle) of every product per tier.
local RECIPES = {
	{healing = {G .. "gravemoss", G .. "sunleaf"},
		mana = {G .. "gravemoss", ROOT},
		vigor = {G .. "sunleaf", M .. "tattered_flesh"},
		focus = {G .. "gravemoss", M .. "crab_eye"},
		precision = {G .. "sunleaf", M .. "boar_tusk"},
		stoneskin = {G .. "gravemoss", M .. "crab_leg"}},
	-- Precision II takes the Ridged Boar Tusk: Dragonweed + Fang is the
	-- Swiftness Draught's recipe, and two grid recipes cannot share inputs.
	{healing = {G .. "dragonweed", G .. "sunleaf"},
		mana = {G .. "dragonweed", C .. "sugar_cane"},
		vigor = {G .. "dragonweed", M .. "tough_sinew"},
		focus = {G .. "dragonweed", M .. "clear_crab_eye"},
		precision = {G .. "dragonweed", M .. "ridged_boar_tusk"},
		stoneskin = {G .. "dragonweed", M .. "ridged_crab_shell"}},
	{healing = {G .. "crimson_lotus", G .. "gravemoss"},
		mana = {G .. "crimson_lotus", C .. "sugar_cane"},
		vigor = {G .. "crimson_lotus", M .. "bear_claw"},
		focus = {G .. "crimson_lotus", C .. "cave_cap"},
		precision = {G .. "crimson_lotus", M .. "serrated_fang"},
		stoneskin = {G .. "crimson_lotus", M .. "layered_crab_shell"}},
	{healing = {G .. "crimson_lotus", M .. "leathery_flesh"},
		mana = {G .. "crimson_lotus", M .. "venom_sac"},
		vigor = {G .. "crimson_lotus", M .. "ironbound_sinew"},
		focus = {G .. "crimson_lotus", M .. "campaign_talisman"},
		precision = {G .. "crimson_lotus", M .. "razor_cat_claw"},
		stoneskin = {G .. "crimson_lotus", M .. "shiny_scale"}},
	{healing = {C .. "ember_moss", G .. "crimson_lotus"},
		mana = {G .. "stormkelp", G .. "crimson_lotus"},
		vigor = {C .. "ember_moss", M .. "scorched_flesh"},
		focus = {C .. "ember_moss", C .. "cave_cap"},
		precision = {C .. "ember_moss", M .. "siegepack_fang"},
		stoneskin = {G .. "stormkelp", M .. "siege_bone"}},
	{healing = {G .. "wild_cocoa", C .. "ember_moss"},
		mana = {G .. "wild_cocoa", G .. "stormkelp"},
		vigor = {G .. "wild_cocoa", M .. "salt_cured_flesh"},
		focus = {G .. "wild_cocoa", M .. "last_hex_shard"},
		precision = {C .. "ember_moss", M .. "sharp_feather"},
		stoneskin = {G .. "wild_cocoa", M .. "unquiet_bone"}},
}

-- The draughts with an effect of their own; tiers and effects unchanged.
local UTILITY = {
	[2] = {
		{kind = "utility", id = "potion_antivenom", name = "Antivenom",
			inputs = {G .. "dragonweed", M .. "venom_gland"}, effect_kind = "antivenom",
			duration = 0, text = "Cures poison", color = "#63ba52"},
		{kind = "utility", id = "potion_swiftness", name = "Swiftness Draught",
			inputs = {G .. "dragonweed", M .. "fang"}, effect_kind = "swiftness",
			duration = 5, text = "+10% movement speed for 5 seconds", color = "#e9c83b"},
	},
	[3] = {
		{kind = "utility", id = "potion_cave", name = "Cave Draught",
			inputs = {C .. "cave_cap", M .. "bound_wisp_mote"}, effect_kind = "cave",
			duration = 600, text = "Night vision for 10 minutes", color = "#804db5"},
	},
	[5] = {
		{kind = "elixir", id = "elixir_deepwater", name = "Deepwater Elixir",
			inputs = {G .. "stormkelp", C .. "cave_cap"}, effect_kind = "deepwater",
			duration = 600, text = "Water breathing for 10 minutes", color = "#269ca7"},
	},
}

-- The mob loot's tier is its catalogue tier (grug_mobs/data/items.json), so
-- a recipe's tier check reads the same number as every other profession.
local catalogue_tier = {}
local catalogue = grug_mobs.read_data_json("items.json") or {}
for _, row in ipairs(catalogue.items or catalogue) do
	if type(row) == "table" and type(row.id) == "string" then
		catalogue_tier[row.id] = tonumber(row.tier)
	end
end

local function note_inputs(inputs)
	for _, item in ipairs(inputs) do
		if item:sub(1, #M) == M then
			ingredients[item] = assert(catalogue_tier[item],
				"grug_alchemy: " .. item .. " has no catalogue tier")
		end
	end
end

local function requirement(tier)
	local level = grug_alchemy.TIER_LEVELS[tier]
	return level > 1 and ("\nRequires level " .. level) or ""
end

local function potion(tier, kind)
	local name = (kind == "health" and "Healing Potion " or "Mana Potion ") .. ROMAN[tier]
	local amount = grug_alchemy.POTION_AMOUNTS[tier]
	local effect = "Restores " .. amount .. (kind == "health" and " HP" or " Mana")
	local id = (kind == "health" and "potion_healing_t" or "potion_mana_t") .. tier
	local inputs = RECIPES[tier][kind == "health" and "healing" or "mana"]
	grug_alchemy.register_consumable(id, {
		family = "potion", tier = tier,
		color = (kind == "health" and HEALING_COLORS or MANA_COLORS)[tier],
		description = name .. "\n" .. effect .. " at once. Shared " ..
			grug_traders.POTION_COOLDOWN .. " second potion cooldown." ..
			requirement(tier),
		on_use = grug_alchemy.potion_use(kind, amount),
	})
	return {id = id, name = name, tier = tier, inputs = {inputs[1], inputs[2], VIAL},
		effect = effect, family = "potion", amount = amount}
end

local function elixir(tier, def)
	local name = def.name .. " " .. ROMAN[tier]
	local value = def.values[tier]
	local effect = def.text:format(value)
	local id = "elixir_" .. def.key .. "_t" .. tier
	local inputs = RECIPES[tier][def.key]
	grug_alchemy.register_consumable(id, {
		family = "elixir", tier = tier, color = def.colors[tier],
		description = name .. "\n" .. effect .. ". Replaces your current elixir." ..
			requirement(tier),
		on_use = grug_alchemy.elixir_use({label = name, modifier = def.modifier,
			value = value, duration = def.duration}),
	})
	return {id = id, name = name, tier = tier, inputs = {inputs[1], inputs[2], VIAL},
		effect = effect, family = "elixir", modifier = def.modifier, value = value,
		duration = def.duration}
end

local function special(tier, def)
	if def.kind == "elixir" then
		grug_alchemy.register_consumable(def.id, {
			family = "elixir", tier = tier, color = def.color,
			description = def.name .. "\n" .. def.text ..
				". Replaces your current elixir." .. requirement(tier),
			on_use = grug_alchemy.elixir_use({label = def.name, value = 0,
				duration = def.duration, kind = def.effect_kind}),
		})
	else
		grug_alchemy.register_consumable(def.id, {
			family = "potion", tier = tier, color = def.color,
			description = def.name .. "\n" .. def.text .. ". Shared " ..
				grug_traders.POTION_COOLDOWN .. " second potion cooldown." ..
				requirement(tier),
			on_use = grug_alchemy.utility_use(def.effect_kind, def.duration),
		})
	end
	return {id = def.id, name = def.name, tier = tier,
		inputs = {def.inputs[1], def.inputs[2], VIAL}, effect = def.text,
		family = def.kind == "elixir" and "elixir" or "potion",
		duration = def.duration}
end

local catalog = {}
for tier = 1, 6 do
	catalog[#catalog + 1] = potion(tier, "health")
	catalog[#catalog + 1] = potion(tier, "mana")
	for _, def in ipairs(ELIXIRS) do
		catalog[#catalog + 1] = elixir(tier, def)
	end
	for _, def in ipairs(UTILITY[tier] or {}) do
		catalog[#catalog + 1] = special(tier, def)
	end
end
for _, row in ipairs(catalog) do note_inputs(row.inputs) end

for item, tier in pairs(ingredients) do
	grug_jobs.register_ingredient_tier(item, tier)
end

grug_alchemy.CATALOG = catalog
grug_alchemy.INGREDIENT_TIERS = ingredients

-- Every product is an Alchemy recipe at the brewing stand (Round 45, spec
-- rulings 27 and 30: 2 s per potion or elixir) that makes the finished
-- potion; each one gives Alchemy XP (spec ruling 31, the registry's
-- `progress` default).
for index = 1, #catalog do
	local row = catalog[index]
	grug_jobs.register_recipe({area = "alchemist", tier = row.tier,
		station = "brewing_stand", output = "grug_alchemy:" .. row.id,
		ingredients = grug_jobs.ingredient_list(row.inputs),
		time = grug_jobs.DURATIONS.potion})
end

-- The prepared mixtures of the automatic brewing before Round 45 stay
-- registered as inert items (stable ids: chests and dug stations may still
-- hold them); no recipe makes or uses them. Lane MS deletes them from
-- characters (round45-plan.md ruling 2).
for index = 1, #catalog do
	local row = catalog[index]
	row.mixture = "grug_alchemy:mixture_" .. row.id
	core.register_craftitem(row.mixture, {
		description = "Prepared " .. row.name .. " Mixture\nNo longer used: " ..
			"alchemists now brew finished potions and elixirs.",
		inventory_image = core.registered_items["grug_alchemy:" .. row.id].inventory_image,
		groups = {grug_potion_mixture = 1}, _grug_tier = row.tier,
	})
end

-- Housing copy: the stand itself, an Alchemy recipe without XP and without a
-- stand nearby. Steel is the declared T3 ingredient.
grug_jobs.register_recipe({area = "alchemist", tier = 3, output = grug_brewing.NODE,
	ingredients = {{item = "grug_materials:steel_bar", n = 3},
		{item = "vessels:glass_bottle", n = 1}, {item = "default:furnace", n = 1}},
	time = grug_jobs.DURATIONS.station, progress = false})

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
