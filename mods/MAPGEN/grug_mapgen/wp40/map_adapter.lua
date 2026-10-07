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

-- Memoized per feature id: the writer asks this for every voxel of an
-- opcode-21 run, and a pattern match is not JIT-compiled. Feature ids come
-- from the plan's fixed stable-ref table, so the memo stays small.
local anchor_grade_memo = {}
local function anchor_grade_feature(feature_id)
	if type(feature_id) ~= "string" then return false end
	local value = anchor_grade_memo[feature_id]
	if value == nil then
		value = feature_id:match("^anchor_00[1-9]$") ~= nil or
			feature_id:match("^anchor_01[0-2]$") ~= nil
		anchor_grade_memo[feature_id] = value
	end
	return value
end

-- Names for the location details of a voxel failure (Round 41 lane CR). Read
-- only on a failure branch, never per voxel.
local CLASS_NAMES = {"air", "foreign", "ignore", "liquid", "native_ore",
	"natural_host", "natural_surface", "natural_vegetation", "unknown",
	"wp43_resource", "wp43_stratum"}
local POLICY_NAMES = {"cut_natural", "deep_exact_host", "fill_void",
	"open_engineered", "seal_void", "surface_exact", "write_water"}

-- The location part of a voxel failure message: position, content id (the
-- emerge wrapper adds its node name, `r7_mapgen.lua`), class, policy, opcode,
-- role and feature id.
local function voxel_details(x, y, z, cid, param2, class_id, policy, opcode,
		role, feature_id)
	return ("at (%s,%s,%s) cid=%s param2=%s class=%s policy=%s opcode=%s " ..
		"role=%s feature=%s"):format(tostring(x), tostring(y), tostring(z),
		tostring(cid), tostring(param2),
		tostring(CLASS_NAMES[class_id] or class_id),
		tostring(POLICY_NAMES[policy] or policy), tostring(opcode), tostring(role),
		tostring(feature_id or "-"))
end

local function preserved_native_cave(opcode, policy, class_id, heightmap_value,
		y, feature_id)
	return policy == 3 and
		(opcode == 27 or opcode == 21 and anchor_grade_feature(feature_id)) and
		(class_id == 1 or class_id == 4) and heightmap_value ~= -31007 and
		y <= heightmap_value
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
	local TARGET_CAPACITY = MAX_TARGET_SLOTS * TARGET_STRIDE
	local SCRATCH_CAPACITY = TARGET_CAPACITY

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
	local M_VM_GET_EMERGED = 11
	local M_VM_GET_DATA = 12
	local M_VM_SET_DATA = 13
	local M_VM_GET_PARAM2 = 14
	local M_VM_SET_PARAM2 = 15
	local M_VM_UPDATE_LIQUIDS = 16
	local M_METRICS_RESULTS = 17
	local METRIC_COUNT = 17

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

	-- The error handler of the transaction wrapper below: a failure keeps its
	-- stack (once, however deeply the wrappers nest), so a seed-fleet run and
	-- a server log both show where it failed.
	local function with_traceback(message)
		if type(message) ~= "string" or message:find("\nstack traceback:", 1, true) or
				type(debug) ~= "table" or type(debug.traceback) ~= "function" then
			return message
		end
		return debug.traceback(message, 2)
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
		MAX_TARGET_SLOTS = MAX_TARGET_SLOTS,
		MAX_VOLUME = MAX_VOLUME,
		METRIC_COUNT = METRIC_COUNT,
		M_APPLY_ALLOCATIONS = M_APPLY_ALLOCATIONS,
		M_CLASSIFIED_COLUMNS = M_CLASSIFIED_COLUMNS,
		M_CONTENT_DIRTY_COLUMNS = M_CONTENT_DIRTY_COLUMNS,
		M_EMERGED_EXTERNAL = M_EMERGED_EXTERNAL,
		M_HEIGHTMAP_ENTRIES = M_HEIGHTMAP_ENTRIES,
		M_LIGHT_DIRTY_COLUMNS = M_LIGHT_DIRTY_COLUMNS,
		M_LIQUID_DIRTY_COLUMNS = M_LIQUID_DIRTY_COLUMNS,
		M_METRICS_RESULTS = M_METRICS_RESULTS,
		M_MODIFIED_VOXELS = M_MODIFIED_VOXELS,
		M_PARAM2_DIRTY_COLUMNS = M_PARAM2_DIRTY_COLUMNS,
		M_PLANNED_COLUMNS = M_PLANNED_COLUMNS,
		M_VM_GET_DATA = M_VM_GET_DATA,
		M_VM_GET_EMERGED = M_VM_GET_EMERGED,
		M_VM_GET_PARAM2 = M_VM_GET_PARAM2,
		M_VM_SET_DATA = M_VM_SET_DATA,
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
			construction_identity, trusted_classify)
		require_manifest(manifest)
		exact_raw_fields(content_contract, K.CONTENT_FIELDS, "content contract",
			"fail_status")
		if content_contract.schema ~= K.CONTENT_SCHEMA or
				type(content_contract.resolve) ~= "function" or
				type(content_contract.classify) ~= "function" or
				type(content_contract.metrics) ~= "function" then
			fail("fail_status", "content contract API differs")
		end
		if trusted_classify ~= nil and type(trusted_classify) ~= "function" then
			fail("fail_status", "trusted classifier seam differs")
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

		local ordinary_family = content_contract.ordinary_water_family_id
		local river_family = content_contract.river_water_family_id
		local ignore_cid = content_contract.ignore_cid
		local resolve_content = content_contract.resolve
		local classify_content = trusted_classify or content_contract.classify
		local trusted_classification = trusted_classify ~= nil
		local get_heightmap = mapgen_context.get_heightmap

		local function compatible_liquid(family_id, liquid_kind)
			return (family_id == ordinary_family or family_id == river_family) and
				(liquid_kind == K.LIQUID_SOURCE or liquid_kind == K.LIQUID_FLOWING)
		end

		local function classify(cid, p2, failure_code)
			if trusted_classification then return classify_content(cid, p2) end
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
				fail("fail_target", "resolved target tuple is invalid" ..
					(" role=%s y=%s"):format(tostring(role_id), tostring(y)))
			end
			local classify_param2 = param2_mode == K.PARAM2_EXACT and
				param2_value or 0
			local class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source =
				classify(target_cid, classify_param2, "fail_target")
			if target_cid == ignore_cid or class_id == K.CLASS_IGNORE or
					class_id == K.CLASS_FOREIGN or class_id == K.CLASS_UNKNOWN then
				fail("fail_target", "planned target class is forbidden" ..
					(" role=%s y=%s"):format(tostring(role_id), tostring(y)))
			end
			if role_id == K.ROLE_AIR then
				if target_kind ~= K.TARGET_AIR or class_id ~= K.CLASS_AIR or
						liquid_kind ~= K.LIQUID_NONE then
					fail("fail_target", "AIR role target differs" ..
						(" role=%s y=%s"):format(tostring(role_id), tostring(y)))
				end
			elseif role_id == K.ROLE_ORDINARY_WATER_SOURCE or
					role_id == K.ROLE_RIVER_WATER_SOURCE then
				if target_kind ~= K.TARGET_WATER_SOURCE or
						class_id ~= K.CLASS_LIQUID or
						liquid_kind ~= K.LIQUID_SOURCE or
						not compatible_liquid(family_id, liquid_kind) then
					fail("fail_target", "water role target differs" ..
						(" role=%s y=%s"):format(tostring(role_id), tostring(y)))
				end
			else
				if target_kind ~= K.TARGET_SOLID or liquid_kind ~= K.LIQUID_NONE or
						(class_id ~= K.CLASS_NATURAL_HOST and
							class_id ~= K.CLASS_NATURAL_SURFACE and
							class_id ~= K.CLASS_WP43_STRATUM) then
					fail("fail_target", "solid role target differs" ..
						(" role=%s y=%s"):format(tostring(role_id), tostring(y)))
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

		-- A failure of one planned voxel names it (Round 41 lane CR): the
		-- details are formatted on the failure branch only.
		local function voxel_fail(code, message, plan, run_base, x, y, z, cid,
				param2, class_id)
			local feature_ref = plan.run_values[run_base + K.R_FEATURE]
			fail(code, message .. " " .. voxel_details(x, y, z, cid, param2,
				class_id, plan.run_values[run_base + K.R_POLICY],
				plan.run_values[run_base + K.R_OPCODE],
				plan.run_values[run_base + K.R_ROLE],
				feature_ref ~= 0 and plan.stable_refs[feature_ref] or nil))
		end

		local function resolve_voxel(plan, run_base, y, min_y, heightmap_value,
				old_cid, old_param2, x, z)
			if old_cid == ignore_cid then
				voxel_fail("fail_content_ignore", "planned owner content is ignore",
					plan, run_base, x, y, z, old_cid, old_param2, K.CLASS_IGNORE)
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
				voxel_fail("fail_target", "air policy target differs", plan, run_base,
					x, y, z, old_cid, old_param2, nil)
			elseif (policy == K.POLICY_FILL_VOID or policy == K.POLICY_SEAL_VOID or
					policy == K.POLICY_SURFACE_EXACT or
					policy == K.POLICY_DEEP_EXACT_HOST) and
					target_kind ~= K.TARGET_SOLID then
				voxel_fail("fail_target", "solid policy target differs", plan,
					run_base, x, y, z, old_cid, old_param2, nil)
			elseif policy == K.POLICY_WRITE_WATER and
					target_kind ~= K.TARGET_WATER_SOURCE then
				voxel_fail("fail_target", "water policy target differs", plan,
					run_base, x, y, z, old_cid, old_param2, nil)
			end
			local class_id, family_id, liquid_kind, liquid_level, floodable,
				paramtype_light, light_propagates, sunlight_propagates, light_source =
				classify(old_cid, old_param2, "fail_old_class")
			if class_id == K.CLASS_IGNORE then
				voxel_fail("fail_content_ignore", "classified owner content is ignore",
					plan, run_base, x, y, z, old_cid, old_param2, class_id)
			end
			local feature_ref = plan.run_values[run_base + K.R_FEATURE]
			local feature_id = feature_ref ~= 0 and plan.stable_refs[feature_ref] or nil
			local preserved_by_heightmap = preserved_native_cave(opcode, policy,
				class_id, heightmap_value, y, feature_id)
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
				voxel_fail("fail_replace_policy", "replace-policy matrix rejected",
					plan, run_base, x, y, z, old_cid, old_param2, class_id)
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

		local function apply_impl(vm, minp, maxp, plan, plan_generation, call_mode,
				lighting_owner)
			-- R6 settles the immutable R5 projection plus successors and owns the
			-- one light transaction (r6_settlement's halo.relight, Round 22 D65).
			-- R5 runs only composed inside it, with lighting delegated.
			if lighting_owner ~= "outer_transaction" then
				fail("fail_call_mode", "lighting owner differs")
			end
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
			local vm_set_data = vm.set_data
			local vm_set_param2_data = vm.set_param2_data
			local vm_update_liquids = vm.update_liquids
			if type(vm_get_emerged_area) ~= "function" or
					type(vm_get_data) ~= "function" or
					type(vm_get_param2_data) ~= "function" or
					type(vm_set_data) ~= "function" or
					type(vm_set_param2_data) ~= "function" or
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
			-- No per-voxel scalar check here: this adapter only ever runs on the
			-- composed R6 transaction's shadow VM (`r6_settlement.lua`), whose
			-- buffers are copies of the engine's `get_data`/`get_param2_data`
			-- output, and the engine fills every index of the emerged volume with
			-- an integer content ID (u16) and param2 (u8).

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
							"required owner neighbour is ignore " ..
							voxel_details(nx, ny, nz, old_cid, old_p2, K.CLASS_IGNORE))
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
						minp.y, heightmap[column], old_cid, old_p2, nx, nz)
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
									minp.y, heightmap[column], old_cid, old_p2, x, z)
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
							end
							local liquid_dirty = false
							if dirty_liquid[column] == 0 and
									(content_changed or param2_changed) then
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

			-- All semantic validation is now complete.  The replay recomputes only
			-- already-validated scalar outcomes from immutable old entries.
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
								param2_buffer[index], x, z)
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
				call_mode, lighting_owner)
			if not rawequal(self, adapter) then
				fail("fail_status", "adapter receiver differs")
			end
			local entered = pcall(allocator.enter_hotpath, allocator, K.HOTPATH_NAME)
			if not entered then fail("fail_status", "adapter is not sealed") end
			local ok, result = xpcall(function()
				return apply_impl(vm, minp, maxp, plan, plan_generation, call_mode,
					lighting_owner)
			end, with_traceback)
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
				vm_get_emerged_area_calls = metric_values[K.M_VM_GET_EMERGED],
				vm_get_data_calls = metric_values[K.M_VM_GET_DATA],
				vm_set_data_calls = metric_values[K.M_VM_SET_DATA],
				vm_get_param2_calls = metric_values[K.M_VM_GET_PARAM2],
				vm_set_param2_calls = metric_values[K.M_VM_SET_PARAM2],
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

return adapter_factory, replacement_outcome_fixture, preserved_native_cave
