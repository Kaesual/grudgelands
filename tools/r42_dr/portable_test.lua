-- Round 42 lane DR portable test (round42-plan.md §4.5, ruling 15): settlement
-- NPCs open, pass and close doors. Loads the REAL mobs/grug_nav.lua,
-- mobs/grug_obstacle.lua, grug_mobs/npc_doors.lua, grug_mobs/patrol.lua and
-- grug_mobs/routes.lua, cuts the REAL amble tick out of start_villagers.lua
-- and the REAL `doors.get` / `doors.door_toggle` out of the vendored
-- doors/init.lua (no player: no interaction check; its own sounds). The
-- world model is tools/r42_nv3's (a node grid, the engine pathfinder's
-- model: a walkable node blocks, so a door is a wall to it, open or shut);
-- a body collides with a shut door and passes an open one. Checks:
--   R  route split at a door: a start-town leg to a spot behind a door is
--      built "to the door", "through the door", "from the door" (no search
--      crosses the door); the walker opens the door, passes and closes it;
--      the leg out of the room too; a leg from one room into another
--      through two doors; the cache's former no-route leg is built;
--   B  "another NPC right behind": the door stays open for it and the last
--      one through closes it (one open, one close);
--   U  an NPC unloaded in the doorway leaves the door open;
--   O  a door found open (a player's) is passed and left open;
--   D  who is in the doorway (players and mobs, never an attached nametag
--      carrier or an item); a walker holding two doors shuts both; a
--      hand-over adds to what the receiver holds;
--   P  never a locked door: an owned door is no door (no route, never
--      opened); trapdoors are no doors;
--   G  gates: NPCs route round a fence gate and never open one; a pen whose
--      only way in is a gate is no route;
--   F  fixed walks without a cache: a village walker and a post guard walk
--      through a door to a goal behind it and close it; a walk that is no
--      settlement NPC's (a camp patrol, a rare) never opens a door;
--   S  sounds: the vendored toggle plays the door's own open and close
--      sounds (no new play path).
-- Usage (repo root): luajit tools/r42_dr/portable_test.lua [REPO]
-- Prints "R42 DR PORTABLE PASS checks=<n>" or raises.
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

-- ---------------------------------------------------------------------------
-- The world: a node grid (unset is air, at y <= 0 stone), node meta, the
-- engine.
-- ---------------------------------------------------------------------------
local us = 1000000
local world, metas, param2s = {}, {}, {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name, p2)
	world[key(x, y, z)] = name
	param2s[key(x, y, z)] = p2
end
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

local DOOR_DEF = {name = "doors:door_wood", sounds = {"doors_door_close",
	"doors_door_open"}, gains = {0.13, 0.06}}
local nodes = {
	air = {name = "air", walkable = false},
	stone = {name = "stone", walkable = true},
	["doors:hidden"] = {name = "doors:hidden", walkable = true},
	["doors:gate_wood_closed"] = {name = "doors:gate_wood_closed", walkable = true,
		groups = {fence = 1}},
	["doors:trapdoor"] = {name = "doors:trapdoor", walkable = true,
		groups = {door = 1}},
}
for _, v in ipairs({"_a", "_b", "_c", "_d"}) do
	nodes["doors:door_wood" .. v] = {name = "doors:door_wood" .. v, walkable = true,
		groups = {door = 1}, door = DOOR_DEF}
end

local logs, players, objects, sounds = {}, {}, {}, {}
local find_calls = {}
local function meta_of(p)
	local k = key(p.x, p.y, p.z)
	local m = metas[k]
	if not m then
		m = {fields = {}}
		function m:get_string(f) return self.fields[f] or "" end
		function m:set_string(f, v) self.fields[f] = v end
		function m:get_int(f) return tonumber(self.fields[f]) or 0 end
		function m:set_int(f, v) self.fields[f] = tostring(v) end
		metas[k] = m
	end
	return m
end
core = {
	registered_nodes = nodes,
	get_us_time = function() return us end,
	log = function(_, text) logs[#logs + 1] = text end,
	pos_to_string = function(p) return ("(%g,%g,%g)"):format(p.x, p.y, p.z) end,
	get_meta = meta_of,
	get_node = function(p)
		return {name = name_at(p.x, p.y, p.z), param2 = param2s[key(p.x, p.y, p.z)] or 0}
	end,
	swap_node = function(p, node) set(p.x, p.y, p.z, node.name, node.param2) end,
	sound_play = function(spec, params)
		sounds[#sounds + 1] = {name = spec, pos = params.pos}
	end,
	register_node = function() end,
	get_objects_inside_radius = function(pos, radius)
		local out = {}
		for _, list in ipairs({players, objects}) do
			for _, o in ipairs(list) do
				local p = o:get_pos()
				local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
				if dx * dx + dy * dy + dz * dz <= radius * radius then out[#out + 1] = o end
			end
		end
		return out
	end,
	find_nodes_in_area = function(minp, maxp, what)
		check(what == "group:door", "find_nodes_in_area only for the doors")
		local out = {}
		for k, name in pairs(world) do
			local def = nodes[name]
			if def and def.groups and def.groups.door then
				local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
				x, y, z = tonumber(x), tonumber(y), tonumber(z)
				if x >= minp.x and x <= maxp.x and y >= minp.y and y <= maxp.y
				and z >= minp.z and z <= maxp.z then
					out[#out + 1] = {x = x, y = y, z = z}
				end
			end
		end
		table.sort(out, function(a, b) return key(a.x, a.y, a.z) < key(b.x, b.y, b.z) end)
		return out
	end,
}
minetest = core
local LIMIT = 300 -- beyond |x| the map is not loaded
function core.get_node_or_nil(pos)
	if abs(pos.x) > LIMIT then return nil end
	return core.get_node(pos)
end
local function walkable(x, y, z)
	local def = nodes[name_at(x, y, z)]
	return not def or def.walkable == true
end
-- What a body bumps into: a shut door and everything walkable but an open
-- door and the hidden node over a door (a hinge pixel).
local OPEN = {["doors:door_wood_c"] = true, ["doors:door_wood_d"] = true,
	["doors:hidden"] = true}
local function collides(x, y, z)
	local n = name_at(x, y, z)
	return walkable(x, y, z) and not OPEN[n]
end
vector = {new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end}

-- The engine pathfinder's model (tools/r42_nv1): ends must not be walkable;
-- four directions; a walkable node blocks (a door, open or shut).
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
			local rev, k = {}, key(c.x, c.y, c.z)
			while k do
				local e = seen[k]
				rev[#rev + 1] = e.cell or s
				k = e.from
			end
			local path = {}
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

-- ---------------------------------------------------------------------------
-- The real modules: the vendored door toggle, the navigation, the walks.
-- ---------------------------------------------------------------------------
doors = {registered_doors = {}, registered_trapdoors = {["doors:trapdoor"] = true}}
for _, v in ipairs({"_a", "_b", "_c", "_d"}) do
	doors.registered_doors["doors:door_wood" .. v] = true
end
local interact_asked = 0
default = {can_interact_with_node = function()
	interact_asked = interact_asked + 1
	return false
end}
cut("mods/BASE/doors/init.lua", "local function is_doors_upper_node(pos)",
	"\treturn true\nend\n", {S = function(s) return s end})
check(type(doors.get) == "function" and type(doors.door_toggle) == "function",
	"the vendored doors.get and doors.door_toggle")

local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
nav.init({obstacle = O, max_jump = 4, max_drop = 6})
mobs = {grug_obstacle = O, grug_nav = nav}
local placed = {}
grug_mobs = {
	place_on_ground = function(object, p)
		placed[#placed + 1] = {x = p.x, y = p.y, z = p.z}
		object.pos = {x = p.x, y = floor(p.y + 0.5) - 0.49, z = p.z}
	end,
	start_npc_claim = function() return true end,
}
grug_mapgen = {wp40 = {}}
dofile(repo .. "/mods/ENTITIES/grug_mobs/npc_doors.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/patrol.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/routes.lua")
local D = grug_mobs.npc_doors
grug_mobs.face_yaw = function(self, yaw) self.object.yaw = yaw end

local VILLAGERS = "mods/ENTITIES/grug_mobs/start_villagers.lua"
local amble_env = {spot_taken = function() return false end}
for _, name in ipairs({"SPOT_ARRIVED", "AMBLE_TICK", "SPOT_GIVE_UP_AFTER"}) do
	amble_env[name] = constant(VILLAGERS, name)
end
do
	local src = read(VILLAGERS)
	local a, b = src:match("\nlocal DWELL_MIN, DWELL_MAX = (%d+), (%d+)")
	local c, d = src:match("\nlocal STATIC_DWELL_MIN, STATIC_DWELL_MAX = (%d+), (%d+)")
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
end
function mob_class:set_animation() end

local function new_object(pos)
	local o = {pos = vector.new(pos), vel = {x = 0, y = 0, z = 0}, yaw = 0}
	function o:get_pos() return vector.new(self.pos) end
	function o:get_velocity() return vector.new(self.vel) end
	function o:is_player() return false end
	function o:get_luaentity() return self.ent end
	function o:get_attach() return self.parent end
	return o
end

-- A villager's body (0.6 wide, 1.7 tall, never jumps) by default.
local function mob(x, z, fields)
	local m = setmetatable({name = "test:villager", state = "stand", temp = {},
		_cmi_is_mob = true,
		walk_velocity = 1.1, jump_height = 0, fear_height = 4,
		initial_properties = {stepheight = 1.1},
		_grug_cbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}, {__index = mob_class})
	for k, v in pairs(fields or {}) do m[k] = v end
	m.object = new_object({x = x, y = 0.51, z = z})
	m.object.ent = m
	objects[#objects + 1] = m.object
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
				if collides(cx, cy, cz) then return false end
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

-- Steps every mob in `list` together.
local function run_all(list, seconds, done)
	for i = 1, floor(seconds / DT + 0.5) do
		us = us + floor(DT * 1e6)
		nav.begin_server_step(DT)
		O.begin_server_step()
		for _, m in ipairs(list) do
			m.do_custom(m, DT)
			physics(m)
		end
		if done and done() then return i * DT end
	end
end
local function run(m, seconds, done)
	return run_all({m}, seconds, done and function() return done(m) end)
end
local function hdist(m, x, z)
	local p = m.object.pos
	return sqrt((p.x - x) * (p.x - x) + (p.z - z) * (p.z - z))
end
local function fresh()
	world, metas, param2s, find_calls, logs, placed, players, objects, sounds =
		{}, {}, {}, {}, {}, {}, {}, {}, {}
	interact_asked = 0
	us = us + 100 * 1000000
end

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
local function arrived(m) return m._grug_idle_dwell ~= nil end

-- A room: stone walls 3 high round x1..x2, z1..z2 (inclusive, walls on the
-- edge) with a wooden door in the west wall at (x1, 1, dz), as the mapgen
-- writes it (the leaf and doors:hidden above, no state meta).
local function room(x1, z1, x2, z2, door_z, door_side)
	fill(x1, 1, z1, x2, 3, z1, "stone")
	fill(x1, 1, z2, x2, 3, z2, "stone")
	fill(x1, 1, z1, x1, 3, z2, "stone")
	fill(x2, 1, z1, x2, 3, z2, "stone")
	if door_z then
		-- The leaf faces inward (the way the placer looked: facedir 1 is +x).
		local dx = door_side == "east" and x2 or x1
		local face = door_side == "east" and 3 or 1
		set(dx, 1, door_z, "doors:door_wood_a", face)
		set(dx, 2, door_z, "doors:hidden", face)
		return {x = dx, y = 1, z = door_z}
	end
end
local function door_open(p)
	return doors.get(p):state()
end
local function count_sounds(name)
	local n = 0
	for _, s in ipairs(sounds) do if s.name == name then n = n + 1 end end
	return n
end

-- ---------------------------------------------------------------------------
-- R. A route split at a door.
-- ---------------------------------------------------------------------------
do
	fresh()
	local town = new_settlement("start")
	local d = room(10, -4, 18, 4, 0)
	local A, B = spot(0, 0), spot(15, 2)
	local m = walker(0, 0, town, {A, B}, 2)
	m._grug_idle_from = 1
	check(D.at(d) and D.at(d).ax == 1, "R0 the door in the wall is a door, across x")
	local opened_at, entry
	local t = run(m, 60, function(s)
		if not opened_at and door_open(d) then opened_at = s.object.pos.x end
		local leg = s.temp.grug_leg
		if leg and leg.entry.state == "ok" then entry = leg.entry end
		return arrived(s)
	end)
	local st = grug_mobs.route_cache_stats(town)
	check(t ~= nil and hdist(m, 15, 2) < 1.6, "R1 the walker reaches the spot behind the door")
	check(st.ok == 1 and st.none == 0 and st.door_legs == 1,
		"R1 ...on a cached door leg (ok " .. st.ok .. ", none " .. st.none .. ")")
	-- The corners: ..., the cell in front, the door's centre (the door rides
	-- on it), the cell behind, ...
	local k
	for i, p in ipairs(entry.points) do if p.door then k = i end end
	check(k and k > 1 and entry.points[k].door.key == D.key(d)
		and entry.points[k - 1].x == d.x - 1 and entry.points[k + 1].x == d.x + 1,
		"R1 the route: in front of the door, through it, behind it")
	check(#find_calls >= 2, "R1 ...searched to the door and from it: " .. #find_calls)
	local seen_pair, twice = {}, false
	for _, c in ipairs(find_calls) do
		local k = key(c.from.x, c.from.y, c.from.z) .. ">" .. key(c.to.x, c.to.y, c.to.z)
		if seen_pair[k] then twice = true end
		seen_pair[k] = true
	end
	check(not twice, "R1 ...no piece searched twice (the check's path is walked)")
	check(opened_at and opened_at < d.x - 0.3,
		"R2 it opens the door in front of it (at x " .. tostring(opened_at) .. ")")
	check(not door_open(d), "R2 ...and it is shut again behind it")
	check(count_sounds("doors_door_open") == 1 and count_sounds("doors_door_close") == 1,
		"S1 the vendored toggle plays the door's own open and close sounds")
	check(interact_asked == 0, "S1 ...with no player, so no interaction check")
	check(m.temp.grug_door_open == nil, "R2 ...and the walker holds no door")
	-- R3 the way out of the room: the door near `from`.
	m._grug_idle_dwell, m._grug_idle_spot, m._grug_idle_from = nil, 1, 2
	local calls = #find_calls
	t = run(m, 60, arrived)
	st = grug_mobs.route_cache_stats(town)
	check(t ~= nil and hdist(m, 0, 0) < 1.6 and st.door_legs == 2 and st.none == 0,
		"R3 out of the room through the door (door legs " .. st.door_legs .. ")")
	check(not door_open(d) and count_sounds("doors_door_close") == 2, "R3 ...shut behind it")
	-- R4 the next round asks nothing (the door legs are cached).
	calls = #find_calls
	m._grug_idle_dwell, m._grug_idle_spot, m._grug_idle_from = nil, 2, 1
	t = run(m, 60, arrived)
	check(t ~= nil and #find_calls == calls, "R4 a cached door leg searches nothing again")
	-- R5 from one room into another: two doors.
	fresh()
	local town5 = new_settlement("start")
	local d1 = room(-12, -4, -4, 4, 0, "east")
	local d2 = room(10, -4, 18, 4, 0)
	local m5 = walker(-8, 2, town5, {spot(-8, 2), spot(15, 2)}, 2)
	m5._grug_idle_from = 1
	t = run(m5, 90, arrived)
	st = grug_mobs.route_cache_stats(town5)
	check(t ~= nil and st.door_legs == 1 and hdist(m5, 15, 2) < 1.6,
		"R5 from one room into another through both doors")
	check(not door_open(d1) and not door_open(d2), "R5 ...both shut behind it")
	check(st.searches <= 30, "R5 ...in a bounded build (" .. st.searches .. " searches)")
	-- R7 a spot right behind the door: the walker does not stop in the
	-- doorway (it would hold the door open), it arrives clear of it and the
	-- door is shut while it dwells.
	fresh()
	local town7 = new_settlement("start")
	local d7 = room(10, -4, 18, 4, 0)
	local m7 = walker(0, 0, town7, {spot(0, 0), spot(11, 0)}, 2)
	m7._grug_idle_from = 1
	local in_doorway
	t = run(m7, 60, function(s)
		if arrived(s) and abs(s.object.pos.x - d7.x) < D.CLEAR then in_doorway = true end
		return arrived(s)
	end)
	run(m7, 2)
	check(t ~= nil and not in_doorway and arrived(m7),
		"R7 a walker never arrives in the doorway")
	check(not door_open(d7), "R7 ...and the door is shut while it dwells behind it")
	-- R8 the open leaf lies along one side: the walker aims at the middle
	-- of the way through, 1/16 off the cell's centre away from the leaf (the
	-- vendored toggle turns facedir 1 into the open leaf's facedir 2, whose
	-- panel lies on +z).
	doors.get(d7):open()
	local aim = D.aim(d7, d7)
	check(abs(aim.z - (d7.z - 1 / 16)) < 1e-9 and aim.x == d7.x,
		"R8 the aim is the middle of the doorway")
	-- R6 the room without its door is no route (the plain plan and the door
	-- plans are spent; nothing searches again).
	fresh()
	local town6 = new_settlement("start")
	room(10, -4, 18, 4, nil)
	local m6 = walker(0, 0, town6, {spot(0, 0), spot(15, 2), spot(0, 10)}, 2)
	m6._grug_idle_from = 1
	run(m6, 3)
	st = grug_mobs.route_cache_stats(town6)
	check(st.none == 1 and m6._grug_idle_spot == 3, "R6 a room without a door is no route")
end

-- ---------------------------------------------------------------------------
-- B. Another NPC right behind keeps the door open; the last one shuts it.
-- ---------------------------------------------------------------------------
do
	fresh()
	local town = new_settlement("start")
	local d = room(10, -4, 18, 4, 0)
	local spots = {spot(0, 0), spot(15, 2)}
	local m1 = walker(4, 0, town, spots, 2)
	local m2 = walker(2, 0, town, spots, 2)
	m1._grug_idle_from, m2._grug_idle_from = 1, 1
	local seen_shut_between = false
	local first_in
	run_all({m1, m2}, 60, function()
		if not first_in and m1.object.pos.x > d.x + 1.2 then first_in = true end
		if first_in and m2.object.pos.x < d.x - 0.5 and not door_open(d) then
			seen_shut_between = true
		end
		return arrived(m1) and arrived(m2)
	end)
	check(arrived(m1) and arrived(m2), "B1 both walkers reach the room")
	check(not seen_shut_between, "B1 the door stays open while the second is right behind")
	check(not door_open(d), "B1 ...and is shut after the last one")
	check(count_sounds("doors_door_open") == 1 and count_sounds("doors_door_close") == 1,
		"B1 ...one open, one close")
end

-- ---------------------------------------------------------------------------
-- U. Unloaded in the doorway: the door stays open.
-- ---------------------------------------------------------------------------
do
	fresh()
	local town = new_settlement("start")
	local d = room(10, -4, 18, 4, 0)
	local m = walker(0, 0, town, {spot(0, 0), spot(15, 2)}, 2)
	m._grug_idle_from = 1
	run(m, 60, function() return door_open(d) and m.object.pos.x > d.x - 0.3 end)
	check(door_open(d), "U1 the walker opened the door")
	-- Unloaded: its runtime state is gone (staticdata keeps no door), the
	-- object leaves the world.
	objects = {}
	local other = walker(0, 8, town, {spot(0, 8), spot(0, 14)}, 2)
	other._grug_idle_from = 1
	run(other, 30)
	check(door_open(d), "U1 an NPC unloaded in the doorway leaves the door open")
	-- Reloaded in the doorway: it walks on through and leaves it open (it
	-- did not open it in this life).
	m.temp = {}
	objects[#objects + 1] = m.object
	local t = run(m, 60, arrived)
	check(t ~= nil and door_open(d), "U2 reloaded, it walks on and the door stays open")
end

-- ---------------------------------------------------------------------------
-- D. Who is in the doorway; every held door is settled (review L1, L2).
-- ---------------------------------------------------------------------------
do
	local function place(m, x, z) m.object.pos = {x = x, y = 0.51, z = z} end
	local function settle(m) D.settle(m, m.object:get_pos()) end
	-- D1 the opener stopped beside the door inside the wall's corner (axis
	-- 0.75, lateral 0.6: past it by the 0.9 measure) with its nametag
	-- carrier attached at its position: nobody is in the doorway, so the
	-- door is shut.
	fresh()
	local d = room(10, -4, 18, 4, 0)
	local m = mob(d.x - 1, d.z)
	D.approach(m, m.object:get_pos(), D.at(d))
	check(door_open(d) and m.temp.grug_door_open[D.key(d)] ~= nil, "D1 the walker opens and holds the door")
	place(m, d.x + 0.75, d.z + 0.6)
	local tag = new_object(m.object.pos)
	tag.parent = m.object
	objects[#objects + 1] = tag
	local item = new_object({x = d.x, y = 1, z = d.z})
	objects[#objects + 1] = item
	settle(m)
	check(not door_open(d) and m.temp.grug_door_open == nil,
		"D1 its own nametag carrier and an item in the doorway hold nothing")
	-- D2 a mob standing in the doorway keeps it open until it leaves.
	fresh()
	d = room(10, -4, 18, 4, 0)
	m = mob(d.x - 1, d.z)
	D.approach(m, m.object:get_pos(), D.at(d))
	place(m, d.x + 2, d.z)
	local other = mob(d.x + 0.2, d.z + 0.1)
	settle(m)
	check(door_open(d) and m.temp.grug_door_open ~= nil, "D2 a mob in the doorway keeps it open")
	place(other, d.x + 3, d.z + 2)
	us = us + 1000000
	settle(m)
	check(not door_open(d) and m.temp.grug_door_open == nil, "D2 ...and it is shut once the doorway is clear")
	-- D3 a second door never drops the first: both are shut.
	fresh()
	local d1 = room(10, -4, 18, 4, 0)
	local d2 = {x = 10, y = 1, z = 2}
	set(10, 1, 2, "doors:door_wood_a", 1)
	set(10, 2, 2, "doors:hidden", 1)
	set(10, 1, 1, "stone")
	m = mob(9, 0)
	local other2 = mob(d1.x, d1.z) -- keeps the first door back
	D.approach(m, m.object:get_pos(), D.at(d1))
	place(m, 12, 0)
	settle(m)
	check(door_open(d1), "D3 the first door is kept open (somebody in it)")
	place(m, 9, 2)
	D.approach(m, m.object:get_pos(), D.at(d2))
	place(m, 12, 3)
	place(other2, 3, -2)
	us = us + 1000000
	settle(m)
	check(not door_open(d1) and not door_open(d2) and m.temp.grug_door_open == nil,
		"D3 a walker holding two doors shuts both")
	-- D4 a hand-over to an NPC that holds a door of its own adds to it.
	fresh()
	d1 = room(10, -4, 18, 4, 0)
	set(10, 1, 2, "doors:door_wood_a", 1)
	set(10, 2, 2, "doors:hidden", 1)
	set(10, 1, 1, "stone")
	local a, b = mob(9, 0), mob(9, 2)
	D.approach(a, a.object:get_pos(), D.at(d1))
	D.approach(b, b.object:get_pos(), D.at(d2))
	place(b, 7, 0.5)
	b.temp.grug_door_next = D.key(d1) -- b heads through a's door next
	place(a, 12, 0)
	settle(a)
	check(a.temp.grug_door_open == nil and b.temp.grug_door_open[D.key(d1)] ~= nil
		and b.temp.grug_door_open[D.key(d2)] ~= nil, "D4 the hand-over adds to what b holds")
	b.temp.grug_door_next = nil
	place(b, 12, 1)
	settle(b)
	check(not door_open(d1) and not door_open(d2), "D4 ...and b shuts both")
end

-- ---------------------------------------------------------------------------
-- O. A door found open is passed and left open.
-- ---------------------------------------------------------------------------
do
	fresh()
	local town = new_settlement("start")
	local d = room(10, -4, 18, 4, 0)
	doors.get(d):open()
	sounds = {}
	local m = walker(0, 0, town, {spot(0, 0), spot(15, 2)}, 2)
	m._grug_idle_from = 1
	local t = run(m, 60, arrived)
	check(t ~= nil and door_open(d) and #sounds == 0,
		"O1 a door a player left open is passed and left open")
end

-- ---------------------------------------------------------------------------
-- P. Never a locked door; trapdoors are no doors.
-- ---------------------------------------------------------------------------
do
	fresh()
	local town = new_settlement("start")
	local d = room(10, -4, 18, 4, 0)
	core.get_meta(d):set_string("owner", "somebody")
	check(D.at(d) == nil, "P1 a door with an owner is no door for an NPC")
	local m = walker(0, 0, town, {spot(0, 0), spot(15, 2), spot(0, 10)}, 2)
	m._grug_idle_from = 1
	run(m, 20)
	local st = grug_mobs.route_cache_stats(town)
	check(st.none == 1 and st.door_legs == 0 and m._grug_idle_spot == 3,
		"P1 ...the leg behind it is no route")
	check(not door_open(d) and #sounds == 0, "P1 ...and the door is never opened")
	-- A village walker's fixed walk does not open it either.
	local v = mob(0, 2, {_grug_idle_spots = {spot(0, 2), spot(15, 2)}, _grug_walker = true,
		_grug_idle_spot = 2})
	v.do_custom = amble_tick
	run(v, 30)
	check(not door_open(d), "P2 a fixed walk never opens a locked door")
	-- Unloaded is never "no door" for the cache; a fixed walk's detour takes
	-- what is loaded.
	fresh()
	local edge = room(286, -4, 294, 4, 0)
	check(D.near({x = 284, y = 1, z = 0}) == "wait",
		"P4 the cache waits while a door search's box is not loaded")
	local part = D.near({x = 284, y = 1, z = 0}, nil, true)
	check(#part == 1 and part[1].key == D.key(edge), "P4 ...a fixed walk takes the loaded part")
	-- A trapdoor is no door.
	set(30, 1, 0, "doors:trapdoor")
	check(D.at({x = 30, y = 1, z = 0}) == nil, "P3 a trapdoor is no door")
end

-- ---------------------------------------------------------------------------
-- G. Gates: round them, never open one.
-- ---------------------------------------------------------------------------
do
	fresh()
	local town = new_settlement("start")
	-- A fence line across the way with a gate on the line, open at its end.
	fill(10, 1, -6, 10, 2, 6, "stone")
	set(10, 1, 0, "doors:gate_wood_closed")
	local m = walker(0, 0, town, {spot(0, 0), spot(20, 0)}, 2)
	m._grug_idle_from = 1
	local t = run(m, 90, arrived)
	check(t ~= nil and name_at(10, 1, 0) == "doors:gate_wood_closed",
		"G1 the walker goes round the gate, which stays shut")
	-- A pen whose only way in is its gate: no route.
	fresh()
	local town2 = new_settlement("start")
	-- (A fence's collision box is 1.5 high: no body steps over it; the
	-- model makes it two nodes.)
	fill(10, 1, -4, 18, 2, -4, "stone")
	fill(10, 1, 4, 18, 2, 4, "stone")
	fill(18, 1, -4, 18, 2, 4, "stone")
	fill(10, 1, -4, 10, 2, 4, "stone")
	set(10, 1, 0, "doors:gate_wood_closed")
	m = walker(0, 0, town2, {spot(0, 0), spot(15, 0), spot(0, 10)}, 2)
	m._grug_idle_from = 1
	run(m, 5)
	local st = grug_mobs.route_cache_stats(town2)
	check(st.none == 1 and m._grug_idle_spot == 3 and #sounds == 0
		and name_at(10, 1, 0) == "doors:gate_wood_closed",
		"G2 a spot behind a gate is no route, the gate never opened")
end

-- ---------------------------------------------------------------------------
-- F. Fixed walks without a cache.
-- ---------------------------------------------------------------------------
do
	-- F1 a village walker (no route cache) to a spot behind a door.
	fresh()
	local d = room(10, -4, 18, 4, 0)
	local v = mob(0, 2, {_grug_idle_spots = {spot(0, 2), spot(15, 2)}, _grug_walker = true,
		_grug_idle_spot = 2, _grug_idle_from = 1})
	v.do_custom = amble_tick
	local t = run(v, 60, arrived)
	check(t ~= nil and hdist(v, 15, 2) < 1.6, "F1 a village walker reaches the spot behind the door")
	check(not door_open(d) and count_sounds("doors_door_open") == 1
		and count_sounds("doors_door_close") == 1, "F1 ...opens it and shuts it behind it")
	-- F2 a post guard walks back to a post behind a door.
	fresh()
	d = room(10, -4, 18, 4, 0)
	local g = mob(0, 0, {name = "test:guard", walk_velocity = 1.2, jump_height = 4})
	local acc = 0
	g.do_custom = function(self, dtime)
		acc = acc + dtime
		if acc < 1 then return grug_mobs.walk_follow(self, dtime, "post") end
		acc = 0
		local pos = self.object:get_pos()
		if (pos.x - 15) * (pos.x - 15) + pos.z * pos.z > 4 then
			grug_mobs.walk_fixed(self, 1, pos, 15, 1, 0, "post", "post")
		else
			grug_mobs.walk_clear(self, "post")
			self:set_velocity(0)
		end
	end
	t = run(g, 60, function(s) return hdist(s, 15, 0) < 2 end)
	run(g, 5)
	check(t ~= nil, "F2 a post guard walks back through the door to its post")
	check(not door_open(d) and #placed == 0, "F2 ...shuts it, never snapped")
	-- F3 a walk that is no settlement NPC's never opens a door.
	fresh()
	d = room(10, -4, 18, 4, 0)
	local r = mob(0, 0, {name = "test:rare"})
	acc = 0
	r.do_custom = function(self, dtime)
		acc = acc + dtime
		if acc < 1 then return grug_mobs.walk_follow(self, dtime, "route") end
		acc = 0
		grug_mobs.walk_fixed(self, 1, self.object:get_pos(), 15, 1, 0, 1, "route")
	end
	run(r, 40)
	check(not door_open(d) and #sounds == 0 and r.object.pos.x < d.x,
		"F3 a camp patrol or a rare never opens a door")
end

-- ---------------------------------------------------------------------------
-- E. The exception is recorded where the crack was the only one.
-- ---------------------------------------------------------------------------
do
	local agents = read("AGENTS.md")
	check(not agents:find("the one\nrecorded exception is the rift's crack", 1, true)
		and not agents:find("its crack the one\nrecorded exception", 1, true),
		"E AGENTS.md no longer calls the crack the only exception")
	check(agents:find("door", 1, true) ~= nil, "E AGENTS.md names the doors")
	check(not read("mods/ENTITIES/grug_mobs/npc_doors.lua"):find("sound_play", 1, true),
		"E no second sound path for the doors")
end

print("R42 DR PORTABLE PASS checks=" .. checks)
