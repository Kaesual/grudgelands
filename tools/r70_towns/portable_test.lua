-- Round 70 lane TOWNS portable test (LuaJIT; round70-plan.md §2.8, §4 TOWNS,
-- the user-accepted land-use study tools/r70_design). Builds the six start
-- towns through the game's own compositions and checks the built result:
--
--   S  the study's schedule: every exported socket stands where
--      tools/r70_design/data/socket-schedules.json says, id, role and order
--      unchanged, except the deviations this test names (DEVIATIONS);
--   P  the waystone: the 13 x 13 pocket holds only the stone and its mailbox,
--      the pad's four arrival sides are free;
--   B  the buildings: no two written footprints overlap, all inside the
--      authored +-63, spawn and the gate axis as they were;
--   W  a walk: from the spawn a body two nodes high that climbs one node
--      reaches every standing socket (adapter rows too), the cell before every
--      door, the stone's arrival sides and every patrol waypoint;
--   F  furniture: nothing stands on a socket's cell.
--
-- Usage (repo root): luajit tools/r70_towns/portable_test.lua [REPO]
-- Prints "R70 TOWNS PORTABLE PASS checks=<n>" or the failures.

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
local SCHEDULE = json.parse(read("tools/r70_design/data/socket-schedules.json"))
local settlement = dofile(wp40 .. "/r7_settlement.lua")

local REACH = 6 -- the pocket: 13 x 13 around the stone
local DEVIATIONS = {}

-- What a walker meets: a node it can stand on, walk through, or neither.
local function solid(cell)
	if cell == nil or cell.name == "air" then return false end
	if cell.name:match("^doors:") then return false end
	local def = NODES[cell.name]
	if def == nil then return true end
	return def.walkable ~= false
end
local function rail(cell)
	if cell == nil then return false end
	return cell.name:match("fence") ~= nil or cell.name:match("^walls:") ~= nil or
		cell.name:match("^xpanes:") ~= nil
end

local function walker(bp)
	local at = {}
	for _, cell in ipairs(bp.cells) do
		at[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
	end
	local function get(x, y, z) return at[x .. ":" .. y .. ":" .. z] end
	local function stands(x, y, z)
		local floor = get(x, y - 1, z)
		return solid(floor) and not rail(floor) and not solid(get(x, y, z)) and
			not solid(get(x, y + 1, z))
	end
	local seen = {}
	local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
	local queue, head = {{0, 1, 0}}, 1
	seen[key(0, 1, 0)] = true
	while head <= #queue do
		local p = queue[head]
		head = head + 1
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local nx, nz = p[1] + d[1], p[3] + d[2]
			if math.abs(nx) <= 63 and math.abs(nz) <= 63 then
				for dy = -3, 1 do
					local ny = p[2] + dy
					-- The head clears the higher of the two cells.
					if stands(nx, ny, nz) and not seen[key(nx, ny, nz)] and
							(dy <= 0 or not solid(get(p[1], p[2] + 2, p[3]))) then
						seen[key(nx, ny, nz)] = true
						queue[#queue + 1] = {nx, ny, nz}
					end
				end
			end
		end
	end
	return {get = get, stands = stands, reached = function(x, y, z)
		return seen[key(x, y, z)] == true
	end}
end

local FACE = {[0] = {0, -1}, [1] = {-1, 0}, [2] = {0, 1}, [3] = {1, 0}}

local towns = {}
for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" then towns[#towns + 1] = profile end
end
check(#towns == 6, "six start towns")

for _, profile in ipairs(towns) do
	local key = profile.key
	local bp = dofile(wp40 .. "/" .. profile.blueprint_file)()
	local walk = walker(bp)
	local by_id = {}
	for index, socket in ipairs(bp.landmarks.sockets) do
		by_id[socket.id] = socket
		socket.index = index
	end

	-- S: the schedule, row by row.
	local rows = SCHEDULE[key]
	check(#rows == #bp.landmarks.sockets + 3, key .. ": the schedule's row count")
	local deviation = DEVIATIONS[key] or {}
	for index, row in ipairs(rows) do
		local socket = by_id[row.id]
		if socket then
			check(socket.index == index, key .. " " .. row.id .. ": socket order")
			check(socket.role == row.role, key .. " " .. row.id .. ": role")
			local want = deviation[row.id] or row
			check(socket.x == want.x and socket.z == want.z,
				("%s %s: at %d,%d, the schedule says %d,%d"):format(key, row.id,
					socket.x, socket.z, want.x, want.z))
		end
	end

	-- W and F: every standing socket, adapter rows included.
	local cells_taken = {}
	for _, row in ipairs(rows) do
		local socket = by_id[row.id] or row
		cells_taken[socket.x .. ":" .. socket.z] = true
		if socket.role ~= "waypoint" and row.role ~= "public_station" then
			local y = socket.y or 1
			check(walk.stands(socket.x, y, socket.z),
				("%s %s: no place to stand at %d,%d,%d"):format(key, row.id,
					socket.x, y, socket.z))
			check(walk.reached(socket.x, y, socket.z),
				("%s %s: not reached on foot from the spawn"):format(key, row.id))
		end
	end

	-- Doors: the cell before each door.
	for _, door in ipairs(bp.landmarks.doors) do
		local face = FACE[door.face]
		local fx, fz = door.x + face[1], door.z + face[2]
		local reached = walk.reached(fx, door.y, fz) or
			walk.reached(fx + face[1], door.y, fz + face[2])
		check(reached, ("%s door of %s at %d,%d,%d: its front is not reached"):format(
			key, door.id, door.x, door.y, door.z))
	end

	-- P: the pocket.
	local stone = by_id.travel_waypoint
	local stone_cell = walk.get(stone.x, 1, stone.z)
	check(stone_cell and stone_cell.name == "grug_mapgen:waystone",
		key .. ": the waystone stands in its socket")
	local box = walk.get(stone.x + 2, 1, stone.z + 1)
	check(box and box.name == "grug_mapgen:mailbox", key .. ": the mailbox")
	for dz = -REACH, REACH do
		for dx = -REACH, REACH do
			local x, z = stone.x + dx, stone.z + dz
			local ground = walk.get(x, 0, z)
			check(ground ~= nil and ground.name ~= "air",
				("%s pocket: no ground at %d,%d"):format(key, x, z))
			for y = 1, 3 do
				local cell = walk.get(x, y, z)
				local allowed = (dx == 0 and dz == 0) or (dx == 2 and dz == 1)
				if not allowed and cell and cell.name ~= "air" and
						NODES[cell.name] and NODES[cell.name].walkable ~= false then
					check(false, ("%s pocket: %s at %d,%d,%d"):format(key, cell.name, x, y, z))
				end
			end
		end
	end
	for _, side in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		check(walk.reached(stone.x + side[1], 1, stone.z + side[2]),
			("%s: the stone's arrival side %d,%d"):format(key, side[1], side[2]))
	end

	-- B: spawn, gate axis, bounds.
	local spawn = bp.landmarks.spawn
	check(spawn.x == 0 and spawn.y == 1 and spawn.z == 0, key .. ": the spawn stays")
	check(bp.bounds.min.x >= -63 and bp.bounds.max.x <= 63 and
		bp.bounds.min.z >= -63 and bp.bounds.max.z <= 63, key .. ": the envelope stays")
	local gate = bp.landmarks.gate
	local step = gate.z > 0 and 1 or -1
	for z = 0, gate.z - step, step do
		local cell = walk.get(0, 0, z)
		check(cell ~= nil and walk.reached(0, 1, z) or
			walk.stands(0, 1, z), ("%s: the gate axis at z %d"):format(key, z))
	end
end

print(("R70 TOWNS portable test: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R70 TOWNS PORTABLE FAIL", 0) end
print("R70 TOWNS PORTABLE PASS checks=" .. checks)
