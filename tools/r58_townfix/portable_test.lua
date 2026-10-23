-- Round 58 lane TOWNFIX portable test (LuaJIT; round58-plan.md §4 TOWNFIX,
-- the user's rulings of 2026-10-22 in round56-plan.md §8 "Towns"). Builds the
-- parts, the capital cores and the start towns through the game's own loader
-- and compositions and walks them with a small player model (below):
--
--   B  Lethariel's bough platforms: from the ground at the stair's foot up
--      the stair to the hall door, for both platforms (the deck-6 stair was
--      blocked by a beam, the rail stood in front of the door);
--   G  the five core gatehouses: from the east chamber's door up the new
--      inner stair to the first floor, every tread entered and left along
--      its own axis (no corner step) and the turn made on a landing, then on
--      up the roof stair to the deck; the doors one node towards the passage
--      with their idle posts, the deck opening four nodes, the first-floor
--      walls closed;
--   R  the royal guards' posts in the six king halls within the follow
--      distance (5 m) of the king's seat (their no-wander and the post they
--      hold are tools/r41_mob's case P);
--   W  the gate watch of every core gate: no passage posts and no tower
--      loop, the deck a post, two loops of four corners on the city side
--      walking one rectangle in opposite directions, every corner and leg
--      on open ground, the loop's own waypoint reach (patrol.lua), three
--      guards per gate;
--   T  the terrace stair (dressing.terrace): lifts 1 to 5 climbed half a
--      node at a time with `lift` treads, and Silverleaf's two terrace
--      houses walked from the lane to the door;
--   S  the six start towns: the waystone at the centre next to the
--      Quartermaster, its mailbox beside it, the travel socket's id.
--
-- THE PLAYER MODEL: a node k spans k-0.5 .. k+0.5; a full node's top is
-- k+0.5, a bottom slab's k, a stair's lower half k and its raised half k+0.5
-- on the side its facedir points to. A step may climb half a node (the
-- engine's stepheight is 0.6) and drop one; the body (1.7) must clear
-- every walkable node of the column it stands in and of the one it leaves.
-- Walkability is the node registry's (tools/building_templates/nodes.json);
-- a fence is as walkable as a block. With `axis_only` a stair is entered and
-- left only along its own axis, so a path found that way has no corner step.
--
-- Usage (repo root): luajit tools/r58_townfix/portable_test.lua [REPO]
-- Prints "R58 TOWNFIX PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
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
local templates = dofile(wp13 .. "/templates.lua")(wp13)
local library = dofile(wp40 .. "/r7_wp13_library.lua")

------------------------------------------------------------------------------
-- The player model.
------------------------------------------------------------------------------
local BODY = 1.7 -- the player's collision box (player_api/init.lua)
local EPS = 1e-6
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

-- A cell map: key "x:y:z" -> {name, param2}.
local function map_of(cells)
	local at = {}
	for _, cell in ipairs(cells) do
		at[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
	end
	return at
end

-- What a node is to a walker: nil (passable), "solid", "slab", "stair",
-- "corner" (an inner or outer stair); `extra` names that classify otherwise
-- (the test palette of T).
local function kind_of(name, param2, extra)
	if extra and extra[name] then return extra[name], param2 % 4 end
	if name == nil or name == "air" or name:match("^doors:") then return nil end
	local def = NODES[name]
	if def and def.walkable == false then return nil end
	if name:match("_stair_inner$") or name:match("_stair_outer$") then return "corner" end
	if name:match("stair") then
		-- an upside-down stair is a ceiling to a walker, never a tread
		if param2 >= 20 then return "solid" end
		return "stair", param2 % 4
	end
	if name:match("slab") and param2 < 20 then return "slab" end
	return "solid"
end

local function walker(at, extra)
	local function node(x, y, z)
		local cell = at[x .. ":" .. y .. ":" .. z]
		if not cell then return nil end
		return kind_of(cell.name, cell.param2 or 0, extra)
	end
	-- The body standing at surface `s` in column x, z clears every node but
	-- the one it stands on (`support`).
	local function clear(x, z, s, support)
		for y = math.floor(s) - 1, math.ceil(s + BODY) + 1 do
			if y ~= support then
				local k = node(x, y, z)
				if k then
					local lo, hi = y - 0.5, y + 0.5
					if k == "slab" then hi = y end
					if lo < s + BODY - EPS and hi > s + EPS then return false end
				end
			end
		end
		return true
	end
	-- The surfaces a walker can arrive on in column x, z coming along
	-- (dx, dz) from surface h: {s, support, stair face or nil}.
	local function arrivals(x, z, h, dx, dz, axis_only)
		local out = {}
		for y = math.floor(h) - 2, math.floor(h) + 1 do
			local k, face = node(x, y, z)
			local tops
			if k == "solid" then tops = {y + 0.5}
			elseif k == "slab" then tops = {y}
			elseif k == "stair" then
				local fx, fz = parts.facedir_step(face)
				if fx == dx and fz == dz then tops = {y} -- up its front
				elseif fx == -dx and fz == -dz then tops = {y + 0.5} -- onto its raised half
				elseif not axis_only then tops = {y, y + 0.5} end
			end
			for _, s in ipairs(tops or {}) do
				if s - h <= 0.5 + EPS and h - s <= 1 + EPS then
					out[#out + 1] = {s = s, support = y, face = k == "stair" and face or nil}
				end
			end
		end
		return out
	end
	-- Breadth first from `start` {x, z, s, support}; `goal(state)` ends it.
	-- Returns the path (a list of states) or nil.
	local function search(start, goal, axis_only, limit)
		local function key(st) return st.x .. ":" .. st.z .. ":" .. st.s end
		local seen = {[key(start)] = true}
		local queue, head = {start}, 1
		while queue[head] do
			local st = queue[head]
			head = head + 1
			if goal(st) then
				local path = {}
				while st do table.insert(path, 1, st); st = st.parent end
				return path
			end
			local moves = {}
			-- a stair's two halves are one cell: its front climbs to its back
			-- and its back steps down to its front
			if st.face then
				local other = st.s < st.support + 0.25 and st.support + 0.5 or st.support
				if clear(st.x, st.z, math.max(other, st.s), st.support) then
					moves[#moves + 1] = {x = st.x, z = st.z, s = other, support = st.support,
						face = st.face, dir = st.dir}
				end
			end
			for _, d in ipairs(DIRS) do
				local leaving_ok = true
				if st.face and axis_only then
					local fx, fz = parts.facedir_step(st.face)
					leaving_ok = (fx == d[1] and fz == d[2]) or (fx == -d[1] and fz == -d[2])
				end
				if st.face then
					-- along the rise from the raised half, against it from the lower
					local fx, fz = parts.facedir_step(st.face)
					if fx == d[1] and fz == d[2] and st.s < st.support + 0.5 - EPS then
						leaving_ok = false
					elseif fx == -d[1] and fz == -d[2] and st.s > st.support + EPS then
						leaving_ok = false
					end
				end
				if leaving_ok then
					local nx, nz = st.x + d[1], st.z + d[2]
					for _, a in ipairs(arrivals(nx, nz, st.s, d[1], d[2], axis_only)) do
						local top = math.max(a.s, st.s)
						if clear(nx, nz, a.s, a.support) and clear(nx, nz, top, a.support) and
								clear(st.x, st.z, top, st.support) then
							moves[#moves + 1] = {x = nx, z = nz, s = a.s, support = a.support,
								face = a.face, dir = d}
						end
					end
				end
			end
			for _, m in ipairs(moves) do
				if not seen[key(m)] then
					seen[key(m)] = true
					m.parent = st
					queue[#queue + 1] = m
					if #queue > (limit or 200000) then return nil end
				end
			end
		end
		return nil
	end
	return {node = node, search = search, clear = clear}
end

-- The standing state on the walkable top below (x, y, z) at feet height y.
local function stand(x, y, z)
	return {x = x, z = z, s = y - 0.5, support = y - 1}
end

-- Every stair of a path entered along its axis, the number of turns the
-- path makes on a cell that is no stair strictly between the heights `lo`
-- and `hi` (a landing), and the treads it climbs.
local function path_shape(path, lo, hi)
	local corner_free, landing_turns, treads = true, 0, 0
	for index = 2, #path do
		local st, prev = path[index], path[index - 1]
		if st.face and st ~= prev and not (st.x == prev.x and st.z == prev.z) then
			treads = treads + 1
			local fx, fz = parts.facedir_step(st.face)
			if not ((fx == st.dir[1] and fz == st.dir[2]) or
					(fx == -st.dir[1] and fz == -st.dir[2])) then
				corner_free = false
			end
		end
		local nxt = path[index + 1]
		if nxt and st.dir and nxt.dir and not st.face and st.s > lo + EPS and
				st.s < hi - EPS and (st.dir[1] ~= nxt.dir[1] or st.dir[2] ~= nxt.dir[2]) then
			landing_turns = landing_turns + 1
		end
	end
	return corner_free, landing_turns, treads
end

-- The part a capital roster builds for one placement, as a cell map.
local function part_cells(capital, template, id, main, roof)
	local part = templates.capital(capital).part(template, id, main, roof)
	local source, count = part.buffer:cells()
	local cells = {}
	for index = 1, count do cells[index] = source[index] end
	return map_of(cells), part
end

------------------------------------------------------------------------------
-- B. Lethariel's bough platforms.
------------------------------------------------------------------------------
for _, case in ipairs({{"lethariel_bough_east", 6}, {"lethariel_bough_west", 7}}) do
	local name, deck = case[1], case[2]
	local at, part = part_cells("lethariel", name, name, "elf")
	local walk = walker(at)
	local door = part.points.doors[1]
	-- the lowest tread and the ground in front of it
	local low
	for k, cell in pairs(at) do
		local kind, face = kind_of(cell.name, cell.param2 or 0)
		if kind == "stair" and (not low or cell.y < low.y) then
			low = {x = cell.x, y = cell.y, z = cell.z, face = face}
		end
	end
	if check(low ~= nil and door ~= nil, "B " .. name .. " has a stair and a door") then
		local fx, fz = parts.facedir_step(low.face)
		local start = stand(low.x - fx, low.y, low.z - fz)
		-- the bough stair ends beside its deck, so its top tread is left
		-- sideways (no axis rule here)
		local path = walk.search(start, function(st)
			return st.x == door.x and st.z == door.z and math.abs(st.s - (door.y - 0.5)) < EPS
		end, false)
		check(path ~= nil, "B " .. name .. ": from the stair's foot up to the hall door (deck " ..
			deck .. ") without a jump")
		check(door.y == deck + 1, "B " .. name .. "'s door stands on its deck")
	end
end

------------------------------------------------------------------------------
-- G. The five core gatehouses.
------------------------------------------------------------------------------
local GATES = {
	{"highcourt", "white", "white_slate"}, {"lethariel", "pale", "pale"},
	{"dur_brannoc", nil, "slate"}, {"nhal_veyr", "crypt", "crypt_vault"},
	{"gor_drazhak", "ors", nil},
}
for _, gate in ipairs(GATES) do
	local capital, main, roof = gate[1], gate[2], gate[3]
	local template = capital .. "_gate_south"
	local label = "G " .. template
	local at, part = part_cells(capital, template, "gate_south", main, roof)
	local walk = walker(at)
	local function name_at(x, y, z)
		local cell = at[x .. ":" .. y .. ":" .. z]
		return cell and cell.name or "air"
	end
	-- the doors and their idle posts
	local doors = part.points.doors
	check(#doors == 2 and doors[1].x == 2 and doors[2].x == 10 and doors[1].z == 6 and
		doors[2].z == 6, label .. ": the doors one node towards the passage (x 2 and 10)")
	for _, x in ipairs({2, 10}) do
		check(name_at(x, 1, 6):match("^doors:door_") ~= nil, label .. ": a door leaf at x " .. x)
	end
	for _, x in ipairs({1, 11}) do
		check(kind_of(name_at(x, 1, 6), 0) == "solid" and kind_of(name_at(x, 2, 6), 0) == "solid",
			label .. ": the old doorway at x " .. x .. " walled")
	end
	local idle = {}
	for _, socket in ipairs(part.points.sockets) do
		if socket.role == "idle" then idle[#idle + 1] = socket end
	end
	check(#idle == 2 and idle[1].x == 2 and idle[2].x == 10,
		label .. ": the idle posts follow the doors")
	-- the inner stair: from the east door to the first floor, no corner step
	local start = stand(10, 1, 6)
	local function first_floor(st)
		return math.abs(st.s - 6.5) < EPS and st.x >= 1 and st.x <= 11 and st.z >= 1 and
			st.z <= 5 and not st.face
	end
	local path = walk.search(start, first_floor, true)
	if check(path ~= nil, label .. ": the inner stair from the ground to the first floor") then
		local corner_free, turns, treads = path_shape(path, 0.5, 6.5)
		check(corner_free, label .. ": every tread entered along its axis (no corner step)")
		check(turns >= 1, label .. ": the stair turns on a landing")
		check(treads >= 6, label .. ": " .. treads .. " treads for the six nodes")
		local in_chamber = true
		for _, st in ipairs(path) do
			if st.face and (st.x < 10 or st.x > 11) then in_chamber = false end
		end
		check(in_chamber, label .. ": the stair stands in the east chamber (right seen from outside)")
	end
	check(walk.search(start, function(st)
		return st.x == 6 and st.z == 3 and math.abs(st.s - 11.5) < EPS
	end, false) ~= nil, label .. ": on up the roof stair to the deck")
	-- the deck opening and the first floor's walls
	local open = 0
	for x = 0, 12 do
		if kind_of(name_at(x, 11, 5), 0) == nil then open = open + 1 end
	end
	check(open == 4, label .. ": the deck opening is " .. open .. " nodes (4)")
	local closed = true
	for _, x in ipairs({0, 12}) do
		for y = 7, 8 do
			for z = 1, 5 do
				if kind_of(name_at(x, y, z), 0) ~= "solid" then closed = false end
			end
		end
	end
	check(closed, label .. ": the first floor's side walls closed")
end

------------------------------------------------------------------------------
-- R. The royal guards' posts beside the king.
------------------------------------------------------------------------------
local HALLS = {
	{"highcourt", "highcourt_kings_hall", "white_slate"},
	{"dur_brannoc", "dur_brannoc_kings_hall", "slate"},
	{"lethariel", "lethariel_kings_hall", "pale"},
	{"nhal_veyr", "nhal_veyr_mausoleum", "crypt", "crypt_vault"},
	{"gor_drazhak", "gor_drazhak_warlord_hall", "ors"},
	{"kezamba", "kezamba_kings_hall", "basalt"},
}
for _, hall in ipairs(HALLS) do
	local _, part = part_cells(hall[1], hall[2], hall[2], hall[3], hall[4])
	local by_id = {}
	for _, socket in ipairs(part.points.sockets) do by_id[socket.id] = socket end
	local king = by_id.king
	for _, id in ipairs({"throne_guard_west", "throne_guard_east"}) do
		local post = by_id[id]
		if check(king ~= nil and post ~= nil, "R " .. hall[2] .. " has the king and " .. id) then
			local dx, dz = post.x - king.x, post.z - king.z
			check(dx * dx + dz * dz <= 25 and post.role == "guard_post",
				("R %s: %s %.1f m from the seat (at most 5)"):format(hall[2], id,
					math.sqrt(dx * dx + dz * dz)))
		end
	end
end

------------------------------------------------------------------------------
-- W. The gate watch.
------------------------------------------------------------------------------
_G.mobs = {grug_nav = {}}
_G.grug_mobs = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/patrol.lua")
local loop_reach = grug_mobs.loop_reach
check(type(loop_reach) == "function", "W patrol.lua has the small loop's reach")
loop_reach = loop_reach or function() return "missing" end
local CORE_GATES = {
	highcourt = {"gate_south", "gate_west", "gate_north", "gate_east"},
	dur_brannoc = {"gate_south", "gate_west", "gate_north", "gate_east"},
	nhal_veyr = {"gate_south", "gate_west", "gate_north", "gate_east"},
	gor_drazhak = {"gate_south", "gate_west", "gate_north", "gate_east"},
	lethariel = {"gate_south", "gate_west", "gate_east"},
}
local AXIS = {gate_south = {"z", -1}, gate_north = {"z", 1}, gate_west = {"x", -1},
	gate_east = {"x", 1}}
local function area2(points)
	local sum = 0
	for index = 1, #points do
		local a, b = points[index], points[index % #points + 1]
		sum = sum + a.x * b.z - b.x * a.z
	end
	return sum
end
for _, capital in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak"}) do
	local bp = library.composition(capital).core()
	local at = map_of(bp.cells)
	local function open(x, z)
		local ground = at[x .. ":0:" .. z]
		if not ground or kind_of(ground.name, ground.param2 or 0) == nil then return false end
		for y = 1, 2 do
			local cell = at[x .. ":" .. y .. ":" .. z]
			if cell and kind_of(cell.name, cell.param2 or 0) ~= nil then return false end
		end
		return true
	end
	local by_id, loops = {}, {}
	for _, socket in ipairs(bp.landmarks.sockets) do
		by_id[socket.id] = socket
		if socket.role == "guard_patrol" then
			loops[socket.group] = loops[socket.group] or {}
			loops[socket.group][socket.order] = socket
		end
	end
	for _, gate in ipairs(CORE_GATES[capital]) do
		local label = "W " .. capital .. " " .. gate
		check(not by_id[gate .. "_post_west"] and not by_id[gate .. "_post_east"] and
			not by_id[gate .. "_rampart"], label .. ": no passage posts, no tower loop")
		check(by_id[gate .. "_deck"] and by_id[gate .. "_deck"].role == "guard_post",
			label .. ": the tower guard holds a post on the deck")
		local axis, side = AXIS[gate][1], AXIS[gate][2]
		local other = axis == "x" and "z" or "x"
		local areas = {}
		for _, name in ipairs({"west", "east"}) do
			local loop = loops[capital .. "_" .. gate .. "_watch_" .. name] or {}
			local ok = #loop == 4
			for _, p in ipairs(loop) do
				-- the city side of the gatehouse (its inner wall at 43) and
				-- within its width
				if p[axis] * side > 42 or math.abs(p[other]) > 6 or not open(p.x, p.z) then
					ok = false
				end
			end
			for index = 1, #loop do
				local a, b = loop[index], loop[index % #loop + 1]
				local steps = math.max(math.abs(b.x - a.x), math.abs(b.z - a.z))
				for step = 0, steps do
					local x = a.x + (b.x - a.x) * step / steps
					local z = a.z + (b.z - a.z) * step / steps
					if not open(x, z) then ok = false end
				end
			end
			check(ok, label .. " watch " .. name .. ": four corners on open ground on the city side, " ..
				"every leg clear")
			areas[name] = area2(loop)
			if #loop == 4 then
				local reach = loop_reach(loop)
				check(reach ~= nil and reach >= 1 and reach < 4,
					label .. " watch " .. name .. ": walked round its corners (reach " ..
						tostring(reach) .. ")")
			end
		end
		check(areas.west ~= 0 and areas.east ~= 0 and areas.west * areas.east < 0 and
			areas.west == -areas.east, label .. ": the two loops walk one rectangle in opposite directions")
		-- who stands at this gate: a post, or a loop's first waypoint
		local guards = 0
		for _, socket in ipairs(bp.landmarks.sockets) do
			if socket.id:sub(1, #gate + 1) == gate .. "_" and (socket.role == "guard_post" or
					(socket.role == "guard_patrol" and socket.order == 1)) then
				guards = guards + 1
			end
		end
		check(guards == 3, label .. ": " .. guards .. " guards (two walking, one on the deck)")
	end
	-- every other loop of the core keeps the plain reach
	for group, loop in pairs(loops) do
		if not group:match("_watch_west$") and not group:match("_watch_east$") then
			check(loop_reach(loop) == nil, "W " .. capital .. " " .. group .. " keeps the 4 m reach")
		end
	end
end

------------------------------------------------------------------------------
-- T. The terrace stair.
------------------------------------------------------------------------------
do
	local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
	local PLAZA, STAIR = "default:cobble", "stairs:stair_cobble"
	local palette = {node = function(role)
		return ({plaza = PLAZA, roof_stair = STAIR})[role] or error(role)
	end}
	for lift = 1, 5 do
		for _, side in ipairs({"z-", "z+", "x-", "x+"}) do
			local buf = parts.buffer()
			for x = -12, 12 do
				for z = -12, 12 do buf:put(x, 0, z, PLAZA) end
			end
			dressing.terrace(buf, palette, -2, -2, 2, 2, lift, side)
			local source, count = buf:cells()
			local cells = {}
			for index = 1, count do cells[index] = source[index] end
			local at = map_of(cells)
			local walk = walker(at)
			-- the treads of the flight's middle line
			local treads, along_x = 0, side == "z-" or side == "z+"
			for _, cell in ipairs(cells) do
				if cell.name == STAIR and ((along_x and cell.x == 0) or
						(not along_x and cell.z == 0)) then
					treads = treads + 1
				end
			end
			check(treads == lift, ("T lift %d %s: %d treads (%d)"):format(lift, side, treads, lift))
			local sx, sz = 0, 0
			if side == "z-" then sz = -2 - lift - 1 elseif side == "z+" then sz = 2 + lift + 1
			elseif side == "x-" then sx = -2 - lift - 1 else sx = 2 + lift + 1 end
			local path = walk.search(stand(sx, 1, sz), function(st)
				return st.x == 0 and st.z == 0 and math.abs(st.s - (lift + 0.5)) < EPS
			end, true)
			check(path ~= nil, ("T lift %d %s: from the ground onto the podium without a jump"):format(
				lift, side))
		end
	end
end

------------------------------------------------------------------------------
-- S. The start towns' waystone, and Silverleaf's terrace houses (T).
------------------------------------------------------------------------------
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local starts = 0
for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" then
		starts = starts + 1
		local bp = dofile(wp40 .. "/" .. profile.blueprint_file)()
		local at = map_of(bp.cells)
		local stone, vendor
		for _, socket in ipairs(bp.landmarks.sockets) do
			if socket.id == "travel_waypoint" and socket.role == "waypoint" then stone = socket end
			if socket.role == "vendor" and socket.kind == "race" then vendor = socket end
		end
		local label = "S " .. profile.key
		if check(stone ~= nil and vendor ~= nil, label .. " has its waystone socket and Quartermaster") then
			local dx, dz = stone.x - vendor.x, stone.z - vendor.z
			local d = math.sqrt(dx * dx + dz * dz)
			check(d <= 6, ("%s: the waystone %.1f m from the Quartermaster"):format(label, d))
			local spawn = bp.landmarks.spawn or bp.landmarks.arrival
			local sx, sz = stone.x - spawn.x, stone.z - spawn.z
			check(sx * sx + sz * sz <= 12 * 12, label .. ": at the town's centre (within 12 of the spawn)")
			local cell = at[stone.x .. ":1:" .. stone.z]
			check(cell and cell.name == "grug_mapgen:waystone", label .. ": the waystone stands in its socket")
			local box = at[(stone.x + 2) .. ":1:" .. (stone.z + 1)]
			check(box and box.name == "grug_mapgen:mailbox",
				label .. ": the mailbox beside it (its name: the waystone within 16)")
			-- the Quartermaster is not crowded: the cell he faces is free of
			-- the stone and the box, and the box is no side neighbour of his
			local fx, fz = vendor.x + vendor.dir.x, vendor.z + vendor.dir.z
			check(not (fx == stone.x and fz == stone.z) and
				not (fx == stone.x + 2 and fz == stone.z + 1) and
				math.abs(stone.x + 2 - vendor.x) + math.abs(stone.z + 1 - vendor.z) >= 2,
				label .. ": the waystone and the mailbox leave the Quartermaster room")
		end
		if profile.key == "silverleaf" then
			local walk = walker(at)
			for _, x in ipairs({-19, 19}) do
				local path = walk.search(stand(x, 1, -24), function(st)
					return st.x == x and st.z == -18 and math.abs(st.s - 3.5) < EPS
				end, true)
				check(path ~= nil, "T Silverleaf's terrace house at x " .. x ..
					": from the lane up the terrace stair to the door without a jump")
			end
		end
	end
end
check(starts == 6, "S six start towns")

print(("R58 TOWNFIX portable test: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R58 TOWNFIX PORTABLE FAIL", 0) end
print("R58 TOWNFIX PORTABLE PASS checks=" .. checks)
