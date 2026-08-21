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
assert(conformance.assert_v3_result_path(
	"/any/root/tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv",
	"rescore-puc-v3-0000.tsv", "v3 rescore output"))
for _, rejected in ipairs({
	"/any/root/tools/wp40/fixtures/t2_extreme_e0/rescore-puc-0000.tsv",
	"/any/root/tools/wp40/fixtures/t2_extreme_e0/conformance-puc.tsv",
	"tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-0000.tsv",
}) do
	expect_error("v3 rescore output path changed", function()
		conformance.assert_v3_result_path(rejected, "rescore-puc-v3-0000.tsv",
			"v3 rescore output")
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

print("WP40 T2 E0 v3 conformance foundation passed artifact=" ..
	gate.artifact_sha256 .. " manifest=" .. gate.manifest_sha256 ..
	" pool=" .. gate.pool_measurement_commit ..
	" s1=" .. s1.s1_authority_sha256 ..
	" execution_dag=" .. execution_dag ..
	" rescore_count=" .. #required .. " winners=" .. slots[1].candidate_index ..
	"," .. slots[2].candidate_index .. "," .. slots[3].candidate_index ..
	"," .. slots[4].candidate_index)
