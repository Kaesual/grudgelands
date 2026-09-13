-- Bounded Gravewood integration through production R6 templates and writer.

return function(repo, production_repo)
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
	-- Verify the post-insertion production catalog and actual compressed assets
	-- through the same R6 template constructor before using the reduced writer
	-- harness below.
	local fixtures = dofile(production_repo .. "/tools/wp40/r6/fixtures.lua")(
		production_repo, common, raw_sha256)
	local actual_content = dofile(wp40 .. "/r6_content.lua")(
		fixtures.r6_manifest(), fixtures.new_content_contract(), fixtures.projection())
	local actual_by_id = {}
	for _, definition in ipairs(actual_content.decorations()) do
		actual_by_id[definition.id] = definition
	end
	local actual_source = dofile(wp40 .. "/r7_template_source.lua")(
		{read_schematic = common.read_mts},
		production_repo .. "/mods/BASE/default/schematics",
		production_repo .. "/mods/ITEMS/grug_trees/schematics")
	local actual_templates = templates_factory(hash, actual_content, actual_source)
	for _, id in ipairs({"blight_gravewood", "bone_forest_gravewood"}) do
		local definition = check(actual_by_id[id], "production catalog row missing")
		check(definition.kind == "template" and definition.settlement_class == 1,
			"production Gravewood row is not class-1 template")
		for rotation = 0, 3 do
			local shape = actual_templates.rotation(id, rotation)
			check(shape.size_x == 7 and shape.size_z == 7,
				"actual R6 template footprint differs")
		end
	end
	local names = {"test:soil", "grug_trees:gravewood_tree",
		"grug_trees:gravewood_leaves"}
	local cids, refs = {100, 101, 102}, {}
	for index = 1, #names do refs[names[index]] = index end
	local contract = {schema = "grug_wp40_r6_content_contract_v1",
		ignore_cid = 65535, ordinary_water_family_id = 1,
		river_water_family_id = 2, content_names = names, content_cids = cids,
		content_kind_masks = {9, 8, 8}, r5 = {}}
	function contract.r5.resolve(role, _, auxiliary)
		check(auxiliary == 0, "R5 auxiliary differs")
		if role == 1 then return 0, 0, 0, nil end
		if role == 10 or role == 13 then return 10, 2, 0, nil end
		return cids[1], 1, 0, nil
	end
	function contract.resolve_r6(content_ref, param2)
		return cids[content_ref], 1, 1, param2, contract.content_kind_masks[content_ref]
	end
	local function classify(cid)
		if cid == 0 then return 1, 0, 0, 0, true, true, true, true, 0 end
		if cid == 10 then return 4, 1, 1, 0, false, true, true, true, 0 end
		if cid == 65535 then return 3, 0, 0, 0, false, false, false, false, 0 end
		if cid == cids[1] then return 7, 0, 0, 0, false, false, false, false, 0 end
		if cid == cids[2] or cid == cids[3] then
			return 6, 0, 0, 0, false, false, false, false, 0
		end
		return 9, 0, 0, 0, false, false, false, false, 0
	end
	contract.classify, contract.classify_runtime = classify, classify
	local surface = {id = "gravewood_fixture", top = names[1], filler = names[1],
		filler_depth = 1, shore = names[1], bed = names[1], dust = names[1],
		top_ref = 1, filler_ref = 1, shore_ref = 1, bed_ref = 1, dust_ref = 0}
	local definitions = {
		{id = "blight_gravewood", biomes = {surface.id}, kind = "template",
			asset_or_node = decoded[1].filename, host = names[1], numerator = 1,
			denominator = 1, rule = "center_xz;quarter_turn_rotation",
			settlement_class = 1},
		{id = "bone_forest_gravewood", biomes = {surface.id}, kind = "template",
			asset_or_node = decoded[2].filename, host = names[1], numerator = 1,
			denominator = 1, rule = "center_xz;quarter_turn_rotation",
			settlement_class = 1},
	}
	local content = {}
	function content.content_contract() return contract end
	function content.surfaces() return {surface} end
	function content.new_surface_selector() return function() return surface end end
	function content.resources() return {} end
	function content.cultural() return {} end
	function content.decorations() return definitions end
	function content.decoration_cover() return 1 end
	function content.content_ref(name) return refs[name] end
	function content.param2_kind() return "none" end
	function content.wp43_projection()
		local tiers = {}
		for index = 1, 6 do tiers[index] = {y_min = -index * 100, node = names[1]} end
		return {tiers = tiers, race_regions = {}}
	end
	local function schematic(definition)
		local size, cells = definition.size, {}
		for index = 1, size.x * size.y * size.z do
			cells[index] = {name = "air", prob = 0, param2 = 0, force_place = false}
		end
		local function put(list, name, probability)
			for _, pos in ipairs(list) do
				local index = (pos[3] + 3) * size.x * size.y + pos[2] * size.x +
					(pos[1] + 3) + 1
				cells[index] = {name = name, prob = probability, param2 = 0,
					force_place = false}
			end
		end
		put(definition.wood, names[2], 254)
		put(definition.leaves, names[3], 96)
		local slices = {}
		for y = 0, size.y - 1 do slices[y + 1] = {ypos = y, prob = 254} end
		return {size = size, yslice_prob = slices, data = cells}
	end
	local sources = {[decoded[1].filename] = schematic(decoded[1]),
		[decoded[2].filename] = schematic(decoded[2])}
	local template_source = {read = function(filename)
		return check(sources[filename], "unexpected template source")
	end}
	local templates = templates_factory(hash, content, template_source)
	for _, definition in ipairs(definitions) do
		check(definition.settlement_class == 1, "Gravewood is not large-template class")
		for rotation = 0, 3 do
			local shape = templates.rotation(definition.id, rotation)
			check(shape.size_x == 7 and shape.size_z == 7,
				"rotated footprint differs")
		end
	end

	local planner_source = {column_values_at = function()
		return "land", 1, "fixture", surface.id, "none", 4,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
	end, surface_cave_run_at = function() return nil end}
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
			local base_x, base_z = -26 + rotation * 17, catalog == 1 and -16 or 17
			for z = base_z, base_z + 8 do
				for x = base_x, base_x + 12 do
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
			data[index] = cids[1]
		end
		shadow:set_data(data)
		return "gravewood_r5_ready"
	end}
	local stable_refs = {definitions[1].id, definitions[2].id}
	table.sort(stable_refs, hash.less_bytes)
	local identity = {value = {}}
	local settlement = settlement_factory.new_runtime({full_seed_string = "0",
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
		column_values[cb + 5], column_values[cb + 7], column_values[cb + 8] = 4, 1, 1
		local base = (index - 1) * 14
		candidate_values[base + 1], candidate_values[base + 2] = 2, root.catalog
		candidate_values[base + 3], candidate_values[base + 4] = 1, root.x
		candidate_values[base + 5], candidate_values[base + 6] = root.y, root.z
		for field = 7, 14 do candidate_values[base + field] = 0 end
	end
	local plan = {schema = "grug_wp40_r6_refinement_plan_v1",
		construction_identity = identity.value, generation = 1, valid = true,
		min_x = minp.x, min_y = minp.y, min_z = minp.z,
		max_x = maxp.x, max_y = maxp.y, max_z = maxp.z,
		r5_plan = {column_start = column_start, run_values = run_values},
		r5_generation = 1, column_values = column_values, column_count = 6400,
		candidate_cell_values = {-2, -2, 1, #roots + 1}, candidate_cell_count = 1,
		candidate_values = candidate_values, candidate_count = #roots,
		stable_refs = stable_refs}
	local function filled(count, value)
		local result = {}; for index = 1, count do result[index] = value end; return result
	end
	local volume = 112 * 64 * 112
	local vm, _, observer = vm_module.new({minp = minp, maxp = maxp,
		data = filled(volume, 0), param2 = filled(volume, 0), light = filled(volume, 0),
		heightmap = filled(6400, -31007), content_contract = contract, water_level = 1,
		ignore_cid = contract.ignore_cid, verify_inactive_tail = false})
	local result = settlement:apply(vm, minp, maxp, plan, 1, "fixture")
	check(result:match("^applied_[cplq]+$") ~= nil, "settlement result differs")
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
						"mandatory wood was not written")
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
	local rows = {"schema\tgrug_wp40_gravewood_writer_v1",
		"templates\t2\tclass=1", "rotations\t8\tmandatory_wood=pass",
		"writer\t" .. result .. "\toptional_leaves=" .. leaf_written}
	local bytes = table.concat(rows, "\n") .. "\n"
	return bytes .. "digest\t" .. common.hex(raw_sha256(bytes)) .. "\n"
end
