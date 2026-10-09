-- Round 45 playtest fix PT8 portable test (LuaJIT): station sounds only when
-- a player starts a job, queued at most once.
--
--   luajit tools/r45_pt8/portable_test.lua [REPO]
--
-- Loads the REAL grug_jobs/station_sounds.lua under a stub engine (a clock,
-- core.after, nodes) with a recording grug_sounds.play, and the REAL
-- grug_ambience/data.lua. Checks:
--   N  no sound without a job: loading registers no globalstep, ABM, LBM or
--      timer and plays nothing; the ambience has no loop at forges and
--      anvils (the fire loop at a burning furnace stays); the only trigger
--      is the job start hook;
--   Q  the queue rule per station node: four starts within one sound play it
--      once and queue it once (the third and fourth add nothing); the queued
--      sound plays when the first ends; a start while the queued one plays
--      queues once more; after the end a start plays at once; two stations
--      are independent;
--   S  which stations sound: the forge (craft_smithy) and the brewing stand
--      (craft_alchemy) at the station's position; the tanning rack, tailor
--      bench, carving bench, jeweller's bench, furnace and dual furnace, a
--      missing position and a removed node are silent; an event without an
--      approved file records nothing; each sound's length is its file's.
-- The start hook's station position (jobs.lua) and the missing end cue are
-- checked in tools/r45_jb and tools/r45_eu.
-- Prints "R45 PT8 PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
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

------------------------------------------------------------------------------
-- Stub engine: a clock in seconds, core.after, nodes by position.
------------------------------------------------------------------------------
local now = 100
local afters = {}
local function run_until(t)
	local ran = true
	while ran do
		ran = false
		table.sort(afters, function(a, b) return a.at < b.at end)
		local first = afters[1]
		if first and first.at <= t + 1e-9 then
			table.remove(afters, 1)
			if first.at > now then now = first.at end
			first.fn()
			ran = true
		end
	end
	if t > now then now = t end
end
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
local nodes = {}
local registrations = {}
local function count(kind) registrations[kind] = (registrations[kind] or 0) + 1 end
core = {
	registered_nodes = {},
	get_us_time = function() return math.floor(now * 1000000 + 0.5) end,
	after = function(delay, fn) afters[#afters + 1] = {at = now + delay, fn = fn} end,
	get_node_or_nil = function(p)
		local name = nodes[key(p)]
		return name and {name = name} or nil
	end,
	hash_node_position = function(p)
		return (p.z + 32768) * 65536 * 65536 + (p.y + 32768) * 65536 + p.x + 32768
	end,
	register_globalstep = function() count("globalstep") end,
	register_abm = function() count("abm") end,
	register_lbm = function() count("lbm") end,
	register_on_joinplayer = function() count("join") end,
}
for name, station in pairs({["grug_jobs:forge"] = "forge",
		["grug_brewing:brewing_stand"] = "brewing_stand",
		["grug_brewing:brewing_stand_active"] = "brewing_stand",
		["grug_jobs:tanning_rack"] = "tanning_rack", ["grug_jobs:tailor_bench"] = "tailor_bench",
		["grug_jobs:carving_bench"] = "carving_bench",
		["grug_jobs:jewellers_bench"] = "jewellers_bench", ["default:furnace"] = "furnace",
		["default:furnace_active"] = "furnace", ["grug_smelting:dual_furnace"] = "dual_furnace"}) do
	core.registered_nodes[name] = {_grug_station = station}
end
core.registered_nodes["grug_decor:cottages_anvil"] = {}

-- grug_sounds.play: records {event, pos, t}; an event in `silent` has no
-- approved file and returns false, as the real helper does.
local played, silent = {}, {}
grug_sounds = {play = function(event, target)
	if silent[event] then return false end
	played[#played + 1] = {event = event, pos = target, t = now}
	return true
end}

local start_hooks = {}
grug_jobs = {register_on_job_start = function(fn) start_hooks[#start_hooks + 1] = fn end}

dofile(ROOT .. "/mods/PLAYER/grug_jobs/station_sounds.lua")
local J = grug_jobs

-- A job start as jobs.lua's begin_job reports it.
local function start(pos)
	for _, fn in ipairs(start_hooks) do fn({}, {kind = "recipe"}, pos) end
end

------------------------------------------------------------------------------
-- N. No sound without a job.
------------------------------------------------------------------------------
do
	eq(#played, 0, "N loading plays nothing")
	eq(#afters, 0, "N loading arms no timer")
	check(next(registrations) == nil, "N no globalstep, ABM, LBM or join work")
	eq(#start_hooks, 1, "N the job start hook is the one trigger")
	local D = dofile(ROOT .. "/mods/CORE/grug_ambience/data.lua")
	eq(D.emitter_nodes["grug_jobs:forge"], nil, "N no ambience loop at the forge")
	eq(D.emitter_nodes["grug_decor:cottages_anvil"], nil, "N no ambience loop at the anvil")
	for node, kind in pairs(D.emitter_nodes) do
		check(kind ~= "forge" and not node:find("forge", 1, true) and
			not node:find("anvil", 1, true), "N no forge or anvil emitter: " .. node)
	end
	eq(D.emitters.forge, nil, "N the forge loop kind is gone")
	eq(D.emitter_nodes["default:furnace_active"], "fire", "N a burning furnace keeps its fire loop")
end

------------------------------------------------------------------------------
-- Q. The queue rule.
------------------------------------------------------------------------------
local FORGE = {x = 10, y = 5, z = -3}
local STAND = {x = 40, y = 5, z = 7}
nodes[key(FORGE)] = "grug_jobs:forge"
nodes[key(STAND)] = "grug_brewing:brewing_stand"
local SMITHY = J.STATION_SOUNDS.forge.seconds
do
	-- Four players start within one sound length.
	eq(J.play_station_sound(FORGE), "played", "Q player 1 plays the sound")
	now = now + 0.3
	eq(J.play_station_sound(FORGE), "queued", "Q player 2 queues one more")
	now = now + 0.3
	eq(J.play_station_sound(FORGE), false, "Q player 3 adds nothing")
	now = now + 0.3
	start(FORGE) -- player 4 through the start hook
	eq(#played, 1, "Q one sound so far")
	eq(#afters, 1, "Q one timer for the queued sound")
	local first = played[1]
	check(first.event == "craft_smithy" and first.pos == FORGE, "Q the forge's sound at the forge")
	run_until(100 + SMITHY - 0.01)
	eq(#played, 1, "Q the queued sound waits for the first to end")
	run_until(100 + SMITHY)
	eq(#played, 2, "Q the queued sound plays when the first ends")
	eq(played[2].t, 100 + SMITHY, "Q ... exactly at its end")
	check(played[2].event == "craft_smithy" and played[2].pos == FORGE, "Q the same sound, same place")
	run_until(100 + 10 * SMITHY)
	eq(#played, 2, "Q four starts: the sound twice, never more")

	-- A start while the queued sound plays queues once more.
	local t0 = now
	start(FORGE)
	eq(#played, 3, "Q after the end a start plays at once")
	now = t0 + SMITHY * 0.5
	start(FORGE)
	start(FORGE)
	run_until(t0 + SMITHY)
	eq(#played, 4, "Q the queued one plays")
	now = t0 + SMITHY * 1.5
	eq(J.play_station_sound(FORGE), "queued", "Q a start during the queued sound queues once more")
	eq(J.play_station_sound(FORGE), false, "Q ... and only once")
	run_until(t0 + 2 * SMITHY)
	eq(#played, 5, "Q it plays when the queued one ends")
	run_until(t0 + 20 * SMITHY)
	eq(#played, 5, "Q nothing more")

	-- Two stations are independent.
	local before = #played
	start(FORGE)
	start(STAND)
	eq(#played - before, 2, "Q the forge and the stand play side by side")
	check(played[#played].event == "craft_alchemy" and played[#played].pos == STAND,
		"Q the brewing stand's sound at the stand")
	start(STAND)
	start(FORGE)
	eq(#played - before, 2, "Q each queues its own")
	run_until(now + 10)
	eq(#played - before, 4, "Q each queued sound plays once")
end

------------------------------------------------------------------------------
-- S. Which stations sound.
------------------------------------------------------------------------------
do
	run_until(now + 10)
	local before = #played
	local quiet = {"grug_jobs:tanning_rack", "grug_jobs:tailor_bench", "grug_jobs:carving_bench",
		"grug_jobs:jewellers_bench", "default:furnace", "default:furnace_active",
		"grug_smelting:dual_furnace", "grug_decor:cottages_anvil"}
	for index, name in ipairs(quiet) do
		local p = {x = index, y = 0, z = 0}
		nodes[key(p)] = name
		eq(J.play_station_sound(p), false, "S silent: " .. name)
	end
	start(nil)
	eq(J.play_station_sound(nil), false, "S a job without a station is silent")
	eq(J.play_station_sound({x = 99, y = 99, z = 99}), false, "S a removed station is silent")
	eq(#played, before, "S nothing played, nothing queued")
	eq(#afters, 0, "S no timer armed")
	nodes[key({x = 1, y = 0, z = 0})] = "grug_brewing:brewing_stand_active"
	eq(J.play_station_sound({x = 1, y = 0, z = 0}), "played", "S the lit brewing stand id sounds too")
	-- An event without an approved file: nothing recorded, the next start tries again.
	run_until(now + 10)
	silent.craft_smithy = true
	local p = {x = 50, y = 0, z = 0}
	nodes[key(p)] = "grug_jobs:forge"
	eq(J.play_station_sound(p), false, "S an event without a file plays nothing")
	silent.craft_smithy = nil
	eq(J.play_station_sound(p), "played", "S ... and blocks nothing")
	-- `seconds` is the shipped file's length (the last Ogg page's granule
	-- position over the Vorbis sample rate).
	local FILES = {craft_smithy = "grug_sounds_craft_smithy", craft_alchemy = "grug_sounds_craft_alchemy"}
	local function ogg_seconds(path)
		local f = io.open(path, "rb")
		if not f then return nil end
		local data = f:read("*a")
		f:close()
		local id = data:find("\1vorbis", 1, true)
		if not id then return nil end
		local r = id + 12 -- after "\1vorbis", the version (4) and the channels (1)
		local rate = data:byte(r) + data:byte(r + 1) * 256 + data:byte(r + 2) * 65536 +
			data:byte(r + 3) * 16777216
		local last, from = nil, 1
		while true do
			local at = data:find("OggS", from, true)
			if not at then break end
			last, from = at, at + 4
		end
		local granule = 0
		for i = 7, 0, -1 do granule = granule * 256 + data:byte(last + 6 + i) end
		return granule / rate
	end
	for station, sound in pairs(J.STATION_SOUNDS) do
		local file = FILES[sound.event]
		local length = file and ogg_seconds(ROOT .. "/mods/CORE/grug_sounds/sounds/" .. file .. ".ogg")
		check(length and math.abs(length - sound.seconds) < 0.05,
			"S " .. station .. "'s seconds are its file's length (" .. tostring(length) .. ")")
	end
end

if failures > 0 then
	print(("R45 PT8 PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R45 PT8 PORTABLE PASS checks=%d"):format(checks))
