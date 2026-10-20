-- The talents' window runtime, dofiled from talents.lua (Round 52). The
-- old talent windows (os.time player meta, grug_classes:talent_ready:<id>)
-- went with the old talents in Round 53; the 0.53.0 migration step deleted
-- their stored keys.
--
-- Readiness windows by any id (Round 52, B8; round52-class-plan.md §3
-- "CORE-B" item 4 and D1). "The next qualifying attack is empowered": a
-- trigger opens the window, the qualifying attack consumes it (one charge),
-- or it runs out. The id is any string (a talent's, a skill's, a proc's);
-- the window carries an optional value for its consumer. An internal
-- cooldown (ICD) runs on the monotonic clock in memory. The ICD outlives
-- death, respec and a relog within the same server run; clear_talent_windows
-- drops it once it has run out. A window's status icon comes from
-- grug_core.status_icons.WINDOWS.
--

local ready = {} -- player name -> {window id -> {expiry_us, value}}
local icds = {} -- player name -> {window id -> us time its ICD runs out}

local function window_status(id)
	local map = grug_core.status_icons and grug_core.status_icons.WINDOWS
	return map and map[id]
end

-- Whether the ICD of window `id` has run out (true when it has none).
function grug_classes.window_icd_ready(player, id)
	local per_player = icds[player:get_player_name()]
	local until_us = per_player and per_player[id]
	return not until_us or core.get_us_time() >= until_us
end

-- Opens window `id` for def.duration seconds, unless its ICD still runs.
-- def.icd (seconds, optional) starts the ICD now; def.value is handed to the
-- consumer; def.label names the status icon. Reopening an open window
-- renews it. Returns true when the window opened.
function grug_classes.open_window(player, id, def)
	local duration = type(def) == "table" and tonumber(def.duration)
	if type(id) ~= "string" or id == "" or not duration or duration <= 0 then
		return false
	end
	if not grug_classes.window_icd_ready(player, id) then
		return false
	end
	local name = player:get_player_name()
	local now = core.get_us_time()
	local icd = tonumber(def.icd)
	if icd and icd > 0 then
		icds[name] = icds[name] or {}
		icds[name][id] = now + icd * 1e6
	end
	local record = {expiry_us = now + duration * 1e6, value = def.value}
	ready[name] = ready[name] or {}
	ready[name][id] = record
	local status_id = window_status(id)
	if status_id and grug_core.set_status then
		grug_core.set_status(player, status_id, {
			label = def.label, expiry_us = record.expiry_us,
		})
	end
	return true
end

-- The open window `id` ({expiry_us, value}), or nil. Never consumes it.
function grug_classes.get_window(player, id)
	local per_player = ready[player:get_player_name()]
	local record = per_player and per_player[id]
	if not record then
		return nil
	end
	if core.get_us_time() > record.expiry_us then
		per_player[id] = nil
		return nil
	end
	return record
end

-- The qualifying attack spends the window: returns its record when it was
-- open (the attack is empowered) and closes it with its status icon, else
-- nil. Also the way to end a window early.
function grug_classes.consume_window(player, id)
	local record = grug_classes.get_window(player, id)
	if not record then
		return nil
	end
	ready[player:get_player_name()][id] = nil
	local status_id = window_status(id)
	if status_id and grug_core.clear_status then
		grug_core.clear_status(player, status_id)
	end
	return record
end

local function prune_icds(now)
	for name, per_player in pairs(icds) do
		for id, until_us in pairs(per_player) do
			if until_us <= now then
				per_player[id] = nil
			end
		end
		if next(per_player) == nil then
			icds[name] = nil
		end
	end
end

function grug_classes.clear_talent_windows(player)
	grug_core.clear_absorb_modifiers(player)
	-- The leave cleanup (talents.lua) relies on this function.
	local name = player:get_player_name()
	for id in pairs(ready[name] or {}) do
		local status_id = window_status(id)
		if status_id and grug_core.clear_status then
			grug_core.clear_status(player, status_id)
		end
	end
	ready[name] = nil
	-- A running ICD stays (death, respec, a relog); a run-out one of any
	-- player is dropped here, so the table never grows past the running ones.
	prune_icds(core.get_us_time())
end
