-- Round 70 lane TOWNS: the wayposts at the road junctions (round70-plan.md
-- §2.4, world_zones.md §9). Pure, the same in main and emerge: from the
-- serialized road layout and the planner's column queries it answers where a
-- `grug_signs:waypost` stack stands, which way each arrow points and which
-- settlement it names.
--
-- Few and useful: one stack where a secondary road (to a village or a
-- contested outpost) leaves a primary road, never at a trail or a capital
-- street. Three arrows, one post: the two ends of the primary road and the
-- secondary road's settlement.
--
-- The stack stands just off the road surface, opposite the mouth if it can
-- (the mouth's corner if not), at most ROAD_SIDE nodes from the road's edge:
-- no road column is taken, the road corridor's vegetation exclusion keeps
-- plants off the cell, and world protection covers it. Roads keep out of
-- every settlement's reservation but the ones they end at, so a junction far
-- enough from its road's ends is clear of them too (tools/seed_fleet checks
-- it on every seed). A junction with no good column (a bridge, a deep cut,
-- water) gets no stack; both environments skip the same one.
--
-- The node's text is metadata, which the emerge environment cannot write: the
-- writer places the nodes, and main's on_generated (grug_mapgen/init.lua)
-- writes each one's text from `M.rows` as soon as the chunk is finished. An
-- LBM would not do: a block that went active as an empty shell of a
-- neighbouring chunk is never activated again when it is generated
-- (serverenvironment.cpp:946-957, emerge.cpp:599-626), so its text would wait
-- for the block's next load.
local M = {}

M.NODE = "grug_signs:waypost"
-- The waypost's board holds 14 characters (grug_signs WAYPOST_SIDES).
M.TEXT_CHARS = 14
-- Road points a direction is read over; a point is about a node.
local LOOK = 16
-- Road points a junction keeps from either end of its primary road.
local END_CLEAR = 96
-- Nodes between two stacks.
local SPACING = 96
-- Road points along the primary road a stack may slip from the mouth.
local SLIP = 12
local ROAD_SIDE = 1

local floor, sqrt, deg, atan2 = math.floor, math.sqrt, math.deg, math.atan2

local function unit(dx, dz)
	local d = sqrt(dx * dx + dz * dz)
	if d == 0 then return 0, 0 end
	return dx / d, dz / d
end

-- A settlement's name on the board: the whole name if it fits, else its first
-- word ("Copperfell Village" reads "Copperfell").
function M.short_label(label)
	if #label <= M.TEXT_CHARS then return label end
	return label:match("^%S+"):sub(1, M.TEXT_CHARS)
end

-- degrotate: the arrow points along (dx, dz) at this param2, the same rule as
-- a player's placement (grug_signs `place_waypost`, half a turn added to the
-- yaw, 1.5 degrees a step).
function M.param2(dx, dz)
	return (floor(deg(atan2(-dx, dz)) / 1.5 + 0.5) + 120) % 240
end

local GRADED = {grade = true, cut = true, fill = true}
local SLOPE = {cutslope = true, embslope = true}

-- The stack's ground y at (x, z) beside a road surface column (cx, cz), or nil.
local function ground_at(x, z, cx, cz, column_values_at, road_column_at)
	local kind, road_y, _, class = road_column_at(cx, cz)
	if kind ~= "surface" or not GRADED[class] then return nil end
	local here = road_column_at(x, z)
	if here ~= nil and not SLOPE[here] then return nil end
	local water_class, _, _, _, _, terrain_y, water_y = column_values_at(x, z)
	if water_class ~= "land" or (water_y ~= nil and water_y > terrain_y) then return nil end
	if math.abs(terrain_y - floor(road_y)) > 1 then return nil end
	return terrain_y
end

-- The first good column round point `index` of `road`, the side `first` of the
-- road first: {x, y, z}, or nil.
local function stand(road, index, first, column_values_at, road_column_at)
	local n = #road.X
	for slip = 0, SLIP do
		for _, sign in ipairs(slip == 0 and {1} or {1, -1}) do
			local i = index + slip * sign
			if i > LOOK and i <= n - LOOK then
				local cx, cz = road.X[i], road.Z[i]
				local tx, tz = unit(road.X[i + LOOK] - road.X[i - LOOK],
					road.Z[i + LOOK] - road.Z[i - LOOK])
				for _, side in ipairs({first, -first}) do
					for reach = 1, ROAD_SIDE * 2 do
						local lateral = road.hw + reach / 2
						local x = floor(cx - tz * side * lateral + 0.5)
						local z = floor(cz + tx * side * lateral + 0.5)
						local ox, oz = x - cx, z - cz
						local y = ox * ox + oz * oz <= (road.hw + ROAD_SIDE) * (road.hw + ROAD_SIDE) and
							ground_at(x, z, floor(cx + 0.5), floor(cz + 0.5),
								column_values_at, road_column_at)
						if y then return {x = x, y = y + 1, z = z} end
					end
				end
			end
		end
	end
	return nil
end

-- Every stack of the world, in road id order:
--   {x, y, z, arms = {{param2 =, text =}, ...}} with y the lowest node's;
-- arms bottom to top. `labels`: anchor id -> settlement name.
function M.rows(road_module, road_text, labels, column_values_at, road_column_at)
	local roads = road_module.deserialize(road_text).roads
	local ids = {}
	for id in pairs(roads) do ids[#ids + 1] = id end
	table.sort(ids)
	local rows = {}
	for _, id in ipairs(ids) do
		local road = roads[id]
		local parent = road.parent and roads[road.parent]
		local index = road.parent_idx
		if road.kind == "secondary" and parent and parent.kind == "primary" and
				labels[road.a] and labels[parent.a] and labels[parent.b] and
				index > END_CLEAR and index <= #parent.X - END_CLEAR then
			local n = #road.X
			local back = math.max(1, n - LOOK)
			local bx, bz = unit(road.X[back] - road.X[n], road.Z[back] - road.Z[n])
			local px, pz = unit(parent.X[index + LOOK] - parent.X[index - LOOK],
				parent.Z[index + LOOK] - parent.Z[index - LOOK])
			-- The side of the primary road away from the mouth.
			local first = (-pz * bx + px * bz) > 0 and -1 or 1
			local spot = stand(parent, index, first, column_values_at, road_column_at)
			local clear = spot ~= nil
			for _, other in ipairs(clear and rows or {}) do
				local dx, dz = other.x - spot.x, other.z - spot.z
				if dx * dx + dz * dz < SPACING * SPACING then clear = false end
			end
			if clear then
				spot.arms = {
					{param2 = M.param2(-px, -pz), text = M.short_label(labels[parent.a])},
					{param2 = M.param2(px, pz), text = M.short_label(labels[parent.b])},
					{param2 = M.param2(bx, bz), text = M.short_label(labels[road.a])},
				}
				rows[#rows + 1] = spot
			end
		end
	end
	return rows
end

-- Main, once a chunk is generated: the text of each waypost node in it.
-- `is_waypost(pos)` guards a chunk the writer gave up on; `write(pos, text)`
-- stores it.
function M.write_texts(rows, minp, maxp, is_waypost, write)
	for index = 1, #rows do
		local row = rows[index]
		if row.x >= minp.x and row.x <= maxp.x and row.z >= minp.z and row.z <= maxp.z then
			for arm = 1, #row.arms do
				local y = row.y + arm - 1
				if y >= minp.y and y <= maxp.y then
					local pos = {x = row.x, y = y, z = row.z}
					if is_waypost(pos) then write(pos, row.arms[arm].text) end
				end
			end
		end
	end
end

return M
