-- Recorded-evidence reuse for the T2c-E0-C1 v3 conformance.
--
-- The launcher's first choice stays what it always was: re-verify the finished
-- artifact against the CURRENT launch pins.  That only works while HEAD has not
-- moved, so a documentation-only commit used to be enough to declare 24 rows of
-- immutable evidence stale and buy a full rerun.
--
-- This is the second choice, and it never relaxes generation.  All 24 rows must
-- still come from one clean immutable commit; what is re-established here is
-- only the re-verification of finished evidence:
--
--   1. the commit/tree/DAG are read from the final artifact's own bytes, not
--      from git rev-parse HEAD;
--   2. that commit must be a commit object of THIS repository and an ancestor
--      of HEAD;
--   3. its tree must be the recorded tree;
--   4. every member of the pinned closure -- the `paths` roster in
--      t2_extreme_conformance_v3_authority.lua, nothing informal beside it --
--      must be byte-identical between that commit and the current working tree,
--      and the roster's DAG at that commit must be the recorded DAG;
--   5. only then is the finalizer run in verify mode with the RECORDED pins, so
--      the whole final blob is re-derived from all 24 retained result files and
--      every one of them is re-verified by t2_extreme_conformance_verify.lua
--      against the same recorded pins.
--
-- The PUC interpreter is the one input the roster cannot carry: tools/bin/lua51
-- is built per checkout and gitignored, so step 4 can never see it.  Step 5 is
-- what covers it -- the verifier re-hashes the live argv[0] against every row's
-- interpreter_sha256 -- which is why the closure proof alone is not acceptance.
--
-- Byte equality of the final TSV alone is never accepted as proof of closure
-- equality, and any failure here is a refusal: the launcher falls back to its
-- existing stale/recompute path, which is a full rerun.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "recorded evidence scratch required")
local final_scratch = assert(arg[3], "recorded finalizer scratch required")
local output_path = assert(arg[4], "final conformance output required")
assert(arg[5] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"C1 recorded evidence requires plain PUC Lua 5.1")
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"C1 recorded evidence requires the reviewed vendored interpreter")
local function safe_absolute(path)
	assert(type(path) == "string" and path:match("^/[A-Za-z0-9._/-]+$") and
		not path:find("/../", 1, true) and not path:find("/./", 1, true) and
		path:sub(-3) ~= "/.." and path:sub(-2) ~= "/." and
		not path:find("/" .. "/", 1, true), "unsafe C1 recorded evidence path")
end
for _, path in ipairs({repo, scratch, final_scratch, output_path}) do
	safe_absolute(path)
end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%.[A-Za-z0-9]+$"),
	"unsafe C1 recorded evidence scratch")
assert(final_scratch:match(
	"^/tmp/grudgelands%-wp40%-t2%-conformance%-final%.[A-Za-z0-9]+$"),
	"unsafe C1 recorded evidence finalizer scratch")
local retained = repo .. "/tools/wp40/fixtures/t2_extreme_e0/"
assert(output_path == retained .. "conformance-puc-v3.tsv",
	"recorded C1 evidence path changed")
-- The pre-v3 evidence of the 53be77e pool is frozen.  This reader must never be
-- able to name one, in either direction.
assert(not output_path:match("/conformance%-puc%.tsv$") and
	not output_path:match("/rescore%-puc%-%d%d%d%d%.tsv$") and
	not output_path:match("/selected%-puc%-slot%d%d%.tsv$"),
	"recorded C1 evidence names pre-v3 evidence")
local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local artifact_file = io.open(output_path, "rb")
assert(artifact_file, "recorded C1 final artifact is missing")
assert(artifact_file:close())
local artifact_bytes = read_file(output_path)
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local cache, counter = {}, 0
local function raw_sha256(data)
	if cache[data] then return cache[data] end
	counter = counter + 1
	local input, output = scratch .. "/recorded-sha-" .. counter .. ".bin",
		scratch .. "/recorded-sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	cache[data] = digest
	return digest
end
local authority = assert(loadfile(repo ..
	"/tools/wp40/t2_extreme_conformance_v3_authority.lua"))()({
	raw_sha256 = raw_sha256})
-- The finalizer is taken from the same immutable export this script runs out
-- of, exactly like the finalizer resolves its own verifier.
local execution_repo = assert(arg[0]:match("^(.*)/tools/wp40/"),
	"cannot resolve captured C1 recorded evidence check")
safe_absolute(execution_repo)
local finalizer = execution_repo .. "/tools/wp40/t2_extreme_conformance_finalize.lua"
local lua = repo .. "/tools/bin/lua51"
-- The finalizer's own console output is kept out of this script's stdout so the
-- acceptance token below is the only line the launcher has to parse; its
-- recomputed artifact digest is carried into that token instead, and on refusal
-- the whole captured log goes to stderr.
local log_path = final_scratch .. "/recorded-finalize-verify.log"
local artifact_sha256
local recorded = authority.verify_recorded_evidence({repo = repo, scratch = scratch,
	artifact_bytes = artifact_bytes,
	run_finalizer = function(pins)
		local status, reason, code = os.execute(lua .. " " .. finalizer .. " " ..
			repo .. " " .. final_scratch .. " " .. output_path .. " " .. pins.commit ..
			" " .. pins.tree .. " " .. pins.dag .. " verify > " .. log_path .. " 2>&1")
		local log = read_file(log_path)
		if not (status == 0 or status == true and reason == "exit" and code == 0) then
			io.stderr:write(log)
			return false
		end
		artifact_sha256 = log:match(
			"WP40 T2 C1 v3 final conformance verified SHA%-256 ([0-9a-f]+) " ..
			"rescore=20 selected=4")
		if type(artifact_sha256) ~= "string" or #artifact_sha256 ~= 64 then
			io.stderr:write(log)
			return false
		end
		return true
	end})
-- A distinct token.  Neither a fresh run nor a current-pin resume prints it,
-- so a reader can never mistake reused evidence for a new measurement.
print("WP40_T2_C1_V3_RECORDED_EVIDENCE_ACCEPTED\tcommit=" .. recorded.commit ..
	"\ttree=" .. recorded.tree .. "\tdag=" .. recorded.dag ..
	"\tclosure=" .. #authority.paths .. "\tartifact_sha256=" .. artifact_sha256)
