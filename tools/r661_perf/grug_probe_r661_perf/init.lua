-- Disposable 0.66.1 PERF probe (tools/r661_perf/run.sh). Never shipped.
--
-- Keeps the first identity's capital (setting grug_r661_target: capital or
-- start) active without a player: forceloads its box (the r42_nv3 probe's
-- way), waits for the emerge and a stable object count, then observes
-- grug_r661_obs seconds of server steps:
--   * every step interval (the globalstep dtime): count, mean, p50, p95, max;
--   * grug_perf's own globalstep, timed in place (get_us_time around it);
--   * the objects and entities at the start and the end.
-- The run script reads the process's and the Server thread's CPU time at the
-- "WINDOW START" and "WINDOW END" lines. After the window, micro benchmarks
-- of the real grug_perf parts: the recorder per step, the minute summary,
-- the census and the line builder. Results go to <world>/r661_results.json;
-- every log line carries "[r661]".

local P = "[r661] "
local now = core.get_us_time
local floor, min, max = math.floor, math.min, math.max
local function log(s) core.log("action", P .. s) end

local TARGET = core.settings:get("grug_r661_target") or "capital"
local OBS = tonumber(core.settings:get("grug_r661_obs") or "") or 120
local results = {target = TARGET, obs = OBS, seed = core.get_mapgen_setting("seed"),
	profiler = core.settings:get_bool("profiler.load", false),
	instrument_profiler = core.settings:get_bool("instrument.profiler", false)}

local function write_results()
	local path = core.get_worldpath() .. "/r661_results.json"
	local text = core.write_json(results, true)
	if not text or not core.safe_file_write(path, text) then
		core.log("error", P .. "could not write " .. path)
	end
end

local function count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

---------------------------------------------------------------------------
-- The window: step intervals and grug_perf's globalstep in place.
---------------------------------------------------------------------------
local window = nil -- {samples, n, perf_us, perf_calls} while observing

core.register_globalstep(function(dtime)
	local w = window
	if not w or dtime <= 0 then return end
	w.n = w.n + 1
	w.samples[w.n] = dtime * 1000
end)

local function wrap_perf_globalstep()
	local steps = core.registered_globalsteps
	for i = 1, #steps do
		local origin = core.callback_origins[steps[i]]
		if origin and origin.mod == "grug_perf" then
			local real = steps[i]
			local wrapped = function(dtime)
				local w = window
				if not w then return real(dtime) end
				local t0 = now()
				real(dtime)
				w.perf_us = w.perf_us + (now() - t0)
				w.perf_calls = w.perf_calls + 1
			end
			core.callback_origins[wrapped] = origin
			steps[i] = wrapped
			return true
		end
	end
	return false
end

local function stats_of(samples, n)
	local sorted = {}
	local sum = 0
	for i = 1, n do sorted[i] = samples[i]; sum = sum + samples[i] end
	table.sort(sorted)
	local function pct(p) return sorted[max(1, min(n, math.ceil(p * n)))] end
	return {steps = n, mean_ms = n > 0 and sum / n or 0, p50_ms = pct(0.5), p95_ms = pct(0.95),
		p99_ms = pct(0.99), max_ms = sorted[n], sum_s = sum / 1000}
end

---------------------------------------------------------------------------
-- Micro benchmarks of the real grug_perf parts (after the window).
---------------------------------------------------------------------------
local function bench()
	local b = {}
	local monitor, lines = grug_perf.monitor, grug_perf.lines
	-- The recorder per step at the default step length, the minute summary
	-- (sort of a minute's samples) included every 667 steps.
	local step = monitor.new(function() end, function() end)
	local N = 2000000
	for _ = 1, 20000 do step(0.09) end
	local t0 = now()
	for _ = 1, N do step(0.09) end
	b.recorder_ns_per_step = (now() - t0) * 1000 / N
	-- The same without the summary: steps of 1e-6 s never reach a minute.
	local step2 = monitor.new(function() end, function() end)
	for _ = 1, 20000 do step2(1e-6) end
	t0 = now()
	for _ = 1, N do step2(1e-6) end
	b.recorder_ns_per_step_no_summary = (now() - t0) * 1000 / N
	-- The summary alone: 667 samples (a minute at 0.09 s), copy included.
	local source, samples = {}, {}
	for i = 1, 667 do source[i] = 85 + math.random() * 10 end
	local R = 2000
	t0 = now()
	for _ = 1, R do
		for i = 1, 667 do samples[i] = source[i] end
		monitor.summarize(samples, 667)
	end
	b.summary_us = (now() - t0) / R
	-- The census (players, objects, entities, the minimap) and the line.
	R = 200
	local values
	t0 = now()
	for _ = 1, R do values = grug_perf.census() end
	b.census_us = (now() - t0) / R
	values.span_s, values.steps, values.step_p50, values.step_p95 = 60, 667, 90, 92
	values.step_max, values.spikes, values.spike_ms = 120, 0, 250
	R = 20000
	t0 = now()
	local line
	for _ = 1, R do line = lines.build("minute", values) end
	b.build_us = (now() - t0) / R
	b.line = line
	b.objects, b.luaentities = count(core.object_refs), count(core.luaentities)
	local luajit = rawget(_G, "jit")
	b.jit = type(luajit) == "table" and luajit.status and luajit.status() or false
	return b
end

---------------------------------------------------------------------------
-- The target
---------------------------------------------------------------------------
local function same(a, b)
	return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function record_at(anchor)
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		if same(record.anchor, anchor) then return record end
	end
end

local function bounds(record)
	local minp, maxp = vector.copy(record.anchor), vector.copy(record.anchor)
	for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
		local p = socket.pos
		minp = {x = min(minp.x, p.x), y = min(minp.y, p.y), z = min(minp.z, p.z)}
		maxp = {x = max(maxp.x, p.x), y = max(maxp.y, p.y), z = max(maxp.z, p.z)}
	end
	-- A ring of the surroundings, for the wildlife.
	return vector.offset(minp, -24, -8, -24), vector.offset(maxp, 24, 16, 24)
end

local function blocks_of(minp, maxp, fn)
	local n = 0
	for bx = floor(minp.x / 16), floor(maxp.x / 16) do
		for by = floor(minp.y / 16), floor(maxp.y / 16) do
			for bz = floor(minp.z / 16), floor(maxp.z / 16) do
				if fn({x = bx * 16 + 8, y = by * 16 + 8, z = bz * 16 + 8}) then n = n + 1 end
			end
		end
	end
	return n
end

local function finish()
	write_results()
	log("RESULT DONE")
	-- A normal shutdown: the run ends early and the world is saved whole
	-- for the next boot on it.
	core.after(2, function() core.request_shutdown("", false, 0) end)
end

local function observe(minp, maxp)
	results.objects_start = count(core.object_refs)
	results.luaentities_start = count(core.luaentities)
	results.objects_in_box_start = #core.get_objects_in_area(minp, maxp)
	window = {samples = {}, n = 0, perf_us = 0, perf_calls = 0, t0 = now()}
	log(("WINDOW START objects=%d luaentities=%d"):format(results.objects_start,
		results.luaentities_start))
	core.after(OBS, function()
		local w = window
		window = nil
		local wall_s = (now() - w.t0) / 1e6
		log(("WINDOW END wall_s=%.3f steps=%d"):format(wall_s, w.n))
		results.wall_s = wall_s
		results.steps = stats_of(w.samples, w.n)
		results.perf_globalstep = {calls = w.perf_calls, us = w.perf_us,
			us_per_call = w.perf_calls > 0 and w.perf_us / w.perf_calls or nil}
		results.objects_end = count(core.object_refs)
		results.luaentities_end = count(core.luaentities)
		results.max_lag_ms = core.get_server_max_lag() * 1000
		-- Benchmarks one step later, outside the window.
		core.after(1, function()
			results.bench = bench()
			log("BENCH " .. core.write_json(results.bench))
			finish()
		end)
	end)
end

local function start()
	results.wrapped = wrap_perf_globalstep()
	local identity = grug_core.start_identities()[1]
	local anchor = TARGET == "start"
		and grug_core.start_anchor(identity.faction_id, identity.race_id)
		or grug_core.capital_anchor(identity.faction_id, identity.race_id)
	local record = record_at(anchor)
	if not record then
		log("no settlement for " .. TARGET)
		return finish()
	end
	local minp, maxp = bounds(record)
	local blocks = blocks_of(minp, maxp, function(p) return core.forceload_block(p, true, -1) end)
	results.key, results.blocks = record.key, blocks
	results.box = {minp, maxp}
	log(("LIVE %s %s box %s - %s, %d blocks forceloaded"):format(TARGET, record.key,
		core.pos_to_string(minp), core.pos_to_string(maxp), blocks))
	local t0 = now()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		results.emerge_s = (now() - t0) / 1e6
		log(("LIVE emerged in %.1f s"):format(results.emerge_s))
		local last, stable, waited = -1, 0, 0
		local function poll()
			local n = #core.get_objects_in_area(minp, maxp)
			if n == last and n > 0 then stable = stable + 1 else stable = 0 end
			last, waited = n, waited + 3
			if stable >= 3 or waited >= 45 then
				results.settle_s = waited
				log(("LIVE %d objects after %d s"):format(n, waited))
				return observe(minp, maxp)
			end
			core.after(3, poll)
		end
		core.after(3, poll)
	end)
end

core.register_on_mods_loaded(function()
	core.after(1, start)
end)
