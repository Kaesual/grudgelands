-- WP40's routes stop at a capital's gates.
--
-- The playtest ruling of 2026-09-15, round 4: every incoming route ends at a
-- planned point of the city boundary -- a gate -- and no longer runs into the
-- interior; inside, the WP13 streets take over. This file is the gate on that
-- sentence, and on the geometry it rests on:
--
--   1. THE GATE POINTS. Twenty-four of them, the middle of each of the four
--      edges of each capital's 512-node build envelope, on the avenue centre
--      line. Each is a route station in its own right, so a route pinned to
--      one genuinely ends there.
--   2. THE ASSIGNMENT. Each capital is reached by exactly four routes, one per
--      side, so no gate is claimed twice and the assignment needs no
--      tie-break. That is a fact of the authored graph, not a rule, so it is
--      checked rather than assumed: a route added to a capital would break it
--      here instead of silently taking a gate that already has a road.
--   3. THE APPROACH. The final stretch is dead straight and axial, 144 nodes
--      long -- the whole leg from the gate to the route's own authored via
--      pin, which the authored graph already puts on the gate's axis. So the
--      road enters the gate normal to the wall it passes through.
--   4. THE INTERIOR. No point of ANY route or POI spur lies strictly inside
--      any capital's envelope.
--   5. NOTHING ELSE MOVED. The whole route graph is digested, and so are the
--      six start routes on their own: the start gate run of round B is a
--      different mechanism at the other end of the same file and this lane
--      must not have touched it.
--   6. THE INGRESS CORRIDOR. The hard protection that guards a capital's
--      approach is rebuilt from the same centrelines, so it now stops at the
--      gate. Checked at the anchor column, which it used to cover and must
--      not any more, and at the gate, which it must.
--
-- Everything here is engine-free and seed-free: it is a property of the
-- COMPILED LAYOUT, which is the same on every world. What the layout does to
-- real terrain -- the cells a route grades inside an envelope, the step at the
-- gate, the water under an avenue -- is `tools/wp13/route_gates.lua`, which
-- needs a height session and therefore a seed.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(wp40 .. "/source/simple_map.lua")
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	-- -----------------------------------------------------------------------
	-- 1. The gate points, derived independently of the source's own table
	-- -----------------------------------------------------------------------
	-- Luanti's +z is north. The half width is read from `capital_core` so that
	-- a change to the envelope moves both the definition and the check, but the
	-- number it must be today is stated as well: a silent 512 -> 384 would
	-- otherwise pass.
	local HALF = source.capital_core.width_x / 2
	assert(HALF == 256 and HALF == source.capital_core.width_z / 2,
		"wp13 route gates: the capital envelope is not 512 nodes square")
	local SIDES = {{"west", -1, 0}, {"east", 1, 0}, {"south", 0, -1},
		{"north", 0, 1}}

	local capital_zone, capital_anchor = {}, {}
	for index = 1, #source.anchors do
		local anchor = source.anchors[index]
		if anchor.slot_id == "capital" then
			local zone = source.zones[anchor.zone_numeric_id]
			assert(anchor.position.x == zone.hub.x and
				anchor.position.z == zone.hub.z,
				"wp13 route gates: capital anchor is not its zone hub: " .. anchor.id)
			capital_zone[anchor.zone_numeric_id] = zone
			capital_anchor[anchor.zone_numeric_id] = anchor
		end
	end
	local capital_order = {}
	for zone_numeric_id in pairs(capital_zone) do
		capital_order[#capital_order + 1] = zone_numeric_id
	end
	table.sort(capital_order)
	assert(#capital_order == 6,
		"wp13 route gates: " .. #capital_order .. " capitals, not six")

	local station_by_id = {}
	for index = 1, #source.route_stations do
		local station = source.route_stations[index]
		assert(station_by_id[station.id] == nil,
			"wp13 route gates: duplicate route station " .. station.id)
		station_by_id[station.id] = station
	end

	local gate_by_key, gate_count = {}, 0
	for _, zone_numeric_id in ipairs(capital_order) do
		local zone = capital_zone[zone_numeric_id]
		for _, side in ipairs(SIDES) do
			local expected_id = ("station:%s:gate_%s"):format(zone.id, side[1])
			local station = station_by_id[expected_id]
			local x, z = zone.hub.x + side[2] * HALF, zone.hub.z + side[3] * HALF
			assert(station ~= nil and station.kind == "gate" and
				station.zone_numeric_id == zone_numeric_id and
				station.position.x == x and station.position.z == z,
				"wp13 route gates: gate station differs at " .. expected_id)
			gate_by_key[zone_numeric_id .. ":" .. side[1]] =
				{id = expected_id, x = x, z = z, side = side[1],
					axis = side[2] ~= 0 and "x" or "z"}
			gate_count = gate_count + 1
			say("route_gate", expected_id, x, z, side[1])
		end
	end
	assert(gate_count == 24, "wp13 route gates: " .. gate_count .. " gates")
	assert(#source.capital_gates == 24,
		"wp13 route gates: the source publishes " .. #source.capital_gates ..
			" capital gates")
	for index = 1, #source.capital_gates do
		local row = source.capital_gates[index]
		local gate = gate_by_key[row.zone_numeric_id .. ":" .. tostring(row.side)]
		assert(gate ~= nil and row.id == gate.id and row.position.x == gate.x and
			row.position.z == gate.z and row.axis == gate.axis,
			"wp13 route gates: published capital gate differs at " .. index)
	end

	-- -----------------------------------------------------------------------
	-- 2, 3. The assignment and the straight approach
	-- -----------------------------------------------------------------------
	local APPROACH = 144
	local claimed, reaching = {}, {}
	for index = 1, #source.routes do
		local route = source.routes[index]
		for _, which in ipairs({"a", "b"}) do
			local zone_numeric_id = which == "a" and route.zone_a or route.zone_b
			local zone = capital_zone[zone_numeric_id]
			if zone then
				local other = source.zones[which == "a" and route.zone_b or
					route.zone_a]
				local dx, dz = other.hub.x - zone.hub.x, other.hub.z - zone.hub.z
				local side
				if math.abs(dx) > math.abs(dz) then side = dx < 0 and "west" or "east"
				else side = dz < 0 and "south" or "north" end
				local key = zone_numeric_id .. ":" .. side
				local gate = gate_by_key[key]
				assert(claimed[key] == nil, "wp13 route gates: " .. gate.id ..
					" is claimed by both " .. tostring(claimed[key]) .. " and " ..
					route.id)
				claimed[key] = route.id
				reaching[zone_numeric_id] = (reaching[zone_numeric_id] or 0) + 1

				local station_id = which == "a" and route.station_a_id or
					route.station_b_id
				local terminal = which == "a" and route.centreline[1] or
					route.centreline[#route.centreline]
				assert(station_id == gate.id, "wp13 route gates: " .. route.id ..
					" pins to " .. station_id .. " and not to " .. gate.id)
				assert(terminal.x == gate.x and terminal.z == gate.z,
					"wp13 route gates: " .. route.id .. " ends at (" .. terminal.x ..
						"," .. terminal.z .. ") and not at its gate")

				-- The straight run, walked off the centreline: from the terminal
				-- outward, every point on the gate's own axis until one is not.
				local step = which == "a" and 1 or -1
				local cursor = which == "a" and 1 or #route.centreline
				local straight = 0
				while true do
					local next_point = route.centreline[cursor + step]
					if next_point == nil then break end
					local off = gate.axis == "x" and (next_point.z - gate.z) or
						(next_point.x - gate.x)
					if off ~= 0 then break end
					local here = route.centreline[cursor]
					straight = straight + math.abs(next_point.x - here.x) +
						math.abs(next_point.z - here.z)
					cursor = cursor + step
				end
				assert(straight >= APPROACH, "wp13 route gates: " .. route.id ..
					" enters its gate straight for only " .. straight .. " nodes")
				say("route_gate_approach", route.id, gate.id, which, straight)
			end
		end
	end
	for _, zone_numeric_id in ipairs(capital_order) do
		assert(reaching[zone_numeric_id] == 4, "wp13 route gates: " ..
			capital_zone[zone_numeric_id].id .. " is reached by " ..
			tostring(reaching[zone_numeric_id]) .. " routes, not one per gate")
	end

	-- -----------------------------------------------------------------------
	-- 4. Nothing runs into the interior
	-- -----------------------------------------------------------------------
	-- The RULING itself. Every segment of a capital's gate leg is axial, so a
	-- polyline whose points are all outside an envelope is a polyline that is
	-- entirely outside it; the bowed legs never come near one. Spurs are walked
	-- too, because a POI spur ends at its zone hub and a hub inside a capital
	-- would be the same defect by another road.
	local interior_faults = 0
	for _, collection in ipairs({source.routes, source.poi_spurs}) do
		for index = 1, #collection do
			local row = collection[index]
			for point_index = 1, #row.centreline do
				local point = row.centreline[point_index]
				for _, zone_numeric_id in ipairs(capital_order) do
					local hub = capital_zone[zone_numeric_id].hub
					if math.abs(point.x - hub.x) < HALF and
							math.abs(point.z - hub.z) < HALF then
						interior_faults = interior_faults + 1
					end
				end
			end
		end
	end
	assert(interior_faults == 0, "wp13 route gates: " .. interior_faults ..
		" route or spur point(s) lie inside a capital build envelope")
	say("route_gate_interior_points", interior_faults)

	-- -----------------------------------------------------------------------
	-- 5. Nothing else moved
	-- -----------------------------------------------------------------------
	local function centreline_digest(rows, wanted)
		local bytes = {}
		for index = 1, #rows do
			local row = rows[index]
			if wanted == nil or wanted[row.id] then
				bytes[#bytes + 1] = row.id .. "\t" .. row.station_a_id .. "\t" ..
					row.station_b_id .. "\t" .. row.pinned_point_index
				for point_index = 1, #row.centreline do
					local point = row.centreline[point_index]
					bytes[#bytes + 1] = "\t" .. point.x .. "," .. point.z
				end
				bytes[#bytes + 1] = "\n"
			end
		end
		return common.hex(raw_sha256(table.concat(bytes)))
	end
	local start_routes = {}
	for index = 1, #source.routes do
		local route = source.routes[index]
		local anchor_slot
		for anchor_index = 1, #source.anchors do
			local anchor = source.anchors[anchor_index]
			if anchor.zone_numeric_id == route.zone_a and
					anchor.slot_id == "start" then
				anchor_slot = true
			end
		end
		if anchor_slot then start_routes[route.id] = true end
	end
	local start_count = 0
	for _ in pairs(start_routes) do start_count = start_count + 1 end
	assert(start_count == 6,
		"wp13 route gates: " .. start_count .. " start routes, not six")
	-- The six start routes' centrelines, frozen at the value round B shipped.
	-- This lane changed the other end of the same compiler; if the gate-axis
	-- run of a start moved, this is where it says so.
	assert(centreline_digest(source.routes, start_routes) ==
		"e57867fba1ef10e2c4625a5ee273a79fd8034caacd6dfd2b802f2b3144fe8989",
		"wp13 route gates: a start route centreline moved")
	say("route_gate_start_routes", start_count,
		centreline_digest(source.routes, start_routes))
	say("route_gate_all_routes", #source.routes,
		centreline_digest(source.routes))

	-- -----------------------------------------------------------------------
	-- 6. The ingress corridor
	-- -----------------------------------------------------------------------
	-- The corridor is the union of its named routes' centrelines widened to
	-- `total_width`, so it follows the road. It used to reach the anchor column
	-- in the middle of the city; it must not any more, and it must still reach
	-- the gate its route now ends at. The membership test is the source's own
	-- geometry, reimplemented here in integers so that the KAT does not have to
	-- construct a horizontal session to ask one question.
	local function corridor_member(x, z, points, total_width)
		for index = 1, #points - 1 do
			local a, b = points[index], points[index + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local px, pz = x - a.x, z - a.z
			local length = dx * dx + dz * dz
			local dot = px * dx + pz * dz
			local numerator, denominator
			if length == 0 then
				numerator, denominator = px * px + pz * pz, 1
			elseif dot <= 0 then
				numerator, denominator = px * px + pz * pz, 1
			elseif dot >= length then
				local qx, qz = x - b.x, z - b.z
				numerator, denominator = qx * qx + qz * qz, 1
			else
				local cross = px * dz - pz * dx
				numerator, denominator = cross * cross, length
			end
			if 4 * numerator <= total_width * total_width * denominator then
				return true
			end
		end
		return false
	end
	local route_by_id = {}
	for index = 1, #source.routes do
		route_by_id[source.routes[index].id] = source.routes[index]
	end
	local anchor_by_id = {}
	for index = 1, #source.anchors do
		anchor_by_id[source.anchors[index].id] = source.anchors[index]
	end
	assert(#source.capital_ingresses == 6,
		"wp13 route gates: " .. #source.capital_ingresses .. " capital ingresses")
	for index = 1, #source.capital_ingresses do
		local ingress = source.capital_ingresses[index]
		local anchor = anchor_by_id[ingress.capital_anchor_id]
		assert(anchor ~= nil and anchor.slot_id == "capital",
			"wp13 route gates: ingress " .. ingress.id .. " names no capital")
		local covers_anchor, covers_gate = false, 0
		for route_index = 1, #ingress.route_ids do
			local route = route_by_id[ingress.route_ids[route_index]]
			assert(route ~= nil, "wp13 route gates: ingress " .. ingress.id ..
				" names an unknown route")
			if corridor_member(anchor.position.x, anchor.position.z,
					route.centreline, ingress.total_width) then
				covers_anchor = true
			end
			for _, side in ipairs(SIDES) do
				local gate = gate_by_key[anchor.zone_numeric_id .. ":" .. side[1]]
				if corridor_member(gate.x, gate.z, route.centreline,
						ingress.total_width) then
					covers_gate = covers_gate + 1
				end
			end
		end
		assert(not covers_anchor, "wp13 route gates: ingress " .. ingress.id ..
			" still protects the capital anchor column")
		assert(covers_gate == 1, "wp13 route gates: ingress " .. ingress.id ..
			" covers " .. covers_gate .. " gates, not exactly one")
		say("route_gate_ingress", ingress.id, anchor.id, #ingress.route_ids,
			ingress.total_width, covers_gate)
	end

	return table.concat(report)
end
