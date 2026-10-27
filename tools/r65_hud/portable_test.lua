-- Round 65 lane HUD portable test (LuaJIT; round plan section 6, "Lane H's
-- fixture"). Loads the REAL grug_xp, grug_core hud_layout.lua, grug_map
-- minimap_view.lua and grug_quests hud.lua under a small engine stub and
-- checks:
--   G  the shared difficulty gradient (grug_xp.con_gradient) gives the
--      target frame's previous colours (its old local copy, verbatim
--      below), and con_color is gray at the gray line;
--   S  the boxes' entries: sorted by quest level, ties by title, then id;
--      "[Lv N]" in the level colour; the title cut keeps the label's room;
--      the HUD switch and the tracker cap;
--   L  the layout (hud_layout.quest_boxes): box count and "+N more" for
--      small and large windows and GUI scalings, every stack inside its
--      band below the minimap block (with and without "Now playing") and
--      above the bottom-centre column; the "Now playing" height pinned to
--      grug_map's own;
--   E  the element diff: added and removed only when the box count or the
--      "+N more" line changes, hud_change only for changed values; a level
--      change recolours the labels only; grug_map's hud_refresh lays the
--      boxes out again at once when "Now playing" comes or goes.
--
--   luajit tools/r65_hud/portable_test.lua [REPO]
-- Prints the layout numbers and "R65 HUD PORTABLE PASS checks=<n>" or the
-- failures (exit 1).

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
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function noop() end

------------------------------------------------------------------------------
-- The engine stub and the real files.
------------------------------------------------------------------------------
local joins, changes, steps = {}, {}, {}
local windows = {}
core = {settings = {get = function() return nil end}, log = noop,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_player_window_information = function(name) return windows[name] end}
setmetatable(core, {__index = function() return noop end})
grug_core = {hud_layout = {COLOR = {xp = 0}}, banner = noop, feed_xp = noop,
	particles = {play = noop}}
dofile(repo .. "/mods/PLAYER/grug_xp/init.lua")
-- Only hud.lua's join is played below.
for i = #joins, 1, -1 do joins[i] = nil end
local level_callbacks = {}
grug_xp.register_on_level_change = function(fn) level_callbacks[#level_callbacks + 1] = fn end

grug_core = {ui = {colors = {text = "#eeeae1", panel = "#0a10115e"}},
	plain_text = function(text) return text end, feed = noop}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local layout = grug_core.hud_layout

------------------------------------------------------------------------------
-- G: the shared gradient against the target frame's previous colours.
------------------------------------------------------------------------------
do
	-- grug_mobs/target_frame.lua con_gradient at 5581ed98, verbatim.
	local function previous(d)
		if d <= 0 then
			local span = grug_xp.GRAY_GAP - 1
			local red = 85 + math.floor(170 * math.max(0, d + span) / span + 0.5)
			return red * 0x10000 + 0xff55
		end
		return 0xff0055 + (255 - 34 * math.min(d, 5)) * 0x100
	end
	for d = -30, 30 do
		eq(grug_xp.con_gradient(d), previous(d), "G the gradient at d = " .. d)
	end
	eq(grug_xp.con_gradient(-9), 0x55ff55, "G green at -9")
	eq(grug_xp.con_gradient(0), 0xffff55, "G yellow at 0")
	eq(grug_xp.con_gradient(5), 0xff5555, "G red at +5")
	eq(grug_xp.con_color(20, 30), 0xaaaaaa, "G con_color: gray 10 below")
	eq(grug_xp.con_color(21, 30), 0x55ff55, "G con_color: green 9 below")
	eq(grug_xp.con_color(33, 30), previous(3), "G con_color: the gradient above")
	-- The target frame calls the shared function and has no copy left.
	local frame = assert(io.open(repo .. "/mods/ENTITIES/grug_mobs/target_frame.lua")):read("*a")
	check(frame:find("grug_xp.con_gradient(mob._grug_level - player_level)", 1, true) ~= nil and
		not frame:find("local function con_gradient", 1, true), "G the target frame uses the shared gradient")
end

------------------------------------------------------------------------------
-- The quest stubs and hud.lua.
------------------------------------------------------------------------------
local Q = {MAX_TRACKED = 10, registered_quests = {}, registered_npcs = {
	elder = {title = "Elder Maren"}}}
grug_quests = Q
function Q.objective_action(objective) return "Do " .. objective.name end
function Q.objective_subject(objective) return objective.name end
Q.markers_changed = noop
local on_change = {}
function Q.register_on_change(fn) on_change[#on_change + 1] = fn end
-- name -> {version, quests = {id -> {count}}, tracked = {ids}, hud}
local state = {}
function Q.journal_key(player)
	local s = state[player:get_player_name()]
	return tostring(s.version), "", {}
end
function Q.journal(player)
	local s = state[player:get_player_name()]
	local rows = {}
	for _, id in ipairs(s.order) do
		local def = Q.registered_quests[id]
		rows[#rows + 1] = {id = id, title = def.title, npc = "elder", ready = false,
			objectives = {{type = "item", name = def.goal, count = s.count[id] or 0, required = 5}}}
	end
	return {quests = rows, tracked = s.tracked, hud_enabled = s.hud ~= false}
end
local function quest(id, level, title, goal)
	Q.registered_quests[id] = {level = level, title = title, goal = goal or "Bring Wood"}
end
dofile(repo .. "/mods/PLAYER/grug_quests/hud.lua")

------------------------------------------------------------------------------
-- S: entries, sorting, labels and the title cut.
------------------------------------------------------------------------------
quest("q_c", 12, "Charcoal for the Kilns")
quest("q_a", 7, "A Long Way Down to the Old Copper Pits of Ashenfold", "Bring Copper Lumps")
quest("q_b", 12, "bandit Trouble")
quest("q_d", 12, "Bandit trouble")
quest("q_e", 3, "Rats")
quest("q_f", 40, "The Siege")
local journal = {hud_enabled = true, tracked = {"q_c", "q_a", "q_d", "q_b", "q_e", "q_f"},
	quests = {}}
for _, id in ipairs(journal.tracked) do
	local def = Q.registered_quests[id]
	journal.quests[#journal.quests + 1] = {id = id, title = def.title, npc = "elder",
		objectives = {{type = "item", name = def.goal, count = 1, required = 5}}}
end
do
	local entries = Q.hud_entries(journal, 12, 38)
	local ids = {}
	for i, entry in ipairs(entries) do ids[i] = entry.id end
	-- Levels 3, 7, 12 x3 (titles "bandit trouble" twice: then the id), 40.
	eq(table.concat(ids, ","), "q_e,q_a,q_b,q_d,q_c,q_f", "S sorted by level, title, id")
	eq(entries[1].label, "[Lv 3]", "S the label")
	eq(entries[6].label, "[Lv 40]", "S a two-digit label")
	eq(entries[1].color, 0x55ff55, "S a quest 9 levels below is green")
	eq(Q.hud_entries(journal, 13, 38)[1].color, 0xaaaaaa, "S ...10 below gray")
	eq(entries[2].color, grug_xp.con_gradient(-5), "S ...5 below the gradient")
	eq(entries[3].color, 0xffff55, "S ...own level yellow")
	eq(entries[6].color, 0xff5555, "S ...far above red")
	eq(entries[2].line, "1/5 Do Bring Copper Lumps", "S the objective line")
	for width = 12, 38 do
		for _, entry in ipairs(Q.hud_entries(journal, 12, width)) do
			check(#entry.title + 1 + #entry.label <= width and #entry.line <= width,
				("S title, label and objective fit %d characters: %q %s"):format(width,
					entry.title, entry.label))
		end
	end
	local long = Q.hud_entries(journal, 12, 38)[2]
	eq(long.title, "A Long Way Down to the Old C...", "S a long title ends with ... before the label")
	eq(Q.hud_entries(journal, 12, 38)[1].title, "Rats", "S a short title is whole")
	journal.hud_enabled = false
	eq(#Q.hud_entries(journal, 12, 38), 0, "S the HUD switch off: no boxes")
	journal.hud_enabled = true
	local many = {hud_enabled = true, tracked = {}, quests = {}}
	for i = 1, 12 do
		local id = ("m%02d"):format(i)
		quest(id, i, "Quest " .. i)
		many.tracked[i] = id
		many.quests[i] = {id = id, title = "Quest " .. i, npc = "elder",
			objectives = {{type = "item", name = "Wood", count = 0, required = 1}}}
	end
	eq(#Q.hud_entries(many, 1, 38), 10, "S at most MAX_TRACKED boxes")
end

------------------------------------------------------------------------------
-- L: the layout.
------------------------------------------------------------------------------
local function window(w, h, gui, hud)
	return {size = {x = w, y = h}, real_gui_scaling = gui or 1, real_hud_scaling = hud or 1}
end
do
	-- "Now playing" and the location gap as grug_map draws them.
	local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
	for _, gui in ipairs({1, 1.1, 1.25, 1.5, 2, 3}) do
		check(math.ceil(layout.NOW_PLAYING_HEIGHT * gui) >= V.now_playing_height(gui),
			"L the reserved \"Now playing\" height holds grug_map's at GUI " .. gui)
	end
	eq(layout.NOW_PLAYING_GAP, V.NOW_PLAYING.gap, "L the \"Now playing\" gap is grug_map's")
	local minimap = assert(io.open(repo .. "/mods/PLAYER/grug_map/minimap.lua")):read("*a")
	eq(tonumber(minimap:match("local LOCATION_GAP, LOCATION_COLOR = (%d+),")), layout.LOCATION_GAP,
		"L the location line's gap is grug_map's")

	-- Every stack in screen pixels: below the minimap block, above its
	-- band's bottom, boxes in order without overlap.
	local function verify(label, win, count, playing)
		local g = layout.quest_boxes(win, count, playing)
		local box = layout.minimap_box(win)
		local hud, gui = box.hud, box.gui
		local block = (layout.MINIMAP_EDGE + layout.LOCATION_GAP) * hud + box.size +
			math.ceil(layout.QUEST_BOX.line * gui)
		if playing then block = block + layout.NOW_PLAYING_GAP * hud +
			math.ceil(layout.NOW_PLAYING_HEIGHT * gui) end
		local function px(offset) return box.height / 2 + offset * hud end
		eq(g.shown + g.more, count, label .. ": shown + more = tracked")
		check(g.more == 0 or g.shown < count, label .. ": +N more only when boxes are left out")
		local first = g.shown > 0 and px(g.tops[1]) or g.more_top and px(g.more_top)
		local last = g.more > 0 and px(g.more_top) + g.line * hud or
			g.shown > 0 and px(g.tops[g.shown]) + g.height * hud
		if first then
			check(first >= block - 1e-6, ("%s: below the minimap block (%.0f >= %.0f)"):format(
				label, first, block))
			check(last <= box.height - layout.QUEST_BOX.margin * hud + 1e-6,
				("%s: above the bottom margin (%.0f)"):format(label, last))
		end
		for i = 2, g.shown do
			check(g.tops[i] >= g.tops[i - 1] + g.height, label .. ": boxes do not overlap")
		end
		return g, first, last
	end

	local rows = {}
	for _, case in ipairs({
		{"1920x1080", window(1920, 1080)}, {"1280x720", window(1280, 720)},
		{"1920x1080 GUI 1.5", window(1920, 1080, 1.5)}, {"1280x720 GUI 1.5", window(1280, 720, 1.5)},
		{"1024x768", window(1024, 768)}, {"800x600", window(800, 600)},
		{"2560x1440 HUD 1.5 GUI 1.5", window(2560, 1440, 1.5, 1.5)}, {"nil (fixtures)", nil}}) do
		local name, win = case[1], case[2]
		for _, playing in ipairs({false, true}) do
			for count = 0, 10 do verify(("%s%s n=%d"):format(name, playing and " playing" or "", count),
				win, count, playing) end
			local g, first, last = verify(name, win, 10, playing)
			rows[#rows + 1] = ("  %-26s %-8s box %2.0f px, gap %d px: %2d boxes + \"+%d more\", %d chars " ..
				"(title %d after the label), y %.0f..%.0f"):format(name, playing and "playing" or "", g.height *
				(win and win.real_hud_scaling or 1), g.gap, g.shown, g.more, g.chars, g.chars - 8, first, last)
		end
	end
	print("Ten tracked quests (layout.quest_boxes):")
	for _, row in ipairs(rows) do print(row) end

	eq(layout.quest_boxes(window(1920, 1080), 10, true).shown, 10, "L ten boxes fit at 1920x1080 with \"Now playing\"")
	eq(layout.quest_boxes(window(1920, 1080), 10, false).shown, 10, "L ...and without")
	local small = layout.quest_boxes(window(1280, 720), 10, true)
	check(small.shown < 10 and small.more == 10 - small.shown, "L 1280x720 with \"Now playing\": \"+N more\"")
	local few = layout.quest_boxes(window(1920, 1080), 2, false)
	check(math.abs(few.tops[1] + (2 * few.height + few.gap) / 2) < 1e-6,
		"L two boxes are centred on the window's middle")
	-- Above the bottom-centre column where a box reaches over it.
	local function stack_bottom(win, count)
		local g = layout.quest_boxes(win, count, false)
		return win.size.y / 2 + (g.tops[g.shown] + g.height) * win.real_hud_scaling
	end
	check(stack_bottom(window(1280, 720), 10) <= 720 + layout.rows.xp.middle - 10,
		"L 1280x720: the stack ends above the XP row's label")
	check(stack_bottom(window(1024, 768), 10) <= 768 + layout.feed_line_offset(3, window(1024, 768)).y - 10,
		"L 1024x768: the stack ends above the feed's top line")
	check(stack_bottom(window(1920, 1080), 10) > 1080 + layout.rows.xp.middle - 10 or
		layout.quest_boxes(window(1920, 1080), 10, false).shown == 10,
		"L 1920x1080: the box clears the column, so the band reaches the bottom margin")
end

------------------------------------------------------------------------------
-- E: the element diff on track, untrack, progress, level and window.
------------------------------------------------------------------------------
do
	local stats
	local function reset() stats = {add = 0, remove = 0, change = 0, keys = {}} end
	reset()
	local live = {}
	local player = {name = "ann"}
	function player:get_player_name() return self.name end
	local next_id = 0
	function player:hud_add(def)
		stats.add = stats.add + 1
		next_id = next_id + 1 -- the engine never reuses a live id
		live[next_id] = def
		return next_id
	end
	function player:hud_change(id, key, value)
		check(live[id] ~= nil, "E hud_change on a live element")
		stats.change = stats.change + 1
		stats.keys[key] = (stats.keys[key] or 0) + 1
		if type(value) == "table" then value = {x = value.x, y = value.y} end
		live[id][key] = value
	end
	function player:hud_remove(id)
		check(live[id] ~= nil, "E hud_remove of a live element")
		stats.remove = stats.remove + 1
		live[id] = nil
	end
	local function count_live()
		local n = 0
		for _ in pairs(live) do n = n + 1 end
		return n
	end
	core.get_player_by_name = function(name) return name == "ann" and player or nil end
	local s = {version = 1, order = {}, tracked = {}, count = {}}
	state.ann = s
	windows.ann = window(1920, 1080)
	grug_xp.get_level = function() return 12 end
	local function changed()
		s.version = s.version + 1
		for _, fn in ipairs(on_change) do fn(player) end
	end
	local function track(id)
		s.order[#s.order + 1] = id
		s.tracked[#s.tracked + 1] = id
		table.sort(s.order)
	end
	local function untrack(id)
		for _, list in ipairs({s.order, s.tracked}) do
			for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
		end
	end
	for _, fn in ipairs(joins) do fn(player) end
	eq(stats.add, 0, "E no tracked quest: no element")
	reset()
	track("q_c"); track("q_f"); track("q_e")
	changed()
	eq(stats.add, 12, "E three tracked: four elements each")
	eq(stats.change, 0, "E ...added with their values, nothing changed after")
	local texts = {}
	for _, def in pairs(live) do texts[#texts + 1] = def.text end
	local joined = table.concat(texts, "|")
	check(joined:find("[Lv 3]", 1, true) and joined:find("Charcoal for the Kilns", 1, true) and
		joined:find("1/5", 1, true) == nil and joined:find("0/5 Do Bring Wood", 1, true),
		"E the boxes carry title, label and objective")
	reset()
	for _, fn in ipairs(on_change) do fn(player) end
	eq(stats.add + stats.change + stats.remove, 0, "E a refresh without change sends nothing")
	reset()
	for _, fn in ipairs(steps) do for _ = 1, 5 do fn(0.1) end end
	eq(stats.add + stats.change + stats.remove, 0, "E the 0.5 s poll without change sends nothing")
	reset()
	s.count.q_c = 1
	changed()
	eq(stats.change, 1, "E one objective count: one hud_change (the line)")
	eq(stats.keys.text, 1, "E ...of its text")
	print(("Element diff: one objective count %d hud_change (before: 1 text change)"):format(stats.change))
	reset()
	track("q_a") -- level 7: sorts second
	changed()
	eq(stats.add, 4, "E a fourth tracked quest adds one box (four elements)")
	eq(stats.remove, 0, "E ...and removes nothing")
	print(("Element diff: track a 4th quest: %d hud_add, %d hud_change (texts %d, numbers %d, offsets %d)"):
		format(stats.add, stats.change, stats.keys.text or 0, stats.keys.number or 0, stats.keys.offset or 0))
	reset()
	untrack("q_e")
	changed()
	eq(stats.remove, 4, "E untracking removes one box")
	eq(stats.add, 0, "E ...and adds nothing")
	print(("Element diff: untrack one: %d hud_remove, %d hud_change"):format(stats.remove, stats.change))
	reset()
	for _, fn in ipairs(level_callbacks) do fn(player, 12, 13) end
	eq(stats.add + stats.remove, 0, "E a level change adds and removes nothing")
	eq(stats.change, stats.keys.number or -1, "E ...and changes only label colours")
	check(stats.change >= 1 and stats.change <= 3, "E ...at most one per box")
	reset()
	for _, fn in ipairs(level_callbacks) do fn(player, 13, 13) end
	eq(stats.change, 0, "E the same level again sends nothing")
	-- Ten tracked at full HD: 40 elements.
	for i = 1, 7 do track(("m%02d"):format(i)) end
	reset()
	changed()
	eq(count_live(), 40, "E ten tracked quests at 1920x1080: 40 elements")
	-- A small window: the boxes that do not fit go, "+N more" comes.
	reset()
	windows.ann = window(1280, 720)
	for _, fn in ipairs(steps) do for _ = 1, 5 do fn(0.1) end end
	local g = layout.quest_boxes(windows.ann, 10, false)
	eq(stats.remove, 4 * (10 - g.shown), "E 1280x720: the boxes beyond the band go")
	eq(stats.add, 1, "E ...and the \"+N more\" line comes")
	local more
	for _, def in pairs(live) do if def.text:find("more", 1, true) then more = def.text end end
	eq(more, ("+%d more"):format(10 - g.shown), "E the \"+N more\" text")
	-- "Now playing" comes: grug_map calls hud_refresh, the boxes make room
	-- at once (no poll step here).
	local playing = false
	rawset(_G, "grug_map", {minimap = {now_playing = function() return playing end}})
	reset()
	playing = true
	Q.hud_refresh(player)
	local g2 = layout.quest_boxes(windows.ann, 10, true)
	check(g2.shown < g.shown, "E (\"Now playing\" costs a box at 1280x720)")
	eq(stats.remove, 4 * (g.shown - g2.shown), "E \"Now playing\" comes: hud_refresh drops a box at once")
	reset()
	playing = false
	Q.hud_refresh(player)
	eq(stats.add, 4 * (g.shown - g2.shown), "E ...and it goes: the box is back at once")
	rawset(_G, "grug_map", nil)
	reset()
	windows.ann = window(1920, 1080)
	for _, fn in ipairs(steps) do for _ = 1, 5 do fn(0.1) end end
	eq(stats.remove, 1, "E full HD again: the \"+N more\" line goes")
	eq(count_live(), 40, "E ...and all ten boxes are back")
	-- The HUD switch off removes everything.
	reset()
	s.hud = false
	changed()
	eq(count_live(), 0, "E the HUD switch off removes every element")
end

if failures > 0 then
	error(("R65 HUD PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
end
print(("R65 HUD PORTABLE PASS checks=%d"):format(checks))
