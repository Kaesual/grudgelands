-- Compact production-settlement fixture for the final R6 LuaJIT/PUC KAT.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local hash = dofile(directory .. "/r6_hash.lua")(raw_sha256)
	local settlement_factory = dofile(directory .. "/r6_settlement.lua")
	local allocator_factory = dofile(directory .. "/counting_allocator.lua")
	local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	local rows = {}
	local function fail(message) error("r6 micro KAT: " .. message, 0) end
	local function check(value, message)
		if not value then fail(message) end
		return value
	end
	local function row(id, value)
		rows[#rows + 1] = id .. "\t" .. tostring(value) .. "\n"
	end
	local function display_key(key)
		local parts, first = {}, 1
		while true do
			local delimiter = key:find("\0", first, true)
			if not delimiter then
				parts[#parts + 1] = key:sub(first)
				return table.concat(parts, "/")
			end
			parts[#parts + 1] = key:sub(first, delimiter - 1)
			first = delimiter + 1
		end
	end
	local function fixed_array(count, value)
		local result = {}
		for index = 1, count do result[index] = value end
		return result
	end
	local function owner_minimum(value)
		return -30912 + math.floor((value + 30912) / 80) * 80
	end
	local function vm_arrays(minp, maxp, fill_cid)
		local ex, ey, ez = maxp.x - minp.x + 33, maxp.y - minp.y + 33,
			maxp.z - minp.z + 33
		local volume = ex * ey * ez
		local data, param2, light = fixed_array(volume, fill_cid),
			fixed_array(volume, 0), fixed_array(volume, 0)
		local emin = {x = minp.x - 16, y = minp.y - 16, z = minp.z - 16}
		local function index_at(x, y, z)
			return (z - emin.z) * ex * ey + (y - emin.y) * ex + (x - emin.x) + 1
		end
		return data, param2, light, index_at
	end
	local function clone(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[clone(key)] = clone(child) end
		return result
	end
	local names = {"kat:top", "kat:filler", "kat:shore", "kat:bed",
		"kat:dust", "kat:ore_a", "kat:ore_b", "kat:ore_c", "kat:template",
		"kat:tall", "kat:simple", "kat:tier5", "kat:tier6", "kat:tier1"}
	local cids, masks, refs, classes, param2_kinds = {}, {}, {}, {}, {}
	for index = 1, #names do
		refs[names[index]], cids[index] = index, 100 + index
		masks[index] = index <= 4 and 1 or (index == 5 and 2 or
			(index <= 8 and 4 or (index <= 11 and 8 or 1)))
		classes[cids[index]] = index <= 4 and 7 or (index == 5 and 8 or
			(index <= 8 and 10 or (index <= 11 and 8 or 11)))
		param2_kinds[index] = index == 9 and "facedir" or "none"
	end
	classes[0], classes[10], classes[65535] = 1, 4, 3
	local cid_by_name = {air = 0, ["default:water_source"] = 10}
	for index = 1, #names do cid_by_name[names[index]] = cids[index] end
	local contract = {schema = "grug_wp40_r6_content_contract_v1",
		ignore_cid = 65535, ordinary_water_family_id = 1,
		river_water_family_id = 2, content_names = names,
		content_cids = cids, content_kind_masks = masks}
	contract.r5 = {}
	function contract.r5.resolve(role, _, aux)
		if aux ~= 0 or role < 1 or role > 16 then
			fail("micro R5 resolver input differs")
		end
		if role == 1 then return 0, 0, 0, nil end
		if role == 10 or role == 13 then return 10, 2, 0, nil end
		return cids[14], 1, 0, nil
	end
	function contract.resolve_r6(content_ref, param2)
		return cids[content_ref], 1, 1, param2, masks[content_ref]
	end
	function contract.classify(cid)
		local class = classes[cid] or 9
		if class == 4 then return 4, 1, 1, 0, false, true, true, true, 0, "none" end
		local content_ref
		for index = 1, #cids do
			if cids[index] == cid then content_ref = index break end
		end
		return class, 0, 0, 0, class == 1 or class == 8, class == 1,
			class == 1, class == 1, 0, param2_kinds[content_ref] or "none"
	end
	local surfaces = {{id = "kat_biome", top = names[1], filler = names[2],
		filler_depth = 1, shore = names[3], bed = names[4], dust = names[5],
		top_ref = 1, filler_ref = 2, shore_ref = 3, bed_ref = 4, dust_ref = 5}}
	local kat_resources = {}
	for index = 1, 3 do
		local denominators = {false, false, false, false, false, 1}
		if index == 1 then denominators[6] = false end
		kat_resources[index] = {key = "ore_" .. index, scope = "universal",
			first_tier = 6, denominators = denominators,
			max_nodes_per_vein = index == 2 and 1 or 2,
			deep_1500_1999_numerator = 5,
			deep_1500_1999_denominator = 4, deep_2000_floor_numerator = 3,
			deep_2000_floor_denominator = 2, node = names[5 + index],
			content_ref = 5 + index}
	end
	local cultural = {{race = "dwarf", key = "kat_cultural",
		ordinary_denominator = 4096, concentrated_denominator = 1024,
		biomes = {"kat_biome"}, concentrated_zone = "kat_zone"}}
	local decorations = {
		{id = "kat_large", biomes = {"kat_biome"}, kind = "template",
			asset_or_node = "kat_large.mts", host = names[1], numerator = 1,
			denominator = 1, rule = "center_xz", settlement_class = 1},
		{id = "kat_small", biomes = {"kat_biome"}, kind = "template",
			asset_or_node = "kat_small.mts", host = names[1], numerator = 1,
			denominator = 1, rule = "center_xz", settlement_class = 2},
		{id = "kat_tall", biomes = {"kat_biome"}, kind = "simple",
			asset_or_node = names[10], host = names[1], numerator = 1,
			denominator = 1, rule = "height_2_to_4_from_domain_hash",
			settlement_class = 3, content_ref = 10},
		{id = "kat_simple", biomes = {"kat_biome"}, kind = "simple",
			asset_or_node = names[11], host = names[1], numerator = 1,
			denominator = 1, rule = "none", settlement_class = 4, content_ref = 11},
	}
	local projection = {tiers = {
		{y_min = -100, node = names[14]}, {y_min = -300, node = names[14]},
		{y_min = -500, node = names[14]}, {y_min = -700, node = names[14]},
		{y_min = -1000, node = names[12]}, {y_min = -31000, node = names[13]},
	}, race_regions = {{race = "dwarf", g1 = "ore_1", g2 = "ore_2"}}}
	local content = {}
	function content.content_contract() return contract end
	function content.surfaces() return clone(surfaces) end
	function content.resources() return clone(kat_resources) end
	function content.cultural() return clone(cultural) end
	function content.decorations() return clone(decorations) end
	function content.wp43_projection() return clone(projection) end
	function content.content_ref(name) return refs[name] end
	function content.param2_kind(content_ref) return param2_kinds[content_ref] end
	local template_source = {}
	function template_source.read(filename)
		local size = filename == "kat_large.mts" and 6 or 3
		local data = {}
		for index = 1, size * size do
			data[index] = {name = names[9], prob = 254, param2 = 0,
				force_place = false}
		end
		return {size = {x = size, y = 1, z = size},
			yslice_prob = {{ypos = 0, prob = 254}}, data = data}
	end
	local templates = dofile(directory .. "/r6_templates.lua")(
		hash, content, template_source)
	local function rejected_template_kind(kind, param2)
		local probe_contract = {ignore_cid = 65535, content_cids = {9001},
			content_kind_masks = {8}}
		function probe_contract.resolve_r6(_, value) return 9001, 1, 1, value, 8 end
		local probe_content = {}
		function probe_content.content_contract() return probe_contract end
		function probe_content.decorations()
			return {{id = "probe", kind = "template", asset_or_node = "probe.mts",
				rule = "center_xz", settlement_class = 2}}
		end
		function probe_content.content_ref(name) return name == "kat:probe" and 1 or nil end
		function probe_content.param2_kind() return kind end
		local probe_source = {}
		function probe_source.read()
			return {size = {x = 1, y = 1, z = 1},
				yslice_prob = {{ypos = 0, prob = 254}},
				data = {{name = "kat:probe", prob = 254, param2 = param2,
					force_place = false}}}
		end
		local ok, message = pcall(dofile(directory .. "/r6_templates.lua"),
			hash, probe_content, probe_source)
		check(not ok and tostring(message):find("fail_template:", 1, true) == 1,
			"forbidden template kind did not fail closed")
		return tostring(message):match("^fail_template: ([^\n]+)$")
	end
	local function accepted_template_param2(kind, param2)
		local probe_contract = {ignore_cid = 65535, content_cids = {9001},
			content_kind_masks = {8}}
		function probe_contract.resolve_r6(_, value) return 9001, 1, 1, value, 8 end
		local probe_content = {}
		function probe_content.content_contract() return probe_contract end
		function probe_content.decorations()
			return {{id = "probe", kind = "template", asset_or_node = "probe.mts",
				rule = "center_xz", settlement_class = 2}}
		end
		function probe_content.content_ref(name) return name == "kat:probe" and 1 or nil end
		function probe_content.param2_kind() return kind end
		local probe_source = {}
		function probe_source.read()
			return {size = {x = 1, y = 1, z = 1},
				yslice_prob = {{ypos = 0, prob = 254}},
				data = {{name = "kat:probe", prob = 254, param2 = param2,
					force_place = false}}}
		end
		local probe = dofile(directory .. "/r6_templates.lua")(
			hash, probe_content, probe_source)
		local rotated = probe.rotation("probe", 1).cells[1].param2
		check(rotated == param2, "pass-through template param2 changed")
		return rotated
	end
	local kat_anchor = {id = "kat_apex", position = {x = 10000, z = 10000}}
	local kat_sockets, kat_hard = {}, {}
	for index = 1, 24 do
		local id = "kat_apex:socket_" .. string.format("%02d", index)
		kat_sockets[index] = {id = id, anchor_id = kat_anchor.id,
			species = "ore_1", offset = {x = index, z = 0}}
		kat_hard[index] = {id = "hard:" .. id, source_anchor_id = kat_anchor.id,
			socket_id = id, resource_key = "ore_1",
			recipe_id = "hard_apex_socket_column_v1", active = true,
			center = {x = 10000 + index, z = 10000}}
	end
	local source = {claim_exclusions = {}, routes = {}, hard_protection = kat_hard,
		anchors = {kat_anchor}, apex_sockets = kat_sockets,
		hydrology_profiles = {}, hydrology = {}, hydrology_interfaces = {}}

	row("schema", "grug_wp40_r6_micro_kat_v2")
	row("domain_population", #hash.domains())
	row("negative_frame", common.hex(hash.sha256_bytes(hash.frame(-42))))
	row("negative_owner", owner_minimum(-37))
	local reduction_vectors = {
		{"reduce_words/512/0/1000", 0, 1000, 512, 488},
		{"reduce_words/12000/1/0", 1, 0, 12000, 11296},
		{"reduce_words/12000/0/2147483648", 0, 2147483648, 12000, 11648},
		{"reduce_words/48000/4294967295/4294967295", 4294967295, 4294967295,
			48000, 15615},
	}
	for index = 1, #reduction_vectors do
		local vector = reduction_vectors[index]
		local reduced = hash.reduce_words(vector[2], vector[3], vector[4])
		check(reduced == vector[5], "mandatory reduction vector differs")
		row(vector[1], reduced)
	end
	local budget_rows = {
		{"ordinary_512", 512, 1, 1},
		{"deep_1500_1999_12000", 3000, 5, 4},
		{"deep_2000_floor_24000", 12000, 3, 2},
		{"remainder_48000", 12000, 5, 4},
	}
	for index = 1, #budget_rows do
		local item = budget_rows[index]
		local digest = hash.digest("resource_budget_remainder_v1", "42",
			{item[1], -2, -188, 7, "grug_materials:abyssal_rock", 6, item[1]})
		local budget, numerator, denominator, base, remainder =
			hash.budget(4096, 1, item[2], item[3], item[4], digest)
		check(denominator == item[2] * item[4],
			"remainder denominator differs for " .. item[1])
		row("budget/" .. item[1], table.concat({budget, numerator, denominator,
			base, remainder}, "/"))
	end

	local surface_id = surfaces[1].id
	local race = cultural[1].race
	local fake_source = {schema = "grug_wp40_r5_planner_source_v1",
		bridge_probe = false}
	function fake_source.column_values_at(x)
		if fake_source.bridge_probe and x == 1 then
			return "land", 1, "kat_zone", surface_id, race, 4, 1, nil, nil,
				"bridge_deck", 6, "kat_bridge", nil, nil, nil, nil, nil, nil, nil,
				false
		end
		return "land", 1, "kat_zone", surface_id, race, 4, nil, nil, nil,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
	end
	local horizontal = {}
	function horizontal.static_exclusion_values_at() return nil end
	local identity = {value = {}}
	local tier1_cid = cid_by_name[projection.tiers[1].node]
	local r5_adapter = {}
	function r5_adapter.apply(_, shadow, minp, maxp, plan)
		local data = {}
		shadow:get_data(data)
		local emerged_min, emerged_max = shadow:get_emerged_area()
		local ex, ey = emerged_max.x - emerged_min.x + 1,
			emerged_max.y - emerged_min.y + 1
		local function index_at(x, y, z)
			return (z - emerged_min.z) * ex * ey + (y - emerged_min.y) * ex +
				(x - emerged_min.x) + 1
		end
		local x_count = maxp.x - minp.x + 1
		for column = 1, plan.kat_column_count do
			local base = (column - 1) * 12
			if plan.kat_column_values[base + 9] ~= 0 and
					plan.kat_column_values[base + 11] > 0 then
				local offset = column - 1
				local x, z = minp.x + offset % x_count,
					minp.z + math.floor(offset / x_count)
				data[index_at(x, plan.kat_column_values[base + 5] - 1, z)] = tier1_cid
			end
		end
		shadow:set_data(data)
		return "kat_r5_ready"
	end
	local settlement, settlement_fixture = settlement_factory.new({
		full_seed_string = "0", r5_adapter = r5_adapter, content = content,
		templates = templates, hash = hash, horizontal = horizontal,
		planner_source = fake_source, construction_identity = identity,
		cultural_registrations = {}, source = source,
		counting_allocator = allocator_factory.new(
			"grug_wp40_r6_settlement_allocator_v1")})

	local stable_refs, stable_set = {}, {}
	local function add_stable(value)
		if not stable_set[value] then
			stable_set[value] = true
			stable_refs[#stable_refs + 1] = value
		end
	end
	for index = 1, #kat_resources do add_stable(kat_resources[index].key) end
	for index = 1, #cultural do add_stable(cultural[index].key) end
	for index = 1, #decorations do add_stable(decorations[index].id) end
	table.sort(stable_refs, hash.less_bytes)
	local generation = 0
	local function blank_plan(minp, maxp, with_predecessors)
		generation = generation + 1
		local column_count = (maxp.x - minp.x + 1) * (maxp.z - minp.z + 1)
		local column_values = fixed_array(column_count * 12, 0)
		local column_start, run_values = {}, {}
		if with_predecessors then
			for column = 1, column_count do
				local cbase, first = (column - 1) * 12, (column - 1) * 3 + 1
				column_values[cbase + 5] = 4
				column_start[column] = first
				for local_run = 0, 2 do
					local base = (first + local_run - 1) * 9
					run_values[base + 1], run_values[base + 2] = 3 + local_run, 3 + local_run
					run_values[base + 3], run_values[base + 4] = 7,
						local_run == 0 and 27 or (local_run == 1 and 28 or 26)
					for field = 5, 9 do run_values[base + field] = 0 end
				end
			end
			column_start[column_count + 1] = column_count * 3 + 1
		else
			for column = 1, column_count + 1 do column_start[column] = 1 end
		end
		return {
			schema = "grug_wp40_r6_refinement_plan_v1",
			construction_identity = identity.value, generation = generation, valid = true,
			min_x = minp.x, min_y = minp.y, min_z = minp.z,
			max_x = maxp.x, max_y = maxp.y, max_z = maxp.z,
			r5_plan = {column_start = column_start, run_values = run_values,
				kat_column_values = column_values, kat_column_count = column_count},
			r5_generation = generation, column_values = column_values,
			column_count = column_count, candidate_cell_values = fixed_array(4, 0),
			candidate_cell_count = 0, candidate_values = {}, candidate_count = 0,
			stable_refs = stable_refs,
		}
	end
	local function column_base(minp, x, z)
		return ((z - minp.z) * 80 + (x - minp.x)) * 12
	end
	local function support(plan, minp, x, z, content_ref, surface_kind, alternate_ref)
		local base = column_base(minp, x, z)
		plan.column_values[base + 7] = surface_kind or 1
		plan.column_values[base + 8] = content_ref
		plan.column_values[base + 10] = alternate_ref or 0
	end
	local function append_candidate(plan, kind, catalog, parameter, x, y, z)
		local index = plan.candidate_count + 1
		local base = (index - 1) * 14
		plan.candidate_values[base + 1], plan.candidate_values[base + 2] = kind, catalog
		plan.candidate_values[base + 3], plan.candidate_values[base + 4] = parameter, x
		plan.candidate_values[base + 5], plan.candidate_values[base + 6] = y, z
		for field = 7, 14 do plan.candidate_values[base + field] = 0 end
		plan.candidate_count = index
	end

	local class_catalog, template_class2 = {}, nil
	local smallest_class2 = math.huge
	for index = 1, #decorations do
		local definition = decorations[index]
		if not class_catalog[definition.settlement_class] then
			class_catalog[definition.settlement_class] = index
		end
		if definition.kind == "template" and definition.settlement_class == 2 then
			local shape = templates.rotation(definition.id, 0)
			local volume = shape.size_x * shape.size_y * shape.size_z
			if volume < smallest_class2 then
				smallest_class2, template_class2 = volume, index
			end
		end
	end
	for class = 1, 4 do check(class_catalog[class], "decoration class missing") end
	check(template_class2, "compact class-2 template missing")
	class_catalog[2] = template_class2

	local surface_min, surface_max = {x = -32, y = 0, z = -32},
		{x = 47, y = 31, z = 47}
	local plan = blank_plan(surface_min, surface_max, true)
	local rotation_roots = {}
	for rotation = 0, 3 do
		local found
		for z = -24 + rotation * 15, -15 + rotation * 15 do
			for x = -24, 36 do
				local definition = decorations[template_class2]
				local actual = math.floor(string.byte(hash.digest("decoration_rotation_v1",
					"0", {definition.id, x, 5, z}), 1) / 64)
				local shape = templates.rotation(definition.id, actual)
				if actual == rotation and x + shape.min_x >= surface_min.x and
						x + shape.max_x <= surface_max.x and z + shape.min_z >= surface_min.z and
						z + shape.max_z <= surface_max.z then
					found = {x = x, z = z}
					break
				end
			end
			if found then break end
		end
		rotation_roots[rotation] = check(found, "rotation root missing: " .. rotation)
		local definition = decorations[template_class2]
		support(plan, surface_min, found.x, found.z,
			content.content_ref(definition.host))
		append_candidate(plan, 2, template_class2, 2, found.x, 5, found.z)
	end

	local fixed_roots = {{-24, 38}, {0, 42}, {18, 42}, {32, 42}}
	for class = 1, 4 do
		if class ~= 2 then
			local catalog, root = class_catalog[class], fixed_roots[class]
			local definition = decorations[catalog]
			support(plan, surface_min, root[1], root[2],
				content.content_ref(definition.host))
			append_candidate(plan, 2, catalog, class, root[1], 5, root[2])
		end
	end
	local ignore_catalog = class_catalog[4]
	local clipped_catalog, clipped_root = template_class2
	for z = -10, 10 do
		for _, x in ipairs({surface_min.x, surface_max.x}) do
			local definition = decorations[clipped_catalog]
			local rotation = math.floor(string.byte(hash.digest("decoration_rotation_v1",
				"0", {definition.id, x, 5, z}), 1) / 64)
			local shape = templates.rotation(definition.id, rotation)
			if x + shape.min_x < surface_min.x or x + shape.max_x > surface_max.x then
				clipped_root = {x, z}
				break
			end
		end
		if clipped_root then break end
	end
	check(clipped_root, "clipped template root missing")
	append_candidate(plan, 2, clipped_catalog, 2, clipped_root[1], 5, clipped_root[2])
	local cultural_root = {40, -24}
	support(plan, surface_min, cultural_root[1], cultural_root[2],
		content.content_ref(surfaces[1].top))
	append_candidate(plan, 1, 1, 4096, cultural_root[1], 4, cultural_root[2])

	local filler = content.content_ref(surfaces[1].filler)
	local dust
	for index = 1, #surfaces do
		if surfaces[index].dust_ref ~= 0 then dust = surfaces[index].dust_ref break end
	end
	check(dust, "dust content ref missing")
	local p7 = {{-30, -30}, {-28, -30}, {-26, -30}}
	local base = column_base(surface_min, p7[1][1], p7[1][2])
	support(plan, surface_min, p7[1][1], p7[1][2],
		content.content_ref(surfaces[1].top), 1)
	plan.column_values[base + 9], plan.column_values[base + 11] = filler, 1
	plan.column_values[base + 12] = dust
	support(plan, surface_min, p7[2][1], p7[2][2],
		content.content_ref(surfaces[1].top), 2,
		content.content_ref(surfaces[1].shore))
	support(plan, surface_min, p7[3][1], p7[3][2],
		content.content_ref(surfaces[1].top), 3,
		content.content_ref(surfaces[1].bed))
	plan.candidate_cell_count = 1
	plan.candidate_cell_values[1], plan.candidate_cell_values[2] = -2, -2
	plan.candidate_cell_values[3], plan.candidate_cell_values[4] = 1,
		plan.candidate_count + 1

	local data, param2, light, index_at = vm_arrays(surface_min, surface_max, 0)
	for index = 1, #light do light[index] = 15 end
	data[index_at(p7[2][1], 4, p7[2][2])] = cid_by_name["default:water_source"]
	local vm, _, observer = vm_module.new({minp = surface_min, maxp = surface_max,
		data = data, param2 = param2, light = light,
		heightmap = fixed_array(6400, -31007), content_contract = contract,
		water_level = 1, ignore_cid = contract.ignore_cid,
		verify_inactive_tail = false})
	local result = settlement:apply(vm, surface_min, surface_max, plan,
		plan.generation, "fixture")
	local ledger = settlement_fixture.last_ledger()
	local run_values, run_count = settlement_fixture.run_values()
	local opcode_counts = {}
	for run = 1, run_count do
		local opcode = run_values[(run - 1) * 9 + 4]
		opcode_counts[opcode] = (opcode_counts[opcode] or 0) + 1
	end
	for _, opcode in ipairs({1, 2, 3, 4, 33}) do
		check((opcode_counts[opcode] or 0) > 0, "P7 opcode missing: " .. opcode)
	end
	local accepted_classes = {}
	for catalog = 1, #decorations do
		local aggregate = ledger.decorations[decorations[catalog].id]
		if aggregate and aggregate.accepted > 0 then
			accepted_classes[decorations[catalog].settlement_class] =
				(accepted_classes[decorations[catalog].settlement_class] or 0) +
				aggregate.accepted
		end
	end
	for class = 1, 4 do
		check((accepted_classes[class] or 0) > 0,
			"decoration class did not settle: " .. class)
		row("decoration_class/" .. class, accepted_classes[class])
	end
	local cultural_key = cultural[1].key .. "\0ordinary"
	check(ledger.cultural[cultural_key] and ledger.cultural[cultural_key].accepted == 1 and
		ledger.cultural[cultural_key].reserved == 225, "cultural reservation differs")
	local clipped_key = "decoration\0" .. decorations[clipped_catalog].id ..
		"\0clipped_owner"
	check(ledger.rejections[clipped_key] == 1, "owner-clipping rejection missing")
	local calls = observer.metrics()
	check(calls.vm_calc_lighting_calls == 1 and calls.vm_set_light_data_calls == 1,
		"lighting dirtiness calls differ")
	local light_seed_runs = settlement_fixture.last_light_seed_runs()
	check(light_seed_runs > 0 and calls.vm_set_lighting_calls == light_seed_runs + 1,
		"lighting seed-run branch differs")
	check(calls.vm_update_liquids_calls == 1, "liquid dirtiness call differs")
	row("p7_opcodes", table.concat({opcode_counts[1], opcode_counts[2],
		opcode_counts[3], opcode_counts[4], opcode_counts[33]}, "/"))
	row("cultural", cultural[1].key .. "/225")
	row("owner_clipping", decorations[clipped_catalog].id .. "/1")
	for rotation = 0, 3 do
		local shape = templates.rotation(decorations[template_class2].id, rotation)
		row("rotation/" .. rotation, table.concat({decorations[template_class2].id,
			shape.size_x, shape.size_y, shape.size_z, shape.cells[1].param2}, "/"))
	end
	row("rotation/wallmounted_invalid",
		rejected_template_kind("wallmounted", 6))
	row("rotation/4dir_invalid", rejected_template_kind("4dir", 0))
	row("rotation/meshoptions_passthrough",
		accepted_template_param2("meshoptions", 4))
	row("light_seed_runs", light_seed_runs)
	row("vm_surface", table.concat({result, calls.vm_set_lighting_calls,
		calls.vm_calc_lighting_calls, calls.vm_set_light_data_calls,
		calls.vm_update_liquids_calls}, "/"))

	-- Keep immutable ignore outside the lighting transaction: a byte-equal P7
	-- support intent makes the decoration rejection observable without dirtying
	-- content or requiring unavailable light context through ignore.
	local ignore_min, ignore_max = {x = -32, y = 4, z = -32},
		{x = 47, y = 5, z = 47}
	plan = blank_plan(ignore_min, ignore_max, true)
	local ignore_root = {0, 0}
	local ignore_host_ref = content.content_ref(decorations[ignore_catalog].host)
	support(plan, ignore_min, ignore_root[1], ignore_root[2], ignore_host_ref)
	append_candidate(plan, 2, ignore_catalog, 4, ignore_root[1], 5, ignore_root[2])
	plan.candidate_cell_count = 1
	plan.candidate_cell_values[1], plan.candidate_cell_values[2] = 0, 0
	plan.candidate_cell_values[3], plan.candidate_cell_values[4] = 1, 2
	data, param2, light, index_at = vm_arrays(ignore_min, ignore_max, 0)
	data[index_at(ignore_root[1], 4, ignore_root[2])] =
		contract.content_cids[ignore_host_ref]
	data[index_at(ignore_root[1], 5, ignore_root[2])] = contract.ignore_cid
	vm = vm_module.new({minp = ignore_min, maxp = ignore_max, data = data,
		param2 = param2, light = light, heightmap = fixed_array(6400, -31007),
		content_contract = contract, water_level = 1, ignore_cid = contract.ignore_cid,
		verify_inactive_tail = false})
	local ignore_result = settlement:apply(vm, ignore_min, ignore_max, plan,
		plan.generation, "fixture")
	ledger = settlement_fixture.last_ledger()
	local ignore_key = "decoration\0" .. decorations[ignore_catalog].id ..
		"\0content_ignore"
	check(ledger.rejections[ignore_key] == 1, "content-ignore rejection missing")
	check(ignore_result == "noop_equal_content", "ignore transaction dirtied content")
	row("ignore", decorations[ignore_catalog].id .. "/1/" .. ignore_result)

	local deep_min, deep_max = {x = -32, y = -1024, z = -32},
		{x = 47, y = -1009, z = 47}
	plan = blank_plan(deep_min, deep_max, false)
	local tier5_cid, tier6_cid = cid_by_name[projection.tiers[5].node],
		cid_by_name[projection.tiers[6].node]
	data, param2, light, index_at = vm_arrays(deep_min, deep_max, tier5_cid)
	data[index_at(0, -1024, 0)], data[index_at(2, -1024, 0)] = tier6_cid, tier6_cid
	vm, _, observer = vm_module.new({minp = deep_min, maxp = deep_max,
		data = data, param2 = param2, light = light,
		heightmap = fixed_array(6400, -31007), content_contract = contract,
		water_level = 1, ignore_cid = contract.ignore_cid,
		verify_inactive_tail = false})
	result = settlement:apply(vm, deep_min, deep_max, plan, plan.generation, "fixture")
	ledger = settlement_fixture.last_ledger()
	local shortfall_total, collision_total, collisions_by_resource = 0, 0, {}
	for key, value in pairs(ledger.resources) do
		shortfall_total = shortfall_total + value.shortfall
		collision_total = collision_total + value.collisions
		local separator = key:find("\0", 1, true)
		if not separator then fail("resource ledger key delimiter is absent") end
		local resource = key:sub(1, separator - 1)
		collisions_by_resource[resource] =
			(collisions_by_resource[resource] or 0) + value.collisions
	end
	check(shortfall_total == 2, "short-vein witness differs")
	check(collision_total == 2 and (collisions_by_resource.ore_1 or 0) == 0 and
			(collisions_by_resource.ore_2 or 0) == 0 and
			(collisions_by_resource.ore_3 or 0) == 2,
		"resource collision owner accounting differs")
	row("short_vein", shortfall_total)
	row("resource_collision", collision_total)
	for index = 1, #kat_resources do
		row("resource_collision/" .. kat_resources[index].key,
			collisions_by_resource[kat_resources[index].key] or 0)
	end
	row("vm_deep", result)
	fake_source.bridge_probe = true
	local bridge_probe = settlement_fixture.scan_horizontal_owner(-32, -32, {},
		{{catalog = template_class2, parameter = 2, x = 0, y = 5, z = 0}})
	fake_source.bridge_probe = false
	local bridge_rejection = "decoration\0" .. decorations[template_class2].id ..
		"\0insufficient_clearance"
	local bridge_details = {}
	for key, value in pairs(bridge_probe.rejections) do
		bridge_details[#bridge_details + 1] = display_key(key) .. "=" .. tostring(value)
	end
	table.sort(bridge_details)
	check(bridge_probe.decorations[decorations[template_class2].id].accepted == 0 and
			bridge_probe.rejections[bridge_rejection] == 1,
		"analytic P2-P6 predecessor bridge probe differs: " ..
			table.concat(bridge_details, ","))
	row("analytic_bridge_predecessor", bridge_probe.rejections[bridge_rejection])
	settlement, settlement_fixture = nil, nil
	collectgarbage("collect")
	local band_resources = clone(kat_resources)
	for index = 2, #band_resources do band_resources[index].denominators[6] = 8 end
	local band_content = {}
	function band_content.content_contract() return contract end
	function band_content.surfaces() return clone(surfaces) end
	function band_content.resources() return clone(band_resources) end
	function band_content.cultural() return clone(cultural) end
	function band_content.decorations() return clone(decorations) end
	function band_content.wp43_projection() return clone(projection) end
	function band_content.content_ref(name) return refs[name] end
	function band_content.param2_kind(content_ref) return param2_kinds[content_ref] end
	local band_settlement, band_fixture = settlement_factory.new({
		full_seed_string = "0", r5_adapter = r5_adapter, content = band_content,
		templates = templates, hash = hash, horizontal = horizontal,
		planner_source = fake_source, construction_identity = identity,
		cultural_registrations = {}, source = source,
		counting_allocator = allocator_factory.new(
			"grug_wp40_r6_settlement_allocator_v1")})

	local function run_deep_band_probe(min_y, band)
		local minp, maxp = {x = -32, y = min_y, z = -32},
			{x = 47, y = min_y + 15, z = 47}
		local band_plan = blank_plan(minp, maxp, false)
		local band_data, band_param2, band_light, band_index =
			vm_arrays(minp, maxp, 0)
		for x = 0, 15 do band_data[band_index(x, min_y, 0)] = tier6_cid end
		local band_vm = vm_module.new({minp = minp, maxp = maxp,
			data = band_data, param2 = band_param2, light = band_light,
			heightmap = fixed_array(6400, -31007), content_contract = contract,
			water_level = 1, ignore_cid = contract.ignore_cid,
			verify_inactive_tail = false})
		local band_result = band_settlement:apply(band_vm, minp, maxp, band_plan,
			band_plan.generation, "fixture")
		local band_ledger = band_fixture.last_ledger()
		local eligible, accepted, placed, rows_seen = 0, 0, 0, 0
		local suffix = "\0" .. band
		for key, value in pairs(band_ledger.resources) do
			check(key:sub(-#suffix) == suffix, "deep-band ledger branch differs")
			eligible = eligible + value.eligible
			accepted = accepted + value.accepted
			placed = placed + value.placed_nodes
			rows_seen = rows_seen + 1
		end
		check(rows_seen > 0 and eligible > 0 and accepted > 0 and placed > 0,
			"deep-band VM probe is empty")
		row("vm_band/" .. band, table.concat({band_result, eligible, accepted, placed}, "/"))
	end
	run_deep_band_probe(-1600, "deep_1500_1999")
	run_deep_band_probe(-2080, "deep_2000_floor")

	return rows
end
