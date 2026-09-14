-- Harvested from cottages (github.com/Sokomine/cottages), GPL-3.0-only code,
-- media per the per-file list in its README (see LICENSE-media.md).
-- Upstream commit: see VENDOR.md.
--
-- What is harvested: the roof family of `nodes_roof.lua` (three shapes per roof
-- material), the straw/loam/clay building blocks of `nodes_straw.lua` and
-- `nodes_historic.lua`, the window shutters of `nodes_doorlike.lua`, the barrel
-- and tub meshes of `nodes_barrel.lua`, and the bench / table / shelf /
-- washing place / anvil nodeboxes of `nodes_furniture.lua` / `nodes_anvil.lua`.
--
-- What is NOT harvested, and why:
--   * everything that uses `cottages_rope.png` (`nodes_mining.lua`: rope,
--     ladder_with_rope_and_rail) -- that texture's licence is "CC" with no
--     version or variant, i.e. unverified (asset audit 2026-09-14, finding 8);
--   * the `feldweg` dirt-road mesh set (`nodes_feldweg.lua`);
--   * threshing floor, hand mill, chests, beds and sleeping mats -- those are
--     mechanics (formspecs, inventories, HUDs, sleep handling);
--   * the pitchfork (a tool), the fences and the `wool` fallback node;
--   * every `register_craft` and every `register_abm` / `on_rightclick` /
--     `on_punch` hook of the harvested nodes.
--
-- GRUG PATCH: the window shutters are STATIC nodes here. Upstream swaps them
-- on right-click and via a day/night ABM; both are dropped, and the closed
-- shutter loses its `not_in_creative_inventory`/`drop` so that a generator can
-- place either state directly. The barrel/tub nodes likewise lose their
-- punch/right-click state machine, and every barrel state is separately
-- placeable.
-- GRUG PATCH: the `sleeping_mat`, `animates_player` and `hay` dispatch groups
-- are dropped -- these nodes carry plain hardness groups only.

local sounds_wood = default.node_sound_wood_defaults()
local sounds_dirt = default.node_sound_dirt_defaults()
local sounds_stone = default.node_sound_stone_defaults()
local sounds_leaves = default.node_sound_leaves_defaults()

local tex_straw = "grug_decor_cottages_cottages_darkage_straw.png"
local tex_reet = "grug_decor_cottages_cottages_reet.png"
local tex_slate = "grug_decor_cottages_cottages_slate.png"
local tex_loam = "grug_decor_cottages_cottages_loam.png"
local tex_clay = "grug_decor_cottages_cottages_clay.png"
local tex_wood = "grug_decor_cottages_cottages_minimal_wood.png"
-- The two textures cottages does not ship and expects from a `default` mod.
-- Both are present in mods/BASE/default/textures.
local tex_roof_sides = "default_wood.png"
local tex_roof_bark = "default_tree.png"

---------------------------------------------------------------------------
-- Roofs (cottages/nodes_roof.lua `register_roof`)
---------------------------------------------------------------------------

local roof_box = {
	{-0.5, -0.5, -0.5, 0.5, 0, 0},
	{-0.5, 0, 0, 0.5, 0.5, 0.5},
}

local roof_connector_box = {
	{-0.5, -0.5, -0.5, 0.5, 0, 0.5},
	{-0.5, 0, 0, 0.5, 0.5, 0.5},
}

local roof_flat_box = {
	{-0.5, -0.5, -0.5, 0.5, 0, 0.5},
}

-- GRUG PATCH: upstream's `register_roof` sets no `sounds`; we pass one per
-- roof material so a straw roof does not sound like stone.
local function register_roof(name, desc, tiles, sounds)
	core.register_node("grug_decor:cottages_roof_" .. name, {
		description = desc .. " Roof",
		drawtype = "nodebox",
		tiles = tiles,
		paramtype = "light",
		paramtype2 = "facedir",
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
		sounds = sounds,
		node_box = {type = "fixed", fixed = roof_box},
		selection_box = {type = "fixed", fixed = roof_box},
		is_ground_content = false,
	})

	core.register_node("grug_decor:cottages_roof_connector_" .. name, {
		description = desc .. " Roof Connector",
		drawtype = "nodebox",
		tiles = tiles,
		paramtype = "light",
		paramtype2 = "facedir",
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
		sounds = sounds,
		node_box = {type = "fixed", fixed = roof_connector_box},
		selection_box = {type = "fixed", fixed = roof_connector_box},
		is_ground_content = false,
	})

	core.register_node("grug_decor:cottages_roof_flat_" .. name, {
		description = desc .. " Roof (flat)",
		drawtype = "nodebox",
		-- upstream: all faces except the underside use the main tile
		tiles = {tiles[1], tiles[2], tiles[1], tiles[1], tiles[1], tiles[1]},
		paramtype = "light",
		paramtype2 = "facedir",
		groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
		sounds = sounds,
		node_box = {type = "fixed", fixed = roof_flat_box},
		selection_box = {type = "fixed", fixed = roof_flat_box},
		is_ground_content = false,
	})
end

register_roof("straw", "Straw",
	{tex_straw, tex_straw, tex_straw, tex_straw, tex_straw, tex_straw},
	sounds_leaves)

register_roof("reet", "Reed",
	{tex_reet, tex_reet, tex_reet, tex_reet, tex_reet, tex_reet},
	sounds_leaves)

register_roof("wood", "Wood",
	{tex_roof_bark, tex_roof_sides, tex_roof_sides, tex_roof_sides,
		tex_roof_sides, tex_roof_bark},
	sounds_wood)

register_roof("slate", "Slate",
	{tex_slate, tex_roof_sides, tex_slate, tex_slate, tex_roof_sides, tex_slate},
	sounds_stone)

local tex_shingle_wood = "grug_decor_cottages_cottages_homedecor_shingles_wood.png"
register_roof("shingle_wood", "Wood Shingle",
	{tex_shingle_wood, tex_roof_sides, tex_roof_sides, tex_roof_sides,
		tex_roof_sides, tex_shingle_wood},
	sounds_wood)

local tex_shingle_red = "grug_decor_cottages_cottages_homedecor_shingles_terracotta.png"
register_roof("shingle_red", "Terracotta Shingle",
	{tex_shingle_red, tex_roof_sides, tex_roof_sides, tex_roof_sides,
		tex_roof_sides, tex_shingle_red},
	sounds_stone)

core.register_node("grug_decor:cottages_slate_vertical", {
	description = "Vertical Slate",
	tiles = {tex_slate, tex_roof_sides, tex_slate, tex_slate, tex_roof_sides, tex_slate},
	paramtype2 = "facedir",
	groups = {cracky = 2},
	sounds = sounds_stone,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_reet", {
	description = "Reed for Thatching",
	tiles = {tex_reet},
	groups = {snappy = 3, choppy = 3, oddly_breakable_by_hand = 3, flammable = 3},
	sounds = sounds_leaves,
	is_ground_content = false,
})

---------------------------------------------------------------------------
-- Straw, loam and clay (cottages/nodes_straw.lua, nodes_historic.lua)
---------------------------------------------------------------------------

core.register_node("grug_decor:cottages_straw", {
	drawtype = "normal",
	description = "Straw",
	tiles = {tex_straw},
	groups = {snappy = 2, oddly_breakable_by_hand = 2, flammable = 3},
	sounds = sounds_leaves,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_straw_mat", {
	description = "Layer of Straw",
	drawtype = "nodebox",
	tiles = {tex_straw},
	wield_image = tex_straw,
	inventory_image = tex_straw,
	sunlight_propagates = true,
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = false,
	groups = {snappy = 2, oddly_breakable_by_hand = 2, flammable = 3},
	sounds = sounds_leaves,
	node_box = {
		type = "fixed",
		fixed = {{-0.48, -0.5, -0.48, 0.48, -0.45, 0.48}},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.48, -0.5, -0.48, 0.48, -0.25, 0.48}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_straw_bale", {
	drawtype = "nodebox",
	description = "Straw Bale",
	tiles = {"grug_decor_cottages_cottages_darkage_straw_bale.png"},
	paramtype = "light",
	groups = {snappy = 2, oddly_breakable_by_hand = 2, flammable = 3},
	sounds = sounds_leaves,
	node_box = {
		type = "fixed",
		fixed = {{-0.45, -0.5, -0.45, 0.45, 0.45, 0.45}},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.45, -0.5, -0.45, 0.45, 0.45, 0.45}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_loam", {
	description = "Loam",
	tiles = {tex_loam},
	groups = {crumbly = 3},
	sounds = sounds_dirt,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_straw_ground", {
	description = "Straw Ground for Animals",
	tiles = {tex_straw, tex_loam, tex_loam, tex_loam, tex_loam, tex_loam},
	groups = {crumbly = 3},
	sounds = sounds_leaves,
	is_ground_content = false,
})

grug_decor.register_shapes("cottages_loam", {
	description = "Loam",
	tiles = {tex_loam},
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_dirt,
})

grug_decor.register_shapes("cottages_clay", {
	description = "Clay",
	tiles = {tex_clay},
	groups = {crumbly = 3},
	sounds = sounds_dirt,
})

---------------------------------------------------------------------------
-- Windows, planks and tent cloth (cottages/nodes_historic.lua)
---------------------------------------------------------------------------

local tex_pane = "grug_decor_cottages_cottages_glass_pane.png"

core.register_node("grug_decor:cottages_glass_pane", {
	description = "Simple Glass Pane (centered)",
	drawtype = "nodebox",
	tiles = {tex_pane},
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.05, 0.5, 0.5, 0.05}},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.05, 0.5, 0.5, 0.05}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_glass_pane_side", {
	description = "Simple Glass Pane",
	drawtype = "nodebox",
	tiles = {tex_pane},
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.40, 0.5, 0.5, -0.50}},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.40, 0.5, 0.5, -0.50}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_wood_flat", {
	description = "Flat Wooden Planks",
	drawtype = "nodebox",
	tiles = {tex_wood},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.50, 0.5, -0.5 + 1 / 16, 0.50}},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.50, 0.5, -0.5 + 1 / 16, 0.50}},
	},
	is_ground_content = false,
	on_place = core.rotate_node,
})

core.register_node("grug_decor:cottages_wool_tent", {
	description = "Wool for Tents",
	drawtype = "nodebox",
	tiles = {"grug_decor_cottages_cottages_wool.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.50, 0.5, -0.5 + 1 / 16, 0.50}},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.50, 0.5, -0.5 + 1 / 16, 0.50}},
	},
	is_ground_content = false,
	on_place = core.rotate_node,
})

---------------------------------------------------------------------------
-- Window shutters (cottages/nodes_doorlike.lua) -- static, see header note
---------------------------------------------------------------------------

core.register_node("grug_decor:cottages_window_shutter_open", {
	description = "Opened Window Shutters",
	drawtype = "nodebox",
	tiles = {tex_wood},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	-- larger than one node but slightly smaller than a half node so that
	-- wallmounted torches pose no problem (upstream comment)
	node_box = {
		type = "fixed",
		fixed = {
			{-0.90, -0.5, 0.4, -0.45, 0.5, 0.5},
			{0.45, -0.5, 0.4, 0.9, 0.5, 0.5},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.9, -0.5, 0.4, 0.9, 0.5, 0.5}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_window_shutter_closed", {
	description = "Closed Window Shutters",
	drawtype = "nodebox",
	tiles = {tex_wood},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.4, -0.05, 0.5, 0.5},
			{0.05, -0.5, 0.4, 0.5, 0.5, 0.5},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, 0.4, 0.5, 0.5, 0.5}},
	},
	is_ground_content = false,
})

---------------------------------------------------------------------------
-- Wagon parts (cottages/nodes_historic.lua)
---------------------------------------------------------------------------

local wheel_box_side = {-1 / 2, -1 / 2, -1 / 2, -1 / 2 + 1 / 5, 1 / 2, 1 / 2}
local wheel_box_road = {-1, -1 / 2, -1 / 2, -1 / 2 + 1 / 5, 1 / 2, 1 / 2}

-- GRUG PATCH: copies of upstream's local `rotate_to_bottom` / `rotate_to_top`.
local function rotate_to_bottom(b)
	return {b[2], b[1], b[3], b[5], b[4], b[6]}
end

local function rotate_to_top(b)
	return {b[2], -b[4], b[3], b[5], -b[1], b[6]}
end

local tex_wheel = "grug_decor_cottages_cottages_wagonwheel.png"

core.register_node("grug_decor:cottages_wagon_wheel", {
	description = "Wagon Wheel",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_wagonwheel_round_with_axle.obj",
	tiles = {tex_wheel},
	inventory_image = tex_wheel,
	wield_image = tex_wheel,
	paramtype = "light",
	paramtype2 = "wallmounted",
	selection_box = {
		type = "wallmounted",
		wall_side = wheel_box_side,
		wall_top = rotate_to_top(wheel_box_side),
		wall_bottom = rotate_to_bottom(wheel_box_side),
	},
	sunlight_propagates = true,
	walkable = false,
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_wagon_wheel_road", {
	description = "Wagon Wheel (offset for dirt roads)",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_wagonwheel_voxel_crimes.obj",
	tiles = {tex_wheel},
	paramtype = "light",
	paramtype2 = "wallmounted",
	selection_box = {
		type = "wallmounted",
		wall_side = wheel_box_road,
		wall_top = rotate_to_top(wheel_box_road),
		wall_bottom = rotate_to_bottom(wheel_box_road),
	},
	sunlight_propagates = true,
	walkable = false,
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	is_ground_content = false,
})

local wagon_load_box = {
	{-0.5, 0, -0.5, -0.4, 0.5, 0.5}, -- left
	{0.4, 0, -0.5, 0.5, 0.5, 0.5}, -- right
	{-0.5, 0, -0.5, 0.5, 0.1, 0.5}, -- bottom
}

core.register_node("grug_decor:cottages_wagon_load", {
	description = "Wagon Load",
	drawtype = "nodebox",
	tiles = {"default_wood.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {type = "fixed", fixed = wagon_load_box},
	selection_box = {type = "fixed", fixed = wagon_load_box},
	is_ground_content = false,
})

---------------------------------------------------------------------------
-- Barrels and tub (cottages/nodes_barrel.lua) -- static, see header note
---------------------------------------------------------------------------

local tex_barrel = "grug_decor_cottages_cottages_barrel.png"
local barrel_groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2}

core.register_node("grug_decor:cottages_barrel", {
	description = "Barrel (closed)",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_barrel_closed.obj",
	tiles = {tex_barrel},
	groups = barrel_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_barrel_open", {
	description = "Barrel (open)",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_barrel.obj",
	tiles = {tex_barrel},
	groups = barrel_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_barrel_lying", {
	description = "Barrel (closed), lying",
	paramtype = "light",
	paramtype2 = "facedir",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_barrel_closed_lying.obj",
	tiles = {tex_barrel},
	groups = barrel_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_barrel_lying_open", {
	description = "Barrel (open), lying",
	paramtype = "light",
	paramtype2 = "facedir",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_barrel_lying.obj",
	tiles = {tex_barrel},
	groups = barrel_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_tub", {
	description = "Tub",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "grug_decor_cottages_cottages_tub.obj",
	tiles = {tex_barrel},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.5, 0.5, -0.1, 0.5}},
	},
	collision_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.5, 0.5, -0.1, 0.5}},
	},
	groups = barrel_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

---------------------------------------------------------------------------
-- Furniture (cottages/nodes_furniture.lua, nodes_anvil.lua)
---------------------------------------------------------------------------

core.register_node("grug_decor:cottages_bench", {
	drawtype = "nodebox",
	description = "Simple Wooden Bench",
	tiles = {tex_wood},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 1, choppy = 2, oddly_breakable_by_hand = 2, flammable = 3},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {
			-- sitting area
			{-0.5, -0.15, 0.1, 0.5, -0.05, 0.5},
			-- legs
			{-0.4, -0.5, 0.2, -0.3, -0.15, 0.4},
			{0.3, -0.5, 0.2, 0.4, -0.15, 0.4},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, 0, 0.5, 0, 0.5}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_table", {
	description = "Table",
	drawtype = "nodebox",
	tiles = {tex_wood},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.1, -0.5, -0.1, 0.1, 0.3, 0.1},
			{-0.5, 0.48, -0.5, 0.5, 0.4, 0.5},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.5, 0.5, 0.4, 0.5}},
	},
	is_ground_content = false,
})

core.register_node("grug_decor:cottages_shelf", {
	description = "Open Storage Shelf",
	drawtype = "nodebox",
	tiles = {tex_wood},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_wood,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.3, -0.4, 0.5, 0.5},
			{0.4, -0.5, -0.3, 0.5, 0.5, 0.5},
			{-0.5, -0.2, -0.3, 0.5, -0.1, 0.5},
			{-0.5, 0.3, -0.3, 0.5, 0.4, 0.5},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}},
	},
	is_ground_content = false,
})

local washing_box = {
	{-0.5, -0.5, -0.5, 0.5, -0.2, -0.2},
	{-0.5, -0.5, -0.2, -0.4, 0.2, 0.5},
	{0.4, -0.5, -0.2, 0.5, 0.2, 0.5},
	{-0.4, -0.5, 0.4, 0.4, 0.2, 0.5},
	{-0.4, -0.5, -0.2, 0.4, 0.2, -0.1},
}

core.register_node("grug_decor:cottages_washing", {
	description = "Washing Place",
	drawtype = "nodebox",
	tiles = {tex_clay},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 2},
	sounds = sounds_stone,
	node_box = {type = "fixed", fixed = washing_box},
	selection_box = {
		type = "fixed",
		fixed = {{-0.5, -0.5, -0.5, 0.5, 0.2, 0.5}},
	},
	is_ground_content = false,
})

local anvil_box = {
	{-0.5, -0.5, -0.3, 0.5, -0.4, 0.3},
	{-0.35, -0.4, -0.25, 0.35, -0.3, 0.25},
	{-0.3, -0.3, -0.15, 0.3, -0.1, 0.15},
	{-0.35, -0.1, -0.2, 0.35, 0.1, 0.2},
}

core.register_node("grug_decor:cottages_anvil", {
	drawtype = "nodebox",
	description = "Anvil",
	tiles = {"grug_decor_cottages_cottages_stone.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {cracky = 2},
	sounds = sounds_stone,
	-- the nodebox model comes from realtest (upstream comment)
	node_box = {type = "fixed", fixed = anvil_box},
	selection_box = {type = "fixed", fixed = anvil_box},
	is_ground_content = false,
})
