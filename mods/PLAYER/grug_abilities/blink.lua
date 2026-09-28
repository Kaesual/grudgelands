-- Blink destination (docs/design/classes.md §5, Blink row and its targeting
-- note). Returns a function
--
--   destination(eye, dir, distance, eye_height, box[, world]) -> feet | nil
--
-- that knows nothing about the caster beyond those arguments and reads the
-- map only through `world` (default: the live map), so the headless probe can
-- call it against built test geometry. nil means "no room to blink".
--
-- Node semantics: walkable nodes are solid with their real collision boxes;
-- non-walkable nodes (air, plants, torches, liquids) are passable. Unloaded
-- and unknown nodes and `ignore` count as solid full cubes.

local EPS = 0.001
-- Back-search step toward the caster, metres.
local STEP = 0.5
-- The one-node step-up allowance (ledge tops, slopes during the back-search).
local MAX_RISE = 1.0
-- Shorter moves fail; the dispatcher then charges neither mana nor cooldown.
local MIN_MOVE = 1.5
-- Gap kept between the player box and a wall face that was aimed at.
local WALL_GAP = 0.05

local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}

local function live_boxes(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "ignore" then
		return FULL
	end
	local def = core.registered_nodes[node.name]
	if not def then
		return FULL
	end
	if not def.walkable then
		return nil
	end
	return core.get_node_boxes("collision_box", pos, node)
end

-- First walkable node on the segment: intersection point and outward face
-- normal of its selection box. Liquids are not returned (passable).
local function live_ray(from, to)
	for hit in core.raycast(from, to, false, false) do
		if hit.type == "node" then
			local node = core.get_node_or_nil(hit.under)
			local def = node and core.registered_nodes[node.name]
			if not def or def.walkable then
				return hit.intersection_point, hit.intersection_normal
			end
		end
	end
	return nil
end

local LIVE = {boxes = live_boxes, ray = live_ray}

local floor, min, max = math.floor, math.min, math.max

-- Highest top of any walkable collision box overlapping the player box with
-- its feet at (x, y, z); nil when the box is free. Faces that merely touch do
-- not overlap. One node row below the box is included because node boxes may
-- reach up out of their own node (fences).
local function blocking_top(world, box, x, y, z)
	local x1, x2 = x + box[1] + EPS, x + box[4] - EPS
	local y1, y2 = y + box[2] + EPS, y + box[5] - EPS
	local z1, z2 = z + box[3] + EPS, z + box[6] - EPS
	local top
	for nx = floor(x1 + 0.5), floor(x2 + 0.5) do
		for ny = floor(y1 + 0.5) - 1, floor(y2 + 0.5) do
			for nz = floor(z1 + 0.5), floor(z2 + 0.5) do
				local boxes = world.boxes({x = nx, y = ny, z = nz})
				if boxes then
					for _, b in ipairs(boxes) do
						local by1 = ny + min(b[2], b[5])
						local by2 = ny + max(b[2], b[5])
						if by1 < y2 and by2 > y1 and
								nx + min(b[1], b[4]) < x2 and nx + max(b[1], b[4]) > x1 and
								nz + min(b[3], b[6]) < z2 and nz + max(b[3], b[6]) > z1 and
								(not top or by2 > top) then
							top = by2
						end
					end
				end
			end
		end
	end
	return top
end

-- Feet position at (x, z) at height y or, when something is in the way, on
-- top of it if that is at most `rise` higher. nil when it does not fit.
local function settle(world, box, x, y, z, rise)
	local base = y
	for _ = 1, 4 do
		local top = blocking_top(world, box, x, y, z)
		if not top then
			return vector.new(x, y, z)
		end
		if top - base > rise + EPS then
			return nil
		end
		y = top
	end
	return nil
end

return function(eye, dir, distance, eye_height, box, world)
	world = world or LIVE
	local from = vector.offset(eye, 0, -eye_height, 0)
	local function accept(feet)
		return feet and vector.distance(from, feet) >= MIN_MOVE and
			world.ray(eye, vector.offset(feet, 0, eye_height, 0)) == nil
	end
	local point, normal = world.ray(eye,
		vector.add(eye, vector.multiply(dir, distance)))
	-- `ref` is the preferred feet spot; `picks` are the spots tried there.
	local ref, picks
	if not point then
		-- Nothing hit: full distance, even into the air (falling is fine).
		ref = vector.add(from, vector.multiply(dir, distance))
		picks = {settle(world, box, ref.x, ref.y, ref.z, MAX_RISE)}
	elseif normal.y > 0.5 then
		-- A top face: stand on it at the aimed point.
		ref = vector.copy(point)
		picks = {settle(world, box, ref.x, ref.y, ref.z, MAX_RISE)}
	elseif normal.y < -0.5 then
		-- A ceiling: hang the head just below it (and fall).
		ref = vector.offset(point, 0, -box[5] - WALL_GAP, 0)
		picks = {settle(world, box, ref.x, ref.y, ref.z, 0)}
	elseif normal.x ~= 0 or normal.z ~= 0 then
		-- A side face: eye level in front of the wall; stand on the ground
		-- there when the feet would be in it, or in the air as before.
		local half = max(-box[1], box[4], -box[3], box[6])
		local front = vector.add(point, vector.multiply(normal, half + WALL_GAP))
		ref = vector.offset(front, 0, -eye_height, 0)
		local stand = settle(world, box, ref.x, ref.y, ref.z, eye_height)
		ref = stand or ref
		-- Step up at most one node onto the aimed node's top. The ledge spot
		-- is the aimed node's centre along the face normal.
		local node = vector.round(vector.subtract(point,
			vector.multiply(normal, 0.01)))
		local lx = normal.x ~= 0 and node.x or point.x
		local lz = normal.z ~= 0 and node.z or point.z
		local ledge = settle(world, box, lx, ref.y, lz, MAX_RISE)
		if ledge and ledge.y <= ref.y + EPS then
			ledge = nil
		end
		picks = {ledge, stand}
	else
		-- The eye is inside a selection box (zero normal).
		return nil
	end
	for i = 1, 2 do
		if accept(picks[i]) then
			return picks[i]
		end
	end
	-- Back-search toward the caster horizontally (along the line only when
	-- the spot is almost straight above or below), up to one node higher.
	local dx, dz = from.x - ref.x, from.z - ref.z
	local span = math.sqrt(dx * dx + dz * dz)
	local step
	if span >= STEP then
		step = vector.new(dx / span * STEP, 0, dz / span * STEP)
	else
		span = vector.distance(from, ref)
		step = vector.multiply(vector.direction(ref, from), STEP)
	end
	for k = 1, floor(span / STEP) do
		local p = vector.add(ref, vector.multiply(step, k))
		if vector.distance(from, p) < MIN_MOVE - EPS then
			break
		end
		local spot = settle(world, box, p.x, p.y, p.z, MAX_RISE)
		if accept(spot) then
			return spot
		end
		-- The column centre: a box straddling a column edge may fit there.
		local cx, cz = floor(p.x + 0.5), floor(p.z + 0.5)
		spot = settle(world, box, cx, p.y, cz, MAX_RISE)
		if accept(spot) then
			return spot
		end
	end
	return nil
end
