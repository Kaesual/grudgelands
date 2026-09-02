-- WP40 T2 census contention probe (plan section 6.5, the 2026-08-18 CPU gate).
--
-- The run-cost gate aborts on a CPU budget of a measured anchor times a
-- measured contention margin, and this is the measurement.  Three census
-- worker seeds are scanned solo and the same three again under full synthetic
-- host load; the CPU each pass spends on each seed is the pair, the worst
-- inflation of a pair is the margin, and the worst solo pass is the anchor.
-- Estimating the multiplier instead is what section 6.5 replaced: the SMT
-- inflation of this workload on this host is not a number anyone can derive.
--
-- The seed list is the launcher's (contracts 9.5's probe protocol): four
-- Scan-4 members with pinned KAT behaviour -- seed 0, the two F10 face
-- witnesses and the R19-heavy winner, which is the only one of them whose
-- Whole tier runs -- plus one non-member, which pays Scan-3b and no Scan-4.
-- Pinned behaviour matters: a probe that silently measured a stage reject (a
-- cheap seed, and a wrong anchor) refuses instead.
--
-- Since the v6 tiers (contracts 9.5) the probe also times each tier. The
-- scanner takes an optional `tier_mark` hook, this is its only caller, and the
-- marginals it yields are what the one-/two-pass decision is read from: a
-- Scan-4 marginal against the v5 per-seed band is a comparison of measured
-- numbers rather than of two whole passes taken days apart. Whether a seed
-- runs Scan-4 at all is read from the consumed membership, exactly as the
-- worker reads it -- guessing it would price a fleet nobody runs.
--
-- What the figure counts is `os.clock`: this process's own CPU, not its SHA
-- responder's, which is exactly what the worker's per-seed telemetry counts.
-- The gate compares the two, so they have to be the same quantity, and the
-- responder's cost is deliberately outside both.
--
-- usage:
--   t2_census_probe_contention.lua REPO SCRATCH measure OUT SEED...
--   t2_census_probe_contention.lua REPO SCRATCH finalize SOLO LOADED
-- The load itself is the shell launcher's: process groups and a cleanup that
-- survives an abort are shell discipline, and a probe that left sixteen busy
-- loops behind would cost more than it measures.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local command = assert(arg[3], "probe command required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local function read_file(path)
	local file = assert(io.open(path, "rb"), "missing file " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

-- The tiers `census_scan` marks, in the order it marks them.  The first four
-- are the v5 pass, `scan3b` is the Scan-3b marginal, and the last three are
-- Scan-4's -- absent by construction on a non-member seed, which is what makes
-- the coverage assertion below a membership check as well as a timing one.
local tier_names = {"stage", "scan1", "scan3a", "scan2", "scan3b",
	"scan4_face", "scan4_whole", "scan4_fragment"}
local v5_tiers, scan4_tiers = 4, 3
local function tier_columns(tiers)
	local fields = {}
	for index = 1, #tier_names do
		fields[index] = ("%.3f"):format(tiers[tier_names[index]] or 0)
	end
	return table.concat(fields, "\t")
end

if command == "measure" then
	local out_path = assert(arg[4], "output path required")
	local seeds = {}
	for index = 5, #arg do
		assert(arg[index]:match("^%d+$"), "seed must be a decimal string")
		seeds[#seeds + 1] = arg[index]
	end
	assert(#seeds >= 1, "at least one seed required")

	local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
		repo = repo, scratch = scratch})
	local raw_sha256 = hasher.raw_sha256
	-- The worker's module wiring, seed for seed: a probe that built the
	-- partition differently would measure a different program than the one the
	-- budget it writes is going to gate.
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local canonical = dofile(wp40 .. "/canonical.lua")
	local deterministic = dofile(wp40 .. "/deterministic.lua")
	local exact = dofile(wp40 .. "/geometry/exact.lua")({
		deterministic = deterministic})
	local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
	local source = dofile(wp40 .. "/source/catalog.lua")
	local source_validator = dofile(wp40 .. "/validation/t2_source.lua")
	local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
		raw_sha256 = raw_sha256})
	local vocabulary = dofile(repo .. "/" .. authority.vocabulary_path)
	local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
	local partition = dofile(wp40 .. "/geometry/partition.lua")({
		canonical = canonical, deterministic = deterministic, exact = exact,
		new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
		source = source, source_validator = source_validator,
		vocabulary = vocabulary})
	-- The consumed Scan-4 membership, read through the authority the worker
	-- reads it through, digest checks and all (contracts 9.2's branch-A
	-- ruling).  Membership decides which seeds pay the Scan-4 tiers, so it is
	-- also what decides what this probe is measuring.
	local membership = authority.read_scan4_membership(
		read_file(repo .. "/" .. authority.scan4_membership_source.seed_set_path),
		read_file(repo .. "/" .. authority.scan4_membership_source.manifest_path))
	hasher.forget()

	local out = assert(io.open(out_path, "wb"))
	for index = 1, #seeds do
		local seed = seeds[index]
		local member = membership.members[seed] == true
		local tiers, tier_count, tier_previous = {}, 0, nil
		-- Marked once per tier by the scanner; accumulating rather than
		-- assigning keeps a second mark visible in the count assertion below
		-- instead of silently overwriting a marginal.
		local function tier_mark(name)
			local now = os.clock()
			tiers[name] = (tiers[name] or 0) + (now - tier_previous)
			tier_count = tier_count + 1
			tier_previous = now
		end
		local wall_started = os.time()
		local cpu_started = os.clock()
		tier_previous = cpu_started
		local scan = partition.census_scan(seed,
			{scan4 = member, tier_mark = tier_mark})
		local cpu = os.clock() - cpu_started
		local wall = os.difftime(os.time(), wall_started)
		-- A stage-rejected seed never reaches the R7 compile that dominates the
		-- cost, so it would understate the anchor by an order of magnitude.
		assert(not scan.stage_reject, "census probe seed " .. seed ..
			" stage-rejected (" .. tostring(scan.stage_reject and
			scan.stage_reject.class) .. "); its cost is not a census seed's")
		-- The tier count is the membership assertion: a member marks every
		-- tier, a non-member marks the v5 four plus Scan-3b and no more, and a
		-- probe whose split does not add up is not evidence about anything.
		local expected_tiers = v5_tiers + 1 + (member and scan4_tiers or 0)
		assert(tier_count == expected_tiers, "census probe seed " .. seed ..
			" marked " .. tier_count .. " tiers, a " ..
			(member and "member" or "non-member") .. " marks " .. expected_tiers)
		-- The worker drops the memo per seed, so the probe does too: the memo
		-- carries no cross-seed reuse and holding it would measure a worker
		-- nobody runs.
		hasher.forget()
		assert(out:write(("%s\t%d\t%.3f\t%d\t%s\n"):format(seed,
			member and 1 or 0, cpu, wall, tier_columns(tiers))))
		assert(out:flush())
		io.stderr:write(("census probe seed %s member=%s cpu=%.2fs wall=%ds " ..
			"scan3b=%.2fs scan4=%.2fs\n"):format(seed, tostring(member), cpu,
			wall, tiers.scan3b or 0, (tiers.scan4_face or 0) +
			(tiers.scan4_whole or 0) + (tiers.scan4_fragment or 0)))
		io.stderr:flush()
	end
	assert(out:close())
	hasher.close()
	print(("WP40 T2 census probe measured seeds=%d out=%s"):format(
		#seeds, out_path))
elseif command == "finalize" then
	local solo_path = assert(arg[4], "solo measurement path required")
	local loaded_path = assert(arg[5], "loaded measurement path required")
	local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({})

	local function load_measurement(path, label)
		local order, cpu, wall, member, tiers = {}, {}, {}, {}, {}
		for line in (read_file(path)):gmatch("([^\n]*)\n") do
			if line ~= "" then
				local fields = {}
				for field in (line .. "\t"):gmatch("(.-)\t") do
					fields[#fields + 1] = field
				end
				local seed = fields[1]
				assert(#fields == 4 + #tier_names and seed and seed:match("^%d+$"),
					label .. " measurement line is malformed: " .. line)
				assert(not cpu[seed], label .. " measured seed " .. seed .. " twice")
				order[#order + 1] = seed
				member[seed] = fields[2] == "1"
				cpu[seed] = assert(tonumber(fields[3]),
					label .. " measurement line is malformed: " .. line)
				wall[seed] = assert(tonumber(fields[4]),
					label .. " measurement line is malformed: " .. line)
				local by_name = {}
				for index = 1, #tier_names do
					by_name[tier_names[index]] = assert(tonumber(fields[4 + index]),
						label .. " measurement line is malformed: " .. line)
				end
				tiers[seed] = by_name
				assert(cpu[seed] > 0, label .. " measured seed " .. seed ..
					" at no CPU at all")
			end
		end
		assert(#order >= 1, label .. " measured no seed")
		return {order = order, cpu = cpu, wall = wall, member = member,
			tiers = tiers}
	end

	-- The v5 pass is the first four tiers; Scan-3b and Scan-4 are the marginals
	-- the v6 record added on top of it.  Split here rather than at measure time
	-- so the conf carries the same arithmetic the report quotes.
	local function tier_split(by_name)
		local v5, scan4 = 0, 0
		for index = 1, v5_tiers do v5 = v5 + by_name[tier_names[index]] end
		for index = 1, scan4_tiers do
			scan4 = scan4 + by_name[tier_names[v5_tiers + 1 + index]]
		end
		return v5, by_name.scan3b, scan4
	end

	local solo = load_measurement(solo_path, "the solo")
	local loaded = load_measurement(loaded_path, "the loaded")
	assert(#solo.order == #loaded.order,
		"the two probe passes measured different seed counts")
	local anchor, worst_loaded, margin, worst_seed = 0, 0, 0, nil
	local worst_v5, worst_scan3b, worst_scan4 = 0, 0, 0
	local lines = {}
	for index = 1, #solo.order do
		local seed = solo.order[index]
		assert(loaded.order[index] == seed,
			"the two probe passes measured different seeds, or in another order")
		assert(solo.member[seed] == loaded.member[seed],
			"the two probe passes disagree on the membership of seed " .. seed)
		local ratio = loaded.cpu[seed] / solo.cpu[seed]
		local solo_v5, solo_scan3b, solo_scan4 = tier_split(solo.tiers[seed])
		local loaded_v5, loaded_scan3b, loaded_scan4 =
			tier_split(loaded.tiers[seed])
		lines[#lines + 1] = ("# seed %s member=%d solo_cpu=%.2f loaded_cpu=%.2f " ..
			"ratio=%.3f solo_wall=%d loaded_wall=%d"):format(seed,
			solo.member[seed] and 1 or 0, solo.cpu[seed], loaded.cpu[seed], ratio,
			solo.wall[seed], loaded.wall[seed])
		lines[#lines + 1] = ("#   solo tiers v5=%.2f scan3b=%.2f scan4=%.2f " ..
			"(face=%.2f whole=%.2f fragment=%.2f)"):format(solo_v5, solo_scan3b,
			solo_scan4, solo.tiers[seed].scan4_face,
			solo.tiers[seed].scan4_whole, solo.tiers[seed].scan4_fragment)
		lines[#lines + 1] = ("#   loaded tiers v5=%.2f scan3b=%.2f scan4=%.2f " ..
			"(face=%.2f whole=%.2f fragment=%.2f)"):format(loaded_v5,
			loaded_scan3b, loaded_scan4, loaded.tiers[seed].scan4_face,
			loaded.tiers[seed].scan4_whole, loaded.tiers[seed].scan4_fragment)
		print(("WP40 T2 census probe pair seed=%s member=%d " ..
			"solo_cpu_seconds=%.2f loaded_cpu_seconds=%.2f ratio=%.3f"):format(
			seed, solo.member[seed] and 1 or 0, solo.cpu[seed], loaded.cpu[seed],
			ratio))
		print(("WP40 T2 census probe tiers seed=%s pass=solo v5_seconds=%.2f " ..
			"scan3b_seconds=%.2f scan4_seconds=%.2f face_seconds=%.2f " ..
			"whole_seconds=%.2f fragment_seconds=%.2f"):format(seed, solo_v5,
			solo_scan3b, solo_scan4, solo.tiers[seed].scan4_face,
			solo.tiers[seed].scan4_whole, solo.tiers[seed].scan4_fragment))
		print(("WP40 T2 census probe tiers seed=%s pass=loaded v5_seconds=%.2f " ..
			"scan3b_seconds=%.2f scan4_seconds=%.2f face_seconds=%.2f " ..
			"whole_seconds=%.2f fragment_seconds=%.2f"):format(seed, loaded_v5,
			loaded_scan3b, loaded_scan4, loaded.tiers[seed].scan4_face,
			loaded.tiers[seed].scan4_whole, loaded.tiers[seed].scan4_fragment))
		if solo.cpu[seed] > anchor then anchor = solo.cpu[seed] end
		if loaded.cpu[seed] > worst_loaded then worst_loaded = loaded.cpu[seed] end
		if ratio > margin then margin, worst_seed = ratio, seed end
		if solo_v5 > worst_v5 then worst_v5 = solo_v5 end
		if solo_scan3b > worst_scan3b then worst_scan3b = solo_scan3b end
		if solo_scan4 > worst_scan4 then worst_scan4 = solo_scan4 end
	end
	-- Contracts 9.5's split criterion, stated as its inputs rather than as a
	-- verdict: the fleet runs one mixed pass unless the Scan-4 marginal exceeds
	-- the whole v5 per-seed band, and the decision on those numbers is the
	-- coordinator's at the announcement pre-flight, not this script's.
	lines[#lines + 1] = ("# split criterion (contracts 9.5): worst solo v5 tier " ..
		"%.2f s, worst solo Scan-3b marginal %.2f s,"):format(worst_v5,
		worst_scan3b)
	lines[#lines + 1] = ("#   worst solo Scan-4 marginal %.2f s -- the decision " ..
		"is the pre-flight's, not this conf's."):format(worst_scan4)
	print(("WP40 T2 census probe split criterion worst_v5_seconds=%.2f " ..
		"worst_scan3b_seconds=%.2f worst_scan4_seconds=%.2f " ..
		"scan4_exceeds_v5=%s"):format(worst_v5, worst_scan3b, worst_scan4,
		tostring(worst_scan4 > worst_v5)))
	-- Rounded up, never to nearest: the margin is a headroom figure, and a
	-- budget rounded down is a gate that fires on the very load it measured.
	margin = math.ceil(margin * 100) / 100
	-- A loaded pass cheaper than the solo one is not a tight budget, it is a
	-- broken measurement -- a polluted solo phase, or load that never started.
	assert(margin >= 1, ("the loaded pass was cheaper than the solo one " ..
		"(worst ratio %.3f); the probe measured nothing usable"):format(margin))
	-- Generous by decision (section 6.5): ten worst loaded seeds of fleet-wide
	-- CPU with nothing completing is not a slow host, it is a loop.
	local allowance = math.ceil(10 * worst_loaded)
	local probe_date = os.date("%Y-%m-%d")
	local conf_path = repo .. "/" .. authority.cpu_gate_conf_path
	local body = table.concat({
		"# WP40 T2 census CPU gate, measured by tools/wp40/run_t2_census_probe.sh",
		"# (plan section 6.5).  Shell-sourceable, read by the launcher through",
		"# the authority's strict parser.  Regenerate it whenever the census",
		"# code or the host moves: a run refuses a conf older than its commit.",
		"#",
		"# The measurement, per seed, solo and under one busy loop per logical CPU:",
		table.concat(lines, "\n"),
		("# anchor = worst solo, margin = worst ratio (seed %s) rounded up,"):format(
			tostring(worst_seed)),
		"# X = 10x the worst loaded seed.",
		("ANCHOR_CPU_SECONDS=%.2f"):format(anchor),
		("CONTENTION_MARGIN=%.2f"):format(margin),
		("LIVENESS_X_CPU_SECONDS=%d"):format(allowance),
		("PROBE_DATE=%s"):format(probe_date),
	}, "\n") .. "\n"
	local file = assert(io.open(conf_path, "wb"))
	assert(file:write(body))
	assert(file:close())
	-- Read back through the launcher's own reader before this reports success:
	-- a conf the gate would refuse is a probe that has not finished its job.
	local conf = authority.read_cpu_gate_conf(read_file(conf_path), probe_date)
	print(("WP40 T2 census probe wrote %s anchor_seconds=%.2f margin=%.2f " ..
		"budget_seconds=%.2f liveness_x_seconds=%d probe_date=%s"):format(
		authority.cpu_gate_conf_path, conf.anchor, conf.margin, conf.budget,
		conf.allowance, conf.probe_date))
else
	error("unknown census probe command " .. tostring(command), 0)
end
