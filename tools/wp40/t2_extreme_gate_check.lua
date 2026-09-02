local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(arg[3] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"full-scan entry gate requires plain PUC Lua 5.1")
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"full-scan entry gate requires the vendored interpreter")
local function safe_scratch_path(path)
	assert(type(path) == "string" and
		(path:match("^/tmp/grudgelands%-wp40%-t2%-extreme%.[A-Za-z0-9]+$") or
		 path:match("^/tmp/grudgelands%-wp40%-t2%-extreme%-orchestrator%.[A-Za-z0-9]+$")),
		"unsafe full-scan entry path")
	return path
end
assert(repo:match("^/[A-Za-z0-9._/-]+$"), "unsafe full-scan entry path")
safe_scratch_path(scratch)
assert(not pcall(safe_scratch_path,
	"/tmp/grudgelands-wp40-t2-extreme.X;id;#") and
	not pcall(safe_scratch_path,
		"/tmp/grudgelands-wp40-t2-extreme-orchestrator.X bad") and
	not pcall(safe_scratch_path,
		"/tmp/grudgelands-wp40-t2-extreme.X/"))

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
local counter = 0
local function raw_sha256(data)
	counter = counter + 1
	local input = scratch .. "/gate-sha-" .. counter .. ".bin"
	local output = scratch .. "/gate-sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	return digest
end

local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority = assert(loadstring(authority_bytes, "@" .. authority_path))()({
	raw_sha256 = raw_sha256})
local files = authority.capture_files(repo, {[authority_path] = authority_bytes})
local gate = authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua")
assert(authority.validate_full_scan_gate(gate))

-- This is the single place where the checked-in pool gate is re-derived from
-- the live tree. It builds only the stage-S1 Source projection -- a pure
-- function of the catalog, no seed geometry -- and the stage-S1 authority
-- digest over the S1 module plus its arithmetic surface. partition.lua,
-- catalog.lua bytes and the boundary-displacement policy are deliberately not
-- inputs: the selector cannot read them, so they must not be able to invalidate
-- a measured pool.
local canonical = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local raster = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local validator = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua")
local vocabulary = authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local boundary = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raster = raster,
	raw_sha256 = raw_sha256, source = source, source_validator = validator,
	vocabulary = vocabulary})
local s1_authority = authority.load_module(files,
	"tools/wp40/t2_s1_authority.lua")({raw_sha256 = raw_sha256})
local s1_source_projection_sha256 = boundary.s1_source_checksum()
local s1_authority_sha256 = s1_authority.digest(files.files,
	s1_source_projection_sha256, boundary.PROJECTION_SCHEMA)
assert(gate.s1_source_projection_schema == boundary.PROJECTION_SCHEMA,
	"full-scan gate names a different stage-S1 projection schema")
assert(s1_authority.verify(files.files, s1_source_projection_sha256,
	boundary.PROJECTION_SCHEMA, gate.s1_authority_sha256))
assert(authority.validate_full_scan_gate(gate, {
	s1_authority_sha256 = s1_authority_sha256,
	s1_source_projection_sha256 = s1_source_projection_sha256,
}))
print("WP40 T2 E0 full-scan gate accepted s1_authority=" ..
	s1_authority_sha256 .. " s1_source_projection=" ..
	s1_source_projection_sha256)
