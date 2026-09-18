--
-- Startup preload of all six race start areas (user decision, 2026-09-14).
--
-- Character creation used to emerge only the chosen race's start and made
-- that one player wait for it. The starts generate through the WP40 mapgen,
-- so the first player of every race paid the same mapchunk cost again. The
-- server now emerges the 128 x 128 build envelope of ALL six starts once per
-- world, and character creation waits until every one of them is ready. A
-- durable marker skips the emerge on later server starts.
--
-- Deliberately NOT emerged here: the 256-node blend ring around each
-- envelope. It is terrain, not arrival area, and doubling the volume would
-- quadruple the startup cost.
--
-- No globalstep, no polling: progress is driven exclusively by the engine's
-- emerge callbacks, and listeners are notified only when a start completes.
--

-- Horizontal: the 128 x 128 build envelope, x/z anchor +-64 (inclusive
-- bounds, so -64 .. +63 is the half-open envelope the hard footprint uses).
local CORE_RADIUS = 64
-- Vertical: exactly the extent character creation emerged before, measured
-- from the spawn position (anchor.y + 1), so nothing an arriving player
-- could see or fall through is lost.
local SPAWN_BELOW = 24
local SPAWN_ABOVE = 80
-- Each start spans several mapchunks and every fresh mapchunk costs roughly
-- half a second of WP40 mapgen. Two concurrent requests keep the emerge
-- threads busy without starving ordinary block loading at server start.
local MAX_CONCURRENT = 2
-- An emerge that reports a non-terminal action (EMERGE_CANCELLED on
-- shutdown, EMERGE_ERRORED) is retried a bounded number of times. The marker
-- is written only after all six succeed, so a cancelled run stays unfinished.
local MAX_ATTEMPTS = 3
local RETRY_DELAY = 5

local EXPECTED_STARTS = 6
local PRELOAD_MARKER = "starts_preloaded_v1"
local storage = core.get_mod_storage()
local marker_present = storage:get_int(PRELOAD_MARKER) == 1
local marker_announced = false

local starts = {}
local by_race = {}
local ready_count = 0
local failed_count = 0
local running = 0
local queue = {}
local queue_head = 1
local started_us
local build_failed = false
local progress_callbacks = {}

local function now_us()
	return core.get_us_time and core.get_us_time() or 0
end

local function elapsed_s()
	if not started_us then
		return 0
	end
	return (now_us() - started_us) / 1000000
end

-- Deferred on purpose, with a snapshot of the state that changed. A listener
-- may react by emerging something itself (character creation loads the
-- arrival area at commit), and NOTHING may call core.emerge_area from inside
-- an emerge callback — see the deadlock note at dispatch_later below.
local function notify_progress()
	local ready, total, failed = ready_count, #starts, failed_count > 0
	core.after(0, function()
		for i = 1, #progress_callbacks do
			progress_callbacks[i](ready, total, failed)
		end
	end)
end

--
-- Public API
--

-- Number of start areas that are completely emerged, and the total. The
-- total is the authenticated start count (six) once the world authority is
-- installed, and the expected six before that.
function grug_core.starts_ready()
	return ready_count, #starts > 0 and #starts or EXPECTED_STARTS
end

function grug_core.start_ready(race_id)
	local row = by_race[race_id]
	return row ~= nil and row.ready == true
end

-- True once at least one start has exhausted its attempts. Character
-- creation turns this into its existing retryable failure state instead of
-- letting a player wait forever.
function grug_core.starts_preload_failed()
	return failed_count > 0 or build_failed
end

-- func(ready, total, failed) — called only when a start actually changes
-- state, never per emerged block and never per server step.
function grug_core.register_on_starts_progress(func)
	progress_callbacks[#progress_callbacks + 1] = func
end

local request_next

-- core.emerge_area must NEVER be called from inside an emerge callback. On
-- shutdown EmergeThread::cancelPendingItems holds m_queue_mutex while it runs
-- the completion callbacks (luanti src/emerge.cpp:494-508), and
-- enqueueBlockEmerge re-locks that same non-recursive mutex (emerge.cpp:302):
-- enqueuing from a callback self-deadlocks the emerge thread, and the server
-- joins those threads before on_shutdown runs, so no Lua-side flag can help.
-- Every dispatch out of a callback therefore goes through one scheduled job.
local function dispatch_later()
	core.after(0, function()
		request_next()
	end)
end

local function enqueue(row)
	if row.queued or row.pending or row.ready then
		return
	end
	row.queued = true
	queue[#queue + 1] = row
end

local function emerge_finished(row, failed)
	running = running - 1
	row.pending = false
	if failed then
		if row.attempts < MAX_ATTEMPTS then
			core.log("warning", "[grug_core] start area " .. row.race_id ..
				" did not complete (attempt " .. row.attempts ..
				"); retrying in " .. RETRY_DELAY .. " s")
			core.after(RETRY_DELAY, function()
				if not row.ready then
					enqueue(row)
					request_next()
				end
			end)
		else
			row.failed = true
			failed_count = failed_count + 1
			core.log("error", "[grug_core] start area " .. row.race_id ..
				" could not be prepared after " .. row.attempts .. " attempts")
			notify_progress()
		end
		dispatch_later()
		return
	end
	if not row.ready then
		row.ready = true
		if row.failed then
			row.failed = false
			failed_count = failed_count - 1
		end
		ready_count = ready_count + 1
		core.log("action", ("[grug_core] start area ready: %s (%d/%d, %.1f s)")
			:format(row.race_id, ready_count, #starts, elapsed_s()))
		if ready_count == #starts then
			core.log("action", ("[grug_core] all %d start areas ready after %.1f s")
				:format(#starts, elapsed_s()))
			storage:set_int(PRELOAD_MARKER, 1)
			marker_present = true
			marker_announced = true
		end
		notify_progress()
	end
	dispatch_later()
end

local function request(row)
	row.attempts = row.attempts + 1
	row.pending = true
	running = running + 1
	local cancelled = false
	core.emerge_area(row.pos1, row.pos2, function(_, action, remaining)
		if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
			cancelled = true
		end
		if remaining > 0 then
			return
		end
		emerge_finished(row, cancelled)
	end)
end

request_next = function()
	while running < MAX_CONCURRENT and queue_head <= #queue do
		local row = queue[queue_head]
		queue[queue_head] = false
		queue_head = queue_head + 1
		if row and not row.ready then
			row.queued = false
			request(row)
		end
	end
end

local function build_rows()
	local identities = grug_core.start_identities()
	local rows = {}
	local index = {}
	for i = 1, #identities do
		local identity = identities[i]
		local anchor = identity.anchor
		local spawn_y = anchor.y + 1
		local row = {
			race_id = identity.race_id,
			faction_id = identity.faction_id,
			attempts = 0,
			ready = false,
			failed = false,
			pos1 = {
				x = anchor.x - CORE_RADIUS,
				y = spawn_y - SPAWN_BELOW,
				z = anchor.z - CORE_RADIUS,
			},
			pos2 = {
				x = anchor.x + CORE_RADIUS - 1,
				y = spawn_y + SPAWN_ABOVE,
				z = anchor.z + CORE_RADIUS - 1,
			},
		}
		rows[#rows + 1] = row
		index[row.race_id] = row
	end
	if #rows ~= EXPECTED_STARTS then
		return false, #rows
	end
	starts = rows
	by_race = index
	ready_count = 0
	failed_count = 0
	return true
end

-- Queues every start that is not ready yet. Safe to call again: a completed
-- start is never re-requested, and a queued one is skipped when it completes
-- before its turn.
function grug_core.request_starts_preload()
	if #starts == 0 then
		local built, found = build_rows()
		if not built then
			build_failed = true
			core.log("error", "[grug_core] start preload: the world authority " ..
				"published " .. tostring(found) .. " start anchors instead of " ..
				EXPECTED_STARTS)
			notify_progress()
			return false
		end
		build_failed = false
	end
	if marker_present then
		if ready_count < #starts then
			for i = 1, #starts do
				starts[i].ready = true
			end
			ready_count = #starts
			notify_progress()
		end
		if not marker_announced then
			core.log("action", "[grug_core] start areas already generated")
			marker_announced = true
		end
		return true
	end
	if not started_us then
		started_us = now_us()
		core.log("action", "[grug_core] start preload: emerging " .. #starts ..
			" start areas (" .. (CORE_RADIUS * 2) .. " x " ..
			(CORE_RADIUS * 2) .. " nodes each, " .. MAX_CONCURRENT ..
			" at a time)")
	end
	for i = 1, #starts do
		local row = starts[i]
		if not row.ready then
			if row.failed then
				row.failed = false
				failed_count = failed_count - 1
				row.attempts = 0
			end
			enqueue(row)
		end
	end
	request_next()
	return true
end

-- After every mod has loaded the WP40 authority is installed and the start
-- anchors are authenticated. core.after(0) moves the request off the load
-- callback onto the first server step.
core.register_on_mods_loaded(function()
	core.after(0, function()
		grug_core.request_starts_preload()
	end)
end)
