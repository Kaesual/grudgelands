-- Engine-free LuaJIT development KAT for the R7 evidence schemas.

local repo = assert(arg[1], "repository root required")
local ffi = assert(rawget(_G, "wp40_ffi"), "wp40_ffi injection required")

ffi.cdef[[
	typedef unsigned long size_t;
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]

local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local function raw_sha256(bytes)
	assert(crypto.SHA256(bytes, #bytes, digest_buffer) ~= nil, "SHA-256 failed")
	return ffi.string(digest_buffer, 32)
end
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end
local function expect_failure(callback, fragment)
	local ok, message = pcall(callback)
	assert(not ok, "failure fixture unexpectedly passed")
	assert(type(message) == "string" and message:find(fragment, 1, true),
		"failure fixture returned " .. tostring(message))
end

local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
local ids = contract.expected_ids()
local function rows(class)
	local result = {}
	for index = 1, #ids[class] do
		result[index] = {placement_class = class, id = ids[class][index]}
	end
	return result
end

local canonical = "closed-catalog-fixture\n"
local catalog_digest = hex(raw_sha256(canonical))
local snapshot = {
	manifest = {
		schema = "grug_wp33_gathering_catalog_v1",
		sha256 = catalog_digest,
		canonical_bytes = canonical,
		source_files = {}, placement = {},
		population = {new_p9g_source = 12, reuse_r6_source = 8,
			r6_cultural_slot = 6},
	},
	p9g_sources = rows("new_p9g_source"),
	reuse_sources = rows("reuse_r6_source"),
	cultural_sources = rows("r6_cultural_slot"),
	cultural_registrations = {},
}
for index = 1, 6 do
	snapshot.cultural_registrations[index] = {
		id = ids.r6_cultural_slot[index], digest = string.rep(string.format("%x", index), 64),
	}
end

contract.validate_catalog(snapshot, raw_sha256)
local receipt = contract.catalog_receipt(snapshot)
assert(receipt:find("population\tnew_p9g_source\t12\n", 1, true))
snapshot.p9g_sources[1], snapshot.p9g_sources[2] =
	snapshot.p9g_sources[2], snapshot.p9g_sources[1]
expect_failure(function() contract.validate_catalog(snapshot, raw_sha256) end,
	"ID/order differs")
snapshot.p9g_sources[1], snapshot.p9g_sources[2] =
	snapshot.p9g_sources[2], snapshot.p9g_sources[1]
snapshot.manifest.population.new_p9g_source = 11
expect_failure(function() contract.validate_catalog(snapshot, raw_sha256) end,
	"12/8/6 population differs")
snapshot.manifest.population.new_p9g_source = 12

local digest_a, digest_b = string.rep("a", 64), string.rep("b", 64)
local stage_a = {
	schema = "grug_wp40_r7_stage_a_receipt_v1", seed_slot = 1,
	seed_identity = "seed-1", production_r6_content_sha256 = digest_a,
	p9g_content_sha256 = digest_b, p9g_delta_sha256 = digest_a,
	anchor_content_sha256 = digest_b, anchor_roster_sha256 = digest_a,
	anchor_delta_sha256 = digest_b, anchor_write_count = 0,
	operation_count = 12, accepted_count = 5, rejected_count = 7,
	restored_buffers_sha256 = digest_a, direct_buffers_sha256 = digest_a,
	restored_runs_sha256 = digest_b, direct_runs_sha256 = digest_b, equal = true,
}
contract.validate_stage_a(stage_a)
stage_a.rejected_count = 6
expect_failure(function() contract.validate_stage_a(stage_a) end,
	"operation partition differs")
stage_a.rejected_count = 7

local stage_b = {
	schema = "grug_wp40_r7_stage_b_receipt_v1", seed_slot = 1,
	seed_identity = "seed-1", production_r6_content_sha256 = digest_a,
	accepted_r6_projection_sha256 = digest_b, name_map_population = 83,
	cultural_name_map_population = 6, cultural_substitution_count = 9,
	inherited_cultural_access_count = 12,
	normalized_artifact_sha256 = digest_b, candidate_decisions_sha256 = digest_a,
	accepted_candidate_decisions_sha256 = digest_a, equal = true,
}
contract.validate_stage_b(stage_b)
stage_b.name_map_population = 82
expect_failure(function() contract.validate_stage_b(stage_b) end,
	"total name map differs")
stage_b.name_map_population = 83

local cases = {}
for _, name in ipairs(contract.integration_cases()) do cases[name] = true end
local integration = {
	schema = "grug_wp40_r7_integration_kat_receipt_v1",
	r7_manifest_sha256 = digest_a, production_r6_content_sha256 = digest_b,
	p9g_content_sha256 = digest_a, anchor_content_sha256 = digest_b,
	anchor_roster_sha256 = digest_a, anchor_delta_sha256 = digest_b,
	catalog_sha256 = digest_b,
	proof_scope = "full_owner_7_private_buffers_pre_replay",
	private_tuple_count = 512000,
	successor_tuple_sha256 = digest_a, direct_tuple_sha256 = digest_b,
	accepted_tuple_sha256 = digest_a, successor_run_count = 11,
	direct_run_count = 10, accepted_run_count = 10,
	successor_run_sha256 = digest_a, direct_run_sha256 = digest_b,
	accepted_run_sha256 = digest_a, successor_run_checksum_a = 1,
	successor_run_checksum_b = 2, direct_run_checksum_a = 3,
	direct_run_checksum_b = 4, accepted_run_checksum_a = 5,
	accepted_run_checksum_b = 6, stage_a_tuple_sha256 = digest_b,
	stage_a_run_sha256 = digest_b, stage_b_tuple_sha256 = digest_a,
	anchor_stripped_run_projection_sha256 = digest_a,
	stage_b_run_sha256 = digest_a, multi_y_owner_x = -32,
	multi_y_owner_z = 48, multi_y_band_count = 3,
	multi_y_bands = "-32,48,128",
	multi_y_active_band_count = 2, multi_y_active_bands = "-32,48",
	multi_y_operation_count = 5, multi_y_eligible = 12,
	multi_y_planned = 5, multi_y_accepted = 4,
	cases = cases,
}
local integration_bytes = contract.integration_receipt_bytes(integration)
assert(integration_bytes:find("case\tstage_b_projection\ttrue\n", 1, true))
assert(integration_bytes:find("multi_y_owner_x\t-32\n", 1, true))
assert(integration_bytes:find("multi_y_owner_z\t48\n", 1, true))
assert(integration_bytes:find("multi_y_bands\t-32,48,128\n", 1, true))
assert(integration_bytes:find("multi_y_active_bands\t-32,48\n", 1, true))
integration.multi_y_owner_z = -32
expect_failure(function() contract.validate_integration_receipt(integration) end,
	"integration frozen multi-y discovery differs")
integration.multi_y_owner_z = 48
integration.multi_y_bands = "-32,48"
expect_failure(function() contract.validate_integration_receipt(integration) end,
	"integration frozen multi-y discovery differs")
integration.multi_y_bands = "-32,48,128"
integration.multi_y_active_bands = "-32,128"
expect_failure(function() contract.validate_integration_receipt(integration) end,
	"integration frozen multi-y discovery differs")
integration.multi_y_active_bands = "-32,48"
cases.replay_parity = false
expect_failure(function() contract.validate_integration_receipt(integration) end,
	"integration case did not pass")

local pilot = {
	schema = "grug_wp40_r7_pilot_result_v3", seed_slot = 17,
	seed_identity = "seed-17", canonical_output_sha256 = digest_a,
	canonical_output_bytes = 12345,
	stage_a_sha256 = digest_b, stage_b_sha256 = digest_a,
	p9g_delta_sha256 = digest_b, frontier_access_roster_sha256 = digest_a,
	frontier_access_enabled = true,
	frontier_access_owner_count = 458, frontier_access_column_count = 2931200,
}
local pilot_bytes = contract.pilot_result_bytes(pilot)
assert(pilot_bytes:find("seed_slot\t17\n", 1, true))
assert(pilot_bytes:find("canonical_output_bytes\t12345\n", 1, true))
pilot.seed_slot = 18
pilot.frontier_access_enabled = false
pilot.frontier_access_owner_count = 0
pilot.frontier_access_column_count = 0
assert(contract.pilot_result_bytes(pilot):find(
	"frontier_access_enabled\tfalse\n", 1, true))
pilot.frontier_access_enabled = true
pilot.frontier_access_owner_count = 458
pilot.frontier_access_column_count = 2931200
expect_failure(function() contract.validate_pilot_result(pilot) end,
	"pilot frontier access slot selection differs")
pilot.seed_slot = 17
pilot.frontier_access_enabled = false
pilot.frontier_access_owner_count = 0
pilot.frontier_access_column_count = 0
expect_failure(function() contract.validate_pilot_result(pilot) end,
	"pilot frontier access slot selection differs")

local runtime_adapter = dofile(repo .. "/tools/wp40/r7/runtime_adapter.lua")
assert(runtime_adapter.canonical_graph_nul_kat() == true)
assert(runtime_adapter.owner_column_count_kat() == true)
assert(runtime_adapter.sample_roster_kat() == true)
assert(runtime_adapter.frontier_access_roster_kat(repo) == true)
local sample_assignment = runtime_adapter.sample_assignment(repo)
assert(sample_assignment:find("schema\tgrug_wp40_r7_sample_assignment_v1\n", 1,
	true) == 1)
assert(hex(raw_sha256(sample_assignment)) ==
	"4d1e0e796941115cfdbc44031e9fbc08775d11adc52503834ac3805b6708092c")
assert(select(2, sample_assignment:gsub("\nseed\t", "")) == 32)
assert(sample_assignment:find("case_population\t4096\n", 1, true))
local frontier_assignment = runtime_adapter.frontier_access_assignment(repo)
assert(frontier_assignment:find(
	"schema\tgrug_wp40_r7_frontier_access_assignment_v2\n", 1, true) == 1)
assert(hex(raw_sha256(frontier_assignment)) ==
	"14101c68d563e329f694b1594402e1d1e688ab6b1b2237db17f6df984725511a")
assert(frontier_assignment:find("seed_population\t7\n", 1, true))
assert(frontier_assignment:find("seed_slots\t1,6,11,17,22,27,32\n", 1, true))
assert(frontier_assignment:find("owner_population_per_seed\t458\n", 1, true))
assert(frontier_assignment:find("case_population\t3206\n", 1, true))
assert(frontier_assignment:find("column_visit_population\t20518400\n", 1, true))
assert(frontier_assignment:find(
	"roster_sha256\t6c52c5aa90b21ff21f5d5b695c5b50adcc2c329a5722362f37e82dde11718341\n",
	1, true))
assert(runtime_adapter.heightmap_projection_kat() == true)
assert(runtime_adapter.normalize_rows_kat() == true)
assert(runtime_adapter.first_difference_kat(repo) == true)
assert(runtime_adapter.stage_b_row_diagnostic_kat() == true)
assert(runtime_adapter.finalizer_authority_kat(repo) == true)

-- Execute the real production-private capture encoder without widening its
-- runtime API.  Lua 5.1 debug upvalues are used only by this offline tool KAT.
local function named_upvalue(fn, wanted)
	assert(type(fn) == "function")
	for index = 1, 100 do
		local name, value = debug.getupvalue(fn, index)
		if not name then break end
		if name == wanted then return value end
	end
	error("missing production capture upvalue " .. wanted, 0)
end
local settlement_factory = dofile(repo ..
	"/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua")
local settlement_new = named_upvalue(settlement_factory.new_capture, "new")
local capture_buffers = named_upvalue(settlement_new, "capture_private_buffers")
local capture_graph = named_upvalue(capture_buffers, "canonical_graph")
local aggregate_key = "runeslate\0ordinary"
local rejection_key = "cultural\0runeslate\0wrong_support"
local capture_encoded = capture_graph({
	cultural = {[aggregate_key] = {accepted = 1, reserved = 225}},
	rejections = {[rejection_key] = 1},
})
assert(capture_encoded:find("s" .. tostring(#aggregate_key) .. ":" .. aggregate_key,
	1, true))
assert(capture_encoded:find("s" .. tostring(#rejection_key) .. ":" .. rejection_key,
	1, true))
assert(capture_encoded ~= capture_graph({
	cultural = {[aggregate_key .. "x"] = {accepted = 1, reserved = 225}},
	rejections = {[rejection_key] = 1},
}))

-- Execute the actual CLI chunk with closed mocks so argument parsing is proven
-- without starting a pilot, worker or runtime adapter.
local function run_cli_fixture(arguments)
	local calls, writes = {sample = 0, access = 0, pilot = 0, worker = 0}, {}
	local contract_mock = {}
	function contract_mock.pilot_result_bytes()
		return "schema\tmock_pilot_result_v1\n"
	end
	local adapter_mock = {}
	function adapter_mock.sample_assignment(actual_repo)
		calls.sample = calls.sample + 1
		calls.sample_repo = actual_repo
		return "schema\tmock_sample_assignment_v1\n"
	end
	function adapter_mock.frontier_access_assignment(actual_repo)
		calls.access = calls.access + 1
		calls.access_repo = actual_repo
		return "schema\tmock_frontier_access_assignment_v1\n"
	end
	function adapter_mock.pilot(actual_repo, scratch, seed_slot)
		calls.pilot = calls.pilot + 1
		calls.pilot_values = {actual_repo, scratch, seed_slot}
		return {}
	end
	function adapter_mock.worker(actual_repo, scratch, first_slot, last_slot,
			projection_sha256)
		calls.worker = calls.worker + 1
		calls.worker_values = {actual_repo, scratch, first_slot, last_slot,
			projection_sha256}
		return "schema\tgrug_wp40_r7_worker_receipt_v3\n"
	end
	local fake_io = {}
	function fake_io.open(path, mode)
		assert(mode == "wb")
		return {
			write = function(_, bytes) writes[path] = bytes; return true end,
			close = function() return true end,
		}
	end
	local chunk = assert(loadfile(repo .. "/tools/wp40/r7/adapter_cli.lua"))
	setfenv(chunk, setmetatable({
		arg = arguments, io = fake_io, print = function() end,
		dofile = function(path)
			if path == "/mock/tools/wp40/r7/contract.lua" then return contract_mock end
			if path == "/mock/tools/wp40/r7/integration_adapter.lua" then
				return adapter_mock
			end
			error("unexpected CLI fixture dofile " .. tostring(path), 0)
		end,
	}, {__index = _G}))
	local ok, message = pcall(chunk)
	return ok, message, calls, writes
end

local ok_cli, message_cli, calls_cli, writes_cli = run_cli_fixture({
	"sample-roster", "/mock", "sample.tsv",
})
assert(ok_cli, message_cli)
assert(calls_cli.sample == 1 and calls_cli.pilot == 0 and calls_cli.worker == 0 and
	calls_cli.sample_repo == "/mock" and
	writes_cli["sample.tsv"] == "schema\tmock_sample_assignment_v1\n")

ok_cli, message_cli, calls_cli, writes_cli = run_cli_fixture({
	"frontier-access-roster", "/mock", "access.tsv",
})
assert(ok_cli, message_cli)
assert(calls_cli.access == 1 and calls_cli.sample == 0 and
	calls_cli.access_repo == "/mock" and writes_cli["access.tsv"] ==
		"schema\tmock_frontier_access_assignment_v1\n")

ok_cli, message_cli, calls_cli = run_cli_fixture({
	"pilot", "/mock", "pilot.tsv", "scratch", "17",
})
assert(ok_cli, message_cli)
assert(calls_cli.pilot == 1 and calls_cli.worker == 0 and
	calls_cli.pilot_values[1] == "/mock" and
	calls_cli.pilot_values[2] == "scratch" and
	calls_cli.pilot_values[3] == 17)
ok_cli, message_cli, calls_cli = run_cli_fixture({
	"worker", "/mock", "worker.tsv", "scratch", "1", "5", string.rep("a", 64),
})
assert(ok_cli, message_cli)
assert(calls_cli.pilot == 0 and calls_cli.worker == 1 and
	calls_cli.worker_values[3] == 1 and calls_cli.worker_values[4] == 5)

local function expect_cli_failure(arguments, fragment)
	local ok, message, calls = run_cli_fixture(arguments)
	assert(not ok and type(message) == "string" and
		message:find(fragment, 1, true), "CLI failure fixture differed")
	assert(calls.pilot == 0 and calls.worker == 0,
		"CLI failure reached the runtime adapter")
end
expect_cli_failure({"pilot", "/mock", "out", "scratch"},
	"pilot seed slot is not one canonical decimal slot")
expect_cli_failure({"pilot", "/mock", "out", "scratch", "not-a-number"},
	"pilot seed slot is not one canonical decimal slot")
expect_cli_failure({"pilot", "/mock", "out", "scratch", "33"},
	"pilot seed slot is outside the frozen 1..32 corpus")
expect_cli_failure({"worker", "/mock", "out", "scratch", "1"},
	"worker last slot is not one canonical decimal slot")
expect_cli_failure({"worker", "/mock", "out", "scratch", "not-a-number", "5",
	string.rep("a", 64)}, "worker first slot is not one canonical decimal slot")

print("WP40 R7 evidence contract KAT PASS catalog=" .. catalog_digest ..
	" populations=12/8/6 rejection_reasons=" .. #contract.rejection_reasons())
