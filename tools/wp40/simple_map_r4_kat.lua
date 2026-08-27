-- Targeted cross-interpreter R4 KAT writer for four canonical full seeds.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "KAT output path required")
local mode = assert(arg[4], "KAT mode required")
assert(mode == "shard" or mode == "merge", "KAT mode must be shard or merge")

local ffi = rawget(_G, "wp40_ffi")
local injected_raw_sha256
if ffi then
	ffi.cdef[[
		unsigned char *SHA256(const unsigned char *data, size_t length,
			unsigned char *digest);
	]]
	local crypto = ffi.load("crypto")
	local digest_buffer = ffi.new("unsigned char[32]")
	injected_raw_sha256 = function(data)
		assert(crypto.SHA256(data, #data, digest_buffer) ~= nil,
			"SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
end

local common = dofile(repo .. "/tools/wp40/simple_map_r4_common.lua")
local offline = dofile(repo .. "/tools/wp40/simple_map_r4_offline.lua")(
	repo, scratch, injected_raw_sha256)
local authority = offline.preflight()
local validator = dofile(repo .. "/tools/wp40/simple_map_r4_validate.lua")(common)
local seeds = common.CANONICAL_SEEDS

local function lines(bytes)
	local result = {}
	for line in bytes:gmatch("([^\n]+)\n") do result[#result + 1] = line end
	if table.concat(result, "\n") .. "\n" ~= bytes then
		error("R4 KAT: payload is not newline-terminated", 0)
	end
	return result
end

local function context(loaded)
	return {source = loaded.source, repo = repo, peer_session = loaded.peer_session}
end

local function assert_fail(label, callback, builder, seed)
	if pcall(callback) then error("R4 KAT: fail-closed case passed: " .. label, 0) end
	builder.add("fail_closed", seed, label, true)
end

local function build_seed(seed_index)
	local seed = seeds[seed_index]
	if not seed then error("R4 KAT: seed index differs", 0) end
	local loaded = offline.load_foundation(seed, common.WATER_LEVEL,
		{peer = true})
	if rawget(_G, "grug_zones") ~= nil then
		error("R4 KAT: disabled loader published a global registry", 0)
	end
	if loaded.foundation.enabled ~= false or loaded.foundation.disabled_reason ~=
			"WP40 R4 payload is validated but not published until R7" then
		error("R4 KAT: disabled foundation boundary differs", 0)
	end
	for _, field in ipairs({"compile", "compiler", "compiled_schema",
			"canonicalize_compiled", "new_offline_test_adapter", "trust_probe"}) do
		if loaded.foundation[field] ~= nil then
			error("R4 KAT: retired foundation field remains: " .. field, 0)
		end
	end
	if loaded.engine_callback_registration_calls ~= 0 or
			loaded.engine_unexpected_api_reads ~= 0 then
		error("R4 KAT: engine-shaped loader used an unexpected API", 0)
	end
	for _, field in ipairs({"schemas", "canonical", "deterministic", "validation",
			"index128", "seed_corpus"}) do
		if type(loaded.foundation[field]) ~= "table" then
			error("R4 KAT: retained foundation field differs: " .. field, 0)
		end
	end
	for _, field in ipairs({"new_session", "new_engine_session",
			"raw_sha256_from_core"}) do
		if type(loaded.foundation[field]) ~= "function" then
			error("R4 KAT: foundation constructor/seam differs: " .. field, 0)
		end
	end
	local session, peer = loaded.session, loaded.peer_session
	if session.canonical_kat() ~= peer.canonical_kat() or
			session.canonical_kat_digest() ~= peer.canonical_kat_digest() then
		error("R4 KAT: engine-free and engine-shaped sessions differ", 0)
	end
	validator.validate_api(session, offline.raw_sha256)
	validator.validate_api(peer, offline.raw_sha256)
	local rows, coverage = validator.targeted_rows(session, context(loaded),
		offline.raw_sha256)
	common.sort_canonical_rows(rows, "targeted KAT rows")
	local payload = common.new_tsv()
	payload.add("seed", seed, session.canonical_kat_digest(),
		peer.canonical_kat_digest())
	payload.add("disabled_loader", seed, loaded.foundation.enabled,
		loaded.foundation.disabled_reason, false,
		loaded.engine_setting_reads, loaded.engine_callback_registration_calls,
		loaded.engine_unexpected_api_reads)
	for row_index = 1, #rows do
		local row = rows[row_index]
		local count = common.dense_count(row, "targeted KAT row")
		payload.add("query", seed, unpack(row, 1, count))
	end
	if type(coverage) ~= "table" then error("R4 KAT: coverage missing", 0) end
	for _, family in ipairs(common.sorted_keys(coverage)) do
		if type(family) ~= "string" or type(coverage[family]) ~= "table" then
			error("R4 KAT: coverage family differs", 0)
		end
		for _, value in ipairs(common.sorted_keys(coverage[family])) do
			if type(value) ~= "string" or coverage[family][value] ~= true then
				error("R4 KAT: coverage value differs", 0)
			end
			payload.add("coverage", family, value)
		end
	end

	local foundation = loaded.foundation
	assert_fail("explicit_water_missing", function()
		foundation.new_session(seed, offline.raw_sha256, nil)
	end, payload, seed)
	assert_fail("explicit_water_fractional", function()
		foundation.new_session(seed, offline.raw_sha256, 1.5)
	end, payload, seed)
	assert_fail("explicit_water_wrong", function()
		foundation.new_session(seed, offline.raw_sha256, 2)
	end, payload, seed)
	local function engine_core(raw_value)
		return {
			sha256 = function(data, raw)
				assert(raw == true)
				return offline.raw_sha256(data)
			end,
			get_mapgen_setting = function(name)
				assert(name == "water_level")
				return raw_value
			end,
		}
	end
	assert_fail("engine_sha_missing", function()
		foundation.new_engine_session(seed, {get_mapgen_setting = function()
			return "1"
		end})
	end, payload, seed)
	assert_fail("engine_setting_missing", function()
		foundation.new_engine_session(seed, {sha256 = function(data)
			return offline.raw_sha256(data)
		end})
	end, payload, seed)
	assert_fail("engine_water_missing", function()
		foundation.new_engine_session(seed, engine_core(nil))
	end, payload, seed)
	assert_fail("engine_water_fractional", function()
		foundation.new_engine_session(seed, engine_core("1.5"))
	end, payload, seed)
	assert_fail("engine_water_wrong", function()
		foundation.new_engine_session(seed, engine_core("2"))
	end, payload, seed)
	local metrics = session.metrics()
	for _, name in ipairs({"query_sha256_calls", "query_lattice_constructions",
			"query_feature_list_constructions", "query_unindexed_catalog_scans"}) do
		if metrics[name] ~= 0 then
			error("R4 KAT: nonzero prohibited query counter: " .. name, 0)
		end
	end
	payload.add("query_counters", seed, metrics.query_sha256_calls,
		metrics.query_lattice_constructions,
		metrics.query_feature_list_constructions,
		metrics.query_unindexed_catalog_scans)
	return seed, payload.body()
end

local function write_shard(seed_index)
	local seed, payload = build_seed(seed_index)
	local builder = common.new_tsv()
	builder.add("schema", "grug_wp40_simple_map_r4_targeted_kat_shard_v1")
	builder.add("seed_index", seed_index)
	builder.add("seed", seed)
	builder.add("payload_begin")
	for _, line in ipairs(lines(payload)) do builder.add_raw(line) end
	builder.add("payload_end")
	local body = builder.body()
	local digest = common.digest_hex(offline.raw_sha256, body)
	common.write_file(output, body .. "kat_shard_sha256\t" .. digest .. "\n")
end

local function read_shard(path, expected_index, aggregate_coverage)
	local bytes = common.read_file(path)
	local body, embedded = bytes:match(
		"^(.*\n)kat_shard_sha256\t([0-9a-f]+)\n$")
	if not body or #embedded ~= 64 or
			common.digest_hex(offline.raw_sha256, body) ~= embedded then
		error("R4 KAT: shard digest differs", 0)
	end
	local rows = lines(body)
	local seed = seeds[expected_index]
	if rows[1] ~= "schema\tgrug_wp40_simple_map_r4_targeted_kat_shard_v1" or
			rows[2] ~= "seed_index\t" .. expected_index or
			rows[3] ~= "seed\t" .. seed or rows[4] ~= "payload_begin" or
			rows[#rows] ~= "payload_end" then
		error("R4 KAT: shard header/boundary differs", 0)
	end
	local payload = {}
	for index = 5, #rows - 1 do
		local line = rows[index]
		if line:match("^coverage\t") then
			local family, value = line:match("^coverage\t([^\t]+)\t([^\t]+)$")
			if not family then error("R4 KAT: malformed coverage row", 0) end
			aggregate_coverage[family] = aggregate_coverage[family] or {}
			if aggregate_coverage[family][value] then
				-- The same coverage across different seeds is expected; retain set form.
			else
				aggregate_coverage[family][value] = true
			end
		elseif not line:match("^seed\t" .. seed .. "\t") and
				not line:match("^disabled_loader\t" .. seed .. "\t") and
				not line:match("^query\t" .. seed .. "\t") and
				not line:match("^fail_closed\t" .. seed .. "\t") and
				not line:match("^query_counters\t" .. seed .. "\t") then
			error("R4 KAT: malformed payload row", 0)
		end
		payload[#payload + 1] = line
	end
	if #payload < 2 or not payload[1]:match("^seed\t" .. seed .. "\t") or
			not payload[#payload]:match("^query_counters\t" .. seed .. "\t") then
		error("R4 KAT: incomplete shard payload", 0)
	end
	return payload
end

if mode == "shard" then
	local seed_index = assert(tonumber(arg[5]), "KAT seed index required")
	common.safe_integer(seed_index, "KAT seed index")
	write_shard(seed_index)
else
	local aggregate_coverage, payloads = {}, {}
	if #arg ~= 8 then error("R4 KAT: merge requires four seed shards", 0) end
	for seed_index = 1, #seeds do
		payloads[seed_index] = read_shard(arg[4 + seed_index], seed_index,
			aggregate_coverage)
	end
	validator.assert_targeted_coverage(aggregate_coverage)
	local builder = common.new_tsv()
	builder.add("schema", "grug_wp40_simple_map_r4_targeted_kat_v1")
	builder.add("r2_body_sha256", authority.r2.body_sha256)
	builder.add("r2_file_sha256", authority.r2.file_sha256)
	builder.add("r3_body_sha256", authority.r3.body_sha256)
	builder.add("r3_file_sha256", authority.r3.file_sha256)
	for seed_index = 1, #seeds do
		for _, line in ipairs(payloads[seed_index]) do builder.add_raw(line) end
	end
	local body = builder.body()
	local digest = common.digest_hex(offline.raw_sha256, body)
	common.write_file(output, body .. "kat_sha256\t" .. digest .. "\n")
	io.write("r4_targeted_kat_sha256\t", digest, "\n")
end
