-- Bounded real R5 planner/writer plus R6 successor fixture equivalence.
-- Target immutable production modules with identical current fixture tooling.
return function(repo, production_repo, check_composition, compact)
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
	local identity = {}
	local planner = planner_module.new(source, manifest, lookup, allocator, identity)
	allocator:seal_construction()

	local contract, stone, heightmap, context, common, raw_sha256, vm_module
	if compact then
		-- The compact composition test needs catalog semantics, not compressed
		-- MTS voxels. Reuse the existing portable header-only catalog fixture;
		-- offline.lua eagerly decodes MTS with FFI and is LuaJIT-only.
		local _, content = dofile(repo .. "/tools/wp40/quality/surface_fixture.lua")(repo)
		contract = content.content_contract()
		stone = assert(contract.content_cids[content.content_ref("default:stone")])
		heightmap = {}
		for index = 1, 6400 do heightmap[index] = -31007 end
		context = {schema = "grug_wp40_r5_mapgen_context_v1"}
		function context.get_heightmap() return heightmap end
		function context.metrics()
			return {heightmap_fetch_calls = 0, heightmap_external_table_allocations = 0,
				metrics_result_table_allocations = 0}
		end
		common = dofile(repo .. "/tools/wp40/r6/common.lua")
		raw_sha256 = common.new_sha256()
		vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	else
		local loader = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo, production_repo)
		local cids
		contract, cids = loader.fixtures.new_content_contract()
		stone = assert(cids["default:stone"])
		heightmap = loader.heightmap(-31007)
		context = loader.fixtures.context(heightmap)
		common, raw_sha256, vm_module = loader.common, loader.raw_sha256, loader.vm_module
	end
	local adapter_allocator = allocator_factory.new("grug_wp40_r5_adapter_allocator_v1")
	local adapter_module = dofile(production_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua")(allocator_factory)
	local adapter = adapter_module.new(manifest, contract.r5,
		context, adapter_allocator, identity)
	adapter_allocator:seal_construction()
	local rows = {}
	local function digest(values)
		local blocks, parts = {}, {}
		for index = 1, #values do
			parts[#parts + 1] = tostring(values[index]) .. ","
			if #parts == 1024 then
				blocks[#blocks + 1] = table.concat(parts)
				parts = {}
			end
		end
		blocks[#blocks + 1] = table.concat(parts)
		return common.hex(raw_sha256(table.concat(blocks)))
	end
	for case = 1, compact and 1 or 3 do
		local minp = {x = -32, y = case == 1 and 48 or -4, z = -32}
		local maxp = {x = minp.x + 79, y = minp.y + (compact and 0 or 15), z = minp.z + 79}
		local plan, generation = planner:plan_slice(minp, maxp)
		local ex, ey, ez = 112, compact and 33 or 48, 112
		local data, param2, light = {}, {}, {}
		for z = minp.z - 16, maxp.z + 16 do
			for y = minp.y - 16, maxp.y + 16 do
				for x = minp.x - 16, maxp.x + 16 do
					local index = #data + 1
					data[index] = case == 1 and stone or
						(y < 0 and stone or (y == 0 and 10 or 0))
					param2[index], light[index] = 0, y > 0 and 15 or 0
					if case == 3 and x == minp.x - 16 then data[index] = 65535 end
				end
			end
		end
		assert(#data == ex * ey * ez)
		local vm, _, observer = vm_module.new({minp = minp, maxp = maxp,
			data = data, param2 = param2, light = light, heightmap = heightmap,
			content_contract = contract, water_level = 1,
			ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
		local result = adapter:apply(vm, minp, maxp, plan, generation, "offline_fixture")
		local snapshot, metrics = observer.snapshot(), adapter:metrics()
		if check_composition then
			local deferred, _, deferred_observer = vm_module.new({
				minp = minp, maxp = maxp, data = data, param2 = param2, light = light,
				heightmap = heightmap, content_contract = contract, water_level = 1,
				ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
			local deferred_result = adapter:apply(deferred, minp, maxp, plan,
				generation, "offline_fixture", "outer_transaction")
			local projected = deferred_observer.snapshot()
			assert(deferred_result == result, "composed dirty result changed")
			assert(digest(projected.data) == digest(snapshot.data) and
				digest(projected.param2) == digest(snapshot.param2),
				"composed content projection differs")
			assert(projected.calls.get_light_data == 0 and
				projected.calls.set_lighting == 0 and projected.calls.calc_lighting == 0 and
				projected.calls.set_light_data == 0, "discarded inner lighting still ran")
			assert(projected.calls.update_liquids == snapshot.calls.update_liquids,
				"composition changed liquid intent")
			assert(not pcall(adapter.apply, adapter, deferred, minp, maxp, plan,
				generation, "offline_fixture", "unknown_owner"),
				"invalid lighting owner was accepted")
		end
		rows[#rows + 1] = "case\t" .. case .. "\t" .. result .. "\n"
		for _, key in ipairs({"data", "param2", "light", "trace"}) do
			rows[#rows + 1] = key .. "\t" .. digest(snapshot[key]) .. "\n"
		end
		local runs = {}
		for index = 1, plan.run_count * 9 do runs[index] = plan.run_values[index] end
		rows[#rows + 1] = "plan_intent\t" .. digest(runs) .. "\n"
		for _, key in ipairs({"modified_voxels", "content_dirty_columns",
			"param2_dirty_columns", "light_dirty_columns", "liquid_dirty_columns"}) do
			rows[#rows + 1] = key .. "\t" .. tostring(metrics[key]) .. "\n"
		end
	end
	if not compact then
		rows[#rows + 1] = dofile(repo .. "/tools/wp40/quality/gravewood_writer_fixture.lua")(
			repo, production_repo, false)
	end
	return table.concat(rows)
end
