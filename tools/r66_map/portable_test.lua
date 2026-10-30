-- Round 66 lane MAP portable test (LuaJIT): marker size by the map's pixel
-- size (ruling 5) and the camps' faction icons (ruling 8).
--
--   luajit tools/r66_map/portable_test.lua [repo]
--
-- Loads the REAL grug_map markers.lua, window.lua (with layers.lua and the
-- rest it loads, on a permissive fake engine), minimap_view.lua,
-- settlement_icons.lua, icon_masks.lua and grug_core hud_layout.lua and
-- ui_window.lua. Window information is built as the client reports it
-- (clientdynamicinfo.cpp calculateMaxFSSize, guiFormSpecMenu.cpp
-- getImgsize: the preferred image size is max(min(W, H) / 15 * gui (integer
-- division), 0.5555 * 96 * density * gui)). Checks:
--   F  markers.fit: the reference gives 32, the cap and the 16 px floor
--      hold, a missing extent keeps the cap;
--   W  the map window per profile (1920x1080 unchanged at 32 px, smaller
--      and phone windows shrink, never above 32 x HUD, never below 16) and
--      the drawn images in W.formspec at that size; no window information
--      keeps 32;
--   M  the minimap per profile against its own hole (1080p unchanged; the
--      phone's box is the desktop's, its markers no longer HUD-scaled);
--   C  the camps' icons: war camps by the slot's faction, construction
--      camps by their race's faction, fortresses unchanged, every variant
--      shipped with its master's mask.
-- Prints the size table and "R66 MAP PORTABLE PASS checks=<n>". Round 67
-- updated the pinned sizes (markers 21 px at the reference, 32 before; the
-- floor 11, 16 before) and measures the map window on the client's own
-- report (ruling 18: no viewport cap for it).
local repo = arg[1] or "."
local MAP = repo .. "/mods/PLAYER/grug_map"
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

-- A permissive fake engine: unknown functions are no-ops.
local function lax(t)
	return setmetatable(t or {}, {__index = function() return function() end end})
end
rawset(_G, "core", lax({
	get_modpath = function() return MAP end,
	get_current_modname = function() return "grug_map" end,
	formspec_escape = function(s) return (tostring(s):gsub("[%[%];,\\]", "\\%0")) end,
	get_us_time = function() return 0 end,
	show_formspec = function() end,
}))
rawset(_G, "grug_core", lax({}))
grug_core.ui = {}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_window.lua")
local layout = grug_core.hud_layout
rawset(_G, "grug_quests", lax({}))
rawset(_G, "grug_keys", lax({}))
rawset(_G, "grug_xp", lax({}))
rawset(_G, "grug_inventory", lax({UI = {header_h = 1.5}}))
rawset(_G, "grug_map", {atlas = lax({view = function()
	return {min_x = -4050, max_x = 4050, min_z = -3600, max_z = 3600}
end})})
local M = dofile(MAP .. "/markers.lua")
local W = dofile(MAP .. "/window.lua")
local V = dofile(MAP .. "/minimap_view.lua")
local icons = dofile(MAP .. "/settlement_icons.lua")
local masks = dofile(MAP .. "/icon_masks.lua")

-- The window information a client reports.
local function client(w, h, density, gui, hud)
	local fixed = 0.5555 * 96 * density * gui
	local preferred = math.max(math.floor(math.min(w, h) / 15) * gui, fixed)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / preferred, y = h / preferred},
		real_gui_scaling = gui * density, real_hud_scaling = hud * density}
end

-- ---------------------------------------------------------------------------
-- F  the rule
-- ---------------------------------------------------------------------------
check(M.SIZE == 21 and M.MIN == 11, "F Round 67: 21 px at the reference, the floor 11")
check(M.fit(21, 700, 700) == 21, "F the reference extent gives 21")
check(M.fit(21, 1400, 700) == 21, "F never above the cap")
check(M.fit(42, 1400, 700) == 42, "F a larger map at HUD 2 reaches the cap")
check(M.fit(80, 350, 700) == 11, "F half the map: 11")
check(M.fit(80, 100, 700) == 11, "F never below 11")
check(M.fit(8, 100, 700) == 8, "F a cap under the floor stays (today's size)")
check(M.fit(21, nil, 700) == 21 and M.fit(21, 0, 700) == 21, "F no extent: the cap")
check(M.fit(80, 525, 700) == 16, "F three quarters: 16")

-- ---------------------------------------------------------------------------
-- W  the map window
-- ---------------------------------------------------------------------------
-- The window's marker size and map extent, as W.formspec's overlay sees them.
local function window_px(raw)
	local info = raw
	local width = W.window_size(raw)
	local header = 1.5
	local w, h = W.window_size(raw, header)
	local L = W.layout_for(raw, header, grug_core.ui.form_growth(raw, w, h + header))
	local cap, per_unit = M.metrics(info, w, h + header)
	local drawn = L.map_w * per_unit
	return cap, M.fit(cap, drawn, W.reference_map_px(header)), drawn, width
end
local PROFILES = {
	{"1920x1080", 1920, 1080, 1, 1, 1},
	{"1280x720", 1280, 720, 1, 1, 1},
	{"2560x1440", 2560, 1440, 1, 1, 1},
	{"3840x2160", 3840, 2160, 1, 1, 1},
	{"3840x2160 HUD 2", 3840, 2160, 1, 1, 2},
	{"1920x1080 HUD 2", 1920, 1080, 1, 1, 2},
	{"phone 2400x1080 density 2.5", 2400, 1080, 2.5, 1, 1},
	{"phone 2400x1080 GUI+HUD 2.5", 2400, 1080, 1, 2.5, 2.5},
}
local rows = {}
local reference = W.reference_map_px(1.5)
check(math.abs(reference - 11.64 * 72) < 0.5, ("W reference map %.1f px (11.64 units at 72)"):
	format(reference))
for _, p in ipairs(PROFILES) do
	local info = client(p[2], p[3], p[4], p[5], p[6])
	local cap, size, drawn = window_px(info)
	local box = layout.minimap_box(info)
	local mini = {box = box.size, hud = box.hud}
	rows[#rows + 1] = {name = p[1], info = info, map = drawn, before = cap, after = size, mini = mini}
	check(size <= cap and (size >= M.MIN or cap < M.MIN), "W " .. p[1] .. ": inside cap and floor")
end
local by = {}
for _, row in ipairs(rows) do by[row.name] = row end
check(by["1920x1080"].after == 21 and by["1920x1080"].before == 21, "W 1920x1080 at the reference (21)")
check(by["1280x720"].after < 21 and by["1280x720"].after >= M.MIN, "W 1280x720 smaller")
check(by["phone 2400x1080 density 2.5"].after < by["phone 2400x1080 density 2.5"].before / 2,
	"W the phone's markers well under the HUD-scaled size")
-- W.formspec draws that size: the trainers layer's icon extent.
do
	rawset(_G, "grug_inventory", lax({UI = {header_h = 1.5},
		navigation_layout = function() return {} end,
		navigation = function() return "", 1.5 end}))
	grug_inventory.UI = {header_h = 1.5}
	local seen = {}
	grug_core.ui.prose = function(_, _, _, _, _, _, restore, font)
		seen.prose = {restore, font}
		return ""
	end
	grug_core.ui.panel = function() return "" end
	grug_core.ui.navigation_style = function() return "" end
	grug_core.ui.rows = function(_, spec) seen.rows = spec.scale return "" end
	-- grug_core.ui.text_growth (ui.lua) with the report given: the form's
	-- growth (ui_window.lua form_growth, loaded above).
	grug_core.ui.text_growth = function(_, fw, fh, info)
		return info and grug_core.ui.form_growth(info, fw, fh) or 1
	end
	grug_quests.category_list = function() return {}, {} end
	grug_map.minimap = {available = function() return false end}
	grug_map.atlas.collect_markers = function(_, only)
		if only and only.service then
			return {{id = "service:t", kind = "trainer", texture = "grug_map_trainer_tailor.png",
				label = "Tailor", detail = "Tailor", position = {x = 0, z = 0}}}
		end
		return {}
	end
	grug_map.atlas.world_to_screen = function(_, _, _, _, w, h) return w / 2, h / 2 end
	grug_map.atlas.scroll_factor = function() return 1 end
	grug_map.atlas.scroll_limit = function() return 1000 end
	grug_map.atlas.view = function()
		return {min_x = -4050, max_x = 4050, min_z = -3600, max_z = 3600, texture = "base.png"}
	end
	grug_map.quest_slots = function() return {} end
	grug_quests.journal = function() return {quests = {}, tracked = {}} end
	local player = {get_player_name = function() return "p" end, get_pos = function()
		return {x = 0, y = 0, z = 0} end}
	local function drawn_icon(info)
		local state = W.new_state()
		state.layer = "trainers"
		local ok, form = pcall(W.formspec, player, state, info)
		if not ok then return nil, form end
		local w, h = form:match("image%[[%d.%-]+,[%d.%-]+;([%d.]+),([%d.]+);grug_map_trainer_tailor%.png%]")
		return tonumber(w), form
	end
	for _, name in ipairs({"1920x1080", "1280x720", "3840x2160", "3840x2160 HUD 2",
			"phone 2400x1080 density 2.5"}) do
		local row = by[name]
		local icon, form = drawn_icon(row.info)
		local fw, fh = (form or ""):match("size%[([%d.]+),([%d.]+)%]")
		local _, per_unit = M.metrics(row.info, tonumber(fw), tonumber(fh))
		check(icon and math.floor(icon * per_unit) == row.after,
			("W %s: W.formspec draws %s px (wanted %d)"):format(name,
				icon and tostring(math.floor(icon * per_unit)) or tostring(form), row.after))
	end
	local icon = drawn_icon(nil)
	check(icon and math.floor(icon * 72) == M.SIZE, "W no window information: 21 px")

	-- G  the body text grows with the form on a grown ceiling (ruling 4):
	-- the "Current:" line, the quest rows and the zone labels; at 1080p
	-- the literals stay.
	grug_map.layers.zones = {{id = "z", name = "Dawnmere Fields", band = "1–10", x = 0, z = 0}}
	local function zones(info)
		local state = W.new_state()
		state.layer = "zones"
		seen.prose, seen.rows = nil, nil
		return W.formspec(player, state, info)
	end
	local form = zones(by["1920x1080"].info)
	check(seen.prose[1] == nil and seen.prose[2] == nil and seen.rows == 1 and
		form:find("style_type[label;font_size=*0.65]", 1, true) and
		form:find("style_type[label;font_size=*1]", 1, true), "G 1920x1080: literal sizes")
	local four = by["3840x2160"].info
	local fw, fh = zones(four):match("size%[([%d.]+),([%d.]+)%]")
	local growth = grug_core.ui.form_growth(four, tonumber(fw), tonumber(fh))
	form = zones(four)
	check(growth > 1.3 and growth < 1.4, ("G 3840x2160: the map window grows %.3f"):format(growth))
	check(seen.prose[1] == growth and seen.prose[2] == growth and seen.rows == growth,
		"G 3840x2160: the Current line and the quest rows grow")
	check(form:find(("style_type[label;font_size=*%.3f]"):format(0.65 * growth), 1, true) and
		form:find(("style_type[label;font_size=*%.3f]"):format(growth), 1, true),
		"G 3840x2160: zone labels grow and restore the grown body size")
	-- the label boxes in the window's own units (Round 67: the client's
	-- report, 144 px a unit at 4K, 72 at 1080p): the text grows by the growth
	-- in pixels, so its box (padding aside) does too
	local Z = grug_map.layers.zone_labels
	local wide = Z.box("Dawnmere Fields", "1–10", Z.metrics(four, 1, growth))
	local base = Z.box("Dawnmere Fields", "1–10", Z.metrics(by["1920x1080"].info, 1))
	local wide_px, base_px = (wide.w - 2 * Z.PAD_X) * 144, (base.w - 2 * Z.PAD_X) * 72
	check(math.abs(wide_px - base_px * growth) < 0.5,
		("G zone label text %.1f px at 4K, %.1f px at 1080p"):format(wide_px, base_px))
	print(("G 3840x2160 map window text growth %.3f"):format(growth))
end

-- ---------------------------------------------------------------------------
-- M  the minimap
-- ---------------------------------------------------------------------------
do
	-- the normal base (base.lua QUALITY.normal) over the atlas bounds
	local v = V.new({quality = "normal", width = 1215, height = 1080, tiles = {}},
		{min_x = -4050, max_x = 4050, min_z = -3600, max_z = 3600})
	local ref = V.frame(v, layout.minimap_box({size = {x = 1920, y = 1080},
		real_hud_scaling = 1}))
	for _, row in ipairs(rows) do
		local frame = V.frame(v, layout.minimap_box(row.info))
		local cap = M.metrics({real_hud_scaling = frame.hud})
		row.mini.hole = 2 * frame.hole
		row.mini.before = cap
		row.mini.after = M.fit(cap, frame.hole, ref.hole)
		check(row.mini.after <= cap, "M " .. row.name .. ": inside the cap")
	end
	check(by["1920x1080"].mini.after == 21, "M 1920x1080 at the reference (21)")
	local phone = by["phone 2400x1080 density 2.5"].mini
	check(phone.box == by["1920x1080"].mini.box and phone.before == 53 and phone.after == 21,
		"M the phone's box is the desktop's (" .. phone.box .. " px): 21 px, not 53")
	check(by["1280x720"].mini.after < 21, "M 1280x720 smaller")
	-- minimap.lua's marker_px is this rule (the source names it)
	local file = assert(io.open(MAP .. "/minimap.lua", "rb"))
	local source = file:read("*a")
	file:close()
	check(source:find("markers.fit(markers.metrics({real_hud_scaling = frame.hud}),", 1, true) and
		source:find("frame.hole, reference_hole)", 1, true) and
		not source:find("markers.metrics({real_hud_scaling=frame.hud})", 1, true),
		"M minimap.lua sizes every marker by marker_px")
end

print(("%-30s %9s %7s %7s | %6s %6s %7s %7s"):format("profile", "map px", "before",
	"after", "box", "hole", "before", "after"))
for _, row in ipairs(rows) do
	print(("%-30s %9.0f %7d %7d | %6d %6.0f %7d %7d"):format(row.name, row.map, row.before,
		row.after, row.mini.box, row.mini.hole, row.mini.before, row.mini.after))
end

-- ---------------------------------------------------------------------------
-- C  the camps' icons
-- ---------------------------------------------------------------------------
do
	check(icons.marker("pvp_accord_low") == "war_camp_accord", "C an Accord war camp is blue")
	check(icons.marker("pvp_throng_high") == "war_camp", "C a Throng war camp keeps the red art")
	check(icons.marker("pvp_accord_high", "throng") == "war_camp_accord",
		"C the slot names a war camp's faction")
	check(icons.marker("camp_construction", "accord") == "camp_construction_accord" and
		icons.marker("camp_construction", "throng") == "camp_construction_throng",
		"C construction camps by their race's faction")
	check(icons.marker("camp_construction", nil) == "camp_construction",
		"C a construction camp of no faction keeps the plain cloth")
	check(icons.marker("pvp_fortress", "accord") == "fortress" and
		icons.marker("pvp_fortress", "throng") == "fortress", "C fortresses unchanged")
	check(icons.marker("mining_camp", "accord") == "mining_camp" and
		icons.marker("capital", "accord") == "capital", "C other kinds unchanged")
	check(icons.class("pvp_accord_low") == "war_camp" and icons.layer("camp_construction") == "pvp",
		"C class and layer unchanged")
	local function same(a, b)
		if #a ~= #b then return false end
		for y = 1, #a do
			if #a[y] ~= #b[y] then return false end
			for i = 1, #a[y] do if a[y][i] ~= b[y][i] then return false end end
		end
		return true
	end
	for master, list in pairs({war_camp = {"war_camp_accord"},
			camp_construction = {"camp_construction_accord", "camp_construction_throng"}}) do
		for _, name in ipairs(list) do
			local texture = "grug_map_" .. name .. ".png"
			local file = io.open(MAP .. "/textures/" .. texture, "rb")
			local png = file and file:read("*a")
			if file then file:close() end
			check(png and png:sub(2, 4) == "PNG" and png:byte(19) * 256 + png:byte(20) == 32 and
				png:byte(23) * 256 + png:byte(24) == 32, "C " .. texture .. " ships, 32x32")
			check(masks[texture] and same(masks[texture], masks["grug_map_" .. master .. ".png"]),
				"C " .. texture .. " has its master's mask")
		end
	end
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R66 MAP PORTABLE FAIL %d of %d"):format(#failures, checks), 0)
end
print(("R66 MAP PORTABLE PASS checks=%d"):format(checks))
