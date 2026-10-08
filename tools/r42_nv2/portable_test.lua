-- Round 42 lane NV2 portable test (round42-plan.md §4.3, rulings 2, 4, 5,
-- 8, 10, 11, 17, 18): the fixed walks on the shared navigation. Loads the
-- REAL mobs/grug_nav.lua, mobs/grug_obstacle.lua, grug_mobs/patrol.lua and
-- grug_mobs/aggro.lua, and cuts the REAL post tick (start_npcs.lua), royal
-- follow (bosses.lua) and rift boss's way home (rift.lua) out of their
-- files. A small world model drives real mobs: a node grid with the engine
-- pathfinder's model (tools/r42_nv1's: four directions, a walkable node
-- blocks, steps of max_jump, drops of max_drop, the padded box exclusive on
-- its positive edge), a box that collides with nodes, steps up one node and
-- falls, and the mobs_redo holds a walker meets: the ambient cliff guard
-- (velocity 0 every 0.25 s at a drop of 1.5) and do_states' once-a-second
-- stop in front of a node named fence, gate or wall. Checks:
--   P  patrols (route_tick): a waypoint behind a wall is reached round it;
--      a walker pushed off its path searches again; a waypoint that cannot
--      be reached is skipped after three failed searches; the second one in
--      a row is snapped to out of sight, skipped while watched; a named
--      rare only skips;
--   O  posts (start_post_tick, also a king's seat): the post behind a row
--      of trees is reached and the guard stands facing its way; a walker
--      the cliff guard holds at a ledge is stuck and walks down a path; a
--      post that cannot be reached is snapped to after six failures, out of
--      sight only;
--   H  held walkers: a walker stood by do_states in front of a fence is
--      measured with the speed its nudge commanded (stuck); one stood by
--      mobs_redo's random stop is not measured;
--   E  the evade (aggro.lua): blocked, it searches a point 6 nodes toward
--      home (within 2 of its height) and runs home round the wall, steered
--      every step on the path; the 40 s snap stays, also while watched;
--   R  the royal follow (bosses.lua): an idle leader is a fixed goal
--      followed round a wall; a fighting leader is tracked (combat_step, run
--      speed) and a path is left when he moved 4 nodes from its end; stuck
--      20 s without a path the guard is snapped to him, also while watched;
--   B  the rift boss: idle, it walks back to its spot round an obstacle;
--      evading, it leaves the way home to the evade;
--   F  review fixes: a walker heading freely for a goal beyond 32 nodes ends
--      its stuck episode (no failures pile up, no skip); a royal guard
--      running after a fighting leader far away is never "stuck"; the
--      ground of a route point without y is the floor nearest the walker
--      (under a lintel, not on it) and start-town route points carry their
--      socket's y; a refused snap is retried 10 s later however rarely the
--      caller asks;
--   A  the old pieces are gone: no path_nudge, no core.find_path outside the
--      navigation, no stall clock (NV3 removed the villagers' last one).
-- Usage (repo root): luajit tools/r42_nv2/portable_test.lua [REPO]
-- Prints "R42 NV2 PORTABLE PASS checks=<n>" or raises.
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

-- A local function block of a source file, loaded with `env`.
local function cut(path, from, to, env, tail)
	local src = read(path)
	local a = src:find(from, 1, true)
	check(a ~= nil, "cut: " .. from .. " in " .. path)
	local _, e = src:find(to, a, true)
	check(e ~= nil, "cut: end of " .. from .. " in " .. path)
	local chunk = assert(loadstring(src:sub(a, e) .. (tail or ""), "=" .. path))
	setfenv(chunk, setmetatable(env or {}, {__index = _G}))
	return chunk()
end
local function constant(path, name)
	local value = read(path):match("\nlocal " .. name .. " = ([%d%.]+)")
	check(value ~= nil, "constant " .. name .. " in " .. path)
	return tonumber(value)
end

local NPCS = "mods/ENTITIES/grug_mobs/start_npcs.lua"
local post_env = {POST_TICK = constant(NPCS, "POST_TICK"),
	POST_SLACK = constant(NPCS, "POST_SLACK"),
	POST_SNAP_AFTER = constant(NPCS, "POST_SNAP_AFTER")}
cut(NPCS, "function grug_mobs.start_post_tick(self, dtime)", "\nend\n", post_env)

local royal_list = {}
local BOSSES = "mods/ENTITIES/grug_mobs/bosses.lua"
local royal_guard_tick = cut(BOSSES, "local ROYAL_FOLLOW_DISTANCE = 5",
	"\tforget_follow(self, t.grug_royal_leader)\nend\n",
	{royal_objects = function() return royal_list end}, "return royal_guard_tick\n")

local RIFT = "mods/ENTITIES/grug_mobs/rift.lua"
local go_home = cut(RIFT, "local function go_home(self, t, pos, dtime)", "\nend\n",
	{HOME_REACH = constant(RIFT, "HOME_REACH")}, "return go_home\n")

-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- P. Patrols (route_tick).
-- ---------------------------------------------------------------------------
local function patroller(x, z, points, snap, fields)
	local m = mob(x, z, fields)
	m.route = {points = points, wp = 1}
	m.do_custom = function(self, dtime)
		grug_mobs.route_tick(self, dtime, self.route.points, self.route, "wp", snap)
	end
	return m
end
do
	-- P1 a waypoint behind a wall: stuck, one local search, round it.
	fresh()
	wall(5, 3)
	local m = patroller(0, 0, {{x = 12, z = 0}, {x = 0, z = 0}}, true)
	local t = run(m, 40, function(s) return s.route.wp == 2 end)
	check(t ~= nil, "P1 the waypoint behind the wall is reached")
	check(m.ev and m.ev.stuck and m.ev.found, "P1 ...stuck at the wall, a path found")
	check(#find_calls >= 1 and #find_calls <= 2, "P1 ...with one or two searches: " .. #find_calls)
	check(find_calls[1].pad == nav.PADDING, "P1 ...in the padded local box")
	check(#placed == 0 and not logged("could not reach"), "P1 ...walked, no skip, no snap")
	-- The way round was steered every step: never more than a node past a
	-- corner of the wall (the box stays out of the wall's own cells).
	-- P2 knocked off the path: more than 2 nodes off it, it searches again.
	fresh()
	wall(5, 3)
	m = patroller(0, 0, {{x = 12, z = 0}, {x = 0, z = 0}}, true)
	run(m, 20, function(s) return s.temp.grug_nav and s.temp.grug_nav.path end)
	check(m.temp.grug_nav and m.temp.grug_nav.path, "P2 following a path")
	local calls = #find_calls
	m.object.pos.x = m.object.pos.x - 3.5
	m.object.pos.z = m.object.pos.z + (m.object.pos.z >= 0 and 3 or -3)
	run(m, 1)
	check(m.ev.leave_off_route == 1, "P2 off the route: the path is left")
	run(m, 30, function(s) return s.route.wp == 2 end)
	check(#find_calls > calls, "P2 ...and searched again")
	check(m.route.wp == 2, "P2 ...and the waypoint reached")
	-- P3 a waypoint nobody can reach: three failed searches, the next one.
	fresh()
	pen(14, 0, 5)
	m = patroller(0, 0, {{x = 14, z = 0}, {x = 0, z = 30}, {x = -20, z = 0}}, true)
	t = run(m, 60, function(s) return s.route.wp == 2 end)
	check(t ~= nil and t > 8, "P3 the waypoint in the pen is skipped (" .. tostring(t) .. " s)")
	check(m.ev.no_path >= 3 or (m.ev.no_path or 0) + (m.ev.refused or 0) >= 3,
		"P3 ...after three failed searches")
	check(logged("could not reach its waypoint (3 failed searches in a row"),
		"P3 ...reported")
	check(#placed == 0, "P3 ...not snapped (the first in a row)")
	-- P4 the second unreachable waypoint in a row is snapped to, out of sight.
	fresh()
	pen(14, 0, 5)
	pen(0, 30, 5)
	m = patroller(0, 0, {{x = 14, z = 0}, {x = 0, z = 30}, {x = -20, z = 0}}, true)
	t = run(m, 120, function() return #placed > 0 end)
	check(t ~= nil and m.route.wp == 2, "P4 the second unreachable waypoint is snapped to")
	check(hdist(m, 0, 30) < 0.01, "P4 ...onto it")
	check(logged("was stuck on two waypoints in a row and was moved to"), "P4 ...reported")
	run(m, 2)
	check(m.route.wp == 3 and m.temp.grug_route_skips == nil, "P4 ...arrived: the next leg starts clean")
	-- P5 watched: never snapped, the waypoint is skipped.
	fresh()
	pen(14, 0, 5)
	pen(0, 30, 5)
	players[1] = {player = true, pos = {x = 0, y = 1, z = 12}, is_player = function() return true end}
	m = patroller(0, 0, {{x = 14, z = 0}, {x = 0, z = 30}, {x = -20, z = 0}}, true)
	t = run(m, 120, function(s) return s.route.wp == 3 end)
	check(t ~= nil and #placed == 0, "P5 watched: skipped, never snapped")
	-- P6 a named rare (no snap): it only skips.
	fresh()
	pen(14, 0, 5)
	pen(0, 30, 5)
	m = patroller(0, 0, {{x = 14, z = 0}, {x = 0, z = 30}, {x = -20, z = 0}}, nil)
	t = run(m, 120, function(s) return s.route.wp == 3 end)
	check(t ~= nil and #placed == 0, "P6 a rare skips both and is never snapped")
	-- P7 a fight owns the movement: the walk is dropped, the navigation is
	-- the fight's.
	fresh()
	wall(5, 3)
	m = patroller(0, 0, {{x = 12, z = 0}, {x = 0, z = 0}}, true)
	run(m, 20, function(s) return s.temp.grug_nav and s.temp.grug_nav.path end)
	m.attack, m.state = {}, "attack"
	m.temp.grug_nav.target = m.attack
	run(m, 1.1)
	check(m.temp.grug_walk == nil and m.temp.grug_nav and m.temp.grug_nav.target == m.attack,
		"P7 a fight: the walk is dropped, the fight's navigation stays")
end

-- ---------------------------------------------------------------------------
-- O. Posts (start_post_tick).
-- ---------------------------------------------------------------------------
local function post_guard(x, z, px, py, pz, fields)
	local m = mob(x, z, fields)
	m._grug_post_x, m._grug_post_z, m._grug_post_yaw = px, pz, 1.5
	m._grug_home = {x = px, y = py, z = pz}
	m.do_custom = function(self, dtime) grug_mobs.start_post_tick(self, dtime) end
	return m
end
grug_mobs.face_yaw = function(self, yaw) self.object.yaw = yaw; self.faced = yaw end
do
	-- O1 a row of trees between the guard and its post.
	fresh()
	for z = -3, 3 do set(6, 1, z, "tree"); set(6, 2, z, "tree") end
	local m = post_guard(0, 0, 12, 1, 0)
	local t = run(m, 40, function(s) return s.faced ~= nil end)
	check(t ~= nil and hdist(m, 12, 0) <= 2, "O1 the post behind the trees is reached")
	check(m.ev and m.ev.found, "O1 ...round the row on a path")
	check(m.state == "stand" and m.faced == 1.5, "O1 ...and the guard stands facing its way")
	check(m.temp.grug_walk == nil and m.temp.grug_nav == nil, "O1 ...the walk and its navigation are over")
	-- O2 a post below a ledge of two: the cliff guard holds the straight walk
	-- (mobs_redo's 1.5 for idle walkers); the walk is stuck and walks down.
	fresh()
	fill(6, -1, -20, 30, 0, 20, "air")
	m = post_guard(0, 0, 12, -1, 0)
	t = run(m, 40, function(s) return s.faced ~= nil end)
	check(m.ev and m.ev.stuck, "O2 a walker the cliff guard holds is stuck")
	check(t ~= nil and m.object.pos.y < 0, "O2 ...and walks down to its post")
	-- O3 a post nobody can reach: after six failed searches, out of sight.
	fresh()
	pen(12, 0, 2)
	m = post_guard(0, 0, 12, 1, 0)
	t = run(m, 120, function() return #placed > 0 end)
	check(t ~= nil and hdist(m, 12, 0) < 0.01, "O3 an unreachable post is snapped to")
	check(logged("was stuck after 6 failed searches in a row"), "O3 ...after six failed searches")
	check(t > 20, "O3 ...not at once (" .. tostring(t) .. " s)")
	fresh()
	pen(12, 0, 2)
	players[1] = {player = true, pos = {x = 0, y = 1, z = 0}, is_player = function() return true end}
	m = post_guard(0, 0, 12, 1, 0)
	run(m, 120)
	check(#placed == 0, "O3 ...never while watched")
	-- O4 the evade owns the walk while it runs: the post tick does nothing.
	fresh()
	m = post_guard(0, 0, 12, 1, 0)
	m.temp.grug_evading = {started = 0}
	run(m, 2)
	check(m.temp.grug_walk == nil and hdist(m, 0, 0) < 0.01, "O4 evading: the post tick leaves it alone")
end

-- ---------------------------------------------------------------------------
-- H. Held walkers: the commanded speed, and mobs_redo's random stop.
-- ---------------------------------------------------------------------------
do
	-- H1 a walker do_states stands in front of a fence, every second (a node
	-- named fence holds it before it touches it): stuck, it searches.
	fresh()
	fill(3, 1, -6, 3, 1, 6, "fence")
	local m = post_guard(0, 0, 10, 1, 0)
	m.do_custom = function(self, dtime)
		grug_mobs.start_post_tick(self, dtime)
		-- The fence is held from 1.5 nodes off (a guard that never reaches it).
		local p = self.object.pos
		if p.x > 1.6 then self.object.vel.x = math.min(self.object.vel.x, 0) end
	end
	run(m, 6)
	check(m.ev and m.ev.stuck, "H1 a walker held in front of a fence is stuck")
	check(#find_calls >= 1, "H1 ...and searches")
	-- H2 mobs_redo's own random stop is no hold: a walker it stands still
	-- for whole seconds on open ground is never stuck.
	fresh()
	m = post_guard(0, 0, 40, 1, 0)
	local n = 0
	m.random_stop = function() n = n + 1; return n % 2 == 1 end
	m.st = 0.95 -- do_states runs right after each nudge
	run(m, 12)
	check(not (m.ev and m.ev.stuck), "H2 a random stop is never stuck")
	check(n >= 10, "H2 ...however often it came")
	-- H3 the same stop in front of a fence is a hold.
	fresh()
	set(1, 1, 0, "fence")
	m = post_guard(0, 0, 40, 1, 0)
	m.object.yaw = -math.pi / 2
	m.do_custom = function(self, dtime)
		grug_mobs.start_post_tick(self, dtime)
		self.object.vel = {x = 0, y = 0, z = 0} -- it never gets a step
	end
	run(m, 4)
	check(m.ev and m.ev.stuck, "H3 the stop in front of a fence is measured")
end

-- ---------------------------------------------------------------------------
-- E. The evade (aggro.lua evade_tick through leash_tick).
-- ---------------------------------------------------------------------------
local function evader(x, z, hx, hz, fields)
	local m = mob(x, z, fields)
	m.type, m._grug_no_leash = "npc", true
	m.walk_velocity = 6.9 -- the evade speed (init.lua tick_speed_effects)
	m._grug_home = {x = hx, y = 0.51, z = hz}
	m.temp.grug_evading = {started = us / 1000000}
	m.do_custom = function(self, dtime) grug_mobs.leash_tick(self, dtime) end
	return m
end
do
	-- E1 a wall across the way home: a point 6 nodes toward home, round it.
	fresh()
	wall(4, 3)
	local m = evader(0, 0, 24, 0)
	local stepped = 0
	local t = run(m, 40, function(s)
		if s.temp.grug_nav and s.temp.grug_nav.path then stepped = stepped + 1 end
		return s.temp.grug_evading == nil
	end)
	check(t ~= nil and t < 20 and #placed == 0, "E1 the evader runs home round the wall (" .. tostring(t) .. " s)")
	check(#find_calls >= 1, "E1 ...with a local search")
	local c = find_calls[1]
	local dx, dz = c.to.x - c.from.x, c.to.z - c.from.z
	local d = sqrt(dx * dx + dz * dz)
	check(d >= 5 and d <= 7.5, "E1 ...to a point about 6 nodes off (" .. d .. ")")
	check(c.to.x > c.from.x and abs(c.to.y - c.from.y) <= 2, "E1 ...toward home, within 2 of its height")
	check(m.temp.grug_walk == nil, "E1 ...home: the walk is over")
	check(stepped >= 5, "E1 ...the path steered every step (" .. stepped .. " steps)")
	-- E2 home near: searched for directly.
	fresh()
	wall(2, 3)
	m = evader(0, 0, 5, 0)
	m._grug_home.x = 6
	run(m, 20, function(s) return s.temp.grug_evading == nil end)
	check(#find_calls >= 1 and find_calls[1].to.x == 6, "E2 home within 6: searched for itself")
	-- E3 no way out: the 40 s snap stays, also while watched.
	fresh()
	pen(0, 0, 3)
	players[1] = {player = true, pos = {x = 1, y = 1, z = 1}, is_player = function() return true end}
	m = evader(0, 0, 30, 0)
	t = run(m, 60, function(s) return s.temp.grug_evading == nil end)
	check(t ~= nil and t >= 39 and t <= 42, "E3 the evade snap still fires after 40 s (" .. tostring(t) .. ")")
	check(#placed == 1 and hdist(m, 30, 0) < 0.01, "E3 ...home, also while watched")
	check(m.temp.grug_walk == nil, "E3 ...the walk is over")
end

-- ---------------------------------------------------------------------------
-- R. The royal follow (bosses.lua royal_guard_tick).
-- ---------------------------------------------------------------------------
local function leader_at(x, z, fields)
	local l = {_grug_royal_king = true, state = "stand", temp = {},
		_grug_cbox = {-0.34, 0, -0.34, 0.34, 1.94, 0.34}}
	for k, v in pairs(fields or {}) do l[k] = v end
	l.object = new_object({x = x, y = 0.51, z = z})
	function l.object:get_luaentity() return l end
	royal_list = {l}
	return l
end
local function royal(x, z)
	local m = mob(x, z, {_grug_royal_race = "human"})
	m.do_custom = function(self, dtime)
		return royal_guard_tick(noop, self, dtime, "king:test")
	end
	return m
end
do
	-- R1 an idle leader behind a wall: a fixed goal, followed round it.
	fresh()
	wall(5, 3)
	local l = leader_at(12, 0)
	local m = royal(0, 0)
	local fixed
	local t = run(m, 40, function(s)
		local nst = s.temp.grug_nav
		if nst and nst.target == "royal_leader" and nst.path then fixed = true end
		return hdist(s, 12, 0) <= 5
	end)
	check(t ~= nil and #placed == 0, "R1 the guard walks to its idle leader round the wall")
	check(fixed, "R1 ...on a fixed walk followed to its end")
	run(m, 1.1)
	check(not m.temp.grug_royal_follow_active, "R1 ...and stops within the follow distance")
	-- R2 a fighting leader: tracked like a chase, at run speed; he moves away
	-- from the path's planned end: the path is left.
	fresh()
	wall(5, 3)
	l = leader_at(12, 0, {attack = {}, state = "attack"})
	m = royal(0, 0)
	local tracked, top = false, 0
	run(m, 20, function(s)
		local nst = s.temp.grug_nav
		if nst and nst.target == l.object and nst.path then tracked = true end
		local v = s.object.vel
		top = math.max(top, sqrt(v.x * v.x + v.z * v.z))
		return tracked
	end)
	check(tracked, "R2 a fighting leader is tracked (the chase's follower)")
	check(abs(top - 4.6) < 0.01, "R2 ...at run speed (" .. top .. ")")
	l.object.pos.z = l.object.pos.z + 6
	run(m, 0.3)
	check(m.ev.leave_drift == 1, "R2 ...he moved 4 nodes from the planned end: the path is left")
	-- R3 a leader nobody can reach: 20 s stuck without a path, the snap,
	-- also while watched.
	fresh()
	pen(14, 0, 6)
	players[1] = {player = true, pos = {x = 0, y = 1, z = 0}, is_player = function() return true end}
	l = leader_at(14, 0)
	m = royal(0, 0)
	t = run(m, 60, function() return #placed > 0 end)
	check(t ~= nil and t >= 20 and hdist(m, 14, 0) < 0.01,
		"R3 stuck 20 s without a path: snapped to the leader (" .. tostring(t) .. " s)")
	check(not m.temp.grug_royal_follow_active and m.temp.grug_nav == nil, "R3 ...the follow starts over")
	-- R4 a hit mid-follow is dropped and the guard walks on at once.
	fresh()
	l = leader_at(20, 0)
	m = royal(0, 0)
	run(m, 1.1)
	m.attack, m.state = {}, "attack"
	run(m, 0.1)
	check(m.attack == nil and m.state == "walk", "R4 a hit mid-follow is dropped, the walk goes on")
end

-- ---------------------------------------------------------------------------
-- B. The rift boss's way home (rift.lua go_home).
-- ---------------------------------------------------------------------------
do
	fresh()
	wall(6, 3)
	local m = mob(0, 0, {_grug_cbox = {-0.8, 0, -0.8, 0.8, 1.95, 0.8}})
	m._grug_home = {x = 14, y = 1, z = 0}
	m.do_custom = function(self, dtime)
		go_home(self, self.temp, self.object:get_pos(), dtime)
	end
	local t = run(m, 60, function(s) return hdist(s, 14, 0) <= 4 end)
	check(t ~= nil and m.ev and m.ev.found, "B1 the idle boss (1.6 wide) walks home round the wall")
	run(m, 1.1)
	check(m.temp.grug_walk == nil, "B1 ...at its spot the walk is over")
	fresh()
	m = mob(0, 0)
	m._grug_home = {x = 14, y = 1, z = 0}
	m.temp.grug_evading = {started = 0}
	m.do_custom = function(self, dtime)
		go_home(self, self.temp, self.object:get_pos(), dtime)
	end
	run(m, 3)
	check(m.temp.grug_walk == nil and hdist(m, 0, 0) < 0.01, "B2 evading: the way home is the evade's")
end

-- ---------------------------------------------------------------------------
-- F. Review fixes.
-- ---------------------------------------------------------------------------
do
	-- F1 a far waypoint (60 nodes): an episode with two failures and a locked
	-- search ends after a free window; the waypoint is kept.
	fresh()
	local m = patroller(0, 0, {{x = 60, z = 0}, {x = 0, z = 0}}, true)
	run(m, 1.5)
	local nst = m.temp.grug_nav
	check(nst and nst.target == 1, "F1 walking to the far waypoint")
	nst.want, nst.fails, nst.lock = true, 2, us / 1000000 + 1000
	run(m, 3)
	nst = m.temp.grug_nav
	check(nst and not nst.want and nst.fails == 0, "F1 walking freely toward it ends the episode")
	check(m.route.wp == 1 and #find_calls == 0, "F1 ...no search, no skip")
	-- F2 a royal guard running after a fighting leader 40 nodes off, with an
	-- episode open: its stuck clock never runs, no snap.
	fresh()
	local l = leader_at(40, 0, {attack = {}, state = "attack"})
	m = royal(0, 0)
	local away = function() l.object.pos.x = l.object.pos.x + 0.4 end
	run(m, 1.5, nil, away)
	nst = m.temp.grug_nav
	check(nst and nst.target == l.object, "F2 tracking the far leader")
	nst.want, nst.fails, nst.lock = true, 1, us / 1000000 + 1000
	local top = 0
	run(m, 25, function(s)
		top = math.max(top, s.temp.grug_royal_stuck or 0)
	end, away)
	check(#placed == 0 and top < 1.5, "F2 running freely is never stuck (" .. top .. " s)")
	-- F3 a route point without y under a lintel: the floor below it.
	fresh()
	set(12, 3, 0, "stone")
	m = patroller(0, 0, {{x = 12, z = 0}, {x = 0, z = 0}}, true)
	run(m, 1.1)
	check(m.temp.grug_walk and m.temp.grug_walk.y == 1, "F3 the floor under the lintel, not its top")
	local npcs = read(NPCS)
	check(npcs:find("y = socket.pos.y, z = socket.pos.z}", 1, true)
		and npcs:find("y = loop[index].y,", 1, true), "F3 start-town route points carry their y")
	-- F4 a refused snap is retried after 10 s on the clock, however rarely.
	fresh()
	players[1] = {player = true, pos = {x = 0, y = 1, z = 0}, is_player = function() return true end}
	m = mob(0, 0)
	check(not grug_mobs.snap_try(m, m.object:get_pos(), 5, 0, 1, "test"), "F4 watched: refused")
	players = {}
	us = us + 5 * 1000000
	check(not grug_mobs.snap_try(m, m.object:get_pos(), 5, 0, 1, "test"), "F4 ...5 s later still waiting")
	us = us + 6 * 1000000
	check(grug_mobs.snap_try(m, m.object:get_pos(), 5, 0, 1, "test"), "F4 ...11 s later: snapped")
end

-- ---------------------------------------------------------------------------
-- A. The old pieces are gone (ruling 17).
-- ---------------------------------------------------------------------------
do
	local dir = "mods/ENTITIES/grug_mobs/"
	for _, file in ipairs({"patrol.lua", "start_npcs.lua", "bosses.lua", "aggro.lua",
			"rift.lua", "rares.lua", "guard.lua"}) do
		local src = read(dir .. file)
		check(not src:find("path_nudge", 1, true), "A " .. file .. ": no path_nudge")
		check(not src:find("core.find_path", 1, true), "A " .. file .. ": no own core.find_path")
		check(not src:find("stall_clock(", 1, true) or file == "patrol.lua",
			"A " .. file .. ": no stall clock")
		check(not src:find("smart_mobs", 1, true), "A " .. file .. ": no smart_mobs comment")
	end
	-- Round 42 NV3 replaced the villagers' stall clock (tools/r42_nv3).
	check(read(dir .. "start_villagers.lua"):find("stall_clock(", 1, true) == nil,
		"A the villagers' stall clock is gone (NV3)")
end

print("R42 NV2 PORTABLE PASS checks=" .. checks)
