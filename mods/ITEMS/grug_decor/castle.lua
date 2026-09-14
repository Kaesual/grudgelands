-- Harvested from castle_masonry (github.com/minetest-mods/castle_masonry),
-- MIT code, textures CC-BY-SA 3.0 (Philipner / Napiophelios).
-- Upstream commit: see VENDOR.md.
--
-- What is harvested: the node definitions produced by upstream's
-- `register_pillar` / `register_arrowslit` / `register_murderhole` material
-- loop plus the six single nodes of `stone_wall.lua` / `paving.lua`.
-- What is NOT harvested: every `register_craft`, the arrowslit-flip LBM, all
-- `register_alias` calls, the `castle_masonry_*` settings and the `_mcl_*`
-- fields (this is not a VoxeLibre game).
--
-- GRUG PATCH: upstream derives each material's groups/sounds/tiles at load
-- time from `core.registered_nodes[craft_material]`. We spell the material
-- table out instead, so that (a) grug_decor never depends on the load order of
-- `grug_materials`, which rewrites `default`'s groups, and (b) the decor copies
-- carry plain hardness groups only -- no `stone`/`level` group that a resource
-- or mapgen system could dispatch on.

local sounds_stone = default.node_sound_stone_defaults()
local sounds_gravel = default.node_sound_gravel_defaults()

-- name: the part that becomes the node name; desc: player-facing material
-- name; tiles: the tile definition; groups: plain hardness groups.
local materials = {
	{
		name = "castle",
		desc = "Castle Stone",
		tiles = {"grug_decor_castle_castle_stonewall.png"},
		groups = {cracky = 3},
	},
	{
		name = "stonebrick",
		desc = "Stone Brick",
		tiles = {"default_stone_brick.png"},
		groups = {cracky = 2},
	},
	{
		name = "stone_block",
		desc = "Stone Block",
		tiles = {"default_stone_block.png"},
		groups = {cracky = 2},
	},
	{
		name = "desert_stonebrick",
		desc = "Desert Stone Brick",
		tiles = {"default_desert_stone_brick.png"},
		groups = {cracky = 2},
	},
	{
		name = "desert_stone_block",
		desc = "Desert Stone Block",
		tiles = {"default_desert_stone_block.png"},
		groups = {cracky = 2},
	},
	{
		name = "sandstonebrick",
		desc = "Sandstone Brick",
		tiles = {"default_sandstone_brick.png"},
		groups = {cracky = 2},
	},
	{
		name = "silver_sandstone_brick",
		desc = "Silver Sandstone Brick",
		tiles = {"default_silver_sandstone_brick.png"},
		groups = {cracky = 2},
	},
	{
		name = "obsidianbrick",
		desc = "Obsidian Brick",
		tiles = {"default_obsidian_brick.png"},
		groups = {cracky = 1},
	},
	{
		name = "mossycobble",
		desc = "Mossy Cobblestone",
		tiles = {"default_mossycobble.png"},
		groups = {cracky = 3},
	},
}

-- GRUG PATCH: copy of upstream `copy_merge` in castle_masonry/pillars.lua.
local function copy_merge(template, overwrites)
	local out = {}
	for k, v in pairs(template) do
		out[k] = v
	end
	for k, v in pairs(overwrites) do
		out[k] = v
	end
	return out
end

local function register_pillar(material)
	local prefix = "grug_decor:castle_pillar_" .. material.name
	local connectable = table.copy(material.groups)
	connectable.crossbrace_connectable = 1

	local template = {
		drawtype = "nodebox",
		groups = material.groups,
		paramtype = "light",
		paramtype2 = "facedir",
		sounds = sounds_stone,
		tiles = material.tiles,
		is_ground_content = false,
	}

	core.register_node(prefix .. "_bottom", copy_merge(template, {
		description = material.desc .. " Pillar Base",
		groups = connectable,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, -0.375, 0.5},
				{-0.375, -0.375, -0.375, 0.375, -0.125, 0.375},
				{-0.25, -0.125, -0.25, 0.25, 0.5, 0.25},
			},
		},
	}))

	core.register_node(prefix .. "_bottom_half", copy_merge(template, {
		description = material.desc .. " Half Pillar Base",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, 0, 0.5, -0.375, 0.5},
				{-0.375, -0.375, 0.125, 0.375, -0.125, 0.5},
				{-0.25, -0.125, 0.25, 0.25, 0.5, 0.5},
			},
		},
	}))

	core.register_node(prefix .. "_top", copy_merge(template, {
		description = material.desc .. " Pillar Top",
		groups = connectable,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, 0.3125, -0.5, 0.5, 0.5, 0.5},
				{-0.375, 0.0625, -0.375, 0.375, 0.3125, 0.375},
				{-0.25, -0.5, -0.25, 0.25, 0.0625, 0.25},
			},
		},
	}))

	core.register_node(prefix .. "_top_half", copy_merge(template, {
		description = material.desc .. " Half Pillar Top",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, 0.3125, 0, 0.5, 0.5, 0.5},
				{-0.375, 0.0625, 0.125, 0.375, 0.3125, 0.5},
				{-0.25, -0.5, 0.25, 0.25, 0.0625, 0.5},
			},
		},
	}))

	core.register_node(prefix .. "_middle", copy_merge(template, {
		description = material.desc .. " Pillar Middle",
		groups = connectable,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.25, -0.5, -0.25, 0.25, 0.5, 0.25},
			},
		},
	}))

	core.register_node(prefix .. "_middle_half", copy_merge(template, {
		description = material.desc .. " Half Pillar Middle",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.25, -0.5, 0.25, 0.25, 0.5, 0.5},
			},
		},
	}))

	core.register_node(prefix .. "_crossbrace", copy_merge(template, {
		description = material.desc .. " Crossbrace",
		node_box = {
			type = "connected",
			fixed = {-0.25, 0.25, -0.25, 0.25, 0.5, 0.25},
			connect_front = {-0.25, 0.25, -0.75, 0.25, 0.5, -0.25}, -- -Z
			connect_left = {-0.25, 0.25, -0.25, -0.75, 0.5, 0.25}, -- -X
			connect_back = {-0.25, 0.25, 0.25, 0.25, 0.5, 0.75}, -- +Z
			connect_right = {0.25, 0.25, -0.25, 0.75, 0.5, 0.25}, -- +X
		},
		connects_to = {
			prefix .. "_crossbrace",
			prefix .. "_extended_crossbrace",
			"group:crossbrace_connectable",
		},
		connect_sides = {"front", "left", "back", "right"},
	}))

	core.register_node(prefix .. "_extended_crossbrace", copy_merge(template, {
		description = material.desc .. " Extended Crossbrace",
		node_box = {
			type = "fixed",
			fixed = {-1.25, 0.25, -0.25, 1.25, 0.5, 0.25},
		},
	}))
end

local function register_arrowslit(material)
	local prefix = "grug_decor:castle_arrowslit_" .. material.name

	local template = {
		drawtype = "nodebox",
		tiles = material.tiles,
		groups = material.groups,
		sounds = sounds_stone,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
	}

	core.register_node(prefix, copy_merge(template, {
		description = material.desc .. " Arrowslit",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.375, 0.5, -0.0625, 0.375, 0.3125},
				{0.0625, -0.375, 0.5, 0.5, 0.375, 0.3125},
				{-0.5, 0.375, 0.5, 0.5, 0.5, 0.3125},
				{-0.5, -0.5, 0.5, 0.5, -0.375, 0.3125},
				{0.25, -0.5, 0.3125, 0.5, 0.5, 0.125},
				{-0.5, -0.5, 0.3125, -0.25, 0.5, 0.125},
			},
		},
	}))

	core.register_node(prefix .. "_cross", copy_merge(template, {
		description = material.desc .. " Arrowslit with Cross",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.125, 0.5, -0.0625, 0.375, 0.3125},
				{0.0625, -0.125, 0.5, 0.5, 0.375, 0.3125},
				{-0.5, 0.375, 0.5, 0.5, 0.5, 0.3125},
				{-0.5, -0.5, 0.5, 0.5, -0.375, 0.3125},
				{0.0625, -0.375, 0.5, 0.5, -0.25, 0.3125},
				{-0.5, -0.375, 0.5, -0.0625, -0.25, 0.3125},
				{-0.5, -0.25, 0.5, -0.1875, -0.125, 0.3125},
				{0.1875, -0.25, 0.5, 0.5, -0.125, 0.3125},
				{0.25, -0.5, 0.3125, 0.5, 0.5, 0.125},
				{-0.5, -0.5, 0.3125, -0.25, 0.5, 0.125},
			},
		},
	}))

	core.register_node(prefix .. "_hole", copy_merge(template, {
		description = material.desc .. " Arrowslit with Hole",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.375, 0.5, -0.125, 0.375, 0.3125},
				{0.125, -0.375, 0.5, 0.5, 0.375, 0.3125},
				{-0.5, -0.5, 0.5, 0.5, -0.375, 0.3125},
				{0.0625, -0.125, 0.5, 0.125, 0.375, 0.3125},
				{-0.125, -0.125, 0.5, -0.0625, 0.375, 0.3125},
				{-0.5, 0.375, 0.5, 0.5, 0.5, 0.3125},
				{0.25, -0.5, 0.3125, 0.5, 0.5, 0.125},
				{-0.5, -0.5, 0.3125, -0.25, 0.5, 0.125},
			},
		},
	}))

	core.register_node(prefix .. "_embrasure", copy_merge(template, {
		description = material.desc .. " Embrasure",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.25, -0.5, 0.375, -0.125, 0.5, 0.5},
				{0.125, -0.5, 0.375, 0.25, 0.5, 0.5},
				{0.25, -0.5, 0.25, 0.5, 0.5, 0.5},
				{0.375, -0.5, 0.125, 0.5, 0.5, 0.25},
				{-0.5, -0.5, 0.25, -0.25, 0.5, 0.5},
				{-0.5, -0.5, 0.125, -0.375, 0.5, 0.25},
			},
		},
	}))
end

local function register_murderhole(material)
	local template = {
		drawtype = "nodebox",
		tiles = material.tiles,
		groups = material.groups,
		sounds = sounds_stone,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
	}

	core.register_node("grug_decor:castle_hole_" .. material.name, copy_merge(template, {
		description = material.desc .. " Murder Hole",
		node_box = {
			type = "fixed",
			fixed = {
				{-8 / 16, -8 / 16, -8 / 16, -4 / 16, 8 / 16, 8 / 16},
				{4 / 16, -8 / 16, -8 / 16, 8 / 16, 8 / 16, 8 / 16},
				{-4 / 16, -8 / 16, -8 / 16, 4 / 16, 8 / 16, -4 / 16},
				{-4 / 16, -8 / 16, 8 / 16, 4 / 16, 8 / 16, 4 / 16},
			},
		},
	}))

	core.register_node("grug_decor:castle_machicolation_" .. material.name, copy_merge(template, {
		description = material.desc .. " Machicolation",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, 0, -0.5, 0.5, 0.5, 0},
				{-0.5, -0.5, 0, -0.25, 0.5, 0.5},
				{0.25, -0.5, 0, 0.5, 0.5, 0.5},
			},
		},
	}))
end

for _, material in ipairs(materials) do
	register_pillar(material)
	register_arrowslit(material)
	register_murderhole(material)
end

---------------------------------------------------------------------------
-- Single nodes (castle_masonry/stone_wall.lua, castle_masonry/paving.lua)
---------------------------------------------------------------------------

core.register_node("grug_decor:castle_stonewall", {
	description = "Castle Wall",
	drawtype = "normal",
	tiles = {"grug_decor_castle_castle_stonewall.png"},
	groups = {cracky = 3},
	sunlight_propagates = false,
	is_ground_content = false,
	sounds = sounds_stone,
})

core.register_node("grug_decor:castle_stonewall_corner", {
	description = "Castle Corner",
	drawtype = "normal",
	paramtype2 = "facedir",
	tiles = {
		"grug_decor_castle_castle_corner_stonewall_tb.png^[transformR90",
		"grug_decor_castle_castle_corner_stonewall_tb.png^[transformR180",
		"grug_decor_castle_castle_corner_stonewall1.png",
		"grug_decor_castle_castle_stonewall.png",
		"grug_decor_castle_castle_stonewall.png",
		"grug_decor_castle_castle_corner_stonewall2.png",
	},
	groups = {cracky = 3},
	is_ground_content = false,
	sounds = sounds_stone,
})

core.register_node("grug_decor:castle_rubble", {
	description = "Castle Rubble",
	drawtype = "normal",
	tiles = {"grug_decor_castle_castle_rubble.png"},
	-- GRUG PATCH: upstream adds `falling_node = 1`. Dropped: a settlement
	-- generator must be able to place a rubble pile without it collapsing.
	groups = {crumbly = 3},
	is_ground_content = false,
	sounds = sounds_gravel,
})

core.register_node("grug_decor:castle_dungeon_stone", {
	description = "Dungeon Stone",
	drawtype = "normal",
	tiles = {"grug_decor_castle_castle_dungeon_stone.png"},
	groups = {cracky = 2},
	is_ground_content = false,
	sounds = sounds_stone,
})

core.register_node("grug_decor:castle_pavement_brick", {
	description = "Paving Stone",
	drawtype = "normal",
	tiles = {"grug_decor_castle_castle_pavement_brick.png"},
	groups = {cracky = 2},
	is_ground_content = false,
	sounds = sounds_stone,
})

core.register_node("grug_decor:castle_roofslate", {
	drawtype = "raillike",
	description = "Roof Slates",
	inventory_image = "grug_decor_castle_castle_slate.png",
	paramtype = "light",
	walkable = false,
	tiles = {"grug_decor_castle_castle_slate.png"},
	climbable = true,
	selection_box = {
		type = "fixed",
		fixed = {-1 / 2, -1 / 2, -1 / 2, 1 / 2, -1 / 2 + 1 / 16, 1 / 2},
	},
	groups = {cracky = 3, attached_node = 1},
	is_ground_content = false,
	sounds = sounds_stone,
})

-- Upstream registers the same four shapes through `stairs` when that mod is
-- present; we use our own `grug_decor:` shape registrar instead (see
-- shapes.lua).
grug_decor.register_shapes("castle_stonewall", {
	description = "Castle Stonewall",
	tiles = {"grug_decor_castle_castle_stonewall.png"},
	groups = {cracky = 3},
	sounds = sounds_stone,
})

grug_decor.register_shapes("castle_rubble", {
	description = "Castle Rubble",
	tiles = {"grug_decor_castle_castle_rubble.png"},
	groups = {cracky = 3},
	sounds = sounds_stone,
})

grug_decor.register_shapes("castle_dungeon_stone", {
	description = "Dungeon Stone",
	tiles = {"grug_decor_castle_castle_dungeon_stone.png"},
	groups = {cracky = 2},
	sounds = sounds_stone,
})

grug_decor.register_shapes("castle_pavement_brick", {
	description = "Castle Pavement",
	tiles = {"grug_decor_castle_castle_pavement_brick.png"},
	groups = {cracky = 2},
	sounds = sounds_stone,
})
