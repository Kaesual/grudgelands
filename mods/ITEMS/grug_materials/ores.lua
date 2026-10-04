-- Canonical natural resources and material items (WP43).

-- Stored, pre-coloured mineral overlays drawn over `default_stone.png`
-- (Round 24 ruling 17; `tools/r24_art/build_rock_ore_textures.py`).
local ORE_VISUALS = {
	quartz = true, silver = true, citrine = true, garnet = true, jade = true,
	emberglass = true, diamond = true, sapphire = true, ruby = true,
	abyssal_crystal = true,
}

-- Vendor payouts are grug_traders' price module (class and harvest tier).
local ITEM_VISUALS = {
	quartz = {"default_diamond.png", "#eaf6ff:120"},
	silver = {"default_iron_lump.png", "#e8edf2:200"},
	citrine = {"default_diamond.png", "#d9a21b:190"},
	garnet = {"default_diamond.png", "#9e1526:210"},
	jade = {"default_diamond.png", "#3d9b65:190"},
	emberglass = {"default_mese_crystal.png", "#ff7a2e:45"},
	diamond = {"default_diamond.png", "#ffffff:20"},
	sapphire = {"default_diamond.png", "#235ac7:190"},
	ruby = {"default_diamond.png", "#c51d35:195"},
	abyssal_crystal = {"default_diamond.png", "#3a1f6e:210"},
}

local function item_texture(key)
	local visual = ITEM_VISUALS[key]
	return visual[1] .. "^[colorize:" .. visual[2]
end

local function register_owned_resource(resource)
	if not ORE_VISUALS[resource.key] then
		return
	end
	core.register_node(resource.natural_node, {
		description = grug_materials.resource_ore_description(resource),
		tiles = {"default_stone.png^grug_materials_mineral_" .. resource.key .. ".png"},
		groups = {grug_natural = 1, grug_resource = resource.harvest_tier,
			level = grug_materials.level_for_tier(resource.harvest_tier)},
		drop = resource.raw_item,
		is_ground_content = true,
		sounds = default.node_sound_stone_defaults(),
	})

	local raw_description = resource.name
	if resource.gem then
		raw_description = "Rough " .. resource.name
	elseif resource.key == "quartz" then
		raw_description = "Quartz"
	end
	core.register_craftitem(resource.raw_item, {
		description = raw_description,
		inventory_image = item_texture(resource.key),
	})

	if resource.cut_item then
		core.register_craftitem(resource.cut_item, {
			description = "Cut " .. resource.name,
			inventory_image = item_texture(resource.key) .. "^[brighten",
		})
	end
	if resource.block_node then
		core.register_node(resource.block_node, {
			description = resource.name .. " Block",
			tiles = {item_texture(resource.key)},
			is_ground_content = false,
			groups = {cracky = 1},
			drop = resource.block_node,
			sounds = default.node_sound_stone_defaults(),
		})
	end
end

for _, resource in ipairs(grug_materials.RESOURCES) do
	if resource.natural_node:match("^grug_materials:") then
		register_owned_resource(resource)
	end
end

-- Canonical processed/storage concepts. No recipes are registered here;
-- `grug_smelting` owns the furnace/alloy outputs and the storage recipe
-- families (WP26, shipped 2026-09-16).
local PROCESSED_VISUALS = {
	copper = {"default_copper_ingot.png", "default_copper_block.png"},
	tin = {"default_tin_ingot.png", "default_tin_block.png"},
	bronze = {"default_bronze_ingot.png", "default_bronze_block.png"},
	iron = {"default_steel_ingot.png", "default_steel_block.png"},
	steel = {"default_steel_ingot.png^[colorize:#34404a:75",
		"default_steel_block.png^[colorize:#34404a:75"},
	silver = {"default_tin_ingot.png^[colorize:#f4f6fa:90",
		"default_tin_block.png^[colorize:#f4f6fa:90"},
	silversteel = {"default_steel_ingot.png^[colorize:#b7c9df:95",
		"default_steel_block.png^[colorize:#b7c9df:95"},
	embersteel = {"default_steel_ingot.png^[colorize:#b94b24:110",
		"default_steel_block.png^[colorize:#b94b24:110"},
	abyssal_steel = {"default_steel_ingot.png^[colorize:#3a245d:135",
		"default_steel_block.png^[colorize:#3a245d:135"},
	gold = {"default_gold_ingot.png", "default_gold_block.png"},
}

-- A bar pays what its smelting inputs pay (grug_traders' price module), so
-- no price lives here or in PROCESSED_MATERIALS (WP40's frozen projection).
for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
	local visual = PROCESSED_VISUALS[material.key]
	if material.kind == "bar" and not core.registered_items[material.item] then
		if not visual then
			error("grug_materials: missing processed visual for " .. material.key)
		end
		core.register_craftitem(material.item, {
			description = material.name .. " Bar",
			inventory_image = visual[1],
		})
	end
	if not core.registered_nodes[material.block_node] then
		if not visual then
			error("grug_materials: missing storage visual for " .. material.key)
		end
		core.register_node(material.block_node, {
			description = material.name .. " Block",
			tiles = {visual[2]},
			is_ground_content = false,
			groups = {cracky = 1},
			drop = material.block_node,
			sounds = default.node_sound_metal_defaults(),
		})
	end
end

core.register_craftitem("grug_materials:emberglass_shard", {
	description = "Emberglass Shard",
	inventory_image = "default_mese_crystal_fragment.png^[colorize:#ff7a2e:45",
})

core.register_node("grug_materials:emberglass_lamp", {
	description = "Emberglass Lamp",
	drawtype = "glasslike",
	tiles = {"default_meselamp.png^[colorize:#ff7a2e:25"},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 3},
	sounds = default.node_sound_glass_defaults(),
	light_source = default.LIGHT_MAX,
})

local posts = {
	{"emberglass_post_light", "Oak Emberglass Post Light", "default_fence_wood.png"},
	{"emberglass_post_light_acacia_wood", "Acacia Emberglass Post Light",
		"default_fence_acacia_wood.png"},
	{"emberglass_post_light_junglewood", "Jungle Wood Emberglass Post Light",
		"default_fence_junglewood.png"},
	{"emberglass_post_light_pine_wood", "Pine Emberglass Post Light",
		"default_fence_pine_wood.png"},
	{"emberglass_post_light_aspen_wood", "Aspen Emberglass Post Light",
		"default_fence_aspen_wood.png"},
}
for _, post in ipairs(posts) do
	default.register_mesepost("grug_materials:" .. post[1], {
		description = post[2], texture = post[3],
	})
end
