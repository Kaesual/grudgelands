-- Signature surface nodes (WP18, docs/design/biomes_mobs.md §1.3).
--
-- Every race/wild biome that cannot be expressed with a minetest_game top
-- node gets its own one here. Besides the visual identity these nodes exist
-- FOR the Lord-of-the-Test spawn trick (biomes_mobs.md §4): mob spawning is
-- gated on a node whitelist, which is precise and costs nothing at runtime.
--
-- The first textures were cheap retints of vendored minetest_game textures
-- (CC BY-SA 3.0); since Round 47 and 51 most are original CC0 art -- see
-- LICENSE-media.md for every file's origin.
--
-- WP18 registers the nodes only; grug_mapgen (T4) wires them into the biome
-- definitions. The shared crop-definition seam also lives below world/jobs content.

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
--
-- Every generated ground node is loose ground (Round 24 ruling 5): the hand,
-- every shovel and every pick dig it, a shovel fastest. `grug_loose` repeats
-- the node's `crumbly` rating.
local function dirt_groups(extra)
	local groups = {crumbly = 3, grug_loose = 3, soil = 1}
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

-- Large flat grounds (Round 51, land plan ruling 6): a 32 px texture spans
-- 2 x 2 nodes at the node's 16 px per node, world-aligned, so the eye sees
-- no 1-node grid. The engine honours it on solid nodes and node boxes (and
-- on a rooted plant's base, which it draws as a solid node); the scale 2
-- divides the 16-node mapblock (lua_api.md, "Tile definition").
local function world_tile(texture)
	return {name = texture, align_style = "world", scale = 2}
end

-- Dirt with a litter layer on top: litter tile on top, plain dirt at the
-- bottom, dirt + litter overlay on the sides (same tile setup default uses
-- for its coniferous/rainforest litter). Drops plain dirt like default's.
-- `wide`: the top is a 32 px world-aligned texture (ruling 6); the 16 px
-- side overlay stays.
local function register_litter(name, description, texture, wide)
	core.register_node("grug_nodes:" .. name, {
		description = description,
		tiles = {
			wide and world_tile(texture .. ".png") or texture .. ".png",
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
	tiles = {world_tile("grug_nodes_blight_dirt.png")},
	groups = dirt_groups(),
	sounds = default.node_sound_dirt_defaults(),
})

register_litter("dirt_with_bone_litter", "Dirt with Bone Litter",
	"grug_nodes_bone_litter", true)
register_litter("dirt_with_forest_litter", "Dirt with Forest Litter",
	"grug_nodes_forest_litter")
register_litter("dirt_with_silver_litter", "Dirt with Silver Litter",
	"grug_nodes_silver_litter", true)
-- The shaded floor under the closed deep-jungle canopy (WP36, biomes_mobs.md
-- §1.3). It exists because grug_deep_jungle used to SHARE
-- `default:dirt_with_rainforest_litter` with grug_jungle_edge, which made
-- 41 % of the Throng continent a single eligible visual (the whole span
-- x 201..1500) -- the one biome pair in the world that did not have its own
-- top per registration. Same node family, same spawn-whitelist role as the
-- three above; the tint is deliberately colder and darker than
-- `dirt_with_forest_litter` (which is Accord-only, so the two never meet).
register_litter("dirt_with_canopy_litter", "Dirt with Canopy Litter",
	"grug_nodes_canopy_litter", true)

-- Swamp mud. `mud = 1` is a MARKER GROUP only -- the walking slow-down
-- described in docs/design/biomes_mobs.md §1.3 is NOT implemented in WP18;
-- a later WP adds the player-movement handler and dispatches on this group.
core.register_node("grug_nodes:mud", {
	description = "Swamp Mud",
	-- one 32 px tile on every face, world-aligned (Round 51)
	tiles = {world_tile("grug_nodes_mud.png")},
	groups = dirt_groups({mud = 1}),
	sounds = default.node_sound_dirt_defaults(),
})

-- The varied swamp (Round 47 lane SW, tools/r47_sw/DESIGN.md; lane ART's
-- textures, CC0, see LICENSE-media.md). Registered here next to the mud;
-- the world generator places them from build step 2 on. The two mud
-- variants and the wet grass are surface variants of the mud: the same
-- groups, and they drop plain mud, as the litters drop plain dirt.
-- Round 51 (land plan ruling 4): the picked calm tops are 32 px,
-- world-aligned; the calm 16 px sides replace the Round 47 sides of the wet
-- mud and the wet grass; the dry mud keeps its side.
core.register_node("grug_nodes:mud_dry", {
	description = "Dry Swamp Mud",
	tiles = {world_tile("grug_nodes_mud_dry_top.png"), "grug_nodes_mud_dry_side.png",
		"grug_nodes_mud_dry_side.png"},
	groups = dirt_groups({mud = 1}),
	drop = "grug_nodes:mud",
	sounds = default.node_sound_dirt_defaults(),
})

core.register_node("grug_nodes:mud_mottled", {
	description = "Wet Swamp Mud",
	tiles = {world_tile("grug_nodes_mud_mottled_top.png"), "grug_nodes_mud_mottled_side.png",
		"grug_nodes_mud_mottled_side.png"},
	groups = dirt_groups({mud = 1}),
	drop = "grug_nodes:mud",
	sounds = default.node_sound_dirt_defaults(),
})

-- The wet grass's side is a whole texture (no overlay); its bottom is the
-- mottled mud's side, as lane ART laid it out.
core.register_node("grug_nodes:mud_with_wet_grass", {
	description = "Mud with Wet Grass",
	tiles = {world_tile("grug_nodes_wet_grass_top.png"), "grug_nodes_mud_mottled_side.png",
		{name = "grug_nodes_wet_grass_side.png", tileable_vertical = false}},
	groups = dirt_groups({mud = 1}),
	drop = "grug_nodes:mud",
	sounds = litter_sounds,
})

-- The swamp's own moss ground (Round 51, land plan ruling 5): the moss
-- hummocks of the swamp, darker and cooler than the forest's moss soil
-- (`dirt_with_moss` below), on mud. It has the moss soil's groups and
-- sounds (soil, natural loose ground, no `mud` marker) and drops plain mud,
-- like the swamp's other grounds. Its side is a whole 16 px texture (a moss
-- fringe over mud), its bottom the mud.
core.register_node("grug_nodes:swamp_moss", {
	description = "Swamp Moss",
	tiles = {world_tile("grug_nodes_swamp_moss_top.png"), world_tile("grug_nodes_mud.png"),
		{name = "grug_nodes_swamp_moss_side.png", tileable_vertical = false}},
	groups = dirt_groups(),
	drop = "grug_nodes:mud",
	sounds = default.node_sound_dirt_defaults(),
})

-- A thin moss carpet on the ground (1/16 high), like a waterlily on land:
-- it goes when its ground goes (attached below), anything may be built into
-- it and water washes it away.
core.register_node("grug_nodes:moss_carpet", {
	description = "Moss Carpet",
	drawtype = "nodebox",
	tiles = {"grug_nodes_moss_carpet_top.png"},
	inventory_image = "grug_nodes_moss_carpet_top.png",
	wield_image = "grug_nodes_moss_carpet_top.png",
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	floodable = true,
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -7 / 16, 0.5}},
	groups = {snappy = 3, attached_node = 3, flammable = 2},
	sounds = default.node_sound_leaves_defaults(),
})

-- Reeds stand in stacks of one or two on land, like papyrus (digging one
-- takes those above it); in a pool they grow out of the mud bed through
-- the water as the rooted form below.
core.register_node("grug_nodes:reeds", {
	description = "Reeds",
	drawtype = "plantlike",
	tiles = {"grug_nodes_reeds.png"},
	inventory_image = "grug_nodes_reeds.png",
	wield_image = "grug_nodes_reeds.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	waving = 1,
	selection_box = {type = "fixed", fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, 0.5, 6 / 16}},
	groups = {snappy = 3, flammable = 2},
	sounds = default.node_sound_leaves_defaults(),
	after_dig_node = function(pos, node, metadata, digger)
		default.dig_up(pos, node, digger)
	end,
})

-- The pool form: the mud bed with reeds growing up through the water
-- (a leveled plantlike_rooted node like grug_mapgen's waterweed; param2 is
-- the height in sixteenths, so the water column stays whole). It is the
-- bed: digging it gives the mud back.
core.register_node("grug_nodes:mud_with_reeds", {
	description = "Mud with Reeds",
	drawtype = "plantlike_rooted",
	waving = 1,
	-- the mud's own world-aligned tile, so a bed matches the mud around it
	tiles = {world_tile("grug_nodes_mud.png")},
	special_tiles = {{name = "grug_nodes_reeds.png", tileable_vertical = true}},
	inventory_image = "grug_nodes_reeds.png",
	wield_image = "grug_nodes_reeds.png",
	paramtype = "light",
	paramtype2 = "leveled",
	-- the mud's digging (loose ground), but no soil: nothing grows on it
	groups = grug_materials.natural_groups({crumbly = 3, grug_loose = 3,
		not_in_creative_inventory = 1}),
	sounds = default.node_sound_dirt_defaults(),
	selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}},
	drop = "grug_nodes:mud",
})

-- Cattails: one node, on land beside the water only (a rooted form would
-- repeat the seed heads once per node of height).
core.register_node("grug_nodes:cattails", {
	description = "Cattails",
	drawtype = "plantlike",
	tiles = {"grug_nodes_cattails.png"},
	inventory_image = "grug_nodes_cattails.png",
	wield_image = "grug_nodes_cattails.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	waving = 1,
	selection_box = {type = "fixed", fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, 0.5, 6 / 16}},
	groups = {snappy = 3, flammable = 2, attached_node = 1},
	sounds = default.node_sound_leaves_defaults(),
})

--
-- Stone-ish
--

-- Badlands surface: hardened clay, so harder than dirt (crumbly 2, like
-- gravel) and it drops itself instead of clay lumps (it is a building
-- material, not a clay source). It is loose ground (Round 24 ruling 5): no
-- `cracky`, so a shovel digs it faster than the pick of its tier.
core.register_node("grug_nodes:mesa_clay", {
	description = "Mesa Clay",
	tiles = {world_tile("grug_nodes_mesa_clay.png")},
	groups = grug_materials.natural_groups({crumbly = 2, grug_loose = 2}),
	sounds = default.node_sound_dirt_defaults(),
})

-- The badlands' coloured clay bands (Round 51, land plan §4 "Orc"): mesa
-- clay in four colours for the strata of steep slopes, which the world
-- generator places. Loose ground like the mesa clay, and each drops plain
-- mesa clay (the user's pick), so no special blocks pile up.
for _, band in ipairs({{"ochre", "Ochre"}, {"sienna", "Sienna"}, {"chalk", "Chalk"},
		{"umber", "Umber"}}) do
	core.register_node("grug_nodes:clay_band_" .. band[1], {
		description = band[2] .. " Mesa Clay",
		tiles = {world_tile("grug_nodes_clay_band_" .. band[1] .. ".png")},
		groups = grug_materials.natural_groups({crumbly = 2, grug_loose = 2}),
		drop = "grug_nodes:mesa_clay",
		sounds = default.node_sound_dirt_defaults(),
	})
end

-- The 32 px sand (Round 51, round plan §3.1): a retexture of `default:sand`,
-- not a new node, because the shore crab's host is exactly that node. It
-- lies above and under water, so the rooted kelp's sand bed wears it too
-- (grug_mapgen's freshwater waterweed binds the same tile).
core.override_item("default:sand", {tiles = {world_tile("grug_nodes_sand.png")}})
core.override_item("default:sand_with_kelp", {tiles = {world_tile("grug_nodes_sand.png")}})

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
	-- Nodebox UVs mirror X on the back face. Mirror that tile too so both
	-- cloth faces sample the painted right-hand part of the atlas. Horizontal
	-- faces use an opaque pole pixel: their Z-based UVs cross unused atlas rows.
	tiles = {
		"grug_nodes_guard_banner.png^[sheet:16x16:7,8",
		"grug_nodes_guard_banner.png^[sheet:16x16:7,8",
		"grug_nodes_guard_banner.png",
		"grug_nodes_guard_banner.png",
		"grug_nodes_guard_banner.png^[transformFX",
		"grug_nodes_guard_banner.png",
	},
	-- Keep unused atlas regions transparent instead of black.
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
	-- soil. A node removed through an authorized future path yields nothing.
	-- The same drop rule applies to grug_nodes:camp_fire.
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

-- Generic camp activation anchor. The pure node lives below grug_mapgen so
-- R7 can authenticate its content ID while the mapgen runtime is assembled;
-- grug_mobs attaches the timer/meta behaviour later with core.override_item.
-- The texture remains in grug_mobs' media directory for now (Luanti's media
-- namespace is game-wide), but the registered node identity is deliberately
-- owned by this lower dependency.
core.register_node("grug_nodes:camp_fire", {
	description = "Camp Fire",
	drawtype = "nodebox",
	tiles = {"grug_mobs_camp_fire.png"},
	paramtype = "light",
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.4, 0.5},
			{-0.4, -0.4, -0.1, 0.4, -0.25, 0.1},
			{-0.1, -0.4, -0.4, 0.1, -0.25, 0.4},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
	},
	walkable = false,
	is_ground_content = false,
	light_source = 9,
	groups = {cracky = 3, grug_camp = 1},
	sounds = default.node_sound_gravel_defaults(),
	drop = "",
})

-- Round-10 secondary ground; existing default media, no new resource identity.
core.register_node("grug_nodes:ash_ground", {
 description="Ash Ground", tiles={"default_gravel.png^[colorize:#45403e:145"},
 groups=dirt_groups(), drop="default:dirt",
 is_ground_content=true, sounds=default.node_sound_dirt_defaults(),
})
-- The forest's moss soil (elf forest mix): Round 51 (ruling 5) replaces the
-- shipped neon moss with a muted 32 px world-aligned top and a whole 16 px
-- side (a moss fringe over dirt).
core.register_node("grug_nodes:dirt_with_moss", {
 description="Moss Soil", tiles={world_tile("grug_nodes_moss_soil_top.png"),"default_dirt.png",
  {name="grug_nodes_moss_soil_side.png",tileable_vertical=false}},
 groups=dirt_groups(), drop="default:dirt",
 is_ground_content=true, sounds=default.node_sound_dirt_defaults(),
})

-- Crop definitions must precede R7's synchronous content/authority construction.
grug_nodes = {}
local crop_path = core.get_modpath("grug_nodes")
grug_nodes.crop_visual = dofile(crop_path .. "/crop_visual.lua")
grug_nodes.bind_crop_soil_callbacks = dofile(crop_path .. "/crop_soil.lua")(core, default)

-- The land kit's props, the bone pile among them (Round 51 lane LK).
dofile(crop_path .. "/props.lua")
-- The Round 51 land plants (flowers, alpine plants, lichen, bush foliage).
dofile(crop_path .. "/plants.lua")
