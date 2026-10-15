-- The mailbox window (mail plan §3.1-§3.9): one formspec (v6, real
-- coordinates, the inventory window's size) with four tabs: Letters,
-- Announcements (the broadcasts), Write and To the admin. Opened by the
-- mailbox node's right-click (lane WORLD's grug_mapgen:mailbox calls
-- grug_mail.open_mailbox). Every action re-checks that the node at the
-- opening position is still a mailbox and the player stands within RANGE
-- nodes of it; closing the window gives the attachment slots back.
--
-- Typed text lives in the client until an event sends it, and a resend of
-- the form does not keep it (guiFormSpecMenu regenerateGui keeps tables and
-- the focus, not edit boxes). So the drafts are kept from every event and
-- written back as the fields' defaults, and the window is resent only on an
-- event, never on an inventory move. So the Write tab shows the postage
-- rule, never a figure for the slots as drawn, and Send charges the slots as
-- they are at the click (Round 49 ruling 1); its result line names the
-- amount paid.

local M, S = grug_mail.model, grug_mail.store
local UI = grug_inventory.UI
local W, H = UI.frame_w, UI.frame_h
local FORM_PREFIX = "grug_mail:mailbox_"
local RANGE = 6
-- The mailbox node (lane WORLD, grug_mapgen/world_nodes.lua).
grug_mail.MAILBOX_NODE = "grug_mapgen:mailbox"
local ATTACH = grug_mail.ATTACH_LIST
local TABS = {"letters", "announcements", "write", "admin"}
local TAB_INDEX = {letters = 1, announcements = 2, write = 3, admin = 4}
local BADGE = "grug_mail_admin_badge.png"
local SEAL = "grug_mail_npc_seal.png"

local COLOR = {text = "#ececec", dim = "#a9adb4", unread = "#ffffff",
	read = "#b8bcc2", dot = "#e8973a", gold = "#f0d58a", banner = "#3a3018",
	bad = "#f0a48f", good = "#9fd89a", open = "#9cc3f0", answered = "#9fd89a",
	closed = "#a9adb4", panel = "#00000040", dialog = "#24272c", alarm = "#c0583f"}

local MONTHS = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
	"Oct", "Nov", "Dec"}

local function esc(text) return core.formspec_escape(tostring(text or "")) end
local function colored(color, text) return core.colorize(color, tostring(text or "")) end

local function date(time)
	local t = os.date("*t", time)
	return t.day .. " " .. MONTHS[t.month]
end

--
-- The mailbox's name (§3.16): the label of the settlement whose waystone
-- socket lies within LABEL_REACH nodes, collected once every settlement is
-- registered.
--

local LABEL_REACH = 16
local pads = {}
core.register_on_mods_loaded(function()
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
			if socket.role == "waypoint" then
				pads[#pads + 1] = {pos = socket.pos, label = row.display_name or row.key}
			end
		end
	end
end)

-- The settlement a mailbox at `pos` belongs to, or nil.
function grug_mail.mailbox_label(pos)
	local best, best_distance
	for _, pad in ipairs(pads) do
		local distance = vector.distance(pos, pad.pos)
		if distance <= LABEL_REACH and (not best_distance or distance < best_distance) then
			best, best_distance = pad, distance
		end
	end
	return best and best.label or nil
end

local function mailbox_text(session)
	return session.label and ("Mailbox in " .. session.label) or "Mailbox"
end

--
-- Sessions
--

local sessions, serial = {}, 0

local function at_mailbox(player, pos)
	if not player or not player:is_player() or player:get_hp() <= 0 then return false end
	if core.get_node(pos).name ~= grug_mail.MAILBOX_NODE then return false end
	local at = player:get_pos()
	return at ~= nil and vector.distance(at, pos) <= RANGE
end

local function new_session(pos)
	serial = serial + 1
	return {formname = FORM_PREFIX .. serial, pos = vector.new(pos),
		label = grug_mail.mailbox_label(pos), tab = "letters",
		pages = {letters = 1, announcements = 1, tickets = 1}, selected = {},
		draft = {to = "", subject = "", body = ""},
		admin = {topic = 1, subject = "", body = ""},
		report = {reason = 1, note = ""}, inv = {}, draw = 0}
end

--
-- Shared parts
--

local function status_line(session, y)
	if not session.status then return "" end
	return ("label[0.4,%.2f;%s]"):format(y, esc(colored(
		session.status_ok and COLOR.good or COLOR.bad, session.status)))
end

local function pager(prefix, x, y, page, pages)
	return ("button[%.2f,%.2f;0.8,0.7;%s_prev;<]label[%.2f,%.2f;%s]" ..
		"button[%.2f,%.2f;0.8,0.7;%s_next;>]"):format(x, y, prefix, x + 1.0, y + 0.35,
		esc("Page " .. page .. " / " .. pages), x + 2.9, y, prefix)
end

local function frame(player, session, counts)
	local captions = {
		counts.letters > 0 and ("Letters (" .. counts.letters .. ")") or "Letters",
		counts.announcements > 0 and ("Announcements (" .. counts.announcements .. ")") or
			"Announcements",
		"Write", "To the admin"}
	for index, caption in ipairs(captions) do captions[index] = esc(caption) end
	return table.concat({
		("formspec_version[6]size[%.3f,%.3f]"):format(W, H),
		-- The focus sits on an invisible button at every send (module guide
		-- "Initial focus"): an edit box or a table would eat the inventory key.
		"set_focus[grug_mail_focus;true]button[0,0;0,0;grug_mail_focus;]",
		("tabheader[0,0;grug_mail_tab;%s;%d;false;true]"):format(
			table.concat(captions, ","), TAB_INDEX[session.tab]),
		"label[0.4,0.55;", esc(mailbox_text(session)), "]",
		("label[%.2f,0.55;%s]"):format(W - 3.4, esc(colored(COLOR.dim, "Purse: ") ..
			grug_money.format(grug_money.get(player)))),
	})
end

-- The four attachment cells of a letter: item images with their tooltip.
local CELL, CELL_STEP = 0.8, 0.9
local function attachment_cells(fs, items, x, y)
	for index = 1, M.STACKS do
		local cx = x + (index - 1) * CELL_STEP
		fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,%.2f;#1e2126]"):format(cx, y, CELL, CELL)
		local item = items[index]
		if item then
			local stack = ItemStack(item)
			fs[#fs + 1] = ("item_image[%.2f,%.2f;%.2f,%.2f;%s]"):format(cx, y, CELL, CELL,
				esc(item))
			fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,%.2f;%s]"):format(cx, y, CELL, CELL,
				esc(stack:get_description()))
		end
	end
end

-- Shortened for a list column (the column grows with its longest cell, and
-- the date must stay in view).
local function clip(text, max)
	if M.text_length(text) <= max then return text end
	return M.truncate(text, max - 3) .. "..."
end
local FROM_CHARS, SUBJECT_CHARS = 15, 18

-- A letter or broadcast list as a table[] of one page: the unread dot, the
-- badge, sender, subject (with the number of attachments) and date.
local function letter_table(fs, name, rows, selected_id, x, y, w, h)
	fs[#fs + 1] = ("tableoptions[background=#0d0e10;border=true;highlight=#2c3a4f;" ..
		"color=%s]"):format(COLOR.text)
	fs[#fs + 1] = ("tablecolumns[color,span=1;text,width=0.6;image,width=1,1=%s,2=%s;" ..
		"color;text,width=6;text,width=8;text,align=right,width=3]"):format(BADGE, SEAL)
	local cells, selected = {}, 0
	for index, row in ipairs(rows) do
		local marker = row.items and #row.items > 0 and (" (+" .. #row.items .. ")") or ""
		local subject = clip(row.subject ~= "" and row.subject or "(no subject)",
			SUBJECT_CHARS - #marker) .. marker
		local badge = (row.kind == "admin" or not row.kind) and 1 or row.kind == "npc" and 2 or 0
		local entries = {COLOR.dot, row.read and "" or "•", tostring(badge),
			row.read and COLOR.read or COLOR.unread, clip(row.from or M.ADMIN_LABEL, FROM_CHARS),
			subject, date(row.time)}
		for _, entry in ipairs(entries) do cells[#cells + 1] = esc(entry) end
		if row.id == selected_id then selected = index end
	end
	fs[#fs + 1] = ("table[%.2f,%.2f;%.2f,%.2f;%s;%s;%d]"):format(x, y, w, h, name,
		table.concat(cells, ","), selected)
end

-- The row a table event names ("CHG:<row>:<column>"), or nil.
local function table_row(value)
	local row = type(value) == "string" and value:match("^%u+:(%d+):")
	return row and tonumber(row) or nil
end

--
-- Letters and Announcements: the list left, the reading pane right
--

local LIST_X, LIST_Y, LIST_W, LIST_H = 0.4, 1.45, 7.5, 5.4
local PANE_X, PANE_W = 8.15, 4.95
local BODY_Y = 3.15

local function reading_head(fs, entry, kind)
	if kind == "admin" then
		fs[#fs + 1] = ("box[%.2f,1.2;%.2f,0.6;%s]image[%.2f,1.25;0.5,0.5;%s]" ..
			"label[%.2f,1.5;%s]"):format(PANE_X, PANE_W, COLOR.banner, PANE_X + 0.1, BADGE,
			PANE_X + 0.75, esc(colored(COLOR.gold, "Sent by the server administration")))
	elseif kind == "npc" then
		fs[#fs + 1] = ("image[%.2f,1.25;0.5,0.5;%s]label[%.2f,1.5;%s]"):format(PANE_X + 0.1,
			SEAL, PANE_X + 0.75, esc(colored(COLOR.dim, "From a character of the realm")))
	end
	fs[#fs + 1] = ("label[%.2f,2.15;%s]"):format(PANE_X, esc(grug_inventory.wrap_text(
		entry.subject ~= "" and entry.subject or "(no subject)", 34)))
	fs[#fs + 1] = ("label[%.2f,2.9;%s]label[%.2f,2.9;%s]"):format(PANE_X,
		esc(colored(COLOR.dim, "From: ") .. (entry.from or M.ADMIN_LABEL)),
		PANE_X + PANE_W - 1.0, esc(colored(COLOR.dim, date(entry.time))))
end

local function reading_body(fs, entry, height)
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,%.2f;#0d0e10]textarea[%.2f,%.2f;%.2f,%.2f;;;%s]")
		:format(PANE_X, BODY_Y, PANE_W, height, PANE_X, BODY_Y, PANE_W, height,
			esc(entry.body))
end

local function dialog_box(fs, y, h)
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,%.2f;%s]box[%.2f,%.2f;%.2f,%.2f;%s]"):format(
		PANE_X, y, PANE_W, h, COLOR.alarm, PANE_X + 0.03, y + 0.03, PANE_W - 0.06, h - 0.06,
		COLOR.dialog)
end

local function report_dialog(fs, session, letter)
	dialog_box(fs, 7.75, 4.7)
	fs[#fs + 1] = ("label[%.2f,8.1;%s]"):format(PANE_X + 0.2, esc(colored(COLOR.bad,
		"Really report this letter\nfrom " .. letter.from .. "?")))
	local reasons = {}
	for index, reason in ipairs(M.REPORT_REASONS) do reasons[index] = esc(reason) end
	fs[#fs + 1] = ("label[%.2f,9.3;Reason]dropdown[%.2f,9.0;3.35,0.6;report_reason;%s;%d;true]")
		:format(PANE_X + 0.2, PANE_X + 1.4, table.concat(reasons, ","), session.report.reason)
	fs[#fs + 1] = ("label[%.2f,10.05;Note]field[%.2f,9.75;3.35,0.6;report_note;;%s]" ..
		"field_close_on_enter[report_note;false]"):format(PANE_X + 0.2, PANE_X + 1.4,
		esc(session.report.note))
	fs[#fs + 1] = ("label[%.2f,10.7;%s]"):format(PANE_X + 0.2, esc(colored(COLOR.dim,
		"The note is optional. A copy of the\nletter goes to the server admin.")))
	fs[#fs + 1] = ("button[%.2f,11.45;1.6,0.75;report_cancel;Cancel]" ..
		"style[report_confirm_%d;bgcolor=#8a3a2c]button[%.2f,11.45;1.6,0.75;report_confirm_%d;Report]")
		:format(PANE_X + 1.4, letter.id, PANE_X + 3.15, letter.id)
end

-- The confirm buttons and Delete carry the letter's id: a click from a form
-- drawn for another letter (a row clicked meanwhile) acts on nothing.
local function delete_dialog(fs, letter)
	dialog_box(fs, 9.25, 2.9)
	fs[#fs + 1] = ("label[%.2f,9.6;%s]label[%.2f,10.25;%s]"):format(PANE_X + 0.2,
		esc(colored(COLOR.bad, "This letter still holds\nits attachments.")), PANE_X + 0.2,
		esc("Delete it together with them?"))
	fs[#fs + 1] = ("button[%.2f,11.15;1.6,0.75;delete_cancel;Cancel]" ..
		"style[delete_confirm_%d;bgcolor=#8a3a2c]button[%.2f,11.15;1.6,0.75;delete_confirm_%d;Delete]")
		:format(PANE_X + 1.4, letter.id, PANE_X + 3.15, letter.id)
end

local function letters_tab(player, session, fs)
	local box = S.box(player:get_player_name())
	local letters = box.letters
	local selected = M.find(letters, session.selected.letters)
	local rows, page, pages = M.page(letters, session.pages.letters)
	session.pages.letters = page
	session.rows = rows
	local unread = 0
	for _, letter in ipairs(letters) do if not letter.read then unread = unread + 1 end end
	fs[#fs + 1] = ("label[%.2f,1.2;%s]"):format(LIST_X, esc(colored(COLOR.dim,
		"From, subject and date, newest first")))
	letter_table(fs, "letters", rows, selected and selected.id, LIST_X, LIST_Y, LIST_W, LIST_H)
	fs[#fs + 1] = pager("letters", LIST_X, 7.05, page, pages)
	fs[#fs + 1] = ("label[%.2f,8.1;%s]"):format(LIST_X, esc(colored(COLOR.dim,
		("%d letters · %d unread · %d player letters at most"):format(#letters, unread,
		M.LETTER_LIMIT))))
	if #letters == 0 then
		fs[#fs + 1] = ("label[%.2f,2.15;%s]"):format(PANE_X, esc(colored(COLOR.dim,
			"Your mailbox is empty.")))
	elseif not selected then
		fs[#fs + 1] = ("label[%.2f,2.15;%s]"):format(PANE_X, esc(colored(COLOR.dim,
			"Choose a letter to read it.")))
	else
		reading_head(fs, selected, selected.kind)
		local dialog = session.dialog
		reading_body(fs, selected, 4.3)
		if dialog == "report" then
			report_dialog(fs, session, selected)
		else
			if M.has_items(selected) then
				fs[#fs + 1] = ("label[%.2f,7.8;Attachments]"):format(PANE_X)
				attachment_cells(fs, selected.items, PANE_X, 8.05)
				fs[#fs + 1] = ("button[%.2f,8.1;1.35,0.7;take_all;Take all]"):format(
					PANE_X + PANE_W - 1.35)
			end
			if dialog == "delete" then
				delete_dialog(fs, selected)
			else
				local x = PANE_X
				if M.reply_kind(selected) then
					fs[#fs + 1] = ("style[reply;bgcolor=#3d5f8a]button[%.2f,9.25;1.55,0.75;reply;Reply]")
						:format(x)
					x = x + 1.725
				else
					fs[#fs + 1] = ("label[%.2f,9.6;%s]"):format(x, esc(colored(COLOR.dim,
						"Letters from characters of the\nrealm cannot be answered.")))
				end
				if selected.kind == "player" then
					if selected.reported then
						fs[#fs + 1] = ("label[%.2f,9.6;%s]"):format(x + 0.2,
							esc(colored(COLOR.dim, "Reported")))
					else
						fs[#fs + 1] = ("button[%.2f,9.25;1.55,0.75;report;Report]"):format(x)
					end
				end
				fs[#fs + 1] = ("button[%.2f,9.25;1.55,0.75;delete_%d;Delete]"):format(
					PANE_X + PANE_W - 1.55, selected.id)
			end
		end
	end
	fs[#fs + 1] = status_line(session, 12.75)
	fs[#fs + 1] = ("label[0.4,13.25;%s]"):format(esc(colored(COLOR.dim,
		"Letters are deleted 30 days after they arrive, attachments too.")))
end

local function announcements_tab(player, session, fs)
	local broadcasts = S.broadcasts()
	local read = S.read_set(player)
	local list = {}
	for index, broadcast in ipairs(broadcasts) do
		list[index] = {id = broadcast.id, kind = "admin", from = M.ADMIN_LABEL,
			subject = broadcast.subject, body = broadcast.body, time = broadcast.time,
			read = read[broadcast.id] == true}
	end
	local selected = M.find(list, session.selected.announcements)
	local rows, page, pages = M.page(list, session.pages.announcements)
	session.pages.announcements = page
	session.rows = rows
	fs[#fs + 1] = ("label[%.2f,1.2;%s]"):format(LIST_X, esc(colored(COLOR.dim,
		"Letters from the admin to all players")))
	letter_table(fs, "announcements", rows, selected and selected.id, LIST_X, LIST_Y,
		LIST_W, LIST_H)
	fs[#fs + 1] = pager("announcements", LIST_X, 7.05, page, pages)
	if #list == 0 then
		fs[#fs + 1] = ("label[%.2f,2.15;%s]"):format(PANE_X, esc(colored(COLOR.dim,
			"No announcements.")))
	elseif not selected then
		fs[#fs + 1] = ("label[%.2f,2.15;%s]"):format(PANE_X, esc(colored(COLOR.dim,
			"Choose an announcement to read it.")))
	else
		reading_head(fs, selected, "admin")
		reading_body(fs, selected, 5.8)
		fs[#fs + 1] = ("style[reply;bgcolor=#3d5f8a]button[%.2f,9.25;1.55,0.75;reply;Reply]")
			:format(PANE_X)
	end
	fs[#fs + 1] = status_line(session, 12.75)
	fs[#fs + 1] = ("label[0.4,13.25;%s]"):format(esc(colored(COLOR.dim,
		"Announcements are deleted 30 days after they were sent.")))
end

--
-- Write
--

-- The two Send buttons carry the serial of the draw they belong to
-- ("write_send_<n>", "admin_send_<n>"): a click from a form the server has
-- already replaced (a quick second click after a sent letter) acts on
-- nothing (see the events).
local function send_button(session, prefix)
	return prefix .. "_" .. session.draw
end

-- The rings: shift-click from an attachment slot goes through the inbox to
-- the give order; from `main` and from each bag into the attachment slots.
-- The engine takes the entry after the FIRST one naming the source list
-- (guiFormSpecMenu.cpp getNextInventoryRing), so the attachment list follows
-- `main` at once and again after each bag (ui.lua bag_rings' pattern).
local function rings(player)
	local fs = {"listring[current_player;" .. ATTACH .. "]",
		"listring[current_player;" .. grug_inventory.INBOX_LIST .. "]",
		"listring[current_player;main]",
		"listring[current_player;" .. ATTACH .. "]"}
	local inv = player:get_inventory()
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		if inv:get_size(list) > 0 then
			fs[#fs + 1] = ("listring[current_player;%s]listring[current_player;%s]"):format(
				list, ATTACH)
		end
	end
	return table.concat(fs)
end

local function write_tab(player, session, fs)
	local draft = session.draft
	fs[#fs + 1] = ("label[0.4,1.375;To]field[1.3,1.05;4.2,0.65;mail_to;;%s]" ..
		"field_close_on_enter[mail_to;false]"):format(esc(draft.to))
	fs[#fs + 1] = ("label[5.8,1.375;Subject]field[7.0,1.05;6.1,0.65;mail_subject;;%s]" ..
		"field_close_on_enter[mail_subject;false]"):format(esc(draft.subject))
	fs[#fs + 1] = ("label[0.4,2.0;Message]textarea[0.4,2.25;12.7,3.0;mail_body;;%s]")
		:format(esc(draft.body))
	fs[#fs + 1] = "label[0.4,5.6;Attachments]"
	fs[#fs + 1] = ("list[current_player;%s;0.4,5.85;4,1;]"):format(ATTACH)
	-- The rule, not a figure (see the file comment).
	fs[#fs + 1] = ("label[5.6,6.1;%s]label[5.6,6.55;%s]"):format(
		esc("Postage: " .. grug_money.format(M.POSTAGE_LETTER) .. " per letter + " ..
			grug_money.format(M.POSTAGE_STACK) .. " per filled slot"),
		esc(colored(COLOR.dim, "Paid when you send.")))
	fs[#fs + 1] = ("label[0.4,7.2;%s]label[0.4,7.6;%s]"):format(esc(colored(COLOR.dim,
		"Drag up to four stacks in or out. Soulbound items and skills do not fit.")),
		esc(colored(COLOR.dim, "The letter arrives at once, also when the recipient is " ..
		"offline. Only players of your faction.")))
	fs[#fs + 1] = status_line(session, 8.4)
	fs[#fs + 1] = ("button[8.6,8.0;2.2,0.8;write_discard;Discard]" ..
		"style[%s;bgcolor=#3d5f8a]button[10.9,8.0;2.2,0.8;%s;Send]"):format(
		send_button(session, "write_send"), send_button(session, "write_send"))
	fs[#fs + 1] = grug_inventory.inventory_view(player, "short", session.inv)
	fs[#fs + 1] = rings(player)
end

--
-- To the admin
--

local ADMIN_HINT = "Questions, problems or a player to report? Feedback on " ..
	"the game and bug reports are very welcome too. Mail to the admin is free."

local function ticket_table(fs, rows, selected_id, x, y, w, h)
	fs[#fs + 1] = ("tableoptions[background=#0d0e10;border=true;highlight=#2c3a4f;" ..
		"color=%s]"):format(COLOR.text)
	fs[#fs + 1] = "tablecolumns[text,width=12;color;text,align=right,width=5]"
	local cells, selected = {}, 0
	for index, ticket in ipairs(rows) do
		local state = M.ticket_state(ticket)
		local color = state == "Open" and COLOR.open or state == "Answered" and
			COLOR.answered or COLOR.closed
		for _, entry in ipairs({clip(ticket.subject, 30), color, state}) do
			cells[#cells + 1] = esc(entry)
		end
		if ticket.id == selected_id then selected = index end
	end
	fs[#fs + 1] = ("table[%.2f,%.2f;%.2f,%.2f;tickets;%s;%d]"):format(x, y, w, h,
		table.concat(cells, ","), selected)
end

-- The right column of To the admin: the player's own messages.
local TICKET_X, TICKET_W = 7.0, 6.1

local function admin_tab(player, session, fs)
	local name = player:get_player_name()
	local draft = session.admin
	local tickets = S.tickets()
	local own = M.tickets_of(tickets, name)
	fs[#fs + 1] = ("image[0.4,1.1;0.55,0.55;%s]label[1.1,1.4;%s]"):format(BADGE,
		esc(colored(COLOR.gold, "Write to the server admin")))
	fs[#fs + 1] = ("label[0.4,2.0;%s]"):format(esc(colored(COLOR.dim,
		grug_inventory.wrap_text(ADMIN_HINT, 48))))
	local topics = {}
	for index, topic in ipairs(M.TOPICS) do topics[index] = esc(topic) end
	fs[#fs + 1] = ("label[0.4,3.6;Topic]dropdown[1.6,3.3;5.1,0.6;admin_topic;%s;%d;true]")
		:format(table.concat(topics, ","), draft.topic)
	fs[#fs + 1] = ("label[0.4,4.3;Subject]field[1.6,4.0;5.1,0.6;admin_subject;;%s]" ..
		"field_close_on_enter[admin_subject;false]"):format(esc(draft.subject))
	fs[#fs + 1] = ("label[0.4,4.95;Message]textarea[0.4,5.2;6.3,3.3;admin_body;;%s]")
		:format(esc(draft.body))
	fs[#fs + 1] = ("label[0.4,8.85;%s]"):format(esc(colored(COLOR.dim,
		"Sent from " .. mailbox_text(session) .. ",\nversion " ..
		tostring(grug_inventory.GAME_VERSION or "unknown") .. " is attached.\n" ..
		("You have %d of %d open messages."):format(M.open_tickets(tickets, name),
		M.OPEN_TICKETS))))
	fs[#fs + 1] = ("button[0.4,10.2;2.2,0.8;admin_discard;Discard]" ..
		"style[%s;bgcolor=#3d5f8a]button[4.5,10.2;2.2,0.8;%s;Send (free)]"):format(
		send_button(session, "admin_send"), send_button(session, "admin_send"))

	local selected = M.find(own, session.selected.tickets)
	local rows, page, pages = M.page(own, session.pages.tickets)
	session.pages.tickets = page
	session.rows = rows
	fs[#fs + 1] = ("label[%.2f,1.4;Your messages to the admin]"):format(TICKET_X)
	ticket_table(fs, rows, selected and selected.id, TICKET_X, 1.7, TICKET_W, 4.0)
	fs[#fs + 1] = pager("tickets", TICKET_X, 5.9, page, pages)
	if #own == 0 then
		fs[#fs + 1] = ("label[%.2f,7.0;%s]"):format(TICKET_X, esc(colored(COLOR.dim,
			"You have not written to the admin.")))
	elseif selected then
		fs[#fs + 1] = ("label[%.2f,7.0;%s]label[%.2f,7.45;%s]"):format(TICKET_X,
			esc(clip(selected.subject, 44)), TICKET_X, esc(colored(COLOR.dim,
			"You, " .. date(selected.time) .. " · " .. selected.topic .. " · ") ..
			M.ticket_state(selected)))
		local text = selected.body
		if selected.report then
			local report = selected.report
			text = ("Reason: %s\n%s\n\nThe reported letter from %s, %s:\n%s\n%s"):format(
				report.reason, report.note ~= "" and ("Note: " .. report.note) or "",
				tostring(report.from), date(report.time), tostring(report.subject),
				tostring(report.body))
		end
		fs[#fs + 1] = ("box[%.2f,7.75;%.2f,2.6;#0d0e10]textarea[%.2f,7.75;%.2f,2.6;;;%s]")
			:format(TICKET_X, TICKET_W, TICKET_X, TICKET_W, esc(text))
		if selected.answered then
			fs[#fs + 1] = ("label[%.2f,10.65;%s]"):format(TICKET_X, esc(colored(COLOR.dim,
				"The answer is in your Letters.")))
		end
		fs[#fs + 1] = ("button[%.2f,11.0;1.9,0.8;ticket_delete_%d;Delete]"):format(
			TICKET_X + TICKET_W - 1.9, selected.id)
	end
	fs[#fs + 1] = status_line(session, 12.75)
	fs[#fs + 1] = ("label[0.4,13.25;%s]"):format(esc(colored(COLOR.dim,
		"Deleting removes a message for good. Messages are deleted after 30 days.")))
end

--
-- Show
--

local TAB_BUILDERS = {letters = letters_tab, announcements = announcements_tab,
	write = write_tab, admin = admin_tab}

local function counts_of(player)
	local name = player:get_player_name()
	local box = S.box(name)
	local letters = 0
	for _, letter in ipairs(box.letters) do if not letter.read then letters = letters + 1 end end
	return {letters = letters, announcements = M.unread_broadcasts(S.broadcasts(),
		S.read_set(player), S.now())}
end

function grug_mail.window_formspec(player, session)
	local fs = {frame(player, session, counts_of(player))}
	TAB_BUILDERS[session.tab](player, session, fs)
	return table.concat(fs)
end

local function show(player, session)
	session.draw = session.draw + 1
	core.show_formspec(player:get_player_name(), session.formname,
		grug_mail.window_formspec(player, session))
end

local function finish(player, session)
	sessions[player:get_player_name()] = nil
	if grug_mail.return_attachments(player) > 0 then
		grug_core.feed(player, "notice", "No room for every attachment: the rest " ..
			"waits in the attachment slots of the next mailbox.", "mail_attach")
	end
end

-- Opens the window for the mailbox at `pos` (the node's right-click). The
-- mailbox-open callbacks run first (lane QUEST's turn-in may pay copper the
-- window then shows).
function grug_mail.open_mailbox(player, pos)
	if not pos or not at_mailbox(player, pos) then return false end
	grug_mail.run_open_callbacks(player, pos)
	if not player:is_player() then return false end
	local session = new_session(pos)
	sessions[player:get_player_name()] = session
	show(player, session)
	return true
end

-- The session of a player (fixtures, lane ADMIN's preview), or nil.
function grug_mail.session(name)
	return sessions[name]
end

-- A change of the unread count refreshes nothing on its own: the window
-- shows it at its next event (a resend would drop typed text).

--
-- Events
--

local function keep_drafts(session, fields)
	local function take(target, key, field, max)
		if fields[field] ~= nil then target[key] = M.truncate(fields[field], max) end
	end
	take(session.draft, "to", "mail_to", 40)
	take(session.draft, "subject", "mail_subject", M.SUBJECT_MAX)
	take(session.draft, "body", "mail_body", M.BODY_MAX)
	take(session.admin, "subject", "admin_subject", M.SUBJECT_MAX)
	take(session.admin, "body", "admin_body", M.BODY_MAX)
	take(session.report, "note", "report_note", M.NOTE_MAX)
	local topic = tonumber(fields.admin_topic)
	if topic and M.TOPICS[topic] then session.admin.topic = topic end
	local reason = tonumber(fields.report_reason)
	if reason and M.REPORT_REASONS[reason] then session.report.reason = reason end
end

local function say(session, ok, message)
	session.status, session.status_ok = message, ok
end

-- The selected entry of a list tab (a fresh copy from storage).
local function selected_letter(player, session)
	return M.find(S.box(player:get_player_name()).letters, session.selected.letters)
end

local function start_reply(player, session, entry, broadcast)
	if broadcast or entry.kind == "admin" then
		session.tab = "admin"
		session.admin.subject = M.reply_subject(entry.subject)
		session.admin.topic = 3 -- Question
		return
	end
	session.tab = "write"
	session.draft = {to = entry.from, subject = M.reply_subject(entry.subject),
		body = M.quote(entry.body)}
end

local function page_turn(session, fields, prefix, key)
	if fields[prefix .. "_prev"] then
		session.pages[key] = session.pages[key] - 1
		return true
	elseif fields[prefix .. "_next"] then
		session.pages[key] = session.pages[key] + 1
		return true
	end
	return false
end

local function letters_event(player, session, fields)
	if page_turn(session, fields, "letters", "letters") then return end
	local letter = selected_letter(player, session)
	if letter and fields.reply then
		start_reply(player, session, letter, false)
	elseif letter and fields.report then
		session.dialog = "report"
		session.report = {reason = 1, note = ""}
	elseif fields.report_cancel or fields.delete_cancel then
		session.dialog = nil
	elseif letter and fields["report_confirm_" .. letter.id] and session.dialog == "report" then
		local ok, message = grug_mail.report_letter(player, letter.id,
			M.REPORT_REASONS[session.report.reason], session.report.note, mailbox_text(session))
		say(session, ok, message)
		if ok then session.dialog = nil end
	elseif letter and fields.take_all then
		say(session, grug_mail.take_all(player, letter.id))
	elseif letter and fields["delete_" .. letter.id] then
		if M.has_items(letter) then
			session.dialog = "delete"
		else
			say(session, grug_mail.delete_letter(player, letter.id))
			session.selected.letters = nil
		end
	elseif letter and fields["delete_confirm_" .. letter.id] and session.dialog == "delete" then
		say(session, grug_mail.delete_letter(player, letter.id))
		session.selected.letters, session.dialog = nil, nil
	else
		local row = table_row(fields.letters)
		local entry = row and session.rows and session.rows[row]
		if entry then
			session.selected.letters, session.dialog = entry.id, nil
			grug_mail.open_letter(player, entry.id)
		end
	end
end

local function announcements_event(player, session, fields)
	if page_turn(session, fields, "announcements", "announcements") then return end
	local broadcast = M.find(S.broadcasts(), session.selected.announcements)
	if broadcast and fields.reply then
		start_reply(player, session, broadcast, true)
		return
	end
	local row = table_row(fields.announcements)
	local entry = row and session.rows and session.rows[row]
	if entry then
		session.selected.announcements = entry.id
		grug_mail.read_broadcast(player, entry.id)
	end
end

local function write_event(player, session, fields)
	if fields.write_discard then
		session.draft = {to = "", subject = "", body = ""}
		grug_mail.return_attachments(player)
		say(session, true, "Letter discarded.")
	elseif fields[send_button(session, "write_send")] then
		local draft = session.draft
		local ok, message = grug_mail.send_letter(player, draft.to, draft.subject,
			draft.body)
		say(session, ok, message)
		if ok then
			session.draft = {to = "", subject = "", body = ""}
			grug_core.feed(player, "notice", message, "mail")
		end
	end
end

local function admin_event(player, session, fields)
	if page_turn(session, fields, "tickets", "tickets") then return end
	local name = player:get_player_name()
	if fields.admin_discard then
		session.admin = {topic = 1, subject = "", body = ""}
		say(session, true, "Message discarded.")
	elseif fields[send_button(session, "admin_send")] then
		local draft = session.admin
		local ok, message = grug_mail.send_ticket(player, M.TOPICS[draft.topic],
			draft.subject, draft.body, mailbox_text(session))
		say(session, ok, message)
		if ok then session.admin = {topic = 1, subject = "", body = ""} end
	elseif session.selected.tickets and fields["ticket_delete_" .. session.selected.tickets] then
		local ticket = grug_mail.ticket(session.selected.tickets)
		if ticket and ticket.from == name then
			say(session, grug_mail.delete_ticket(ticket.id, name))
		end
		session.selected.tickets = nil
	else
		local row = table_row(fields.tickets)
		local entry = row and session.rows and session.rows[row]
		if entry then session.selected.tickets = entry.id end
	end
end

local TAB_EVENTS = {letters = letters_event, announcements = announcements_event,
	write = write_event, admin = admin_event}

-- The short inventory view's scrollbar (grug_inventory ui.lua): the value
-- of every event is kept; a pure scroll event ends here without a resend.
local function scrolled(session, fields)
	local raw = fields[grug_inventory.SCROLL_FIELDS.short]
	local kind, value
	if type(raw) == "string" then kind, value = raw:match("^(%u+):(%-?%d+)$") end
	if kind == "CHG" or kind == "VAL" then
		session.inv.grug_inv_scroll = {short = math.max(0, tonumber(value))}
	end
	return kind == "CHG"
end

-- The buttons, tables and tabs: the fields that ask for an action.
local ACTIONS = {reply = true, report = true, report_cancel = true,
	take_all = true, delete_cancel = true, write_discard = true, admin_discard = true,
	letters = true,
	announcements = true, tickets = true, grug_mail_tab = true}

-- Whether the event asks for nothing (an Enter in a single-line field):
-- no resend, so the field keeps its focus.
local function idle(fields)
	if not fields.key_enter_field then return false end
	for field in pairs(fields) do
		if ACTIONS[field] or field:match("_prev$") or field:match("_next$") or
				field:match("_send_%d+$") or field:match("^delete_%d+$") or
				field:match("_confirm_%d+$") or field:match("^ticket_delete_%d+$") then
			return false
		end
	end
	return true
end

-- A Send from an older draw than the one shown last: no action and none of
-- its fields kept (they are the text the first click already sent).
local function stale(session, fields)
	for field in pairs(fields) do
		local serial = field:match("^write_send_(%d+)$") or field:match("^admin_send_(%d+)$")
		if serial and tonumber(serial) ~= session.draw then return true end
	end
	return false
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #FORM_PREFIX) ~= FORM_PREFIX then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session or session.formname ~= formname then return true end
	if fields.quit then
		finish(player, session)
		return true
	end
	if not at_mailbox(player, session.pos) then
		finish(player, session)
		core.close_formspec(name, formname)
		return true
	end
	if stale(session, fields) then
		show(player, session)
		return true
	end
	keep_drafts(session, fields)
	if scrolled(session, fields) or idle(fields) then return true end
	session.status = nil
	local tab = tonumber(fields.grug_mail_tab)
	if tab and TABS[tab] and TABS[tab] ~= session.tab then
		session.tab, session.dialog = TABS[tab], nil
	else
		TAB_EVENTS[session.tab](player, session, fields)
	end
	if sessions[name] == session then show(player, session) end
	return true
end)

local function clear(player)
	sessions[player:get_player_name()] = nil
end
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(function(player)
	local session = sessions[player:get_player_name()]
	if session then
		finish(player, session)
		core.close_formspec(player:get_player_name(), session.formname)
	end
end)
