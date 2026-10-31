-- Canonical natural resources and material items (WP43).

-- Stored, pre-coloured mineral overlays drawn over `default_stone.png`
-- (Round 24 ruling 17; `tools/r24_art/build_rock_ore_textures.py`; the
-- Anthracite overlay from Round 47 lane ART, `tools/r47_art/anthracite/`).
local ORE_VISUALS = {
	quartz = true, silver = true, citrine = true, garnet = true, jade = true,
	emberglass = true, diamond = true, sapphire = true, ruby = true,
	abyssal_crystal = true, anthracite = true,
}

-- Stored item images (Round 47 lane ART's Anthracite set, the user's pick
-- of 2026-10-13).
local STORED_ITEM_IMAGES = {
	anthracite = "grug_materials_anthracite_lump.png",
}

-- Stored images named after the registered id (`grug_materials:cut_ruby`
-- draws `grug_materials_cut_ruby.png`; Round 68 ICONS, the user's picks of
-- 2026-10-31): the raw, cut and block forms of these resources each have
-- their own.
local OWN_IMAGES = {
	quartz = true, citrine = true, garnet = true, jade = true, diamond = true,
	sapphire = true, ruby = true, abyssal_crystal = true,
}

local function own_image(name)
	return name:gsub(":", "_") .. ".png"
end

-- Silver and Emberglass keep tinted vendored images. Vendor payouts are
-- grug_traders' price module (class and harvest tier).
local ITEM_VISUALS = {
	silver = {"default_iron_lump.png", "#e8edf2:200"},
	emberglass = {"default_mese_crystal.png", "#ff7a2e:45"},
}

local function item_texture(resource)
	local key = resource.key
	if OWN_IMAGES[key] then return own_image(resource.raw_item) end
	if STORED_ITEM_IMAGES[key] then return STORED_ITEM_IMAGES[key] end
	local visual = ITEM_VISUALS[key]
	if not visual then
		error("grug_materials: missing item visual for " .. key)
	end
	return visual[1] .. "^[colorize:" .. visual[2]
end

local function register_owned_resource(resource)
	if not ORE_VISUALS[resource.key] then
		return
	end
	core.register_node(resource.natural_node, {
		description = grug_materials.resource_ore_description(resource),
		tiles = {"default_stone.png^grug_materials_mineral_" .. resource.key .. ".png"},
		groups = grug_materials.set_gate_groups({grug_natural = 1,
			grug_resource = resource.harvest_tier},
			grug_materials.resource_level(resource)),
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
		inventory_image = item_texture(resource),
	})

	if resource.cut_item then
		core.register_craftitem(resource.cut_item, {
			description = "Cut " .. resource.name,
			inventory_image = own_image(resource.cut_item),
		})
	end
	if resource.block_node then
		core.register_node(resource.block_node, {
			description = resource.name .. " Block",
			tiles = {OWN_IMAGES[resource.key] and own_image(resource.block_node)
				or item_texture(resource)},
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
-- Bars and storage blocks draw stored images named after their ids
-- (Round 68 ICONS, the user's pick A of 2026-10-31).
local PROCESSED_IMAGES = {
	copper = true, tin = true, bronze = true, iron = true, steel = true,
	silver = true, silversteel = true, embersteel = true, abyssal_steel = true,
	gold = true,
}

-- A bar pays what its smelting inputs pay (grug_traders' price module), so
-- no price lives here or in PROCESSED_MATERIALS (WP40's frozen projection).
for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
	local has_image = PROCESSED_IMAGES[material.key]
	if material.kind == "bar" and not core.registered_items[material.item] then
		if not has_image then
			error("grug_materials: missing processed visual for " .. material.key)
		end
		core.register_craftitem(material.item, {
			description = material.name .. " Bar",
			inventory_image = own_image(material.item),
		})
	end
	if not core.registered_nodes[material.block_node] then
		if not has_image then
			error("grug_materials: missing storage visual for " .. material.key)
		end
		core.register_node(material.block_node, {
			description = material.name .. " Block",
			tiles = {own_image(material.block_node)},
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
