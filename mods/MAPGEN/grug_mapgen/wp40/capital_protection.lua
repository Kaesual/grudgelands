-- Capital protection outline (Round 22, plan D76). A capital's immutable
-- ground is its city: everything inside the wall line of the planned layout,
-- the wall with its gatehouses and turrets, and a band of about 12 nodes
-- beyond the edge's outermost structure. It replaces the old 532-node square
-- (`hard_capital_build_plus_apron_v1`). The open capitals (Lethariel,
-- Kezamba) have no closed wall; their planted belt and four thresholds stand
-- on the same planned outline, so the same line bounds them.
--
-- The shape is computed once per environment from the parsed capital layouts
-- (main and emerge parse the same payload text, so they agree exactly) and
-- kept as integer column intervals per row: a query is one table index and
-- one or two comparisons.
--
--   local P = dofile(".../capital_protection.lua")
--   local shape = P.build(layout)           -- a deserialized capital layout
--   shape.member(x, z)                      -- world columns
--   P.install(holder, layouts)              -- {anchor id -> layout} into the
--                                           -- holder the horizontal sessions
--                                           -- share (`r7_runtime.lua`)
--
-- Plain Lua 5.1, pure, no globals, no engine calls.
local floor, ceil, sqrt, min, max = math.floor, math.ceil, math.sqrt, math.min, math.max

local M = {}

-- The edge's outermost structure from the wall line: a turret disc (radius
-- 5) or a gatehouse's outer face (depth 5), plus one node
-- (`capital_planner.lua` M.EDGE, `wp13/city_edge.lua`).
M.EDGE_REACH = 6
-- The band beyond that structure (D76: 10-20 nodes from the wall): no trees,
-- no ground cover, so a player sees where the protection ends.
M.BAND = 12
-- The reserved square the shape must stay inside: the anchor-relative half
-- width of the capital's hard-protection index box (`source/simple_map.lua`,
-- `hard_capital_city_v1` bound_width 532). The planner's outline keeps
-- 26 + (256 - 230) nodes clear of it, so the band always fits.
M.BOUND_HALF = 266

local function fail(message)
	error("WP40 capital protection: " .. message, 0)
end

-- `layout`: a deserialized capital layout (`capital_planner.lua`
-- M.deserialize), local coordinates relative to its anchor.
function M.build(layout)
	if type(layout) ~= "table" or type(layout.anchor) ~= "table" or
			type(layout.wall) ~= "table" or type(layout.wall.pts) ~= "table" or
			#layout.wall.pts < 3 then
		fail("layout differs")
	end
	local pts = layout.wall.pts
	local n = #pts
	local reach = M.EDGE_REACH + M.BAND
	local z_lo, z_hi = math.huge, -math.huge
	for i = 1, n do
		z_lo, z_hi = min(z_lo, pts[i][2]), max(z_hi, pts[i][2])
	end
	z_lo, z_hi = ceil(z_lo), floor(z_hi)
	-- 1. inside the wall line: per node row (its centre z), the crossings of
	--    the closed polyline, paired into x intervals (even-odd rule)
	local inside = {}
	for z = z_lo, z_hi do
		local xs = {}
		for i = 1, n do
			local a, b = pts[i], pts[i % n + 1]
			local az, bz = a[2], b[2]
			if (az <= z and bz > z) or (bz <= z and az > z) then
				xs[#xs + 1] = a[1] + (z - az) / (bz - az) * (b[1] - a[1])
			end
		end
		table.sort(xs)
		if #xs % 2 ~= 0 then fail("wall line is not closed") end
		inside[z] = xs
	end
	-- 2. the band: every row takes each inside interval of the rows within
	--    `reach` widened by the circle's half chord there (an exact Euclidean
	--    dilation of the inside rows), merged; a node belongs when its centre
	--    lies in a merged interval
	local rows, bounds = {}, {min_x = math.huge, max_x = -math.huge,
		min_z = z_lo - reach, max_z = z_hi + reach}
	for z = z_lo - reach, z_hi + reach do
		local spans = {}
		for dz = -reach, reach do
			local xs = inside[z + dz]
			if xs then
				local w = sqrt(reach * reach - dz * dz)
				for i = 1, #xs, 2 do
					spans[#spans + 1] = {xs[i] - w, xs[i + 1] + w}
				end
			end
		end
		if #spans > 0 then
			table.sort(spans, function(p, q) return p[1] < q[1] end)
			local out = {}
			local a, b = spans[1][1], spans[1][2]
			for i = 2, #spans do
				local s = spans[i]
				if s[1] <= b then
					if s[2] > b then b = s[2] end
				else
					out[#out + 1], out[#out + 2] = ceil(a), floor(b)
					a, b = s[1], s[2]
				end
			end
			out[#out + 1], out[#out + 2] = ceil(a), floor(b)
			rows[z] = out
			bounds.min_x = min(bounds.min_x, out[1])
			bounds.max_x = max(bounds.max_x, out[#out])
		end
	end
	local H = M.BOUND_HALF
	if bounds.min_x < -H or bounds.max_x >= H or bounds.min_z < -H or bounds.max_z >= H then
		fail(layout.anchor.id .. ": the protected city leaves its reserved square")
	end
	local AX, AZ = layout.anchor.x, layout.anchor.z
	local shape = {anchor = layout.anchor, rows = rows, bounds = {
		min_x = AX + bounds.min_x, max_x = AX + bounds.max_x,
		min_z = AZ + bounds.min_z, max_z = AZ + bounds.max_z}}
	-- world columns
	function shape.member(x, z)
		local row = rows[z - AZ]
		if not row then return false end
		local lx = x - AX
		for i = 1, #row, 2 do
			if lx < row[i] then return false end
			if lx <= row[i + 1] then return true end
		end
		return false
	end
	-- inside the wall line itself (the band excluded): local node centres
	function shape.inside(x, z)
		local xs = inside[z - AZ]
		if not xs then return false end
		local lx = x - AX
		for i = 1, #xs, 2 do
			if lx >= xs[i] and lx <= xs[i + 1] then return true end
		end
		return false
	end
	return shape
end

-- Fills `holder` (the table `r7_runtime.lua` hands every horizontal session
-- it builds) with the shapes of the parsed layouts: {anchor id -> {layout}}
-- as `r7_capitals.parse` returns them, or {anchor id -> layout}.
function M.install(holder, layouts)
	if type(holder) ~= "table" or type(layouts) ~= "table" then fail("install seam differs") end
	local shapes = {}
	for id, entry in pairs(layouts) do
		local layout = entry.layout or entry
		if layout.anchor.id ~= id then fail("layout anchor differs: " .. tostring(id)) end
		shapes[id] = M.build(layout)
	end
	holder.shapes = shapes
	return holder
end

return M
