-- Pure, disabled WP40 R5 VoxelManip adapter.

local FIXTURE_MAX_SAFE = 9007199254740991

local function replacement_outcome_core(policy_id, class_id, family_id,
		liquid_kind, ordinary_family_id, river_family_id)
	if class_id == 2 or class_id == 3 or class_id == 9 then
		return 2
	end
	if policy_id == 2 then return 0 end
	if class_id == 4 and
			(not (family_id == ordinary_family_id or
				family_id == river_family_id) or
			(liquid_kind ~= 1 and liquid_kind ~= 2)) then
		return 2
	end
	if policy_id == 3 then
		if class_id == 1 or class_id == 4 or class_id == 8 then return 1 end
		return 0
	elseif policy_id == 1 then
		if class_id == 1 then return 0 end
		return 1
	elseif policy_id == 6 or policy_id == 7 then
		return 1
	elseif policy_id == 5 then
		if class_id == 1 or class_id == 4 or class_id == 8 then return 1 end
		return 0
	elseif policy_id == 4 then
		if class_id == 1 then return 0 end
		return 1
	end
	return 2
end

local function replacement_outcome_fixture(...)
	if select("#", ...) ~= 6 then
		error("fail_fixture: replacement fixture arity differs", 0)
	end
	local policy_id, class_id, family_id, liquid_kind,
		ordinary_family_id, river_family_id = ...
	if type(policy_id) ~= "number" or policy_id % 1 ~= 0 or
			policy_id < 1 or policy_id > 7 or
			type(class_id) ~= "number" or class_id % 1 ~= 0 or
			class_id < 1 or class_id > 11 or
			type(family_id) ~= "number" or family_id % 1 ~= 0 or
			family_id < 0 or family_id > FIXTURE_MAX_SAFE or
			type(liquid_kind) ~= "number" or liquid_kind % 1 ~= 0 or
			liquid_kind < 0 or liquid_kind > 2 or
			type(ordinary_family_id) ~= "number" or
			ordinary_family_id % 1 ~= 0 or ordinary_family_id < 1 or
			ordinary_family_id > FIXTURE_MAX_SAFE or
			type(river_family_id) ~= "number" or river_family_id % 1 ~= 0 or
			river_family_id < 1 or river_family_id > FIXTURE_MAX_SAFE or
			(liquid_kind == 0) ~= (family_id == 0) then
		error("fail_fixture: replacement fixture scalar domain differs", 0)
	end
	return replacement_outcome_core(policy_id, class_id, family_id, liquid_kind,
		ordinary_family_id, river_family_id)
end

local function adapter_factory(allocator_factory)
	local MAX_SAFE = 9007199254740991
	local PLAN_SCHEMA = "grug_wp40_r5_column_run_plan_v1"
	local CONTENT_SCHEMA = "grug_wp40_r5_content_contract_v1"
	local CONTEXT_SCHEMA = "grug_wp40_r5_mapgen_context_v1"
	local MANIFEST_SCHEMA = "grug_wp40_r5_mapgen_manifest_v1"
	local MANIFEST_MARKER = "grug_wp40_r5_validated_manifest_v1"
	local ADAPTER_ALLOCATOR_DOMAIN = "grug_wp40_r5_adapter_allocator_v1"
	local HOTPATH_NAME = "adapter_apply"
	local OWNER_MIN = -30912
	local OWNER_MAX = 30927
	local HEIGHTMAP_SENTINEL = -31007
	local MAX_COLUMNS = 6400
	local MAX_RUNS = 198400
	local RUN_STRIDE = 9
	local MAX_VOLUME = 112 * 112 * 112
	local MAX_TARGET_SLOTS = 16 * 80
	local TARGET_STRIDE = 13
	local MAX_SEED_RUNS = 6400
	local TARGET_CAPACITY = MAX_TARGET_SLOTS * TARGET_STRIDE
	local SEED_COORD_OFFSET = 30928
	local SEED_COORD_BASE = 62000
	local SCRATCH_CAPACITY = TARGET_CAPACITY + MAX_SEED_RUNS

	local R_Y_MIN = 1
	local R_Y_MAX = 2
	local R_PRIORITY = 3
	local R_OPCODE = 4
	local R_ROLE = 5
	local R_POLICY = 6
	local R_FEATURE = 7
	local R_INTERFACE = 8
	local R_AUX = 9

	local ROLE_AIR = 1
	local ROLE_ORDINARY_WATER_SOURCE = 10
	local ROLE_RIVER_WATER_SOURCE = 13
	local ROLE_STRATUM_AT_Y = 14
	local MAX_ROLE = 16

	local POLICY_CUT_NATURAL = 1
	local POLICY_DEEP_EXACT_HOST = 2
	local POLICY_FILL_VOID = 3
	local POLICY_OPEN_ENGINEERED = 4
	local POLICY_SEAL_VOID = 5
	local POLICY_SURFACE_EXACT = 6
	local POLICY_WRITE_WATER = 7

	local CLASS_AIR = 1
	local CLASS_FOREIGN = 2
	local CLASS_IGNORE = 3
	local CLASS_LIQUID = 4
	local CLASS_NATIVE_ORE = 5
	local CLASS_NATURAL_HOST = 6
	local CLASS_NATURAL_SURFACE = 7
	local CLASS_NATURAL_VEGETATION = 8
	local CLASS_UNKNOWN = 9
	local CLASS_WP43_RESOURCE = 10
	local CLASS_WP43_STRATUM = 11

	local TARGET_AIR = 0
	local TARGET_SOLID = 1
	local TARGET_WATER_SOURCE = 2
	local PARAM2_PRESERVE = 0
	local PARAM2_EXACT = 1
	local LIQUID_NONE = 0
	local LIQUID_SOURCE = 1
	local LIQUID_FLOWING = 2

	local OUTCOME_NOOP = 0
	local OUTCOME_WRITE = 1
	local OUTCOME_REJECT = 2

	local M_APPLY_ALLOCATIONS = 1
	local M_EMERGED_EXTERNAL = 2
	local M_HEIGHTMAP_ENTRIES = 3
	local M_CLASSIFIED_COLUMNS = 4
	local M_PLANNED_COLUMNS = 5
	local M_MODIFIED_VOXELS = 6
	local M_CONTENT_DIRTY_COLUMNS = 7
	local M_PARAM2_DIRTY_COLUMNS = 8
	local M_LIGHT_DIRTY_COLUMNS = 9
	local M_LIQUID_DIRTY_COLUMNS = 10
	local M_LIGHT_SEED_RUNS = 11
	local M_PEAK_LIGHT_SEED_RUNS = 12
	local M_VM_GET_EMERGED = 13
	local M_VM_GET_DATA = 14
	local M_VM_SET_DATA = 15
	local M_VM_GET_PARAM2 = 16
	local M_VM_SET_PARAM2 = 17
	local M_VM_GET_LIGHT = 18
	local M_VM_SET_LIGHTING = 19
	local M_VM_CALC_LIGHTING = 20
	local M_VM_SET_LIGHT_DATA = 21
	local M_VM_UPDATE_LIQUIDS = 22
	local M_METRICS_RESULTS = 23
	local METRIC_COUNT = 23

	local OP_PRIORITY = {
		[5] = 3, [6] = 3, [7] = 3, [8] = 3, [9] = 3, [10] = 3,
		[11] = 3, [13] = 3, [14] = 2, [15] = 2, [16] = 2,
		[17] = 3, [18] = 3, [19] = 6, [20] = 4, [21] = 4,
		[22] = 4, [23] = 6, [25] = 6, [26] = 5, [27] = 5,
		[28] = 5, [29] = 3, [30] = 3, [31] = 3, [32] = 3,
	}
	local OP_ROLE = {
		[5] = 1, [6] = 2, [7] = 3, [8] = 13, [9] = 4, [10] = 5,
		[11] = 1, [13] = 6, [14] = 1, [15] = 7, [16] = 8,
		[17] = 9, [18] = 9, [19] = 10, [20] = 1, [21] = 11,
		[22] = 12, [23] = 1, [25] = 13, [26] = 1, [27] = 14,
		[28] = 14, [29] = 15, [30] = 1, [31] = 16, [32] = 16,
	}
	local OP_POLICY = {
		[5] = 4, [6] = 6, [7] = 5, [8] = 7, [9] = 3, [10] = 6,
		[11] = 4, [13] = 6, [14] = 1, [15] = 3, [16] = 6,
		[17] = 5, [18] = 5, [19] = 7, [20] = 1, [21] = 3,
		[22] = 6, [23] = 4, [25] = 7, [26] = 1, [27] = 3,
		[28] = 6, [29] = 6, [30] = 4, [31] = 5, [32] = 5,
	}
	local OP_POLICY_ALT = {
		[5] = POLICY_CUT_NATURAL,
	}

	local FACE_DX = {-1, 1, 0, 0, 0, 0}
	local FACE_DY = {0, 0, -1, 1, 0, 0}
	local FACE_DZ = {0, 0, 0, 0, -1, 1}

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
	local CONTENT_FIELDS = {
		schema = true,
		ignore_cid = true,
		ordinary_water_family_id = true,
		river_water_family_id = true,
		resolve = true,
		classify = true,
		metrics = true,
	}
	local CONTEXT_FIELDS = {
		schema = true,
		get_heightmap = true,
		metrics = true,
	}
	local PLAN_FIELDS = {
		schema = true,
		construction_identity = true,
		generation = true,
		valid = true,
		min_x = true,
		min_y = true,
		min_z = true,
		max_x = true,
		max_y = true,
		max_z = true,
		column_start = true,
		run_values = true,
		run_count = true,
		stable_refs = true,
	}
	local RESULT_NOOP_EMPTY = "noop_empty_plan"
	local RESULT_NOOP_EQUAL = "noop_equal_content"
	local RESULT_P = "applied_p"
	local RESULT_PQ = "applied_pq"
	local RESULT_C = "applied_c"
	local RESULT_CP = "applied_cp"
	local RESULT_CL = "applied_cl"
	local RESULT_CPL = "applied_cpl"
	local RESULT_CQ = "applied_cq"
	local RESULT_CPQ = "applied_cpq"
	local RESULT_CLQ = "applied_clq"
	local RESULT_CPLQ = "applied_cplq"

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	local function safe_integer(value, label, minimum, maximum, code)
		minimum = minimum or -MAX_SAFE
		maximum = maximum or MAX_SAFE
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 or
				value < minimum or value > maximum then
			fail(code or "fail_bounds", label .. " is not a safe integer")
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
				fail(code, label .. " has an unexpected field")
			end
			count = count + 1
		end
		local expected = 0
		for key in pairs(allowed) do
			expected = expected + 1
			if rawget(value, key) == nil then
				fail(code, label .. " is missing a field")
			end
		end
		if count ~= expected then fail(code, label .. " field count differs") end
	end

	local function check_position(value, label)
		if type(value) ~= "table" then fail("fail_bounds", label .. " missing") end
		safe_integer(value.x, label .. ".x")
		safe_integer(value.y, label .. ".y")
		safe_integer(value.z, label .. ".z")
	end

	local function require_manifest(manifest)
		exact_raw_fields(manifest, MANIFEST_FIELDS, "manifest", "fail_manifest")
		if getmetatable(manifest) ~= MANIFEST_MARKER or
				manifest.schema ~= MANIFEST_SCHEMA or
				manifest.engine_commit ~=
					"df04879066de6eb94ca43996822a6dfacc74feca" or
				manifest.mg_name ~= "v7" or manifest.water_level ~= 1 or
				manifest.mapgen_limit ~= 31007 or manifest.chunksize ~= 5 or
				manifest.central_owner_y_min ~= OWNER_MIN or
				manifest.central_owner_y_max ~= OWNER_MAX or
				manifest.heightmap_entries ~= 6400 or
				manifest.heightmap_sentinel ~= HEIGHTMAP_SENTINEL or
				manifest.heightmap_order ~= "x_fast_z_outer" or
				manifest.emerge_threads ~= 1 or
				manifest.engine_emerge_setting ~= "num_emerge_threads" or
				manifest.mg_flags ~=
					"biomes,caves,decorations,dungeons,light,ores" or
				manifest.mgv7_spflags ~= "caverns,mountains,ridges" or
				manifest.mgv7_dungeon_ymin ~= -31000 or
				manifest.mgv7_dungeon_ymax ~= -193 or
				manifest.authored_floor ~= -37 or
				manifest.force_native_dungeon ~= false then
			fail("fail_manifest", "validated manifest bytes differ")
		end
		local block_size = 16
		local limit_blocks = math.floor(manifest.mapgen_limit / block_size)
		local limit_min = -limit_blocks * block_size
		local limit_max = (limit_blocks + 1) * block_size - 1
		local central_min = math.ceil(-manifest.chunksize / 2) * block_size
		local chunk_nodes = manifest.chunksize * block_size
		local central_max = central_min + chunk_nodes - 1
		local full_min = central_min - block_size
		local full_max = central_max + block_size
		local count_min = math.max(math.floor((full_min - limit_min) /
			chunk_nodes), 0)
		local count_max = math.max(math.floor((limit_max - full_max) /
			chunk_nodes), 0)
		if central_min - count_min * chunk_nodes ~= OWNER_MIN or
				central_max + count_max * chunk_nodes ~= OWNER_MAX then
			fail("fail_manifest", "pinned owner-edge formula differs")
		end
	end

	local function class_tuple_valid(class_id, family_id, liquid_kind,
			liquid_level, floodable, paramtype_light, light_propagates,
			sunlight_propagates, light_source)
		if type(class_id) ~= "number" or class_id % 1 ~= 0 or
				class_id < CLASS_AIR or class_id > CLASS_WP43_STRATUM or
				type(family_id) ~= "number" or family_id % 1 ~= 0 or
				family_id < 0 or family_id > MAX_SAFE or
				type(liquid_kind) ~= "number" or liquid_kind % 1 ~= 0 or
				liquid_kind < LIQUID_NONE or liquid_kind > LIQUID_FLOWING or
				type(liquid_level) ~= "number" or liquid_level % 1 ~= 0 or
				liquid_level < 0 or liquid_level > 7 or
				type(floodable) ~= "boolean" or
				type(paramtype_light) ~= "boolean" or
				type(light_propagates) ~= "boolean" or
				type(sunlight_propagates) ~= "boolean" or
				type(light_source) ~= "number" or light_source % 1 ~= 0 or
				light_source < 0 or light_source > 14 then
			return false
		end
		if liquid_kind == LIQUID_NONE then
			return family_id == 0 and liquid_level == 0
		end
		return family_id > 0 and
			(liquid_kind ~= LIQUID_SOURCE or liquid_level == 0)
	end

	-- One pre-construction dependency table keeps the constructed adapter's
	-- closure graph below Lua 5.1's 60-upvalue limit.  It is part of the module
	-- factory layer and therefore exists before r5_module.new.
	local K = {
		ADAPTER_ALLOCATOR_DOMAIN = ADAPTER_ALLOCATOR_DOMAIN,
		ALLOCATOR_FIELDS = ALLOCATOR_FIELDS,
		CLASS_AIR = CLASS_AIR,
		CLASS_FOREIGN = CLASS_FOREIGN,
		CLASS_IGNORE = CLASS_IGNORE,
		CLASS_LIQUID = CLASS_LIQUID,
		CLASS_NATURAL_HOST = CLASS_NATURAL_HOST,
		CLASS_NATURAL_SURFACE = CLASS_NATURAL_SURFACE,
		CLASS_NATURAL_VEGETATION = CLASS_NATURAL_VEGETATION,
		CLASS_UNKNOWN = CLASS_UNKNOWN,
		CLASS_WP43_STRATUM = CLASS_WP43_STRATUM,
		CONTENT_FIELDS = CONTENT_FIELDS,
		CONTENT_SCHEMA = CONTENT_SCHEMA,
		CONTEXT_FIELDS = CONTEXT_FIELDS,
		CONTEXT_SCHEMA = CONTEXT_SCHEMA,
		FACE_DX = FACE_DX,
		FACE_DY = FACE_DY,
		FACE_DZ = FACE_DZ,
		HEIGHTMAP_SENTINEL = HEIGHTMAP_SENTINEL,
		HOTPATH_NAME = HOTPATH_NAME,
		LIQUID_FLOWING = LIQUID_FLOWING,
		LIQUID_NONE = LIQUID_NONE,
		LIQUID_SOURCE = LIQUID_SOURCE,
		MAX_COLUMNS = MAX_COLUMNS,
		MAX_ROLE = MAX_ROLE,
		MAX_RUNS = MAX_RUNS,
		MAX_SAFE = MAX_SAFE,
		MAX_SEED_RUNS = MAX_SEED_RUNS,
		MAX_TARGET_SLOTS = MAX_TARGET_SLOTS,
		MAX_VOLUME = MAX_VOLUME,
		METRIC_COUNT = METRIC_COUNT,
		M_APPLY_ALLOCATIONS = M_APPLY_ALLOCATIONS,
		M_CLASSIFIED_COLUMNS = M_CLASSIFIED_COLUMNS,
		M_CONTENT_DIRTY_COLUMNS = M_CONTENT_DIRTY_COLUMNS,
		M_EMERGED_EXTERNAL = M_EMERGED_EXTERNAL,
		M_HEIGHTMAP_ENTRIES = M_HEIGHTMAP_ENTRIES,
		M_LIGHT_DIRTY_COLUMNS = M_LIGHT_DIRTY_COLUMNS,
		M_LIGHT_SEED_RUNS = M_LIGHT_SEED_RUNS,
		M_LIQUID_DIRTY_COLUMNS = M_LIQUID_DIRTY_COLUMNS,
		M_METRICS_RESULTS = M_METRICS_RESULTS,
		M_MODIFIED_VOXELS = M_MODIFIED_VOXELS,
		M_PARAM2_DIRTY_COLUMNS = M_PARAM2_DIRTY_COLUMNS,
		M_PEAK_LIGHT_SEED_RUNS = M_PEAK_LIGHT_SEED_RUNS,
		M_PLANNED_COLUMNS = M_PLANNED_COLUMNS,
		M_VM_CALC_LIGHTING = M_VM_CALC_LIGHTING,
		M_VM_GET_DATA = M_VM_GET_DATA,
		M_VM_GET_EMERGED = M_VM_GET_EMERGED,
		M_VM_GET_LIGHT = M_VM_GET_LIGHT,
		M_VM_GET_PARAM2 = M_VM_GET_PARAM2,
		M_VM_SET_DATA = M_VM_SET_DATA,
		M_VM_SET_LIGHTING = M_VM_SET_LIGHTING,
		M_VM_SET_LIGHT_DATA = M_VM_SET_LIGHT_DATA,
		M_VM_SET_PARAM2 = M_VM_SET_PARAM2,
		M_VM_UPDATE_LIQUIDS = M_VM_UPDATE_LIQUIDS,
		OP_POLICY = OP_POLICY,
		OP_POLICY_ALT = OP_POLICY_ALT,
		OP_PRIORITY = OP_PRIORITY,
		OP_ROLE = OP_ROLE,
		OUTCOME_NOOP = OUTCOME_NOOP,
		OUTCOME_REJECT = OUTCOME_REJECT,
		OUTCOME_WRITE = OUTCOME_WRITE,
		OWNER_MAX = OWNER_MAX,
		OWNER_MIN = OWNER_MIN,
		PARAM2_EXACT = PARAM2_EXACT,
		PARAM2_PRESERVE = PARAM2_PRESERVE,
		PLAN_FIELDS = PLAN_FIELDS,
		PLAN_SCHEMA = PLAN_SCHEMA,
		POLICY_CUT_NATURAL = POLICY_CUT_NATURAL,
		POLICY_DEEP_EXACT_HOST = POLICY_DEEP_EXACT_HOST,
		POLICY_FILL_VOID = POLICY_FILL_VOID,
		POLICY_OPEN_ENGINEERED = POLICY_OPEN_ENGINEERED,
		POLICY_SEAL_VOID = POLICY_SEAL_VOID,
		POLICY_SURFACE_EXACT = POLICY_SURFACE_EXACT,
		POLICY_WRITE_WATER = POLICY_WRITE_WATER,
		RESULT_C = RESULT_C,
		RESULT_CL = RESULT_CL,
		RESULT_CLQ = RESULT_CLQ,
		RESULT_CP = RESULT_CP,
		RESULT_CPL = RESULT_CPL,
		RESULT_CPLQ = RESULT_CPLQ,
		RESULT_CPQ = RESULT_CPQ,
		RESULT_CQ = RESULT_CQ,
		RESULT_NOOP_EMPTY = RESULT_NOOP_EMPTY,
		RESULT_NOOP_EQUAL = RESULT_NOOP_EQUAL,
		RESULT_P = RESULT_P,
		RESULT_PQ = RESULT_PQ,
		ROLE_AIR = ROLE_AIR,
		ROLE_ORDINARY_WATER_SOURCE = ROLE_ORDINARY_WATER_SOURCE,
		ROLE_RIVER_WATER_SOURCE = ROLE_RIVER_WATER_SOURCE,
		RUN_STRIDE = RUN_STRIDE,
		R_AUX = R_AUX,
		R_FEATURE = R_FEATURE,
		R_INTERFACE = R_INTERFACE,
		R_OPCODE = R_OPCODE,
		R_POLICY = R_POLICY,
		R_PRIORITY = R_PRIORITY,
		R_ROLE = R_ROLE,
		R_Y_MAX = R_Y_MAX,
		R_Y_MIN = R_Y_MIN,
		SCRATCH_CAPACITY = SCRATCH_CAPACITY,
		SEED_COORD_BASE = SEED_COORD_BASE,
		SEED_COORD_OFFSET = SEED_COORD_OFFSET,
		TARGET_AIR = TARGET_AIR,
		TARGET_CAPACITY = TARGET_CAPACITY,
		TARGET_SOLID = TARGET_SOLID,
		TARGET_STRIDE = TARGET_STRIDE,
		TARGET_WATER_SOURCE = TARGET_WATER_SOURCE,
	}

	if type(allocator_factory) ~= "table" or
			type(rawget(allocator_factory, "new")) ~= "function" then
		fail("fail_status", "allocator factory is invalid")
	end
	for key in pairs(allocator_factory) do
		if key ~= "new" then fail("fail_status", "allocator factory differs") end
	end
	local allocator_factory_new = allocator_factory.new
	local function new(manifest, content_contract, mapgen_context, allocator,
			construction_identity)
		require_manifest(manifest)
		exact_raw_fields(content_contract, K.CONTENT_FIELDS, "content contract",
			"fail_status")
		if content_contract.schema ~= K.CONTENT_SCHEMA or
				type(content_contract.resolve) ~= "function" or
				type(content_contract.classify) ~= "function" or
				type(content_contract.metrics) ~= "function" then
			fail("fail_status", "content contract API differs")
		end
		safe_integer(content_contract.ignore_cid, "ignore CID", 0, K.MAX_SAFE,
			"fail_status")
		safe_integer(content_contract.ordinary_water_family_id,
			"ordinary water family", 1, K.MAX_SAFE, "fail_status")
		safe_integer(content_contract.river_water_family_id,
			"river water family", 1, K.MAX_SAFE, "fail_status")
		exact_raw_fields(mapgen_context, K.CONTEXT_FIELDS, "mapgen context",
			"fail_status")
		if mapgen_context.schema ~= K.CONTEXT_SCHEMA or
				type(mapgen_context.get_heightmap) ~= "function" or
				type(mapgen_context.metrics) ~= "function" then
			fail("fail_status", "mapgen context API differs")
		end
		exact_raw_fields(allocator, K.ALLOCATOR_FIELDS, "adapter allocator",
			"fail_status")
		local provenance_ok, provenance = pcall(allocator_factory_new,
			K.ADAPTER_ALLOCATOR_DOMAIN, allocator)
		if not provenance_ok or provenance ~= true then
			fail("fail_status", "adapter allocator provenance differs")
		end
		if type(construction_identity) ~= "table" or
				getmetatable(construction_identity) ~= nil then
			fail("fail_status", "construction identity is invalid")
		end
		for _ in pairs(construction_identity) do
			fail("fail_status", "construction identity is not opaque and empty")
		end

		local function new_full_array(label, capacity)
			local array = allocator:new_array(label, capacity)
			allocator:grow(array, label, 0, capacity)
			return array
		end

		local data_buffer = new_full_array("adapter_vm_data", K.MAX_VOLUME)
		local param2_buffer = new_full_array("adapter_vm_param2", K.MAX_VOLUME)
		local light_original = new_full_array("adapter_vm_light_original",
			K.MAX_VOLUME)
		local light_final = new_full_array("adapter_vm_light_final", K.MAX_VOLUME)
		local dirty_content = new_full_array("adapter_dirty_content_columns",
			K.MAX_COLUMNS)
		local dirty_param2 = new_full_array("adapter_dirty_param2_columns",
			K.MAX_COLUMNS)
		local dirty_light = new_full_array("adapter_dirty_light_columns",
			K.MAX_COLUMNS)
		local dirty_liquid = new_full_array("adapter_dirty_liquid_columns",
			K.MAX_COLUMNS)
		local scratch = new_full_array("adapter_phase_scratch",
			K.SCRATCH_CAPACITY)
		local metric_values = new_full_array("adapter_metrics_state", K.METRIC_COUNT)

		local adapter = allocator:new_map("adapter_api", 2)
		local call_min = allocator:new_map("adapter_vm_call_min", 3)
		local call_max = allocator:new_map("adapter_vm_call_max", 3)
		local light_value = allocator:new_map("adapter_vm_light_value", 2)
		allocator:map_put(call_min, "adapter_vm_call_min", "x", 0)
		allocator:map_put(call_min, "adapter_vm_call_min", "y", 0)
		allocator:map_put(call_min, "adapter_vm_call_min", "z", 0)
		allocator:map_put(call_max, "adapter_vm_call_max", "x", 0)
		allocator:map_put(call_max, "adapter_vm_call_max", "y", 0)
		allocator:map_put(call_max, "adapter_vm_call_max", "z", 0)
		allocator:map_put(light_value, "adapter_vm_light_value", "day", 0)
		allocator:map_put(light_value, "adapter_vm_light_value", "night", 0)

		local ordinary_family = content_contract.ordinary_water_family_id
		local river_family = content_contract.river_water_family_id
		local ignore_cid = content_contract.ignore_cid
		local resolve_content = content_contract.resolve
		local classify_content = content_contract.classify
		local get_heightmap = mapgen_context.get_heightmap

		local function compatible_liquid(family_id, liquid_kind)
			return (family_id == ordinary_family or family_id == river_family) and
				(liquid_kind == K.LIQUID_SOURCE or liquid_kind == K.LIQUID_FLOWING)
		end

		local function classify(cid, p2, failure_code)
			local ok, class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source =
				pcall(classify_content, cid, p2)
			if not ok or not class_tuple_valid(class_id, family_id, liquid_kind,
					liquid_level, floodable, paramtype_light, light_propagates,
					sunlight_propagates, light_source) then
				fail(failure_code, "content classification is invalid")
			end
			if (cid == ignore_cid) ~= (class_id == K.CLASS_IGNORE) then
				fail(failure_code, "CONTENT_IGNORE classification differs")
			end
			local ok2, class_id2, family_id2, liquid_kind2, liquid_level2,
				floodable2, paramtype_light2, light_propagates2,
				sunlight_propagates2, light_source2 =
				pcall(classify_content, cid, p2)
			if not ok2 or class_id ~= class_id2 or family_id ~= family_id2 or
					liquid_kind ~= liquid_kind2 or liquid_level ~= liquid_level2 or
					floodable ~= floodable2 or
					paramtype_light ~= paramtype_light2 or
					light_propagates ~= light_propagates2 or
					sunlight_propagates ~= sunlight_propagates2 or
					light_source ~= light_source2 then
				fail(failure_code, "content classification is not pure")
			end
			return class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source
		end

		local function target_base(role_id, y, min_y)
			local slot = (role_id - 1) * 80 + (y - min_y) + 1
			if slot < 1 or slot > K.MAX_TARGET_SLOTS then
				fail("fail_target", "target cache slot is outside its bound")
			end
			return (slot - 1) * K.TARGET_STRIDE
		end

		local function cache_target(role_id, y, aux, min_y)
			if role_id < 1 or role_id > K.MAX_ROLE or aux ~= 0 then
				fail("fail_role", "role or aux is outside R5 vocabulary")
			end
			local base = target_base(role_id, y, min_y)
			if scratch[base + 1] ~= 0 then return base end
			local ok, target_cid, target_kind, param2_mode, param2_value =
				pcall(resolve_content, role_id, y, aux)
			if not ok or type(target_cid) ~= "number" or
					target_cid % 1 ~= 0 or target_cid < 0 or
					target_cid >= K.MAX_SAFE or
					type(target_kind) ~= "number" or target_kind % 1 ~= 0 or
					target_kind < K.TARGET_AIR or target_kind > K.TARGET_WATER_SOURCE or
					(param2_mode ~= K.PARAM2_PRESERVE and
						param2_mode ~= K.PARAM2_EXACT) or
					(param2_mode == K.PARAM2_PRESERVE and param2_value ~= nil) or
					(param2_mode == K.PARAM2_EXACT and
						(type(param2_value) ~= "number" or param2_value % 1 ~= 0 or
							param2_value < 0 or param2_value > 255)) then
				fail("fail_target", "resolved target tuple is invalid")
			end
			local classify_param2 = param2_mode == K.PARAM2_EXACT and
				param2_value or 0
			local class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source =
				classify(target_cid, classify_param2, "fail_target")
			if target_cid == ignore_cid or class_id == K.CLASS_IGNORE or
					class_id == K.CLASS_FOREIGN or class_id == K.CLASS_UNKNOWN then
				fail("fail_target", "planned target class is forbidden")
			end
			if role_id == K.ROLE_AIR then
				if target_kind ~= K.TARGET_AIR or class_id ~= K.CLASS_AIR or
						liquid_kind ~= K.LIQUID_NONE then
					fail("fail_target", "AIR role target differs")
				end
			elseif role_id == K.ROLE_ORDINARY_WATER_SOURCE or
					role_id == K.ROLE_RIVER_WATER_SOURCE then
				if target_kind ~= K.TARGET_WATER_SOURCE or
						class_id ~= K.CLASS_LIQUID or
						liquid_kind ~= K.LIQUID_SOURCE or
						not compatible_liquid(family_id, liquid_kind) then
					fail("fail_target", "water role target differs")
				end
			else
				if target_kind ~= K.TARGET_SOLID or liquid_kind ~= K.LIQUID_NONE or
						(class_id ~= K.CLASS_NATURAL_HOST and
							class_id ~= K.CLASS_NATURAL_SURFACE and
							class_id ~= K.CLASS_WP43_STRATUM) then
					fail("fail_target", "solid role target differs")
				end
			end
			scratch[base + 1] = target_cid + 1
			scratch[base + 2] = target_kind
			scratch[base + 3] = param2_mode
			scratch[base + 4] = param2_mode == K.PARAM2_EXACT and
				param2_value + 1 or 0
			scratch[base + 5] = class_id
			scratch[base + 6] = family_id
			scratch[base + 7] = liquid_kind
			scratch[base + 8] = liquid_level
			scratch[base + 9] = floodable and 1 or 0
			scratch[base + 10] = paramtype_light and 1 or 0
			scratch[base + 11] = light_propagates and 1 or 0
			scratch[base + 12] = sunlight_propagates and 1 or 0
			scratch[base + 13] = light_source
			return base
		end

		local function replacement_outcome(policy_id, class_id, family_id,
				liquid_kind)
			return replacement_outcome_core(policy_id, class_id, family_id,
				liquid_kind, ordinary_family, river_family)
		end

		local function validate_plan_bounds(minp, maxp, plan, call_mode)
			check_position(minp, "minp")
			check_position(maxp, "maxp")
			if call_mode ~= "offline_fixture" and call_mode ~= "engine_fixture" then
				fail("fail_call_mode", "R5 call mode is disabled")
			end
			local x_count = maxp.x - minp.x + 1
			local y_count = maxp.y - minp.y + 1
			local z_count = maxp.z - minp.z + 1
			if x_count < 1 or x_count > 80 or y_count < 1 or y_count > 80 or
					z_count < 1 or z_count > 80 or minp.x < K.OWNER_MIN or
					minp.y < K.OWNER_MIN or minp.z < K.OWNER_MIN or maxp.x > K.OWNER_MAX or
					maxp.y > K.OWNER_MAX or maxp.z > K.OWNER_MAX then
				fail("fail_bounds", "central bounds are outside manifest limits")
			end
			if plan.min_x ~= minp.x or plan.min_y ~= minp.y or
					plan.min_z ~= minp.z or plan.max_x ~= maxp.x or
					plan.max_y ~= maxp.y or plan.max_z ~= maxp.z then
				fail("fail_bounds", "plan and apply bounds differ")
			end
			if plan.run_count > 0 and (x_count ~= 80 or z_count ~= 80) then
				fail("fail_bounds", "nonempty adapter plan is not engine-shaped")
			end
			if call_mode == "engine_fixture" then
				if x_count ~= 80 or y_count ~= 80 or z_count ~= 80 or
						(minp.x + 32) % 80 ~= 0 or (minp.y + 32) % 80 ~= 0 or
						(minp.z + 32) % 80 ~= 0 then
					fail("fail_bounds", "engine fixture alignment differs")
				end
			end
			return x_count, y_count, z_count
		end

		local function validate_stable_refs(stable_refs)
			if type(stable_refs) ~= "table" or getmetatable(stable_refs) ~= nil then
				fail("fail_plan", "stable refs are not an array")
			end
			local count = #stable_refs
			if count > 512 then fail("fail_plan", "stable refs exceed bound") end
			local previous
			for index = 1, count do
				local value = stable_refs[index]
				if type(value) ~= "string" or value == "" or
						(previous ~= nil and previous >= value) then
					fail("fail_plan", "stable refs are not canonical")
				end
				previous = value
			end
			for key in pairs(stable_refs) do
				if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or
						key > count then
					fail("fail_plan", "stable refs are not dense")
				end
			end
			return count
		end

		local function validate_plan(plan, plan_generation, minp, maxp, call_mode)
			if getmetatable(construction_identity) ~= nil then
				fail("fail_status", "construction identity metatable changed")
			end
			for _ in pairs(construction_identity) do
				fail("fail_status", "construction identity is no longer empty")
			end
			exact_raw_fields(plan, K.PLAN_FIELDS, "plan", "fail_plan")
			if getmetatable(plan) ~= nil or plan.schema ~= K.PLAN_SCHEMA or
					plan.valid ~= true or
					not rawequal(plan.construction_identity, construction_identity) then
				fail("fail_plan", "plan provenance or status differs")
			end
			safe_integer(plan.generation, "plan generation", 1, K.MAX_SAFE,
				"fail_stale_plan")
			if plan_generation ~= plan.generation then
				fail("fail_stale_plan", "plan generation is stale")
			end
			safe_integer(plan.run_count, "run count", 0, K.MAX_RUNS, "fail_plan")
			local x_count, y_count, z_count =
				validate_plan_bounds(minp, maxp, plan, call_mode)
			local column_count = x_count * z_count
			local stable_ref_count = validate_stable_refs(plan.stable_refs)
			if type(plan.column_start) ~= "table" or
					type(plan.run_values) ~= "table" or
					getmetatable(plan.column_start) ~= nil or
					getmetatable(plan.run_values) ~= nil then
				fail("fail_plan", "plan buffers are invalid")
			end
			if plan.column_start[1] ~= 1 or
					plan.column_start[column_count + 1] ~= plan.run_count + 1 then
				fail("fail_plan", "column sentinel differs")
			end
			for column = 1, column_count do
				local first = plan.column_start[column]
				local after = plan.column_start[column + 1]
				if type(first) ~= "number" or first % 1 ~= 0 or
						type(after) ~= "number" or after % 1 ~= 0 or first < 1 or
						after < first or after > plan.run_count + 1 then
					fail("fail_plan", "column run span differs")
				end
				local previous_y_max
				local previous_base
				for run = first, after - 1 do
					local base = (run - 1) * K.RUN_STRIDE
					local y_min = plan.run_values[base + K.R_Y_MIN]
					local y_max = plan.run_values[base + K.R_Y_MAX]
					local priority = plan.run_values[base + K.R_PRIORITY]
					local opcode = plan.run_values[base + K.R_OPCODE]
					local role = plan.run_values[base + K.R_ROLE]
					local policy = plan.run_values[base + K.R_POLICY]
					local feature_ref = plan.run_values[base + K.R_FEATURE]
					local interface_ref = plan.run_values[base + K.R_INTERFACE]
					local aux = plan.run_values[base + K.R_AUX]
					if type(y_min) ~= "number" or y_min % 1 ~= 0 or
							type(y_max) ~= "number" or y_max % 1 ~= 0 or
							y_min < minp.y or y_max > maxp.y or y_min > y_max or
							(previous_y_max ~= nil and y_min <= previous_y_max) or
							type(priority) ~= "number" or priority % 1 ~= 0 or
							type(opcode) ~= "number" or opcode % 1 ~= 0 or
							type(role) ~= "number" or role % 1 ~= 0 or
							type(policy) ~= "number" or policy % 1 ~= 0 or
							type(feature_ref) ~= "number" or feature_ref % 1 ~= 0 or
							type(interface_ref) ~= "number" or
							interface_ref % 1 ~= 0 or aux ~= 0 then
						fail("fail_plan", "run scalar domain differs")
					end
					if K.OP_PRIORITY[opcode] ~= priority or K.OP_ROLE[opcode] ~= role or
							(policy ~= K.OP_POLICY[opcode] and
								policy ~= K.OP_POLICY_ALT[opcode]) then
						fail("fail_plan", "opcode tuple differs")
					end
					if feature_ref < 0 or feature_ref > stable_ref_count or
							interface_ref < 0 or interface_ref > stable_ref_count then
						fail("fail_plan", "stable reference index differs")
					end
					if previous_y_max ~= nil and y_min == previous_y_max + 1 then
						local equal = true
						for field = K.R_PRIORITY, K.R_AUX do
							if plan.run_values[previous_base + field] ~=
									plan.run_values[base + field] then
								equal = false
							end
						end
						if equal then fail("fail_plan", "adjacent equal runs are not coalesced") end
					end
					previous_y_max = y_max
					previous_base = base
				end
			end
			return x_count, y_count, z_count, column_count
		end

		local function vm_call0(method, metric_index, vm)
			metric_values[metric_index] = metric_values[metric_index] + 1
			local ok, result_a, result_b = pcall(method, vm)
			if not ok then fail("fail_vm_contract", "VoxelManip method failed") end
			return result_a, result_b
		end

		local function vm_call1(method, metric_index, vm, first)
			metric_values[metric_index] = metric_values[metric_index] + 1
			local ok, result_a, result_b = pcall(method, vm, first)
			if not ok then fail("fail_vm_contract", "VoxelManip method failed") end
			return result_a, result_b
		end

		local function vm_call3(method, metric_index, vm, first, second, third)
			metric_values[metric_index] = metric_values[metric_index] + 1
			local ok, result_a, result_b = pcall(method, vm, first, second, third)
			if not ok then fail("fail_vm_contract", "VoxelManip method failed") end
			return result_a, result_b
		end

		local function resolve_voxel(plan, run_base, y, min_y, heightmap_value,
				old_cid, old_param2)
			if old_cid == ignore_cid then
				fail("fail_content_ignore", "planned owner content is ignore")
			end
			local role = plan.run_values[run_base + K.R_ROLE]
			local policy = plan.run_values[run_base + K.R_POLICY]
			local opcode = plan.run_values[run_base + K.R_OPCODE]
			local aux = plan.run_values[run_base + K.R_AUX]
			local target = cache_target(role, y, aux, min_y)
			local target_cid = scratch[target + 1] - 1
			local target_kind = scratch[target + 2]
			if (policy == K.POLICY_CUT_NATURAL or
					policy == K.POLICY_OPEN_ENGINEERED) and target_kind ~= K.TARGET_AIR then
				fail("fail_target", "air policy target differs")
			elseif (policy == K.POLICY_FILL_VOID or policy == K.POLICY_SEAL_VOID or
					policy == K.POLICY_SURFACE_EXACT or
					policy == K.POLICY_DEEP_EXACT_HOST) and
					target_kind ~= K.TARGET_SOLID then
				fail("fail_target", "solid policy target differs")
			elseif policy == K.POLICY_WRITE_WATER and
					target_kind ~= K.TARGET_WATER_SOURCE then
				fail("fail_target", "water policy target differs")
			end
			local class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source =
				classify(old_cid, old_param2, "fail_old_class")
			if class_id == K.CLASS_IGNORE then
				fail("fail_content_ignore", "classified owner content is ignore")
			end
			local preserved_by_heightmap = opcode == 27 and
				policy == K.POLICY_FILL_VOID and
					(class_id == K.CLASS_AIR or class_id == K.CLASS_LIQUID) and
					heightmap_value ~= K.HEIGHTMAP_SENTINEL and y <= heightmap_value
			local outcome
			if preserved_by_heightmap then
				outcome = K.OUTCOME_NOOP
			elseif old_cid == target_cid then
				outcome = K.OUTCOME_NOOP
			else
				outcome = replacement_outcome(policy, class_id, family_id,
					liquid_kind)
			end
			if outcome == K.OUTCOME_REJECT then
				fail("fail_replace_policy", "replace-policy matrix rejected")
			end
			local final_cid = outcome == K.OUTCOME_WRITE and target_cid or old_cid
			local param2_mode = scratch[target + 3]
			local final_param2 = old_param2
			if param2_mode == K.PARAM2_EXACT and not preserved_by_heightmap then
				final_param2 = scratch[target + 4] - 1
			end
			local final_class, final_family, final_liquid_kind, final_liquid_level,
				final_floodable, final_paramtype_light, final_light_propagates,
				final_sunlight_propagates, final_light_source
			if outcome == K.OUTCOME_WRITE then
				final_class = scratch[target + 5]
				final_family = scratch[target + 6]
				final_liquid_kind = scratch[target + 7]
				final_liquid_level = scratch[target + 8]
				final_floodable = scratch[target + 9] == 1
				final_paramtype_light = scratch[target + 10] == 1
				final_light_propagates = scratch[target + 11] == 1
				final_sunlight_propagates = scratch[target + 12] == 1
				final_light_source = scratch[target + 13]
			else
				final_class, final_family, final_liquid_kind, final_liquid_level,
					final_floodable, final_paramtype_light,
					final_light_propagates, final_sunlight_propagates,
					final_light_source = classify(final_cid, final_param2,
						"fail_old_class")
			end
			return final_cid, final_param2, class_id, family_id, liquid_kind,
				liquid_level, floodable, paramtype_light, light_propagates,
				sunlight_propagates, light_source, final_class, final_family,
				final_liquid_kind, final_liquid_level, final_floodable,
				final_paramtype_light, final_light_propagates,
				final_sunlight_propagates, final_light_source
		end

		local function run_for_y(plan, column, y)
			local first = plan.column_start[column]
			local after = plan.column_start[column + 1]
			for run = first, after - 1 do
				local base = (run - 1) * K.RUN_STRIDE
				if y < plan.run_values[base + K.R_Y_MIN] then return nil end
				if y <= plan.run_values[base + K.R_Y_MAX] then return base end
			end
			return nil
		end

		local function metric_add(index, value)
			metric_values[index] = metric_values[index] + value
		end

		local function set_call_box(min_x, min_y, min_z, max_x, max_y, max_z)
			call_min.x = min_x
			call_min.y = min_y
			call_min.z = min_z
			call_max.x = max_x
			call_max.y = max_y
			call_max.z = max_z
		end

		local function apply_impl(vm, minp, maxp, plan, plan_generation, call_mode)
			require_manifest(manifest)
			local x_count, y_count, z_count, column_count =
				validate_plan(plan, plan_generation, minp, maxp, call_mode)
			if plan.run_count == 0 then return K.RESULT_NOOP_EMPTY end
			if type(vm) ~= "table" and type(vm) ~= "userdata" then
				fail("fail_vm_contract", "VoxelManip object is invalid")
			end
			local vm_get_emerged_area = vm.get_emerged_area
			local vm_get_data = vm.get_data
			local vm_get_param2_data = vm.get_param2_data
			local vm_get_light_data = vm.get_light_data
			local vm_set_data = vm.set_data
			local vm_set_param2_data = vm.set_param2_data
			local vm_set_lighting = vm.set_lighting
			local vm_calc_lighting = vm.calc_lighting
			local vm_set_light_data = vm.set_light_data
			local vm_update_liquids = vm.update_liquids
			if type(vm_get_emerged_area) ~= "function" or
					type(vm_get_data) ~= "function" or
					type(vm_get_param2_data) ~= "function" or
					type(vm_get_light_data) ~= "function" or
					type(vm_set_data) ~= "function" or
					type(vm_set_param2_data) ~= "function" or
					type(vm_set_lighting) ~= "function" or
					type(vm_calc_lighting) ~= "function" or
					type(vm_set_light_data) ~= "function" or
					type(vm_update_liquids) ~= "function" then
				fail("fail_vm_contract", "required VoxelManip method is absent")
			end
			for index = 1, K.MAX_COLUMNS do
				dirty_content[index] = 0
				dirty_param2[index] = 0
				dirty_light[index] = 0
				dirty_liquid[index] = 0
			end
			for index = 1, K.SCRATCH_CAPACITY do scratch[index] = 0 end

			local planned_columns = 0
			for column = 1, column_count do
				if plan.column_start[column] < plan.column_start[column + 1] then
					planned_columns = planned_columns + 1
					for run = plan.column_start[column],
							plan.column_start[column + 1] - 1 do
						local base = (run - 1) * K.RUN_STRIDE
						for y = plan.run_values[base + K.R_Y_MIN],
								plan.run_values[base + K.R_Y_MAX] do
							cache_target(plan.run_values[base + K.R_ROLE], y,
								plan.run_values[base + K.R_AUX], minp.y)
						end
					end
				end
			end

			local emerged_min, emerged_max = vm_call0(vm_get_emerged_area,
				K.M_VM_GET_EMERGED, vm)
			metric_add(K.M_EMERGED_EXTERNAL, 2)
			check_position(emerged_min, "emerged min")
			check_position(emerged_max, "emerged max")
			if emerged_min.x ~= minp.x - 16 or emerged_min.y ~= minp.y - 16 or
					emerged_min.z ~= minp.z - 16 or emerged_max.x ~= maxp.x + 16 or
					emerged_max.y ~= maxp.y + 16 or emerged_max.z ~= maxp.z + 16 then
				fail("fail_halo", "emerged halo differs")
			end
			local ex = emerged_max.x - emerged_min.x + 1
			local ey = emerged_max.y - emerged_min.y + 1
			local ez = emerged_max.z - emerged_min.z + 1
			local volume = ex * ey * ez
			if volume < 1 or volume > K.MAX_VOLUME then
				fail("fail_vm_contract", "emerged volume exceeds retained buffer")
			end
			local y_stride = ex
			local z_stride = ex * ey

			local ok_heightmap, heightmap = pcall(get_heightmap)
			if not ok_heightmap or type(heightmap) ~= "table" or
					getmetatable(heightmap) ~= nil then
				fail("fail_native_heightmap", "heightmap fetch differs")
			end
			local heightmap_keys = 0
			for key, value in pairs(heightmap) do
				if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 6400 or
						type(value) ~= "number" or value % 1 ~= 0 or
						(value ~= K.HEIGHTMAP_SENTINEL and
							(value < minp.y or value > maxp.y)) then
					fail("fail_native_heightmap", "heightmap domain differs")
				end
				heightmap_keys = heightmap_keys + 1
			end
			if heightmap_keys ~= 6400 then
				fail("fail_native_heightmap", "heightmap key count differs")
			end
			for index = 1, 6400 do
				if heightmap[index] == nil then
					fail("fail_native_heightmap", "heightmap has a hole")
				end
			end
			metric_add(K.M_HEIGHTMAP_ENTRIES, 6400)

			local returned_data = vm_call1(vm_get_data, K.M_VM_GET_DATA, vm,
				data_buffer)
			if not rawequal(returned_data, data_buffer) then
				fail("fail_vm_contract", "get_data did not reuse buffer")
			end
			local returned_param2 = vm_call1(vm_get_param2_data, K.M_VM_GET_PARAM2,
				vm, param2_buffer)
			if not rawequal(returned_param2, param2_buffer) then
				fail("fail_vm_contract", "get_param2_data did not reuse buffer")
			end
			for index = 1, volume do
				local cid = data_buffer[index]
				local p2 = param2_buffer[index]
				if type(cid) ~= "number" or cid % 1 ~= 0 or cid < 0 or
						cid > K.MAX_SAFE or type(p2) ~= "number" or p2 % 1 ~= 0 or
						p2 < 0 or p2 > 255 then
					fail("fail_vm_contract", "VM buffer scalar differs")
				end
			end

			local function buffer_index(x, y, z)
				return (z - emerged_min.z) * z_stride +
					(y - emerged_min.y) * y_stride + (x - emerged_min.x) + 1
			end
			local function column_index(x, z)
				return (z - minp.z) * x_count + (x - minp.x) + 1
			end

			local modified_voxels = 0
			local content_dirty_columns = 0
			local param2_dirty_columns = 0
			local light_dirty_columns = 0
			local liquid_dirty_columns = 0
			local light_min_x = K.OWNER_MAX
			local light_min_y = K.OWNER_MAX
			local light_min_z = K.OWNER_MAX
			local light_max_x = K.OWNER_MIN
			local light_max_y = K.OWNER_MIN
			local light_max_z = K.OWNER_MIN

			local function mark_column(array, column)
				if array[column] == 0 then
					array[column] = 1
					return 1
				end
				return 0
			end

			local function final_neighbor(nx, ny, nz)
				local column = column_index(nx, nz)
				local index = buffer_index(nx, ny, nz)
				local old_cid = data_buffer[index]
				local old_p2 = param2_buffer[index]
				local run_base = run_for_y(plan, column, ny)
				if run_base == nil then
					if old_cid == ignore_cid then
						fail("fail_content_ignore",
							"required owner neighbour is ignore")
					end
					local _, family, kind = classify(old_cid, old_p2,
						"fail_old_class")
					return old_cid, old_p2, family, kind
				end
				local final_cid, final_p2, old_class_unused, old_family_unused,
					old_kind_unused, old_level_unused, old_floodable_unused,
					old_paramtype_unused, old_light_unused, old_sunlight_unused,
					old_source_unused, final_class_unused, final_family,
					final_kind = resolve_voxel(plan, run_base, ny,
						minp.y, heightmap[column], old_cid, old_p2)
				return final_cid, final_p2, final_family, final_kind
			end

			for z = minp.z, maxp.z do
				for x = minp.x, maxp.x do
					local column = column_index(x, z)
					local first = plan.column_start[column]
					local after = plan.column_start[column + 1]
					for run = first, after - 1 do
						local run_base = (run - 1) * K.RUN_STRIDE
						for y = plan.run_values[run_base + K.R_Y_MIN],
								plan.run_values[run_base + K.R_Y_MAX] do
							local index = buffer_index(x, y, z)
							local old_cid = data_buffer[index]
							local old_p2 = param2_buffer[index]
							local final_cid, final_p2, _, old_family, old_kind,
								old_level, old_floodable, old_paramtype_light,
								old_light_propagates, old_sunlight_propagates,
								old_light_source, _, final_family, final_kind,
								final_level, final_floodable, final_paramtype_light,
								final_light_propagates, final_sunlight_propagates,
								final_light_source = resolve_voxel(plan, run_base, y,
									minp.y, heightmap[column], old_cid, old_p2)
							local content_changed = final_cid ~= old_cid
							local param2_changed = final_p2 ~= old_p2
							if content_changed or param2_changed then
								modified_voxels = modified_voxels + 1
							end
							if content_changed then
								content_dirty_columns = content_dirty_columns +
									mark_column(dirty_content, column)
							end
							if param2_changed then
								param2_dirty_columns = param2_dirty_columns +
									mark_column(dirty_param2, column)
							end
							if content_changed and
									(old_paramtype_light ~= final_paramtype_light or
									old_light_propagates ~= final_light_propagates or
									old_sunlight_propagates ~= final_sunlight_propagates or
									old_light_source ~= final_light_source) then
								light_dirty_columns = light_dirty_columns +
									mark_column(dirty_light, column)
								if x < light_min_x then light_min_x = x end
								if y < light_min_y then light_min_y = y end
								if z < light_min_z then light_min_z = z end
								if x > light_max_x then light_max_x = x end
								if y > light_max_y then light_max_y = y end
								if z > light_max_z then light_max_z = z end
							end
							local liquid_dirty = false
							if content_changed or param2_changed then
								if old_family > 0 or final_family > 0 or
										old_kind ~= final_kind or
										old_family ~= final_family or
										old_level ~= final_level then
									liquid_dirty = true
								elseif old_floodable ~= final_floodable then
									for face = 1, 6 do
										local nx = x + K.FACE_DX[face]
										local ny = y + K.FACE_DY[face]
										local nz = z + K.FACE_DZ[face]
										if nx < minp.x or nx > maxp.x or ny < minp.y or
												ny > maxp.y or nz < minp.z or nz > maxp.z then
											liquid_dirty = true
										else
											local n_old_index = buffer_index(nx, ny, nz)
											local n_old_cid = data_buffer[n_old_index]
											local n_old_p2 = param2_buffer[n_old_index]
											local n_final_cid, n_final_p2, n_family, n_kind =
												final_neighbor(nx, ny, nz)
											if n_final_cid == n_old_cid and
													n_final_p2 == n_old_p2 and
													compatible_liquid(n_family, n_kind) then
												liquid_dirty = true
											end
										end
										if liquid_dirty then break end
									end
								end
							end
							if liquid_dirty then
								liquid_dirty_columns = liquid_dirty_columns +
									mark_column(dirty_liquid, column)
							end
						end
					end
				end
			end

			local seed_run_count = 0
			local seed_y
			local box_min_x, box_min_y, box_min_z
			local box_max_x, box_max_y, box_max_z
			if light_dirty_columns > 0 then
				box_min_x = math.max(light_min_x - 15, emerged_min.x)
				box_min_y = math.max(light_min_y - 15, emerged_min.y)
				box_min_z = math.max(light_min_z - 15, emerged_min.z)
				box_max_x = math.min(light_max_x + 15, emerged_max.x)
				box_max_y = math.min(light_max_y + 15, emerged_max.y - 1)
				box_max_z = math.min(light_max_z + 15, emerged_max.z)
				if box_min_x > box_max_x or box_min_y > box_max_y or
						box_min_z > box_max_z then
					fail("fail_lighting_context", "light box is empty")
				end
				local function precommit_light_state(x, y, z)
					local index = buffer_index(x, y, z)
					local old_cid = data_buffer[index]
					local old_p2 = param2_buffer[index]
					local final_cid = old_cid
					local final_p2 = old_p2
					if x >= minp.x and x <= maxp.x and y >= minp.y and
							y <= maxp.y and z >= minp.z and z <= maxp.z then
						local column = column_index(x, z)
						local run_base = run_for_y(plan, column, y)
						if run_base ~= nil then
							final_cid, final_p2 = resolve_voxel(plan, run_base, y,
								minp.y, heightmap[column], old_cid, old_p2)
						end
					end
					if final_cid == ignore_cid then
						return final_cid, final_p2, false
					end
					local _, _, _, _, _, _, _, sunlight = classify(final_cid,
						final_p2, "fail_lighting_context")
					return final_cid, final_p2, sunlight
				end

				for z = box_min_z, box_max_z do
					for y = box_min_y, box_max_y do
						for x = box_min_x, box_max_x do
							local final_cid = precommit_light_state(x, y, z)
							if final_cid == ignore_cid then
								fail("fail_content_ignore", "required light context is ignore")
							end
						end
					end
				end
				seed_y = box_max_y + 1
				for z = box_min_z, box_max_z do
					for x = box_min_x, box_max_x do
						local final_cid = precommit_light_state(x, seed_y, z)
						if final_cid == ignore_cid then
							if x >= minp.x and x <= maxp.x and seed_y >= minp.y and
									seed_y <= maxp.y and z >= minp.z and z <= maxp.z then
								fail("fail_content_ignore", "owner overtop is ignore")
							end
						end
					end
				end
				local returned_light = vm_call1(vm_get_light_data, K.M_VM_GET_LIGHT,
					vm, light_original)
				if not rawequal(returned_light, light_original) then
					fail("fail_vm_contract", "get_light_data did not reuse buffer")
				end
				for index = 1, volume do
					local value = light_original[index]
					if type(value) ~= "number" or value % 1 ~= 0 or
							value < 0 or value > 255 then
						fail("fail_vm_contract", "light buffer scalar differs")
					end
				end
				for z = box_min_z, box_max_z do
					local run_start
					for x = box_min_x, box_max_x + 1 do
						local seeds = false
						if x <= box_max_x then
							local index = buffer_index(x, seed_y, z)
							local final_cid, _, sunlight =
								precommit_light_state(x, seed_y, z)
							if final_cid ~= ignore_cid then
								seeds = sunlight and light_original[index] == 15
							end
						end
						if seeds and run_start == nil then
							run_start = x
						elseif not seeds and run_start ~= nil then
							seed_run_count = seed_run_count + 1
							if seed_run_count > K.MAX_SEED_RUNS then
								fail("fail_lighting_context", "seed-run bound exceeded")
							end
							local x_start_slot = run_start + K.SEED_COORD_OFFSET
							local x_end_slot = x - 1 + K.SEED_COORD_OFFSET
							local z_slot = z + K.SEED_COORD_OFFSET
							scratch[K.TARGET_CAPACITY + seed_run_count] =
								(z_slot * K.SEED_COORD_BASE + x_end_slot) *
								K.SEED_COORD_BASE + x_start_slot
							run_start = nil
						end
					end
				end
			end

			-- All semantic and lighting validation is now complete.  The replay
			-- recomputes only already-validated scalar outcomes from immutable old
			-- entries, while the packed seed list occupies the disjoint scratch tail.
			for z = minp.z, maxp.z do
				for x = minp.x, maxp.x do
					local column = column_index(x, z)
					for run = plan.column_start[column],
							plan.column_start[column + 1] - 1 do
						local run_base = (run - 1) * K.RUN_STRIDE
						for y = plan.run_values[run_base + K.R_Y_MIN],
								plan.run_values[run_base + K.R_Y_MAX] do
							local index = buffer_index(x, y, z)
							local final_cid, final_p2 = resolve_voxel(plan, run_base, y,
								minp.y, heightmap[column], data_buffer[index],
								param2_buffer[index])
							data_buffer[index] = final_cid
							param2_buffer[index] = final_p2
						end
					end
				end
			end

			metric_add(K.M_CLASSIFIED_COLUMNS, planned_columns)
			metric_add(K.M_PLANNED_COLUMNS, planned_columns)
			metric_add(K.M_MODIFIED_VOXELS, modified_voxels)
			metric_add(K.M_CONTENT_DIRTY_COLUMNS, content_dirty_columns)
			metric_add(K.M_PARAM2_DIRTY_COLUMNS, param2_dirty_columns)
			metric_add(K.M_LIGHT_DIRTY_COLUMNS, light_dirty_columns)
			metric_add(K.M_LIQUID_DIRTY_COLUMNS, liquid_dirty_columns)
			if content_dirty_columns == 0 and param2_dirty_columns == 0 then
				heightmap = nil
				return K.RESULT_NOOP_EQUAL
			end

			if content_dirty_columns > 0 then
				vm_call1(vm_set_data, K.M_VM_SET_DATA, vm, data_buffer)
			end
			if param2_dirty_columns > 0 then
				vm_call1(vm_set_param2_data, K.M_VM_SET_PARAM2, vm, param2_buffer)
			end
			if light_dirty_columns > 0 then
				light_value.day = 0
				light_value.night = 0
				set_call_box(box_min_x, box_min_y, box_min_z,
					box_max_x, box_max_y, box_max_z)
				vm_call3(vm_set_lighting, K.M_VM_SET_LIGHTING, vm, light_value,
					call_min, call_max)
				light_value.day = 15
				for run = 1, seed_run_count do
					local packed = scratch[K.TARGET_CAPACITY + run]
					local x_start_slot = packed % K.SEED_COORD_BASE
					local quotient = (packed - x_start_slot) / K.SEED_COORD_BASE
					local x_end_slot = quotient % K.SEED_COORD_BASE
					local z_slot = (quotient - x_end_slot) / K.SEED_COORD_BASE
					local seed_x_min = x_start_slot - K.SEED_COORD_OFFSET
					local seed_x_max = x_end_slot - K.SEED_COORD_OFFSET
					local seed_z = z_slot - K.SEED_COORD_OFFSET
					set_call_box(seed_x_min, seed_y, seed_z,
						seed_x_max, seed_y, seed_z)
					vm_call3(vm_set_lighting, K.M_VM_SET_LIGHTING, vm, light_value,
						call_min, call_max)
				end
				set_call_box(box_min_x, box_min_y, box_min_z,
					box_max_x, box_max_y, box_max_z)
				vm_call3(vm_calc_lighting, K.M_VM_CALC_LIGHTING, vm, call_min,
					call_max, true)
				local returned_final_light = vm_call1(vm_get_light_data,
					K.M_VM_GET_LIGHT, vm, light_final)
				if not rawequal(returned_final_light, light_final) then
					fail("fail_vm_contract", "get_light_data did not reuse buffer")
				end
				for index = 1, volume do
					local value = light_final[index]
					if type(value) ~= "number" or value % 1 ~= 0 or
							value < 0 or value > 255 then
						fail("fail_vm_contract", "light buffer scalar differs")
					end
				end
				local owner_light_min_x = math.max(box_min_x, minp.x)
				local owner_light_min_y = math.max(box_min_y, minp.y)
				local owner_light_min_z = math.max(box_min_z, minp.z)
				local owner_light_max_x = math.min(box_max_x, maxp.x)
				local owner_light_max_y = math.min(box_max_y, maxp.y)
				local owner_light_max_z = math.min(box_max_z, maxp.z)
				for z = emerged_min.z, emerged_max.z do
					for y = emerged_min.y, emerged_max.y do
						local index = buffer_index(emerged_min.x, y, z)
						for x = emerged_min.x, emerged_max.x do
							if x < owner_light_min_x or x > owner_light_max_x or
									y < owner_light_min_y or y > owner_light_max_y or
									z < owner_light_min_z or z > owner_light_max_z then
								light_final[index] = light_original[index]
							end
							index = index + 1
						end
					end
				end
				vm_call1(vm_set_light_data, K.M_VM_SET_LIGHT_DATA, vm, light_final)
				metric_add(K.M_LIGHT_SEED_RUNS, seed_run_count)
				if seed_run_count > metric_values[K.M_PEAK_LIGHT_SEED_RUNS] then
					metric_values[K.M_PEAK_LIGHT_SEED_RUNS] = seed_run_count
				end
			end
			if liquid_dirty_columns > 0 then
				vm_call0(vm_update_liquids, K.M_VM_UPDATE_LIQUIDS, vm)
			end
			heightmap = nil

			local has_content = content_dirty_columns > 0
			local has_param2 = param2_dirty_columns > 0
			local has_light = light_dirty_columns > 0
			local has_liquid = liquid_dirty_columns > 0
			if not has_content then
				return has_liquid and K.RESULT_PQ or K.RESULT_P
			elseif has_param2 then
				if has_light then
					return has_liquid and K.RESULT_CPLQ or K.RESULT_CPL
				end
				return has_liquid and K.RESULT_CPQ or K.RESULT_CP
			elseif has_light then
				return has_liquid and K.RESULT_CLQ or K.RESULT_CL
			end
			return has_liquid and K.RESULT_CQ or K.RESULT_C
		end

		local function apply(self, vm, minp, maxp, plan, plan_generation,
				call_mode)
			if not rawequal(self, adapter) then
				fail("fail_status", "adapter receiver differs")
			end
			local entered = pcall(allocator.enter_hotpath, allocator, K.HOTPATH_NAME)
			if not entered then fail("fail_status", "adapter is not sealed") end
			local ok, result = pcall(apply_impl, vm, minp, maxp, plan,
				plan_generation, call_mode)
			local left = pcall(allocator.leave_hotpath, allocator, K.HOTPATH_NAME)
			if not left then fail("fail_status", "adapter hotpath is unbalanced") end
			if not ok then error(result, 0) end
			return result
		end

		local function metrics(self)
			if not rawequal(self, adapter) then
				fail("fail_status", "adapter receiver differs")
			end
			metric_values[K.M_METRICS_RESULTS] =
				metric_values[K.M_METRICS_RESULTS] + 1
			return {
				adapter_apply_table_allocations = metric_values[K.M_APPLY_ALLOCATIONS],
				emerged_area_external_table_allocations =
					metric_values[K.M_EMERGED_EXTERNAL],
				heightmap_entries_validated = metric_values[K.M_HEIGHTMAP_ENTRIES],
				classified_columns = metric_values[K.M_CLASSIFIED_COLUMNS],
				planned_columns = metric_values[K.M_PLANNED_COLUMNS],
				modified_voxels = metric_values[K.M_MODIFIED_VOXELS],
				content_dirty_columns = metric_values[K.M_CONTENT_DIRTY_COLUMNS],
				param2_dirty_columns = metric_values[K.M_PARAM2_DIRTY_COLUMNS],
				light_dirty_columns = metric_values[K.M_LIGHT_DIRTY_COLUMNS],
				liquid_dirty_columns = metric_values[K.M_LIQUID_DIRTY_COLUMNS],
				light_seed_runs = metric_values[K.M_LIGHT_SEED_RUNS],
				peak_light_seed_runs = metric_values[K.M_PEAK_LIGHT_SEED_RUNS],
				vm_get_emerged_area_calls = metric_values[K.M_VM_GET_EMERGED],
				vm_get_data_calls = metric_values[K.M_VM_GET_DATA],
				vm_set_data_calls = metric_values[K.M_VM_SET_DATA],
				vm_get_param2_calls = metric_values[K.M_VM_GET_PARAM2],
				vm_set_param2_calls = metric_values[K.M_VM_SET_PARAM2],
				vm_get_light_calls = metric_values[K.M_VM_GET_LIGHT],
				vm_set_lighting_calls = metric_values[K.M_VM_SET_LIGHTING],
				vm_calc_lighting_calls = metric_values[K.M_VM_CALC_LIGHTING],
				vm_set_light_data_calls = metric_values[K.M_VM_SET_LIGHT_DATA],
				vm_update_liquids_calls = metric_values[K.M_VM_UPDATE_LIQUIDS],
				metrics_result_table_allocations = metric_values[K.M_METRICS_RESULTS],
			}
		end

		allocator:map_put(adapter, "adapter_api", "apply", apply)
		allocator:map_put(adapter, "adapter_api", "metrics", metrics)
		return adapter
	end

	return {new = new}
end

return adapter_factory, replacement_outcome_fixture
