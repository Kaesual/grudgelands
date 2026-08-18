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
-- The seeds are three KAT seeds -- seed 0, the Slot-29 R19 witness and the
-- Slot-30 fragment witness -- so the pass they measure has pinned behaviour
-- and a probe that silently measured a stage reject (a cheap seed, and a wrong
-- anchor) refuses instead.
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
	hasher.forget()

	local out = assert(io.open(out_path, "wb"))
	for index = 1, #seeds do
		local seed = seeds[index]
		local wall_started = os.time()
		local cpu_started = os.clock()
		local scan = partition.census_scan(seed)
		local cpu = os.clock() - cpu_started
		local wall = os.difftime(os.time(), wall_started)
		-- A stage-rejected seed never reaches the R7 compile that dominates the
		-- cost, so it would understate the anchor by an order of magnitude.
		assert(not scan.stage_reject, "census probe seed " .. seed ..
			" stage-rejected (" .. tostring(scan.stage_reject and
			scan.stage_reject.class) .. "); its cost is not a census seed's")
		-- The worker drops the memo per seed, so the probe does too: the memo
		-- carries no cross-seed reuse and holding it would measure a worker
		-- nobody runs.
		hasher.forget()
		assert(out:write(("%s\t%.3f\t%d\n"):format(seed, cpu, wall)))
		assert(out:flush())
		io.stderr:write(("census probe seed %s cpu=%.2fs wall=%ds\n"):format(
			seed, cpu, wall))
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
		local order, cpu, wall = {}, {}, {}
		for line in (read_file(path)):gmatch("([^\n]*)\n") do
			if line ~= "" then
				local seed, seconds, seed_wall = line:match("^(%d+)\t([%d.]+)\t(%d+)$")
				assert(seed, label .. " measurement line is malformed: " .. line)
				assert(not cpu[seed], label .. " measured seed " .. seed .. " twice")
				order[#order + 1] = seed
				cpu[seed] = assert(tonumber(seconds))
				wall[seed] = assert(tonumber(seed_wall))
				assert(cpu[seed] > 0, label .. " measured seed " .. seed ..
					" at no CPU at all")
			end
		end
		assert(#order >= 1, label .. " measured no seed")
		return {order = order, cpu = cpu, wall = wall}
	end

	local solo = load_measurement(solo_path, "the solo")
	local loaded = load_measurement(loaded_path, "the loaded")
	assert(#solo.order == #loaded.order,
		"the two probe passes measured different seed counts")
	local anchor, worst_loaded, margin, worst_seed = 0, 0, 0, nil
	local lines = {}
	for index = 1, #solo.order do
		local seed = solo.order[index]
		assert(loaded.order[index] == seed,
			"the two probe passes measured different seeds, or in another order")
		local ratio = loaded.cpu[seed] / solo.cpu[seed]
		lines[#lines + 1] = ("# seed %s solo_cpu=%.2f loaded_cpu=%.2f ratio=%.3f " ..
			"solo_wall=%d loaded_wall=%d"):format(seed, solo.cpu[seed],
			loaded.cpu[seed], ratio, solo.wall[seed], loaded.wall[seed])
		print(("WP40 T2 census probe pair seed=%s solo_cpu_seconds=%.2f " ..
			"loaded_cpu_seconds=%.2f ratio=%.3f"):format(seed, solo.cpu[seed],
			loaded.cpu[seed], ratio))
		if solo.cpu[seed] > anchor then anchor = solo.cpu[seed] end
		if loaded.cpu[seed] > worst_loaded then worst_loaded = loaded.cpu[seed] end
		if ratio > margin then margin, worst_seed = ratio, seed end
	end
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
