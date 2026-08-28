-- Pure, disabled WP40 R5 typed column/Y-run planner.

return function(allocator_factory)
	local MAX_SAFE = 9007199254740991
	local SOURCE_SCHEMA = "grug_wp40_r5_planner_source_v1"
	local PLAN_SCHEMA = "grug_wp40_r5_column_run_plan_v1"
	local RELATION_SCHEMA = "grug_wp40_r5_relational_lookup_v1"
	local MANIFEST_SCHEMA = "grug_wp40_r5_mapgen_manifest_v1"
	local MANIFEST_MARKER = "grug_wp40_r5_validated_manifest_v1"
	local PLANNER_ALLOCATOR_DOMAIN = "grug_wp40_r5_planner_allocator_v1"
	local HOTPATH_NAME = "planner_plan_slice"

	local AUTHORED_FLOOR = -37
	local OWNER_MIN = -30912
	local OWNER_MAX = 30927
	local MAX_AXIS = 80
	local MAX_COLUMNS = 6400
	local MAX_CANDIDATES = 16
	local MAX_RESOLVED_PER_COLUMN = 31
	local MAX_RESOLVED = 198400
	local RUN_STRIDE = 9
	local MAX_RUN_CELLS = MAX_RESOLVED * RUN_STRIDE
	local MAX_STABLE_REFS = 512

	local R_Y_MIN = 1
	local R_Y_MAX = 2
	local R_PRIORITY = 3
	local R_OPCODE = 4
	local R_ROLE = 5
	local R_POLICY = 6
	local R_FEATURE = 7
	local R_INTERFACE = 8
	local R_AUX = 9
	local M_PLANNER_CONSTRUCTION = 1
	local M_PLAN_IDENTITY = 2
	local M_STABLE_REF_COUNT = 3
	local M_PLAN_SLICE_ALLOCATIONS = 4
	local M_PEAK_CANDIDATES = 5
	local M_PEAK_RESOLVED_COLUMN = 6
	local M_PEAK_RESOLVED_SLICE = 7
	local M_PEAK_RUN_CELLS = 8
	local M_REUSE_CALLS = 9
	local M_METRICS_RESULTS = 10

	-- Strict unsigned-ASCII ordinals from the complete closed vocabularies.
	local OP_BIOME_BED = 1
	local OP_BIOME_FILLER = 2
	local OP_BIOME_SHORE = 3
	local OP_BIOME_TOP = 4
	local OP_BRIDGE_CLEAR = 5
	local OP_BRIDGE_DECK = 6
	local OP_BRIDGE_SUPPORT = 7
	local OP_CAUSEWAY_CULVERT = 8
	local OP_CAUSEWAY_FILL = 9
	local OP_CAUSEWAY_SURFACE = 10
	local OP_CONTACT_FALL_CLEAR = 11
	local OP_DECORATION = 12
	local OP_FORD_BED = 13
	local OP_FOUNDATION_CLEAR = 14
	local OP_FOUNDATION_FILL = 15
	local OP_FOUNDATION_SURFACE = 16
	local OP_HYDROLOGY_BANK_SEAL = 17
	local OP_HYDROLOGY_BED_SEAL = 18
	local OP_ORDINARY_WATER = 19
	local OP_PATH_CLEAR = 20
	local OP_PATH_FILL = 21
	local OP_PATH_SURFACE = 22
	local OP_RECEIVER_OPEN = 23
	local OP_RESOURCE_EXACT_HOST = 24
	local OP_RIVER_WATER = 25
	local OP_TERRAIN_CLEAR = 26
	local OP_TERRAIN_FILL = 27
	local OP_TERRAIN_SURFACE = 28
	local OP_TUNNEL_FLOOR = 29
	local OP_TUNNEL_LUMEN = 30
	local OP_TUNNEL_ROOF = 31
	local OP_TUNNEL_WALL = 32

	local ROLE_AIR = 1
	local ROLE_BRIDGE_DECK = 2
	local ROLE_BRIDGE_SUPPORT = 3
	local ROLE_CAUSEWAY_CORE = 4
	local ROLE_CAUSEWAY_SURFACE = 5
	local ROLE_FORD_SURFACE = 6
	local ROLE_FOUNDATION_CORE = 7
	local ROLE_FOUNDATION_SURFACE = 8
	local ROLE_HYDROLOGY_SEAL = 9
	local ROLE_ORDINARY_WATER_SOURCE = 10
	local ROLE_PATH_CORE = 11
	local ROLE_PATH_SURFACE = 12
	local ROLE_RIVER_WATER_SOURCE = 13
	local ROLE_STRATUM_AT_Y = 14
	local ROLE_TUNNEL_FLOOR = 15
	local ROLE_TUNNEL_WALL = 16

	local POLICY_CUT_NATURAL = 1
	local POLICY_DEEP_EXACT_HOST = 2
	local POLICY_FILL_VOID = 3
	local POLICY_OPEN_ENGINEERED = 4
	local POLICY_SEAL_VOID = 5
	local POLICY_SURFACE_EXACT = 6
	local POLICY_WRITE_WATER = 7
	local AUX_NONE = 0

	local ALLOCATOR_FIELDS = {
		new_array = true,
		new_map = true,
		grow = true,
		map_put = true,
		seal_construction = true,
		enter_hotpath = true,
		leave_hotpath = true,
		metrics = true,
	}
	local SOURCE_FIELDS = {
		schema = true,
		column_values_at = true,
		hydrology_metric_values_at = true,
		metrics = true,
	}
	local RELATION_FIELDS = {
		schema = true,
		allocator_identity = true,
		stable_refs = true,
		hydrology_ids = true,
		hydrology_profile_ids = true,
		hydrology_depths = true,
		hydrology_bed_seal_layers = true,
		hydrology_bank_seal_nodes = true,
		interface_ids = true,
		interface_kinds = true,
		interface_hydrology_ordinals = true,
		interface_upper_ordinals = true,
		interface_lower_ordinals = true,
		interface_member_start = true,
		interface_members = true,
	}
	local MANIFEST_FIELDS = {
		schema = true,
		engine_commit = true,
		mg_name = true,
		water_level = true,
		mapgen_limit = true,
		chunksize = true,
		central_owner_y_min = true,
		central_owner_y_max = true,
		heightmap_entries = true,
		heightmap_sentinel = true,
		heightmap_order = true,
		emerge_threads = true,
		engine_emerge_setting = true,
		mg_flags = true,
		mgv7_spflags = true,
		mgv7_dungeon_ymin = true,
		mgv7_dungeon_ymax = true,
		authored_floor = true,
		force_native_dungeon = true,
	}

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	local function safe_integer(value, label, minimum, maximum, code)
		minimum = minimum or -MAX_SAFE
		maximum = maximum or MAX_SAFE
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 or
				value < minimum or value > maximum then
			fail(code or "fail_bound", label .. " is not a safe integer")
		end
		return value
	end

	local function exact_raw_fields(value, allowed, label, code)
		if type(value) ~= "table" then
			fail(code, label .. " is not a table")
		end
		local count = 0
		for key in pairs(value) do
			if not allowed[key] then
				fail(code, label .. " has unexpected field " .. tostring(key))
			end
			count = count + 1
		end
		local expected = 0
		for key in pairs(allowed) do
			expected = expected + 1
			if rawget(value, key) == nil then
				fail(code, label .. " is missing field " .. key)
			end
		end
		if count ~= expected then fail(code, label .. " field count differs") end
	end

	local function exact_dense_count(values, label, maximum, code)
		if type(values) ~= "table" then fail(code, label .. " is not an array") end
		local count = #values
		if maximum and count > maximum then fail(code, label .. " exceeds bound") end
		for index = 1, count do
			if rawget(values, index) == nil then fail(code, label .. " has a hole") end
		end
		local seen = 0
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail(code, label .. " is not dense")
			end
			seen = seen + 1
		end
		if seen ~= count then fail(code, label .. " key count differs") end
		return count
	end

	if type(allocator_factory) ~= "table" or
			type(rawget(allocator_factory, "new")) ~= "function" then
		fail("fail_source", "allocator factory is invalid")
	end
	for key in pairs(allocator_factory) do
		if key ~= "new" then
			fail("fail_source", "allocator factory has unexpected field")
		end
	end
	local allocator_factory_new = rawget(allocator_factory, "new")
	local module = {}

	function module.new(planner_source, validated_manifest, relational_lookup,
			counting_allocator, construction_identity)
		-- The few vocabulary constants used by generic candidate helpers are
		-- local scalars so this Lua 5.1 constructor stays below 60 upvalues.
		local OP_BRIDGE_CLEAR, OP_BRIDGE_DECK, OP_BRIDGE_SUPPORT = 5, 6, 7
		local OP_CAUSEWAY_CULVERT, OP_CAUSEWAY_FILL,
			OP_CAUSEWAY_SURFACE = 8, 9, 10
		local OP_CONTACT_FALL_CLEAR, OP_FORD_BED = 11, 13
		local OP_RECEIVER_OPEN, OP_RIVER_WATER = 23, 25
		local OP_TUNNEL_FLOOR, OP_TUNNEL_LUMEN, OP_TUNNEL_ROOF,
			OP_TUNNEL_WALL = 29, 30, 31, 32
		local ROLE_HYDROLOGY_SEAL, ROLE_TUNNEL_WALL = 9, 16
		local POLICY_SEAL_VOID = 5
		exact_raw_fields(planner_source, SOURCE_FIELDS, "planner source",
			"fail_source")
		if planner_source.schema ~= SOURCE_SCHEMA or
				type(planner_source.column_values_at) ~= "function" or
				type(planner_source.hydrology_metric_values_at) ~= "function" or
				type(planner_source.metrics) ~= "function" then
			fail("fail_source", "planner source API differs")
		end
		local column_values_at = planner_source.column_values_at
		local hydrology_metric_values_at =
			planner_source.hydrology_metric_values_at

		exact_raw_fields(validated_manifest, MANIFEST_FIELDS, "manifest",
			"fail_manifest")
		if getmetatable(validated_manifest) ~= MANIFEST_MARKER or
				validated_manifest.schema ~= MANIFEST_SCHEMA or
				validated_manifest.engine_commit ~=
					"df04879066de6eb94ca43996822a6dfacc74feca" or
				validated_manifest.mg_name ~= "v7" or
				validated_manifest.water_level ~= 1 or
				validated_manifest.mapgen_limit ~= 31007 or
				validated_manifest.chunksize ~= 5 or
				validated_manifest.central_owner_y_min ~= OWNER_MIN or
				validated_manifest.central_owner_y_max ~= OWNER_MAX or
				validated_manifest.heightmap_entries ~= 6400 or
				validated_manifest.heightmap_sentinel ~= -31007 or
				validated_manifest.heightmap_order ~= "x_fast_z_outer" or
				validated_manifest.emerge_threads ~= 1 or
				validated_manifest.engine_emerge_setting ~= "num_emerge_threads" or
				validated_manifest.mg_flags ~=
					"biomes,caves,decorations,dungeons,light,ores" or
				validated_manifest.mgv7_spflags ~= "caverns,mountains,ridges" or
				validated_manifest.mgv7_dungeon_ymin ~= -31000 or
				validated_manifest.mgv7_dungeon_ymax ~= -193 or
				validated_manifest.authored_floor ~= AUTHORED_FLOOR or
				validated_manifest.force_native_dungeon ~= false then
			fail("fail_manifest", "manifest authority differs")
		end

		exact_raw_fields(counting_allocator, ALLOCATOR_FIELDS, "planner allocator",
			"fail_source")
		if allocator_factory_new(PLANNER_ALLOCATOR_DOMAIN,
				counting_allocator) ~= true then
			fail("fail_source", "planner allocator factory identity differs")
		end
		for name in pairs(ALLOCATOR_FIELDS) do
			if type(counting_allocator[name]) ~= "function" then
				fail("fail_source", "planner allocator method differs: " .. name)
			end
		end

		if type(relational_lookup) ~= "table" or
				relational_lookup.schema ~= RELATION_SCHEMA or
				not rawequal(relational_lookup.allocator_identity,
					counting_allocator) then
			fail("fail_source", "relational lookup provenance differs")
		end
		for key in pairs(RELATION_FIELDS) do
			if rawget(relational_lookup, key) == nil then
				fail("fail_source", "relational lookup is missing field " .. key)
			end
		end
		if type(construction_identity) ~= "table" or
				getmetatable(construction_identity) ~= nil then
			fail("fail_source", "construction identity is not opaque table")
		end
		for _ in pairs(construction_identity) do
			fail("fail_source", "construction identity is not empty")
		end

		local stable_refs = relational_lookup.stable_refs
		local stable_count = exact_dense_count(stable_refs, "stable refs",
			MAX_STABLE_REFS, "fail_source")
		local LOOKUP_BASE = 513
		local LOOKUP_BASE_2 = LOOKUP_BASE * LOOKUP_BASE
		local LOOKUP_BASE_3 = LOOKUP_BASE_2 * LOOKUP_BASE
		local function lookup_components(id, label)
			local packed = relational_lookup[id]
			safe_integer(packed, label .. " packed lookup", 1, MAX_SAFE,
				"fail_source")
			local stable = packed % LOOKUP_BASE
			local quotient = math.floor(packed / LOOKUP_BASE)
			local hydro = quotient % LOOKUP_BASE
			quotient = math.floor(quotient / LOOKUP_BASE)
			local interface = quotient % LOOKUP_BASE
			local route_interface = math.floor(quotient / LOOKUP_BASE)
			if route_interface > MAX_STABLE_REFS then
				fail("fail_source", label .. " packed component exceeds bound")
			end
			return stable, hydro, interface, route_interface
		end
		local previous_ref
		for index = 1, stable_count do
			local id = stable_refs[index]
			if type(id) ~= "string" or id == "" or RELATION_FIELDS[id] or
					(previous_ref ~= nil and not (previous_ref < id)) then
				fail("fail_source", "stable refs are not canonical")
			end
			local stable = lookup_components(id, "stable ref")
			if stable ~= index then
				fail("fail_source", "stable lookup ordinal differs")
			end
			previous_ref = id
		end
		local relation_key_count = 0
		for key in pairs(relational_lookup) do
			if not RELATION_FIELDS[key] then
				if type(key) ~= "string" then
					fail("fail_source", "relational lookup has non-text dynamic key")
				end
				local stable = lookup_components(key, "dynamic relation key")
				if stable_refs[stable] ~= key then
					fail("fail_source", "relational lookup has unknown dynamic key")
				end
			end
			relation_key_count = relation_key_count + 1
		end
		local fixed_relation_count = 0
		for _ in pairs(RELATION_FIELDS) do fixed_relation_count = fixed_relation_count + 1 end
		if relation_key_count ~= fixed_relation_count + stable_count then
			fail("fail_source", "relational lookup key population differs")
		end

		local hydrology_ids = relational_lookup.hydrology_ids
		local hydro_profile_ids = relational_lookup.hydrology_profile_ids
		local hydro_depths = relational_lookup.hydrology_depths
		local hydro_bed_layers = relational_lookup.hydrology_bed_seal_layers
		local hydro_bank_nodes = relational_lookup.hydrology_bank_seal_nodes
		if not rawequal(hydrology_ids, hydro_profile_ids) or
				not rawequal(hydrology_ids, hydro_depths) or
				not rawequal(hydrology_ids, hydro_bed_layers) or
				not rawequal(hydrology_ids, hydro_bank_nodes) then
			fail("fail_source", "hydrology stride aliases differ")
		end
		local hydro_cells = exact_dense_count(hydrology_ids,
			"hydrology stride", MAX_STABLE_REFS * 5, "fail_source")
		if hydro_cells % 5 ~= 0 then
			fail("fail_source", "hydrology stride length differs")
		end
		local hydro_count = hydro_cells / 5
		local function hydro_value(ordinal, offset)
			return hydrology_ids[(ordinal - 1) * 5 + offset]
		end
		for index = 1, hydro_count do
			local id = hydro_value(index, 1)
			local profile_id = hydro_value(index, 2)
			local stable, hydro = lookup_components(id, "hydrology ID")
			if type(id) ~= "string" or id == "" or hydro ~= index or
					stable_refs[stable] ~= id or type(profile_id) ~= "string" or
					profile_id == "" then
				fail("fail_source", "hydrology identity/profile differs")
			end
			safe_integer(hydro_value(index, 3), "hydrology depth", 0, MAX_SAFE,
				"fail_source")
			if safe_integer(hydro_value(index, 4), "hydrology bed seal", 0,
					MAX_SAFE, "fail_source") ~= 3 or
					safe_integer(hydro_value(index, 5), "hydrology bank seal", 0,
						MAX_SAFE, "fail_source") ~= 2 then
				fail("fail_source", "hydrology seal profile differs")
			end
		end

		local interface_ids = relational_lookup.interface_ids
		local interface_kinds = relational_lookup.interface_kinds
		local interface_hydro = relational_lookup.interface_hydrology_ordinals
		local interface_upper = relational_lookup.interface_upper_ordinals
		local interface_lower = relational_lookup.interface_lower_ordinals
		local interface_start = relational_lookup.interface_member_start
		local interface_members = relational_lookup.interface_members
		if not rawequal(interface_ids, interface_kinds) or
				not rawequal(interface_ids, interface_hydro) or
				not rawequal(interface_ids, interface_upper) or
				not rawequal(interface_ids, interface_lower) or
				not rawequal(interface_ids, interface_start) then
			fail("fail_source", "interface stride aliases differ")
		end
		local interface_cells = exact_dense_count(interface_ids,
			"interface stride", MAX_STABLE_REFS * 6 + 1, "fail_source")
		if interface_cells < 1 or (interface_cells - 1) % 6 ~= 0 then
			fail("fail_source", "interface stride length differs")
		end
		local interface_count = (interface_cells - 1) / 6
		local function interface_value(ordinal, offset)
			return interface_ids[(ordinal - 1) * 6 + offset]
		end
		local function interface_after(ordinal)
			if ordinal < interface_count then return interface_value(ordinal + 1, 6) end
			return interface_ids[interface_count * 6 + 1]
		end
		local member_count = exact_dense_count(interface_members,
			"interface members", MAX_STABLE_REFS, "fail_source")
		if interface_count == 0 or interface_value(1, 6) ~= 1 or
				interface_ids[interface_count * 6 + 1] ~= member_count + 1 then
			fail("fail_source", "interface member starts differ")
		end
		for index = 1, interface_count do
			local id = interface_value(index, 1)
			local kind = interface_value(index, 2)
			local first, after = interface_value(index, 6), interface_after(index)
			local hydrology_ordinal = interface_value(index, 3)
			local upper_ordinal = interface_value(index, 4)
			local lower_ordinal = interface_value(index, 5)
			local stable, _, interface = lookup_components(id, "interface ID")
			if type(id) ~= "string" or id == "" or interface ~= index or
					stable_refs[stable] ~= id or type(kind) ~= "string" or kind == "" or
					first > after or first < 1 or after > member_count + 1 then
				fail("fail_source", "interface identity/member span differs")
			end
			safe_integer(hydrology_ordinal, "interface hydrology ordinal", 0,
				hydro_count, "fail_source")
			safe_integer(upper_ordinal, "interface upper ordinal", 0,
				hydro_count, "fail_source")
			safe_integer(lower_ordinal, "interface lower ordinal", 0,
				hydro_count, "fail_source")
			local previous_member_id
			for member_index = first, after - 1 do
				local member = safe_integer(interface_members[member_index],
					"interface member", 1, hydro_count, "fail_source")
				local member_id = hydro_value(member, 1)
				if previous_member_id ~= nil and not (previous_member_id < member_id) then
					fail("fail_source", "interface members are not sorted and unique")
				end
				previous_member_id = member_id
			end
			local relation_member_count = after - first
			local route_reference_count = 0
			for stable_index = 1, stable_count do
				local _, _, _, route_interface = lookup_components(
					stable_refs[stable_index], "route-interface validation")
				if route_interface == index then
					route_reference_count = route_reference_count + 1
				end
			end
			if kind == "bridge" or kind == "ford" or kind == "causeway" then
				if hydrology_ordinal == 0 or upper_ordinal ~= 0 or lower_ordinal ~= 0 or
						relation_member_count ~= 1 or
						interface_members[first] ~= hydrology_ordinal or
						route_reference_count < 1 then
					fail("fail_source", "route-interface relation shape differs")
				end
			elseif kind == "rapid" or kind == "waterfall" then
				local first_member, second_member = interface_members[first],
					interface_members[first + 1]
				if hydrology_ordinal ~= 0 or upper_ordinal == 0 or
						lower_ordinal == 0 or upper_ordinal == lower_ordinal or
						relation_member_count ~= 2 or route_reference_count ~= 0 or
						not ((first_member == upper_ordinal and
							second_member == lower_ordinal) or
							(first_member == lower_ordinal and
							second_member == upper_ordinal)) then
					fail("fail_source", "transition relation shape differs")
				end
			elseif kind == "confluence" then
				if hydrology_ordinal ~= 0 or upper_ordinal ~= 0 or lower_ordinal ~= 0 or
						relation_member_count < 2 or route_reference_count ~= 0 then
					fail("fail_source", "confluence relation shape differs")
				end
			else
				fail("fail_source", "unknown relation kind")
			end
		end
		for stable_index = 1, stable_count do
			local id = stable_refs[stable_index]
			local stable, hydro, interface, route_interface =
				lookup_components(id, "stable lookup")
			if stable ~= stable_index or hydro > hydro_count or
					interface > interface_count or route_interface > interface_count or
					(hydro > 0 and hydro_value(hydro, 1) ~= id) or
					(interface > 0 and interface_value(interface, 1) ~= id) or
					(route_interface > 0 and
						(interface_value(route_interface, 2) ~= "bridge" and
						interface_value(route_interface, 2) ~= "ford" and
						interface_value(route_interface, 2) ~= "causeway")) or
					(route_interface > 0 and
						interface_value(route_interface, 3) == 0) then
				fail("fail_source", "packed lookup component differs")
			end
		end

		local function new_full_array(label, maximum)
			local result = counting_allocator:new_array(label, maximum)
			counting_allocator:grow(result, label, 0, maximum)
			return result
		end

		local column_start = new_full_array("planner_column_start", MAX_COLUMNS + 1)
		local run_values = new_full_array("planner_run_values", MAX_RUN_CELLS)
		local candidate_values = new_full_array("planner_candidate_values",
			MAX_CANDIDATES * RUN_STRIDE)
		local endpoints = new_full_array("planner_candidate_endpoints",
			MAX_CANDIDATES * 2)
		local plan = counting_allocator:new_map("planner_plan_handle", 14)
		local function plan_put(key, value)
			counting_allocator:map_put(plan, "planner_plan_handle", key, value)
		end
		plan_put("schema", PLAN_SCHEMA)
		plan_put("construction_identity", construction_identity)
		plan_put("generation", 0)
		plan_put("valid", false)
		plan_put("min_x", 0)
		plan_put("min_y", 0)
		plan_put("min_z", 0)
		plan_put("max_x", 0)
		plan_put("max_y", 0)
		plan_put("max_z", 0)
		plan_put("column_start", column_start)
		plan_put("run_values", run_values)
		plan_put("run_count", 0)
		plan_put("stable_refs", stable_refs)

		local metric_state = new_full_array("planner_metric_state", 10)
		metric_state[M_PLANNER_CONSTRUCTION] = 1
		metric_state[M_PLAN_IDENTITY] = 1
		metric_state[M_STABLE_REF_COUNT] = stable_count

		local planner
		local candidate_count = 0
		local current_min_y, current_max_y

		local function stable_ordinal(id, label)
			if id == nil then return 0 end
			if type(id) ~= "string" or id == "" then
				fail("fail_source", label .. " is not a stable ID")
			end
			local packed = relational_lookup[id]
			if packed == nil then fail("fail_source", label .. " is not interned") end
			local ordinal = packed % LOOKUP_BASE
			if stable_refs[ordinal] ~= id then
				fail("fail_source", label .. " lookup differs")
			end
			return ordinal
		end

		local function add_candidate(y_min, y_max, priority, opcode, role, policy,
				feature_id, interface_id)
			safe_integer(y_min, "candidate y_min", -MAX_SAFE, MAX_SAFE,
				"fail_bound")
			safe_integer(y_max, "candidate y_max", -MAX_SAFE, MAX_SAFE,
				"fail_bound")
			if y_min > y_max then return end
			if y_min < OWNER_MIN or y_max > OWNER_MAX then
				fail("fail_bound", "nonempty candidate crosses owner edges")
			end
			local clipped_min = math.max(y_min, current_min_y)
			local clipped_max = math.min(y_max, current_max_y)
			if clipped_min > clipped_max then return end
			candidate_count = candidate_count + 1
			if candidate_count > MAX_CANDIDATES then
				fail("fail_bound", "candidate-run bound exceeded")
			end
			local base = (candidate_count - 1) * RUN_STRIDE
			candidate_values[base + R_Y_MIN] = clipped_min
			candidate_values[base + R_Y_MAX] = clipped_max
			candidate_values[base + R_PRIORITY] = priority
			candidate_values[base + R_OPCODE] = opcode
			candidate_values[base + R_ROLE] = role
			candidate_values[base + R_POLICY] = policy
			candidate_values[base + R_FEATURE] = stable_ordinal(feature_id,
				"candidate feature")
			candidate_values[base + R_INTERFACE] = stable_ordinal(interface_id,
				"candidate interface")
			candidate_values[base + R_AUX] = AUX_NONE
		end

		local function hydrology_ordinal(id, depth, label)
			if id == nil then
				if depth ~= nil then fail("fail_source", label .. " depth lacks ID") end
				return 0
			end
			if type(id) ~= "string" or id == "" then
				fail("fail_source", label .. " ID differs")
			end
			local packed = relational_lookup[id]
			if packed == nil then fail("fail_source", label .. " ID is unknown") end
			local ordinal = math.floor(packed / LOOKUP_BASE) % LOOKUP_BASE
			if ordinal == 0 or hydro_value(ordinal, 3) ~= depth then
				fail("fail_source", label .. " profile depth differs")
			end
			return ordinal
		end

		local function route_relation(interface_id, wanted_kind,
				classified_ordinal, required)
			if interface_id == nil then
				if required then fail("fail_mask", wanted_kind .. " interface missing") end
				return 0
			end
			local packed = relational_lookup[interface_id]
			local ordinal = packed and math.floor(packed / LOOKUP_BASE_3) or 0
			if ordinal == 0 or interface_value(ordinal, 2) ~= wanted_kind or
					interface_value(ordinal, 3) ~= classified_ordinal then
				fail("fail_mask", wanted_kind .. " relation differs")
			end
			return ordinal
		end

		local function transition_relation(interface_id, wanted_kind)
			if type(interface_id) ~= "string" or interface_id == "" then
				fail("fail_mask", "transition interface missing")
			end
			local packed = relational_lookup[interface_id]
			local ordinal = packed and
				(math.floor(packed / LOOKUP_BASE_2) % LOOKUP_BASE) or 0
			if ordinal == 0 or interface_value(ordinal, 2) ~= wanted_kind or
					interface_value(ordinal, 4) == 0 or
					interface_value(ordinal, 5) == 0 then
				fail("fail_mask", "transition relation differs")
			end
			return ordinal
		end

		local function validate_column_tuple(x, z, water_class, zone_numeric_id,
				zone_id, logical_biome_id, race_region_id, terrain_y, water_y,
				classified_hydrology_id, classified_depth, functional_kind,
				functional_y, functional_feature_id, functional_interface_id,
				transition_kind, transition_interface_id, transition_upper_y,
				transition_lower_y, transition_progress_q, transition_face_mask,
				hard_foundation)
			if water_class ~= "land" and water_class ~= "planned_water" and
					water_class ~= "coastal_shelf" and water_class ~= "deep_ocean" and
					water_class ~= "immutable_dragon_channel" then
				fail("fail_source", "unknown water class")
			end
			if zone_numeric_id ~= nil then
				safe_integer(zone_numeric_id, "zone numeric ID", 1, MAX_SAFE,
					"fail_source")
			end
			if (zone_id ~= nil and (type(zone_id) ~= "string" or zone_id == "")) or
					(logical_biome_id ~= nil and
						(type(logical_biome_id) ~= "string" or logical_biome_id == "")) or
					(race_region_id ~= nil and
						(type(race_region_id) ~= "string" or race_region_id == "")) then
				fail("fail_source", "column identity scalar differs")
			end
			safe_integer(terrain_y, "terrain y", OWNER_MIN, OWNER_MAX, "fail_bound")
			if water_y ~= nil then
				safe_integer(water_y, "water y", OWNER_MIN, OWNER_MAX, "fail_bound")
			end
			local hydro_ordinal = hydrology_ordinal(classified_hydrology_id,
				classified_depth, "classified hydrology")
			if functional_kind == nil then
				if functional_y ~= nil or functional_feature_id ~= nil or
						functional_interface_id ~= nil then
					fail("fail_source", "nil functional kind carries values")
				end
			else
				if functional_kind ~= "anchor_platform" and
						functional_kind ~= "bridge_deck" and
						functional_kind ~= "causeway" and functional_kind ~= "ford" and
						functional_kind ~= "land_grade" and
						functional_kind ~= "tunnel_floor" then
					fail("fail_source", "unknown functional kind")
				end
				safe_integer(functional_y, "functional y", OWNER_MIN, OWNER_MAX,
					"fail_bound")
				if type(functional_feature_id) ~= "string" or
						functional_feature_id == "" then
					fail("fail_source", "functional feature is missing")
				end
				stable_ordinal(functional_feature_id, "functional feature")
				if functional_interface_id ~= nil then
					stable_ordinal(functional_interface_id, "functional interface")
				end
			end
			if transition_kind == nil then
				if transition_interface_id ~= nil or transition_upper_y ~= nil or
						transition_lower_y ~= nil or transition_progress_q ~= nil or
						transition_face_mask ~= nil then
					fail("fail_source", "nil transition carries values")
				end
			else
				if transition_kind ~= "rapid" and transition_kind ~= "waterfall" then
					fail("fail_source", "unknown transition kind")
				end
				transition_relation(transition_interface_id, transition_kind)
				safe_integer(transition_upper_y, "transition upper y", OWNER_MIN,
					OWNER_MAX, "fail_bound")
				safe_integer(transition_lower_y, "transition lower y", OWNER_MIN,
					OWNER_MAX, "fail_bound")
				if transition_face_mask ~= nil then
					if transition_kind ~= "waterfall" or
							transition_progress_q ~= nil then
						fail("fail_source", "contact transition tuple differs")
					end
					safe_integer(transition_face_mask, "transition face mask", 1, 15,
						"fail_source")
				else
					safe_integer(transition_progress_q, "transition progress", 0, 65536,
						"fail_source")
				end
			end
			if type(hard_foundation) ~= "boolean" then
				fail("fail_source", "hard-foundation scalar differs")
			end
			return hydro_ordinal
		end

		local function tuple_at(x, z)
			local water_class, zone_numeric_id, zone_id, logical_biome_id,
				race_region_id, terrain_y, water_y, classified_hydrology_id,
				classified_depth, functional_kind, functional_y,
				functional_feature_id, functional_interface_id, transition_kind,
				transition_interface_id, transition_upper_y, transition_lower_y,
				transition_progress_q, transition_face_mask, hard_foundation =
					column_values_at(x, z)
			validate_column_tuple(x, z, water_class, zone_numeric_id, zone_id,
				logical_biome_id, race_region_id, terrain_y, water_y,
				classified_hydrology_id, classified_depth, functional_kind,
				functional_y, functional_feature_id, functional_interface_id,
				transition_kind, transition_interface_id, transition_upper_y,
				transition_lower_y, transition_progress_q, transition_face_mask,
				hard_foundation)
			return water_class, zone_numeric_id, zone_id, logical_biome_id,
				race_region_id, terrain_y, water_y, classified_hydrology_id,
				classified_depth, functional_kind, functional_y,
				functional_feature_id, functional_interface_id, transition_kind,
				transition_interface_id, transition_upper_y, transition_lower_y,
				transition_progress_q, transition_face_mask, hard_foundation
		end

		local function named_wet_values(x, z)
			local _, _, _, _, _, _, water_y, classified_id, classified_depth,
				_, _, _, _, transition_kind, transition_id, _, transition_lower_y,
				_, transition_face_mask = tuple_at(x, z)
			if transition_kind == "waterfall" and transition_face_mask ~= nil then
				local relation_ordinal = transition_relation(transition_id, "waterfall")
				local hydro_ordinal = interface_value(relation_ordinal, 5)
				local depth = hydro_value(hydro_ordinal, 3)
				if depth <= 0 then fail("fail_mask", "contact lower profile is dry") end
				return hydro_ordinal, transition_lower_y,
					transition_lower_y - depth, relation_ordinal
			end
			if water_y ~= nil and classified_id ~= nil and
					transition_kind ~= "waterfall" then
				local hydro_ordinal = hydrology_ordinal(classified_id,
					classified_depth, "wet hydrology")
				if classified_depth <= 0 then
					fail("fail_mask", "named wet hydrology has dry profile")
				end
				local relation_ordinal = 0
				if transition_kind == "rapid" then
					relation_ordinal = transition_relation(transition_id, "rapid")
				end
				return hydro_ordinal, water_y, water_y - classified_depth,
					relation_ordinal
			end
			return 0, nil, nil, 0
		end

		local function relation_contains(relation_ordinal, hydro_ordinal)
			local first = interface_value(relation_ordinal, 6)
			local after = interface_after(relation_ordinal)
			for index = first, after - 1 do
				if interface_members[index] == hydro_ordinal then return true end
			end
			return false
		end

		local function candidate_is_p3_solid(opcode)
			return opcode == OP_BRIDGE_DECK or opcode == OP_BRIDGE_SUPPORT or
				opcode == OP_CAUSEWAY_FILL or opcode == OP_CAUSEWAY_SURFACE or
				opcode == OP_FORD_BED or opcode == OP_TUNNEL_FLOOR or
				opcode == OP_TUNNEL_ROOF or opcode == OP_TUNNEL_WALL
		end

		local function candidate_is_p3_open(opcode)
			return opcode == OP_BRIDGE_CLEAR or opcode == OP_CAUSEWAY_CULVERT or
				opcode == OP_CONTACT_FALL_CLEAR or opcode == OP_RECEIVER_OPEN or
				opcode == OP_TUNNEL_LUMEN or opcode == OP_RIVER_WATER
		end

		local function add_seal_subtracted(y_min, y_max, opcode, feature_id,
				interface_id)
			if y_min < AUTHORED_FLOOR then
				fail("fail_bound", "hydrology seal crosses authored floor")
			end
			local fragment_count = 1
			local low1, high1 = y_min, y_max
			local low2, high2, low3, high3
			local initial_candidates = candidate_count
			for candidate_index = 1, initial_candidates do
				local base = (candidate_index - 1) * RUN_STRIDE
				if candidate_values[base + R_PRIORITY] == 3 then
					local other_low = candidate_values[base + R_Y_MIN]
					local other_high = candidate_values[base + R_Y_MAX]
					local other_opcode = candidate_values[base + R_OPCODE]
					if other_high >= math.max(y_min, current_min_y) and
							other_low <= math.min(y_max, current_max_y) then
						if candidate_is_p3_open(other_opcode) then
							fail("fail_conflict", "hydrology seal overlaps P3 opening")
						elseif candidate_is_p3_solid(other_opcode) then
							local next_count = 0
							local nlow1, nhigh1, nlow2, nhigh2, nlow3, nhigh3
							for fragment = 1, fragment_count do
								local fragment_low, fragment_high
								if fragment == 1 then fragment_low, fragment_high = low1, high1
								elseif fragment == 2 then fragment_low, fragment_high = low2, high2
								else fragment_low, fragment_high = low3, high3 end
								if other_high < fragment_low or other_low > fragment_high then
									next_count = next_count + 1
									if next_count == 1 then nlow1, nhigh1 = fragment_low, fragment_high
									elseif next_count == 2 then nlow2, nhigh2 = fragment_low, fragment_high
									else nlow3, nhigh3 = fragment_low, fragment_high end
								else
									if fragment_low < other_low then
										next_count = next_count + 1
										if next_count == 1 then nlow1, nhigh1 = fragment_low, other_low - 1
										elseif next_count == 2 then nlow2, nhigh2 = fragment_low, other_low - 1
										else nlow3, nhigh3 = fragment_low, other_low - 1 end
									end
									if fragment_high > other_high then
										next_count = next_count + 1
										if next_count == 1 then nlow1, nhigh1 = other_high + 1, fragment_high
										elseif next_count == 2 then nlow2, nhigh2 = other_high + 1, fragment_high
										else nlow3, nhigh3 = other_high + 1, fragment_high end
									end
								end
							end
							if next_count > 3 then
								fail("fail_bound", "seal subtraction exceeds three fragments")
							end
							fragment_count = next_count
							low1, high1, low2, high2, low3, high3 =
								nlow1, nhigh1, nlow2, nhigh2, nlow3, nhigh3
						end
					end
				end
			end
			for fragment = 1, fragment_count do
				local low, high
				if fragment == 1 then low, high = low1, high1
				elseif fragment == 2 then low, high = low2, high2
				else low, high = low3, high3 end
				add_candidate(low, high, 3, opcode, ROLE_HYDROLOGY_SEAL,
					POLICY_SEAL_VOID, feature_id, interface_id)
			end
		end

		local function functional_values_at(x, z)
			local _, _, _, _, _, _, _, _, _, kind, functional_y, feature_id,
				interface_id = tuple_at(x, z)
			return kind, functional_y, feature_id, interface_id
		end

		local function metric_hydrology_at(x, z)
			local id, segment, numerator, denominator =
				hydrology_metric_values_at(x, z)
			if id == nil then
				if segment ~= nil or numerator ~= nil or denominator ~= nil then
					fail("fail_source", "nil hydrology metric carries values")
				end
				return nil, nil, nil, nil
			end
			if type(id) ~= "string" or id == "" or relational_lookup[id] == nil then
				fail("fail_source", "hydrology metric ID differs")
			end
			local packed = relational_lookup[id]
			local hydro = math.floor(packed / LOOKUP_BASE) % LOOKUP_BASE
			if hydro == 0 then fail("fail_source", "hydrology metric ID is unknown") end
			safe_integer(segment, "hydrology metric segment", 1, MAX_SAFE,
				"fail_source")
			safe_integer(numerator, "hydrology metric numerator", 0, MAX_SAFE,
				"fail_source")
			safe_integer(denominator, "hydrology metric denominator", 1, MAX_SAFE,
				"fail_source")
			return id, segment, numerator, denominator
		end

		local function validate_wet_profile(hydro_ordinal)
			local depth = hydro_value(hydro_ordinal, 3)
			if depth <= 0 or hydro_value(hydro_ordinal, 4) ~= 3 or
					hydro_value(hydro_ordinal, 5) ~= 2 then
				fail("fail_mask", "wet hydrology seal profile differs")
			end
			return depth
		end

		local function current_named_wet(water_y, classified_id,
				classified_depth, transition_kind, transition_id, transition_lower_y,
				transition_face_mask)
			if transition_kind == "waterfall" and transition_face_mask ~= nil then
				local relation_ordinal = transition_relation(transition_id, "waterfall")
				local hydro_ordinal = interface_value(relation_ordinal, 5)
				local depth = validate_wet_profile(hydro_ordinal)
				return hydro_ordinal, transition_lower_y,
					transition_lower_y - depth, relation_ordinal
			end
			if water_y ~= nil and classified_id ~= nil and
					transition_kind ~= "waterfall" then
				local hydro_ordinal = hydrology_ordinal(classified_id,
					classified_depth, "current wet hydrology")
				local depth = validate_wet_profile(hydro_ordinal)
				local relation_ordinal = 0
				if transition_kind == "rapid" then
					relation_ordinal = transition_relation(transition_id, "rapid")
				end
				return hydro_ordinal, water_y, water_y - depth, relation_ordinal
			end
			return 0, nil, nil, 0
		end

		local function scan_bank_samples(x, z)
			local sample_count = 0
			local first_hydro = 0
			local all_same = true
			local minimum_seal_y, maximum_water_y
			local smallest_id
			for dx = -2, 2 do
				for dz = -2, 2 do
					local distance = math.abs(dx) + math.abs(dz)
					if distance >= 1 and distance <= 2 then
						local hydro_ordinal, water_y, bed_y =
							named_wet_values(x + dx, z + dz)
						if hydro_ordinal > 0 then
							sample_count = sample_count + 1
							if first_hydro == 0 then first_hydro = hydro_ordinal
							elseif hydro_ordinal ~= first_hydro then all_same = false end
							local seal_y = bed_y - 2
							minimum_seal_y = minimum_seal_y and
								math.min(minimum_seal_y, seal_y) or seal_y
							maximum_water_y = maximum_water_y and
								math.max(maximum_water_y, water_y) or water_y
							local id = hydro_value(hydro_ordinal, 1)
							if smallest_id == nil or id < smallest_id then smallest_id = id end
						end
					end
				end
			end
			return sample_count, first_hydro, all_same, minimum_seal_y,
				maximum_water_y, smallest_id
		end

		local function bank_relation_for(x, z, sample_count)
			local best_relation = 0
			local best_id
			for relation_ordinal = 1, interface_count do
				local kind = interface_value(relation_ordinal, 2)
				if kind == "confluence" or kind == "rapid" or kind == "waterfall" then
					local compatible = true
					local observed = 0
					for dx = -2, 2 do
						for dz = -2, 2 do
							local distance = math.abs(dx) + math.abs(dz)
							if distance >= 1 and distance <= 2 then
								local hydro_ordinal = named_wet_values(x + dx, z + dz)
								if hydro_ordinal > 0 then
									observed = observed + 1
									if not relation_contains(relation_ordinal,
											hydro_ordinal) then compatible = false end
								end
							end
						end
					end
					local relation_id = interface_value(relation_ordinal, 1)
					if compatible and observed == sample_count and
							(best_id == nil or relation_id < best_id) then
						best_relation = relation_ordinal
						best_id = relation_id
					end
				end
			end
			if best_relation == 0 then
				fail("fail_conflict", "bank samples lack one accepted relation")
			end
			return best_relation
		end

		local function add_tunnel_collar(x, z, current_kind, current_feature_id)
			local tunnel_count = 0
			local shared_feature_id, shared_interface_id
			local minimum_floor, maximum_floor
			for direction = 1, 4 do
				local dx, dz = 0, 0
				if direction == 1 then dx = -1
				elseif direction == 2 then dx = 1
				elseif direction == 3 then dz = -1
				else dz = 1 end
				local kind, floor_y, feature_id, interface_id =
					functional_values_at(x + dx, z + dz)
				if kind == "tunnel_floor" then
					if type(feature_id) ~= "string" or type(interface_id) ~= "string" then
						fail("fail_mask", "tunnel sample identity is incomplete")
					end
					tunnel_count = tunnel_count + 1
					if shared_feature_id == nil then
						shared_feature_id, shared_interface_id = feature_id, interface_id
					elseif shared_feature_id ~= feature_id or
							shared_interface_id ~= interface_id then
						fail("fail_conflict", "tunnel collar samples disagree")
					end
					minimum_floor = minimum_floor and math.min(minimum_floor, floor_y) or
						floor_y
					maximum_floor = maximum_floor and math.max(maximum_floor, floor_y) or
						floor_y
				end
			end
			if tunnel_count == 0 or current_kind == "tunnel_floor" then return end
			if current_feature_id == shared_feature_id then return end
			if current_kind ~= nil then
				fail("fail_conflict", "tunnel collar overlaps another functional surface")
			end
			add_candidate(minimum_floor + 1, maximum_floor + 4, 3,
				OP_TUNNEL_WALL, ROLE_TUNNEL_WALL, POLICY_SEAL_VOID,
				shared_feature_id, shared_interface_id)
		end

		local function add_column_candidates(x, z)
			-- Scalar locals keep the Lua 5.1 closure below its 60-upvalue ceiling.
			local OP_BRIDGE_CLEAR, OP_BRIDGE_DECK, OP_BRIDGE_SUPPORT = 5, 6, 7
			local OP_CAUSEWAY_CULVERT, OP_CAUSEWAY_FILL,
				OP_CAUSEWAY_SURFACE = 8, 9, 10
			local OP_CONTACT_FALL_CLEAR, OP_FORD_BED = 11, 13
			local OP_FOUNDATION_CLEAR, OP_FOUNDATION_FILL,
				OP_FOUNDATION_SURFACE = 14, 15, 16
			local OP_HYDROLOGY_BANK_SEAL, OP_HYDROLOGY_BED_SEAL = 17, 18
			local OP_ORDINARY_WATER, OP_PATH_CLEAR, OP_PATH_FILL,
				OP_PATH_SURFACE = 19, 20, 21, 22
			local OP_RECEIVER_OPEN, OP_RIVER_WATER = 23, 25
			local OP_TERRAIN_CLEAR, OP_TERRAIN_FILL,
				OP_TERRAIN_SURFACE = 26, 27, 28
			local OP_TUNNEL_FLOOR, OP_TUNNEL_LUMEN,
				OP_TUNNEL_ROOF = 29, 30, 31
			local ROLE_AIR, ROLE_BRIDGE_DECK, ROLE_BRIDGE_SUPPORT = 1, 2, 3
			local ROLE_CAUSEWAY_CORE, ROLE_CAUSEWAY_SURFACE,
				ROLE_FORD_SURFACE = 4, 5, 6
			local ROLE_FOUNDATION_CORE, ROLE_FOUNDATION_SURFACE = 7, 8
			local ROLE_ORDINARY_WATER_SOURCE, ROLE_PATH_CORE,
				ROLE_PATH_SURFACE = 10, 11, 12
			local ROLE_RIVER_WATER_SOURCE, ROLE_STRATUM_AT_Y = 13, 14
			local ROLE_TUNNEL_FLOOR, ROLE_TUNNEL_WALL = 15, 16
			local POLICY_CUT_NATURAL, POLICY_FILL_VOID,
				POLICY_OPEN_ENGINEERED = 1, 3, 4
			local POLICY_SEAL_VOID, POLICY_SURFACE_EXACT,
				POLICY_WRITE_WATER = 5, 6, 7
			local water_class, zone_numeric_id, zone_id, logical_biome_id,
				race_region_id, terrain_y, water_y, classified_id, classified_depth,
				functional_kind, functional_y, functional_feature_id,
				functional_interface_id, transition_kind, transition_id,
				transition_upper_y, transition_lower_y, transition_progress_q,
				transition_face_mask, hard_foundation = tuple_at(x, z)
			local classified_ordinal = hydrology_ordinal(classified_id,
				classified_depth, "column hydrology")
			local clearance_y = water_y
			if clearance_y == nil and transition_upper_y ~= nil then
				clearance_y = math.max(transition_upper_y, transition_lower_y)
			end
			local surface_cap = clearance_y and math.max(terrain_y, clearance_y) or
				terrain_y
			if terrain_y < AUTHORED_FLOOR or terrain_y > surface_cap or
					surface_cap > OWNER_MAX then
				fail("fail_bound", "column surface interval differs")
			end

			local culvert = false
			local culvert_bed
			if functional_kind == "causeway" then
				if functional_y ~= terrain_y or clearance_y == nil or
						terrain_y < clearance_y + 1 then
					fail("fail_mask", "causeway scalar contract differs")
				end
				local relation_ordinal = route_relation(functional_interface_id,
					"causeway", classified_ordinal, false)
				if relation_ordinal > 0 and water_y ~= nil and classified_ordinal > 0 then
					local metric_id, _, numerator, denominator = metric_hydrology_at(x, z)
					if metric_id == classified_id and numerator <= denominator then
						culvert = true
						culvert_bed = water_y - validate_wet_profile(classified_ordinal)
						if culvert_bed >= water_y then
							fail("fail_mask", "causeway culvert bed differs")
						end
					end
				end
			end

			if hard_foundation and functional_kind == "anchor_platform" then
				if functional_y ~= terrain_y then
					fail("fail_mask", "foundation platform height differs")
				end
				add_candidate(AUTHORED_FLOOR, terrain_y - 1, 2,
					OP_FOUNDATION_FILL, ROLE_FOUNDATION_CORE, POLICY_FILL_VOID,
					functional_feature_id, functional_interface_id)
				add_candidate(terrain_y, terrain_y, 2, OP_FOUNDATION_SURFACE,
					ROLE_FOUNDATION_SURFACE, POLICY_SURFACE_EXACT,
					functional_feature_id, functional_interface_id)
				add_candidate(terrain_y + 1, terrain_y + 4, 2,
					OP_FOUNDATION_CLEAR, ROLE_AIR, POLICY_CUT_NATURAL,
					functional_feature_id, functional_interface_id)
			elseif functional_kind == "anchor_platform" or
					functional_kind == "land_grade" then
				if functional_y ~= terrain_y then
					fail("fail_mask", "path surface height differs")
				end
				add_candidate(AUTHORED_FLOOR, terrain_y - 1, 4, OP_PATH_FILL,
					ROLE_PATH_CORE, POLICY_FILL_VOID, functional_feature_id,
					functional_interface_id)
				add_candidate(terrain_y, terrain_y, 4, OP_PATH_SURFACE,
					ROLE_PATH_SURFACE, POLICY_SURFACE_EXACT, functional_feature_id,
					functional_interface_id)
				add_candidate(terrain_y + 1, terrain_y + 4, 4, OP_PATH_CLEAR,
					ROLE_AIR, POLICY_CUT_NATURAL, functional_feature_id,
					functional_interface_id)
			elseif functional_kind == "ford" then
				if water_y == nil or functional_y ~= terrain_y or
						terrain_y ~= water_y - 1 then
					fail("fail_mask", "ford scalar contract differs")
				end
				if functional_interface_id ~= nil then
					route_relation(functional_interface_id, "ford", classified_ordinal,
						true)
				end
				add_candidate(terrain_y, terrain_y, 3, OP_FORD_BED,
					ROLE_FORD_SURFACE, POLICY_SURFACE_EXACT, functional_feature_id,
					functional_interface_id)
			elseif functional_kind == "bridge_deck" then
				if clearance_y == nil then fail("fail_mask", "bridge clearance is nil") end
				local named = functional_interface_id ~= nil
				if named then
					route_relation(functional_interface_id, "bridge",
						classified_ordinal, true)
				end
				local required = named and 4 or 2
				if functional_y < clearance_y + required then
					fail("fail_guard", "bridge clearance threshold differs")
				end
				if functional_y + 5 > OWNER_MAX or
						functional_y + 5 <= surface_cap then
					fail("fail_guard", "bridge analytic headroom differs")
				end
				add_candidate(math.max(terrain_y + 1, clearance_y + 1),
					functional_y - 2, 3, OP_BRIDGE_CLEAR, ROLE_AIR,
					POLICY_OPEN_ENGINEERED, functional_feature_id,
					functional_interface_id)
				add_candidate(functional_y - 1, functional_y - 1, 3,
					OP_BRIDGE_SUPPORT, ROLE_BRIDGE_SUPPORT, POLICY_SEAL_VOID,
					functional_feature_id, functional_interface_id)
				add_candidate(functional_y, functional_y, 3, OP_BRIDGE_DECK,
					ROLE_BRIDGE_DECK, POLICY_SURFACE_EXACT, functional_feature_id,
					functional_interface_id)
				add_candidate(functional_y + 1, functional_y + 4, 3,
					OP_BRIDGE_CLEAR, ROLE_AIR, POLICY_CUT_NATURAL,
					functional_feature_id, functional_interface_id)
			elseif functional_kind == "causeway" then
				local fill_low = culvert and water_y + 1 or AUTHORED_FLOOR
				add_candidate(fill_low, terrain_y - 1, 3, OP_CAUSEWAY_FILL,
					ROLE_CAUSEWAY_CORE, POLICY_FILL_VOID, functional_feature_id,
					functional_interface_id)
				add_candidate(terrain_y, terrain_y, 3, OP_CAUSEWAY_SURFACE,
					ROLE_CAUSEWAY_SURFACE, POLICY_SURFACE_EXACT,
					functional_feature_id, functional_interface_id)
				if culvert then
					add_candidate(culvert_bed + 1, water_y, 3,
						OP_CAUSEWAY_CULVERT, ROLE_RIVER_WATER_SOURCE,
						POLICY_WRITE_WATER, functional_feature_id,
						functional_interface_id)
				end
				add_candidate(terrain_y + 1, terrain_y + 4, 4, OP_PATH_CLEAR,
					ROLE_AIR, POLICY_CUT_NATURAL, functional_feature_id,
					functional_interface_id)
			elseif functional_kind == "tunnel_floor" then
				if type(functional_interface_id) ~= "string" then
					fail("fail_mask", "tunnel interface is missing")
				end
				add_candidate(functional_y, functional_y, 3, OP_TUNNEL_FLOOR,
					ROLE_TUNNEL_FLOOR, POLICY_SURFACE_EXACT, functional_feature_id,
					functional_interface_id)
				add_candidate(functional_y + 1, functional_y + 4, 3,
					OP_TUNNEL_LUMEN, ROLE_AIR, POLICY_OPEN_ENGINEERED,
					functional_feature_id, functional_interface_id)
				add_candidate(functional_y + 5, functional_y + 5, 3,
					OP_TUNNEL_ROOF, ROLE_TUNNEL_WALL, POLICY_SEAL_VOID,
					functional_feature_id, functional_interface_id)
			end

			add_tunnel_collar(x, z, functional_kind, functional_feature_id)

			local wet_hydro, wet_surface, wet_bed, wet_relation = current_named_wet(
				water_y, classified_id, classified_depth, transition_kind,
				transition_id, transition_lower_y, transition_face_mask)
			if wet_hydro > 0 then
				add_seal_subtracted(wet_bed - 2, wet_bed,
					OP_HYDROLOGY_BED_SEAL, hydro_value(wet_hydro, 1),
					wet_relation > 0 and interface_value(wet_relation, 1) or nil)
			else
				local sample_count, _, all_same, seal_low, sample_high,
					smallest_id = scan_bank_samples(x, z)
				if sample_count > 0 then
					local bank_relation = 0
					if not all_same then
						bank_relation = bank_relation_for(x, z, sample_count)
					end
					local seal_high = math.min(terrain_y, sample_high)
					if seal_low <= seal_high then
						add_seal_subtracted(seal_low, seal_high,
							OP_HYDROLOGY_BANK_SEAL, smallest_id,
							bank_relation > 0 and
								interface_value(bank_relation, 1) or nil)
					end
				end
			end

			if transition_kind == "waterfall" and
					transition_face_mask ~= nil then
				local relation_ordinal = transition_relation(transition_id, "waterfall")
				local lower_hydro = interface_value(relation_ordinal, 5)
				local lower_depth = validate_wet_profile(lower_hydro)
				local lower_bed = transition_lower_y - lower_depth
				add_candidate(lower_bed + 1, transition_lower_y - 1, 6,
					OP_RIVER_WATER, ROLE_RIVER_WATER_SOURCE, POLICY_WRITE_WATER,
					hydro_value(lower_hydro, 1), transition_id)
				add_candidate(transition_lower_y, transition_lower_y, 6,
					OP_RECEIVER_OPEN, ROLE_AIR, POLICY_OPEN_ENGINEERED,
					hydro_value(lower_hydro, 1), transition_id)
				add_candidate(transition_lower_y + 1, OWNER_MAX, 3,
					OP_CONTACT_FALL_CLEAR, ROLE_AIR, POLICY_OPEN_ENGINEERED,
					hydro_value(lower_hydro, 1), transition_id)
			elseif water_y ~= nil and terrain_y < water_y then
				if classified_ordinal > 0 then
					add_candidate(terrain_y + 1, water_y, 6, OP_RIVER_WATER,
						ROLE_RIVER_WATER_SOURCE, POLICY_WRITE_WATER, classified_id,
						transition_id)
				else
					add_candidate(terrain_y + 1, water_y, 6, OP_ORDINARY_WATER,
						ROLE_ORDINARY_WATER_SOURCE, POLICY_WRITE_WATER, nil, nil)
				end
			end

			add_candidate(AUTHORED_FLOOR, terrain_y - 1, 5, OP_TERRAIN_FILL,
				ROLE_STRATUM_AT_Y, POLICY_FILL_VOID, nil, nil)
			add_candidate(terrain_y, terrain_y, 5, OP_TERRAIN_SURFACE,
				ROLE_STRATUM_AT_Y, POLICY_SURFACE_EXACT, nil, nil)
			add_candidate(surface_cap + 1, OWNER_MAX, 5, OP_TERRAIN_CLEAR,
				ROLE_AIR, POLICY_CUT_NATURAL, nil, nil)

		end

		local build_run_count = 0
		local build_column_first = 1

		local function semantic_equal(left_base, right_base, left_values,
				right_values)
			for offset = R_PRIORITY, R_AUX do
				if left_values[left_base + offset] ~=
						right_values[right_base + offset] then return false end
			end
			return true
		end

		local function append_resolved(y_min, y_max, winner_base)
			if build_run_count >= build_column_first then
				local previous_base = (build_run_count - 1) * RUN_STRIDE
				if run_values[previous_base + R_Y_MAX] + 1 == y_min and
						semantic_equal(previous_base, winner_base, run_values,
							candidate_values) then
					run_values[previous_base + R_Y_MAX] = y_max
					return
				end
			end
			build_run_count = build_run_count + 1
			if build_run_count > MAX_RESOLVED or
					build_run_count - build_column_first + 1 >
						MAX_RESOLVED_PER_COLUMN then
				fail("fail_bound", "resolved-run bound exceeded")
			end
			local output_base = (build_run_count - 1) * RUN_STRIDE
			run_values[output_base + R_Y_MIN] = y_min
			run_values[output_base + R_Y_MAX] = y_max
			for offset = R_PRIORITY, R_AUX do
				run_values[output_base + offset] = candidate_values[winner_base + offset]
			end
		end

		local function resolve_column()
			if candidate_count > metric_state[M_PEAK_CANDIDATES] then
				metric_state[M_PEAK_CANDIDATES] = candidate_count
			end
			local endpoint_count = candidate_count * 2
			for candidate_index = 1, candidate_count do
				local base = (candidate_index - 1) * RUN_STRIDE
				endpoints[candidate_index * 2 - 1] =
					candidate_values[base + R_Y_MIN]
				endpoints[candidate_index * 2] = candidate_values[base + R_Y_MAX] + 1
			end
			for index = 2, endpoint_count do
				local value = endpoints[index]
				local cursor = index - 1
				while cursor >= 1 and endpoints[cursor] > value do
					endpoints[cursor + 1] = endpoints[cursor]
					cursor = cursor - 1
				end
				endpoints[cursor + 1] = value
			end
			local unique_count = 0
			for index = 1, endpoint_count do
				if unique_count == 0 or endpoints[index] ~= endpoints[unique_count] then
					unique_count = unique_count + 1
					endpoints[unique_count] = endpoints[index]
				end
			end
			for endpoint_index = 1, unique_count - 1 do
				local y_min = endpoints[endpoint_index]
				local y_max = endpoints[endpoint_index + 1] - 1
				local winner_base
				local winner_priority
				for candidate_index = 1, candidate_count do
					local base = (candidate_index - 1) * RUN_STRIDE
					if candidate_values[base + R_Y_MIN] <= y_min and
							candidate_values[base + R_Y_MAX] >= y_max then
						local priority = candidate_values[base + R_PRIORITY]
						if winner_priority == nil or priority < winner_priority then
							winner_base, winner_priority = base, priority
						elseif priority == winner_priority and
								not semantic_equal(winner_base, base, candidate_values,
									candidate_values) then
							fail("fail_conflict", "non-identical same-priority overlap")
						end
					end
				end
				if winner_base ~= nil then append_resolved(y_min, y_max, winner_base) end
			end
			local resolved = build_run_count - build_column_first + 1
			if resolved < 0 then resolved = 0 end
			if resolved > metric_state[M_PEAK_RESOLVED_COLUMN] then
				metric_state[M_PEAK_RESOLVED_COLUMN] = resolved
			end
		end

		local function validate_position(value, label)
			if type(value) ~= "table" then fail("fail_bound", label .. " is not v3") end
			local count = 0
			for key in pairs(value) do
				if key ~= "x" and key ~= "y" and key ~= "z" then
					fail("fail_bound", label .. " has unexpected field")
				end
				count = count + 1
			end
			if count ~= 3 then fail("fail_bound", label .. " fields differ") end
			return safe_integer(value.x, label .. " x", OWNER_MIN, OWNER_MAX,
				"fail_bound"),
				safe_integer(value.y, label .. " y", OWNER_MIN, OWNER_MAX,
					"fail_bound"),
				safe_integer(value.z, label .. " z", OWNER_MIN, OWNER_MAX,
					"fail_bound")
		end

		local function plan_slice_core(min_x, min_y, min_z, max_x, max_y, max_z,
				x_count, z_count)
			plan.valid = false
			if plan.generation >= MAX_SAFE then
				fail("fail_bound", "plan generation cannot advance")
			end
			plan.generation = plan.generation + 1
			plan.min_x, plan.min_y, plan.min_z = min_x, min_y, min_z
			plan.max_x, plan.max_y, plan.max_z = max_x, max_y, max_z
			plan.run_count = 0
			build_run_count = 0
			current_min_y, current_max_y = min_y, max_y
			local column_index = 0
			for z = min_z, max_z do
				for x = min_x, max_x do
					column_index = column_index + 1
					column_start[column_index] = build_run_count + 1
					build_column_first = build_run_count + 1
					candidate_count = 0
					add_column_candidates(x, z)
					resolve_column()
				end
			end
			local column_count = x_count * z_count
			if column_index ~= column_count then
				fail("fail_bound", "column population differs")
			end
			column_start[column_count + 1] = build_run_count + 1
			plan.run_count = build_run_count
			if build_run_count > metric_state[M_PEAK_RESOLVED_SLICE] then
				metric_state[M_PEAK_RESOLVED_SLICE] = build_run_count
			end
			local run_cells = build_run_count * RUN_STRIDE
			if run_cells > metric_state[M_PEAK_RUN_CELLS] then
				metric_state[M_PEAK_RUN_CELLS] = run_cells
			end
			metric_state[M_REUSE_CALLS] = metric_state[M_REUSE_CALLS] + 1
			plan.valid = true
			return plan, plan.generation
		end

		local function planner_plan_slice(self, minp, maxp)
			if not rawequal(self, planner) then fail("fail_source", "planner self differs") end
			local min_x, min_y, min_z = validate_position(minp, "minp")
			local max_x, max_y, max_z = validate_position(maxp, "maxp")
			local x_count = max_x - min_x + 1
			local y_count = max_y - min_y + 1
			local z_count = max_z - min_z + 1
			if x_count < 1 or x_count > MAX_AXIS or y_count < 1 or
					y_count > MAX_AXIS or z_count < 1 or z_count > MAX_AXIS or
					x_count * z_count > MAX_COLUMNS then
				fail("fail_bound", "slice axis/count bound differs")
			end
			counting_allocator:enter_hotpath(HOTPATH_NAME)
			local ok, result, generation = pcall(plan_slice_core, min_x, min_y,
				min_z, max_x, max_y, max_z, x_count, z_count)
			counting_allocator:leave_hotpath(HOTPATH_NAME)
			if not ok then error(result, 0) end
			return result, generation
		end

		local function planner_metrics(self)
			if not rawequal(self, planner) then fail("fail_source", "planner self differs") end
			metric_state[M_METRICS_RESULTS] = metric_state[M_METRICS_RESULTS] + 1
			return {
				planner_construction_count = metric_state[M_PLANNER_CONSTRUCTION],
				plan_identity_count = metric_state[M_PLAN_IDENTITY],
				stable_ref_count = metric_state[M_STABLE_REF_COUNT],
				plan_slice_table_allocations = metric_state[M_PLAN_SLICE_ALLOCATIONS],
				peak_candidate_runs_per_column = metric_state[M_PEAK_CANDIDATES],
				peak_resolved_runs_per_column =
					metric_state[M_PEAK_RESOLVED_COLUMN],
				peak_resolved_runs_per_slice = metric_state[M_PEAK_RESOLVED_SLICE],
				peak_run_value_cells = metric_state[M_PEAK_RUN_CELLS],
				plan_buffer_reuse_calls = metric_state[M_REUSE_CALLS],
				metrics_result_table_allocations = metric_state[M_METRICS_RESULTS],
			}
		end

		planner = counting_allocator:new_map("planner_api", 2)
		counting_allocator:map_put(planner, "planner_api", "plan_slice",
			planner_plan_slice)
		counting_allocator:map_put(planner, "planner_api", "metrics",
			planner_metrics)
		return planner
	end

	return module
end
