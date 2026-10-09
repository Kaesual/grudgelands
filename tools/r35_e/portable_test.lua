-- Round 35 lane E portable test (night mobs leave at dawn, round35-plan.md
-- §2.5). Loads the REAL grug_mobs/dawn.lua under small stubs, with the real
-- spawn clock (clock_now) cut out of spawn_regions.lua and the real day-phase
-- edges of grug_core, and checks:
--   A. the clock: day exactly from DAY_PHASE_START to DAY_PHASE_END;
--   B. a free region mob spawned for the night leaves by day, quietly (one
--      smoke puff, one removal), and not before its one-second check;
--   C. it stays at night, in combat (target, attack or runaway state,
--      engagement, evade run) and while a player is within 64 nodes on every
--      axis (a cube, edge included; Round 45 playtest, was a 32-node sphere),
--      and leaves on the next check once neither holds;
--   D. never touched: a day mob, a mob without a spawn clock (underground,
--      water, leaders, rares, summons), a camp member, an unknown tag, a boss,
--      a rare, a tamed or owned mob, a camp post, an NPC;
--   E. the player list is fetched only when the rest of the rule holds;
--   F. grug_mobs/init.lua loads dawn.lua after spawn_regions.lua and its
--      do_custom stops the step after a departure.
--
-- Usage (repo root): luajit tools/r35_e/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The real code cut out of the shipped files.
local regions = read("mods/ENTITIES/grug_mobs/spawn_regions.lua")
local clock_src = regions:match("\n(local function clock_now%(%).-\nend)\n")
check(clock_src, "clock_now found")
local atmosphere = read("mods/CORE/grug_core/atmosphere.lua")
grug_core = {
	DAY_PHASE_START = tonumber(atmosphere:match("grug_core%.DAY_PHASE_START = ([%d%.]+)")),
	DAY_PHASE_END = tonumber(atmosphere:match("grug_core%.DAY_PHASE_END = ([%d%.]+)")),
}
check(grug_core.DAY_PHASE_START and grug_core.DAY_PHASE_END, "day phase edges read")

local timeofday = 0.5
core = {get_timeofday = function() return timeofday end}
local SR = {}
local cut = assert(loadstring(clock_src .. "\nreturn clock_now", "clock_now"))
SR.clock_now = cut()
SR.players_clear = function() error("dawn.lua must not use the spherical SR.players_clear") end

local units = {
	["z/rats"] = {tag = "z/rats"},
	["z/camp"] = {tag = "z/camp", is_camp = true},
}
SR.area_by_tag = function(tag) return units[tag] end
local players, fetched = {}, 0
SR.players = function()
	fetched = fetched + 1
	return players
end
local function player_at(x, y, z)
	return {get_pos = function() return {x = x, y = y or 0, z = z or 0} end}
end

local puffs, removed = 0, {}
mobs = {
	effect = function(_, _, _, texture) puffs = puffs + 1; check(texture == "mobs_tnt_smoke.png", "puff texture") end,
	remove = function(_, self) removed[self] = true end,
}
grug_mobs = {spawn_regions = SR}
dofile(repo .. "/mods/ENTITIES/grug_mobs/dawn.lua")

-- A. the clock
for _, case in ipairs({{0.18, "night"}, {grug_core.DAY_PHASE_START, "day"}, {0.5, "day"},
		{grug_core.DAY_PHASE_END, "day"}, {0.82, "night"}, {0, "night"}}) do
	timeofday = case[1]
	check(SR.clock_now() == case[2], "A clock at " .. case[1])
end

-- A mob at x = 0 with the given fields.
local function mob(fields)
	local self = {state = "stand", object = {get_pos = function() return {x = 0, y = 0, z = 0} end}}
	for k, v in pairs(fields or {}) do self[k] = v end
	return self
end
local function night_mob(fields)
	local self = mob({_grug_area = "z/rats", _grug_spawn_clock = "night"})
	for k, v in pairs(fields or {}) do self[k] = v end
	return self
end
-- Steps of 0.25 s for `seconds`; true when the mob left.
local function run(self, seconds)
	for _ = 1, math.floor(seconds / 0.25 + 0.5) do
		if grug_mobs.dawn_tick(self, 0.25) then
			return true
		end
	end
	return false
end

-- B. leaves by day, quietly, on its one-second check
timeofday, players = 0.5, {}
local rat = night_mob()
check(not run(rat, 0.75), "B not before the one-second check")
check(run(rat, 0.25), "B leaves on the check")
check(removed[rat] and puffs == 1 and grug_mobs.dawn_stats.left == 1, "B one puff, one removal")
check(grug_mobs.DAWN_NEAR == 64, "B near distance 64")

-- C. stays at night, in combat, with a player near; then leaves
timeofday = 0.9
rat = night_mob()
check(not run(rat, 5), "C stays at night")
timeofday = 0.1
check(not run(rat, 5), "C stays before dawn")
timeofday = grug_core.DAY_PHASE_START
check(run(rat, 1), "C leaves at dawn")

timeofday = 0.5
for _, case in ipairs({
	{"target", {attack = {}}},
	{"attack state", {state = "attack"}},
	{"runaway state", {state = "runaway"}},
	{"engaged", {temp = {grug_engaged = {singleplayer = true}}}},
	{"evading", {temp = {grug_evading = true}}},
}) do
	rat = night_mob(case[2])
	check(not run(rat, 3), "C stays in combat: " .. case[1])
	rat.attack, rat.state = nil, "stand"
	rat.temp.grug_engaged, rat.temp.grug_evading = nil, nil
	check(run(rat, 1), "C leaves after combat: " .. case[1])
end

players = {player_at(20)}
rat = night_mob()
check(not run(rat, 3), "C stays with a player at 20 nodes")
players = {player_at(40)}
check(not run(rat, 1), "C stays with a player at 40 nodes (beyond the old 32)")
players = {player_at(64)}
check(not run(rat, 1), "C stays with a player at 64 nodes (the edge counts)")
players = {player_at(-64, 64, 64)}
check(not run(rat, 1), "C stays with a player in the cube's corner (64 on every axis)")
players = {player_at(0, -63.5, 0)}
check(not run(rat, 1), "C stays with a player 63.5 nodes below")
players = {player_at(64.1), player_at(0, 65, 0), player_at(10, 10, -70)}
check(run(rat, 1), "C leaves once every player is beyond 64 nodes on some axis")

players = {player_at(10)}
rat = night_mob({attack = {}})
check(not run(rat, 2), "C fighting near a player stays")
rat.attack = nil
check(not run(rat, 2), "C after the fight, player still near: stays")
players = {}
check(run(rat, 1), "C leaves once alone")

-- D. never touched
players = {}
for _, case in ipairs({
	{"day mob", mob({_grug_area = "z/rats", _grug_spawn_clock = "day"})},
	{"no clock (underground, water, leader, rare, summon)", mob({_grug_area = "z/rats"})},
	{"no tag", mob({_grug_spawn_clock = "night"})},
	{"camp member", night_mob({_grug_area = "z/camp"})},
	{"unknown tag", night_mob({_grug_area = "z/gone"})},
	{"boss", night_mob({_grug_boss_id = "x", _grug_tier = "boss"})},
	{"boss tier", night_mob({_grug_tier = "boss"})},
	{"rare", night_mob({_grug_rare_id = "x", _grug_tier = "rare"})},
	{"boss summon", night_mob({_grug_boss_summon = true})},
	{"royal summon", night_mob({_grug_royal_summon = true})},
	{"leader", night_mob({_grug_leader = true})},
	{"tamed", night_mob({tamed = true})},
	{"owned", night_mob({owner = "singleplayer"})},
	{"camp post", night_mob({_grug_camp_pos = {x = 0, y = 0, z = 0}})},
	{"patroller", night_mob({_grug_patrol_route = {}})},
	{"npc", night_mob({type = "npc"})},
}) do
	check(not run(case[2], 5), "D never touched: " .. case[1])
	check(not removed[case[2]], "D not removed: " .. case[1])
end
check(run(night_mob({owner = ""}), 1), "D an empty owner is no owner")

-- E. the player list only when the rest holds
fetched = 0
timeofday = 0.9
run(night_mob(), 3)
timeofday = 0.5
run(night_mob({attack = {}}), 3)
run(mob({_grug_area = "z/camp", _grug_spawn_clock = "night"}), 3)
check(fetched == 0, "E no player list at night, in combat or for a camp member")
run(night_mob(), 1)
check(fetched == 1, "E one player list for a check that may leave")

-- F. the hook in init.lua
local init = read("mods/ENTITIES/grug_mobs/init.lua")
local hook = init:find("grug_mobs.leash_tick(self, dtime)\n\t\t-- A night mob by day leaves (dawn.lua); one field test for the rest.\n" ..
	"\t\tif grug_mobs.dawn_tick(self, dtime) then\n\t\t\treturn false\n\t\tend", 1, true)
check(hook ~= nil, "F do_custom stops the step after a departure")
local at_regions = init:find('dofile(modpath .. "/spawn_regions.lua")', 1, true)
local at_dawn = init:find('dofile(modpath .. "/dawn.lua")', 1, true)
check(at_regions and at_dawn and at_regions < at_dawn, "F dawn.lua loads after spawn_regions.lua")

print(("r35 e dawn departure: PASS (%d checks)"):format(checks))
