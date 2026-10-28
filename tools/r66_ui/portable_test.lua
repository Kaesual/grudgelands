-- Round 66 lane UI portable test (LuaJIT): the grown viewport ceiling, text
-- growth and the creation window's faction buttons.
--
--   luajit tools/r66_ui/portable_test.lua [REPO]
--
-- Loads the REAL grug_core/ui.lua and ui_window.lua on a minimal stub and
-- checks them against the engine's fitting equations (guiFormSpecMenu.cpp
-- getImgsize/calculateImgsize, clientdynamicinfo.cpp calculateMaxFSSize) and
-- against a verbatim copy of the 0.65.0 functions:
--   C  the ceiling: height min(H, max(1080, 2/3 H)), width 1920 scaled by the
--      same factor, at most W; native fitting of real and legacy forms on the
--      padded screen equals fitting on that viewport; the responsive report
--      (window_information) is the one of that viewport;
--   U  up to 1620 px screen height every result is exactly the 0.65.0 one:
--      padding, responsive report, text_scale, frame, text growth 1, the
--      literal font sizes; 1280x720, 1920x1080 and 2560x1440 among them;
--   T  where the ceiling grew, form text keeps its 1080p proportion to the
--      inventory window's slots (font pixels follow GUI scale x density,
--      fontengine.cpp getFontSize; slots follow the viewport); a form that
--      does not grow (portrait, the fixed floor) gets growth 1;
--   F  the creation window's faction buttons (selection.lua): both subdued
--      in their colour while none is chosen, the chosen one at full strength
--      and bold, the other subdued; hover brighter; focus like the normal
--      state; no navigation underline; race/class keep the navigation style.
-- Prints the screen table of the lane report (computed, GUI scale 1).
local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function near(a, b, label, tolerance)
	return check(type(a) == "number" and math.abs(a - b) <= (tolerance or 1e-9),
		label .. " (" .. tostring(a) .. " / " .. tostring(b) .. ")")
end
local function read(path)
	local f = assert(io.open(repo .. "/" .. path, "rb"), "cannot read " .. path)
	local text = f:read("*a")
	f:close()
	return text
end

local report
core = {get_player_window_information = function() return report end,
	formspec_escape = function(s) return (tostring(s):gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(_, s) return s end}
grug_core, grug_sounds = {}, {CLICK_STYLE = ""}
grug_inventory = {UI = {frame_w = 20, window_h = 15}}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_window.lua")
local UI = grug_core.ui
local player = {get_player_name = function() return "fixture" end}

--
-- 0.65.0 (main 5e50b4f4), verbatim apart from the names.
--
local OLD = {}
do
	local WIDTH, HEIGHT = 1920, 1080
	local function positive(value)
		return type(value) == "number" and value > 0 and value < math.huge
	end
	local function dimensions(info)
		local size = type(info) == "table" and info.size
		if type(size) ~= "table" or not positive(size.x) or not positive(size.y) then return end
		return size.x, size.y, math.min(size.x, WIDTH), math.min(size.y, HEIGHT)
	end
	function OLD.window_padding(player, base, info)
		base = base or 0.05
		if info == nil and player and core.get_player_window_information then
			info = core.get_player_window_information(player:get_player_name())
		end
		local w, h, vw, vh = dimensions(info)
		if not w or (w == vw and h == vh) then
			return base == 0.05 and "" or ("padding[%g,%g]"):format(base, base)
		end
		return ("padding[%.6f,%.6f]"):format(
			(1 - vw / w * (1 - 2 * base)) / 2,
			(1 - vh / h * (1 - 2 * base)) / 2)
	end
	function OLD.window_information(info)
		local w, h, vw, vh = dimensions(info)
		local max = type(info) == "table" and info.max_formspec_size
		local rgs = type(info) == "table" and info.real_gui_scaling
		if not w or (w == vw and h == vh) or type(max) ~= "table" or
				not positive(max.x) or not positive(max.y) or not positive(rgs) then return info end
		local preferred = math.max(w / max.x, h / max.y)
		local virtual_preferred = math.max(0.5555 * 96 * rgs,
			preferred * math.min(vw, vh) / math.min(w, h))
		local result = {}
		for key, value in pairs(info) do result[key] = value end
		result.size = {x = vw, y = vh}
		result.max_formspec_size = {x = vw / virtual_preferred, y = vh / virtual_preferred}
		return result
	end
	function OLD.text_scale(player)
		if not player then return 1 end
		local info = core.get_player_window_information and
			core.get_player_window_information(player:get_player_name())
		info = OLD.window_information(info)
		if info and info.max_formspec_size then
			local rgs = math.max(1, info.real_gui_scaling or 1)
			local form_h = grug_inventory.UI.window_h
			return math.max(1 / rgs, math.min(1, info.max_formspec_size.y / form_h))
		end
		return 1
	end
	function OLD.frame(w, h, title, opaque, player)
		local fs = ("formspec_version[6]size[%.3f,%.3f]"):format(w, h) .. OLD.window_padding(player)
		if opaque then fs = fs .. "no_prepend[]" .. UI.prepend(true) end
		if title then
			fs = fs .. ("style_type[label;font=normal;font_size=*%.3f]"):format(1.1) ..
				("label[%.3f,%.3f;%s]"):format(0.4, 0.45, core.formspec_escape(title)) ..
				"style_type[label;font_size=*1]"
		end
		return fs
	end
end

--
-- The engine's equations, independently of ui_window.lua.
--
local function preferred(w, h, gui, density)
	return math.max(0.5555 * 96 * density * gui, math.min(w, h) / 15 * gui)
end
local function information(w, h, gui, density)
	local slot = preferred(w, h, gui, density)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / slot, y = h / slot},
		real_gui_scaling = gui * density}
end
local function fitted(w, h, gui, density, fw, fh, padding, legacy)
	local px, py = (padding or ""):match("padding%[([^,]+),([^%]]+)%]")
	px, py = tonumber(px) or 0.05, tonumber(py) or 0.05
	local aw, ah = w * (1 - 2 * px), h * (1 - 2 * py)
	if legacy then fw, fh = 1.25 * (0.5 + fw), 15 / 13 * (0.85 + fh) end
	return math.min(preferred(aw, ah, gui, density), aw / fw, ah / fh)
end
-- Ruling 4, written out.
local function ceiling(w, h)
	local vh = math.min(h, math.max(1080, h * 2 / 3))
	return math.min(w, 1920 * math.max(1, vh / 1080)), vh
end
local function same_table(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same_table(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

local SIZES = {{1035, 696}, {1280, 720}, {1920, 1080}, {2560, 1440}, {3440, 1440},
	{2560, 1600}, {1920, 1620}, {2880, 1620}, {1920, 1621}, {3840, 2160}, {5120, 2160},
	{5120, 2880}, {2400, 1080}, {1080, 2400}, {1200, 1600}, {1600, 2560}}
local SCALES = {{1, 1}, {1.5, 1}, {2, 1}, {2.5, 1}, {1, 2}, {1.5, 2}, {1, 1.25}}
local FORMS = {{20, 15}, {20, 16.04}, {15, 10.6}, {18.8, 12.2}, {10, 3}, {8, 4.3}, {11, 20},
	{8, 4, true}}

for _, size in ipairs(SIZES) do
	for _, scale in ipairs(SCALES) do
		local w, h, gui, density = size[1], size[2], scale[1], scale[2]
		local tag = ("%dx%d gui %g density %g"):format(w, h, gui, density)
		report = information(w, h, gui, density)
		local vw, vh = ceiling(w, h)
		local padding = UI.window_padding(player)
		-- C: native fitting on the padded screen = fitting on the ceiling.
		for _, form in ipairs(FORMS) do
			near(fitted(w, h, gui, density, form[1], form[2], padding, form[3]),
				fitted(vw, vh, gui, density, form[1], form[2], "", form[3]),
				"C native frame equals the ceiling " .. tag, 0.002)
		end
		local virtual = UI.window_information(report)
		local expected = information(vw, vh, gui, density)
		near(virtual.size.x, vw, "C responsive width " .. tag)
		near(virtual.size.y, vh, "C responsive height " .. tag)
		near(virtual.max_formspec_size.x, expected.max_formspec_size.x, "C responsive units x " .. tag, 1e-6)
		near(virtual.max_formspec_size.y, expected.max_formspec_size.y, "C responsive units y " .. tag, 1e-6)
		check(report.size.x == w and report.size.y == h, "C the report is not mutated " .. tag)
		local map_padding = UI.window_padding(nil, 0, report)
		near(fitted(w, h, gui, density, virtual.max_formspec_size.x * 0.85,
			virtual.max_formspec_size.y * 0.85, map_padding),
			fitted(vw, vh, gui, density, expected.max_formspec_size.x * 0.85,
			expected.max_formspec_size.y * 0.85, "padding[0,0]"), "C map window on the ceiling " .. tag, 0.002)

		if h <= 1620 then
			-- U: byte-identical with 0.65.0.
			check(padding == OLD.window_padding(player), "U padding " .. tag)
			check(map_padding == OLD.window_padding(nil, 0, report), "U map padding " .. tag)
			-- 0.65.0's report plus the pass-through mark (never in a form).
			local old = OLD.window_information(report)
			if old ~= report then old.capped = true end
			check(same_table(virtual, old), "U responsive report " .. tag)
			check(UI.window_information(virtual) == virtual, "C a derived report passes through " .. tag)
			check(UI.text_scale(player) == OLD.text_scale(player), "U text_scale " .. tag)
			for _, form in ipairs(FORMS) do
				check(UI.text_growth(player, form[1], form[2]) == 1, "U growth 1 " .. tag)
				check(UI.frame(form[1], form[2], "Title", false, player) ==
					OLD.frame(form[1], form[2], "Title", false, player), "U frame " .. tag)
				check(UI.frame(form[1], form[2], nil, true, player) ==
					OLD.frame(form[1], form[2], nil, true, player), "U opaque frame " .. tag)
			end
		else
			-- T: font pixels / slot pixels as under the Full-HD ceiling.
			local font = 16 * gui * density
			local fw, fh = 20, 15
			local s_new = fitted(w, h, gui, density, fw, fh, padding)
			local s_ref = fitted(math.min(w, 1920), math.min(h, 1080), gui, density, fw, fh, "")
			near(font * UI.text_scale(player) / s_new, font * OLD.text_scale(player) / s_ref,
				"T text keeps its 1080p proportion " .. tag, 1e-6)
			for _, form in ipairs(FORMS) do
				if not form[3] then
					local grown = fitted(w, h, gui, density, form[1], form[2], UI.window_padding(player))
					local ref = fitted(math.min(w, 1920), math.min(h, 1080), gui, density, form[1], form[2], "")
					near(UI.text_growth(player, form[1], form[2]), grown / ref,
						"T growth is the form's growth " .. tag, 1e-6)
				end
			end
		end
	end
end

-- The ruling's figures.
report = information(3840, 2160, 1, 1)
local v = UI.window_information(report)
check(v.size.x == 2560 and v.size.y == 1440, "C 3840x2160 lays out like 2560x1440")
near(UI.text_growth(player), 4 / 3, "T 3840x2160 inventory text grows by 4/3")
near(UI.text_scale(player), 4 / 3, "T 3840x2160 text_scale 4/3 at GUI 1")
report = information(1080, 2400, 2.5, 1)
check(UI.text_growth(player) == 1, "T a portrait phone's inventory is width-bound: no growth")
report = information(3840, 2160, 1, 2)
check(UI.text_growth(player, 8, 4.3) == 1, "T the fixed floor holds a small dialog: no growth")

-- Literal sizes keep their bytes at growth 1 and scale otherwise.
for literal, factor in pairs({["*0.85"] = 0.85, ["*1"] = 1, ["*0.75"] = 0.75, ["*0.8"] = 0.8,
		["*1.1"] = 1.1, ["*1.4"] = 1.4, [""] = false}) do
	check(UI.font_size(factor or nil, 1) == literal and UI.font_size(factor or nil) == literal,
		"U literal " .. literal)
end
check(UI.font_size(0.85, 4 / 3) == "*1.133" and UI.font_size(nil, 4 / 3) == "*1.333",
	"T literal sizes grow")
check(UI.title(1, 2, "X") == UI.title(1, 2, "X", nil, 1), "U title reset")
report = information(3840, 2160, 1, 1)
local grown = UI.frame(20, 15, "Title", false, player)
check(grown:find(UI.fonts(4 / 3), 1, true) ~= nil and
	grown:find("label;font_size=*1.333]", 1, true) ~= nil, "T a grown frame scales its text defaults")
report = nil
check(UI.text_growth(player) == 1 and UI.text_scale(player) == 1, "U no report: native, unscaled")
check(UI.text_growth(nil) == 1, "U no player")
for _, invalid in ipairs({{}, {size = {x = 0, y = 2160}}, {size = {x = 0 / 0, y = 2160}},
		{size = {x = 3840, y = 2160}}}) do
	report = invalid
	check(UI.text_growth(player) == 1, "U a malformed report never scales text")
end

-- The screen table of the lane report (GUI scale 1, density 1; the phone at 2.5).
print("screen          gui  viewport     text_scale growth inventory/height")
for _, row in ipairs({{1280, 720, 1}, {1920, 1080, 1}, {2560, 1440, 1}, {3440, 1440, 1},
		{3840, 2160, 1}, {2400, 1080, 2.5}, {1080, 2400, 2.5}}) do
	report = information(row[1], row[2], row[3], 1)
	local info = UI.window_information(report)
	local s = fitted(row[1], row[2], row[3], 1, 20, 15, UI.window_padding(player))
	print(("%4dx%-4d       %-4g %4dx%-4d    %.3f      %.3f  %.0f %%"):format(row[1], row[2], row[3],
		info.size.x, info.size.y, UI.text_scale(player), UI.text_growth(player), 100 * 15 * s / row[2]))
end

--
-- F: the faction buttons, from the real selection.lua.
--
do
	local source = read("mods/PLAYER/grug_classes/selection.lua")
	local body = source:match("\n(local FACTION_SUBDUED.-\nlocal function button%(.-\nend)\n")
	if check(body ~= nil, "F faction style and button() found") then
		local env = setmetatable({esc = core.formspec_escape}, {__index = _G})
		local chunk = assert(loadstring(body .. "\nreturn button"))
		setfenv(chunk, env)
		local button = chunk()
		local colours = {accord = "#3f6fce", throng = "#c41e3a"}
		local function row(chosen)
			local fs = {growth = 1}
			for _, id in ipairs({"accord", "throng"}) do
				button(fs, 0, 0, 7, 0.9, "faction_" .. id, id, "tip", colours[id], chosen == id)
			end
			return table.concat(fs)
		end
		local function style(fs, field, state)
			local key = state and (field .. ":" .. state) or field
			return fs:match("style%[" .. key:gsub("%p", "%%%0") .. ";([^%]]-)%]") or ""
		end
		local function fill(fs, field, state)
			return style(fs, field, state):match("bgimg=\\%[fill:16x16:(#%x+)")
		end
		local none = row(nil)
		for id, colour in pairs(colours) do
			local field = "faction_" .. id
			check(fill(none, field) == colour .. "61", "F " .. id .. " subdued (38 %) with none chosen")
			check(fill(none, field, "focused") == fill(none, field), "F " .. id .. " focus looks normal")
			check(style(none, field, "focused"):find("textcolor=#eeeae1", 1, true) ~= nil,
				"F " .. id .. " focus keeps the normal text")
			check(fill(none, field, "hovered") == colour .. "80", "F " .. id .. " hover a little brighter")
			check(fill(none, field, "pressed") == colour .. "9e", "F " .. id .. " pressed")
			check(not none:find("style%[" .. field .. ";font=bold%]"), "F " .. id .. " not bold unchosen")
		end
		check(not none:find("box[", 1, true) and not none:find("grug_ui_focus", 1, true) and
			not none:find("grug_ui_nav", 1, true), "F no navigation underline or shared focus look")
		for id, colour in pairs(colours) do
			local other = id == "accord" and "throng" or "accord"
			local fs = row(id)
			check(fill(fs, "faction_" .. id) == colour .. "ff" and
				fill(fs, "faction_" .. id, "focused") == colour .. "ff" and
				fill(fs, "faction_" .. id, "hovered") == colour .. "ff", "F chosen " .. id .. " at full strength")
			check(fs:find("style[faction_" .. id .. ";font=bold]", 1, true) ~= nil, "F chosen " .. id .. " bold")
			check(fill(fs, "faction_" .. other) == colours[other] .. "61" and
				not fs:find("style[faction_" .. other .. ";font=bold]", 1, true), "F the other stays subdued")
		end
		local fs = {growth = 4 / 3}
		button(fs, 0, 0, 7, 0.9, "faction_accord", "A", "tip", "#3f6fce", false)
		check(table.concat(fs):find("font_size=*1.333", 1, true) ~= nil, "F faction text grows with the window")
		fs = {growth = 1}
		button(fs, 0, 0, 3, 0.8, "race_human", "Human", "tip", nil, true)
		local race = table.concat(fs)
		check(race:find("grug_ui_nav_selected.png", 1, true) ~= nil and race:find("box[", 1, true) ~= nil,
			"F race buttons keep the navigation style")
		fs = {growth = 1}
		button(fs, 0, 0, 3, 0.8, "create_character", "Create", "tip", "#2f6a2a", false)
		check(table.concat(fs):find("style[create_character;bgcolor=#2f6a2a]", 1, true) ~= nil,
			"F Create character keeps its green")
	end
	check(source:find("grug_core.factions%[id%]%.color, draft%.faction == id%)") ~= nil,
		"F the faction row passes each faction's own colour and the choice")
	check(not source:find("dimmed", 1, true), "F the dead dimming code is gone")
end

if failures > 0 then
	error(("R66 UI PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
print(("R66 UI PORTABLE PASS checks=%d"):format(checks))
