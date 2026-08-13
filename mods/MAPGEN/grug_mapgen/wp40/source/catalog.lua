-- WP40 authored world source. This module is intentionally engine-free: it
-- contains only ordered, integer/rational source records for the later T2
-- geometry compiler. It does not compile displacement, evaluate H, or place
-- content.

local function point(x, z)
	return {x = x, z = z}
end

local function fraction(numerator, denominator)
	return {numerator = numerator, denominator = denominator}
end

local function palette(...)
	return {...}
end

local function biome(id, share)
	return {id = id, share = share}
end

local function zone(numeric_id, id, name, race_region, faction,
		territory_rule, pvp_rule, level_min, level_max, relief_id,
		biomes, civic)
	return {
		numeric_id = numeric_id,
		id = id,
		display_name = name,
		race_region = race_region,
		faction = faction,
		territory_rule = territory_rule,
		pvp_rule = pvp_rule,
		level_min = level_min,
		level_max = level_max,
		primary_relief_id = relief_id,
		biomes = biomes,
		civic_no_hostiles = civic,
	}
end

local source = {
	schema = "grug_wp40_authored_source_v1",
	section_order = {
		"critical_source_manifest", "constants", "relief_profiles",
		"route_classes", "water_classes",
		"landmark_role_vocabulary", "template_primitives", "zones",
		"land_edges", "route_stations", "routes", "route_interfaces",
		"route_crossing_interfaces", "boat_edges", "island_landings",
		"island_route_stations", "island_routes", "island_route_interfaces",
		"perimeters", "bays", "islands", "channels", "landmarks", "anchors", "templates",
		"template_compositions", "hydrology", "hydrology_interfaces",
		"housing_masks", "coastal_housing_cores", "semantics",
	},
}

-- Semantic source authority for the engine-facing settings that participate
-- in the vertical native-dungeon preservation proof. Flag records model the
-- closed bitsets themselves; they intentionally do not copy negative
-- settings-string spellings.
source.critical_source_manifest = {
	id = "critical_source_manifest",
	schema = "grug_wp40_critical_source_manifest_v1",
	mg_name = "v7",
	water_level = 1,
	chunksize = 5,
	num_emerge_threads = 1,
	mg_flags = {
		"dungeons", "biomes", "caves", "ores", "decorations", "light",
	},
	mgv7_special_flags = {
		{id = "mountains", enabled = true},
		{id = "ridges", enabled = true},
		{id = "floatlands", enabled = false},
		{id = "caverns", enabled = true},
	},
	mgv7_dungeon_ymin = -31000,
	mgv7_dungeon_ymax = -193,
	mgv7_np_dungeons = {
		offset = fraction(9, 10),
		scale = fraction(1, 2),
		spread = {x = 500, y = 500, z = 500},
		seed = 0,
		octaves = 2,
		persistence = fraction(4, 5),
		lacunarity = 2,
		flags = {"defaults"},
	},
	broad_content_y_min = -37,
	force_native_dungeon = false,
}

source.constants = {
	q = 65536,
	mainland_frame = {min_x = -2600, max_x = 2600, min_z = -3000, max_z = 3000},
	holy_grounds = {min_x = -2500, max_x = 2500, min_z = -250, max_z = 250},
	holy_junction_x = {-1500, 0, 1500},
	elandor_belt = {min_z = -1900, max_z = -1100},
	kragmar_belt = {min_z = 1100, max_z = 1900},
	elandor_frontier = {min_z = -1100, max_z = -250},
	kragmar_frontier = {min_z = 250, max_z = 1100},
	ordinary_boundary_displacement = 64,
	peace_contested_displacement = 32,
	coast_displacement = 96,
	bay_displacement = 48,
	boundary_min_wavelength = 256,
	anchor_no_jitter_radius = 96,
	minimum_zone_core = 256,
	minimum_travel_corridor = 96,
	coastal_shelf_width = 80,
	flight_warning_width = 48,
	minimum_dragon_channel = 200,
	minimum_hard_flight_width = 104,
	dragon_approach_width = 96,
	dragon_approach_z = {-125, 125},
	shallow_protection_floor = -700,
	contested_deep_ceiling = -701,
	spatial_index_cell = 128,
	native_displacement_limit = 16,
	surface_repair_clearance = 16,
	decoration_light_radius = 15,
	authored_vein_cell = 16,
	housing_reservation_width = 101,
	housing_reservation_radius = 50,
	housing_relief_limit = 12,
	housing_frontage_min = 600,
	housing_depth_min = 300,
	capital_build_width = 512,
	capital_blend_width = 704,
	capital_civic_core_width = 96,
	capital_gate_width = 32,
	capital_protection_apron = 10,
	start_build_width = 128,
	start_blend_width = 256,
	start_dry_core_width = 600,
	start_dry_core_depth = 500,
	island_envelope_width = 600,
	island_envelope_depth = 700,
	island_route_parity = fraction(1, 10),
	outer_coast_noise_period = 512,
	ordinary_boundary_noise_period = 384,
	bay_noise_period = 256,
}

source.relief_profiles = {
	{id = "wetland_delta", min_above_water = 2, max_above_water = 24,
		noise_domain = "relief_wetland_delta", octaves = {
			{period = 512, amplitude = fraction(3, 5)},
			{period = 256, amplitude = fraction(2, 5)},
		}},
	{id = "lowland", min_above_water = 8, max_above_water = 56,
		noise_domain = "relief_lowland", octaves = {
			{period = 768, amplitude = fraction(2, 3)},
			{period = 256, amplitude = fraction(1, 3)},
		}},
	{id = "rolling_hills", min_above_water = 24, max_above_water = 96,
		noise_domain = "relief_rolling_hills", octaves = {
			{period = 768, amplitude = fraction(3, 5)},
			{period = 384, amplitude = fraction(2, 5)},
		}},
	{id = "plateau", min_above_water = 56, max_above_water = 144,
		noise_domain = "relief_plateau", octaves = {
			{period = 1024, amplitude = fraction(3, 4)},
			{period = 384, amplitude = fraction(1, 4)},
		}},
	{id = "highland", min_above_water = 96, max_above_water = 224,
		noise_domain = "relief_highland", octaves = {
			{period = 1024, amplitude = fraction(2, 3)},
			{period = 512, amplitude = fraction(1, 3)},
		}},
	{id = "mountain", min_above_water = 160, max_above_water = 360,
		noise_domain = "relief_mountain", octaves = {
			{period = 1280, amplitude = fraction(3, 5)},
			{period = 640, amplitude = fraction(3, 10)},
			{period = 320, amplitude = fraction(1, 10)},
		}},
}

source.route_classes = {
	{id = "primary", visible_width = 7, exclusion_width = 16,
		max_cut = 8, max_fill = 6, tunnel_lumen_width = 9,
		tunnel_clear_height = 5},
	{id = "secondary", visible_width = 5, exclusion_width = 12,
		max_cut = 6, max_fill = 4, tunnel_lumen_width = 7,
		tunnel_clear_height = 5},
	{id = "trail", visible_width = 3, exclusion_width = 8,
		max_cut = 3, max_fill = 2, tunnel_lumen_width = 5,
		tunnel_clear_height = 5},
}

source.water_classes = {
	{id = "land", authored_source = false, full_column_immutable = false},
	{id = "planned_water", authored_source = true, full_column_immutable = false},
	{id = "coastal_shelf", authored_source = true, full_column_immutable = false},
	{id = "deep_ocean", authored_source = true, full_column_immutable = true},
	{id = "immutable_dragon_channel", authored_source = true,
		full_column_immutable = true},
}

source.landmark_role_vocabulary = {
	"base_H", "target_T", "hydrology", "route", "interface", "dressing",
}

source.template_primitives = {
	{id="flat",version=1,parameters={"height_offset"}},
	{id="tilt",version=1,parameters={"axis_x","axis_z","rise","run"}},
	{id="terrace",version=1,parameters={"step_height","step_run","rings"}},
	{id="plateau",version=1,parameters={"inner_radius","shoulder_width"}},
	{id="basin",version=1,parameters={"inner_radius","depth","rim_width"}},
	{id="rim",version=1,parameters={"inner_radius","outer_radius","height"}},
	{id="causeway",version=1,parameters={"surface_width","backing_depth"}},
	{id="cross_section",version=1,parameters={"surface_width","corridor_width"}},
	{id="housing_smoothing",version=1,parameters={"radius","relief_limit"}},
}

source.zones = {
	zone(1, "elandor_hearthpine_vale", "Hearthpine Vale", "dwarf", "accord", "accord_home", "peaceful", 1, 10, "lowland", palette(biome("grug_pine_hills", 90), biome("grug_crags", 10)), false),
	zone(2, "elandor_copperfell_foothills", "Copperfell Foothills", "dwarf", "accord", "accord_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_pine_hills", 75), biome("grug_crags", 25)), false),
	zone(3, "elandor_dur_brannoc", "Dur Brannoc", "dwarf", "accord", "accord_home", "peaceful", 20, 30, "plateau", palette(biome("grug_pine_hills", 60), biome("grug_crags", 40)), true),
	zone(4, "elandor_frostbarrow_shelf", "Frostbarrow Shelf", "dwarf", "accord", "accord_home", "peaceful", 21, 30, "plateau", palette(biome("grug_pine_hills", 55), biome("grug_crags", 40), biome("grug_swamp", 5)), false),
	zone(5, "elandor_stormvault_heights", "Stormvault Heights", "dwarf", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_crags", 75), biome("grug_crags_snowy", 25)), false),
	zone(6, "elandor_dawnmere_fields", "Dawnmere Fields", "human", "accord", "accord_home", "peaceful", 1, 10, "lowland", palette(biome("grug_meadows", 85), biome("grug_deep_forest", 5), biome("grug_swamp", 10)), false),
	zone(7, "elandor_goldmead_vale", "Goldmead Vale", "human", "accord", "accord_home", "peaceful", 11, 20, "lowland", palette(biome("grug_meadows", 65), biome("grug_deep_forest", 20), biome("grug_swamp", 15)), false),
	zone(8, "elandor_highcourt", "Highcourt", "human", "accord", "accord_home", "peaceful", 20, 30, "rolling_hills", palette(biome("grug_meadows", 80), biome("grug_deep_forest", 20)), true),
	zone(9, "elandor_whitebridge_shire", "Whitebridge Shire", "human", "accord", "accord_home", "peaceful", 21, 30, "lowland", palette(biome("grug_meadows", 50), biome("grug_deep_forest", 35), biome("grug_swamp", 15)), false),
	zone(10, "elandor_ashenward_march", "Ashenward March", "human", false, "contested_land", "contested", 31, 40, "rolling_hills", palette(biome("grug_deep_forest", 50), biome("grug_meadows", 30), biome("grug_swamp", 20)), false),
	zone(11, "elandor_silverleaf_glades", "Silverleaf Glades", "elf", "accord", "accord_home", "peaceful", 1, 10, "lowland", palette(biome("grug_elf_forest", 95), biome("grug_deep_forest", 5)), false),
	zone(12, "elandor_starbough_vale", "Starbough Vale", "elf", "accord", "accord_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_elf_forest", 80), biome("grug_deep_forest", 20)), false),
	zone(13, "elandor_lethariel", "Lethariel", "elf", "accord", "accord_home", "peaceful", 20, 30, "rolling_hills", palette(biome("grug_elf_forest", 90), biome("grug_deep_forest", 10)), true),
	zone(14, "elandor_lorindor", "Lorindor", "elf", "accord", "accord_home", "peaceful", 21, 30, "rolling_hills", palette(biome("grug_elf_forest", 50), biome("grug_deep_forest", 30), biome("grug_swamp", 20)), false),
	zone(15, "elandor_moonfall_wood", "Moonfall Wood", "elf", "accord", "accord_home", "peaceful", 21, 30, "lowland", palette(biome("grug_elf_forest", 40), biome("grug_deep_forest", 45), biome("grug_swamp", 15)), false),
	zone(16, "elandor_glassroot_wilds", "Glassroot Wilds", "elf", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_deep_forest", 45), biome("grug_jungle_fringe", 35), biome("grug_elf_forest", 10), biome("grug_swamp", 10)), false),
	zone(17, "kragmar_stillgrave_hollow", "Stillgrave Hollow", "undead", "throng", "throng_home", "peaceful", 1, 10, "lowland", palette(biome("grug_blight", 90), biome("grug_bone_forest", 5), biome("grug_swamp", 5)), false),
	zone(18, "kragmar_mournfen", "Mournfen", "undead", "throng", "throng_home", "peaceful", 11, 20, "wetland_delta", palette(biome("grug_blight", 60), biome("grug_bone_forest", 10), biome("grug_swamp", 30)), false),
	zone(19, "kragmar_nhal_veyr", "Nhal Veyr", "undead", "throng", "throng_home", "peaceful", 20, 30, "plateau", palette(biome("grug_blight", 75), biome("grug_bone_forest", 25)), true),
	zone(20, "kragmar_ossuary_reach", "Ossuary Reach", "undead", "throng", "throng_home", "peaceful", 21, 30, "rolling_hills", palette(biome("grug_blight", 40), biome("grug_bone_forest", 50), biome("grug_swamp", 10)), false),
	zone(21, "kragmar_blackwind_rise", "Blackwind Rise", "undead", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_bone_forest", 65), biome("grug_blight", 30), biome("grug_swamp", 5)), false),
	zone(22, "kragmar_sunscar_flats", "Sunscar Flats", "orc", "throng", "throng_home", "peaceful", 1, 10, "lowland", palette(biome("grug_savanna", 95), biome("grug_badlands", 5)), false),
	zone(23, "kragmar_redtusk_savanna", "Redtusk Savanna", "orc", "throng", "throng_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_savanna", 75), biome("grug_badlands", 25)), false),
	zone(24, "kragmar_gor_drazhak", "Gor Drazhak", "orc", "throng", "throng_home", "peaceful", 20, 30, "plateau", palette(biome("grug_savanna", 60), biome("grug_badlands", 40)), true),
	zone(25, "kragmar_speargrass_reach", "Speargrass Reach", "orc", "throng", "throng_home", "peaceful", 21, 30, "rolling_hills", palette(biome("grug_savanna", 55), biome("grug_badlands", 40), biome("grug_swamp", 5)), false),
	zone(26, "kragmar_bannerbreak_mesa", "Bannerbreak Mesa", "orc", false, "contested_land", "contested", 31, 40, "plateau", palette(biome("grug_badlands", 70), biome("grug_savanna", 25), biome("grug_swamp", 5)), false),
	zone(27, "kragmar_kapok_cradle", "Kapok Cradle", "troll", "throng", "throng_home", "peaceful", 1, 10, "lowland", palette(biome("grug_jungle_edge", 90), biome("grug_swamp", 10)), false),
	zone(28, "kragmar_raincall_basin", "Raincall Basin", "troll", "throng", "throng_home", "peaceful", 11, 20, "rolling_hills", palette(biome("grug_jungle_edge", 65), biome("grug_deep_jungle", 15), biome("grug_swamp", 20)), false),
	zone(29, "kragmar_kezamba", "Kezamba", "troll", "throng", "throng_home", "peaceful", 20, 30, "plateau", palette(biome("grug_jungle_edge", 75), biome("grug_deep_jungle", 20), biome("grug_swamp", 5)), true),
	zone(30, "kragmar_whispering_reedlands", "Whispering Reedlands", "troll", "throng", "throng_home", "peaceful", 21, 30, "wetland_delta", palette(biome("grug_jungle_edge", 45), biome("grug_deep_jungle", 25), biome("grug_swamp", 30)), false),
	zone(31, "kragmar_totemwater_reach", "Totemwater Reach", "troll", "throng", "throng_home", "peaceful", 21, 30, "wetland_delta", palette(biome("grug_jungle_edge", 35), biome("grug_deep_jungle", 45), biome("grug_swamp", 20)), false),
	zone(32, "kragmar_thunderroot_wilds", "Thunderroot Wilds", "troll", false, "contested_land", "contested", 31, 40, "highland", palette(biome("grug_deep_jungle", 55), biome("grug_badlands_east", 30), biome("grug_swamp", 15)), false),
	zone(33, "front_wyrmglass_crown", "The Wyrmglass Crown", "dwarf", false, "contested_land", "contested", 60, 60, "mountain", palette(biome("grug_crags", 55), biome("grug_crags_snowy", 30), biome("grug_beach", 15)), false),
	zone(34, "front_gravesalt_escarpment", "Gravesalt Escarpment", "undead", false, "holy_grounds", "contested", 51, 59, "highland", palette(biome("grug_bone_forest", 55), biome("grug_blight", 15), biome("grug_swamp", 15), biome("grug_beach", 15)), false),
	zone(35, "front_broken_causeway", "The Broken Causeway", "human", false, "holy_grounds", "contested", 31, 40, "wetland_delta", palette(biome("grug_meadows", 40), biome("grug_deep_forest", 25), biome("grug_swamp", 35)), false),
	zone(36, "front_shattered_line", "The Shattered Line", "orc", false, "holy_grounds", "contested", 41, 50, "plateau", palette(biome("grug_badlands", 65), biome("grug_savanna", 20), biome("grug_swamp", 15)), false),
	zone(37, "front_skyglass_canopy", "The Skyglass Canopy", "elf", false, "holy_grounds", "contested", 51, 59, "highland", palette(biome("grug_jungle_fringe", 60), biome("grug_deep_forest", 25), biome("grug_elf_forest", 15)), false),
	zone(38, "front_stormscale_summit", "Stormscale Summit", "troll", false, "contested_land", "contested", 60, 60, "mountain", palette(biome("grug_deep_jungle", 50), biome("grug_badlands_east", 20), biome("grug_swamp", 15), biome("grug_beach", 15)), false),
}

local function edge(numeric_id, a, b, route_class, displacement, controls)
	return {
		numeric_id = numeric_id,
		id = ("land_%03d"):format(numeric_id),
		zone_a = a,
		zone_b = b,
		max_displacement = displacement,
		noise_domain = ("boundary_land_%03d"):format(numeric_id),
		control = controls,
	}
end

-- Land boundaries own adjacency and boundary shape only. Route class and road
-- geometry are separate authorities below; the fourth literal argument above
-- is retained solely to make the fixed §9.4 class list readable beside the
-- fixed adjacency list and is deliberately not copied into a boundary record.

source.land_edges = {
	-- Six race spines. The start/home records retain every fixed §7 vertex.
	edge(1, "elandor_hearthpine_vale", "elandor_copperfell_foothills", "primary", 64, {point(-2700,-2760),point(-2310,-2570),point(-2150,-2210),point(-1800,-2140),point(-1450,-2210),point(-1050,-2250)}),
	edge(2, "elandor_copperfell_foothills", "elandor_dur_brannoc", "primary", 64, {point(-2200,-1900),point(-1400,-1900)}),
	edge(3, "elandor_dur_brannoc", "elandor_stormvault_heights", "primary", 32, {point(-2200,-1100),point(-1400,-1100)}),
	edge(4, "elandor_dawnmere_fields", "elandor_goldmead_vale", "primary", 64, {point(-1050,-2250),point(-650,-2230),point(-350,-2170),point(0,-2120),point(350,-2180),point(650,-2240),point(950,-2250)}),
	edge(5, "elandor_goldmead_vale", "elandor_highcourt", "primary", 64, {point(-400,-1900),point(400,-1900)}),
	edge(6, "elandor_highcourt", "elandor_ashenward_march", "primary", 32, {point(-400,-1100),point(400,-1100)}),
	edge(7, "elandor_silverleaf_glades", "elandor_starbough_vale", "primary", 64, {point(950,-2250),point(1450,-2210),point(1800,-2150),point(2150,-2230),point(2310,-2580),point(2700,-2740)}),
	edge(8, "elandor_starbough_vale", "elandor_lethariel", "primary", 64, {point(1400,-1900),point(2200,-1900)}),
	edge(9, "elandor_lethariel", "elandor_glassroot_wilds", "primary", 32, {point(1400,-1100),point(2200,-1100)}),
	edge(10, "kragmar_stillgrave_hollow", "kragmar_mournfen", "primary", 64, {point(-2700,2740),point(-2320,2580),point(-2160,2210),point(-1800,2140),point(-1440,2200),point(-970,2260)}),
	edge(11, "kragmar_mournfen", "kragmar_nhal_veyr", "primary", 64, {point(-2200,1900),point(-1400,1900)}),
	edge(12, "kragmar_nhal_veyr", "kragmar_blackwind_rise", "primary", 32, {point(-2200,1100),point(-1400,1100)}),
	edge(13, "kragmar_sunscar_flats", "kragmar_redtusk_savanna", "primary", 64, {point(-970,2260),point(-660,2240),point(-360,2180),point(0,2130),point(360,2190),point(680,2230),point(1020,2250)}),
	edge(14, "kragmar_redtusk_savanna", "kragmar_gor_drazhak", "primary", 64, {point(-400,1900),point(400,1900)}),
	edge(15, "kragmar_gor_drazhak", "kragmar_bannerbreak_mesa", "primary", 32, {point(-400,1100),point(400,1100)}),
	edge(16, "kragmar_kapok_cradle", "kragmar_raincall_basin", "primary", 64, {point(1020,2250),point(1440,2200),point(1800,2140),point(2160,2210),point(2320,2590),point(2700,2760)}),
	edge(17, "kragmar_raincall_basin", "kragmar_kezamba", "primary", 64, {point(1400,1900),point(2200,1900)}),
	edge(18, "kragmar_kezamba", "kragmar_thunderroot_wilds", "primary", 32, {point(1400,1100),point(2200,1100)}),
	-- The two six-edge capital axes.
	edge(19, "elandor_frostbarrow_shelf", "elandor_dur_brannoc", "primary", 64, {point(-2200,-1900),point(-2200,-1100)}),
	edge(20, "elandor_dur_brannoc", "elandor_whitebridge_shire", "primary", 64, {point(-1400,-1900),point(-1400,-1100)}),
	edge(21, "elandor_whitebridge_shire", "elandor_highcourt", "primary", 64, {point(-400,-1900),point(-400,-1100)}),
	edge(22, "elandor_highcourt", "elandor_lorindor", "primary", 64, {point(400,-1900),point(400,-1100)}),
	edge(23, "elandor_lorindor", "elandor_lethariel", "primary", 64, {point(1400,-1900),point(1400,-1100)}),
	edge(24, "elandor_lethariel", "elandor_moonfall_wood", "primary", 64, {point(2200,-1900),point(2200,-1100)}),
	edge(25, "kragmar_ossuary_reach", "kragmar_nhal_veyr", "primary", 64, {point(-2200,1100),point(-2200,1900)}),
	edge(26, "kragmar_nhal_veyr", "kragmar_speargrass_reach", "primary", 64, {point(-1400,1100),point(-1400,1900)}),
	edge(27, "kragmar_speargrass_reach", "kragmar_gor_drazhak", "primary", 64, {point(-400,1100),point(-400,1900)}),
	edge(28, "kragmar_gor_drazhak", "kragmar_whispering_reedlands", "primary", 64, {point(400,1100),point(400,1900)}),
	edge(29, "kragmar_whispering_reedlands", "kragmar_kezamba", "primary", 64, {point(1400,1100),point(1400,1900)}),
	edge(30, "kragmar_kezamba", "kragmar_totemwater_reach", "primary", 64, {point(2200,1100),point(2200,1900)}),
	-- Heartland/front cross-links. The separator polylines preserve all fixed
	-- belt/front/Holy vertices and are shared by their incident zones.
	edge(31, "elandor_frostbarrow_shelf", "elandor_stormvault_heights", "secondary", 32, {point(-2600,-1100),point(-2200,-1100)}),
	edge(32, "elandor_whitebridge_shire", "elandor_ashenward_march", "secondary", 32, {point(-1400,-1100),point(-400,-1100)}),
	edge(33, "elandor_lorindor", "elandor_glassroot_wilds", "secondary", 32, {point(400,-1100),point(1400,-1100)}),
	edge(34, "elandor_moonfall_wood", "elandor_glassroot_wilds", "secondary", 32, {point(2200,-1100),point(2600,-1100)}),
	edge(35, "elandor_stormvault_heights", "elandor_ashenward_march", "secondary", 64, {point(-1400,-1100),point(-900,-900),point(-750,-250)}),
	edge(36, "elandor_ashenward_march", "elandor_glassroot_wilds", "secondary", 64, {point(400,-1100),point(900,-900),point(750,-250)}),
	edge(37, "kragmar_ossuary_reach", "kragmar_blackwind_rise", "secondary", 32, {point(-2600,1100),point(-2200,1100)}),
	edge(38, "kragmar_speargrass_reach", "kragmar_bannerbreak_mesa", "secondary", 32, {point(-1400,1100),point(-400,1100)}),
	edge(39, "kragmar_whispering_reedlands", "kragmar_thunderroot_wilds", "secondary", 32, {point(400,1100),point(1400,1100)}),
	edge(40, "kragmar_totemwater_reach", "kragmar_thunderroot_wilds", "secondary", 32, {point(2200,1100),point(2600,1100)}),
	edge(41, "kragmar_blackwind_rise", "kragmar_bannerbreak_mesa", "secondary", 64, {point(-1400,1100),point(-900,900),point(-750,250)}),
	edge(42, "kragmar_bannerbreak_mesa", "kragmar_thunderroot_wilds", "secondary", 64, {point(400,1100),point(900,900),point(750,250)}),
	-- Twelve fixed mainland/Holy contacts. Their z = +/-250 geometry has no
	-- jitter because it is the exact no-jitter Holy rectangle boundary.
	edge(43, "elandor_stormvault_heights", "front_gravesalt_escarpment", "secondary", 0, {point(-2500,-250),point(-1500,-250)}),
	edge(44, "elandor_stormvault_heights", "front_broken_causeway", "secondary", 0, {point(-1500,-250),point(-750,-250)}),
	edge(45, "elandor_ashenward_march", "front_broken_causeway", "secondary", 0, {point(-750,-250),point(0,-250)}),
	edge(46, "elandor_ashenward_march", "front_shattered_line", "secondary", 0, {point(0,-250),point(750,-250)}),
	edge(47, "elandor_glassroot_wilds", "front_shattered_line", "secondary", 0, {point(750,-250),point(1500,-250)}),
	edge(48, "elandor_glassroot_wilds", "front_skyglass_canopy", "secondary", 0, {point(1500,-250),point(2500,-250)}),
	edge(49, "kragmar_blackwind_rise", "front_gravesalt_escarpment", "secondary", 0, {point(-2500,250),point(-1500,250)}),
	edge(50, "kragmar_blackwind_rise", "front_broken_causeway", "secondary", 0, {point(-1500,250),point(-750,250)}),
	edge(51, "kragmar_bannerbreak_mesa", "front_broken_causeway", "secondary", 0, {point(-750,250),point(0,250)}),
	edge(52, "kragmar_bannerbreak_mesa", "front_shattered_line", "secondary", 0, {point(0,250),point(750,250)}),
	edge(53, "kragmar_thunderroot_wilds", "front_shattered_line", "secondary", 0, {point(750,250),point(1500,250)}),
	edge(54, "kragmar_thunderroot_wilds", "front_skyglass_canopy", "secondary", 0, {point(1500,250),point(2500,250)}),
	-- The three internal Holy boundaries carry the required west/east trails.
	edge(55, "front_gravesalt_escarpment", "front_broken_causeway", "trail", 64, {point(-1500,-250),point(-1500,0),point(-1500,250)}),
	edge(56, "front_broken_causeway", "front_shattered_line", "trail", 64, {point(0,-250),point(0,0),point(0,250)}),
	edge(57, "front_shattered_line", "front_skyglass_canopy", "trail", 64, {point(1500,-250),point(1500,0),point(1500,250)}),
}

local function station(id, zone_id, kind, x, z, gate_ref)
	return {id=id,zone_id=zone_id,kind=kind,position=point(x,z),
		gate_ref=gate_ref or false}
end

-- Stable route stations are the complete route endpoints. Ordinary zone hubs
-- are conservative implementation data near the authored zone cores. Start
-- and capital routes terminate at their exact external gate stations instead
-- of allowing the later compiler to choose an approach from terrain.
source.route_stations = {
	station("station:elandor_hearthpine_vale:hub","elandor_hearthpine_vale","hub",-1800,-2550),
	station("station:elandor_copperfell_foothills:hub","elandor_copperfell_foothills","hub",-1800,-2050),
	station("station:elandor_dur_brannoc:hub","elandor_dur_brannoc","hub",-1800,-1500),
	station("station:elandor_frostbarrow_shelf:hub","elandor_frostbarrow_shelf","hub",-2400,-1500),
	station("station:elandor_stormvault_heights:hub","elandor_stormvault_heights","hub",-1800,-700),
	station("station:elandor_dawnmere_fields:hub","elandor_dawnmere_fields","hub",0,-2550),
	station("station:elandor_goldmead_vale:hub","elandor_goldmead_vale","hub",0,-2050),
	station("station:elandor_highcourt:hub","elandor_highcourt","hub",0,-1500),
	station("station:elandor_whitebridge_shire:hub","elandor_whitebridge_shire","hub",-900,-1500),
	station("station:elandor_ashenward_march:hub","elandor_ashenward_march","hub",0,-700),
	station("station:elandor_silverleaf_glades:hub","elandor_silverleaf_glades","hub",1800,-2550),
	station("station:elandor_starbough_vale:hub","elandor_starbough_vale","hub",1800,-2050),
	station("station:elandor_lethariel:hub","elandor_lethariel","hub",1800,-1500),
	station("station:elandor_lorindor:hub","elandor_lorindor","hub",900,-1500),
	station("station:elandor_moonfall_wood:hub","elandor_moonfall_wood","hub",2400,-1500),
	station("station:elandor_glassroot_wilds:hub","elandor_glassroot_wilds","hub",1800,-700),
	station("station:kragmar_stillgrave_hollow:hub","kragmar_stillgrave_hollow","hub",-1800,2550),
	station("station:kragmar_mournfen:hub","kragmar_mournfen","hub",-1800,2050),
	station("station:kragmar_nhal_veyr:hub","kragmar_nhal_veyr","hub",-1800,1500),
	station("station:kragmar_ossuary_reach:hub","kragmar_ossuary_reach","hub",-2400,1500),
	station("station:kragmar_blackwind_rise:hub","kragmar_blackwind_rise","hub",-1800,700),
	station("station:kragmar_sunscar_flats:hub","kragmar_sunscar_flats","hub",0,2550),
	station("station:kragmar_redtusk_savanna:hub","kragmar_redtusk_savanna","hub",0,2050),
	station("station:kragmar_gor_drazhak:hub","kragmar_gor_drazhak","hub",0,1500),
	station("station:kragmar_speargrass_reach:hub","kragmar_speargrass_reach","hub",-900,1500),
	station("station:kragmar_bannerbreak_mesa:hub","kragmar_bannerbreak_mesa","hub",0,700),
	station("station:kragmar_kapok_cradle:hub","kragmar_kapok_cradle","hub",1800,2550),
	station("station:kragmar_raincall_basin:hub","kragmar_raincall_basin","hub",1800,2050),
	station("station:kragmar_kezamba:hub","kragmar_kezamba","hub",1800,1500),
	station("station:kragmar_whispering_reedlands:hub","kragmar_whispering_reedlands","hub",900,1500),
	station("station:kragmar_totemwater_reach:hub","kragmar_totemwater_reach","hub",2400,1500),
	station("station:kragmar_thunderroot_wilds:hub","kragmar_thunderroot_wilds","hub",1800,700),
	station("station:front_wyrmglass_crown:hub","front_wyrmglass_crown","hub",-3150,0),
	station("station:front_gravesalt_escarpment:hub","front_gravesalt_escarpment","hub",-2000,0),
	station("station:front_broken_causeway:hub","front_broken_causeway","hub",-750,0),
	station("station:front_shattered_line:hub","front_shattered_line","hub",750,0),
	station("station:front_skyglass_canopy:hub","front_skyglass_canopy","hub",2000,0),
	station("station:front_stormscale_summit:hub","front_stormscale_summit","hub",3150,0),
	station("station:elandor_hearthpine_vale:start_north","elandor_hearthpine_vale","start_gate",-1800,-2486,"start:north"),
	station("station:elandor_dawnmere_fields:start_north","elandor_dawnmere_fields","start_gate",0,-2486,"start:north"),
	station("station:elandor_silverleaf_glades:start_north","elandor_silverleaf_glades","start_gate",1800,-2486,"start:north"),
	station("station:kragmar_stillgrave_hollow:start_south","kragmar_stillgrave_hollow","start_gate",-1800,2486,"start:south"),
	station("station:kragmar_sunscar_flats:start_south","kragmar_sunscar_flats","start_gate",0,2486,"start:south"),
	station("station:kragmar_kapok_cradle:start_south","kragmar_kapok_cradle","start_gate",1800,2486,"start:south"),
}

local capital_centers={{"elandor_dur_brannoc",-1800,-1500},{"elandor_highcourt",0,-1500},{"elandor_lethariel",1800,-1500},{"kragmar_nhal_veyr",-1800,1500},{"kragmar_gor_drazhak",0,1500},{"kragmar_kezamba",1800,1500}}
for capital_index=1,#capital_centers do local row=capital_centers[capital_index]
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_north",row[1],"capital_gate",row[2],row[3]+256,"capital:north")
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_south",row[1],"capital_gate",row[2],row[3]-256,"capital:south")
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_east",row[1],"capital_gate",row[2]+256,row[3],"capital:east")
	source.route_stations[#source.route_stations+1]=station("station:"..row[1]..":capital_west",row[1],"capital_gate",row[2]-256,row[3],"capital:west")
end

local endpoint_gate_refs = {
	elandor_hearthpine_vale="start:north",elandor_dawnmere_fields="start:north",
	elandor_silverleaf_glades="start:north",kragmar_stillgrave_hollow="start:south",
	kragmar_sunscar_flats="start:south",kragmar_kapok_cradle="start:south",
}
local capital_gate_refs={
	["elandor_dur_brannoc\0elandor_copperfell_foothills"]="capital:south",["elandor_dur_brannoc\0elandor_stormvault_heights"]="capital:north",["elandor_dur_brannoc\0elandor_frostbarrow_shelf"]="capital:west",["elandor_dur_brannoc\0elandor_whitebridge_shire"]="capital:east",
	["elandor_highcourt\0elandor_goldmead_vale"]="capital:south",["elandor_highcourt\0elandor_ashenward_march"]="capital:north",["elandor_highcourt\0elandor_whitebridge_shire"]="capital:west",["elandor_highcourt\0elandor_lorindor"]="capital:east",
	["elandor_lethariel\0elandor_starbough_vale"]="capital:south",["elandor_lethariel\0elandor_glassroot_wilds"]="capital:north",["elandor_lethariel\0elandor_lorindor"]="capital:west",["elandor_lethariel\0elandor_moonfall_wood"]="capital:east",
	["kragmar_nhal_veyr\0kragmar_mournfen"]="capital:north",["kragmar_nhal_veyr\0kragmar_blackwind_rise"]="capital:south",["kragmar_nhal_veyr\0kragmar_ossuary_reach"]="capital:west",["kragmar_nhal_veyr\0kragmar_speargrass_reach"]="capital:east",
	["kragmar_gor_drazhak\0kragmar_redtusk_savanna"]="capital:north",["kragmar_gor_drazhak\0kragmar_bannerbreak_mesa"]="capital:south",["kragmar_gor_drazhak\0kragmar_speargrass_reach"]="capital:west",["kragmar_gor_drazhak\0kragmar_whispering_reedlands"]="capital:east",
	["kragmar_kezamba\0kragmar_raincall_basin"]="capital:north",["kragmar_kezamba\0kragmar_thunderroot_wilds"]="capital:south",["kragmar_kezamba\0kragmar_whispering_reedlands"]="capital:west",["kragmar_kezamba\0kragmar_totemwater_reach"]="capital:east",
}

local function sign_direction(dx, dz)
	local east_west = dx > 0 and "east" or (dx < 0 and "west" or "")
	local north_south = dz > 0 and "north" or (dz < 0 and "south" or "")
	if east_west ~= "" and north_south ~= "" then
		return north_south .. "_" .. east_west
	end
	return east_west ~= "" and east_west or north_south
end

-- Authored route crossings are independent source geometry. Each crossing is
-- joined to its two explicit stable stations below, producing the complete
-- ordered control path consumed by one-node station rasterization. No later
-- compiler chooses endpoints, follows a boundary, or invents an approach.
local route_geometry = {
	{crossing=point(-1975,-2175),approach_dx=96,approach_dz=-96},{crossing=point(-1800,-1900),approach_dx=0,approach_dz=-96},{crossing=point(-1800,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-175,-2145),approach_dx=96,approach_dz=-96},{crossing=point(0,-1900),approach_dx=0,approach_dz=-96},{crossing=point(0,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(1975,-2190),approach_dx=-96,approach_dz=-96},{crossing=point(1800,-1900),approach_dx=0,approach_dz=-96},{crossing=point(1800,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-1980,2175),approach_dx=-96,approach_dz=-96},{crossing=point(-1800,1900),approach_dx=0,approach_dz=-96},{crossing=point(-1800,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-180,2155),approach_dx=-96,approach_dz=-96},{crossing=point(0,1900),approach_dx=0,approach_dz=-96},{crossing=point(0,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(1980,2175),approach_dx=96,approach_dz=-96},{crossing=point(1800,1900),approach_dx=0,approach_dz=-96},{crossing=point(1800,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-2200,-1500),approach_dx=96,approach_dz=0},{crossing=point(-1400,-1500),approach_dx=96,approach_dz=0},{crossing=point(-400,-1500),approach_dx=96,approach_dz=0},
	{crossing=point(400,-1500),approach_dx=96,approach_dz=0},{crossing=point(1400,-1500),approach_dx=96,approach_dz=0},{crossing=point(2200,-1500),approach_dx=96,approach_dz=0},
	{crossing=point(-2200,1500),approach_dx=96,approach_dz=0},{crossing=point(-1400,1500),approach_dx=96,approach_dz=0},{crossing=point(-400,1500),approach_dx=96,approach_dz=0},
	{crossing=point(400,1500),approach_dx=96,approach_dz=0},{crossing=point(1400,1500),approach_dx=96,approach_dz=0},{crossing=point(2200,1500),approach_dx=96,approach_dz=0},
	{crossing=point(-2400,-1100),approach_dx=0,approach_dz=-96},{crossing=point(-900,-1100),approach_dx=0,approach_dz=-96},{crossing=point(900,-1100),approach_dx=0,approach_dz=-96},{crossing=point(2400,-1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-1150,-1000),approach_dx=96,approach_dz=-96},{crossing=point(650,-1000),approach_dx=96,approach_dz=-96},
	{crossing=point(-2400,1100),approach_dx=0,approach_dz=-96},{crossing=point(-900,1100),approach_dx=0,approach_dz=-96},{crossing=point(900,1100),approach_dx=0,approach_dz=-96},{crossing=point(2400,1100),approach_dx=0,approach_dz=-96},
	{crossing=point(-1150,1000),approach_dx=-96,approach_dz=-96},{crossing=point(650,1000),approach_dx=-96,approach_dz=-96},
	{crossing=point(-2000,-250),approach_dx=0,approach_dz=-96},{crossing=point(-1125,-250),approach_dx=0,approach_dz=-96},{crossing=point(-375,-250),approach_dx=0,approach_dz=-96},{crossing=point(375,-250),approach_dx=0,approach_dz=-96},{crossing=point(1125,-250),approach_dx=0,approach_dz=-96},{crossing=point(2000,-250),approach_dx=0,approach_dz=-96},
	{crossing=point(-2000,250),approach_dx=0,approach_dz=-96},{crossing=point(-1125,250),approach_dx=0,approach_dz=-96},{crossing=point(-375,250),approach_dx=0,approach_dz=-96},{crossing=point(375,250),approach_dx=0,approach_dz=-96},{crossing=point(1125,250),approach_dx=0,approach_dz=-96},{crossing=point(2000,250),approach_dx=0,approach_dz=-96},
	{crossing=point(-1500,-125),approach_dx=96,approach_dz=0},{crossing=point(0,-125),approach_dx=96,approach_dz=0},{crossing=point(1500,-125),approach_dx=96,approach_dz=0},
}

local route_class_order={}
for route_index=1,30 do route_class_order[route_index]="primary" end
for route_index=31,54 do route_class_order[route_index]="secondary" end
for route_index=55,57 do route_class_order[route_index]="trail" end

local station_by_id={}
for station_index=1,#source.route_stations do
	station_by_id[source.route_stations[station_index].id]=source.route_stations[station_index]
end

local function endpoint_station_id(zone_id,gate_ref)
	if gate_ref then
		return "station:"..zone_id..":"..gate_ref:gsub(":","_")
	end
	return "station:"..zone_id..":hub"
end

source.routes = {}
source.route_interfaces = {}
for route_index = 1, #source.land_edges do
	local boundary = source.land_edges[route_index]
	local geometry=route_geometry[route_index]
	local crossing=geometry.crossing
	local route_id = ("route_%03d"):format(route_index)
	local interface_a = route_id .. ":endpoint_a"
	local interface_b = route_id .. ":endpoint_b"
	local crossing_id = route_id .. ":boundary_crossing"
	local gate_ref_a=endpoint_gate_refs[boundary.zone_a] or capital_gate_refs[boundary.zone_a.."\0"..boundary.zone_b] or false
	local gate_ref_b=endpoint_gate_refs[boundary.zone_b] or capital_gate_refs[boundary.zone_b.."\0"..boundary.zone_a] or false
	local station_a_id=endpoint_station_id(boundary.zone_a,gate_ref_a)
	local station_b_id=endpoint_station_id(boundary.zone_b,gate_ref_b)
	local station_a=station_by_id[station_a_id]
	local station_b=station_by_id[station_b_id]
	local minus=point(crossing.x-geometry.approach_dx,crossing.z-geometry.approach_dz)
	local plus=point(crossing.x+geometry.approach_dx,crossing.z+geometry.approach_dz)
	local minus_distance=(minus.x-station_a.position.x)*(minus.x-station_a.position.x)+(minus.z-station_a.position.z)*(minus.z-station_a.position.z)
	local plus_distance=(plus.x-station_a.position.x)*(plus.x-station_a.position.x)+(plus.z-station_a.position.z)*(plus.z-station_a.position.z)
	local approach_a,approach_b=minus,plus
	if plus_distance<minus_distance then approach_a,approach_b=plus,minus end
	source.routes[route_index] = {
		id=route_id,boundary_id=boundary.id,zone_a=boundary.zone_a,
		zone_b=boundary.zone_b,class=route_class_order[route_index],
		centreline={point(station_a.position.x,station_a.position.z),approach_a,
			point(crossing.x,crossing.z),approach_b,
			point(station_b.position.x,station_b.position.z)},
		crossing_station=3,
		station_a_id=station_a_id,station_b_id=station_b_id,
		endpoint_a_id=interface_a,endpoint_b_id=interface_b,
		boundary_interface_id=crossing_id,grade_phase=0,
		gate_ref_a=gate_ref_a,gate_ref_b=gate_ref_b,
	}
	source.route_interfaces[#source.route_interfaces+1]={id=interface_a,
		route_id=route_id,kind="endpoint",zone_id=boundary.zone_a,
		position=source.routes[route_index].centreline[1],
		station_id=station_a_id,
		direction=sign_direction(crossing.x-station_a.position.x,crossing.z-station_a.position.z),grade_phase=0}
	source.route_interfaces[#source.route_interfaces+1]={id=interface_b,
		route_id=route_id,kind="endpoint",zone_id=boundary.zone_b,
		position=source.routes[route_index].centreline[5],
		station_id=station_b_id,
		direction=sign_direction(crossing.x-station_b.position.x,crossing.z-station_b.position.z),grade_phase=0}
	source.route_interfaces[#source.route_interfaces+1]={id=crossing_id,
		route_id=route_id,kind="boundary_crossing",boundary_id=boundary.id,
		position=point(crossing.x,crossing.z),direction=sign_direction(station_b.position.x-station_a.position.x,station_b.position.z-station_a.position.z),grade_phase=0}
end

-- Named physical interfaces are explicit because route priority alone may
-- never decide a water/terrain overlap.
source.route_crossing_interfaces = {
	{id="whitebridge_bridge",route_id="route_021",kind="bridge",position=point(-400,-1500),direction="east",span=48,width=9,grade_limit=fraction(1,12),hydrology_id="hydro_whitebridge_main",alternate_id="whitebridge_ford",hard_protected=false},
	{id="whitebridge_ford",route_id="route_032",kind="ford",position=point(-900,-1100),direction="north",span=32,width=9,grade_limit=fraction(1,12),hydrology_id="hydro_whitebridge_ford",alternate_id="whitebridge_bridge",hard_protected=false},
	{id="broken_causeway",route_id="route_045",kind="causeway",position=point(-375,-250),direction="north",span=96,width=9,grade_limit=fraction(1,12),hydrology_id="hydro_broken_marsh",alternate_id="broken_ford",hard_protected=false},
	{id="broken_ford",route_id="route_050",kind="ford",position=point(-1125,250),direction="south",span=48,width=9,grade_limit=fraction(1,12),hydrology_id="hydro_broken_marsh",alternate_id="broken_aqueduct",hard_protected=false},
	{id="broken_aqueduct",route_id="route_055",kind="bridge",position=point(-1500,-125),direction="east",span=64,width=7,grade_limit=fraction(1,12),hydrology_id="hydro_broken_marsh",alternate_id="broken_causeway",hard_protected=false},
	{id="gravesalt_tomb_tunnel",route_id="route_043",kind="tunnel",position=point(-2000,-100),direction="north",span=96,width=7,portal_length=16,grade_limit=fraction(1,12),landmark_id="gravesalt_tombways",alternate_id="route_044",hard_protected=false},
	{id="skyglass_cliff_tunnel",route_id="route_048",kind="tunnel",position=point(2000,-100),direction="north",span=96,width=7,portal_length=16,grade_limit=fraction(1,12),landmark_id="skyglass_escarpment",alternate_id="route_047",hard_protected=false},
}

source.boat_edges = {
	{numeric_id = 1, id = "boat_wyrmglass_south", from_zone = "front_gravesalt_escarpment", to_zone = "front_wyrmglass_crown", approach_z = -125, width = 96, landing_id = "wyrmglass_south_landing"},
	{numeric_id = 2, id = "boat_wyrmglass_north", from_zone = "front_gravesalt_escarpment", to_zone = "front_wyrmglass_crown", approach_z = 125, width = 96, landing_id = "wyrmglass_north_landing"},
	{numeric_id = 3, id = "boat_stormscale_south", from_zone = "front_skyglass_canopy", to_zone = "front_stormscale_summit", approach_z = -125, width = 96, landing_id = "stormscale_south_landing"},
	{numeric_id = 4, id = "boat_stormscale_north", from_zone = "front_skyglass_canopy", to_zone = "front_stormscale_summit", approach_z = 125, width = 96, landing_id = "stormscale_north_landing"},
}

source.island_landings = {
	{id="wyrmglass_south_landing",island_id="island_wyrmglass",zone_id="front_wyrmglass_crown",boat_edge_id="boat_wyrmglass_south",station_id="island_station_wyrmglass_south",position=point(-2890,-125)},
	{id="wyrmglass_north_landing",island_id="island_wyrmglass",zone_id="front_wyrmglass_crown",boat_edge_id="boat_wyrmglass_north",station_id="island_station_wyrmglass_north",position=point(-2890,125)},
	{id="stormscale_south_landing",island_id="island_stormscale",zone_id="front_stormscale_summit",boat_edge_id="boat_stormscale_south",station_id="island_station_stormscale_south",position=point(2890,-125)},
	{id="stormscale_north_landing",island_id="island_stormscale",zone_id="front_stormscale_summit",boat_edge_id="boat_stormscale_north",station_id="island_station_stormscale_north",position=point(2900,125)},
}

source.island_route_stations = {
	{id="island_station_wyrmglass_south",island_id="island_wyrmglass",kind="landing",position=point(-2890,-125)},
	{id="island_station_wyrmglass_north",island_id="island_wyrmglass",kind="landing",position=point(-2890,125)},
	{id="island_station_wyrmglass_junction",island_id="island_wyrmglass",kind="junction",position=point(-3100,0)},
	{id="island_station_wyrmglass_dragon",island_id="island_wyrmglass",kind="dragon",anchor_id="anchor_087",position=point(-3260,-40)},
	{id="island_station_wyrmglass_apex",island_id="island_wyrmglass",kind="apex_mine",anchor_id="anchor_089",position=point(-3200,80)},
	{id="island_station_stormscale_south",island_id="island_stormscale",kind="landing",position=point(2890,-125)},
	{id="island_station_stormscale_north",island_id="island_stormscale",kind="landing",position=point(2900,125)},
	{id="island_station_stormscale_junction",island_id="island_stormscale",kind="junction",position=point(3100,0)},
	{id="island_station_stormscale_dragon",island_id="island_stormscale",kind="dragon",anchor_id="anchor_088",position=point(3260,-40)},
	{id="island_station_stormscale_apex",island_id="island_stormscale",kind="apex_mine",anchor_id="anchor_090",position=point(3200,80)},
}

local function island_route(id,island_id,from_id,to_id,points)
	return {id=id,island_id=island_id,class="secondary",from_station_id=from_id,
		to_station_id=to_id,centreline=points}
end
source.island_routes = {
	island_route("island_route_wyrmglass_south_junction","island_wyrmglass","island_station_wyrmglass_south","island_station_wyrmglass_junction",{point(-2890,-125),point(-2990,-90),point(-3100,0)}),
	island_route("island_route_wyrmglass_north_junction","island_wyrmglass","island_station_wyrmglass_north","island_station_wyrmglass_junction",{point(-2890,125),point(-2990,90),point(-3100,0)}),
	island_route("island_route_wyrmglass_junction_dragon","island_wyrmglass","island_station_wyrmglass_junction","island_station_wyrmglass_dragon",{point(-3100,0),point(-3180,-10),point(-3260,-40)}),
	island_route("island_route_wyrmglass_junction_apex","island_wyrmglass","island_station_wyrmglass_junction","island_station_wyrmglass_apex",{point(-3100,0),point(-3140,50),point(-3200,80)}),
	island_route("island_route_stormscale_south_junction","island_stormscale","island_station_stormscale_south","island_station_stormscale_junction",{point(2890,-125),point(2990,-90),point(3100,0)}),
	island_route("island_route_stormscale_north_junction","island_stormscale","island_station_stormscale_north","island_station_stormscale_junction",{point(2900,125),point(2990,90),point(3100,0)}),
	island_route("island_route_stormscale_junction_dragon","island_stormscale","island_station_stormscale_junction","island_station_stormscale_dragon",{point(3100,0),point(3180,-10),point(3260,-40)}),
	island_route("island_route_stormscale_junction_apex","island_stormscale","island_station_stormscale_junction","island_station_stormscale_apex",{point(3100,0),point(3140,50),point(3200,80)}),
}

source.island_route_interfaces = {}
for island_route_index=1,#source.island_routes do local row=source.island_routes[island_route_index]
	source.island_route_interfaces[#source.island_route_interfaces+1]={id=row.id..":from",route_id=row.id,station_id=row.from_station_id,kind="endpoint",position=point(row.centreline[1].x,row.centreline[1].z)}
	source.island_route_interfaces[#source.island_route_interfaces+1]={id=row.id..":to",route_id=row.id,station_id=row.to_station_id,kind="endpoint",position=point(row.centreline[#row.centreline].x,row.centreline[#row.centreline].z)}
end

source.perimeters = {
	{id = "perimeter_elandor_mainland", kind = "planned_mainland_footprint",
		continent = "elandor", orientation = "counterclockwise",
		noise_domain = "coast_elandor_independent", max_displacement = 96,
		polygon = {
			point(-2500,-250),point(-2470,-650),point(-2490,-1050),point(-2560,-1500),point(-2600,-1900),point(-2580,-2200),point(-2600,-2500),point(-2470,-2760),point(-2250,-2920),point(-1800,-2960),point(-1350,-2920),point(-980,-2940),point(-520,-2910),point(0,-2960),point(460,-2930),point(900,-2920),point(1320,-2930),point(1800,-2950),point(2240,-2925),point(2470,-2740),point(2600,-2500),point(2580,-2200),point(2600,-1900),point(2550,-1500),point(2490,-1050),point(2530,-650),point(2500,-250),point(-2500,-250),
		}},
	{id = "perimeter_kragmar_mainland", kind = "planned_mainland_footprint",
		continent = "kragmar", orientation = "clockwise",
		noise_domain = "coast_kragmar_independent", max_displacement = 96,
		polygon = {
			point(-2500,250),point(-2540,620),point(-2480,1050),point(-2560,1480),point(-2600,1900),point(-2580,2200),point(-2600,2500),point(-2480,2750),point(-2260,2920),point(-1800,2960),point(-1440,2940),point(-1080,2930),point(-560,2940),point(0,2970),point(440,2920),point(820,2960),point(1280,2920),point(1800,2960),point(2250,2920),point(2480,2760),point(2600,2500),point(2580,2200),point(2600,1900),point(2540,1500),point(2500,1000),point(2550,600),point(2500,250),point(-2500,250),
		}},
	{id = "perimeter_holy_grounds", kind = "fixed_land_band",
		continent = "front", orientation = "counterclockwise",
		noise_domain = "fixed", max_displacement = 0,
		polygon = {point(-2500,-250),point(2500,-250),point(2500,250),point(-2500,250),point(-2500,-250)}},
}

source.bays = {
	{id = "bay_elandor_west", continent = "elandor",
		noise_domain = "bay_elandor_west", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id", centreline = {
			{x=-980,z=-2940,half_width=360},{x=-900,z=-2600,half_width=280},{x=-1040,z=-2300,half_width=190},{x=-980,z=-2000,half_width=80},
		}},
	{id = "bay_elandor_east", continent = "elandor",
		noise_domain = "bay_elandor_east", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id", centreline = {
			{x=900,z=-2920,half_width=330},{x=1080,z=-2580,half_width=250},{x=920,z=-2280,half_width=180},{x=1020,z=-1990,half_width=80},
		}},
	{id = "bay_kragmar_west", continent = "kragmar",
		noise_domain = "bay_kragmar_west", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id", centreline = {
			{x=-1080,z=2930,half_width=320},{x=-1200,z=2620,half_width=260},{x=-940,z=2300,half_width=190},{x=-1060,z=2010,half_width=80},
		}},
	{id = "bay_kragmar_east", continent = "kragmar",
		noise_domain = "bay_kragmar_east", max_displacement = 48,
		owner_seam_tie = "lower_zone_numeric_id", centreline = {
			{x=820,z=2960,half_width=370},{x=700,z=2630,half_width=250},{x=1050,z=2320,half_width=170},{x=900,z=1980,half_width=80},
		}},
}

source.islands = {
	{id = "island_wyrmglass", zone_id = "front_wyrmglass_crown",
		center = point(-3150,0), envelope = {radius_x=300,radius_z=350},
		orientation = "counterclockwise", noise_domain = "coast_wyrmglass",
		polygon = {point(-3430,-80),point(-3360,-260),point(-3160,-330),point(-2940,-250),point(-2860,-80),point(-2890,150),point(-3060,320),point(-3290,280),point(-3440,100),point(-3430,-80)}},
	{id = "island_stormscale", zone_id = "front_stormscale_summit",
		center = point(3150,0), envelope = {radius_x=300,radius_z=350},
		orientation = "counterclockwise", noise_domain = "coast_stormscale",
		polygon = {point(2870,-130),point(2970,-310),point(3200,-340),point(3400,-220),point(3440,20),point(3370,260),point(3150,330),point(2940,230),point(2860,60),point(2870,-130)}},
}

source.channels = {
	{id = "channel_wyrmglass", island_id = "island_wyrmglass",
		mainland_zone_id = "front_gravesalt_escarpment",
		orientation = "counterclockwise", warning_width = 48,
		minimum_hard_width = 104,
		polygon = {point(-2850,-350),point(-2500,-350),point(-2500,350),point(-2850,350),point(-2850,-350)},
		approach_edge_ids = {"boat_wyrmglass_south","boat_wyrmglass_north"}},
	{id = "channel_stormscale", island_id = "island_stormscale",
		mainland_zone_id = "front_skyglass_canopy",
		orientation = "counterclockwise", warning_width = 48,
		minimum_hard_width = 104,
		polygon = {point(2500,-350),point(2860,-350),point(2860,350),point(2500,350),point(2500,-350)},
		approach_edge_ids = {"boat_stormscale_south","boat_stormscale_north"}},
}

local function landmark(numeric_id, id, zone_id, primitive, x, z, radius_x,
		radius_z, relief_id)
	return {
		numeric_id = numeric_id,
		id = id,
		zone_id = zone_id,
		primitive = primitive,
		center = point(x, z),
		radius_x = radius_x,
		radius_z = radius_z,
		secondary_relief_id = relief_id,
		noise_domain = "landmark_" .. id,
	}
end

source.landmarks = {
	landmark(1,"hearthpine_bowl","elandor_hearthpine_vale","ellipse",-1800,-2520,290,220,"lowland"),
	landmark(2,"copperfell_drainage","elandor_copperfell_foothills","capsule",-2050,-2050,180,260,"highland"),
	landmark(3,"copperfell_coastal_terraces","elandor_copperfell_foothills","rectangle",-2430,-2200,150,300,"lowland"),
	landmark(4,"dur_brannoc_granite_terrace","elandor_dur_brannoc","rectangle",-1800,-1500,352,352,"plateau"),
	landmark(5,"dur_brannoc_forge_chasm","elandor_dur_brannoc","capsule",-1800,-1500,55,120,"highland"),
	landmark(6,"frostbarrow_escarpment","elandor_frostbarrow_shelf","capsule",-2420,-1450,120,300,"highland"),
	landmark(7,"frostbarrow_tarns","elandor_frostbarrow_shelf","ellipse",-2350,-1740,150,100,"plateau"),
	landmark(8,"stormvault_arch","elandor_stormvault_heights","ellipse",-1820,-650,180,130,"mountain"),
	landmark(9,"dawnmere_headwaters","elandor_dawnmere_fields","capsule",0,-2500,230,150,"wetland_delta"),
	landmark(10,"goldmead_millriver","elandor_goldmead_vale","capsule",0,-2020,110,260,"lowland"),
	landmark(11,"goldmead_orchard_slopes","elandor_goldmead_vale","ellipse",-280,-2050,210,150,"rolling_hills"),
	landmark(12,"highcourt_riverfork","elandor_highcourt","capsule",0,-1500,280,352,"lowland"),
	landmark(13,"whitebridge_crossing","elandor_whitebridge_shire","capsule",-900,-1500,250,70,"lowland"),
	landmark(14,"whitebridge_ford","elandor_whitebridge_shire","capsule",-720,-1260,180,60,"wetland_delta"),
	landmark(15,"ashenward_burnscar","elandor_ashenward_march","capsule",0,-720,260,90,"rolling_hills"),
	landmark(16,"ashenward_trenchbelt","elandor_ashenward_march","rectangle",0,-470,330,120,"wetland_delta"),
	landmark(17,"silverleaf_gladechain","elandor_silverleaf_glades","capsule",1800,-2520,250,180,"lowland"),
	landmark(18,"starbough_canopy_steps","elandor_starbough_vale","ellipse",1950,-2050,230,180,"highland"),
	landmark(19,"starbough_coastal_gardens","elandor_starbough_vale","rectangle",2430,-2200,150,300,"lowland"),
	landmark(20,"lethariel_crownlake","elandor_lethariel","ellipse",1800,-1500,260,220,"lowland"),
	landmark(21,"lorindor_silverorchards","elandor_lorindor","ellipse",900,-1500,280,190,"rolling_hills"),
	landmark(22,"lorindor_berrymarsh","elandor_lorindor","ellipse",1080,-1740,150,110,"wetland_delta"),
	landmark(23,"moonfall_crescent","elandor_moonfall_wood","ellipse",2400,-1500,150,230,"wetland_delta"),
	landmark(24,"glassroot_pale_cliffs","elandor_glassroot_wilds","capsule",1550,-650,170,300,"mountain"),
	landmark(25,"glassroot_rootways","elandor_glassroot_wilds","capsule",2050,-520,260,120,"highland"),
	landmark(26,"stillgrave_basin","kragmar_stillgrave_hollow","ellipse",-1800,2520,290,220,"lowland"),
	landmark(27,"stillgrave_ringbarrows","kragmar_stillgrave_hollow","ellipse",-1800,2520,330,250,"rolling_hills"),
	landmark(28,"mournfen_drowned_roads","kragmar_mournfen","capsule",-2050,2100,180,260,"wetland_delta"),
	landmark(29,"mournfen_dryward","kragmar_mournfen","rectangle",-2430,2200,150,300,"lowland"),
	landmark(30,"nhal_veyr_necropolis","kragmar_nhal_veyr","rectangle",-1800,1500,352,352,"plateau"),
	landmark(31,"ossuary_spine","kragmar_ossuary_reach","capsule",-2400,1450,130,300,"highland"),
	landmark(32,"ossuary_gravewoods","kragmar_ossuary_reach","ellipse",-2320,1730,170,120,"rolling_hills"),
	landmark(33,"blackwind_bonearches","kragmar_blackwind_rise","ellipse",-1850,650,220,150,"highland"),
	landmark(34,"blackwind_ashcuts","kragmar_blackwind_rise","capsule",-1350,520,240,110,"plateau"),
	landmark(35,"sunscar_open_flats","kragmar_sunscar_flats","rectangle",0,2520,290,220,"lowland"),
	landmark(36,"sunscar_waterholes","kragmar_sunscar_flats","ellipse",260,2450,130,90,"wetland_delta"),
	landmark(37,"redtusk_gullies","kragmar_redtusk_savanna","capsule",-120,2050,250,120,"plateau"),
	landmark(38,"redtusk_wellchain","kragmar_redtusk_savanna","capsule",180,2040,180,80,"rolling_hills"),
	landmark(39,"gor_drazhak_crossmesa","kragmar_gor_drazhak","rectangle",0,1500,352,352,"plateau"),
	landmark(40,"speargrass_dryriver","kragmar_speargrass_reach","capsule",-900,1500,280,90,"rolling_hills"),
	landmark(41,"speargrass_hunting_stones","kragmar_speargrass_reach","ellipse",-700,1750,180,100,"plateau"),
	landmark(42,"bannerbreak_crowned_mesa","kragmar_bannerbreak_mesa","ellipse",0,650,290,220,"highland"),
	landmark(43,"bannerbreak_siegeramps","kragmar_bannerbreak_mesa","capsule",0,430,330,100,"plateau"),
	landmark(44,"kapok_worldtree_basin","kragmar_kapok_cradle","ellipse",1800,2520,290,220,"wetland_delta"),
	landmark(45,"raincall_falls","kragmar_raincall_basin","capsule",2020,2080,210,260,"highland"),
	landmark(46,"raincall_coastal_steps","kragmar_raincall_basin","rectangle",2430,2200,150,300,"lowland"),
	landmark(47,"kezamba_cenote","kragmar_kezamba","ellipse",1800,1500,250,220,"wetland_delta"),
	landmark(48,"whispering_reedmaze","kragmar_whispering_reedlands","rectangle",900,1500,300,230,"wetland_delta"),
	landmark(49,"whispering_totemways","kragmar_whispering_reedlands","capsule",900,1500,300,80,"lowland"),
	landmark(50,"totemwater_delta","kragmar_totemwater_reach","capsule",2400,1500,160,300,"wetland_delta"),
	landmark(51,"totemwater_colossi","kragmar_totemwater_reach","ellipse",2380,1750,160,110,"lowland"),
	landmark(52,"thunderroot_exposures","kragmar_thunderroot_wilds","capsule",2050,520,260,120,"highland"),
	landmark(53,"thunderroot_ochresteps","kragmar_thunderroot_wilds","ellipse",1550,680,210,180,"plateau"),
	landmark(54,"wyrmglass_ring","front_wyrmglass_crown","ellipse",-3150,0,250,300,"mountain"),
	landmark(55,"wyrmglass_faultfields","front_wyrmglass_crown","rectangle",-3200,60,150,120,"highland"),
	landmark(56,"wyrmglass_dragonspire","front_wyrmglass_crown","ellipse",-3260,-40,100,90,"mountain"),
	landmark(57,"gravesalt_whitewall","front_gravesalt_escarpment","capsule",-2050,0,350,120,"mountain"),
	landmark(58,"gravesalt_tombways","front_gravesalt_escarpment","rectangle",-1800,0,260,160,"highland"),
	landmark(59,"gravesalt_warcoast","front_gravesalt_escarpment","capsule",-2450,0,80,230,"highland"),
	landmark(60,"broken_threeways","front_broken_causeway","rectangle",-750,0,520,180,"lowland"),
	landmark(61,"broken_marsh","front_broken_causeway","rectangle",-750,0,650,220,"wetland_delta"),
	landmark(62,"shattered_breachwall","front_shattered_line","capsule",750,0,620,70,"plateau"),
	landmark(63,"shattered_noman","front_shattered_line","rectangle",750,0,650,210,"rolling_hills"),
	landmark(64,"shattered_siegeramp","front_shattered_line","capsule",1250,60,180,80,"plateau"),
	landmark(65,"skyglass_escarpment","front_skyglass_canopy","capsule",2050,0,350,120,"mountain"),
	landmark(66,"skyglass_hangingways","front_skyglass_canopy","rectangle",1800,0,260,160,"rolling_hills"),
	landmark(67,"skyglass_warcoast","front_skyglass_canopy","capsule",2450,0,80,230,"highland"),
	landmark(68,"stormscale_caldera","front_stormscale_summit","ellipse",3150,0,250,300,"mountain"),
	landmark(69,"stormscale_gemterraces","front_stormscale_summit","rectangle",3200,60,150,120,"highland"),
	landmark(70,"stormscale_dragonroost","front_stormscale_summit","ellipse",3260,-40,100,90,"mountain"),
}

local hydrology_landmarks = {
	copperfell_drainage=true,frostbarrow_tarns=true,dawnmere_headwaters=true,
	goldmead_millriver=true,highcourt_riverfork=true,whitebridge_crossing=true,
	whitebridge_ford=true,lethariel_crownlake=true,lorindor_berrymarsh=true,
	moonfall_crescent=true,mournfen_drowned_roads=true,sunscar_waterholes=true,
	speargrass_dryriver=true,raincall_falls=true,kezamba_cenote=true,
	whispering_reedmaze=true,totemwater_delta=true,gravesalt_whitewall=true,
	broken_marsh=true,
}
local route_landmarks = {
	stormvault_arch=true,whitebridge_crossing=true,whitebridge_ford=true,
	ashenward_trenchbelt=true,glassroot_rootways=true,mournfen_drowned_roads=true,
	blackwind_bonearches=true,redtusk_gullies=true,speargrass_dryriver=true,
	bannerbreak_siegeramps=true,whispering_totemways=true,
	thunderroot_exposures=true,wyrmglass_ring=true,gravesalt_whitewall=true,
	gravesalt_tombways=true,gravesalt_warcoast=true,broken_threeways=true,
	shattered_breachwall=true,shattered_siegeramp=true,skyglass_escarpment=true,
	skyglass_hangingways=true,skyglass_warcoast=true,stormscale_caldera=true,
}
local target_landmarks = {
	copperfell_coastal_terraces=true,dur_brannoc_granite_terrace=true,
	dur_brannoc_forge_chasm=true,starbough_coastal_gardens=true,
	lethariel_crownlake=true,nhal_veyr_necropolis=true,mournfen_dryward=true,
	gor_drazhak_crossmesa=true,raincall_coastal_steps=true,kezamba_cenote=true,
	wyrmglass_faultfields=true,wyrmglass_dragonspire=true,
	stormscale_gemterraces=true,stormscale_dragonroost=true,
}
for landmark_index = 1, #source.landmarks do
	local row = source.landmarks[landmark_index]
	local roles = {"base_H"}
	if target_landmarks[row.id] then roles[#roles+1]="target_T" end
	if hydrology_landmarks[row.id] then roles[#roles+1]="hydrology" end
	if route_landmarks[row.id] then
		roles[#roles+1]="route"
		roles[#roles+1]="interface"
	end
	roles[#roles+1]="dressing"
	row.roles=roles
end

local function fixed_anchor(numeric_id, zone_id, slot_id, x, z, template_id)
	return {
		numeric_id = numeric_id,
		id = ("anchor_%03d"):format(numeric_id),
		zone_id = zone_id,
		slot_id = slot_id,
		placement_mode = "fixed",
		template_id = template_id,
		position = point(x, z),
	}
end

local function candidate_anchor(numeric_id, zone_id, slot_id, x, z,
		template_id)
	-- Flexible slots use one conservative three-point authored set. The small
	-- offsets keep every fallback inside the same reserved envelope; T2b must
	-- still reject the seed if none passes the complete solver.
	return {
		numeric_id = numeric_id,
		id = ("anchor_%03d"):format(numeric_id),
		zone_id = zone_id,
		slot_id = slot_id,
		placement_mode = "candidate_set",
		template_id = template_id,
		candidates = {point(x,z),point(x+32,z-16),point(x-24,z+24)},
	}
end


source.anchors = {
	-- Six starts and six capitals retain the exact fixed §7 coordinates.
	fixed_anchor(1,"elandor_hearthpine_vale","start",-1800,-2550,"start"),
	fixed_anchor(2,"elandor_dawnmere_fields","start",0,-2550,"start"),
	fixed_anchor(3,"elandor_silverleaf_glades","start",1800,-2550,"start"),
	fixed_anchor(4,"kragmar_stillgrave_hollow","start",-1800,2550,"start"),
	fixed_anchor(5,"kragmar_sunscar_flats","start",0,2550,"start"),
	fixed_anchor(6,"kragmar_kapok_cradle","start",1800,2550,"start"),
	fixed_anchor(7,"elandor_dur_brannoc","capital",-1800,-1500,"capital_dwarf"),
	fixed_anchor(8,"elandor_highcourt","capital",0,-1500,"capital_human"),
	fixed_anchor(9,"elandor_lethariel","capital",1800,-1500,"capital_elf"),
	fixed_anchor(10,"kragmar_nhal_veyr","capital",-1800,1500,"capital_undead"),
	fixed_anchor(11,"kragmar_gor_drazhak","capital",0,1500,"capital_orc"),
	fixed_anchor(12,"kragmar_kezamba","capital",1800,1500,"capital_troll"),
	-- Twelve villages: exactly two per race region.
	candidate_anchor(13,"elandor_copperfell_foothills","village_1",-1900,-2020,"village"),
	candidate_anchor(14,"elandor_frostbarrow_shelf","village_1",-2380,-1600,"village"),
	candidate_anchor(15,"elandor_goldmead_vale","village_1",-120,-2020,"village"),
	candidate_anchor(16,"elandor_whitebridge_shire","village_1",-900,-1580,"village"),
	candidate_anchor(17,"elandor_starbough_vale","village_1",1900,-2020,"village"),
	candidate_anchor(18,"elandor_lorindor","village_1",900,-1580,"village"),
	candidate_anchor(19,"kragmar_mournfen","village_1",-1900,2020,"village"),
	candidate_anchor(20,"kragmar_ossuary_reach","village_1",-2380,1600,"village"),
	candidate_anchor(21,"kragmar_redtusk_savanna","village_1",-120,2020,"village"),
	candidate_anchor(22,"kragmar_speargrass_reach","village_1",-900,1580,"village"),
	candidate_anchor(23,"kragmar_raincall_basin","village_1",1900,2020,"village"),
	candidate_anchor(24,"kragmar_whispering_reedlands","village_1",900,1580,"village"),
	-- Twenty-four ordinary outposts: exactly four per race region.
	candidate_anchor(25,"elandor_copperfell_foothills","outpost_1",-2100,-2100,"outpost"),
	candidate_anchor(26,"elandor_frostbarrow_shelf","outpost_1",-2300,-1250,"outpost"),
	candidate_anchor(27,"elandor_stormvault_heights","outpost_1",-2050,-850,"outpost"),
	candidate_anchor(28,"elandor_stormvault_heights","outpost_2",-1500,-450,"outpost"),
	candidate_anchor(29,"elandor_goldmead_vale","outpost_1",200,-2050,"outpost"),
	candidate_anchor(30,"elandor_whitebridge_shire","outpost_1",-650,-1250,"outpost"),
	candidate_anchor(31,"elandor_ashenward_march","outpost_1",-350,-850,"outpost"),
	candidate_anchor(32,"elandor_ashenward_march","outpost_2",300,-450,"outpost"),
	candidate_anchor(33,"elandor_starbough_vale","outpost_1",2100,-2100,"outpost"),
	candidate_anchor(34,"elandor_lorindor","outpost_1",650,-1250,"outpost"),
	candidate_anchor(35,"elandor_moonfall_wood","outpost_1",2400,-1350,"outpost"),
	candidate_anchor(36,"elandor_glassroot_wilds","outpost_1",1900,-550,"outpost"),
	candidate_anchor(37,"kragmar_mournfen","outpost_1",-2100,2100,"outpost"),
	candidate_anchor(38,"kragmar_ossuary_reach","outpost_1",-2300,1250,"outpost"),
	candidate_anchor(39,"kragmar_blackwind_rise","outpost_1",-2050,850,"outpost"),
	candidate_anchor(40,"kragmar_blackwind_rise","outpost_2",-1500,450,"outpost"),
	candidate_anchor(41,"kragmar_redtusk_savanna","outpost_1",200,2050,"outpost"),
	candidate_anchor(42,"kragmar_speargrass_reach","outpost_1",-650,1250,"outpost"),
	candidate_anchor(43,"kragmar_bannerbreak_mesa","outpost_1",-350,850,"outpost"),
	candidate_anchor(44,"kragmar_bannerbreak_mesa","outpost_2",300,450,"outpost"),
	candidate_anchor(45,"kragmar_raincall_basin","outpost_1",2100,2100,"outpost"),
	candidate_anchor(46,"kragmar_whispering_reedlands","outpost_1",650,1250,"outpost"),
	candidate_anchor(47,"kragmar_totemwater_reach","outpost_1",2400,1350,"outpost"),
	candidate_anchor(48,"kragmar_thunderroot_wilds","outpost_1",1900,550,"outpost"),
	-- Twelve fixed-budget bandit slots: one home and one frontier per race.
	candidate_anchor(49,"elandor_copperfell_foothills","bandit_1",-1600,-2050,"bandit_home"),
	candidate_anchor(50,"elandor_stormvault_heights","bandit_1",-1800,-430,"bandit_frontier"),
	candidate_anchor(51,"elandor_goldmead_vale","bandit_1",320,-1980,"bandit_home"),
	candidate_anchor(52,"elandor_ashenward_march","bandit_1",0,-430,"bandit_frontier"),
	candidate_anchor(53,"elandor_starbough_vale","bandit_1",1600,-2050,"bandit_home"),
	candidate_anchor(54,"elandor_glassroot_wilds","bandit_1",1800,-430,"bandit_frontier"),
	candidate_anchor(55,"kragmar_mournfen","bandit_1",-1600,2050,"bandit_home"),
	candidate_anchor(56,"kragmar_blackwind_rise","bandit_1",-1800,430,"bandit_frontier"),
	candidate_anchor(57,"kragmar_redtusk_savanna","bandit_1",320,1980,"bandit_home"),
	candidate_anchor(58,"kragmar_bannerbreak_mesa","bandit_1",0,430,"bandit_frontier"),
	candidate_anchor(59,"kragmar_raincall_basin","bandit_1",1600,2050,"bandit_home"),
	candidate_anchor(60,"kragmar_thunderroot_wilds","bandit_1",1800,430,"bandit_frontier"),
	-- Six peaceful regional mines and four Mirefolk camps.
	candidate_anchor(61,"elandor_frostbarrow_shelf","mine",-2450,-1280,"mine"),
	candidate_anchor(62,"elandor_whitebridge_shire","mine",-1050,-1280,"mine"),
	candidate_anchor(63,"elandor_lorindor","mine",1050,-1280,"mine"),
	candidate_anchor(64,"kragmar_ossuary_reach","mine",-2450,1280,"mine"),
	candidate_anchor(65,"kragmar_speargrass_reach","mine",-1050,1280,"mine"),
	candidate_anchor(66,"kragmar_whispering_reedlands","mine",1050,1280,"mine"),
	candidate_anchor(67,"elandor_whitebridge_shire","mirefolk",-620,-1760,"mirefolk"),
	candidate_anchor(68,"elandor_lorindor","mirefolk",1120,-1740,"mirefolk"),
	candidate_anchor(69,"kragmar_mournfen","mirefolk",-2050,2250,"mirefolk"),
	candidate_anchor(70,"kragmar_whispering_reedlands","mirefolk",1120,1740,"mirefolk"),
	-- Sixteen dedicated clash anchors.
	candidate_anchor(71,"elandor_ashenward_march","clash_1",-250,-320,"clash"),
	candidate_anchor(72,"elandor_ashenward_march","clash_2",250,-320,"clash"),
	candidate_anchor(73,"kragmar_bannerbreak_mesa","clash_1",-250,320,"clash"),
	candidate_anchor(74,"kragmar_bannerbreak_mesa","clash_2",250,320,"clash"),
	candidate_anchor(75,"front_wyrmglass_crown","clash_1",-3000,170,"clash"),
	candidate_anchor(76,"front_gravesalt_escarpment","clash_1",-2200,-80,"clash"),
	candidate_anchor(77,"front_gravesalt_escarpment","clash_2",-1800,80,"clash"),
	candidate_anchor(78,"front_broken_causeway","clash_1",-1250,-100,"clash"),
	candidate_anchor(79,"front_broken_causeway","clash_2",-750,100,"clash"),
	candidate_anchor(80,"front_broken_causeway","clash_3",-250,-100,"clash"),
	candidate_anchor(81,"front_shattered_line","clash_1",250,100,"clash"),
	candidate_anchor(82,"front_shattered_line","clash_2",750,-100,"clash"),
	candidate_anchor(83,"front_shattered_line","clash_3",1250,100,"clash"),
	candidate_anchor(84,"front_skyglass_canopy","clash_1",1800,-80,"clash"),
	candidate_anchor(85,"front_skyglass_canopy","clash_2",2200,80,"clash"),
	candidate_anchor(86,"front_stormscale_summit","clash_1",3000,170,"clash"),
	-- Two dragon arenas and two all-six-gem apex mines.
	candidate_anchor(87,"front_wyrmglass_crown","dragon",-3260,-40,"dragon"),
	candidate_anchor(88,"front_stormscale_summit","dragon",3260,-40,"dragon"),
	candidate_anchor(89,"front_wyrmglass_crown","apex_mine",-3200,80,"apex_mine"),
	candidate_anchor(90,"front_stormscale_summit","apex_mine",3200,80,"apex_mine"),
	-- Ten stable named-rare route instances; Captain Bonerattle owns one
	-- instance in each of its two published route zones.
	candidate_anchor(91,"elandor_goldmead_vale","rare_grimtusk",120,-2100,"rare_route"),
	candidate_anchor(92,"elandor_ashenward_march","rare_old_whitefang",-180,-650,"rare_route"),
	candidate_anchor(93,"elandor_stormvault_heights","rare_korgans_bane",-1850,-620,"rare_route"),
	candidate_anchor(94,"front_skyglass_canopy","rare_silkfang",2050,70,"rare_route"),
	candidate_anchor(95,"kragmar_blackwind_rise","rare_marrowclaw",-1850,620,"rare_route"),
	candidate_anchor(96,"kragmar_bannerbreak_mesa","rare_dustwing",180,650,"rare_route"),
	candidate_anchor(97,"front_stormscale_summit","rare_emerald_coil",3000,-120,"rare_route"),
	candidate_anchor(98,"kragmar_redtusk_savanna","rare_ashmaw",120,2100,"rare_route"),
	candidate_anchor(99,"front_broken_causeway","rare_captain_bonerattle",-600,80,"rare_route"),
	candidate_anchor(100,"front_shattered_line","rare_captain_bonerattle",600,-80,"rare_route"),
}

-- The apex camp socket species are semantic WP43 keys. They are attached to
-- the two apex-mine source records without registering or copying itemstrings.
source.anchors[89].socket_resource_keys = {"citrine","citrine","garnet","garnet","jade","jade","diamond","diamond","sapphire","sapphire","ruby","ruby"}
source.anchors[90].socket_resource_keys = {"citrine","citrine","garnet","garnet","jade","jade","diamond","diamond","sapphire","sapphire","ruby","ruby"}
for rare_index=91,100 do
	local row=source.anchors[rare_index]
	local first=row.candidates[1]
	row.patrol_route={
		point(first.x-48,first.z-24),point(first.x+16,first.z+40),
		point(first.x+56,first.z-16),
	}
end

source.templates = {
	{id="start", shape="flat", fitting_width=128, blend_width=256, max_cut=8, max_fill=8, force_native_dungeon=false},
	{id="capital_dwarf", shape="granite_terrace", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_human", shape="river_plateau", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_elf", shape="terraced_grove", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_undead", shape="raised_necropolis", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_orc", shape="mesa_shelf", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="capital_troll", shape="cenote_terrace", fitting_width=512, blend_width=704, max_cut=24, max_fill=16, force_native_dungeon=false},
	{id="village", shape="gentle_grade", fitting_width=96, blend_width=160, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="outpost", shape="gentle_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="bandit_home", shape="gentle_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="bandit_frontier", shape="gentle_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="mine", shape="gentle_grade", fitting_width=80, blend_width=128, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="mirefolk", shape="shallow_marsh_island", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="clash", shape="battlefield_grade", fitting_width=64, blend_width=112, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="dragon", shape="arena_terrace", fitting_width=96, blend_width=160, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="apex_mine", shape="mine_terrace", fitting_width=96, blend_width=160, max_cut=8, max_fill=6, force_native_dungeon=false},
	{id="rare_route", shape="patrol_route", fitting_width=32, blend_width=64, max_cut=3, max_fill=2, force_native_dungeon=false},
}

source.template_compositions = {
	{id="compose_start",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}},{op="blend",primitive_id="rim",parameters={inner_radius=64,outer_radius=128,height=0}}}},
	{id="compose_capital_dwarf",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=256,shoulder_width=96}},{op="overlay",primitive_id="terrace",parameters={step_height=4,step_run=48,rings=5}}}},
	{id="compose_capital_human",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=240,shoulder_width=112}},{op="overlay",primitive_id="tilt",parameters={axis_x=0,axis_z=1,rise=2,run=352}}}},
	{id="compose_capital_elf",version=1,operations={{op="apply",primitive_id="terrace",parameters={step_height=3,step_run=56,rings=5}},{op="blend",primitive_id="rim",parameters={inner_radius=240,outer_radius=352,height=0}}}},
	{id="compose_capital_undead",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=240,shoulder_width=112}},{op="overlay",primitive_id="terrace",parameters={step_height=3,step_run=48,rings=5}}}},
	{id="compose_capital_orc",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=256,shoulder_width=96}},{op="overlay",primitive_id="rim",parameters={inner_radius=208,outer_radius=256,height=8}}}},
	{id="compose_capital_troll",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=256,shoulder_width=96}},{op="subtract",primitive_id="basin",parameters={inner_radius=72,depth=12,rim_width=24}}}},
	{id="compose_village",version=1,operations={{op="apply",primitive_id="tilt",parameters={axis_x=1,axis_z=0,rise=1,run=96}}}},
	{id="compose_outpost",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}}}},
	{id="compose_bandit_home",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}}}},
	{id="compose_bandit_frontier",version=1,operations={{op="apply",primitive_id="tilt",parameters={axis_x=0,axis_z=1,rise=1,run=64}}}},
	{id="compose_mine",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=32,shoulder_width=24}}}},
	{id="compose_mirefolk",version=1,operations={{op="apply",primitive_id="causeway",parameters={surface_width=32,backing_depth=3}}}},
	{id="compose_clash",version=1,operations={{op="apply",primitive_id="flat",parameters={height_offset=0}},{op="overlay",primitive_id="cross_section",parameters={surface_width=32,corridor_width=48}}}},
	{id="compose_dragon",version=1,operations={{op="apply",primitive_id="plateau",parameters={inner_radius=48,shoulder_width=32}},{op="overlay",primitive_id="rim",parameters={inner_radius=36,outer_radius=48,height=4}}}},
	{id="compose_apex_mine",version=1,operations={{op="apply",primitive_id="terrace",parameters={step_height=2,step_run=16,rings=4}}}},
	{id="compose_rare_route",version=1,operations={{op="apply",primitive_id="cross_section",parameters={surface_width=3,corridor_width=8}}}},
	{id="compose_coastal_housing_core",version=1,operations={{op="apply",primitive_id="housing_smoothing",parameters={radius=50,relief_limit=12}}}},
}
for template_index=1,#source.templates do
	source.templates[template_index].composition_id="compose_"..source.templates[template_index].id
end

local function hydro(id,landmark_id,zone_id,profile,offset,depth,centreline,from_id,to_id)
	return {id=id,landmark_id=landmark_id,zone_id=zone_id,profile=profile,
		water_surface={reference="mapgen_water_level",offset=offset},depth=depth,
		centreline=centreline,from_id=from_id,to_id=to_id,bed_seal_layers=3,
		bank_seal_nodes=2,water_node_semantic="surface_water"}
end

-- Every reach is authored explicitly. In particular, crossings below are
-- vertices of their referenced reach; no compiler may synthesize or widen a
-- generic landmark-centred line to make an interface fit.
source.hydrology = {
	hydro("hydro_copperfell_streams","copperfell_drainage","elandor_copperfell_foothills","stream",18,2,{{x=-2114,z=-2050,half_width=12},{x=-1986,z=-2050,half_width=12}},"copperfell_spring","copperfell_sink"),
	hydro("hydro_frostbarrow_tarns","frostbarrow_tarns","elandor_frostbarrow_shelf","shallow_pond",62,2,{{x=-2414,z=-1740,half_width=12},{x=-2286,z=-1740,half_width=12}},"frostbarrow_inflow","frostbarrow_basin"),
	hydro("hydro_dawnmere_headwaters","dawnmere_headwaters","elandor_dawnmere_fields","spring",12,2,{{x=-64,z=-2500,half_width=12},{x=64,z=-2500,half_width=12}},"dawnmere_spring","dawnmere_outflow"),
	hydro("hydro_goldmead_millriver","goldmead_millriver","elandor_goldmead_vale","river",16,4,{{x=-64,z=-2020,half_width=12},{x=64,z=-2020,half_width=12}},"goldmead_upstream","goldmead_downstream"),
	hydro("hydro_highcourt_fork_west","highcourt_riverfork","elandor_highcourt","river",34,4,{{x=-300,z=-1750,half_width=18},{x=-120,z=-1550,half_width=22},{x=0,z=-1320,half_width=18}},"highcourt_west_source","highcourt_fork_join"),
	hydro("hydro_highcourt_fork_east","highcourt_riverfork","elandor_highcourt","river",34,4,{{x=300,z=-1750,half_width=16},{x=140,z=-1510,half_width=20},{x=0,z=-1320,half_width=18}},"highcourt_east_source","highcourt_fork_join"),
	hydro("hydro_whitebridge_main","whitebridge_crossing","elandor_whitebridge_shire","river",16,4,{{x=-964,z=-1500,half_width=12},{x=-700,z=-1500,half_width=12},{x=-400,z=-1500,half_width=12}},"whitebridge_upstream","whitebridge_downstream"),
	hydro("hydro_whitebridge_ford","whitebridge_ford","elandor_whitebridge_shire","ford",16,1,{{x=-900,z=-1100,half_width=12},{x=-820,z=-1180,half_width=12},{x=-720,z=-1260,half_width=12}},"whitebridge_ford_upstream","whitebridge_ford_downstream"),
	hydro("hydro_lethariel_lake","lethariel_crownlake","elandor_lethariel","ordinary_lake",34,8,{{x=1736,z=-1500,half_width=12},{x=1864,z=-1500,half_width=12}},"lethariel_inflow","lethariel_outflow"),
	hydro("hydro_lorindor_marsh","lorindor_berrymarsh","elandor_lorindor","shallow_marsh",28,1,{{x=1016,z=-1740,half_width=12},{x=1144,z=-1740,half_width=12}},"lorindor_inflow","lorindor_sink"),
	hydro("hydro_moonfall_lake","moonfall_crescent","elandor_moonfall_wood","ordinary_lake",18,8,{{x=2336,z=-1500,half_width=12},{x=2464,z=-1500,half_width=12}},"moonfall_inflow","moonfall_outflow"),
	hydro("hydro_mournfen_marsh","mournfen_drowned_roads","kragmar_mournfen","shallow_marsh",8,1,{{x=-2114,z=2100,half_width=12},{x=-1986,z=2100,half_width=12}},"mournfen_inflow","mournfen_sink"),
	hydro("hydro_sunscar_waterholes","sunscar_waterholes","kragmar_sunscar_flats","shallow_pond",12,2,{{x=196,z=2450,half_width=12},{x=324,z=2450,half_width=12}},"sunscar_seep","sunscar_basin"),
	hydro("hydro_speargrass_dryriver","speargrass_dryriver","kragmar_speargrass_reach","dry_channel",28,0,{{x=-964,z=1500,half_width=12},{x=-836,z=1500,half_width=12}},"speargrass_dry_head","speargrass_dry_mouth"),
	hydro("hydro_raincall_upper","raincall_falls","kragmar_raincall_basin","shallow_pond",72,2,{{x=1900,z=2200,half_width=24},{x=1990,z=2110,half_width=28}},"raincall_headwater","raincall_upper_lip"),
	hydro("hydro_raincall_middle","raincall_falls","kragmar_raincall_basin","shallow_pond",60,2,{{x=1990,z=2070,half_width=24},{x=2050,z=2010,half_width=28}},"raincall_upper_drop","raincall_lower_lip"),
	hydro("hydro_raincall_plunge","raincall_falls","kragmar_raincall_basin","plunge_pool",44,12,{{x=2050,z=1970,half_width=30},{x=2130,z=1900,half_width=34}},"raincall_lower_drop","raincall_outflow"),
	hydro("hydro_kezamba_cenote","kezamba_cenote","kragmar_kezamba","deep_cenote",64,12,{{x=1736,z=1500,half_width=12},{x=1864,z=1500,half_width=12}},"kezamba_inflow","kezamba_cenote_sink"),
	hydro("hydro_whispering_reedmaze","whispering_reedmaze","kragmar_whispering_reedlands","shallow_marsh",8,1,{{x=836,z=1500,half_width=12},{x=964,z=1500,half_width=12}},"reedmaze_inflow","reedmaze_outflow"),
	hydro("hydro_totemwater_delta","totemwater_delta","kragmar_totemwater_reach","delta_arm",8,4,{{x=2336,z=1500,half_width=12},{x=2464,z=1500,half_width=12}},"totemwater_upstream","totemwater_mouth"),
	hydro("hydro_gravesalt_pans","gravesalt_whitewall","front_gravesalt_escarpment","shallow_marsh",100,1,{{x=-2114,z=0,half_width=12},{x=-1986,z=0,half_width=12}},"gravesalt_seep","gravesalt_pan"),
	hydro("hydro_broken_marsh","broken_marsh","front_broken_causeway","ordinary_lake",8,8,{{x=-1125,z=250,half_width=12},{x=-1500,z=-125,half_width=12},{x=-750,z=-100,half_width=12},{x=-375,z=-250,half_width=12}},"broken_marsh_inflow","broken_marsh_outflow"),
}

source.hydrology_interfaces = {
	{id="highcourt_fork_join",kind="confluence",from_ids={"hydro_highcourt_fork_west","hydro_highcourt_fork_east"},to_id="highcourt_outflow",sealed=true},
	{id="whitebridge_bridge_water",kind="bridge",hydrology_id="hydro_whitebridge_main",route_interface_id="whitebridge_bridge",position=point(-400,-1500),transition_profile="bridge_clearance",sealed=true},
	{id="whitebridge_ford_water",kind="ford",hydrology_id="hydro_whitebridge_ford",route_interface_id="whitebridge_ford",position=point(-900,-1100),transition_profile="ford_bed",sealed=true},
	{id="raincall_upper_rapid",kind="rapid",hydrology_id="hydro_raincall_upper",position=point(1960,2140),transition_profile="rapid_approach",run=48,drop=4,sealed=true},
	{id="raincall_upper_fall",kind="waterfall",upper_id="hydro_raincall_upper",lower_id="hydro_raincall_middle",position=point(1990,2090),lip_id="raincall_upper_lip",drop_id="raincall_upper_drop",plunge_id="raincall_upper_plunge",drop_height=12,drop_mask_width=10,plunge_profile="shallow_pond",bed_seal_layers=3,bank_seal_nodes=2},
	{id="raincall_middle_rapid",kind="rapid",hydrology_id="hydro_raincall_middle",position=point(2020,2040),transition_profile="rapid_approach",run=40,drop=4,sealed=true},
	{id="raincall_lower_fall",kind="waterfall",upper_id="hydro_raincall_middle",lower_id="hydro_raincall_plunge",position=point(2050,1990),lip_id="raincall_lower_lip",drop_id="raincall_lower_drop",plunge_id="raincall_lower_plunge",drop_height=16,drop_mask_width=12,plunge_profile="plunge_pool",bed_seal_layers=3,bank_seal_nodes=2},
	{id="broken_causeway_water",kind="causeway",hydrology_id="hydro_broken_marsh",route_interface_id="broken_causeway",sealed=true},
	{id="broken_ford_water",kind="ford",hydrology_id="hydro_broken_marsh",route_interface_id="broken_ford",sealed=true},
	{id="broken_aqueduct_water",kind="bridge",hydrology_id="hydro_broken_marsh",route_interface_id="broken_aqueduct",sealed=true},
}

source.housing_masks = {
	{id="housing_elandor_copperfell",zone_id="elandor_copperfell_foothills",primitive="polygon",orientation="counterclockwise",polygon={point(-2520,-2470),point(-2220,-2470),point(-2180,-1930),point(-2520,-1930),point(-2520,-2470)}},
	{id="housing_elandor_goldmead",zone_id="elandor_goldmead_vale",primitive="polygon",orientation="counterclockwise",polygon={point(-600,-2260),point(600,-2260),point(560,-1910),point(-560,-1910),point(-600,-2260)}},
	{id="housing_elandor_starbough",zone_id="elandor_starbough_vale",primitive="polygon",orientation="counterclockwise",polygon={point(2220,-2470),point(2520,-2470),point(2520,-1930),point(2180,-1930),point(2220,-2470)}},
	{id="housing_elandor_whitebridge",zone_id="elandor_whitebridge_shire",primitive="polygon",orientation="counterclockwise",polygon={point(-1360,-1860),point(-440,-1860),point(-440,-1140),point(-1360,-1140),point(-1360,-1860)}},
	{id="housing_elandor_lorindor",zone_id="elandor_lorindor",primitive="polygon",orientation="counterclockwise",polygon={point(440,-1860),point(1360,-1860),point(1360,-1140),point(440,-1140),point(440,-1860)}},
	{id="housing_kragmar_mournfen",zone_id="kragmar_mournfen",primitive="polygon",orientation="counterclockwise",polygon={point(-2520,1930),point(-2180,1930),point(-2220,2470),point(-2520,2470),point(-2520,1930)}},
	{id="housing_kragmar_redtusk",zone_id="kragmar_redtusk_savanna",primitive="polygon",orientation="counterclockwise",polygon={point(-560,1910),point(560,1910),point(600,2260),point(-600,2260),point(-560,1910)}},
	{id="housing_kragmar_raincall",zone_id="kragmar_raincall_basin",primitive="polygon",orientation="counterclockwise",polygon={point(2180,1930),point(2520,1930),point(2520,2470),point(2220,2470),point(2180,1930)}},
	{id="housing_kragmar_speargrass",zone_id="kragmar_speargrass_reach",primitive="polygon",orientation="counterclockwise",polygon={point(-1360,1140),point(-440,1140),point(-440,1860),point(-1360,1860),point(-1360,1140)}},
	{id="housing_kragmar_whispering",zone_id="kragmar_whispering_reedlands",primitive="polygon",orientation="counterclockwise",polygon={point(440,1140),point(1360,1140),point(1360,1860),point(440,1860),point(440,1140)}},
}

source.coastal_housing_cores = {
	{id="coastal_core_copperfell",zone_id="elandor_copperfell_foothills",housing_mask_id="housing_elandor_copperfell",composition_id="compose_coastal_housing_core",side="west",frontage_min=600,inland_depth_min=300,relief_max=12,centerline={point(-2580,-2500),point(-2580,-2200),point(-2600,-1900)}},
	{id="coastal_core_starbough",zone_id="elandor_starbough_vale",housing_mask_id="housing_elandor_starbough",composition_id="compose_coastal_housing_core",side="east",frontage_min=600,inland_depth_min=300,relief_max=12,centerline={point(2600,-2500),point(2580,-2200),point(2600,-1900)}},
	{id="coastal_core_mournfen",zone_id="kragmar_mournfen",housing_mask_id="housing_kragmar_mournfen",composition_id="compose_coastal_housing_core",side="west",frontage_min=600,inland_depth_min=300,relief_max=12,centerline={point(-2600,1900),point(-2580,2200),point(-2600,2500)}},
	{id="coastal_core_raincall",zone_id="kragmar_raincall_basin",housing_mask_id="housing_kragmar_raincall",composition_id="compose_coastal_housing_core",side="east",frontage_min=600,inland_depth_min=300,relief_max=12,centerline={point(2600,1900),point(2580,2200),point(2600,2500)}},
}

source.semantics = {
	race_regions = {"dwarf","human","elf","undead","orc","troll"},
	regional_resource_keys = {"citrine","garnet","jade","diamond","sapphire","ruby"},
	cultural_material_keys = {"runeslate","sunwax","moonresin","gravesalt","red_ochre","spirit_resin"},
	signature_wood_keys = {"mountain_pine","oak","silverwood","gravewood","spikethorn_acacia","kapok"},
	-- Stable assignments only. All resource species, node names, harvest tiers,
	-- depths and density values remain owned and resolved by WP43.
	race_region_assignments = {
		{race_region="dwarf",g1="garnet",g2="sapphire",cultural="runeslate",signature_wood="mountain_pine"},
		{race_region="human",g1="citrine",g2="diamond",cultural="sunwax",signature_wood="oak"},
		{race_region="elf",g1="jade",g2="sapphire",cultural="moonresin",signature_wood="silverwood"},
		{race_region="undead",g1="citrine",g2="ruby",cultural="gravesalt",signature_wood="gravewood"},
		{race_region="orc",g1="garnet",g2="diamond",cultural="red_ochre",signature_wood="spikethorn_acacia"},
		{race_region="troll",g1="jade",g2="ruby",cultural="spirit_resin",signature_wood="kapok"},
	},
}

-- Numeric ids are the canonical one-based positions in every ordered record
-- family. They are installed in one deterministic pass so records with large
-- literal bodies cannot accidentally drift away from their array position.
local numeric_collections = {
	source.relief_profiles, source.route_classes, source.water_classes,
	source.template_primitives, source.zones, source.land_edges,
	source.route_stations,source.routes,source.route_interfaces,
	source.route_crossing_interfaces,
	source.boat_edges,source.island_landings,source.island_route_stations,
	source.island_routes,source.island_route_interfaces,source.perimeters,
	source.bays, source.islands, source.channels, source.landmarks,
	source.anchors, source.templates,source.template_compositions,
	source.hydrology,source.hydrology_interfaces, source.housing_masks,
	source.coastal_housing_cores, source.semantics.race_region_assignments,
}
for collection_index = 1, #numeric_collections do
	local collection = numeric_collections[collection_index]
	for record_index = 1, #collection do
		collection[record_index].numeric_id = record_index
	end
end

return source
