-- Real-production shoreline contract KAT for round 6.
--
-- The selected windows cover a mainland coast, two ordinary named reaches,
-- an island landing and the Kezamba civic lake. Every exposed water-surface
-- column with a cardinal bank must have a zero-rise dry neighbor, and no dry
-- neighbor may end below that water surface. Raised route/deck surfaces are
-- counted separately because they are functional rims, not bank columns.

return function(repo)
	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(directory .. "/source/simple_map.lua")
	local schemas = dofile(directory .. "/schemas.lua")
	local canonical = dofile(directory .. "/canonical.lua")
	local deterministic = dofile(directory .. "/deterministic.lua")
	local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
	local horizontal_module = dofile(directory .. "/simple_map.lua")({
		source = source,
		schemas = schemas,
		canonical = canonical,
		deterministic = deterministic,
		raw_sha256 = raw_sha256,
	})
	assert(horizontal_module.validate_source())
	local seed = "531802985935182545"
	local horizontal = horizontal_module.new(seed)
	local height = dofile(directory .. "/height.lua")({
		source = source,
		canonical = canonical,
		deterministic = deterministic,
		coupled_grade = dofile(directory .. "/coupled_grade.lua")(),
		raw_sha256 = raw_sha256,
		horizontal_session = horizontal,
	}).new_runtime(seed)

	local boxes = {
		{id = "hearthpine_coast", min_x = -2540, max_x = -2320,
			min_z = -2520, max_z = -2440},
		{id = "dawnmere_start", min_x = 30, max_x = 280,
			min_z = -2505, max_z = -2370},
		{id = "goldmead_river", min_x = -80, max_x = 80,
			min_z = -2140, max_z = -1980},
		{id = "wyrmglass_landing", min_x = -2940, max_x = -2840,
			min_z = -190, max_z = 190},
		{id = "kezamba_cenote", min_x = 1780, max_x = 2010,
			min_z = 1510, max_z = 1670},
	}
	local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	local rows = {"schema\tgrug_r6_shore_kat_v1"}
	local all_contacts, all_water_columns, all_functional_rims = 0, 0, 0
	for box_index = 1, #boxes do
		local box = boxes[box_index]
		local contacts, water_columns, exact, plus_one, below, other,
			functional_rims, functional_plus_one, functional_other =
			0, 0, 0, 0, 0, 0, 0, 0, 0
		for z = box.min_z, box.max_z do
			for x = box.min_x, box.max_x do
				local water_class = horizontal.water_class_at(x, z)
				local water_y = height.water_surface_at(x, z)
				if water_class ~= "land" and water_y ~= nil and
						height.terrain_height_at(x, z) < water_y then
					local land_neighbors, bank_neighbors, has_exact, descriptions =
						0, 0, false, {}
					for direction_index = 1, #directions do
						local direction = directions[direction_index]
						local land_x, land_z = x + direction[1], z + direction[2]
						if horizontal.water_class_at(land_x, land_z) == "land" then
							land_neighbors = land_neighbors + 1
							contacts = contacts + 1
							local land_y = height.terrain_height_at(land_x, land_z)
							local kind, surface_y, feature_id =
								height.functional_surface_values_at(land_x, land_z)
							descriptions[#descriptions + 1] = table.concat({land_x,
								land_z, land_y, kind or "terrain", surface_y or "-",
								feature_id or "-"}, "/")
							local raised_path_rim = kind == "land_grade" and
								type(feature_id) == "string" and
								(feature_id:match("^route_") or
									feature_id:match("^poi_spur_")) and
								land_y > water_y
							if raised_path_rim then
								functional_rims = functional_rims + 1
								if land_y == water_y + 1 then
									functional_plus_one = functional_plus_one + 1
								else
									functional_other = functional_other + 1
								end
							else
								bank_neighbors = bank_neighbors + 1
							end
							if land_y == water_y then
								exact, has_exact = exact + 1, true
							elseif land_y == water_y + 1 then
								plus_one = plus_one + 1
							elseif land_y < water_y then
								below = below + 1
							else
								other = other + 1
							end
						end
					end
					if land_neighbors > 0 then
						water_columns = water_columns + 1
						assert(bank_neighbors == 0 or has_exact,
							"water surface lacks a zero-rise bank neighbor at " ..
							x .. "," .. z .. ": " .. table.concat(descriptions, ","))
					end
				end
			end
		end
		assert(water_columns > 0, "shore fixture has no contacts: " .. box.id)
		assert(below == 0, "land below water in " .. box.id)
		assert(plus_one == functional_plus_one,
			"first land column remains one node above water in " .. box.id)
		assert(other == functional_other,
			"non-functional shore column is above water in " .. box.id)
		all_contacts = all_contacts + contacts
		all_water_columns = all_water_columns + water_columns
		all_functional_rims = all_functional_rims + functional_rims
		rows[#rows + 1] = table.concat({"shore", box.id, water_columns,
			contacts, exact, plus_one, below, other, functional_rims,
			functional_plus_one}, "\t")
	end
	assert(all_contacts >= 1000 and all_water_columns >= 1000,
		"shore fixture population is too small")
	rows[#rows + 1] = table.concat({"total", all_water_columns,
		all_contacts, all_functional_rims}, "\t")
	return table.concat(rows, "\n") .. "\n"
end
