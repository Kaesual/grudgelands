-- Tree prototype (Round 46 lane TREE): the wood shapes, as plain data.
--
-- Four shapes per wood type. Boxes are in sixteenths of a node, centred on
-- the node (-8..8), in the order x1, y1, z1, x2, y2, z2. init.lua turns them
-- into node boxes; metrics.lua and the fixture read the same table, so the
-- face counts describe exactly what is registered.
--
--   corner  a quarter-round trunk piece (paramtype2 facedir, values 0..3).
--           Its inner corner, the trunk's axis, is at +x +z for param2 0;
--           four make a round 2 x 2 trunk, and on the corners of a 3 x 3
--           trunk they round it. Three stepped boxes approximate a quarter
--           disc of radius one node round the inner corner.
--   branch  a thick limb, 10/16 wide: a connected node box, so one node is
--           every straight piece, elbow, fork and end. It joins whatever wood
--           of the same type touches its faces.
--   twig    the same at 6/16: limb tips and the twigs that carry a crown.
--   root    a buttress fin: a vertical board 8/16 thick and a full node
--           high, also connected, so a row of them is one board that steps
--           down away from the trunk.
--
-- Connected boxes never rotate (src/mapnode.cpp transformNodeBox: only the
-- fixed and leveled types turn with facedir), so a branch or a fin needs no
-- param2 at all; only the corner does.
--
-- Plain Lua 5.1, pure, no engine calls.

local M = {}

-- Half widths in sixteenths.
local BRANCH = 5
local TWIG = 3
local FIN = 4

-- The six arms of a connected box of half width `h`, by engine side name
-- (lua_api.md "Node boxes": front is -z, back +z, left -x, right +x).
local function arms(h, full_height)
	local low, high = -h, h
	if full_height then low, high = -8, 8 end
	local result = {
		front = {-h, low, -8, h, high, -h},
		back = {-h, low, h, h, high, 8},
		left = {-8, low, -h, -h, high, h},
		right = {h, low, -h, 8, high, h},
	}
	if not full_height then
		result.top = {-h, h, -h, h, 8, h}
		result.bottom = {-h, -8, -h, h, -h, h}
	end
	return result
end

M.SIDES = {"top", "bottom", "front", "left", "back", "right"}
-- Unit offset of each side, matching the engine's neighbour flags
-- (src/mapnode.cpp getNeighbors: 1 top, 2 bottom, 4 z-, 8 x-, 16 z+, 32 x+).
M.SIDE_OFFSET = {
	top = {0, 1, 0}, bottom = {0, -1, 0}, front = {0, 0, -1},
	left = {-1, 0, 0}, back = {0, 0, 1}, right = {1, 0, 0},
}

M.ORDER = {"corner", "branch", "twig", "root"}

M.SHAPES = {
	corner = {
		kind = "fixed",
		boxes = {
			{-8, -8, 0, 8, 8, 8},
			{-5, -8, -5, 8, 8, 0},
			{0, -8, -8, 8, 8, -5},
		},
		-- top and bottom show the trunk's end grain, the sides its bark
		tiles = "top_top_bark",
	},
	branch = {
		kind = "connected",
		core = {-BRANCH, -BRANCH, -BRANCH, BRANCH, BRANCH, BRANCH},
		arms = arms(BRANCH, false),
		tiles = "bark",
	},
	twig = {
		kind = "connected",
		core = {-TWIG, -TWIG, -TWIG, TWIG, TWIG, TWIG},
		arms = arms(TWIG, false),
		tiles = "bark",
	},
	root = {
		kind = "connected",
		core = {-FIN, -8, -FIN, FIN, 8, FIN},
		arms = arms(FIN, true),
		tiles = "bark",
	},
}

-- facedir param2 of a corner piece whose inner corner (the trunk axis) lies
-- towards (sx, sz), each -1 or 1. facedir 1 turns a box by rotateXZBy(-90),
-- (x, z) -> (z, -x) (src/mapnode.cpp transformNodeBox, irr vector3d.h
-- rotateXZBy), so +x+z goes to +x-z under 1, -x-z under 2 and -x+z under 3.
function M.corner_param2(sx, sz)
	if sx > 0 then
		return sz > 0 and 0 or 1
	end
	return sz < 0 and 2 or 3
end

-- One box turned by a facedir 0..3 the way the engine does it.
function M.rotate_box(box, param2)
	local x1, z1, x2, z2 = box[1], box[3], box[4], box[6]
	for _ = 1, param2 % 4 do
		-- rotateXZBy(-90): (x, z) -> (z, -x)
		x1, z1 = z1, -x1
		x2, z2 = z2, -x2
	end
	return {math.min(x1, x2), box[2], math.min(z1, z2),
		math.max(x1, x2), box[5], math.max(z1, z2)}
end

-- The boxes the client draws for one node: `connected` is a set of side
-- names that have a joining neighbour (ignored by the corner).
function M.boxes(name, param2, connected)
	local shape = M.SHAPES[name]
	local result = {}
	if shape.kind == "fixed" then
		for index = 1, #shape.boxes do
			result[index] = M.rotate_box(shape.boxes[index], param2 or 0)
		end
		return result
	end
	result[1] = shape.core
	for _, side in ipairs(M.SIDES) do
		if connected[side] and shape.arms[side] then
			result[#result + 1] = shape.arms[side]
		end
	end
	return result
end

return M
