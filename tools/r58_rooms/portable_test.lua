-- Round 58 lane ROOMS portable test (LuaJIT): the Miner's Guild lift rooms,
-- mostly on a stub camp list (camps at chosen chunk corners), and on the
-- real camps of three seeds (W).
--
--   luajit tools/r58_rooms/portable_test.lua [REPO]
--
-- A. The room module (wp40/guild_rooms.lua): every stub camp's rooms at its
--    tiers' floors, the box, the lift cell, the arrival, room_at inside and
--    outside (rounding included), the shape (three exits ending at the box
--    face, four lamps, the mantle), the index's refusals and determinism,
--    every box inside one y chunk and the -50 box below the writer's
--    authored floor (y -37).
-- W. The real camps through the game's seam (`lift_camps`, CAMPS'
--    r58_camps.lua) on seeds 42, 12345 and 5575844014311305038: 36 camps,
--    148 rooms, no two boxes meeting, each in one y chunk, deterministic.
-- B. The room step (wp40/guild_room_writer.lua) on a fake VoxelManip: a box
--    split over chunk edges comes out the same as written by one chunk (the
--    lift node at the lift cell, its front toward the arrival), in
--    either chunk order; every write lies in its own chunk and in a box;
--    calc_lighting on each written part.
-- C. The early-outs: the real air_chunks.lua skips the writer in every room
--    chunk from y -113 down, and the room is written there all the same;
--    r7_mapgen.lua runs the room step after the refinement, outside it.
-- D. A writer veto in the -50 chunk (the real degrade.lua): the refinement's
--    failure is reported, the room is written whole; a failing room step is
--    reported, never raised.
-- E. Liquids: water and lava round two rooms; nothing liquid is left in a
--    box, the liquid right outside stays, the liquid in an exit's plug cell
--    is replaced by the plug and the cell beyond stays; every node the step
--    writes is non-ground-content.
-- F. Protection (wp40/guild_room_protection.lua): inside a box
--    "guild_room", "hard_protected" and protected for both factions; above,
--    below and beside it the wrapped session's answers; the PvP rule and the
--    claim footprints untouched; the real protection.lua's hint
--    "Miner's Guild – protected" in a room.
-- G. The spawn refusals: the real spawn_policy.lua refuses an ambient
--    underground spawn in a room and allows it beside; the real
--    depth_pulse.lua refuses a pulse spot in a room ("refused_protected").
-- H. The nodes (guild_room_nodes.lua on a fake engine with the engine's
--    node defaults): the fill's definition; the travel path's real
--    `passable()` and `safe_arrival()` (grug_home/travel.lua) take the fill
--    and the arrival on the floor.
-- Prints "R58 ROOMS PORTABLE PASS checks=<n>" or raises.

local repo = arg and arg[1] or "."
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end

local R = dofile(wp40 .. "/guild_rooms.lua")
local W = dofile(wp40 .. "/guild_room_writer.lua")

local FLOORS = {-50, -250, -450, -650, -950, -1050}
-- The stub camps: a T2 camp, a T4 camp whose lift column sits on a chunk
-- corner (x 47|48, z -33|-32 on the chunk grid -32 + 80k), a T6 camp.
local CAMPS = {
	{id = "stub_t2", kind = "mining", tier = 2, lift = {x = 200, z = 300},
		levels = {1, 2}},
	{id = "stub_t4_edge", kind = "mining", tier = 4, lift = {x = 47, z = -33},
		levels = {1, 2, 3, 4}},
	{id = "stub_t6", kind = "war", tier = 6, lift = {x = -500, z = 1000},
		levels = {1, 2, 3, 4, 5, 6}},
}
local rooms = R.index(CAMPS, FLOORS)

-- ---------------------------------------------------------------------------
-- A. The room module
-- ---------------------------------------------------------------------------
check(#rooms.list == 12, "A 2 + 4 + 6 rooms: " .. #rooms.list)
for _, camp in ipairs(CAMPS) do
	local list = rooms.rooms_for_camp(camp)
	check(#list == #camp.levels and rooms.rooms_for_camp(camp.id) == list,
		"A " .. camp.id .. " has a room per level")
	for index, room in ipairs(list) do
		local tier = camp.levels[index]
		local at = camp.id .. " T" .. tier
		check(room.camp_id == camp.id and room.tier == tier and
			room.floor_y == FLOORS[tier], "A " .. at .. " at its floor " .. room.floor_y)
		check(room.lift_cell.x == camp.lift.x and room.lift_cell.z == camp.lift.z and
			room.lift_cell.y == room.floor_y, "A " .. at .. " lift cell in the lift column")
		check(room.arrival.x == camp.lift.x and room.arrival.z == camp.lift.z + 1 and
			room.arrival.y == room.floor_y - 0.49, "A " .. at .. " arrival beside the lift")
		check(room.minp.x == camp.lift.x - 6 and room.maxp.x == camp.lift.x + 6 and
			room.minp.z == camp.lift.z - 6 and room.maxp.z == camp.lift.z + 6 and
			room.minp.y == room.floor_y - 3 and room.maxp.y == room.floor_y + 6,
			"A " .. at .. " box 13 x 10 x 13")
		check(rooms.room_at(room.lift_cell) == room and rooms.room_at(room.minp) == room and
			rooms.room_at(room.maxp) == room, "A " .. at .. " room_at inside")
		local mx, my, mz = room.maxp.x, room.maxp.y, room.maxp.z
		check(rooms.room_at({x = mx + 1, y = my, z = mz}) == nil and
			rooms.room_at({x = mx, y = my + 1, z = mz}) == nil and
			rooms.room_at({x = mx, y = my, z = mz + 1}) == nil and
			rooms.room_at({x = room.minp.x, y = room.minp.y - 1, z = room.minp.z}) == nil,
			"A " .. at .. " room_at outside")
		-- Node rounding: .49 stays in the node, .51 is the next one; an exact
		-- half goes away from zero (y: every box is below 0).
		check(rooms.room_at({x = mx + 0.49, y = my + 0.49, z = mz}) == room and
			rooms.room_at({x = mx + 0.51, y = my, z = mz}) == nil and
			rooms.room_at({x = room.minp.x - 0.49, y = room.minp.y - 0.49,
				z = room.minp.z}) == room and
			rooms.room_at({x = room.minp.x - 0.51, y = room.minp.y, z = room.minp.z}) == nil and
			rooms.room_at({x = mx, y = room.minp.y - 0.5, z = mz}) == nil and
			rooms.room_at({x = mx, y = my + 0.5, z = mz}) == room,
			"A " .. at .. " room_at rounds half away from zero")
		-- One y chunk holds the box (chunks -32 + 80k .. +79).
		local chunk_y = math.floor((room.minp.y + 32) / 80)
		check(math.floor((room.maxp.y + 32) / 80) == chunk_y,
			"A " .. at .. " box in one y chunk")
	end
end
check(rooms.room_at({x = 0, y = -50, z = 0}) == nil and rooms.room_at({x = 200, y = 0,
	z = 300}) == nil and rooms.room_at("x") == nil, "A no room elsewhere")
local top_room = rooms.rooms_for_camp("stub_t2")[1]
check(top_room.maxp.y < -37, "A the -50 box tops out below the authored floor -37: " ..
	top_room.maxp.y)
check(rooms.rooms_for_camp("nobody") == nil, "A an unknown camp has no rooms")

-- The shape: counts, the exits, the lamps.
local counts = {}
for dz = -7, 7 do
	for dy = -4, 7 do
		for dx = -7, 7 do
			local kind = R.cell_at_offset(dx, dy, dz)
			if kind then counts[kind] = (counts[kind] or 0) + 1 end
		end
	end
end
-- open room 7*7*4 = 196 (one lift cell), exits 3*3*2 = 18, floor 49 + 9,
-- lamps 4 (in the walls), mantle the rest of 13*13*10 = 1690
check(counts.lift == 1 and counts.fill == 195 + 18 and counts.floor == 58 and
	counts.lamp == 4 and counts.mantle == 1690 - 196 - 18 - 58 - 4 and counts.plug == 3 * 2,
	"A the shape's counts")
for _, exit in ipairs(R.EXITS) do
	local fx, fz = exit[1] * 6, exit[2] * 6
	check(R.cell_at_offset(fx, 0, fz) == "fill" and R.cell_at_offset(fx, 1, fz) == "fill" and
		R.cell_at_offset(fx, 2, fz) == "mantle" and R.cell_at_offset(fx, -1, fz) == "floor" and
		R.cell_at_offset(exit[1] * 7, 0, exit[2] * 7) == "plug" and
		R.cell_at_offset(exit[1] * 7, 1, exit[2] * 7) == "plug" and
		R.cell_at_offset(exit[1] * 7, 2, exit[2] * 7) == nil and
		R.cell_at_offset(exit[1] * 7, -1, exit[2] * 7) == nil and
		R.cell_at_offset(exit[1] * 8, 0, exit[2] * 8) == nil,
		"A an exit runs to the box face and ends in a 1 x 2 plug just past it")
end
check(R.cell_at_offset(0, 0, 7) == nil and R.cell_at_offset(7, 0, 1) == nil,
	"A no plug where no exit is")
for _, room in ipairs(rooms.list) do
	local c = room.lift_cell
	local wmin, wmax = room.write_minp, room.write_maxp
	check(wmin.x == room.minp.x - 1 and wmax.x == room.maxp.x + 1 and
		wmin.z == room.minp.z - 1 and wmax.z == room.maxp.z + 1 and
		wmin.y == room.minp.y and wmax.y == room.maxp.y,
		"A the written extent: the box one node wider in x and z")
	for _, exit in ipairs(R.EXITS) do
		local plug = {x = c.x + exit[1] * 7, y = c.y + 1, z = c.z + exit[2] * 7}
		check(rooms.room_at(plug) == nil and R.cell(room, plug.x, plug.y, plug.z) == "plug",
			"A a plug lies outside the protected box")
	end
end
check(R.cell_at_offset(0, 0, 4) == "mantle" and R.cell_at_offset(0, 0, 6) == "mantle",
	"A no exit in the +z wall")
check(R.cell_at_offset(-4, 2, 0) == "lamp" and R.cell_at_offset(4, 2, 0) == "lamp" and
	R.cell_at_offset(0, 2, -4) == "lamp" and R.cell_at_offset(0, 2, 4) == "lamp" and
	R.cell_at_offset(-5, 2, 0) == "mantle" and R.cell_at_offset(0, 4, 0) == "mantle",
	"A a lamp in each wall, above each exit")
-- Light: a lamp gives 14, one less per node (Manhattan through the open
-- nodes); every open node of the room is within 6 of a lamp.
for dz = -3, 3 do
	for dy = 0, 3 do
		for dx = -3, 3 do
			local nearest = math.huge
			for _, lamp in ipairs(R.LAMPS) do
				nearest = math.min(nearest, math.abs(dx - lamp[1]) + math.abs(dy - lamp[2]) +
					math.abs(dz - lamp[3]))
			end
			check(14 - nearest >= 8, "A light 8 or more at " .. dx .. "," .. dy .. "," .. dz)
		end
	end
end
check(R.cell_at_offset(0, 0, 1) == "fill" and R.cell_at_offset(0, -1, 1) == "floor",
	"A the arrival cell is open over the floor")

-- Determinism and refusals.
check(R.index(CAMPS, FLOORS).summary() == rooms.summary(), "A the same rooms again")
local function refused(camps, label)
	check(not pcall(R.index, camps, FLOORS), "A refuses " .. label)
end
refused({CAMPS[1], CAMPS[1]}, "a camp twice")
refused({CAMPS[1], {id = "near", tier = 2, lift = {x = 212, z = 300}, levels = {1}}},
	"two meeting rooms")
refused({{id = "order", tier = 3, lift = {x = 0, z = 0}, levels = {2, 1}}}, "levels out of order")
refused({{id = "deep", tier = 7, lift = {x = 0, z = 0}, levels = {7}}}, "a tier past 6")
refused({{id = "half", tier = 1, lift = {x = 0.5, z = 0}, levels = {1}}}, "a fractional lift")
check(#R.index({}, {}).list == 0 and R.index({}, {}).room_at({x = 0, y = -50, z = 0}) == nil,
	"A no camps, no rooms")

-- W. The real camps (CAMPS' r58_camps.lua through the game's one seam,
-- `lift_camps`) over three fleet seeds: 36 camps, 148 rooms, no two boxes
-- meeting (the index refuses that), every room in one y chunk, every lift
-- column a node coordinate; the same rooms from a second read.
do
	_G.core = _G.core or {}
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local A = dofile(wp40 .. "/world_assembly.lua")(wp40, common.new_sha256())
	for _, seed in ipairs({"42", "12345", "5575844014311305038"}) do
		local W = A.world(seed)
		W.place()
		local text = W.placement_text
		local camps, floors = R.lift_camps(wp40, text)
		local real = R.index(camps, floors)
		check(#camps == 36 and #real.list == 148, "W seed " .. seed .. ": 36 camps, 148 rooms: " ..
			#camps .. ", " .. #real.list)
		for index = 1, 6 do check(floors[index] == FLOORS[index], "W the floors are CAMPS'") end
		local in_one_chunk = 0
		for _, room in ipairs(real.list) do
			if math.floor((room.minp.y + 32) / 80) == math.floor((room.maxp.y + 32) / 80) then
				in_one_chunk = in_one_chunk + 1
			end
		end
		check(in_one_chunk == 148, "W seed " .. seed .. ": every room in one y chunk")
		check(R.index(R.lift_camps(wp40, text)).summary() == real.summary(),
			"W seed " .. seed .. ": the same rooms again")
		print(("  seed %s: %d camps, %d rooms, digest %s"):format(seed, #camps, #real.list,
			common.hex(common.new_sha256()(real.summary())):sub(1, 16)))
	end
end

-- ---------------------------------------------------------------------------
-- The fake world and VoxelManip
-- ---------------------------------------------------------------------------
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function new_world(fill_at)
	return {nodes = {}, fill_at = fill_at or function() return "default:stone" end}
end
local function world_get(world, x, y, z)
	return world.nodes[key(x, y, z)] or world.fill_at(x, y, z)
end
local function inside(p, lo, hi)
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and
		p.z >= lo.z and p.z <= hi.z
end
-- A mapgen VoxelManip of the chunk minp .. maxp (the emerged area one
-- mapblock wider); `writes` counts set_node_at, `lit` the calc_lighting calls.
local function new_vm(world, minp, maxp, broken)
	local emin = {x = minp.x - 16, y = minp.y - 16, z = minp.z - 16}
	local emax = {x = maxp.x + 16, y = maxp.y + 16, z = maxp.z + 16}
	local vm = {writes = 0, lit = {}}
	function vm:get_emerged_area() return emin, emax end
	function vm:set_node_at(pos, node)
		if broken then error("set_node_at refused") end
		check(inside(pos, minp, maxp), "B a write inside its own chunk")
		check(rooms.room_at(pos) ~= nil or node.name:find("^grug_mapgen:room_plug_t%d$"),
			"B a write inside a room box, or a plug")
		local lift = node.name == R.NODES.lift
		check((node.param1 or 0) == 0 and (node.param2 or 0) == (lift and 2 or 0),
			"B light reset, param2 0 (the lift's front toward +z: 2)")
		world.param2 = world.param2 or {}
		world.param2[key(pos.x, pos.y, pos.z)] = node.param2
		world.nodes[key(pos.x, pos.y, pos.z)] = node.name
		self.writes = self.writes + 1
	end
	function vm:get_node_at(pos)
		return {name = world_get(world, pos.x, pos.y, pos.z)}
	end
	function vm:calc_lighting(low, high, shadow)
		check(inside(low, minp, maxp) and inside(high, minp, maxp) and shadow == true,
			"B calc_lighting on the written part")
		self.lit[#self.lit + 1] = {low = {x = low.x, y = low.y, z = low.z},
			high = {x = high.x, y = high.y, z = high.z}}
	end
	return vm
end
local function chunk_of(x, y, z)
	local function base(v) return math.floor((v + 32) / 80) * 80 - 32 end
	local minp = {x = base(x), y = base(y), z = base(z)}
	return minp, {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
end
-- Every chunk a room's written extent meets, in the order given.
local function room_chunks(room_list, reverse)
	local seen, list = {}, {}
	for _, room in ipairs(room_list) do
		local wmin, wmax = room.write_minp, room.write_maxp
		for z = wmin.z, wmax.z, 13 do
			for x = wmin.x, wmax.x, 13 do
				for _, cx in ipairs({x, wmax.x}) do
					for _, cz in ipairs({z, wmax.z}) do
						local minp, maxp = chunk_of(cx, room.minp.y, cz)
						local k = key(minp.x, minp.y, minp.z)
						if not seen[k] then
							seen[k] = true
							list[#list + 1] = {minp, maxp}
						end
					end
				end
			end
		end
	end
	if reverse then
		local reversed = {}
		for index = #list, 1, -1 do reversed[#reversed + 1] = list[index] end
		list = reversed
	end
	return list
end
local write = W.new(R, rooms)

-- ---------------------------------------------------------------------------
-- B. Chunk edges
-- ---------------------------------------------------------------------------
local edge_rooms = rooms.rooms_for_camp("stub_t4_edge")
local whole = new_world()
do
	local minp, maxp = {x = -31000, y = -31000, z = -31000}, {x = 31000, y = 31000, z = 31000}
	local vm = new_vm(whole, minp, maxp)
	check(write(vm, minp, maxp) == 12, "B one big chunk writes every room")
	check(vm.writes == 12 * (1690 + 6), "B every box node and plug written once: " .. vm.writes)
end
for _, reverse in ipairs({false, true}) do
	local split = new_world()
	local chunks = room_chunks(edge_rooms, reverse)
	check(#chunks == 4 * 4, "B the edge camp's rooms meet four chunks each: " .. #chunks)
	local written = 0
	for _, chunk in ipairs(chunks) do
		local vm = new_vm(split, chunk[1], chunk[2])
		check(write(vm, chunk[1], chunk[2]) == 1, "B one room part per chunk")
		check(#vm.lit == 1, "B one lighting call per room part")
		written = written + vm.writes
	end
	check(written == 4 * (1690 + 6), "B the parts add up to the boxes and plugs: " .. written)
	local same = 0
	for _, room in ipairs(edge_rooms) do
		for z = room.write_minp.z, room.write_maxp.z do
			for y = room.write_minp.y, room.write_maxp.y do
				for x = room.write_minp.x, room.write_maxp.x do
					local k = key(x, y, z)
					if split.nodes[k] == whole.nodes[k] and split.nodes[k] ~= nil then
						same = same + 1
					end
				end
			end
		end
	end
	check(same == 4 * (1690 + 6), "B split = whole" .. (reverse and " (reverse order)" or ""))
end
-- The node at each kind.
do
	local room = edge_rooms[3]
	local c = room.lift_cell
	check(whole.nodes[key(c.x, c.y, c.z)] == R.NODES.lift and
		whole.param2[key(c.x, c.y, c.z)] == 2 and
		whole.nodes[key(c.x, c.y, c.z + 1)] == R.NODES.fill and
		whole.nodes[key(c.x, c.y - 1, c.z)] == R.NODES.floor and
		whole.nodes[key(c.x, c.y + 2, c.z + 4)] == R.NODES.lamp and
		whole.nodes[key(c.x, c.y + 5, c.z)] == R.NODES.mantle[3],
		"B the lift facing the arrival, fill, floor, lamp and the tier's mantle")
	check(whole.nodes[key(c.x + 7, c.y, c.z)] == R.NODES.plug[3] and
		whole.nodes[key(c.x + 7, c.y + 1, c.z)] == R.NODES.plug[3] and
		whole.nodes[key(c.x + 7, c.y + 2, c.z)] == nil and
		whole.nodes[key(c.x + 8, c.y, c.z)] == nil, "B the tier's plug past the +x exit")
end
-- A plug alone in a chunk: a box ending on a chunk edge (x 47) has its +x
-- plug in the next chunk (x 48 ..), which the box does not meet; that chunk
-- still writes the plug, and only it.
do
	local lone = R.index({{id = "edge_plug", tier = 1, lift = {x = 41, z = 300},
		levels = {1}}}, FLOORS)
	local room = lone.list[1]
	check(room.maxp.x == 47, "B the box ends on the chunk edge")
	local minp, maxp = chunk_of(48, room.floor_y, 300)
	local world = new_world()
	local vm = new_vm(world, minp, maxp)
	vm.set_node_at = function(_, pos, node)
		check(inside(pos, minp, maxp), "B the plug inside its own chunk")
		world.nodes[key(pos.x, pos.y, pos.z)] = node.name
		vm.writes = vm.writes + 1
	end
	check(W.new(R, lone)(vm, minp, maxp) == 1 and vm.writes == 2 and
		world.nodes[key(48, room.floor_y, 300)] == R.NODES.plug[1] and
		world.nodes[key(48, room.floor_y + 1, 300)] == R.NODES.plug[1],
		"B the next chunk writes the lone plug")
end

-- ---------------------------------------------------------------------------
-- C. The early-outs
-- ---------------------------------------------------------------------------
local air = dofile(wp40 .. "/air_chunks.lua")({
	tile_bounds = function() return 1, -37, 60 end,
	column_bounds = function() return -37, 60 end}, 1)
local severe_reports = {}
local severe = {report = function(source, summary, details, report_key)
	severe_reports[#severe_reports + 1] = {source = source, summary = summary,
		details = details, key = report_key}
end}
local refine_or_degrade = dofile(wp40 .. "/degrade.lua")(severe, function() return "x" end)
local rooms_or_degrade = W.or_degrade(severe, write)
-- r7_mapgen.lua's callback with a refinement that early-outs like the real
-- one and otherwise runs `writer` (a stand-in for the R7 writer).
local function generated(vm, minp, maxp, writer)
	refine_or_degrade(function(v, a, b)
		if air.below(a, b) then return end
		writer(v, a, b)
	end, vm, minp, maxp)
	rooms_or_degrade(vm, minp, maxp)
end
do
	local world = new_world()
	local skipped, ran = 0, 0
	for _, chunk in ipairs(room_chunks(rooms.list)) do
		local vm = new_vm(world, chunk[1], chunk[2])
		generated(vm, chunk[1], chunk[2], function() ran = ran + 1 end)
		if air.below(chunk[1], chunk[2]) then skipped = skipped + 1 end
	end
	-- the edge camp's -50 room meets four chunks, the others one each
	check(ran == 4 + 1 + 1 and skipped == 4 * 3 + 1 + 5,
		"C the writer runs only in the -50 chunks: ran " .. ran .. ", skipped " .. skipped)
	local whole_nodes, missing = 0, 0
	for _, room in ipairs(rooms.list) do
		for z = room.minp.z, room.maxp.z do
			for y = room.minp.y, room.maxp.y do
				for x = room.minp.x, room.maxp.x do
					local k = key(x, y, z)
					whole_nodes = whole_nodes + 1
					if world.nodes[k] ~= whole.nodes[k] then missing = missing + 1 end
				end
			end
		end
	end
	check(missing == 0 and whole_nodes == 12 * 1690,
		"C every room written whole, early-out chunks included")
	check(#severe_reports == 0, "C nothing reported")
end
do
	local source = read(wp40 .. "/r7_mapgen.lua")
	local callback = source:match("core%.register_on_generated%(function%(vmanip, minp, maxp, blockseed%)(.-)\nend%)")
	check(callback ~= nil, "C r7_mapgen.lua's callback found")
	local refined = callback:find("refine_or_degrade(refine, vmanip, minp, maxp)", 1, true)
	local roomed = callback:find("rooms_or_degrade(vmanip, minp, maxp)", 1, true)
	check(refined and roomed and refined < roomed, "C the room step after the refinement")
	local refine_body = source:match("local function refine%(vmanip, minp, maxp%)(.-)\nend\n")
	check(refine_body and not refine_body:find("room", 1, true) and
		refine_body:find("air_chunks.below", 1, true), "C the room step outside the refinement")
	check(source:find("guild_room_writer.lua", 1, true) and
		source:find("rooms_module.lift_camps(wp40,\n\tpayload.placement_layout)", 1, true),
		"C the mapgen env reads the camps from the payload's placement layout")
end

-- ---------------------------------------------------------------------------
-- D. A writer veto in the -50 chunk
-- ---------------------------------------------------------------------------
do
	local world = new_world()
	local room = rooms.rooms_for_camp("stub_t2")[1]
	local minp, maxp = chunk_of(room.lift_cell.x, room.lift_cell.y, room.lift_cell.z)
	check(not air.below(minp, maxp), "D the -50 chunk keeps the writer")
	severe_reports = {}
	generated(new_vm(world, minp, maxp), minp, maxp, function()
		error("fail_settlement: foreign content at (1,2,3) cid=7 class=foreign", 0)
	end)
	check(#severe_reports == 1 and severe_reports[1].key == "mapgen:" ..
		("(%d,%d,%d)"):format(minp.x, minp.y, minp.z), "D the veto reported once")
	local whole_room = true
	for z = room.minp.z, room.maxp.z do
		for y = room.minp.y, room.maxp.y do
			for x = room.minp.x, room.maxp.x do
				local k = key(x, y, z)
				if world.nodes[k] == nil or world.nodes[k] ~= whole.nodes[k] then
					whole_room = false
				end
			end
		end
	end
	check(whole_room, "D the room written whole after the veto")
	severe_reports = {}
	check(rooms_or_degrade(new_vm(world, minp, maxp, true), minp, maxp) == false and
		#severe_reports == 1 and severe_reports[1].key:find("^mapgen_room:") and
		severe_reports[1].summary:find("Miner's Guild room", 1, true),
		"D a failing room step reports and returns")
end

-- ---------------------------------------------------------------------------
-- H (first part). The nodes on a fake engine with the engine's defaults
-- ---------------------------------------------------------------------------
local NODEDEF_DEFAULT = {drawtype = "normal", paramtype = "none", paramtype2 = "none",
	is_ground_content = true, sunlight_propagates = false, walkable = true,
	pointable = true, diggable = true, climbable = false, buildable_to = false,
	floodable = false, liquidtype = "none", damage_per_second = 0, groups = {}}
local registered = {}
local function register(name, def)
	registered[name] = setmetatable(def, {__index = NODEDEF_DEFAULT})
end
register("default:stone", {tiles = {"default_stone.png"}, description = "Stone",
	groups = {cracky = 3, stone = 1, grug_natural = 1, grug_stratum = 1},
	drop = "default:cobble"})
for tier = 2, 6 do
	register("grug_materials:t" .. tier .. "_stone", {tiles = {"grug_materials_t" .. tier ..
		"_stone.png"}, description = "Tier " .. tier .. " rock", drop = "default:cobble",
		groups = {cracky = 3, level = tier, grug_natural = 1, grug_stratum = tier}})
end
register("default:water_source", {drawtype = "liquid", liquidtype = "source",
	walkable = false})
register("default:lava_source", {drawtype = "liquid", liquidtype = "source",
	walkable = false, damage_per_second = 8, is_ground_content = false})
-- CAMPS' lift node (world_nodes.lua): its fields that matter here, checked
-- against the real registration's source below.
register("grug_mapgen:guild_lift", {drawtype = "nodebox", paramtype = "light",
	paramtype2 = "4dir", is_ground_content = false, floodable = false, diggable = false})
register("air", {drawtype = "airlike", walkable = false, pointable = false,
	buildable_to = true, floodable = true, paramtype = "light", sunlight_propagates = true})
do
	_G.grug_materials = {}
	_G.core = {get_modpath = function() return nil end}
	dofile(repo .. "/mods/ITEMS/grug_materials/registry.lua")
	_G.default = {node_sound_stone_defaults = function() return {} end,
		node_sound_glass_defaults = function() return {} end}
	dofile(repo .. "/mods/MAPGEN/grug_mapgen/guild_room_nodes.lua")({
		get_modpath = function(mod)
			assert(mod == "grug_mapgen")
			return repo .. "/mods/MAPGEN/grug_mapgen"
		end,
		registered_nodes = registered,
		register_node = register}, grug_materials)
end
local fill = registered[R.NODES.fill]
check(fill and fill.drawtype == "airlike" and fill.paramtype == "light" and
	fill.sunlight_propagates == true and fill.walkable == false and
	fill.floodable == false and fill.buildable_to == false and
	fill.is_ground_content == false and fill.pointable == false and
	fill.diggable == false and fill.liquidtype == "none" and
	(fill.damage_per_second or 0) == 0 and fill.liquid_move_physics == nil and
	fill.post_effect_color == nil and (fill.light_source or 0) == 0 and fill.drop == "",
	"H the fill: airlike, light passing, no walk, flood, build, point, dig, damage or tint")
local floor_def = registered[R.NODES.floor]
check(floor_def and floor_def.drawtype == "normal" and floor_def.walkable == true and
	floor_def.is_ground_content == false and floor_def.diggable == false,
	"H the floor: a full normal node, non-ground-content")
for tier = 1, 6 do
	local mantle = registered[R.NODES.mantle[tier]]
	local host = registered[grug_materials.TIERS[tier].node]
	check(mantle and mantle.is_ground_content == false and mantle.diggable == false and
		mantle.walkable == true and mantle.tiles[1] == host.tiles[1],
		"H the T" .. tier .. " mantle looks like " .. grug_materials.TIERS[tier].node)
	local plug = registered[R.NODES.plug[tier]]
	check(plug and plug.is_ground_content == false and plug.diggable == true and
		plug.walkable == true and plug.drawtype == "normal" and plug.tiles[1] == host.tiles[1] and
		plug.drop == "default:cobble" and plug.groups.cracky == 3 and
		plug.groups.level == host.groups.level and plug.groups.grug_natural == nil and
		plug.groups.grug_stratum == nil and plug.description == host.description,
		"H the T" .. tier .. " plug digs like its host rock (Cobble), non-ground-content")
end
do
	local source = read(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")
	local block = source:match('register_node%("grug_mapgen:guild_lift", {(.-)\n }%)')
	check(block and block:find("is_ground_content=false", 1, true) and
		block:find("floodable=false", 1, true) and block:find('paramtype2="4dir"', 1, true),
		"H CAMPS' lift node is non-ground-content, not floodable, 4dir")
end
local lamp = registered[R.NODES.lamp]
check(lamp and lamp.is_ground_content == false and lamp.diggable == false and
	lamp.paramtype == "light" and lamp.light_source == 14,
	"H the lamp: light 14 that spreads (paramtype light), non-ground-content")
-- No room node is one the game's content curation removes (default's Mese
-- Lamp is: the first engine run refused it in every room chunk).
do
	local curation = read(repo .. "/mods/ITEMS/grug_materials/content_curation.lua")
	local names = {R.NODES.fill, R.NODES.floor, R.NODES.lamp, R.NODES.lift}
	for _, name in ipairs(R.NODES.mantle) do names[#names + 1] = name end
	for _, name in ipairs(R.NODES.plug) do names[#names + 1] = name end
	for _, name in ipairs(names) do
		check(name:find("^grug_mapgen:") and not curation:find('"' .. name .. '"', 1, true),
			"H " .. name .. " is grug_mapgen's own, never curated away")
	end
end

-- ---------------------------------------------------------------------------
-- E. Liquids round the rooms
-- ---------------------------------------------------------------------------
do
	local wet_room = edge_rooms[4] -- T4, -650
	local hot_room = rooms.rooms_for_camp("stub_t6")[5] -- T5, -950
	local function near(room, x, y, z, reach)
		return x >= room.minp.x - reach and x <= room.maxp.x + reach and
			y >= room.minp.y - reach and y <= room.maxp.y + reach and
			z >= room.minp.z - reach and z <= room.maxp.z + reach
	end
	local world = new_world(function(x, y, z)
		if near(wet_room, x, y, z, 3) then return "default:water_source" end
		if near(hot_room, x, y, z, 3) then return "default:lava_source" end
		return "default:stone"
	end)
	for _, chunk in ipairs(room_chunks({wet_room, hot_room})) do
		write(new_vm(world, chunk[1], chunk[2]), chunk[1], chunk[2])
	end
	for _, case in ipairs({{wet_room, "default:water_source"}, {hot_room,
			"default:lava_source"}}) do
		local room, liquid = case[1], case[2]
		local liquid_inside, ground_content, outside_kept = 0, 0, true
		for z = room.minp.z - 1, room.maxp.z + 1 do
			for y = room.minp.y - 1, room.maxp.y + 1 do
				for x = room.minp.x - 1, room.maxp.x + 1 do
					local name = world_get(world, x, y, z)
					local def = registered[name]
					if rooms.room_at({x = x, y = y, z = z}) then
						if def.liquidtype ~= "none" then liquid_inside = liquid_inside + 1 end
						if def.is_ground_content ~= false then
							ground_content = ground_content + 1
						end
					elseif R.cell(room, x, y, z) == "plug" then
						if name ~= R.NODES.plug[room.tier] then outside_kept = false end
					elseif name ~= liquid then
						outside_kept = false
					end
				end
			end
		end
		check(liquid_inside == 0, "E no " .. liquid .. " left in the box")
		check(ground_content == 0, "E every box node is non-ground-content")
		check(outside_kept, "E the " .. liquid .. " right outside the box stays")
		local c = room.lift_cell
		for _, exit in ipairs(R.EXITS) do
			local fx, fz = c.x + exit[1] * 6, c.z + exit[2] * 6
			check(world_get(world, fx, c.y, fz) == R.NODES.fill and
				world_get(world, fx + exit[1], c.y, fz + exit[2]) == R.NODES.plug[room.tier] and
				world_get(world, fx + exit[1], c.y + 1, fz + exit[2]) == R.NODES.plug[room.tier] and
				world_get(world, fx + 2 * exit[1], c.y, fz + 2 * exit[2]) == liquid,
				"E the " .. liquid .. " in an exit's plug cell replaced, the cell beyond unchanged")
		end
	end
	check(fill.floodable == false and fill.buildable_to == false and fill.liquidtype == "none",
		"E the fill takes no liquid (Luanti floods only floodable non-liquid nodes)")
end

-- ---------------------------------------------------------------------------
-- F. Protection
-- ---------------------------------------------------------------------------
local wrap = dofile(wp40 .. "/guild_room_protection.lua")
local session = {
	territory_rule_at = function(pos) return pos.y <= -501 and "contested_land" or
		"accord_home" end,
	hard_protection_kind_at = function() return nil end,
	pvp_rule_at = function(pos) return pos.y <= -501 and "contested" or "peaceful" end,
	hard_footprint_in = function() return nil end,
	r7_functional_anchor_overlay = {schema = "grug_wp40_r7_functional_anchor_protection_v2"},
	compatibility = {
		world_protected_for_faction = function(pos, faction)
			return pos.y > -501 and faction ~= "accord"
		end,
		surface_level_at = function() return 1 end,
	},
}
local zones = wrap(session, rooms)
check(zones.pvp_rule_at == session.pvp_rule_at and
	zones.hard_footprint_in == session.hard_footprint_in and
	zones.compatibility.surface_level_at == session.compatibility.surface_level_at and
	zones.r7_functional_anchor_overlay == session.r7_functional_anchor_overlay and
	zones.guild_room_protection.rooms == 12, "F the other queries and the overlay field untouched")
for _, room in ipairs(rooms.list) do
	local at = room.camp_id .. " T" .. room.tier
	for _, p in ipairs({room.minp, room.maxp, room.lift_cell, room.arrival}) do
		check(zones.hard_protection_kind_at(p) == "guild_room" and
			zones.territory_rule_at(p) == "hard_protected" and
			zones.compatibility.world_protected_for_faction(p, "accord") and
			zones.compatibility.world_protected_for_faction(p, "throng"),
			"F " .. at .. " protected inside")
	end
	local c = room.lift_cell
	for _, p in ipairs({{x = c.x, y = room.maxp.y + 1, z = c.z},
			{x = c.x, y = room.minp.y - 1, z = c.z}, {x = room.maxp.x + 1, y = c.y, z = c.z},
			{x = c.x, y = c.y, z = room.minp.z - 1}}) do
		check(zones.hard_protection_kind_at(p) == nil and
			zones.territory_rule_at(p) == session.territory_rule_at(p) and
			zones.compatibility.world_protected_for_faction(p, "accord") ==
				session.compatibility.world_protected_for_faction(p, "accord"),
			"F " .. at .. " the session's answers above, below and beside")
	end
	check(zones.pvp_rule_at(c) == (room.floor_y <= -501 and "contested" or "peaceful"),
		"F " .. at .. " keeps its PvP rule")
end
check(not pcall(wrap, {}, rooms), "F refuses a session without the queries")
-- The player's hint (the real grug_core/protection.lua on stubs): a room
-- explains itself as the Miner's Guild's, the ground beside it does not.
do
	local saved_core, saved_grug_core, saved_zones = rawget(_G, "core"), rawget(_G, "grug_core"),
		rawget(_G, "grug_zones")
	_G.core = {is_protected = function() return false end,
		check_player_privs = function() return false end}
	_G.grug_core = {
		get_player_faction = function() return "accord" end,
		zone_authority_installed = function() return true end,
		world_protected_for_faction = function(pos, faction)
			return zones.compatibility.world_protected_for_faction(pos, faction)
		end,
		world_feature_at = function() return nil end,
	}
	_G.grug_zones = zones
	dofile(repo .. "/mods/CORE/grug_core/protection.lua")
	local room = edge_rooms[2]
	check(grug_core.protection_hint(room.lift_cell, "miner") == "Miner's Guild – protected",
		"F the hint in a room: " .. tostring(grug_core.protection_hint(room.lift_cell, "miner")))
	check(core.is_protected(room.minp, "miner") and
		not core.is_protected({x = room.maxp.x + 1, y = room.floor_y, z = room.lift_cell.z}, "miner"),
		"F protected in the box, not beside it (own home ground)")
	local c = room.lift_cell
	check(not core.is_protected({x = c.x + 7, y = c.y, z = c.z}, "miner") and
		grug_core.protection_hint({x = c.x + 7, y = c.y + 1, z = c.z}, "miner") == nil and
		zones.hard_protection_kind_at({x = c.x, y = c.y, z = c.z - 7}) == nil,
		"F an exit's plug is not protected: a player digs it")
	_G.core, _G.grug_core, _G.grug_zones = saved_core, saved_grug_core, saved_zones
end

-- ---------------------------------------------------------------------------
-- G. The spawn refusals
-- ---------------------------------------------------------------------------
do
	_G.core = {
		settings = {get_bool = function() return true end, get = function() return nil end},
		register_globalstep = function() end,
		register_on_leaveplayer = function() end,
		get_objects_inside_radius = function() return {} end,
	}
	_G.grug_mapgen = {guild_rooms = rooms}
	_G.grug_mobs = {spawn_regions = {fallback_palettes = function() return {}, {}, {} end}}
	dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")
	local allows = grug_mobs.spawn_policy_allows
	local room = edge_rooms[2]
	local c = room.lift_cell
	check(allows("grug_mobs:zombie", c) == false and
		allows("grug_mobs:cave_bat", {x = c.x + 3, y = c.y + 3, z = c.z - 3}) == false,
		"G no ambient underground spawn in a room")
	check(allows("grug_mobs:zombie", {x = room.maxp.x + 1, y = c.y, z = c.z}) == true and
		allows("grug_mobs:zombie", {x = c.x, y = room.minp.y - 1, z = c.z}) == true,
		"G the spawn beside and below the room allowed")
	grug_mobs.in_start_footprint = function() return false end
	grug_mobs.claim_refuses_spawn = function() return false end
	_G.grug_zones = setmetatable({mob_level_at = function() return 40 end}, {__index = zones})
	dofile(repo .. "/mods/ENTITIES/grug_mobs/depth_pulse.lua")
	local DP = grug_mobs.depth_pulse
	local deep = edge_rooms[4].lift_cell
	check(DP.refused("blood_bat", {x = deep.x + 1, y = deep.y + 1, z = deep.z}) ==
		"refused_protected", "G the depth pulse refuses a spot in a room")
	check(DP.refused("blood_bat", {x = deep.x + 7, y = deep.y + 1, z = deep.z}) == nil,
		"G the depth pulse takes a spot beside it")
	_G.grug_mapgen, _G.grug_zones = nil, nil
end

-- ---------------------------------------------------------------------------
-- H. The travel path takes the fill and the arrival
-- ---------------------------------------------------------------------------
do
	local source = read(repo .. "/mods/PLAYER/grug_home/travel.lua")
	local passable_src = source:match("\n(local function passable%(pos%).-\nend)\n")
	local arrival_src = source:match("\n(local function safe_arrival%(row%).-\nend)\n")
	check(passable_src and arrival_src, "H travel.lua's passable and safe_arrival found")
	local env = {
		core = {get_node_or_nil = function(pos)
			return {name = world_get(whole, pos.x, pos.y, pos.z)}
		end, registered_nodes = registered},
		vector = {new = function(v) return {x = v.x, y = v.y, z = v.z} end,
			offset = function(v, x, y, z) return {x = v.x + x, y = v.y + y, z = v.z + z} end},
		math = math,
	}
	local chunk = assert(loadstring(passable_src .. "\n" .. arrival_src ..
		"\nreturn passable, safe_arrival"))
	setfenv(chunk, env)
	local passable, safe_arrival = chunk()
	for _, room in ipairs(rooms.list) do
		local at = room.camp_id .. " T" .. room.tier
		local a = room.arrival
		local cell = {x = a.x, y = room.floor_y, z = a.z}
		check(passable(cell) and passable({x = a.x, y = room.floor_y + 1, z = a.z}),
			"H " .. at .. " the fill is passable")
		local got = safe_arrival({arrival = a})
		check(got and got.x == a.x and got.y == a.y and got.z == a.z,
			"H " .. at .. " the arrival is safe on the floor")
	end
	check(not passable({x = 0, y = -5000, z = 0}), "H rock is not passable")
end

print(("R58 ROOMS PORTABLE PASS checks=%d"):format(checks))
