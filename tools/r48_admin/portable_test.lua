-- Round 48 lane ADMIN portable test (LuaJIT; mail plan §6 "ADMIN", §4.2,
-- defaults §3.6, §3.14, §3.15): the Admin Mail tab of grug_mail/admin.lua
-- under an engine stub, with the REAL sfinv (mods/BASE/sfinv/api.lua), the
-- REAL inventory frame and tab order (grug_inventory/ui.lua) and the REAL
-- grug_mail (model, store, API, window):
--   P. the privilege gates the tab: registered for admins, the tab in the
--      navigation only with it and after Help, granting and revoking redraw
--      the inventory window and a revoke leaves the page; the privilege
--      callbacks return nothing;
--   H. the inbox: filters Open / All, the header (sender, level, faction,
--      race and class, position, the mailbox, the game version, date), a
--      Player report's frozen copy;
--   A. Send answer delivers an admin letter "Re: <subject>" from Server Admin
--      and closes the ticket ("Closed by" the admin, only in the tab); Close
--      closes without a letter; Delete removes it for everyone; a double
--      click acts once; the admin's real name is logged;
--   C. a new admin letter to one player (text only, Server Admin) and to All
--      players: a broadcast stored once and read per player, also by a
--      character created later; the preview; deleting an announcement;
--   N. a non-admin's form submission to the admin page changes nothing.
--
--   luajit tools/r48_admin/portable_test.lua [REPO]
-- Prints "R48 ADMIN PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil, label ..
		" (missing " .. part .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil, label ..
		" (found " .. part .. ")")
end

------------------------------------------------------------------------------
-- Engine stub
------------------------------------------------------------------------------
local DAY = 24 * 3600
local clock = 1800000000
os.time = function() return clock end

local callbacks = {join = {}, leave = {}, die = {}, fields = {}, mods_loaded = {},
	grant = {}, revoke = {}}
local logs, privileges, privs = {}, {}, {}
local players = {}

local function serialize(value)
	local kind = type(value)
	if kind == "string" then return string.format("%q", value) end
	if kind == "number" or kind == "boolean" or kind == "nil" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if type(a) == type(b) then return a < b end
		return type(a) == "number"
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local mod_storage, storage_writes = {}, {}
local Storage = {}
Storage.__index = Storage
function Storage:get_string(key) return mod_storage[key] or "" end
function Storage:set_string(key, value)
	storage_writes[key] = (storage_writes[key] or 0) + 1
	mod_storage[key] = value ~= "" and value or nil
end
function Storage:get_int(key) return tonumber(mod_storage[key]) or 0 end
function Storage:set_int(key, value) mod_storage[key] = tostring(value) end

local function name_of(who)
	return type(who) == "string" and who or who:get_player_name()
end

core = {
	registered_items = {}, registered_privileges = {},
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_dieplayer = function(f) table.insert(callbacks.die, f) end,
	register_on_player_receive_fields = function(f) table.insert(callbacks.fields, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.mods_loaded, f) end,
	register_on_priv_grant = function(f) table.insert(callbacks.grant, f) end,
	register_on_priv_revoke = function(f) table.insert(callbacks.revoke, f) end,
	register_privilege = function(name, def) core.registered_privileges[name] = def end,
	check_player_privs = function(who, wanted)
		local own = privs[name_of(who)] or {}
		for priv in pairs(wanted) do if not own[priv] then return false end end
		return true
	end,
	get_modpath = function(name)
		local dirs = {grug_mail = "PLAYER/grug_mail", sfinv = "BASE/sfinv"}
		return ROOT .. "/mods/" .. (dirs[name] or name)
	end,
	get_current_modname = function() return "grug_mail" end,
	get_mod_storage = function() return setmetatable({}, Storage) end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local chunk = loadstring(text)
		if not chunk then return nil end
		setfenv(chunk, {})
		local ok, value = pcall(chunk)
		return ok and value or nil
	end,
	formspec_escape = function(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	colorize = function(_, text) return text end,
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	get_player_by_name = function(name)
		local player = players[name]
		return player and player.online and player or nil
	end,
	get_connected_players = function()
		local list = {}
		for _, player in pairs(players) do if player.online then list[#list + 1] = player end end
		return list
	end,
	player_exists = function(name) return players[name] ~= nil end,
	get_node = function() return {name = "air"} end,
	show_formspec = function() end,
	close_formspec = function() end,
	add_item = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
minetest = core
dump = function(value) return tostring(value) end
vector = {
	new = function(pos) return {x = pos.x, y = pos.y, z = pos.z} end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

-- A small ItemStack: name and count (the admin side never touches items).
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	if type(item) == "table" then item = item:to_string() end
	local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
	return setmetatable({name = name or "", count = name ~= "" and (tonumber(count) or 1) or 0},
		Stack)
end
function Stack:is_empty() return self.count <= 0 end
function Stack:to_string() return self.count > 0 and (self.name .. " " .. self.count) or "" end
function Stack:get_count() return self.count end
function Stack:get_name() return self.name end
function Stack:get_short_description() return self.name end
function Stack:equals(other) return self:to_string() == ItemStack(other):to_string() end

local function new_inventory()
	local inv = {lists = {}}
	function inv:set_size(list, size)
		self.lists[list] = self.lists[list] or {}
		for i = 1, size do self.lists[list][i] = self.lists[list][i] or ItemStack("") end
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i) return ItemStack((self.lists[list] or {})[i] or "") end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	return inv
end

local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end

------------------------------------------------------------------------------
-- Mod surface
------------------------------------------------------------------------------
grug_core = {
	factions = {accord = {name = "Accord"}, throng = {name = "Throng"}},
	feed = function() return true end,
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
}
grug_factions = {
	get_faction = function(player) return player.faction end,
	display_name = function(id)
		local def = id and grug_core.factions[id]
		return def and ("The " .. def.name) or nil
	end,
	register_on_faction_chosen = function() end,
}
grug_classes = {
	get_class = function(player) return player.class end,
	get_race = function(player) return player.race end,
	registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"}},
	registered_races = {dwarf = {name = "Dwarf"}, orc = {name = "Orc"}},
}
grug_xp = {get_level = function(player) return player.level end,
	register_on_level_change = function() end}
grug_classes.register_on_arrival = function() end
-- Lane QUEST's starter quest and letters (tools/r48_quest tests them): the
-- quest registers into a stub; every character here has had both already.
grug_quests = {register_quest = function() end}
grug_money = {get = function() return 0 end, format = function(n) return n .. "c" end}
local mail_counts = {}
grug_map = {minimap = {set_mail_count = function(name, n) mail_counts[name] = n end}}

grug_inventory = {BAG_COUNT = 4, INBOX_LIST = "grug_inbox",
	give = function(_, stack) return ItemStack(stack) end,
	fits = function() return true end,
	content_list = function(i) return "grug_bag" .. i .. "_content" end}
dofile(ROOT .. "/mods/BASE/sfinv/api.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/ui.lua")
grug_inventory.GAME_VERSION = "0.48.0"
function sfinv.get_homepage_name() return "grug_inventory:inventory" end
local function stub_page(name, title)
	sfinv.register_page(name, {title = title, get = function(_, player, context)
		return sfinv.make_formspec(player, context, "label[1,1;" .. title .. "]", false)
	end})
end
stub_page("grug_inventory:inventory", "Inventory")
stub_page("grug_inventory:help", "Help")
dofile(ROOT .. "/mods/PLAYER/grug_mail/init.lua")
stub_page("grug_parties:group", "Party & PvP")
for _, f in ipairs(callbacks.mods_loaded) do f() end

local function new_player(name, faction, race, class, level)
	local inv = new_inventory()
	local meta = setmetatable({fields = {["grug_mail:welcome_sent"] = "1",
		["grug_mail:quest_granted"] = "1"}}, Meta)
	local player = {online = true, hp = 20, pos = {x = 412.4, y = 18, z = -1290.2},
		faction = faction, race = race, class = class, level = level, formspec = ""}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return self.online end
	function player:get_pos() return self.pos end
	function player:get_hp() return self.hp end
	function player:set_inventory_formspec(text) self.formspec = text end
	players[name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
	return player
end

-- The engine's privilege change (builtin chat.lua /grant, /revoke): store
-- the privileges, then core.run_priv_callbacks (register.lua): the
-- privilege's own callback, and the global ones unless it returned true.
local function set_priv(name, value, method)
	privs[name] = privs[name] or {}
	privs[name].mail_admin = value or nil
	local def = core.registered_privileges.mail_admin
	local returned = def["on_" .. method](name, "server")
	if not returned then
		for _, func in ipairs(callbacks[method]) do func(name, "server", "mail_admin") end
	end
	return returned
end
local global_grants = 0
table.insert(callbacks.grant, function() global_grants = global_grants + 1 end)

-- An event of the inventory window ("" formname), through every handler.
local function send(player, fields)
	for _, f in ipairs(callbacks.fields) do
		if f(player, "", fields) then return end
	end
end
local function nav_titles(player)
	return player.formspec:match("tabheader%[0,0;sfinv_nav_tabs;([^;]*);") or ""
end
local function open_tab(player, title)
	local index = 0
	for entry in (nav_titles(player) .. ","):gmatch("([^,]*),") do
		index = index + 1
		if entry == title then
			send(player, {sfinv_nav_tabs = tostring(index)})
			return true
		end
	end
	return false
end
-- The name an action button has in the form shown now
-- (mail_admin_<action>_<draw>[_<id>], mail_admin_delete_<id>).
local function button(player, action)
	return player.formspec:match("(mail_admin_" .. action .. "_[%d_]+);")
end
local function letters_of(name) return grug_mail.store.box(name).letters end
local function logged(...)
	local parts = {...}
	for _, line in ipairs(logs) do
		local all = true
		for _, part in ipairs(parts) do all = all and line:find(part, 1, true) ~= nil end
		if all then return true end
	end
	return false
end

local PAGE = grug_mail.ADMIN_PAGE
local jan = new_player("Jan", "accord", "dwarf", "warrior", 30)
local alice = new_player("Alice", "accord", "dwarf", "warrior", 23)
local brakka = new_player("Brakka", "throng", "orc", "mage", 12)

------------------------------------------------------------------------------
-- P. The privilege gates the tab
------------------------------------------------------------------------------
do
	local def = core.registered_privileges.mail_admin
	check(def and def.give_to_admin == true, "P mail_admin is registered and given to the admin")
	eq(def.give_to_singleplayer, false, "P not given in singleplayer")
	eq(PAGE, "grug_mail:admin", "P the page name")
	local order = {}
	for _, page in ipairs(sfinv.pages_unordered) do order[#order + 1] = page.name end
	eq(table.concat(order, ","), "grug_inventory:inventory,grug_parties:group," ..
		"grug_inventory:help,grug_mail:admin", "P Admin Mail follows Help in the tab order")
	lacks(nav_titles(jan), "Admin Mail", "P without the privilege there is no Admin Mail tab")
	local returned = set_priv("Jan", true, "grant")
	check(not returned and global_grants == 1,
		"P on_grant returns nothing: the global grant callbacks still run")
	has(nav_titles(jan), "Help,Admin Mail", "P granting redraws the window: the tab follows Help")
	check(open_tab(jan, "Admin Mail") and sfinv.get_page(jan) == PAGE, "P the admin opens the tab")
	lacks(jan.formspec, "list[current_player;main", "P the tab shows no player inventory")
	has(jan.formspec, "set_focus[mail_admin_focus;true]", "P the focus sits on a harmless button")
	returned = set_priv("Jan", false, "revoke")
	check(not returned, "P on_revoke returns nothing")
	check(sfinv.get_page(jan) ~= PAGE, "P revoking leaves the open page")
	lacks(nav_titles(jan), "Admin Mail", "P revoking removes the tab")
	set_priv("Jan", true, "grant")
	open_tab(jan, "Admin Mail")
end

------------------------------------------------------------------------------
-- H. The inbox and the header
------------------------------------------------------------------------------
local first_id, second_id
do
	local ok, _, id = grug_mail.send_ticket(alice, "Bug report",
		"Waystone in Hearthpine does nothing", "When I right-click it nothing happens.",
		"Mailbox in Dur Brannoc")
	check(ok, "H Alice writes to the admin")
	first_id = id
	clock = clock + 60
	ok, _, second_id = grug_mail.send_ticket(brakka, "Question", "Name change?", "Can I?",
		"Mailbox in Grakmar")
	check(ok, "H Brakka writes to the admin")
	send(jan, {mail_admin_filter_open = "Open (2)"})
	has(jan.formspec, "Open (2)", "H the Open filter counts the open messages")
	has(jan.formspec, "Waystone in Hearthpine does nothing", "H the inbox lists the message")
	-- Newest first: row 1 is Brakka's, row 2 Alice's.
	send(jan, {mail_admin_list = "CHG:2:3"})
	local text = jan.formspec
	has(text, "From Alice · Level 23 · The Accord · Dwarf Warrior",
		"H the header: sender, level, faction, race and class")
	has(text, "Position (412\\, 18\\, -1290) · Sent from Mailbox in Dur Brannoc · Version 0.48.0",
		"H the header: position, the mailbox and the game version")
	has(text, "Bug report · ", "H the header names the topic")
	has(text, os.date("*t", clock - 60).day .. " ", "H the date shows")
	has(text, "When I right-click it nothing happens.", "H the message shows")
	has(text, "mail_admin_answer;;\n\n> When I right-click it nothing happens.",
		"H the answer box starts with the message quoted")
	lacks(text, "closed by", "H an open message has no Closed by")
	has(text, "Send answer and close", "H Send answer")
	has(text, "Close without answer", "H Close")
	-- A Player report shows its frozen copy.
	grug_mail.send_system("Brakka", "admin", "x", "s", "b") -- index Brakka for nothing else
	local letter = grug_mail.model.letter(9001, "player", "Gruk", "Cheap gold", "Pay me first.",
		{"t:ingot 12"}, clock - DAY)
	local box = grug_mail.store.box("Alice")
	grug_mail.model.deliver(box, letter)
	grug_mail.store.save_box("Alice", box)
	check(grug_mail.report_letter(alice, 9001, "Scam", "He never paid.", "Mailbox in Dur Brannoc"),
		"H Alice reports a letter")
	send(jan, {mail_admin_filter_all = "All"}) -- the redraw lists the report
	send(jan, {mail_admin_list = "CHG:1:1"})
	text = jan.formspec
	has(text, "Report: letter from Gruk", "H the report is listed")
	has(text, "Reason: Scam\nNote: He never paid.", "H the report's reason and note")
	has(text, "The reported letter #9001 from Gruk", "H the frozen copy's sender")
	has(text, "Subject: Cheap gold\nPay me first.", "H the frozen copy's subject and text")
	has(text, "Attachments: t:ingot x12", "H the frozen copy's attachments")
end

------------------------------------------------------------------------------
-- A. Answering, closing, deleting
------------------------------------------------------------------------------
do
	send(jan, {mail_admin_list = "CHG:3:3"}) -- Alice's bug report (the report is row 1)
	local before = #letters_of("Alice")
	local brakka_before = #letters_of("Brakka")
	local answer = button(jan, "answer")
	send(jan, {mail_admin_answer = "   ", [answer] = "Send answer and close"})
	has(jan.formspec, "Write an answer", "A an empty answer is refused")
	eq(grug_mail.ticket(first_id).state, "open", "A the refused answer leaves it open")
	answer = button(jan, "answer")
	send(jan, {mail_admin_answer = "\n\n> When I right-click it nothing happens.  ",
		[answer] = "Send answer and close"})
	has(jan.formspec, "Write an answer above the quoted message",
		"A an answer that is only the untouched quote is refused")
	eq(#letters_of("Alice"), before, "A the quote alone sends nothing")
	-- A stale form: A's buttons clicked after row B was selected (one round
	-- trip apart) act on nothing, and A's typed answer does not become B's.
	local a_answer, a_close, a_delete = button(jan, "answer"), button(jan, "close"),
		button(jan, "delete")
	check(a_answer:find("_" .. first_id .. "$") and a_delete == "mail_admin_delete_" .. first_id,
		"A the action buttons carry the selected message's id")
	send(jan, {mail_admin_list = "CHG:2:3"}) -- Brakka's question
	has(jan.formspec, "From Brakka", "A row B is selected")
	send(jan, {mail_admin_answer = "Private answer for Alice.", [a_answer] = "Send answer and close"})
	send(jan, {[a_close] = "Close without answer"})
	send(jan, {[a_delete] = "Delete"})
	check(grug_mail.ticket(first_id).state == "open" and grug_mail.ticket(second_id).state == "open",
		"A a stale click closes neither message")
	check(#letters_of("Alice") == before and #letters_of("Brakka") == brakka_before,
		"A a stale click sends no letter")
	check(grug_mail.ticket(first_id) and grug_mail.ticket(second_id), "A a stale click deletes nothing")
	lacks(jan.formspec, "Private answer for Alice.", "A the stale answer text is not kept for B")
	send(jan, {mail_admin_list = "CHG:3:3"}) -- back to Alice's
	answer = button(jan, "answer")
	send(jan, {mail_admin_answer = "Fixed after a restart.", [answer] = "Send answer and close"})
	local ticket = grug_mail.ticket(first_id)
	check(ticket.state == "closed" and ticket.answered and ticket.closed_by == "Jan",
		"A Send answer closes the ticket as answered, by the admin")
	local reply = letters_of("Alice")[1]
	check(#letters_of("Alice") == before + 1 and reply.kind == "admin" and
		reply.from == "Server Admin" and reply.subject == "Re: Waystone in Hearthpine does nothing" and
		reply.body == "Fixed after a restart." and #reply.items == 0,
		"A the answer arrives as an admin letter Re: <subject> from Server Admin, no items")
	eq(grug_mail.model.ticket_state(grug_mail.ticket(first_id)), "Answered",
		"A the player sees it Answered")
	check(logged("answer to ticket #" .. first_id, "by Jan") and
		logged("ticket #" .. first_id .. " answered by Jan"),
		"A the answer and the closing are logged with the admin's name")
	has(jan.formspec, "Answered and closed by Jan", "A Closed by shows in the tab")
	has(jan.formspec, "Answer sent to Alice", "A the tab confirms")
	lacks(reply.from .. reply.body, "Jan", "A the player never sees the admin's name")
	-- A double click: the second click comes from the form already replaced.
	send(jan, {mail_admin_answer = "Fixed after a restart.", [answer] = "Send answer and close"})
	eq(#letters_of("Alice"), before + 1, "A a double click on Send answer sends one letter")
	-- Close without an answer.
	send(jan, {mail_admin_filter_all = "All"})
	send(jan, {mail_admin_list = "CHG:2:3"})
	has(jan.formspec, "Name change?", "A All lists every message")
	local brakka_letters = #letters_of("Brakka")
	send(jan, {[button(jan, "close")] = "Close without answer"})
	ticket = grug_mail.ticket(second_id)
	check(ticket.state == "closed" and not ticket.answered and ticket.closed_by == "Jan",
		"A Close closes without an answer")
	eq(#letters_of("Brakka"), brakka_letters, "A Close sends no letter")
	eq(grug_mail.model.ticket_state(ticket), "Closed", "A the player sees it Closed")
	has(jan.formspec, "Closed without answer by Jan", "A Closed by for a closing")
	check(logged("ticket #" .. second_id .. " closed by Jan"), "A the closing is logged")
	lacks(jan.formspec, "Send answer and close", "A a closed message has no answer box")
	-- The Open filter no longer lists them.
	send(jan, {mail_admin_filter_open = "Open"})
	lacks(jan.formspec, "Name change?", "A Open hides closed messages (and drops the selection)")
	has(jan.formspec, "Open (1)", "A one open message left (the report)")
	-- Delete removes it for everyone.
	send(jan, {mail_admin_filter_all = "All"})
	send(jan, {mail_admin_list = "CHG:2:3"})
	send(jan, {[button(jan, "delete")] = "Delete"})
	check(grug_mail.ticket(second_id) == nil and
		#grug_mail.model.tickets_of(grug_mail.tickets(), "Brakka") == 0,
		"A Delete removes the message for everyone")
	check(logged("ticket #" .. second_id .. " deleted by Jan"), "A the deletion is logged")
end

------------------------------------------------------------------------------
-- C. New admin letters and announcements
------------------------------------------------------------------------------
do
	send(jan, {mail_admin_new = "New admin letter"})
	has(jan.formspec, "Back to admin mail", "C New admin letter opens the compose view")
	has(jan.formspec, "Send as Server Admin", "C the compose view sends as Server Admin")
	lacks(jan.formspec, "list[", "C admin letters carry no items: no item slots")
	-- One player.
	local before = #letters_of("Brakka")
	send(jan, {mail_admin_to = "brakka", mail_admin_subject = "Hello there",
		mail_admin_body = "Welcome.", mail_admin_preview = "Update preview"})
	has(jan.formspec, "Server Admin", "C the preview shows the sender as players see it")
	has(jan.formspec, "Hello there", "C the preview shows the subject")
	has(jan.formspec, "Sent by the server administration", "C the preview shows the banner")
	has(jan.formspec, "grug_mail_admin_badge.png", "C the preview shows the shield badge")
	has(jan.formspec, "mailbox (Letters)", "C the preview names the Letters list")
	local sending = button(jan, "send")
	send(jan, {mail_admin_to = "brakka", mail_admin_subject = "Hello there",
		mail_admin_body = "Welcome.", [sending] = "Send as Server Admin"})
	local letter = letters_of("Brakka")[1]
	check(#letters_of("Brakka") == before + 1 and letter.kind == "admin" and
		letter.from == "Server Admin" and letter.subject == "Hello there" and #letter.items == 0,
		"C an admin letter to one player, from Server Admin, text only")
	check(logged("admin Jan wrote admin letter #" .. letter.id .. " to Brakka"),
		"C the admin letter is logged with the admin's name")
	send(jan, {mail_admin_to = "brakka", mail_admin_subject = "Hello there",
		mail_admin_body = "Welcome.", [sending] = "Send as Server Admin"})
	eq(#letters_of("Brakka"), before + 1, "C a double click sends one letter")
	send(jan, {mail_admin_to = "Nobody", mail_admin_subject = "x",
		[button(jan, "send")] = "Send as Server Admin"})
	has(jan.formspec, "There is no player called Nobody.", "C an unknown name is refused")
	send(jan, {mail_admin_to = "Alice", mail_admin_subject = "  ",
		[button(jan, "send")] = "Send as Server Admin"})
	has(jan.formspec, "Write a subject.", "C a subject is needed")
	-- All players: one broadcast, read per player.
	local alice_box_writes = storage_writes["box:Alice"] or 0
	send(jan, {mail_admin_all = "true", mail_admin_subject = "Restart on Sunday",
		mail_admin_body = "Back within minutes."})
	has(jan.formspec, "Every player\\, also characters created later", "C All players replaces the name")
	lacks(jan.formspec, "field[1.50,1.25;6.0,0.65;mail_admin_to", "C no name field for All players")
	has(jan.formspec, "mailbox (Announcements)", "C the preview names Announcements")
	local alice_before, brakka_before = grug_mail.unread_count("Alice"), grug_mail.unread_count("Brakka")
	sending = button(jan, "send")
	send(jan, {mail_admin_subject = "Restart on Sunday", mail_admin_body = "Back within minutes.",
		[sending] = "Send as Server Admin"})
	send(jan, {mail_admin_subject = "Restart on Sunday", mail_admin_body = "Back within minutes.",
		[sending] = "Send as Server Admin"})
	local broadcasts = grug_mail.broadcasts()
	eq(#broadcasts, 1, "C an announcement is stored once (a double click too)")
	eq(storage_writes["box:Alice"] or 0, alice_box_writes, "C no player's mailbox is written")
	check(broadcasts[1].subject == "Restart on Sunday" and broadcasts[1].by == "Jan",
		"C the broadcast keeps the admin's name for the tab")
	check(logged("broadcast #" .. broadcasts[1].id .. " by Jan"), "C the broadcast is logged")
	eq(grug_mail.unread_count("Alice"), alice_before + 1, "C Alice sees it unread")
	eq(grug_mail.unread_count("Brakka"), brakka_before + 1, "C Brakka (other faction) too")
	grug_mail.read_broadcast(alice, broadcasts[1].id)
	eq(grug_mail.unread_count("Alice"), alice_before, "C reading marks it read for Alice")
	eq(grug_mail.unread_count("Brakka"), brakka_before + 1, "C but not for Brakka")
	local late = new_player("Late", "accord", "dwarf", "mage", 1)
	eq(grug_mail.unread_count("Late"), 1, "C a character created later sees it")
	check(late and grug_mail.store.read_set(late)[broadcasts[1].id] == nil,
		"C the late character's read state is its own")
	-- The sent announcements, and deleting one.
	send(jan, {mail_admin_back = "Back to admin mail"})
	send(jan, {mail_admin_filter_announcements = "Announcements"})
	has(jan.formspec, "Restart on Sunday", "C the tab lists the sent announcements")
	send(jan, {mail_admin_list = "CHG:1:2"})
	has(jan.formspec, "To all players\\, by Jan", "C an announcement shows who sent it")
	send(jan, {[button(jan, "delete")] = "Delete"})
	eq(#grug_mail.broadcasts(), 0, "C Delete removes the announcement for everyone")
	eq(grug_mail.unread_count("Brakka"), brakka_before, "C and from the unread count")
	-- Discard.
	send(jan, {mail_admin_new = "New admin letter"})
	send(jan, {mail_admin_to = "Alice", mail_admin_subject = "Draft", mail_admin_discard = "Discard"})
	lacks(jan.formspec, "Draft", "C Discard clears the letter")
end

------------------------------------------------------------------------------
-- N. A non-admin's submission to the admin page
------------------------------------------------------------------------------
do
	local report
	for _, ticket in ipairs(grug_mail.tickets()) do if ticket.report then report = ticket end end
	check(report and report.state == "open", "N the report is still open")
	-- Brakka has no privilege: no tab, and a forged event on the page acts on
	-- nothing (the page context set by hand, as a stale or forged form would).
	lacks(nav_titles(brakka), "Admin Mail", "N no tab without the privilege")
	check(not open_tab(brakka, "Admin Mail"), "N the tab cannot be chosen")
	local context = sfinv.get_or_create_context(brakka)
	context.page = PAGE
	local letters = #letters_of("Alice")
	context.grug_mail_admin = {view = "inbox", filter = "all", page = 1, draw = 5, floor = 0,
		answer = "", selected = report.id, rows = {report},
		compose = {to = "Alice", all = true, subject = "Hacked", body = "x"}}
	send(brakka, {mail_admin_answer = "Ha.", ["mail_admin_answer_5_" .. report.id] = "Send answer and close"})
	context.page = PAGE
	send(brakka, {["mail_admin_close_5_" .. report.id] = "Close without answer"})
	context.page = PAGE
	send(brakka, {["mail_admin_delete_" .. report.id] = "Delete"})
	context = sfinv.get_or_create_context(brakka)
	context.page = PAGE
	context.grug_mail_admin = {view = "compose", page = 1, draw = 5, floor = 0, answer = "",
		compose = {to = "Alice", all = true, subject = "Hacked", body = "x"}}
	send(brakka, {mail_admin_send_5 = "Send as Server Admin"})
	report = grug_mail.ticket(report.id)
	check(report and report.state == "open", "N the report stays open and is not deleted")
	eq(#letters_of("Alice"), letters, "N no letter is sent")
	eq(#grug_mail.broadcasts(), 0, "N no announcement is stored")
	check(sfinv.get_page(brakka) ~= PAGE, "N the page is left")
	check(logged("Brakka sent Admin Mail fields without the mail_admin privilege"),
		"N the refusal is logged")
	-- The page itself shows nothing of the inbox without the privilege.
	local text = grug_mail.admin_formspec(brakka, {})
	lacks(text, "Report: letter from Gruk", "N the page draws no inbox without the privilege")
end

-- Sizes of the tab's sends (bytes), for the report.
send(jan, {mail_admin_back = "Back to admin mail"})
send(jan, {mail_admin_filter_all = "All"})
send(jan, {mail_admin_list = "CHG:1:1"})
print(("bytes: Admin Mail inbox with a selected report %d"):format(#jan.formspec))
send(jan, {mail_admin_new = "New admin letter"})
print(("bytes: Admin Mail compose %d"):format(#jan.formspec))

if failures > 0 then
	error(("R48 ADMIN PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R48 ADMIN PORTABLE PASS checks=%d"):format(checks))
