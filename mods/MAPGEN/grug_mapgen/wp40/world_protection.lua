-- Round 25 rulings 15-17: world protection of roads, their bridges and the
-- building cores of POIs, villages and camps, for player digging and placing
-- only. Mapgen never reads this; it is built once in main from data the
-- mapgen already published (the serialized road layout and main's prepared
-- settlement blueprints) and handed to grug_core with the zone authority.
--
--   local wp = dofile(".../world_protection.lua")
--   local corridors = wp.road_corridors(road_module, road_layout_text)
--   local boxes = wp.settlement_boxes(rows)
--   local index = wp.new(index128, {corridors = corridors, boxes = boxes})
--   index.kind_at(x, y, z) -> "road", "bridge", "village", "camp", "poi" or nil
--
-- A CORRIDOR is a polyline with a surface profile: a road today, a waypoint
-- path later. A column is inside it when its distance to the centreline (its
-- nearest segment) is at most the half width plus `side` nodes of terrain,
-- and a node when it also lies within `vertical` nodes of the surface at
-- that nearest point. The surface node follows the road sampler exactly
-- (`road_layout.lua` sampler: the nearest segment's profile at the clamped
-- projection, rounded to half nodes, its full node), so a joint needs no
-- special case and a slope does not widen the band. Each corridor answers
-- on its own: a junction or an overpass protects both roads, each in its own
-- band. Nothing is rasterised.
-- A BOX is an inclusive x/y/z box: a settlement's building core from 10
-- below its placement height to 10 above the highest node its blueprint
-- places.
-- Both live in one 128-node candidate grid (`index128.compile_footprints`).
-- A corridor registers its segments in runs of CHUNK consecutive segments,
-- each run by the bounding box of its segments grown by the reach.
local M = {}

M.SCHEMA = "grug_wp40_world_protection_v1"
M.INDEX_SCHEMA = "grug_wp40_world_protection_index_v1"
-- Ruling 15: 3 nodes of terrain beside the road edge, +-5 around the surface.
M.ROAD_SIDE = 3
M.ROAD_VERTICAL = 5
-- Ruling 16: 10 below the placement height, 10 above the highest node.
M.BOX_BELOW = 10
M.BOX_ABOVE = 10
-- Segments per registered run.
M.CHUNK = 16
-- The world's query bounds (`zones.lua` and `height.lua` MIN_X .. MAX_Z).
M.BOUNDS = {min_x = -3740, max_x = 3740, min_z = -3340, max_z = 3340}

local floor, abs, min, max = math.floor, math.abs, math.min, math.max

local function fail(message)
	error("WP40 world protection: " .. message, 0)
end

local function integer(value, label)
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or
			abs(value) > 9007199254740991 then
		fail(label .. " is not an integer")
	end
	return value
end

local function finite(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge then
		fail(label .. " is not a finite number")
	end
	return value
end

-- The road sampler's surface node at a segment's clamped projection u.
local function surface_node(r0, r1, u)
	local rc = r0 + u * (r1 - r0)
	return floor(floor(2 * rc + 0.5) / 2)
end
M.surface_node = surface_node

-- The hint category of a settlement roster slot (`r7_settlement.lua`).
function M.settlement_kind(slot)
	if type(slot) ~= "string" then fail("settlement slot differs") end
	if slot:match("^village_%d+$") then return "village" end
	if slot:match("^bandit_%d+$") or slot == "mirefolk" then return "camp" end
	return "poi"
end

-- Every road of a serialized layout (network roads, trails, capital streets
-- and connectors) as a corridor, in road id order. A bridge run's points
-- (`road_layout.lua` bridge_points, the runs the writer gives the bridge
-- material) answer "bridge".
function M.road_corridors(road_module, text)
	if type(road_module) ~= "table" or type(road_module.deserialize) ~= "function" or
			type(road_module.bridge_points) ~= "function" or type(text) ~= "string" then
		fail("road corridor seam differs")
	end
	local layout = road_module.deserialize(text)
	local ids = {}
	for id in pairs(layout.roads) do ids[#ids + 1] = id end
	table.sort(ids)
	local out = {}
	for index = 1, #ids do
		local road = layout.roads[ids[index]]
		out[index] = {id = ("road:%05d"):format(road.id), kind = "road",
			X = road.X, Z = road.Z, R = road.R, half_width = road.hw,
			side = M.ROAD_SIDE, vertical = M.ROAD_VERTICAL,
			special = road_module.bridge_points(road.cls), special_kind = "bridge"}
	end
	return out
end

-- Settlement building cores. `rows`: {key, slot, anchor = {x, y, z},
-- bounds = {min = {x, y, z}, max = {x, y, z}}} with the blueprint's own cell
-- bounds, anchor-relative (local y = 0 lands on the anchor's placement
-- height). Starts and capitals are skipped: their towns are hard-protected.
function M.settlement_boxes(rows)
	if type(rows) ~= "table" then fail("settlement rows differ") end
	local out = {}
	for index = 1, #rows do
		local row = rows[index]
		if row.slot ~= "start" and row.slot ~= "capital" then
			local a, b = row.anchor, row.bounds
			if type(a) ~= "table" or type(b) ~= "table" or type(b.min) ~= "table" or
					type(b.max) ~= "table" then
				fail("settlement box differs: " .. tostring(row.key))
			end
			local ax, ay, az = integer(a.x, "anchor x"), integer(a.y, "anchor y"),
				integer(a.z, "anchor z")
			out[#out + 1] = {id = tostring(row.key), kind = M.settlement_kind(row.slot),
				min_x = ax + integer(b.min.x, "bounds min x"),
				max_x = ax + integer(b.max.x, "bounds max x"),
				min_z = az + integer(b.min.z, "bounds min z"),
				max_z = az + integer(b.max.z, "bounds max z"),
				min_y = ay + min(0, integer(b.min.y, "bounds min y")) - M.BOX_BELOW,
				max_y = ay + integer(b.max.y, "bounds max y") + M.BOX_ABOVE}
		end
	end
	return out
end

function M.new(index128, definition)
	if type(index128) ~= "table" or type(index128.compile_footprints) ~= "function" or
			type(index128.footprint_candidates) ~= "function" then
		fail("index seam differs")
	end
	if type(definition) ~= "table" then fail("definition differs") end
	local bounds = definition.bounds or M.BOUNDS
	local MIN_X, MAX_X = integer(bounds.min_x, "min x"), integer(bounds.max_x, "max x")
	local MIN_Z, MAX_Z = integer(bounds.min_z, "min z"), integer(bounds.max_z, "max z")
	local corridors, boxes = definition.corridors or {}, definition.boxes or {}
	local chunk = definition.chunk or M.CHUNK
	integer(chunk, "chunk")
	if chunk < 1 then fail("chunk differs") end

	-- Candidate ids: every box id sorts before every corridor id ("box:" <
	-- "corridor:"; index128 sorts each cell's candidates), so a query meets
	-- the boxes first and a POI core answers before a road reaching into it.
	local records, footprints = {}, {}
	local metrics = {boxes = 0, corridors = 0, segments = 0, runs = 0}
	local function clamp_bbox(x0, x1, z0, z1)
		-- half-open, inside the query bounds
		x0, z0 = max(MIN_X, x0), max(MIN_Z, z0)
		x1, z1 = min(MAX_X + 1, x1), min(MAX_Z + 1, z1)
		if x0 >= x1 or z0 >= z1 then return nil end
		return {min_x = x0, max_x = x1, min_z = z0, max_z = z1}
	end
	local function add(id, record, x0, x1, z0, z1)
		if records[id] then fail("duplicate record " .. id) end
		local bbox = clamp_bbox(x0, x1, z0, z1)
		if bbox then
			records[id] = record
			footprints[#footprints + 1] = {id = id, bbox = bbox}
		end
	end

	for index = 1, #boxes do
		local b = boxes[index]
		if type(b) ~= "table" or type(b.id) ~= "string" or type(b.kind) ~= "string" then
			fail("box differs at " .. index)
		end
		for _, key in ipairs({"min_x", "max_x", "min_y", "max_y", "min_z", "max_z"}) do
			integer(b[key], "box " .. b.id .. " " .. key)
		end
		if b.min_x > b.max_x or b.min_y > b.max_y or b.min_z > b.max_z then
			fail("box is empty: " .. b.id)
		end
		metrics.boxes = metrics.boxes + 1
		add("box:" .. b.id, {box = true, kind = b.kind, min_x = b.min_x, max_x = b.max_x,
			min_y = b.min_y, max_y = b.max_y, min_z = b.min_z, max_z = b.max_z},
			b.min_x, b.max_x + 1, b.min_z, b.max_z + 1)
	end

	for index = 1, #corridors do
		local c = corridors[index]
		if type(c) ~= "table" or type(c.id) ~= "string" or type(c.kind) ~= "string" or
				type(c.X) ~= "table" or type(c.Z) ~= "table" or type(c.R) ~= "table" then
			fail("corridor differs at " .. index)
		end
		local X, Z, R = c.X, c.Z, c.R
		local n = #X
		if n < 2 or #Z ~= n or #R ~= n then fail("corridor points differ: " .. c.id) end
		local reach = finite(c.half_width, "half width") + integer(c.side, "side")
		local vertical = integer(c.vertical, "vertical")
		for i = 1, n do
			finite(X[i], "corridor x") finite(Z[i], "corridor z") finite(R[i], "corridor y")
		end
		metrics.corridors = metrics.corridors + 1
		metrics.segments = metrics.segments + n - 1
		local shared = {kind = c.kind, X = X, Z = Z, R = R,
			reach2 = reach * reach, vertical = vertical, special = c.special or {},
			special_kind = c.special_kind or c.kind}
		local first, run = 1, 0
		while first < n do
			local last = min(n, first + chunk)
			local x0, x1, z0, z1 = X[first], X[first], Z[first], Z[first]
			for i = first, last do
				x0, x1 = min(x0, X[i]), max(x1, X[i])
				z0, z1 = min(z0, Z[i]), max(z1, Z[i])
			end
			run = run + 1
			metrics.runs = metrics.runs + 1
			add(("corridor:%s:%05d"):format(c.id, run), {corridor = shared,
				first = first, last = last,
				min_x = x0 - reach, max_x = x1 + reach,
				min_z = z0 - reach, max_z = z1 + reach},
				floor(x0 - reach), floor(x1 + reach) + 1,
				floor(z0 - reach), floor(z1 + reach) + 1)
			first = last
		end
	end

	local index = index128.compile_footprints({schema = M.INDEX_SCHEMA,
		min_x = MIN_X, max_x = MAX_X, min_z = MIN_Z, max_z = MAX_Z,
		records = footprints}, M.INDEX_SCHEMA)
	local candidates_at = index128.footprint_candidates

	-- Per-query scratch: the nearest segment so far of every corridor met.
	local near_corridor, near_d2, near_i, near_u = {}, {}, {}, {}

	-- Integer node coordinates.
	local function kind_at(x, y, z)
		if x < MIN_X or x > MAX_X or z < MIN_Z or z > MAX_Z then return nil end
		local list = candidates_at(index, x, z)
		local met = 0
		for n = 1, #list do
			local record = records[list[n]]
			if x >= record.min_x and x <= record.max_x and z >= record.min_z and
					z <= record.max_z then
				if record.box then
					if y >= record.min_y and y <= record.max_y then return record.kind end
				else
					local c = record.corridor
					local slot = 0
					for k = 1, met do
						if near_corridor[k] == c then slot = k break end
					end
					if slot == 0 then
						met = met + 1
						slot = met
						near_corridor[slot], near_d2[slot] = c, math.huge
					end
					local X, Z = c.X, c.Z
					local best, best_i, best_u = near_d2[slot], near_i[slot], near_u[slot]
					for i = record.first, record.last - 1 do
						local ax, az = X[i], Z[i]
						local vx, vz = X[i + 1] - ax, Z[i + 1] - az
						local l2 = vx * vx + vz * vz
						local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
						if u < 0 then u = 0 elseif u > 1 then u = 1 end
						local dx, dz = x - ax - u * vx, z - az - u * vz
						local d2 = dx * dx + dz * dz
						-- the first nearest in segment order, as the sampler
						if d2 < best then best, best_i, best_u = d2, i, u end
					end
					near_d2[slot], near_i[slot], near_u[slot] = best, best_i, best_u
				end
			end
		end
		local found
		for k = 1, met do
			local c = near_corridor[k]
			near_corridor[k] = nil
			if not found and near_d2[k] <= c.reach2 then
				local i, u = near_i[k], near_u[k]
				local s = surface_node(c.R[i], c.R[i + 1], u)
				if y >= s - c.vertical and y <= s + c.vertical then
					-- the sampler's point of this projection
					found = c.special[u < 0.5 and i or i + 1] and c.special_kind or c.kind
				end
			end
		end
		return found
	end

	local compiled = index128.sparse_metrics(index)
	metrics.populated_cells = compiled.populated_cells
	metrics.candidate_references = compiled.candidate_references
	metrics.maximum_candidates = compiled.maximum_candidates
	metrics.records = compiled.record_count
	return {schema = M.SCHEMA, kind_at = kind_at, metrics = metrics}
end

return M
