-- grug_perf (0.66.1): the game's performance numbers for the hosting
-- platform, as [GRUG-PERF] lines in the server log (action level, one JSON
-- object after the marker; contract v1 in docs/technical/module-guide.md
-- "Performance log lines"). Two parts, each behind its own setting, both read
-- at load (a change needs a restart):
--
--   * grug_perf_monitor (on by default): one `minute` line per minute (step
--     intervals, spikes, lag, players and their round trips, objects, the
--     minimap's cost, the Lua heap) and a `spike` line for a step over 250 ms
--     (at most one per 10 s). Per step it records one interval and counts;
--     the players and objects are walked once a minute. Off: no globalstep.
--   * grug_perf_profile_minutes (0 = off): while the engine's profiler is
--     loaded (profiler.load), every N minutes the engine's own /profiler
--     command saves a JSON profile into the world folder and resets the
--     statistics, and a `profile_saved` line names the file.
--
-- A CORE mod with no dependency: the minimap's counters are read from
-- grug_map's table when it is there (optional_depends only orders the load),
-- so grug_map knows nothing of this mod. The pure parts (lines.lua,
-- monitor.lua) are tested by tools/r661_perf/portable_test.lua.
local modpath = core.get_modpath(core.get_current_modname())
local lines = dofile(modpath .. "/lines.lua")
local monitor = dofile(modpath .. "/monitor.lua")

grug_perf = {lines = lines, monitor = monitor}

local profiler_on = core.settings:get_bool("profiler.load", false)

local function emit(kind, values)
	local line, err = lines.build(kind, values)
	if line then
		core.log("action", line)
	else
		core.log("warning", "[grug_perf] " .. kind .. " line dropped: " .. tostring(err))
	end
end

local function count(t)
	local n = 0
	if type(t) == "table" then
		for _ in pairs(t) do n = n + 1 end
	end
	return n
end

-- Active objects (players included) and active Lua entities: the engine's
-- own tables of them (src/script/scripting_server.cpp:63-70; an object's
-- entry lives while it is active, cpp_api/s_base.cpp:424-500).
local function object_counts()
	return count(core.object_refs), count(core.luaentities)
end

-- The minimap's cumulative counters (grug_map/minimap.lua `M.stats`), or nil
-- without grug_map.
local function minimap_stats()
	local map = rawget(_G, "grug_map")
	local minimap = type(map) == "table" and map.minimap
	return type(minimap) == "table" and type(minimap.stats) == "table" and minimap.stats or nil
end

-- The counters at the last line; the first line counts from this mod's load
-- (grug_map, when there, loaded before it).
local last_minimap = {us = 0, changes = 0, bytes = 0}
do
	local stats = minimap_stats()
	if stats then
		last_minimap.us, last_minimap.changes, last_minimap.bytes =
			stats.us or 0, stats.changes or 0, stats.bytes or 0
	end
end

-- The once-a-minute part of a `minute` line: everything but the step
-- statistics. Walks the connected players once (their round trips) and
-- counts the objects. Public for the measuring probe.
function grug_perf.census()
	local values = {}
	local players = core.get_connected_players()
	values.players = #players
	local rtts, jitter_max = {}, nil
	for i = 1, #players do
		local info = core.get_player_information(players[i]:get_player_name())
		-- Seconds; negative until the connection has measured a round trip
		-- (src/network/mtp/impl.h:191-198).
		if info and type(info.avg_rtt) == "number" and info.avg_rtt >= 0 then
			rtts[#rtts + 1] = info.avg_rtt * 1000
		end
		if info and type(info.avg_jitter) == "number" and info.avg_jitter >= 0 then
			local jitter = info.avg_jitter * 1000
			if not jitter_max or jitter > jitter_max then jitter_max = jitter end
		end
	end
	if #rtts > 0 then
		table.sort(rtts)
		values.rtt_p50 = rtts[monitor.rank(#rtts, 0.5)]
		values.rtt_max = rtts[#rtts]
	end
	values.jitter_max = jitter_max
	values.objects, values.luaentities = object_counts()
	-- Seconds (src/script/lua_api/l_server.cpp:52-56).
	values.max_lag = (core.get_server_max_lag() or 0) * 1000
	local stats = minimap_stats()
	if stats then
		values.minimap_us = (stats.us or 0) - last_minimap.us
		values.minimap_changes = (stats.changes or 0) - last_minimap.changes
		values.minimap_bytes = (stats.bytes or 0) - last_minimap.bytes
		last_minimap.us, last_minimap.changes, last_minimap.bytes =
			stats.us or 0, stats.changes or 0, stats.bytes or 0
	end
	values.lua_kb = collectgarbage("count")
	values.profiler = profiler_on
	return values
end

if core.settings:get_bool("grug_perf_monitor", true) then
	local census = grug_perf.census
	core.register_globalstep(monitor.new(function(stats)
		local values = census()
		for name, value in pairs(stats) do values[name] = value end
		emit("minute", values)
	end, function(step_ms)
		local objects, luaentities = object_counts()
		emit("spike", {step_ms = step_ms, players = #core.get_connected_players(),
			objects = objects, luaentities = luaentities})
	end))
end

-- The periodic profile save (only with the engine's profiler loaded).
local minutes = math.floor(tonumber(core.settings:get("grug_perf_profile_minutes") or "") or 0)
if minutes > 0 and profiler_on then
	-- builtin/profiler/init.lua:25-50 registers the command before any mod
	-- loads (builtin/game/chat.lua:115-119); "save json" without a filter
	-- writes profile-<os.date>.json (reporter.lua:226-268), "reset" clears
	-- the statistics (sampling.lua:29-54).
	local command = core.registered_chatcommands["profiler"]
	local worldpath = core.get_worldpath()
	local report_path = core.settings:get("profiler.report_path") or ""
	local folder = report_path ~= "" and (worldpath .. "/" .. report_path) or worldpath
	if report_path ~= "" then
		core.log("warning", "[grug_perf] profiler.report_path is set: the periodic " ..
			"profiles go to " .. folder .. ", not the world folder itself")
	end
	local warned = false
	local function warn_once(text)
		if warned then return end
		warned = true
		core.log("warning", "[grug_perf] periodic profile save failed (reported once " ..
			"until a save works again): " .. tostring(text))
	end
	local function exists(name)
		local file = io.open(folder .. "/" .. name, "rb")
		if not file then return false end
		file:close()
		return true
	end
	local function save()
		core.after(minutes * 60, save)
		if not (command and type(command.func) == "function") then
			return warn_once("the engine's /profiler command is not registered")
		end
		local before = os.time()
		local ok, saved, message = pcall(command.func, "", "save json")
		local after = os.time()
		pcall(command.func, "", "reset")
		if not ok then return warn_once(saved) end
		if not saved then return warn_once(message) end
		local name = monitor.find_saved(before, after, os.date, exists)
		if not name then return warn_once("the saved file was not found in " .. folder) end
		warned = false
		emit("profile_saved", {file = name})
	end
	core.after(minutes * 60, save)
end
