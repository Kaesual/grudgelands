-- WP40 R6 P7-P9 refinement settlement and single VM transaction.

local function settlement_factory()
	local MAX_SAFE = 9007199254740991
	local MAX_VOLUME = 112 * 112 * 112
	local MAX_RUNS = 512000
	local RUN_STRIDE = 9
	local COLUMN_STRIDE = 12
	local CELL_STRIDE = 4
	local CANDIDATE_STRIDE = 14
	local CLASS_AIR, CLASS_FOREIGN, CLASS_IGNORE, CLASS_LIQUID = 1, 2, 3, 4
	local CLASS_NATIVE_ORE, CLASS_NATURAL_HOST, CLASS_NATURAL_SURFACE = 5, 6, 7
	local CLASS_NATURAL_VEGETATION, CLASS_UNKNOWN = 8, 9
	local CLASS_WP43_RESOURCE, CLASS_WP43_STRATUM = 10, 11
	local FACE_X = {1, -1, 0, 0, 0, 0}
	local FACE_Y = {0, 0, 1, -1, 0, 0}
	local FACE_Z = {0, 0, 0, 0, 1, -1}

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	local function integer(value, label, minimum, maximum, code)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail(code or "fail_bound", label .. " is not an exact bounded integer")
		end
		return value
	end

	local function exact_fields(value, allowed, label, code)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(code or "fail_settlement", label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then
				fail(code or "fail_settlement",
					label .. " has unexpected field " .. tostring(key))
			end
		end
		for key, requirement in pairs(allowed) do
			if requirement == true and value[key] == nil then
				fail(code or "fail_settlement", label .. " is missing " .. key)
			end
		end
		return value
	end

	local function position(value, label)
		exact_fields(value, {x = true, y = true, z = true}, label, "fail_bounds")
		return integer(value.x, label .. " x", -30912, 30927),
			integer(value.y, label .. " y", -30912, 30927),
			integer(value.z, label .. " z", -30912, 30927)
	end

	local function copy_map(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then fail("fail_ledger", "ledger graph contains a cycle") end
		active[value] = true
		local result = {}
		for key, child in pairs(value) do result[copy_map(key, active)] = copy_map(child, active) end
		active[value] = nil
		return result
	end

	local function canonical_less(left, right)
		local count = math.min(#left, #right)
		for index = 1, count do
			local a, b = string.byte(left, index), string.byte(right, index)
			if a ~= b then return a < b end
		end
		return #left < #right
	end

	local function canonical_scalar(value)
		if type(value) == "string" then
			-- This is a binary graph encoding, not a line format.  R6 ledger
			-- maps deliberately use NUL-delimited composite keys; the decimal
			-- byte length makes every string unambiguous without a byte blacklist.
			return "s" .. tostring(#value) .. ":" .. value
		elseif type(value) == "number" then
			integer(value, "capture scalar", -MAX_SAFE, MAX_SAFE, "fail_ledger")
			return "n" .. string.format("%.0f", value) .. ";"
		elseif type(value) == "boolean" then
			return value and "b1;" or "b0;"
		end
		fail("fail_ledger", "capture scalar type differs")
	end

	local function canonical_graph(value, active)
		if type(value) ~= "table" then return canonical_scalar(value) end
		if getmetatable(value) ~= nil then
			fail("fail_ledger", "capture graph has a metatable")
		end
		active = active or {}
		if active[value] then fail("fail_ledger", "capture graph contains a cycle") end
		active[value] = true
		local count, key_count, is_array = #value, 0, true
		for key in pairs(value) do
			key_count = key_count + 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				is_array = false
			end
		end
		if key_count ~= count then is_array = false end
		local output = {}
		if is_array then
			output[1] = "a" .. tostring(count) .. "["
			for index = 1, count do
				output[#output + 1] = canonical_graph(value[index], active)
			end
			output[#output + 1] = "]"
		else
			local entries = {}
			for key, child in pairs(value) do
				entries[#entries + 1] = canonical_graph(key, active) ..
					canonical_graph(child, active)
			end
			table.sort(entries, canonical_less)
			output[1] = "m" .. tostring(#entries) .. "{"
			for index = 1, #entries do output[#output + 1] = entries[index] end
			output[#output + 1] = "}"
		end
		active[value] = nil
		return table.concat(output)
	end

	local function private_sha256(hash, bytes)
		return hash.hex(hash.sha256_bytes(bytes))
	end

	local function capture_private_buffers(hash, bounds, index_at, buffers,
			run_values, run_count, run_checksum_a, run_checksum_b, ledger)
		local tuple_values, tuple_parts, tuple_rows = {}, {
			"schema\tgrug_wp40_r7_private_tuple_tsv_v1\n",
			"bounds\t" .. bounds.min_x .. "\t" .. bounds.min_y .. "\t" ..
				bounds.min_z .. "\t" .. bounds.max_x .. "\t" .. bounds.max_y ..
				"\t" .. bounds.max_z .. "\n",
			"order\tz_outer_x_middle_y_inner\n",
			"fields\tdata\tparam2\toccupancy\topcode\tfeature\tinterface\taux\n",
		}, {}
		local tuple_count = 0
		for z = bounds.min_z, bounds.max_z do
			for x = bounds.min_x, bounds.max_x do
				for y = bounds.min_y, bounds.max_y do
					local index = index_at(x, y, z)
					local data, param2, occupied, opcode = buffers.data[index],
						buffers.param2[index], buffers.occupancy[index], buffers.opcode[index]
					local feature, interface, aux = buffers.feature[index],
						buffers.interface[index], buffers.aux[index]
					integer(data, "private tuple data", -MAX_SAFE, MAX_SAFE, "fail_ledger")
					integer(param2, "private tuple param2", -MAX_SAFE, MAX_SAFE, "fail_ledger")
					integer(occupied, "private tuple occupancy", -MAX_SAFE, MAX_SAFE,
						"fail_ledger")
					integer(opcode, "private tuple opcode", -MAX_SAFE, MAX_SAFE, "fail_ledger")
					integer(feature, "private tuple feature", -MAX_SAFE, MAX_SAFE,
						"fail_ledger")
					integer(interface, "private tuple interface", -MAX_SAFE, MAX_SAFE,
						"fail_ledger")
					integer(aux, "private tuple aux", -MAX_SAFE, MAX_SAFE, "fail_ledger")
					tuple_count = tuple_count + 1
					local base = (tuple_count - 1) * 7
					tuple_values[base + 1], tuple_values[base + 2] = data, param2
					tuple_values[base + 3], tuple_values[base + 4] = occupied, opcode
					tuple_values[base + 5], tuple_values[base + 6], tuple_values[base + 7] =
						feature, interface, aux
					tuple_rows[#tuple_rows + 1] = string.format(
						"tuple\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\n",
						data, param2, occupied, opcode, feature, interface, aux)
					if #tuple_rows == 4096 then
						tuple_parts[#tuple_parts + 1] = table.concat(tuple_rows)
						tuple_rows = {}
					end
				end
			end
		end
		if #tuple_rows > 0 then tuple_parts[#tuple_parts + 1] = table.concat(tuple_rows) end
		local tuple_bytes = table.concat(tuple_parts)
		local captured_runs = {}
		local run_parts = {
			"schema\tgrug_wp40_r7_private_run_tsv_v1\n",
			"fields\tymin\tymax\tclass\topcode\tkind\tpolicy\tfeature\tinterface\taux\n",
		}
		for run = 1, run_count do
			local base, fields = (run - 1) * RUN_STRIDE, {}
			for field = 1, RUN_STRIDE do
				local value = run_values[base + field]
				integer(value, "private run", -MAX_SAFE, MAX_SAFE, "fail_ledger")
				captured_runs[base + field] = value
				fields[field] = string.format("%.0f", value)
			end
			run_parts[#run_parts + 1] = "run\t" .. table.concat(fields, "\t") .. "\n"
		end
		local run_bytes = table.concat(run_parts)
		local captured_ledger = ledger and copy_map(ledger) or false
		local ledger_bytes = captured_ledger and
			("schema\tgrug_wp40_r7_private_ledger_graph_v1\nledger\t" ..
				canonical_graph(captured_ledger) .. "\n") or
			"schema\tgrug_wp40_r7_private_ledger_graph_v1\nnone\n"
		return {
			schema = "grug_wp40_r7_private_buffer_capture_v1",
			min_x = bounds.min_x, min_y = bounds.min_y, min_z = bounds.min_z,
			max_x = bounds.max_x, max_y = bounds.max_y, max_z = bounds.max_z,
			tuple_order = "z_outer_x_middle_y_inner", tuple_stride = 7,
			tuple_count = tuple_count, tuple_values = tuple_values,
			tuple_sha256 = private_sha256(hash, tuple_bytes),
			run_stride = RUN_STRIDE, run_count = run_count, run_values = captured_runs,
			run_checksum_a = run_checksum_a, run_checksum_b = run_checksum_b,
			run_sha256 = private_sha256(hash, run_bytes),
			ledger = captured_ledger,
			ledger_sha256 = private_sha256(hash, ledger_bytes),
			metrics = {schema = "grug_wp40_r7_private_buffer_capture_metrics_v1",
				tuple_count = tuple_count, tuple_scalar_count = #tuple_values,
				tuple_encoded_bytes = #tuple_bytes, run_count = run_count,
				run_scalar_count = #captured_runs, run_encoded_bytes = #run_bytes,
				run_checksum_a = run_checksum_a, run_checksum_b = run_checksum_b,
				ledger_encoded_bytes = #ledger_bytes},
		}
	end

	local function equal_graph(left, right, active)
		if type(left) ~= type(right) then return false end
		if type(left) ~= "table" then return left == right end
		active = active or {}
		if active[left] == right then return true end
		active[left] = right
		for key, value in pairs(left) do
			if not equal_graph(value, right[key], active) then return false end
		end
		for key in pairs(right) do if left[key] == nil then return false end end
		return true
	end

	local function sift_down(values, root, finish, less)
		while root * 2 <= finish do
			local child = root * 2
			if child < finish and less(values[child], values[child + 1]) then
				child = child + 1
			end
			if not less(values[root], values[child]) then return end
			values[root], values[child] = values[child], values[root]
			root = child
		end
	end

	local function sort_prefix(values, count, less)
		for root = math.floor(count / 2), 1, -1 do
			sift_down(values, root, count, less)
		end
		for finish = count, 2, -1 do
			values[1], values[finish] = values[finish], values[1]
			sift_down(values, 1, finish - 1, less)
		end
	end

	local function new(dependencies, evidence_only, capture_enabled)
		if evidence_only ~= nil and evidence_only ~= true then
			fail("fail_settlement", "evidence-only construction flag differs")
		end
		if capture_enabled ~= nil and capture_enabled ~= true then
			fail("fail_settlement", "capture construction flag differs")
		end
		if evidence_only and capture_enabled then
			fail("fail_settlement", "evidence construction modes overlap")
		end
		exact_fields(dependencies, {
			full_seed_string = true, r5_adapter = true, content = true,
			templates = true, hash = true, horizontal = true, planner_source = true,
			construction_identity = true, cultural_registrations = true, source = true,
			counting_allocator = true, successor_tail = "optional",
			planner_stable_refs = "optional",
		}, "settlement dependencies", "fail_settlement")
		local full_seed = dependencies.full_seed_string
		local r5_adapter = dependencies.r5_adapter
		local content = dependencies.content
		local templates = dependencies.templates
		local hash = dependencies.hash
		local horizontal = dependencies.horizontal
		local planner_source = dependencies.planner_source
		local cultural_registrations = dependencies.cultural_registrations
		local source = dependencies.source
		local allocator = dependencies.counting_allocator
		local successor_tail = dependencies.successor_tail
		local planner_stable_refs = dependencies.planner_stable_refs
		if type(full_seed) ~= "string" or full_seed == "" or
				type(r5_adapter) ~= "table" or type(r5_adapter.apply) ~= "function" or
				type(content) ~= "table" or type(templates) ~= "table" or
				type(hash) ~= "table" or type(horizontal) ~= "table" or
				type(planner_source) ~= "table" or type(source) ~= "table" or
				(successor_tail ~= nil and (type(successor_tail) ~= "table" or
					type(successor_tail.settle) ~= "function")) then
			fail("fail_settlement", "construction seams differ")
		end
		exact_fields(allocator, {new_array = true, new_map = true, grow = true,
			map_put = true, seal_construction = true, enter_hotpath = true,
			leave_hotpath = true, metrics = true}, "settlement counting allocator",
			"fail_settlement")
		for name, method in pairs(allocator) do
			if type(method) ~= "function" then
				fail("fail_settlement", "settlement allocator method differs: " .. name)
			end
		end
		local function retained_array(label, size, value)
			local result = allocator:new_array(label, size)
			allocator:grow(result, label, 0, size)
			if value ~= 0 then
				for index = 1, size do result[index] = value end
			end
			return result
		end
		local contract = content.content_contract()
		local ordinary_water_cid, ordinary_water_kind, ordinary_water_param2 =
			contract.r5.resolve(10, 0, 0)
		local river_water_cid, river_water_kind, river_water_param2 =
			contract.r5.resolve(13, 0, 0)
		if ordinary_water_kind ~= 2 or river_water_kind ~= 2 or
				ordinary_water_param2 ~= 0 or river_water_param2 ~= 0 then
			fail("fail_content_manifest", "prospective water targets differ")
		end
		local surfaces = content.surfaces()
		local resources = content.resources()
		local cultural = content.cultural()
		local decorations = content.decorations()
		local projection = content.wp43_projection()
		local surface_by_id = {}
		for index = 1, #surfaces do surface_by_id[surfaces[index].id] = surfaces[index] end
		local race_assignment = {}
		for index = 1, #(projection.race_regions or {}) do
			local row = projection.race_regions[index]
			local race = row.race or row._projection_key
			if race then race_assignment[race] = row end
		end
		local tier_by_y = projection.tiers
		local cultural_registration = {}
		for index = 1, #cultural_registrations do
			cultural_registration[cultural_registrations[index].cultural_key] =
				cultural_registrations[index]
		end
		local evidence_stable_ref = {}
		if planner_stable_refs ~= nil then
			if type(planner_stable_refs) ~= "table" or #planner_stable_refs < 1 then
				fail("fail_settlement", "planner stable refs differ")
			end
			for index = 1, #planner_stable_refs do
				local id = planner_stable_refs[index]
				if type(id) ~= "string" or id == "" or evidence_stable_ref[id] or
						(index > 1 and not hash.less_bytes(planner_stable_refs[index - 1], id)) then
					fail("fail_settlement", "planner stable refs differ")
				end
				evidence_stable_ref[id] = index
			end
		end
		local exclusion_reason_by_id = {}
		for index = 1, #(source.claim_exclusions or {}) do
			local row = source.claim_exclusions[index]
			local reason = (row.recipe_id == "exclude_route_corridor_v1" or
				row.recipe_id == "exclude_planned_water_v1" or
				row.recipe_id == "exclude_coast_v1") and "route_or_water" or
				"fixed_or_protected"
			exclusion_reason_by_id[row.id] = reason
		end
		local function exclusion_reason(x, z)
			local _, id = horizontal.static_exclusion_values_at(x, z)
			if not id then return nil end
			local reason = exclusion_reason_by_id[id]
			if not reason then fail("fail_settlement", "exclusion identity differs") end
			if reason == "route_or_water" and
					select(20, planner_source.column_values_at(x, z)) then
				return "fixed_or_protected"
			end
			return reason
		end
		local function housing_excluded_at(x, z)
			return type(horizontal.housing_mask_id_at) == "function" and
				horizontal.housing_mask_id_at(x, z) ~= nil
		end
		local apex_columns = {}
		do
			local anchors = {}
			for index = 1, #(source.anchors or {}) do
				anchors[source.anchors[index].id] = source.anchors[index]
			end
			for index = 1, #(source.apex_sockets or {}) do
				local socket = source.apex_sockets[index]
				local anchor = anchors[socket.anchor_id]
				if not anchor then fail("fail_settlement", "apex anchor identity differs") end
				local key = tostring(anchor.position.x + socket.offset.x) .. "/" ..
					tostring(anchor.position.z + socket.offset.z)
				if apex_columns[key] then
					fail("fail_settlement", "duplicate apex socket column")
				end
				apex_columns[key] = socket.id
			end
			if #(source.apex_sockets or {}) ~= 24 then
				fail("fail_settlement", "apex socket population differs")
			end
		end
		local function overlaps_apex(x, y, z)
			return y >= -700 and apex_columns[tostring(x) .. "/" .. tostring(z)] ~= nil
		end
		local route_by_id, hard_ingresses = {}, {}
		for index = 1, #(source.routes or {}) do
			route_by_id[source.routes[index].id] = source.routes[index]
		end
		for index = 1, #(source.hard_protection or {}) do
			local row = source.hard_protection[index]
			if row.recipe_id == "hard_capital_ingress_corridor_v1" then
				hard_ingresses[#hard_ingresses + 1] = row
			end
		end
		local function segment_corridor_member(x, z, a, b, total_width)
			local half_floor = math.floor(total_width / 2)
			if x < math.min(a.x, b.x) - half_floor - 1 or
					x > math.max(a.x, b.x) + half_floor + 1 or
					z < math.min(a.z, b.z) - half_floor - 1 or
					z > math.max(a.z, b.z) + half_floor + 1 then return false end
			local vx, vz = b.x - a.x, b.z - a.z
			local wx, wz = x - a.x, z - a.z
			local length_squared = vx * vx + vz * vz
			local numerator, denominator
			local dot = wx * vx + wz * vz
			if dot <= 0 then
				numerator, denominator = wx * wx + wz * wz, 1
			elseif dot >= length_squared then
				local dx, dz = x - b.x, z - b.z
				numerator, denominator = dx * dx + dz * dz, 1
			else
				local cross = wx * vz - wz * vx
				numerator, denominator = cross * cross, length_squared
			end
			return 4 * numerator <= total_width * total_width * denominator
		end
		local function in_hard_ingress(x, z)
			for hard_index = 1, #hard_ingresses do
				local hard = hard_ingresses[hard_index]
				for route_index = 1, #hard.route_ids do
					local route = route_by_id[hard.route_ids[route_index]]
					if not route then fail("fail_settlement", "hard ingress route differs") end
					for point = 1, #route.centreline - 1 do
						if segment_corridor_member(x, z, route.centreline[point],
								route.centreline[point + 1], 128) then return true end
					end
				end
			end
			return false
		end
		local hydrology_profile_depth, hydrology_depth, lower_hydrology = {}, {}, {}
		for index = 1, #(source.hydrology_profiles or {}) do
			local row = source.hydrology_profiles[index]
			hydrology_profile_depth[row.id] = row.depth
		end
		for index = 1, #(source.hydrology or {}) do
			local row = source.hydrology[index]
			hydrology_depth[row.id] = hydrology_profile_depth[row.profile_id]
		end
		for index = 1, #(source.hydrology_interfaces or {}) do
			local row = source.hydrology_interfaces[index]
			if row.kind == "waterfall" then lower_hydrology[row.id] = row.lower_id end
		end

		local retained_volume = evidence_only and 1 or MAX_VOLUME
		local original_data = retained_array("r6_settlement_original_data",
			retained_volume, 0)
		local original_param2 = retained_array("r6_settlement_original_param2",
			retained_volume, 0)
		local final_data = retained_array("r6_settlement_final_data", retained_volume, 0)
		local final_param2 = retained_array("r6_settlement_final_param2",
			retained_volume, 0)
		local original_light = retained_array("r6_settlement_original_light",
			retained_volume, 0)
		local final_light = retained_array("r6_settlement_final_light", retained_volume, 0)
		local occupancy = retained_array("r6_settlement_occupancy", retained_volume, 0)
		local intent_opcode = retained_array("r6_settlement_intent_opcode",
			retained_volume, 0)
		local intent_feature = retained_array("r6_settlement_intent_feature",
			retained_volume, 0)
		local intent_interface = retained_array("r6_settlement_intent_interface",
			retained_volume, 0)
		local intent_aux = retained_array("r6_settlement_intent_aux", retained_volume, 0)
		local coordinate_scratch = {}
		for index = 1, 4096 do
			coordinate_scratch[index] = {x = 0, y = 0, z = 0, digest = false}
		end
		local frontier_scratch = {}
		for index = 1, 48 do
			frontier_scratch[index] = {x = 0, y = 0, z = 0, digest = false}
		end
		local light_seed_start = retained_array("r6_settlement_light_seed_start",
			evidence_only and 1 or 8192, 0)
		local light_seed_finish = retained_array("r6_settlement_light_seed_finish",
			evidence_only and 1 or 8192, 0)
		local light_seed_z = retained_array("r6_settlement_light_seed_z",
			evidence_only and 1 or 8192, 0)
		local light_zero, light_full = {day = 0, night = 0}, {day = 15, night = 0}
		local call_min, call_max = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
		local transaction_state = {
			final_light = final_light,
			seed_start = light_seed_start, seed_finish = light_seed_finish,
			seed_z = light_seed_z, light_zero = light_zero, light_full = light_full,
			call_min = call_min, call_max = call_max,
			successor_tail = successor_tail,
		}
		if capture_enabled then
			transaction_state.private_capture = {armed = false, value = false}
		end
		local run_values = retained_array("r6_settlement_run_values",
			evidence_only and 1 or MAX_RUNS * RUN_STRIDE, 0)
		local census_occupancy = retained_array("r6_settlement_census_occupancy", 4096, 0)
		local census_column_allowed = retained_array(
			"r6_settlement_census_column_allowed", 256, false)
		local stable_state = {
			resource = retained_array("r6_settlement_stable_resource", #resources, 0),
			cultural = retained_array("r6_settlement_stable_cultural", #cultural, 0),
			decoration = retained_array("r6_settlement_stable_decoration", #decorations, 0),
			bound = false,
		}
		local metrics_state = {
			apply_calls = 0, peak_successor_runs = 0,
			modified_voxels = 0, content_dirty_columns = 0,
			param2_dirty_columns = 0, light_dirty_columns = 0,
			liquid_dirty_columns = 0, replay_count = 0,
		}
		local last_ledger, last_run_count, last_light_seed_runs = false, 0, 0

		local function classify(cid, param2, code)
			local ok, class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source =
				pcall(contract.classify, cid, param2)
			if not ok or type(class_id) ~= "number" or class_id < 1 or class_id > 11 or
				type(family_id) ~= "number" or type(liquid_kind) ~= "number" or
				type(liquid_level) ~= "number" or type(floodable) ~= "boolean" or
				type(paramtype_light) ~= "boolean" or
				type(light_propagates) ~= "boolean" or
				type(sunlight_propagates) ~= "boolean" or
				type(light_source) ~= "number" then
				fail(code or "fail_settlement", "content classification differs")
			end
			return class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source
		end

		local function resolve(content_ref, param2, role_bit)
			integer(content_ref, "content ref", 1, #contract.content_names,
				"fail_content_manifest")
			integer(param2, "content param2", 0, 255, "fail_content_manifest")
			local ok, cid, kind, mode, value, mask = pcall(contract.resolve_r6,
				content_ref, param2)
			if not ok or type(cid) ~= "number" or kind ~= 1 or mode ~= 1 or
					value ~= param2 or mask ~= contract.content_kind_masks[content_ref] or
					math.floor(mask / role_bit) % 2 ~= 1 or cid == contract.ignore_cid then
				fail("fail_content_manifest", "content target differs")
			end
			return cid, value
		end

		local function tier_at(y)
			for index = 1, #tier_by_y do
				if y >= tier_by_y[index].y_min then return index, tier_by_y[index].node end
			end
			return #tier_by_y, tier_by_y[#tier_by_y].node
		end

		local function deep_band(y)
			if y >= -1499 then return "ordinary", 1, 1 end
			if y >= -1999 then return "deep_1500_1999", 5, 4 end
			return "deep_2000_floor", 3, 2
		end

		local function analytic_hydrology_seal(x, z)
			local _, _, _, _, _, terrain_y, water_y, classified_id,
				classified_depth, _, _, _, _, transition_kind, transition_id,
				_, transition_lower_y, _, transition_face_mask =
					planner_source.column_values_at(x, z)
			local wet_surface, wet_depth
			if transition_kind == "waterfall" and transition_face_mask ~= nil then
				wet_surface = transition_lower_y
				wet_depth = hydrology_depth[lower_hydrology[transition_id]]
			elseif classified_id ~= nil and water_y ~= nil and
					transition_kind ~= "waterfall" then
				wet_surface, wet_depth = water_y, classified_depth
			end
			if wet_surface and wet_depth then
				local bed = wet_surface - wet_depth
				return bed - 2, bed
			end
			local minimum_seal_y, maximum_water_y
			for dx = -2, 2 do
				for dz = -2, 2 do
					local distance = math.abs(dx) + math.abs(dz)
					if distance >= 1 and distance <= 2 then
						local _, _, _, _, _, _, neighbor_water, neighbor_classified,
							neighbor_depth, _, _, _, _, neighbor_transition,
							neighbor_transition_id, _, neighbor_lower_y, _, neighbor_face =
								planner_source.column_values_at(x + dx, z + dz)
						local neighbor_surface, depth
						if neighbor_transition == "waterfall" and neighbor_face ~= nil then
							neighbor_surface = neighbor_lower_y
							depth = hydrology_depth[lower_hydrology[neighbor_transition_id]]
						elseif neighbor_water ~= nil and neighbor_classified ~= nil and
								neighbor_transition ~= "waterfall" then
							neighbor_surface, depth = neighbor_water, neighbor_depth
						end
						if neighbor_surface and depth and depth > 0 then
							local seal_y = neighbor_surface - depth - 2
							minimum_seal_y = minimum_seal_y and
								math.min(minimum_seal_y, seal_y) or seal_y
							maximum_water_y = maximum_water_y and
								math.max(maximum_water_y, neighbor_surface) or neighbor_surface
						end
					end
				end
			end
			if minimum_seal_y then
				return minimum_seal_y, math.min(terrain_y, maximum_water_y)
			end
			return nil, nil
		end

		local function analytic_p7_material_ref(x, y, z)
			local _, _, zone_id, biome, _, terrain_y, water_y, classified_id,
				classified_depth,
				functional_kind, functional_y, _, _, transition_kind, transition_id,
				_, transition_lower_y, _, transition_face_mask =
					planner_source.column_values_at(x, z)
			local surface = surface_by_id[biome]
			if not zone_id or not surface or y < terrain_y - surface.filler_depth or
					y > terrain_y or y < -37 then return nil end
			if functional_kind == "anchor_platform" or
					functional_kind == "land_grade" or functional_kind == "causeway" or
					(functional_kind == "ford" and y == terrain_y) or
					(functional_kind == "tunnel_floor" and functional_y <= y and
						y <= functional_y + 5) then
				return nil
			end
			local seal_min, seal_max = analytic_hydrology_seal(x, z)
			if seal_min and seal_min <= y and y <= seal_max then return nil end
			if y < terrain_y then return surface.filler_ref end
			local wet = water_y ~= nil and water_y > terrain_y
			local name = wet and surface.bed or
				(biome == "grug_beach" and surface.shore or surface.top)
			return content.content_ref(name)
		end

		local function r5_target_cid(role, y)
			local ok, cid, target_kind, param2_mode, param2_value =
				pcall(contract.r5.resolve, role, y, 0)
			if not ok or type(cid) ~= "number" or cid % 1 ~= 0 or cid < 0 or
					type(target_kind) ~= "number" or target_kind < 0 or target_kind > 2 or
					(param2_mode ~= 0 and param2_mode ~= 1) or
					(param2_mode == 0 and param2_value ~= nil) or
					(param2_mode == 1 and (type(param2_value) ~= "number" or
						param2_value % 1 ~= 0 or param2_value < 0 or param2_value > 255)) then
				fail("fail_content_manifest", "analytic R5 target differs")
			end
			return cid
		end

		-- Exact single-voxel replay of the frozen R5 P2-P6 winner over its
		-- deterministic P5/P6 base. This is the horizontal evidence authority for
		-- decoration predecessors and shares production resolvers/source scalars.
		local function analytic_r5_material_cid(x, y, z)
			local _, _, _, _, _, terrain_y, water_y, classified_id, classified_depth,
				functional_kind, functional_y, _, _, transition_kind, transition_id,
				transition_upper_y, transition_lower_y, _, transition_face_mask,
				hard_foundation = planner_source.column_values_at(x, z)
			local clearance_y = water_y
			if clearance_y == nil and transition_upper_y ~= nil then
				clearance_y = math.max(transition_upper_y, transition_lower_y)
			end
			local surface_cap = clearance_y and math.max(terrain_y, clearance_y) or
				terrain_y
			local winner_priority, winner_role, winner_policy
			local function offer(priority, role, policy)
				if winner_priority == nil or priority < winner_priority then
					winner_priority, winner_role, winner_policy = priority, role, policy
				end
			end
			local function within(low, high)
				return low ~= nil and high ~= nil and low <= high and y >= low and y <= high
			end

			if hard_foundation and functional_kind == "anchor_platform" then
				if within(-37, terrain_y - 1) then offer(2, 7, 3)
				elseif y == terrain_y then offer(2, 8, 6)
				elseif within(terrain_y + 1, terrain_y + 4) then offer(2, 1, 1) end
			elseif functional_kind == "anchor_platform" or
					functional_kind == "land_grade" then
				if within(-37, terrain_y - 1) then offer(4, 11, 3)
				elseif y == terrain_y then offer(4, 12, 6)
				elseif within(terrain_y + 1, terrain_y + 4) then offer(4, 1, 1) end
			elseif functional_kind == "ford" then
				if y == terrain_y then offer(3, 6, 6) end
			elseif functional_kind == "bridge_deck" then
				if within(math.max(terrain_y + 1, clearance_y + 1),
						functional_y - 2) then offer(3, 1, 4)
				elseif y == functional_y - 1 then offer(3, 3, 5)
				elseif y == functional_y then offer(3, 2, 6)
				elseif within(functional_y + 1, functional_y + 4) then offer(3, 1, 1) end
			elseif functional_kind == "causeway" then
				local culvert = false
				if classified_id ~= nil and water_y ~= nil and
						type(planner_source.hydrology_metric_values_at) == "function" then
					local metric_id, _, numerator, denominator =
						planner_source.hydrology_metric_values_at(x, z)
					culvert = metric_id == classified_id and numerator <= denominator
				end
				local culvert_bed = culvert and water_y - classified_depth or nil
				local fill_low = culvert and water_y + 1 or -37
				if within(fill_low, terrain_y - 1) then offer(3, 4, 3)
				elseif y == terrain_y then offer(3, 5, 6)
				elseif culvert and within(culvert_bed + 1, water_y) then offer(3, 13, 7)
				elseif within(terrain_y + 1, terrain_y + 4) then offer(4, 1, 1) end
			elseif functional_kind == "tunnel_floor" then
				if y == functional_y then offer(3, 15, 6)
				elseif within(functional_y + 1, functional_y + 4) then offer(3, 1, 4)
				elseif y == functional_y + 5 then offer(3, 16, 5) end
			end

			if y <= terrain_y then
				local seal_min, seal_max = analytic_hydrology_seal(x, z)
				if within(seal_min, seal_max) then offer(3, 9, 5) end
			end
			if transition_kind == "waterfall" and transition_face_mask ~= nil then
				local lower_depth = hydrology_depth[lower_hydrology[transition_id]]
				local lower_bed = transition_lower_y - lower_depth
				if within(lower_bed + 1, transition_lower_y - 1) then offer(6, 13, 7)
				elseif y == transition_lower_y then offer(6, 1, 4)
				elseif y >= transition_lower_y + 1 then offer(3, 1, 4) end
			elseif water_y ~= nil and terrain_y < water_y and
					within(terrain_y + 1, water_y) then
				offer(6, classified_id and 13 or 10, 7)
			end
			if within(-37, terrain_y - 1) or y == terrain_y then offer(5, 14, 6)
			elseif y > surface_cap then offer(5, 1, 1) end
			if not winner_role then winner_priority, winner_role, winner_policy = 5, 1, 1 end

			local target_cid = r5_target_cid(winner_role, y)
			if winner_priority >= 5 then return target_cid, winner_priority end
			local base_role
			if y <= terrain_y then base_role = 14
			elseif transition_kind == "waterfall" and transition_face_mask ~= nil then
				local lower_depth = hydrology_depth[lower_hydrology[transition_id]]
				base_role = y < transition_lower_y and
					y > transition_lower_y - lower_depth and 13 or 1
			elseif water_y ~= nil and y <= water_y then
				base_role = classified_id and 13 or 10
			else base_role = 1 end
			local old_cid = r5_target_cid(base_role, y)
			if old_cid == target_cid then return old_cid, winner_priority end
			local old_class = classify(old_cid, 0, "fail_old_class")
			local writes = winner_policy == 6 or winner_policy == 7 or
				((winner_policy == 1 or winner_policy == 4) and old_class ~= CLASS_AIR) or
				((winner_policy == 3 or winner_policy == 5) and
					(old_class == CLASS_AIR or old_class == CLASS_LIQUID or
						old_class == CLASS_NATURAL_VEGETATION))
			return writes and target_cid or old_cid, winner_priority
		end

		local function analytic_p7_support_ref(x, y, z)
			local _, _, _, _, _, terrain_y = planner_source.column_values_at(x, z)
			if y ~= terrain_y then return nil end
			return analytic_p7_material_ref(x, y, z)
		end

		local function regional_allowed(resource, race)
			if resource.scope == "universal" then return true end
			local assignment = race_assignment[race]
			if not assignment then return false end
			if resource.scope == "regional_g1" then
				return assignment.g1 == resource.key
			end
			return assignment.g2 == resource.key
		end

		local function coordinate_less(left, right)
			if left.digest ~= right.digest then
				return hash.less_bytes(left.digest, right.digest)
			end
			if left.z ~= right.z then return left.z < right.z end
			if left.x ~= right.x then return left.x < right.x end
			return left.y < right.y
		end

		local function owner_minimum(value)
			return -30912 + math.floor((value + 30912) / 80) * 80
		end

		local function occupied_key(x, y, z)
			return tostring(x) .. "/" .. tostring(y) .. "/" .. tostring(z)
		end

		local function run_class_policy(opcode)
			local class_id = opcode == 35 and 10 or (opcode == 24 and 8 or
				((opcode == 12 or opcode == 34) and 9 or 7))
			local policy = opcode == 35 and 11 or (opcode == 2 and 10 or
				(opcode == 34 and 9 or ((opcode == 12 or opcode == 33) and 8 or
					(opcode == 24 and 2 or 6))))
			return class_id, policy
		end

		local function evidence_run_rows(rows)
			local result, index = {}, 1
			while index <= #rows do
				local first = rows[index]
				if first[7] == 0 then
					index = index + 1
				else
					local finish = index
					while finish + 1 <= #rows do
						local next_row = rows[finish + 1]
						if next_row[1] ~= first[1] or next_row[3] ~= first[3] or
								next_row[2] ~= rows[finish][2] + 1 or
								next_row[7] ~= first[7] or next_row[8] ~= first[8] or
								next_row[9] ~= first[9] or next_row[10] ~= first[10] then
							break
						end
						finish = finish + 1
					end
					local class_id, policy = run_class_policy(first[7])
					result[#result + 1] = {first[1], first[3], first[2],
						rows[finish][2], class_id, first[7], 17, policy,
						first[8], first[9], first[10]}
					index = finish + 1
				end
			end
			return result
		end

		local function primary_reason(flags, ordered)
			for index = 1, #ordered do
				if flags[ordered[index]] then return ordered[index] end
			end
			return nil
		end

		-- Production-owned canonical horizontal evidence fixture.  It shares the
		-- exact catalog, exclusion, hash, template and accepted-P7 authorities of
		-- the writer, while replacing the native VM with Section 11.2's closed
		-- stratum/surface/air population.  Only aggregate ledgers escape.
		local function scan_horizontal_owner(owner_x, owner_z,
				cultural_candidates, decoration_candidates)
			integer(owner_x, "evidence owner x", -30912, 30927, "fail_ledger")
			integer(owner_z, "evidence owner z", -30912, 30927, "fail_ledger")
			local result = {cultural = {}, decorations = {}, rejections = {},
				witnesses = {}, apex_overlaps = 0}
			local occupied, occupied_positions, written = {}, {}, {}
			local evidence_air_cid, air_kind, air_param2 =
				contract.r5.resolve(1, 0, 0)
			if air_kind ~= 0 or air_param2 ~= 0 or
					evidence_air_cid == contract.ignore_cid then
				fail("fail_content_manifest", "evidence air authority differs")
			end
			if successor_tail and next(evidence_stable_ref) == nil then
				fail("fail_ledger", "successor evidence stable refs are absent")
			end
			local function evidence_write(x, y, z, content_ref, param2, opcode,
					feature, interface, occupancy_value)
				local cid = contract.content_cids[content_ref]
				local key = occupied_key(x, y, z)
				occupied_positions[key] = {x, y, z}
				written[key] = {x, y, z, cid, param2,
					occupancy_value, opcode, feature, interface,
					(content_ref - 1) * 256 + param2}
			end
			local function evidence_rows(base_tuple)
				local rows = {}
				for key, position in pairs(occupied_positions) do
					local row = written[key]
					if row then
						rows[#rows + 1] = copy_map(row)
					else
						local _, cid, _, opcode, aux = base_tuple(position[1],
							position[2], position[3])
						rows[#rows + 1] = {position[1], position[2], position[3],
							cid, 0, occupied[key], opcode, 0, 0, aux}
					end
				end
				table.sort(rows, function(left, right)
					if left[3] ~= right[3] then return left[3] < right[3] end
					if left[1] ~= right[1] then return left[1] < right[1] end
					return left[2] < right[2]
				end)
				return rows
			end
			local function inside(x, y, z, oy)
				return x >= owner_x and x <= owner_x + 79 and y >= oy and
					y <= oy + 79 and z >= owner_z and z <= owner_z + 79 and
					x >= -3740 and x <= 3740 and z >= -3340 and z <= 3340 and
					y >= -31000 and y <= 31000
			end
			local function reject(subsystem, id, reason)
				local key = subsystem .. "\0" .. id .. "\0" .. reason
				result.rejections[key] = (result.rejections[key] or 0) + 1
			end
			for candidate_index = 1, #cultural_candidates do
				local candidate = cultural_candidates[candidate_index]
				local row = cultural[candidate.catalog]
				local rate = candidate.denominator == 1024 and "concentrated" or "ordinary"
				local aggregate_key = row.key .. "\0" .. rate
				local aggregate = result.cultural[aggregate_key]
				if not aggregate then
					aggregate = {accepted = 0, reserved = 0}
					result.cultural[aggregate_key] = aggregate
				end
				local oy = owner_minimum(candidate.y)
				local flags = {}
				for z = candidate.z - 2, candidate.z + 2 do
					for y = candidate.y - 1, candidate.y + 7 do
						for x = candidate.x - 2, candidate.x + 2 do
							if not inside(x, y, z, oy) then flags.clipped_owner = true
							else
								local excluded = exclusion_reason(x, z)
								if excluded then flags[excluded] = true end
								if occupied[occupied_key(x, y, z)] == 1 then
									flags.cultural_collision = true
								end
							end
						end
					end
				end
				if not analytic_p7_support_ref(candidate.x, candidate.y, candidate.z) then
					flags.wrong_support = true
				end
				local reason = primary_reason(flags, {"clipped_owner",
					"fixed_or_protected", "route_or_water", "content_ignore",
					"wrong_support", "cultural_collision"})
				if reason then reject("cultural", row.key, reason)
				else
					aggregate.accepted = aggregate.accepted + 1
					aggregate.reserved = aggregate.reserved + 225
					if not result.witnesses[aggregate_key] then
						local _, _, zone_id = planner_source.column_values_at(candidate.x,
							candidate.z)
						result.witnesses[aggregate_key] = {zone_id = zone_id,
							x = candidate.x, y = candidate.y, z = candidate.z}
					end
					for z = candidate.z - 2, candidate.z + 2 do
						for y = candidate.y - 1, candidate.y + 7 do
							for x = candidate.x - 2, candidate.x + 2 do
								if overlaps_apex(x, y, z) then
									result.apex_overlaps = result.apex_overlaps + 1
								end
								local key = occupied_key(x, y, z)
								occupied[key] = 1
								occupied_positions[key] = {x, y, z}
							end
						end
					end
					local registration = cultural_registration[row.key]
					if registration then
						local feature = evidence_stable_ref[row.key]
						if not feature then fail("fail_ledger", "cultural stable ref differs") end
						for part = 1, #registration.cells do
							local cell = registration.cells[part]
							local x, y, z = candidate.x + cell.x,
								candidate.y + cell.y, candidate.z + cell.z
							local lower = cell.y == -1 or cell.y == 0
							local exact_p7 = analytic_p7_material_ref(x, y, z) ~= nil
							if not (lower and exact_p7 and
									registration.lower_two_policy == "preserve_p7") then
								evidence_write(x, y, z, cell.content_ref, cell.param2, 34,
									feature, registration.template_or_simple_kind == "template" and
										feature or 0, 1)
							end
						end
					end
				end
			end

			local function prospective(x, y, z)
				local _, _, _, biome, _, terrain_y, water_y =
					planner_source.column_values_at(x, z)
				local surface = surface_by_id[biome]
				if not surface then return CLASS_UNKNOWN, 0, false, 0, 0 end
				local p7_ref = analytic_p7_material_ref(x, y, z)
				if p7_ref then
					local cid = contract.content_cids[p7_ref]
					local wet = water_y ~= nil and water_y > terrain_y
					local opcode = y < terrain_y and 2 or (wet and 1 or
						(biome == "grug_beach" and 3 or 4))
					return classify(cid, 0, "fail_old_class"), cid, true, opcode,
						(p7_ref - 1) * 256
				end
				local wet = water_y ~= nil and water_y > terrain_y
				local cid, r5_priority = analytic_r5_material_cid(x, y, z)
				if y > terrain_y then
					if surface.dust_ref ~= 0 and not wet and y == terrain_y + 1 and
							r5_priority == 5 and cid == r5_target_cid(1, y) and
							analytic_p7_material_ref(x, terrain_y, z) ~= nil then
						return CLASS_NATURAL_VEGETATION,
							contract.content_cids[surface.dust_ref], false, 33,
							(surface.dust_ref - 1) * 256
					end
				end
				return classify(cid, 0, "fail_old_class"), cid, false, 0, 0
			end

			for class = 1, 4 do
				for candidate_index = 1, #decoration_candidates do
					local candidate = decoration_candidates[candidate_index]
					local row = decorations[candidate.catalog]
					if row.settlement_class == class then
						local cells, min_fx, max_fx, min_fy, max_fy, min_fz, max_fz =
							{}, 0, 0, 0, 0, 0, 0
						local feature_ref = evidence_stable_ref[row.id]
						if not feature_ref then
							fail("fail_ledger", "decoration stable ref differs")
						end
						local interface_ref = 0
						if row.kind == "template" then
							interface_ref = feature_ref
							local rotation_digest = hash.digest("decoration_rotation_v1",
								full_seed, {row.id, candidate.x, candidate.y, candidate.z})
							local rotation = math.floor(string.byte(rotation_digest, 1) / 64)
							local template = templates.rotation(row.id, rotation)
							min_fx, max_fx, min_fy, max_fy, min_fz, max_fz = template.min_x,
								template.max_x, template.min_y, template.max_y,
								template.min_z, template.max_z
							for z = 1, template.size_z do
								for y = 1, template.size_y do
									local slice_ok = templates.probability_include(full_seed,
										row.id, candidate.x, candidate.y, candidate.z, rotation,
										"slice", 0, y - 1, 0,
										template.y_slice_probabilities[y])
									for x = 1, template.size_x do
										local source_index = (z - 1) * template.size_x *
											template.size_y + (y - 1) * template.size_x + x
										local node = template.cells[source_index]
										cells[#cells + 1] = {x = template.min_x + x - 1,
											y = template.min_y + y - 1,
											z = template.min_z + z - 1,
											include = slice_ok and node.name ~= "air" and
												templates.probability_include(full_seed, row.id,
													candidate.x, candidate.y, candidate.z, rotation,
													"node", x - 1, y - 1, z - 1, node.probability),
											content_ref = node.content_ref, param2 = node.param2,
											force_place = node.force_place}
									end
								end
							end
						else
							local height = 1
							if row.settlement_class == 3 then
								local digest = hash.digest("decoration_simple_height_v1",
									full_seed, {row.id, candidate.x, candidate.y, candidate.z})
								height = 2 + string.byte(digest, 1) % 3
							end
							max_fy = height - 1
							for y = 0, height - 1 do
								cells[#cells + 1] = {x = 0, y = y, z = 0, include = true,
									content_ref = row.content_ref,
									param2 = row.rule == "param2_4" and 4 or 0,
									force_place = false}
							end
						end
						local oy = owner_minimum(candidate.y)
						local flags = {}
						if not inside(candidate.x + min_fx, candidate.y + min_fy,
								candidate.z + min_fz, oy) or
								not inside(candidate.x + max_fx, candidate.y + max_fy,
									candidate.z + max_fz, oy) then flags.clipped_owner = true end
						local support_ref = analytic_p7_support_ref(candidate.x,
							candidate.y - 1, candidate.z)
						if support_ref ~= content.content_ref(row.host) then
							flags.wrong_host = true
						end
						if not flags.clipped_owner then
							for z = candidate.z + min_fz, candidate.z + max_fz do
								for y = candidate.y + min_fy, candidate.y + max_fy do
									for x = candidate.x + min_fx, candidate.x + max_fx do
										local excluded = exclusion_reason(x, z)
										if excluded then flags[excluded] = true end
										local occupant = occupied[occupied_key(x, y, z)]
										if occupant == 1 then flags.cultural_collision = true
										elseif occupant == -1 then flags.decoration_collision = true end
									end
								end
							end
							for part = 1, #cells do
								local cell = cells[part]
								if cell.include then
									local old_class, old_cid, exact_p7 = prospective(
										candidate.x + cell.x,
										candidate.y + cell.y, candidate.z + cell.z)
									local target = contract.content_cids[cell.content_ref]
									if old_cid ~= target and old_class ~= CLASS_AIR and
											old_class ~= CLASS_NATURAL_VEGETATION then
										if cell.force_place then
											if not exact_p7 then flags.forbidden_old_class = true end
										else
											flags.insufficient_clearance = true
										end
									end
								end
							end
						end
						local reason = primary_reason(flags, {"clipped_owner",
							"content_ignore", "fixed_or_protected", "route_or_water",
							"wrong_host", "insufficient_clearance", "cultural_collision",
							"resource_collision", "decoration_collision",
							"forbidden_old_class"})
						local aggregate = result.decorations[row.id]
						if not aggregate then
							aggregate = {accepted = 0, emitted = 0, reserved = 0}
							result.decorations[row.id] = aggregate
						end
						if reason then reject("decoration", row.id, reason)
						else
							aggregate.accepted = aggregate.accepted + 1
							for z = candidate.z + min_fz, candidate.z + max_fz do
								for y = candidate.y + min_fy, candidate.y + max_fy do
									for x = candidate.x + min_fx, candidate.x + max_fx do
										if overlaps_apex(x, y, z) then
											result.apex_overlaps = result.apex_overlaps + 1
										end
										local key = occupied_key(x, y, z)
										occupied[key] = -1
										occupied_positions[key] = {x, y, z}
										aggregate.reserved = aggregate.reserved + 1
									end
								end
							end
							for part = 1, #cells do
								if cells[part].include then
									aggregate.emitted = aggregate.emitted + 1
									local cell = cells[part]
									evidence_write(candidate.x + cell.x,
										candidate.y + cell.y, candidate.z + cell.z,
										cell.content_ref, cell.param2, 12, feature_ref,
										interface_ref, -1)
								end
							end
						end
					end
				end
			end
			result.direct_rows = evidence_rows(prospective)
			result.direct_runs = evidence_run_rows(result.direct_rows)
			if successor_tail then
				if type(successor_tail.plan_evidence_owner) ~= "function" then
					fail("fail_ledger", "successor evidence planner is absent")
				end
				local plan, generation = successor_tail:plan_evidence_owner(owner_x,
					owner_x + 79, owner_z, owner_z + 79)
				local context = {schema = "grug_wp40_r7_successor_context_v1",
					plan = plan, generation = generation, call_mode = "evidence_fixture",
					min_x = owner_x, min_y = -30912, min_z = owner_z,
					max_x = owner_x + 79, max_y = 30927, max_z = owner_z + 79}
				local function evidence_inside(x, y, z)
					local surface_y = select(6, planner_source.column_values_at(x, z))
					return inside(x, y, z, owner_minimum(surface_y + 1))
				end
				function context.inside_owner(x, y, z) return evidence_inside(x, y, z) end
				function context.original_at(x, y, z)
					return evidence_air_cid, 0
				end
				function context.settled_at(x, y, z)
					local key = occupied_key(x, y, z)
					local row = written[key]
					if row then
						return row[4], row[5], row[6], row[7], row[8], row[9], row[10]
					end
					local _, cid, _, opcode, aux = prospective(x, y, z)
					return cid, 0, occupied[key] or 0, opcode, 0, 0, aux
				end
				function context.production_content(name)
					local ref = content.content_ref(name)
					return ref, ref and contract.content_cids[ref] or nil
				end
				function context.analytic_p7_ref(x, y, z)
					return analytic_p7_material_ref(x, y, z)
				end
				function context.analytic_p7_tuple(x, y, z)
					local ref = analytic_p7_material_ref(x, y, z)
					if not ref then return -1, -1, -3, -1, -1, -1, -1 end
					local _, _, _, biome, _, terrain_y, water_y =
						planner_source.column_values_at(x, z)
					local opcode = y < terrain_y and 2 or
						((water_y ~= nil and water_y > terrain_y) and 1 or
							(biome == "grug_beach" and 3 or 4))
					return contract.content_cids[ref], 0, 0, opcode, 0, 0,
						(ref - 1) * 256
				end
				function context.exclusion_at(x, z) return exclusion_reason(x, z) end
				function context.housing_excluded_at(x, z)
					return housing_excluded_at(x, z)
				end
				function context.column_values_at(x, z)
					return planner_source.column_values_at(x, z)
				end
				function context.write_p9g(x, y, z, cid, param2, local_ref, feature)
					local key = occupied_key(x, y, z)
					occupied[key] = -2
					occupied_positions[key] = {x, y, z}
					written[key] = {x, y, z, cid, param2, -2, 35, feature, 0,
						(#contract.content_names + local_ref - 1) * 256 + param2}
				end
				result.p9g = successor_tail:settle(context)
				result.final_rows = evidence_rows(prospective)
				result.final_runs = evidence_run_rows(result.final_rows)
			end
			return result
		end

		-- The exhaustive resource census is a production-owned fixture seam.  It
		-- uses the same catalog, hash, budget, root and frontier rules as apply(),
		-- but supplies the contract's closed immutable evidence substrate instead
		-- of a VoxelManip.  Tooling may aggregate this ledger; it must not recreate
		-- P8 settlement.
		local function scan_census_cube(record)
			exact_fields(record, {race = true, bucket = true, zone_id = true,
				cell_x = true, cell_y = true, cell_z = true}, "census cube",
				"fail_ledger")
			local race = record.race
			if type(race) ~= "string" or type(record.bucket) ~= "string" or
					type(record.zone_id) ~= "string" then
				fail("fail_ledger", "census cube vocabulary differs")
			end
			local cell_x = integer(record.cell_x, "census cell x", -1932, 1932,
				"fail_ledger")
			local cell_y = integer(record.cell_y, "census cell y", -1932, 1932,
				"fail_ledger")
			local cell_z = integer(record.cell_z, "census cell z", -1932, 1932,
				"fail_ledger")
			local min_x, min_y, min_z = cell_x * 16, cell_y * 16, cell_z * 16
			local max_y = min_y + 15
			if max_y >= -37 then
				fail("fail_ledger", "census cube is not below the P2-P7 authored floor")
			end
			local tier, host_name = tier_at(min_y)
			local last_tier, last_host = tier_at(max_y)
			local band, multiplier_numerator, multiplier_denominator = deep_band(min_y)
			local last_band = deep_band(max_y)
			if last_tier ~= tier or last_host ~= host_name or last_band ~= band then
				fail("fail_ledger", "census cube crosses a tier or deep-band boundary")
			end

			local substrate_counts, substrate_parts = {}, {}
			local substrate_class_names = {"AIR", "NATIVE_ORE", "LIQUID", host_name}
			for index = 1, #substrate_class_names do
				local class_name = substrate_class_names[index]
				if substrate_counts[class_name] ~= nil then
					fail("fail_ledger", "duplicate substrate class identity")
				end
				substrate_counts[class_name], substrate_parts[class_name] = 0, {}
			end
			local function substrate_add(class_name, x, y, z)
				if substrate_counts[class_name] == nil then
					fail("fail_ledger", "unknown substrate class identity")
				end
				substrate_counts[class_name] = substrate_counts[class_name] + 1
				local parts = substrate_parts[class_name]
				parts[#parts + 1] = hash.frame(x) .. hash.frame(y) .. hash.frame(z) ..
					hash.frame(class_name)
			end
			local function local_index(x, y, z)
				return (z - min_z) * 256 + (y - min_y) * 16 + (x - min_x) + 1
			end
			for z = min_z, min_z + 15 do
				for x = min_x, min_x + 15 do
					local column = (z - min_z) * 16 + (x - min_x) + 1
					census_column_allowed[column] = exclusion_reason(x, z) == nil and
						analytic_p7_material_ref(x, max_y, z) == nil
				end
			end
			for index = 1, 4096 do census_occupancy[index] = 0 end
			for z = min_z, min_z + 15 do
				for y = min_y, min_y + 15 do
					for x = min_x, min_x + 15 do
						local digest = hash.digest("evidence_substrate_v1", full_seed,
							{x, y, z})
						local byte = string.byte(digest, 1)
						local class_name = byte <= 15 and "AIR" or
							(byte == 16 and "NATIVE_ORE" or
							(byte == 17 and "LIQUID" or host_name))
						census_occupancy[local_index(x, y, z)] = class_name == host_name and 0 or -1
						substrate_add(class_name, x, y, z)
					end
				end
			end
			local substrate = {}
			for index = 1, #substrate_class_names do
				local class_name = substrate_class_names[index]
				local count = substrate_counts[class_name]
				substrate[class_name] = {count = count,
					digest = hash.hex(hash.sha256_bytes(table.concat(
						substrate_parts[class_name])))}
			end

			local resource_rows, rejections, witnesses = {}, {}, {}
			local apex_overlaps = 0
			local union_host = 0
			local counted_host = false
			for resource_index = 1, #resources do
				local resource = resources[resource_index]
				local denominator = resource.denominators[tier]
				local allowed = regional_allowed(resource, race)
				local eligible = 0
				if denominator and allowed then
					counted_host = true
					for z = min_z, min_z + 15 do
						for y = min_y, min_y + 15 do
							for x = min_x, min_x + 15 do
								local column = (z - min_z) * 16 + (x - min_x) + 1
								if census_column_allowed[column] and
										census_occupancy[local_index(x, y, z)] ~= -1 then
									eligible = eligible + 1
									local coordinate = coordinate_scratch[eligible]
									coordinate.x, coordinate.y, coordinate.z = x, y, z
									coordinate.digest = hash.digest("resource_root_rank_v1",
										full_seed, {resource.key, cell_x, cell_y, cell_z,
											host_name, tier, band, x, y, z})
								end
							end
						end
					end
				end
				local remainder_digest = hash.digest("resource_budget_remainder_v1",
					full_seed, {resource.key, cell_x, cell_y, cell_z, host_name,
						tier, band})
				local budget, numerator, budget_denominator, base_budget, remainder =
					0, 0, denominator and denominator * multiplier_denominator or 1, 0, 0
				if denominator then
					budget, numerator, budget_denominator, base_budget, remainder =
						hash.budget(eligible, 1, denominator, multiplier_numerator,
							multiplier_denominator, remainder_digest)
				end
				sort_prefix(coordinate_scratch, eligible, coordinate_less)
				local planned = budget == 0 and 0 or math.floor((budget +
					resource.max_nodes_per_vein - 1) / resource.max_nodes_per_vein)
				local small = planned == 0 and 0 or math.floor(budget / planned)
				local large_count = budget - small * planned
				local placed, accepted, shortfall, collisions = 0, 0, 0, 0
				local next_root_rank = 1
				for vein = 1, planned do
					local target = small + (vein <= large_count and 1 or 0)
					local root
					while next_root_rank <= eligible do
						local coordinate = coordinate_scratch[next_root_rank]
						next_root_rank = next_root_rank + 1
						local claim = census_occupancy[local_index(coordinate.x,
							coordinate.y, coordinate.z)]
						if claim == 0 then root = coordinate break end
						if claim ~= resource_index then collisions = collisions + 1 end
					end
					if not root then
						local key = "resource\0" .. resource.key .. "\0rejected_no_root"
						rejections[key] = (rejections[key] or 0) + 1
						shortfall = shortfall + target
					else
						accepted = accepted + 1
						if not witnesses[resource.key] then
							witnesses[resource.key] = {race = race, bucket = record.bucket,
								zone_id = record.zone_id, x = root.x, y = root.y, z = root.z}
						end
						local vein_nodes = {{x = root.x, y = root.y, z = root.z}}
						census_occupancy[local_index(root.x, root.y, root.z)] = resource_index
						if overlaps_apex(root.x, root.y, root.z) then
							apex_overlaps = apex_overlaps + 1
						end
						placed = placed + 1
						while #vein_nodes < target do
							local frontier_count = 0
							for node_index = 1, #vein_nodes do
								local node = vein_nodes[node_index]
								for face = 1, 6 do
									local x, y, z = node.x + FACE_X[face],
										node.y + FACE_Y[face], node.z + FACE_Z[face]
									if x >= min_x and x <= min_x + 15 and y >= min_y and
											y <= min_y + 15 and z >= min_z and z <= min_z + 15 and
											census_occupancy[local_index(x, y, z)] == 0 then
										local duplicate = false
										for f = 1, frontier_count do
											local old = frontier_scratch[f]
											if old.x == x and old.y == y and old.z == z then
												duplicate = true break
											end
										end
									if not duplicate then
										if frontier_count >= #frontier_scratch then
											fail("fail_bound", "resource frontier bound exceeded")
										end
										frontier_count = frontier_count + 1
											local frontier = frontier_scratch[frontier_count]
											frontier.x, frontier.y, frontier.z = x, y, z
											frontier.digest = hash.digest(
												"resource_frontier_rank_v1", full_seed,
												{resource.key, cell_x, cell_y, cell_z,
													host_name, tier, band, vein, x, y, z})
										end
									end
								end
							end
							if frontier_count == 0 then break end
							sort_prefix(frontier_scratch, frontier_count, coordinate_less)
							local next_node = frontier_scratch[1]
							vein_nodes[#vein_nodes + 1] = {x = next_node.x,
								y = next_node.y, z = next_node.z}
							census_occupancy[local_index(next_node.x, next_node.y,
								next_node.z)] = resource_index
							if overlaps_apex(next_node.x, next_node.y, next_node.z) then
								apex_overlaps = apex_overlaps + 1
							end
							placed = placed + 1
						end
						if #vein_nodes < target then
							shortfall = shortfall + target - #vein_nodes
							local key = "resource\0" .. resource.key .. "\0short_frontier"
							rejections[key] = (rejections[key] or 0) + 1
						end
					end
				end
				resource_rows[resource.key] = {eligible = eligible,
					numerator = numerator, denominator = budget_denominator,
					base = base_budget, remainder = remainder,
					remainder_digest = hash.hex(remainder_digest), budget = budget,
					planned = planned, accepted = accepted, collisions = collisions,
					shortfall = shortfall, target_nodes = budget, placed_nodes = placed,
					host = host_name, tier = tier, band = band}
			end
			if counted_host then union_host = substrate_counts[host_name] or 0 end
			return {substrate = substrate, resources = resource_rows,
				region_host = {count = union_host, tier = tier, band = band},
				rejections = rejections, witnesses = witnesses,
				apex_overlaps = apex_overlaps}
		end

		local function run_at(plan, column, y)
			local r5 = plan.r5_plan
			for run = r5.column_start[column], r5.column_start[column + 1] - 1 do
				local base = (run - 1) * RUN_STRIDE
				if y < r5.run_values[base + 1] then return nil end
				if y <= r5.run_values[base + 2] then return base end
			end
			return nil
		end
		local function resource_volume_excluded(plan, column, x, y, z)
			if y >= -700 then
				local reason = exclusion_reason(x, z)
				if reason == "fixed_or_protected" or
						(reason == "route_or_water" and in_hard_ingress(x, z)) then
					return true
				end
			end
			local rbase = run_at(plan, column, y)
			if rbase then
				local priority = plan.r5_plan.run_values[rbase + 3]
				if priority == 2 or priority == 3 or priority == 4 or priority == 6 then
					return true
				end
			end
			return false
		end

		local function metric_rejection(ledger, subsystem, catalog_id, reason)
			local key = subsystem .. "\0" .. catalog_id .. "\0" .. reason
			ledger.rejections[key] = (ledger.rejections[key] or 0) + 1
		end
		local helpers = {equal_graph = equal_graph,
			primary_reason = primary_reason, exclusion_reason = exclusion_reason,
			housing_excluded_at = housing_excluded_at,
			analytic_p7_material_ref = analytic_p7_material_ref,
			analytic_p7_support_ref = analytic_p7_support_ref,
			regional_allowed = regional_allowed, coordinate_less = coordinate_less,
			resource_volume_excluded = resource_volume_excluded,
			run_class_policy = run_class_policy,
			capture_private_buffers = capture_private_buffers}

		local function apply_impl(vm, minp, maxp, plan, plan_generation, call_mode)
			if call_mode ~= "fixture" and call_mode ~= "production" and
					call_mode ~= "replay_fixture" then
				fail("fail_status", "R6 is disabled")
			end
			if call_mode == "fixture" or call_mode == "production" then
				last_ledger, last_run_count = false, 0
			end
			if type(plan) ~= "table" or
					plan.schema ~= "grug_wp40_r6_refinement_plan_v1" or
					not plan.valid or plan.generation ~= plan_generation or
					type(dependencies.construction_identity) ~= "table" or
					dependencies.construction_identity.value == false or
					not rawequal(plan.construction_identity,
						dependencies.construction_identity.value) then
				fail("fail_settlement", "plan identity or generation differs")
			end
			local min_x, min_y, min_z = position(minp, "minp")
			local max_x, max_y, max_z = position(maxp, "maxp")
			if min_x ~= plan.min_x or min_y ~= plan.min_y or min_z ~= plan.min_z or
					max_x ~= plan.max_x or max_y ~= plan.max_y or max_z ~= plan.max_z then
				fail("fail_settlement", "plan bounds differ")
			end
			if type(vm) ~= "table" and type(vm) ~= "userdata" then
				fail("fail_vm_contract", "VoxelManip object differs")
			end
			if not stable_state.bound then
				local function bind(values, field, output)
					for value_index = 1, #values do
						local wanted, found = values[value_index][field], 0
						for stable_index = 1, #plan.stable_refs do
							if plan.stable_refs[stable_index] == wanted then
								found = stable_index break
							end
						end
						if found == 0 then
							fail("fail_settlement", "successor stable ref is absent")
						end
						output[value_index] = found
					end
				end
				bind(resources, "key", stable_state.resource)
				bind(cultural, "key", stable_state.cultural)
				bind(decorations, "id", stable_state.decoration)
				stable_state.bound = true
			end
			local required_methods = {"get_emerged_area", "get_data", "get_param2_data",
				"get_light_data", "set_data", "set_param2_data", "set_lighting",
				"calc_lighting", "set_light_data", "update_liquids"}
			for index = 1, #required_methods do
				if type(vm[required_methods[index]]) ~= "function" then
					fail("fail_vm_contract", "required VoxelManip method is absent")
				end
			end
			local ok_area, emerged_min, emerged_max = pcall(vm.get_emerged_area, vm)
			if not ok_area then fail("fail_vm_contract", "get_emerged_area failed") end
			local eminx, eminy, eminz = position(emerged_min, "emerged min")
			local emaxx, emaxy, emaxz = position(emerged_max, "emerged max")
			if eminx ~= min_x - 16 or eminy ~= min_y - 16 or eminz ~= min_z - 16 or
					emaxx ~= max_x + 16 or emaxy ~= max_y + 16 or emaxz ~= max_z + 16 then
				fail("fail_halo", "emerged halo differs")
			end
			local ex, ey, ez = emaxx - eminx + 1, emaxy - eminy + 1,
				emaxz - eminz + 1
			local volume = ex * ey * ez
			if volume < 1 or volume > MAX_VOLUME then
				fail("fail_vm_contract", "emerged volume differs")
			end
			local y_stride, z_stride = ex, ex * ey
			local function index_at(x, y, z)
				return (z - eminz) * z_stride + (y - eminy) * y_stride +
					(x - eminx) + 1
			end
			local ok_data, returned_data = pcall(vm.get_data, vm, original_data)
			if not ok_data or not rawequal(returned_data, original_data) then
				fail("fail_vm_contract", "get_data did not reuse the retained buffer")
			end
			local ok_p2, returned_p2 = pcall(vm.get_param2_data, vm, original_param2)
			if not ok_p2 or not rawequal(returned_p2, original_param2) then
				fail("fail_vm_contract", "get_param2_data did not reuse the retained buffer")
			end
			for index = 1, volume do
				integer(original_data[index], "VM CID", 0, MAX_SAFE, "fail_vm_contract")
				integer(original_param2[index], "VM param2", 0, 255, "fail_vm_contract")
				final_data[index], final_param2[index] =
					original_data[index], original_param2[index]
				occupancy[index], intent_opcode[index], intent_feature[index],
					intent_interface[index], intent_aux[index] = 0, 0, 0, 0, 0
			end

			local light_loaded = false
			local shadow = {}
			function shadow.get_emerged_area() return emerged_min, emerged_max end
			function shadow.get_data(_, buffer)
				for index = 1, volume do buffer[index] = original_data[index] end
				return buffer
			end
			function shadow.get_param2_data(_, buffer)
				for index = 1, volume do buffer[index] = original_param2[index] end
				return buffer
			end
			function shadow.set_data(_, buffer)
				for index = 1, volume do final_data[index] = buffer[index] end
			end
			function shadow.set_param2_data(_, buffer)
				for index = 1, volume do final_param2[index] = buffer[index] end
			end
			function shadow.get_light_data(_, buffer)
				-- Nested R5 lighting is not committed; R6 derives one combined final
				-- light transaction after successor replay.  A closed valid scratch
				-- buffer keeps that projection read-only and avoids an early external
				-- light read whose bytes cannot affect P2-P6 data/param2 settlement.
				for index = 1, volume do buffer[index] = 0 end
				return buffer
			end
			function shadow.set_lighting() end
			function shadow.calc_lighting() end
			function shadow.set_light_data() end
			function shadow.update_liquids() end
			local r5_result = r5_adapter:apply(shadow, minp, maxp, plan.r5_plan,
				plan.r5_generation, call_mode == "production" and
					"engine_fixture" or "offline_fixture")
			if type(r5_result) ~= "string" then
				fail("fail_settlement", "nested R5 result differs")
			end

			local ledger = {rejections = {}, resources = {}, cultural = {},
				decorations = {}, successor_runs = 0}
			local accepted_cultural = {}
			local x_count = max_x - min_x + 1
			local function column_index(x, z)
				return (z - min_z) * x_count + (x - min_x) + 1
			end
			local function write_intent(x, y, z, content_ref, param2, opcode,
					feature_ref, interface_ref, role_bit, occupant)
				if x < min_x or x > max_x or y < min_y or y > max_y or
						z < min_z or z > max_z then
					fail("fail_settlement", "successor write escaped central owner")
				end
				local index = index_at(x, y, z)
				local cid, exact_param2 = resolve(content_ref, param2, role_bit)
				final_data[index], final_param2[index] = cid, exact_param2
				intent_opcode[index], intent_feature[index], intent_interface[index] =
					opcode, feature_ref or 0, interface_ref or 0
				intent_aux[index] = (content_ref - 1) * 256 + exact_param2
				if occupant then occupancy[index] = occupant end
			end

			-- P7: exact R5 P5 predecessor refinement.
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column = column_index(x, z)
					local base = (column - 1) * COLUMN_STRIDE
					local terrain_y = plan.column_values[base + 5]
					local surface_kind = plan.column_values[base + 7]
					local top_ref = plan.column_values[base + 8]
					local filler_ref = plan.column_values[base + 9]
					local alternate_ref = plan.column_values[base + 10]
					local filler_depth = plan.column_values[base + 11]
					local dust_ref = plan.column_values[base + 12]
					if top_ref ~= 0 and terrain_y >= min_y and terrain_y <= max_y then
						local rbase = run_at(plan, column, terrain_y)
						if rbase and plan.r5_plan.run_values[rbase + 4] == 28 then
							local opcode = surface_kind == 1 and 4 or
								(surface_kind == 2 and 3 or 1)
							write_intent(x, terrain_y, z,
								surface_kind == 1 and top_ref or alternate_ref, 0,
								opcode, 0, 0, 1, false)
						end
					end
					for y = terrain_y - filler_depth, terrain_y - 1 do
						if y >= min_y and y <= max_y then
							local rbase = run_at(plan, column, y)
							if rbase and plan.r5_plan.run_values[rbase + 4] == 27 then
								local index = index_at(x, y, z)
								local class_id = classify(final_data[index], final_param2[index])
								if filler_ref ~= 0 and class_id ~= CLASS_AIR and
										class_id ~= CLASS_LIQUID then
									if class_id == CLASS_FOREIGN or class_id == CLASS_UNKNOWN or
											class_id == CLASS_IGNORE then
										fail("fail_settlement", "P7 filler predecessor differs")
									end
									write_intent(x, y, z, filler_ref, 0, 2, 0, 0, 1, false)
								end
							end
						end
					end
					local dust_y = terrain_y + 1
					if dust_ref ~= 0 and surface_kind == 1 and dust_y >= min_y and
							dust_y <= max_y then
						local rbase = run_at(plan, column, dust_y)
						local index = index_at(x, dust_y, z)
						if helpers.analytic_p7_support_ref(x, terrain_y, z) ~= nil and rbase and
								plan.r5_plan.run_values[rbase + 4] == 26 and
								classify(final_data[index], final_param2[index]) == CLASS_AIR then
							write_intent(x, dust_y, z, dust_ref, 0, 33, 0, 0, 2, false)
						end
					end
				end
			end

			local function inside_owner(x, y, z)
				return x >= min_x and x <= max_x and y >= min_y and y <= max_y and
					z >= min_z and z <= max_z and x >= -3740 and x <= 3740 and
					z >= -3340 and z <= 3340 and y >= -31000 and y <= 31000
			end
			local function candidate_fields(candidate)
				local base = (candidate - 1) * CANDIDATE_STRIDE
				return plan.candidate_values[base + 1], plan.candidate_values[base + 2],
					plan.candidate_values[base + 3], plan.candidate_values[base + 4],
					plan.candidate_values[base + 5], plan.candidate_values[base + 6]
			end

			-- Invisible cultural reservation settlement precedes P8.
			for cell = 1, plan.candidate_cell_count do
				local cell_base = (cell - 1) * CELL_STRIDE
				for candidate = plan.candidate_cell_values[cell_base + 3],
						plan.candidate_cell_values[cell_base + 4] - 1 do
					local kind, catalog, denominator, root_x, root_y, root_z =
						candidate_fields(candidate)
					if kind == 1 and root_x >= min_x and root_x <= max_x and
							root_y >= min_y and root_y <= max_y and
							root_z >= min_z and root_z <= max_z then
						local row = cultural[catalog]
						local flags = {}
						for z = root_z - 2, root_z + 2 do
							for y = root_y - 1, root_y + 7 do
								for x = root_x - 2, root_x + 2 do
									if not inside_owner(x, y, z) then flags.clipped_owner = true
									else
										local excluded = helpers.exclusion_reason(x, z)
										if excluded then flags[excluded] = true end
										local index = index_at(x, y, z)
										if original_data[index] == contract.ignore_cid then
											flags.content_ignore = true
										elseif occupancy[index] == 1 then
											flags.cultural_collision = true
										end
									end
								end
							end
						end
						local support_index = inside_owner(root_x, root_y, root_z) and
							index_at(root_x, root_y, root_z) or nil
						if not support_index or (intent_opcode[support_index] ~= 3 and
								intent_opcode[support_index] ~= 4) then
							flags.wrong_support = true
						end
						local reason = helpers.primary_reason(flags, {"clipped_owner",
							"fixed_or_protected", "route_or_water", "content_ignore",
							"wrong_support", "cultural_collision"})
						local rate = denominator == 1024 and "concentrated" or "ordinary"
						local aggregate = ledger.cultural[row.key .. "\0" .. rate] or
							{accepted = 0, reserved = 0}
						ledger.cultural[row.key .. "\0" .. rate] = aggregate
						if reason then
							metric_rejection(ledger, "cultural", row.key, reason)
						else
							aggregate.accepted = aggregate.accepted + 1
							aggregate.reserved = aggregate.reserved + 225
							for z = root_z - 2, root_z + 2 do
								for y = root_y - 1, root_y + 7 do
									for x = root_x - 2, root_x + 2 do
										occupancy[index_at(x, y, z)] = 1
									end
								end
							end
							accepted_cultural[#accepted_cultural + 1] = {row = row,
								catalog = catalog, x = root_x, y = root_y, z = root_z}
						end
					end
				end
			end

			local function host_eligible(resource, x, y, z, tier, host_cid)
				local water_class, _, _, _, race = planner_source.column_values_at(x, z)
				if (water_class ~= "land" and water_class ~= "planned_water") or
						not helpers.regional_allowed(resource, race) then return false end
				local denominator = resource.denominators[tier]
				if not denominator then return false end
				local index = index_at(x, y, z)
				return not helpers.resource_volume_excluded(plan, column_index(x, z),
					x, y, z) and original_data[index] == host_cid and
					((intent_opcode[index] == 0 and
						final_data[index] == original_data[index]) or
						intent_opcode[index] == 24) and occupancy[index] ~= 1
			end
			for resource_index = 1, #resources do
				local resource = resources[resource_index]
				for cell_z = math.floor(min_z / 16), math.floor(max_z / 16) do
					for cell_x = math.floor(min_x / 16), math.floor(max_x / 16) do
						for cell_y = math.floor(min_y / 16), math.floor(max_y / 16) do
							local first_y = math.max(min_y, cell_y * 16)
							local last_y = math.min(max_y, cell_y * 16 + 15)
							local segment_y = first_y
							while segment_y <= last_y do
								local tier, host_name = tier_at(segment_y)
								local band, multiplier_numerator,
									multiplier_denominator = deep_band(segment_y)
								local segment_end = segment_y
								while segment_end < last_y do
									local ntier = tier_at(segment_end + 1)
									local nband = deep_band(segment_end + 1)
									if ntier ~= tier or nband ~= band then break end
									segment_end = segment_end + 1
								end
								local host_ref = content.content_ref(host_name)
								local host_cid = host_ref and contract.content_cids[host_ref]
								local eligible = 0
								if host_cid and resource.denominators[tier] then
									for z = math.max(min_z, cell_z * 16),
											math.min(max_z, cell_z * 16 + 15) do
										for y = segment_y, segment_end do
											for x = math.max(min_x, cell_x * 16),
													math.min(max_x, cell_x * 16 + 15) do
												if host_eligible(resource, x, y, z, tier, host_cid) then
													eligible = eligible + 1
													local coordinate = coordinate_scratch[eligible]
													coordinate.x, coordinate.y, coordinate.z = x, y, z
													coordinate.digest = hash.digest(
														"resource_root_rank_v1", full_seed,
														{resource.key, cell_x, cell_y, cell_z,
															host_name, tier, band, x, y, z})
												end
											end
										end
									end
								end
								if eligible > 0 then
									local denominator = resource.denominators[tier]
									local remainder_digest = hash.digest(
										"resource_budget_remainder_v1", full_seed,
										{resource.key, cell_x, cell_y, cell_z, host_name,
											tier, band})
									local budget, numerator, budget_denominator, base_budget,
										remainder = hash.budget(eligible, 1, denominator,
										multiplier_numerator, multiplier_denominator,
										remainder_digest)
									sort_prefix(coordinate_scratch, eligible, helpers.coordinate_less)
									local planned = budget == 0 and 0 or
										math.floor((budget + resource.max_nodes_per_vein - 1) /
											resource.max_nodes_per_vein)
									local small = planned == 0 and 0 or math.floor(budget / planned)
									local large_count = budget - small * planned
									local placed, accepted, shortfall, collisions = 0, 0, 0, 0
									local next_root_rank = 1
									for vein = 1, planned do
										local target = small + (vein <= large_count and 1 or 0)
										local root
										while next_root_rank <= eligible do
											local coordinate = coordinate_scratch[next_root_rank]
											next_root_rank = next_root_rank + 1
											local claim = occupancy[index_at(coordinate.x,
												coordinate.y, coordinate.z)]
											if claim == 0 then root = coordinate break end
											if claim ~= resource_index + 1 then
												collisions = collisions + 1
											end
										end
										if not root then
											metric_rejection(ledger, "resource", resource.key,
												"rejected_no_root")
											shortfall = shortfall + target
										else
											accepted = accepted + 1
											local vein_nodes = {{x = root.x, y = root.y, z = root.z}}
											local root_index = index_at(root.x, root.y, root.z)
											occupancy[root_index] = resource_index + 1
											write_intent(root.x, root.y, root.z,
												resource.content_ref, 0, 24,
												stable_state.resource[resource_index], 0, 4,
												resource_index + 1)
											placed = placed + 1
											while #vein_nodes < target do
												local frontier_count = 0
												for node_index = 1, #vein_nodes do
													local node = vein_nodes[node_index]
													for face = 1, 6 do
														local x, y, z = node.x + FACE_X[face],
															node.y + FACE_Y[face], node.z + FACE_Z[face]
												if x >= math.max(min_x, cell_x * 16) and
														x <= math.min(max_x, cell_x * 16 + 15) and
														y >= segment_y and y <= segment_end and
														z >= math.max(min_z, cell_z * 16) and
														z <= math.min(max_z, cell_z * 16 + 15) and
																host_eligible(resource, x, y, z, tier, host_cid) and
																occupancy[index_at(x, y, z)] == 0 then
															local duplicate = false
															for f = 1, frontier_count do
																local old = frontier_scratch[f]
																if old.x == x and old.y == y and old.z == z then
																	duplicate = true break
																end
															end
														if not duplicate then
															if frontier_count >= #frontier_scratch then
																fail("fail_bound", "resource frontier bound exceeded")
															end
															frontier_count = frontier_count + 1
																local frontier = frontier_scratch[frontier_count]
																frontier.x, frontier.y, frontier.z = x, y, z
																frontier.digest = hash.digest(
																	"resource_frontier_rank_v1", full_seed,
																	{resource.key, cell_x, cell_y, cell_z,
																		host_name, tier, band, vein, x, y, z})
															end
														end
													end
												end
												if frontier_count == 0 then break end
											sort_prefix(frontier_scratch, frontier_count,
												helpers.coordinate_less)
												local next_node = frontier_scratch[1]
												vein_nodes[#vein_nodes + 1] = {x = next_node.x,
													y = next_node.y, z = next_node.z}
												occupancy[index_at(next_node.x, next_node.y,
													next_node.z)] = resource_index + 1
												write_intent(next_node.x, next_node.y, next_node.z,
													resource.content_ref, 0, 24,
													stable_state.resource[resource_index], 0, 4,
													resource_index + 1)
												placed = placed + 1
											end
											if #vein_nodes < target then
												shortfall = shortfall + target - #vein_nodes
												metric_rejection(ledger, "resource", resource.key,
													"short_frontier")
											end
										end
									end
									local key = table.concat({resource.key, cell_x, cell_y,
										cell_z, host_name, tier, band}, "\0")
									ledger.resources[key] = {eligible = eligible, numerator = numerator,
										denominator = budget_denominator, base = base_budget,
										remainder = remainder, remainder_digest = hash.hex(remainder_digest),
										budget = budget, planned = planned, accepted = accepted,
										collisions = collisions, shortfall = shortfall,
										target_nodes = budget, placed_nodes = placed}
								end
								segment_y = segment_end + 1
							end
						end
					end
				end
			end

			-- P9 cultural output is visible only after P8.  The reservation itself
			-- remains the earlier occupancy authority.  Validate every cell before
			-- committing any cell so one registration cannot partially settle.
			for accepted_index = 1, #accepted_cultural do
				local accepted = accepted_cultural[accepted_index]
				local registration = cultural_registration[accepted.row.key]
				if registration then
					local allowed = true
					for part = 1, #registration.cells do
						local cell_record = registration.cells[part]
						local x, y, z = accepted.x + cell_record.x,
							accepted.y + cell_record.y, accepted.z + cell_record.z
						local index = inside_owner(x, y, z) and index_at(x, y, z) or nil
						if not index or original_data[index] == contract.ignore_cid or
								occupancy[index] >= 2 then
							allowed = false break
						end
						local target = contract.content_cids[cell_record.content_ref]
						local class_id = classify(final_data[index], final_param2[index])
						local lower = cell_record.y == -1 or cell_record.y == 0
						local exact_p7 = intent_opcode[index] >= 1 and intent_opcode[index] <= 4
						local preserves_p7 = lower and exact_p7 and
							registration.lower_two_policy == "preserve_p7"
						if not preserves_p7 and final_data[index] ~= target and
								class_id ~= CLASS_AIR and
								class_id ~= CLASS_NATURAL_VEGETATION and
								not (lower and registration.lower_two_policy ==
									"replace_exact_p7" and exact_p7) then
							allowed = false break
						end
					end
					if allowed then
						for part = 1, #registration.cells do
							local cell_record = registration.cells[part]
							local x, y, z = accepted.x + cell_record.x,
								accepted.y + cell_record.y, accepted.z + cell_record.z
							local index = index_at(x, y, z)
							local lower = cell_record.y == -1 or cell_record.y == 0
							local exact_p7 = intent_opcode[index] >= 1 and
								intent_opcode[index] <= 4
							if not (lower and exact_p7 and
									registration.lower_two_policy == "preserve_p7") then
								write_intent(x, y, z, cell_record.content_ref,
									cell_record.param2, 34,
									stable_state.cultural[accepted.catalog],
									registration.template_or_simple_kind == "template" and
										stable_state.cultural[accepted.catalog] or 0, 16, 1)
							end
						end
					else
						metric_rejection(ledger, "cultural", accepted.row.key,
							"wrong_support")
					end
				end
			end

			-- P9 decorations, globally ordered by class, cell z/x and planned rank.
			for class = 1, 4 do
				for cell = 1, plan.candidate_cell_count do
					local cell_base = (cell - 1) * CELL_STRIDE
					for candidate = plan.candidate_cell_values[cell_base + 3],
							plan.candidate_cell_values[cell_base + 4] - 1 do
						local kind, catalog, parameter, root_x, root_y, root_z =
							candidate_fields(candidate)
						if kind == 2 and parameter == class and root_x >= min_x and
								root_x <= max_x and root_y >= min_y and root_y <= max_y and
								root_z >= min_z and root_z <= max_z then
							local row = decorations[catalog]
							local cells, min_fx, max_fx, min_fy, max_fy, min_fz, max_fz = {}, 0, 0, 0, 0, 0, 0
							local template_ref = 0
							if row.kind == "template" then
								local rotation_digest = hash.digest("decoration_rotation_v1",
									full_seed, {row.id, root_x, root_y, root_z})
								local rotation = math.floor(string.byte(rotation_digest, 1) / 64)
								local template = templates.rotation(row.id, rotation)
								template_ref = stable_state.decoration[catalog]
								min_fx, max_fx, min_fy, max_fy, min_fz, max_fz = template.min_x,
									template.max_x, template.min_y, template.max_y,
									template.min_z, template.max_z
								for z = 1, template.size_z do
									for y = 1, template.size_y do
										local slice_ok = templates.probability_include(full_seed,
											row.id, root_x, root_y, root_z, rotation, "slice",
											0, y - 1, 0, template.y_slice_probabilities[y])
										for x = 1, template.size_x do
											local source_index = (z - 1) * template.size_x *
												template.size_y + (y - 1) * template.size_x + x
											local node = template.cells[source_index]
											local included = slice_ok and node.name ~= "air" and
												templates.probability_include(full_seed, row.id,
													root_x, root_y, root_z, rotation, "node",
													x - 1, y - 1, z - 1, node.probability)
											cells[#cells + 1] = {x = template.min_x + x - 1,
												y = template.min_y + y - 1,
												z = template.min_z + z - 1, include = included,
												content_ref = node.content_ref, param2 = node.param2,
												force_place = node.force_place}
										end
									end
								end
							else
								local height = 1
								if row.settlement_class == 3 then
									local digest = hash.digest("decoration_simple_height_v1",
										full_seed, {row.id, root_x, root_y, root_z})
									height = 2 + (string.byte(digest, 1) % 3)
								end
								max_fy = height - 1
								for y = 0, height - 1 do
									cells[#cells + 1] = {x = 0, y = y, z = 0, include = true,
										content_ref = row.content_ref,
										param2 = row.rule == "param2_4" and 4 or 0,
										force_place = false}
								end
							end
							local flags = {}
							if not inside_owner(root_x + min_fx, root_y + min_fy,
									root_z + min_fz) or not inside_owner(root_x + max_fx,
									root_y + max_fy, root_z + max_fz) then
								flags.clipped_owner = true
							end
							local support = inside_owner(root_x, root_y - 1, root_z) and
								index_at(root_x, root_y - 1, root_z) or nil
							local support_ref
							if not support then
								support_ref = helpers.analytic_p7_support_ref(root_x,
									root_y - 1, root_z)
							end
							if (support and (intent_opcode[support] < 1 or
									intent_opcode[support] > 4 or final_data[support] ~=
									contract.content_cids[content.content_ref(row.host)])) or
									(not support and support_ref ~= content.content_ref(row.host)) then
								flags.wrong_host = true
							end
							if not flags.clipped_owner then
								for z = root_z + min_fz, root_z + max_fz do
									for y = root_y + min_fy, root_y + max_fy do
										for x = root_x + min_fx, root_x + max_fx do
											local index = index_at(x, y, z)
											if original_data[index] == contract.ignore_cid then
												flags.content_ignore = true
											end
											local excluded = helpers.exclusion_reason(x, z)
											if excluded then flags[excluded] = true end
											if occupancy[index] == 1 then flags.cultural_collision = true
											elseif occupancy[index] >= 2 and
													occupancy[index] <= #resources + 1 then
												flags.resource_collision = true
											elseif occupancy[index] == -1 then
												flags.decoration_collision = true end
										end
									end
								end
							end
							if not flags.clipped_owner then
								for part = 1, #cells do
									local cell_record = cells[part]
									if cell_record.include then
										local index = index_at(root_x + cell_record.x,
											root_y + cell_record.y, root_z + cell_record.z)
										local target_cid = contract.content_cids[cell_record.content_ref]
										local class_id = classify(final_data[index], final_param2[index])
										if final_data[index] ~= target_cid and class_id ~= CLASS_AIR and
												class_id ~= CLASS_NATURAL_VEGETATION and
												not (cell_record.force_place and intent_opcode[index] >= 1 and
													intent_opcode[index] <= 4) then
											if cell_record.force_place then
												flags.forbidden_old_class = true
											else
												flags.insufficient_clearance = true
											end
										end
									end
								end
							end
							local reason = helpers.primary_reason(flags, {"clipped_owner",
								"content_ignore", "fixed_or_protected", "route_or_water",
								"wrong_host", "insufficient_clearance", "cultural_collision",
								"resource_collision", "decoration_collision",
								"forbidden_old_class"})
							local aggregate = ledger.decorations[row.id] or
								{accepted = 0, emitted = 0, reserved = 0}
							ledger.decorations[row.id] = aggregate
							if reason then metric_rejection(ledger, "decoration", row.id, reason)
							else
								aggregate.accepted = aggregate.accepted + 1
								for z = root_z + min_fz, root_z + max_fz do
									for y = root_y + min_fy, root_y + max_fy do
										for x = root_x + min_fx, root_x + max_fx do
											occupancy[index_at(x, y, z)] = -1
											aggregate.reserved = aggregate.reserved + 1
										end
									end
								end
								for part = 1, #cells do
									local cell_record = cells[part]
									if cell_record.include then
									write_intent(root_x + cell_record.x, root_y + cell_record.y,
										root_z + cell_record.z, cell_record.content_ref,
										cell_record.param2, 12, stable_state.decoration[catalog],
										template_ref, 8, -1)
										aggregate.emitted = aggregate.emitted + 1
									end
								end
							end
						end
					end
				end
			end

			-- R7's only legal successor hook. It receives a deliberately narrow
			-- closure surface over these private buffers, runs after the complete R6
			-- P9 loop and before common run derivation/replay/commit, and cannot call
			-- a VoxelManip setter. A missing tail preserves the accepted R6 path.
			if transaction_state.successor_tail then
				local successor_context = {
					schema = "grug_wp40_r7_successor_context_v1",
					plan = plan, generation = plan_generation, call_mode = call_mode,
					min_x = min_x, min_y = min_y, min_z = min_z,
					max_x = max_x, max_y = max_y, max_z = max_z,
				}
				function successor_context.inside_owner(x, y, z)
					return inside_owner(x, y, z)
				end
				function successor_context.original_at(x, y, z)
					local index = index_at(x, y, z)
					return original_data[index], original_param2[index]
				end
				function successor_context.settled_at(x, y, z)
					local index = index_at(x, y, z)
					return final_data[index], final_param2[index], occupancy[index],
						intent_opcode[index], intent_feature[index], intent_interface[index],
						intent_aux[index]
				end
				function successor_context.production_content(name)
					local ref = content.content_ref(name)
					return ref, ref and contract.content_cids[ref] or nil
				end
				function successor_context.analytic_p7_ref(x, y, z)
					return helpers.analytic_p7_material_ref(x, y, z)
				end
				function successor_context.analytic_p7_tuple(x, y, z)
					local ref = helpers.analytic_p7_material_ref(x, y, z)
					if not ref then return -1, -1, -3, -1, -1, -1, -1 end
					local _, _, _, biome, _, terrain_y, water_y =
						planner_source.column_values_at(x, z)
					local opcode
					if y < terrain_y then opcode = 2
					elseif water_y ~= nil and water_y > terrain_y then opcode = 1
					elseif biome == "grug_beach" then opcode = 3
					else opcode = 4 end
					return contract.content_cids[ref], 0, 0, opcode, 0, 0,
						(ref - 1) * 256
				end
				function successor_context.exclusion_at(x, z)
					return helpers.exclusion_reason(x, z)
				end
				function successor_context.housing_excluded_at(x, z)
					return helpers.housing_excluded_at(x, z)
				end
				function successor_context.column_values_at(x, z)
					return planner_source.column_values_at(x, z)
				end
				function successor_context.write_p9g(x, y, z, cid, param2,
						local_ref, feature_ref)
					if not inside_owner(x, y, z) then
						fail("fail_settlement", "P9G write escaped central owner")
					end
					integer(cid, "P9G CID", 0, MAX_SAFE, "fail_content_manifest")
					integer(param2, "P9G param2", 0, 255, "fail_content_manifest")
					integer(local_ref, "P9G local ref", 1, 12, "fail_content_manifest")
					integer(feature_ref, "P9G feature ref", 1, 12, "fail_content_manifest")
					if cid == contract.ignore_cid then
						fail("fail_content_manifest", "P9G target is ignore")
					end
					local index = index_at(x, y, z)
					final_data[index], final_param2[index] = cid, param2
					intent_opcode[index], intent_feature[index], intent_interface[index] =
						35, feature_ref, 0
					local successor_ref = #contract.content_names + local_ref
					intent_aux[index] = (successor_ref - 1) * 256 + param2
					occupancy[index] = -2
				end
				local p9g_ledger = transaction_state.successor_tail:settle(successor_context)
				if type(p9g_ledger) ~= "table" then
					fail("fail_ledger", "P9G ledger differs")
				end
				ledger.p9g = p9g_ledger
			end

			-- Canonical run derivation.  The second pass compares every scalar
			-- against the first pass's retained run buffer instead of overwriting it;
			-- exact run parity also proves the reconstructed data/param2 bytes.
			local replaying = call_mode == "replay_fixture"
			local expected_run_count = replaying and last_ledger and
				last_ledger.successor_runs or nil
			local run_count = 0
			local function emit_run(y_min, y_max, opcode, feature, interface, aux)
				run_count = run_count + 1
				if run_count > MAX_RUNS then
					fail("fail_bound", "successor run bound exceeded")
				end
				local base = (run_count - 1) * RUN_STRIDE
				local class_id, policy = helpers.run_class_policy(opcode)
				if replaying then
					if run_values[base + 1] ~= y_min or run_values[base + 2] ~= y_max or
							run_values[base + 3] ~= class_id or
							run_values[base + 4] ~= opcode or run_values[base + 5] ~= 17 or
							run_values[base + 6] ~= policy or
							run_values[base + 7] ~= feature or
							run_values[base + 8] ~= interface or
							run_values[base + 9] ~= aux then
						fail("fail_ledger", "second settlement run bytes differ")
					end
				else
					run_values[base + 1], run_values[base + 2] = y_min, y_max
					run_values[base + 3], run_values[base + 4] = class_id, opcode
					run_values[base + 5], run_values[base + 6] = 17, policy
					run_values[base + 7], run_values[base + 8], run_values[base + 9] =
						feature, interface, aux
				end
			end
			for z = min_z, max_z do
				for x = min_x, max_x do
					local start_y, previous_y, previous_opcode, previous_feature,
						previous_interface, previous_aux
					for y = min_y, max_y do
						local index = index_at(x, y, z)
						local opcode = intent_opcode[index]
						local feature, interface, aux = intent_feature[index],
							intent_interface[index], intent_aux[index]
						local continues = start_y ~= nil and previous_y == y - 1 and
							opcode ~= 0 and opcode == previous_opcode and
							feature == previous_feature and interface == previous_interface and
							aux == previous_aux
						if start_y ~= nil and not continues then
							emit_run(start_y, previous_y, previous_opcode, previous_feature,
								previous_interface, previous_aux)
							start_y = nil
						end
						if opcode ~= 0 then
							if start_y == nil then start_y = y end
							previous_y, previous_opcode = y, opcode
							previous_feature, previous_interface, previous_aux =
								feature, interface, aux
						end
					end
					if start_y ~= nil then
						emit_run(start_y, previous_y, previous_opcode, previous_feature,
							previous_interface, previous_aux)
					end
				end
			end
			if replaying and expected_run_count ~= run_count then
				fail("fail_ledger", "second settlement run count differs")
			end
			ledger.successor_runs = run_count
			local checksum_a, checksum_b = 1, 7
			for index = 1, run_count * RUN_STRIDE do
				local value = run_values[index]
				checksum_a = (checksum_a * 131 + (value + 31012)) % 6700417
				checksum_b = (checksum_b * 257 + (value + 31012)) % 15485863
			end
			ledger.run_checksum_a, ledger.run_checksum_b = checksum_a, checksum_b
			if not replaying and run_count > metrics_state.peak_successor_runs then
				metrics_state.peak_successor_runs = run_count
			end
			local capture_state = transaction_state.private_capture
			if capture_state and not replaying then
				if not capture_state.armed or capture_state.value then
					fail("fail_ledger", "private capture was not armed exactly once")
				end
				capture_state.armed = false
				capture_state.value = helpers.capture_private_buffers(hash, {
					min_x = min_x, min_y = min_y, min_z = min_z,
					max_x = max_x, max_y = max_y, max_z = max_z,
				}, index_at, {data = final_data, param2 = final_param2,
					occupancy = occupancy, opcode = intent_opcode,
					feature = intent_feature, interface = intent_interface,
					aux = intent_aux}, run_values, run_count, checksum_a, checksum_b,
					transaction_state.successor_tail and ledger or false)
			end
			last_ledger = ledger
			last_run_count = run_count
			if replaying then return "replay_ready" end
			local first_ledger = copy_map(ledger)
			local replay_vm = {}
			function replay_vm.get_emerged_area() return emerged_min, emerged_max end
			function replay_vm.get_data(_, buffer)
				for index = 1, volume do buffer[index] = original_data[index] end
				return buffer
			end
			function replay_vm.get_param2_data(_, buffer)
				for index = 1, volume do buffer[index] = original_param2[index] end
				return buffer
			end
			function replay_vm.get_light_data(_, buffer)
				if not light_loaded then
					fail("fail_ledger", "second replay requested new immutable light input")
				end
				for index = 1, volume do buffer[index] = original_light[index] end
				return buffer
			end
			function replay_vm.set_data() fail("fail_ledger", "replay attempted data setter") end
			function replay_vm.set_param2_data()
				fail("fail_ledger", "replay attempted param2 setter")
			end
			function replay_vm.set_lighting()
				fail("fail_ledger", "replay attempted lighting setter")
			end
			function replay_vm.calc_lighting()
				fail("fail_ledger", "replay attempted lighting calculation")
			end
			function replay_vm.set_light_data()
				fail("fail_ledger", "replay attempted light setter")
			end
			function replay_vm.update_liquids()
				fail("fail_ledger", "replay attempted liquid update")
			end
			local replay_result = apply_impl(replay_vm, minp, maxp, plan, plan_generation,
				"replay_fixture")
			if replay_result ~= "replay_ready" or not last_ledger or
					not helpers.equal_graph(first_ledger, last_ledger) then
				fail("fail_ledger", "second read-only settlement replay differs")
			end
			metrics_state.replay_count = metrics_state.replay_count + 1

			local content_changed, param2_changed, light_changed, liquid_changed =
				false, false, false, false
			last_light_seed_runs = 0
			local light_min_x, light_min_y, light_min_z = max_x, max_y, max_z
			local light_max_x, light_max_y, light_max_z = min_x, min_y, min_z
			local modified, content_columns, param2_columns, light_columns,
				liquid_columns = 0, 0, 0, 0, 0
			local function compatible_liquid(family, kind)
				return (family == contract.ordinary_water_family_id or
					family == contract.river_water_family_id) and (kind == 1 or kind == 2)
			end
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column_content, column_param2, column_light, column_liquid =
						false, false, false, false
					for y = min_y, max_y do
						local index = index_at(x, y, z)
						local changed_content = final_data[index] ~= original_data[index]
						local changed_param2 = final_param2[index] ~= original_param2[index]
						if changed_content or changed_param2 then
							modified = modified + 1
							content_changed = content_changed or changed_content
							param2_changed = param2_changed or changed_param2
							column_content = column_content or changed_content
							column_param2 = column_param2 or changed_param2
							local _, old_family, old_liquid, old_level, old_flood,
								old_light, old_propagates, old_sun, old_source =
								classify(original_data[index], original_param2[index])
							local _, new_family, new_liquid, new_level, new_flood,
								new_light, new_propagates, new_sun, new_source =
								classify(final_data[index], final_param2[index])
							local voxel_light = changed_content and
								(old_light ~= new_light or old_propagates ~= new_propagates or
									old_sun ~= new_sun or old_source ~= new_source)
							if voxel_light then
								light_changed, column_light = true, true
								if x < light_min_x then light_min_x = x end
								if y < light_min_y then light_min_y = y end
								if z < light_min_z then light_min_z = z end
								if x > light_max_x then light_max_x = x end
								if y > light_max_y then light_max_y = y end
								if z > light_max_z then light_max_z = z end
							end
							local voxel_liquid = old_family > 0 or new_family > 0 or
								old_liquid ~= new_liquid or old_family ~= new_family or
								old_level ~= new_level
							if not voxel_liquid and old_flood ~= new_flood then
								for face = 1, 6 do
									local nx, ny, nz = x + FACE_X[face], y + FACE_Y[face],
										z + FACE_Z[face]
									if nx < min_x or nx > max_x or ny < min_y or ny > max_y or
											nz < min_z or nz > max_z then
										voxel_liquid = true
									else
										local neighbor = index_at(nx, ny, nz)
										if final_data[neighbor] == original_data[neighbor] and
												final_param2[neighbor] == original_param2[neighbor] then
											local _, family, kind = classify(final_data[neighbor],
												final_param2[neighbor])
											if compatible_liquid(family, kind) then voxel_liquid = true end
										end
									end
									if voxel_liquid then break end
								end
							end
							if voxel_liquid then liquid_changed, column_liquid = true, true end
						end
					end
					if column_content then content_columns = content_columns + 1 end
					if column_param2 then param2_columns = param2_columns + 1 end
					if column_light then light_columns = light_columns + 1 end
					if column_liquid then liquid_columns = liquid_columns + 1 end
				end
			end
			metrics_state.modified_voxels = metrics_state.modified_voxels + modified
			metrics_state.content_dirty_columns = metrics_state.content_dirty_columns +
				content_columns
			metrics_state.param2_dirty_columns = metrics_state.param2_dirty_columns +
				param2_columns
			metrics_state.light_dirty_columns = metrics_state.light_dirty_columns +
				light_columns
			metrics_state.liquid_dirty_columns = metrics_state.liquid_dirty_columns +
				liquid_columns
			if not content_changed and not param2_changed then return "noop_equal_content" end

			local box_min_x, box_min_y, box_min_z, box_max_x, box_max_y, box_max_z
			local seed_y, seed_run_count = 0, 0
			if light_changed then
				box_min_x, box_min_y, box_min_z = math.max(eminx, light_min_x - 15),
					math.max(eminy, light_min_y - 15), math.max(eminz, light_min_z - 15)
				box_max_x, box_max_y, box_max_z = math.min(emaxx, light_max_x + 15),
					math.min(emaxy - 1, light_max_y + 15), math.min(emaxz, light_max_z + 15)
				if box_min_x > box_max_x or box_min_y > box_max_y or
						box_min_z > box_max_z then
					fail("fail_lighting_context", "light box is empty")
				end
				if not light_loaded then
					local ok, returned = pcall(vm.get_light_data, vm, original_light)
					if not ok or not rawequal(returned, original_light) then
						fail("fail_vm_contract", "get_light_data did not reuse buffer")
					end
					light_loaded = true
				end
				for index = 1, volume do
					integer(original_light[index], "VM light", 0, 255, "fail_vm_contract")
				end
				for z = box_min_z, box_max_z do
					for y = box_min_y, box_max_y do
						for x = box_min_x, box_max_x do
							if final_data[index_at(x, y, z)] == contract.ignore_cid then
								fail("fail_content_ignore", "required light context is ignore")
							end
						end
					end
				end
				seed_y = box_max_y + 1
				for z = box_min_z, box_max_z do
					local run_start
					for x = box_min_x, box_max_x + 1 do
						local seeds = false
						if x <= box_max_x then
							local index = index_at(x, seed_y, z)
							local cid = final_data[index]
							if cid == contract.ignore_cid then
								if x >= min_x and x <= max_x and seed_y >= min_y and
										seed_y <= max_y and z >= min_z and z <= max_z then
									fail("fail_content_ignore", "owner overtop is ignore")
								end
							else
								local _, _, _, _, _, _, _, sunlight =
									classify(cid, final_param2[index], "fail_lighting_context")
								seeds = sunlight and original_light[index] == 15
							end
						end
						if seeds and run_start == nil then
							run_start = x
						elseif not seeds and run_start ~= nil then
							seed_run_count = seed_run_count + 1
							if seed_run_count > #transaction_state.seed_start then
								fail("fail_bound", "light seed-run bound exceeded")
							end
							transaction_state.seed_start[seed_run_count] = run_start
							transaction_state.seed_finish[seed_run_count] = x - 1
							transaction_state.seed_z[seed_run_count] = z
							run_start = nil
						end
					end
				end
				last_light_seed_runs = seed_run_count
			end

			if content_changed then
				local ok = pcall(vm.set_data, vm, final_data)
				if not ok then fail("fail_vm_contract", "set_data failed") end
			end
			if param2_changed then
				local ok = pcall(vm.set_param2_data, vm, final_param2)
				if not ok then fail("fail_vm_contract", "set_param2_data failed") end
			end
			if light_changed then
				local light_call_min, light_call_max = transaction_state.call_min,
					transaction_state.call_max
				light_call_min.x, light_call_min.y, light_call_min.z =
					box_min_x, box_min_y, box_min_z
				light_call_max.x, light_call_max.y, light_call_max.z =
					box_max_x, box_max_y, box_max_z
				local ok = pcall(vm.set_lighting, vm, transaction_state.light_zero,
					light_call_min, light_call_max)
				if not ok then fail("fail_vm_contract", "set_lighting failed") end
				for run = 1, seed_run_count do
					light_call_min.x, light_call_min.y, light_call_min.z =
						transaction_state.seed_start[run], seed_y,
						transaction_state.seed_z[run]
					light_call_max.x, light_call_max.y, light_call_max.z =
						transaction_state.seed_finish[run], seed_y,
						transaction_state.seed_z[run]
					ok = pcall(vm.set_lighting, vm, transaction_state.light_full,
						light_call_min, light_call_max)
					if not ok then fail("fail_vm_contract", "light seed setter failed") end
				end
				light_call_min.x, light_call_min.y, light_call_min.z =
					box_min_x, box_min_y, box_min_z
				light_call_max.x, light_call_max.y, light_call_max.z =
					box_max_x, box_max_y, box_max_z
				ok = pcall(vm.calc_lighting, vm, light_call_min, light_call_max, true)
				if not ok then fail("fail_vm_contract", "calc_lighting failed") end
				local returned
				ok, returned = pcall(vm.get_light_data, vm, transaction_state.final_light)
				if not ok or not rawequal(returned, transaction_state.final_light) then
					fail("fail_vm_contract", "post-light buffer differs")
				end
				for index = 1, volume do
					integer(transaction_state.final_light[index], "final VM light", 0, 255,
						"fail_vm_contract")
				end
				local owner_min_x, owner_min_y, owner_min_z = math.max(box_min_x, min_x),
					math.max(box_min_y, min_y), math.max(box_min_z, min_z)
				local owner_max_x, owner_max_y, owner_max_z = math.min(box_max_x, max_x),
					math.min(box_max_y, max_y), math.min(box_max_z, max_z)
				for z = eminz, emaxz do
					for y = eminy, emaxy do
						for x = eminx, emaxx do
							if x < owner_min_x or x > owner_max_x or y < owner_min_y or
									y > owner_max_y or z < owner_min_z or z > owner_max_z then
								local index = index_at(x, y, z)
								transaction_state.final_light[index] = original_light[index]
							end
						end
					end
				end
				ok = pcall(vm.set_light_data, vm, transaction_state.final_light)
				if not ok then fail("fail_vm_contract", "set_light_data failed") end
			end
			if liquid_changed then
				local ok = pcall(vm.update_liquids, vm)
				if not ok then fail("fail_vm_contract", "update_liquids failed") end
			end
			metrics_state.apply_calls = metrics_state.apply_calls + 1
			local c, p, l, q = content_changed, param2_changed, light_changed,
				liquid_changed
			if not c then return q and "applied_pq" or "applied_p" end
			if p then
				if l then return q and "applied_cplq" or "applied_cpl" end
				return q and "applied_cpq" or "applied_cp"
			end
			if l then return q and "applied_clq" or "applied_cl" end
			return q and "applied_cq" or "applied_c"
		end

		local settlement = {}
		function settlement.apply(self, vm, minp, maxp, plan, generation, call_mode)
			if not rawequal(self, settlement) then
				fail("fail_status", "settlement receiver differs")
			end
			if evidence_only then fail("fail_status", "evidence fixture has no VM writer") end
			allocator:enter_hotpath("r6_settlement_apply")
			local ok, result = pcall(apply_impl, vm, minp, maxp, plan, generation,
				call_mode)
			allocator:leave_hotpath("r6_settlement_apply")
			if not ok then error(result, 0) end
			return result
		end
		function settlement.metrics(self)
			if not rawequal(self, settlement) then
				fail("fail_status", "settlement receiver differs")
			end
			local result = copy_map(metrics_state)
			local allocation = allocator:metrics()
			result.retained_buffer_growth_events = allocation.hotpath_table_allocations
			result.allocator_sealed = allocation.construction_sealed
			return result
		end
		local fixture = {}
		function fixture.last_ledger()
			if not last_ledger then return nil end
			local result = copy_map(last_ledger)
			last_ledger = false
			return result
		end
		function fixture.last_light_seed_runs()
			return last_light_seed_runs
		end
		function fixture.run_values()
			local result = {}
			local count = last_run_count
			for index = 1, count * RUN_STRIDE do result[index] = run_values[index] end
			return result, count
		end
		function fixture.scan_census_cube(record)
			return copy_map(scan_census_cube(record))
		end
		function fixture.scan_horizontal_owner(owner_x, owner_z,
				cultural_candidates, decoration_candidates)
			return copy_map(scan_horizontal_owner(owner_x, owner_z,
				cultural_candidates, decoration_candidates))
		end
		local capture_state = transaction_state.private_capture
		if capture_state then
			function fixture.arm_private_capture()
				if capture_state.armed or capture_state.value then
					fail("fail_ledger", "private capture is already armed or pending")
				end
				capture_state.armed = true
			end
			function fixture.take_private_capture()
				if capture_state.armed or not capture_state.value then
					fail("fail_ledger", "private capture is not ready")
				end
				local result = capture_state.value
				capture_state.value = false
				return result
			end
		end
		allocator:seal_construction()
		return settlement, fixture
	end

	return {new = function(dependencies) return new(dependencies, nil, nil) end,
		new_evidence = function(dependencies) return new(dependencies, true, nil) end,
		new_capture = function(dependencies) return new(dependencies, nil, true) end}
end

return settlement_factory()
