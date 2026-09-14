-- Harvested from xdecor-libre (codeberg.org/Wuzzy/xdecor-libre),
-- BSD-3-Clause code, CC0 textures (with named exceptions that we do not use).
-- Upstream commit: see VENDOR.md.
--
-- What is harvested: the interior-prop layer -- barrel, chair, table, cushion,
-- curtain, lantern (+ hanging), candle, potted plants, paintings, stone path,
-- wood-framed glass, ivy, cobweb, item frame, rope, work bench, cauldron and
-- the plain shelf.
--
-- What is NOT harvested, and why:
--   * chess, enchanting, cooking, mailbox, hive, mechanisms, the enderchest and
--     the trampoline -- mechanics (formspecs, inventories, timers, entities);
--   * radio and speaker -- their textures are the LICENSE.txt CC BY 4.0
--     exception and we do not need them;
--   * the `xpanes`-based panes and the japanese/etc. doors -- neither `xpanes`
--     nor `doors` is vendored in this game;
--   * every `register_craft`, every `xdecor.register` behaviour hook
--     (sitting, curtain toggling, lantern floor/ceiling placement, painting
--     randomisation, item-frame handling, rope unrolling) and both upstream
--     LBMs.
--
-- GRUG PATCH: `xdecor.register` derives `drawtype` / `paramtype` /
-- `paramtype2` / `sunlight_propagates` from the rest of the definition. Those
-- derived values are spelled out here so the shipped nodes need no registrar,
-- and so a static reader (tools/wp13/extract_tiles.py) sees them.
-- GRUG PATCH: the dispatch and physics groups `sittable`, `plant`, `flower`,
-- `potted_flower`, `cauldron`, `fall_damage_add_percent` and the cobweb's
-- `move_resistance` are dropped -- these nodes are decorative only.
-- GRUG PATCH: every state node upstream hides (the open curtain, the hanging
-- lantern, paintings 2-4) loses its `not_in_creative_inventory`/`drop` pair, so
-- a settlement generator can place each state directly.
-- GRUG PATCH: the curtain's base texture is xdecor's own CC0 `xdecor_cushion`
-- cloth instead of upstream's `wool_red.png`; the `wool` mod is not vendored.

local sounds_wood = default.node_sound_wood_defaults()
local sounds_stone = default.node_sound_stone_defaults()
local sounds_metal = default.node_sound_metal_defaults()
local sounds_glass = default.node_sound_glass_defaults()
local sounds_leaves = default.node_sound_leaves_defaults()
local sounds_default = default.node_sound_defaults()

local function tex(name)
	return "grug_decor_xdecor_xdecor_" .. name .. ".png"
end

-- GRUG PATCH: copy of `xdecor.pixelbox` (xdecor-libre/handlers/nodeboxes.lua).
local function pixelbox(size, boxes)
	local fixed = {}
	for _, box in ipairs(boxes) do
		local x, y, z, w, h, l = unpack(box)
		fixed[#fixed + 1] = {
			(x / size) - 0.5,
			(y / size) - 0.5,
			(z / size) - 0.5,
			((x + w) / size) - 0.5,
			((y + h) / size) - 0.5,
			((z + l) / size) - 0.5,
		}
	end
	return {type = "fixed", fixed = fixed}
end

-- GRUG PATCH: copy of `xdecor.box.slab_y` wrapped as a node box.
local function slab_y(height, shift)
	return {
		type = "fixed",
		fixed = {-0.5, -0.5 + (shift or 0), -0.5, 0.5, -0.5 + height + (shift or 0), 0.5},
	}
end

---------------------------------------------------------------------------
-- Furniture and containers
---------------------------------------------------------------------------

core.register_node("grug_decor:xdecor_barrel", {
	description = "Barrel",
	tiles = {tex("barrel_top"), tex("barrel_top"), tex("barrel_sides")},
	paramtype2 = "facedir",
	on_place = core.rotate_node,
	groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
	is_ground_content = false,
	sounds = sounds_wood,
})

core.register_node("grug_decor:xdecor_chair", {
	description = "Chair",
	drawtype = "nodebox",
	tiles = {tex("wood")},
	paramtype = "light",
	paramtype2 = "facedir",
	sounds = sounds_wood,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2},
	is_ground_content = false,
	node_box = pixelbox(16, {
		{3, 0, 11, 2, 16, 2},
		{11, 0, 11, 2, 16, 2},
		{5, 9, 11.5, 6, 6, 1},
		{3, 0, 3, 2, 6, 2},
		{11, 0, 3, 2, 6, 2},
		{3, 6, 3, 10, 2, 8},
	}),
})

core.register_node("grug_decor:xdecor_table", {
	description = "Table",
	drawtype = "nodebox",
	tiles = {tex("wood")},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
	is_ground_content = false,
	sounds = sounds_wood,
	node_box = pixelbox(16, {
		{0, 14, 0, 16, 2, 16},
		{5.5, 0, 5.5, 5, 14, 6},
	}),
})

core.register_node("grug_decor:xdecor_cushion", {
	description = "Cushion",
	drawtype = "nodebox",
	tiles = {tex("cushion")},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 3, flammable = 3},
	is_ground_content = false,
	sounds = sounds_default,
	on_place = core.rotate_node,
	node_box = slab_y(0.5),
})

core.register_node("grug_decor:xdecor_cushion_block", {
	description = "Cushion Block",
	tiles = {tex("cushion")},
	paramtype2 = "facedir",
	groups = {snappy = 3, flammable = 3},
	is_ground_content = false,
	sounds = sounds_default,
})

core.register_node("grug_decor:xdecor_workbench", {
	description = "Work Bench",
	tiles = {
		tex("workbench_top"), tex("workbench_bottom"),
		tex("workbench_sides"), tex("workbench_sides"),
		tex("workbench_front"), tex("workbench_front"),
	},
	paramtype2 = "facedir",
	groups = {cracky = 2, choppy = 2, oddly_breakable_by_hand = 1},
	is_ground_content = false,
	sounds = sounds_wood,
})

core.register_node("grug_decor:xdecor_cauldron", {
	description = "Cauldron",
	tiles = {
		tex("cauldron_top_empty"), tex("cauldron_bottom"), tex("cauldron_sides"),
	},
	paramtype2 = "facedir",
	groups = {cracky = 2, oddly_breakable_by_hand = 1},
	is_ground_content = false,
	sounds = sounds_metal,
	collision_box = pixelbox(16, {
		{0, 0, 0, 16, 16, 0},
		{0, 0, 16, 16, 16, 0},
		{0, 0, 0, 0, 16, 16},
		{16, 0, 0, 0, 16, 16},
		{0, 0, 0, 16, 8, 16},
	}),
})

core.register_node("grug_decor:xdecor_empty_shelf", {
	description = "Plain Shelf",
	tiles = {
		"default_wood.png", "default_wood.png", "default_wood.png",
		"default_wood.png", "default_wood.png^" .. tex("empty_shelf"),
	},
	use_texture_alpha = "opaque",
	paramtype2 = "facedir",
	groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
	is_ground_content = false,
	sounds = sounds_wood,
})

core.register_node("grug_decor:xdecor_itemframe", {
	description = "Item Frame",
	drawtype = "nodebox",
	tiles = {
		tex("wood"), tex("wood"), tex("wood"),
		tex("wood"), tex("wood"), tex("itemframe"),
	},
	inventory_image = tex("itemframe"),
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3},
	is_ground_content = false,
	sounds = sounds_wood,
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5 + 0.9375, 0.5, 0.5, 0.5}},
})

---------------------------------------------------------------------------
-- Curtains (two static states)
---------------------------------------------------------------------------

local curtain_base = tex("cushion")
local curtain_open_tile = curtain_base .. "^" .. tex("curtain_open_overlay") ..
	"^[makealpha:255,126,126"
local curtain_offset = 1 / 16
local curtain_box = {
	type = "wallmounted",
	wall_side = {-0.5, -0.5, -0.5, -0.5 + curtain_offset, 0.5, 0.5},
	wall_top = {-0.5, 0.5 - curtain_offset, -0.5, 0.5, 0.5, 0.5},
	wall_bottom = {-0.5, -0.5, -0.5, 0.5, -0.5 + curtain_offset, 0.5},
}

core.register_node("grug_decor:xdecor_curtain", {
	description = "Curtain",
	drawtype = "nodebox",
	walkable = false,
	tiles = {curtain_base, "(" .. curtain_base .. ")^[transformFY", curtain_base},
	use_texture_alpha = "clip",
	inventory_image = curtain_open_tile,
	wield_image = curtain_open_tile,
	paramtype = "light",
	paramtype2 = "wallmounted",
	node_box = curtain_box,
	groups = {dig_immediate = 3, flammable = 3},
	is_ground_content = false,
	sounds = sounds_default,
})

core.register_node("grug_decor:xdecor_curtain_open", {
	description = "Open Curtain",
	drawtype = "nodebox",
	walkable = false,
	tiles = {
		curtain_open_tile,
		"(" .. curtain_open_tile .. ")^[transformFY",
		curtain_base,
		curtain_base,
		curtain_base .. "^" .. tex("curtain_open_overlay_top") .. "^[makealpha:255,126,126",
		curtain_base .. "^" .. tex("curtain_open_overlay_bottom") .. "^[makealpha:255,126,126",
	},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "wallmounted",
	node_box = curtain_box,
	groups = {dig_immediate = 3, flammable = 3},
	is_ground_content = false,
	sounds = sounds_default,
})

---------------------------------------------------------------------------
-- Lights (static: no placement logic, no state changes)
---------------------------------------------------------------------------

local lantern_tiles = {
	{name = tex("lantern"), animation = {type = "vertical_frames", length = 1.5}},
}

core.register_node("grug_decor:xdecor_lantern", {
	description = "Lantern",
	light_source = 13,
	drawtype = "plantlike",
	inventory_image = tex("lantern_inv"),
	wield_image = tex("lantern_inv"),
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = {snappy = 3, attached_node = 3},
	is_ground_content = false,
	tiles = lantern_tiles,
	selection_box = pixelbox(16, {{4, 0, 4, 8, 16, 8}}),
	sounds = sounds_metal,
})

core.register_node("grug_decor:xdecor_lantern_hanging", {
	description = "Hanging Lantern",
	light_source = 13,
	drawtype = "plantlike",
	inventory_image = tex("lantern_inv") .. "^" .. tex("lantern_hanging_overlay_inv"),
	wield_image = tex("lantern_inv"),
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = {snappy = 3, attached_node = 4},
	is_ground_content = false,
	tiles = lantern_tiles,
	selection_box = pixelbox(16, {{4, 0, 4, 8, 16, 8}}),
	sounds = sounds_metal,
})

core.register_node("grug_decor:xdecor_candle", {
	description = "Candle",
	light_source = 12,
	drawtype = "torchlike",
	inventory_image = tex("candle_inv"),
	wield_image = tex("candle_wield"),
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	walkable = false,
	groups = {dig_immediate = 3, attached_node = 1},
	is_ground_content = false,
	sounds = sounds_default,
	tiles = {
		{name = tex("candle_floor"), animation = {type = "vertical_frames", length = 1.5}},
		{name = tex("candle_hanging"), animation = {type = "vertical_frames", length = 1.5}},
		{name = tex("candle_wall"), animation = {type = "vertical_frames", length = 1.5}},
	},
	selection_box = {
		type = "wallmounted",
		wall_top = {-0.25, -0.3, -0.25, 0.25, 0.5, 0.25},
		wall_bottom = {-0.25, -0.5, -0.25, 0.25, 0.1, 0.25},
		wall_side = {-0.5, -0.35, -0.15, -0.15, 0.4, 0.15},
	},
})

---------------------------------------------------------------------------
-- Potted plants
---------------------------------------------------------------------------

local potted = {
	{"dandelion_white", "Potted White Dandelion"},
	{"dandelion_yellow", "Potted Yellow Dandelion"},
	{"geranium", "Potted Blue Geranium"},
	{"rose", "Potted Red Rose"},
	{"tulip", "Potted Orange Tulip"},
	{"viola", "Potted Viola"},
	{"tulip_black", "Potted Black Tulip"},
	{"chrysanthemum_green", "Potted Green Chrysanthemum"},
}

for _, p in ipairs(potted) do
	local image = tex(p[1] .. "_pot")
	core.register_node("grug_decor:xdecor_potted_" .. p[1], {
		description = p[2],
		drawtype = "plantlike",
		tiles = {image},
		inventory_image = image,
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		groups = {snappy = 3, flammable = 3},
		is_ground_content = false,
		sounds = sounds_leaves,
		selection_box = slab_y(0.3),
	})
end

---------------------------------------------------------------------------
-- Paintings (four static variants)
---------------------------------------------------------------------------

local painting_box = {
	type = "wallmounted",
	wall_top = {-0.4375, 0.4375, -0.3125, 0.4375, 0.5, 0.3125},
	wall_bottom = {-0.4375, -0.5, -0.3125, 0.4375, -0.4375, 0.3125},
	wall_side = {-0.5, -0.3125, -0.4375, -0.4375, 0.3125, 0.4375},
}

for i = 1, 4 do
	local image = tex("painting_" .. i)
	core.register_node("grug_decor:xdecor_painting_" .. i, {
		description = "Painting " .. i,
		drawtype = "nodebox",
		tiles = {image, image .. "^[transformR180", image},
		use_texture_alpha = "opaque",
		inventory_image = tex("painting_empty"),
		wield_image = tex("painting_empty"),
		paramtype = "light",
		paramtype2 = "wallmounted",
		wallmounted_rotate_vertical = true,
		sunlight_propagates = true,
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, attached_node = 1},
		is_ground_content = false,
		sounds = sounds_wood,
		node_box = painting_box,
	})
end

---------------------------------------------------------------------------
-- Outdoor props
---------------------------------------------------------------------------

core.register_node("grug_decor:xdecor_stonepath", {
	description = "Garden Stone Path",
	drawtype = "nodebox",
	tiles = {"default_stone.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	groups = {snappy = 3},
	is_ground_content = false,
	sounds = sounds_stone,
	node_box = pixelbox(16, {
		{8, 0, 8, 6, .5, 6}, {1, 0, 1, 6, .5, 6},
		{1, 0, 10, 5, .5, 5}, {10, 0, 2, 4, .5, 4},
	}),
	selection_box = slab_y(0.05),
})

core.register_node("grug_decor:xdecor_woodframed_glass", {
	description = "Wood Framed Glass",
	drawtype = "glasslike_framed",
	paramtype = "light",
	sunlight_propagates = true,
	tiles = {tex("woodframed_glass"), tex("woodframed_glass_detail")},
	use_texture_alpha = "clip",
	groups = {cracky = 2, oddly_breakable_by_hand = 1},
	is_ground_content = false,
	sounds = sounds_glass,
})

core.register_node("grug_decor:xdecor_ivy", {
	description = "Ivy",
	drawtype = "signlike",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	walkable = false,
	climbable = true,
	groups = {snappy = 3, attached_node = 1, flammable = 3},
	is_ground_content = false,
	selection_box = {type = "wallmounted"},
	tiles = {tex("ivy")},
	inventory_image = tex("ivy"),
	wield_image = tex("ivy"),
	sounds = sounds_leaves,
})

core.register_node("grug_decor:xdecor_cobweb", {
	description = "Cobweb",
	drawtype = "plantlike",
	paramtype = "light",
	sunlight_propagates = true,
	tiles = {tex("cobweb")},
	inventory_image = tex("cobweb"),
	walkable = false,
	selection_box = {type = "regular"},
	groups = {snappy = 3, flammable = 3},
	is_ground_content = false,
	sounds = sounds_leaves,
})

core.register_node("grug_decor:xdecor_rope", {
	description = "Rope",
	drawtype = "plantlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	climbable = true,
	groups = {dig_immediate = 3, flammable = 3},
	is_ground_content = false,
	tiles = {tex("rope")},
	inventory_image = tex("rope_inv"),
	wield_image = tex("rope_inv"),
	selection_box = pixelbox(8, {{3, 0, 3, 2, 8, 2}}),
	sounds = sounds_leaves,
})
