-- Hotfix 0.43.1 portable test: a settlement leg whose two ends lie in one
-- search cell (two idle spots on one position, or on one x/z with y one
-- apart, the lower on a walkable node that end_cell raises by one; or the
-- stand-in start of a walker that does not know where it came from). At
-- 0.43.0 such a leg was built as an "ok" route with no point, and the walker
-- joining it crashed the server in nav.line_walkable (production log
-- 2026-10-08: grug_nav.lua:245 <- routes.lua:877 route_walk <-
-- start_villagers.lua walk_leg). Loads the REAL mobs/grug_nav.lua,
-- mobs/grug_obstacle.lua, grug_mobs/npc_doors.lua, grug_mobs/patrol.lua and
-- grug_mobs/routes.lua and cuts the REAL amble tick out of
-- start_villagers.lua; the world model and the moving body are
-- tools/r42_nv3's. Checks:
--   E1 two spots on one position: the walker pushed off it arrives, the leg's
--      route has its goal as a point;
--   E2 the same with the y offset of one (the lower spot on a block);
--   E3 the stand-in start (no known spot it came from) in the goal's cell;
--   G  the guard: an "ok" route without points (an entry the 0.43.0 build
--      left) is walked as a fixed walk to the goal, by route_walk and
--      route_follow, without a crash and without a stuck walker.
-- Usage (repo root): luajit tools/hf_0431/portable_test.lua [REPO]
-- Prints "HF 0431 PORTABLE PASS checks=<n>" or raises.
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
dofile(repo .. "/mods/ENTITIES/grug_mobs/npc_doors.lua")
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
-- The cases. Each runs on its own; a crash or a failed check is reported
-- with its label and the next case still runs.
-- ---------------------------------------------------------------------------
local failures = {}
local function case(label, fn)
	local ok, err = xpcall(fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2):gsub("\n%s*%[C%][^\n]*", ""):sub(1, 400)
	end)
	if ok then
		print("ok   " .. label)
	else
		failures[#failures + 1] = label .. ": " .. tostring(err)
		print("FAIL " .. label .. ": " .. tostring(err))
	end
end
local SPOT_ARRIVED = amble_env.SPOT_ARRIVED

-- E1 two idle spots on one position; the walker was pushed 3 nodes off it.
case("E1 two spots on one position", function()
	fresh()
	local town = new_settlement("start")
	local spots = {spot(5, 0), spot(5, 0), spot(20, 0)}
	local m = walker(2, 0, town, spots, 2)
	m._grug_idle_from = 1
	check(hdist(m, 5, 0) > SPOT_ARRIVED, "E1 the walker starts off its spot")
	local t = run(m, 20, arrived)
	check(t ~= nil and hdist(m, 5, 0) <= SPOT_ARRIVED, "E1 the walker arrives")
	local st = grug_mobs.route_cache_stats(town)
	check(st.legs == 1 and st.ok == 1 and st.corners >= 1,
		"E1 the leg's route has its goal as a point (corners " .. st.corners .. ")")
	check(#find_calls == 0, "E1 ...without an engine search")
	-- A second walker on the same cached leg.
	local m2 = walker(8, 0, town, spots, 2)
	m2._grug_idle_from = 1
	check(run(m2, 20, arrived) ~= nil, "E1 a second walker on the cached leg arrives")
end)

-- E2 the same x/z, y one apart: the lower spot's feet cell is a block, so
-- its search cell is raised by one, into the upper spot's.
case("E2 two spots one node apart in height", function()
	fresh()
	local town = new_settlement("start")
	set(5, 1, 0, "stone")
	local spots = {{x = 5, y = 1, z = 0, yaw = 0}, {x = 5, y = 2, z = 0, yaw = 0},
		spot(20, 0)}
	for _, pair in ipairs({{1, 2}, {2, 1}}) do
		local m = walker(2, 0, town, spots, pair[2])
		m._grug_idle_from = pair[1]
		local t = run(m, 20, arrived)
		check(t ~= nil and hdist(m, 5, 0) <= SPOT_ARRIVED,
			"E2 the walker arrives (" .. pair[1] .. " to " .. pair[2] .. ")")
	end
	local st = grug_mobs.route_cache_stats(town)
	check(st.legs == 2 and st.ok == 2 and st.corners >= 2,
		"E2 both legs' routes have their goal (corners " .. st.corners .. ")")
end)

-- E3 the stand-in start: the walker does not know the spot it came from
-- (its first walk after a load), and the spot nearest to it lies in its
-- goal's cell.
case("E3 a stand-in start in the goal's cell", function()
	fresh()
	local town = new_settlement("start")
	local spots = {spot(5, 0), spot(5, 0), spot(20, 0)}
	local m = walker(3, 0, town, spots, 2)
	local t = run(m, 20, arrived)
	check(t ~= nil and hdist(m, 5, 0) <= SPOT_ARRIVED, "E3 the walker arrives")
	local st = grug_mobs.route_cache_stats(town)
	check(st.ok == 1 and st.corners >= 1, "E3 the stand-in leg's route has its goal")
end)

-- G an "ok" route without a point (what the 0.43.0 build left in the cache):
-- the walk never indexes it; the walker walks to its goal as a fixed walk.
case("G an ok route without points", function()
	fresh()
	local town = new_settlement("start")
	trunk(10, 0)
	local spots = {spot(0, 0), spot(20, 0)}
	local m = walker(0, 0, town, spots, 2)
	m._grug_idle_from = 1
	run(m, 5, function(s) return s.temp.grug_leg ~= nil end)
	local leg = m.temp.grug_leg
	check(leg ~= nil, "G the walker starts its leg")
	local entry = leg.entry
	entry.state, entry.job, entry.points = "ok", nil, {}
	leg.k = nil
	local t = run(m, 40, arrived)
	check(t ~= nil and hdist(m, 20, 0) <= SPOT_ARRIVED,
		"G1 joining an empty route: the walker arrives (fixed walk)")
	-- A walker whose corner index is already set on the empty route.
	local m2 = walker(0, 0, town, spots, 2)
	m2._grug_idle_from = 1
	m2.temp.grug_leg = {owner = "amble", from = spots[1], to = spots[2],
		entry = entry, key = entry.key, k = 1}
	for _ = 1, 5 do grug_mobs.route_follow(m2, DT, "amble") end
	check(not grug_mobs.door_crossing(m2, m2.object:get_pos()),
		"G2 an empty route is no doorway")
	t = run(m2, 40, arrived)
	check(t ~= nil and hdist(m2, 20, 0) <= SPOT_ARRIVED,
		"G2 route_follow and route_walk on corner 1 of an empty route: arrives")
end)

if #failures > 0 then
	error(#failures .. " case(s) failed:\n  " .. table.concat(failures, "\n  "))
end
print("HF 0431 PORTABLE PASS checks=" .. checks)
