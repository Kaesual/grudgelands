-- The Housing Steward (rulings 7 and 14; renamed from Housing Manager in
-- Round 26, ruling 11): one per capital, handing out the Claim Stone through
-- issue_stone and explaining activation and upkeep in a few lines. The
-- internal role id stays "housing_manager" (sockets, grug_mobs, grug_map).
--
-- NO MAPGEN CHANGE. Like the innkeeper (grug_home), the Steward takes over an
-- existing inhabited gate resident: the gate socket of each capital's tailor
-- service plot (capital_services.lua M.PLOTS[city].tailor). Service plots are
-- required plots, so the capital planner always places them, and the socket
-- keeps its authored, terrain-resolved position; only its role changes before
-- grug_mobs builds its rows at mods-loaded. A missing socket fails the load.
--
-- Needs grug_mapgen (the sockets are registered at its load) and grug_mobs
-- (the role resolver) loaded first: mod.conf `depends` must list both.

return function(ui)

local FORMNAME = "grug_housing:manager"

local MANAGERS = {
	{key = "highcourt", faction = "accord",
		socket = "market_counting_house/market_counting_house_gate_idle"},
	{key = "dur_brannoc", faction = "accord",
		socket = "forge_guild_house/forge_guild_house_gate_idle"},
	{key = "lethariel", faction = "accord",
		socket = "market_weaver/market_weaver_gate_idle"},
	{key = "nhal_veyr", faction = "throng",
		socket = "market_shroud_house/market_shroud_house_gate_idle"},
	{key = "gor_drazhak", faction = "throng",
		socket = "warren_weaver/warren_weaver_gate_idle"},
	{key = "kezamba", faction = "throng",
		socket = "shore_tailor/shore_tailor_gate_idle"},
}
local FACTION = {}

local mobs = rawget(_G, "grug_mobs")
if not mobs or not mobs.register_start_socket_role then
	error("grug_housing: the Housing Steward needs grug_mobs loaded first " ..
		"(mod.conf: depends = grug_mapgen, grug_mobs)", 0)
end
for _, row in ipairs(MANAGERS) do
	grug_core.assign_service_socket(row.key, row.socket, "housing_manager")
	FACTION[row.key] = row.faction
end
mobs.register_start_socket_role("housing_manager", function(_, settlement)
	return "grug_mobs:villager_" .. settlement.race_id
end)

-- The six Steward sockets as world positions, for the map and for probes.
function grug_housing.manager_sockets()
	local result = {}
	for _, row in ipairs(MANAGERS) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
			if socket.id == row.socket then
				result[#result + 1] = {settlement = row.key, socket = socket.id,
					role = socket.role, pos = socket.pos}
			end
		end
	end
	return result
end

local sessions = {}

-- The dialog is bound to the live Steward standing on its own socket, within
-- talking range, and to players of the capital's faction
-- (grug_core.npc_window_permitted).
local function permitted(player, entity)
	return grug_core.npc_window_permitted(player, entity, "housing_manager",
		type(entity) == "table" and FACTION[entity._grug_start] or nil)
end

local LINES = {
	"From level 20 you get one Claim Stone for free.",
	"It claims one map square; hold it to see the free ones.",
	("Activate it within %d minutes with %d coal, charcoal or anthracite,"):format(
		grug_housing.DRAFT_SECONDS / 60, grug_housing.ACTIVATION_LUMPS),
	"or it crumbles and I give you a new one.",
	"It burns coal lumps or charcoal: 99 lumps last about 30 days.",
	"Anthracite burns too and counts as 1.5 lumps.",
	"When the fuel runs out, the protection ends.",
	("After activation the stone stays in place for %d hours."):format(
		grug_housing.PICKUP_LOCK_SECONDS / 3600),
}

-- Round 86 (concept §3.1 rulings 1-6): the choice of the two stones below
-- the explanation, each column with its line and its button or, in the
-- button's place, the reason (account.lua account_offer for the account
-- column). A member's personal column offers leaving instead. Choosing the
-- account while carrying a personal stone asks once (the stone vanishes).
local CHOICE_Y, CHOICE_H = 7.15, 3.1
-- A column: its line (two lines at most) below the heading, then the button
-- or the reason (three lines at most), then the warning (two at most).
local LINE_DY, LINE_H, BUTTON_DY, REASON_DY, REASON_H, WARN_DY, WARN_H =
	0.25, 0.85, 1.2, 1.15, 1.45, 1.85, 0.85

local function personal_column(fs, player, x, y, g, UI)
	local name = player:get_player_name()
	local _, state = grug_housing.player_claim(name)
	fs[#fs + 1] = UI.heading(x, y, "Personal Claim Stone", g)
	if state == "member" then
		fs[#fs + 1] = UI.prose(x, y + LINE_DY, 4.9, LINE_H, "Leave your account's home " ..
			"first; its stone stays with the others.", false, g)
		local ok, reason = grug_housing.can_leave_account(name)
		if ok then
			fs[#fs + 1] = ("button[%g,%g;4.6,0.6;leave;Leave your account's home]"):format(x,
				y + BUTTON_DY)
		else
			fs[#fs + 1] = UI.prose(x, y + REASON_DY, 4.9, REASON_H, reason, true, g)
		end
		return
	end
	fs[#fs + 1] = UI.prose(x, y + LINE_DY, 4.9, LINE_H, "A home of your own: only you " ..
		"own it.", false, g)
	local ok, reason = grug_housing.can_receive_stone(player)
	if ok then
		fs[#fs + 1] = ("button[%g,%g;4.6,0.6;receive;Receive Claim Stone]"):format(x, y + BUTTON_DY)
	else
		fs[#fs + 1] = UI.prose(x, y + REASON_DY, 4.9, REASON_H, reason, true, g)
	end
end

local function account_column(fs, session, player, x, y, g, UI)
	local offer = grug_housing.account_offer(player)
	session.offer = offer
	fs[#fs + 1] = UI.heading(x, y, "Account Claim Stone", g)
	fs[#fs + 1] = UI.prose(x, y + LINE_DY, 4.9, LINE_H, offer.text, false, g)
	if offer.button then
		local label = offer.button
		if session.confirm_account and offer.confirm then label = "Confirm: " .. label end
		fs[#fs + 1] = ("button[%g,%g;4.6,0.6;account;%s]"):format(x, y + BUTTON_DY,
			core.formspec_escape(label))
		if offer.confirm then
			fs[#fs + 1] = UI.prose(x, y + WARN_DY, 4.9, WARN_H, offer.confirm, true, g)
		end
	else
		fs[#fs + 1] = UI.prose(x, y + REASON_DY, 4.9, REASON_H, offer.reason or "", true, g)
	end
end

-- The button only when the player can receive a stone (Round 49 ruling 4),
-- else the reason in its place: below level 20, a stone placed or carried.
-- A full inventory keeps the button; the click then says so in red. While
-- belongings from an old map wait (Round 50 D8), one more line says so.
local function formspec(session, player)
	local lines = LINES
	if grug_housing.recovered.count(player:get_player_name()) > 0 then
		lines = {}
		for index, line in ipairs(LINES) do lines[index] = line end
		lines[#lines + 1] = grug_housing.recovered.notice(player:get_player_name())
	end
	local shift = #lines > #LINES and 0.6 or 0
	local UI = grug_core.ui
	local height = 8.6 + CHOICE_H + shift
	local g = UI.text_growth(player, 11.5, height)
	local fs = {UI.frame(11.5, height, nil, nil, player), "set_focus[close;true]",
		UI.service_header(11.5, "Housing Steward", "Your place in the world", nil, g),
		UI.panel(0.4, 1.6, 10.7, 5.4),
		UI.heading(0.65, 1.95, "01 · RECEIVE YOUR CLAIM STONE", g),
		UI.prose(0.65, 2.2, 10.2, 0.6, LINES[1], false, g),
		UI.heading(0.65, 3.0, "02 · PLACE AND ACTIVATE", g),
		UI.prose(0.65, 3.25, 10.2, 1.25, LINES[2] .. "\n" .. LINES[3] .. " " .. LINES[4], false, g),
		UI.heading(0.65, 4.75, "03 · KEEP IT FUELLED", g),
		UI.prose(0.65, 5.0, 10.2, 1.65, table.concat(LINES, "\n", 5, #LINES), false, g)}
	if shift > 0 then fs[#fs + 1] = UI.prose(0.5, 7.1, 10.5, 0.6, lines[#lines], false, g) end
	local y = CHOICE_Y + shift
	fs[#fs + 1] = UI.panel(0.4, y, 10.7, CHOICE_H - 0.1)
	personal_column(fs, player, 0.65, y + 0.3, g, UI)
	account_column(fs, session, player, 6.0, y + 0.3, g, UI)
	if session.message then
		fs[#fs + 1] = UI.prose(0.4, 7.05 + CHOICE_H + shift, 10.6, 0.6,
			core.colorize(session.message_color or ui.GREEN, session.message), false, g)
	end
	fs[#fs + 1] = ("button_exit[0.4,%g;1.7,0.6;close;Close]"):format(7.7 + CHOICE_H + shift)
	return table.concat(fs)
end

function grug_housing.open_manager(player, entity)
	if not permitted(player, entity) then return false end
	local name = player:get_player_name()
	local session = {entity = entity}
	sessions[name] = session
	grug_sounds.play("npc_steward", player)
	core.show_formspec(name, FORMNAME, formspec(session, player))
	return true
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then return true end
	if fields.quit or not permitted(player, session.entity) then
		sessions[name] = nil
		if not fields.quit then core.close_formspec(name, FORMNAME) end
		return true
	end
	local ok, message
	if fields.receive then
		ok, message = grug_housing.issue_stone(player)
		message = message or (ok and "Here is your Claim Stone." or
			"You cannot receive a Claim Stone now.")
	elseif fields.account then
		-- Round 86: a carried personal stone vanishes, so the first click asks.
		local offer = session.offer
		if offer and offer.confirm and not session.confirm_account then
			session.confirm_account = true
			session.message = nil
			core.show_formspec(name, FORMNAME, formspec(session, player))
			return true
		end
		ok, message = grug_housing.choose_account(player)
	elseif fields.leave then
		ok, message = grug_housing.leave_account(player)
	else
		return true
	end
	session.confirm_account = nil
	session.message = message
	session.message_color = ok and ui.GREEN or ui.RED
	core.show_formspec(name, FORMNAME, formspec(session, player))
	ui.refresh_character(player)
	return true
end)

local function forget(player)
	sessions[player:get_player_name()] = nil
end
core.register_on_leaveplayer(forget)
core.register_on_dieplayer(forget)

ui.manager_sessions = sessions
ui.manager_formname = FORMNAME

end
