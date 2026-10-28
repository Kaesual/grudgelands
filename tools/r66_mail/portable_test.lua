-- Round 66 lane MAIL portable test (LuaJIT): the sender's text copy of a
-- player letter and the read-only Sent tab (round66-plan.md §2 ruling 3 and
-- the coordinator default "Sent tab", §4 MAIL, §6).
--
--   luajit tools/r66_mail/portable_test.lua [repo]
--
-- Loads the REAL grug_mail model, store, api and window and the REAL
-- grug_core ui and ui_rows on a fake engine (money, inventory and the give
-- order are small stand-ins; the real sending transaction is tested by
-- tools/r48_mail). Checks:
--   A  the model: a copy holds the text, postage and attachment names; the
--      50-cap drops the oldest silently;
--   B  the store: a missing key reads as empty; expiry after 30 days, saved
--      when read; an empty list removes the key;
--   C  sending: one copy per sent letter with the attachments' names and
--      counts, never item strings; the recipient's letter and the box format
--      are unchanged; refused letters, admin and NPC letters, messages to
--      the admin and announcements write no copy; the 51st send drops the
--      oldest copy and still succeeds; delete; expiry;
--   D  the window: five tab buttons sharing the bar, the second opens Sent;
--      the list (recipient, date, attachment count), the reading pane (To:,
--      postage, attachment names as text), no Take all, Reply or Report, no
--      item image; Delete without a dialog; the empty list; a second page.
-- Prints "R66 MAIL PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function has(text, part) return text:find(part, 1, true) ~= nil end

local DAY = 24 * 3600
local NOW = 1800000000
local clock = NOW
os.time = function() return clock end

------------------------------------------------------------------------------
-- Fake engine
------------------------------------------------------------------------------
local function serialize(value)
	local kind = type(value)
	if kind == "string" then return string.format("%q", value) end
	if kind ~= "table" then return tostring(value) end
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

local mod_storage = {}
local Storage = {}
Storage.__index = Storage
function Storage:get_string(key) return mod_storage[key] or "" end
function Storage:set_string(key, value) mod_storage[key] = value ~= "" and value or nil end
function Storage:get_int(key) return tonumber(mod_storage[key]) or 0 end
function Storage:set_int(key, value) mod_storage[key] = tostring(value) end

local callbacks = {join = {}, fields = {}}
local formspecs, players, nodes = {}, {}, {}
local items = {
	["t:ingot"] = {description = "Iron Ingot", stack_max = 99},
	["t:axe"] = {description = "Bronze Axe\nA sturdy axe.", stack_max = 1},
}

core = {
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
	log = function() end,
	register_on_joinplayer = function(f) callbacks.join[#callbacks.join + 1] = f end,
	register_on_player_receive_fields = function(f) callbacks.fields[#callbacks.fields + 1] = f end,
	register_on_mods_loaded = function(f) f() end,
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
	get_node = function(pos)
		return {name = nodes[pos.x .. "," .. pos.y .. "," .. pos.z] or "air"}
	end,
	show_formspec = function(name, formname, text)
		formspecs[name] = {formname = formname, text = text}
	end,
	close_formspec = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {
	new = function(pos) return {x = pos.x, y = pos.y, z = pos.z} end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

-- ItemStack: name and count are enough here (meta travels in tools/r48_mail).
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	if type(item) == "table" then return setmetatable({name = item.name, count = item.count}, Stack) end
	local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
	return setmetatable({name = name or "", count = name ~= "" and (tonumber(count) or 1) or 0}, Stack)
end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_name() return self.name end
function Stack:get_count() return self.count end
function Stack:to_string() return self:is_empty() and "" or (self.name .. " " .. self.count) end
function Stack:get_description()
	return items[self.name] and items[self.name].description or self.name
end
function Stack:get_short_description()
	return (self:get_description():match("^[^\n]*"))
end

local function new_inventory()
	local inv = {lists = {main = {}}}
	function inv:set_size(list, size)
		self.lists[list] = self.lists[list] or {}
		for i = 1, size do self.lists[list][i] = self.lists[list][i] or ItemStack("") end
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i) return ItemStack(self.lists[list][i] or "") end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:is_empty(list)
		for _, stack in ipairs(self.lists[list] or {}) do
			if not stack:is_empty() then return false end
		end
		return true
	end
	return inv
end

local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end

------------------------------------------------------------------------------
-- Mod surface
------------------------------------------------------------------------------
local money = {}
grug_money = {
	get = function(player) return money[player:get_player_name()] or 0 end,
	format = function(copper) return tostring(copper) .. "c" end,
	-- The real transaction (tools/r48_mail): money and the slots in one step.
	take_with_inventory = function(player, amount, changes)
		local name = player:get_player_name()
		if (money[name] or 0) < amount then return false, "Not enough money." end
		money[name] = money[name] - amount
		for _, change in ipairs(changes) do
			player:get_inventory():set_stack(change.list, change.index, change.replacement)
		end
		return true
	end,
}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end,
}
grug_xp = {get_level = function() return 12 end}
grug_classes = {get_class = function() return "warrior" end, get_race = function() return "dwarf" end}
grug_sounds = {CLICK_STYLE = ""}
grug_core = {
	feed = function() return true end,
	settlement_socket_settlements = function()
		return {{key = "dur_brannoc", display_name = "Dur Brannoc"}}
	end,
	settlement_sockets_at = function()
		return {{role = "waypoint", pos = {x = 100, y = 10, z = 100}}}
	end,
}
grug_inventory = {
	GAME_VERSION = "0.66.0",
	UI = {frame_w = 20, frame_h = 13.5, window_h = 15},
	SCROLL_FIELDS = {short = "grug_inv_scroll_short"},
	INBOX_LIST = "grug_inbox",
	BAG_COUNT = 0,
	inventory_view = function() return "<inventory view>" end,
	hotbar_switch_fields = function() return false end,
	wrap_text = function(text) return text end,
	give = function(_, stack) return ItemStack("") end,
	fits = function() return true end,
}
dofile(ROOT .. "/mods/CORE/grug_core/ui.lua")
dofile(ROOT .. "/mods/CORE/grug_core/ui_rows.lua")

grug_mail = {}
local M = dofile(ROOT .. "/mods/PLAYER/grug_mail/model.lua")
grug_mail.model = M
local S = dofile(ROOT .. "/mods/PLAYER/grug_mail/store.lua")
grug_mail.store = S
dofile(ROOT .. "/mods/PLAYER/grug_mail/api.lua")
dofile(ROOT .. "/mods/PLAYER/grug_mail/window.lua")
local ATTACH = grug_mail.ATTACH_LIST

local function new_player(name, faction)
	local inv = new_inventory()
	local meta = setmetatable({fields = {}}, Meta)
	local player = {online = true, faction = faction, pos = {x = 100, y = 10, z = 103}}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return self.online end
	function player:get_pos() return self.pos end
	function player:get_hp() return 20 end
	players[name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
	return player
end

local alice = new_player("Alice", "accord")
local brakka = new_player("Brakka", "accord")
new_player("Gruk", "throng")
money.Alice = 100000

local function send(subject, body, attachments)
	for index, item in ipairs(attachments or {}) do
		alice:get_inventory():set_stack(ATTACH, index, ItemStack(item))
	end
	return grug_mail.send_letter(alice, "Brakka", subject, body or "")
end

------------------------------------------------------------------------------
-- A. The model
------------------------------------------------------------------------------
eq(M.SENT_LIMIT, 50, "A at most 50 sent copies")
do
	local names = {"Iron Ingot x12"}
	local copy = M.sent_copy(7, "Brakka", "Ingots", "For you.", 35, names, NOW)
	check(copy.id == 7 and copy.to == "Brakka" and copy.subject == "Ingots" and
		copy.body == "For you." and copy.postage == 35 and copy.time == NOW and
		copy.attachments[1] == "Iron Ingot x12" and #copy.attachments == 1,
		"A a copy holds recipient, date, text, postage and attachment names")
	names[2] = "changed"
	eq(#copy.attachments, 1, "A the copy keeps its own list")
	check(copy.read == nil and copy.items == nil, "A a copy holds no read state and no items")
	local list = {}
	for id = 1, 51 do M.keep_sent(list, M.sent_copy(id, "B", "s", "b", 5, {}, NOW)) end
	check(#list == 50 and list[1].id == 51 and list[50].id == 2,
		"A the 51st copy drops the oldest, newest first")
end

------------------------------------------------------------------------------
-- B. The store
------------------------------------------------------------------------------
do
	check(mod_storage["sent:Alice"] == nil and #S.sent("Alice") == 0,
		"B a missing key reads as an empty list")
	local list = {M.sent_copy(1, "B", "new", "", 5, {}, NOW - 30 * DAY + 1),
		M.sent_copy(2, "B", "old", "", 5, {}, NOW - 30 * DAY)}
	S.save_sent("Zed", list)
	local read = S.sent("Zed")
	check(#read == 1 and read[1].id == 1, "B a copy 30 days old expires when read")
	check(not has(mod_storage["sent:Zed"], "old"), "B the expiry is saved")
	S.save_sent("Zed", {})
	eq(mod_storage["sent:Zed"], nil, "B an empty list removes the key")
end

------------------------------------------------------------------------------
-- C. Sending
------------------------------------------------------------------------------
do
	local ok, message = send("Your axe", "As promised.", {"t:ingot 12", "", "t:axe"})
	check(ok and message == "Letter sent to Brakka. Postage paid: 65c.", "C sent: " .. tostring(message))
	local sent = grug_mail.sent("Alice")
	local letter = S.box("Brakka").letters[1]
	eq(#sent, 1, "C one copy per sent letter")
	local copy = sent[1]
	check(copy.id == letter.id and copy.to == "Brakka" and copy.subject == "Your axe" and
		copy.body == "As promised." and copy.postage == 65 and copy.time == NOW,
		"C the copy holds the letter's id, recipient, date, text and postage")
	check(#copy.attachments == 2 and copy.attachments[1] == "Iron Ingot x12" and
		copy.attachments[2] == "Bronze Axe", "C the attachments as display names and counts")
	check(not has(mod_storage["sent:Alice"], "t:ingot") and not has(mod_storage["sent:Alice"], "t:axe"),
		"C the copy stores no item string: nothing can be taken")
	-- The recipient's letter and the box format are those of 0.65.0.
	local keys = {}
	for key in pairs(letter) do keys[#keys + 1] = key end
	table.sort(keys)
	eq(table.concat(keys, ","), "body,from,id,items,kind,read,reported,subject,time",
		"C the letter keeps exactly its 0.65.0 fields")
	check(#letter.items == 2 and letter.items[1] == "t:ingot 12",
		"C the recipient's letter holds the items")
	check(not has(mod_storage["box:Brakka"], "postage") and
		not has(mod_storage["box:Brakka"], "attachments") and
		not has(mod_storage["box:Alice"] or "", "Your axe"), "C nothing of the copy enters a mailbox")
	check(alice:get_inventory():is_empty(ATTACH), "C the slots left with the letter")
end

do -- no copy for what is not sent as a player letter
	local before = mod_storage["sent:Alice"]
	local ok = grug_mail.send_letter(alice, "Gruk", "Hi", "")
	check(not ok, "C a refused recipient is refused")
	ok = grug_mail.send_letter(alice, "Brakka", "Long", string.rep("x", 4001))
	check(not ok, "C a long letter is refused")
	local poor = money.Alice
	money.Alice = 2
	ok = grug_mail.send_letter(alice, "Brakka", "Broke", "")
	money.Alice = poor
	check(not ok, "C a letter without postage is refused")
	grug_mail.send_system("Alice", "admin", "Jan", "Welcome", "Hello.")
	grug_mail.send_system("Brakka", "npc", "Riding Trainer", "Mount", "Come.")
	grug_mail.send_ticket(alice, "Question", "Lag", "Slow.", "Mailbox")
	grug_mail.send_broadcast("News", "Read me.", "Jan")
	eq(mod_storage["sent:Alice"], before, "C refusals, admin and NPC letters, tickets, " ..
		"announcements: no copy")
	check(mod_storage["sent:Server Admin"] == nil and mod_storage["sent:Jan"] == nil and
		mod_storage["sent:Riding Trainer"] == nil, "C no sent list for the admin side")
end

do -- the cap at send: the 51st copy drops the oldest silently
	local box = S.box("Brakka")
	box.letters = {}
	S.save_box("Brakka", box)
	local first = grug_mail.sent("Alice")[1].id
	for index = 2, 51 do
		clock = NOW + index
		local ok = send("Letter " .. index, "")
		if not ok then check(false, "C send " .. index .. " succeeds") end
		if index == 50 then
			box = S.box("Brakka")
			box.letters = {}
			S.save_box("Brakka", box)
		end
	end
	local sent = grug_mail.sent("Alice")
	check(#sent == 50 and sent[1].subject == "Letter 51" and sent[50].subject == "Letter 2" and
		not M.find(sent, first), "C at 51 sends the oldest copy is gone, the send succeeded")
	eq(sent[1].postage, 5, "C a letter without attachments: 5c, no names")
	eq(#sent[1].attachments, 0, "C ...and no attachment names")
end

do -- delete and expiry
	local id = grug_mail.sent("Alice")[1].id
	local ok, message = grug_mail.delete_sent(alice, id)
	check(ok and message == "Sent letter deleted." and not M.find(grug_mail.sent("Alice"), id),
		"C delete removes the copy")
	ok, message = grug_mail.delete_sent(alice, id)
	check(not ok and message == "That letter is gone.", "C a second delete finds nothing")
	clock = NOW + 30 * DAY + 2
	local sent = grug_mail.sent("Alice")
	check(#sent == 48 and sent[48].subject == "Letter 3", "C copies expire 30 days after sending")
	clock = NOW + 31 * DAY
	eq(#grug_mail.sent("Alice"), 0, "C every copy expires")
	eq(mod_storage["sent:Alice"], nil, "C ...and the key goes with the last one")
end

------------------------------------------------------------------------------
-- D. The window
------------------------------------------------------------------------------
local MAILBOX = {x = 102, y = 10, z = 100}
nodes["102,10,100"] = "grug_mapgen:mailbox"
local function fields(player, sent)
	local form = formspecs[player:get_player_name()]
	for _, f in ipairs(callbacks.fields) do
		if f(player, form and form.formname or "", sent) then return end
	end
end
local function form() return formspecs.Alice.text end

do
	check(grug_mail.open_mailbox(alice, MAILBOX), "D the window opens")
	local session = grug_mail.session("Alice")
	-- Five buttons share the bar: (20 - 0.8) / 5 = 3.84 a place, 3.74 wide.
	local captions = {"Letters", "Sent", "Announcements", "Write", "To the admin"}
	for index, caption in ipairs(captions) do
		local x = 0.4 + (index - 1) * 3.84
		check(has(form(), ("button[%.3f,0.2;3.740,0.6;grug_mail_tab_%d;"):format(x, index)),
			"D tab " .. index .. " is drawn at its fifth of the bar")
		check(has(form(), ";grug_mail_tab_" .. index .. ";" .. caption), "D tab " .. index ..
			" reads " .. caption)
	end
	check(not has(form(), "grug_mail_tab_6"), "D five tabs, no more")
	fields(alice, {grug_mail_tab_2 = true})
	eq(session.tab, "sent", "D the second tab opens Sent")
	check(has(form(), "You have not sent any letters."), "D the empty list says so")
	clock = NOW + 40 * DAY
	money.Alice = 1000
	grug_mail.send_system("Alice", "admin", "Jan", "Welcome back", "Hello.")
	send("Your axe", "As promised.", {"t:ingot 12", "t:axe"})
	for index = 1, 9 do
		clock = clock + 60
		send("Note " .. index, "Text " .. index)
	end
	fields(alice, {grug_mail_tab_2 = true})
	check(has(form(), "Note 9") and has(form(), "To Brakka · "), "D the list shows subject and recipient")
	check(has(form(), "Page 1 / 2") and not has(form(), "Your axe"),
		"D eight a page, newest first: the oldest on page 2")
	check(has(form(), "10 sent letters"), "D the count under the list")
	fields(alice, {sent_next = true})
	check(has(form(), "Your axe") and has(form(), "2 attachments"),
		"D page 2: the oldest with its attachment count")
	fields(alice, {sent_row_2 = true})
	local copy = grug_mail.sent("Alice")[10]
	eq(session.selected.sent, copy.id, "D a row opens its copy")
	local text = form()
	check(has(text, "To: Brakka") and not has(text, "From: "), "D the pane names the recipient")
	check(has(text, "As promised."), "D the pane shows the text")
	check(has(text, "Postage paid: 65c"), "D the pane shows the postage paid")
	check(has(text, "• Iron Ingot x12") and has(text, "• Bronze Axe"),
		"D the attachment names as text")
	check(not has(text, "item_image[") and not has(text, "take_all") and
		not has(text, ";reply;") and not has(text, ";report;"),
		"D nothing to take, no Reply, no Report")
	check(has(text, ";sent_delete_" .. copy.id .. ";Delete]"), "D Delete carries the copy's id")
	fields(alice, {["sent_delete_" .. copy.id] = "Delete"})
	check(not M.find(grug_mail.sent("Alice"), copy.id) and session.dialog == nil and
		session.status == "Sent letter deleted.", "D Delete removes the copy at once, no dialog")
	-- A Delete drawn for another copy acts on nothing.
	fields(alice, {sent_prev = true})
	fields(alice, {sent_row_1 = true})
	local shown = session.selected.sent
	fields(alice, {["sent_delete_" .. (shown - 1)] = "Delete"})
	eq(#grug_mail.sent("Alice"), 9, "D a stale Delete deletes nothing")
	-- Letters still lists the received ones, unaffected.
	fields(alice, {grug_mail_tab_1 = true})
	eq(session.tab, "letters", "D the first tab is still Letters")
	check(has(form(), "Letters (1)") and has(form(), "Welcome"), "D Letters keeps its unread count")
	fields(alice, {grug_mail_tab_3 = true})
	eq(session.tab, "announcements", "D the third tab is Announcements")
	fields(alice, {quit = "true"})
end

if failures > 0 then
	error(("R66 MAIL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R66 MAIL PORTABLE PASS checks=%d"):format(checks))
