-- R9 Woodcarver and Goldsmith content. The catalog files own recipes while
-- this entry point owns their shared registration, refinement and audit seams.

grug_artisans = {
	CATALOGS = {woodcarver = {}, goldsmith = {}},
	INGREDIENT_TIERS = {},
}

local modpath = core.get_modpath(core.get_current_modname())
local refinement_recipes = {}

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

function grug_artisans.register_refinement(tier, base, wood_grade)
	local recipe = grug_artisans.register_recipe("woodcarver", {
		tier = tier,
		station = "grid",
		inputs = {{base, wood_grade}},
		output = base,
		in_place = true,
		hint = "Refine in the inventory grid",
	})
	recipe.quality_mode = "refinement"
	refinement_recipes[recipe.id] = true
	return recipe
end

local function refinement_for(itemstack, old_grid)
	local recipe = grug_jobs.recipe_for_craft("grid", itemstack, old_grid)
	return recipe, recipe and refinement_recipes[recipe.id] == true
end

local function already_refined(old_grid, output_name)
	for index = 1, #old_grid do
		local stack = old_grid[index]
		if stack and stack:get_name() == output_name and
				stack:get_meta():get_int("grug_refined") == 1 then
			return true
		end
	end
	return false
end

core.register_craft_predict(function(itemstack, player, old_grid)
	local recipe, refinement = refinement_for(itemstack, old_grid)
	if refinement and already_refined(old_grid, recipe.output_name) then
		if player and player.get_player_name then
			core.chat_send_player(player:get_player_name(),
				"That item is already refined.")
		end
		return ItemStack("")
	end
end)

core.register_on_craft(function(itemstack, player, old_grid)
	local recipe, refinement = refinement_for(itemstack, old_grid)
	if not refinement then return nil end
	local base
	for index = 1, #old_grid do
		local stack = old_grid[index]
		if stack and stack:get_name() == recipe.output_name then
			base = ItemStack(stack)
			break
		end
	end
	if not base then return nil end
	grug_items.set_refined(base, true)
	if grug_gear.initialize_weapon_tooltip then
		grug_gear.initialize_weapon_tooltip(base, player)
	end
	return base
end)

dofile(modpath .. "/woodcarver.lua")
dofile(modpath .. "/goldsmith.lua")

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
