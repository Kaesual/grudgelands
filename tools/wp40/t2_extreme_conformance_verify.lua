local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "verification scratch required")
local kind = assert(arg[3], "result kind required")
local identity_text = assert(arg[4], "result identity required")
local result_path = assert(arg[5], "result path required")
local expected_commit = assert(arg[6], "launch commit required")
local expected_tree = assert(arg[7], "launch tree required")
local expected_dag = assert(arg[8], "launch DAG required")
assert(arg[9] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"C1 verification requires plain PUC Lua 5.1")
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"C1 verification requires the reviewed vendored interpreter")
local function safe_absolute(path)
	assert(type(path) == "string" and path:match("^/[A-Za-z0-9._/-]+$") and
		not path:find("/../", 1, true) and not path:find("/./", 1, true) and
		path:sub(-3) ~= "/.." and path:sub(-2) ~= "/." and
		not path:find("/" .. "/", 1, true), "unsafe C1 verification path")
end
for _, path in ipairs({repo, scratch, result_path}) do safe_absolute(path) end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%-verify%.[A-Za-z0-9]+$") or
	scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%-final%.[A-Za-z0-9]+/" ..
		"verify%-[rs]%-[0-9]+$"), "unsafe C1 verification scratch")
local identity = tonumber(identity_text)
assert(identity and identity % 1 == 0 and tostring(identity) == identity_text)
local expected_path
if kind == "rescore" then
	assert(identity >= 0 and identity <= 4095)
	expected_path = repo .. ("/tools/wp40/fixtures/t2_extreme_e0/" ..
		"rescore-puc-%04d.tsv"):format(identity)
elseif kind == "selected" then
	assert(identity >= 28 and identity <= 31)
	expected_path = repo .. ("/tools/wp40/fixtures/t2_extreme_e0/" ..
		"selected-puc-slot%02d.tsv"):format(identity)
else
	error("C1 result kind changed", 0)
end
assert(result_path == expected_path, "C1 result path changed")
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
	local input, output = scratch .. "/sha-" .. counter .. ".bin",
		scratch .. "/sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	cache[data] = digest
	return digest
end
local function split_lines(blob)
	local result = {}
	for line in blob:gmatch("([^\n]*)\n") do result[#result + 1] = line end
	return result
end
local blob = read_file(result_path)
local header = split_lines(blob)
assert(#header >= 9)
local function field(line, name)
	return assert(line:match("^" .. name .. "\t([^\t]+)$"))
end
local conformance_commit = field(header[7], "conformance_commit")
local conformance_tree = field(header[8], "conformance_tree")
local conformance_dag = field(header[9], "conformance_dag_sha256")
assert(#expected_commit == 40 and expected_commit:match("^[0-9a-f]+$") and
	#expected_tree == 40 and expected_tree:match("^[0-9a-f]+$") and
	#expected_dag == 64 and expected_dag:match("^[0-9a-f]+$"),
	"expected C1 launch pins are invalid")
assert(conformance_commit == expected_commit and conformance_tree == expected_tree and
	conformance_dag == expected_dag,
	"retained result differs from exact C1 launch pins")
local live_authority_path = repo .. "/tools/wp40/t2_extreme_conformance_authority.lua"
local live_authority = assert(loadfile(live_authority_path))()({raw_sha256 = raw_sha256})
assert(live_authority.validate_provenance(repo, scratch,
	{commit = expected_commit, tree = expected_tree}))
local snapshot = live_authority.capture_git(repo, scratch, expected_commit)
assert(snapshot.dag_sha256 == expected_dag, "pinned C1 DAG changed")
local pinned_authority = assert(loadstring(snapshot.files[
	"tools/wp40/t2_extreme_conformance_authority.lua"],
	"@tools/wp40/t2_extreme_conformance_authority.lua"))()({raw_sha256 = raw_sha256})
assert(pinned_authority.capture_git(repo, scratch, expected_commit).dag_sha256 ==
	expected_dag)

local measurement_bytes = snapshot.files["tools/wp40/t2_extreme_authority.lua"]
local measurement = assert(loadstring(measurement_bytes,
	"@tools/wp40/t2_extreme_authority.lua"))()({raw_sha256 = raw_sha256})
local provenance = {authority_commit =
	"53be77ee3dab615be39c2e66b6d24a4adccc3d26",
	authority_tree = "c9ac6639048804f15d76bd02101cf9e3a062e9de",
	authority_dag_sha256 =
	"d059686fb3668627b1ed153e5f54aa5572fd96624e43487b2c157dbc4c505949",
	partition_sha256 =
	"de53e1b5cc0cc3fcaee2d58ce3cc391c637b123d430f234c74e4960ad4bee967"}
local measured = measurement.validate_pinned_authority(repo, scratch, provenance)
local canonical = measurement.load_module(measured,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = measurement.load_module(measured,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = measurement.load_module(measured,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local seed_corpus = measurement.load_module(measured,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local source = measurement.load_module(measured,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local extreme = measurement.load_module(measured,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
		scalar_reader = function() error("verification cannot materialize") end,
		seed_corpus = seed_corpus, source = source})
local conformance = assert(loadstring(snapshot.files[
	"tools/wp40/t2_extreme_conformance.lua"],
	"@tools/wp40/t2_extreme_conformance.lua"))()({raw_sha256 = raw_sha256,
	extreme = extreme, rational_compare = extreme.rational_compare,
	decimal_less = extreme.decimal_less})
local launch_pins = conformance.validate_launch_pins({commit = expected_commit,
	tree = expected_tree, dag = expected_dag})
assert(conformance_commit == launch_pins.commit and
	conformance_tree == launch_pins.tree and conformance_dag == launch_pins.dag,
	"retained result differs from exact C1 launch pins")
local gate = assert(loadstring(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua"],
	"@tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua"))()
local artifact = conformance.parse_artifact(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit.tsv"], gate)
conformance.parse_manifest(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv"], gate)
local slots, _, required = conformance.selected_and_required(artifact, gate,
	extreme.staging_seed)
assert(artifact.headers.merge_interpreter_path == arg[-1] and
	artifact.headers.merge_interpreter_version ==
		"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio" and
	artifact.headers.merge_interpreter_sha256 ==
		conformance.digest(read_file(arg[-1])),
	"verification PUC interpreter differs from retained merge authority")
local pins = launch_pins
if kind == "rescore" then
	local required_set = {}
	for index = 1, #required do required_set[required[index]] = true end
	assert(required_set[identity], "rescore result is outside exact roster")
	local winner_set = {}
	for index = 1, #slots do winner_set[slots[index].candidate_index] = true end
	local expected_sha = conformance.digest(assert(artifact.raw_by_index[identity]) .. "\n")
	local result = conformance.parse_rescore_result(blob)
	assert(result.candidate_decimal == artifact.rows_by_index[identity].decimal and
		result.candidate_role == (winner_set[identity] and "winner" or "endpoint"),
		"rescore candidate identity/role changed")
	conformance.validate_rescore_result(result, gate, identity, expected_sha, pins, arg[-1])
	assert(result.interpreter_sha256 == conformance.digest(read_file(arg[-1])),
		"rescore interpreter bytes changed")
else
	local winner = assert(slots[identity - 27])
	local result = conformance.parse_selected_result(blob)
	conformance.validate_selected_result(result, gate, winner, pins, arg[-1])
	assert(result.interpreter_sha256 == conformance.digest(read_file(arg[-1])),
		"selected interpreter bytes changed")
end
print(("WP40 T2 C1 retained %s verified identity=%d sha256=%s"):format(kind,
	identity, conformance.digest(blob)))
