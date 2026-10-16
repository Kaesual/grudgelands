-- The pure mail model (Round 48 lane MAIL, docs/design/mail.md; spec
-- docs/planning/mail-plan.md §2-§3): letters, tickets, broadcasts, the
-- limits, expiry, pagination, postage, the unread count and the report
-- rules. No engine calls: the caller passes the time (`now`, os.time()
-- seconds) and stores the tables (store.lua). The portable fixture
-- tools/r48_mail/portable_test.lua tests this file.
--
-- A mailbox is {letters = {letter, ...}}, newest first. A letter:
--   {id, kind = "player"|"admin"|"npc", from, subject, body, time,
--    read = bool, items = {ItemStack strings}, reported = bool}
-- A ticket (a message to the admin):
--   {id, from, topic, subject, body, time, state = "open"|"closed",
--    answered = bool, closed_by, closed_at, mailbox, version, level,
--    faction, race, class, pos = {x, y, z},
--    report = {letter_id, from, time, subject, body, items, reason, note}}
-- A broadcast: {id, subject, body, time, by}.

local M = {}

M.LETTER_LIMIT = 50       -- player letters per mailbox (ruling 7)
M.OPEN_TICKETS = 5        -- open messages to the admin per player
M.PAGE_SIZE = 8           -- rows per list page (§3.2)
M.SUBJECT_MAX = 60        -- characters (§3.3)
-- A message's text (letters, tickets, admin letters and answers, broadcasts):
-- a longer one is refused, not cut (fix 0.49.1 rulings 1 and 3); only the
-- letters written by code keep a cut at it as a safety net (send_system).
M.BODY_MAX = 4000
-- What the window keeps of a typed text (ruling 4): Luanti limits neither
-- textarea[] nor field[], only a whole submit (640 KB), so the drafts the
-- form is sent back with are cut here (at most about 40 KB).
M.DRAFT_MAX = 10000
M.QUOTE_MAX = 500         -- characters of the original in a reply (ruling 5)
M.NOTE_MAX = 200
M.STACKS = 4              -- attachment stacks per letter
M.EXPIRY = 30 * 24 * 3600 -- seconds a letter, ticket or broadcast is kept
M.POSTAGE_LETTER = 5      -- copper per letter (ruling 2)
M.POSTAGE_STACK = 30      -- copper per attached stack
M.ADMIN_LABEL = "Server Admin"
M.KINDS = {player = true, admin = true, npc = true}
M.TOPICS = {"Feedback", "Bug report", "Question", "Player report", "Other"}
M.REPORT_TOPIC = "Player report"
M.REPORT_REASONS = {"Spam", "Insult or harassment", "Scam", "Other"}

-- Postage for a letter with `stacks` attachments: 5c, 35c, ... 125c.
function M.postage(stacks)
	return M.POSTAGE_LETTER + M.POSTAGE_STACK * (stacks or 0)
end

--
-- Text
--

-- One UTF-8 character: a lead byte and its continuation bytes.
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

function M.text_length(text)
	local count = 0
	for _ in tostring(text or ""):gmatch(CHAR) do count = count + 1 end
	return count
end

-- The first `max` characters of `text`, never a cut character. Valid UTF-8
-- has at most four bytes a character, so only the first 4 x `max` bytes are
-- read: a huge or malformed input (a modified client) is never walked whole.
function M.truncate(text, max)
	text = tostring(text or ""):sub(1, 4 * max)
	local count, last = 0, 0
	for from, char in text:gmatch("()(" .. CHAR .. ")") do
		count = count + 1
		if count > max then return text:sub(1, last) end
		last = from + #char - 1
	end
	return text:sub(1, last)
end

-- Player text as stored: control characters (the client's colour escapes
-- among them) and stray bytes removed, line ends kept only where `multiline`,
-- outer blanks trimmed, at most `max` characters (no cut without `max`).
function M.clean(text, max, multiline)
	text = tostring(text or ""):gsub("\r\n?", "\n")
	local kept = {}
	for char in text:gmatch(CHAR) do
		if char == "\n" then
			kept[#kept + 1] = multiline and "\n" or " "
		elseif char == "\t" then
			kept[#kept + 1] = " "
		elseif not (#char == 1 and (char:byte() < 32 or char:byte() == 127)) then
			kept[#kept + 1] = char
		end
	end
	text = table.concat(kept):match("^%s*(.-)%s*$")
	if not max then return text end
	return M.truncate(text, max)
end

-- 5723 -> "5,723".
function M.thousands(number)
	local text, changed = tostring(math.floor(number)), 1
	while changed > 0 do text, changed = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2") end
	return text
end

-- A message body as it is stored (cleaned, never cut), or nil and the
-- refusal when it is longer than M.BODY_MAX (ruling 3). The length counts
-- what is stored: characters after cleaning.
function M.check_body(body)
	local text = M.clean(body, nil, true)
	local length = M.text_length(text)
	if length > M.BODY_MAX then
		return nil, ("Too long, please shorten it (%s characters, %s allowed)."):format(
			M.thousands(length), M.thousands(M.BODY_MAX))
	end
	return text
end

-- "Re: <subject>", never "Re: Re: ...", within the subject limit.
function M.reply_subject(subject)
	local bare, stripped = tostring(subject or ""), 1
	while stripped > 0 do bare, stripped = bare:gsub("^%s*[Rr][Ee]:%s*", "") end
	return M.truncate("Re: " .. bare, M.SUBJECT_MAX)
end

-- The quoted text of a reply: every line of `body` behind "> ", after two
-- empty lines for the answer. At most M.QUOTE_MAX characters of the original
-- are quoted; a cut one ends in " [...]" (ruling 5). So a quote stays far
-- below the body limit (about 1,500 characters even with a line each).
function M.quote(body)
	body = tostring(body or "")
	if M.text_length(body) > M.QUOTE_MAX then
		body = M.truncate(body, M.QUOTE_MAX):match("^(.-)%s*$") .. " [...]"
	end
	local lines = {}
	for line in (body .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = "> " .. line
	end
	return "\n\n" .. table.concat(lines, "\n")
end

--
-- Lists: expiry, lookup, pages
--

function M.expired(entry, now)
	return type(entry.time) ~= "number" or now - entry.time >= M.EXPIRY
end

-- Removes the entries of `list` that are 30 days old or older (attachments
-- go with their letter). Returns how many went.
function M.prune(list, now)
	local removed = 0
	for index = #list, 1, -1 do
		if M.expired(list[index], now) then
			table.remove(list, index)
			removed = removed + 1
		end
	end
	return removed
end

function M.find(list, id)
	for index, entry in ipairs(list) do
		if entry.id == id then return entry, index end
	end
	return nil
end

function M.remove(list, id)
	local _, index = M.find(list, id)
	if not index then return nil end
	return table.remove(list, index)
end

-- One page of `list` (page numbers from 1, clamped): the rows, the page
-- shown and the number of pages (at least 1).
function M.page(list, page, size)
	size = size or M.PAGE_SIZE
	local pages = math.max(1, math.ceil(#list / size))
	page = math.max(1, math.min(pages, math.floor(tonumber(page) or 1)))
	local rows = {}
	for index = (page - 1) * size + 1, math.min(#list, page * size) do
		rows[#rows + 1] = list[index]
	end
	return rows, page, pages
end

-- The page that holds the entry `id` (1 when it is not in the list).
function M.page_of(list, id, size)
	local _, index = M.find(list, id)
	if not index then return 1 end
	return math.ceil(index / (size or M.PAGE_SIZE))
end

--
-- Mailboxes and letters
--

function M.new_box()
	return {letters = {}}
end

function M.player_letters(box)
	local count = 0
	for _, letter in ipairs(box.letters) do
		if letter.kind == "player" then count = count + 1 end
	end
	return count
end

-- Player mail stops at 50 player letters; admin and system letters always
-- arrive (ruling 7).
function M.accepts(box, kind)
	return kind ~= "player" or M.player_letters(box) < M.LETTER_LIMIT
end

-- A new letter, newest first. `items` is a list of ItemStack strings.
function M.letter(id, kind, from, subject, body, items, now)
	local stored = {}
	for _, item in ipairs(items or {}) do
		if item ~= "" then stored[#stored + 1] = item end
	end
	return {id = id, kind = kind, from = from, subject = subject, body = body,
		time = now, read = false, items = stored, reported = false}
end

function M.deliver(box, letter)
	table.insert(box.letters, 1, letter)
	return letter
end

-- Opening a letter marks it read (ruling 12). True when it changed.
function M.mark_read(entry)
	if entry.read then return false end
	entry.read = true
	return true
end

function M.has_items(letter)
	return letter.items ~= nil and #letter.items > 0
end

-- Who shows as the sender: admin letters always read "Server Admin"
-- (ruling 3), whatever label they were sent with.
function M.sender_label(kind, from_label)
	if kind == "admin" then return M.ADMIN_LABEL end
	return from_label
end

-- Reply: a player letter is answered by a letter, an admin letter (and a
-- broadcast) by a new message to the admin; an NPC letter has none (§3.4).
function M.reply_kind(letter)
	if letter.kind == "player" then return "letter" end
	if letter.kind == "admin" then return "ticket" end
	return nil
end

-- Only a player letter can be reported, and only once (§3.7).
function M.can_report(letter)
	if letter.kind ~= "player" then
		return false, "Only letters from players can be reported."
	end
	if letter.reported then return false, "You already reported this letter." end
	return true
end

--
-- Broadcasts and the unread count
--

-- The broadcasts a player sees: every one that has not expired, also those
-- sent before the character existed (§3.11).
function M.unread_broadcasts(broadcasts, read_set, now)
	local count = 0
	for _, broadcast in ipairs(broadcasts) do
		if not M.expired(broadcast, now) and not read_set[broadcast.id] then
			count = count + 1
		end
	end
	return count
end

-- Unread letters plus unread broadcasts (§3.11).
function M.unread(box, broadcasts, read_set, now)
	local count = 0
	for _, letter in ipairs(box.letters) do
		if not letter.read and not M.expired(letter, now) then count = count + 1 end
	end
	return count + M.unread_broadcasts(broadcasts or {}, read_set or {}, now)
end

-- The read set kept to the broadcasts that still exist.
function M.trim_read_set(read_set, broadcasts)
	local kept = {}
	for _, broadcast in ipairs(broadcasts) do
		if read_set[broadcast.id] then kept[broadcast.id] = true end
	end
	return kept
end

--
-- Tickets
--

function M.open_tickets(tickets, name)
	local count = 0
	for _, ticket in ipairs(tickets) do
		if ticket.from == name and ticket.state == "open" then count = count + 1 end
	end
	return count
end

-- At most five open messages per player, reports included (§3.5).
function M.can_open_ticket(tickets, name)
	if M.open_tickets(tickets, name) >= M.OPEN_TICKETS then
		return false, ("You have %d open messages to the admin. Wait for an " ..
			"answer or delete one first."):format(M.OPEN_TICKETS)
	end
	return true
end

function M.valid_topic(topic)
	for _, known in ipairs(M.TOPICS) do
		if known == topic then return true end
	end
	return false
end

-- A new open ticket. `header` holds what the admin sees about the sender
-- (§3.15): mailbox, version, level, faction, race, class, pos.
function M.ticket(id, from, topic, subject, body, header, now)
	local ticket = {id = id, from = from, topic = topic, subject = subject,
		body = body, time = now, state = "open", answered = false}
	for key, value in pairs(header or {}) do
		if ticket[key] == nil then ticket[key] = value end
	end
	return ticket
end

-- The report of a player letter: a "Player report" ticket holding a frozen
-- copy of the letter (sender, time, text, the attachments' names; §3.7).
-- `item_names` are the attachments as the reporter saw them.
function M.report_ticket(id, reporter, letter, reason, note, item_names, header, now)
	local ticket = M.ticket(id, reporter, M.REPORT_TOPIC,
		M.truncate("Report: letter from " .. tostring(letter.from), M.SUBJECT_MAX),
		note or "", header, now)
	local names = {}
	for _, name in ipairs(item_names or {}) do names[#names + 1] = name end
	ticket.report = {letter_id = letter.id, from = letter.from, time = letter.time,
		subject = letter.subject, body = letter.body, items = names,
		reason = reason, note = note or ""}
	return ticket
end

-- Closing (ruling 11): with an answer or without. Closing a closed ticket
-- changes nothing and answers false.
function M.close(ticket, admin_name, answered, now)
	if ticket.state ~= "open" then return false end
	ticket.state = "closed"
	ticket.answered = answered and true or false
	ticket.closed_by = admin_name
	ticket.closed_at = now
	return true
end

-- What the player sees: "Open", "Answered" or "Closed".
function M.ticket_state(ticket)
	if ticket.state == "open" then return "Open" end
	return ticket.answered and "Answered" or "Closed"
end

-- The player's own tickets, newest first (the list keeps arrival order).
function M.tickets_of(tickets, name)
	local own = {}
	for _, ticket in ipairs(tickets) do
		if ticket.from == name then own[#own + 1] = ticket end
	end
	return own
end

return M
