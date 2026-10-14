-- Round 48 lane MAIL portable test (LuaJIT; mail plan §6 "MAIL", round
-- plan §3.2-§3.5, §3.9):
--   A. the pure model (grug_mail/model.lua): postage, the 50-letter limit,
--      expiry, pagination, the unread count, read state, the 5-open cap,
--      tickets, reports, text cleaning;
--   B. the sending path under an engine stub, with the REAL grug_money
--      (take_with_inventory), the REAL give/fit helpers (grug_inventory
--      bags.lua + storage.lua, inbox.lua) and the REAL guards
--      (grug_skills/bound_items.lua, grug_housing/soulbound.lua): money and
--      stacks in one step, a changed slot refuses with nothing lost, the
--      guards keep soulbound, skill and mount items out of the attachment
--      list, closing returns the stacks and keeps leftovers, item meta
--      survives, Take all refuses without room, faction and unknown-name
--      refusals, send_system with stacks;
--   C. tickets, reports, answers and broadcasts in the stores;
--   D. the window: opening, every tab and dialog builds, the Write tab's
--      quote, reach, closing.
--
--   luajit tools/r48_mail/portable_test.lua [REPO]
-- Prints "R48 MAIL PORTABLE PASS checks=<n>" or the failures (exit 1).

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

------------------------------------------------------------------------------
-- A. The pure model
------------------------------------------------------------------------------
local M = dofile(ROOT .. "/mods/PLAYER/grug_mail/model.lua")
local DAY = 24 * 3600
local NOW = 1800000000

eq(M.postage(0), 5, "A postage without attachments")
eq(M.postage(1), 35, "A postage with one stack")
eq(M.postage(4), 125, "A postage with four stacks")

do
	local box = M.new_box()
	for i = 1, 49 do M.deliver(box, M.letter(i, "player", "P", "s", "b", {}, NOW)) end
	check(M.accepts(box, "player"), "A 49 player letters: one more fits")
	M.deliver(box, M.letter(50, "player", "P", "s", "b", {}, NOW))
	check(not M.accepts(box, "player"), "A 50 player letters: player mail refused")
	check(M.accepts(box, "admin") and M.accepts(box, "npc"),
		"A 50 player letters: admin and system mail still arrive")
	M.deliver(box, M.letter(51, "admin", "x", "s", "b", {}, NOW))
	M.deliver(box, M.letter(52, "npc", "Riding Trainer", "s", "b", {}, NOW))
	eq(M.player_letters(box), 50, "A admin and npc letters do not count to the limit")
	eq(box.letters[1].id, 52, "A newest first")
end

do
	local list = {
		{id = 1, time = NOW - 30 * DAY, items = {"default:dirt 5"}},
		{id = 2, time = NOW - 30 * DAY + 1},
		{id = 3, time = NOW},
		{id = 4, time = NOW - 45 * DAY},
	}
	eq(M.prune(list, NOW), 2, "A expiry removes the entries 30 days old and older")
	check(#list == 2 and list[1].id == 2 and list[2].id == 3,
		"A expiry keeps the younger ones (the attachments leave with theirs)")
	local tickets = {{id = 9, time = NOW - 31 * DAY}, {id = 10, time = NOW}}
	local broadcasts = {{id = 11, time = NOW - 31 * DAY}}
	M.prune(tickets, NOW)
	M.prune(broadcasts, NOW)
	check(#tickets == 1 and #broadcasts == 0, "A expiry applies to tickets and broadcasts")
end

do
	local list = {}
	for i = 1, 17 do list[i] = {id = i} end
	local rows, page, pages = M.page(list, 1)
	check(#rows == 8 and rows[1].id == 1 and page == 1 and pages == 3, "A page 1 of 17 rows")
	rows, page = M.page(list, 3)
	check(#rows == 1 and rows[1].id == 17 and page == 3, "A last page holds the rest")
	local _
	_, page = M.page(list, 9)
	eq(page, 3, "A a page past the end clamps to the last")
	_, page = M.page(list, 0)
	eq(page, 1, "A a page before the start clamps to the first")
	rows, page, pages = M.page({}, 2)
	check(#rows == 0 and page == 1 and pages == 1, "A an empty list has one page")
	eq(M.page_of(list, 9), 2, "A the page of an entry")
end

do
	local box = M.new_box()
	M.deliver(box, M.letter(1, "player", "P", "s", "b", {}, NOW))
	M.deliver(box, M.letter(2, "admin", "x", "s", "b", {}, NOW))
	local broadcasts = {{id = 7, time = NOW}, {id = 8, time = NOW}, {id = 6, time = NOW - 40 * DAY}}
	eq(M.unread(box, broadcasts, {}, NOW), 4,
		"A unread = unread letters + unread live broadcasts")
	check(M.mark_read(box.letters[1]), "A opening marks read")
	check(not M.mark_read(box.letters[1]), "A opening again changes nothing")
	eq(M.unread(box, broadcasts, {[7] = true}, NOW), 2, "A a read broadcast no longer counts")
	local set = M.trim_read_set({[7] = true, [99] = true}, broadcasts)
	check(set[7] and not set[99], "A the read set keeps existing broadcasts only")
end

do
	local tickets = {}
	for i = 1, 4 do tickets[i] = M.ticket(i, "Alice", "Question", "s", "b", {}, NOW) end
	check(M.can_open_ticket(tickets, "Alice"), "A four open: a fifth may be sent")
	local letter = M.letter(30, "player", "Scamz", "Cheap gold", "Pay first", {}, NOW - DAY)
	tickets[5] = M.report_ticket(5, "Alice", letter, "Scam", "", {"Bag of Coins"}, {}, NOW)
	local ok, message = M.can_open_ticket(tickets, "Alice")
	check(not ok and message:find("5 open", 1, true), "A five open (a report included): refused")
	check(M.can_open_ticket(tickets, "Bob"), "A the cap is per player")
	check(M.close(tickets[1], "Jan", true, NOW), "A an open ticket closes")
	check(not M.close(tickets[1], "Jan", false, NOW), "A a closed ticket stays closed")
	check(M.can_open_ticket(tickets, "Alice"), "A a closed ticket frees the cap")
	eq(M.ticket_state(tickets[1]), "Answered", "A closed with an answer reads Answered")
	M.close(tickets[2], "Jan", false, NOW)
	eq(M.ticket_state(tickets[2]), "Closed", "A closed without an answer reads Closed")
	eq(M.ticket_state(tickets[3]), "Open", "A open reads Open")
	eq(tickets[5].topic, "Player report", "A a report is a Player report ticket")
	local copy = tickets[5].report
	check(copy.from == "Scamz" and copy.subject == "Cheap gold" and copy.body == "Pay first" and
		copy.time == NOW - DAY and copy.items[1] == "Bag of Coins" and copy.reason == "Scam",
		"A the report holds a frozen copy of the letter")
	letter.subject = "changed"
	eq(copy.subject, "Cheap gold", "A the copy does not follow the letter")
	check(M.remove(tickets, 3) and not M.find(tickets, 3), "A deleting a ticket removes it")
	eq(#M.tickets_of(tickets, "Alice"), 4, "A the player's own tickets")
end

do
	local player = M.letter(1, "player", "P", "s", "b", {}, NOW)
	check(M.can_report(player), "A a player letter can be reported")
	player.reported = true
	check(not M.can_report(player), "A a letter is reported once")
	check(not M.can_report(M.letter(2, "admin", "x", "s", "b", {}, NOW)),
		"A an admin letter cannot be reported")
	check(not M.can_report(M.letter(3, "npc", "x", "s", "b", {}, NOW)),
		"A an NPC letter cannot be reported")
	eq(M.reply_kind({kind = "player"}), "letter", "A Reply on a player letter writes a letter")
	eq(M.reply_kind({kind = "admin"}), "ticket", "A Reply on an admin letter writes to the admin")
	eq(M.reply_kind({kind = "npc"}), nil, "A an NPC letter has no Reply")
	eq(M.sender_label("admin", "Jan"), "Server Admin", "A admin letters never show the admin's name")
	eq(M.sender_label("npc", "Riding Trainer"), "Riding Trainer", "A an NPC letter keeps its sender")
end

do
	eq(M.clean("  a\27(c@#ff0000)b\tc\1  ", 60, false), "a(c@#ff0000)b c",
		"A control characters and colour escapes are removed")
	eq(M.clean("one\ntwo\r\nthree", 60, false), "one two three", "A a subject has one line")
	eq(M.clean("one\ntwo\r\nthree", 60, true), "one\ntwo\nthree", "A a body keeps its lines")
	eq(M.clean(string.rep("ä", 70), 60, false), string.rep("ä", 60),
		"A truncation counts characters, never cuts one")
	eq(M.text_length("Grüße"), 5, "A text length in characters")
	eq(M.reply_subject("Re: Re: hello"), "Re: hello", "A Reply subject never repeats Re:")
	eq(M.reply_subject("hello"), "Re: hello", "A Reply subject")
	eq(M.quote("a\nb"), "\n\n> a\n> b", "A the quoted text of a reply")
	eq(M.text_length(M.reply_subject(string.rep("x", 60))), 60, "A Reply subject keeps the limit")
end

------------------------------------------------------------------------------
-- B-D. Engine stub
------------------------------------------------------------------------------
local callbacks = {allow = {}, action = {}, join = {}, fields = {}, leave = {},
	die = {}, mods_loaded = {}, faction = {}}
local feed_lines, logs, dropped, formspecs, closed = {}, {}, {}, {}, {}
local nodes = {}
local players = {}
local clock = NOW

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

local mod_storage = {}
local Storage = {}
Storage.__index = Storage
function Storage:get_string(key) return mod_storage[key] or "" end
function Storage:set_string(key, value) mod_storage[key] = value ~= "" and value or nil end
function Storage:get_int(key) return tonumber(mod_storage[key]) or 0 end
function Storage:set_int(key, value) mod_storage[key] = tostring(value) end

core = {
	registered_items = {}, registered_nodes = {}, detached_inventories = {},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_dieplayer = function(f) table.insert(callbacks.die, f) end,
	register_on_player_receive_fields = function(f) table.insert(callbacks.fields, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.mods_loaded, f) end,
	register_craftitem = function(name, def)
		def.groups = def.groups or {}
		core.registered_items[name] = def
	end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do core.registered_items[name][key] = value end
	end,
	create_detached_inventory = function() end,
	register_chatcommand = function() end,
	get_modpath = function(name)
		local dirs = {grug_mail = "PLAYER/grug_mail", grug_inventory = "PLAYER/grug_inventory",
			grug_money = "PLAYER/grug_money"}
		return ROOT .. "/mods/" .. (dirs[name] or name)
	end,
	get_current_modname = function() return current_mod end,
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
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	add_item = function(_, stack) dropped[#dropped + 1] = ItemStack(stack) end,
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
	close_formspec = function(name, formname) closed[#closed + 1] = name .. " " .. formname end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
os.time = function() return clock end
vector = {
	new = function(pos) return {x = pos.x, y = pos.y, z = pos.z} end,
	offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

-- ItemStack double with name, count, wear and metadata that survives
-- to_string (the engine's item string carries all three).
local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
local function meta_string(fields)
	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. fields[key] end
	return table.concat(parts, ";")
end
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({fields = {}}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear
		for key, value in pairs(item.fields or {}) do self.fields[key] = value end
		return self
	end
	local name, count, wear, meta = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)%s*(.*)$")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	self.wear = tonumber(wear) or 0
	for key, value in (meta or ""):gmatch("([^=;]+)=([^;]*)") do self.fields[key] = value end
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_meta() return setmetatable({fields = self.fields}, Meta) end
function Stack:get_description()
	local def = core.registered_items[self.name]
	return self.fields.description or (def and def.description) or self.name
end
Stack.get_short_description = Stack.get_description
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count, self.fields, self.wear = "", 0, {}, 0 end
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken:set_count(n)
	self:set_count(self.count - n)
	return taken
end
local function compatible(a, b)
	return a.name == b.name and a.wear == b.wear and
		meta_string(a.fields) == meta_string(b.fields)
end
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		local fit = math.min(other.count, ItemStack(other):get_stack_max())
		self.name, self.count, self.wear = other.name, fit, other.wear
		self.fields = {}
		for key, value in pairs(other.fields) do self.fields[key] = value end
		other:set_count(other.count - fit)
		return other
	end
	if not compatible(self, other) then return other end
	local fit = math.max(0, math.min(other.count, self:get_stack_max() - self.count))
	self.count = self.count + fit
	other:set_count(other.count - fit)
	return other
end
function Stack:equals(other)
	other = ItemStack(other)
	if self:is_empty() and other:is_empty() then return true end
	return self.count == other.count and compatible(self, other)
end
function Stack:to_string()
	if self:is_empty() then return "" end
	local meta = meta_string(self.fields)
	return self.name .. " " .. self.count .. " " .. self.wear .. (meta ~= "" and " " .. meta or "")
end

local function new_inventory(owner)
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
		return true
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i)
		local l = self.lists[list]
		return ItemStack(l and l[i] or "")
	end
	function inv:set_stack(list, i, stack)
		if not self.lists[list] or i > #self.lists[list] then return false end
		self.lists[list][i] = ItemStack(stack)
		return true
	end
	function inv:get_list(list)
		local l = self.lists[list]
		if not l then return nil end
		local out = {}
		for i = 1, #l do out[i] = ItemStack(l[i]) end
		return out
	end
	function inv:get_lists()
		local out = {}
		for name in pairs(self.lists) do out[name] = self:get_list(name) end
		return out
	end
	function inv:is_empty(list)
		for _, s in ipairs(self.lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	function inv:contains_item() return false end
	function inv:get_location() return {type = "player", name = owner} end
	return inv
end

core.create_detached_inventory = function(_, _, owner) return new_inventory(owner) end

local function new_player(name, faction)
	local inv = new_inventory(name)
	inv:set_size("main", 32)
	local meta = setmetatable({fields = {}}, Meta)
	local player = {inv = inv, meta = meta, online = true, hp = 20,
		pos = {x = 0, y = 10, z = 0}, faction = faction, level = 12}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return self.online end
	function player:get_pos() return self.pos end
	function player:get_hp() return self.hp end
	players[name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
	return player
end

-- The engine's inventory action: every allow callback in registration
-- order, the first number decides (OR with short-circuit); nil from all of
-- them allows the whole count.
local function allowed(player, action, info)
	for _, f in ipairs(callbacks.allow) do
		local result = f(player, action, player.inv, info)
		if result ~= nil then return result end
	end
	return info.count or (info.stack and info.stack:get_count()) or 99
end

------------------------------------------------------------------------------
-- Mod surface: stand-ins for what the real files call.
------------------------------------------------------------------------------
grug_core = {
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind,
			text = text, key = key}
		return true
	end,
	settlement_socket_settlements = function()
		return {{key = "dur_brannoc", display_name = "Dur Brannoc"}}
	end,
	settlement_sockets_at = function(key)
		if key ~= "dur_brannoc" then return {} end
		return {{id = "travel_waypoint", role = "waypoint", pos = {x = 100, y = 10, z = 100}}}
	end,
}
grug_classes = {
	get_class = function(player) return player.class_id or "warrior" end,
	get_race = function() return "dwarf" end,
}
grug_xp = {get_level = function(player) return player.level end}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function(f) table.insert(callbacks.faction, f) end,
}
grug_gear = {initialize_weapon_tooltip = function() return false end}
grug_abilities = {is_unlocked = function() return true end}
grug_mounts = {owns_tier = function() return true end}
grug_housing, grug_skills = {}, {}
local mail_counts = {}
grug_map = {minimap = {set_mail_count = function(name, n) mail_counts[name] = n end}}

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("t:dirt", {description = "Dirt"})
item("t:ingot", {description = "Iron Ingot"})
item("t:axe", {description = "Bronze Axe", stack_max = 1})
item("t:claim", {description = "Claim Stone", stack_max = 1, groups = {grug_soulbound = 1}})
item("grug_abilities:strike", {description = "Strike", stack_max = 1,
	groups = {grug_bound_skill = 1, grug_ability = 1}})
item("grug_mounts:wolf", {description = "Wolf", stack_max = 1, _grug_mount_tier = "t15",
	groups = {grug_bound_skill = 1}})
item("grug_money:bag_of_coins", {description = "Bag of Coins", stack_max = 1})

current_mod = "grug_inventory"
grug_inventory = {refresh = function() end}
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/inbox.lua")
grug_inventory.GAME_VERSION = "0.48.0"
grug_inventory.UI = {frame_w = 13.5, frame_h = 13.673}
grug_inventory.SCROLL_FIELDS = {short = "grug_inv_scroll_short"}
grug_inventory.inventory_view = function() return "<inventory view>" end
grug_inventory.wrap_text = function(text) return text end
current_mod = "grug_skills"
dofile(ROOT .. "/mods/PLAYER/grug_skills/bound_items.lua")
current_mod = "grug_housing"
dofile(ROOT .. "/mods/PLAYER/grug_housing/soulbound.lua")
current_mod = "grug_money"
dofile(ROOT .. "/mods/PLAYER/grug_money/init.lua")
current_mod = "grug_mail"
-- The Admin Mail tab (admin.lua, lane ADMIN) registers an sfinv page; its
-- own fixture is tools/r48_admin.
sfinv = {register_page = function() end}
dofile(ROOT .. "/mods/PLAYER/grug_mail/init.lua")
for _, f in ipairs(callbacks.mods_loaded) do f() end

local ATTACH = grug_mail.ATTACH_LIST
local MAILBOX = {x = 102, y = 10, z = 100}
nodes["102,10,100"] = "grug_mapgen:mailbox"

local alice = new_player("Alice", "accord")
local brakka = new_player("Brakka", "accord")
local gruk = new_player("Gruk", "throng")
grug_money.set(alice, 1000)

local function letters_of(name) return grug_mail.store.box(name).letters end
local function fill(player, list, from, to, itemstring)
	for index = from, to do player.inv:set_stack(list, index, ItemStack(itemstring)) end
end
local function census(player)
	local counts = {}
	for _, list in pairs(player.inv.lists) do
		for _, stack in ipairs(list) do
			if not stack:is_empty() then counts[stack.name] = (counts[stack.name] or 0) + stack.count end
		end
	end
	return counts
end
local function same(a, b)
	for key, value in pairs(a) do if b[key] ~= value then return false end end
	for key, value in pairs(b) do if a[key] ~= value then return false end end
	return true
end

------------------------------------------------------------------------------
-- B. Sending
------------------------------------------------------------------------------
eq(alice.inv:get_size(ATTACH), 4, "B the attachment list has four slots at join")
check(grug_inventory.carried_lists(alice.inv)[2] == nil and
	grug_inventory.carried_lists(alice.inv)[1] == "main",
	"B the attachment list is not a carried list")

do -- the guards: nothing bound or soulbound enters the attachment list
	alice.inv:set_stack("main", 9, ItemStack("t:claim"))
	alice.inv:set_stack("main", 1, ItemStack("grug_abilities:strike"))
	alice.inv:set_stack("main", 10, ItemStack("grug_mounts:wolf 1 0 grug_mounts:owner=Alice"))
	alice.inv:set_stack("main", 11, ItemStack("t:dirt 5"))
	local function move(from_index)
		return allowed(alice, "move", {from_list = "main", from_index = from_index,
			to_list = ATTACH, to_index = 1, count = 1})
	end
	eq(move(9), 0, "B a soulbound Claim Stone cannot be moved into an attachment slot")
	eq(move(1), 0, "B a skill cannot be moved into an attachment slot")
	eq(move(10), 0, "B a mount item cannot be moved into an attachment slot")
	check(move(11) > 0, "B an ordinary stack can be moved into an attachment slot")
	for _, name in ipairs({"t:claim", "grug_abilities:strike", "grug_mounts:wolf"}) do
		eq(allowed(alice, "put", {listname = ATTACH, index = 1, stack = ItemStack(name)}), 0,
			"B " .. name .. " cannot be put into an attachment slot")
	end
	for index = 1, 32 do alice.inv:set_stack("main", index, ItemStack("")) end
end

do -- money and two stacks leave in one step
	alice.inv:set_stack(ATTACH, 1, ItemStack("t:ingot 12"))
	alice.inv:set_stack(ATTACH, 3, ItemStack("t:axe"))
	local ok, message = grug_mail.send_letter(alice, "brakka", "Your axe", "As promised.")
	check(ok and message == "Letter sent to Brakka (65c).", "B sending with two stacks: " ..
		tostring(message))
	eq(grug_money.get(alice), 935, "B 65c postage taken")
	check(alice.inv:is_empty(ATTACH), "B the attachment slots are empty")
	local letter = letters_of("Brakka")[1]
	check(letter and letter.kind == "player" and letter.from == "Alice" and
		#letter.items == 2 and ItemStack(letter.items[1]):get_count() == 12,
		"B the letter holds both stacks")
	eq(mail_counts.Brakka, 1, "B the recipient's mail icon shows one")
	local line = feed_lines[#feed_lines]
	check(line.name == "Brakka" and line.text == "New letter from Alice." and line.key == "mail",
		"B an online recipient gets the feed notice")
end

do -- a changed slot refuses with nothing lost
	alice.inv:set_stack(ATTACH, 2, ItemStack("t:dirt 10"))
	local quote = {}
	for index, stack in ipairs(grug_mail.attachments(alice)) do quote[index] = stack:to_string() end
	alice.inv:set_stack(ATTACH, 4, ItemStack("t:dirt 3"))
	local before, money, count = census(alice), grug_money.get(alice), #letters_of("Brakka")
	local ok, message = grug_mail.send_letter(alice, "Brakka", "More dirt", "", quote)
	check(not ok and message:find("attachments changed", 1, true),
		"B a slot changed since the quote: refused")
	check(same(before, census(alice)) and grug_money.get(alice) == money and
		#letters_of("Brakka") == count, "B the refusal loses nothing and sends nothing")
	quote[4] = "t:dirt 3"
	ok = grug_mail.send_letter(alice, "Brakka", "More dirt", "", quote)
	check(ok and grug_money.get(alice) == money - 65, "B the fresh quote sends")
end

do -- refusals before anything is taken
	alice.inv:set_stack(ATTACH, 1, ItemStack("t:dirt 7"))
	local before, money = census(alice), grug_money.get(alice)
	local ok, message = grug_mail.send_letter(alice, "Gruk", "Hi", "")
	check(not ok and message == "There is no player called Gruk in your faction.",
		"B a player of the other faction is refused like an unknown name")
	ok, message = grug_mail.send_letter(alice, "Nobody", "Hi", "")
	check(not ok and message == "There is no player called Nobody in your faction.",
		"B an unknown name is refused")
	ok, message = grug_mail.send_letter(alice, "Alice", "Hi", "")
	check(not ok and message == "You cannot write to yourself.", "B no letter to oneself")
	ok, message = grug_mail.send_letter(alice, "Brakka", "  ", "")
	check(not ok and message == "Write a subject.", "B a subject is needed")
	grug_money.set(alice, 20)
	ok, message = grug_mail.send_letter(alice, "Brakka", "Hi", "")
	check(not ok and message:find("not have enough money", 1, true), "B not enough money")
	check(same(before, census(alice)) and grug_money.get(alice) == 20,
		"B the refusals take nothing")
	grug_money.set(alice, money)
end

do -- closing returns the stacks; what does not fit stays
	alice.inv:set_stack(ATTACH, 2, ItemStack("t:ingot 4"))
	eq(grug_mail.return_attachments(alice), 0, "B closing: every stack fits back")
	check(alice.inv:is_empty(ATTACH) and census(alice)["t:ingot"] == 4 and
		census(alice)["t:dirt"] == 7, "B the stacks are back in the inventory")
	for index = 1, 32 do alice.inv:set_stack("main", index, ItemStack("")) end
	fill(alice, "main", 1, 31, "t:axe")
	alice.inv:set_stack(ATTACH, 1, ItemStack("t:ingot 4"))
	alice.inv:set_stack(ATTACH, 2, ItemStack("t:dirt 90"))
	eq(grug_mail.return_attachments(alice), 1, "B closing with one free slot")
	check(alice.inv:get_stack(ATTACH, 1):is_empty() and
		alice.inv:get_stack(ATTACH, 2):equals(ItemStack("t:dirt 90")),
		"B the stack that fits goes back, the leftover stays in its slot")
	local total = census(alice)
	check(total["t:dirt"] == 90 and total["t:ingot"] == 4 and total["t:axe"] == 31,
		"B nothing lost or duplicated")
	for index = 1, 32 do alice.inv:set_stack("main", index, ItemStack("")) end
	for index = 1, 4 do alice.inv:set_stack(ATTACH, index, ItemStack("")) end
end

do -- item meta survives; Take all
	local blade = ItemStack("t:axe 1 1234 grug_quality=3;grug_enchant=str;grug_crown=1")
	alice.inv:set_stack(ATTACH, 1, ItemStack(blade))
	local ok = grug_mail.send_letter(alice, "Brakka", "A crowned axe", "")
	check(ok, "B a crowned, enchanted, worn axe is sent")
	local letter = letters_of("Brakka")[1]
	fill(brakka, "main", 1, 32, "t:axe")
	local before = census(brakka)
	local taken, message = grug_mail.take_all(brakka, letter.id)
	check(not taken and message:find("Not enough room", 1, true),
		"B Take all refuses without room")
	check(same(before, census(brakka)) and #letters_of("Brakka")[1].items == 1,
		"B the items stay in the letter")
	brakka.inv:set_stack("main", 20, ItemStack(""))
	taken = grug_mail.take_all(brakka, letter.id)
	check(taken and brakka.inv:get_stack("main", 20):equals(blade),
		"B the axe arrives identical: quality, enchant, crown, wear")
	eq(#letters_of("Brakka")[1].items, 0, "B the letter is empty after Take all")
	for index = 1, 32 do brakka.inv:set_stack("main", index, ItemStack("")) end
end

do -- the 50-letter limit; system mail beyond it
	local box = grug_mail.store.box("Gruk")
	for i = 1, 50 do M.deliver(box, M.letter(1000 + i, "player", "Zug", "s", "b", {}, clock)) end
	grug_mail.store.save_box("Gruk", box)
	local orc = new_player("Zug", "throng")
	grug_money.set(orc, 500)
	local ok, message = grug_mail.send_letter(orc, "Gruk", "Hi", "")
	check(not ok and message == "Gruk's mailbox is full.", "B a full mailbox refuses player mail")
	eq(grug_money.get(orc), 500, "B the refusal costs nothing")
	ok = grug_mail.send_system("Gruk", "npc", "Riding Trainer", "Time for a mount", "Visit me.")
	check(ok and letters_of("Gruk")[1].from == "Riding Trainer", "B system mail arrives beyond the limit")
end

do -- send_system with stacks (round plan §3.2)
	local stacks = {"t:dirt 99", "t:ingot 30", "t:axe 1 77 grug_quality=2", "t:dirt 5"}
	local ok, id = grug_mail.send_system("Brakka", "npc", "Lost and Found",
		"Your bags got smaller", "Attached.", stacks)
	check(ok and type(id) == "number", "B send_system with four stacks")
	local letter = letters_of("Brakka")[1]
	check(letter.id == id and #letter.items == 4 and letter.kind == "npc" and
		ItemStack(letter.items[3]):equals(ItemStack("t:axe 1 77 grug_quality=2")),
		"B the stacks are stored like attachments, meta included")
	check(grug_mail.take_all(brakka, id), "B system attachments are taken like player ones")
	eq(census(brakka)["t:dirt"], 104, "B every stack arrived")
	local refused, reason = grug_mail.send_system("Brakka", "npc", "x", "s", "b",
		{"t:dirt", "t:dirt", "t:dirt", "t:dirt", "t:dirt"})
	check(refused == false and type(reason) == "string", "B five stacks are refused: false, reason")
	check(id ~= nil and ok == true, "B success returns true and the id, never nil")
	refused, reason = grug_mail.send_system("Nobody", "npc", "x", "s", "b", {"t:dirt"})
	check(refused == false and type(reason) == "string" and #letters_of("Nobody") == 0,
		"B an unknown recipient returns false, reason and stores nothing")
	ok = grug_mail.send_system("Brakka", "admin", "Jan", "Hello", "Text")
	check(ok and letters_of("Brakka")[1].from == "Server Admin",
		"B an admin letter shows Server Admin, never the admin's name")
	check(not grug_mail.send_system("Nobody", "admin", "x", "s", "b"), "B unknown recipient refused")
	check(not grug_mail.send_system("Brakka", "mob", "x", "s", "b"), "B unknown kind refused")
	-- An offline character still gets system mail (the migration at join).
	brakka.online = false
	ok = grug_mail.send_system("Brakka", "npc", "Lost and Found", "s", "b", {"t:dirt 1"})
	check(ok, "B system mail reaches an offline character")
	brakka.online = true
end

------------------------------------------------------------------------------
-- C. Tickets, reports, answers, broadcasts
------------------------------------------------------------------------------
do
	local ok, message, id = grug_mail.send_ticket(alice, "Bug report", "Waystone",
		"Nothing happens.", "Mailbox in Dur Brannoc")
	check(ok and id, "C a message to the admin: " .. tostring(message))
	local ticket = grug_mail.ticket(id)
	check(ticket.state == "open" and ticket.mailbox == "Mailbox in Dur Brannoc" and
		ticket.version == "0.48.0" and ticket.level == 12 and ticket.faction == "accord" and
		ticket.race == "dwarf" and ticket.class == "warrior" and ticket.pos.y == 10,
		"C the ticket holds the header the admin sees")
	local logged = false
	for _, line in ipairs(logs) do
		logged = logged or (line:find("ticket #" .. id, 1, true) and line:find("Nothing happens.", 1, true))
	end
	check(logged, "C every message to the admin is logged")
	check(not grug_mail.send_ticket(alice, "Gossip", "x", "y"), "C an unknown topic is refused")
	for i = 1, 4 do grug_mail.send_ticket(alice, "Question", "q" .. i, "?") end
	ok, message = grug_mail.send_ticket(alice, "Question", "q5", "?")
	check(not ok and message:find("5 open", 1, true), "C the 5-open cap")
	-- A report counts against the cap too.
	local letter = letters_of("Brakka")
	local player_letter
	for _, entry in ipairs(letter) do if entry.kind == "player" then player_letter = entry end end
	check(grug_mail.close_ticket(id, "Jan"), "C close without an answer")
	check(not grug_mail.close_ticket(id, "Jan"), "C closing twice is refused")
	ok = grug_mail.report_letter(brakka, player_letter.id, "Scam", "fake", "Mailbox in Dur Brannoc")
	check(ok, "C a player letter is reported")
	local report
	for _, entry in ipairs(grug_mail.tickets()) do if entry.report then report = entry end end
	check(report and report.from == "Brakka" and report.report.from == "Alice" and
		report.report.subject == player_letter.subject and report.report.reason == "Scam" and
		report.topic == "Player report", "C the report ticket holds the letter's copy")
	check(not grug_mail.report_letter(brakka, player_letter.id, "Scam", "", "x"),
		"C a letter is reported once")
	local admin_letter = letters_of("Brakka")[2]
	check(admin_letter.kind == "admin" and
		not grug_mail.report_letter(brakka, admin_letter.id, "Spam", "", "x"),
		"C an admin letter cannot be reported")
	-- An answer: an admin letter "Re: ..." and the ticket closes answered.
	local open = M.find(grug_mail.tickets(), report.id)
	ok = grug_mail.answer_ticket(report.id, "Jan", "We looked into it.")
	local answered = grug_mail.ticket(report.id)
	check(ok and answered.state == "closed" and answered.answered and answered.closed_by == "Jan",
		"C answering closes the ticket as answered")
	local reply = letters_of("Brakka")[1]
	check(reply.kind == "admin" and reply.from == "Server Admin" and
		reply.subject == M.reply_subject(open.subject) and reply.body == "We looked into it.",
		"C the answer arrives as an admin letter Re: subject")
	check(grug_mail.delete_ticket(report.id, "Brakka") and not grug_mail.ticket(report.id),
		"C deleting removes the ticket for everyone")
	-- Broadcasts: stored once, read per player.
	local before = grug_mail.unread_count("Alice")
	local bid = grug_mail.send_broadcast("Server restart", "Tonight at 8.", "Jan")
	eq(#grug_mail.broadcasts(), 1, "C a broadcast is stored once")
	eq(grug_mail.unread_count("Alice"), before + 1, "C it counts as unread for every player")
	eq(mail_counts.Alice, before + 1, "C every online player's icon updates")
	grug_mail.read_broadcast(alice, bid)
	eq(grug_mail.unread_count("Alice"), before, "C reading marks it for that player")
	check(grug_mail.unread_count("Gruk") >= 1 and not grug_mail.store.read_set(gruk)[bid],
		"C another player's read state is untouched")
	-- Expiry over the stores.
	clock = clock + 30 * DAY
	eq(#grug_mail.broadcasts(), 0, "C a broadcast expires after 30 days")
	eq(#letters_of("Brakka"), 0, "C letters expire after 30 days, attachments too")
	eq(#grug_mail.tickets(), 0, "C tickets expire after 30 days")
	clock = clock - 30 * DAY
end

------------------------------------------------------------------------------
-- D. The window
------------------------------------------------------------------------------
local function send_fields(player, fields)
	local form = formspecs[player:get_player_name()]
	for _, f in ipairs(callbacks.fields) do
		if f(player, form and form.formname or "", fields) then return end
	end
end
-- The name a Send button has in the form shown now ("write_send_<n>").
local function button(player, prefix)
	return formspecs[player:get_player_name()].text:match("(" .. prefix .. "_%d+);")
end

do
	local opened = {}
	grug_mail.register_on_mailbox_open(function(player, pos)
		opened[#opened + 1] = player:get_player_name() .. "@" .. pos.x
	end)
	alice.pos = {x = 100, y = 10, z = 103}
	check(not grug_mail.open_mailbox(alice, {x = 5, y = 5, z = 5}),
		"D no window at a position without a mailbox")
	check(grug_mail.open_mailbox(alice, MAILBOX), "D the window opens at a mailbox")
	eq(opened[#opened], "Alice@102", "D the mailbox-open callbacks ran")
	eq(grug_mail.mailbox_label(MAILBOX), "Dur Brannoc", "D the mailbox takes the settlement's name")
	local session = grug_mail.session("Alice")
	check(formspecs.Alice.text:find("Mailbox in Dur Brannoc", 1, true),
		"D the window names its mailbox")
	-- Letters for the tabs: a player letter with items, an admin, an NPC letter.
	grug_mail.send_system("Alice", "admin", "x", "Welcome", "Hello.")
	grug_mail.send_system("Alice", "npc", "Riding Trainer", "Mount", "Come.", {"t:dirt 2"})
	brakka.inv:set_stack(ATTACH, 1, ItemStack("t:ingot 3"))
	grug_money.set(brakka, 100)
	grug_mail.send_letter(brakka, "Alice", "Ingots", "For you.")
	grug_mail.send_broadcast("News", "Read me.", "Jan")
	for tab = 1, 4 do
		send_fields(alice, {grug_mail_tab = tostring(tab)})
		check(formspecs.Alice.text:find("formspec_version[6]", 1, true) ~= nil,
			"D tab " .. tab .. " builds")
	end
	send_fields(alice, {grug_mail_tab = "1"})
	check(formspecs.Alice.text:find("Letters (3)", 1, true), "D the Letters tab counts unread")
	check(formspecs.Alice.text:find("Announcements (1)", 1, true), "D the Announcements tab counts unread")
	send_fields(alice, {letters = "CHG:1:5"})
	local first = letters_of("Alice")[1]
	check(first.read and session.selected.letters == first.id, "D clicking a letter opens it and marks it read")
	check(formspecs.Alice.text:find("Take all", 1, true) and formspecs.Alice.text:find("report", 1, true),
		"D a player letter shows Take all and Report")
	send_fields(alice, {report = "Report"})
	check(formspecs.Alice.text:find("Really report this letter\nfrom Brakka?", 1, true),
		"D Report asks first")
	send_fields(alice, {report_cancel = "Cancel"})
	send_fields(alice, {delete = "Delete"})
	check(session.dialog == "delete" and formspecs.Alice.text:find("still holds\nits attachments", 1, true),
		"D deleting a letter with attachments asks first")
	send_fields(alice, {delete_cancel = "Cancel"})
	send_fields(alice, {letters = "CHG:2:5"})
	check(formspecs.Alice.text:find("cannot be answered", 1, true), "D an NPC letter has no Reply")
	send_fields(alice, {letters = "CHG:3:5"})
	check(formspecs.Alice.text:find("Sent by the server administration", 1, true),
		"D an admin letter carries the banner")
	send_fields(alice, {reply = "Reply"})
	check(session.tab == "admin" and session.admin.subject == "Re: Welcome",
		"D Reply on an admin letter writes to the admin")
	send_fields(alice, {grug_mail_tab = "1"})
	send_fields(alice, {letters = "CHG:1:5"})
	send_fields(alice, {reply = "Reply"})
	check(session.tab == "write" and session.draft.to == "Brakka" and
		session.draft.subject == "Re: Ingots" and session.draft.body:find("> For you.", 1, true),
		"D Reply on a player letter opens Write with the quote")
	-- Write: the quote, a changed slot, the second Send.
	local money = grug_money.get(alice)
	local brakka_letters = #letters_of("Brakka")
	alice.inv:set_stack(ATTACH, 1, ItemStack("t:dirt 4"))
	local first = button(alice, "write_send")
	send_fields(alice, {mail_to = "Brakka", mail_subject = "Re: Ingots", mail_body = "Thanks!",
		[first] = "Send (5c)"})
	check(session.status and session.status:find("attachments changed", 1, true) and
		grug_money.get(alice) == money, "D a slot filled after the quote: Send refuses")
	check(formspecs.Alice.text:find("Send (35c)", 1, true), "D the new postage shows")
	local second = button(alice, "write_send")
	check(second ~= first, "D every draw names its Send button anew")
	send_fields(alice, {mail_to = "Brakka", mail_subject = "Re: Ingots", mail_body = "Thanks!",
		[first] = "Send (5c)"})
	check(grug_money.get(alice) == money and #letters_of("Brakka") == brakka_letters and
		not alice.inv:is_empty(ATTACH),
		"D a quick second click from the refused form charges and sends nothing")
	send_fields(alice, {mail_to = "Brakka", mail_subject = "Re: Ingots", mail_body = "Thanks!",
		[button(alice, "write_send")] = "Send (35c)"})
	check(session.status_ok and grug_money.get(alice) == money - 35 and alice.inv:is_empty(ATTACH),
		"D Send from the latest form pays the shown postage")
	eq(letters_of("Brakka")[1].body, "Thanks!", "D the typed text was sent")
	local sent = button(alice, "write_send")
	send_fields(alice, {mail_to = "Brakka", mail_subject = "Re: Ingots", mail_body = "Thanks!",
		[second] = "Send (35c)"})
	check(grug_money.get(alice) == money - 35 and #letters_of("Brakka") == brakka_letters + 1 and
		session.draft.to == "" and session.draft.body == "",
		"D a double click on Send sends one letter; the stale fields are not kept")
	check(button(alice, "write_send") ~= sent, "D the stale click redraws the window")
	-- The shift-click rings with a bag: main and the bag both lead to the
	-- attachment slots, the attachment slots to the inbox (the engine takes
	-- the entry after the first one naming the source list).
	alice.inv:set_size("grug_bag1_content", 8)
	send_fields(alice, {grug_mail_tab = "3"})
	local ring = {}
	for list in formspecs.Alice.text:gmatch("listring%[current_player;([^%]]+)%]") do
		ring[#ring + 1] = list
	end
	local function next_of(list)
		for index, entry in ipairs(ring) do
			if entry == list then return ring[index % #ring + 1] end
		end
	end
	check(next_of("main") == ATTACH and next_of("grug_bag1_content") == ATTACH and
		next_of(ATTACH) == grug_inventory.INBOX_LIST,
		"D shift-click: main and the bag into the attachment slots, the slots out via the inbox")
	alice.inv:set_size("grug_bag1_content", 0)
	-- The inventory view's scrollbar: its value is kept, a pure scroll
	-- event sends nothing.
	local shown = formspecs.Alice.text
	formspecs.Alice.text = "unchanged"
	send_fields(alice, {grug_inv_scroll_short = "CHG:20"})
	check(formspecs.Alice.text == "unchanged" and session.inv.grug_inv_scroll.short == 20,
		"D a scroll event keeps the value and sends nothing")
	formspecs.Alice.text = shown
	-- To the admin through the window.
	send_fields(alice, {grug_mail_tab = "4"})
	local admin_send = button(alice, "admin_send")
	send_fields(alice, {admin_topic = "2", admin_subject = "Lag", admin_body = "Slow.",
		[admin_send] = "Send (free)"})
	send_fields(alice, {admin_topic = "2", admin_subject = "Lag", admin_body = "Slow.",
		[admin_send] = "Send (free)"})
	local own = M.tickets_of(grug_mail.tickets(), "Alice")
	eq(#own, 1, "D a double click on Send (free) makes one ticket")
	check(own[1] and own[1].topic == "Bug report" and own[1].mailbox == "Mailbox in Dur Brannoc",
		"D the window sends a ticket with topic and mailbox")
	send_fields(alice, {tickets = "CHG:1:1"})
	send_fields(alice, {ticket_delete = "Delete"})
	check(not grug_mail.ticket(own[1].id), "D the player deletes their own ticket")
	-- Closing returns the attachments; reach ends the session.
	alice.inv:set_stack(ATTACH, 2, ItemStack("t:ingot 2"))
	send_fields(alice, {quit = "true"})
	check(alice.inv:is_empty(ATTACH) and not grug_mail.session("Alice"),
		"D closing the window gives the attachments back")
	grug_mail.open_mailbox(alice, MAILBOX)
	alice.pos = {x = 120, y = 10, z = 100}
	alice.inv:set_stack(ATTACH, 1, ItemStack("t:ingot 1"))
	send_fields(alice, {grug_mail_tab = "2"})
	check(not grug_mail.session("Alice") and #closed > 0 and alice.inv:is_empty(ATTACH),
		"D walking away closes the window and returns the attachments")
	nodes["102,10,100"] = nil
	alice.pos = {x = 100, y = 10, z = 103}
	check(not grug_mail.open_mailbox(alice, MAILBOX), "D a removed mailbox does not open")
end

if failures > 0 then
	error(("R48 MAIL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R48 MAIL PORTABLE PASS checks=%d"):format(checks))
