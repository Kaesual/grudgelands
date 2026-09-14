-- The six start routes' compiled centreline vertices near the start, with the
-- Chebyshev radius of each vertex and the heading change at it. No session is
-- constructed: this reads the compiled source geometry directly.
local repo, output = assert(arg[1]), assert(arg[2])
local src = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local start_zone = {}
for index = 1, #src.anchors do
	local anchor = src.anchors[index]
	if anchor.slot_id == "start" then
		start_zone[anchor.zone_numeric_id] = anchor
	end
end
local file = assert(io.open(output, "wb"))
file:write("route\tanchor\tvertex\tx\tz\tradius\theading_deg\tturn_deg\n")
for index = 1, #src.routes do
	local route = src.routes[index]
	local anchor = start_zone[route.zone_a]
	if anchor then
		local previous
		for vertex = 1, math.min(#route.centreline, 5) do
			local point = route.centreline[vertex]
			local radius = math.max(math.abs(point.x - anchor.position.x),
				math.abs(point.z - anchor.position.z))
			local heading, turn = "-", "-"
			if vertex > 1 then
				local back = route.centreline[vertex - 1]
				heading = math.atan2(point.x - back.x, point.z - back.z) * 180 /
					math.pi
				if previous then turn = string.format("%.1f", heading - previous) end
				previous = heading
				heading = string.format("%.1f", heading)
			end
			file:write(table.concat({route.id, anchor.id, vertex, point.x, point.z,
				radius, heading, turn}, "\t"), "\n")
		end
		file:write(route.id, "\tvertices\t", #route.centreline, "\n")
	end
end
assert(file:close())
print("route_shape\tok\t" .. output)
