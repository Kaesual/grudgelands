-- Exact R2 audit for fixed civic cores, their route exits and 2D anchors.

return function(source, session)
	assert(type(source) == "table", "simple-map source required")
	assert(type(session) == "table", "simple-map session required")
	assert(type(session.classification_values_at) == "function",
		"classification_values_at required")
	assert(type(session.power_owner_at) == "function",
		"power_owner_at required")

	local violations = {}
	local witnesses = {}
	local occurrence_counts = {}
	local first_witness = {}
	local function occurrence(code, witness)
		occurrence_counts[code] = (occurrence_counts[code] or 0) + 1
		if not first_witness[code] then first_witness[code] = witness end
	end
	local function inside_half_open(point, center, dimensions)
		return point.x >= center.x-dimensions.width_x/2 and
			point.x < center.x+dimensions.width_x/2 and
			point.z >= center.z-dimensions.width_z/2 and
			point.z < center.z+dimensions.width_z/2
	end

	local civic_hydrology = {}
	for index = 1, #source.hydrology do
		local row = source.hydrology[index]
		if row.civic_core_zone_numeric_id then civic_hydrology[row.id] = row end
	end

	local cores = {}
	local scanned_nodes = 0
	local underlying_power_disagreements = 0
	for index = 1, 12 do
		local anchor = source.anchors[index]
		local zone = source.zones[anchor.zone_numeric_id]
		local dimensions = index <= 6 and source.start_core or source.capital_core
		local min_x = anchor.position.x-dimensions.width_x/2
		local max_x = anchor.position.x+dimensions.width_x/2-1
		local min_z = anchor.position.z-dimensions.width_z/2
		local max_z = anchor.position.z+dimensions.width_z/2-1
		local core = {
			anchor_id=anchor.id,zone_numeric_id=anchor.zone_numeric_id,
			zone_id=zone.id,kind=index <= 6 and "start" or "capital",
			min_x=min_x,max_x=max_x,min_z=min_z,max_z=max_z,
			nodes=0,land_nodes=0,civic_water_nodes=0,
			underlying_power_disagreements=0,route_exits={},
		}
		for z = min_z, max_z do
			for x = min_x, max_x do
				core.nodes = core.nodes + 1
				scanned_nodes = scanned_nodes + 1
				local water_class, macro_region, owner, _, hydrology_id, _, fixed,
					civic_water = session.classification_values_at(x,z)
				if owner ~= anchor.zone_numeric_id or macro_region ~= zone.macro_region or
						fixed ~= true then
					occurrence("fixed_core_owner_mismatch", {code=
						"fixed_core_owner_mismatch",anchor_id=anchor.id,x=x,z=z,
						expected_owner=anchor.zone_numeric_id,actual_owner=owner,
						expected_macro=zone.macro_region,actual_macro=macro_region,
						fixed=fixed})
				end
				if water_class == "land" then
					core.land_nodes = core.land_nodes + 1
				elseif water_class == "planned_water" and civic_water == true and
						civic_hydrology[hydrology_id] and
						civic_hydrology[hydrology_id].civic_core_zone_numeric_id ==
							anchor.zone_numeric_id then
					core.civic_water_nodes = core.civic_water_nodes + 1
				else
					occurrence("fixed_core_water_mismatch", {code=
						"fixed_core_water_mismatch",anchor_id=anchor.id,x=x,z=z,
						water_class=water_class,hydrology_id=hydrology_id,
						civic_water=civic_water})
				end
				local power_owner = session.power_owner_at(x,z,zone.macro_region)
				if power_owner ~= anchor.zone_numeric_id then
					core.underlying_power_disagreements =
						core.underlying_power_disagreements + 1
					underlying_power_disagreements =
						underlying_power_disagreements + 1
				end
			end
		end

		for route_index = 1, #source.routes do
			local route = source.routes[route_index]
			if route.zone_a == anchor.zone_numeric_id or
					route.zone_b == anchor.zone_numeric_id then
				local has_inside, has_outside = false, false
				for point_index = 1, #route.centreline do
					if inside_half_open(route.centreline[point_index],anchor.position,
							dimensions) then
						has_inside = true
					else
						has_outside = true
					end
				end
				if has_inside and has_outside then
					core.route_exits[#core.route_exits+1] = route.id
				end
			end
		end
		table.sort(core.route_exits)
		local expected_exits = index <= 6 and 1 or 4
		if #core.route_exits ~= expected_exits then
			occurrence("fixed_core_route_exit_count", {code=
				"fixed_core_route_exit_count",anchor_id=anchor.id,
				expected=expected_exits,actual=#core.route_exits})
		end
		cores[#cores+1] = core
	end

	local anchors = {}
	local horizontally_valid_candidate_sets = 0
	for index = 1, #source.anchors do
		local anchor = source.anchors[index]
		local zone = source.zones[anchor.zone_numeric_id]
		local positions = anchor.position and {anchor.position} or anchor.candidates
		local valid = 0
		for candidate_index = 1, #positions do
			local point = positions[candidate_index]
			local water_class, macro_region, owner =
				session.classification_values_at(point.x,point.z)
			if owner == anchor.zone_numeric_id and macro_region == zone.macro_region and
					(water_class == "land" or water_class == "planned_water") then
				valid = valid + 1
			end
		end
		if anchor.placement_mode == "candidate_set" then
			if valid > 0 then
				horizontally_valid_candidate_sets =
					horizontally_valid_candidate_sets + 1
			else
				occurrence("anchor_candidate_set_invalid", {code=
					"anchor_candidate_set_invalid",anchor_id=anchor.id,
					zone_numeric_id=anchor.zone_numeric_id})
			end
		elseif valid ~= 1 then
			occurrence("fixed_anchor_invalid", {code="fixed_anchor_invalid",
				anchor_id=anchor.id,zone_numeric_id=anchor.zone_numeric_id,
				valid_positions=valid})
		end
		anchors[#anchors+1] = {anchor_id=anchor.id,
			placement_mode=anchor.placement_mode,valid_positions=valid,
			total_positions=#positions}
	end

	local violation_order = {
		"fixed_core_owner_mismatch",
		"fixed_core_water_mismatch",
		"fixed_core_route_exit_count",
		"fixed_anchor_invalid",
		"anchor_candidate_set_invalid",
	}
	for index = 1, #violation_order do
		local code = violation_order[index]
		if occurrence_counts[code] then
			violations[#violations+1] = {code=code,count=occurrence_counts[code]}
			witnesses[#witnesses+1] = first_witness[code]
		end
	end

	return {
		schema="grug_wp40_simple_map_r2_cores_v1",
		ok=#violations == 0,
		violations=violations,
		metrics={scanned_core_nodes=scanned_nodes,fixed_cores=#cores,
			anchors=#anchors,candidate_sets=#source.anchors-16,
			horizontally_valid_candidate_sets=horizontally_valid_candidate_sets,
			underlying_power_disagreements=underlying_power_disagreements},
		witnesses=witnesses,cores=cores,anchors=anchors,
	}
end
