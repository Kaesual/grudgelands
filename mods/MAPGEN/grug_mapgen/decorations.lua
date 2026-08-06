-- Biome decorations (docs/design/biomes_mobs.md §2). Schematics come from
-- minetest_game's default mod; the two race trees that have no .mts
-- (silverwood, gravewood) are handled without one: silverwood is default's
-- aspen schematic with node `replacements` (grug_trees), gravewood is a
-- `simple` trunk decoration -- exactly the bare dead tree the Undead look
-- wants, and schematic decorations could not call the Lua grower anyway
-- (it is not VoxelManip-safe).
--
-- WP18 places TREES AND GROUND COVER only. The gathering flora of §2 --
-- herbs (sunleaf/gravemoss/dragonweed/marshbloom/crimson lotus/stormkelp),
-- food plants, flowers, mushrooms, beach shells and kelp -- are WP10
-- content and get their nodes and decorations there.
--
-- LANDMINE (AGENTS.md): every `biomes` entry below must name a biome
-- registered in biomes.lua, otherwise the decoration silently becomes
-- world-wide.

local schem = core.get_modpath("default") .. "/schematics/"

local function register_tree(name, schematic, place_on, biomes, fill_ratio,
		extra)
	local def = {
		name = "grug_mapgen:" .. name,
		deco_type = "schematic",
		place_on = place_on,
		sidelen = 16,
		fill_ratio = fill_ratio,
		biomes = biomes,
		y_max = 31000,
		y_min = 1,
		schematic = schem .. schematic,
		flags = "place_center_x, place_center_z",
		rotation = "random",
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	core.register_decoration(def)
end

local function register_plant(name, decoration, place_on, biomes, fill_ratio,
		extra)
	local def = {
		name = "grug_mapgen:" .. name,
		deco_type = "simple",
		place_on = place_on,
		sidelen = 16,
		fill_ratio = fill_ratio,
		biomes = biomes,
		y_max = 31000,
		y_min = 1,
		decoration = decoration,
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	core.register_decoration(def)
end

-- Surface nodes of the biomes (biomes.lua); every place_on below is the
-- actual node_top of the biomes it is registered for.
local GRASS = "default:dirt_with_grass"
local CONIFER = "default:dirt_with_coniferous_litter"
local SILVER = "grug_nodes:dirt_with_silver_litter"
local FOREST = "grug_nodes:dirt_with_forest_litter"
local BONE = "grug_nodes:dirt_with_bone_litter"
local BLIGHT = "grug_nodes:blight_dirt"
local RAINFOREST = "default:dirt_with_rainforest_litter"
local DRY_GRASS = "default:dry_dirt_with_dry_grass"
local MESA = "grug_nodes:mesa_clay"
local GRAVEL = "default:gravel"
local MUD = "grug_nodes:mud"

local GRAVEWOOD = "grug_trees:gravewood_tree"
local JUNGLE = {"grug_deep_jungle", "grug_jungle_fringe"}

--
-- grug_meadows (Human settled): open grassland, a few oaks.
--

register_tree("meadows_apple_tree", "apple_tree.mts", GRASS,
	{"grug_meadows"}, 0.0015)
register_tree("meadows_bush", "bush.mts", GRASS, {"grug_meadows"}, 0.004)
for length = 1, 5 do
	register_plant("meadows_grass_" .. length, "default:grass_" .. length,
		GRASS, {"grug_meadows"}, 0.06)
end

--
-- grug_pine_hills (Dwarf settled): pine forest on rugged ground.
--

register_tree("pine_hills_pine_tree", "pine_tree.mts", CONIFER,
	{"grug_pine_hills"}, 0.004)
register_tree("pine_hills_small_pine_tree", "small_pine_tree.mts", CONIFER,
	{"grug_pine_hills"}, 0.002)
register_tree("pine_hills_pine_bush", "pine_bush.mts", CONIFER,
	{"grug_pine_hills"}, 0.006)
-- Wild berries: the bush and its fruit node both come from default, so the
-- §2 `[food]` source of the hills already exists -- kept rare, WP10 owns
-- the gathering rules.
register_tree("pine_hills_blueberry_bush", "blueberry_bush.mts", CONIFER,
	{"grug_pine_hills"}, 0.001, {place_offset_y = 1})
for length = 1, 3 do
	register_plant("pine_hills_fern_" .. length, "default:fern_" .. length,
		CONIFER, {"grug_pine_hills"}, 0.02)
end

--
-- grug_elf_forest (Elf settled): silverwood groves on pale litter.
--

register_tree("elf_forest_silverwood", "aspen_tree.mts", SILVER,
	{"grug_elf_forest"}, 0.007,
	{replacements = grug_trees.silverwood_replacements})
register_tree("elf_forest_apple_tree", "apple_tree.mts", SILVER,
	{"grug_elf_forest"}, 0.002)
for length = 1, 3 do
	register_plant("elf_forest_grass_" .. length, "default:grass_" .. length,
		SILVER, {"grug_elf_forest"}, 0.02)
end

--
-- grug_deep_forest (Accord wilderness): dark, dense, fallen logs.
--

register_tree("deep_forest_apple_tree", "apple_tree.mts", FOREST,
	{"grug_deep_forest"}, 0.012)
register_tree("deep_forest_aspen_tree", "aspen_tree.mts", FOREST,
	{"grug_deep_forest"}, 0.008)
-- apple_log.mts also contains flowers:mushroom_brown; the flowers mod is not
-- part of the game, so the node is replaced instead of silently dropped.
register_tree("deep_forest_apple_log", "apple_log.mts", FOREST,
	{"grug_deep_forest"}, 0.001, {
		flags = "place_center_x",
		place_offset_y = 1,
		replacements = {["flowers:mushroom_brown"] = "air"},
	})
for length = 1, 3 do
	register_plant("deep_forest_fern_" .. length, "default:fern_" .. length,
		FOREST, {"grug_deep_forest"}, 0.02)
end

--
-- grug_crags (Accord wilderness): bare gravel, a few snowy pines high up.
-- Above y = 80 the grug_crags_snowy cap takes over and stays empty (bare
-- snow) on purpose.
--

register_tree("crags_snowy_pine_tree", "snowy_pine_tree_from_sapling.mts",
	GRAVEL, {"grug_crags"}, 0.002, {y_min = 60})

--
-- grug_savanna (Orc settled): dry grassland with acacias.
--

register_tree("savanna_acacia_tree", "acacia_tree.mts", DRY_GRASS,
	{"grug_savanna"}, 0.002)
register_tree("savanna_acacia_bush", "acacia_bush.mts", DRY_GRASS,
	{"grug_savanna"}, 0.004)
for length = 1, 5 do
	register_plant("savanna_dry_grass_" .. length,
		"default:dry_grass_" .. length, DRY_GRASS, {"grug_savanna"}, 0.06)
end

--
-- grug_badlands (Throng wilderness): mesa clay, cacti, dead shrubs.
--

register_tree("badlands_large_cactus", "large_cactus.mts", MESA,
	{"grug_badlands"}, 0.001)
register_plant("badlands_dry_shrub", "default:dry_shrub", MESA,
	{"grug_badlands"}, 0.008, {param2 = 4})

--
-- grug_blight (Undead settled): barren, bare gravewood trunks, bone piles.
--

register_plant("blight_gravewood", GRAVEWOOD, BLIGHT, {"grug_blight"},
	0.0015, {height = 2, height_max = 4})
register_plant("blight_dry_shrub", "default:dry_shrub", BLIGHT,
	{"grug_blight"}, 0.015, {param2 = 4})
register_plant("blight_bone_pile", "grug_nodes:bone_pile", BLIGHT,
	{"grug_blight"}, 0.002)

--
-- grug_bone_forest (Throng wilderness): a dense forest of dead trunks.
--

register_plant("bone_forest_gravewood", GRAVEWOOD, BONE,
	{"grug_bone_forest"}, 0.015, {height = 2, height_max = 4})
register_plant("bone_forest_bone_pile", "grug_nodes:bone_pile", BONE,
	{"grug_bone_forest"}, 0.004)

--
-- grug_jungle_edge (Troll settled): light rainforest.
--

register_tree("jungle_edge_jungle_tree", "jungle_tree.mts", RAINFOREST,
	{"grug_jungle_edge"}, 0.008)
register_plant("jungle_edge_junglegrass", "default:junglegrass", RAINFOREST,
	{"grug_jungle_edge"}, 0.04)

--
-- grug_deep_jungle / grug_jungle_fringe: the same nodes on both continents
-- (§8.4) -- dense canopy plus emergent giants.
--

register_tree("jungle_tree", "jungle_tree.mts", RAINFOREST, JUNGLE, 0.02)
-- 37 nodes tall: default limits it to low altitudes and a wide sidelen,
-- otherwise it cannot fit into a mapchunk.
register_tree("emergent_jungle_tree", "emergent_jungle_tree.mts", RAINFOREST,
	JUNGLE, 0.005, {sidelen = 80, y_max = 32, place_offset_y = -4})
register_plant("jungle_junglegrass", "default:junglegrass", RAINFOREST,
	JUNGLE, 0.05)
-- Papyrus stands right at the water line; the schematic brings its own
-- dirt base node.
register_tree("jungle_papyrus", "papyrus_on_dirt.mts", RAINFOREST, JUNGLE,
	0.01, {y_min = 1, y_max = 2})

--
-- grug_swamp (universal): reed pools on mud.
--

register_tree("swamp_papyrus", "papyrus_on_dirt.mts", MUD, {"grug_swamp"},
	0.02, {
		y_min = 1,
		y_max = 4,
		replacements = {["default:dirt"] = "grug_nodes:mud"},
	})
register_plant("swamp_dry_shrub", "default:dry_shrub", MUD, {"grug_swamp"},
	0.004, {param2 = 4})
