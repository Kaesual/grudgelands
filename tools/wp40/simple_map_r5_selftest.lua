-- Focused LuaJIT-only integration smoke for the disabled WP40 R5 path.
--
-- This is deliberately not the final micro-KAT or exhaustive evidence lane.
-- It exercises one seed-zero, one-node-high offline owner slice and leaves
-- production loading disabled.

local repo = assert(arg[1], "repository root required")
assert(type(rawget(_G, "jit")) == "table",
	"simple_map_r5_selftest requires LuaJIT")
local ffi = assert(rawget(_G, "wp40_ffi"),
	"wp40_ffi must be injected before the selftest")

ffi.cdef[[
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]
local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local function raw_sha256(data)
	assert(type(data) == "string", "SHA-256 input must be bytes")
	assert(crypto.SHA256(data, #data, digest_buffer) ~= nil,
		"SHA-256 failed")
	return ffi.string(digest_buffer, 32)
end

local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end

local function exact_fields(value, allowed, label)
	assert(type(value) == "table", label .. " is not a table")
	local actual_count = 0
	for key in pairs(value) do
		assert(allowed[key], label .. " has unexpected field " .. tostring(key))
		actual_count = actual_count + 1
	end
	local expected_count = 0
	for key in pairs(allowed) do
		expected_count = expected_count + 1
		assert(rawget(value, key) ~= nil, label .. " is missing " .. key)
	end
	assert(actual_count == expected_count, label .. " field count differs")
end

local function expect_failure(prefix, callback)
	local ok, message = pcall(callback)
	assert(not ok, prefix .. " fixture unexpectedly succeeded")
	assert(type(message) == "string" and
		message:sub(1, #prefix + 1) == prefix .. ":",
		prefix .. " fixture returned " .. tostring(message))
end

local function dense_fill(count, value)
	local result = {}
	for index = 1, count do result[index] = value end
	return result
end

local initial_globals = {}
for key, value in pairs(_G) do initial_globals[key] = value end
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(directory .. "/source/simple_map.lua")
local schemas = dofile(directory .. "/schemas.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local index128 = dofile(directory .. "/index128.lua")
local horizontal_factory = dofile(directory .. "/simple_map.lua")
local height_factory = dofile(directory .. "/height.lua")
local zones_factory = dofile(directory .. "/zones.lua")
local planner_factory = dofile(directory .. "/planner.lua")
local adapter_factory = dofile(directory .. "/map_adapter.lua")
local manifest_module = dofile(directory .. "/mapgen_manifest.lua")
local allocator_factory = dofile(directory .. "/counting_allocator.lua")
local r5_factory = dofile(directory .. "/r5.lua")
local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")

local manifest_values = {
	schema = "grug_wp40_r5_mapgen_manifest_v1",
	engine_commit = "df04879066de6eb94ca43996822a6dfacc74feca",
	mg_name = "v7",
	water_level = 1,
	mapgen_limit = 31007,
	chunksize = 5,
	central_owner_y_min = -30912,
	central_owner_y_max = 30927,
	heightmap_entries = 6400,
	heightmap_sentinel = -31007,
	heightmap_order = "x_fast_z_outer",
	emerge_threads = 1,
	engine_emerge_setting = "num_emerge_threads",
	mg_flags = "biomes,caves,decorations,dungeons,light,ores",
	mgv7_spflags = "caverns,mountains,ridges",
	mgv7_dungeon_ymin = -31000,
	mgv7_dungeon_ymax = -193,
	authored_floor = -37,
	force_native_dungeon = false,
}
local expected_manifest_bytes =
	"schema\tgrug_wp40_r5_mapgen_manifest_v1\n" ..
	"engine_commit\tdf04879066de6eb94ca43996822a6dfacc74feca\n" ..
	"mg_name\tv7\n" ..
	"water_level\t1\n" ..
	"mapgen_limit\t31007\n" ..
	"chunksize\t5\n" ..
	"central_owner_y_min\t-30912\n" ..
	"central_owner_y_max\t30927\n" ..
	"heightmap_entries\t6400\n" ..
	"heightmap_sentinel\t-31007\n" ..
	"heightmap_order\tx_fast_z_outer\n" ..
	"emerge_threads\t1\n" ..
	"engine_emerge_setting\tnum_emerge_threads\n" ..
	"mg_flags\tbiomes,caves,decorations,dungeons,light,ores\n" ..
	"mgv7_spflags\tcaverns,mountains,ridges\n" ..
	"mgv7_dungeon_ymin\t-31000\n" ..
	"mgv7_dungeon_ymax\t-193\n" ..
	"authored_floor\t-37\n" ..
	"force_native_dungeon\tfalse\n"
local validated_manifest = manifest_module.validate(manifest_values)
assert(manifest_module.canonical_bytes(validated_manifest) ==
	expected_manifest_bytes, "canonical manifest bytes differ")

-- Closed fixture role/CID map. All fixture nodes deliberately share inert
-- light/floodable properties so this focused integration lane does not expand
-- into the exhaustive lighting matrix.
local role_cid = {0, 5, 6, 8, 9, 7, 3, 2, 12, 13, 3, 4, 14, 1, 10, 11}
local role_kind = {0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 2, 1, 1, 1}
local resolve_calls = 0
local classify_calls = 0
local content_metrics_calls = 0
local content_contract = {
	schema = "grug_wp40_r5_content_contract_v1",
	ignore_cid = 65535,
	ordinary_water_family_id = 1,
	river_water_family_id = 2,
}
function content_contract.resolve(role_id, y, aux)
	resolve_calls = resolve_calls + 1
	assert(type(role_id) == "number" and role_id % 1 == 0 and
		role_id >= 1 and role_id <= 16, "fixture role is invalid")
	assert(type(y) == "number" and y % 1 == 0,
		"fixture target y is invalid")
	assert(aux == 0, "fixture aux is invalid")
	return role_cid[role_id], role_kind[role_id], 0, nil
end
function content_contract.classify(cid, param2)
	classify_calls = classify_calls + 1
	assert(type(cid) == "number" and cid % 1 == 0 and cid >= 0,
		"fixture CID is invalid")
	assert(type(param2) == "number" and param2 % 1 == 0 and
		param2 >= 0 and param2 <= 255, "fixture param2 is invalid")
	local class_id = 9
	local family_id = 0
	local liquid_kind = 0
	if cid == 0 then
		class_id = 1
	elseif cid == 65535 then
		class_id = 3
	elseif cid == 13 then
		class_id, family_id, liquid_kind = 4, 1, 1
	elseif cid == 14 then
		class_id, family_id, liquid_kind = 4, 2, 1
	elseif cid == 1 then
		class_id = 11
	elseif cid == 2 or cid == 4 or cid == 5 or cid == 7 or cid == 9 or
			cid == 10 then
		class_id = 7
	elseif cid == 3 or cid == 6 or cid == 8 or cid == 11 or cid == 12 then
		class_id = 6
	end
	return class_id, family_id, liquid_kind, 0, false, false, false,
		false, 0
end
function content_contract.metrics()
	content_metrics_calls = content_metrics_calls + 1
	return {
		resolve_calls = resolve_calls,
		classify_calls = classify_calls,
		query_table_allocations = 0,
		metrics_result_table_allocations = content_metrics_calls,
	}
end
exact_fields(content_contract, {
	schema = true,
	ignore_cid = true,
	ordinary_water_family_id = true,
	river_water_family_id = true,
	resolve = true,
	classify = true,
	metrics = true,
}, "content contract")

local minp = {x = -32, y = 1, z = -32}
local maxp = {x = 47, y = 1, z = 47}
local emerged_volume = 112 * 33 * 112
local zero_buffer = dense_fill(emerged_volume, 0)
local heightmap = dense_fill(6400, -31007)
local vm, mapgen_context, observer = vm_module.new({
	minp = minp,
	maxp = maxp,
	data = zero_buffer,
	param2 = zero_buffer,
	light = zero_buffer,
	heightmap = heightmap,
	content_contract = content_contract,
	water_level = 1,
	ignore_cid = 65535,
})

-- Record the two otherwise-private production allocators without weakening
-- their factory provenance. The wrapper exposes exactly `new` and delegates
-- both the one-argument constructor and two-argument identity predicate.
local recorded_allocators = {}
local recording_allocator_factory = {}
function recording_allocator_factory.new(...)
	local argument_count = select("#", ...)
	if argument_count == 1 then
		local allocator = allocator_factory.new(...)
		recorded_allocators[#recorded_allocators + 1] = allocator
		return allocator
	end
	if argument_count == 2 then return allocator_factory.new(...) end
	error("recording allocator factory arity differs", 0)
end
exact_fields(recording_allocator_factory, {new = true},
	"recording allocator factory")

local dependencies = {
	zones_factory = zones_factory,
	planner_factory = planner_factory,
	adapter_factory = adapter_factory,
	manifest_module = manifest_module,
	allocator_factory = recording_allocator_factory,
	source = source,
	schemas = schemas,
	canonical = canonical,
	deterministic = deterministic,
	index128 = index128,
	horizontal_factory = horizontal_factory,
	height_factory = height_factory,
	raw_sha256 = raw_sha256,
}
local r5_module = r5_factory(dependencies)
local status = r5_module.status()
exact_fields(status, {
	schema = true,
	planner_available = true,
	adapter_available = true,
	production_enabled = true,
	callback_registered = true,
	disabled_reason = true,
}, "R5 status")
assert(status.schema == "grug_wp40_simple_map_r5_status_v1" and
	status.planner_available == true and status.adapter_available == true and
	status.production_enabled == false and
	status.callback_registered == false and
	status.disabled_reason ==
		"WP40 R5 planner and adapter are internal and disabled until R7",
	"R5 disabled status differs")
status.production_enabled = true
assert(r5_module.status().production_enabled == false,
	"R5 status is not defensive")

local session, planner_source, planner, adapter = r5_module.new("0", 1,
	manifest_values, content_contract, mapgen_context)
assert(#recorded_allocators == 2, "R5 did not construct exactly two allocators")

-- The public constructor and the public side of the private constructor must
-- remain exact accepted R4 authority.
local zones_module = zones_factory({
	source = source,
	schemas = schemas,
	canonical = canonical,
	deterministic = deterministic,
	index128 = index128,
	horizontal_factory = horizontal_factory,
	height_factory = height_factory,
	raw_sha256 = raw_sha256,
})
local public_session = zones_module.new("0", 1)
local accepted_seed_zero_digest =
	"8b5145180dd8a4a6de01de47cbb8fc4560e2947d78cdb281016d5c3414b9b8aa"
local public_kat = public_session.canonical_kat()
local private_public_kat = session.canonical_kat()
assert(public_kat == private_public_kat,
	"public/private constructor canonical KAT bytes differ")
assert(hex(raw_sha256(public_kat)) == accepted_seed_zero_digest and
	public_session.canonical_kat_digest() == accepted_seed_zero_digest and
	session.canonical_kat_digest() == accepted_seed_zero_digest,
	"accepted seed-zero R4 canonical KAT digest differs")
local public_fields = {
	get = true, at = true, neighbors = true, travel_links = true, anchor = true,
	id_at = true, biome_at = true, race_region_at = true, faction_at = true,
	territory_rule_at = true, pvp_rule_at = true,
	surface_mob_level_at = true, mob_level_at = true, guard_level_at = true,
	terrain_height_at = true, water_class_at = true, nearest_route_at = true,
	nearest_hydrology_at = true, housing_eligible_at = true,
	canonical_kat = true, canonical_kat_digest = true,
	artifact_evidence = true, metrics = true, compatibility = true,
}
exact_fields(public_session, public_fields, "public R4 session")
exact_fields(session, public_fields, "private-constructor public R4 session")
local _, _, _, logical_biome_id = planner_source.column_values_at(0, 0)
assert(logical_biome_id == session.biome_at(0, 0),
	"private logical-biome scalar is not the public R4 value")

local function plan_bytes(plan)
	local rows = {
		plan.schema, tostring(plan.min_x), tostring(plan.min_y),
		tostring(plan.min_z), tostring(plan.max_x), tostring(plan.max_y),
		tostring(plan.max_z), tostring(plan.run_count),
	}
	for index = 1, 6401 do rows[#rows + 1] = tostring(plan.column_start[index]) end
	for index = 1, plan.run_count * 9 do
		rows[#rows + 1] = tostring(plan.run_values[index])
	end
	for index = 1, #plan.stable_refs do
		local value = plan.stable_refs[index]
		rows[#rows + 1] = tostring(#value) .. ":" .. value
	end
	return table.concat(rows, "\n") .. "\n"
end

local plan, generation = planner:plan_slice(minp, maxp)
assert(plan.valid == true and plan.generation == generation and
	plan.run_count > 0, "focused R5 plan is empty or invalid")
local first_plan_digest = hex(raw_sha256(plan_bytes(plan)))
local first_result = adapter:apply(vm, minp, maxp, plan, generation,
	"offline_fixture")
assert(first_result:match("^applied_"),
	"focused R5 apply did not change its fixture")
local repeat_result = adapter:apply(vm, minp, maxp, plan, generation,
	"offline_fixture")
assert(repeat_result == "noop_equal_content",
	"same-VM repeated R5 apply is not an exact no-op")

local repeated_plan, repeated_generation = planner:plan_slice(minp, maxp)
assert(rawequal(plan, repeated_plan) and repeated_generation == generation + 1,
	"planner did not reuse its exact plan handle and advance generation")
assert(hex(raw_sha256(plan_bytes(repeated_plan))) == first_plan_digest,
	"repeated planner bytes differ")
expect_failure("fail_stale_plan", function()
	adapter:apply(vm, minp, maxp, repeated_plan, generation,
		"offline_fixture")
end)

local foreign_plan = {}
for _, key in ipairs({
	"schema", "construction_identity", "generation", "valid",
	"min_x", "min_y", "min_z", "max_x", "max_y", "max_z",
	"column_start", "run_values", "run_count", "stable_refs",
}) do
	foreign_plan[key] = repeated_plan[key]
end
foreign_plan.construction_identity = {}
expect_failure("fail_plan", function()
	adapter:apply(vm, minp, maxp, foreign_plan, repeated_generation,
		"offline_fixture")
end)

-- Empty plans validate status/provenance/bounds but must not require, inspect
-- or call a VM/context object. Keep the current retained plan identity and
-- generation, then make this the final plan-handle state used by the smoke.
repeated_plan.run_count = 0
for column = 1, 6401 do repeated_plan.column_start[column] = 1 end
assert(adapter:apply(nil, minp, maxp, repeated_plan, repeated_generation,
	"offline_fixture") == "noop_empty_plan",
	"canonical empty plan did not bypass every VM/context seam")

-- Public loading remains R4-only and does not publish an R5 global.
local foundation = dofile(directory .. "/init.lua")(directory)
exact_fields(foundation, {
	enabled = true,
	disabled_reason = true,
	schemas = true,
	canonical = true,
	deterministic = true,
	validation = true,
	index128 = true,
	seed_corpus = true,
	raw_sha256_from_core = true,
	new_session = true,
	new_engine_session = true,
}, "public WP40 foundation")
assert(foundation.enabled == false and foundation.disabled_reason ==
	"WP40 R4 payload is validated but not published until R7",
	"public R4 disabled bytes differ")
for key, value in pairs(_G) do
	assert(initial_globals[key] == value,
		"R5 loading published or changed global " .. tostring(key))
end
for key, value in pairs(initial_globals) do
	assert(rawget(_G, key) == value,
		"R5 loading removed global " .. tostring(key))
end

-- One coordinated terminal metrics snapshot. No owner metrics method is
-- called before this point, so every result-allocation count begins at one.
local terminal_trace = observer.snapshot().trace
local cross_seam_sequences = 0
for index = 1, #terminal_trace - 3 do
	if terminal_trace[index] == "get_emerged_area" and
			terminal_trace[index + 1] == "get_heightmap" and
			terminal_trace[index + 2] == "get_data" and
			terminal_trace[index + 3] == "get_param2_data" then
		cross_seam_sequences = cross_seam_sequences + 1
	end
end
assert(cross_seam_sequences == 2,
	"nonempty applies do not preserve the exact cross-seam precommit order")
local terminal = {
	planner_allocator = recorded_allocators[1]:metrics(),
	adapter_allocator = recorded_allocators[2]:metrics(),
	planner_source = planner_source.metrics(),
	planner = planner:metrics(),
	adapter = adapter:metrics(),
	content = content_contract.metrics(),
	context = mapgen_context.metrics(),
	vm = observer.metrics(),
}
assert(terminal.planner_allocator.domain_id ==
	"grug_wp40_r5_planner_allocator_v1" and
	terminal.adapter_allocator.domain_id ==
	"grug_wp40_r5_adapter_allocator_v1",
	"allocator domain order differs")
assert(terminal.planner_allocator.construction_array_tables +
	terminal.adapter_allocator.construction_array_tables == 19,
	"R5 retained array-table aggregate differs")
assert(terminal.planner_allocator.construction_map_tables +
	terminal.adapter_allocator.construction_map_tables == 8,
	"R5 retained map-table aggregate differs")
assert(terminal.planner_allocator.allocator_bootstrap_tables +
	terminal.adapter_allocator.allocator_bootstrap_tables == 4,
	"R5 allocator bootstrap aggregate differs")
assert(terminal.planner_allocator.hotpath_table_allocations == 0 and
	terminal.adapter_allocator.hotpath_table_allocations == 0 and
	terminal.planner.plan_slice_table_allocations == 0 and
	terminal.adapter.adapter_apply_table_allocations == 0,
	"R5 hotpath allocation evidence differs")
assert(terminal.planner_allocator.metrics_result_table_allocations == 1 and
	terminal.adapter_allocator.metrics_result_table_allocations == 1 and
	terminal.planner.metrics_result_table_allocations == 1 and
	terminal.adapter.metrics_result_table_allocations == 1,
	"terminal R5 metrics snapshot count differs")
assert(terminal.planner.plan_identity_count == 1 and
	terminal.planner.plan_buffer_reuse_calls == 2 and
	terminal.planner_source.horizontal_session_count == 1 and
	terminal.planner_source.height_session_count == 1 and
	terminal.planner_source.planner_source_count == 1 and
	terminal.planner_source.query_table_allocations == 0,
	"planner/source focused metrics differ")
assert(terminal.context.heightmap_fetch_calls == 2 and
	terminal.context.heightmap_external_table_allocations == 2 and
	terminal.adapter.heightmap_entries_validated == 12800 and
	terminal.adapter.emerged_area_external_table_allocations == 4,
	"focused native-heightmap/emerged-area metrics differ")
assert(terminal.vm.vm_get_emerged_area_calls == 2 and
	terminal.vm.vm_get_data_calls == 2 and
	terminal.vm.vm_get_param2_calls == 2 and
	terminal.vm.vm_set_data_calls == 1 and
	terminal.vm.vm_set_param2_calls == 0 and
	terminal.vm.vm_get_light_calls == 0 and
	terminal.vm.vm_set_lighting_calls == 0 and
	terminal.vm.vm_calc_lighting_calls == 0 and
	terminal.vm.vm_set_light_data_calls == 0,
	"focused VM call trace differs")
local traced_vm_calls = terminal.vm.vm_get_emerged_area_calls +
	terminal.vm.vm_get_data_calls + terminal.vm.vm_get_param2_calls +
	terminal.vm.vm_get_light_calls + terminal.vm.vm_set_data_calls +
	terminal.vm.vm_set_param2_calls + terminal.vm.vm_set_lighting_calls +
	terminal.vm.vm_calc_lighting_calls + terminal.vm.vm_set_light_data_calls +
	terminal.vm.vm_update_liquids_calls
assert(#terminal_trace == terminal.vm.trace_entries and
	terminal.vm.trace_entries == traced_vm_calls +
		terminal.context.heightmap_fetch_calls,
	"failed/stale/foreign/empty calls touched the VM/context trace")

print("WP40 simple-map R5 phase-3 selftest passed")
