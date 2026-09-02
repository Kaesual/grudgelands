return function(common, output_path)
	local rows = {}
	local summary = {raw_positive = 0, all_positive = 0, zone_positive = 0}
	for route_index = 1, #common.source.island_routes do
		local route = common.source.island_routes[route_index]
		local stations = common.route_stations(route)
		local class = assert(common.class_by_id[route.class])
		local literal = common.island_flat_deltas(stations, "literal_contract")
		local symmetric = common.island_flat_deltas(stations,
			"symmetric_seven_delta")
		local literal_bridge = common.transition_capacity(2, #stations, literal,
			class.minimum_transition_run) + class.max_cut + class.max_fill
		local symmetric_bridge = common.transition_capacity(2, #stations, symmetric,
			class.minimum_transition_run) + class.max_cut + class.max_fill
		local zone_id = assert(common.island_zone_by_id[route.island_id],
			"island has no landing-derived zone")
		for seed_index = 1, #common.seeds do
			local seed = common.seeds[seed_index]
			local raw_min, raw_max, all_min, all_max, zone_min, zone_max
			local first_raw, first_all, first_zone, last_raw, last_all, last_zone
			for station_index = 1, #stations do
				local point = stations[station_index]
				local raw, all_landmarks, authored_zone = common.heights(seed,
					zone_id, point.x, point.z)
				raw_min = not raw_min and raw or math.min(raw_min, raw)
				raw_max = not raw_max and raw or math.max(raw_max, raw)
				all_min = not all_min and all_landmarks or math.min(all_min, all_landmarks)
				all_max = not all_max and all_landmarks or math.max(all_max, all_landmarks)
				zone_min = not zone_min and authored_zone or
					math.min(zone_min, authored_zone)
				zone_max = not zone_max and authored_zone or
					math.max(zone_max, authored_zone)
				if station_index == 1 then
					first_raw, first_all, first_zone = raw, all_landmarks, authored_zone
				elseif station_index == #stations then
					last_raw, last_all, last_zone = raw, all_landmarks, authored_zone
				end
			end
			local raw_deficit = math.abs(last_raw - first_raw) - literal_bridge
			local all_deficit = math.abs(last_all - first_all) - literal_bridge
			local zone_deficit = math.abs(last_zone - first_zone) - literal_bridge
			if raw_deficit > 0 then summary.raw_positive = summary.raw_positive + 1 end
			if all_deficit > 0 then summary.all_positive = summary.all_positive + 1 end
			if zone_deficit > 0 then summary.zone_positive = summary.zone_positive + 1 end
			rows[#rows + 1] = {row_type = "measured_route", route_id = route.id,
				seed = seed, winner_index = common.winner_indices[seed_index],
				station_count = #stations, literal_bridgeable_delta = literal_bridge,
				symmetric_bridgeable_delta = symmetric_bridge,
				raw_start_h = first_raw, raw_end_h = last_raw, raw_min_h = raw_min,
				raw_max_h = raw_max, raw_endpoint_deficit_literal = raw_deficit,
				unclipped_all_start_h = first_all, unclipped_all_end_h = last_all,
				unclipped_all_min_h = all_min, unclipped_all_max_h = all_max,
				unclipped_all_endpoint_deficit_literal = all_deficit,
				authored_zone_start_h = first_zone, authored_zone_end_h = last_zone,
				authored_zone_min_h = zone_min, authored_zone_max_h = zone_max,
				authored_zone_endpoint_deficit_literal = zone_deficit,
				claim_scope = "raw_plus_landmarks_no_edge_G_or_junction_not_final_H"}
		end
	end
	common.write_tsv(output_path, {"row_type", "route_id", "seed",
		"winner_index", "station_count", "literal_bridgeable_delta",
		"symmetric_bridgeable_delta", "raw_start_h", "raw_end_h", "raw_min_h",
		"raw_max_h", "raw_endpoint_deficit_literal", "unclipped_all_start_h",
		"unclipped_all_end_h", "unclipped_all_min_h", "unclipped_all_max_h",
		"unclipped_all_endpoint_deficit_literal", "authored_zone_start_h",
		"authored_zone_end_h", "authored_zone_min_h", "authored_zone_max_h",
		"authored_zone_endpoint_deficit_literal", "claim_scope"}, rows)
	return #common.source.island_routes * #common.seeds, #rows, summary
end
