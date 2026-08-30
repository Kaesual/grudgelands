-- Targeted real-production R6 transaction KAT (LuaJIT-only by contract).

return function(repo)
	local loader = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	local heightmap = loader.heightmap(-31007)
	local loaded = loader.new_public("0", heightmap, true)
	local minp, maxp = {x = -32, y = 0, z = -32}, {x = 47, y = 79, z = 47}
	local plan, generation = loaded.session.plan_slice(minp, maxp)
	local volume = 112 * 112 * 112
	local data, param2, light = {}, {}, {}
	for index = 1, volume do
		data[index], param2[index], light[index] = 0, 0, 0
	end
	local vm, _, observer = loader.vm_module.new({minp = minp, maxp = maxp,
		data = data, param2 = param2, light = light, heightmap = heightmap,
		content_contract = loaded.content_contract, water_level = 1,
		ignore_cid = loaded.content_contract.ignore_cid,
		verify_inactive_tail = false})
	local result = loaded.session.apply_fixture(vm, minp, maxp, plan, generation)
	local snapshot, metrics = observer.snapshot(), loaded.session.metrics()
	local values = {
		schema = "grug_wp40_r6_production_kat_v1",
		status = loaded.session.status(), result_code = result,
		plan_schema = plan.schema, generation = generation,
		column_count = plan.column_count,
		candidate_cell_count = plan.candidate_cell_count,
		candidate_count = plan.candidate_count,
		vm_get_data_calls = snapshot.calls.get_data,
		vm_set_data_calls = snapshot.calls.set_data,
		vm_get_param2_calls = snapshot.calls.get_param2_data,
		vm_set_param2_calls = snapshot.calls.set_param2_data,
		vm_get_light_calls = snapshot.calls.get_light_data,
		vm_set_light_calls = snapshot.calls.set_light_data,
		vm_set_lighting_calls = snapshot.calls.set_lighting,
		vm_calc_lighting_calls = snapshot.calls.calc_lighting,
		vm_update_liquids_calls = snapshot.calls.update_liquids,
		vm_trace_entries = #snapshot.trace,
		vm_trace_sha256 = loader.common.hex(loader.raw_sha256(
			table.concat(snapshot.trace, "\n") .. "\n")),
		vm_active_volume = snapshot.active_volume,
		vm_retained_capacity = snapshot.retained_capacity,
		vm_inactive_tail_checks = snapshot.inactive_tail_checks,
		vm_inactive_tail_unchanged = snapshot.inactive_tail_unchanged,
		planner_retained_buffer_growth_events =
			metrics.planner.retained_buffer_growth_events,
		planner_allocator_sealed = metrics.planner.allocator_sealed,
		planner_peak_candidates = metrics.planner.peak_candidates,
		planner_peak_candidate_cells = metrics.planner.peak_candidate_cells,
		settlement_retained_buffer_growth_events =
			metrics.settlement.retained_buffer_growth_events,
		settlement_allocator_sealed = metrics.settlement.allocator_sealed,
		settlement_peak_successor_runs = metrics.settlement.peak_successor_runs,
		settlement_replay_count = metrics.settlement.replay_count,
		settlement_modified_voxels = metrics.settlement.modified_voxels,
		settlement_content_dirty_columns = metrics.settlement.content_dirty_columns,
		settlement_param2_dirty_columns = metrics.settlement.param2_dirty_columns,
		settlement_light_dirty_columns = metrics.settlement.light_dirty_columns,
		settlement_liquid_dirty_columns = metrics.settlement.liquid_dirty_columns,
	}
	local lines = {}
	for key, value in pairs(values) do
		lines[#lines + 1] = key .. "\t" .. tostring(value) .. "\n"
	end
	table.sort(lines, loader.common.less_bytes)
	local body = table.concat(lines)
	return body .. "output_sha256\t" ..
		loader.common.hex(loader.raw_sha256(body)) .. "\n"
end
