local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local slot_text = assert(arg[3], "C2 provisional diagnostic slot required")
local slot = assert(tonumber(slot_text), "C2 provisional diagnostic slot required")
assert(arg[4] == nil and slot % 1 == 0 and slot >= 28 and slot <= 31 and
	tostring(slot) == slot_text, "C2 provisional diagnostic slot must be exactly 28..31")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-partition%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local function closed(value, names, label)
	assert(type(value) == "table" and getmetatable(value) == nil,
		label .. " is not a plain table")
	local allowed = {}
	for index = 1, #names do allowed[names[index]] = true end
	local count = 0
	for name in pairs(value) do
		assert(allowed[name], label .. " has an extra field")
		count = count + 1
	end
	assert(count == #names, label .. " has a missing field")
end

local gate = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua")
closed(gate, {"schema", "status", "measurement_commit", "measurement_tree",
	"authority_dag_sha256", "source_checksum", "boundary_policy_checksum",
	"partition_sha256", "artifact_sha256", "manifest_sha256",
	"candidate_rows_sha256", "shards", "winners", "staging"},
	"historical conformance gate")
assert(gate.schema == "grug_wp40_extreme_conformance_gate_v1" and
	gate.status == "pending_selected_four_conformance" and
	gate.measurement_commit == "53be77ee3dab615be39c2e66b6d24a4adccc3d26" and
	gate.measurement_tree == "c9ac6639048804f15d76bd02101cf9e3a062e9de" and
	gate.authority_dag_sha256 ==
		"d059686fb3668627b1ed153e5f54aa5572fd96624e43487b2c157dbc4c505949" and
	gate.source_checksum ==
		"154cbc31dea35e0aed06f9525ecb3f2d1ac6fa90f0a71e127da591ed16ed067d" and
	gate.boundary_policy_checksum ==
		"a32f35c4621d84b50f93253fa7e046fe79553796d6b2752f6344ebf4cea1380f" and
	gate.partition_sha256 ==
		"de53e1b5cc0cc3fcaee2d58ce3cc391c637b123d430f234c74e4960ad4bee967" and
	gate.artifact_sha256 ==
		"1096139ae2f98e5105fd9f19a09954f22c0ac63f7d6a0be95b44de259c034017" and
	gate.manifest_sha256 ==
		"23b909d2b4d30ccffce3c09b9a1a987ffe1123136583fe409377a27fd0649a52" and
	gate.candidate_rows_sha256 ==
		"b08e142a16da23f5b7f07c3ec2e6f894705130d1d72fe409998fb5f028deada3",
	"historical provisional-winner provenance changed")

assert(#gate.shards == 8 and #gate.winners == 4)
for index = 1, 8 do
	closed(gate.shards[index], {"first", "last", "sha256"},
		"historical measurement shard")
end
local expected = {
	{slot = 28, candidate_index = 2192, decimal = "5270046902118333881"},
	{slot = 29, candidate_index = 1713, decimal = "16178445837170081103"},
	{slot = 30, candidate_index = 1047, decimal = "15219119262482319357"},
	{slot = 31, candidate_index = 3438, decimal = "17842018860885445630"},
}
for index = 1, 4 do
	local winner, wanted = gate.winners[index], expected[index]
	closed(winner, {"slot", "id", "candidate_index", "decimal", "score_n",
		"score_d"}, "historical provisional winner")
	assert(winner.slot == wanted.slot and
		winner.candidate_index == wanted.candidate_index and
		winner.decimal == wanted.decimal,
		"historical provisional-winner tuple changed")
end
closed(gate.staging, {"label", "decimal"}, "historical staging seed")

local winner = assert(gate.winners[slot - 27])
local request = {seed = winner.decimal}
local chunk = assert(loadfile(repo .. "/tools/wp40/t2_partition_test.lua"))
local test_arg = {[0] = "tools/wp40/t2_partition_test.lua", [1] = repo,
	[2] = scratch, [-1] = arg[-1]}
local environment = setmetatable({arg = test_arg,
	WP40_T2_SELECTED_REQUEST = request}, {__index = _G})
environment._G = environment
setfenv(chunk, environment)
chunk()
assert(type(request.result) == "table" and request.result.transition_count == 8 and
	request.result.bank_count == 20 and request.result.face_count == 38 and
	request.result.coast_count == 22 and request.result.report.g == 0 and
	request.result.report.o == 0 and request.result.report.r == 0 and
	request.result.report.m == 0 and
	type(request.result.edge_inventory_sha256) == "string" and
	#request.result.edge_inventory_sha256 == 64)
print("WP40 T2 C2 historical pre-R18 provisional-winner diagnostic passed slot=" ..
	slot .. " seed=" .. winner.decimal ..
	" status=provisional_no_promotion")
