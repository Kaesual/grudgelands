-- Portable one-column regression for variable ordinary hydrology depths.

return function(repo)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local allocator_factory = dofile(wp40 .. "/counting_allocator.lua")
	local planner_factory = dofile(wp40 .. "/planner.lua")
	local planner_module = planner_factory(allocator_factory)
	local manifest = dofile(wp40 .. "/mapgen_manifest.lua").validate(
		dofile(wp40 .. "/r7_r6_manifest.lua")().r5_manifest_values)
	local allocator = allocator_factory.new("grug_wp40_r5_planner_allocator_v1")
	local stable_refs = {"hydro_1", "hydro_2", "hydro_3", "hydro_4", "join"}
	local hydrology = {
		"hydro_1", "profile_2", 2, 3, 2,
		"hydro_2", "profile_4", 4, 3, 2,
		"hydro_3", "profile_8", 8, 3, 2,
		"hydro_4", "profile_12", 12, 3, 2,
	}
	local interfaces = {"join", "rapid", 0, 1, 2, 1, 3}
	local members = {1, 2}
	local lookup = allocator:new_map("relational_lookup", 20)
	local function put(key, value)
		allocator:map_put(lookup, "relational_lookup", key, value)
	end
	put("schema", "grug_wp40_r5_relational_lookup_v1")
	put("allocator_identity", allocator)
	put("stable_refs", stable_refs)
	put("hydrology_ids", hydrology)
	put("hydrology_profile_ids", hydrology)
	put("hydrology_depths", hydrology)
	put("hydrology_bed_seal_layers", hydrology)
	put("hydrology_bank_seal_nodes", hydrology)
	put("interface_ids", interfaces)
	put("interface_kinds", interfaces)
	put("interface_hydrology_ordinals", interfaces)
	put("interface_upper_ordinals", interfaces)
	put("interface_lower_ordinals", interfaces)
	put("interface_member_start", interfaces)
	put("interface_members", members)
	local base = 513
	for index = 1, 4 do put(stable_refs[index], index + index * base) end
	put("join", 5 + base * base)

	local state = {id = "hydro_1", terrain = 7, water = 10, depth = 3}
	local source = {schema = "grug_wp40_r5_planner_source_v1"}
	function source.column_values_at()
		return "planned_water", 1, "zone", "biome", "race", state.terrain,
			state.water, state.id, state.depth, state.functional_kind,
			state.functional_y, state.feature_id, nil, state.transition_kind,
			state.transition_id, state.upper_y, state.lower_y, state.progress,
			nil, false
	end
	function source.hydrology_metric_values_at() return state.id, 1, 1, 1 end
	function source.surface_cave_run_at() return nil end
	function source.metrics() return {} end
	local planner = planner_module.new(source, manifest, lookup, allocator, {})
	allocator:seal_construction()
	local minp, maxp = {x = 0, y = -20, z = 0}, {x = 0, y = 20, z = 0}
	local function expect_failure(label, fragment)
		local ok, message = pcall(planner.plan_slice, planner, minp, maxp)
		if ok or type(message) ~= "string" or
				not message:find(fragment, 1, true) then
			error("hydrology depth fixture failure differs for " .. label, 0)
		end
	end
	local cases = {
		{"hydro_1", 2, 1, 3}, {"hydro_2", 4, 2, 6},
		{"hydro_3", 8, 5, 11}, {"hydro_4", 12, 8, 15},
	}
	local rows = {}
	for index = 1, #cases do
		local case = cases[index]
		for _, depth in ipairs({case[3], case[2], case[4]}) do
			state.id, state.depth = case[1], depth
			state.terrain, state.water = 10 - depth, 10
			state.functional_kind, state.transition_kind = nil, nil
			local plan = planner:plan_slice(minp, maxp)
			local found = false
			for run = plan.column_start[1], plan.column_start[2] - 1 do
				local offset = (run - 1) * 9
				if plan.run_values[offset + 4] == 18 then
					if plan.run_values[offset + 1] ~= state.terrain - 2 or
							plan.run_values[offset + 2] ~= state.terrain then
						error("hydrology bed seal did not follow actual bed", 0)
					end
					found = true
				end
			end
			if not found then error("hydrology bed seal run is absent", 0) end
			rows[#rows + 1] = table.concat({case[1], depth,
				state.terrain - 2, state.terrain}, "/")
		end
	end
	state.id, state.water, state.depth, state.terrain = "hydro_1", 10, 4, 6
	expect_failure("out-of-range ordinary depth", "profile depth differs")
	state.depth, state.terrain = 3, 8
	expect_failure("ordinary bed mismatch", "bed depth differs")
	state.depth, state.terrain = 2, 8
	state.functional_kind, state.functional_y, state.feature_id =
		"land_grade", 8, "join"
	planner:plan_slice(minp, maxp)
	state.depth, state.terrain, state.functional_y = 3, 7, 7
	expect_failure("non-nominal functional depth", "profile depth differs")
	state.functional_kind, state.functional_y, state.feature_id = nil, nil, nil
	state.depth, state.terrain = 2, 8
	state.transition_kind, state.transition_id = "rapid", "join"
	state.upper_y, state.lower_y, state.progress = 10, 9, 32768
	planner:plan_slice(minp, maxp)
	state.depth, state.terrain = 3, 7
	expect_failure("non-nominal transition depth", "profile depth differs")
	return table.concat(rows, "\n") .. "\n"
end
