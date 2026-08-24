local function distance_to_band(value, low, high)
	if value < low then return low - value end
	if value > high then return value - high end
	return 0
end

local function far_distance_to_band(value, low, high)
	return math.max(math.abs(value - low), math.abs(value - high))
end

return function(common, output_path)
	local rows = {}
	local summary = {raw_optimistic_negative = 0, raw_pessimistic_negative = 0,
		all_optimistic_negative = 0, all_pessimistic_negative = 0,
		zone_optimistic_negative = 0, zone_pessimistic_negative = 0,
		singleton_rows = 0, range_rows = 0,
		raw_singleton_negative = 0, raw_range_optimistic_negative = 0,
		all_singleton_negative = 0, all_range_optimistic_negative = 0}
	if common.source.geometry_policies.relief_field.boundary_blend_width ~= 96 then
		error("WP40 CB-1: relief boundary blend width moved", 0)
	end
	for route_index = 1, #common.source.routes do
		local route = common.source.routes[route_index]
		local stations = common.route_stations(route)
		local blocked, indices = common.mainland_flat_deltas(route, stations)
		local crossing_index = indices[2]
		if crossing_index <= 96 or crossing_index + 96 > #stations then
			error("WP40 CB-1: route " .. route.id ..
				" has no complete 96-station boundary approaches", 0)
		end
		local approach_a, approach_b = stations[crossing_index - 96],
			stations[crossing_index + 96]
		if approach_a.x ~= route.centreline[2].x or
				approach_a.z ~= route.centreline[2].z or
				approach_b.x ~= route.centreline[4].x or
				approach_b.z ~= route.centreline[4].z then
			error("WP40 CB-1: route " .. route.id ..
				" ±96 samples are not the authored approach controls", 0)
		end
		local class = assert(common.class_by_id[route.class])
		local edge = assert(common.edge_by_id[route.boundary_id])
		local gate_low = common.water_level + edge.gate_min_above_water
		local gate_high = common.water_level + edge.gate_max_above_water
		for seed_index = 1, #common.seeds do
			local seed = common.seeds[seed_index]
			for side_index = 1, 2 do
				local side = side_index == 1 and "a" or "b"
				local sample_index = side_index == 1 and crossing_index - 96 or
					crossing_index + 96
				local zone_id = side_index == 1 and route.zone_a or route.zone_b
				local point = stations[sample_index]
				local raw, all_landmarks, authored_zone = common.heights(seed,
					zone_id, point.x, point.z)
				local first_delta = side_index == 1 and sample_index + 1 or
					crossing_index + 1
				local last_delta = side_index == 1 and crossing_index or sample_index
				local transitions = common.transition_capacity(first_delta, last_delta,
					blocked, class.minimum_transition_run)
				local bridge = transitions + class.max_cut + class.max_fill
				local function margins(height)
					return bridge - distance_to_band(height, gate_low, gate_high),
						bridge - far_distance_to_band(height, gate_low, gate_high)
				end
				local raw_best, raw_worst = margins(raw)
				local all_best, all_worst = margins(all_landmarks)
				local zone_best, zone_worst = margins(authored_zone)
				local singleton = gate_low == gate_high
				if singleton then summary.singleton_rows = summary.singleton_rows + 1
				else summary.range_rows = summary.range_rows + 1 end
				if raw_best < 0 then summary.raw_optimistic_negative =
					summary.raw_optimistic_negative + 1 end
				if raw_worst < 0 then summary.raw_pessimistic_negative =
					summary.raw_pessimistic_negative + 1 end
				if raw_best < 0 and singleton then summary.raw_singleton_negative =
					summary.raw_singleton_negative + 1
				elseif raw_best < 0 then summary.raw_range_optimistic_negative =
					summary.raw_range_optimistic_negative + 1 end
				if all_best < 0 then summary.all_optimistic_negative =
					summary.all_optimistic_negative + 1 end
				if all_worst < 0 then summary.all_pessimistic_negative =
					summary.all_pessimistic_negative + 1 end
				if all_best < 0 and singleton then summary.all_singleton_negative =
					summary.all_singleton_negative + 1
				elseif all_best < 0 then summary.all_range_optimistic_negative =
					summary.all_range_optimistic_negative + 1 end
				if zone_best < 0 then summary.zone_optimistic_negative =
					summary.zone_optimistic_negative + 1 end
				if zone_worst < 0 then summary.zone_pessimistic_negative =
					summary.zone_pessimistic_negative + 1 end
				rows[#rows + 1] = {route_id = route.id, seed = seed,
					winner_index = common.winner_indices[seed_index], side = side,
					zone_id = zone_id, sample_station_index = sample_index,
					x = point.x, z = point.z, crossing_station_index = crossing_index,
					gate_low = gate_low, gate_high = gate_high,
					local_transition_capacity = transitions,
					local_bridgeable_delta = bridge, raw_h = raw,
					raw_optimistic_margin = raw_best,
					raw_pessimistic_margin = raw_worst,
					unclipped_all_landmarks_h = all_landmarks,
					unclipped_all_optimistic_margin = all_best,
					unclipped_all_pessimistic_margin = all_worst,
					authored_zone_landmarks_h = authored_zone,
					authored_zone_optimistic_margin = zone_best,
					authored_zone_pessimistic_margin = zone_worst,
					claim_scope =
						"raw_plus_landmarks_no_edge_G_or_junction_not_final_H",
					gate_value_scope = singleton and "exact_singleton" or
						"authored_range_actual_hash_G_unavailable"}
			end
		end
	end
	common.write_tsv(output_path, {"route_id", "seed", "winner_index", "side",
		"zone_id", "sample_station_index", "x", "z", "crossing_station_index",
		"gate_low", "gate_high", "local_transition_capacity",
		"local_bridgeable_delta", "raw_h", "raw_optimistic_margin",
		"raw_pessimistic_margin", "unclipped_all_landmarks_h",
		"unclipped_all_optimistic_margin", "unclipped_all_pessimistic_margin",
		"authored_zone_landmarks_h", "authored_zone_optimistic_margin",
		"authored_zone_pessimistic_margin", "claim_scope", "gate_value_scope"},
		rows)
	return #common.source.routes * #common.seeds, #rows, summary
end
