-- Pure, disabled WP40 R5 typed column/Y-run planner.

local FIXTURE_MAX_SAFE = 9007199254740991
local FIXTURE_OWNER_MIN = -30912
local FIXTURE_OWNER_MAX = 30927
local FIXTURE_MAX_CANDIDATES = 16
local FIXTURE_MAX_RESOLVED = 31
local FIXTURE_RUN_STRIDE = 9
local OP_PRIORITY = {
	[5]=3,[6]=3,[7]=3,[8]=3,[9]=3,[10]=3,[11]=3,[13]=3,
	[14]=2,[15]=2,[16]=2,[17]=3,[18]=3,[19]=6,[20]=4,[21]=4,
	[22]=4,[23]=6,[25]=6,[26]=5,[27]=5,[28]=5,[29]=3,[30]=3,
	[31]=3,[32]=3,
}
local OP_ROLE = {
	[5]=1,[6]=2,[7]=3,[8]=13,[9]=4,[10]=5,[11]=1,[13]=6,
	[14]=1,[15]=7,[16]=8,[17]=9,[18]=9,[19]=10,[20]=1,[21]=11,
	[22]=12,[23]=1,[25]=13,[26]=1,[27]=14,[28]=14,[29]=15,
	[30]=1,[31]=16,[32]=16,
}
local OP_POLICY = {
	[5]=4,[6]=6,[7]=5,[8]=7,[9]=3,[10]=6,[11]=4,[13]=6,
	[14]=1,[15]=3,[16]=6,[17]=5,[18]=5,[19]=7,[20]=1,[21]=3,
	[22]=6,[23]=4,[25]=7,[26]=1,[27]=3,[28]=6,[29]=6,[30]=4,
	[31]=5,[32]=5,
}
local OP_POLICY_ALT = {[5]=1}

local function core_semantic_equal(left_base, right_base, left_values,
		right_values)
	for offset = 3, FIXTURE_RUN_STRIDE do
		if left_values[left_base + offset] ~= right_values[right_base + offset] then
			return false
		end
	end
	return true
end

local function resolve_candidates_core(candidate_values, candidate_count,
		permutation, endpoints, output_values, output_first, output_count,
		invalid_code, fail_core)
	local endpoint_count = candidate_count * 2
	for candidate_index = 1, candidate_count do
		local base = (candidate_index - 1) * FIXTURE_RUN_STRIDE
		endpoints[candidate_index * 2 - 1] = candidate_values[base + 1]
		endpoints[candidate_index * 2] = candidate_values[base + 2] + 1
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
		local priority_2_base, priority_3_base, priority_4_base
		local priority_5_base, priority_6_base
		for order_index = 1, candidate_count do
			local candidate_index = permutation and permutation[order_index] or
				order_index
			local base = (candidate_index - 1) * FIXTURE_RUN_STRIDE
			if candidate_values[base + 1] <= y_min and
					candidate_values[base + 2] >= y_max then
				local priority = candidate_values[base + 3]
				local same_priority_base
				if priority == 2 then
					same_priority_base = priority_2_base
					if priority_2_base == nil then priority_2_base = base end
				elseif priority == 3 then
					same_priority_base = priority_3_base
					if priority_3_base == nil then priority_3_base = base end
				elseif priority == 4 then
					same_priority_base = priority_4_base
					if priority_4_base == nil then priority_4_base = base end
				elseif priority == 5 then
					same_priority_base = priority_5_base
					if priority_5_base == nil then priority_5_base = base end
				elseif priority == 6 then
					same_priority_base = priority_6_base
					if priority_6_base == nil then priority_6_base = base end
				else
					fail_core(invalid_code, "candidate priority differs")
				end
				if same_priority_base ~= nil and
						not core_semantic_equal(same_priority_base, base,
							candidate_values, candidate_values) then
					fail_core("fail_conflict",
						"non-identical same-priority overlap")
				end
				if winner_priority == nil or priority < winner_priority then
					winner_base, winner_priority = base, priority
				end
			end
		end
		if winner_base ~= nil then
			if output_count >= output_first then
				local previous_base = (output_count - 1) * FIXTURE_RUN_STRIDE
				if output_values[previous_base + 2] + 1 == y_min and
						core_semantic_equal(previous_base, winner_base,
							output_values, candidate_values) then
					output_values[previous_base + 2] = y_max
					winner_base = nil
				end
			end
			if winner_base ~= nil then
				output_count = output_count + 1
				if output_count - output_first + 1 > FIXTURE_MAX_RESOLVED then
					fail_core("fail_bound", "resolved-run bound exceeded")
				end
				local output_base = (output_count - 1) * FIXTURE_RUN_STRIDE
				output_values[output_base + 1] = y_min
				output_values[output_base + 2] = y_max
				for offset = 3, FIXTURE_RUN_STRIDE do
					output_values[output_base + offset] =
						candidate_values[winner_base + offset]
				end
			end
		end
	end
	return output_count, output_count - output_first + 1
end

local function fixture_fail(code, message)
	error(code .. ": " .. message, 0)
end

local function fixture_integer(value, label, minimum, maximum)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fixture_fail("fail_fixture", label .. " is not a bounded integer")
	end
	return value
end

local function fixture_dense(values, expected, label)
	if type(values) ~= "table" or getmetatable(values) ~= nil then
		fixture_fail("fail_fixture", label .. " is not a plain array")
	end
	local count = 0
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > expected then
			fixture_fail("fail_fixture", label .. " has an out-of-range key")
		end
		count = count + 1
	end
	if count ~= expected then fixture_fail("fail_fixture", label .. " count differs") end
	for index = 1, expected do
		if rawget(values, index) == nil then
			fixture_fail("fail_fixture", label .. " has a hole")
		end
	end
end

local function resolve_candidates_fixture(candidate_values, candidate_count,
		permutation)
	candidate_count = fixture_integer(candidate_count, "candidate count", 0,
		FIXTURE_MAX_CANDIDATES)
	fixture_dense(candidate_values, candidate_count * FIXTURE_RUN_STRIDE,
		"candidate values")
	fixture_dense(permutation, candidate_count, "candidate permutation")
	local seen = {}
	for candidate_index = 1, candidate_count do
		local base = (candidate_index - 1) * FIXTURE_RUN_STRIDE
		fixture_integer(candidate_values[base + 1], "candidate y_min",
			FIXTURE_OWNER_MIN, FIXTURE_OWNER_MAX)
		fixture_integer(candidate_values[base + 2], "candidate y_max",
			candidate_values[base + 1], FIXTURE_OWNER_MAX)
		fixture_integer(candidate_values[base + 3], "candidate priority", 2, 6)
		local opcode = fixture_integer(candidate_values[base + 4],
			"candidate opcode", 1, 32)
		local role = fixture_integer(candidate_values[base + 5],
			"candidate role", 1, 16)
		local policy = fixture_integer(candidate_values[base + 6],
			"candidate policy", 1, 7)
		if OP_PRIORITY[opcode] ~= candidate_values[base + 3] or
				OP_ROLE[opcode] ~= role or
				(OP_POLICY[opcode] ~= policy and OP_POLICY_ALT[opcode] ~= policy) then
			fixture_fail("fail_fixture", "candidate opcode tuple differs")
		end
		fixture_integer(candidate_values[base + 7], "candidate feature", 0, 512)
		fixture_integer(candidate_values[base + 8], "candidate interface", 0, 512)
		fixture_integer(candidate_values[base + 9], "candidate aux", 0, 0)
		local ordinal = fixture_integer(permutation[candidate_index],
			"candidate permutation ordinal", 1, candidate_count)
		if seen[ordinal] then fixture_fail("fail_fixture", "permutation repeats") end
		seen[ordinal] = true
	end
	local endpoints = {}
	local output = {}
	local output_count = resolve_candidates_core(candidate_values, candidate_count,
		permutation, endpoints, output, 1, 0, "fail_fixture", fixture_fail)
	return output, output_count
end

local function planner_factory(allocator_factory)
	local MAX_SAFE = 9007199254740991
	local SOURCE_SCHEMA = "grug_wp40_r5_planner_source_v1"
	local PLAN_SCHEMA = "grug_wp40_r5_column_run_plan_v1"
	local LOOKUP_SCHEMA = "grug_wp40_r5_feature_lookup_v2"
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
		river_water_in = true,
		surface_cave_run_at = true,
		surface_cave_candidate_at_cell = true,
		surface_cave_cell_at = true,
		surface_cave_constants = true,
		coast_material_at = true,
		primary_relief_at = true,
		landmark_excluded_at = true,
		static_exclusion_values_at = true,
		housing_mask_id_at = true,
		functional_surface_values_at = true,
		hard_row_at = true,
		metrics = true,
	}
	local LOOKUP_FIELDS = {
		schema = true,
		allocator_identity = true,
		stable_refs = true,
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

	function module.new(planner_source, validated_manifest, feature_lookup,
			counting_allocator, construction_identity)
		-- The few vocabulary constants used by generic candidate helpers are
		-- local scalars so this Lua 5.1 constructor stays below 60 upvalues.
		local OP_BRIDGE_CLEAR, OP_BRIDGE_DECK, OP_BRIDGE_SUPPORT = 5, 6, 7
		local OP_CAUSEWAY_CULVERT, OP_CAUSEWAY_FILL,
			OP_CAUSEWAY_SURFACE = 8, 9, 10
		local OP_CONTACT_FALL_CLEAR, OP_FORD_BED = 11, 13
		local OP_RECEIVER_OPEN, OP_RIVER_WATER = 23, 25
		local OP_TUNNEL_FLOOR, OP_TUNNEL_ROOF, OP_TUNNEL_WALL = 29, 31, 32
		local OP_TUNNEL_LUMEN = 30
		local ROLE_HYDROLOGY_SEAL = 9
		local POLICY_SEAL_VOID = 5
		exact_raw_fields(planner_source, SOURCE_FIELDS, "planner source",
			"fail_source")
		if planner_source.schema ~= SOURCE_SCHEMA or
				type(planner_source.column_values_at) ~= "function" or
				type(planner_source.river_water_in) ~= "function" or
				type(planner_source.surface_cave_run_at) ~= "function" or
				type(planner_source.surface_cave_candidate_at_cell) ~= "function" or
				type(planner_source.coast_material_at) ~= "function" or
				type(planner_source.primary_relief_at) ~= "function" or
				type(planner_source.static_exclusion_values_at) ~= "function" or
				type(planner_source.housing_mask_id_at) ~= "function" or
				type(planner_source.functional_surface_values_at) ~= "function" or
				type(planner_source.hard_row_at) ~= "function" or
				type(planner_source.metrics) ~= "function" then
			fail("fail_source", "planner source API differs")
		end
		local column_values_at = planner_source.column_values_at
		local river_water_in = planner_source.river_water_in
		local surface_cave_run_at = planner_source.surface_cave_run_at

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
		local provenance_ok, provenance = pcall(allocator_factory_new,
			PLANNER_ALLOCATOR_DOMAIN, counting_allocator)
		if not provenance_ok or provenance ~= true then
			fail("fail_source", "planner allocator factory identity differs")
		end
		for name in pairs(ALLOCATOR_FIELDS) do
			if type(counting_allocator[name]) ~= "function" then
				fail("fail_source", "planner allocator method differs: " .. name)
			end
		end

		-- The feature lookup interns the anchor fittings' IDs (r5.lua). Any
		-- other feature or interface ID (roads, rivers) is ordinal 0.
		if type(feature_lookup) ~= "table" or
				feature_lookup.schema ~= LOOKUP_SCHEMA or
				not rawequal(feature_lookup.allocator_identity,
					counting_allocator) then
			fail("fail_source", "feature lookup provenance differs")
		end
		for key in pairs(LOOKUP_FIELDS) do
			if rawget(feature_lookup, key) == nil then
				fail("fail_source", "feature lookup is missing field " .. key)
			end
		end
		if type(construction_identity) ~= "table" or
				getmetatable(construction_identity) ~= nil then
			fail("fail_source", "construction identity is not opaque table")
		end
		for _ in pairs(construction_identity) do
			fail("fail_source", "construction identity is not empty")
		end

		local stable_refs = feature_lookup.stable_refs
		local stable_count = exact_dense_count(stable_refs, "stable refs",
			MAX_STABLE_REFS, "fail_source")
		local previous_ref
		for index = 1, stable_count do
			local id = stable_refs[index]
			if type(id) ~= "string" or id == "" or LOOKUP_FIELDS[id] or
					(previous_ref ~= nil and not (previous_ref < id)) or
					feature_lookup[id] ~= index then
				fail("fail_source", "stable refs are not canonical")
			end
			previous_ref = id
		end
		local lookup_key_count = 0
		for key, value in pairs(feature_lookup) do
			if not LOOKUP_FIELDS[key] and
					(type(key) ~= "string" or stable_refs[value] ~= key) then
				fail("fail_source", "feature lookup has an unknown key")
			end
			lookup_key_count = lookup_key_count + 1
		end
		if lookup_key_count ~= 3 + stable_count then
			fail("fail_source", "feature lookup key population differs")
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

		-- Interned feature ordinal of an ID; 0 for nil and for any ID the
		-- lookup does not intern.
		local function stable_ordinal(id, label)
			if id == nil then return 0 end
			if type(id) ~= "string" or id == "" then
				fail("fail_source", label .. " is not a stable ID")
			end
			return feature_lookup[id] or 0
		end

		local function add_candidate(y_min, y_max, priority, opcode, role, policy,
				feature_id, interface_id)
			safe_integer(y_min, "candidate y_min", -MAX_SAFE, MAX_SAFE,
				"fail_bound")
			safe_integer(y_max, "candidate y_max", -MAX_SAFE, MAX_SAFE,
				"fail_bound")
			if y_min > y_max then return end
			if OP_PRIORITY[opcode] ~= priority or OP_ROLE[opcode] ~= role or
					(OP_POLICY[opcode] ~= policy and OP_POLICY_ALT[opcode] ~= policy) then
				fail("fail_source", "candidate opcode tuple differs")
			end
			if y_min < AUTHORED_FLOOR then
				fail("fail_bound", "candidate crosses authored floor")
			end
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

		-- The column tuple (zones.lua). Inland water by column: the river-id
		-- slot holds the sealed water id of a wet river or lake column
		-- ("lake:<n>" is ordinary water; any other id, "river:<n>" or a lake's
		-- step face "outlet:<n>", is river water) and nothing
		-- is registered; its bed depth is `water_y - terrain_y`. Step faces
		-- carry a transition kind and their upper and lower surface y.
		local function validate_column_tuple(x, z, water_class, zone_numeric_id,
				zone_id, logical_biome_id, race_region_id, terrain_y, water_y,
				river_id, river_depth, functional_kind,
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
			if river_id == nil then
				if river_depth ~= nil then
					fail("fail_source", "river depth lacks a river")
				end
			elseif type(river_id) ~= "string" or river_id == "" or water_y == nil or
					river_depth ~= water_y - terrain_y then
				fail("fail_source", "river water column differs")
			end
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
				if functional_interface_id ~= nil and
						(type(functional_interface_id) ~= "string" or
						functional_interface_id == "") then
					fail("fail_source", "functional interface differs")
				end
			end
			-- A step face between two reaches (a water-water contact inside the
			-- channel): "rapid" or "fall" on a wet sealed column, its own surface
			-- as the upper y and the lower neighbour's as the lower y. No
			-- relation is registered; the water is written per column.
			if transition_kind ~= nil then
				if (transition_kind ~= "rapid" and transition_kind ~= "fall") or
						river_id == nil or transition_upper_y ~= water_y or
						transition_interface_id ~= nil or
						transition_progress_q ~= nil or transition_face_mask ~= nil then
					fail("fail_source", "step transition differs")
				end
				safe_integer(transition_lower_y, "step lower y", OWNER_MIN,
					transition_upper_y - 1, "fail_source")
			elseif transition_interface_id ~= nil or
					transition_upper_y ~= nil or transition_lower_y ~= nil or
					transition_progress_q ~= nil or transition_face_mask ~= nil then
				fail("fail_source", "nil step transition carries values")
			end
			if type(hard_foundation) ~= "boolean" then
				fail("fail_source", "hard-foundation scalar differs")
			end
		end

		local function tuple_at(x, z)
			local water_class, zone_numeric_id, zone_id, logical_biome_id,
				race_region_id, terrain_y, water_y, river_id,
				river_depth, functional_kind, functional_y,
				functional_feature_id, functional_interface_id, transition_kind,
				transition_interface_id, transition_upper_y, transition_lower_y,
				transition_progress_q, transition_face_mask, hard_foundation =
					column_values_at(x, z)
			validate_column_tuple(x, z, water_class, zone_numeric_id, zone_id,
				logical_biome_id, race_region_id, terrain_y, water_y,
				river_id, river_depth, functional_kind,
				functional_y, functional_feature_id, functional_interface_id,
				transition_kind, transition_interface_id, transition_upper_y,
				transition_lower_y, transition_progress_q, transition_face_mask,
				hard_foundation)
			return water_class, zone_numeric_id, zone_id, logical_biome_id,
				race_region_id, terrain_y, water_y, river_id,
				river_depth, functional_kind, functional_y,
				functional_feature_id, functional_interface_id, transition_kind,
				transition_interface_id, transition_upper_y, transition_lower_y,
				transition_progress_q, transition_face_mask, hard_foundation
		end

		-- Bed y and surface y of a wet sealed (river or lake) column; nil for
		-- every other column. The bed of such a column is its terrain.
		local function wet_river_at(x, z)
			local _, _, _, _, _, terrain_y, water_y, river_id = tuple_at(x, z)
			if river_id ~= nil and terrain_y < water_y then
				return terrain_y, water_y
			end
			return nil, nil
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

		-- Bank seal of a column that is not wet sealed water: from two below
		-- the lowest neighbouring river/lake bed up to the highest neighbouring
		-- surface (capped at the column's terrain), over the owner plus a
		-- two-column diamond. Only scanned when such water may lie near the
		-- slice.
		local river_near = false
		local function bank_seal_values(x, z)
			local seal_low, water_high
			for dx = -2, 2 do
				for dz = -2, 2 do
					local distance = math.abs(dx) + math.abs(dz)
					if distance >= 1 and distance <= 2 then
						local bed_y, surface_y = wet_river_at(x + dx, z + dz)
						if bed_y ~= nil then
							seal_low = seal_low and math.min(seal_low, bed_y - 2) or
								bed_y - 2
							water_high = water_high and math.max(water_high, surface_y) or
								surface_y
						end
					end
				end
			end
			return seal_low, water_high
		end

		local function add_column_candidates(x, z)
			-- Scalar locals keep the Lua 5.1 closure below its 60-upvalue ceiling.
			local OP_BRIDGE_CLEAR, OP_BRIDGE_DECK, OP_BRIDGE_SUPPORT = 5, 6, 7
			local OP_CAUSEWAY_FILL, OP_CAUSEWAY_SURFACE = 9, 10
			local OP_FORD_BED = 13
			local OP_FOUNDATION_CLEAR, OP_FOUNDATION_FILL,
				OP_FOUNDATION_SURFACE = 14, 15, 16
			local OP_HYDROLOGY_BANK_SEAL, OP_HYDROLOGY_BED_SEAL = 17, 18
			local OP_ORDINARY_WATER, OP_PATH_CLEAR, OP_PATH_FILL,
				OP_PATH_SURFACE = 19, 20, 21, 22
			local OP_RIVER_WATER = 25
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
			local _, _, _, _, _, terrain_y, water_y, river_id, _,
				functional_kind, functional_y, functional_feature_id,
				functional_interface_id, _, _, _, _, _, _, hard_foundation =
					tuple_at(x, z)
			local clearance_y = water_y
			local surface_cap = clearance_y and math.max(terrain_y, clearance_y) or
				terrain_y
			if terrain_y < AUTHORED_FLOOR or terrain_y > surface_cap or
					surface_cap > OWNER_MAX then
				fail("fail_bound", "column surface interval differs")
			end
			if functional_kind == "causeway" and (functional_y ~= terrain_y or
					clearance_y == nil or terrain_y < clearance_y + 1) then
				fail("fail_mask", "causeway scalar contract differs")
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
				if water_y == nil or functional_y ~= terrain_y then
					fail("fail_mask", "ford scalar contract differs")
				end
				add_candidate(terrain_y, terrain_y, 3, OP_FORD_BED,
					ROLE_FORD_SURFACE, POLICY_SURFACE_EXACT, functional_feature_id,
					functional_interface_id)
			elseif functional_kind == "bridge_deck" then
				if clearance_y == nil then fail("fail_mask", "bridge clearance is nil") end
				-- A bridge with a named interface keeps four nodes of
				-- clearance, an unnamed one two.
				local required = functional_interface_id ~= nil and 4 or 2
				if functional_y < clearance_y + required then
					fail("fail_guard", "bridge clearance threshold differs")
				end
				if functional_y + 4 > OWNER_MAX then
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
				add_candidate(AUTHORED_FLOOR, terrain_y - 1, 3, OP_CAUSEWAY_FILL,
					ROLE_CAUSEWAY_CORE, POLICY_FILL_VOID, functional_feature_id,
					functional_interface_id)
				add_candidate(terrain_y, terrain_y, 3, OP_CAUSEWAY_SURFACE,
					ROLE_CAUSEWAY_SURFACE, POLICY_SURFACE_EXACT,
					functional_feature_id, functional_interface_id)
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

			-- Inland water by column: a wet river or lake column seals its bed
			-- (three layers down from its terrain), a river holds range-2 river
			-- water and a lake ordinary water; sea and bay columns hold ordinary
			-- water. A column beside sealed water gets a bank seal.
			local wet = water_y ~= nil and terrain_y < water_y
			if river_id ~= nil and wet then
				-- tripwire: the bucket lookup must know every sealed column, or
				-- the bank seals around it would be skipped
				if not river_near then
					fail("fail_source", "sealed water column outside river_water_in")
				end
				add_seal_subtracted(terrain_y - 2, terrain_y,
					OP_HYDROLOGY_BED_SEAL, nil, nil)
			elseif river_near then
				local seal_low, water_high = bank_seal_values(x, z)
				if seal_low ~= nil then
					local seal_high = math.min(terrain_y, water_high)
					if seal_low <= seal_high then
						add_seal_subtracted(seal_low, seal_high,
							OP_HYDROLOGY_BANK_SEAL, nil, nil)
					end
				end
			end
			if wet then
				if river_id ~= nil and river_id:sub(1, 5) ~= "lake:" then
					add_candidate(terrain_y + 1, water_y, 6, OP_RIVER_WATER,
						ROLE_RIVER_WATER_SOURCE, POLICY_WRITE_WATER, nil, nil)
				else
					add_candidate(terrain_y + 1, water_y, 6, OP_ORDINARY_WATER,
						ROLE_ORDINARY_WATER_SOURCE, POLICY_WRITE_WATER, nil, nil)
				end
			end

			local cave_low, cave_high = surface_cave_run_at(x, z)
			if cave_low ~= nil then
				safe_integer(cave_low, "surface cave low", AUTHORED_FLOOR, OWNER_MAX,
					"fail_source")
				safe_integer(cave_high, "surface cave high", cave_low, OWNER_MAX,
					"fail_source")
				add_candidate(AUTHORED_FLOOR, math.min(terrain_y - 1, cave_low - 1), 5,
					OP_TERRAIN_FILL, ROLE_STRATUM_AT_Y, POLICY_FILL_VOID, nil, nil)
				add_candidate(math.max(AUTHORED_FLOOR, cave_high + 1), terrain_y - 1, 5,
					OP_TERRAIN_FILL, ROLE_STRATUM_AT_Y, POLICY_FILL_VOID, nil, nil)
				if terrain_y < cave_low or terrain_y > cave_high then
					add_candidate(terrain_y, terrain_y, 5, OP_TERRAIN_SURFACE,
						ROLE_STRATUM_AT_Y, POLICY_SURFACE_EXACT, nil, nil)
				end
				add_candidate(cave_low, cave_high, 5, OP_TERRAIN_CLEAR, ROLE_AIR,
					POLICY_CUT_NATURAL, nil, nil)
			else
				add_candidate(AUTHORED_FLOOR, terrain_y - 1, 5, OP_TERRAIN_FILL,
					ROLE_STRATUM_AT_Y, POLICY_FILL_VOID, nil, nil)
				add_candidate(terrain_y, terrain_y, 5, OP_TERRAIN_SURFACE,
					ROLE_STRATUM_AT_Y, POLICY_SURFACE_EXACT, nil, nil)
			end
			add_candidate(surface_cap + 1, OWNER_MAX, 5, OP_TERRAIN_CLEAR,
				ROLE_AIR, POLICY_CUT_NATURAL, nil, nil)

		end

		local build_run_count = 0
		local build_column_first = 1

		local function resolve_column()
			if candidate_count > metric_state[M_PEAK_CANDIDATES] then
				metric_state[M_PEAK_CANDIDATES] = candidate_count
			end
			local resolved
			build_run_count, resolved = resolve_candidates_core(candidate_values,
				candidate_count, nil, endpoints, run_values, build_column_first,
				build_run_count, "fail_source", fail)
			if build_run_count > MAX_RESOLVED or resolved > MAX_RESOLVED_PER_COLUMN then
				fail("fail_bound", "resolved-run bound exceeded")
			end
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
			river_near = river_water_in(min_x - 2, min_z - 2, max_x + 2,
				max_z + 2) == true
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

return planner_factory, resolve_candidates_fixture
