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
--   4. the quest log column (grug_quests/ui.lua): textareas right of the list
--      with a visible gap, the title aligned with the text;
--   5. the Riding Trainer (grug_mounts/state.lua tier_state + trainer.lua):
--      all four tiers with the right state, buttons only for "buy";
--   6. the Character page (grug_inventory/pages.lua): "Damage reduction" with
--      its tooltip, the Professions tab body from grug_jobs/character_tab.lua;
--   7. recipe books (grug_jobs/ui.lua): a profession book lists T1-T6 with
--      locked recipes greyed and "N locked" per tier, the station view and
--      Basics keep their old rules;
--   8. every formspec built above passes a bracket/escape sanity check.
--
-- Usage (repo root): luajit tools/r28_a6_ui/portable_test.lua

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
grug_xp.add_xp(bob, 60, "kill")
eq(fed_xp[1], 60, "kill XP reaches the feed")
eq(#banners, 0, "no banner below the next level")
grug_xp.add_xp(bob, 50, "kill")
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
	register_on_change = function(fn) grug_quests._changed = fn end,
	journal = function() return deep_copy(journal_state) end}
core.registered_entities["grug_mobs:small_boar"] = {description = "Small Boar"}
dofile("mods/PLAYER/grug_quests/hud.lua")
local function quest(id, objectives) return {id = id, objectives = objectives, ready = false} end
local boar = {type = "kill", mobs = {"grug_mobs:small_boar"}, count = 3, required = 10}
local axe = {type = "item", item = "grug_mobs:leather", count = 0, required = 1}
eq(grug_quests.feed_text(quest("q1", {boar})), "Small Boar 3/10", "kill line text")
eq(grug_quests.feed_text(quest("q2", {axe, {type = "talk", npc = "elder", count = 1, required = 1}})),
	"Light Leather 0/1, Elder Maren 1/1", "multi-objective line text")
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
journal_state.quests[2].objectives[1].count = 0
run_steps(0.6)
eq(#fed, 1, "a falling item count is silent")
journal_state.quests[2].objectives[1].count = 1
run_steps(0.6)
eq(fed[2] and fed[2].text, "Light Leather 1/1", "an item gain posts through the 0.5 s pass")
grug_core.feed = nil

------------------------------------------------------------------------------
-- 4. Quest log column (legacy coordinates).
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
grug_inventory = {}
dofile("mods/PLAYER/grug_inventory/ui.lua")
grug_money = {format = function(c) return c .. " copper" end, get = function() return 0 end,
	register_on_change = function() end}
grug_quests.journal = function()
	return {quests = {{id = "q1", title = "Boar Trouble", description = "Boars eat our crops.",
		objectives = {{type = "kill", mobs = {"grug_mobs:small_boar"}, count = 3, required = 10}},
		ready = false, npc = "elder", rewards = {xp = 40, copper = 5, items = {"grug_mobs:leather 2"}}}},
		tracked = {"q1"}, hud_enabled = true}
end
dofile("mods/PLAYER/grug_quests/ui.lua")
local quest_fs = pages["grug_quests:quests"]:get(carol, {})
formspec_ok(quest_fs, "quest log")
local PAD, SPACING_PER_IMG = 0.3, 1.25 -- legacy padding (spacing units), spacing / imgsize
local list_x, list_w = quest_fs:match("textlist%[([%d.]+),[%d.]+;([%d.]+),")
local list_right = tonumber(list_x) + tonumber(list_w)
local text_lefts = {}
for x in quest_fs:gmatch("textarea%[([%d.]+),") do text_lefts[#text_lefts + 1] = tonumber(x) - PAD end
local title_x = tonumber(quest_fs:match("label%[([%d.]+),0%.65;Boar Trouble%]"))
eq(#text_lefts, 3, "description, objective and reward textareas")
for i, left in ipairs(text_lefts) do
	check(left - list_right >= 0.15, ("textarea %d right of the list with a gap (%.2f units)")
		:format(i, left - list_right))
end
check(title_x and math.abs(title_x - text_lefts[1]) < 1e-6, "title label starts where the text starts")
print(("quest log: list ends at %.2f, text starts at %.2f (gap %.2f spacing = %.3f imgsize); before: overlap %.3f imgsize")
	:format(list_right, text_lefts[1], text_lefts[1] - list_right,
		(text_lefts[1] - list_right) * SPACING_PER_IMG, (list_right - (3.85 - PAD)) * SPACING_PER_IMG))
has(quest_fs, "Small Boar: 3/10", "objective text unchanged")

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
local smith = make_player("smith", nil)
eq(grug_jobs.professions_formspec(grug_jobs.profession_overview(smith)):find("No professions learned", 1, true) ~= nil,
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
eq(overview[1].capped, true, "level 15 caps tier 2")
eq(overview[2].capped, false, "cooking T1 is not capped at level 15")
local prof_fs = grug_jobs.professions_formspec(overview)
formspec_ok(prof_fs, "professions tab")
has(prof_fs, fs_escape("Weaponsmith — Tier 2"), "profession name and tier")
has(prof_fs, fs_escape("Crafts: 7/15 toward tier 3"), "tier progress")
has(prof_fs, fs_escape("Capped by your level: tier 3 needs character level 21."), "cap note")
has(prof_fs, fs_escape("Crafts: 10/10 toward tier 2"), "cooking progress")
char_level = 5
overview = grug_jobs.profession_overview(smith)
eq(overview[2].capped, true, "level 5 caps cooking T1")
has(grug_jobs.professions_formspec(overview),
	fs_escape("Capped by your level: reach level 11, then craft once more for tier 2."),
	"saturated cap note")
char_level = 60
smith.meta["grug_jobs:level:weaponsmith"] = 6
has(grug_jobs.professions_formspec(grug_jobs.profession_overview(smith)),
	"Highest tier reached.", "T6 needs nothing more")
char_level = 15
smith.meta["grug_jobs:level:weaponsmith"] = 2

-- The page itself.
grug_inventory.equipment_slots = {}
player_api = {registered_models = {["character.b3d"] = {textures = {"character.png"}}}}
grug_classes = {get_class_def = function() return {resource = "rage"} end,
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
function smith:get_inventory() return {get_stack = function() return ItemStack("") end} end
local resent = 0
sfinv.set_player_inventory_formspec = function() resent = resent + 1 end
dofile("mods/PLAYER/grug_inventory/pages.lua")
local character = pages["grug_inventory:character"]
local context = {page = "grug_inventory:character"}
contexts.smith = context
local stats_fs = character:get(smith, context)
formspec_ok(stats_fs, "character stats")
has(stats_fs, "label[2.75,2.60;Damage reduction: 12.3%]", "Damage reduction label")
lacks(stats_fs, "Own-level", "old label gone")
has(stats_fs, fs_escape("Armor reduction against an enemy of your level."), "tooltip text")
has(stats_fs, "tooltip[2.75,2.608;3.6,0.45;", "tooltip covers the label line")
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
core.get_all_craft_recipes = function(name)
	if name == "grug_test:plank" then
		return {{method = "normal", width = 1, items = {"grug_test:bar"}, output = "grug_test:plank 4"}}
	end
	return nil
end
dofile("mods/PLAYER/grug_jobs/ui.lua")
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

print(("%d formspecs checked for bracket/escape sanity"):format(formspecs_checked))
for label, count in pairs(raw_brackets) do
	print(("note: %s carries %d raw '[' inside elements (texture modifiers)"):format(label, count))
end
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print("R28 A6 UI PORTABLE PASS checks=" .. checks)
