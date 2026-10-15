-- The mail API (mail plan §4.1, round plan §3.1-§3.5, §3.9): player
-- letters with postage and attachments, system letters, the mailbox-open
-- hook, the unread count, the ticket and broadcast stores. The names are the
-- contract the lanes ADMIN, QUEST and BAGS build on (docs/design/mail.md,
-- module guide "Mail").

local M, S = grug_mail.model, grug_mail.store

-- The attachment list: four slots of the player's own inventory, sized at
-- join. Not a carried list (grug_inventory.carried_lists stays `main` plus
-- the bags), so selling, crafting, the sort and migrations never touch it.
-- The existing guards keep soulbound items (grug_housing/soulbound.lua: only
-- `main` and the bags), skills (grug_skills/bound_items.lua: only the hotbar)
-- and mount items (only `main` and the bags) out of it.
grug_mail.ATTACH_LIST = "grug_mail_out"
local ATTACH = grug_mail.ATTACH_LIST

local function is_player(player)
	return player ~= nil and player.is_player ~= nil and player:is_player()
end

-- One log line, never spanning lines.
local function log(text)
	core.log("action", "[grug_mail] " .. tostring(text):gsub("\n", " / "))
end

--
-- The unread count and its HUD icon
--

-- Unread letters plus unread broadcasts (§3.11). Broadcasts count only for
-- an online player: their read set is player meta.
function grug_mail.unread_count(name)
	local box = S.box(name)
	local player = core.get_player_by_name(name)
	if not player then return M.unread(box, {}, {}, S.now()) end
	return M.unread(box, S.broadcasts(), S.read_set(player), S.now())
end

local count_callbacks = {}

-- func(name, count): after every unread change of an online player (the
-- open mailbox window refreshes its tab captions here).
function grug_mail.register_on_count(func)
	count_callbacks[#count_callbacks + 1] = func
end

-- Recomputes an online player's count and hands it to the minimap's mail
-- icon (lane HUD's grug_map.minimap.set_mail_count, looked up at call time:
-- it may merge after this mod).
function grug_mail.refresh_count(name)
	if not core.get_player_by_name(name) then return end
	local count = grug_mail.unread_count(name)
	local minimap = rawget(_G, "grug_map") and grug_map.minimap
	if minimap and type(minimap.set_mail_count) == "function" then
		minimap.set_mail_count(name, count)
	end
	for _, func in ipairs(count_callbacks) do func(name, count) end
	return count
end

--
-- Delivery
--

local function notice(name, from)
	local player = core.get_player_by_name(name)
	if not player then return end
	grug_core.feed(player, "notice", "New letter from " .. from .. ".", "mail")
	grug_mail.refresh_count(name)
end

local function item_list(items)
	local names = {}
	for _, item in ipairs(items) do names[#names + 1] = ItemStack(item):to_string() end
	return #names > 0 and table.concat(names, ", ") or "none"
end

-- A typed recipient of player mail (§3.8): a created character of the
-- sender's faction, never the sender. Other faction and unknown names get
-- the same answer.
local function resolve_recipient(sender, typed)
	typed = M.clean(typed, 40, false)
	if typed == "" then return nil, "Write the name of the recipient." end
	local name, faction = S.lookup(typed)
	if not name or faction ~= grug_factions.get_faction(sender) then
		return nil, ("There is no player called %s in your faction."):format(typed)
	end
	if name == sender:get_player_name() then
		return nil, "You cannot write to yourself."
	end
	return name
end

-- Any character, for admin and system mail: the index first (any letter
-- case), then the server's own player records.
local function resolve_any(typed)
	typed = tostring(typed or "")
	local name = S.lookup(typed)
	if name then return name end
	if typed ~= "" and core.player_exists(typed) then return typed end
	return nil
end

-- The four attachment slots as they are now.
function grug_mail.attachments(player)
	local inv, stacks = player:get_inventory(), {}
	for index = 1, M.STACKS do stacks[index] = inv:get_stack(ATTACH, index) end
	return stacks
end

-- Player mail (rulings 2 and 7, §3.8-§3.9). Postage and the four
-- attachment slots leave in one grug_money.take_with_inventory transaction.
-- The postage counts the slots as they are at this call (Round 49 ruling 1:
-- no quote, the result names the amount paid). Returns ok, message.
function grug_mail.send_letter(player, to_name, subject, body)
	if not is_player(player) then return false, "Only a player can send letters." end
	local name = player:get_player_name()
	local recipient, refusal = resolve_recipient(player, to_name)
	if not recipient then return false, refusal end
	subject = M.clean(subject, M.SUBJECT_MAX, false)
	body = M.clean(body, M.BODY_MAX, true)
	if subject == "" then return false, "Write a subject." end
	local box = S.box(recipient)
	if not M.accepts(box, "player") then
		return false, recipient .. "'s mailbox is full."
	end
	local changes, items = {}, {}
	for index, stack in ipairs(grug_mail.attachments(player)) do
		changes[index] = {list = ATTACH, index = index, expected = stack,
			replacement = ItemStack("")}
		if not stack:is_empty() then items[#items + 1] = stack:to_string() end
	end
	local postage = M.postage(#items)
	if grug_money.get(player) < postage then
		return false, "The postage is " .. grug_money.format(postage) ..
			". You do not have enough money."
	end
	local ok, failure = grug_money.take_with_inventory(player, postage, changes)
	if not ok then return false, failure end
	-- Read again after the payment: a money callback might have written to
	-- this mailbox meanwhile, and the copy above would overwrite it.
	box = S.box(recipient)
	local letter = M.letter(S.next_id(), "player", name, subject, body, items, S.now())
	M.deliver(box, letter)
	S.save_box(recipient, box)
	log(("letter #%d from %s to %s, postage %dc, attachments: %s"):format(
		letter.id, name, recipient, postage, item_list(items)))
	notice(recipient, name)
	return true, ("Letter sent to %s. Postage paid: %s."):format(recipient,
		grug_money.format(postage))
end

-- Admin and system mail (round plan §3.2): kind "admin" (shown as "Server
-- Admin", ruling 3) or "npc" (`from_label`, e.g. "Riding Trainer"). Always
-- delivered: no limit, no faction, no postage. `stacks` (optional, up to
-- four ItemStack strings) is stored and taken like player attachments; only
-- the 0.48.0 bag migration passes it (admin letters carry no items, ruling
-- 5). Returns true and the new letter id, or false and a message; never nil
-- (the migration retries at the next join on anything that is not truthy).
function grug_mail.send_system(to_name, kind, from_label, subject, body, stacks)
	if kind ~= "admin" and kind ~= "npc" then
		return false, "Unknown letter kind: " .. tostring(kind)
	end
	local name = resolve_any(to_name)
	if not name then return false, ("There is no player called %s."):format(tostring(to_name)) end
	local items = {}
	for _, item in ipairs(stacks or {}) do
		local stack = ItemStack(item)
		if not stack:is_empty() then items[#items + 1] = stack:to_string() end
	end
	if #items > M.STACKS then
		return false, ("A letter holds at most %d stacks."):format(M.STACKS)
	end
	local from = M.sender_label(kind, from_label)
	if type(from) ~= "string" or from == "" then return false, "The letter has no sender." end
	local letter = M.letter(S.next_id(), kind, from,
		M.clean(subject, M.SUBJECT_MAX, false), M.clean(body, M.BODY_MAX, true),
		items, S.now())
	local box = S.box(name)
	M.deliver(box, letter)
	S.save_box(name, box)
	log(("%s letter #%d from %s to %s, attachments: %s"):format(kind, letter.id,
		from, name, item_list(items)))
	notice(name, from)
	return true, letter.id
end

--
-- Reading: open, take all, delete
--

-- Opening a letter marks it read (ruling 12). Returns the letter or nil.
function grug_mail.open_letter(player, id)
	local name = player:get_player_name()
	local box = S.box(name)
	local letter = M.find(box.letters, id)
	if letter and M.mark_read(letter) then
		S.save_box(name, box)
		grug_mail.refresh_count(name)
	end
	return letter
end

-- Every attachment or none (§3.9): without room the items stay in the letter.
function grug_mail.take_all(player, id)
	local name = player:get_player_name()
	local box = S.box(name)
	local letter = M.find(box.letters, id)
	if not letter then return false, "That letter is gone." end
	if not M.has_items(letter) then return false, "The letter holds no items." end
	if not grug_inventory.fits(player, letter.items) then
		return false, "Not enough room in your inventory. The items stay in the letter."
	end
	local items = letter.items
	letter.items = {}
	S.save_box(name, box)
	local left = {}
	for _, item in ipairs(items) do
		local leftover = grug_inventory.give(player, item)
		if not leftover:is_empty() then left[#left + 1] = leftover:to_string() end
	end
	-- The fit check makes this unreachable; never lose an item if it is not.
	if #left > 0 then
		box = S.box(name)
		letter = M.find(box.letters, id)
		if letter then
			letter.items = left
			S.save_box(name, box)
		else
			for _, item in ipairs(left) do core.add_item(player:get_pos(), item) end
		end
	end
	log(("%s took the attachments of letter #%d: %s"):format(name, id, item_list(items)))
	return true, "You took the attachments."
end

-- Deleting removes the letter and what it still holds (the window asks
-- first when it holds items).
function grug_mail.delete_letter(player, id)
	local name = player:get_player_name()
	local box = S.box(name)
	local letter = M.remove(box.letters, id)
	if not letter then return false, "That letter is gone." end
	S.save_box(name, box)
	if M.has_items(letter) then
		log(("%s deleted letter #%d with its attachments: %s"):format(name, id,
			item_list(letter.items)))
	end
	grug_mail.refresh_count(name)
	return true, "Letter deleted."
end

-- Closing the window without sending (§3.9): each attachment slot goes back
-- through the give order; what does not fit stays in the slot and shows at
-- the next mailbox.
function grug_mail.return_attachments(player)
	local inv = player:get_inventory()
	local kept = 0
	for index = 1, inv:get_size(ATTACH) do
		local stack = inv:get_stack(ATTACH, index)
		if not stack:is_empty() then
			local leftover = grug_inventory.give(player, stack)
			inv:set_stack(ATTACH, index, leftover)
			if not leftover:is_empty() then kept = kept + 1 end
		end
	end
	return kept
end

--
-- Broadcasts ("All players", ruling 6): stored once, read per player.
--

function grug_mail.broadcasts()
	return S.broadcasts()
end

-- Stores a broadcast; every online player's count updates. Returns its id.
function grug_mail.send_broadcast(subject, body, admin_name)
	local broadcasts = S.broadcasts()
	local broadcast = {id = S.next_id(), subject = M.clean(subject, M.SUBJECT_MAX, false),
		body = M.clean(body, M.BODY_MAX, true), time = S.now(), by = admin_name}
	table.insert(broadcasts, 1, broadcast)
	S.save_broadcasts(broadcasts)
	log(("broadcast #%d by %s: %s: %s"):format(broadcast.id, tostring(admin_name),
		broadcast.subject, broadcast.body))
	for _, player in ipairs(core.get_connected_players()) do
		grug_mail.refresh_count(player:get_player_name())
	end
	return broadcast.id
end

function grug_mail.delete_broadcast(id, admin_name)
	local broadcasts = S.broadcasts()
	local broadcast = M.remove(broadcasts, id)
	if not broadcast then return false, "That announcement is gone." end
	S.save_broadcasts(broadcasts)
	log(("broadcast #%d deleted by %s"):format(id, tostring(admin_name)))
	for _, player in ipairs(core.get_connected_players()) do
		grug_mail.refresh_count(player:get_player_name())
	end
	return true
end

-- Opening a broadcast marks it read for this player only.
function grug_mail.read_broadcast(player, id)
	local broadcasts = S.broadcasts()
	if not M.find(broadcasts, id) then return nil end
	local set = S.read_set(player)
	if not set[id] then
		set[id] = true
		S.save_read_set(player, set, broadcasts)
		grug_mail.refresh_count(player:get_player_name())
	end
	return M.find(broadcasts, id)
end

--
-- Tickets: messages to the admin (rulings 4, 10, 11; §3.5-§3.7, §3.15)
--

-- What the admin sees about the sender, frozen at sending.
local function header(player, mailbox)
	local pos = player:get_pos()
	return {mailbox = mailbox, version = grug_inventory.GAME_VERSION,
		level = grug_xp.get_level(player), faction = grug_factions.get_faction(player),
		race = grug_classes.get_race(player), class = grug_classes.get_class(player),
		pos = pos and {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
			z = math.floor(pos.z + 0.5)} or nil}
end

local function log_ticket(ticket)
	local report = ticket.report
	log(("ticket #%d from %s (%s) at %s, version %s: %s: %s%s"):format(ticket.id,
		ticket.from, ticket.topic, tostring(ticket.mailbox), tostring(ticket.version),
		ticket.subject, ticket.body, report and (" | reported letter #%d from %s (%s): %s: %s; attachments: %s"):format(
			report.letter_id, tostring(report.from), tostring(report.reason),
			tostring(report.subject), tostring(report.body),
			#report.items > 0 and table.concat(report.items, ", ") or "none") or ""))
end

-- A new message to the admin; free, no items. `mailbox` is the label of the
-- mailbox it was sent from. Returns ok, message.
function grug_mail.send_ticket(player, topic, subject, body, mailbox)
	if not is_player(player) then return false, "Only a player can write to the admin." end
	if not M.valid_topic(topic) then return false, "Choose a topic." end
	subject = M.clean(subject, M.SUBJECT_MAX, false)
	body = M.clean(body, M.BODY_MAX, true)
	if subject == "" then return false, "Write a subject." end
	local name = player:get_player_name()
	local tickets = S.tickets()
	local ok, refusal = M.can_open_ticket(tickets, name)
	if not ok then return false, refusal end
	local ticket = M.ticket(S.next_id(), name, topic, subject, body,
		header(player, mailbox), S.now())
	table.insert(tickets, 1, ticket)
	S.save_tickets(tickets)
	log_ticket(ticket)
	return true, "Your message went to the admin.", ticket.id
end

-- Reports a received player letter (§3.7): a "Player report" ticket with a
-- frozen copy of it; once per letter. Returns ok, message.
function grug_mail.report_letter(player, id, reason, note, mailbox)
	local name = player:get_player_name()
	local box = S.box(name)
	local letter = M.find(box.letters, id)
	if not letter then return false, "That letter is gone." end
	local ok, refusal = M.can_report(letter)
	if not ok then return false, refusal end
	local known = false
	for _, entry in ipairs(M.REPORT_REASONS) do known = known or entry == reason end
	if not known then return false, "Choose a reason." end
	local tickets = S.tickets()
	ok, refusal = M.can_open_ticket(tickets, name)
	if not ok then return false, refusal end
	local names = {}
	for _, item in ipairs(letter.items or {}) do
		local stack = ItemStack(item)
		names[#names + 1] = (stack:get_short_description() or stack:get_name()) ..
			(stack:get_count() > 1 and (" x" .. stack:get_count()) or "")
	end
	local ticket = M.report_ticket(S.next_id(), name, letter, reason,
		M.clean(note, M.NOTE_MAX, false), names, header(player, mailbox), S.now())
	letter.reported = true
	S.save_box(name, box)
	table.insert(tickets, 1, ticket)
	S.save_tickets(tickets)
	log_ticket(ticket)
	return true, "The letter was reported to the admin."
end

-- The admin inbox, newest first (fresh tables; writing to them stores
-- nothing).
function grug_mail.tickets()
	return S.tickets()
end

function grug_mail.ticket(id)
	return (M.find(S.tickets(), id))
end

-- Closes a ticket (ruling 11), with an answer (`answered`) or without.
-- `admin_name` is logged and shown as "Closed by" in the Admin Mail tab only.
function grug_mail.close_ticket(id, admin_name, answered)
	local tickets = S.tickets()
	local ticket = M.find(tickets, id)
	if not ticket then return false, "That message is gone." end
	if not M.close(ticket, admin_name, answered, S.now()) then
		return false, "That message is already closed."
	end
	S.save_tickets(tickets)
	log(("ticket #%d %s by %s"):format(id, answered and "answered" or "closed",
		tostring(admin_name)))
	return true
end

-- An answer: an admin letter "Re: <subject>" to the sender, then the ticket
-- closes as answered. Returns ok, message.
function grug_mail.answer_ticket(id, admin_name, body)
	local ticket = grug_mail.ticket(id)
	if not ticket then return false, "That message is gone." end
	if ticket.state ~= "open" then return false, "That message is already closed." end
	local ok, failure = grug_mail.send_system(ticket.from, "admin", M.ADMIN_LABEL,
		M.reply_subject(ticket.subject), body)
	if not ok then return false, failure end
	log(("answer to ticket #%d by %s: %s"):format(id, tostring(admin_name),
		M.clean(body, M.BODY_MAX, true)))
	return grug_mail.close_ticket(id, admin_name, true)
end

-- Deleting removes the ticket for everyone (ruling 10); the server log
-- keeps it. `by_name` is logged (the window lets a player delete only their
-- own).
function grug_mail.delete_ticket(id, by_name)
	local tickets = S.tickets()
	local ticket = M.remove(tickets, id)
	if not ticket then return false, "That message is gone." end
	S.save_tickets(tickets)
	log(("ticket #%d deleted by %s"):format(id, tostring(by_name)))
	return true, "Message deleted."
end

--
-- The mailbox-open hook (round plan §3.3)
--

local open_callbacks = {}

-- func(player, pos): every time a player opens a mailbox, before the
-- window is drawn (lane QUEST turns the starter quest in here).
function grug_mail.register_on_mailbox_open(func)
	assert(type(func) == "function", "grug_mail.register_on_mailbox_open: not a function")
	open_callbacks[#open_callbacks + 1] = func
end

function grug_mail.run_open_callbacks(player, pos)
	for _, func in ipairs(open_callbacks) do func(player, pos) end
end

--
-- Join and faction choice
--

grug_factions.register_on_faction_chosen(function(player, faction)
	S.index_player(player:get_player_name(), faction)
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local inv = player:get_inventory()
	inv:set_size(ATTACH, M.STACKS)
	-- Stacks left in the slots by a disconnect go back (what fits).
	grug_mail.return_attachments(player)
	S.index_player(name, grug_factions.get_faction(player))
	S.save_read_set(player, S.read_set(player), S.broadcasts())
	grug_mail.refresh_count(name)
end)
