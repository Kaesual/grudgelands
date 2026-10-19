-- The talents' window runtime, dofiled from talents.lua (Round 52).
--
-- Timed windows (§3.2). A window key contributes only while its talent's
-- window runs; get_talent_bonus returns 0 for it otherwise, so a consumer
-- needs no second accessor and no new mechanism.
--

local windows = {} -- player name -> {talent id -> expiry in us}

function grug_classes.start_talent_window(player, talent_id, duration)
	local def = grug_classes.registered_talents[talent_id]
	if not def or not duration or duration <= 0 then
		return false
	end
	local name = player:get_player_name()
	windows[name] = windows[name] or {}
	windows[name][talent_id] = core.get_us_time() + duration * 1e6
	-- The window's status icon (Round 26 ruling 18) carries the same expiry;
	-- clear_talent_windows removes it with the window.
	local status_id = grug_core.status_icons and
		grug_core.status_icons.TALENT_WINDOWS[talent_id]
	if status_id and grug_core.set_status then
		grug_core.set_status(player, status_id, {
			label = def.name, expiry_us = windows[name][talent_id],
		})
	end
	return true
end

function grug_classes.talent_window_active(player, talent_id)
	local per_player = windows[player:get_player_name()]
	local expiry = per_player and per_player[talent_id]
	if not expiry then
		return false
	end
	if core.get_us_time() > expiry then
		per_player[talent_id] = nil
		return false
	end
	return true
end

function grug_classes.try_trigger_talent_window(player, talent_id, duration,
		cooldown)
	if grug_classes.talent_rank(player, talent_id) <= 0 then return false end
	if not grug_classes.talent_trigger_ready(player, talent_id, cooldown) then
		return false
	end
	return grug_classes.start_talent_window(player, talent_id, duration)
end

function grug_classes.talent_trigger_ready(player, talent_id, cooldown)
	local key = "grug_classes:talent_ready:" .. talent_id
	local now = os.time()
	local meta = player:get_meta()
	if now < (tonumber(meta:get_string(key)) or 0) then return false end
	meta:set_string(key, tostring(now + cooldown))
	return true
end

--
-- Readiness windows by any id (Round 52, B8; round52-class-plan.md §3
-- "CORE-B" item 4 and D1). "The next qualifying attack is empowered": a
-- trigger opens the window, the qualifying attack consumes it (one charge),
-- or it runs out. The id is any string (a talent's, a skill's, a proc's);
-- the window carries an optional value for its consumer. An internal
-- cooldown (ICD) runs on the monotonic clock in memory, for this API only:
-- the talent windows above keep their os.time player-meta clock (D1). The
-- ICD outlives death, respec and a relog within the same server run;
-- clear_talent_windows drops it once it has run out. A window's status icon
-- comes from grug_core.status_icons.WINDOWS.
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
	if grug_classes.talent_window_active(player, "hold_ground") then
		grug_core.clear_move_immunity(player)
	end
	grug_core.clear_absorb_modifiers(player)
	local per_player = windows[player:get_player_name()]
	local status_ids = grug_core.status_icons and
		grug_core.status_icons.TALENT_WINDOWS or {}
	if per_player and grug_core.clear_status then
		for talent_id in pairs(per_player) do
			if status_ids[talent_id] then
				grug_core.clear_status(player, status_ids[talent_id])
			end
		end
	end
	-- The leave cleanup (talents.lua) relies on this line.
	windows[player:get_player_name()] = nil
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
