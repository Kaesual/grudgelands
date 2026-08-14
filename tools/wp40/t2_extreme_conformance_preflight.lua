local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "preflight scratch required")
local commit = assert(arg[3], "conformance commit required")
local tree = assert(arg[4], "conformance tree required")
assert(arg[5] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"C1 preflight requires plain PUC Lua 5.1")
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"C1 preflight requires the reviewed vendored interpreter")
assert(repo:match("^/[A-Za-z0-9._/-]+$") and not repo:find("/../", 1, true) and
	not repo:find("/./", 1, true) and repo:sub(-3) ~= "/.." and
	repo:sub(-2) ~= "/." and
	scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%.[A-Za-z0-9]+$"),
	"unsafe C1 preflight path")
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
	local input, output = scratch .. "/preflight-sha-" .. counter .. ".bin",
		scratch .. "/preflight-sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	return digest
end
local authority = assert(loadfile(repo ..
	"/tools/wp40/t2_extreme_conformance_authority.lua"))()({
	raw_sha256 = raw_sha256})
assert(authority.validate_provenance(repo, scratch, {commit = commit, tree = tree}))
local snapshot = authority.capture(repo)
local pinned = authority.capture_git(repo, scratch, commit)
assert(snapshot.file_manifest == pinned.file_manifest and
	snapshot.dag_sha256 == pinned.dag_sha256,
	"working C1 authority differs from the pinned commit")
for index = 1, #authority.paths do
	local path = authority.paths[index]
	assert(snapshot.files[path] == pinned.files[path],
		"working C1 authority byte differs from the pinned commit: " .. path)
end
assert(authority.verify(repo, snapshot))
print("WP40_T2_C1_PREFLIGHT\t" .. commit .. "\t" .. tree .. "\t" ..
	snapshot.dag_sha256)
