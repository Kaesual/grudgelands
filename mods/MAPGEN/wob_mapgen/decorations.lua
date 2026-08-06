-- Region decorations. Schematics are reused from minetest_game's default
-- mod; densities are per-region flavor: dense elven/troll forests, open
-- plains/savanna, barren undead blight, a readable borderland battlefield.

local schem = core.get_modpath("default") .. "/schematics/"

local function register_tree(name, schematic, place_on, biomes, fill_ratio)
	core.register_decoration({
		name = "wob_mapgen:" .. name,
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
	})
end

local function register_plant(name, decoration, place_on, biomes, fill_ratio, extra)
	local def = {
		name = "wob_mapgen:" .. name,
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

local grass = "default:dirt_with_grass"

-- Neutral borderland: open field, grass only (sightlines for PvP).
for length = 1, 3 do
	register_plant("borderland_grass_" .. length, "default:grass_" .. length,
		grass, {"wob_borderland"}, 0.04)
end

-- Alliance plains (Humans): meadows, scattered trees.
for length = 1, 5 do
	register_plant("plains_grass_" .. length, "default:grass_" .. length,
		grass, {"wob_alliance_plains"}, 0.06)
end
register_tree("plains_apple_tree", "apple_tree.mts", grass,
	{"wob_alliance_plains"}, 0.0008)
register_tree("plains_bush", "bush.mts", grass,
	{"wob_alliance_plains"}, 0.004)

-- Alliance forest (Elves): dense deciduous forest.
register_tree("forest_apple_tree", "apple_tree.mts", grass,
	{"wob_alliance_forest"}, 0.02)
register_tree("forest_aspen_tree", "aspen_tree.mts", grass,
	{"wob_alliance_forest"}, 0.012)
register_tree("forest_bush", "bush.mts", grass,
	{"wob_alliance_forest"}, 0.008)
for length = 1, 5 do
	register_plant("forest_grass_" .. length, "default:grass_" .. length,
		grass, {"wob_alliance_forest"}, 0.02)
end

-- Alliance hills (Dwarves): pine forest on rugged ground.
local litter = "default:dirt_with_coniferous_litter"
register_tree("hills_pine_tree", "pine_tree.mts", litter,
	{"wob_alliance_hills"}, 0.015)
register_tree("hills_small_pine_tree", "small_pine_tree.mts", litter,
	{"wob_alliance_hills"}, 0.008)
register_tree("hills_pine_bush", "pine_bush.mts", litter,
	{"wob_alliance_hills"}, 0.006)
for length = 1, 3 do
	register_plant("hills_fern_" .. length, "default:fern_" .. length,
		litter, {"wob_alliance_hills"}, 0.02)
end

-- Horde savanna (Orcs): dry grassland with acacias.
local dry_grass_top = "default:dry_dirt_with_dry_grass"
register_tree("savanna_acacia_tree", "acacia_tree.mts", dry_grass_top,
	{"wob_horde_savanna"}, 0.002)
register_tree("savanna_acacia_bush", "acacia_bush.mts", dry_grass_top,
	{"wob_horde_savanna"}, 0.004)
for length = 1, 5 do
	register_plant("savanna_dry_grass_" .. length,
		"default:dry_grass_" .. length, dry_grass_top,
		{"wob_horde_savanna"}, 0.06)
end

-- Horde jungle (Trolls): dense rainforest.
local rainforest = "default:dirt_with_rainforest_litter"
register_tree("jungle_tree", "jungle_tree.mts", rainforest,
	{"wob_horde_jungle"}, 0.025)
register_plant("jungle_grass", "default:junglegrass", rainforest,
	{"wob_horde_jungle"}, 0.04)

-- Horde blight (Undead): barren land, dead trunks and dry shrubs.
register_plant("blight_dry_shrub", "default:dry_shrub", "default:dirt",
	{"wob_horde_blight"}, 0.015, {param2 = 4})
register_plant("blight_dead_trunk", "default:tree", "default:dirt",
	{"wob_horde_blight"}, 0.0015, {height = 2, height_max = 4})
