-- Round 51 lane LP: the land plants the user picked in the land viewer
-- (tools/r47_sw/land.js ITEMS, land plan §4; art ARTL, tools/r51_land/plants).
--
-- Every plant here is decoration (round plan §3.6): it drops nothing, like
-- the bone pile and the hanging moss, so a player never mistakes one for a
-- gathering source (land plan ruling 11) and never carries a stack of them.
-- None glows (ruling 10). The world generator places them as decoration rows
-- (wp40/r7_r6_manifest.lua, the Round 51 LP block) and the wild renewal
-- brings them back (grug_farming/renewal.lua through the vegetation
-- authority, ruling 18). The jungle's lianas are grug_trees' (they belong to
-- their trees).

-- A small plant on the ground: plantlike, not walkable, anything may be built
-- into it, it goes with its ground. `low` (sixteenths): the height of its
-- selection box above the node's floor.
local function ground_plant(name, description, texture, low)
	core.register_node("grug_nodes:" .. name, {
		description = description,
		drawtype = "plantlike",
		waving = 1,
		tiles = {texture},
		inventory_image = texture,
		wield_image = texture,
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		is_ground_content = false,
		drop = "",
		selection_box = {type = "fixed",
			fixed = {-5 / 16, -0.5, -5 / 16, 5 / 16, -0.5 + low / 16, 5 / 16}},
		groups = {snappy = 3, flammable = 2, attached_node = 1},
		sounds = default.node_sound_leaves_defaults(),
	})
end

-- Flowers (ruling 11): three in strong colours for the jungle, three in
-- pastels for the elves.
ground_plant("flower_ruby_fan", "Ruby Fan", "grug_nodes_flower_ruby_fan.png", 10)
ground_plant("flower_ember_star", "Ember Star", "grug_nodes_flower_ember_star.png", 10)
ground_plant("flower_violet_fan", "Violet Fan", "grug_nodes_flower_violet_fan.png", 10)
ground_plant("flower_blush_star", "Blush Star", "grug_nodes_flower_blush_star.png", 10)
ground_plant("flower_lilac_bells", "Lilac Bells", "grug_nodes_flower_lilac_bells.png", 10)
ground_plant("flower_cream_cups", "Cream Cups", "grug_nodes_flower_cream_cups.png", 10)
-- Small alpine plants of the crags (the art fills the lowest seven rows).
ground_plant("alpine_cushion", "Alpine Cushion", "grug_nodes_alpine_cushion.png", 7)
ground_plant("alpine_windshrub", "Alpine Windshrub", "grug_nodes_alpine_windshrub.png", 7)

-- Lichen: a crust on gravel and stone, a carpet 1/16 high like the moss
-- carpet, in two variants (the generator alternates them); its texture is
-- mostly open, so the ground shows through (alpha clip).
local function lichen(name, texture)
	core.register_node("grug_nodes:" .. name, {
		description = "Lichen",
		drawtype = "nodebox",
		tiles = {texture},
		inventory_image = texture,
		wield_image = texture,
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		floodable = true,
		is_ground_content = false,
		drop = "",
		node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -7 / 16, 0.5}},
		groups = {snappy = 3, attached_node = 3, flammable = 2},
		sounds = default.node_sound_leaves_defaults(),
	})
end
lichen("lichen_carpet", "grug_nodes_lichen_carpet_top.png")
lichen("lichen_carpet_b", "grug_nodes_lichen_carpet_top_b.png")

-- Bush foliage on the default bush shapes: the jungle's large-leaved bush
-- (bush.mts) and the badlands' withered bush (acacia_bush.mts). The leaves
-- drop nothing (no sapling grows these bushes); the stems stay default's
-- and drop themselves. They decay with their stem like the default bush
-- leaves (radius 1); default.register_leafdecay replaces a stem's
-- after_destruct, so each stem lists its default leaves too.
local function bush_leaves(name, description, texture)
	core.register_node("grug_nodes:" .. name, {
		description = description,
		drawtype = "allfaces_optional",
		waving = 1,
		tiles = {texture},
		paramtype = "light",
		is_ground_content = false,
		drop = "",
		groups = {snappy = 3, flammable = 2, leaves = 1},
		sounds = default.node_sound_leaves_defaults(),
		after_place_node = default.after_place_leaves,
	})
end
bush_leaves("jungle_bush_leaves", "Jungle Bush Leaves", "grug_nodes_jungle_bush_leaves.png")
bush_leaves("withered_bush_leaves", "Withered Bush Leaves", "grug_nodes_withered_bush_leaves.png")
default.register_leafdecay({
	trunks = {"default:bush_stem"},
	leaves = {"default:bush_leaves", "grug_nodes:jungle_bush_leaves"},
	radius = 1,
})
default.register_leafdecay({
	trunks = {"default:acacia_bush_stem"},
	leaves = {"default:acacia_bush_leaves", "grug_nodes:withered_bush_leaves"},
	radius = 1,
})

-- Ferns and marram grass are default's nodes; as decoration (§3.6) they
-- drop nothing, wherever they grow.
for i = 1, 3 do
	core.override_item("default:fern_" .. i, {drop = ""})
	core.override_item("default:marram_grass_" .. i, {drop = ""})
end
