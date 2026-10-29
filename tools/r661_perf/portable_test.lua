-- 0.66.1 lane PERF portable test: the [GRUG-PERF] lines of grug_perf
-- (mods/CORE/grug_perf). Loads the REAL lines.lua, monitor.lua and init.lua
-- (the last under a small engine stub) and checks:
--   A. percentiles: nearest rank, an empty and a one-step minute, a shorter
--      minute after a longer one (the stale tail is dropped);
--   B. rounding: one decimal, integers, and NaN, infinities, negatives and
--      nil written as 0;
--   C. the line builder against every rule of the platform's parser: the
--      exact marker, one JSON object and nothing after it, every number
--      finite and >= 0, integer fields as integers (minimap_us and
--      minimap_bytes above 2^31 too), `profiler` a real boolean, the three
--      round-trip fields absent without players, the line under 4096
--      bytes, the `file` pattern, the exact field set per kind;
--   D. the recorder: one minute line per 60 s of steps, the spike threshold
--      (strictly over 250 ms), at most one spike line per 10 s with every
--      spike counted, the parser's per-minute caps over ten minutes of
--      spikes, the load step's dtime 0 ignored, no allocation per step;
--   E. the profile file detection: the newest existing second, the engine's
--      name pattern, nothing found;
--   F. init.lua under a stub: the monitor off registers no globalstep; on,
--      the minute line at action level with the census (players, round
--      trips, objects, entities, max lag, the minimap's differences, the
--      Lua heap, the profiler flag), zeros without grug_map; the periodic
--      save only with profiler.load, its line, the warning once per failure
--      streak.
--
-- Usage (repo root): luajit tools/r661_perf/portable_test.lua [REPO]

local repo = arg[1] or "."
local MOD = repo .. "/mods/CORE/grug_perf"
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local lines = dofile(MOD .. "/lines.lua")
local monitor = dofile(MOD .. "/monitor.lua")

---------------------------------------------------------------------------
-- The platform parser's rules, as a validator: returns the decoded object
-- or nil and the broken rule.
---------------------------------------------------------------------------
local CONTRACT = {
	minute = {
		required = {"v", "kind", "span_s", "steps", "step_p50", "step_p95", "step_max",
			"spikes", "spike_ms", "max_lag", "players", "objects", "luaentities",
			"minimap_us", "minimap_changes", "minimap_bytes", "lua_kb", "profiler"},
		optional = {"rtt_p50", "rtt_max", "jitter_max"},
		ints = {v = true, steps = true, spikes = true, players = true, objects = true,
			luaentities = true, minimap_us = true, minimap_changes = true,
			minimap_bytes = true, lua_kb = true},
		big = {minimap_us = true, minimap_bytes = true},
	},
	spike = {
		required = {"v", "kind", "step_ms", "players", "objects", "luaentities"},
		optional = {},
		ints = {v = true, players = true, objects = true, luaentities = true},
		big = {},
	},
	profile_saved = {required = {"v", "kind", "file"}, optional = {}, ints = {v = true}, big = {}},
}
local PREFIX = "[GRUG-PERF] "

local function validate(text)
	if type(text) ~= "string" then return nil, "not a string" end
	if #text >= 4096 then return nil, "4096 bytes or more" end
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, "marker" end
	local body = text:sub(#PREFIX + 1)
	if body:sub(1, 1) ~= "{" or body:sub(-1) ~= "}" then return nil, "one JSON object" end
	local ok, obj = pcall(json.parse, body)
	if not ok or type(obj) ~= "table" then return nil, "JSON: " .. tostring(obj) end
	local spec = CONTRACT[obj.kind]
	if not spec then return nil, "kind " .. tostring(obj.kind) end
	if obj.v ~= 1 then return nil, "v" end
	local known = {}
	for _, name in ipairs(spec.required) do
		known[name] = true
		if obj[name] == nil then return nil, "missing " .. name end
	end
	for _, name in ipairs(spec.optional) do known[name] = true end
	for name, value in pairs(obj) do
		if not known[name] then return nil, "unknown field " .. name end
		if type(value) == "number" then
			if value ~= value or value == math.huge or value == -math.huge then
				return nil, name .. " not finite"
			end
			if value < 0 then return nil, name .. " negative" end
			if spec.ints[name] then
				-- The text itself: digits only, no point, no exponent.
				local raw = body:match('"' .. name .. '":([^,}]*)')
				if not raw or not raw:match("^%d+$") then return nil, name .. " not an integer: " .. tostring(raw) end
				if not spec.big[name] and value >= 2 ^ 31 then return nil, name .. " over 32 bits" end
			end
		elseif name == "profiler" then
			if type(value) ~= "boolean" then return nil, "profiler not a boolean" end
		elseif name == "kind" or name == "file" then
			if type(value) ~= "string" then return nil, name .. " not a string" end
		else
			return nil, name .. " has type " .. type(value)
		end
	end
	if obj.kind == "minute" and type(obj.profiler) ~= "boolean" then return nil, "profiler" end
	if obj.kind == "profile_saved" and not obj.file:match("^profile%-%d%d%d%d%d%d%d%dT%d%d%d%d%d%d%.json$") then
		return nil, "file pattern"
	end
	return obj
end

local function valid(text, label)
	local obj, why = validate(text)
	check(obj ~= nil, label .. " passes the parser rules (" .. tostring(why) .. "): " .. tostring(text))
	return obj or {}
end

---------------------------------------------------------------------------
-- A. Percentiles
---------------------------------------------------------------------------
do
	local samples = {}
	for i = 1, 100 do samples[i] = 101 - i end
	local p50, p95, max = monitor.summarize(samples, 100)
	eq(p50, 50, "A p50 of 1..100")
	eq(p95, 95, "A p95 of 1..100")
	eq(max, 100, "A max of 1..100")
	-- A shorter minute after it: only the first 3 entries count.
	samples[1], samples[2], samples[3] = 7, 3, 5
	p50, p95, max = monitor.summarize(samples, 3)
	eq(#samples, 3, "A the stale tail is dropped")
	eq(p50, 5, "A p50 of three")
	eq(p95, 7, "A p95 of three")
	eq(max, 7, "A max of three")
	p50, p95, max = monitor.summarize({42}, 1)
	check(p50 == 42 and p95 == 42 and max == 42, "A one step")
	p50, p95, max = monitor.summarize({1, 2}, 0)
	check(p50 == 0 and p95 == 0 and max == 0, "A no step")
	eq(monitor.rank(2, 0.5), 1, "A median rank of two (nearest rank)")
	eq(monitor.rank(20, 0.95), 19, "A p95 rank of twenty")
end

---------------------------------------------------------------------------
-- B. Rounding
---------------------------------------------------------------------------
eq(lines.tenth(92.345), 92.3, "B tenth rounds down")
eq(lines.tenth(92.35001), 92.4, "B tenth rounds up")
eq(lines.int(2.5), 3, "B int rounds half up")
for _, bad in ipairs({0 / 0, math.huge, -math.huge, -3, "x"}) do
	eq(lines.tenth(bad), 0, "B " .. tostring(bad) .. " is 0")
	eq(lines.int(bad), 0, "B int " .. tostring(bad) .. " is 0")
end
eq(lines.int(nil), 0, "B nil is 0")

---------------------------------------------------------------------------
-- C. The line builder against the parser rules
---------------------------------------------------------------------------
do
	local full = {span_s = 60.034, steps = 667, step_p50 = 90.04, step_p95 = 91.96,
		step_max = 312.27, spikes = 2, spike_ms = 250, max_lag = 123.456, players = 7,
		objects = 812, luaentities = 805, rtt_p50 = 41.27, rtt_max = 180.04,
		jitter_max = 12.55, minimap_us = 2 ^ 33 + 0.4, minimap_changes = 5123,
		minimap_bytes = 2 ^ 32 + 7, lua_kb = 171234.75, profiler = false}
	local text = assert(lines.build("minute", full))
	local obj = valid(text, "C full minute line")
	eq(text:sub(1, 13), '[GRUG-PERF] {', "C marker, one space, the object")
	eq(obj.span_s, 60, "C span_s at one decimal")
	eq(obj.step_p50, 90, "C step_p50 at one decimal")
	eq(obj.step_max, 312.3, "C step_max at one decimal")
	eq(obj.max_lag, 123.5, "C max_lag at one decimal")
	eq(obj.minimap_us, 2 ^ 33, "C minimap_us above 2^31")
	eq(obj.minimap_bytes, 2 ^ 32 + 7, "C minimap_bytes above 2^31")
	eq(obj.lua_kb, 171235, "C lua_kb an integer")
	eq(obj.profiler, false, "C profiler a boolean")
	eq(obj.rtt_p50, 41.3, "C rtt_p50")
	check(not text:find("e+", 1, true) and not text:find("e-", 1, true), "C no exponent")
	print("sample minute line: " .. text)

	-- No players: the round-trip fields are absent, not null.
	local empty = {}
	for k, v in pairs(full) do empty[k] = v end
	empty.rtt_p50, empty.rtt_max, empty.jitter_max, empty.players = nil, nil, nil, 0
	text = assert(lines.build("minute", empty))
	obj = valid(text, "C minute line without players")
	check(obj.rtt_p50 == nil and obj.rtt_max == nil and obj.jitter_max == nil
		and not text:find("rtt", 1, true) and not text:find("null", 1, true),
		"C round trips absent without players")

	-- Bad values never break the line.
	local bad = {span_s = 0 / 0, steps = -1, step_p50 = math.huge, step_p95 = -math.huge,
		step_max = "x", spikes = nil, max_lag = -0.5, players = 3.7, profiler = "yes"}
	obj = valid(assert(lines.build("minute", bad)), "C minute line from bad values")
	eq(obj.span_s, 0, "C NaN is 0")
	eq(obj.steps, 0, "C negative is 0")
	eq(obj.players, 4, "C players rounded")
	eq(obj.profiler, false, "C a non-boolean profiler is false")
	eq(obj.spike_ms, 0, "C a missing required number is 0")

	obj = valid(assert(lines.build("spike", {step_ms = 412.06, players = 6, objects = 900,
		luaentities = 894})), "C spike line")
	eq(obj.step_ms, 412.1, "C spike step_ms")
	obj = valid(assert(lines.build("profile_saved", {file = "profile-20261029T143005.json"})),
		"C profile_saved line")
	eq(obj.file, "profile-20261029T143005.json", "C file")
	check(validate(assert(lines.build("profile_saved", {file = "profile-x.json"}))) == nil,
		"C the validator refuses a wrong file name")
	check(lines.build("nonsense", {}) == nil, "C unknown kind refused")
	-- A quote or a control character in a string stays valid JSON.
	local quoted = assert(lines.build("profile_saved", {file = 'a"b\\c\1'}))
	check(pcall(json.parse, quoted:sub(#PREFIX + 1)), "C strings escaped")
	-- The longest possible minute line stays far under the limit.
	local huge = {}
	for k in pairs(full) do huge[k] = 2 ^ 52 end
	huge.profiler = true
	text = assert(lines.build("minute", huge))
	check(#text < 1024, "C the longest minute line is short (" .. #text .. " bytes)")
end

---------------------------------------------------------------------------
-- D. The recorder
---------------------------------------------------------------------------
do
	local minutes, spikes = {}, {}
	local step = monitor.new(function(s) minutes[#minutes + 1] = s end,
		function(ms) spikes[#spikes + 1] = ms end)
	step(0) -- the engine's initial step
	for _ = 1, 666 do step(0.09) end
	eq(#minutes, 0, "D no minute line before 60 s")
	step(0.09)
	eq(#minutes, 1, "D one minute line at 60 s")
	local m = minutes[1]
	eq(m.steps, 667, "D steps (the load step's 0 not counted)")
	check(math.abs(m.span_s - 60.03) < 1e-6, "D span_s " .. m.span_s)
	check(math.abs(m.step_p50 - 90) < 1e-6 and math.abs(m.step_max - 90) < 1e-6, "D step ms")
	eq(m.spikes, 0, "D no spike")
	eq(m.spike_ms, 250, "D spike_ms is the threshold")
	eq(#spikes, 0, "D no spike line")

	-- Exactly 250 ms is no spike; 250.1 is.
	step(0.25)
	eq(#spikes, 0, "D 250 ms is not a spike")
	step(0.2501)
	eq(#spikes, 1, "D over 250 ms is a spike")
	-- Spikes 1 s apart: lines 10 s apart, all counted.
	for _ = 1, 20 do
		step(0.7); step(0.3)
	end
	eq(#spikes, 2, "D one spike line per 10 s (spikes for 20 s after the first)")
	for _ = 1, 500 do step(0.09) end
	eq(#minutes, 2, "D the second minute")
	eq(minutes[2].spikes, 41, "D every spike counted in the minute")
	eq(minutes[2].step_max, 700, "D step_max")

	-- Every step a spike, 0.5 s apart (exact in binary): lines at 0.5, 10.5
	-- and 20.5 s of 21 s.
	local at, sclock = {}, 0
	local s1 = monitor.new(function() end, function() at[#at + 1] = sclock end)
	for _ = 1, 42 do sclock = sclock + 0.5; s1(0.5) end
	eq(#at, 3, "D spike lines 10 s apart")
	check(at[1] == 0.5 and at[2] == 10.5 and at[3] == 20.5, "D spike line times")

	-- Ten minutes of one spike a second: the parser's caps per log minute
	-- (2 minute lines, 12 spike lines) hold in every 60 s window.
	local clock, events = 0, {}
	local s2 = monitor.new(function() events[#events + 1] = {"minute", clock} end,
		function() events[#events + 1] = {"spike", clock} end)
	for _ = 1, 600 do
		clock = clock + 0.7; s2(0.7)
		clock = clock + 0.3; s2(0.3)
	end
	local worst = {minute = 0, spike = 0}
	for start = 0, 600, 0.5 do
		local n = {minute = 0, spike = 0}
		for _, e in ipairs(events) do
			if e[2] >= start and e[2] < start + 60 then n[e[1]] = n[e[1]] + 1 end
		end
		worst.minute = math.max(worst.minute, n.minute)
		worst.spike = math.max(worst.spike, n.spike)
	end
	check(worst.minute <= 2 and worst.minute >= 1, "D minute lines per 60 s: " .. worst.minute)
	check(worst.spike <= 12 and worst.spike >= 6, "D spike lines per 60 s: " .. worst.spike)

	-- No allocation per step once a minute's array has grown.
	-- (The interpreter only: a LuaJIT trace is itself a GC object.)
	if jit then jit.off() end
	local s3 = monitor.new(function() end, function() end)
	for _ = 1, 1334 do s3(0.09) end -- two minutes: the array has grown
	collectgarbage("collect"); collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 600 do s3(0.09) end -- inside one minute, no summary
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then jit.on() end
	check(grown < 0.5, ("D no allocation per step (%.2f KB over 600 steps)"):format(grown))
end

---------------------------------------------------------------------------
-- E. The profile file detection
---------------------------------------------------------------------------
do
	local function date(fmt, t)
		eq(fmt, "%Y%m%dT%H%M%S", "E the engine's date format")
		return ("20261029T1430%02d"):format(t - 1000)
	end
	local present = {["profile-20261029T143005.json"] = true, ["profile-20261029T143007.json"] = true}
	local function exists(name) return present[name] == true end
	eq(monitor.find_saved(1005, 1007, date, exists), "profile-20261029T143007.json",
		"E the newest existing second")
	eq(monitor.find_saved(1005, 1006, date, exists), "profile-20261029T143005.json",
		"E an earlier second in the span")
	eq(monitor.find_saved(1008, 1009, date, exists), nil, "E nothing in the span")
	eq(monitor.find_saved(1009, 1008, date, exists), nil, "E a clock going back")
	eq(monitor.find_saved(nil, 1008, date, exists), nil, "E no time")
	check(("profile-20261029T143005.json"):find(monitor.PROFILE_PATTERN) ~= nil, "E the pattern")
	check(("profile-20261029T143005-grug.json"):find(monitor.PROFILE_PATTERN) == nil,
		"E a filtered save is not the pattern")
	-- The real os.date gives a name of the pattern.
	check(monitor.profile_name(os.date(monitor.PROFILE_DATE)):find(monitor.PROFILE_PATTERN) ~= nil,
		"E os.date's name matches")
end

---------------------------------------------------------------------------
-- F. init.lua under a stub engine
---------------------------------------------------------------------------
local function boot(settings, world)
	local env = {logs = {}, globalsteps = {}, afters = {}, players = {}, infos = {},
		saves = 0, resets = 0, files = {}}
	env.object_refs, env.luaentities = {}, {}
	for i = 1, 12 do env.object_refs[i] = true end
	for i = 1, 9 do env.luaentities[i] = true end
	env.command = {func = function(_, param)
		if param == "reset" then env.resets = env.resets + 1; return true, "reset" end
		env.saves = env.saves + 1
		if env.fail then return false, "Saving of profile failed: disk" end
		if env.misname then return true, "saved elsewhere" end
		env.files[world .. "/profile-" .. os.date("%Y%m%dT%H%M%S") .. ".json"] = true
		return true, "Profile saved to somewhere (translated)"
	end}
	_G.grug_perf = nil
	_G.core = {
		get_modpath = function() return MOD end,
		get_current_modname = function() return "grug_perf" end,
		settings = {
			get_bool = function(_, key, default)
				local v = settings[key]
				if v == nil then return default end
				return v
			end,
			get = function(_, key)
				local v = settings[key]
				if v == nil then return nil end
				return tostring(v)
			end,
		},
		log = function(level, text) env.logs[#env.logs + 1] = {level = level, text = text} end,
		register_globalstep = function(f) env.globalsteps[#env.globalsteps + 1] = f end,
		after = function(t, f) env.afters[#env.afters + 1] = {t = t, f = f} end,
		get_connected_players = function() return env.players end,
		get_player_information = function(name) return env.infos[name] end,
		object_refs = env.object_refs,
		luaentities = env.luaentities,
		get_server_max_lag = function() return 0.1234 end,
		registered_chatcommands = {profiler = env.command},
		get_worldpath = function() return world end,
	}
	local real_open = io.open
	env.restore = function() io.open = real_open end
	io.open = function(path, mode)
		if env.files[path] then return {close = function() end} end
		return nil, "no such file"
	end
	dofile(MOD .. "/init.lua")
	env.restore()
	env.open = function(path) return env.files[path] and {close = function() end} or nil end
	return env
end

local function player(name) return {get_player_name = function() return name end} end

local function perf_lines(env, kind)
	local out = {}
	for _, entry in ipairs(env.logs) do
		if entry.text:sub(1, #PREFIX) == PREFIX then
			check(entry.level == "action", "F " .. kind .. " line at action level")
			local obj = validate(entry.text)
			if obj and obj.kind == kind then out[#out + 1] = obj end
		end
	end
	return out
end

do
	-- Off: no globalstep, no timer, nothing logged.
	local env = boot({grug_perf_monitor = false}, "/w")
	eq(#env.globalsteps, 0, "F monitor off: no globalstep")
	eq(#env.afters, 0, "F profile off: no timer")
	eq(#env.logs, 0, "F off: nothing logged")
	check(type(grug_perf) == "table" and type(grug_perf.census) == "function",
		"F the one global")

	-- On by default, without grug_map and without players.
	_G.grug_map = nil
	env = boot({}, "/w")
	eq(#env.globalsteps, 1, "F monitor on by default: one globalstep")
	for _ = 1, 667 do env.globalsteps[1](0.09) end
	local m = perf_lines(env, "minute")
	eq(#m, 1, "F one minute line")
	m = m[1] or {}
	eq(m.players, 0, "F no players")
	check(m.rtt_p50 == nil and m.rtt_max == nil and m.jitter_max == nil, "F no round trips")
	eq(m.objects, 12, "F objects")
	eq(m.luaentities, 9, "F luaentities")
	eq(m.max_lag, 123.4, "F max_lag in ms")
	check(m.minimap_us == 0 and m.minimap_changes == 0 and m.minimap_bytes == 0,
		"F minimap zeros without grug_map")
	check(type(m.lua_kb) == "number" and m.lua_kb > 0, "F lua_kb")
	eq(m.profiler, false, "F profiler off")
	eq(m.steps, 667, "F steps")

	-- With grug_map, players and a spike; the profiler loaded.
	_G.grug_map = {minimap = {stats = {us = 5000, changes = 40, bytes = 1200}}}
	env = boot({["profiler.load"] = true}, "/w")
	env.players = {player("a"), player("b"), player("c")}
	env.infos = {
		a = {avg_rtt = 0.040, avg_jitter = 0.002},
		b = {avg_rtt = 0.120, avg_jitter = 0.015},
		c = {avg_rtt = -1, avg_jitter = -1}, -- not measured yet
	}
	env.globalsteps[1](0.4)
	local spikes = perf_lines(env, "spike")
	eq(#spikes, 1, "F spike line")
	eq((spikes[1] or {}).step_ms, 400, "F spike step_ms")
	eq((spikes[1] or {}).players, 3, "F spike players")
	eq((spikes[1] or {}).objects, 12, "F spike objects")
	grug_map.minimap.stats.us = 2 ^ 32 + 5000
	grug_map.minimap.stats.changes = 140
	grug_map.minimap.stats.bytes = 4200
	for _ = 1, 700 do env.globalsteps[1](0.09) end
	m = perf_lines(env, "minute")[1] or {}
	eq(m.players, 3, "F players")
	eq(m.rtt_p50, 40, "F rtt_p50 (nearest rank of the measured two)")
	eq(m.rtt_max, 120, "F rtt_max")
	eq(m.jitter_max, 15, "F jitter_max")
	eq(m.minimap_us, 2 ^ 32, "F minimap_us is the difference since load (5000 at load)")
	eq(m.minimap_changes, 100, "F minimap_changes (40 at load)")
	eq(m.minimap_bytes, 3000, "F minimap_bytes (1200 at load)")
	eq(m.profiler, true, "F profiler on")
	eq(m.spikes, 1, "F spikes in the minute")
	-- The next minute reports only the new work.
	grug_map.minimap.stats.changes = 150
	for _ = 1, 700 do env.globalsteps[1](0.09) end
	m = perf_lines(env, "minute")[2] or {}
	eq(m.minimap_changes, 10, "F the next minute's difference")
	eq(m.minimap_us, 0, "F no minimap time in the next minute")
	_G.grug_map = nil

	-- The periodic save: off without profiler.load.
	env = boot({grug_perf_profile_minutes = 5}, "/w")
	eq(#env.afters, 0, "F no periodic save without profiler.load")
	env = boot({["profiler.load"] = true, grug_perf_profile_minutes = 0}, "/w")
	eq(#env.afters, 0, "F no periodic save at 0 minutes")

	-- On: every N minutes save, reset, one line.
	env = boot({["profiler.load"] = true, grug_perf_profile_minutes = 5,
		grug_perf_monitor = false}, "/world")
	eq(#env.afters, 1, "F one timer")
	eq((env.afters[1] or {}).t, 300, "F every 5 minutes")
	local function fire()
		local job = table.remove(env.afters, 1)
		io.open = function(path) return env.open(path) end
		job.f()
		env.restore()
	end
	fire()
	eq(env.saves, 1, "F saved")
	eq(env.resets, 1, "F reset after the save")
	eq(#env.afters, 1, "F the next save is due")
	local saved = perf_lines(env, "profile_saved")
	eq(#saved, 1, "F profile_saved line")
	check(saved[1] and saved[1].file:match("^profile%-%d+T%d+%.json$") ~= nil, "F file name")
	-- Failures warn once per streak.
	env.fail = true
	fire(); fire(); fire()
	local warnings = 0
	for _, entry in ipairs(env.logs) do
		if entry.level == "warning" and entry.text:find("profile save failed", 1, true) then
			warnings = warnings + 1
		end
	end
	eq(warnings, 1, "F a failing save warns once")
	eq(env.resets, 4, "F the statistics reset every interval")
	env.fail = false
	fire()
	eq(#perf_lines(env, "profile_saved"), 2, "F a later save works again")
	env.misname = true
	env.files = {} -- (the earlier save's file carries this very second)
	fire()
	warnings = 0
	for _, entry in ipairs(env.logs) do
		if entry.level == "warning" and entry.text:find("not found", 1, true) then
			warnings = warnings + 1
		end
	end
	eq(warnings, 1, "F a save without its file warns (after a success, again)")
	eq(#perf_lines(env, "profile_saved"), 2, "F no line without the file")

	-- Without the engine's command (it is registered only with profiler.load).
	env = boot({["profiler.load"] = true, grug_perf_profile_minutes = 1}, "/w")
	core.registered_chatcommands.profiler = nil
	env.command.func = nil
	fire()
	check(env.logs[#env.logs] and env.logs[#env.logs].level == "warning", "F missing command warns")
end

if failures > 0 then
	error(("R661 PERF PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R661 PERF PORTABLE PASS checks=%d"):format(checks))
