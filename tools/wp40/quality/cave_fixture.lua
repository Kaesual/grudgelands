-- Focused regression for deterministic hillside cave entrances.

return function(repo, expanded)
	local _, cave_factory = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/zones.lua")
	local function check(condition, message)
		if not condition then error("quality cave fixture: " .. message, 0) end
	end
	local function new_synthetic(seed, slope_x, slope_z, rejected)
		local function local_axis(value)
			return value - math.floor(value / 192) * 192
		end
		local definition = {full_seed_string = seed}
		function definition.column_values_at(x, z)
			local terrain_y
			if slope_x or slope_z then
				terrain_y = 100 + math.floor((x * (slope_x or 0) +
					z * (slope_z or 0)) / 4)
			else
				terrain_y = 100 + math.floor(local_axis(x) / 4)
			end
			local water_class, water_y, classified, functional, transition, hard =
				"land", nil, nil, nil, nil, false
			if rejected == "water" then water_class, water_y = "planned_water", 101
			elseif rejected == "hydrology" then classified = "fixture_river"
			elseif rejected == "functional" then functional = "land_grade"
			elseif rejected == "transition" then transition = "rapid"
			elseif rejected == "foundation" then hard = true end
			local zone = rejected == "zone" and tostring(x % 2) or "fixture_zone"
			return water_class, 1, zone, "fixture_biome", "fixture_race", terrain_y,
				water_y, classified, nil, functional, nil, nil, nil, transition,
				nil, nil, nil, nil, nil, hard
		end
		function definition.static_exclusion_values_at()
			return rejected == "static" and 1 or nil
		end
		function definition.housing_mask_id_at()
			return rejected == "housing" and "fixture_housing" or nil
		end
		return cave_factory(definition)
	end

	local seed = "13191094842853985814"
	local base = new_synthetic(seed)
	local accepted
	for cell_z = -8, 8 do
		for cell_x = -8, 8 do
			local record = base.candidate_record_at_cell(cell_x, cell_z)
			if record and not accepted then accepted = record end
		end
	end
	check(accepted ~= nil, "synthetic hillside has no entrance")
	local cell_min_x, cell_min_z = accepted.cell_x * 192, accepted.cell_z * 192
	check(accepted.mouth_x - cell_min_x >= 40 and
		accepted.mouth_x - cell_min_x <= 151 and
		accepted.mouth_z - cell_min_z >= 40 and
		accepted.mouth_z - cell_min_z <= 151, "candidate margin differs")
	check(accepted.length == 32 and accepted.radius == 2 and
		(accepted.endpoint_distance == 24 or accepted.endpoint_distance == 32) and
		accepted.endpoint_height - accepted.mouth_y >= 6,
		"accepted record differs")
	local previous_low, previous_high
	for step = 0, 31 do
		local x = accepted.mouth_x + accepted.direction_x * step
		local z = accepted.mouth_z + accepted.direction_z * step
		local low, high = base.run_at(x, z)
		check(low and high and high - low == 4 and low >= -37,
			"centre tube run differs")
		if previous_low then
			check(low <= previous_high and high >= previous_low,
				"tube is not vertically connected")
		end
		previous_low, previous_high = low, high
		for side = -2, 2 do
			local sx = x - accepted.direction_z * side
			local sz = z + accepted.direction_x * side
			local side_low, side_high = base.run_at(sx, sz)
			local expected_half = math.floor(math.sqrt(4 - side * side))
			check(side_low and side_high and side_high - side_low == expected_half * 2,
				"circular cross-section differs")
		end
	end
	check(base.run_at(accepted.mouth_x - accepted.direction_x,
		accepted.mouth_z - accepted.direction_z) == nil and
		base.run_at(accepted.mouth_x + accepted.direction_x * 32,
			accepted.mouth_z + accepted.direction_z * 32) == nil,
		"tube length boundary differs")

	local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for index = 1, #directions do
		local wanted = directions[index]
		local session = new_synthetic(seed, wanted[1], wanted[2])
		local record
		for cell_z = -1, 1 do
			for cell_x = -1, 1 do
				record = record or session.candidate_record_at_cell(cell_x, cell_z)
			end
		end
		check(record and record.direction_x == wanted[1] and
			record.direction_z == wanted[2], "uphill direction differs")
	end
	for _, reason in ipairs({"water", "hydrology", "functional", "transition",
			"foundation", "static", "housing", "zone"}) do
		check(new_synthetic(seed, nil, nil, reason).candidate_record_at_cell(
			accepted.cell_x, accepted.cell_z) == nil, reason .. " candidate survived")
	end

	local function population(session, reverse)
		local rows = {}
		local first, last, step = reverse and 180 or -180,
			reverse and -180 or 180, reverse and -1 or 1
		for cell_x = first, last, step do
			local record = session.candidate_record_at_cell(cell_x, -3)
			if record then
				rows[#rows + 1] = table.concat({record.cell_x, record.cell_z,
					record.mouth_x, record.mouth_y, record.mouth_z,
					record.direction_x, record.direction_z,
					record.endpoint_distance}, "/")
			end
		end
		table.sort(rows)
		return table.concat(rows, "\n"), #rows
	end
	local forward = new_synthetic("0")
	local reverse = new_synthetic("0")
	local forward_rows, population_count = population(forward, false)
	local reverse_rows, reverse_count = population(reverse, true)
	check(forward_rows == reverse_rows and population_count == reverse_count and
		population_count > 0, "candidate population depends on query order")
	local metrics = forward.metrics()
	check(metrics.cache_limit == 128 and metrics.cache_evictions > 0,
		"bounded cache eviction absent")

	local actual_rows, cross_slice = "compact", "compact"
	if expanded then
		local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
		local rows, user_loaded, cross_record = {}, nil, nil
		for _, actual_seed in ipairs({seed, "0"}) do
			local loaded = actual_seed == seed and
				offline.new_internal(actual_seed, nil, false, false) or
				offline.new_evidence(actual_seed, false)
			local actual = cave_factory({full_seed_string = actual_seed,
				column_values_at = loaded.planner_source.column_values_at,
				static_exclusion_values_at = loaded.horizontal.static_exclusion_values_at,
				housing_mask_id_at = loaded.horizontal.housing_mask_id_at})
			local count, first_record = 0, nil
			for cell_z = -18, 17 do
				for cell_x = -20, 19 do
					local record = actual.candidate_record_at_cell(cell_x, cell_z)
					if record then
						count = count + 1
						if not first_record then first_record = record end
						local end_x = record.mouth_x + record.direction_x * 31
						local end_z = record.mouth_z + record.direction_z * 31
						local function owner(value)
							return -30912 + math.floor((value + 30912) / 80) * 80
						end
						if actual_seed == seed and not cross_record and
								(owner(record.mouth_x) ~= owner(end_x) or
								owner(record.mouth_z) ~= owner(end_z)) then
							cross_record = record
						end
					end
				end
			end
			check(count > 0 and first_record, "actual seed has no bounded entrance")
			rows[#rows + 1] = table.concat({actual_seed, count, first_record.mouth_x,
				first_record.mouth_y, first_record.mouth_z,
				first_record.direction_x, first_record.direction_z}, "/")
			if actual_seed == seed then user_loaded = loaded end
		end
		check(user_loaded and cross_record, "actual cross-slice entrance absent")
		local function opcode_at(plan, y)
			for run = plan.r5_plan.column_start[1],
					plan.r5_plan.column_start[2] - 1 do
				local base_index = (run - 1) * 9
				if y >= plan.r5_plan.run_values[base_index + 1] and
						y <= plan.r5_plan.run_values[base_index + 2] then
					return plan.r5_plan.run_values[base_index + 4]
				end
			end
		end
		for _, step in ipairs({0, 31}) do
			local x = cross_record.mouth_x + cross_record.direction_x * step
			local z = cross_record.mouth_z + cross_record.direction_z * step
			local low, high = user_loaded.planner_source.surface_cave_run_at(x, z)
			check(low and high, "actual cross-slice run absent")
			local plan = user_loaded.planner:plan_slice({x = x, y = low - 1, z = z},
				{x = x, y = high + 1, z = z})
			for y = low, high do
				check(opcode_at(plan, y) == 26, "actual cave is not P5 natural cut")
			end
			if step == 0 then
				local terrain_y = select(6, user_loaded.planner_source.column_values_at(x, z))
				check(low <= terrain_y and terrain_y <= high and
					opcode_at(plan, terrain_y) == 26,
					"mouth surface was not removed before P7")
			end
		end
		cross_slice = table.concat({cross_record.mouth_x, cross_record.mouth_y,
			cross_record.mouth_z, cross_record.direction_x,
			cross_record.direction_z}, "/")
		actual_rows = table.concat(rows, ",")
	end
	return table.concat({"schema\tgrug_wp40_quality_caves_v1",
		"synthetic_entrance\t" .. table.concat({accepted.mouth_x,
			accepted.mouth_y, accepted.mouth_z, accepted.direction_x,
			accepted.direction_z}, "/"),
		"ordered_population\t" .. population_count,
		"cache_evictions\t" .. metrics.cache_evictions,
		"actual\t" .. actual_rows,
		"cross_slice\t" .. cross_slice}, "\n") .. "\n"
end
