-- The Expedition Registrar (Round 71; docs/planning/round71-expeditions-concept.md
-- sections 4 and 5): the villager on the clerk's socket of every capital's guild
-- house, its one window and the notices of a run. It only asks and calls
-- init.lua's interface: every rule and every refusal text are runs.lua's.
--
-- Without a run the window lists the Expeditions, the levels the player may enter
-- in two steps (a tier, which names its ore and gem, then a level inside it) and one
-- row per party member, which warns and stops nobody; with one it shows that run,
-- Enter, and for its leader Finish or Cancel (Round 72.1; Cancel asks first). Nothing
-- here is saved. Since Round 72.1 the Deserter's Mark shows here as a status too.
--
-- Takes over the socket like the Miner's Guild Exchange takes its counter
-- (grug_traders/vendors.lua) and needs no template change. On a world older than
-- this file the clerk gives way at its activation (grug_mobs start_npc_claim).
local M = grug_expeditions
local capital_services = dofile(core.get_modpath("grug_mapgen") .. "/wp13/capital_services.lua")

local ROLE = "expedition_registrar"
local CLERK = "miners_guild/miners_guild_clerk"
local TITLE, SUBTITLE = "Expedition Registrar", "The Miner's Guild needs fighters"
local FORMNAME = "grug_expeditions:registrar"
local REACH = 8
local GREEN, RED, WARN = "#8fdc7a", "#ff6060", "#d4b77d"
-- The window without a run, and with one.
local CHOICE_W, CHOICE_H, RUN_W, RUN_H = 13, 9.9, 9, 9.9
local ROW_PITCH = 0.42
-- Why a run ended, for those it touches. A reason without a row reads as the last.
local ENDED = {
	failed = "Your Expedition could not be prepared. Try again soon.",
	empty = ("Your Expedition has ended: nobody was inside for %d minutes."):format(
		M.catalogue.RESERVE_SECONDS / 60),
	joined_party = "You joined a party, so your Expedition has ended.",
	finished = "Your Expedition has ended.",
	cancelled = "Your Expedition was cancelled.",
}
local ENDED_OTHER = "Your Expedition has ended."
-- Why a player is on the way out without having asked: a line of its own, beside
-- the line of the end. The other ways out are the player's own and say nothing.
local LEFT = {
	expelled = "You are no longer in the party, so you left its Expedition.",
	ended = "You are on your way back.",
}
-- How long the black screen of an arrival lasts: the first blocks of a box take
-- 0.6 to 0.8 s to reach a client, which until then draws the open sky.
local CURTAIN_SECONDS = 1

local capital_keys = {}
for key in pairs(capital_services.PLOTS) do capital_keys[#capital_keys + 1] = key end
table.sort(capital_keys)
for _, key in ipairs(capital_keys) do grug_core.assign_service_socket(key, CLERK, ROLE) end
grug_mobs.register_start_socket_role(ROLE, function(_, settlement)
	return "grug_mobs:villager_" .. settlement.race_id
end)

local sessions = {}
local UI = grug_core.ui

local function esc(text) return core.formspec_escape(tostring(text)) end

-- Bound to the live registrar, within talking range, and to its own faction.
-- A capital's settlement key is its home location's id.
local function permitted(player, entity)
	if not player or not player.is_player or not player:is_player() or
			player:get_hp() <= 0 or type(entity) ~= "table" or
			entity._grug_socket_role ~= ROLE or not entity.object then
		return false
	end
	local location = grug_home.location(entity._grug_start)
	if not location or not grug_factions.serves(location.faction, player) then return false end
	local pos, npc = player:get_pos(), entity.object:get_pos()
	return pos ~= nil and npc ~= nil and vector.distance(pos, npc) <= REACH
end

local function level_text(level)
	return ("Level %d"):format(level)
end

-- A tier's line: its levels, its ore and its gem, by grug_materials' names.
local function resource_name(node)
	local row = grug_materials.resource_for_node(node)
	return row and row.name or node
end
local function tier_text(tier)
	local ore, gem = resource_name(tier.ore), resource_name(tier.gem)
	return ("T%d (%d-%d): %s, %s"):format(tier.tier, tier.min_level, tier.max_level, ore, gem)
end

local function count(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

local state_text = M.state_text

-- One row per member at x, y: name, level, whether they can enter. Returns the
-- number of rows that cannot.
local function eligibility_rows(fs, x, y, rows)
	local refused = 0
	for index, row in ipairs(rows) do
		local top = y + (index - 1) * ROW_PITCH
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]label[%.2f,%.2f;%s]"):format(x, top, esc(row.name),
			x + 3, top, esc("Lv " .. row.level))
		local text = row.eligible and core.colorize(GREEN, "Can enter") or
			core.colorize(RED, row.reason or "Cannot enter")
		if not row.online then text = text .. core.colorize(UI.colors.muted, "  (offline)") end
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + 4, top, esc(text))
		if not row.eligible then refused = refused + 1 end
	end
	return refused
end

-- A coloured line: a label, the read-only textarea draws no colour escapes.
local function coloured_line(fs, y, color, text)
	fs[#fs + 1] = ("label[0.45,%.2f;%s]"):format(y, esc(core.colorize(color, text)))
end

-- The player's own Expedition: its state, who can enter, and Enter. Enter stays
-- while the level or the places say no: the click gives the reason. Its leader also
-- sees Finish once it may end, else Cancel, which asks first (Round 72.1).
local function run_form(player, session, run)
	local def = M.definition(run.expedition)
	local g = UI.text_growth(player, RUN_W, RUN_H)
	local fs = {UI.frame(RUN_W, RUN_H, nil, nil, player), "set_focus[close;true]",
		UI.service_header(RUN_W, TITLE, SUBTITLE, nil, g),
		UI.panel(0.4, 1.6, 8.2, 6.9), UI.heading(0.65, 1.95, def.name, g),
		("label[0.65,2.4;%s]"):format(esc(("%s, %d of %d places taken"):format(
			level_text(run.level), count(run.entered), run.max_players))),
		UI.prose(0.65, 2.7, 7.7, 0.9, state_text(run), false, g),
		UI.heading(0.65, 3.8, "WHO CAN ENTER", g)}
	eligibility_rows(fs, 0.65, 4.2, M.eligibility(player, run.expedition, run.bonus))
	if session.confirm and M.can_cancel(player, run) then
		coloured_line(fs, 8.8, WARN, M.CANCEL_CONFIRM)
		fs[#fs + 1] = "button[2.3,9.15;3.1,0.6;cancel_back;Back]"
		fs[#fs + 1] = UI.button_style("cancel_confirm", "selected", g)
		fs[#fs + 1] = "button[5.6,9.15;3,0.6;cancel_confirm;Confirm]"
		fs[#fs + 1] = "button_exit[0.4,9.15;1.7,0.6;close;Close]"
		return table.concat(fs)
	end
	session.confirm = nil
	if session.message then coloured_line(fs, 8.8, RED, session.message) end
	if run.state ~= "preparing" then
		fs[#fs + 1] = UI.button_style("enter", "selected", g)
		fs[#fs + 1] = ("button[5.6,9.15;3,0.6;enter;Enter]")
	end
	if M.can_finish(player, run) then
		fs[#fs + 1] = "button[2.3,9.15;3.1,0.6;finish;Finish]"
	elseif M.can_cancel(player, run) then
		fs[#fs + 1] = "button[2.3,9.15;3.1,0.6;cancel;Cancel]"
	end
	fs[#fs + 1] = "button_exit[0.4,9.15;1.7,0.6;close;Close]"
	return table.concat(fs)
end

-- The offered levels by tier, in order: {{tier = catalogue row, levels = {row, ...}}}.
local function by_tier(offered)
	local tiers = {}
	for _, row in ipairs(offered) do
		local tier = M.catalogue.tier_of(row.level)
		local last = tiers[#tiers]
		if not last or last.tier ~= tier then
			last = {tier = tier, levels = {}}
			tiers[#tiers + 1] = last
		end
		last.levels[#last.levels + 1] = row
	end
	return tiers
end

-- The chosen level of `offered`, kept while it is still on offer; at first the
-- player's own level, or the nearest one offered. The level and its tier's index.
local function chosen_level(player, session, tiers)
	local own, best, best_gap = grug_xp.get_level(player), nil, nil
	for t, group in ipairs(tiers) do
		for _, row in ipairs(group.levels) do
			if row.bonus == session.bonus then return row, t end
			local gap = math.abs(row.level - own)
			if not best_gap or gap < best_gap then best, best_gap = {row, t}, gap end
		end
	end
	session.bonus = best and best[1].bonus or nil
	if best then return best[1], best[2] end
end

local function choice_body(fs, player, session, def, g)
	fs[#fs + 1] = UI.heading(5.45, 1.95, def.name, g)
	local tiers = by_tier(M.offered_levels(player, def.id))
	session.tiers = tiers
	local level, tier_index = chosen_level(player, session, tiers)
	session.tier = tier_index
	local bonus = level and level.bonus or 0
	if level then
		local tier_items, level_items, level_index = {}, {}, 1
		for i, group in ipairs(tiers) do tier_items[i] = esc(tier_text(group.tier)) end
		for i, row in ipairs(tiers[tier_index].levels) do
			level_items[i] = esc(level_text(row.level))
			if row == level then level_index = i end
		end
		fs[#fs + 1] = ("label[5.45,2.65;Tier]dropdown[7.3,2.35;5.1,0.6;tier;%s;%d;true]")
			:format(table.concat(tier_items, ","), tier_index)
		fs[#fs + 1] = ("label[5.45,3.35;Mob level]dropdown[7.3,3.05;3.2,0.6;level;%s;%d;true]")
			:format(table.concat(level_items, ","), level_index)
	end
	-- A leader sees every member before opening it; the warning stops nobody.
	local party = grug_parties.view(player)
	if level and party then
		fs[#fs + 1] = UI.heading(5.45, 4.05, "WHO CAN ENTER", g)
		if eligibility_rows(fs, 5.45, 4.45, M.eligibility(player, def.id, bonus)) > 0 then
			coloured_line(fs, 8.8, WARN, "Not everyone in your party can enter at this level.")
		end
	end
	if session.message then coloured_line(fs, 8.8, RED, session.message) end
	local ok, why = M.can_create(player, def.id, bonus)
	if ok then
		fs[#fs + 1] = UI.button_style("open", "selected", g)
		fs[#fs + 1] = "button[9.1,9.15;3.5,0.6;open;Open Expedition]"
	else
		fs[#fs + 1] = UI.prose(2.4, 9.15, 10.2, 0.65, why, true, g)
	end
end

local function choice_form(player, session)
	local g = UI.text_growth(player, CHOICE_W, CHOICE_H)
	local fs = {UI.frame(CHOICE_W, CHOICE_H, nil, nil, player), "set_focus[close;true]",
		UI.service_header(CHOICE_W, TITLE, SUBTITLE, nil, g),
		UI.panel(0.4, 1.6, 4.6, 6.9), UI.panel(5.2, 1.6, 7.4, 6.9),
		UI.heading(0.65, 1.95, "EXPEDITIONS", g)}
	local list, rows, selected = M.list(), {}, nil
	session.listed = {}
	for index, row in ipairs(list) do
		session.listed[index] = row.id
		if row.id == session.expedition then selected = row end
	end
	selected = selected or list[1]
	session.expedition = selected and selected.id or nil
	for index, row in ipairs(list) do
		rows[index] = {title = row.name, selected = row == selected,
			subtitle = ("Levels %d-%d, up to %d players"):format(row.level, row.max_level,
				row.max_players)}
	end
	if selected then
		fs[#fs + 1] = UI.rows(session, {name = "expeditions", x = 0.5, y = 2.25, w = 4.4, h = 6.15,
			scale = g, rows = rows})
		choice_body(fs, player, session, selected, g)
	else
		fs[#fs + 1] = UI.prose(0.65, 2.3, 4.1, 1.5, "The guild has no Expedition to offer yet.", true, g)
	end
	fs[#fs + 1] = "button_exit[0.4,9.15;1.7,0.6;close;Close]"
	return table.concat(fs)
end

local function form(player, session)
	local run = M.run_of(player)
	if run then return run_form(player, session, run) end
	session.confirm = nil
	return choice_form(player, session)
end

local function show(player, session)
	core.show_formspec(player:get_player_name(), FORMNAME, form(player, session))
end

function M.open_registrar(player, entity)
	if not permitted(player, entity) then return false end
	local session = {entity = entity, capital = entity._grug_start}
	sessions[player:get_player_name()] = session
	grug_sounds.play("npc_steward", player)
	show(player, session)
	return true
end

-- Both dropdowns send their index with every event of the window: only a change
-- counts, and only an index the window showed. A new tier takes its first level and
-- leaves the level field, which still names the old tier's list.
local function read_level(session, fields)
	local group = fields.tier and session.tiers and session.tiers[tonumber(fields.tier)]
	if group and session.tier ~= tonumber(fields.tier) then
		session.bonus = group.levels[1].bonus
		return true
	end
	local levels = session.tiers and session.tier and session.tiers[session.tier]
	local row = fields.level and levels and levels.levels[tonumber(fields.level)]
	if row and row.bonus ~= session.bonus then
		session.bonus = row.bonus
		return true
	end
	return false
end

local function tell(run, text)
	for _, player in ipairs(core.get_connected_players()) do
		if run.inside[player:get_player_name()] or M.belongs(run, player) then
			grug_core.feed(player, "notice", text, "expedition")
		end
	end
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
	local clicked = UI.rows_event(session, "expeditions", fields)
	local changed = read_level(session, fields)
	if clicked and session.listed[clicked] then
		session.expedition, session.bonus = session.listed[clicked], nil
		changed = true
	end
	if changed then session.message = nil end
	if fields.open and session.expedition then
		local run, why = M.create(player, session.expedition, session.bonus or 0)
		session.message = why
		if run then tell(run, state_text(run)) end
		changed = true
	elseif fields.enter then
		local ok, why = M.enter(player, session.capital)
		if ok then
			sessions[name] = nil
			core.close_formspec(name, FORMNAME)
			return true
		end
		session.message, changed = why, true
	elseif fields.finish then
		local _, why = M.finish(player)
		session.message, changed = why, true
	elseif fields.cancel then
		local ok, why = M.can_cancel(player)
		session.confirm, session.message, changed = ok or nil, why, true
	elseif fields.cancel_confirm then
		-- Only the Confirm of a question the window asked.
		if session.confirm then
			local _, why = M.cancel(player)
			session.message = why
		end
		session.confirm, changed = nil, true
	elseif fields.cancel_back then
		session.confirm, session.message, changed = nil, nil, true
	end
	if changed then show(player, session) end
	return true
end)

local function forget(player) sessions[player:get_player_name()] = nil end
core.register_on_leaveplayer(forget)
core.register_on_dieplayer(forget)

-- A window open on `run` shows the news, and one waiting in the queue moves up.
local function refresh(run)
	for name, session in pairs(sessions) do
		local player = core.get_player_by_name(name)
		local own = player and M.run_of(player)
		if player and (M.belongs(run, player) or (own and own.state == "preparing")) then
			session.message = nil
			show(player, session)
		end
	end
end

M.register_on_ready(function(run)
	tell(run, ("Your Expedition is ready: %s, level %d."):format(
		M.definition(run.expedition).name, run.level))
	refresh(run)
end)

M.register_on_end(function(run, reason)
	tell(run, ENDED[reason] or ENDED_OTHER)
	refresh(run)
end)

M.register_on_leave(function(_, name, reason)
	local player = LEFT[reason] and core.get_player_by_name(name)
	if player then grug_core.feed(player, "notice", LEFT[reason], "expedition_left") end
end)

-- The arrival: black until the box has reached the client, instead of a frame of
-- open sky at y -100.
M.register_on_enter(function(_, name)
	local player = core.get_player_by_name(name)
	if not player then return end
	local curtain = player:hud_add({type = "image", position = {x = 0.5, y = 0.5},
		alignment = {x = 0, y = 0}, scale = {x = -100, y = -100},
		text = "[fill:1x1:#000000", z_index = 1000})
	core.after(CURTAIN_SECONDS, function()
		if player:is_valid() then player:hud_remove(curtain) end
	end)
end)

-- The Deserter's Mark (Round 72.1, runs.lua) in the status row and the Effects tab: a
-- status source, so it shows again after a death, which clears the stored statuses,
-- and after a login, which reads its end back (runs.lua).
grug_core.register_status_source(function(player, now)
	local left = M.deserter_left(player)
	if left then return {{id = "deserter_mark", expiry_us = now + left * 1e6}} end
end)

-- For fixtures: the sessions and the window's text.
M.registrar = {sessions = sessions, form = form, FORMNAME = FORMNAME, ROLE = ROLE, CLERK = CLERK}
