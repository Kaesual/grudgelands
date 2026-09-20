-- Shared geometry for the protected boundary of a capital's civic core.
--
-- The ring lies one column inside the 99 x 99 core pad, at +/-48. Structural
-- content is authored before it, so a house, orchard, green or prop cannot
-- silently cut the boundary. Later free-cell dressing respects it. Only the
-- four thirteen-column gatehouse/threshold bands are omitted here. A capital
-- may additionally skip an authored corner tower or water edge and verify that
-- structure itself.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local M = {}

M.RADIUS = 48
M.GATE_HALF = 6

function M.is_gate(x, z, gate_half)
	local half = gate_half or M.GATE_HALF
	return (math.abs(x) == M.RADIUS and math.abs(z) <= half) or
		(math.abs(z) == M.RADIUS and math.abs(x) <= half)
end

function M.is_corner(x, z, corner_half)
	local half = corner_half or 2
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
