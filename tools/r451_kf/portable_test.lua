-- 0.45.1 lane KF portable test (LuaJIT): the inventory key closes every
-- window, because no window opens with an element focused that eats a
-- letter key (an edit box, a read-only textarea included, or a table).
--
--   luajit tools/r451_kf/portable_test.lua [REPO]
--
-- M. The focus model (focus.lua, after guiFormSpecMenu.cpp) on small forms:
--    the engine's order (first empty edit box, first edit box, first table
--    or textlist, last button, first other), a scroll container's contents not counted,
--    set_focus forced or on a new form only, before its element only, a
--    tabheader click re-running the order, a kept name.
-- I. The inventory pages, built by the REAL vendored sfinv, grug_inventory's
--    frame (tools/r44_ts/harness.lua) and the pages' own files: Talents &
--    Skills (talents_ui.lua with grug_skills), Party & PvP (grug_parties/
--    ui.lua and grug_pvp/page.lua, out of a party, in one, with a notice)
--    and Help (help.lua, every sub-page). Each focuses a harmless button
--    when opened and after a tab click; without its set_focus the engine
--    would focus an element that eats the key (the bug this lane fixes).
-- B. The written book's read view (the vendored default craftitems.lua).
-- S. Every set_focus[] of these windows names an element that is no field
--    or textarea of the same file.
-- The standalone windows' own fixtures check theirs with the same model:
-- tools/r25_interfaces (Claim Stone), tools/r33_c5 (Crownbinder),
-- tools/r34_f2 (withdraw dialog), tools/r35_c (character creation).
--
-- What no fixture can prove: the client's real key handling (which keys a
-- focused element consumes, the inventory key closing the window). The
-- model follows the engine source; the GUI checklist covers the rest.

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

local F = dofile(repo .. "/tools/r451_kf/focus.lua")

-- The element focused on `fs`, as "type:name" (or "none").
local function focused(fs, opts)
	local got = F.initial(fs, opts)
	return got and (got.type .. ":" .. got.name) or "none", got
end
-- A window that opens with `want` (a button) focused, also after a tab click
-- (`tab`: the tabheader's name) or on a re-send of the same form; without its
-- set_focus[] the engine would focus a key-eating element.
local function harmless(fs, want, label, opts)
	opts = opts or {}
	local name, got = focused(fs, {new_form = opts.new_form})
	eq(name, want, label .. ": focused when opened")
	check(got and got.kind == "button" and not got.eats, label .. ": a button, which " ..
		"passes the inventory key on")
	if opts.tab then
		eq(focused(fs, {preserved = opts.tab}), want, label .. ": focused after a tab click")
	end
	local _, bare = focused(F.without_set_focus(fs), {new_form = opts.new_form})
	check(bare and bare.eats, label .. ": without set_focus the engine focuses an element " ..
		"that eats the key (" .. (bare and bare.type .. " by " .. bare.how or "none") .. ")")
end

--
-- M. The model
--

local RO = "textarea[0,0;2,1;;;Some text]"
eq(focused(RO .. "button[0,2;1,1;ok;OK]"), "textarea:", "M a read-only textarea before a button")
check(select(2, focused(RO)).eats, "M a read-only textarea eats letters")
eq(focused("field[0,0;2,1;a;A;x]field[0,1;2,1;b;B;]"), "field:b", "M the first EMPTY edit box first")
eq(focused("field[0,0;2,1;a;A;x]table[0,1;2,1;t;r1;1]"), "field:a", "M then the first edit box")
eq(focused("button[0,0;1,1;b;B]table[0,1;2,1;t;r1;1]"), "table:t", "M a table before buttons")
check(select(2, focused("table[0,1;2,1;t;r1;1]")).eats, "M a table eats letters")
eq(focused("button[0,0;1,1;a;A]button[0,1;1,1;b;B]checkbox[0,2;c;C;false]"), "button:b",
	"M the last button")
eq(focused("label[0,0;x]checkbox[0,2;c;C;false]dropdown[0,3;2;d;a,b;1]"), "checkbox:c",
	"M the first element that is no static text")
eq(focused("button[0,0;1,1;b;B]textlist[0,3;2,2;l;a,b;1]"), "textlist:l",
	"M a textlist is a table")
check(select(2, focused("textlist[0,3;2,2;l;a,b;1]")).eats, "M a textlist eats letters")
eq(focused("field[0,0;2,1;;Static;x]button[0,1;1,1;b;B]"), "button:b",
	"M an unnamed field is static text")
eq(focused("scroll_container[0,0;3,3;s;vertical]" .. RO .. "scroll_container_end[]" ..
	"button[0,4;1,1;b;B]"), "button:b", "M a scroll container's contents are no children")
eq(focused("tabheader[0,0;tabs;A,B;1]" .. RO .. "button[0,2;1,1;b;B]", {preserved = "tabs"}),
	"textarea:", "M a tab click re-runs the order")
eq(focused(RO .. "button[0,2;1,1;b;B]", {preserved = "b"}), "button:b", "M a kept name")
local unforced = "set_focus[b;false]" .. RO .. "button[0,2;1,1;b;B]"
eq(focused(unforced), "textarea:", "M set_focus unforced: not on the same form (the inventory)")
eq(focused(unforced, {new_form = true}), "button:b", "M set_focus unforced: on a new form")
eq(focused("set_focus[b;true]" .. RO .. "button[0,2;1,1;b;B]"), "button:b", "M set_focus forced")
eq(focused(RO .. "button[0,2;1,1;b;B]set_focus[b;true]"), "textarea:",
	"M set_focus after its element does nothing")
eq(focused("set_focus[x;true]" .. RO), "textarea:", "M set_focus on a missing name")
eq(focused("set_focus[f;true]field[0,0;2,1;f;F;]button[0,2;1,1;b;B]"), "field:f",
	"M set_focus can name a field")

--
-- I. The inventory pages
--

local H = dofile(repo .. "/tools/r44_ts/harness.lua")(repo)
local TABS = "sfinv_nav_tabs"

-- Talents & Skills: a scout with ranks (respec button) and a fresh one.
for _, case in ipairs({{"ranked", "strong_draw=5,cold_eye=4"}, {"fresh", ""}}) do
	local player = H.make_player("t_" .. case[1], "scout", 30, case[2])
	H.join(player)
	local fs = H.render(player, "grug_classes:talents")
	check(fs:find("textarea[", 1, true) ~= nil, "I Talents " .. case[1] .. ": the text line is there")
	harmless(fs, "button:grug_talent_focus", "I Talents " .. case[1], {tab = TABS})
	check(fs:find("button[0,0;0,0;grug_talent_focus;]", 1, true) ~= nil,
		"I Talents " .. case[1] .. ": the focus button has no size and no label")
end
local sink_handled = sfinv.pages["grug_classes:talents"]:on_player_receive_fields(
	core.get_player_by_name("t_fresh"), sfinv.get_or_create_context(core.get_player_by_name("t_fresh")),
	{grug_talent_focus = ""})
check(not sink_handled, "I Talents: pressing the focus button (Space, Enter) does nothing")

-- Party & PvP and Help on the same stub world, with their neighbours stubbed.
local function load_mod(mod, path, file)
	local get_modpath, get_modname = core.get_modpath, core.get_current_modname
	core.get_modpath = function() return repo .. "/mods/" .. path end
	core.get_current_modname = function() return mod end
	dofile(repo .. "/mods/" .. path .. "/" .. file)
	core.get_modpath, core.get_current_modname = get_modpath, get_modname
end
local connected = {}
core.get_connected_players = function() return connected end
core.get_game_info = function() return {path = repo} end
Settings = function() return {get = function() return "0.45.0" end} end
grug_core.status_icons = {CLASSES = {"warrior", "mage", "priest", "scout"},
	class_icon = function(id) return "grug_class_" .. id .. ".png" end}
grug_factions.get_faction = function() return "accord" end
grug_factions.display_name = function(id) return id end
local party, pending = nil, {}
grug_parties = {
	view = function() return party end,
	pending = function() return pending end,
	invitations_enabled = function() return true end,
	hud_enabled = function() return true end,
	health_color_mode = function() return "by_class" end,
	register_on_change = function() end,
}
grug_pvp = {
	state = function() return {flagged = false} end,
	stats = function() return {} end,
	register_on_change = function() end,
}
grug_sounds = {play = function() end}
load_mod("grug_parties", "PLAYER/grug_parties", "ui.lua")
load_mod("grug_pvp", "PLAYER/grug_pvp", "page.lua")
load_mod("grug_inventory", "PLAYER/grug_inventory", "help.lua")

local ana, bo = H.make_player("ana", "scout", 30, ""), H.make_player("bo", "mage", 28, "")
H.join(ana)
H.join(bo)
connected = {ana, bo}
local PARTY = "grug_parties:group"
local fs = H.render(ana, PARTY)
check(fs:find("You are not in a party.", 1, true) ~= nil, "I Party out: the hint textarea")
harmless(fs, "button:grug_party_refresh", "I Party out of a party", {tab = TABS})
party = {leader = "ana", members = {
	{name = "ana", class = "scout", level = 30, online = true, hp = 20, hp_max = 20},
	{name = "bo", class = "mage", level = 28, online = true, hp = 18, hp_max = 20}}}
pending = {{inviter = "bo", level = 28, expires_in = 50}}
fs = H.render(ana, PARTY)
check(fs:find("table[", 1, true) ~= nil and fs:find("textarea[", 1, true) == nil,
	"I Party in a party: the member table, no textarea")
harmless(fs, "button:grug_party_refresh", "I Party in a party", {tab = TABS})
sfinv.get_or_create_context(ana).grug_party_notice = "Refused: no."
fs = H.render(ana, PARTY)
check(fs:find("Refused: no.", 1, true) ~= nil, "I Party with a notice: the notice textarea")
harmless(fs, "button:grug_party_refresh", "I Party with a notice", {tab = TABS})

local HELP = "grug_inventory:help"
local hctx = sfinv.get_or_create_context(ana)
for _, section in ipairs({"start", "quests", "basics", "formulas", "about", "sound"}) do
	hctx.grug_help_section = section
	fs = H.render(ana, HELP)
	local want = "button:grug_help_" .. section
	eq(focused(fs), want, "I Help " .. section .. ": focused when opened")
	eq(focused(fs, {preserved = TABS}), want, "I Help " .. section .. ": after a tab click")
	if section == "about" then
		harmless(fs, want, "I Help about")
	end
end

--
-- B. The written book's read view (vendored default/craftitems.lua)
--

do
	local items, shown = {}, nil
	local saved = {core.register_craftitem, core.register_craft, core.show_formspec,
		core.register_on_player_receive_fields, core.register_on_leaveplayer}
	core.register_craftitem = function(name, def) items[name] = def end
	core.register_craft = function() end
	core.show_formspec = function(_, formname, form) shown = {formname, form} end
	core.register_on_player_receive_fields = function() end
	core.register_on_leaveplayer = function() end
	core.register_on_mods_loaded = core.register_on_mods_loaded or function() end
	-- Anything else the file calls at load is a no-op here.
	local noop = function() return function() end end
	default = setmetatable({get_translator = function(text, ...)
		local args = {...}
		return (text:gsub("@(%d)", function(i) return tostring(args[tonumber(i)]) end))
	end}, {__index = function() return noop end})
	setmetatable(core, {__index = function() return noop end})
	local ok, err = pcall(dofile, repo .. "/mods/BASE/default/craftitems.lua")
	setmetatable(core, nil)
	check(ok, "B craftitems.lua loads on the stub (" .. tostring(err) .. ")")
	local def = items["default:book_written"]
	if check(def and def.on_use, "B the written book has on_use") then
		local meta = {owner = "someone", title = "Notes", text = "line one\nline two",
			page = "1", page_max = "1"}
		local stack = {get_meta = function()
			return {to_table = function() return {fields = meta} end}
		end}
		local reader = {get_player_name = function() return "reader" end,
			get_wield_index = function() return 1 end}
		def.on_use(stack, reader)
		eq(shown and shown[1], "default:book", "B the read view is shown")
		harmless(shown[2], "button:book_next", "B the book's read view (another's book)",
			{new_form = true})
		-- The owner's read tab: a tab click re-sends it with its tabheader.
		meta.owner = "reader"
		def.on_use(stack, reader)
		local write_fs = shown[2]
		local name = focused(write_fs, {new_form = true})
		eq(name, "field:title", "B the owner's write tab still focuses its title (a text editor)")
	end
	core.register_craftitem, core.register_craft, core.show_formspec,
		core.register_on_player_receive_fields, core.register_on_leaveplayer = unpack(saved)
end

--
-- S. Every set_focus[] of the windows names no field or textarea of its file
--

do
	local found = 0
	for _, path in ipairs({"mods/PLAYER/grug_parties/ui.lua",
			"mods/PLAYER/grug_classes/talents_ui.lua", "mods/PLAYER/grug_inventory/help.lua",
			"mods/ENTITIES/grug_traders/crown.lua", "mods/PLAYER/grug_classes/selection.lua",
			"mods/PLAYER/grug_housing/stone_form.lua", "mods/PLAYER/grug_money/coins.lua",
			"mods/BASE/default/craftitems.lua"}) do
		local text = assert(io.open(repo .. "/" .. path)):read("*a")
		for target in text:gmatch("set_focus%[([%w_]+)") do
			found = found + 1
			local field = text:find("field%[[^%]]-;" .. target .. ";") or
				text:find("textarea%[[^%]]-;" .. target .. ";")
			check(not field, "S " .. path .. ": set_focus[" .. target .. "] names no field")
		end
	end
	check(found >= 7, "S the windows' set_focus[] found (" .. found .. ")")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("R451 KF PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R451 KF PORTABLE PASS checks=" .. checks)
