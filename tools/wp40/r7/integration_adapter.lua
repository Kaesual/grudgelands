-- Tool-side bridge from the closed R7 evidence schemas to production-owned
-- APIs. Catalog inspection is available as soon as grug_gathering lands.
-- Runtime evidence deliberately delegates to runtime_adapter.lua, which is
-- added only after the final production session API has been integrated.

local module = {}

local ffi = assert(rawget(_G, "wp40_ffi"), "wp40_ffi injection required")
ffi.cdef[[
	typedef unsigned long size_t;
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]
local crypto = ffi.load("crypto")

local function fail(message)
	error("WP40 R7 integration adapter: " .. message, 0)
end

local function read_file(path)
	local file, message = io.open(path, "rb")
	if not file then fail("cannot read " .. path .. ": " .. tostring(message)) end
	local bytes = file:read("*a")
	file:close()
	return bytes
end

local function raw_sha256(bytes)
	local buffer = ffi.new("unsigned char[32]")
	if crypto.SHA256(bytes, #bytes, buffer) == nil then fail("SHA-256 failed") end
	return ffi.string(buffer, 32)
end

local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end

local function exact_api(api, label)
	if type(api) ~= "table" or getmetatable(api) ~= nil then
		fail(label .. " is not a plain table")
	end
	return api
end

local function catalog_api(repo)
	local path = repo .. "/mods/ITEMS/grug_gathering/catalog.lua"
	local probe = io.open(path, "rb")
	if not probe then
		fail("gathering catalog is not integrated at " .. path)
	end
	probe:close()
	local api = exact_api(dofile(path), "gathering catalog API")
	for _, name in ipairs({"manifest", "p9g_sources", "reuse_sources",
			"cultural_sources", "cultural_registrations"}) do
		if type(api[name]) ~= "function" then fail("catalog API lacks " .. name) end
	end
	return api
end

local function snapshot(api)
	return {
		manifest = api.manifest(),
		p9g_sources = api.p9g_sources(),
		reuse_sources = api.reuse_sources(),
		cultural_sources = api.cultural_sources(),
		cultural_registrations = api.cultural_registrations(),
	}
end

local function verify_source_files(repo, manifest)
	if type(manifest.source_files) ~= "table" or #manifest.source_files ~= 2 then
		fail("catalog source-file population differs")
	end
	local seen = {}
	for index = 1, 2 do
		local row = manifest.source_files[index]
		if type(row) ~= "table" or type(row.path) ~= "string" or
				type(row.sha256) ~= "string" or seen[row.path] then
			fail("catalog source-file row differs")
		end
		seen[row.path] = true
		local actual = hex(raw_sha256(read_file(repo .. "/" .. row.path)))
		if actual ~= row.sha256 then
			fail("catalog source-file digest differs for " .. row.path)
		end
	end
end

function module.raw_sha256(bytes)
	if type(bytes) ~= "string" then fail("SHA-256 input is not bytes") end
	return raw_sha256(bytes)
end

function module.catalog_snapshot(repo)
	local api = catalog_api(repo)
	local first = snapshot(api)
	verify_source_files(repo, first.manifest)

	-- The production API promises defensive copies. Mutating one return must
	-- not affect a later snapshot used by the mapgen environment.
	local expected_first_id = first.p9g_sources[1] and first.p9g_sources[1].id
	local expected_bytes = first.manifest.canonical_bytes
	first.p9g_sources[1].id = "mutated_by_evidence_probe"
	first.manifest.canonical_bytes = "mutated_by_evidence_probe"
	local second = snapshot(api)
	if second.p9g_sources[1].id ~= expected_first_id or
			second.manifest.canonical_bytes ~= expected_bytes then
		fail("catalog API does not return defensive copies")
	end
	return second
end

local function runtime_adapter(repo)
	local path = repo .. "/tools/wp40/r7/runtime_adapter.lua"
	local probe = io.open(path, "rb")
	if not probe then
		fail("runtime evidence API is not integrated; missing " .. path)
	end
	probe:close()
	local adapter = exact_api(dofile(path), "runtime adapter")
	if adapter.schema ~= "grug_wp40_r7_runtime_adapter_v1" then
		fail("runtime adapter schema differs")
	end
	return adapter
end

function module.integration_kat(repo)
	local adapter = runtime_adapter(repo)
	if type(adapter.integration_kat) ~= "function" then
		fail("runtime adapter lacks integration_kat")
	end
	return adapter.integration_kat(repo)
end

function module.sample_assignment(repo)
	local adapter = runtime_adapter(repo)
	if type(adapter.sample_assignment) ~= "function" then
		fail("runtime adapter lacks sample_assignment")
	end
	return adapter.sample_assignment(repo)
end

function module.frontier_access_assignment(repo)
	local adapter = runtime_adapter(repo)
	if type(adapter.frontier_access_assignment) ~= "function" then
		fail("runtime adapter lacks frontier_access_assignment")
	end
	return adapter.frontier_access_assignment(repo)
end

function module.pilot(repo, scratch, seed_slot)
	local adapter = runtime_adapter(repo)
	if type(adapter.pilot) ~= "function" then fail("runtime adapter lacks pilot") end
	return adapter.pilot(repo, scratch, seed_slot)
end

function module.worker(repo, scratch, first_slot, last_slot, projection_sha256)
	local adapter = runtime_adapter(repo)
	if type(adapter.worker) ~= "function" then fail("runtime adapter lacks worker") end
	return adapter.worker(repo, scratch, first_slot, last_slot, projection_sha256)
end

function module.finalize(repo, scratch, worker_paths)
	local adapter = runtime_adapter(repo)
	if type(adapter.finalize) ~= "function" then fail("runtime adapter lacks finalize") end
	return adapter.finalize(repo, scratch, worker_paths)
end

return module
