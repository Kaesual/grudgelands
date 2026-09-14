-- Harvested from darkage (github.com/adrido/darkage), MIT code, CC0 graphics.
-- Upstream commit: see VENDOR.md.
--
-- What is harvested: the pre-industrial stone family and its brick/block/cobble
-- variants, adobe, mud, straw bale, the reinforced-wood set, the medieval glass
-- family, the connected walls of `walls.lua`, and the stair/slab shapes that
-- `stairs.lua` registers for the harvested materials.
--
-- What is NOT harvested, and why:
--   * `mapgen.lua` in full (ore and stratum placement) -- WP40 R7 owns the
--     world and registers zero Lua ores/decorations;
--   * the craftitems (chalk powder, mud lump, silt lump, iron stick) and every
--     `register_craft`;
--   * `furniture.lua`'s box and shelves (formspecs + inventories), the lamp and
--     the glow-glass family (light sources, not building material), and the
--     milk glasses (they need `unifieddyes`, which is GPL-2.0-only and must
--     never be vendored);
--   * the tuff / rhyolitic tuff / gneiss / schist / shale / silt / dark dirt
--     nodes: not in the harvest list and, for tuff, gated behind a weathering
--     ABM upstream;
--   * the `cobble_with_plaster` -> `chalked_bricks_with_plaster` conversion LBM
--     and the tuff weathering ABM.
--
-- Upstream also declares nodes `darkage:darkwood` and `darkage:mud_brick`
-- nowhere in the tree at this commit; the nearest harvested equivalents are
-- `grug_decor:darkage_mud`, `grug_decor:darkage_adobe` and
-- `grug_decor:darkage_reinforced_wood`. See the work-package report.
--
-- GRUG PATCH: every upstream `drop` is dropped with the crafts -- they name
-- craftitems (`darkage:chalk_powder`, `darkage:mud_lump`, ...) and
-- `farming:straw`, none of which this game has; the nodes now drop themselves.
-- GRUG PATCH: the `not_cuttable`, `legacy_mineral` and `stone` groups are
-- dropped -- `not_cuttable` is a moreblocks/xdecor marker, `legacy_mineral` is
-- an engine legacy flag that fresh-server mode removes, and the decor copies
-- carry plain hardness groups only.

local sounds_stone = default.node_sound_stone_defaults()
local sounds_dirt = default.node_sound_dirt_defaults()
local sounds_sand = default.node_sound_sand_defaults()
local sounds_wood = default.node_sound_wood_defaults()
local sounds_leaves = default.node_sound_leaves_defaults()
local sounds_glass = default.node_sound_glass_defaults()

local function tex(name)
	return "grug_decor_darkage_darkage_" .. name .. ".png"
end

---------------------------------------------------------------------------
-- Stone family, adobe, mud, straw bale (darkage/nodes.lua)
---------------------------------------------------------------------------

-- name, description, tiles, groups, sounds
local blocks = {
	{"adobe", "Adobe", {tex("adobe")}, {crumbly = 3}, sounds_sand},

	{"basalt", "Basalt", {tex("basalt")}, {cracky = 3}, sounds_stone},
	{"basalt_rubble", "Basalt Rubble", {tex("basalt_rubble")}, {cracky = 3}, sounds_stone},
	{"basalt_brick", "Basalt Brick", {tex("basalt_brick")}, {cracky = 2}, sounds_stone},
	{"basalt_block", "Basalt Block", {tex("basalt_block")}, {cracky = 2}, sounds_stone},

	{"chalk", "Chalk", {tex("chalk")}, {crumbly = 2, cracky = 2}, sounds_stone},
	{"chalked_bricks", "Chalked Brick", {tex("chalked_bricks")}, {cracky = 2}, sounds_stone},

	{"marble", "Marble", {tex("marble")}, {cracky = 3}, sounds_stone},
	{"marble_tile", "Marble Tile", {tex("marble_tile")}, {cracky = 2}, sounds_stone},

	{"ors", "Old Red Sandstone", {tex("ors")}, {cracky = 2}, sounds_stone},
	{"ors_rubble", "Old Red Sandstone Rubble", {tex("ors_rubble")},
		{cracky = 3, crumbly = 2}, sounds_stone},
	{"ors_brick", "Old Red Sandstone Brick", {tex("ors_brick")}, {cracky = 3}, sounds_stone},
	{"ors_block", "Old Red Sandstone Block", {tex("ors_block")}, {cracky = 3}, sounds_stone},

	{"serpentine", "Serpentine", {tex("serpentine")}, {cracky = 3}, sounds_stone},

	{"slate", "Slate", {tex("slate"), tex("slate"), tex("slate_side")},
		{cracky = 2}, sounds_stone},
	{"slate_rubble", "Slate Rubble", {tex("slate_rubble")}, {cracky = 2}, sounds_stone},
	{"slate_brick", "Slate Brick", {tex("slate_brick")}, {cracky = 2}, sounds_stone},
	{"slate_block", "Slate Block", {tex("slate_block")}, {cracky = 2}, sounds_stone},
	{"slate_tile", "Slate Tile", {tex("slate_tile")}, {cracky = 2}, sounds_stone},

	{"stone_brick", "Dark Stone Brick", {tex("stone_brick")}, {cracky = 3}, sounds_stone},

	{"mud", "Mud", {tex("mud_up"), tex("mud")}, {crumbly = 3}, sounds_dirt},

	{"straw_bale", "Straw Bale", {tex("straw_bale")}, {snappy = 2, flammable = 2},
		sounds_leaves},
}

local by_name = {}

for _, b in ipairs(blocks) do
	-- one source-of-truth record per material, kept separate from the table
	-- handed to the engine (which takes ownership of what it is given)
	by_name[b[1]] = {
		description = b[2],
		tiles = b[3],
		groups = b[4],
		sounds = b[5],
	}
	core.register_node("grug_decor:darkage_" .. b[1], {
		description = b[2],
		tiles = table.copy(b[3]),
		groups = table.copy(b[4]),
		sounds = b[5],
		is_ground_content = false,
	})
end

---------------------------------------------------------------------------
-- Stair and slab shapes (the subset of darkage/stairs.lua we harvested)
---------------------------------------------------------------------------

local shaped = {
	"basalt", "basalt_brick", "basalt_rubble", "chalked_bricks",
	"marble", "marble_tile", "ors", "ors_brick", "ors_rubble",
	"serpentine", "slate", "slate_brick", "slate_rubble", "slate_tile",
	"stone_brick", "straw_bale",
}

for _, name in ipairs(shaped) do
	local def = by_name[name]
	grug_decor.register_shapes("darkage_" .. name, {
		description = def.description,
		tiles = def.tiles,
		groups = def.groups,
		sounds = def.sounds,
	})
end

---------------------------------------------------------------------------
-- Reinforced wood (darkage/building.lua `register_reinforce`, "Wood" only)
---------------------------------------------------------------------------

local wood = "default_wood.png"
local reinforce_groups = {snappy = 2, choppy = 3, flammable = 3}

core.register_node("grug_decor:darkage_reinforced_wood", {
	description = "Reinforced Wood",
	tiles = {wood .. "^" .. tex("reinforce")},
	groups = reinforce_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:darkage_reinforced_wood_slope", {
	description = "Reinforced Wood Slope",
	paramtype2 = "facedir",
	tiles = {
		wood .. "^" .. tex("reinforce_right"),
		wood .. "^" .. tex("reinforce_right"),
		wood .. "^" .. tex("reinforce_right"),
		wood .. "^" .. tex("reinforce_right"),
		wood .. "^" .. tex("reinforce_left"),
		wood .. "^" .. tex("reinforce_left"),
	},
	groups = reinforce_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:darkage_reinforced_wood_arrow", {
	description = "Reinforced Wood Arrow",
	paramtype2 = "facedir",
	tiles = {
		wood,
		wood,
		wood .. "^(" .. tex("reinforce_arrow") .. "^[transformR90)",
		wood .. "^(" .. tex("reinforce_arrow") .. "^[transformR270)",
		wood .. "^(" .. tex("reinforce_arrow") .. "^[transformR180)",
		wood .. "^" .. tex("reinforce_arrow"),
	},
	groups = reinforce_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

core.register_node("grug_decor:darkage_reinforced_wood_bars", {
	description = "Wood Bars",
	tiles = {wood .. "^" .. tex("reinforce_bars")},
	groups = reinforce_groups,
	sounds = sounds_wood,
	is_ground_content = false,
})

---------------------------------------------------------------------------
-- Medieval glass, bars and grilles (darkage/glass.lua, darkage/furniture.lua)
---------------------------------------------------------------------------

local glasses = {
	{"glass", "Clean Medieval Glass", tex("glass")},
	{"glass_round", "Round Glass", tex("glass_round")},
	{"glass_square", "Square Glass", tex("glass_square")},
}

for _, g in ipairs(glasses) do
	core.register_node("grug_decor:darkage_" .. g[1], {
		description = g[2],
		drawtype = "glasslike",
		tiles = {g[3]},
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		groups = {cracky = 3, oddly_breakable_by_hand = 3},
		sounds = sounds_glass,
		is_ground_content = false,
	})
end

core.register_node("grug_decor:darkage_wood_frame", {
	description = "Wooden Frame",
	drawtype = "glasslike_framed",
	tiles = {tex("wood_frame")},
	inventory_image = tex("wood_frame"),
	wield_image = tex("wood_frame"),
	paramtype = "light",
	sunlight_propagates = true,
	groups = {snappy = 1, choppy = 2, oddly_breakable_by_hand = 3},
	sounds = sounds_wood,
	is_ground_content = false,
})

local grilles = {
	{"iron_bars", "Iron Bars", tex("iron_bars"), {cracky = 3}, sounds_stone},
	{"iron_grille", "Iron Grille", tex("iron_grille"), {cracky = 3}, sounds_stone},
	{"wood_bars", "Wooden Bars", tex("wood_bars"), {snappy = 1, choppy = 2}, sounds_wood},
	{"wood_grille", "Wooden Grille", tex("wood_grille"), {snappy = 1, choppy = 2}, sounds_wood},
}

for _, g in ipairs(grilles) do
	core.register_node("grug_decor:darkage_" .. g[1], {
		description = g[2],
		drawtype = "glasslike",
		tiles = {g[3]},
		inventory_image = g[3],
		wield_image = g[3],
		paramtype = "light",
		sunlight_propagates = true,
		groups = g[4],
		sounds = g[5],
		is_ground_content = false,
	})
end

---------------------------------------------------------------------------
-- Connected walls (darkage/walls.lua)
---------------------------------------------------------------------------

local wall_box = {
	type = "connected",
	fixed = {{-1 / 4, -1 / 2, -1 / 4, 1 / 4, 1 / 2, 1 / 4}},
	connect_front = {{-3 / 16, -1 / 2, -1 / 2, 3 / 16, 3 / 8, -1 / 4}},
	connect_left = {{-1 / 2, -1 / 2, -3 / 16, -1 / 4, 3 / 8, 3 / 16}},
	connect_back = {{-3 / 16, -1 / 2, 1 / 4, 3 / 16, 3 / 8, 1 / 2}},
	connect_right = {{1 / 4, -1 / 2, -3 / 16, 1 / 2, 3 / 8, 3 / 16}},
}

local function register_wall(base)
	local def = by_name[base]
	local name = "grug_decor:darkage_" .. base .. "_wall"
	local groups = table.copy(def.groups)
	-- `wall` stays: it is the connection group the connected nodebox reads.
	groups.wall = 1
	core.register_node(name, {
		description = def.description .. " Wall",
		drawtype = "nodebox",
		node_box = wall_box,
		connects_to = {"grug_decor:darkage_" .. base, "group:wall"},
		paramtype = "light",
		is_ground_content = false,
		tiles = def.tiles,
		walkable = true,
		groups = groups,
		sounds = def.sounds,
	})
end

register_wall("basalt_rubble")
register_wall("ors_rubble")
register_wall("stone_brick")
register_wall("slate_rubble")
