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
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority = assert(loadstring(authority_bytes, "@" .. authority_path))()({
	raw_sha256 = raw_sha256})
local files = authority.capture_files(repo, {[authority_path] = authority_bytes})
local gate = authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua")
local validator = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua")
local partition_path = "mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua"
local partition_sha256 = hex(raw_sha256(files.files[partition_path]))
assert(authority.validate_full_scan_gate(gate, {
	source_checksum = validator.EXPECTED_SOURCE_CHECKSUM,
	boundary_policy_checksum = validator.EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM,
	partition_sha256 = partition_sha256,
}))
print("WP40 T2 E0 full-scan gate accepted source=" .. gate.source_checksum ..
	" boundary=" .. gate.boundary_policy_checksum ..
	" partition=" .. partition_sha256)
