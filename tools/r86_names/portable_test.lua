-- Round 86 lane NAMES portable test (LuaJIT): home names
-- (docs/planning/round86-plan.md rulings 8, 9, 12, 15; housing concept
-- ruling 11).
--
--   luajit tools/r86_names/portable_test.lua [repo]
--
-- Loads the REAL grug_housing registry.lua, api.lua and names.lua, and
-- grug_core hud_layout.lua and flash.lua, on a fake engine. Checks:
--   V  the rule of a typed name (ruling 8): ASCII letters, digits, space,
--      apostrophe, hyphen, 1-24 characters, no leading or trailing space;
--      "|", ";", "]", "[", ",", "\", a newline, a tab, a colour escape,
--      "_", non-ASCII and 24 wide glyphs refused, 24 "W" accepted;
--   R  the record: the default "<character>'s Home" stored at placement
--      (the longest player name too), a set name and a refused one survive
--      a reload with the record intact, a 0.85.0 record with an empty name
--      reads the default, the reset; an account claim's default: the
--      placer's name kept through the activation, else the first member by
--      name (lane STONE's member index), never the owner text, "Home"
--      without one;
--   A  the engine side (names.lua): a rename by the owner (and by a member
--      of an account claim, through is_owner), the refusal for anybody
--      else (an unjoined character of the account too) and for a bad name,
--      an unchanged name kept without a refusal, the event "renamed", the admin command
--      /claim_name_reset with <player> and here;
--   L  the icon's placement before a centred HUD text (hud_layout): the
--      estimated widths, the font size, the icon and the text centred
--      together;
--   F  the flash line with an icon (the protection hint) and without;
--   H  Help's line on home names.
-- Prints "R86 NAMES PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local function new_storage()
	local data = {}
	return {data = data, get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end}
end
local registry = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
local clock = 1800000000

-- ---------------------------------------------------------------------------
-- V  the rule of a typed name
-- ---------------------------------------------------------------------------
do
	local model = registry({storage = new_storage(), now = function() return clock end})
	eq(model.NAME_MAX, 24, "V at most 24 characters")
	local ok_cases = {"A", "Bob's Home", "Rook's Rest", "Hill-Top 2", "o'Neil - the 3rd",
		("W"):rep(24), "a  b"}
	for _, text in ipairs(ok_cases) do
		check(model.valid_name(text) == true, "V accepted: " .. text)
	end
	local refused = {
		{"", "Type a name"}, {("a"):rep(25), "at most 24"},
		{" Home", "start or end"}, {"Home ", "start or end"},
		{"Bob|Home", "only letters"}, {"Bob;Home", "only letters"},
		{"Bob]Home", "only letters"}, {"Bob[Home", "only letters"},
		{"Bob,Home", "only letters"}, {"Bob\\Home", "only letters"},
		{"Bob\nHome", "only letters"}, {"Bob\tHome", "only letters"},
		{"\27(c@#ff0000)Red", "only letters"}, {"Bob_Home", "only letters"},
		{"Caf\195\169", "only letters"}, {("\230\152\159"):rep(24), "only letters"},
		{("\239\188\183"):rep(8), "only letters"}, {"Home\0", "only letters"},
		{"A=B", "only letters"}, {"<b>", "only letters"},
	}
	for _, case in ipairs(refused) do
		local ok, why = model.valid_name(case[1])
		check(ok == false and type(why) == "string" and why:find(case[2], 1, true) ~= nil,
			("V refused (%q): %s"):format(case[1], tostring(why)))
	end
	check(model.valid_name(nil) == false and model.valid_name(24) == false,
		"V not a string: refused")
end

-- ---------------------------------------------------------------------------
-- R  the record
-- ---------------------------------------------------------------------------
do
	local storage = new_storage()
	local model = registry({storage = storage, now = function() return clock end})
	model.load()
	local ann = model.create("ann", {x = 0, y = 5, z = 0})
	eq(ann.name, "ann's Home", "R the default stored at placement")
	eq(model.home_name(ann), "ann's Home", "R ...and read")
	check(storage.get_string("claim:" .. ann.id):sub(-11) == "|ann's Home",
		"R ...as the record's last field")
	local long = ("Abcdefghij_klmnop-qr")
	local far = model.create(long, {x = 400, y = 5, z = 0})
	eq(model.home_name(far), long .. "'s Home", "R the longest player name: its default whole")
	check(model.placement_name("x", "account") == "x's Home",
		"R an account stone's default names the character that placed it")

	check(model.set_name(ann, "Rook's Rest"), "R a valid name is set")
	local ok, why = model.set_name(ann, "Bad|Name\nx")
	check(ok == false and why ~= nil, "R a bad name is refused by the setter itself")
	eq(model.home_name(ann), "Rook's Rest", "R ...and changes nothing")
	check(not model.set_name({id = 999, owner = "x"}, "Fine"), "R no such claim: refused")

	-- a reload reads the name back; the record stays whole
	local again = registry({storage = storage, now = function() return clock end})
	eq(#again.load(), 0, "R every record decodes after the rename")
	local back = again.claim_at({x = 0, y = 5, z = 0})
	eq(back and again.home_name(back), "Rook's Rest", "R the name survives a reload")
	eq(again.home_name(again.claim_at({x = 400, y = 5, z = 0})), long .. "'s Home",
		"R ...and the long default")

	-- a 0.85.0 record: kind and name empty
	storage.set_string("claim:" .. ann.id, (storage.get_string("claim:" .. ann.id):gsub(
		"|Rook's Rest$", "|")))
	local old = registry({storage = storage, now = function() return clock end})
	eq(#old.load(), 0, "R a 0.85.0 record with an empty name loads")
	local plain = old.claim_at({x = 0, y = 5, z = 0})
	eq(plain.name, "", "R ...its name empty")
	eq(old.home_name(plain), "ann's Home", "R ...reads the owner's default")
	eq(old.home_name({owner = "Jens"}), "Jens's Home", "R a table without the field: the default")

	-- the reset
	old.set_name(plain, "Whatever")
	local done, name = old.reset_name(plain)
	check(done and name == "ann's Home" and plain.name == "ann's Home",
		"R the reset stores the default")

	-- an account claim (Round 86 lane STONE's membership): the default
	-- names the placer and survives the activation, which makes the owner
	-- the owner text; an empty name reads the first member by name, never
	-- the owner text; "Home" with no member
	local OWNER = old.owner_text("acc_7", "accord")
	old.join("zed", OWNER)
	old.join("mia", OWNER)
	local acc = old.create("zed", {x = 800, y = 5, z = 0}, "account")
	eq(acc.name, "zed's Home", "R an account draft: the placing character's default")
	eq(old.activate(acc, 5), 5, "R ...activated")
	eq(acc.owner, OWNER, "R ...its owner now the owner text")
	eq(old.home_name(acc), "zed's Home", "R ...the stored name survives the activation")
	acc.name = ""
	eq(old.default_name(acc), "mia's Home", "R an empty name: the first member by name")
	check(not old.home_name(acc):find("account:", 1, true), "R ...never the owner text")
	old.reset_name(acc)
	eq(old.home_name(acc), "mia's Home", "R ...stored by the reset")
	check(old.is_owner(acc, "zed") and old.is_owner(acc, "mia") and not old.is_owner(acc, "bo"),
		"R members own the account claim (is_owner), a visitor does not")
	old.end_membership("mia")
	old.end_membership("zed")
	eq(old.default_name(acc), "Home", "R no member left: Home")
	acc.name = ""
	eq(old.home_name(acc), "Home", "R ...also for an empty name")
end

-- ---------------------------------------------------------------------------
-- A  the engine side: names.lua over the real api.lua
-- ---------------------------------------------------------------------------
local commands, events, logs = {}, {}, {}
local online = {}
rawset(_G, "core", {
	get_modpath = function(mod) return repo .. "/mods/PLAYER/" .. mod end,
	get_mod_storage = function()
		local data = {}
		return {get_string = function(_, k) return data[k] or "" end,
			set_string = function(_, k, v) data[k] = v ~= "" and v or nil end,
			get_keys = function() local keys = {} for k in pairs(data) do keys[#keys + 1] = k end return keys end}
	end,
	register_chatcommand = function(name, def) commands[name] = def end,
	log = function(_, line) logs[#logs + 1] = line end,
	get_player_by_name = function(name) return online[name] end,
	get_player_window_information = function() return nil end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
	after = function() end,
})
function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
rawset(_G, "grug_core", {map_reset = {clear = function() end, pending = function() return false end},
	severe = {report = function() end}})
rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
dofile(repo .. "/mods/PLAYER/grug_housing/names.lua")
do
	local H, model = grug_housing, grug_housing.model
	H.register_on_claim_changed(function(claim, event) events[#events + 1] = event .. ":" .. claim.id end)
	eq(H.NAME_MAX, 24, "A NAME_MAX published")
	eq(H.HOME_ICON, "grug_map_home.png", "A the house icon (the map's home marker, the user's pick)")
	local claim = model.create("ann", {x = 0, y = 5, z = 0})
	local ok, message = H.rename(claim, "ann", "Rook's Rest")
	check(ok and message:find("Rook's Rest", 1, true), "A the owner renames: " .. tostring(message))
	eq(H.home_name(claim), "Rook's Rest", "A ...read through the API")
	eq(events[#events], "renamed:" .. claim.id, "A ...the event renamed")
	local count = #events
	ok, message = H.rename(claim, "bob", "Bob's Now")
	check(not ok and message:find("owner", 1, true), "A anybody else is refused")
	ok, message = H.rename(claim, "ann", "Rook|Rest")
	check(not ok and message:find("only letters", 1, true), "A a bad name is refused")
	eq(#events, count, "A ...no event for a refusal")
	eq(H.home_name(claim), "Rook's Rest", "A ...the name unchanged")

	-- an unchanged name is kept without a refusal, also a default the rule
	-- refuses ("_", more than 24 characters)
	local odd = model.create("long_name_of_twenty1", {x = 400, y = 5, z = 0})
	count = #events
	ok, message = H.rename(odd, "long_name_of_twenty1", "long_name_of_twenty1's Home")
	check(ok and message == "Your home keeps its name." and #events == count,
		"A an unchanged default: kept, no refusal, no event: " .. tostring(message))
	ok, message = H.rename(claim, "ann", "Rook's Rest")
	check(ok and message == "Your home keeps its name.", "A an unchanged typed name: kept")

	-- an account claim (lane STONE's membership): every member renames
	-- through is_owner; a character of the same account that has not
	-- joined, and a visitor, cannot
	local OWNER = model.owner_text("acc_7", "accord")
	model.join("zed", OWNER)
	model.join("mia", OWNER)
	local acc = model.create("zed", {x = 800, y = 5, z = 0}, "account")
	model.activate(acc, 5)
	eq(H.home_name(acc), "zed's Home", "A the account claim: the placer's name after activation")
	check(H.rename(acc, "mia", "The Hold"), "A a member renames the account claim")
	eq(H.home_name(acc), "The Hold", "A ...renamed")
	check(not H.rename(acc, "kit", "Not Mine"), "A ...an unjoined character cannot")
	check(not H.rename(acc, "ann", "Not Mine"), "A ...a visitor cannot")

	-- the admin command
	local cmd = commands.claim_name_reset
	check(cmd and cmd.privs.server, "A /claim_name_reset needs server")
	ok, message = cmd.func("admin", "ann")
	check(ok and H.home_name(claim) == "ann's Home" and message:find("ann's Home", 1, true) and
		message:find("Rook's Rest", 1, true), "A <player>: the default again: " .. tostring(message))
	eq(events[#events], "renamed:" .. claim.id, "A ...with the event")
	ok, message = cmd.func("admin", "zed")
	check(ok and H.home_name(acc) == "mia's Home", "A a member's name finds the account claim, " ..
		"reset to the first member's default: " .. tostring(message))
	check(not message:find("account:", 1, true), "A ...the answer never shows the owner text")
	online.admin = {get_pos = function() return {x = 810, y = 7, z = 5} end}
	H.rename(acc, "zed", "Again Named")
	ok = cmd.func("admin", "here")
	check(ok and H.home_name(acc) == "mia's Home", "A here on the account claim: the first member's default")
	online.admin = {get_pos = function() return {x = 5000, y = 7, z = 5} end}
	ok, message = cmd.func("admin", "here")
	check(not ok and message:find("not standing", 1, true), "A here outside claims: refused")
	ok = cmd.func("admin", "nobody")
	check(not ok, "A an unknown player: refused")
	ok = cmd.func("admin", "")
	check(not ok, "A no parameter: the usage")
end

-- ---------------------------------------------------------------------------
-- L  the icon before a centred HUD text
-- ---------------------------------------------------------------------------
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local layout = grug_core.hud_layout
do
	-- Arimo Regular: W 0.944, i 0.222, space 0.278 (fonts/Arimo-Regular.ttf)
	eq(layout.text_px("W", 100), 94, "L a W is 0.944 em")
	eq(layout.text_px("i i", 100), 22 + 28 + 22, "L glyphs add up, each rounded")
	eq(layout.text_px("W", 100, true), 94, "L bold W")
	eq(layout.text_px("a", 100, true), 56, "L bold a")
	eq(layout.text_px("b", 100, true), 61, "L bold b is wider than regular")
	eq(layout.text_px("x – y", 100), 50 + 28 + 56 + 28 + 50, "L the hint's en dash")
	eq(layout.text_px("\230\152\159", 100), 95, "L an unknown glyph counts WIDE_EM")
	eq(layout.text_px(("W"):rep(24), 40, true), 24 * 38, "L 24 W in the banner's font")
	eq(layout.font_px(nil, nil), 16, "L the default font at scale 1")
	eq(layout.font_px(2.5, {real_gui_scaling = 1.5}), 60, "L the banner's size at GUI 1.5")
	eq(layout.font_px(nil, {real_gui_scaling = 1.25}), 20, "L the default font at GUI 1.25")
	local g = layout.icon_before("ann's Home", 40, true)
	local w = layout.text_px("ann's Home", 40, true)
	eq(g.size, 48, "L the icon 1.2 em")
	local gap = math.floor(0.4 * 40 + 0.5)
	-- the group (icon, gap, text) is centred on the old centre
	local left = g.icon_x - g.size / 2
	local right = g.text_x + w / 2
	check(math.abs(left + right) < 1e-9, "L icon and text centred together")
	check(math.abs((g.text_x - w / 2) - (g.icon_x + g.size / 2) - gap) < 1e-9,
		"L the gap between them is 0.4 em (fix round 2: 0.3 nearly touched at scale 1.5)")
	local o = layout.icon_before_offsets("ann's Home", 2.5, true,
		{real_hud_scaling = 2, real_gui_scaling = 1}, 32)
	check(math.abs(o.text_x - g.text_x / 2) < 1e-9 and math.abs(o.icon_x - g.icon_x / 2) < 1e-9,
		"L offsets in HUD units (HUD scaling 2)")
	check(math.abs(o.scale - (48.25 / 64)) < 1e-9, "L the scale draws the icon 48 px at HUD 2")
end

-- ---------------------------------------------------------------------------
-- F  the flash line with an icon
-- ---------------------------------------------------------------------------
do
	local joins, timers = {}, {}
	core.register_on_joinplayer = function(fn) joins[#joins + 1] = fn end
	core.after = function(_, fn) timers[#timers + 1] = fn end
	dofile(repo .. "/mods/CORE/grug_core/flash.lua")
	local huds, next_id = {}, 0
	local p = {name = "sam"}
	function p:get_player_name() return self.name end
	function p:hud_add(def)
		next_id = next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		huds[next_id] = copy
		return next_id
	end
	function p:hud_change(id, stat, value) huds[id][stat] = value end
	online.sam = p
	for _, fn in ipairs(joins) do fn(p) end
	local text_id = next_id
	check(grug_core.flash(p, "Too hard"), "F a plain flash")
	eq(next_id, text_id, "F ...adds no icon element")
	eq(huds[text_id].offset.x, 0, "F ...centred")
	grug_core.flash(p, "ann's Home – protected", grug_core.FLASH_COLOR.notice, "grug_map_home.png")
	local icon = huds[next_id]
	check(next_id == text_id + 1 and icon.type == "image" and icon.text == "grug_map_home.png",
		"F the hint with its icon: one image element")
	local g = layout.icon_before_offsets("ann's Home – protected", nil, false, nil, 32)
	check(math.abs(huds[text_id].offset.x - g.text_x) < 1e-9 and
		math.abs(icon.offset.x - g.icon_x) < 1e-9 and icon.offset.y == huds[text_id].offset.y,
		"F ...the text moved right, the icon left of it on its line")
	eq(huds[text_id].text, "ann's Home – protected", "F ...the line")
	grug_core.flash(p, "Too hard")
	check(icon.text == "" and huds[text_id].offset.x == 0, "F a plain flash after it: no icon, centred")
	grug_core.flash(p, "ann's Home – protected", nil, "grug_map_home.png")
	eq(next_id, text_id + 1, "F the icon element is reused")
	timers[#timers - 1]() -- an older flash's timer: nothing
	eq(icon.text, "grug_map_home.png", "F an old timer leaves the newer hint")
	timers[#timers]()
	check(huds[text_id].text == "" and icon.text == "" and huds[text_id].offset.x == 0,
		"F the flash's end hides the icon too")
end

-- Help's line under the Housing heading (the source, as tools/r69_ui reads it)
do
	local file = assert(io.open(repo .. "/mods/PLAYER/grug_inventory/help.lua"))
	local help = file:read("*a")
	file:close()
	local line = help:match('"(• Every home has a name[^"]*)"')
	check(line and line:find("Rename it on your Claim Stone (in an account home every member " ..
		"may): up to 24 letters A-Z, digits, spaces, ' and -.", 1, true) ~= nil,
		"H the Help line on home names")
	check(line and not line:find("[<\\]"), "H ...without hypertext control characters")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R86 NAMES PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R86 NAMES PORTABLE PASS checks=" .. checks)
