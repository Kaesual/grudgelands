-- Round 40 lane V4: portable fixture for the probe's pure parts -- the path
-- planner on every test course (destinations from the game's own
-- grug_abilities/blink.lua), the cooldown number and frame, and the engine's
-- hotbar slot arithmetic. Not part of tools/run_fixtures.sh (a probe).
--
--   luajit tools/r40_probe/portable_test.lua <repo>

local repo = arg[1] or "."
local dir = repo .. "/tools/r40_probe/"

-- The vector subset blink.lua uses (tools/r28_a4/portable_test.lua does the same).
vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.direction(a, b)
	local d = vector.subtract(b, a)
	local l = vector.length(d)
	return l == 0 and vector.new(0, 0, 0) or vector.multiply(d, 1 / l)
end
local planner = dofile(dir .. "planner.lua")
local hudmath = dofile(dir .. "hudmath.lua")
local shapes = dofile(dir .. "shapes.lua")
local blink = dofile(repo .. "/mods/PLAYER/grug_abilities/blink.lua")

local failures, checks = 0, 0
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. msg)
	end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local EYE = 1.47
local REACH = 3

local function course(name, opts)
	local shape = shapes.LIST[name]
	local world = shapes.table_world(shape)
	local from, target = shapes.start(shape), shapes.target(shape)
	local dest = blink.charge(from, EYE, BOX, target, world)
	if not dest then return nil end
	local plan, why = planner.plan(world.xyz, from, dest, opts)
	return {from = from, target = target, dest = dest, plan = plan, why = why}
end

local function kinds(plan)
	local out = {}
	for _, s in ipairs(plan.segments) do out[#out + 1] = s.kind end
	return table.concat(out, ",")
end

local function dist(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The segments are continuous: each starts where the previous one ends.
local function continuous(plan)
	for k = 2, #plan.segments do
		local s, n = plan.segments[k - 1], plan.segments[k]
		local t = s.t
		local e = {x = s.p0.x + s.v.x * t + 0.5 * s.a.x * t * t,
			y = s.p0.y + s.v.y * t + 0.5 * s.a.y * t * t,
			z = s.p0.z + s.v.z * t + 0.5 * s.a.z * t * t}
		if dist(e, n.p0) > 1e-6 or not near(s.t0 + s.t, n.t0) then return false end
	end
	return true
end

for _, name in ipairs(shapes.ORDER) do
	local c = course(name)
	if name == "wall_high" then
		check(c == nil, "wall_high: the game's destination refuses (no line of sight)")
	else
		check(c ~= nil, name .. ": the game's destination exists")
		if c then
			check(c.plan ~= nil, name .. ": planned (" .. tostring(c.why) .. ")")
			if c.plan then
				local p = c.plan
				check(continuous(p), name .. ": segments continuous")
				check(not p.cut, name .. ": not cut short")
				check(dist(p.finish, c.target) <= REACH, name .. ": ends within CHARGE_REACH")
				for _, s in ipairs(p.segments) do
					check(s.t > 0 and s.len > 0, name .. ": segment has length and time")
				end
				local hops = 0
				for _, s in ipairs(p.segments) do
					if s.kind == "hop" then hops = hops + 1 end
				end
				if name == "short" or name == "long" or name == "hit" then
					check(kinds(p) == "run", name .. ": one run, got " .. kinds(p))
				elseif name == "wall" then
					check(hops == 1, name .. ": one hop over the wall, got " .. kinds(p))
					for _, s in ipairs(p.segments) do
						if s.kind == "hop" then
							check(s.apex >= 1.25, name .. ": apex clears the wall")
							check(near(s.rise, 0), name .. ": lands level")
						end
					end
				elseif name == "step" then
					check(hops == 1, name .. ": one hop, got " .. kinds(p))
					check(near(p.finish.y, 0.5), name .. ": ends on the step")
				elseif name == "uphill" then
					check(hops >= 1, name .. ": hops up the stairs")
					check(p.finish.y > 2, name .. ": ends high up")
				elseif name == "ledge" then
					check(hops == 1 and near(p.finish.y, -0.5),
						name .. ": one hop down to the ground, got " .. kinds(p))
				end
			end
		end
	end
end

-- The straight carrier is one line to the destination.
do
	local s = planner.straight({x = 0, y = 0, z = 0}, {x = 8, y = 0, z = 6}, 16)
	check(near(s.total, 10 / 16) and near(s.dist, 10), "straight: 10 m at 16 m/s")
	local p = planner.state_at(s, s.total)
	check(near(p.x, 8) and near(p.z, 6), "straight: state_at the end is the destination")
end

-- A wall higher than max_rise cuts the path; too early a cut is refused.
do
	local shape = {dist = 9, floor = function() return 0 end, walls = {[6] = 2}}
	local world = shapes.table_world(shape)
	local p = planner.plan(world.xyz, {x = 0, y = -0.5, z = 0}, {x = 9, y = -0.5, z = 0})
	check(p and p.cut and p.dist < 6 and p.dist > 4.5, "a 2 m wall at 6 m cuts the path short")
	local shape2 = {dist = 9, floor = function() return 0 end, walls = {[1] = 2}}
	local w2 = shapes.table_world(shape2)
	local r, why = planner.plan(w2.xyz, {x = 0, y = -0.5, z = 0}, {x = 9, y = -0.5, z = 0})
	check(r == nil and why and why:find("refused"), "a wall 1 m out refuses the path")
end

-- Hops land exactly: the arc reaches the landing height at its end.
do
	local c = course("step")
	for _, s in ipairs(c.plan.segments) do
		if s.kind == "hop" then
			local y = s.p0.y + s.v.y * s.t + 0.5 * s.a.y * s.t * s.t
			check(near(y - s.p0.y, s.rise, 1e-9), "step: the hop lands at its rise")
			-- the top of the arc is apex above the takeoff
			local tt = s.v.y / -s.a.y
			if tt < s.t then
				local top = s.v.y * tt + 0.5 * s.a.y * tt * tt
				check(near(top, s.apex, 1e-9), "step: the arc's top is the apex")
			end
		end
	end
end

-- §2.1 number format.
local cases = {
	{300, "5m"}, {240.5, "5m"}, {240, "4m"}, {61, "2m"}, {60.5, "2m"},
	{60, "60"}, {59.2, "60"}, {59, "59"}, {1.2, "2"}, {1, "1"}, {0.01, "1"}, {0, ""},
}
for _, c in ipairs(cases) do
	local got = hudmath.cooldown_text(c[1])
	check(got == c[2], ("cooldown_text(%s) = %q, want %q"):format(c[1], got, c[2]))
end

-- Frames: 72, fixed by the angle step.
check(hudmath.frame_index(0, 10) == 0, "frame 0 at the start")
check(hudmath.frame_index(5, 10) == 36, "frame 36 at half")
check(hudmath.frame_index(9.99, 10) == 71, "frame 71 near the end")
check(hudmath.frame_index(12, 10) == 71, "frame clamps")
check(hudmath.frame_index(1, 2) == hudmath.frame_index(150, 300), "same share, same frame")

-- The engine's slot arithmetic.
do
	local g = hudmath.engine_slots({width = 1280, height = 720, density = 1,
		hud_scaling = 1, count = 8})
	check(g.size == 48 and g.pad == 4 and g.pitch == 56 and g.rows == 1, "1x: 48/4/56, one row")
	-- row width 448, left edge 640 - 224 = 416; first item at 420; bottom
	-- 720 - 4 - 56 = 660, item top 664.
	check(g.slots[1].x == 420 and g.slots[1].y == 664, "1x: slot 1 at 420,664")
	check(g.slots[8].x == 420 + 7 * 56, "1x: slot 8")
	local g2 = hudmath.engine_slots({width = 1280, height = 720, density = 1,
		hud_scaling = 1.3, count = 8})
	-- 48 * 1.3 = 62.4 -> 62; 62 / 12 -> 5; pitch 72 (not 56 * 1.3 = 72.8).
	check(g2.size == 62 and g2.pad == 5 and g2.pitch == 72, "1.3x: 62/5/72")
	local g3 = hudmath.engine_slots({width = 400, height = 600, density = 1,
		hud_scaling = 1, count = 8})
	check(g3.rows == 2, "448 px in a 400 px window: two rows")
	check(g3.slots[1].y < g3.slots[5].y and g3.slots[1].x == g3.slots[5].x,
		"two rows: items 1-4 above 5-8")
	-- The exact layout lands on the pixel after the engine's truncation.
	local lay = hudmath.layout("exact", {width = 1280, height = 720, density = 1,
		hud_scaling = 1.3, count = 8}, 96)
	for i = 1, 8 do
		local s = g2.slots[i]
		local x = 640 + hudmath.trunc(lay[i].cover.x * 1.3)
		local y = 720 + hudmath.trunc(lay[i].cover.y * 1.3)
		check(x == s.x and y == s.y, "exact layout: slot " .. i .. " on its pixel")
		check(hudmath.trunc(96 * lay[i].scale * 1.3) == 62, "exact layout: 62 px cover")
	end
end

-- Digit textures.
do
	local glyphs = {["5"] = {file = "d5.png", w = 24}, m = {file = "dm.png", w = 24}}
	local tex, w = hudmath.digit_texture("5m", glyphs, 32, -2)
	check(tex == "[combine:46x32:0,0=d5.png:22,0=dm.png" and w == 46, "digit texture: " .. tex)
end

-- The generated glyphs are the size overlay.lua assumes (24 x 32) and the
-- pie frames 96 x 96 (PNG IHDR).
do
	local function ihdr(path)
		local f = io.open(path, "rb")
		if not f then return nil end
		local data = f:read(24)
		f:close()
		local function u32(i)
			local a, b, c, d = data:byte(i, i + 3)
			return ((a * 256 + b) * 256 + c) * 256 + d
		end
		return u32(17), u32(21)
	end
	local w, h = ihdr(dir .. "textures/grug_r40_probe_digit_7.png")
	check(w == 24 and h == 32, "glyph 24 x 32")
	w, h = ihdr(dir .. "textures/grug_r40_probe_pie_71.png")
	check(w == 96 and h == 96, "pie 96 x 96")
end

print(("r40_probe portable_test: %d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
