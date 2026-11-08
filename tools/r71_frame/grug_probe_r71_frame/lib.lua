-- The probe's clock, phases, waiting and the player (from lane SPIKE's probe).
local M = {}
local P = "[r71frame] "
local us = core.get_us_time

M.NAME = "grugcap"

function M.log(msg) core.log("action", P .. msg) end
function M.logf(fmt, ...) M.log(fmt:format(...)) end

function M.check(ok, label)
	M.logf("%s %s", ok and "PASS" or "FAIL", label)
	return ok
end

local phase
function M.phase(label)
	if phase then M.phase_end() end
	phase = {label = label, started = us(), intervals = {}}
end
function M.phase_end()
	local done = phase
	if not done then return end
	phase = nil
	local sorted = done.intervals
	table.sort(sorted)
	local n = #sorted
	local function pick(q)
		return n == 0 and 0 or sorted[math.max(1, math.ceil(n * q))]
	end
	M.logf("PHASE %s wall_s %.2f steps %d p50 %.1f p95 %.1f p99 %.1f max %.1f", done.label,
		(us() - done.started) / 1e6, n, pick(0.5), pick(0.95), pick(0.99), sorted[n] or 0)
end

-- The preparation's job time per step, by phase. Its pump runs through core.after
-- from its own file: nothing in the game knows it is timed. Step intervals cannot
-- show this: a server idling at 90 ms hides any job below that.
local job_rows = {}
M.job_run = nil
local real_after = core.after
core.after = function(delay, fn, ...)
	if delay == 0 and debug.getinfo(fn, "S").source:find("preparation.lua", 1, true) then
		return real_after(0, function()
			local status = M.job_run and grug_expeditions.preparation(M.job_run)
			local name = status and status.phase or "other"
			local t0 = us()
			fn()
			local spent = (us() - t0) / 1000
			local row = job_rows[name] or {count = 0, total = 0, max = 0, list = {}}
			job_rows[name] = row
			row.count, row.total = row.count + 1, row.total + spent
			row.max = math.max(row.max, spent)
			row.list[row.count] = spent
		end)
	end
	return real_after(delay, fn, ...)
end
function M.job_report(label)
	local names = {}
	for name in pairs(job_rows) do names[#names + 1] = name end
	table.sort(names)
	local all = {count = 0, total = 0, max = 0, list = {}}
	for _, name in ipairs(names) do
		local row = job_rows[name]
		table.sort(row.list)
		M.logf("JOB %s %-8s steps %d total_ms %.1f p95 %.2f max %.2f", label, name, row.count, row.total,
			row.list[math.max(1, math.ceil(row.count * 0.95))], row.max)
		all.count, all.total = all.count + row.count, all.total + row.total
		all.max = math.max(all.max, row.max)
		for _, v in ipairs(row.list) do all.list[#all.list + 1] = v end
	end
	if all.count > 0 then
		table.sort(all.list)
		M.logf("JOB %s ALL steps %d total_ms %.1f p50 %.2f p95 %.2f p99 %.2f max %.2f", label, all.count,
			all.total, all.list[math.ceil(all.count * 0.5)], all.list[math.ceil(all.count * 0.95)],
			all.list[math.ceil(all.count * 0.99)], all.max)
	end
	job_rows = {}
end

-- Mapchunks generated, for how much land the player's emerge got done in a phase.
M.chunks = 0
core.register_on_generated(function() M.chunks = M.chunks + 1 end)

function M.wait(seconds)
	local t0 = us()
	while us() - t0 < seconds * 1e6 do coroutine.yield() end
end

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

-- Character creation by the form fields (tools/r502_home's driver).
function M.wait_character()
	while true do
		coroutine.yield()
		local player = M.player()
		if player and grug_core.world_preparation_status().ready and
				player:get_meta():get_string("grug_classes:arriving") == "" then
			if grug_classes.get_class(player) then
				core.close_formspec(M.NAME, "")
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

local last
core.register_globalstep(function()
	local now = us()
	if last and phase then phase.intervals[#phase.intervals + 1] = (now - last) / 1000 end
	last = now
	if M.on_extra then M.on_extra() end
	if M.on_step then M.on_step() end
end)

return M
