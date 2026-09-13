-- Bounded regression for terrain-fitted shared road junctions.

return function(repo)
	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(directory .. "/source/simple_map.lua")
	local schemas = dofile(directory .. "/schemas.lua")
	local canonical = dofile(directory .. "/canonical.lua")
	local deterministic = dofile(directory .. "/deterministic.lua")
	local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
	local horizontal_module = dofile(directory .. "/simple_map.lua")({
		source = source, schemas = schemas, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256,
	})
	assert(horizontal_module.validate_source())
	local rows = {"schema\tgrug_wp40_quality_junction_fixture_v1"}
	for _, seed in ipairs({"0", "13191094842853985814"}) do
		local horizontal = horizontal_module.new(seed)
		local height = dofile(directory .. "/height.lua")({
			source = source, canonical = canonical, deterministic = deterministic,
			coupled_grade = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/coupled_grade.lua")(),
			raw_sha256 = raw_sha256, horizontal_session = horizontal,
		}).new_runtime(seed)
		local records = height.quality_junction_records()
		local free_count, fixed_count, shared_count, improved_count = 0, 0, 0, 0
		local maximum_free_deviation = 0
		for record_index = 1, #records do
			local record = records[record_index]
			assert(record.target_y == height.terrain_height_at(record.x, record.z),
				"visible junction differs from its shared target")
			if #record.uses > 1 then shared_count = shared_count + 1 end
			for use_index = 1, #record.uses do
				assert(record.uses[use_index].final_y == record.target_y,
					"connected endpoint heights differ")
			end
			if record.constraint_kind == "free_terrain_feasible" then
				free_count = free_count + 1
				maximum_free_deviation = math.max(maximum_free_deviation,
					record.maximum_natural_deviation)
				assert(record.target_y == math.max(record.feasible_lower_y,
					math.min(record.natural_y, record.feasible_upper_y)),
					"free junction did not choose its nearest feasible terrain height")
				local previous_deviation = math.abs(record.previous_target_y -
					record.natural_y)
				assert(record.maximum_natural_deviation <= previous_deviation,
					"terrain fitting is farther from terrain than the former zone pin")
				if record.maximum_natural_deviation < previous_deviation then
					improved_count = improved_count + 1
				end
			else
				fixed_count = fixed_count + 1
				if record.constraint_kind == "water_clearance" then
					local water_y = assert(height.water_surface_at(record.x, record.z))
					assert(record.target_y >= water_y + 1,
						"water junction lost surface clearance")
				elseif record.constraint_kind == "landing_endpoint" then
					assert(record.target_y == 2, "landing elevation changed")
				end
			end
		end
		assert(free_count > 0 and fixed_count > 0 and shared_count > 0 and
			improved_count > 0,
			"junction fixture lacks a required boundary class")
		rows[#rows + 1] = table.concat({"seed", seed, #records, free_count,
			fixed_count, shared_count, improved_count, maximum_free_deviation}, "\t")
	end
	rows[#rows + 1] = "junction_fixture\tok"
	return table.concat(rows, "\n") .. "\n"
end
