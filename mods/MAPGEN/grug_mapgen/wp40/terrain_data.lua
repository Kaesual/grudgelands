-- Round 22 terrain character data (world_zones.md §7.6, §8.4).
--
-- Every tunable of the natural surface lives here; `terrain_field.lua` holds
-- only the mechanism. The values are the accepted Phase 2 prototype, variant
-- R2 (plan D25): rugged base, two continental ranges, hill country in human
-- and orc lands, calm bowls around starts and capitals.
local data = {}

-- Region character channels per relief id: base elevation above water, hill
-- amplitude, fBm gain (roughness), ridge amplitude, ridge share (area that
-- carries ranges), cliff share (soft ledges), erosion strength, small-scale
-- roughness multiplier, coast ramp width.
data.channels = {"base", "hill", "gain", "ridge", "rshare", "cliff", "erode",
	"rough", "coastw"}

data.relief = {
	wetland_delta = {base = 10, hill = 10, gain = 0.66, ridge = 20, rshare = 0.1,
		cliff = 0.0, erode = 0.3, rough = 1.0, coastw = 260},
	lowland = {base = 30, hill = 20, gain = 0.68, ridge = 30, rshare = 0.2,
		cliff = 0.0, erode = 0.4, rough = 1.0, coastw = 240},
	rolling_hills = {base = 52, hill = 30, gain = 0.72, ridge = 55, rshare = 0.35,
		cliff = 0.0, erode = 0.5, rough = 1.0, coastw = 200},
	plateau = {base = 72, hill = 26, gain = 0.71, ridge = 70, rshare = 0.4,
		cliff = 0.12, erode = 0.5, rough = 1.0, coastw = 160},
	highland = {base = 100, hill = 28, gain = 0.74, ridge = 150, rshare = 0.65,
		cliff = 0.05, erode = 0.6, rough = 1.0, coastw = 140},
	mountain = {base = 130, hill = 32, gain = 0.76, ridge = 200, rshare = 0.95,
		cliff = 0.1, erode = 0.6, rough = 1.0, coastw = 70},
}
-- The relief id used where a zone names none, and for sea cells of the grid.
data.default_relief = "rolling_hills"
data.sea_relief = "lowland"

-- Mild race accents: {"+", v} adds, {"*", v} multiplies.
data.race = {
	dwarf = {base = {"+", 10}, hill = {"*", 1.15}, gain = {"+", 0.03},
		ridge = {"*", 1.3}, rshare = {"+", 0.15}},
	human = {base = {"+", -2}, hill = {"*", 1.0}, gain = {"+", -0.02},
		ridge = {"*", 0.8}, rshare = {"+", -0.05}},
	elf = {erode = {"+", 0.1}, ridge = {"*", 0.9}},
	undead = {base = {"+", -4}, hill = {"*", 0.9}, gain = {"+", 0.02},
		ridge = {"*", 1.1}, rshare = {"+", 0.05}},
	orc = {hill = {"*", 0.95}, ridge = {"*", 0.85}, cliff = {"+", 0.08}},
	troll = {base = {"+", -6}, hill = {"*", 1.1}, gain = {"+", -0.04},
		erode = {"+", 0.2}, ridge = {"*", 0.6}},
}

-- Capital ground target band above water, per race. The damping mask and the
-- target are keyed to the civic-core centre (the capital anchor), never to the
-- build envelope (plan guardrail 8).
data.capital_target = {
	dwarf = {24, 70}, human = {14, 40}, elf = {16, 55},
	undead = {14, 45}, orc = {18, 60}, troll = {10, 36},
}

-- Long-wave relief amplitude (nodes, +-) around each race's capital, keyed to
-- the civic core like the target band (D28): the district plots of the WP13
-- blueprints must still stand on it.
data.capital_wave = {
	dwarf = 12, human = 8, elf = 10, undead = 9, orc = 11, troll = 9,
}

-- Mechanism knobs (prototype DEFAULT with the R2 overrides folded in).
data.params = {
	warp = 260, warp_period = 1600,
	hill_period = 1000, hill_octaves = 8, fine = 0.7, crest = 0.45,
	ridge_period = 650, ridge_octaves = 6, ridge_warp = 0.5,
	range_period = 2400, hilly_period = 1600,
	cliff_step = 11,
	blend_cell = 32, blend_radius = 5, blend_passes = 3,
	param_warp = 0.6, landmark_warp = 0.4, anchor_warp = 0.3,
	ridge_mul = 1.5, rshare_add = 0.2, hill_mul = 1.25, rough_mul = 1, base_add = 8,
	start_r_in = 70, start_r_out = 300, start_resid = 0.15,
	-- The capital bowl is calm out to the WP13 district plots (offsets up to
	-- ~240 from the civic core); at r_in 80 their perimeters fell and rose by
	-- up to 40 nodes (Phase 3 integration, seed 15140735923413111218).
	capital_r_in = 260, capital_r_out = 520, capital_resid = 0.08,
	-- D28: long-wave hills and hollows inside the capital calm zone (period
	-- in nodes, faded in between these distances from the civic-core centre;
	-- amplitudes per race in `data.capital_wave`), and the outer edge radius
	-- grown by up to capital_edge (share of r_out) with a noise of this period.
	capital_wave_period = 360, capital_wave_core = 60, capital_wave_full = 180,
	capital_edge = 0.45, capital_edge_period = 420,
	spines = true, spine_warp = 0.7, range_ridge = 210,
	mid = 1.35, neg_compress = 0.5, crest_warp = 0.4, massif_min = 0.75,
	start_band = {6, 36},
	-- Anchor target: mean natural height within this radius, sampled on a grid.
	target_radius = 200, target_step = 40,
	-- Grid extent of the precomputed character and coast-distance grids.
	grid_min_x = -3808, grid_max_x = 3808, grid_min_z = -3424, grid_max_z = 3424,
	coast_cell = 16,
}

-- D13 landmark fields (world_zones.md §8.4). One or two strong soft fields
-- per zone; ids are stable where content or story uses them. Geometry is free
-- (angle in degrees, 0 = +x axis):
--   x, z   centre           L  half length of the axis segment
--   R      half width / radius  A  amplitude in nodes
--   S      escarpment step half width (cliff steepness), default 14
--   side   escarpment high side: +1 left of the axis direction, -1 right
-- Types: basin, lake, dome, ridge, ring, peak, caldera, valley, escarpment, mesa.
-- The order is part of the field (each entry's noise salt is its index).
data.landmarks = {
	{id = "hearthpine_bowl", type = "basin", x = -1800, z = -2480, angle = 20, L = 120, R = 380, A = 14},
	{id = "copperfell_drainage", type = "valley", x = -1690, z = -1900, angle = -11, L = 600, R = 48, A = 22},
	{id = "frostbarrow_escarpment", type = "escarpment", x = -2420, z = -1450, angle = 80, L = 280, R = 220, A = 36, S = 12, side = 1},
	{id = "frostbarrow_tarns", type = "basin", x = -2330, z = -1720, angle = 15, L = 90, R = 110, A = 14},
	{id = "stormvault_arch", type = "ridge", x = -1820, z = -680, angle = 25, L = 380, R = 200, A = 90},
	{id = "dawnmere_headwaters", type = "basin", x = 120, z = -2440, angle = 30, L = 100, R = 160, A = 10},
	{id = "goldmead_millriver", type = "valley", x = -40, z = -2020, angle = 92, L = 260, R = 40, A = 16},
	{id = "whitebridge_crossing", type = "valley", x = -760, z = -1700, angle = 38, L = 420, R = 50, A = 18},
	{id = "ashenward_burnscar", type = "basin", x = 0, z = -720, angle = -15, L = 200, R = 180, A = 16},
	{id = "silverleaf_gladechain", type = "basin", x = 1800, z = -2480, angle = 10, L = 220, R = 150, A = 10},
	{id = "starbough_canopy_steps", type = "escarpment", x = 1950, z = -2050, angle = 120, L = 220, R = 180, A = 28, S = 16, side = 1},
	{id = "lorindor_silverorchards", type = "dome", x = 900, z = -1500, angle = 0, L = 120, R = 260, A = 22},
	{id = "lorindor_berrymarsh", type = "basin", x = 1080, z = -1740, angle = 20, L = 80, R = 130, A = 10},
	{id = "moonfall_crescent", type = "lake", x = 2400, z = -1480, angle = 70, L = 100, R = 120, A = 14},
	{id = "glassroot_pale_cliffs", type = "escarpment", x = 1550, z = -650, angle = 75, L = 300, R = 200, A = 45, S = 10, side = -1},
	{id = "stillgrave_basin", type = "basin", x = -1800, z = 2480, angle = 0, L = 150, R = 380, A = 16},
	{id = "stillgrave_ringbarrows", type = "ring", x = -1800, z = 2480, angle = 0, L = 0, R = 440, A = 10},
	{id = "mournfen_drowned_roads", type = "basin", x = -2000, z = 2080, angle = -25, L = 300, R = 180, A = 10},
	{id = "ossuary_spine", type = "ridge", x = -2420, z = 1450, angle = 80, L = 300, R = 110, A = 55},
	{id = "blackwind_bonearches", type = "ridge", x = -1850, z = 650, angle = -20, L = 220, R = 150, A = 60},
	{id = "blackwind_ashcuts", type = "valley", x = -1350, z = 520, angle = 10, L = 250, R = 35, A = 18},
	{id = "sunscar_waterholes", type = "basin", x = 270, z = 2440, angle = 0, L = 60, R = 110, A = 8},
	{id = "redtusk_gullies", type = "valley", x = -120, z = 2050, angle = 0, L = 260, R = 30, A = 14},
	{id = "speargrass_dryriver", type = "valley", x = -940, z = 1600, angle = -62, L = 330, R = 35, A = 16},
	{id = "speargrass_hunting_stones", type = "mesa", x = -700, z = 1760, angle = 10, L = 60, R = 110, A = 26},
	{id = "bannerbreak_crowned_mesa", type = "mesa", x = 0, z = 650, angle = 5, L = 140, R = 200, A = 45},
	{id = "kapok_worldtree_basin", type = "basin", x = 1800, z = 2480, angle = 0, L = 150, R = 360, A = 14},
	{id = "raincall_falls", type = "escarpment", x = 2020, z = 2080, angle = 45, L = 220, R = 200, A = 40, S = 10, side = 1},
	{id = "whispering_reedmaze", type = "basin", x = 900, z = 1520, angle = 10, L = 220, R = 200, A = 8},
	{id = "totemwater_delta", type = "basin", x = 2400, z = 1500, angle = 90, L = 250, R = 140, A = 8},
	{id = "thunderroot_exposures", type = "escarpment", x = 2050, z = 520, angle = 10, L = 250, R = 160, A = 40, S = 12, side = -1},
	{id = "thunderroot_ochresteps", type = "mesa", x = 1550, z = 680, angle = -30, L = 100, R = 160, A = 35},
	{id = "wyrmglass_ring", type = "caldera", x = -3150, z = 0, angle = 0, L = 0, R = 260, A = 70},
	{id = "wyrmglass_dragonspire", type = "peak", x = -3100, z = -150, angle = 0, L = 0, R = 110, A = 90},
	{id = "gravesalt_whitewall", type = "escarpment", x = -2050, z = 0, angle = 5, L = 330, R = 220, A = 55, S = 10, side = 1},
	{id = "broken_marsh", type = "basin", x = -850, z = 0, angle = 5, L = 380, R = 160, A = 10},
	{id = "shattered_breachwall", type = "ridge", x = 750, z = 0, angle = 8, L = 340, R = 130, A = 34},
	{id = "skyglass_escarpment", type = "escarpment", x = 2050, z = 0, angle = -5, L = 330, R = 220, A = 50, S = 10, side = -1},
	{id = "stormscale_caldera", type = "caldera", x = 3150, z = 0, angle = 0, L = 0, R = 260, A = 70},
	{id = "stormscale_dragonroost", type = "peak", x = 3100, z = -150, angle = 0, L = 0, R = 110, A = 90},
}
-- §8.4 civic features: part of the capital's blueprint and fitting, not a
-- terrain field (the capital damping would flatten one anyway).
data.civic_landmarks = {
	"dur_brannoc_granite_terrace", "dur_brannoc_forge_chasm",
	"highcourt_riverfork", "lethariel_crownlake", "nhal_veyr_necropolis",
	"gor_drazhak_crossmesa", "kezamba_cenote",
}

-- Continental mountain ranges: long spines independent of zones and race. The
-- zone ridge channel only scales how pronounced a range is locally.
--   pts  centreline polyline (warped with the shared domain warp)
--   W    half width in nodes (varied +-30 % by noise); the field reaches 1.3 W
--   A    crest elevation added at full massif; passes drop it to 30 %; the
--        ends taper over 700 nodes
data.ranges = {
	{id = "spine_nw_se", W = 380, A = 120,
		pts = {{-3450, -2150}, {-2700, -1050}, {-1900, -800}, {-1000, -500},
			{0, -100}, {1000, 350}, {1900, 800}, {2700, 1100}, {3450, 2150}}},
	{id = "spine_sw", W = 320, A = 100,
		pts = {{-3400, 2300}, {-2800, 1000}, {-2100, 750}, {-1200, 600}}},
}

return data
