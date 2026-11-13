-- Round 76 lane SOCIAL portable test (LuaJIT): the Social tab in four cards,
-- the clan card and the clan parts of the Online Players rows.
--
--   luajit tools/r76_social/portable_test.lua [repo]
--
-- Loads the REAL grug_parties (init.lua with ui.lua and hud.lua), the REAL
-- grug_clans (init.lua with social.lua), the REAL grug_pvp/page.lua and
-- view.lua, the vendored sfinv api.lua and grug_core's ui.lua, hud_layout.lua
-- and status_icons.lua on a fake engine with a clock (core.after, os.time)
-- and the join and leave hooks; factions, classes, races, levels and the PvP
-- state are stubs. Every clan is made through the clan API, so the buttons
-- are checked against the real rules. Checks:
--   G  the four cards (party, clan, online players, PvP) inside the page and
--      not overlapping; the clan card's and the PvP card's elements inside
--      their card; the online list shorter and scrolling.
--   N  the clan card without a clan: the hint, then one and two pending
--      invitations (sizes, seconds), Accept and Decline; the switch.
--   R  the buttons per role exactly as the API allows, for the own row and a
--      selected leader, captain and member row, as leader, captain and member.
--   O  the online row: Party and Clan for a free player of the own faction,
--      no Party for a party mate, the mark and no Clan for a clan mate, none
--      for the other faction, none with either switch off, no Clan from a
--      plain member.
--   M  the member order (online by role and name, then the latest logout
--      first), the ages, the selection hints, 100 members in pages.
--   A  a button press calls the API and shows its message (Clan, Accept,
--      Decline, Make captain, Make member, Make leader, Kick, Leave, the
--      switch, a refused press); the selection follows a row click.
--   F  the refresh: a membership change re-sends every viewer of the tab
--      through the limiter, an invitation only the players named, another
--      page nothing.
-- and prints the tab's formspec bytes with a 100 member clan (a comparison).

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
-- Fake engine (tools/r67_social's, with per-mod storage and os.time)
--

local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local parts, keys = {}, {}
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
local clock = 1800000000
os.time = function() return clock end -- luacheck: ignore
local steps, joins, leaves, receive, mods_loaded = {}, {}, {}, {}, {}
local jobs = {}
local players, joined, windows = {}, {}, {}
local storages, current_mod = {}, "grug_parties"
local chat = {}
core = {
	formspec_escape = function(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
	end,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function()
		local data = storages[current_mod] or {}
		storages[current_mod] = data
		return {get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value end}
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
	register_on_shutdown = function() end,
	register_chatcommand = function() end,
	get_player_by_name = function(name) return joined[name] and players[name] or nil end,
	get_connected_players = function()
		local list = {}
		for _, name in ipairs(joined.order or {}) do
			if joined[name] then list[#list + 1] = players[name] end
		end
		return list
	end,
	get_player_window_information = function(name) return windows[name] end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
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
-- Advances both clocks by `seconds` in 0.1 s server steps.
local function step(seconds)
	local t = 0
	while t < seconds - 1e-9 do
		t = t + 0.1
		us = us + 100000
		for _, fn in ipairs(steps) do fn(0.1) end
		run_jobs()
	end
	clock = clock + math.floor(seconds + 0.5)
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
		self.huds[self.next_id] = def
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

local pvp_change = {}
grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/status_icons.lua")
grug_sounds = {CLICK_STYLE = "", play = function() end}
grug_factions = {
	get_faction = function(player) return player.faction end,
	display_name = function(id) return id == "accord" and "The Accord" or "The Throng" end,
	register_on_faction_chosen = function() end,
}
grug_xp = {
	get_level = function(player) return player and player.level or 1 end,
	register_on_level_change = function() end,
}
grug_classes = {
	registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"},
		priest = {name = "Priest"}, scout = {name = "Scout"}},
	registered_races = {human = {name = "Human"}, orc = {name = "Orc"}},
	get_class = function(player) return player.class end,
	get_race = function(player) return player.race end,
	register_on_class_chosen = function() end,
	register_on_race_chosen = function() end,
}
grug_pvp = {
	state = function() return {flagged = false} end,
	stats = function() return {} end,
	flag_now = function() return true end,
	register_on_change = function(fn) pvp_change[#pvp_change + 1] = fn end,
}
dofile(repo .. "/mods/BASE/sfinv/api.lua")
sfinv.register_page("home", {get = function() return "home" end})
sfinv.get_homepage_name = function() return "home" end
-- The page's body alone; tools/r44_pp checks the party and PvP parts in
-- the real frame.
sfinv.make_formspec = function(_, _, content) return content end
current_mod = "grug_parties"
dofile(repo .. "/mods/PLAYER/grug_parties/init.lua")
current_mod = "grug_clans"
dofile(repo .. "/mods/PLAYER/grug_clans/init.lua")
current_mod = "grug_pvp"
dofile(repo .. "/mods/PLAYER/grug_pvp/page.lua")
current_mod = "test"
for _, fn in ipairs(mods_loaded) do fn() end
local PAGE = grug_parties.PAGE
local section = grug_parties.clan_section
check(type(section) == "table", "T grug_clans installs the clan section")
local conf = assert(io.open(repo .. "/mods/PLAYER/grug_parties/mod.conf")):read("*a")
check(not conf:find("grug_clans", 1, true), "T grug_parties never depends on grug_clans")
local file = io.open(repo .. "/mods/PLAYER/grug_clans/textures/" .. section.MARK, "rb")
check(file ~= nil and file:read(4) == "\137PNG", "T the clan mark ships as a PNG")
if file then file:close() end

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
local function select_member(p, name)
	sfinv.contexts[p.name].grug_clan_member, sfinv.contexts[p.name].grug_clan_notice = name, nil
	return resend(p)
end
-- The clan card's part of the page (up to the PvP card that follows it).
local function clan_card(fs)
	return fs:match("container%[0%.20,6%.30%](.-)container%[9%.00,7%.00%]") or ""
end
-- The clan card's member (or inviter) rows on the shown page, in order.
local function picks(fs, prefix)
	local names = {}
	for name in clan_card(fs):gmatch(";" .. (prefix or "grug_clan_pick_") .. "([%w_%-]+);") do
		names[#names + 1] = name
	end
	return table.concat(names, ",")
end
-- The online list's row of `name` (between its box or icon and the next row).
local function row_of(fs, name)
	local area = fs:match("scroll_container%[9%.20,0%.85[^%]]*%](.-)scroll_container_end%[%]") or ""
	local at = area:find("label%[1%.0,[%d.]+;" .. name:gsub("%p", "%%%0") .. "[%]%s]")
	if not at then return "" end
	-- It ends where the next row's box or faction icon begins.
	local stop = #area + 1
	for _, pattern in ipairs({"label%[1%.0,", "image%[0%.10,", "box%[0,"}) do
		stop = math.min(stop, area:find(pattern, at + 1) or stop)
	end
	-- The mark precedes the name label: take from the row's faction icon.
	local start = area:sub(1, at):match(".*()image%[0%.10,") or at
	return area:sub(start, stop - 1)
end
local function clan_button(fs, name) return fs:find(";grug_social_clan_" .. name .. ";Clan]", 1, true) ~= nil end
local function party_button(fs, name) return fs:find(";grug_social_inv_" .. name .. ";Party]", 1, true) ~= nil end
local BUTTONS = {"grug_clan_leave", "grug_clan_promote", "grug_clan_demote", "grug_clan_transfer",
	"grug_clan_kick"}
local function buttons(fs)
	local card, shown = clan_card(fs), {}
	for _, field in ipairs(BUTTONS) do
		if card:find(";" .. field .. ";", 1, true) then shown[#shown + 1] = field:sub(11) end
	end
	return table.concat(shown, ",")
end

-- The cast: leader Lea, captain Cap, members Mem and Max (all The Accord);
-- free players Fay and Ned (Accord), Ork (The Throng), Pia (party mate of
-- Lea), Off (clan invitations off), Pof (party invitations off).
local lea = make_player("Lea", "accord", "warrior", "human", 30)
local cap = make_player("Cap", "accord", "mage", "human", 25)
local mem = make_player("Mem", "accord", "priest", "human", 20)
local max = make_player("Max", "accord", "scout", "human", 21)
local fay = make_player("Fay", "accord", "mage", "human", 9)
local ned = make_player("ned", "accord", "scout", "human", 8)
local ork = make_player("Ork", "throng", "warrior", "orc", 40)
local pia = make_player("Pia", "accord", "priest", "human", 14)
local off = make_player("Off", "accord", "mage", "human", 15)
local pof = make_player("Pof", "accord", "mage", "human", 16)
for _, p in ipairs({lea, cap, mem, max, fay, ned, ork, pia, off, pof}) do join(p) end
grug_clans.set_invitations_enabled(off, false)
grug_parties.set_invitations_enabled(pof, false)

--
-- N. Without a clan
--

local fs = open_social(fay)
local card = clan_card(fs)
has(card, grug_core.ui.heading(0.3, 0.32, "0 Pending Clan Invitations"), "N no invitation: the count")
has(card, "You are not in a clan.", "N ...the hint")
has(card, "Clan button in the Online Players list", "N ...names the Clan button")
has(fs, "with the Party button in the Online Players list", "N the party box names the Party button")
lacks(card, "grug_clan_ipick_", "N ...and no empty list")
has(card, "checkbox[5.55,0.32;grug_clan_invites;Clan invitations;true]", "N the switch, on by default")
lacks(card, "grug_clan_accept", "N no Accept without an invitation")

-- Lea forms the clan with Cap, Mem and Max through the API.
check(grug_clans.invite(lea, "Cap"), "setup Lea invites Cap")
check(grug_clans.accept(cap, "Lea"), "setup Cap accepts")
step(1.1)
grug_clans.invite(lea, "Mem")
grug_clans.accept(mem, "Lea")
step(1.1)
grug_clans.invite(lea, "Max")
grug_clans.accept(max, "Lea")
grug_clans.promote(lea, "Cap")
eq(grug_clans.role_of("Cap"), "captain", "setup Cap is captain")
-- Lea and Pia form a party.
step(1.1)
grug_parties.invite(lea, "Pia")
grug_parties.accept(pia, "Lea")

-- Invitations to Fay: from Lea (clan of 4) and from Ned (no clan).
step(1.1)
grug_clans.invite(lea, "Fay")
grug_clans.invite(ned, "Fay")
step(0.2)
fs = resend(fay)
card = clan_card(fs)
has(card, grug_core.ui.heading(0.3, 0.32, "2 Pending Clan Invitations"), "N two invitations: plural")
eq(picks(fs, "grug_clan_ipick_"), "Lea,ned", "N one row per inviter, by name")
has(card, "label[3.85,0.27;4/100]", "N the inviter's clan size in the role column")
has(card, "label[3.85,0.87;new clan]", "N ...or a new clan")
has(card, "label[4.95,0.27;Lv 30]", "N the inviter's level")
has(card, "label[5.70,0.87;120 s]", "N the seconds left")
has(card, "image[0.10,0.06;0.42,0.42;grug_class_warrior.png]", "N the inviter's class icon")
has(card, "box[0,0.00;7.85,0.54;#bba0626b]", "N the first invitation is selected")
has(card, "INVITED BY", "N the column heads")
has(card, ";grug_clan_accept;Accept]", "N Accept")
has(card, ";grug_clan_decline;Decline]", "N Decline")
lacks(card, ";grug_clan_leave;", "N no Leave without a clan")
-- Decline Ned's: one left, singular.
submit(fay, {grug_clan_ipick_ned = ""})
eq(sfinv.contexts.Fay.grug_clan_inviter, "ned", "A a row click selects an inviter")
submit(fay, {grug_clan_decline = "Decline"})
fs = fay.formspec
has(clan_card(fs), grug_core.ui.heading(0.3, 0.32, "1 Pending Clan Invitation"), "N one invitation: singular")
has(clan_card(fs), "Success: Invitation declined.", "A Decline calls the API and shows its message")
eq(#grug_clans.pending(fay), 1, "A ...one invitation left")

--
-- G. The four cards
--

-- Every element in drawn order with its absolute rectangle (container
-- offsets applied); escaped brackets inside texts are skipped.
local function elements(text)
	local list, i = {}, 1
	while true do
		local s, e, name = text:find("([%w_]+)%[", i)
		if not s then break end
		local j = e + 1
		while j <= #text do
			local c = text:sub(j, j)
			if c == "\\" then j = j + 1
			elseif c == "]" then break end
			j = j + 1
		end
		list[#list + 1] = {name = name, args = text:sub(e + 1, j - 1)}
		i = j + 1
	end
	return list
end
local function rects(text)
	local out, ox, oy, stack = {}, 0, 0, {}
	for _, el in ipairs(elements(text)) do
		local x, y, w, h = el.args:match("^(%-?[%d.]+),(%-?[%d.]+);(%-?[%d.]+),(%-?[%d.]+)")
		if el.name == "container" or el.name == "scroll_container" then
			stack[#stack + 1] = {ox, oy}
			local cx, cy = el.args:match("^(%-?[%d.]+),(%-?[%d.]+)")
			ox, oy = ox + tonumber(cx), oy + tonumber(cy)
		elseif el.name == "container_end" or el.name == "scroll_container_end" then
			local top = table.remove(stack)
			if top then ox, oy = top[1], top[2] end
		end
		if x and el.name ~= "container" and el.name ~= "scroll_container" then
			out[#out + 1] = {name = el.name, x = ox + tonumber(x), y = oy + tonumber(y),
				w = tonumber(w), h = tonumber(h), args = el.args, depth = #stack}
		end
	end
	return out
end
local function overlap(a, b)
	return a.x < b.x + b.w - 1e-6 and b.x < a.x + a.w - 1e-6 and
		a.y < b.y + b.h - 1e-6 and b.y < a.y + a.h - 1e-6
end
local function inside(a, b)
	return a.x >= b.x - 1e-6 and a.y >= b.y - 1e-6 and a.x + a.w <= b.x + b.w + 1e-6 and
		a.y + a.h <= b.y + b.h + 1e-6
end
local function four_cards(text, label)
	local panels = {}
	for _, r in ipairs(rects(text)) do
		if r.name == "background9" and r.args:find("grug_ui_panel.png", 1, true) then panels[#panels + 1] = r end
	end
	eq(#panels, 4, label .. ": four cards")
	local page = {x = 0, y = 0, w = 20, h = 13.5}
	for i, a in ipairs(panels) do
		check(inside(a, page), label .. ": card " .. i .. " inside the page")
		for j = i + 1, #panels do
			check(not overlap(a, panels[j]), label .. ": cards " .. i .. " and " .. j .. " apart")
		end
	end
	-- Fix round 1: party (0.2, 0.85), online players (9.0, 0.1), clan (0.2, 6.3), PvP (9.0, 7.0).
	local where = {}
	for _, p in ipairs(panels) do where[#where + 1] = ("%.2f,%.2f %.2fx%.2f"):format(p.x, p.y, p.w, p.h) end
	eq(table.concat(where, " | "), "0.20,0.85 8.60x5.25 | 9.00,0.10 10.80x6.70 | " ..
		"0.20,6.30 8.60x7.05 | 9.00,7.00 10.80x6.35", label .. ": the cards' places")
	-- Every sized element of the clan and PvP containers inside its card.
	local clan, pvp = panels[3], panels[4]
	for _, r in ipairs(rects(clan_card(text))) do
		r.x, r.y = r.x + 0.2, r.y + 6.3
		if r.name ~= "background9" and r.name ~= "tooltip" then
			check(inside(r, clan), label .. ": clan element inside its card: " .. r.name .. "[" .. r.args:sub(1, 40))
		end
	end
	local pvp_part = text:match("container%[9%.00,7%.00%](.-)container_end%[%]") or ""
	check(pvp_part ~= "", label .. ": the PvP card on the right")
	for _, r in ipairs(rects(pvp_part)) do
		r.x, r.y = r.x + 9.0, r.y + 7.0
		if r.name ~= "background9" and r.name ~= "tooltip" then
			check(inside(r, pvp), label .. ": PvP element inside its card: " .. r.name)
		end
	end
	-- The party box's controls stay inside it, above the clan card.
	for _, r in ipairs(rects(text)) do
		if r.depth == 0 and r.x < 8.8 and r.y > 0.85 and r.name ~= "background9" and r.name ~= "tooltip" then
			check(r.y + r.h <= 6.1 + 1e-6 and r.x + r.w <= 8.8 + 1e-6,
				label .. ": party element inside the party box: " .. r.name)
		end
	end
	has(text, "scroll_container[9.20,0.85;10.05,5.80;grug_social_scroll;vertical;0.10]",
		label .. ": the shorter, wider online list")
	-- The party notice sits in the online card's heading row and fits it.
	local note = text:match("label%[12%.20,0%.45;([^%]]*)%]")
	if note then
		check(12.2 + #note * 0.1275 <= 19.8, label .. ": the party notice fits the heading row")
	end
end
four_cards(resend(fay), "G invitations")
four_cards(open_social(lea), "G leader in a party and a clan")
local saved_notice = sfinv.contexts.Lea.grug_party_notice
sfinv.contexts.Lea.grug_party_notice = "Refused: That player has disabled party invitations."
four_cards(resend(lea), "G with a party notice")
sfinv.contexts.Lea.grug_party_notice = saved_notice

--
-- R. The buttons per role
--

local cases = {
	-- viewer, selected row, the buttons the rules allow
	-- (fix round 2: and the hint under the list)
	{lea, "Lea", "leave", "Selected: you."},
	{lea, "Cap", "leave,demote,transfer,kick", "Selected: Cap."},
	{lea, "Mem", "leave,promote,transfer,kick", "Selected: Mem."},
	{cap, "Cap", "leave", "Selected: you."},
	{cap, "Lea", "leave", "Captains cannot act on the leader or other captains."},
	{cap, "Mem", "leave,kick", "Selected: Mem."},
	{mem, "Mem", "leave", "Selected: you."},
	{mem, "Lea", "leave", "Members can only leave."},
	{mem, "Cap", "leave", "Members can only leave."},
	{mem, "Max", "leave", "Members can only leave."},
}
for _, case in ipairs(cases) do
	local viewer, target, want = case[1], case[2], case[3]
	open_social(viewer)
	fs = select_member(viewer, target)
	local label = ("R %s (%s) selects %s"):format(viewer.name, grug_clans.role_of(viewer), target)
	eq(buttons(fs), want, label)
	-- The same as the API's own answers.
	local api = {"leave"}
	if target ~= viewer.name then
		if grug_clans.can_promote(viewer.name, target) then api[#api + 1] = "promote" end
		if grug_clans.can_demote(viewer.name, target) then api[#api + 1] = "demote" end
		if grug_clans.can_transfer(viewer.name, target) then api[#api + 1] = "transfer" end
		if grug_clans.can_kick(viewer.name, target) then api[#api + 1] = "kick" end
	end
	eq(buttons(fs), table.concat(api, ","), label .. ": as the API answers")
	has(clan_card(fs), "label[0.25,6.05;" .. core.formspec_escape(core.colorize(grug_core.ui.colors.muted,
		case[4])) .. "]", label .. ": the hint")
end
fs = select_member(lea, "Mem")
card = clan_card(fs)
has(card, "button[2.10,6.30;2.0,0.55;grug_clan_promote;Make captain]", "R Make captain's place")
has(card, "button[4.30,6.30;2.1,0.55;grug_clan_transfer;Make leader]", "R Make leader's place")
has(card, "button[6.60,6.30;1.7,0.55;grug_clan_kick;Kick]", "R Kick's place")
has(card, "button[0.20,6.30;1.7,0.55;grug_clan_leave;Leave]", "R Leave's place")
-- The rows: Lea, Cap, then Max and Mem by name; Mem (row 4) selected.
eq(picks(fs), "Lea,Cap,Max,Mem", "R the online tab's rows")
has(card, "box[0,1.80;7.85,0.54;#bba0626b]box[0,1.80;7.85,0.03;#d4b77db3]",
	"R the selected row: a stronger tint and a frame")
has(card, "box[0,0.00;7.85,0.54;#bba06230]", "R the own row tinted")
has(card, "image_button[0,1.80;7.85,0.54;blank.png;grug_clan_pick_Mem;;false;false]",
	"R an invisible button over the whole row")
has(card, "label[3.85,0.27;" .. core.formspec_escape(core.colorize("#d4b77d", "Leader")) .. "]",
	"R the leader's role in gold")
has(card, "label[3.85,0.87;" .. core.formspec_escape(core.colorize(grug_clans.COLOR, "Captain")) .. "]",
	"R a captain's role in green")
has(card, "label[5.70,0.27;" .. core.formspec_escape(core.colorize("#b4dca4", "Online")) .. "]",
	"R Online in the last column")
has(card, "style[grug_clan_kick;border=false;bgcolor=#ffffff;bgimg=grug_ui_danger.png", "R Kick is red")
has(select_member(lea, "Cap"), ";grug_clan_demote;Make member]", "R Make member for a captain row")

--
-- O. The online rows
--

fs = resend(lea)
check(party_button(fs, "Fay") and not clan_button(fs, "Fay"),
	"O an invited player: no Clan while the invitation lasts, Party from a party leader")
check(party_button(fs, "ned") and clan_button(fs, "ned"), "O a free player of the own faction: Party and Clan")
check(not party_button(fs, "Ork") and not clan_button(fs, "Ork"), "O the other faction: neither")
check(not party_button(fs, "Pia") and clan_button(fs, "Pia"), "O a party mate: Clan only")
check(party_button(fs, "Off") and not clan_button(fs, "Off"), "O clan invitations off: no Clan")
check(not party_button(fs, "Pof") and clan_button(fs, "Pof"), "O party invitations off: no Party")
check(not clan_button(fs, "Cap") and not clan_button(fs, "Max"), "O clan mates: no Clan")
has(row_of(fs, "Cap"), "image[0.55,", "O a clan mate carries the mark")
has(row_of(fs, "Cap"), section.MARK, "O ...the clan mark texture")
has(row_of(fs, "Cap"), "tooltip[0.55,", "O ...with its tooltip")
lacks(row_of(fs, "ned"), section.MARK, "O no mark for a player outside the clan")
lacks(row_of(fs, "Lea (you)"), section.MARK, "O no mark on the own row")
lacks(row_of(fs, "Lea (you)"), "grug_social_clan_", "O no Clan button on the own row")
has(row_of(fs, "ned"), "button[7.6,", "O Party's place")
has(row_of(fs, "ned"), "button[8.8,", "O Clan's place")
has(row_of(fs, "ned"), "button[6.95,", "O the star's place")
has(row_of(fs, "ned"), "image[5.10,", "O the class icon's place")
has(row_of(fs, "ned"), "label[6.05,", "O the level's place")
has(row_of(fs, "ned"), "tooltip[grug_social_clan_ned;Invite to your clan]", "O Clan's tooltip")
fs = resend(mem)
check(not clan_button(fs, "ned"), "O a plain member invites nobody to the clan")
check(party_button(fs, "ned"), "O ...but may still form a party")
has(row_of(fs, "Lea"), section.MARK, "O the member sees the mark on the leader")
fs = resend(cap)
check(clan_button(fs, "ned"), "O a captain invites to the clan")
fs = open_social(ork)
check(not clan_button(fs, "ned") and not party_button(fs, "Lea"), "O the Throng sees no buttons on the Accord")
lacks(row_of(fs, "Lea"), section.MARK, "O no mark for another clan's members")

--
-- P. The clan rows' Party button (0.76.1, the user's ruling 2026-11-11)
--

-- The Party button on `name`'s clan row, and that row's pick.
local function clan_party(fs, name)
	return clan_card(fs):find(";" .. section.PARTY_PREFIX .. name .. ";Party]", 1, true) ~= nil
end
do
local function clan_pick_y(fs, name)
	return tonumber(clan_card(fs):match("image_button%[0,([%d.]+);7%.85,0%.54;blank%.png;grug_clan_pick_" ..
		name .. ";"))
end
-- Lea leads the party Lea, Pia; Max joins it (a clan member already in a party).
step(1.1)
grug_parties.invite(lea, "Max")
grug_parties.accept(max, "Lea")
fs = open_social(lea)
eq(picks(fs), "Lea,Cap,Max,Mem", "P the online tab's rows")
check(clan_party(fs, "Cap") and clan_party(fs, "Mem"), "P Party on an online member the party may invite")
check(not clan_party(fs, "Lea"), "P never on the own row")
check(not clan_party(fs, "Max"), "P none on a member already in a party")
for _, name in ipairs({"Cap", "Max", "Mem"}) do
	eq(clan_party(fs, name), grug_parties.can_invite("Lea", name), "P " .. name .. ": as grug_parties.can_invite answers")
	-- Same faction by design: a faction change removes the member.
	eq(grug_factions.get_faction(players[name]), grug_factions.get_faction(lea), "P " .. name .. " shares the faction")
end
check(not grug_clans.can_invite(lea, "Ork") and not grug_parties.can_invite("Lea", "Ork"),
	"P the other faction never joins the clan, nor the party")
-- The place: the Online Players button's size, inside the row, right of the
-- status text, drawn after the row's pick (the engine hands a click to the
-- last element at that point).
local card_cap = clan_card(fs)
local y = clan_pick_y(fs, "Cap")
eq(y, 0.6, "P Cap's row")
local field = section.PARTY_PREFIX .. "Cap"
local party_at = card_cap:find(("button[6.65,%.2f;1.10,0.5;%s;Party]"):format(y + 0.02, field), 1, true)
check(party_at ~= nil, "P the button at the row's right end, 1.1 x 0.5 like Online Players'")
has(card_cap, "tooltip[" .. field .. ";Invite to your party]", "P ...with the Online Players tooltip")
lacks(card_cap, "style[" .. field, "P ...and no style of its own (the plain button look)")
local pick_at = card_cap:find("grug_clan_pick_Cap;", 1, true)
check(pick_at and party_at and party_at > pick_at, "P ...after the row's pick, so it takes its own clicks")
local row = {x = 0, y = y, w = 7.85, h = 0.54}
local button = {x = 6.65, y = y + 0.02, w = 1.1, h = 0.5}
check(inside(button, row), "P the button inside the row")
check(button.x + button.w <= row.w - 0.05, "P ...not touching the row's right edge")
-- "Online" at the last column, with the fixture's width estimate per letter.
local status = {x = grug_parties.COLUMNS.last, y = y, w = #"Online" * 0.1275, h = 0.54}
has(card_cap, "label[" .. ("%.2f"):format(status.x) .. "," .. ("%.2f"):format(y + 0.27) .. ";" ..
	core.formspec_escape(core.colorize("#b4dca4", "Online")) .. "]", "P Cap's status text")
check(not overlap(button, status), "P the button does not cover the status text")
four_cards(fs, "P leader with Party buttons")
-- Not the party leader (Max), a party invitation switch off (Mem), the
-- invitation pending (after the press).
fs = open_social(max)
check(not clan_party(fs, "Cap") and not clan_party(fs, "Mem") and not clan_party(fs, "Lea"),
	"P a party member who does not lead: no Party button")
grug_parties.set_invitations_enabled(mem, false)
step(2.1)
check(not clan_party(lea.formspec, "Mem"), "P Mem switched party invitations off: gone (re-sent)")
grug_parties.set_invitations_enabled(mem, true)
step(2.1)
check(clan_party(lea.formspec, "Mem"), "P ...and back on")
-- The press: invites, shows the party's answer in the clan card, never selects.
submit(lea, {grug_clan_pick_Mem = ""})
eq(sfinv.contexts.Lea.grug_clan_member, "Mem", "P a click on the row still selects")
local party_notice = sfinv.contexts.Lea.grug_party_notice
submit(lea, {[field] = "Party"})
fs = lea.formspec
check(grug_parties.pending(cap)[1] ~= nil and grug_parties.pending(cap)[1].inviter == "Lea",
	"P the press calls grug_parties.invite")
has(clan_card(fs), "Success: Invitation sent.", "P ...its answer in the clan card's notice line")
eq(sfinv.contexts.Lea.grug_party_notice, party_notice, "P ...not in the party's notice")
eq(sfinv.contexts.Lea.grug_clan_member, "Mem", "P ...and the selection stays")
check(not clan_party(fs, "Cap"), "P Cap invited: the button goes while the invitation lasts")
check(clan_party(fs, "Mem"), "P ...Mem's stays")
-- A refusal shows too (a stale page: Cap holds the invitation already).
step(1.1)
submit(lea, {grug_clan_party_Max = "Party"})
has(clan_card(lea.formspec), "Refused: That player already belongs to a party.", "P a refused press")
-- Cap declines: Lea's button comes back (the decline asks the inviter's page).
grug_parties.decline(cap, "Lea")
step(2.1)
check(clan_party(lea.formspec, "Cap"), "P a declined invitation: the button returns")
-- Max leaves the party: his button appears (a membership change asks everyone).
grug_parties.leave(max)
step(2.1)
check(clan_party(lea.formspec, "Max"), "P a member who left the party: the button appears")
sfinv.contexts.Lea.grug_clan_member, sfinv.contexts.Lea.grug_clan_notice = nil, nil
end

--
-- A. Button presses
--

step(1.1) -- one clan invitation per second per sender
open_social(lea)
submit(lea, {grug_social_clan_ned = "Clan"})
fs = lea.formspec
has(clan_card(fs), "Success: Invitation sent.", "A Clan invites and shows the API's message")
check(not clan_button(fs, "ned"), "A ...the button goes while the invitation lasts")
eq(#grug_clans.pending(ned), 1, "A ...ned holds it")
step(1.1)
open_social(ned)
submit(ned, {grug_clan_accept = "Accept"})
fs = ned.formspec
has(clan_card(fs), "Success: Joined the clan.", "A Accept joins")
has(clan_card(fs), "Clan (5/100)", "A ...the card switches at once")
-- A row click selects its member by name.
open_social(lea)
submit(lea, {grug_clan_pick_ned = ""})
eq(sfinv.contexts.Lea.grug_clan_member, "ned", "A a row click selects that member")
submit(lea, {grug_clan_promote = "Make captain"})
eq(grug_clans.role_of("ned"), "captain", "A Make captain")
has(clan_card(lea.formspec), "Success: Made captain.", "A ...its message")
lacks(clan_card(lea.formspec), "Selected: ned.", "A ...the notice takes the hint's line")
submit(lea, {grug_clan_pick_ned = ""})
has(clan_card(lea.formspec), "Selected: ned.", "A a new selection: the hint again")
submit(lea, {grug_clan_demote = "Make member"})
eq(grug_clans.role_of("ned"), "member", "A Make member")
-- A refused press (a stale page): Cap tries to kick the leader.
open_social(cap)
sfinv.contexts.Cap.grug_clan_member = "Lea"
submit(cap, {grug_clan_kick = "Kick"})
has(clan_card(cap.formspec), "Refused: You may not remove that member.", "A a refused press shows the refusal")
eq(grug_clans.role_of("Lea"), "leader", "A ...and changes nothing")
submit(lea, {grug_clan_pick_ned = ""})
submit(lea, {grug_clan_kick = "Kick"})
eq(grug_clans.in_clan("ned"), false, "A Kick removes the member")
has(clan_card(lea.formspec), "Success: Member removed.", "A ...its message")
eq(sfinv.contexts.Lea.grug_clan_member, nil, "A ...no selection any more")
eq(buttons(lea.formspec), "leave", "A ...then only Leave")
-- The switch.
submit(fay, {grug_clan_invites = "false"})
eq(grug_clans.invitations_enabled(fay), false, "A the switch turns clan invitations off")
has(clan_card(fay.formspec), "checkbox[5.55,0.32;grug_clan_invites;Clan invitations;false]", "A ...shown off")
eq(#grug_clans.pending(fay), 0, "A ...and drops the pending ones")
eq(grug_parties.invitations_enabled(fay), true, "A ...party invitations stay on")
submit(fay, {grug_clan_invites = "true"})
eq(grug_clans.invitations_enabled(fay), true, "A ...and back on")
-- Party fields still reach the party (the clan section does not swallow them).
local before = #grug_parties.pending(ned)
submit(lea, {grug_social_inv_ned = "Party"})
eq(#grug_parties.pending(ned), before + 1, "A Party still invites to the party")
has(lea.formspec, "label[12.20,0.45;Success: Invitation sent.]",
	"A ...with the party's notice in the online card's heading row")
-- Fix round 2: the party invitations in the row style.
fs = open_social(ned)
has(fs, "image_button[0,0.00;7.85,0.54;blank.png;grug_party_ipick_Lea;;false;false]",
	"A ned's party invitation as a row with its pick button")
has(fs, "label[3.85,0.27;2/10]", "A ...the party's size")
has(fs, "label[4.95,0.27;Lv 30]", "A ...the inviter's level")
has(fs, "label[5.70,0.27;120 s]", "A ...the seconds left")
has(fs, "PARTY", "A ...under column heads")
has(fs, "box[0,0.00;7.85,0.54;#bba0626b]", "A ...the first invitation selected")
lacks(fs, "grug_party_pending", "A ...no textlist any more")
submit(ned, {grug_party_ipick_Lea = ""})
eq(sfinv.contexts.ned.grug_party_inviter, "Lea", "A a row click selects the party inviter")
-- The party rows: a click selects, the leader's buttons follow.
fs = resend(lea)
has(fs, "image_button[0,0.60;7.85,0.54;blank.png;grug_party_pick_Pia;;false;false]",
	"A the party rows carry the invisible pick button")
submit(lea, {grug_party_pick_Pia = ""})
eq(sfinv.contexts.Lea.grug_party_member, "Pia", "A a party row click selects")
has(lea.formspec, ";grug_party_kick;Kick]", "A ...Kick for the leader")
has(lea.formspec, "box[0,0.60;7.85,0.54;#bba0626b]", "A ...the row marked")
has(lea.formspec, "label[3.85,0.27;" .. core.formspec_escape(core.colorize("#d4b77d", "Leader")) .. "]",
	"A the party leader's role, no star prefix")
-- Fix round 2: a status column instead of HP, no "(you)" in the rows.
has(lea.formspec, "label[5.70,0.87;" .. core.formspec_escape(core.colorize("#b4dca4", "Online")) .. "]",
	"A a party member's status")
lacks(lea.formspec, " HP]", "A no HP in the party rows")
has(lea.formspec, "label[1.05,0.27;Lea]", "A the own party row, without (you)")
lacks(clan_card(lea.formspec), "(you)", "A no (you) in the clan rows")
has(lea.formspec, "STATUS", "A the party's column heads")
has(lea.formspec, "image[0.55,0.06;0.42,0.42;" .. core.formspec_escape(grug_core.status_icons.race_icon("human")) ..
	"]", "A the race icon of an online party member")

--
-- M. Order, ages and 100 members
--

-- Max and Mem log out at different times: Mem first (older), Max later.
-- The clocks jump (no server steps in between).
local function jump(seconds)
	us, clock = us + seconds * 1000000, clock + seconds
	run_jobs()
end
leave(mem)
jump(3 * 3600)
leave(max)
jump(300)
fs = resend(lea)
eq(picks(fs), "Lea,Cap", "M the online tab: online members only")
card = clan_card(fs)
has(card, grug_core.ui.heading(0.3, 0.32, "Clan (4/100)"), "M the heading")
has(card, ";grug_clan_tab_online;Online (2)]", "M the online tab counts")
has(card, ";grug_clan_tab_offline;Offline (2)]", "M the offline tab counts")
has(card, "style[grug_clan_tab_online;border=false;bgcolor=#ffffff;bgimg=grug_ui_selected.png",
	"M the online tab is the shown one")
has(card, "label[6.72,0.98;1 / 1]", "M one page")
has(card, "style[grug_clan_prev;border=false;bgimg=grug_ui_clear.png;textcolor=#a9aea459]",
	"M ‹ inactive on the first page")
has(card, "style[grug_clan_next;border=false;bgimg=grug_ui_clear.png;textcolor=#a9aea459]",
	"M › inactive on the last page")
sfinv.contexts.Lea.grug_clan_notice = nil
has(clan_card(resend(lea)), "Click a member to select them.", "M no selection and no notice: the hint")
submit(lea, {grug_clan_tab_offline = "Offline (2)"})
fs = lea.formspec
eq(picks(fs), "Max,Mem", "M the offline tab: the latest logout first")
card = clan_card(fs)
has(card, "LAST ONLINE", "M the offline tab's last column head")
has(card, core.formspec_escape(core.colorize(grug_core.ui.colors.muted, "5 min ago")), "M Max's age, grey")
has(card, core.formspec_escape(core.colorize(grug_core.ui.colors.muted, "3 h ago")), "M Mem's age")
has(card, core.formspec_escape(core.colorize(grug_core.ui.colors.muted, "Max")), "M an offline row is grey")
lacks(card, section.PARTY_PREFIX, "P an offline member never has a Party button")
submit(lea, {grug_clan_pick_Max = ""})
eq(buttons(lea.formspec), "leave,promote,transfer,kick", "M an offline member can be selected and kicked")
submit(lea, {grug_clan_tab_online = "Online (2)"})
eq(sfinv.contexts.Lea.grug_clan_member, nil, "M a tab change clears the selection")
eq(picks(lea.formspec), "Lea,Cap", "M ...and shows the online tab again")
eq(section.age(clock - 30, clock), "1 min ago", "M under a minute")
eq(section.age(clock - 59 * 60, clock), "59 min ago", "M minutes")
eq(section.age(clock - 2 * 86400 - 5, clock), "2 d ago", "M days")
eq(section.age(nil, clock), "Offline", "M no time stored")
local function names_of(rows)
	local names = {}
	for _, row in ipairs(rows) do names[#names + 1] = row.name end
	return table.concat(names, ",")
end
eq(names_of(section.ordered({
	{name = "b", online = true, role = "member"}, {name = "A", online = true, role = "member"},
	{name = "z", online = true, role = "captain"}, {name = "y", online = false, role = "member", last_online = 5},
	{name = "x", online = false, role = "member", last_online = 9}, {name = "w", online = true, role = "leader"}})),
	"w,z,A,b,x,y", "M leader, captains, members by name, then offline by time")
eq(names_of(section.ordered({
	{name = "m", online = true, role = "member"}, {name = "c", online = false, role = "captain", last_online = 9},
	{name = "l", online = false, role = "leader", last_online = 1}, {name = "n", online = true, role = "member"},
	{name = "d", online = false, role = "member", last_online = 9}})),
	"m,n,c,d,l", "M an offline leader or captain after every online member; equal times by name")

-- 100 members: Cap's own clan, filled to the limit.
local big_leader = make_player("Boss", "accord", "warrior", "human", 50)
join(big_leader)
for i = 1, 99 do
	local p = make_player(("member_%02d"):format(i), "accord", "mage", "human", 10 + i % 50)
	join(p)
	step(1.1)
	grug_clans.invite(big_leader, p.name)
	grug_clans.accept(p, "Boss")
	if i % 3 == 0 then leave(p) end
end
eq(#grug_clans.view(big_leader).members, 100, "M the clan is full")
fs = open_social(big_leader)
card = clan_card(fs)
has(card, grug_core.ui.heading(0.3, 0.32, "Clan (100/100)"), "M 100 members in the heading")
has(card, ";grug_clan_tab_online;Online (67)]", "M 67 online")
has(card, ";grug_clan_tab_offline;Offline (33)]", "M 33 offline")
has(card, "label[6.72,0.98;1 / 10]", "M ten pages of seven")
eq(select(2, card:gsub(";grug_clan_pick_", "")), 7, "M only the shown page is in the formspec")
lacks(card, "style[grug_clan_next;border=false;bgimg=grug_ui_clear.png", "M › active on page 1")
check(not clan_button(fs, "ned") and party_button(fs, "ned"), "M a full clan: no Clan button, Party stays")
local bytes_online, card_online = #fs, #card
local page1 = picks(fs)
submit(big_leader, {grug_clan_pick_member_01 = ""})
eq(sfinv.contexts.Boss.grug_clan_member, "member_01", "M a row of page 1 selected")
submit(big_leader, {grug_clan_next = "›"})
eq(sfinv.contexts.Boss.grug_clan_page, 2, "M › turns the page")
eq(sfinv.contexts.Boss.grug_clan_member, nil, "M ...and clears the selection")
check(picks(big_leader.formspec) ~= page1, "M ...another seven rows")
has(clan_card(big_leader.formspec), "label[6.72,0.98;2 / 10]", "M ...page 2 of 10")
submit(big_leader, {grug_clan_prev = "‹"})
submit(big_leader, {grug_clan_prev = "‹"})
eq(sfinv.contexts.Boss.grug_clan_page, 1, "M ‹ stops at the first page")
-- The selected member leaves the page by a refresh (goes offline): no selection.
submit(big_leader, {grug_clan_pick_member_01 = ""})
leave(players.member_01)
run_jobs()
fs = resend(big_leader)
eq(sfinv.contexts.Boss.grug_clan_member, nil, "M a member who leaves the page is no longer selected")
eq(buttons(fs), "leave", "M ...then only Leave")
submit(big_leader, {grug_clan_tab_offline = "Offline (34)"})
fs = big_leader.formspec
has(clan_card(fs), "label[6.72,0.98;1 / 5]", "M the offline tab pages too")
eq(picks(fs):match("^[^,]+"), "member_01", "M ...the latest logout first")
for _ = 1, 6 do submit(big_leader, {grug_clan_next = "›"}) end
eq(sfinv.contexts.Boss.grug_clan_page, 5, "M › stops at the last page")
has(clan_card(big_leader.formspec), "style[grug_clan_next;border=false;bgimg=grug_ui_clear.png",
	"M ...where it is inactive")
local bytes_offline, card_offline = #big_leader.formspec, #clan_card(big_leader.formspec)
submit(big_leader, {grug_clan_tab_online = "Online"})
-- P: Boss's party fills up; with ten members no row has a Party button.
do
	local mates = {"member_11", "member_13", "member_14", "member_16", "member_17", "member_19",
		"member_20", "member_22", "member_23"}
	for index, name in ipairs(mates) do
		step(1.1)
		check(grug_parties.invite(big_leader, name) and grug_parties.accept(players[name], "Boss"),
			"P setup " .. name .. " joins Boss's party")
		if index == 8 then
			fs = resend(big_leader)
			eq(picks(fs), "Boss,member_02,member_04,member_05,member_07,member_08,member_10",
				"P Boss's first page")
			check(clan_party(fs, "member_02") and clan_party(fs, "member_10"),
				"P a party of nine: Party on the free rows")
		end
	end
	fs = resend(big_leader)
	eq(#grug_parties.view(big_leader).members, 10, "P Boss's party is full")
	lacks(clan_card(fs), section.PARTY_PREFIX, "P a full party: no Party button on any row")
	-- Back to no party for the refresh checks below.
	for _, name in ipairs(mates) do grug_parties.kick(big_leader, name) end
	run_jobs()
end

--
-- F. The refresh
--

open_social(ned)
open_social(fay)
sfinv.set_page(pia, "home")
step(3)
local n0, f0, p0, l0 = ned.sent, fay.sent, pia.sent, lea.sent
-- An invitation names only its two players.
grug_clans.invite(lea, "ned")
run_jobs()
eq(ned.sent, n0 + 1, "F an invitation re-sends the invited")
eq(fay.sent, f0, "F ...not a bystander")
step(3)
n0, f0, p0, l0 = ned.sent, fay.sent, pia.sent, lea.sent
-- A membership change re-sends every viewer of the tab (marks and buttons).
grug_clans.accept(ned, "Lea")
run_jobs()
eq(fay.sent, f0 + 1, "F a membership change re-sends a bystander's tab")
eq(pia.sent, p0, "F ...not another page")
check(lea.sent > l0, "F ...and the clan's viewer")
-- Inside the gap it is owed, once.
step(0.5)
grug_clans.leave(ned)
run_jobs()
eq(fay.sent, f0 + 1, "F a change inside the 2 s gap is owed")
step(1.6)
eq(fay.sent, f0 + 2, "F ...and sent once the gap ends")

print(("Social tab bytes (page body with the PvP card) as leader of 100 (about 80 players online): " ..
	"online tab %d (clan card %d), offline tab, last page %d (clan card %d)")
	:format(bytes_online, card_online, bytes_offline, card_offline))
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("R76 SOCIAL PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R76 SOCIAL PORTABLE PASS checks=" .. checks)
