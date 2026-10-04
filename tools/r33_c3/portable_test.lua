-- Round 33 Lane C3 portable test (LuaJIT): achievements and cloaks
-- (round33-plan.md §2.10, character_visuals.md §5b).
--
--   luajit tools/r33_c3/portable_test.lua [repo]
--
-- Loads the REAL grug_achievements core.lua, creatures.lua, catalog.lua and
-- init.lua on a fake engine (the hooks of grug_mobs and grug_pvp captured).
-- Checks:
--   D  a new character owns exactly "No cloak" and "Plain grey cloak" and
--      wears No cloak (the cloak source answers nil);
--   K  kill counters per character: two characters of one account (two
--      player names, two metas) never see each other's counters; a sub-type
--      counts as its base mob, zombies count apart, humanoids, guards and
--      bosses not at all; the counters of an entity name are cached;
--   U  unlock on threshold: 99 animals unlock nothing, the 100th earns Hunter
--      once, unlocks its cloak and posts one feed line;
--   B  boss ledger kills: a King earns Kingslayer, the Stormscale Jungle
--      Wyvern Wyvernslayer, the Wyrmglass Ice Dragon Dragonslayer;
--   P  grug_pvp's guard counter: the 50th enemy guard earns Honored;
--   T  tiers (a test catalogue): each tier earned once, a jump earns every
--      tier passed, a tier is never taken back, titles count up;
--   S  the selection survives a rejoin (same meta, fresh player object, the
--      join pass) and reaches the cloak source; an unowned or unknown stored
--      cloak, or one the catalogue dropped, reads as No cloak; select refuses
--      what the character does not own;
--   F  the dropdown lists owned cloaks with the selected one marked; the
--      page's resubmission of the same name changes nothing, a new name
--      selects and redraws;
--   C  every mob grug_mobs registers in the source (and every sub-type base)
--      is classified, and the three lists are disjoint.
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

-- A PlayerMetaRef stand-in: strings in, ints as numbers.
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

-- The fake engine and the seams grug_achievements reaches.
local joins, mods_loaded, logs = {}, {}, {}
local feed, refreshed, tab_refreshed, applied = {}, 0, 0, {}
local eligible_kill, boss_kill, pvp_stat
local pvp_stats = {} -- player name -> {guards = n}
local subtypes = {
	["grug_mobs:young_boar"] = {base = "grug_mobs:boar", family = "boar"},
	["grug_mobs:marching_husk"] = {base = "grug_mobs:zombie", family = "zombie"},
	["grug_mobs:confused_bandit"] = {base = "grug_mobs:bandit", family = "outlaw"},
}

core = {
	get_modpath = function() return repo .. "/mods/PLAYER/grug_achievements" end,
	get_current_modname = function() return "grug_achievements" end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	formspec_escape = function(text)
		return (text:gsub("[\\%[%];,]", "\\%0"))
	end,
	colorize = function(_, text) return text end,
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
}
grug_core = {feed = function(player, kind, text, key)
	feed[#feed + 1] = {name = player:get_player_name(), text = text, key = key}
end}
grug_inventory = {
	refresh_character = function() refreshed = refreshed + 1 end,
	refresh_character_tab = function(_, tab)
		if tab == "achievements" then tab_refreshed = tab_refreshed + 1 end
	end,
}
local cloak_source
grug_visuals = {
	register_cloak_source = function(fn) cloak_source = fn end,
	apply = function(player) applied[#applied + 1] = player:get_player_name() end,
}
sfinv = {set_player_inventory_formspec = function() end}
grug_mobs = {
	register_on_eligible_kill = function(fn) eligible_kill = fn end,
	register_on_boss_kill = function(fn) boss_kill = fn end,
	subtype = function(name) return subtypes[name] end,
	registered_cadence = {["grug_mobs:boar"] = true, ["grug_mobs:zombie"] = true,
		["grug_mobs:bandit"] = true, ["grug_mobs:young_boar"] = true},
}
grug_pvp = {
	register_on_stat = function(fn) pvp_stat = fn end,
	stats = function(player)
		local row = pvp_stats[player:get_player_name()] or {}
		return {guards = row.guards or 0, kills = 0}
	end,
}

dofile(repo .. "/mods/PLAYER/grug_achievements/init.lua")
local A = grug_achievements
local R, C, book = A.rules, A.creatures, A.book
for _, fn in ipairs(mods_loaded) do fn() end

local function join(player)
	for _, fn in ipairs(joins) do fn(player) end
end
local function kill(player, name, times)
	for _ = 1, times or 1 do eligible_kill(player, {name = name}) end
end

check(eligible_kill and boss_kill and pvp_stat and cloak_source, "all hooks installed")

-- D: defaults.
local meta_a, meta_b = new_meta(), new_meta()
local anna, bert = new_player("anna", meta_a), new_player("bert", meta_b)
join(anna)
join(bert)
local owned = A.unlocked_cloaks(anna)
eq(#owned, 2, "D new character owns two cloaks")
eq(owned[1], "none", "D first is No cloak")
eq(owned[2], "grey", "D second is the plain grey cloak")
eq(A.selected_cloak(anna), "none", "D wears No cloak")
eq(cloak_source(anna), nil, "D cloak source: no texture")
check(next(meta_a.data) == nil, "D a new character stores nothing")

-- K + U: counters per character, unlock on threshold.
kill(anna, "grug_mobs:boar", 60)
kill(anna, "grug_mobs:young_boar", 39)    -- a sub-type counts as its base
kill(anna, "grug_mobs:zombie", 5)
kill(anna, "grug_mobs:marching_husk", 2)
kill(anna, "grug_mobs:bandit", 7)         -- humanoid
kill(anna, "grug_mobs:confused_bandit", 3)
kill(anna, "grug_mobs:guard_throng", 4)   -- faction NPC
kill(anna, "grug_mobs:ice_dragon", 1)     -- a boss is no animal
kill(anna, "grug_mobs:storm_whelp", 1)    -- nor a boss add
kill(bert, "grug_mobs:boar", 3)
eq(R.count(meta_a, "kill:animal"), 99, "K anna's wild animals")
eq(R.count(meta_a, "kill:zombie"), 7, "K anna's zombies")
eq(R.count(meta_b, "kill:animal"), 3, "K bert's wild animals, no leak")
eq(R.count(meta_b, "kill:zombie"), 0, "K bert's zombies, no leak")
check(A.kill_counters("grug_mobs:boar") == A.kill_counters("grug_mobs:boar"),
	"K the counters of an entity name are cached")
eq(#A.kill_counters("grug_mobs:bandit"), 0, "K a bandit feeds no counter")
eq(A.kill_counters("grug_mobs:kraken")[1], "kill:animal", "K the Kraken Guard is a wild animal")
eq(#feed, 0, "U 99 animals earn nothing")
check(not R.has_cloak(book, meta_a, "hunter"), "U no Hunter cloak at 99")
kill(anna, "grug_mobs:rabbit")
eq(R.count(meta_a, "kill:animal"), 100, "U the 100th animal")
check(R.has_cloak(book, meta_a, "hunter"), "U Hunter's cloak unlocked at 100")
eq(R.earned(meta_a, book.achievement.hunter), 1, "U Hunter earned")
eq(#feed, 1, "U one feed line")
check(feed[1] and feed[1].text:find("Hunter") ~= nil and feed[1].name == "anna",
	"U the line names Hunter, for anna")
check(refreshed >= 1, "U the Character page is refreshed")
kill(anna, "grug_mobs:rabbit", 5)
eq(#feed, 1, "U Hunter is earned once")
check(not R.has_cloak(book, meta_b, "hunter"), "U bert has no Hunter cloak")
check(tab_refreshed > 0, "K progress re-sends the Achievements tab")

-- B: boss ledger kills.
boss_kill(anna, "king:human")
eq(R.count(meta_a, "boss:king"), 1, "B a King kill")
eq(R.count(meta_a, "boss:king:human"), 1, "B per boss id")
check(R.has_cloak(book, meta_a, "kingslayer"), "B Kingslayer's cloak")
boss_kill(anna, "dragon:stormscale")
check(R.has_cloak(book, meta_a, "wyvernslayer"), "B Wyvernslayer's cloak")
check(not R.has_cloak(book, meta_a, "dragonslayer"), "B the Wyvern is not the Ice Dragon")
boss_kill(bert, "dragon:wyrmglass")
check(R.has_cloak(book, meta_b, "dragonslayer"), "B Dragonslayer's cloak for bert")
eq(R.count(meta_b, "boss:dragon"), 1, "B bert's dragon kills")
check(not R.has_cloak(book, meta_b, "kingslayer"), "B bert killed no King")

-- P: grug_pvp's guard counter.
pvp_stats.bert = {guards = 49}
pvp_stat(bert, "guards", 49)
check(not R.has_cloak(book, meta_b, "honored"), "P 49 guards earn nothing")
pvp_stats.bert.guards = 50
pvp_stat(bert, "guards", 50)
check(R.has_cloak(book, meta_b, "honored"), "P the 50th guard earns Honored")
pvp_stat(bert, "kills", 3)
check(not R.has_cloak(book, meta_a, "honored"), "P anna is not honored")

-- T: tiers, on a test catalogue.
local test_book = R.build({
	defaults = {"none"},
	cloaks = {{id = "none", name = "No cloak"},
		{id = "c1", name = "One", texture = "one.png"},
		{id = "c3", name = "Three", texture = "three.png"}},
	achievements = {{id = "slayer", name = "Slayer", counter = "kill:zombie",
		text = "Kill %d zombies.",
		tiers = {{at = 3, cloak = "c1"}, {at = 5}, {at = 10, cloak = "c3"}}}},
})
local slayer = test_book.achievement.slayer
local tm = new_meta()
eq(#R.settle(test_book, tm, slayer, 2), 0, "T below the first tier")
local rows = R.settle(test_book, tm, slayer, 6)
eq(#rows, 2, "T a jump to 6 earns tiers 1 and 2")
eq(rows[1].tier, 1, "T first row tier 1")
eq(rows[2].tier, 2, "T second row tier 2")
eq(R.earned(tm, slayer), 2, "T two tiers stored")
check(R.has_cloak(test_book, tm, "c1") and not R.has_cloak(test_book, tm, "c3"),
	"T only the first tier's cloak")
eq(#R.settle(test_book, tm, slayer, 6), 0, "T nothing twice")
eq(#R.settle(test_book, tm, slayer, 1), 0, "T a lower value takes nothing back")
eq(R.earned(tm, slayer), 2, "T still two tiers")
rows = R.settle(test_book, tm, slayer, 10)
eq(#rows, 1, "T the third tier")
check(R.has_cloak(test_book, tm, "c3"), "T the third tier's cloak")
eq(R.title(slayer, 1), "Slayer", "T title tier 1")
eq(R.title(slayer, 3), "Slayer III", "T title tier 3")
eq(R.title(book.achievement.hunter, 1), "Hunter", "T a one-tier title")
check(not pcall(R.build, {defaults = {"none"}, cloaks = {{id = "none", name = "No cloak"}},
	achievements = {{id = "x", name = "X", counter = "c", tiers = {{at = 5}, {at = 3}}}}}),
	"T falling tiers are a load error")

-- S: selection, rejoin, fallbacks.
check(A.select_cloak(anna, "kingslayer"), "S anna selects the Kingslayer's cloak")
eq(applied[#applied], "anna", "S the selection redraws anna")
check(not A.select_cloak(anna, "dragonslayer"), "S anna does not own the Dragonslayer's cloak")
check(not A.select_cloak(anna, "nonsense"), "S an unknown cloak is refused")
eq(A.selected_cloak(anna), "kingslayer", "S still the Kingslayer's cloak")
local anna_again = new_player("anna", meta_a) -- leave and rejoin: same meta
local feed_before = #feed
join(anna_again)
eq(A.selected_cloak(anna_again), "kingslayer", "S the selection survives a rejoin")
eq(cloak_source(anna_again), "grug_achievements_cloak_kingslayer.png",
	"S the cloak source after the rejoin")
eq(#feed, feed_before, "S the rejoin earns nothing again")
check(A.select_cloak(anna_again, "none"), "S back to No cloak")
eq(meta_a:get_string(R.KEY_SELECTED), "", "S No cloak stores nothing")
meta_b:set_string(R.KEY_SELECTED, "hunter") -- bert does not own it
eq(A.selected_cloak(bert), "none", "S an unowned stored cloak reads as No cloak")
meta_b:set_string(R.KEY_SELECTED, "gone")
eq(A.selected_cloak(bert), "none", "S an unknown stored cloak reads as No cloak")
eq(cloak_source(bert), nil, "S ... and draws no cloak")
meta_b:set_string(R.KEY_CLOAKS, meta_b:get_string(R.KEY_CLOAKS) .. ",retired")
meta_b:set_string(R.KEY_SELECTED, "retired")
eq(A.selected_cloak(bert), "none", "S a cloak the catalogue dropped reads as No cloak")
check(A.select_cloak(bert, "grey"), "S a default cloak can be selected")
eq(cloak_source(bert), "grug_achievements_cloak_grey.png", "S grey cloak texture")

-- F: the dropdown and the page's resubmissions.
local fs = A.cloak_dropdown(anna_again, 0, 6.3, 2.6)
check(fs:find("dropdown%[0.00,6.30;2.60;grug_cloak;No cloak,Plain grey cloak,Hunter's cloak," ..
	"Kingslayer's cloak,Wyvernslayer's cloak;1%]") ~= nil, "F dropdown items and index: " .. fs)
local before = #applied
check(not A.choose_cloak_by_name(anna_again, "No cloak"), "F the same name changes nothing")
eq(#applied, before, "F ... and draws nothing")
check(A.choose_cloak_by_name(anna_again, "Hunter's cloak"), "F a new name selects")
eq(A.selected_cloak(anna_again), "hunter", "F Hunter's cloak selected")
check(not A.choose_cloak_by_name(anna_again, "Cloak of the Honored"), "F an unowned name is ignored")
local context = {}
local tab = A.character_achievements_formspec(anna_again, context)
check(tab:find("Hunter  Earned", 1, true) ~= nil, "F the tab shows Hunter earned")
check(tab:find("Honored  0/50", 1, true) ~= nil, "F the tab shows Honored's progress")
check(tab:find("Kill 50 guards of the enemy faction.", 1, true) ~= nil, "F condition text")

-- C: every mob in the grug_mobs source is classified.
local names, seen = {}, {}
local function add_name(name)
	if not seen[name] then seen[name] = true; names[#names + 1] = name end
end
-- The files grug_mobs loads: init.lua itself and every file it dofile's.
local function read(path)
	local handle = assert(io.open(path))
	local text = handle:read("*a")
	handle:close()
	return text
end
local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs/"
local init_text = read(mobs_dir .. "init.lua")
local sources = {init_text}
for file in init_text:gmatch('dofile%(modpath %.%. "/([%w_]+%.lua)"%)') do
	sources[#sources + 1] = read(mobs_dir .. file)
end
for _, text in ipairs(sources) do
	for role in text:gmatch('register_mob%("grug_mobs:([%w_]+)"') do
		add_name("grug_mobs:" .. role .. (role:sub(-1) == "_" and "x" or ""))
	end
end
for base in read(mobs_dir .. "data/subtypes.json"):gmatch('"base"%s*:%s*"([^"]+)"') do
	add_name(base)
end
check(#names > 60, "C found the mob registrations (" .. #names .. ")")
local missing = C.unclassified(names, nil)
eq(#missing, 0, "C unclassified mobs: " .. table.concat(missing, ", "))
for name in pairs(C.ANIMALS) do
	check(not C.ZOMBIES[name] and not C.OTHERS[name], "C " .. name .. " in one list")
end
for name in pairs(C.ZOMBIES) do
	check(not C.OTHERS[name], "C " .. name .. " in one list")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R33 C3 PORTABLE FAIL") end
print("R33 C3 PORTABLE PASS checks=" .. checks)
