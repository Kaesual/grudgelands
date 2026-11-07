-- The probe's clock, phases, waiting and the player.
local M = {}
local P = "[r71spike] "
local us = core.get_us_time

M.NAME = "grugcap"

function M.log(msg) core.log("action", P .. msg) end
function M.logf(fmt, ...) M.log(fmt:format(...)) end

-- One step interval in ms per entry, of the phase in progress.
local phase

function M.phase(label)
	if phase then M.phase_end() end
	phase = {label = label, started = us(), intervals = {}, job_us = 0, job_max = 0,
		epoch = os.time()}
	M.logf("PHASE_START %s epoch %d", label, phase.epoch)
end

-- A stretch of the job, for the phase's job columns. Returns its time in ms.
function M.timed(fn, ...)
	local t0 = us()
	fn(...)
	local spent = us() - t0
	if phase then
		phase.job_us = phase.job_us + spent
		if spent > phase.job_max then phase.job_max = spent end
	end
	return spent / 1000
end

local function rtt()
	local info = core.get_player_information(M.NAME)
	return info and info.avg_rtt or 0
end

function M.phase_end(extra)
	local done = phase
	if not done then return end
	phase = nil
	local sorted = done.intervals
	table.sort(sorted)
	local n = #sorted
	local function pick(q)
		if n == 0 then return 0 end
		return sorted[math.max(1, math.ceil(n * q))]
	end
	local over = 0
	for i = 1, n do
		if sorted[i] > 150 then over = over + 1 end
	end
	M.logf("PHASE %s wall_s %.2f steps %d p50 %.1f p95 %.1f p99 %.1f max %.1f over150 %d " ..
		"job_ms %.1f job_max_ms %.1f rtt %.3f lua_kb %d epoch %d..%d %s",
		done.label, (us() - done.started) / 1e6, n, pick(0.5), pick(0.95), pick(0.99),
		sorted[n] or 0, over, done.job_us / 1000, done.job_max / 1000, rtt(),
		collectgarbage("count"), done.epoch, os.time(), extra or "")
end

function M.yield() coroutine.yield() end

function M.wait(seconds)
	local t0 = us()
	while us() - t0 < seconds * 1e6 do coroutine.yield() end
end

-- Waits for fn() to be true; returns the seconds it took, or nil on timeout.
function M.wait_for(fn, timeout)
	local t0 = us()
	while not fn() do
		if timeout and us() - t0 > timeout * 1e6 then return nil end
		coroutine.yield()
	end
	return (us() - t0) / 1e6
end

function M.player() return core.get_player_by_name(M.NAME) end

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

-- The driver of tools/r502_home's probe: character creation by the form fields.
function M.wait_character()
	while true do
		coroutine.yield()
		local player = M.player()
		if player and grug_core.world_preparation_status().ready and
				player:get_meta():get_string("grug_classes:arriving") == "" then
			if grug_classes.get_class(player) then
				core.close_formspec(M.NAME, "")
				player:set_physics_override({gravity = 0, speed = 0, jump = 0})
				M.logf("character complete at %s", core.pos_to_string(vector.round(player:get_pos())))
				return player
			end
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
		end
	end
end

-- Mapblock-aligned chunk arithmetic. chunksize 5: a mapchunk is 80 nodes, its
-- lowest corner at 80 k - 32 on every axis.
M.CHUNK = 80
function M.chunk_index(v) return math.floor((v + 32) / 80) end
function M.chunk_min(k) return 80 * k - 32 end

-- Every chunk that holds a node of the area, as {x, y, z} chunk indices.
function M.chunks_of(minp, maxp)
	local list = {}
	for kz = M.chunk_index(minp.z), M.chunk_index(maxp.z) do
		for ky = M.chunk_index(minp.y), M.chunk_index(maxp.y) do
			for kx = M.chunk_index(minp.x), M.chunk_index(maxp.x) do
				list[#list + 1] = {x = kx, y = ky, z = kz}
			end
		end
	end
	return list
end

-- A test slot: a box whose corner is one mapblock inside chunk (kx, ky, kz).
function M.slot(kx, ky, kz, w, h, d)
	local minp = {x = M.chunk_min(kx) + 16, y = M.chunk_min(ky) + 16, z = M.chunk_min(kz) + 16}
	return {minp = minp, w = w, h = h, d = d,
		maxp = {x = minp.x + w - 1, y = minp.y + h - 1, z = minp.z + d - 1}}
end

function M.grown(slot, by)
	return vector.subtract(slot.minp, by), vector.add(slot.maxp, by)
end

-- emerge_area over an area, waiting for the last callback; a block another
-- emerge was already making comes back cancelled and is asked for again.
-- Returns seconds, generated, from_db, from_memory, cancelled counts.
function M.emerge(p1, p2)
	local t0 = us()
	local remaining, counts = nil, {[0] = 0, 0, 0, 0}
	local cancelled
	local finished
	repeat
		cancelled = 0
		remaining = nil
		core.emerge_area(p1, p2, function(_, action, left)
			counts[action] = (counts[action] or 0) + 1
			if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
				cancelled = cancelled + 1
			end
			remaining = left
			-- the callback runs on the emerge thread, so this is finer than a step
			if left == 0 then finished = us() end
		end)
		while remaining ~= 0 do coroutine.yield() end
	until cancelled == 0
	return (finished - t0) / 1e6, counts[core.EMERGE_GENERATED] or 0,
		counts[core.EMERGE_FROM_DISK] or 0, counts[core.EMERGE_FROM_MEMORY] or 0,
		counts[core.EMERGE_CANCELLED] or 0
end

-- Generates an area one chunk at a time, each by one block: the emerge queue
-- never holds more than that one entry, so a player's request waits for at
-- most the chunk in progress. Returns the per-chunk seconds.
function M.emerge_chunkwise(p1, p2)
	local times = {}
	for _, k in ipairs(M.chunks_of(p1, p2)) do
		local at = {x = M.chunk_min(k.x) + 40, y = M.chunk_min(k.y) + 40, z = M.chunk_min(k.z) + 40}
		times[#times + 1] = (M.emerge(at, at))
	end
	return times
end

function M.sizes_text(times)
	local parts = {}
	for i, t in ipairs(times) do parts[i] = ("%.2f"):format(t) end
	return table.concat(parts, " ")
end

function M.file_size(path)
	local f = io.open(path, "rb")
	if not f then return 0 end
	local size = f:seek("end")
	f:close()
	return size
end

function M.map_size()
	return M.file_size(core.get_worldpath() .. "/map.sqlite")
end

-- The step recorder: the probe's only globalstep.
local last
core.register_globalstep(function()
	local now = us()
	-- a check that reads a whole box back is the probe's, not the preparation's
	if last and phase and not M.pause_recording then
		phase.intervals[#phase.intervals + 1] = (now - last) / 1000
	end
	last = now
	if M.on_step then M.on_step() end
end)

return M
