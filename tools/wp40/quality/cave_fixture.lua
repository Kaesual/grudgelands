-- Focused regression for R8 owner-local cave-mouth candidates.

return function(repo, expanded)
	local _, cave_factory = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/zones.lua")
	local function check(condition, message)
		if not condition then error("quality cave fixture: " .. message, 0) end
	end
	local function synthetic(seed, slope_x, slope_z, rejected)
		local definition = {full_seed_string = seed}
		function definition.column_values_at(x, z)
			local terrain_y = 100 + math.floor((x * (slope_x or 0) +
				z * (slope_z or 0)) / 4)
			local water_class, water_y, hydrology, functional, transition, hard =
				"land", nil, nil, nil, nil, false
			if rejected == "water" then water_class, water_y = "planned_water", 101
			elseif rejected == "hydrology" then hydrology = "fixture_river"
			elseif rejected == "functional" then functional = "land_grade"
			elseif rejected == "transition" then transition = "rapid"
			elseif rejected == "foundation" then hard = true end
			local zone = rejected == "zone" and tostring(x % 2) or "fixture_zone"
			return water_class, 1, zone, "fixture_biome", "fixture_race", terrain_y,
				water_y, hydrology, nil, functional, nil, nil, nil, transition,
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
	local hillside = synthetic(seed, 2, 0)
	local base_x, base_z = hillside.cell_at(0, 0)
	local hill_record
	for dz = -10, 10 do
		for dx = -10, 10 do
			local record = hillside.candidate_record_at_cell(base_x + dx, base_z + dz)
			if record and record.kind == "hillside" then hill_record = hill_record or record end
		end
	end
	check(hill_record ~= nil, "synthetic hillside has no candidate")
	local cell_min_x = -30912 + hill_record.cell_x * 80
	local cell_min_z = -30912 + hill_record.cell_z * 80
	check(hill_record.mouth_x - cell_min_x >= 28 and
		hill_record.mouth_x - cell_min_x <= 51 and
		hill_record.mouth_z - cell_min_z >= 28 and
		hill_record.mouth_z - cell_min_z <= 51, "candidate margin differs")
	check(hill_record.length == 24 and hill_record.radius == 2 and
		hill_record.search_radius == 2 and
		hill_record.maximum_depth == 24 and hill_record.endpoint_distance == 12 and
		hill_record.endpoint_height - hill_record.mouth_y >= 4,
		"hillside record differs")
	check(hillside.run_at(hill_record.mouth_x, hill_record.mouth_z) == nil,
		"offline candidate authorized a carve")

	local flat = synthetic(seed)
	local sink_record
	for dz = -10, 10 do
		for dx = -10, 10 do
			local record = flat.candidate_record_at_cell(base_x + dx, base_z + dz)
			if record and record.kind == "sinkhole" then sink_record = sink_record or record end
		end
	end
	check(sink_record ~= nil, "synthetic flat ground has no sinkhole candidate")
	check(sink_record.search_radius == 24, "sinkhole search radius differs")

	for _, reason in ipairs({"water", "hydrology", "functional", "transition",
			"foundation", "static", "housing", "zone"}) do
		local rejected = synthetic(seed, 2, 0, reason)
		check(rejected.candidate_record_at_cell(hill_record.cell_x,
			hill_record.cell_z) == nil, reason .. " candidate survived")
	end

	local function population(session, reverse)
		local rows = {}
		local first, last, step = reverse and 180 or -180,
			reverse and -180 or 180, reverse and -1 or 1
		for offset = first, last, step do
			local record = session.candidate_record_at_cell(base_x + offset, base_z)
			if record then rows[#rows + 1] = table.concat({record.cell_x, record.cell_z,
				record.kind, record.mouth_x, record.mouth_y, record.mouth_z}, "/") end
		end
		table.sort(rows)
		return table.concat(rows, "\n"), #rows
	end
	local forward_rows, count = population(synthetic("0"), false)
	local reverse_rows, reverse_count = population(synthetic("0"), true)
	check(forward_rows == reverse_rows and count == reverse_count and count > 0,
		"candidate population depends on query order")
	local metrics = hillside.metrics()
	check(metrics.cache_limit == 128 and metrics.cache_evictions > 0,
		"bounded cache eviction absent")

	local actual = "compact"
	if expanded then
		local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
		local loaded = offline.new_evidence("0", false)
		local cx0, cz0 = loaded.planner_source.surface_cave_cell_at(-3740, -3340)
		local cx1, cz1 = loaded.planner_source.surface_cave_cell_at(3740, 3340)
		local candidates, hills, sinks = 0, 0, 0
		for cz = cz0, cz1 do for cx = cx0, cx1 do
			local record = loaded.planner_source.surface_cave_candidate_at_cell(cx, cz)
			if record then
				candidates = candidates + 1
				if record.kind == "hillside" then hills = hills + 1 else sinks = sinks + 1 end
			end
		end end
		check(candidates > 0 and hills > 0 and sinks > 0,
			"fixed layout candidate population differs")
		actual = table.concat({candidates, hills, sinks}, "/")
	end
	return table.concat({"schema\tgrug_wp40_quality_caves_v2",
		"hillside\t" .. table.concat({hill_record.mouth_x, hill_record.mouth_y,
			hill_record.mouth_z}, "/"),
		"sinkhole\t" .. table.concat({sink_record.mouth_x, sink_record.mouth_y,
			sink_record.mouth_z}, "/"),
		"ordered_population\t" .. count,
		"cache_evictions\t" .. metrics.cache_evictions,
		"actual\t" .. actual}, "\n") .. "\n"
end
