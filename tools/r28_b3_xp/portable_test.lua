-- Round 28 Lane B3 portable test (LuaJIT): XP in kill equivalents, rulings
-- 30-32. Loads the REAL grug_xp/init.lua and grug_mobs/levels.lua, and the
-- real kill settlement (grug_mobs.award_kill_xp with within_xp_range) cut
-- verbatim out of grug_mobs/init.lua, under a minimal `core` stub. Checks:
--   1. the unit and the curve: M(L) = 25 + 5L, XP per level rounded to tens,
--      4,200 XP to level 10 and 194,220 to level 60, level_from_xp on both
--      sides of every threshold, set_xp capped at the level-60 total;
--   2. kill XP through the real settlement: the level cap (player + 5), the
--      gray rule, elite x4 / rare x6, boss and critter tiers, the
--      `_grug_xp_reward` override, the participant split with each
--      recipient's own cap, same-faction refusal, no x1.5 and no race bonus;
--   3. gathering XP (ore 0.10, gem 0.20, fish 0.33 of M(min(ref, L + 5))),
--      quiet awards and no race bonus;
--   4. quest_reward(level, weight) and the human +10 % applied by add_xp;
--   5. cross-check: every line printed by ledger_values.py (the design
--      ledger's r28common.py) recomputed here must be identical: M, the
--      per-level XP and level starts for levels 1..60, level_of boundaries,
--      quest rewards (plain and human), kill XP over a mob x player x tier x
--      participants grid, gathering XP over kinds, tiers and player levels.
-- Prints the curve table (the source of progression.md's table).
--
-- Usage (repo root): luajit tools/r28_b3_xp/portable_test.lua [ROOT]

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then print("FAIL " .. label) end
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local players_by_name = {}
_G.core = {
	settings = {get = function() return nil end},
	log = function() end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_by_name = function(name) return players_by_name[name] end,
}
setmetatable(_G.core, {__index = function() return function() end end})
_G.vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	new = function(x, y, z) return {x = x, y = y, z = z} end}
local banners, fed = {}, {}
_G.grug_core = {
	hud_layout = {COLOR = {xp = 0}},
	banner = function(_, text) banners[#banners + 1] = text end,
	feed_xp = function(_, amount) fed[#fed + 1] = amount end,
}

local function make_player(name, level_xp, opts)
	opts = opts or {}
	local store = {}
	local meta = {
		get_int = function(_, key) return store[key] or 0 end,
		set_int = function(_, key, value) store[key] = value end,
	}
	local p = {name = name, human = opts.human, faction = opts.faction,
		pos = opts.pos or {x = 0, y = 0, z = 0}}
	function p:get_meta() return meta end
	function p:get_player_name() return self.name end
	function p:get_pos() return self.pos end
	store["grug_xp:xp"] = level_xp or 0
	players_by_name[name] = p
	return p
end

dofile(ROOT .. "/mods/PLAYER/grug_xp/init.lua")
local X = _G.grug_xp

-- Race bonus as grug_classes/perks.lua: only source "quest", human x1.1.
_G.grug_classes = {get_xp_bonus = function(player, source)
	if source == "quest" and player.human then return 1.1 end
	return 1
end}

-- Every add_xp call is recorded (amount before the race bonus, source).
local grants = {}
local real_add_xp = X.add_xp
X.add_xp = function(player, amount, source, quiet)
	local ok, granted = real_add_xp(player, amount, source, quiet)
	grants[#grants + 1] = {name = player.name, amount = amount, source = source,
		granted = granted}
	return ok, granted
end

_G.grug_mobs = {}
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/levels.lua")
_G.grug_factions = {same_faction = function(player, object)
	return player.faction ~= nil and player.faction == object.faction
end}
do
	local src = assert(io.open(ROOT .. "/mods/ENTITIES/grug_mobs/init.lua")):read("*a")
	local range = src:match("\nlocal function within_xp_range%(player, pos%)\n.-\nend\n")
	local settle = src:match("\nfunction grug_mobs%.award_kill_xp%(self%)\n.-\nend\n")
	assert(range and settle, "award_kill_xp / within_xp_range not found in init.lua")
	assert(loadstring(range .. "local eligible_kill_callbacks = {}\n" .. settle,
		"=award_kill_xp"))()
end
grug_mobs.cleanup_xp_participants = function() end

local mob_count = 0
local function mob(level, tier, participants, opts)
	opts = opts or {}
	mob_count = mob_count + 1
	local name = opts.name or "test:mob"
	local set = {}
	for _, p in ipairs(participants) do set[p.name] = true end
	return {name = name, _grug_level = level, _grug_tier = tier,
		object = {get_pos = function() return {x = 0, y = 0, z = 0} end,
			faction = opts.faction},
		temp = {grug_xp_participants = set}}
end
-- Kill XP each participant is awarded by one settlement (name -> amount
-- handed to add_xp; a level-60 player's capped meta would read 0 granted).
local last_granted
local function settle(m)
	grants = {}
	grug_mobs.award_kill_xp(m)
	local got = {}
	last_granted = {}
	for _, g in ipairs(grants) do
		got[g.name] = g.amount
		last_granted[g.name] = g.granted
	end
	return got
end
local function at_level(p, level) p:get_meta():set_int("grug_xp:xp", X.xp_for_level(level)) end

------------------------------------------------------------------------------
-- 1. The unit and the curve.
------------------------------------------------------------------------------
for level, m in pairs({[1] = 30, [2] = 35, [3] = 40, [10] = 75, [30] = 175, [60] = 325}) do
	eq(X.mob_xp(level), m, "M(" .. level .. ")")
end
eq(X.level_xp(1), 240, "level 1 -> 2: 30 x 8")
eq(X.level_xp(59), 7940, "level 59 -> 60")
eq(X.xp_for_level(1), 0, "level 1 starts at 0")
eq(X.xp_for_level(2), 240, "level 2 starts at 240")
eq(X.xp_for_level(10), 4200, "4,200 XP to level 10")
eq(X.xp_for_level(60), 194220, "194,220 XP to level 60")
eq(X.xp_for_level(61), 194220, "beyond the cap reads the cap")
for level = 1, 59 do
	check(X.level_xp(level) % 10 == 0, "level " .. level .. " XP is a multiple of ten")
	check(X.level_xp(level + 1) > X.level_xp(level) or level == 59, "curve rises at " .. level)
	eq(X.xp_for_level(level + 1) - X.xp_for_level(level), X.level_xp(level),
		"level start difference at " .. level)
end
for level = 1, 60 do
	local start = X.xp_for_level(level)
	eq(X.level_from_xp(start), level, "level_from_xp at the start of " .. level)
	if level > 1 then
		eq(X.level_from_xp(start - 1), level - 1, "level_from_xp one below " .. level)
	end
end
eq(X.level_from_xp(0), 1, "0 XP is level 1")
eq(X.level_from_xp(10 ^ 9), 60, "huge XP is level 60")
do
	local p = make_player("capper")
	X.set_xp(p, 10 ^ 7)
	eq(X.get_xp(p), 194220, "set_xp caps at the level-60 total")
	eq(X.get_level(p), 60, "capped player is level 60")
end
do -- level-up banner exactly at the threshold
	local p = make_player("leveler")
	banners = {}
	X.add_xp(p, 239, "kill")
	eq(#banners, 0, "239 XP: still level 1")
	X.add_xp(p, 1, "kill")
	eq(banners[1], "Reached level 2!", "240 XP: level 2")
end

-- Kill equivalents per level and in total (ruling 31: 82 to level 10, 968 to 60).
local ke10, ke60 = 0, 0
print("level   M(L)  XP to next  start XP   KE")
for level = 1, 60 do
	local next_xp = level < 60 and X.level_xp(level) or 0
	local ke = next_xp / X.mob_xp(level)
	if level < 10 then ke10 = ke10 + ke end
	ke60 = ke60 + ke
	if level <= 12 or level % 5 == 0 or level == 59 then
		print(("%5d %6d %11d %9d %5.1f"):format(level, X.mob_xp(level), next_xp,
			X.xp_for_level(level), ke))
	end
end
print(("kill equivalents: to level 10 %.1f, to level 60 %.1f"):format(ke10, ke60))
check(math.floor(ke10 + 0.5) == 82, "about 82 kill equivalents to level 10")
check(math.floor(ke60 + 0.5) == 968, "about 968 kill equivalents to level 60")

------------------------------------------------------------------------------
-- 2. Kill XP through the real settlement.
------------------------------------------------------------------------------
do
	local a = make_player("alice")
	local b = make_player("bob", nil, {human = true})
	at_level(a, 1)
	eq(settle(mob(1, "normal", {a})).alice, 30, "L1 kill at L1: 30 (no x1.5)")
	eq(settle(mob(3, "normal", {a})).alice, 40, "L3 kill at L1: 40 = 1.33 x an L1 kill")
	eq(settle(mob(20, "normal", {a})).alice, 55, "L20 kill at L1: capped at L6, 55")
	at_level(a, 15)
	eq(settle(mob(5, "normal", {a})).alice, nil, "gray: L5 at L15 gives nothing")
	eq(settle(mob(6, "normal", {a})).alice, 55, "L6 at L15 is not gray: 55")
	at_level(a, 10)
	eq(settle(mob(10, "elite", {a})).alice, 300, "elite x4 at L10: 300")
	eq(settle(mob(10, "rare", {a})).alice, 450, "rare x6 at L10: 450")
	eq(settle(mob(10, "boss", {a})).alice, 75, "boss tier: normal XP")
	eq(settle(mob(1, "critter", {a})).alice, nil, "critter: 0 XP")
	grug_mobs.register_level_cfg("test:kraken", {_grug_xp_reward = 0})
	grug_mobs.register_level_cfg("test:fixed", {_grug_xp_reward = 77})
	eq(settle(mob(60, "normal", {a}, {name = "test:kraken"})).alice, nil,
		"_grug_xp_reward 0 overrides")
	eq(settle(mob(60, "normal", {a}, {name = "test:fixed"})).alice, 77,
		"_grug_xp_reward 77 pays exactly 77")
	at_level(a, 60)
	eq(settle(mob(65, "boss", {a})).alice, 350, "L65 boss at L60: M(65) = 350")
	eq(settle(mob(70, "elite", {a})).alice, 1400, "L70 elite guard at L60: 4 x M(65)")
	-- Split: each recipient's own cap, divided by the head count.
	at_level(a, 10)
	at_level(b, 1)
	local got = settle(mob(10, "normal", {a, b}))
	eq(got.alice, 37, "split: L10 player gets floor(75 / 2)")
	eq(got.bob, 27, "split: L1 player gets floor(M(6) / 2)")
	eq(last_granted.bob, 27, "no race bonus on kills (human bob)")
	-- Out of range participants are not counted.
	b.pos = {x = 100, y = 0, z = 0}
	got = settle(mob(10, "normal", {a, b}))
	eq(got.alice, 75, "far participant is not eligible: full XP")
	eq(got.bob, nil, "far participant gets nothing")
	b.pos = {x = 0, y = 0, z = 0}
	-- Same faction: nothing.
	a.faction = "accord"
	eq(settle(mob(10, "normal", {a}, {faction = "accord"})).alice, nil, "own faction: no XP")
	a.faction = nil
	-- The settlement runs once.
	local m = mob(10, "normal", {a})
	settle(m)
	eq(settle(m).alice, nil, "a second settlement pays nothing")
end

------------------------------------------------------------------------------
-- 3. Gathering XP.
------------------------------------------------------------------------------
do
	eq(X.GATHER_XP_RATIO.ore, 0.10, "ore ratio")
	eq(X.GATHER_XP_RATIO.gem, 0.20, "gem ratio")
	eq(X.GATHER_XP_RATIO.fish, 0.33, "fish ratio")
	eq(X.gather_xp("ore", 10, 1), 6, "T1 ore at L1: 0.1 x M(6) = 5.5 -> 6")
	eq(X.gather_xp("ore", 10, 60), 8, "T1 ore at L60: 0.1 x M(10) = 7.5 -> 8")
	eq(X.gather_xp("gem", 40, 30), 40, "G2 gem at L30: 0.2 x M(35)")
	eq(X.gather_xp("fish", 10, 1), 18, "band 1 fish at L1: 0.33 x M(6)")
	eq(X.gather_xp("fish", 60, 60), 107, "band 6 fish at L60: 0.33 x M(60)")
	check(not pcall(X.gather_xp, "wood", 10, 1), "unknown kind raises")
	local p = make_player("miner", nil, {human = true})
	at_level(p, 12)
	fed = {}
	eq(X.award_gathering(p, "gem", 20), 22, "award at L12: 0.2 x M(min(20, 17))")
	eq(grants[#grants].source, "gathering", "source gathering")
	eq(grants[#grants].granted, 22, "no race bonus on gathering")
	eq(fed[1], 22, "a loud award posts its XP")
	fed = {}
	eq(X.award_gathering(p, "fish", 10, true), 25, "quiet fish award at L12: 0.33 x M(10)")
	eq(#fed, 0, "a quiet award posts nothing")
end

------------------------------------------------------------------------------
-- 4. Quest rewards.
------------------------------------------------------------------------------
do
	eq(X.quest_reward(1, 1), 30, "1 KE at level 1")
	eq(X.quest_reward(10, 2.5), 188, "2.5 KE at level 10: 187.5 -> 188")
	eq(X.quest_reward(60, 4), 1300, "4 KE at level 60")
	eq(X.quest_reward(5, 0), 0, "weight 0")
	local h = make_player("hilda", nil, {human = true})
	local o = make_player("orla")
	X.add_xp(h, X.quest_reward(10, 2.5), "quest")
	eq(grants[#grants].granted, 207, "human +10 %: 188 x 1.1 = 206.8 -> 207")
	X.add_xp(o, X.quest_reward(10, 2.5), "quest")
	eq(grants[#grants].granted, 188, "non-human: 188")
end

------------------------------------------------------------------------------
-- 5. Cross-check against the design ledger (r28common.py).
------------------------------------------------------------------------------
do
	local pipe = assert(io.popen("python3 '" .. ROOT .. "/tools/r28_b3_xp/ledger_values.py'"))
	local text = pipe:read("*a")
	pipe:close()
	local lines, kinds = 0, {}
	local quester = make_player("quester")
	local human = make_player("human_quester", nil, {human = true})
	local party = {make_player("p1"), make_player("p2"), make_player("p3")}
	for line in text:gmatch("[^\n]+") do
		lines = lines + 1
		local f = {}
		for word in line:gmatch("%S+") do f[#f + 1] = word end
		local kind = f[1]
		kinds[kind] = (kinds[kind] or 0) + 1
		local expected = tonumber(f[#f])
		if kind == "mob" then
			eq(X.mob_xp(tonumber(f[2])), expected, "ledger " .. line)
		elseif kind == "start" then
			eq(X.xp_for_level(tonumber(f[2])), expected, "ledger " .. line)
		elseif kind == "level_xp" then
			eq(X.level_xp(tonumber(f[2])), expected, "ledger " .. line)
		elseif kind == "level_of" then
			eq(X.level_from_xp(tonumber(f[2])), expected, "ledger " .. line)
		elseif kind == "quest" then
			local p = f[4] == "1" and human or quester
			X.add_xp(p, X.quest_reward(tonumber(f[3]), tonumber(f[2])), "quest")
			eq(grants[#grants].granted, expected, "ledger " .. line)
			p:get_meta():set_int("grug_xp:xp", 0)
		elseif kind == "kill" then
			local n = tonumber(f[5])
			local who = {}
			for i = 1, n do
				at_level(party[i], tonumber(f[3]))
				who[i] = party[i]
			end
			eq(settle(mob(tonumber(f[2]), f[4], who)).p1 or 0, expected, "ledger " .. line)
		elseif kind == "gather" then
			eq(X.gather_xp(f[2], X.gathering_reference_level(tonumber(f[3])), tonumber(f[4])),
				expected, "ledger " .. line)
		else
			check(false, "unknown ledger line " .. line)
		end
	end
	local parts = {}
	for _, k in ipairs({"mob", "level_xp", "start", "level_of", "quest", "kill", "gather"}) do
		parts[#parts + 1] = k .. " " .. (kinds[k] or 0)
	end
	print("ledger cross-check lines: " .. lines .. " (" .. table.concat(parts, ", ") .. ")")
	check(lines > 10000 and (kinds.level_xp or 0) == 59 and (kinds.start or 0) == 60,
		"ledger printed the full grid")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	print("R28 B3 XP PORTABLE FAIL")
	os.exit(1)
end
print("R28 B3 XP PORTABLE PASS checks=" .. checks)
