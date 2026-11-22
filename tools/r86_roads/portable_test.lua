-- Round 86 lane ROADS portable test (round86-plan.md §4 ROADS, rulings 7 and
-- 17), on constructed sections, LuaJIT:
--   A. the cut meets the ground at the side zone's edge (`road_layout.lua`
--      CUT_FADE, CUT_FADE_LIFT): a straight road along a hillside steeper
--      than the cut's rock face (3.7 per node), across a gentle one (0.4),
--      through a ridge and deep in a cut (the ground 40 above the road at its
--      edge); every side column is cut at most its distance to the edge deep
--      unless its face would be lifted more than CUT_FADE_LIFT times the
--      square of its distance to the road above the slope before Round 86,
--      nothing beyond
--      the edge changes, where the hill is gentle or the cut ends inside the
--      zone the answer is the rule before Round 86 (both huge) column for
--      column, and the deep cut keeps no step beside the road;
--   B. the seed fleet's check (`walls.lua` largest, as tools/seed_fleet/
--      seed.lua uses it): the rule before Round 86 leaves a wall at the edge
--      of the steep hillside (fails the bound 2), today's rule passes, an
--      exempt column is skipped, the report-only road_face (W.face) is low
--      on the deep cut and high under the pure fade, and the census's steps
--      and clusters see the
--      three walls (the north side's, the deep cut's south side, the ridge's
--      south side).
-- Usage (repo root): luajit tools/r86_roads/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local floor, max = math.floor, math.max
local RL = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/road_layout.lua")
local W = dofile(repo .. "/tools/r86_roads/walls.lua")
local P = RL.P
local SIDE, LIMIT = P.SIDE_MAX, 2
check(P.CUT_FADE == 1, "CUT_FADE is 1")

-- one secondary road along x at z = 0, its surface at y 10
local X, Z, R, cls = {}, {}, {}, {}
for i = 1, 201 do X[i], Z[i], R[i], cls[i] = i - 101, 0, 10, "G" end
local layout = {roads = {{id = 1, kind = "secondary", a = "a", b = "b", X = X, Z = Z, R = R,
	cls = cls, hw = P.HALF.secondary}}}
local hw = P.HALF.secondary
-- the ground: steep uphill north (3.7 per node beyond the road's edge),
-- gentle uphill south (0.4); a ridge east of x = 40 (up 3.7 per node to
-- 20 out, then down again); west of x = -60 a deep cut (the ground 40 above
-- the road at its edge, 2.5 per node across)
local function ground(x, z)
	local e = math.abs(z) - hw
	if x < -60 then return floor(50 + 2.5 * e) end
	if e <= 0 then return 10 end
	if x > 40 then
		local up = e <= 20 and e or 40 - e
		return floor(10 + 3.7 * max(0, up))
	end
	if z > 0 then return floor(10 + 3.7 * e) end
	return floor(10 + 0.4 * e)
end
local today = RL.sampler(layout)
local before = RL.with_params({CUT_FADE = 1e9, CUT_FADE_LIFT = 1e9}).sampler(layout)
local LIFT = P.CUT_FADE_LIFT
check(LIFT == 0.25, "CUT_FADE_LIFT is 0.25")
local function answer(s, x, z)
	local t = ground(x, z)
	local kind, _, nt = s.column(x, z, t, nil)
	return kind, nt or t, t
end

-- A. the cut meets the ground at the edge
local faded, same = 0, 0
for x = -95, 80, 7 do
	for z = -40, 40 do
		local e = math.abs(z) - hw
		local kind, f, t = answer(today, x, z)
		local kind0, f0 = answer(before, x, z)
		if e > SIDE then
			check(kind == nil and f == t, ("nothing beyond the edge at %d,%d"):format(x, z))
		elseif e > 0 and kind ~= "surface" then
			check(f >= math.min(t - (SIDE - e), f0 + LIFT * e * e) - 1, ("cut at most its distance " ..
				"to the edge deep or lifted %.2f e^2 above the slope at %d,%d (%d below %d at %.1f)")
				:format(LIFT, x, z, t - f, t, e))
			check(f >= f0, ("the fade never cuts deeper than before at %d,%d"):format(x, z))
			if f ~= f0 then faded = faded + 1 end
			if (z < 0 and x <= 40 and x >= -60) or (x > 40 and t - f0 <= SIDE - e) then
				check(kind == kind0 and f == f0, ("the gentle or shallow cut as before at %d,%d")
					:format(x, z))
				same = same + 1
			end
		end
	end
end
check(faded > 0 and same > 0, "both cases met")
-- the deep cut: no step beside the road larger than the slope's foot and
-- the bound allow (the low wall and 1, the slope's foot)
for x = -95, -65, 5 do
	local last
	for z = 2, SIDE + 6 do
		local _, f = answer(today, x, z)
		if last and z <= 8 then
			check(f - last <= P.WALL_H + 3, ("no step beside the road in the deep cut at %d,%d (%d)")
				:format(x, z, f - last))
		end
		last = f
	end
end

-- B. the fleet's check
local function query(s)
	return function(x, z)
		local kind, f, t = answer(s, x, z)
		return f, t, kind
	end
end
local step0, at0 = W.largest(layout, SIDE, query(before))
check(step0 > LIMIT and at0[3] > 0, ("the rule before Round 86 leaves a wall (%d)"):format(step0))
local step1 = W.largest(layout, SIDE, query(today))
check(step1 <= LIMIT, ("today's rule passes (%d)"):format(step1))
local step2 = W.largest(layout, SIDE, query(before), function(x, z) return z > 0 or x > 40 or x < -60 end)
check(step2 <= LIMIT, ("an exempt column is skipped (%d)"):format(step2))
local walls = W.clusters(W.steps(W.band(layout, SIDE), query(before), 1), 3)
local big = 0
for _, w in ipairs(walls) do if w.max > LIMIT then big = big + 1 end end
check(big == 3, ("a wall on the steep side, on the deep cut's south side and on the ridge's " ..
	"(%d)"):format(big))
-- the report-only road_face (W.face, -1 to 6 from the edge): today's
-- rule keeps the deep cut's foot, the pure fade (no lift bound) leaves a
-- ledge beside the road there
local face1 = W.face(layout, -1, 6, query(today))
local face0 = W.face(layout, -1, 6, query(RL.with_params({CUT_FADE_LIFT = 1e9}).sampler(layout)))
check(face1 <= P.WALL_H + 3 and face0 > face1 + 6, ("road_face today %d, pure fade %d")
	:format(face1, face0))
print(("r86_roads portable test: %d checks PASS (wall before %d, after %d; road_face %d, " ..
	"pure fade %d)"):format(checks, step0, step1, face1, face0))
