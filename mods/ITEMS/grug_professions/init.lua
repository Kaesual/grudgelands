-- Profession materials, equipment recipes and named enchant catalogs.

grug_professions = {
	INGREDIENT_TIERS = {},
}

local modpath = core.get_modpath(core.get_current_modname())
grug_professions.enchant_data = dofile(modpath .. "/enchant_data.lua")

-- Decoded JSON from this mod's data/ directory, or nil when the file is absent.
function grug_professions.read_json(name)
	local file = io.open(modpath .. "/data/" .. name, "r")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	local value, err = core.parse_json(text, nil, true)
	if value == nil then
		error("grug_professions: data/" .. name .. ": " .. tostring(err), 0)
	end
	return value
end

function grug_professions.register_item(name, description, image, groups)
	if not core.registered_items[name] then
		core.register_craftitem(name, {
			description = description,
			inventory_image = image,
			groups = groups or {grug_profession_material = 1},
		})
	end
	return name
end

function grug_professions.register_ingredient(item, tier)
	grug_jobs.register_ingredient_tier(item, tier)
	grug_professions.INGREDIENT_TIERS[item] = tier
	return item
end

-- One recipe of `profession`'s area at its station (grug_jobs
-- PROFESSION_STATIONS); `definition` takes the record's other fields.
function grug_professions.register_recipe(profession, definition)
	definition.area = profession
	definition.station = grug_jobs.PROFESSION_STATIONS[profession]
	return grug_jobs.register_recipe(definition)
end

-- The profession that makes `family` (FAMILY_OWNERS, enchants.lua), or nil.
function grug_professions.family_owner(family)
	for profession, families in pairs(grug_professions.FAMILY_OWNERS) do
		for _, owned in ipairs(families) do
			if owned == family then return profession end
		end
	end
	return nil
end

local SUPPLIES = {
	{"thread", "Thread", "default_paper.png^[colorize:#d8d1bd:115", 1},
	{"parchment", "Parchment", "default_paper.png^[colorize:#d6b879:65", 5},
}

for index = 1, #SUPPLIES do
	local row = SUPPLIES[index]
	grug_professions.register_item("grug_professions:" .. row[1], row[2], row[3],
		{grug_profession_supply = 1})
	grug_traders.register_all_vendor_stock({
		item = "grug_professions:" .. row[1], price = row[4], category = "goods",
	})
end

-- Thread is an ordinary feedstock: its recipe (two from a Linen Scrap) is
-- Basic (grug_jobs/basic_recipes.lua), like the bolts, leathers and graded
-- wood the professions turn into gear.

dofile(core.get_modpath("grug_jobs") .. "/station_operations.lua")

-- The ingredient tier of the new mob loot grug_mobs registered from its
-- catalogue (data/items.json `tier`): the recipe books show it, and
-- enchants.lua refuses an enchant input declared above the enchant's tier.
for item, tier in pairs(grug_mobs.loot_item_tiers) do
	grug_jobs.register_ingredient_tier(item, tier)
end

-- The material tiers and the family owners first: a gear recipe is checked
-- against them.
dofile(modpath .. "/smiths.lua")
dofile(modpath .. "/leatherworker.lua")
dofile(modpath .. "/tailor.lua")
dofile(modpath .. "/enchants.lua")
dofile(modpath .. "/base_recipes.lua")

core.log("action", "[grug_professions] registered Weaponsmith, Armorsmith, " ..
	"Leatherworker and Tailor catalogs")
