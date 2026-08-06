-- Signature surface nodes (WP18, docs/design/biomes_mobs.md §1.3).
--
-- Every race/wild biome that cannot be expressed with a minetest_game top
-- node gets its own one here. Besides the visual identity these nodes exist
-- FOR the Lord-of-the-Test spawn trick (biomes_mobs.md §4): mob spawning is
-- gated on a node whitelist, which is precise and costs nothing at runtime.
--
-- All textures are cheap retints of vendored minetest_game textures
-- (CC BY-SA 3.0) -- see LICENSE-media.md for attribution and the exact
-- ImageMagick operations.
--
-- WP18 registers the nodes only; grug_mapgen (T4) wires them into the biome
-- definitions. The mod exposes no API, so it declares no global table.

-- Groups shared by the whole dirt family.
--
-- `spreading_dirt_type` is deliberately ABSENT: default's "Grass spread"
-- and "Grass covered" ABMs (default/functions.lua) act on exactly that
-- group, so our tops are never converted into -- or out of -- default
-- grass, which would erase the biome signature the spawn whitelist relies
-- on. `soil = 1` is kept (every default dirt/litter node has it) because
-- `default.can_grow()` refuses to grow a sapling unless the node below is
-- in group `soil`; without it no tree could ever grow on an elf-forest or
-- bone-forest floor.
local function dirt_groups(extra)
	local groups = {crumbly = 3, soil = 1}
	if extra then
		for k, v in pairs(extra) do
			groups[k] = v
		end
	end
	return groups
end

local litter_sounds = default.node_sound_dirt_defaults({
	footstep = {name = "default_grass_footstep", gain = 0.4},
})

-- Dirt with a litter layer on top: litter tile on top, plain dirt at the
-- bottom, dirt + litter overlay on the sides (same tile setup default uses
-- for its coniferous/rainforest litter). Drops plain dirt like default's.
local function register_litter(name, description, texture)
	core.register_node("grug_nodes:" .. name, {
		description = description,
		tiles = {
			texture .. ".png",
			"default_dirt.png",
			{name = "default_dirt.png^" .. texture .. "_side.png",
				tileable_vertical = false},
		},
		groups = dirt_groups(),
		drop = "default:dirt",
		sounds = litter_sounds,
	})
end

--
-- Dirt family
--

core.register_node("grug_nodes:blight_dirt", {
	description = "Blight Dirt",
	tiles = {"grug_nodes_blight_dirt.png"},
	groups = dirt_groups(),
	sounds = default.node_sound_dirt_defaults(),
})

register_litter("dirt_with_bone_litter", "Dirt with Bone Litter",
	"grug_nodes_bone_litter")
register_litter("dirt_with_forest_litter", "Dirt with Forest Litter",
	"grug_nodes_forest_litter")
register_litter("dirt_with_silver_litter", "Dirt with Silver Litter",
	"grug_nodes_silver_litter")

-- Swamp mud. `mud = 1` is a MARKER GROUP only -- the walking slow-down
-- described in docs/design/biomes_mobs.md §1.3 is NOT implemented in WP18;
-- a later WP adds the player-movement handler and dispatches on this group.
core.register_node("grug_nodes:mud", {
	description = "Swamp Mud",
	tiles = {"grug_nodes_mud.png"},
	groups = dirt_groups({mud = 1}),
	sounds = default.node_sound_dirt_defaults(),
})

--
-- Stone-ish
--

-- Badlands surface: hardened clay, so harder than dirt and it drops itself
-- instead of clay lumps (it is a building material, not a clay source).
core.register_node("grug_nodes:mesa_clay", {
	description = "Mesa Clay",
	tiles = {"grug_nodes_mesa_clay.png"},
	groups = {cracky = 3, crumbly = 2},
	sounds = default.node_sound_dirt_defaults(),
})

--
-- Decoration
--

-- Purely decorative bone heap for the blight/bone forest ground cover:
-- not walkable, replaceable by anything and it drops nothing.
core.register_node("grug_nodes:bone_pile", {
	description = "Bone Pile",
	drawtype = "plantlike",
	tiles = {"grug_nodes_bone_pile.png"},
	inventory_image = "grug_nodes_bone_pile.png",
	wield_image = "grug_nodes_bone_pile.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	floodable = true,
	is_ground_content = false,
	drop = "",
	selection_box = {
		type = "fixed",
		fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, 1 / 16, 6 / 16},
	},
	groups = {snappy = 3, attached_node = 1},
	sounds = default.node_sound_gravel_defaults(),
})
