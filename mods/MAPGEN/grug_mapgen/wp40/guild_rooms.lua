-- The Miner's Guild lift rooms (Round 58 lane ROOMS, round58-plan.md §2):
-- one room per lift level of every camp with a lift, around the camp's lift
-- column at the floor y of that level's tier. Pure data and arithmetic, no
-- engine calls: the main environment (protection, the lift, the foremen),
-- the mapgen environment (the room step, `guild_room_writer.lua`) and the
-- fixtures read the same rooms.
--
--   local R = dofile(wp40 .. "/guild_rooms.lua")
--   local rooms = R.index(camps, floors)
--     camps   the camps with a lift (CAMPS' camp module, `camps(layout)`):
--             {id, tier, lift = {x, z}, levels = {1, ..., tier}, ...}
--     floors  the room floor y per tier (the camp module's ROOM_FLOOR_Y)
--   rooms.list                  every room: the camps in their order, each
--                               camp's rooms by level
--   rooms.rooms_for_camp(camp)  a camp's rooms by level (the camp row or its
--                               id), or nil for a camp without rooms
--   rooms.room_at(pos)          the room whose box holds the node at pos, or
--                               nil (allocation-free: the spawn gates ask it)
--   rooms.rooms_in(minp, maxp)  the rooms whose box meets the inclusive box
--   rooms.summary()             one line per room (the identity both
--                               environments log)
--   R.cell(room, x, y, z)       what the room holds at a node of its box:
--                               "fill", "lift", "floor", "lamp", "mantle"
--                               or nil outside
--
-- A room is {camp_id, tier, floor_y, minp, maxp, arrival, lift_cell}, one
-- table shared by every caller (never written into):
--   floor_y    the room's lowest open layer: a player stands at floor_y on
--              the floor nodes of floor_y - 1;
--   minp/maxp  the inclusive box the room step writes and protects: the
--              open room, its exits and the mantle round them;
--   lift_cell  the node of the room's lift (CAMPS' lift node), in the lift
--              column on the floor, its front toward the arrival;
--   arrival    the player position beside the lift (the feet 0.49 below
--              the cell, so `grug_home/travel.lua`'s safe arrival reads the
--              floor node under it).
--
-- THE SHAPE, in offsets from (lift.x, floor_y, lift.z): the open room is 7 x 7
-- columns (-3 .. 3) and 4 layers (0 .. 3); three exits, 1 wide and 2 high,
-- leave the middle of the -x, +x and -z walls and run through the mantle to
-- the box face (offset 4 .. 6), where they end blind in the host rock beyond
-- it; players dig on from there. The floor (offset -1) is the floor node under
-- the room and the exits; four lamps sit in the walls at offset 2, one above
-- each exit and one in the +z wall behind the lift (light 8 or more on every
-- open node); everything else of the box is mantle, three nodes thick
-- round the room: below the floor -3 .. -2, above the room 4 .. 6, beside it
-- 4 .. 6. The lift cell is the room's centre (0, 0, 0), the arrival beside it
-- at (0, 0, 1).
--
-- Every node the room step writes is non-ground-content (the fill, the floor,
-- the lamps, the mantle; `guild_room_nodes.lua`): a neighbouring chunk's caves,
-- flooded caves and dungeons, which reach about 16 nodes past its edge, spare
-- exactly such nodes, and the fill (walkable, floodable and buildable_to false)
-- lets no liquid in. The exits end at the box face, so the host rock a player
-- digs there lies outside the protected box.
local M = {}

M.SCHEMA = "grug_wp58_guild_rooms_v1"
-- The node names the room step writes (registered by guild_room_nodes.lua;
-- the lift is CAMPS' node, world_nodes.lua, the one the camps' surface lifts
-- are). The lift's param2 (`4dir`, 0 = its front toward -z) turns its front
-- toward +z, to the arrival cell.
M.NODES = {
	fill = "grug_mapgen:room_fill",
	floor = "grug_mapgen:room_floor",
	lamp = "grug_mapgen:room_lamp",
	lift = "grug_mapgen:guild_lift",
	lift_param2 = 2,
	mantle = {"grug_mapgen:room_mantle_t1", "grug_mapgen:room_mantle_t2",
		"grug_mapgen:room_mantle_t3", "grug_mapgen:room_mantle_t4",
		"grug_mapgen:room_mantle_t5", "grug_mapgen:room_mantle_t6"},
}
M.TIERS = 6

-- The shape (offsets from the lift column at floor_y).
M.HALF = 3 -- the open room: -HALF .. HALF in x and z
local HALF = M.HALF
M.HEIGHT = 4 -- the open room: 0 .. HEIGHT - 1 in y
M.MANTLE = 3 -- the mantle's thickness round the room (the floor layer counts)
M.EXIT_HEIGHT = 2
-- The exits' directions {dx, dz}: the middle of the -x, +x and -z walls.
M.EXITS = {{-1, 0}, {1, 0}, {0, -1}}
-- The lamps' offsets {dx, dy, dz} in the walls' first layer.
M.LAMPS = {{-HALF - 1, 2, 0}, {HALF + 1, 2, 0}, {0, 2, -HALF - 1}, {0, 2, HALF + 1}}
M.ARRIVAL = {0, 0, 1} -- {dx, dy, dz} of the arrival cell
local HEIGHT, MANTLE, EXIT_HEIGHT = M.HEIGHT, M.MANTLE, M.EXIT_HEIGHT
local REACH = HALF + MANTLE -- the box: -REACH .. REACH in x and z
local BOTTOM, TOP = -MANTLE, HEIGHT - 1 + MANTLE -- the box in y
M.BOX = {min_x = -REACH, max_x = REACH, min_y = BOTTOM, max_y = TOP,
	min_z = -REACH, max_z = REACH}

local function fail(message) error("guild rooms: " .. message, 0) end

local function integer(value, label)
	if type(value) ~= "number" or value % 1 ~= 0 or value < -31000 or
			value > 31000 then
		fail(label .. " is not a node coordinate: " .. tostring(value))
	end
	return value
end

-- The node of a world coordinate, half away from zero like the engine
-- (r7_zone_overlay.lua's rounding).
local function node(value)
	if value >= 0 then
		local base = math.floor(value)
		return value - base >= 0.5 and base + 1 or base
	end
	local base = math.ceil(value)
	return base - value >= 0.5 and base - 1 or base
end

-- Whether a column offset is an exit's: the exit's direction and its
-- distance from the room's centre line.
local function exit_column(dx, dz)
	for index = 1, #M.EXITS do
		local exit = M.EXITS[index]
		local along = dx * exit[1] + dz * exit[2]
		local across = dx * exit[2] - dz * exit[1]
		if across == 0 and along > HALF and along <= REACH then return true end
	end
	return false
end

local function lamp_cell(dx, dy, dz)
	for index = 1, #M.LAMPS do
		local lamp = M.LAMPS[index]
		if dx == lamp[1] and dy == lamp[2] and dz == lamp[3] then return true end
	end
	return false
end

-- What the room holds at offset (dx, dy, dz) from its lift column at
-- floor_y; nil outside the box.
function M.cell_at_offset(dx, dy, dz)
	if dx < -REACH or dx > REACH or dz < -REACH or dz > REACH or dy < BOTTOM or
			dy > TOP then
		return nil
	end
	local inside = dx >= -HALF and dx <= HALF and dz >= -HALF and dz <= HALF
	local exit = not inside and exit_column(dx, dz)
	if inside and dy >= 0 and dy < HEIGHT then
		if dx == 0 and dy == 0 and dz == 0 then return "lift" end
		return "fill"
	end
	if exit and dy >= 0 and dy < EXIT_HEIGHT then return "fill" end
	if dy == -1 and (inside or exit) then return "floor" end
	if lamp_cell(dx, dy, dz) then return "lamp" end
	return "mantle"
end

function M.cell(room, x, y, z)
	return M.cell_at_offset(x - room.lift_cell.x, y - room.floor_y,
		z - room.lift_cell.z)
end

local function new_room(camp, level, floor_y)
	local x, z = camp.lift.x, camp.lift.z
	local arrival = M.ARRIVAL
	return {camp_id = camp.id, tier = level, floor_y = floor_y,
		minp = {x = x - REACH, y = floor_y + BOTTOM, z = z - REACH},
		maxp = {x = x + REACH, y = floor_y + TOP, z = z + REACH},
		lift_cell = {x = x, y = floor_y, z = z},
		arrival = {x = x + arrival[1], y = floor_y + arrival[2] - 0.49,
			z = z + arrival[3]}}
end

local function boxes_meet(a_min, a_max, b_min, b_max)
	return a_min.x <= b_max.x and b_min.x <= a_max.x and
		a_min.y <= b_max.y and b_min.y <= a_max.y and
		a_min.z <= b_max.z and b_min.z <= a_max.z
end

function M.index(camps, floors)
	if type(camps) ~= "table" or type(floors) ~= "table" then
		fail("the camps and the floors differ")
	end
	local list, by_camp, bands = {}, {}, {}
	local band_of = {} -- floor_y -> band
	for camp_index = 1, #camps do
		local camp = camps[camp_index]
		if type(camp) ~= "table" or type(camp.id) ~= "string" or camp.id == "" then
			fail("camp " .. camp_index .. " has no id")
		end
		if by_camp[camp.id] then fail("camp " .. camp.id .. " is listed twice") end
		if type(camp.lift) ~= "table" or type(camp.levels) ~= "table" then
			fail("camp " .. camp.id .. " has no lift or levels")
		end
		integer(camp.lift.x, camp.id .. " lift x")
		integer(camp.lift.z, camp.id .. " lift z")
		local rooms, previous = {}, 0
		for level_index = 1, #camp.levels do
			local level = camp.levels[level_index]
			if type(level) ~= "number" or level % 1 ~= 0 or level < 1 or
					level > M.TIERS or level <= previous then
				fail("camp " .. camp.id .. " levels differ")
			end
			previous = level
			local floor_y = integer(floors[level], "the tier " .. level .. " floor")
			local room = new_room(camp, level, floor_y)
			rooms[#rooms + 1] = room
			list[#list + 1] = room
			local band = band_of[floor_y]
			if not band then
				band = {min_y = room.minp.y, max_y = room.maxp.y, rooms = {}}
				band_of[floor_y] = band
				bands[#bands + 1] = band
			end
			band.rooms[#band.rooms + 1] = room
		end
		by_camp[camp.id] = rooms
	end
	-- One room per place: two boxes never meet (camps lie far apart; a
	-- placement that broke this would write one room into another).
	for band_index = 1, #bands do
		local band = bands[band_index]
		for first = 1, #band.rooms do
			for second = first + 1, #band.rooms do
				local a, b = band.rooms[first], band.rooms[second]
				if boxes_meet(a.minp, a.maxp, b.minp, b.maxp) then
					fail("the rooms of " .. a.camp_id .. " and " .. b.camp_id .. " meet")
				end
			end
		end
		for other = band_index + 1, #bands do
			local o = bands[other]
			if band.min_y <= o.max_y and o.min_y <= band.max_y then
				fail("two room floors lie closer than a room's height")
			end
		end
	end
	local band_count = #bands
	local low_y, high_y = math.huge, -math.huge
	for band_index = 1, band_count do
		low_y = math.min(low_y, bands[band_index].min_y)
		high_y = math.max(high_y, bands[band_index].max_y)
	end

	local index = {schema = M.SCHEMA, list = list}
	function index.rooms_for_camp(camp)
		local id = type(camp) == "table" and camp.id or camp
		return by_camp[id]
	end
	function index.room_at(pos)
		if type(pos) ~= "table" then return nil end
		local py = pos.y
		if type(py) ~= "number" or py ~= py then return nil end
		local y = node(py)
		if y < low_y or y > high_y then return nil end
		for band_index = 1, band_count do
			local band = bands[band_index]
			if y >= band.min_y and y <= band.max_y then
				local px, pz = pos.x, pos.z
				if type(px) ~= "number" or type(pz) ~= "number" then return nil end
				local x, z = node(px), node(pz)
				local rooms = band.rooms
				for room_index = 1, #rooms do
					local room = rooms[room_index]
					local minp, maxp = room.minp, room.maxp
					if x >= minp.x and x <= maxp.x and z >= minp.z and z <= maxp.z then
						return room
					end
				end
				return nil
			end
		end
		return nil
	end
	function index.rooms_in(minp, maxp)
		local found = {}
		if maxp.y < low_y or minp.y > high_y then return found end
		for band_index = 1, band_count do
			local band = bands[band_index]
			if minp.y <= band.max_y and band.min_y <= maxp.y then
				for room_index = 1, #band.rooms do
					local room = band.rooms[room_index]
					if boxes_meet(minp, maxp, room.minp, room.maxp) then
						found[#found + 1] = room
					end
				end
			end
		end
		return found
	end
	function index.summary()
		local lines = {M.SCHEMA}
		for room_index = 1, #list do
			local room = list[room_index]
			lines[#lines + 1] = ("%s %d %d %d %d"):format(room.camp_id, room.tier,
				room.lift_cell.x, room.floor_y, room.lift_cell.z)
		end
		return table.concat(lines, "\n")
	end
	return index
end

-- The camps with a lift and the room floor per tier, as the game reads them
-- in both environments from the world's placement layout text: CAMPS' camp
-- module (`r58_camps.lua`; no seams: the rooms need no war camp's race).
function M.lift_camps(wp40, placement_layout)
	assert(type(wp40) == "string" and type(placement_layout) == "string",
		"guild rooms: the camp source differs")
	local camps = dofile(wp40 .. "/r58_camps.lua")
	return camps.camps(placement_layout), camps.ROOM_FLOOR_Y
end

return M
