-- Launcher-side entry points for the four census gates (plan section 6.6).
--
-- The shell launcher owns process discipline and nothing else: every decision
-- it makes -- which seeds are in `W`, which range a shard covers, whether a
-- first record satisfies the contract, whether a resumed shard is trustworthy,
-- whether the projection fits the cap -- is taken here, against
-- t2_census_authority.lua, so the same rule serves the launcher, the worker
-- and the M5 merge.
--
-- usage:
--   t2_census_gate.lua REPO SCRATCH paths
--   t2_census_gate.lua REPO SCRATCH plan W_PATH
--   t2_census_gate.lua REPO SCRATCH cost BUDGET SIZE:COMPLETED:WALL:CPU...
--     one sample per shard; WALL and CPU are that shard's own elapsed and own
--     CPU seconds at its own latest completion, never the launcher's wall clock
--     (section 6.6.3).  BUDGET is the per-seed CPU budget: since 2026-08-18 the
--     wall projection is advisory and only the CPU projection can abort.
--   t2_census_gate.lua REPO SCRATCH cpu_gate HEAD_DATE
--     read the measured CPU gate conf and refuse a missing or stale one
--   t2_census_gate.lua REPO SCRATCH liveness CONSUMED COMPLETED_SINCE ALLOWANCE
--   t2_census_gate.lua REPO SCRATCH module_digest
--   t2_census_gate.lua REPO SCRATCH first_record W_PATH DIGEST MODULES FIRST LAST PATH
--   t2_census_gate.lua REPO SCRATCH verify W_PATH DIGEST MODULES FIRST LAST PATH
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local command = assert(arg[3], "gate command required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local function read_file(path)
	local file = assert(io.open(path, "rb"), "missing file " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

-- The hasher is built on the first digest and not before.  Starting it costs a
-- python3 probe, a compile check, two FIFOs, a responder process and three
-- verified fixed vectors, and section 6.6.3's rolling projection now runs this
-- script once per completed seed -- roughly 4,123 times over a full `W`, on the
-- eight-core host whose contention the projection is trying to measure.  The
-- `cost` and `paths` commands hash nothing, so they now pay nothing; every
-- command that does hash still gets the same responder and the same proofs.
local hasher_handle = nil
local function hasher()
	if not hasher_handle then
		hasher_handle = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
			repo = repo, scratch = scratch})
	end
	return hasher_handle
end
local function close_hasher()
	if hasher_handle then hasher_handle.close() end
end
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = function(data) return hasher().raw_sha256(data) end})

-- A gate that refuses exits 3; anything else that goes wrong exits 1.  The
-- launcher must be able to tell "the contract said no" from "the check itself
-- broke", because a launcher message that names the gate's verdict while the
-- gate actually crashed is the vacuous-gate failure this branch has already
-- shipped twice.
local function refuse(body, ...)
	local ok, message = pcall(body, ...)
	if ok then return message end
	io.stderr:write(tostring(message), "\n")
	io.stderr:flush()
	close_hasher()
	os.exit(3)
end

local function derive()
	local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	return authority.derive_w(corpus,
		read_file(repo .. "/" .. authority.candidates_path), hasher().raw_sha256)
end

-- The cached seed list is re-digested on every read, so a scratch file that
-- was truncated or written by an older run can never quietly redefine `W`
-- between the plan step and the shard that verifies against it.
local function load_w(path, expected_digest)
	local bytes = read_file(path)
	local seeds = {}
	for line in (bytes):gmatch("([^\n]*)\n") do
		seeds[#seeds + 1] = authority.validate_seed_text(line, "cached W seed")
	end
	local digest = authority.digest_of(table.concat(seeds, "\n") .. "\n")
	if digest ~= expected_digest then
		error("WP40 T2 census: the cached W digest is " .. digest ..
			", expected " .. expected_digest, 0)
	end
	return {seeds = seeds, total = #seeds, digest = digest}
end

local function slice(w, first, last)
	local seeds = {}
	for index = first, last do
		seeds[#seeds + 1] = assert(w.seeds[index + 1], "W index " .. index .. " is absent")
	end
	return seeds
end

if command == "module_digest" then
	-- What a resumed shard has to agree with.  The commit is recorded in a
	-- shard header for provenance but is not the resume key: an unrelated docs
	-- commit must not invalidate hours of finished measurement.
	print(authority.module_digest(function(path)
		return read_file(repo .. "/" .. path)
	end))
elseif command == "paths" then
	for index = 1, #authority.module_paths do print(authority.module_paths[index]) end
	for index = 1, #authority.launcher_paths do print(authority.launcher_paths[index]) end
elseif command == "plan" then
	local w_path = assert(arg[4], "W path required")
	local w = derive()
	local file = assert(io.open(w_path, "wb"))
	assert(file:write(table.concat(w.seeds, "\n"), "\n"))
	assert(file:close())
	print(("WP40 T2 census W total=%d digest=%s corpus_slots=%d pool_candidates=%d " ..
		"duplicates=%d order=%s"):format(w.total, w.digest,
		w.derivation.corpus_fixed, w.derivation.pool_candidates,
		w.derivation.duplicates, w.derivation.order))
	local ranges = authority.shard_ranges(w.total)
	for index = 1, #ranges do
		local range = ranges[index]
		print(("WP40 T2 census shard %d range=%d..%d seeds=%d path=%s"):format(
			index, range.first, range.last, range.size,
			authority.census_shard_path(range.first, range.last)))
	end
elseif command == "cost" then
	local budget = tonumber(arg[4] or "")
	assert(budget and budget > 0, "the CPU budget must be a positive number of seconds")
	local samples = {}
	for index = 5, #arg do
		local size, completed, elapsed, cpu =
			arg[index]:match("^(%d+):(%d+):(%d+):(%d+)$")
		assert(size, "cost sample " .. arg[index] ..
			" is not SIZE:COMPLETED:WALL:CPU")
		samples[#samples + 1] = {size = tonumber(size),
			completed = tonumber(completed), elapsed = tonumber(elapsed),
			cpu = tonumber(cpu)}
	end
	-- Section 6.5, 2026-08-18: wall is still projected and still printed -- the
	-- run manifest states the single-seed cost and the projected total in wall
	-- time at a stated worker count, and the operator reads it -- but it is
	-- labelled advisory and no verdict is taken on it.  The host is a
	-- workstation, so wall time separates a contended run from a pathological
	-- one not at all.
	local wall = authority.project_wall_seconds(samples)
	print(("WP40 T2 census cost projection wall_seconds=%d workers=%d " ..
		"per_seed_seconds=%.2f completions=%d shards=%d observed_wall_seconds=%d " ..
		"verdict=advisory"):format(math.floor(wall.wall_seconds),
		wall.worker_count, wall.per_seed_seconds, wall.driver.completed, #samples,
		math.floor(wall.observed_wall_seconds)))
	-- The verdict is decided before the line is printed so the line can carry
	-- it: a projection over the budget that did not abort is only readable as a
	-- deferral if the log says so, and a deferral the log hides is the shape of
	-- gate this branch keeps having to prove is not vacuous.  One line, no tabs
	-- -- the launcher persists both verbatim beside the shards they describe.
	local cpu = authority.project_cpu_seconds(samples)
	local decided, verdict = pcall(authority.check_cpu_gate, cpu, budget)
	print(("WP40 T2 census cpu projection cpu_seconds=%d workers=%d " ..
		"budget_seconds=%.2f per_seed_cpu_seconds=%.2f completions=%d shards=%d " ..
		"observed_cpu_seconds=%d verdict=%s"):format(math.floor(cpu.cpu_seconds),
		cpu.worker_count, budget, cpu.per_seed_cpu_seconds, cpu.driver.completed,
		#samples, math.floor(cpu.observed_cpu_seconds),
		decided and verdict or "aborted"))
	-- Flushed before the refusal so the launcher, which captures both streams
	-- into one buffer, records the projections above the abort that cites them.
	io.stdout:flush()
	if not decided then refuse(error, verdict, 0) end
	print("WP40 T2 census cost gate " .. verdict)
elseif command == "cpu_gate" then
	-- The measured budget, read once before the fan-out.  A full-`W` run that
	-- cannot say what its CPU budget is measured from does not start: an
	-- estimated margin is what section 6.5 replaced.
	local head_date = arg[4]
	local conf_path = repo .. "/" .. authority.cpu_gate_conf_path
	local conf = refuse(function()
		local file = io.open(conf_path, "rb")
		if not file then
			error("WP40 T2 census: no measured CPU gate at " ..
				authority.cpu_gate_conf_path ..
				"; run tools/wp40/run_t2_census_probe.sh (plan section 6.5)", 0)
		end
		local bytes = assert(file:read("*a"))
		assert(file:close())
		return authority.read_cpu_gate_conf(bytes, head_date)
	end)
	print(("WP40 T2 census CPU gate anchor_seconds=%.2f margin=%.2f " ..
		"budget_seconds=%.2f liveness_x_seconds=%.2f probe_date=%s"):format(
		conf.anchor, conf.margin, conf.budget, conf.allowance, conf.probe_date))
elseif command == "liveness" then
	local consumed = tonumber(arg[4] or "")
	local completed_since = tonumber(arg[5] or "")
	local allowance = tonumber(arg[6] or "")
	assert(consumed and completed_since and allowance,
		"liveness needs CONSUMED COMPLETED_SINCE ALLOWANCE")
	local decided, verdict = pcall(authority.check_liveness_gate,
		{consumed = consumed, completed_since = completed_since,
		allowance = allowance})
	print(("WP40 T2 census liveness consumed_cpu_seconds=%d completions_since=%d " ..
		"allowance_seconds=%d verdict=%s"):format(math.floor(consumed),
		completed_since, math.floor(allowance), decided and verdict or "aborted"))
	io.stdout:flush()
	if not decided then refuse(error, verdict, 0) end
elseif command == "merge_kat" then
	-- The M5 gate's pinned half.  The LuaJIT/PUC comparison proves the two
	-- runtimes agree; this proves they agree on the value a reviewed run
	-- measured, which is what stops a silent semantic change in the merge from
	-- passing because both interpreters changed with it.
	local digest = assert(arg[4], "merge artifacts digest required")
	local fixture_path = repo .. "/tools/wp40/fixtures/t2_census/scan_kat_v6.lua"
	local chunk, diagnostic = loadfile(fixture_path)
	assert(chunk, "census KAT fixture missing or invalid: " .. tostring(diagnostic))
	local fixture = chunk()
	refuse(function()
		if type(fixture.merge_artifacts_digest) ~= "string" then
			error("WP40 T2 census: the KAT fixture pins no merge artifacts digest", 0)
		end
		if digest ~= fixture.merge_artifacts_digest then
			error("WP40 T2 census merge artifacts digest is " .. digest ..
				", the KAT fixture pins " .. fixture.merge_artifacts_digest, 0)
		end
	end)
	print("WP40 T2 census merge KAT passed digest=" .. digest)
elseif command == "first_record" or command == "verify" then
	local w_path = assert(arg[4], "W path required")
	local digest = assert(arg[5], "W digest required")
	local modules = assert(arg[6], "module digest required")
	local first = assert(tonumber(arg[7]), "range start required")
	local last = assert(tonumber(arg[8]), "range end required")
	local shard_path = assert(arg[9], "shard path required")
	local w = load_w(w_path, digest)
	authority.validate_shard_range(first, last, w.total)
	authority.validate_census_shard_path(
		authority.census_shard_path(first, last), first, last)
	local expected = {first = first, last = last, w_digest = w.digest,
		module_digest = modules, seeds = slice(w, first, last)}
	local file = io.open(shard_path, "rb")
	if not file then
		if command == "first_record" then
			print(("WP40 T2 census first record range=%04d..%04d ready=0"):format(
				first, last))
			close_hasher()
			os.exit(0)
		end
		error("WP40 T2 census: shard file is absent at " .. shard_path, 0)
	end
	local bytes = assert(file:read("*a"))
	assert(file:close())
	if command == "first_record" then
		local record = refuse(authority.validate_first_record, bytes, expected)
		if not record then
			print(("WP40 T2 census first record range=%04d..%04d ready=0"):format(
				first, last))
		elseif record.stage_reject then
			-- The v4 second record shape: a stage-rejected first seed is a
			-- validated record -- the early-visibility gate holds -- and the
			-- line says so instead of reporting zero sites as if they were
			-- missing.
			print(("WP40 T2 census first record range=%04d..%04d ready=1 seed=%s " ..
				"kind=stage_reject"):format(first, last, record.seed))
		else
			print(("WP40 T2 census first record range=%04d..%04d ready=1 seed=%s " ..
				"sites=%d"):format(first, last, record.seed,
				(record.counts.edge or 0) + (record.counts.perimeter or 0) +
				(record.counts.aperture or 0) + (record.counts.attachment or 0) +
				(record.counts.junction or 0) + (record.counts.bay or 0)))
		end
	else
		local verified = refuse(authority.verify_shard, bytes, expected)
		print(("WP40 T2 census shard verified range=%04d..%04d seeds=%d rows=%d " ..
			"digest=%s"):format(first, last, #verified.seeds,
			(verified.totals.edge or 0), verified.digest))
	end
else
	error("unknown census gate command " .. tostring(command), 0)
end
close_hasher()
