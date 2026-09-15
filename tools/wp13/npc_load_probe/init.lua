--
-- Disposable headless LOAD probe for the settlement NPCs (WP13 playtest round
-- 3, 2026-09-15). Staged into a scratch game copy by
-- `tools/wp13/run_npc_load.sh` (PROBE= of tools/luanti_headless.sh); never
-- shipped with the game, never loaded by a normal server.
--
-- It answers ONE question, the one the round-3 brief asks for before and after
-- the work-socket change: WHAT DOES A POPULATED START COST THE SERVER?
--
--   * how many active mobs stand in the settlement,
--   * how many `core.find_path` calls a minute they make -- a STATIC resident
--     must make none at all, which is the whole reason the 80/20 split exists,
--   * the mean and the worst server step over a fixed window,
--   * and, as the census the walker rule is judged by, how the settlement's
--     residents split into static workers, static idlers and walkers.
--
-- The separate runner and the separate mod directory are deliberate: the full
-- `npc_probe` programme is a seven-minute correctness run whose own teleports,
-- injections and wolf fight would be inside any window measured through it, and
-- `tools/luanti_headless.sh` passes no environment into the Flatpak, so a mode
-- switch can only be a different staged directory.
--
-- WHY A FORCELOAD AND NOT A PLAYER: a headless server has no client to connect,
-- and `ActiveBlockList::update` starts its new list from the forceloaded set
-- (serverenvironment.cpp), so a forceload activates the blocks around the
-- arrival exactly like a player standing there. The ONE thing it does not do is
-- make `core.get_connected_players()` answer, so the two player-gated paths in
-- the game -- `grug_traders`' vendor presence poll and the nametag proximity
-- gate -- are idle during this measurement. Both only ever ADD work when a
-- player is near, so every number below is the floor, and both are measured on
-- their own elsewhere (`npc_probe`'s tag phase).
--
-- Plain Lua 5.1.

local storage = core.get_mod_storage()
local BOOT = (tonumber(storage:get_string("boots")) or 0) + 1
storage:set_string("boots", tostring(BOOT))

local FORCE_REACH = 64 -- nodes each way around the arrival; the active grid
local CENSUS_RADIUS = 120 -- covers a 128 x 128 start pad from its anchor
local SETTLE = 8 -- s after the forceload before anything is measured
local WINDOW = 30 -- s of measurement per start

local function log(fields)
	local parts = {"GRUG_WP13_LOAD", "boot=" .. BOOT}
	for index = 1, #fields do parts[#parts + 1] = fields[index] end
	core.log("action", table.concat(parts, " "))
end

local function fail(message)
	core.log("error", "GRUG_WP13_LOAD boot=" .. BOOT .. " event=fail " .. message)
end

--
-- THE PATHFINDER COUNTER. Both callers in the game reach the engine through the
-- global `core.find_path` -- `grug_mobs/patrol.lua`'s stuck rescue and
-- mobs_redo's own `smart_mobs` (api.lua:1681) -- so one wrapper installed at
-- load counts every call any mob in the world makes. Chained, never replaced.
--
local path_calls = 0
local real_find_path = core.find_path
core.find_path = function(...)
	path_calls = path_calls + 1
	return real_find_path(...)
end

--
-- Step accounting. `dtime` IS the server step: the engine hands the globalstep
-- the wall time the previous step took, so the mean over a window is the mean
-- server step over that window and the maximum is its worst one.
--
local steps, dtime_sum, dtime_max = 0, 0, 0

--
-- The six starts, taken from the registry rather than from a roster of names:
-- a settlement is a START when its socket anchor is the published start anchor
-- of its race (the same test `grug_mobs/start_npcs.lua` applies).
--
local starts = {}

local function collect_starts()
	-- REBUILT from scratch on every call. This runs once a second until every
	-- start reports ready, and appending to the same list instead made the
	-- first attempt report 282 starts -- 47 polls times six -- and then measure
	-- Dawnmere forty-seven times over.
	starts = {}
	local identities = grug_core.start_identities()
	local faction_of = {}
	for index = 1, #identities do
		faction_of[identities[index].race_id] = identities[index].faction_id
	end
	local settlements = grug_core.settlement_socket_settlements()
	for index = 1, #settlements do
		local record = settlements[index]
		local faction_id = faction_of[record.race_id]
		local published = faction_id and
			grug_core.start_anchor(faction_id, record.race_id)
		if published and published.x == record.anchor.x and
				published.y == record.anchor.y and
				published.z == record.anchor.z then
			starts[#starts + 1] = {key = record.key, race_id = record.race_id,
				anchor = record.anchor}
		end
	end
	table.sort(starts, function(a, b) return a.key < b.key end)
	return #starts
end

local function forceload_area(anchor, want)
	local blocks = 0
	for dx = -FORCE_REACH, FORCE_REACH, 16 do
		for dz = -FORCE_REACH, FORCE_REACH, 16 do
			for dy = 0, 16, 16 do
				local pos = {x = anchor.x + dx, y = anchor.y + dy,
					z = anchor.z + dz}
				if want then
					if core.forceload_block(pos, true, -1) then
						blocks = blocks + 1
					end
				else
					core.forceload_free_block(pos, true)
					blocks = blocks + 1
				end
			end
		end
	end
	return blocks
end

--
-- What is standing in this settlement right now, counted out of the map by
-- identity rather than out of a log.
--
--   objects   every active object in the census sphere
--   mobs      every mobs_redo mob among them (`health` is what the api writes
--             onto every mob it activates and onto nothing else)
--   npcs      the settlement's own roster, by `_grug_start`
--   work/idle/walk  the resident split of contract section 8.3
--
local function census(row)
	local objects = core.get_objects_inside_radius(row.anchor, CENSUS_RADIUS)
	local out = {objects = #objects, mobs = 0, npcs = 0, guards = 0,
		residents = 0, work = 0, static_idle = 0, walkers = 0, vendors = 0,
		-- Is this build's placement engine the one that SPLITS residents? The
		-- same probe is run against the tree before the change to get the
		-- baseline, and there every resident is an undifferentiated ambler --
		-- so the split assertion is made only where there is a split to make.
		split_known = false}
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity then
			if entity.health ~= nil then out.mobs = out.mobs + 1 end
			if entity._grug_start == row.key then
				out.npcs = out.npcs + 1
				local role = entity._grug_socket_role
				if role ~= nil then out.split_known = true end
				if entity.name:find("guard", 1, true) then
					out.guards = out.guards + 1
				elseif entity.name:find("vendor", 1, true) then
					out.vendors = out.vendors + 1
				elseif entity.name:find("villager", 1, true) then
					out.residents = out.residents + 1
					if role == "work" then
						out.work = out.work + 1
					elseif entity._grug_walker then
						out.walkers = out.walkers + 1
					else
						out.static_idle = out.static_idle + 1
					end
				end
			end
		end
	end
	return out
end

local function census_fields(tag, row, data, extra)
	local fields = {"event=" .. tag, "key=" .. row.key,
		"objects=" .. data.objects, "mobs=" .. data.mobs,
		"npcs=" .. data.npcs, "guards=" .. data.guards,
		"vendors=" .. data.vendors, "residents=" .. data.residents,
		"work=" .. data.work, "static_idle=" .. data.static_idle,
		"walkers=" .. data.walkers}
	for index = 1, #(extra or {}) do fields[#fields + 1] = extra[index] end
	log(fields)
end

--
-- The programme: one window per start, in key order. Each window forceloads the
-- arrival, lets the engine settle, measures, reports and releases again -- so
-- only one settlement is active at a time and the numbers are per start rather
-- than per world.
--
local PHASE_FORCE, PHASE_MEASURE, PHASE_REPORT = 1, 2, 3

local current = 0
local phase = PHASE_REPORT
local phase_at = 0
local mark = {}

local function begin(row, clock)
	log({"event=window_open", "key=" .. row.key, "race=" .. row.race_id,
		"anchor=" .. core.pos_to_string(row.anchor),
		"blocks=" .. forceload_area(row.anchor, true)})
	phase, phase_at = PHASE_FORCE, clock + SETTLE
end

local function measure(row, clock)
	local data = census(row)
	census_fields("window_start", row, data)
	mark = {steps = steps, sum = dtime_sum, max_at = dtime_max,
		paths = path_calls}
	dtime_max = 0
	phase, phase_at = PHASE_MEASURE, clock + WINDOW
end

--
-- THE MICROBENCHMARK, and why the server step alone does not answer the
-- question. A dedicated server runs a FIXED step (`dedicated_server_step`,
-- 0.09 s by default) and only exceeds it once it cannot keep up, so the mean
-- step of a quiet world reads 90 ms whatever the settlement costs: it says
-- "there is headroom", which is worth knowing and is not a measurement of the
-- NPCs.
--
-- So the mod-side tick is timed directly: every settlement NPC's `do_custom`
-- is called once with dtime = 1, which is exactly the work the server does for
-- that NPC in one second (each of these families throttles itself on a
-- one-second accumulator), around `core.get_us_time()`. The side effects are
-- the side effects of one ordinary simulated second and it runs at the END of
-- the window, after every census.
--
local function micro_line(row)
	local objects = core.get_objects_inside_radius(row.anchor, CENSUS_RADIUS)
	local npcs = {}
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity and entity._grug_start == row.key and entity.do_custom then
			npcs[#npcs + 1] = entity
		end
	end
	local rounds = 20
	local started = core.get_us_time()
	for _ = 1, rounds do
		for index = 1, #npcs do
			local entity = npcs[index]
			entity:do_custom(1)
		end
	end
	local spent = core.get_us_time() - started
	log({"event=micro", "key=" .. row.key, "npcs=" .. #npcs,
		"rounds=" .. rounds, "us_total=" .. spent,
		"us_per_npc_second=" .. string.format("%.2f",
			(#npcs > 0 and rounds > 0) and (spent / rounds / #npcs) or 0),
		"us_per_settlement_second=" .. string.format("%.2f",
			rounds > 0 and (spent / rounds) or 0)})
end

local function report(row)
	local data = census(row)
	local window_steps = steps - mark.steps
	local window_time = dtime_sum - mark.sum
	local window_paths = path_calls - mark.paths
	local mean_ms = window_steps > 0 and (window_time / window_steps * 1000) or 0
	local share = data.residents > 0 and
		(data.walkers / data.residents * 100) or 0
	census_fields("window", row, data, {
		"seconds=" .. string.format("%.1f", window_time),
		"steps=" .. window_steps,
		"step_mean_ms=" .. string.format("%.2f", mean_ms),
		"step_max_ms=" .. string.format("%.2f", dtime_max * 1000),
		"find_path=" .. window_paths,
		"find_path_per_min=" .. string.format("%.2f",
			window_time > 0 and (window_paths / window_time * 60) or 0),
		"walker_share_pct=" .. string.format("%.1f", share)})
	--
	-- THE TWO CLAIMS OF THE ROUND, asserted here so a regression fails the run
	-- rather than being read out of a table by a human.
	--
	--   1. A settlement full of standing residents costs NO path-finding. The
	--      only caller a settlement has is `patrol.lua`'s stuck rescue, and a
	--      guard that is not stuck never reaches it; nothing a resident does may
	--      ever ask the pathfinder.
	--   2. The walker share is between 10 and 30 percent of residents
	--      (contract section 8.3). Measured on the living population, which is
	--      the number the user sees.
	--
	if window_paths > 0 then
		fail(row.key .. " asked the pathfinder " .. window_paths ..
			" times in a quiet " .. string.format("%.0f", window_time) ..
			" s window")
	end
	if data.split_known and data.residents > 0 and
			(share < 10 or share > 30) then
		fail(row.key .. " has a walker share of " ..
			string.format("%.1f", share) .. " percent of " .. data.residents ..
			" residents")
	end
	micro_line(row)
	forceload_area(row.anchor, false)
	phase = PHASE_REPORT
end

local started = false
local clock = 0
local accumulator = 0

core.register_globalstep(function(dtime)
	steps = steps + 1
	dtime_sum = dtime_sum + dtime
	if dtime > dtime_max then dtime_max = dtime end
	accumulator = accumulator + dtime
	if accumulator < 1 then return end
	local elapsed = accumulator
	accumulator = 0
	if not started then
		if collect_starts() < 1 then return end
		-- EVERY start prepared, not just the first: the windows below run one
		-- after another and a start that is still emerging would be measured
		-- while the preload is spending the very steps under test.
		for index = 1, #starts do
			if not grug_core.start_ready(starts[index].race_id) then return end
		end
		started = true
		log({"event=ready", "starts=" .. #starts,
			"window_s=" .. WINDOW, "settle_s=" .. SETTLE})
	end
	clock = clock + elapsed
	if phase == PHASE_FORCE and clock >= phase_at then
		measure(starts[current], clock)
	elseif phase == PHASE_MEASURE and clock >= phase_at then
		report(starts[current])
	elseif phase == PHASE_REPORT then
		current = current + 1
		if current > #starts then
			log({"event=complete", "starts=" .. #starts,
				"steps=" .. steps,
				"uptime_s=" .. string.format("%.1f", dtime_sum),
				"find_path_total=" .. path_calls})
			core.request_shutdown("wp13 npc load probe done", false, 1)
			phase = 0
			return
		end
		begin(starts[current], clock)
	end
end)
