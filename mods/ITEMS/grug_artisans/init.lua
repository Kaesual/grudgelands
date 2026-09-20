-- R9 Woodcarver and Goldsmith content. The catalog files own recipes while
-- this entry point owns their shared registration, refinement and audit seams.

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

function grug_artisans.register_refinement(tier, base, wood_grade)
	return grug_artisans.register_recipe("woodcarver", {
		tier = tier,
		station = "carving_bench",
		inputs = {{base, wood_grade}},
		output = base,
		in_place = true,
		operation = "refinement", family = "weapon",
		operation_material = wood_grade, quality_mode = "refinement",
		hint = "Improve at a Carving Bench",
	})
end

function grug_artisans.register_add_affix(tier, base, wood_grade, reagent)
	return grug_artisans.register_recipe("woodcarver", {
		tier = tier, station = "carving_bench",
		inputs = {{base, wood_grade, reagent}}, output = base,
		in_place = true, operation = "add_affix", family = "weapon",
		operation_material = wood_grade, operation_reagent = reagent,
		hint = "Add the next affix at a Carving Bench",
	})
end

dofile(modpath .. "/woodcarver.lua")
dofile(modpath .. "/goldsmith.lua")

local KIT_GROUPS = {
	{group = "grug_whetstone_", family = "melee_weapon"},
	{group = "grug_armor_polish_", family = "metal_armor"},
	{group = "grug_leather_", family = "leather_armor"},
	{group = "grug_embroidery_", family = "cloth_armor"},
	{group = "grug_wood_oil_", family = "caster_weapon"},
	{group = "grug_gem_setting_", family = "trinket"},
}

local function kit_definition(stack)
	local groups = (stack:get_definition() or {}).groups or {}
	for index = 1, #KIT_GROUPS do
		local row = KIT_GROUPS[index]
		for _, mode in ipairs({"imbue", "temper"}) do
			local tier = tonumber(groups[row.group .. mode])
			if tier and tier > 0 then return mode, row.family, tier end
		end
	end
end

local function upgrade_inputs(old_grid)
	local item, kit, mode, family, tier
	for index = 1, #old_grid do
		local stack = old_grid[index]
		if stack and not stack:is_empty() then
			local candidate_mode, candidate_family, candidate_tier = kit_definition(stack)
			if candidate_mode then
				kit, mode, family, tier = stack, candidate_mode, candidate_family,
					candidate_tier
			elseif grug_items.family_for(stack) then
				item = stack
			end
		end
	end
	return item, kit, mode, family, tier
end

core.register_craft_predict(function(itemstack, player, old_grid)
	local item, kit, mode, family, tier = upgrade_inputs(old_grid)
	if not item or not kit then return nil end
	local definition = item:get_definition() or {}
	if grug_items.family_for(item) ~= family or
			tonumber(definition._grug_bracket) ~= tier then
		return ItemStack("")
	end
	local allowed = grug_items.can_apply_upgrade_kit(item, mode)
	if not allowed then return ItemStack("") end
	return ItemStack(item)
end)

core.register_on_craft(function(itemstack, player, old_grid)
	local item, kit, mode, family, tier = upgrade_inputs(old_grid)
	if not item or not kit then return nil end
	local definition = item:get_definition() or {}
	if grug_items.family_for(item) ~= family or
			tonumber(definition._grug_bracket) ~= tier then return ItemStack("") end
	local result = ItemStack(item)
	result:set_count(1)
	local allowed = grug_items.apply_upgrade_kit(result, mode)
	return allowed and result or ItemStack("")
end)

for kit_name, kit_def in pairs(core.registered_items) do
	local mode, family, tier = kit_definition(ItemStack(kit_name))
	if mode then
		for item_name, item_def in pairs(core.registered_items) do
			local probe = ItemStack(item_name)
			if grug_items.family_for(probe) == family and
					tonumber(item_def._grug_bracket) == tier then
				core.register_craft({type = "shapeless", output = item_name,
					recipe = {item_name, kit_name}})
			end
		end
	end
end

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
