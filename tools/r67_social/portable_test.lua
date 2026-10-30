-- Round 67 lane SOCIAL portable test (LuaJIT): the Social tab, the
-- invitation box in the HUD and the favourites.
--
--   luajit tools/r67_social/portable_test.lua [repo]
--
-- Loads the REAL grug_parties (init.lua, which loads ui.lua and hud.lua),
-- the vendored sfinv api.lua, grug_core's ui.lua, hud_layout.lua and
-- status_icons.lua on a fake engine with a clock, core.after and the
-- globalsteps; factions, classes, races and levels are stubs. Checks:
--   S  the player list's order: own faction, then the other, then players
--      without a faction; favourites first, then by name (case-insensitive);
--      the own row marked "(you)" without star or button; the race icons.
--   I  the invite button: shown for an eligible same-faction player of a
--      viewer without a party and of a leader; never for an enemy, a player
--      in a party, one with invitations off, one already invited, the own
--      row, and never for a party member or the leader of a full party.
--   B  the party box: "0 Pending Invitations" with its hint, "1 Pending
--      Invitation", "2 Pending Invitations", "Current Party (n/10)" with
--      the member table; accepting switches it at once.
--   H  the HUD box: shown with the inviter and the seconds, "+N more",
--      seconds kept current by the poll, independent of the Party HUD
--      switch, hidden on expiry, decline and accept; a party forming clears
--      the inviter's own invitations too.
--   F  favourites in player meta: the star toggles, an offline name cannot
--      be added, the order follows.
--   C  the coalesced refresh: a burst in one step gives one send, a change
--      inside the gap one owed send when it ends, nothing for another page;
--      a scrollbar move sends nothing and holds sends for QUIET_US; the
--      scroll value is kept and echoed; an expiry re-sends the inviter.
-- and prints the tab's formspec bytes with 1, 10 and 50 listed players (a
-- comparison, not a target).

local repo = arg and arg[1] or "."
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
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. ("%q"):format(part) .. ")")
end

--
-- Fake engine
--

local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local parts = {}
		local keys = {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local us = 1000000
local steps, joins, leaves, receive, mods_loaded = {}, {}, {}, {}, {}
local jobs = {}
local players, joined, windows = {}, {}, {}
local storage = {}
core = {
	formspec_escape = function(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
	end,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return "grug_parties" end,
	get_mod_storage = function()
		return {get_string = function(_, key) return storage[key] or "" end,
			set_string = function(_, key, value) storage[key] = value end}
	end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local fn = loadstring(text)
		return fn and fn() or nil
	end,
	get_us_time = function() return us end,
	after = function(delay, fn, ...)
		jobs[#jobs + 1] = {at = us + delay * 1000000, fn = fn, args = {...}}
	end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_player_receive_fields = function(fn) receive[#receive + 1] = fn end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	get_player_by_name = function(name) return joined[name] and players[name] or nil end,
	get_connected_players = function()
		local list = {}
		for _, name in ipairs(joined.order or {}) do
			if joined[name] then list[#list + 1] = players[name] end
		end
		return list
	end,
	get_player_window_information = function(name) return windows[name] end,
	chat_send_player = function() end,
	log = function() end,
	explode_textlist_event = function(value)
		local kind, index = value:match("^(%u+):(%d+)$")
		return {type = kind or "INV", index = tonumber(index) or 0}
	end,
	explode_table_event = function(value)
		local kind, row, column = value:match("^(%u+):(%d+):(%d+)$")
		return {type = kind or "INV", row = tonumber(row) or 0, column = tonumber(column) or 0}
	end,
}
minetest = core
dump = function(value) return tostring(value) end

-- Runs the core.after jobs due now (in their order), as the next step does.
local function run_jobs()
	local ran = true
	while ran do
		ran = false
		table.sort(jobs, function(a, b) return a.at < b.at end)
		for index, job in ipairs(jobs) do
			if job.at <= us then
				table.remove(jobs, index)
				job.fn(unpack(job.args))
				ran = true
				break
			end
		end
	end
end
-- Advances the clock by `seconds` in 0.1 s server steps.
local function step(seconds)
	local t = 0
	while t < seconds - 1e-9 do
		t = t + 0.1
		us = us + 100000
		for _, fn in ipairs(steps) do fn(0.1) end
		run_jobs()
	end
end

local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:set_int(key, value) self.fields[key] = value ~= 0 and tostring(value) or nil end

local function make_player(name, faction, class, race, level)
	local p = {name = name, faction = faction, class = class, race = race, level = level or 10,
		meta = setmetatable({fields = {}}, Meta), huds = {}, next_id = 0, sent = 0}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_meta() return self.meta end
	function p:get_hp() return 20 end
	function p:get_properties() return {hp_max = 20} end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, key, value) self.huds[id][key] = value end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:set_inventory_formspec(fs)
		self.sent = self.sent + 1
		self.formspec = fs
	end
	players[name] = p
	return p
end
local function join(p)
	joined[p.name] = true
	joined.order = joined.order or {}
	joined.order[#joined.order + 1] = p.name
	windows[p.name] = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	for _, fn in ipairs(joins) do fn(p) end
end
local function leave(p)
	for _, fn in ipairs(leaves) do fn(p) end
	joined[p.name] = nil
	for i, name in ipairs(joined.order) do
		if name == p.name then table.remove(joined.order, i) break end
	end
end

--
-- Neighbours
--

local level_callbacks, class_callbacks, race_callbacks, faction_callbacks = {}, {}, {}, {}
grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/status_icons.lua")
grug_sounds = {CLICK_STYLE = ""}
grug_factions = {
	get_faction = function(player) return player.faction end,
	display_name = function(id) return id == "accord" and "The Accord" or "The Throng" end,
	register_on_faction_chosen = function(fn) faction_callbacks[#faction_callbacks + 1] = fn end,
}
grug_xp = {
	get_level = function(player) return player and player.level or 1 end,
	register_on_level_change = function(fn) level_callbacks[#level_callbacks + 1] = fn end,
}
grug_classes = {
	registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"},
		priest = {name = "Priest"}, scout = {name = "Scout"}},
	registered_races = {human = {name = "Human"}, dwarf = {name = "Dwarf"},
		orc = {name = "Orc"}, undead = {name = "Undead"}},
	get_class = function(player) return player.class end,
	get_race = function(player) return player.race end,
	register_on_class_chosen = function(fn) class_callbacks[#class_callbacks + 1] = fn end,
	register_on_race_chosen = function(fn) race_callbacks[#race_callbacks + 1] = fn end,
}
dofile(repo .. "/mods/BASE/sfinv/api.lua")
sfinv.register_page("home", {get = function() return "home" end})
sfinv.get_homepage_name = function() return "home" end
-- The page's body alone; tools/r44_pp checks it inside the real frame.
sfinv.make_formspec = function(_, _, content) return content end
dofile(repo .. "/mods/PLAYER/grug_parties/init.lua")
for _, fn in ipairs(mods_loaded) do fn() end
local PAGE = grug_parties.PAGE
eq(sfinv.pages[PAGE] and sfinv.pages[PAGE].title, "Social", "T the tab is called Social")

local function submit(p, fields)
	for _, fn in ipairs(receive) do
		if fn(p, "", fields) then return true end
	end
end
local function open_social(p)
	sfinv.set_page(p, PAGE)
	run_jobs()
	return p.formspec
end
local function resend(p)
	sfinv.set_player_inventory_formspec(p, sfinv.contexts[p.name])
	return p.formspec
end
-- The list's rows in drawn order: the names of the scroll area's labels.
local function row_names(fs)
	local area = fs:match("scroll_container%[[^%]]*%](.*)scroll_container_end%[%]") or ""
	local names = {}
	for name in area:gmatch("label%[0%.65,[%d.]+;([^%]]*)%]") do
		names[#names + 1] = name
	end
	return table.concat(names, " ")
end
local function invite_button(fs, name)
	return fs:find(";grug_social_inv_" .. name .. ";Invite]", 1, true) ~= nil
end
local function star_button(fs, name)
	return fs:find(";grug_social_fav_" .. name .. ";", 1, true) ~= nil
end

-- The cast: alice views; The Accord: Carl, bob, anna, zed, iris (invites
-- off); The Throng: dave, eve; newbie has no faction yet.
local alice = make_player("alice", "accord", "warrior", "human", 12)
local bob = make_player("bob", "accord", "mage", "dwarf", 11)
local carl = make_player("Carl", "accord", "priest", "human", 30)
local anna = make_player("anna", "accord", "scout", "dwarf", 7)
local zed = make_player("zed", "accord", "mage", "human", 60)
local iris = make_player("iris", "accord", "mage", "human", 20)
local dave = make_player("dave", "throng", "warrior", "orc", 40)
local eve = make_player("eve", "throng", "priest", "undead", 41)
local newbie = make_player("newbie", nil, nil, nil, 1)
for _, p in ipairs({alice, bob, carl, anna, zed, iris, dave, eve, newbie}) do join(p) end
grug_parties.set_invitations_enabled(iris, false)
run_jobs()

--
-- S. The order
--

local fs = open_social(alice)
eq(row_names(fs), "alice (you) anna bob Carl iris zed dave eve newbie",
	"S own faction, then the other, then no faction; by name, case-insensitive")
has(fs, "Online Players (9)", "S the heading counts every online player")
check(not star_button(fs, "alice") and not invite_button(fs, "alice"),
	"S the own row has no star and no button")
has(fs, "box[0,0.00;8.95,0.54;#bba06230]", "S the own row is highlighted")
has(fs, "image[0.10,0.06;0.42,0.42;grug_inventory_faction_accord.png]", "S the faction icon")
has(fs, "tooltip[0.10,0.06;0.42,0.42;The Accord]", "S the faction's word as tooltip")
has(fs, "image[4.60,0.06;0.42,0.42;grug_class_warrior.png]tooltip[4.60,0.06;0.42,0.42;Warrior]",
	"S the class icon with its word")
has(fs, "image[5.10,0.06;0.42,0.42;" .. core.formspec_escape(grug_core.status_icons.race_icon("human")) ..
	"]tooltip[5.10,0.06;0.42,0.42;Human]", "S the race icon with its word")
has(fs, "label[5.7,0.27;Lv 12]", "S the level")
local races = 0
for _, id in ipairs({"human", "dwarf", "elf", "orc", "troll", "undead"}) do
	if grug_core.status_icons.race_icon(id) ~= "" then races = races + 1 end
end
eq(races, 6, "S one race icon per race")
eq(grug_core.status_icons.race_icon("nobody"), "", "S no icon for an unknown race")

--
-- F. Favourites
--

submit(alice, {grug_social_fav_zed = "☆"})
eq(alice.meta.fields[grug_parties.FAVORITES_KEY] and
	core.deserialize(alice.meta.fields[grug_parties.FAVORITES_KEY])[1], "zed",
	"F the star stores the name in player meta")
submit(alice, {grug_social_fav_eve = "☆"})
fs = alice.formspec
eq(row_names(fs), "zed alice (you) anna bob Carl iris eve dave newbie",
	"F favourites first inside their faction, the own row by name")
has(fs, "style[grug_social_fav_zed,grug_social_fav_eve;textcolor=#f0c419;", "F gold stars on favourites")
check(grug_parties.is_favorite(alice, "zed"), "F is_favorite")
submit(alice, {grug_social_fav_ghost = "☆"})
check(not grug_parties.is_favorite(alice, "ghost"), "F an offline name is never added")
submit(alice, {grug_social_fav_alice = "☆"})
check(not grug_parties.is_favorite(alice, "alice"), "F not oneself")
submit(alice, {grug_social_fav_eve = "★"})
check(not grug_parties.is_favorite(alice, "eve"), "F a second click removes the mark")
fs = alice.formspec
eq(row_names(fs), "zed alice (you) anna bob Carl iris dave eve newbie", "F the order follows")

--
-- I. The invite button, without a party
--

check(invite_button(fs, "bob") and invite_button(fs, "anna") and invite_button(fs, "zed"),
	"I eligible players of the own faction have Invite")
check(not invite_button(fs, "dave") and not invite_button(fs, "eve"), "I enemies never have it")
check(star_button(fs, "dave"), "I enemies have the star")
check(not invite_button(fs, "iris"), "I a player with invitations off has none")
check(not invite_button(fs, "newbie"), "I a player without a faction has none")
submit(alice, {grug_social_inv_bob = "Invite"})
fs = alice.formspec
check(not invite_button(fs, "bob"), "I a player already invited by the viewer has none")
has(fs, "Success: Invitation sent.", "I the click invites")

--
-- B and H. The party box and the HUD box
--

local function hud_texts(p)
	local out = {}
	for _, def in pairs(p.huds) do
		if def.type == "text" then out[#out + 1] = def.text end
	end
	table.sort(out)
	return table.concat(out, " | ")
end
local function hud_count(p)
	local n = 0
	for _ in pairs(p.huds) do n = n + 1 end
	return n
end
step(0.6) -- a poll of every player
fs = open_social(bob)
has(fs, grug_core.ui.heading(0.5, 1.2, "1 Pending Invitation"), "B one invitation: singular")
has(fs, "grug_party_pending;" .. core.formspec_escape("alice [Lv 12] (1/10, 120s)") .. ";1;true]",
	"B the invitation's row")
has(fs, ";grug_party_accept;Accept]", "B Accept")
eq(hud_count(bob), 5, "H the box: panel, icon and three lines")
has(hud_texts(bob), "alice has invited you to join their | ", "H the inviter's sentence, wrapped")
has(hud_texts(bob), "party.", "H ...its end on the next line")
has(hud_texts(bob), "Open Social to answer (120 s)", "H the seconds and the note")
step(1.1)
grug_parties.invite(carl, "bob")
step(0.6)
fs = resend(bob)
has(fs, grug_core.ui.heading(0.5, 1.2, "2 Pending Invitations"), "B two invitations: plural")
has(hud_texts(bob), "+1 more", "H a second invitation: +1 more")
has(hud_texts(bob), "Carl has invited you", "H the newest invitation shows")
step(30)
has(hud_texts(bob), "Open Social to answer (90 s)", "H the poll keeps the seconds current")
grug_parties.set_hud_enabled(bob, false)
step(0.6)
check(hud_count(bob) > 0, "H the box ignores the Party HUD switch")
grug_parties.set_hud_enabled(bob, true)
-- Decline Carl's: one left, no "+N more".
submit(bob, {grug_party_pending = "CHG:1"})
eq(sfinv.contexts.bob.grug_party_inviter, "Carl", "B the list selects an inviter (Carl sorts first)")
submit(bob, {grug_party_decline = "Decline"})
lacks(hud_texts(bob), "+1 more", "H declined: the other invitation alone")
has(hud_texts(bob), "alice has invited you", "H declined: alice's stays")
-- Expiry: alice's invitation runs out.
local alice_sends = alice.sent
step(95)
eq(hud_count(bob), 0, "H hidden once the invitation expired")
has(bob.formspec, grug_core.ui.heading(0.5, 1.2, "0 Pending Invitations"), "B no invitation: zero, plural")
has(bob.formspec, "Invite a player of your faction with the Invite button", "B the empty box's hint")
check(alice.sent > alice_sends and invite_button(alice.formspec, "bob"),
	"C an expiry re-sends the inviter: its Invite button is back")

-- Accept: a party forms; the inviter's own invitations go too.
submit(alice, {grug_social_inv_bob = "Invite"})
step(1.1)
grug_parties.invite(zed, "alice")
step(0.6)
check(hud_count(alice) > 0, "H alice holds zed's invitation")
fs = resend(bob)
submit(bob, {grug_party_accept = "Accept"})
fs = bob.formspec
has(fs, "Current Party (2/10)", "B accepting switches the box at once")
has(fs, "tablecolumns[image,align=center,0=blank.png,1=grug_class_warrior.png", "B the member table")
has(fs, ";grug_party_leave;Leave]", "B Leave")
lacks(hud_texts(bob), "has invited you", "H accepted: the joiner's box goes")
step(0.6)
lacks(hud_texts(alice), "has invited you", "H a party forming clears the inviter's invitations too")
eq(#grug_parties.pending(alice), 0, "H ...in the store as well")

--
-- I. With a party: leader, member, full party
--

fs = resend(alice)
check(invite_button(fs, "anna") and invite_button(fs, "zed"), "I the leader invites eligible players")
check(not invite_button(fs, "bob"), "I a member of a party (here the own) has none")
fs = resend(bob)
check(not invite_button(fs, "anna") and not invite_button(fs, "zed"), "I a member never invites")
fs = open_social(carl)
check(not invite_button(fs, "bob") and not invite_button(fs, "alice"),
	"I players in a party have no button for others")
-- Fill the party to ten.
local extra = {}
for i = 1, 8 do
	local p = make_player("m" .. i, "accord", "mage", "human", 5)
	join(p)
	extra[i] = p
	step(1.1)
	grug_parties.invite(alice, p.name)
	grug_parties.accept(p, "alice")
end
eq(#grug_parties.view(alice).members, 10, "I the party is full")
step(0.1)
fs = resend(alice)
check(not invite_button(fs, "anna") and not invite_button(fs, "zed"), "I a full party invites nobody")
grug_parties.leave(extra[8])
fs = resend(alice)
check(invite_button(fs, "anna"), "I one place free: Invite is back")

--
-- C. The coalesced refresh
--

local function sends(p) return p.sent end
-- anna watches the tab, long enough to scroll; carl watches another page.
for i = 1, 10 do join(make_player("f" .. i, "throng", "mage", "orc", 9)) end
open_social(anna)
sfinv.set_page(carl, "home")
step(3)
local a0, c0 = sends(anna), sends(carl)
-- A burst in one step: two joins and a level change.
local x1, x2 = make_player("x1", "throng", "scout", "orc", 3), make_player("x2", "accord", "scout", "human", 3)
join(x1)
join(x2)
zed.level = 61
for _, fn in ipairs(level_callbacks) do fn(zed) end
eq(sends(anna), a0, "C nothing goes out inside the step")
run_jobs()
eq(sends(anna), a0 + 1, "C a burst in one step gives one send")
has(anna.formspec, "x1", "C ...showing the new players")
has(anna.formspec, "Lv 61", "C ...and the new level")
eq(sends(carl), c0, "C another page gets nothing")
-- A change inside the gap waits for its end.
step(0.5)
leave(x1)
run_jobs()
eq(sends(anna), a0 + 1, "C a change inside the 2 s gap is owed")
step(1.0)
eq(sends(anna), a0 + 1, "C ...still owed at 1.5 s")
step(0.6)
eq(sends(anna), a0 + 2, "C ...and sent once the gap ends")
lacks(anna.formspec, "x1", "C ...without the player who left")
step(3)
eq(sends(anna), a0 + 2, "C a quiet tab sends nothing")
-- Scrolling: kept, echoed, no send, and it holds sends.
local context = sfinv.contexts.anna
local before = sends(anna)
check(submit(anna, {grug_social_scroll = "CHG:42"}), "C a scrollbar move is handled")
eq(context.grug_social_scroll, 42, "C its value is kept")
eq(sends(anna), before, "C a scrollbar move sends nothing")
leave(x2)
step(0.2)
eq(sends(anna), before, "C a change inside the quiet hold waits")
step(0.5)
eq(sends(anna), before + 1, "C ...and goes out after it")
has(anna.formspec, ";vertical;grug_social_scroll;", "C the list scrolls")
check(anna.formspec:find("grug_social_scroll;%d+%]") ~= nil, "C the scrollbar carries a value")
submit(anna, {grug_social_scroll = "VAL:6", grug_social_fav_bob = "☆"})
eq(context.grug_social_scroll, 6, "C a VAL from any event is kept")
has(anna.formspec, ";vertical;grug_social_scroll;6]", "C ...and echoed by the next send")
-- Leaving the tab ends the owed sends.
sfinv.set_page(anna, "home")
before = sends(anna)
zed.level = 62
for _, fn in ipairs(level_callbacks) do fn(zed) end
step(3)
eq(sends(anna), before, "C a player who left the tab gets nothing")
-- The focus button does nothing.
open_social(anna)
before = sends(anna)
check(submit(anna, {grug_social_focus = ""}), "C the focus button is handled")
eq(sends(anna), before, "C ...without a send")
has(anna.formspec, "set_focus[grug_social_focus;true]button[0,0;0,0;grug_social_focus;]",
	"C the page focuses the invisible button")

--
-- Bytes: the tab with 1, 10 and 50 listed players (a comparison).
--

local function bytes_with(count)
	for _, p in ipairs(core.get_connected_players()) do leave(p) end
	run_jobs()
	local viewer = make_player("viewer", "accord", "warrior", "human", 30)
	join(viewer)
	for i = 2, count do
		local faction = i % 3 == 0 and "throng" or "accord"
		local p = make_player(("player_%02d_name"):format(i), faction,
			({"warrior", "mage", "priest", "scout"})[i % 4 + 1],
			faction == "throng" and "orc" or "dwarf", 10 + i)
		join(p)
		if i % 5 == 0 then grug_parties.toggle_favorite(viewer, p.name) end
	end
	run_jobs()
	local out = open_social(viewer)
	eq(select(2, row_names(out):gsub("%S+", "")) - 1, count, "bytes: " .. count .. " rows listed")
	leave(viewer)
	return #out
end
local b1, b10, b50 = bytes_with(1), bytes_with(10), bytes_with(50)

print(("Social tab bytes (page body, no PvP section): 1 player %d, 10 players %d, 50 players %d")
	:format(b1, b10, b50))
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("R67 SOCIAL PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R67 SOCIAL PORTABLE PASS checks=" .. checks)
