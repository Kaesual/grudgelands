local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(arg[3] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"targeted E0 conformance requires plain PUC Lua 5.1")
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"targeted E0 conformance requires the vendored interpreter")
assert(repo:match("^/[A-Za-z0-9._/-]+$") and
	scratch:match("^/tmp/grudgelands%-wp40%-t2%-extreme%-puc%.[A-Za-z0-9]+$"),
	"unsafe targeted E0 path")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local cache, counter = {}, 0
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local function raw_sha256(data)
	local cached = cache[data]
	if cached then return cached end
	counter = counter + 1
	local input = scratch .. "/sha-" .. counter .. ".bin"
	local output = scratch .. "/sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	file = assert(io.open(output, "rb"))
	local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
	assert(file:close() and #digest == 32)
	cache[data] = digest
	return digest
end
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end
local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do result[deep_copy(key, seen)] =
		deep_copy(child, seen) end
	return result
end
local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok and tostring(message):find(fragment, 1, true), tostring(message))
end
local function plain_bytes(value, seen)
	local kind = type(value)
	if kind == "string" then return "s" .. #value .. ":" .. value end
	if kind == "number" then assert(value % 1 == 0); return "n" .. value .. ";" end
	if kind == "boolean" then return value and "b1" or "b0" end
	if kind == "nil" then return "z" end
	assert(kind == "table" and getmetatable(value) == nil)
	seen = seen or {}
	assert(not seen[value], "scalar projection aliases or cycles")
	seen[value] = true
	local count, array = 0, true
	for key in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then array = false end
	end
	local parts
	if array and count == #value then
		parts = {"a", tostring(count), ":"}
		for index = 1, count do parts[#parts + 1] = plain_bytes(value[index], seen) end
	else
		local keys = {}
		for key in pairs(value) do assert(type(key) == "string"); keys[#keys + 1] = key end
		table.sort(keys)
		parts = {"m", tostring(#keys), ":"}
		for index = 1, #keys do
			parts[#parts + 1] = plain_bytes(keys[index], seen)
			parts[#parts + 1] = plain_bytes(value[keys[index]], seen)
		end
	end
	seen[value] = nil
	return table.concat(parts)
end

local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority = assert(loadstring(authority_bytes, "@" .. authority_path))()({
	raw_sha256 = raw_sha256})
local files = authority.capture_files(repo, {[authority_path] = authority_bytes})
local canonical = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({
		deterministic = deterministic})
local raster = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua")({canonical = canonical,
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local validator_module = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua")
local seed_corpus = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")

local vocabulary = authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local snapshot = authority.bind_vocabulary(files, vocabulary)
local gate = authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua")
local partition_path = "mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua"
local partition_sha256 = hex(raw_sha256(files.files[partition_path]))
local s1_authority = authority.load_module(files,
	"tools/wp40/t2_s1_authority.lua")({raw_sha256 = raw_sha256})
local s1_boundary = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raster = raster,
	raw_sha256 = raw_sha256, source = source,
	source_validator = validator_module, vocabulary = vocabulary})
local s1_source_projection_sha256 = s1_boundary.s1_source_checksum()
local s1_authority_sha256 = s1_authority.digest(files.files,
	s1_source_projection_sha256, s1_boundary.PROJECTION_SCHEMA)
local expected_gate_pins = {s1_authority_sha256 = s1_authority_sha256,
	s1_source_projection_sha256 = s1_source_projection_sha256}
assert(authority.validate_full_scan_gate(gate, expected_gate_pins))
for _, mutate in ipairs({
	function(row) row.status = "blocked" end,
	function(row) row.s1_authority_sha256 = string.rep("0", 64) end,
	function(row) row.s1_source_projection_sha256 = string.rep("0", 64) end,
	function(row) row.s1_authority_schema = "grug_wp40_s1_authority_v0" end,
	function(row) row.extra = true end,
}) do
	local corrupt = deep_copy(gate)
	mutate(corrupt)
	expect_error("full-scan", function()
		authority.validate_full_scan_gate(corrupt, expected_gate_pins)
	end)
end

local validator = validator_module.new_offline_test_adapter(canonical, raw_sha256)
local new_boundary = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua")
local partition = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary,
	raster = raster, raw_sha256 = raw_sha256, source = source,
	source_validator = validator, vocabulary = vocabulary})
local session = partition.new_extreme_scalar_session()
local seed0_records = session("0")
local max_records = session("18446744073709551615")
local seed0_sha256 = hex(raw_sha256(plain_bytes(seed0_records)))
local max_sha256 = hex(raw_sha256(plain_bytes(max_records)))
assert(seed0_sha256 ==
	"f3faae90bc897caca481cd774a5c20b00bdc88385d3e12b037f89ebd1e0701c0" and
	max_sha256 ==
	"f29a6231471bc6a712c2aba582fc2e5e5c60ec148acbc095ca29266f9aaff0af",
	"targeted PUC scalar projection differs from the LuaJIT/frozen bytes")

local extreme = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
	scalar_reader = session, seed_corpus = seed_corpus, source = source})
local candidate = seed_corpus.extreme_candidate(0, raw_sha256)
assert(candidate.digest ==
	"2e0c0041e1bcc0abf1cf4f3e024dfc28d32b05b4742249335b4fa9979261f2c8" and
	candidate.first8 == "2e0c0041e1bcc0ab" and
	candidate.decimal == "3318027308425330859")
local row = extreme.score_candidate(0)
assert(row.status == "scored" and row.candidate_index == 0 and
	row.decimal == candidate.decimal and row.coast_n == 1972811 and
	row.coast_d == 24696061952 and row.noncoast_n == 618062429 and
	row.noncoast_d == 178530549760 and row.coast_sample_count == 23552 and
	row.noncoast_sample_count == 42565 and row.coast_identity_sha256 ==
		"0be6420d4f27c8e885f1c4af23ab98f0551c658e07715a1384e47629ba69a662" and
	row.noncoast_identity_sha256 ==
		"8070e4c25a86397aaa04e474b9d4917e4d79ac8def9998c111ae76747b32ca38",
	"targeted PUC candidate0 score/identity changed")

local provenance = authority.git_provenance(repo, scratch)
local pins = {s1_authority_sha256 = gate.s1_authority_sha256,
	s1_source_projection_sha256 = gate.s1_source_projection_sha256,
	authority_dag_sha256 = snapshot.authority_dag_sha256,
	authority_commit = provenance.commit, authority_tree = provenance.tree,
	interpreter_id = "puc_lua51", interpreter_launcher = arg[-1],
	interpreter_path = arg[-1],
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = hex(raw_sha256(assert((function()
		local file = assert(io.open(arg[-1], "rb"))
		local bytes = assert(file:read("*a")); assert(file:close()); return bytes
	end)()))), measurement_scope = "R7_SCALAR_MEASUREMENT_ONLY",
	stage2_status = "pending_selected_four",
	scorer_schema = "grug_wp40_extreme_selector_e0_v1"}
local shard = extreme.candidate_shard({row}, 0, 0, pins)
local blob = extreme.shard_blob(shard)
local parsed = extreme.parse_shard_blob(blob)
assert(extreme.shard_blob(parsed) == blob and parsed.rows_sha256 == shard.rows_sha256)
assert(shard.rows_sha256 ==
	"a1cf557c4d18e6f6c0559a85a9cd59ab7dbbbf5bd3281bce615f0e91fd7c8890",
	"targeted PUC candidate0 canonical row digest changed")
assert(authority.verify(repo, snapshot, vocabulary))
print("WP40 T2 E0 targeted PUC candidate0 rows SHA-256 " .. shard.rows_sha256)
print("WP40 T2 E0 targeted PUC passed scalar seed0=" .. seed0_sha256 ..
	" max_u64=" .. max_sha256 .. " candidate0=" .. candidate.decimal ..
	" s1_authority=" .. s1_authority_sha256 ..
	" partition=" .. partition_sha256)
