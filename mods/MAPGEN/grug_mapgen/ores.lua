-- Ore registrations, adopted from minetest_game default.register_ores()
-- (same values), minus the desert stratum ores (we have no desert biomes)
-- and with blob biome lists mapped to our biome names.

-- Blob ores first so scatter ores don't end up inside blobs.

core.register_ore({
	ore_type = "blob",
	ore = "default:clay",
	wherein = {"default:sand"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 0,
	y_min = -15,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = -316,
		octaves = 1,
		persist = 0.0
	},
})

core.register_ore({
	ore_type = "blob",
	ore = "default:silver_sand",
	wherein = {"default:stone"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 31000,
	y_min = -31000,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 2316,
		octaves = 1,
		persist = 0.0
	},
})

core.register_ore({
	ore_type = "blob",
	ore = "default:dirt",
	wherein = {"default:stone"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 31000,
	y_min = -31,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 17676,
		octaves = 1,
		persist = 0.0
	},
	-- Only in the biomes whose ground is dirt (node_top of the dirt family
	-- over a default:dirt filler, biomes.lua). Left out on purpose: savanna
	-- (dry dirt, as in minetest_game), badlands (mesa clay), crags (gravel),
	-- swamp (mud), beach/ocean (sand).
	biomes = {"grug_meadows", "grug_pine_hills", "grug_elf_forest",
		"grug_deep_forest", "grug_blight", "grug_bone_forest",
		"grug_jungle_edge", "grug_deep_jungle", "grug_jungle_fringe"},
})

core.register_ore({
	ore_type = "blob",
	ore = "default:gravel",
	wherein = {"default:stone"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 31000,
	y_min = -31000,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 766,
		octaves = 1,
		persist = 0.0
	},
})

-- Scatter ores: {ore, {clust_scarcity, clust_num_ores, clust_size, y_max, y_min}, ...}

local scatter_ores = {
	{"default:stone_with_coal",
		{8 * 8 * 8, 9, 3, 31000, 1025},
		{8 * 8 * 8, 8, 3, 64, -127},
		{12 * 12 * 12, 30, 5, -128, -31000}},
	{"default:stone_with_tin",
		{10 * 10 * 10, 5, 3, 31000, 1025},
		{13 * 13 * 13, 4, 3, -64, -127},
		{10 * 10 * 10, 5, 3, -128, -31000}},
	{"default:stone_with_copper",
		{9 * 9 * 9, 5, 3, 31000, 1025},
		{12 * 12 * 12, 4, 3, -64, -127},
		{9 * 9 * 9, 5, 3, -128, -31000}},
	{"default:stone_with_iron",
		{9 * 9 * 9, 12, 3, 31000, 1025},
		{7 * 7 * 7, 5, 3, -128, -255},
		{12 * 12 * 12, 29, 5, -256, -31000}},
	{"default:stone_with_gold",
		{13 * 13 * 13, 5, 3, 31000, 1025},
		{15 * 15 * 15, 3, 2, -256, -511},
		{13 * 13 * 13, 5, 3, -512, -31000}},
	{"default:stone_with_mese",
		{14 * 14 * 14, 5, 3, 31000, 1025},
		{18 * 18 * 18, 3, 2, -512, -1023},
		{14 * 14 * 14, 5, 3, -1024, -31000}},
	{"default:stone_with_diamond",
		{15 * 15 * 15, 4, 3, 31000, 1025},
		{17 * 17 * 17, 4, 3, -1024, -2047},
		{15 * 15 * 15, 4, 3, -2048, -31000}},
	{"default:mese",
		{36 * 36 * 36, 3, 2, 31000, 1025},
		{36 * 36 * 36, 3, 2, -2048, -4095},
		{28 * 28 * 28, 5, 3, -4096, -31000}},
}

for _, entry in ipairs(scatter_ores) do
	for i = 2, #entry do
		local p = entry[i]
		core.register_ore({
			ore_type = "scatter",
			ore = entry[1],
			wherein = "default:stone",
			clust_scarcity = p[1],
			clust_num_ores = p[2],
			clust_size = p[3],
			y_max = p[4],
			y_min = p[5],
		})
	end
end
