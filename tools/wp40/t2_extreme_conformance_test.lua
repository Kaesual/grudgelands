-- T2c-E0-C1 conformance KAT for the v3 scalar pool.
--
-- It runs entirely against committed bytes and a caller-supplied repository
-- root, so it is independent of where the repository is checked out.  What it
-- deliberately cannot cover is the absolute-path interpreter pin: the retained
-- artifact records merge_interpreter_path
-- /home/jan/projects/grudgelands/tools/bin/lua51, and the workers compare that
-- against their own argv[0], so an end-to-end worker launch only succeeds from
-- that one checkout.  This KAT asserts the recorded VALUE of that pin instead
-- of the runtime comparison.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(arg[3] == nil)
assert(repo:match("^/[A-Za-z0-9._/-]+$") and not repo:find("/../", 1, true) and
	not repo:find("/./", 1, true) and repo:sub(-3) ~= "/.." and
	repo:sub(-2) ~= "/." and
	scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%.[A-Za-z0-9]+$"),
	"unsafe T2 conformance test path")

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
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local seed_corpus = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local source = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local extreme = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
		scalar_reader = function() error("conformance parser cannot materialize") end,
		seed_corpus = seed_corpus, source = source})
local conformance = assert(loadfile(repo ..
	"/tools/wp40/t2_extreme_conformance.lua"))()({raw_sha256 = raw_sha256,
	extreme = extreme, rational_compare = extreme.rational_compare,
	decimal_less = extreme.decimal_less})
local retained = repo .. "/tools/wp40/fixtures/t2_extreme_e0/"
local gate = assert(loadfile(retained .. "conformance_gate_v3.lua"))()
-- The frozen pre-v3 gate is READ here, never written, purely to prove that the
-- two generations cannot be substituted for one another.
local historical_gate = assert(loadfile(retained .. "conformance_gate.lua"))()

-- The pre-v3 fixtures this KAT reads are NEGATIVE inputs, so their bytes can
-- change what it proves.  They must therefore sit inside the v3 DAG roster, and
-- so must this file -- assert that instead of trusting a comment.
local v3_authority = assert(loadfile(repo ..
	"/tools/wp40/t2_extreme_conformance_v3_authority.lua"))()({
	raw_sha256 = raw_sha256})
local v3_roster = v3_authority.paths
local rostered = {}
for index = 1, #v3_roster do rostered[v3_roster[index]] = true end
for _, entry in ipairs({
	"tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua",
	"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit.tsv",
	"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv",
	"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-0000-0511.tsv",
	"tools/wp40/t2_extreme_conformance_test.lua",
	"tools/wp40/t2_extreme_conformance_recorded.lua",
}) do
	assert(rostered[entry], "input is outside the v3 DAG roster: " .. entry)
end

-- ---------------------------------------------------------------- paths ----
-- Two generations, one directory: every v3 name is produced by the module and
-- every pre-v3 name is recognised as pre-v3 evidence, in both directions.
assert(conformance.rescore_result_path(0) ==
	"tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv")
assert(conformance.rescore_result_path(4095) ==
	"tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-4095.tsv")
assert(conformance.selected_result_path(28) ==
	"tools/wp40/fixtures/t2_extreme_e0/selected-puc-v3-slot28.tsv")
assert(conformance.selected_result_path(31) ==
	"tools/wp40/fixtures/t2_extreme_e0/selected-puc-v3-slot31.tsv")
assert(conformance.final_result_path() ==
	"tools/wp40/fixtures/t2_extreme_e0/conformance-puc-v3.tsv")
assert(conformance.retained_shard_path(0, 511) ==
	"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-0000-0511.tsv")
assert(conformance.retained_shard_path(3584, 4095) ==
	"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-3584-4095.tsv")
for _, historical in ipairs({"rescore-puc-0000.tsv", "rescore-puc-4095.tsv",
		"selected-puc-slot28.tsv", "conformance-puc.tsv",
		"/x/tools/wp40/fixtures/t2_extreme_e0/rescore-puc-2192.tsv"}) do
	assert(conformance.is_historical_result_path(historical),
		"pre-v3 evidence name was not recognised: " .. historical)
end
for _, current in ipairs({"rescore-puc-v3-0000.tsv",
		"selected-puc-v3-slot28.tsv", "conformance-puc-v3.tsv",
		"shard-luajit-v3-0000-0511.tsv"}) do
	assert(not conformance.is_historical_result_path(current),
		"v3 name was misread as pre-v3 evidence: " .. current)
end
local fake_root = "/any/root"
assert(conformance.assert_v3_result_path(
	fake_root .. "/tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv",
	fake_root, conformance.rescore_result_path(0), "v3 rescore output"))
assert(conformance.assert_v3_result_path(
	fake_root .. "/tools/wp40/fixtures/t2_extreme_e0/conformance-puc-v3.tsv",
	fake_root, conformance.final_result_path(), "v3 final output"))
-- The guard checks the whole absolute path, so a right-hand suffix match is not
-- enough: a foreign directory, a name glued onto a directory component, a
-- lookalike directory, a bare relative path and a different root are all out.
for _, rejected in ipairs({
	"/etc/rescore-puc-v3-0000.tsv",
	fake_root .. "/xrescore-puc-v3-0000.tsv",
	fake_root .. "/tools/wp40/fixtures/t2_extreme_e0x/rescore-puc-v3-0000.tsv",
	"tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv",
	"/other/root/tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv",
}) do
	expect_error("v3 rescore output path changed", function()
		conformance.assert_v3_result_path(rejected, fake_root,
			conformance.rescore_result_path(0), "v3 rescore output")
	end)
end
expect_error("v3 rescore output names pre-v3 evidence", function()
	conformance.assert_v3_result_path(
		fake_root .. "/tools/wp40/fixtures/t2_extreme_e0/rescore-puc-0000.tsv",
		fake_root, "tools/wp40/fixtures/t2_extreme_e0/rescore-puc-0000.tsv",
		"v3 rescore output")
end)
for _, outside in ipairs({"tmp/rescore-puc-v3-0000.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/nested/rescore-puc-v3-0000.tsv"}) do
	expect_error("v3 rescore output is outside the retained directory", function()
		conformance.assert_v3_result_path(fake_root .. "/" .. outside, fake_root,
			outside, "v3 rescore output")
	end)
end
for _, bad_root in ipairs({"relative/root", "/any/root/", "/any/../root"}) do
	expect_error("v3 rescore output repository root is not a plain absolute path",
		function()
			conformance.assert_v3_result_path(bad_root .. "/x", bad_root,
				conformance.rescore_result_path(0), "v3 rescore output")
		end)
end
for _, range in ipairs({{1, 512}, {0, 512}, {512, 1022}, {3584, 4096}}) do
	expect_error("v3 shard range is not canonical", function()
		conformance.retained_shard_path(range[1], range[2])
	end)
end
expect_error("v3 rescore candidate", function()
	conformance.rescore_result_path(4096)
end)
expect_error("v3 selected slot", function() conformance.selected_result_path(27) end)

-- ------------------------------------------------------- gate and pool ----
assert(conformance.validate_gate(gate) == gate)
assert(gate.schema == "grug_wp40_extreme_conformance_gate_v3")
local artifact_bytes = read_file(retained .. "candidates-luajit-v3.tsv")
local manifest_bytes = read_file(retained .. "manifest-luajit-v3.tsv")
assert(conformance.digest(artifact_bytes) == gate.artifact_sha256 and
	conformance.digest(manifest_bytes) == gate.manifest_sha256,
	"committed v3 artifact/manifest bytes differ from the v3 gate")
local parsed = conformance.parse_artifact(artifact_bytes, gate)
local manifest = conformance.parse_manifest(manifest_bytes, gate)
assert(parsed.headers.schema == "grug_wp40_extreme_measurement_artifact_v3")
-- R6: the interpreter pin is retained, not relaxed.  The recorded value is
-- asserted here; the runtime equality against argv[0] can only be exercised
-- from the checkout that path names.
assert(parsed.headers.merge_interpreter_id == "puc_lua51" and
	parsed.headers.merge_interpreter_path ==
		"/home/jan/projects/grudgelands/tools/bin/lua51" and
	parsed.headers.merge_interpreter_version ==
		"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio" and
	#parsed.headers.merge_interpreter_sha256 == 64,
	"retained v3 merge interpreter pin changed")
for index = 1, 8 do
	local shard = manifest.shards[index]
	assert(shard.path == conformance.retained_shard_path(shard.first, shard.last),
		"v3 manifest names a non-v3 shard path")
	assert(conformance.digest(read_file(repo .. "/" .. shard.path)) == shard.sha256,
		"retained v3 shard digest changed")
	assert(shard.sha256 == gate.shards[index].sha256)
end
local slots, staging, required = conformance.selected_and_required(parsed, gate,
	extreme.staging_seed)
assert(#slots == 4 and #required == 20 and staging.decimal == gate.staging.decimal
	and staging.label == gate.staging.label)
local expected_indices = {0, 511, 512, 1023, 1024, 1047, 1535, 1536, 1713,
	2047, 2048, 2192, 2559, 2560, 3071, 3072, 3438, 3583, 3584, 4095}
for index = 1, #expected_indices do assert(required[index] == expected_indices[index]) end
local expected_winners = {
	{slot = 28, id = "greatest_coast", candidate_index = 2192,
		decimal = "5270046902118333881"},
	{slot = 29, id = "least_coast", candidate_index = 1713,
		decimal = "16178445837170081103"},
	{slot = 30, id = "greatest_noncoast", candidate_index = 1047,
		decimal = "15219119262482319357"},
	{slot = 31, id = "least_noncoast", candidate_index = 3438,
		decimal = "17842018860885445630"},
}
for index = 1, 4 do
	local actual, wanted = slots[index], expected_winners[index]
	assert(actual.slot == wanted.slot and actual.id == wanted.id and
		actual.candidate_index == wanted.candidate_index and
		actual.decimal == wanted.decimal, "v3 winner tuple changed")
	assert(parsed.rows_by_index[wanted.candidate_index].decimal == wanted.decimal)
end

-- ------------------------------------- pre-v3 versus v3 reader crossing ----
-- A pre-v3 gate has measurement_commit/source_checksum/... and no pool_ or
-- s1_ fields, so the v3 reader rejects it before reading a digest.
expect_error("conformance gate has an unknown field", function()
	conformance.validate_gate(historical_gate)
end)
-- ... and the mirrored direction: the exact closed field roster that the
-- historical readers (t2_partition_c2_selected.lua, t2_partition_test.lua's
-- selected_stage2_historical mode) apply to the pre-v3 gate rejects the v3 one.
local historical_gate_fields = {"schema", "status", "measurement_commit",
	"measurement_tree", "authority_dag_sha256", "source_checksum",
	"boundary_policy_checksum", "partition_sha256", "artifact_sha256",
	"manifest_sha256", "candidate_rows_sha256", "shards", "winners", "staging"}
local function closed_against(value, names)
	local allowed, count = {}, 0
	for index = 1, #names do allowed[names[index]] = true end
	for key in pairs(value) do
		if not allowed[key] then return false end
		count = count + 1
	end
	return count == #names
end
assert(closed_against(historical_gate, historical_gate_fields),
	"the frozen pre-v3 gate no longer matches its own historical roster")
assert(not closed_against(gate, historical_gate_fields),
	"the v3 gate would validate against the pre-v3 gate roster")
assert(historical_gate.schema ~= gate.schema)
-- The pre-v3 merged artifact and manifest are rejected by the v3 readers on
-- their digests, and -- with the digest spoofed -- on their shape.
local historical_artifact = read_file(retained .. "candidates-luajit.tsv")
local historical_manifest = read_file(retained .. "manifest-luajit.tsv")
expect_error("measurement artifact digest changed", function()
	conformance.parse_artifact(historical_artifact, gate)
end)
expect_error("measurement manifest digest changed", function()
	conformance.parse_manifest(historical_manifest, gate)
end)
local spoofed_artifact_gate = deep_copy(gate)
spoofed_artifact_gate.artifact_sha256 = conformance.digest(historical_artifact)
expect_error("measurement artifact line count changed", function()
	conformance.parse_artifact(historical_artifact, spoofed_artifact_gate)
end)
local spoofed_manifest_gate = deep_copy(gate)
spoofed_manifest_gate.manifest_sha256 = conformance.digest(historical_manifest)
expect_error("measurement manifest line count/schema changed", function()
	conformance.parse_manifest(historical_manifest, spoofed_manifest_gate)
end)
-- Shard readers do not cross either: v3 bytes are not historical bytes.
expect_error("candidate shard blob header changed", function()
	extreme.parse_shard_blob(read_file(retained .. "shard-luajit-0000-0511.tsv"))
end)
expect_error("historical candidate shard blob header changed", function()
	extreme.parse_historical_shard_blob(
		read_file(retained .. "shard-luajit-v3-0000-0511.tsv"))
end)

-- ---------------------------------------------- three provenance claims ----
-- (b) stage-S1 CURRENCY, recomputed from the tree this KAT runs on.
local s1 = conformance.s1_currency(authority, files, gate)
assert(s1.s1_authority_sha256 == gate.s1_authority_sha256 and
	s1.s1_source_projection_sha256 == gate.s1_source_projection_sha256,
	"stage-S1 currency differs from the v3 gate")
assert(parsed.headers.s1_authority_sha256 == s1.s1_authority_sha256 and
	parsed.headers.s1_source_projection_sha256 ==
		s1.s1_source_projection_sha256)
for _, field in ipairs({"s1_authority_sha256", "s1_source_projection_sha256"}) do
	local corrupt = deep_copy(gate)
	corrupt[field] = string.rep("0", 64)
	expect_error("differs from the conformance gate", function()
		conformance.s1_currency(authority, files, corrupt)
	end)
end
-- (c) EXECUTING CODE: the measurement Authority-DAG of this tree.  It is a
-- different claim from (a) and carries a different field name.
local execution_dag = conformance.execution_authority_dag(authority, files)
assert(#execution_dag == 64 and execution_dag:match("^[0-9a-f]+$"))
-- (a) POOL ORIGIN: historical, re-materialized from the pinned pool commit,
-- with no partition_sha256 -- v3 pool provenance does not carry one.
local pinned = authority.validate_pinned_authority(repo, scratch, {
	authority_commit = gate.pool_measurement_commit,
	authority_tree = gate.pool_measurement_tree,
	authority_dag_sha256 = gate.pool_authority_dag_sha256,
	s1_authority_sha256 = gate.s1_authority_sha256,
	s1_source_projection_sha256 = gate.s1_source_projection_sha256})
assert(pinned.authority_dag_sha256 == gate.pool_authority_dag_sha256,
	"pinned v3 pool Authority-DAG changed")
expect_error("pinned commit Authority-DAG differs", function()
	authority.validate_pinned_authority(repo, scratch, {
		authority_commit = gate.pool_measurement_commit,
		authority_tree = gate.pool_measurement_tree,
		authority_dag_sha256 = string.rep("0", 64)})
end)

-- --------------------------------------------- independent rank replay ----
-- Equal rational scores use the lower decimal, and each chosen decimal is
-- removed before the next category is scanned.
local synthetic = {
	{status = "scored", candidate_index = 1, decimal = "10",
		coast_n = 5, coast_d = 1, noncoast_n = 100, noncoast_d = 1},
	{status = "scored", candidate_index = 2, decimal = "2",
		coast_n = 10, coast_d = 2, noncoast_n = 1000, noncoast_d = 1},
	{status = "scored", candidate_index = 3, decimal = "3",
		coast_n = -5, coast_d = 1, noncoast_n = -100, noncoast_d = 1},
	{status = "scored", candidate_index = 4, decimal = "4",
		coast_n = 0, coast_d = 1, noncoast_n = -200, noncoast_d = 1},
}
local synthetic_slots = conformance.sequential_slots(synthetic)
assert(synthetic_slots[1].candidate_index == 2 and
	synthetic_slots[2].candidate_index == 3 and
	synthetic_slots[3].candidate_index == 1 and
	synthetic_slots[4].candidate_index == 4,
	"rational tie or sequential chosen skip changed")
-- A skipped row is never a candidate, and four scored rows are the minimum.
expect_error("sequential extreme slot has no candidate", function()
	conformance.sequential_slots({{status = "skipped", candidate_index = 1,
		decimal = "1"}})
end)
local three_scored = {synthetic[1], synthetic[2], synthetic[3]}
expect_error("sequential extreme slot has no candidate", function()
	conformance.sequential_slots(three_scored)
end)

-- ------------------------------------------------------ gate mutations ----
-- Each mutation names the exact diagnostic it must produce, and whether the
-- artifact or the manifest reader is the one that has to catch it.
for _, case in ipairs({
	{via = "artifact", fragment = "conformance gate has an unknown field",
		mutate = function(row) row.extra = true end},
	{via = "artifact", fragment = "conformance gate has a missing field",
		mutate = function(row) row.pool_measurement_commit = nil end},
	{via = "artifact", fragment = "conformance gate schema/status changed",
		mutate = function(row) row.schema = "grug_wp40_extreme_conformance_gate_v1" end},
	{via = "artifact", fragment = "pool measurement commit is not a commit/tree id",
		mutate = function(row) row.pool_measurement_commit = "0123456789" end},
	{via = "artifact",
		fragment = "conformance gate s1_authority_sha256 is not lowercase SHA-256",
		mutate = function(row) row.s1_authority_sha256 = "not-a-digest" end},
	{via = "artifact", fragment = "measurement artifact digest changed",
		mutate = function(row) row.artifact_sha256 = string.rep("0", 64) end},
	{via = "artifact", fragment = "measurement artifact pin changed",
		mutate = function(row) row.candidate_rows_sha256 = string.rep("0", 64) end},
	{via = "artifact", fragment = "measurement artifact pin changed",
		mutate = function(row) row.pool_authority_dag_sha256 = string.rep("0", 64) end},
	{via = "artifact", fragment = "measurement artifact pin changed",
		mutate = function(row) row.s1_source_projection_sha256 = string.rep("0", 64) end},
	{via = "artifact", fragment = "conformance winner identity changed",
		mutate = function(row)
			row.winners[1].candidate_index = row.winners[2].candidate_index
		end},
	{via = "artifact", fragment = "conformance winner order changed",
		mutate = function(row) row.winners[1].slot = 27 end},
	{via = "artifact", fragment = "conformance gate does not have eight shards",
		mutate = function(row) table.remove(row.shards) end},
	{via = "artifact", fragment = "conformance shard range changed",
		mutate = function(row) row.shards[3].last = 1534 end},
	{via = "artifact", fragment = "conformance staging identity changed",
		mutate = function(row) row.staging.label = "grudgelands-wp40-seed-xx" end},
	{via = "manifest", fragment = "measurement manifest digest changed",
		mutate = function(row) row.manifest_sha256 = string.rep("0", 64) end},
	{via = "manifest", fragment = "measurement manifest shard roster changed",
		mutate = function(row) row.shards[3].sha256 = string.rep("1", 64) end},
	{via = "manifest", fragment = "measurement manifest pin changed",
		mutate = function(row) row.pool_measurement_tree = string.rep("c", 40) end},
}) do
	local corrupt = deep_copy(gate)
	case.mutate(corrupt)
	expect_error(case.fragment, function()
		if case.via == "artifact" then
			conformance.parse_artifact(artifact_bytes, corrupt)
		else
			conformance.parse_manifest(manifest_bytes, corrupt)
		end
	end)
end
local corrupted_artifact = artifact_bytes:sub(1, #artifact_bytes - 2) .. "x\n"
expect_error("artifact digest", function()
	conformance.parse_artifact(corrupted_artifact, gate)
end)
local corrupted_manifest = manifest_bytes:gsub("shard\t0\t511", "shard\t1\t511", 1)
expect_error("manifest digest", function()
	conformance.parse_manifest(corrupted_manifest, gate)
end)

-- ---------------------------------------------------- rescore results ----
local conformance_pins = {commit = string.rep("1", 40),
	tree = string.rep("2", 40), dag = string.rep("3", 64)}
assert(conformance.validate_launch_pins(conformance_pins))
local stale_launch_pins = {commit = string.rep("9", 40),
	tree = string.rep("a", 40), dag = string.rep("b", 64)}
for _, corrupt in ipairs({
	{commit = conformance_pins.commit, tree = conformance_pins.tree},
	{commit = conformance_pins.commit, tree = conformance_pins.tree,
		dag = conformance_pins.dag, extra = true},
}) do
	expect_error("conformance launch pins", function()
		conformance.validate_launch_pins(corrupt)
	end)
end
local interpreter = repo .. "/tools/bin/lua51"
local row_sha = conformance.digest(assert(parsed.raw_by_index[0]) .. "\n")
local rescore = {schema = "grug_wp40_extreme_puc_rescore_v3", status = "passed",
	scope = "T2C_E0_PUC_ROW_CONFORMANCE_ONLY",
	pool_measurement_commit = gate.pool_measurement_commit,
	pool_measurement_tree = gate.pool_measurement_tree,
	pool_authority_dag_sha256 = gate.pool_authority_dag_sha256,
	s1_authority_sha256 = gate.s1_authority_sha256,
	s1_source_projection_sha256 = gate.s1_source_projection_sha256,
	conformance_commit = conformance_pins.commit,
	conformance_tree = conformance_pins.tree,
	conformance_dag_sha256 = conformance_pins.dag,
	execution_authority_dag_sha256 = execution_dag,
	artifact_sha256 = gate.artifact_sha256,
	manifest_sha256 = gate.manifest_sha256,
	candidate_rows_sha256 = gate.candidate_rows_sha256,
	interpreter_id = "puc_lua51", interpreter_path = interpreter,
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = string.rep("4", 64), candidate_index = 0,
	candidate_decimal = parsed.rows_by_index[0].decimal, candidate_role = "endpoint",
	expected_row_sha256 = row_sha, rescored_row_sha256 = row_sha}
assert(conformance.validate_rescore_result(rescore, gate, 0, row_sha,
	conformance_pins, interpreter))
assert(conformance.assert_launch_pins(rescore, conformance_pins,
	"PUC rescore result"))
expect_error("PUC rescore result launch pins changed", function()
	conformance.assert_launch_pins(rescore, stale_launch_pins, "PUC rescore result")
end)
local rescore_blob = conformance.rescore_result_blob(rescore)
assert(conformance.validate_rescore_result(conformance.parse_rescore_result(rescore_blob),
	gate, 0, row_sha, conformance_pins, interpreter))
-- The v3 row names the three claims separately and never merges them.
assert(rescore_blob:find("pool_authority_dag_sha256\t", 1, true) and
	rescore_blob:find("execution_authority_dag_sha256\t", 1, true) and
	rescore_blob:find("s1_authority_sha256\t", 1, true) and
	not rescore_blob:find("\nauthority_dag_sha256\t", 1, true),
	"v3 rescore row conflates pool and executing provenance")
for _, noncanonical in ipairs({
	(rescore_blob:gsub("candidate_index\t0\n", "candidate_index\t00\n", 1)),
	(rescore_blob:gsub("candidate_index\t0\n", "candidate_index\t0e0\n", 1)),
}) do
	expect_error("PUC rescore result bytes are not canonical", function()
		conformance.parse_rescore_result(noncanonical)
	end)
end
-- A pre-v3 rescore row has the same field COUNT, so only the exact field order
-- separates the two; the v3 reader must reject it on that.
local historical_rescore_fields = {"schema", "status", "scope",
	"measurement_commit", "measurement_tree", "authority_dag_sha256",
	"conformance_commit", "conformance_tree", "conformance_dag_sha256",
	"source_checksum", "boundary_policy_checksum", "partition_sha256",
	"artifact_sha256", "manifest_sha256", "candidate_rows_sha256",
	"interpreter_id", "interpreter_path", "interpreter_version",
	"interpreter_sha256", "candidate_index", "candidate_decimal",
	"candidate_role", "expected_row_sha256", "rescored_row_sha256"}
local historical_rescore_lines = {}
for index = 1, #historical_rescore_fields do
	historical_rescore_lines[index] = historical_rescore_fields[index] .. "\t0"
end
local historical_rescore_blob =
	table.concat(historical_rescore_lines, "\n") .. "\n"
expect_error("PUC rescore result field order changed", function()
	conformance.parse_rescore_result(historical_rescore_blob)
end)
-- ... and the mirrored direction, stated as bytes: a pre-v3 reader addresses
-- field 4 as measurement_commit, and the v3 row does not have that name.
do
	local fourth = assert(select(4, rescore_blob:match(
		"^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)\n")))
	assert(fourth:match("^pool_measurement_commit\t"),
		"v3 rescore field 4 is not pool_measurement_commit")
	assert(historical_rescore_fields[4] == "measurement_commit")
end
for _, mutation in ipairs({
	function(row) row.extra = true end,
	function(row) row.execution_authority_dag_sha256 = nil end,
	function(row) row.schema = "grug_wp40_extreme_puc_rescore_v1" end,
	function(row) row.rescored_row_sha256 = string.rep("5", 64) end,
	function(row) row.conformance_commit = string.rep("6", 40) end,
	function(row) row.s1_authority_sha256 = string.rep("7", 64) end,
	function(row) row.pool_authority_dag_sha256 = string.rep("8", 64) end,
	function(row) row.execution_authority_dag_sha256 = "short" end,
	function(row) row.interpreter_path = "/fake/tools/bin/lua51" end,
}) do
	local corrupt = deep_copy(rescore)
	mutation(corrupt)
	expect_error("PUC rescore", function()
		conformance.validate_rescore_result(corrupt, gate, 0, row_sha,
			conformance_pins, interpreter)
	end)
end

-- --------------------------------------------------- selected results ----
local winner = gate.winners[1]
local selected = {schema = "grug_wp40_extreme_selected_partition_v3",
	status = "passed", scope = "T2C_E0_SELECTED_FOUR_PARTITION_CONFORMANCE_ONLY",
	pool_measurement_commit = gate.pool_measurement_commit,
	pool_measurement_tree = gate.pool_measurement_tree,
	pool_authority_dag_sha256 = gate.pool_authority_dag_sha256,
	s1_authority_sha256 = gate.s1_authority_sha256,
	s1_source_projection_sha256 = gate.s1_source_projection_sha256,
	conformance_commit = conformance_pins.commit,
	conformance_tree = conformance_pins.tree,
	conformance_dag_sha256 = conformance_pins.dag,
	execution_authority_dag_sha256 = execution_dag,
	artifact_sha256 = gate.artifact_sha256,
	manifest_sha256 = gate.manifest_sha256,
	candidate_rows_sha256 = gate.candidate_rows_sha256,
	interpreter_id = "puc_lua51", interpreter_path = interpreter,
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = string.rep("7", 64), slot = winner.slot, slot_id = winner.id,
	candidate_index = winner.candidate_index, candidate_decimal = winner.decimal,
	compiled_sha256 = string.rep("8", 64), columns = 100, base_total = 20,
	planned_water = 40, dry = 60, g = 0, o = 0, r = 0, m = 0,
	schedule_intervals = 10, perimeter_aperture = 2, perimeter_attachment = 8,
	perimeter_dry = 6, transition_count = 8, bank_count = 20, wing_count = 8,
	coast_count = 22, face_count = 38}
assert(conformance.validate_selected_result(selected, gate, winner, conformance_pins,
	interpreter))
assert(conformance.assert_launch_pins(selected, conformance_pins,
	"selected partition result"))
expect_error("selected partition result launch pins changed", function()
	conformance.assert_launch_pins(selected, stale_launch_pins,
		"selected partition result")
end)
-- The final fast path reads these same three exact fields before accepting
-- any retained child count.  A final artifact from a previous clean HEAD is
-- therefore rejected even when all of its child pins agree with each other.
local final_header = {conformance_commit = conformance_pins.commit,
	conformance_tree = conformance_pins.tree,
	conformance_dag_sha256 = conformance_pins.dag}
assert(conformance.assert_launch_pins(final_header, conformance_pins,
	"final conformance artifact"))
expect_error("final conformance artifact launch pins changed", function()
	conformance.assert_launch_pins(final_header, stale_launch_pins,
		"final conformance artifact")
end)
local selected_blob = conformance.selected_result_blob(selected)
assert(conformance.validate_selected_result(conformance.parse_selected_result(selected_blob),
	gate, winner, conformance_pins, interpreter))
for _, noncanonical in ipairs({
	(selected_blob:gsub("slot\t28\n", "slot\t028\n", 1)),
	(selected_blob:gsub("columns\t100\n", "columns\t1e2\n", 1)),
}) do
	expect_error("selected partition result bytes are not canonical", function()
		conformance.parse_selected_result(noncanonical)
	end)
end
local historical_selected_blob = selected_blob
	:gsub("pool_measurement_commit\t", "measurement_commit\t", 1)
	:gsub("pool_measurement_tree\t", "measurement_tree\t", 1)
expect_error("selected partition result field order changed", function()
	conformance.parse_selected_result(historical_selected_blob)
end)
for _, mutation in ipairs({
	function(row) row.extra = true end,
	function(row) row.schema = "grug_wp40_extreme_selected_partition_v1" end,
	function(row) row.execution_authority_dag_sha256 = nil end,
	function(row) row.s1_source_projection_sha256 = string.rep("9", 64) end,
	function(row) row.g = 1 end,
	function(row) row.candidate_decimal = "1" end,
	function(row) row.perimeter_attachment = 7 end,
	function(row) row.base_total = 0 end,
	function(row) row.base_total = row.planned_water + 1 end,
	function(row) row.schedule_intervals = 0 end,
	function(row) row.interpreter_path = "/fake/tools/bin/lua51" end,
}) do
	local corrupt = deep_copy(selected)
	mutation(corrupt)
	expect_error("selected partition", function()
		conformance.validate_selected_result(corrupt, gate, winner, conformance_pins,
			interpreter)
	end)
end

-- ---------------------------------------------- recorded-evidence reuse ----
-- A finished 24-row artifact is immutable evidence of the commit it RECORDS,
-- not of whatever HEAD happens to be.  These cases drive the real closure
-- functions -- exactly the ones the launcher's recorded-evidence branch calls
-- -- against a throwaway git repository with a two-entry synthetic closure, so
-- every git-shaped refusal is executed rather than argued.  The finalizer is
-- the one collaborator that is stubbed: a real 24-row re-derivation is not a
-- KAT, and what has to be proven here is that it is driven with the RECORDED
-- pins and that its refusal is fatal.
-- A closure member is validated as strictly as a repository root, one level
-- down.  Two spellings of one path would otherwise enter a caller-supplied list
-- as two distinct members carrying the same blob, and a "complete closure"
-- would be complete only by arithmetic.
for _, rejected in ipairs({"./tools/closure_a.lua", "tools/./closure_a.lua",
		"tools/closure_a.lua/.", "tools/../tools/closure_a.lua",
		"tools//closure_a.lua", "/tools/closure_a.lua", "tools/closure_a.lua/",
		".hidden.lua", "", 7}) do
	expect_error("unsafe closure member", function()
		v3_authority.closure_equality("/tmp", "/tmp", string.rep("0", 40), {rejected})
	end)
end
expect_error("closure path list repeats tools/closure_a.lua", function()
	v3_authority.closure_equality("/tmp", "/tmp", string.rep("0", 40),
		{"tools/closure_a.lua", "tools/closure_a.lua"})
end)
expect_error("closure path list is empty", function()
	v3_authority.closure_equality("/tmp", "/tmp", string.rep("0", 40), {})
end)
local function shell(command)
	local status, reason, code = os.execute(command)
	return status == 0 or status == true and reason == "exit" and code == 0
end
-- Both streams are captured and both are reported: a failing git command whose
-- diagnostic went to /dev/null and whose assertion said only "git-commit-1.txt"
-- is unactionable, and a global core.hooksPath pre-commit hook is a realistic
-- way to hit exactly that.
local function shell_capture(command, name)
	local output = scratch .. "/" .. name
	local errors = scratch .. "/" .. name .. ".err"
	local completed = shell(command .. " > " .. output .. " 2> " .. errors)
	local text = read_file(output)
	assert(completed, "command failed: " .. command .. "\n" .. text ..
		read_file(errors))
	return (text:gsub("%s+$", ""))
end
local sandbox = shell_capture(
	"mktemp -d -p /tmp grudgelands-wp40-t2-recorded.XXXXXXXX", "sandbox.txt")
assert(sandbox:match("^/tmp/grudgelands%-wp40%-t2%-recorded%.[A-Za-z0-9]+$"),
	"unsafe recorded-evidence sandbox")
-- Every case below runs inside one throwaway repository, so they run inside
-- one pcall: an assertion firing in the middle must not leave an unnamed /tmp
-- git repository behind.  On failure the sandbox is KEPT -- it is the exact
-- git state the failure happened in -- and its path is part of the error, so
-- it is announced evidence rather than a leak.  A clean run removes it.
local function recorded_evidence_cases()
	-- core.hooksPath and commit.gpgsign are neutralised: a developer's global
	-- pre-commit hook or signing key must not decide whether this KAT passes.
	local function git(arguments, name)
		return shell_capture("git -C " .. sandbox .. " -c user.name=wp40" ..
			" -c user.email=wp40@example.invalid -c commit.gpgsign=false" ..
			" -c core.hooksPath=/dev/null " .. arguments, name)
	end
	local function write_sandbox(relative, bytes)
		local file = assert(io.open(sandbox .. "/" .. relative, "wb"))
		assert(file:write(bytes)) assert(file:close())
	end
	local closure_paths = {"tools/closure_a.lua", "tools/closure_b.tsv"}
	assert(shell("mkdir -p " .. sandbox .. "/tools " .. sandbox .. "/docs"))
	write_sandbox("tools/closure_a.lua", "-- closure member a\nreturn 1\n")
	write_sandbox("tools/closure_b.tsv", "member\tb\n")
	write_sandbox("docs/notes.md", "notes revision one\n")
	assert(shell("git -C " .. sandbox .. " -c init.templateDir=" ..
		" -c init.defaultBranch=main init -q"), "the sandbox repository was not created")
	git("add -A", "git-add-1.txt")
	git("commit -q -m recorded", "git-commit-1.txt")
	local recorded_commit = git("rev-parse --verify HEAD", "git-head-1.txt")
	local recorded_tree = git("rev-parse --verify 'HEAD^{tree}'", "git-tree-1.txt")
	assert(#recorded_commit == 40 and recorded_commit:match("^[0-9a-f]+$") and
		#recorded_tree == 40 and recorded_tree:match("^[0-9a-f]+$"),
		"the synthetic recorded commit is not a git id")
	local recorded_dag = v3_authority.capture_git(sandbox, scratch, recorded_commit,
		closure_paths).dag_sha256
	local recorded_pins = {commit = recorded_commit, tree = recorded_tree,
		dag = recorded_dag}
	-- The HEAD movement under test: a file that is NOT a closure member.
	write_sandbox("docs/notes.md", "notes revision two\n")
	git("add -A", "git-add-2.txt")
	git("commit -q -m documentation-only", "git-commit-2.txt")
	local head_commit = git("rev-parse --verify HEAD", "git-head-2.txt")
	local head_tree = git("rev-parse --verify 'HEAD^{tree}'", "git-tree-2.txt")
	assert(head_commit ~= recorded_commit and head_tree ~= recorded_tree,
		"the documentation-only commit did not move HEAD")

	local function final_artifact(pins, options)
		options = options or {}
		local lines = {
			"schema\t" .. (options.schema or "grug_wp40_extreme_puc_conformance_v3"),
			"status\t" .. (options.status or "passed"),
			"scope\tT2C_E0_SELECTED_FOUR_CONFORMANCE_ONLY",
			"stage2_status\tpending_seed_corpus_promotion",
			"conformance_commit\t" .. pins.commit,
			"conformance_tree\t" .. pins.tree,
			"conformance_dag_sha256\t" .. pins.dag,
			"interpreter_id\tpuc_lua51", "rescore_count\t20", "selected_count\t4",
			"rescore\t0\ttools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv\t" ..
				string.rep("a", 64),
			"selected\t28\tgreatest_coast\t2192\t5270046902118333881\t" ..
				string.rep("b", 64) ..
				"\ttools/wp40/fixtures/t2_extreme_e0/selected-puc-v3-slot28.tsv\t" ..
				string.rep("c", 64)}
		if options.append then lines[#lines + 1] = options.append end
		return table.concat(lines, "\n") .. "\n"
	end
	local artifact = final_artifact(recorded_pins)
	local finalizer_calls = {}
	local function stub_finalizer(outcome)
		return function(pins)
			finalizer_calls[#finalizer_calls + 1] = pins
			return outcome
		end
	end
	local function recorded_request(overrides)
		local request = {repo = sandbox, scratch = scratch, paths = closure_paths,
			artifact_bytes = artifact, run_finalizer = stub_finalizer(true)}
		for key, value in pairs(overrides or {}) do request[key] = value end
		return request
	end
	local function refuse(fragment, pins, options)
		expect_error(fragment, function()
			v3_authority.verify_recorded_evidence(recorded_request({
				artifact_bytes = final_artifact(pins, options)}))
		end)
	end

	-- (1) An unrelated documentation-only HEAD movement still permits verification,
	-- and what reaches the finalizer are the RECORDED pins, never HEAD's.
	local accepted = v3_authority.verify_recorded_evidence(recorded_request())
	assert(accepted.commit == recorded_commit and accepted.tree == recorded_tree and
		accepted.dag == recorded_dag, "recorded pins were not the ones proven")
	assert(#finalizer_calls == 1 and finalizer_calls[1].commit == recorded_commit and
		finalizer_calls[1].tree == recorded_tree and
		finalizer_calls[1].dag == recorded_dag,
		"the finalizer was not driven with the recorded pins")

	-- (3) A modified retained row or a modified final artifact fails.  The
	-- re-derivation from all 24 retained rows is the finalizer's verify mode, so
	-- its refusal has to be fatal here ...
	expect_error("recorded evidence failed re-verification against its own commit",
		function()
			v3_authority.verify_recorded_evidence(recorded_request({
				run_finalizer = stub_finalizer(false)}))
		end)
	-- ... and reading the pins is never itself proof that the artifact is intact:
	-- a mutated result row leaves all three pins untouched, which is exactly why
	-- equality of the final TSV alone is not accepted as closure equality.
	local mutated_artifact = (artifact:gsub(string.rep("a", 64), string.rep("d", 64), 1))
	assert(mutated_artifact ~= artifact, "the final artifact mutation did not apply")
	local mutated_pins = v3_authority.parse_recorded_pins(mutated_artifact)
	assert(mutated_pins.commit == recorded_pins.commit and
		mutated_pins.tree == recorded_pins.tree and
		mutated_pins.dag == recorded_pins.dag,
		"a mutated result row changed the recorded pins")
	-- A retained ROW that no longer matches is refused by the very validator the
	-- finalizer drives per row, addressed with the recorded pins.
	local recorded_row = deep_copy(rescore)
	recorded_row.conformance_commit = recorded_pins.commit
	recorded_row.conformance_tree = recorded_pins.tree
	recorded_row.conformance_dag_sha256 = recorded_pins.dag
	assert(conformance.validate_rescore_result(recorded_row, gate, 0, row_sha,
		recorded_pins, interpreter))
	assert(conformance.assert_launch_pins(recorded_row, recorded_pins,
		"PUC rescore result"))
	for _, mutation in ipairs({
		function(row) row.rescored_row_sha256 = string.rep("e", 64) end,
		function(row) row.conformance_commit = string.rep("f", 40) end,
		function(row) row.conformance_dag_sha256 = string.rep("0", 64) end,
	}) do
		local corrupt = deep_copy(recorded_row)
		mutation(corrupt)
		expect_error("PUC rescore", function()
			conformance.validate_rescore_result(corrupt, gate, 0, row_sha, recorded_pins,
				interpreter)
		end)
	end

	-- (4) A missing or invalid recorded commit fails, and every refusal names its
	-- own reason: malformed hex, wrong length, uppercase, a missing pin, a repeated
	-- pin, an object that does not exist, an object that is not a commit, a commit
	-- outside this repository's history, and a commit whose tree is not the
	-- recorded tree.
	refuse("conformance_commit is not a lowercase 40-hex id",
		{commit = "zz" .. string.rep("0", 38), tree = recorded_tree, dag = recorded_dag})
	refuse("conformance_commit is not a lowercase 40-hex id",
		{commit = string.rep("a", 39), tree = recorded_tree, dag = recorded_dag})
	refuse("conformance_commit is not a lowercase 40-hex id",
		{commit = recorded_commit:upper(), tree = recorded_tree, dag = recorded_dag})
	refuse("conformance_tree is not a lowercase 40-hex id",
		{commit = recorded_commit, tree = recorded_tree .. "0", dag = recorded_dag})
	refuse("conformance_dag_sha256 is not a lowercase 64-hex id",
		{commit = recorded_commit, tree = recorded_tree, dag = string.rep("a", 63)})
	expect_error("recorded conformance artifact is missing conformance_tree", function()
		v3_authority.parse_recorded_pins(
			(artifact:gsub("conformance_tree\t[0-9a-f]+\n", "", 1)))
	end)
	expect_error("recorded conformance artifact repeats conformance_commit", function()
		v3_authority.parse_recorded_pins(final_artifact(recorded_pins,
			{append = "conformance_commit\t" .. string.rep("a", 40)}))
	end)
	refuse("recorded commit is not available in this repository",
		{commit = string.rep("d", 40), tree = recorded_tree, dag = recorded_dag})
	refuse("recorded commit is not available in this repository",
		{commit = recorded_tree, tree = recorded_tree, dag = recorded_dag})
	-- git commit-tree writes a real commit object that no ref reaches: it exists,
	-- and it is still not this repository's history.
	local dangling = git("commit-tree " .. recorded_tree .. " -p " .. recorded_commit ..
		" -m dangling", "git-dangling.txt")
	assert(#dangling == 40 and dangling:match("^[0-9a-f]+$") and
		dangling ~= recorded_commit, "the dangling commit was not created")
	refuse("recorded commit is outside repository history",
		{commit = dangling, tree = recorded_tree, dag = recorded_dag})
	refuse("conformance commit/tree changed",
		{commit = recorded_commit, tree = head_tree, dag = recorded_dag})
	-- The recorded DAG must be the pinned closure's DAG at that commit.
	refuse("recorded conformance DAG differs from the pinned closure",
		{commit = recorded_commit, tree = recorded_tree, dag = string.rep("0", 64)})

	-- (5) Pre-v3 evidence cannot satisfy the v3 verifier.  A pre-v3 final artifact
	-- and every result row of either generation carry well-formed conformance_*
	-- pins; only the v3 FINAL artifact schema is accepted, and it must be the
	-- artifact's first line, so a v3 schema appended to foreign bytes is not one
	-- either.  The name side of the same separation is asserted further up:
	-- is_historical_result_path recognises conformance-puc.tsv, and the launcher's
	-- recorded-evidence driver may name conformance-puc-v3.tsv only.
	for _, foreign in ipairs({"grug_wp40_extreme_puc_conformance_v1",
			"grug_wp40_extreme_puc_rescore_v1", "grug_wp40_extreme_puc_rescore_v3",
			"grug_wp40_extreme_selected_partition_v3"}) do
		refuse("recorded conformance artifact is not a v3 final artifact",
			recorded_pins, {schema = foreign})
	end
	refuse("recorded conformance artifact did not pass", recorded_pins,
		{status = "failed"})
	expect_error("recorded conformance artifact is not a v3 final artifact", function()
		v3_authority.parse_recorded_pins("status\tpassed\n" ..
			(artifact:gsub("status\tpassed\n", "", 1)))
	end)

	-- (2) Movement of ONE closure member refuses reuse and demands a rerun, naming
	-- the file.  An uncommitted working-tree edit already counts: what is compared
	-- is the recorded commit against the tree a rerun would run in.
	write_sandbox("tools/closure_a.lua", "-- closure member a, edited\nreturn 2\n")
	expect_error("closure member differs from the recorded commit: tools/closure_a.lua",
		function() v3_authority.verify_recorded_evidence(recorded_request()) end)
	git("add -A", "git-add-3.txt")
	git("commit -q -m closure-member", "git-commit-3.txt")
	-- Committing the edit is the discriminating case: HEAD and the working tree now
	-- agree again, so only a comparison against the RECORDED commit can still
	-- refuse.  A check that read git rev-parse HEAD would accept here.
	expect_error("closure member differs from the recorded commit: tools/closure_a.lua",
		function() v3_authority.verify_recorded_evidence(recorded_request()) end)
	-- The untouched member really is untouched, so the refusal is per file.
	assert(v3_authority.capture_git(sandbox, scratch, recorded_commit,
		{"tools/closure_b.tsv"}).files["tools/closure_b.tsv"] ==
		read_file(sandbox .. "/tools/closure_b.tsv"),
		"the unchanged closure member did not stay equal")
	-- An incomplete closure at the recorded commit is a refusal, never a skip.
	expect_error("pinned conformance file is missing: tools/closure_c.lua", function()
		v3_authority.closure_equality(sandbox, scratch, recorded_commit,
			{"tools/closure_a.lua", "tools/closure_c.lua"})
	end)
	-- Exactly two of these cases ever reached the finalizer: the accepted one and
	-- the one that stubbed a refusal.  Everything else was refused before any
	-- retained evidence was reused at all.
	assert(#finalizer_calls == 2, "a refused case still called the finalizer")
end
local cases_ok, cases_message = pcall(recorded_evidence_cases)
if not cases_ok then
	error("recorded-evidence cases failed; the sandbox git repository was KEPT" ..
		" at " .. sandbox .. " -- inspect it, then remove it: " ..
		tostring(cases_message), 0)
end
assert(shell("rm -rf -- " .. sandbox),
	"the recorded-evidence sandbox was not removed: " .. sandbox)

-- The launcher drives all of the above through
-- t2_extreme_conformance_recorded.lua.  Its own guards are refusals that hold
-- whether or not an accepted artifact exists, so they are exercised here: it
-- may name the v3 final artifact and nothing else -- a pre-v3 name is refused
-- in the same direction as every other v3 guard -- and its scratch directories
-- are pattern-pinned.  Both refusals happen before the script reads or writes
-- anything, so the scratch names below are never created.
local driver = repo .. "/tools/wp40/t2_extreme_conformance_recorded.lua"
local driver_lua = repo .. "/tools/bin/lua51"
local function driver_refuses(fragment, arguments)
	local output = scratch .. "/recorded-driver.txt"
	local refused = not shell(driver_lua .. " " .. driver .. " " .. arguments ..
		" > " .. output .. " 2>&1")
	local text = read_file(output)
	assert(refused and text:find(fragment, 1, true),
		"the recorded-evidence driver did not refuse: " .. text)
end
driver_refuses("recorded C1 evidence path changed",
	repo .. " /tmp/grudgelands-wp40-t2-conformance.katguard" ..
	" /tmp/grudgelands-wp40-t2-conformance-final.katguard " .. repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/conformance-puc.tsv")
driver_refuses("unsafe C1 recorded evidence scratch",
	repo .. " /tmp/katguard" ..
	" /tmp/grudgelands-wp40-t2-conformance-final.katguard " .. repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/conformance-puc-v3.tsv")

print("WP40 T2 E0 v3 conformance foundation passed artifact=" ..
	gate.artifact_sha256 .. " manifest=" .. gate.manifest_sha256 ..
	" pool=" .. gate.pool_measurement_commit ..
	" s1=" .. s1.s1_authority_sha256 ..
	" execution_dag=" .. execution_dag ..
	" recorded_closure=" .. #v3_roster ..
	" rescore_count=" .. #required .. " winners=" .. slots[1].candidate_index ..
	"," .. slots[2].candidate_index .. "," .. slots[3].candidate_index ..
	"," .. slots[4].candidate_index)
