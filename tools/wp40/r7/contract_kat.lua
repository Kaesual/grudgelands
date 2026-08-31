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
	p9g_content_sha256 = digest_a, catalog_sha256 = digest_b, cases = cases,
}
local integration_bytes = contract.integration_receipt_bytes(integration)
assert(integration_bytes:find("case\tstage_b_projection\ttrue\n", 1, true))
cases.replay_parity = false
expect_failure(function() contract.validate_integration_receipt(integration) end,
	"integration case did not pass")

local pilot = {
	schema = "grug_wp40_r7_pilot_result_v1", seed_slot = 17,
	seed_identity = "seed-17", canonical_output_sha256 = digest_a,
	stage_a_sha256 = digest_b, stage_b_sha256 = digest_a,
	p9g_delta_sha256 = digest_b,
}
assert(contract.pilot_result_bytes(pilot):find("seed_slot\t17\n", 1, true))

print("WP40 R7 evidence contract KAT PASS catalog=" .. catalog_digest ..
	" populations=12/8/6 rejection_reasons=" .. #contract.rejection_reasons())
