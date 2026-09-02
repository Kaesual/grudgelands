-- Targeted cross-interpreter R3 KAT writer for four canonical full seeds.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "KAT output path required")
local mode = arg[4] or "serial"

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
		assert(crypto.SHA256(data, #data, digest_buffer) ~= nil, "SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
end

local common = dofile(repo .. "/tools/wp40/simple_map_r3_common.lua")
local offline = dofile(repo .. "/tools/wp40/simple_map_r3_offline.lua")(
	repo, scratch, injected_raw_sha256)
local r2 = common.verify_r2(repo, offline.raw_sha256)
local validator = dofile(repo .. "/tools/wp40/simple_map_r3_validate.lua")(common)
local seeds = {"0", "1", "9223372036854775808", "18446744073709551615"}
local builder = common.new_tsv()
builder.add("schema", "grug_wp40_simple_map_r3_targeted_kat_v1")
builder.add("r2_body_sha256", r2.body_sha256)
builder.add("r2_file_sha256", r2.file_sha256)

local function build_seed(seed_index)
	local seed = seeds[seed_index]
	if not seed then error("R3 targeted KAT seed index differs", 0) end
	local loaded = offline.load(seed)
	local session = loaded.height
	validator.validate_api(session, offline.raw_sha256)
	local evidence = validator.validate_evidence(session, loaded.source)
	local payload = common.new_tsv()
	payload.add("seed", seed, session.canonical_kat_digest(),
		session.relief_lattice_digest())
	local rows, coverage = validator.targeted_rows(session, loaded.horizontal,
		loaded.source, evidence)
	for row_index = 1, #rows do
		local row = rows[row_index]
		payload.add("query", seed, unpack(row, 1, 19))
	end
	local metrics = session.metrics()
	payload.add("query_counters", seed, metrics.query_sha256_calls,
		metrics.query_lattice_constructions)
	collectgarbage("collect")
	return seed, payload.body(), coverage
end

local function lines(bytes)
	local result = {}
	for line in bytes:gmatch("([^\n]+)\n") do result[#result + 1] = line end
	if table.concat(result, "\n") .. "\n" ~= bytes then
		error("R3 targeted KAT shard is not newline-terminated", 0)
	end
	return result
end

local function final_write(target)
	local body = target.body()
	local digest = common.digest_hex(offline.raw_sha256, body)
	common.write_file(output, body .. "kat_sha256\t" .. digest .. "\n")
	io.write("r3_targeted_kat_sha256\t", digest, "\n")
end

local function read_shard(path, expected_index, aggregate_coverage)
	local bytes = common.read_file(path)
	local body, embedded = bytes:match(
		"^(.*\n)kat_shard_sha256\t([0-9a-f]+)\n$")
	if not body or #embedded ~= 64 or
			common.digest_hex(offline.raw_sha256, body) ~= embedded then
		error("R3 targeted KAT shard digest differs", 0)
	end
	local rows = lines(body)
	local seed = seeds[expected_index]
	if rows[1] ~= "schema\tgrug_wp40_simple_map_r3_targeted_kat_shard_v1" or
			rows[2] ~= "seed_index\t" .. expected_index or
			rows[3] ~= "seed\t" .. seed then
		error("R3 targeted KAT shard header differs", 0)
	end
	local payload, cursor = {}, 4
	if rows[cursor] ~= "payload_begin" then
		error("R3 targeted KAT shard payload boundary differs", 0)
	end
	cursor = cursor + 1
	while rows[cursor] and rows[cursor] ~= "payload_end" do
		payload[#payload + 1] = rows[cursor]
		cursor = cursor + 1
	end
	if rows[cursor] ~= "payload_end" or cursor ~= #rows or #payload < 2 or
			not payload[1]:match("^seed\t" .. seed .. "\t") or
			not payload[#payload]:match("^query_counters\t" .. seed .. "\t") then
		error("R3 targeted KAT shard payload differs", 0)
	end
	for index = 2, #payload - 1 do
		local fields = {}
		for value in payload[index]:gmatch("[^\t]+") do
			fields[#fields + 1] = value
		end
		if #fields ~= 21 or fields[1] ~= "query" or fields[2] ~= seed then
			error("R3 targeted KAT shard query row differs", 0)
		end
		aggregate_coverage.class[fields[6]] = true
		if fields[13] ~= "-" then aggregate_coverage.functional[fields[13]] = true end
		if fields[17] ~= "-" then aggregate_coverage.transition[fields[17]] = true end
	end
	return payload
end

if mode == "serial" then
	local aggregate_coverage = {functional = {}, transition = {}, class = {}}
	for seed_index = 1, #seeds do
		local _, payload, coverage = build_seed(seed_index)
		for family, values in pairs(coverage) do
			for value in pairs(values) do aggregate_coverage[family][value] = true end
		end
		for _, line in ipairs(lines(payload)) do builder.add_raw(line) end
	end
	validator.assert_targeted_coverage(aggregate_coverage)
	final_write(builder)
elseif mode == "shard" then
	local seed_index = assert(tonumber(arg[5]), "KAT seed index required")
	local seed, payload = build_seed(seed_index)
	local shard = common.new_tsv()
	shard.add("schema", "grug_wp40_simple_map_r3_targeted_kat_shard_v1")
	shard.add("seed_index", seed_index)
	shard.add("seed", seed)
	shard.add("payload_begin")
	for _, line in ipairs(lines(payload)) do shard.add_raw(line) end
	shard.add("payload_end")
	local body = shard.body()
	common.write_file(output, body .. "kat_shard_sha256\t" ..
		common.digest_hex(offline.raw_sha256, body) .. "\n")
elseif mode == "merge" then
	local aggregate_coverage = {functional = {}, transition = {}, class = {}}
	local payloads = {}
	for seed_index = 1, #seeds do
		payloads[seed_index] = read_shard(
			assert(arg[4 + seed_index], "KAT shard required"), seed_index,
			aggregate_coverage)
	end
	validator.assert_targeted_coverage(aggregate_coverage)
	for seed_index = 1, #seeds do
		for _, line in ipairs(payloads[seed_index]) do builder.add_raw(line) end
	end
	final_write(builder)
else
	error("R3 targeted KAT mode must be serial, shard or merge", 0)
end
