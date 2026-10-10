-- Release 0.45.1 lane CH portable test (LuaJIT): Charge down gentle slopes
-- (0.45.1 fix plan row 2). The REAL planner (grug_abilities/charge_path.lua)
-- with the game's own destination search (blink.lua) on built terrain:
--
--   A  straight stairs down, treads of 1 to 4 nodes, the target every 5 cm
--      from 3 to 12 m: never cut, ends on the destination;
--   B  stairs whose edges run diagonally (45 degrees), approached from 0 to
--      90 degrees, and a gentle natural-like slope with one-node steps and
--      irregular contours: never cut, ends within reach of the target;
--   C  the same stairs and slope climbed (a stair chain no hop clears lands
--      after an earlier edge of it): never cut, within reach;
--   D  a landing flush against a riser two or three nodes down: the last
--      step is dropped off in one straight line (a hop with g = 0) onto the
--      destination; under a roof the line would graze, the path stops on
--      the upper step instead; a staircase whose LAST step cannot be taken
--      stops at that step, not at the first edge of the chain.
--
-- Every plan is continuous, its hops land exactly, 24 m/s along the ground.
--
--   luajit tools/r451_ch/portable_test.lua [repo [planner-repo]]
--
-- planner-repo (optional) loads charge_path.lua from another checkout, for a
-- before/after comparison: the summary lines count the cut plans either way.
-- Prints "R451 CH PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local PLANNER = arg and arg[2] or ROOT
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
vector.copy = vector.new
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.round(v)
	return vector.new(math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
end
function vector.direction(a, b)
	local d = vector.subtract(b, a)
	local l = vector.length(d)
	return l == 0 and vector.new(0, 0, 0) or vector.multiply(d, 1 / l)
end

local path = dofile(PLANNER .. "/mods/PLAYER/grug_abilities/charge_path.lua")
local destinations = dofile(ROOT .. "/mods/PLAYER/grug_abilities/blink.lua")
local REACH = destinations.charge_reach
local floor = math.floor

local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local EYE = 1.47
local MOB = {-0.4, 0, -0.4, 0.4, 1.0, 0.4} -- a mob's box, feet at its position
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}

local function kinds(p)
	local out = {}
	for _, s in ipairs(p.segments) do
		out[#out + 1] = (s.kind == "hop" and s.g == 0 and "drop" or s.kind) ..
			("%.2f"):format(s.len)
	end
	return table.concat(out, ",")
end

-- Each segment starts where the previous one ends; hops land exactly; the
-- dash keeps 24 m/s along the ground.
local function sound(p)
	for k, s in ipairs(p.segments) do
		if not (s.t > 0 and s.len > 0) then return false end
		if not near(math.sqrt(s.v.x * s.v.x + s.v.z * s.v.z), 24, 1e-9) then return false end
		local t = s.t
		local e = {x = s.p0.x + s.v.x * t + 0.5 * s.a.x * t * t,
			y = s.p0.y + s.v.y * t + 0.5 * s.a.y * t * t,
			z = s.p0.z + s.v.z * t + 0.5 * s.a.z * t * t}
		local n = p.segments[k + 1]
		if n and (vector.distance(e, n.p0) > 1e-6 or not near(s.t0 + s.t, n.t0)) then return false end
		if not n and vector.distance(e, p.finish) > 1e-6 then return false end
		if s.kind == "hop" and not near(e.y - s.p0.y, s.rise, 1e-9) then return false end
	end
	return true
end

-- A heightmap world: column (x, z) is solid up to node row H(x, z) - 1, its
-- top at H - 0.5.
local function hworld(H)
	local function boxes(x, y, z)
		return y <= H(x, z) - 1 and FULL or nil
	end
	-- A marching ray (2 cm steps) against the full nodes: enough for tests.
	local function ray(from, to)
		local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local steps = math.max(1, math.ceil(len / 0.02))
		for s = 0, steps do
			local f = s / steps
			local px, py, pz = from.x + dx * f, from.y + dy * f, from.z + dz * f
			local nx, ny, nz = floor(px + 0.5), floor(py + 0.5), floor(pz + 0.5)
			if ny <= H(nx, nz) - 1 then return {x = px, y = py, z = pz} end
		end
		return nil
	end
	return {boxes = function(pos) return boxes(pos.x, pos.y, pos.z) end, ray = ray,
		xyz = boxes}
end

-- The feet height of a box standing at (x, z): the highest column top under
-- its footprint.
local function feet(H, x, z)
	local top = -math.huge
	for nx = floor(x - 0.3 + 0.5), floor(x + 0.3 + 0.5) do
		for nz = floor(z - 0.3 + 0.5), floor(z + 0.3 + 0.5) do
			top = math.max(top, H(nx, nz) - 0.5)
		end
	end
	return top
end

-- charge.lua's arrival rule: the end within REACH of the target's box.
local function in_reach(pos, t)
	local function gap(p, lo, hi) return math.max(lo - p, 0, p - hi) end
	local gx = gap(pos.x, t.x + MOB[1], t.x + MOB[4])
	local gy = gap(pos.y, t.y + MOB[2], t.y + MOB[5])
	local gz = gap(pos.z, t.z + MOB[3], t.z + MOB[6])
	return gx * gx + gy * gy + gz * gz <= REACH * REACH
end

-- One family of charges: every plan sound, none cut; `exact`: each ends on
-- its destination, else within reach of the target.
local function family(label, H, cases, exact)
	local world = hworld(H)
	local planned, cut, bad, missed, drops = 0, 0, 0, 0, 0
	local first
	for _, c in ipairs(cases) do
		local from = c.from
		local target = {x = c.x, y = feet(H, c.x, c.z), z = c.z}
		local dest = destinations.charge(from, EYE, BOX, target, world)
		if dest then
			planned = planned + 1
			local p = path.plan({boxes = world.xyz, liquid = function() return false end}, from, dest)
			local ok = exact and vector.distance(p.finish, dest) < 1e-6 or
				(not exact and in_reach(p.finish, target))
			if p.cut then cut = cut + 1 end
			if not sound(p) then bad = bad + 1 end
			if p.cut or not ok then
				missed = missed + 1
				first = first or ("target (%.2f, %.2f, %.2f): %s %s"):format(target.x, target.y,
					target.z, tostring(p.cut_why), kinds(p))
			end
			for _, s in ipairs(p.segments) do
				if s.kind == "hop" and s.g == 0 then drops = drops + 1 end
			end
		end
	end
	print(("  %-22s %4d plans  %3d cut  %3d short  (%d straight drops)"):format(label,
		planned, cut, missed, drops))
	check(planned > 0, label .. ": the game's destination exists")
	check(bad == 0, label .. ": every plan continuous, hops land exactly, 24 m/s")
	check(missed == 0, label .. ": " .. missed .. " plans stop short, the first " ..
		tostring(first))
end

------------------------------------------------------------------------------
-- A: straight stairs down.
------------------------------------------------------------------------------
print("A straight stairs down (the user's report)")
for tread = 1, 4 do
	local H = function(x)
		if x <= 0 then return 8 end
		return math.max(-4, 8 - math.ceil(x / tread))
	end
	local cases = {}
	for k = 0, 180 do
		cases[#cases + 1] = {from = {x = 0, y = 7.5, z = 0}, x = 3 + k * 0.05, z = 0}
	end
	family("tread " .. tread .. " down", H, cases, true)
end

------------------------------------------------------------------------------
-- B: diagonal stairs and a natural-like slope, down.
------------------------------------------------------------------------------
print("B diagonal stairs and a gentle slope, down")
local function fan(from, a0, a1, d0, d1, dd)
	local cases = {}
	for ang = a0, a1, 7.5 do
		local r = math.rad(ang)
		for d = d0, d1, dd do
			cases[#cases + 1] = {from = from, x = from.x + d * math.cos(r),
				z = from.z + d * math.sin(r)}
		end
	end
	return cases
end
for tread = 1, 3 do
	local H = function(x, z) return 8 - floor((x + z) / tread + 0.5) end
	family("diagonal tread " .. tread, H, fan({x = 0, y = 7.5, z = 0}, 0, 90, 3, 12, 0.25), false)
end
-- One-node steps, about 25 degrees on average, the contours bent.
local function slope(x, z)
	return floor(10 - 0.45 * x - 0.15 * z + 0.8 * math.sin(x * 0.7) * math.cos(z * 0.5) + 0.5)
end
do
	local cases = {}
	for _, o in ipairs({{0, 0}, {0.3, -0.2}, {-0.4, 0.45}, {2, 3}}) do
		local from = {x = o[1], y = feet(slope, o[1], o[2]), z = o[2]}
		for _, c in ipairs(fan(from, -60, 60, 3, 12, 0.5)) do cases[#cases + 1] = c end
	end
	family("gentle slope down", slope, cases, false)
end

------------------------------------------------------------------------------
-- C: the same, climbed.
------------------------------------------------------------------------------
print("C stairs and the slope climbed")
for tread = 1, 4 do
	local H = function(x)
		if x <= 0 then return 0 end
		return math.min(8, math.ceil(x / tread))
	end
	local cases = {}
	for k = 0, 180 do
		cases[#cases + 1] = {from = {x = 0, y = -0.5, z = 0}, x = 3 + k * 0.05, z = 0}
	end
	family("tread " .. tread .. " up", H, cases, false)
end
do
	local cases = {}
	for _, o in ipairs({{12, 0}, {12.3, -0.2}, {14, 3}}) do
		local from = {x = o[1], y = feet(slope, o[1], o[2]), z = o[2]}
		for _, c in ipairs(fan(from, 150, 210, 3, 12, 0.5)) do cases[#cases + 1] = c end
	end
	family("gentle slope up", slope, cases, false)
end

------------------------------------------------------------------------------
-- D: the straight drop off a step.
------------------------------------------------------------------------------
print("D the straight drop")
local FROM = {x = 0, y = -0.5, z = 0}
-- Level ground (top -0.5) up to node x = edge, `drop` nodes lower after it;
-- `roof(x, y)` adds node boxes.
local function step_lane(edge, drop, roof)
	return {
		boxes = function(x, y)
			if x <= edge then
				if y <= -1 then return FULL end
			elseif y <= -1 - drop then
				return FULL
			end
			return roof and roof(x, y) or nil
		end,
		liquid = function() return false end,
	}
end
for _, drop in ipairs({2, 3}) do
	for _, dx in ipairs({2.81, 2.85}) do
		local p = path.plan(step_lane(2, drop), FROM, {x = dx, y = -0.5 - drop, z = 0})
		local last = p.segments[#p.segments]
		check(sound(p) and not p.cut and near(p.finish.x, dx) and near(p.finish.y, -0.5 - drop) and
			last and last.kind == "hop" and last.g == 0 and near(last.p0.y, -0.5) and
			near(last.rise, -drop),
			("D a landing flush %d nodes down at %.2f: run to the edge, drop straight onto it (%s)"):format(
				drop, dx, kinds(p)))
	end
end
-- A curtain: a thin wall (x 0.1 to 0.5 of its node) hanging from above
-- down to the upper step's level, over the lower ground just past the edge.
-- The box at the destination fits under it, but the straight drop from
-- x = 2.75 to 2.9 would take the head through its foot, and no hop clears
-- the edge either: the path stops on the upper step.
local CURTAIN = {{0.1, -0.5, -0.5, 0.5, 0.5, 0.5}}
do
	local p = path.plan(step_lane(2, 3, function(x, y)
		if x == 3 and y >= 0 and y <= 3 then return CURTAIN end
	end), FROM, {x = 2.9, y = -3.5, z = 0})
	check(sound(p) and p.cut and near(p.finish.y, -0.5) and kinds(p) == "run2.75",
		"D a drop that would graze a curtain: stops on the step (" .. kinds(p) .. ")")
	p = path.plan(step_lane(2, 3), FROM, {x = 2.9, y = -3.5, z = 0})
	check(sound(p) and not p.cut, "D ... and without it the path drops (" .. kinds(p) .. ")")
end
-- A staircase down (treads of two nodes) whose last step, three nodes deep
-- and flush with the destination, has that curtain over it: the path goes
-- down the steps it can and stops on the last tread, not at the first edge.
do
	local function top(x)
		if x <= 0 then return -1 end
		if x <= 2 then return -2 end
		if x <= 4 then return -3 end
		return -6
	end
	local curtain = true
	local world = {
		boxes = function(x, y)
			if y <= top(x) then return FULL end
			if curtain and x == 5 and y >= -2 and y <= 1 then return CURTAIN end
			return nil
		end,
		liquid = function() return false end,
	}
	local p = path.plan(world, FROM, {x = 4.9, y = -5.5, z = 0})
	check(sound(p) and p.cut and near(p.finish.y, -2.5) and p.finish.x > 3.5 and p.finish.x < 4.8,
		"D stairs whose last step cannot be taken: stops on the last tread (" .. kinds(p) ..
		", at " .. ("%.2f"):format(p.finish.x) .. ")")
	curtain = false
	p = path.plan(world, FROM, {x = 4.9, y = -5.5, z = 0})
	check(sound(p) and not p.cut and near(p.finish.y, -5.5),
		"D ... and without it the path reaches the destination (" .. kinds(p) .. ")")
end

if failures > 0 then
	error(("R451 CH PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R451 CH PORTABLE PASS checks=%d"):format(checks))
