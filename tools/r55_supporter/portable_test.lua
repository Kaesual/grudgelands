-- Round 55 lane SUPPORTER portable test (LuaJIT): manual achievements and
-- /achievement (character_visuals.md §5b).
--
--   luajit tools/r55_supporter/portable_test.lua [repo]
--
-- Loads the REAL grug_achievements core.lua, creatures.lua and init.lua on a
-- fake engine (tools/r33_c3's seams plus the chat command, mod storage and
-- player_exists), with a stub catalogue in place of catalog.lua: seven
-- automatic achievements (one page of the tab) and one manual achievement,
-- "supporter", whose cloak carries wings. Checks:
--   V  the catalogue validation of `manual`: its counter is manual:<id> (the
--      catalogue row untouched), and a manual row with a counter, a faction,
--      two tiers, a tier above 1, a value other than true, an id with other
--      characters or a cloak another tier unlocks too is a load error;
--   P  the command needs the `server` privilege;
--   H  hidden until granted: a character without it lists seven rows on one
--      page, granted eight on two; revoked one page again;
--   G  a grant to a player online: the tier, the cloak (with its wings
--      through the cloak source), one feed line, a log line; a second grant
--      changes nothing;
--   R  a revoke: tier, counter and cloak gone, a worn cloak back to No cloak
--      and redrawn, a feed line; a revoke of something not granted changes
--      nothing;
--   X  refusals: an automatic achievement (grant and revoke), an unknown id,
--      an unknown player, a malformed command;
--   Q  a player who is offline: the grant is queued, applied once at the
--      next join (and logged), the queue removed; a revoke likewise; a later
--      action on the same id replaces the earlier; a queued id the
--      catalogue no longer has as manual is dropped.

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg[1] or "."

local checks, failures = 0, 0
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

-- A PlayerMetaRef (and ModStorage) stand-in.
local function new_meta()
	local data = {}
	return {
		data = data,
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(data[key]) or 0 end,
		set_int = function(_, key, value) data[key] = tostring(value) end,
	}
end

local function new_player(name, meta)
	return {
		name = name, meta = meta,
		get_meta = function(self) return self.meta end,
		get_player_name = function(self) return self.name end,
		is_player = function() return true end,
	}
end

-- The stub catalogue: seven automatic rows fill one page of the tab.
local AUTO = {}
local stub = {
	defaults = {"none", "plain_grey"},
	cloaks = {
		{id = "none", name = "No cloak"},
		{id = "plain_grey", name = "Plain grey cloak", texture = "grey.png"},
		{id = "hunter_1", name = "Hunter's Green", texture = "hunter.png"},
		{id = "patron", name = "Patron's Mantle", texture = "patron.png",
			wings = "patron_wings.png"},
	},
	achievements = {
		{id = "hunter", name = "Hunter", counter = "kill:animal",
			text = "Kill %d wild animals.", tiers = {{at = 2, cloak = "hunter_1"}}},
	},
}
for index = 2, 7 do
	stub.achievements[index] = {id = "auto_" .. index, name = "Auto " .. index,
		counter = "death:fall", text_one = "Fall.", tiers = {{at = 1}}}
end
stub.achievements[8] = {id = "supporter", name = "Supporter", manual = true,
	text_one = "Played early and helped shape the land.",
	flavour = "You were here before the roads were.",
	tiers = {{at = 1, cloak = "patron"}}}
for _, ach in ipairs(stub.achievements) do AUTO[ach.id] = not ach.manual end

-- The fake engine and the seams grug_achievements reaches.
local joins, logs, feed, applied = {}, {}, {}, {}
local commands, storage = {}, new_meta()
local online, known = {}, {}
local real_dofile = dofile
local catalog = stub
dofile = function(path)
	if path:find("/catalog%.lua$") then return catalog end
	return real_dofile(path)
end
core = {
	get_modpath = function() return repo .. "/mods/PLAYER/grug_achievements" end,
	get_current_modname = function() return "grug_achievements" end,
	get_mod_storage = function() return storage end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_mods_loaded = function() end,
	register_on_dieplayer = function() end,
	register_chatcommand = function(name, def) commands[name] = def end,
	get_player_by_name = function(name) return online[name] end,
	player_exists = function(name) return known[name] == true end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	formspec_escape = function(text) return (text:gsub("[\\%[%];,]", "\\%0")) end,
	colorize = function(_, text) return text end,
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
}
grug_core = {feed = function(player, kind, text, key)
	feed[#feed + 1] = {name = player:get_player_name(), text = text, key = key}
end, get_player_faction = function() return "accord" end}
grug_inventory = {refresh_character = function() end, refresh_character_tab = function() end}
local cloak_source
grug_visuals = {
	register_cloak_source = function(fn) cloak_source = fn end,
	apply = function(player) applied[#applied + 1] = player:get_player_name() end,
}
sfinv = {set_player_inventory_formspec = function() end}

dofile(repo .. "/mods/PLAYER/grug_achievements/init.lua")
dofile = real_dofile
local A = grug_achievements
local R, book = A.rules, A.book
local cmd = commands.achievement
local AREA = {x = 0.4, y = 1.25, w = 7.5, h = 7.8}

local function join(player)
	online[player:get_player_name()] = player
	known[player:get_player_name()] = true
	for _, fn in ipairs(joins) do fn(player) end
end
local function leave(player) online[player:get_player_name()] = nil end
local function run(param) return cmd.func("admin", param) end
local function feed_count(name, needle)
	local count = 0
	for _, line in ipairs(feed) do
		if line.name == name and line.text:find(needle, 1, true) then count = count + 1 end
	end
	return count
end
local function log_count(needle)
	local count = 0
	for _, line in ipairs(logs) do
		if line:find(needle, 1, true) then count = count + 1 end
	end
	return count
end
local function tab(player)
	local context, text = {}, ""
	for _ = 1, 3 do
		text = text .. A.character_achievements_formspec(player, context, AREA)
		A.handle_tab_fields(player, context, {grug_ach_next = true})
	end
	return text, A.character_achievements_formspec(player, {}, AREA)
end

-- V: the catalogue validation.
local supporter = book.achievement.supporter
eq(supporter.counter, "manual:supporter", "V the manual counter")
eq(stub.achievements[8].counter, nil, "V the catalogue row is untouched")
check(book.by_counter["manual:supporter"][1] == supporter, "V indexed by its counter")
check(pcall(R.build, stub), "V the stub builds twice")
local function refused(edit, label)
	local row = {id = "gift", name = "Gift", manual = true, text_one = "Given.",
		tiers = {{at = 1, cloak = "patron"}}}
	local extra = edit(row)
	local cat = {defaults = {"none"}, cloaks = stub.cloaks,
		achievements = {row, extra}}
	local ok, err = pcall(R.build, cat)
	check(not ok, "V refused: " .. label)
	return err
end
check(pcall(R.build, {defaults = {"none"}, cloaks = stub.cloaks, achievements = {
	{id = "gift", name = "Gift", manual = true, text_one = "Given.", tiers = {{at = 1}}}}}),
	"V a manual row without a cloak builds")
refused(function(row) row.counter = "kill:animal" end, "a counter")
refused(function(row) row.faction = "accord" end, "a faction")
refused(function(row) row.tiers[2] = {at = 2} end, "two tiers")
refused(function(row) row.tiers[1].at = 3 end, "a tier above 1")
refused(function(row) row.manual = "yes" end, "manual not true")
refused(function(row) row.id = "Gift-1" end, "an id with other characters")
refused(function(row) row.text_one = nil end, "no condition text")
refused(function()
	return {id = "other", name = "Other", counter = "kill:zombie", text_one = "x",
		tiers = {{at = 1, cloak = "patron"}}}
end, "a cloak another tier unlocks too")

-- P: the privilege.
check(cmd ~= nil, "P /achievement registered")
check(cmd and cmd.privs and cmd.privs.server == true, "P needs the server privilege")

-- H + G: hidden until granted, a grant online.
local anna = new_player("anna", new_meta())
join(anna)
local all, first = tab(anna)
check(not all:find("Supporter", 1, true), "H not listed before the grant")
check(not first:find("grug_ach_next", 1, true), "H seven rows: one page")
eq(#R.shown_list(book, anna:get_meta(), "accord"), 7, "H seven rows shown")
check(next(anna:get_meta().data) == nil, "H a new character stores nothing")
local ok, msg = run("grant anna supporter")
check(ok, "G the grant succeeds")
eq(msg, "Supporter granted for anna.", "G the message")
eq(R.earned(anna:get_meta(), supporter), 1, "G the tier")
eq(R.count(anna:get_meta(), "manual:supporter"), 1, "G the counter")
check(R.has_cloak(book, anna:get_meta(), "patron"), "G the cloak unlocked")
eq(feed_count("anna", "Achievement: Supporter — Patron's Mantle unlocked"), 1, "G one feed line")
eq(log_count("admin grant supporter for anna"), 1, "G a log line")
all, first = tab(anna)
check(all:find("Supporter  Earned", 1, true) ~= nil, "H listed once granted")
check(first:find("grug_ach_next", 1, true) ~= nil, "H eight rows: two pages")
check(A.select_cloak(anna, "patron"), "G the cloak can be worn")
local texture, id, wings = cloak_source(anna)
check(texture == "patron.png" and id == "patron" and wings == "patron_wings.png",
	"G the cloak source gives the cloak and its wings")
ok, msg = run("grant anna supporter")
check(ok and msg == "anna already has Supporter.", "G a second grant: " .. tostring(msg))
eq(feed_count("anna", "Achievement: Supporter"), 1, "G no second feed line")
eq(R.earned(anna:get_meta(), supporter), 1, "G still one tier")
join(anna)
eq(feed_count("anna", "Achievement: Supporter"), 1, "G a rejoin earns nothing again")

-- R: revoke.
local drawn = #applied
ok, msg = run("revoke anna supporter")
check(ok and msg == "Supporter revoked for anna.", "R the revoke: " .. tostring(msg))
eq(R.earned(anna:get_meta(), supporter), 0, "R the tier is gone")
check(anna:get_meta().data["grug_achievements:n:manual:supporter"] == nil and
	anna:get_meta().data["grug_achievements:tier:supporter"] == nil, "R counter and tier cleared")
check(not R.has_cloak(book, anna:get_meta(), "patron"), "R the cloak is gone")
eq(A.selected_cloak(anna), "none", "R the worn cloak falls back to No cloak")
eq(anna:get_meta():get_string(R.KEY_SELECTED), "", "R the selection is cleared")
eq(cloak_source(anna), nil, "R the cloak source draws no cloak")
eq(#applied, drawn + 1, "R the player is redrawn")
eq(feed_count("anna", "Achievement removed: Supporter"), 1, "R a feed line")
eq(log_count("admin revoke supporter for anna"), 1, "R a log line")
all = tab(anna)
check(not all:find("Supporter", 1, true), "H hidden again after the revoke")
join(anna)
eq(R.earned(anna:get_meta(), supporter), 0, "R a rejoin does not re-earn it")
ok, msg = run("revoke anna supporter")
check(ok and msg == "anna does not have Supporter.", "R a revoke of nothing: " .. tostring(msg))
eq(#applied, drawn + 1, "R ... redraws nothing")
eq(feed_count("anna", "Achievement removed"), 1, "R ... and posts nothing")
-- A grant, a cloak not worn, a revoke: no redraw.
run("grant anna supporter")
check(A.select_cloak(anna, "plain_grey"), "R wearing the grey cloak")
drawn = #applied
run("revoke anna supporter")
eq(A.selected_cloak(anna), "plain_grey", "R another worn cloak stays")
eq(#applied, drawn, "R ... and nothing is redrawn")

-- X: refusals.
ok, msg = run("grant anna hunter")
check(not ok and msg == "Hunter is earned by playing, not granted.", "X automatic grant: " .. tostring(msg))
ok, msg = run("revoke anna hunter")
check(not ok and msg == "Hunter is earned by playing, not revoked.", "X automatic revoke: " .. tostring(msg))
eq(R.earned(anna:get_meta(), book.achievement.hunter), 0, "X Hunter untouched")
ok, msg = run("grant anna nothing")
check(not ok and msg:find("Unknown achievement", 1, true), "X an unknown id: " .. tostring(msg))
ok, msg = run("grant nobody supporter")
check(not ok and msg == "No player named nobody.", "X an unknown player: " .. tostring(msg))
eq(storage.data["queue:nobody"], nil, "X ... queues nothing")
for _, param in ipairs({"", "grant", "grant anna", "give anna supporter", "grant anna supporter x"}) do
	ok, msg = run(param)
	check(not ok and msg:find("^Usage"), "X usage for '" .. param .. "'")
end

-- Q: a player who is offline.
local bert = new_player("bert", new_meta())
join(bert)
leave(bert)
ok, msg = run("grant bert supporter")
check(ok and msg == "bert is offline: Supporter will be granted at their next join.",
	"Q queued: " .. tostring(msg))
eq(R.earned(bert:get_meta(), supporter), 0, "Q nothing applied yet")
eq(log_count("admin queued: grant supporter for bert (offline)"), 1, "Q a log line")
join(bert)
eq(R.earned(bert:get_meta(), supporter), 1, "Q applied at the join")
check(R.has_cloak(book, bert:get_meta(), "patron"), "Q the cloak too")
eq(feed_count("bert", "Achievement: Supporter"), 1, "Q announced")
eq(storage.data["queue:bert"], nil, "Q the queue is removed")
eq(log_count("queued grant of supporter applied for bert"), 1, "Q the join logs it")
leave(bert)
join(bert)
eq(feed_count("bert", "Achievement: Supporter"), 1, "Q applied once")
A.select_cloak(bert, "patron")
leave(bert)
run("revoke bert supporter")
eq(R.earned(bert:get_meta(), supporter), 1, "Q the revoke waits")
join(bert)
eq(R.earned(bert:get_meta(), supporter), 0, "Q the revoke at the join")
eq(A.selected_cloak(bert), "none", "Q the worn cloak falls back at the join")
eq(storage.data["queue:bert"], nil, "Q the queue is removed again")
leave(bert)
run("grant bert supporter")
run("revoke bert supporter")
eq(storage.data["queue:bert"], "supporter=revoke", "Q the later action replaces the earlier")
join(bert)
eq(R.earned(bert:get_meta(), supporter), 0, "Q grant then revoke: not granted")
eq(feed_count("bert", "Achievement removed"), 1, "Q ... and nothing to remove")
leave(bert)
storage:set_string("queue:bert", "retired=grant,hunter=grant,supporter=grant")
join(bert)
eq(R.earned(bert:get_meta(), supporter), 1, "Q the known manual id applies")
eq(R.earned(bert:get_meta(), book.achievement.hunter), 0, "Q a queued automatic id is dropped")
eq(storage.data["queue:bert"], nil, "Q the whole queue is removed")

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R55 SUPPORTER PORTABLE FAIL") end
print("R55 SUPPORTER PORTABLE PASS checks=" .. checks)
