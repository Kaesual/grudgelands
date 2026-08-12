-- Canonical natural resources and material items (WP43).

local ORE_VISUALS = {
	quartz = {"default_mineral_diamond.png", "#eaf6ff:120", 2},
	silver = {"default_mineral_iron.png", "#e8edf2:200", 2},
	citrine = {"default_mineral_diamond.png", "#d9a21b:190", 2},
	garnet = {"default_mineral_diamond.png", "#9e1526:210", 2},
	jade = {"default_mineral_diamond.png", "#3d9b65:190", 2},
	emberglass = {"default_mineral_mese.png", "#ff7a2e:65", 1},
	diamond = {"default_mineral_diamond.png", "#ffffff:20", 1},
	sapphire = {"default_mineral_diamond.png", "#235ac7:190", 1},
	ruby = {"default_mineral_diamond.png", "#c51d35:195", 1},
	abyssal_crystal = {"default_mineral_diamond.png", "#3a1f6e:210", 1},
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
		description = resource.name .. " Ore",
		tiles = {"default_stone.png^(" .. ore[1] .. "^[colorize:" .. ore[2] .. ")"},
		groups = {cracky = ore[3], grug_natural = 1,
			grug_resource = resource.harvest_tier},
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
