-- Capital protection outline (Round 22, plan D76). A capital's immutable
-- ground is its city: everything inside the wall line of the planned layout,
-- the wall with its gatehouses and turrets, and a band of 12 nodes or more
-- beyond the edge's outermost structure (21 from the wall line). It replaces the old 532-node square
-- (`hard_capital_build_plus_apron_v1`). Every capital's edge -- a stone
-- curtain or a palisade since Round 23 -- stands on its planned outline, so
-- the same line bounds all six. A capital's own
-- civic lake (Lethariel's crown lake, Kezamba's cenote) belongs to the city
-- even where the outline crosses it.
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

-- The edge's outermost structure from the wall line: a gatehouse corner. A
-- gatehouse box (depth 5, width 7) stays compass-aligned while its gate
-- slides up to ~34 degrees along the wall, so a corner reaches ~8.7 beyond
-- the wall line; turrets (radius 5) and wall faces (half 2-3) reach less
-- (`capital_planner.lua` M.EDGE, `wp13/city_edge.lua`).
M.EDGE_REACH = 9
-- The band beyond that structure (D76: 10-20 nodes): no trees, so a player
-- sees where the protection ends; since Round 36 W3 a share of it grows the
-- zone's ground cover, thinning toward the wall. With the reach above it
-- lies 21 from the wall line: ~12 beyond a gatehouse corner, 16 beyond a
-- turret, 17.5-18.5 beyond a wall face.
M.BAND = 12
-- The reserved square the shape must stay inside: the anchor-relative half
-- width of the capital's hard-protection index box (`source/simple_map.lua`,
-- `hard_capital_city_v1` bound_width 532). The planner keeps the wall line
-- within 230 of the anchor on each axis (reserved half 256 minus its 26-node
-- band), 36 nodes short of 266, so the protected band always fits.
M.BOUND_HALF = 266

local function fail(message)
	error("WP40 capital protection: " .. message, 0)
end

-- Sorted, merged union of x intervals {a1, b1, a2, b2, ...}.
local function merge(spans)
	table.sort(spans, function(p, q) return p[1] < q[1] end)
	local out = {}
	local a, b
	for i = 1, #spans do
		local s = spans[i]
		if a and s[1] <= b then
			if s[2] > b then b = s[2] end
		else
			if a then out[#out + 1], out[#out + 2] = a, b end
			a, b = s[1], s[2]
		end
	end
	if a then out[#out + 1], out[#out + 2] = a, b end
	return out
end

-- `layout`: a deserialized capital layout (`capital_planner.lua`
-- M.deserialize), local coordinates relative to its anchor. `lake`: the
-- capital's own civic lake (an authored water row of `water_authored.lua`:
-- Lethariel's crown lake, Kezamba's cenote) or nil. The planned outline may
-- cross it (the wall snaps to its banks or crosses as an arcade or a timber
-- deck); the whole civic lake belongs to the city all the same.
function M.build(layout, lake)
	if type(layout) ~= "table" or type(layout.anchor) ~= "table" or
			type(layout.wall) ~= "table" or type(layout.wall.pts) ~= "table" or
			#layout.wall.pts < 3 then
		fail("layout differs")
	end
	local AX, AZ = layout.anchor.x, layout.anchor.z
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
	local spans_of = {}
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
		local spans = {}
		for i = 1, #xs, 2 do spans[#spans + 1] = {xs[i], xs[i + 1]} end
		spans_of[z] = spans
	end
	--    plus the civic lake's planned water (indicator >= 0.5), node runs
	if lake ~= nil then
		if type(lake) ~= "table" or type(lake.indicator) ~= "function" or
				type(lake.min_x) ~= "number" then
			fail("civic lake differs")
		end
		for z = lake.min_z, lake.max_z do
			local lz = z - AZ
			local run
			for x = lake.min_x, lake.max_x + 1 do
				local wet = x <= lake.max_x and lake.indicator(x, z) >= 0.5
				if wet and not run then
					run = x
				elseif not wet and run then
					local spans = spans_of[lz]
					if not spans then spans = {}; spans_of[lz] = spans end
					spans[#spans + 1] = {run - AX - 0.5, x - 1 - AX + 0.5}
					z_lo, z_hi = min(z_lo, lz), max(z_hi, lz)
					run = nil
				end
			end
		end
	end
	local inside = {}
	for z, spans in pairs(spans_of) do inside[z] = merge(spans) end
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
			local out = merge(spans)
			for i = 1, #out, 2 do out[i], out[i + 1] = ceil(out[i]), floor(out[i + 1]) end
			rows[z] = out
			bounds.min_x = min(bounds.min_x, out[1])
			bounds.max_x = max(bounds.max_x, out[#out])
		end
	end
	local H = M.BOUND_HALF
	if bounds.min_x < -H or bounds.max_x >= H or bounds.min_z < -H or bounds.max_z >= H then
		fail(layout.anchor.id .. ": the protected city leaves its reserved square")
	end
	local shape = {anchor = layout.anchor, rows = rows, bounds = {
		min_x = AX + bounds.min_x, max_x = AX + bounds.max_x,
		min_z = AZ + bounds.min_z, max_z = AZ + bounds.max_z}}
	-- The query form: per row (array index from 1) its first interval in two
	-- flat arrays, the rare further intervals in a side table; nearly every
	-- row of a round city is one interval.
	local Z0 = AZ + bounds.min_z - 1
	local LO, HI, MORE = {}, {}, {}
	for k = 1, bounds.max_z - bounds.min_z + 1 do
		local row = rows[bounds.min_z + k - 1]
		if row then
			LO[k], HI[k] = row[1], row[2]
			if #row > 2 then
				local more = {}
				for i = 3, #row do more[i - 2] = row[i] end
				MORE[k] = more
			end
		else
			-- an empty row inside the span (never for one city): no member
			LO[k], HI[k] = 1, 0
		end
	end
	-- world columns
	function shape.member(x, z)
		local k = z - Z0
		local lo = LO[k]
		if not lo then return false end
		local lx = x - AX
		if lx < lo then return false end
		if lx <= HI[k] then return true end
		local more = MORE[k]
		if not more then return false end
		for i = 1, #more, 2 do
			if lx < more[i] then return false end
			if lx <= more[i + 1] then return true end
		end
		return false
	end
	-- The squared distance of a world column's centre from the inside rows
	-- (the measure the band dilation above uses: a column is a member exactly
	-- when it is at most `reach` squared), 0 inside, nil beyond `reach`.
	-- Ground cover in the band asks it (Round 36 W3, `simple_map.lua`
	-- band_cover); `edge_reach` and `band` say where the band lies.
	function shape.distance2(x, z)
		local lx, lz = x - AX, z - AZ
		local best
		for dz = -reach, reach do
			local xs = inside[lz + dz]
			if xs then
				for i = 1, #xs, 2 do
					local dx = xs[i] - lx
					if dx < 0 then dx = max(lx - xs[i + 1], 0) end
					local d2 = dx * dx + dz * dz
					if best == nil or d2 < best then best = d2 end
				end
			end
		end
		if best ~= nil and best <= reach * reach then return best end
		return nil
	end
	shape.edge_reach, shape.band = M.EDGE_REACH, M.BAND
	-- inside the wall line or the civic lake (the band excluded)
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
-- as `r7_capitals.parse` returns them, or {anchor id -> layout}; `lakes`
-- {anchor id -> civic lake row} (optional).
function M.install(holder, layouts, lakes)
	if type(holder) ~= "table" or type(layouts) ~= "table" or
			(lakes ~= nil and type(lakes) ~= "table") then
		fail("install seam differs")
	end
	local shapes = {}
	for id, entry in pairs(layouts) do
		local layout = entry.layout or entry
		if layout.anchor.id ~= id then fail("layout anchor differs: " .. tostring(id)) end
		shapes[id] = M.build(layout, lakes and lakes[id])
	end
	holder.shapes = shapes
	return holder
end

return M
