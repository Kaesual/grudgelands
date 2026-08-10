-- Runtime-only combat diagnostics (combat_stats.md, "Combat diagnostics").
--
-- Hot combat sites must guard ALL diagnostic work with one of the two cheap
-- predicates below. In particular, do not build a message, result table or
-- diagnostic ray before the predicate succeeds:
--
--   if grug_core.combat_debug_due(name, "swing:ray", 0.25) then
--       grug_core.combat_debug_log(name, "swing_ray", formatted_message)
--   end
--
-- On a disabled player, combat_debug_due returns after exactly one lookup in
-- enabled_players. The rate key is deliberately separate from the event name:
-- callers can group noisy variants under one namespaced limiter while keeping
-- precise event labels in the log.

local enabled_players = {} -- player name -> true
local last_events = {} -- player name -> rate key -> timestamp in microseconds

-- Cheap branch for diagnostic sites that do not need rate limiting. The
-- caller must keep every diagnostic-only operation inside the true branch.
function grug_core.combat_debug_enabled(name)
	return enabled_players[name] == true
end

-- Returns true only when diagnostics are enabled and this event's per-player
-- rate limit permits work. `interval` is in seconds; nil/zero means no limit.
-- The disabled path intentionally performs no clock read and allocates no
-- tables, so callers may put this directly in hot combat paths.
function grug_core.combat_debug_due(name, rate_key, interval)
	if not enabled_players[name] then
		return false
	end
	if not interval or interval <= 0 then
		return true
	end

	local now = core.get_us_time()
	local player_events = last_events[name]
	local last = player_events and player_events[rate_key]
	if last and now >= last and now - last < interval * 1e6 then
		return false
	end
	if not player_events then
		player_events = {}
		last_events[name] = player_events
	end
	player_events[rate_key] = now
	return true
end

-- Emits one already-built diagnostic line. Call only after
-- combat_debug_enabled/combat_debug_due so formatting remains out of disabled
-- paths. The enabled check here is defense in depth, not the hot-path gate.
function grug_core.combat_debug_log(name, event, message)
	if not enabled_players[name] then
		return false
	end
	core.log("action", "[combatdebug][" .. name .. "][" .. event .. "] " ..
		tostring(message))
	return true
end

core.register_chatcommand("combatdebug", {
	params = "on|off",
	description = "Enable or disable combat diagnostics for yourself",
	privs = {server = true},
	func = function(name, param)
		param = param:match("^%s*(.-)%s*$")
		if param == "on" then
			enabled_players[name] = true
			-- A fresh enable starts every limiter ready, including after an
			-- idempotent second /combatdebug on.
			last_events[name] = nil
			return true, "Combat diagnostics enabled; events are written to debug.txt."
		end
		if param == "off" then
			enabled_players[name] = nil
			last_events[name] = nil
			return true, "Combat diagnostics disabled."
		end
		return false, "Usage: /combatdebug on|off"
	end,
})

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	enabled_players[name] = nil
	last_events[name] = nil
end)
