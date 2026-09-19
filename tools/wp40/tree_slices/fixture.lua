-- Compact live/evidence regression for native schematic y-slice compression.

return function(repo, settlement_path)
	local function check(condition, message)
		if not condition then error("tree-slice fixture: " .. message, 0) end
		return condition
	end
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local hash = dofile(wp40 .. "/r6_hash.lua")(raw_sha256)
	local settlement_factory = dofile(settlement_path or
		(wp40 .. "/r6_settlement.lua"))
	local templates_factory = dofile(wp40 .. "/r6_templates.lua")
	local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	local pine_id, synthetic_id = "pine_hills_pine_tree", "tree_slice_synthetic"
	local support_name, pine_tree_name = "test:variant_soil", "default:pine_tree"
	local pine_needles_name, marker_name = "default:pine_needles", "test:slice_marker"
	local names = {support_name, pine_tree_name, pine_needles_name, marker_name}
	local cids, masks, refs = {100, 101, 102, 103}, {9, 8, 8, 8}, {}
	for index = 1, #names do refs[names[index]] = index end
	local contract = {schema = "grug_wp40_r6_content_contract_v1",
		ignore_cid = 65535, ordinary_water_family_id = 1,
		river_water_family_id = 2, content_names = names,
		content_cids = cids, content_kind_masks = masks, r5 = {}}
	function contract.r5.resolve(role, _, auxiliary)
		check(auxiliary == 0, "R5 auxiliary differs")
		if role == 1 then return 0, 0, 0, nil end
		if role == 10 or role == 13 then return 10, 2, 0, nil end
		return cids[1], 1, 0, nil
	end
	function contract.resolve_r6(content_ref, param2)
		return cids[content_ref], 1, 1, param2, masks[content_ref]
	end
	local function classify(cid)
		if cid == 0 then return 1, 0, 0, 0, true, true, true, true, 0 end
		if cid == 10 then return 4, 1, 1, 0, false, true, true, true, 0 end
		if cid == 65535 then return 3, 0, 0, 0, false, false, false, false, 0 end
		if cid == cids[1] then return 7, 0, 0, 0, false, false, false, false, 0 end
		if cid == cids[3] then return 8, 0, 0, 0, false, false, false, false, 0 end
		if cid == cids[2] or cid == cids[4] then
			return 6, 0, 0, 0, false, false, false, false, 0
		end
		return 9, 0, 0, 0, false, false, false, false, 0
	end
	contract.classify, contract.classify_runtime = classify, classify
	local surface = {id = "tree_slice_biome", top = support_name,
		filler = support_name, filler_depth = 1, shore = support_name,
		bed = support_name, dust = support_name, top_ref = 1, filler_ref = 1,
		shore_ref = 1, bed_ref = 1, dust_ref = 0}
	local decorations = {
		{id = pine_id, biomes = {surface.id}, kind = "template",
			asset_or_node = "pine_tree.mts", host = "test:base_soil",
			numerator = 1, denominator = 1,
			rule = "center_xz;quarter_turn_rotation", settlement_class = 2},
		{id = synthetic_id, biomes = {surface.id}, kind = "template",
			asset_or_node = "tree_slice_synthetic.mts", host = "test:base_soil",
			numerator = 1, denominator = 1,
			rule = "center_xz;quarter_turn_rotation", settlement_class = 2},
	}
	local content = {}
	function content.content_contract() return contract end
	function content.surfaces() return {surface} end
	function content.new_surface_selector() return function() return surface end end
	function content.resources() return {} end
	function content.cultural() return {} end
	function content.decorations() return decorations end
	function content.decoration_cover(id, biome, support_ref)
		return (id == pine_id or id == synthetic_id) and biome == surface.id and
			support_ref == 1 and 1 or 0
	end
	function content.wp43_projection()
		return {tiers = {{y_min = -100, node = support_name},
			{y_min = -300, node = support_name}, {y_min = -500, node = support_name},
			{y_min = -700, node = support_name}, {y_min = -1000, node = support_name},
			{y_min = -31000, node = support_name}}, race_regions = {}}
	end
	function content.content_ref(name) return refs[name] end
	function content.param2_kind() return "none" end

	-- Complete parsed 5x16x5 pine cell population, bound to the shipped asset below.
	local pine_codes = table.concat({
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaamqnqmaaaaaaaaaamqnqmaaaaaaaaaamqnqmaaaaaaaaaa",
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaqnanqannnaaaaaaqnanqannnaaaaaaqnanqannnaaaaaa",
		"aataaaataaaataaaataaaataaaataaaataanatanantnaaataanatanantnaaataanatanannnaaanaa",
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaqnanqannnaaaaaaqnanqannnaaaaaaqnanqannnaaaaaa",
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaamqnqmaaaaaaaaaamqnqmaaaaaaaaaamqnqmaaaaaaaaaa",
	})
	check(#pine_codes == 400, "frozen pine cell population differs")
	local alphabet = {
		a = {"air", 0, false}, t = {pine_tree_name, 254, true},
		n = {pine_needles_name, 254, false},
		m = {pine_needles_name, 190, false}, q = {pine_needles_name, 222, false},
	}
	local pine_cells = {}
	for index = 1, #pine_codes do
		local source_cell = check(alphabet[pine_codes:sub(index, index)],
			"unknown pine cell code")
		pine_cells[index] = {name = source_cell[1], prob = source_cell[2],
			param2 = 0, force_place = source_cell[3]}
	end
	local pine_slice_bytes = {127, 127, 63, 63, 63, 63, 127, 127,
		127, 63, 127, 127, 63, 127, 127, 127}
	local pine_slices = {}
	for index = 1, #pine_slice_bytes do
		pine_slices[index] = {ypos = index - 1, prob = pine_slice_bytes[index] * 2}
	end
	local marker = function(probability)
		return {name = marker_name, prob = probability, param2 = 0, force_place = false}
	end
	local synthetic_cells = {marker(254), marker(254), marker(254), marker(254),
		marker(0), marker(254), marker(254), marker(254)}
	local template_source = {}
	function template_source.read(filename)
		if filename == "pine_tree.mts" then
			return {size = {x = 5, y = 16, z = 5},
				yslice_prob = pine_slices, data = pine_cells}
		end
		check(filename == "tree_slice_synthetic.mts", "unexpected template source")
		return {size = {x = 2, y = 4, z = 1}, yslice_prob = {
			{ypos = 0, prob = 254}, {ypos = 1, prob = 0},
			{ypos = 2, prob = 254}, {ypos = 3, prob = 254}}, data = synthetic_cells}
	end
	local asset_bytes = common.read_file(
		repo .. "/mods/BASE/default/schematics/pine_tree.mts")
	local asset_sha = common.hex(raw_sha256(asset_bytes))
	check(asset_sha == "3d91afa7dd3fbf6d15c295716af5409d3d77b0dff1464d623ef91433fdfd508f",
		"shipped pine asset digest differs")
	check(asset_bytes:sub(1, 12) == "MTSM" .. string.char(0, 4, 0, 5, 0, 16, 0, 5),
		"shipped pine MTS header differs")
	for index = 1, #pine_slice_bytes do
		check(string.byte(asset_bytes, 12 + index) == pine_slice_bytes[index],
			"shipped pine slice byte differs")
	end

	local base_templates = templates_factory(hash, content, template_source)
	local calls, templates = {}, {}
	function templates.rotation(...) return base_templates.rotation(...) end
	function templates.rotation_runtime(...) return base_templates.rotation_runtime(...) end
	function templates.maximum_footprint() return base_templates.maximum_footprint() end
	function templates.probability_include(full_seed, definition_id, root_x,
			root_y, root_z, rotation, trial, x, y, z, probability)
		local included = base_templates.probability_include(full_seed, definition_id,
			root_x, root_y, root_z, rotation, trial, x, y, z, probability)
		calls[#calls + 1] = table.concat({definition_id, root_x, root_y, root_z,
			rotation, trial, x, y, z, probability, included and 1 or 0}, "/")
		return included
	end
	local planner_source = {}
	function planner_source.column_values_at()
		return "land", 1, "tree_slice_zone", surface.id, "none", 4,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
	end
	function planner_source.surface_cave_run_at() return nil end
	function planner_source.surface_cave_candidate_at_cell() return nil end
	function planner_source.surface_cave_cell_at() return 0, 0 end
	function planner_source.coast_profile_at() return nil end
	function planner_source.landmark_excluded_at() return false end
	local horizontal = {}
	function horizontal.static_exclusion_values_at() return nil end
	function horizontal.housing_mask_id_at() return nil end
	local anchor = {id = "tree_slice_apex", position = {x = 10000, z = 10000}}
	local source = {claim_exclusions = {}, routes = {}, hard_protection = {},
		anchors = {anchor}, apex_sockets = {}, hydrology_profiles = {},
		hydrology = {}, hydrology_interfaces = {}}
	for index = 1, 24 do
		source.apex_sockets[index] = {id = "tree_slice_socket_" .. index,
			anchor_id = anchor.id, offset = {x = index, z = 0}}
	end
	local allocator = {}
	function allocator.new_array() return {} end
	function allocator.new_map() return {} end
	function allocator.grow(_, values, _, old_size, new_size)
		for index = old_size + 1, new_size do values[index] = 0 end
	end
	function allocator.map_put(_, values, _, key, value) values[key] = value end
	function allocator.seal_construction() end
	function allocator.enter_hotpath() end
	function allocator.leave_hotpath() end
	function allocator.metrics()
		return {hotpath_table_allocations = 0, construction_sealed = true}
	end
	local roots = {{catalog = 1, parameter = 2, x = -10, y = 5, z = -10},
		{catalog = 2, parameter = 2, x = 18, y = 5, z = 20}}
	local r5_adapter = {}
	function r5_adapter.apply(_, shadow)
		local data = {}
		shadow:get_data(data)
		local emerged_min, emerged_max = shadow:get_emerged_area()
		local ex, ey = emerged_max.x - emerged_min.x + 1,
			emerged_max.y - emerged_min.y + 1
		for index = 1, #roots do
			local root = roots[index]
			local offset = (root.z - emerged_min.z) * ex * ey +
				(4 - emerged_min.y) * ex + (root.x - emerged_min.x) + 1
			data[offset] = cids[1]
		end
		shadow:set_data(data)
		return "tree_slice_r5_ready"
	end
	local stable_refs = {pine_id, synthetic_id}
	table.sort(stable_refs, hash.less_bytes)
	local identity = {value = {}}
	local settlement, settlement_fixture = settlement_factory.new_runtime({
		full_seed_string = "0", r5_adapter = r5_adapter, content = content,
		templates = templates, hash = hash, horizontal = horizontal,
		planner_source = planner_source, construction_identity = identity,
		cultural_registrations = {}, source = source,
		planner_stable_refs = stable_refs, counting_allocator = allocator})

	local function rotation_for(candidate)
		return math.floor(string.byte(hash.digest("decoration_rotation_v1", "0",
			{decorations[candidate.catalog].id, candidate.x, candidate.y,
				candidate.z}), 1) / 64)
	end
	local function expected_calls()
		local rows = {}
		for candidate_index = 1, #roots do
			local candidate = roots[candidate_index]
			local definition = decorations[candidate.catalog]
			local rotation = rotation_for(candidate)
			local template = base_templates.rotation_runtime(definition.id, rotation)
			local slice_ok = {}
			for y = 1, template.size_y do
				local probability = template.y_slice_probabilities[y]
				local included = base_templates.probability_include("0", definition.id,
					candidate.x, candidate.y, candidate.z, rotation, "slice",
					0, y - 1, 0, probability)
				slice_ok[y] = included
				rows[#rows + 1] = table.concat({definition.id, candidate.x,
					candidate.y, candidate.z, rotation, "slice", 0, y - 1, 0,
					probability, included and 1 or 0}, "/")
			end
			for z = 1, template.size_z do
				for y = 1, template.size_y do
					if slice_ok[y] then
						for x = 1, template.size_x do
							local source_index = (z - 1) * template.size_x *
								template.size_y + (y - 1) * template.size_x + x
							local node = template.cells[source_index]
							if node.name ~= "air" then
								local included = base_templates.probability_include("0",
									definition.id, candidate.x, candidate.y, candidate.z,
									rotation, "node", x - 1, y - 1, z - 1,
									node.probability)
								rows[#rows + 1] = table.concat({definition.id,
									candidate.x, candidate.y, candidate.z, rotation,
									"node", x - 1, y - 1, z - 1, node.probability,
									included and 1 or 0}, "/")
							end
						end
					end
				end
			end
		end
		return table.concat(rows, "\n") .. "\n"
	end
	local expected_probability_calls = expected_calls()
	local function take_calls(label)
		local bytes = table.concat(calls, "\n") .. "\n"
		calls = {}
		check(bytes == expected_probability_calls,
			label .. " source coordinates or slice call count differ")
		return common.hex(raw_sha256(bytes))
	end
	local evidence = settlement_fixture.scan_horizontal_owner(-32, -32, {}, roots)
	local evidence_call_hash = take_calls("evidence")
	check(evidence.decorations[pine_id].accepted == 1 and
		evidence.decorations[pine_id].reserved == 400,
		"pine evidence acceptance or conservative bounds differ")
	check(evidence.decorations[synthetic_id].accepted == 1 and
		evidence.decorations[synthetic_id].reserved == 8,
		"synthetic evidence acceptance or conservative bounds differ")

	local pine_rotation = rotation_for(roots[1])
	check(pine_rotation == 1, "pine witness rotation differs")
	local pine_template = base_templates.rotation_runtime(pine_id, pine_rotation)
	local decisions, pine_destination_y, pine_trunk_y = {}, {}, {}
	local next_y = pine_template.min_y
	for y = 1, pine_template.size_y do
		local included = base_templates.probability_include("0", pine_id,
			roots[1].x, roots[1].y, roots[1].z, pine_rotation, "slice",
			0, y - 1, 0, pine_template.y_slice_probabilities[y])
		decisions[y] = included and "1" or "0"
		if included then
			pine_destination_y[#pine_destination_y + 1] = roots[1].y + next_y
			local center = (2 * pine_template.size_x * pine_template.size_y) +
				(y - 1) * pine_template.size_x + 3
			if pine_template.cells[center].name == pine_tree_name then
				pine_trunk_y[#pine_trunk_y + 1] = roots[1].y + next_y
			end
			next_y = next_y + 1
		end
	end
	check(table.concat(decisions) == "1100001110111111",
		"shipped pine rejection witness differs")
	local function evidence_cid(x, y, z)
		for index = 1, #evidence.direct_rows do
			local row = evidence.direct_rows[index]
			if row[1] == x and row[2] == y and row[3] == z and row[7] == 12 then
				return row[4]
			end
		end
		return 0
	end
	for index = 1, #pine_trunk_y do
		check(evidence_cid(roots[1].x, pine_trunk_y[index], roots[1].z) ==
			cids[2], "pine evidence trunk is not vertically contiguous")
	end
	check(evidence_cid(roots[1].x, roots[1].y + 13,
		roots[1].z) == 0, "pine evidence retained an uncompressed trunk cell")
	check(evidence_cid(18, 6, 20) == 0 and evidence_cid(19, 6, 20) == cids[4] and
		evidence_cid(18, 7, 20) == cids[4] and evidence_cid(19, 7, 20) == cids[4],
		"evidence node omission compressed or slice omission did not compress")

	local owner_min, owner_max = {x = -32, y = 0, z = -32},
		{x = 47, y = 79, z = 47}
	local column_values, column_start, run_values = {}, {}, {}
	for column = 1, 6400 do
		local cbase, rbase = (column - 1) * 12, (column - 1) * 9
		for field = 1, 12 do column_values[cbase + field] = 0 end
		column_start[column] = column
		run_values[rbase + 1], run_values[rbase + 2] = 4, 4
		run_values[rbase + 3], run_values[rbase + 4] = 7, 28
		for field = 5, 9 do run_values[rbase + field] = 0 end
	end
	column_start[6401] = 6401
	for index = 1, #roots do
		local root = roots[index]
		local column = (root.z - owner_min.z) * 80 + (root.x - owner_min.x) + 1
		local base = (column - 1) * 12
		column_values[base + 5], column_values[base + 7],
			column_values[base + 8] = 4, 1, 1
	end
	local candidate_values = {}
	for index = 1, #roots do
		local root, base = roots[index], (index - 1) * 14
		candidate_values[base + 1], candidate_values[base + 2] = 2, root.catalog
		candidate_values[base + 3], candidate_values[base + 4] = 2, root.x
		candidate_values[base + 5], candidate_values[base + 6] = root.y, root.z
		for field = 7, 14 do candidate_values[base + field] = 0 end
	end
	local plan = {schema = "grug_wp40_r6_refinement_plan_v1",
		construction_identity = identity.value, generation = 1, valid = true,
		min_x = owner_min.x, min_y = owner_min.y, min_z = owner_min.z,
		max_x = owner_max.x, max_y = owner_max.y, max_z = owner_max.z,
		r5_plan = {column_start = column_start, run_values = run_values},
		r5_generation = 1, column_values = column_values, column_count = 6400,
		candidate_cell_values = {-2, -2, 1, 3}, candidate_cell_count = 1,
		candidate_values = candidate_values, candidate_count = 2,
		stable_refs = stable_refs}
	local function fixed_array(count, value)
		local result = {}
		for index = 1, count do result[index] = value end
		return result
	end
	local volume = 112 * 112 * 112
	local vm, _, observer = vm_module.new({minp = owner_min, maxp = owner_max,
		data = fixed_array(volume, 0), param2 = fixed_array(volume, 0),
		light = fixed_array(volume, 0), heightmap = fixed_array(6400, -31007),
		content_contract = contract, water_level = 1,
		ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
	local applied = settlement:apply(vm, owner_min, owner_max, plan, 1, "fixture")
	local live_call_hash = take_calls("live")
	check(applied:match("^applied_[cplq]+$") ~= nil, "live result differs")
	local snapshot, axis = observer.snapshot(), 112
	local function live_cid(x, y, z)
		local index = (z - snapshot.emin.z) * axis * axis +
			(y - snapshot.emin.y) * axis + (x - snapshot.emin.x) + 1
		return snapshot.data[index]
	end
	for index = 1, #pine_trunk_y do
		check(live_cid(roots[1].x, pine_trunk_y[index], roots[1].z) == cids[2],
			"pine live trunk is not vertically contiguous")
	end
	check(live_cid(roots[1].x, roots[1].y + 13,
		roots[1].z) == 0, "pine live retained an uncompressed trunk cell")
	check(live_cid(18, 6, 20) == 0 and live_cid(19, 6, 20) == cids[4] and
		live_cid(18, 7, 20) == cids[4] and live_cid(19, 7, 20) == cids[4],
		"live node omission compressed or slice omission did not compress")
	check(evidence_call_hash == live_call_hash, "live/evidence probability calls differ")
	local rows = {"schema\tgrug_wp40_tree_slice_micro_kat_v1",
		"asset_sha256\t" .. asset_sha, "pine_rotation\t" .. pine_rotation,
		"pine_source_slices\t" .. table.concat(decisions),
		"pine_destination_y\t" .. table.concat(pine_destination_y, ","),
		"probability_calls_sha256\t" .. evidence_call_hash,
		"evidence_reserved\t400/8",
		"synthetic_destination\t5,6,7/node_gap_at_6_x18",
		"live_result\t" .. applied}
	local bytes = table.concat(rows, "\n") .. "\n"
	return bytes .. "digest\t" .. common.hex(raw_sha256(bytes)) .. "\n"
end
