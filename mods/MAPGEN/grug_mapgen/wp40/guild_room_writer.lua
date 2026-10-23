-- The room step (Round 58 lane ROOMS): writes the Miner's Guild lift rooms
-- (`guild_rooms.lua`) into the generated chunks, mapgen environment. It is a
-- step of its own after the R7 writer's transaction, outside its refinement
-- and its degrade (`r7_mapgen.lua`): it runs in every chunk a room box meets,
-- also where the writer's early-outs skip the transaction (`air_chunks.lua`:
-- rock below, every chunk from y -113 down) and where the writer failed and
-- the chunk kept the engine's terrain, so a writer veto never drops a room.
--
--   local W = dofile(wp40 .. "/guild_room_writer.lua")
--   local write = W.new(R, rooms[, nodes])  -- R: guild_rooms.lua, rooms: R.index
--   write(vm, minp, maxp) -> the number of rooms written into the chunk
--   local step = W.or_degrade(severe, write) -- step(vm, minp, maxp) -> ok
--
-- Each chunk writes exactly the part of every room box and its exits'
-- plugs inside its own minp .. maxp, so a room split over chunk edges comes out the same in
-- whatever order its chunks are generated: every node of the box is the
-- shape's (R.cell), whatever stood there, liquids and caves included. The
-- old param1 goes with set_node_at (light 0), then calc_lighting on the
-- written part lights it from its lamps and its surroundings (an early-out
-- chunk never runs the writer's own lighting). No liquid update: the
-- engine queued the chunk's liquids before this callback, so a flow that
-- lost its source to a room recedes when its queue entry runs.
--
-- Not the writer's content: the R7 writer never meets a room node in what it
-- writes. Rooms lie below y -37 (the authored floor, the writer's lowest run;
-- the -50 room's box tops out at -44), the room step runs after the writer in
-- the same chunk, and the writer's neighbour scans stay inside its owner.
local W = {}

function W.new(R, rooms, nodes)
	nodes = nodes or R.NODES
	assert(type(rooms) == "table" and type(rooms.rooms_in) == "function",
		"guild room writer: the room index differs")
	assert(type(nodes.fill) == "string" and type(nodes.floor) == "string" and
		type(nodes.lamp) == "string" and type(nodes.mantle) == "table" and
		#nodes.mantle == R.TIERS and type(nodes.plug) == "table" and
		#nodes.plug == R.TIERS, "guild room writer: the node names differ")
	local cell_at_offset = R.cell_at_offset
	local pos, node = {x = 0, y = 0, z = 0}, {name = "", param1 = 0, param2 = 0}
	local low, high = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
	local by_kind = {fill = nodes.fill, lift = nodes.lift or nodes.fill,
		floor = nodes.floor, lamp = nodes.lamp}
	local lift_param2 = nodes.lift and nodes.lift_param2 or 0
	return function(vm, minp, maxp)
		local rooms_here = rooms.rooms_in(minp, maxp)
		for room_index = 1, #rooms_here do
			local room = rooms_here[room_index]
			local mantle, plug = nodes.mantle[room.tier], nodes.plug[room.tier]
			local cx, fy, cz = room.lift_cell.x, room.floor_y, room.lift_cell.z
			local wmin, wmax = room.write_minp, room.write_maxp
			low.x, low.y, low.z = math.max(minp.x, wmin.x),
				math.max(minp.y, wmin.y), math.max(minp.z, wmin.z)
			high.x, high.y, high.z = math.min(maxp.x, wmax.x),
				math.min(maxp.y, wmax.y), math.min(maxp.z, wmax.z)
			for z = low.z, high.z do
				for y = low.y, high.y do
					for x = low.x, high.x do
						local kind = cell_at_offset(x - cx, y - fy, z - cz)
						if kind then
							pos.x, pos.y, pos.z = x, y, z
							node.name = kind == "mantle" and mantle or
								(kind == "plug" and plug or by_kind[kind])
							node.param2 = kind == "lift" and lift_param2 or 0
							vm:set_node_at(pos, node)
						end
					end
				end
			end
			vm:calc_lighting(low, high, true)
		end
		return #rooms_here
	end
end

-- A failed room step never stops the server either (degrade.lua's rule): the
-- report names the chunk, and the room part there stays what it was.
function W.or_degrade(severe, write)
	local function text(p)
		return ("(%s,%s,%s)"):format(tostring(p.x), tostring(p.y), tostring(p.z))
	end
	return function(vm, minp, maxp)
		local ok, err = pcall(write, vm, minp, maxp)
		if not ok then
			local chunk = text(minp)
			severe.report("mapgen", "a Miner's Guild room in the map chunk at " ..
				chunk .. " was not written whole", ("minp=%s maxp=%s error=%s"):format(
				chunk, text(maxp), tostring(err):match("^[^\n]*")), "mapgen_room:" .. chunk)
		end
		return ok
	end
end

return W
