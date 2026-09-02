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
		"rescore-puc-v3-%04d.tsv"):format(identity)
elseif kind == "selected" then
	assert(identity >= 28 and identity <= 31)
	expected_path = repo .. ("/tools/wp40/fixtures/t2_extreme_e0/" ..
		"selected-puc-v3-slot%02d.tsv"):format(identity)
else
	error("C1 result kind changed", 0)
end
assert(result_path == expected_path, "C1 result path changed")
-- A pre-v3 working paper is not a v3 result and must never be verified as one.
assert(not result_path:match("/rescore%-puc%-%d%d%d%d%.tsv$") and
	not result_path:match("/selected%-puc%-slot%d%d%.tsv$") and
	not result_path:match("/conformance%-puc%.tsv$"),
	"C1 verification target names pre-v3 evidence")
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
assert(#header >= 24)
-- Name-addressed rather than positional.  The v3 schemas insert s1_* and
-- execution_authority_dag_sha256, so a positional read would silently return a
-- neighbouring field instead of failing on a schema it does not know.
local function field(name)
	for index = 1, #header do
		local value = header[index]:match("^" .. name .. "\t([^\t]+)$")
		if value then return value end
	end
	error("retained C1 result is missing " .. name, 0)
end
local conformance_commit = field("conformance_commit")
local conformance_tree = field("conformance_tree")
local conformance_dag = field("conformance_dag_sha256")
assert(#expected_commit == 40 and expected_commit:match("^[0-9a-f]+$") and
	#expected_tree == 40 and expected_tree:match("^[0-9a-f]+$") and
	#expected_dag == 64 and expected_dag:match("^[0-9a-f]+$"),
	"expected C1 launch pins are invalid")
assert(conformance_commit == expected_commit and conformance_tree == expected_tree and
	conformance_dag == expected_dag,
	"retained result differs from exact C1 launch pins")
local live_authority_path = repo ..
	"/tools/wp40/t2_extreme_conformance_v3_authority.lua"
local live_authority = assert(loadfile(live_authority_path))()({raw_sha256 = raw_sha256})
assert(live_authority.validate_provenance(repo, scratch,
	{commit = expected_commit, tree = expected_tree}))
local snapshot = live_authority.capture_git(repo, scratch, expected_commit)
assert(snapshot.dag_sha256 == expected_dag, "pinned C1 DAG changed")
local pinned_authority = assert(loadstring(snapshot.files[
	"tools/wp40/t2_extreme_conformance_v3_authority.lua"],
	"@tools/wp40/t2_extreme_conformance_v3_authority.lua"))()({
		raw_sha256 = raw_sha256})
assert(pinned_authority.capture_git(repo, scratch, expected_commit).dag_sha256 ==
	expected_dag)

local measurement_bytes = snapshot.files["tools/wp40/t2_extreme_authority.lua"]
local measurement = assert(loadstring(measurement_bytes,
	"@tools/wp40/t2_extreme_authority.lua"))()({raw_sha256 = raw_sha256})
local gate = assert(loadstring(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua"],
	"@tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua"))()
-- (R3a) POOL ORIGIN is a HISTORICAL claim: re-materialize the pinned pool
-- commit and require its Authority-DAG.  No partition_sha256 -- v3 pool
-- provenance does not carry one, and demanding it would resurrect exactly the
-- coupling the stage-S1 migration removed.
local provenance = {authority_commit = gate.pool_measurement_commit,
	authority_tree = gate.pool_measurement_tree,
	authority_dag_sha256 = gate.pool_authority_dag_sha256,
	s1_authority_sha256 = gate.s1_authority_sha256,
	s1_source_projection_sha256 = gate.s1_source_projection_sha256}
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
-- (R3b) stage-S1 CURRENCY and (R3c) the executing Authority-DAG are both
-- recomputed from the LIVE tree the conformance runs on, never from the
-- re-materialized pool commit.  The preflight has already proved that the live
-- tree equals the pinned conformance commit for every byte both depend on.
local live_files = measurement.capture_files(repo)
local s1 = conformance.s1_currency(measurement, live_files, gate)
local execution_dag = conformance.execution_authority_dag(measurement, live_files)
local artifact = conformance.parse_artifact(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv"], gate)
conformance.parse_manifest(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit-v3.tsv"], gate)
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
	assert(result.execution_authority_dag_sha256 == execution_dag,
		"rescore executing Authority-DAG differs from the conformance tree")
	assert(result.s1_authority_sha256 == s1.s1_authority_sha256 and
		result.s1_source_projection_sha256 == s1.s1_source_projection_sha256,
		"rescore stage-S1 currency differs from the conformance tree")
else
	local winner = assert(slots[identity - 27])
	local result = conformance.parse_selected_result(blob)
	conformance.validate_selected_result(result, gate, winner, pins, arg[-1])
	assert(result.interpreter_sha256 == conformance.digest(read_file(arg[-1])),
		"selected interpreter bytes changed")
	assert(result.execution_authority_dag_sha256 == execution_dag,
		"selected executing Authority-DAG differs from the conformance tree")
	assert(result.s1_authority_sha256 == s1.s1_authority_sha256 and
		result.s1_source_projection_sha256 == s1.s1_source_projection_sha256,
		"selected stage-S1 currency differs from the conformance tree")
end
print(("WP40 T2 C1 v3 retained %s verified identity=%d sha256=%s"):format(kind,
	identity, conformance.digest(blob)))
