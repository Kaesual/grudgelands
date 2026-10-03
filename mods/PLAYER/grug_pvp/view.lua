-- The PvP tab's texts (pvp-plan.md rulings 2-4, 8 and 16; Round 31 lane P2):
-- what grug_pvp.state and grug_pvp.stats look like to the player. PURE Lua:
-- it calls nothing from `core`, so the portable fixture (tools/r31_p2) loads
-- the real file. page.lua is the sfinv page around it.

local V = {}

V.COLOR_SAFE = "#55ff55"
V.COLOR_FLAGGED = "#ff5555"
V.COLOR_COMBAT = "#f0c75e"

-- Why the player is flagged (state.reason): the name (the status icon's
-- label; the headline after "Flagged: " for a location), the tab's line under
-- the headline and the icon's shorter detail line on the Character page's
-- Effects tab (which clips at 34 characters). A location keeps the flag while
-- the player stays (untimed icon); the button and contact flags count down
-- (state.seconds_left).
V.REASONS = {
	location_contested = {location = true, label = "Contested Territory",
		detail = "Flagged enemy players can attack you here.",
		effect = "Flagged enemies can attack you"},
	location_enemy = {location = true, label = "Enemy Territory",
		detail = "Flagged enemy players can attack you here.",
		effect = "Flagged enemies can attack you"},
	button = {label = "PvP flagged", detail = "You pressed \"Flag me for PvP\".",
		effect = "You pressed the PvP button"},
	contact = {label = "PvP flagged", detail = "PvP contact: 60 s after your last fight.",
		effect = "60 s after your last PvP fight"},
}
V.SAFE = {headline = "Safe",
	detail = "Enemy players cannot attack you, nor you them."}
V.COMBAT = "In PvP combat: no mount, food or travel."

-- The ruling 16 counters in their order; a counter grug_pvp.stats does not
-- report reads 0.
V.STATS = {
	{"kills", "Player kills"},
	{"killing_blows", "Killing blows"},
	{"deaths", "Deaths to players"},
	{"guards", "Enemy guards killed"},
	{"captains", "Enemy captains killed"},
	{"generals", "Enemy generals killed"},
	{"kings", "Enemy kings killed"},
}

function V.seconds_text(seconds)
	return math.max(0, math.ceil(tonumber(seconds) or 0)) .. " s"
end

-- {headline, detail, color, combat}: `combat` is the PvP combat line or nil.
function V.state_lines(state)
	state = type(state) == "table" and state or {}
	local combat = state.pvp_combat and V.COMBAT or nil
	local reason = state.flagged and V.REASONS[state.reason]
	if not state.flagged then
		return {headline = V.SAFE.headline, detail = V.SAFE.detail,
			color = V.COLOR_SAFE, combat = combat}
	end
	local headline
	if reason and reason.location then
		headline = "Flagged: " .. reason.label
	elseif state.seconds_left then
		headline = "Flagged for " .. V.seconds_text(state.seconds_left)
	else
		headline = "Flagged"
	end
	return {headline = headline, detail = reason and reason.detail or "",
		color = V.COLOR_FLAGGED, combat = combat}
end

-- {{label, value}, ...} in V.STATS order.
function V.stats_rows(stats)
	stats = type(stats) == "table" and stats or {}
	local rows = {}
	for index, row in ipairs(V.STATS) do
		rows[index] = {row[2], math.max(0, math.floor(tonumber(stats[row[1]]) or 0))}
	end
	return rows
end

-- Everything the page prints from the two tables, one string: the page is
-- re-sent only when it changes (once a second while a countdown runs).
function V.page_key(state, stats)
	local lines = V.state_lines(state)
	local parts = {lines.headline, lines.detail, lines.combat or ""}
	for _, row in ipairs(V.stats_rows(stats)) do
		parts[#parts + 1] = row[1] .. "=" .. row[2]
	end
	return table.concat(parts, "\n")
end

return V
