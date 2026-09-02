-- Engine-free horizontal metadata validation for the compact WP40 source.
-- Geometry ownership is delegated to the supplied simple-map session; this
-- module deliberately does not reproduce point-in-shape predicates.

local EXPECTED_HOUSING_POLICY = {
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
}

local EXPECTED_HOUSING_ORDERS = {
	"minimum_conflict_degree", "maximum_conflict_degree", "edge_biased",
	"route_biased", "poi_biased", "row_major", "reverse_row_major",
}

local HOUSING_MASK_IDS = {
	"housing_elandor_copperfell", "housing_elandor_goldmead",
	"housing_elandor_starbough", "housing_elandor_whitebridge",
	"housing_elandor_lorindor", "housing_kragmar_mournfen",
	"housing_kragmar_redtusk", "housing_kragmar_raincall",
	"housing_kragmar_speargrass", "housing_kragmar_whispering",
}

local COASTAL_CORES = {
	{"coastal_core_copperfell", 2, "housing_elandor_copperfell",
		"copperfell_coastal_terraces"},
	{"coastal_core_starbough", 12, "housing_elandor_starbough",
		"starbough_coastal_gardens"},
	{"coastal_core_mournfen", 18, "housing_kragmar_mournfen",
		"mournfen_dryward"},
	{"coastal_core_raincall", 28, "housing_kragmar_raincall",
		"raincall_coastal_steps"},
}

local RELIEF_IDS = {
	"wetland_delta", "lowland", "rolling_hills", "plateau", "highland",
	"mountain",
}

local ANCHOR_PROFILE_IDS = {
	"start", "capital_dwarf", "capital_human", "capital_elf",
	"capital_undead", "capital_orc", "capital_troll", "village", "outpost",
	"bandit_home", "bandit_frontier", "mine", "mirefolk", "clash",
	"dragon", "apex_mine", "rare_route",
}

local LANDMARK_IDS = {
	"hearthpine_bowl", "copperfell_drainage",
	"copperfell_coastal_terraces", "dur_brannoc_granite_terrace",
	"dur_brannoc_forge_chasm", "frostbarrow_escarpment",
	"frostbarrow_tarns", "stormvault_arch", "dawnmere_headwaters",
	"goldmead_millriver", "goldmead_orchard_slopes", "highcourt_riverfork",
	"whitebridge_crossing", "whitebridge_ford", "ashenward_burnscar",
	"ashenward_trenchbelt", "silverleaf_gladechain",
	"starbough_canopy_steps", "starbough_coastal_gardens",
	"lethariel_crownlake", "lorindor_silverorchards",
	"lorindor_berrymarsh", "moonfall_crescent", "glassroot_pale_cliffs",
	"glassroot_rootways", "stillgrave_basin", "stillgrave_ringbarrows",
	"mournfen_drowned_roads", "mournfen_dryward", "nhal_veyr_necropolis",
	"ossuary_spine", "ossuary_gravewoods", "blackwind_bonearches",
	"blackwind_ashcuts", "sunscar_open_flats", "sunscar_waterholes",
	"redtusk_gullies", "redtusk_wellchain", "gor_drazhak_crossmesa",
	"speargrass_dryriver", "speargrass_hunting_stones",
	"bannerbreak_crowned_mesa", "bannerbreak_siegeramps",
	"kapok_worldtree_basin", "raincall_falls", "raincall_coastal_steps",
	"kezamba_cenote", "whispering_reedmaze", "whispering_totemways",
	"totemwater_delta", "totemwater_colossi", "thunderroot_exposures",
	"thunderroot_ochresteps", "wyrmglass_ring", "wyrmglass_faultfields",
	"wyrmglass_dragonspire", "gravesalt_whitewall", "gravesalt_tombways",
	"gravesalt_warcoast", "broken_threeways", "broken_marsh",
	"shattered_breachwall", "shattered_noman", "shattered_siegeramp",
	"skyglass_escarpment", "skyglass_hangingways", "skyglass_warcoast",
	"stormscale_caldera", "stormscale_gemterraces",
	"stormscale_dragonroost",
}

local HYDROLOGY_PROFILE_IDS = {
	"dry_channel", "ford", "shallow_marsh", "stream", "spring",
	"shallow_pond", "river", "delta_arm", "ordinary_lake", "plunge_pool",
	"deep_cenote",
}

local TRANSITION_PROFILE_IDS = {
	"river_confluence_exact", "bridge_clearance", "ford_bed", "rapid_drop",
	"waterfall_drop", "causeway_deck",
}

local HYDROLOGY_IDS = {
	"hydro_copperfell_streams", "hydro_frostbarrow_tarns",
	"hydro_dawnmere_headwaters", "hydro_goldmead_millriver",
	"hydro_highcourt_fork_west", "hydro_highcourt_fork_east",
	"hydro_highcourt_outflow", "hydro_whitebridge_main",
	"hydro_whitebridge_ford", "hydro_lethariel_lake",
	"hydro_lorindor_marsh", "hydro_moonfall_lake",
	"hydro_mournfen_marsh", "hydro_sunscar_waterholes",
	"hydro_speargrass_dryriver", "hydro_raincall_headwater",
	"hydro_raincall_upper_lip", "hydro_raincall_middle_upper",
	"hydro_raincall_middle_lip", "hydro_raincall_plunge",
	"hydro_kezamba_cenote", "hydro_whispering_reedmaze",
	"hydro_totemwater_delta", "hydro_gravesalt_pans", "hydro_broken_marsh",
}

local HYDROLOGY_INTERFACE_IDS = {
	"highcourt_fork_join", "whitebridge_bridge_water",
	"whitebridge_ford_water", "raincall_upper_rapid",
	"raincall_upper_fall", "raincall_middle_rapid", "raincall_lower_fall",
	"broken_causeway_water", "broken_ford_water", "broken_aqueduct_water",
	"gravesalt_causeway_south_water", "gravesalt_causeway_north_water",
	"highcourt_goldmead_fall", "gravesalt_broken_fall",
	"raincall_reedmaze_fall",
}

local BIOME_IDS = {
	"grug_pine_hills", "grug_crags", "grug_swamp", "grug_crags_snowy",
	"grug_meadows", "grug_deep_forest", "grug_elf_forest",
	"grug_jungle_fringe", "grug_blight", "grug_bone_forest",
	"grug_savanna", "grug_badlands", "grug_jungle_edge",
	"grug_deep_jungle", "grug_badlands_east", "grug_beach",
}

local HARD_RECIPE_IDS = {
	"hard_capital_build_plus_apron_v1",
	"hard_capital_ingress_corridor_v1", "hard_start_core_v1",
	"hard_apex_socket_column_v1",
}

local CLAIM_RECIPE_IDS = {
	"exclude_anchor_blend_v1", "exclude_route_corridor_v1",
	"exclude_planned_water_v1", "exclude_coast_v1",
	"exclude_active_core_v1",
}

local DEFERRED_R3 = {
	"terrain_height_field", "relief_height_composition",
	"landmark_vertical_composition", "hydrology_surface_levels_and_grading",
	"anchor_terrain_fitting", "hard_protection_vertical_volumes",
	"coastal_housing_vertical_relief",
}

local function records(value)
	if type(value) == "table" then return value end
	return {}
end

local function scalar(value)
	local kind = type(value)
	if kind == "string" or kind == "number" or kind == "boolean" then
		return value
	end
	if value == nil then return "<nil>" end
	return "<" .. kind .. ">"
end

local function integer(value)
	return type(value) == "number" and value == math.floor(value)
end

local function point_record(value)
	return type(value) == "table" and integer(value.x) and integer(value.z)
end

local function expected_macro_region(index)
	if index <= 16 then return "elandor_mainland" end
	if index <= 32 then return "kragmar_mainland" end
	if index == 33 then return "wyrmglass_island" end
	if index <= 37 then return "holy_grounds" end
	return "stormscale_island"
end

local function number_token(value)
	if type(value) ~= "number" then return "?" end
	return ("%.17g"):format(value)
end

return function(source, session)
	local result = {
		violations = {},
		metrics = {
			scope = "R2_horizontal_metadata",
			counts = {},
			ownership = {authored_fixed_centers_checked=0,
				layout_fixed_centers_checked=0},
			deferred_r3 = {},
		},
		coastal_cores = {},
		witnesses = {},
	}
	if type(source) ~= "table" then source = {} end

	local function violation(code, family, record_id, expected, actual)
		result.violations[#result.violations+1] = {
			code = code,
			family = family,
			record_id = record_id or "",
			expected = scalar(expected),
			actual = scalar(actual),
		}
	end

	local function witness(code, family, record_id, fields)
		local row = {code=code, family=family, record_id=record_id or ""}
		for index = 1, #fields do
			row[fields[index][1]] = scalar(fields[index][2])
		end
		result.witnesses[#result.witnesses+1] = row
	end

	local function count_keys(value)
		if type(value) ~= "table" then return 0 end
		local count = 0
		for _ in pairs(value) do count = count + 1 end
		return count
	end

	local function id_index(values, family)
		local by_id = {}
		for index = 1, #values do
			local row = values[index]
			local id = type(row) == "table" and row.id or nil
			if type(id) ~= "string" or id == "" then
				violation("invalid_id", family, ("#%d"):format(index),
					"nonempty string", id)
			elseif by_id[id] then
				violation("duplicate_id", family, id, "unique", "duplicate")
			else
				by_id[id] = row
			end
		end
		return by_id
	end

	local function validate_roster(values, expected, family)
		result.metrics.counts[family] = #values
		if #values ~= #expected then
			violation("count_mismatch", family, "", #expected, #values)
		end
		for index = 1, #expected do
			local actual = type(values[index]) == "table" and values[index].id or nil
			if actual ~= expected[index] then
				violation("roster_mismatch", family, ("#%d"):format(index),
					expected[index], actual)
			end
		end
	end

	-- The complete packing-policy record is fixed horizontal authorship.
	local housing = source.housing_policy
	if type(housing) ~= "table" then
		violation("missing_policy", "housing_policy", "", "table", housing)
		housing = {}
	end
	if count_keys(housing) ~= 15 then
		violation("field_count_mismatch", "housing_policy", "", 15,
			count_keys(housing))
	end
	local housing_fields = {
		"reservation_width", "reservation_radius", "minimum_gap",
		"lattice_spacing", "lattice_origin_period", "hash_order_count",
		"hash_domain_prefix", "hash_order_numbering", "conflict_rule",
		"tie_break", "bias_direction", "edge_bias_scope", "route_bias_scope",
		"poi_bias_scope",
	}
	for index = 1, #housing_fields do
		local key = housing_fields[index]
		if housing[key] ~= EXPECTED_HOUSING_POLICY[key] then
			violation("policy_value_mismatch", "housing_policy", key,
				EXPECTED_HOUSING_POLICY[key], housing[key])
		end
	end
	local housing_orders = records(housing.greedy_orders)
	if #housing_orders ~= #EXPECTED_HOUSING_ORDERS then
		violation("count_mismatch", "housing_greedy_orders", "",
			#EXPECTED_HOUSING_ORDERS, #housing_orders)
	end
	for index = 1, #EXPECTED_HOUSING_ORDERS do
		if housing_orders[index] ~= EXPECTED_HOUSING_ORDERS[index] then
			violation("roster_mismatch", "housing_greedy_orders",
				("#%d"):format(index), EXPECTED_HOUSING_ORDERS[index],
				housing_orders[index])
		end
	end

	local zones = records(source.zones)
	local relief = records(source.relief_profiles)
	local anchor_profiles = records(source.anchor_profiles)
	local landmarks = records(source.landmarks)
	local hydrology_profiles = records(source.hydrology_profiles)
	local transition_profiles = records(source.hydrology_transition_profiles)
	local hydrology = records(source.hydrology)
	local hydro_interfaces = records(source.hydrology_interfaces)
	local masks = records(source.housing_masks)
	local coastal = records(source.coastal_housing_cores)

	validate_roster(relief, RELIEF_IDS, "relief_profiles")
	validate_roster(anchor_profiles, ANCHOR_PROFILE_IDS, "anchor_profiles")
	validate_roster(landmarks, LANDMARK_IDS, "landmarks")
	validate_roster(hydrology_profiles, HYDROLOGY_PROFILE_IDS,
		"hydrology_profiles")
	validate_roster(transition_profiles, TRANSITION_PROFILE_IDS,
		"hydrology_transition_profiles")
	validate_roster(hydrology, HYDROLOGY_IDS, "hydrology")
	validate_roster(hydro_interfaces, HYDROLOGY_INTERFACE_IDS,
		"hydrology_interfaces")
	validate_roster(masks, HOUSING_MASK_IDS, "housing_masks")

	local zone_by_id = id_index(zones, "zones")
	local relief_by_id = id_index(relief, "relief_profiles")
	local anchor_profile_by_id = id_index(anchor_profiles, "anchor_profiles")
	local landmark_by_id = id_index(landmarks, "landmarks")
	local hydro_profile_by_id = id_index(hydrology_profiles,
		"hydrology_profiles")
	local transition_by_id = id_index(transition_profiles,
		"hydrology_transition_profiles")
	local hydro_by_id = id_index(hydrology, "hydrology")
	local mask_by_id = id_index(masks, "housing_masks")
	local crossing_by_id = id_index(records(source.crossing_interfaces),
		"crossing_interfaces")

	-- Progression, faction and PvP authorship is complete on every zone.
	result.metrics.counts.zones = #zones
	if #zones ~= 38 then violation("count_mismatch", "zones", "", 38, #zones) end
	local biome_seen = {}
	local biome_count = 0
	local races = {dwarf=true, human=true, elf=true, undead=true, orc=true,
		troll=true}
	for index = 1, #zones do
		local row = zones[index]
		if type(row) == "table" then
			if row.numeric_id ~= index then
				violation("numeric_id_mismatch", "zones", row.id, index,
					row.numeric_id)
			end
			local expected_bias = index == 25 and 256 or 0
			if row.bias ~= expected_bias then
				violation("zone_bias_mismatch", "zones", row.id,
					expected_bias, row.bias)
			end
			if row.macro_region ~= expected_macro_region(index) then
				violation("macro_region_mismatch", "zones", row.id,
					expected_macro_region(index), row.macro_region)
			end
			if not races[row.race_region] then
				violation("race_region_missing", "zones", row.id,
					"required race", row.race_region)
			end
			if row.faction ~= "accord" and row.faction ~= "throng" and
					row.faction ~= false then
				violation("faction_missing", "zones", row.id,
					"accord/throng/false", row.faction)
			end
			local expected_faction, expected_pvp
			if row.territory_rule == "accord_home" then
				expected_faction, expected_pvp = "accord", "peaceful"
			elseif row.territory_rule == "throng_home" then
				expected_faction, expected_pvp = "throng", "peaceful"
			elseif row.territory_rule == "contested_land" or
					row.territory_rule == "holy_grounds" then
				expected_faction, expected_pvp = false, "contested"
			else
				violation("territory_rule_missing", "zones", row.id,
					"known rule", row.territory_rule)
			end
			if expected_faction ~= nil and row.faction ~= expected_faction then
				violation("faction_rule_mismatch", "zones", row.id,
					expected_faction, row.faction)
			end
			if expected_pvp and row.pvp_rule ~= expected_pvp then
				violation("pvp_rule_mismatch", "zones", row.id, expected_pvp,
					row.pvp_rule)
			end
			if not integer(row.level_min) or not integer(row.level_max) or
					row.level_min < 1 or row.level_min > row.level_max or
					row.level_max > 60 then
				violation("level_range_invalid", "zones", row.id, "1..60",
					"invalid")
			end
			if not integer(row.difficulty_target) or row.difficulty_target < 1 or
					row.difficulty_target > 60 then
				violation("difficulty_target_invalid", "zones", row.id, "1..60",
					row.difficulty_target)
			end
			if type(row.civic_no_hostiles) ~= "boolean" then
				violation("civic_policy_missing", "zones", row.id, "boolean",
					row.civic_no_hostiles)
			end
			if not relief_by_id[row.primary_relief_id] then
				violation("missing_reference", "zone_relief", row.id,
					"relief profile", row.primary_relief_id)
			end
			local shares, local_biomes = 0, {}
			local palette = records(row.biomes)
			if #palette == 0 then
				violation("empty_palette", "zone_biomes", row.id,
					"one or more", 0)
			end
			for palette_index = 1, #palette do
				local biome = palette[palette_index]
				local biome_id = type(biome) == "table" and biome.id or nil
				if type(biome_id) ~= "string" or biome_id == "" or
						local_biomes[biome_id] then
					violation("invalid_biome_id", "zone_biomes", row.id,
						"unique id", biome_id)
				else
					local_biomes[biome_id] = true
					if not biome_seen[biome_id] then
						biome_seen[biome_id] = true
						biome_count = biome_count + 1
					end
				end
				if type(biome) ~= "table" or not integer(biome.share) or
						biome.share <= 0 then
					violation("invalid_biome_share", "zone_biomes", row.id,
						"positive integer", type(biome) == "table" and
							biome.share or nil)
				else
					shares = shares + biome.share
				end
			end
			if shares ~= 100 then
				violation("biome_share_total", "zone_biomes", row.id, 100, shares)
			end
		end
	end
	result.metrics.counts.logical_biomes = biome_count
	if biome_count ~= #BIOME_IDS then
		violation("count_mismatch", "logical_biomes", "", #BIOME_IDS,
			biome_count)
	end
	for index = 1, #BIOME_IDS do
		if not biome_seen[BIOME_IDS[index]] then
			violation("roster_missing", "logical_biomes", BIOME_IDS[index],
				"present", "missing")
		end
	end

	local selector = source.logical_biome_selector
	if type(selector) ~= "table" then
		violation("missing_policy", "logical_biome_selector", "", "table",
			selector)
		selector = {}
	end
	local selector_values = {
		{"id", "zone_palette_jittered_voronoi_t1_hash_v1"},
		{"schema_version", 1}, {"cell_size", 192}, {"site_offset_min", 32},
		{"site_offset_span", 128},
		{"share_audit_tolerance_percentage_points", 5},
		{"ownership_rule", "resolve_zone_first_and_use_only_owning_zone_palette"},
	}
	for index = 1, #selector_values do
		local expected = selector_values[index]
		if selector[expected[1]] ~= expected[2] then
			violation("policy_value_mismatch", "logical_biome_selector",
				expected[1], expected[2], selector[expected[1]])
		end
	end
	local lanes = type(selector.hash_lanes) == "table" and selector.hash_lanes or {}
	for _, expected in ipairs({{"site_x",0},{"site_z",1},{"palette",2}}) do
		if lanes[expected[1]] ~= expected[2] then
			violation("policy_value_mismatch", "logical_biome_hash_lanes",
				expected[1], expected[2], lanes[expected[1]])
		end
	end

	-- Housing masks and the four authored coastal references are horizontal.
	for index = 1, #masks do
		local row = masks[index]
		if type(row) == "table" then
			if not zones[row.zone_numeric_id] then
				violation("missing_reference", "housing_masks", row.id,
					"zone", row.zone_numeric_id)
			end
			local polygon = records(row.polygon)
			if #polygon < 3 then
				violation("invalid_polygon", "housing_masks", row.id,
					"at least 3 points", #polygon)
			end
			for point_index = 1, #polygon do
				if not point_record(polygon[point_index]) then
					violation("invalid_point", "housing_masks", row.id,
						"integer x/z", ("#%d"):format(point_index))
				end
			end
		end
	end
	result.metrics.counts.coastal_housing_cores = #coastal
	if #coastal ~= #COASTAL_CORES then
		violation("count_mismatch", "coastal_housing_cores", "",
			#COASTAL_CORES, #coastal)
	end
	for index = 1, #COASTAL_CORES do
		local expected, row = COASTAL_CORES[index], coastal[index]
		if type(row) ~= "table" then
			violation("roster_mismatch", "coastal_housing_cores",
				("#%d"):format(index), expected[1], nil)
		else
			local checks = {
				{"id",expected[1]}, {"zone_numeric_id",expected[2]},
				{"housing_mask_id",expected[3]}, {"landmark_id",expected[4]},
				{"shape","vertical_capsule_v1"},
				{"frontage_min",600}, {"inland_depth_min",300}, {"relief_max",12},
			}
			for check_index = 1, #checks do
				local check = checks[check_index]
				if row[check[1]] ~= check[2] then
					violation("coastal_core_mismatch", "coastal_housing_cores",
						row.id or ("#%d"):format(index), check[2], row[check[1]])
				end
			end
			if not mask_by_id[row.housing_mask_id] then
				violation("missing_reference", "coastal_housing_cores", row.id,
					"housing mask", row.housing_mask_id)
			end
			if not landmark_by_id[row.landmark_id] then
				violation("missing_reference", "coastal_housing_cores", row.id,
					"landmark", row.landmark_id)
			end
		end
	end
	local coastal_session_ready = type(session) == "table" and
		type(session.classification_values_at) == "function" and
		type(session.coastal_core_member) == "function" and
		type(session.static_exclusion_values_at) == "function" and
		type(session.housing_point_valid_for_mask) == "function"
	if not coastal_session_ready then
		violation("missing_session_api", "coastal_housing_cores", "",
			"classification/core/exclusion/housing queries", "missing")
	end
	if coastal_session_ready then
		for index = 1, #coastal do
			local core = coastal[index]
			local landmark = type(core) == "table" and
				landmark_by_id[core.landmark_id] or nil
			if landmark and landmark.primitive == "rectangle" then
				local min_x = landmark.center.x - landmark.radius_x
				local max_x = landmark.center.x + landmark.radius_x - 1
				local min_z = landmark.center.z - landmark.radius_z
				local max_z = landmark.center.z + landmark.radius_z - 1
				local bounding_nodes = (max_x-min_x+1)*(max_z-min_z+1)
				local shape_nodes=0
				local land_nodes,owner_nodes,exclusion_free_nodes,eligible_nodes=0,0,0,0
				for z=min_z,max_z do
					for x=min_x,max_x do
						if session.coastal_core_member(core.id,x,z) then
							shape_nodes=shape_nodes+1
							local water_class,_,owner=
								session.classification_values_at(x,z)
							if water_class == "land" then land_nodes=land_nodes+1 end
							if owner == core.zone_numeric_id then owner_nodes=owner_nodes+1 end
							if session.static_exclusion_values_at(x,z) == nil then
								exclusion_free_nodes=exclusion_free_nodes+1
							end
							if session.housing_point_valid_for_mask(
									core.housing_mask_id,x,z) then
								eligible_nodes=eligible_nodes+1
							end
						end
					end
				end
				local width=max_x-min_x+1
				local frontage=max_z-min_z+1
				local reservation_centers=0
				for z=min_z+50,max_z-50 do
					for x=min_x+50,max_x-50 do
						if session.coastal_core_member(core.id,x-50,z-50) and
								session.coastal_core_member(core.id,x+50,z-50) and
								session.coastal_core_member(core.id,x-50,z+50) and
								session.coastal_core_member(core.id,x+50,z+50) then
							reservation_centers=reservation_centers+1
						end
					end
				end
				result.coastal_cores[#result.coastal_cores+1]={
					id=core.id,zone_numeric_id=core.zone_numeric_id,
					min_x=min_x,max_x=max_x,min_z=min_z,max_z=max_z,
					inland_depth=width,frontage=frontage,
					bounding_nodes=bounding_nodes,shape_nodes=shape_nodes,
					land_nodes=land_nodes,owner_nodes=owner_nodes,
					exclusion_free_nodes=exclusion_free_nodes,
					eligible_nodes=eligible_nodes,
					wholly_contained_reservation_centers=reservation_centers,
				}
				if width < core.inland_depth_min or frontage < core.frontage_min then
					violation("coastal_core_dimensions_below_minimum",
						"coastal_housing_cores",core.id,
						("%dx%d"):format(core.inland_depth_min,core.frontage_min),
						("%dx%d"):format(width,frontage))
				end
				if shape_nodes == 0 or reservation_centers == 0 or
						land_nodes ~= shape_nodes or owner_nodes ~= shape_nodes or
						exclusion_free_nodes ~= shape_nodes or
						eligible_nodes ~= shape_nodes then
					violation("coastal_core_not_fully_realized",
						"coastal_housing_cores",core.id,shape_nodes,
						("land=%d owner=%d clear=%d eligible=%d centers=%d"):format(
							land_nodes,owner_nodes,exclusion_free_nodes,eligible_nodes,
							reservation_centers))
				end
			end
		end
	end

	-- Anchor metadata and ownership use the production session API.
	local anchors = records(source.anchors)
	local anchor_by_id = id_index(anchors, "anchors")
	result.metrics.counts.anchors = #anchors
	local authored_fixed_count, layout_fixed_count = 0, 0
	local fixed_template_by_index = {
		[1]="start", [2]="start", [3]="start", [4]="start", [5]="start",
		[6]="start", [7]="capital_dwarf", [8]="capital_human",
		[9]="capital_elf", [10]="capital_undead", [11]="capital_orc",
		[12]="capital_troll", [87]="dragon", [88]="dragon",
		[89]="apex_mine", [90]="apex_mine",
	}
	local can_query_ownership = type(session) == "table" and
		type(session.id_at) == "function" and
		type(session.selected_anchor_by_id) == "function"
	if not can_query_ownership then
		violation("missing_session_api", "anchor_ownership", "",
			"id_at and selected_anchor_by_id", nil)
	end
	local function check_owner(anchor, point)
		if not point_record(point) then
			violation("invalid_point", "anchors", anchor.id, "integer x/z", nil)
			return
		end
		local zone = zones[anchor.zone_numeric_id]
		local expected = type(zone) == "table" and zone.id or nil
		if not expected then
			violation("missing_reference", "anchors", anchor.id, "zone",
				anchor.zone_numeric_id)
			return
		end
		if can_query_ownership then
			local called, actual = pcall(session.id_at, point.x, point.z)
			if not called then actual = "<id_at error>" end
			if actual ~= expected then
				violation("center_owner_mismatch", "anchor_ownership", anchor.id,
					expected, actual)
				witness("center_owner_mismatch", "anchor_ownership", anchor.id, {
					{"approved_candidate_index",anchor.approved_candidate_index},
					{"x",point.x}, {"z",point.z},
					{"expected_zone",expected}, {"actual_zone",actual},
				})
			end
			local selected = session.selected_anchor_by_id(anchor.id)
			local expected_selection_mode =
				anchor.placement_mode == "authored_fixed" and
				"authored_fixed" or "frozen_layout"
			local field_count, field_roster_ok = 0, true
			local expected_fields = {x=true,z=true,anchor_id=true,
				selection_mode=true,approved_candidate_index=true}
			if type(selected) == "table" then
				for key in pairs(selected) do
					field_count = field_count + 1
					if not expected_fields[key] then field_roster_ok = false end
				end
			end
			if type(selected) ~= "table" or field_count ~= 5 or
					not field_roster_ok or selected.x ~= point.x or
					selected.z ~= point.z or selected.anchor_id ~= anchor.id or
					selected.selection_mode ~= expected_selection_mode or
					selected.approved_candidate_index ~=
						anchor.approved_candidate_index then
				violation("selected_anchor_mismatch", "anchor_ownership", anchor.id,
					"exact defensive fixed-layout result", "mismatch")
			end
		end
	end
	for index = 1, #anchors do
		local row = anchors[index]
		if type(row) == "table" then
			if row.numeric_id ~= index or row.id ~= ("anchor_%03d"):format(index) then
				violation("numeric_id_mismatch", "anchors", row.id, index,
					row.numeric_id)
			end
			if not anchor_profile_by_id[row.template_id] then
				violation("missing_reference", "anchor_templates", row.id,
					"anchor profile", row.template_id)
			end
			local expected_template = fixed_template_by_index[index]
			local expected_mode = expected_template and "authored_fixed" or
				"layout_fixed"
			if row.placement_mode ~= expected_mode then
				violation("authored_mode_mismatch", "anchors", row.id,
					expected_mode, row.placement_mode)
			end
			if expected_template and row.template_id ~= expected_template then
				violation("authored_template_mismatch", "anchors", row.id,
					expected_template, row.template_id)
			end
			if index <= 6 and row.slot_id ~= "start" then
				violation("authored_slot_mismatch", "anchors", row.id, "start",
					row.slot_id)
			elseif index >= 7 and index <= 12 and row.slot_id ~= "capital" then
				violation("authored_slot_mismatch", "anchors", row.id, "capital",
					row.slot_id)
			end
			if row.placement_mode == "authored_fixed" then
				authored_fixed_count = authored_fixed_count + 1
				result.metrics.ownership.authored_fixed_centers_checked =
					result.metrics.ownership.authored_fixed_centers_checked + 1
				if row.approved_candidate_index ~= 0 then
					violation("anchor_provenance_mismatch", "anchors", row.id, 0,
						row.approved_candidate_index)
				end
			elseif row.placement_mode == "layout_fixed" then
				layout_fixed_count = layout_fixed_count + 1
				result.metrics.ownership.layout_fixed_centers_checked =
					result.metrics.ownership.layout_fixed_centers_checked + 1
				if not integer(row.approved_candidate_index) or
						row.approved_candidate_index < 1 or
						row.approved_candidate_index > 3 then
					violation("anchor_provenance_mismatch", "anchors", row.id,
						"integer 1..3", row.approved_candidate_index)
				end
			else
				violation("placement_mode_invalid", "anchors", row.id,
					"authored_fixed/layout_fixed", row.placement_mode)
			end
			if not point_record(row.position) or row.candidates ~= nil then
				violation("placement_shape_mismatch", "anchors", row.id,
					"one position and no candidate array", "mismatch")
			else
				check_owner(row, row.position)
			end
		end
	end
	result.metrics.counts.authored_fixed_anchors = authored_fixed_count
	result.metrics.counts.layout_fixed_anchors = layout_fixed_count
	if #anchors ~= 100 then violation("count_mismatch", "anchors", "", 100, #anchors) end
	if authored_fixed_count ~= 16 then
		violation("count_mismatch", "authored_fixed_anchors", "", 16,
			authored_fixed_count)
	end
	if layout_fixed_count ~= 84 then
		violation("count_mismatch", "layout_fixed_anchors", "", 84,
			layout_fixed_count)
	end

	-- Landmark and hydrology rosters carry stable IDs and cross references.
	local primitives = {ellipse=true, rectangle=true, capsule=true}
	local roles = {base_H=true, target_T=true, hydrology=true, route=true,
		interface=true, dressing=true}
	for index = 1, #landmarks do
		local row = landmarks[index]
		if type(row) == "table" then
			if row.numeric_id ~= index then
				violation("numeric_id_mismatch", "landmarks", row.id, index,
					row.numeric_id)
			end
			if not zones[row.zone_numeric_id] then
				violation("missing_reference", "landmarks", row.id, "zone",
					row.zone_numeric_id)
			end
			if not primitives[row.primitive] then
				violation("primitive_invalid", "landmarks", row.id,
					"ellipse/rectangle/capsule", row.primitive)
			end
			if not point_record(row.center) or not integer(row.radius_x) or
					not integer(row.radius_z) or row.radius_x <= 0 or row.radius_z <= 0 then
				violation("geometry_invalid", "landmarks", row.id,
					"integer center and positive radii", "invalid")
			end
			if not relief_by_id[row.secondary_relief_id] then
				violation("missing_reference", "landmark_relief", row.id,
					"relief profile", row.secondary_relief_id)
			end
			local row_roles, seen_roles = records(row.roles), {}
			if row_roles[1] ~= "base_H" or row_roles[#row_roles] ~= "dressing" then
				violation("role_envelope_mismatch", "landmarks", row.id,
					"base_H...dressing", "invalid")
			end
			for role_index = 1, #row_roles do
				local role = row_roles[role_index]
				if not roles[role] or seen_roles[role] then
					violation("role_invalid", "landmarks", row.id,
						"known unique role", role)
				end
				seen_roles[role] = true
			end
		end
	end

	for index = 1, #hydrology do
		local row = hydrology[index]
		if type(row) == "table" then
			if not landmark_by_id[row.landmark_id] then
				violation("missing_reference", "hydrology", row.id, "landmark",
					row.landmark_id)
			end
			if not zones[row.zone_numeric_id] then
				violation("missing_reference", "hydrology", row.id, "zone",
					row.zone_numeric_id)
			end
			if not hydro_profile_by_id[row.profile_id] then
				violation("missing_reference", "hydrology", row.id,
					"hydrology profile", row.profile_id)
			end
			if row.civic_core_zone_numeric_id ~= nil and
					not zones[row.civic_core_zone_numeric_id] then
				violation("missing_reference", "hydrology", row.id,
					"civic core zone", row.civic_core_zone_numeric_id)
			end
			if row.water_surface_reference ~= "mapgen_water_level" or
					row.water_node_semantic ~= "surface_water" or
					type(row.from_id) ~= "string" or type(row.to_id) ~= "string" then
				violation("horizontal_metadata_incomplete", "hydrology", row.id,
					"stable surface/endpoints", "invalid")
			end
			local centreline = records(row.centreline)
			if #centreline < 2 then
				violation("centreline_invalid", "hydrology", row.id,
					"at least 2 samples", #centreline)
			end
			for sample_index = 1, #centreline do
				local sample = centreline[sample_index]
				if not point_record(sample) or not integer(sample.half_width) or
						sample.half_width <= 0 then
					violation("centreline_sample_invalid", "hydrology", row.id,
						"integer x/z/positive width", sample_index)
				end
			end
		end
	end
	for index = 1, #hydro_interfaces do
		local row = hydro_interfaces[index]
		if type(row) == "table" then
			if not transition_by_id[row.transition_profile_id] then
				violation("missing_reference", "hydrology_interfaces", row.id,
					"transition profile", row.transition_profile_id)
			end
			if not point_record(row.position) or row.sealed ~= true then
				violation("interface_metadata_incomplete", "hydrology_interfaces",
					row.id, "integer position and sealed", "invalid")
			end
			local reach_refs = {}
			if row.hydrology_id then reach_refs[#reach_refs+1] = row.hydrology_id end
			if row.upper_id then reach_refs[#reach_refs+1] = row.upper_id end
			if row.lower_id then reach_refs[#reach_refs+1] = row.lower_id end
			if row.outgoing_reach_id then
				reach_refs[#reach_refs+1] = row.outgoing_reach_id
			end
			for from_index = 1, #records(row.from_ids) do
				reach_refs[#reach_refs+1] = row.from_ids[from_index]
			end
			for ref_index = 1, #reach_refs do
				if not hydro_by_id[reach_refs[ref_index]] then
					violation("missing_reference", "hydrology_interfaces", row.id,
						"hydrology reach", reach_refs[ref_index])
				end
			end
			if row.route_interface_id and not crossing_by_id[row.route_interface_id] then
				violation("missing_reference", "hydrology_interfaces", row.id,
					"route interface", row.route_interface_id)
			end
			if row.plunge_profile_id and
					not hydro_profile_by_id[row.plunge_profile_id] then
				violation("missing_reference", "hydrology_interfaces", row.id,
					"plunge profile", row.plunge_profile_id)
			end
		end
	end

	-- Every hard feature and every static claimable alternative has coverage.
	local hard_recipes = records(source.hard_protection_recipes)
	local hard = records(source.hard_protection)
	local ingresses = records(source.capital_ingresses)
	local sockets = records(source.apex_sockets)
	local routes = records(source.routes)
	local route_by_id = id_index(routes, "routes")
	local ingress_by_id = id_index(ingresses, "capital_ingresses")
	local socket_by_id = id_index(sockets, "apex_sockets")
	validate_roster(hard_recipes, HARD_RECIPE_IDS, "hard_protection_recipes")
	local hard_recipe_by_id = id_index(hard_recipes, "hard_protection_recipes")
	local hard_by_id = id_index(hard, "hard_protection")
	result.metrics.counts.hard_protection = #hard
	if #hard ~= 42 then
		violation("count_mismatch", "hard_protection", "", 42, #hard)
	end
	local hard_recipe_counts = {}
	if #ingresses ~= 6 then
		violation("count_mismatch", "capital_ingresses", "", 6, #ingresses)
	end
	for index = 1, #ingresses do
		local ingress = ingresses[index]
		if type(ingress) == "table" then
			local anchor = anchor_by_id[ingress.capital_anchor_id]
			if not anchor or anchor.slot_id ~= "capital" then
				violation("missing_reference", "capital_ingresses", ingress.id,
					"capital anchor", ingress.capital_anchor_id)
			end
			local route_ids = records(ingress.route_ids)
			if #route_ids ~= 2 or ingress.total_width ~= 128 then
				violation("ingress_metadata_mismatch", "capital_ingresses",
					ingress.id, "2 routes/width 128", "invalid")
			end
			for route_index = 1, #route_ids do
				if not route_by_id[route_ids[route_index]] then
					violation("missing_reference", "capital_ingresses", ingress.id,
						"route", route_ids[route_index])
				end
			end
		end
	end
	if #sockets ~= 24 then
		violation("count_mismatch", "apex_sockets", "", 24, #sockets)
	end
	for index = 1, #sockets do
		local socket = sockets[index]
		if type(socket) == "table" then
			local anchor = anchor_by_id[socket.anchor_id]
			if not anchor or anchor.template_id ~= "apex_mine" then
				violation("missing_reference", "apex_sockets", socket.id,
					"apex-mine anchor", socket.anchor_id)
			end
			if type(socket.species) ~= "string" or socket.species == "" or
					not point_record(socket.offset) then
				violation("socket_metadata_incomplete", "apex_sockets", socket.id,
					"species and integer offset", "invalid")
			end
		end
	end
	for index = 1, #hard do
		local row = hard[index]
		if type(row) == "table" then
			hard_recipe_counts[row.recipe_id] =
				(hard_recipe_counts[row.recipe_id] or 0) + 1
			if not hard_recipe_by_id[row.recipe_id] then
				violation("missing_reference", "hard_protection", row.id,
					"hard recipe", row.recipe_id)
			end
			if not anchor_by_id[row.source_anchor_id] then
				violation("missing_reference", "hard_protection", row.id,
					"anchor", row.source_anchor_id)
			end
			if row.ingress_id and not ingress_by_id[row.ingress_id] then
				violation("missing_reference", "hard_protection", row.id,
					"capital ingress", row.ingress_id)
			end
			if row.socket_id and not socket_by_id[row.socket_id] then
				violation("missing_reference", "hard_protection", row.id,
					"apex socket", row.socket_id)
			end
			if row.active ~= true or row.activation_owner ~= "WP40" or
					row.status ~= "active" then
				violation("activation_metadata_incomplete", "hard_protection",
					row.id, "active/WP40/active", "invalid")
			end
		end
	end
	local expected_hard_counts = {
		{"hard_start_core_v1",6}, {"hard_capital_build_plus_apron_v1",6},
		{"hard_capital_ingress_corridor_v1",6},
		{"hard_apex_socket_column_v1",24},
	}
	for index = 1, #expected_hard_counts do
		local expected = expected_hard_counts[index]
		if (hard_recipe_counts[expected[1]] or 0) ~= expected[2] then
			violation("coverage_count_mismatch", "hard_protection", expected[1],
				expected[2], hard_recipe_counts[expected[1]] or 0)
		end
	end
	for index = 1, 12 do
		local anchor = anchors[index]
		local id = type(anchor) == "table" and "hard:" .. anchor.id or ""
		local row = hard_by_id[id]
		local expected_recipe = index <= 6 and "hard_start_core_v1" or
			"hard_capital_build_plus_apron_v1"
		if id == "" or not row then
			violation("coverage_missing", "hard_protection", id,
				"start/capital footprint", "missing")
		elseif row.recipe_id ~= expected_recipe or not point_record(row.center) or
				row.center.x ~= anchor.position.x or row.center.z ~= anchor.position.z then
			violation("coverage_mismatch", "hard_protection", id,
				"exact start/capital footprint", "invalid")
		end
	end
	for index = 1, #ingresses do
		local ingress = ingresses[index]
		local id = type(ingress) == "table" and "hard:" .. ingress.id or ""
		local row = hard_by_id[id]
		if id == "" or not row then
			violation("coverage_missing", "hard_protection", id,
				"capital ingress footprint", "missing")
		elseif row.recipe_id ~= "hard_capital_ingress_corridor_v1" or
				row.ingress_id ~= ingress.id then
			violation("coverage_mismatch", "hard_protection", id,
				"exact capital ingress footprint", "invalid")
		end
	end
	for index = 1, #sockets do
		local socket = sockets[index]
		local id = type(socket) == "table" and "hard:" .. socket.id or ""
		local row = hard_by_id[id]
		local anchor = type(socket) == "table" and
			anchor_by_id[socket.anchor_id] or nil
		if id == "" or not row then
			violation("coverage_missing", "hard_protection", id,
				"apex socket footprint", "missing")
		elseif row.recipe_id ~= "hard_apex_socket_column_v1" or
				row.socket_id ~= socket.id or row.resource_key ~= socket.species or
				not point_record(row.center) or not anchor or
				row.center.x ~= anchor.position.x + socket.offset.x or
				row.center.z ~= anchor.position.z + socket.offset.z then
			violation("coverage_mismatch", "hard_protection", id,
				"exact apex socket footprint", "invalid")
		end
	end

	local claim_recipes = records(source.claim_exclusion_recipes)
	local claims = records(source.claim_exclusions)
	validate_roster(claim_recipes, CLAIM_RECIPE_IDS, "claim_exclusion_recipes")
	local claim_recipe_by_id = id_index(claim_recipes,
		"claim_exclusion_recipes")
	local claim_by_id = id_index(claims, "claim_exclusions")
	result.metrics.counts.claim_exclusions = #claims
	if #claims ~= 314 then
		violation("count_mismatch", "claim_exclusions", "", 314, #claims)
	end
	local claim_recipe_counts = {}
	for index = 1, #claims do
		local row = claims[index]
		if type(row) == "table" then
			claim_recipe_counts[row.recipe_id] =
				(claim_recipe_counts[row.recipe_id] or 0) + 1
			if not claim_recipe_by_id[row.recipe_id] then
				violation("missing_reference", "claim_exclusions", row.id,
					"claim recipe", row.recipe_id)
			end
		end
	end
	local expected_claim_counts = {
		{"exclude_anchor_blend_v1",100}, {"exclude_route_corridor_v1",139},
		{"exclude_planned_water_v1",29}, {"exclude_coast_v1",4},
		{"exclude_active_core_v1",42},
	}
	for index = 1, #expected_claim_counts do
		local expected = expected_claim_counts[index]
		if (claim_recipe_counts[expected[1]] or 0) ~= expected[2] then
			violation("coverage_count_mismatch", "claim_exclusions", expected[1],
				expected[2], claim_recipe_counts[expected[1]] or 0)
		end
	end
	for anchor_index = 1, #anchors do
		local anchor = anchors[anchor_index]
		if type(anchor) == "table" then
			local profile = anchor_profile_by_id[anchor.template_id]
			local identity_index = anchor.placement_mode == "authored_fixed" and 1 or
				anchor.approved_candidate_index
			local id = ("exclude:anchor:%s:%02d"):format(anchor.id,
				identity_index)
			local claim = claim_by_id[id]
			if not claim then
				violation("coverage_missing", "claim_exclusions", id,
					"actual anchor position", "missing")
			elseif claim.recipe_id ~= "exclude_anchor_blend_v1" or
					claim.source_id ~= anchor.id or
					not point_record(claim.center) or
					claim.center.x ~= anchor.position.x or
					claim.center.z ~= anchor.position.z or
					(type(profile) == "table" and
						claim.total_width ~= profile.blend_width) then
				violation("coverage_mismatch", "claim_exclusions", id,
					"exact actual-anchor blend envelope", "invalid")
			end
		end
	end
	local function require_claims(values, prefix, recipe, coverage)
		for index = 1, #values do
			local row = values[index]
			if type(row) == "table" then
				local id = prefix .. row.id
				local claim = claim_by_id[id]
				if not claim then
					violation("coverage_missing", "claim_exclusions", id,
						coverage, "missing")
				elseif claim.recipe_id ~= recipe or claim.source_id ~= row.id then
					violation("coverage_mismatch", "claim_exclusions", id,
						coverage, "invalid")
				end
			end
		end
	end
	require_claims(routes, "exclude:route:",
		"exclude_route_corridor_v1", "route corridor")
	require_claims(records(source.island_routes), "exclude:route:",
		"exclude_route_corridor_v1", "island-route corridor")
	require_claims(records(source.poi_spurs), "exclude:route:",
		"exclude_route_corridor_v1", "single-centreline spur corridor")
	require_claims(hydrology, "exclude:water:", "exclude_planned_water_v1",
		"hydrology mask")
	require_claims(records(source.bays), "exclude:water:",
		"exclude_planned_water_v1", "bay mask")
	require_claims(records(source.islands), "exclude:coast:",
		"exclude_coast_v1", "island coast")
	require_claims(records(source.channels), "exclude:coast:",
		"exclude_coast_v1", "channel coast")
	require_claims(hard, "exclude:active:", "exclude_active_core_v1",
		"active hard footprint")

	-- A record-level geometry projection proves the two ordinary mainlands are
	-- not an accidental reflection. It compares authored numbers only.
	local function primitive_token(row, reflect_z)
		local function z(value)
			if reflect_z and type(value) == "number" then return -value end
			return value
		end
		if row.kind == "capsule" then
			return table.concat({"capsule",number_token(row.a and row.a.x),
				number_token(z(row.a and row.a.z)),number_token(row.b and row.b.x),
				number_token(z(row.b and row.b.z)),number_token(row.radius)}, ":")
		elseif row.kind == "ellipse" then
			return table.concat({"ellipse",number_token(row.center and row.center.x),
				number_token(z(row.center and row.center.z)),number_token(row.radius_x),
				number_token(row.radius_z)}, ":")
		elseif row.kind == "rounded_rect" then
			local min_z, max_z = row.min_z, row.max_z
			if reflect_z and type(min_z) == "number" and type(max_z) == "number" then
				min_z, max_z = -max_z, -min_z
			end
			return table.concat({"rounded_rect",number_token(row.min_x),
				number_token(row.max_x),number_token(min_z),number_token(max_z),
				number_token(row.radius)}, ":")
		end
		return "invalid"
	end
	local function bay_token(row, reflect_z)
		local parts = {"bay",number_token(reflect_z and -row.deep_ocean_cut_z or
			row.deep_ocean_cut_z)}
		for index = 1, #records(row.centreline) do
			local point = row.centreline[index]
			parts[#parts+1] = table.concat({number_token(point.x),
				number_token(reflect_z and -point.z or point.z),
				number_token(point.half_width)}, ",")
		end
		return table.concat(parts, ":")
	end
	local elandor, kragmar = {}, {}
	for index = 1, #records(source.land_primitives) do
		local row = source.land_primitives[index]
		if type(row) == "table" and row.region == "elandor_mainland" then
			elandor[#elandor+1] = primitive_token(row, true)
		elseif type(row) == "table" and row.region == "kragmar_mainland" then
			kragmar[#kragmar+1] = primitive_token(row, false)
		end
	end
	for index = 1, #records(source.bays) do
		local row = source.bays[index]
		if type(row) == "table" and row.region == "elandor_mainland" then
			elandor[#elandor+1] = bay_token(row, true)
		elseif type(row) == "table" and row.region == "kragmar_mainland" then
			kragmar[#kragmar+1] = bay_token(row, false)
		end
	end
	local first_difference
	local maximum = math.max(#elandor, #kragmar)
	for index = 1, maximum do
		if elandor[index] ~= kragmar[index] then
			first_difference = index
			break
		end
	end
	local identical = #elandor == #kragmar and first_difference == nil
	result.metrics.reflection_projection = {
		family = "ordinary_land_primitives_and_bays",
		elandor_records = #elandor,
		kragmar_records = #kragmar,
		identical = identical,
		first_difference_index = first_difference or 0,
	}
	if #elandor ~= 9 or #kragmar ~= 9 then
		violation("projection_roster_mismatch", "reflection_projection", "", 9,
			("%d/%d"):format(#elandor,#kragmar))
	end
	if identical then
		violation("reflected_geometry_identical", "reflection_projection", "",
			"nonidentical", "identical")
	else
		witness("reflected_geometry_nonidentity", "reflection_projection",
			("#%d"):format(first_difference), {
				{"elandor_reflected",elandor[first_difference]},
				{"kragmar",kragmar[first_difference]},
			})
	end

	for index = 1, #DEFERRED_R3 do
		result.metrics.deferred_r3[index] = {
			id = DEFERRED_R3[index],
			status = "deferred_to_R3_vertical_validation",
		}
	end
	result.metrics.deferred_r3_count = #DEFERRED_R3
	result.ok = #result.violations == 0
	return result
end
