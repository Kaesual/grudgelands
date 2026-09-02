-- Compact canonical cross-interpreter WP40 simple-map R5 micro-KAT writer.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local manifest_path = assert(arg[3], "input manifest path required")
local output = assert(arg[4], "micro-KAT output path required")
local mode = assert(arg[5], "micro-KAT mode required")
if mode ~= "micro" or #arg ~= 5 then
	error("R5 KAT accepts exactly the micro mode", 0)
end

local ffi = rawget(_G, "wp40_ffi")
local injected_raw_sha256
if ffi then
	ffi.cdef[[
		unsigned char *SHA256(const unsigned char *data, size_t length,
			unsigned char *digest);
	]]
	local crypto = ffi.load("crypto")
	local digest_buffer = ffi.new("unsigned char[32]")
	injected_raw_sha256 = function(bytes)
		assert(type(bytes) == "string", "SHA-256 input must be bytes")
		assert(crypto.SHA256(bytes, #bytes, digest_buffer) ~= nil,
			"SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
end

local common = dofile(repo .. "/tools/wp40/simple_map_r5_common.lua")
local offline_factory = dofile(repo .. "/tools/wp40/simple_map_r5_offline.lua")
-- Constructing the nil-mode loader is side-effect free: its historical
-- preflight remains lazy and is never called here.  We use only its exact
-- cross-interpreter SHA seam to parse the frozen manifest, then discard it.
local hash_loader = offline_factory(repo, scratch, injected_raw_sha256)
local manifest = common.parse_input_manifest(hash_loader.raw_sha256,
	common.read_file(manifest_path))
assert(hash_loader.loaded() == false,
	"bootstrap SHA loader unexpectedly loaded current production")
local offline = offline_factory(repo, scratch, injected_raw_sha256, manifest)
local frozen = offline.input_manifest()
assert(frozen.canonical_bytes == manifest.canonical_bytes and
	frozen.sha256 == manifest.sha256,
	"gated Offline changed the parsed frozen manifest")
offline.verify_input_manifest()
assert(offline.loaded() == false,
	"manifest verification unexpectedly loaded current production")
local validator = dofile(repo .. "/tools/wp40/simple_map_r5_validate.lua")(common)

local function fail(message)
	error("WP40 simple-map R5 micro-KAT: " .. message, 0)
end

local function exact_fields(value, allowed, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain table")
	end
	local actual = 0
	for key in pairs(value) do
		if not allowed[key] then fail(label .. " has unexpected field") end
		actual = actual + 1
	end
	local expected = 0
	for key in pairs(allowed) do
		expected = expected + 1
		if rawget(value, key) == nil then fail(label .. " is missing " .. key) end
	end
	if actual ~= expected then fail(label .. " field count differs") end
end

exact_fields(validator, {run_shard = true, merge_shards = true,
	micro_kat = true, validate_micro_kat_coverage = true}, "validator API")

local function progress(label, value)
	io.write("r5_micro_progress\t", tostring(label))
	if value ~= nil then io.write("\t", tostring(value)) end
	io.write("\n")
end

local result = validator.micro_kat(offline, progress)
exact_fields(result, {schema = true, rows = true, coverage = true,
	canonical_bytes = true, sha256 = true}, "micro-KAT envelope")
if validator.validate_micro_kat_coverage(result) ~= true then
	fail("micro-KAT coverage validator did not return true")
end
local actual_digest = common.digest_hex(offline.raw_sha256,
	result.canonical_bytes)
if actual_digest ~= common.require_sha256(result.sha256,
		"micro-KAT body digest") then
	fail("micro-KAT body digest differs")
end
offline.verify_input_manifest()
local bytes = result.canonical_bytes .. "kat_sha256\t" .. result.sha256 .. "\n"
common.write_file(output, bytes)
io.write("r5_micro_kat_sha256\t", result.sha256, "\n")
