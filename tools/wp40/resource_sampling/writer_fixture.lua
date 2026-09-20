-- Differential R6 resource-root settlement fixture.

return function(repo, expanded)
	if expanded and type(jit) ~= "table" then
		error("resource-rank fixture: expanded mode requires LuaJIT", 0)
	end
	local function check(condition, message)
		if not condition then error("resource-rank fixture: " .. message, 0) end
		return condition
	end
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local output_sha256 = common.new_sha256()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local hash_factory = dofile(wp40 .. "/r6_hash.lua")
	local settlement_factory = dofile(wp40 .. "/r6_settlement.lua")
	local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	local owner_min = {x = -32, y = -752, z = -32}
	local owner_max = {x = 47, y = -673, z = 47}
	local axis, volume = 112, 112 * 112 * 112
	local raw_inputs = {}
	local old_root_calls, shuffle_calls, b0_shuffle_calls = 0, 0, 0
	local function frame(value) return tostring(#value) .. ":" .. value end
	local old_root_prefix = frame("grug_wp40_r6_hash_v1") ..
		frame("resource_root_rank_v1") .. frame("rank-fixture")
	local shuffle_prefix = frame("grug_wp40_r6_hash_v1") ..
		frame("resource_root_shuffle_v1") .. frame("rank-fixture")
	local b0_shuffle_prefix = shuffle_prefix .. frame("B0")
	local function fake_raw_sha256(bytes)
		raw_inputs[#raw_inputs + 1] = bytes
		if bytes:sub(1, #old_root_prefix) == old_root_prefix then
			old_root_calls = old_root_calls + 1
		end
		if bytes:sub(1, #shuffle_prefix) == shuffle_prefix then
			shuffle_calls = shuffle_calls + 1
			if bytes:sub(1, #b0_shuffle_prefix) == b0_shuffle_prefix then
				b0_shuffle_calls = b0_shuffle_calls + 1
			end
		end
		return string.rep(string.char(255), 32)
	end
	local hash = hash_factory(fake_raw_sha256)

	local names, cids, masks, refs = {}, {}, {}, {}
	local function add(name, cid, mask)
		names[#names + 1], cids[#cids + 1], masks[#masks + 1] = name, cid, mask
		refs[name] = #names
	end
	for tier = 1, 6 do add("test:host_" .. tier, 100 + tier, 1) end
	local resource_specs = {
		{"H0", 1, 1, 1}, {"H1", 2, 1, 1}, {"H4096", 3, 4096, 1},
		{"B0", 4, 12000, 1}, {"normal_a", 5, 1, 3},
		{"normal_b", 5, 1, 2}, {"inactive", 6, 1, 1},
		{"regional_empty", 5, 1, 1},
	}
	for index = 1, #resource_specs do
		add("test:ore_" .. resource_specs[index][1], 200 + index, 4)
	end
	local stone_cid = 300
	add("default:stone", stone_cid, 1)
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
		if cid == stone_cid then
			return 6, 0, 0, 0, false, false, false, false, 0
		end
		for index = 1, 6 do
			if cid == cids[index] then
				return 6, 0, 0, 0, false, false, false, false, 0
			end
		end
		for index = 7, #cids do
			if cid == cids[index] then
				return 10, 0, 0, 0, false, false, false, false, 0
			end
		end
		return 9, 0, 0, 0, false, false, false, false, 0
	end
	contract.classify, contract.classify_runtime = classify, classify
	local resources = {}
	for index = 1, #resource_specs do
		local spec, denominators = resource_specs[index],
			{false, false, false, false, false, false}
		denominators[spec[2]] = spec[3]
		resources[index] = {key = spec[1], scope = spec[1] == "regional_empty" and "regional_g1" or "universal",
			first_tier = spec[2], denominators = denominators,
			max_nodes_per_vein = spec[4], deep_1500_1999_numerator = 5,
			deep_1500_1999_denominator = 4, deep_2000_floor_numerator = 3,
			deep_2000_floor_denominator = 2, node = "test:ore_" .. spec[1],
			content_ref = refs["test:ore_" .. spec[1]]}
	end
	local surface = {id = "resource_rank_biome", top = names[1],
		filler = names[1], filler_depth = 1, shore = names[1], bed = names[1],
		dust = names[1], top_ref = 1, filler_ref = 1, shore_ref = 1,
		bed_ref = 1, dust_ref = 0}
	local tier_min = {-688, -704, -720, -736, -752, -31000}
	local content = {}
	function content.content_contract() return contract end
	function content.surfaces() return {surface} end
	function content.new_surface_selector() return function() return surface end end
	function content.resources() return resources end
	function content.cultural() return {} end
	function content.decorations() return {} end
	function content.content_ref(name) return refs[name] end
	function content.new_surface_selector() return function() return surface end end
	function content.wp43_projection()
		local tiers = {}
		for index = 1, 6 do tiers[index] = {y_min = tier_min[index], node = names[index]} end
		return {tiers = tiers, race_regions = {}}
	end

	local planner_source = {}
	function planner_source.column_values_at()
		return "land", 1, "resource_rank_zone", surface.id, "none", -673,
			nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
	end
	function planner_source.surface_cave_run_at() return nil end
	function planner_source.surface_cave_candidate_at_cell() return nil end
	function planner_source.surface_cave_cell_at() return 0, 0 end
	function planner_source.coast_profile_at() return nil end
	function planner_source.coast_material_at() return nil end
	function planner_source.primary_relief_at() return nil end
	-- This fixture owns only the deep resource oracle. Keep the unrelated
	-- surface-skin pass excluded while still providing its complete content seam.
	function planner_source.landmark_excluded_at() return true end
	local horizontal = {}
	function horizontal.static_exclusion_values_at() return nil end
	function horizontal.housing_mask_id_at() return nil end
	local anchor = {id = "resource_rank_apex", position = {x = 10000, z = 10000}}
	local source = {claim_exclusions = {}, routes = {}, hard_protection = {},
		anchors = {anchor}, apex_sockets = {}, hydrology_profiles = {},
		hydrology = {}, hydrology_interfaces = {}}
	for index = 1, 24 do
		source.apex_sockets[index] = {id = "resource_rank_socket_" .. index,
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
	local r5_adapter, blocked_index = {}, false
	function r5_adapter.apply(_, vm)
		if blocked_index then
			local buffer = vm:get_data({})
			buffer[blocked_index] = 0
			vm:set_data(buffer)
		end
		return "resource_rank_r5_ready"
	end
	local stable_refs = {}
	for index = 1, #resources do stable_refs[index] = resources[index].key end
	table.sort(stable_refs, hash.less_bytes)
	local identity = {value = {}}

	local column_values, column_start = {}, {}
	for column = 1, 6400 do
		local base = (column - 1) * 12
		for field = 1, 12 do column_values[base + field] = 0 end
		column_values[base + 1] = 1
		column_start[column] = column == 1 and 1 or 2
	end
	column_start[6401] = 2
	local plan = {schema = "grug_wp40_r6_refinement_plan_v1",
		construction_identity = identity.value, generation = 1, valid = true,
		min_x = owner_min.x, min_y = owner_min.y, min_z = owner_min.z,
		max_x = owner_max.x, max_y = owner_max.y, max_z = owner_max.z,
		-- One harmless predecessor run activates the runtime eligibility cache.
		r5_plan = {column_start = column_start,
			run_values = {-673, -673, 7, 28, 0, 0, 0, 0, 0}}, r5_generation = 1,
		column_values = column_values, column_count = 6400,
		candidate_cell_values = {}, candidate_cell_count = 0,
		candidate_values = {}, candidate_count = 0, stable_refs = stable_refs}

	local function fixed_array(count, value)
		local result = {}
		for index = 1, count do result[index] = value end
		return result
	end
	local emerged_min = {x = owner_min.x - 16, y = owner_min.y - 16,
		z = owner_min.z - 16}
	local function index_at(x, y, z)
		return (z - emerged_min.z) * axis * axis +
			(y - emerged_min.y) * axis + (x - emerged_min.x) + 1
	end
	local function new_vm()
		local data = fixed_array(volume, 0)
		local function host(tier, x, y, z) data[index_at(x, y, z)] = cids[tier] end
		host(2, 20, -700, -20) -- H1
		for z = 0, 15 do for y = -720, -705 do for x = 0, 15 do
			host(3, x, y, z) -- H4096
		end end end
		host(4, 20, -730, 20) -- B0
		for x = -30, -25 do host(5, x, -750, -30) end -- own frontier roots
		host(5, -15, -750, -30); host(5, -14, -750, -30) -- connected pair
		host(5, -10, -750, -30); host(5, -5, -750, -30) -- short frontier
		if expanded then
			-- A large zero-budget population exposes accidental root hashing
			-- and sorting without changing any settlement decision.
			for z = 16, 31 do for y = -736, -729 do for x = 16, 31 do
				host(4, x, y, z)
			end end end
			for z = 32, 39 do for x = 32, 39 do host(5, x, -745, z) end end
		end
		return vm_module.new({minp = owner_min, maxp = owner_max, data = data,
			param2 = fixed_array(volume, 0), light = fixed_array(volume, 0),
			heightmap = fixed_array(6400, -31007), content_contract = contract,
			water_level = 1, ignore_cid = contract.ignore_cid,
			verify_inactive_tail = false})
	end

	local function rle(values)
		local rows, first, count = {}, values[1], 1
		for index = 2, #values do
			if values[index] == first then count = count + 1
			else
				rows[#rows + 1] = tostring(first) .. "*" .. tostring(count)
				first, count = values[index], 1
			end
		end
		rows[#rows + 1] = tostring(first) .. "*" .. tostring(count)
		return table.concat(rows, ",")
	end
	local function raw_trace()
		local rows = {}
		for index = 1, #raw_inputs do
			rows[index] = tostring(#raw_inputs[index]) .. ":" .. raw_inputs[index]
		end
		return table.concat(rows)
	end
	local function canonical_snapshot(snapshot)
		return table.concat({"data=", rle(snapshot.data), "\nparam2=",
			rle(snapshot.param2), "\nlight=", rle(snapshot.light),
			"\ntrace=", table.concat(snapshot.trace, "|"), "\n"})
	end
	local dependencies = {full_seed_string = "rank-fixture", r5_adapter = r5_adapter,
		content = content, templates = {}, hash = hash, horizontal = horizontal,
		planner_source = planner_source, construction_identity = identity,
		cultural_registrations = {}, source = source,
		planner_stable_refs = stable_refs, counting_allocator = allocator}
	local function census_snapshot(result)
		local host = result.substrate["test:host_3"]
		local row = result.resources.H4096
		local witness = result.witnesses.H4096
		return table.concat({result.region_host.count, result.region_host.tier,
			result.region_host.band, host.count, host.digest, row.eligible, row.budget,
			row.planned, row.accepted, row.collisions, row.shortfall,
			row.target_nodes, row.placed_nodes, witness.x, witness.y, witness.z}, "\t")
	end
	local function scan_fixture(fixture)
		raw_inputs, old_root_calls, shuffle_calls, b0_shuffle_calls = {}, 0, 0, 0
		local result = fixture.scan_census_cube({race = "human", bucket = "test",
			zone_id = "resource_rank_zone", cell_x = 0, cell_y = -45, cell_z = 0})
		local row = result.resources.H4096
		check(result.region_host.count == 4096 and result.region_host.tier == 3 and
			result.region_host.band == "ordinary", "census region host differs")
		check(row.eligible == 4096 and row.budget == 1 and row.target_nodes == 1 and
			row.placed_nodes == 1, "census H4096 result differs")
		check(old_root_calls == 0, "census used old root rank hashes")
		check(shuffle_calls == 1, "census did not use one positive-group shuffle seed")
		check(b0_shuffle_calls == 0, "census zero-budget group used a shuffle seed")
		return census_snapshot(result), raw_trace()
	end
	local _, shared_census = settlement_factory.new(dependencies)
	local census_first, census_first_raw = scan_fixture(shared_census)
	local census_repeat, census_repeat_raw = scan_fixture(shared_census)
	local _, runtime_census = settlement_factory.new_runtime(dependencies)
	local census_runtime, census_runtime_raw = scan_fixture(runtime_census)
	check(census_first == census_repeat and census_first == census_runtime,
		"census repeated constructor output differs")
	check(census_first_raw == census_repeat_raw and census_first_raw == census_runtime_raw,
		"census repeated constructor hash framing differs")
	local function run(runtime)
		raw_inputs, old_root_calls, shuffle_calls, b0_shuffle_calls = {}, 0, 0, 0
		blocked_index = false
		local settlement, fixture
		if runtime then
			settlement, fixture = settlement_factory.new_runtime(dependencies)
		else
			settlement, fixture = settlement_factory.new(dependencies)
		end
		local vm, _, observer = new_vm()
		local status = settlement:apply(vm, owner_min, owner_max, plan, 1, "fixture")
		local ledger = runtime and false or fixture.last_ledger()
		local snapshot = observer.snapshot()
		local result = {status = status, canonical = canonical_snapshot(snapshot),
			raw = raw_trace(), raw_count = #raw_inputs,
			old_root_calls = old_root_calls, shuffle_calls = shuffle_calls,
			b0_shuffle_calls = b0_shuffle_calls, ledger = ledger, cid_counts = {}}
		for index = 1, #snapshot.data do
			result.cid_counts[snapshot.data[index]] =
				(result.cid_counts[snapshot.data[index]] or 0) + 1
		end
		-- Reuse the writer with changed predecessor content at the same owner
		-- index. Eligibility must observe this transaction's predecessor bytes.
		blocked_index = index_at(20, -700, -20) -- H1: exactly one host, budget 1.
		raw_inputs = {}
		vm, _, observer = new_vm()
		result.reused_status = settlement:apply(vm, owner_min, owner_max, plan, 1, "fixture")
		snapshot = observer.snapshot()
		check(snapshot.data[blocked_index] == 0, "previous eligibility survived writer reuse")
		result.reused_canonical = canonical_snapshot(snapshot)
		result.reused_raw = raw_trace()
		blocked_index = false
		settlement, fixture, vm, observer, snapshot = nil, nil, nil, nil, nil
		collectgarbage("collect")
		return result
	end
	local ordinary = run(false)
	local runtime = run(true)
	-- Deep owners have no predecessor runs and bypass the cache entirely.
	local populated_r5_plan = plan.r5_plan
	local empty_starts = {}
	for column = 1, 6401 do empty_starts[column] = 1 end
	plan.r5_plan = {column_start = empty_starts, run_values = {}}
	local uncached_runtime = run(true)
	plan.r5_plan = populated_r5_plan
	check(uncached_runtime.canonical == runtime.canonical and
		uncached_runtime.raw == runtime.raw and
		uncached_runtime.reused_canonical == runtime.reused_canonical and
		uncached_runtime.reused_raw == runtime.reused_raw,
		"no-predecessor cache bypass differs")
	check(runtime.status == ordinary.status, "settlement status differs")
	check(runtime.canonical == ordinary.canonical,
		"content, param2, light or VoxelManip trace differs")
	check(runtime.reused_status == ordinary.reused_status and
		runtime.reused_canonical == ordinary.reused_canonical,
		"reused writer differs from uncached settlement")
	check(ordinary.reused_raw == runtime.reused_raw .. runtime.reused_raw,
		"reused writer eligible population or hash framing differs")
	-- The ordinary fixture performs its mandated private replay. Both passes must
	-- frame the same inputs as the single runtime transaction.
	check(ordinary.raw_count == runtime.raw_count * 2 and
		ordinary.raw == runtime.raw .. runtime.raw,
		"prepared hash framing or digest population differs")
	check(ordinary.old_root_calls == 0 and runtime.old_root_calls == 0,
		"old resource-root rank hashes remain")
	check(ordinary.shuffle_calls == runtime.shuffle_calls * 2,
		"shuffle seed population differs between replay paths")
	check(ordinary.b0_shuffle_calls == 0 and runtime.b0_shuffle_calls == 0,
		"zero-budget group computed a shuffle seed")

	local function ledger_row(resource, cell_x, cell_y, cell_z, tier)
		local key = table.concat({resource, cell_x, cell_y, cell_z,
			"test:host_" .. tier, tier, "ordinary"}, "\0")
		return ordinary.ledger.resources[key]
	end
	local h1 = check(ledger_row("H1", 1, -44, -2, 2), "H1 ledger absent")
	check(h1.eligible == 1 and h1.budget == 1 and h1.placed_nodes == 1,
		"H1 result differs")
	local h4096 = check(ledger_row("H4096", 0, -45, 0, 3),
		"H4096 ledger absent")
	check(h4096.eligible == 4096 and h4096.budget == 1 and
		h4096.placed_nodes == 1, "H4096 result differs")
	local b0 = check(ledger_row("B0", 1, -46, 1, 4), "B0 ledger absent")
	check(b0.eligible == (expanded and 2048 or 1) and b0.budget == 0 and
		b0.planned == 0,
		"B0 result differs")
	for key in pairs(ordinary.ledger.resources) do
		check(key:sub(1, 3) ~= "H0\0", "H0 unexpectedly has eligible hosts")
		check(key:sub(1, 9) ~= "inactive\0", "inactive tier produced resources")
		check(key:sub(1, 15) ~= "regional_empty\0", "disallowed region produced resources")
	end
	local own = check(ledger_row("normal_a", -2, -47, -2, 5),
		"own-frontier ledger absent")
	check(own.eligible == 6 and own.budget == 6 and own.planned == 2 and
		own.placed_nodes + own.shortfall == own.budget and own.collisions == 0,
		"own frontier budget or claims differ")
	local short = check(ledger_row("normal_a", -1, -47, -2, 5),
		"short-frontier ledger absent")
	check(short.eligible == 4 and short.budget == 4 and short.planned == 2 and
		short.placed_nodes + short.shortfall == short.budget,
		"short frontier budget conservation differs")
	local exhausted = check(ledger_row("normal_b", -2, -47, -2, 5),
		"exhausted-root ledger absent")
	check(exhausted.eligible == 6 and exhausted.budget == 6 and
		exhausted.planned == 3 and exhausted.placed_nodes + exhausted.shortfall ==
		exhausted.budget, "subsequent resource budget conservation differs")
	local positive_groups = 0
	local placed_by_resource = {}
	for key, row in pairs(ordinary.ledger.resources) do
		if row.budget > 0 then positive_groups = positive_groups + 1 end
		local separator = assert(string.find(key, "\0", 1, true))
		local resource = string.sub(key, 1, separator - 1)
		placed_by_resource[resource] = (placed_by_resource[resource] or 0) +
			row.placed_nodes
		local spec
		for index = 1, #resources do
			if resources[index].key == resource then spec = resources[index] break end
		end
		check(spec and row.target_nodes == row.budget and
			row.planned == (row.budget == 0 and 0 or math.floor(
				(row.budget + spec.max_nodes_per_vein - 1) / spec.max_nodes_per_vein)) and
			row.placed_nodes + row.shortfall == row.budget,
			"multi-node target conservation differs for " .. resource)
	end
	check(runtime.shuffle_calls == positive_groups,
		"shuffle seed count is not one per positive-budget group")
	for index = 1, #resources do
		local resource = resources[index]
		local cid = cids[6 + index]
		check((runtime.cid_counts[cid] or 0) == (placed_by_resource[resource.key] or 0),
			"VM claims differ from ledger for " .. resource.key)
	end
	check(ordinary.raw:find("-47", 1, true) ~= nil and
		ordinary.raw:find("-30", 1, true) ~= nil,
		"negative-coordinate hash witness absent")

	local canonical_sha = common.hex(output_sha256(ordinary.canonical))
	local raw_sha = common.hex(output_sha256(runtime.raw))
	local census_sha = common.hex(output_sha256(census_first))
	local rows = {"schema\tgrug_wp40_resource_rank_diff_v1",
		"mode\t" .. (expanded and "expanded" or "compact"),
		"status\t" .. ordinary.status,
		"cases\tH0/H1/H4096/B0/normal/budget_conservation/claims/inactive/region_empty/reuse/no_r5",
		"h4096\t" .. h4096.eligible .. "/" .. h4096.budget,
		"b0\t" .. b0.eligible .. "/" .. b0.budget .. "/" ..
			runtime.b0_shuffle_calls,
		"own_claim\t" .. own.placed_nodes .. "/" .. own.collisions,
		"short_frontier\t" .. short.placed_nodes .. "/" .. short.shortfall,
		"exhausted\t" .. exhausted.accepted .. "/" .. exhausted.collisions ..
			"/" .. exhausted.shortfall,
		"raw_calls\t" .. runtime.raw_count,
		"old_root_calls\t" .. runtime.old_root_calls,
		"shuffle_calls\t" .. runtime.shuffle_calls,
		"census\t4096/1/1",
		"census_sha256\t" .. census_sha,
		"raw_framing_sha256\t" .. raw_sha,
		"vm_canonical_sha256\t" .. canonical_sha,
		"reused_vm_sha256\t" .. common.hex(output_sha256(runtime.reused_canonical))}
	local bytes = table.concat(rows, "\n") .. "\n"
	return bytes .. "digest\t" .. common.hex(output_sha256(bytes)) .. "\n"
end
