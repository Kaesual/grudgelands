-- Round 74 lane TRAIL portable test (round74-plan.md §3.1, §4 TRAIL): the evade
-- seam and the evader's trail. Loads the REAL mobs/grug_nav.lua,
-- mobs/grug_obstacle.lua, grug_mobs/patrol.lua and grug_mobs/aggro.lua on the small
-- world model of tools/r42_nv2 (a node grid with the engine pathfinder's model, a box
-- that collides with nodes, steps up one node and falls, the cliff guard and the
-- fence stop of mobs_redo; here also the nodes under and at the feet). A chase is
-- scripted (the mob is moved along a course in attack state, leash_tick every step);
-- the evade runs on the physics. Checks:
--   S  the seam: grug_mobs.register_evade_guide; a fixture guide answering for one
--      mob only is walked to (its own walk), the others walk home; guides are asked
--      in registration order, before the trail; a guided mob leaves its trail, so
--      a guide's later nil walks home; the arrival at home stays;
--   T  the recording: the first point where the mob leaves its arrival area, then
--      one every 8 nodes walked; none mid-jump or swimming (put off to the next
--      sample); a detour (the navigation's path to the target) drops a point where
--      it began and one every 3 nodes; the loop cut keeps the short thread, a
--      detour's close points stay; at most 10 points, the corners kept; cleared
--      back inside the arrival area, when idle, at the arrival; kept while fleeing;
--      none for a flier;
--   W  the walk back: a guard pulled round the end of a long wall resets at its
--      leash and walks home over its trail with no teleport, where the walk
--      straight home (the same pull, the trail wiped) needs the 40 s teleport; a
--      point on a ledge the mob came down is skipped once its leg fails, and the
--      mob still gets home.
-- Prints the comparison (time home with and without the trail).
-- Usage (repo root): luajit tools/r74_trail/portable_test.lua [REPO]
-- Prints "R74 TRAIL PORTABLE PASS checks=<n>" or raises.
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
local floor, sqrt, abs = math.floor, math.sqrt, math.abs
local function noop() end

-- ---------------------------------------------------------------------------
-- The world: a node grid (unset is air, at y <= 0 stone) and the engine.
-- ---------------------------------------------------------------------------
local us = 1000000
local world = {}
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

local logs, players = {}, {}
local find_calls = {}
core = {
	registered_nodes = {
		air = {name = "air", walkable = false},
		stone = {name = "stone", walkable = true},
		tree = {name = "tree", walkable = true},
		fence = {name = "fence", walkable = true},
		water = {name = "water", walkable = false, liquidtype = "source"},
	},
	get_us_time = function() return us end,
	log = function(_, text) logs[#logs + 1] = text end,
	pos_to_string = function(p) return ("(%g,%g,%g)"):format(p.x, p.y, p.z) end,
	get_objects_inside_radius = function(pos, radius)
		local out = {}
		for _, p in ipairs(players) do
			local dx, dz = p.pos.x - pos.x, p.pos.z - pos.z
			if dx * dx + dz * dz <= radius * radius then out[#out + 1] = p end
		end
		return out
	end,
	is_player = function(o) return type(o) == "table" and o.player == true end,
}
function core.get_node_or_nil(pos)
	if abs(pos.x) > LIMIT or abs(pos.z) > LIMIT then return nil end
	return {name = name_at(pos.x, pos.y, pos.z)}
end
local function walkable(x, y, z)
	local def = core.registered_nodes[name_at(x, y, z)]
	return not def or def.walkable == true
end
vector = {new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end}

-- The engine pathfinder's model (tools/r42_nv1): ends must not be walkable;
-- the start walks down to the ground up to max_drop, the goal up to max_jump.
function core.find_path(from, to, pad, jump, drop)
	find_calls[#find_calls + 1] = {pad = pad, from = vector.new(from), to = vector.new(to)}
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

-- ---------------------------------------------------------------------------
-- The real modules.
-- ---------------------------------------------------------------------------
local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
nav.init({obstacle = O, max_jump = 4, max_drop = 6})
nav.on_event = function(self, kind)
	self.ev = self.ev or {}
	self.ev[kind] = (self.ev[kind] or 0) + 1
end
mobs = {grug_obstacle = O, grug_nav = nav}

local placed = {}
grug_core = {
	mono_time = function() return us / 1000000 end,
	recheck_switch = noop,
	prune_engagement = noop,
	clear_threat = noop,
}
grug_mobs = {
	-- A standing y (a cell) or a feet position: the feet on that cell's floor.
	place_on_ground = function(object, p)
		placed[#placed + 1] = {x = p.x, y = p.y, z = p.z}
		object.pos = {x = p.x, y = floor(p.y + 0.5) - 0.49, z = p.z}
		object.vel = {x = 0, y = 0, z = 0}
	end,
	idle_health_tick = noop,
	roam_avoid_tick = noop,
}
dofile(repo .. "/mods/ENTITIES/grug_mobs/npc_doors.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/patrol.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")

-- Mobs: mobs_redo's methods the walks use, the holds, and a body that moves.
-- ---------------------------------------------------------------------------
local DT = 0.1
local mob_class = {}
function mob_class:yaw_to_pos(target)
	local p = self.object.pos
	local yaw = math.atan2(-(target.x - p.x), target.z - p.z)
	self.object.yaw = yaw
	return yaw
end
function mob_class:set_velocity(v)
	if self.order == "stand" then v = 0 end
	local yaw = self.object.yaw
	self.object.vel = {x = -math.sin(yaw) * v, y = 0, z = math.cos(yaw) * v}
end
function mob_class:set_animation() end
function mob_class:stop_attack() self.attack = nil; self.state = "stand" end

local function new_object(pos)
	local o = {pos = vector.new(pos), vel = {x = 0, y = 0, z = 0}, yaw = 0}
	function o:get_pos() return self.valid ~= false and vector.new(self.pos) or nil end
	function o:get_velocity() return vector.new(self.vel) end
	function o:is_player() return false end
	return o
end

-- fields: walk speed etc.; the body is a guard's (0.6 wide, 1.7 tall).
local function mob(x, z, fields)
	local m = setmetatable({name = "test:mob", state = "stand", temp = {},
		walk_velocity = 1.2, run_velocity = 4.6, jump_height = 4,
		fear_height = 4, initial_properties = {stepheight = 1.1},
		_grug_cbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}, nt = 0, st = 0},
		{__index = mob_class})
	for k, v in pairs(fields or {}) do m[k] = v end
	m.object = new_object({x = x, y = 0.51, z = z})
	function m.object:get_luaentity() return m end
	return m
end

local function cells(lo, hi)
	return floor(lo + 0.5), floor(hi + 0.5 - 1e-6)
end
local function box_free(m, x, feet, z)
	local b = m._grug_cbox
	local x1, x2 = cells(x + b[1], x + b[4])
	local z1, z2 = cells(z + b[3], z + b[6])
	local y1, y2 = cells(feet, feet + b[5] - b[2])
	for cx = x1, x2 do
		for cz = z1, z2 do
			for cy = y1, y2 do
				if walkable(cx, cy, cz) then return false end
			end
		end
	end
	return true
end
local function supported(m, x, feet, z)
	local b = m._grug_cbox
	local x1, x2 = cells(x + b[1], x + b[4])
	local z1, z2 = cells(z + b[3], z + b[6])
	local row = floor(feet + 0.5) - 1
	for cx = x1, x2 do
		for cz = z1, z2 do
			if walkable(cx, row, cz) then return true end
		end
	end
	return false
end
local function physics(m)
	local o = m.object
	local p = o.pos
	local feet = p.y + m._grug_cbox[2]
	for _, axis in ipairs({"x", "z"}) do
		local q = {x = p.x, z = p.z}
		q[axis] = q[axis] + o.vel[axis] * DT
		if box_free(m, q.x, feet, q.z) then
			p.x, p.z = q.x, q.z
		elseif box_free(m, q.x, feet + 1, q.z) and box_free(m, p.x, feet + 1, p.z) then
			p.x, p.z, feet = q.x, q.z, feet + 1
		end
	end
	local n = 0
	while not supported(m, p.x, feet, p.z) and n < 20 do
		feet, n = feet - 1, n + 1
	end
	p.y = feet - m._grug_cbox[2]
end

-- What mobs_redo sees ahead (get_nodes, is_at_cliff: the ambient guard).
local function ahead(m)
	local o = m.object
	local r = m._grug_cbox[4] + 0.5
	local x = floor(o.pos.x - math.sin(o.yaw) * r + 0.5)
	local z = floor(o.pos.z + math.cos(o.yaw) * r + 0.5)
	return x, floor(o.pos.y + m._grug_cbox[2] + 0.5), z
end
local function holds(m)
	local x, fr, z = ahead(m)
	local name = name_at(x, fr, z)
	m.facing_fence = (name:find("fence") or name:find("gate") or name:find("wall")) ~= nil
	m.at_cliff = (m.state == "stand" or m.state == "walk")
		and not (walkable(x, fr, z) or walkable(x, fr - 1, z) or walkable(x, fr - 2, z))
end

-- What mobs_redo's get_nodes reads under and at the feet.
local function stand_nodes(m)
	local p = m.object.pos
	local feet = p.y + m._grug_cbox[2]
	local x, z = floor(p.x + 0.5), floor(p.z + 0.5)
	m.standing_on = name_at(x, floor(feet - 0.25 + 0.5), z)
	m.standing_in = name_at(x, floor(feet + 0.25 + 0.5), z)
end

-- One server step of one mob (and anything `each` moves), in mobs_redo's
-- order: the 0.25 s node pass with the cliff guard, do_custom, the 1 s
-- do_states pass (the walk state's stop at a fence or a cliff, and a random
-- stop when the test asks for one), the movement.
local function step(m, each)
	us = us + floor(DT * 1e6)
	nav.begin_server_step(DT)
	O.begin_server_step()
	if each then each() end
	m.nt = m.nt + DT
	if m.nt >= 0.25 - 1e-9 then
		m.nt = 0
		holds(m)
		if m.at_cliff then m:set_velocity(0) end
	end
	stand_nodes(m)
	local result = m.do_custom(m, DT)
	if result ~= false then
		m.st = m.st + DT
		if m.st >= 1 - 1e-9 then
			m.st = 0
			if m.state == "walk" and (m.facing_fence or m.at_cliff
					or (m.random_stop and m.random_stop())) then
				m:set_velocity(0)
				m.state = "stand"
			end
		end
	end
	physics(m)
end
local function run(m, seconds, done, each)
	for i = 1, floor(seconds / DT + 0.5) do
		step(m, each)
		if done and done(m) then return i * DT end
	end
end
local function hdist(m, x, z)
	local p = m.object.pos
	return sqrt((p.x - x) * (p.x - x) + (p.z - z) * (p.z - z))
end
local function fresh()
	world, find_calls, logs, placed, players = {}, {}, {}, {}, {}
	us = us + 100 * 1000000 -- every lockout and negative-cache wait is over
end
-- A wall across the x axis at x = wx, z from -h to h, two nodes high.
local function wall(wx, h, name)
	fill(wx, 1, -h, wx, 2, h, name or "stone")
end
-- A closed ring of walls round (cx, cz), radius r, two nodes high.
local function pen(cx, cz, r)
	fill(cx - r, 1, cz - r, cx + r, 2, cz - r, "stone")
	fill(cx - r, 1, cz + r, cx + r, 2, cz + r, "stone")
	fill(cx - r, 1, cz - r, cx - r, 2, cz + r, "stone")
	fill(cx + r, 1, cz - r, cx + r, 2, cz + r, "stone")
end
local function logged(text)
	for _, line in ipairs(logs) do
		if line:find(text, 1, true) then return true end
	end
	return false
end


vector.distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return sqrt(dx * dx + dy * dy + dz * dz)
end

-- ---------------------------------------------------------------------------
-- Helpers: the surface, a scripted chase, the trail.
-- ---------------------------------------------------------------------------
local TARGET = {player = true, is_player = function() return true end,
	get_pos = function() return {x = 0, y = 0, z = 0} end, get_hp = function() return 20 end,
	get_player_name = function() return "p" end}

-- The feet of a mob standing at (x, z): on the highest walkable node below y 12.
local function surface(x, z)
	local cx, cz = floor(x + 0.5), floor(z + 0.5)
	for y = 12, -5, -1 do
		if walkable(cx, y, cz) then return y + 0.51 end
	end
	return 0.51
end

local function trail(m) return m.temp.grug_evade_trail end
local function points(m)
	local tr = trail(m)
	return tr and #tr or 0
end

-- A chaser: an npc without a chase leash (the leash rules are W's), home at (hx, hz),
-- standing at (x, z).
local function chaser(x, z, hx, hz, fields)
	local m = mob(x, z, fields)
	m.type = m.type or "npc"
	if m._grug_no_leash == nil then m._grug_no_leash = true end
	m._grug_home = {x = hx, y = surface(hx, hz), z = hz}
	m.object.pos.y = surface(x, z)
	m.do_custom = function(self, dtime) grug_mobs.leash_tick(self, dtime) end
	return m
end

-- Moves `m` in attack state along `course` ({x, z} corners) at `speed`, leash_tick
-- every step. `each(m, i)` may change the step (the vertical speed, the navigation
-- state). Stops at the course's end or once the mob evades.
local function chase(m, course, speed, each)
	m.attack, m.state = m.attack or TARGET, "attack"
	local o = m.object
	local i = 1
	while course[i] do
		local c = course[i]
		local dx, dz = c.x - o.pos.x, c.z - o.pos.z
		local d = sqrt(dx * dx + dz * dz)
		local s = speed * DT
		if d <= s then
			o.pos.x, o.pos.z = c.x, c.z
			i = i + 1
		else
			o.pos.x, o.pos.z = o.pos.x + dx / d * s, o.pos.z + dz / d * s
		end
		o.pos.y = surface(o.pos.x, o.pos.z)
		o.vel = {x = d > 0 and dx / d * speed or 0, y = 0, z = d > 0 and dz / d * speed or 0}
		if m.attack then m.state = "attack" end
		if each then each(m, i) end
		us = us + floor(DT * 1e6)
		nav.begin_server_step(DT)
		O.begin_server_step()
		stand_nodes(m)
		m.do_custom(m, DT)
		if m.temp.grug_evading then return end
	end
end

-- The evade from where the mob stands: the evade speed (init.lua), the evade state.
local function start_evade(m)
	m.attack, m.state = nil, "stand"
	m.object.vel = {x = 0, y = 0, z = 0}
	m.temp.grug_evading = m.temp.grug_evading or {started = us / 1000000}
	m.walk_velocity = 6.9
end

local function evade_home(m, seconds)
	return run(m, seconds or 60, function(s) return s.temp.grug_evading == nil end)
end

-- ---------------------------------------------------------------------------
-- S. The seam.
-- ---------------------------------------------------------------------------
local calls = {}
local GUIDE_A = {x = 0, y = 0.51, z = 20}
check(type(grug_mobs.register_evade_guide) == "function", "S1 grug_mobs.register_evade_guide")
grug_mobs.register_evade_guide(function(self, pos, home)
	calls[#calls + 1] = {guide = "a", self = self, pos = pos, home = home}
	if self.guide_a then return GUIDE_A end
	return nil
end)
grug_mobs.register_evade_guide(function(self, pos, home)
	calls[#calls + 1] = {guide = "b", self = self}
	if self.guide_b then return {x = 0, z = -20} end
	return nil
end)
do
	fresh()
	-- S2 a mob the first guide answers for: it walks to the guide's point.
	local m = chaser(0, 0, 30, 0, {guide_a = true})
	start_evade(m)
	calls = {}
	run(m, 2)
	check(#calls >= 1 and calls[1].guide == "a" and calls[1].self == m
		and calls[1].home == m._grug_home and calls[1].pos.x ~= nil,
		"S2 the guide is asked with (self, pos, home)")
	check(m.temp.grug_walk and m.temp.grug_walk.key == "evade_guide1"
		and m.temp.grug_walk.owner == "evade", "S2 ...its point is a walk of its own")
	check(m.object.pos.z > 3 and abs(m.object.pos.x) < 1, "S2 ...and the mob walks there ("
		.. m.object.pos.x .. ", " .. m.object.pos.z .. ")")
	local only_a = true
	for _, c in ipairs(calls) do only_a = only_a and c.guide == "a" end
	check(only_a, "S3 an answer ends the asking: the second guide is not asked")
	-- S3 a mob only the second guide answers for: asked in order, the second walked.
	fresh()
	m = chaser(0, 0, 30, 0, {guide_b = true})
	start_evade(m)
	calls = {}
	run(m, 1.05)
	check(#calls >= 2 and calls[1].guide == "a" and calls[2].guide == "b",
		"S3 the guides are asked in registration order")
	check(m.temp.grug_walk and m.temp.grug_walk.key == "evade_guide2", "S3 ...the second walked")
	-- S4 a mob no guide answers for walks home as before.
	fresh()
	m = chaser(0, 0, 30, 0)
	start_evade(m)
	local t = evade_home(m)
	check(m.temp.grug_walk == nil and t ~= nil and #placed == 0 and hdist(m, 30, 0) <= 4,
		"S4 no answer: the walk home (" .. tostring(t) .. " s)")
	-- S5 the arrival stays the evade's: a guided mob near home is home.
	fresh()
	m = chaser(2, 0, 0, 0, {guide_a = true})
	start_evade(m)
	calls = {}
	run(m, 1.05)
	check(m.temp.grug_evading == nil and #calls == 0, "S5 the arrival at home comes first")
	-- S6 the guide comes before the trail.
	fresh()
	m = chaser(0, 0, 0, 0, {guide_a = true})
	chase(m, {{x = 30, z = 0}}, 4)
	check(points(m) >= 3, "S6 a trail was recorded")
	start_evade(m)
	run(m, 1.05)
	check(m.temp.grug_walk and m.temp.grug_walk.key == "evade_guide1", "S6 ...the guide walks first")
	check(trail(m) == nil, "S6 ...and the guided mob leaves its trail")
	-- S7 the guide answers, then has none (off its grid): the mob walks home, not
	-- back to the trail's newest point behind it.
	fresh()
	m = chaser(0, 0, 0, 0, {guide_a = true})
	chase(m, {{x = 30, z = 0}}, 4)
	check(points(m) >= 3, "S7 a trail was recorded")
	start_evade(m)
	run(m, 2.05)
	check(m.temp.grug_walk and m.temp.grug_walk.key == "evade_guide1", "S7 the guide walks")
	m.guide_a = nil
	run(m, 1.05)
	check(m.temp.grug_walk and m.temp.grug_walk.key == "evade", "S7 ...then no answer: the walk home ("
		.. tostring(m.temp.grug_walk and m.temp.grug_walk.key) .. ")")
end

-- ---------------------------------------------------------------------------
-- T. The recording.
-- ---------------------------------------------------------------------------
local function spacings(m)
	local tr, out = trail(m), {}
	for i = 2, #tr do
		local a, b = tr[i - 1], tr[i]
		out[#out + 1] = sqrt((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z))
	end
	return out
end
do
	-- T1 a straight chase: the first point outside the arrival area (4 nodes round
	-- the post), then one every 8 nodes walked.
	fresh()
	local m = chaser(0, 0, 0, 0)
	chase(m, {{x = 60, z = 0}}, 4)
	local tr = trail(m)
	check(tr and tr[1].x > 4 and tr[1].x <= 8.5, "T1 the first point where the mob left its area ("
		.. (tr and tr[1].x or -1) .. ")")
	local ok = true
	for _, d in ipairs(spacings(m)) do ok = ok and d >= 8 - 1e-6 and d < 12 end
	check(ok and #tr >= 6 and #tr <= 8, "T1 ...then one every 8 nodes walked (" .. #tr .. " points)")
	check(abs(tr[1].y - 0.51) < 1e-6, "T1 ...at the feet")
	-- T2 none mid-jump or swimming: put off to the next sample on the ground.
	fresh()
	fill(20, 1, -3, 30, 1, 3, "water")
	m = chaser(0, 0, 0, 0)
	chase(m, {{x = 60, z = 0}}, 4, function(s)
		local x = s.object.pos.x
		if x > 40 and x < 50 then s.object.vel.y = 3 end
	end)
	tr = trail(m)
	local wet, air = 0, 0
	for _, p in ipairs(tr) do
		if p.x >= 19.5 and p.x <= 30.5 then wet = wet + 1 end
		if p.x > 40 and p.x < 50 then air = air + 1 end
	end
	check(wet == 0 and air == 0, "T2 no point in the water nor mid-jump")
	local after = false
	for _, p in ipairs(tr) do
		if p.x >= 30.5 and p.x <= 35 then after = true end
	end
	check(after, "T2 ...the drop put off to the first sample on the ground after the water")
	-- T3 the loop cut: out, round and back near an older point.
	fresh()
	m = chaser(0, 0, 0, 0)
	chase(m, {{x = 30, z = 0}, {x = 30, z = 20}, {x = 14, z = 20}, {x = 14, z = 3},
		{x = 14, z = -20}}, 4)
	tr = trail(m)
	local far = 0
	for _, p in ipairs(tr) do
		if p.x > 18 or p.z > 6 then far = far + 1 end
	end
	check(far == 0 and #tr >= 3, "T3 kited round and back: the loop is cut (" .. #tr .. " points left)")
	local d = 0
	for _, s in ipairs(spacings(m)) do if s > d then d = s end end
	check(d <= 14, "T3 ...the thread's legs stay short (" .. d .. ")")
	-- T4 a detour: a point where it began, then one every 3 nodes; after it, 8 again.
	fresh()
	m = chaser(0, 0, 0, 0)
	local began
	chase(m, {{x = 60, z = 0}}, 4, function(s)
		local x = s.object.pos.x
		if x >= 21 and x <= 36 then
			s.temp.grug_nav = s.temp.grug_nav or {fails = 0}
			s.temp.grug_nav.target, s.temp.grug_nav.path = s.attack, {{x = 0, y = 0, z = 0}}
			began = began or x
		elseif s.temp.grug_nav then
			s.temp.grug_nav = nil
		end
	end)
	tr = trail(m)
	local at_start, inside = false, 0
	for _, p in ipairs(tr) do
		if p.x >= began and p.x <= began + 4.5 then at_start = true end
		if p.x > began and p.x <= 40 then inside = inside + 1 end
	end
	check(at_start, "T4 a point where the detour began (" .. began .. ")")
	check(inside >= 4, "T4 ...and one every 3 nodes on it (" .. inside .. ")")
	local dense, wide = true, true
	for i = 2, #tr do
		local s = tr[i].x - tr[i - 1].x
		-- (the leash slot samples every 1.1 s here: 4.4 nodes)
		if tr[i].x > began + 4.5 and tr[i].x <= 40 then dense = dense and s < 5 end
		if tr[i - 1].x > 41 then wide = wide and s >= 8 - 1e-6 end
	end
	check(dense and wide, "T4 ...one per sample on it, 8 nodes again after it")
	-- T5 a detour's close points stay: a hairpin round a short wall's end, both legs
	-- about 5 nodes apart, walked less than 18 between them: no cut.
	fresh()
	m = chaser(0, 0, 0, 0)
	chase(m, {{x = 12, z = 0}, {x = 20, z = 0}, {x = 20, z = 5}, {x = 12, z = 5},
		{x = 12, z = 30}}, 4, function(s, i)
		if i >= 2 and i <= 4 then
			s.temp.grug_nav = {fails = 0, target = s.attack, path = {{x = 0, y = 0, z = 0}}}
		else
			s.temp.grug_nav = nil
		end
	end)
	local out_leg, turn, back_leg = 0, 0, 0
	for _, p in ipairs(trail(m)) do
		if p.z == 0 and p.x > 12.5 and p.x < 18.5 then out_leg = out_leg + 1 end
		if p.x >= 18.5 then turn = turn + 1 end
		if p.z >= 4.5 and p.x < 18.5 then back_leg = back_leg + 1 end
	end
	check(out_leg >= 1 and turn >= 1 and back_leg >= 1, "T5 a detour's close points are not cut ("
		.. out_leg .. " out, " .. turn .. " at the turn, " .. back_leg .. " back)")
	-- T6 at most 10 points, the corners kept.
	fresh()
	m = chaser(0, 0, 0, 0)
	local seen_max = 0
	chase(m, {{x = 100, z = 0}, {x = 100, z = 100}, {x = 0, z = 100}}, 4, function(s)
		if points(s) > seen_max then seen_max = points(s) end
	end)
	tr = trail(m)
	local function near(px, pz)
		for _, p in ipairs(tr) do
			-- (a sample a second before or after the corner)
			if (p.x - px) * (p.x - px) + (p.z - pz) * (p.z - pz) <= 7 * 7 then return true end
		end
		return false
	end
	check(seen_max <= 10 and #tr == 10, "T6 at most 10 points (" .. seen_max .. ")")
	check(near(100, 0) and near(100, 100), "T6 ...the corners kept")
	check(tr[1].x <= 8.5 and tr[1].z == 0, "T6 ...and the first point")
	-- T7 cleared back inside the arrival area.
	fresh()
	m = chaser(0, 0, 0, 0)
	chase(m, {{x = 20, z = 0}}, 4)
	check(points(m) >= 2, "T7 a trail")
	chase(m, {{x = 2, z = 0}, {x = 2, z = -3}, {x = 2, z = 0}}, 4)
	check(trail(m) == nil, "T7 ...cleared back at the post")
	-- T8 kept while fleeing, cleared when idle.
	chase(m, {{x = 20, z = 0}}, 4)
	local n = points(m)
	m.state = "runaway"
	run(m, 2.05)
	check(points(m) == n, "T8 kept while it flees")
	m.state, m.attack = "stand", nil
	run(m, 1.05)
	check(trail(m) == nil, "T8 ...cleared once it is idle without an evade")
	-- T9 none for a flier.
	fresh()
	m = chaser(0, 0, 0, 0, {fly = true})
	chase(m, {{x = 30, z = 0}}, 4)
	check(trail(m) == nil, "T9 no trail for a flier")
	-- T10 a free mob records outside its wander radius only.
	fresh()
	m = chaser(0, 0, 0, 0, {type = "animal", _grug_no_leash = false,
		_grug_damage_pursuit_candidate = true})
	chase(m, {{x = 60, z = 0}}, 4)
	tr = trail(m)
	check(tr and tr[1].x > grug_mobs.WANDER_RADIUS and tr[1].x <= grug_mobs.WANDER_RADIUS + 4.5,
		"T10 a free mob: from its wander radius on (" .. (tr and tr[1].x or -1) .. ")")
end

-- ---------------------------------------------------------------------------
-- W. The walk back.
-- ---------------------------------------------------------------------------
-- A wall at x = 6 from z = -40 to 33, two nodes high; the guard's post at (0, 0); it
-- is pulled north round the wall's end and south again behind it, then east, until
-- its leash (40 from where the chase began) resets it.
local COURSE = {{x = 0, z = 38}, {x = 12, z = 38}, {x = 12, z = 0}, {x = 60, z = 0}}
local function pulled(keep_trail)
	fresh()
	fill(6, 1, -40, 6, 2, 33, "stone")
	local m = chaser(0, 1, 0, 0, {_grug_no_leash = false})
	chase(m, COURSE, 4.6, function(s)
		s.temp.grug_last_contact = us / 1000000 -- hits keep the contact clock fresh
	end)
	check(m.temp.grug_evading ~= nil, "W the leash reset starts the evade")
	if not keep_trail then m.temp.grug_evade_trail = nil end
	local n = points(m)
	start_evade(m)
	return m, n
end
local with_t, without_t
do
	-- W1 over the trail: home round the wall's end, no teleport.
	local m, n = pulled(true)
	check(n >= 5, "W1 the reset kept the trail (" .. n .. " points)")
	local t = evade_home(m)
	with_t = t
	check(t ~= nil and #placed == 0 and hdist(m, 0, 0) <= 4,
		"W1 over the trail: home with no teleport (" .. tostring(t) .. " s)")
	check(trail(m) == nil and m.temp.grug_walk == nil, "W1 ...the trail and the walk cleared")
	-- W2 the same pull walking straight home: the 40 s teleport.
	m = pulled(false)
	t = evade_home(m)
	without_t = t
	check(t ~= nil and #placed == 1, "W2 straight home: the teleport (" .. tostring(t) .. " s)")
	-- W3 a ledge it came down: a platform 3 high at x 14..22, z -4..4; the chase
	-- crossed it eastward and dropped off its east edge.
	fresh()
	fill(14, 1, -4, 22, 3, 4, "stone")
	m = chaser(0, 0, 0, 0)
	chase(m, {{x = 40, z = 0}}, 4)
	local on_top = 0
	for _, p in ipairs(trail(m)) do
		if p.y > 3 then on_top = on_top + 1 end
	end
	check(on_top >= 1, "W3 points on the platform (" .. on_top .. ")")
	start_evade(m)
	local skipped = 0
	t = run(m, 60, function(s)
		return s.temp.grug_evading == nil
	end, function()
		local tr = trail(m)
		local top = tr and tr[#tr]
		if top and top.y > 3 and not m.top_seen then m.top_seen = top end
		if m.top_seen and (not tr or tr[#tr] ~= m.top_seen) then
			if m.object.pos.y < 3 then skipped = skipped + 1 end
			m.top_seen = nil
		end
	end)
	check(skipped >= 1, "W3 a point on the ledge is skipped once its leg fails (" .. skipped .. ")")
	check(t ~= nil and #placed == 0 and hdist(m, 0, 0) <= 4,
		"W3 ...and the mob still gets home (" .. tostring(t) .. " s)")
end

print(("R74 TRAIL comparison: the pull round the wall, home in %s s over the trail, "
	.. "%s s walking straight home (teleport)"):format(tostring(with_t), tostring(without_t)))
print("R74 TRAIL PORTABLE PASS checks=" .. checks)
