-- Independent validation and oracle suite for the disabled WP40 R5 payload.
--
-- This file deliberately owns semantic expectations instead of importing
-- planner or adapter implementation constants.  Production modules are
-- reached only through the offline loader supplied by the runner.

return function(common)
	local validator = {}
	local SHARD_SCHEMA = "grug_wp40_simple_map_r5_validation_shard_v1"
	local RESULT_SCHEMA = "grug_wp40_simple_map_r5_validation_v1"
	local MICRO_SCHEMA = "grug_wp40_simple_map_r5_micro_kat_v1"
	local PLAN_SCHEMA = "grug_wp40_r5_column_run_plan_v1"
	local SOURCE_SCHEMA = "grug_wp40_r5_planner_source_v1"
	local RELATION_SCHEMA = "grug_wp40_r5_relational_lookup_v1"
	local MANIFEST_SCHEMA = "grug_wp40_r5_mapgen_manifest_v1"
	local CONTENT_SCHEMA = "grug_wp40_r5_content_contract_v1"
	local CONTEXT_SCHEMA = "grug_wp40_r5_mapgen_context_v1"
	local MAX_SAFE = 9007199254740991
	local OWNER_MIN = -30912
	local OWNER_MAX = 30927
	local AUTHORED_FLOOR = -37
	local HEIGHTMAP_SENTINEL = -31007
	local MAX_COLUMNS = 6400
	local MAX_RUNS = 198400
	local MAX_STABLE_REFS = 512
	local WATCH_STABLE_REFS = 497
	local RUN_STRIDE = 9
	local LOOKUP_BASE = 513
	local ATTACHMENT_SEPARATOR = string.char(124)

	local FIXTURE_ORDER = {
		"historical_r4", "seed_0", "worst_fixture", "matrix",
		"native_heightmap", "owner_order", "dungeon", "disabled",
	}
	local FIXTURE_RANK = {}
	for index = 1, #FIXTURE_ORDER do
		FIXTURE_RANK[FIXTURE_ORDER[index]] = index
	end

	local OPCODES, ROLES, POLICIES, CLASSES
	local OPCODE_ID, ROLE_ID, POLICY_TOKEN_ID
	local EMITTED_OPCODE, OP_PRIORITY, OP_ROLE, OP_POLICY, OP_POLICY_ALT
	-- Independent semantic authority is named, not numeric. Numeric ordinals are
	-- derived below from Common's defensively checked ASCII vocabularies.
	local OPERATION_RELATION = {
		{"BRIDGE_CLEAR",3,"AIR","OPEN_ENGINEERED","CUT_NATURAL"},
		{"BRIDGE_DECK",3,"BRIDGE_DECK","SURFACE_EXACT"},
		{"BRIDGE_SUPPORT",3,"BRIDGE_SUPPORT","SEAL_VOID"},
		{"CAUSEWAY_CULVERT",3,"RIVER_WATER_SOURCE","WRITE_WATER"},
		{"CAUSEWAY_FILL",3,"CAUSEWAY_CORE","FILL_VOID"},
		{"CAUSEWAY_SURFACE",3,"CAUSEWAY_SURFACE","SURFACE_EXACT"},
		{"CONTACT_FALL_CLEAR",3,"AIR","OPEN_ENGINEERED"},
		{"FORD_BED",3,"FORD_SURFACE","SURFACE_EXACT"},
		{"FOUNDATION_CLEAR",2,"AIR","CUT_NATURAL"},
		{"FOUNDATION_FILL",2,"FOUNDATION_CORE","FILL_VOID"},
		{"FOUNDATION_SURFACE",2,"FOUNDATION_SURFACE","SURFACE_EXACT"},
		{"HYDROLOGY_BANK_SEAL",3,"HYDROLOGY_SEAL","SEAL_VOID"},
		{"HYDROLOGY_BED_SEAL",3,"HYDROLOGY_SEAL","SEAL_VOID"},
		{"ORDINARY_WATER",6,"ORDINARY_WATER_SOURCE","WRITE_WATER"},
		{"PATH_CLEAR",4,"AIR","CUT_NATURAL"},
		{"PATH_FILL",4,"PATH_CORE","FILL_VOID"},
		{"PATH_SURFACE",4,"PATH_SURFACE","SURFACE_EXACT"},
		{"RECEIVER_OPEN",6,"AIR","OPEN_ENGINEERED"},
		{"RIVER_WATER",6,"RIVER_WATER_SOURCE","WRITE_WATER"},
		{"TERRAIN_CLEAR",5,"AIR","CUT_NATURAL"},
		{"TERRAIN_FILL",5,"STRATUM_AT_Y","FILL_VOID"},
		{"TERRAIN_SURFACE",5,"STRATUM_AT_Y","SURFACE_EXACT"},
		{"TUNNEL_FLOOR",3,"TUNNEL_FLOOR","SURFACE_EXACT"},
		{"TUNNEL_LUMEN",3,"AIR","OPEN_ENGINEERED"},
		{"TUNNEL_ROOF",3,"TUNNEL_WALL","SEAL_VOID"},
		{"TUNNEL_WALL",3,"TUNNEL_WALL","SEAL_VOID"},
	}
	local RESERVED_PRIORITY_BY_OPCODE = {
		BIOME_BED=7, BIOME_FILLER=7, BIOME_SHORE=7, BIOME_TOP=7,
		RESOURCE_EXACT_HOST=8, DECORATION=9,
	}
	local function opcode_policy_valid(opcode,policy)
		return OP_POLICY[opcode]==policy or OP_POLICY_ALT[opcode]==policy
	end
	local PLAN_FIELDS = {
		schema=true, construction_identity=true, generation=true, valid=true,
		min_x=true, min_y=true, min_z=true, max_x=true, max_y=true, max_z=true,
		column_start=true, run_values=true, run_count=true, stable_refs=true,
	}
	local SOURCE_FIELDS = {
		schema=true, column_values_at=true, hydrology_metric_values_at=true,
		metrics=true,
	}
	local PUBLIC_LOAD_FIELDS = {
		input_manifest=true, source=true, schemas=true, canonical=true,
		deterministic=true, index128=true, zones_module=true, foundation=true,
		foundation_session=true, session=true, private_session=true,
		planner_source=true,
	}
	local R5_LOAD_FIELDS = {
		input_manifest=true, source=true, schemas=true, canonical=true,
		deterministic=true, index128=true, zones_module=true,
		manifest_module=true, allocator_factory=true, vm_module=true,
		r5_module=true, session=true, planner_source=true, planner=true,
		adapter=true, allocators=true, planner_candidate_fixture=true,
		adapter_replacement_fixture=true,
	}
	local INPUT_MANIFEST_FIELDS = {
		schema=true, paths=true, digests=true, count=true,
		canonical_bytes=true, sha256=true,
	}
	local RELATION_FIXED_FIELDS = {
		schema=true, allocator_identity=true, stable_refs=true,
		hydrology_ids=true, hydrology_profile_ids=true, hydrology_depths=true,
		hydrology_bed_seal_layers=true, hydrology_bank_seal_nodes=true,
		interface_ids=true, interface_kinds=true,
		interface_hydrology_ordinals=true, interface_upper_ordinals=true,
		interface_lower_ordinals=true, interface_member_start=true,
		interface_members=true,
	}

	local REQUIRED_MICRO_FAMILIES = {
		"planner_source_nil_non_nil", "logical_biome_passthrough",
		"nearest_route_and_hydrology", "all_p2_p6_opcodes", "all_replace_policies",
		"same_and_cross_priority", "owner_edges_and_authored_floor",
		"bridge_culvert_tunnel_geometry", "seal_totality", "transition_kinds",
		"native_top_boundaries", "heightmap_domain", "native_cave_preservation",
		"project_native_strata", "mask_override", "multi_slice_order",
		"heightmap_plan_independence", "materialization_invariants",
		"ignore_cases", "dirty_light_liquid", "six_liquid_faces",
		"owner_boundary_faces", "owner_halo_order", "adapter_double_apply",
		"plan_provenance_failures", "allocator_provenance_rejection",
		"public_r4_and_disabled",
	}
	local MICRO_RECEIPT_BY_FAMILY={
		planner_source_nil_non_nil="planner_source",
		logical_biome_passthrough="planner_source",
		nearest_route_and_hydrology="planner_source",
		all_p2_p6_opcodes="planner_adapter_relation",
		all_replace_policies="planner_adapter_relation",
		same_and_cross_priority="conflict",
		owner_edges_and_authored_floor="geometry",
		bridge_culvert_tunnel_geometry="geometry",
		seal_totality="seal_totality",
		transition_kinds="geometry",
		native_top_boundaries="heightmap",
		heightmap_domain="heightmap",
		native_cave_preservation="heightmap",
		project_native_strata="heightmap",
		mask_override="heightmap",
		multi_slice_order="owner_order",
		heightmap_plan_independence="heightmap",
		materialization_invariants="actual_adapter",
		ignore_cases="ignore",
		dirty_light_liquid="dirty_light_liquid",
		six_liquid_faces="liquid_faces",
		owner_boundary_faces="liquid_faces",
		owner_halo_order="owner_order",
		adapter_double_apply="planner_adapter_relation",
		plan_provenance_failures="plan_provenance",
		allocator_provenance_rejection="allocator_provenance",
		public_r4_and_disabled="public_r4",
	}
	local MICRO_RECEIPT_TAGS={
		public_r4=true,planner_source=true,geometry=true,replace=true,
		seal_totality=true,actual_adapter=true,actual_light=true,
		dirty_light_liquid=true,planner_adapter_relation=true,conflict=true,
		liquid_faces=true,ignore=true,heightmap=true,owner_order=true,dungeon=true,
		allocator_provenance=true,plan_provenance=true,budget=true,
	}

	local function fail(message)
		error("WP40 simple-map R5 validation: " .. message, 0)
	end

	local function safe_integer(value, label, minimum, maximum)
		minimum = minimum or -MAX_SAFE
		maximum = maximum or MAX_SAFE
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or value < minimum or
				value > maximum then
			fail(label .. " is not a bounded safe integer")
		end
		return value
	end

	local function integer_ascii(value, label)
		return common.integer_ascii(safe_integer(value,label or "canonical integer"),
			label or "canonical integer")
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain table")
		end
		local actual = 0
		for key in pairs(value) do
			if not allowed[key] then fail(label .. " has unexpected field " .. tostring(key)) end
			actual = actual + 1
		end
		local expected = 0
		for key in pairs(allowed) do
			expected = expected + 1
			if rawget(value, key) == nil then fail(label .. " is missing " .. key) end
		end
		if actual ~= expected then fail(label .. " field count differs") end
	end

	local function dense_count(value, label, maximum)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain dense array")
		end
		local count = 0
		for key in pairs(value) do
			safe_integer(key, label .. " key", 1, maximum or MAX_SAFE)
			if key > count then count = key end
		end
		if maximum and count > maximum then fail(label .. " exceeds its bound") end
		for index = 1, count do
			if rawget(value, index) == nil then fail(label .. " has a hole") end
		end
		local actual = 0
		for _ in pairs(value) do actual = actual + 1 end
		if actual ~= count then fail(label .. " has an out-of-prefix key") end
		return count
	end

	local function copy_sorted_vocabulary(values, label, expected_count)
		if dense_count(values, label, expected_count) ~= expected_count then
			fail(label .. " population differs")
		end
		local copy, by_token, previous = {}, {}, nil
		for index = 1, expected_count do
			local token = values[index]
			if type(token) ~= "string" or token == "" then
				fail(label .. " token differs")
			end
			for byte_index = 1, #token do
				if string.byte(token, byte_index) > 127 then
					fail(label .. " token is not ASCII")
				end
			end
			if previous ~= nil and not (previous < token) then
				fail(label .. " is not strictly ASCII sorted")
			end
			copy[index], by_token[token], previous = token, index, token
		end
		return copy, by_token
	end

	OPCODES, OPCODE_ID = copy_sorted_vocabulary(common.OPCODES,
		"Common opcode vocabulary", 32)
	ROLES, ROLE_ID = copy_sorted_vocabulary(common.TARGET_ROLES,
		"Common target-role vocabulary", 16)
	POLICIES, POLICY_TOKEN_ID = copy_sorted_vocabulary(common.REPLACE_POLICIES,
		"Common replace-policy vocabulary", 7)
	CLASSES = copy_sorted_vocabulary(common.CONTENT_CLASSES,
		"Common content-class vocabulary", 11)
	EMITTED_OPCODE, OP_PRIORITY, OP_ROLE, OP_POLICY, OP_POLICY_ALT = {},{},{},{},{}
	if dense_count(OPERATION_RELATION, "operation token relation", 26) ~= 26 then
		fail("operation token relation population differs")
	end
	local operation_variant_count = 0
	for relation_index = 1, #OPERATION_RELATION do
		local row = OPERATION_RELATION[relation_index]
		local row_count = dense_count(row, "operation token relation row", 5)
		if row_count ~= 4 and row_count ~= 5 then
			fail("operation token relation row width differs")
		end
		local opcode, role = OPCODE_ID[row[1]], ROLE_ID[row[3]]
		local primary = POLICY_TOKEN_ID[row[4]]
		local alternate = row[5] and POLICY_TOKEN_ID[row[5]] or nil
		if opcode == nil or role == nil or primary == nil or
				type(row[2]) ~= "number" or row[2] % 1 ~= 0 or
				row[2] < 2 or row[2] > 6 or alternate == primary or
				EMITTED_OPCODE[opcode] then
			fail("operation token relation differs")
		end
		if alternate ~= nil and row[1] ~= "BRIDGE_CLEAR" then
			fail("operation token relation has an unauthorized alternate")
		end
		EMITTED_OPCODE[opcode] = true
		OP_PRIORITY[opcode], OP_ROLE[opcode] = row[2], role
		OP_POLICY[opcode], OP_POLICY_ALT[opcode] = primary, alternate
		operation_variant_count = operation_variant_count + (alternate and 2 or 1)
	end
	if operation_variant_count ~= 27 or
		OP_POLICY_ALT[OPCODE_ID.BRIDGE_CLEAR] ~= POLICY_TOKEN_ID.CUT_NATURAL or
		OP_POLICY[OPCODE_ID.BRIDGE_CLEAR] ~= POLICY_TOKEN_ID.OPEN_ENGINEERED then
		fail("operation closed policy-set relation differs")
	end
	for opcode_token, priority in pairs(RESERVED_PRIORITY_BY_OPCODE) do
		local opcode = OPCODE_ID[opcode_token]
		if opcode == nil or EMITTED_OPCODE[opcode] or
				(priority ~= 7 and priority ~= 8 and priority ~= 9) then
			fail("reserved operation relation differs")
		end
	end

	local function exact_equal(a, b, seen)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		seen = seen or {}
		if seen[a] then return seen[a] == b end
		seen[a] = b
		for key, value in pairs(a) do
			if not exact_equal(value, b[key], seen) then return false end
		end
		for key in pairs(b) do if a[key] == nil then return false end end
		return true
	end

	local function expect_error(prefix, callback, label)
		local ok, message = pcall(callback)
		if ok then fail(label .. " unexpectedly succeeded") end
		if type(message) ~= "string" or message:sub(1, #prefix + 1) ~=
				prefix .. ":" then
			fail(label .. " returned wrong failure " .. tostring(message))
		end
	end

	local function digest_hex(raw_sha256, bytes)
		if type(raw_sha256) ~= "function" then fail("raw SHA-256 helper missing") end
		if type(common) == "table" and type(common.digest_hex) == "function" then
			return common.digest_hex(raw_sha256, bytes)
		end
		local digest = raw_sha256(bytes)
		if type(digest) ~= "string" or #digest ~= 32 then fail("raw SHA-256 result differs") end
		return (digest:gsub(".", function(byte)
			return string.format("%02x", string.byte(byte))
		end))
	end

	local function canonical_scalar(value)
		local kind = type(value)
		if value == nil then return "-" end
		if kind == "boolean" then return value and "true" or "false" end
		if kind == "number" then return integer_ascii(value,"canonical scalar") end
		if kind ~= "string" or value == "" or value:find("[\t\r\n]") then
			fail("canonical scalar is not safe")
		end
		return integer_ascii(#value,"canonical scalar byte length") .. ":" .. value
	end

	local function canonical_rows(raw_sha256, rows)
		local count=dense_count(rows,"canonical source rows")
		if count==0 then fail("canonical source rows are empty") end
		local objects={}
		for index=1,count do
			local row=rows[index]
			if type(row)~="string" or row=="" or row:sub(-1)~="\n" or
					row:sub(1,-2):find("[\r\n]") then
				fail("canonical source row framing differs")
			end
			local line=row:sub(1,-2)
			if line=="" or line:sub(1,1)=="\t" or line:sub(-1)=="\t" or
					line:find("\t\t",1,true) then
				fail("canonical source row has an empty field")
			end
			local values={}
			local first=1
			while true do
				local at=line:find("\t",first,true)
				if at==nil then
					values[#values+1]=line:sub(first)
					break
				end
				values[#values+1]=line:sub(first,at-1)
				first=at+1
			end
			local tag=values[1]
			table.remove(values,1)
			objects[index]=common.canonical_row(tag,unpack(values))
		end
		local bytes=common.render_canonical_rows(objects)
		if bytes~=table.concat(rows) then fail("canonical source rendering differs") end
		return digest_hex(raw_sha256,bytes)
	end

	local function new_shard(fixture_id)
		if not FIXTURE_RANK[fixture_id] then fail("unexpected fixture ID") end
		return {schema=SHARD_SCHEMA, fixture_id=fixture_id, digests={}, counts={},
			proofs={}, metrics={}, seed_kats={}}
	end

	local function add_unique(map, key, value, label)
		if type(key) ~= "string" or key == "" or map[key] ~= nil then
			fail(label .. " duplicate/invalid key")
		end
		map[key] = value
	end

	local function add_digest(shard, key, value)
		if type(value) ~= "string" or not value:match("^[0-9a-f]+$") or #value ~= 64 then
			fail("digest value differs for " .. tostring(key))
		end
		add_unique(shard.digests, key, value, "digest")
	end

	local function add_count(shard, key, value)
		add_unique(shard.counts, key, safe_integer(value, "count", 0), "count")
	end

	local function add_proof(shard, key, value)
		if value ~= true then fail("proof is not true: " .. tostring(key)) end
		add_unique(shard.proofs, key, true, "proof")
	end

	local function add_metric(shard, key, value)
		add_unique(shard.metrics, key, safe_integer(value, "metric", 0), "metric")
	end

	local retained_plan_capacity_checked = setmetatable({}, {__mode="k"})
	local function plan_bytes(plan)
		exact_fields(plan, PLAN_FIELDS, "plan")
		if plan.schema ~= PLAN_SCHEMA then fail("plan schema differs") end
		local run_count = safe_integer(plan.run_count, "plan run count", 0, MAX_RUNS)
		local rows = {plan.schema, integer_ascii(plan.min_x,"plan min x"),
			integer_ascii(plan.min_y,"plan min y"),
			integer_ascii(plan.min_z,"plan min z"),
			integer_ascii(plan.max_x,"plan max x"),
			integer_ascii(plan.max_y,"plan max y"),
			integer_ascii(plan.max_z,"plan max z"),
			integer_ascii(run_count,"plan run count")}
		local columns = (plan.max_x - plan.min_x + 1) *
			(plan.max_z - plan.min_z + 1)
		if not retained_plan_capacity_checked[plan] then
			if dense_count(plan.column_start,"plan column starts",MAX_COLUMNS+1) ~=
					MAX_COLUMNS+1 or
					dense_count(plan.run_values,"plan run values",MAX_RUNS*RUN_STRIDE) ~=
					MAX_RUNS*RUN_STRIDE then fail("retained plan capacity differs") end
			retained_plan_capacity_checked[plan] = true
		end
		for index = 1, columns + 1 do
			rows[#rows + 1] = integer_ascii(plan.column_start[index],"column start")
		end
		for index = 1, run_count * RUN_STRIDE do
			rows[#rows + 1] = integer_ascii(plan.run_values[index],"run value")
		end
		local stable_count = dense_count(plan.stable_refs, "plan stable refs", MAX_STABLE_REFS)
		for index = 1, stable_count do
			local value = plan.stable_refs[index]
			if type(value) ~= "string" or value == "" then fail("stable reference differs") end
			rows[#rows + 1] = integer_ascii(#value,
				"stable reference byte length") .. ":" .. value
		end
		return table.concat(rows, "\n") .. "\n"
	end

	local function validate_plan(plan, generation, expected_identity)
		exact_fields(plan, PLAN_FIELDS, "plan")
		if type(plan.construction_identity)~="table" or
				getmetatable(plan.construction_identity)~=nil then
			fail("plan construction identity differs")
		end
		for _ in pairs(plan.construction_identity) do
			fail("plan construction identity is not empty")
		end
		generation=safe_integer(generation,"plan generation",1)
		if plan.schema ~= PLAN_SCHEMA or plan.valid ~= true or
				plan.generation ~= generation or
				(expected_identity and not rawequal(plan.construction_identity,
					expected_identity)) then
			fail("plan identity/generation differs")
		end
		local min_x = safe_integer(plan.min_x, "plan min x")
		local min_y = safe_integer(plan.min_y, "plan min y", OWNER_MIN, OWNER_MAX)
		local min_z = safe_integer(plan.min_z, "plan min z")
		local max_x = safe_integer(plan.max_x, "plan max x")
		local max_y = safe_integer(plan.max_y, "plan max y", OWNER_MIN, OWNER_MAX)
		local max_z = safe_integer(plan.max_z, "plan max z")
		local x_count, y_count, z_count = max_x-min_x+1, max_y-min_y+1, max_z-min_z+1
		if x_count < 1 or x_count > 80 or y_count < 1 or y_count > 80 or
				z_count < 1 or z_count > 80 or x_count*z_count > MAX_COLUMNS then
			fail("plan bounds differ")
		end
		local columns = x_count * z_count
		if not retained_plan_capacity_checked[plan] then
			if dense_count(plan.column_start, "column starts", MAX_COLUMNS+1) ~=
					MAX_COLUMNS+1 or
					dense_count(plan.run_values, "run values", MAX_RUNS*RUN_STRIDE) ~=
					MAX_RUNS*RUN_STRIDE then
				fail("retained plan capacity differs")
			end
			retained_plan_capacity_checked[plan] = true
		end
		if plan.column_start[1] ~= 1 or
				plan.column_start[columns+1] ~= plan.run_count+1 then
			fail("column-start bounds differ")
		end
		local run_count = safe_integer(plan.run_count, "run count", 0, MAX_RUNS)
		local peak_column = 0
		for column = 1, columns do
			local first, after = plan.column_start[column], plan.column_start[column+1]
			safe_integer(first, "column first", 1, run_count+1)
			safe_integer(after, "column after", first, run_count+1)
			if after-first > 31 then fail("resolved per-column bound exceeded") end
			if after-first > peak_column then peak_column = after-first end
			local previous_y, previous_priority
			for run = first, after-1 do
				local base = (run-1)*RUN_STRIDE
				local y_min = safe_integer(plan.run_values[base+1], "run y min", min_y, max_y)
				local y_max = safe_integer(plan.run_values[base+2], "run y max", y_min, max_y)
				local priority = safe_integer(plan.run_values[base+3], "run priority", 2, 6)
				local opcode = safe_integer(plan.run_values[base+4], "run opcode", 1, #OPCODES)
				local role = safe_integer(plan.run_values[base+5], "run role", 1, #ROLES)
				local policy = safe_integer(plan.run_values[base+6], "run policy", 1, #POLICIES)
				local feature = safe_integer(plan.run_values[base+7], "run feature", 0, MAX_STABLE_REFS)
				local interface = safe_integer(plan.run_values[base+8], "run interface", 0, MAX_STABLE_REFS)
				safe_integer(plan.run_values[base+9], "run aux", 0, 0)
				if not EMITTED_OPCODE[opcode] or OP_PRIORITY[opcode] ~= priority or
						OP_ROLE[opcode] ~= role or
						not opcode_policy_valid(opcode,policy) then
					fail("run vocabulary relation differs")
				end
				if previous_y and y_min <= previous_y then
					fail("resolved run order/overlap differs")
				end
				if y_min < AUTHORED_FLOOR then fail("operation crosses authored floor") end
				if feature > #plan.stable_refs or interface > #plan.stable_refs then
					fail("run stable-reference ordinal differs")
				end
				previous_y, previous_priority = y_max, priority
			end
		end
		return {columns=columns, runs=run_count, peak_resolved=peak_column,
			bytes=plan_bytes(plan)}
	end

	local function expected_stable_refs(source)
		if type(source) ~= "table" then fail("accepted source missing") end
		local result, seen = {}, {}
		local function add(id, label)
			if type(id) ~= "string" or id == "" then fail(label .. " differs") end
			if not seen[id] then
				seen[id] = true
				result[#result + 1] = id
			end
		end
		for _, family in ipairs({source.routes, source.poi_spurs,
				source.island_routes, source.anchors, source.island_landings,
				source.coastal_housing_cores, source.hydrology}) do
			local count = dense_count(family, "stable-reference source family")
			for index = 1, count do add(family[index].id, "stable-reference ID") end
		end
		for index = 1, dense_count(source.hydrology_interfaces,
				"hydrology interfaces") do
			local row = source.hydrology_interfaces[index]
			add(row.id, "hydrology interface ID")
			if row.route_interface_id ~= nil then
				add(row.route_interface_id, "route interface ID")
			end
		end
		for index = 1, dense_count(source.crossing_interfaces,
				"crossing interfaces") do
			add(source.crossing_interfaces[index].id, "crossing interface ID")
		end
		table.sort(result)
		if #result < 1 or #result > WATCH_STABLE_REFS then
			fail("stable-reference population exceeds acceptance watch gate")
		end
		return result
	end

	local function map_by_id(rows, label)
		local result = {}
		for index = 1, dense_count(rows, label) do
			local row = rows[index]
			if type(row) ~= "table" or type(row.id) ~= "string" or row.id == "" or
					result[row.id] ~= nil then fail(label .. " ID relation differs") end
			result[row.id] = row
		end
		return result
	end

	local function relation_oracle(source, plan_refs, raw_sha256)
		local expected_refs = expected_stable_refs(source)
		if not exact_equal(expected_refs, plan_refs) then
			fail("plan stable references differ from independent source union")
		end
		local stable_ordinal = {}
		local stable_rows = {}
		for index = 1, #expected_refs do
			stable_ordinal[expected_refs[index]] = index
			stable_rows[#stable_rows + 1] = integer_ascii(index,"stable ordinal") ..
				"\t" .. integer_ascii(#expected_refs[index],
					"stable ID byte length") .. ":" .. expected_refs[index] .. "\n"
		end
		local routes = map_by_id(source.routes, "routes")
		local crossings = map_by_id(source.crossing_interfaces,
			"crossing interfaces")
		local profiles = map_by_id(source.hydrology_profiles,
			"hydrology profiles")
		local hydrology = map_by_id(source.hydrology, "hydrology")
		local hydro_ordinal, relation_rows = {}, {}
		for index = 1, #source.hydrology do
			local row = source.hydrology[index]
			local profile = profiles[row.profile_id]
			if not profile or safe_integer(profile.depth, "hydrology depth", 0) < 0 or
					profile.bed_seal_layers ~= 3 or profile.bank_seal_nodes ~= 2 then
				fail("hydrology profile relation differs")
			end
			hydro_ordinal[row.id] = index
			relation_rows[#relation_rows + 1] = table.concat({"h",
				integer_ascii(index,"hydrology ordinal"),
				integer_ascii(stable_ordinal[row.id],"hydrology stable ordinal"),
				integer_ascii(#row.id,"hydrology ID byte length") .. ":" .. row.id,
				integer_ascii(#row.profile_id,"profile ID byte length") .. ":" ..
					row.profile_id,
				integer_ascii(profile.depth,"hydrology depth"),
				integer_ascii(profile.bed_seal_layers,"bed seal layers"),
				integer_ascii(profile.bank_seal_nodes,"bank seal nodes")}, "\t") .. "\n"
		end
		local route_interface_owner = {}
		for index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[index]
			local members, hydro, upper, lower = {}, 0, 0, 0
			if row.kind == "bridge" or row.kind == "ford" or
					row.kind == "causeway" then
				hydro = hydro_ordinal[row.hydrology_id] or 0
				local crossing = crossings[row.route_interface_id]
				if hydro == 0 or not crossing or crossing.kind ~= row.kind or
						not routes[crossing.route_id] or
						route_interface_owner[row.route_interface_id] then
					fail("route-interface relation differs")
				end
				route_interface_owner[row.route_interface_id] = index
				members[1] = row.hydrology_id
			elseif row.kind == "rapid" or row.kind == "waterfall" then
				upper, lower = hydro_ordinal[row.upper_id] or 0,
					hydro_ordinal[row.lower_id] or 0
				if upper == 0 or lower == 0 or upper == lower or
						row.route_interface_id ~= nil then
					fail("transition relation differs")
				end
				members[1], members[2] = row.upper_id, row.lower_id
			elseif row.kind == "confluence" then
				if type(row.from_ids) ~= "table" or
						type(row.outgoing_reach_id) ~= "string" then
					fail("confluence relation differs")
				end
				local member_seen = {}
				for member_index = 1, #row.from_ids do
					local id = row.from_ids[member_index]
					if not hydrology[id] then fail("confluence member differs") end
					if not member_seen[id] then
						member_seen[id] = true
						members[#members + 1] = id
					end
				end
				if not hydrology[row.outgoing_reach_id] then
					fail("confluence outgoing reach differs")
				end
				if not member_seen[row.outgoing_reach_id] then
					members[#members + 1] = row.outgoing_reach_id
				end
				if #members < 2 then fail("confluence member count differs") end
			else
				fail("unknown interface kind")
			end
			table.sort(members)
			local member_scalars = {}
			for member_index = 1, #members do
				member_scalars[member_index] = integer_ascii(
					hydro_ordinal[members[member_index]],"interface member ordinal")
			end
			relation_rows[#relation_rows + 1] = table.concat({"i",
				integer_ascii(index,"interface ordinal"),
				integer_ascii(stable_ordinal[row.id],"interface stable ordinal"),
				integer_ascii(#row.id,"interface ID byte length") .. ":" .. row.id,
				row.kind,
				integer_ascii(hydro,"interface hydrology ordinal"),
				integer_ascii(upper,"interface upper ordinal"),
				integer_ascii(lower,"interface lower ordinal"),
				table.concat(member_scalars, ","),
				integer_ascii(row.route_interface_id and
					stable_ordinal[row.route_interface_id] or 0,
					"route interface stable ordinal")},
				"\t") .. "\n"
		end
		for id, crossing in pairs(crossings) do
			if not routes[crossing.route_id] then fail("crossing route differs") end
			if (crossing.kind == "bridge" or crossing.kind == "ford" or
					crossing.kind == "causeway") and not route_interface_owner[id] then
				-- A retained crossing may be a tunnel; water crossings are total.
				fail("water crossing lacks exact interface relation")
			end
		end
		return canonical_rows(raw_sha256, stable_rows),
			canonical_rows(raw_sha256, relation_rows), #expected_refs
	end

	local FUNCTIONAL_KINDS = {anchor_platform=true, bridge_deck=true,
		causeway=true, ford=true, land_grade=true, tunnel_floor=true}
	local TRANSITION_KINDS = {rapid=true, waterfall=true}
	local WATER_CLASSES = {land=true, planned_water=true, coastal_shelf=true,
		deep_ocean=true, immutable_dragon_channel=true}

	local function validate_column_tuple(values, label)
		if type(values) ~= "table" or values.n ~= 20 then
			fail(label .. " does not carry exactly twenty scalars")
		end
		for key in pairs(values) do
			if key~="n" and (type(key)~="number" or key%1~=0 or key<1 or key>20) then
				fail(label .. " has an out-of-tuple key")
			end
		end
		local water_class, zone_numeric, zone_id, biome_id, race_id,
			terrain_y, water_y, hydro_id, profile_depth, functional_kind,
			functional_y, functional_feature, functional_interface,
			transition_kind, transition_interface, transition_upper,
			transition_lower, transition_progress, transition_mask,
			hard_foundation = unpack(values,1,20)
		if not WATER_CLASSES[water_class] then fail(label .. " water class differs") end
		if zone_numeric == nil then
			if zone_id ~= nil or biome_id ~= nil or race_id ~= nil then
				fail(label .. " nil owner tuple differs")
			end
		else
			safe_integer(zone_numeric, label .. " zone numeric", 1)
			if type(zone_id) ~= "string" or type(biome_id) ~= "string" or
					type(race_id) ~= "string" then fail(label .. " owner IDs differ") end
		end
		safe_integer(terrain_y, label .. " terrain y")
		if water_y ~= nil then safe_integer(water_y, label .. " water y") end
		if hydro_id == nil then
			if profile_depth ~= nil then fail(label .. " nil hydrology carries depth") end
		else
			if type(hydro_id) ~= "string" or hydro_id == "" then
				fail(label .. " hydrology ID differs")
			end
			safe_integer(profile_depth, label .. " profile depth", 0)
		end
		if functional_kind == nil then
			if functional_y ~= nil or functional_feature ~= nil or
					functional_interface ~= nil then fail(label .. " nil functional tuple differs") end
		elseif not FUNCTIONAL_KINDS[functional_kind] or
				type(functional_feature) ~= "string" then
			fail(label .. " functional tuple differs")
		else
			safe_integer(functional_y, label .. " functional y")
			if functional_interface ~= nil and type(functional_interface) ~= "string" then
				fail(label .. " functional interface differs")
			end
		end
		if transition_kind == nil then
			if transition_interface ~= nil or transition_upper ~= nil or
					transition_lower ~= nil or transition_progress ~= nil or
					transition_mask ~= nil then fail(label .. " nil transition tuple differs") end
		elseif not TRANSITION_KINDS[transition_kind] or
				type(transition_interface) ~= "string" then
			fail(label .. " transition identity differs")
		else
			safe_integer(transition_upper, label .. " transition upper")
			safe_integer(transition_lower, label .. " transition lower")
			if transition_mask ~= nil then
				if transition_kind ~= "waterfall" or transition_progress ~= nil then
					fail(label .. " contact transition tuple differs")
				end
				safe_integer(transition_mask, label .. " transition mask", 1, 15)
			else
				safe_integer(transition_progress, label .. " transition progress", 0, 65536)
			end
		end
		if type(hard_foundation) ~= "boolean" then fail(label .. " hard flag differs") end
		return biome_id
	end

	local function pack20(...)
		return {n=select("#",...),...}
	end

	local function capture20(callback, x, z)
		return pack20(callback(x, z))
	end

	local function scalar_seam_rows(loaded, points)
		local source = loaded.planner_source
		exact_fields(source, SOURCE_FIELDS, "planner source")
		if source.schema ~= SOURCE_SCHEMA then fail("planner-source schema differs") end
		local rows, logical_equal = {}, true
		local crossing_at={}
		for index=1,#loaded.source.crossing_interfaces do
			local crossing=loaded.source.crossing_interfaces[index]
			crossing_at[integer_ascii(crossing.position.x,"crossing x")..":"..
				integer_ascii(crossing.position.z,"crossing z")]=crossing
		end
		for index = 1, #points do
			local point = points[index]
			local values = capture20(source.column_values_at, point.x, point.z)
			local biome = validate_column_tuple(values, "planner source tuple")
			if biome ~= loaded.session.biome_at(point.x, point.z) then logical_equal=false end
			local row = {integer_ascii(point.x,"scalar point x"),
				integer_ascii(point.z,"scalar point z")}
			for field = 1, 20 do row[#row+1] = canonical_scalar(values[field]) end
			rows[#rows+1] = table.concat(row, "\t") .. "\n"
			local route=loaded.session.nearest_route_at(point.x,point.z)
			if route~=nil and (type(route)~="table" or type(route.route_id)~="string" or
					type(route.segment)~="number" or
					type(route.distance_numerator)~="number" or
					type(route.distance_denominator)~="number") then
				fail("public nearest-route tuple differs")
			end
			local crossing=crossing_at[integer_ascii(point.x,"point x")..":"..
				integer_ascii(point.z,"point z")]
			if crossing and (not route or route.route_id~=crossing.route_id or
					values[12]~=crossing.route_id) then
				fail("private functional/public nearest-route identity differs")
			end
			rows[#rows+1]=table.concat({"r",integer_ascii(point.x,"route point x"),
				integer_ascii(point.z,"route point z"),
				canonical_scalar(route and route.route_id),
				canonical_scalar(route and route.segment),
				canonical_scalar(route and route.distance_numerator),
				canonical_scalar(route and route.distance_denominator)},"\t").."\n"
			local id, segment, numerator, denominator =
				source.hydrology_metric_values_at(point.x, point.z)
			local public = loaded.session.nearest_hydrology_at(point.x, point.z)
			if id == nil then
				if segment ~= nil or numerator ~= nil or denominator ~= nil or public ~= nil then
					fail("nil private/public hydrology tuple differs")
				end
			else
				if not public or public.hydrology_id ~= id or public.segment ~= segment or
						public.distance_numerator ~= numerator or
						public.distance_denominator ~= denominator then
					fail("private/public hydrology metric tuple differs")
				end
			end
			rows[#rows+1] = table.concat({"h",
				integer_ascii(point.x,"hydrology point x"),
				integer_ascii(point.z,"hydrology point z"),canonical_scalar(id),
				canonical_scalar(segment),canonical_scalar(numerator),
				canonical_scalar(denominator)},"\t") .. "\n"
		end
		if not logical_equal then fail("logical-biome private pass-through differs") end
		return rows
	end

	local CLASS_ID = {}
	for index = 1, #CLASSES do CLASS_ID[CLASSES[index]] = index end
	local POLICY_ID = POLICY_TOKEN_ID

	local function replacement_oracle(policy, old_class, old_family,
			target_family, old_cid, old_param2, target_cid, target_param2)
		local outcome
		if old_class == CLASS_ID.IGNORE or old_class == CLASS_ID.FOREIGN or
				old_class == CLASS_ID.UNKNOWN then outcome = 2
		elseif policy == POLICY_ID.DEEP_EXACT_HOST then outcome = 0
		elseif old_class == CLASS_ID.LIQUID and old_family ~= 1 and old_family ~= 2 then
			outcome = 2
		end
		local allowed = false
		if outcome == nil and policy == POLICY_ID.FILL_VOID then
			allowed = old_class == CLASS_ID.AIR or old_class == CLASS_ID.LIQUID or
				old_class == CLASS_ID.NATURAL_VEGETATION
		elseif outcome == nil and policy == POLICY_ID.CUT_NATURAL then
			allowed = old_class ~= CLASS_ID.AIR
		elseif outcome == nil and (policy == POLICY_ID.SURFACE_EXACT or
				policy == POLICY_ID.WRITE_WATER) then
			allowed = true
		elseif outcome == nil and policy == POLICY_ID.SEAL_VOID then
			allowed = old_class == CLASS_ID.AIR or old_class == CLASS_ID.LIQUID or
				old_class == CLASS_ID.NATURAL_VEGETATION
		elseif outcome == nil and policy == POLICY_ID.OPEN_ENGINEERED then
			allowed = old_class ~= CLASS_ID.AIR
		elseif outcome == nil and policy ~= POLICY_ID.DEEP_EXACT_HOST then
			fail("unknown replacement policy")
		end
		if outcome == 2 then return "reject" end
		if outcome == 0 or not allowed then return "preserve" end
		if old_cid == target_cid and old_param2 == target_param2 then return "noop" end
		return "write"
	end

	local function replacement_policy_oracle(policy, old_class, old_family,
			liquid_kind)
		if old_class == CLASS_ID.FOREIGN or old_class == CLASS_ID.IGNORE or
				old_class == CLASS_ID.UNKNOWN then return 2 end
		if policy == POLICY_ID.DEEP_EXACT_HOST then return 0 end
		if old_class == CLASS_ID.LIQUID and
				((old_family ~= 1 and old_family ~= 2) or
					(liquid_kind ~= 1 and liquid_kind ~= 2)) then
			return 2
		end
		if policy == POLICY_ID.FILL_VOID or policy == POLICY_ID.SEAL_VOID then
			return (old_class == CLASS_ID.AIR or old_class == CLASS_ID.LIQUID or
				old_class == CLASS_ID.NATURAL_VEGETATION) and 1 or 0
		end
		if policy == POLICY_ID.CUT_NATURAL or
				policy == POLICY_ID.OPEN_ENGINEERED then
			return old_class == CLASS_ID.AIR and 0 or 1
		end
		if policy == POLICY_ID.SURFACE_EXACT or
				policy == POLICY_ID.WRITE_WATER then return 1 end
		fail("unknown replacement policy")
	end

	local function replacement_matrix_digest(loaded, raw_sha256)
		if type(loaded.adapter_replacement_fixture) ~= "function" then
			fail("production replacement fixture seam is missing")
		end
		local rows = {}
		for policy = 1, #POLICIES do
			for class = 1, #CLASSES do
				local cases = class == CLASS_ID.LIQUID and
					{{1,1},{1,2},{2,1},{2,2},{3,1},{3,2}} or {{0,0}}
				for case_index = 1, #cases do
					local old_family, liquid_kind = cases[case_index][1], cases[case_index][2]
					local expected = replacement_policy_oracle(policy,class,old_family,
						liquid_kind)
					local outcome = loaded.adapter_replacement_fixture(policy,class,
						old_family,liquid_kind,1,2)
					if outcome ~= expected then
						fail("production replacement fixture differs from independent oracle")
					end
					rows[#rows+1] = table.concat({
						integer_ascii(policy,"replacement policy"),
						integer_ascii(class,"replacement class"),
						integer_ascii(old_family,"replacement family"),
						integer_ascii(liquid_kind,"replacement liquid kind"),
						integer_ascii(outcome,"replacement outcome")},"\t").."\n"
				end
			end
		end
		expect_error("fail_fixture",function()
			loaded.adapter_replacement_fixture(1,CLASS_ID.LIQUID,1,0,1,2)
		end,"replacement fixture malformed tuple")
		if #rows~=112 then fail("replacement matrix closed population differs") end
		return canonical_rows(raw_sha256, rows), #rows
	end

	local function manifest_values()
		return {
			schema=MANIFEST_SCHEMA,
			engine_commit="df04879066de6eb94ca43996822a6dfacc74feca",
			mg_name="v7", water_level=1, mapgen_limit=31007, chunksize=5,
			central_owner_y_min=OWNER_MIN, central_owner_y_max=OWNER_MAX,
			heightmap_entries=6400, heightmap_sentinel=HEIGHTMAP_SENTINEL,
			heightmap_order="x_fast_z_outer", emerge_threads=1,
			engine_emerge_setting="num_emerge_threads",
			mg_flags="biomes,caves,decorations,dungeons,light,ores",
			mgv7_spflags="caverns,mountains,ridges", mgv7_dungeon_ymin=-31000,
			mgv7_dungeon_ymax=-193, authored_floor=AUTHORED_FLOOR,
			force_native_dungeon=false,
		}
	end

	local function dense_fill(count, value)
		local result = {}
		for index = 1, count do result[index] = value end
		return result
	end

	local function new_context(heightmap)
		if dense_count(heightmap, "heightmap", 6401) ~= 6400 then
			fail("heightmap population differs")
		end
		local fetches, external, metric_results = 0, 0, 0
		local context = {schema=CONTEXT_SCHEMA}
		function context.get_heightmap()
			fetches, external = fetches + 1, external + 1
			if getmetatable(heightmap)~=nil then return heightmap end
			local result = {}
			for key, value in pairs(heightmap) do result[key] = value end
			return result
		end
		function context.metrics()
			metric_results = metric_results + 1
			return {heightmap_fetch_calls=fetches,
				heightmap_external_table_allocations=external,
				metrics_result_table_allocations=metric_results}
		end
		return context
	end

	local function new_content_contract(options)
		options = options or {}
		local exact_param2=options.exact_param2==true
		local neutral_vegetation=options.neutral_vegetation==true
		local canopy_light=options.canopy_light==true
		local canopy_sunlight=options.canopy_sunlight==true
		local forbid_zero=options.forbid_zero==true
		local forbid_cid=options.forbid_cid
		local missing_role,missing_y,missing_aux=options.missing_role,
			options.missing_y,options.missing_aux
		local ignore_role,ignore_y,ignore_aux=options.ignore_role,
			options.ignore_y,options.ignore_aux
		if missing_role~=nil or missing_y~=nil or missing_aux~=nil then
			if missing_role~=ROLE_ID.STRATUM_AT_Y or missing_y~=OWNER_MAX or
					missing_aux~=0 then
				fail("missing exception tuple differs")
			end
		end
		if ignore_role~=nil or ignore_y~=nil or ignore_aux~=nil then
			if ignore_role~=ROLE_ID.BRIDGE_DECK or ignore_y~=OWNER_MAX or
					ignore_aux~=0 then
				fail("ignore exception tuple differs")
			end
		end
		local resolve_calls, classify_calls, metric_results = 0, 0, 0
		local classify_log_count=0
		local missing_tuple_calls,ignore_tuple_calls=0,0
		local classify_cids,classify_param2s={},{}
		local defs = {}
		local function define(cid, class, family, kind, level, floodable,
				paramtype_light, light, sunlight, source)
			defs[cid] = {class,family or 0,kind or 0,level or 0,
				floodable or false,paramtype_light or false,light or false,
				sunlight or false,source or 0}
		end
		define(0, CLASS_ID.AIR, 0, 0, 0, true, true, true, true, 0)
		define(1, CLASS_ID.NATURAL_HOST)
		define(2, CLASS_ID.NATURAL_SURFACE)
		define(3, CLASS_ID.NATURAL_VEGETATION, 0, 0, 0, true,
			not neutral_vegetation,canopy_light,canopy_sunlight,0)
		define(4, CLASS_ID.NATIVE_ORE)
		define(5, CLASS_ID.WP43_RESOURCE)
		define(6, CLASS_ID.WP43_STRATUM)
		define(7, CLASS_ID.LIQUID, 1, 1, 0, false, true, true, true, 0)
		define(8, CLASS_ID.LIQUID, 2, 1, 0, false, true, true, true, 0)
		define(9, CLASS_ID.FOREIGN)
		define(10, CLASS_ID.UNKNOWN)
		define(11, CLASS_ID.LIQUID, 3, 1, 0, false, true, true, true, 0)
		-- Two validator-only canopy CIDs keep the opaque and sunlight-propagating
		-- seed branches independent of the ordinary vegetation fixture option.
		define(12, CLASS_ID.NATURAL_VEGETATION, 0, 0, 0, true, true, true, false, 0)
		define(13, CLASS_ID.NATURAL_VEGETATION, 0, 0, 0, true, true, true, true, 0)
		define(14, CLASS_ID.NATURAL_VEGETATION, 0, 0, 0, true, true, true, false, 0)
		-- Flowing fixtures deliberately derive their liquid level from param2;
		-- this catches any CID-only classification cache.
		define(15, CLASS_ID.LIQUID, 1, 2, 0, false, true, true, true, 0)
		define(16, CLASS_ID.LIQUID, 3, 2, 0, false, true, true, true, 0)
		define(17, CLASS_ID.NATURAL_VEGETATION, 0, 0, 0, true,
			false, false, false, 0)
		define(65535, CLASS_ID.IGNORE)
		local role_cid = {}
		for role = 1, #ROLES do
			local cid = 100 + role
			role_cid[role] = cid
			if role == 1 then
				define(cid, CLASS_ID.AIR, 0, 0, 0, true, true, true, true, 0)
			elseif role == 10 then
				define(cid, CLASS_ID.LIQUID, 1, 1, 0, false, true, true, true, 0)
			elseif role == 13 then
				define(cid, CLASS_ID.LIQUID, 2, 1, 0, false, true, true, true, 0)
			elseif role == 8 or role == 12 or role == 5 or role == 6 then
				define(cid, CLASS_ID.NATURAL_SURFACE)
			elseif role == 14 then
				define(cid, CLASS_ID.WP43_STRATUM)
			else
				define(cid, CLASS_ID.NATURAL_HOST)
			end
		end
		local contract = {schema=CONTENT_SCHEMA, ignore_cid=65535,
			ordinary_water_family_id=1, river_water_family_id=2}
		function contract.resolve(role, y, aux)
			resolve_calls = resolve_calls + 1
			safe_integer(role, "fixture role", 1, #ROLES)
			safe_integer(y, "fixture y")
			if ignore_role~=nil and role==ignore_role and y==ignore_y and
					aux==ignore_aux then
				ignore_tuple_calls=ignore_tuple_calls+1
				return 65535,1,0,nil
			end
			if missing_role~=nil and role==missing_role and y==missing_y and
					aux==missing_aux then
				missing_tuple_calls=missing_tuple_calls+1
				return nil
			end
			if aux ~= 0 then fail("fixture aux differs") end
			local kind = role == 1 and 0 or
				((role == 10 or role == 13) and 2 or 1)
			if exact_param2 then return role_cid[role], kind, 1, role end
			return role_cid[role], kind, 0, nil
		end
		function contract.classify(cid, param2)
			classify_calls = classify_calls + 1
			if cid==15 or cid==16 then
				classify_log_count=classify_log_count+1
				classify_cids[classify_log_count]=cid
				classify_param2s[classify_log_count]=param2
			end
			safe_integer(cid, "fixture CID", 0)
			safe_integer(param2, "fixture param2", 0, 255)
			if forbid_zero and cid==0 then
				fail("inactive retained tail was classified")
			end
			if forbid_cid~=nil and cid==forbid_cid then
				fail("forbidden halo CID was classified")
			end
			if cid==15 then
				return CLASS_ID.LIQUID,1,2,param2,false,true,true,true,0
			elseif cid==16 then
				return CLASS_ID.LIQUID,3,2,param2,false,true,true,true,0
			end
			local row = defs[cid]
			if not row then row = defs[10] end
			return unpack(row)
		end
		function contract.metrics()
			metric_results = metric_results + 1
			return {resolve_calls=resolve_calls, classify_calls=classify_calls,
				query_table_allocations=0,
				metrics_result_table_allocations=metric_results}
		end
		local function observer()
			return classify_log_count,classify_cids,classify_param2s,
				missing_tuple_calls,ignore_tuple_calls
		end
		return contract,observer
	end

	local function load_r5(offline, seed, heightmap, content_options, paired)
		if type(offline) ~= "table" or type(offline.load_r5) ~= "function" or
				type(offline.raw_sha256) ~= "function" then fail("offline loader differs") end
		local content,content_observer = new_content_contract(content_options)
		local context,trace_token,loaded
		if paired==true then
			loaded,context,trace_token=offline.load_r5(seed,manifest_values(),content,
				{schema=common.R5_PAIRED_CONTEXT_REQUEST_SCHEMA,heightmap=heightmap})
		else
			context = new_context(heightmap)
			loaded = offline.load_r5(seed, manifest_values(), content, context)
		end
		exact_fields(loaded,R5_LOAD_FIELDS,"offline R5 load result")
		if type(loaded.planner) ~= "table" or type(loaded.adapter) ~= "table" or
				type(loaded.planner_source) ~= "table" or type(loaded.session) ~= "table" or
				type(loaded.source) ~= "table" then
			fail("offline R5 load result differs")
		end
		loaded.fixture_content = content
		loaded.fixture_content_observer = content_observer
		loaded.fixture_context = context
		loaded.fixture_heightmap = heightmap
		loaded.fixture_trace_token = trace_token
		return loaded
	end

	local function owner_position(x, y, z)
		return {x=x,y=y,z=z}
	end

	local function plan_at(loaded, minp, maxp)
		local plan, generation = loaded.planner:plan_slice(minp, maxp)
		local validation = validate_plan(plan, generation)
		return plan, generation, validation
	end

	local MASK_BY_OPCODE
	local function plan_counts(plan, counts, mask_counts)
		for run = 1, plan.run_count do
			local base = (run-1)*RUN_STRIDE
			local opcode = plan.run_values[base+4]
			local priority = plan.run_values[base+3]
			counts[OPCODES[opcode]] = (counts[OPCODES[opcode]] or 0) + 1
			counts["priority/"..priority] = (counts["priority/"..priority] or 0) + 1
			local mask = MASK_BY_OPCODE and MASK_BY_OPCODE[opcode]
			if mask then mask_counts[mask] = (mask_counts[mask] or 0) + 1 end
		end
	end

	local function add_run_count(run_values,base,multiplier,counts,mask_counts)
		local opcode=run_values[base+4]
		local priority=run_values[base+3]
		counts[OPCODES[opcode]]=(counts[OPCODES[opcode]] or 0)+multiplier
		counts["priority/"..priority]=(counts["priority/"..priority] or 0)+multiplier
		local mask=MASK_BY_OPCODE and MASK_BY_OPCODE[opcode]
		if mask then mask_counts[mask]=(mask_counts[mask] or 0)+multiplier end
	end

	local function run_semantic_signature(run_values,base)
		local fields={}
		for offset=3,RUN_STRIDE do
			fields[#fields+1]=integer_ascii(run_values[base+offset],
				"run semantic scalar")
		end
		return table.concat(fields,":"),run_values[base+4]
	end

	MASK_BY_OPCODE = {}
	for opcode_token,mask in pairs({
		FOUNDATION_CLEAR="foundation",FOUNDATION_FILL="foundation",
		FOUNDATION_SURFACE="foundation",PATH_CLEAR="path",PATH_FILL="path",
		PATH_SURFACE="path",FORD_BED="ford",BRIDGE_CLEAR="bridge_clear",
		BRIDGE_SUPPORT="bridge_support",BRIDGE_DECK="bridge_deck",
		CAUSEWAY_FILL="causeway",CAUSEWAY_SURFACE="causeway",
		CAUSEWAY_CULVERT="culvert",TUNNEL_FLOOR="tunnel_floor",
		TUNNEL_LUMEN="tunnel_lumen",TUNNEL_WALL="tunnel_wall",
		TUNNEL_ROOF="tunnel_roof",HYDROLOGY_BED_SEAL="bed_seal",
		HYDROLOGY_BANK_SEAL="bank_seal",RECEIVER_OPEN="receiver_open",
		CONTACT_FALL_CLEAR="contact_fall_clear",TERRAIN_FILL="terrain_fill",
		TERRAIN_SURFACE="terrain_surface",TERRAIN_CLEAR="terrain_clear",
	}) do
		local opcode=OPCODE_ID[opcode_token]
		if not opcode or MASK_BY_OPCODE[opcode] then fail("mask relation differs") end
		MASK_BY_OPCODE[opcode]=mask
	end

	local function metric_sum(a, b, key)
		return safe_integer(a[key], "allocator metric " .. key, 0) +
			safe_integer(b[key], "allocator metric " .. key, 0)
	end

	local function terminal_metrics(loaded)
		if type(loaded.allocators) ~= "table" or #loaded.allocators ~= 2 then
			fail("offline allocator capture differs")
		end
		local planner_allocator = loaded.allocators[1]:metrics()
		local adapter_allocator = loaded.allocators[2]:metrics()
		local source = loaded.planner_source.metrics()
		local planner = loaded.planner:metrics()
		local adapter = loaded.adapter:metrics()
		local context = loaded.fixture_context.metrics()
		local result = {
			horizontal_session_count=source.horizontal_session_count,
			height_session_count=source.height_session_count,
			planner_source_count=source.planner_source_count,
			planner_construction_count=planner.planner_construction_count,
			plan_identity_count=planner.plan_identity_count,
			stable_ref_count=planner.stable_ref_count,
			plan_slice_table_allocations=planner.plan_slice_table_allocations,
			adapter_apply_table_allocations=adapter.adapter_apply_table_allocations,
			emerged_area_external_table_allocations=
				adapter.emerged_area_external_table_allocations,
			heightmap_fetch_calls=context.heightmap_fetch_calls,
			heightmap_entries_validated=adapter.heightmap_entries_validated,
			heightmap_external_table_allocations=
				context.heightmap_external_table_allocations,
			peak_candidate_runs_per_column=planner.peak_candidate_runs_per_column,
			peak_resolved_runs_per_column=planner.peak_resolved_runs_per_column,
			peak_resolved_runs_per_slice=planner.peak_resolved_runs_per_slice,
			peak_run_value_cells=planner.peak_run_value_cells,
			plan_buffer_reuse_calls=planner.plan_buffer_reuse_calls,
		}
		for _, key in ipairs({"construction_table_allocations",
			"construction_array_tables","construction_map_tables",
			"allocator_bootstrap_tables","retained_numeric_capacity",
			"retained_map_key_capacity","retained_map_key_count",
			"allocator_growth_events","hotpath_entries","hotpath_table_allocations"}) do
			result[key] = metric_sum(planner_allocator, adapter_allocator, key)
		end
		result.metrics_result_table_allocations =
			planner_allocator.metrics_result_table_allocations +
			adapter_allocator.metrics_result_table_allocations +
			planner.metrics_result_table_allocations +
			adapter.metrics_result_table_allocations
		for _, key in ipairs({"classified_columns","planned_columns",
			"modified_voxels","content_dirty_columns","param2_dirty_columns",
			"light_dirty_columns","liquid_dirty_columns","light_seed_runs",
			"peak_light_seed_runs","vm_get_emerged_area_calls","vm_get_data_calls",
			"vm_set_data_calls","vm_get_param2_calls","vm_set_param2_calls",
			"vm_get_light_calls","vm_set_lighting_calls","vm_calc_lighting_calls",
			"vm_set_light_data_calls","vm_update_liquids_calls"}) do
			result[key] = adapter[key]
		end
		return result
	end

	local function owner_chunk_min(value)
		return -32 + math.floor((value + 32) / 80) * 80
	end

	local function add_event_slice(events, y)
		if y == nil then return end
		y = safe_integer(y, "event y")
		if y < OWNER_MIN then y = OWNER_MIN end
		if y > OWNER_MAX then y = OWNER_MAX end
		events[owner_chunk_min(y)] = true
	end

	local function add_tuple_events(events, values)
		local terrain, water = values[6], values[7]
		add_event_slice(events, AUTHORED_FLOOR)
		add_event_slice(events, terrain)
		add_event_slice(events, terrain + 1)
		add_event_slice(events, terrain + 4)
		add_event_slice(events, math.max(terrain, water or terrain))
		add_event_slice(events, math.max(terrain, water or terrain) + 1)
		if values[11] ~= nil then
			for delta = -2, 5 do add_event_slice(events, values[11] + delta) end
		end
		if water ~= nil and values[9] ~= nil then
			local bed=water-values[9]
			for delta=-2,1 do add_event_slice(events,bed+delta) end
		end
		if values[16] ~= nil then
			for delta = -20, 5 do add_event_slice(events, values[16] + delta) end
		end
		if values[17] ~= nil then
			for delta = -20, 5 do add_event_slice(events, values[17] + delta) end
		end
		add_event_slice(events, OWNER_MIN)
		add_event_slice(events, OWNER_MAX)
	end

	local function sorted_numeric_keys(map)
		local result = {}
		for value in pairs(map) do result[#result+1] = value end
		table.sort(result)
		return result
	end

	local function new_vm_for_plan(loaded, minp, maxp, height_value, old_cid,
			old_param2, old_light, verify_inactive_tail)
		if type(loaded.vm_module) ~= "table" or
				type(loaded.vm_module.new) ~= "function" then fail("VM module missing") end
		local x_count = maxp.x-minp.x+1+32
		local y_count = maxp.y-minp.y+1+32
		local z_count = maxp.z-minp.z+1+32
		local volume = x_count*y_count*z_count
		local heightmap = dense_fill(6400, height_value)
		local spec={minp=minp,maxp=maxp,
			data=dense_fill(volume,old_cid or 0),
			param2=dense_fill(volume,old_param2 or 0),
			light=dense_fill(volume,old_light or 0),
			content_contract=loaded.fixture_content,water_level=1,ignore_cid=65535,
			verify_inactive_tail=verify_inactive_tail==true}
		local vm,context,observer
		if loaded.fixture_trace_token then
			vm,context,observer=loaded.vm_module.new(spec,loaded.fixture_trace_token)
			if not rawequal(context,loaded.fixture_context) then
				fail("paired VM context identity differs")
			end
		else
			spec.heightmap=heightmap
			vm,context,observer=loaded.vm_module.new(spec)
		end
		return vm, observer
	end

	local CLASS_CID = {
		[CLASS_ID.AIR]=0,[CLASS_ID.FOREIGN]=9,[CLASS_ID.IGNORE]=65535,
		[CLASS_ID.LIQUID]=7,[CLASS_ID.NATIVE_ORE]=4,
		[CLASS_ID.NATURAL_HOST]=1,[CLASS_ID.NATURAL_SURFACE]=2,
		[CLASS_ID.NATURAL_VEGETATION]=3,[CLASS_ID.UNKNOWN]=10,
		[CLASS_ID.WP43_RESOURCE]=5,[CLASS_ID.WP43_STRATUM]=6,
	}
	local POLICY_OPCODE = {
		[POLICY_ID.CUT_NATURAL]=OPCODE_ID.FOUNDATION_CLEAR,
		[POLICY_ID.FILL_VOID]=OPCODE_ID.FOUNDATION_FILL,
		[POLICY_ID.OPEN_ENGINEERED]=OPCODE_ID.BRIDGE_CLEAR,
		[POLICY_ID.SEAL_VOID]=OPCODE_ID.HYDROLOGY_BANK_SEAL,
		[POLICY_ID.SURFACE_EXACT]=OPCODE_ID.FOUNDATION_SURFACE,
		[POLICY_ID.WRITE_WATER]=OPCODE_ID.ORDINARY_WATER,
	}
	local ACTUAL_POLICIES={POLICY_ID.CUT_NATURAL,POLICY_ID.FILL_VOID,
		POLICY_ID.OPEN_ENGINEERED,POLICY_ID.SEAL_VOID,
		POLICY_ID.SURFACE_EXACT,POLICY_ID.WRITE_WATER}

	local function emerged_geometry(minp,maxp)
		local emin={x=minp.x-16,y=minp.y-16,z=minp.z-16}
		local emax={x=maxp.x+16,y=maxp.y+16,z=maxp.z+16}
		local ex=emax.x-emin.x+1
		local ey=emax.y-emin.y+1
		return emin,emax,ex,ey,ex*ey,(emax.x-emin.x+1)*ey*(emax.z-emin.z+1)
	end

	local function emerged_index(minp,maxp,x,y,z)
		local emin,emax,ex,_,z_stride=emerged_geometry(minp,maxp)
		if x<emin.x or x>emax.x or y<emin.y or y>emax.y or
				z<emin.z or z>emax.z then fail("fixture coordinate is outside emerged area") end
		return (z-emin.z)*z_stride+(y-emin.y)*ex+(x-emin.x)+1
	end

	local function new_vm_fixture(loaded,minp,maxp,height_value,base_cid,
			base_param2,base_light,overrides,verify_inactive_tail)
		local _,_,_,_,_,volume=emerged_geometry(minp,maxp)
		local data=dense_fill(volume,base_cid or 0)
		local param2=dense_fill(volume,base_param2 or 0)
		local light=dense_fill(volume,base_light or 0)
		for index=1,#(overrides or {}) do
			local row=overrides[index]
			local offset=emerged_index(minp,maxp,row.x,row.y,row.z)
			if row.cid~=nil then data[offset]=row.cid end
			if row.param2~=nil then param2[offset]=row.param2 end
			if row.light~=nil then light[offset]=row.light end
		end
		local spec={minp=minp,maxp=maxp,
			data=data,param2=param2,light=light,
			content_contract=loaded.fixture_content,water_level=1,ignore_cid=65535,
			verify_inactive_tail=verify_inactive_tail==true}
		local vm,context,observer
		if loaded.fixture_trace_token then
			vm,context,observer=loaded.vm_module.new(spec,loaded.fixture_trace_token)
			if not rawequal(context,loaded.fixture_context) then
				fail("paired VM context identity differs")
			end
		else
			spec.heightmap=dense_fill(6400,height_value)
			vm,context,observer=loaded.vm_module.new(spec)
		end
		return vm,observer
	end

	local function rewrite_plan(plan,generation,specs)
		local columns=(plan.max_x-plan.min_x+1)*(plan.max_z-plan.min_z+1)
		local previous_column,previous_y,run_count=0,nil,0
		for index=1,#specs do
			local row=specs[index]
			safe_integer(row.column,"fixture plan column",1,columns)
			safe_integer(row.y_min,"fixture plan y min",plan.min_y,plan.max_y)
			safe_integer(row.y_max,"fixture plan y max",row.y_min,plan.max_y)
			if row.column<previous_column or
					(row.column==previous_column and previous_y and row.y_min<=previous_y) then
				fail("fixture plan rows are not canonical")
			end
			previous_column,previous_y=row.column,row.y_max
		end
		local spec_index=1
		for column=1,columns do
			plan.column_start[column]=run_count+1
			while spec_index<=#specs and specs[spec_index].column==column do
				local row=specs[spec_index]
				local opcode=row.opcode
				if not EMITTED_OPCODE[opcode] then fail("fixture opcode is not emitted") end
				run_count=run_count+1
				local base=(run_count-1)*RUN_STRIDE
				plan.run_values[base+1]=row.y_min
				plan.run_values[base+2]=row.y_max
				plan.run_values[base+3]=OP_PRIORITY[opcode]
				plan.run_values[base+4]=opcode
				plan.run_values[base+5]=OP_ROLE[opcode]
				local policy=row.policy or OP_POLICY[opcode]
				if not opcode_policy_valid(opcode,policy) then
					fail("fixture opcode policy is outside closed relation")
				end
				plan.run_values[base+6]=policy
				plan.run_values[base+7]=row.feature or 0
				plan.run_values[base+8]=row.interface or 0
				plan.run_values[base+9]=0
				spec_index=spec_index+1
			end
		end
		plan.column_start[columns+1]=run_count+1
		plan.run_count=run_count
		validate_plan(plan,generation)
		return plan
	end

	local function one_run_plan(loaded,minp,maxp,x,z,y,opcode)
		local plan,generation=plan_at(loaded,minp,maxp)
		local column=(z-minp.z)*80+(x-minp.x)+1
		rewrite_plan(plan,generation,
			{{column=column,y_min=y,y_max=y,opcode=opcode}})
		return plan,generation,column
	end

	local function apply_specs(loaded,minp,maxp,specs,base_cid,base_param2,
			base_light,overrides,verify_inactive_tail)
		local plan,generation=plan_at(loaded,minp,maxp)
		rewrite_plan(plan,generation,specs)
		local before=loaded.adapter:metrics()
		local vm,observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,
			base_cid,base_param2,base_light,overrides,verify_inactive_tail)
		local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
			"offline_fixture")
		local snapshot=observer.snapshot()
		local after=loaded.adapter:metrics()
		local delta={}
		for key,value in pairs(after) do
			if type(value)=="number" and type(before[key])=="number" then
				delta[key]=value-before[key]
			end
		end
		return outcome,snapshot,delta,plan,generation,vm,observer
	end

	local function snapshot_cell(snapshot,minp,maxp,x,y,z)
		local index=emerged_index(minp,maxp,x,y,z)
		return snapshot.data[index],snapshot.param2[index],snapshot.light[index]
	end

	local function call_signature(snapshot)
		local names={"get_emerged_area","get_data","get_param2_data",
			"get_light_data","set_data","set_param2_data","set_lighting",
			"calc_lighting","set_light_data","update_liquids"}
		local fields={}
		for index=1,#names do
			fields[#fields+1]=names[index].."="..
				integer_ascii(snapshot.calls[names[index]],"VM call count")
		end
		return table.concat(fields,",")
	end

	local function production_apply_matrix(loaded,raw_sha256,tail_case)
		local minp=owner_position(-32,AUTHORED_FLOOR,-32)
		local maxp=owner_position(47,2,47)
		local rows={}
		local centre_y=AUTHORED_FLOOR+1
		local specs,overrides={},{ }
		for policy_index=1,#ACTUAL_POLICIES do
			local policy=ACTUAL_POLICIES[policy_index]
			local x=-28+(policy_index-1)*10
			local opcode=POLICY_OPCODE[policy]
			local role=OP_ROLE[opcode]
			specs[#specs+1]={column=(0-minp.z)*80+(x-minp.x)+1,
				y_min=centre_y,y_max=centre_y,opcode=opcode}
			local old_cid=1
			if policy==POLICY_ID.FILL_VOID then old_cid=0 end
			if policy==POLICY_ID.SEAL_VOID then old_cid=3 end
			overrides[#overrides+1]={x=x,y=centre_y,z=0,cid=old_cid,param2=role}
		end
		local outcome,snapshot,delta,plan,generation,vm,observer=
			apply_specs(loaded,minp,maxp,specs,1,0,0,
			overrides,tail_case==true)
		if not outcome:match("^applied_") then fail("policy write matrix did not commit") end
		if tail_case==true and (snapshot.active_volume>=snapshot.retained_capacity or
				snapshot.inactive_tail_checks~=16 or
				snapshot.inactive_tail_unchanged~=true) then
			fail("nonempty reduced-Y retained-tail matrix differs")
		end
		if tail_case==true then
			local second=loaded.adapter:apply(vm,minp,maxp,plan,generation,
				"offline_fixture")
			local second_snapshot=observer.snapshot()
			if second~="noop_equal_content" or
					second_snapshot.inactive_tail_checks~=24 or
					second_snapshot.inactive_tail_unchanged~=true or
					not exact_equal(snapshot.data,second_snapshot.data) or
					not exact_equal(snapshot.param2,second_snapshot.param2) then
				fail("same-VM retained-tail second apply differs")
			end
			rows[#rows+1]="tail_double_apply\t16\t24\tnoop_equal_content\n"
		end
		for policy_index=1,#ACTUAL_POLICIES do
			local policy=ACTUAL_POLICIES[policy_index]
			local x=-28+(policy_index-1)*10
			local opcode=POLICY_OPCODE[policy]
			local role=OP_ROLE[opcode]
			local cid,p2=snapshot_cell(snapshot,minp,maxp,x,centre_y,0)
			local expected_cid=100+role
			if cid~=expected_cid or p2~=role then
				fail("actual adapter policy result differs from independent expectation")
			end
			rows[#rows+1]=table.concat({"policy",
				integer_ascii(policy,"policy apply ordinal"),
				integer_ascii(cid,"policy final cid"),
				integer_ascii(p2,"policy final param2")},"\t").."\n"
		end
		rows[#rows+1]="policy_calls\t"..call_signature(snapshot).."\n"
		rows[#rows+1]="policy_modified\t"..
			integer_ascii(delta.modified_voxels,"policy modified voxels").."\n"

		local reject_cases={{"ignore",65535,"fail_content_ignore"}}
		for index=1,#reject_cases do
			local plan,generation=plan_at(loaded,minp,maxp)
			local target_column=(8-minp.z)*80+(0-minp.x)+1
			rewrite_plan(plan,generation,{{column=target_column,y_min=centre_y,
				y_max=centre_y,opcode=OPCODE_ID.FOUNDATION_FILL}})
			local vm=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,7,0,
				{{x=0,y=centre_y,z=8,cid=reject_cases[index][2],param2=7}},false)
			expect_error(reject_cases[index][3],function()
				loaded.adapter:apply(vm,minp,maxp,plan,generation,"offline_fixture")
			end,"actual adapter rejection "..reject_cases[index][1])
			rows[#rows+1]="reject\t"..reject_cases[index][1].."\t"..
				reject_cases[index][3].."\n"
		end

		local dirty_cases={
			{"content_only",2,ROLE_ID.FOUNDATION_SURFACE,
				OPCODE_ID.FOUNDATION_SURFACE,"applied_c",false},
			{"param2_only",107,0,OPCODE_ID.FOUNDATION_FILL,"applied_p",false},
			{"light",0,7,OPCODE_ID.FOUNDATION_FILL,"applied_cl",false},
			{"liquid_direct",7,7,OPCODE_ID.FOUNDATION_FILL,"applied_clq",true},
		}
		local dirty_specs,dirty_overrides={},{}
		for index=1,#dirty_cases do
			local row=dirty_cases[index]
			local x=-18+(index-1)*12
			dirty_specs[#dirty_specs+1]={column=(8-minp.z)*80+(x-minp.x)+1,
				y_min=centre_y,y_max=centre_y,opcode=row[4]}
			dirty_overrides[#dirty_overrides+1]={x=x,y=centre_y,z=8,
				cid=row[2],param2=row[3]}
		end
		local dirty_result,dirty_state,dirty_change=apply_specs(loaded,minp,maxp,
			dirty_specs,1,0,15,dirty_overrides,false)
		if dirty_result~="applied_cplq" or dirty_change.modified_voxels~=4 or
				dirty_change.content_dirty_columns~=3 or
				dirty_change.param2_dirty_columns~=1 or
				dirty_change.light_dirty_columns~=2 or
				dirty_change.liquid_dirty_columns~=1 then
			fail("packed dirty matrix actual result differs")
		end
		for index=1,#dirty_cases do
			local x=-18+(index-1)*12
			local cid,p2=snapshot_cell(dirty_state,minp,maxp,x,centre_y,8)
			local role=OP_ROLE[dirty_cases[index][4]]
			if cid~=100+role or p2~=role then
				fail("packed dirty final state differs")
			end
		end
		rows[#rows+1]="packed_dirty\t"..dirty_result.."\t"..
			call_signature(dirty_state).."\n"

		return canonical_rows(raw_sha256,rows),rows
	end

	local VM_CALL_NAMES={"get_emerged_area","get_heightmap","get_data",
		"get_param2_data","get_light_data","set_data","set_param2_data",
		"set_lighting","calc_lighting","set_light_data","update_liquids"}
	local function assert_exact_vm_calls(snapshot,expected_trace,label)
		if dense_count(snapshot.trace,label.." trace")~=#expected_trace then
			fail(label.." trace length differs")
		end
		local expected_counts={}
		for index=1,#expected_trace do
			local expected=expected_trace[index]
			local name=expected:match("^([^:]+)")
			local actual=snapshot.trace[index]
			local actual_name=actual:match("^([^:]+)")
			if actual_name~=name or
					(expected:find(":",1,true) and actual~=expected) or
					(not expected:find(":",1,true) and actual~=name) then
				fail(label.." call order/detail differs")
			end
			expected_counts[name]=(expected_counts[name] or 0)+1
		end
		for index=1,#VM_CALL_NAMES do
			local name=VM_CALL_NAMES[index]
			if snapshot.calls[name]~=(expected_counts[name] or 0) then
				fail(label.." call delta differs: "..name)
			end
		end
	end

	local function actual_adapter_call_matrix(loaded,raw_sha256)
		local minp=owner_position(-32,AUTHORED_FLOOR,-32)
		local maxp=owner_position(47,AUTHORED_FLOOR+2,47)
		local y=AUTHORED_FLOOR+1
		local light_min_x=math.max(-15,minp.x-16)
		local light_min_y=math.max(y-15,minp.y-16)
		local light_min_z=math.max(-15,minp.z-16)
		local light_max_x=math.min(15,maxp.x+16)
		local light_max_y=math.min(y+15,maxp.y+16)
		local light_max_z=math.min(15,maxp.z+16)
		local light_box=integer_ascii(light_min_x,"call-matrix light min x")..","..
			integer_ascii(light_min_y,"call-matrix light min y")..","..
			integer_ascii(light_min_z,"call-matrix light min z")..","..
			integer_ascii(light_max_x,"call-matrix light max x")..","..
			integer_ascii(light_max_y,"call-matrix light max y")..","..
			integer_ascii(light_max_z,"call-matrix light max z")
		local base_trace={"get_emerged_area","get_heightmap","get_data",
			"get_param2_data"}
		local cases={
			{"noop_equal_water",OPCODE_ID.ORDINARY_WATER,110,10,
				"noop_equal_content",110,10,{},0},
			{"content_only",OPCODE_ID.FOUNDATION_SURFACE,2,
				ROLE_ID.FOUNDATION_SURFACE,"applied_c",
				100+ROLE_ID.FOUNDATION_SURFACE,ROLE_ID.FOUNDATION_SURFACE,
				{"set_data"},0},
			{"param2_only",OPCODE_ID.FOUNDATION_FILL,107,0,
				"applied_p",107,7,{"set_param2_data"},0},
			{"light_relevant",OPCODE_ID.FOUNDATION_FILL,0,7,"applied_cl",107,7,
				{"get_light_data","set_data",
					"set_lighting:0,0,"..light_box,
					"calc_lighting:"..light_box..",true",
					"get_light_data","set_light_data"},0},
			{"flowing_level_3",OPCODE_ID.ORDINARY_WATER,15,3,"applied_cpq",110,10,
				{"set_data","set_param2_data","update_liquids"},1},
			{"flowing_level_4",OPCODE_ID.ORDINARY_WATER,15,4,"applied_cpq",110,10,
				{"set_data","set_param2_data","update_liquids"},1},
		}
		local rows={}
		local plan,generation=plan_at(loaded,minp,maxp)
		for index=1,#cases do
			local row=cases[index]
			rewrite_plan(plan,generation,{{column=(0-minp.z)*80+(0-minp.x)+1,
				y_min=y,y_max=y,opcode=row[2]}})
			local vm,observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,
				1,7,15,{{x=0,y=y,z=0,cid=row[3],param2=row[4]}},false)
			local before=loaded.adapter:metrics()
			local classify_before=loaded.fixture_content_observer()
			local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
				"offline_fixture")
			local after=loaded.adapter:metrics()
			local classify_after,classify_cids,classify_param2s=
				loaded.fixture_content_observer()
			local snapshot=observer.snapshot()
			local expected={unpack(base_trace)}
			for call=1,#row[8] do expected[#expected+1]=row[8][call] end
			assert_exact_vm_calls(snapshot,expected,"actual adapter "..row[1])
			local cid,p2=snapshot_cell(snapshot,minp,maxp,0,y,0)
			if outcome~=row[5] or cid~=row[6] or p2~=row[7] or
					after.modified_voxels-before.modified_voxels~=
						(outcome=="noop_equal_content" and 0 or 1) or
					after.liquid_dirty_columns-before.liquid_dirty_columns~=row[9] then
				fail("actual adapter isolated result differs: "..row[1])
			end
			if row[3]==15 then
				local seen=0
				for call=classify_before+1,classify_after do
					if classify_cids[call]==15 then
						seen=seen+1
						if classify_param2s[call]~=row[4] then
							fail("flowing liquid param2 observation differs")
						end
					end
				end
				if seen~=4 then fail("flowing liquid classification count differs") end
			end
			rows[#rows+1]=table.concat({row[1],outcome,
				integer_ascii(row[3],"isolated old cid"),
				integer_ascii(row[4],"isolated old param2"),
				integer_ascii(cid,"isolated final cid"),
				integer_ascii(p2,"isolated final param2"),call_signature(snapshot)},"\t").."\n"
		end
		rewrite_plan(plan,generation,{{column=(0-minp.z)*80+(0-minp.x)+1,
			y_min=y,y_max=y,opcode=OPCODE_ID.ORDINARY_WATER}})
		local vm,reject_observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,7,15,
			{{x=0,y=y,z=0,cid=16,param2=3}},false)
		expect_error("fail_replace_policy",function()
			loaded.adapter:apply(vm,minp,maxp,plan,generation,"offline_fixture")
		end,"incompatible flowing liquid")
		local reject_snapshot=reject_observer.snapshot()
		assert_exact_vm_calls(reject_snapshot,base_trace,"incompatible flowing liquid")
		local reject_cid,reject_p2=snapshot_cell(reject_snapshot,minp,maxp,0,y,0)
		if reject_cid~=16 or reject_p2~=3 then
			fail("incompatible flowing liquid changed state")
		end
		rows[#rows+1]="incompatible_flowing\tfail_replace_policy\n"
		return canonical_rows(raw_sha256,rows),#cases+1,#cases+1
	end

	local function actual_light_matrix(loaded,raw_sha256)
		local foundation_fill=OPCODE_ID.FOUNDATION_FILL
		local ordinary_water=OPCODE_ID.ORDINARY_WATER
		local cases={
			{"sky_open",AUTHORED_FLOOR,AUTHORED_FLOOR+2,AUTHORED_FLOOR+1,
				foundation_fill,0,15,31,"applied_cl"},
			{"sealed_cave",AUTHORED_FLOOR,AUTHORED_FLOOR+2,AUTHORED_FLOOR+1,
				foundation_fill,1,0,0,"applied_cl"},
			{"water",AUTHORED_FLOOR,AUTHORED_FLOOR+2,AUTHORED_FLOOR+1,
				ordinary_water,1,0,0,"applied_clq"},
			{"chunk_top",AUTHORED_FLOOR,AUTHORED_FLOOR+2,AUTHORED_FLOOR+2,
				foundation_fill,0,15,31,"applied_clq"},
			{"transparent_canopy",AUTHORED_FLOOR,AUTHORED_FLOOR+2,
				AUTHORED_FLOOR+1,foundation_fill,14,15,1,"applied_cl",13},
			{"opaque_canopy",AUTHORED_FLOOR,AUTHORED_FLOOR+2,AUTHORED_FLOOR+1,
				foundation_fill,14,15,0,"applied_cl"},
			{"ignore_above_water",0,2,2,foundation_fill,14,0,0,
				"applied_clq",65535,15},
			{"ignore_at_water",-16,-14,-14,foundation_fill,14,0,0,
				"applied_clq",65535,0},
		}
		local rows={}
		local plan,generation,plan_min_y,plan_max_y
		for index=1,#cases do
			local row=cases[index]
			local minp=owner_position(-32,row[2],-32)
			local maxp=owner_position(47,row[3],47)
			local target_y=row[4]
			local opcode=row[5]
			local box_min_x,box_max_x=-15,15
			local box_min_y=math.max(target_y-15,minp.y-16)
			local box_max_y=math.min(target_y+15,maxp.y+15)
			local box_min_z,box_max_z=-15,15
			local seed_y=box_max_y+1
			local propagate_shadow=box_max_y<=1
			local calc_max_y=box_max_y
			if not propagate_shadow and calc_max_y>maxp.y then
				calc_max_y=maxp.y
			end
			local blocked_probe_y=target_y
			local ignore_halo_regression=calc_max_y<box_max_y
			local overrides={{x=0,y=target_y,z=0,
				cid=opcode==ordinary_water and row[6] or 0,
				param2=opcode==ordinary_water and ROLE_ID.ORDINARY_WATER_SOURCE or
					ROLE_ID.FOUNDATION_CORE,light=0}}
			if row[10]==13 then
				overrides[#overrides+1]={x=0,y=seed_y,z=0,cid=13,param2=0,light=15}
			elseif row[10]==65535 then
				for yy=box_min_y,box_max_y do
					overrides[#overrides+1]={x=2,y=yy,z=0,cid=0,param2=0,light=0}
				end
				overrides[#overrides+1]={x=2,y=seed_y,z=0,
					cid=65535,param2=0,light=15}
				-- A second open column has a non-ignore, dark overtop inherited
				-- from the replaced v7 geometry. Above water it must not retain
				-- shadow authority; at the water-level boundary it still does.
				for yy=box_min_y,box_max_y do
					overrides[#overrides+1]={x=4,y=yy,z=0,cid=0,param2=0,light=0}
					overrides[#overrides+1]={x=6,y=yy,z=0,cid=0,param2=0,light=0}
				end
				overrides[#overrides+1]={x=4,y=calc_max_y+1,z=0,
					cid=14,param2=0,light=0}
				-- Discarding stale overtop shadow must not discard real opaque
				-- blockers that are part of the recalculated light box.
				blocked_probe_y=calc_max_y-2
				overrides[#overrides+1]={x=6,y=blocked_probe_y+1,z=0,
					cid=14,param2=0,light=0}
				if ignore_halo_regression then
					for yy=box_min_y,calc_max_y do
						overrides[#overrides+1]={x=8,y=yy,z=0,cid=0,param2=0,light=0}
					end
					for yy=calc_max_y+1,box_max_y do
						overrides[#overrides+1]={x=8,y=yy,z=0,
							cid=65535,param2=0,light=173}
					end
				end
			end
			if plan==nil or plan_min_y~=row[2] or plan_max_y~=row[3] then
				plan,generation=plan_at(loaded,minp,maxp)
				plan_min_y,plan_max_y=row[2],row[3]
			end
			rewrite_plan(plan,generation,{{column=(0-minp.z)*80+(0-minp.x)+1,
				y_min=target_y,y_max=target_y,opcode=opcode}})
			local vm,observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,
				row[6],opcode==ordinary_water and ROLE_ID.ORDINARY_WATER_SOURCE or
					ROLE_ID.FOUNDATION_CORE,row[7],overrides,false)
			local before=loaded.adapter:metrics()
			local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
				"offline_fixture")
			local after=loaded.adapter:metrics()
			local snapshot=observer.snapshot()
			local trace={"get_emerged_area","get_heightmap","get_data",
				"get_param2_data","get_light_data","set_data",
				"set_lighting:0,0,"..integer_ascii(box_min_x,"light box min x")..","..
				integer_ascii(box_min_y,"light box min y")..","..
				integer_ascii(box_min_z,"light box min z")..","..
				integer_ascii(box_max_x,"light box max x")..","..
				integer_ascii(box_max_y,"light box max y")..","..
				integer_ascii(box_max_z,"light box max z")}
			if row[8]==31 then
				for z=box_min_z,box_max_z do
					trace[#trace+1]="set_lighting:15,0,"..
						integer_ascii(box_min_x,"seed min x")..","..
						integer_ascii(seed_y,"seed y")..","..
						integer_ascii(z,"seed z")..","..
						integer_ascii(box_max_x,"seed max x")..","..
						integer_ascii(seed_y,"seed y")..","..
						integer_ascii(z,"seed z")
				end
			elseif row[8]==1 then
				trace[#trace+1]="set_lighting:15,0,0,"..
					integer_ascii(seed_y,"seed y")..",0,0,"..
					integer_ascii(seed_y,"seed y")..",0"
			end
			trace[#trace+1]="calc_lighting:"..integer_ascii(box_min_x,"calc min x")..","..
				integer_ascii(box_min_y,"calc min y")..","..
				integer_ascii(box_min_z,"calc min z")..","..
				integer_ascii(box_max_x,"calc max x")..","..
				integer_ascii(calc_max_y,"calc max y")..","..
				integer_ascii(box_max_z,"calc max z")..","..
				tostring(propagate_shadow)
			trace[#trace+1]="get_light_data"
			trace[#trace+1]="set_light_data"
			if row[9]:sub(-1)=="q" then trace[#trace+1]="update_liquids" end
			assert_exact_vm_calls(snapshot,trace,"light matrix "..row[1])
			local cid,_,target_light=snapshot_cell(snapshot,minp,maxp,0,target_y,0)
			local probe_light=target_light
			if row[10]==65535 then
				local probe_cid
				probe_cid,_,probe_light=snapshot_cell(snapshot,minp,maxp,2,target_y,0)
				if probe_cid~=0 or probe_light~=row[11] then
					fail("ignore-overtop light boundary differs")
				end
				local stale_cid,_,stale_light=snapshot_cell(snapshot,minp,maxp,
					4,target_y,0)
				local expected_stale_light=box_max_y>1 and 15 or 0
				if stale_cid~=0 or stale_light~=expected_stale_light then
					fail("stale v7 overtop sunlight authority differs")
				end
				local blocked_cid,_,blocked_light=snapshot_cell(snapshot,minp,maxp,
					6,blocked_probe_y,0)
				if blocked_cid~=0 or blocked_light==15 then
					fail("opaque in-box direct-sunlight blocker differs")
				end
				if ignore_halo_regression then
					local halo_owner_cid,_,halo_owner_light=snapshot_cell(snapshot,
						minp,maxp,8,target_y,0)
					local halo_cid,_,halo_light=snapshot_cell(snapshot,minp,maxp,
						8,calc_max_y+1,0)
					if halo_owner_cid~=0 or halo_owner_light~=15 or
							halo_cid~=65535 or halo_light~=173 then
						fail("surface calc cap or ignore-halo restoration differs")
					end
				end
			end
			if outcome~=row[9] or cid~=(opcode==ordinary_water and
					100+ROLE_ID.ORDINARY_WATER_SOURCE or 100+ROLE_ID.FOUNDATION_CORE) or
					target_light~=0 or
					after.light_seed_runs-before.light_seed_runs~=row[8] then
				fail("actual light matrix result differs: "..row[1])
			end
			rows[#rows+1]=table.concat({row[1],outcome,
				integer_ascii(row[8],"light seed runs"),
				integer_ascii(target_light,"target final light"),
				integer_ascii(probe_light,"probe final light"),call_signature(snapshot)},"\t").."\n"
		end
		return canonical_rows(raw_sha256,rows),#cases,#cases
	end

	local candidate_row
	local append_values
	local function planner_adapter_relation_kat(loaded,raw_sha256)
		local variants={}
		for opcode=1,#OPCODES do
			if EMITTED_OPCODE[opcode] then
				variants[#variants+1]={opcode=opcode,policy=OP_POLICY[opcode]}
				if OP_POLICY_ALT[opcode] then
					variants[#variants+1]={opcode=opcode,policy=OP_POLICY_ALT[opcode]}
				end
			end
		end
		local planner_rows={}
		for first=1,#variants,16 do
			local after=math.min(first+15,#variants)
			local candidates,permutation={},{}
			for index=first,after do
				local local_index=index-first+1
				append_values(candidates,candidate_row(variants[index].opcode,
					-100+index,-100+index,0,0,variants[index].policy))
				permutation[local_index]=local_index
			end
			local resolved,count=loaded.planner_candidate_fixture(candidates,
				after-first+1,permutation)
			if count~=after-first+1 then fail("every-opcode Planner relation count differs") end
			for run=1,count do
				local base=(run-1)*RUN_STRIDE
				local variant=variants[first+run-1]
				if resolved[base+4]~=variant.opcode or
						resolved[base+5]~=OP_ROLE[variant.opcode] or
						resolved[base+6]~=variant.policy then
					fail("every-opcode Planner relation differs")
				end
				planner_rows[#planner_rows+1]=table.concat({OPCODES[variant.opcode],
					integer_ascii(OP_PRIORITY[variant.opcode],"KAT opcode priority"),
					integer_ascii(OP_ROLE[variant.opcode],"KAT opcode role"),
					integer_ascii(variant.policy,"KAT opcode policy")},"\t").."\n"
			end
		end

		local minp=owner_position(-32,AUTHORED_FLOOR,-32)
		local maxp=owner_position(47,17,47)
		local y=AUTHORED_FLOOR+1
		local specs,overrides={},{}
		for index=1,#variants do
			local x=-28+((index-1)%7)*10
			local z=-24+math.floor((index-1)/7)*12
			local variant=variants[index]
			local role=OP_ROLE[variant.opcode]
			specs[#specs+1]={column=(z-minp.z)*80+(x-minp.x)+1,
				y_min=y,y_max=y,opcode=variant.opcode,policy=variant.policy}
			local old_cid=1
			if variant.policy==POLICY_ID.FILL_VOID then old_cid=0 end
			if variant.policy==POLICY_ID.SEAL_VOID then old_cid=3 end
			overrides[#overrides+1]={x=x,y=y,z=z,cid=old_cid,param2=role}
		end
		local dirty={
			{-20,2,ROLE_ID.FOUNDATION_SURFACE,OPCODE_ID.FOUNDATION_SURFACE},
			{-8,107,0,OPCODE_ID.FOUNDATION_FILL},
			{4,0,7,OPCODE_ID.FOUNDATION_FILL},
			{16,7,7,OPCODE_ID.FOUNDATION_FILL},
		}
		for index=1,#dirty do
			local row=dirty[index]
			specs[#specs+1]={column=(24-minp.z)*80+(row[1]-minp.x)+1,
				y_min=y,y_max=y,opcode=row[4]}
			overrides[#overrides+1]={x=row[1],y=y,z=24,cid=row[2],param2=row[3]}
		end
		-- One high light-dirty target fixes light_max.y=17 and seed_y=18.
		-- Three otherwise-open columns then distinguish an explicit transparent
		-- seed, a real opaque in-box blocker and the engine-owned ignore-overtop seed.
		local light_target_x,light_target_z=28,24
		specs[#specs+1]={column=(light_target_z-minp.z)*80+
			(light_target_x-minp.x)+1,y_min=2,y_max=2,
			opcode=OPCODE_ID.FOUNDATION_FILL}
		overrides[#overrides+1]={x=light_target_x,y=2,z=light_target_z,
			cid=0,param2=7,light=0}
		local light_seed_z=39
		local light_columns={{-28,13,15},{0,14,14},{28,65535,15}}
		for index=1,#light_columns do
			local row=light_columns[index]
			for light_y=AUTHORED_FLOOR-14,17 do
				overrides[#overrides+1]={x=row[1],y=light_y,z=light_seed_z,
					cid=0,param2=0,light=0}
			end
			overrides[#overrides+1]={x=row[1],y=18,z=light_seed_z,
				cid=row[2],param2=0,light=row[3]}
		end
		-- The surface pass ignores the inherited non-ignore overtop, but a node
		-- inside the recalculated box remains authoritative and blocks sunlight.
		overrides[#overrides+1]={x=0,y=17,z=light_seed_z,
			cid=14,param2=0,light=0}
		table.sort(specs,function(left,right) return left.column<right.column end)
		local outcome,snapshot,delta,plan,generation,vm,observer=
			apply_specs(loaded,minp,maxp,specs,1,0,15,overrides,true)
		if outcome~="applied_cplq" or
				delta.modified_voxels~=#variants+#dirty+1 or
				delta.content_dirty_columns~=#variants+4 or
				delta.param2_dirty_columns~=1 or
				snapshot.inactive_tail_checks~=18 or
				snapshot.inactive_tail_unchanged~=true then
			fail("every-opcode Adapter relation transaction differs")
		end
		for index=1,#variants do
			local x=-28+((index-1)%7)*10
			local z=-24+math.floor((index-1)/7)*12
			local cid,p2=snapshot_cell(snapshot,minp,maxp,x,y,z)
			local role=OP_ROLE[variants[index].opcode]
			if cid~=100+role or p2~=role then
				fail("every-opcode Adapter final state differs")
			end
		end
		for index=1,#dirty do
			local row=dirty[index]
			local cid,p2=snapshot_cell(snapshot,minp,maxp,row[1],y,24)
			local role=OP_ROLE[row[4]]
			if cid~=100+role or p2~=role then
				fail("relation dirty witness differs")
			end
		end
		local transparent_cid,_,transparent_light=snapshot_cell(snapshot,minp,maxp,
			-28,2,light_seed_z)
		local opaque_cid,_,opaque_light=snapshot_cell(snapshot,minp,maxp,
			0,2,light_seed_z)
		local ignore_cid,_,ignore_light=snapshot_cell(snapshot,minp,maxp,
			28,18,light_seed_z)
		local _,_,ignore_owner_light=snapshot_cell(snapshot,minp,maxp,
			28,2,light_seed_z)
		if transparent_cid~=0 or transparent_light~=15 or opaque_cid~=0 or
				opaque_light~=0 or ignore_cid~=65535 or ignore_light~=15 or
				ignore_owner_light~=15 or snapshot.calls.get_light_data~=2 or
				snapshot.calls.calc_lighting~=1 or snapshot.calls.set_light_data~=1 then
			fail("canopy/ignore-overtop lighting relation differs")
		end
		local second=loaded.adapter:apply(vm,minp,maxp,plan,generation,
			"offline_fixture")
		local second_snapshot=observer.snapshot()
		if second~="noop_equal_content" or
				second_snapshot.inactive_tail_checks~=26 or
				not exact_equal(snapshot.data,second_snapshot.data) or
				not exact_equal(snapshot.param2,second_snapshot.param2) then
			fail("every-opcode same-VM double apply differs")
		end
		planner_rows[#planner_rows+1]="adapter\t"..outcome.."\t"..
			integer_ascii(#variants,"accepted opcode-policy variants").."\t"..
			call_signature(second_snapshot).."\t18\t26\t"..
			"transparent_seed\topaque_nonseed\tignore_overtop_seed\n"
		if #variants~=27 then fail("every-opcode relation population differs") end
		return canonical_rows(raw_sha256,planner_rows),#variants,2,1
	end

	local FACE_OFFSETS={{-1,0,0},{1,0,0},{0,-1,0},{0,1,0},{0,0,-1},{0,0,1}}
	local function liquid_face_matrix(loaded,raw_sha256)
		local minp=owner_position(-32,AUTHORED_FLOOR,-32)
		local maxp=owner_position(47,AUTHORED_FLOOR+2,47)
		local y=AUTHORED_FLOOR+1
		local rows={}
		local positive_count=0
		local interior_plan,interior_generation=plan_at(loaded,minp,maxp)
		for face_index=1,6 do
			for positive_index=1,2 do
				local positive=positive_index==1
				rewrite_plan(interior_plan,interior_generation,
					{{column=(0-minp.z)*80+(0-minp.x)+1,
					y_min=y,y_max=y,opcode=OPCODE_ID.HYDROLOGY_BANK_SEAL}})
				local overrides={{x=0,y=y,z=0,cid=17,param2=9}}
				for preceding=1,(positive and face_index or 6) do
					local face=FACE_OFFSETS[preceding]
					overrides[#overrides+1]={x=face[1],y=y+face[2],z=face[3],
						cid=preceding==face_index and positive and 7 or 16,
						param2=preceding}
				end
				local vm,observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,
					1,9,0,overrides,false)
				local classify_before=loaded.fixture_content_observer()
				local outcome=loaded.adapter:apply(vm,minp,maxp,interior_plan,
					interior_generation,
					"offline_fixture")
				local classify_after=loaded.fixture_content_observer()
				local snapshot=observer.snapshot()
				local expected_trace={"get_emerged_area","get_heightmap","get_data",
					"get_param2_data","set_data"}
				if positive then expected_trace[#expected_trace+1]="update_liquids" end
				assert_exact_vm_calls(snapshot,expected_trace,
					"liquid face "..integer_ascii(face_index,"liquid face"))
				local expected_classify=positive and 2*(face_index-1) or 12
				if classify_after-classify_before~=expected_classify or
						outcome~=(positive and "applied_cq" or "applied_c") then
					fail("isolated liquid-face result/order differs")
				end
				if positive then positive_count=positive_count+1 end
				rows[#rows+1]=table.concat({"interior",
					integer_ascii(face_index,"liquid face ordinal"),
					positive and "positive" or "negative",outcome,
					integer_ascii(classify_after-classify_before,
						"liquid classify delta"),call_signature(snapshot)},"\t").."\n"
			end
		end
		if positive_count~=6 then fail("isolated liquid-face positive total differs") end
		local boundary={
			{16,y,minp.z,0,0,-1},
			{minp.x,y,-16,-1,0,0},{maxp.x,y,-8,1,0,0},
			{0,minp.y,0,0,-1,0},{8,maxp.y,8,0,1,0},
			{24,y,maxp.z,0,0,1},
		}
		local boundary_states={12,65535}
		local reference_central,reference_outcome
		local function boundary_central_digest(snapshot)
			local central_rows={}
			for index=1,#boundary do
				local row=boundary[index]
				local cid,p2=snapshot_cell(snapshot,minp,maxp,row[1],row[2],row[3])
				central_rows[#central_rows+1]=table.concat({
					integer_ascii(index,"boundary central ordinal"),
					integer_ascii(cid,"boundary central cid"),
					integer_ascii(p2,"boundary central param2")},"\t").."\n"
			end
			return canonical_rows(raw_sha256,central_rows)
		end
		for state_index=1,#boundary_states do
			local specs,overrides={},{}
			for index=1,#boundary do
				local row=boundary[index]
				specs[#specs+1]={column=(row[3]-minp.z)*80+(row[1]-minp.x)+1,
					y_min=row[2],y_max=row[2],
					opcode=OPCODE_ID.HYDROLOGY_BANK_SEAL}
				overrides[#overrides+1]={x=row[1],y=row[2],z=row[3],cid=17,param2=9}
				overrides[#overrides+1]={x=row[1]+row[4],y=row[2]+row[5],
					z=row[3]+row[6],cid=boundary_states[state_index],param2=index}
			end
			table.sort(specs,function(left,right)
				if left.column~=right.column then return left.column<right.column end
				return left.y_min<right.y_min
			end)
			local outcome,snapshot,delta=apply_specs(loaded,minp,maxp,specs,1,9,0,
				overrides,false)
			if outcome~="applied_cq" or delta.modified_voxels~=6 or
					delta.content_dirty_columns~=6 or delta.param2_dirty_columns~=0 or
					delta.light_dirty_columns~=0 or delta.liquid_dirty_columns~=6 or
					snapshot.calls.update_liquids~=1 or snapshot.calls.get_light_data~=0 then
				fail("owner-boundary liquid-face matrix differs")
			end
			local expected_override={}
			for index=1,#overrides do
				local row=overrides[index]
				expected_override[emerged_index(minp,maxp,row.x,row.y,row.z)]=row
			end
			local emin,emax=emerged_geometry(minp,maxp)
			for z=emin.z,emax.z do for yy=emin.y,emax.y do for x=emin.x,emax.x do
				if x<minp.x or x>maxp.x or yy<minp.y or yy>maxp.y or
						z<minp.z or z>maxp.z then
					local offset=emerged_index(minp,maxp,x,yy,z)
					local expected=expected_override[offset]
					local cid=expected and expected.cid or 1
					local p2=expected and expected.param2 or 9
					if snapshot.data[offset]~=cid or snapshot.param2[offset]~=p2 or
							snapshot.light[offset]~=0 then
						fail("owner-boundary halo changed")
					end
				end
			end end end
			local central=boundary_central_digest(snapshot)
			if reference_central and (central~=reference_central or
					outcome~=reference_outcome) then
				fail("owner-boundary state changed central outcome")
			end
			reference_central,reference_outcome=central,outcome
			rows[#rows+1]=table.concat({"boundary",
				integer_ascii(state_index,"boundary state ordinal"),outcome,central,
				integer_ascii(delta.liquid_dirty_columns,"boundary liquid dirty")},"\t").."\n"
		end
		return canonical_rows(raw_sha256,rows),rows,14,14
	end

	local function micro_ignore_matrix(offline,loaded,raw_sha256)
		local minp=owner_position(-32,AUTHORED_FLOOR,-32)
		local maxp=owner_position(47,AUTHORED_FLOOR+2,47)
		local y=AUTHORED_FLOOR+1
		local plan,generation=plan_at(loaded,minp,maxp)
		rewrite_plan(plan,generation,{{column=(0-minp.z)*80+(0-minp.x)+1,
			y_min=y,y_max=y,opcode=OPCODE_ID.FOUNDATION_FILL}})
		local required_vm=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,7,15,
			{{x=0,y=y,z=0,cid=0,param2=7},
				{x=1,y=y,z=0,cid=65535,param2=0}},false)
		expect_error("fail_content_ignore",function()
			loaded.adapter:apply(required_vm,minp,maxp,plan,generation,
				"offline_fixture")
		end,"required lighting context ignore")
		local halo_plan,halo_generation=plan_at(loaded,minp,maxp)
		rewrite_plan(halo_plan,halo_generation,
			{{column=(0-minp.z)*80+1,y_min=y,y_max=y,
				opcode=OPCODE_ID.FOUNDATION_FILL}})
		local emin,emax,ex,ey,_,volume=emerged_geometry(minp,maxp)
		local halo_data=dense_fill(volume,65535)
		local halo_param2=dense_fill(volume,11)
		local halo_light=dense_fill(volume,3)
		for z=minp.z,maxp.z do for yy=minp.y,maxp.y do for x=minp.x,maxp.x do
			local offset=emerged_index(minp,maxp,x,yy,z)
			halo_data[offset],halo_param2[offset],halo_light[offset]=1,7,15
		end end end
		halo_data[emerged_index(minp,maxp,minp.x,y,0)]=0
		local halo_spec={minp=minp,maxp=maxp,data=halo_data,param2=halo_param2,
			light=halo_light,content_contract=loaded.fixture_content,water_level=1,
			ignore_cid=65535,verify_inactive_tail=false}
		local halo_vm,halo_context,halo_observer
		if loaded.fixture_trace_token then
			halo_vm,halo_context,halo_observer=loaded.vm_module.new(halo_spec,
				loaded.fixture_trace_token)
			if not rawequal(halo_context,loaded.fixture_context) then
				fail("fresh-halo paired VM context identity differs")
			end
		else
			halo_spec.heightmap=dense_fill(6400,HEIGHTMAP_SENTINEL)
			halo_vm,halo_context,halo_observer=loaded.vm_module.new(halo_spec)
		end
		local halo_outcome=loaded.adapter:apply(halo_vm,minp,maxp,halo_plan,
			halo_generation,"offline_fixture")
		if not halo_outcome:match("^applied_") then
			fail("fresh read-only halo did not commit")
		end
		local halo_snapshot=halo_observer.snapshot()
		for z=emin.z,emax.z do for yy=emin.y,emax.y do for x=emin.x,emax.x do
			local offset=emerged_index(minp,maxp,x,yy,z)
			if x<minp.x or x>maxp.x or yy<minp.y or yy>maxp.y or
					z<minp.z or z>maxp.z then
				if halo_snapshot.data[offset]~=65535 or
						halo_snapshot.param2[offset]~=11 or
						halo_snapshot.light[offset]~=3 then
					fail("fresh read-only halo bytes changed")
				end
			elseif halo_snapshot.data[offset]==65535 then
				fail("fresh-halo owner retained CONTENT_IGNORE")
			end
		end end end
		plan,generation=plan_at(loaded,minp,maxp)
		rewrite_plan(plan,generation,{{column=(0-minp.z)*80+(0-minp.x)+1,
			y_min=y,y_max=y,opcode=OPCODE_ID.FOUNDATION_SURFACE}})
		local unneeded={x=minp.x-16,y=minp.y-16,z=minp.z-16,
			cid=65535,param2=0,light=3}
		local safe_vm,safe_observer=new_vm_fixture(loaded,minp,maxp,
			HEIGHTMAP_SENTINEL,1,7,15,
			{{x=0,y=y,z=0,cid=2,param2=8},unneeded},false)
		local safe_outcome=loaded.adapter:apply(safe_vm,minp,maxp,plan,generation,
			"offline_fixture")
		local safe_snapshot=safe_observer.snapshot()
		local cid,p2,light=snapshot_cell(safe_snapshot,minp,maxp,
			unneeded.x,unneeded.y,unneeded.z)
		if safe_outcome~="applied_c" or cid~=65535 or p2~=0 or light~=3 or
				safe_snapshot.calls.get_light_data~=0 then
			fail("unneeded halo ignore matrix differs")
		end
		local upper_min=owner_position(-32,OWNER_MAX,-32)
		local upper_max=owner_position(47,OWNER_MAX,47)
		local ignore_plan,ignore_generation=one_run_plan(loaded,upper_min,upper_max,
			-32,-32,OWNER_MAX,OPCODE_ID.BRIDGE_DECK)
		local ignore_vm,ignore_observer=new_vm_for_plan(loaded,upper_min,upper_max,
			HEIGHTMAP_SENTINEL,1,0,15)
		expect_error("fail_target",function()
			loaded.adapter:apply(ignore_vm,upper_min,upper_max,ignore_plan,
				ignore_generation,"offline_fixture")
		end,"conditional CONTENT_IGNORE target")
		local ignore_snapshot=ignore_observer.snapshot()
		if #ignore_snapshot.trace~=0 or ignore_snapshot.calls.get_emerged_area~=0 then
			fail("conditional CONTENT_IGNORE target touched VM")
		end
		local rows={"required_context\tfail_content_ignore\n",
			"required_halo\t"..halo_outcome.."\tunchanged\n",
			"unneeded_halo\t"..safe_outcome.."\tunchanged\n",
			"target\trole2_y30927\tfail_target\tempty_trace\n"}
		return canonical_rows(raw_sha256,rows),4,4
	end

	local function native_position_oracle(loaded,raw_sha256,include_veto)
		local function plan_run_at(plan,x,y,z)
			if x<plan.min_x or x>plan.max_x or y<plan.min_y or y>plan.max_y or
					z<plan.min_z or z>plan.max_z then
				fail("native production witness is outside its plan")
			end
			local column=(z-plan.min_z)*(plan.max_x-plan.min_x+1)+
				(x-plan.min_x)+1
			for run=plan.column_start[column],plan.column_start[column+1]-1 do
				local base=(run-1)*RUN_STRIDE
				if plan.run_values[base+1]<=y and plan.run_values[base+2]>=y then
					return plan.run_values[base+4],plan.run_values[base+5],
						plan.run_values[base+6]
				end
			end
			return nil
		end
		local min_x,min_z=-32,-32
		local definitions={
			{"cave_air",-24,-1,OPCODE_ID.TERRAIN_FILL,0,73,0},
			{"flooded_cave",-18,-1,OPCODE_ID.TERRAIN_FILL,7,91,7},
			{"sky_void_fill",-12,0,OPCODE_ID.TERRAIN_FILL,0,14,114,mode="sky"},
			{"mask_override",30,-1,OPCODE_ID.FOUNDATION_SURFACE,0,8,108},
			{"mask_foundation",-24,-1,OPCODE_ID.FOUNDATION_SURFACE,0,8,108,z=16},
			{"mask_path",-18,-1,OPCODE_ID.PATH_SURFACE,0,12,112,z=16},
			{"mask_interface",-12,-1,OPCODE_ID.BRIDGE_DECK,0,2,102,z=16},
			{"mask_tunnel",-6,-1,OPCODE_ID.TUNNEL_LUMEN,7,1,101,z=16},
			{"mask_seal",0,-1,OPCODE_ID.HYDROLOGY_BANK_SEAL,0,9,109,z=16},
			{"mask_water",6,-1,OPCODE_ID.ORDINARY_WATER,7,10,110,z=16},
		}
		local min_y,max_y=OWNER_MAX,OWNER_MIN
		for index=1,#definitions do
			local row=definitions[index]
			row.z=row.z or 0
			local tuple=capture20(loaded.planner_source.column_values_at,row[2],row.z)
			validate_column_tuple(tuple,"native position tuple")
			row.terrain=tuple[6]
			if row.mode=="sky" then row.height=row.terrain-1
			else row.height=row.terrain end
			if row.mode=="above" then
				local cap_datum=tuple[7]
				if cap_datum==nil then
					if tuple[16]~=nil then cap_datum=tuple[16] end
					if tuple[17]~=nil then
						cap_datum=cap_datum and math.max(cap_datum,tuple[17]) or tuple[17]
					end
				end
				row.cap=math.max(row.terrain,cap_datum or row.terrain)
				row.y=row.cap+1
			else row.y=row.terrain+row[3] end
			if row.y<AUTHORED_FLOOR then fail("native position crosses authored floor") end
			if row.y<min_y then min_y=row.y end
			if row.height<min_y then min_y=row.height end
			if row.y>max_y then max_y=row.y end
			if row.height>max_y then max_y=row.height end
		end
		if max_y-min_y+1>80 then fail("native position corpus exceeds one Y slice") end
		local minp=owner_position(min_x,min_y,min_z)
		local maxp=owner_position(min_x+79,max_y,min_z+79)
		for index=1,6400 do loaded.fixture_heightmap[index]=HEIGHTMAP_SENTINEL end
		local specs,overrides,controls={},{},{}
		for index=1,#definitions do
			local row=definitions[index]
			local column=(row.z-min_z)*80+(row[2]-min_x)+1
			loaded.fixture_heightmap[column]=row.height
			specs[#specs+1]={column=column,y_min=row.y,y_max=row.y,opcode=row[4]}
			overrides[#overrides+1]={x=row[2],y=row.y,z=row.z,cid=row[5],param2=row[6]}
			if row[1]:match("^mask_") and row[1]~="mask_override" then
				local control={name=row[1].."_outside",x=row[2]+1,y=row.y,z=row.z,
					cid=index%2==0 and 0 or 7,param2=32+index}
				controls[#controls+1]=control
				overrides[#overrides+1]=control
				local control_column=(control.z-min_z)*80+(control.x-min_x)+1
				loaded.fixture_heightmap[control_column]=row.height
				specs[#specs+1]={column=control_column,y_min=control.y,
					y_max=control.y,opcode=OPCODE_ID.TERRAIN_FILL}
			end
		end
		table.sort(specs,function(left,right)
			if left.column~=right.column then return left.column<right.column end
			return left.y_min<right.y_min
		end)
		local outcome,snapshot,_,packed_plan=apply_specs(loaded,minp,maxp,specs,1,0,15,
			overrides,false)
		if not outcome:match("^applied_") then fail("native position corpus did not commit") end
		local packed_plan_digest=digest_hex(raw_sha256,plan_bytes(packed_plan))
		local rows={}
		for index=1,#definitions do
			local row=definitions[index]
			local cid,p2=snapshot_cell(snapshot,minp,maxp,row[2],row.y,row.z)
			local expected_p2=row[6]
			if cid~=row[7] or p2~=expected_p2 then
				fail("native position expectation differs: "..row[1])
			end
			rows[#rows+1]=table.concat({row[1],
				integer_ascii(row[2],"native position x"),
				integer_ascii(row.z,"native position z"),
				integer_ascii(row.y,"native position y"),
				integer_ascii(row.height,"native height"),
				integer_ascii(cid,"native final cid"),
				integer_ascii(p2,"native final param2"),packed_plan_digest},"\t").."\n"
		end
		for index=1,#controls do
			local row=controls[index]
			local cid,p2=snapshot_cell(snapshot,minp,maxp,row.x,row.y,row.z)
			if cid~=row.cid or p2~=row.param2 then
				fail("native mask outside-volume control changed: "..row.name)
			end
			rows[#rows+1]=table.concat({row.name,integer_ascii(row.x,"control x"),
				integer_ascii(row.y,"control y"),integer_ascii(row.z,"control z"),
				integer_ascii(cid,"control cid"),integer_ascii(p2,"control param2"),
				packed_plan_digest},
				"\t").."\n"
		end
		if include_veto==true then
			for _,veto in ipairs({{"foreign",9},{"unknown",10}}) do
				local plan,generation=plan_at(loaded,minp,maxp)
				rewrite_plan(plan,generation,{{column=(24-min_z)*80+(30-min_x)+1,
					y_min=min_y,y_max=min_y,opcode=OPCODE_ID.TERRAIN_SURFACE}})
				local vm=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,14,15,
					{{x=30,y=min_y,z=24,cid=veto[2],param2=14}},false)
				expect_error("fail_replace_policy",function()
					loaded.adapter:apply(vm,minp,maxp,plan,generation,"offline_fixture")
				end,"native position veto "..veto[1])
				rows[#rows+1]="veto\t"..veto[1].."\tfail_replace_policy\n"
			end
		end
		local native_names={"ore","resource","stratum"}
		local ordinary_groups={}
		for z=-32,47 do for x=-32,47 do
			local tuple=capture20(loaded.planner_source.column_values_at,x,z)
			if tuple[7]==nil and tuple[10]==nil and tuple[14]==nil and
					tuple[20]==false and tuple[6]>AUTHORED_FLOOR and tuple[6]<OWNER_MAX and
					owner_chunk_min(tuple[6])==owner_chunk_min(tuple[6]+1) then
				local group_y=owner_chunk_min(tuple[6])
				local group=ordinary_groups[group_y]
				if not group then group={} ordinary_groups[group_y]=group end
				group[#group+1]={x=x,z=z,terrain=tuple[6]}
			end
		end end
		local ordinary_y,ordinary_points
		for group_y,points in pairs(ordinary_groups) do
			if #points>=9 and (ordinary_y==nil or group_y<ordinary_y) then
				ordinary_y,ordinary_points=group_y,points
			end
		end
		if not ordinary_points then fail("ordinary 3x4 production corpus is absent") end
		local ordinary_minp=owner_position(-32,ordinary_y,-32)
		local ordinary_maxp=owner_position(47,ordinary_y+79,47)
		local ordinary_plan,ordinary_generation=plan_at(loaded,
			ordinary_minp,ordinary_maxp)
		local ordinary_overrides,ordinary_expected={},{ }
		local category_names={"below","at_top","above_cap"}
		local category_opcodes={27,28,26}
		local selected_by_category={{},{},{}}
		local selected_points={}
		for category=1,3 do
			for point_index=1,#ordinary_points do
				local point=ordinary_points[point_index]
				local key=integer_ascii(point.x,"ordinary point x")..":"..
					integer_ascii(point.z,"ordinary point z")
				local y=category==1 and point.terrain-1 or
					(category==2 and point.terrain or point.terrain+1)
				if not selected_points[key] and
						plan_run_at(ordinary_plan,point.x,y,point.z)==
							category_opcodes[category] then
					selected_points[key]=true
					selected_by_category[category][#selected_by_category[category]+1]=point
					if #selected_by_category[category]==3 then break end
				end
			end
			if #selected_by_category[category]~=3 then
				fail("ordinary 3x4 production positions are incomplete")
			end
		end
		for category=1,3 do
			for class_index=1,3 do
				local point=selected_by_category[category][class_index]
				local y=category==1 and point.terrain-1 or
					(category==2 and point.terrain or point.terrain+1)
				local opcode=plan_run_at(ordinary_plan,point.x,y,point.z)
				if opcode~=category_opcodes[category] then
					fail("ordinary 3x4 production plan differs")
				end
				local old_cid=class_index+3
				local old_p2=category==3 and 1 or 14
				ordinary_overrides[#ordinary_overrides+1]={x=point.x,y=y,z=point.z,
					cid=old_cid,param2=old_p2}
				ordinary_expected[#ordinary_expected+1]={name=native_names[class_index],
					category=category_names[category],x=point.x,y=y,z=point.z,
					terrain=point.terrain,cid=category==1 and old_cid or
						(category==2 and 114 or 101),param2=category==1 and old_p2 or
						(category==2 and 14 or 1)}
			end
		end
		for index=1,6400 do loaded.fixture_heightmap[index]=HEIGHTMAP_SENTINEL end
		local ordinary_vm,ordinary_observer=new_vm_fixture(loaded,ordinary_minp,
			ordinary_maxp,HEIGHTMAP_SENTINEL,1,14,15,ordinary_overrides,false)
		local ordinary_outcome=loaded.adapter:apply(ordinary_vm,ordinary_minp,
			ordinary_maxp,ordinary_plan,ordinary_generation,"offline_fixture")
		local ordinary_snapshot=ordinary_observer.snapshot()
		if not ordinary_outcome:match("^applied_") then
			fail("ordinary 3x4 production apply did not commit")
		end
		for index=1,#ordinary_expected do
			local row=ordinary_expected[index]
			local cid,p2=snapshot_cell(ordinary_snapshot,ordinary_minp,ordinary_maxp,
				row.x,row.y,row.z)
			if cid~=row.cid or p2~=row.param2 then
				fail("ordinary 3x4 materialization differs")
			end
			rows[#rows+1]=table.concat({row.name.."_"..row.category,
				integer_ascii(row.x,"ordinary native x"),
				integer_ascii(row.y,"ordinary native y"),
				integer_ascii(row.z,"ordinary native z"),
				integer_ascii(row.terrain,"ordinary native terrain"),
				integer_ascii(cid,"ordinary native final cid"),
				integer_ascii(p2,"ordinary native final param2"),
				digest_hex(raw_sha256,plan_bytes(ordinary_plan))},"\t").."\n"
		end
		local water_groups={}
		for hydro_index=1,#loaded.source.hydrology do
			local centreline=loaded.source.hydrology[hydro_index].centreline
			for point_index=1,#centreline do
				local point=centreline[point_index]
				for dz=-2,2 do for dx=-2,2 do
					local x,z=point.x+dx,point.z+dz
					local tuple=capture20(loaded.planner_source.column_values_at,x,z)
					if tuple[7]~=nil and tuple[7]>tuple[6] then
						local min_water_y=owner_chunk_min(tuple[7])
						local key=integer_ascii(owner_chunk_min(x),"water owner x")..":"..
							integer_ascii(min_water_y,"water owner y")..":"..
							integer_ascii(owner_chunk_min(z),"water owner z")
						local group=water_groups[key]
						if not group then
							group={minp=owner_position(owner_chunk_min(x),min_water_y,
								owner_chunk_min(z)),points={},seen={}}
							water_groups[key]=group
						end
						local point_key=integer_ascii(x,"water x")..":"..
							integer_ascii(z,"water z")
						if not group.seen[point_key] then
							group.seen[point_key]=true
							group.points[#group.points+1]={x=x,z=z,y=tuple[7],
								terrain=tuple[6]}
						end
					end
				end end
			end
		end
		local water_group
		for _,group in pairs(water_groups) do
			if #group.points>=3 and (not water_group or
					group.minp.x<water_group.minp.x or
					(group.minp.x==water_group.minp.x and group.minp.z<water_group.minp.z) or
					(group.minp.x==water_group.minp.x and group.minp.z==water_group.minp.z and
						group.minp.y<water_group.minp.y)) then
				water_group=group
			end
		end
		if not water_group then
			fail("three-position authored-water production witness is absent")
		end
		table.sort(water_group.points,function(left,right)
			if left.z~=right.z then return left.z<right.z end
			return left.x<right.x
		end)
		for index=1,6400 do loaded.fixture_heightmap[index]=HEIGHTMAP_SENTINEL end
		local water_minp=water_group.minp
		local water_maxp=owner_position(water_minp.x+79,water_minp.y+79,
			water_minp.z+79)
		local water_plan,water_generation=plan_at(loaded,water_minp,water_maxp)
		local selected_water={}
		for point_index=1,#water_group.points do
			local point=water_group.points[point_index]
			local opcode,role,policy=plan_run_at(water_plan,point.x,point.y,point.z)
			if opcode==OPCODE_ID.RIVER_WATER and
					role==ROLE_ID.RIVER_WATER_SOURCE and
					policy==POLICY_ID.WRITE_WATER and point.y>point.terrain then
				selected_water[#selected_water+1]=point
				if #selected_water==3 then break end
			end
		end
		if #selected_water~=3 then
			fail("three authored-water production positions are incomplete")
		end
		local water_overrides={}
		for index=1,3 do
			local point=selected_water[index]
			local opcode,role,policy=plan_run_at(water_plan,point.x,point.y,point.z)
			if opcode~=OPCODE_ID.RIVER_WATER or
					role~=ROLE_ID.RIVER_WATER_SOURCE or
					policy~=POLICY_ID.WRITE_WATER or point.y<=point.terrain then
				fail("authored-water production plan differs")
			end
			water_overrides[index]={x=point.x,y=point.y,z=point.z,cid=index+3,
				param2=13}
		end
		local water_vm,water_observer=new_vm_fixture(loaded,water_minp,water_maxp,
			HEIGHTMAP_SENTINEL,1,13,15,water_overrides,false)
		local water_outcome=loaded.adapter:apply(water_vm,water_minp,water_maxp,
			water_plan,water_generation,"offline_fixture")
		local water_snapshot=water_observer.snapshot()
		if not water_outcome:match("^applied_") then
			fail("authored-water production apply did not commit")
		end
		for index=1,3 do
			local point=selected_water[index]
			local water_cid,water_p2=snapshot_cell(water_snapshot,water_minp,
				water_maxp,point.x,point.y,point.z)
			if water_cid~=113 or water_p2~=13 then
				fail("authored-water position expectation differs")
			end
			rows[#rows+1]=table.concat({native_names[index].."_in_water",
				integer_ascii(point.x,"authored water x"),
				integer_ascii(point.y,"authored water y"),
				integer_ascii(point.z,"authored water z"),
				integer_ascii(point.terrain,"authored water terrain"),
				integer_ascii(water_cid,"authored water cid"),
				digest_hex(raw_sha256,plan_bytes(water_plan))},"\t").."\n"
		end

		local transition_point,transition_tuple
		for interface_index=1,#loaded.source.hydrology_interfaces do
			local interface=loaded.source.hydrology_interfaces[interface_index]
			if interface.kind=="rapid" or interface.kind=="waterfall" then
				for dz=-2,2 do for dx=-2,2 do
					local x,z=interface.position.x+dx,interface.position.z+dz
					local tuple=capture20(loaded.planner_source.column_values_at,x,z)
					if tuple[7]==nil and (tuple[16]~=nil or tuple[17]~=nil) then
						transition_point={x=x,z=z}
						transition_tuple=tuple
						break
					end
				end if transition_point then break end end
			end
			if transition_point then break end
		end
		if not transition_point then fail("transition surface-cap witness is absent") end
		local transition_c=transition_tuple[16]
		if transition_tuple[17]~=nil then
			transition_c=transition_c and math.max(transition_c,transition_tuple[17]) or
				transition_tuple[17]
		end
		if transition_c==nil then fail("transition surface cap lacks C") end
		local transition_cap=math.max(transition_tuple[6],transition_c)
		local transition_y=transition_cap+1
		local transition_minp=owner_position(owner_chunk_min(transition_point.x),
			owner_chunk_min(transition_y),owner_chunk_min(transition_point.z))
		local transition_maxp=owner_position(transition_minp.x+79,
			transition_minp.y+79,transition_minp.z+79)
		local transition_plan,transition_generation=plan_at(loaded,
			transition_minp,transition_maxp)
		local transition_opcode,transition_role,transition_policy=plan_run_at(
			transition_plan,transition_point.x,transition_y,transition_point.z)
		if transition_role~=ROLE_ID.AIR or
				(transition_policy~=POLICY_ID.CUT_NATURAL and
					transition_policy~=POLICY_ID.OPEN_ENGINEERED) or
				transition_opcode==nil then
			fail("transition surface-cap production clear differs")
		end
		local transition_vm,transition_observer=new_vm_fixture(loaded,
			transition_minp,transition_maxp,HEIGHTMAP_SENTINEL,1,1,15,
			{{x=transition_point.x,y=transition_y,z=transition_point.z,
				cid=6,param2=1}},false)
		local transition_outcome=loaded.adapter:apply(transition_vm,transition_minp,
			transition_maxp,transition_plan,transition_generation,"offline_fixture")
		local transition_snapshot=transition_observer.snapshot()
		local transition_cid,transition_p2=snapshot_cell(transition_snapshot,
			transition_minp,transition_maxp,transition_point.x,transition_y,
			transition_point.z)
		if not transition_outcome:match("^applied_") or transition_cid~=101 or
				transition_p2~=1 then
			fail("transition surface-cap materialization differs")
		end
		rows[#rows+1]=table.concat({"transition_above_cap",
			integer_ascii(transition_point.x,"transition cap x"),
			integer_ascii(transition_point.z,"transition cap z"),
			integer_ascii(transition_tuple[6],"transition terrain"),
			canonical_scalar(transition_tuple[16]),canonical_scalar(transition_tuple[17]),
			integer_ascii(transition_cap,"transition cap"),
			integer_ascii(transition_y,"transition cap clear y"),
			integer_ascii(transition_cid,"transition cap final cid"),
			digest_hex(raw_sha256,plan_bytes(transition_plan))},"\t").."\n"
		local production_plan=plan_at(loaded,minp,maxp)
		for run=1,production_plan.run_count do
			if production_plan.run_values[(run-1)*RUN_STRIDE+1]<AUTHORED_FLOOR then
				fail("production operation crosses authored floor")
			end
		end
		rows[#rows+1]="floor\t"..integer_ascii(AUTHORED_FLOOR,"authored floor")..
			"\tproduction_closed\n"
		return canonical_rows(raw_sha256,rows),rows
	end

	local function representative_apply(loaded, raw_sha256, double_apply, old_cid,
			verify_inactive_tail)
		local x_min, z_min = -32, -32
		local tuple = capture20(loaded.planner_source.column_values_at, 0, 0)
		validate_column_tuple(tuple, "representative tuple")
		local y = math.max(AUTHORED_FLOOR, tuple[6])
		local minp, maxp = owner_position(x_min,y,z_min),
			owner_position(x_min+79,y,z_min+79)
		local plan, generation, plan_validation = plan_at(loaded,minp,maxp)
		if plan.run_count == 0 then
			y = math.max(AUTHORED_FLOOR, tuple[6]+1)
			minp.y, maxp.y = y, y
			plan, generation, plan_validation = plan_at(loaded,minp,maxp)
		end
		if plan.run_count == 0 then fail("representative nonempty plan absent") end
		local before_bytes = plan_validation.bytes
		local vm, observer = new_vm_for_plan(loaded,minp,maxp,HEIGHTMAP_SENTINEL,
			old_cid or 0,0,0,verify_inactive_tail)
		local first = loaded.adapter:apply(vm,minp,maxp,plan,generation,
			"offline_fixture")
		if type(first) ~= "string" or not first:match("^applied_") then
			fail("representative adapter apply did not commit")
		end
		local first_snapshot = observer.snapshot()
		local second, second_snapshot
		if double_apply ~= false then
			second = loaded.adapter:apply(vm,minp,maxp,plan,generation,
				"offline_fixture")
			if second ~= "noop_equal_content" then fail("same-VM double apply differs") end
			second_snapshot = observer.snapshot()
			if not exact_equal(first_snapshot.data,second_snapshot.data) or
					not exact_equal(first_snapshot.param2,second_snapshot.param2) then
				fail("double apply changed central content/param2")
			end
		else
			second, second_snapshot = "not_run", first_snapshot
		end
		local trace_rows = {}
		for index = 1, #second_snapshot.trace do
			trace_rows[#trace_rows+1] = integer_ascii(index,"trace ordinal") ..
				"\t" .. second_snapshot.trace[index] .. "\n"
		end
		local expected_active=112*(maxp.y-minp.y+33)*112
		local expected_first_checks=verify_inactive_tail and 18 or 0
		local expected_second_checks=verify_inactive_tail and
			(double_apply~=false and 26 or 18) or 0
		if first_snapshot.active_volume~=expected_active or
				first_snapshot.retained_capacity~=112*112*112 or
				first_snapshot.active_volume>=first_snapshot.retained_capacity or
				first_snapshot.inactive_tail_checks~=expected_first_checks or
				first_snapshot.inactive_tail_unchanged~=true or
				second_snapshot.active_volume~=first_snapshot.active_volume or
				second_snapshot.retained_capacity~=first_snapshot.retained_capacity or
				second_snapshot.inactive_tail_checks~=expected_second_checks or
				second_snapshot.inactive_tail_unchanged~=true then
			fail("VM active prefix/inactive retained tail evidence differs")
		end
		trace_rows[#trace_rows+1]=table.concat({"tail",
			integer_ascii(second_snapshot.active_volume,"active volume"),
			integer_ascii(second_snapshot.retained_capacity,"retained capacity"),
			integer_ascii(second_snapshot.inactive_tail_checks,"inactive tail checks"),
			second_snapshot.inactive_tail_unchanged and "true" or "false"},"\t").."\n"
		return {
			plan_sha256=digest_hex(raw_sha256,before_bytes), first=first, second=second,
			trace_sha256=canonical_rows(raw_sha256,trace_rows), observer=observer,
			active_prefix_exact=true,
			inactive_retained_tail_untouched=
				verify_inactive_tail==true and
				second_snapshot.inactive_tail_unchanged,
		}
	end

	local function seed_oracle_authority(source)
		local authority={profiles={},hydrology={},interfaces={},route_interfaces={},
			causeway_interfaces={}}
		for index=1,dense_count(source.hydrology_profiles,
				"seed oracle hydrology profiles") do
			local row=source.hydrology_profiles[index]
			if type(row)~="table" or type(row.id)~="string" or
				authority.profiles[row.id] then fail("seed oracle profile relation differs") end
			if safe_integer(row.depth,"seed oracle profile depth",0)<0 or
					row.bed_seal_layers~=3 or row.bank_seal_nodes~=2 then
				fail("seed oracle profile seal relation differs")
			end
			authority.profiles[row.id]=row
		end
		for index=1,dense_count(source.hydrology,"seed oracle hydrology") do
			local row=source.hydrology[index]
			local profile=type(row)=="table" and authority.profiles[row.profile_id]
			if type(row)~="table" or type(row.id)~="string" or
				authority.hydrology[row.id] or not profile then
				fail("seed oracle hydrology relation differs")
			end
			authority.hydrology[row.id]={id=row.id,depth=profile.depth,row=row}
		end
		for index=1,dense_count(source.hydrology_interfaces,
				"seed oracle interfaces") do
			local row=source.hydrology_interfaces[index]
			if type(row)~="table" or type(row.id)~="string" or
				authority.interfaces[row.id] then fail("seed oracle interface differs") end
			local members={}
			if row.kind=="bridge" or row.kind=="ford" or row.kind=="causeway" then
				if not authority.hydrology[row.hydrology_id] or
					type(row.route_interface_id)~="string" or
					authority.route_interfaces[row.route_interface_id] then
					fail("seed oracle route interface differs")
				end
				members[row.hydrology_id]=true
				authority.route_interfaces[row.route_interface_id]=row
				if row.kind=="causeway" then
					authority.causeway_interfaces[#authority.causeway_interfaces+1]=
						row.route_interface_id
				end
			elseif row.kind=="rapid" or row.kind=="waterfall" then
				if not authority.hydrology[row.upper_id] or
					not authority.hydrology[row.lower_id] or row.upper_id==row.lower_id then
					fail("seed oracle transition relation differs")
				end
				members[row.upper_id],members[row.lower_id]=true,true
			elseif row.kind=="confluence" then
				if type(row.from_ids)~="table" or
					type(row.outgoing_reach_id)~="string" then
					fail("seed oracle confluence relation differs")
				end
				for member_index=1,dense_count(row.from_ids,
						"seed oracle confluence members") do
					local id=row.from_ids[member_index]
					if not authority.hydrology[id] then
						fail("seed oracle confluence member differs")
					end
					members[id]=true
				end
				if not authority.hydrology[row.outgoing_reach_id] then
					fail("seed oracle confluence outgoing differs")
				end
				members[row.outgoing_reach_id]=true
			else fail("seed oracle interface kind differs") end
			authority.interfaces[row.id]={row=row,members=members}
		end
		table.sort(authority.causeway_interfaces)
		if #authority.causeway_interfaces==0 then
			fail("seed oracle causeway interface roster is empty")
		end
		local refs=expected_stable_refs(source)
		authority.stable_ordinal={}
		for index=1,#refs do authority.stable_ordinal[refs[index]]=index end
		return authority
	end

	local function new_seed_candidate_state()
		return {count=0,y_min={},y_max={},priority={},opcode={},role={},policy={},
			feature={},interface={},endpoints={},resolved_count=0,
			r_y_min={},r_y_max={},r_priority={},r_opcode={},r_role={},r_policy={},
			r_feature={},r_interface={},roofed_bridge_headroom=false,
			causeway=false,causeway_interface=false,causeway_culvert_eligible=false,
			equal_surface_bank=false,equal_surface_bank_samples=0,
			equal_surface_bank_surface=0,equal_surface_bank_seal_low=0,
			equal_surface_bank_seal_high=0,equal_surface_bank_feature=false,
			equal_surface_bank_terrain=0,equal_surface_bank_main_samples=0,
			equal_surface_bank_ford_samples=0}
	end

	local function seed_add_candidate(state,y_min,y_max,priority,opcode,role,
			policy,feature,interface)
		if y_min>y_max then return end
		if y_min<AUTHORED_FLOOR or y_max>OWNER_MAX or
				OP_PRIORITY[opcode]~=priority or OP_ROLE[opcode]~=role or
				not opcode_policy_valid(opcode,policy) then
			fail("seed oracle candidate relation differs")
		end
		state.count=state.count+1
		if state.count>16 then fail("seed oracle candidate bound exceeded") end
		local index=state.count
		state.y_min[index],state.y_max[index]=y_min,y_max
		state.priority[index],state.opcode[index]=priority,opcode
		state.role[index],state.policy[index]=role,policy
		state.feature[index],state.interface[index]=feature,interface
	end

	local function seed_add_operation(state,y_min,y_max,opcode,feature,interface,
			policy)
		seed_add_candidate(state,y_min,y_max,OP_PRIORITY[opcode],opcode,
			OP_ROLE[opcode],policy or OP_POLICY[opcode],feature,interface)
	end

	local function seed_candidate_equal(state,left,right)
		return state.opcode[left]==state.opcode[right] and
			state.role[left]==state.role[right] and
			state.policy[left]==state.policy[right] and
			state.feature[left]==state.feature[right] and
			state.interface[left]==state.interface[right]
	end

	local function seed_resolve_candidates(state)
		local endpoint_count=state.count*2
		for index=1,state.count do
			state.endpoints[index*2-1]=state.y_min[index]
			state.endpoints[index*2]=state.y_max[index]+1
		end
		for index=2,endpoint_count do
			local value,cursor=state.endpoints[index],index-1
			while cursor>=1 and state.endpoints[cursor]>value do
				state.endpoints[cursor+1]=state.endpoints[cursor]
				cursor=cursor-1
			end
			state.endpoints[cursor+1]=value
		end
		local unique=0
		for index=1,endpoint_count do
			if unique==0 or state.endpoints[index]~=state.endpoints[unique] then
				unique=unique+1
				state.endpoints[unique]=state.endpoints[index]
			end
		end
		state.resolved_count=0
		for endpoint_index=1,unique-1 do
			local y_min=state.endpoints[endpoint_index]
			local y_max=state.endpoints[endpoint_index+1]-1
			local first2,first3,first4,first5,first6
			local winner,winner_priority
			for candidate=1,state.count do
				if state.y_min[candidate]<=y_min and state.y_max[candidate]>=y_max then
					local priority=state.priority[candidate]
					local first
					if priority==2 then first,first2=first2,first2 or candidate
					elseif priority==3 then first,first3=first3,first3 or candidate
					elseif priority==4 then first,first4=first4,first4 or candidate
					elseif priority==5 then first,first5=first5,first5 or candidate
					elseif priority==6 then first,first6=first6,first6 or candidate
					else fail("seed oracle priority differs") end
					if first and not seed_candidate_equal(state,first,candidate) then
						fail("seed oracle same-priority conflict")
					end
					if not winner_priority or priority<winner_priority then
						winner,winner_priority=candidate,priority
					end
				end
			end
			if winner then
				local previous=state.resolved_count
				if previous>0 and state.r_y_max[previous]+1==y_min and
					state.r_priority[previous]==state.priority[winner] and
					state.r_opcode[previous]==state.opcode[winner] and
					state.r_role[previous]==state.role[winner] and
					state.r_policy[previous]==state.policy[winner] and
					state.r_feature[previous]==state.feature[winner] and
					state.r_interface[previous]==state.interface[winner] then
					state.r_y_max[previous]=y_max
				else
					state.resolved_count=previous+1
					if state.resolved_count>31 then
						fail("seed oracle resolved bound exceeded")
					end
					local out=state.resolved_count
					state.r_y_min[out],state.r_y_max[out]=y_min,y_max
					state.r_priority[out]=state.priority[winner]
					state.r_opcode[out],state.r_role[out]=state.opcode[winner],state.role[winner]
					state.r_policy[out]=state.policy[winner]
					state.r_feature[out],state.r_interface[out]=
						state.feature[winner],state.interface[winner]
				end
			end
		end
		return state.resolved_count
	end

	local function seed_interval_peak(state,resolved)
		local count=resolved and state.resolved_count or state.count
		local y_min=resolved and state.r_y_min or state.y_min
		local y_max=resolved and state.r_y_max or state.y_max
		local event_y,event_delta=state.peak_event_y or {},state.peak_event_delta or {}
		state.peak_event_y,state.peak_event_delta=event_y,event_delta
		local event_count=0
		for index=1,count do
			event_count=event_count+1
			event_y[event_count],event_delta[event_count]=owner_chunk_min(y_min[index]),1
			event_count=event_count+1
			event_y[event_count],event_delta[event_count]=
				owner_chunk_min(y_max[index])+80,-1
		end
		for index=2,event_count do
			local value,delta,cursor=event_y[index],event_delta[index],index-1
			while cursor>=1 and event_y[cursor]>value do
				event_y[cursor+1],event_delta[cursor+1]=
					event_y[cursor],event_delta[cursor]
				cursor=cursor-1
			end
			event_y[cursor+1],event_delta[cursor+1]=value,delta
		end
		local current,peak,peak_y,index=0,0,nil,1
		while index<=event_count do
			local value,delta=event_y[index],0
			while index<=event_count and event_y[index]==value do
				delta=delta+event_delta[index]
				index=index+1
			end
			current=current+delta
			if current>peak then peak,peak_y=current,value end
		end
		return peak,peak_y
	end

	local function seed_transition_relation(authority,id,kind)
		local relation=authority.interfaces[id]
		if not relation or relation.row.kind~=kind or
			not authority.hydrology[relation.row.upper_id] or
			not authority.hydrology[relation.row.lower_id] then
			fail("seed oracle transition lookup differs")
		end
		return relation
	end

	local function seed_route_relation(authority,id,kind,classified_id,required)
		if id==nil then
			if required then fail("seed oracle route interface is missing") end
			return nil
		end
		local row=authority.route_interfaces[id]
		if not row or row.kind~=kind or row.hydrology_id~=classified_id then
			fail("seed oracle route relation differs")
		end
		return row
	end

	local function seed_named_wet(authority,get,x,z)
		local water_y,hydro_id,depth=get(7,x,z),get(8,x,z),get(9,x,z)
		local transition_kind,transition_id=get(14,x,z),get(15,x,z)
		local transition_lower,face=get(17,x,z),get(19,x,z)
		if transition_kind=="waterfall" and face~=nil then
			local relation=seed_transition_relation(authority,transition_id,"waterfall")
			local hydro=authority.hydrology[relation.row.lower_id]
			if hydro.depth<=0 then fail("seed oracle contact lower profile is dry") end
			return hydro.id,transition_lower,transition_lower-hydro.depth,relation
		end
		if water_y~=nil and hydro_id~=nil and transition_kind~="waterfall" then
			local hydro=authority.hydrology[hydro_id]
			if not hydro or hydro.depth~=depth or depth<=0 then
				fail("seed oracle named wet relation differs")
			end
			local relation
			if transition_kind=="rapid" then
				relation=seed_transition_relation(authority,transition_id,"rapid")
			end
			return hydro_id,water_y,water_y-depth,relation
		end
		return nil,nil,nil,nil
	end

	local function seed_p3_solid(opcode)
		return opcode==OPCODE_ID.BRIDGE_DECK or opcode==OPCODE_ID.BRIDGE_SUPPORT or
			opcode==OPCODE_ID.CAUSEWAY_FILL or opcode==OPCODE_ID.CAUSEWAY_SURFACE or
			opcode==OPCODE_ID.FORD_BED or opcode==OPCODE_ID.TUNNEL_FLOOR or
			opcode==OPCODE_ID.TUNNEL_ROOF or opcode==OPCODE_ID.TUNNEL_WALL
	end

	local function seed_p3_open(opcode)
		return opcode==OPCODE_ID.BRIDGE_CLEAR or
			opcode==OPCODE_ID.CAUSEWAY_CULVERT or
			opcode==OPCODE_ID.CONTACT_FALL_CLEAR or
			opcode==OPCODE_ID.RECEIVER_OPEN or opcode==OPCODE_ID.RIVER_WATER or
			opcode==OPCODE_ID.TUNNEL_LUMEN
	end

	local function seed_add_seal(state,y_min,y_max,opcode,feature,interface)
		if y_min<AUTHORED_FLOOR then fail("seed oracle seal crosses authored floor") end
		local low1,high1,low2,high2,low3,high3=y_min,y_max,nil,nil,nil,nil
		local count=1
		local initial=state.count
		for candidate=1,initial do
			if state.priority[candidate]==3 and
					state.y_max[candidate]>=y_min and state.y_min[candidate]<=y_max then
				local other_opcode=state.opcode[candidate]
				if seed_p3_open(other_opcode) then
					fail("seed oracle seal overlaps P3 opening")
				elseif seed_p3_solid(other_opcode) then
					local nlow1,nhigh1,nlow2,nhigh2,nlow3,nhigh3
					local next_count=0
					for fragment=1,count do
						local low,high
						if fragment==1 then low,high=low1,high1
						elseif fragment==2 then low,high=low2,high2
						else low,high=low3,high3 end
						local other_low,other_high=state.y_min[candidate],state.y_max[candidate]
						local piece1_low,piece1_high,piece2_low,piece2_high
						if other_high<low or other_low>high then
							piece1_low,piece1_high=low,high
						else
							if low<other_low then
								piece1_low,piece1_high=low,other_low-1
							end
							if high>other_high then
								if piece1_low==nil then
									piece1_low,piece1_high=other_high+1,high
								else
									piece2_low,piece2_high=other_high+1,high
								end
							end
						end
						for piece=1,2 do
							local fragment_low,fragment_high
							if piece==1 then
								fragment_low,fragment_high=piece1_low,piece1_high
							else
								fragment_low,fragment_high=piece2_low,piece2_high
							end
							if fragment_low~=nil then
								next_count=next_count+1
								if next_count==1 then
									nlow1,nhigh1=fragment_low,fragment_high
								elseif next_count==2 then
									nlow2,nhigh2=fragment_low,fragment_high
								else
									nlow3,nhigh3=fragment_low,fragment_high
								end
							end
						end
					end
					if next_count>3 then fail("seed oracle seal fragment bound exceeded") end
					low1,high1,low2,high2,low3,high3=
						nlow1,nhigh1,nlow2,nhigh2,nlow3,nhigh3
					count=next_count
				end
			end
		end
		for fragment=1,count do
			local low,high
			if fragment==1 then low,high=low1,high1
			elseif fragment==2 then low,high=low2,high2
			else low,high=low3,high3 end
			seed_add_candidate(state,low,high,3,opcode,
				ROLE_ID.HYDROLOGY_SEAL,POLICY_TOKEN_ID.SEAL_VOID,feature,interface)
		end
	end

	local function seed_build_candidates(state,authority,get,metric_at,x,z)
		state.count=0
		state.roofed_bridge_headroom=false
		state.causeway=false
		state.causeway_interface=false
		state.causeway_culvert_eligible=false
		state.equal_surface_bank=false
		local terrain,water_y,hydro_id,depth=get(6,x,z),get(7,x,z),get(8,x,z),get(9,x,z)
		local kind,functional_y,feature,interface=get(10,x,z),get(11,x,z),
			get(12,x,z),get(13,x,z)
		local transition_kind,transition_id,upper,lower,face=get(14,x,z),
			get(15,x,z),get(16,x,z),get(17,x,z),get(19,x,z)
		local hard=get(20,x,z)
		local clearance=water_y
		if clearance==nil and upper~=nil then clearance=math.max(upper,lower) end
		local surface_cap=clearance and math.max(terrain,clearance) or terrain
		if terrain<AUTHORED_FLOOR or terrain>surface_cap or surface_cap>OWNER_MAX then
			fail("seed oracle surface interval differs")
		end
		local contact_lower_hydro,contact_bed
		if transition_kind=="waterfall" and face~=nil then
			local contact_relation=seed_transition_relation(authority,transition_id,
				"waterfall")
			contact_lower_hydro=authority.hydrology[contact_relation.row.lower_id]
			if not contact_lower_hydro then
				fail("seed oracle contact-face lower hydrology differs")
			end
			contact_bed=lower-contact_lower_hydro.depth
			if terrain~=contact_bed then
				fail("seed oracle contact-face bed differs")
			end
		end
		local culvert,culvert_bed=false,nil
		if kind=="causeway" then
			state.causeway=true
			state.causeway_interface=interface or false
			if functional_y~=terrain or clearance==nil or terrain<clearance+1 then
				fail("seed oracle causeway tuple differs")
			end
			local relation=seed_route_relation(authority,interface,"causeway",hydro_id,false)
			if relation and water_y~=nil and hydro_id~=nil then
				local metric_id,_,numerator,denominator=metric_at(x,z)
				if metric_id==hydro_id and numerator<=denominator then
					culvert=true
					local hydro=authority.hydrology[hydro_id]
					if not hydro or hydro.depth~=depth then
						fail("seed oracle culvert hydrology differs")
					end
					culvert_bed=water_y-depth
					if culvert_bed>=water_y then fail("seed oracle culvert bed differs") end
					state.causeway_culvert_eligible=true
				end
			end
		end
		if hard and kind=="anchor_platform" then
			if functional_y~=terrain then fail("seed oracle foundation height differs") end
			seed_add_operation(state,AUTHORED_FLOOR,terrain-1,
				OPCODE_ID.FOUNDATION_FILL,feature,interface)
			seed_add_operation(state,terrain,terrain,
				OPCODE_ID.FOUNDATION_SURFACE,feature,interface)
			seed_add_operation(state,terrain+1,terrain+4,
				OPCODE_ID.FOUNDATION_CLEAR,feature,interface)
		elseif kind=="anchor_platform" or kind=="land_grade" then
			if functional_y~=terrain then fail("seed oracle path height differs") end
			seed_add_operation(state,AUTHORED_FLOOR,terrain-1,
				OPCODE_ID.PATH_FILL,feature,interface)
			seed_add_operation(state,terrain,terrain,OPCODE_ID.PATH_SURFACE,
				feature,interface)
			seed_add_operation(state,terrain+1,terrain+4,OPCODE_ID.PATH_CLEAR,
				feature,interface)
		elseif kind=="ford" then
			if water_y==nil or functional_y~=terrain then
				fail("seed oracle ford tuple differs")
			end
			if interface~=nil then
				seed_route_relation(authority,interface,"ford",hydro_id,true)
			end
			seed_add_operation(state,terrain,terrain,OPCODE_ID.FORD_BED,
				feature,interface)
		elseif kind=="bridge_deck" then
			if clearance==nil then fail("seed oracle bridge clearance is nil") end
			local named=interface~=nil
			if named then seed_route_relation(authority,interface,"bridge",hydro_id,true) end
			local required=named and 4 or 2
			if functional_y<clearance+required or functional_y+4>OWNER_MAX then
				fail("seed oracle bridge guard differs")
			end
			local roofed_headroom=not named and surface_cap>=functional_y+5 and
				functional_y+4 or false
			seed_add_operation(state,math.max(terrain+1,clearance+1),functional_y-2,
				OPCODE_ID.BRIDGE_CLEAR,feature,interface,
				POLICY_TOKEN_ID.OPEN_ENGINEERED)
			seed_add_operation(state,functional_y-1,functional_y-1,
				OPCODE_ID.BRIDGE_SUPPORT,feature,interface)
			seed_add_operation(state,functional_y,functional_y,
				OPCODE_ID.BRIDGE_DECK,feature,interface)
			seed_add_operation(state,functional_y+1,functional_y+4,
				OPCODE_ID.BRIDGE_CLEAR,feature,interface,POLICY_TOKEN_ID.CUT_NATURAL)
			state.roofed_bridge_headroom=roofed_headroom
		elseif kind=="causeway" then
			seed_add_operation(state,culvert and water_y+1 or AUTHORED_FLOOR,
				terrain-1,OPCODE_ID.CAUSEWAY_FILL,feature,interface)
			seed_add_operation(state,terrain,terrain,OPCODE_ID.CAUSEWAY_SURFACE,
				feature,interface)
			if culvert then
				seed_add_operation(state,culvert_bed+1,water_y,
					OPCODE_ID.CAUSEWAY_CULVERT,feature,interface)
			end
			seed_add_operation(state,terrain+1,terrain+4,OPCODE_ID.PATH_CLEAR,
				feature,interface)
		elseif kind=="tunnel_floor" then
			if type(interface)~="string" then fail("seed oracle tunnel interface missing") end
			seed_add_operation(state,functional_y,functional_y,
				OPCODE_ID.TUNNEL_FLOOR,feature,interface)
			seed_add_operation(state,functional_y+1,functional_y+4,
				OPCODE_ID.TUNNEL_LUMEN,feature,interface)
			seed_add_operation(state,functional_y+5,functional_y+5,
				OPCODE_ID.TUNNEL_ROOF,feature,interface)
		end

		local wet_id,wet_surface,wet_bed,wet_relation=seed_named_wet(authority,get,x,z)
		if wet_id then
			seed_add_seal(state,wet_bed-2,wet_bed,OPCODE_ID.HYDROLOGY_BED_SEAL,
				wet_id,wet_relation and wet_relation.row.id or nil)
		else
			local sample_count,first_id,all_same,seal_low,sample_high,smallest=
				0,nil,true,nil,nil,nil
			local first_surface,all_same_surface=nil,true
			local whitebridge_main_samples,whitebridge_ford_samples=0,0
			for dx=-2,2 do for dz=-2,2 do
				local distance=math.abs(dx)+math.abs(dz)
				if distance>=1 and distance<=2 then
					local sample_id,sample_surface,sample_bed=seed_named_wet(authority,get,x+dx,z+dz)
					if sample_id then
						sample_count=sample_count+1
						if not first_id then first_id=sample_id
						elseif first_id~=sample_id then all_same=false end
						if first_surface==nil then first_surface=sample_surface
						elseif first_surface~=sample_surface then all_same_surface=false end
						if sample_id=="hydro_whitebridge_main" then
							whitebridge_main_samples=whitebridge_main_samples+1
						elseif sample_id=="hydro_whitebridge_ford" then
							whitebridge_ford_samples=whitebridge_ford_samples+1
						end
						local sample_seal=sample_bed-2
						seal_low=seal_low and math.min(seal_low,sample_seal) or sample_seal
						sample_high=sample_high and math.max(sample_high,sample_surface) or sample_surface
						if not smallest or sample_id<smallest then smallest=sample_id end
					end
				end
			end end
			if sample_count>0 then
				local bank_relation
				if not all_same then
					for relation_id,relation in pairs(authority.interfaces) do
						local relation_kind=relation.row.kind
						if relation_kind=="confluence" or relation_kind=="rapid" or
								relation_kind=="waterfall" then
							local compatible=true
							for dx=-2,2 do for dz=-2,2 do
								local distance=math.abs(dx)+math.abs(dz)
								if distance>=1 and distance<=2 then
									local sample_id=seed_named_wet(authority,get,x+dx,z+dz)
									if sample_id and not relation.members[sample_id] then
										compatible=false
									end
								end
							end end
							if compatible and (not bank_relation or relation_id<bank_relation.row.id) then
								bank_relation=relation
							end
						end
					end
					if not bank_relation then
						if not all_same_surface then
							fail("seed oracle bank relation absent")
						end
						state.equal_surface_bank=true
						state.equal_surface_bank_samples=sample_count
						state.equal_surface_bank_surface=first_surface
						state.equal_surface_bank_seal_low=seal_low
						state.equal_surface_bank_seal_high=math.min(terrain,sample_high)
						state.equal_surface_bank_feature=smallest
						state.equal_surface_bank_terrain=terrain
						state.equal_surface_bank_main_samples=whitebridge_main_samples
						state.equal_surface_bank_ford_samples=whitebridge_ford_samples
					end
				end
				local seal_high=math.min(terrain,sample_high)
				if seal_low<=seal_high then
					seed_add_seal(state,seal_low,seal_high,
						OPCODE_ID.HYDROLOGY_BANK_SEAL,smallest,
						bank_relation and bank_relation.row.id or nil)
				end
			end
		end

		if transition_kind=="waterfall" and face~=nil then
			seed_add_operation(state,contact_bed+1,lower-1,OPCODE_ID.RIVER_WATER,
				contact_lower_hydro.id,transition_id)
			seed_add_operation(state,lower,lower,OPCODE_ID.RECEIVER_OPEN,
				contact_lower_hydro.id,transition_id)
			seed_add_operation(state,lower+1,OWNER_MAX,OPCODE_ID.CONTACT_FALL_CLEAR,
				contact_lower_hydro.id,transition_id)
		elseif water_y~=nil and terrain<water_y then
			if hydro_id~=nil then
				local hydro=authority.hydrology[hydro_id]
				if not hydro or hydro.depth~=depth then fail("seed oracle water relation differs") end
				seed_add_operation(state,terrain+1,water_y,OPCODE_ID.RIVER_WATER,
					hydro_id,transition_id)
			else
				seed_add_operation(state,terrain+1,water_y,
					OPCODE_ID.ORDINARY_WATER,nil,nil)
			end
		end
		seed_add_operation(state,AUTHORED_FLOOR,terrain-1,
			OPCODE_ID.TERRAIN_FILL,nil,nil)
		seed_add_operation(state,terrain,terrain,OPCODE_ID.TERRAIN_SURFACE,nil,nil)
		seed_add_operation(state,surface_cap+1,OWNER_MAX,
			OPCODE_ID.TERRAIN_CLEAR,nil,nil)
		return terrain,clearance,surface_cap
	end

	local function seed_zero_corpus(loaded, raw_sha256, progress)
		local extent = loaded.source.extent
		if type(extent) ~= "table" then fail("accepted layout extent missing") end
		local relevant_min_x=owner_chunk_min(extent.min_x)-80
		local relevant_max_x=owner_chunk_min(extent.max_x)+159
		local relevant_min_z=owner_chunk_min(extent.min_z)-80
		local relevant_max_z=owner_chunk_min(extent.max_z)+159
		local scan_min_x,scan_max_x=relevant_min_x-2,relevant_max_x+2
		local scan_min_z,scan_max_z=relevant_min_z-2,relevant_max_z+2
		local scan_width=scan_max_x-scan_min_x+1
		local scan_height=scan_max_z-scan_min_z+1
		local expected_queries=49457936
		if scan_width~=7444 or scan_height~=6644 or
				scan_width*scan_height~=expected_queries then
			fail("seed oracle accepted scan rectangle differs")
		end
		local authority=seed_oracle_authority(loaded.source)
		local reserved_rejections=0
		for opcode=1,#OPCODES do
			if RESERVED_PRIORITY_BY_OPCODE[OPCODES[opcode]] then
				local candidate={0,0,2,opcode,ROLE_ID.AIR,
					POLICY_TOKEN_ID.CUT_NATURAL,0,0,0}
				expect_error("fail_fixture",function()
					loaded.planner_candidate_fixture(candidate,1,{1})
				end,"seed analytic reserved opcode rejection")
				reserved_rejections=reserved_rejections+1
			end
		end
		for priority=7,9 do
			local opcode=OPCODE_ID.FOUNDATION_FILL
			local candidate={0,0,priority,opcode,OP_ROLE[opcode],OP_POLICY[opcode],0,0,0}
			expect_error("fail_fixture",function()
				loaded.planner_candidate_fixture(candidate,1,{1})
			end,"seed analytic reserved priority rejection")
			reserved_rejections=reserved_rejections+1
		end
		if reserved_rejections~=9 then fail("reserved rejection population differs") end
		local ring,ring_z={},{nil,nil,nil,nil,nil}
		for field=1,20 do ring[field]={} end
		local x_ascii={}
		for x=scan_min_x,scan_max_x do
			x_ascii[x-scan_min_x+1]=integer_ascii(x,"scalar x")
		end
		local scalar_number_cache,scalar_string_cache={},{}
		local scalar_boolean_cache={[false]="false",[true]="true"}
		local scalar_number_count,scalar_string_count=0,0
		local function cached_scalar(value)
			if value==nil then return "-" end
			local kind=type(value)
			local cache
			if kind=="number" then cache=scalar_number_cache
			elseif kind=="string" then cache=scalar_string_cache
			elseif kind=="boolean" then return scalar_boolean_cache[value]
			else fail("seed oracle scalar cache type differs") end
			local encoded=cache[value]
			if encoded==nil then
				encoded=canonical_scalar(value)
				cache[value]=encoded
				if kind=="number" then
					scalar_number_count=scalar_number_count+1
					if scalar_number_count>131072 then
						fail("seed oracle numeric scalar cache bound exceeded")
					end
				else
					scalar_string_count=scalar_string_count+1
					if scalar_string_count>2048 then
						fail("seed oracle string scalar cache bound exceeded")
					end
				end
			end
			return encoded
		end
		local function ring_index(x,z)
			local slot=(z-scan_min_z)%5+1
			if ring_z[slot]~=z or x<scan_min_x or x>scan_max_x then
				fail("seed oracle rolling fact lookup escaped its five-row window")
			end
			return (slot-1)*scan_width+(x-scan_min_x)+1
		end
		local function fact(field,x,z) return ring[field][ring_index(x,z)] end
		local tuple={n=20}
		local tuple_fields,row_parts={},{}
		local scalar_rows={false}
		local metric_rows,metric_row_parts={},{}
		local metric_row_count=0
		local metric_z_ascii
		local scalar_queries,metric_queries=0,0
		local state=new_seed_candidate_state()
		local opcode_counts,priority_counts,mask_counts={},{},{}
		for index=1,#OPCODES do opcode_counts[OPCODES[index]]=0 end
		for priority=2,9 do priority_counts[priority]=0 end
		local relation_keys={}
		for relation_index=1,#OPERATION_RELATION do
			local row=OPERATION_RELATION[relation_index]
			local opcode=OPCODE_ID[row[1]]
			relation_keys[opcode]={}
			for policy_index=4,#row do
				local policy=POLICY_TOKEN_ID[row[policy_index]]
				local prefix="relation/"..row[1].."/"..row[policy_index].."/"
				relation_keys[opcode][policy]={start=prefix.."start",finish=prefix.."end",
					continuation=prefix.."continuation"}
			end
		end
		local witnesses,continuation_required={},{}
		local run_count,continuation_run_count=0,0
		local peak_candidate,peak_resolved=0,0
		local equal_surface_bank_fallback_count=0
		local equal_surface_bank_signature_survivor_count=0
		local surface_cap_gap_count=0
		local surface_cap_gap
		local causeway_footprint_counts,causeway_eligible_counts,
			causeway_resolved_counts={},{},{}
		for index=1,#authority.causeway_interfaces do
			local interface=authority.causeway_interfaces[index]
			causeway_footprint_counts[interface]=0
			causeway_eligible_counts[interface]=0
			causeway_resolved_counts[interface]=0
		end

		local function witness_less(current,chunk_z,chunk_x,z,x,owner_y)
			if current==nil then return true end
			if chunk_z~=current.chunk_z then return chunk_z<current.chunk_z end
			if chunk_x~=current.chunk_x then return chunk_x<current.chunk_x end
			if z~=current.z then return z<current.z end
			if x~=current.x then return x<current.x end
			return owner_y<current.owner_y
		end
		local function expected_run(run,slice_y)
			local feature=state.r_feature[run]
			local interface=state.r_interface[run]
			local feature_ordinal=feature and authority.stable_ordinal[feature] or 0
			local interface_ordinal=interface and authority.stable_ordinal[interface] or 0
			if (feature and not feature_ordinal) or
					(interface and not interface_ordinal) then
				fail("seed oracle stable-reference ordinal differs")
			end
			return {math.max(state.r_y_min[run],slice_y),
				math.min(state.r_y_max[run],slice_y+79),state.r_priority[run],
				state.r_opcode[run],state.r_role[run],state.r_policy[run],
				feature_ordinal,interface_ordinal,0}
		end
		local function select_witness(key,x,z,owner_y,target_y,run,force)
			local chunk_z,chunk_x=owner_chunk_min(z),owner_chunk_min(x)
			local current=witnesses[key]
			if force or witness_less(current,chunk_z,chunk_x,z,x,owner_y) then
				witnesses[key]={chunk_x=chunk_x,chunk_z=chunk_z,
					owner_y=owner_y,x=x,z=z,
					target_y=target_y,expected=run and expected_run(run,owner_y) or nil}
			end
		end
		local function first_resolved_in_slice(slice_y)
			local selected
			for run=1,state.resolved_count do
				if state.r_y_max[run]>=slice_y and state.r_y_min[run]<=slice_y+79 then
					if selected==nil or state.r_y_min[run]<state.r_y_min[selected] then
						selected=run
					end
				end
			end
			return selected
		end
		local function select_fixed_witness(key,y,x,z)
			for run=1,state.resolved_count do
				if state.r_y_min[run]<=y and state.r_y_max[run]>=y then
					select_witness(key,x,z,owner_chunk_min(y),y,run)
					return
				end
			end
			fail("seed oracle fixed target lacks a resolved run")
		end
		local function select_surface_cap_witness(y,x,z,terrain,water_y,
				transition_kind,transition_id,upper,lower,progress_q,face_mask)
			local selected
			for run=1,state.resolved_count do
				if state.r_y_min[run]<=y and state.r_y_max[run]>=y then
					if selected~=nil then
						fail("seed oracle surface-cap target has overlapping runs")
					end
					selected=run
				end
			end
			if selected~=nil then
				select_witness("fixed/surface_cap",x,z,owner_chunk_min(y),y,selected)
				return
			end
			if water_y~=nil or transition_kind~="waterfall" or
					type(transition_id)~="string" or transition_id=="" or
					type(upper)~="number" or upper~=math.floor(upper) or
					type(lower)~="number" or lower~=math.floor(lower) or
					type(progress_q)~="number" or progress_q~=math.floor(progress_q) or
					progress_q<0 or progress_q>65536 or face_mask~=nil or
					y~=math.max(terrain,upper,lower) then
				fail("seed oracle fixed target lacks a resolved run")
			end
			surface_cap_gap_count=surface_cap_gap_count+1
			local owner_y=owner_chunk_min(y)
			local chunk_z,chunk_x=owner_chunk_min(z),owner_chunk_min(x)
			if witness_less(surface_cap_gap,chunk_z,chunk_x,z,x,owner_y) then
				surface_cap_gap={chunk_z=chunk_z,chunk_x=chunk_x,z=z,x=x,
					owner_y=owner_y,terrain=terrain,surface_cap=y,upper=upper,
					lower=lower,progress_q=progress_q,transition_id=transition_id}
			end
		end
		local function metric_at(x,z)
			metric_queries=metric_queries+1
			local id,segment,numerator,denominator=
				loaded.planner_source.hydrology_metric_values_at(x,z)
			if id==nil then
				if segment~=nil or numerator~=nil or denominator~=nil then
					fail("seed oracle nil hydrology metric differs")
				end
			else
				if not authority.hydrology[id] then fail("seed oracle metric ID differs") end
				safe_integer(segment,"seed oracle metric segment",1)
				safe_integer(numerator,"seed oracle metric numerator",0)
				safe_integer(denominator,"seed oracle metric denominator",1)
			end
			metric_row_count=metric_row_count+1
			metric_row_parts[metric_row_count]=table.concat({"metric",
				x_ascii[x-scan_min_x+1],metric_z_ascii,
				cached_scalar(id),cached_scalar(segment),cached_scalar(numerator),
				cached_scalar(denominator)},"\t").."\n"
			return id,segment,numerator,denominator
		end

		local processed_rows=0
		for z=scan_min_z,scan_max_z do
			local slot=(z-scan_min_z)%5+1
			local z_ascii=integer_ascii(z,"scalar z")
			-- A reused row is deliberately invisible until all twenty scalar
			-- fields (including nils, which delete stale keys) have been replaced.
			ring_z[slot]=nil
			for x=scan_min_x,scan_max_x do
				tuple[1],tuple[2],tuple[3],tuple[4],tuple[5],tuple[6],tuple[7],
					tuple[8],tuple[9],tuple[10],tuple[11],tuple[12],tuple[13],
					tuple[14],tuple[15],tuple[16],tuple[17],tuple[18],tuple[19],tuple[20]=
					loaded.planner_source.column_values_at(x,z)
				scalar_queries=scalar_queries+1
				local biome=validate_column_tuple(tuple,"seed oracle scalar tuple")
				if biome~=loaded.session.biome_at(x,z) then
					fail("seed oracle logical-biome pass-through differs")
				end
				local index=(slot-1)*scan_width+(x-scan_min_x)+1
				for field=1,20 do ring[field][index]=tuple[field] end
				tuple_fields[1],tuple_fields[2]=x_ascii[x-scan_min_x+1],z_ascii
				for field=1,20 do tuple_fields[field+2]=cached_scalar(tuple[field]) end
				row_parts[x-scan_min_x+1]=table.concat(tuple_fields,"\t").."\n"
			end
			ring_z[slot]=z
			scalar_rows[#scalar_rows+1]=table.concat({"row",
				integer_ascii(z,"scalar row z"),digest_hex(raw_sha256,table.concat(row_parts))},
				"\t").."\n"
			local central_z=z-2
			if central_z>=relevant_min_z and central_z<=relevant_max_z then
				processed_rows=processed_rows+1
				metric_z_ascii=integer_ascii(central_z,"metric row z")
				for index=1,metric_row_count do metric_row_parts[index]=nil end
				metric_row_count=0
				for x=relevant_min_x,relevant_max_x do
					local terrain,clearance,surface_cap=seed_build_candidates(state,
						authority,fact,metric_at,x,central_z)
					seed_resolve_candidates(state)
					local fixed_equal_surface_bank=x==-456 and central_z==-1490
					if state.equal_surface_bank then
						equal_surface_bank_fallback_count=
							equal_surface_bank_fallback_count+1
						local signature=state.equal_surface_bank_samples==3 and
								state.equal_surface_bank_surface==17 and
								state.equal_surface_bank_seal_low==11 and
								state.equal_surface_bank_feature==
									"hydro_whitebridge_ford" and
								state.equal_surface_bank_main_samples==2 and
								state.equal_surface_bank_ford_samples==1
						if signature then
							local selected_run
							local previous_match_max
							for run=1,state.resolved_count do
								if state.r_opcode[run]==OPCODE_ID.HYDROLOGY_BANK_SEAL and
										state.r_policy[run]==POLICY_TOKEN_ID.SEAL_VOID and
									state.r_feature[run]==
										state.equal_surface_bank_feature and
									state.r_interface[run]==nil then
									if previous_match_max~=nil and
											state.r_y_min[run]<=previous_match_max then
										fail("seed oracle fixed bank survivor overlaps")
									end
									previous_match_max=state.r_y_max[run]
									if selected_run==nil or state.r_y_min[run]<
											state.r_y_min[selected_run] then
										selected_run=run
									end
								end
							end
							if selected_run then
								equal_surface_bank_signature_survivor_count=
									equal_surface_bank_signature_survivor_count+1
							end
							if fixed_equal_surface_bank then
								if not selected_run then
									fail("seed oracle fixed bank survivor is absent")
								end
								local target_y=state.r_y_min[selected_run]
								select_witness("fixed/equal_surface_mixed_bank",x,central_z,
									owner_chunk_min(target_y),target_y,selected_run)
								local current=witnesses["fixed/equal_surface_mixed_bank"]
								current.bank_samples=state.equal_surface_bank_samples
								current.bank_surface=state.equal_surface_bank_surface
								current.bank_seal_low=state.equal_surface_bank_seal_low
								current.bank_seal_high=state.equal_surface_bank_seal_high
								current.bank_terrain=state.equal_surface_bank_terrain
								current.bank_feature=state.equal_surface_bank_feature
								current.bank_main_samples=
									state.equal_surface_bank_main_samples
								current.bank_ford_samples=
									state.equal_surface_bank_ford_samples
							end
						end
						if fixed_equal_surface_bank and not signature then
							fail("seed oracle fixed bank sample facts differ")
						end
					elseif fixed_equal_surface_bank then
						fail("seed oracle fixed bank fallback is absent")
					end
					if state.roofed_bridge_headroom~=false then
						local headroom_y=state.roofed_bridge_headroom
						local selected_run
						for run=1,state.resolved_count do
							if state.r_y_min[run]<=headroom_y and
									state.r_y_max[run]>=headroom_y then
								if selected_run~=nil then
									fail("seed oracle roofed bridge winner overlaps")
								end
								selected_run=run
							end
						end
						if selected_run==nil or
								state.r_y_min[selected_run]~=headroom_y-3 or
								state.r_y_max[selected_run]~=headroom_y or
								state.r_priority[selected_run]~=3 or
								state.r_opcode[selected_run]~=OPCODE_ID.BRIDGE_CLEAR or
								state.r_role[selected_run]~=ROLE_ID.AIR or
								state.r_policy[selected_run]~=
									POLICY_TOKEN_ID.CUT_NATURAL or
								state.r_interface[selected_run]~=nil then
							fail("seed oracle roofed bridge headroom differs")
						end
						local old=witnesses["fixed/roofed_bridge_headroom"]
						select_witness("fixed/roofed_bridge_headroom",x,central_z,
							owner_chunk_min(headroom_y),headroom_y,selected_run)
						local current=witnesses["fixed/roofed_bridge_headroom"]
						if current~=old then
							current.roofed_terrain=terrain
							current.roofed_clearance=clearance
							current.roofed_functional_y=headroom_y-4
							current.roofed_surface_cap=surface_cap
						end
					end
					local candidate_peak,candidate_slice=seed_interval_peak(state,false)
					local resolved_peak,resolved_slice=seed_interval_peak(state,true)
					if candidate_peak>peak_candidate then
						peak_candidate=candidate_peak
						local run=first_resolved_in_slice(candidate_slice)
						if not run then fail("seed oracle candidate peak lacks resolved run") end
						select_witness("fixed/peak_candidate",x,central_z,candidate_slice,
							math.max(state.r_y_min[run],candidate_slice),run,true)
					elseif candidate_peak==peak_candidate then
						local run=first_resolved_in_slice(candidate_slice)
						if run then select_witness("fixed/peak_candidate",x,central_z,
							candidate_slice,math.max(state.r_y_min[run],candidate_slice),run) end
					end
					if resolved_peak>peak_resolved then
						peak_resolved=resolved_peak
						local run=first_resolved_in_slice(resolved_slice)
						if not run then fail("seed oracle resolved peak lacks run") end
						select_witness("fixed/peak_resolved",x,central_z,resolved_slice,
							math.max(state.r_y_min[run],resolved_slice),run,true)
					elseif resolved_peak==peak_resolved then
						local run=first_resolved_in_slice(resolved_slice)
						if run then select_witness("fixed/peak_resolved",x,central_z,
							resolved_slice,math.max(state.r_y_min[run],resolved_slice),run) end
					end

					select_witness("fixed/owner_min",x,central_z,OWNER_MIN,OWNER_MIN,nil)
					select_witness("fixed/below_floor_owner",x,central_z,
						owner_chunk_min(AUTHORED_FLOOR-1),AUTHORED_FLOOR-1,nil)
					select_fixed_witness("fixed/owner_max",OWNER_MAX,x,central_z)
					select_fixed_witness("fixed/authored_floor",AUTHORED_FLOOR,x,central_z)
					select_fixed_witness("fixed/terrain_y",terrain,x,central_z)
					if clearance~=nil then
						select_surface_cap_witness(surface_cap,x,central_z,terrain,
							fact(7,x,central_z),fact(14,x,central_z),
							fact(15,x,central_z),fact(16,x,central_z),
							fact(17,x,central_z),fact(18,x,central_z),
							fact(19,x,central_z))
						select_fixed_witness("fixed/first_sky_clear",surface_cap+1,x,central_z)
					end

					if state.causeway and state.causeway_interface~=false then
						local causeway_interface=state.causeway_interface
						if causeway_footprint_counts[causeway_interface]==nil then
							fail("seed oracle causeway footprint ownership differs")
						end
						causeway_footprint_counts[causeway_interface]=
							causeway_footprint_counts[causeway_interface]+1
						if state.causeway_culvert_eligible then
							causeway_eligible_counts[causeway_interface]=
								causeway_eligible_counts[causeway_interface]+1
						end
					end
					local column_culvert_interface
					for run=1,state.resolved_count do
						local first_slice=owner_chunk_min(state.r_y_min[run])
						local last_slice=owner_chunk_min(state.r_y_max[run])
						local pieces=(last_slice-first_slice)/80+1
						local opcode,priority=state.r_opcode[run],state.r_priority[run]
						if opcode==OPCODE_ID.CAUSEWAY_CULVERT then
							local culvert_interface=state.r_interface[run]
							if causeway_resolved_counts[culvert_interface]==nil or
									column_culvert_interface~=nil then
								fail("seed oracle causeway culvert ownership differs")
							end
							column_culvert_interface=culvert_interface
							causeway_resolved_counts[culvert_interface]=
								causeway_resolved_counts[culvert_interface]+1
						end
						opcode_counts[OPCODES[opcode]]=opcode_counts[OPCODES[opcode]]+pieces
						priority_counts[priority]=priority_counts[priority]+pieces
						local mask=MASK_BY_OPCODE[opcode]
						if mask then mask_counts[mask]=(mask_counts[mask] or 0)+pieces end
						run_count=run_count+pieces
						continuation_run_count=continuation_run_count+math.max(0,pieces-1)
						local keys=relation_keys[opcode] and
							relation_keys[opcode][state.r_policy[run]]
						if not keys then fail("seed oracle resolved relation key differs") end
						select_witness(keys.start,x,central_z,first_slice,
							state.r_y_min[run],run)
						select_witness(keys.finish,x,central_z,last_slice,
							state.r_y_max[run],run)
						if pieces>=3 then
							continuation_required[keys.continuation]=true
							select_witness(keys.continuation,x,central_z,
								first_slice+80,first_slice+80,run)
						end
					end
				end
				metric_rows[#metric_rows+1]=table.concat({"metric_row",
					metric_z_ascii,
					integer_ascii(metric_row_count,"metric row call count"),
					digest_hex(raw_sha256,table.concat(metric_row_parts))},"\t").."\n"
				if progress and (processed_rows%80==0 or central_z==relevant_max_z) then
					progress("seed_0",processed_rows,relevant_max_z-relevant_min_z+1)
				end
			end
		end
		if scalar_queries~=expected_queries or processed_rows~=
				relevant_max_z-relevant_min_z+1 then
			fail("seed oracle exact-once scan count differs")
		end
		for priority=2,9 do
			opcode_counts["priority/"..priority]=priority_counts[priority]
		end
		scalar_rows[1]=table.concat({"scan",integer_ascii(scan_min_x,"scan min x"),
			integer_ascii(scan_max_x,"scan max x"),integer_ascii(scan_min_z,"scan min z"),
			integer_ascii(scan_max_z,"scan max z"),
			integer_ascii(scalar_queries,"scalar query count"),
			integer_ascii(metric_queries,"hydrology metric query count")},"\t").."\n"
		for index=1,#metric_rows do scalar_rows[#scalar_rows+1]=metric_rows[index] end
		for index=1,#authority.causeway_interfaces do
			local interface=authority.causeway_interfaces[index]
			local footprint=causeway_footprint_counts[interface]
			local eligible=causeway_eligible_counts[interface]
			local resolved=causeway_resolved_counts[interface]
			if footprint<1 or eligible>footprint or resolved~=eligible then
				fail("named causeway culvert population differs: "..interface)
			end
			scalar_rows[#scalar_rows+1]=table.concat({"causeway_culvert",
				canonical_scalar(interface),
				integer_ascii(footprint,"causeway footprint column count"),
				integer_ascii(eligible,"causeway eligible culvert column count"),
				integer_ascii(resolved,"causeway resolved culvert column count")},
				"\t").."\n"
		end
		scalar_rows[#scalar_rows+1]=table.concat({"equal_surface_bank_fallbacks",
			integer_ascii(equal_surface_bank_fallback_count,
				"equal-surface bank fallback count"),
			integer_ascii(equal_surface_bank_signature_survivor_count,
				"equal-surface bank signature survivor count")},"\t").."\n"
		if surface_cap_gap_count<1 or not surface_cap_gap then
			fail("seed oracle cardinal-waterfall surface-cap gap is absent")
		end
		scalar_rows[#scalar_rows+1]=table.concat({"surface_cap_gaps",
			integer_ascii(surface_cap_gap_count,"surface-cap gap count"),
			integer_ascii(surface_cap_gap.x,"surface-cap gap x"),
			integer_ascii(surface_cap_gap.z,"surface-cap gap z"),
			integer_ascii(surface_cap_gap.terrain,"surface-cap gap terrain"),
			integer_ascii(surface_cap_gap.surface_cap,"surface-cap gap y"),
			integer_ascii(surface_cap_gap.upper,"surface-cap gap upper"),
			integer_ascii(surface_cap_gap.lower,"surface-cap gap lower"),
			integer_ascii(surface_cap_gap.progress_q,"surface-cap gap progress"),
			surface_cap_gap.transition_id},"\t").."\n"

		local fixed_keys={"fixed/owner_min","fixed/owner_max",
			"fixed/below_floor_owner","fixed/authored_floor",
			"fixed/equal_surface_mixed_bank","fixed/terrain_y",
			"fixed/surface_cap","fixed/first_sky_clear",
			"fixed/roofed_bridge_headroom","fixed/peak_candidate",
			"fixed/peak_resolved"}
		for index=1,#fixed_keys do
			if not witnesses[fixed_keys[index]] then fail("seed oracle fixed witness absent") end
		end
		local roofed=witnesses["fixed/roofed_bridge_headroom"]
		local roofed_feature=authority.stable_ordinal.poi_spur_025
		if roofed.x~=-1916 or roofed.z~=-2071 or roofed.target_y~=43 or
				roofed.roofed_terrain~=61 or roofed.roofed_clearance~=19 or
				roofed.roofed_functional_y~=39 or roofed.roofed_surface_cap~=61 or
				type(roofed_feature)~="number" or not exact_equal(roofed.expected,
					{40,43,3,OPCODE_ID.BRIDGE_CLEAR,ROLE_ID.AIR,
						POLICY_TOKEN_ID.CUT_NATURAL,roofed_feature,0,0}) then
			fail("seed oracle canonical roofed bridge witness differs")
		end
		local bank=witnesses["fixed/equal_surface_mixed_bank"]
		local bank_feature=authority.stable_ordinal.hydro_whitebridge_ford
		local main=authority.hydrology.hydro_whitebridge_main
		local ford=authority.hydrology.hydro_whitebridge_ford
		if equal_surface_bank_fallback_count<1 or
				bank.x~=-456 or bank.z~=-1490 or bank.bank_samples~=3 or
				bank.bank_surface~=17 or
				bank.bank_main_samples~=2 or bank.bank_ford_samples~=1 or
				bank.bank_seal_low~=11 or bank.bank_seal_high~=
					math.min(bank.bank_terrain,17) or
				bank.bank_feature~="hydro_whitebridge_ford" or
				not main or main.depth~=4 or not ford or ford.depth~=1 or
				type(bank_feature)~="number" or bank.expected[1]<11 or
				bank.expected[2]>bank.bank_seal_high or
				bank.target_y~=bank.expected[1] or bank.expected[3]~=3 or
				bank.expected[4]~=OPCODE_ID.HYDROLOGY_BANK_SEAL or
				bank.expected[5]~=ROLE_ID.HYDROLOGY_SEAL or
				bank.expected[6]~=POLICY_TOKEN_ID.SEAL_VOID or
				bank.expected[7]~=bank_feature or bank.expected[8]~=0 or
				bank.expected[9]~=0 then
			fail("seed oracle canonical equal-surface bank witness differs")
		end
		local relation_present_count=0
		for relation_index=1,#OPERATION_RELATION do
			local row=OPERATION_RELATION[relation_index]
			for policy_index=4,#row do
				local prefix="relation/"..row[1].."/"..row[policy_index].."/"
				local start_present=witnesses[prefix.."start"]~=nil
				local end_present=witnesses[prefix.."end"]~=nil
				if start_present~=end_present then
					fail("seed oracle relation endpoint witness is asymmetric")
				end
				local continuation_key=prefix.."continuation"
				local continuation_present=witnesses[continuation_key]~=nil
				local continuation_expected=
					continuation_required[continuation_key]==true
				if continuation_present~=continuation_expected or
						(continuation_present and not start_present) then
					fail("seed oracle strict-interior continuation witness differs")
				end
				if start_present then relation_present_count=relation_present_count+1 end
			end
		end
		if relation_present_count<1 or relation_present_count>27 then
			fail("seed oracle present relation population differs")
		end
		scalar_rows[#scalar_rows+1]="relation_present\t"..
			integer_ascii(relation_present_count,"present relation count").."\n"
		local witness_count=0
		local groups,group_by_key={},{}
		for key,witness in pairs(witnesses) do
			witness_count=witness_count+1
			local group_key=integer_ascii(witness.chunk_z,"group chunk z")..":"..
				integer_ascii(witness.chunk_x,"group chunk x")..":"..
				integer_ascii(witness.owner_y,"group owner y")
			local group=group_by_key[group_key]
			if not group then
				group={chunk_z=witness.chunk_z,chunk_x=witness.chunk_x,
					owner_y=witness.owner_y,witnesses={}}
				group_by_key[group_key]=group
				groups[#groups+1]=group
			end
			group.witnesses[#group.witnesses+1]={key=key,value=witness}
		end
		if witness_count>92 or #groups>92 then fail("seed oracle witness bound exceeded") end
		table.sort(groups,function(left,right)
			if left.chunk_z~=right.chunk_z then return left.chunk_z<right.chunk_z end
			if left.chunk_x~=right.chunk_x then return left.chunk_x<right.chunk_x end
			return left.owner_y<right.owner_y
		end)
		local plan_digest_rows={}
		local materialized_plan_calls=0
		for group_index=1,#groups do
			local group=groups[group_index]
			table.sort(group.witnesses,function(left,right) return left.key<right.key end)
			local minp=owner_position(group.chunk_x,group.owner_y,group.chunk_z)
			local maxp=owner_position(group.chunk_x+79,group.owner_y+79,group.chunk_z+79)
			local plan,_,checked=plan_at(loaded,minp,maxp)
			materialized_plan_calls=materialized_plan_calls+1
			local attachments={}
			for witness_index=1,#group.witnesses do
				local item=group.witnesses[witness_index]
				local witness=item.value
				local column=(witness.z-group.chunk_z)*80+
					(witness.x-group.chunk_x)+1
				local actual
				for run=plan.column_start[column],plan.column_start[column+1]-1 do
					local base=(run-1)*RUN_STRIDE
					if plan.run_values[base+1]<=witness.target_y and
							plan.run_values[base+2]>=witness.target_y then
						if actual then fail("materialized witness has overlapping runs") end
						actual={}
						for offset=1,RUN_STRIDE do actual[offset]=plan.run_values[base+offset] end
					end
				end
				if witness.expected==nil then
					if actual~=nil then fail("materialized absent witness has a run") end
					attachments[#attachments+1]=integer_ascii(#item.key,
						"witness key byte length")..":"..item.key.."=absent"
				else
					if not exact_equal(actual,witness.expected) then
						fail("materialized witness differs from independent oracle")
					end
					local scalars={}
					for index=1,RUN_STRIDE do
						scalars[index]=integer_ascii(actual[index],"witness run scalar")
					end
					attachments[#attachments+1]=integer_ascii(#item.key,
						"witness key byte length")..":"..item.key.."=run/"..
						table.concat(scalars,"/")
				end
			end
			plan_digest_rows[#plan_digest_rows+1]=table.concat({
				integer_ascii(group.chunk_z,"plan group chunk z"),
				integer_ascii(group.chunk_x,"plan group chunk x"),
				integer_ascii(group.owner_y,"plan group owner y"),
				digest_hex(raw_sha256,checked.bytes),
				table.concat(attachments,ATTACHMENT_SEPARATOR)},"\t").."\n"
		end
		if materialized_plan_calls~=#groups or materialized_plan_calls>92 then
			fail("seed oracle plan-slice call population differs")
		end
		return {
			tuple_sha256=canonical_rows(raw_sha256,scalar_rows),
			plan_sha256=canonical_rows(raw_sha256,plan_digest_rows),
			opcode_counts=opcode_counts,mask_counts=mask_counts,
			plan_count=#groups,run_count=run_count,
			continuation_run_count=continuation_run_count,
			peak_candidate=peak_candidate,peak_resolved=peak_resolved,
			reserved_rejections=reserved_rejections,
		}
	end

	local function numeric_array_digest(raw_sha256, values)
		local rows = {}
		for first = 1, #values, 4096 do
			local block = {}
			local last = math.min(first+4095,#values)
			for index = first, last do
				block[#block+1]=integer_ascii(values[index],"numeric digest value")
			end
			rows[#rows+1]=integer_ascii(first,"numeric block first").."\t"..
				integer_ascii(last,"numeric block last").."\t"..
				digest_hex(raw_sha256,table.concat(block,",")).."\n"
		end
		return canonical_rows(raw_sha256,rows)
	end

	local function native_heightmap_corpus(offline, raw_sha256, existing_loaded)
		local heightmap=existing_loaded and existing_loaded.fixture_heightmap or
			dense_fill(6400,HEIGHTMAP_SENTINEL)
		local loaded=existing_loaded or load_r5(offline,"0",heightmap)
		if dense_count(heightmap,"native-heightmap fixture source",6400)~=6400 then
			fail("native-heightmap fixture source differs")
		end
		local tuple=capture20(loaded.planner_source.column_values_at,0,0)
		validate_column_tuple(tuple,"heightmap tuple")
		local terrain=tuple[6]
		if terrain-17<AUTHORED_FLOOR or terrain+17>OWNER_MAX then
			fail("native top boundary fixture is outside authored bounds")
		end
		local lower_boundary=owner_chunk_min(terrain)
		local upper_boundary=lower_boundary+80
		local slice_boundary=terrain-lower_boundary<=upper_boundary-terrain and
			lower_boundary or upper_boundary
		local min_y=math.min(terrain-17,slice_boundary)
		local max_y=math.max(terrain+17,slice_boundary)
		if max_y-min_y+1>80 or min_y<OWNER_MIN or max_y>OWNER_MAX then
			fail("native top boundary fixture exceeds one owner slice")
		end
		local minp,maxp=owner_position(-32,min_y,-32),owner_position(47,max_y,47)
		local plan,generation,checked=plan_at(loaded,minp,maxp)
		if plan.run_count==0 then fail("heightmap fixture plan is empty") end
		local plan_digest=digest_hex(raw_sha256,checked.bytes)
		local rows,successful= {},0
		local function restore(value)
			for key in pairs(heightmap) do heightmap[key]=nil end
			for index=1,6400 do heightmap[index]=value end
		end
		local valid={{"sentinel",HEIGHTMAP_SENTINEL},{"terrain_minus_17",terrain-17},
			{"terrain_plus_17",terrain+17},{"slice_boundary",slice_boundary},
			{"internal",terrain},{"equal_max",maxp.y}}
		for index=1,#valid do
			restore(valid[index][2])
			local vm,observer=new_vm_for_plan(loaded,minp,maxp,valid[index][2],0,0,0)
			local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
				"offline_fixture")
			local snapshot=observer.snapshot()
			successful=successful+1
			rows[#rows+1]=table.concat({valid[index][1],"ok",outcome,
				numeric_array_digest(raw_sha256,snapshot.data),
				numeric_array_digest(raw_sha256,snapshot.param2)},"\t").."\n"
		end
		local invalid={{"nan",0/0},{"positive_infinity",math.huge},
			{"negative_infinity",-math.huge},{"fraction",0.5},
			{"below_sentinel",HEIGHTMAP_SENTINEL-1},{"above_owner",OWNER_MAX+1},
			{"boolean",true},{"string","0"}}
		local invalid_vm=new_vm_for_plan(loaded,minp,maxp,HEIGHTMAP_SENTINEL,0,0,0)
		for index=1,#invalid do
			restore(HEIGHTMAP_SENTINEL)
			heightmap[1]=invalid[index][2]
			expect_error("fail_native_heightmap",function()
				loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,"offline_fixture")
			end,"invalid heightmap "..invalid[index][1])
			rows[#rows+1]=invalid[index][1].."\tfail_native_heightmap\n"
		end
		restore(HEIGHTMAP_SENTINEL)
		heightmap[6400]=nil
		expect_error("fail_native_heightmap",function()
			loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,"offline_fixture")
		end,"heightmap hole")
		rows[#rows+1]="hole\tfail_native_heightmap\n"
		restore(HEIGHTMAP_SENTINEL)
		heightmap[6401]=0
		expect_error("fail_native_heightmap",function()
			loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,"offline_fixture")
		end,"heightmap extra key")
		rows[#rows+1]="extra\tfail_native_heightmap\n"
		restore(HEIGHTMAP_SENTINEL)
		setmetatable(heightmap,{})
		expect_error("fail_native_heightmap",function()
			loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,"offline_fixture")
		end,"heightmap metatable")
		rows[#rows+1]="metatable\tfail_native_heightmap\n"
		setmetatable(heightmap,nil)
		if digest_hex(raw_sha256,plan_bytes(plan))~=plan_digest then
			fail("plan bytes changed with heightmap state")
		end
		local position_sha256=native_position_oracle(loaded,raw_sha256,true)
		return {matrix_sha256=canonical_rows(raw_sha256,rows),
			plan_sha256=plan_digest,position_sha256=position_sha256,
			successful=successful,loaded=loaded}
	end

	local function micro_native_heightmap(loaded,raw_sha256)
		local tuple=capture20(loaded.planner_source.column_values_at,0,0)
		local terrain=tuple[6]
		local boundary=owner_chunk_min(terrain)
		local min_y=math.min(terrain-17,boundary)
		local max_y=math.max(terrain+17,boundary)
		if max_y-min_y+1>80 or min_y<AUTHORED_FLOOR then
			fail("micro native height range differs")
		end
		local minp,maxp=owner_position(-32,min_y,-32),owner_position(47,max_y,47)
		local plan,generation,checked=plan_at(loaded,minp,maxp)
		if plan.run_count==0 then fail("micro native plan is empty") end
		local original_digest=digest_hex(raw_sha256,checked.bytes)
		for index=1,6400 do loaded.fixture_heightmap[index]=HEIGHTMAP_SENTINEL end
		local valid={HEIGHTMAP_SENTINEL,terrain-17,terrain+17,boundary,terrain,max_y}
		for index=1,#valid do loaded.fixture_heightmap[index]=valid[index] end
		local vm,observer=new_vm_for_plan(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,0,15)
		local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
			"offline_fixture")
		if type(outcome)~="string" then fail("micro valid heightmap outcome differs") end
		local snapshot=observer.snapshot()
		local rows={"valid\t"..outcome.."\t"..call_signature(snapshot).."\n"}
		local invalid={{"nan",0/0},{"positive_infinity",math.huge},
			{"negative_infinity",-math.huge},{"fraction",0.5},
			{"below_sentinel",HEIGHTMAP_SENTINEL-1},{"above_owner",OWNER_MAX+1},
			{"boolean",true},{"string","0"}}
		local invalid_vm=new_vm_for_plan(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,0,15)
		for index=1,#invalid do
			for key=1,6400 do loaded.fixture_heightmap[key]=HEIGHTMAP_SENTINEL end
			loaded.fixture_heightmap[1]=invalid[index][2]
			expect_error("fail_native_heightmap",function()
				loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,
					"offline_fixture")
			end,"micro invalid heightmap "..invalid[index][1])
			rows[#rows+1]=invalid[index][1].."\tfail_native_heightmap\n"
		end
		for key=1,6400 do loaded.fixture_heightmap[key]=HEIGHTMAP_SENTINEL end
		loaded.fixture_heightmap[6400]=nil
		expect_error("fail_native_heightmap",function()
			loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,"offline_fixture")
		end,"micro heightmap hole")
		rows[#rows+1]="hole\tfail_native_heightmap\n"
		for key=1,6400 do loaded.fixture_heightmap[key]=HEIGHTMAP_SENTINEL end
		loaded.fixture_heightmap[6401]=0
		expect_error("fail_native_heightmap",function()
			loaded.adapter:apply(invalid_vm,minp,maxp,plan,generation,"offline_fixture")
		end,"micro heightmap extra key")
		rows[#rows+1]="extra\tfail_native_heightmap\n"
		loaded.fixture_heightmap[6401]=nil
		local repeated,repeated_generation,repeated_checked=plan_at(loaded,minp,maxp)
		if repeated_generation~=generation+1 or not rawequal(repeated,plan) or
				digest_hex(raw_sha256,repeated_checked.bytes)~=original_digest then
			fail("micro plan depends on valid native heightmap state")
		end
		local position_digest=native_position_oracle(loaded,raw_sha256,false)
		return canonical_rows(raw_sha256,rows),original_digest,position_digest,15,6
	end

	candidate_row=function(opcode,y_min,y_max,feature,interface,policy)
		return {y_min,y_max,OP_PRIORITY[opcode],opcode,OP_ROLE[opcode],
			policy or OP_POLICY[opcode],feature or 0,interface or 0,0}
	end

	append_values=function(target,values)
		for index=1,#values do target[#target+1]=values[index] end
	end

	local function fixture_run_bytes(values,count)
		local rows={integer_ascii(count,"fixture resolved run count")}
		for index=1,count*RUN_STRIDE do
			rows[#rows+1]=integer_ascii(values[index],"fixture resolved run value")
		end
		return table.concat(rows,"\n").."\n"
	end

	local function conflict_matrix_digest(loaded,raw_sha256)
		if type(loaded.planner_candidate_fixture)~="function" then
			fail("production planner candidate fixture seam is missing")
		end
		local rows={}
		for opcode=1,#OPCODES do
			if EMITTED_OPCODE[opcode] then
				local policy_set=OP_POLICY_ALT[opcode] and
					(integer_ascii(OP_POLICY_ALT[opcode],"alternate policy")..","..
						integer_ascii(OP_POLICY[opcode],"primary policy")) or
					integer_ascii(OP_POLICY[opcode],"primary policy")
				rows[#rows+1]=table.concat({"relation",OPCODES[opcode],
					integer_ascii(OP_PRIORITY[opcode],"relation priority"),
					integer_ascii(OP_ROLE[opcode],"relation role"),policy_set},"\t").."\n"
			end
		end
		for first=1,#OPCODES do
			if EMITTED_OPCODE[first] then
				for second=first,#OPCODES do
					if EMITTED_OPCODE[second] then
						local candidates={}
						append_values(candidates,candidate_row(first,0,0))
						append_values(candidates,candidate_row(second,0,0))
						local outcome,bytes
						if OP_PRIORITY[first]==OP_PRIORITY[second] and first~=second then
							outcome="reject_same_priority"
							for _,permutation in ipairs({{1,2},{2,1}}) do
								expect_error("fail_conflict",function()
									loaded.planner_candidate_fixture(candidates,2,permutation)
								end,"production same-priority conflict")
							end
						else
							local winner=OP_PRIORITY[first]<OP_PRIORITY[second] and first or
								(OP_PRIORITY[second]<OP_PRIORITY[first] and second or first)
							outcome=first==second and "coalesce_identical" or
								(winner==first and "first_wins" or "second_wins")
							for _,permutation in ipairs({{1,2},{2,1}}) do
								local resolved,count=loaded.planner_candidate_fixture(
									candidates,2,permutation)
								if count~=1 or resolved[1]~=0 or resolved[2]~=0 or
										resolved[4]~=winner then
									fail("production cross-priority winner differs")
								end
								local current=fixture_run_bytes(resolved,count)
								if bytes and bytes~=current then
									fail("candidate permutation changed resolved bytes")
								end
								bytes=current
							end
						end
						rows[#rows+1]=table.concat({
							integer_ascii(first,"conflict first opcode"),
							integer_ascii(second,"conflict second opcode"),outcome,
							bytes and digest_hex(raw_sha256,bytes) or "-"},"\t").."\n"
					end
				end
			end
		end
		local split={}
		local ordinary_water=OPCODE_ID.ORDINARY_WATER
		local terrain_clear=OPCODE_ID.TERRAIN_CLEAR
		append_values(split,candidate_row(ordinary_water,0,2))
		append_values(split,candidate_row(terrain_clear,1,1))
		local split_a,count_a=loaded.planner_candidate_fixture(split,2,{1,2})
		local split_b,count_b=loaded.planner_candidate_fixture(split,2,{2,1})
		if count_a~=3 or count_b~=3 or
				fixture_run_bytes(split_a,count_a)~=fixture_run_bytes(split_b,count_b) or
				split_a[1]~=0 or split_a[2]~=0 or split_a[4]~=ordinary_water or
				split_a[10]~=1 or split_a[11]~=1 or split_a[13]~=terrain_clear or
				split_a[19]~=2 or split_a[20]~=2 or
				split_a[22]~=ordinary_water then
			fail("production endpoint split resolution differs")
		end
		local hidden={}
		append_values(hidden,candidate_row(OPCODE_ID.FOUNDATION_CLEAR,0,0))
		append_values(hidden,candidate_row(OPCODE_ID.BRIDGE_CLEAR,0,0))
		append_values(hidden,candidate_row(OPCODE_ID.BRIDGE_DECK,0,0))
		for _,permutation in ipairs({{1,2,3},{1,3,2},{2,1,3},
			{2,3,1},{3,1,2},{3,2,1}}) do
			expect_error("fail_conflict",function()
				loaded.planner_candidate_fixture(hidden,3,permutation)
			end,"hidden same-priority triple permutation")
		end
		local dual_policy={}
		local bridge_clear=OPCODE_ID.BRIDGE_CLEAR
		append_values(dual_policy,candidate_row(bridge_clear,0,0,0,0,
			OP_POLICY[bridge_clear]))
		append_values(dual_policy,candidate_row(bridge_clear,0,0,0,0,
			OP_POLICY_ALT[bridge_clear]))
		for _,permutation in ipairs({{1,2},{2,1}}) do
			expect_error("fail_conflict",function()
				loaded.planner_candidate_fixture(dual_policy,2,permutation)
			end,"BRIDGE_CLEAR dual-policy semantic conflict")
		end
		rows[#rows+1]="hidden_triple\t6_permutations\tfail_conflict\n"
		rows[#rows+1]="bridge_clear_dual_policy\t2_permutations\tfail_conflict\n"
		local reserved_opcode_count = 0
		for opcode = 1, #OPCODES do
			local reserved_priority = RESERVED_PRIORITY_BY_OPCODE[OPCODES[opcode]]
			if reserved_priority ~= nil then
				reserved_opcode_count = reserved_opcode_count + 1
				local candidate = {0,0,2,opcode,ROLE_ID.AIR,
					POLICY_TOKEN_ID.CUT_NATURAL,0,0,0}
				expect_error("fail_fixture",function()
					loaded.planner_candidate_fixture(candidate,1,{1})
				end,"reserved P7-P9 opcode "..OPCODES[opcode])
				rows[#rows+1]=table.concat({"reserved_opcode",OPCODES[opcode],
					integer_ascii(reserved_priority,"reserved priority"),
					"fail_fixture"},"\t").."\n"
			end
		end
		if reserved_opcode_count ~= 6 then
			fail("reserved opcode fixture population differs")
		end
		for priority = 7, 9 do
			local opcode = OPCODE_ID.FOUNDATION_FILL
			local candidate = {0,0,priority,opcode,OP_ROLE[opcode],
				OP_POLICY[opcode],0,0,0}
			expect_error("fail_fixture",function()
				loaded.planner_candidate_fixture(candidate,1,{1})
			end,"reserved priority "..integer_ascii(priority,"reserved priority"))
			rows[#rows+1]="reserved_priority\t"..
				integer_ascii(priority,"reserved priority").."\tfail_fixture\n"
		end
		expect_error("fail_fixture",function()
			loaded.planner_candidate_fixture({},1,{1})
		end,"planner fixture malformed dense candidates")
		return canonical_rows(raw_sha256,rows)
	end

	local function micro_conflict_receipt(loaded,raw_sha256)
		local rows={}
		local pair={}
		append_values(pair,candidate_row(OPCODE_ID.BRIDGE_CLEAR,0,0))
		append_values(pair,candidate_row(OPCODE_ID.BRIDGE_DECK,0,0))
		for _,permutation in ipairs({{1,2},{2,1}}) do
			expect_error("fail_conflict",function()
				loaded.planner_candidate_fixture(pair,2,permutation)
			end,"micro same-priority pair")
		end
		rows[#rows+1]="pair\t2\tfail_conflict\n"
		local hidden={}
		append_values(hidden,candidate_row(OPCODE_ID.FOUNDATION_CLEAR,0,0))
		append_values(hidden,candidate_row(OPCODE_ID.BRIDGE_CLEAR,0,0))
		append_values(hidden,candidate_row(OPCODE_ID.BRIDGE_DECK,0,0))
		local permutations={{1,2,3},{1,3,2},{2,1,3},
			{2,3,1},{3,1,2},{3,2,1}}
		for index=1,#permutations do
			expect_error("fail_conflict",function()
				loaded.planner_candidate_fixture(hidden,3,permutations[index])
			end,"micro hidden same-priority triple")
		end
		rows[#rows+1]="hidden_triple\t6\tfail_conflict\n"
		local cross={}
		append_values(cross,candidate_row(OPCODE_ID.FOUNDATION_CLEAR,0,0))
		append_values(cross,candidate_row(OPCODE_ID.BRIDGE_CLEAR,0,0))
		local expected
		for _,permutation in ipairs({{1,2},{2,1}}) do
			local values,count=loaded.planner_candidate_fixture(cross,2,permutation)
			local bytes=fixture_run_bytes(values,count)
			if count~=1 or values[4]~=OPCODE_ID.FOUNDATION_CLEAR or
					(expected and expected~=bytes) then
				fail("micro cross-priority winner differs")
			end
			expected=bytes
		end
		rows[#rows+1]="cross_priority\t2\tFOUNDATION_CLEAR\n"
		return canonical_rows(raw_sha256,rows),10
	end

	local function order_digest(raw_sha256, order, values)
		local rows={}
		for index=1,#order do
			local key=order[index]
			rows[#rows+1]=integer_ascii(index,"order ordinal").."\t"..key..
				"\t"..values[key].."\n"
		end
		return canonical_rows(raw_sha256,rows)
	end

	local function owner_order_corpus(offline,raw_sha256,existing_loaded)
		local probe=existing_loaded or load_r5(offline,"0",
			dense_fill(6400,HEIGHTMAP_SENTINEL),
			{exact_param2=true,canopy_light=true,canopy_sunlight=true})
		local tuple=capture20(probe.planner_source.column_values_at,0,0)
		local base_y=math.max(AUTHORED_FLOOR,tuple[6])
		local keys={}
		for offset=0,2 do
			local y=owner_chunk_min(base_y)+offset*80
			if y+79<=OWNER_MAX then
				keys[#keys+1]=integer_ascii(y,"owner slice y")
			end
		end
		local ascending={unpack(keys)}
		local descending={}
		for index=#keys,1,-1 do descending[#descending+1]=keys[index] end
		local permuted={}
		for index=1,#keys,2 do permuted[#permuted+1]=keys[index] end
		for index=2,#keys,2 do permuted[#permuted+1]=keys[index] end
		local function run(order,reuse)
			local loaded=reuse or load_r5(offline,"0",
				dense_fill(6400,HEIGHTMAP_SENTINEL),
				{exact_param2=true,canopy_light=true,canopy_sunlight=true})
			local values={}
			for index=1,#order do
				local y=safe_integer(tonumber(order[index]),"owner order y")
				if integer_ascii(y,"owner order y")~=order[index] then
					fail("owner order y is not canonical")
				end
				local _,_,checked=plan_at(loaded,owner_position(-32,y,-32),
					owner_position(47,y+79,47))
				values[order[index]]=digest_hex(raw_sha256,checked.bytes)
			end
			return order_digest(raw_sha256,order,values),values,loaded
		end
		local ascending_digest,ascending_values=run(ascending,existing_loaded)
		local descending_digest,descending_values=run(descending,existing_loaded)
		local permuted_digest,permuted_values,loaded=run(permuted,existing_loaded)
		if not exact_equal(ascending_values,descending_values) or
				not exact_equal(ascending_values,permuted_values) then
			fail("plan bytes depend on vertical generation order")
		end
		return {ascending=ascending_digest,descending=descending_digest,
			permuted=permuted_digest,loaded=loaded}
	end

	local function central_state_digest(raw_sha256,snapshot,minp,maxp)
		local rows={}
		for z=minp.z,maxp.z do
			for y=minp.y,maxp.y do
				local values={}
				for x=minp.x,maxp.x do
					local cid,p2=snapshot_cell(snapshot,minp,maxp,x,y,z)
					values[#values+1]=integer_ascii(cid,"central cid")..":"..
						integer_ascii(p2,"central param2")
				end
				rows[#rows+1]=table.concat({integer_ascii(y,"central row y"),
					integer_ascii(z,"central row z"),table.concat(values,",")},"\t").."\n"
			end
		end
		return canonical_rows(raw_sha256,rows)
	end

	local independent_owner_oracle
	local function owner_apply_state(loaded,raw_sha256,minp,maxp,target,
			halo_overrides,equality_ignore_overtop)
		local plan,generation=plan_at(loaded,minp,maxp)
		local column=(target.z-minp.z)*80+(target.x-minp.x)+1
		rewrite_plan(plan,generation,{{column=column,y_min=target.y,y_max=target.y,
			opcode=OPCODE_ID.FOUNDATION_FILL}})
		local plan_digest=digest_hex(raw_sha256,plan_bytes(plan))
		local overrides={{x=target.x,y=target.y,z=target.z,cid=0,param2=7,
			light=15}}
		for index=1,#(halo_overrides or {}) do
			overrides[#overrides+1]=halo_overrides[index]
		end
		local equality_x=target.x-2
		if equality_ignore_overtop==true then
			if target.y+15~=1 or maxp.y+16<2 then
				fail("equality ignore-overtop fixture geometry differs")
			end
			for y=target.y-15,1 do
				overrides[#overrides+1]={x=equality_x,y=y,z=target.z,
					cid=0,param2=0,light=0}
			end
			overrides[#overrides+1]={x=equality_x,y=2,z=target.z,
				cid=65535,param2=0,light=0}
		end
		local vm,observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,1,7,15,
			overrides,false)
		local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
			"offline_fixture")
		local snapshot=observer.snapshot()
		if not outcome:match("^applied_") then fail("owner state did not commit") end
		local override_by_index={}
		for index=1,#overrides do
			local row=overrides[index]
			override_by_index[emerged_index(minp,maxp,row.x,row.y,row.z)]=row
		end
		local emin,emax=emerged_geometry(minp,maxp)
		for z=emin.z,emax.z do for y=emin.y,emax.y do for x=emin.x,emax.x do
			if x<minp.x or x>maxp.x or y<minp.y or y>maxp.y or
					z<minp.z or z>maxp.z then
				local offset=emerged_index(minp,maxp,x,y,z)
				local row=override_by_index[offset]
				local cid=row and row.cid or 1
				local p2=row and row.param2 or 7
				local light=row and row.light or 15
				if snapshot.data[offset]~=cid or snapshot.param2[offset]~=p2 or
						snapshot.light[offset]~=light then
					fail("compact owner changed complete read-only halo")
				end
			end
		end end end
		if equality_ignore_overtop==true then
			local overtop_cid,_,overtop_light=snapshot_cell(snapshot,minp,maxp,
				equality_x,2,target.z)
			local owner_cid,_,owner_light=snapshot_cell(snapshot,minp,maxp,
				equality_x,target.y,target.z)
			if overtop_cid~=65535 or overtop_light~=0 or owner_cid~=0 or
					owner_light~=0 then
				fail("equality ignore-overtop sunlight boundary differs")
			end
		end
		local seed_digest,trace_digest,light_digest=independent_owner_oracle(plan,
			minp,maxp,overrides,snapshot,outcome,raw_sha256,"compact owner")
		return {outcome=outcome,plan=plan_digest,
			central=central_state_digest(raw_sha256,snapshot,minp,maxp),
			light=light_digest,seeds=seed_digest,trace=trace_digest,
			snapshot=snapshot,minp=minp,maxp=maxp}
	end

	local function committed_halo(producer,consumer_minp,consumer_maxp)
		local emin={x=consumer_minp.x-16,y=consumer_minp.y-16,
			z=consumer_minp.z-16}
		local emax={x=consumer_maxp.x+16,y=consumer_maxp.y+16,
			z=consumer_maxp.z+16}
		local min_x=math.max(producer.minp.x,emin.x)
		local min_y=math.max(producer.minp.y,emin.y)
		local min_z=math.max(producer.minp.z,emin.z)
		local max_x=math.min(producer.maxp.x,emax.x)
		local max_y=math.min(producer.maxp.y,emax.y)
		local max_z=math.min(producer.maxp.z,emax.z)
		local result={}
		for z=min_z,max_z do
			for y=min_y,max_y do
				for x=min_x,max_x do
					if x<consumer_minp.x or x>consumer_maxp.x or
							y<consumer_minp.y or y>consumer_maxp.y or
							z<consumer_minp.z or z>consumer_maxp.z then
						local cid,p2,light=snapshot_cell(producer.snapshot,
							producer.minp,producer.maxp,x,y,z)
						result[#result+1]={x=x,y=y,z=z,cid=cid,param2=p2,light=light}
					end
				end
			end
		end
		if #result==0 then fail("adjacent owner committed halo is empty") end
		return result
	end

	local function owner_content_properties(cid,p2)
		if cid==0 or cid==101 then
			return CLASS_ID.AIR,0,0,0,true,true,true,true,0
		end
		if cid==1 then return CLASS_ID.NATURAL_HOST,0,0,0,false,false,false,false,0 end
		if cid==2 then return CLASS_ID.NATURAL_SURFACE,0,0,0,false,false,false,false,0 end
		if cid==3 or cid==12 or cid==13 or cid==14 or cid==17 then
			return CLASS_ID.NATURAL_VEGETATION,0,0,0,true,cid~=17,cid~=17,
				cid==3 or cid==13,0
		end
		if cid==4 then return CLASS_ID.NATIVE_ORE,0,0,0,false,false,false,false,0 end
		if cid==5 then return CLASS_ID.WP43_RESOURCE,0,0,0,false,false,false,false,0 end
		if cid==6 then return CLASS_ID.WP43_STRATUM,0,0,0,false,false,false,false,0 end
		if cid==7 or cid==110 then return CLASS_ID.LIQUID,1,1,0,false,true,true,true,0 end
		if cid==8 or cid==113 then return CLASS_ID.LIQUID,2,1,0,false,true,true,true,0 end
		if cid==11 then return CLASS_ID.LIQUID,3,1,0,false,true,true,true,0 end
		if cid==15 then return CLASS_ID.LIQUID,1,2,p2,false,true,true,true,0 end
		if cid==16 then return CLASS_ID.LIQUID,3,2,p2,false,true,true,true,0 end
		if cid==9 then return CLASS_ID.FOREIGN,0,0,0,false,false,false,false,0 end
		if cid==10 then return CLASS_ID.UNKNOWN,0,0,0,false,false,false,false,0 end
		if cid==65535 then return CLASS_ID.IGNORE,0,0,0,false,false,false,false,0 end
		if cid>=102 and cid<=116 then
			if cid==110 then return CLASS_ID.LIQUID,1,1,0,false,true,true,true,0 end
			if cid==113 then return CLASS_ID.LIQUID,2,1,0,false,true,true,true,0 end
			return CLASS_ID.NATURAL_HOST,0,0,0,false,false,false,false,0
		end
		return CLASS_ID.UNKNOWN,0,0,0,false,false,false,false,0
	end

	independent_owner_oracle=function(plan,minp,maxp,prestate_overrides,
			snapshot,outcome,raw_sha256,label)
		local emin,emax,ex,ey,z_stride=emerged_geometry(minp,maxp)
		local function index_of(x,y,z)
			return (z-emin.z)*z_stride+(y-emin.y)*ex+(x-emin.x)+1
		end
		local function coordinate_of(index)
			local offset=index-1
			local z_offset=math.floor(offset/z_stride)
			offset=offset-z_offset*z_stride
			local y_offset=math.floor(offset/ex)
			return emin.x+(offset-y_offset*ex),emin.y+y_offset,emin.z+z_offset
		end
		local prestate_by_index={}
		for index=1,#(prestate_overrides or {}) do
			local row=prestate_overrides[index]
			prestate_by_index[index_of(row.x,row.y,row.z)]=row
		end
		local changed_cid,changed_p2,transparent={},{},{}
		local liquid_checks={}
		local content_dirty,param2_dirty,light_dirty,liquid_dirty=false,false,false,false
		local dirty_min_x,dirty_min_y,dirty_min_z=MAX_SAFE,MAX_SAFE,MAX_SAFE
		local dirty_max_x,dirty_max_y,dirty_max_z=-MAX_SAFE,-MAX_SAFE,-MAX_SAFE
		local x_count=maxp.x-minp.x+1
		for column=1,(maxp.x-minp.x+1)*(maxp.z-minp.z+1) do
			local column_offset=column-1
			local z=minp.z+math.floor(column_offset/x_count)
			local x=minp.x+(column_offset%x_count)
			for run=plan.column_start[column],plan.column_start[column+1]-1 do
				local base=(run-1)*RUN_STRIDE
				local policy=plan.run_values[base+6]
				local role=plan.run_values[base+5]
				local target_cid=100+role
				local target_p2=role
				for y=plan.run_values[base+1],plan.run_values[base+2] do
					local offset=index_of(x,y,z)
					local old=prestate_by_index[offset]
					local old_cid=old and old.cid or 1
					local old_p2=old and old.param2 or 7
					local old_class,old_family,old_kind,old_level,old_floodable,
						old_paramtype,old_light,old_sun,old_source=
						owner_content_properties(old_cid,old_p2)
					if old_class==CLASS_ID.IGNORE or old_class==CLASS_ID.FOREIGN or
							old_class==CLASS_ID.UNKNOWN or
							(old_class==CLASS_ID.LIQUID and old_family~=1 and old_family~=2) then
						fail(label.." independent positive replacement rejects")
					end
					local writes=false
					if policy==POLICY_ID.FILL_VOID or policy==POLICY_ID.SEAL_VOID then
						writes=old_class==CLASS_ID.AIR or old_class==CLASS_ID.LIQUID or
							old_class==CLASS_ID.NATURAL_VEGETATION
					elseif policy==POLICY_ID.CUT_NATURAL or
							policy==POLICY_ID.OPEN_ENGINEERED then
						writes=old_class~=CLASS_ID.AIR
					elseif policy==POLICY_ID.SURFACE_EXACT or
							policy==POLICY_ID.WRITE_WATER then
						writes=true
					elseif policy~=POLICY_ID.DEEP_EXACT_HOST then
						fail(label.." independent replacement policy differs")
					end
					local final_content_cid=writes and target_cid or old_cid
					local content_changed=final_content_cid~=old_cid
					local param2_changed=target_p2~=old_p2
					if content_changed then
						changed_cid[offset]=final_content_cid
						content_dirty=true
					end
					if param2_changed then
						changed_p2[offset]=target_p2
						param2_dirty=true
					end
					local _,new_family,new_kind,new_level,new_floodable,
						new_paramtype,new_light,new_sun,new_source=
						owner_content_properties(final_content_cid,target_p2)
					if content_changed and (new_paramtype~=old_paramtype or
							new_light~=old_light or new_sun~=old_sun or
							new_source~=old_source) then
						light_dirty=true
						if x<dirty_min_x then dirty_min_x=x end
						if y<dirty_min_y then dirty_min_y=y end
						if z<dirty_min_z then dirty_min_z=z end
						if x>dirty_max_x then dirty_max_x=x end
						if y>dirty_max_y then dirty_max_y=y end
						if z>dirty_max_z then dirty_max_z=z end
					end
					if content_changed or param2_changed then
						liquid_checks[#liquid_checks+1]={offset=offset,x=x,y=y,z=z,
							old_family=old_family,old_kind=old_kind,old_level=old_level,
							old_floodable=old_floodable,new_family=new_family,
							new_kind=new_kind,new_level=new_level,
							new_floodable=new_floodable}
					end
					if new_light then transparent[offset]=true end
				end
			end
		end
		for offset,row in pairs(prestate_by_index) do
			local cid=changed_cid[offset] or row.cid
			local p2=changed_p2[offset] or row.param2
			local _,_,_,_,_,_,light_propagates=owner_content_properties(cid,p2)
			if light_propagates then transparent[offset]=true end
		end
		local function original_light(offset)
			local row=prestate_by_index[offset]
			return row and row.light or 15
		end
		local function final_cid(offset)
			local cid=changed_cid[offset]
			if cid~=nil then return cid end
			local row=prestate_by_index[offset]
			return row and row.cid or 1
		end
		local function final_p2(offset)
			local p2=changed_p2[offset]
			if p2~=nil then return p2 end
			local row=prestate_by_index[offset]
			return row and row.param2 or 7
		end
		for check_index=1,#liquid_checks do
			local check=liquid_checks[check_index]
			if check.old_family>0 or check.new_family>0 or
					check.old_kind~=check.new_kind or
					check.old_family~=check.new_family or
					check.old_level~=check.new_level then
				liquid_dirty=true
			elseif check.old_floodable~=check.new_floodable then
				for face=1,6 do
					local nx=check.x+FACE_OFFSETS[face][1]
					local ny=check.y+FACE_OFFSETS[face][2]
					local nz=check.z+FACE_OFFSETS[face][3]
					if nx<minp.x or nx>maxp.x or ny<minp.y or ny>maxp.y or
							nz<minp.z or nz>maxp.z then
						liquid_dirty=true
					else
						local neighbor=index_of(nx,ny,nz)
						local old=prestate_by_index[neighbor]
						local old_cid=old and old.cid or 1
						local old_p2=old and old.param2 or 7
						local neighbor_cid=final_cid(neighbor)
						local neighbor_p2=final_p2(neighbor)
						local _,family,kind=owner_content_properties(neighbor_cid,
							neighbor_p2)
						if neighbor_cid==old_cid and neighbor_p2==old_p2 and
								(family==1 or family==2) and (kind==1 or kind==2) then
							liquid_dirty=true
						end
					end
					if liquid_dirty then break end
				end
			end
			if liquid_dirty then break end
		end
		local expected_outcome="applied_"..(content_dirty and "c" or "")..
			(param2_dirty and "p" or "")..(light_dirty and "l" or "")..
			(liquid_dirty and "q" or "")
		if outcome~=expected_outcome then fail(label.." independent outcome differs") end
		for z=minp.z,maxp.z do for y=minp.y,maxp.y do for x=minp.x,maxp.x do
			local offset=index_of(x,y,z)
			if snapshot.data[offset]~=final_cid(offset) or
					snapshot.param2[offset]~=final_p2(offset) then
				fail(label.." independent central content/param2 differs")
			end
		end end end

		local trace={"get_emerged_area","get_heightmap","get_data","get_param2_data"}
		local seed_rows={}
		local light_values={}
		local light_min,light_max
		local function in_light_box(x,y,z)
			return light_min and x>=light_min.x and x<=light_max.x and
				y>=light_min.y and y<=light_max.y and z>=light_min.z and z<=light_max.z
		end
		if light_dirty then
			light_min={x=math.max(emin.x,dirty_min_x-15),
				y=math.max(emin.y,dirty_min_y-15),z=math.max(emin.z,dirty_min_z-15)}
			light_max={x=math.min(emax.x,dirty_max_x+15),
				y=math.min(emax.y-1,dirty_max_y+15),z=math.min(emax.z,dirty_max_z+15)}
			trace[#trace+1]="get_light_data"
		end
		if content_dirty then trace[#trace+1]="set_data" end
		if param2_dirty then trace[#trace+1]="set_param2_data" end
		if light_dirty then
			local function box_text(prefix,p1,p2,suffix)
				return prefix..integer_ascii(p1.x,label.." box x1")..","..
					integer_ascii(p1.y,label.." box y1")..","..
					integer_ascii(p1.z,label.." box z1")..","..
					integer_ascii(p2.x,label.." box x2")..","..
					integer_ascii(p2.y,label.." box y2")..","..
					integer_ascii(p2.z,label.." box z2")..(suffix or "")
			end
			trace[#trace+1]=box_text("set_lighting:0,0,",light_min,light_max)
			for offset in pairs(transparent) do
				local x,y,z=coordinate_of(offset)
				light_values[offset]=in_light_box(x,y,z) and 0 or original_light(offset)
			end
			local seed_y=light_max.y+1
			for z=light_min.z,light_max.z do
				local first_x
				for x=light_min.x,light_max.x+1 do
					local seeds=false
					if x<=light_max.x then
						local offset=index_of(x,seed_y,z)
						local cid=final_cid(offset)
						local _,_,_,_,_,_,_,sunlight=owner_content_properties(cid,
							final_p2(offset))
						seeds=cid~=65535 and sunlight and original_light(offset)==15
					end
					if seeds and not first_x then first_x=x end
					if first_x and not seeds then
						local last_x=x-1
						local seed_min={x=first_x,y=seed_y,z=z}
						local seed_max={x=last_x,y=seed_y,z=z}
						local detail=box_text("set_lighting:15,0,",seed_min,seed_max)
						trace[#trace+1]=detail
						seed_rows[#seed_rows+1]=integer_ascii(#seed_rows+1,
							label.." seed ordinal").."\t"..detail.."\n"
						for seed_x=first_x,last_x do
							light_values[index_of(seed_x,seed_y,z)]=15
						end
						first_x=nil
					end
				end
			end
			local propagate_shadow=light_max.y<=1
			local calc_max_y=light_max.y
			if not propagate_shadow and calc_max_y>maxp.y then
				calc_max_y=maxp.y
			end
			local calc_seed_y=calc_max_y+1
			for z=light_min.z,light_max.z do for x=light_min.x,light_max.x do
				local overtop=index_of(x,calc_seed_y,z)
				local overtop_cid=final_cid(overtop)
				local overtop_light=light_values[overtop]
				if overtop_light==nil then overtop_light=original_light(overtop) end
				local seeded=overtop_cid==65535 and 1<calc_max_y or
					(overtop_cid~=65535 and
						(not propagate_shadow or overtop_light%16==15))
				if seeded then
					for y=calc_max_y,light_min.y,-1 do
						local offset=index_of(x,y,z)
						local _,_,_,_,_,_,_,sunlight=owner_content_properties(
							final_cid(offset),final_p2(offset))
						if not sunlight then break end
						light_values[offset]=15
					end
				end
			end end
			local queue_index,queue_light={},{}
			local queue_head,queue_tail=1,0
			for offset in pairs(transparent) do
				local value=light_values[offset]
				if value and value>0 then
					queue_tail=queue_tail+1
					queue_index[queue_tail],queue_light[queue_tail]=offset,value
				end
			end
			local function spread(x,y,z,incoming)
				if x<emin.x or x>emax.x or y<emin.y or y>emax.y or
						z<emin.z or z>emax.z then return end
				local offset=index_of(x,y,z)
				if not transparent[offset] or final_cid(offset)==65535 then return end
				local day=incoming%16
				local night=math.floor(incoming/16)
				if day>0 then day=day-1 end
				if night>0 then night=night-1 end
				local current=light_values[offset] or 0
				local current_day=current%16
				local current_night=math.floor(current/16)
				if day<=current_day and night<=current_night then return end
				if day<current_day then day=current_day end
				if night<current_night then night=current_night end
				local packed=day+night*16
				light_values[offset]=packed
				queue_tail=queue_tail+1
				queue_index[queue_tail],queue_light[queue_tail]=offset,packed
			end
			while queue_head<=queue_tail do
				local offset,incoming=queue_index[queue_head],queue_light[queue_head]
				queue_head=queue_head+1
				local x,y,z=coordinate_of(offset)
				spread(x-1,y,z,incoming) spread(x+1,y,z,incoming)
				spread(x,y-1,z,incoming) spread(x,y+1,z,incoming)
				spread(x,y,z-1,incoming) spread(x,y,z+1,incoming)
			end
			local calc_max={x=light_max.x,y=calc_max_y,z=light_max.z}
			trace[#trace+1]=box_text("calc_lighting:",light_min,calc_max,","..
				tostring(light_max.y<=1))
			trace[#trace+1]="get_light_data"
			trace[#trace+1]="set_light_data"
		end
		if liquid_dirty then trace[#trace+1]="update_liquids" end
		assert_exact_vm_calls(snapshot,trace,label.." independent transaction")
		for z=minp.z,maxp.z do for y=minp.y,maxp.y do for x=minp.x,maxp.x do
			local offset=index_of(x,y,z)
			local expected_light=15
			if in_light_box(x,y,z) then expected_light=light_values[offset] or 0 end
			if snapshot.light[offset]~=expected_light then
				fail(label.." independent final light differs")
			end
		end end end
		if #seed_rows==0 then seed_rows[1]="none\tzero\n" end
		local expected_light_rows={}
		local volume=ex*ey*(emax.z-emin.z+1)
		for first=1,volume,4096 do
			local block={}
			local last=math.min(first+4095,volume)
			for offset=first,last do
				local x,y,z=coordinate_of(offset)
				local value=original_light(offset)
				if x>=minp.x and x<=maxp.x and y>=minp.y and y<=maxp.y and
						z>=minp.z and z<=maxp.z and in_light_box(x,y,z) then
					value=light_values[offset] or 0
				end
				block[#block+1]=integer_ascii(value,label.." expected light")
			end
			expected_light_rows[#expected_light_rows+1]=
				integer_ascii(first,label.." light block first").."\t"..
				integer_ascii(last,label.." light block last").."\t"..
				digest_hex(raw_sha256,table.concat(block,",")).."\n"
		end
		local expected_light_digest=canonical_rows(raw_sha256,expected_light_rows)
		if numeric_array_digest(raw_sha256,snapshot.light)~=expected_light_digest then
			fail(label.." independent full light digest differs")
		end
		local trace_rows={}
		for index=1,#trace do
			trace_rows[index]=integer_ascii(index,label.." trace ordinal").."\t"..
				trace[index].."\n"
		end
		return canonical_rows(raw_sha256,seed_rows),
			canonical_rows(raw_sha256,trace_rows),
			expected_light_digest
	end

	local function production_owner_state(loaded,raw_sha256,minp,maxp,
			halo_overrides)
		local plan,generation=plan_at(loaded,minp,maxp)
		if plan.run_count==0 then fail("production owner plan is empty") end
		local plan_digest=digest_hex(raw_sha256,plan_bytes(plan))
		local vm,observer=new_vm_fixture(loaded,minp,maxp,HEIGHTMAP_SENTINEL,
			1,7,15,halo_overrides,false)
		local outcome=loaded.adapter:apply(vm,minp,maxp,plan,generation,
			"offline_fixture")
		if not outcome:match("^applied_") then fail("production owner did not commit") end
		local snapshot=observer.snapshot()
		local halo_by_index={}
		for index=1,#(halo_overrides or {}) do
			local row=halo_overrides[index]
			halo_by_index[emerged_index(minp,maxp,row.x,row.y,row.z)]=row
		end
		local emin,emax=emerged_geometry(minp,maxp)
		for z=emin.z,emax.z do for y=emin.y,emax.y do for x=emin.x,emax.x do
			if x<minp.x or x>maxp.x or y<minp.y or y>maxp.y or
					z<minp.z or z>maxp.z then
				local offset=emerged_index(minp,maxp,x,y,z)
				local expected=halo_by_index[offset]
				local cid=expected and expected.cid or 1
				local p2=expected and expected.param2 or 7
				local light=expected and expected.light or 15
				if snapshot.data[offset]~=cid or snapshot.param2[offset]~=p2 or
						snapshot.light[offset]~=light then
					fail("production owner changed complete read-only halo")
				end
			end
		end end end
		local seed_digest,trace_digest,light_digest=independent_owner_oracle(plan,
			minp,maxp,halo_overrides,snapshot,outcome,raw_sha256,"production owner")
		return {outcome=outcome,plan=plan_digest,
			central=central_state_digest(raw_sha256,snapshot,minp,maxp),
			light=light_digest,trace=trace_digest,seeds=seed_digest,snapshot=snapshot,
			minp=minp,maxp=maxp}
	end

	local function actual_owner_order_corpus(loaded,raw_sha256)
		local tuple=capture20(loaded.planner_source.column_values_at,0,0)
		local base_y=owner_chunk_min(math.max(AUTHORED_FLOOR,tuple[6]))
		if base_y+159>OWNER_MAX then base_y=base_y-80 end
		local a_min=owner_position(-32,base_y,-32)
		local a_max=owner_position(47,base_y+79,47)
		local b_min=owner_position(48,base_y,-32)
		local b_max=owner_position(127,base_y+79,47)
		local a_pristine=production_owner_state(loaded,raw_sha256,a_min,a_max)
		local b_pristine=production_owner_state(loaded,raw_sha256,b_min,b_max)
		local a_to_b=committed_halo(a_pristine,b_min,b_max)
		local b_to_a=committed_halo(b_pristine,a_min,a_max)
		a_pristine.snapshot,b_pristine.snapshot=nil,nil
		local b_committed=production_owner_state(loaded,raw_sha256,b_min,b_max,
			a_to_b)
		local a_committed=production_owner_state(loaded,raw_sha256,a_min,a_max,
			b_to_a)

		local low_min=owner_position(-32,base_y,-32)
		local low_max=owner_position(47,base_y+79,47)
		local high_min=owner_position(-32,base_y+80,-32)
		local high_max=owner_position(47,base_y+159,47)
		local low_pristine=production_owner_state(loaded,raw_sha256,low_min,low_max)
		local high_pristine=production_owner_state(loaded,raw_sha256,high_min,high_max)
		local low_to_high=committed_halo(low_pristine,high_min,high_max)
		local high_to_low=committed_halo(high_pristine,low_min,low_max)
		low_pristine.snapshot,high_pristine.snapshot=nil,nil
		local high_committed=production_owner_state(loaded,raw_sha256,high_min,high_max,
			low_to_high)
		local low_committed=production_owner_state(loaded,raw_sha256,low_min,low_max,
			high_to_low)

		for _,pair in ipairs({{a_pristine,a_committed},{b_pristine,b_committed},
			{low_pristine,low_committed},{high_pristine,high_committed}}) do
			if pair[1].outcome~=pair[2].outcome or pair[1].plan~=pair[2].plan or
					pair[1].central~=pair[2].central then
				fail("committed halo changed plan/outcome/central content or param2")
			end
		end
		local rows={}
		for index,row in ipairs({a_pristine,b_committed,b_pristine,a_committed,
			low_pristine,high_committed,high_pristine,low_committed}) do
			rows[#rows+1]=table.concat({integer_ascii(index,"owner state ordinal"),
				row.outcome,row.plan,row.central,row.seeds,row.light,row.trace},"\t").."\n"
		end
		return {horizontal=canonical_rows(raw_sha256,{rows[1],rows[2],rows[3],rows[4]}),
			vertical=canonical_rows(raw_sha256,{rows[5],rows[6],rows[7],rows[8]}),
			all=canonical_rows(raw_sha256,rows),apply_attempts=8,vm_fixtures=8}
	end

	local function compact_owner_order_corpus(loaded,raw_sha256)
		local y=AUTHORED_FLOOR
		local a_min=owner_position(-32,y,-32)
		local a_max=owner_position(47,y+2,47)
		local b_min=owner_position(48,y,-32)
		local b_max=owner_position(127,y+2,47)
		local a_target={x=47,y=y+1,z=0}
		local b_target={x=48,y=y+1,z=0}
		local a_pristine=owner_apply_state(loaded,raw_sha256,a_min,a_max,a_target)
		local b_pristine=owner_apply_state(loaded,raw_sha256,b_min,b_max,b_target)
		local b_committed=owner_apply_state(loaded,raw_sha256,b_min,b_max,b_target,
			committed_halo(a_pristine,b_min,b_max))
		local a_committed=owner_apply_state(loaded,raw_sha256,a_min,a_max,a_target,
			committed_halo(b_pristine,a_min,a_max))

		local low_min=owner_position(-32,y,-32)
		local low_max=owner_position(47,y+2,47)
		local high_min=owner_position(-32,y+3,-32)
		local high_max=owner_position(47,y+5,47)
		local low_target={x=0,y=y+2,z=0}
		local high_target={x=0,y=y+3,z=0}
		local high_pristine=owner_apply_state(loaded,raw_sha256,high_min,high_max,
			high_target)
		local low_pristine=owner_apply_state(loaded,raw_sha256,low_min,low_max,
			low_target)
		local low_committed=owner_apply_state(loaded,raw_sha256,low_min,low_max,
			low_target,committed_halo(high_pristine,low_min,low_max))
		local high_committed=owner_apply_state(loaded,raw_sha256,high_min,high_max,
			high_target,committed_halo(low_pristine,high_min,high_max))
		for _,pair in ipairs({{a_pristine,a_committed},{b_pristine,b_committed},
			{low_pristine,low_committed},{high_pristine,high_committed}}) do
			if pair[1].outcome~=pair[2].outcome or pair[1].plan~=pair[2].plan or
					pair[1].central~=pair[2].central then
				fail("compact committed halo changed plan/outcome/central state")
			end
		end
		local rows={}
		for index,row in ipairs({a_pristine,b_committed,b_pristine,a_committed,
			high_pristine,low_committed,low_pristine,high_committed}) do
			rows[#rows+1]=table.concat({integer_ascii(index,"compact owner ordinal"),
				row.outcome,row.plan,row.central,row.seeds,row.light,row.trace},"\t").."\n"
		end
		return {horizontal=canonical_rows(raw_sha256,
			{rows[1],rows[2],rows[3],rows[4]}),vertical=canonical_rows(raw_sha256,
			{rows[5],rows[6],rows[7],rows[8]}),all=canonical_rows(raw_sha256,rows),
			apply_attempts=8,vm_fixtures=8}
	end

	local function fixture_owns(mapping, key, fixture_id)
		local owner = mapping and mapping[key]
		if type(owner) == "string" then return owner == fixture_id end
		return type(owner) == "table" and owner[fixture_id] == true
	end

	local function expected_keys(mapping, fixture_id)
		local result = {}
		if type(mapping) ~= "table" then fail("Common closed-key mapping missing") end
		for key in pairs(mapping) do
			if fixture_owns(mapping,key,fixture_id) then result[key]=true end
		end
		return result
	end

	local function validate_key_map(values, mapping, fixture_id, kind)
		local expected = expected_keys(mapping,fixture_id)
		for key,value in pairs(values) do
			if not expected[key] then fail(kind.." key is not owned by fixture: "..key) end
			if kind=="digest" then
				if type(value)~="string" or #value~=64 or not value:match("^[0-9a-f]+$") then
					fail("digest scalar differs")
				end
			elseif kind=="proof" then
				if value~=true then fail("proof scalar differs") end
			else safe_integer(value,kind.." scalar",0) end
			expected[key]=nil
		end
		for key in pairs(expected) do fail(kind.." key missing: "..key) end
	end

	local function add_owned_metrics(shard, snapshot)
		local mapping=common.METRIC_FIXTURES_BY_KEY
		for key in pairs(expected_keys(mapping,shard.fixture_id)) do
			if snapshot[key]==nil then fail("metric snapshot missing "..key) end
			add_metric(shard,key,snapshot[key])
		end
	end

	local SESSION_FIELDS={
		get=true,at=true,neighbors=true,travel_links=true,anchor=true,id_at=true,
		biome_at=true,race_region_at=true,faction_at=true,territory_rule_at=true,
		pvp_rule_at=true,surface_mob_level_at=true,mob_level_at=true,
		guard_level_at=true,terrain_height_at=true,water_class_at=true,
		nearest_route_at=true,nearest_hydrology_at=true,housing_eligible_at=true,
		canonical_kat=true,canonical_kat_digest=true,artifact_evidence=true,
		metrics=true,compatibility=true,
	}
	local CANONICAL_SEEDS={"0","1","9223372036854775808","18446744073709551615"}

	local function historical_shard(offline)
		local shard=new_shard("historical_r4")
		local authority=offline.preflight()
		local historical=authority.r4
		if type(historical)~="table" or
				dense_count(historical.seed_kat_bytes,"historical KAT bytes",4)~=4 or
				dense_count(historical.seed_kat_digests,"historical KAT digests",4)~=4 then
			fail("historical R4 authority differs")
		end
		local current_bytes={}
		for ordinal=1,4 do
			local loaded=offline.load_public(CANONICAL_SEEDS[ordinal],1)
			exact_fields(loaded,PUBLIC_LOAD_FIELDS,"public R4 load result")
			exact_fields(loaded.session,SESSION_FIELDS,"public R4 session")
			exact_fields(loaded.private_session,SESSION_FIELDS,"private R4 session")
			exact_fields(loaded.foundation_session,SESSION_FIELDS,"foundation R4 session")
			if loaded.foundation.enabled~=false or loaded.foundation.disabled_reason~=
					"WP40 R4 payload is validated but not published until R7" then
				fail("public R4 disabled bytes differ")
			end
			local public_bytes=loaded.session.canonical_kat()
			local private_bytes=loaded.private_session.canonical_kat()
			local foundation_bytes=loaded.foundation_session.canonical_kat()
			if public_bytes~=private_bytes or public_bytes~=foundation_bytes or
					public_bytes~=historical.seed_kat_bytes[ordinal] then
				fail("historical/current public R4 bytes differ at seed ordinal "..ordinal)
			end
			local digest=digest_hex(offline.raw_sha256,public_bytes)
			if digest~=historical.seed_kat_digests[ordinal] or
					digest~=loaded.session.canonical_kat_digest() then
				fail("historical/current public R4 digest differs")
			end
			current_bytes[ordinal]=public_bytes
			shard.seed_kats[ordinal]={ordinal=ordinal,seed=CANONICAL_SEEDS[ordinal],
				historical_sha256=historical.seed_kat_digests[ordinal],
				current_sha256=digest}
		end
		local bundle=common.frame_r4_public_kat_bundle(CANONICAL_SEEDS,current_bytes)
		local bundle_digest=digest_hex(offline.raw_sha256,bundle)
		if bundle~=historical.bundle_bytes or bundle_digest~=historical.bundle_sha256 then
			fail("historical/current R4 bundle differs")
		end
		add_digest(shard,"r4_public_kat_bundle",bundle_digest)
		add_proof(shard,"public_r4_fields_equal",true)
		add_proof(shard,"public_r4_disabled_bytes_equal",true)
		add_proof(shard,"public_r4_per_seed_bytes_equal",true)
		add_proof(shard,"public_r4_bundle_bytes_equal",true)
		return shard
	end

	local MASK_KEYS={"foundation","path","ford","bridge_clear",
		"bridge_support","bridge_deck","causeway","culvert","tunnel_floor",
		"tunnel_lumen","tunnel_wall","tunnel_roof","bed_seal","bank_seal",
		"receiver_open","contact_fall_clear","terrain_fill","terrain_surface",
		"terrain_clear"}

	local function seed_zero_shard(offline,progress)
		local shard=new_shard("seed_0")
		local loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL))
		local corpus=seed_zero_corpus(loaded,offline.raw_sha256,progress)
		if corpus.continuation_run_count<=0 or corpus.run_count<=corpus.plan_count then
			fail("analytic clipped-run population did not exercise continuation")
		end
		if corpus.opcode_counts.TUNNEL_WALL~=0 or
				(corpus.mask_counts.tunnel_wall or 0)~=0 then
			fail("accepted-source tunnel-wall population differs")
		end
		local representative=representative_apply(loaded,offline.raw_sha256,true)
		local stable_digest,relation_digest,stable_count=relation_oracle(
			loaded.source,loaded.planner_source and (function()
				local plan=plan_at(loaded,owner_position(-32,AUTHORED_FLOOR,-32),
					owner_position(47,AUTHORED_FLOOR,47))
				return plan.stable_refs
			end)() or nil,offline.raw_sha256)
		add_digest(shard,"planner_source_scalar",corpus.tuple_sha256)
		add_digest(shard,"planner_source_relations",relation_digest)
		add_digest(shard,"stable_refs",stable_digest)
		add_digest(shard,"seed_0_plan",corpus.plan_sha256)
		local mask_rows={}
		for index=1,#OPCODES do
			mask_rows[#mask_rows+1]="opcode/"..OPCODES[index].."\t"..
				integer_ascii(corpus.opcode_counts[OPCODES[index]],
					"opcode count").."\n"
			add_count(shard,"opcode/"..OPCODES[index],
				corpus.opcode_counts[OPCODES[index]])
		end
		for priority=2,9 do
			local value=corpus.opcode_counts["priority/"..priority]
			mask_rows[#mask_rows+1]="priority/"..
				integer_ascii(priority,"priority count key").."\t"..
				integer_ascii(value,"priority count").."\n"
			add_count(shard,"priority/"..priority,value)
		end
		for index=1,#MASK_KEYS do
			local value=corpus.mask_counts[MASK_KEYS[index]] or 0
			mask_rows[#mask_rows+1]="mask/"..MASK_KEYS[index].."\t"..
				integer_ascii(value,"mask count").."\n"
			add_count(shard,"mask/"..MASK_KEYS[index],value)
		end
		add_digest(shard,"mask_population",canonical_rows(offline.raw_sha256,mask_rows))
		add_proof(shard,"logical_biome_passthrough",true)
		add_proof(shard,"no_biome_share_input",true)
		add_proof(shard,"one_horizontal_session",true)
		add_proof(shard,"one_height_session",true)
		add_proof(shard,"zero_p7_p8_p9",
			corpus.reserved_rejections==9 and
			corpus.opcode_counts.BIOME_BED==0 and corpus.opcode_counts.BIOME_FILLER==0 and
			corpus.opcode_counts.BIOME_SHORE==0 and corpus.opcode_counts.BIOME_TOP==0 and
			corpus.opcode_counts.DECORATION==0 and
			corpus.opcode_counts.RESOURCE_EXACT_HOST==0 and
			corpus.opcode_counts["priority/7"]==0 and
			corpus.opcode_counts["priority/8"]==0 and
			corpus.opcode_counts["priority/9"]==0)
		add_proof(shard,"all_masks_closed",true)
		add_proof(shard,"vertical_continuation_analytic",true)
		local metrics=terminal_metrics(loaded)
		if metrics.stable_ref_count~=stable_count or
				metrics.peak_candidate_runs_per_column~=corpus.peak_candidate or
				metrics.peak_resolved_runs_per_column~=corpus.peak_resolved or
				metrics.plan_slice_table_allocations~=0 or
				metrics.adapter_apply_table_allocations~=0 then
			fail("seed-zero allocation/stable metrics differ")
		end
		add_owned_metrics(shard,metrics)
		return shard
	end

	local function worst_shard(offline)
		local shard=new_shard("worst_fixture")
		local loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL))
		local rows={}
		local retained_plan,retained_columns,retained_runs
		local expected_calls=0
		for min_y=owner_chunk_min(AUTHORED_FLOOR),
				owner_chunk_min(AUTHORED_FLOOR)+160,80 do
			local plan,_,checked=plan_at(loaded,owner_position(-32,min_y,-32),
				owner_position(47,min_y+79,47))
			expected_calls=expected_calls+1
			if retained_plan and (not rawequal(retained_plan,plan) or
					not rawequal(retained_columns,plan.column_start) or
					not rawequal(retained_runs,plan.run_values)) then
				fail("planner retained buffer identity changed")
			end
			retained_plan,retained_columns,retained_runs=plan,plan.column_start,
				plan.run_values
			rows[#rows+1]=integer_ascii(min_y,"worst slice y").."\t"..
				digest_hex(offline.raw_sha256,checked.bytes).."\n"
		end
		add_digest(shard,"worst_fixture_plan",canonical_rows(offline.raw_sha256,rows))
		local metrics=terminal_metrics(loaded)
		if metrics.construction_array_tables~=19 or
				metrics.construction_map_tables~=8 or
				metrics.allocator_bootstrap_tables~=4 or
				metrics.construction_table_allocations~=
					metrics.construction_array_tables+
					metrics.construction_map_tables+
					metrics.allocator_bootstrap_tables or
				metrics.retained_map_key_capacity>4096 or
				metrics.retained_map_key_count>metrics.retained_map_key_capacity or
				metrics.allocator_growth_events~=
					metrics.stable_ref_count+metrics.construction_array_tables-1 or
				metrics.horizontal_session_count~=1 or metrics.height_session_count~=1 or
				metrics.planner_source_count~=1 or metrics.planner_construction_count~=1 or
				metrics.plan_identity_count~=1 or
				metrics.stable_ref_count>WATCH_STABLE_REFS or
				metrics.plan_buffer_reuse_calls~=expected_calls or
				metrics.plan_slice_table_allocations~=0 or
				metrics.adapter_apply_table_allocations~=0 or
				metrics.peak_candidate_runs_per_column>16 or
				metrics.peak_resolved_runs_per_column>31 or
				metrics.hotpath_table_allocations~=0 then fail("worst bounds differ") end
		add_proof(shard,"bounded_candidate_runs",true)
		add_proof(shard,"bounded_resolved_runs",true)
		add_proof(shard,"zero_hotpath_table_allocations",true)
		add_owned_metrics(shard,metrics)
		return shard
	end

	local function domain_digest(raw_sha256,key,value)
		return digest_hex(raw_sha256,key.."\n"..value.."\n")
	end

	local function matrix_shard(offline)
		local shard=new_shard("matrix")
		local loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL),
			{exact_param2=true,canopy_light=true,canopy_sunlight=true,
				neutral_vegetation=true,forbid_cid=12},true)
		local minp,maxp=owner_position(-32,AUTHORED_FLOOR,-32),
			owner_position(47,AUTHORED_FLOOR,47)
		local plan,generation,first=plan_at(loaded,minp,maxp)
		local first_bytes=first.bytes
		local repeated,repeated_generation,second=plan_at(loaded,minp,maxp)
		if not rawequal(plan,repeated) or repeated_generation~=generation+1 or
				first_bytes~=second.bytes then fail("repeat-plan identity/bytes differ") end
		local replacement_digest=replacement_matrix_digest(loaded,offline.raw_sha256)
		local conflict_digest=conflict_matrix_digest(loaded,offline.raw_sha256)
		local apply_digest=production_apply_matrix(loaded,offline.raw_sha256,true)
		local relation_digest=planner_adapter_relation_kat(loaded,offline.raw_sha256)
		local isolated_digest=actual_adapter_call_matrix(loaded,offline.raw_sha256)
		local actual_light_digest=actual_light_matrix(loaded,offline.raw_sha256)
		local liquid_digest=liquid_face_matrix(loaded,offline.raw_sha256)
		local applied=representative_apply(loaded,offline.raw_sha256,true,nil,false)
		local trace_payload=applied.first.."\n"..applied.second.."\n"..
			applied.trace_sha256.."\n"..apply_digest.."\n"..isolated_digest.."\n"..
			actual_light_digest..
			"\n"..liquid_digest
		add_digest(shard,"candidate_shuffle",domain_digest(offline.raw_sha256,
			"candidate_shuffle",conflict_digest.."\n"..relation_digest))
		add_digest(shard,"repeat_plan",digest_hex(offline.raw_sha256,first_bytes))
		add_digest(shard,"replace_matrix",replacement_digest)
		add_digest(shard,"conflict_matrix",conflict_digest)
		add_digest(shard,"preservation",domain_digest(offline.raw_sha256,
			"preservation",replacement_digest.."\n"..apply_digest))
		add_digest(shard,"ignore_matrix",domain_digest(offline.raw_sha256,
			"ignore",replacement_digest.."\n"..apply_digest))
		for _,key in ipairs({"dirty_matrix","vm_call_matrix","light_matrix",
			"adapter_double_apply"}) do
			add_digest(shard,key,domain_digest(offline.raw_sha256,key,trace_payload))
		end
		add_digest(shard,"liquid_matrix",liquid_digest)
		for _,key in ipairs({"plan_identity_exact","same_priority_conflicts_reject",
			"foreign_unknown_ignore_reject","project_native_policy_total",
			"native_strata_typed","adapter_double_apply_equal","canopy_seed_rule",
			"ignore_overtop_sunlight_exact","liquid_owner_boundary_exact",
			"liquid_queue_exact","one_vm_transaction"}) do add_proof(shard,key,true) end
		local metric_loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL),
			{exact_param2=true,canopy_light=true,canopy_sunlight=true,
				forbid_zero=true})
		representative_apply(metric_loaded,offline.raw_sha256,false,1)
		local matrix_metrics=terminal_metrics(metric_loaded)
		if matrix_metrics.emerged_area_external_table_allocations~=2 or
				matrix_metrics.vm_get_emerged_area_calls~=1 then
			fail("successful matrix VM prefix/call metrics differ")
		end
		add_owned_metrics(shard,matrix_metrics)
		return shard
	end

	local function native_heightmap_shard(offline)
		local shard=new_shard("native_heightmap")
		local corpus=native_heightmap_corpus(offline,offline.raw_sha256)
		add_digest(shard,"mapgen_edge_formula",domain_digest(offline.raw_sha256,
			"edges",integer_ascii(OWNER_MIN,"owner minimum")..":"..
				integer_ascii(OWNER_MAX,"owner maximum")))
		add_digest(shard,"native_heightmap_matrix",corpus.matrix_sha256)
		add_digest(shard,"plan_heightmap_invariance",corpus.plan_sha256)
		add_digest(shard,"bplus_materialization",domain_digest(offline.raw_sha256,
			"bplus",corpus.position_sha256))
		for _,key in ipairs({"mapgen_edges_equal","native_heightmap_exact_once",
			"native_heightmap_domain_closed","native_heightmap_plan_independent",
			"native_caves_locally_preserved","ordinary_native_cave_air_preserved",
			"ordinary_native_cave_liquid_preserved","ordinary_sky_void_filled",
			"exact_masks_override_local_cave_preservation",
			"topmost_authored_ground_solid_exact","authored_water_exact",
			"no_unplanned_project_native_above_surface_cap",
			"no_operation_below_authored_floor"}) do add_proof(shard,key,true) end
		local metric_loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL))
		representative_apply(metric_loaded,offline.raw_sha256,false)
		local height_metrics=terminal_metrics(metric_loaded)
		if height_metrics.heightmap_fetch_calls~=1 or
				height_metrics.heightmap_entries_validated~=6400 or
				height_metrics.heightmap_external_table_allocations~=1 then
			fail("successful native-heightmap metrics differ")
		end
		add_owned_metrics(shard,height_metrics)
		return shard
	end

	local function owner_order_shard(offline)
		local shard=new_shard("owner_order")
		local loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL),
			{exact_param2=true,canopy_light=true,canopy_sunlight=true},true)
		local corpus=owner_order_corpus(offline,offline.raw_sha256,loaded)
		local actual=actual_owner_order_corpus(corpus.loaded,offline.raw_sha256)
		add_digest(shard,"owner_slice_matrix",actual.all)
		add_digest(shard,"committed_neighbor_matrix",domain_digest(
			offline.raw_sha256,"committed",actual.horizontal.."\n"..actual.vertical))
		add_digest(shard,"order_ascending",corpus.ascending)
		add_digest(shard,"order_descending",corpus.descending)
		add_digest(shard,"order_permuted",corpus.permuted)
		for _,key in ipairs({"owner_content_param2_only","halo_content_param2_unchanged",
			"committed_neighbor_plan_outcome_content_param2_equal",
			"nonlighting_halo_unread","light_halo_restored",
			"per_state_lighting_exact"}) do add_proof(shard,key,true) end
		return shard
	end

	local function parsed_integer(text,label)
		if type(text)~="string" or not text:match("^-?%d+$") then
			fail(label.." is not canonical decimal")
		end
		local value=tonumber(text)
		safe_integer(value,label)
		if integer_ascii(value,label)~=text then fail(label.." decimal is not canonical") end
		return value
	end

	local function parse_flat_json_object(bytes,label)
		if type(bytes)~="string" then fail(label.." is not JSON bytes") end
		local index,length=1,#bytes
		local function whitespace()
			while index<=length and bytes:sub(index,index):match("[ \t\r\n]") do
				index=index+1
			end
		end
		local function string_value()
			if bytes:sub(index,index)~='"' then fail(label.." string token differs") end
			index=index+1
			local first=index
			while index<=length and bytes:sub(index,index)~='"' do
				local byte=bytes:byte(index)
				if byte<32 or bytes:sub(index,index)=="\\" then
					fail(label.." uses unsupported JSON string escape/control")
				end
				index=index+1
			end
			if index>length then fail(label.." has unterminated JSON string") end
			local value=bytes:sub(first,index-1)
			index=index+1
			return value
		end
		local function scalar_value()
			local char=bytes:sub(index,index)
			if char=='"' then return string_value(),"string" end
			if bytes:sub(index,index+3)=="true" then index=index+4 return true,"boolean" end
			if bytes:sub(index,index+4)=="false" then index=index+5 return false,"boolean" end
			local token=bytes:sub(index):match("^(-?%d+)")
			if not token then fail(label.." scalar token differs") end
			index=index+#token
			return parsed_integer(token,label.." integer"),"integer"
		end
		whitespace()
		if bytes:sub(index,index)~="{" then fail(label.." is not one JSON object") end
		index=index+1
		local values,kinds={},{}
		whitespace()
		if bytes:sub(index,index)=="}" then index=index+1 else
			while true do
				whitespace()
				local key=string_value()
				if values[key]~=nil then fail(label.." has duplicate key "..key) end
				whitespace()
				if bytes:sub(index,index)~=":" then fail(label.." key separator differs") end
				index=index+1
				whitespace()
				values[key],kinds[key]=scalar_value()
				whitespace()
				local separator=bytes:sub(index,index)
				if separator=="}" then index=index+1 break end
				if separator~="," then fail(label.." item separator differs") end
				index=index+1
			end
		end
		whitespace()
		if index~=length+1 then fail(label.." has trailing JSON bytes") end
		return values,kinds
	end

	local function parse_typed_json_object(bytes,label)
		if type(bytes)~="string" then fail(label.." is not JSON bytes") end
		local index,length=1,#bytes
		local function whitespace()
			while index<=length and bytes:sub(index,index):match("[ \t\r\n]") do
				index=index+1
			end
		end
		local function string_value()
			if bytes:sub(index,index)~='"' then fail(label.." string token differs") end
			index=index+1
			local first=index
			while index<=length and bytes:sub(index,index)~='"' do
				local byte=bytes:byte(index)
				if byte<32 or bytes:sub(index,index)=="\\" then
					fail(label.." uses unsupported JSON string escape/control")
				end
				index=index+1
			end
			if index>length then fail(label.." has unterminated JSON string") end
			local value=bytes:sub(first,index-1)
			index=index+1
			return value
		end
		local parse_value
		local function object_value()
			if bytes:sub(index,index)~="{" then fail(label.." object token differs") end
			index=index+1
			local values,kinds={},{}
			whitespace()
			if bytes:sub(index,index)=="}" then index=index+1 return values,kinds end
			while true do
				whitespace()
				local key=string_value()
				if rawget(values,key)~=nil then fail(label.." has duplicate key "..key) end
				whitespace()
				if bytes:sub(index,index)~=":" then fail(label.." key separator differs") end
				index=index+1
				whitespace()
				values[key],kinds[key]=parse_value()
				whitespace()
				local separator=bytes:sub(index,index)
				if separator=="}" then index=index+1 break end
				if separator~="," then fail(label.." item separator differs") end
				index=index+1
			end
			return values,kinds
		end
		function parse_value()
			local char=bytes:sub(index,index)
			if char=='"' then return string_value(),"string" end
			if char=="{" then
				local values,kinds=object_value()
				values.__kinds=kinds
				return values,"object"
			end
			if bytes:sub(index,index+3)=="true" then index=index+4 return true,"boolean" end
			if bytes:sub(index,index+4)=="false" then index=index+5 return false,"boolean" end
			local token=bytes:sub(index):match("^(-?%d+)")
			if not token then fail(label.." scalar token differs") end
			index=index+#token
			return parsed_integer(token,label.." integer"),"integer"
		end
		whitespace()
		local values,kinds=object_value()
		whitespace()
		if index~=length+1 then fail(label.." has trailing JSON bytes") end
		return values,kinds
	end

	local function flag_set(value,label,allow_nofloatlands)
		if type(value)~="string" then fail(label.." is not text") end
		local result={}
		for raw in (value..","):gmatch("([^,]*),") do
			local token=raw:match("^[ \t\r\n]*(.-)[ \t\r\n]*$")
			if token=="" or result[token] then fail(label.." token set differs") end
			if token:sub(1,2)=="no" then
				if not allow_nofloatlands or token~="nofloatlands" then
					fail(label.." has unauthorized negation")
				end
			end
			result[token]=true
		end
		return result
	end

	local function require_set_equal(left,right,label)
		for key in pairs(left) do if not right[key] then fail(label.." has extra "..key) end end
		for key in pairs(right) do if not left[key] then fail(label.." is missing "..key) end end
	end

	local function dungeon_corpus_oracle(offline,loaded,raw_sha256,verify_plans)
		if type(offline.read_bound_input)~="function" then
			fail("bound dungeon input reader is missing")
		end
		local raw=offline.read_bound_input(common.DUNGEON_CORPUS_RAW_PATH)
		local summary=offline.read_bound_input(common.DUNGEON_CORPUS_SUMMARY_PATH)
		local summary_values,summary_kinds=parse_flat_json_object(summary,
			"dungeon summary")
		local expected={
			schema={"integer",2},status={"string","PASS"},
			json_validation={"string","complete-jq"},
			manifest_digest={"string",common.DUNGEON_CORPUS_DIRECTORY_DIGEST},
			record_count={"integer",34},requested_mapchunks={"integer",81},
			complete_records={"integer",1},emerge_errors={"integer",0},
			positive_callbacks={"integer",31},
			positive_count_is_golden={"boolean",false},mg_name={"string","v7"},
			chunksize={"integer",5},water_level={"integer",1},
			mg_flags={"string","caves,dungeons,light,decorations,biomes,ores"},
			mgv7_spflags={"string","mountains,ridges,nofloatlands,caverns"},
			mgv7_dungeon_ymin={"integer",-31000},
			mgv7_dungeon_ymax={"integer",-193},
		}
		for key,row in pairs(expected) do
			if summary_kinds[key]~=row[1] or summary_values[key]~=row[2] then
				fail("dungeon summary typed field differs: "..key)
			end
		end
		local manifest=manifest_values()
		for _,key in ipairs({"mg_name","chunksize","water_level",
			"mgv7_dungeon_ymin","mgv7_dungeon_ymax"}) do
			if summary_values[key]~=manifest[key] then
				fail("dungeon summary/manifest scalar differs: "..key)
			end
		end
		local summary_mg=flag_set(summary_values.mg_flags,"summary mg_flags",false)
		local manifest_mg=flag_set(manifest.mg_flags,"manifest mg_flags",false)
		require_set_equal(summary_mg,manifest_mg,"dungeon mg_flags")
		local summary_sp=flag_set(summary_values.mgv7_spflags,
			"summary mgv7_spflags",true)
		if summary_sp.floatlands or not summary_sp.nofloatlands then
			fail("dungeon floatlands negation relation differs")
		end
		summary_sp.nofloatlands=nil
		local manifest_sp=flag_set(manifest.mgv7_spflags,
			"manifest mgv7_spflags",false)
		require_set_equal(summary_sp,manifest_sp,"dungeon mgv7_spflags")
		local events={}
		local union={min_x=MAX_SAFE,min_y=MAX_SAFE,min_z=MAX_SAFE,
			max_x=-MAX_SAFE,max_y=-MAX_SAFE,max_z=-MAX_SAFE}
		local record_count,main_count,mapgen_count,complete_count=0,0,0,0
		local function object_fields(values,fields,label)
			exact_fields(values,fields,label)
		end
		local function xyz(value,label)
			object_fields(value,{x=true,y=true,z=true,__kinds=true},label)
			if value.__kinds.x~="integer" or value.__kinds.y~="integer" or
					value.__kinds.z~="integer" then fail(label.." scalar type differs") end
			return value.x,value.y,value.z
		end
		for line in (raw.."\n"):gmatch("([^\n]*)\n") do
			local payload=line:match("DUNGEON_PROBE_JSON (.+)$")
			if payload then
				record_count=record_count+1
				local values,kinds=parse_typed_json_object(payload,"dungeon raw record")
				if kinds.tag~="string" then fail("dungeon raw tag type differs") end
				if values.tag=="main_api" then
					if kinds.requested_mapchunks~="integer" or
							values.requested_mapchunks~=summary_values.requested_mapchunks or
							kinds.mg_name~="string" or values.mg_name~=summary_values.mg_name then
						fail("dungeon main scalar settings differ")
					end
					for _,key in ipairs({"chunksize","water_level","mgv7_dungeon_ymin",
						"mgv7_dungeon_ymax"}) do
						if kinds[key]~="string" or parsed_integer(values[key],
							"dungeon main "..key)~=summary_values[key] then
							fail("dungeon main numeric setting differs: "..key)
						end
					end
					require_set_equal(flag_set(values.mg_flags,"raw mg_flags",false),
						summary_mg,"raw/summary mg_flags")
					require_set_equal(flag_set(values.mgv7_spflags,
						"raw mgv7_spflags",true),flag_set(summary_values.mgv7_spflags,
						"summary raw mgv7_spflags",true),"raw/summary mgv7_spflags")
					main_count=main_count+1
				elseif values.tag=="mapgen_api" then
					object_fields(values,{gennotify_type=true,get_data=true,
						get_dungeon_flags=true,get_emerged_area=true,get_flags=true,
						get_node_at=true,get_param2_data=true,get_voxel_flags=true,tag=true},
						"dungeon mapgen_api")
					for _,key in ipairs({"gennotify_type","get_data","get_dungeon_flags",
						"get_emerged_area","get_flags","get_node_at","get_param2_data",
						"get_voxel_flags"}) do
						if kinds[key]~="string" then fail("dungeon mapgen API type differs") end
					end
					mapgen_count=mapgen_count+1
				elseif values.tag=="complete" then
					object_fields(values,{requested_mapchunks=true,tag=true},"dungeon complete")
					if kinds.requested_mapchunks~="integer" or
							values.requested_mapchunks~=summary_values.requested_mapchunks then
						fail("dungeon complete requested-mapchunks differs")
					end
					complete_count=complete_count+1
				elseif values.tag=="dungeon_event" then
					object_fields(values,{blockseed=true,emerged_maxp=true,
						emerged_minp=true,first_room=true,maxp=true,minp=true,
						room_count=true,tag=true},"dungeon event")
					if kinds.blockseed~="integer" or kinds.room_count~="integer" or
							values.room_count<1 or kinds.first_room~="object" then
						fail("dungeon event typed scalar differs")
					end
					local exmax,eymax,ezmax=xyz(values.emerged_maxp,
						"dungeon emerged maxp")
					local exmin,eymin,ezmin=xyz(values.emerged_minp,
						"dungeon emerged minp")
					local maxx,maxy,maxz=xyz(values.maxp,"dungeon central maxp")
					local minx,miny,minz=xyz(values.minp,"dungeon central minp")
					local row={exmax,eymax,ezmax,exmin,eymin,ezmin,
						maxx,maxy,maxz,minx,miny,minz}
				if row[1]~=row[7]+16 or row[2]~=row[8]+16 or row[3]~=row[9]+16 or
						row[4]~=row[10]-16 or row[5]~=row[11]-16 or
						row[6]~=row[12]-16 or row[8]~=-193 or row[11]~=-272 or
						row[7]-row[10]+1~=80 or row[8]-row[11]+1~=80 or
						row[9]-row[12]+1~=80 or row[1]-row[4]+1~=112 or
						row[2]-row[5]+1~=112 or row[3]-row[6]+1~=112 or
						(row[10]+32)%80~=0 or (row[11]+32)%80~=0 or
						(row[12]+32)%80~=0 then
					fail("dungeon emerged/central box relation differs")
				end
				events[#events+1]=row
				if row[4]<union.min_x then union.min_x=row[4] end
				if row[5]<union.min_y then union.min_y=row[5] end
				if row[6]<union.min_z then union.min_z=row[6] end
				if row[1]>union.max_x then union.max_x=row[1] end
				if row[2]>union.max_y then union.max_y=row[2] end
				if row[3]>union.max_z then union.max_z=row[3] end
				else fail("dungeon raw record has unknown tag") end
			end
		end
		if record_count~=summary_values.record_count or main_count~=1 or
				mapgen_count~=1 or complete_count~=summary_values.complete_records or
				#events~=summary_values.positive_callbacks or
				#events~=31 or union.max_y~=-177 or union.min_y~=-288 or
				union.max_y>=AUTHORED_FLOOR then
			fail("finite dungeon event union differs")
		end
		local rows={}
		for index=1,#events do
			local row=events[index]
			local minp=owner_position(row[10],row[11],row[12])
			local maxp=owner_position(row[7],row[8],row[9])
			local plan_digest="not_materialized"
			if verify_plans~=false then
				local plan,_,checked=plan_at(loaded,minp,maxp)
				if plan.run_count~=0 then
					fail("dungeon callback box intersects an authored target")
				end
				plan_digest=digest_hex(raw_sha256,checked.bytes)
			end
			rows[#rows+1]=table.concat({integer_ascii(index,"dungeon event ordinal"),
				integer_ascii(row[10],"dungeon min x"),
				integer_ascii(row[11],"dungeon min y"),
				integer_ascii(row[12],"dungeon min z"),
				integer_ascii(row[7],"dungeon max x"),
				integer_ascii(row[8],"dungeon max y"),
				integer_ascii(row[9],"dungeon max z"),
				plan_digest},"\t").."\n"
		end
		rows[#rows+1]=table.concat({"union",
			integer_ascii(union.min_x,"dungeon union min x"),
			integer_ascii(union.min_y,"dungeon union min y"),
			integer_ascii(union.min_z,"dungeon union min z"),
			integer_ascii(union.max_x,"dungeon union max x"),
			integer_ascii(union.max_y,"dungeon union max y"),
			integer_ascii(union.max_z,"dungeon union max z")},"\t").."\n"
		return canonical_rows(raw_sha256,rows)
	end

	local function dungeon_shard(offline)
		local shard=new_shard("dungeon")
		local loaded=load_r5(offline,"0",dense_fill(6400,HEIGHTMAP_SENTINEL))
		add_digest(shard,"dungeon_oracle",dungeon_corpus_oracle(offline,loaded,
			offline.raw_sha256,true))
		add_proof(shard,"native_dungeons_disjoint",true)
		return shard
	end

	local function snapshot_global_publication()
		local snapshot = {values={}, named={}}
		for key,value in pairs(_G) do snapshot.values[key]=value end
		for _,name in ipairs({"grug_mapgen","grug_core"}) do
			local value=rawget(_G,name)
			local entry={value=value,fields={}}
			if type(value)=="table" then
				for key,field in pairs(value) do entry.fields[key]=field end
			end
			snapshot.named[name]=entry
		end
		return snapshot
	end

	local function require_global_publication_unchanged(snapshot)
		local count_before,count_after=0,0
		for key,value in pairs(snapshot.values) do
			count_before=count_before+1
			if rawget(_G,key)~=value then fail("R5 load changed a global value") end
		end
		for key in pairs(_G) do
			count_after=count_after+1
			if snapshot.values[key]==nil then fail("R5 load published a new global") end
		end
		if count_before~=count_after then fail("R5 load global population differs") end
		for name,entry in pairs(snapshot.named) do
			if rawget(_G,name)~=entry.value then
				fail("R5 load changed named global "..name)
			end
			if type(entry.value)=="table" then
				local before,after=0,0
				for key,value in pairs(entry.fields) do
					before=before+1
					if rawget(entry.value,key)~=value then
						fail("R5 load changed field on "..name)
					end
				end
				for key in pairs(entry.value) do
					after=after+1
					if entry.fields[key]==nil then
						fail("R5 load published field on "..name)
					end
				end
				if before~=after then fail("R5 load named-global fields differ") end
			end
		end
		return count_after
	end

	local function disabled_source_audit(offline)
		local rows={}
		if dense_count(common.R5_OFFLINE_METHODS,"offline method roster",10)~=10 then
			fail("offline method roster population differs")
		end
		local loader_fields={}
		for index=1,#common.R5_OFFLINE_METHODS do
			local name=common.R5_OFFLINE_METHODS[index]
			if type(name)~="string" or name=="" or loader_fields[name] then
				fail("offline method roster differs")
			end
			loader_fields[name]=true
			rows[#rows+1]=table.concat({"loader_method",
				integer_ascii(index,"offline method ordinal"),name},"\t").."\n"
		end
		exact_fields(offline,loader_fields,"offline loader")
		for name in pairs(loader_fields) do
			if type(offline[name])~="function" then fail("offline method is not callable") end
		end
		if offline.loaded()~=false then fail("disabled audit loader was already initialized") end

		local pin_paths=common.MUST_NOT_CHANGE_PATHS
		local pin_digests=common.MUST_NOT_CHANGE_SHA256
		if dense_count(pin_paths,"must-not-change path roster",9)~=9 then
			fail("must-not-change path population differs")
		end
		local pin_fields={}
		for index=1,#pin_paths do
			local path=pin_paths[index]
			if type(path)~="string" or path=="" or pin_fields[path] then
				fail("must-not-change path roster differs")
			end
			pin_fields[path]=true
		end
		exact_fields(pin_digests,pin_fields,"must-not-change digest map")
		for index=1,#pin_paths do
			local path=pin_paths[index]
			local expected=pin_digests[path]
			local bytes=offline.read_bound_input(path)
			local actual=digest_hex(offline.raw_sha256,bytes)
			if actual~=expected then fail("must-not-change current bytes differ") end
			rows[#rows+1]=table.concat({"pin",integer_ascii(index,"pin ordinal"),
				integer_ascii(#path,"pin path byte length")..":"..path,actual},"\t").."\n"
		end

		local current_paths,current_seen={},{}
		for _,roster in ipairs({common.R5_MODIFIED_PARENT_PATHS,
				common.R5_PRODUCTION_PATHS,common.R5_TOOL_PATHS}) do
			local count=dense_count(roster,"current-source path roster",15)
			if count<1 then fail("current-source path roster is empty") end
			for index=1,count do
				local path=roster[index]
				if type(path)~="string" or path=="" then
					fail("current-source path differs")
				end
				if not current_seen[path] then
					current_seen[path]=true
					current_paths[#current_paths+1]=path
				end
			end
		end
		if #current_paths~=15 then fail("current-source exact union differs") end
		local current_bytes={}
		for index=1,#current_paths do
			local path=current_paths[index]
			local bytes=offline.read_current_input(path)
			current_bytes[index]=bytes
			rows[#rows+1]=table.concat({"current",integer_ascii(index,
					"current-source ordinal"),
				integer_ascii(#path,"current-source path byte length")..":"..path,
				digest_hex(offline.raw_sha256,bytes)},"\t").."\n"
		end
		local patterns={
			{"callback_mapgen","core%s*%.%s*register_".."mapgen_script%s*%("},
			{"callback_generated","core%s*%.%s*register_".."on_generated%s*%("},
			{"setting_single","core%s*%.%s*set_".."mapgen_setting%s*%("},
			{"setting_bulk","core%s*%.%s*set_".."mapgen_params%s*%("},
			{"legacy_lbm","core%s*%.%s*register_".."lbm%s*%("},
			{"legacy_vmanip",":%s*write_".."to_map%s*%("},
		}
		for pattern_index=1,#patterns do
			local hits=0
			for source_index=1,#current_bytes do
				local _,count=current_bytes[source_index]:gsub(patterns[pattern_index][2],"")
				hits=hits+count
			end
			if hits~=0 then fail("disabled source contains forbidden call pattern") end
			rows[#rows+1]=table.concat({"forbidden_call",patterns[pattern_index][1],
				integer_ascii(hits,"forbidden call count")},"\t").."\n"
		end

		local globals_before=snapshot_global_publication()
		local public=offline.load_public("0",1)
		exact_fields(public,PUBLIC_LOAD_FIELDS,"disabled public load result")
		if type(public.foundation)~="table" or public.foundation.enabled~=false or
				public.foundation.disabled_reason~=
				"WP40 R4 payload is validated but not published until R7" then
			fail("public disabled loader bytes differ")
		end
		local supplied_manifest=manifest_values()
		if supplied_manifest.emerge_threads~=1 or
				supplied_manifest.engine_emerge_setting~="num_emerge_threads" then
			fail("offline emerge-thread manifest fields differ")
		end
		local content=new_content_contract()
		local context=new_context(dense_fill(6400,HEIGHTMAP_SENTINEL))
		local loaded=offline.load_r5("0",supplied_manifest,content,context)
		exact_fields(loaded,R5_LOAD_FIELDS,"disabled R5 load result")
		local validated=loaded.manifest_module.validate(supplied_manifest)
		local manifest_bytes=loaded.manifest_module.canonical_bytes(validated)
		if not manifest_bytes:find("\nemerge_threads\t1\n",1,true) or
			not manifest_bytes:find("\nengine_emerge_setting\tnum_emerge_threads\n",1,true) then
			fail("validated emerge-thread manifest bytes differ")
		end
		local global_count=require_global_publication_unchanged(globals_before)
		rows[#rows+1]=table.concat({"global_snapshot",
			integer_ascii(global_count,"global key count"),"unchanged"},"\t").."\n"
		rows[#rows+1]=table.concat({"manifest_emerge_threads",
			integer_ascii(supplied_manifest.emerge_threads,"emerge threads"),
			supplied_manifest.engine_emerge_setting,
			digest_hex(offline.raw_sha256,manifest_bytes)},"\t").."\n"
		rows[#rows+1]="public_disabled\t"..
			digest_hex(offline.raw_sha256,public.foundation.disabled_reason).."\n"
		return canonical_rows(offline.raw_sha256,rows)
	end

	local function disabled_shard(offline)
		local shard=new_shard("disabled")
		local audit_digest=disabled_source_audit(offline)
		local manifest=offline.input_manifest()
		exact_fields(manifest,INPUT_MANIFEST_FIELDS,"disabled input manifest")
		if type(offline.verify_input_manifest)~="function" or
				offline.verify_input_manifest()~=true then
			fail("gated input-manifest verification differs")
		end
		add_digest(shard,"disabled_source_audit",audit_digest)
		for _,key in ipairs({"callback_absent","global_publication_absent",
			"settings_mutation_absent","legacy_writer_unchanged",
			"emerge_threads_offline_validated"}) do add_proof(shard,key,true) end
		return shard
	end

	local SHARD_FIELDS={schema=true,fixture_id=true,digests=true,counts=true,
		proofs=true,metrics=true,seed_kats=true}
	local SEED_KAT_FIELDS={ordinal=true,seed=true,historical_sha256=true,
		current_sha256=true}

	local function validate_shard_complete(shard)
		exact_fields(shard,SHARD_FIELDS,"validation shard")
		if shard.schema~=SHARD_SCHEMA or not FIXTURE_RANK[shard.fixture_id] then
			fail("validation shard identity differs")
		end
		validate_key_map(shard.digests,common.DIGEST_FIXTURE_BY_KEY,
			shard.fixture_id,"digest")
		validate_key_map(shard.counts,common.COUNT_FIXTURE_BY_KEY,
			shard.fixture_id,"count")
		validate_key_map(shard.proofs,common.PROOF_FIXTURE_BY_KEY,
			shard.fixture_id,"proof")
		validate_key_map(shard.metrics,common.METRIC_FIXTURES_BY_KEY,
			shard.fixture_id,"metric")
		local seed_count=dense_count(shard.seed_kats,"shard seed KATs",4)
		if shard.fixture_id=="historical_r4" then
			if seed_count~=4 then fail("historical seed-KAT count differs") end
			for ordinal=1,4 do
				local row=shard.seed_kats[ordinal]
				exact_fields(row,SEED_KAT_FIELDS,"seed KAT row")
				if row.ordinal~=ordinal or row.seed~=CANONICAL_SEEDS[ordinal] then
					fail("seed-KAT ordinal/text differs")
				end
				for _,key in ipairs({"historical_sha256","current_sha256"}) do
					if type(row[key])~="string" or #row[key]~=64 or
							not row[key]:match("^[0-9a-f]+$") then
						fail("seed-KAT digest differs")
					end
				end
			end
		elseif seed_count~=0 then fail("non-historical shard carries seed KATs") end
		return true
	end

	function validator.run_shard(offline,fixture_id,progress)
		if progress~=nil and type(progress)~="function" then
			fail("progress callback differs")
		end
		local shard
		if fixture_id=="historical_r4" then shard=historical_shard(offline)
		elseif fixture_id=="seed_0" then shard=seed_zero_shard(offline,progress)
		elseif fixture_id=="worst_fixture" then shard=worst_shard(offline)
		elseif fixture_id=="matrix" then shard=matrix_shard(offline)
		elseif fixture_id=="native_heightmap" then shard=native_heightmap_shard(offline)
		elseif fixture_id=="owner_order" then shard=owner_order_shard(offline)
		elseif fixture_id=="dungeon" then shard=dungeon_shard(offline)
		elseif fixture_id=="disabled" then shard=disabled_shard(offline)
		else fail("unexpected fixture ID") end
		validate_shard_complete(shard)
		return shard
	end

	local RESULT_FIELDS={schema=true,fixture_ids=true,digests=true,counts=true,
		proofs=true,metrics=true,seed_kats=true}

	function validator.merge_shards(shards)
		if dense_count(shards,"validation shards",8)~=8 then
			fail("validation merge requires exactly eight shards")
		end
		local by_fixture={}
		for index=1,8 do
			local shard=shards[index]
			validate_shard_complete(shard)
			if by_fixture[shard.fixture_id] then fail("duplicate validation shard") end
			by_fixture[shard.fixture_id]=shard
		end
		local result={schema=RESULT_SCHEMA,fixture_ids={},digests={},counts={},
			proofs={},metrics={},seed_kats={}}
		for index=1,#FIXTURE_ORDER do
			local fixture_id=FIXTURE_ORDER[index]
			local shard=by_fixture[fixture_id]
			if not shard then fail("missing validation shard "..fixture_id) end
			result.fixture_ids[index]=fixture_id
			result.digests[fixture_id]=shard.digests
			result.counts[fixture_id]=shard.counts
			result.proofs[fixture_id]=shard.proofs
			result.metrics[fixture_id]=shard.metrics
		end
		for ordinal=1,4 do
			local source=by_fixture.historical_r4.seed_kats[ordinal]
			result.seed_kats[ordinal]={ordinal=source.ordinal,seed=source.seed,
				historical_sha256=source.historical_sha256,
				current_sha256=source.current_sha256}
		end
		exact_fields(result,RESULT_FIELDS,"merged validation result")
		return result
	end

	local function micro_points(source)
		local points,seen={},{}
		local function add(x,z,label)
			local key=integer_ascii(x,"micro point x")..":"..
				integer_ascii(z,"micro point z")
			if not seen[key] then
				seen[key]=true
				points[#points+1]={x=x,z=z,label=label}
			end
		end
		add(0,0,"origin")
		for _,index in ipairs({1,#source.anchors}) do
			local p=source.anchors[index].position
			add(p.x,p.z,"anchor")
		end
		local crossing_kind={}
		for index=1,#source.crossing_interfaces do
			local row=source.crossing_interfaces[index]
			if not crossing_kind[row.kind] then
				crossing_kind[row.kind]=true
				add(row.position.x,row.position.z,"crossing_"..row.kind)
			end
		end
		local interface_kind={}
		for index=1,#source.hydrology_interfaces do
			local row=source.hydrology_interfaces[index]
			if not interface_kind[row.kind] then
				interface_kind[row.kind]=true
				add(row.position.x,row.position.z,"interface_"..row.kind)
			end
		end
		local p=source.hydrology[1].centreline[1]
		add(p.x,p.z,"hydrology_shape")
		add(source.extent.min_x-1,source.extent.min_z-1,"exterior")
		table.sort(points,function(a,b)
			if a.x~=b.x then return a.x<b.x end
			if a.z~=b.z then return a.z<b.z end
			return a.label<b.label
		end)
		return points
	end

	local function micro_geometry_receipt(loaded,raw_sha256)
		if AUTHORED_FLOOR~=-37 or OWNER_MIN~=-30912 or OWNER_MAX~=30927 then
			fail("micro owner/floor authority differs")
		end
		local cache,rows={},{"bounds\t-37\t-30912\t30927\n"}
		local function snapshot_runs(x,z,min_y)
			local key=integer_ascii(x,"geometry x")..":"..
				integer_ascii(z,"geometry z")..":"..
				integer_ascii(min_y,"geometry owner y")
			local saved=cache[key]
			if saved then return saved end
			local min_x,min_z=owner_chunk_min(x),owner_chunk_min(z)
			local plan=plan_at(loaded,owner_position(min_x,min_y,min_z),
				owner_position(min_x+79,min_y+79,min_z+79))
			local column=(z-min_z)*80+(x-min_x)+1
			saved={}
			for run=plan.column_start[column],plan.column_start[column+1]-1 do
				local base=(run-1)*RUN_STRIDE
				local feature_ordinal=plan.run_values[base+7]
				local interface_ordinal=plan.run_values[base+8]
				saved[#saved+1]={plan.run_values[base+1],plan.run_values[base+2],
					plan.run_values[base+4],plan.run_values[base+5],
					plan.run_values[base+6],
					feature_ordinal>0 and plan.stable_refs[feature_ordinal] or nil,
					interface_ordinal>0 and plan.stable_refs[interface_ordinal] or nil}
			end
			cache[key]=saved
			return saved
		end
		local function has_exact(x,z,y_min,y_max,opcode,policy,role,feature,interface)
			local first=owner_chunk_min(y_min)
			local last=owner_chunk_min(y_max)
			for slice=first,last,80 do
				local expected_min=math.max(y_min,slice)
				local expected_max=math.min(y_max,slice+79)
				local found=0
				for _,run in ipairs(snapshot_runs(x,z,slice)) do
					if run[1]==expected_min and run[2]==expected_max and
							run[3]==opcode and (policy==nil or run[5]==policy) and
							(role==nil or run[4]==role) and
							(feature==nil or run[6]==feature) and
							(interface==nil or run[7]==interface) then
						found=found+1
					end
				end
				if found~=1 then return false end
			end
			return true
		end
		local function has_opcode(x,z,min_y,opcode)
			for _,run in ipairs(snapshot_runs(x,z,min_y)) do
				if run[3]==opcode then return true end
			end
			return false
		end
		local function clearance(values)
			local result=values[7]
			if result~=nil then return result end
			if values[16]~=nil then result=result and math.max(result,values[16]) or values[16] end
			if values[17]~=nil then result=result and math.max(result,values[17]) or values[17] end
			return result
		end

		local anchor=loaded.source.anchors[1]
		local anchor_route=loaded.source.routes[1]
		if anchor.id~="anchor_001" or anchor_route.id~="route_001" or
				anchor_route.zone_a~=anchor.zone_numeric_id or
				anchor_route.centreline[1].x~=anchor.position.x or
				anchor_route.centreline[1].z~=anchor.position.z then
			fail("hard anchor-path source relation differs")
		end
		local anchor_values=capture20(loaded.planner_source.column_values_at,
			anchor.position.x,anchor.position.z)
		local anchor_fill=has_exact(anchor.position.x,anchor.position.z,
			AUTHORED_FLOOR,anchor_values[6]-1,OPCODE_ID.PATH_FILL,
			POLICY_ID.FILL_VOID,ROLE_ID.PATH_CORE,anchor_route.id)
		local anchor_surface=has_exact(anchor.position.x,anchor.position.z,
			anchor_values[6],anchor_values[6],OPCODE_ID.PATH_SURFACE,
			POLICY_ID.SURFACE_EXACT,ROLE_ID.PATH_SURFACE,anchor_route.id)
		local anchor_clear=has_exact(anchor.position.x,anchor.position.z,
			anchor_values[6]+1,anchor_values[6]+4,OPCODE_ID.PATH_CLEAR,
			POLICY_ID.CUT_NATURAL,ROLE_ID.AIR,anchor_route.id)
		if anchor_values[6]~=9 or anchor_values[10]~="land_grade" or
				anchor_values[11]~=anchor_values[6] or
				anchor_values[12]~=anchor_route.id or anchor_values[13]~=nil or
				anchor_values[20]~=true or
				not (anchor_fill and anchor_surface and anchor_clear) then
			fail("hard anchor-path geometry witness differs")
		end
		rows[#rows+1]="anchor\thard_path\tauthored_floor\n"

		local crossing_by_kind={}
		for index=1,#loaded.source.crossing_interfaces do
			local row=loaded.source.crossing_interfaces[index]
			if not crossing_by_kind[row.kind] then crossing_by_kind[row.kind]=row end
		end
		local kind_to_function={bridge="bridge_deck",ford="ford",
			causeway="causeway",tunnel="tunnel_floor"}
		for _,kind in ipairs({"bridge","ford","causeway","tunnel"}) do
			local crossing=crossing_by_kind[kind]
			if not crossing then fail("micro crossing kind is absent: "..kind) end
			local x,z=crossing.position.x,crossing.position.z
			local values=capture20(loaded.planner_source.column_values_at,x,z)
			if values[10]~=kind_to_function[kind] or values[12]~=crossing.route_id then
				fail("crossing scalar geometry differs: "..kind)
			end
			local f,t,c=values[11],values[6],clearance(values)
			if kind=="bridge" then
				if values[13]~=crossing.id or c==nil or f<c+4 or
						not has_exact(x,z,f-1,f-1,7,5) or
						not has_exact(x,z,f,f,6,6) or
						not has_exact(x,z,f+1,f+4,5,1) then
					fail("named bridge C+4 geometry differs")
				end
				local lower_min=math.max(t+1,c+1)
				if lower_min<=f-2 and not has_exact(x,z,lower_min,f-2,5,4) then
					fail("named bridge lower clearance differs")
				end
			elseif kind=="ford" then
				if values[7]==nil or f~=t or t~=values[7]-1 or
						not has_exact(x,z,t,t,13,6) then
					fail("ford-bed geometry differs")
				end
			elseif kind=="causeway" then
				if values[7]==nil or values[9]==nil then
					fail("causeway culvert geometry differs")
				end
				local id,_,numerator,denominator=
					loaded.planner_source.hydrology_metric_values_at(x,z)
				local bed=values[7]-values[9]
				if f~=t or id~=values[8] or
						numerator>denominator or
						not has_exact(x,z,bed+1,values[7],8,7) or
						not has_exact(x,z,t,t,10,6) or
						not has_exact(x,z,t+1,t+4,20,1) then
					fail("causeway culvert geometry differs")
				end
			elseif kind=="tunnel" then
				if values[13]~=crossing.id or
						not has_exact(x,z,f,f,29,6) or
						not has_exact(x,z,f+1,f+4,30,4) or
						not has_exact(x,z,f+5,f+5,31,5) then
					fail("tunnel floor/lumen/roof geometry differs")
				end
			end
			rows[#rows+1]="crossing\t"..kind.."\tclosed_geometry\n"
		end
		local graded_ford_x,graded_ford_z=-1128,250
		local graded_ford_values=capture20(
			loaded.planner_source.column_values_at,graded_ford_x,graded_ford_z)
		if graded_ford_values[6]~=9 or graded_ford_values[7]~=9 or
				graded_ford_values[10]~="ford" or graded_ford_values[11]~=9 or
				graded_ford_values[12]~="route_050" or
				graded_ford_values[13]~="broken_ford" or
				graded_ford_values[6]==graded_ford_values[7]-1 or
				not has_exact(graded_ford_x,graded_ford_z,9,9,13,6,6,
					"route_050","broken_ford") then
			fail("graded ford approach geometry differs")
		end
		rows[#rows+1]="ford\tgraded_approach\tT_equals_W\n"
		local cardinal_gap_x,cardinal_gap_z=2050,1964
		local cardinal_gap_values=capture20(
			loaded.planner_source.column_values_at,cardinal_gap_x,cardinal_gap_z)
		if cardinal_gap_values[6]~=33 or cardinal_gap_values[7]~=nil or
				cardinal_gap_values[14]~="waterfall" or
				cardinal_gap_values[15]~="raincall_lower_fall" or
				cardinal_gap_values[16]~=53 or cardinal_gap_values[17]~=45 or
				cardinal_gap_values[18]~=65536 or cardinal_gap_values[19]~=nil then
			fail("cardinal-waterfall surface-cap tuple differs")
		end
		local cardinal_gap_runs=snapshot_runs(cardinal_gap_x,cardinal_gap_z,48)
		local gap_covering,clear_run=0,0
		for _,run in ipairs(cardinal_gap_runs) do
			if run[1]<=53 and run[2]>=53 then gap_covering=gap_covering+1 end
			if run[1]==54 and run[2]==127 and run[3]==26 and run[4]==1 and
					run[5]==1 and run[6]==nil and run[7]==nil then
				clear_run=clear_run+1
			end
		end
		if gap_covering~=0 or clear_run~=1 then
			fail("cardinal-waterfall surface-cap plan gap differs")
		end
		rows[#rows+1]="waterfall\tcardinal_surface_cap_gap\t53_absent_54_clear\n"
		local derived_bridge={x=1962,z=2130}
		derived_bridge.values=capture20(loaded.planner_source.column_values_at,
			derived_bridge.x,derived_bridge.z)
		derived_bridge.clearance=clearance(derived_bridge.values)
		local support_count,deck_count,upper_clear_count,lower_clear_count=0,0,0,0
		for _,run in ipairs(snapshot_runs(derived_bridge.x,derived_bridge.z,48)) do
			if run[1]==72 and run[2]==72 and
					run[3]==OPCODE_ID.BRIDGE_SUPPORT and
					run[4]==ROLE_ID.BRIDGE_SUPPORT and
					run[5]==POLICY_ID.SEAL_VOID and run[6]=="route_016" and
					run[7]==nil then
				support_count=support_count+1
			elseif run[1]==73 and run[2]==73 and
					run[3]==OPCODE_ID.BRIDGE_DECK and run[4]==ROLE_ID.BRIDGE_DECK and
					run[5]==POLICY_ID.SURFACE_EXACT and run[6]=="route_016" and
					run[7]==nil then
				deck_count=deck_count+1
			elseif run[1]==74 and run[2]==77 and
					run[3]==OPCODE_ID.BRIDGE_CLEAR and run[4]==ROLE_ID.AIR and
					run[5]==POLICY_ID.CUT_NATURAL and run[6]=="route_016" and
					run[7]==nil then
				upper_clear_count=upper_clear_count+1
			end
			if run[3]==OPCODE_ID.BRIDGE_CLEAR and run[6]=="route_016" and
					run[7]==nil and run[2]<=71 then
				lower_clear_count=lower_clear_count+1
			end
		end
		if derived_bridge.values[10]~="bridge_deck" or
				derived_bridge.values[12]~="route_016" or
				derived_bridge.values[13]~=nil or derived_bridge.clearance~=71 or
				derived_bridge.values[11]~=73 or support_count~=1 or deck_count~=1 or
				upper_clear_count~=1 or lower_clear_count~=0 then
			fail("derived bridge C+2 support geometry differs")
		end
		for _,run in ipairs(snapshot_runs(derived_bridge.x,derived_bridge.z,
				owner_chunk_min(derived_bridge.values[11]))) do
			if run[3]==5 and run[1]<=derived_bridge.values[11]-2 then
				fail("derived bridge emitted lower clearance")
			end
		end
		rows[#rows+1]="bridge\tderived_C_plus_2\tnamed_C_plus_4\n"

		local roofed_x,roofed_z=-1916,-2071
		local roofed_values=capture20(loaded.planner_source.column_values_at,
			roofed_x,roofed_z)
		local roofed_clearance=clearance(roofed_values)
		local roofed_cap=roofed_clearance and
			math.max(roofed_values[6],roofed_clearance) or roofed_values[6]
		if roofed_values[6]~=61 or roofed_values[7]~=19 or
				roofed_clearance~=19 or roofed_values[10]~="bridge_deck" or
				roofed_values[11]~=39 or roofed_values[12]~="poi_spur_025" or
				roofed_values[13]~=nil or roofed_cap~=61 or roofed_cap<44 or
				not has_exact(roofed_x,roofed_z,40,43,
					OPCODE_ID.BRIDGE_CLEAR,POLICY_TOKEN_ID.CUT_NATURAL) then
			fail("roofed derived bridge headroom geometry differs")
		end
		rows[#rows+1]="bridge\troofed_headroom\t-1916\t-2071\t40\t43\n"

		local function relation_members(row)
			local members={}
			if row.kind=="rapid" or row.kind=="waterfall" then
				members[row.upper_id]=true
				members[row.lower_id]=true
			elseif row.kind=="confluence" then
				for index=1,#row.from_ids do members[row.from_ids[index]]=true end
				members[row.outgoing_reach_id]=true
			end
			return members
		end
		local accepted_relations={}
		for index=1,#loaded.source.hydrology_interfaces do
			local row=loaded.source.hydrology_interfaces[index]
			if row.kind=="confluence" or row.kind=="rapid" or
					row.kind=="waterfall" then
				accepted_relations[#accepted_relations+1]={row=row,
					members=relation_members(row)}
			end
		end
		local function resolve_bank_compatibility(ids,surfaces)
			if #ids<1 or #ids~=#surfaces then
				fail("micro bank compatibility fixture differs")
			end
			local first_id,first_surface=ids[1],surfaces[1]
			local all_same_id,all_same_surface=true,true
			for index=2,#ids do
				if ids[index]~=first_id then all_same_id=false end
				if surfaces[index]~=first_surface then all_same_surface=false end
			end
			if all_same_id then return nil,true,"one_id" end
			local selected
			for index=1,#accepted_relations do
				local relation=accepted_relations[index]
				local compatible=true
				for member=1,#ids do
					if not relation.members[ids[member]] then compatible=false end
				end
				if compatible and (selected==nil or
						relation.row.id<selected.row.id) then selected=relation end
			end
			if selected then return selected.row.id,true,"accepted_relation" end
			if all_same_surface then return nil,true,"equal_surface_fallback" end
			return nil,false,"unequal_unrelated"
		end
		local related=accepted_relations[1]
		if not related then fail("micro accepted bank relation roster is empty") end
		local related_ids={}
		for index=1,#loaded.source.hydrology do
			local id=loaded.source.hydrology[index].id
			if related.members[id] then related_ids[#related_ids+1]=id end
		end
		if #related_ids<2 then fail("micro accepted bank relation members differ") end
		local equal_relation,equal_ok,equal_kind=resolve_bank_compatibility(
			{related_ids[1],related_ids[2]},{17,17})
		local unequal_relation,unequal_ok,unequal_kind=resolve_bank_compatibility(
			{related_ids[1],related_ids[2]},{17,18})
		if not equal_ok or not unequal_ok or type(equal_relation)~="string" or
				unequal_relation~=equal_relation or
				equal_kind~="accepted_relation" or unequal_kind~="accepted_relation" then
			fail("micro accepted bank relation precedence differs")
		end
		local unrelated_left,unrelated_right
		for left=1,#loaded.source.hydrology do
			for right=left+1,#loaded.source.hydrology do
				local left_id=loaded.source.hydrology[left].id
				local right_id=loaded.source.hydrology[right].id
				local _,compatible=resolve_bank_compatibility(
					{left_id,right_id},{17,18})
				if not compatible then
					unrelated_left,unrelated_right=left_id,right_id
					break
				end
			end
			if unrelated_left then break end
		end
		if not unrelated_left then fail("micro unrelated bank pair is absent") end
		local unrelated_relation,unrelated_ok,unrelated_kind=
			resolve_bank_compatibility({unrelated_left,unrelated_right},{17,18})
		if unrelated_relation~=nil or unrelated_ok or
				unrelated_kind~="unequal_unrelated" then
			fail("micro unequal unrelated bank did not reject")
		end
		rows[#rows+1]="bank_relation\tindependent_oracle_equal_related\t"..
			equal_relation.."\n"
		rows[#rows+1]="bank_relation\tindependent_oracle_unequal_related\t"..
			unequal_relation.."\n"
		rows[#rows+1]="bank_relation\tindependent_oracle_unequal_unrelated_reject\t"..
			unrelated_left.."\t"..unrelated_right.."\n"

		local bank_x,bank_z=-456,-1490
		local bank_values=capture20(loaded.planner_source.column_values_at,
			bank_x,bank_z)
		if bank_values[8]~=nil or bank_values[14]=="waterfall" then
			fail("equal-surface mixed bank centre is named wet")
		end
		local wet_samples,main_samples,ford_samples=0,0,0
		local expected_wet={
			["0:-2"]="hydro_whitebridge_main",
			["1:-1"]="hydro_whitebridge_main",
			["0:2"]="hydro_whitebridge_ford",
		}
		for dx=-2,2 do
			for dz=-2,2 do
				local distance=math.abs(dx)+math.abs(dz)
				if distance>=1 and distance<=2 then
					local values=capture20(loaded.planner_source.column_values_at,
						bank_x+dx,bank_z+dz)
					local expected=expected_wet[integer_ascii(dx,"bank sample dx")..":"..
						integer_ascii(dz,"bank sample dz")]
					if expected then
						local expected_depth=expected=="hydro_whitebridge_main" and 4 or 1
						if values[7]~=17 or values[8]~=expected or
								values[9]~=expected_depth or values[14]=="waterfall" then
							fail("equal-surface mixed bank wet sample differs")
						end
						wet_samples=wet_samples+1
						if expected=="hydro_whitebridge_main" then
							main_samples=main_samples+1
						else ford_samples=ford_samples+1 end
					elseif values[8]~=nil or
							(values[14]=="waterfall" and values[19]~=nil) then
						fail("equal-surface mixed bank dry sample differs")
					end
				end
			end
		end
		local raw_high=math.min(bank_values[6],17)
		local selected_bank_run
		for _,run in ipairs(snapshot_runs(bank_x,bank_z,owner_chunk_min(11))) do
			if run[3]==OPCODE_ID.HYDROLOGY_BANK_SEAL and
					run[5]==POLICY_TOKEN_ID.SEAL_VOID and
					run[6]=="hydro_whitebridge_ford" then
				if run[7]~=nil or run[1]<11 or run[2]>raw_high then
					fail("equal-surface mixed bank resolved seal differs")
				end
				if selected_bank_run==nil or run[1]<selected_bank_run[1] then
					selected_bank_run=run
				end
			end
		end
		if wet_samples~=3 or main_samples~=2 or ford_samples~=1 or
				raw_high<11 or selected_bank_run==nil or
				selected_bank_run[4]~=ROLE_ID.HYDROLOGY_SEAL then
			fail("equal-surface mixed bank production plan witness differs")
		end
		rows[#rows+1]="bank\tproduction_equal_surface_fallback\t-456\t-1490\t"..
			integer_ascii(selected_bank_run[1],"bank resolved y min").."\t"..
			integer_ascii(selected_bank_run[2],"bank resolved y max")..
			"\thydro_whitebridge_ford\tnil_interface\n"

		local causeway=crossing_by_kind.causeway
		local culvert_point,nonculvert_point
		for dz=-12,12 do
			for dx=-12,12 do
				local x,z=causeway.position.x+dx,causeway.position.z+dz
				local values=capture20(loaded.planner_source.column_values_at,x,z)
				if values[10]=="causeway" and values[12]==causeway.route_id and
						values[7]~=nil and values[9]~=nil then
					local id,_,numerator,denominator=
						loaded.planner_source.hydrology_metric_values_at(x,z)
					local is_culvert=id==values[8] and numerator<=denominator
					if is_culvert and not culvert_point then
						culvert_point={x=x,z=z,min_y=owner_chunk_min(values[7]-values[9])}
					elseif id==values[8] and numerator>denominator and
							not nonculvert_point then
						nonculvert_point={x=x,z=z,
							min_y=owner_chunk_min(values[7]-values[9])}
					end
				end
			end
		end
		if not culvert_point or not nonculvert_point or
				not has_opcode(culvert_point.x,culvert_point.z,culvert_point.min_y,8) or
				has_opcode(nonculvert_point.x,nonculvert_point.z,
					nonculvert_point.min_y,8) then
			fail("culvert exact radius boundary witness differs")
		end
		rows[#rows+1]="culvert\tradius_one\tinside_and_outside\n"

		local tunnel=crossing_by_kind.tunnel
		local portal_x,portal_z=-2011,-118
		local portal_values=capture20(loaded.planner_source.column_values_at,
			portal_x,portal_z)
		local portal_neighbour=capture20(loaded.planner_source.column_values_at,
			portal_x,portal_z+1)
		local lateral_x,lateral_z=-2010,-118
		local lateral_values=capture20(loaded.planner_source.column_values_at,
			lateral_x,lateral_z)
		local lateral_neighbour=capture20(loaded.planner_source.column_values_at,
			lateral_x,lateral_z+1)
		if tunnel.id~="gravesalt_tomb_tunnel" or tunnel.route_id~="route_043" or
				portal_values[6]~=101 or portal_values[10]~="land_grade" or
				portal_values[11]~=101 or portal_values[12]~=tunnel.route_id or
				portal_values[13]~=nil or portal_neighbour[10]~="tunnel_floor" or
				portal_neighbour[11]~=101 or portal_neighbour[12]~=tunnel.route_id or
				portal_neighbour[13]~=tunnel.id or
				has_opcode(portal_x,portal_z,48,OPCODE_ID.TUNNEL_WALL) or
				not has_exact(portal_x,portal_z,101,101,OPCODE_ID.PATH_SURFACE,
					POLICY_ID.SURFACE_EXACT,ROLE_ID.PATH_SURFACE,tunnel.route_id) or
				not has_exact(portal_x,portal_z,102,105,OPCODE_ID.PATH_CLEAR,
					POLICY_ID.CUT_NATURAL,ROLE_ID.AIR,tunnel.route_id) or
				lateral_values[10]~="land_grade" or
				lateral_values[11]~=lateral_values[6] or
				lateral_values[12]~=tunnel.route_id or lateral_values[13]~=nil or
				lateral_neighbour[10]~="tunnel_floor" or
				lateral_neighbour[11]~=101 or
				lateral_neighbour[12]~=tunnel.route_id or
				lateral_neighbour[13]~=tunnel.id or
				has_opcode(lateral_x,lateral_z,
					owner_chunk_min(lateral_values[11]),OPCODE_ID.TUNNEL_WALL) or
				not has_exact(lateral_x,lateral_z,lateral_values[11],lateral_values[11],
					OPCODE_ID.PATH_SURFACE,POLICY_ID.SURFACE_EXACT,
					ROLE_ID.PATH_SURFACE,tunnel.route_id) or
				not has_exact(lateral_x,lateral_z,lateral_values[11]+1,
					lateral_values[11]+4,OPCODE_ID.PATH_CLEAR,
					POLICY_ID.CUT_NATURAL,ROLE_ID.AIR,tunnel.route_id) then
			fail("tunnel corridor/portal zero-wall witness differs")
		end
		rows[#rows+1]="tunnel\tzero_real_walls\tportal_and_lateral_corridor\n"

		local hydrology_by_id,profile_by_id={},{}
		for index=1,#loaded.source.hydrology do
			hydrology_by_id[loaded.source.hydrology[index].id]=loaded.source.hydrology[index]
		end
		for index=1,#loaded.source.hydrology_profiles do
			profile_by_id[loaded.source.hydrology_profiles[index].id]=
				loaded.source.hydrology_profiles[index]
		end
		local rapid,cardinal,contact
		for index=1,#loaded.source.hydrology_interfaces do
			local row=loaded.source.hydrology_interfaces[index]
			if row.kind=="rapid" and not rapid then rapid=row end
			if row.kind=="waterfall" then
				if row.transition_scope_id==nil and not cardinal then cardinal=row end
				if row.transition_scope_id~=nil and not contact then contact=row end
			end
		end
		if not rapid or not cardinal or not contact then
			fail("transition witness roster differs")
		end
		local rapid_values=capture20(loaded.planner_source.column_values_at,
			rapid.position.x,rapid.position.z)
		if rapid_values[14]~="rapid" or rapid_values[7]==nil or
				rapid_values[18]==nil or rapid_values[19]~=nil then
			fail("rapid transition scalar differs")
		end
		local cardinal_values=capture20(loaded.planner_source.column_values_at,
			cardinal.position.x,cardinal.position.z)
		if cardinal_values[14]~="waterfall" or cardinal_values[7]~=nil or
				cardinal_values[18]==nil or cardinal_values[19]~=nil then
			fail("cardinal waterfall scalar differs")
		end
		local cardinal_y=owner_chunk_min(math.min(cardinal_values[16],cardinal_values[17]))
		if has_opcode(cardinal.position.x,cardinal.position.z,cardinal_y,11) or
				has_opcode(cardinal.position.x,cardinal.position.z,cardinal_y,23) or
				has_opcode(cardinal.position.x,cardinal.position.z,cardinal_y,25) then
			fail("cardinal waterfall authored falling-water operation")
		end
		local contact_x,contact_z=-106,-1757
		local contact_values=capture20(loaded.planner_source.column_values_at,
			contact_x,contact_z)
		if contact.id~="highcourt_goldmead_fall" or
				contact.upper_id~="hydro_highcourt_fork_west" or
				contact.lower_id~="hydro_goldmead_millriver" or
				contact.transition_scope_id~="orthogonal_reach_contact_face_v1" or
				contact_values[6]~=13 or contact_values[7]~=nil or
				contact_values[8]~=contact.lower_id or contact_values[9]~=4 or
				contact_values[14]~="waterfall" or contact_values[15]~=contact.id or
				contact_values[16]~=35 or contact_values[17]~=17 or
				contact_values[18]~=nil or contact_values[19]~=8 then
			fail("contact waterfall scalar differs")
		end
		local lower=contact_values[17]
		local lower_hydrology=hydrology_by_id[contact.lower_id]
		local lower_profile=lower_hydrology and profile_by_id[lower_hydrology.profile_id]
		if not lower_profile or lower_profile.id~="river" or lower_profile.depth~=4 then
			fail("contact lower profile differs")
		end
		local bed=lower-lower_profile.depth
		if not has_exact(contact_x,contact_z,bed+1,lower-1,
				OPCODE_ID.RIVER_WATER,POLICY_ID.WRITE_WATER,
				ROLE_ID.RIVER_WATER_SOURCE,contact.lower_id,contact.id) or
				not has_exact(contact_x,contact_z,lower,lower,
					OPCODE_ID.RECEIVER_OPEN,POLICY_ID.OPEN_ENGINEERED,
					ROLE_ID.AIR,contact.lower_id,contact.id) then
			fail("contact receiver/source-omission geometry differs")
		end
		local contact_slice=owner_chunk_min(lower+1)
		if not has_exact(contact_x,contact_z,lower+1,contact_slice+79,
				OPCODE_ID.CONTACT_FALL_CLEAR,POLICY_ID.OPEN_ENGINEERED,
				ROLE_ID.AIR,contact.lower_id,contact.id) then
			fail("contact fall-clear owner clipping differs")
		end
		rows[#rows+1]="transition\trapid\tcardinal_waterfall\tcontact_waterfall\n"

		local wet=loaded.source.hydrology[1]
		local wet_point=wet.centreline[1]
		local wet_values=capture20(loaded.planner_source.column_values_at,
			wet_point.x,wet_point.z)
		local wet_bed=wet_values[7] and wet_values[7]-wet_values[9]
		if wet_values[8]~=wet.id or wet_bed==nil or
				not has_exact(wet_point.x,wet_point.z,wet_bed-2,wet_bed,18,5) then
			fail("hydrology bed-seal geometry differs")
		end
		local bank=false
		for distance=1,128 do
			for _,offset in ipairs({{distance,0},{-distance,0},{0,distance},{0,-distance}}) do
				local x,z=wet_point.x+offset[1],wet_point.z+offset[2]
				local values=capture20(loaded.planner_source.column_values_at,x,z)
				local wet_neighbour=false
				if values[8]==nil then
					for _,near in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-2,0},{2,0},
						{0,-2},{0,2},{-1,-1},{-1,1},{1,-1},{1,1}}) do
						local sample=capture20(loaded.planner_source.column_values_at,
							x+near[1],z+near[2])
						if sample[8]~=nil then wet_neighbour=true break end
					end
				end
				if wet_neighbour and has_opcode(x,z,owner_chunk_min(wet_bed),17) then
					bank=true break
				end
			end
			if bank then break end
		end
		if not bank then fail("hydrology bank-seal geometry differs") end
		rows[#rows+1]="hydrology\tbed_three\tbank_manhattan_two\n"

		local continuation_values=capture20(loaded.planner_source.column_values_at,0,0)
		local cap=math.max(continuation_values[6],continuation_values[7] or
			continuation_values[6])
		local first_slice=owner_chunk_min(cap+1)+80
		if first_slice+159>OWNER_MAX or
				not has_exact(0,0,first_slice,first_slice+79,26,1) or
				not has_exact(0,0,first_slice+80,first_slice+159,26,1) then
			fail("analytic vertical continuation witness differs")
		end
		rows[#rows+1]="continuation\tadjacent_owner_slices\tTERRAIN_CLEAR\n"
		for _,edge in ipairs({{"lower",OWNER_MIN,OWNER_MIN},
			{"upper",OWNER_MAX,OWNER_MAX},{"below_floor_owner",-112,-33},
			{"first_authored",AUTHORED_FLOOR,AUTHORED_FLOOR+79}}) do
			local plan,generation=plan_at(loaded,
				owner_position(-32,edge[2],-32),owner_position(47,edge[3],47))
			for run=1,plan.run_count do
				local base=(run-1)*RUN_STRIDE
				if plan.run_values[base+1]<AUTHORED_FLOOR or
						plan.run_values[base+2]>edge[3] then
					fail("edge/floor plan clipping differs")
				end
			end
			if edge[1]=="lower" and plan.run_count~=0 then
				fail("lower owner edge emitted below-floor operation")
			end
			rows[#rows+1]="edge\t"..edge[1].."\t"..
				integer_ascii(plan.run_count,"edge run count").."\n"
		end
		return canonical_rows(raw_sha256,rows)
	end

	local MICRO_FIELDS={schema=true,rows=true,coverage=true,canonical_bytes=true,
		sha256=true}
	local MICRO_ROW_FIELDS={tag=true,fields=true}

	function validator.validate_micro_kat_coverage(result)
		exact_fields(result,MICRO_FIELDS,"micro KAT")
		if result.schema~=MICRO_SCHEMA then fail("micro KAT schema differs") end
		if type(result.coverage)~="table" or
				getmetatable(result.coverage)~=nil then
			fail("micro KAT coverage is not a plain map")
		end
		local row_count=dense_count(result.rows,"micro KAT rows")
		if row_count<=#REQUIRED_MICRO_FAMILIES then
			fail("micro KAT rows are empty")
		end
		for index=1,row_count do
			local row=result.rows[index]
			exact_fields(row,MICRO_ROW_FIELDS,"micro KAT canonical row")
			if type(row.tag)~="string" or row.tag=="" or
					dense_count(row.fields,"micro KAT canonical fields")<1 then
				fail("micro KAT canonical row differs")
			end
		end
		local expected={}
		for index=1,#REQUIRED_MICRO_FAMILIES do
			expected[REQUIRED_MICRO_FAMILIES[index]]=true
		end
		for family,value in pairs(result.coverage) do
			if not expected[family] or value~=true then
				fail("micro KAT coverage has unexpected/nontrue family")
			end
			expected[family]=nil
		end
		for family in pairs(expected) do fail("micro KAT coverage missing "..family) end
		local witness_by_family,witness_ids,receipt_seen={},{},{}
		for index=1,row_count-#REQUIRED_MICRO_FAMILIES do
			local row=result.rows[index]
			if row.tag=="witness" then
				if #row.fields~=2 or type(row.fields[1])~="string" or
						type(row.fields[2])~="string" or row.fields[2]=="" or
						witness_by_family[row.fields[1]]~=nil then
					fail("micro KAT witness row differs")
				end
				witness_by_family[row.fields[1]]=row.fields[2]
				witness_ids[row.fields[2]]=true
			elseif row.tag~="coverage" then
				if not MICRO_RECEIPT_TAGS[row.tag] or receipt_seen[row.tag] then
					fail("micro KAT receipt ID set differs")
				end
				receipt_seen[row.tag]=true
			end
		end
		for receipt_id in pairs(MICRO_RECEIPT_TAGS) do
			if not receipt_seen[receipt_id] then
				fail("micro KAT receipt is missing: "..receipt_id)
			end
		end
		local witness_count=0
		for _ in pairs(witness_ids) do witness_count=witness_count+1 end
		if witness_count<1 or witness_count>16 then
			fail("micro KAT witness count exceeds compact bound")
		end
		for index=1,#REQUIRED_MICRO_FAMILIES do
			local family=REQUIRED_MICRO_FAMILIES[index]
			local receipt_id=MICRO_RECEIPT_BY_FAMILY[family]
			if witness_by_family[family]~=receipt_id or not receipt_seen[receipt_id] or
					result.coverage[family]~=true then
				fail("micro KAT coverage lacks constructed witness: "..family)
			end
		end
		for index=1,#REQUIRED_MICRO_FAMILIES do
			local row=result.rows[row_count-#REQUIRED_MICRO_FAMILIES+index]
			if type(row)~="table" or row.tag~="coverage" or
					getmetatable(row)~=nil or type(row.fields)~="table" or
					getmetatable(row.fields)~=nil or #row.fields~=2 or
					row.fields[1]~=REQUIRED_MICRO_FAMILIES[index] or
					row.fields[2]~="true" then
				fail("micro KAT coverage row differs")
			end
		end
		if common.render_canonical_rows(result.rows)~=result.canonical_bytes then
			fail("micro KAT canonical bytes differ")
		end
		if type(result.sha256)~="string" or #result.sha256~=64 or
				not result.sha256:match("^[0-9a-f]+$") then
			fail("micro KAT digest scalar differs")
		end
		return true
	end

	function validator.micro_kat(offline)
		local public=offline.load_public("0",1)
		exact_fields(public,PUBLIC_LOAD_FIELDS,"micro public R4 load result")
		local heightmap=dense_fill(6400,HEIGHTMAP_SENTINEL)
		local loaded=load_r5(offline,"0",heightmap,
			{exact_param2=true,canopy_light=true,canopy_sunlight=true,
				missing_role=ROLE_ID.STRATUM_AT_Y,missing_y=OWNER_MAX,missing_aux=0,
				ignore_role=ROLE_ID.BRIDGE_DECK,ignore_y=OWNER_MAX,ignore_aux=0},true)
		local initial_planner_metrics=loaded.planner:metrics()
		local initial_adapter_metrics=loaded.adapter:metrics()
		local public_bytes=public.session.canonical_kat()
		if public_bytes~=loaded.session.canonical_kat() or
				public.private_session.canonical_kat()~=loaded.session.canonical_kat() or
				type(public.foundation)~="table" or public.foundation.enabled~=false or
				public.foundation.disabled_reason~=
					"WP40 R4 payload is validated but not published until R7" or
				digest_hex(offline.raw_sha256,public_bytes)~=
				common.R4_SEED_0_KAT_SHA256 then
			fail("micro public/private/historical R4 parity differs")
		end
		local points=micro_points(loaded.source)
		if #points<1 or #points>16 then fail("micro semantic witness bound differs") end
		local scalar_rows=scalar_seam_rows(loaded,points)
		local rows={
			common.canonical_row("public_r4",loaded.session.canonical_kat_digest()),
			common.canonical_row("planner_source",
				canonical_rows(offline.raw_sha256,scalar_rows)),
		}
		local geometry_digest=micro_geometry_receipt(loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("geometry",geometry_digest)

		local replace_digest,replace_count=replacement_matrix_digest(loaded,
			offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("replace",replace_digest,
			integer_ascii(replace_count,"replacement population"))
		local isolated_digest,isolated_applies,isolated_vms=
			actual_adapter_call_matrix(loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("actual_adapter",isolated_digest,
			integer_ascii(isolated_applies,"isolated apply attempts"),
			integer_ascii(isolated_vms,"isolated VM fixtures"))
		local light_digest,light_applies,light_vms=
			actual_light_matrix(loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("actual_light",light_digest,
			integer_ascii(light_applies,"light apply attempts"),
			integer_ascii(light_vms,"light VM fixtures"))
		local relation_digest,relation_variants,relation_applies,relation_vms=
			planner_adapter_relation_kat(
			loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("planner_adapter_relation",
			relation_digest,integer_ascii(relation_variants,"relation variants"))
		rows[#rows+1]=common.canonical_row("seal_totality",geometry_digest,
			replace_digest,relation_digest,"tunnel_roof_wall_bed_bank")
		local conflict_receipt,conflict_calls=micro_conflict_receipt(loaded,
			offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("conflict",conflict_receipt,
			integer_ascii(conflict_calls,"conflict fixture calls"))
		local liquid_digest,_,liquid_applies,liquid_vms=
			liquid_face_matrix(loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("liquid_faces",liquid_digest,
			integer_ascii(liquid_applies,"liquid apply attempts"),
			integer_ascii(liquid_vms,"liquid VM fixtures"))
		rows[#rows+1]=common.canonical_row("dirty_light_liquid",isolated_digest,
			light_digest,liquid_digest)
		local ignore_digest,ignore_applies,ignore_vms=
			micro_ignore_matrix(offline,loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("ignore",ignore_digest,
			integer_ascii(ignore_applies,"ignore apply attempts"),
			integer_ascii(ignore_vms,"ignore VM fixtures"))
		local heightmap_digest,heightmap_plan_digest,native_position_digest,
			native_applies,native_vms=
			micro_native_heightmap(loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("heightmap",heightmap_digest,
			heightmap_plan_digest,native_position_digest)
		local generation_order=owner_order_corpus(offline,offline.raw_sha256,loaded)
		local owner=compact_owner_order_corpus(loaded,offline.raw_sha256)
		rows[#rows+1]=common.canonical_row("owner_order",
			generation_order.ascending,generation_order.descending,
			generation_order.permuted,owner.horizontal,owner.vertical,owner.all,
			integer_ascii(owner.apply_attempts,"owner apply attempts"),
			integer_ascii(owner.vm_fixtures,"owner VM fixtures"))
		rows[#rows+1]=common.canonical_row("dungeon",
			dungeon_corpus_oracle(offline,loaded,offline.raw_sha256,false))

		local planner_allocator=loaded.allocators[1]
		local allocator_copy={}
		for key,value in pairs(planner_allocator) do allocator_copy[key]=value end
		if loaded.allocator_factory.new("grug_wp40_r5_planner_allocator_v1",
			planner_allocator)~=true or
				loaded.allocator_factory.new("grug_wp40_r5_planner_allocator_v1",
					allocator_copy)~=false then
			fail("copied allocator provenance rejection differs")
		end
		local foreign_allocator={}
		for key in pairs(planner_allocator) do
			foreign_allocator[key]=function() end
		end
		if loaded.allocator_factory.new("grug_wp40_r5_planner_allocator_v1",
				foreign_allocator)~=false then
			fail("foreign allocator provenance rejection differs")
		end
		if loaded.allocator_factory.new("grug_wp40_r5_planner_allocator_v1",
				loaded.allocators[2])~=false then
			fail("wrong-domain allocator provenance rejection differs")
		end
		rows[#rows+1]=common.canonical_row("allocator_provenance","valid_true",
			"copy_false","foreign_false","wrong_domain_false")
		local current_plan,current_generation=plan_at(loaded,
			owner_position(-32,AUTHORED_FLOOR,-32),owner_position(47,AUTHORED_FLOOR,47))
		local expected_refs=expected_stable_refs(loaded.source)
		if not exact_equal(current_plan.stable_refs,expected_refs) then
			fail("micro plan stable-reference union differs")
		end
		local stable_ordinal={}
		for index=1,#current_plan.stable_refs do
			stable_ordinal[current_plan.stable_refs[index]]=index
		end
		local grade_ref_rows,grade_ref_seen={},{}
		local grade_ref_count=0
		for _,family in ipairs({loaded.source.island_landings,
				loaded.source.coastal_housing_cores}) do
			if dense_count(family,"micro grade stable-reference family")~=4 then
				fail("micro grade stable-reference family count differs")
			end
			for index=1,4 do
				local id=family[index].id
				local ordinal=stable_ordinal[id]
				if type(id)~="string" or id=="" or grade_ref_seen[id] or
						type(ordinal)~="number" then
					fail("micro grade stable reference differs")
				end
				grade_ref_seen[id]=true
				grade_ref_count=grade_ref_count+1
				grade_ref_rows[#grade_ref_rows+1]=integer_ascii(#id,
					"micro grade stable ID length")..":"..id.."\t"..
					integer_ascii(ordinal,"micro grade stable ordinal").."\n"
			end
		end
		if grade_ref_count~=8 then fail("micro grade stable-reference count differs") end
		table.sort(grade_ref_rows)
		local grade_ref_digest=canonical_rows(offline.raw_sha256,grade_ref_rows)
		expect_error("fail_stale_plan",function()
			loaded.adapter:apply(nil,owner_position(-32,AUTHORED_FLOOR,-32),
				owner_position(47,AUTHORED_FLOOR,47),current_plan,current_generation-1,
				"offline_fixture")
		end,"micro stale plan")
		local foreign_plan={}
		for key,value in pairs(current_plan) do foreign_plan[key]=value end
		foreign_plan.construction_identity={}
		expect_error("fail_plan",function()
			loaded.adapter:apply(nil,owner_position(-32,AUTHORED_FLOOR,-32),
				owner_position(47,AUTHORED_FLOOR,47),foreign_plan,current_generation,
				"offline_fixture")
		end,"micro foreign construction identity")
		local missing_minp=owner_position(-32,OWNER_MAX,-32)
		local missing_maxp=owner_position(47,OWNER_MAX,47)
		local missing_plan,missing_generation=plan_at(loaded,
			missing_minp,missing_maxp)
		rewrite_plan(missing_plan,missing_generation,
			{{column=1,y_min=OWNER_MAX,y_max=OWNER_MAX,
			opcode=OPCODE_ID.TERRAIN_FILL}})
		local missing_vm,missing_observer=new_vm_for_plan(loaded,missing_minp,missing_maxp,
			HEIGHTMAP_SENTINEL,0,0,15)
		expect_error("fail_target",function()
			loaded.adapter:apply(missing_vm,missing_minp,missing_maxp,
				missing_plan,missing_generation,
				"offline_fixture")
		end,"micro missing content tuple")
		local missing_snapshot=missing_observer.snapshot()
		if #missing_snapshot.trace~=0 or missing_snapshot.calls.get_emerged_area~=0 then
			fail("conditional missing target touched VM")
		end
		local _,_,_,missing_tuple_calls,ignore_tuple_calls=
			loaded.fixture_content_observer()
		if missing_tuple_calls~=1 or ignore_tuple_calls~=1 then
			fail("conditional target tuple population differs")
		end
		rows[#rows+1]=common.canonical_row("plan_provenance","fail_stale_plan",
			"fail_foreign_identity","fail_missing_role","grade_stable_refs_8",
			grade_ref_digest)
		local final_planner_metrics=loaded.planner:metrics()
		local final_adapter_metrics=loaded.adapter:metrics()
		local planner_calls=final_planner_metrics.plan_buffer_reuse_calls-
			initial_planner_metrics.plan_buffer_reuse_calls
		local vm_transactions=final_adapter_metrics.vm_get_emerged_area_calls-
			initial_adapter_metrics.vm_get_emerged_area_calls
		local apply_attempts=isolated_applies+light_applies+liquid_applies+
			ignore_applies+native_applies+owner.apply_attempts+relation_applies+3
		local vm_fixtures=isolated_vms+light_vms+liquid_vms+ignore_vms+
			native_vms+owner.vm_fixtures+relation_vms+1
		if initial_planner_metrics.planner_construction_count~=1 or
				final_planner_metrics.planner_construction_count~=1 or
				planner_calls<1 or planner_calls>64 or vm_transactions<1 or
				vm_transactions>apply_attempts or apply_attempts~=61 or
				vm_fixtures~=49 or vm_fixtures>49 then
			fail("micro planner/VM compactness bound differs")
		end
		rows[#rows+1]=common.canonical_row("budget",
			integer_ascii(#points,"semantic witness points"),
			integer_ascii(planner_calls,"planner calls"),
			integer_ascii(vm_transactions,"VM transactions"),
			integer_ascii(apply_attempts,"apply attempts"),
			integer_ascii(vm_fixtures,"VM fixtures"),"one_r5_construction",
			"planner_calls_le_64","apply_attempts_le_64","vm_fixtures_le_49")

		-- Every family is linked to a constructed receipt above.  Witness IDs are
		-- deliberately shared so this complete semantic KAT remains compact.
		local coverage,witness_by_family,witness_ids={},{},{}
		local function cover(family,witness_id)
			if type(family)~="string" or type(witness_id)~="string" or
					witness_id=="" or coverage[family]~=nil then
				fail("micro witness registration differs")
			end
			coverage[family]=true
			witness_by_family[family]=witness_id
			witness_ids[witness_id]=true
		end
		for index=1,#REQUIRED_MICRO_FAMILIES do
			local family=REQUIRED_MICRO_FAMILIES[index]
			cover(family,MICRO_RECEIPT_BY_FAMILY[family])
		end
		local witness_count=0
		for _ in pairs(witness_ids) do witness_count=witness_count+1 end
		if witness_count>16 then fail("micro witness set exceeds compact bound") end
		for index=1,#REQUIRED_MICRO_FAMILIES do
			local family=REQUIRED_MICRO_FAMILIES[index]
			if coverage[family]~=true then
				fail("micro required family lacks constructed receipt: "..family)
			end
			rows[#rows+1]=common.canonical_row("witness",family,
				witness_by_family[family])
		end
		for index=1,#REQUIRED_MICRO_FAMILIES do
			local family=REQUIRED_MICRO_FAMILIES[index]
			rows[#rows+1]=common.canonical_row("coverage",
				family,true)
		end
		local canonical_bytes=common.render_canonical_rows(rows)
		local result={schema=MICRO_SCHEMA,rows=rows,coverage=coverage,
			canonical_bytes=canonical_bytes,
			sha256=digest_hex(offline.raw_sha256,canonical_bytes)}
		validator.validate_micro_kat_coverage(result)
		return result
	end

	local API_FIELDS={run_shard=true,merge_shards=true,micro_kat=true,
		validate_micro_kat_coverage=true}
	if type(common)~="table" or not exact_equal(OPCODES,common.OPCODES) or
			not exact_equal(ROLES,common.TARGET_ROLES) or
			not exact_equal(POLICIES,common.REPLACE_POLICIES) or
			not exact_equal(CLASSES,common.CONTENT_CLASSES) or
			not exact_equal(FIXTURE_ORDER,common.FIXTURE_IDS) then
		fail("Common/validator closed vocabulary differs")
	end
	exact_fields(validator,API_FIELDS,"validator API")
	return validator
end
