-- Compact, engine-free source for the fixed WP40 simple map. This file does
-- not load or filter the retired exact-topology catalog.

local function point(x, z)
	return {x = x, z = z}
end

local function fraction(numerator, denominator)
	return {numerator = numerator, denominator = denominator}
end

local function polygon(...)
	return {...}
end

local source = {
	schema = "grug_wp40_simple_map_source_v2",
	layout_id = "wp40-simple-map-v1d",
	layout_revision_id = "wp40-simple-map-v1e",
	height_revision_id = "wp40-height-shore-v6",
	extent = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200},
	shelf_width = 80,
	housing_policy = {
		reservation_width = 101,
		reservation_radius = 50,
		minimum_gap = 10,
		lattice_spacing = 111,
		lattice_origin_period = 111,
		hash_order_count = 16,
		hash_domain_prefix = "housing-pack-",
		hash_order_numbering = "zero_based_two_digit",
		conflict_rule = "candidate_expanded_aabb_v1",
		tie_break = "z_then_x",
		bias_direction = "nearest_first",
		edge_bias_scope = "mask_polygon_boundary",
		route_bias_scope = "all_land_route_centrelines",
		poi_bias_scope = "all_actual_anchor_positions_v1",
		greedy_orders = {
			"minimum_conflict_degree", "maximum_conflict_degree",
			"edge_biased", "route_biased", "poi_biased",
			"row_major", "reverse_row_major",
		},
	},
}

local function zone(numeric_id, id, display_name, race_region, faction,
		territory_rule, pvp_rule, level_min, level_max, relief_id,
		hub_x, hub_z, biomes, civic)
	local macro_region
	if numeric_id <= 16 then macro_region = "elandor_mainland"
	elseif numeric_id <= 32 then macro_region = "kragmar_mainland"
	elseif numeric_id == 33 then macro_region = "wyrmglass_island"
	elseif numeric_id <= 37 then macro_region = "holy_grounds"
	else macro_region = "stormscale_island" end
	return {
		numeric_id = numeric_id,
		id = id,
		display_name = display_name,
		race_region = race_region,
		faction = faction,
		territory_rule = territory_rule,
		pvp_rule = pvp_rule,
		level_min = level_min,
		level_max = level_max,
		primary_relief_id = relief_id,
		hub = point(hub_x, hub_z),
		macro_region = macro_region,
		bias = 0,
		biomes = biomes,
		civic_no_hostiles = civic or false,
	}
end

source.zones = {
	zone(1,"elandor_hearthpine_vale","Hearthpine Vale","dwarf","accord","accord_home","peaceful",1,10,"lowland",-1800,-2550,{"grug_pine_hills","grug_crags"}),
	zone(2,"elandor_copperfell_foothills","Copperfell Foothills","dwarf","accord","accord_home","peaceful",11,20,"rolling_hills",-1800,-2050,{"grug_pine_hills","grug_crags"}),
	zone(3,"elandor_dur_brannoc","Dur Brannoc","dwarf","accord","accord_home","peaceful",20,30,"plateau",-1800,-1500,{"grug_pine_hills","grug_crags"},true),
	zone(4,"elandor_frostbarrow_shelf","Frostbarrow Shelf","dwarf","accord","accord_home","peaceful",21,30,"plateau",-2400,-1500,{"grug_pine_hills","grug_crags","grug_swamp"}),
	zone(5,"elandor_stormvault_heights","Stormvault Heights","dwarf",false,"contested_land","contested",31,40,"highland",-1800,-700,{"grug_crags","grug_crags_snowy"}),
	zone(6,"elandor_dawnmere_fields","Dawnmere Fields","human","accord","accord_home","peaceful",1,10,"lowland",0,-2550,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(7,"elandor_goldmead_vale","Goldmead Vale","human","accord","accord_home","peaceful",11,20,"lowland",0,-2050,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(8,"elandor_highcourt","Highcourt","human","accord","accord_home","peaceful",20,30,"rolling_hills",0,-1500,{"grug_meadows","grug_deep_forest"},true),
	zone(9,"elandor_whitebridge_shire","Whitebridge Shire","human","accord","accord_home","peaceful",21,30,"lowland",-900,-1500,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(10,"elandor_ashenward_march","Ashenward March","human",false,"contested_land","contested",31,40,"rolling_hills",0,-700,{"grug_deep_forest","grug_meadows","grug_swamp"}),
	zone(11,"elandor_silverleaf_glades","Silverleaf Glades","elf","accord","accord_home","peaceful",1,10,"lowland",1800,-2550,{"grug_elf_forest","grug_deep_forest"}),
	zone(12,"elandor_starbough_vale","Starbough Vale","elf","accord","accord_home","peaceful",11,20,"rolling_hills",1800,-2050,{"grug_elf_forest","grug_deep_forest"}),
	zone(13,"elandor_lethariel","Lethariel","elf","accord","accord_home","peaceful",20,30,"rolling_hills",1800,-1500,{"grug_elf_forest","grug_deep_forest"},true),
	zone(14,"elandor_lorindor","Lorindor","elf","accord","accord_home","peaceful",21,30,"rolling_hills",900,-1500,{"grug_elf_forest","grug_deep_forest","grug_swamp"}),
	zone(15,"elandor_moonfall_wood","Moonfall Wood","elf","accord","accord_home","peaceful",21,30,"lowland",2400,-1500,{"grug_elf_forest","grug_deep_forest","grug_swamp"}),
	zone(16,"elandor_glassroot_wilds","Glassroot Wilds","elf",false,"contested_land","contested",31,40,"highland",1800,-700,{"grug_deep_forest","grug_jungle_fringe","grug_elf_forest","grug_swamp"}),
	zone(17,"kragmar_stillgrave_hollow","Stillgrave Hollow","undead","throng","throng_home","peaceful",1,10,"lowland",-1800,2550,{"grug_blight","grug_bone_forest","grug_swamp"}),
	zone(18,"kragmar_mournfen","Mournfen","undead","throng","throng_home","peaceful",11,20,"wetland_delta",-1800,2050,{"grug_blight","grug_bone_forest","grug_swamp"}),
	zone(19,"kragmar_nhal_veyr","Nhal Veyr","undead","throng","throng_home","peaceful",20,30,"plateau",-1800,1500,{"grug_blight","grug_bone_forest"},true),
	zone(20,"kragmar_ossuary_reach","Ossuary Reach","undead","throng","throng_home","peaceful",21,30,"rolling_hills",-2400,1500,{"grug_blight","grug_bone_forest","grug_swamp"}),
	zone(21,"kragmar_blackwind_rise","Blackwind Rise","undead",false,"contested_land","contested",31,40,"highland",-1800,700,{"grug_bone_forest","grug_blight","grug_swamp"}),
	zone(22,"kragmar_sunscar_flats","Sunscar Flats","orc","throng","throng_home","peaceful",1,10,"lowland",0,2550,{"grug_savanna","grug_badlands"}),
	zone(23,"kragmar_redtusk_savanna","Redtusk Savanna","orc","throng","throng_home","peaceful",11,20,"rolling_hills",0,2050,{"grug_savanna","grug_badlands"}),
	zone(24,"kragmar_gor_drazhak","Gor Drazhak","orc","throng","throng_home","peaceful",20,30,"plateau",0,1500,{"grug_savanna","grug_badlands"},true),
	zone(25,"kragmar_speargrass_reach","Speargrass Reach","orc","throng","throng_home","peaceful",21,30,"rolling_hills",-900,1500,{"grug_savanna","grug_badlands","grug_swamp"}),
	zone(26,"kragmar_bannerbreak_mesa","Bannerbreak Mesa","orc",false,"contested_land","contested",31,40,"plateau",0,700,{"grug_badlands","grug_savanna","grug_swamp"}),
	zone(27,"kragmar_kapok_cradle","Kapok Cradle","troll","throng","throng_home","peaceful",1,10,"lowland",1800,2550,{"grug_jungle_edge","grug_swamp"}),
	zone(28,"kragmar_raincall_basin","Raincall Basin","troll","throng","throng_home","peaceful",11,20,"rolling_hills",1800,2050,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"}),
	zone(29,"kragmar_kezamba","Kezamba","troll","throng","throng_home","peaceful",20,30,"plateau",1800,1500,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"},true),
	zone(30,"kragmar_whispering_reedlands","Whispering Reedlands","troll","throng","throng_home","peaceful",21,30,"wetland_delta",900,1500,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"}),
	zone(31,"kragmar_totemwater_reach","Totemwater Reach","troll","throng","throng_home","peaceful",21,30,"wetland_delta",2400,1500,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"}),
	zone(32,"kragmar_thunderroot_wilds","Thunderroot Wilds","troll",false,"contested_land","contested",31,40,"highland",1800,700,{"grug_deep_jungle","grug_badlands_east","grug_swamp"}),
	zone(33,"front_wyrmglass_crown","The Wyrmglass Crown","dwarf",false,"contested_land","contested",60,60,"mountain",-3150,0,{"grug_crags","grug_crags_snowy","grug_beach"}),
	zone(34,"front_gravesalt_escarpment","Gravesalt Escarpment","undead",false,"contested_land","contested",51,59,"highland",-2000,0,{"grug_bone_forest","grug_blight","grug_swamp","grug_beach"}),
	zone(35,"front_broken_causeway","The Broken Causeway","human",false,"contested_land","contested",31,40,"wetland_delta",-750,0,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(36,"front_shattered_line","The Shattered Line","orc",false,"contested_land","contested",41,50,"plateau",750,0,{"grug_badlands","grug_savanna","grug_swamp"}),
	zone(37,"front_skyglass_canopy","The Skyglass Canopy","elf",false,"contested_land","contested",51,59,"highland",2000,0,{"grug_jungle_fringe","grug_deep_forest","grug_elf_forest"}),
	zone(38,"front_stormscale_summit","Stormscale Summit","troll",false,"contested_land","contested",60,60,"mountain",3150,0,{"grug_deep_jungle","grug_badlands_east","grug_swamp","grug_beach"}),
}

-- A sub-node power-weight nudge keeps the Redtusk/Speargrass boundary from
-- leaving one isolated Redtusk coast node where it meets the western bay.
source.zones[25].bias = 256

-- Stable logical-biome target shares remain authored zone data. Keeping the
-- compact shares beside the zone order avoids repeating the rest of each
-- already-readable zone record.
local biome_share_rows = {
	{90,10},{75,25},{60,40},{55,40,5},{75,25},
	{85,5,10},{65,20,15},{80,20},{50,35,15},{50,30,20},
	{95,5},{80,20},{90,10},{50,30,20},{40,45,15},{45,35,10,10},
	{90,5,5},{60,10,30},{75,25},{40,50,10},{65,30,5},
	{95,5},{75,25},{60,40},{55,40,5},{70,25,5},
	{90,10},{65,15,20},{75,20,5},{45,25,30},{35,45,20},{55,30,15},
	{55,30,15},{55,15,15,15},{40,25,35},{65,20,15},{60,25,15},
	{50,20,15,15},
}
for zone_index = 1, #source.zones do
	local zone_row=source.zones[zone_index]
	local shares=biome_share_rows[zone_index]
	for biome_index = 1, #zone_row.biomes do
		zone_row.biomes[biome_index] = {
			id=zone_row.biomes[biome_index],share=shares[biome_index],
		}
	end
end

-- Positive macro land is deliberately small and readable. Bays below are
-- independent subtractive planned-water masks.
source.land_primitives = {
	{id="elandor_west_prong",region="elandor_mainland",kind="capsule",a=point(-1850,-2310),b=point(-1820,-1700),radius=650},
	{id="elandor_centre_prong",region="elandor_mainland",kind="capsule",a=point(-40,-2310),b=point(-40,-1720),radius=650},
	{id="elandor_east_prong",region="elandor_mainland",kind="capsule",a=point(1850,-2290),b=point(1780,-1700),radius=670},
	{id="elandor_belt",region="elandor_mainland",kind="rounded_rect",min_x=-2550,max_x=2550,min_z=-2150,max_z=-900,radius=300},
	{id="elandor_front",region="elandor_mainland",kind="rounded_rect",min_x=-2500,max_x=2500,min_z=-1160,max_z=0,radius=240},
	{id="elandor_west_shoulder",region="elandor_mainland",kind="ellipse",center=point(-2250,-1450),radius_x=300,radius_z=650},
	{id="elandor_east_shoulder",region="elandor_mainland",kind="ellipse",center=point(2260,-1440),radius_x=290,radius_z=640},
	{id="kragmar_west_prong",region="kragmar_mainland",kind="capsule",a=point(-1880,2310),b=point(-1760,1710),radius=660},
	{id="kragmar_centre_prong",region="kragmar_mainland",kind="capsule",a=point(30,2300),b=point(80,1740),radius=660},
	{id="kragmar_east_prong",region="kragmar_mainland",kind="capsule",a=point(1850,2300),b=point(1800,1700),radius=660},
	{id="kragmar_belt",region="kragmar_mainland",kind="rounded_rect",min_x=-2550,max_x=2550,min_z=880,max_z=2150,radius=330},
	{id="kragmar_front",region="kragmar_mainland",kind="rounded_rect",min_x=-2500,max_x=2500,min_z=0,max_z=1160,radius=250},
	{id="kragmar_west_shoulder",region="kragmar_mainland",kind="ellipse",center=point(-2250,1460),radius_x=300,radius_z=640},
	{id="kragmar_east_shoulder",region="kragmar_mainland",kind="ellipse",center=point(2260,1480),radius_x=290,radius_z=650},
}
for primitive_index=1,#source.land_primitives do
	source.land_primitives[primitive_index].operation="add"
end

source.bays = {
	{id="bay_elandor_west",region="elandor_mainland",shore_zone_ids={1,2,6,7},deep_ocean_side="min_z",deep_ocean_cut_z=-3000,centreline={{x=-940,z=-3660,half_width=800},{x=-950,z=-3460,half_width=700},{x=-970,z=-3260,half_width=620},{x=-900,z=-2960,half_width=540},{x=-920,z=-2750,half_width=500},{x=-980,z=-2550,half_width=400},{x=-900,z=-2350,half_width=270},{x=-1020,z=-2200,half_width=220},{x=-970,z=-2070,half_width=130},{x=-1000,z=-1980,half_width=72}}},
	{id="bay_elandor_east",region="elandor_mainland",shore_zone_ids={6,7,11,12},deep_ocean_side="min_z",deep_ocean_cut_z=-3000,centreline={{x=940,z=-3660,half_width=800},{x=930,z=-3460,half_width=700},{x=920,z=-3260,half_width=620},{x=900,z=-2960,half_width=540},{x=920,z=-2750,half_width=500},{x=850,z=-2550,half_width=400},{x=1010,z=-2350,half_width=270},{x=950,z=-2200,half_width=220},{x=1030,z=-2070,half_width=130},{x=990,z=-1970,half_width=72}}},
	{id="bay_kragmar_west",region="kragmar_mainland",shore_zone_ids={17,18,22,23},deep_ocean_side="max_z",deep_ocean_cut_z=3000,centreline={{x=-940,z=3660,half_width=800},{x=-935,z=3460,half_width=700},{x=-930,z=3260,half_width=620},{x=-900,z=2960,half_width=540},{x=-920,z=2750,half_width=500},{x=-980,z=2550,half_width=400},{x=-900,z=2350,half_width=270},{x=-1060,z=2200,half_width=230},{x=-980,z=2080,half_width=190},{x=-1020,z=1990,half_width=100}}},
	{id="bay_kragmar_east",region="kragmar_mainland",shore_zone_ids={22,23,27,28},deep_ocean_side="max_z",deep_ocean_cut_z=3000,centreline={{x=940,z=3660,half_width=800},{x=930,z=3460,half_width=700},{x=920,z=3260,half_width=620},{x=900,z=2960,half_width=540},{x=920,z=2750,half_width=500},{x=850,z=2550,half_width=400},{x=1010,z=2350,half_width=270},{x=950,z=2200,half_width=220},{x=1030,z=2070,half_width=130},{x=920,z=1960,half_width=72}}},
}

source.islands = {
	{id="island_wyrmglass",region="wyrmglass_island",zone_numeric_id=33,polygon=polygon(point(-3430,-80),point(-3360,-260),point(-3160,-330),point(-2940,-250),point(-2860,-80),point(-2890,150),point(-3060,320),point(-3290,280),point(-3440,100))},
	{id="island_stormscale",region="stormscale_island",zone_numeric_id=38,polygon=polygon(point(2870,-130),point(2970,-310),point(3200,-340),point(3400,-220),point(3440,20),point(3370,260),point(3150,330),point(2940,230),point(2860,60))},
}

source.channels = {
	{id="channel_wyrmglass",polygon=polygon(point(-2850,-350),point(-2500,-350),point(-2500,350),point(-2850,350)),warning_width=48,minimum_hard_width=104},
	{id="channel_stormscale",polygon=polygon(point(2500,-350),point(2860,-350),point(2860,350),point(2500,350)),warning_width=48,minimum_hard_width=104},
}

-- Round 22 zone borders and coastline (world_zones.md §7.1-7.4, D24): the
-- parameters of `zone_field.lua`. The land primitives, bays and island
-- polygons above give the macro silhouette; the world seed warps it.
source.zone_field = {
	seed_domain = "r22-zones:",
	-- Composed warp steps (periods and per-component amplitudes in nodes). Keep
	-- every step at amp * 7.3 * sqrt(2) / period < 0.8: that is the no-fold
	-- guarantee, so re-tune amplitudes only under this bound.
	warp_periods = {3000, 1800, 1000, 450, 200, 90, 40},
	warp_amps = {150, 70, 40, 22, 12, 5, 2.5},
	-- small-scale coast irregularity added to the signed distance (nodes)
	coast_periods = {480, 220, 90, 36},
	coast_amps = {50, 45, 16, 4},
	-- power weight (node^2) of the four Battlegrounds zones
	front_bias = -160000,
	-- land joining the two mainland fronts (replaces the old front rectangle)
	front_band = {min_x = -2520, max_x = 2520, min_z = -300, max_z = 300, radius = 160},
	-- Segment sites {x_from, x_to[, z]}: the Battlegrounds zones on z = 0 and the
	-- six frontier zones on their hub rows, so the front stays one band and no
	-- Elandor zone touches a Kragmar zone.
	front_segments = {[34] = {-2450, -1425}, [35] = {-1325, -50},
		[36] = {50, 1325}, [37] = {1425, 2450},
		[5] = {-2250, -1350, -700}, [10] = {-450, 450, -700}, [16] = {1350, 2250, -700},
		[21] = {-2250, -1350, 700}, [26] = {-450, 450, 700}, [32] = {1350, 2250, 700}},
	-- extra power weight (node^2): the side zones between a capital and the
	-- coast would otherwise be squeezed into coastal slivers
	zone_bias = {[4] = 60000, [15] = 60000, [20] = 60000, [31] = 60000, [25] = 30000},
	-- anchor keeping (one construction pass)
	zone_margin = 24,       -- nodes a key-point footprint sits inside its zone
	land_margin = 16,       -- nodes a key-point footprint sits above the coast
	bulge_falloff = 140,    -- nodes from footprint edge to zero bulge
	bonus_falloff = 220,    -- nodes from footprint edge to zero land bonus
	landing_damp = 0.15, landing_damp_r0 = 120, landing_damp_falloff = 380,
	island_damp = 0.05, island_damp_r0 = 320, island_damp_falloff = 420,
	-- dragon islands: polygon scale towards the hub, coast-noise factor, envelope
	island_scale = 0.85, island_noise = 0.5,
	island_envelope = {half_x = 300, half_z = 350, radius = 140},
	-- how far coast noise pulls the envelope clamp inward (nodes), and the
	-- radius of land kept around each island landing
	island_envelope_jitter = 56, island_landing_keep = 20,
	-- construction self-check (rough targets) and its weaker-warp fallback
	check = {grid = 24, inland_cells = 2, coast_cells = 24, min_strait = 104,
		min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200,
		strait_from = 2200, strait_to = 3450},
	fallback_scales = {1, 0.8, 0.6, 0.4, 0.2, 0},
	-- gameplay neighbours: zones sharing at least this much land border (D14),
	-- counted on a grid of this spacing
	neighbor_grid = 16, neighbor_min_border = 64,
	-- coastal housing areas: own-zone land up to this far from the coast
	coastal_housing_depth = 300,
	-- biome dither at zone borders: jitter amplitude and period (nodes), and
	-- the border band (warped-space nodes) where the palette zone is re-looked up
	biome_dither = {amplitude = 24, period = 18, band = 40},
}

-- Roads (Round 22 Phase 4) and inland water (Phase 5) are rebuilt per world
-- seed. The pre-Round-22 route, station, gate, spur, crossing, ingress,
-- landmark and hydrology tables were removed at the start of Phase 5 together
-- with the load asserts and planner relation checks that pinned them.

source.boat_paths = {
	{id="boat_wyrmglass_south",kind="boat",from_zone=34,to_zone=33,width=96,landing_id="landing_wyrmglass_south",centreline={point(-2500,-125),point(-2700,-125),point(-2890,-125)}},
	{id="boat_wyrmglass_north",kind="boat",from_zone=34,to_zone=33,width=96,landing_id="landing_wyrmglass_north",centreline={point(-2500,125),point(-2700,125),point(-2890,125)}},
	{id="boat_stormscale_south",kind="boat",from_zone=37,to_zone=38,width=96,landing_id="landing_stormscale_south",centreline={point(2500,-125),point(2700,-125),point(2890,-125)}},
	{id="boat_stormscale_north",kind="boat",from_zone=37,to_zone=38,width=96,landing_id="landing_stormscale_north",centreline={point(2500,125),point(2700,125),point(2920,125)}},
}
source.island_landings = {
	{id="landing_wyrmglass_south",boat_path_id="boat_wyrmglass_south",zone_numeric_id=33,position=point(-2890,-125),width=96},
	{id="landing_wyrmglass_north",boat_path_id="boat_wyrmglass_north",zone_numeric_id=33,position=point(-2890,125),width=96},
	{id="landing_stormscale_south",boat_path_id="boat_stormscale_south",zone_numeric_id=38,position=point(2890,-125),width=96},
	{id="landing_stormscale_north",boat_path_id="boat_stormscale_north",zone_numeric_id=38,position=point(2920,125),width=96},
}
source.boat_parity_policy = {
	id="paired_axis_aligned_node_run_v1",metric="axis_aligned_polyline_node_run",
	maximum_difference_numerator=1,maximum_difference_denominator=10,
	pairs={{"boat_wyrmglass_south","boat_stormscale_south"},
		{"boat_wyrmglass_north","boat_stormscale_north"}},
}

source.housing_masks = {
	{id="housing_elandor_copperfell",zone_numeric_id=2,polygon=polygon(point(-2520,-2500),point(-2180,-2500),point(-2180,-1900),point(-2520,-1900))},
	{id="housing_elandor_goldmead",zone_numeric_id=7,polygon=polygon(point(-600,-2260),point(600,-2260),point(560,-1910),point(-560,-1910))},
	{id="housing_elandor_starbough",zone_numeric_id=12,polygon=polygon(point(2180,-2500),point(2520,-2500),point(2520,-1900),point(2180,-1900))},
	{id="housing_elandor_whitebridge",zone_numeric_id=9,polygon=polygon(point(-1360,-1860),point(-440,-1860),point(-440,-1140),point(-1360,-1140))},
	{id="housing_elandor_lorindor",zone_numeric_id=14,polygon=polygon(point(440,-1860),point(1360,-1860),point(1360,-1140),point(440,-1140))},
	{id="housing_kragmar_mournfen",zone_numeric_id=18,polygon=polygon(point(-2525,1900),point(-2180,1900),point(-2180,2500),point(-2525,2500))},
	{id="housing_kragmar_redtusk",zone_numeric_id=23,polygon=polygon(point(-560,1910),point(560,1910),point(600,2260),point(-600,2260))},
	{id="housing_kragmar_raincall",zone_numeric_id=28,polygon=polygon(point(2180,1900),point(2520,1900),point(2520,2500),point(2180,2500))},
	{id="housing_kragmar_speargrass",zone_numeric_id=25,polygon=polygon(point(-1360,1140),point(-440,1140),point(-440,1860),point(-1360,1860))},
	{id="housing_kragmar_whispering",zone_numeric_id=30,polygon=polygon(point(440,1140),point(1360,1140),point(1360,1860),point(440,1860))},
}
-- The four coastal housing areas (world_zones.md §7.5, D21, D24): the layout
-- authors only an approximate stretch; the exact mask is the zone's own land
-- within `zone_field.coastal_housing_depth` of the finished coast inside this
-- window. The window spans the zone's rows from the bay to past the outer
-- coast, because the per-seed borders can hand either coast to a neighbour.
local coastal_housing_windows = {
	housing_elandor_copperfell={min_x=-2900,max_x=-900,min_z=-2500,max_z=-1900},
	housing_elandor_starbough={min_x=900,max_x=2900,min_z=-2500,max_z=-1900},
	housing_kragmar_mournfen={min_x=-2900,max_x=-900,min_z=1900,max_z=2500},
	housing_kragmar_raincall={min_x=900,max_x=2900,min_z=1900,max_z=2500},
}
for _, mask in ipairs(source.housing_masks) do
	mask.coastal_window = coastal_housing_windows[mask.id]
end

local anchor_rows = {
	{1,"start","start","authored_fixed",0,-1800,-2550},
	{6,"start","start","authored_fixed",0,0,-2550},
	{11,"start","start","authored_fixed",0,1800,-2550},
	{17,"start","start","authored_fixed",0,-1800,2550},
	{22,"start","start","authored_fixed",0,0,2550},
	{27,"start","start","authored_fixed",0,1800,2550},
	{3,"capital","capital_dwarf","authored_fixed",0,-1800,-1500},
	{8,"capital","capital_human","authored_fixed",0,0,-1500},
	{13,"capital","capital_elf","authored_fixed",0,1800,-1500},
	{19,"capital","capital_undead","authored_fixed",0,-1800,1500},
	{24,"capital","capital_orc","authored_fixed",0,0,1500},
	{29,"capital","capital_troll","authored_fixed",0,1800,1500},
	{2,"village_1","village","layout_fixed",2,-1868,-2036},
	{4,"village_1","village","layout_fixed",3,-2404,-1576},
	{7,"village_1","village","layout_fixed",1,-120,-2020},
	{9,"village_1","village","layout_fixed",3,-924,-1556},
	{12,"village_1","village","layout_fixed",1,1900,-2020},
	{14,"village_1","village","layout_fixed",3,876,-1556},
	{18,"village_1","village","layout_fixed",1,-1900,2020},
	{20,"village_1","village","layout_fixed",1,-2380,1600},
	{23,"village_1","village","layout_fixed",2,-88,2004},
	{25,"village_1","village","layout_fixed",2,-868,1564},
	{28,"village_1","village","layout_fixed",3,1876,2044},
	{30,"village_1","village","layout_fixed",3,876,1604},
	{2,"outpost_1","outpost","layout_fixed",1,-2100,-2100},
	{4,"outpost_1","outpost","layout_fixed",1,-2300,-1250},
	{5,"outpost_1","outpost","layout_fixed",3,-2074,-826},
	{5,"outpost_2","outpost","layout_fixed",1,-1500,-450},
	{7,"outpost_1","outpost","layout_fixed",3,176,-2026},
	{9,"outpost_1","outpost","layout_fixed",2,-618,-1266},
	{10,"outpost_1","outpost","layout_fixed",1,-350,-850},
	{10,"outpost_2","outpost","layout_fixed",1,300,-450},
	{12,"outpost_1","outpost","layout_fixed",1,2100,-2100},
	{14,"outpost_1","outpost","layout_fixed",3,626,-1226},
	{15,"outpost_1","outpost","layout_fixed",3,2376,-1326},
	{16,"outpost_1","outpost","layout_fixed",2,1932,-566},
	{18,"outpost_1","outpost","layout_fixed",1,-2100,2100},
	{20,"outpost_1","outpost","layout_fixed",2,-2268,1234},
	{21,"outpost_1","outpost","layout_fixed",2,-2018,834},
	{21,"outpost_2","outpost","layout_fixed",2,-1468,434},
	{23,"outpost_1","outpost","layout_fixed",3,176,2074},
	{25,"outpost_1","outpost","layout_fixed",1,-650,1250},
	{26,"outpost_1","outpost","layout_fixed",3,-374,874},
	{26,"outpost_2","outpost","layout_fixed",3,276,474},
	{28,"outpost_1","outpost","layout_fixed",2,2132,2084},
	{30,"outpost_1","outpost","layout_fixed",2,682,1234},
	{31,"outpost_1","outpost","layout_fixed",1,2400,1350},
	{32,"outpost_1","outpost","layout_fixed",1,1900,550},
	{2,"bandit_1","bandit_home","layout_fixed",2,-1568,-2066},
	{5,"bandit_1","bandit_frontier","layout_fixed",3,-1824,-406},
	{7,"bandit_1","bandit_home","layout_fixed",1,320,-1980},
	{10,"bandit_1","bandit_frontier","layout_fixed",3,-24,-406},
	{12,"bandit_1","bandit_home","layout_fixed",2,1632,-2066},
	{16,"bandit_1","bandit_frontier","layout_fixed",3,1776,-406},
	{18,"bandit_1","bandit_home","layout_fixed",1,-1600,2050},
	{21,"bandit_1","bandit_frontier","layout_fixed",1,-1800,430},
	{23,"bandit_1","bandit_home","layout_fixed",1,320,1980},
	{26,"bandit_1","bandit_frontier","layout_fixed",2,32,414},
	{28,"bandit_1","bandit_home","layout_fixed",2,1632,2034},
	{32,"bandit_1","bandit_frontier","layout_fixed",3,1776,454},
	{4,"mine","mine","layout_fixed",2,-2418,-1296},
	{9,"mine","mine","layout_fixed",3,-1074,-1256},
	{14,"mine","mine","layout_fixed",3,1026,-1256},
	{20,"mine","mine","layout_fixed",2,-2418,1264},
	{25,"mine","mine","layout_fixed",1,-1050,1280},
	{30,"mine","mine","layout_fixed",3,1026,1304},
	{9,"mirefolk","mirefolk","layout_fixed",1,-620,-1760},
	{14,"mirefolk","mirefolk","layout_fixed",3,1096,-1716},
	{18,"mirefolk","mirefolk","layout_fixed",3,-2074,2274},
	{30,"mirefolk","mirefolk","layout_fixed",3,1096,1764},
	{10,"clash_1","clash","layout_fixed",3,-274,-296},
	{10,"clash_2","clash","layout_fixed",1,250,-320},
	{26,"clash_1","clash","layout_fixed",2,-218,304},
	{26,"clash_2","clash","layout_fixed",2,282,304},
	{33,"clash_1","clash","layout_fixed",3,-3024,194},
	{34,"clash_1","clash","layout_fixed",1,-2200,-80},
	{34,"clash_2","clash","layout_fixed",2,-1768,64},
	{35,"clash_1","clash","layout_fixed",3,-1274,-76},
	{35,"clash_2","clash","layout_fixed",3,-774,124},
	{35,"clash_3","clash","layout_fixed",3,-274,-76},
	{36,"clash_1","clash","layout_fixed",1,250,100},
	{36,"clash_2","clash","layout_fixed",2,782,-116},
	{36,"clash_3","clash","layout_fixed",2,1282,84},
	{37,"clash_1","clash","layout_fixed",2,1832,-96},
	{37,"clash_2","clash","layout_fixed",3,2176,104},
	{38,"clash_1","clash","layout_fixed",1,3000,170},
	{33,"dragon","dragon","authored_fixed",0,-3260,-40},
	{38,"dragon","dragon","authored_fixed",0,3260,-40},
	{33,"apex_mine","apex_mine","authored_fixed",0,-3200,80},
	{38,"apex_mine","apex_mine","authored_fixed",0,3200,80},
	{7,"rare_grimtusk","rare_route","layout_fixed",2,152,-2116},
	{10,"rare_old_whitefang","rare_route","layout_fixed",1,-180,-650},
	{5,"rare_korgans_bane","rare_route","layout_fixed",3,-1874,-596},
	{37,"rare_silkfang","rare_route","layout_fixed",3,2026,94},
	{21,"rare_marrowclaw","rare_route","layout_fixed",2,-1818,604},
	{26,"rare_dustwing","rare_route","layout_fixed",3,156,674},
	{38,"rare_emerald_coil","rare_route","layout_fixed",1,3000,-120},
	{23,"rare_ashmaw","rare_route","layout_fixed",2,152,2084},
	{35,"rare_captain_bonerattle","rare_route","layout_fixed",2,-568,64},
	{36,"rare_captain_bonerattle","rare_route","layout_fixed",1,600,-80},
}

source.anchors = {}
for index = 1, #anchor_rows do
	local row = anchor_rows[index]
	local anchor = {numeric_id=index,id=("anchor_%03d"):format(index),
		zone_numeric_id=row[1],slot_id=row[2],template_id=row[3],
		placement_mode=row[4],approved_candidate_index=row[5],
		position=point(row[6],row[7])}
	source.anchors[index] = anchor
end
source.apex_sockets = {}
local socket_offsets = {
	{-80,-60},{-30,-80},{30,-80},{80,-60},{-90,0},{90,0},
	{-80,60},{-30,80},{30,80},{80,60},{-45,0},{45,0},
}
local gem_species = {"citrine","garnet","jade","diamond","sapphire","ruby"}
for _, anchor_index in ipairs({89,90}) do
	local anchor = source.anchors[anchor_index]
	for offset_index = 1, #socket_offsets do
		local offset = socket_offsets[offset_index]
		source.apex_sockets[#source.apex_sockets+1] = {
			id=anchor.id..(":socket_%02d"):format(offset_index),anchor_id=anchor.id,
			species=gem_species[math.floor((offset_index-1)/2)+1],
			offset=point(offset[1],offset[2]),
		}
	end
end

source.relief_profiles = {
	{id="wetland_delta",min_above_water=2,max_above_water=24,
		detail_amplitude=3,
		noise_domain="relief_wetland_delta",octaves={
			{period=512,amplitude=fraction(2,5)},
			{period=256,amplitude=fraction(3,5)}}},
	{id="lowland",min_above_water=8,max_above_water=56,
		detail_amplitude=9,
		noise_domain="relief_lowland",octaves={
			{period=768,amplitude=fraction(1,2)},
			{period=256,amplitude=fraction(1,2)}}},
	{id="rolling_hills",min_above_water=24,max_above_water=96,
		detail_amplitude=12,
		noise_domain="relief_rolling_hills",octaves={
			{period=768,amplitude=fraction(9,20)},
			{period=384,amplitude=fraction(11,20)}}},
	{id="plateau",min_above_water=56,max_above_water=144,
		detail_amplitude=10,
		noise_domain="relief_plateau",octaves={
			{period=1024,amplitude=fraction(11,20)},
			{period=384,amplitude=fraction(9,20)}}},
	{id="highland",min_above_water=96,max_above_water=224,
		detail_amplitude=12,
		noise_domain="relief_highland",octaves={
			{period=1024,amplitude=fraction(11,20)},
			{period=512,amplitude=fraction(9,20)}}},
	{id="mountain",min_above_water=160,max_above_water=360,
		detail_amplitude=16,
		noise_domain="relief_mountain",octaves={
			{period=1280,amplitude=fraction(9,20)},
			{period=640,amplitude=fraction(7,20)},
			{period=320,amplitude=fraction(1,5)}}},
}

source.logical_biome_selector = {
	id="zone_palette_jittered_voronoi_t1_hash_v1",schema_version=1,
	coordinate_space="world_xz_integer_columns",
	seed_input="t1_canonical_unsigned_u64_decimal_text",
	hash_api="deterministic.new_hash",
	hash_schema="grug_wp40_geometry_source_v1",
	hash_domain="logical_biome_patch_v1",hash_feature_id="",
	hash_coordinates="signed_cell_x_z",hash_candidate_index=0,
	hash_lanes={site_x=0,site_z=1,palette=2},cell_size=192,
	cell_index_rule="mathematical_floor_coordinate_div_cell_size",
	candidate_neighborhood="own_and_eight_adjacent_cells",
	site_offset_min=32,site_offset_span=128,
	site_offset_rule="min_plus_t1_unbiased_range_lane",
	distance_rule="squared_euclidean_integer_world_xz",
	nearest_tie_rule="lowest_cell_x_then_lowest_cell_z",
	palette_roll_rule="t1_unbiased_range_lane_size_100",
	palette_mapping_rule=
		"first_authored_cumulative_share_strictly_greater_than_roll",
	ownership_rule="resolve_zone_first_and_use_only_owning_zone_palette",
	arithmetic_rule="t1_safe_integer_and_floor_division",
	share_audit_domain="ordinary_land_columns_after_fixed_roads_and_structures",
	share_audit_tolerance_percentage_points=5,
}

source.anchor_profiles = {
	{id="start",shape="flat",fitting_width=128,blend_width=256,max_cut=8,max_fill=8,force_native_dungeon=false},
	{id="capital_dwarf",shape="granite_terrace",fitting_width=512,blend_width=704,civic_width=96,terrace_step=4,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_human",shape="river_plateau",fitting_width=512,blend_width=704,civic_width=96,terrace_step=2,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_elf",shape="terraced_grove",fitting_width=512,blend_width=704,civic_width=96,terrace_step=3,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_undead",shape="raised_necropolis",fitting_width=512,blend_width=704,civic_width=96,terrace_step=3,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_orc",shape="mesa_shelf",fitting_width=512,blend_width=704,civic_width=96,terrace_step=4,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_troll",shape="cenote_terrace",fitting_width=512,blend_width=704,civic_width=96,terrace_step=3,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="village",shape="gentle_grade",building_core_width=24,fitting_width=96,blend_width=160,force_native_dungeon=false},
	{id="outpost",shape="gentle_grade",building_core_width=16,fitting_width=64,blend_width=112,force_native_dungeon=false},
	{id="bandit_home",shape="gentle_grade",building_core_width=24,fitting_width=64,blend_width=112,force_native_dungeon=false},
	{id="bandit_frontier",shape="gentle_grade",building_core_width=16,fitting_width=64,blend_width=112,force_native_dungeon=false},
	{id="mine",shape="gentle_grade",building_core_width=20,fitting_width=80,blend_width=128,force_native_dungeon=false},
	{id="mirefolk",shape="shallow_marsh_island",building_core_width=16,fitting_width=64,blend_width=112,force_native_dungeon=false},
	{id="clash",shape="battlefield_grade",building_core_width=16,fitting_width=64,blend_width=112,force_native_dungeon=false},
	{id="dragon",shape="arena_terrace",building_core_width=32,fitting_width=96,blend_width=160,force_native_dungeon=false},
	{id="apex_mine",shape="mine_terrace",building_core_width=32,fitting_width=96,blend_width=160,force_native_dungeon=false},
	{id="rare_route",shape="patrol_route",building_core_width=12,fitting_width=32,blend_width=64,force_native_dungeon=false},
}
source.hard_protection_recipes = {
	{id="hard_capital_build_plus_apron_v1",shape="centered_half_open_square",footprint_policy_id="centered_half_open_square_v1",total_width=532,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
	{id="hard_start_core_v1",shape="centered_half_open_square",footprint_policy_id="centered_half_open_square_v1",total_width=148,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
	{id="hard_apex_socket_column_v1",shape="exact_column",footprint_policy_id="exact_column_v1",column_count=1,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
}

source.hard_protection = {}
for anchor_index = 1, 12 do
	local anchor = source.anchors[anchor_index]
	source.hard_protection[#source.hard_protection+1] = {
		id="hard:"..anchor.id,source_anchor_id=anchor.id,
		recipe_id=anchor.slot_id == "capital" and
			"hard_capital_build_plus_apron_v1" or "hard_start_core_v1",
		center=point(anchor.position.x,anchor.position.z),active=true,
		activation_owner="WP40",status="active",
	}
end
local anchor_by_id = {}
for anchor_index = 1, #source.anchors do
	anchor_by_id[source.anchors[anchor_index].id] = source.anchors[anchor_index]
end
for socket_index = 1, #source.apex_sockets do
	local socket = source.apex_sockets[socket_index]
	local anchor = anchor_by_id[socket.anchor_id]
	source.hard_protection[#source.hard_protection+1] = {
		id="hard:"..socket.id,source_anchor_id=anchor.id,
		socket_id=socket.id,resource_key=socket.species,
		recipe_id="hard_apex_socket_column_v1",
		center=point(anchor.position.x+socket.offset.x,
			anchor.position.z+socket.offset.z),active=true,
		activation_owner="WP40",status="active",
	}
end

source.claim_exclusion_recipes = {
	{id="exclude_anchor_blend_v1",kind="anchor_blend_envelope",footprint_policy_id="centered_half_open_square_v1"},
	{id="exclude_route_corridor_v1",kind="route_corridor",footprint_policy_id="route_class_corridor_v1"},
	{id="exclude_planned_water_v1",kind="planned_water",footprint_policy_id="analytic_water_mask_v1"},
	{id="exclude_coast_v1",kind="coast",footprint_policy_id="analytic_coast_mask_v1"},
	{id="exclude_active_core_v1",kind="active_core",footprint_policy_id="active_hard_footprint_v1"},
}

local profile_by_id = {}
for profile_index = 1, #source.anchor_profiles do
	local profile = source.anchor_profiles[profile_index]
	profile_by_id[profile.id] = profile
end
source.claim_exclusions = {}
local function add_exclusion(row)
	source.claim_exclusions[#source.claim_exclusions+1] = row
end
for anchor_index = 1, #source.anchors do
	local anchor = source.anchors[anchor_index]
	local profile = profile_by_id[anchor.template_id]
	local identity_index = anchor.placement_mode == "authored_fixed" and 1 or
		anchor.approved_candidate_index
	add_exclusion({
		id=("exclude:anchor:%s:%02d"):format(anchor.id,identity_index),
		recipe_id="exclude_anchor_blend_v1",source_id=anchor.id,
		center=point(anchor.position.x,anchor.position.z),
		total_width=profile.blend_width,
		coverage="complete_fitting_plus_blend_envelope",
	})
end
for bay_index = 1, #source.bays do
	local bay = source.bays[bay_index]
	add_exclusion({id="exclude:water:"..bay.id,
		recipe_id="exclude_planned_water_v1",source_id=bay.id,
		coverage="complete_analytic_mask"})
end
for _, collection in ipairs({source.islands,source.channels}) do
	for record_index = 1, #collection do
		local record = collection[record_index]
		add_exclusion({id="exclude:coast:"..record.id,
			recipe_id="exclude_coast_v1",source_id=record.id,
			projection_width=source.shelf_width,
			coverage="coast_water_and_projection"})
	end
end
for hard_index = 1, #source.hard_protection do
	local hard = source.hard_protection[hard_index]
	add_exclusion({id="exclude:active:"..hard.id,
		recipe_id="exclude_active_core_v1",source_id=hard.id,
		coverage="exact_active_hard_footprint"})
end

source.region_resources = {
	{race_region="dwarf",g1="garnet",g2="sapphire",cultural="runeslate",signature_wood="mountain_pine"},
	{race_region="human",g1="citrine",g2="diamond",cultural="sunwax",signature_wood="oak"},
	{race_region="elf",g1="jade",g2="sapphire",cultural="moonresin",signature_wood="silverwood"},
	{race_region="undead",g1="citrine",g2="ruby",cultural="gravesalt",signature_wood="gravewood"},
	{race_region="orc",g1="garnet",g2="diamond",cultural="red_ochre",signature_wood="spikethorn_acacia"},
	{race_region="troll",g1="jade",g2="ruby",cultural="spirit_resin",signature_wood="kapok"},
}

return source
