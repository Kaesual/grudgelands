-- Round 44 lane PP portable test: the Party & PvP tab, Help without an
-- inventory and the texts that name tabs and keys. Loads the REAL vendored
-- sfinv (mods/BASE/sfinv/api.lua), grug_inventory's ui.lua (the frame and
-- the tab order), help.lua and welcome.lua, grug_parties/ui.lua and
-- grug_pvp/page.lua (with view.lua) under a minimal `core` stub and checks:
--   T. the tab table: one "Party & PvP" entry (grug_parties:group), no PvP
--      page of its own;
--   P. the page out of a party and in one (as leader and as member): the
--      party section (settings, online same-faction players, pending
--      invitations, the member table and its buttons) and the PvP section
--      below it (state, the flag button, the statistics); no inventory view;
--      every element inside the window, the PvP section under the party's;
--   B. every party and PvP field still handled: each button, checkbox,
--      dropdown, textlist and table event reaches its grug_parties or
--      grug_pvp call; the flag button re-sends the page once;
--   S. the PvP 1 s check: an open tab re-sent only when the section's text
--      changed, another page asked nothing; grug_pvp changes re-send at once;
--   H. Help without an inventory view, its bodies inside the window; Help
--      and the welcome window name the new tabs, E, Z and the aux1 notes;
--   X. no player-facing string in mods/ (Lua string literals outside
--      comments, JSON data) names a removed tab or path: Bags, Quests,
--      Skills, Talents, Party or PvP tab or page, "Inventory > ...";
--   and prints the page's formspec bytes (a comparison, not a target).
--
-- Usage (repo root): luajit tools/r44_pp/portable_test.lua [repo]

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

local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
end

-- The elements of a formspec as {name, fields}; "]" and ";" escaped by
-- formspec_escape do not split.
local function elements(fs)
	local out, piece, i = {}, {}, 1
	while i <= #fs do
		local c = fs:sub(i, i)
		if c == "\\" then
			piece[#piece + 1] = fs:sub(i, i + 1)
			i = i + 1
		elseif c == "]" then
			local text = table.concat(piece)
			local name, args = text:match("^([%a_]+)%[(.*)$")
			out[#out + 1] = {name = name, args = args or "", raw = text}
			piece = {}
		else
			piece[#piece + 1] = c
		end
		i = i + 1
	end
	return out, #piece == 0
end
local function formspec_ok(fs, label)
	local list, closed = elements(fs)
	local ok = closed
	for _, element in ipairs(list) do
		if not element.name then ok = false end
	end
	return check(ok, label .. ": every element well formed")
end
local function numbers(text)
	local out = {}
	for value in (text .. ","):gmatch("([^,]*),") do out[#out + 1] = tonumber(value) end
	return out
end
-- The fields of an element, split at unescaped ";".
local function fields_of(args)
	local out, piece, i = {}, {}, 1
	while i <= #args do
		local c = args:sub(i, i)
		if c == "\\" then
			piece[#piece + 1] = args:sub(i, i + 1)
			i = i + 1
		elseif c == ";" then
			out[#out + 1] = table.concat(piece)
			piece = {}
		else
			piece[#piece + 1] = c
		end
		i = i + 1
	end
	out[#out + 1] = table.concat(piece)
	return out
end

--
-- Stubs
--

local mods_loaded, receive_handlers, steps = {}, {}, {}
local modname = "grug_inventory"
local players = {}
core = {
	formspec_escape = fs_escape,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return modname end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_player_receive_fields = function(fn)
		receive_handlers[#receive_handlers + 1] = fn
	end,
	log = function() end,
	get_game_info = function() return {path = repo} end,
	show_formspec = function() end,
	get_player_by_name = function(name) return players[name] end,
	get_connected_players = function()
		local list = {}
		for _, name in ipairs({"alice", "bob", "cyd", "dax"}) do
			if players[name] then list[#list + 1] = players[name] end
		end
		return list
	end,
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
Settings = function() return {get = function() return "0.44.0" end} end

grug_inventory = {BAG_COUNT = 4, content_list = function(i) return "grug_bag" .. i .. "_content" end}
grug_core = {status_icons = {
	CLASSES = {"warrior", "mage", "priest", "scout"},
	class_icon = function(id) return "grug_class_" .. id .. ".png" end,
}}
local factions = {alice = "accord", bob = "accord", cyd = "accord", dax = "throng"}
grug_factions = {
	get_faction = function(player) return factions[player:get_player_name()] end,
	display_name = function(id) return id end,
}
grug_xp = {get_level = function() return 12 end}
grug_classes = {register_on_arrival = function() end,
	get_race_def = function() return nil end, get_class_def = function() return nil end}

-- grug_parties: the state the page reads and a log of the calls it makes.
local party_calls, party_view, pending_rows = {}, nil, {}
local function party_call(name)
	return function(_, ...)
		party_calls[#party_calls + 1] = table.concat({name, ...}, ":")
		return true, name .. " done."
	end
end
local party_change
grug_parties = {
	view = function(player)
		return player:get_player_name() == "alice" and party_view or nil
	end,
	pending = function() return pending_rows end,
	invitations_enabled = function(player) return player:get_player_name() ~= "cyd" end,
	hud_enabled = function() return true end,
	health_color_mode = function() return "by_class" end,
	invite = party_call("invite"),
	accept = party_call("accept"),
	decline = party_call("decline"),
	leave = party_call("leave"),
	kick = party_call("kick"),
	transfer_leader = party_call("transfer"),
	set_invitations_enabled = function(_, value)
		party_calls[#party_calls + 1] = "invitations:" .. tostring(value)
		return true, "ok"
	end,
	set_hud_enabled = function(_, value)
		party_calls[#party_calls + 1] = "hud:" .. tostring(value)
		return true, "ok"
	end,
	set_health_color_mode = function(_, mode)
		party_calls[#party_calls + 1] = "colors:" .. tostring(mode)
		return true, "ok"
	end,
	register_on_change = function(fn) party_change = fn end,
}

-- grug_pvp: state and stats per player, flag_now counted.
local pvp_state, pvp_stats, pvp_change = {}, {}, {}
local pvp_calls = {state = 0, flag_now = 0, sounds = 0}
grug_pvp = {
	state = function(player)
		pvp_calls.state = pvp_calls.state + 1
		return pvp_state[player:get_player_name()] or {flagged = false}
	end,
	stats = function(player) return pvp_stats[player:get_player_name()] or {} end,
	flag_now = function(player)
		pvp_calls.flag_now = pvp_calls.flag_now + 1
		pvp_state[player:get_player_name()] = {flagged = true, reason = "button",
			seconds_left = 60}
		return true
	end,
	register_on_change = function(fn) pvp_change[#pvp_change + 1] = fn end,
}
grug_sounds = {play = function() pvp_calls.sounds = pvp_calls.sounds + 1 end}

local function make_player(name)
	local player = {sent = 0}
	function player.get_player_name() return name end
	function player.set_inventory_formspec(_, fs)
		player.sent = player.sent + 1
		player.formspec = fs
	end
	players[name] = player
	return player
end

--
-- Load the real files.
--

dofile(repo .. "/mods/BASE/sfinv/api.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/ui.lua")
sfinv.get_homepage_name = function() return "grug_inventory:help" end
dofile(repo .. "/mods/PLAYER/grug_inventory/help.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/welcome.lua")
modname = "grug_parties"
dofile(repo .. "/mods/PLAYER/grug_parties/ui.lua")
modname = "grug_pvp"
dofile(repo .. "/mods/PLAYER/grug_pvp/page.lua")
local V = dofile(repo .. "/mods/PLAYER/grug_pvp/view.lua")
for _, fn in ipairs(mods_loaded) do fn() end

--
-- T. The tab table
--

local PAGE = "grug_parties:group"
local in_table, pvp_in_table = 0, false
for _, name in ipairs(grug_inventory.TAB_ORDER) do
	if name == PAGE then in_table = in_table + 1 end
	if name == "grug_pvp:pvp" then pvp_in_table = true end
end
eq(in_table, 1, "T Party & PvP has one entry in TAB_ORDER")
check(not pvp_in_table, "T no separate PvP entry in TAB_ORDER")
check(sfinv.pages["grug_pvp:pvp"] == nil, "T no PvP page of its own")
eq(sfinv.pages[PAGE] and sfinv.pages[PAGE].title, "Party & PvP", "T the tab's title")
eq(grug_parties.PAGE, PAGE, "T grug_parties names its page")
check(type(grug_parties.pvp_section) == "table", "T grug_pvp installs its section")
local mod_conf = assert(io.open(repo .. "/mods/PLAYER/grug_pvp/mod.conf")):read("*a")
check(mod_conf:match("\ndepends = [^\n]*grug_parties") ~= nil,
	"T grug_pvp depends on grug_parties (it installs the section there)")

--
-- P. The page
--

local alice, bob, cyd, dax = make_player("alice"), make_player("bob"),
	make_player("cyd"), make_player("dax")
local page = sfinv.pages[PAGE]
local FRAME_W, FRAME_H = grug_inventory.UI.frame_w, grug_inventory.UI.frame_h

-- Every positioned element inside the window; labels at about 0.15 units a
-- character (the web build at 720 px, 48 px a unit, 7 px a character;
-- generous) and 0.36 high around their middle (a 16 px line at 48 px a
-- unit is 0.33). Returns the
-- element rectangles of the content for further checks.
local function geometry(fs, label)
	local list = elements(fs)
	local rects, inside = {}, true
	local real = false
	for _, element in ipairs(list) do
		if element.name == "real_coordinates" then real = element.args == "true" end
		local f = fields_of(element.args)
		local pos = f[1] and numbers(f[1])
		local size = f[2] and numbers(f[2])
		if real and pos and pos[1] and pos[2] and element.name ~= "tabheader" then
			local x, y, w, h
			if element.name == "label" then
				local text = f[2]:gsub("\27%(c@#%x+%)", ""):gsub("\\(.)", "%1")
				x, y, w, h = pos[1], pos[2] - 0.18, #text * 0.15, 0.36
				rects[#rects + 1] = {kind = "label", x = x, y = y, w = w, h = h, text = text}
			elseif element.name == "checkbox" then
				x, y, w, h = pos[1], pos[2] - 0.2, 0.5 + #f[3] * 0.15, 0.4
			elseif size and size[1] and size[2] then
				x, y, w, h = pos[1], pos[2], size[1], size[2]
				rects[#rects + 1] = {kind = element.name, x = x, y = y, w = w, h = h,
					text = f[3]}
			end
			if x and (x < 0 or y < 0 or x + w > FRAME_W - 0.1 or y + h > FRAME_H - 0.1) then
				inside = false
				print("  outside: " .. element.raw)
			end
		end
	end
	check(inside, label .. ": every element inside the 13.5 x 13.67 window")
	return rects
end
local function overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function no_inventory(fs, label)
	lacks(fs, "list[current_player;main", label .. ": no inventory view")
	lacks(fs, "scroll_container[", label .. ": no scroll area")
end
local function pvp_section(fs, label)
	has(fs, "PvP status", label .. ": the PvP heading")
	has(fs, ";grug_pvp_flag;Flag me for PvP]", label .. ": the flag button")
	has(fs, "Statistics", label .. ": the statistics heading")
	for _, row in ipairs(V.STATS) do
		has(fs, row[2], label .. ": counter " .. row[2])
	end
	has(fs, "There is no early unflag.", label .. ": the flag rule")
end

-- The PvP section sits under every party element, and no label runs into a
-- button or another label of its row.
local function layout(rects, label)
	local party_bottom, pvp_top = 0, math.huge
	local separator
	for _, rect in ipairs(rects) do
		if rect.kind == "box" then separator = rect end
	end
	check(separator ~= nil, label .. ": a separator line")
	if not separator then return end
	for _, rect in ipairs(rects) do
		if rect ~= separator then
			if rect.y < separator.y then
				party_bottom = math.max(party_bottom, rect.y + rect.h)
			else
				pvp_top = math.min(pvp_top, rect.y)
			end
		end
	end
	check(party_bottom <= separator.y and pvp_top >= separator.y + separator.h,
		label .. ": the PvP section starts under the party section")
	local clash = false
	for i, a in ipairs(rects) do
		for j = i + 1, #rects do
			local b = rects[j]
			if a.y >= separator.y and b.y >= separator.y and overlap(a, b) then
				clash = true
				print("  overlap: " .. tostring(a.text) .. " / " .. tostring(b.text))
			end
		end
	end
	check(not clash, label .. ": no PvP element overlaps another")
end

pvp_state.alice = {flagged = true, reason = "location_contested", pvp_combat = true}
pvp_stats.alice = {kills = 4, killing_blows = 2, deaths = 1, guards = 9, captains = 1,
	generals = 0, kings = 1}
pending_rows = {
	{inviter = "bob", level = 12, expires_in = 50, party = {members = {"bob", "x"}}},
	{inviter = "cyd", level = 11, expires_in = 20},
}

-- Out of a party.
local context = sfinv.get_or_create_context(alice)
sfinv.set_page(alice, PAGE)
local out_fs = alice.formspec
formspec_ok(out_fs, "P out of a party")
local frame_header = ("formspec_version[6]size[%.3f,%.3f]"):format(FRAME_W, FRAME_H)
eq(out_fs:sub(1, #frame_header), frame_header, "P out of a party: the window's frame")
has(out_fs, "tabheader[0,0;sfinv_nav_tabs;", "P the tab row")
has(out_fs, "Party & PvP", "P the tab caption")
no_inventory(out_fs, "P out of a party")
has(out_fs, "checkbox[0.20,0.22;grug_party_invites;Allow invitations;true]",
	"P out of a party: the invitations checkbox")
has(out_fs, ";grug_party_hud;Party HUD;true]", "P out of a party: the HUD checkbox")
has(out_fs, ";grug_party_health_colors;All green,By class;2;true]",
	"P out of a party: the health colours dropdown")
has(out_fs, "textlist[0.20,1.25;6.35,2.00;grug_party_online_list;" ..
	fs_escape("bob [Lv 12]") .. "," .. fs_escape("cyd [Lv 12] (Invites off)") .. ";1;false]",
	"P out of a party: online players of the own faction only, sorted")
lacks(out_fs, "dax", "P out of a party: no player of the other faction")
has(out_fs, ";grug_party_invite;Invite]", "P out of a party: Invite")
has(out_fs, ";grug_party_refresh;Refresh]", "P out of a party: Refresh")
has(out_fs, "textlist[6.85,1.25;6.35,2.00;grug_party_pending;" ..
	fs_escape("bob [Lv 12] (2/10, 50s)") .. "," .. fs_escape("cyd [Lv 11] (1/10, 20s)") ..
	";1;false]", "P out of a party: the pending invitations")
has(out_fs, ";grug_party_accept;Accept]", "P out of a party: Accept")
has(out_fs, ";grug_party_decline;Decline]", "P out of a party: Decline")
has(out_fs, "You are not in a party.", "P out of a party: the hint")
lacks(out_fs, "grug_party_members", "P out of a party: no member table")
lacks(out_fs, "grug_party_leave", "P out of a party: no Leave")
pvp_section(out_fs, "P out of a party")
has(out_fs, "Flagged: Contested Territory", "P the PvP headline")
has(out_fs, "In PvP combat", "P the PvP combat line")
has(out_fs, "label[4.40,12.60;9]", "P a counter value (guards 9, fourth row)")
has(out_fs, "label[11.05,11.40;1]", "P a counter value (captains 1, second column)")
layout(geometry(out_fs, "P out of a party"), "P out of a party")
local bytes_out = #out_fs

-- In a party, as its leader, another member selected: every button.
party_view = {leader = "alice", members = {
	{name = "alice", online = true, level = 12, hp = 20, hp_max = 20, class = "warrior"},
	{name = "bob", online = true, level = 12, hp = 10, hp_max = 20, class = "priest"},
	{name = "cyd", online = false, level = 11},
}}
context.grug_party_member = "bob"
context.grug_party_notice = "Success: invite done."
sfinv.set_player_inventory_formspec(alice, context)
local in_fs = alice.formspec
formspec_ok(in_fs, "P in a party")
no_inventory(in_fs, "P in a party")
has(in_fs, "label[0.20,4.25;Current party]", "P in a party: the heading")
has(in_fs, "table[0.20,4.58;6.35,2.55;grug_party_members;1," ..
	fs_escape("* alice [Lv 12]  20/20 HP") .. ",3," .. fs_escape("bob [Lv 12]  10/20 HP") ..
	",0," .. fs_escape("cyd [Lv 11]  Offline") .. ";2]", "P in a party: the member table")
has(in_fs, ";grug_party_kick;Kick]", "P in a party: Kick for the leader")
has(in_fs, ";grug_party_transfer;Make leader]", "P in a party: Make leader for the leader")
has(in_fs, ";grug_party_leave;Leave]", "P in a party: Leave")
has(in_fs, "Success: invite done.", "P in a party: the notice")
has(in_fs, ";grug_party_invite;Invite]", "P in a party: Invite stays")
has(in_fs, ";grug_party_accept;Accept]", "P in a party: Accept stays")
pvp_section(in_fs, "P in a party")
layout(geometry(in_fs, "P in a party"), "P in a party")
local bytes_in = #in_fs

-- Selecting oneself: no Kick or Make leader.
context.grug_party_member = "alice"
sfinv.set_player_inventory_formspec(alice, context)
lacks(alice.formspec, "grug_party_kick", "P own row: no Kick")
has(alice.formspec, ";grug_party_leave;Leave]", "P own row: Leave")

-- Safe, not in combat: the section without the combat line still fits.
pvp_state.bob = {flagged = false}
sfinv.get_or_create_context(bob)
sfinv.set_page(bob, PAGE)
has(bob.formspec, "Safe", "P safe headline")
lacks(bob.formspec, "In PvP combat", "P no combat line when safe")
pvp_section(bob.formspec, "P safe")
layout(geometry(bob.formspec, "P safe"), "P safe")

--
-- B. Every field still handled
--

local function submit(player, fields)
	return receive_handlers[1](player, "", fields)
end
local function last_call() return party_calls[#party_calls] end
context.grug_party_member = "bob"
submit(alice, {grug_party_online_list = "CHG:2"})
eq(context.grug_party_online, "cyd", "B the online list selects a player")
submit(alice, {grug_party_invite = "Invite"})
eq(last_call(), "invite:cyd", "B Invite invites the selected player")
submit(alice, {grug_party_pending = "CHG:2"})
eq(context.grug_party_inviter, "cyd", "B the invitation list selects an inviter")
submit(alice, {grug_party_accept = "Accept"})
eq(last_call(), "accept:cyd", "B Accept")
submit(alice, {grug_party_decline = "Decline"})
eq(last_call(), "decline:cyd", "B Decline")
submit(alice, {grug_party_members = "CHG:3:2"})
eq(context.grug_party_member, "cyd", "B the member table selects a member")
submit(alice, {grug_party_kick = "Kick"})
eq(last_call(), "kick:cyd", "B Kick")
submit(alice, {grug_party_transfer = "Make leader"})
eq(last_call(), "transfer:cyd", "B Make leader")
submit(alice, {grug_party_leave = "Leave"})
eq(last_call(), "leave", "B Leave")
submit(alice, {grug_party_invites = "false"})
eq(last_call(), "invitations:false", "B the invitations checkbox")
submit(alice, {grug_party_hud = "false"})
eq(last_call(), "hud:false", "B the HUD checkbox")
submit(alice, {grug_party_health_colors = "1"})
eq(last_call(), "colors:all_green", "B the health colours dropdown")
players.dax = nil
local sent = alice.sent
submit(alice, {grug_party_refresh = "Refresh"})
eq(alice.sent, sent + 1, "B Refresh re-sends the page")
eq(#context.grug_party_online_rows, 2, "B Refresh rebuilds the roster")
players.dax = dax
-- The PvP flag button: flag_now, its sound, one send, no party call.
local calls = #party_calls
pvp_state.alice = {flagged = false}
sent = alice.sent
local handled = submit(alice, {grug_pvp_flag = "Flag me for PvP"})
check(handled == true and pvp_calls.flag_now == 1 and pvp_calls.sounds == 1,
	"B the flag button flags the player, with its sound")
eq(alice.sent, sent + 1, "B the flag button re-sends the page once")
has(alice.formspec, "Flagged for 60 s", "B the re-sent page shows the flag")
eq(#party_calls, calls, "B the flag button calls nothing of the party")
-- A party change re-sends the open page.
sent = alice.sent
party_change("alice", "members")
eq(alice.sent, sent + 1, "B a party change re-sends the open page")

--
-- S. The PvP 1 s check
--

local function step(seconds)
	local t = 0
	while t < seconds - 1e-9 do
		t = t + 0.1
		for _, fn in ipairs(steps) do fn(0.1) end
	end
end
sfinv.contexts.bob, sfinv.contexts.cyd, sfinv.contexts.dax = nil, nil, nil
step(1) -- align the accumulator
sent = alice.sent
step(3)
eq(alice.sent, sent, "S an unchanged open tab is not re-sent")
pvp_state.alice.seconds_left = 59
step(1)
eq(alice.sent, sent + 1, "S a countdown second re-sends once")
pvp_stats.alice.kills = 5
step(1)
eq(alice.sent, sent + 2, "S a new counter value re-sends")
context.page = "grug_inventory:help"
pvp_state.alice.seconds_left = 30
local before_state = pvp_calls.state
step(3)
eq(alice.sent, sent + 2, "S another page gets nothing")
eq(pvp_calls.state, before_state, "S another page asks grug_pvp nothing")
for _, fn in ipairs(pvp_change) do fn(alice, {}) end
eq(alice.sent, sent + 2, "S a change on another page re-sends nothing")
context.page = PAGE
for _, fn in ipairs(pvp_change) do fn(alice, {}) end
eq(alice.sent, sent + 3, "S a change on the open tab re-sends at once")
local ok = pcall(pvp_change[1], make_player("newcomer"), {flagged = false})
check(ok, "S a join-time change without a context does nothing")

--
-- H. Help and the welcome window
--

context.grug_help_section = nil
sfinv.set_page(alice, "grug_inventory:help")
local help_fs = alice.formspec
formspec_ok(help_fs, "H Help")
no_inventory(help_fs, "H Help")
-- Hypertext bodies in legacy coordinates end inside the window: (y + 0.35
-- + 0.8667 h - 0.1333) slot spacings (help.lua), the window FRAME_H real
-- units (13.673 = 11.85 spacings until the Round 45 playtest) high.
local window_s = FRAME_H * 13 / 15
for _, section in ipairs({"start", "quests", "basics", "formulas", "about", "sound"}) do
	context.grug_help_section = section
	local fs = sfinv.get_formspec(alice, context)
	local inside = true
	for _, element in ipairs(elements(fs)) do
		if element.name == "hypertext" then
			local f = fields_of(element.args)
			local pos, size = numbers(f[1]), numbers(f[2])
			local bottom = pos[2] + 0.35 + 0.8667 * size[2] - 0.1333
			if bottom > window_s - 0.3 then inside = false end
		end
	end
	check(inside, "H Help " .. section .. ": the body ends inside the window")
	no_inventory(fs, "H Help " .. section)
end
local help_text = assert(io.open(repo .. "/mods/PLAYER/grug_inventory/help.lua")):read("*a")
for _, part in ipairs({"Talents & Skills tab", "Party & PvP tab", "Inventory tab",
		"potion belt", "E opens the quickbar", "Z opens the map", "Aux1 and Zoom keys",
		"Aux1 key for climbing/descending", "sink in water", "climb down ladders",
		"Toggle Aux1 key", "every second press of E", "quest log is in the map window",
		"wait in the quickbar"}) do
	has(help_text, part, "H Help names " .. part)
end
local shown
core.show_formspec = function(_, _, form) shown = form end
grug_inventory.welcome_formspec(alice)
shown = grug_inventory.welcome_formspec(alice):gsub("\\(.)", "%1")
for _, part in ipairs({"Talents & Skills tab", "Party & PvP tab", "Press E and Z.",
		"E opens your mounts and potions", "Z the map"}) do
	has(shown, part, "H the welcome window names " .. part)
end

--
-- X. No player-facing text names a removed tab
--

-- The file list comes from find(1), as in tools/r26_status_icons (a tool,
-- not game code: check_lua's sweep 5 names the io.popen).
-- The quoted string literals of one Lua line, outside a "--" comment.
local function lua_strings(line, out)
	local i, n = 1, #line
	while i <= n do
		local c = line:sub(i, i)
		if c == "-" and line:sub(i + 1, i + 1) == "-" then return end
		if c == '"' or c == "'" then
			local j, piece = i + 1, {}
			while j <= n do
				local d = line:sub(j, j)
				if d == "\\" then
					piece[#piece + 1] = line:sub(j + 1, j + 1)
					j = j + 1
				elseif d == c then
					break
				else
					piece[#piece + 1] = d
				end
				j = j + 1
			end
			out[#out + 1] = table.concat(piece)
			i = j
		end
		i = i + 1
	end
end
local BANNED = {
	"Bags tab", "Quests tab", "Skills tab", "Talents tab", "Party tab", "PvP tab",
	"Bags page", "Quests page", "Skills page", "Talents page", "Party page", "PvP page",
	"Inventory > ", "Open Party to",
}
-- "Talents & Skills tab" and "Party & PvP tab" contain two of the banned
-- phrases; they are the new names.
local ALLOWED = {"Talents & Skills tab", "Talents & Skills page", "Party & PvP tab",
	"Party & PvP page"}
local function offending(text)
	for _, allowed in ipairs(ALLOWED) do
		text = text:gsub(allowed:gsub("%p", "%%%0"), "")
	end
	for _, phrase in ipairs(BANNED) do
		if text:find(phrase, 1, true) then return phrase end
	end
end
local files, scanned, found = {}, 0, {}
local pipe = assert(io.popen("find '" .. repo .. "/mods' -type f \\( -name '*.lua' " ..
	"-o -name '*.json' \\) | sort"))
for path in pipe:lines() do files[#files + 1] = path end
pipe:close()
for _, path in ipairs(files) do
	local handle = io.open(path, "rb")
	if handle then
		local text = handle:read("*a")
		handle:close()
		scanned = scanned + 1
		local number = 0
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			number = number + 1
			local strings = {}
			if path:sub(-4) == ".lua" then
				lua_strings(line, strings)
				-- Concatenated literals on one line read as one text.
				strings[#strings + 1] = table.concat(strings)
			else
				strings[1] = line
			end
			for _, s in ipairs(strings) do
				local phrase = offending(s)
				if phrase then
					found[#found + 1] = path:sub(#repo + 2) .. ":" .. number .. " (" .. phrase .. ")"
					break
				end
			end
		end
	end
end
check(scanned > 500, "X the scan read the game's Lua and JSON files (" .. scanned .. ")")
for _, where in ipairs(found) do print("  names an old tab: " .. where) end
eq(#found, 0, "X no player-facing string names a removed tab")
-- The scan itself finds what it looks for.
local probe = {}
lua_strings([[	text = "Open the Skills tab" -- the "Bags tab"]], probe)
check(#probe == 1 and offending(probe[1]) == "Skills tab", "X the scan finds a literal")
probe = {}
lua_strings([[	-- "Open the Skills tab"]], probe)
eq(#probe, 0, "X the scan skips comments")
check(offending("Open the Talents & Skills tab.") == nil, "X the new names pass")

print(("Party & PvP page bytes (no inventory): out of a party %d, in a party of 3 " ..
	"as leader %d"):format(bytes_out, bytes_in))
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("R44 PP PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R44 PP PORTABLE PASS checks=" .. checks)
