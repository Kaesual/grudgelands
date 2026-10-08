-- Round 28 Lane A6 portable test (rulings 19-24). Loads the REAL files under a
-- minimal `core` stub and checks:
--   1. the message feed (grug_core/feed.lua + hud_layout.lua): placement above
--      the status icon row at several GUI scales, three lines newest at the
--      bottom, keyed replacement, XP merge window, loot merge per item, colours
--      by kind, darkening before expiry, expiry, idle passes writing nothing,
--      the level-up banner and the wrapped item-pickup count;
--   2. grug_xp: every positive grant reaches the feed unless quiet, the
--      level-up is a banner and nothing goes to chat;
--   3. quest progress lines (grug_quests/hud.lua): first sight silent, a rise
--      posts "<subject> n/m" under the quest's key, a fall is silent;
--   4. the quest log (the map window's quest box since Round 44,
--      grug_map/quest_box.lua): one text field below the list, the title
--      aligned with the text; description, objectives and rewards in that
--      field, "Track on HUD" and Abandon on one row, the abandon
--      confirmation alone on it (Round 32 F3); the ready line below;
--   5. the Riding Trainer (grug_mounts/state.lua tier_state + trainer.lua):
--      all four tiers with the right state, buttons only for "buy";
--   6. the Character page (grug_inventory/pages.lua): "Damage reduction" with
--      its tooltip, the Professions tab body from grug_jobs/character_tab.lua;
--      the Scout's quiver cell at 0, 100, 101, 181 and 500 arrows (Round 41:
--      above 100 the total as an overlay, its cover at gui_scaling 1 and 2);
--   7. recipe books (grug_jobs/ui.lua): a profession book lists T1-T6 with
--      locked recipes greyed and "N locked" per tier, the station view and
--      Basics keep their old rules;
--   8. every formspec built above passes a bracket/escape sanity check;
--   9. slots that accept several items (Round 41 lane UI, ruling 4): the
--      2 / 3 / 4 (2x2) / 3 + "+N" icon layouts inside the cell, a single
--      member keeps its one icon, icons in the tooltip's order, one click
--      target per icon with a recipe and none for "+N", the complete list on
--      every icon, and navigation and Back from a sub-icon.
--
-- Usage (repo root): luajit tools/r28_a6_ui/portable_test.lua

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
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

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

-- builtin's formspec_escape and colorize, verbatim in effect.
local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
end
local ESC = string.char(27)
local function colorize(color, text)
	return ESC .. "(c@" .. color .. ")" .. text .. ESC .. "(c@#ffffff)"
end

-- Formspec sanity: every "[" opens exactly one element, escapes are honoured,
-- nothing but element names sits between elements, and all elements close.
local formspecs_checked = 0
local raw_brackets = {}
local function formspec_ok(fs, label)
	formspecs_checked = formspecs_checked + 1
	local depth, i, n = 0, 1, #fs
	while i <= n do
		local c = fs:sub(i, i)
		if c == "\\" then
			i = i + 2
		else
			if c == "[" then
				-- The engine splits an element at its FIRST "[" and ends it at
				-- the first unescaped "]"; a later raw "[" (a texture modifier
				-- such as "^[transformR270") is legal and logged.
				if depth == 1 then raw_brackets[label] = (raw_brackets[label] or 0) + 1 end
				depth = 1
			elseif c == "]" then
				depth = depth - 1
				if depth < 0 then return check(false, label .. ": stray ] at " .. i) end
			elseif depth == 0 and not c:match("[%w_]") then
				return check(false, label .. ": text outside an element at " .. i ..
					" near " .. ("%q"):format(fs:sub(math.max(1, i - 20), i + 20)))
			end
			i = i + 1
		end
	end
	return check(depth == 0, label .. ": unclosed element")
end

-- Engine surface shared by all sections.
local clock_us = 0
local after_queue = {}
local callbacks = {}
local function capture(kind) return function(fn) callbacks[kind] = callbacks[kind] or {}; table.insert(callbacks[kind], fn) end end
local players = {}
local chat = {}
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	registered_nodes = {},
	formspec_escape = fs_escape, colorize = colorize,
	get_us_time = function() return clock_us end,
	after = function(delay, fn, ...)
		after_queue[#after_queue + 1] = {at = clock_us + delay * 1000000, fn = fn,
			args = {...}}
	end,
	get_player_by_name = function(name) return players[name] end,
	get_connected_players = function()
		local out = {}
		for _, p in pairs(players) do out[#out + 1] = p end
		return out
	end,
	get_player_window_information = function(name)
		return players[name] and players[name]._window
	end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name = name, text = text} end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	log = function() end,
	get_item_group = function() return 0 end,
	register_on_joinplayer = capture("join"),
	register_on_leaveplayer = capture("leave"),
	register_globalstep = capture("step"),
	register_on_mods_loaded = capture("mods_loaded"),
	register_on_player_receive_fields = capture("fields"),
	register_on_dieplayer = capture("die"),
	register_on_player_hpchange = capture("hpchange"),
	register_on_player_inventory_action = capture("inventory_action"),
	register_chatcommand = function() end,
	add_particlespawner = function() end,
	show_formspec = function() end,
	close_formspec = function() end,
}
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end}

-- ItemStack double with the methods the files use.
function ItemStack(item)
	if type(item) == "table" and item._is_stack then item = item:to_string() end
	local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
	count = tonumber(count) or (name == "" and 0 or 1)
	if name == "" then count = 0 end
	local stack = {_is_stack = true}
	function stack:get_name() return name end
	function stack:get_count() return count end
	function stack:is_empty() return count == 0 or name == "" end
	function stack:to_string() return name == "" and "" or (name .. " " .. count) end
	function stack:get_stack_max()
		local def = core.registered_items[name]
		return def and def.stack_max or 99
	end
	function stack:get_short_description()
		local def = core.registered_items[name]
		return def and def.description or name
	end
	return stack
end

local function run_steps(dt)
	for _, fn in ipairs(callbacks.step or {}) do fn(dt) end
end
-- Advances the clock in 0.05 s steps, running due core.after jobs.
local function advance(seconds)
	local steps = math.floor(seconds / 0.05 + 0.5)
	for _ = 1, steps do
		clock_us = clock_us + 50000
		local due = {}
		for i = #after_queue, 1, -1 do
			if after_queue[i].at <= clock_us then
				due[#due + 1] = table.remove(after_queue, i)
			end
		end
		for i = #due, 1, -1 do due[i].fn(unpack(due[i].args)) end
		run_steps(0.05)
	end
end

local function make_player(name, window)
	local p = {_name = name, _window = window, huds = {}, writes = 0, meta = {}}
	function p:get_player_name() return self._name end
	function p:is_player() return true end
	function p:hud_add(def)
		local id = #self.huds + 1
		self.huds[id] = deep_copy(def)
		return id
	end
	function p:hud_change(id, stat, value)
		self.writes = self.writes + 1
		self.huds[id][stat] = deep_copy(value)
	end
	function p:get_pos() return nil end
	-- The inventory views (Round 44) read the lists' sizes: main only.
	function p:get_inventory()
		return {get_size = function(_, list) return list == "main" and 32 or 0 end}
	end
	function p:get_meta()
		local meta = self.meta
		return {
			get_int = function(_, key) return tonumber(meta[key]) or 0 end,
			set_int = function(_, key, value) meta[key] = value end,
			get_string = function(_, key) return meta[key] or "" end,
			set_string = function(_, key, value) meta[key] = value end,
		}
	end
	players[name] = p
	return p
end

------------------------------------------------------------------------------
-- 1. Message feed.
------------------------------------------------------------------------------
grug_core = {}
dofile("mods/CORE/grug_core/hud_layout.lua")
dofile("mods/CORE/grug_core/item_names.lua")
dofile("mods/CORE/grug_core/feed.lua")
local layout = grug_core.hud_layout

-- Placement: lines sit above the status icon row (icons and captions) at
-- every GUI scale, so they never touch the skill row or any bar.
for _, window in ipairs({
	{real_hud_scaling = 1, real_gui_scaling = 1},
	{real_hud_scaling = 1, real_gui_scaling = 1.5},
	{real_hud_scaling = 1, real_gui_scaling = 2},
	{real_hud_scaling = 2, real_gui_scaling = 2},
}) do
	local hud, gui = window.real_hud_scaling, window.real_gui_scaling
	local icon_centre = layout.status_slot(1, 1, window)
	local icon_top = icon_centre.y - layout.STATUS_ICON / 2
	local line = math.ceil(layout.FEED_LINE * gui / hud)
	local low = layout.feed_line_offset(1, window)
	local top = layout.feed_line_offset(layout.FEED_LINES, window)
	local tag = ("gui %.1f hud %.1f"):format(gui, hud)
	check(low.y + line / 2 <= icon_top - 4, "feed lowest line clears the icon row, " .. tag)
	check(low.y < layout.rows.skill.top, "feed above the skill row, " .. tag)
	eq(low.y - top.y, (layout.FEED_LINES - 1) * line, "feed line pitch, " .. tag)
	check(top.y - line / 2 > -400, "feed stays in the lower screen part, " .. tag)
end
print(("feed lines at GUI scale 1: centres y = %d, %d, %d (status icon top %d, skill row %d..%d)")
	:format(layout.feed_line_offset(1).y, layout.feed_line_offset(2).y,
		layout.feed_line_offset(3).y, layout.status_slot(1, 1).y - layout.STATUS_ICON / 2,
		layout.rows.skill.top, layout.rows.skill.bottom))

core.registered_items["grug_mobs:leather"] = {description = "Light Leather\nCrafting material"}
core.registered_items["grug_mobs:meat_raw"] = {description = "Raw Meat"}
local alice = make_player("alice", {real_hud_scaling = 1, real_gui_scaling = 1})
for _, fn in ipairs(callbacks.join) do fn(alice) end
eq(#alice.huds, 4, "join adds three feed lines and the banner")
local function line_text(p, slot) return p.huds[slot].text end
local function line_color(p, slot) return p.huds[slot].number end
local C = grug_core.FEED_COLOR

check(grug_core.feed(alice, "quest", "Small Boar 3/10", "quest:a"), "feed returns true")
eq(line_text(alice, 1), "Small Boar 3/10", "single line at the bottom")
eq(line_color(alice, 1), C.quest, "quest colour")
eq(C.combat, 0xaaaaaa, "combat notices are grey")
eq(line_text(alice, 2), "", "upper slot empty")
advance(0.2)
grug_core.feed(alice, "loot", "+1 Bone")
eq(line_text(alice, 1), "+1 Bone", "newest line at the bottom")
eq(line_text(alice, 2), "Small Boar 3/10", "older line moves up")
advance(0.2)
grug_core.feed(alice, "quest", "Small Boar 4/10", "quest:a")
eq(line_text(alice, 1), "Small Boar 4/10", "keyed line replaces its own previous line")
eq(line_text(alice, 2), "+1 Bone", "replacement moves to the bottom")
eq(line_text(alice, 3), "", "replacement leaves no duplicate")
grug_core.feed(alice, "notice", "Line C")
grug_core.feed(alice, "notice", "Line D")
eq(line_text(alice, 1), "Line D", "four lines: newest bottom")
eq(line_text(alice, 3), "Small Boar 4/10", "four lines: oldest dropped")
eq(line_text(alice, 2), "Line C", "four lines: middle line")
check(not grug_core.feed(alice, "notice", ""), "empty text refused")
check(not grug_core.feed({get_player_name = function() return "ghost" end}, "xp", "x"),
	"player without a feed refused")

-- Expiry and darkening: "Line D" was posted at t; dark from t+2.0, gone at t+2.5.
local posted = clock_us
advance(1.9)
eq(line_color(alice, 1), C.notice, "full colour before the last 0.5 s")
advance(0.25)
eq(line_color(alice, 1), grug_core.feed_darker(C.notice), "darkened in the last 0.5 s")
advance(0.4)
check(clock_us - posted >= 2500000, "clock past the lifetime")
eq(line_text(alice, 1), "", "expired lines are cleared")
local writes = alice.writes
advance(1)
eq(alice.writes, writes, "an idle feed writes nothing")

-- XP merge: within 1.5 s summed, later a new line.
grug_core.feed_xp(alice, 40)
advance(0.5)
grug_core.feed_xp(alice, 90)
eq(line_text(alice, 1), "+130 XP", "XP within 1.5 s is summed")
eq(line_text(alice, 2), "", "summed XP stays one line")
eq(line_color(alice, 1), C.xp, "XP colour")
advance(1.6)
grug_core.feed_xp(alice, 35)
eq(line_text(alice, 1), "+35 XP", "XP after the merge window starts a new line")
eq(line_text(alice, 2), "+130 XP", "the older sum stays until it expires")
check(not grug_core.feed_xp(alice, 0), "zero XP posts nothing")

-- Loot merge per item while the line is shown.
advance(3)
grug_core.feed_item(alice, ItemStack("grug_mobs:leather 2"), 2)
grug_core.feed_item(alice, "grug_mobs:meat_raw", 1)
advance(1)
grug_core.feed_item(alice, ItemStack("grug_mobs:leather"), 1)
eq(line_text(alice, 1), "+3 Light Leather", "loot merged per item, newest at the bottom")
eq(line_text(alice, 2), "+1 Raw Meat", "another item keeps its own line")
eq(line_color(alice, 1), C.loot, "loot colour")
advance(3)
grug_core.feed_item(alice, "grug_mobs:leather", 1)
eq(line_text(alice, 1), "+1 Light Leather", "a gone line does not merge again")

-- Fishing kind colour.
grug_core.feed(alice, "fish", "Caught Silver Trout (+25 XP)")
eq(line_color(alice, 1), C.fish, "fish colour")

-- Banner.
check(grug_core.banner(alice, "Reached level 5!", 0xffd100), "banner shown")
eq(alice.huds[4].text, "Reached level 5!", "banner text")
eq(alice.huds[4].size and alice.huds[4].size.x, 2, "banner is large")
advance(3.1)
eq(alice.huds[4].text, "", "banner clears after its time")

-- Item pickup: the wrapped entity callback reports what left the ground.
eq(grug_core.picked_up_count("grug_mobs:leather 5", ""), 5, "all picked up")
eq(grug_core.picked_up_count("grug_mobs:leather 5", "grug_mobs:leather 2"), 3, "partial pickup")
eq(grug_core.picked_up_count("grug_mobs:leather 5", "grug_mobs:leather 5"), 0, "nothing picked up")
local entity_def = {on_punch = function(self, hitter)
	if hitter._full then return end
	self.itemstring = self._rest or ""
end}
core.registered_entities["__builtin:item"] = entity_def
for _, fn in ipairs(callbacks.mods_loaded) do fn() end
advance(3)
local ent = setmetatable({itemstring = "grug_mobs:leather 4", _rest = "grug_mobs:leather 1"},
	{__index = entity_def})
ent:on_punch(alice)
eq(line_text(alice, 1), "+3 Light Leather", "pickup of 3 of 4 reported")
alice._full = true
ent:on_punch(alice)
eq(line_text(alice, 1), "+3 Light Leather", "a refused pickup reports nothing")
alice._full = nil

-- Cost (a comparison, not a gate): one post plus the expiry passes it causes.
do
	advance(3)
	local before_writes = alice.writes
	local started = os.clock()
	for i = 1, 2000 do
		grug_core.feed_xp(alice, 10)
		if i % 20 == 0 then grug_core.feed(alice, "quest", "Small Boar " .. i, "quest:x") end
		run_steps(0.1)
	end
	local elapsed = os.clock() - started
	print(("feed cost: %.1f us per post incl. one expiry pass, %.2f HUD writes per post (stub engine)")
		:format(elapsed / 2100 * 1e6, (alice.writes - before_writes) / 2100))
	advance(3)
end

------------------------------------------------------------------------------
-- 2. grug_xp: feed instead of chat.
------------------------------------------------------------------------------
local fed_xp, banners = {}, {}
local real_feed_xp, real_banner = grug_core.feed_xp, grug_core.banner
grug_core.feed_xp = function(p, amount) fed_xp[#fed_xp + 1] = amount; return real_feed_xp(p, amount) end
grug_core.banner = function(p, text, color) banners[#banners + 1] = text; return real_banner(p, text, color) end
dofile("mods/PLAYER/grug_xp/init.lua")
local bob = make_player("bob", {real_hud_scaling = 1, real_gui_scaling = 1})
for _, fn in ipairs(callbacks.join) do fn(bob) end
chat = {}
grug_xp.add_xp(bob, 200, "kill")
eq(fed_xp[1], 200, "kill XP reaches the feed")
eq(#banners, 0, "no banner below the next level")
grug_xp.add_xp(bob, 50, "kill") -- 250 >= 240, level 2 (Round 28 ruling 31)
eq(fed_xp[2], 50, "second grant reaches the feed")
eq(banners[1], "Reached level 2!", "level-up is a banner")
grug_xp.award_gathering(bob, "fish", 10, true)
eq(#fed_xp, 2, "a quiet award posts no XP line")
eq(#chat, 0, "nothing goes to chat")

------------------------------------------------------------------------------
-- 3. Quest progress lines.
------------------------------------------------------------------------------
local fed = {}
grug_core.feed = function(p, kind, text, key)
	fed[#fed + 1] = {kind = kind, text = text, key = key}
	return true
end
local journal_state
grug_quests = {MAX_TRACKED = 10, registered_npcs = {elder = {title = "Elder Maren"}},
	-- npc.lua's list helpers (Round 35), checked in tools/r35_f.
	list_entry = function(title, _, repeatable) return fs_escape(title .. (repeatable and " (R)" or "")) end,
	status_tooltip = function() return "" end,
	register_on_change = function(fn) grug_quests._changed = fn end,
	journal = function() return deep_copy(journal_state) end,
	-- The tracker builds the journal only when this key changes (Round 30).
	journal_key = function()
		local parts = {}
		for _, quest in ipairs(journal_state.quests) do
			parts[#parts + 1] = quest.id
			for _, objective in ipairs(quest.objectives) do parts[#parts + 1] = objective.count end
		end
		return table.concat(parts, " "), ""
	end}
core.registered_entities["grug_mobs:small_boar"] = {description = "Small Boar"}
grug_mobs = {} -- no sub-types here: labels read the entity description
dofile("mods/PLAYER/grug_quests/labels.lua")
dofile("mods/PLAYER/grug_quests/hud.lua")
local function quest(id, objectives) return {id = id, objectives = objectives, ready = false} end
local boar = {type = "kill", mobs = {"grug_mobs:small_boar"}, count = 3, required = 10}
local axe = {type = "item", item = "grug_mobs:leather", count = 0, required = 1}
eq(grug_quests.feed_text(quest("q1", {boar})), "Small Boar 3/10", "kill line text")
eq(grug_quests.feed_text(quest("q2", {axe, {type = "talk", npc = "elder", count = 1, required = 1}})),
	"Light Leather 0/1, Elder Maren 1/1", "multi-objective line text")
local long = quest("q9", {deep_copy(boar), deep_copy(axe), {type = "talk", npc = "elder", count = 0, required = 1}})
local cut = grug_quests.feed_text(long)
check(#cut <= grug_core.hud_layout.QUEST_WRAP and cut:sub(-3) == "...",
	"a long quest line is cut like a tracker line (" .. cut .. ")")
local carol = make_player("carol", nil)
journal_state = {quests = {quest("q1", {boar})}, tracked = {}, hud_enabled = true}
for _, fn in ipairs(callbacks.join) do fn(carol) end
eq(#fed, 0, "first sight after join posts nothing")
journal_state.quests[1].objectives[1].count = 4
grug_quests._changed(carol)
eq(#fed, 1, "a kill credit posts one line")
eq(fed[1] and fed[1].text, "Small Boar 4/10", "progress text")
eq(fed[1] and fed[1].key, "quest:q1", "keyed per quest")
eq(fed[1] and fed[1].kind, "quest", "quest kind")
journal_state.quests[2] = quest("q2", {deep_copy(axe)})
journal_state.quests[2].objectives[1].count = 1
grug_quests._changed(carol)
eq(#fed, 1, "a newly accepted quest posts nothing")
-- The 0.5 s pass refreshes each player in one of five 0.1 s slots.
local function half_second() for _ = 1, 6 do run_steps(0.1) end end
journal_state.quests[2].objectives[1].count = 0
half_second()
eq(#fed, 1, "a falling item count is silent")
journal_state.quests[2].objectives[1].count = 1
half_second()
eq(fed[2] and fed[2].text, "Light Leather 1/1", "an item gain posts through the 0.5 s pass")
grug_core.feed = nil

------------------------------------------------------------------------------
-- 4. The quest log.
------------------------------------------------------------------------------
local pages, contexts = {}, {}
sfinv = {pages = pages, pages_unordered = {}, contexts = contexts,
	register_page = function(name, def) def.name = name; pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def end,
	override_page = function(name, def) pages[name] = def end,
	get_page = function() return "x" end, set_page = function() end,
	get_or_create_context = function(p) contexts[p:get_player_name()] =
		contexts[p:get_player_name()] or {}; return contexts[p:get_player_name()] end,
	set_player_inventory_formspec = function() end,
	get_formspec = function() return "" end,
	get_nav_fs = function() return "tabheader[0,0;sfinv_nav_tabs;Character,Quests;1;true;false]" end,
}
grug_inventory = {BAG_COUNT = 0}
dofile("mods/PLAYER/grug_inventory/ui.lua")
grug_money = {format = function(c) return c .. " copper" end, get = function() return 0 end,
	register_on_change = function() end,
	deposit_location = function() return "detached:grug_money_deposit_x", "deposit" end}
grug_quests.journal = function()
	return {quests = {{id = "q1", title = "Boar Trouble", description = "Boars eat our crops.",
		objectives = {{type = "kill", mobs = {"grug_mobs:small_boar"}, count = 3, required = 10}},
		ready = false, npc = "elder", rewards = {xp = 40, copper = 5, items = {"grug_mobs:leather 2"}},
		reward_xp = 40}},
		tracked = {"q1"}, hud_enabled = true}
end
-- Since Round 44 the quest log is the map window's quest box
-- (grug_map/quest_box.lua) in real coordinates: labels and checkboxes are
-- placed by their vertical centre, buttons, the list and text fields by
-- their top-left corner (guiFormSpecMenu.cpp, real_coordinates). The window
-- around it is tools/r44_mq's.
grug_quests.registered_quests = {q1 = {level = 3, zone = "dawnmere"}}
local saved_zones = rawget(_G, "grug_zones")
grug_zones = {get = function() return {display_name = "Dawnmere Fields"} end}
local quest_box = dofile("mods/PLAYER/grug_map/quest_box.lua")
local RECT = {x = 13.4, y = 1.05, w = 7.0, h = 10.7}
local function box_fs(session)
	session = session or {}
	session.quest_selected = "q1" -- nothing is preselected since Round 44
	return quest_box.content(session, grug_quests.journal(carol), RECT)
end
local quest_fs = box_fs()
formspec_ok(quest_fs, "quest log")
local function nums(text) local out = {}
	for v in text:gmatch("[%d.]+") do out[#out + 1] = tonumber(v) end
	return out
end
local function rect_of(fs, pattern)
	local g = nums(fs:match(pattern) or "")
	return g[1] and {left = g[1], top = g[2], right = g[1] + g[3], bottom = g[2] + g[4]} or nil
end
local function near(a, b) return a and b and math.abs(a - b) < 0.011 end
local list = rect_of(quest_fs, "textlist%[([%d.,;]+);grug_quest_list;")
local text = rect_of(quest_fs, "textarea%[([%d.,;]+);;;")
local textareas = 0
for _ in quest_fs:gmatch("textarea%[") do textareas = textareas + 1 end
eq(textareas, 1, "one text field for description, objectives and rewards (Round 32)")
check(list and text and text.top - list.bottom >= 0.5, "the text field below the list box")
check(list and near(list.left, text.left) and near(list.right, text.right),
	"list and text share the column's edges")
check(text.right <= RECT.x + RECT.w and text.bottom <= RECT.y + RECT.h, "the text inside the column")
local title_x = tonumber(quest_fs:match("label%[([%d.]+),[%d.]+;Boar Trouble%]"))
check(near(title_x, text.left), "title label starts where the text starts")
has(quest_fs, "Level 3 · Dawnmere Fields", "the level and zone line")
has(quest_fs, "Small Boar: 3/10", "objective text unchanged")
local detail = quest_fs:match("textarea%[[%d.,;]+;;;(.-)%]")
local d_desc = detail and detail:find("Boars eat our crops.\n\n", 1, true)
local d_obj = detail and detail:find("Small Boar: 3/10", 1, true)
local d_rew = detail and detail:find("\n\nRewards: 40 XP\\, 5 copper\\, 2 × Light Leather", 1, true)
check(d_desc == 1 and d_obj and d_rew and d_obj < d_rew,
	"one field: description, empty line, objective, empty line, rewards (" .. tostring(detail) .. ")")
-- No hard wrap: a description longer than 58 characters stays one line for
-- the textarea to wrap at its own width.
local long_description = ("Boars trample the fields east of the village every night "):rep(2)
local plain_journal = grug_quests.journal
grug_quests.journal = function()
	local journal = plain_journal()
	journal.quests[1].description = long_description
	return journal
end
has(box_fs(), long_description .. "\n\n", "the description reaches the text field unwrapped")
grug_quests.journal = plain_journal
-- "Track on HUD" and Abandon share one row at the list box's bottom; the
-- buttons end at the list's right edge.
local function button_rect(fs, field) return rect_of(fs, "button%[([%d.,;]+);" .. field .. ";") end
local track_y = tonumber(quest_fs:match("checkbox%[[%d.]+,([%d.]+);grug_quest_track;"))
local track_x = tonumber(quest_fs:match("checkbox%[([%d.]+),[%d.]+;grug_quest_track;"))
local abandon = button_rect(quest_fs, "grug_quest_abandon")
check(abandon and near((abandon.top + abandon.bottom) / 2, track_y), "row: Abandon on the checkbox row")
check(abandon and near(abandon.right, list.right), "row: Abandon ends at the list's right edge")
check(near(track_x, list.left), "row: Track on HUD starts at the list's left edge")
check(abandon and abandon.top - list.bottom >= 0.1, "row: below the list")
check(abandon and abandon.bottom < text.top, "row: above the text box")
local confirm_fs = box_fs({quest_abandon = "q1"})
formspec_ok(confirm_fs, "quest log, confirm abandon")
local confirm = button_rect(confirm_fs, "grug_quest_confirm")
local cancel = button_rect(confirm_fs, "grug_quest_cancel")
check(confirm and cancel and cancel.left - confirm.right > 0.1, "Confirm abandon left of Cancel")
check(cancel and near(cancel.right, list.right) and near(confirm.top, abandon.top),
	"confirm row: in the Abandon row, ending at the list's right edge")
-- "Track on HUD" (about 125 px x gui_scaling with its box) would reach into
-- Confirm abandon at a large GUI scale, so the confirmation takes the row
-- alone.
check(not confirm_fs:find("grug_quest_track", 1, true),
	"no Track on HUD checkbox while the abandon confirmation is shown")
-- The ready line sits below the text field, inside the box.
grug_quests.journal = function()
	local journal = plain_journal()
	journal.quests[1].ready = true
	return journal
end
local ready_fs = box_fs()
local ready_y = tonumber(ready_fs:match("label%[[%d.]+,([%d.]+);Ready to return to Elder Maren%.%]"))
local ready_text = rect_of(ready_fs, "textarea%[([%d.,;]+);;;")
check(ready_y and ready_text and ready_y - 0.2 >= ready_text.bottom and ready_y <= RECT.y + RECT.h,
	"the ready line sits below the text field")
grug_quests.journal = plain_journal
grug_zones = saved_zones

------------------------------------------------------------------------------
-- 5. Riding Trainer.
------------------------------------------------------------------------------
grug_mounts = {}
grug_core.FLIGHT_CEILING = 600
grug_core.FLASH_COLOR = {error = 0xff4444, notice = 0xf0e6c8}
dofile("mods/PLAYER/grug_mounts/catalog.lua")
local level = 20
grug_xp = {get_level = function() return level end}
grug_inventory.BAG_COUNT = 0
grug_classes = {register_on_race_chosen = function() end}
grug_factions = {register_on_faction_chosen = function() end}
dofile("mods/PLAYER/grug_mounts/state.lua")
grug_mobs = {register_start_socket_role = function() end}
dofile("mods/PLAYER/grug_mounts/trainer.lua")
local rider = make_player("rider", nil)
local function set_owned(land, flight)
	rider.meta["grug_mounts:land_tier"] = land
	rider.meta["grug_mounts:flight_tier"] = flight
end
local function states()
	local out = {}
	for tier = 1, 4 do out[tier] = (grug_mounts.tier_state(rider, tier)) end
	return table.concat(out, ",")
end
set_owned(0, 0); level = 10
eq(states(), "level,level,level,level", "level 10: everything needs a level")
level = 20
eq(states(), "buy,level,level,level", "level 20: first tier for sale")
level = 31
eq(states(), "buy,previous,level,level", "level 31 without tier 1: learn it first")
set_owned(1, 0)
eq(states(), "owned,buy,level,level", "level 31 with tier 1")
set_owned(2, 0); level = 60
eq(states(), "owned,owned,buy,previous", "level 60 with both land tiers")
set_owned(2, 4)
eq(states(), "owned,owned,owned,owned", "everything owned")
local rows = {
	{id = 1, name = "Apprentice Riding", level = 15, state = "owned"},
	{id = 2, name = "Journeyman Riding", level = 30, state = "buy", price = "15 silver"},
	{id = 3, name = "Expert Riding", level = 45, state = "level"},
	{id = 4, name = "Master Riding", level = 60, state = "previous", previous = "Expert Riding"},
}
local trainer_fs = grug_mounts.trainer_formspec(rows, {ok = false, text = "You do not have enough money."})
formspec_ok(trainer_fs, "trainer")
has(trainer_fs, "button[5.0,2.05;3.0,0.65;buy_2;Buy 15 silver]", "buy button with price")
lacks(trainer_fs, "buy_1", "no button for an owned tier")
lacks(trainer_fs, "buy_3", "no button below the level")
lacks(trainer_fs, "buy_4", "no button without the previous tier")
has(trainer_fs, fs_escape(colorize("#7ae08a", "Owned")), "owned state")
has(trainer_fs, fs_escape(colorize("#8a8a8a", "Requires level 45")), "level state greyed")
has(trainer_fs, fs_escape(colorize("#8a8a8a", "Learn Expert Riding first")), "previous state greyed")
has(trainer_fs, fs_escape(colorize("#8a8a8a", "Master Riding (L60)")), "blocked tier name greyed")
has(trainer_fs, "Apprentice Riding (L15)", "owned tier name plain")
has(trainer_fs, fs_escape(colorize("#ff6b6b", "You do not have enough money.")), "purchase error in the form")
for tier = 1, 4 do has(trainer_fs, rows[tier].name, "all four tiers listed: " .. tier) end

------------------------------------------------------------------------------
-- 6. Character page: Damage reduction, Professions tab.
------------------------------------------------------------------------------
grug_jobs = {}
dofile("mods/PLAYER/grug_jobs/registry.lua")
local char_level = 15
grug_xp = {get_level = function() return char_level end,
	register_on_level_change = function() end}
local refreshed = 0
grug_inventory.refresh = function() refreshed = refreshed + 1 end
dofile("mods/PLAYER/grug_jobs/state.lua")
dofile("mods/PLAYER/grug_jobs/character_tab.lua")
-- The Character page's mode area the body is drawn into (Round 44).
local AREA = {x = 0.4, y = 1.25, w = 7.5, h = 7.8}
local smith = make_player("smith", nil)
eq(grug_jobs.professions_formspec(grug_jobs.profession_overview(smith), AREA):find("No professions learned", 1, true) ~= nil,
	true, "empty professions state")
smith.meta["grug_jobs:primary:1"] = "weaponsmith"
smith.meta["grug_jobs:level:weaponsmith"] = 2
smith.meta["grug_jobs:crafts:weaponsmith"] = 7
smith.meta["grug_jobs:learned:cooking"] = 1
smith.meta["grug_jobs:level:cooking"] = 1
smith.meta["grug_jobs:crafts:cooking"] = 10
local overview = grug_jobs.profession_overview(smith)
eq(#overview, 2, "two known professions")
eq(overview[1].name, "Weaponsmith", "primary first")
eq(overview[1].tier, 2, "weaponsmith tier")
eq(overview[1].crafts, 7, "crafts in tier")
eq(overview[1].needed, 15, "needed for the next tier")
eq(overview[1].capped, false, "7/15 at level 15: crafting, not the level, is missing")
eq(overview[2].capped, false, "cooking T1 is not capped at level 15")
local prof_fs = grug_jobs.professions_formspec(overview, AREA)
formspec_ok(prof_fs, "professions tab")
has(prof_fs, fs_escape("Weaponsmith — Tier 2"), "profession name and tier")
has(prof_fs, fs_escape("Crafts: 7/15 toward tier 3"), "tier progress")
lacks(prof_fs, "Capped by your level", "no cap note while crafts are missing")
smith.meta["grug_jobs:crafts:weaponsmith"] = 15
overview = grug_jobs.profession_overview(smith)
eq(overview[1].capped, true, "15/15 at level 15: the level blocks tier 3")
-- The note wraps to the mode area's width (Round 44).
local capped_fs = grug_jobs.professions_formspec(overview, AREA)
has(capped_fs, fs_escape(colorize("#f0c75e", "Capped by your level: reach level 21, then craft")),
	"cap note when the level blocks")
has(capped_fs, fs_escape(colorize("#f0c75e", "once more for tier 3.")), "cap note, wrapped")
smith.meta["grug_jobs:crafts:weaponsmith"] = 7
has(prof_fs, fs_escape("Crafts: 10/10 toward tier 2"), "cooking progress")
char_level = 5
overview = grug_jobs.profession_overview(smith)
eq(overview[2].capped, true, "level 5 caps cooking T1")
has(grug_jobs.professions_formspec(overview, AREA),
	fs_escape(colorize("#f0c75e", "Capped by your level: reach level 11, then craft")),
	"saturated cap note")
char_level = 60
smith.meta["grug_jobs:level:weaponsmith"] = 6
has(grug_jobs.professions_formspec(grug_jobs.profession_overview(smith), AREA),
	"Highest tier reached.", "T6 needs nothing more")
char_level = 15
smith.meta["grug_jobs:level:weaponsmith"] = 2

-- The page itself.
grug_inventory.equipment_slots = {}
player_api = {registered_models = {["character.b3d"] = {textures = {"character.png"}}}}
-- Lane A7's hand slots and Scout quiver read the class (a Warrior: no quiver).
grug_inventory.has_quiver = function() return false end
grug_classes = {get_class_def = function() return {resource = "rage"} end,
	get_class = function() return "warrior" end,
	get_pool_breakdown = function() return {final = 120} end,
	get_crit_chance = function() return 0.05 end, get_dodge_chance = function() return 0.05 end}
grug_core.get_armor_rating = function() return 10 end
grug_core.armor_reduction = function() return 0.123 end
grug_core.get_player_level = function() return 15 end
grug_core.register_on_equipment_change = function() end
grug_core.register_on_status_modifiers_changed = function() end
grug_core.status_effects = function() return {} end
grug_core.status_icons = {remaining_text = function() return "" end}
function smith:get_properties() return {visual = "mesh", mesh = "character.b3d", textures = {"character.png"}} end
function smith:get_inventory() return {get_stack = function() return ItemStack("") end,
	get_size = function(_, list) return list == "main" and 32 or 0 end} end
local resent = 0
sfinv.set_player_inventory_formspec = function() resent = resent + 1 end
dofile("mods/PLAYER/grug_inventory/pages.lua")
local character = pages["grug_inventory:character"]
local context = {page = "grug_inventory:character", grug_character_tab = "stats"}
contexts.smith = context
local stats_fs = character:get(smith, context)
formspec_ok(stats_fs, "character stats")
has(stats_fs, "label[0.40,3.10;Damage reduction: 12.3%]", "Damage reduction label")
lacks(stats_fs, "Own-level", "old label gone")
has(stats_fs, fs_escape("Armor reduction against an enemy of your level."), "tooltip text")
has(stats_fs, "tooltip[0.40,2.85;5.0,0.50;", "tooltip covers the label line")
has(stats_fs, "grug_character_professions;Professions]", "Professions tab button")
character:on_player_receive_fields(smith, context, {grug_character_professions = "Professions"})
eq(context.grug_character_tab, "professions", "Professions tab selected")
local tab_fs = character:get(smith, context)
formspec_ok(tab_fs, "character professions tab")
has(tab_fs, fs_escape("Weaponsmith — Tier 2"), "Professions tab body")
lacks(tab_fs, "Damage reduction", "stats hidden on the Professions tab")
resent = 0
grug_jobs.record_craft(smith, "weaponsmith", 2)
eq(resent, 1, "a counted craft refreshes the open Professions tab")
context.grug_character_tab = "stats"
grug_jobs.record_craft(smith, "weaponsmith", 2)
eq(resent, 1, "no refresh while another tab is open")

-- The Scout's quiver cell (Round 41 ruling 6): above 100 arrows it shows the
-- true total, a cover over the engine's count corner (sized for the window:
-- a three-digit count at 30 x 20 px per real_gui_scaling against the
-- slot size) and an item_image of the cell's item with the total, both after
-- the list[]; at 100 or fewer the engine's own count stays alone.
core.registered_items["grug_gear:arrow"] = {description = "Arrow", stack_max = 100}
grug_inventory.QUIVER_LIST = "grug_quiver_content"
grug_inventory.quiver_capacity = function() return 500 end
local quiver_total = 0
grug_inventory.quiver_count = function() return quiver_total end
grug_inventory.has_quiver = function(p) return p:get_player_name() ~= "smith" end
-- The engine's real-coordinate formspec layout (guiFormSpecMenu.cpp; the
-- Character page is real coordinates since Round 44), written out here
-- independently of pages.lua: calculateImgsize (padding 0.05 on each side;
-- getImgsize with the padded screen, its integer min_dim / 15; capped by
-- fitx / fity for the form's size[13.500,13.673], so fit = padded size /
-- that size; truncated to v2s32), a position trunc(pos * imgsize)
-- (getRealCoordinateBasePos :267-271), an image or item_image size
-- trunc(size * imgsize) (getRealCoordinateGeometry :273-276), a list slot
-- imgsize from that base (parseList). The window information a client sends
-- is clientdynamicinfo.cpp's: max_formspec_size = size / getImgsize(size).
local function get_imgsize(w, h, gui_scaling, density)
	local min_dim = math.floor(math.min(w, h))
	return math.max(math.floor(min_dim / 15) * gui_scaling, 0.5555 * density * 96 * gui_scaling)
end
local function engine_window(w, h, gui_scaling)
	local prefer = get_imgsize(w, h, gui_scaling, 1)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / prefer, y = h / prefer},
		real_gui_scaling = gui_scaling, real_hud_scaling = gui_scaling}
end
local function real_layout(w, h, gui_scaling)
	local pw, ph = w * 0.9, h * 0.9
	local img = math.floor(math.min(get_imgsize(pw, ph, gui_scaling, 1),
		pw / 13.5, ph / 13.673))
	return {img = img, font = 16 * gui_scaling}
end
local function rect_of(layout, x, y, w, h)
	local x0 = math.floor(x * layout.img)
	local y0 = math.floor(y * layout.img)
	return {x0 = x0, y0 = y0, x1 = x0 + math.floor(w * layout.img), y1 = y0 + math.floor(h * layout.img)}
end
local NORMAL_WINDOW = engine_window(1920, 1080, 1)
local LARGE_WINDOW = engine_window(1920, 1080, 2)
-- A small browser window of the web build at gui_scaling 1.5: the form-fit
-- cap holds, so the count is largest against the slot.
local SMALL_WINDOW = engine_window(1280, 720, 1.5)
local function quiver_page(name, window, total)
	local archer = make_player(name, window)
	function archer:get_properties() return smith:get_properties() end
	function archer:get_inventory()
		return {get_stack = function(_, list, index)
			if list == grug_inventory.QUIVER_LIST and index == 1 and total > 0 then
				return ItemStack("grug_gear:arrow " .. math.min(total, 100))
			end
			return ItemStack("")
		end, get_size = function(_, list) return list == "main" and 32 or 0 end}
	end
	quiver_total = total
	contexts[name] = {page = "grug_inventory:character", grug_character_tab = "stats"}
	local fs = character:get(archer, contexts[name])
	formspec_ok(fs, "quiver " .. name)
	return fs
end
local QUIVER_CELL = "list[current_player;grug_quiver_content;8.50,6.10;1,1;]"
local COVER = "[fill:8x8:#1f1f1f]"
-- Where the engine draws the cover and the count overlay for a page, in
-- pixels, against the slot and the engine's own count "100" in its corner
-- (drawItemStack: right- and bottom-aligned at the slot's corner; the
-- default font's digits about 0.556 em wide, its line about 1.2 em high).
local function overlay_ok(fs, layout, label)
	local cx, cy, cw, ch = fs:match("image%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);%[fill:8x8:#1f1f1f%]")
	local ix, iy, iw, ih = fs:match("item_image%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_gear:arrow %d+%]")
	if not check(cx and ix, label .. ": cover and count overlay present") then return end
	local slot = rect_of(layout, 8.5, 6.1, 1, 1)
	local cover = rect_of(layout, tonumber(cx), tonumber(cy), tonumber(cw), tonumber(ch))
	local image = rect_of(layout, tonumber(ix), tonumber(iy), tonumber(iw), tonumber(ih))
	local count_w = math.ceil(3 * 0.556 * layout.font)
	local count_h = math.ceil(1.2 * layout.font)
	local detail = (" (slot %d,%d-%d,%d, cover %d,%d-%d,%d, count %dx%d)"):format(slot.x0, slot.y0,
		slot.x1, slot.y1, cover.x0, cover.y0, cover.x1, cover.y1, count_w, count_h)
	check(image.x0 == slot.x0 and image.y0 == slot.y0 and image.x1 == slot.x1 and image.y1 == slot.y1,
		label .. ": the item_image lies exactly on the slot" .. detail)
	check(cover.x0 >= slot.x0 and cover.y0 >= slot.y0, label .. ": the cover starts inside the slot" .. detail)
	check(cover.x0 <= slot.x1 - count_w and cover.y0 <= slot.y1 - count_h,
		label .. ": the cover hides the engine's count" .. detail)
	check(cover.x1 >= slot.x1 and cover.y1 >= slot.y1 and cover.x1 <= slot.x1 + 1 and
		cover.y1 <= slot.y1 + 1, label .. ": the cover reaches the slot's corner, at most onto its 1 px border" .. detail)
end
local fs100 = quiver_page("archer100", NORMAL_WINDOW, 100)
has(fs100, QUIVER_CELL, "quiver 100: the cell")
has(fs100, "label[9.60,6.35;Quiver\n100/500]", "quiver 100: the total beside it")
lacks(fs100, "item_image[", "quiver 100: no overlay")
lacks(fs100, COVER, "quiver 100: no cover")
local fs101 = quiver_page("archer101", NORMAL_WINDOW, 101)
local count101 = "item_image[8.50,6.10;1,1;grug_gear:arrow 101]"
has(fs101, count101, "quiver 101: the total on the cell")
overlay_ok(fs101, real_layout(1920, 1080, 1), "quiver 101, 1920x1080 gui_scaling 1")
local at_list, at_cover, at_count = fs101:find(QUIVER_CELL, 1, true),
	fs101:find(COVER, 1, true), fs101:find(count101, 1, true)
check(at_list and at_cover and at_count and at_list < at_cover and at_cover < at_count,
	"quiver 101: list, then cover, then count (drawn on top, clicks reach the list)")
local fs500 = quiver_page("archer500", LARGE_WINDOW, 500)
has(fs500, "item_image[8.50,6.10;1,1;grug_gear:arrow 500]", "quiver 500: the total on the cell")
has(fs500, "label[9.60,6.35;Quiver\n500/500]", "quiver 500: the total beside it")
overlay_ok(fs500, real_layout(1920, 1080, 2), "quiver 500, 1920x1080 gui_scaling 2")
overlay_ok(quiver_page("archer_small", SMALL_WINDOW, 250), real_layout(1280, 720, 1.5),
	"quiver 250, 1280x720 gui_scaling 1.5")
local fs_unknown = quiver_page("archer_join", nil, 181)
has(fs_unknown, "item_image[8.50,6.10;1,1;grug_gear:arrow 181]", "quiver 181: the total on the cell")
-- Without window information the cover must still hide the count in the
-- small window above, the largest count against the slot.
local cx, cy = fs_unknown:match("image%[([%d.]+),([%d.]+);[%d.]+,[%d.]+;%[fill")
local small = real_layout(1280, 720, 1.5)
local cover_at = rect_of(small, tonumber(cx) or 0, tonumber(cy) or 0, 0, 0)
local slot_small = rect_of(small, 8.5, 6.1, 1, 1)
check(cover_at.x0 <= slot_small.x1 - math.ceil(3 * 0.556 * small.font) and
	cover_at.y0 <= slot_small.y1 - math.ceil(1.2 * small.font),
	"quiver 181 without window information: the cover hides the count even in a small window")
local fs0 = quiver_page("archer0", NORMAL_WINDOW, 0)
lacks(fs0, "item_image[", "empty quiver: no overlay")
has(fs0, "grug_inventory_quiver.png", "empty quiver: the ghost")
grug_inventory.has_quiver = function() return false end

------------------------------------------------------------------------------
-- 7. Recipe books.
------------------------------------------------------------------------------
local function item(name, description) core.registered_items[name] = {description = description} end
item("grug_test:sword_t1", "Bronze Sword"); item("grug_test:sword_t2", "Iron Sword")
item("grug_test:sword_t3", "Steel Sword"); item("grug_test:bar", "Bar")
item("grug_test:plank", "Plank")
local book_recipes = {
	{profession = "weaponsmith", tier = 1, station = "forge", inputs = {"grug_test:bar"},
		output = "grug_test:sword_t1", output_name = "grug_test:sword_t1"},
	{profession = "weaponsmith", tier = 2, station = "forge", inputs = {"grug_test:bar"},
		output = "grug_test:sword_t2", output_name = "grug_test:sword_t2"},
	{profession = "weaponsmith", tier = 3, station = "forge", inputs = {"grug_test:bar"},
		output = "grug_test:sword_t3", output_name = "grug_test:sword_t3"},
}
grug_jobs.recipes_for = function(profession, station)
	local out = {}
	for _, recipe in ipairs(book_recipes) do
		if recipe.profession == profession and (station == nil or recipe.station == station) then
			out[#out + 1] = recipe
		end
	end
	return out
end
-- Basics tiers (Round 29 P4): a gear bracket beats the item-level band (ilvl
-- 50 is the T6 bracket, not T5), a bar takes its ingredient tier, an untiered
-- pick its bar's.
item("grug_test:abyss_bar", "Abyssal Bar"); item("grug_test:abyss_pick", "Abyssal Pick")
item("grug_test:abyss_sword", "Abyssal Sword")
core.registered_items["grug_test:abyss_sword"]._grug_bracket = 6
core.registered_items["grug_test:abyss_sword"]._grug_ilvl = 50
grug_jobs.register_ingredient_tier("grug_test:abyss_bar", 6)
local basics_crafts = {
	["grug_test:plank"] = {method = "normal", width = 1, items = {"grug_test:bar"}, output = "grug_test:plank 4"},
	["grug_test:abyss_bar"] = {method = "cooking", width = 1, items = {"grug_test:plank"}, output = "grug_test:abyss_bar"},
	["grug_test:abyss_pick"] = {method = "normal", width = 1, items = {"grug_test:abyss_bar", "grug_test:plank"},
		output = "grug_test:abyss_pick"},
	["grug_test:abyss_sword"] = {method = "normal", width = 1, items = {"grug_test:plank"}, output = "grug_test:abyss_sword"},
}
core.get_all_craft_recipes = function(name)
	return basics_crafts[name] and {basics_crafts[name]} or nil
end
dofile("mods/PLAYER/grug_jobs/ui.lua")
local basics_tiers = {}
for _, record in ipairs(grug_jobs.book_records(smith, "general")) do
	basics_tiers[#basics_tiers + 1] = record.output_name .. "=" .. record.tier
end
eq(table.concat(basics_tiers, " "), "grug_test:plank=1 grug_test:abyss_bar=6 grug_test:abyss_pick=6 " ..
	"grug_test:abyss_sword=6", "Basics tiers: plank 1, bar, pick and bracket-6 sword 6")
-- smith: Weaponsmith tier 2 at character level 15 (tier capped at 2).
local book_fs = grug_jobs.book_formspec(smith, "weaponsmith", nil, 1, "", nil, 1)
formspec_ok(book_fs, "weaponsmith book")
has(book_fs, "item_image_button[0.30,1.45;1,1;grug_test:sword_t1;grug_jobs_item_1;]", "T1 craftable button")
has(book_fs, "item_image_button[1.65,1.45;1,1;grug_test:sword_t2;grug_jobs_item_2;]", "T2 craftable button")
has(book_fs, "item_image[3.00,1.45;1,1;grug_test:sword_t3]", "T3 listed although locked")
has(book_fs, "box[3.00,1.45;1,1;#101010b0]", "T3 greyed")
has(book_fs, "image_button[3.00,1.45;1,1;blank.png;grug_jobs_item_3;;false;false]", "T3 still clickable")
has(book_fs, fs_escape("Locked: needs Weaponsmith tier 3 (character level 21+)."), "T3 tooltip says why")
has(book_fs, "label[0.30,4.02;" .. fs_escape("T1: 0 locked  T2: 0 locked  T3: 1 locked  " ..
	"T4: 0 locked  T5: 0 locked  T6: 0 locked") .. "]", "per-tier locked counts")
lacks(book_fs, "Undiscovered", "profession book has no undiscovered line")
local locked_fs = grug_jobs.book_formspec(smith, "weaponsmith", nil, 1, "", "grug_test:sword_t3", 1)
formspec_ok(locked_fs, "locked recipe view")
has(locked_fs, fs_escape("Locked: needs Weaponsmith tier 3 (character level 21+)."), "lock line in the recipe view")
local station_fs = grug_jobs.book_formspec(smith, "station", "forge", 1, "", nil, 1)
formspec_ok(station_fs, "forge station view")
lacks(station_fs, "grug_test:sword_t3", "station view lists only craftable recipes")
has(station_fs, "grug_test:sword_t2", "station view lists the unlocked tier")
local basics_fs = grug_jobs.book_formspec(smith, "general", nil, 1, "", nil, 1)
formspec_ok(basics_fs, "Basics")
has(basics_fs, "Undiscovered — T1: 0", "Basics keeps its undiscovered line")
has(basics_fs, "grug_test:plank", "Basics lists its recipe")
local counts = grug_jobs.book_locked_counts(smith, grug_jobs.book_records(smith, "weaponsmith"))
eq(table.concat(counts, ","), "0,0,1,0,0,0", "book_locked_counts")

------------------------------------------------------------------------------
-- 9. Slots that accept several items (Round 41 lane UI, ruling 4).
------------------------------------------------------------------------------
-- Groups of 1, 2, 3, 4 (five members, two sharing a label) and 5 items; corn
-- and apple have a Basics recipe of their own, so their icons are clickable.
local group_items = {
	testone = {{"grug_test:salt", "Salt"}},
	testtwo = {{"grug_test:potato", "Potato"}, {"grug_test:corn", "Corn"}},
	testthree = {{"grug_test:onion", "Onion"}, {"grug_test:garlic", "Garlic"},
		{"grug_test:leek", "Leek"}},
	testfour = {{"grug_test:berry_b", "Blueberry"}, {"grug_test:berry_a", "Blueberry"},
		{"grug_test:cherry", "Cherry"}, {"grug_test:raspberry", "Raspberry"},
		{"grug_test:strawberry", "Strawberry"}},
	testfive = {{"grug_test:pear", "Pear"}, {"grug_test:apple", "Apple"},
		{"grug_test:plum", "Plum"}, {"grug_test:fig", "Fig"}, {"grug_test:quince", "Quince"}},
}
for group, members in pairs(group_items) do
	for _, member in ipairs(members) do
		core.registered_items[member[1]] = {description = member[2] .. "\nFood",
			groups = {[group] = 1}}
	end
end
item("grug_test:stew", "Test Stew")
core.get_item_group = function(name, group)
	local def = core.registered_items[name]
	return def and def.groups and def.groups[group] or 0
end
basics_crafts["grug_test:stew"] = {method = "normal", width = 3, items = {"group:testtwo",
	"group:testthree", "group:testfour", "group:testfive", "group:testone"},
	output = "grug_test:stew"}
basics_crafts["grug_test:corn"] = {method = "normal", width = 1, items = {"grug_test:plank"},
	output = "grug_test:corn"}
basics_crafts["grug_test:apple"] = {method = "normal", width = 1, items = {"grug_test:bar"},
	output = "grug_test:apple"}
grug_jobs._reset_book_cache()
local book_shown
core.show_formspec = function(_, formname, formspec)
	if formname == "grug_jobs:book" then book_shown = formspec end
end
local stew_fs = grug_jobs.book_formspec(smith, "general", nil, 1, "", "grug_test:stew", 1)
formspec_ok(stew_fs, "multi-item slots")
-- Elements per kind, with their position and size.
local function slot_elements(fs, kind)
	local out = {}
	for x, y, w, h, rest in fs:gmatch(kind .. "%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);(.-)%]") do
		out[#out + 1] = {x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h),
			rest = rest}
	end
	return out
end
local function inside(e, cx, cy)
	return e.x >= cx - 1e-6 and e.y >= cy - 1e-6 and e.x + e.w <= cx + 0.82 + 1e-6 and
		e.y + e.h <= cy + 0.82 + 1e-6
end
local function cell_parts(fs, cx, cy)
	local parts = {icons = {}, buttons = {}, tooltips = {}, whole = {}}
	for _, e in ipairs(slot_elements(fs, "item_image")) do
		if inside(e, cx, cy) then
			if e.w < 0.82 then parts.icons[#parts.icons + 1] = e else parts.whole[#parts.whole + 1] = e end
		end
	end
	for _, e in ipairs(slot_elements(fs, "image_button")) do
		if inside(e, cx, cy) then parts.buttons[#parts.buttons + 1] = e end
	end
	for _, e in ipairs(slot_elements(fs, "tooltip")) do
		if inside(e, cx, cy) then parts.tooltips[#parts.tooltips + 1] = e end
	end
	return parts
end
local function near2(a, b) return math.abs(a - b) < 0.002 end
-- Icon offsets inside the cell, row by row.
local function offsets(parts, cx, cy)
	local out = {}
	for _, e in ipairs(parts.icons) do
		out[#out + 1] = ("%.3f,%.3f"):format(e.x - cx, e.y - cy)
	end
	return table.concat(out, " ")
end
local function icon_items(parts)
	local out = {}
	for _, e in ipairs(parts.icons) do out[#out + 1] = e.rest end
	return table.concat(out, " ")
end
local CELLS = {{1.25, 5.65}, {2.15, 5.65}, {3.05, 5.65}, {1.25, 6.55}, {2.15, 6.55}}
local two, three, four, five, one = cell_parts(stew_fs, unpack(CELLS[1])),
	cell_parts(stew_fs, unpack(CELLS[2])), cell_parts(stew_fs, unpack(CELLS[3])),
	cell_parts(stew_fs, unpack(CELLS[4])), cell_parts(stew_fs, unpack(CELLS[5]))
eq(offsets(two, 1.25, 5.65), "0.020,0.225 0.430,0.225", "2 items: two icons side by side")
eq(offsets(three, 2.15, 5.65), "0.020,0.020 0.430,0.020 0.225,0.430",
	"3 items: two above, one below")
eq(offsets(four, 3.05, 5.65), "0.020,0.020 0.430,0.020 0.020,0.430 0.430,0.430", "4 items: 2x2")
eq(offsets(five, 1.25, 6.55), "0.020,0.020 0.430,0.020 0.020,0.430", "5 items: three icons")
for _, parts in ipairs({two, three, four, five}) do
	for _, e in ipairs(parts.icons) do
		check(near2(e.w, 0.37) and near2(e.h, 0.37), "icons are 0.37 inside 0.41 quarters")
	end
	eq(#parts.whole, 0, "a multi-item slot draws no full-size icon")
end
has(stew_fs, "style_type[label;font_size=*0.8]label[1.710,7.165;+2]style_type[label;font_size=*1]",
	"5 items: \"+2\" in the fourth place, in a smaller font reset afterwards")
eq(#one.icons, 0, "1 item: no small icons")
eq(#one.whole, 1, "1 item: today's single icon")
eq(one.whole[1] and one.whole[1].rest, "grug_test:salt", "1 item: its only member")
-- Icon order follows the tooltip's (label) order; a shared label is one entry.
eq(icon_items(two), "grug_test:corn grug_test:potato", "icons in tooltip order (Corn, Potato)")
eq(icon_items(three), "grug_test:garlic grug_test:leek grug_test:onion", "3 icons in order")
eq(icon_items(four), "grug_test:berry_a grug_test:cherry grug_test:raspberry grug_test:strawberry",
	"two Blueberries are one icon (the first name), 4 icons")
eq(icon_items(five), "grug_test:apple grug_test:fig grug_test:pear", "the first three of five")
-- Clickability: one target per icon under the cell rule, never the marker.
eq(#two.buttons, 1, "2 items: only Corn (with a recipe) is clickable")
has(stew_fs, "image_button[1.250,5.855;0.41,0.41;blank.png;grug_jobs_cell_1_1;;false;false]",
	"Corn's click target covers its quarter")
lacks(stew_fs, "grug_jobs_cell_1_2", "Potato (no recipe) has no click target")
eq(#three.buttons + #four.buttons, 0, "items without a recipe are inert")
eq(#five.buttons, 1, "5 items: only Apple is clickable")
has(stew_fs, "grug_jobs_cell_4_1;", "Apple is icon 1 of cell 4")
lacks(stew_fs, "grug_jobs_cell_4_4", "the \"+2\" marker is never clickable")
-- Every icon shows the same complete list; a clickable one adds the click line.
local function tooltip_texts(parts)
	local out = {}
	for _, e in ipairs(parts.tooltips) do out[#out + 1] = e.rest end
	return out
end
local five_full = fs_escape("Apple or Fig or Pear or Plum or Quince")
local tips = tooltip_texts(five)
eq(#tips, 2, "5 items: the clickable icon's tooltip and the whole cell's")
eq(tips[1], five_full .. "\nClick to view recipe", "the clickable icon lists all five")
eq(tips[2], five_full, "the whole cell (inert icons, the marker) lists all five")
check(not stew_fs:find("%+%d+ more"), "no \"+N more\" cut in any tooltip")
tips = tooltip_texts(four)
eq(#tips, 1, "4 items: one tooltip over the whole cell")
eq(tips[1], fs_escape("Blueberry or Cherry or Raspberry or Strawberry"), "4 items: the full list")
eq(tooltip_texts(two)[2], fs_escape("Corn or Potato"), "2 items: \"Corn or Potato\"")
eq(tooltip_texts(one)[1], "Salt", "1 item: today's tooltip")
-- Navigation and Back from a sub-icon, through the book's own handler.
local function send_book(fields)
	book_shown = nil
	for _, fn in ipairs(callbacks.fields) do
		if fn(smith, "grug_jobs:book", fields) then break end
	end
	return book_shown
end
grug_jobs.open_book(smith, "general")
send_book({grug_jobs_search = "stew", grug_jobs_do_search = ""})
local host = send_book({grug_jobs_item_1 = "", grug_jobs_search = "stew"})
has(host, "item_image[5.25,6.35;1.1,1.1;grug_test:stew]", "the stew is selected")
eq(send_book({grug_jobs_cell_1_2 = ""}), nil, "a forged click on Potato does nothing")
local jumped = send_book({grug_jobs_cell_1_1 = ""})
has(jumped, "item_image[5.25,6.35;1.1,1.1;grug_test:corn]", "clicking Corn opens its recipe")
has(jumped, "grug_jobs_back;Back]", "Back appears after a sub-icon jump")
local back = send_book({grug_jobs_back = ""})
has(back, "item_image[5.25,6.35;1.1,1.1;grug_test:stew]", "Back returns to the stew")
has(back, "grug_jobs_search;;stew]", "Back restores the search")
jumped = send_book({grug_jobs_cell_4_1 = ""})
has(jumped, "item_image[5.25,6.35;1.1,1.1;grug_test:apple]", "clicking Apple (5-item slot) opens its recipe")

print(("%d formspecs checked for bracket/escape sanity"):format(formspecs_checked))
for label, count in pairs(raw_brackets) do
	print(("note: %s carries %d raw '[' inside elements (texture modifiers)"):format(label, count))
end
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("R28 A6 UI PORTABLE FAIL %d/%d"):format(failures, checks), 0) end
print("R28 A6 UI PORTABLE PASS checks=" .. checks)
