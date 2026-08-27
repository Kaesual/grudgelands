-- Exhaustive and targeted gates for the WP40 simple-map R3 height session.

return function(common)
	local validator = {}
	local Q = 65536
	local ALLOWED_FUNCTIONAL = {
		land_grade = true,
		anchor_platform = true,
		causeway = true,
		ford = true,
		bridge_deck = true,
		tunnel_floor = true,
	}
	local ALLOWED_TRANSITIONS = {rapid = true, waterfall = true}
	local BASELINE_DIAGNOSIS_PAIRS = {
		{"island_route_stormscale_junction_apex", "poi_spur_086"},
		{"poi_spur_013", "route_001"},
		{"poi_spur_023", "route_016"},
		{"poi_spur_025", "route_001"},
		{"poi_spur_029", "poi_spur_051"},
		{"poi_spur_036", "route_048"},
		{"poi_spur_045", "route_016"},
		{"poi_spur_050", "route_043"},
		{"poi_spur_060", "route_054"},
		{"poi_spur_069", "route_010"},
		{"poi_spur_077", "route_055"},
		{"poi_spur_081", "route_052"},
		{"route_051", "route_056"},
		{"route_052", "route_056"},
	}
	local DIAGNOSIS_FIELDS = {
		"losing_path_id", "losing_run", "from_x", "from_z", "from_y",
		"to_x", "to_z", "to_y", "absolute_step", "winner_path_id",
		"winner_run", "winner_x", "winner_z", "pair_a", "pair_b",
	}
	local DIAGNOSIS_SORT_FIELDS = {
		"losing_path_id", "losing_run", "from_x", "from_z", "to_x",
		"to_z", "winner_path_id", "winner_run", "winner_x", "winner_z",
	}
	local CONTACT_FACE_SCOPE = "orthogonal_reach_contact_face_v1"
	local CONTACT_FACE_EXPECTED = {
		{
			id = "highcourt_goldmead_fall",
			upper_id = "hydro_highcourt_fork_west",
			lower_id = "hydro_goldmead_millriver",
			upper_landmark_id = "highcourt_riverfork",
			lower_landmark_id = "goldmead_millriver",
			upper_offset = 34, lower_offset = 16, drop = 18,
			position_x = -100, position_z = -1780,
			lip_id = "highcourt_goldmead_lip",
			drop_id = "highcourt_goldmead_drop",
			plunge_id = "highcourt_goldmead_plunge",
			plunge_profile_id = "river",
			contact_edge_count = 13, upper_lip_count = 13,
			lower_face_count = 13,
			first_upper_x = -106, first_upper_z = -1756,
			first_lower_x = -106, first_lower_z = -1757,
			upper_min_x = -106, upper_max_x = -94,
			upper_min_z = -1756, upper_max_z = -1756,
			lower_min_x = -106, lower_max_x = -94,
			lower_min_z = -1757, lower_max_z = -1757,
		},
		{
			id = "gravesalt_broken_fall",
			upper_id = "hydro_gravesalt_pans",
			lower_id = "hydro_broken_marsh",
			upper_landmark_id = "gravesalt_whitewall",
			lower_landmark_id = "broken_marsh",
			upper_offset = 100, lower_offset = 8, drop = 92,
			position_x = -1700, position_z = 80,
			lip_id = "gravesalt_broken_lip",
			drop_id = "gravesalt_broken_drop",
			plunge_id = "gravesalt_broken_plunge",
			plunge_profile_id = "ordinary_lake",
			contact_edge_count = 163, upper_lip_count = 114,
			lower_face_count = 114,
			first_upper_x = -1713, first_upper_z = 21,
			first_lower_x = -1712, first_lower_z = 21,
			upper_min_x = -1713, upper_max_x = -1650,
			upper_min_z = 21, upper_max_z = 110,
			lower_min_x = -1712, lower_max_x = -1649,
			lower_min_z = 21, lower_max_z = 110,
		},
		{
			id = "raincall_reedmaze_fall",
			upper_id = "hydro_raincall_plunge",
			lower_id = "hydro_whispering_reedmaze",
			upper_landmark_id = "raincall_falls",
			lower_landmark_id = "whispering_reedmaze",
			upper_offset = 44, lower_offset = 8, drop = 36,
			position_x = 2100, position_z = 1900,
			lip_id = "raincall_reedmaze_lip",
			drop_id = "raincall_reedmaze_drop",
			plunge_id = "raincall_reedmaze_plunge",
			plunge_profile_id = "shallow_marsh",
			contact_edge_count = 109, upper_lip_count = 66,
			lower_face_count = 65,
			first_upper_x = 2070, first_upper_z = 1864,
			first_lower_x = 2069, first_lower_z = 1864,
			upper_min_x = 2026, upper_max_x = 2070,
			upper_min_z = 1864, upper_max_z = 1929,
			lower_min_x = 2026, lower_max_x = 2069,
			lower_min_z = 1864, lower_max_z = 1928,
		},
	}
	local WET_REACH_CONTACT_EXPECTED = {
		{"hydro_gravesalt_pans", "hydro_broken_marsh", 100, 8,
			"gravesalt_broken_fall", 163, 114, 114},
		{"hydro_highcourt_fork_east", "hydro_highcourt_fork_west", 34, 34,
			nil, 75, 50, 50},
		{"hydro_highcourt_fork_east", "hydro_highcourt_outflow", 34, 34,
			nil, 17, 9, 9},
		{"hydro_highcourt_fork_west", "hydro_goldmead_millriver", 34, 16,
			"highcourt_goldmead_fall", 13, 13, 13},
		{"hydro_highcourt_fork_west", "hydro_highcourt_outflow", 34, 34,
			nil, 62, 40, 41},
		{"hydro_raincall_headwater", "hydro_raincall_upper_lip", 72, 68,
			"raincall_upper_rapid", 136, 99, 99},
		{"hydro_raincall_middle_lip", "hydro_raincall_plunge", 52, 44,
			"raincall_lower_fall", 125, 82, 83},
		{"hydro_raincall_middle_upper", "hydro_raincall_middle_lip", 56, 52,
			"raincall_middle_rapid", 122, 86, 87},
		{"hydro_raincall_plunge", "hydro_whispering_reedmaze", 44, 8,
			"raincall_reedmaze_fall", 109, 66, 65},
		{"hydro_raincall_upper_lip", "hydro_raincall_middle_upper", 68, 56,
			"raincall_upper_fall", 90, 61, 61},
		{"hydro_totemwater_delta", "hydro_whispering_reedmaze", 8, 8,
			nil, 151, 107, 107},
		{"hydro_whitebridge_ford", "hydro_whitebridge_main", 16, 16,
			nil, 73, 60, 61},
	}
	local LEGACY_RAINCALL_TRANSITIONS = {
		raincall_upper_rapid = true, raincall_upper_fall = true,
		raincall_middle_rapid = true, raincall_lower_fall = true,
	}
	local validated_raw_sha256

	local function fail(message)
		error("WP40 simple-map R3 validation: " .. message, 0)
	end

	local function method(value, name)
		if type(value[name]) ~= "function" then fail("session." .. name .. " missing") end
	end

	local function clearance_at(session, x, z)
		local water = session.water_surface_at(x, z)
		if water ~= nil then
			common.safe_integer(water, "water clearance datum")
			return water, false
		end
		local kind, _, upper, lower =
			session.hydrology_transition_values_at(x, z)
		if kind ~= "waterfall" then
			fail("planned-water column has no scalar water or waterfall datum at " ..
				tostring(x) .. "," .. tostring(z))
		end
		common.safe_integer(upper, "waterfall clearance upper y")
		common.safe_integer(lower, "waterfall clearance lower y")
		return math.max(upper, lower), true
	end

	local function exact_copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[exact_copy(key)] = exact_copy(child) end
		return result
	end

	local function normalized_evidence_bytes(evidence)
		local builder = common.new_tsv()
		common.add_evidence(builder, evidence)
		return builder.body()
	end

	local function row_id(row)
		return row.id or row.profile_id or row.anchor_id or row.interface_id or
			row.feature_id or row.core_id
	end

	local function require_array(evidence, name, count)
		local value = evidence[name]
		local actual = common.dense_count(value, "artifact evidence " .. name)
		if count and actual ~= count then
			fail(name .. " count differs: expected " .. count .. ", got " .. actual)
		end
		return value
	end

	local function require_id_coverage(rows, expected, label)
		local found = {}
		for index = 1, #rows do
			local id = row_id(rows[index])
			if type(id) ~= "string" or id == "" then fail(label .. " row has no id") end
			if found[id] then fail(label .. " has duplicate id " .. id) end
			found[id] = true
		end
		for index = 1, #expected do
			if not found[expected[index].id] then
				fail(label .. " evidence misses " .. expected[index].id)
			end
		end
	end

	local function check_digest_fields(value, path)
		if type(value) ~= "table" then return end
		for key, child in pairs(value) do
			local child_path = path .. "." .. tostring(key)
			if type(key) == "string" and
					(key == "digest" or key:match("_digest$") or key:match("_sha256$")) then
				common.digest(child, child_path)
			elseif type(child) == "table" then
				check_digest_fields(child, child_path)
			end
		end
	end

	local function check_zero_violation_fields(value, path)
		if type(value) ~= "table" then return end
		for key, child in pairs(value) do
			local child_path = path .. "." .. tostring(key)
			if type(child) == "table" then
				check_zero_violation_fields(child, child_path)
			elseif type(key) == "string" and type(child) == "number" and
					(key:match("_violations$") or key:match("_failures$") or
					key:match("_escapes$") or key == "rejected_anchors" or
					key == "reselected_anchors" or key == "unsafe_integers") then
				common.safe_integer(child, child_path)
				if child ~= 0 then fail(child_path .. " is not zero") end
			end
		end
	end

	local function maps_by_id(rows)
		local result = {}
		for index = 1, #rows do result[rows[index].id] = rows[index] end
		return result
	end

	local function expected_paths(source)
		local result = {}
		for index = 1, #source.routes do result[#result + 1] = source.routes[index] end
		for index = 1, #source.poi_spurs do result[#result + 1] = source.poi_spurs[index] end
		for index = 1, #source.island_routes do
			result[#result + 1] = source.island_routes[index]
		end
		return result
	end

	local function integer_fields(row, fields, label)
		for index = 1, #fields do
			common.safe_integer(row[fields[index]], label .. " " .. fields[index])
		end
	end

	local function validate_station_anchor_evidence(session, source, evidence)
		if evidence.source_cut_fill_limits_consumed ~= false then
			fail("source max_cut/max_fill were not explicitly retired")
		end
		local profile_by_id = maps_by_id(source.relief_profiles)
		local station_rows = require_array(evidence, "stations", #source.route_stations)
		require_id_coverage(station_rows, source.route_stations, "stations")
		local station_by_zone = {}
		for index = 1, #station_rows do
			local row = station_rows[index]
			integer_fields(row, {"zone_numeric_id", "primary_min_above_water",
				"primary_max_above_water", "zone_station_y", "hub_x", "hub_z",
				"hub_target_y"}, "station")
			local zone = source.zones[row.zone_numeric_id]
			local station = source.route_stations[row.zone_numeric_id]
			local profile = zone and profile_by_id[zone.primary_relief_id] or nil
			if not zone or not station or not profile or row.id ~= station.id or
					station.zone_numeric_id ~= row.zone_numeric_id or
					row.primary_profile_id ~= profile.id or
					row.primary_min_above_water ~= profile.min_above_water or
					row.primary_max_above_water ~= profile.max_above_water or
					row.zone_station_y ~= common.WATER_LEVEL + profile.min_above_water or
					row.hub_x ~= zone.hub.x or row.hub_z ~= zone.hub.z or
					type(row.hub_water) ~= "boolean" then
				fail("station/reference rule differs at " .. tostring(row.id))
			end
			if station_by_zone[row.zone_numeric_id] then
				fail("duplicate station zone " .. row.zone_numeric_id)
			end
			station_by_zone[row.zone_numeric_id] = row
			if row.hub_water then
				if row.capital_anchor_id ~= nil then
					fail("capital hub is planned water at " .. row.id)
				end
				common.safe_integer(row.hub_clearance_y, "station hub clearance")
				if row.hub_target_y ~= math.max(row.zone_station_y,
						row.hub_clearance_y + 1) then
					fail("planned-water hub target differs at " .. row.id)
				end
			elseif row.hub_clearance_y ~= nil then
				fail("dry station carries a clearance datum at " .. row.id)
			elseif row.capital_anchor_id == nil and
					row.hub_target_y ~= row.zone_station_y then
				fail("dry non-capital hub target differs at " .. row.id)
			end
		end

		local anchors = require_array(evidence, "anchors", #source.anchors)
		require_id_coverage(anchors, source.anchors, "anchors")
		local anchor_profile_by_id = maps_by_id(source.anchor_profiles)
		local source_anchor_by_id = maps_by_id(source.anchors)
		local capital_by_zone = {}
		for index = 1, #source.anchors do
			local anchor = source.anchors[index]
			if anchor.slot_id == "capital" then capital_by_zone[anchor.zone_numeric_id] = anchor end
		end
		for index = 1, #anchors do
			local row = anchors[index]
			local source_anchor = assert(source_anchor_by_id[row_id(row)])
			local profile = assert(anchor_profile_by_id[source_anchor.template_id])
			local station = assert(station_by_zone[source_anchor.zone_numeric_id])
			integer_fields(row, {"reference_y", "profile_midpoint_y", "fitting_width",
				"blend_width", "collar_width", "fitting_columns", "collar_columns",
				"platform_columns", "owner_escape_columns", "observed_max_cut",
				"observed_max_cut_witness_x", "observed_max_cut_witness_z",
				"observed_max_fill", "observed_max_fill_witness_x",
				"observed_max_fill_witness_z", "civic_water_columns"}, "anchor")
			local midpoint = common.WATER_LEVEL + math.floor(
				(station.primary_min_above_water + station.primary_max_above_water) / 2)
			if row.profile_midpoint_y ~= midpoint or row.fitting_width ~= profile.fitting_width or
					row.blend_width ~= profile.blend_width or
					row.fitting_width <= 0 or row.fitting_width % 2 ~= 0 or
					row.blend_width <= row.fitting_width or row.blend_width % 2 ~= 0 or
					row.collar_width ~= (profile.blend_width - profile.fitting_width) / 2 or
					row.fitting_columns <= 0 or
					row.fitting_columns > profile.fitting_width * profile.fitting_width or
					row.collar_columns < 0 or
					row.collar_columns > (profile.blend_width - 2) *
						(profile.blend_width - 2) - row.fitting_columns or
					row.owner_escape_columns ~= 0 or row.observed_max_cut < 0 or
					row.observed_max_fill < 0 or row.rejected ~= false or
					row.reselected ~= false then
				fail("anchor fitting/reference evidence differs at " .. source_anchor.id)
			end
			local expected_rule, expected_reference
			if source_anchor.slot_id == "start" then
				expected_rule, expected_reference = "start_zone_station", station.zone_station_y
			elseif source_anchor.slot_id == "capital" then
				local selected = session.selected_anchor_3d_by_id(source_anchor.id)
				if not selected or session.water_surface_at(selected.x, selected.z) ~= nil or
						select(1, session.hydrology_transition_values_at(
							selected.x, selected.z)) == "waterfall" then
					fail("capital centre is planned water at " .. source_anchor.id)
				end
				if row.civic_water_columns == 0 then
					expected_rule, expected_reference = "capital_zone_station",
						station.zone_station_y
					if row.civic_max_clearance_y ~= nil or
							row.civic_max_clearance_witness_x ~= nil or
							row.civic_max_clearance_witness_z ~= nil then
						fail("empty capital civic-water set has a maximum")
					end
				else
					integer_fields(row, {"civic_max_clearance_y",
						"civic_max_clearance_witness_x", "civic_max_clearance_witness_z"},
						"capital civic water")
					expected_rule, expected_reference = "capital_civic_max",
						math.max(station.zone_station_y, row.civic_max_clearance_y + 1)
					if clearance_at(session, row.civic_max_clearance_witness_x,
							row.civic_max_clearance_witness_z) ~= row.civic_max_clearance_y then
						fail("capital civic-water maximum witness differs")
					end
				end
				if row.platform_columns ~= 0 then
					fail("capital received an anchor platform at " .. source_anchor.id)
				end
			else
				local selected = session.selected_anchor_3d_by_id(source_anchor.id)
				local datum
				if selected then
					local water = session.water_surface_at(selected.x, selected.z)
					if water ~= nil then datum = water
					else
						local transition, _, upper, lower =
							session.hydrology_transition_values_at(selected.x, selected.z)
						if transition == "waterfall" then datum = math.max(upper, lower) end
					end
				end
				if datum then
					expected_rule, expected_reference = "profile_midpoint_water_raise",
						math.max(midpoint, datum + 1)
				else expected_rule, expected_reference = "profile_midpoint", midpoint end
			end
			if row.reference_rule ~= expected_rule or row.reference_y ~= expected_reference then
				fail("anchor reference rule differs at " .. source_anchor.id)
			end
			if row.platform_columns > 0 then
				integer_fields(row, {"platform_witness_x", "platform_witness_z"},
					"anchor platform")
				local datum = clearance_at(session, row.platform_witness_x,
					row.platform_witness_z)
				local kind, surface, feature = session.functional_surface_values_at(
					row.platform_witness_x, row.platform_witness_z)
				if kind ~= "anchor_platform" or feature ~= source_anchor.id or
						surface ~= math.max(row.reference_y, datum + 1) or
						session.terrain_height_at(row.platform_witness_x,
							row.platform_witness_z) ~= surface then
					fail("non-capital water platform witness differs at " .. source_anchor.id)
				end
			end
		end
		for zone_id, anchor in pairs(capital_by_zone) do
			local station = assert(station_by_zone[zone_id])
			local anchor_row = maps_by_id(anchors)[anchor.id]
			if station.capital_anchor_id ~= anchor.id or
					station.hub_target_y ~= anchor_row.reference_y then
				fail("capital hub/reference link differs at " .. anchor.id)
			end
		end
		return anchors
	end

	local function validate_route_operation_evidence(session, source, evidence)
		local routes = require_array(evidence, "routes")
		local paths = expected_paths(source)
		if #routes ~= #paths then
			fail("routes count differs: expected " .. #paths .. ", got " .. #routes)
		end
		require_id_coverage(routes, paths, "routes")
		local route_by_id = maps_by_id(routes)
		local pin_count_by_path, lower_count_by_path = {}, {}
		local lower_columns_by_path, raise_count_by_path = {}, {}, {}
		for index = 1, #routes do
			local row = routes[index]
			integer_fields(row, {"node_count", "baseline_min_y", "baseline_max_y",
				"final_min_y", "final_max_y", "maximum_step", "exact_pin_count",
				"water_lower_bound_run_count", "water_lower_bound_column_count",
				"raised_run_count", "support_witness_count"}, "route")
			if row.node_count <= 1 or row.baseline_min_y > row.baseline_max_y or
					row.final_min_y > row.final_max_y or row.maximum_step < 0 or
					row.maximum_step > 1 or row.raised_run_count ~= row.support_witness_count then
				fail("route grade aggregate differs at " .. row.id)
			end
			for _, key in ipairs({"baseline_digest", "final_grade_digest",
				"exact_pin_digest", "lower_bound_digest", "classification_digest"}) do
				common.digest(row[key], "route " .. key)
			end
		end

		local pins = require_array(evidence, "route_exact_pins")
		local pin_key = {}
		for index = 1, #pins do
			local row = pins[index]
			integer_fields(row, {"run", "y", "baseline_y", "final_y"}, "route pin")
			if not route_by_id[row.path_id] or type(row.pin_kind) ~= "string" or
					type(row.source_id) ~= "string" or row.run < 1 or
					row.run > route_by_id[row.path_id].node_count or row.y ~= row.baseline_y or
					row.y ~= row.final_y then
				fail("exact route pin changed at " .. tostring(row.path_id))
			end
			local key = row.path_id .. ":" .. row.run
			if pin_key[key] then fail("duplicate exact route pin " .. key) end
			pin_key[key] = row
			pin_count_by_path[row.path_id] = (pin_count_by_path[row.path_id] or 0) + 1
		end
		local station_by_zone = {}
		for index = 1, #evidence.stations do
			station_by_zone[evidence.stations[index].zone_numeric_id] = evidence.stations[index]
		end
		local anchor_by_id = maps_by_id(evidence.anchors)
		local function exact_endpoint(path_id, run, kind, source_id, y)
			local pin = pin_key[path_id .. ":" .. run]
			if not pin or pin.pin_kind ~= kind or pin.source_id ~= source_id or pin.y ~= y then
				fail("route skeleton endpoint differs at " .. path_id .. ":" .. run)
			end
		end
		for index = 1, #source.routes do
			local path = source.routes[index]
			local row = assert(route_by_id[path.id])
			local station_a = assert(station_by_zone[path.zone_a])
			local station_b = assert(station_by_zone[path.zone_b])
			exact_endpoint(path.id, 1, "endpoint_a", source.zones[path.zone_a].id,
				station_a.hub_target_y)
			exact_endpoint(path.id, row.node_count, "endpoint_b",
				source.zones[path.zone_b].id, station_b.hub_target_y)
		end
		for index = 1, #source.poi_spurs do
			local path = source.poi_spurs[index]
			if path.anchor_id then
				local row = assert(route_by_id[path.id])
				local anchor = assert(anchor_by_id[path.anchor_id])
				local source_anchor
				for anchor_index = 1, #source.anchors do
					if source.anchors[anchor_index].id == path.anchor_id then
						source_anchor = source.anchors[anchor_index] break
					end
				end
				local station = assert(station_by_zone[source_anchor.zone_numeric_id])
				exact_endpoint(path.id, 1, "anchor_endpoint", path.anchor_id,
					anchor.reference_y)
				exact_endpoint(path.id, row.node_count, "station_endpoint",
					source.zones[source_anchor.zone_numeric_id].id, station.hub_target_y)
			end
		end
		local landing_at, fixed_anchor_at = {}, {}
		for index = 1, #source.island_landings do
			local landing = source.island_landings[index]
			landing_at[landing.position.x .. ":" .. landing.position.z] = landing
		end
		for index = 1, #source.anchors do
			local anchor = source.anchors[index]
			if anchor.position and (anchor.template_id == "dragon" or
					anchor.template_id == "apex_mine") then
				fixed_anchor_at[anchor.position.x .. ":" .. anchor.position.z] = anchor
			end
		end
		local function island_endpoint(path, point, run, owner)
			local key = point.x .. ":" .. point.z
			local landing = landing_at[key]
			if landing then
				exact_endpoint(path.id, run, "landing_endpoint", landing.id,
					common.WATER_LEVEL + 1)
				return
			end
			local anchor = fixed_anchor_at[key]
			if anchor then
				exact_endpoint(path.id, run, "island_anchor_endpoint", anchor.id,
					assert(anchor_by_id[anchor.id]).reference_y)
				return
			end
			exact_endpoint(path.id, run, "island_junction", source.zones[owner].id,
				assert(station_by_zone[owner]).zone_station_y)
		end
		for index = 1, #source.island_routes do
			local path = source.island_routes[index]
			local row = assert(route_by_id[path.id])
			local first_key = path.centreline[1].x .. ":" .. path.centreline[1].z
			local last_point = path.centreline[#path.centreline]
			local last_key = last_point.x .. ":" .. last_point.z
			local endpoint_source = landing_at[first_key] or fixed_anchor_at[first_key] or
				landing_at[last_key] or fixed_anchor_at[last_key]
			if not endpoint_source then
				fail("island route has no authoritative landing/anchor owner")
			end
			local owner = endpoint_source.zone_numeric_id
			island_endpoint(path, path.centreline[1], 1, owner)
			island_endpoint(path, last_point, row.node_count, owner)
		end

		local lower_bounds = require_array(evidence, "route_water_lower_bounds")
		local lower_key = {}
		for index = 1, #lower_bounds do
			local row = lower_bounds[index]
			integer_fields(row, {"run", "column_count", "lower_y", "witness_x",
				"witness_z"}, "route water lower bound")
			if not route_by_id[row.path_id] or row.run < 1 or
					row.run > route_by_id[row.path_id].node_count or row.column_count <= 0 or
					type(row.bound_kind) ~= "string" then
				fail("route water lower-bound row differs")
			end
			local key = row.path_id .. ":" .. row.run
			if lower_key[key] then fail("duplicate projected lower-bound run " .. key) end
			lower_key[key] = row
			local datum = clearance_at(session, row.witness_x, row.witness_z)
			local expected_lower
			if row.bound_kind == "ordinary_water" or row.bound_kind == "causeway" then
				expected_lower = datum + 1
			elseif row.bound_kind == "bridge_deck" then
				expected_lower = datum + 4
			elseif row.bound_kind == "ford" then
				expected_lower = datum - 1
			elseif row.bound_kind == "ford_approach" then
				expected_lower = row.lower_y
			else fail("unknown projected lower-bound kind " .. row.bound_kind) end
			if row.lower_y ~= expected_lower then
				fail("projected lower-bound witness differs at " .. key)
			end
			lower_count_by_path[row.path_id] =
				(lower_count_by_path[row.path_id] or 0) + 1
			lower_columns_by_path[row.path_id] =
				(lower_columns_by_path[row.path_id] or 0) + row.column_count
		end

		local raises = require_array(evidence, "route_raise_witnesses")
		local raise_key = {}
		for index = 1, #raises do
			local row = raises[index]
			integer_fields(row, {"run", "baseline_y", "final_y", "support_run",
				"support_lower_y", "support_x", "support_z"}, "route raise witness")
			local route = route_by_id[row.path_id]
			if not route or row.run < 1 or row.run > route.node_count or
					row.support_run < 1 or row.support_run > route.node_count or
					row.final_y <= row.baseline_y or
					row.final_y ~= row.support_lower_y - math.abs(row.run - row.support_run) or
					type(row.support_kind) ~= "string" then
				fail("non-minimal route-envelope witness at " .. tostring(row.path_id))
			end
			local support = lower_key[row.path_id .. ":" .. row.support_run]
			if not support or support.lower_y ~= row.support_lower_y or
					support.witness_x ~= row.support_x or support.witness_z ~= row.support_z or
					support.bound_kind ~= row.support_kind or
					support.interface_id ~= row.support_id then
				fail("route raise does not bind a projected support witness")
			end
			local key = row.path_id .. ":" .. row.run
			if raise_key[key] then fail("duplicate raised route run " .. key) end
			raise_key[key] = row
			raise_count_by_path[row.path_id] = (raise_count_by_path[row.path_id] or 0) + 1
		end
		for path_id, row in pairs(route_by_id) do
			if row.exact_pin_count ~= (pin_count_by_path[path_id] or 0) or
					row.water_lower_bound_run_count ~= (lower_count_by_path[path_id] or 0) or
					row.water_lower_bound_column_count ~=
						(lower_columns_by_path[path_id] or 0) or
					row.raised_run_count ~= (raise_count_by_path[path_id] or 0) then
				fail("route evidence totals differ at " .. path_id)
			end
		end
		for path_id, route in pairs(route_by_id) do
			local pin_runs = {}
			for run = 1, route.node_count do
				if pin_key[path_id .. ":" .. run] then pin_runs[#pin_runs + 1] = run end
			end
			if #pin_runs < 2 or pin_runs[1] ~= 1 or
					pin_runs[#pin_runs] ~= route.node_count then
				fail("route exact pins do not cover both endpoints at " .. path_id)
			end
			local baseline = {}
			for pin_index = 1, #pin_runs - 1 do
				local first_run, last_run = pin_runs[pin_index], pin_runs[pin_index + 1]
				local first = pin_key[path_id .. ":" .. first_run]
				local last = pin_key[path_id .. ":" .. last_run]
				if math.abs(last.y - first.y) > last_run - first_run then
					fail("infeasible exact-pin interval at " .. path_id)
				end
				for run = first_run, last_run do
					baseline[run] = first.y + common.round_half_away(
						(last.y - first.y) * (run - first_run), last_run - first_run)
				end
			end
			local final = {}
			for run = 1, route.node_count do
				local lower = lower_key[path_id .. ":" .. run]
				final[run] = math.max(baseline[run], lower and lower.lower_y or baseline[run])
			end
			for run = 2, route.node_count do
				final[run] = math.max(final[run], final[run - 1] - 1)
			end
			for run = route.node_count - 1, 1, -1 do
				final[run] = math.max(final[run], final[run + 1] - 1)
			end
			local baseline_min, baseline_max, final_min, final_max, maximum_step
			local expected_raises = 0
			for run = 1, route.node_count do
				baseline_min = baseline_min and math.min(baseline_min, baseline[run]) or baseline[run]
				baseline_max = baseline_max and math.max(baseline_max, baseline[run]) or baseline[run]
				final_min = final_min and math.min(final_min, final[run]) or final[run]
				final_max = final_max and math.max(final_max, final[run]) or final[run]
				if run > 1 then
					maximum_step = math.max(maximum_step or 0,
						math.abs(final[run] - final[run - 1]))
				end
				local pin = pin_key[path_id .. ":" .. run]
				if pin and (baseline[run] ~= pin.y or final[run] ~= pin.y) then
					fail("two-pass envelope changed an exact pin at " .. path_id)
				end
				local raised = raise_key[path_id .. ":" .. run]
				if final[run] > baseline[run] then
					expected_raises = expected_raises + 1
					if not raised or raised.baseline_y ~= baseline[run] or
							raised.final_y ~= final[run] then
						fail("two-pass envelope raise evidence differs at " .. path_id)
					end
				elseif raised then fail("unchanged route run reported as raised") end
			end
			if route.baseline_min_y ~= baseline_min or route.baseline_max_y ~= baseline_max or
					route.final_min_y ~= final_min or route.final_max_y ~= final_max or
					route.maximum_step ~= (maximum_step or 0) or maximum_step > 1 or
					route.raised_run_count ~= expected_raises then
				fail("exact minimal two-pass envelope aggregate differs at " .. path_id)
			end
		end

		local approaches = require_array(evidence, "ford_approaches")
		local approach_by_interface = {}
		for index = 1, #approaches do
			local row = approaches[index]
			integer_fields(row, {"run", "ford_run", "ford_pin_y", "distance",
				"uncapped_lower_y", "capped_lower_y", "witness_x", "witness_z"},
				"ford approach")
			local datum = clearance_at(session, row.witness_x, row.witness_z)
			if row.distance ~= math.abs(row.run - row.ford_run) or
					row.capped_lower_y ~= row.ford_pin_y + row.distance or
					row.uncapped_lower_y ~= datum + 1 or
					row.capped_lower_y >= row.uncapped_lower_y or
					type(row.interface_id) ~= "string" or
					type(row.hydrology_id) ~= "string" or
					not lower_key[row.path_id .. ":" .. row.run] or
					lower_key[row.path_id .. ":" .. row.run].bound_kind ~= "ford_approach" or
					lower_key[row.path_id .. ":" .. row.run].interface_id ~= row.interface_id then
				fail("ford-approach cap differs at " .. tostring(row.interface_id))
			end
			local kind, surface, feature, interface =
				session.functional_surface_values_at(row.witness_x, row.witness_z)
			if kind ~= "ford" or feature ~= row.path_id or
					interface ~= row.interface_id or surface < row.capped_lower_y or
					session.terrain_height_at(row.witness_x, row.witness_z) ~= surface then
				fail("ford-approach functional witness differs")
			end
			local rows = approach_by_interface[row.interface_id]
			if not rows then rows = {} approach_by_interface[row.interface_id] = rows end
			rows[#rows + 1] = row
		end
		local summaries = require_array(evidence, "ford_approach_summaries")
		local ford_source_count, ford_source_ids = 0, {}
		for index = 1, #source.crossing_interfaces do
			if source.crossing_interfaces[index].kind == "ford" then
				ford_source_count = ford_source_count + 1
				ford_source_ids[source.crossing_interfaces[index].id] = true
			end
		end
		if #summaries ~= ford_source_count then fail("ford summary count differs") end
		local summary_ids = {}
		for index = 1, #summaries do
			local row = summaries[index]
			if not ford_source_ids[row.interface_id] or summary_ids[row.interface_id] then
				fail("ford summary identity differs")
			end
			summary_ids[row.interface_id] = true
			integer_fields(row, {"ford_run", "ford_pin_y", "capped_run_count"},
				"ford approach summary")
			local rows = approach_by_interface[row.interface_id] or {}
			if row.capped_run_count ~= #rows then fail("ford cap count differs") end
			if #rows == 0 then
				if row.first_run ~= nil or row.last_run ~= nil or
						row.resume_before_run ~= nil or row.resume_after_run ~= nil then
					fail("empty ford cap carries run bounds")
				end
			else
				table.sort(rows, function(a, b) return a.run < b.run end)
				if row.first_run ~= rows[1].run or row.last_run ~= rows[#rows].run then
					fail("ford capped run bounds differ")
				end
				local function expected_resume(first_run, last_run, direction)
					local run = direction < 0 and first_run - 1 or last_run + 1
					local limit = route_by_id[row.path_id].node_count
					while run >= 1 and run <= limit do
						local lower = lower_key[row.path_id .. ":" .. run]
						if lower and lower.bound_kind == "ordinary_water" then return run end
						run = run + direction
					end
					return nil
				end
				if row.resume_before_run ~= expected_resume(row.first_run,
						row.last_run, -1) or row.resume_after_run ~=
						expected_resume(row.first_run, row.last_run, 1) then
					fail("ford first ordinary-water resumption differs")
				end
			end
		end

		local named_expected = {}
		local tunnel_expected = {}
		for index = 1, #source.crossing_interfaces do
			local crossing = source.crossing_interfaces[index]
			if crossing.kind == "tunnel" then tunnel_expected[#tunnel_expected + 1] = crossing
			else named_expected[#named_expected + 1] = crossing end
		end
		local named = require_array(evidence, "named_water_operations", #named_expected)
		require_id_coverage(named, named_expected, "named water operations")
		local kind_map = {bridge = "bridge_deck", causeway = "causeway", ford = "ford"}
		local expected_named_by_id = maps_by_id(named_expected)
		for index = 1, #named do
			local row = named[index]
			local expected = expected_named_by_id[row_id(row)]
			integer_fields(row, {"footprint_columns", "min_surface_y", "max_surface_y",
				"first_witness_x", "first_witness_z"}, "named water operation")
			if not expected or row.path_id ~= expected.route_id or
					row.kind ~= kind_map[expected.kind] or row.footprint_columns <= 0 or
					row.min_surface_y > row.max_surface_y then
				fail("named water operation differs at " .. tostring(row_id(row)))
			end
			local datum = clearance_at(session, row.first_witness_x,
				row.first_witness_z)
			local kind, surface, feature, interface =
				session.functional_surface_values_at(row.first_witness_x,
					row.first_witness_z)
			if kind ~= row.kind or feature ~= row.path_id or interface ~= row_id(row) or
					surface < row.min_surface_y or surface > row.max_surface_y then
				fail("named operation identity witness differs at " .. row_id(row))
			end
			if row.kind == "bridge_deck" then
				if surface < datum + 4 then
					fail("named bridge scalar semantics differ at " .. row_id(row))
				end
			elseif row.kind == "causeway" then
				if surface < datum + 1 or session.terrain_height_at(row.first_witness_x,
						row.first_witness_z) ~= surface then
					fail("named causeway scalar semantics differ at " .. row_id(row))
				end
			elseif session.terrain_height_at(row.first_witness_x,
					row.first_witness_z) ~= surface then
				fail("named ford scalar semantics differ at " .. row_id(row))
			end
			common.digest(row.classification_digest, "named operation classification")
		end
		for index = 1, #named_expected do
			local crossing = named_expected[index]
			if crossing.kind == "ford" then
				local found
				for pin_index = 1, #pins do
					local pin = pins[pin_index]
					if pin.source_id == crossing.id and pin.pin_kind == "ford_center" then
						if found then fail("duplicate ford-centre pin at " .. crossing.id) end
						found = pin
					end
				end
				local datum = clearance_at(session, crossing.position.x,
					crossing.position.z)
				if not found or found.path_id ~= crossing.route_id or found.y ~= datum - 1 then
					fail("ford-centre exact pin differs at " .. crossing.id)
				end
			end
		end

		local derived = require_array(evidence, "derived_water_runs")
		local derived_key = {}
		for index = 1, #derived do
			local row = derived[index]
			integer_fields(row, {"run", "causeway_columns", "bridge_columns"},
				"derived water run")
			if not route_by_id[row.path_id] or row.causeway_columns < 0 or
					row.bridge_columns < 0 or row.causeway_columns + row.bridge_columns <= 0 or
					row.interface_id ~= nil or row.id ~= nil then
				fail("derived water run identity/count differs")
			end
			local key = row.path_id .. ":" .. row.run
			if derived_key[key] then fail("duplicate derived water run " .. key) end
			derived_key[key] = true
			if row.causeway_columns > 0 then
				integer_fields(row, {"causeway_witness_x", "causeway_witness_z"},
					"derived causeway witness")
				local datum = clearance_at(session, row.causeway_witness_x,
					row.causeway_witness_z)
				local kind, surface, feature, interface =
					session.functional_surface_values_at(row.causeway_witness_x,
						row.causeway_witness_z)
				if kind ~= "causeway" or surface ~= datum + 1 or
						feature ~= row.path_id or interface ~= nil or
						session.terrain_height_at(row.causeway_witness_x,
							row.causeway_witness_z) ~= surface then
					fail("derived causeway scalar semantics differ")
				end
			end
			if row.bridge_columns > 0 then
				integer_fields(row, {"bridge_witness_x", "bridge_witness_z"},
					"derived bridge witness")
				local datum = clearance_at(session, row.bridge_witness_x,
					row.bridge_witness_z)
				local kind, surface, feature, interface =
					session.functional_surface_values_at(row.bridge_witness_x,
						row.bridge_witness_z)
				if kind ~= "bridge_deck" or surface <= datum + 1 or
						feature ~= row.path_id or interface ~= nil then
					fail("derived bridge non-scalar semantics differ")
				end
			end
			common.digest(row.classification_digest, "derived classification")
		end

		local landings = require_array(evidence, "landings", #source.island_landings)
		require_id_coverage(landings, source.island_landings, "landings")
		local source_landing_by_id = maps_by_id(source.island_landings)
		local source_boat_by_id = maps_by_id(source.boat_paths or {})
		local island_path_by_id = maps_by_id(source.island_routes)
		for index = 1, #landings do
			local row = landings[index]
			local source_landing = source_landing_by_id[row_id(row)]
			local boat = source_landing and source_boat_by_id[source_landing.boat_path_id]
			integer_fields(row, {"surface_y", "corridor_land_columns", "graded_columns",
				"water_columns_unchanged", "mainland_columns_unchanged", "witness_x",
				"witness_z"}, "landing")
			if not source_landing or not boat or boat.width ~= 96 or
					row.boat_path_id ~= boat.id or not island_path_by_id[row.route_id] or
					row.surface_y ~= common.WATER_LEVEL + 1 or
					row.corridor_land_columns <= 0 or
					row.graded_columns <= 0 or row.water_columns_unchanged <= 0 or
					row.mainland_columns_unchanged <= 0 or
					row.graded_columns > row.corridor_land_columns then
				fail("island landing grade evidence differs at " .. row.id)
			end
			local kind, surface, feature = session.functional_surface_values_at(
				row.witness_x, row.witness_z)
			if kind ~= "land_grade" or surface ~= row.surface_y or feature ~= row.id then
				fail("island landing witness differs at " .. row.id)
			end
			common.digest(row.classification_digest, "landing classification")
		end

		local tunnels = require_array(evidence, "tunnels", #tunnel_expected)
		require_id_coverage(tunnels, tunnel_expected, "tunnels")
		for index = 1, #tunnels do
			local row = tunnels[index]
			local expected_tunnel = maps_by_id(tunnel_expected)[row_id(row)]
			integer_fields(row, {"center_run", "first_run", "last_run", "axis_node_count",
				"footprint_columns", "interior_min", "interior_min_witness_x",
				"interior_min_witness_z", "baseline_y", "feasible_lower_y",
				"feasible_upper_y", "floor_y", "before_pin_run", "before_pin_y",
				"after_pin_run", "after_pin_y", "minimum_overburden",
				"overburden_witness_x", "overburden_witness_z",
				"named_overlap_columns", "tunnel_overlap_columns"}, "tunnel")
			local clamped_floor = math.max(row.feasible_lower_y,
				math.min(row.baseline_y, row.feasible_upper_y))
			if not expected_tunnel or row.path_id ~= expected_tunnel.route_id or
					row.axis_node_count ~= 33 or row.last_run - row.first_run ~= 32 or
					row.center_run - row.first_run ~= 16 or row.last_run - row.center_run ~= 16 or
					row.footprint_columns < 33 or row.feasible_lower_y > row.feasible_upper_y or
					row.floor_y ~= clamped_floor or
					row.feasible_upper_y > row.interior_min - 5 or
					row.minimum_overburden ~= row.interior_min - row.floor_y or
					row.minimum_overburden < 5 or row.before_pin_run >= row.first_run or
					row.after_pin_run <= row.last_run or
					math.abs(row.floor_y - row.before_pin_y) > row.first_run - row.before_pin_run or
					math.abs(row.floor_y - row.after_pin_y) > row.after_pin_run - row.last_run or
					row.named_overlap_columns ~= 0 or row.tunnel_overlap_columns ~= 0 then
				fail("central-33 tunnel construction differs at " .. row.interface_id)
			end
			if session.terrain_height_at(row.interior_min_witness_x,
					row.interior_min_witness_z) ~= row.interior_min or
					session.terrain_height_at(row.overburden_witness_x,
						row.overburden_witness_z) - row.floor_y < 5 then
				fail("tunnel overburden witness differs at " .. row.interface_id)
			end
			local tunnel_pins = {}
			for pin_index = 1, #pins do
				local pin = pins[pin_index]
				if pin.source_id == row.interface_id and
						(pin.pin_kind == "tunnel_first" or pin.pin_kind == "tunnel_last") then
					tunnel_pins[pin.pin_kind] = pin
				end
			end
			if not tunnel_pins.tunnel_first or not tunnel_pins.tunnel_last or
					tunnel_pins.tunnel_first.path_id ~= row.path_id or
					tunnel_pins.tunnel_last.path_id ~= row.path_id or
					tunnel_pins.tunnel_first.run ~= row.first_run or
					tunnel_pins.tunnel_last.run ~= row.last_run or
					tunnel_pins.tunnel_first.y ~= row.floor_y or
					tunnel_pins.tunnel_last.y ~= row.floor_y then
				fail("tunnel-end exact pins differ at " .. row.interface_id)
			end
			common.digest(row.classification_digest, "tunnel classification")
		end

		common.digest(evidence.visible_surface_classification_digest,
			"visible-surface classification digest")
		if type(evidence.operation_counts) ~= "table" then
			fail("deterministic operation counts missing")
		end
		for key, value in pairs(evidence.operation_counts) do
			if type(key) ~= "string" or type(value) ~= "number" or
					key:match("time") or key:match("cpu") or key:match("wall") or
					key:match("second") or key:match("duration") then
				fail("operation_counts must contain deterministic numeric counts only")
			end
			common.safe_integer(value, "operation count " .. key)
			if value < 0 then fail("negative operation count " .. key) end
		end
		common.digest(evidence.operation_digest, "operation digest")
		common.digest(evidence.route_digest, "route digest")
		local named_overlap = evidence.operation_counts.tunnel_named_operation_overlap_columns
		common.safe_integer(named_overlap, "tunnel/named-operation overlap columns")
		if named_overlap ~= 0 then fail("tunnel overlaps a named water operation") end
	end

	local function contact_face_source_authority(source)
		if source.layout_revision_id ~= "wp40-simple-map-v1e" then return nil end
		if source.schema ~= "grug_wp40_simple_map_source_v2" or
				source.layout_id ~= "wp40-simple-map-v1d" or
				#source.hydrology ~= 25 or #source.hydrology_interfaces ~= 15 then
			fail("V1e hydrology source population/identity differs")
		end
		local hydrology_by_id = maps_by_id(source.hydrology)
		local profile_by_id = maps_by_id(source.hydrology_profiles)
		local contact_rows, pair_seen, legacy_seen = {}, {}, {}
		local population = {total = #source.hydrology_interfaces,
			unequal_level_pairs = 0, rapids = 0, waterfalls = 0,
			cardinal_waterfalls = 0, contact_face_waterfalls = 0, other = 0}
		for index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[index]
			if row.kind == "rapid" then population.rapids = population.rapids + 1
			elseif row.kind == "waterfall" then
				population.waterfalls = population.waterfalls + 1
			else population.other = population.other + 1 end
			if row.upper_id ~= nil or row.lower_id ~= nil then
				if type(row.upper_id) ~= "string" or type(row.lower_id) ~= "string" or
						row.upper_id == row.lower_id then
					fail("hydrology upper/lower pair identity differs at " .. row.id)
				end
				local upper, lower = hydrology_by_id[row.upper_id],
					hydrology_by_id[row.lower_id]
				if not upper or not lower or
						row.upper_level_offset ~= upper.water_surface_offset or
						row.lower_level_offset ~= lower.water_surface_offset or
						row.upper_level_offset == row.lower_level_offset then
					fail("hydrology unequal-level pair differs at " .. row.id)
				end
				local a, b = row.upper_id, row.lower_id
				if b < a then a, b = b, a end
				local key = a .. "\t" .. b
				if pair_seen[key] then fail("duplicate named hydrology level pair") end
				pair_seen[key] = row.id
				population.unequal_level_pairs =
					population.unequal_level_pairs + 1
			end
			if row.transition_scope_id == CONTACT_FACE_SCOPE then
				local expected = CONTACT_FACE_EXPECTED[#contact_rows + 1]
				local upper, lower = hydrology_by_id[row.upper_id],
					hydrology_by_id[row.lower_id]
				local lower_profile = lower and profile_by_id[lower.profile_id]
				if not expected or index ~= 12 + #contact_rows + 1 or
						row.id ~= expected.id or row.kind ~= "waterfall" or
						row.upper_id ~= expected.upper_id or
						row.lower_id ~= expected.lower_id or
						row.upper_level_offset ~= expected.upper_offset or
						row.lower_level_offset ~= expected.lower_offset or
						not upper or not lower or not lower_profile or
						upper.landmark_id ~= expected.upper_landmark_id or
						lower.landmark_id ~= expected.lower_landmark_id or
						row.position.x ~= expected.position_x or
						row.position.z ~= expected.position_z or
						row.lip_id ~= expected.lip_id or row.drop_id ~= expected.drop_id or
						row.plunge_id ~= expected.plunge_id or
						row.plunge_profile_id ~= expected.plunge_profile_id or
						lower_profile.id ~= expected.plunge_profile_id or
						row.transition_profile_id ~= "waterfall_drop" or
						row.drop ~= expected.drop or row.drop_height ~= expected.drop or
						row.bed_seal_layers ~= 3 or row.bank_seal_nodes ~= 2 or
						row.receiver_source_omission_nodes ~= 1 or row.sealed ~= true then
					fail("contact-face source authority differs at " .. tostring(row.id))
				end
				for _, forbidden in ipairs({"axis_start", "axis_end", "run", "width",
					"drop_mask_width", "drop_mask_length", "plunge_width",
					"plunge_length"}) do
					if row[forbidden] ~= nil then
						fail("contact-face source carries corridor field " .. forbidden)
					end
				end
				contact_rows[#contact_rows + 1] = row
				population.contact_face_waterfalls =
					population.contact_face_waterfalls + 1
			elseif row.transition_scope_id ~= nil then
				fail("unknown hydrology transition scope at " .. tostring(row.id))
			elseif LEGACY_RAINCALL_TRANSITIONS[row.id] then
				legacy_seen[row.id] = true
				if row.kind == "waterfall" then
					population.cardinal_waterfalls =
						population.cardinal_waterfalls + 1
					if row.drop_mask_width == nil or row.drop_mask_length == nil or
							row.plunge_width == nil or row.plunge_length == nil then
						fail("legacy cardinal waterfall geometry differs at " .. row.id)
					end
				elseif row.kind ~= "rapid" or row.run == nil or row.width == nil then
					fail("legacy Raincall rapid geometry differs at " .. row.id)
				end
			end
		end
		for id in pairs(LEGACY_RAINCALL_TRANSITIONS) do
			if not legacy_seen[id] then fail("legacy Raincall transition missing " .. id) end
		end
		if #contact_rows ~= 3 or population.unequal_level_pairs ~= 7 or
				population.rapids ~= 2 or population.waterfalls ~= 5 or
				population.cardinal_waterfalls ~= 2 or
				population.contact_face_waterfalls ~= 3 or population.other ~= 8 then
			fail("hydrology interface 15/7 population differs")
		end
		return {rows = contact_rows, population = population,
			hydrology_by_id = hydrology_by_id, profile_by_id = profile_by_id}
	end

	local function exact_value_equal(a, b, seen)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		seen = seen or {}
		if seen[a] then return seen[a] == b end
		seen[a] = b
		local count_a, count_b = 0, 0
		for key, value in pairs(a) do
			count_a = count_a + 1
			if not exact_value_equal(value, b[key], seen) then return false end
		end
		for _ in pairs(b) do count_b = count_b + 1 end
		return count_a == count_b
	end

	local function validate_contact_face_evidence_shape(source, evidence,
			interface_evidence)
		local authority = contact_face_source_authority(source)
		if not authority then return nil end
		if not exact_value_equal(evidence.hydrology_interface_population,
				authority.population) then
			fail("hydrology interface population evidence differs")
		end
		if evidence.wet_reach_contact_pairs ~= 12 or
				evidence.unequal_interface_pairs ~= 7 then
			fail("hydrology contact/interface pair evidence differs")
		end
		local contacts = require_array(evidence, "contact_face_waterfalls", 3)
		local interface_by_id = maps_by_id(interface_evidence)
		for index = 1, #contacts do
			local row, expected = contacts[index], CONTACT_FACE_EXPECTED[index]
			if row.numeric_id ~= 12 + index or row.id ~= expected.id or
					row.kind ~= "waterfall" or row.transition_scope_id ~=
					CONTACT_FACE_SCOPE or row.upper_id ~= expected.upper_id or
					row.lower_id ~= expected.lower_id then
				fail("contact-face evidence identity/order differs")
			end
			integer_fields(row, {"numeric_id", "position_x", "position_z",
				"upper_y", "lower_y", "upper_bed", "lower_bed", "drop",
				"drop_height", "bed_seal_layers", "bank_seal_nodes",
				"receiver_source_omission_nodes", "scan_min_x", "scan_max_x",
				"scan_min_z", "scan_max_z", "contact_edge_count",
				"upper_lip_count", "lower_face_count",
				"upper_lip_component_count", "lower_face_component_count",
				"first_upper_x", "first_upper_z", "first_lower_x", "first_lower_z",
				"upper_min_x", "upper_max_x", "upper_min_z", "upper_max_z",
				"lower_min_x", "lower_max_x", "lower_min_z", "lower_max_z",
				"receiver_opening_count", "receiver_y", "receiver_source_min_y",
				"receiver_source_max_y", "authored_falling_water_columns"},
				"contact-face evidence")
			local edges = common.dense_count(row.contact_edges,
				"contact-face evidence edges")
			local lips = common.dense_count(row.upper_lip_columns,
				"contact-face evidence upper lips")
			local faces = common.dense_count(row.lower_face_columns,
				"contact-face evidence lower faces")
			common.dense_count(row.direction_mask_counts,
				"contact-face evidence direction masks")
			if edges ~= row.contact_edge_count or lips ~= row.upper_lip_count or
					faces ~= row.lower_face_count or row.sealed ~= true or
					row.authored_falling_water_columns ~= 0 then
				fail("contact-face complete evidence population differs")
			end
			for _, key in ipairs({"contact_edge_digest", "upper_lip_digest",
				"lower_face_digest", "direction_mask_digest", "contact_face_digest"}) do
				common.digest(row[key], "contact-face " .. key)
			end
			if not interface_by_id[row.id] or
					not exact_value_equal(row, interface_by_id[row.id]) then
				fail("contact-face top-level/interface evidence differs at " .. row.id)
			end
		end
		return {source = authority, rows = contacts}
	end

	function validator.validate_evidence(session, source)
		method(session, "artifact_evidence")
		local first = session.artifact_evidence()
		if type(first) ~= "table" then fail("artifact_evidence did not return a table") end
		local original = normalized_evidence_bytes(first)
		first.__r3_mutation_probe = true
		if type(first.anchors) == "table" and type(first.anchors[1]) == "table" then
			first.anchors[1].__r3_mutation_probe = true
		end
		local evidence = session.artifact_evidence()
		if normalized_evidence_bytes(evidence) ~= original then
			fail("artifact_evidence is not a defensive copy")
		end
		if type(evidence.schema) ~= "string" or evidence.schema == "" then
			fail("artifact evidence schema missing")
		end
		if evidence.height_schema ~= nil and
				evidence.height_schema ~= common.HEIGHT_SCHEMA then
			fail("artifact evidence height schema differs")
		end
		common.digest(evidence.base_lattice_digest, "base lattice digest")
		local roots = require_array(evidence, "relief_roots", #source.relief_profiles)
		require_id_coverage(roots, source.relief_profiles, "relief roots")
		local octave_count = 0
		for index = 1, #source.relief_profiles do
			octave_count = octave_count + #source.relief_profiles[index].octaves
		end
		require_array(evidence, "octave_lattices", octave_count)
		local profiles = require_array(evidence, "primary_profiles",
			#source.relief_profiles)
		require_id_coverage(profiles, source.relief_profiles, "primary profiles")
		local source_profile_by_id = maps_by_id(source.relief_profiles)
		for index = 1, #profiles do
			local row = profiles[index]
			local source_profile = assert(source_profile_by_id[row_id(row)])
			for _, key in ipairs({"sample_count", "observed_min_y",
				"observed_min_count", "observed_min_witness_x",
				"observed_min_witness_z", "observed_max_y",
				"observed_max_count", "observed_max_witness_x",
				"observed_max_witness_z"}) do
				common.safe_integer(row[key], "primary profile " .. key)
			end
			if row.sample_count <= 0 or row.observed_min_count <= 0 or
					row.observed_max_count <= 0 or
					row.observed_min_count > row.sample_count or
					row.observed_max_count > row.sample_count or
					row.observed_min_y > row.observed_max_y or
					row.observed_min_y < common.WATER_LEVEL +
						source_profile.min_above_water or
					row.observed_max_y > common.WATER_LEVEL +
						source_profile.max_above_water then
				fail("primary profile observed extrema/counts differ at " .. row_id(row))
			end
		end
		local landmarks = require_array(evidence, "landmarks", #source.landmarks)
		require_id_coverage(landmarks, source.landmarks, "landmarks")
		for index = 1, #landmarks do
			local row = landmarks[index]
			for _, key in ipairs({"mask_columns", "collar_columns",
				"owner_escape_columns", "observed_min_y",
				"observed_min_witness_x", "observed_min_witness_z",
				"observed_max_y", "observed_max_witness_x",
				"observed_max_witness_z"}) do
				common.safe_integer(row[key], "landmark " .. key)
			end
			if row.mask_columns <= 0 or row.collar_columns <= 0 or
					row.owner_escape_columns ~= 0 or
					row.observed_min_y > row.observed_max_y then
				fail("landmark mask/owner/extrema evidence differs at " .. row_id(row))
			end
		end
		validate_station_anchor_evidence(session, source, evidence)
		local hard = require_array(evidence, "hard_protection",
			#source.hard_protection)
		require_id_coverage(hard, source.hard_protection, "hard protection")
		validate_route_operation_evidence(session, source, evidence)
		local hydrology = require_array(evidence, "hydrology", #source.hydrology)
		require_id_coverage(hydrology, source.hydrology, "hydrology")
		local interfaces = require_array(evidence, "interfaces",
			#source.hydrology_interfaces)
		require_id_coverage(interfaces, source.hydrology_interfaces, "interfaces")
		validate_contact_face_evidence_shape(source, evidence, interfaces)
		local exterior = require_array(evidence, "exterior_witnesses")
		local exterior_seen = {}
		for index = 1, #exterior do
			local row = exterior[index]
			integer_fields(row, {"x", "z", "terrain_y", "water_y"},
				"exterior witness")
			if exterior_seen[row.kind] or
					session.terrain_height_at(row.x, row.z) ~= row.terrain_y or
					session.water_surface_at(row.x, row.z) ~= row.water_y then
				fail("exterior witness differs at " .. tostring(row.kind))
			end
			exterior_seen[row.kind] = true
		end
		for _, kind in ipairs({"bay", "coastal_shelf", "deep_ocean",
				"immutable_dragon_channel"}) do
			if not exterior_seen[kind] then fail("exterior evidence misses " .. kind) end
		end
		local cores = require_array(evidence, "coastal_cores",
			#source.coastal_housing_cores)
		require_id_coverage(cores, source.coastal_housing_cores, "coastal cores")
		check_digest_fields(evidence, "artifact_evidence")
		check_zero_violation_fields(evidence, "artifact_evidence")
		return evidence
	end

	function validator.validate_api(session, raw_sha256)
		if type(raw_sha256) ~= "function" then fail("raw SHA-256 helper missing") end
		validated_raw_sha256 = raw_sha256
		for _, name in ipairs({
			"terrain_height_at", "water_surface_at",
			"functional_surface_values_at", "hydrology_transition_values_at",
			"selected_anchor_3d_by_id", "hard_protection_volumes",
			"relief_lattice_digest", "canonical_kat", "canonical_kat_digest",
			"artifact_evidence", "metrics",
		}) do method(session, name) end
		common.digest(session.relief_lattice_digest(), "relief lattice digest")
		local kat = session.canonical_kat()
		if type(kat) ~= "string" then fail("canonical_kat did not return bytes") end
		local digest = common.digest(session.canonical_kat_digest(),
			"canonical KAT digest")
		if common.digest_hex(raw_sha256, kat) ~= digest then
			fail("canonical KAT bytes and digest differ")
		end
		local metrics = session.metrics()
		if type(metrics) ~= "table" then fail("metrics did not return a table") end
		common.safe_integer(metrics.query_sha256_calls, "query SHA-256 calls")
		common.safe_integer(metrics.query_lattice_constructions,
			"query lattice constructions")
		if metrics.query_sha256_calls ~= 0 then fail("height query used SHA-256") end
		if metrics.query_lattice_constructions ~= 0 then
			fail("height query constructed a lattice")
		end
		for key, value in pairs(metrics) do
			if type(key) ~= "string" or type(value) ~= "number" then
				fail("metrics must be a flat table of deterministic numeric counts")
			end
			if key:match("time") or key:match("cpu") or key:match("wall") or
					key:match("second") or key:match("duration") then
				fail("host/interpreter timings must not enter canonical metrics")
			end
			common.safe_integer(value, "metric " .. key)
		end
		metrics.query_sha256_calls = -1
		local second = session.metrics()
		if second.query_sha256_calls ~= 0 then fail("metrics is not a defensive copy") end
		return second
	end

	local function query_column(session, horizontal, x, z, reuse)
		common.safe_integer(x, "query x")
		common.safe_integer(z, "query z")
		local ground = session.terrain_height_at(x, z)
		common.safe_integer(ground, "terrain height")
		local water = session.water_surface_at(x, z)
		if water ~= nil then common.safe_integer(water, "water surface") end
		local kind, surface, feature_id, interface_id =
			session.functional_surface_values_at(x, z)
		if kind == nil then
			if surface ~= nil or feature_id ~= nil or interface_id ~= nil then
				fail("partial nil functional tuple")
			end
		else
			if not ALLOWED_FUNCTIONAL[kind] then fail("unknown functional kind " .. tostring(kind)) end
			common.safe_integer(surface, "functional surface")
			if type(feature_id) ~= "string" or feature_id == "" then
				fail("functional feature id missing")
			end
			if interface_id ~= nil and
					(type(interface_id) ~= "string" or interface_id == "") then
				fail("functional interface id differs")
			end
			if ((kind == "land_grade" or kind == "anchor_platform") and
					interface_id ~= nil) or
					((kind == "ford" or kind == "tunnel_floor") and
					interface_id == nil) then
				fail("functional interface identity differs for " .. kind)
			end
		end
		local transition, transition_id, upper, lower, progress, face_mask =
			session.hydrology_transition_values_at(x, z)
		if transition == nil then
			if transition_id ~= nil or upper ~= nil or lower ~= nil or
					progress ~= nil or face_mask ~= nil then
				fail("partial nil hydrology-transition tuple")
			end
		else
			if not ALLOWED_TRANSITIONS[transition] then
				fail("unknown hydrology transition " .. tostring(transition))
			end
			if type(transition_id) ~= "string" or transition_id == "" then
				fail("hydrology transition id missing")
			end
			common.safe_integer(upper, "transition upper y")
			common.safe_integer(lower, "transition lower y")
			if progress == nil then
				common.safe_integer(face_mask, "contact-face direction mask")
				if transition ~= "waterfall" or face_mask < 1 or face_mask > 15 then
					fail("contact-face transition tuple differs")
				end
			else
				common.safe_integer(progress, "transition progress Q")
				if progress < 0 or progress > Q then
					fail("transition progress outside Q")
				end
				if face_mask ~= nil then
					fail("corridor transition returned a contact-face mask")
				end
			end
		end
		local water_class, macro_region, zone_numeric_id, bay_id, hydrology_id,
			channel_id, fixed, civic_water = horizontal.classification_values_at(x, z)
		local row = reuse or {}
		local classification = row.classification or {}
		classification.water_class = water_class
		classification.macro_region = macro_region
		classification.zone_numeric_id = zone_numeric_id
		classification.bay_id = bay_id
		classification.hydrology_id = hydrology_id
		classification.channel_id = channel_id
		classification.fixed = fixed or nil
		classification.civic_water = civic_water or nil
		row.x, row.z, row.ground, row.water = x, z, ground, water
		row.kind, row.surface, row.feature_id = kind, surface, feature_id
		row.interface_id, row.transition = interface_id, transition
		row.transition_id, row.upper, row.lower = transition_id, upper, lower
		row.progress, row.face_mask = progress, face_mask
		row.classification = classification
		return row
	end

	local function expected_shelf_depth(horizontal, x, z, shelf_width)
		local low, high = 1, shelf_width
		while low < high do
			local middle = math.floor((low + high) / 2)
			if horizontal.expanded_land_at(x, z, middle) then high = middle
			else low = middle + 1 end
		end
		return 1 + math.floor(7 * (low - 1) / 79)
	end

	local function check_column_rules(row, source, horizontal, hydro_by_id,
			profile_by_id, counts, anchor_reference_by_id, landing_ids,
			contact_faces, corridor_transition_by_id, corridor_transition_checks)
		local class = row.classification.water_class
		local contact_face = contact_faces and
			contact_faces[row.x .. ":" .. row.z] or nil
		if row.face_mask ~= nil and not contact_face then
			fail("contact-face mask escaped independently reconstructed authority")
		end
		if contact_face and (row.transition_id ~= contact_face.id or
				row.face_mask ~= contact_face.mask or row.ground ~= contact_face.lower_bed or
				row.water ~= nil or row.lower ~= contact_face.lower_y or
				row.progress ~= nil) then
			fail("contact-face column differs from independently reconstructed authority")
		end
		if row.progress ~= nil then
			local transition = corridor_transition_by_id and
				corridor_transition_by_id[row.transition_id] or nil
			local checks = corridor_transition_checks and
				corridor_transition_checks[row.transition_id] or nil
			if not transition or not checks or transition.kind ~= row.transition or
					transition.upper_y ~= row.upper or
					transition.lower_y ~= row.lower then
				fail("corridor transition authority differs at " ..
					tostring(row.transition_id))
			end
			checks.columns = checks.columns + 1
			if row.transition == "rapid" then
				local expected_water = common.round_half_away(
					row.upper * Q + (row.lower - row.upper) * row.progress, Q)
				if row.water ~= expected_water then
					fail("rapid water surface differs at " .. row.x .. "," .. row.z)
				end
			elseif row.transition == "waterfall" then
				if row.water ~= nil then
					fail("cardinal waterfall has a water surface at " ..
						row.x .. "," .. row.z)
				end
			else
				fail("corridor transition kind differs at " ..
					tostring(row.transition_id))
			end

			-- H is the final top solid. These three bounded functional kinds
			-- intentionally replace a covered transition bed with their dry top;
			-- the planned-water scalar-kind gates below independently require
			-- row.ground == row.surface. No other kind may skip the bed identity.
			local solid_override = row.kind == "causeway" or row.kind == "ford" or
				row.kind == "anchor_platform"
			if solid_override then
				checks.solid_overrides = checks.solid_overrides + 1
			else
				local expected_bed = common.round_half_away(
					transition.upper_bed * Q +
						(transition.lower_bed - transition.upper_bed) * row.progress, Q)
				if row.ground ~= expected_bed then
					fail("corridor transition bed differs at " .. row.x .. "," .. row.z)
				end
				checks.beds = checks.beds + 1
			end
		end
		counts[class] = (counts[class] or 0) + 1
		if class == "land" then
			if row.water ~= nil then fail("land column has a water surface") end
			if row.kind == "anchor_platform" then
				fail("anchor platform appeared on ordinary land")
			elseif row.kind == "land_grade" then
				if row.ground ~= row.surface then fail("solid functional surface differs from H") end
				if landing_ids and landing_ids[row.feature_id] and
						row.surface ~= common.WATER_LEVEL + 1 then
					fail("island landing grade is not water level + 1")
				end
			end
		elseif class == "planned_water" then
			if row.water == nil and row.transition ~= "waterfall" then
				fail("planned-water column has no scalar water or waterfall datum")
			end
			local reach = row.classification.hydrology_id and
				hydro_by_id[row.classification.hydrology_id] or nil
			local expected_bed
			if reach then
				local profile = assert(profile_by_id[reach.profile_id])
				local expected_water = common.WATER_LEVEL + reach.water_surface_offset
				if row.transition == nil and row.water ~= expected_water then
					fail("wet reach surface differs at " .. row.x .. "," .. row.z)
				end
				expected_bed = expected_water - profile.depth
			else
				if not row.classification.bay_id then fail("unidentified planned water") end
				if row.water ~= common.WATER_LEVEL then fail("bay surface differs") end
				expected_bed = common.WATER_LEVEL - 8
			end
			if row.kind == "causeway" then
				local clearance_y = row.water or math.max(row.upper, row.lower)
				if row.surface < clearance_y + 1 or
						(row.interface_id == nil and row.surface ~= clearance_y + 1) or
						row.ground ~= row.surface then
					fail("causeway output differs")
				end
			elseif row.kind == "ford" then
				if row.interface_id == nil or row.ground ~= row.surface then
					fail("ford output differs")
				end
			elseif row.kind == "bridge_deck" then
				local clearance_y = row.water or math.max(row.upper, row.lower)
				if (row.interface_id ~= nil and row.surface < clearance_y + 4) or
						(row.interface_id == nil and row.surface <= clearance_y + 1) then
					fail("bridge clearance/classification differs")
				end
			elseif row.kind == "anchor_platform" then
				local clearance_y = row.water or math.max(row.upper, row.lower)
				local reference_y = anchor_reference_by_id and
					anchor_reference_by_id[row.feature_id] or nil
				if not reference_y or
						row.surface ~= math.max(reference_y, clearance_y + 1) or
						row.ground ~= row.surface then
					fail("anchor platform is not dry")
				end
			elseif row.kind == "tunnel_floor" then
				fail("land-only tunnel entered planned water")
			elseif row.transition == nil and row.ground ~= expected_bed then
				fail("planned-water bed differs at " .. row.x .. "," .. row.z)
			end
		elseif class == "coastal_shelf" then
			if row.kind ~= nil then fail("functional grade entered coastal shelf") end
			if row.water ~= common.WATER_LEVEL then fail("shelf surface differs") end
			local depth = expected_shelf_depth(horizontal, row.x, row.z,
				source.shelf_width)
			if row.ground ~= common.WATER_LEVEL - depth then fail("shelf bed differs") end
		elseif class == "deep_ocean" or class == "immutable_dragon_channel" then
			if row.kind ~= nil then fail("functional grade entered forbidden exterior water") end
			if row.water ~= common.WATER_LEVEL or
					row.ground ~= common.WATER_LEVEL - 24 then
				fail(class .. " output differs")
			end
		else
			fail("unknown horizontal water class " .. tostring(class))
		end
	end

	local function selected_paths(source, horizontal)
		local result = {}
		for index = 1, #source.routes do
			local row = source.routes[index]
			result[#result + 1] = {id = row.id, points = row.centreline,
				surface_width = row.surface_width, corridor_width = row.corridor_width,
				kind = "land_route"}
		end
		local anchor_by_id = maps_by_id(source.anchors)
		local trail = {bandit_home = true, bandit_frontier = true,
			mirefolk = true, clash = true}
		for index = 1, #source.poi_spurs do
			local spur = source.poi_spurs[index]
			local anchor = assert(anchor_by_id[spur.anchor_id])
			local width = trail[anchor.template_id] and 8 or 12
			result[#result + 1] = {id = spur.id,
				points = spur.centreline,
				surface_width = width == 8 and 3 or 5, corridor_width = width,
				kind = "poi_spur"}
		end
		for index = 1, #source.island_routes do
			local row = source.island_routes[index]
			result[#result + 1] = {id = row.id, points = row.centreline,
				surface_width = 5, corridor_width = 12, kind = "island_route"}
		end
		return result
	end

	local function contact_point_before(a, b)
		return a.z < b.z or (a.z == b.z and a.x < b.x)
	end

	local function contact_edge_before(a, b)
		if a.upper_z ~= b.upper_z then return a.upper_z < b.upper_z end
		if a.upper_x ~= b.upper_x then return a.upper_x < b.upper_x end
		if a.lower_z ~= b.lower_z then return a.lower_z < b.lower_z end
		return a.lower_x < b.lower_x
	end

	local function contact_face_mask_bit(upper_x, upper_z, lower_x, lower_z)
		if upper_x == lower_x - 1 and upper_z == lower_z then return 1 end
		if upper_x == lower_x + 1 and upper_z == lower_z then return 2 end
		if upper_x == lower_x and upper_z == lower_z - 1 then return 4 end
		if upper_x == lower_x and upper_z == lower_z + 1 then return 8 end
		fail("contact-face edge is not orthogonal")
	end

	local function contact_support_bounds(reach)
		local min_x, max_x, min_z, max_z
		for index = 1, #reach.centreline do
			local point = reach.centreline[index]
			local point_min_x, point_max_x = point.x - point.half_width,
				point.x + point.half_width
			local point_min_z, point_max_z = point.z - point.half_width,
				point.z + point.half_width
			min_x = min_x and math.min(min_x, point_min_x) or point_min_x
			max_x = max_x and math.max(max_x, point_max_x) or point_max_x
			min_z = min_z and math.min(min_z, point_min_z) or point_min_z
			max_z = max_z and math.max(max_z, point_max_z) or point_max_z
		end
		return {min_x = min_x - 1, max_x = max_x + 1,
			min_z = min_z - 1, max_z = max_z + 1}
	end

	local function contact_point_bounds(points)
		if #points == 0 then fail("contact-face point set is empty") end
		local result = {min_x = points[1].x, max_x = points[1].x,
			min_z = points[1].z, max_z = points[1].z}
		for index = 2, #points do
			local point = points[index]
			result.min_x, result.max_x = math.min(result.min_x, point.x),
				math.max(result.max_x, point.x)
			result.min_z, result.max_z = math.min(result.min_z, point.z),
				math.max(result.max_z, point.z)
		end
		return result
	end

	local function contact_component_count(points)
		local members, visited = {}, {}
		for index = 1, #points do
			local point = points[index]
			local member_row = members[point.z]
			if not member_row then member_row = {} members[point.z] = member_row end
			member_row[point.x] = true
		end
		local components = 0
		for index = 1, #points do
			local point = points[index]
			local visited_row = visited[point.z]
			if not visited_row or not visited_row[point.x] then
				components = components + 1
				local queue_x, queue_z, cursor = {point.x}, {point.z}, 1
				visited_row = visited_row or {}
				visited[point.z], visited_row[point.x] = visited_row, true
				while cursor <= #queue_x do
					local x, z = queue_x[cursor], queue_z[cursor]
					cursor = cursor + 1
					for dz = -1, 1 do
						local member_row = members[z + dz]
						if member_row then
							local neighbour_visited = visited[z + dz]
							for dx = -1, 1 do
								if (dx ~= 0 or dz ~= 0) and member_row[x + dx] and
										(not neighbour_visited or
										not neighbour_visited[x + dx]) then
									neighbour_visited = neighbour_visited or {}
									visited[z + dz] = neighbour_visited
									neighbour_visited[x + dx] = true
									queue_x[#queue_x + 1], queue_z[#queue_z + 1] =
										x + dx, z + dz
								end
							end
						end
					end
				end
			end
		end
		return components
	end

	local function half_open_square_member(point, center, width)
		local half = width / 2
		return point.x >= center.x - half and point.x < center.x + half and
			point.z >= center.z - half and point.z < center.z + half
	end

	local function add_hit(hits, id)
		hits[id] = (hits[id] or 0) + 1
	end

	local function exact_hits(actual, expected, label)
		for id, count in pairs(actual) do
			if expected[id] ~= count then fail(label .. " differs at " .. id) end
		end
		for id, count in pairs(expected) do
			if actual[id] ~= count then fail(label .. " misses " .. id) end
		end
	end

	local function contact_digest_bytes(id, edges, lips, faces, directions)
		local edge_lines, lip_lines, face_lines, direction_lines = {}, {}, {}, {}
		for index = 1, #edges do
			local row = edges[index]
			edge_lines[index] = table.concat({"edge", id, tostring(row.upper_x),
				tostring(row.upper_z), tostring(row.lower_x), tostring(row.lower_z),
				tostring(row.face_mask_bit)}, "\t") .. "\n"
		end
		for index = 1, #lips do
			local row = lips[index]
			lip_lines[index] = table.concat({"upper_lip", id, tostring(row.x),
				tostring(row.z)}, "\t") .. "\n"
		end
		for index = 1, #faces do
			local row = faces[index]
			face_lines[index] = table.concat({"lower_face", id, tostring(row.x),
				tostring(row.z), tostring(row.face_mask)}, "\t") .. "\n"
		end
		for index = 1, #directions do
			local row = directions[index]
			direction_lines[index] = table.concat({"direction_mask", id,
				tostring(row.face_mask), tostring(row.column_count)}, "\t") .. "\n"
		end
		return table.concat(edge_lines), table.concat(lip_lines),
			table.concat(face_lines), table.concat(direction_lines)
	end

	local function build_contact_face_authority(session, horizontal, source,
			evidence)
		local source_authority = contact_face_source_authority(source)
		if not source_authority then return nil end
		if type(validated_raw_sha256) ~= "function" then
			fail("contact-face digest reconstruction lacks validated SHA-256")
		end
		if type(horizontal.polyline_corridor_member) ~= "function" then
			fail("horizontal corridor authority missing")
		end
		local evidence_shape = validate_contact_face_evidence_shape(source,
			evidence, evidence.interfaces)
		local evidence_by_id = maps_by_id(evidence_shape.rows)
		local paths = selected_paths(source, horizontal)
		if #paths ~= 139 then fail("contact-face path authority count differs") end
		local anchor_profile_by_id = maps_by_id(source.anchor_profiles)
		local hard_recipe_by_id = maps_by_id(source.hard_protection_recipes)
		local route_by_id = maps_by_id(source.routes)
		local result = {records = {}, by_id = {}, face_by_coordinate = {},
			lip_by_coordinate = {}}
		for index = 1, #CONTACT_FACE_EXPECTED do
			local expected = CONTACT_FACE_EXPECTED[index]
			local upper = source_authority.hydrology_by_id[expected.upper_id]
			local lower = source_authority.hydrology_by_id[expected.lower_id]
			local upper_profile = source_authority.profile_by_id[upper.profile_id]
			local lower_profile = source_authority.profile_by_id[lower.profile_id]
			local upper_support, lower_support = contact_support_bounds(upper),
				contact_support_bounds(lower)
			local scan_min_x = math.max(upper_support.min_x, lower_support.min_x)
			local scan_max_x = math.min(upper_support.max_x, lower_support.max_x)
			local scan_min_z = math.max(upper_support.min_z, lower_support.min_z)
			local scan_max_z = math.min(upper_support.max_z, lower_support.max_z)
			if scan_min_x > scan_max_x or scan_min_z > scan_max_z then
				fail("contact-face support intersection is empty")
			end
			local edges, lips, faces = {}, {}, {}
			local lip_seen, face_by_key = {}, {}
			local neighbour_x, neighbour_z = {-1, 1, 0, 0}, {0, 0, -1, 1}
			for z = scan_min_z, scan_max_z do
				for x = scan_min_x, scan_max_x do
					local class, _, _, _, hydrology_id =
						horizontal.classification_values_at(x, z)
					if class == "planned_water" and hydrology_id == upper.id then
						for direction = 1, 4 do
							local lower_x, lower_z = x + neighbour_x[direction],
								z + neighbour_z[direction]
							local lower_class, _, _, _, lower_id =
								horizontal.classification_values_at(lower_x, lower_z)
							if lower_class == "planned_water" and lower_id == lower.id then
								local bit = contact_face_mask_bit(x, z, lower_x, lower_z)
								edges[#edges + 1] = {upper_x = x, upper_z = z,
									lower_x = lower_x, lower_z = lower_z,
									face_mask_bit = bit}
								local lip_key = x .. ":" .. z
								if not lip_seen[lip_key] then
									lip_seen[lip_key] = true
									lips[#lips + 1] = {x = x, z = z}
								end
								local face_key = lower_x .. ":" .. lower_z
								local face = face_by_key[face_key]
								if not face then
									face = {x = lower_x, z = lower_z, face_mask = 0}
									face_by_key[face_key] = face
									faces[#faces + 1] = face
								end
								if math.floor(face.face_mask / bit) % 2 ~= 0 then
									fail("duplicate contact-face direction bit")
								end
								face.face_mask = face.face_mask + bit
							end
						end
					end
				end
			end
			table.sort(edges, contact_edge_before)
			table.sort(lips, contact_point_before)
			table.sort(faces, contact_point_before)
			local upper_bounds, lower_bounds = contact_point_bounds(lips),
				contact_point_bounds(faces)
			local first = edges[1]
			if #edges ~= expected.contact_edge_count or
					#lips ~= expected.upper_lip_count or
					#faces ~= expected.lower_face_count or
					contact_component_count(lips) ~= 1 or
					contact_component_count(faces) ~= 1 or not first or
					first.upper_x ~= expected.first_upper_x or
					first.upper_z ~= expected.first_upper_z or
					first.lower_x ~= expected.first_lower_x or
					first.lower_z ~= expected.first_lower_z or
					upper_bounds.min_x ~= expected.upper_min_x or
					upper_bounds.max_x ~= expected.upper_max_x or
					upper_bounds.min_z ~= expected.upper_min_z or
					upper_bounds.max_z ~= expected.upper_max_z or
					lower_bounds.min_x ~= expected.lower_min_x or
					lower_bounds.max_x ~= expected.lower_max_x or
					lower_bounds.min_z ~= expected.lower_min_z or
					lower_bounds.max_z ~= expected.lower_max_z then
				fail("independent contact-face set reconstruction differs at " ..
					expected.id)
			end
			local direction_count = {}
			for face_index = 1, #faces do
				local face = faces[face_index]
				if face.face_mask < 1 or face.face_mask > 15 then
					fail("independent contact-face mask differs")
				end
				direction_count[face.face_mask] =
					(direction_count[face.face_mask] or 0) + 1
			end
			local directions = {}
			for mask = 1, 15 do
				if direction_count[mask] then directions[#directions + 1] = {
					face_mask = mask, column_count = direction_count[mask]} end
			end
			local edge_bytes, lip_bytes, face_bytes, direction_bytes =
				contact_digest_bytes(expected.id, edges, lips, faces, directions)
			local upper_y, lower_y = common.WATER_LEVEL + expected.upper_offset,
				common.WATER_LEVEL + expected.lower_offset
			local upper_bed, lower_bed = upper_y - upper_profile.depth,
				lower_y - lower_profile.depth
			local record = {numeric_id = 12 + index, id = expected.id,
				kind = "waterfall", position_x = expected.position_x,
				position_z = expected.position_z,
				transition_profile_id = "waterfall_drop",
				transition_scope_id = CONTACT_FACE_SCOPE,
				upper_id = expected.upper_id, lower_id = expected.lower_id,
				upper_y = upper_y, lower_y = lower_y,
				upper_bed = upper_bed, lower_bed = lower_bed,
				lip_id = expected.lip_id, drop_id = expected.drop_id,
				plunge_id = expected.plunge_id,
				plunge_profile_id = expected.plunge_profile_id,
				drop = expected.drop, drop_height = expected.drop,
				bed_seal_layers = 3, bank_seal_nodes = 2,
				receiver_source_omission_nodes = 1, sealed = true,
				scan_min_x = scan_min_x, scan_max_x = scan_max_x,
				scan_min_z = scan_min_z, scan_max_z = scan_max_z,
				contact_edge_count = #edges, upper_lip_count = #lips,
				lower_face_count = #faces, upper_lip_component_count = 1,
				lower_face_component_count = 1,
				first_upper_x = first.upper_x, first_upper_z = first.upper_z,
				first_lower_x = first.lower_x, first_lower_z = first.lower_z,
				upper_min_x = upper_bounds.min_x, upper_max_x = upper_bounds.max_x,
				upper_min_z = upper_bounds.min_z, upper_max_z = upper_bounds.max_z,
				lower_min_x = lower_bounds.min_x, lower_max_x = lower_bounds.max_x,
				lower_min_z = lower_bounds.min_z, lower_max_z = lower_bounds.max_z,
				receiver_opening_count = #faces, receiver_y = lower_y,
				receiver_source_min_y = lower_bed + 1,
				receiver_source_max_y = lower_y - 1,
				authored_falling_water_columns = 0,
				contact_edges = edges, upper_lip_columns = lips,
				lower_face_columns = faces, direction_mask_counts = directions,
				contact_edge_digest = common.digest_hex(validated_raw_sha256, edge_bytes),
				upper_lip_digest = common.digest_hex(validated_raw_sha256, lip_bytes),
				lower_face_digest = common.digest_hex(validated_raw_sha256, face_bytes),
				direction_mask_digest = common.digest_hex(validated_raw_sha256,
					direction_bytes),
				contact_face_digest = common.digest_hex(validated_raw_sha256,
					edge_bytes .. lip_bytes .. face_bytes .. direction_bytes),
			}
			if not exact_value_equal(record, evidence_by_id[expected.id]) then
				fail("independent complete contact-face evidence differs at " ..
					expected.id)
			end
			local full_lip_hits, full_face_hits = {}, {}
			local blend_lip_hits, blend_face_hits = {}, {}
			for anchor_index = 1, #source.anchors do
				local anchor = source.anchors[anchor_index]
				local profile = anchor_profile_by_id[anchor.template_id]
				for lip_index = 1, #lips do
					if half_open_square_member(lips[lip_index], anchor.position,
							profile.fitting_width) then add_hit(full_lip_hits, anchor.id) end
					if half_open_square_member(lips[lip_index], anchor.position,
							profile.blend_width) then add_hit(blend_lip_hits, anchor.id) end
				end
				for face_index = 1, #faces do
					if half_open_square_member(faces[face_index], anchor.position,
							profile.fitting_width) then add_hit(full_face_hits, anchor.id) end
					if half_open_square_member(faces[face_index], anchor.position,
							profile.blend_width) then add_hit(blend_face_hits, anchor.id) end
				end
			end
			local expected_full_lip, expected_full_face = {}, {}
			local expected_blend_lip, expected_blend_face = {}, {}
			if expected.id == "highcourt_goldmead_fall" then
				expected_full_lip.anchor_008 = 13
				expected_blend_lip.anchor_008 = 13
				expected_blend_face.anchor_008 = 13
			elseif expected.id == "gravesalt_broken_fall" then
				expected_blend_lip.anchor_077 = 1
			end
			exact_hits(full_lip_hits, expected_full_lip,
				expected.id .. " full-weight lip fitting")
			exact_hits(full_face_hits, expected_full_face,
				expected.id .. " full-weight face fitting")
			exact_hits(blend_lip_hits, expected_blend_lip,
				expected.id .. " blend lip fitting")
			exact_hits(blend_face_hits, expected_blend_face,
				expected.id .. " blend face fitting")
			local hard_lip_hits, hard_face_hits = {}, {}
			for hard_index = 1, #source.hard_protection do
				local hard = source.hard_protection[hard_index]
				local recipe = hard_recipe_by_id[hard.recipe_id]
				local function hard_member(point)
					if recipe.shape == "centered_half_open_square" then
						return half_open_square_member(point, hard.center,
							recipe.total_width)
					elseif recipe.shape == "exact_column" then
						return point.x == hard.center.x and point.z == hard.center.z
					elseif recipe.shape == "polyline_corridor" then
						for route_index = 1, #hard.route_ids do
							local route = route_by_id[hard.route_ids[route_index]]
							if horizontal.polyline_corridor_member(point.x, point.z,
									route.centreline, recipe.total_width) then return true end
						end
						return false
					end
					fail("unknown hard-protection shape")
				end
				for lip_index = 1, #lips do
					if hard_member(lips[lip_index]) then add_hit(hard_lip_hits, hard.id) end
				end
				for face_index = 1, #faces do
					if hard_member(faces[face_index]) then add_hit(hard_face_hits, hard.id) end
				end
			end
			local expected_hard_lip, expected_hard_face = {}, {}
			if expected.id == "highcourt_goldmead_fall" then
				expected_hard_lip["hard:anchor_008"] = 13
				expected_hard_face["hard:anchor_008"] = 13
			end
			exact_hits(hard_lip_hits, expected_hard_lip,
				expected.id .. " hard lip protection")
			exact_hits(hard_face_hits, expected_hard_face,
				expected.id .. " hard face protection")
			local path_surface_columns, path_corridor_columns = 0, 0
			for face_index = 1, #faces do
				local face, on_surface, in_corridor = faces[face_index], false, false
				for path_index = 1, #paths do
					local path = paths[path_index]
					on_surface = on_surface or horizontal.polyline_corridor_member(
						face.x, face.z, path.points, path.surface_width)
					in_corridor = in_corridor or horizontal.polyline_corridor_member(
						face.x, face.z, path.points, path.corridor_width)
				end
				if on_surface then path_surface_columns = path_surface_columns + 1 end
				if in_corridor then path_corridor_columns = path_corridor_columns + 1 end
				local ground = session.terrain_height_at(face.x, face.z)
				local water = session.water_surface_at(face.x, face.z)
				local kind, _, _, operation_id =
					session.functional_surface_values_at(face.x, face.z)
				local transition, transition_id, query_upper, query_lower, progress,
					face_mask = session.hydrology_transition_values_at(face.x, face.z)
				local class, _, _, _, hydrology_id =
					horizontal.classification_values_at(face.x, face.z)
				if class ~= "planned_water" or hydrology_id ~= lower.id or
						ground ~= lower_bed or water ~= nil or transition ~= "waterfall" or
						transition_id ~= expected.id or query_upper ~= upper_y or
						query_lower ~= lower_y or progress ~= nil or
						face_mask ~= face.face_mask or operation_id ~= nil or
						(kind == "causeway" or kind == "ford" or
						kind == "bridge_deck" or kind == "tunnel_floor") then
					fail("contact-face receiver/query semantics differ at " ..
						expected.id)
				end
				local coordinate = face.x .. ":" .. face.z
				if result.face_by_coordinate[coordinate] then
					fail("contact-face waterfall receiver sets overlap")
				end
				result.face_by_coordinate[coordinate] = {id = expected.id,
					mask = face.face_mask, lower_bed = lower_bed, lower_y = lower_y}
			end
			if path_surface_columns ~= 0 or path_corridor_columns ~= 0 then
				fail("contact-face receiver overlaps a route surface/corridor")
			end
			for lip_index = 1, #lips do
				local lip = lips[lip_index]
				local ground, water = session.terrain_height_at(lip.x, lip.z),
					session.water_surface_at(lip.x, lip.z)
				local transition, transition_id, query_upper, query_lower, progress,
					face_mask = session.hydrology_transition_values_at(lip.x, lip.z)
				local class, _, _, _, hydrology_id =
					horizontal.classification_values_at(lip.x, lip.z)
				if class ~= "planned_water" or hydrology_id ~= upper.id or
						ground ~= upper_bed or water ~= upper_y or transition ~= nil or
						transition_id ~= nil or query_upper ~= nil or query_lower ~= nil or
						progress ~= nil or face_mask ~= nil then
					fail("contact-face upper-lip ordinary query semantics differ at " ..
						expected.id)
				end
				local coordinate = lip.x .. ":" .. lip.z
				if result.lip_by_coordinate[coordinate] then
					fail("contact-face waterfall lip sets overlap")
				end
				result.lip_by_coordinate[coordinate] = {id = expected.id,
					upper_bed = upper_bed, upper_y = upper_y}
			end
			for z = scan_min_z, scan_max_z do
				for x = scan_min_x, scan_max_x do
					local _, transition_id, _, _, _, face_mask =
						session.hydrology_transition_values_at(x, z)
					if transition_id == expected.id and not face_by_key[x .. ":" .. z] then
						fail("contact-face transition escaped reconstructed receiver set")
					end
					if face_mask ~= nil and transition_id == expected.id and
							face_mask ~= face_by_key[x .. ":" .. z].face_mask then
						fail("contact-face transition mask escaped authority")
					end
				end
			end
			result.records[index], result.by_id[expected.id] = record, record
		end
		return result
	end

	local function diagnosis_less(a, b)
		for index = 1, #DIAGNOSIS_SORT_FIELDS do
			local field = DIAGNOSIS_SORT_FIELDS[index]
			local left, right = tostring(a[field]), tostring(b[field])
			if left ~= right then return left < right end
		end
		return false
	end

	function validator.validate_baseline_axis_diagnosis(witnesses, source)
		if common.dense_count(witnesses, "baseline diagnosis witnesses") ~= 40 then
			fail("baseline diagnosis must contain exactly 40 witnesses")
		end
		local paths = selected_paths(source)
		if #paths ~= 139 then fail("baseline diagnosis path count differs") end
		local path_by_id, raster_by_id = {}, {}
		for index = 1, #paths do
			local path = paths[index]
			if path_by_id[path.id] then
				fail("baseline diagnosis has duplicate path " .. tostring(path.id))
			end
			path_by_id[path.id] = path
			raster_by_id[path.id] = common.raster_polyline(path.points)
		end
		local required = {}
		for index = 1, #DIAGNOSIS_FIELDS do
			required[DIAGNOSIS_FIELDS[index]] = true
		end
		local expected_pairs = {}
		for index = 1, #BASELINE_DIAGNOSIS_PAIRS do
			local pair = BASELINE_DIAGNOSIS_PAIRS[index]
			expected_pairs[pair[1] .. "\t" .. pair[2]] = true
		end
		local pair_counts, duplicate_keys = {}, {}
		local previous
		for index = 1, #witnesses do
			local row = witnesses[index]
			if type(row) ~= "table" then
				fail("baseline diagnosis witness is not a table")
			end
			local field_count = 0
			for key in pairs(row) do
				if not required[key] then
					fail("baseline diagnosis witness has unexpected field " ..
						tostring(key))
				end
				field_count = field_count + 1
			end
			if field_count ~= #DIAGNOSIS_FIELDS then
				fail("baseline diagnosis witness field count differs")
			end
			for field in pairs(required) do
				if row[field] == nil then
					fail("baseline diagnosis witness misses " .. field)
				end
			end
			if type(row.losing_path_id) ~= "string" or
					type(row.winner_path_id) ~= "string" or
					type(row.pair_a) ~= "string" or type(row.pair_b) ~= "string" or
					row.losing_path_id == "" or row.winner_path_id == "" or
					row.pair_a == "" or row.pair_b == "" then
				fail("baseline diagnosis path identity differs")
			end
			integer_fields(row, {"losing_run", "from_x", "from_z", "from_y",
				"to_x", "to_z", "to_y", "absolute_step", "winner_run",
				"winner_x", "winner_z"}, "baseline diagnosis")
			local losing = raster_by_id[row.losing_path_id]
			local winner = raster_by_id[row.winner_path_id]
			if not losing or not winner or row.losing_path_id == row.winner_path_id then
				fail("baseline diagnosis loser/winner identity differs")
			end
			if row.losing_run < 2 or row.losing_run > #losing then
				fail("baseline diagnosis losing run is outside the path")
			end
			local from, to = losing[row.losing_run - 1], losing[row.losing_run]
			if row.from_x ~= from.x or row.from_z ~= from.z or
					row.to_x ~= to.x or row.to_z ~= to.z or
					math.max(math.abs(row.to_x - row.from_x),
						math.abs(row.to_z - row.from_z)) ~= 1 then
				fail("baseline diagnosis losing adjacency differs")
			end
			if row.absolute_step ~= math.abs(row.to_y - row.from_y) or
					row.absolute_step <= 1 then
				fail("baseline diagnosis does not describe a final axis violation")
			end
			if row.winner_run < 1 or row.winner_run > #winner or
					row.winner_x ~= winner[row.winner_run].x or
					row.winner_z ~= winner[row.winner_run].z then
				fail("baseline diagnosis winner projection differs")
			end
			local pair_a, pair_b = row.losing_path_id, row.winner_path_id
			if pair_b < pair_a then pair_a, pair_b = pair_b, pair_a end
			if row.pair_a ~= pair_a or row.pair_b ~= pair_b or
					row.pair_a >= row.pair_b then
				fail("baseline diagnosis unordered pair differs")
			end
			local pair_key = row.pair_a .. "\t" .. row.pair_b
			if not expected_pairs[pair_key] then
				fail("baseline diagnosis pair is outside the closed authority: " ..
					row.pair_a .. " / " .. row.pair_b)
			end
			pair_counts[pair_key] = (pair_counts[pair_key] or 0) + 1
			local duplicate_values = {}
			for field_index = 1, #DIAGNOSIS_FIELDS do
				duplicate_values[field_index] = tostring(row[DIAGNOSIS_FIELDS[field_index]])
			end
			local duplicate_key = table.concat(duplicate_values, "\t")
			if duplicate_keys[duplicate_key] then
				fail("baseline diagnosis has a duplicate witness")
			end
			duplicate_keys[duplicate_key] = true
			if previous and diagnosis_less(row, previous) then
				fail("baseline diagnosis witnesses are not canonically sorted")
			end
			previous = row
		end
		local pair_rows = {}
		for index = 1, #BASELINE_DIAGNOSIS_PAIRS do
			local pair = BASELINE_DIAGNOSIS_PAIRS[index]
			local key = pair[1] .. "\t" .. pair[2]
			local count = pair_counts[key]
			if not count or count <= 0 then
				fail("baseline diagnosis misses required pair " .. pair[1] ..
					" / " .. pair[2])
			end
			pair_rows[index] = {pair_a = pair[1], pair_b = pair[2],
				witness_count = count}
		end
		local unique_pair_count = 0
		for _ in pairs(pair_counts) do unique_pair_count = unique_pair_count + 1 end
		if unique_pair_count ~= 14 then
			fail("baseline diagnosis must contain exactly 14 unique pairs")
		end
		return pair_rows
	end

	local function traversable_y(row)
		return row.kind and row.surface or row.ground
	end

	local function route_envelope_from_evidence(evidence, path_id, node_count)
		local pins, lower = {}, {}
		for index = 1, #evidence.route_exact_pins do
			local row = evidence.route_exact_pins[index]
			if row.path_id == path_id then pins[#pins + 1] = row end
		end
		for index = 1, #evidence.route_water_lower_bounds do
			local row = evidence.route_water_lower_bounds[index]
			if row.path_id == path_id then lower[row.run] = row.lower_y end
		end
		table.sort(pins, function(a, b) return a.run < b.run end)
		if #pins < 2 or pins[1].run ~= 1 or pins[#pins].run ~= node_count then
			fail("route envelope evidence lacks endpoint pins at " .. path_id)
		end
		local baseline = {}
		for index = 1, #pins - 1 do
			local a, b = pins[index], pins[index + 1]
			for run = a.run, b.run do
				baseline[run] = a.y + common.round_half_away(
					(b.y - a.y) * (run - a.run), b.run - a.run)
			end
		end
		local final = {}
		for run = 1, node_count do
			final[run] = math.max(baseline[run], lower[run] or baseline[run])
		end
		for run = 2, node_count do final[run] = math.max(final[run], final[run - 1] - 1) end
		for run = node_count - 1, 1, -1 do
			final[run] = math.max(final[run], final[run + 1] - 1)
		end
		return final
	end

	local function check_paths(session, horizontal, source, evidence,
			full_corridors, metrics)
		local paths = selected_paths(source, horizontal)
		local path_ids = {}
		for index = 1, #paths do path_ids[paths[index].id] = true end
		local exact_pin_y = {}
		for index = 1, #evidence.route_exact_pins do
			local pin = evidence.route_exact_pins[index]
			local by_run = exact_pin_y[pin.path_id]
			if not by_run then by_run = {} exact_pin_y[pin.path_id] = by_run end
			by_run[pin.run] = pin.y
		end
		local function check_visible_land_identity(row, path_id)
			if row.classification.water_class ~= "land" then return end
			if row.kind == "tunnel_floor" then
				if not path_ids[row.feature_id] then fail("tunnel path identity differs") end
				return
			end
			if row.kind ~= "land_grade" then
				fail("visible land path lacks its scalar grade: " .. path_id)
			end
			if not path_ids[row.feature_id] then
				fail("non-path grade masks full-weight visible path: " .. path_id ..
					" at " .. row.x .. "," .. row.z .. " feature=" ..
					tostring(row.feature_id))
			end
		end
		metrics.route_summaries = {}
		for path_index = 1, #paths do
			local path = paths[path_index]
			local raster = common.raster_polyline(path.points)
			local expected_grade = route_envelope_from_evidence(evidence, path.id, #raster)
			local seen, previous_y, maximum_step = {}, nil, 0
			local foreign_winner_nodes = 0
			local start_y, end_y
			for index = 1, #raster do
				local point = raster[index]
				local key = point.x .. ":" .. point.z
				if seen[key] then fail("route raster repeats a non-join node: " .. path.id) end
				seen[key] = true
				local row = query_column(session, horizontal, point.x, point.z)
				check_visible_land_identity(row, path.id)
				local class = row.classification.water_class
				if class == "coastal_shelf" or class == "deep_ocean" or
						class == "immutable_dragon_channel" then
					fail("graded route enters forbidden water: " .. path.id)
				end
				if class == "planned_water" and row.kind ~= "causeway" and
						row.kind ~= "ford" and row.kind ~= "bridge_deck" then
					fail("route planned-water run has no local operation: " .. path.id)
				end
				if class == "planned_water" and not path_ids[row.feature_id] then
					fail("planned-water route operation has non-path feature identity")
				end
				local y = traversable_y(row)
				local own_envelope_required = row.feature_id == path.id or
					(exact_pin_y[path.id] and exact_pin_y[path.id][index] ~= nil)
				if own_envelope_required and y ~= expected_grade[index] then
					fail("final composed route differs from exact envelope: " .. path.id ..
						" run=" .. tostring(index) .. " at " .. tostring(point.x) ..
						"," .. tostring(point.z) .. " expected=" ..
						tostring(expected_grade[index]) .. " actual=" .. tostring(y) ..
						" kind=" .. tostring(row.kind) .. " feature=" ..
						tostring(row.feature_id))
				end
				if row.feature_id ~= path.id then
					foreign_winner_nodes = foreign_winner_nodes + 1
				end
				if previous_y then
					local step = math.abs(y - previous_y)
					maximum_step = math.max(maximum_step, step)
					if step > 1 then fail("route step exceeds one: " .. path.id) end
				end
				if index == 1 then start_y = y end
				if index == #raster then end_y = y end
				previous_y = y
				metrics.route_axis_nodes = metrics.route_axis_nodes + 1
			end
			if full_corridors then
				for segment = 1, #path.points - 1 do
					local a, b = path.points[segment], path.points[segment + 1]
					local segment_points = {a, b}
					local radius = math.floor(path.corridor_width / 2) + 1
					for z = math.min(a.z, b.z) - radius, math.max(a.z, b.z) + radius do
						for x = math.min(a.x, b.x) - radius, math.max(a.x, b.x) + radius do
							if horizontal.polyline_corridor_member(x, z, segment_points,
									path.corridor_width) then
								local row = query_column(session, horizontal, x, z)
								local visible = horizontal.polyline_corridor_member(x, z,
									segment_points, path.surface_width)
								if visible then check_visible_land_identity(row, path.id) end
								if visible and row.classification.water_class == "planned_water" and
									row.kind ~= "causeway" and row.kind ~= "ford" and
									row.kind ~= "bridge_deck" then
									fail("visible water crossing lacks an operation: " .. path.id)
								end
								if visible and row.classification.water_class == "planned_water" and
										not path_ids[row.feature_id] then
									fail("visible water operation has non-path feature identity")
								end
								metrics.route_corridor_visits = metrics.route_corridor_visits + 1
							end
						end
					end
				end
			end
			metrics.route_summaries[#metrics.route_summaries + 1] = {
				id = path.id, kind = path.kind, nodes = #raster,
				start_y = start_y, end_y = end_y, maximum_step = maximum_step,
				foreign_winner_nodes = foreign_winner_nodes,
			}
		end
		metrics.graded_paths = #paths
	end

	local function check_anchors(session, horizontal, source, metrics)
		local volumes = session.hard_protection_volumes()
		if common.dense_count(volumes, "hard protection volumes") ~=
				#source.hard_protection then fail("hard-protection count differs") end
		local by_id = maps_by_id(volumes)
		for index = 1, #source.hard_protection do
			local expected = source.hard_protection[index]
			local actual = by_id[expected.id]
			if not actual then fail("hard-protection volume missing " .. expected.id) end
			if actual.recipe_id ~= expected.recipe_id or actual.y_min ~= -700 or
					actual.upward_unbounded ~= true then
				fail("hard-protection policy differs for " .. expected.id)
			end
			if expected.center and (type(actual.center) ~= "table" or
					actual.center.x ~= expected.center.x or
					actual.center.z ~= expected.center.z) then
				fail("hard-protection centre differs for " .. expected.id)
			end
			if expected.ingress_id then
				if actual.surface_y ~= nil then fail("ingress collapsed to one surface y") end
			elseif actual.surface_y ~= nil then
				common.safe_integer(actual.surface_y, "hard-protection surface y")
				local centre = query_column(session, horizontal,
					expected.center.x, expected.center.z)
				if actual.surface_y ~= traversable_y(centre) then
					fail("hard-protection centre surface differs for " .. expected.id)
				end
			else
				fail("hard-protection centre surface missing for " .. expected.id)
			end
		end
		volumes[1].id = "mutation-probe"
		if session.hard_protection_volumes()[1].id == "mutation-probe" then
			fail("hard_protection_volumes is not a defensive copy")
		end
		for index = 1, #source.anchors do
			local expected = source.anchors[index]
			local two_d = assert(horizontal.selected_anchor_by_id(expected.id))
			local two_d_fields = {x = true, z = true, anchor_id = true,
				selection_mode = true, approved_candidate_index = true}
			local two_d_field_count = 0
			for key in pairs(two_d) do
				if not two_d_fields[key] then
					fail("2D anchor result has an unexpected field " .. tostring(key))
				end
				two_d_field_count = two_d_field_count + 1
			end
			if two_d_field_count ~= 5 or two_d.anchor_id ~= expected.id then
				fail("2D anchor result shape differs " .. expected.id)
			end
			local actual = session.selected_anchor_3d_by_id(expected.id)
			if type(actual) ~= "table" then fail("3D anchor missing " .. expected.id) end
			if actual.id ~= nil and actual.id ~= expected.id then fail("3D anchor id differs") end
			if actual.anchor_id ~= nil and actual.anchor_id ~= expected.id then
				fail("3D anchor anchor_id differs")
			end
			if actual.x ~= two_d.x or actual.z ~= two_d.z or
					actual.selection_mode ~= two_d.selection_mode or
					actual.approved_candidate_index ~=
						two_d.approved_candidate_index then
				fail("3D anchor moved or reselected " .. expected.id)
			end
			common.safe_integer(actual.y, "anchor y")
			local centre = query_column(session, horizontal, two_d.x, two_d.z)
			if actual.y ~= traversable_y(centre) then
				fail("anchor y differs from its resolved surface " .. expected.id)
			end
			if actual.ground_y ~= nil then
				common.safe_integer(actual.ground_y, "anchor ground y")
				if actual.ground_y ~= session.terrain_height_at(two_d.x, two_d.z) then
					fail("anchor ground y differs from H " .. expected.id)
				end
			end
			local expected_selection_mode =
				expected.placement_mode == "authored_fixed" and
				"authored_fixed" or "frozen_layout"
			if actual.selection_mode ~= expected_selection_mode or
					actual.approved_candidate_index ~=
						expected.approved_candidate_index then
				fail("anchor selection provenance differs " .. expected.id)
			end
			actual.x = actual.x + 1
			if session.selected_anchor_3d_by_id(expected.id).x ~= two_d.x then
				fail("selected_anchor_3d_by_id is not a defensive copy")
			end
		end
		metrics.anchors = #source.anchors
		metrics.hard_protection_volumes = #source.hard_protection
	end

	local function check_interfaces(session, horizontal, source, metrics,
			contact_face_authority)
		local crossing_kind = {
			bridge = "bridge_deck", ford = "ford", causeway = "causeway",
			tunnel = "tunnel_floor",
		}
		local crossing_by_id = maps_by_id(source.crossing_interfaces)
		for index = 1, #source.crossing_interfaces do
			local interface = source.crossing_interfaces[index]
			local row = query_column(session, horizontal,
				interface.position.x, interface.position.z)
			local identity_matches = row.interface_id == interface.id and
				row.feature_id == interface.route_id
			if not identity_matches then
				local winner = crossing_by_id[row.interface_id]
				identity_matches = winner and winner.kind == interface.kind and
					winner.position.x == interface.position.x and
					winner.position.z == interface.position.z and
					row.feature_id == winner.route_id
			end
			if row.kind ~= crossing_kind[interface.kind] or not identity_matches then
				fail("crossing kind differs at " .. interface.id)
			end
		end
		for index = 1, #source.hydrology_interfaces do
			local interface = source.hydrology_interfaces[index]
			local query_x, query_z = interface.position.x, interface.position.z
			if interface.transition_scope_id == CONTACT_FACE_SCOPE then
				local contact = contact_face_authority and
					contact_face_authority.by_id[interface.id]
				local first_face = contact and contact.lower_face_columns[1]
				if not first_face then fail("contact-face interface evidence missing") end
				query_x, query_z = first_face.x, first_face.z
			end
			local row = query_column(session, horizontal, query_x, query_z)
			if interface.kind == "rapid" or interface.kind == "waterfall" then
				if row.transition ~= interface.kind or
						row.transition_id ~= interface.id then
					fail("hydrology transition identity differs at " .. interface.id)
				end
				if row.upper ~= common.WATER_LEVEL + interface.upper_level_offset or
						row.lower ~= common.WATER_LEVEL + interface.lower_level_offset or
						row.upper - row.lower ~= interface.drop then
					fail("hydrology transition levels differ at " .. interface.id)
				end
			end
		end
		metrics.crossing_interfaces = #source.crossing_interfaces
		metrics.hydrology_interfaces = #source.hydrology_interfaces
		if metrics.hydrology_interfaces ~= 15 then
			fail("hydrology interface metric differs from V1e closure")
		end
	end

	local function check_dry_channel(session, horizontal, source, metrics)
		local profiles = maps_by_id(source.hydrology_profiles)
		local found = 0
		for index = 1, #source.hydrology do
			local reach = source.hydrology[index]
			if profiles[reach.profile_id].depth == 0 then
				local raster = common.raster_polyline(reach.centreline)
				local exact = common.WATER_LEVEL + reach.water_surface_offset
				local exact_witness = false
				for point_index = 1, #raster do
					local point = raster[point_index]
					local row = query_column(session, horizontal, point.x, point.z)
					if row.water ~= nil then fail("dry channel returned a water surface") end
					if row.classification.water_class ~= "land" then
						fail("dry channel changed horizontal water class")
					end
					if row.kind == nil and row.ground == exact then exact_witness = true end
				end
				if not exact_witness then fail("dry channel has no ungraded datum witness") end
				found = found + 1
			end
		end
		if found == 0 then fail("source has no dry channel") end
		metrics.dry_channels = found
	end

	local function core_bounds(source, core)
		local landmarks = maps_by_id(source.landmarks)
		local landmark = assert(landmarks[core.landmark_id])
		return landmark.center.x - landmark.radius_x,
			landmark.center.x + landmark.radius_x - 1,
			landmark.center.z - landmark.radius_z,
			landmark.center.z + landmark.radius_z - 1
	end

	local function check_coastal_cores(session, horizontal, source, r2, metrics)
		metrics.coastal_cores = {}
		for index = 1, #source.coastal_housing_cores do
			local core = source.coastal_housing_cores[index]
			local min_x, max_x, min_z, max_z = core_bounds(source, core)
			local minimum, maximum, count
			for z = min_z, max_z do
				for x = min_x, max_x do
					if horizontal.coastal_core_member(core.id, x, z) then
						local row = query_column(session, horizontal, x, z)
						if row.classification.water_class ~= "land" or
								row.classification.zone_numeric_id ~= core.zone_numeric_id then
							fail("coastal core escaped dry owner: " .. core.id)
						end
						minimum = minimum and math.min(minimum, row.ground) or row.ground
						maximum = maximum and math.max(maximum, row.ground) or row.ground
						count = (count or 0) + 1
					end
				end
			end
			if not count or maximum - minimum > core.relief_max then
				fail("coastal-core relief exceeds contract: " .. core.id)
			end
			local reservations = r2.coastal_reservation_counts[core.id]
			if type(reservations) ~= "number" or reservations <= 0 then
				fail("accepted R2 reservation count missing for " .. core.id)
			end
			metrics.coastal_cores[#metrics.coastal_cores + 1] = {
				id = core.id, columns = count, minimum = minimum, maximum = maximum,
				range = maximum - minimum, reservations = reservations,
			}
		end
	end

	local function check_outside(session, horizontal, source, counts)
		local warp = horizontal.warp_proof()
		local points = {
			{warp.min_x - 1, warp.min_z}, {warp.max_x + 1, warp.max_z},
			{warp.min_x, warp.min_z - 1}, {warp.max_x, warp.max_z + 1},
		}
		for index = 1, #points do
			local row = query_column(session, horizontal, points[index][1], points[index][2])
			check_column_rules(row, source, horizontal, {}, {}, counts)
			if row.classification.zone_numeric_id ~= nil or
					row.classification.water_class ~= "deep_ocean" then
				fail("outside-bounds query is not fixed deep ocean")
			end
		end
	end

	local function representative_points(source, horizontal, evidence)
		local points, seen = {}, {}
		local function add(x, z, label)
			if type(x) ~= "number" or type(z) ~= "number" then return end
			local key = x .. ":" .. z
			if not seen[key] then
				seen[key] = true
				points[#points + 1] = {x = x, z = z, label = label}
			end
		end
		for _, pair in ipairs({{-64, -64}, {-63, -63}, {-1, -1}, {0, 0},
			{1, 1}, {63, 63}, {64, 64}, {-769, 257}}) do add(pair[1], pair[2], "lattice") end
		local profile_seen = {}
		for index = 1, #source.zones do
			local zone = source.zones[index]
			if not profile_seen[zone.primary_relief_id] then
				profile_seen[zone.primary_relief_id] = true
				add(zone.hub.x, zone.hub.z, "profile:" .. zone.primary_relief_id)
			end
		end
		for profile_index = 1, #source.relief_profiles do
			local profile = source.relief_profiles[profile_index]
			for octave_index = 1, #profile.octaves do
				local period = profile.octaves[octave_index].period
				add(-period, 0, "octave-corner:" .. profile.id .. ":" .. octave_index)
				add(-period + math.floor(period / 2), math.floor(period / 3),
					"octave-interior:" .. profile.id .. ":" .. octave_index)
			end
		end
		local primitive_seen = {}
		for index = 1, #source.landmarks do
			local row = source.landmarks[index]
			if not primitive_seen[row.primitive] then
				primitive_seen[row.primitive] = true
				add(row.center.x, row.center.z, "mask:" .. row.primitive)
				add(row.center.x + row.radius_x - 1, row.center.z,
					"mask-edge:" .. row.primitive)
				add(row.center.x + row.radius_x + 32, row.center.z,
					"mask-collar:" .. row.primitive)
			end
		end
		for index = 1, #source.hydrology do
			local point = source.hydrology[index].centreline[1]
			add(point.x, point.z, "hydrology:" .. source.hydrology[index].id)
		end
		for index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[index]
			add(row.position.x, row.position.z, "interface:" .. row.id)
		end
		for index = 1, #source.crossing_interfaces do
			local row = source.crossing_interfaces[index]
			add(row.position.x, row.position.z, "crossing:" .. row.id)
		end
		for index = 1, #source.anchors do
			local selected = horizontal.selected_anchor_by_id(source.anchors[index].id)
			add(selected.x, selected.z, "anchor:" .. source.anchors[index].id)
		end
		for _, family in ipairs({"exterior_witnesses", "stations", "anchors",
				"routes", "route_exact_pins", "route_water_lower_bounds",
				"route_raise_witnesses", "ford_approaches",
				"named_water_operations", "derived_water_runs", "landings",
				"tunnels", "hydrology", "interfaces", "contact_face_waterfalls",
				"landmarks", "coastal_cores"}) do
			local rows = evidence[family] or {}
			for index = 1, #rows do
				local row = rows[index]
				add(row.x or row.witness_x, row.z or row.witness_z,
					family .. ":" .. tostring(row_id(row) or index))
				local keys = common.sorted_keys(row)
				for key_index = 1, #keys do
					local key = keys[key_index]
					if type(key) == "string" and key:match("_x$") then
						local prefix = key:sub(1, #key - 2)
						add(row[key], row[prefix .. "_z"], family .. ":" ..
							tostring(row_id(row) or index) .. ":" .. prefix)
					end
				end
			end
		end
		for contact_index = 1, #(evidence.contact_face_waterfalls or {}) do
			local contact = evidence.contact_face_waterfalls[contact_index]
			for edge_index = 1, #contact.contact_edges do
				local edge = contact.contact_edges[edge_index]
				add(edge.upper_x, edge.upper_z, "contact-edge-upper:" .. contact.id)
				add(edge.lower_x, edge.lower_z, "contact-edge-lower:" .. contact.id)
			end
			for lip_index = 1, #contact.upper_lip_columns do
				local lip = contact.upper_lip_columns[lip_index]
				add(lip.x, lip.z, "contact-upper-lip:" .. contact.id)
			end
			for face_index = 1, #contact.lower_face_columns do
				local face = contact.lower_face_columns[face_index]
				add(face.x, face.z, "contact-lower-face:" .. contact.id)
			end
		end
		return points
	end

	function validator.targeted_rows(session, horizontal, source, evidence)
		build_contact_face_authority(session, horizontal, source, evidence)
		local rows, coverage = {}, {functional = {}, transition = {}, class = {}}
		local points = representative_points(source, horizontal, evidence)
		for index = 1, #points do
			local point = points[index]
			local row = query_column(session, horizontal, point.x, point.z)
			coverage.class[row.classification.water_class] = true
			if row.kind then coverage.functional[row.kind] = true end
			if row.transition then coverage.transition[row.transition] = true end
			rows[#rows + 1] = {
				point.label, point.x, point.z, row.classification.water_class,
				row.classification.zone_numeric_id, row.classification.bay_id,
				row.classification.hydrology_id, row.classification.channel_id,
				row.ground, row.water, row.kind, row.surface, row.feature_id,
				row.interface_id, row.transition, row.transition_id,
				row.upper, row.lower, row.progress,
			}
		end
		return rows, coverage
	end

	function validator.assert_targeted_coverage(coverage)
		for kind in pairs(ALLOWED_FUNCTIONAL) do
			if not coverage.functional[kind] then fail("targeted KAT misses " .. kind) end
		end
		for kind in pairs(ALLOWED_TRANSITIONS) do
			if not coverage.transition[kind] then fail("targeted KAT misses " .. kind) end
		end
		for _, class in ipairs({"land", "planned_water", "coastal_shelf",
			"deep_ocean", "immutable_dragon_channel"}) do
			if not coverage.class[class] then fail("targeted KAT misses " .. class) end
		end
	end

	function validator.run(session, horizontal, source, r2, evidence, mode, progress)
		if mode ~= "quick" and mode ~= "full" then fail("unknown validation mode") end
		local metrics = {
			columns = 0, route_axis_nodes = 0, route_corridor_visits = 0,
			graded_paths = 0, class_counts = {},
		}
		local profile_by_id = maps_by_id(source.hydrology_profiles)
		local hydro_by_id = maps_by_id(source.hydrology)
		local interface_evidence_by_id = maps_by_id(evidence.interfaces)
		local corridor_transition_by_id = {}
		local corridor_transition_checks = {}
		local corridor_transition_count = 0
		for index = 1, #source.hydrology_interfaces do
			local interface = source.hydrology_interfaces[index]
			if interface.kind == "rapid" or
					(interface.kind == "waterfall" and
						interface.transition_scope_id == nil) then
				local row = interface_evidence_by_id[interface.id]
				local upper = hydro_by_id[interface.upper_id]
				local lower = hydro_by_id[interface.lower_id]
				local upper_profile = upper and profile_by_id[upper.profile_id] or nil
				local lower_profile = lower and profile_by_id[lower.profile_id] or nil
				local upper_y = common.WATER_LEVEL + interface.upper_level_offset
				local lower_y = common.WATER_LEVEL + interface.lower_level_offset
				if not row or not upper_profile or not lower_profile or
						row.kind ~= interface.kind or row.upper_y ~= upper_y or
						row.lower_y ~= lower_y or
						row.upper_bed ~= upper_y - upper_profile.depth or
						row.lower_bed ~= lower_y - lower_profile.depth then
					fail("corridor transition evidence differs at " .. interface.id)
				end
				corridor_transition_by_id[interface.id] = row
				corridor_transition_checks[interface.id] = {
					columns = 0, beds = 0, solid_overrides = 0}
				corridor_transition_count = corridor_transition_count + 1
			end
		end
		if corridor_transition_count ~= 4 then
			fail("corridor transition evidence population differs")
		end
		local anchor_reference_by_id = {}
		for index = 1, #evidence.anchors do
			anchor_reference_by_id[row_id(evidence.anchors[index])] =
				evidence.anchors[index].reference_y
		end
		local landing_ids = {}
		for index = 1, #source.island_landings do
			landing_ids[source.island_landings[index].id] = true
		end
		local contact_face_authority = build_contact_face_authority(session,
			horizontal, source, evidence)
		local named_level_pair = {}
		for index = 1, #source.hydrology_interfaces do
			local interface = source.hydrology_interfaces[index]
			if interface.upper_id and interface.lower_id then
				local a, b = interface.upper_id, interface.lower_id
				if b < a then a, b = b, a end
				local key = a .. "\t" .. b
				if named_level_pair[key] then fail("duplicate named level pair") end
				named_level_pair[key] = interface.id
			end
		end
		local expected_contact_by_key = {}
		for index = 1, #WET_REACH_CONTACT_EXPECTED do
			local row = WET_REACH_CONTACT_EXPECTED[index]
			local a, b = row[1], row[2]
			if b < a then a, b = b, a end
			local key = a .. "\t" .. b
			if expected_contact_by_key[key] then fail("duplicate expected wet contact") end
			expected_contact_by_key[key] = row
		end
		local wet_contacts = {}
		local function check_contact(id, x, z, other_id, other_x, other_z)
			if not id or not other_id or id == other_id then return end
			local reach, other_reach = hydro_by_id[id], hydro_by_id[other_id]
			if not reach or not other_reach or
					profile_by_id[reach.profile_id].depth <= 0 or
					profile_by_id[other_reach.profile_id].depth <= 0 then return end
			local upper_id, upper_x, upper_z = id, x, z
			local lower_id, lower_x, lower_z = other_id, other_x, other_z
			local upper_offset, lower_offset = reach.water_surface_offset,
				other_reach.water_surface_offset
			if lower_offset > upper_offset or
					(lower_offset == upper_offset and lower_id < upper_id) then
				upper_id, lower_id = lower_id, upper_id
				upper_x, lower_x = lower_x, upper_x
				upper_z, lower_z = lower_z, upper_z
				upper_offset, lower_offset = lower_offset, upper_offset
			end
			local a, b = upper_id, lower_id
			if b < a then a, b = b, a end
			local key = a .. "\t" .. b
			local record = wet_contacts[key]
			if not record then
				record = {upper_id = upper_id, lower_id = lower_id,
					upper_offset = upper_offset, lower_offset = lower_offset,
					edges = {}, upper_points = {}, lower_points = {},
					upper_seen = {}, lower_seen = {}}
				wet_contacts[key] = record
			elseif record.upper_id ~= upper_id or record.lower_id ~= lower_id or
					record.upper_offset ~= upper_offset or
					record.lower_offset ~= lower_offset then
				fail("wet-reach contact orientation differs")
			end
			record.edges[#record.edges + 1] = {upper_x = upper_x,
				upper_z = upper_z, lower_x = lower_x, lower_z = lower_z}
			local upper_key, lower_key = upper_x .. ":" .. upper_z,
				lower_x .. ":" .. lower_z
			if not record.upper_seen[upper_key] then
				record.upper_seen[upper_key] = true
				record.upper_points[#record.upper_points + 1] =
					{x = upper_x, z = upper_z}
			end
			if not record.lower_seen[lower_key] then
				record.lower_seen[lower_key] = true
				record.lower_points[#record.lower_points + 1] =
					{x = lower_x, z = lower_z}
			end
		end
		if mode == "full" then
			local warp = horizontal.warp_proof()
			local above_hydrology = {}
			local query_reuse = {classification = {}}
			for z = warp.min_z, warp.max_z do
				local left_hydrology
				for x = warp.min_x, warp.max_x do
					local row = query_column(session, horizontal, x, z, query_reuse)
					check_column_rules(row, source, horizontal, hydro_by_id,
						profile_by_id, metrics.class_counts, anchor_reference_by_id,
						landing_ids, contact_face_authority and
							contact_face_authority.face_by_coordinate,
						corridor_transition_by_id, corridor_transition_checks)
					local offset = x - warp.min_x + 1
					local hydrology_id = row.classification.hydrology_id
					check_contact(hydrology_id, x, z, left_hydrology, x - 1, z)
					check_contact(hydrology_id, x, z, above_hydrology[offset], x, z - 1)
					left_hydrology = hydrology_id
					above_hydrology[offset] = hydrology_id
					metrics.columns = metrics.columns + 1
				end
				if progress and (z - warp.min_z) % 128 == 0 then
					progress("extent", z - warp.min_z, warp.max_z - warp.min_z + 1)
				end
			end
			local contact_keys = common.sorted_keys(wet_contacts)
			if #contact_keys ~= 12 then fail("wet-reach contact roster count differs") end
			local unequal_count, contact_records = 0, {}
			for index = 1, #contact_keys do
				local key, actual = contact_keys[index], wet_contacts[contact_keys[index]]
				local expected = expected_contact_by_key[key]
				if not expected or actual.upper_id ~= expected[1] or
						actual.lower_id ~= expected[2] or
						actual.upper_offset ~= expected[3] or
						actual.lower_offset ~= expected[4] or
						#actual.edges ~= expected[6] or
						#actual.upper_points ~= expected[7] or
						#actual.lower_points ~= expected[8] then
					fail("wet-reach contact roster differs at " .. key)
				end
				local named_id = named_level_pair[key]
				if named_id ~= expected[5] then
					fail("wet-reach contact interface binding differs at " .. key)
				end
				if actual.upper_offset ~= actual.lower_offset then
					unequal_count = unequal_count + 1
				end
				table.sort(actual.edges, contact_edge_before)
				table.sort(actual.upper_points, contact_point_before)
				table.sort(actual.lower_points, contact_point_before)
				local upper_bounds = contact_point_bounds(actual.upper_points)
				local lower_bounds = contact_point_bounds(actual.lower_points)
				local first = actual.edges[1]
				if not first then fail("wet-reach contact has no edge") end
				contact_records[#contact_records + 1] = {
					upper_id = actual.upper_id, lower_id = actual.lower_id,
					upper_offset = actual.upper_offset,
					lower_offset = actual.lower_offset,
					unequal = actual.upper_offset ~= actual.lower_offset,
					interface_id = named_id,
					edge_count = #actual.edges,
					upper_count = #actual.upper_points,
					lower_count = #actual.lower_points,
					upper_min_x = upper_bounds.min_x,
					upper_max_x = upper_bounds.max_x,
					upper_min_z = upper_bounds.min_z,
					upper_max_z = upper_bounds.max_z,
					lower_min_x = lower_bounds.min_x,
					lower_max_x = lower_bounds.max_x,
					lower_min_z = lower_bounds.min_z,
					lower_max_z = lower_bounds.max_z,
					first_upper_x = first.upper_x,
					first_upper_z = first.upper_z,
					first_lower_x = first.lower_x,
					first_lower_z = first.lower_z,
				}
				if expected[5] and contact_face_authority and
						contact_face_authority.by_id[expected[5]] then
					local face_record = contact_face_authority.by_id[expected[5]]
					if #actual.edges ~= #face_record.contact_edges then
						fail("contact-face full-roster edge population differs")
					end
					for edge_index = 1, #actual.edges do
						actual.edges[edge_index].face_mask_bit = contact_face_mask_bit(
							actual.edges[edge_index].upper_x,
							actual.edges[edge_index].upper_z,
							actual.edges[edge_index].lower_x,
							actual.edges[edge_index].lower_z)
					end
					if not exact_value_equal(actual.edges, face_record.contact_edges) then
						fail("contact-face full-roster edges differ")
					end
				end
			end
			for key in pairs(expected_contact_by_key) do
				if not wet_contacts[key] then fail("wet-reach contact roster misses " .. key) end
			end
			if unequal_count ~= 7 then
				fail("wet-reach unequal contact pair count differs")
			end
			table.sort(contact_records, function(a, b)
				return a.upper_id < b.upper_id or
					a.upper_id == b.upper_id and a.lower_id < b.lower_id
			end)
			local contact_lines = {}
			for index = 1, #contact_records do
				local row = contact_records[index]
				contact_lines[index] = table.concat({"hydrology_contact",
					row.upper_id, row.lower_id, tostring(row.upper_offset),
					tostring(row.lower_offset), tostring(row.unequal),
					row.interface_id or "-", tostring(row.edge_count),
					tostring(row.upper_count), tostring(row.lower_count),
					tostring(row.upper_min_x), tostring(row.upper_max_x),
					tostring(row.upper_min_z), tostring(row.upper_max_z),
					tostring(row.lower_min_x), tostring(row.lower_max_x),
					tostring(row.lower_min_z), tostring(row.lower_max_z),
					tostring(row.first_upper_x), tostring(row.first_upper_z),
					tostring(row.first_lower_x), tostring(row.first_lower_z)}, "\t") .. "\n"
			end
			local contact_digest = common.digest_hex(validated_raw_sha256,
				table.concat(contact_lines))
			if contact_digest ~= r2.bindings.hydrology_contact_roster_sha256 then
				fail("wet-reach contact roster digest differs from R2")
			end
			metrics.wet_reach_contact_pairs = #contact_keys
			metrics.unequal_interface_pairs = unequal_count
			metrics.hydrology_contact_roster_sha256 = contact_digest
			metrics.hydrology_contacts = contact_records
		else
			local points = representative_points(source, horizontal, evidence)
			for index = 1, #points do
				local point = points[index]
				local row = query_column(session, horizontal, point.x, point.z)
				check_column_rules(row, source, horizontal, hydro_by_id,
					profile_by_id, metrics.class_counts, anchor_reference_by_id,
					landing_ids, contact_face_authority and
						contact_face_authority.face_by_coordinate,
					corridor_transition_by_id, corridor_transition_checks)
				metrics.columns = metrics.columns + 1
			end
		end
		for transition_id, checks in pairs(corridor_transition_checks) do
			if checks.columns == 0 or checks.beds == 0 or
					checks.beds + checks.solid_overrides ~= checks.columns then
				fail("corridor transition checks are incomplete at " .. transition_id)
			end
		end
		check_outside(session, horizontal, source, metrics.class_counts)
		check_anchors(session, horizontal, source, metrics)
		check_interfaces(session, horizontal, source, metrics,
			contact_face_authority)
		check_dry_channel(session, horizontal, source, metrics)
		check_paths(session, horizontal, source, evidence, mode == "full", metrics)
		check_coastal_cores(session, horizontal, source, r2, metrics)
		local after = session.metrics()
		if after.query_sha256_calls ~= 0 or after.query_lattice_constructions ~= 0 then
			fail("query-time construction counters changed during validation")
		end
		return metrics
	end

	function validator.deterministic_evidence_projection(evidence)
		local result = {
			schema = evidence.schema,
			height_schema = evidence.height_schema,
			base_lattice_digest = evidence.base_lattice_digest,
			relief_lattice_digest = evidence.relief_lattice_digest,
			octave_lattice_digest = evidence.octave_lattice_digest,
			relief_roots = exact_copy(evidence.relief_roots),
			octave_lattices = exact_copy(evidence.octave_lattices),
			primary_profiles = exact_copy(evidence.primary_profiles),
			landmarks = exact_copy(evidence.landmarks),
			stations = exact_copy(evidence.stations),
			anchors = exact_copy(evidence.anchors),
			hard_protection = exact_copy(evidence.hard_protection),
			routes = exact_copy(evidence.routes),
			route_exact_pins = exact_copy(evidence.route_exact_pins),
			route_water_lower_bounds = exact_copy(evidence.route_water_lower_bounds),
			route_raise_witnesses = exact_copy(evidence.route_raise_witnesses),
			ford_approaches = exact_copy(evidence.ford_approaches),
			ford_approach_summaries = exact_copy(evidence.ford_approach_summaries),
			named_water_operations = exact_copy(evidence.named_water_operations),
			derived_water_runs = exact_copy(evidence.derived_water_runs),
			landings = exact_copy(evidence.landings),
			tunnels = exact_copy(evidence.tunnels),
			visible_surface_classification_digest =
				evidence.visible_surface_classification_digest,
			hydrology = exact_copy(evidence.hydrology),
			interfaces = exact_copy(evidence.interfaces),
			hydrology_interface_population =
				exact_copy(evidence.hydrology_interface_population),
			wet_reach_contact_pairs = evidence.wet_reach_contact_pairs,
			unequal_interface_pairs = evidence.unequal_interface_pairs,
			contact_face_waterfalls =
				exact_copy(evidence.contact_face_waterfalls),
			exterior_witnesses = exact_copy(evidence.exterior_witnesses),
			coastal_cores = exact_copy(evidence.coastal_cores),
			source_cut_fill_limits_consumed =
				evidence.source_cut_fill_limits_consumed,
			operation_counts = exact_copy(evidence.operation_counts),
			operation_digest = evidence.operation_digest,
			route_digest = evidence.route_digest,
		}
		return result
	end

	return validator
end
