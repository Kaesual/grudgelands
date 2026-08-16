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
--   t2_census_gate.lua REPO SCRATCH cost CAP SIZE:COMPLETED:ELAPSED...
--   t2_census_gate.lua REPO SCRATCH first_record W_PATH DIGEST COMMIT FIRST LAST PATH
--   t2_census_gate.lua REPO SCRATCH verify W_PATH DIGEST COMMIT FIRST LAST PATH
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

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = hasher.raw_sha256})

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
	hasher.close()
	os.exit(3)
end

local function derive()
	local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	return authority.derive_w(corpus,
		read_file(repo .. "/" .. authority.candidates_path), hasher.raw_sha256)
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

if command == "paths" then
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
	local cap = tonumber(arg[4] or "")
	assert(cap and cap > 0, "cap must be a positive number of seconds")
	local samples = {}
	for index = 5, #arg do
		local size, completed, elapsed = arg[index]:match("^(%d+):(%d+):(%d+)$")
		assert(size, "cost sample " .. arg[index] .. " is not SIZE:COMPLETED:ELAPSED")
		samples[#samples + 1] = {size = tonumber(size),
			completed = tonumber(completed), elapsed = tonumber(elapsed)}
	end
	local projection = authority.project_wall_seconds(samples)
	print(("WP40 T2 census cost projection wall_seconds=%d workers=%d cap_seconds=%d " ..
		"per_seed_seconds=%.2f"):format(math.floor(projection.wall_seconds),
		projection.worker_count, math.floor(cap),
		projection.slowest.elapsed / projection.slowest.completed))
	refuse(authority.check_cost_gate, projection, cap)
	print("WP40 T2 census cost gate passed")
elseif command == "first_record" or command == "verify" then
	local w_path = assert(arg[4], "W path required")
	local digest = assert(arg[5], "W digest required")
	local commit = assert(arg[6], "commit required")
	local first = assert(tonumber(arg[7]), "range start required")
	local last = assert(tonumber(arg[8]), "range end required")
	local shard_path = assert(arg[9], "shard path required")
	local w = load_w(w_path, digest)
	authority.validate_shard_range(first, last, w.total)
	authority.validate_census_shard_path(
		authority.census_shard_path(first, last), first, last)
	local expected = {first = first, last = last, w_digest = w.digest,
		census_commit = commit, seeds = slice(w, first, last)}
	local file = io.open(shard_path, "rb")
	if not file then
		if command == "first_record" then
			print(("WP40 T2 census first record range=%04d..%04d ready=0"):format(
				first, last))
			hasher.close()
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
hasher.close()
