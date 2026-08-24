return function(common, output_path)
	local rows, h1_capacity_differences, route_011_bridge = {}, 0
	local function add(route, family)
		local stations = common.route_stations(route)
		local class = assert(common.class_by_id[route.class])
		local literal, symmetric, indices
		if family == "mainland" then
			literal, indices = common.mainland_flat_deltas(route, stations)
			symmetric = literal
		else
			literal, indices = common.island_flat_deltas(stations,
				"literal_contract")
			symmetric = common.island_flat_deltas(stations, "symmetric_seven_delta")
		end
		local literal_capacity = common.transition_capacity(2, #stations,
			literal, class.minimum_transition_run)
		local symmetric_capacity = common.transition_capacity(2, #stations,
			symmetric, class.minimum_transition_run)
		if literal_capacity ~= symmetric_capacity then
			h1_capacity_differences = h1_capacity_differences + 1
		end
		if route.id == "route_011" then
			route_011_bridge = literal_capacity + class.max_cut + class.max_fill
		end
		rows[#rows + 1] = {family = family, route_id = route.id,
			class = route.class, station_count = #stations,
			from_station_id = route.station_a_id or route.from_station_id,
			to_station_id = route.station_b_id or route.to_station_id,
			boundary_id = route.boundary_id,
			interface_station_indices = table.concat(indices, ","),
			interface_count = #indices,
			min_transition_run = class.minimum_transition_run,
			max_cut = class.max_cut, max_fill = class.max_fill,
			literal_h1_transition_capacity = literal_capacity,
			literal_h1_bridgeable_delta = literal_capacity + class.max_cut +
				class.max_fill,
			symmetric_h1_transition_capacity = symmetric_capacity,
			symmetric_h1_bridgeable_delta = symmetric_capacity + class.max_cut +
				class.max_fill,
			initial_transition_assumption = "first_permitted_transition_free"}
	end
	for index = 1, #common.source.routes do add(common.source.routes[index],
		"mainland") end
	for index = 1, #common.source.island_routes do
		add(common.source.island_routes[index], "island")
	end
	common.write_tsv(output_path, {"family", "route_id", "class", "boundary_id",
		"from_station_id", "to_station_id",
		"station_count", "interface_count", "interface_station_indices",
		"min_transition_run", "max_cut", "max_fill",
		"literal_h1_transition_capacity", "literal_h1_bridgeable_delta",
		"symmetric_h1_transition_capacity", "symmetric_h1_bridgeable_delta",
		"initial_transition_assumption"}, rows)
	return #rows, #rows, {h1_capacity_differences = h1_capacity_differences,
		route_011_bridgeable_delta = route_011_bridge}
end
