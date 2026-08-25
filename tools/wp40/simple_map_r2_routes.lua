-- Pure R2 route and transport validation for the WP40 simple map.
--
-- Planned-water route footprints are accepted as deterministic inputs for
-- later bridge/ford/causeway grading.  This module records those footprints;
-- it never repairs, snaps, widens or otherwise mutates the source or session.

return function(source, session)
	local result = {
		schema = "grug_wp40_simple_map_r2_routes_result_v1",
		ok = false,
		violations = {},
		metrics = {
			route_count = 0,
			route_class_counts = {primary = 0, secondary = 0, trail = 0},
			route_pair_count = 0,
			route_corridor_columns = 0,
			route_land_columns = 0,
			route_declared_crossing_columns = 0,
			route_derived_water_columns = 0,
			route_automatic_grading_columns = 0,
			route_off_land_columns = 0,
			route_third_zone_columns = 0,
			route_difficulty_edges = 0,
			route_max_adjacent_difficulty_delta = 0,
			route_difficulty_violations = 0,
			crossing_count = 0,
			poi_spur_count = 0,
			poi_corridor_columns = 0,
			poi_derived_water_columns = 0,
			poi_off_land_columns = 0,
			poi_wrong_zone_columns = 0,
			ingress_count = 0,
			ingress_corridor_columns = 0,
			ingress_declared_crossing_columns = 0,
			ingress_derived_water_columns = 0,
			ingress_automatic_grading_columns = 0,
			ingress_off_land_columns = 0,
			ingress_neighbor_contact_columns = 0,
			boat_count = 0,
			boat_corridor_columns = 0,
			boat_land_columns = 0,
			boat_water_columns = 0,
			boat_channel_columns = 0,
			boat_wrong_land_columns = 0,
		},
		witnesses = {},
	}

	local MAX_WITNESSES_PER_SUBJECT = 8
	local MAX_CORRIDOR_CANDIDATES = 5000000
	local witness_counts = {}
	local aggregates = {}

	local function value_text(value)
		if value == nil then return "nil" end
		if type(value) == "boolean" then return value and "true" or "false" end
		return tostring(value)
	end

	local function add_violation(code, subject, expected, actual, count)
		result.violations[#result.violations + 1] = {
			code = code,
			subject = subject or "-",
			expected = value_text(expected),
			actual = value_text(actual),
			count = count or 1,
		}
	end

	local function witness_key(code, subject)
		return code .. "\0" .. (subject or "-")
	end

	local function add_witness(code, subject, x, z, classification, extra)
		local key = witness_key(code, subject)
		local count = witness_counts[key] or 0
		if count >= MAX_WITNESSES_PER_SUBJECT then return end
		witness_counts[key] = count + 1
		local row = {
			code = code,
			subject = subject or "-",
			x = x,
			z = z,
		}
		if classification then
			row.water_class = classification.water_class
			row.zone_numeric_id = classification.zone_numeric_id
			row.hydrology_id = classification.hydrology_id
			row.channel_id = classification.channel_id
			row.bay_id = classification.bay_id
			row.civic_water = classification.civic_water or nil
		end
		if extra then
			for key_name, value in pairs(extra) do row[key_name] = value end
		end
		result.witnesses[#result.witnesses + 1] = row
	end

	local function aggregate(code, subject, expected, actual, x, z,
			classification, extra)
		local key = witness_key(code, subject)
		local row = aggregates[key]
		if not row then
			row = {code = code, subject = subject or "-", expected = expected,
				actual = actual, count = 0}
			aggregates[key] = row
		end
		row.count = row.count + 1
		add_witness(code, subject, x, z, classification, extra)
	end

	local function derived_water_witness(code, subject, x, z, classification,
			crossing_id, footprint_policy)
		local extra = {
			grading_policy = crossing_id and "declared_crossing_surface" or
				"automatic_bridge_ford_causeway_surface",
			crossing_id = crossing_id or false,
		}
		if footprint_policy then extra.footprint_policy = footprint_policy end
		add_witness(code, subject, x, z, classification, extra)
	end

	local function integer(value)
		return type(value) == "number" and value == value and
			value ~= math.huge and value ~= -math.huge and value % 1 == 0
	end

	local function point_valid(point)
		return type(point) == "table" and integer(point.x) and integer(point.z)
	end

	local function same_point(a, b)
		return point_valid(a) and point_valid(b) and a.x == b.x and a.z == b.z
	end

	local function closed_pair(a, b)
		if not integer(a) or not integer(b) then return nil end
		if a > b then a, b = b, a end
		return ("%02d:%02d"):format(a, b)
	end

	local function dense_count(values)
		if type(values) ~= "table" then return 0, false end
		local count = #values
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				return count, false
			end
		end
		return count, true
	end

	local function point_on_polyline(point, points)
		return point_valid(point) and type(points) == "table" and
			type(session.polyline_point_member) == "function" and
			session.polyline_point_member(point.x,point.z,points)
	end

	local function sequence_valid(points)
		local count, dense = dense_count(points)
		if not dense or count < 2 then return false end
		for index = 1, count do
			if not point_valid(points[index]) then return false end
			if index > 1 and same_point(points[index - 1], points[index]) then
				return false
			end
		end
		return true
	end

	if type(source) ~= "table" then
		add_violation("source_missing", "source", "table", type(source))
		result.metrics.violation_count = #result.violations
		return result
	end
	if type(session) ~= "table" then
		add_violation("session_missing", "session", "table", type(session))
		result.metrics.violation_count = #result.violations
		return result
	end
	if type(session.classification_at) ~= "function" then
		add_violation("classification_api_missing", "session.classification_at",
			"function", type(session.classification_at))
	end
	if type(session.difficulty_at) ~= "function" then
		add_violation("difficulty_api_missing", "session.difficulty_at",
			"function", type(session.difficulty_at))
	end
	if type(session.polyline_corridor_member) ~= "function" then
		add_violation("corridor_api_missing", "session.polyline_corridor_member",
			"function", type(session.polyline_corridor_member))
	end
	if type(session.path_corridor_member) ~= "function" then
		add_violation("corridor_api_missing", "session.path_corridor_member",
			"function", type(session.path_corridor_member))
	end
	if type(session.polyline_point_member) ~= "function" or
			type(session.polygon_member) ~= "function" then
		add_violation("exact_geometry_api_missing", "session",
			"polyline_point_member and polygon_member", "missing")
	end

	local zones = type(source.zones) == "table" and source.zones or {}
	local station_by_id = {}
	local station_count, stations_dense = dense_count(source.route_stations)
	if not stations_dense or station_count ~= 38 then
		add_violation("route_station_roster", "route_stations", 38, station_count)
	end
	for index = 1, station_count do
		local station = source.route_stations[index]
		local zone = type(station) == "table" and zones[station.zone_numeric_id] or nil
		local subject = type(station) == "table" and station.id or
			("route_station_%02d"):format(index)
		if type(station) ~= "table" or type(station.id) ~= "string" or
				station_by_id[station.id] then
			add_violation("route_station_identity", subject, "unique string id", "invalid")
		elseif not zone or station.kind ~= "hub" or
				not same_point(station.position, zone.hub) then
			add_violation("route_station_endpoint", subject,
				"matching zone hub station", "mismatch")
		else
			station_by_id[station.id] = station
		end
	end

	local expected_profiles = {
		primary = {surface_width = 7, corridor_width = 16, kind = "road"},
		secondary = {surface_width = 5, corridor_width = 12, kind = "road"},
		trail = {surface_width = 3, corridor_width = 8, kind = "trail"},
	}
	local route_by_id, route_pair_seen = {}, {}
	local route_count, routes_dense = dense_count(source.routes)
	result.metrics.route_count = route_count
	if not routes_dense or route_count ~= 57 then
		add_violation("route_roster", "routes", 57, route_count)
	end
	local route_neighbor_offsets={{-1,0},{1,0},{0,-1},{0,1}}
	for index = 1, route_count do
		local route = source.routes[index]
		local expected_id = ("route_%03d"):format(index)
		local subject = type(route) == "table" and value_text(route.id) or expected_id
		if type(route) ~= "table" then
			add_violation("route_record", subject, "table", type(route))
		else
			local profile = expected_profiles[route.class]
			if route.numeric_id ~= index or route.id ~= expected_id or
					type(route.id) ~= "string" or route_by_id[route.id] then
				add_violation("route_identity", subject, expected_id, route.id)
			end
			if not profile then
				add_violation("route_class", subject, "primary/secondary/trail", route.class)
			else
				result.metrics.route_class_counts[route.class] =
					result.metrics.route_class_counts[route.class] + 1
				if route.kind ~= profile.kind or
						route.surface_width ~= profile.surface_width or
						route.corridor_width ~= profile.corridor_width then
					add_violation("route_profile", subject,
						("%s:%d/%d"):format(profile.kind, profile.surface_width,
							profile.corridor_width),
						("%s:%s/%s"):format(value_text(route.kind),
							value_text(route.surface_width),
							value_text(route.corridor_width)))
				end
			end
			if route.provisional ~= false then
				add_violation("route_not_frozen", subject, false, route.provisional)
			end
			local zone_a, zone_b = zones[route.zone_a], zones[route.zone_b]
			local station_a = station_by_id[route.station_a_id]
			local station_b = station_by_id[route.station_b_id]
			if not zone_a or not zone_b or route.zone_a == route.zone_b then
				add_violation("route_zone_reference", subject,
					"two distinct known zones", closed_pair(route.zone_a, route.zone_b))
			end
			local pair = closed_pair(route.zone_a, route.zone_b)
			if not pair or route_pair_seen[pair] then
				add_violation("route_pair_identity", subject, "unique closed pair", pair)
			elseif type(route.id) == "string" then
				route_pair_seen[pair] = route.id
				result.metrics.route_pair_count = result.metrics.route_pair_count + 1
			end
			if not station_a or not station_b or
					station_a.zone_numeric_id ~= route.zone_a or
					station_b.zone_numeric_id ~= route.zone_b then
				add_violation("route_station_reference", subject,
					"endpoint stations for route zones", "mismatch")
			end
			if not sequence_valid(route.centreline) then
				add_violation("route_centreline", subject,
					"dense integer polyline", "invalid")
			elseif not station_a or not station_b or
					not same_point(route.centreline[1], station_a.position) or
					not same_point(route.centreline[#route.centreline], station_b.position) then
				add_violation("route_endpoint", subject,
					"centreline pinned to both stations", "mismatch")
			end
			if type(route.id) == "string" and not route_by_id[route.id] then
				route_by_id[route.id] = route
			end
		end
	end
	for class, expected in pairs({primary = 30, secondary = 24, trail = 3}) do
		if result.metrics.route_class_counts[class] ~= expected then
			add_violation("route_class_count", class, expected,
				result.metrics.route_class_counts[class])
		end
	end

	local hydrology_by_id = {}
	if type(source.hydrology) == "table" then
		for index = 1, #source.hydrology do
			local row = source.hydrology[index]
			if type(row) == "table" and type(row.id) == "string" then
				hydrology_by_id[row.id] = row
			end
		end
	end
	local hydrology_interface_by_crossing = {}
	if type(source.hydrology_interfaces) == "table" then
		for index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[index]
			if type(row) == "table" and type(row.route_interface_id) == "string" then
				local values = hydrology_interface_by_crossing[row.route_interface_id]
				if not values then values = {} hydrology_interface_by_crossing[row.route_interface_id] = values end
				values[#values + 1] = row
			end
		end
	end

	local crossing_by_route = {}
	local crossing_id_seen = {}
	local crossing_count, crossings_dense = dense_count(source.crossing_interfaces)
	result.metrics.crossing_count = crossing_count
	if not crossings_dense or crossing_count ~= 9 then
		add_violation("crossing_roster", "crossing_interfaces", 9, crossing_count)
	end
	local crossing_kind = {bridge = true, ford = true, tunnel = true,
		causeway = true, ferry = true}
	for index = 1, crossing_count do
		local crossing = source.crossing_interfaces[index]
		local subject = type(crossing) == "table" and value_text(crossing.id) or
			("crossing_%02d"):format(index)
		if type(crossing) ~= "table" then
			add_violation("crossing_record", subject, "table", type(crossing))
		else
			local route = route_by_id[crossing.route_id]
			if type(crossing.id) ~= "string" or crossing_id_seen[crossing.id] then
				add_violation("crossing_identity", subject, "unique string id", crossing.id)
			else crossing_id_seen[crossing.id] = true end
			if not route or not crossing_kind[crossing.kind] or
					not point_valid(crossing.position) then
				add_violation("crossing_reference", subject,
					"known route/kind/integer position", "invalid")
			elseif not point_on_polyline(crossing.position, route.centreline) then
				add_violation("crossing_route_incidence", subject,
					"position on route centreline", "off-route")
			end
			local interfaces = hydrology_interface_by_crossing[crossing.id] or {}
			local expected_interface_count = crossing.kind == "tunnel" and 0 or 1
			if #interfaces ~= expected_interface_count then
				add_violation("crossing_hydrology_multiplicity", subject,
					expected_interface_count, #interfaces)
			end
			local interface = interfaces[1]
			if interface then
				if not hydrology_by_id[interface.hydrology_id] or
						not same_point(interface.position, crossing.position) or
						interface.kind ~= crossing.kind then
					add_violation("crossing_hydrology_binding", subject,
						"matching kind/position/known hydrology", "mismatch")
				end
				local polygon = crossing.authorization_polygon
				local polygon_valid = type(polygon) == "table" and #polygon >= 3
				if polygon_valid then
					for point_index = 1, #polygon do
						if not point_valid(polygon[point_index]) then polygon_valid = false break end
					end
				end
				if not polygon_valid then
					add_violation("crossing_authorization_geometry_missing", subject,
						"explicit integer authorization_polygon", "missing")
				elseif not session.polygon_member(crossing.position.x,
						crossing.position.z,polygon) then
					add_violation("crossing_authorization_position", subject,
						"declared position inside authorization polygon", "outside")
				end
				if point_valid(crossing.position) and
						type(session.classification_at) == "function" then
					local classification = session.classification_at(
						crossing.position.x, crossing.position.z)
					if classification.hydrology_id ~= interface.hydrology_id then
						add_violation("crossing_hydrology_incidence", subject,
							interface.hydrology_id, classification.hydrology_id)
					end
				end
				if polygon_valid and route then
					local values = crossing_by_route[route.id]
					if not values then values = {} crossing_by_route[route.id] = values end
					values[#values + 1] = {crossing = crossing, interface = interface,
						polygon = polygon}
				end
			end
		end
	end

	local function authorized_water(route_id, x, z, classification)
		local values = crossing_by_route[route_id]
		if not values or not classification.hydrology_id then return nil end
		for index = 1, #values do
			local value = values[index]
			if value.interface.hydrology_id == classification.hydrology_id and
					session.polygon_member(x,z,value.polygon) then
				return value.crossing.id
			end
		end
		return nil
	end

	local function scan_corridor(subject, points, width, path_id, visitor)
		if type(session.classification_at) ~= "function" or
				type(session.polyline_corridor_member) ~= "function" or
				(path_id and type(session.path_corridor_member) ~= "function") then
			return false
		end
		if not sequence_valid(points) or not integer(width) or width <= 0 or width > 256 then
			add_violation("corridor_scan_input", subject,
				"integer polyline and width 1..256", "invalid")
			return false
		end
		local pad = math.floor(width / 2) + 1
		local candidate_count = 0
		for segment = 1, #points - 1 do
			local a, b = points[segment], points[segment + 1]
			candidate_count = candidate_count +
				(math.abs(a.x - b.x) + 2 * pad + 1) *
				(math.abs(a.z - b.z) + 2 * pad + 1)
		end
		if candidate_count > MAX_CORRIDOR_CANDIDATES then
			add_violation("corridor_scan_bound_exceeded", subject,
				MAX_CORRIDOR_CANDIDATES, candidate_count)
			return false
		end
		local visited = {}
		for segment = 1, #points - 1 do
			local a, b = points[segment], points[segment + 1]
			local min_x = math.min(a.x, b.x) - pad
			local max_x = math.max(a.x, b.x) + pad
			local min_z = math.min(a.z, b.z) - pad
			local max_z = math.max(a.z, b.z) + pad
			for z = min_z, max_z do
				for x = min_x, max_x do
					local key = x .. ":" .. z
					if not visited[key] then
						local member
						if path_id then member = session.path_corridor_member(path_id, x, z)
						else member = session.polyline_corridor_member(x, z, points, width) end
						if member then
							visited[key] = true
							visitor(x, z, session.classification_at(x, z))
						end
					end
				end
			end
		end
		return true
	end

	for index = 1, route_count do
		local route = source.routes[index]
		if type(route) == "table" and type(route.id) == "string" and
				sequence_valid(route.centreline) and integer(route.corridor_width) then
			local route_difficulty={}
			scan_corridor(route.id, route.centreline, route.corridor_width, route.id,
				function(x, z, classification)
					result.metrics.route_corridor_columns =
						result.metrics.route_corridor_columns + 1
					local owner = classification.zone_numeric_id
					if owner and owner ~= route.zone_a and owner ~= route.zone_b then
						result.metrics.route_third_zone_columns =
							result.metrics.route_third_zone_columns + 1
						add_witness("route_third_zone", route.id, x, z,
							classification, {
								expected_route_pair = closed_pair(route.zone_a, route.zone_b),
								observed_zone_numeric_id = owner,
							})
					end
					if classification.water_class == "land" then
						result.metrics.route_land_columns =
							result.metrics.route_land_columns + 1
					elseif classification.water_class == "planned_water" then
						result.metrics.route_derived_water_columns =
							result.metrics.route_derived_water_columns + 1
						local crossing_id = authorized_water(route.id, x, z, classification)
						if crossing_id then
							result.metrics.route_declared_crossing_columns =
								result.metrics.route_declared_crossing_columns + 1
						else
							result.metrics.route_automatic_grading_columns =
								result.metrics.route_automatic_grading_columns + 1
						end
						derived_water_witness("route_derived_water", route.id,
							x, z, classification, crossing_id)
					else
						result.metrics.route_off_land_columns =
							result.metrics.route_off_land_columns + 1
						aggregate("route_off_land", route.id,
							"land or planned_water",
							classification.water_class, x, z, classification)
					end
					if (classification.water_class == "land" or
							classification.water_class == "planned_water") and
							type(session.difficulty_at) == "function" then
						local difficulty=session.difficulty_at(x,z)
						if not integer(difficulty) then
							add_violation("route_difficulty_missing",route.id,
								"integer difficulty",difficulty)
						else
							for _,offset in ipairs(route_neighbor_offsets) do
								local neighbor_x,neighbor_z=x+offset[1],z+offset[2]
								local neighbor_difficulty=route_difficulty[
									neighbor_x .. ":" .. neighbor_z]
								if neighbor_difficulty then
									local delta=math.abs(difficulty-neighbor_difficulty)
									result.metrics.route_difficulty_edges=
										result.metrics.route_difficulty_edges+1
									result.metrics.route_max_adjacent_difficulty_delta=math.max(
										result.metrics.route_max_adjacent_difficulty_delta,delta)
									if delta > 2 then
										result.metrics.route_difficulty_violations=
											result.metrics.route_difficulty_violations+1
										aggregate("route_difficulty_delta",route.id,
											"<=2",delta,x,z,classification,{
												neighbor_x=neighbor_x,neighbor_z=neighbor_z,
												neighbor_difficulty=neighbor_difficulty,
												difficulty=difficulty})
									end
								end
							end
							route_difficulty[x .. ":" .. z]=difficulty
						end
					end
				end)
		end
	end
	for _, route_id in ipairs({"route_043", "route_049"}) do
		local found = false
		local values = crossing_by_route[route_id] or {}
		for index = 1, #values do
			if values[index].interface.hydrology_id == "hydro_gravesalt_pans" then
				found = true break
			end
		end
		if not found then
			add_violation("gravesalt_crossing_declaration_missing", route_id,
				"spatial declaration for hydro_gravesalt_pans", "missing")
		end
	end

	local anchor_by_id = {}
	if type(source.anchors) == "table" then
		for index = 1, #source.anchors do
			local anchor = source.anchors[index]
			if type(anchor) == "table" and type(anchor.id) == "string" then
				anchor_by_id[anchor.id] = anchor
			end
		end
	end
	local exclusion_by_source = {}
	if type(source.claim_exclusions) == "table" then
		for index = 1, #source.claim_exclusions do
			local exclusion = source.claim_exclusions[index]
			if type(exclusion) == "table" and type(exclusion.source_id) == "string" then
				local values = exclusion_by_source[exclusion.source_id]
				if not values then values = {} exclusion_by_source[exclusion.source_id] = values end
				values[#values + 1] = exclusion
			end
		end
	end
	local spur_count, spurs_dense = dense_count(source.poi_spurs)
	result.metrics.poi_spur_count = spur_count
	if not spurs_dense or spur_count ~= 74 then
		add_violation("poi_spur_roster", "poi_spurs", 74, spur_count)
	end
	for index = 1, spur_count do
		local spur = source.poi_spurs[index]
		local subject = type(spur) == "table" and value_text(spur.id) or
			("poi_spur_%03d"):format(index)
		local anchor = type(spur) == "table" and anchor_by_id[spur.anchor_id] or nil
		local zone = anchor and zones[anchor.zone_numeric_id] or nil
		local exclusions = type(spur) == "table" and exclusion_by_source[spur.id] or nil
		local exclusion = exclusions and exclusions[1] or nil
		if type(spur) ~= "table" or type(spur.id) ~= "string" or not anchor or
				not zone then
			add_violation("poi_spur_reference", subject,
				"known candidate anchor and zone", "invalid")
		elseif not exclusions or #exclusions ~= 1 or not exclusion or
				exclusion.recipe_id ~= "exclude_route_corridor_v1" or
				not integer(exclusion.corridor_width) then
			add_violation("poi_spur_corridor_policy_missing", subject,
				"one route-corridor claim exclusion with integer width", "missing")
		else
			local path_count, paths_dense = dense_count(spur.candidate_paths)
			local candidates = anchor.candidates
			if not paths_dense or type(candidates) ~= "table" or
					path_count ~= #candidates then
				add_violation("poi_spur_candidate_roster", subject,
					value_text(type(candidates) == "table" and #candidates or nil),
					path_count)
			else
				for candidate_index = 1, path_count do
					local path = spur.candidate_paths[candidate_index]
					local path_subject = subject .. ":" .. candidate_index
					if not sequence_valid(path) or
							not same_point(path[1], candidates[candidate_index]) or
							not same_point(path[#path], zone.hub) then
						add_violation("poi_spur_endpoint", path_subject,
							"candidate to intended zone hub", "mismatch")
					else
						scan_corridor(path_subject, path, exclusion.corridor_width, nil,
							function(x, z, classification)
								result.metrics.poi_corridor_columns =
									result.metrics.poi_corridor_columns + 1
								if classification.water_class == "planned_water" then
									result.metrics.poi_derived_water_columns =
										result.metrics.poi_derived_water_columns + 1
									derived_water_witness("poi_spur_derived_water",
										path_subject, x, z, classification, nil)
								elseif classification.water_class ~= "land" then
									result.metrics.poi_off_land_columns =
										result.metrics.poi_off_land_columns + 1
									aggregate("poi_spur_off_land", path_subject,
										"land or planned_water", classification.water_class,
										x, z, classification)
								end
								if classification.zone_numeric_id ~= anchor.zone_numeric_id then
									result.metrics.poi_wrong_zone_columns =
										result.metrics.poi_wrong_zone_columns + 1
									aggregate("poi_spur_wrong_zone", path_subject,
										anchor.zone_numeric_id,
										classification.zone_numeric_id,
										x, z, classification)
								end
							end)
					end
				end
			end
		end
	end

	local expected_ingresses = {
		{"ingress_dur_brannoc", "anchor_007", "route_003", "route_043"},
		{"ingress_highcourt", "anchor_008", "route_006", "route_046"},
		{"ingress_lethariel", "anchor_009", "route_009", "route_048"},
		{"ingress_nhal_veyr", "anchor_010", "route_012", "route_049"},
		{"ingress_gor_drazhak", "anchor_011", "route_015", "route_052"},
		{"ingress_kezamba", "anchor_012", "route_018", "route_054"},
	}
	local ingress_count, ingresses_dense = dense_count(source.capital_ingresses)
	result.metrics.ingress_count = ingress_count
	if not ingresses_dense or ingress_count ~= 6 then
		add_violation("capital_ingress_roster", "capital_ingresses", 6, ingress_count)
	end
	local hard_by_ingress = {}
	if type(source.hard_protection) == "table" then
		for index = 1, #source.hard_protection do
			local hard = source.hard_protection[index]
			if type(hard) == "table" and type(hard.ingress_id) == "string" then
				local values = hard_by_ingress[hard.ingress_id]
				if not values then values = {} hard_by_ingress[hard.ingress_id] = values end
				values[#values + 1] = hard
			end
		end
	end
	for index = 1, ingress_count do
		local ingress = source.capital_ingresses[index]
		local expected = expected_ingresses[index]
		local subject = type(ingress) == "table" and value_text(ingress.id) or
			("capital_ingress_%02d"):format(index)
		if type(ingress) ~= "table" or not expected then
			add_violation("capital_ingress_record", subject, "canonical row", "invalid")
		else
			local route_ids = ingress.route_ids
			if ingress.id ~= expected[1] or ingress.capital_anchor_id ~= expected[2] or
					type(route_ids) ~= "table" or #route_ids ~= 2 or
					route_ids[1] ~= expected[3] or route_ids[2] ~= expected[4] or
					ingress.total_width ~= 128 then
				add_violation("capital_ingress_identity", subject,
					table.concat(expected, ":") .. ":128", "changed")
			end
			local route_a = type(route_ids) == "table" and route_by_id[route_ids[1]] or nil
			local route_b = type(route_ids) == "table" and route_by_id[route_ids[2]] or nil
			local anchor = anchor_by_id[ingress.capital_anchor_id]
			local joined = route_a and route_b and sequence_valid(route_a.centreline) and
				sequence_valid(route_b.centreline) and
				same_point(route_a.centreline[#route_a.centreline], route_b.centreline[1])
			local holy = source.holy_grounds
			local terminal = route_b and route_b.centreline[#route_b.centreline] or nil
			local terminal_holy = point_valid(terminal) and type(holy) == "table" and
				terminal.x >= holy.min_x and terminal.x <= holy.max_x and
				terminal.z >= holy.min_z and terminal.z <= holy.max_z
			if not route_a or not route_b or route_a.class ~= "primary" or
					route_b.class ~= "secondary" or not joined or not anchor or
					not same_point(route_a.centreline[1], anchor.position) or
					not terminal_holy then
				add_violation("capital_ingress_continuity", subject,
					"capital anchor through joined primary/secondary routes into Holy rectangle",
					"mismatch")
			else
				local points = {}
				for point_index = 1, #route_a.centreline do
					points[#points + 1] = route_a.centreline[point_index]
				end
				for point_index = 2, #route_b.centreline do
					points[#points + 1] = route_b.centreline[point_index]
				end
				local allowed_zones = {
					[route_a.zone_a] = true, [route_a.zone_b] = true,
					[route_b.zone_a] = true, [route_b.zone_b] = true,
				}
				scan_corridor(subject, points, ingress.total_width, nil,
					function(x, z, classification)
						result.metrics.ingress_corridor_columns =
							result.metrics.ingress_corridor_columns + 1
						if classification.zone_numeric_id and
								not allowed_zones[classification.zone_numeric_id] then
							result.metrics.ingress_neighbor_contact_columns =
								result.metrics.ingress_neighbor_contact_columns + 1
							add_witness("capital_ingress_neighbor_contact", subject,
								x, z, classification, {
									observed_zone_numeric_id =
										classification.zone_numeric_id,
								})
						end
						if classification.water_class == "planned_water" then
							result.metrics.ingress_derived_water_columns =
								result.metrics.ingress_derived_water_columns + 1
							local crossing_id = authorized_water(route_a.id, x, z, classification) or
								authorized_water(route_b.id, x, z, classification)
							if crossing_id then
								result.metrics.ingress_declared_crossing_columns =
									result.metrics.ingress_declared_crossing_columns + 1
							else
								result.metrics.ingress_automatic_grading_columns =
									result.metrics.ingress_automatic_grading_columns + 1
							end
							derived_water_witness("capital_ingress_derived_water",
								subject, x, z, classification, crossing_id,
								"hard_claim_protection_around_traversable_route_axis")
						elseif classification.water_class ~= "land" then
							result.metrics.ingress_off_land_columns =
								result.metrics.ingress_off_land_columns + 1
							aggregate("capital_ingress_off_land", subject,
								"land or planned_water", classification.water_class,
								x, z, classification)
						end
					end)
			end
			local hard_values = hard_by_ingress[ingress.id] or {}
			local hard = hard_values[1]
			if #hard_values ~= 1 or not hard or
					hard.recipe_id ~= "hard_capital_ingress_corridor_v1" or
					hard.source_anchor_id ~= ingress.capital_anchor_id or
					hard.active ~= true or hard.status ~= "active" or
					type(hard.route_ids) ~= "table" or
					type(ingress.route_ids) ~= "table" or
					hard.route_ids[1] ~= ingress.route_ids[1] or
					hard.route_ids[2] ~= ingress.route_ids[2] then
				add_violation("capital_ingress_hard_binding", subject,
					"one matching active hard corridor", #hard_values)
			else
				local exclusions = exclusion_by_source[hard.id] or {}
				if #exclusions ~= 1 or
						exclusions[1].recipe_id ~= "exclude_active_core_v1" then
					add_violation("capital_ingress_claim_binding", subject,
						"one active-hard claim exclusion", #exclusions)
				end
			end
		end
	end

	local expected_boats = {
		{"boat_wyrmglass_south", 34, 33, -125},
		{"boat_wyrmglass_north", 34, 33, 125},
		{"boat_stormscale_south", 37, 38, -125},
		{"boat_stormscale_north", 37, 38, 125},
	}
	local boat_count, boats_dense = dense_count(source.boat_paths)
	result.metrics.boat_count = boat_count
	if not boats_dense or boat_count ~= 4 then
		add_violation("boat_roster", "boat_paths", 4, boat_count)
	end
	local landing_id_seen, landing_position_seen, boat_by_id = {}, {}, {}
	if type(source.island_landings) ~= "table" then
		add_violation("boat_landing_roster_missing", "island_landings",
			"explicit landing records", "missing")
	end
	for index = 1, boat_count do
		local boat = source.boat_paths[index]
		local expected = expected_boats[index]
		local subject = type(boat) == "table" and value_text(boat.id) or
			("boat_%02d"):format(index)
		if type(boat) ~= "table" or not expected then
			add_violation("boat_record", subject, "canonical boat row", "invalid")
		else
			boat_by_id[boat.id]=boat
			if boat.id ~= expected[1] or boat.kind ~= "boat" or
					boat.from_zone ~= expected[2] or boat.to_zone ~= expected[3] or
					boat.width ~= 96 or not sequence_valid(boat.centreline) then
				add_violation("boat_identity", subject,
					("%s:%d:%d:%d:96"):format(expected[1], expected[2],
						expected[3], expected[4]), "changed")
			else
				for point_index = 1, #boat.centreline do
					if boat.centreline[point_index].z ~= expected[4] then
						add_violation("boat_approach_axis", subject,
							"centreline fixed at z=" .. expected[4],
							boat.centreline[point_index].z)
						break
					end
				end
				local first, last = boat.centreline[1], boat.centreline[#boat.centreline]
				if type(session.classification_at) == "function" then
					local first_class = session.classification_at(first.x, first.z)
					local last_class = session.classification_at(last.x, last.z)
					if first_class.water_class ~= "land" or
							first_class.zone_numeric_id ~= boat.from_zone or
							last_class.water_class ~= "land" or
							last_class.zone_numeric_id ~= boat.to_zone then
						add_violation("boat_endpoint_land", subject,
							"from-zone land to island-zone landing land", "mismatch")
					end
				end
				local landing_key = last.x .. ":" .. last.z
				if landing_position_seen[landing_key] then
					add_violation("boat_distinct_landing", subject,
						"unique terminal coordinate", landing_key)
				else landing_position_seen[landing_key] = true end
				if type(boat.landing_id) ~= "string" or boat.landing_id == "" then
					add_violation("boat_landing_identity_missing", subject,
						"explicit landing_id", boat.landing_id)
				elseif landing_id_seen[boat.landing_id] then
					add_violation("boat_distinct_landing", subject,
						"unique landing_id", boat.landing_id)
				else landing_id_seen[boat.landing_id] = true end
				scan_corridor(subject, boat.centreline, boat.width, boat.id,
					function(x, z, classification)
						result.metrics.boat_corridor_columns =
							result.metrics.boat_corridor_columns + 1
						if classification.water_class == "land" then
							result.metrics.boat_land_columns =
								result.metrics.boat_land_columns + 1
							if classification.zone_numeric_id ~= boat.from_zone and
									classification.zone_numeric_id ~= boat.to_zone then
								result.metrics.boat_wrong_land_columns =
									result.metrics.boat_wrong_land_columns + 1
								aggregate("boat_wrong_land", subject,
									closed_pair(boat.from_zone, boat.to_zone),
									classification.zone_numeric_id, x, z, classification)
							end
						else
							result.metrics.boat_water_columns =
								result.metrics.boat_water_columns + 1
							if classification.water_class == "immutable_dragon_channel" then
								result.metrics.boat_channel_columns =
									result.metrics.boat_channel_columns + 1
							end
						end
					end)
			end
		end
	end
	if type(source.boat_parity_policy) ~= "table" then
		add_violation("boat_parity_policy_missing", "boat_parity_policy",
			"precise faction-oriented route-length policy with <=1/10 bound", "missing")
	else
		local policy=source.boat_parity_policy
		if policy.id ~= "paired_axis_aligned_node_run_v1" or
				policy.metric ~= "axis_aligned_polyline_node_run" or
				policy.maximum_difference_numerator ~= 1 or
				policy.maximum_difference_denominator ~= 10 or
				type(policy.pairs) ~= "table" or #policy.pairs ~= 2 then
			add_violation("boat_parity_policy_unknown", "boat_parity_policy",
				"paired_axis_aligned_node_run_v1 with 1/10 bound",
				value_text(policy.id))
		else
			local function axis_run(path)
				local total=0
				for point_index=1,#path.centreline-1 do
					local a,b=path.centreline[point_index],path.centreline[point_index+1]
					if a.x ~= b.x and a.z ~= b.z then return nil end
					total=total+math.abs(a.x-b.x)+math.abs(a.z-b.z)
				end
				return total
			end
			for pair_index=1,#policy.pairs do
				local pair=policy.pairs[pair_index]
				local left,right=type(pair) == "table" and boat_by_id[pair[1]] or nil,
					type(pair) == "table" and boat_by_id[pair[2]] or nil
				local left_run=left and axis_run(left) or nil
				local right_run=right and axis_run(right) or nil
				if not left_run or not right_run or
						math.abs(left_run-right_run)*
							policy.maximum_difference_denominator >
						math.max(left_run,right_run)*
							policy.maximum_difference_numerator then
					add_violation("boat_parity",("pair_%02d"):format(pair_index),
						"axis-aligned run difference <= 1/10",
						value_text(left_run)..":"..value_text(right_run))
				end
			end
		end
	end

	local aggregate_rows = {}
	for _, row in pairs(aggregates) do aggregate_rows[#aggregate_rows + 1] = row end
	table.sort(aggregate_rows, function(a, b)
		if a.code ~= b.code then return a.code < b.code end
		return a.subject < b.subject
	end)
	for index = 1, #aggregate_rows do
		local row = aggregate_rows[index]
		add_violation(row.code, row.subject, row.expected, row.actual, row.count)
	end
	table.sort(result.violations, function(a, b)
		if a.code ~= b.code then return a.code < b.code end
		if a.subject ~= b.subject then return a.subject < b.subject end
		if a.expected ~= b.expected then return a.expected < b.expected end
		if a.actual ~= b.actual then return a.actual < b.actual end
		return a.count < b.count
	end)
	table.sort(result.witnesses, function(a, b)
		if a.code ~= b.code then return a.code < b.code end
		if a.subject ~= b.subject then return a.subject < b.subject end
		if a.z ~= b.z then return a.z < b.z end
		return a.x < b.x
	end)
	result.metrics.violation_count = #result.violations
	result.metrics.witness_count = #result.witnesses
	result.ok = #result.violations == 0
	return result
end
