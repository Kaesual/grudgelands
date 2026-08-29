-- Canonical WP40 simple-map R5 manifest, validation-shard and artifact codec.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "output path required")
local mode = assert(arg[4], "artifact mode required")
if mode ~= "manifest" and mode ~= "preflight" and mode ~= "shard" and
		mode ~= "validate" and mode ~= "merge" then
	error("R5 artifact mode must be manifest, preflight, shard, validate or merge", 0)
end

local ffi = assert(rawget(_G, "wp40_ffi"),
	"R5 artifact lanes require injected LuaJIT FFI")
ffi.cdef[[
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]
local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local function injected_raw_sha256(bytes)
	assert(type(bytes) == "string", "SHA-256 input must be bytes")
	assert(crypto.SHA256(bytes, #bytes, digest_buffer) ~= nil,
		"SHA-256 failed")
	return ffi.string(digest_buffer, 32)
end

local common = dofile(repo .. "/tools/wp40/simple_map_r5_common.lua")
local offline_factory = dofile(repo .. "/tools/wp40/simple_map_r5_offline.lua")
local validator = dofile(repo .. "/tools/wp40/simple_map_r5_validate.lua")(common)
local SHARD_SCHEMA = "grug_wp40_simple_map_r5_validation_shard_v1"
local RESULT_SCHEMA = "grug_wp40_simple_map_r5_validation_v1"
local RECEIPT_SCHEMA = "grug_wp40_simple_map_r5_validation_receipt_v1"

local function fail(message)
	error("WP40 simple-map R5 artifact: " .. message, 0)
end

local function exact_fields(value, allowed, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain table")
	end
	local count = 0
	for key in pairs(value) do
		if not allowed[key] then fail(label .. " has unexpected field") end
		count = count + 1
	end
	local expected = 0
	for key in pairs(allowed) do
		expected = expected + 1
		if rawget(value, key) == nil then fail(label .. " is missing " .. key) end
	end
	if count ~= expected then fail(label .. " field count differs") end
end

exact_fields(validator, {run_shard = true, merge_shards = true,
	micro_kat = true, validate_micro_kat_coverage = true}, "validator API")

local fixture_set = {}
for index = 1, #common.FIXTURE_IDS do
	fixture_set[common.FIXTURE_IDS[index]] = true
end

local function split_tsv(line)
	local fields = {}
	local start = 1
	while true do
		local separator = line:find("\t", start, true)
		if not separator then
			fields[#fields + 1] = line:sub(start)
			break
		end
		fields[#fields + 1] = line:sub(start, separator - 1)
		start = separator + 1
	end
	for index = 1, #fields do
		if fields[index] == "" then fail("empty TSV field") end
	end
	return fields
end

local function nonnegative_ascii(text, label)
	if type(text) ~= "string" or
			not (text == "0" or text:match("^[1-9][0-9]*$")) then
		fail(label .. " is not minimal nonnegative ASCII")
	end
	local value = tonumber(text)
	common.nonnegative_integer(value, label)
	if common.integer_ascii(value) ~= text then fail(label .. " is not canonical") end
	return value
end

local function validate_owned_map(values, fixture_id, ownership, kind)
	if type(values) ~= "table" or getmetatable(values) ~= nil then
		fail(kind .. " map is not plain")
	end
	for key, value in pairs(values) do
		if type(key) ~= "string" or key == "" then fail(kind .. " key differs") end
		local owner = ownership[key]
		if kind == "metric" then
			if type(owner) ~= "table" or owner[fixture_id] ~= true then
				fail("metric fixture ownership differs")
			end
		elseif owner ~= fixture_id then
			fail(kind .. " fixture ownership differs")
		end
		if kind == "digest" then
			common.require_sha256(value, "shard digest")
		elseif kind == "proof" then
			if value ~= true then fail("shard proof is not true") end
		else
			common.nonnegative_integer(value, "shard " .. kind)
		end
	end
end

local SHARD_FIELDS = {schema = true, fixture_id = true, digests = true,
	counts = true, proofs = true, metrics = true, seed_kats = true}
local SEED_FIELDS = {ordinal = true, seed = true, historical_sha256 = true,
	current_sha256 = true}

local function validate_shard_codec(report)
	exact_fields(report, SHARD_FIELDS, "validation shard")
	if report.schema ~= SHARD_SCHEMA or not fixture_set[report.fixture_id] then
		fail("validation shard identity differs")
	end
	validate_owned_map(report.digests, report.fixture_id,
		common.DIGEST_FIXTURE_BY_KEY, "digest")
	validate_owned_map(report.counts, report.fixture_id,
		common.COUNT_FIXTURE_BY_KEY, "count")
	validate_owned_map(report.proofs, report.fixture_id,
		common.PROOF_FIXTURE_BY_KEY, "proof")
	validate_owned_map(report.metrics, report.fixture_id,
		common.METRIC_FIXTURES_BY_KEY, "metric")
	local seed_count = common.dense_count(report.seed_kats, "shard seed KATs")
	if report.fixture_id == "historical_r4" then
		if seed_count ~= 4 then fail("historical seed-KAT count differs") end
		for ordinal = 1, 4 do
			local row = report.seed_kats[ordinal]
			exact_fields(row, SEED_FIELDS, "seed KAT row")
			if row.ordinal ~= ordinal or row.seed ~= common.CANONICAL_SEEDS[ordinal] then
				fail("seed-KAT ordinal/text differs")
			end
			common.require_sha256(row.historical_sha256, "historical seed KAT")
			common.require_sha256(row.current_sha256, "current seed KAT")
		end
	elseif seed_count ~= 0 then
		fail("non-historical shard carries seed KATs")
	end
	return report
end

local function append_map_rows(rows, tag, values)
	local keys = common.sorted_keys(values)
	for index = 1, #keys do
		local key = keys[index]
		rows[#rows + 1] = common.canonical_row(tag, key, values[key])
	end
end

local function serialize_shard(report, manifest_sha256)
	validate_shard_codec(report)
	common.require_sha256(manifest_sha256, "shard input manifest")
	local rows = {
		common.canonical_row("schema", SHARD_SCHEMA),
		common.canonical_row("fixture_id", report.fixture_id),
		common.canonical_row("input_manifest_sha256", manifest_sha256),
	}
	append_map_rows(rows, "digest", report.digests)
	append_map_rows(rows, "count", report.counts)
	append_map_rows(rows, "proof", report.proofs)
	append_map_rows(rows, "metric", report.metrics)
	for ordinal = 1, #report.seed_kats do
		local row = report.seed_kats[ordinal]
		rows[#rows + 1] = common.canonical_row("seed_kat", row.ordinal,
			row.seed, row.historical_sha256, row.current_sha256)
	end
	local body = common.render_canonical_rows(rows)
	local digest = common.digest_hex(injected_raw_sha256, body)
	return body .. "shard_sha256\t" .. digest .. "\n", digest
end

local function parse_shard(path, manifest_sha256)
	local bytes = common.read_file(path)
	local body, embedded = bytes:match("^(.*\n)shard_sha256\t([0-9a-f]+)\n$")
	if not body or common.digest_hex(injected_raw_sha256, body) ~= embedded then
		fail("validation shard framing/digest differs")
	end
	common.require_sha256(embedded, "validation shard digest")
	local report = {schema = SHARD_SCHEMA, fixture_id = nil, digests = {},
		counts = {}, proofs = {}, metrics = {}, seed_kats = {}}
	local row_index = 0
	for line in body:gmatch("([^\n]+)\n") do
		row_index = row_index + 1
		local fields = split_tsv(line)
		if row_index == 1 then
			if #fields ~= 2 or fields[1] ~= "schema" or fields[2] ~= SHARD_SCHEMA then
				fail("validation shard schema row differs")
			end
		elseif row_index == 2 then
			if #fields ~= 2 or fields[1] ~= "fixture_id" or
					not fixture_set[fields[2]] then fail("shard fixture row differs") end
			report.fixture_id = fields[2]
		elseif row_index == 3 then
			if #fields ~= 2 or fields[1] ~= "input_manifest_sha256" or
					fields[2] ~= manifest_sha256 then fail("shard manifest row differs") end
		elseif fields[1] == "digest" and #fields == 3 then
			if report.digests[fields[2]] ~= nil then fail("duplicate shard digest") end
			common.require_sha256(fields[3], "shard digest")
			report.digests[fields[2]] = fields[3]
		elseif fields[1] == "count" and #fields == 3 then
			if report.counts[fields[2]] ~= nil then fail("duplicate shard count") end
			report.counts[fields[2]] = nonnegative_ascii(fields[3], "shard count")
		elseif fields[1] == "proof" and #fields == 3 then
			if report.proofs[fields[2]] ~= nil or fields[3] ~= "true" then
				fail("shard proof differs")
			end
			report.proofs[fields[2]] = true
		elseif fields[1] == "metric" and #fields == 3 then
			if report.metrics[fields[2]] ~= nil then fail("duplicate shard metric") end
			report.metrics[fields[2]] = nonnegative_ascii(fields[3], "shard metric")
		elseif fields[1] == "seed_kat" and #fields == 5 then
			local ordinal = nonnegative_ascii(fields[2], "seed KAT ordinal")
			if ordinal < 1 or ordinal > 4 or report.seed_kats[ordinal] ~= nil then
				fail("seed-KAT ordinal differs")
			end
			report.seed_kats[ordinal] = {ordinal = ordinal, seed = fields[3],
				historical_sha256 = fields[4], current_sha256 = fields[5]}
		else
			fail("unexpected validation shard row")
		end
	end
	if row_index < 3 or report.fixture_id == nil then fail("shard header incomplete") end
	local canonical = serialize_shard(report, manifest_sha256)
	if canonical ~= bytes then fail("validation shard bytes are not canonical") end
	return report, embedded, bytes
end

local function read_manifest(path)
	return common.parse_input_manifest(injected_raw_sha256,
		common.read_file(path))
end

local function progress(label, value)
	io.write("r5_progress\t", tostring(label))
	if value ~= nil then io.write("\t", tostring(value)) end
	io.write("\n")
end

local function artifact_bytes(result, manifest)
	exact_fields(result, {schema = true, fixture_ids = true, digests = true,
		counts = true, proofs = true, metrics = true, seed_kats = true},
		"merged validation result")
	if result.schema ~= RESULT_SCHEMA then fail("merged result schema differs") end
	local builder = common.new_artifact_builder()
	builder.add("schema", common.R5_ARTIFACT_SCHEMA)
	local lineage = {
		r2_body_sha256 = common.R2_BODY_SHA256,
		r2_file_sha256 = common.R2_FILE_SHA256,
		r3_body_sha256 = common.R3_BODY_SHA256,
		r3_file_sha256 = common.R3_FILE_SHA256,
		r4_historical_body_sha256 = common.R4_HISTORICAL_BODY_SHA256,
		r4_historical_file_sha256 = common.R4_HISTORICAL_FILE_SHA256,
		r4_public_kat_bundle_sha256 =
			result.digests.historical_r4.r4_public_kat_bundle,
		r4_seed_0_canonical_kat_sha256 =
			result.seed_kats[1].historical_sha256,
		r4_accepted_targeted_kat_body_sha256 = common.R4_TARGETED_KAT_BODY_SHA256,
		r4_accepted_targeted_kat_file_sha256 = common.R4_TARGETED_KAT_FILE_SHA256,
		r4_accepted_implementation_commit = common.R4_ACCEPTED_COMMIT,
		r4_review_file_sha256 = common.R4_REVIEW_FILE_SHA256,
		r4_review_verdict_sha256 = common.R4_REVIEW_VERDICT_SHA256,
		contract_sha256 = manifest.digests[
			"docs/research/wp40-simple-map-r5-contract.md"],
	}
	for index = 1, #common.LINEAGE_KEYS do
		local key = common.LINEAGE_KEYS[index]
		if lineage[key] == nil then fail("lineage binding missing " .. key) end
		builder.add("lineage", key, lineage[key])
	end
	for _, key in ipairs(common.sorted_keys(common.CONSTANTS)) do
		local row = common.CONSTANTS[key]
		builder.add("constant", key, row.type, row.value)
	end
	for _, key in ipairs(common.sorted_keys(common.MANIFEST)) do
		local row = common.MANIFEST[key]
		builder.add("manifest", key, row.type, row.value)
	end
	for index = 1, #common.VOCABULARY do
		local row = common.VOCABULARY[index]
		builder.add("vocabulary", row.domain, row.id, row.token)
	end
	for index = 1, #manifest.paths do
		local encoded = manifest.paths[index]
		local path = common.decode_path(encoded)
		builder.add("input_sha256", encoded, manifest.digests[path])
	end
	for ordinal = 1, 4 do
		local row = result.seed_kats[ordinal]
		builder.add("seed_kat", row.ordinal, row.seed, row.historical_sha256,
			row.current_sha256)
	end
	for fixture_index = 1, #common.FIXTURE_IDS do
		local fixture_id = common.FIXTURE_IDS[fixture_index]
		for _, key in ipairs(common.sorted_keys(result.digests[fixture_id])) do
			builder.add("digest", fixture_id, key,
				result.digests[fixture_id][key])
		end
		for _, key in ipairs(common.sorted_keys(result.counts[fixture_id])) do
			builder.add("count", fixture_id, key, result.counts[fixture_id][key])
		end
		for _, key in ipairs(common.sorted_keys(result.proofs[fixture_id])) do
			builder.add("proof", fixture_id, key, result.proofs[fixture_id][key])
		end
		for _, key in ipairs(common.sorted_keys(result.metrics[fixture_id])) do
			builder.add("metric", fixture_id, key, result.metrics[fixture_id][key])
		end
	end
	local body = builder.body()
	local bytes, digest = common.finalize_artifact(injected_raw_sha256, body)
	common.parse_finalized_artifact(injected_raw_sha256, bytes, digest, nil,
		"R5 artifact candidate")
	return bytes, digest
end

local function load_reports(manifest)
	if #arg ~= 13 then fail(mode .. " requires exactly eight shard paths") end
	local reports, shard_digests = {}, {}
	for index = 1, 8 do
		local report, digest = parse_shard(arg[index + 5], manifest.sha256)
		reports[index] = report
		shard_digests[report.fixture_id] = digest
	end
	return reports, shard_digests
end

if mode == "manifest" then
	if #arg ~= 4 then fail("manifest mode takes no additional arguments") end
	local parent = common.verify_parent_authority(repo, injected_raw_sha256)
	local manifest = common.capture_input_manifest(repo, injected_raw_sha256,
		parent.r2.inputs, parent.r3.inputs)
	common.verify_input_manifest(repo, injected_raw_sha256, manifest,
		parent.r2.inputs, parent.r3.inputs)
	common.write_file(output, manifest.canonical_bytes)
	io.write("r5_input_manifest_sha256\t", manifest.sha256, "\n")
elseif mode == "preflight" then
	if #arg ~= 5 then fail("preflight mode requires manifest output path") end
	local manifest_output = arg[5]
	local offline = offline_factory(repo, scratch, injected_raw_sha256)
	local authority = offline.preflight()
	local manifest = authority.input_manifest
	local report = validator.run_shard(offline, "historical_r4", progress)
	local shard_bytes, shard_digest = serialize_shard(report, manifest.sha256)
	offline.verify_input_manifest()
	common.write_file(output, shard_bytes)
	common.write_file(manifest_output, manifest.canonical_bytes)
	io.write("r5_historical_shard_sha256\t", shard_digest, "\n")
	io.write("r5_input_manifest_sha256\t", manifest.sha256, "\n")
elseif mode == "shard" then
	if #arg ~= 6 then fail("shard mode requires manifest and fixture ID") end
	local manifest = read_manifest(arg[5])
	local fixture_id = arg[6]
	if fixture_id == "historical_r4" then
		fail("historical fixture is owned by preflight mode")
	end
	local offline = offline_factory(repo, scratch, injected_raw_sha256, manifest)
	offline.verify_input_manifest()
	local report = validator.run_shard(offline, fixture_id, progress)
	local bytes, digest = serialize_shard(report, manifest.sha256)
	offline.verify_input_manifest()
	common.write_file(output, bytes)
	io.write("r5_validation_shard_sha256\t", fixture_id, "\t", digest, "\n")
else
	local manifest_path = assert(arg[5], "input manifest path required")
	local manifest = read_manifest(manifest_path)
	local offline = offline_factory(repo, scratch, injected_raw_sha256, manifest)
	offline.verify_input_manifest()
	local reports, shard_digests = load_reports(manifest)
	local result = validator.merge_shards(reports)
	offline.verify_input_manifest()
	if mode == "validate" then
		local rows = {
			common.canonical_row("schema", RECEIPT_SCHEMA),
			common.canonical_row("input_manifest_sha256", manifest.sha256),
			common.canonical_row("result_schema", result.schema),
		}
		for index = 1, #common.FIXTURE_IDS do
			local fixture_id = common.FIXTURE_IDS[index]
			rows[#rows + 1] = common.canonical_row("fixture", fixture_id,
				shard_digests[fixture_id])
		end
		rows[#rows + 1] = common.canonical_row("validated", true)
		local body = common.render_canonical_rows(rows)
		local digest = common.digest_hex(injected_raw_sha256, body)
		common.write_file(output,
			body .. "validation_sha256\t" .. digest .. "\n")
		io.write("r5_validation_receipt_sha256\t", digest, "\n")
	else
		local bytes, digest = artifact_bytes(result, manifest)
		common.write_file(output, bytes)
		io.write("r5_artifact_body_sha256\t", digest, "\n")
	end
end
