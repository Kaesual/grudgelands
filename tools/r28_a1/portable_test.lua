-- Round 28 Lane A1 portable test (LuaJIT): roads and roaming, rulings 1, 2, 4.
--
--   luajit tools/r28_a1/portable_test.lua [REPO] [seed|none]
--
-- 1. Ruling 1 on synthetic roads of every kind (trail 1.5, secondary 2.5,
--    primary 3.5 half width; a straight road with round ends and an L
--    joint): through the real road module and the real world protection,
--    every column the protection covers (half width + ROAD_SIDE) lies inside
--    the vegetation claim exclusion (the road sampler's `near` with
--    EXCLUDE_PAD, what height.lua road_exclusion_at asks), and the exclusion
--    is strictly wider: a full ring of excluded, unprotected columns.
-- 2. Ruling 1 on the real road layout of one seed (default 4242424242;
--    "none" skips it): every column within a corridor's protection reach
--    answers overlay_exclusion_at == "road_corridor" (the claim exclusion the
--    mapgen vegetation writer and vegetation_density.lua categories refuse),
--    or is not land (categories refuses those itself). The next ring outward
--    is counted too. The cost of one push probe (eight points) is timed on
--    that world's real protection and zone session.
-- 3. Ruling 2 and 4: the real roam_avoid.lua and the real aggro.lua leash
--    tick under stubs: the away direction (mean, cancelling hits, all/none),
--    which features push (road, bridge, village, town; not camp, poi,
--    landmark), the 4-5 slot cadence, who is pushed (aggressive free roamers
--    only), never in combat, following or evading, and the leash winning
--    outside the wander radius.
-- Prints "R28 A1 PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local seed = arg[2] or "4242424242"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local floor, sqrt, abs, ceil = math.floor, math.sqrt, math.abs, math.ceil

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local roads = dofile(dir .. "/road_layout.lua")
local index128 = dofile(dir .. "/index128.lua")
local wp = dofile(dir .. "/world_protection.lua")
local HALF, Q, PAD = roads.P.HALF, roads.P.Q, roads.P.EXCLUDE_PAD

check(wp.ROAD_SIDE == 1 and wp.ROAD_VERTICAL == 5, "ruling 1: side 1, vertical 5")
check(PAD == 2 and PAD > wp.ROAD_SIDE, "the exclusion pad stays wider than the side")

-- ---------------------------------------------------------------------------
-- 1. Synthetic roads
-- ---------------------------------------------------------------------------
local function synthetic(kind, points, level)
	local X, Z, RQ, cls = {}, {}, {}, {}
	for i = 1, #points do
		X[i], Z[i], RQ[i], cls[i] = points[i][1], points[i][2], level * Q, "G"
	end
	return roads.serialize({roads = {{id = 1, kind = kind, X = X, Z = Z, RQ = RQ,
		cls = cls, a = "a", b = "b"}}})
end

for _, kind in ipairs({"trail", "secondary", "primary"}) do
	local hw = HALF[kind]
	local shapes = {}
	local straight = {}
	for i = 0, 40 do straight[#straight + 1] = {i, 0} end
	shapes.straight = straight
	local joint = {}
	for i = 0, 20 do joint[#joint + 1] = {i, 0} end
	for i = 1, 20 do joint[#joint + 1] = {20, i} end
	shapes.joint = joint
	for name, points in pairs(shapes) do
		local text = synthetic(kind, points, 10)
		local P = wp.new(index128, {corridors = wp.road_corridors(roads, text)})
		local S = roads.sampler(roads.deserialize(text))
		local protected, ring = 0, 0
		for x = -15, 55 do
			for z = -15, 35 do
				local guarded = P.kind_at(x, 10, z) ~= nil
				local excluded = S.near(x, z, PAD)
				if guarded then
					protected = protected + 1
					check(excluded, ("%s %s: protected column %d,%d outside the exclusion")
						:format(kind, name, x, z))
				elseif excluded then
					ring = ring + 1
				end
			end
		end
		check(protected > 0 and ring > 0, kind .. " " .. name .. " both bands present")
		if name == "straight" then
			-- across the middle: protected 2*floor(hw + 1) + 1, excluded
			-- 2*floor(hw + 2) + 1 (9/7/5 and 11/9/7 for primary/secondary/trail)
			local across_p, across_e = 0, 0
			for z = -15, 15 do
				if P.kind_at(20, 10, z) then across_p = across_p + 1 end
				if S.near(20, z, PAD) then across_e = across_e + 1 end
			end
			local want_p = ({primary = 9, secondary = 7, trail = 5})[kind]
			check(across_p == want_p, kind .. " protected width " .. across_p)
			check(across_e == want_p + 2, kind .. " excluded width " .. across_e)
			print(("ruling 1 %s (half width %.1f): protected %d wide, vegetation exclusion %d wide; " ..
				"%d protected columns, %d excluded-only ring columns"):format(kind, hw,
				across_p, across_e, protected, ring))
		end
	end
end

-- ---------------------------------------------------------------------------
-- 3. Ruling 2 and 4 (before the slow real world)
-- ---------------------------------------------------------------------------
-- Stubs: a straight road band along x from z = ROAD_Z to ROAD_Z + 7, a
-- village, a camp, a POI, a town and a landmark square.
local ROAD_Z = 10
local world = {authority = true, feature_calls = 0}
local function feature(pos)
	world.feature_calls = world.feature_calls + 1
	local x, z = floor(pos.x + 0.5), floor(pos.z + 0.5)
	if world.road and z >= ROAD_Z and z <= ROAD_Z + 7 then return world.road end
	if x >= 100 and x <= 140 and z >= -20 and z <= 20 then return "village" end
	if x >= 200 and x <= 240 and z >= -20 and z <= 20 then return "camp" end
	if x >= 300 and x <= 340 and z >= -20 and z <= 20 then return "poi" end
	return nil
end
local function hard(pos)
	local x, z = floor(pos.x + 0.5), floor(pos.z + 0.5)
	if x >= 400 and x <= 440 and z >= -20 and z <= 20 then return "town" end
	if x >= 500 and x <= 540 and z >= -20 and z <= 20 then return "landmark" end
	return nil
end
_G.grug_core = {
	world_feature_at = feature,
	zone_authority_installed = function() return world.authority end,
	recheck_switch = function() end,
	prune_engagement = function() end,
	mono_time = function() return 0 end,
}
_G.grug_zones = {hard_protection_kind_at = hard}
_G.core = {is_player = function() return false end}
_G.grug_mobs = {}
local walks = {}
local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs"
dofile(mobs_dir .. "/aggro.lua")
dofile(mobs_dir .. "/roam_avoid.lua")
grug_mobs.walk_toward = function(self, x, z, pos)
	walks[#walks + 1] = {x = x, z = z, from = {x = pos.x, z = pos.z}}
end
grug_mobs.idle_health_tick = function() end

-- 3a. the away direction
local away = grug_mobs.roam_avoid_away
local D = grug_mobs.ROAM_AVOID_DIRS
local function hits_of(list)
	local h = {}
	for i = 1, 8 do h[i] = false end
	for _, i in ipairs(list) do h[i] = true end
	return h
end
local function near(ax, az, bx, bz) return abs(ax - bx) < 1e-9 and abs(az - bz) < 1e-9 end
check(away(hits_of({})) == nil, "no hit: no push")
check(away(hits_of({1, 2, 3, 4, 5, 6, 7, 8})) == nil, "surrounded: no push")
local x, z = away(hits_of({1}))
check(near(x, z, -1, 0), "one hit at +x: walk -x")
x, z = away(hits_of({3}))
check(near(x, z, 0, -1), "one hit at +z: walk -z")
x, z = away(hits_of({2, 3, 4}))
check(near(x, z, 0, -1), "a road ahead at +z (three points): walk -z")
x, z = away(hits_of({1, 2}))
local a = math.atan2(z, x)
check(abs(a + (math.pi - math.pi / 8)) < 1e-9, "hits at 0 and 45 degrees: walk at 202.5 degrees")
x, z = away(hits_of({1, 5}))
check(near(x, z, D[3][1], D[3][2]), "on a straight road along x: off it at a right angle")
x, z = away(hits_of({3, 7}))
check(near(x, z, D[1][1], D[1][2]), "between two roads along x: along them")
x, z = away(hits_of({1, 3, 5, 7}))
check(near(x, z, D[2][1], D[2][2]), "on a crossroads: off it diagonally")
for mask = 1, 254 do
	local list = {}
	for i = 1, 8 do if floor(mask / 2 ^ (i - 1)) % 2 == 1 then list[#list + 1] = i end end
	local h = hits_of(list)
	x, z = away(h)
	check(x ~= nil and abs(x * x + z * z - 1) < 1e-9, "mask " .. mask .. " gives a unit direction")
	-- opposite of the hits' mean direction where it has one
	local sx, sz = 0, 0
	for _, i in ipairs(list) do sx, sz = sx + D[i][1], sz + D[i][2] end
	if sqrt(sx * sx + sz * sz) > 0.01 then
		check(abs(x * sx + z * sz + sqrt(sx * sx + sz * sz)) < 1e-9,
			"mask " .. mask .. " walks opposite the mean")
	else
		check(not h[1] or x ~= D[1][1] or z ~= D[1][2], "mask " .. mask .. " free direction")
		local free_dir = false
		for i = 1, 8 do
			if not h[i] and near(x, z, D[i][1], D[i][2]) then free_dir = true end
		end
		check(free_dir, "mask " .. mask .. " cancelling hits pick a free direction")
	end
end

-- 3b. which features push
local function probe_at(px, pz, r)
	local h = grug_mobs.roam_avoid_probe({x = px, y = 5, z = pz}, r)
	local n = 0
	for i = 1, 8 do if h[i] then n = n + 1 end end
	return n, h
end
for _, kind in ipairs({"road", "bridge"}) do
	world.road = kind
	local n, h = probe_at(0, 0, 8)
	check(n == 0, kind .. " out of view: no hit")
	n, h = probe_at(0, 0, 16)
	check(n == 3 and h[2] and h[3] and h[4], kind .. " in view: three ring points hit")
	x, z = away(h)
	check(near(x, z, 0, -1), kind .. ": walk away from it")
end
world.road = nil
check(probe_at(100 - 17, 0, 16) == 0, "village out of view")
check(probe_at(100 - 14, 0, 16) > 0, "village in view")
check(probe_at(200 - 14, 0, 16) == 0, "a bandit camp does not push")
check(probe_at(300 - 14, 0, 16) == 0, "a POI does not push")
check(probe_at(400 - 14, 0, 16) > 0, "a start town or capital city pushes")
check(probe_at(500 - 14, 0, 16) == 0, "a landmark does not push")

-- 3c. the leash tick: who, when, where
local function mob(fields)
	local m = {name = "grug_mobs:test", type = "monster", state = "stand",
		view_range = 16, _grug_disposition = "aggressive", temp = {},
		_grug_home = {x = 0, y = 5, z = 0}, pos = {x = 0, y = 5, z = 0}}
	for k, v in pairs(fields or {}) do m[k] = v end
	m.object = {get_pos = function() return m.pos end}
	return m
end
local function run(m, seconds)
	walks = {}
	world.feature_calls = 0
	for _ = 1, seconds do grug_mobs.leash_tick(m, 1.0) end
	return walks
end
world.road = "road"
math.randomseed(7)
do
	local m = mob()
	local w = run(m, 60)
	check(#w >= 12 and #w <= 15, "an idle aggressive free roamer near a road probes every 4-5 s: " ..
		#w .. " pushes in 60 s")
	for _, walk in ipairs(w) do
		check(walk.z < walk.from.z - 15, "the push walks away from the road")
	end
	-- the slots between pushes are 4 or 5 (the first one random in 1..5)
	m = mob()
	local slots, last = {}, nil
	for second = 1, 40 do
		walks = {}
		grug_mobs.leash_tick(m, 1.0)
		if #walks > 0 then
			if last then slots[#slots + 1] = second - last end
			last = second
		end
	end
	for _, gap in ipairs(slots) do check(gap == 4 or gap == 5, "probe gap " .. gap) end
	check(#slots >= 6, "probe gaps measured")
	-- the first probe of an activation lands at a random slot in 1..5
	local firsts = {}
	for _ = 1, 200 do
		local fresh = mob()
		for second = 1, 6 do
			walks = {}
			grug_mobs.leash_tick(fresh, 1.0)
			if #walks > 0 then firsts[second] = true break end
		end
	end
	check(firsts[1] and firsts[5] and not firsts[6], "first probe spread over slots 1..5")
end
-- far from any road: probes run but nothing pushes
world.road = nil
do
	local m = mob()
	check(#run(m, 30) == 0 and world.feature_calls > 0, "no road in view: probes, no push")
end
world.road = "road"
-- who is never pushed
for label, fields in pairs({
	neutral = {_grug_disposition = "neutral"},
	critter = {_grug_disposition = "critter"},
	npc = {type = "npc"},
	camp = {_grug_camp_pos = {x = 0, y = 5, z = 0}},
	patrol = {_grug_patrol_route = {}},
	rare = {_grug_rare_id = "grimtusk"},
	boss = {_grug_boss_id = "x"},
	no_leash = {_grug_no_leash = true},
	swimmer = {_grug_swim_dy = 1},
	tamed = {tamed = true},
	attacking = {attack = {}, state = "attack"},
	attack_state = {state = "attack"},
	following = {following = {}},
	fleeing = {state = "runaway"},
	evading = {temp = {grug_evading = {started = 0}}, pos = {x = 0, y = 5, z = -20}},
}) do
	local m = mob(fields)
	run(m, 20)
	check(world.feature_calls == 0, label .. ": never probes")
	if label ~= "evading" then
		check(#walks == 0, label .. ": never pushed")
	end
end
-- neither before the zone authority is installed nor without a view range
world.authority = false
check(#run(mob(), 20) == 0 and world.feature_calls == 0, "no authority: no probe")
world.authority = true
do
	local m = mob()
	m.view_range = nil
	check(#run(m, 20) == 0, "no view range: no push")
end
-- Ruling 4: outside the wander radius the leash walks home every slot and
-- the push is not asked; just inside it the push steers.
do
	-- beyond the road from home: the push walks it further out, up to the
	-- leash; past the leash the walk is home, across the road, every slot
	local m = mob({pos = {x = 0, y = 5, z = 33}})
	local w = run(m, 12)
	check(#w == 12 and world.feature_calls == 0, "outside the leash: home every slot, no probe")
	for _, walk in ipairs(w) do check(walk.x == 0 and walk.z == 0, "the leash walks home") end
	m = mob({pos = {x = 0, y = 5, z = 31}})
	w = run(m, 12)
	check(#w >= 2 and world.feature_calls > 0, "just inside the leash: the push steers")
	for _, walk in ipairs(w) do check(walk.z > 31, "pushed further from the road") end
end
print("ruling 2/4 logic: ok")

-- ---------------------------------------------------------------------------
-- 2. The real road layout of one seed
-- ---------------------------------------------------------------------------
if seed ~= "none" then
	local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
	local ps = W.planner_source
	local corridors = wp.road_corridors(W.roads, W.road_text)
	-- Two passes over windows of four segments round every other centreline
	-- point (a window's distance is never below the true one, and every
	-- segment lies in a window): the protected columns first, then the ring
	-- just outside the reach that no corridor protects.
	local guarded, ringed = {}, {}
	local protected, not_land, ring, ring_excluded, ring_land = 0, 0, 0, 0, 0
	local t0 = os.clock()
	for pass = 1, 2 do
		for _, c in ipairs(corridors) do
			local X, Z, n = c.X, c.Z, #c.X
			local reach = c.half_width + c.side
			local outer = reach + 1
			local square = ceil(outer) + 1
			for i = 1, n, 2 do
				local i0, i1 = math.max(1, i - 2), math.min(n - 1, i + 1)
				local cx, cz = floor(X[i] + 0.5), floor(Z[i] + 0.5)
				for x = cx - square, cx + square do
					for z = cz - square, cz + square do
						local key = (x + 4096) * 8192 + (z + 4096)
						if not guarded[key] and not ringed[key] then
							local best = math.huge
							for j = i0, i1 do
								local ax, az = X[j], Z[j]
								local vx, vz = X[j + 1] - ax, Z[j + 1] - az
								local l2 = vx * vx + vz * vz
								local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
								if u < 0 then u = 0 elseif u > 1 then u = 1 end
								local dx, dz = x - ax - u * vx, z - az - u * vz
								local d2 = dx * dx + dz * dz
								if d2 < best then best = d2 end
							end
							if pass == 1 and best <= reach * reach then
								guarded[key] = true
								protected = protected + 1
								if ps.overlay_exclusion_at(x, z) ~= "road_corridor" then
									local water = ps.column_values_at(x, z)
									check(water ~= "land", ("protected land column %d,%d is " ..
										"not excluded from vegetation"):format(x, z))
									not_land = not_land + 1
								end
							elseif pass == 2 and best <= outer * outer then
								ringed[key] = true
								ring = ring + 1
								if ps.column_values_at(x, z) == "land" then
									ring_land = ring_land + 1
									if ps.overlay_exclusion_at(x, z) == "road_corridor" then
										ring_excluded = ring_excluded + 1
									end
								end
							end
						end
					end
				end
			end
		end
	end
	check(protected > 10000, "real protected columns scanned")
	print(("ruling 1 seed %s: %d protected columns, all " ..
		"excluded from vegetation (%d of them not land); next ring outward: %d columns, " ..
		"%d land, %d of those excluded (%.1f s)"):format(seed, protected, not_land, ring,
		ring_land, ring_excluded, os.clock() - t0))

	-- The cost of one push probe on this world's real queries (comparison
	-- only): eight points, each world_feature_at (the protection index) and
	-- hard_protection_kind_at (the zone session), at the mob's height.
	local P = W.protection
	local session = W.session
	local function round(v) return floor(v + 0.5) end
	grug_core.world_feature_at = function(pos)
		return P.kind_at(round(pos.x), round(pos.y), round(pos.z))
	end
	grug_zones.hard_protection_kind_at = session.hard_protection_kind_at
	local samples = {}
	local random = math.random
	math.randomseed(11)
	-- half beside roads (where mobs near a road probe), half anywhere
	for k = 1, 2000 do
		local c = corridors[random(#corridors)]
		local i = random(#c.X)
		local s = wp.surface_node(c.R[i], c.R[i], 0)
		samples[k] = {x = c.X[i] + random(-20, 20), y = s + 1, z = c.Z[i] + random(-20, 20)}
	end
	for k = 2001, 4000 do
		local x, z = random(-3600, 3600), random(-3200, 3200)
		samples[k] = {x = x, y = session.terrain_height_at and
			session.terrain_height_at(x, z) or 10, z = z}
	end
	local pushes = 0
	for _, p in ipairs(samples) do
		if away(grug_mobs.roam_avoid_probe(p, 14)) then pushes = pushes + 1 end
	end
	local rounds = 5
	local t1 = os.clock()
	for _ = 1, rounds do
		for _, p in ipairs(samples) do grug_mobs.roam_avoid_probe(p, 14) end
	end
	local us = (os.clock() - t1) / (rounds * #samples) * 1e6
	print(("push probe cost (LuaJIT, this machine, comparison only): %.1f us per probe of " ..
		"eight points (%.2f us per point); %d of %d sample positions would push"):format(
		us, us / 8, pushes, #samples))
end

print("R28 A1 PORTABLE PASS checks=" .. checks)
