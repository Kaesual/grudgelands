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
	schema = "grug_wp40_simple_map_source_v1",
	layout_id = "wp40-simple-map-v1d",
	extent = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200},
	warp = {cell = 256, maximum = 60,
		hash_domain = "fixed_visual_warp_v1"},
	mainland_partition = {axis = "warped_z", split = 0,
		negative_region = "elandor_mainland",
		nonnegative_region = "kragmar_mainland"},
	shelf_width = 80,
	holy_grounds = {min_x = -2500, max_x = 2500, min_z = -250, max_z = 250},
	start_core = {width_x = 600, width_z = 500},
	capital_core = {width_x = 512, width_z = 512},
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
		poi_bias_scope = "all_authored_anchor_positions_and_candidates",
		greedy_orders = {
			"minimum_conflict_degree", "maximum_conflict_degree",
			"edge_biased", "route_biased", "poi_biased",
			"row_major", "reverse_row_major",
		},
	},
}

local function zone(numeric_id, id, display_name, race_region, faction,
		territory_rule, pvp_rule, level_min, level_max, relief_id,
		difficulty_target, hub_x, hub_z, biomes, civic)
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
		difficulty_target = difficulty_target,
		hub = point(hub_x, hub_z),
		macro_region = macro_region,
		bias = 0,
		biomes = biomes,
		civic_no_hostiles = civic or false,
	}
end

source.zones = {
	zone(1,"elandor_hearthpine_vale","Hearthpine Vale","dwarf","accord","accord_home","peaceful",1,10,"lowland",5,-1800,-2550,{"grug_pine_hills","grug_crags"}),
	zone(2,"elandor_copperfell_foothills","Copperfell Foothills","dwarf","accord","accord_home","peaceful",11,20,"rolling_hills",15,-1800,-2050,{"grug_pine_hills","grug_crags"}),
	zone(3,"elandor_dur_brannoc","Dur Brannoc","dwarf","accord","accord_home","peaceful",20,30,"plateau",25,-1800,-1500,{"grug_pine_hills","grug_crags"},true),
	zone(4,"elandor_frostbarrow_shelf","Frostbarrow Shelf","dwarf","accord","accord_home","peaceful",21,30,"plateau",25,-2400,-1500,{"grug_pine_hills","grug_crags","grug_swamp"}),
	zone(5,"elandor_stormvault_heights","Stormvault Heights","dwarf",false,"contested_land","contested",31,40,"highland",35,-1800,-700,{"grug_crags","grug_crags_snowy"}),
	zone(6,"elandor_dawnmere_fields","Dawnmere Fields","human","accord","accord_home","peaceful",1,10,"lowland",5,0,-2550,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(7,"elandor_goldmead_vale","Goldmead Vale","human","accord","accord_home","peaceful",11,20,"lowland",15,0,-2050,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(8,"elandor_highcourt","Highcourt","human","accord","accord_home","peaceful",20,30,"rolling_hills",25,0,-1500,{"grug_meadows","grug_deep_forest"},true),
	zone(9,"elandor_whitebridge_shire","Whitebridge Shire","human","accord","accord_home","peaceful",21,30,"lowland",25,-900,-1500,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(10,"elandor_ashenward_march","Ashenward March","human",false,"contested_land","contested",31,40,"rolling_hills",35,0,-700,{"grug_deep_forest","grug_meadows","grug_swamp"}),
	zone(11,"elandor_silverleaf_glades","Silverleaf Glades","elf","accord","accord_home","peaceful",1,10,"lowland",5,1800,-2550,{"grug_elf_forest","grug_deep_forest"}),
	zone(12,"elandor_starbough_vale","Starbough Vale","elf","accord","accord_home","peaceful",11,20,"rolling_hills",15,1800,-2050,{"grug_elf_forest","grug_deep_forest"}),
	zone(13,"elandor_lethariel","Lethariel","elf","accord","accord_home","peaceful",20,30,"rolling_hills",25,1800,-1500,{"grug_elf_forest","grug_deep_forest"},true),
	zone(14,"elandor_lorindor","Lorindor","elf","accord","accord_home","peaceful",21,30,"rolling_hills",25,900,-1500,{"grug_elf_forest","grug_deep_forest","grug_swamp"}),
	zone(15,"elandor_moonfall_wood","Moonfall Wood","elf","accord","accord_home","peaceful",21,30,"lowland",25,2400,-1500,{"grug_elf_forest","grug_deep_forest","grug_swamp"}),
	zone(16,"elandor_glassroot_wilds","Glassroot Wilds","elf",false,"contested_land","contested",31,40,"highland",35,1800,-700,{"grug_deep_forest","grug_jungle_fringe","grug_elf_forest","grug_swamp"}),
	zone(17,"kragmar_stillgrave_hollow","Stillgrave Hollow","undead","throng","throng_home","peaceful",1,10,"lowland",5,-1800,2550,{"grug_blight","grug_bone_forest","grug_swamp"}),
	zone(18,"kragmar_mournfen","Mournfen","undead","throng","throng_home","peaceful",11,20,"wetland_delta",15,-1800,2050,{"grug_blight","grug_bone_forest","grug_swamp"}),
	zone(19,"kragmar_nhal_veyr","Nhal Veyr","undead","throng","throng_home","peaceful",20,30,"plateau",25,-1800,1500,{"grug_blight","grug_bone_forest"},true),
	zone(20,"kragmar_ossuary_reach","Ossuary Reach","undead","throng","throng_home","peaceful",21,30,"rolling_hills",25,-2400,1500,{"grug_blight","grug_bone_forest","grug_swamp"}),
	zone(21,"kragmar_blackwind_rise","Blackwind Rise","undead",false,"contested_land","contested",31,40,"highland",35,-1800,700,{"grug_bone_forest","grug_blight","grug_swamp"}),
	zone(22,"kragmar_sunscar_flats","Sunscar Flats","orc","throng","throng_home","peaceful",1,10,"lowland",5,0,2550,{"grug_savanna","grug_badlands"}),
	zone(23,"kragmar_redtusk_savanna","Redtusk Savanna","orc","throng","throng_home","peaceful",11,20,"rolling_hills",15,0,2050,{"grug_savanna","grug_badlands"}),
	zone(24,"kragmar_gor_drazhak","Gor Drazhak","orc","throng","throng_home","peaceful",20,30,"plateau",25,0,1500,{"grug_savanna","grug_badlands"},true),
	zone(25,"kragmar_speargrass_reach","Speargrass Reach","orc","throng","throng_home","peaceful",21,30,"rolling_hills",25,-900,1500,{"grug_savanna","grug_badlands","grug_swamp"}),
	zone(26,"kragmar_bannerbreak_mesa","Bannerbreak Mesa","orc",false,"contested_land","contested",31,40,"plateau",35,0,700,{"grug_badlands","grug_savanna","grug_swamp"}),
	zone(27,"kragmar_kapok_cradle","Kapok Cradle","troll","throng","throng_home","peaceful",1,10,"lowland",5,1800,2550,{"grug_jungle_edge","grug_swamp"}),
	zone(28,"kragmar_raincall_basin","Raincall Basin","troll","throng","throng_home","peaceful",11,20,"rolling_hills",15,1800,2050,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"}),
	zone(29,"kragmar_kezamba","Kezamba","troll","throng","throng_home","peaceful",20,30,"plateau",25,1800,1500,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"},true),
	zone(30,"kragmar_whispering_reedlands","Whispering Reedlands","troll","throng","throng_home","peaceful",21,30,"wetland_delta",25,900,1500,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"}),
	zone(31,"kragmar_totemwater_reach","Totemwater Reach","troll","throng","throng_home","peaceful",21,30,"wetland_delta",25,2400,1500,{"grug_jungle_edge","grug_deep_jungle","grug_swamp"}),
	zone(32,"kragmar_thunderroot_wilds","Thunderroot Wilds","troll",false,"contested_land","contested",31,40,"highland",35,1800,700,{"grug_deep_jungle","grug_badlands_east","grug_swamp"}),
	zone(33,"front_wyrmglass_crown","The Wyrmglass Crown","dwarf",false,"contested_land","contested",60,60,"mountain",60,-3150,0,{"grug_crags","grug_crags_snowy","grug_beach"}),
	zone(34,"front_gravesalt_escarpment","Gravesalt Escarpment","undead",false,"holy_grounds","contested",51,59,"highland",55,-2000,0,{"grug_bone_forest","grug_blight","grug_swamp","grug_beach"}),
	zone(35,"front_broken_causeway","The Broken Causeway","human",false,"holy_grounds","contested",31,40,"wetland_delta",35,-750,0,{"grug_meadows","grug_deep_forest","grug_swamp"}),
	zone(36,"front_shattered_line","The Shattered Line","orc",false,"holy_grounds","contested",41,50,"plateau",45,750,0,{"grug_badlands","grug_savanna","grug_swamp"}),
	zone(37,"front_skyglass_canopy","The Skyglass Canopy","elf",false,"holy_grounds","contested",51,59,"highland",55,2000,0,{"grug_jungle_fringe","grug_deep_forest","grug_elf_forest"}),
	zone(38,"front_stormscale_summit","Stormscale Summit","troll",false,"contested_land","contested",60,60,"mountain",60,3150,0,{"grug_deep_jungle","grug_badlands_east","grug_swamp","grug_beach"}),
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

source.route_profiles = {
	primary = {surface_width=7,corridor_width=16},
	secondary = {surface_width=5,corridor_width=12},
	trail = {surface_width=3,corridor_width=8},
}
source.route_curve = {
	id="bounded_pinned_curve_v1",points_per_leg=3,minimum_points_per_route=7,
	amplitude_by_class={primary=48,secondary=64,trail=80},
}

local route_rows = {
	{1,2,"primary",-1975,-2175},{2,3,"primary",-1800,-1900},{3,5,"primary",-1800,-1100},{6,7,"primary",-175,-2145},{7,8,"primary",0,-1900},{8,10,"primary",0,-1100},{11,12,"primary",1975,-2190},{12,13,"primary",1800,-1900},{13,16,"primary",1800,-1100},
	{17,18,"primary",-1980,2175},{18,19,"primary",-1800,1900},{19,21,"primary",-1800,1100},{22,23,"primary",-180,2155},{23,24,"primary",0,1900},{24,26,"primary",0,1100},{27,28,"primary",1980,2175},{28,29,"primary",1800,1900},{29,32,"primary",1800,1100},
	{4,3,"primary",-2200,-1500},{3,9,"primary",-1400,-1500},{9,8,"primary",-400,-1500},{8,14,"primary",400,-1500},{14,13,"primary",1400,-1500},{13,15,"primary",2200,-1500},{20,19,"primary",-2200,1500},{19,25,"primary",-1400,1500},{25,24,"primary",-400,1500},{24,30,"primary",400,1500},{30,29,"primary",1400,1500},{29,31,"primary",2200,1500},
	{4,5,"secondary",-2400,-1100},{9,10,"secondary",-900,-1100},{14,16,"secondary",900,-1100},{15,16,"secondary",2400,-1100},{5,10,"secondary",-1150,-1000},{10,16,"secondary",650,-1000},{20,21,"secondary",-2400,1100},{25,26,"secondary",-900,1100},{30,32,"secondary",900,1100},{31,32,"secondary",2400,1100},{21,26,"secondary",-1150,1000},{26,32,"secondary",650,1000},
	{5,34,"secondary",-2000,-250},{5,35,"secondary",-1125,-250},{10,35,"secondary",-375,-250},{10,36,"secondary",375,-250},{16,36,"secondary",1125,-250},{16,37,"secondary",2000,-250},{21,34,"secondary",-2000,250},{21,35,"secondary",-1125,250},{26,35,"secondary",-375,250},{26,36,"secondary",375,250},{32,36,"secondary",1125,250},{32,37,"secondary",2000,250},
	{34,35,"trail",-1500,-125},{35,36,"trail",0,-125},{36,37,"trail",1500,-125},
}

source.route_stations = {}
for index = 1, #source.zones do
	local row = source.zones[index]
	source.route_stations[index] = {id="station:"..row.id..":hub",
		zone_numeric_id=index,kind="hub",position=point(row.hub.x,row.hub.z)}
end

source.routes = {}
local function round_div(numerator,denominator)
	if numerator < 0 then
		return -math.floor((-numerator+math.floor(denominator/2))/denominator)
	end
	return math.floor((numerator+math.floor(denominator/2))/denominator)
end
local function append_bowed_leg(result,a,b,amplitude,sign,include_start)
	local dx,dz=b.x-a.x,b.z-a.z
	local scale=math.max(math.abs(dx),math.abs(dz))
	assert(scale > 0,"WP40 route curve has coincident pins")
	local bounded_amplitude=math.min(amplitude,math.floor(scale/4))
	if include_start then result[#result+1]=point(a.x,a.z) end
	for step=1,2 do
		local x=round_div(a.x*(3-step)+b.x*step,3)
		local z=round_div(a.z*(3-step)+b.z*step,3)
		local offset_x=round_div(-dz*bounded_amplitude*sign,scale)
		local offset_z=round_div(dx*bounded_amplitude*sign,scale)
		result[#result+1]=point(x+offset_x,z+offset_z)
	end
	result[#result+1]=point(b.x,b.z)
end
local route_extra_pins_by_index={
	[43]={point(-2000,-100)},
	[48]={point(2000,-100)},
}
local function curved_route(a,via,b,class,index)
	local result={}
	local amplitude=source.route_curve.amplitude_by_class[class]
	local pins={a,via}
	local extras=route_extra_pins_by_index[index] or {}
	for extra_index=1,#extras do pins[#pins+1]=extras[extra_index] end
	pins[#pins+1]=b
	for leg=1,#pins-1 do
		local sign=((index*37+leg*17)%11)<5 and -1 or 1
		append_bowed_leg(result,pins[leg],pins[leg+1],amplitude,sign,leg==1)
	end
	return result
end
for index = 1, #route_rows do
	local row = route_rows[index]
	local a, b = source.zones[row[1]], source.zones[row[2]]
	local profile = source.route_profiles[row[3]]
	local via=point(row[4],row[5])
	source.routes[index] = {
		numeric_id=index,id=("route_%03d"):format(index),zone_a=row[1],zone_b=row[2],
		class=row[3],kind=row[3] == "trail" and "trail" or "road",
		surface_width=profile.surface_width,
		corridor_width=profile.corridor_width,provisional=false,
		curve_policy_id=source.route_curve.id,pinned_point_index=4,
		station_a_id=source.route_stations[row[1]].id,
		station_b_id=source.route_stations[row[2]].id,
		centreline=curved_route(a.hub,via,b.hub,row[3],index),
	}
end

source.crossing_interfaces = {
	{id="whitebridge_bridge",route_id="route_021",kind="bridge",position=point(-400,-1500)},
	{id="whitebridge_ford",route_id="route_032",kind="ford",position=point(-900,-1100)},
	{id="broken_causeway",route_id="route_045",kind="causeway",position=point(-375,-250)},
	{id="broken_ford",route_id="route_050",kind="ford",position=point(-1125,250)},
	{id="broken_aqueduct",route_id="route_055",kind="bridge",position=point(-1500,-125)},
	{id="gravesalt_tomb_tunnel",route_id="route_043",kind="tunnel",position=point(-2000,-100)},
	{id="skyglass_cliff_tunnel",route_id="route_048",kind="tunnel",position=point(2000,-100)},
	{id="gravesalt_causeway_south",route_id="route_043",kind="causeway",position=point(-2000,0)},
	{id="gravesalt_causeway_north",route_id="route_049",kind="causeway",position=point(-2000,0)},
}
local crossing_authorization_half_extent = {
	whitebridge_bridge=96,whitebridge_ford=96,broken_causeway=96,
	broken_ford=96,broken_aqueduct=96,gravesalt_causeway_south=96,
	gravesalt_causeway_north=96,
}
for crossing_index=1,#source.crossing_interfaces do
	local crossing=source.crossing_interfaces[crossing_index]
	local half=crossing_authorization_half_extent[crossing.id]
	if half then
		local x,z=crossing.position.x,crossing.position.z
		crossing.authorization_polygon=polygon(point(x-half,z-half),
			point(x+half,z-half),point(x+half,z+half),point(x-half,z+half))
	end
end

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

source.island_routes = {
	{id="island_route_wyrmglass_south_junction",kind="road",centreline={point(-2890,-125),point(-2990,-90),point(-3100,0)}},
	{id="island_route_wyrmglass_north_junction",kind="road",centreline={point(-2890,125),point(-2990,90),point(-3100,0)}},
	{id="island_route_wyrmglass_junction_dragon",kind="road",centreline={point(-3100,0),point(-3180,-10),point(-3260,-40)}},
	{id="island_route_wyrmglass_junction_apex",kind="road",centreline={point(-3100,0),point(-3140,50),point(-3200,80)}},
	{id="island_route_stormscale_south_junction",kind="road",centreline={point(2890,-125),point(2990,-90),point(3100,0)}},
	{id="island_route_stormscale_north_junction",kind="road",centreline={point(2920,125),point(2990,90),point(3100,0)}},
	{id="island_route_stormscale_junction_dragon",kind="road",centreline={point(3100,0),point(3180,-10),point(3260,-40)}},
	{id="island_route_stormscale_junction_apex",kind="road",centreline={point(3100,0),point(3140,50),point(3200,80)}},
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

source.coastal_housing_cores = {
	{id="coastal_core_copperfell",shape="vertical_capsule_v1",zone_numeric_id=2,housing_mask_id="housing_elandor_copperfell",landmark_id="copperfell_coastal_terraces",frontage_min=600,inland_depth_min=300,relief_max=12},
	{id="coastal_core_starbough",shape="vertical_capsule_v1",zone_numeric_id=12,housing_mask_id="housing_elandor_starbough",landmark_id="starbough_coastal_gardens",frontage_min=600,inland_depth_min=300,relief_max=12},
	{id="coastal_core_mournfen",shape="vertical_capsule_v1",zone_numeric_id=18,housing_mask_id="housing_kragmar_mournfen",landmark_id="mournfen_dryward",frontage_min=600,inland_depth_min=300,relief_max=12},
	{id="coastal_core_raincall",shape="vertical_capsule_v1",zone_numeric_id=28,housing_mask_id="housing_kragmar_raincall",landmark_id="raincall_coastal_steps",frontage_min=600,inland_depth_min=300,relief_max=12},
}

local anchor_rows = {
	{1,"start","start","fixed",-1800,-2550},{6,"start","start","fixed",0,-2550},{11,"start","start","fixed",1800,-2550},{17,"start","start","fixed",-1800,2550},{22,"start","start","fixed",0,2550},{27,"start","start","fixed",1800,2550},
	{3,"capital","capital_dwarf","fixed",-1800,-1500},{8,"capital","capital_human","fixed",0,-1500},{13,"capital","capital_elf","fixed",1800,-1500},{19,"capital","capital_undead","fixed",-1800,1500},{24,"capital","capital_orc","fixed",0,1500},{29,"capital","capital_troll","fixed",1800,1500},
	{2,"village_1","village","candidate_set",-1900,-2020},{4,"village_1","village","candidate_set",-2380,-1600},{7,"village_1","village","candidate_set",-120,-2020},{9,"village_1","village","candidate_set",-900,-1580},{12,"village_1","village","candidate_set",1900,-2020},{14,"village_1","village","candidate_set",900,-1580},{18,"village_1","village","candidate_set",-1900,2020},{20,"village_1","village","candidate_set",-2380,1600},{23,"village_1","village","candidate_set",-120,2020},{25,"village_1","village","candidate_set",-900,1580},{28,"village_1","village","candidate_set",1900,2020},{30,"village_1","village","candidate_set",900,1580},
	{2,"outpost_1","outpost","candidate_set",-2100,-2100},{4,"outpost_1","outpost","candidate_set",-2300,-1250},{5,"outpost_1","outpost","candidate_set",-2050,-850},{5,"outpost_2","outpost","candidate_set",-1500,-450},{7,"outpost_1","outpost","candidate_set",200,-2050},{9,"outpost_1","outpost","candidate_set",-650,-1250},{10,"outpost_1","outpost","candidate_set",-350,-850},{10,"outpost_2","outpost","candidate_set",300,-450},{12,"outpost_1","outpost","candidate_set",2100,-2100},{14,"outpost_1","outpost","candidate_set",650,-1250},{15,"outpost_1","outpost","candidate_set",2400,-1350},{16,"outpost_1","outpost","candidate_set",1900,-550},
	{18,"outpost_1","outpost","candidate_set",-2100,2100},{20,"outpost_1","outpost","candidate_set",-2300,1250},{21,"outpost_1","outpost","candidate_set",-2050,850},{21,"outpost_2","outpost","candidate_set",-1500,450},{23,"outpost_1","outpost","candidate_set",200,2050},{25,"outpost_1","outpost","candidate_set",-650,1250},{26,"outpost_1","outpost","candidate_set",-350,850},{26,"outpost_2","outpost","candidate_set",300,450},{28,"outpost_1","outpost","candidate_set",2100,2100},{30,"outpost_1","outpost","candidate_set",650,1250},{31,"outpost_1","outpost","candidate_set",2400,1350},{32,"outpost_1","outpost","candidate_set",1900,550},
	{2,"bandit_1","bandit_home","candidate_set",-1600,-2050},{5,"bandit_1","bandit_frontier","candidate_set",-1800,-430},{7,"bandit_1","bandit_home","candidate_set",320,-1980},{10,"bandit_1","bandit_frontier","candidate_set",0,-430},{12,"bandit_1","bandit_home","candidate_set",1600,-2050},{16,"bandit_1","bandit_frontier","candidate_set",1800,-430},{18,"bandit_1","bandit_home","candidate_set",-1600,2050},{21,"bandit_1","bandit_frontier","candidate_set",-1800,430},{23,"bandit_1","bandit_home","candidate_set",320,1980},{26,"bandit_1","bandit_frontier","candidate_set",0,430},{28,"bandit_1","bandit_home","candidate_set",1600,2050},{32,"bandit_1","bandit_frontier","candidate_set",1800,430},
	{4,"mine","mine","candidate_set",-2450,-1280},{9,"mine","mine","candidate_set",-1050,-1280},{14,"mine","mine","candidate_set",1050,-1280},{20,"mine","mine","candidate_set",-2450,1280},{25,"mine","mine","candidate_set",-1050,1280},{30,"mine","mine","candidate_set",1050,1280},
	{9,"mirefolk","mirefolk","candidate_set",-620,-1760},{14,"mirefolk","mirefolk","candidate_set",1120,-1740},{18,"mirefolk","mirefolk","candidate_set",-2050,2250},{30,"mirefolk","mirefolk","candidate_set",1120,1740},
	{10,"clash_1","clash","candidate_set",-250,-320},{10,"clash_2","clash","candidate_set",250,-320},{26,"clash_1","clash","candidate_set",-250,320},{26,"clash_2","clash","candidate_set",250,320},{33,"clash_1","clash","candidate_set",-3000,170},{34,"clash_1","clash","candidate_set",-2200,-80},{34,"clash_2","clash","candidate_set",-1800,80},{35,"clash_1","clash","candidate_set",-1250,-100},{35,"clash_2","clash","candidate_set",-750,100},{35,"clash_3","clash","candidate_set",-250,-100},{36,"clash_1","clash","candidate_set",250,100},{36,"clash_2","clash","candidate_set",750,-100},{36,"clash_3","clash","candidate_set",1250,100},{37,"clash_1","clash","candidate_set",1800,-80},{37,"clash_2","clash","candidate_set",2200,80},{38,"clash_1","clash","candidate_set",3000,170},
	{33,"dragon","dragon","fixed",-3260,-40},{38,"dragon","dragon","fixed",3260,-40},{33,"apex_mine","apex_mine","fixed",-3200,80},{38,"apex_mine","apex_mine","fixed",3200,80},
	{7,"rare_grimtusk","rare_route","candidate_set",120,-2100},{10,"rare_old_whitefang","rare_route","candidate_set",-180,-650},{5,"rare_korgans_bane","rare_route","candidate_set",-1850,-620},{37,"rare_silkfang","rare_route","candidate_set",2050,70},{21,"rare_marrowclaw","rare_route","candidate_set",-1850,620},{26,"rare_dustwing","rare_route","candidate_set",180,650},{38,"rare_emerald_coil","rare_route","candidate_set",3000,-120},{23,"rare_ashmaw","rare_route","candidate_set",120,2100},{35,"rare_captain_bonerattle","rare_route","candidate_set",-600,80},{36,"rare_captain_bonerattle","rare_route","candidate_set",600,-80},
}

source.anchors = {}
for index = 1, #anchor_rows do
	local row = anchor_rows[index]
	local anchor = {numeric_id=index,id=("anchor_%03d"):format(index),
		zone_numeric_id=row[1],slot_id=row[2],template_id=row[3],
		placement_mode=row[4]}
	if row[4] == "fixed" then
		anchor.position = point(row[5], row[6])
	else
		anchor.candidates = {point(row[5],row[6]),point(row[5]+32,row[6]-16),
			point(row[5]-24,row[6]+24)}
	end
	source.anchors[index] = anchor
end

source.poi_spurs = {}
for index = 13, 86 do
	local anchor = source.anchors[index]
	local hub = source.zones[anchor.zone_numeric_id].hub
	local paths = {}
	for candidate_index = 1, #anchor.candidates do
		local candidate = anchor.candidates[candidate_index]
		paths[candidate_index] = {point(candidate.x,candidate.z),
			point(hub.x,hub.z)}
	end
	source.poi_spurs[#source.poi_spurs+1] = {
		id=("poi_spur_%03d"):format(index),anchor_id=anchor.id,
		candidate_paths=paths,
	}
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
		noise_domain="relief_wetland_delta",octaves={
			{period=512,amplitude=fraction(3,5)},
			{period=256,amplitude=fraction(2,5)}}},
	{id="lowland",min_above_water=8,max_above_water=56,
		noise_domain="relief_lowland",octaves={
			{period=768,amplitude=fraction(2,3)},
			{period=256,amplitude=fraction(1,3)}}},
	{id="rolling_hills",min_above_water=24,max_above_water=96,
		noise_domain="relief_rolling_hills",octaves={
			{period=768,amplitude=fraction(3,5)},
			{period=384,amplitude=fraction(2,5)}}},
	{id="plateau",min_above_water=56,max_above_water=144,
		noise_domain="relief_plateau",octaves={
			{period=1024,amplitude=fraction(3,4)},
			{period=384,amplitude=fraction(1,4)}}},
	{id="highland",min_above_water=96,max_above_water=224,
		noise_domain="relief_highland",octaves={
			{period=1024,amplitude=fraction(2,3)},
			{period=512,amplitude=fraction(1,3)}}},
	{id="mountain",min_above_water=160,max_above_water=360,
		noise_domain="relief_mountain",octaves={
			{period=1280,amplitude=fraction(3,5)},
			{period=640,amplitude=fraction(3,10)},
			{period=320,amplitude=fraction(1,10)}}},
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
	{id="capital_dwarf",shape="granite_terrace",fitting_width=512,blend_width=704,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_human",shape="river_plateau",fitting_width=512,blend_width=704,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_elf",shape="terraced_grove",fitting_width=512,blend_width=704,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_undead",shape="raised_necropolis",fitting_width=512,blend_width=704,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_orc",shape="mesa_shelf",fitting_width=512,blend_width=704,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="capital_troll",shape="cenote_terrace",fitting_width=512,blend_width=704,max_cut=24,max_fill=16,force_native_dungeon=false},
	{id="village",shape="gentle_grade",fitting_width=96,blend_width=160,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="outpost",shape="gentle_grade",fitting_width=64,blend_width=112,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="bandit_home",shape="gentle_grade",fitting_width=64,blend_width=112,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="bandit_frontier",shape="gentle_grade",fitting_width=64,blend_width=112,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="mine",shape="gentle_grade",fitting_width=80,blend_width=128,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="mirefolk",shape="shallow_marsh_island",fitting_width=64,blend_width=112,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="clash",shape="battlefield_grade",fitting_width=64,blend_width=112,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="dragon",shape="arena_terrace",fitting_width=96,blend_width=160,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="apex_mine",shape="mine_terrace",fitting_width=96,blend_width=160,max_cut=8,max_fill=6,force_native_dungeon=false},
	{id="rare_route",shape="patrol_route",fitting_width=32,blend_width=64,max_cut=3,max_fill=2,force_native_dungeon=false},
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
	ashenward_trenchbelt=true,glassroot_rootways=true,
	mournfen_drowned_roads=true,blackwind_bonearches=true,
	redtusk_gullies=true,speargrass_dryriver=true,
	bannerbreak_siegeramps=true,whispering_totemways=true,
	thunderroot_exposures=true,wyrmglass_ring=true,gravesalt_whitewall=true,
	gravesalt_tombways=true,gravesalt_warcoast=true,broken_threeways=true,
	shattered_breachwall=true,shattered_siegeramp=true,
	skyglass_escarpment=true,skyglass_hangingways=true,
	skyglass_warcoast=true,stormscale_caldera=true,
}
local target_landmarks = {
	copperfell_coastal_terraces=true,dur_brannoc_granite_terrace=true,
	dur_brannoc_forge_chasm=true,starbough_coastal_gardens=true,
	lethariel_crownlake=true,nhal_veyr_necropolis=true,mournfen_dryward=true,
	gor_drazhak_crossmesa=true,raincall_coastal_steps=true,kezamba_cenote=true,
	wyrmglass_faultfields=true,wyrmglass_dragonspire=true,
	stormscale_gemterraces=true,stormscale_dragonroost=true,
}

local function landmark(numeric_id,id,zone_numeric_id,primitive,x,z,
		radius_x,radius_z,relief_id)
	local roles = {"base_H"}
	if target_landmarks[id] then roles[#roles+1] = "target_T" end
	if hydrology_landmarks[id] then roles[#roles+1] = "hydrology" end
	if route_landmarks[id] then
		roles[#roles+1] = "route"
		roles[#roles+1] = "interface"
	end
	roles[#roles+1] = "dressing"
	return {numeric_id=numeric_id,id=id,zone_numeric_id=zone_numeric_id,
		primitive=primitive,center=point(x,z),radius_x=radius_x,
		radius_z=radius_z,secondary_relief_id=relief_id,roles=roles}
end

source.landmarks = {
	landmark(1,"hearthpine_bowl",1,"ellipse",-1800,-2520,290,220,"lowland"),
	landmark(2,"copperfell_drainage",2,"capsule",-2050,-2050,180,260,"highland"),
	landmark(3,"copperfell_coastal_terraces",2,"rectangle",-2350,-2200,150,300,"lowland"),
	landmark(4,"dur_brannoc_granite_terrace",3,"rectangle",-1800,-1500,352,352,"plateau"),
	landmark(5,"dur_brannoc_forge_chasm",3,"capsule",-1800,-1500,55,120,"highland"),
	landmark(6,"frostbarrow_escarpment",4,"capsule",-2420,-1450,120,300,"highland"),
	landmark(7,"frostbarrow_tarns",4,"ellipse",-2350,-1740,150,100,"plateau"),
	landmark(8,"stormvault_arch",5,"ellipse",-1820,-650,180,130,"mountain"),
	landmark(9,"dawnmere_headwaters",6,"capsule",0,-2500,230,150,"wetland_delta"),
	landmark(10,"goldmead_millriver",7,"capsule",0,-2020,110,260,"lowland"),
	landmark(11,"goldmead_orchard_slopes",7,"ellipse",-280,-2050,210,150,"rolling_hills"),
	landmark(12,"highcourt_riverfork",8,"capsule",0,-1500,280,352,"lowland"),
	landmark(13,"whitebridge_crossing",9,"capsule",-900,-1500,250,70,"lowland"),
	landmark(14,"whitebridge_ford",9,"capsule",-720,-1260,180,60,"wetland_delta"),
	landmark(15,"ashenward_burnscar",10,"capsule",0,-720,260,90,"rolling_hills"),
	landmark(16,"ashenward_trenchbelt",10,"rectangle",0,-470,330,120,"wetland_delta"),
	landmark(17,"silverleaf_gladechain",11,"capsule",1800,-2520,250,180,"lowland"),
	landmark(18,"starbough_canopy_steps",12,"ellipse",1950,-2050,230,180,"highland"),
	landmark(19,"starbough_coastal_gardens",12,"rectangle",2350,-2200,150,300,"lowland"),
	landmark(20,"lethariel_crownlake",13,"ellipse",1800,-1500,260,220,"lowland"),
	landmark(21,"lorindor_silverorchards",14,"ellipse",900,-1500,280,190,"rolling_hills"),
	landmark(22,"lorindor_berrymarsh",14,"ellipse",1080,-1740,150,110,"wetland_delta"),
	landmark(23,"moonfall_crescent",15,"ellipse",2400,-1500,150,230,"wetland_delta"),
	landmark(24,"glassroot_pale_cliffs",16,"capsule",1550,-650,170,300,"mountain"),
	landmark(25,"glassroot_rootways",16,"capsule",2050,-520,260,120,"highland"),
	landmark(26,"stillgrave_basin",17,"ellipse",-1800,2520,290,220,"lowland"),
	landmark(27,"stillgrave_ringbarrows",17,"ellipse",-1800,2520,330,250,"rolling_hills"),
	landmark(28,"mournfen_drowned_roads",18,"capsule",-2050,2100,180,260,"wetland_delta"),
	landmark(29,"mournfen_dryward",18,"rectangle",-2370,2200,151,300,"lowland"),
	landmark(30,"nhal_veyr_necropolis",19,"rectangle",-1800,1500,352,352,"plateau"),
	landmark(31,"ossuary_spine",20,"capsule",-2400,1450,130,300,"highland"),
	landmark(32,"ossuary_gravewoods",20,"ellipse",-2320,1730,170,120,"rolling_hills"),
	landmark(33,"blackwind_bonearches",21,"ellipse",-1850,650,220,150,"highland"),
	landmark(34,"blackwind_ashcuts",21,"capsule",-1350,520,240,110,"plateau"),
	landmark(35,"sunscar_open_flats",22,"rectangle",0,2520,290,220,"lowland"),
	landmark(36,"sunscar_waterholes",22,"ellipse",260,2450,130,90,"wetland_delta"),
	landmark(37,"redtusk_gullies",23,"capsule",-120,2050,250,120,"plateau"),
	landmark(38,"redtusk_wellchain",23,"capsule",180,2040,180,80,"rolling_hills"),
	landmark(39,"gor_drazhak_crossmesa",24,"rectangle",0,1500,352,352,"plateau"),
	landmark(40,"speargrass_dryriver",25,"capsule",-900,1500,280,90,"rolling_hills"),
	landmark(41,"speargrass_hunting_stones",25,"ellipse",-700,1750,180,100,"plateau"),
	landmark(42,"bannerbreak_crowned_mesa",26,"ellipse",0,650,290,220,"highland"),
	landmark(43,"bannerbreak_siegeramps",26,"capsule",0,430,330,100,"plateau"),
	landmark(44,"kapok_worldtree_basin",27,"ellipse",1800,2520,290,220,"wetland_delta"),
	landmark(45,"raincall_falls",28,"capsule",2020,2080,210,260,"highland"),
	landmark(46,"raincall_coastal_steps",28,"rectangle",2350,2200,150,300,"lowland"),
	landmark(47,"kezamba_cenote",29,"ellipse",1800,1500,250,220,"wetland_delta"),
	landmark(48,"whispering_reedmaze",30,"rectangle",900,1500,300,230,"wetland_delta"),
	landmark(49,"whispering_totemways",30,"capsule",900,1500,300,80,"lowland"),
	landmark(50,"totemwater_delta",31,"capsule",2400,1500,160,300,"wetland_delta"),
	landmark(51,"totemwater_colossi",31,"ellipse",2380,1750,160,110,"lowland"),
	landmark(52,"thunderroot_exposures",32,"capsule",2050,520,260,120,"highland"),
	landmark(53,"thunderroot_ochresteps",32,"ellipse",1550,680,210,180,"plateau"),
	landmark(54,"wyrmglass_ring",33,"ellipse",-3150,0,250,300,"mountain"),
	landmark(55,"wyrmglass_faultfields",33,"rectangle",-3200,60,150,120,"highland"),
	landmark(56,"wyrmglass_dragonspire",33,"ellipse",-3260,-40,100,90,"mountain"),
	landmark(57,"gravesalt_whitewall",34,"capsule",-2050,0,350,120,"mountain"),
	landmark(58,"gravesalt_tombways",34,"rectangle",-1800,0,260,160,"highland"),
	landmark(59,"gravesalt_warcoast",34,"capsule",-2420,0,80,230,"highland"),
	landmark(60,"broken_threeways",35,"rectangle",-750,0,520,180,"lowland"),
	landmark(61,"broken_marsh",35,"rectangle",-750,0,650,220,"wetland_delta"),
	landmark(62,"shattered_breachwall",36,"capsule",750,0,620,70,"plateau"),
	landmark(63,"shattered_noman",36,"rectangle",750,0,650,210,"rolling_hills"),
	landmark(64,"shattered_siegeramp",36,"capsule",1250,60,180,80,"plateau"),
	landmark(65,"skyglass_escarpment",37,"capsule",2050,0,350,120,"mountain"),
	landmark(66,"skyglass_hangingways",37,"rectangle",1800,0,260,160,"rolling_hills"),
	landmark(67,"skyglass_warcoast",37,"capsule",2420,0,80,230,"highland"),
	landmark(68,"stormscale_caldera",38,"ellipse",3150,0,250,300,"mountain"),
	landmark(69,"stormscale_gemterraces",38,"rectangle",3200,60,150,120,"highland"),
	landmark(70,"stormscale_dragonroost",38,"ellipse",3260,-40,100,90,"mountain"),
}

source.hydrology_profiles = {
	{id="dry_channel",depth=0,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=8,mask_semantic_id="hydro_dry_channel_v1"},
	{id="ford",depth=1,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=8,mask_semantic_id="hydro_ford_v1"},
	{id="shallow_marsh",depth=1,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=8,mask_semantic_id="hydro_shallow_marsh_v1"},
	{id="stream",depth=2,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=8,mask_semantic_id="hydro_stream_v1"},
	{id="spring",depth=2,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=8,mask_semantic_id="hydro_spring_v1"},
	{id="shallow_pond",depth=2,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=8,mask_semantic_id="hydro_shallow_pond_v1"},
	{id="river",depth=4,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=12,mask_semantic_id="hydro_river_v1"},
	{id="delta_arm",depth=4,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=12,mask_semantic_id="hydro_delta_arm_v1"},
	{id="ordinary_lake",depth=8,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=16,mask_semantic_id="hydro_ordinary_lake_v1"},
	{id="plunge_pool",depth=12,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=16,mask_semantic_id="hydro_plunge_pool_v1"},
	{id="deep_cenote",depth=12,bed_seal_layers=3,bank_seal_nodes=2,bank_blend_width=16,mask_semantic_id="hydro_deep_cenote_v1"},
}

source.hydrology_transition_profiles = {
	{id="river_confluence_exact",kind="confluence",run=0,drop=0,open_face="outgoing_reach",seal_semantic_id="hydro_confluence_seal_v1"},
	{id="bridge_clearance",kind="bridge",run=12,drop=0,vertical_rule_id="bridge_clearance_v1",minimum_clearance_nodes=3,open_face="bridge_lumen",seal_semantic_id="hydro_bridge_seal_v1"},
	{id="ford_bed",kind="ford",run=12,drop=0,vertical_rule_id="ford_bed_v1",road_y_offset_from_bed=0,open_face="water_surface",seal_semantic_id="hydro_ford_seal_v1"},
	{id="rapid_drop",kind="rapid",run=1,drop=1,open_face="downstream",seal_semantic_id="hydro_rapid_seal_v1"},
	{id="waterfall_drop",kind="waterfall",run=1,drop=1,open_face="fall_face",seal_semantic_id="hydro_waterfall_seal_v1"},
	{id="causeway_deck",kind="causeway",run=12,drop=0,vertical_rule_id="causeway_culvert_v1",deck_y_offset_from_W=1,open_face="water_surface",seal_semantic_id="hydro_causeway_seal_v1"},
}

local function hydro(id,landmark_id,zone_numeric_id,profile_id,offset,
		centreline,from_id,to_id,civic_core_zone_numeric_id)
	return {id=id,landmark_id=landmark_id,zone_numeric_id=zone_numeric_id,
		profile_id=profile_id,water_surface_reference="mapgen_water_level",
		water_surface_offset=offset,centreline=centreline,from_id=from_id,
		to_id=to_id,water_node_semantic="surface_water",
		civic_core_zone_numeric_id=civic_core_zone_numeric_id}
end

source.hydrology = {
	hydro("hydro_copperfell_streams","copperfell_drainage",2,"stream",18,{{x=-2320,z=-1780,half_width=18},{x=-2260,z=-1880,half_width=20},{x=-2150,z=-1950,half_width=22},{x=-2010,z=-2040,half_width=24},{x=-1850,z=-2100,half_width=26},{x=-1650,z=-2160,half_width=28},{x=-1450,z=-2140,half_width=30},{x=-1260,z=-2070,half_width=32},{x=-1060,z=-2020,half_width=34}},"copperfell_spring","copperfell_sink"),
	hydro("hydro_frostbarrow_tarns","frostbarrow_tarns",4,"shallow_pond",62,{{x=-2440,z=-1710,half_width=35},{x=-2380,z=-1670,half_width=60},{x=-2300,z=-1680,half_width=72},{x=-2220,z=-1740,half_width=54},{x=-2180,z=-1800,half_width=34}},"frostbarrow_inflow","frostbarrow_basin"),
	hydro("hydro_dawnmere_headwaters","dawnmere_headwaters",6,"spring",12,{{x=70,z=-2440,half_width=30},{x=115,z=-2400,half_width=48},{x=180,z=-2410,half_width=55},{x=225,z=-2460,half_width=34}},"dawnmere_spring","dawnmere_outflow",6),
	hydro("hydro_goldmead_millriver","goldmead_millriver",7,"river",16,{{x=-80,z=-2250,half_width=22},{x=-20,z=-2140,half_width=23},{x=60,z=-2020,half_width=24},{x=20,z=-1900,half_width=24},{x=-100,z=-1780,half_width=24}},"goldmead_upstream","goldmead_downstream"),
	hydro("hydro_highcourt_fork_west","highcourt_riverfork",8,"river",34,{{x=-100,z=-1780,half_width=24},{x=-170,z=-1680,half_width=25},{x=-180,z=-1580,half_width=26},{x=-100,z=-1460,half_width=25},{x=0,z=-1320,half_width=24}},"highcourt_west_source","highcourt_fork_join",8),
	hydro("hydro_highcourt_fork_east","highcourt_riverfork",8,"river",34,{{x=500,z=-1850,half_width=18},{x=410,z=-1750,half_width=20},{x=300,z=-1670,half_width=22},{x=180,z=-1510,half_width=23},{x=0,z=-1320,half_width=24}},"highcourt_east_source","highcourt_fork_join",8),
	hydro("hydro_highcourt_outflow","highcourt_riverfork",8,"river",34,{{x=0,z=-1320,half_width=24},{x=120,z=-1100,half_width=22}},"highcourt_fork_join","highcourt_outflow",8),
	hydro("hydro_whitebridge_main","whitebridge_crossing",9,"river",16,{{x=-1060,z=-2020,half_width=26},{x=-1040,z=-1900,half_width=25},{x=-980,z=-1800,half_width=24},{x=-850,z=-1680,half_width=23},{x=-700,z=-1600,half_width=22},{x=-540,z=-1530,half_width=21},{x=-400,z=-1500,half_width=20}},"whitebridge_upstream","whitebridge_downstream"),
	hydro("hydro_whitebridge_ford","whitebridge_ford",9,"ford",16,{{x=-900,z=-1100,half_width=18},{x=-850,z=-1140,half_width=18},{x=-820,z=-1180,half_width=18},{x=-760,z=-1230,half_width=18},{x=-720,z=-1260,half_width=18},{x=-560,z=-1400,half_width=19},{x=-400,z=-1500,half_width=20}},"whitebridge_ford_upstream","whitebridge_ford_downstream"),
	hydro("hydro_lethariel_lake","lethariel_crownlake",13,"ordinary_lake",34,{{x=1800,z=-1440,half_width=38},{x=1840,z=-1390,half_width=62},{x=1900,z=-1380,half_width=78},{x=1960,z=-1420,half_width=68},{x=1990,z=-1480,half_width=42}},"lethariel_inflow","lethariel_outflow",13),
	hydro("hydro_lorindor_marsh","lorindor_berrymarsh",14,"shallow_marsh",28,{{x=1930,z=-1420,half_width=24},{x=1810,z=-1490,half_width=26},{x=1700,z=-1550,half_width=28},{x=1570,z=-1600,half_width=29},{x=1450,z=-1650,half_width=30},{x=1320,z=-1710,half_width=35},{x=1200,z=-1770,half_width=40},{x=1100,z=-1880,half_width=36},{x=1020,z=-1990,half_width=32}},"lorindor_inflow","lorindor_sink"),
	hydro("hydro_moonfall_lake","moonfall_crescent",15,"ordinary_lake",18,{{x=2260,z=-1540,half_width=42},{x=2310,z=-1470,half_width=68},{x=2400,z=-1440,half_width=84},{x=2490,z=-1480,half_width=72},{x=2540,z=-1560,half_width=44}},"moonfall_inflow","moonfall_outflow"),
	hydro("hydro_mournfen_marsh","mournfen_drowned_roads",18,"shallow_marsh",8,{{x=-2380,z=1750,half_width=30},{x=-2280,z=1810,half_width=36},{x=-2200,z=1900,half_width=45},{x=-2140,z=2010,half_width=54},{x=-2050,z=2100,half_width=60},{x=-1850,z=2160,half_width=54},{x=-1600,z=2150,half_width=45},{x=-1330,z=2080,half_width=39},{x=-1060,z=2010,half_width=34}},"mournfen_inflow","mournfen_sink"),
	hydro("hydro_sunscar_waterholes","sunscar_waterholes",22,"shallow_pond",12,{{x=170,z=2470,half_width=34},{x=220,z=2425,half_width=58},{x=290,z=2420,half_width=68},{x=350,z=2470,half_width=42}},"sunscar_seep","sunscar_basin",22),
	hydro("hydro_speargrass_dryriver","speargrass_dryriver",25,"dry_channel",28,{{x=-1100,z=1900,half_width=18},{x=-1000,z=1700,half_width=18},{x=-900,z=1500,half_width=18},{x=-780,z=1300,half_width=18}},"speargrass_dry_head","speargrass_dry_mouth"),
	hydro("hydro_raincall_headwater","raincall_falls",28,"shallow_pond",72,{{x=1850,z=2280,half_width=42},{x=1880,z=2250,half_width=70},{x=1930,z=2200,half_width=65},{x=1960,z=2140,half_width=40}},"raincall_headwater","raincall_upper_rapid"),
	hydro("hydro_raincall_upper_lip","raincall_falls",28,"shallow_pond",68,{{x=1960,z=2140,half_width=40},{x=1990,z=2110,half_width=38}},"raincall_upper_rapid","raincall_upper_lip"),
	hydro("hydro_raincall_middle_upper","raincall_falls",28,"shallow_pond",56,{{x=1990,z=2070,half_width=34},{x=2020,z=2040,half_width=32}},"raincall_upper_drop","raincall_middle_rapid"),
	hydro("hydro_raincall_middle_lip","raincall_falls",28,"shallow_pond",52,{{x=2020,z=2040,half_width=32},{x=2050,z=2010,half_width=38}},"raincall_middle_rapid","raincall_lower_lip"),
	hydro("hydro_raincall_plunge","raincall_falls",28,"plunge_pool",44,{{x=2050,z=1970,half_width=45},{x=2130,z=1900,half_width=70}},"raincall_lower_drop","raincall_outflow"),
	hydro("hydro_kezamba_cenote","kezamba_cenote",29,"deep_cenote",64,{{x=1810,z=1600,half_width=42},{x=1850,z=1560,half_width=68},{x=1910,z=1565,half_width=75},{x=1960,z=1610,half_width=48}},"kezamba_inflow","kezamba_cenote_sink",29),
	hydro("hydro_whispering_reedmaze","whispering_reedmaze",30,"shallow_marsh",8,{{x=2130,z=1900,half_width=34},{x=1940,z=1890,half_width=33},{x=1750,z=1850,half_width=32},{x=1560,z=1825,half_width=35},{x=1350,z=1770,half_width=40},{x=1170,z=1710,half_width=43},{x=1000,z=1650,half_width=45}},"reedmaze_inflow","reedmaze_outflow"),
	hydro("hydro_totemwater_delta","totemwater_delta",31,"delta_arm",8,{{x=1000,z=1650,half_width=45},{x=990,z=1750,half_width=50},{x=950,z=1850,half_width=55},{x=920,z=1920,half_width=62},{x=900,z=1980,half_width=70}},"totemwater_upstream","totemwater_mouth"),
	hydro("hydro_gravesalt_pans","gravesalt_whitewall",34,"shallow_marsh",100,{{x=-2200,z=0,half_width=55},{x=-2080,z=-20,half_width=66},{x=-1950,z=0,half_width=75},{x=-1820,z=45,half_width=64},{x=-1700,z=80,half_width=50}},"gravesalt_seep","gravesalt_pan"),
	hydro("hydro_broken_marsh","broken_marsh",35,"ordinary_lake",8,{{x=-1700,z=80,half_width=50},{x=-1600,z=-20,half_width=54},{x=-1500,z=-125,half_width=55},{x=-1300,z=30,half_width=60},{x=-1125,z=250,half_width=65},{x=-930,z=100,half_width=74},{x=-750,z=-100,half_width=85},{x=-560,z=-180,half_width=68},{x=-375,z=-250,half_width=55}},"broken_marsh_inflow","broken_marsh_outflow"),
}

source.hydrology_interfaces = {
	{id="highcourt_fork_join",kind="confluence",from_ids={"hydro_highcourt_fork_west","hydro_highcourt_fork_east"},outgoing_reach_id="hydro_highcourt_outflow",position=point(0,-1320),transition_profile_id="river_confluence_exact",sealed=true},
	{id="whitebridge_bridge_water",kind="bridge",hydrology_id="hydro_whitebridge_main",route_interface_id="whitebridge_bridge",position=point(-400,-1500),transition_profile_id="bridge_clearance",sealed=true},
	{id="whitebridge_ford_water",kind="ford",hydrology_id="hydro_whitebridge_ford",route_interface_id="whitebridge_ford",position=point(-900,-1100),transition_profile_id="ford_bed",sealed=true},
	{id="raincall_upper_rapid",kind="rapid",upper_id="hydro_raincall_headwater",lower_id="hydro_raincall_upper_lip",upper_level_offset=72,lower_level_offset=68,position=point(1960,2140),transition_profile_id="rapid_drop",run=48,drop=4,width=12,bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="raincall_upper_fall",kind="waterfall",upper_id="hydro_raincall_upper_lip",lower_id="hydro_raincall_middle_upper",upper_level_offset=68,lower_level_offset=56,position=point(1990,2090),lip_id="raincall_upper_lip",drop_id="raincall_upper_drop",plunge_id="raincall_upper_plunge",transition_profile_id="waterfall_drop",drop=12,drop_height=12,drop_mask_width=10,drop_mask_length=40,plunge_profile_id="shallow_pond",plunge_width=48,plunge_length=40,bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="raincall_middle_rapid",kind="rapid",upper_id="hydro_raincall_middle_upper",lower_id="hydro_raincall_middle_lip",upper_level_offset=56,lower_level_offset=52,position=point(2020,2040),transition_profile_id="rapid_drop",run=40,drop=4,width=12,bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="raincall_lower_fall",kind="waterfall",upper_id="hydro_raincall_middle_lip",lower_id="hydro_raincall_plunge",upper_level_offset=52,lower_level_offset=44,position=point(2050,1990),lip_id="raincall_lower_lip",drop_id="raincall_lower_drop",plunge_id="raincall_lower_plunge",transition_profile_id="waterfall_drop",drop=8,drop_height=8,drop_mask_width=12,drop_mask_length=40,plunge_profile_id="plunge_pool",plunge_width=60,plunge_length=48,bed_seal_layers=3,bank_seal_nodes=2,sealed=true},
	{id="broken_causeway_water",kind="causeway",hydrology_id="hydro_broken_marsh",route_interface_id="broken_causeway",position=point(-375,-250),transition_profile_id="causeway_deck",sealed=true},
	{id="broken_ford_water",kind="ford",hydrology_id="hydro_broken_marsh",route_interface_id="broken_ford",position=point(-1125,250),transition_profile_id="ford_bed",sealed=true},
	{id="broken_aqueduct_water",kind="bridge",hydrology_id="hydro_broken_marsh",route_interface_id="broken_aqueduct",position=point(-1500,-125),transition_profile_id="bridge_clearance",sealed=true},
	{id="gravesalt_causeway_south_water",kind="causeway",hydrology_id="hydro_gravesalt_pans",route_interface_id="gravesalt_causeway_south",position=point(-2000,0),transition_profile_id="causeway_deck",sealed=true},
	{id="gravesalt_causeway_north_water",kind="causeway",hydrology_id="hydro_gravesalt_pans",route_interface_id="gravesalt_causeway_north",position=point(-2000,0),transition_profile_id="causeway_deck",sealed=true},
}

source.hard_protection_recipes = {
	{id="hard_capital_build_plus_apron_v1",shape="centered_half_open_square",footprint_policy_id="centered_half_open_square_v1",total_width=532,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
	{id="hard_capital_ingress_corridor_v1",shape="polyline_corridor",footprint_policy_id="polyline_corridor_v1",total_width=128,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
	{id="hard_start_core_v1",shape="centered_half_open_square",footprint_policy_id="centered_half_open_square_v1",total_width=128,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
	{id="hard_apex_socket_column_v1",shape="exact_column",footprint_policy_id="exact_column_v1",column_count=1,y_policy_id="shallow_land_upward_to_world_top",y_min=-700,upward_unbounded=true},
}

source.capital_ingresses = {
	{id="ingress_dur_brannoc",capital_anchor_id="anchor_007",route_ids={"route_003","route_043"},total_width=128},
	{id="ingress_highcourt",capital_anchor_id="anchor_008",route_ids={"route_006","route_046"},total_width=128},
	{id="ingress_lethariel",capital_anchor_id="anchor_009",route_ids={"route_009","route_048"},total_width=128},
	{id="ingress_nhal_veyr",capital_anchor_id="anchor_010",route_ids={"route_012","route_049"},total_width=128},
	{id="ingress_gor_drazhak",capital_anchor_id="anchor_011",route_ids={"route_015","route_052"},total_width=128},
	{id="ingress_kezamba",capital_anchor_id="anchor_012",route_ids={"route_018","route_054"},total_width=128},
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
for ingress_index = 1, #source.capital_ingresses do
	local ingress=source.capital_ingresses[ingress_index]
	source.hard_protection[#source.hard_protection+1] = {
		id="hard:"..ingress.id,source_anchor_id=ingress.capital_anchor_id,
		ingress_id=ingress.id,route_ids=ingress.route_ids,
		recipe_id="hard_capital_ingress_corridor_v1",
		active=true,activation_owner="WP40",status="active",
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
	local candidates = anchor.position and {anchor.position} or anchor.candidates
	for candidate_index = 1, #candidates do
		local candidate = candidates[candidate_index]
		add_exclusion({
			id=("exclude:anchor:%s:%02d"):format(anchor.id,candidate_index),
			recipe_id="exclude_anchor_blend_v1",source_id=anchor.id,
			candidate_index=candidate_index,center=point(candidate.x,candidate.z),
			total_width=profile.blend_width,
			coverage="complete_fitting_plus_blend_envelope",
		})
	end
end
for route_index = 1, #source.routes do
	local route = source.routes[route_index]
	add_exclusion({id="exclude:route:"..route.id,
		recipe_id="exclude_route_corridor_v1",source_id=route.id,
		corridor_width=route.corridor_width,coverage="complete_centreline"})
end
for route_index = 1, #source.island_routes do
	local route = source.island_routes[route_index]
	add_exclusion({id="exclude:route:"..route.id,
		recipe_id="exclude_route_corridor_v1",source_id=route.id,
		corridor_width=12,coverage="complete_centreline"})
end
local trail_template = {
	bandit_home=true,bandit_frontier=true,mirefolk=true,clash=true,
}
for spur_index = 1, #source.poi_spurs do
	local spur = source.poi_spurs[spur_index]
	local anchor = anchor_by_id[spur.anchor_id]
	add_exclusion({id="exclude:route:"..spur.id,
		recipe_id="exclude_route_corridor_v1",source_id=spur.id,
		corridor_width=trail_template[anchor.template_id] and 8 or 12,
		coverage="all_candidate_paths_and_fixed_terminal"})
end
for hydro_index = 1, #source.hydrology do
	local reach = source.hydrology[hydro_index]
	add_exclusion({id="exclude:water:"..reach.id,
		recipe_id="exclude_planned_water_v1",source_id=reach.id,
		coverage="complete_analytic_mask"})
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
