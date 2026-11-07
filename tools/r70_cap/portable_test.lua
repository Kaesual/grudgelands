-- Round 70 capitals, the test every capital lane shares (LuaJIT; plan §2.7,
-- tools/r70_cap/CAPITAL-GUIDE.md). Builds the six civic cores through the real
-- compositions and walks them with a small body model.
--
--   S  the size: one source (`wp13/precinct_ring.lua`), the fitting profiles,
--      the planner's defaults, the settlement bounds and every core's
--      gate landmarks read the same radius 56;
--   B  every cell inside BOUNDS.capital_core;
--   T  every socket of the core a standing point inside the pad.
-- A capital in DONE (a capital lane adds its key when its core is finished):
--   R  the protected ring closed, every gate on it;
--   W  every socket reached on foot from the crossing, doors passable;
--   C  the castle: 45 x 35, the two royal guards at their posts, the door
--      guards ordinary posts at the great door, the throne within the seat's
--      reach of the dais;
--   K  the king's real body (bosses.lua king_def through levels.lua's elite
--      scale, stepheight 1.1) reaches the great door from his seat inside his
--      leash, walks every free cell of the dais and goes home;
--   P  every socket on its row of the study's schedule
--      (tools/r70_design/data/socket-schedules.json), the rows in MOVED aside.
--
-- THE BODY MODEL is tools/r58_townfix's: a node k spans k-0.5 .. k+0.5, a full
-- node's top is k+0.5, a bottom slab's k, a stair's lower half k and its raised
-- half k+0.5 on the side its facedir points to; the body clears every walkable
-- node of the column it stands in and of the one it leaves. Here the body's
-- height and step are parameters.
--
-- Usage (repo root): luajit tools/r70_cap/portable_test.lua [REPO] [CAPITAL]
-- Prints "R70 CAP PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
local only = arg and arg[2]
_G.core = _G.core or {}
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"), path)
	local text = file:read("*a")
	file:close()
	return text
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local NODES = json.parse(read("tools/building_templates/nodes.json")).nodes
local parts = dofile(wp13 .. "/parts.lua")
local library = dofile(wp40 .. "/r7_wp13_library.lua")
local ring = dofile(wp13 .. "/precinct_ring.lua")
local planner = dofile(wp40 .. "/capital_planner.lua")
local settlement = dofile(wp40 .. "/r7_settlement.lua")

-- The capitals whose core a lane has finished; a capital lane adds its key.
-- These tables keep one row per capital with a comment line between rows, so
-- parallel lanes do not touch adjacent lines.
local DONE = {
	highcourt = false,
	-- the next capital
	dur_brannoc = true,
	-- the next capital
	lethariel = true,
	-- the next capital
	nhal_veyr = false,
	-- the next capital
	gor_drazhak = false,
	-- the next capital
	kezamba = false,
}
-- The castle's placement: anchor, turns, per capital.
local CASTLE = {
	highcourt = false,
	-- the next capital
	dur_brannoc = {plot = "kings_hall", x = -22, z = 10, turns = 0},
	-- the next capital
	lethariel = {plot = "kings_hall", x = -52, z = -51, turns = 3},
	-- the next capital
	nhal_veyr = false,
	-- the next capital
	gor_drazhak = false,
	-- the next capital
	kezamba = false,
}
-- Rows of the study's schedule the build moved on purpose, id -> reason.
local MOVED = {
	highcourt = {},
	-- the next capital
	dur_brannoc = {
		-- The castle's own rows follow the picked template, not the 2D study.
		king = "castle", throne_guard_west = "castle", throne_guard_east = "castle",
		door_guard_west = "castle", door_guard_east = "castle",
		hall_idle_west = "castle", hall_idle_east = "castle",
		hall_idle_service = "castle",
		-- The study moved template rows only: the court's furniture went east
		-- with the forge, and these three stand at it.
		court_idle_forge = "court", court_idle_yard = "court", court_idle_fire = "court",
	},
	-- the next capital
	lethariel = {
		-- The castle's own rows follow the picked template, not the 2D study.
		king = "castle", throne_guard_west = "castle", throne_guard_east = "castle",
		door_guard_west = "castle", door_guard_east = "castle",
		hall_idle_west = "castle", hall_idle_east = "castle",
		hall_idle_service = "castle",
	},
	-- the next capital
	nhal_veyr = {},
	-- the next capital
	gor_drazhak = {},
	-- the next capital
	kezamba = {},
}

local CAPITALS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}

------------------------------------------------------------------------------
-- The body model.
------------------------------------------------------------------------------
local EPS = 1e-6
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
local PLAYER = {height = 1.7, step = 0.5}

local function kind_of(name, param2)
	if name == nil or name == "air" or name:match("^doors:") then return nil end
	local def = NODES[name]
	if def and def.walkable == false then return nil end
	if name:match("_stair_inner$") or name:match("_stair_outer$") then return "corner" end
	if name:match("stair") then
		if param2 >= 20 then return "solid" end
		return "stair", param2 % 4
	end
	if name:match("slab") and param2 < 20 then return "slab" end
	return "solid"
end

local function map_of(cells)
	local at = {}
	for _, cell in ipairs(cells) do at[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell end
	return at
end

local function walker(at, body)
	local function node(x, y, z)
		local cell = at[x .. ":" .. y .. ":" .. z]
		if not cell then return nil end
		return kind_of(cell.name, cell.param2 or 0)
	end
	local function clear(x, z, s, support)
		for y = math.floor(s) - 1, math.ceil(s + body.height) + 1 do
			if y ~= support then
				local k = node(x, y, z)
				if k then
					local lo, hi = y - 0.5, y + 0.5
					if k == "slab" then hi = y end
					if lo < s + body.height - EPS and hi > s + EPS then return false end
				end
			end
		end
		return true
	end
	local function arrivals(x, z, h, dx, dz)
		local out = {}
		for y = math.floor(h) - 2, math.floor(h) + 2 do
			local k, face = node(x, y, z)
			local tops
			if k == "solid" or k == "corner" then tops = {y + 0.5}
			elseif k == "slab" then tops = {y}
			elseif k == "stair" then
				local fx, fz = parts.facedir_step(face)
				if fx == dx and fz == dz then tops = {y}
				elseif fx == -dx and fz == -dz then tops = {y + 0.5}
				else tops = {y, y + 0.5} end
			end
			for _, s in ipairs(tops or {}) do
				if s - h <= body.step + EPS and h - s <= 1 + EPS then
					out[#out + 1] = {s = s, support = y, face = k == "stair" and face or nil}
				end
			end
		end
		return out
	end
	-- Everything reachable from `start`: seen["x:z:s"] = state.
	local function flood(start, limit)
		local function key(st) return st.x .. ":" .. st.z .. ":" .. st.s end
		local seen = {[key(start)] = start}
		local queue, head = {start}, 1
		while queue[head] do
			local st = queue[head]
			head = head + 1
			local moves = {}
			if st.face then
				local other = st.s < st.support + 0.25 and st.support + 0.5 or st.support
				if clear(st.x, st.z, math.max(other, st.s), st.support) then
					moves[#moves + 1] = {x = st.x, z = st.z, s = other, support = st.support,
						face = st.face}
				end
			end
			for _, d in ipairs(DIRS) do
				local nx, nz = st.x + d[1], st.z + d[2]
				for _, a in ipairs(arrivals(nx, nz, st.s, d[1], d[2])) do
					local top = math.max(a.s, st.s)
					if clear(nx, nz, a.s, a.support) and clear(nx, nz, top, a.support) and
							clear(st.x, st.z, top, st.support) then
						moves[#moves + 1] = {x = nx, z = nz, s = a.s, support = a.support,
							face = a.face}
					end
				end
			end
			for _, m in ipairs(moves) do
				local k = key(m)
				if not seen[k] then
					seen[k] = m
					queue[#queue + 1] = m
					if #queue > (limit or 1000000) then return seen end
				end
			end
		end
		return seen
	end
	return {node = node, clear = clear, flood = flood}
end

-- The surface under feet cell (x, y, z): y - 0.5 on a full node, y - 1 on a
-- slab, or a step's halves; falls one node when the feet cell itself is a tread.
local function surface(w, x, y, z)
	for support = y, y - 2, -1 do
		local k = w.node(x, support, z)
		if k == "solid" or k == "corner" then return support + 0.5, support end
		if k == "slab" then return support, support end
		if k == "stair" then return support + 0.5, support end
	end
	return nil
end

-- Is the state set holding a place at feet cell (x, y, z), give or take a tread?
local function reached(seen, x, y, z)
	for dy = -1.5, 1, 0.5 do
		if seen[x .. ":" .. z .. ":" .. (y + dy)] then return true end
	end
	return false
end

------------------------------------------------------------------------------
-- S. The size.
------------------------------------------------------------------------------
check(ring.RADIUS == 56 and ring.PAD == 57 and ring.CIVIC_WIDTH == 112,
	"S precinct_ring is radius 56, pad 57, width 112")
check(planner.DEFAULTS.CORE == ring.RADIUS and planner.DEFAULTS.CORE_GATE == ring.PAD and
	planner.DEFAULTS.CORE_KEEP == ring.PAD + 3, "S the planner reads the ring")
local bounds = settlement.BOUNDS.capital_core
check(bounds.max.x == ring.PAD and bounds.min.z == -ring.PAD, "S BOUNDS.capital_core reads the ring")
do
	local widths = 0
	for _, row in ipairs(dofile(wp40 .. "/source/simple_map.lua").anchor_profiles) do
		if row.civic_width then
			widths = widths + 1
			check(row.civic_width == ring.CIVIC_WIDTH, "S profile " .. row.id .. " civic_width")
		end
	end
	check(widths == 6, "S six capital profiles")
	-- The two copies that cannot read the module: the lakes' calm squares
	-- and the cloud base's samples.
	local calm = 0
	for half in read("mods/MAPGEN/grug_mapgen/wp40/water_authored.lua"):gmatch(
			"keep = {x = 1800, z = %-?1500, half = (%d+)") do
		calm = calm + 1
		check(tonumber(half) == ring.PAD, "S a civic lake's calm square is the pad")
	end
	check(calm == 2, "S two civic lakes")
	check(tonumber(read("mods/CORE/grug_core/atmosphere_zones.lua"):match(
		"local CIVIC_HALF = (%d+)")) == ring.RADIUS, "S atmosphere_zones' CIVIC_HALF is the ring")
end

------------------------------------------------------------------------------
-- The schedule (tools/r70_design), per capital id -> {x, y, z}.
------------------------------------------------------------------------------
local function schedule(capital)
	local text = read("tools/r70_design/data/socket-schedules.json")
	local data = json.parse(text)
	local rows = {}
	for _, row in ipairs(data[capital]) do rows[row.id] = row end
	return rows
end

------------------------------------------------------------------------------
-- One capital.
------------------------------------------------------------------------------
local function capital_tests(capital)
	local label = capital .. " "
	local composition = library.composition(capital)
	local bp = composition.core()
	local at = map_of(bp.cells)
	local lm = bp.landmarks

	-- B
	local outside = 0
	for _, cell in ipairs(bp.cells) do
		if cell.x < bounds.min.x or cell.x > bounds.max.x or cell.z < bounds.min.z or
				cell.z > bounds.max.z or cell.y < bounds.min.y or cell.y > bounds.max.y then
			outside = outside + 1
		end
	end
	check(outside == 0, "B " .. label .. outside .. " cells outside BOUNDS.capital_core")
	for _, gate in ipairs({"gate_south", "gate_west", "gate_east", "gate_north"}) do
		local spot = lm[gate]
		-- Lethariel's gate_north names the lake's tip: it has no north gate.
		if spot and not (capital == "lethariel" and gate == "gate_north") then
			check(math.max(math.abs(spot.x), math.abs(spot.z)) == ring.PAD,
				"S " .. label .. gate .. " landmark on the pad's edge")
		end
	end

	-- T
	local walk = walker(at, PLAYER)
	for _, socket in ipairs(lm.sockets) do
		check(math.max(math.abs(socket.x), math.abs(socket.z)) <= ring.PAD,
			"T " .. label .. socket.id .. " inside the pad")
		if DONE[capital] then
			local s, support = surface(walk, socket.x, socket.y, socket.z)
			check(s ~= nil and walk.clear(socket.x, socket.z, s, support),
				"T " .. label .. socket.id .. " at " .. socket.x .. "," .. socket.y .. "," ..
					socket.z .. " is a standing point")
		end
	end
	if not DONE[capital] then return end

	-- R
	local columns, gaps = 0, 0
	ring.walk(function(x, z)
		-- The core writes nothing over water: only columns with ground count.
		if not walk.node(x, 0, z) then return end
		columns = columns + 1
		if not walk.node(x, 1, z) then
			gaps = gaps + 1
			print("note " .. label .. "ring gap at " .. x .. "," .. z)
		end
	end, {skip = ring.is_corner})
	check(columns > 200 and gaps == 0, "R " .. label .. "the ring is closed (" .. gaps .. " gaps)")

	-- W
	local start = {x = 0, z = 0, s = 0.5, support = 0}
	local seen = walk.flood(start)
	for _, socket in ipairs(lm.sockets) do
		-- The waystone stands in the travel socket's own cell: a neighbour counts.
		local near = socket.role == "waypoint" and reached(seen, socket.x + 1, socket.y, socket.z)
		check(near or reached(seen, socket.x, socket.y, socket.z),
			"W " .. label .. socket.id .. " at " .. socket.x .. "," .. socket.y .. "," ..
				socket.z .. " reached on foot from the crossing")
	end
	for _, spot in ipairs(lm.destinations) do
		check(reached(seen, spot.x, spot.y, spot.z), "W " .. label .. spot.id .. " inside reached")
	end

	-- C, K
	local castle = CASTLE[capital]
	local by_id = {}
	for _, socket in ipairs(lm.sockets) do by_id[socket.id] = socket end
	local king = by_id.king
	if check(king ~= nil, "C " .. label .. "has the king's socket") and castle then
		local guards = 0
		for _, socket in ipairs(lm.sockets) do
			if socket.id:match("^throne_guard_") then
				guards = guards + 1
				local dx, dz = socket.x - king.x, socket.z - king.z
				check(socket.role == "guard_post" and dx * dx + dz * dz <= 25,
					"C " .. label .. socket.id .. " holds a post within 5 m of the seat")
			end
		end
		check(guards == 2, "C " .. label .. "two throne guards")
		local royal = read("mods/ENTITIES/grug_mobs/start_npcs.lua"):match(
			"local ROYAL_GUARD_SOCKET = (%b{})")
		check(royal ~= nil and royal:find("throne_guard_west", 1, true) ~= nil and
			royal:find("door_guard", 1, true) == nil,
			"C only the throne guards bind to the king")
		local door = lm[castle.plot .. "_door"] or lm.kings_hall_door
		for _, id in ipairs({"door_guard_west", "door_guard_east"}) do
			check(by_id[id] and by_id[id].role == "guard_post" and
				math.max(math.abs(by_id[id].x - door.x), math.abs(by_id[id].z - door.z)) <= 6,
				"C " .. label .. id .. " an ordinary post at the great door")
		end
		check((lm[castle.plot] or lm.kings_hall).max.y <= bounds.max.y + 2,
			"C " .. label .. "the castle's top inside the core's height")

		-- The king's real body: the player box at 8/7, the elite scale 1.4.
		local source = read("mods/ENTITIES/grug_mobs/bosses.lua")
		local scale = 8 / 7 * 1.4
		local KING = {height = 1.7 * scale, step = 1.0}
		check(source:find("stepheight = 1.1", 1, true) ~= nil and
			source:find("1.7 * 8 / 7", 1, true) ~= nil, "K the king's body data unchanged")
		local leash = tonumber(source:match("_grug_leash_range = (%d+)"))
		local body = walker(at, KING)
		local seat_s = surface(body, king.x, king.y, king.z)
		local _, seat_support = surface(body, king.x, king.y, king.z)
		local from_seat = body.flood({x = king.x, z = king.z, s = seat_s, support = seat_support})
		-- One node outside the great door, on the forecourt.
		local outside_door = false
		local step_x, step_z = parts.facedir_step(door.face or 2)
		for _, spot in ipairs(lm.doors) do
			if spot.id == castle.plot and spot.x == door.x and spot.z == door.z then
				step_x, step_z = parts.facedir_step(spot.face)
			end
		end
		outside_door = reached(from_seat, door.x + step_x, door.y, door.z + step_z)
		check(outside_door, "K " .. label .. "the king reaches the great door from his seat")
		local dx, dy, dz = door.x - king.x, door.y - king.y, door.z - king.z
		check(math.sqrt(dx * dx + dy * dy + dz * dz) < leash,
			"K " .. label .. "the great door inside his leash of " .. tostring(leash))
		-- Every cell of the dais top: the socket's row and the row before it,
		-- across the dais, in the hall's frame. Walked by the king, and from
		-- every one the way home exists (the flood is symmetric on a dais with
		-- full steps, and the seat is its start).
		local dais, walked = 0, 0
		for offset = -7, 7 do
			for back = 0, 1 do
				local fx, fz = parts.facedir_step(king.face)
				local x = king.x + (fz ~= 0 and offset or 0) + fx * back
				local z = king.z + (fx ~= 0 and offset or 0) + fz * back
				if body.node(x, king.y - 1, z) and not body.node(x, king.y, z) then
					dais = dais + 1
					if reached(from_seat, x, king.y, z) then walked = walked + 1 end
				end
			end
		end
		check(dais >= 20 and walked == dais, "K " .. label .. "the king walks the dais (" ..
			walked .. " of " .. dais .. ")")
		local to_seat = body.flood({x = door.x + step_x, z = door.z + step_z,
			s = surface(body, door.x + step_x, door.y, door.z + step_z),
			support = select(2, surface(body, door.x + step_x, door.y, door.z + step_z))})
		check(reached(to_seat, king.x, king.y, king.z), "K " .. label .. "he walks home from the door")
	end

	-- P
	local rows = schedule(capital)
	local moved = MOVED[capital] or {}
	for _, socket in ipairs(lm.sockets) do
		local row = rows[socket.id]
		if not moved[socket.id] then
			if check(row ~= nil, "P " .. label .. socket.id .. " has a row") then
				check(row.x == socket.x and row.z == socket.z,
					("P %s%s at %d,%d, its row says %d,%d"):format(label, socket.id,
						socket.x, socket.z, row.x, row.z))
			end
		end
	end
end

for _, capital in ipairs(CAPITALS) do
	if not only or only == capital then capital_tests(capital) end
end

if failures > 0 then
	print(("R70 CAP PORTABLE FAIL failures=%d of checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R70 CAP PORTABLE PASS checks=%d"):format(checks))
