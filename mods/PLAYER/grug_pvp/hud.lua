-- The PvP status icons (pvp-plan.md rulings 2-3; Round 31 lane P2) on the
-- status icon row (grug_core/status.lua): one status SOURCE read at display
-- time from grug_pvp.state, so the icon can never outlive the flag.
--   pvp_contested  untimed, while the location flags the player (contested
--                  or enemy territory; the label says which);
--   pvp_tagged     with the countdown, while the button or PvP contact keeps
--                  the player flagged outside such ground.
-- Labels and details (the Effects tab's lines) come from view.lua. PvP combat
-- needs no icon here: it is the shared combat state, which combat_hud.lua
-- draws next to the health bar.

local V = dofile(core.get_modpath(core.get_current_modname()) .. "/view.lua")

grug_core.register_status_source(function(player, now_us)
	local state = grug_pvp.state(player)
	local reason = state.flagged and V.REASONS[state.reason]
	if not reason then return nil end
	if reason.location then
		return {{id = "pvp_contested", untimed = true, label = reason.label,
			detail = reason.effect}}
	end
	local seconds = tonumber(state.seconds_left)
	if not seconds or seconds <= 0 then return nil end
	return {{id = "pvp_tagged", expiry_us = now_us + seconds * 1e6,
		label = reason.label, detail = reason.effect}}
end)
