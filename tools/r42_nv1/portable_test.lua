-- Round 42 lane NV1 portable test (round42-plan.md §4.2, rulings 2-9 and
-- 17-20). Loads the REAL mobs/grug_nav.lua and mobs/grug_obstacle.lua on a
-- small fake engine (a node grid, a clock and a grid search modelled on the
-- engine's pathfinder: four directions, a walkable node blocks, a step up of
-- max_jump with a free column, a drop of max_drop, the box of start and goal
-- widened by the padding and exclusive on its positive edge). Checks:
--   D  the stuck detector: free walking, a target running away, every
--      intentional stop, a skipped step, slows and the water speed
--      (mobs/api.lua grug_liquid_speed, cut out), the 0.5 s window;
--   C  the candidate fan: rings 10 then 16, the angle order, the height
--      band, head room;
--   F  the follower: smoothing, the path's end, the target's drift, the
--      walkable line, stuck on the path, striking; a fixed walk followed to
--      its end and searched again off route;
--   L  the lockout (1 s combat, 5 s fixed), the cap of 20 searches a second,
--      the padding floor of 2, the 32-node leg;
--   W  head room and width: a rejected path is a failed search, a wide body
--      is steered through the 2x2 block it fits;
--   G  give-up: three failures in a row (also a visible target, a moving
--      target, intermediate points), the dragons only wait, progress resets
--      the count, a mob pressed into a fence (NV0 F7), the veto of
--      aggro.lua (8 nodes or 15 s, cut out);
--   P  the physics box of a mob taller than two nodes (ruling 20);
--   A  api.lua: the replaced pieces are gone.
-- Usage (repo root): luajit tools/r42_nv1/portable_test.lua [REPO]
-- Prints "R42 NV1 PORTABLE PASS checks=<n>" or raises.
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

-- ---------------------------------------------------------------------------
-- The fake engine.
-- ---------------------------------------------------------------------------
local us = 1000000
local world = {} -- "x,y,z" -> node name; unset is air, below y 1 stone
local LIMIT = 200 -- beyond |x|, |z| the map is not loaded
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name) world[key(x, y, z)] = name end
local function fill(x1, y1, z1, x2, y2, z2, name)
	for x = math.min(x1, x2), math.max(x1, x2) do
		for y = math.min(y1, y2), math.max(y1, y2) do
			for z = math.min(z1, z2), math.max(z1, z2) do set(x, y, z, name) end
		end
	end
end
local function name_at(x, y, z)
	local n = world[key(x, y, z)]
	if n then return n end
	return y <= 0 and "stone" or "air"
end

local find_calls = {}
core = {
	registered_nodes = {
		air = {name = "air", walkable = false},
		stone = {name = "stone", walkable = true},
		fence = {name = "fence", walkable = true},
		water = {name = "water", walkable = false, liquidtype = "source",
			liquid_viscosity = 1, groups = {water = 3, liquid = 3}},
		lava = {name = "lava", walkable = false, liquidtype = "source",
			damage_per_second = 4, groups = {lava = 3, liquid = 2}},
		slab = {name = "slab", walkable = true},
	},
	get_us_time = function() return us end,
}
function core.get_node_or_nil(pos)
	if math.abs(pos.x) > LIMIT or math.abs(pos.z) > LIMIT then return nil end
	return {name = name_at(pos.x, pos.y, pos.z)}
end
local function walkable(x, y, z)
	local def = core.registered_nodes[name_at(x, y, z)]
	return not def or def.walkable == true
end

-- The engine model (pathfinder.cpp): ends must not be walkable; the start
-- walks down to the ground up to max_drop, the goal up to max_jump.
function core.find_path(from, to, pad, jump, drop)
	find_calls[#find_calls + 1] = {pad = pad, from = from, to = to}
	us = us + 50
	if walkable(from.x, from.y, from.z) or walkable(to.x, to.y, to.z) then return nil end
	local function down(p, n)
		local y = p.y
		for _ = 1, n do
			if walkable(p.x, y - 1, p.z) then break end
			y = y - 1
		end
		return {x = p.x, y = y, z = p.z}
	end
	local s, g = down(from, drop), down(to, jump)
	local x1, x2 = math.min(from.x, to.x) - pad, math.max(from.x, to.x) + pad - 1
	local z1, z2 = math.min(from.z, to.z) - pad, math.max(from.z, to.z) + pad - 1
	local seen, queue, first = {[key(s.x, s.y, s.z)] = {}}, {s}, 1
	while first <= #queue do
		local c = queue[first]
		first = first + 1
		if c.x == g.x and c.y == g.y and c.z == g.z then
			local path, k = {}, key(c.x, c.y, c.z)
			local rev = {}
			while k do
				local e = seen[k]
				rev[#rev + 1] = e.cell or s
				k = e.from
			end
			for i = #rev, 1, -1 do path[#path + 1] = rev[i] end
			return path
		end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z, y = c.x + d[1], c.z + d[2], c.y
			if x >= x1 and x <= x2 and z >= z1 and z <= z2 then
				local ny
				if not walkable(x, y, z) then
					local yy = y
					while yy > y - drop - 1 and not walkable(x, yy - 1, z) do yy = yy - 1 end
					if walkable(x, yy - 1, z) and y - yy <= drop then ny = yy end
				else
					for up = 1, jump do
						if not walkable(x, y + up, z) and not walkable(c.x, c.y + up, c.z) then
							ny = y + up
							break
						end
					end
				end
				if ny then
					local k = key(x, ny, z)
					if not seen[k] then
						seen[k] = {from = key(c.x, c.y, c.z), cell = {x = x, y = ny, z = z}}
						queue[#queue + 1] = {x = x, y = ny, z = z}
					end
				end
			end
		end
	end
	return nil
end

local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
nav.init({obstacle = O, max_jump = 4, max_drop = 6})
local events = {}
nav.on_event = function(self, kind)
	events[#events + 1] = kind
	self.ev = self.ev or {}
	self.ev[kind] = (self.ev[kind] or 0) + 1
end

local function clear_world() world = {} end
local function pos(x, y, z) return {x = x, y = y, z = z} end
local function mob(fields)
	local m = {_grug_cbox = {-0.3, -0.01, -0.3, 0.3, 1.7, 0.3},
		initial_properties = {stepheight = 1.1}, jump_height = 4,
		fear_height = 6, floats = true, temp = {}}
	for k, v in pairs(fields or {}) do m[k] = v end
	return m
end
local function target_obj()
	return {
		get_luaentity = function() return nil end,
		is_player = function() return false end,
		get_properties = function() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}} end,
	}
end
-- Feet at y 0.5 stand on the floor's top (y 0 is the top floor node).
local Y = 0.51

local DT = 0.1
-- One server step of a combat mover: the step, then what it commanded.
local function server_step()
	us = us + math.floor(DT * 1e6)
	nav.begin_server_step(DT)
	O.begin_server_step()
end
local function mob_step(m, p, target, tpos, v, striking)
	local dx, dz = tpos.x - p.x, tpos.z - p.z
	local steer, outcome = nav.combat_step(m, p, DT, target, tpos,
		math.sqrt(dx * dx + dz * dz), striking == true, m.never == true)
	-- do_states returns on a give-up before it commands anything.
	if outcome ~= "give_up" then nav.command(m, p, v) end
	return steer, outcome
end
local function step(m, p, target, tpos, v, striking)
	server_step()
	return mob_step(m, p, target, tpos, v, striking)
end
local function fstep(m, p, goal, goal_key, v)
	us = us + math.floor(DT * 1e6)
	nav.begin_server_step(DT)
	O.begin_server_step()
	local steer, outcome = nav.fixed_step(m, p, DT, goal, goal_key)
	nav.command(m, p, v)
	return steer, outcome
end
local function nst(m) return m.temp.grug_nav end
-- Advance a mob straight at `to` by v*DT (no collision; the tests hold it).
local function walk(p, to, v)
	local dx, dz = to.x - p.x, to.z - p.z
	local l = math.sqrt(dx * dx + dz * dz)
	if l < 1e-6 then return p end
	local d = math.min(l, v * DT)
	return pos(p.x + dx / l * d, p.y, p.z + dz / l * d)
end

-- ---------------------------------------------------------------------------
-- D. The stuck detector.
-- ---------------------------------------------------------------------------
do
	clear_world()
	local m, t = mob(), target_obj()
	local p, tp = pos(0, Y, 0), pos(30, Y, 0)
	-- D1 free walking at the commanded speed: never stuck.
	for _ = 1, 30 do
		step(m, p, t, tp, 4.6)
		p = walk(p, tp, 4.6)
	end
	check(not m.ev and not nst(m).want, "D1 free walking is never stuck")
	-- D2 the target runs away faster than the mob: still not stuck.
	for _ = 1, 30 do
		tp = pos(tp.x + 0.6, Y, 0)
		step(m, p, t, tp, 4.6)
		p = walk(p, tp, 4.6)
	end
	check(not m.ev, "D2 a target running away faster is no stuck mob")
	-- D3 every intentional stop (speed 0) never counts, however long.
	for _ = 1, 30 do step(m, p, t, tp, 0) end
	check(not m.ev, "D3 an intentional stop is not stuck")
	-- D4 held in place while it wants to move: stuck after the 0.5 s window.
	local first
	for i = 1, 10 do
		step(m, p, t, tp, 4.6)
		if m.ev and m.ev.stuck and not first then first = i end
	end
	check(first ~= nil and first >= 6 and first <= 7,
		"D4 stuck after one 0.5 s window, step " .. tostring(first))
	-- D5 a slowed mob moving at its slowed speed is free.
	local m2 = mob()
	local q = pos(0, Y, 5)
	for _ = 1, 30 do
		step(m2, q, t, pos(30, Y, 5), 2.3)
		q = walk(q, pos(30, Y, 5), 2.3)
	end
	check(not m2.ev, "D5 a slowed mob at its slowed speed is not stuck")
	-- D6 water: the expected distance uses the speed the mob really has.
	-- A viscosity-7 liquid moves it at 1/8: raw speed would read stuck.
	local raw, eff = mob(), mob()
	local a, b = pos(0, Y, 8), pos(0, Y, 9)
	for _ = 1, 12 do
		server_step()
		mob_step(raw, a, t, pos(30, Y, 8), 4.6)
		mob_step(eff, b, t, pos(30, Y, 9), 4.6 / 8)
		a = walk(a, pos(30, Y, 8), 4.6 / 8)
		b = walk(b, pos(30, Y, 9), 4.6 / 8)
	end
	check(raw.ev and raw.ev.stuck, "D6 raw speed in a slow liquid would read stuck")
	check(not eff.ev, "D6 the real (liquid) speed reads free")
	-- D7 a skipped step (knockback pause, stun) breaks the window.
	local m3 = mob()
	local c = pos(0, Y, 12)
	for _ = 1, 4 do step(m3, c, t, pos(30, Y, 12), 4.6) end
	us = us + 100000
	nav.begin_server_step(DT) -- a step without do_states
	for _ = 1, 4 do step(m3, c, t, pos(30, Y, 12), 4.6) end
	check(not m3.ev, "D7 a skipped step restarts the window")
	-- D8 the liquid speed is api.lua's set_velocity rule (cut out).
	local api = read("mods/ENTITIES/mobs/api.lua")
	local function cut(from, to)
		local s = api:find(from, 1, true)
		local _, e = api:find(to, s, true)
		return api:sub(s, e)
	end
	local src = cut("local function check_for(look_for, look_inside)", "\nend\n") ..
		cut("local function grug_liquid_speed(self, v)", "\nend\n") ..
		"return grug_liquid_speed\n"
	local chunk = assert(loadstring(src))
	setfenv(chunk, setmetatable({min = math.min}, {__index = _G}))
	local speed = chunk()
	check(speed({standing_in = "water"}, 4.6) == 2.3, "D8 water halves the speed")
	check(speed({standing_in = "water", fly_in = "water"}, 4.6) == 4.6,
		"D8 a swimmer keeps its speed")
	check(speed({standing_in = "air"}, 4.6) == 4.6, "D8 dry ground keeps it")
	check(api:find("grug_nav.command(self, s, grug_nav_v > 0\n\t\t\t\t\t\tand grug_liquid_speed(self, grug_nav_v) or 0)", 1, true) ~= nil,
		"D8 do_states feeds the detector the liquid speed")
	check(api:find("if self.order == \"stand\" or grug_winding_up(self) then grug_nav_v = 0 end", 1, true) ~= nil,
		"D8 ordered to stand and winding up are intentional stops")
	check(api:find("if not in_sight then grug_nav_v = self.run_velocity end", 1, true) ~= nil,
		"D8 a visible target in reach is struck, a blocked one run at")
	check(api:find("grug_nav_v = grug_chase_v\n", 1, true) ~= nil
		and api:find("if self.at_cliff or pad < 0.2 then", 1, true) ~= nil,
		"D8 a chaser held at a cliff or under its target still wants to move")
end

-- ---------------------------------------------------------------------------
-- C. Candidates.
-- ---------------------------------------------------------------------------
do
	clear_world()
	local m = mob()
	local body = nav.body(m, nil)
	check(body.head == 2 and body.step == 1 and body.drop == 6 and body.jump == 1,
		"C0 the body: head 2, step 1, drop 6, jump 1")
	-- next_candidate is internal: drive it through combat_step's attempt.
	local t = target_obj()
	local p = pos(0, Y, 0)
	local tp = pos(40, Y, 0)
	-- Hold the mob until it is stuck; the search runs to the ring point.
	local s
	for _ = 1, 8 do s = step(m, p, t, tp, 4.6) end
	local call = find_calls[#find_calls]
	check(call and call.to.x == 10 and call.to.z == 0 and call.to.y == 1,
		"C1 far target: ring 10 straight toward it")
	check(s ~= nil and nst(m).path ~= nil, "C1 a path to the ring point")
	-- C2 the straight candidate stands on nothing (a hole): the next angle.
	clear_world()
	fill(9, -8, -1, 11, 0, 1, "air")
	local m2 = mob()
	find_calls = {}
	for _ = 1, 8 do step(m2, p, t, tp, 4.6) end
	call = find_calls[#find_calls]
	local ex = math.floor(10 * math.cos(math.rad(20)) + 0.5)
	local ez = math.floor(10 * math.sin(math.rad(20)) + 0.5)
	check(call and call.to.x == ex and call.to.z == ez,
		"C2 an unstandable candidate: +20 degrees next")
	-- C3 a failed search to a candidate: the next attempt tries ring 16.
	clear_world()
	fill(-20, 1, -20, 20, 5, 20, "fence") -- no standable point in the band
	fill(-1, 1, -1, 1, 5, 1, "air")
	local m3 = mob()
	find_calls = {}
	for _ = 1, 8 do step(m3, p, t, tp, 4.6) end
	check(#find_calls == 0 and m3.ev and m3.ev.refused == 1,
		"C3 no standable candidate at all: refused, counted")
	clear_world()
	fill(-2, 1, -2, 2, 3, 2, "fence")
	fill(-1, 1, -1, 1, 3, 1, "air")
	local m4 = mob()
	find_calls = {}
	for _ = 1, 8 do step(m4, p, t, tp, 4.6) end
	us = us + 2100000
	for _ = 1, 8 do step(m4, p, t, tp, 4.6) end
	check(#find_calls == 2 and find_calls[1].to.x == 10 and find_calls[2].to.x == 16,
		"C3 ring 10 failed: ring 16 next")
	-- C4 the height band: a terrace 3 up is standable, 4 up is not.
	clear_world()
	fill(9, 1, -1, 11, 3, 1, "stone")
	check(nav.stand_y(body, 10, 0, 1) == 4, "C4 a terrace 3 up is in the band")
	fill(9, 4, -1, 11, 4, 1, "stone")
	check(nav.stand_y(body, 10, 0, 1) == nil, "C4 4 up is not")
	-- C5 head room: a 1-high gap under an overhang is no place for 2 nodes.
	clear_world()
	set(10, 2, 0, "stone")
	check(nav.stand_y(body, 10, 0, 1) == 3, "C5 under a 1-high overhang: on top instead")
	set(10, 4, 0, "stone")
	set(10, 5, 0, "stone")
	check(nav.stand_y(body, 10, 0, 1) == nil, "C5 no room anywhere in the band")
	local small = nav.body(mob({_grug_cbox = {-0.3, -0.01, -0.3, 0.3, 0.84, 0.3}}), nil)
	check(small.head == 1 and nav.stand_y(small, 10, 0, 1) == 3,
		"C5 a wolf fits in the 1-high space on the stone")
end

-- ---------------------------------------------------------------------------
-- F. The follower.
-- ---------------------------------------------------------------------------
-- A row of trunks across the line at x 5 (z -3..3), gaps nowhere: the mob at
-- the origin, the target at x 10.
local function wall_scene()
	clear_world()
	fill(5, 1, -3, 5, 4, 3, "stone")
end
do
	wall_scene()
	local m, t = mob(), target_obj()
	local p, tp = pos(4, Y, 0), pos(10, Y, 0)
	find_calls = {}
	local steer
	for _ = 1, 8 do steer = step(m, p, t, tp, 4.6) end
	check(#find_calls == 1 and find_calls[1].pad == 6, "F1 one search, padding 6")
	check(steer ~= nil and nst(m).path ~= nil, "F1 the mob follows a path")
	-- The steer point is never inside the wall and leads round its end.
	check(not walkable(math.floor(steer.x + 0.5), 1, math.floor(steer.z + 0.5)),
		"F1 the steer point is open")
	-- Walk the path: the mob reaches the target side.
	local reached
	for _ = 1, 200 do
		steer = step(m, p, t, tp, 4.6)
		if not steer then reached = true break end
		p = walk(p, steer, 4.6)
	end
	check(reached and p.x > 5, "F1 the path leads round the wall: x " .. p.x)
	check(not nst(m).want, "F1 left on a walkable line: no new search")
	for _ = 1, 8 do
		step(m, p, t, tp, 4.6)
		p = walk(p, tp, 4.6)
	end
	check(nst(m).fails == 0 and not nst(m).line_left,
		"F1 the free straight walk is progress")
	-- F2 the target moves 5 nodes from the planned end: the path is left.
	wall_scene()
	m = mob()
	p, tp = pos(4, Y, 0), pos(10, Y, 0)
	for _ = 1, 8 do steer = step(m, p, t, tp, 4.6) end
	check(nst(m).path ~= nil, "F2 following")
	steer = step(m, p, t, pos(10, Y, 5), 4.6)
	check(steer == nil and nst(m).path == nil and m.ev.leave_drift == 1,
		"F2 a target 5 from the planned end: the path is left")
	-- F3 the straight line becomes walkable: left within 0.5 s, progress.
	wall_scene()
	m = mob()
	p, tp = pos(4, Y, 0), pos(10, Y, 0)
	for _ = 1, 8 do step(m, p, t, tp, 4.6) end
	check(nst(m).path ~= nil, "F3 following")
	fill(5, 1, -3, 5, 4, 3, "air")
	local left
	for i = 1, 6 do
		step(m, p, t, tp, 0) -- standing (no stuck window)
		if not nst(m).path then left = i break end
	end
	check(left and left <= 5 and m.ev.leave_line == 1 and nst(m).fails == 0,
		"F3 a walkable line leaves the path, step " .. tostring(left))
	-- F3b stuck right after such a leave (before any free window): the line
	-- test was wrong, a failure (never a found-and-left loop).
	wall_scene()
	m = mob()
	for _ = 1, 8 do step(m, p, t, tp, 4.6) end
	nst(m).line_left = true
	nst(m).path = nil
	for _ = 1, 7 do step(m, p, t, tp, 4.6) end
	check(nst(m).fails == 1, "F3b stuck after leaving on the line counts")
	-- F4 stuck on its path: a failure.
	wall_scene()
	m = mob()
	p, tp = pos(4, Y, 0), pos(10, Y, 0)
	for _ = 1, 8 do step(m, p, t, tp, 4.6) end
	for _ = 1, 7 do step(m, p, t, tp, 4.6) end
	check(m.ev.leave_stuck == 1 and nst(m).fails == 1 and nst(m).want,
		"F4 stuck on the path counts a failure")
	-- F5 striking ends everything.
	wall_scene()
	m = mob()
	for _ = 1, 8 do step(m, p, t, tp, 4.6) end
	step(m, p, t, tp, 0, true)
	check(nst(m).path == nil and nst(m).fails == 0 and not nst(m).want,
		"F5 striking drops the path, progress")
	-- F6 smoothing: on open ground the steer point is far ahead, not the
	-- next node.
	clear_world()
	set(3, 1, 0, "stone")
	set(3, 2, 0, "stone")
	m = mob()
	p, tp = pos(0, Y, 0), pos(9, Y, 0)
	for _ = 1, 8 do steer = step(m, p, t, tp, 4.6) end
	check(steer and math.abs(steer.x - p.x) + math.abs(steer.z - p.z) > 2,
		"F6 smoothing steers past the next waypoint")
	check(nav.line_walkable(nav.body(m), pos(p.x, 0.5, p.z), steer),
		"F6 the smoothed leg is walkable")
	-- F7 a fixed walk is followed to its end, even with a clear line.
	wall_scene()
	m = mob()
	p = pos(4, Y, 0)
	local goal = pos(10, 0.5, 0)
	for _ = 1, 12 do steer = fstep(m, p, goal, "post", 1.2) end
	check(steer and nst(m).path, "F7 a fixed walk searched after its 1 s window")
	fill(5, 1, -3, 5, 4, 3, "air")
	for _ = 1, 15 do steer = fstep(m, p, goal, "post", 0) end
	check(nst(m).path ~= nil, "F7 a clear line does not end a fixed walk")
	-- F8 more than 2 nodes off the route: searched again.
	wall_scene()
	m = mob()
	p = pos(4, Y, 0)
	for _ = 1, 12 do steer = fstep(m, p, goal, "post", 1.2) end
	local far = pos(p.x - 3, Y, p.z - 3)
	fstep(m, far, goal, "post", 1.2)
	check(m.ev.leave_off_route == 1 and nst(m).want, "F8 off route: search again")
	-- F9 a fixed walk never gives up: three failures return "failed".
	clear_world()
	fill(-2, 1, -2, 2, 3, 2, "fence")
	fill(-1, 1, -1, 1, 3, 1, "air")
	m = mob()
	p = pos(0, Y, 0)
	local fails, gave = 0, false
	for _ = 1, 400 do
		local _, out = fstep(m, p, pos(8, 0.5, 0), "post", 1.2)
		if out == "failed" then fails = fails + 1 end
		if out == "give_up" then gave = true end
	end
	check(fails >= 3 and not gave and m.ev.give_up == nil, "F9 fixed walks count, never give up: " .. fails)
end

-- ---------------------------------------------------------------------------
-- L. Lockout, cap, padding floor, leg limit.
-- ---------------------------------------------------------------------------
do
	-- L1 lockout: a second search waits 1 s in combat.
	clear_world()
	fill(-2, 1, -2, 2, 3, 2, "fence")
	fill(-1, 1, -1, 1, 3, 1, "air")
	local m, t = mob(), target_obj()
	local p, tp = pos(0, Y, 0), pos(6, Y, 0)
	find_calls = {}
	local times = {}
	for _ = 1, 40 do
		local before = #find_calls
		step(m, p, t, tp, 4.6)
		if #find_calls > before then times[#times + 1] = us end
	end
	check(#times >= 2 and times[2] - times[1] >= 1000000,
		"L1 one mob's searches at least 1 s apart in combat")
	-- Fixed: 5 s.
	m = mob()
	find_calls = {}
	times = {}
	for _ = 1, 140 do
		local before = #find_calls
		fstep(m, p, pos(6, 0.5, 0), "post", 1.2)
		if #find_calls > before then times[#times + 1] = us end
	end
	check(#times >= 2 and times[2] - times[1] >= 5000000,
		"L1 5 s apart on a fixed walk")
	-- L2 the cap: 30 stuck mobs at once start at most 20 searches a second.
	clear_world()
	local mobs = {}
	for i = 1, 30 do mobs[i] = {m = mob(), p = pos(0, Y, i * 3)} end
	for i = 1, 30 do fill(-1, 1, i * 3 - 1, 1, 3, i * 3 + 1, "fence") set(0, 1, i * 3, "air") set(0, 2, i * 3, "air") end
	find_calls = {}
	nav.counters.cap_waits = 0
	-- Start after a quiet second of server steps.
	us = us + 10000000
	nav.begin_server_step(1)
	local in_window = {}
	for s = 1, 25 do
		us = us + 100000
		nav.begin_server_step(0.1)
		O.begin_server_step()
		for i = 1, 30 do
			local e = mobs[i]
			nav.combat_step(e.m, e.p, 0.1, t, pos(6, Y, i * 3), 6, false)
			nav.command(e.m, e.p, 4.6)
		end
		in_window[s] = #find_calls
		if s == 10 then mobs.at10 = #find_calls end
	end
	-- Any ten consecutive steps (one second) hold at most 20 searches.
	local worst = 0
	for s = 10, 25 do
		local n = in_window[s] - (in_window[s - 10] or 0)
		if n > worst then worst = n end
	end
	check(worst <= 20, "L2 at most 20 in any one second: " .. worst)
	check(mobs.at10 <= 20 and nav.counters.cap_waits > 0,
		"L2 the cap holds the first second near 20: " .. tostring(mobs.at10))
	check(#find_calls > mobs.at10, "L2 the waiting mobs search in the next second")
	-- L3 the padding floor and the leg limit.
	find_calls = {}
	nav.search(pos(0, 1, 0), pos(3, 1, 0), 1, 1, 6)
	check(find_calls[1].pad == 2, "L3 padding never below 2")
	nav.search(pos(0, 1, 0), pos(3, 1, 0), 0, 1, 6)
	check(find_calls[2].pad == 2, "L3 padding 0 becomes 2")
	check(nav.search(pos(0, 1, 0), pos(33, 1, 0), 6, 1, 6) == nil and #find_calls == 2,
		"L3 a leg over 32 nodes never reaches the engine")
	check(nav.PADDING == 6 and nav.MIN_PADDING == 2 and nav.CAP == 20
		and nav.LOCKOUT.combat == 1 and nav.LOCKOUT.fixed == 5,
		"L3 the calibrated values")
end

-- ---------------------------------------------------------------------------
-- W. Head room and width.
-- ---------------------------------------------------------------------------
do
	-- A wall at x 5 with a 1-high hole on the line and nothing else within
	-- the box: a 1.7 mob's path through the hole is rejected (a failure).
	clear_world()
	fill(5, 1, -20, 5, 4, 20, "stone")
	set(5, 1, 0, "air")
	local m, t = mob(), target_obj()
	local p, tp = pos(4, Y, 0), pos(9, Y, 0)
	for _ = 1, 8 do step(m, p, t, tp, 4.6) end
	check(m.ev.rejected == 1 and nst(m).fails == 1, "W1 head room rejects, counted")
	local wolf = mob({_grug_cbox = {-0.3, -0.01, -0.3, 0.3, 0.84, 0.3}})
	for _ = 1, 8 do step(wolf, p, t, tp, 4.6) end
	check(wolf.ev.found == 1 and nst(wolf).path, "W1 a wolf takes the hole")
	-- W2 a 1.4-wide body: a 1-wide gap is rejected, a 2-wide gap fits with
	-- the body's centre between the two cells.
	fill(5, 1, -20, 5, 4, 20, "stone")
	set(5, 1, 0, "air")
	set(5, 2, 0, "air")
	local bear = mob({_grug_cbox = {-0.7, -0.01, -0.7, 0.7, 1.39, 0.7}})
	for _ = 1, 8 do step(bear, p, t, tp, 4.6) end
	check(bear.ev.rejected == 1, "W2 a 1-wide gap is too narrow for 1.4")
	fill(5, 1, 0, 5, 2, 1, "air")
	local bear2 = mob({_grug_cbox = {-0.7, -0.01, -0.7, 0.7, 1.39, 0.7}})
	local steer
	for _ = 1, 8 do steer = step(bear2, p, t, tp, 4.6) end
	check(bear2.ev.found == 1, "W2 a 2-wide gap fits")
	local through
	for _, w in ipairs(nst(bear2).path) do
		if math.abs(w.x - 5) <= 0.5 then through = w end
	end
	check(through and through.z == 0.5, "W2 steered between the two cells: z " ..
		tostring(through and through.z))
	-- W3 three rejections give up (ruling 19).
	fill(5, 1, 1, 5, 2, 1, "stone")
	local bear3 = mob({_grug_cbox = {-0.7, -0.01, -0.7, 0.7, 1.39, 0.7}})
	local out
	for _ = 1, 120 do
		local _, o = step(bear3, p, t, tp, 4.6)
		if o then out = o break end
	end
	check(out == "give_up" and bear3.ev.rejected == 3, "W3 rejected paths give up")
	-- W4 unknown or unloaded cells are blocked.
	local b = nav.body(mob(), nil)
	check(not nav.line_walkable(b, pos(LIMIT - 3, 0.5, 0), pos(LIMIT + 3, 1, 0)),
		"W4 an unloaded column blocks the line")
	-- W5 the line: steps up to the step height, drops to the fear height,
	-- harmless water for a mob that wades, never lava.
	clear_world()
	set(3, 1, 0, "stone")
	check(nav.line_walkable(b, pos(0, 0.5, 0), pos(6, 1, 0)), "W5 a one-node step")
	set(3, 2, 0, "stone")
	check(not nav.line_walkable(b, pos(0, 0.5, 0), pos(6, 1, 0)), "W5 a two-node wall")
	clear_world()
	fill(3, 0, -1, 4, 0, 1, "air")
	check(nav.line_walkable(b, pos(0, 0.5, 0), pos(6, 1, 0)), "W5 a 1-deep ditch, crossed")
	fill(3, -1, -1, 4, -1, 1, "air")
	check(not nav.line_walkable(b, pos(0, 0.5, 0), pos(6, 1, 0)),
		"W5 2 deep: no way up the far side")
	clear_world()
	fill(3, -5, -3, 12, 0, 3, "air")
	check(nav.line_walkable(b, pos(0, 0.5, 0), pos(8, -5, 0)), "W5 a drop of 6 (fear 6)")
	fill(3, -6, -3, 12, -6, 3, "air")
	check(not nav.line_walkable(b, pos(0, 0.5, 0), pos(8, -6, 0)), "W5 a drop of 7: no")
	clear_world()
	fill(3, -1, -3, 5, 0, 3, "water")
	check(nav.line_walkable(b, pos(0, 0.5, 0), pos(8, 1, 0)), "W5 a floater crosses water")
	local dry = nav.body(mob({floats = false}), nil)
	check(not nav.line_walkable(dry, pos(0, 0.5, 0), pos(8, 1, 0)), "W5 a non-floater does not")
	fill(3, -1, -3, 5, 0, 3, "lava")
	check(not nav.line_walkable(b, pos(0, 0.5, 0), pos(8, 1, 0)), "W5 lava never")
	-- W6 a diagonal corner: both corner cells must be free.
	clear_world()
	set(1, 1, 0, "stone")
	set(1, 2, 0, "stone")
	check(not nav.line_walkable(b, pos(0, 0.5, 0.4), pos(1, 1, 1)),
		"W6 a diagonal past a blocked corner")
end

-- ---------------------------------------------------------------------------
-- G. Give-up, failure count, veto.
-- ---------------------------------------------------------------------------
-- A 2-high fence ring round the target (NV0's fence scene).
local function fence_scene()
	clear_world()
	fill(6, 1, -4, 14, 2, -4, "fence")
	fill(6, 1, 4, 14, 2, 4, "fence")
	fill(6, 1, -3, 6, 2, 3, "fence")
	fill(14, 1, -3, 14, 2, 3, "fence")
end
do
	fence_scene()
	local m, t = mob(), target_obj()
	local p, tp = pos(5, Y, 0), pos(10, Y, 0)
	local out, t0, steps = nil, us, 0
	for _ = 1, 200 do
		steps = steps + 1
		local _, o = step(m, p, t, tp, 4.6)
		if o then out = o break end
	end
	check(out == "give_up" and m.ev.no_path == 3,
		"G1 three failed searches give the (visible) target up")
	local secs = (us - t0) / 1e6
	check(secs > 2 and secs < 6, "G1 within a few seconds: " .. secs)
	check(m.temp.grug_nav == nil, "G1 the state is forgotten")
	-- G2 the dragons only wait.
	fence_scene()
	local dragon = mob({never = true})
	out = nil
	for _ = 1, 300 do
		local _, o = step(dragon, p, t, tp, 4.6)
		if o then out = o end
	end
	check(out == nil and nst(dragon).fails >= 3, "G2 never_give_up only waits")
	-- G3 progress resets the count: two failures, then free with a clear way.
	fence_scene()
	m = mob()
	for _ = 1, 200 do
		step(m, p, t, tp, 4.6)
		if nst(m).fails == 2 then break end
	end
	check(nst(m).fails == 2, "G3 two failures")
	local q = pos(5, Y, -10)
	local away = pos(-10, Y, -10)
	for _ = 1, 8 do
		step(m, q, t, away, 4.6)
		q = walk(q, away, 4.6)
	end
	check(nst(m) and nst(m).fails == 0, "G3 free with a clear line: the count resets")
	-- G4 the count goes on when the target moves inside the ring.
	fence_scene()
	m = mob()
	out = nil
	local k = 0
	for _ = 1, 300 do
		k = k + 1
		local _, o = step(m, p, t, pos(10 + (k % 20 < 10 and 1 or -1), Y, 0), 4.6)
		if o then out = o break end
	end
	check(out == "give_up", "G4 a target moving inside the ring is still given up")
	-- G5 a mob pressed into the fence rounds into the fence cell: its start
	-- moves to the open neighbour, the searches run and count (NV0 F7).
	fence_scene()
	m = mob()
	local pressed = pos(5.55, Y, 0)
	find_calls = {}
	out = nil
	for _ = 1, 200 do
		local _, o = step(m, pressed, t, tp, 4.6)
		if o then out = o break end
	end
	check(#find_calls >= 1 and find_calls[1].from.x == 5, "G5 the start is the open cell")
	check(out == "give_up", "G5 and it gives up")
	-- G6 no open neighbour at all: refused, counted, given up.
	clear_world()
	fill(-1, 1, -1, 1, 3, 1, "fence")
	m = mob()
	out = nil
	for _ = 1, 200 do
		local _, o = step(m, pos(0, Y, 0), t, tp, 4.6)
		if o then out = o break end
	end
	check(out == "give_up" and m.ev.refused == 3, "G6 refusals count to the give-up")
	-- G7 the veto (aggro.lua, cut out): 8 nodes or 15 s.
	local src = read("mods/ENTITIES/grug_mobs/aggro.lua")
	local block = src:match("\n(local GAVE_UP_NODES = %d+.-\nfunction grug_mobs.gave_up_on%(self, player%).-\nend\n)")
	check(block ~= nil, "G7 the give-up block")
	local clock = 100
	local env = {grug_mobs = {leash_reset = function() end},
		grug_core = {mono_time = function() return clock end},
		core = {is_player = function() return true end}}
	local chunk = assert(loadstring(block))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	chunk()
	local G = env.grug_mobs
	local ppos = {x = 0, y = 1, z = 0}
	local player = {get_player_name = function() return "anna" end,
		get_pos = function() return ppos end}
	local gm = {attack = player, stop_attack = function() end}
	G.give_up_target(gm)
	ppos = {x = 5, y = 1, z = 5}
	check(G.gave_up_on(gm, player), "G7 7 nodes away: still ignored")
	clock = 114
	check(G.gave_up_on(gm, player), "G7 after 14 s: still ignored")
	clock = 115.1
	check(not G.gave_up_on(gm, player) and gm.temp.grug_gave_up == nil,
		"G7 after 15 s: a target again")
	clock = 200
	ppos = {x = 0, y = 1, z = 0}
	G.give_up_target(gm)
	ppos = {x = 6, y = 1, z = 6}
	check(not G.gave_up_on(gm, player), "G7 moved 8.5 nodes: a target again")
end

-- ---------------------------------------------------------------------------
-- P. The physics box (ruling 20).
-- ---------------------------------------------------------------------------
do
	local tall = {-0.42, 0, -0.42, 0.42, 2.38, 0.42}
	local cut = O.physics_box(tall, {})
	check(cut ~= tall and cut[5] == 1.95 and cut[2] == 0 and cut[1] == -0.42
		and tall[5] == 2.38, "P1 2.38 tall: 1.95, the base untouched")
	local golem = {-0.6, -2, -0.6, 0.6, 1.4, 0.6}
	check(O.physics_box(golem, {})[5] == -2 + 1.95, "P2 from the box's own floor")
	local ooze = {-1.02, -0.01, -1.02, 1.02, 2.03, 1.02}
	check(O.physics_box(ooze, {})[5] == -0.01 + 1.95, "P3 the bog ooze")
	local guard = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
	check(O.physics_box(guard, {}) == guard, "P4 2 nodes or less unchanged")
	check(O.physics_box(tall, {keep_flying = true}) == tall
		and O.physics_box(tall, {fly = true}) == tall, "P5 fliers keep their box")
	local body = nav.body({_grug_cbox = cut, initial_properties = {stepheight = 1.1},
		jump_height = 4, fear_height = 4})
	check(body.head == 2, "P6 a cut mob needs 2 cells of head room")
	local api = read("mods/ENTITIES/mobs/api.lua")
	local _, n = api:gsub("grug_obstacle%.physics_box%(", "")
	check(n == 3, "P7 every collision box api.lua sets goes through it: " .. n)
end

-- ---------------------------------------------------------------------------
-- A. The replaced pieces are gone (ruling 17).
-- ---------------------------------------------------------------------------
do
	local api = read("mods/ENTITIES/mobs/api.lua")
	for _, gone in ipairs({"function mob_class:smart_mobs", "function mob_class:apply_path",
			"local function path_height_blocked", "stuck_timer", "self.path.",
			"choose_sidestep", "close_path_due", "mob_pathfinding_stuck_timeout",
			"mob_pathfinding_searchdistance"}) do
		check(api:find(gone, 1, true) == nil, "A1 api.lua no longer has " .. gone)
	end
	local ob = read("mods/ENTITIES/mobs/grug_obstacle.lua")
	for _, gone in ipairs({"sidestep", "close_path_due", "keep_path", "path_backoff"}) do
		check(ob:find(gone, 1, true) == nil, "A2 grug_obstacle.lua no longer has " .. gone)
	end
	local _, finds = read("mods/ENTITIES/mobs/grug_nav.lua"):gsub("core%.find_path%(", "")
	check(finds == 1, "A3 grug_nav has one engine search")
end

print("R42 NV1 PORTABLE PASS checks=" .. checks)
