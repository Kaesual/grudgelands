-- R9 Woodcarver and Goldsmith content. The catalog files own recipes while
-- this entry point owns their shared registration and audit seams.

grug_artisans = {
	INGREDIENT_TIERS = {},
}

local modpath = core.get_modpath(core.get_current_modname())

function grug_artisans.register_item(name, description, image, groups)
	if core.registered_items[name] then
		error("grug_artisans: duplicate item concept " .. name, 0)
	end
	core.register_craftitem(name, {
		description = description,
		inventory_image = image,
		groups = groups or {grug_profession_material = 1},
	})
	return name
end

function grug_artisans.register_ingredient(item, tier)
	grug_jobs.register_ingredient_tier(item, tier)
	grug_artisans.INGREDIENT_TIERS[item] = tier
	return item
end

-- One recipe of `profession`'s area at its station (grug_jobs
-- PROFESSION_STATIONS); `definition` takes the record's other fields.
function grug_artisans.register_recipe(profession, definition)
	definition.area = profession
	definition.station = grug_jobs.PROFESSION_STATIONS[profession]
	return grug_jobs.register_recipe(definition)
end

dofile(modpath .. "/woodcarver.lua")
dofile(modpath .. "/goldsmith.lua")

dofile(modpath .. "/enchants.lua")

core.log("action", "[grug_artisans] registered Woodcarver and Goldsmith catalogs")
