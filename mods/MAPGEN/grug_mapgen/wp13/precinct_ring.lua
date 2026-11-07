-- Shared geometry for the protected boundary of a capital's civic core.
--
-- This file is the ONE SOURCE of the civic core's size (Round 70, radius 56
-- in all six capitals): everything that needs it reads it from here, the
-- compositions, `city_green.lua`, the capital planner and the settlement
-- bounds. The fitting profiles' `civic_width` (`wp40/source/simple_map.lua`)
-- is plain data and cannot read a module, so `wp40/r7_capitals.lua` fails the
-- load when it differs from CIVIC_WIDTH.
--
-- The ring lies one column inside the 115 x 115 core pad, at +/-56. Structural
-- content is authored before it, so a house, orchard, green or prop cannot
-- silently cut the boundary. Later free-cell dressing respects it. Only the
-- four thirteen-column gatehouse/threshold bands are omitted here. A capital
-- may additionally skip an authored corner tower or water edge and verify that
-- structure itself.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local M = {}

M.RADIUS = 56
M.PAD = M.RADIUS + 1          -- the pad's half width, the compositions' RADIUS
M.CIVIC_WIDTH = 2 * M.RADIUS  -- the fitting profiles' civic_width
M.CORNER = M.RADIUS - 1       -- the corner towers' centres
M.GATE_HALF = 6

function M.is_gate(x, z, gate_half)
	local half = gate_half or M.GATE_HALF
	return (math.abs(x) == M.RADIUS and math.abs(z) <= half) or
		(math.abs(z) == M.RADIUS and math.abs(x) <= half)
end

-- The corner drums and towers of Dur Brannoc, Gor Drazhak and Nhal Veyr are
-- 5 x 5 squares centred on (+/-CORNER, +/-CORNER), so their walls reach two
-- columns inside it and those ring columns are theirs: a ring that wrote there
-- cut the tower's own masonry (Round 23 found Nhal Veyr's bars and Gor
-- Drazhak's earth in the tower walls). The first ring column beyond the skip
-- stands against the tower wall.
function M.is_corner(x, z, corner_half)
	local half = corner_half or 3
	return math.abs(x) >= M.RADIUS - half and
		math.abs(z) >= M.RADIUS - half
end

-- A wallmounted fitting beside a hedge column may have been attached to the
-- building or tree the protected ring replaces. Remove only fittings whose
-- support direction points at this exact column; leaving one behind would make
-- the engine drop it as soon as the loose hedge leaves update.
local WALL_SUPPORT = {
	[2] = {1, 0}, [3] = {-1, 0}, [4] = {0, 1}, [5] = {0, -1},
}

function M.clear_wallmounted(buf, parts, x, z, max_y)
	for _, step in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
		local nx, nz = x + step[1], z + step[2]
		for y = 1, max_y do
			local cell = buf:at(nx, y, nz)
			if cell and parts.param2_kind(cell.name) == parts.WALLMOUNTED then
				local support = WALL_SUPPORT[cell.param2]
				if support and nx + support[1] == x and nz + support[2] == z then
					buf:put(nx, y, nz, parts.AIR, 0)
				end
			end
		end
	end
end

function M.walk(write, options)
	if type(write) ~= "function" then
		error("wp13 precinct ring: writer differs", 0)
	end
	options = options or {}
	local seen = {}
	local written = 0
	for offset = -M.RADIUS, M.RADIUS do
		for _, spot in ipairs({{offset, -M.RADIUS}, {M.RADIUS, offset},
				{offset, M.RADIUS}, {-M.RADIUS, offset}}) do
			local x, z = spot[1], spot[2]
			local key = x .. ":" .. z
			local skipped = M.is_gate(x, z, options.gate_half)
			if not skipped and options.skip then skipped = options.skip(x, z) end
			if not seen[key] and not skipped then
				seen[key] = true
				write(x, z)
				written = written + 1
			end
		end
	end
	return written
end

return M
