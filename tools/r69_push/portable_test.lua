-- Round 69 follow-up lane PUSH portable test (LuaJIT): idle hostile mobs walk
-- away from active Claim Stones.
--
--   luajit tools/r69_push/portable_test.lua [REPO]
--
-- Runs the shipped bytes: grug_mobs/aggro.lua and roam_avoid.lua, the Claim
-- Stone core grug_housing/registry.lua, and, cut out of their files,
-- SR.in_drift (spawn_regions.lua) and claim_refuses_spawn (spawn_policy.lua).
--   1. the spawn rules do not change: with active claims installed
--      roam_avoid_hit and SR.in_drift answer as without them, around and
--      inside a claim, while the push's own probe hits there;
--   2. active claims only, claim_refuses_spawn's test: draft, fuelled, run
--      out, refuelled, below the claim's floor, picked up, no grug_housing;
--   3. the push: an idle aggressive free roamer beside a claim walks away at
--      the same period; neutral, fighting or following mobs do not; outside
--      the wander radius the leash steers;
--   4. a claim placed over a mob's home does not push that mob, deep in it
--      or near its edge, so the leash has nothing to fight; a road still
--      does; a mob from outside is drawn out, also when surrounded;
--   5. the cost of one probe with no claim near (printed, comparison only).
-- Prints "R69 PUSH PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg and arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local function read(path)
	local f = assert(io.open(repo .. path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- A road band along x at z 1000..1007, nothing else.
local world = {}
_G.grug_core = {
	world_feature_at = function(pos)
		world.calls = (world.calls or 0) + 1
		local z = floor(pos.z + 0.5)
		return (world.everywhere or z >= 1000 and z <= 1007) and "road" or nil
	end,
	zone_authority_installed = function() return true end,
	recheck_switch = function() end,
	prune_engagement = function() end,
	mono_time = function() return 0 end,
}
_G.grug_zones = {hard_protection_kind_at = function() return nil end}
_G.core = {is_player = function() return false end}
_G.grug_mobs = {}
local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs"
dofile(mobs_dir .. "/aggro.lua")
dofile(mobs_dir .. "/roam_avoid.lua")
local GM = grug_mobs

local nudges = 0
GM.walk_toward = function(self, x, z)
	nudges = nudges + 1
	self.toward = {x = x, z = z}
end
GM.walk_fixed = function() return 0 end
GM.walk_follow = function() end
GM.walk_clear = function() end
GM.idle_health_tick = function() end

-- The real Claim Stone core on a fake clock.
local clock = 1800000000
local function new_model()
	local data = {}
	local storage = {
		get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end,
	}
	local model = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({storage = storage,
		now = function() return clock end})
	model.load()
	return model
end
local function housing_of(model)
	return {claim_at = model.claim_at, is_active = model.is_active}
end
local model = new_model()
local function place(name, x, z, lumps)
	local claim = model.create(name, {x = x, y = 5, z = z})
	if lumps then model.activate(claim, lumps) end
	return claim
end

-- The shipped bytes of two functions, cut out of files that need a whole
-- engine to load.
local function cut(text, from, to)
	local a = assert(text:find(from, 1, true), from)
	local b = assert(text:find(to, a, true), to)
	return text:sub(a, b - 1)
end
local SR = {}
assert(loadstring("local SR, CORE = ...\n" .. cut(read("/mods/ENTITIES/grug_mobs/spawn_regions.lua"),
	"SR.DRIFT = CORE.DRIFT", "-- Today's light behaviour")))(SR, {DRIFT = 16})
assert(loadstring("local claim_hostile_spawns = {[\"grug_mobs:test\"] = true}\n" ..
	cut(read("/mods/ENTITIES/grug_mobs/spawn_policy.lua"),
		"function grug_mobs.claim_refuses_spawn", "--\n-- Round 46 ruling 15")))()
check(SR.DRIFT == 16 and type(SR.in_drift) == "function", "the real in_drift")

local function hit_count(x, z, radius)
	local hits = GM.roam_avoid_probe({x = x, y = 5, z = z}, radius or 16, grug_housing)
	local n = 0
	for index = 1, 8 do
		if hits[index] then n = n + 1 end
	end
	return n
end

-- ---------------------------------------------------------------------------
-- 1. The spawn rules do not change
-- ---------------------------------------------------------------------------
local claim = place("owner", 0, 0, 10)
place("second", 300, 0, 10)
local function spawn_answers()
	local answers = {}
	for x = -140, 460, 7 do
		for z = -140, 140, 7 do
			local pos = {x = x, y = 5, z = z}
			answers[#answers + 1] = tostring(SR.in_drift(pos)) .. tostring(GM.roam_avoid_hit(pos))
		end
	end
	return table.concat(answers, ",")
end
local without = spawn_answers()
_G.grug_housing = housing_of(model)
check(spawn_answers() == without, "a claim changes neither in_drift nor roam_avoid_hit")
check(not without:find("true", 1, true), "no drift band, inside or around a claim")
for _, spot in ipairs({{0, 0}, {49, 0}, {51, 0}, {57, 20}, {66, 0}}) do
	check(not SR.in_drift({x = spot[1], y = 5, z = spot[2]}), "no drift at a claim")
end
check(SR.in_drift({x = 0, y = 5, z = 990}) and not SR.in_drift({x = 0, y = 5, z = 980}),
	"the road's drift band stands")
check(hit_count(60, 0) == 3, "the probe alone sees the claim: three ring points")
check(hit_count(0, 0) == 8, "the middle of a claim: every point")
check(hit_count(67, 0) == 0, "out of view: no hit")

-- ---------------------------------------------------------------------------
-- 2. Active claims only, the same test as a spawn refusal
-- ---------------------------------------------------------------------------
local function agree(x, z, want, label)
	local pushes = hit_count(x, z, 16) > 0
	local refuses = GM.claim_refuses_spawn("grug_mobs:test", {x = x + 16, y = 5, z = z})
	check(pushes == want and refuses == want, label)
end
agree(100, 100, false, "open ground")
local draft = place("drafter", 100, 100)
agree(100, 100, false, "a draft does not push")
model.activate(draft, 5)
agree(100, 100, true, "activated, it pushes")
clock = draft.paid_until - 1
agree(100, 100, true, "the last second of fuel")
clock = draft.paid_until
agree(100, 100, false, "run out: no push, no refusal")
agree(0, 0, true, "a claim with longer fuel still pushes")
draft.paid_until = clock + 100
agree(100, 100, true, "refuelled, it pushes again")
clock = 1800000000
check(GM.roam_avoid_probe({x = 60, y = model.MIN_Y - 1, z = 0}, 16, grug_housing)[5] == false,
	"below the claim's floor: no hit")
check(GM.roam_avoid_probe({x = 60, y = model.MIN_Y, z = 0}, 16, grug_housing)[5] == true,
	"at the claim's floor: a hit, as a refused cave spawn")
model.remove(draft, "picked_up")
agree(100, 100, false, "picked up: no push")
_G.grug_housing = nil
check(hit_count(0, 0) == 0, "no grug_housing: no hit, no error")

-- ---------------------------------------------------------------------------
-- 3. The push
-- ---------------------------------------------------------------------------
_G.grug_housing = housing_of(model)
local function mob(fields)
	local m = {name = "grug_mobs:test", type = "monster", state = "stand", view_range = 16,
		_grug_disposition = "aggressive", temp = {}, walk_velocity = 1,
		_grug_home = {x = 70, y = 5, z = 0}, pos = {x = 60, y = 5, z = 0}}
	for key, value in pairs(fields or {}) do m[key] = value end
	m.object = {get_pos = function() return m.pos end}
	return m
end
-- `seconds` leash slots with no walking; the number of nudges.
local function nudged(m, seconds)
	nudges = 0
	for _ = 1, seconds do GM.leash_tick(m, 1.0) end
	return nudges
end
math.randomseed(69)
do
	local m = mob()
	local count = nudged(m, 60)
	check(count >= 12 and count <= 15, "the same period: every 4 or 5 s, " .. count .. " in 60 s")
	check(m.toward.x > 60, "the push walks away from the claim")
end
for label, fields in pairs({
	neutral = {_grug_disposition = "neutral"},
	npc = {type = "npc"},
	camp = {_grug_camp_pos = {x = 60, y = 5, z = 0}},
	fighting = {attack = {}, state = "attack"},
	following = {following = {}},
	fleeing = {state = "runaway"},
}) do
	check(nudged(mob(fields), 30) == 0, label .. ": not pushed")
end
do
	-- Outside the wander radius the leash steers, every second, home.
	local m = mob({_grug_home = {x = 110, y = 5, z = 0}, pos = {x = 70, y = 5, z = 0}})
	check(nudged(m, 6) == 6 and m.toward.x == 110, "outside the leash: the leash, not the push")
end
do
	-- An unfuelled claim: the same mob beside it stays.
	local spent = place("spent", 0, 400, 5)
	clock = spent.paid_until
	local m = mob({_grug_home = {x = 70, y = 5, z = 400}, pos = {x = 60, y = 5, z = 400}})
	check(nudged(m, 30) == 0, "an unfuelled claim pushes nobody")
	clock = 1800000000
	check(nudged(m, 30) > 0, "fuelled again, it does")
end

-- ---------------------------------------------------------------------------
-- 4. A claim placed over a mob's home
-- ---------------------------------------------------------------------------
do
	local deep = {x = 0, y = 5, z = 0}
	local rim = {x = 40, y = 5, z = 0}
	check(nudged(mob({_grug_home = deep, pos = {x = 0, y = 5, z = 0}}), 60) == 0,
		"at its home deep in the claim: no nudge")
	check(nudged(mob({_grug_home = deep, pos = {x = 12, y = 5, z = 9}}), 60) == 0,
		"beside its home deep in the claim: no nudge")
	-- Pushed, this one would pace to and fro between the push and the leash.
	check(nudged(mob({_grug_home = rim, pos = {x = 45, y = 5, z = 0}}), 60) == 0,
		"at the claim's edge with its home inside: no nudge")
	check(nudged(mob({_grug_home = rim, pos = {x = 70, y = 5, z = 0}}), 60) == 0,
		"outside the claim with its home inside, on the leash: no nudge")
	-- The claim only steps aside: a road through it pushes this mob as before.
	local m = mob({_grug_home = {x = 0, y = 5, z = 960}, pos = {x = 0, y = 5, z = 990}})
	local road_claim = place("roadside", 0, 960, 10)
	check(nudged(m, 12) >= 2 and m.toward.z < 990, "a road in a claim still pushes its mob")
	model.remove(road_claim, "picked_up")
	-- The same mob with its home outside the claim is drawn out.
	m = mob({_grug_home = {x = 80, y = 5, z = 0}, pos = {x = 20, y = 5, z = 0}})
	check(nudged(m, 12) >= 2 and m.toward.x > 20 and abs(m.toward.z) < 1e-6,
		"surrounded by the claim, home outside: toward home")
	check(nudged(mob({_grug_home = {x = 70, y = 5, z = 0}, pos = {x = 49, y = 5, z = 0}}), 12) > 0,
		"walked in, home outside: pushed")
	m = mob({pos = {x = 20, y = 5, z = 0}})
	m._grug_home = nil
	check(nudged(m, 12) == 0, "surrounded without a home: no push")
	-- Every point on a road, the old rule, with housing installed.
	world.everywhere = true
	m = mob({_grug_home = {x = 70, y = 5, z = 40}, pos = {x = 80, y = 5, z = 40}})
	check(nudged(m, 12) >= 2 and m.toward.x < 80, "every point on a road: toward home")
	world.everywhere = nil
end

-- ---------------------------------------------------------------------------
-- 5. The cost of a probe with no claim near (comparison only)
-- ---------------------------------------------------------------------------
do
	local empty = new_model()
	local full = new_model()
	for index = 1, 100 do
		-- a claim every 300 nodes on a far row: the grid has rows, the mob's
		-- cell has none
		local c = full.create("p" .. index, {x = index * 300, y = 5, z = 30000})
		full.activate(c, 10)
	end
	local function cost(label, housing)
		_G.grug_housing = housing
		local rounds, spots = 40000, 8
		local t0 = os.clock()
		for round = 1, rounds do
			GM.roam_avoid_probe({x = 2000 + round % spots, y = 5, z = 2000}, 14, housing)
		end
		print(("probe with no claim near, %s: %.0f ns (LuaJIT, stub world, comparison only)")
			:format(label, (os.clock() - t0) / rounds * 1e9))
	end
	cost("no grug_housing", nil)
	cost("no claims", housing_of(empty))
	cost("100 claims elsewhere", housing_of(full))
	_G.grug_housing = nil
end

print("R69 PUSH PORTABLE PASS checks=" .. checks)
