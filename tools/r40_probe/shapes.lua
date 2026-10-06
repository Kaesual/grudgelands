-- Round 40 lane V4: the Charge test courses (PURE Lua; the course builder,
-- the bench and the portable fixture share them).
--
-- A course is a lane three nodes wide along the caster's facing axis. `a`
-- counts nodes along it (0 = the caster's node), `h` node rows up from the
-- row under the caster's feet (h = 0). `floor(a)` is the lane's ground
-- height in nodes; `walls[a]` puts a wall across the lane at a: 1.25 (a low
-- wall the eyes see over) or 2 (a full wall: no line of sight). `dist` is
-- the target's distance in metres (cast range 12 m, kits.lua:324).

local shapes = {}

local floor = math.floor

local function flat() return 0 end

shapes.LIST = {
	short = {dist = 5.3, floor = flat,
		text = "flat, target 5.3 m away (a dash of about 4 m)"},
	long = {dist = 12, floor = flat,
		text = "flat, target 12 m away (a dash of about 10.7 m)"},
	wall = {dist = 9, floor = flat, walls = {[4] = 1.25},
		text = "a 1.25 m wall 4 m out the eyes see over, target 9 m away"},
	wall_high = {dist = 9, floor = flat, walls = {[4] = 2},
		text = "a 2 m wall 4 m out: no line of sight, every variant refuses"},
	step = {dist = 8, floor = function(a) return a >= 5 and 1 or 0 end,
		text = "a one-node step up 4.5 m out, target 8 m away on top"},
	uphill = {dist = 10, floor = function(a) return a >= 2 and floor((a - 1) / 2) or 0 end,
		text = "stairs up one node every two (about 27 degrees), target 10 m away, 4 m higher"},
	ledge = {dist = 9, floor = function(a) return a <= 1 and 3 or 0 end,
		text = "a 3 m ledge 1.5 m out, target 9 m away below"},
	hit = {dist = 10, floor = flat, striker = {a = 5, side = 1.6},
		text = "flat, target 10 m away, a striker beside the lane at 5 m hits whoever passes"},
}
shapes.ORDER = {"short", "long", "wall", "wall_high", "step", "uphill", "ledge", "hit"}

shapes.LANE = 1 -- lateral half width in nodes (three nodes wide)
shapes.BEHIND = 2 -- nodes of lane behind the caster
shapes.AHEAD = 2 -- nodes of lane beyond the target
shapes.HEADROOM = 5 -- cleared rows above the highest ground

shapes.LOW_WALL_BOX = {-0.5, -0.5, -0.5, 0.5, 0.75, 0.5}
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local LOW = {shapes.LOW_WALL_BOX}

function shapes.extent(shape)
	local a1 = math.ceil(shape.dist) + shapes.AHEAD
	local top = 0
	for a = -shapes.BEHIND, a1 do top = math.max(top, shape.floor(a)) end
	return -shapes.BEHIND, a1, top + shapes.HEADROOM
end

-- What the course puts at (a, h): "floor", "wall", "low_wall" or "air".
function shapes.cell(shape, a, h)
	local f = shape.floor(a)
	if h <= f then return "floor" end
	local w = shape.walls and shape.walls[a]
	if w == 1.25 and h == f + 1 then return "low_wall" end
	if w == 2 and h <= f + 2 then return "wall" end
	return "air"
end

-- The caster's and the target's feet, lane along +x from (0, 0, 0): the
-- row under the caster's feet is y = -1, so level ground is at y = -0.5.
function shapes.start(shape)
	return {x = 0, y = shape.floor(0) - 0.5, z = 0}
end
function shapes.target(shape)
	return {x = shape.dist, y = shape.floor(floor(shape.dist + 0.5)) - 0.5, z = 0}
end

-- A table world for the planner and grug_abilities/blink.lua: the course
-- built along +x, natural ground (full nodes) below y = -1 and air above
-- outside the lane.
function shapes.table_world(shape)
	local a0, a1, h1 = shapes.extent(shape)
	local function boxes(x, y, z)
		local h = y + 1
		if x >= a0 and x <= a1 and z >= -shapes.LANE and z <= shapes.LANE and
				h >= 0 and h <= h1 then
			local c = shapes.cell(shape, x, h)
			if c == "floor" or c == "wall" then return FULL end
			if c == "low_wall" then return LOW end
			return nil
		end
		return h <= 0 and FULL or nil
	end
	-- A marching ray (2 cm steps) against the same boxes: enough for tests.
	local function ray(from, to)
		local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local steps = math.max(1, math.ceil(len / 0.02))
		for s = 0, steps do
			local f = s / steps
			local px, py, pz = from.x + dx * f, from.y + dy * f, from.z + dz * f
			local nx, ny, nz = floor(px + 0.5), floor(py + 0.5), floor(pz + 0.5)
			local list = boxes(nx, ny, nz)
			if list then
				for _, b in ipairs(list) do
					if px >= nx + b[1] and px <= nx + b[4] and py >= ny + b[2] and
							py <= ny + b[5] and pz >= nz + b[3] and pz <= nz + b[6] then
						return {x = px, y = py, z = pz}
					end
				end
			end
		end
		return nil
	end
	return {boxes = function(pos) return boxes(pos.x, pos.y, pos.z) end, ray = ray,
		xyz = boxes}
end

return shapes
