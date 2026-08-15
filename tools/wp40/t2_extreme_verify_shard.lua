local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local first = assert(tonumber(arg[3]), "first candidate required")
local last = assert(tonumber(arg[4]), "last candidate required")
local shard_path = assert(arg[5], "shard path required")
assert(arg[6] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"retained shard verification requires plain PUC Lua 5.1")
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"retained shard verification requires the vendored interpreter")

local function safe_absolute_path(value)
	assert(type(value) == "string" and value:match("^/[A-Za-z0-9._/-]+$") and
		not value:find("/../", 1, true) and not value:find("/./", 1, true) and
		not value:find("//", 1, true), "unsafe absolute path")
end
for _, path in ipairs({repo, scratch, shard_path}) do safe_absolute_path(path) end
assert(first % 512 == 0 and last == first + 511 and first >= 0 and last <= 4095)

local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local cache, counter = {}, 0
local function raw_sha256(data)
	if cache[data] then return cache[data] end
	counter = counter + 1
	local input = scratch .. "/verify-sha-" .. counter .. ".bin"
	local output = scratch .. "/verify-sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	cache[data] = digest
	return digest
end

local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority = assert(loadstring(authority_bytes, "@" .. authority_path))()({
	raw_sha256 = raw_sha256})
local files = authority.capture_files(repo, {[authority_path] = authority_bytes})
local snapshot = authority.bind_expected_vocabulary(files)
-- Only a current-generation (v3) path may be verified or resumed from. The
-- frozen pre-v3 shards live under their own names and are never a resume
-- source; pointing this verifier at one is a caller error, not a skip.
assert(shard_path == repo .. "/" .. authority.retained_shard_path(first, last),
	"retained shard path changed")
local shard_bytes = read_file(shard_path)
local shard_provenance = authority.preparse_shard_provenance(shard_bytes)
local pinned_snapshot = authority.validate_pinned_authority(repo, scratch,
	shard_provenance)
assert(pinned_snapshot.authority_dag_sha256 == snapshot.authority_dag_sha256,
	"current verifier Authority-DAG differs from the pinned measurement commit")
local full_scan_gate = authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua")
assert(authority.validate_full_scan_gate(full_scan_gate))

local input, output = scratch .. "/verify-labels.bin", scratch .. "/verify-labels.out"
local file = assert(io.open(input, "wb"))
local labels = {}
for index = 0, 4095 do
	local label = ("grudgelands-wp40-extreme-%04d"):format(index)
	labels[index + 1] = label
	assert(file:write(tostring(#label), "\n", label))
end
assert(file:close())
local status, reason, code = os.execute("python3 " .. repo ..
	"/tools/wp40/t2_sha256_batch.py " .. input .. " " .. output)
assert(status == 0 or status == true and reason == "exit" and code == 0)
local hashes = read_file(output)
assert(#hashes == 4096 * 32)
for index = 1, 4096 do cache[labels[index]] = hashes:sub(index * 32 - 31, index * 32) end

local canonical = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local seed_corpus = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local source = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local extreme = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
	scalar_reader = function() error("verification must not materialize geometry") end,
	seed_corpus = seed_corpus, source = source})
local shard = extreme.parse_shard_blob(shard_bytes)
assert(shard.first_index == first and shard.last_index == last)
local pins = shard.pins
-- The shard must carry exactly the stage-S1 authority the checked-in gate
-- pins. The gate itself is re-derived from the live tree by
-- t2_extreme_gate_check.lua, which is the entry gate for every measurement;
-- this verifier deliberately materializes no geometry of its own.
assert(pins.s1_authority_sha256 == full_scan_gate.s1_authority_sha256,
	"retained shard stage-S1 authority differs from the full-scan gate")
assert(pins.s1_source_projection_sha256 ==
	full_scan_gate.s1_source_projection_sha256,
	"retained shard stage-S1 Source projection differs from the full-scan gate")
assert(pins.authority_dag_sha256 == snapshot.authority_dag_sha256 and
	pins.measurement_scope == "R7_SCALAR_MEASUREMENT_ONLY" and
	pins.stage2_status == "pending_selected_four")
assert(authority.verify_git_provenance(repo, scratch, pins.authority_commit,
	pins.authority_tree))
assert(pins.interpreter_id == "luajit" and
	pins.interpreter_launcher == "/usr/bin/luajit" and
	pins.interpreter_path == "/usr/bin/luajit-2.1.1767980792" and
	pins.interpreter_version ==
		"LuaJIT 2.1.1767980792 -- Copyright (C) 2005-2026 Mike Pall. https://luajit.org/")
assert(canonical.hex(raw_sha256(read_file(pins.interpreter_path))) ==
	pins.interpreter_sha256)
assert(authority.verify(repo, snapshot))
print(("WP40 T2 E0 retained shard verified range=%04d..%04d rows_sha256=%s"):format(
	first, last, shard.rows_sha256))
