-- Actual R5 planner KAT for the transient named-wet result cache.
return function(repo, production_repo)
	production_repo = production_repo or repo
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local allocator_factory = dofile(wp40 .. "/counting_allocator.lua")
	local planner_factory = dofile(production_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/planner.lua")
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
	for index = 1, 4 do put(stable_refs[index], index + index * 513) end
	put("join", 5 + 513 * 513)

	local state = {mode = "mixed", calls = 0, fail_x = false, fail_z = false}
	local source = {schema = "grug_wp40_r5_planner_source_v1"}
	function source.column_values_at(x, z)
		state.calls = state.calls + 1
		if x == state.fail_x and z == state.fail_z then error("injected source error", 0) end
		if state.mode == "mixed" and (x + z * 2) % 5 == 0 then
			return "planned_water", 1, "zone", "biome", "race", 8, 10,
				"hydro_1", 2, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
		end
		return "land", 1, "zone", "biome", "race", 8, nil, nil, nil,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
	end
	function source.hydrology_metric_values_at() return nil end
	function source.surface_cave_run_at() return nil end
	function source.surface_cave_candidate_at_cell() return nil end
	function source.surface_cave_cell_at() return 0, 0 end
	function source.surface_cave_constants() return 80, -30912, 24, 2, 24 end
	function source.coast_profile_at() return nil end
	function source.landmark_excluded_at() return false end
	function source.metrics() return {} end
	local planner = planner_module.new(source, manifest, lookup, allocator, {})
	allocator:seal_construction()

	local function encode_plan(plan, column_count)
		local parts = {tostring(plan.run_count), ":"}
		for index = 1, column_count + 1 do
			parts[#parts + 1] = tostring(plan.column_start[index]) .. ","
		end
		for index = 1, plan.run_count * 9 do
			parts[#parts + 1] = tostring(plan.run_values[index]) .. ","
		end
		return table.concat(parts)
	end
	local function plan(minp, maxp)
		local before = state.calls
		local result = planner:plan_slice(minp, maxp)
		local column_count = (maxp.x - minp.x + 1) * (maxp.z - minp.z + 1)
		return encode_plan(result, column_count), state.calls - before
	end
	local function digest(bytes)
		local value = 23
		for index = 1, #bytes do
			value = (value * 257 + string.byte(bytes, index)) % 16777213
		end
		return tostring(value)
	end
	local small_min, small_max = {x = -2, y = -20, z = -2},
		{x = 2, y = 20, z = 2}
	local mixed_bytes, mixed_calls = plan(small_min, small_max)
	state.mode = "dry"
	local dry_bytes, dry_calls = plan(small_min, small_max)
	assert(mixed_bytes ~= dry_bytes, "wet/dry planner runs unexpectedly agree")
	state.mode = "mixed"
	local repeat_bytes, repeat_calls = plan(small_min, small_max)
	assert(repeat_bytes == mixed_bytes, "wet cache did not reset deterministically")
	state.fail_x, state.fail_z = 0, 0
	local ok, message = pcall(planner.plan_slice, planner, small_min, small_max)
	assert(not ok and type(message) == "string" and
		message:find("injected source error", 1, true), "source failure differs")
	state.fail_x, state.fail_z = false, false
	local recovered_bytes, recovery_calls = plan(small_min, small_max)
	assert(recovered_bytes == mixed_bytes, "failed plan cache escaped into recovery")

	state.mode = "dry"
	local bound_bytes, bound_calls = plan({x = -40, y = -20, z = -40},
		{x = 39, y = 20, z = 39})
	assert(#bound_bytes > #dry_bytes, "maximum-bound plan was not exercised")
	assert(#mixed_bytes == 1713 and digest(mixed_bytes) == "14637360" and
		#dry_bytes == 1628 and digest(dry_bytes) == "9167105" and
		digest(bound_bytes) == "2402327", "canonical planner run bytes differ")
	if production_repo == repo then
		-- Each central column still owns its ordinary full tuple read. Neighbor
		-- wet results add at most the distinct two-column plan halo.
		assert(mixed_calls <= 106 and dry_calls <= 106 and repeat_calls <= 106 and
			recovery_calls <= 106 and bound_calls <= 13456,
			"named-wet cache did not bound distinct plan coordinates")
	else
		assert(mixed_calls > 81 and dry_calls > 81 and repeat_calls > 81 and
			recovery_calls > 81 and bound_calls > 7056,
			"baseline unexpectedly has bounded named-wet reads")
	end
	return table.concat({"schema\tgrug_wp40_r5_wet_cache_fixture_v1",
		"mixed_bytes\t" .. #mixed_bytes, "dry_bytes\t" .. #dry_bytes,
		"mixed_digest\t" .. digest(mixed_bytes),
		"dry_digest\t" .. digest(dry_bytes),
		"bound_digest\t" .. digest(bound_bytes),
		"mixed_calls\t" .. mixed_calls, "dry_calls\t" .. dry_calls,
		"repeat_calls\t" .. repeat_calls, "recovery_calls\t" .. recovery_calls,
		"bound_calls\t" .. bound_calls, ""}, "\n")
end
