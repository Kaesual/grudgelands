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
-- Also deferred: the §2 war-coast battlefield overlay (broken carts, bone
-- piles, burnt patches) ships with WP13's schematic pass.
--
-- LANDMINE (AGENTS.md): every `biomes` entry below must name a biome
-- registered in biomes.lua, otherwise the decoration silently becomes
-- world-wide. An unresolvable single name is only dropped with a warning
-- (l_mapgen.cpp:412-455); it is a whole list that fails to resolve which
-- turns the deco unrestricted (mg_decoration.cpp:193-197).
--
-- SECOND LANDMINE, since the capital-guarantee carve (biomes.lua, 2026-08-08):
-- grug_deep_forest and (since WP36) grug_badlands ship as several SIBLING
-- registrations, and a sibling is a separate biome name. A deco that lists
-- only the parent silently disappears from the slabs it does not list — no
-- warning, because the parent name resolves fine. The DEEP_FOREST and
-- BADLANDS lists below are the single place those mappings live; never write
-- "grug_deep_forest" or "grug_badlands" as a bare string in a `biomes` list
-- again. (grug_meadows and grug_savanna were split the same way and collapsed
-- back to one cuboid each on 2026-08-08 — their `_front`/`_back` siblings no
-- longer exist and must not be named here, or the whole list stops resolving.)
--
-- THIRD LANDMINE, WP36: a `place_on` is just as silent as a `biomes` list.
-- grug_deep_jungle got its OWN node_top that round
-- (grug_nodes:dirt_with_canopy_litter, it used to share the jungle edge's
-- rainforest litter), and every deco that kept `place_on = RAINFOREST` while
-- still naming grug_deep_jungle in `biomes` would simply never fire there —
-- a bare biome. That is what JUNGLE_FLOOR below is for.

local schem = core.get_modpath("default") .. "/schematics/"

-- LANDMINE: Luanti caches file-loaded schematics BY FULL PATH. A string
-- `schematic` goes through get_or_load_schematic() -> get_objdef() ->
-- SchematicManager::getByName(path) (l_mapgen.cpp), and
-- Schematic::loadSchematicFromFile() sets that name to the file path
-- (mg_schematic.cpp). So the SECOND registration of the same .mts silently
-- reuses the FIRST Schematic object -- WITH the first one's `replacements`
-- and WITHOUT its own, which are never even looked at. clear_registered_
-- decorations() does not help: it clears decorations, not the schematic
-- cache.
--
-- That bug shipped once: elf_forest_silverwood registered aspen_tree.mts
-- with the silverwood replacements first, so deep_forest_aspen_tree got
-- silverwood trees instead of aspens -- all over the map, far outside the
-- elf band.
--
-- read_mts() below hands register_decoration a Lua TABLE instead. Tables
-- take the load_schematic_from_def() path, which builds a fresh Schematic
-- per registration and applies THAT registration's replacements, so the
-- same .mts can be used any number of times. The engine only reads the
-- table, so one parse per file is shared by all its decorations.
--
-- NEVER pass a bare path string as `schematic` again -- always read_mts().
local mts_cache = {}

local function read_mts(filename)
	local schematic = mts_cache[filename]
	if not schematic then
		schematic = core.read_schematic(schem .. filename, {})
		if not schematic then
			error("grug_mapgen: cannot read schematic " .. filename)
		end
		mts_cache[filename] = schematic
	end
	return schematic
end

local function register_tree(name, schematic, place_on, biomes, fill_ratio,
		extra)
	if extra and extra.schematic then
		-- Would reintroduce the path cache bug above.
		error("grug_mapgen: " .. name .. " overrides `schematic`; pass the "
			.. ".mts file name instead")
	end
	local def = {
		name = "grug_mapgen:" .. name,
		deco_type = "schematic",
		place_on = place_on,
		sidelen = 16,
		fill_ratio = fill_ratio,
		biomes = biomes,
		y_max = 31000,
		y_min = 1,
		schematic = read_mts(schematic),
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
-- The deep jungle's own floor since WP36 (grug_nodes, biomes.lua). It used to
-- be RAINFOREST, i.e. the same node as grug_jungle_edge — which is exactly
-- why every deco below that means "jungle" has to name BOTH nodes now.
local CANOPY = "grug_nodes:dirt_with_canopy_litter"
local DRY_GRASS = "default:dry_dirt_with_dry_grass"
local MESA = "grug_nodes:mesa_clay"
local GRAVEL = "default:gravel"
local MUD = "grug_nodes:mud"

local GRAVEWOOD = "grug_trees:gravewood_tree"
local JUNGLE = {"grug_deep_jungle", "grug_jungle_fringe"}
-- place_on for the JUNGLE list: the Throng half now stands on CANOPY and the
-- Accord half still on RAINFOREST (§8.4 binds the FRINGE to the troll
-- jungle's nodes, and the troll jungle is grug_jungle_edge). Both nodes in
-- one place_on rather than two registrations — the `biomes` list already
-- confines the deco to the two jungle wilds, and only one of the two nodes
-- can ever be the top inside each of them.
local JUNGLE_FLOOR = {RAINFOREST, CANOPY}

-- The two split bands (biomes.lua): grug_deep_forest ships as back slab +
-- front slab + east wing (the carve box needs a hole in the middle of the
-- cuboid), grug_badlands as back slab + east wing. Same node_top and same
-- flora throughout — the split is pure geometry, so every deco of a band
-- lists all of its registrations.
local DEEP_FOREST = {"grug_deep_forest", "grug_deep_forest_front",
	"grug_deep_forest_east"}
local BADLANDS = {"grug_badlands", "grug_badlands_east"}
-- Single cuboids, kept as one-element lists so a future re-split only has to
-- touch these two lines.
local MEADOWS = {"grug_meadows"}
local SAVANNA = {"grug_savanna"}

--
-- grug_meadows (Human settled): open grassland, a few oaks.
--

register_tree("meadows_apple_tree", "apple_tree.mts", GRASS,
	MEADOWS, 0.0015)
register_tree("meadows_bush", "bush.mts", GRASS, MEADOWS, 0.004)
for length = 1, 5 do
	register_plant("meadows_grass_" .. length, "default:grass_" .. length,
		GRASS, MEADOWS, 0.06)
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

-- aspen_tree.mts is ALSO used by deep_forest_aspen_tree below, unreplaced.
-- Only correct because read_mts() passes a table -- see the note at the top.
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
	DEEP_FOREST, 0.012)
-- Real aspen (§2): the same .mts as elf_forest_silverwood, but WITHOUT its
-- replacements. Keep it that way -- silverwood belongs to the elf band only.
register_tree("deep_forest_aspen_tree", "aspen_tree.mts", FOREST,
	DEEP_FOREST, 0.008)
-- apple_log.mts also contains flowers:mushroom_brown; the flowers mod is not
-- part of the game, so the node is replaced instead of silently dropped.
register_tree("deep_forest_apple_log", "apple_log.mts", FOREST,
	DEEP_FOREST, 0.001, {
		flags = "place_center_x",
		place_offset_y = 1,
		replacements = {["flowers:mushroom_brown"] = "air"},
	})
for length = 1, 3 do
	register_plant("deep_forest_fern_" .. length, "default:fern_" .. length,
		FOREST, DEEP_FOREST, 0.02)
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
	SAVANNA, 0.002)
register_tree("savanna_acacia_bush", "acacia_bush.mts", DRY_GRASS,
	SAVANNA, 0.004)
for length = 1, 5 do
	register_plant("savanna_dry_grass_" .. length,
		"default:dry_grass_" .. length, DRY_GRASS, SAVANNA, 0.06)
end

--
-- grug_badlands (Throng wilderness): mesa clay, cacti, dead shrubs.
--

register_tree("badlands_large_cactus", "large_cactus.mts", MESA,
	BADLANDS, 0.001)
register_plant("badlands_dry_shrub", "default:dry_shrub", MESA,
	BADLANDS, 0.008, {param2 = 4})

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
-- grug_deep_jungle / grug_jungle_fringe: same flora and roster on both
-- continents, but NOT the same ground node since WP36 -- the deep jungle
-- stands on grug_nodes:dirt_with_canopy_litter, the fringe still on
-- default:dirt_with_rainforest_litter. That is why every deco below places
-- on JUNGLE_FLOOR (= RAINFOREST + CANOPY) and not on one of the two: a
-- place_on that misses a top is as silent as a biomes list that misses a
-- slab. Dense canopy plus emergent giants.
--

register_tree("jungle_tree", "jungle_tree.mts", JUNGLE_FLOOR, JUNGLE, 0.02)
-- 37 nodes tall: default limits it to low altitudes and a wide sidelen,
-- otherwise it cannot fit into a mapchunk.
register_tree("emergent_jungle_tree", "emergent_jungle_tree.mts", JUNGLE_FLOOR,
	JUNGLE, 0.005, {sidelen = 80, y_max = 32, place_offset_y = -4})
register_plant("jungle_junglegrass", "default:junglegrass", JUNGLE_FLOOR,
	JUNGLE, 0.05)
-- NO jungle papyrus: v7 never places water above sea level, so "papyrus at
-- water" cannot exist on the jungle cuboids (surface y >= 4) -- any real
-- waterside ground at y <= 6 belongs to the swamp/beach biomes, and the
-- swamp registration below covers it. (Review-verified: a jungle papyrus
-- deco with spawn_by water is structurally dead.)

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
