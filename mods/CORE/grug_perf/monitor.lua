-- The step monitor's pure parts (0.66.1): the per-step recorder behind the
-- `minute` and `spike` lines and the detection of a saved profile's file.
--
-- A step interval is the `dtime` a globalstep receives: the engine measures
-- the whole previous server step with its own clock, unclamped and
-- unsmoothed (reference_projects/luanti src/server.cpp:136-170, the server
-- thread's loop; :152 passes it to AsyncRunStep, serverenvironment.cpp:1073
-- and cpp_api/s_env.cpp:134-143 hand it to every globalstep unchanged), so a
-- long step arrives whole in the next step's dtime without a clock call of
-- our own.
--
-- Pure: no engine call, so tools/r661_perf/portable_test.lua loads this file
-- as it ships. Returns the module table; it publishes no global itself.
local M = {}

-- A step longer than this is a spike (reported in the line as `spike_ms`).
M.SPIKE_MS = 250
-- At most one `spike` line per this many seconds; the spikes in between are
-- still counted in the minute's `spikes`.
M.SPIKE_GAP_S = 10
-- One `minute` line per this many seconds of steps.
M.MINUTE_S = 60

local sort, ceil = table.sort, math.ceil

-- The nearest-rank index of the share p (0..1) in a sorted list of n >= 1.
local function rank(n, p)
	local i = ceil(p * n)
	if i < 1 then return 1 end
	if i > n then return n end
	return i
end
M.rank = rank

-- p50, p95 and the maximum of samples[1..n] (nearest rank). Sorts the list
-- in place and drops the entries after n first (they belong to an earlier,
-- longer minute; the array keeps its size, so the next minute allocates
-- nothing). All 0 for n = 0.
function M.summarize(samples, n)
	for i = #samples, n + 1, -1 do samples[i] = nil end
	if n < 1 then return 0, 0, 0 end
	sort(samples)
	return samples[rank(n, 0.50)], samples[rank(n, 0.95)], samples[n]
end

-- The recorder: returns the function to register as a globalstep. Per step it
-- stores one interval and counts (no clock call, no allocation once the
-- array has grown to a minute's steps, nothing per player or object).
-- on_spike(step_ms) runs for a spike at most once per SPIKE_GAP_S;
-- on_minute(stats) after MINUTE_S seconds of steps, with
-- stats = {span_s, steps, step_p50, step_p95, step_max, spikes, spike_ms}
-- (times in ms, span_s in seconds; a fresh table each minute).
function M.new(on_minute, on_spike)
	local SPIKE_MS, SPIKE_GAP_S, MINUTE_S = M.SPIKE_MS, M.SPIKE_GAP_S, M.MINUTE_S
	local summarize = M.summarize
	local samples, n, spikes, span = {}, 0, 0, 0
	-- Seconds of steps since the start, for the spike lines' spacing.
	local clock, spike_at = 0, nil
	return function(dtime)
		-- The engine's first step at load passes 0 (src/server.cpp:126, the
		-- initial AsyncRunStep): no interval.
		if not (dtime > 0) then return end
		local ms = dtime * 1000
		n = n + 1
		samples[n] = ms
		span = span + dtime
		clock = clock + dtime
		if ms > SPIKE_MS then
			spikes = spikes + 1
			if not spike_at or clock - spike_at >= SPIKE_GAP_S then
				spike_at = clock
				on_spike(ms)
			end
		end
		if span >= MINUTE_S then
			local p50, p95, max = summarize(samples, n)
			local stats = {span_s = span, steps = n, step_p50 = p50, step_p95 = p95,
				step_max = max, spikes = spikes, spike_ms = SPIKE_MS}
			n, spikes, span = 0, 0, 0
			on_minute(stats)
		end
	end
end

-- The engine's name for a JSON save without a filter
-- (builtin/profiler/reporter.lua:226-239: "profile-" .. os.date of the save
-- .. ".json"). The contract's `file` matches PROFILE_PATTERN.
M.PROFILE_PATTERN = "^profile%-%d%d%d%d%d%d%d%dT%d%d%d%d%d%d%.json$"
M.PROFILE_DATE = "%Y%m%dT%H%M%S"

function M.profile_name(stamp)
	return "profile-" .. stamp .. ".json"
end

-- The file a save between the times `before` and `after` (os.time seconds)
-- wrote: the newest second whose name exists(name) finds, else nil. `date`
-- is os.date, the clock the engine names the file by. Looks at most 60
-- seconds back (a save takes far less).
function M.find_saved(before, after, date, exists)
	if type(before) ~= "number" or type(after) ~= "number" then return nil end
	local first = after - 60
	if before > first then first = before end
	for t = after, first, -1 do
		local name = M.profile_name(date(M.PROFILE_DATE, t))
		if name:find(M.PROFILE_PATTERN) and exists(name) then return name end
	end
	return nil
end

return M
