-- Release 0.45.1 lane TR portable test (LuaJIT): the profession trainer
-- window and the greetings (fix plan row 12).
--
--   luajit tools/r451_tr/portable_test.lua [REPO]
--
-- Loads under a stub engine the REAL grug_jobs/trainers.lua and
-- grug_repair/providers.lua, the real profession table of
-- grug_jobs/registry.lua and the real grug_inventory.wrap_text (ui.lua).
-- Checks:
--   B  the trainer window in every state (not learned, learned primary,
--      learned secondary, both primary slots taken, confirming the unlearn,
--      after cancel, each with and without the repair button): every button
--      in one bottom row (one y, one height), Close the rightmost and the
--      last element, no element outside the window, the button labels fit;
--   G  a greeting for every trainer profession and the mender, on top of the
--      trainer window (above the status line and the notice) and in the
--      mender's repair form, which is titled grug_jobs.MENDER_TITLE; no
--      greeting and the plain title in a teaching trainer's or a station's
--      repair form; a 200-character greeting fits whole, above the status
--      line, with nothing outside the window; the repair form with a full
--      page of rows stays inside its window;
--   F  nothing that eats the inventory key is focused first: the windows
--      hold no edit box (field, pwdfield, textarea), table, textlist,
--      dropdown, checkbox or scrollbar and no set_focus, so the engine's
--      initial focus (guiFormSpecMenu.cpp setInitialFocus: the last button
--      when there is no edit box or table) is Close. Real key handling is
--      GUI-only; the checklist covers it.
-- Prints "R451 TR PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

------------------------------------------------------------------------------
-- Stub engine.
------------------------------------------------------------------------------
local shown, receivers = {}, {}
core = {
	log = function() end,
	formspec_escape = function(text)
		return (tostring(text):gsub("[\\%[%];,]", "\\%0"))
	end,
	show_formspec = function(name, form, spec)
		shown[#shown + 1] = {name = name, form = form, spec = spec}
	end,
	register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	chat_send_player = function() end,
}

-- The real wrap_text, cut out of grug_inventory/ui.lua.
grug_inventory = {}
do
	local source = read_file("mods/PLAYER/grug_inventory/ui.lua")
	local body = source:match("(function grug_inventory%.wrap_text.-\nend)\n")
	assert(body, "grug_inventory.wrap_text not found in ui.lua")
	assert((loadstring or load)(body))()
end

-- The real profession table of registry.lua; the state functions stubbed
-- over a per-player record.
local state = {}
grug_jobs = {}
do
	local source = read_file("mods/PLAYER/grug_jobs/registry.lua")
	local literal = source:match("grug_jobs%.PROFESSIONS = (%b{})")
	assert(literal, "grug_jobs.PROFESSIONS not found in registry.lua")
	grug_jobs.PROFESSIONS = assert((loadstring or load)("return " .. literal))()
end
local function record(player) return state[player:get_player_name()] end
function grug_jobs.has(player, profession) return record(player).known[profession] == true end
function grug_jobs.primary_at(player, slot) return record(player).primary[slot] end
function grug_jobs.profession_level() return 3 end
function grug_jobs.crafts_in_tier() return 12 end
function grug_jobs.learn(player, profession)
	local rec, def = record(player), grug_jobs.PROFESSIONS[profession]
	if def.class == "primary" then
		if rec.primary[1] and rec.primary[2] then
			return false, "Two primary professions already learned. Unlearn one first."
		end
		rec.primary[rec.primary[1] and 2 or 1] = profession
	end
	rec.known[profession] = true
	return true, "Learned " .. def.name .. "."
end
function grug_jobs.unlearn(player, profession)
	local rec = record(player)
	rec.known[profession] = nil
	for slot = 1, 2 do if rec.primary[slot] == profession then rec.primary[slot] = nil end end
	return true, "Unlearned " .. grug_jobs.PROFESSIONS[profession].name .. "; its progression was lost."
end
-- The longest station name of the game stands in for every station.
grug_jobs.PROFESSION_STATIONS = setmetatable({}, {__index = function() return "bench" end})
function grug_jobs.station_info() return {display_name = "Jeweller's Workbench"} end
grug_sounds = {play = function() end}
grug_mobs = {register_start_socket_role = function() end}

dofile(ROOT .. "/mods/PLAYER/grug_jobs/trainers.lua")

-- grug_repair: the service seam service.lua defines, the real providers.
local provider_types = {}
local repair_allowed = true
grug_repair = {}
function grug_repair.register_provider(kind, fn) provider_types[kind] = fn end
function grug_repair.provider_permitted() return repair_allowed end
local quote_items = {}
function grug_repair.quote(player, provider)
	local total = 0
	for _, row in ipairs(quote_items) do total = total + row.price end
	return {owner = player:get_player_name(), provider = provider, items = quote_items, total = total}
end
grug_money = {format = function(copper) return copper .. "c" end}
dofile(ROOT .. "/mods/ITEMS/grug_repair/providers.lua")

------------------------------------------------------------------------------
-- Formspec parsing.
------------------------------------------------------------------------------
-- Elements as {type, args = {{part...}...}} with the escapes resolved.
local function parse(spec)
	local elements, i, n = {}, 1, #spec
	while i <= n do
		local open = spec:find("[", i, true)
		if not open then break end
		local kind = spec:sub(i, open - 1)
		local args, part, piece = {}, {}, {}
		local j = open + 1
		while j <= n do
			local c = spec:sub(j, j)
			if c == "\\" then
				piece[#piece + 1] = spec:sub(j + 1, j + 1)
				j = j + 2
			elseif c == "," then
				part[#part + 1] = table.concat(piece) piece = {}
				j = j + 1
			elseif c == ";" then
				part[#part + 1] = table.concat(piece) piece = {}
				args[#args + 1] = part part = {}
				j = j + 1
			elseif c == "]" then
				part[#part + 1] = table.concat(piece)
				args[#args + 1] = part
				break
			else
				piece[#piece + 1] = c
				j = j + 1
			end
		end
		elements[#elements + 1] = {type = kind, args = args}
		i = j + 1
	end
	return elements
end

-- Rough text width in real-coordinate units (overview.lua's 6.6 per unit).
local function text_width(text) return #text / 6.6 end
local EATERS = {field = true, pwdfield = true, textarea = true, table = true,
	textlist = true, dropdown = true, checkbox = true, scrollbar = true,
	set_focus = true, scrollbaroptions = false}

-- The layout checks every window shares; returns the parsed form.
local function layout(spec, label)
	local elements = parse(spec)
	local W, H
	for _, element in ipairs(elements) do
		if element.type == "size" then
			W, H = tonumber(element.args[1][1]), tonumber(element.args[1][2])
		end
	end
	check(W and H, label .. ": the window has a size")
	W, H = W or 0, H or 0
	local form = {elements = elements, W = W, H = H, buttons = {}, labels = {}}
	for _, element in ipairs(elements) do
		local kind, a = element.type, element.args
		check(not EATERS[kind], label .. ": no key-eating element (" .. kind .. ")")
		if kind == "label" then
			local x, y, text = tonumber(a[1][1]), tonumber(a[1][2]), a[2][1]
			form.labels[#form.labels + 1] = {x = x, y = y, text = text}
			check(x >= 0 and y - 0.21 >= 0 and y + 0.21 <= H and x + text_width(text) <= W,
				label .. ": label inside the window: " .. text)
		elseif kind == "button" or kind == "button_exit" then
			local b = {x = tonumber(a[1][1]), y = tonumber(a[1][2]), w = tonumber(a[2][1]),
				h = tonumber(a[2][2]), name = a[3][1], text = a[4][1], exit = kind == "button_exit"}
			form.buttons[#form.buttons + 1] = b
			check(b.x >= 0 and b.y >= 0 and b.x + b.w <= W and b.y + b.h <= H,
				label .. ": button inside the window: " .. b.name)
			check(text_width(b.text) + 0.2 <= b.w, label .. ": the label fits its button: " .. b.text)
		elseif kind == "item_image" then
			local x, y, w, h = tonumber(a[1][1]), tonumber(a[1][2]), tonumber(a[2][1]), tonumber(a[2][2])
			check(x >= 0 and y >= 0 and x + w <= W and y + h <= H, label .. ": image inside the window")
		end
	end
	local last = elements[#elements]
	check(last and last.type == "button_exit",
		label .. ": the last element is the Close button (the engine's first focus)")
	return form
end

local function find_label(form, text)
	for _, l in ipairs(form.labels) do if l.text == text then return l end end
end
local line_ys
-- Whether `text` is shown whole, wrapped as both windows wrap it.
local function shows(form, text)
	for _, y in ipairs(line_ys(form, text)) do
		if not y then return false end
	end
	return true
end
-- The y of each wrapped line of `text` (67 characters, both windows).
function line_ys(form, text)
	local ys = {}
	for piece in (grug_inventory.wrap_text(text, 67) .. "\n"):gmatch("(.-)\n") do
		local l = find_label(form, piece)
		ys[#ys + 1] = l and l.y or false
	end
	return ys
end

------------------------------------------------------------------------------
-- Players and the trainer flow.
------------------------------------------------------------------------------
local players = {}
local function new_player(name)
	state[name] = {known = {}, primary = {}}
	local player = {}
	function player:get_player_name() return name end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	players[name] = player
	return player
end
local function send(player, fields)
	for _, fn in ipairs(receivers) do
		if fn(player, "grug_jobs:trainer", fields) then return end
	end
end
local function last_spec(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

-- The trainer window's own checks: one button row, Close on the right, the
-- greeting on top, the status line below it.
local function trainer_check(player, profession, label, expect)
	local entry = last_spec(player:get_player_name())
	eq(entry.form, "grug_jobs:trainer", label .. ": the trainer window is shown")
	local form = layout(entry.spec, label)
	local row_y, row_h
	for _, b in ipairs(form.buttons) do
		row_y, row_h = row_y or b.y, row_h or b.h
		eq(b.y, row_y, label .. ": " .. b.name .. " shares the bottom row")
		eq(b.h, row_h, label .. ": " .. b.name .. " has the row's height")
	end
	local close = form.buttons[#form.buttons]
	eq(close and close.name, "grug_jobs_close", label .. ": Close is the last button")
	for _, b in ipairs(form.buttons) do
		check(b == close or b.x + b.w <= close.x, label .. ": " .. b.name .. " left of Close")
	end
	check(close and math.abs(close.x + close.w - (form.W - 0.4)) < 0.001,
		label .. ": Close sits at the right edge")
	check(close and math.abs(close.y + close.h - (form.H - 0.4)) < 0.001,
		label .. ": the row sits at the bottom")
	for _, l in ipairs(form.labels) do
		check(l.y + 0.21 <= row_y, label .. ": text above the button row: " .. l.text)
	end
	local names = {}
	for _, b in ipairs(form.buttons) do names[#names + 1] = b.name end
	eq(table.concat(names, " "), expect, label .. ": the buttons")
	-- The greeting on top, above the status line.
	local ys = line_ys(form, grug_jobs.GREETINGS[profession])
	local greeting_last = 0
	for index, y in ipairs(ys) do
		check(y ~= false, label .. ": greeting line " .. index .. " shown")
		greeting_last = math.max(greeting_last, y or 0)
	end
	local title = form.labels[1]
	check(title and title.text == grug_jobs.PROFESSIONS[profession].name .. " Trainer",
		label .. ": the title first")
	local status = form.labels[#ys + 2]
	check(status and status.y >= greeting_last + 0.42, label .. ": the status line below the greeting")
	return form
end

local TRAINERS = {}
for id in pairs(grug_jobs.PROFESSIONS) do
	if grug_jobs.trainer_teaches(id) then TRAINERS[#TRAINERS + 1] = id end
end
table.sort(TRAINERS)
eq(#TRAINERS, 7, "G seven trainer professions")

-- G: the greeting table holds the seven trainers and the mender, nothing else.
do
	local keys = 0
	for key, text in pairs(grug_jobs.GREETINGS) do
		keys = keys + 1
		check(key == "mender" or grug_jobs.trainer_teaches(key), "G greeting key is a trainer: " .. key)
		check(type(text) == "string" and #text > 0, "G greeting text: " .. key)
		check(not text:lower():find("placeholder", 1, true) and not text:find("[", 1, true),
			"G the picked text, no placeholder left: " .. key)
	end
	eq(keys, 8, "G seven trainer greetings and the mender's")
	check(grug_jobs.GREETINGS.cooking == nil, "G Cooking has no trainer and no greeting")
end

-- B: every state, with and without the repair button.
local function states(profession, with_repair)
	repair_allowed = with_repair
	local repair = with_repair and " grug_jobs_repair" or ""
	local label = profession .. (with_repair and " +repair" or "")
	local player = new_player("p_" .. label:gsub("%W", "_"))
	local primary = grug_jobs.PROFESSIONS[profession].class == "primary"
	check(grug_jobs.open_trainer(player, profession, {x = 1, y = 0, z = 0}, {}),
		label .. ": opens")
	trainer_check(player, profession, label .. " not learned",
		"grug_jobs_learn" .. repair .. " grug_jobs_close")
	send(player, {grug_jobs_learn = "Learn"})
	if primary then
		local form = trainer_check(player, profession, label .. " learned primary",
			"grug_jobs_unlearn" .. repair .. " grug_jobs_close")
		local notice = false
		for _, l in ipairs(form.labels) do
			if l.text:find("Learned " .. grug_jobs.PROFESSIONS[profession].name .. ". Craft", 1, true) == 1 then
				notice = true
			end
		end
		check(notice, label .. ": the learn notice is shown")
		send(player, {grug_jobs_unlearn = "Unlearn"})
		trainer_check(player, profession, label .. " confirming", "grug_jobs_confirm grug_jobs_cancel grug_jobs_close")
		send(player, {grug_jobs_cancel = "Cancel"})
		trainer_check(player, profession, label .. " cancelled",
			"grug_jobs_unlearn" .. repair .. " grug_jobs_close")
		send(player, {grug_jobs_unlearn = "Unlearn"})
		send(player, {grug_jobs_confirm = "Confirm unlearn"})
		trainer_check(player, profession, label .. " unlearned",
			"grug_jobs_learn" .. repair .. " grug_jobs_close")
	else
		trainer_check(player, profession, label .. " learned secondary",
			(with_repair and "grug_jobs_repair " or "") .. "grug_jobs_close")
	end
	send(player, {quit = "true"})
	-- A fresh window of a learned profession shows the Crafting tab hint.
	state[player:get_player_name()].known[profession] = true
	grug_jobs.open_trainer(player, profession, {x = 1, y = 0, z = 0}, {})
	local form = trainer_check(player, profession, label .. " reopened learned",
		(primary and "grug_jobs_unlearn " or "") .. (with_repair and "grug_jobs_repair " or "") ..
		"grug_jobs_close")
	check(shows(form, "Craft its recipes in the Crafting tab, with a Jeweller's Workbench nearby."),
		label .. ": the Crafting tab hint is shown")
	send(player, {quit = "true"})
end
for _, profession in ipairs(TRAINERS) do
	states(profession, true)
	states(profession, false)
end

-- G: the picked texts reach the windows escaped (an apostrophe, a colon and
-- the woodcarver's ";" stay text): every line of each greeting is one whole
-- label inside the window (no scrollbar: labels only, the window grows), and
-- the raw formspec carries the escaped semicolon.
do
	repair_allowed = true
	for _, profession in ipairs(TRAINERS) do
		local player = new_player("picked_" .. profession)
		grug_jobs.open_trainer(player, profession, {x = 1, y = 0, z = 0}, {})
		local entry = last_spec(player:get_player_name())
		local form = trainer_check(player, profession, "picked " .. profession,
			"grug_jobs_learn grug_jobs_repair grug_jobs_close")
		check(shows(form, grug_jobs.GREETINGS[profession]), "G picked " .. profession .. ": shown whole")
		if profession == "woodcarver" then
			check(entry.spec:find("You bring the magic\\; I'll teach", 1, true) ~= nil,
				"G the woodcarver's semicolon is escaped in the formspec")
		end
		send(player, {quit = "true"})
	end
end

-- B: both primary slots taken: the learn button stays, the status says so.
do
	repair_allowed = true
	local player = new_player("full")
	state.full.known = {tailor = true, goldsmith = true}
	state.full.primary = {"tailor", "goldsmith"}
	grug_jobs.open_trainer(player, "woodcarver", {x = 1, y = 0, z = 0}, {})
	local form = trainer_check(player, "woodcarver", "slots full",
		"grug_jobs_learn grug_jobs_repair grug_jobs_close")
	check(find_label(form, "Two primary professions already learned.") ~= nil, "slots full: status")
	send(player, {grug_jobs_learn = "Learn"})
	form = trainer_check(player, "woodcarver", "slots full refused",
		"grug_jobs_learn grug_jobs_repair grug_jobs_close")
	check(find_label(form, "Two primary professions already learned. Unlearn one first.") ~= nil,
		"slots full: the refusal notice")
end

-- G: a 200-character greeting fits whole, the window grows to hold it, and
-- the placeholder windows keep one height across the states.
do
	local heights = {}
	for _, entry in ipairs(shown) do
		if entry.form == "grug_jobs:trainer" then
			heights[parse(entry.spec)[2].args[1][2]] = true
		end
	end
	local count = 0
	for _ in pairs(heights) do count = count + 1 end
	eq(count, 1, "G the placeholder trainer windows share one height")
	local saved = grug_jobs.GREETINGS.tailor
	grug_jobs.GREETINGS.tailor = ("Ah, you're interested in learning the art of tailoring. " ..
		"Well, you've come to the right place! Thread, needle and patience: I teach all three, " ..
		"and the patience costs extra, friend. Sit down, mind the pins on the stool."):sub(1, 200)
	eq(#grug_jobs.GREETINGS.tailor, 200, "G the long greeting is 200 characters")
	repair_allowed = true
	local player = new_player("long")
	grug_jobs.open_trainer(player, "tailor", {x = 1, y = 0, z = 0}, {})
	trainer_check(player, "tailor", "long greeting", "grug_jobs_learn grug_jobs_repair grug_jobs_close")
	send(player, {grug_jobs_learn = "Learn"})
	trainer_check(player, "tailor", "long greeting learned", "grug_jobs_unlearn grug_jobs_repair grug_jobs_close")
	grug_jobs.GREETINGS.tailor = saved
end

------------------------------------------------------------------------------
-- The repair form: the mender's greeting, none elsewhere.
------------------------------------------------------------------------------
local function stack(name)
	return {get_name = function() return name end,
		get_description = function() return "Exceptional Reinforced Leather Gloves of the Owl\nx" end,
		get_wear = function() return 30000 end}
end
local function repair_form(provider, items, label)
	quote_items = items
	local player = new_player("r_" .. label:gsub("%W", "_"))
	check(grug_repair.open(player, provider), label .. ": the repair form opens")
	local entry = last_spec(player:get_player_name())
	check(entry.form:match("^grug_repair:service:") ~= nil, label .. ": the repair form is shown")
	local form = layout(entry.spec, label)
	local close = form.buttons[#form.buttons]
	eq(close and close.name, "close", label .. ": Close is the last button")
	return form
end
local mender = {kind = "trainer", profession = "cooking"}
local trainer = {kind = "trainer", profession = "tailor"}
local station = {kind = "station", pos = {x = 0, y = 0, z = 0}}
local full_page = {}
for i = 1, 9 do full_page[i] = {expected = stack("grug_gear:gloves_" .. i), price = 1234} end

for _, items in ipairs({{}, full_page}) do
	local tag = #items == 0 and " (empty)" or " (full page)"
	local form = repair_form(mender, items, "mender" .. tag)
	local ys = line_ys(form, grug_jobs.GREETINGS.mender)
	for index, y in ipairs(ys) do
		check(y ~= false, "mender" .. tag .. ": greeting line " .. index .. " shown")
	end
	local info = find_label(form, "All professions can repair your equipment for money.")
	check(info and ys[#ys] and info.y >= ys[#ys] + 0.42, "mender" .. tag .. ": the greeting above the info line")
	eq(form.labels[1].text, "Grudge-Free Repairs", "mender" .. tag .. ": the mender's title first")
	for _, other in ipairs({{trainer, "teaching trainer"}, {station, "station"}}) do
		local plain = repair_form(other[1], items, other[2] .. tag)
		check(line_ys(plain, grug_jobs.GREETINGS.mender)[1] == false, other[2] .. tag .. ": no greeting")
		eq(plain.H, 9, other[2] .. tag .. ": the form keeps its height")
		eq(plain.labels[1].text, "Equipment repairs", other[2] .. tag .. ": the plain title")
		check(find_label(plain, "All professions can repair your equipment for money.").y == 0.9,
			other[2] .. tag .. ": the info line where it was")
	end
end
do
	local saved = grug_jobs.GREETINGS.mender
	grug_jobs.GREETINGS.mender = ("Dents, dings and a grudge or two? Leave them all here. " ..
		"We hammer out the dents, we sand off the dings, and the grudges we keep for ourselves; " ..
		"we have a shelf for them in the back."):sub(1, 200)
	local form = repair_form(mender, full_page, "mender long greeting")
	for index, y in ipairs(line_ys(form, grug_jobs.GREETINGS.mender)) do
		check(y ~= false, "mender long greeting: line " .. index .. " shown")
	end
	grug_jobs.GREETINGS.mender = saved
end

if failures > 0 then
	error(("R451 TR PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R451 TR PORTABLE PASS checks=%d"):format(checks))
