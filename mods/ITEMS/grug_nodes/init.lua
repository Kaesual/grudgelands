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
	return grug_materials.natural_groups(groups)
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
-- The shaded floor under the closed deep-jungle canopy (WP36, biomes_mobs.md
-- §1.3). It exists because grug_deep_jungle used to SHARE
-- `default:dirt_with_rainforest_litter` with grug_jungle_edge, which made
-- 41 % of the Throng continent a single eligible visual (the whole span
-- x 201..1500) -- the one biome pair in the world that did not have its own
-- top per registration. Same node family, same spawn-whitelist role as the
-- three above; the tint is deliberately colder and darker than
-- `dirt_with_forest_litter` (which is Accord-only, so the two never meet).
register_litter("dirt_with_canopy_litter", "Dirt with Canopy Litter",
	"grug_nodes_canopy_litter")

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
	groups = grug_materials.natural_groups({cracky = 3, crumbly = 2}),
	sounds = default.node_sound_dirt_defaults(),
})

--
-- Decoration
--

-- Guard banner / military standard (WP6, docs/design/world.md §4): the
-- ANCHOR node of a guard post. grug_mapgen places one in the middle of every
-- military outpost pad and one on every race-capital spawn platform; the
-- guards themselves are spawned by the camp mechanism in grug_mobs
-- (camps.lua), which attaches on_construct/on_timer to this node with
-- core.override_item and starts the timer of mapgen-placed banners from an
-- LBM (a VoxelManip write fires no node callbacks).
--
-- The node carries NO callbacks here on purpose: grug_nodes must not depend
-- on grug_mobs (it sits below it in the dependency graph), and the node is
-- perfectly usable content on its own.
--
-- Faction-NEUTRAL by design — no per-faction variant and no param2 colour:
-- which faction a post belongs to follows from WHERE it stands
-- (grug_core.territory_at), so one node covers both continents and a banner
-- can never contradict the territory it is in.
core.register_node("grug_nodes:guard_banner", {
	description = "Guard Banner",
	drawtype = "nodebox",
	tiles = {"grug_nodes_guard_banner.png"},
	-- The tile is only opaque where a box actually samples it (nodebox faces
	-- read the region of the tile their box covers); "clip" keeps the unused
	-- rest transparent instead of black.
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	-- Not walkable, like the camp fire: the post is a landmark, never an
	-- obstacle its own guards can get stuck on.
	walkable = false,
	is_ground_content = false, -- caves and the ocean mask must not eat a post
	light_source = 6, -- a lit standard, visible from a distance at night
	-- Same dispatch group as the camp fire (AGENTS.md: dispatch on groups,
	-- not on name lists) — a guard post IS a camp, only with guards in it.
	groups = {cracky = 3, grug_camp = 1},
	-- PORTABLE-SPAWNER EXPLOIT: grug_mobs turns this node into a mob spawner
	-- with a node timer that repopulates the post forever. If it dropped, a
	-- player could mine an outpost banner and re-plant it wherever they like —
	-- a private guard barracks, or an enemy-faction post carried onto friendly
	-- soil. Razing a post stays possible, it just yields nothing. Same rule on
	-- grug_mobs:camp_fire.
	drop = "",
	node_box = {
		type = "fixed",
		fixed = {
			-- Pole, full node height, centred (tile columns 6..9).
			{-2 / 16, -0.5, -2 / 16, 2 / 16, 0.5, 2 / 16},
			-- Flag board hanging off the pole (tile columns 10..14, upper
			-- half), one 16th thin so it reads as cloth.
			{2 / 16, 0, -1 / 32, 7 / 16, 7 / 16, 1 / 32},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-2 / 16, -0.5, -2 / 16, 7 / 16, 0.5, 2 / 16},
	},
	sounds = default.node_sound_wood_defaults(),
})

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

--
-- Sub-files
--

-- R4 ore respawn (WP6/T9): the "Depleted Vein" placeholder node plus the
-- single register_on_dignode hook that grows mined ore back.
dofile(core.get_modpath(core.get_current_modname()) .. "/ore_respawn.lua")
