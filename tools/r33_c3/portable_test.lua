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
--      counts as its base mob, zombies count apart, humanoids, guards,
--      dragons and whelps not at all, the Kraken does; families (boar incl.
--      its regional bases, rat, skeleton incl. witches, golem, construct),
--      named leaders by role and Captain Bonerattle by rare id; the counters
--      of an entity name are cached;
--   U  unlock on threshold: 49 animals unlock nothing, the 50th earns Hunter
--      once, unlocks hunter_1 and posts one feed line; 150 earns Hunter II;
--   B  boss ledger kills: a King earns Kingslayer, the Stormscale Jungle
--      Wyvern Wyvernslayer, the Wyrmglass Ice Dragon Dragonslayer; five
--      King kills earn Kingslayer II;
--   P  grug_pvp's guard counter: the 50th enemy guard earns Honored;
--   J  counted crafts: cooking and alchemist output counts (by stack count)
--      reach Supper's Ready and Bottle Service; other professions count nothing;
--   X  a fall death earns Grounded, another death does not;
--   T  tiers (a test catalogue): each tier earned once, a jump earns every
--      tier passed, a tier is never taken back, titles count up;
--   S  the selection survives a rejoin (same meta, fresh player object, the
--      join pass) and reaches the cloak source; an unowned or unknown stored
--      cloak, or one the catalogue dropped, reads as No cloak; select refuses
--      what the character does not own;
--   F  the dropdown lists owned cloaks with the selected one marked; the
--      page's resubmission of the same name changes nothing, a new name
--      selects and redraws; the tab pages its 17 achievements;
--   C  every mob grug_mobs registers in the source (and every sub-type base)
--      is classified, the lists are disjoint, every family, role and rare id
--      exists in the source, every catalogue counter is one a hook produces,
--      every cloak has its texture file and the 41 Astra ids are exactly the
--      catalogue's textured cloaks.
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
local eligible_kill, boss_kill, pvp_stat, award, die
local pvp_stats = {} -- player name -> {guards = n}
local subtypes = {
	["grug_mobs:young_boar"] = {base = "grug_mobs:boar", family = "boar"},
	["grug_mobs:marching_husk"] = {base = "grug_mobs:zombie", family = "zombie"},
	["grug_mobs:confused_bandit"] = {base = "grug_mobs:bandit", family = "outlaw"},
	["grug_mobs:tollmaster_penn"] = {base = "grug_mobs:bandit", family = "outlaw"},
	["grug_mobs:salt_hex_witch"] = {base = "grug_mobs:bog_witch", family = "skeleton"},
	["grug_mobs:seam_mesa_golem"] = {base = "grug_mobs:mesa_golem", family = "golem"},
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
	register_on_dieplayer = function(fn) die = fn end,
}
ItemStack = function(text)
	local count = tonumber(tostring(text):match("%s(%d+)$")) or 1
	return {get_count = function() return count end}
end
grug_jobs = {register_on_award_progress = function(fn) award = fn end}
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

check(eligible_kill and boss_kill and pvp_stat and award and die and cloak_source,
	"all hooks installed")

local function feed_count(name, needle)
	local count = 0
	for _, line in ipairs(feed) do
		if line.name == name and line.text:find(needle, 1, true) then count = count + 1 end
	end
	return count
end

-- D: defaults.
local meta_a, meta_b = new_meta(), new_meta()
local anna, bert = new_player("anna", meta_a), new_player("bert", meta_b)
join(anna)
join(bert)
local owned = A.unlocked_cloaks(anna)
eq(#owned, 2, "D new character owns two cloaks")
eq(owned[1], "none", "D first is No cloak")
eq(owned[2], "plain_grey", "D second is the plain grey cloak")
eq(A.selected_cloak(anna), "none", "D wears No cloak")
eq(cloak_source(anna), nil, "D cloak source: no texture")
check(next(meta_a.data) == nil, "D a new character stores nothing")

-- K + U: counters per character, unlock on threshold.
kill(anna, "grug_mobs:boar", 20)
kill(anna, "grug_mobs:young_boar", 19)    -- a sub-type counts as its base
kill(anna, "grug_mobs:plague_boar", 5)    -- a regional boar is a boar
kill(anna, "grug_mobs:giant_rat", 5)
kill(anna, "grug_mobs:zombie", 5)
kill(anna, "grug_mobs:marching_husk", 2)
kill(anna, "grug_mobs:bandit", 7)         -- humanoid
kill(anna, "grug_mobs:confused_bandit", 3)
kill(anna, "grug_mobs:guard_throng", 4)   -- faction NPC
kill(anna, "grug_mobs:ice_dragon", 1)     -- a boss is no animal
kill(anna, "grug_mobs:storm_whelp", 1)    -- nor a boss add
kill(bert, "grug_mobs:boar", 3)
eq(R.count(meta_a, "kill:animal"), 49, "K anna's wild animals")
eq(R.count(meta_a, "kill:family:boar"), 44, "K anna's boars")
eq(R.count(meta_a, "kill:family:rat"), 5, "K anna's rats")
eq(R.count(meta_a, "kill:zombie"), 7, "K anna's zombies")
eq(R.count(meta_b, "kill:animal"), 3, "K bert's wild animals, no leak")
eq(R.count(meta_b, "kill:zombie"), 0, "K bert's zombies, no leak")
check(A.kill_counters("grug_mobs:boar") == A.kill_counters("grug_mobs:boar"),
	"K the counters of an entity name are cached")
eq(#A.kill_counters("grug_mobs:bandit"), 0, "K a bandit feeds no counter")
eq(#A.kill_counters(nil), 0, "K a nameless entity feeds no counter")
eligible_kill(anna, {})
eq(A.kill_counters("grug_mobs:kraken")[1], "kill:animal", "K the Kraken Guard is a wild animal")
eq(A.kill_counters("grug_mobs:salt_hex_witch")[1], "kill:family:skeleton", "K a witch is a skeleton")
eq(A.kill_counters("grug_mobs:seam_mesa_golem")[1], "kill:family:golem", "K a golem sub-type")
eq(A.kill_counters("grug_mobs:war_construct")[1], "kill:family:construct", "K a construct")
eq(A.kill_counters("grug_mobs:tollmaster_penn")[1], "kill:group:final_notice",
	"K a named leader by role")
check(R.has_cloak(book, meta_a, "boaring_work_1") and not R.has_cloak(book, meta_a, "boaring_work_2"),
	"K 44 boars: Boaring Work I only")
eq(feed_count("anna", "Hunter"), 0, "U 49 animals earn nothing")
check(not R.has_cloak(book, meta_a, "hunter_1"), "U no Hunter cloak at 49")
kill(anna, "grug_mobs:rabbit")
eq(R.count(meta_a, "kill:animal"), 50, "U the 50th animal")
check(R.has_cloak(book, meta_a, "hunter_1"), "U Hunter's Green unlocked at 50")
eq(R.earned(meta_a, book.achievement.hunter), 1, "U Hunter earned")
eq(feed_count("anna", "Achievement: Hunter"), 1, "U one feed line")
check(refreshed >= 1, "U the Character page is refreshed")
kill(anna, "grug_mobs:rabbit", 5)
eq(feed_count("anna", "Achievement: Hunter"), 1, "U Hunter is earned once")
kill(anna, "grug_mobs:hare", 95)
check(R.has_cloak(book, meta_a, "hunter_2") and not R.has_cloak(book, meta_a, "hunter_3"),
	"U 150 animals: Hunter II")
check(feed_count("anna", "Achievement: Hunter II") == 1, "U Hunter II's line")
check(not R.has_cloak(book, meta_b, "hunter_1"), "U bert has no Hunter cloak")
check(tab_refreshed > 0, "K progress re-sends the Achievements tab")
eligible_kill(anna, {name = "grug_mobs:skeleton_raider", _grug_rare_id = "bonerattle_north"})
check(R.has_cloak(book, meta_a, "no_more_orders_1"), "K Captain Bonerattle by rare id")
eq(R.count(meta_a, "kill:family:skeleton"), 1, "K ... who is also a skeleton")
eligible_kill(anna, {name = "grug_mobs:skeleton_raider", _grug_rare_id = "grimtusk"})
eq(R.count(meta_a, "kill:rare:bonerattle"), 1, "K another rare is not Bonerattle")
kill(anna, "grug_mobs:tollmaster_penn")
check(R.has_cloak(book, meta_a, "final_notice_1"), "K Final Notice")

-- B: boss ledger kills.
boss_kill(anna, "king:human")
eq(R.count(meta_a, "boss:king"), 1, "B a King kill")
eq(R.count(meta_a, "boss:king:human"), 1, "B per boss id")
check(R.has_cloak(book, meta_a, "kingslayer_1"), "B Kingslayer's cloak")
for _ = 1, 4 do boss_kill(anna, "king:orc") end
check(R.has_cloak(book, meta_a, "kingslayer_2") and not R.has_cloak(book, meta_a, "kingslayer_3"),
	"B five Kings: Kingslayer II")
boss_kill(anna, "dragon:stormscale")
check(R.has_cloak(book, meta_a, "wyvernslayer_1"), "B Wyvernslayer's cloak")
check(not R.has_cloak(book, meta_a, "dragonslayer_1"), "B the Wyvern is not the Ice Dragon")
boss_kill(bert, "dragon:wyrmglass")
check(R.has_cloak(book, meta_b, "dragonslayer_1"), "B Dragonslayer's cloak for bert")
eq(R.count(meta_b, "boss:dragon"), 1, "B bert's dragon kills")
check(not R.has_cloak(book, meta_b, "kingslayer_1"), "B bert killed no King")

-- P: grug_pvp's guard counter.
pvp_stats.bert = {guards = 49}
pvp_stat(bert, "guards", 49)
check(not R.has_cloak(book, meta_b, "honored_1"), "P 49 guards earn nothing")
pvp_stats.bert.guards = 50
pvp_stat(bert, "guards", 50)
check(R.has_cloak(book, meta_b, "honored_1"), "P the 50th guard earns Honored")
pvp_stat(bert, "kills", 3)
check(not R.has_cloak(book, meta_a, "honored_1"), "P anna is not honored")

-- J: counted crafts.
for _ = 1, 24 do award(bert, {profession = "cooking", output = "grug_cooking:stew 2", progress = true}) end
check(not R.has_cloak(book, meta_b, "suppers_ready_1"), "J 48 dishes earn nothing")
award(bert, {profession = "cooking", output = "grug_cooking:raw_stew_pot", progress = true})
award(bert, {profession = "cooking", output = "grug_cooking:raw_stew_pot", progress = true})
eq(R.count(meta_b, "craft:cooking"), 50, "J output counts add up")
check(R.has_cloak(book, meta_b, "suppers_ready_1"), "J 50 dishes: Supper's Ready")
for _ = 1, 50 do award(bert, {profession = "alchemist", output = "grug_alchemy:mixture_x", progress = true}) end
check(R.has_cloak(book, meta_b, "bottle_service_1"), "J 50 potions: Bottle Service")
award(bert, {profession = "weaponsmith", output = "grug_gear:sword", progress = true})
eq(R.count(meta_b, "craft:weaponsmith"), 0, "J an unused profession counts nothing")
eq(R.count(meta_a, "craft:cooking"), 0, "J no leak to anna")

-- X: deaths.
die(bert, {type = "punch"})
check(not R.has_cloak(book, meta_b, "grounded_1"), "X a punch is no fall")
die(bert, {type = "fall"})
check(R.has_cloak(book, meta_b, "grounded_1"), "X a fall death earns Grounded")
die(bert, nil)
check(true, "X a death without a reason does not fail")

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
check(A.select_cloak(anna, "kingslayer_1"), "S anna selects the Fallen Crown")
eq(applied[#applied], "anna", "S the selection redraws anna")
check(not A.select_cloak(anna, "dragonslayer_1"), "S anna does not own Wyrmglass")
check(not A.select_cloak(anna, "nonsense"), "S an unknown cloak is refused")
eq(A.selected_cloak(anna), "kingslayer_1", "S still the Fallen Crown")
local anna_again = new_player("anna", meta_a) -- leave and rejoin: same meta
local feed_before = #feed
join(anna_again)
eq(A.selected_cloak(anna_again), "kingslayer_1", "S the selection survives a rejoin")
eq(cloak_source(anna_again), "grug_achievements_cloak_kingslayer_1.png",
	"S the cloak source after the rejoin")
eq(#feed, feed_before, "S the rejoin earns nothing again")
check(A.select_cloak(anna_again, "none"), "S back to No cloak")
eq(meta_a:get_string(R.KEY_SELECTED), "", "S No cloak stores nothing")
meta_b:set_string(R.KEY_SELECTED, "hunter_1") -- bert does not own it
eq(A.selected_cloak(bert), "none", "S an unowned stored cloak reads as No cloak")
meta_b:set_string(R.KEY_SELECTED, "gone")
eq(A.selected_cloak(bert), "none", "S an unknown stored cloak reads as No cloak")
eq(cloak_source(bert), nil, "S ... and draws no cloak")
meta_b:set_string(R.KEY_CLOAKS, meta_b:get_string(R.KEY_CLOAKS) .. ",retired")
meta_b:set_string(R.KEY_SELECTED, "retired")
eq(A.selected_cloak(bert), "none", "S a cloak the catalogue dropped reads as No cloak")
check(A.select_cloak(bert, "plain_grey"), "S a default cloak can be selected")
eq(cloak_source(bert), "grug_achievements_cloak_plain_grey.png", "S grey cloak texture")

-- F: the dropdown and the page's resubmissions.
local fs = A.cloak_dropdown(anna_again, 0, 6.3, 2.6)
check(fs:find("dropdown%[0.00,6.30;2.60;grug_cloak;No cloak,Plain grey cloak,Hunter's Green," ..
	"Trail Green,Fallen Crown,Heavy Crown,Stormscale,", 1) ~= nil, "F dropdown items: " .. fs)
check(fs:find(";1%]$") ~= nil, "F No cloak is marked")
local before = #applied
check(not A.choose_cloak_by_name(anna_again, "No cloak"), "F the same name changes nothing")
eq(#applied, before, "F ... and draws nothing")
check(A.choose_cloak_by_name(anna_again, "Trail Green"), "F a new name selects")
eq(A.selected_cloak(anna_again), "hunter_2", "F Trail Green selected")
check(not A.choose_cloak_by_name(anna_again, "Honored Red"), "F an unowned name is ignored")
local context = {}
local tab = A.character_achievements_formspec(anna_again, context)
check(tab:find("Hunter III  150/500", 1, true) ~= nil, "F the tab shows Hunter III's progress")
check(tab:find("Honored  0/50", 1, true) ~= nil, "F the tab shows Honored's progress")
check(tab:find("Kill 50 guards of the enemy faction.", 1, true) ~= nil, "F condition text")
check(tab:find("Kingslayer III  5/20", 1, true) ~= nil, "F Kingslayer III's progress")
check(tab:find("grug_ach_next", 1, true) ~= nil, "F a second page")
check(tab:find("tooltip", 1, true) ~= nil and tab:find("Cloak: Deepwood Green", 1, true) ~= nil,
	"F the tooltip names the next cloak")
check(A.handle_tab_fields(anna_again, context, {grug_ach_next = true}), "F next page")
local tab2 = A.character_achievements_formspec(anna_again, context)
check(tab2:find("Grounded", 1, true) ~= nil and tab2:find("Hunter", 1, true) == nil,
	"F page 2 holds the rest: " .. tab2:sub(1, 120))
check(tab2:find("Last Word  0/1", 1, true) ~= nil, "F a one-kill achievement")
check(tab2:find("Kill Huskell or Paymaster Chirr.", 1, true) ~= nil, "F text_one")

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

-- Families, roles and rare ids exist in the source.
local roles = {}
for role in read(mobs_dir .. "data/subtypes.json"):gmatch('"role"%s*:%s*"([^"]+)"') do
	roles[role] = true
end
for family, bases in pairs(C.FAMILIES) do
	for base in pairs(bases) do
		check(seen["grug_mobs:" .. base], "C family " .. family .. " base " .. base .. " exists")
	end
end
for group, members in pairs(C.ROLE_GROUPS) do
	for role in pairs(members) do
		check(roles[role], "C group " .. group .. " role " .. role .. " exists")
	end
end
local rares_text = read(mobs_dir .. "rares.lua")
for group, ids in pairs(C.RARE_GROUPS) do
	for id in pairs(ids) do
		check(rares_text:find('register_rare%("' .. id .. '"') ~= nil,
			"C rare group " .. group .. " id " .. id .. " exists")
	end
end
-- Every catalogue counter is one a hook produces.
for _, ach in ipairs(book.achievements) do
	local c = ach.counter
	local ok = c == "kill:animal" or c == "kill:zombie" or c:find("^boss:") or
		c:find("^pvp:guards$") or c == "craft:cooking" or c == "craft:alchemist" or
		c == "death:fall"
	local family = c:match("^kill:family:(.+)$")
	local group = c:match("^kill:group:(.+)$")
	local rare = c:match("^kill:rare:(.+)$")
	ok = ok or (family and C.FAMILIES[family]) or (group and C.ROLE_GROUPS[group]) or
		(rare and C.RARE_GROUPS[rare])
	check(ok, "C counter " .. c .. " of " .. ach.id .. " is produced by a hook")
end
-- Every textured cloak has its file, and the ids are exactly Astra's 41.
local ASTRA = {"plain_grey"}
for _, row in ipairs({{"hunter", 3}, {"kingslayer", 3}, {"wyvernslayer", 3},
		{"dragonslayer", 3}, {"honored", 3}, {"zombie_slayer", 3}, {"boaring_work", 3},
		{"rat_race", 2}, {"suppers_ready", 3}, {"bottle_service", 3}, {"loose_bones", 3},
		{"stone_deaf", 2}, {"final_notice", 1}, {"rust_in_peace", 2},
		{"no_more_orders", 1}, {"last_word", 1}, {"grounded", 1}}) do
	for tier = 1, row[2] do ASTRA[#ASTRA + 1] = row[1] .. "_" .. tier end
end
local textured = {}
for _, cloak in ipairs(book.cloaks) do
	if cloak.texture then
		textured[cloak.id] = true
		eq(cloak.texture, "grug_achievements_cloak_" .. cloak.id .. ".png", "C texture name of " .. cloak.id)
		local handle = io.open(repo .. "/mods/PLAYER/grug_achievements/textures/" .. cloak.texture)
		check(handle ~= nil, "C texture file of " .. cloak.id)
		if handle then handle:close() end
	end
end
eq(#ASTRA, 41, "C Astra's list")
for _, id in ipairs(ASTRA) do check(textured[id], "C catalogue has " .. id) end
local count = 0
for _ in pairs(textured) do count = count + 1 end
eq(count, 41, "C no cloak beyond Astra's list")
-- Tier N of an achievement unlocks <id>_N.
for _, ach in ipairs(book.achievements) do
	for t, tier in ipairs(ach.tiers) do
		eq(tier.cloak, ach.id .. "_" .. t, "C " .. ach.id .. " tier " .. t .. " cloak")
	end
end
eq(#book.achievements, 17, "C seventeen achievements")

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R33 C3 PORTABLE FAIL") end
print("R33 C3 PORTABLE PASS checks=" .. checks)
