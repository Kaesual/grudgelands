-- Bounded Gravewood integration through production R6 templates and writer.

return function(repo, production_repo, verify_compressed)
	production_repo = production_repo or repo
	local function check(value, message)
		if not value then error("gravewood writer fixture: " .. message, 0) end
		return value
	end
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local wp40 = production_repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local hash = dofile(wp40 .. "/r6_hash.lua")(raw_sha256)
	local templates_factory = dofile(wp40 .. "/r6_templates.lua")
	local settlement_factory = dofile(wp40 .. "/r6_settlement.lua")
	local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	local decoded = dofile(repo .. "/tools/wp40/quality/gravewood_decoded.lua")
	local _, portable = dofile(repo .. "/tools/wp40/quality/gravewood_fixture.lua")(
		repo, verify_compressed, production_repo)
	-- surface_fixture builds the actual production catalog with a header-only
	-- MTS reader, so this catalog seam remains executable without zlib FFI.
	local _, actual_content = dofile(production_repo ..
		"/tools/wp40/quality/surface_fixture.lua")(production_repo)
	local actual_by_id = {}
	for _, definition in ipairs(actual_content.decorations()) do
		actual_by_id[definition.id] = definition
	end
	local definitions = {check(actual_by_id["blight_gravewood"],
		"production small row missing"),
		check(actual_by_id["bone_forest_gravewood"], "production tall row missing")}
	local reader
	if verify_compressed then
		reader = common.read_mts
	else
		reader = function(path)
			return check(portable[path:match("([^/]+)$")], "portable schematic missing")
		end
	end
	local template_source = dofile(wp40 .. "/r7_template_source.lua")(
		{read_schematic = reader},
		production_repo .. "/mods/BASE/default/schematics",
		production_repo .. "/mods/ITEMS/grug_trees/schematics")
	local contract = actual_content.content_contract()
	contract.classify_runtime = contract.classify_runtime or contract.classify
	local surface = {id = "gravewood_fixture", top = definitions[1].host,
		filler = definitions[1].host, filler_depth = 1, shore = definitions[1].host,
		bed = definitions[1].host, dust = definitions[1].host,
		top_ref = actual_content.content_ref(definitions[1].host),
		filler_ref = actual_content.content_ref(definitions[1].host),
		shore_ref = actual_content.content_ref(definitions[1].host),
		bed_ref = actual_content.content_ref(definitions[1].host), dust_ref = 0}
	local surface2 = {id = "gravewood_fixture_bone", top = definitions[2].host,
		filler = definitions[2].host, filler_depth = 1, shore = definitions[2].host,
		bed = definitions[2].host, dust = definitions[2].host,
		top_ref = actual_content.content_ref(definitions[2].host),
		filler_ref = actual_content.content_ref(definitions[2].host),
		shore_ref = actual_content.content_ref(definitions[2].host),
		bed_ref = actual_content.content_ref(definitions[2].host), dust_ref = 0}
	local content = {}
	function content.content_contract() return contract end
	function content.surfaces() return {surface, surface2} end
	function content.new_surface_selector()
		return function(id) return id == surface2.id and surface2 or surface end
	end
	function content.resources() return {} end
	function content.cultural() return {} end
	function content.decorations() return definitions end
	function content.decoration_cover() return 1 end
	function content.content_ref(name) return actual_content.content_ref(name) end
	function content.param2_kind(...) return actual_content.param2_kind(...) end
	function content.wp43_projection()
		local tiers = {}
		for index = 1, 6 do tiers[index] = {y_min = -index * 100,
			node = definitions[1].host} end
		return {tiers = tiers, race_regions = {}}
	end
	local templates = templates_factory(hash, content, template_source)
	for _, definition in ipairs(definitions) do
		check(definition.kind == "template" and definition.settlement_class == 1,
			"production Gravewood row is not class-1 template")
		for rotation = 0, 3 do
			local shape = templates.rotation(definition.id, rotation)
			check(shape.size_x == 7 and shape.size_z == 7,
				"actual R6 template footprint differs")
		end
	end
	local names = {definitions[1].host, "grug_trees:gravewood_tree",
		"grug_trees:gravewood_leaves"}
	local cids = {
		contract.content_cids[content.content_ref(definitions[1].host)],
		contract.content_cids[content.content_ref(names[2])],
		contract.content_cids[content.content_ref(names[3])],
	}

	local planner_source = {column_values_at = function(_, z)
		return "land", 1, "fixture", z > 0 and surface2.id or surface.id, "none", 4,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
	end, surface_cave_run_at = function() return nil end,
		surface_cave_candidate_at_cell = function() return nil end,
		surface_cave_cell_at = function() return 0, 0 end,
		coast_profile_at = function() return nil end,
		landmark_excluded_at = function() return false end}
	local horizontal = {static_exclusion_values_at = function() return nil end,
		housing_mask_id_at = function() return nil end}
	local anchor = {id = "gravewood_anchor", position = {x = 10000, z = 10000}}
	local source = {claim_exclusions = {}, routes = {}, hard_protection = {},
		anchors = {anchor}, apex_sockets = {}, hydrology_profiles = {}, hydrology = {},
		hydrology_interfaces = {}}
	for index = 1, 24 do source.apex_sockets[index] = {id = "socket_" .. index,
		anchor_id = anchor.id, offset = {x = index, z = 0}} end
	local allocator = {new_array = function() return {} end,
		new_map = function() return {} end, seal_construction = function() end,
		enter_hotpath = function() end, leave_hotpath = function() end,
		metrics = function() return {hotpath_table_allocations = 0,
			construction_sealed = true} end}
	function allocator.grow(_, values, _, old_size, new_size)
		for index = old_size + 1, new_size do values[index] = 0 end
	end
	function allocator.map_put(_, values, _, key_value, value) values[key_value] = value end
	local roots = {}
	for catalog = 1, 2 do
		for rotation = 0, 3 do
			local found
			local base_x, base_z = -27 + rotation * 18, catalog == 1 and -16 or 34
			for z = base_z, base_z + 8 do
				for x = base_x, base_x + 5 do
					local actual = math.floor(string.byte(hash.digest(
						"decoration_rotation_v1", "0",
						{definitions[catalog].id, x, 5, z}), 1) / 64)
					if actual == rotation then found = {catalog = catalog, rotation = rotation,
						x = x, y = 5, z = z}; break end
				end
				if found then break end
			end
			roots[#roots + 1] = check(found, "rotation witness missing")
		end
	end
	local r5_adapter = {apply = function(_, shadow)
		local data, minp, maxp = {}, shadow:get_emerged_area()
		shadow:get_data(data)
		minp, maxp = shadow:get_emerged_area()
		local ex, ey = maxp.x - minp.x + 1, maxp.y - minp.y + 1
		for _, root in ipairs(roots) do
			local index = (root.z - minp.z) * ex * ey + (4 - minp.y) * ex +
				(root.x - minp.x) + 1
			local host_ref = content.content_ref(definitions[root.catalog].host)
			data[index] = contract.content_cids[host_ref]
		end
		shadow:set_data(data)
		return "gravewood_r5_ready"
	end}
	local stable_refs = {definitions[1].id, definitions[2].id}
	table.sort(stable_refs, hash.less_bytes)
	local identity = {value = {}}
	local settlement, settlement_fixture = settlement_factory.new({full_seed_string = "0",
		r5_adapter = r5_adapter, content = content, templates = templates, hash = hash,
		horizontal = horizontal, planner_source = planner_source,
		construction_identity = identity, cultural_registrations = {}, source = source,
		planner_stable_refs = stable_refs, counting_allocator = allocator})
	local minp, maxp = {x = -32, y = 0, z = -32}, {x = 47, y = 31, z = 47}
	local column_values, column_start, run_values = {}, {}, {}
	for column = 1, 6400 do
		local cb, rb = (column - 1) * 12, (column - 1) * 9
		for field = 1, 12 do column_values[cb + field] = 0 end
		column_start[column] = column
		run_values[rb + 1], run_values[rb + 2] = 4, 4
		run_values[rb + 3], run_values[rb + 4] = 7, 28
		for field = 5, 9 do run_values[rb + field] = 0 end
	end
	column_start[6401] = 6401
	local candidate_values = {}
	for index, root in ipairs(roots) do
		local column = (root.z - minp.z) * 80 + (root.x - minp.x) + 1
		local cb = (column - 1) * 12
		local host_ref = content.content_ref(definitions[root.catalog].host)
		column_values[cb + 5], column_values[cb + 7], column_values[cb + 8] =
			4, 1, host_ref
		local base = (index - 1) * 14
		candidate_values[base + 1], candidate_values[base + 2] = 2, root.catalog
		candidate_values[base + 3], candidate_values[base + 4] = 1, root.x
		candidate_values[base + 5], candidate_values[base + 6] = root.y, root.z
		for field = 7, 14 do candidate_values[base + field] = 0 end
	end
	local candidate_cells = {}
	for index, root in ipairs(roots) do
		local base = (index - 1) * 4
		candidate_cells[base + 1] = math.floor(root.x / 16)
		candidate_cells[base + 2] = math.floor(root.z / 16)
		candidate_cells[base + 3], candidate_cells[base + 4] = index, index + 1
	end
	local plan = {schema = "grug_wp40_r6_refinement_plan_v1",
		construction_identity = identity.value, generation = 1, valid = true,
		min_x = minp.x, min_y = minp.y, min_z = minp.z,
		max_x = maxp.x, max_y = maxp.y, max_z = maxp.z,
		r5_plan = {column_start = column_start, run_values = run_values},
		r5_generation = 1, column_values = column_values, column_count = 6400,
		candidate_cell_values = candidate_cells, candidate_cell_count = #roots,
		candidate_values = candidate_values, candidate_count = #roots,
		stable_refs = stable_refs}
	local function filled(count, value)
		local result = {}; for index = 1, count do result[index] = value end; return result
	end
	local volume = 112 * 64 * 112
	local blocked
	do
		local root, definition = roots[1], definitions[roots[1].catalog]
		local shape = templates.rotation_runtime(definition.id, root.rotation)
		for z = 1, shape.size_z do for y = 1, shape.size_y do
			for x = 1, shape.size_x do
				local cell = shape.cells[(z - 1) * shape.size_x * shape.size_y +
					(y - 1) * shape.size_x + x]
				if not blocked and cell.name == names[3] and
						templates.probability_include("0", definition.id, root.x, root.y,
							root.z, root.rotation, "node", x - 1, y - 1, z - 1,
							cell.probability) then
					blocked = {x = root.x + shape.min_x + x - 1,
						y = root.y + shape.min_y + y - 1,
						z = root.z + shape.min_z + z - 1}
				end
			end
		end end
	end
	check(blocked, "included leaf witness missing")
	local emerged_min = {x = minp.x - 16, y = minp.y - 16, z = minp.z - 16}
	local blocked_index = (blocked.z - emerged_min.z) * 112 * 64 +
		(blocked.y - emerged_min.y) * 112 + (blocked.x - emerged_min.x) + 1
	local blocked_cid = contract.content_cids[content.content_ref(definitions[1].host)]
	local native_data = filled(volume, 0)
	for z = minp.z, maxp.z do
		for y = 1, 3 do
			for x = minp.x, maxp.x do
				native_data[(z + 48) * 112 * 64 + (y + 16) * 112 + x + 49] = cids[1]
			end
		end
	end
	local vm, _, observer = vm_module.new({minp = minp, maxp = maxp,
		data = native_data, param2 = filled(volume, 0), light = filled(volume, 0),
		heightmap = filled(6400, -31007), content_contract = contract, water_level = 1,
		ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
	local result = settlement:apply(vm, minp, maxp, plan, 1, "fixture")
	check(result:match("^applied_[cplq]+$") ~= nil, "settlement result differs")
	local ledger = settlement_fixture.last_ledger()
	for _, definition in ipairs(definitions) do
		local aggregate = ledger.decorations[definition.id]
		local rejection_rows = {}
		for key_value, count in pairs(ledger.rejections) do
			if key_value:find(definition.id, 1, true) then
				rejection_rows[#rejection_rows + 1] = common.hex(key_value) .. "=" .. count
			end
		end
		check(aggregate and aggregate.accepted == 4,
			"rotation candidates not all accepted: " .. definition.id .. "/" ..
			tostring(aggregate and aggregate.accepted) .. "/" ..
			table.concat(rejection_rows, ","))
	end
	local snapshot = observer.snapshot()
	local ex, ey = snapshot.emax.x - snapshot.emin.x + 1,
		snapshot.emax.y - snapshot.emin.y + 1
	local function cid_at(x, y, z)
		return snapshot.data[(z - snapshot.emin.z) * ex * ey +
			(y - snapshot.emin.y) * ex + (x - snapshot.emin.x) + 1]
	end
	local leaf_written = 0
	for _, root in ipairs(roots) do
		local definition = definitions[root.catalog]
		local shape = templates.rotation_runtime(definition.id, root.rotation)
		local written_wood = {}
		for z = 1, shape.size_z do for y = 1, shape.size_y do
			for x = 1, shape.size_x do
				local cell = shape.cells[(z - 1) * shape.size_x * shape.size_y +
					(y - 1) * shape.size_x + x]
				local wx, wy, wz = root.x + shape.min_x + x - 1,
					root.y + shape.min_y + y - 1, root.z + shape.min_z + z - 1
				if cell.name == names[2] then
					check(cell.probability == 254 and cid_at(wx, wy, wz) == cids[2],
						"mandatory wood was not written: " .. definition.id .. "/" ..
						root.rotation .. "/" .. wx .. "/" .. wy .. "/" .. wz ..
						" actual=" .. tostring(cid_at(wx, wy, wz)) ..
						" expected=" .. tostring(cids[2]))
					written_wood[wx .. ":" .. wy .. ":" .. wz] = true
				elseif cell.name == names[3] then
					local included = templates.probability_include("0", definition.id,
						root.x, root.y, root.z, root.rotation, "node",
						x - 1, y - 1, z - 1, cell.probability)
					check((cid_at(wx, wy, wz) == cids[3]) == included,
						"optional leaf decision differs")
					if included then leaf_written = leaf_written + 1 end
				end
			end
		end end
		local root_key = root.x .. ":" .. root.y .. ":" .. root.z
		check(written_wood[root_key], "written template lost mandatory root wood")
		local reached = {[root_key] = true}
		local changed = true
		while changed do
			changed = false
			for position in pairs(written_wood) do if not reached[position] then
				local x, y, z = position:match("^(-?%d+):(-?%d+):(-?%d+)$")
				x, y, z = tonumber(x), tonumber(y), tonumber(z)
				if reached[(x+1)..":"..y..":"..z] or reached[(x-1)..":"..y..":"..z]
					or reached[x..":"..(y+1)..":"..z] or reached[x..":"..(y-1)..":"..z]
					or reached[x..":"..y..":"..(z+1)] or reached[x..":"..y..":"..(z-1)] then
					reached[position], changed = true, true
				end
			end end
		end
		for position in pairs(written_wood) do
			check(reached[position], "written wood disconnected")
		end
	end
	-- A separate one-candidate transaction proves the writer's conservative
	-- preflight rejects an occupied destination and preserves its old content.
	local blocked_data = filled(volume, 0)
	blocked_data[blocked_index] = blocked_cid
	local blocked_vm, _, blocked_observer = vm_module.new({minp = minp, maxp = maxp,
		data = blocked_data, param2 = filled(volume, 0), light = filled(volume, 0),
		heightmap = filled(6400, -31007), content_contract = contract, water_level = 1,
		ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
	local blocked_values = {}
	for index = 1, 14 do blocked_values[index] = candidate_values[index] end
	local blocked_root = roots[1]
	local blocked_plan = {schema = plan.schema,
		construction_identity = plan.construction_identity, generation = plan.generation,
		valid = true, min_x = plan.min_x, min_y = plan.min_y, min_z = plan.min_z,
		max_x = plan.max_x, max_y = plan.max_y, max_z = plan.max_z,
		r5_plan = plan.r5_plan, r5_generation = plan.r5_generation,
		column_values = plan.column_values, column_count = plan.column_count,
		candidate_cell_values = {math.floor(blocked_root.x / 16),
			math.floor(blocked_root.z / 16), 1, 2}, candidate_cell_count = 1,
		candidate_values = blocked_values, candidate_count = 1,
		stable_refs = plan.stable_refs}
	settlement:apply(blocked_vm, minp, maxp, blocked_plan, 1, "fixture")
	check(blocked_observer.snapshot().data[blocked_index] == blocked_cid,
		"occupied destination was overwritten")
	-- The opening transaction uses the real writer with a 3x3 native-air band.
	-- R5 first places the exact surface host at T=4; the R9 opening must replace
	-- that predecessor intent with air rather than merely skipping P7 and skin.
	local opening_columns = {}
	for index = 1, 6400 * 12 do opening_columns[index] = 0 end
	for column = 1, 6400 do
		local base = (column - 1) * 12
		opening_columns[base + 5], opening_columns[base + 7],
			opening_columns[base + 8] = 4, 1,
			content.content_ref(definitions[1].host)
	end
	local opening_plan = {schema = plan.schema,
		construction_identity = plan.construction_identity, generation = plan.generation,
		valid = true, min_x = plan.min_x, min_y = plan.min_y, min_z = plan.min_z,
		max_x = plan.max_x, max_y = plan.max_y, max_z = plan.max_z,
		r5_plan = plan.r5_plan, r5_generation = plan.r5_generation,
		column_values = opening_columns, column_count = plan.column_count,
		candidate_cell_values = {}, candidate_cell_count = 0,
		candidate_values = {}, candidate_count = 0, stable_refs = plan.stable_refs}
	local opening_vm, _, opening_observer = vm_module.new({minp = minp, maxp = maxp,
		data = filled(volume, 0), param2 = filled(volume, 0), light = filled(volume, 0),
		heightmap = filled(6400, -31007), content_contract = contract, water_level = 1,
		ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
	settlement:apply(opening_vm, minp, maxp, opening_plan, 1, "fixture")
	local opening_snapshot = opening_observer.snapshot()
	local opening_root = roots[1]
	local opening_index = (opening_root.z - opening_snapshot.emin.z) * 112 * 64 +
		(4 - opening_snapshot.emin.y) * 112 +
		(opening_root.x - opening_snapshot.emin.x) + 1
	check(opening_snapshot.data[opening_index] == 0,
		"surface opening retained the R5 solid node at T")
	local rows = {"schema\tgrug_wp40_gravewood_writer_v1",
		"templates\t2\tclass=1", "rotations\t8\tmandatory_wood=pass",
		"opening_surface\tair_at_t=pass",
		"writer\t" .. result .. "\toptional_leaves=" .. leaf_written ..
			"\tnonoverwrite=pass"}
	local bytes = table.concat(rows, "\n") .. "\n"
	return bytes .. "digest\t" .. common.hex(raw_sha256(bytes)) .. "\n"
end
