-- Authored lakes (world_zones.md §7.4; plan D26, D34, D41, D42): civic water
-- and water landmarks that do not arise from drainage -- the Kezamba cenote,
-- the Lethariel crown lake, Highcourt's canals, the Dawnmere and Sunscar
-- ponds, Moonfall's crescent. Loaded in main and in emerge alike (every value
-- must be a pure function of the coordinates), handed to `height.lua`, which
-- applies them on the FITTED terrain (after the anchor fittings, before the
-- shore rule). They are not part of the drainage layout, so no start or
-- capital keep-out applies to them; natural rivers and lakes still keep out
-- of the keep-outs. Their water is ordinary water, sealed like every inland
-- water body, and the columns are `planned_water`.
--
-- The file returns function(P) -> rows, P the water parameters of
-- `terrain_data.lua` (LAKE_PROXY scales the indicators). One row per lake:
--   id           unique text; the column's sealed water id is "lake:<id>"
--   min_x, min_z, max_x, max_z
--                integer bounds of every column the lake touches (its bank
--                envelope included)
--   indicator    function(x, z) -> m in 0..1: wet where m >= 0.5 and the
--                ground lies below the level; the bank is raised to the level
--                where rim <= m < 0.5. A soft, warped field keeps shores
--                natural (seam rules: true distances into ramps, no bilinear
--                reads, no arc parameters, rounded creases).
--   level        absolute water surface y, or omit it and give
--   anchor, level_offset
--                the anchor id whose fitted reference y (the flat core of a
--                start or capital) plus level_offset is the surface, or
--   shore_level, level_offset
--                the lowest fitted ground on the lake's bank ring
--   depth        optional carved bed: where m >= 0.5 the ground is lowered to
--                at most level - 1 - (depth - 1) * smoothstep(0.5, 0.9, m)
--   bed_step     optional: that carve in steps of this many nodes (ledges)
--   bank         optional shore envelope {up, down} (height.lua): banks
--                instead of walls, natural dams instead of one-column dikes
--   bank_weight  optional function(x, z) -> 0..1 scaling the envelope
--   rim          optional bank-fill threshold (default here 0.4)
--   keepout      optional {x, z, r}: a natural-water keep-out disc for a lake
--                outside every start and capital (height.lua water inputs)
--
-- Every indicator here is m = 0.5 + s / LAKE_PROXY, s a signed distance in
-- nodes (positive inside), so the height code's bank distance proxy
-- (0.5 - m) * LAKE_PROXY is the true distance to the shore. Shapes are chains
-- of capsules with a radius per point; outside a civic core the distance is
-- moved by a smooth two-octave noise so shores get coves and points.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

-- Gradient noise with a fixed permutation (the shapes are authored, the same
-- in every world; the terrain under them is not).
local perm = {}
do
	for i = 0, 255 do perm[i] = i end
	local state = 20260925
	for i = 255, 1, -1 do
		state = (state * 1103515245 + 12345) % 2147483648
		local j = state % (i + 1)
		perm[i], perm[j] = perm[j], perm[i]
	end
	for i = 0, 255 do perm[i + 256] = perm[i] end
end
local GX = {1, -1, 1, -1, 1, -1, 0, 0}
local GZ = {1, 1, -1, -1, 0, 0, 1, -1}
local function grad(hash, x, z)
	local k = hash % 8 + 1
	return GX[k] * x + GZ[k] * z
end
local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
-- -1..1 (roughly), period one unit.
local function noise(x, z)
	local ix, iz = floor(x), floor(z)
	local fx, fz = x - ix, z - iz
	ix, iz = ix % 256, iz % 256
	local a, b = perm[ix] + iz, perm[ix + 1] + iz
	local u, v = fade(fx), fade(fz)
	local n00 = grad(perm[a], fx, fz)
	local n10 = grad(perm[b], fx - 1, fz)
	local n01 = grad(perm[a + 1], fx, fz - 1)
	local n11 = grad(perm[b + 1], fx - 1, fz - 1)
	local nx0 = n00 + (n10 - n00) * u
	local nx1 = n01 + (n11 - n01) * u
	return (nx0 + (nx1 - nx0) * v) * 1.4
end

local function smoothstep(a, b, v)
	local t = (v - a) / (b - a)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end

-- Signed distance to a capsule chain: points {x, z, r}, the radius linear
-- along each segment; negative inside.
local function chain(points)
	local segs = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local vx, vz = b[1] - a[1], b[2] - a[2]
		segs[#segs + 1] = {ax = a[1], az = a[2], vx = vx, vz = vz,
			l2 = vx * vx + vz * vz, ra = a[3], dr = b[3] - a[3]}
	end
	if #points == 1 then
		local p = points[1]
		segs[1] = {ax = p[1], az = p[2], vx = 0, vz = 0, l2 = 0, ra = p[3], dr = 0}
	end
	return function(x, z)
		local best = math.huge
		for i = 1, #segs do
			local g = segs[i]
			local ox, oz = x - g.ax, z - g.az
			local t = g.l2 > 0 and (ox * g.vx + oz * g.vz) / g.l2 or 0
			if t < 0 then t = 0 elseif t > 1 then t = 1 end
			local ex, ez = ox - t * g.vx, oz - t * g.vz
			local d = sqrt(ex * ex + ez * ez) - (g.ra + g.dr * t)
			if d < best then best = d end
		end
		return best
	end
end

-- Chaikin corner cutting (endpoints kept): a polyline with rounded bends.
local function smooth(points, passes)
	for _ = 1, passes do
		local out = {points[1]}
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local q, r = {}, {}
			for k = 1, #a do
				q[k] = 0.75 * a[k] + 0.25 * b[k]
				r[k] = 0.25 * a[k] + 0.75 * b[k]
			end
			if i > 1 then out[#out + 1] = q end
			if i < #points - 1 then out[#out + 1] = r end
		end
		out[#out + 1] = points[#points]
		points = out
	end
	return points
end

-- The part of a polyline between arc lengths s0 and s1.
local function cut(points, s0, s1)
	local out, s = {}, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local l = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local function at(t)
			local p = {}
			for k = 1, #a do p[k] = a[k] + (b[k] - a[k]) * t end
			return p
		end
		if s + l >= s0 and s <= s1 and l > 0 then
			if #out == 0 then out[1] = at(max(0, (s0 - s) / l)) end
			if s + l <= s1 then out[#out + 1] = b else out[#out + 1] = at((s1 - s) / l) break end
		end
		s = s + l
	end
	return out
end
local function length(points)
	local s = 0
	for i = 1, #points - 1 do
		s = s + sqrt((points[i + 1][1] - points[i][1]) ^ 2 +
			(points[i + 1][2] - points[i][2]) ^ 2)
	end
	return s
end

return function(P)
	local PROXY = assert(P and P.LAKE_PROXY, "water_authored: LAKE_PROXY missing")
	local SUPPORT = 0.5 * PROXY -- the envelope reaches this far beyond the shore
	local rows = {}

	-- A lake from a capsule chain. `warp` {cove, point, period, salt} moves the
	-- shore inward by up to `cove` and outward by up to `point` nodes (a lake
	-- is bitten into more than it bulges, and never much beyond its authored
	-- outline); `keep` {x, z, half, fade} is a civic core square in which
	-- neither the warp nor the bank envelope act (faded in over `fade` nodes
	-- outside it), so inside the core the water is exactly the chain.
	local function lake(spec)
		local sdf = chain(spec.points)
		local warp, keep = spec.warp, spec.keep
		local function keep_weight(x, z)
			if not keep then return 1 end
			local dx = max(0, math.abs(x - keep.x) - keep.half)
			local dz = max(0, math.abs(z - keep.z) - keep.half)
			return smoothstep(2, keep.fade, sqrt(dx * dx + dz * dz))
		end
		local grow = warp and warp.point or 0
		local function indicator(x, z)
			local s = -sdf(x, z)
			if s < -SUPPORT - grow then return 0 end
			if warp then
				local w = keep_weight(x, z)
				if w > 0 then
					local u, v = x / warp.period + warp.salt, z / warp.period - warp.salt
					local n = (noise(u, v) + 0.5 * noise(2.1 * u + 17.3, 2.1 * v - 5.1) +
						0.25 * noise(4.3 * u - 8.9, 4.3 * v + 3.7)) / 1.2
					if n > 1 then n = 1 elseif n < -1 then n = -1 end
					s = s + w * (n < 0 and warp.cove * n or warp.point * n)
				end
			end
			local m = 0.5 + s / PROXY
			if m <= 0 then return 0 elseif m >= 1 then return 1 end
			return m
		end
		local reach = SUPPORT + grow + 2
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(spec.points) do
			x0, x1 = min(x0, p[1] - p[3]), max(x1, p[1] + p[3])
			z0, z1 = min(z0, p[2] - p[3]), max(z1, p[2] + p[3])
		end
		local row = {id = spec.id, indicator = indicator,
			min_x = floor(x0 - reach), max_x = floor(x1 + reach) + 1,
			min_z = floor(z0 - reach), max_z = floor(z1 + reach) + 1,
			level = spec.level, anchor = spec.anchor, shore_level = spec.shore_level,
			level_offset = spec.level_offset, depth = spec.depth,
			bed_step = spec.bed_step, bank = spec.bank, rim = spec.rim or 0.4,
			keepout = spec.keepout}
		if keep then row.bank_weight = keep_weight end
		rows[#rows + 1] = row
		return row
	end

	---------------------------------------------------------------------------
	-- Kezamba cenote (settlements.md, "the one capital whose civic core is not
	-- flat"). The chain is the committed `wp13/kezamba_lagoon.lua` mask (the
	-- old four-basin cenote: inside the civic core the two agree column for
	-- column), so the moot house, the boardwalk decks, their piers and the
	-- anglers stand over real water. The surface is two nodes below the civic
	-- pad: the piers (core y -2..-1) stand in the water and the decks keep a
	-- node of air over it. Deep, with ledges; outside the core the rim is
	-- warped and shaped into banks and low natural dams.
	---------------------------------------------------------------------------
	lake({id = "kezamba_cenote", anchor = "anchor_012", level_offset = -2,
		points = {{1810, 1600, 42}, {1850, 1560, 68}, {1910, 1565, 75},
			{1960, 1610, 48}},
		warp = {cove = 16, point = 6, period = 56, salt = 3.1},
		keep = {x = 1800, z = 1500, half = 47, fade = 30},
		depth = 18, bed_step = 3, bank = {up = 0.9, down = 0.5}})

	---------------------------------------------------------------------------
	-- Lethariel crown lake (settlements.md: the mere precinct, the quay, the
	-- north avenue's causeway). The chain is the old crown lake, which is the
	-- `MERE` table of `wp13/lethariel.lua` inside the civic core; the district
	-- lots of `wp13/lethariel_quadrants.lua` were laid round it. The capital
	-- damping flattened the natural basin, so the bed is carved.
	---------------------------------------------------------------------------
	lake({id = "lethariel_crown_lake", anchor = "anchor_009", level_offset = -2,
		points = {{1800, -1440, 38}, {1840, -1390, 62}, {1900, -1380, 78},
			{1960, -1420, 68}, {1990, -1480, 42}},
		warp = {cove = 16, point = 6, period = 60, salt = 7.7},
		keep = {x = 1800, z = -1500, half = 47, fade = 30},
		depth = 9, bank = {up = 0.7, down = 0.5}})

	---------------------------------------------------------------------------
	-- Highcourt canals (plan D42). The blueprint's lots are staggered round two
	-- river arms that meet north of the core (`wp13/highcourt_quadrants.lua`);
	-- they are filled as civic canals: a chain of level pools along each arm,
	-- each pool at the lowest ground of its own banks, with a short dry weir
	-- between two pools, so the water steps down the terraces without a
	-- water-to-water fall. Narrow, walled where a terrace rises beside them.
	---------------------------------------------------------------------------
	do
		local cx, cz = 0, -1500
		local HW, POOL, WEIR = 5, 80, 4
		-- the centreline meanders by up to MEANDER nodes over about WAVE
		local MEANDER, WAVE = 7, 90
		local arms = {
			{id = "west", points = {{-112, -236}, {-170, -180}, {-180, -80},
				{-100, 40}, {0, 180}}, tail = WEIR + HW},
			{id = "east", points = {{236, -85}, {180, -10}, {0, 180}}, tail = WEIR + HW},
			{id = "outflow", points = {{0, 180}, {30, 236}}, tail = 0},
		}
		for arm_index, arm in ipairs(arms) do
			local pts = {}
			for i, p in ipairs(arm.points) do pts[i] = {cx + p[1], cz + p[2]} end
			pts = smooth(pts, 3)
			local bent, s = {}, 0
			for i = 1, #pts do
				local a, b = pts[max(1, i - 1)], pts[min(#pts, i + 1)]
				local tx, tz = b[1] - a[1], b[2] - a[2]
				local l = sqrt(tx * tx + tz * tz)
				if i > 1 then
					s = s + sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2)
				end
				-- no bend at the two ends (the join and the arm's head stay put)
				local w = smoothstep(0, 40, s) * smoothstep(0, 40, length(pts) - s)
				local o = MEANDER * w * noise(s / WAVE + 0.37, arm_index * 3.3)
				bent[i] = {pts[i][1] - tz / l * o, pts[i][2] + tx / l * o}
			end
			pts = bent
			local total = length(pts) - arm.tail
			local n = max(1, floor(total / POOL + 0.5))
			local span = total / n
			for k = 1, n do
				-- wet caps end HW beyond the centreline piece, so a gap of WEIR
				-- dry columns remains between two pools
				local s0 = (k - 1) * span + (k > 1 and (WEIR / 2 + HW) or 0)
				local s1 = k * span - (WEIR / 2 + HW)
				if k == n then s1 = total - HW end
				local piece = cut(pts, s0, s1)
				local points = {}
				for i, p in ipairs(piece) do points[i] = {p[1], p[2], HW} end
				lake({id = "highcourt_canal_" .. arm.id .. "_" .. k,
					shore_level = true, points = points,
					warp = {cove = 1.5, point = 1, period = 20, salt = 11.3 + k},
					depth = 6, bank = {up = 1.2, down = 0.5}})
			end
		end
	end

	---------------------------------------------------------------------------
	-- The start ponds (world_zones.md §8: Dawnmere's spring ponds among the
	-- fields, Sunscar's shallow waterholes). On the start's calm ground beside
	-- the start core, off its road side.
	---------------------------------------------------------------------------
	lake({id = "dawnmere_pond", shore_level = true,
		points = {{88, -2480, 13}, {112, -2468, 16}},
		warp = {cove = 7, point = 3, period = 18, salt = 21.9},
		depth = 3, bank = {up = 0.5, down = 0.5}})
	lake({id = "sunscar_waterhole_1", shore_level = true,
		points = {{104, 2478, 10}, {114, 2470, 8}},
		warp = {cove = 5, point = 2.5, period = 14, salt = 5.3},
		depth = 2, bank = {up = 0.5, down = 0.5}})
	lake({id = "sunscar_waterhole_2", shore_level = true,
		points = {{146, 2508, 7}},
		warp = {cove = 4, point = 2, period = 12, salt = 9.4},
		depth = 2, bank = {up = 0.5, down = 0.5}})

	---------------------------------------------------------------------------
	-- Moonfall's crescent lake (plan D41; world_zones.md: "the crescent lake
	-- beneath the fallen great silverwood"). The landmark's calm bowl
	-- (`terrain_data.lua`, `bowl`) gives it a shelf; a crescent of capsules
	-- opening south, thick in the middle and tapering to both horns, at the
	-- lowest ground of its banks; a natural-water keep-out round it.
	---------------------------------------------------------------------------
	do
		local cx, cz, R = 2400, -1560, 100
		local points = {}
		for i, a in ipairs({160, 138, 115, 90, 65, 42, 20}) do
			local t = math.rad(a)
			local r = ({7, 15, 22, 26, 22, 15, 7})[i]
			points[i] = {cx + R * math.cos(t), cz + R * math.sin(t), r}
		end
		lake({id = "moonfall_crescent", shore_level = true, points = points,
			warp = {cove = 9, point = 4, period = 36, salt = 13.9},
			depth = 8, bank = {up = 0.6, down = 0.5},
			keepout = {x = 2400, z = -1510, r = 160}})
	end

	return rows
end
