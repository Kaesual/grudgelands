-- The PvP section of the Party & PvP tab (pvp-plan.md ruling 16; Round 31
-- lane P2; one tab with the party since Round 44, spec §3.8): the "Flag me
-- for PvP" button, the current state (safe, or flagged with its reason and
-- the seconds left; PvP combat) and the statistics, nothing else (no rank,
-- titles or rewards). Texts: view.lua. The page itself is grug_parties's
-- (grug_parties/ui.lua); this file installs the section there
-- (grug_parties.pvp_section) and keeps it current.
--
-- Real coordinates, from the y the party page passes down to about 2.9
-- below it. While the tab is the player's page the section's text is
-- compared once a second and the page re-sent only when it changed, so a
-- countdown costs one send per second and a quiet tab none; a state change
-- re-sends it at once.

local V = dofile(core.get_modpath(core.get_current_modname()) .. "/view.lua")
local FLAG_FIELD = "grug_pvp_flag"
local HEADING_COLOR = "#f0c75e"
local LINE = 0.4 -- one label row
local BUTTON_X, BUTTON_W, BUTTON_H = 9.6, 3.6, 0.7
local STATS_X, VALUE_DX, STATS_ROWS = {0.2, 6.85}, 4.2, 4

local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

local function label(y, text, x)
	return ("label[%.2f,%.2f;%s]"):format(x or 0.2, y, esc(text))
end

-- The section's formspec, real coordinates, starting at `y` (a label's y is
-- the middle of its line).
local function section(player, context, y)
	local state, stats = grug_pvp.state(player), grug_pvp.stats(player)
	context.grug_pvp_key = V.page_key(state, stats)
	local lines = V.state_lines(state)
	local fs = {
		label(y + 0.15, core.colorize(HEADING_COLOR, "PvP status")),
		("button[%.2f,%.2f;%.2f,%.2f;%s;Flag me for PvP]"):format(BUTTON_X, y,
			BUTTON_W, BUTTON_H, FLAG_FIELD),
		label(y + 0.15 + LINE, core.colorize(lines.color, lines.headline)),
		label(y + 0.15 + 2 * LINE, lines.detail),
	}
	if lines.combat then
		fs[#fs + 1] = label(y + 0.15 + 3 * LINE, core.colorize(V.COLOR_COMBAT,
			lines.combat))
	end
	fs[#fs + 1] = label(y + 0.15 + 4 * LINE,
		"Flags you for 60 s; pressing it again restarts the 60 s.")
	fs[#fs + 1] = label(y + 0.15 + 5 * LINE,
		"PvP needs both players flagged. There is no early unflag.")
	local stats_y = y + 0.15 + 6 * LINE + 0.1
	fs[#fs + 1] = label(stats_y, core.colorize(HEADING_COLOR, "Statistics"))
	for index, row in ipairs(V.stats_rows(stats)) do
		local column = math.floor((index - 1) / STATS_ROWS) + 1
		local x = STATS_X[column]
		local row_y = stats_y + (1 + (index - 1) % STATS_ROWS) * LINE
		fs[#fs + 1] = label(row_y, row[1], x) .. label(row_y, row[2], x + VALUE_DX)
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
