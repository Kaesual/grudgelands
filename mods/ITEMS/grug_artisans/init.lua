-- R9 Woodcarver and Goldsmith content. The catalog files own recipes while
-- this entry point owns their shared registration and audit seams.

grug_artisans = {
	CATALOGS = {woodcarver = {}, goldsmith = {}},
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

function grug_artisans.register_recipe(profession, definition)
	definition.profession = profession
	local recipe = grug_jobs.register_recipe(definition)
	grug_artisans.CATALOGS[profession][#grug_artisans.CATALOGS[profession] + 1] = {
		tier = recipe.tier,
		station = recipe.station,
		inputs = recipe.inputs,
		output = recipe.output_name,
		material = recipe.material,
		in_place = recipe.in_place,
		hint = recipe.hint,
	}
	return recipe
end

dofile(modpath .. "/woodcarver.lua")
dofile(modpath .. "/goldsmith.lua")

dofile(modpath .. "/enchants.lua")

local function input_exists(input)
	local group = input:match("^group:(.+)$")
	if not group then return core.registered_items[input] ~= nil end
	for name in pairs(core.registered_items) do
		if core.get_item_group(name, group) > 0 then return true end
	end
	return false
end

core.register_on_mods_loaded(function()
	for profession, catalog in pairs(grug_artisans.CATALOGS) do
		for index = 1, #catalog do
			local row = catalog[index]
			if not core.registered_items[row.output] then
				error("grug_artisans: unregistered " .. profession ..
					" output " .. row.output, 0)
			end
			local inputs = grug_jobs._flatten_inputs(row.inputs)
			for input_index = 1, #inputs do
				if not input_exists(inputs[input_index]) then
					error("grug_artisans: unregistered " .. profession ..
						" input " .. inputs[input_index], 0)
				end
			end
		end
	end
end)

core.log("action", "[grug_artisans] registered Woodcarver and Goldsmith catalogs")
