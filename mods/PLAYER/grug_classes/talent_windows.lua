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
	windows[player:get_player_name()] = nil
end
