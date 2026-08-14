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
local expected_path = repo .. ("/tools/wp40/fixtures/t2_extreme_e0/" ..
	"shard-luajit-%04d-%04d.tsv"):format(first, last)
assert(shard_path == expected_path, "retained shard path changed")

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
local shard = extreme.parse_shard_blob(read_file(shard_path))
assert(shard.first_index == first and shard.last_index == last)
local pins = shard.pins
assert(pins.source_checksum ==
	"9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68" and
	pins.boundary_policy_checksum ==
	"3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140")
assert(pins.authority_dag_sha256 == snapshot.authority_dag_sha256 and
	pins.measurement_scope == "R7_SCALAR_MEASUREMENT_ONLY" and
	pins.stage2_status == "blocked")
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
