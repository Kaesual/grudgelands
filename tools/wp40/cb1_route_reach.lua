return function(common, output_path)
	local declared = {}
	for index = 1, #common.source.route_crossing_interfaces do
		local row = common.source.route_crossing_interfaces[index]
		if row.hydrology_id then
			local key = row.route_id .. "\0" .. row.hydrology_id
			if declared[key] then
				error("WP40 CB-1: duplicate declared route/reach pair " ..
					row.route_id .. "/" .. row.hydrology_id, 0)
			end
			declared[key] = row
		end
	end
	local reach_points, reach_sets = {}, {}
	for index = 1, #common.source.hydrology do
		local reach = common.source.hydrology[index]
		local points = common.route_stations(reach)
		local set = {}
		for point_index = 1, #points do set[common.point_key(points[point_index])] = true end
		reach_points[reach.id], reach_sets[reach.id] = points, set
	end
	local rows, seen_declared, declared_count, undeclared_count = {}, {}, 0, 0
	local raster_disagreements, island_contacts = 0, 0
	local routes = {}
	for index = 1, #common.source.routes do
		routes[#routes + 1] = {row = common.source.routes[index], family = "mainland"}
	end
	for index = 1, #common.source.island_routes do
		routes[#routes + 1] = {row = common.source.island_routes[index],
			family = "island"}
	end
	for route_index = 1, #routes do
		local route, family = routes[route_index].row, routes[route_index].family
		local stations = common.route_stations(route)
		for reach_index = 1, #common.source.hydrology do
			local reach = common.source.hydrology[reach_index]
			local analytic_count = common.polyline_intersection_count(route.centreline,
				reach.centreline)
			local first, last, count
			count = 0
			for station_index = 1, #stations do
				if reach_sets[reach.id][common.point_key(stations[station_index])] then
					count = count + 1
					first = first or stations[station_index]
					last = stations[station_index]
				end
			end
			local analytic_contact, raster_contact = analytic_count > 0, count > 0
			if analytic_contact ~= raster_contact then
				raster_disagreements = raster_disagreements + 1
			end
			local key = route.id .. "\0" .. reach.id
			if analytic_contact or raster_contact then
				local interface = declared[key]
				if interface then seen_declared[key] = true end
				if interface then declared_count = declared_count + 1
				else undeclared_count = undeclared_count + 1 end
				if family == "island" then island_contacts = island_contacts + 1 end
				rows[#rows + 1] = {row_type =
						"route_reach_analytic_centreline_contact",
					route_family = family, route_id = route.id, reach_id = reach.id,
					profile_id = reach.profile_id,
					analytic_segment_pair_count = analytic_count,
					raster_common_station_count = count,
					raster_first_x = first and first.x, raster_first_z = first and first.z,
					raster_last_x = last and last.x, raster_last_z = last and last.z,
					raster_relation = analytic_contact == raster_contact and "agrees" or
						(analytic_contact and "analytic_only" or "raster_only"),
					declared_interface_id = interface and interface.id,
					declaration_status = interface and "declared" or "undeclared",
					proof_scope =
						"exact_authored_segment_intersection_with_raster_crosscheck"}
			end
		end
	end
	for key, interface in pairs(declared) do
		if not seen_declared[key] then
			rows[#rows + 1] = {row_type = "declared_without_centreline_contact",
				route_family = "mainland", route_id = interface.route_id,
				reach_id = interface.hydrology_id,
				declared_interface_id = interface.id, declaration_status = "missing",
				proof_scope = "exact_authored_segment_intersection"}
		end
	end
	table.sort(rows, function(a, b)
		local ak = a.route_id .. "\0" .. a.reach_id .. "\0" .. a.row_type
		local bk = b.route_id .. "\0" .. b.reach_id .. "\0" .. b.row_type
		return ak < bk
	end)
	common.write_tsv(output_path, {"row_type", "route_family", "route_id",
		"reach_id", "profile_id", "analytic_segment_pair_count",
		"raster_common_station_count", "raster_first_x", "raster_first_z",
		"raster_last_x", "raster_last_z", "raster_relation",
		"declared_interface_id", "declaration_status", "proof_scope"}, rows)
	return #routes, #rows, {declared = declared_count,
		undeclared = undeclared_count, raster_disagreements = raster_disagreements,
		island_contacts = island_contacts}
end
