-- Biome layer of the two continents (docs/design/biomes_mobs.md §1.3).
--
-- Kragmar (Throng) is the northern continent (z positive), Elandor (Accord)
-- the southern one (z negative). Every band is authored ONCE in Throng
-- coordinates; `register_mirrored` registers the Throng biome as authored
-- and the Accord biome with the cuboid mirrored at z = 0. The two
-- continents never touch, so a mirrored pair may share heat/humidity
-- points.
--
-- Inside a continent the band cuboids overlap WIDELY (400-500 nodes) on
-- purpose: in an overlap the heat/humidity voronoi decides per position,
-- which yields the recurring settled/wild patch mosaic of §1.4 instead of
-- hard seams. The climate noise that makes the extreme points (95/15,
-- 10/30, 90/90) reachable is set in init.lua.
--
-- LANDMINE (AGENTS.md): ore/decoration defs whose `biomes` names do not
-- resolve are silently unrestricted world-wide -- decorations.lua and
-- ores.lua may only name biomes registered in this file.

local X_HALF = grug_core.CONTINENT_X_HALF -- 1500
local Z_MIN = grug_core.CONTINENT_Z_MIN -- 100
local Z_MAX = grug_core.CONTINENT_Z_MAX -- 1700

-- Lowest y of the land biomes; y 1..4 belongs to the beach, y <= 3 to the
-- ocean (both cover the soft coastline the ocean mask carves, structures.lua).
local LAND_Y_MIN = 4
local SKY = 31000

local dungeon_nodes = {
	node_dungeon = "default:cobble",
	node_dungeon_alt = "default:mossycobble",
	node_dungeon_stair = "stairs:stair_cobble",
}

-- One half of a mirrored pair. `def` is always authored in THRONG
-- coordinates (z positive); side = -1 mirrors the cuboid to Elandor.
local function register_side(def, side)
	local z_min, z_max = def.z_min, def.z_max
	if side < 0 then
		z_min, z_max = -def.z_max, -def.z_min
	end
	core.register_biome({
		name = def.name,
		node_top = def.top,
		depth_top = def.top_depth or 1,
		node_filler = def.filler,
		depth_filler = def.filler_depth or 3,
		node_dust = def.dust,
		node_riverbed = "default:sand",
		depth_riverbed = 2,
		node_dungeon = dungeon_nodes.node_dungeon,
		node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
		node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
		min_pos = {x = def.x_min, y = def.y_min or LAND_Y_MIN, z = z_min},
		max_pos = {x = def.x_max, y = def.y_max or SKY, z = z_max},
		heat_point = def.heat,
		humidity_point = def.humidity,
	})
end

-- Registers one row of the §1.3 table: the Throng biome plus its Accord
-- mirror. Each side carries its OWN name, climate point and (where the
-- table says so) its own x/z range -- the bands are only geometrically
-- mirrored, never identical.
local function register_mirrored(row)
	if row.throng then
		register_side(row.throng, 1)
	end
	if row.accord then
		register_side(row.accord, -1)
	end
end

--
-- Center band: Orc savanna (T) / Human meadows (A), plus their wild
-- back-country variants badlands (T) / deep forest (A).
--
-- NB the settled cuboids start at Z_MIN (100) instead of the table's 160:
-- the war coast (|z| 100..300) does carry land above y = 4 wherever the
-- coast noise inset is small, and a z-range starting at 160 would leave
-- that land without ANY biome (bare stone, no decorations, no spawn
-- surface). Same reason for every band below.
--

register_mirrored({
	throng = {
		name = "grug_savanna",
		top = "default:dry_dirt_with_dry_grass",
		filler = "default:dry_dirt",
		x_min = -700, x_max = 700, z_min = Z_MIN, z_max = 1500,
		heat = 85, humidity = 35,
	},
	accord = {
		name = "grug_meadows",
		top = "default:dirt_with_grass",
		filler = "default:dirt",
		x_min = -700, x_max = 700, z_min = Z_MIN, z_max = 1500,
		heat = 50, humidity = 40,
	},
})

-- grug_deep_forest is ONE wide Accord biome spanning the human back-country
-- AND the elf band (§1.3 note): it loses to the settled points inside
-- core/inner and wins uncontested beyond them.
register_mirrored({
	throng = {
		name = "grug_badlands",
		top = "grug_nodes:mesa_clay",
		filler = "grug_nodes:mesa_clay",
		x_min = -700, x_max = 700, z_min = 1100, z_max = Z_MAX,
		heat = 95, humidity = 15,
	},
	accord = {
		name = "grug_deep_forest",
		top = "grug_nodes:dirt_with_forest_litter",
		filler = "default:dirt",
		x_min = -900, x_max = 1500, z_min = Z_MIN, z_max = Z_MAX,
		heat = 60, humidity = 75,
	},
})

--
-- West band: Undead blight (T) / Dwarf pine hills (A), wild variants
-- bone forest (T) / crags (A).
--

register_mirrored({
	throng = {
		name = "grug_blight",
		top = "grug_nodes:blight_dirt",
		filler = "default:dirt",
		x_min = -1250, x_max = -500, z_min = Z_MIN, z_max = Z_MAX,
		heat = 25, humidity = 20,
	},
	accord = {
		name = "grug_pine_hills",
		top = "default:dirt_with_coniferous_litter",
		filler = "default:dirt",
		x_min = -1250, x_max = -500, z_min = Z_MIN, z_max = Z_MAX,
		heat = 30, humidity = 60,
	},
})

register_mirrored({
	throng = {
		name = "grug_bone_forest",
		top = "grug_nodes:dirt_with_bone_litter",
		filler = "default:dirt",
		x_min = -X_HALF, x_max = -750, z_min = Z_MIN, z_max = Z_MAX,
		heat = 15, humidity = 45,
	},
	accord = {
		-- Gravel tops over stone: the bare high crags of the Dwarf band.
		name = "grug_crags",
		top = "default:gravel",
		filler = "default:gravel",
		filler_depth = 2,
		x_min = -X_HALF, x_max = -750, z_min = Z_MIN, z_max = Z_MAX,
		y_max = 79,
		heat = 10, humidity = 30,
	},
})

-- Cheap alpine cap (WP18 addition, not in the §1.3 table): the crags cuboid
-- and climate point once more, snow-topped above y = 80, so the high peaks
-- read as alpine without any extra noise machinery.
register_mirrored({
	accord = {
		name = "grug_crags_snowy",
		top = "default:snowblock",
		filler = "default:gravel",
		filler_depth = 2,
		dust = "default:snow",
		x_min = -X_HALF, x_max = -750, z_min = Z_MIN, z_max = Z_MAX,
		y_min = 80,
		heat = 10, humidity = 30,
	},
})

--
-- East band: Troll jungle edge (T) / Elf forest (A), wild variants
-- deep jungle (T) / jungle fringe (A, the same nodes as the troll jungle
-- one-to-one, §8.4).
--

register_mirrored({
	throng = {
		name = "grug_jungle_edge",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = 500, x_max = 1250, z_min = Z_MIN, z_max = Z_MAX,
		heat = 80, humidity = 70,
	},
	accord = {
		name = "grug_elf_forest",
		top = "grug_nodes:dirt_with_silver_litter",
		filler = "default:dirt",
		x_min = 500, x_max = 1250, z_min = Z_MIN, z_max = Z_MAX,
		heat = 70, humidity = 60,
	},
})

register_mirrored({
	throng = {
		name = "grug_deep_jungle",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = 750, x_max = X_HALF, z_min = Z_MIN, z_max = Z_MAX,
		heat = 90, humidity = 90,
	},
	accord = {
		name = "grug_jungle_fringe",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = 1150, x_max = X_HALF, z_min = Z_MIN, z_max = Z_MAX,
		heat = 85, humidity = 85,
	},
})

--
-- Universal biomes. A biome name can only be registered once, so the three
-- shared ones get ONE registration with a z-symmetric cuboid instead of a
-- mirrored pair (doc delta to §1.3, which lists them per continent).
--

-- Swamp pockets: low terrain anywhere on either continent. The extreme
-- humidity point keeps them rare and tied to the wet noise regions.
core.register_biome({
	name = "grug_swamp",
	node_top = "grug_nodes:mud",
	depth_top = 1,
	node_filler = "grug_nodes:mud",
	depth_filler = 2,
	node_riverbed = "default:sand",
	depth_riverbed = 2,
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	min_pos = {x = -X_HALF, y = 1, z = -Z_MAX},
	max_pos = {x = X_HALF, y = 6, z = Z_MAX},
	heat_point = 60,
	humidity_point = 95,
})

-- Shoreline fringe. The ocean mask carves a wandering coastline INSIDE the
-- continent rectangle: the coast noise insets the rectangle by 0..150 nodes
-- and the waterline sits ~30 nodes further in, so the shore wanders up to
-- ~180 nodes deep and the sand-capped beach band up to ~190. The beach
-- therefore covers the whole outer band of the rectangle, not just its edge.
core.register_biome({
	name = "grug_beach",
	node_top = "default:sand",
	depth_top = 1,
	node_filler = "default:sand",
	depth_filler = 2,
	node_riverbed = "default:sand",
	depth_riverbed = 2,
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	min_pos = {x = -X_HALF, y = 1, z = -Z_MAX},
	max_pos = {x = X_HALF, y = 4, z = Z_MAX},
	heat_point = 50,
	humidity_point = 55,
})

-- ONE sand-bottom ocean for the whole world, x/z UNLIMITED (doc delta to
-- §1.3, which caps it at the continent rectangles): the strait, the coastal
-- ocean and the open sea are all outside every land cuboid, and without an
-- unlimited ocean they would have no biome at all -- no seabed filler, no
-- dungeon nodes, no cave liquid.
core.register_biome({
	name = "grug_ocean",
	node_top = "default:sand",
	depth_top = 1,
	node_filler = "default:sand",
	depth_filler = 3,
	node_riverbed = "default:sand",
	depth_riverbed = 2,
	node_cave_liquid = "default:water_source",
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	vertical_blend = 1,
	y_max = 3,
	y_min = -255,
	heat_point = 50,
	humidity_point = 50,
})

-- One shared underground biome below everything (cave content).
core.register_biome({
	name = "grug_underground",
	node_cave_liquid = {"default:water_source", "default:lava_source"},
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	y_max = -256,
	y_min = -31000,
	heat_point = 50,
	humidity_point = 50,
})
