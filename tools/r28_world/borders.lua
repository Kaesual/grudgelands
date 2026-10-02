-- Round 28 Lane W1: the level fit across zone borders (pure Lua, LuaJIT or
-- 5.1), for the world view (world.lua) and its fixture
-- (tools/r28_w1/portable_test.lua).
--
--   local B = dofile(repo .. "/tools/r28_world/borders.lua")
--   local cells = B.cells(zones)       -- key -> {zone, lo, hi}
--   local edges = B.edges(zones)       -- every border edge, classified
--
-- `zones`: a list of {id, band = {lo, hi}, cells = {{i, j, lo, hi}, ...}}
-- (lo/hi: the level range of the cell's region; nil for a zone without a
-- recipe). The cells lie on the spawn-region grid (32 nodes, world
-- multiples). A cell two zones both list (a tie of the plurality rule) is
-- kept by the first zone in list order and counted in `duplicates`.
--
-- An edge is a side shared by two land cells of different zones (four
-- neighbours, so one edge is 32 nodes of border). Its class compares the two
-- regions' level ranges: the gap is the distance between the ranges (0 when
-- they overlap, 1 when they touch: 10 next to 11).
--   fit     gap <= 1                      (green)
--   step    gap 2..5                      (yellow)
--   jump    gap > 5                       (red)
--   forced  the zones' bands are more than 5 apart, so no recipe can close
--           the gap (a start zone 1-10 beside a heartland 21-30)  (purple)
--   none    a side has no recipe (no levels to compare)
local M = {}

M.FIT = 1
M.STEP = 5
M.CLASSES = {"fit", "step", "jump", "forced", "none"}

function M.key(i, j)
	return i * 65536 + j
end

-- The distance between two level ranges (0 when they overlap).
function M.gap(a_lo, a_hi, b_lo, b_hi)
	return math.max(0, b_lo - a_hi, a_lo - b_hi)
end

function M.class(gap, band_gap)
	if band_gap > M.STEP then return "forced" end
	if gap == nil then return "none" end
	if gap <= M.FIT then return "fit" end
	if gap <= M.STEP then return "step" end
	return "jump"
end

-- key -> {zone = index, lo, hi}; duplicates = cells listed twice.
function M.cells(zones)
	local out, duplicates = {}, 0
	for z, zone in ipairs(zones) do
		for _, c in ipairs(zone.cells) do
			local k = M.key(c[1], c[2])
			if out[k] then
				duplicates = duplicates + 1
			else
				out[k] = {zone = z, i = c[1], j = c[2], lo = c[3], hi = c[4]}
			end
		end
	end
	return out, duplicates
end

-- The border edges, in a fixed order (zone list order, then the cells'
-- order): {i, j, side ("e": the side toward i + 1, "n": toward j + 1),
-- a, b (zone indices: a owns cell i, j), a_lo, a_hi, b_lo, b_hi, gap,
-- band_gap, class}.
function M.edges(zones)
	local grid, duplicates = M.cells(zones)
	local edges = {}
	for z, zone in ipairs(zones) do
		for _, c in ipairs(zone.cells) do
			local mine = grid[M.key(c[1], c[2])]
			if mine and mine.zone == z then
				for _, side in ipairs({{"e", 1, 0}, {"n", 0, 1}}) do
					local other = grid[M.key(c[1] + side[2], c[2] + side[3])]
					if other and other.zone ~= z then
						local za, zb = zone, zones[other.zone]
						local band_gap = M.gap(za.band[1], za.band[2], zb.band[1], zb.band[2])
						local gap
						if mine.lo and other.lo then
							gap = M.gap(mine.lo, mine.hi, other.lo, other.hi)
						end
						edges[#edges + 1] = {i = c[1], j = c[2], side = side[1], a = z,
							b = other.zone, a_lo = mine.lo, a_hi = mine.hi, b_lo = other.lo,
							b_hi = other.hi, gap = gap, band_gap = band_gap,
							class = M.class(gap, band_gap)}
					end
				end
			end
		end
	end
	return edges, duplicates
end

-- Border length per class in nodes (CELL nodes per edge).
function M.totals(edges, cell)
	local out = {}
	for _, name in ipairs(M.CLASSES) do out[name] = 0 end
	for _, e in ipairs(edges) do
		out[e.class] = out[e.class] + cell
	end
	return out
end

return M
