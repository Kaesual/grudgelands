-- The PvP section of the Party & PvP tab (pvp-plan.md ruling 16; Round 31
-- lane P2; one tab with the party since Round 44, spec §3.8): the "Flag me
-- for PvP" button, the current state (safe, or flagged with its reason and
-- the seconds left; PvP combat) and the statistics, nothing else (no rank,
-- titles or rewards). Texts: view.lua. The page itself is grug_parties's
-- (grug_parties/ui.lua); this file installs the section there
-- (grug_parties.pvp_section) and keeps it current.
--
-- Real coordinates, in the right-hand card positioned by the party page. While the tab is the player's page the section's text is
-- compared once a second and the page re-sent only when it changed, so a
-- countdown costs one send per second and a quiet tab none; a state change
-- re-sends it at once.

local V = dofile(core.get_modpath(core.get_current_modname()) .. "/view.lua")
local FLAG_FIELD = "grug_pvp_flag"
local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

local function label(x, y, text)
	return ("label[%.2f,%.2f;%s]"):format(x, y, esc(text))
end

-- A narrow card beside the party roster. The caller supplies a container;
-- all status texts, statistics and refresh keys still come from view.lua.
local function section(player, context, y)
	local state, stats = grug_pvp.state(player), grug_pvp.stats(player)
	context.grug_pvp_key = V.page_key(state, stats)
	local lines = V.state_lines(state)
	local detail = lines.detail
	if lines.combat then
		detail = detail .. "\n" .. core.colorize(V.COLOR_COMBAT, lines.combat)
	end
	local fs = {
		grug_core.ui.panel(0, y, 6.55, 9.0),
		grug_core.ui.heading(0.3, y + 0.35, "PvP status"),
		label(0.3, y + 0.9, core.colorize(lines.color, lines.headline)),
		("textarea[0.3,%.2f;5.95,1.0;;;%s]"):format(y + 1.2, esc(detail)),
		("textarea[0.3,%.2f;5.95,1.3;;;%s]"):format(y + 2.2, esc(
			"Flags you for 60 s; pressing it again restarts the 60 s.\n" ..
			"PvP needs both players flagged. There is no early unflag.")),
		grug_core.ui.button_style(FLAG_FIELD, "danger"),
		("button[0.3,%.2f;5.95,0.7;%s;Flag me for PvP]"):format(y + 3.6, FLAG_FIELD),
		grug_core.ui.heading(0.3, y + 4.8, "Statistics"),
	}
	for index, row in ipairs(V.stats_rows(stats)) do
		local row_y = y + 5.35 + (index - 1) * 0.45
		fs[#fs + 1] = label(0.3, row_y, row[1]) .. label(5.35, row_y, row[2])
	end
	return table.concat(fs)
end

-- Re-sends the page when the player has it open and the section's text
-- changed.
local function refresh(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == grug_parties.PAGE and
			V.page_key(grug_pvp.state(player), grug_pvp.stats(player)) ~=
			context.grug_pvp_key then
		sfinv.set_player_inventory_formspec(player, context)
	end
end

grug_parties.pvp_section = {
	get = section,
	-- True when the fields were the section's (the page is re-sent here).
	on_fields = function(player, _, fields)
		if not fields[FLAG_FIELD] then return false end
		-- The only PvP sound: the player's own press (user, Round 34);
		-- automatic flag changes stay silent.
		if grug_pvp.flag_now(player) then grug_sounds.play("pvp_on", player) end
		refresh(player)
		return true
	end,
}

grug_pvp.register_on_change(refresh)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 1 then return end
	elapsed = elapsed % 1
	for _, player in ipairs(core.get_connected_players()) do
		refresh(player)
	end
end)
