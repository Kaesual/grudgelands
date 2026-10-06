-- Round 38 lane WC portable test (LuaJIT): the welcome window.
--
--   luajit tools/r38_wc/portable_test.lua [REPO]
--
-- Loads the REAL grug_inventory help.lua and welcome.lua on stubs and reads
-- grug_classes/selection.lua as text. Checks:
--   W  welcome.lua registers one arrival callback; it shows
--      grug_inventory:welcome with the player's line ("Thorvin, Dwarf
--      Warrior of The Accord"), the five points, the five link buttons with
--      Help -> About's addresses plus the credits, and "Got it" as an exit
--      button; its fields are swallowed, other forms' are not;
--   M  the hypertext holds no "<" outside its own tags and no "\";
--   A  selection.lua runs the arrival callbacks only in finish_if_ready,
--      after the teleport cleared the arriving mark and released the player.
-- Prints "R38 WC PORTABLE PASS checks=<n>" or the failures.
local repo = arg and arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end

local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

local function escape(s)
	return (tostring(s):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"))
end
local function unescape(s)
	return (s:gsub("\\(.)", "%1"))
end

-- W. The window on stubs ----------------------------------------------------------
local arrival, receive, shown = {}, {}, {}
_G.core = {
	formspec_escape = escape,
	get_game_info = function() return {path = "GAMEPATH"} end,
	log = function() end,
	show_formspec = function(name, formname, form)
		shown[#shown + 1] = {name = name, formname = formname, form = form}
	end,
	register_on_player_receive_fields = function(func) receive[#receive + 1] = func end,
}
_G.Settings = function() return {get = function() return "0.38.0" end} end
_G.sfinv = {register_page = function() end}
_G.grug_inventory = {selected_button_style = function() return "" end}
_G.grug_classes = {
	register_on_arrival = function(func) arrival[#arrival + 1] = func end,
	get_race_def = function() return {name = "Dwarf"} end,
	get_class_def = function() return {name = "Warrior"} end,
}
_G.grug_factions = {
	get_faction = function() return "accord" end,
	display_name = function(id) return id == "accord" and "The Accord" or nil end,
}
local MOD = repo .. "/mods/PLAYER/grug_inventory"
dofile(MOD .. "/help.lua")
dofile(MOD .. "/welcome.lua")

check(#arrival == 1, "W one arrival callback")
check(#receive == 1, "W one fields handler")
local player = {get_player_name = function() return "Thorvin" end}
arrival[1](player)
local form = shown[1] and shown[1].form or ""
check(#shown == 1 and shown[1].name == "Thorvin" and
	shown[1].formname == "grug_inventory:welcome", "W the arrival shows the window")
local plain = unescape(form)
check(plain:find("Thorvin, Dwarf Warrior of The Accord", 1, true) ~= nil,
	"W the player's line")
for _, word in ipairs({"Welcome to Grudgelands", "Explore.", "Level up.", "Do quests.",
		"Use your skills.", "Team up.", "Party tab", "Help tab", "open source",
		"buy me a coffee"}) do
	check(plain:find(word, 1, true) ~= nil, "W the text names " .. word)
end
local urls = {}
for _, link in ipairs(grug_inventory.LINKS) do urls[link.id] = link.url end
local expected = {
	{"discord", "Discord", urls.discord}, {"issues", "Report a bug", urls.issues},
	{"source", "Source code", urls.source},
	{"credits", "Credits", "https://github.com/Kaesual/grudgelands/blob/main/CREDITS.md"},
	{"coffee", "Buy me a coffee", urls.coffee},
}
local buttons = 0
for _ in form:gmatch("button_url%[") do buttons = buttons + 1 end
check(buttons == 5, "W five link buttons")
for _, row in ipairs(expected) do
	check(row[3] ~= nil and form:find(("grug_welcome_%s;%s;%s]"):format(row[1],
		escape(row[2]), escape(row[3])), 1, true) ~= nil, "W the " .. row[1] .. " button")
end
check(form:find("button_exit%[[^%]]*;grug_welcome_ok;Got it%]") ~= nil, "W Got it closes")
check(receive[1](player, "grug_inventory:welcome", {quit = "true"}) == true,
	"W its fields are swallowed")
check(receive[1](player, "grug_classes:create", {}) == nil, "W other forms pass")

-- A broken identity leaves its parts out instead of failing.
grug_classes.get_race_def = function() return nil end
grug_factions.get_faction = function() return nil end
arrival[1](player)
check(shown[2] and unescape(shown[2].form):find(">Thorvin, Warrior</style>", 1, true) ~= nil,
	"W a missing race and faction are left out")

-- M. Hypertext markup ---------------------------------------------------------------
local TAGS = {style = true, b = true, big = true}
for body in form:gmatch("hypertext%[[^;]*;[^;]*;;(.-[^\\])%]") do
	local text = unescape(body)
	check(not text:find("\\", 1, true), "M no backslash in a hypertext")
	for tag in text:gmatch("<(/?[%w]*)") do
		check(TAGS[tag:gsub("^/", "")] == true, "M only known tags (" .. tag .. ")")
	end
end

-- A. Where selection.lua runs the callbacks -----------------------------------------
local selection = read(repo .. "/mods/PLAYER/grug_classes/selection.lua")
local _, calls = selection:gsub("in ipairs%(arrival_callbacks%)", "")
check(calls == 1, "A one place runs the arrival callbacks")
local finish = selection:match("\nfinish_if_ready = function%(player%)(.-)\nend\n")
check(finish ~= nil, "A finish_if_ready found")
if finish then
	local clear = finish:find("set_string(META_ARRIVING, \"\")", 1, true)
	local release = finish:find("if not release_player(player, session) then", 1, true)
	local run = finish:find("in ipairs(arrival_callbacks)", 1, true)
	check(clear and release and run and clear < release and release < run,
		"A the callbacks run after the mark is cleared and the player released")
end

if #failures == 0 then
	print("R38 WC PORTABLE PASS checks=" .. checks)
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R38 WC PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
