-- Round 42 lane NV3 portable test (round42-plan.md §4.4, rulings 5, 12-14,
-- 16-18): the settlement walkers, the route cache and the capital street
-- patrols. Loads the REAL mobs/grug_nav.lua, mobs/grug_obstacle.lua,
-- grug_mobs/patrol.lua and grug_mobs/routes.lua (its street reader on a road
-- layout written by the REAL wp40/road_layout.lua), and cuts the REAL amble
-- and work ticks (start_villagers.lua) and the rings (start_npcs.lua) out of
-- their files. The world model is tools/r42_nv2's: a node grid with the
-- engine pathfinder's model (four directions, a walkable node blocks, the
-- padded box exclusive on its positive edge), a box that collides, steps up
-- one node and falls. Checks:
--   C  the cache: a leg is searched on first use and reused by the next
--      walker (no second search); a leg with no route is remembered (no
--      search storm) and the walker takes its next spot at once; a long leg
--      is split (no search longer than 32 nodes, padding 6), into as many
--      pieces as it takes (failures spend a plan, not pieces); a split point
--      on an obstacle moves beside the line; legs are per body class;
--   S  capital patrols over the streets: a long leg is "to the street"
--      (a search), the street corners, "from the street" (a search); a leg
--      whose ends are far from every street is the split straight leg;
--   W  following: the walker arrives on its cached route; pushed off it, it
--      walks back to the route's next corner; a village walker (no cache)
--      follows its spot as a fixed target round a trunk; a fight drops the
--      leg; a start-town patrol's second round asks nothing;
--   U  unloaded is "later": a leg across the unloaded edge waits and is
--      built once loaded; a pending walk is a fixed walk (round a wall); a
--      walker away from an enclosed no-route start walks to its goal, and so
--      does one beside an enclosed stand-in start;
--   N  the next-spot stage: a village spot in a pen is given up after three
--      failed searches;
--   R  rings: a walker whose composition has one spot borrows the nearest
--      spots of the settlement (ruling 16); a static resident does not; a
--      claim re-derives an old ring of one and old patrol points without y;
--   Z  residents that never leave their spot ask nothing: a ring-of-one
--      resident and a work resident walk back straight, the work resident
--      is snapped home after 30 s out of sight only;
--   A  the old pieces are gone: no stall clock, no own core.find_path.
-- Usage (repo root): luajit tools/r42_nv3/portable_test.lua [REPO]
-- Prints "R42 NV3 PORTABLE PASS checks=<n>" or raises.
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
local LIMIT = 300 -- beyond |x|, |z| the map is not loaded
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
	get_modpath = function(name)
		check(name == "grug_mapgen", "get_modpath only for the road layout")
		return repo .. "/mods/MAPGEN/grug_mapgen"
	end,
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
grug_mobs = {
	place_on_ground = function(object, p)
		placed[#placed + 1] = {x = p.x, y = p.y, z = p.z}
		object.pos = {x = p.x, y = floor(p.y + 0.5) - 0.49, z = p.z}
		object.vel = {x = 0, y = 0, z = 0}
	end,
	start_npc_claim = function() return true end,
}
-- The road layout the runtime holds (set per street test).
grug_mapgen = {wp40 = {}}
dofile(repo .. "/mods/ENTITIES/grug_mobs/patrol.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/routes.lua")
local routes = grug_mobs.routes
grug_mobs.face_yaw = function(self, yaw) self.object.yaw = yaw; self.faced = yaw end

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

local VILLAGERS = "mods/ENTITIES/grug_mobs/start_villagers.lua"
local amble_env = {spot_taken = function() return false end}
for _, name in ipairs({"SPOT_ARRIVED", "AMBLE_TICK", "SPOT_GIVE_UP_AFTER"}) do
	amble_env[name] = constant(VILLAGERS, name)
end
do
	local src = read(VILLAGERS)
	local a, b = src:match("\nlocal DWELL_MIN, DWELL_MAX = (%d+), (%d+)")
	local c, d = src:match("\nlocal STATIC_DWELL_MIN, STATIC_DWELL_MAX = (%d+), (%d+)")
	check(a and c, "the dwell constants")
	amble_env.DWELL_MIN, amble_env.DWELL_MAX = tonumber(a), tonumber(b)
	amble_env.STATIC_DWELL_MIN, amble_env.STATIC_DWELL_MAX = tonumber(c), tonumber(d)
end
local amble_tick = cut(VILLAGERS, "local function next_spot(self, spots, index)",
	"\tself._grug_idle_dwell = nil\nend\n", amble_env, "return amble_tick\n")
local work_env = {ACTIVITY = {smith = {anim = "work"}},
	watched = function() return false end}
for _, name in ipairs({"WORK_TICK", "WORK_SLACK", "WORK_STALL_SNAP", "SWEEP_SPAN"}) do
	work_env[name] = constant(VILLAGERS, name)
end
local work_tick = cut(VILLAGERS, "local function work_tick(self, dtime)",
	"\treturn false\nend\n", work_env, "return work_tick\n")

local NPCS = "mods/ENTITIES/grug_mobs/start_npcs.lua"
local ring_env = {WALK_RADIUS = constant(NPCS, "WALK_RADIUS"),
	WALK_MIN_RING = constant(NPCS, "WALK_MIN_RING"), by_key = {}}
local _, bounded_spots = cut(NPCS,
	"local function bounded_spots(group, home_index, walker, others)",
	"then route.wp = 1 end\n\tend\nend\n", ring_env,
	"return idle_ring, bounded_spots\n")

-- ---------------------------------------------------------------------------
-- Mobs: mobs_redo's methods the walks use, and a body that moves.
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
	local yaw = self.object.yaw
	self.object.vel = {x = -math.sin(yaw) * v, y = 0, z = math.cos(yaw) * v}
	self.velocity = v
end
function mob_class:set_animation() end

local function new_object(pos)
	local o = {pos = vector.new(pos), vel = {x = 0, y = 0, z = 0}, yaw = 0}
	function o:get_pos() return vector.new(self.pos) end
	function o:get_velocity() return vector.new(self.vel) end
	function o:is_player() return false end
	return o
end

-- A villager's body (0.6 wide, 1.7 tall, never jumps) by default.
local function mob(x, z, fields)
	local m = setmetatable({name = "test:villager", state = "stand", temp = {},
		walk_velocity = 1.1, jump_height = 0, fear_height = 4,
		initial_properties = {stepheight = 1.1},
		_grug_cbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}, {__index = mob_class})
	for k, v in pairs(fields or {}) do m[k] = v end
	m.object = new_object({x = x, y = 0.51, z = z})
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

local function step(m)
	us = us + floor(DT * 1e6)
	nav.begin_server_step(DT)
	O.begin_server_step()
	m.do_custom(m, DT)
	physics(m)
end
local function run(m, seconds, done)
	for i = 1, floor(seconds / DT + 0.5) do
		step(m)
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
local function pen(cx, cz, r)
	fill(cx - r, 1, cz - r, cx + r, 2, cz - r, "stone")
	fill(cx - r, 1, cz + r, cx + r, 2, cz + r, "stone")
	fill(cx - r, 1, cz - r, cx - r, 2, cz + r, "stone")
	fill(cx + r, 1, cz - r, cx + r, 2, cz + r, "stone")
end
local function trunk(x, z) set(x, 1, z, "tree"); set(x, 2, z, "tree"); set(x, 3, z, "tree") end
local function longest_call()
	local top = 0
	for _, c in ipairs(find_calls) do
		local dx, dz = c.to.x - c.from.x, c.to.z - c.from.z
		top = math.max(top, sqrt(dx * dx + dz * dz))
	end
	return top
end
local function all_padded()
	for _, c in ipairs(find_calls) do
		if c.pad ~= nav.PADDING then return false end
	end
	return true
end

-- A walker of settlement `key` with its ring (spots carry their y).
local settlement_n = 0
local function new_settlement(kind)
	settlement_n = settlement_n + 1
	local k = "test_" .. kind .. "_" .. settlement_n
	grug_mobs.route_settlement(k, kind, {x = 0, y = 0, z = 0})
	return k
end
local function walker(x, z, settlement, spots, index, fields)
	local m = mob(x, z, fields)
	m._grug_start, m._grug_walker = settlement, true
	m._grug_idle_spots, m._grug_idle_spot = spots, index or 1
	m.do_custom = amble_tick
	return m
end
local function spot(x, z) return {x = x, y = 1, z = z, yaw = 0} end
local function arrived(m)
	return m._grug_idle_dwell ~= nil
end

-- ---------------------------------------------------------------------------
-- C. The cache.
-- ---------------------------------------------------------------------------
do
	-- C1 first use: one search, the walker arrives round a trunk.
	fresh()
	local town = new_settlement("start")
	trunk(10, 0)
	local spots = {spot(0, 0), spot(20, 0)}
	local m = walker(0, 0, town, spots, 2)
	m._grug_idle_from = 1
	local t = run(m, 40, arrived)
	check(t ~= nil and hdist(m, 20, 0) < 1.6, "C1 the walker arrives round the trunk")
	check(#find_calls == 1 and find_calls[1].pad == nav.PADDING,
		"C1 ...with one bounded search: " .. #find_calls)
	local st = grug_mobs.route_cache_stats(town)
	check(st.legs == 1 and st.ok == 1 and st.none == 0 and st.searches == 1,
		"C1 ...remembered as one route")
	check(st.corners >= 2, "C1 ...as corner points round the trunk (" .. st.corners .. ")")
	-- C2 the next walker on the same leg asks nothing.
	local m2 = walker(0, 0, town, spots, 2)
	m2._grug_idle_from = 1
	t = run(m2, 40, arrived)
	check(t ~= nil and #find_calls == 1, "C2 a second walker reuses the route")
	check(m2.ev == nil or m2.ev.found == nil, "C2 ...no local search either")
	-- C3 a spot in a pen: no route, remembered; the next spot at once.
	fresh()
	local town3 = new_settlement("start")
	pen(20, 0, 3)
	spots = {spot(0, 0), spot(20, 0), spot(0, 12)}
	m = walker(0, 0, town3, spots, 2)
	m._grug_idle_from = 1
	run(m, 3)
	st = grug_mobs.route_cache_stats(town3)
	check(st.none == 1 and m._grug_idle_spot == 3, "C3 no route: the next spot at once")
	local calls = #find_calls
	check(calls >= 1 and calls <= routes.MAX_FAILS, "C3 ...after a bounded build: " .. calls)
	t = run(m, 30, arrived)
	check(t ~= nil, "C3 ...which is reached")
	calls = #find_calls
	m._grug_idle_dwell, m._grug_idle_spot, m._grug_idle_from = nil, 2, 1
	m.object.pos = {x = 0, y = 0.51, z = 0}
	run(m, 3)
	check(#find_calls == calls and m._grug_idle_spot == 3,
		"C3 the remembered no-route leg searches nothing again")
	-- C4 a long leg is split: no search longer than 32 nodes.
	fresh()
	local town4 = new_settlement("start")
	fill(30, 1, -4, 30, 2, 4, "stone")
	spots = {spot(0, 0), spot(60, 0)}
	m = walker(0, 0, town4, spots, 2)
	m._grug_idle_from = 1
	t = run(m, 120, arrived)
	check(t ~= nil and hdist(m, 60, 0) < 1.6, "C4 a 60-node leg is walked")
	check(#find_calls >= 3 and longest_call() <= routes.SPLIT + 0.01 and all_padded(),
		"C4 ...in pieces of at most " .. routes.SPLIT .. " nodes, padding 6 (" ..
		#find_calls .. " searches, longest " .. longest_call() .. ")")
	-- C4b a leg of many pieces: failures, not pieces, spend a plan.
	fresh()
	local town4b = new_settlement("start")
	fill(80, 1, -4, 80, 2, 4, "stone")
	spots = {spot(0, 0), spot(170, 0)}
	m = walker(0, 0, town4b, spots, 2)
	m._grug_idle_from = 1
	t = run(m, 240, arrived)
	st = grug_mobs.route_cache_stats(town4b)
	check(t ~= nil and st.ok == 1 and st.searches >= 8,
		"C4b a 170-node leg in " .. st.searches .. " pieces is walked")
	-- C5 a split point on a pillar: the candidate beside the line.
	fresh()
	local town5 = new_settlement("start")
	fill(19, 1, -1, 21, 4, 1, "stone")
	spots = {spot(0, 0), spot(40, 0)}
	m = walker(0, 0, town5, spots, 2)
	m._grug_idle_from = 1
	t = run(m, 90, arrived)
	st = grug_mobs.route_cache_stats(town5)
	check(t ~= nil and st.ok == 1 and st.searches == 2,
		"C5 the split point moves off the pillar (searches " .. st.searches .. ")")
	-- C6 legs are per body class: a 3-high body builds its own.
	local tall = walker(0, 0, town5, spots, 2,
		{_grug_cbox = {-0.3, 0, -0.3, 0.3, 2.4, 0.3}, name = "test:tall"})
	tall._grug_idle_from = 1
	run(tall, 2)
	check(grug_mobs.route_cache_stats(town5).legs == 2, "C6 a taller body has its own leg")
end

-- ---------------------------------------------------------------------------
-- S. Capital patrols over the streets.
-- ---------------------------------------------------------------------------
-- A road layout the way the planner writes it (real serializer): streets at
-- one-node spacing on the 1/128 lattice, R the surface (feet one above).
local roads_mod = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/road_layout.lua")
local function street(id, kind, pts)
	local X, Z, RQ, cls = {}, {}, {}, {}
	for i, p in ipairs(pts) do X[i], Z[i], RQ[i], cls[i] = p[1], p[2], 0, "G" end
	return {id = id, kind = kind, a = "-", b = "-", X = X, Z = Z, RQ = RQ, cls = cls}
end
local function line(x1, z1, x2, z2)
	local out, n = {}, math.max(abs(x2 - x1), abs(z2 - z1))
	for i = 0, n do out[#out + 1] = {x1 + (x2 - x1) * i / n, z1 + (z2 - z1) * i / n} end
	return out
end
local function patroller(x, z, settlement, points)
	local m = mob(x, z, {name = "test:guard", walk_velocity = 1.2, jump_height = 4})
	m._grug_start = settlement
	m.route = {points = points, wp = 1}
	m.do_custom = function(self, dtime)
		grug_mobs.route_tick(self, dtime, self.route.points, self.route, "wp", true,
			self._grug_start)
	end
	return m
end
do
	-- An L of streets: an avenue along z = 0 (x 0..80), a lane along x = 80
	-- (z 0..80) meeting it; a block of houses fills the inside of the L, so
	-- the straight line between the two patrol points is walled off.
	local layout = {roads = {
		street(1, "avenue", line(0, 0, 80, 0)),
		street(2, "lane", line(80, 0, 80, 80)),
		street(3, "primary", line(0, -100, 0, -200)), -- the network: ignored
	}}
	grug_mapgen.wp40.road_layout_text = roads_mod.serialize(layout)
	fresh()
	fill(5, 1, 5, 75, 3, 75, "stone")
	local capital = new_settlement("capital")
	-- S1 a long patrol leg: to the street, along it, from it.
	local a, b = {x = 6, y = 1, z = -8}, {x = 88, y = 1, z = 70}
	local m = patroller(6, -8, capital, {a, b})
	m.route.wp = 2
	m.temp.grug_route_from = 1
	local leg_calls
	local t = run(m, 300, function(s)
		if s.route.wp == 2 then leg_calls = #find_calls end
		return s.route.wp == 1
	end)
	local st = grug_mobs.route_cache_stats(capital)
	check(st.street_roads == 2 and st.street_stops >= 4,
		"S1 the capital's two streets, joined (" .. tostring(st.street_stops) .. " stops)")
	check(t ~= nil, "S1 the patrol reaches the far waypoint")
	check(st.street_legs >= 1 and leg_calls == 2,
		"S1 ...over the streets with two searches (" .. tostring(leg_calls) .. ")")
	check(longest_call() <= routes.STREET_REACH + 1 and all_padded(),
		"S1 ...each a short bounded one (" .. longest_call() .. ")")
	check(st.corners >= 3, "S1 ...on corner points along the streets (" .. st.corners .. ")")
	check(#placed == 0, "S1 ...walked, never snapped")
	-- S2 the way back reuses nothing new but its own leg.
	t = run(m, 300, function(s) return s.route.wp == 2 end)
	st = grug_mobs.route_cache_stats(capital)
	check(t ~= nil and st.street_legs == 2 and st.searches == 4,
		"S2 the way back is its own street leg (" .. st.searches .. " searches)")
	local before = #find_calls
	t = run(m, 300, function(s) return s.route.wp == 1 end)
	t = t and run(m, 300, function(s) return s.route.wp == 2 end)
	check(t ~= nil and #find_calls == before, "S2 ...and the next round asks nothing")
	-- S3 ends far from every street: the split straight leg.
	fresh()
	local capital2 = new_settlement("capital")
	a, b = {x = 20, y = 1, z = 40}, {x = 60, y = 1, z = 40}
	m = patroller(20, 40, capital2, {a, b})
	m.route.wp = 2
	m.temp.grug_route_from = 1
	t = run(m, 120, function(s) return s.route.wp == 1 end)
	st = grug_mobs.route_cache_stats(capital2)
	check(t ~= nil and st.street_legs == 0 and st.ok >= 1,
		"S3 far from the streets: a split straight leg")
	-- S4 a villager in a capital never takes the streets.
	fresh()
	local capital3 = new_settlement("capital")
	local w = walker(10, 40, capital3, {spot(10, 40), spot(50, 40)}, 2)
	w._grug_idle_from = 1
	run(w, 60, arrived)
	check(grug_mobs.route_cache_stats(capital3).street_legs == 0,
		"S4 a walker's leg is never a street leg")
	grug_mapgen.wp40.road_layout_text = nil
end

-- ---------------------------------------------------------------------------
-- W. Following.
-- ---------------------------------------------------------------------------
do
	-- W1 pushed off the route: back to its next corner, no new route search.
	fresh()
	local town = new_settlement("start")
	fill(10, 1, -3, 10, 2, 3, "stone")
	local spots = {spot(0, 0), spot(20, 0)}
	local m = walker(0, 0, town, spots, 2)
	m._grug_idle_from = 1
	run(m, 4, function(s) return s.temp.grug_leg and s.temp.grug_leg.k end)
	local st = grug_mobs.route_cache_stats(town)
	check(st.ok == 1, "W1 on its route")
	local calls = #find_calls
	m.object.pos.x, m.object.pos.z = m.object.pos.x - 2, m.object.pos.z - 6
	local t = run(m, 60, arrived)
	check(t ~= nil and hdist(m, 20, 0) < 1.6, "W1 pushed off, it returns and arrives")
	check(grug_mobs.route_cache_stats(town).searches == 1,
		"W1 ...without building the route again (" .. (#find_calls - calls) .. " local searches)")
	-- W2 a village walker (no cache): its spot is a fixed target.
	fresh()
	trunk(10, 0)
	m = walker(0, 0, "a_village", {spot(0, 0), spot(20, 0)}, 2)
	t = run(m, 40, arrived)
	check(t ~= nil and hdist(m, 20, 0) < 1.6, "W2 a village walker arrives round the trunk")
	check(m.ev and m.ev.stuck and m.ev.found, "W2 ...stuck, a local search found its way")
	check(grug_mobs.route_cache_stats("a_village") == nil, "W2 ...no cache for a village")
	-- W3 a fight drops the leg; afterwards the walk resumes.
	fresh()
	town = new_settlement("start")
	m = walker(0, 0, town, {spot(0, 0), spot(20, 0)}, 2)
	m._grug_idle_from = 1
	run(m, 3)
	check(m.temp.grug_leg ~= nil, "W3 walking a leg")
	m.attack, m.state = {}, "attack"
	run(m, 1.1)
	check(m.temp.grug_leg == nil and m.temp.grug_walk == nil, "W3 a fight drops the leg")
	m.attack, m.state = nil, "stand"
	check(run(m, 40, arrived) ~= nil, "W3 ...and the walk resumes afterwards")
	-- W4 a start-town patrol: legs on first use, the second round asks nothing.
	fresh()
	town = new_settlement("start")
	trunk(10, 0)
	trunk(10, 20)
	local points = {{x = 0, y = 1, z = 0}, {x = 20, y = 1, z = 0},
		{x = 20, y = 1, z = 20}, {x = 0, y = 1, z = 20}}
	m = patroller(0, 0, town, points)
	local laps = 0
	run(m, 200, function(s)
		if s.route.wp == 1 and s.lap_seen ~= 1 then laps = laps + 1 end
		s.lap_seen = s.route.wp
		return laps >= 2
	end)
	st = grug_mobs.route_cache_stats(town)
	check(laps >= 1 and st.legs == 4 and st.searches == 4, "W4 four legs, built once")
	calls = #find_calls
	laps = 0
	m.lap_seen = nil
	t = run(m, 200, function(s)
		if s.route.wp == 1 and s.lap_seen ~= 1 then laps = laps + 1 end
		s.lap_seen = s.route.wp
		return laps >= 2
	end)
	check(t ~= nil and #find_calls == calls and #placed == 0,
		"W4 ...the next rounds ask nothing")
end

-- ---------------------------------------------------------------------------
-- U. Unloaded is "later", never "no route" (review High); a walker away from
-- a no-route leg's start walks to its goal (review Medium).
-- ---------------------------------------------------------------------------
do
	-- U1 a leg across the unloaded edge (x > 300): pending, not none; the
	-- walker walks on as a fixed walk; once loaded, the leg is built.
	fresh()
	local town = new_settlement("start")
	local spots = {spot(250, 0), spot(350, 0)}
	local m = walker(250, 0, town, spots, 2)
	m._grug_idle_from = 1
	run(m, 3)
	local st = grug_mobs.route_cache_stats(town)
	check(st.none == 0 and st.pending == 1, "U1 an unloaded leg waits (none " ..
		st.none .. ", pending " .. st.pending .. ")")
	check(hdist(m, 250, 0) > 1, "U1 ...while the walker walks on")
	LIMIT = 1000
	m.object.pos = {x = 250, y = 0.51, z = 0}
	local t = run(m, 120, arrived)
	st = grug_mobs.route_cache_stats(town)
	check(t ~= nil and st.ok == 1 and st.none == 0, "U1 ...loaded, it is built and walked")
	LIMIT = 300
	-- U2 a wall on the way while the far end is unloaded: the pending walk
	-- is a fixed walk, stuck at the wall it searches its way round.
	fresh()
	town = new_settlement("start")
	fill(268, 1, -3, 268, 2, 3, "stone")
	m = walker(260, 0, town, {spot(260, 0), spot(301, 0)}, 2)
	m._grug_idle_from = 1
	t = run(m, 40, function(s) return s.object.pos.x > 271 end)
	st = grug_mobs.route_cache_stats(town)
	check(t ~= nil and st.none == 0, "U2 round the wall while the leg waits (" ..
		tostring(t) .. " s)")
	check(m.ev and m.ev.stuck and m.ev.found, "U2 ...stuck, a local search found the way")
	-- U3 the start of a no-route leg is enclosed and the walker is away from
	-- it: it walks to its goal (ring: A open, B and C in pens).
	fresh()
	town = new_settlement("start")
	pen(20, 0, 3)
	pen(0, 20, 3)
	spots = {spot(0, 0), spot(20, 0), spot(0, 20)}
	m = walker(14, 6, town, spots, 1)
	t = run(m, 60, arrived)
	check(t ~= nil and hdist(m, 0, 0) < 1.6, "U3 the walker away from its enclosed start arrives")
	check(m._grug_idle_from == 1, "U3 ...the stand-in start was never saved")
	-- U4 the walker stands right by its enclosed stand-in start (within 5
	-- nodes of it): the stand-in's "no route" is no verdict, it still walks.
	fresh()
	town = new_settlement("start")
	pen(20, 0, 3)
	spots = {spot(0, 0), spot(20, 0), spot(40, 0)}
	m = walker(20, 4.6, town, spots, 1)
	t = run(m, 120, arrived)
	check(t ~= nil, "U4 a walker beside its enclosed stand-in start arrives (" ..
		tostring(t) .. " s, spot " .. tostring(m._grug_idle_spot) .. ")")
end

-- ---------------------------------------------------------------------------
-- N. The next-spot stage of a fixed-target walker.
-- ---------------------------------------------------------------------------
do
	fresh()
	pen(20, 0, 3)
	local m = walker(0, 0, "a_village", {spot(0, 0), spot(20, 0), spot(0, 12)}, 2)
	local t = run(m, 60, function(s) return s._grug_idle_spot == 3 end)
	check(t ~= nil and t > 5, "N1 a village spot in a pen is given up (" .. tostring(t) .. " s)")
	check(m.temp.grug_nav == nil or m.temp.grug_nav.fails == 0,
		"N1 ...after three failed searches, the walk cleared")
	check(#find_calls <= 4, "N1 ...bounded (" .. #find_calls .. " searches)")
end

-- ---------------------------------------------------------------------------
-- R. Rings: the one-spot walkers (ruling 16) and the claim's refresh.
-- ---------------------------------------------------------------------------
do
	local own = {{x = 0, y = 1, z = 0, yaw = 0}}
	local others = {{x = 40, y = 1, z = 0}, {x = 30, y = 1, z = 0},
		{x = 30, y = 1, z = 1}, {x = 90, y = 1, z = 0}}
	local ring, index = bounded_spots(own, 1, true, others)
	check(#ring == ring_env.WALK_MIN_RING and index == 1,
		"R1 a walker alone in its composition borrows spots: ring " .. #ring)
	check(ring[2].x == 30 and ring[2].z == 0 and ring[3].z == 1,
		"R1 ...the nearest, in a fixed order")
	ring = bounded_spots(own, 1, false, others)
	check(#ring == 1, "R1 a static resident is never topped up")
	ring = bounded_spots({own[1], {x = 5, y = 1, z = 0}, {x = 9, y = 1, z = 0}}, 1,
		true, others)
	check(#ring == 3 and ring[3].x == 9, "R1 a full ring borrows nothing")
	-- R2 the claim re-derives an old ring of one and old points without y.
	local row = {walkers = {home = true},
		idle_groups = {plot_a = {{x = 0, y = 1, z = 0, yaw = 0}},
			plot_b = {{x = 12, y = 1, z = 0}, {x = 16, y = 1, z = 0}}},
		by_socket = {home = {role = "idle", id = "home", composition = "plot_a",
			idle_index = 1}, watch = {role = "guard_patrol", group = "ring"}},
		patrols = {ring = {{x = 0, y = 3, z = 0}, {x = 9, y = 4, z = 9}}}}
	ring_env.by_key.cap = row
	local e = {_grug_start = "cap", _grug_socket = "home", _grug_idle_spot = 1,
		_grug_idle_spots = {{x = 0, y = 1, z = 0}}, _grug_idle_from = 1}
	ring_env.refresh_walk(e)
	check(#e._grug_idle_spots == 3 and e._grug_idle_spot == 1 and e._grug_idle_from == nil,
		"R2 an old ring of one is re-derived at the claim")
	local g = {_grug_start = "cap", _grug_socket = "watch",
		_grug_patrol_route = {points = {{x = 0, z = 0}, {x = 9, z = 9}}, wp = 2}}
	ring_env.refresh_walk(g)
	check(g._grug_patrol_route.points[2].y == 4 and g._grug_patrol_route.wp == 2,
		"R2 old patrol points get their heights, the place in the loop stays")
	check(read(NPCS):find("refresh_walk(entity)", 1, true) ~= nil,
		"R2 the claim calls it")
end

-- ---------------------------------------------------------------------------
-- Z. Residents that never leave their spot ask nothing.
-- ---------------------------------------------------------------------------
do
	-- Z1 a resident whose ring is its own spot, pushed away behind a wall.
	fresh()
	local town = new_settlement("start")
	fill(3, 1, -3, 3, 2, 3, "stone")
	local m = walker(6, 0, town, {spot(0, 0)}, 1)
	m._grug_walker = false
	run(m, 20)
	check(#find_calls == 0 and grug_mobs.route_cache_stats(town).legs == 0,
		"Z1 a resident with one spot asks nothing")
	-- Z2 a work resident pushed away: straight home, no search; snapped home
	-- after 30 s, out of sight only.
	fresh()
	fill(3, 1, -3, 3, 2, 3, "stone")
	players[1] = {player = true, pos = {x = 0, y = 1, z = 40}, is_player = function() return true end}
	m = mob(6, 0, {_grug_work_activity = "smith", _grug_work_x = 0, _grug_work_z = 0})
	m.do_custom = work_tick
	run(m, 40)
	check(#find_calls == 0 and #placed == 0, "Z2 a work resident asks nothing; watched, not snapped")
	players = {}
	run(m, 12)
	check(#placed == 1 and hdist(m, 0, 0) < 0.01, "Z2 ...out of sight it is put home")
	check(#find_calls == 0, "Z2 ...still without a search")
end

-- ---------------------------------------------------------------------------
-- A. The old pieces are gone (ruling 17).
-- ---------------------------------------------------------------------------
do
	local dir = "mods/ENTITIES/grug_mobs/"
	for _, file in ipairs({"patrol.lua", "start_villagers.lua", "start_npcs.lua",
			"routes.lua", "guard.lua"}) do
		local src = read(dir .. file)
		check(not src:find("stall_clock", 1, true), "A " .. file .. ": no stall clock")
		check(not src:find("stall_clear", 1, true), "A " .. file .. ": no stall_clear")
		check(not src:find("core.find_path(", 1, true), "A " .. file .. ": no own core.find_path")
		check(not src:find("smart_mobs", 1, true), "A " .. file .. ": no smart_mobs comment")
	end
	check(grug_mobs.stall_clock == nil and grug_mobs.stall_clear == nil,
		"A the stall clock is removed")
	check(not read(VILLAGERS):find("SPOT_GIVE_UP =", 1, true), "A no 15 s spot give-up")
end

print("R42 NV3 PORTABLE PASS checks=" .. checks)
