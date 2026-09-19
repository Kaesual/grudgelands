-- R9 primary-profession content. One mod owns three catalog files so their
-- shared supplies, refinement metadata and collision checks have one source.
-- WP22 consumes the persistent grug_refined marker for the doubled wear budget.

grug_professions = {
	CATALOGS = {blacksmith = {}, leatherworker = {}, tailor = {}},
	INGREDIENT_TIERS = {},
}

local modpath = core.get_modpath(core.get_current_modname())
local STAT_COLOR = "#9aa0a6"
local refinement_recipes = {}

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
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
		station = "grid",
		inputs = {{base, material}},
		output = base,
		in_place = true,
		hint = "Refine in the inventory grid",
	})
	refinement_recipes[recipe.id] = family
	return recipe
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

dofile(modpath .. "/blacksmith.lua")
dofile(modpath .. "/leatherworker.lua")
dofile(modpath .. "/tailor.lua")

local function refined_description(stack, family)
	local definition = stack:get_definition()
	local description = definition.description or stack:get_name()
	local first = description:match("^[^\n]+") or stack:get_name()
	local level = description:match("\nItem level [^\n]+") or ""
	local meta = stack:get_meta()
	if family == "weapon" then
		local caps = copy(definition.tool_capabilities or {})
		caps.damage_groups = caps.damage_groups or {}
		local damage = caps.damage_groups.fleshy or 0
		damage = math.max(1, math.floor(damage * 1.15 + 0.5))
		caps.damage_groups.fleshy = damage
		meta:set_tool_capabilities(caps)
		meta:set_string("description", "Honed " .. first .. level .. "\n" ..
			core.colorize(STAT_COLOR, string.format("%d damage, %.1f s swing",
				damage, caps.full_punch_interval or 1.4)))
	else
		local armor = definition._grug_armor or 0
		armor = math.max(1, math.floor(armor * 1.15 + 0.5))
		meta:set_int("grug_refined_armor", armor)
		local word = family == "cloth_armor" and "Ornate " or "Reinforced "
		meta:set_string("description", word .. first .. level .. "\n" ..
			core.colorize(STAT_COLOR, string.format(
				"%d armor (-%d%% damage taken)", armor, armor)))
	end
	meta:set_int("grug_refined", 1)
	meta:set_int("grug_quality", definition._grug_quality or 1)
	return stack
end

local function refinement_for(itemstack, old_grid)
	local recipe = grug_jobs.recipe_for_craft("grid", itemstack, old_grid)
	local family = recipe and refinement_recipes[recipe.id]
	return recipe, family
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
	local recipe, family = refinement_for(itemstack, old_grid)
	if family and already_refined(old_grid, recipe.output_name) then
		if player and player.get_player_name then
			core.chat_send_player(player:get_player_name(),
				"That item is already refined.")
		end
		return ItemStack("")
	end
end)

core.register_on_craft(function(itemstack, player, old_grid)
	local recipe, family = refinement_for(itemstack, old_grid)
	if not family then return nil end
	local base
	for index = 1, #old_grid do
		local stack = old_grid[index]
		if stack and stack:get_name() == recipe.output_name then
			base = ItemStack(stack)
			break
		end
	end
	if not base then return nil end
	refined_description(base, family)
	if family == "weapon" and grug_gear.initialize_weapon_tooltip then
		grug_gear.initialize_weapon_tooltip(base, player)
	end
	return base
end)

-- Called while grug_inventory builds its invalidation-backed armor cache.
function grug_inventory.armor_points_of(stack, armor)
	if stack:get_meta():get_int("grug_refined") ~= 1 then return armor end
	local refined = stack:get_meta():get_int("grug_refined_armor")
	if refined > (armor or 0) then return refined end
	return armor
end

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

core.log("action", "[grug_professions] registered Blacksmith, Leatherworker " ..
	"and Tailor catalogs")
