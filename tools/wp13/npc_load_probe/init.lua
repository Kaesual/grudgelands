--
-- Disposable headless LOAD probe for the settlement NPCs (WP13 playtest round
-- 3, 2026-09-15). Staged into a scratch game copy by
-- `tools/wp13/run_npc_load.sh` (PROBE= of tools/luanti_headless.sh); never
-- shipped with the game, never loaded by a normal server.
--
-- It answers ONE question, the one the round-3 brief asks for before and after
-- the work-socket change: WHAT DOES A POPULATED SETTLEMENT COST THE SERVER?
--
--   * how many active mobs stand in the settlement,
--   * how many `core.find_path` calls a minute they make -- a STATIC resident
--     must make none at all, which is the whole reason the 80/20 split exists,
--   * the mean and the worst server step over a fixed window,
--   * and, as the census the walker rule is judged by, how the settlement's
--     residents split into static workers, static idlers and walkers.
--
-- WAVE 3 (2026-09-16) ADDS A CAPITAL SUBJECT. The six starts are still the
-- programme; a capital, when the runner names one, is measured LAST and by
-- exactly the same clock -- settle, a thirty-second window, the same census and
-- the same microbenchmark -- so its numbers can be read against the wave-1
-- start numbers of docs/research/wp13-npc-work.md section 7.1 without an
-- apples-to-oranges correction. Three things differ, and only three:
--
--   1. WHAT IS HELD. A start's population lives inside one 128-node pad, so
--      the start windows forceload a 64-node grid around the arrival. A
--      capital's sockets are spread over a 512 envelope and no grid of that
--      size is affordable, so the capital window forceloads EVERY SOCKET'S OWN
--      MAPBLOCK instead, deduplicated by block coordinate -- the same plan
--      `npc_probe`'s capital mode makes, minus its patrol-leg sampling, which
--      exists to prove a marker's holder is in memory and is not a question
--      about cost.
--   2. WHEN THE WINDOW OPENS. A start is ready when `grug_core.start_ready`
--      says so. A capital has no preload at all: its blocks come up as the
--      forceloads land, so the phase waits until the placement engine has
--      marked every socket it owes (`grug_mobs.start_npc_census`) and gives up
--      on a stall clock rather than on a total, because progress is what says
--      whether waiting longer can help.
--   3. WHAT IS ASSERTED. The walker-share rule of the sockets contract's
--      section 8.3 is asserted for a capital exactly as for a start. The
--      ZERO-PATHFINDER rule is REPORTED and not asserted for a capital: it was
--      established for a start's population and a capital carries an order of
--      magnitude more patrol loops, so a run that found a non-zero count there
--      would be reporting a measurement, not catching a regression. The number
--      is in the window line either way.
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

-- The capital subject. `tools/wp13/run_npc_load.sh` writes `subject.lua` into
-- the staged copy of this directory when it is given a capital key; the
-- repository's own copy has no such file and the probe then runs the six
-- starts and nothing else, which is what every wave-1 and wave-2 record was
-- taken with. `tools/luanti_headless.sh` passes no environment into the
-- Flatpak, so a staged file is the only way to hand a probe an argument --
-- the same mechanism `run_npc_probe.sh` uses for its `mode.lua`.
local CAPITAL_KEY = nil
do
	local path = core.get_modpath(core.get_current_modname()) .. "/subject.lua"
	local chunk = loadfile(path)
	if chunk then
		local subject = chunk()
		if type(subject) == "table" and type(subject.capital) == "string" and
				subject.capital ~= "" then
			CAPITAL_KEY = subject.capital
		end
	end
end

-- A capital's own constants. The envelope is 512 square and the outermost
-- district lot stands about 240 nodes out, so 300 is a census sphere that
-- reaches every socket and nothing of a neighbouring settlement (the nearest
-- other anchor is 1800 nodes away).
local CAPITAL_RADIUS = 300
local CAPITAL_BATCH = 24 -- socket blocks forceloaded per second
local CAPITAL_WAIT = 300 -- s the placement engine gets in total
local CAPITAL_STALL = 60 -- ...and s without a single new marked socket

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
	--
	-- AND THE CAPITAL, LAST. Appended after the sort so the six starts keep
	-- exactly the order and therefore exactly the warm-up profile every earlier
	-- record was taken with: the trend inside a run is as large as the
	-- difference between two runs (wp13-npc-work.md section 7.1), so a capital
	-- inserted in key order would have moved the start numbers it is meant to
	-- be compared with.
	--
	if CAPITAL_KEY then
		for index = 1, #settlements do
			local record = settlements[index]
			if record.key == CAPITAL_KEY then
				starts[#starts + 1] = {key = record.key,
					race_id = record.race_id, anchor = record.anchor,
					capital = true, radius = CAPITAL_RADIUS}
			end
		end
	end
	return #starts
end

--
-- A CAPITAL'S BLOCK PLAN: every socket's own mapblock plus the anchor's,
-- deduplicated by block coordinate, because a plot's dozen sockets share two or
-- three blocks and `forceload_block` counts each call against the limit.
-- `limit = -1` is what lifts `max_forceloaded_blocks` (16 by default), which a
-- capital passes several times over.
--
local function capital_plan(row)
	local seen, order = {}, {}
	local function want(pos)
		local id = math.floor(pos.x / 16) .. ":" .. math.floor(pos.y / 16) ..
			":" .. math.floor(pos.z / 16)
		if seen[id] then return end
		seen[id] = true
		order[#order + 1] = {x = pos.x, y = pos.y, z = pos.z}
	end
	want(row.anchor)
	local sockets = grug_core.settlement_sockets_at(row.key) or {}
	for index = 1, #sockets do want(sockets[index].pos) end
	row.blocks = order
	row.block_next = 1
	row.sockets = #sockets
	return #order
end

-- How far the placement engine has got with this settlement.
local function capital_marked(key)
	local rows = grug_mobs.start_npc_census()
	for index = 1, #rows do
		if rows[index].key == key then
			return rows[index].marked, rows[index].roster
		end
	end
	return 0, 0
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
	local objects = core.get_objects_inside_radius(row.anchor,
		row.radius or CENSUS_RADIUS)
	local out = {objects = #objects, mobs = 0, npcs = 0, guards = 0,
		residents = 0, work = 0, static_idle = 0, walkers = 0, vendors = 0,
		-- The smallest wander ring any walker of this settlement was handed;
		-- nil when the build under test has no walkers to speak of.
		min_ring = nil,
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
						--
						-- THE SMALLEST RING ANY WALKER OF THIS SETTLEMENT GOT.
						-- A ring of one is a walker that never moves
						-- (`next_spot` returns the index it was given when the
						-- ring is shorter than two), and Stillgrave shipped
						-- exactly that: its idle sockets are 27 nodes apart and
						-- WALK_RADIUS was a wall. This probe is the only one
						-- that visits all six starts, so it is where that claim
						-- is measured for the five the NPC probe never reaches.
						--
						local ring = #(entity._grug_idle_spots or {})
						if not out.min_ring or ring < out.min_ring then
							out.min_ring = ring
						end
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
		"walkers=" .. data.walkers,
		"min_walker_ring=" .. tostring(data.min_ring)}
	for index = 1, #(extra or {}) do fields[#fields + 1] = extra[index] end
	log(fields)
end

--
-- The programme: one window per start, in key order. Each window forceloads the
-- arrival, lets the engine settle, measures, reports and releases again -- so
-- only one settlement is active at a time and the numbers are per start rather
-- than per world.
--
-- A CAPITAL ADDS TWO PHASES IN FRONT OF THE SETTLE. `PHASE_LOAD` feeds the
-- block plan to `forceload_block` a batch a second; `PHASE_PLACE` then waits
-- for the placement engine to mark every socket the settlement owes. Neither
-- exists for a start, which is ready before its window opens.
local PHASE_FORCE, PHASE_MEASURE, PHASE_REPORT = 1, 2, 3
local PHASE_LOAD, PHASE_PLACE = 4, 5

local current = 0
local phase = PHASE_REPORT
local phase_at = 0
local mark = {}
-- The capital's own waiting state: when the phase started, the best `marked`
-- count seen so far, and when that count last improved.
local wait_from, wait_best, wait_moved = 0, -1, 0

local function begin(row, clock)
	if row.capital then
		local planned = capital_plan(row)
		log({"event=window_open", "key=" .. row.key, "race=" .. row.race_id,
			"kind=capital", "anchor=" .. core.pos_to_string(row.anchor),
			"sockets=" .. row.sockets, "planned_blocks=" .. planned})
		row.held = 0
		phase = PHASE_LOAD
		return
	end
	log({"event=window_open", "key=" .. row.key, "race=" .. row.race_id,
		"kind=start", "anchor=" .. core.pos_to_string(row.anchor),
		"blocks=" .. forceload_area(row.anchor, true)})
	phase, phase_at = PHASE_FORCE, clock + SETTLE
end

-- One batch of the capital's block plan. Returns true when the plan is spent.
local function load_batch(row, clock)
	local done = 0
	while row.block_next <= #row.blocks and done < CAPITAL_BATCH do
		if core.forceload_block(row.blocks[row.block_next], true, -1) == true then
			row.held = row.held + 1
		end
		row.block_next = row.block_next + 1
		done = done + 1
	end
	if row.block_next <= #row.blocks then return false end
	local marked, roster = capital_marked(row.key)
	log({"event=blocks_held", "key=" .. row.key, "planned=" .. #row.blocks,
		"held=" .. row.held, "marked=" .. marked, "roster=" .. roster})
	phase = PHASE_PLACE
	wait_from, wait_best, wait_moved = clock, -1, clock
	return true
end

-- Wait for the placement engine, and give up on a STALL rather than on a
-- total: progress is what says whether waiting longer can help. Either way the
-- window then opens and the line records how complete the population was, so a
-- short run reports a measurement instead of failing.
local function wait_for_placement(row, clock)
	local marked, roster = capital_marked(row.key)
	if marked > wait_best then
		wait_best, wait_moved = marked, clock
	end
	local complete = roster > 0 and marked >= roster
	local stalled = clock - wait_moved >= CAPITAL_STALL
	local spent = clock - wait_from >= CAPITAL_WAIT
	if not (complete or stalled or spent) then return end
	log({"event=placed", "key=" .. row.key, "marked=" .. marked,
		"roster=" .. roster,
		"reason=" .. (complete and "complete" or
			(stalled and "stalled" or "capped")),
		"waited_s=" .. string.format("%.0f", clock - wait_from)})
	row.marked, row.roster = marked, roster
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
	local objects = core.get_objects_inside_radius(row.anchor,
		row.radius or CENSUS_RADIUS)
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
	local extra = {
		"kind=" .. (row.capital and "capital" or "start"),
		"seconds=" .. string.format("%.1f", window_time),
		"steps=" .. window_steps,
		"step_mean_ms=" .. string.format("%.2f", mean_ms),
		"step_max_ms=" .. string.format("%.2f", dtime_max * 1000),
		"find_path=" .. window_paths,
		"find_path_per_min=" .. string.format("%.2f",
			window_time > 0 and (window_paths / window_time * 60) or 0),
		"walker_share_pct=" .. string.format("%.1f", share)}
	if row.capital then
		extra[#extra + 1] = "marked=" .. tostring(row.marked)
		extra[#extra + 1] = "roster=" .. tostring(row.roster)
		extra[#extra + 1] = "blocks_held=" .. tostring(row.held)
	end
	census_fields("window", row, data, extra)
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
	-- CLAIM 1 IS ASSERTED FOR A START AND REPORTED FOR A CAPITAL. It was
	-- established on a start's population, and a capital carries an order of
	-- magnitude more patrol loops over ground the wave-1 evidence never
	-- covered, so failing a run on it would be calling a measurement a
	-- regression. The count is in the window line above either way, and the
	-- research note carries the number this lane measured.
	--
	if window_paths > 0 and not row.capital then
		fail(row.key .. " asked the pathfinder " .. window_paths ..
			" times in a quiet " .. string.format("%.0f", window_time) ..
			" s window")
	end
	--
	-- EVERY WALKER HAS SOMEWHERE TO WALK. Asserted here because this is the
	-- only programme that visits all six starts, and the settlement that had
	-- the defect -- Stillgrave -- is not the one the NPC probe exercises.
	--
	if data.split_known and data.walkers > 0 and
			(data.min_ring == nil or data.min_ring < 2) then
		fail(row.key .. " handed a walker a ring of " ..
			tostring(data.min_ring) .. ": it can never move")
	end
	if data.split_known and data.residents > 0 and
			(share < 10 or share > 30) then
		fail(row.key .. " has a walker share of " ..
			string.format("%.1f", share) .. " percent of " .. data.residents ..
			" residents")
	end
	micro_line(row)
	if row.capital then
		for index = 1, #row.blocks do
			core.forceload_free_block(row.blocks[index], true)
		end
	else
		forceload_area(row.anchor, false)
	end
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
		local subjects = 0
		for index = 1, #starts do
			-- A CAPITAL HAS NO PRELOAD to be ready for -- `start_ready` answers
			-- for a race's START, and asking it about the capital row would
			-- only ask the same question twice. The capital's own readiness is
			-- `PHASE_LOAD` and `PHASE_PLACE`.
			if not starts[index].capital then
				if not grug_core.start_ready(starts[index].race_id) then return end
				subjects = subjects + 1
			end
		end
		started = true
		log({"event=ready", "starts=" .. subjects,
			"subjects=" .. #starts,
			"capital=" .. tostring(CAPITAL_KEY),
			"window_s=" .. WINDOW, "settle_s=" .. SETTLE})
	end
	clock = clock + elapsed
	if phase == PHASE_LOAD then
		load_batch(starts[current], clock)
	elseif phase == PHASE_PLACE then
		wait_for_placement(starts[current], clock)
	elseif phase == PHASE_FORCE and clock >= phase_at then
		measure(starts[current], clock)
	elseif phase == PHASE_MEASURE and clock >= phase_at then
		report(starts[current])
	elseif phase == PHASE_REPORT then
		current = current + 1
		if current > #starts then
			log({"event=complete", "subjects=" .. #starts,
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
