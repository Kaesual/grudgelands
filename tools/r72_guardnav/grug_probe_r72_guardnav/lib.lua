-- The probe's clock, waiting and the player (from lane TRAPS' probe, Round 72).
local M = {}
local P = "[r72guardnav] "
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
	if M.on_step then M.on_step() end
end)

return M
