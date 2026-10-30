-- Round 67 lane MAP portable test (LuaJIT): the map window at about 90 %
-- of the screen, markers at their anchors and smaller, flat layer buttons,
-- the compact quest list and one quest order for the list and the HUD.
--
--   luajit tools/r67_map/portable_test.lua [repo]
--
-- Loads the REAL grug_core ui.lua, ui_window.lua, ui_rows.lua and
-- hud_layout.lua, grug_map atlas.lua, markers.lua (with icon_layout.lua and
-- icon_masks.lua), window.lua (with layers.lua, quest_box.lua and the rest
-- it loads, on a permissive fake engine), grug_quests hud.lua and npc.lua's
-- category_list (read from the file). Window information is built as the
-- client reports it (clientdynamicinfo.cpp calculateMaxFSSize). Checks:
--   S  the window size at 1280x720, 1920x1080 and 3840x2160: about 90 % of
--      the screen in both directions from the client's own report (no
--      viewport cap, padding[0,0]); the map about 62 % of the width;
--   M  markers at their anchors (no displacement left: no markers.offsets,
--      no solve, no reserved quest slots; two markers on one anchor drawn
--      on the same spot), 21 px at the reference (11 px floor), the arrows
--      32 px on top, the draw order by importance (markers.rank, the
--      minimap's z-index too);
--   B  the layer buttons: flat, one marked, none in quest mode, the short
--      labels in order, one row at 1920x1080 and two at 1035x696, the
--      handler's grug_map_layer_<id> fields;
--   Q  the quest list: compact one-line rows with "[Lv N]" in the
--      difficulty colour; the Story and Side groups each by level; the HUD
--      in the same order (story first, by level, ties by title and id);
--      today's rows (mail, quest giver) byte-identical to 0.66.1;
--   P  the party check every 1 s.
-- Prints the profile table (window, map view px, marker px before/after)
-- and "R67 MAP PORTABLE PASS checks=<n>".
local repo = arg[1] or "."
local MAP = repo .. "/mods/PLAYER/grug_map"
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) <= (eps or 1e-6) end
local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
local function count(text, pattern)
	local n = 0
	for _ in text:gmatch(pattern) do n = n + 1 end
	return n
end
local function hash(text)
	local h = 5381
	for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
	return ("%08x"):format(h)
end

-- ---------------------------------------------------------------------------
-- The fake engine
-- ---------------------------------------------------------------------------
local function lax(t)
	return setmetatable(t or {}, {__index = function() return function() end end})
end
local function fs_escape(s) return (tostring(s):gsub("[%[%];,\\]", "\\%0")) end
rawset(_G, "core", lax({
	get_modpath = function() return MAP end,
	get_current_modname = function() return "grug_map" end,
	formspec_escape = fs_escape,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_us_time = function() return 0 end,
}))
rawset(_G, "grug_core", lax({plain_text = function(text) return text end}))
rawset(_G, "grug_sounds", {CLICK_STYLE = ""})
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_window.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_rows.lua")
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")

-- The quests: hud.lua for real, npc.lua's category_list from its source.
local registered_quests = {}
rawset(_G, "grug_quests", lax({MAX_TRACKED = 10, registered_quests = registered_quests,
	registered_npcs = {elder = {title = "Elder Maren"}}}))
rawset(_G, "grug_xp", {get_level = function() return 20 end, register_on_level_change = function() end,
	con_color = function(level, player_level) return level > player_level and 0xff5555 or 0x55ff55 end})
dofile(repo .. "/mods/PLAYER/grug_quests/hud.lua")
do
	local body = read(repo .. "/mods/PLAYER/grug_quests/npc.lua"):match(
		"\n(function Q%.category_list.-\nend)\n")
	assert(body, "Q.category_list not found")
	grug_quests.STORY_COLOR = "#c69cff"
	assert(loadstring("local Q = grug_quests\n" .. body))()
end
grug_quests.objective_action = function(o) return "Do " .. tostring(o.what) end
grug_quests.objective_levels_text = function() return "" end

rawset(_G, "grug_keys", lax({}))
rawset(_G, "grug_zones", lax({}))
rawset(_G, "grug_factions", {get_faction = function() return "accord" end})
local in_party = false
rawset(_G, "grug_parties", {in_party = function() return in_party end,
	view = function() return in_party and {members = {{name = "p", online = true},
		{name = "bea", online = true}}} or nil end})
rawset(_G, "grug_inventory", lax({UI = {header_h = 1.5},
	navigation_layout = function() return {} end,
	navigation = function() return "", 1.5 end}))
rawset(_G, "grug_map", {atlas = dofile(MAP .. "/atlas.lua")})
local atlas = grug_map.atlas
atlas.set_base_texture("base.png")
grug_map.minimap = {available = function() return false end}
grug_map.base = {QUALITY = {normal = {width = 1215, height = 1080}}}
local M = dofile(MAP .. "/markers.lua")
local W = dofile(MAP .. "/window.lua")
local layers = grug_map.layers
-- (quest mode's targets are r44_mq's; here only the mode matters)
W.quest_targets = function() return nil end
W.handin_mark = function() return nil end

-- The markers: two trainers on one anchor, quest givers of every state, the
-- player and a party member.
local anchor = {x = 1000, y = 0, z = -500}
local services = {
	{id = "a", label = "Tailor Trainer", kind = "trainer", texture = "grug_map_trainer_tailor.png",
		position = anchor},
	{id = "b", label = "Riding Trainer", kind = "trainer", texture = "grug_map_riding.png",
		position = anchor},
}
atlas.register_marker_provider("service", function() return services end)
local givers = {}
for i, status in ipairs({"story_ready", "ready", "locked", "available", "story_available", "active"}) do
	givers[i] = {id = "g" .. i, label = "Giver " .. status, kind = "quest", status = status,
		position = {x = -2000 + 300 * i, z = 1000}}
end
atlas.register_marker_provider("quest", function() return givers end)
local player = {get_player_name = function() return "p" end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
	get_look_horizontal = function() return 0 end}
local bea = {get_player_name = function() return "bea" end,
	get_pos = function() return {x = 1000, y = 0, z = -500} end,
	get_look_horizontal = function() return 0 end}
core.get_player_by_name = function(name) return name == "bea" and bea or nil end
atlas.register_marker_provider("player", function()
	return {{id = "p", label = "p", kind = "player", position = player:get_pos(), heading = 0}}
end)
atlas.register_marker_provider("party", function()
	return in_party and {{id = "bea", label = "bea", kind = "party", position = bea:get_pos(),
		heading = 0}} or {}
end)

-- The quests of the list and the HUD.
local journal = {quests = {}, tracked = {}, hud_enabled = true}
local function quest(id, level, title, story)
	registered_quests[id] = {id = id, level = level, title = title, story = story, zone = "z"}
	journal.quests[#journal.quests + 1] = {id = id, title = title, story = story,
		objectives = {{type = "kill", count = 0, required = 1, what = id}}, ready = id == "s_mid",
		npc = "elder", rewards = {copper = 0, items = {}}, reward_xp = 0, description = ""}
	journal.tracked[#journal.tracked + 1] = id
end
-- (the journal's own order is by id, as grug_quests.journal sorts it)
quest("a_high", 30, "Bandit Trouble")
quest("b_low", 5, "Rats in the Cellar")
quest("c_tie", 12, "charcoal")
quest("d_tie", 12, "Charcoal")
quest("s_late", 25, "The King's Road", true)
quest("s_mid", 8, "A Story of Old Days That Goes On For Very Long Indeed", true)
quest("z_mid", 12, "Apples")
grug_quests.journal = function() return journal end

-- The window information a client reports.
local function client(w, h, density, gui, hud)
	local fixed = 0.5555 * 96 * (density or 1) * (gui or 1)
	local preferred = math.max(math.floor(math.min(w, h) / 15) * (gui or 1), fixed)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / preferred, y = h / preferred},
		real_gui_scaling = (gui or 1) * (density or 1), real_hud_scaling = (hud or 1) * (density or 1)}
end
local function images(form)
	local list = {}
	for x, y, w, h, texture in form:gmatch("image%[([%d.%-]+),([%d.%-]+);([%d.]+),([%d.]+);([^%]]+)%]") do
		list[#list + 1] = {x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h),
			texture = texture}
	end
	return list
end
local function find(list, texture)
	for _, image in ipairs(list) do if image.texture == texture then return image end end
end
local function render(layer, info, selected)
	local state = W.new_state()
	state.layer, state.quest_selected = layer, selected
	return W.formspec(player, state, info), state
end

-- ---------------------------------------------------------------------------
-- S: the window size and layout
-- ---------------------------------------------------------------------------
-- 0.66.1's figures (measured with the same rules on 9fcf8093): the window
-- in screen pixels, the map's drawn width and the markers' pixels.
local BEFORE = {
	["1280x720"] = {window = "1081x607", map = 496, marker = 21},
	["1920x1080"] = {window = "1631x918", map = 762, marker = 32},
	["2560x1440"] = {window = "1631x918", map = 762, marker = 32},
	["3840x2160"] = {window = "2175x1224", map = 1016, marker = 32},
	["phone 2400x1080 density 2.5"] = {window = "1728x1080", map = 783, marker = 33},
}
local PROFILES = {
	{"1280x720", client(1280, 720)},
	{"1920x1080", client(1920, 1080)},
	{"2560x1440", client(2560, 1440)},
	{"3840x2160", client(3840, 2160)},
	{"phone 2400x1080 density 2.5", client(2400, 1080, 2.5)},
}
local table_rows = {}
for _, p in ipairs(PROFILES) do
	local name, info = p[1], p[2]
	local form, state = render("trainers", info)
	local fw, fh = form:match("size%[([%d.]+),([%d.]+)%]")
	fw, fh = tonumber(fw), tonumber(fh)
	local _, per_unit = M.metrics(info, fw, fh)
	local L = state.layout
	local icon = find(images(form), "grug_map_trainer_tailor.png")
	local marker = icon and math.floor(icon.w * per_unit) or -1
	local px_w, px_h = fw * per_unit, fh * per_unit
	table_rows[#table_rows + 1] = {name = name, window = ("%dx%d"):format(px_w, px_h),
		share = ("%d%%x%d%%"):format(100 * px_w / info.size.x + 0.5, 100 * px_h / info.size.y + 0.5),
		map = L.map_w * per_unit, marker = marker}
	check(form:find("padding[0,0]", 1, true) ~= nil and not form:find("padding%[0%.%d"),
		"S " .. name .. ": padding[0,0], no viewport cap")
	if name ~= "phone 2400x1080 density 2.5" then
		check(near(px_w / info.size.x, 0.9, 0.006) and near(px_h / info.size.y, 0.9, 0.006),
			("S %s: about 90 %% of the screen (%.3f x %.3f)"):format(name, px_w / info.size.x,
				px_h / info.size.y))
		check(near(L.viewport_w + 0.35, (fw - 0.8) * 0.62, 1e-6) and
			near(L.column.w, (fw - 0.8) * 0.38, 1e-6), "S " .. name .. ": the map takes 62 % of the width")
	end
end
-- The phone: the 16 x 10 floor is taller than its screen; the client
-- shrinks it to the full height (as before).
check(table_rows[5].window:match("x(%d+)$") == "1080", "S the phone: fitted to the screen's height")
-- Text keeps today's growth rule (ui.lua text_growth over the window).
do
	local info = client(3840, 2160)
	local seen
	local prose = grug_core.ui.prose
	grug_core.ui.prose = function(...) seen = select(8, ...) return prose(...) end
	local form = render("none", info)
	grug_core.ui.prose = prose
	local fw, fh = form:match("size%[([%d.]+),([%d.]+)%]")
	local growth = grug_core.ui.form_growth(info, tonumber(fw), tonumber(fh))
	check(near(seen, growth) and growth > 1.3 and growth < 1.4,
		("S 3840x2160: the text growth as today's rule gives it (%.3f)"):format(growth or 0))
end

-- ---------------------------------------------------------------------------
-- M: markers at their anchors, their sizes and order
-- ---------------------------------------------------------------------------
do
	check(M.offsets == nil and M.layout.solve == nil and M.layout.overlap == nil,
		"M no displacement solve left (markers.offsets, icon_layout solve)")
	check(grug_map.quest_slots == nil and not read(MAP .. "/providers.lua"):find("quest_slots", 1, true),
		"M no reserved quest-giver slots")
	local minimap = read(MAP .. "/minimap.lua")
	check(not minimap:find("markers.offsets", 1, true) and not minimap:find("marker.dx", 1, true),
		"M the minimap draws every marker at its anchor")
	check(minimap:find("local z = Z.marker + row.marker.rank", 1, true) ~= nil,
		"M the minimap's z-index is the importance")
	eq(M.SIZE, 21, "M markers 21 px at the reference (32 before)")
	eq(M.MIN, 11, "M the floor 11 px (16 before)")
	eq(M.arrow(21), 32, "M the arrows keep 32 px at the reference")
	-- Importance: places and bosses < services < travel < quest givers by
	-- state, story over plain.
	local function rank(kind, status) return M.rank({kind = kind, status = status}) end
	check(rank("capital") < rank("trainer") and rank("trainer") < rank("waypoint") and
		rank("waypoint") < rank("quest", "locked"), "M rank: places, services, travel, quests")
	check(rank("quest", "locked") < rank("quest", "active") and
		rank("quest", "active") < rank("quest", "available") and
		rank("quest", "available") < rank("quest", "ready") and
		rank("quest", "ready") < rank("quest", "story_ready") and
		rank("quest", "story_available") < rank("quest", "ready") and
		rank("quest", "story_ready") <= 10, "M rank: quest states, story above plain, under the bezel")

	in_party = true
	local info = client(1920, 1080)
	local form, state = render("trainers", info)
	local list = images(form)
	local a, b = find(list, "grug_map_trainer_tailor.png"), find(list, "grug_map_riding.png")
	local view = atlas.view()
	local L = state.layout
	local sx, sy = atlas.world_to_screen(view, anchor, 0, 0, L.map_w, L.map_h)
	local _, per_unit = M.metrics(info, L.w, L.form_h)
	local units = 21 / per_unit
	check(a and b and near(a.x, b.x) and near(a.y, b.y), "M two markers on one anchor share the spot")
	check(a and near(a.x + units / 2, sx, 1e-5) and near(a.y + units / 2, sy, 1e-5),
		"M a marker centred on its anchor")
	check(a and math.floor(a.w * per_unit) == 21, "M 21 px drawn at 1920x1080")
	local arrow = find(list, "grug_map_heading_gold_00.png")
	local party = find(list, "grug_map_heading_cyan_00.png")
	check(arrow and math.floor(arrow.w * per_unit) == 32 and party and math.floor(party.w * per_unit) == 32,
		"M the arrows 32 px")
	local order = {}
	for _, image in ipairs(list) do order[#order + 1] = image.texture end
	local joined = table.concat(order, " ")
	check(joined:find("riding%.png.*heading_cyan.*heading_gold") ~= nil,
		"M the party's arrow over the markers, the player's on top")
	check(party and math.abs(party.x + party.w / 2 - (a.x + units / 2)) < 0.03,
		"M the party's arrow at its true position (over a marker on the same spot)")
	in_party = false
	-- The quest givers bottom to top by importance.
	form = render("quests", info)
	local map = form:match("scroll_container%[.-scroll_container_end%[%]scroll_container_end%[%]")
	local drawn = {}
	for _, image in ipairs(images(map)) do
		local status = image.texture:match("^grug_map_quest_(.+)%.png$")
		if status then drawn[#drawn + 1] = status end
	end
	eq(table.concat(drawn, ","), "locked,active,available,story_available,ready,story_ready",
		"M quest givers drawn by importance")
	-- Tooltips topmost first: the story_ready giver's tooltip before the locked one's.
	local first, last = form:find(";Giver story_ready]", 1, true), form:find(";Giver locked]", 1, true)
	check(first and last and first < last, "M the topmost marker's tooltip first")
end

-- ---------------------------------------------------------------------------
-- B: the layer buttons
-- ---------------------------------------------------------------------------
do
	local MARKED = "style%[grug_map_layer_([^;:]+);[^%]]*textcolor=#d4b77d;"
	local form, state = render("towns", client(1920, 1080))
	eq(count(form, "dropdown%["), 0, "B no dropdown")
	local marked = {}
	for id in form:gmatch(MARKED) do marked[#marked + 1] = id end
	eq(table.concat(marked, ","), "towns", "B the active layer's button marked")
	check(form:find("style[grug_map_layer_quests,grug_map_layer_bosses,grug_map_layer_trainers," ..
		"grug_map_layer_pois,grug_map_layer_pvp,grug_map_layer_zones,grug_map_layer_none;border=false;" ..
		"bgcolor=#ffffff;bgimg=grug_ui_clear.png;", 1, true) ~= nil and
		form:find("style[grug_map_layer_towns;border=false;bgcolor=#ffffff;bgimg=grug_ui_clear.png;", 1,
		true) ~= nil and form:find("grug_map_layer_quests:hovered,grug_map_layer_bosses:hovered,", 1, true),
		"B flat buttons (the toolkit's clear navigation style; one shared set for the unmarked ones)")
	local labels = {}
	for id, label in form:gmatch("button%[[^;]+;[^;]+;grug_map_layer_(%a+);([^%]]*)%]") do
		labels[#labels + 1] = label
	end
	eq(table.concat(labels, ","), "Quests,Bosses,Services,Travel,Places,PvP,Zones,None",
		"B the short labels in order")
	local b = state.layout.buttons
	eq(b.rows, 1, "B one row at 1920x1080")
	check(near(b.y + b.h + 0.15, state.layout.map_y), "B the row right above the map")
	local _, small = render("towns", client(1035, 696))
	eq(small.layout.buttons.rows, 2, "B two rows at 1035x696")
	form = render("towns", client(1920, 1080), "a_high")
	eq(count(form, MARKED), 0, "B quest mode marks no button")
	-- The handler: a button field picks its layer and deselects the quest.
	local session = W.new_state()
	W.sessions.p = session
	session.quest_selected = "a_high"
	rawset(_G, "sfinv", lax({}))
	rawset(_G, "default", {node_formspec = {shown_form = function() return nil end}})
	grug_inventory.navigation_target = function() return nil, false end
	W.handle_fields(player, {grug_map_layer_pois = "Places"})
	check(session.layer == "pois" and session.quest_selected == nil,
		"B grug_map_layer_<id> picks the layer and deselects the quest")
	W.sessions.p = nil
end

-- ---------------------------------------------------------------------------
-- Q: the quest list, the HUD and the shared order
-- ---------------------------------------------------------------------------
do
	local form = render("quests", client(1920, 1080), "s_mid")
	local list = form:match("scroll_container%[[^%]]*grug_quest_list_scroll.-scroll_container_end%[%]")
	assert(list, "the quest list")
	-- The rows: their titles (first label of each row) and badges.
	local titles, badges, heights = {}, {}, {}
	for h in list:gmatch("button%[0,[%d.]+;[%d.]+,([%d.]+);grug_quest_list_row_%d+;%]") do
		heights[#heights + 1] = tonumber(h)
	end
	-- (labels end at the first unescaped "]"; colour escapes stripped)
	for text in list:gmatch("label%[[%d.]+,[%d.]+;(.-[^\\])%]") do
		local plain = text:gsub("\27%(c@[^)]*%)", ""):gsub("\\(.)", "%1")
		if plain:match("^%[Lv %d+%]$") then badges[#badges + 1] = text else titles[#titles + 1] = plain end
	end
	eq(#heights, 7, "Q one row per quest")
	check(#heights > 0 and near(heights[1], 0.54) and near(heights[#heights], 0.54),
		"Q compact rows: 0.6 units (0.54 drawn)")
	eq(#titles, 9, "Q one title line per row (and the two group headings)")
	check(titles[2] and titles[2]:find("^A Story of Old Days") and titles[2]:find("…$"),
		"Q a long title cut to one line with …")
	titles[2] = "A Story…"
	eq(table.concat(titles, "|"), "Story|A Story…|The King's Road|" ..
		"Side quests|Rats in the Cellar|Apples|charcoal|Charcoal|Bandit Trouble",
		"Q Story and Side groups, each by level (ties by title, then id)")
	eq(#badges, 7, "Q a level label per row")
	check(badges[1] and badges[1]:find("#55ff55", 1, true) and badges[1]:find(fs_escape("[Lv 8]"), 1, true) and
		badges[2]:find("#ff5555", 1, true) and badges[2]:find(fs_escape("[Lv 25]"), 1, true),
		"Q [Lv N] in the difficulty colour")
	check(list:find("tooltip%[grug_quest_list_row_%d+;A Story of Old Days That Goes On For Very Long " ..
		"Indeed\nReady to complete · Tracked\nLevel 8%]") ~= nil, "Q the whole title and the state in the tooltip")
	check(not list:find("label%[[^%]]*Ready to complete") and not list:find("label%[[^%]]*In progress"),
		"Q no subtitle line")
	-- The HUD: the same order without headings.
	local ids = {}
	for _, entry in ipairs(grug_quests.hud_entries(journal, 20, 38)) do ids[#ids + 1] = entry.id end
	eq(table.concat(ids, ","), "s_mid,s_late,b_low,z_mid,c_tie,d_tie,a_high",
		"Q the HUD: story first, then by level, ties by title and id")
	-- One function for both.
	local box = read(MAP .. "/quest_box.lua")
	local hud = read(repo .. "/mods/PLAYER/grug_quests/hud.lua")
	check(box:find("grug_quests.sort_quests(ordered)", 1, true) and
		hud:find("grug_quests.sort_quests(tracked)", 1, true) and
		select(2, hud:gsub("table%.sort%(", "")) == 1, "Q one shared sort function")
	-- Today's rows keep their bytes (0.66.1's ui_rows.lua on this stub
	-- engine: a mail list and a quest giver's list).
	local specs = {
		{name = "letters", x = 0.4, y = 2, w = 7.5, h = 9, scale = 1, rows = {
			{title = "A short letter", subtitle = "From Anna · 2 days", icon = "grug_mail_letter.png",
				selected = true},
			{title = "A very long letter title that wraps onto a second line in the list for sure",
				subtitle = "From Bertram the Very Long-Named Merchant of Highcourt · 1 day"},
			{title = "Unread", subtitle = "From Cara"}}},
		{name = "quests", x = 0.5, y = 1.85, w = 5.25, h = 8.05, reveal_selected = true, scale = 1.333,
			rows = {
			{title = "Story", header = true},
			{title = "The Long Road to the Capital of the Throng",
				icon = "grug_map_quest_story_available.png", tooltip = "tip", selected = false},
			{title = "Side quests", header = true},
			{title = "Rats", icon = "grug_map_quest_ready.png", subtitle = "Ready", selected = true}}},
	}
	local want = {letters = {2212, "5e90ead6"}, quests = {1699, "1784f6d9"}}
	for _, spec in ipairs(specs) do
		local out = grug_core.ui.rows({}, spec)
		check(#out == want[spec.name][1] and hash(out) == want[spec.name][2],
			("Q today's %s rows byte-identical (%d %s)"):format(spec.name, #out, hash(out)))
	end
end

-- ---------------------------------------------------------------------------
-- P: the party check
-- ---------------------------------------------------------------------------
eq(W.PARTY_US, 1000000, "P the party check every 1 s (2 s before)")

print(("%-30s %-10s %-9s %-10s %7s %7s | %6s %6s"):format("profile", "window", "share", "before",
	"map px", "before", "marker", "before"))
for _, row in ipairs(table_rows) do
	local before = BEFORE[row.name]
	print(("%-30s %-10s %-9s %-10s %7.0f %7d | %6d %6d"):format(row.name, row.window, row.share,
		before.window, row.map, before.map, row.marker, before.marker))
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R67 MAP PORTABLE FAIL %d of %d"):format(#failures, checks), 0)
end
print(("R67 MAP PORTABLE PASS checks=%d"):format(checks))
