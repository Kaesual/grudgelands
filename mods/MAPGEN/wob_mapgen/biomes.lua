-- Territory biomes (docs/design/world.md §1/§7). Each faction territory is
-- split into three race-flavored x-bands; the bands overlap by 200 nodes and
-- the heat/humidity voronoi decides inside the overlap, which yields an
-- organic transition. z-cuboids keep every biome inside its territory.

local NEUTRAL = wob_core.NEUTRAL_HALF_WIDTH
-- Territory biomes reach this far into the neutral borderland so the
-- territory edge is a noisy voronoi blend instead of a straight line.
-- Gameplay borders (protection, territory_at) stay crisp at +-NEUTRAL.
local TERRITORY_BIOME_Z = NEUTRAL - 31
local WEST_MAX = wob_core.REGION_WEST_MAX
local CENTER_MIN = wob_core.REGION_CENTER_MIN
local CENTER_MAX = wob_core.REGION_CENTER_MAX
local EAST_MIN = wob_core.REGION_EAST_MIN

local dungeon_nodes = {
	node_dungeon = "default:cobble",
	node_dungeon_alt = "default:mossycobble",
	node_dungeon_stair = "stairs:stair_cobble",
}

-- Registers a surface biome plus its sand-bottomed ocean variant, both
-- confined to the same x/z cuboid.
local function register_region(def)
	core.register_biome({
		name = def.name,
		node_dust = def.dust,
		node_top = def.top,
		depth_top = def.top_depth or 1,
		node_filler = def.filler,
		depth_filler = def.filler_depth or 1,
		node_riverbed = "default:sand",
		depth_riverbed = 2,
		node_dungeon = dungeon_nodes.node_dungeon,
		node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
		node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
		min_pos = {x = def.x_min or -31000, y = 4, z = def.z_min or -31000},
		max_pos = {x = def.x_max or 31000, y = 31000, z = def.z_max or 31000},
		heat_point = def.heat,
		humidity_point = def.humidity,
	})
	core.register_biome({
		name = def.name .. "_ocean",
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
		min_pos = {x = def.x_min or -31000, y = -255, z = def.z_min or -31000},
		max_pos = {x = def.x_max or 31000, y = 3, z = def.z_max or 31000},
		heat_point = def.heat,
		humidity_point = def.humidity,
	})
end

-- Neutral borderland: readable, open PvP battlefield across the full width.
register_region({
	name = "wob_borderland",
	top = "default:dirt_with_grass",
	filler = "default:dirt",
	z_min = -NEUTRAL, z_max = NEUTRAL,
	heat = 50, humidity = 50,
})

-- Alliance (south).
register_region({
	name = "wob_alliance_hills", -- Dwarves: mountains/hills, pine forest
	top = "default:dirt_with_coniferous_litter",
	filler = "default:dirt",
	filler_depth = 3,
	x_max = WEST_MAX, z_max = -TERRITORY_BIOME_Z,
	heat = 25, humidity = 65,
})
register_region({
	name = "wob_alliance_plains", -- Humans: plains/meadows, capital region
	top = "default:dirt_with_grass",
	filler = "default:dirt",
	x_min = CENTER_MIN, x_max = CENTER_MAX, z_max = -TERRITORY_BIOME_Z,
	heat = 50, humidity = 35,
})
register_region({
	name = "wob_alliance_forest", -- Elves: deciduous forests
	top = "default:dirt_with_grass",
	filler = "default:dirt",
	filler_depth = 3,
	x_min = EAST_MIN, z_max = -TERRITORY_BIOME_Z,
	heat = 65, humidity = 70,
})

-- Horde (north).
register_region({
	name = "wob_horde_blight", -- Undead: barren dark forest/blight
	top = "default:dirt",
	filler = "default:dirt",
	filler_depth = 2,
	x_max = WEST_MAX, z_min = TERRITORY_BIOME_Z,
	heat = 30, humidity = 25,
})
register_region({
	name = "wob_horde_savanna", -- Orcs: savanna/badlands, capital region
	top = "default:dry_dirt_with_dry_grass",
	filler = "default:dry_dirt",
	x_min = CENTER_MIN, x_max = CENTER_MAX, z_min = TERRITORY_BIOME_Z,
	heat = 85, humidity = 40,
})
register_region({
	name = "wob_horde_jungle", -- Trolls: jungle/swamp
	top = "default:dirt_with_rainforest_litter",
	filler = "default:dirt",
	filler_depth = 3,
	x_min = EAST_MIN, z_min = TERRITORY_BIOME_Z,
	heat = 80, humidity = 75,
})

-- One shared underground biome below all territories.
core.register_biome({
	name = "wob_underground",
	node_cave_liquid = {"default:water_source", "default:lava_source"},
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	y_max = -256,
	y_min = -31000,
	heat_point = 50,
	humidity_point = 50,
})
