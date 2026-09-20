-- R9 primary-profession content. One mod owns three catalog files so their
-- shared supplies, refinement metadata and collision checks have one source.
-- WP22 consumes the persistent grug_refined marker for the doubled wear budget.

grug_professions = {
	CATALOGS = {weaponsmith = {}, armorsmith = {}, leatherworker = {}, tailor = {}},
	INGREDIENT_TIERS = {},
}

local modpath = core.get_modpath(core.get_current_modname())

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

function grug_professions.register_recipe(profession, definition)
	definition.profession = profession
	local recipe = grug_jobs.register_recipe(definition)
	local row = {
		tier = recipe.tier, station = recipe.station, inputs = recipe.inputs,
		output = recipe.output_name, hint = recipe.hint,
	}
	grug_professions.CATALOGS[profession][#grug_professions.CATALOGS[profession] + 1] = row
	return recipe
end

function grug_professions.register_refinement(profession, tier, family, base,
		material)
	local recipe = grug_professions.register_recipe(profession, {
		tier = tier,
		station = (profession == "weaponsmith" or profession == "armorsmith") and
			"forge" or (profession == "tailor" and "tailor_bench" or
			"tanning_rack"),
		inputs = {{base, material}},
		output = base,
		in_place = true,
		operation = "refinement", family = family,
		operation_material = material, quality_mode = "refinement",
		hint = "Improve at the owning profession station",
	})
	return recipe
end

function grug_professions.register_add_affix(profession, tier, family, base,
		material, reagent)
	return grug_professions.register_recipe(profession, {
		tier = tier,
		station = (profession == "weaponsmith" or profession == "armorsmith") and
			"forge" or (profession == "tailor" and "tailor_bench" or
			"tanning_rack"),
		inputs = {{base, material, reagent}}, output = base, in_place = true,
		operation = "add_affix", family = family,
		operation_material = material, operation_reagent = reagent,
		hint = "Add the next affix at the owning profession station",
	})
end

local SUPPLIES = {
	{"thread", "Thread", "default_paper.png^[colorize:#d8d1bd:115", 1},
	{"flux", "Smithing Flux", "default_clay_lump.png^[colorize:#62574b:110", 2},
	{"parchment", "Parchment", "default_paper.png^[colorize:#d6b879:65", 5},
	{"whetstone_blank", "Whetstone Blank",
		"default_stone.png^[colorize:#a5a09a:55", 4},
}

for index = 1, #SUPPLIES do
	local row = SUPPLIES[index]
	grug_professions.register_item("grug_professions:" .. row[1], row[2], row[3],
		{grug_profession_supply = 1})
	grug_traders.register_all_vendor_stock({
		item = "grug_professions:" .. row[1], price = row[4], category = "goods",
	})
end

-- Thread is an ordinary feedstock. Keeping this route in Basics prevents
-- universal cloth and leather equipment from hiding a Tailor dependency.
core.register_craft({
	output = "grug_professions:thread 2",
	recipe = {{"grug_mobs:linen_scrap"}},
})

dofile(modpath .. "/base_recipes.lua")
dofile(modpath .. "/smiths.lua")
dofile(modpath .. "/leatherworker.lua")
dofile(modpath .. "/tailor.lua")

core.register_on_mods_loaded(function()
	local function input_exists(input)
		local group = input:match("^group:(.+)$")
		if not group then return core.registered_items[input] ~= nil end
		for name in pairs(core.registered_items) do
			if core.get_item_group(name, group) > 0 then return true end
		end
		return false
	end
	for profession, catalog in pairs(grug_professions.CATALOGS) do
		for index = 1, #catalog do
			local row = catalog[index]
			if not core.registered_items[row.output] then
				error("grug_professions: unregistered " .. profession ..
					" output " .. row.output, 0)
			end
			local inputs = grug_jobs._flatten_inputs(row.inputs)
			for input_index = 1, #inputs do
				if not input_exists(inputs[input_index]) then
					error("grug_professions: unregistered " .. profession ..
						" input " .. inputs[input_index], 0)
				end
			end
		end
	end
end)

core.log("action", "[grug_professions] registered Weaponsmith, Armorsmith, " ..
	"Leatherworker and Tailor catalogs")
