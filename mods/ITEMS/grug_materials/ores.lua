-- Canonical natural resources and material items (WP43).

local ORE_VISUALS = {
	quartz = {"default_mineral_diamond.png", "#eaf6ff:120"},
	silver = {"default_mineral_iron.png", "#e8edf2:200"},
	citrine = {"default_mineral_diamond.png", "#d9a21b:190"},
	garnet = {"default_mineral_diamond.png", "#9e1526:210"},
	jade = {"default_mineral_diamond.png", "#3d9b65:190"},
	emberglass = {"default_mineral_mese.png", "#ff7a2e:65"},
	diamond = {"default_mineral_diamond.png", "#ffffff:20"},
	sapphire = {"default_mineral_diamond.png", "#235ac7:190"},
	ruby = {"default_mineral_diamond.png", "#c51d35:195"},
	abyssal_crystal = {"default_mineral_diamond.png", "#3a1f6e:210"},
}

local ITEM_VISUALS = {
	quartz = {"default_diamond.png", "#eaf6ff:120", 2},
	silver = {"default_iron_lump.png", "#e8edf2:200", 4},
	citrine = {"default_diamond.png", "#d9a21b:190", 3},
	garnet = {"default_diamond.png", "#9e1526:210", 3},
	jade = {"default_diamond.png", "#3d9b65:190", 3},
	emberglass = {"default_mese_crystal.png", "#ff7a2e:45", 5},
	diamond = {"default_diamond.png", "#ffffff:20", 3},
	sapphire = {"default_diamond.png", "#235ac7:190", 3},
	ruby = {"default_diamond.png", "#c51d35:195", 3},
	abyssal_crystal = {"default_diamond.png", "#3a1f6e:210", 6},
}

local function item_texture(key)
	local visual = ITEM_VISUALS[key]
	return visual[1] .. "^[colorize:" .. visual[2]
end

local function register_owned_resource(resource)
	local ore = ORE_VISUALS[resource.key]
	if not ore then
		return
	end
	core.register_node(resource.natural_node, {
		description = grug_materials.resource_ore_description(resource),
		tiles = {"default_stone.png^(" .. ore[1] .. "^[colorize:" .. ore[2] .. ")"},
		groups = {grug_natural = 1, grug_resource = resource.harvest_tier},
		drop = resource.raw_item,
		is_ground_content = true,
		sounds = default.node_sound_stone_defaults(),
	})

	local visual = ITEM_VISUALS[resource.key]
	local raw_description = resource.name
	if resource.grade then
		raw_description = "Rough " .. resource.name
	elseif resource.key == "quartz" then
		raw_description = "Quartz"
	end
	core.register_craftitem(resource.raw_item, {
		description = raw_description,
		inventory_image = item_texture(resource.key),
		_grug_sell_price = visual[3],
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
-- WP26 owns furnace/alloy outputs and the storage recipe families.
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

for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
	local visual = PROCESSED_VISUALS[material.key]
	if material.kind == "bar" and not core.registered_items[material.item] then
		if not visual then
			error("grug_materials: missing processed visual for " .. material.key)
		end
		core.register_craftitem(material.item, {
			description = material.name .. " Bar",
			inventory_image = visual[1],
			_grug_sell_price = material.sell_price,
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
	_grug_sell_price = 1,
})

local cultural_images = {
	human = "default_mese_crystal_fragment.png^[colorize:#f0c45a:120",
	dwarf = "default_stone.png^[colorize:#64758a:110",
	elf = "default_mese_crystal_fragment.png^[colorize:#a9c9ee:130",
	orc = "default_clay_lump.png^[colorize:#a54122:150",
	troll = "default_mese_crystal_fragment.png^[colorize:#8ca833:130",
	undead = "default_mese_crystal_fragment.png^[colorize:#ddd8c8:145",
}

for _, material in pairs(grug_materials.CULTURAL_MATERIALS) do
	core.register_craftitem(material.item, {
		description = material.name,
		inventory_image = cultural_images[material.race],
	})
end

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
