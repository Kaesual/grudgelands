-- The Admin Mail tab (Round 48 lane ADMIN; mail plan §4.2, rulings 3, 5, 6,
-- 10, 11, 18, defaults §3.6, §3.14, §3.15; docs/design/mail.md §6): the
-- privilege `mail_admin` and an inventory tab after Help, shown only with
-- it, without the player inventory (like Party & PvP). Two views:
--   inbox    the shared admin inbox (filters Open, All and the sent
--            Announcements), paginated; the selected message with the
--            sender's header, answering ("Re: <subject>" as an admin letter
--            through grug_mail.answer_ticket, which closes the ticket),
--            closing without an answer and deleting;
--   compose  a new admin letter to one player (grug_mail.send_system, kind
--            "admin") or to All players (grug_mail.send_broadcast, stored
--            once), text only, with a preview of how it shows in the
--            player's mailbox.
-- Every event checks the privilege again: a form submitted without it acts on
-- nothing and leaves the page. The admin's real name is logged with every
-- answer, closing, deletion and letter, and shown ("Closed by") only here.
--
-- Typed text lives in the client until an event sends it; the drafts are
-- kept from every event of this page and written back as the fields'
-- defaults. The three sending buttons carry the serial of the draw they
-- belong to (mail_admin_<action>_<n>); a click from a form drawn before the
-- last successful send (a double click) acts on nothing and its fields are
-- not kept (they are the text the first click already sent).

local M = grug_mail.model
local PAGE = "grug_mail:admin"
grug_mail.ADMIN_PAGE = PAGE
local PRIV = "mail_admin"
grug_mail.ADMIN_PRIV = PRIV
local BADGE = "grug_mail_admin_badge.png"
local W = grug_inventory.UI.frame_w
local X, CONTENT_W = 0.3, W - 0.6

local COLOR = {text = "#ececec", dim = "#a9adb4", dot = "#e8973a", gold = "#f0d58a",
	banner = "#3a3018", row = "#2c3a4f", panel = "#1e2126", bad = "#f0a48f",
	good = "#9fd89a", open = "#9cc3f0", answered = "#9fd89a", closed = "#a9adb4",
	report = "#f0d58a", bug = "#f0a48f", feedback = "#a9c6ea", topic = "#cfd3d8"}
local TOPIC_COLOR = {["Bug report"] = COLOR.bug, Feedback = COLOR.feedback,
	["Player report"] = COLOR.report}

local MONTHS = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
	"Oct", "Nov", "Dec"}

local function esc(text) return core.formspec_escape(tostring(text or "")) end
local function colored(color, text) return core.colorize(color, tostring(text or "")) end

local function date(time)
	local t = os.date("*t", time)
	return t.day .. " " .. MONTHS[t.month]
end

local function date_time(time)
	local t = os.date("*t", time)
	return ("%d %s, %02d:%02d"):format(t.day, MONTHS[t.month], t.hour, t.min)
end

local function clip(text, max)
	if M.text_length(text) <= max then return text end
	return M.truncate(text, max - 3) .. "..."
end

-- One log line, never spanning lines.
local function log(text)
	core.log("action", "[grug_mail] " .. tostring(text):gsub("\n", " / "))
end

local function allowed(player)
	return core.check_player_privs(player, {[PRIV] = true})
end
grug_mail.is_mail_admin = allowed

--
-- The tab's state, in the player's sfinv context
--

local function state_of(context)
	local state = context.grug_mail_admin
	if not state then
		state = {view = "inbox", filter = "open", page = 1, draw = 0, floor = 0,
			answer = "", compose = {to = "", all = false, subject = "", body = ""}}
		context.grug_mail_admin = state
	end
	return state
end

local function say(state, ok, message)
	state.status, state.status_ok = message, ok
end

local function status_line(state, y)
	if not state.status then return "" end
	return ("label[%.2f,%.2f;%s]"):format(X, y, esc(colored(
		state.status_ok and COLOR.good or COLOR.bad, state.status)))
end

-- A sending button's name in the draw shown now.
local function serial(state, action)
	return "mail_admin_" .. action .. "_" .. state.draw
end

local function pager(x, y, page, pages)
	return ("button[%.2f,%.2f;0.8,0.7;mail_admin_prev;<]label[%.2f,%.2f;%s]" ..
		"button[%.2f,%.2f;0.8,0.7;mail_admin_next;>]"):format(x, y, x + 1.0, y + 0.35,
		esc("Page " .. page .. " / " .. pages), x + 2.9, y)
end

--
-- The sender's header (§3.15), as frozen in the ticket
--

local function race_class(ticket)
	local race = ticket.race and grug_classes.registered_races[ticket.race]
	local class = ticket.class and grug_classes.registered_classes[ticket.class]
	local parts = {}
	if race then parts[#parts + 1] = race.name end
	if class then parts[#parts + 1] = class.name end
	return #parts > 0 and table.concat(parts, " ") or "no race or class yet"
end

-- The header lines the admin sees: sender, level, faction, race and class;
-- position and mailbox; game version.
function grug_mail.admin_header(ticket)
	local faction = grug_factions.display_name(ticket.faction) or "no faction"
	local pos = ticket.pos and ("(%d, %d, %d)"):format(ticket.pos.x, ticket.pos.y,
		ticket.pos.z) or "unknown"
	return {
		("From %s · Level %s · %s · %s"):format(tostring(ticket.from),
			tostring(ticket.level or "?"), faction, race_class(ticket)),
		("Position %s · Sent from %s · Version %s"):format(pos,
			tostring(ticket.mailbox or "an unknown mailbox"),
			tostring(ticket.version or "unknown")),
	}
end

-- What the message pane shows: the text, or for a Player report the reason,
-- the note and the frozen copy of the reported letter.
local function message_text(ticket)
	local report = ticket.report
	if not report then return ticket.body end
	local lines = {"Reason: " .. tostring(report.reason)}
	if report.note and report.note ~= "" then lines[#lines + 1] = "Note: " .. report.note end
	lines[#lines + 1] = ""
	lines[#lines + 1] = ("The reported letter #%s from %s, %s:"):format(
		tostring(report.letter_id), tostring(report.from), date_time(report.time))
	lines[#lines + 1] = "Subject: " .. tostring(report.subject)
	lines[#lines + 1] = tostring(report.body)
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Attachments: " .. (report.items and #report.items > 0 and
		table.concat(report.items, ", ") or "none")
	return table.concat(lines, "\n")
end

-- "Closed by" (only admins see it): who closed it, when, with or without an
-- answer.
local function closed_text(ticket)
	return ("%s by %s, %s (only admins see this)"):format(
		ticket.answered and "Answered and closed" or "Closed without answer",
		tostring(ticket.closed_by or "?"), ticket.closed_at and date_time(ticket.closed_at) or "?")
end

--
-- The inbox view
--

local LIST_Y, LIST_H = 1.45, 3.75
local PANEL_Y = 6.15

local function filter_buttons(state, open_count)
	local fs = {}
	for _, entry in ipairs({{"open", 0.0, 1.9, "Open (" .. open_count .. ")"},
			{"all", 2.0, 1.3, "All"}, {"announcements", 3.4, 2.5, "Announcements"}}) do
		local field = "mail_admin_filter_" .. entry[1]
		fs[#fs + 1] = grug_inventory.selected_button_style(field, state.filter == entry[1])
		fs[#fs + 1] = ("button[%.2f,0.2;%.2f,0.7;%s;%s]"):format(X + entry[2], entry[3],
			field, esc(entry[4]))
	end
	fs[#fs + 1] = ("style[mail_admin_new;bgcolor=#3d5f8a]button[%.2f,0.2;2.8,0.7;" ..
		"mail_admin_new;New admin letter]"):format(X + CONTENT_W - 2.8)
	return table.concat(fs)
end

local function ticket_table(fs, rows, selected_id)
	fs[#fs + 1] = ("tableoptions[background=#0d0e10;border=true;highlight=%s;color=%s]")
		:format(COLOR.row, COLOR.text)
	fs[#fs + 1] = "tablecolumns[color,span=1;text,width=6;text,width=7;text,width=17;" ..
		"color,span=1;text,width=5;text,align=right,width=3]"
	local cells, selected = {}, -1
	for index, ticket in ipairs(rows) do
		local state = M.ticket_state(ticket)
		local entries = {TOPIC_COLOR[ticket.topic] or COLOR.topic, ticket.topic,
			clip(ticket.from, 16), clip(ticket.subject ~= "" and ticket.subject or "(no subject)", 40),
			state == "Open" and COLOR.open or state == "Answered" and COLOR.answered or COLOR.closed,
			state, date(ticket.time)}
		for _, entry in ipairs(entries) do cells[#cells + 1] = esc(entry) end
		if ticket.id == selected_id then selected = index end
	end
	fs[#fs + 1] = ("table[%.2f,%.2f;%.2f,%.2f;mail_admin_list;%s;%d]"):format(X, LIST_Y,
		CONTENT_W, LIST_H, table.concat(cells, ","), selected)
end

local function broadcast_table(fs, rows, selected_id)
	fs[#fs + 1] = ("tableoptions[background=#0d0e10;border=true;highlight=%s;color=%s]")
		:format(COLOR.row, COLOR.text)
	fs[#fs + 1] = "tablecolumns[image,width=1,1=" .. BADGE .. ";text,width=24;" ..
		"text,width=8;text,align=right,width=3]"
	local cells, selected = {}, -1
	for index, broadcast in ipairs(rows) do
		for _, entry in ipairs({"1", clip(broadcast.subject ~= "" and broadcast.subject or
				"(no subject)", 50), "by " .. clip(tostring(broadcast.by or "?"), 16),
				date(broadcast.time)}) do
			cells[#cells + 1] = esc(entry)
		end
		if broadcast.id == selected_id then selected = index end
	end
	fs[#fs + 1] = ("table[%.2f,%.2f;%.2f,%.2f;mail_admin_list;%s;%d]"):format(X, LIST_Y,
		CONTENT_W, LIST_H, table.concat(cells, ","), selected)
end

local function ticket_panel(fs, state, ticket)
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,3.45;%s]"):format(X, PANEL_Y, CONTENT_W, COLOR.panel)
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]label[%.2f,%.2f;%s]"):format(X + 0.2, PANEL_Y + 0.3,
		esc(clip(ticket.subject ~= "" and ticket.subject or "(no subject)", 60)),
		X + CONTENT_W - 2.4, PANEL_Y + 0.3, esc(colored(COLOR.dim, date_time(ticket.time))))
	local header = grug_mail.admin_header(ticket)
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]label[%.2f,%.2f;%s]"):format(X + 0.2, PANEL_Y + 0.75,
		esc(colored(COLOR.dim, ticket.topic .. " · " .. header[1])), X + 0.2, PANEL_Y + 1.15,
		esc(colored(COLOR.dim, header[2])))
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,1.8;#0d0e10]textarea[%.2f,%.2f;%.2f,1.8;;;%s]"):format(
		X + 0.15, PANEL_Y + 1.5, CONTENT_W - 0.3, X + 0.15, PANEL_Y + 1.5, CONTENT_W - 0.3,
		esc(message_text(ticket)))
	if ticket.state == "open" then
		fs[#fs + 1] = ("label[%.2f,9.95;%s]"):format(X, esc(colored(COLOR.dim,
			("Answer · arrives in %s's Letters as \"%s\" from the %s and closes the ticket")
			:format(ticket.from, clip(M.reply_subject(ticket.subject), 40), M.ADMIN_LABEL))))
		fs[#fs + 1] = ("textarea[%.2f,10.2;%.2f,1.75;mail_admin_answer;;%s]"):format(X,
			CONTENT_W, esc(state.answer))
	else
		fs[#fs + 1] = ("label[%.2f,9.95;%s]"):format(X, esc(colored(COLOR.dim, closed_text(ticket))))
	end
	fs[#fs + 1] = status_line(state, 12.25)
	if ticket.state == "open" then
		fs[#fs + 1] = ("button[%.2f,12.6;1.6,0.8;mail_admin_delete;Delete]" ..
			"button[%.2f,12.6;2.7,0.8;%s;Close without answer]" ..
			"style[%s;bgcolor=#3d5f8a]button[%.2f,12.6;2.9,0.8;%s;Send answer and close]")
			:format(X + CONTENT_W - 7.4, X + CONTENT_W - 5.7, serial(state, "close"),
				serial(state, "answer"), X + CONTENT_W - 2.9, serial(state, "answer"))
	else
		fs[#fs + 1] = ("button[%.2f,12.6;1.6,0.8;mail_admin_delete;Delete]"):format(
			X + CONTENT_W - 1.6)
	end
end

local function broadcast_panel(fs, state, broadcast)
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,3.45;%s]"):format(X, PANEL_Y, CONTENT_W, COLOR.panel)
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]label[%.2f,%.2f;%s]"):format(X + 0.2, PANEL_Y + 0.3,
		esc(clip(broadcast.subject ~= "" and broadcast.subject or "(no subject)", 60)),
		X + CONTENT_W - 2.4, PANEL_Y + 0.3, esc(colored(COLOR.dim, date_time(broadcast.time))))
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(X + 0.2, PANEL_Y + 0.75, esc(colored(COLOR.dim,
		("To all players, by %s (only admins see this) · expires %s"):format(
		tostring(broadcast.by or "?"), date(broadcast.time + M.EXPIRY)))))
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,2.2;#0d0e10]textarea[%.2f,%.2f;%.2f,2.2;;;%s]"):format(
		X + 0.15, PANEL_Y + 1.1, CONTENT_W - 0.3, X + 0.15, PANEL_Y + 1.1, CONTENT_W - 0.3,
		esc(broadcast.body))
	fs[#fs + 1] = status_line(state, 12.25)
	fs[#fs + 1] = ("label[%.2f,13.0;%s]"):format(X, esc(colored(COLOR.dim,
		"Deleting removes it from every player's Announcements.")))
	fs[#fs + 1] = ("button[%.2f,12.6;1.6,0.8;mail_admin_delete;Delete]"):format(
		X + CONTENT_W - 1.6)
end

-- The list the filter shows, newest first.
local function filtered(state)
	if state.filter == "announcements" then return grug_mail.broadcasts() end
	local tickets = grug_mail.tickets()
	if state.filter == "all" then return tickets end
	local open = {}
	for _, ticket in ipairs(tickets) do
		if ticket.state == "open" then open[#open + 1] = ticket end
	end
	return open
end

local function inbox_view(state, fs)
	local list = filtered(state)
	local open_count = 0
	for _, ticket in ipairs(grug_mail.tickets()) do
		if ticket.state == "open" then open_count = open_count + 1 end
	end
	fs[#fs + 1] = filter_buttons(state, open_count)
	local announcements = state.filter == "announcements"
	local rows, page, pages = M.page(list, state.page)
	state.page, state.rows = page, rows
	fs[#fs + 1] = ("label[%.2f,1.2;%s]"):format(X, esc(colored(COLOR.dim, announcements and
		"Letters to all players, newest first" or
		"Messages to the admin: topic, sender, subject, state and date, newest first")))
	local selected
	if announcements then
		selected = M.find(list, state.selected_broadcast)
		broadcast_table(fs, rows, selected and selected.id)
	else
		selected = grug_mail.ticket(state.selected)
		ticket_table(fs, rows, selected and selected.id)
	end
	fs[#fs + 1] = pager(X, 5.35, page, pages)
	fs[#fs + 1] = ("label[%.2f,5.7;%s]"):format(X + 4.0, esc(colored(COLOR.dim, announcements and
		("%d announcements"):format(#list) or
		("%d shown · %d open in all · messages are deleted 30 days after they arrive")
			:format(#list, open_count))))
	if selected and announcements then
		broadcast_panel(fs, state, selected)
	elseif selected then
		ticket_panel(fs, state, selected)
	else
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(X, PANEL_Y + 0.3, esc(colored(COLOR.dim,
			#list == 0 and (announcements and "No announcements." or "No messages here.") or
			(announcements and "Choose an announcement to read it." or
				"Choose a message to read and answer it."))))
		fs[#fs + 1] = status_line(state, 12.25)
	end
end

--
-- The compose view
--

local function compose_view(state, fs)
	local draft = state.compose
	fs[#fs + 1] = "button[" .. X .. ",0.2;2.8,0.7;mail_admin_back;Back to admin mail]"
	fs[#fs + 1] = ("image[%.2f,0.3;0.5,0.5;%s]label[%.2f,0.55;%s]"):format(X + 3.1, BADGE,
		X + 3.75, esc(colored(COLOR.gold, "New admin letter")))
	fs[#fs + 1] = ("label[%.2f,1.55;To]"):format(X)
	if draft.all then
		fs[#fs + 1] = ("label[%.2f,1.55;%s]"):format(X + 1.2, esc(colored(COLOR.dim,
			"Every player, also characters created later")))
	else
		fs[#fs + 1] = ("field[%.2f,1.25;6.0,0.65;mail_admin_to;;%s]" ..
			"field_close_on_enter[mail_admin_to;false]"):format(X + 1.2, esc(draft.to))
	end
	fs[#fs + 1] = ("checkbox[%.2f,1.575;mail_admin_all;All players;%s]"):format(X + 7.5,
		draft.all and "true" or "false")
	fs[#fs + 1] = ("label[%.2f,2.4;Subject]field[%.2f,2.1;%.2f,0.65;mail_admin_subject;;%s]" ..
		"field_close_on_enter[mail_admin_subject;false]"):format(X, X + 1.2, CONTENT_W - 1.2,
		esc(draft.subject))
	fs[#fs + 1] = ("label[%.2f,3.1;Message]textarea[%.2f,3.35;%.2f,3.6;mail_admin_body;;%s]")
		:format(X, X, CONTENT_W, esc(draft.body))
	-- The preview: the row and the banner as the player's mailbox draws them
	-- (grug_mail window.lua: the unread dot, the shield badge, "Server Admin",
	-- the subject, the date; the reading pane's banner).
	fs[#fs + 1] = ("label[%.2f,7.4;%s]"):format(X, esc(colored(COLOR.dim,
		"Preview: how the letter shows in the player's mailbox (" ..
		(draft.all and "Announcements" or "Letters") .. ")")))
	fs[#fs + 1] = ("button[%.2f,7.05;2.8,0.65;mail_admin_preview;Update preview]"):format(
		X + CONTENT_W - 2.8)
	local subject = M.clean(draft.subject, M.SUBJECT_MAX, false)
	fs[#fs + 1] = ("box[%.2f,7.85;%.2f,0.6;%s]label[%.2f,8.15;%s]image[%.2f,7.9;0.5,0.5;%s]" ..
		"label[%.2f,8.15;%s]label[%.2f,8.15;%s]label[%.2f,8.15;%s]"):format(X, CONTENT_W,
		COLOR.row, X + 0.15, esc(colored(COLOR.dot, "•")), X + 0.5, BADGE, X + 1.15,
		esc(M.ADMIN_LABEL), X + 4.0, esc(clip(subject ~= "" and subject or "(no subject)", 50)),
		X + CONTENT_W - 1.0, esc(colored(COLOR.dim, "today")))
	fs[#fs + 1] = ("box[%.2f,8.6;%.2f,0.6;%s]image[%.2f,8.65;0.5,0.5;%s]label[%.2f,8.9;%s]")
		:format(X, CONTENT_W, COLOR.banner, X + 0.1, BADGE, X + 0.75,
			esc(colored(COLOR.gold, "Sent by the server administration")))
	fs[#fs + 1] = ("label[%.2f,9.6;%s]"):format(X, esc(colored(COLOR.dim, draft.all and
		"Stored once: every player finds it under Announcements for 30 days,\n" ..
		"also characters created after it was sent. Each player's read state is their own." or
		"Text only, no items. Players can answer; answers land in this tab.\n" ..
		"Admin letters always arrive, also in a full mailbox and while the player is offline.")))
	fs[#fs + 1] = status_line(state, 12.25)
	fs[#fs + 1] = ("button[%.2f,12.6;2.0,0.8;mail_admin_discard;Discard]" ..
		"style[%s;bgcolor=#3d5f8a]button[%.2f,12.6;3.2,0.8;%s;Send as Server Admin]"):format(
		X + CONTENT_W - 5.3, serial(state, "send"), X + CONTENT_W - 3.2, serial(state, "send"))
end

--
-- The page
--

function grug_mail.admin_formspec(player, context)
	local state = state_of(context)
	state.draw = state.draw + 1
	-- The focus sits on an invisible button at every send (module guide
	-- "Initial focus"): an edit box or a table would eat the inventory key.
	local fs = {"real_coordinates[true]",
		"set_focus[mail_admin_focus;true]button[0,0;0,0;mail_admin_focus;]"}
	if not allowed(player) then
		fs[#fs + 1] = ("label[%.2f,1.0;%s]"):format(X, esc("Admin Mail needs the " ..
			PRIV .. " privilege."))
	elseif state.view == "compose" then
		compose_view(state, fs)
	else
		inbox_view(state, fs)
	end
	return table.concat(fs)
end

-- Redraws the page (not through sfinv.set_page, whose on_enter would clear
-- the status line).
local function show(player, context)
	if sfinv.get_page(player) == PAGE then sfinv.set_player_inventory_formspec(player, context) end
end

--
-- Events
--

local function keep_drafts(state, fields)
	local function take(target, key, field, max)
		if fields[field] ~= nil then target[key] = M.truncate(fields[field], max) end
	end
	take(state, "answer", "mail_admin_answer", M.BODY_MAX)
	take(state.compose, "to", "mail_admin_to", 40)
	take(state.compose, "subject", "mail_admin_subject", M.SUBJECT_MAX)
	take(state.compose, "body", "mail_admin_body", M.BODY_MAX)
	if fields.mail_admin_all ~= nil then state.compose.all = fields.mail_admin_all == "true" end
end

-- The serial of a sending button in `fields` (any draw), and its action.
local function sending(fields)
	for field in pairs(fields) do
		local action, number = field:match("^mail_admin_(%a+)_(%d+)$")
		if action == "answer" or action == "close" or action == "send" then
			return action, tonumber(number)
		end
	end
	return nil
end

-- Whether the event asks for nothing (an Enter in a single-line field): no
-- redraw, so the field keeps its focus.
local function idle(fields)
	if not fields.key_enter_field then return false end
	for field in pairs(fields) do
		if field ~= "key_enter_field" and field ~= "key_enter" and
				field ~= "mail_admin_to" and field ~= "mail_admin_subject" and
				field ~= "mail_admin_body" and field ~= "mail_admin_answer" then
			return false
		end
	end
	return true
end

local function select_ticket(state, ticket)
	state.selected = ticket and ticket.id or nil
	-- The answer box starts with the message quoted, as a player's Reply does.
	state.answer = ticket and ticket.state == "open" and ticket.body ~= "" and
		M.quote(ticket.body) or ""
end

local function inbox_event(player, state, fields, action)
	local name = player:get_player_name()
	for _, filter in ipairs({"open", "all", "announcements"}) do
		if fields["mail_admin_filter_" .. filter] then
			if state.filter ~= filter then state.filter, state.page = filter, 1 end
			-- The selection stays only while the new list holds it.
			local list = filtered(state)
			if not M.find(list, state.selected) then select_ticket(state, nil) end
			if not M.find(list, state.selected_broadcast) then state.selected_broadcast = nil end
			return
		end
	end
	if fields.mail_admin_new then
		state.view = "compose"
		return
	end
	if fields.mail_admin_prev then
		state.page = state.page - 1
		return
	elseif fields.mail_admin_next then
		state.page = state.page + 1
		return
	end
	local announcements = state.filter == "announcements"
	if fields.mail_admin_delete then
		if announcements then
			local id = state.selected_broadcast
			if id then say(state, grug_mail.delete_broadcast(id, name)) end
			state.selected_broadcast = nil
		else
			local id = state.selected
			if id then say(state, grug_mail.delete_ticket(id, name)) end
			select_ticket(state, nil)
		end
		return
	end
	if action == "answer" then
		local ticket = grug_mail.ticket(state.selected)
		if not ticket then
			say(state, false, "That message is gone.")
		elseif M.clean(state.answer, M.BODY_MAX, true) == "" then
			say(state, false, "Write an answer, or close the message without one.")
		else
			local ok, failure = grug_mail.answer_ticket(ticket.id, name, state.answer)
			if ok then
				state.answer = ""
				say(state, true, ("Answer sent to %s; the message is closed."):format(ticket.from))
				return true
			end
			say(state, false, failure)
		end
		return
	elseif action == "close" then
		local ticket = grug_mail.ticket(state.selected)
		if not ticket then
			say(state, false, "That message is gone.")
			return
		end
		local ok, failure = grug_mail.close_ticket(ticket.id, name, false)
		say(state, ok, ok and "Closed without an answer." or failure)
		if ok then state.answer = "" end
		return ok
	end
	local value = fields.mail_admin_list
	local row = type(value) == "string" and tonumber(value:match("^%u+:(%d+)"))
	local entry = row and state.rows and state.rows[row]
	if entry then
		if announcements then
			state.selected_broadcast = entry.id
		elseif entry.id ~= state.selected then
			select_ticket(state, entry)
		end
	end
end

local function compose_event(player, state, fields, action)
	local name = player:get_player_name()
	if fields.mail_admin_back then
		state.view = "inbox"
		return
	elseif fields.mail_admin_discard then
		state.compose = {to = "", all = false, subject = "", body = ""}
		say(state, true, "Letter discarded.")
		return
	elseif action ~= "send" then
		return -- Update preview, the checkbox: the drafts are kept, the page redraws.
	end
	local draft = state.compose
	local subject = M.clean(draft.subject, M.SUBJECT_MAX, false)
	if subject == "" then
		say(state, false, "Write a subject.")
		return
	end
	if draft.all then
		grug_mail.send_broadcast(subject, draft.body, name) -- logged with the admin's name
		say(state, true, "Announcement sent to all players.")
	else
		local to = M.clean(draft.to, 40, false)
		if to == "" then
			say(state, false, "Write the name of the player, or tick All players.")
			return
		end
		local ok, result = grug_mail.send_system(to, "admin", M.ADMIN_LABEL, subject, draft.body)
		if not ok then
			say(state, false, result)
			return
		end
		to = grug_mail.store.lookup(to) or to
		log(("admin %s wrote admin letter #%d to %s"):format(name, result, to))
		say(state, true, ("Admin letter sent to %s."):format(to))
	end
	state.compose = {to = "", all = false, subject = "", body = ""}
	return true
end

-- The page's events. Returns true (the event is this page's).
function grug_mail.admin_fields(player, context, fields)
	local state = state_of(context)
	if not allowed(player) then
		-- A submission without the privilege (a stale form, a forged one):
		-- nothing happens, and the page is left.
		core.log("warning", ("[grug_mail] %s sent Admin Mail fields without the %s " ..
			"privilege; refused"):format(player:get_player_name(), PRIV))
		context.grug_mail_admin = nil
		sfinv.set_page(player, sfinv.get_homepage_name(player))
		return true
	end
	local action, number = sending(fields)
	if action and number <= state.floor then
		show(player, context) -- a double click: no action, its text is not kept
		return true
	end
	keep_drafts(state, fields)
	-- Closing the window only keeps the typed text; an Enter in a field asks
	-- for nothing.
	if fields.quit or idle(fields) then return true end
	state.status = nil
	local handler = state.view == "compose" and compose_event or inbox_event
	if handler(player, state, fields, action) then
		state.floor = number or state.draw
	end
	show(player, context)
	return true
end

sfinv.register_page(PAGE, {
	title = "Admin Mail",
	is_in_nav = function(_, player)
		return allowed(player)
	end,
	on_enter = function(_, _, context)
		state_of(context).status = nil
	end,
	get = function(_, player, context)
		return sfinv.make_formspec(player, context, grug_mail.admin_formspec(player, context),
			false)
	end,
	on_player_receive_fields = function(_, player, context, fields)
		return grug_mail.admin_fields(player, context, fields)
	end,
})

--
-- The privilege (§3.14). Granting or revoking it redraws the inventory
-- window, so the tab appears or goes at once; a revoke leaves the page if it
-- is open. The callbacks return nothing, so the engine's global privilege
-- callbacks still run (builtin/game/register.lua core.run_priv_callbacks).
--

local function refresh(name, leave)
	local player = core.get_player_by_name(name)
	if not player then return end
	if leave and sfinv.get_page(player) == PAGE then
		sfinv.set_page(player, sfinv.get_homepage_name(player))
	else
		sfinv.set_player_inventory_formspec(player)
	end
end

core.register_privilege(PRIV, {
	description = "Can read and answer the messages to the admin and write admin " ..
		"letters and announcements (the Admin Mail tab)",
	give_to_singleplayer = false,
	give_to_admin = true,
	on_grant = function(name)
		refresh(name, false)
	end,
	on_revoke = function(name)
		refresh(name, true)
	end,
})
