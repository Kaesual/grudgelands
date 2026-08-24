return function(common, output_path)
	local rows = {}
	local summary = {water_stations = 0, dry_stations = 0,
		W_below_band = 0, W_above_band = 0,
		W_below_landmark_band = 0, W_above_landmark_band = 0,
		W_above_landmark_band_by_reach = {},
		direction_conflicts = 0, direction_audited = 0}
	local stations = {}
	for index = 1, #common.source.route_stations do
		local row = common.source.route_stations[index]
		stations[common.point_key(row.position)] = stations[common.point_key(row.position)] or {}
		stations[common.point_key(row.position)][#stations[common.point_key(row.position)] + 1] = row
	end
	for reach_index = 1, #common.source.hydrology do
		local reach = common.source.hydrology[reach_index]
		local zone = assert(common.zone_by_id[reach.zone_id])
		local profile = assert(common.profile_by_id[zone.primary_relief_id])
		local hydro_profile = assert(common.hydro_profile_by_id[reach.profile_id])
		local landmark = assert(common.landmark_by_id[reach.landmark_id])
		local landmark_profile = assert(common.profile_by_id[
			landmark.secondary_relief_id])
		local first, last = reach.centreline[1], reach.centreline[#reach.centreline]
		local W = common.water_level + reach.water_surface_offset
		if W < common.water_level + profile.min_above_water then
			summary.W_below_band = summary.W_below_band + 1
		elseif W > common.water_level + profile.max_above_water then
			summary.W_above_band = summary.W_above_band + 1
		end
		if W < common.water_level + landmark_profile.min_above_water then
			summary.W_below_landmark_band = summary.W_below_landmark_band + 1
		elseif W > common.water_level + landmark_profile.max_above_water then
			summary.W_above_landmark_band = summary.W_above_landmark_band + 1
			summary.W_above_landmark_band_by_reach[reach.id] = W -
				(common.water_level + landmark_profile.max_above_water)
		end
		local delta_x, delta_z = last.x - first.x, last.z - first.z
		local expectation = common.flow_expectation_by_zone[reach.zone_id]
		local direction_status, direction_conflict, expected_axis, expected_sign
		if expectation then
			summary.direction_audited = summary.direction_audited + 1
			if not reach.from_id:find(expectation.from_role, 1, true) or
					not reach.to_id:find(expectation.to_role, 1, true) then
				error("WP40 CB-1: expected flow endpoint roles missing for zone " ..
					reach.zone_id, 0)
			end
			expected_axis, expected_sign = expectation.axis, expectation.sign
			local measured = expected_axis == "x" and delta_x or delta_z
			direction_conflict = measured * expected_sign <= 0
			if direction_conflict then
				summary.direction_conflicts = summary.direction_conflicts + 1
				direction_status = "contradicts_design_expected_flow"
			else
				direction_status = "conforms_to_design_expected_flow"
			end
		else
			direction_status = "not_audited_no_design_direction_rule"
		end
		rows[#rows + 1] = {row_type = "reach", reach_id = reach.id,
			zone_id = reach.zone_id, profile_id = reach.profile_id,
			zone_primary_profile_id = zone.primary_relief_id,
			landmark_secondary_profile_id = landmark.secondary_relief_id,
			landmark_id = reach.landmark_id, from_id = reach.from_id, to_id = reach.to_id,
			start_x = first.x, start_z = first.z, finish_x = last.x,
			finish_z = last.z, delta_x = delta_x, delta_z = delta_z,
			W = W, depth = hydro_profile.depth,
			zone_band_low = common.water_level + profile.min_above_water,
			zone_band_high = common.water_level + profile.max_above_water,
			W_minus_band_low = W - (common.water_level + profile.min_above_water),
			band_high_minus_W = common.water_level + profile.max_above_water - W,
			landmark_band_low = common.water_level +
				landmark_profile.min_above_water,
			landmark_band_high = common.water_level +
				landmark_profile.max_above_water,
			W_minus_landmark_band_low = W - (common.water_level +
				landmark_profile.min_above_water),
			landmark_band_high_minus_W = common.water_level +
				landmark_profile.max_above_water - W,
			direction_status = direction_status,
			direction_conflict = direction_conflict,
			direction_expected_axis = expected_axis,
			direction_expected_sign = expected_sign,
			direction_authority = expectation and expectation.authority,
			final_owner_status = "unavailable_deferred_until_reviewed_ca2",
			final_H_status = "unavailable_deferred_until_reviewed_ca2"}
		local points = common.route_stations(reach)
		for point_index = 1, #points do
			local at = stations[common.point_key(points[point_index])]
			if at then
				for station_index = 1, #at do
					local station = at[station_index]
					local segment_index, half_width = common.reach_segment_at(
						station.position, reach.centreline)
					if not segment_index then
						error("WP40 CB-1: raster contact is not an analytic reach " ..
							"centreline point", 0)
					end
					local inside_closed_mask = half_width > 0
					if not inside_closed_mask then
						error("WP40 CB-1: reach centreline has non-positive width", 0)
					end
					if hydro_profile.depth == 0 then
						summary.dry_stations = summary.dry_stations + 1
					else
						summary.water_stations = summary.water_stations + 1
					end
					rows[#rows + 1] = {row_type = "station_on_reach_centreline",
						reach_id = reach.id, zone_id = reach.zone_id,
						profile_id = reach.profile_id, station_id = station.id,
						start_x = station.position.x, start_z = station.position.z,
						W = W, proven_inside_closed_mask = inside_closed_mask,
						matching_segment_index = segment_index,
						interpolated_half_width = half_width,
						water_status = hydro_profile.depth == 0 and "dry_channel" or
							"planned_surface_water",
						proof_scope =
							"analytic_zero_distance_le_interpolated_half_width"}
				end
			end
		end
	end
	for interface_index = 1, #common.source.hydrology_interfaces do
		local interface = common.source.hydrology_interfaces[interface_index]
		local upper, lower
		if interface.upper_id then
			upper, lower = common.hydrology_by_id[interface.upper_id],
				common.hydrology_by_id[interface.lower_id]
			if not upper or not lower or
					interface.upper_level_offset ~= upper.water_surface_offset or
					interface.lower_level_offset ~= lower.water_surface_offset or
					interface.drop ~= upper.water_surface_offset -
						lower.water_surface_offset then
				error("WP40 CB-1: hydrology interface level binding moved for " ..
					interface.id, 0)
			end
		end
		rows[#rows + 1] = {row_type = "interface", interface_id = interface.id,
			interface_kind = interface.kind, reach_id = interface.hydrology_id or
				interface.upper_id or interface.outgoing_reach_id,
			start_x = interface.position.x, start_z = interface.position.z,
			upper_W = upper and common.water_level + upper.water_surface_offset,
			lower_W = lower and common.water_level + lower.water_surface_offset,
			declared_drop = interface.drop,
			W_drop = upper and lower and upper.water_surface_offset -
				lower.water_surface_offset,
			proof_scope = "source_graph_literals"}
	end
	table.sort(rows, function(a, b)
		local ak = a.row_type .. "\0" .. (a.reach_id or "") .. "\0" ..
			(a.station_id or a.interface_id or "")
		local bk = b.row_type .. "\0" .. (b.reach_id or "") .. "\0" ..
			(b.station_id or b.interface_id or "")
		return ak < bk
	end)
	common.write_tsv(output_path, {"row_type", "reach_id", "interface_id",
		"interface_kind", "station_id", "zone_id", "profile_id", "landmark_id",
		"zone_primary_profile_id", "landmark_secondary_profile_id",
		"from_id", "to_id", "start_x", "start_z", "finish_x", "finish_z",
		"delta_x", "delta_z", "W", "depth", "zone_band_low", "zone_band_high",
		"W_minus_band_low", "band_high_minus_W", "upper_W", "lower_W",
		"landmark_band_low", "landmark_band_high", "W_minus_landmark_band_low",
		"landmark_band_high_minus_W", "declared_drop", "W_drop",
		"direction_status", "direction_conflict", "direction_expected_axis",
		"direction_expected_sign", "direction_authority",
		"proven_inside_closed_mask", "matching_segment_index",
		"interpolated_half_width", "water_status", "proof_scope",
		"final_owner_status", "final_H_status"}, rows)
	return #common.source.hydrology, #rows, summary
end
