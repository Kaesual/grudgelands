-- Negative proofs for the four census launcher gates (plan section 6.6.2-4
-- and 6.6.7).  Every gate is exercised on the decision function the launcher
-- and the worker actually call, once positively and once per way the contract
-- says it must abort.
--
-- Written because a happy-path run is not evidence: this branch already
-- shipped a verification run that reported success with zero workers started
-- and a ripgrep gate that passed vacuously, and both would have survived any
-- test that only asserted the good case.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local function read_file(path)
	local file = assert(io.open(path, "rb"), "missing file " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local function write_file(path, bytes)
	local file = assert(io.open(path, "wb"))
	assert(file:write(bytes)) assert(file:close())
end
local function to_hex(value)
	return (value:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = hasher.raw_sha256})

local checks, refusals = 0, 0
local function check(condition, label)
	checks = checks + 1
	if not condition then error("census gate test failed: " .. label, 0) end
end
-- A negative proof only counts when the call fails *for the stated reason*:
-- an abort on an unrelated typo in the fixture would otherwise read as the
-- gate working.
local function refuses(label, fragment, body, ...)
	checks, refusals = checks + 1, refusals + 1
	local ok, message = pcall(body, ...)
	if ok then error("census gate test: " .. label .. " did not abort", 0) end
	message = tostring(message)
	if not message:find(fragment, 1, true) then
		error("census gate test: " .. label .. " aborted on the wrong reason: " ..
			message, 0)
	end
end

-- ---------------------------------------------------------------- W and ranges
local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local candidate_bytes = read_file(repo .. "/" .. authority.candidates_path)
local w = authority.derive_w(corpus, candidate_bytes, hasher.raw_sha256)
check(w.total == 4123, "W holds " .. w.total .. " seeds")
check(w.seeds[1] == "0", "W does not start at seed 0")
check(w.seeds[w.total] == "18446744073709551615", "W does not end at max-u64")
check(w.derivation.duplicates == 0, "W deduplicated unexpectedly")
check(#w.digest == 64, "W digest is not a hex digest")
local again = authority.derive_w(corpus, candidate_bytes, hasher.raw_sha256)
check(again.digest == w.digest, "W derivation is not reproducible")
for index = 2, w.total do
	check(authority.decimal_less(w.seeds[index - 1], w.seeds[index]),
		"W is not in ascending canonical order at index " .. index)
end
refuses("a candidate artifact with a corrupted decimal", "corpus label rule",
	function()
		local broken = candidate_bytes:gsub("\t3318027308425330859\t",
			"\t3318027308425330860\t", 1)
		authority.derive_w(corpus, broken, hasher.raw_sha256)
	end)
refuses("a candidate artifact with a dropped row", "holds 4095 rows",
	function()
		local broken = candidate_bytes:gsub("\n0\tscored\t[^\n]*", "", 1)
		authority.derive_w(corpus, broken, hasher.raw_sha256)
	end)

local ranges = authority.shard_ranges(w.total)
check(#ranges == authority.worker_count, "shard count changed")
local covered = 0
for index = 1, #ranges do
	check(ranges[index].first == covered, "shard " .. index .. " does not abut")
	covered = ranges[index].last + 1
end
check(covered == w.total, "the shard ranges do not cover W")
refuses("a range that is not one of the eight", "canonical shard ranges",
	authority.validate_shard_range, 0, 63, w.total)
check(authority.validate_shard_range(ranges[1].first, ranges[1].last, w.total) == 1,
	"the first canonical range was rejected")

-- ------------------------------------------------------------ shard path names
local shard_path = authority.census_shard_path(ranges[1].first, ranges[1].last)
check(shard_path == "tools/wp40/results/t2_census/census-scan-v6-0000-0515.tsv",
	"census shard path changed: " .. shard_path)
check(not shard_path:find("shard-luajit", 1, true),
	"census shard path collides with the pool pattern")
check(authority.assert_disjoint_from_pool(0, 515), "pool disjointness check failed")
-- Since v6 the collision set is four patterns rather than two: both extreme
-- pool shard names and the v4 and v5 census generations, which stay on disk as
-- the prior records (contracts 9.3).  The disjointness is proven over every
-- canonical range, not just the first, because the rule is about the formatted
-- name and only a formatted name can break it -- and both directions are
-- proven, so a stem rule that had quietly started refusing v6 outright would
-- fail here rather than at a full-`W` start.
local earlier_shard_stems = {"shard-luajit-v3", "shard-luajit",
	"census-scan-v4", "census-scan-v5"}
for index = 1, #ranges do
	local range = ranges[index]
	check(authority.assert_disjoint_from_pool(range.first, range.last),
		"the v6 shard name for range " .. index .. " was refused as a collision")
	local name = authority.census_shard_path(range.first, range.last)
	for stem_index = 1, #earlier_shard_stems do
		check(not name:find(earlier_shard_stems[stem_index], 1, true),
			"the v6 shard name " .. name .. " carries the earlier shard stem " ..
				earlier_shard_stems[stem_index])
	end
end
refuses("a shard path that is not canonical", "not the canonical census path",
	authority.validate_census_shard_path, "tools/wp40/results/t2_census/other.tsv",
	0, 515)
refuses("a free run writing a shard file name", "must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v6-0000-0515.tsv")
refuses("a free run writing a stale M1 shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan1-v1-0000-0515.tsv")
refuses("a free run writing into the shard directory", "must not write into",
	authority.validate_free_output_path,
	"/home/x/tools/wp40/results/t2_census/free.tsv")

-- ------------------------------------------------------------------- GO gate
check(authority.check_go_token(nil, w.digest, authority.free_seed_budget),
	"a free-budget run was refused")
refuses("a full-W slice without the token", "needs the explicit GO token",
	authority.check_go_token, nil, w.digest, ranges[1].size)
refuses("an empty token on a gated slice", "needs the explicit GO token",
	authority.check_go_token, "", w.digest, ranges[1].size)
refuses("a token for a different W", "does not match this W",
	authority.check_go_token, string.rep("a", 64), w.digest, ranges[1].size)
refuses("a stale token on a free run", "does not match this W",
	authority.check_go_token, string.rep("b", 64), w.digest, 2)
check(authority.check_go_token(w.digest, w.digest, ranges[1].size),
	"the matching token was refused")

-- ----------------------------------------------------------------- cost gate
local cap = authority.wall_cap_seconds
-- Two completions per shard at the same 25 s and 24 s rates the single-sample
-- fixture used to carry: since 2026-08-16 a verdict needs a shard that has
-- answered twice, so a one-completion fixture proves deferral, not refusal.
local inside = authority.project_wall_seconds({
	{size = 516, completed = 2, elapsed = 50},
	{size = 515, completed = 2, elapsed = 48}})
check(math.floor(inside.wall_seconds) == 12900,
	"projection changed: " .. inside.wall_seconds)
check(authority.check_cost_gate(inside), "an inside-cap projection was refused")
-- Section 6.5's cap, re-decided 2026-08-16 from eight hours to nine.  Checked
-- here rather than assumed, because every pinned projection below is a
-- statement about which side of this number it falls on.
check(cap == 32400, "the section-6.5 wall cap changed: " .. cap)
-- Retired as a kill criterion 2026-08-18.  The launcher restated it as its
-- WP40_CENSUS_WALL_CAP_SECONDS default until then; what is checked now is that
-- the copy is *gone*, because a wall cap left in the launcher would be a second
-- gate nobody decided to keep.  The replays below still drive the estimator
-- through this number: they are its pinned behaviour in the domain they were
-- measured in, and the CPU gate is the same estimator.
local launcher_source = read_file(repo .. "/tools/wp40/run_t2_census.sh")
check(launcher_source:find("WALL_CAP", 1, true) == nil,
	"the launcher still carries a wall cap after the 2026-08-18 retirement")
-- The trap section 6.5 names: 4,123 worker-seconds per seed-second is a
-- nine-hour overrun in wall time only if the projection stays per shard.
local over = authority.project_wall_seconds({
	{size = 516, completed = 2, elapsed = 130}})
check(math.floor(over.wall_seconds) == 33540, "overrun projection changed")
refuses("a projection past the nine-hour cap", "exceeds the",
	authority.check_cost_gate, over)
refuses("a projection past a lowered cap", "exceeds the",
	authority.check_cost_gate, inside, 600)
refuses("a projection from no completions", "at least one completed sample",
	authority.project_wall_seconds, {})
refuses("a projection from a shard that completed nothing", "completed no seed",
	authority.project_wall_seconds, {{size = 516, completed = 0, elapsed = 30}})

-- Section 6.6.3, the rolling estimate.  A cold first seed is an observation:
-- it is reported, it is never decisive, and it does not mask a shard that has
-- answered twice from over the cap.
check(authority.cost_verdict_min_completions == 2,
	"the cost verdict no longer needs two completions")
local cold = authority.project_wall_seconds({
	{size = 516, completed = 1, elapsed = 71},
	{size = 515, completed = 1, elapsed = 36}})
check(cold.decisive == false, "a one-completion fleet was treated as decisive")
check(math.floor(cold.observed_wall_seconds) == 36636,
	"the cold observation changed: " .. cold.observed_wall_seconds)
check(cold.observed_wall_seconds > cap, "the cold observation is not over the cap")
check(authority.check_cost_gate(cold) == "deferred",
	"an over-cap single sample was not deferred")
check(authority.check_cost_gate(cold, 600) == "deferred",
	"an over-cap single sample was not deferred against a lowered cap")
-- Deferral has no ceiling of its own, by decision: a fleet whose every shard
-- has completed exactly one seed has told the gate nothing about its rate, and
-- how far over the cap that one observation lands does not change that.  What
-- bounds the deferral is the next completion, not a number here.
check(authority.check_cost_gate(authority.project_wall_seconds({
		{size = 516, completed = 1, elapsed = 800},
		{size = 515, completed = 1, elapsed = 800}})) == "deferred",
	"a fleet 12x over the cap on single samples was not deferred")
-- The other direction of the same rule: deferral belongs to the verdict, not
-- to the fleet.  One shard stalled on its first seed must not buy seven others
-- an exemption -- that would be a gate that cannot fire, which is the failure
-- this file exists to catch.
local stalled = authority.project_wall_seconds({
	{size = 516, completed = 1, elapsed = 3600},
	{size = 515, completed = 3, elapsed = 213}})
check(math.floor(stalled.observed_wall_seconds) == 1857600,
	"the stalled observation changed: " .. stalled.observed_wall_seconds)
check(math.floor(stalled.wall_seconds) == 36565,
	"the decisive projection followed the stalled shard: " .. stalled.wall_seconds)
refuses("a stalled shard masking seven that are over the cap", "exceeds the",
	authority.check_cost_gate, stalled)

-- The launcher reads each shard's own progress line, so the gate can be
-- replayed exactly: give every shard its per-seed wall times, walk the
-- completion events in global time order and evaluate at each one, from the
-- event where every shard has a completion -- which is when the launcher first
-- projects.
local census_sizes = {516, 516, 516, 515, 515, 515, 515, 515}
local function replay_cost(fleet, limit)
	local events = {}
	for index = 1, #fleet do
		local clock = 0
		for step = 1, #fleet[index].seconds do
			clock = clock + fleet[index].seconds[step]
			events[#events + 1] = {time = clock, shard = index, completed = step}
		end
	end
	table.sort(events, function(left, right)
		if left.time ~= right.time then return left.time < right.time end
		return left.shard < right.shard
	end)
	local latest, seen, verdicts = {}, 0, {}
	for _, event in ipairs(events) do
		if not latest[event.shard] then seen = seen + 1 end
		latest[event.shard] = {size = fleet[event.shard].size,
			completed = event.completed, elapsed = event.time}
		if seen == #fleet then
			local samples = {}
			for index = 1, #fleet do samples[#samples + 1] = latest[index] end
			local projection = authority.project_wall_seconds(samples)
			local decided, verdict = pcall(authority.check_cost_gate, projection, limit)
			verdicts[#verdicts + 1] = {time = event.time, projection = projection,
				verdict = decided and verdict or "aborted"}
			if not decided then return verdicts, event.time end
		end
	end
	return verdicts, nil
end
-- The highest projection that was ever allowed to decide anything in a replay.
-- A run's last verdict is not its worst: the estimate converges downwards, so
-- the number a cap has to clear is this one.
local function peak_decisive(verdicts)
	local peak = 0
	for _, entry in ipairs(verdicts) do
		if entry.projection.decisive and entry.projection.wall_seconds > peak then
			peak = entry.projection.wall_seconds
		end
	end
	return peak
end
local function fleet_of(first_seconds, steady, seeds)
	local fleet = {}
	for index = 1, #census_sizes do
		local seconds = {first_seconds[index]}
		for _ = 2, seeds do seconds[#seconds + 1] = steady end
		fleet[index] = {size = census_sizes[index], seconds = seconds}
	end
	return fleet
end

-- The 2026-08-16 start minute, as measured: five shards at ~36 s and three
-- cold outliers at 51/53/70 s on their first seed, then the M4 steady state.
-- Solo re-measurement of those three seeds gave 29-32 s, identical to the
-- control, so the outliers were the host and the old gate aborted on them.
local first_minute = {36, 36, 51, 37, 36, 53, 37, 70}
local real_verdicts, real_abort = replay_cost(fleet_of(first_minute, 36, 12), cap)
check(real_abort == nil,
	"the 2026-08-16 start-minute pattern still aborts, at " .. tostring(real_abort) .. "s")
check(#real_verdicts > 1, "the estimate was not re-taken after the first projection")
check(real_verdicts[1].time == 70, "the first projection no longer lands on the 70 s seed")
check(real_verdicts[1].projection.observed_wall_seconds > cap,
	"the replay no longer sees the cold 70 s outlier at all")
local worst = 0
for _, entry in ipairs(real_verdicts) do
	check(entry.verdict == "passed" or entry.verdict == "deferred",
		"the start-minute pattern produced verdict " .. entry.verdict)
	if entry.projection.decisive and entry.projection.wall_seconds > worst then
		worst = entry.projection.wall_seconds
	end
end
-- The tightest decisive moment of that pattern, pinned: the 70 s shard's second
-- completion at 106 s projects 27,295 s, 5.2% under the cap.  The margin is
-- thin and belongs in the record rather than in a comment nobody rechecks.
check(math.floor(worst) == 27295, "the tightest real-pattern projection changed: " .. worst)
-- The same pattern at the slow edge of the M4 band still clears it.
check(select(2, replay_cost(fleet_of(first_minute, 39, 12), cap)) == nil,
	"the start-minute pattern aborts at a 39 s steady state")

-- The second measured borderline case, and the one the cap was re-decided
-- over: the full-`W` start of 2026-08-16 whose shard 1 took 51, 52 and 65 s on
-- seeds 0-2 while the other seven ran 34-39.  Every per-seed time here is that
-- run's own, so the replay reproduces its log: 26,316 s deferred on the first
-- completions, and a decisive peak of 28,896 s at 168 s -- 0.33% over the
-- eight-hour cap that aborted it, while the corpus ETA read 22,728 s.
local churn_seconds = {
	{51, 52, 65}, {35, 37, 35}, {37, 34, 36, 51}, {36, 37, 36, 51},
	{35, 38, 34, 37}, {37, 35, 38, 39}, {37, 35, 37, 36}, {38, 37, 35, 35}}
local churn = {}
for index = 1, #census_sizes do
	churn[index] = {size = census_sizes[index], seconds = churn_seconds[index]}
end
local churn_verdicts, churn_abort = replay_cost(churn, cap)
check(churn_abort == nil, "the 2026-08-16 SMT-churn pattern aborts at " ..
	tostring(churn_abort) .. "s under the re-decided cap")
check(math.floor(churn_verdicts[1].projection.observed_wall_seconds) == 26316,
	"the churn replay no longer starts where the run did")
local churn_peak = peak_decisive(churn_verdicts)
check(math.floor(churn_peak) == 28896, "the churn peak changed: " .. churn_peak)
-- And the same fleet against the cap it was measured under, which is the whole
-- content of the re-decision: nothing about the run changed, the threshold did.
check(select(2, replay_cost(churn, 28800)) == 168,
	"the churn pattern no longer aborts under the retired eight-hour cap")

-- Where two completions put the trigger.  Under the retired cap this fleet --
-- a 53 s cold first seed and a 60 s second, 56.5 s per seed against a 55.81 s
-- budget -- aborted seven shards that were on a 5.2 h pace, and that near-miss
-- is half of why the cap moved.  At 32,400 s the budget is 62.79 s per seed
-- and the same fleet passes; the flip is the intended effect, not a slackened
-- estimator, and the trigger is re-pinned one row below.
local tight = {}
for index = 1, #census_sizes do
	tight[index] = {size = census_sizes[index], seconds = {36, 36, 36, 36}}
end
tight[3] = {size = census_sizes[3], seconds = {53, 60, 36, 36}}
local tight_verdicts, tight_abort = replay_cost(tight, cap)
check(tight_abort == nil, "the 56.5 s/seed borderline fleet still aborts at " ..
	tostring(tight_abort) .. "s")
check(math.floor(peak_decisive(tight_verdicts)) == 29154,
	"the borderline projection changed")
check(select(2, replay_cost(tight, 28800)) == 113,
	"the borderline fleet no longer aborts under the retired eight-hour cap")
-- The trigger at the new cap: 32,400 s over 516 seeds is 62.79 s per seed, so
-- 53 s followed by 73 s is the first two-completion pair that still refuses.
local trigger = {}
for index = 1, #census_sizes do
	trigger[index] = {size = census_sizes[index], seconds = {36, 36, 36, 36}}
end
trigger[3] = {size = census_sizes[3], seconds = {53, 73, 36, 36}}
local trigger_verdicts, trigger_abort = replay_cost(trigger, cap)
check(trigger_abort == 126, "the two-completion trigger moved: aborted at " ..
	tostring(trigger_abort) .. "s, expected the slow shard's second completion")
check(math.floor(peak_decisive(trigger_verdicts)) == 32508,
	"the trigger projection changed")

-- The direction the gate exists for: a fleet that really is delivering 71 s per
-- seed must still abort in the run's first minutes, not run for nine hours.
local slow_verdicts, slow_abort = replay_cost(
	fleet_of({71, 71, 71, 71, 71, 71, 71, 71}, 71, 12), cap)
check(slow_abort == 142, "an all-71 s fleet aborts at " .. tostring(slow_abort) ..
	"s, not on its second completions")
check(slow_verdicts[#slow_verdicts].verdict == "aborted",
	"the all-71 s replay did not end in an abort")
check(slow_verdicts[1].verdict == "deferred",
	"the all-71 s fleet was judged on its first completions after all")

-- ------------------------------------------------------------- CPU gate
-- Section 6.5, 2026-08-18: the hard abort moved to the CPU domain, where
-- intrinsic pathology and host contention separate.  The fixtures here are
-- fabricated shard *logs* rather than samples, because the launcher's input is
-- the workers' progress lines: a worker that renamed a field or a launcher that
-- stopped reading one would pass a sample-level test and then fail a run.
local launcher_progress_fields =
	"completed=([0-9]+)/[0-9]+ wall_seconds=([0-9]+) cpu_seconds=([0-9]+)"
check(launcher_source:find(launcher_progress_fields, 1, true) ~= nil,
	"the launcher no longer reads completed, wall and CPU off one progress line")
-- Every worker of a full-`W` fleet is launched under it (section 6.5: user work
-- preempts the fleet, the run stretches instead of the user yielding the host).
check(launcher_source:find("chrt --idle 0", 1, true) ~= nil and
	launcher_source:find("nice -n19", 1, true) ~= nil,
	"the launcher no longer starts its workers under idle scheduling")

local function shard_log(first, last, per_seed_wall, per_seed_cpu, completed)
	local total = last - first + 1
	local lines = {}
	for index = 1, completed do
		lines[#lines + 1] = authority.shard_progress_line({first = first,
			last = last, completed = index, total = total,
			wall_seconds = per_seed_wall * index, cpu_seconds = per_seed_cpu * index,
			eta_seconds = per_seed_wall * (total - index)})
	end
	return table.concat(lines, "\n") .. "\n"
end
-- The launcher's own reading of that log: the last progress line, and the three
-- fields its pattern names.
local function sample_of(size, log)
	local line
	for candidate in (log):gmatch("([^\n]*)\n") do
		if candidate:find("WP40 T2 census shard progress ", 1, true) == 1 then
			line = candidate
		end
	end
	check(line ~= nil, "the fabricated shard log holds no progress line")
	local completed, wall, cpu = line:match(
		"completed=(%d+)/%d+ wall_seconds=(%d+) cpu_seconds=(%d+)")
	check(completed ~= nil,
		"the worker's progress line lost a field the launcher reads: " .. line)
	return {size = size, completed = tonumber(completed),
		elapsed = tonumber(wall), cpu = tonumber(cpu)}
end
refuses("a progress line claiming more completions than the shard has seeds",
	"reports 3 of 2 seeds", authority.shard_progress_line,
	{first = 0, last = 1, completed = 3, total = 2, wall_seconds = 1,
	cpu_seconds = 1, eta_seconds = 0})

-- A budget of the shape the probe writes: 35 s of anchor at a 1.8x measured
-- margin is 63 s of CPU per seed, against this host's 32-39 s steady state.
local cpu_budget = authority.cpu_budget_seconds(35, 1.8)
check(math.abs(cpu_budget - 63) < 1e-9, "the CPU budget arithmetic changed: " ..
	cpu_budget)
refuses("a contention margin below one", "at least 1",
	authority.cpu_budget_seconds, 35, 0.9)
refuses("a CPU anchor of zero", "positive number",
	authority.cpu_budget_seconds, 0, 1.8)

-- Under budget: two shards two completions in at 36 s of CPU per seed, with
-- wall running well ahead of CPU because the host is busy with something else.
-- That is the case the wall cap used to kill and this gate must not.
local under = {sample_of(516, shard_log(0, 515, 120, 36, 2)),
	sample_of(515, shard_log(516, 1030, 118, 35, 2))}
local under_cpu = authority.project_cpu_seconds(under)
check(math.floor(under_cpu.cpu_seconds) == 18576,
	"the under-budget CPU projection changed: " .. under_cpu.cpu_seconds)
check(math.abs(under_cpu.per_seed_cpu_seconds - 36) < 1e-9,
	"the under-budget rate is not the slowest shard's CPU per seed")
check(authority.check_cpu_gate(under_cpu, cpu_budget) == "passed",
	"an under-budget CPU projection was refused")
-- Over budget: the same fleet at 70 s of CPU per seed, which no amount of host
-- contention explains at a measured 1.8x margin over a 35 s anchor.
local over = {sample_of(516, shard_log(0, 515, 75, 70, 2)),
	sample_of(515, shard_log(516, 1030, 74, 69, 2))}
local over_cpu = authority.project_cpu_seconds(over)
check(math.abs(over_cpu.per_seed_cpu_seconds - 70) < 1e-9,
	"the over-budget rate changed: " .. over_cpu.per_seed_cpu_seconds)
refuses("a projection past the measured CPU budget", "exceeds the",
	authority.check_cpu_gate, over_cpu, cpu_budget)
-- The estimator's rules carry over whole: one completion is an observation, and
-- however far over the budget it lands it can only defer.
local cold_cpu = authority.project_cpu_seconds({
	sample_of(516, shard_log(0, 515, 900, 800, 1)),
	sample_of(515, shard_log(516, 1030, 40, 36, 1))})
check(cold_cpu.decisive == false,
	"a one-completion CPU fleet was treated as decisive")
check(authority.check_cpu_gate(cold_cpu, cpu_budget) == "deferred",
	"an over-budget single CPU sample was not deferred")
-- And a shard stalled on its first seed still cannot buy a sibling that has
-- answered twice an exemption.
refuses("a stalled shard masking one that is over the CPU budget", "exceeds the",
	authority.check_cpu_gate, authority.project_cpu_seconds({
		sample_of(516, shard_log(0, 515, 3600, 3600, 1)),
		sample_of(515, shard_log(516, 1030, 80, 71, 3))}), cpu_budget)

-- The advisory wall path (section 6.5, 2026-08-18): nothing on the launcher's
-- path can abort on wall time any more.  The functional half -- a fleet whose
-- wall projection is more than twice the retired nine-hour cap passes, because
-- its CPU is inside the budget -- and the structural half: the gate script the
-- launcher calls does not so much as name the wall verdict function.
local advisory = {sample_of(516, shard_log(0, 515, 130, 36, 2)),
	sample_of(515, shard_log(516, 1030, 128, 35, 2))}
local advisory_wall = authority.project_wall_seconds(advisory)
check(math.floor(advisory_wall.wall_seconds) == 67080,
	"the advisory wall projection changed: " .. advisory_wall.wall_seconds)
check(advisory_wall.wall_seconds > 2 * cap,
	"the advisory fixture no longer projects past twice the retired cap")
check(authority.check_cpu_gate(authority.project_cpu_seconds(advisory),
	cpu_budget) == "passed",
	"a fleet twice over the retired wall cap was refused by the CPU gate")
local gate_source = read_file(repo .. "/tools/wp40/t2_census_gate.lua")
check(gate_source:find("check_cpu_gate", 1, true) ~= nil,
	"the launcher-side gate no longer takes a CPU verdict")
check(gate_source:find("check_cost_gate", 1, true) == nil,
	"the launcher-side gate still takes a wall verdict after the retirement")
check(gate_source:find("verdict=advisory", 1, true) ~= nil,
	"the wall projection line no longer says it is advisory")

-- The liveness gate (section 6.5, 2026-08-18): the busy-loop hang, without
-- false-firing on the starved fleet that idle scheduling makes ordinary.
local allowance = 540
check(authority.check_liveness_gate({consumed = 0, completed_since = 0,
	allowance = allowance}) == "quiet",
	"a fleet consuming no CPU at all was accused of looping")
check(authority.check_liveness_gate({consumed = allowance,
	completed_since = 0, allowance = allowance}) == "quiet",
	"the liveness gate fired exactly at its allowance")
refuses("a fleet burning CPU while nothing completes",
	"since its last completed seed", authority.check_liveness_gate,
	{consumed = allowance + 1, completed_since = 0, allowance = allowance})
-- Progress is never accused, however much CPU it cost: the span the gate reads
-- is the one since the last completed seed, and a completion ends it.
check(authority.check_liveness_gate({consumed = 100 * allowance,
	completed_since = 1, allowance = allowance}) == "progressing",
	"a fleet that completed a seed was judged on the CPU it took to do it")
refuses("a liveness allowance of zero", "allowance is invalid",
	authority.check_liveness_gate,
	{consumed = 1, completed_since = 0, allowance = 0})

-- The measured conf the budget and the allowance come from.  Nothing here is a
-- restated number: what is checked is that the file has to carry them, that a
-- conf older than the commit it would gate is refused, and that a typo reads as
-- a typo rather than as a missing measurement.
local conf_text = "# measured\nANCHOR_CPU_SECONDS=35.00\nCONTENTION_MARGIN=1.80\n" ..
	"LIVENESS_X_CPU_SECONDS=600\nPROBE_DATE=2026-08-18\n"
local conf = authority.read_cpu_gate_conf(conf_text, "2026-08-18")
check(math.abs(conf.budget - 63) < 1e-9,
	"the conf's budget is not anchor times margin: " .. conf.budget)
check(conf.allowance == 600 and conf.anchor == 35 and conf.margin == 1.8,
	"the conf reader lost a measured value")
check(authority.read_cpu_gate_conf(conf_text, "2026-08-17").probe_date ==
	"2026-08-18", "a conf newer than the commit was refused")
refuses("a CPU gate conf measured before the commit it would gate",
	"older than the HEAD commit", authority.read_cpu_gate_conf, conf_text,
	"2026-08-19")
refuses("a CPU gate conf missing its margin", "declares no CONTENTION_MARGIN",
	authority.read_cpu_gate_conf,
	(conf_text:gsub("CONTENTION_MARGIN=1.80\n", "", 1)), "2026-08-18")
refuses("a CPU gate conf with a misspelled key", "undeclared key",
	authority.read_cpu_gate_conf,
	(conf_text:gsub("CONTENTION_MARGIN", "CONTENTION_MARGINS", 1)), "2026-08-18")
refuses("a CPU gate conf line that is not an assignment", "KEY=VALUE",
	authority.read_cpu_gate_conf, conf_text .. "margin 1.8\n", "2026-08-18")
refuses("a CPU gate conf declaring a key twice", "twice",
	authority.read_cpu_gate_conf, conf_text .. "CONTENTION_MARGIN=9.00\n",
	"2026-08-18")
refuses("a CPU gate conf with an undated probe", "not an ISO date",
	authority.read_cpu_gate_conf,
	(conf_text:gsub("PROBE_DATE=2026%-08%-18", "PROBE_DATE=yesterday", 1)),
	"2026-08-18")

-- --------------------------------------------------- first record and resume
-- A synthetic shard in the exact worker format.  Building it here rather than
-- capturing one keeps the negatives cheap: every mutation below is a one-line
-- edit of bytes whose good form has just been accepted.
-- The record shape is derived from the authority's declared roster rather
-- than a shadow copy: occupancy-driven kinds (count nil) emit two synthetic
-- rows, and every class/kind cell takes the first declared vocabulary value.
-- Stage-shaped kinds are skipped by their declared attribute: they are v4's
-- *other* record shape and may never appear inside a full-roster record,
-- which is proven below.
--
-- Two v6 kinds are occupancy-driven in the roster and still fixed by the
-- member-conditional grammar (contracts 9.2/9.6): a record whose membership
-- row says `member` -- which the first declared vocabulary value makes this
-- one -- carries all 38 faces and exactly one Whole row.  Two synthetic rows
-- would be a malformed member record, so the two counts are named here rather
-- than left to the generic occupancy default, and both halves of that grammar
-- are proven refusable below.
local synthetic_member_rows = {scan4_face = 38, scan4_whole = 1}
local function seed_record(seed)
	local rows = {"seed_begin\t" .. seed}
	for _, layout in ipairs(authority.record_rows) do
		if not layout.stage_shape then
			for index = 1, layout.count or synthetic_member_rows[layout.tag] or 2 do
				local cells = {layout.tag, seed}
				for field = 3, layout.fields do
					cells[field] = layout.tag .. index .. "_" .. field
				end
				if layout.class_field then
					cells[layout.class_field] = authority.classes[layout.class_set][1]
				end
				if layout.extra_field then
					cells[layout.extra_field] = authority.classes[layout.extra_set][1]
				end
				if layout.extra2_field then
					cells[layout.extra2_field] = authority.classes[layout.extra2_set][1]
				end
				rows[#rows + 1] = table.concat(cells, "\t")
			end
		end
	end
	rows[#rows + 1] = "seed_end\t" .. seed
	return table.concat(rows, "\n") .. "\n"
end

-- v4's second record shape: exactly one stage_reject row between its frame
-- lines, nothing else.  Deliberately hardcoded rather than derived from the
-- layout: a fixture that auto-adapted to the authority could not catch the
-- authority drifting.
local function stage_reject_record(seed, class)
	return "seed_begin\t" .. seed .. "\n" .. table.concat({"stage_reject",
		seed, "bay_mouth_aperture:elandor_east",
		class or "aperture_second_run_reject",
		"WP40 geometry partition: bay_mouth_aperture:elandor_east has a " ..
			"wrapping or second aperture run"}, "\t") ..
		"\nseed_end\t" .. seed .. "\n"
end

local header = authority.shard_header_lines({
	schema = authority.schema, vocabulary = authority.vocabulary_path,
	shard_schema = authority.shard_schema, first = 0, last = 1, shard_seeds = 2,
	w_digest = w.digest, w_total = w.total, census_commit = string.rep("c", 40),
	census_tree = string.rep("t", 40), module_digest = string.rep("d", 64),
	interpreter_id = "luajit", interpreter_path = "/usr/bin/luajit-test",
	interpreter_version = "LuaJIT test"})
local prefilter = {}
for index = 1, authority.prefilter_edge_count do
	prefilter[index] = "prefilter\tedge_" .. index ..
		(index <= 14 and "\tdischarged\tout of reach" or "\tscanned\tin reach")
end
local body = table.concat(header, "\n") .. "\n" ..
	table.concat(prefilter, "\n") .. "\n" ..
	seed_record(w.seeds[1]) .. seed_record(w.seeds[2])
local function sealed(text)
	return text .. "digest\tsha256=" .. to_hex(hasher.raw_sha256(text)) .. "\n"
end
local shard = sealed(body)
local expected = {first = 0, last = 1, w_digest = w.digest,
	census_commit = string.rep("c", 40), seeds = {w.seeds[1], w.seeds[2]}}

local verified = authority.verify_shard(shard, expected)
check(#verified.seeds == 2 and verified.seeds[1] == w.seeds[1],
	"a well-formed shard did not verify")
check(verified.totals.edge == 122, "shard row totals changed")
check(verified.totals.scan2_endpoint == 16 and verified.totals.scan2_edge == 12
	and verified.totals.scan2_tuple == 4, "shard scan2 totals changed")
check(verified.totals.scan3_aperture == 16 and verified.totals.scan3_wing == 16
	and verified.totals.scan3_bank == 8 and verified.totals.scan3_width == 8
	and verified.totals.scan3_step == 4 and verified.totals.scan3_selection == 4,
	"shard scan3 totals changed")
check(verified.totals.scan3b_bank == 32 and verified.totals.scan3b_step == 4
	and verified.totals.scan3b_selection == 4
	and verified.totals.scan3b_attribution == 4 and verified.totals.scan3b_event == 4,
	"shard scan3b totals changed")
check(verified.totals.scan4_membership == 2 and verified.totals.scan4_face == 76
	and verified.totals.scan4_whole == 2
	and verified.totals.scan4_whole_interval == 4
	and verified.totals.scan4_fragment == 4, "shard scan4 totals changed")
local first_record = authority.validate_first_record(body, expected)
check(first_record and first_record.seed == w.seeds[1],
	"a well-formed first record did not validate")
check(authority.validate_first_record(
	table.concat(header, "\n") .. "\n" .. table.concat(prefilter, "\n") .. "\n" ..
	"seed_begin\t" .. w.seeds[1] .. "\n") == nil,
	"an unfinished first record was treated as complete")

refuses("a first record with an undeclared class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("ordinary_interval_select", "ordinary_interval_maybe", 1)), expected)
refuses("a first record with an undeclared edge kind", "undeclared kind",
	authority.validate_first_record,
	(body:gsub("\tordinary\t", "\tordinary_ish\t", 1)), expected)
refuses("a first record missing a site", "expected 38",
	authority.validate_first_record,
	(body:gsub("\njunction\t" .. w.seeds[1] .. "\tjunction1_3[^\n]*", "", 1)), expected)
refuses("a first record with a short row", "fields, expected 13",
	authority.validate_first_record, (body:gsub("\tedge1_13\n", "\n", 1)), expected)
refuses("a first record for the wrong seed", "expected " .. w.seeds[1],
	authority.validate_first_record,
	(body:gsub("seed_begin\t" .. w.seeds[1], "seed_begin\t7", 1)), expected)
refuses("a first record under a foreign W", "different W",
	authority.validate_first_record, body,
	{first = 0, last = 1, w_digest = string.rep("f", 64)})
refuses("a first record with an unknown row tag", "unknown row tag",
	authority.validate_first_record,
	(body:gsub("\nbay\t", "\nbays\t", 1)), expected)
refuses("a first record with an undeclared scan2 edge class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("scan2_exactly_one_complete_select", "scan2_probably_complete", 1)),
	expected)
refuses("a first record with an undeclared scan2 tuple mode", "undeclared kind",
	authority.validate_first_record,
	(body:gsub("\tdirect\t", "\tdirectish\t", 1)), expected)
refuses("a first record with an undeclared scan2 to-mode", "undeclared kind",
	authority.validate_first_record,
	(body:gsub("scan2_tuple1_10\tdirect", "scan2_tuple1_10\tdirectish", 1)),
	expected)
refuses("a first record missing a scan2 edge row", "expected 6",
	authority.validate_first_record,
	(body:gsub("\nscan2_edge\t" .. w.seeds[1] .. "\tscan2_edge1_3[^\n]*", "", 1)),
	expected)

-- Scan-3a (M4).  Each of the six new row kinds is proven refusable on the
-- dimension that kind actually carries: its class column, its second
-- vocabulary column where it has one, its roster count and its width.
refuses("a first record with an undeclared scan3 aperture class",
	"undeclared class", authority.validate_first_record,
	(body:gsub("aperture_direct_select", "aperture_direct_maybe", 1)), expected)
refuses("a first record with an undeclared scan3 aperture mode",
	"undeclared kind", authority.validate_first_record,
	(body:gsub("aperture_direct_select\tdirect\t",
		"aperture_direct_select\tdirectish\t", 1)),
	expected)
refuses("a first record with an undeclared scan3 wing class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("wing_wedge_valid_select", "wing_wedge_valid_maybe", 1)), expected)
refuses("a first record with an undeclared scan3 bank class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("bank_trace_complete_select", "bank_trace_complete_maybe", 1)),
	expected)
refuses("a first record with an undeclared scan3 width class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("bay_bank_width_positive", "bay_bank_width_probably", 1)), expected)
refuses("a first record with an undeclared scan3 step outcome",
	"undeclared class", authority.validate_first_record,
	(body:gsub("\tadmitted\t", "\tadmittedish\t", 1)), expected)
refuses("a first record with an undeclared scan3 step direction",
	"undeclared kind", authority.validate_first_record,
	(body:gsub("\teast\t", "\tnortheastish\t", 1)), expected)
refuses("a first record with an undeclared scan3 selection class",
	"undeclared class", authority.validate_first_record,
	(body:gsub("single_admitted_untested", "single_admitted_maybe", 1)), expected)
refuses("a first record missing a scan3 wing row", "expected 8",
	authority.validate_first_record,
	(body:gsub("\nscan3_wing\t" .. w.seeds[1] .. "\tscan3_wing1_3[^\n]*", "", 1)),
	expected)
refuses("a first record with a short scan3 width row", "fields, expected 20",
	authority.validate_first_record, (body:gsub("\tscan3_width1_20\n", "\n", 1)),
	expected)
-- The exclusion-cause vocabulary is declared here and checked by the worker
-- against the projection's own ordered list, so a cause added on one side and
-- not the other cannot silently drop a column out of every shard.
check(#authority.wing_exclusion_causes == 7,
	"the F5 exclusion cause list changed width without the wing row")

-- ------------------------------------------- v6 Scan-3b/4 record declarations
-- The two v6 rosters the record grammar counts rather than merely admits: the
-- sixteen transition-incident Bank traces that close the last open extremal
-- sites, and the one membership row every full record carries (contracts
-- 9.1/9.2).  Pinned here because both counts are load-bearing elsewhere --
-- the roster total below and the member-conditional block above -- and a
-- silent change to either would move a census without moving a schema.
local scan3b_bank_row = authority.record_row_by_tag.scan3b_bank
check(scan3b_bank_row ~= nil and scan3b_bank_row.count == 16 and
	scan3b_bank_row.class_set == "scan3b_bank_class",
	"the scan3b_bank roster is no longer 16 rows of scan3b_bank_class")
local membership_row = authority.record_row_by_tag.scan4_membership
check(membership_row ~= nil and membership_row.count == 1,
	"a full record no longer carries exactly one scan4_membership row")
check(#authority.record_rows == 27,
	"the record row roster changed width: " .. #authority.record_rows)
-- The member-conditional Scan-4 block, both directions.  This is the rule the
-- merge's own coverage re-check leans on, so a grammar that admitted either
-- shape would leave that re-check checking the worker against itself.
refuses("a member record short one scan4_face row",
	"scan4_face rows, expected 38", authority.validate_first_record,
	(body:gsub("\nscan4_face\t" .. w.seeds[1] .. "\tscan4_face1_3[^\n]*", "", 1)),
	expected)
refuses("a non-member record carrying the Scan-4 block",
	"holds 38 scan4_face rows", authority.validate_first_record,
	(body:gsub("\tmember\t" .. authority.classes.scan4_member_source[1] .. "\t",
		"\tnonmember\t" .. authority.classes.scan4_member_source[1] .. "\t", 1)),
	expected)

-- A schema bump is only worth its cost if a finished older shard can never
-- be resumed into the new run.  Two independent refusals per retired
-- version: the canonical path no longer names it, and the free-output rule
-- refuses to write it either.
check(shard_path:find("census-scan-v6-", 1, true) and
	not shard_path:find("census-scan-v5-", 1, true) and
	not shard_path:find("census-scan-v4-", 1, true) and
	not shard_path:find("census-scan-v3-", 1, true) and
	not shard_path:find("census-scan-v2-", 1, true),
	"the v6 shard name still admits an older shard")
refuses("a free run writing a stale M3 shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v2-0000-0515.tsv")
refuses("a free run writing a stale M4/M5 shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v3-0000-0515.tsv")
refuses("a free run writing a stale v4 census shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v4-0000-0515.tsv")
refuses("a free run writing a stale v5 census shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v5-0000-0515.tsv")

-- ------------------------------------------------- v4 stage-reject grammar
-- The two record shapes are mutually exclusive and the prefilter block may
-- be preceded only by stage_reject records.  The positive first: a shard
-- whose first seed stage-rejected verifies, and its reject record is a
-- valid first record -- early visibility holds even when seed one dies in
-- stage build.
local reject_body = table.concat(header, "\n") .. "\n" ..
	stage_reject_record(w.seeds[1]) ..
	table.concat(prefilter, "\n") .. "\n" .. seed_record(w.seeds[2])
local reject_verified = authority.verify_shard(sealed(reject_body), expected)
check(#reject_verified.seeds == 2 and reject_verified.totals.stage_reject == 1,
	"a shard with a leading stage_reject record did not verify")
local reject_first = authority.validate_first_record(reject_body, expected)
check(reject_first ~= nil and reject_first.stage_reject == true and
	reject_first.seed == w.seeds[1],
	"a leading stage_reject record did not validate as the first record")
check(authority.validate_first_record(table.concat(header, "\n") .. "\n" ..
	"seed_begin\t" .. w.seeds[1] .. "\n", expected) == nil,
	"an unfinished leading stage_reject record was treated as complete")
local free_reject_body = "schema\t" .. authority.schema .. "\nvocabulary\t" ..
	authority.vocabulary_path .. "\n" .. stage_reject_record(w.seeds[1]) ..
	table.concat(prefilter, "\n") .. "\n" .. seed_record(w.seeds[2])
local free_reject = authority.verify_free_output(sealed(free_reject_body), nil)
check(#free_reject.seeds == 2 and free_reject.totals.stage_reject == 1,
	"a free record set with a leading stage_reject record did not verify")

local mixed_record = (seed_record(w.seeds[1]):gsub(
	"seed_end\t" .. w.seeds[1] .. "\n",
	"stage_reject\t" .. w.seeds[1] .. "\tbay_mouth_aperture:elandor_east\t" ..
		"aperture_second_run_reject\tdetail\nseed_end\t" .. w.seeds[1] .. "\n", 1))
refuses("a full record mixed with a stage_reject row", "mixes a stage_reject row",
	authority.verify_shard, sealed(table.concat(header, "\n") .. "\n" ..
		table.concat(prefilter, "\n") .. "\n" .. mixed_record ..
		seed_record(w.seeds[2])), expected)
local doubled_record = (stage_reject_record(w.seeds[1]):gsub("\nseed_end",
	"\nstage_reject\t" .. w.seeds[1] .. "\tbay_mouth_aperture:elandor_west\t" ..
		"aperture_overlap_reject\tdetail\nseed_end", 1))
refuses("a record holding two stage_reject rows", "emits exactly one",
	authority.verify_shard, sealed(table.concat(header, "\n") .. "\n" ..
		doubled_record .. table.concat(prefilter, "\n") .. "\n" ..
		seed_record(w.seeds[2])), expected)
refuses("a full record ahead of the prefilter block", "before its prefilter block",
	authority.verify_shard, sealed(table.concat(header, "\n") .. "\n" ..
		seed_record(w.seeds[1]) .. table.concat(prefilter, "\n") .. "\n" ..
		seed_record(w.seeds[2])), expected)
refuses("an input holding no full record at all", "holds no full seed record",
	authority.verify_shard, sealed(table.concat(header, "\n") .. "\n" ..
		stage_reject_record(w.seeds[1]) .. stage_reject_record(w.seeds[2])),
	expected)
-- The stricter variant: a prefilter block copied into an all-reject body --
-- the digest is self-computable framing, not authentication -- must not
-- count as attestation, because no full record of this input stands behind
-- it.  The refusal keys on the missing full record, not on the block.
refuses("an all-reject input carrying a copied prefilter block",
	"holds no full seed record",
	authority.verify_shard, sealed(table.concat(header, "\n") .. "\n" ..
		stage_reject_record(w.seeds[1]) ..
		table.concat(prefilter, "\n") .. "\n" ..
		stage_reject_record(w.seeds[2])),
	expected)
refuses("a second prefilter block", "second prefilter block",
	authority.verify_shard, sealed(body .. table.concat(prefilter, "\n") .. "\n"),
	expected)
refuses("an undeclared stage-reject class", "undeclared class",
	authority.verify_shard, sealed(table.concat(header, "\n") .. "\n" ..
		stage_reject_record(w.seeds[1], "aperture_second_run_maybe") ..
		table.concat(prefilter, "\n") .. "\n" .. seed_record(w.seeds[2])),
	expected)

-- Section 6.6.4: the empty claim file of a crashed worker, a truncated shard
-- and a silently edited one all abort; none of them is an empty shard.
refuses("an empty claim file", "shard file is empty",
	authority.verify_shard, "", expected)
refuses("a claim file holding only its header", "no trailing digest line",
	authority.verify_shard, table.concat(header, "\n") .. "\n", expected)
refuses("a shard truncated mid record", "no trailing digest line",
	authority.verify_shard, body, expected)
refuses("a shard whose digest was not recomputed", "recomputed",
	authority.verify_shard, (shard:gsub("ordinary_interval_select",
		"transition_interval_select", 1)), expected)
refuses("a shard resealed around an undeclared class", "undeclared class",
	authority.verify_shard,
	sealed((body:gsub("attachment_equality_select", "attachment_equality_maybe", 1))),
	expected)
-- Removed as a plain suffix: the record bytes now contain `-` cells, which
-- are pattern-magic and would silently turn a gsub removal into a no-op.
local record_two = seed_record(w.seeds[2])
check(body:sub(-#record_two) == record_two,
	"the second seed record is not the shard body suffix")
refuses("a shard resealed with a missing seed record", "seed records",
	authority.verify_shard, sealed(body:sub(1, #body - #record_two)),
	expected)
refuses("a shard resealed for another range", "not the range",
	authority.verify_shard,
	sealed((body:gsub("shard_range\t0\t1", "shard_range\t2\t3", 1))), expected)
refuses("a shard resealed at another commit", "produced at commit",
	authority.verify_shard,
	sealed((body:gsub(string.rep("c", 40), string.rep("e", 40), 1))), expected)
-- Trailing junk is refused where the parser expects the next record to open,
-- which is the earliest and most specific place it can be named.
refuses("a shard with trailing text after its last record",
	"does not open with seed_begin",
	authority.verify_shard, sealed(body .. "bay\t0\tx\t0\t-\n"), expected)
refuses("a shard whose header lost a line", "shard header line",
	authority.verify_shard,
	sealed((body:gsub("w_total\t" .. w.total .. "\n", "", 1))), expected)
refuses("a shard whose prefilter lost a row", "prefilter row 61",
	authority.verify_shard, sealed((body:gsub("\n" .. prefilter[61], "", 1))),
	expected)
refuses("a shard whose prefilter status is undeclared", "has status",
	authority.verify_shard, sealed((body:gsub("\tdischarged\t", "\tdisarmed\t", 1))),
	expected)

-- ------------------------------------------------- M5 merge-side declarations
-- The merge reads every field by name and keys every row on a declared site,
-- so a column list that drifts from the frozen width or a site column that
-- does not exist would corrupt an artifact silently.  The authority refuses
-- both at load; what is checked here is that the declarations it loaded are
-- the ones the merge actually needs.
for _, layout in ipairs(authority.record_rows) do
	check(#layout.columns == layout.fields,
		layout.tag .. " names a different number of columns than fields")
	check(#layout.site >= 1, layout.tag .. " declares no site columns")
	local cells = {}
	for field = 1, layout.fields do cells[field] = layout.tag .. "_" .. field end
	cells[1], cells[2] = layout.tag, "0"
	check(authority.field(layout.tag, cells, layout.columns[layout.fields]) ==
		cells[layout.fields], layout.tag .. " reads its last column wrong")
	check(type(authority.site_of(layout.tag, cells)) == "string",
		layout.tag .. " has no site key")
end
refuses("a merge reading a column no row declares", "has no column named",
	authority.field, "edge", {"edge", "0"}, "not_a_column")
refuses("a merge reading a row tag no roster declares", "unknown row tag",
	authority.site_of, "not_a_tag", {"not_a_tag", "0"})

-- Section 6.2.2's universe.  Every declared decision branch must carry a
-- verdict -- the authority fails at load otherwise -- and the kind
-- vocabularies must stay out of it, or the vacuous report would call an
-- unrealized row *shape* dead policy.
local universe = authority.branch_universe()
check(#universe > 0, "the declared branch universe is empty")
-- Pinned since v6 (contracts 9.1): the Scan-3b and Scan-4 decision
-- vocabularies widened the universe to 121 branches, and the vacuous report
-- is exactly this list minus what the shards realized -- so a branch that
-- silently left the declaration would shrink the report rather than appear
-- in it as the zero it is.  Re-pinned 2026-08-20 by the section-11 package
-- (a recorded correction, named in its commit): face_appendix_select and
-- residual_multi_face_reject widen the universe to 123.
check(#universe == 123, "the declared branch universe changed width: " .. #universe)
local in_universe = {}
for index = 1, #universe do
	local declared = universe[index]
	check(declared.verdict == "DECIDED" or declared.verdict == "REJECTED" or
		declared.verdict == "EVENT", declared.branch .. " has no usable verdict")
	in_universe[declared.vocabulary .. "\t" .. declared.branch] = true
end
for name, kind in pairs(authority.class_vocabulary_kind) do
	if kind == "kind" then
		for _, value in ipairs(authority.classes[name]) do
			check(not in_universe[name .. "\t" .. value],
				"the kind vocabulary " .. name .. " leaked into the branch universe")
		end
	else
		for _, value in ipairs(authority.classes[name]) do
			check(in_universe[name .. "\t" .. value],
				name .. " declares " .. value .. " outside the branch universe")
		end
	end
end
for _, cause in ipairs(authority.wing_exclusion_causes) do
	check(in_universe[authority.exclusion_vocabulary .. "\t" .. cause],
		"the F5 exclusion cause " .. cause .. " is outside the branch universe")
end
-- Section 6.2.3's roster is load-bearing: the measurable sites and whatever a
-- family still declares open have to add up to the 153 the contract names.
-- Since v6 nothing is open -- the sixteen transition-incident Banks arrive on
-- scan3b_bank rows -- so the scanned total is the full roster and the merge's
-- manifest says "153 of 153".
local roster_total, roster_scanned = 0, 0
for _, family in ipairs(authority.extremal_families) do
	roster_total = roster_total + family.sites
	roster_scanned = roster_scanned + (family.scanned_sites or family.sites)
	check(authority.record_row_by_tag[family.row] ~= nil,
		family.family .. " names a row kind the record does not carry")
	-- A family may draw one roster from more than one row kind since v6, and
	-- the merge reads every one of them, so every named kind has to exist and
	-- to carry the family's scalars -- not merely the first.
	for _, row in ipairs(family.rows or {family.row}) do
		local layout = authority.record_row_by_tag[row]
		check(layout ~= nil,
			family.family .. " draws sites from the unknown row kind " .. row)
		for _, scalar in ipairs(family.scalars) do
			check(authority.derived_scalars[scalar] ~= nil or
				layout.column_index[scalar] ~= nil,
				family.family .. " names the unmeasurable scalar " .. scalar ..
					" on row " .. row)
		end
	end
end
check(roster_total == authority.extremal_site_total,
	"the extremal roster no longer covers 153 sites")
check(roster_scanned == 153,
	"the scans 1-4 extremal coverage moved from 153 sites to " .. roster_scanned)
for _, rule in ipairs(authority.flag_rules) do
	local layout = authority.record_row_by_tag[rule.row]
	check(layout ~= nil and layout.column_index[rule.column] ~= nil,
		"the " .. rule.flag .. " flag reads a column its row does not carry")
	check(rule.test == "equals" or rule.test == "at_least" or
		rule.test == "any" or rule.test == "present",
		"the " .. rule.flag .. " flag uses a test the merge does not implement")
end
-- The v6 flag rule (contracts 9.2, branch A): the flag vocabulary predated the
-- class the collected correction created, and the seed-set derivation text
-- reads this rule, so it is pinned in full rather than only counted above.
local admission_rule
for _, rule in ipairs(authority.flag_rules) do
	if rule.flag == "detached_shoulder_admission" then admission_rule = rule end
end
check(admission_rule ~= nil and admission_rule.row == "scan3_aperture" and
	admission_rule.column == "detached" and admission_rule.test == "present",
	"the detached_shoulder_admission flag is not the present test on " ..
		"scan3_aperture.detached")

-- ------------------------------------------------ the Scan-4 membership (9.2)
-- Branch A, ruled 2026-08-19: the consumed membership is the committed v2
-- seed-set artifact plus the v2 manifest's seven detached-shoulder admission
-- seeds, union 3,061.  This is driven over the real committed fixtures rather
-- than a synthetic pair, because the whole point of the ruling is *which*
-- bytes Scan-4 ran on: a green run against fabricated inputs would prove the
-- arithmetic and say nothing about the census.
local membership_seed_set = read_file(repo ..
	"/tools/wp40/fixtures/t2_census/census-scan4-seed-set-v2.tsv")
local membership_manifest = read_file(repo ..
	"/tools/wp40/fixtures/t2_census/census-manifest-v2.tsv")
local membership = authority.read_scan4_membership(membership_seed_set,
	membership_manifest)
check(membership.union == 3061,
	"the consumed Scan-4 union is " .. membership.union .. ", the ruling says 3061")
check(membership.sources["2466379686918096853"] == "admission",
	"a manifest admission seed is not sourced as an admission")
check(membership.sources["0"] == "seed_set",
	"a seed-set row is not sourced as seed_set")
check(membership.members["0"] == true and
	membership.members["2466379686918096853"] == true,
	"the union lost a seed one of its two sources names")
refuses("a Scan-4 seed-set artifact whose bytes were edited",
	"does not match its pinned digest", authority.read_scan4_membership,
	(membership_seed_set:gsub("\nseed\t0\t", "\nseed\t9\t", 1)),
	membership_manifest)
refuses("a v2 manifest whose bytes were edited", "does not match its pinned digest",
	authority.read_scan4_membership, membership_seed_set,
	(membership_manifest:gsub("\ndetached_shoulder_admission[^\n]*", "", 1)))
-- The counted half of the ruling -- 3,058 rows, 7 admissions, 3 newcomers --
-- sits behind those two digests, so editing bytes to reach it always stops at
-- the digest instead.  An authority whose injected hasher answers with the
-- pinned digests for exactly these two fixtures is the only way to prove the
-- counts refuse anything at all; the digest gate itself keeps the two real
-- negatives above.
local function to_raw(hex_digest)
	return (hex_digest:gsub("%x%x", function(pair)
		return string.char(tonumber(pair, 16))
	end))
end
local pinned = authority.scan4_membership_source
local stubbed = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = function(text)
		return to_raw(text:find("grug_wp40_census_manifest_v2", 1, true) and
			pinned.manifest_digest or pinned.seed_set_digest)
	end})
check(stubbed.read_scan4_membership(membership_seed_set,
	membership_manifest).union == 3061,
	"the digest-stubbed authority does not reproduce the ruling's union")
refuses("a v2 manifest that lost one of its admission lines", "admission seeds",
	stubbed.read_scan4_membership, membership_seed_set,
	(membership_manifest:gsub("\ndetached_shoulder_admission[^\n]*", "", 1)))
refuses("a v2 seed-set artifact that lost a seed row",
	"seed rows, the ruling consumed", stubbed.read_scan4_membership,
	(membership_seed_set:gsub("\nseed\t0\t[^\n]*", "", 1)), membership_manifest)

-- Free worker output is the only thing the M5 merge KAT can consume, and it
-- must never be readable as a slice of `W` -- nor a shard as a free run.
local free_body = "schema\t" .. authority.schema .. "\nvocabulary\t" ..
	authority.vocabulary_path .. "\n" .. table.concat(prefilter, "\n") .. "\n" ..
	seed_record(w.seeds[1])
local free_rows = 0
local free = authority.verify_free_output(sealed(free_body), nil,
	function() free_rows = free_rows + 1 end)
check(#free.seeds == 1 and #free.prefilter == authority.prefilter_edge_count and
	free_rows > 0, "a well-formed free record set was not accepted")
refuses("a shard read as a free record set", "must be verified as a shard",
	authority.verify_free_output, shard, nil)
refuses("a free record set read as a shard", "shard header line 3",
	authority.verify_shard, sealed(free_body), nil)
refuses("a free record set with a foreign schema", "record set schema is",
	authority.verify_free_output,
	sealed((free_body:gsub(authority.schema, "grug_wp40_census_scan_v2", 1))), nil)
refuses("a free record set with an undeclared class", "undeclared class",
	authority.verify_free_output,
	sealed((free_body:gsub("attachment_equality_select",
		"attachment_equality_maybe", 1))), nil)
refuses("a free record set without its digest line", "no trailing digest line",
	authority.verify_free_output, free_body, nil)

write_file(scratch .. "/gate-shard.tsv", shard)
check(read_file(scratch .. "/gate-shard.tsv") == shard, "shard round trip failed")
hasher.close()
print(("census gate test passed: %d checks, %d of them negative"):format(
	checks, refusals))
