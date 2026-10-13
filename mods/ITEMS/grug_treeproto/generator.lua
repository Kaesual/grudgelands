-- Tree prototype (Round 46 lane TREE): a seeded tree generator.
--
-- build(species, seed) returns one tree as a sorted list of cells relative to
-- its root: the ground node under the trunk is (0, 0, 0) and the tree stands
-- on y >= 1. Every number that shapes a tree (height, lean, fork height,
-- limb count, direction, reach and rise, crown pads, roots, leaf tint) is
-- drawn from the seed, inside the ranges its species row allows, so every
-- seed is a different tree of the same character. The same seed always gives
-- the same cells.
--
-- Cell kinds: trunk (the wood type's full log), corner, branch, twig, root
-- (the shapes of shapes.lua), leaves, fruit. A leaves cell carries the
-- palette param2 of its tint (index * 32: an 8-colour palette is stretched
-- over the 256 param2 values, src/client/texturesource.cpp getPalette).
--
-- Every species keeps inside a bounding box that fits the world generator's
-- template limits (x and z at most 16 wide, grug_mapgen wp40/r6_templates.lua), and every
-- leaf keeps a wood cell within its leaf decay radius: a leaf that would have
-- none is dropped (the engine would decay it at the first nearby cut).
--
-- Plain Lua 5.1, pure, no engine calls, deterministic (no pairs order reaches
-- the output, x * x instead of powers).

local M = {}

local MODULUS = 2147483647

-- a * b mod 2^31 - 1 for a, b below the modulus, exact in doubles: b is
-- split into 16-bit halves so no product exceeds 2^47.
local function mulmod(a, b)
	local high, low = math.floor(b / 65536), b % 65536
	return ((a * high) % MODULUS * 65536 + a * low) % MODULUS
end

local function powmod(base, exponent)
	local result = 1
	while exponent > 0 do
		if exponent % 2 == 1 then result = mulmod(result, base) end
		base = mulmod(base, base)
		exponent = math.floor(exponent / 2)
	end
	return result
end

-- Park-Miller minimal standard generator: every product stays below 2^46,
-- exact in a double. The start state is the species salt times 48271^(seed
-- + 1), so neighbouring seeds start at unrelated points of the sequence
-- instead of one linear offset (or one step) apart.
local function new_rng(seed, salt)
	local state = mulmod(salt * 104729 % (MODULUS - 1) + 1,
		powmod(48271, seed + 1))
	local rng = {}
	function rng.next()
		state = state * 16807 % MODULUS
		return state
	end
	function rng.int(low, high)
		return low + rng.next() % (high - low + 1)
	end
	function rng.float()
		return rng.next() / MODULUS
	end
	function rng.chance(p)
		return rng.next() / MODULUS < p
	end
	for _ = 1, 4 do rng.next() end
	return rng
end

local PRIORITY = {leaves = 1, fruit = 1, twig = 2, branch = 3, root = 4,
	corner = 5, trunk = 6}
local WOOD = {trunk = true, corner = true, branch = true, twig = true,
	root = true}
M.WOOD = WOOD

local function cell_key(x, y, z)
	return ((y + 64) * 256 + (z + 128)) * 256 + (x + 128)
end

local function new_tree(spec, seed)
	return {species = spec.id, seed = seed, bounds = spec.bounds, cells = {},
		outside = 0, params = {}}
end

local function put(tree, x, y, z, kind, param2)
	local b = tree.bounds
	if x < b.x1 or x > b.x2 or y < b.y1 or y > b.y2 or z < b.z1 or z > b.z2 then
		tree.outside = tree.outside + 1
		return
	end
	local key = cell_key(x, y, z)
	local old = tree.cells[key]
	if old and PRIORITY[old.kind] >= PRIORITY[kind] then return end
	tree.cells[key] = {x = x, y = y, z = z, kind = kind, param2 = param2 or 0}
end

local function get(tree, x, y, z)
	return tree.cells[cell_key(x, y, z)]
end

-- The cardinal directions, in a fixed order.
local CARDINAL = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}

-- A face-connected path from one cell to another: one axis step at a time,
-- always on the axis that is furthest behind its share of the way, so a
-- slanted limb becomes a staircase whose steps the connected boxes join.
local function path(x0, y0, z0, x1, y1, z1)
	local total = {math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)}
	local sign = {x1 >= x0 and 1 or -1, y1 >= y0 and 1 or -1,
		z1 >= z0 and 1 or -1}
	local done = {0, 0, 0}
	local at = {x0, y0, z0}
	local cells = {{x0, y0, z0}}
	local steps = total[1] + total[2] + total[3]
	-- ties: horizontal before vertical, so a limb leaves its trunk sideways
	local ORDER = {1, 3, 2}
	for _ = 1, steps do
		local best, best_share
		for _, axis in ipairs(ORDER) do
			if done[axis] < total[axis] then
				local share = (done[axis] + 0.5) / total[axis]
				if best == nil or share < best_share then
					best, best_share = axis, share
				end
			end
		end
		done[best] = done[best] + 1
		at[best] = at[best] + sign[best]
		cells[#cells + 1] = {at[1], at[2], at[3]}
	end
	return cells
end

-- A limb along a path: `thick` of its cells as branch, the rest as twig.
local function limb(tree, x0, y0, z0, x1, y1, z1, thick)
	local cells = path(x0, y0, z0, x1, y1, z1)
	local n = #cells
	for index = 1, n do
		local c = cells[index]
		local kind = (index - 1) / math.max(1, n - 1) <= thick and "branch" or "twig"
		put(tree, c[1], c[2], c[3], kind)
	end
	return cells
end

-- A leaf pad: an ellipsoid rx wide and ry high round (cx, cy, cz), with its
-- rim thinned by `holes` so no two pads have the same outline.
local function pad(tree, rng, cx, cy, cz, rx, ry, tint, holes)
	local ex, ey = (rx + 0.5) * (rx + 0.5), (ry + 0.5) * (ry + 0.5)
	for dy = -ry, ry do
		for dz = -rx, rx do
			for dx = -rx, rx do
				local d = (dx * dx + dz * dz) / ex + dy * dy / ey
				if d <= 1 then
					local keep = true
					if d > 0.55 then keep = not rng.chance(holes) end
					if keep then
						put(tree, cx + dx, cy + dy, cz + dz, "leaves", tint * 32)
					end
				end
			end
		end
	end
end

-- Twigs inside a pad, so its leaves stay within the decay radius of wood:
-- `count` runs from the centre, each `reach` long, in different directions.
local function fingers(tree, rng, cx, cy, cz, reach, count)
	if reach < 1 then return end
	local first = rng.int(0, 3)
	for index = 0, count - 1 do
		local d = CARDINAL[(first + index) % 4 + 1]
		limb(tree, cx, cy, cz, cx + d[1] * reach, cy, cz + d[2] * reach, 0)
	end
end

-- A buttress fin leaving the trunk at (x, z) in direction d: `length` cells,
-- `height` nodes high at the trunk, falling to one node at its tip.
local function fin(tree, x, z, d, length, height)
	for step = 1, length do
		local h = height
		if length > 1 then
			h = math.floor(height - (height - 1) * (step - 1) / (length - 1) + 0.5)
		end
		for y = 1, h do
			put(tree, x + d[1] * (step - 1), y, z + d[2] * (step - 1), "root")
		end
	end
end

-- A round trunk section: size 1 is a log column, size 2 four corner pieces,
-- size 3 logs with corner pieces on the four corners. `x0`, `z0` is its
-- lowest x and z.
local function trunk_section(tree, size, x0, z0, y1, y2)
	for y = y1, y2 do
		for dz = 0, size - 1 do
			for dx = 0, size - 1 do
				local edge_x = (dx == 0 or dx == size - 1)
				local edge_z = (dz == 0 or dz == size - 1)
				if size >= 2 and edge_x and edge_z then
					-- the trunk's axis lies inward
					local sx = dx == 0 and 1 or -1
					local sz = dz == 0 and 1 or -1
					put(tree, x0 + dx, y, z0 + dz, "corner",
						M.corner_param2(sx, sz))
				else
					put(tree, x0 + dx, y, z0 + dz, "trunk")
				end
			end
		end
	end
end

-- Sixteen compass directions as literal unit vectors (no trigonometry, so
-- the result cannot differ between interpreters).
local DIR16 = {
	{1, 0}, {0.9239, 0.3827}, {0.7071, 0.7071}, {0.3827, 0.9239},
	{0, 1}, {-0.3827, 0.9239}, {-0.7071, 0.7071}, {-0.9239, 0.3827},
	{-1, 0}, {-0.9239, -0.3827}, {-0.7071, -0.7071}, {-0.3827, -0.9239},
	{0, -1}, {0.3827, -0.9239}, {0.7071, -0.7071}, {0.9239, -0.3827},
}

-- `count` directions spread round the tree from a random start, each nudged
-- by up to one step, so limbs never bunch and never sit on a perfect star.
local function spread(rng, count)
	local base = rng.int(0, 15)
	local result = {}
	for index = 1, count do
		local step = math.floor((index - 1) * 16 / count + 0.5)
		result[index] = DIR16[(base + step + rng.int(-1, 1)) % 16 + 1]
	end
	return result
end

local function round(v)
	return math.floor(v + 0.5)
end

-- Removes leaves and fruit with no wood within `radius` (a cube, like
-- default's leaf decay find_node_near) and returns how many went.
local function prune(tree, radius)
	local removed = 0
	local doomed = {}
	for key, cell in pairs(tree.cells) do
		if not WOOD[cell.kind] then
			local found = false
			for dy = -radius, radius do
				for dz = -radius, radius do
					for dx = -radius, radius do
						local other = get(tree, cell.x + dx, cell.y + dy, cell.z + dz)
						if other and WOOD[other.kind] then found = true break end
					end
					if found then break end
				end
				if found then break end
			end
			if not found then doomed[#doomed + 1] = key end
		end
	end
	for index = 1, #doomed do
		tree.cells[doomed[index]] = nil
		removed = removed + 1
	end
	return removed
end

--
-- SPECIES
--

M.SPECIES = {}

-- The troll jungle tree: lower and lighter than the 5 x 17 x 5 schematic. A
-- slim log trunk 6..9 high, sometimes kinked once, flared by two to four
-- small fins; at the top it forks into two to four limbs that reach out and
-- up and carry flat, lopsided leaf pads at different heights; one or two
-- short spurs with a tuft lower down keep the jungle tree's side shoots.
M.SPECIES.jungle = {
	id = "jungle", wood = "jungle", decay_radius = 2,
	bounds = {x1 = -6, x2 = 6, y1 = 1, y2 = 15, z1 = -6, z2 = 6},
	build = function(tree, rng)
		local p = tree.params
		p.trunk_h = rng.int(6, 9)
		local x, z = 0, 0
		p.lean = rng.chance(0.6) and rng.int(3, p.trunk_h - 2) or 0
		local lean_dir = CARDINAL[rng.int(1, 4)]
		for y = 1, p.trunk_h do
			put(tree, x, y, z, "trunk")
			if y == p.lean then
				x, z = x + lean_dir[1], z + lean_dir[2]
				put(tree, x, y, z, "trunk")
			end
		end
		local reach_room = 6 - math.max(math.abs(x), math.abs(z))
		-- the flare
		p.roots = rng.int(2, 4)
		local first = rng.int(0, 3)
		for index = 0, p.roots - 1 do
			local d = CARDINAL[(first + index) % 4 + 1]
			fin(tree, d[1], d[2], d, rng.chance(0.5) and 2 or 1, rng.int(1, 2))
		end
		-- the fork
		p.limbs = rng.int(2, 4)
		p.pads = {}
		local dirs = spread(rng, p.limbs)
		for index = 1, p.limbs do
			local radius = rng.int(2, 3)
			local reach = math.min(rng.int(2, 4), reach_room - radius)
			local rise = rng.int(1, 3)
			local start = p.trunk_h - rng.int(0, 1)
			local ex = x + round(dirs[index][1] * reach)
			local ez = z + round(dirs[index][2] * reach)
			local ey = start + rise
			limb(tree, x, start, z, ex, ey, ez, 0.5)
			local tint = rng.int(0, 3)
			pad(tree, rng, ex, ey + 1, ez, radius, 1, tint, 0.35)
			fingers(tree, rng, ex, ey, ez, radius - 1, 2)
			p.pads[#p.pads + 1] = radius
		end
		-- a small top tuft over the fork, so the crown has no bald centre
		pad(tree, rng, x, p.trunk_h + 2, z, 1, 0, rng.int(0, 3), 0.2)
		put(tree, x, p.trunk_h + 1, z, "branch")
		-- spurs
		p.spurs = rng.int(1, 2)
		for _ = 1, p.spurs do
			local y = rng.int(3, math.max(3, p.trunk_h - 3))
			local d = CARDINAL[rng.int(1, 4)]
			local cx = (y > p.lean and p.lean > 0) and x or 0
			local cz = (y > p.lean and p.lean > 0) and z or 0
			local length = rng.int(1, 2)
			limb(tree, cx, y, cz, cx + d[1] * length, y + 1, cz + d[2] * length, 0)
			pad(tree, rng, cx + d[1] * length, y + 1, cz + d[2] * length, 1, 0,
				rng.int(0, 3), 0.3)
		end
	end,
}

-- The giant kapok: a landmark. A round trunk, 3 x 3 at the foot then 2 x 2,
-- or 2 x 2 throughout, ends in a log leader; four to six buttress fins run
-- out from the foot; near the top four to six thick limbs reach out almost
-- level and carry flat pads that join into a wide, uneven umbrella: up to 15
-- nodes across and 19 to 24 high (today's schematic: 7 across, 33 above the
-- ground).
M.SPECIES.kapok = {
	id = "kapok", wood = "jungle", decay_radius = 2,
	bounds = {x1 = -7, x2 = 8, y1 = 1, y2 = 28, z1 = -7, z2 = 8},
	build = function(tree, rng)
		local p = tree.params
		p.size = rng.chance(0.5) and 3 or 2
		p.trunk_h = rng.int(16, 20)
		local base = p.size == 3 and -1 or 0
		local top3 = 0
		if p.size == 3 then
			top3 = round(p.trunk_h * (0.3 + 0.15 * rng.float()))
			trunk_section(tree, 3, -1, -1, 1, top3)
		end
		local top2 = p.trunk_h - rng.int(2, 4)
		-- the 2 x 2 stands off-centre on the 3 x 3: the trunk leans a little
		local x2, z2 = 0, 0
		if p.size == 3 then x2, z2 = rng.int(-1, 0), rng.int(-1, 0) end
		trunk_section(tree, 2, x2, z2, top3 + 1, top2)
		-- the leader stands on one of the four quarters
		local lx, lz = x2 + rng.int(0, 1), z2 + rng.int(0, 1)
		trunk_section(tree, 1, lx, lz, top2 + 1, p.trunk_h)
		p.top3, p.top2 = top3, top2
		-- buttress fins
		local lo, hi = base, base + p.size - 1
		local candidates = {}
		for _, d in ipairs(CARDINAL) do
			for offset = lo, hi do
				local fx, fz
				if d[1] ~= 0 then
					fx = d[1] > 0 and hi + 1 or lo - 1
					fz = offset
				else
					fx = offset
					fz = d[2] > 0 and hi + 1 or lo - 1
				end
				candidates[#candidates + 1] = {d = d, x = fx, z = fz, offset = offset}
			end
		end
		-- a seeded shuffle, then one fin per side first
		for index = #candidates, 2, -1 do
			local other = rng.int(1, index)
			candidates[index], candidates[other] = candidates[other], candidates[index]
		end
		p.roots = rng.int(4, 6)
		local placed, per_side = {}, {}
		for pass = 1, 2 do
			for _, c in ipairs(candidates) do
				if #placed >= p.roots then break end
				local side = c.d[1] * 3 + c.d[2]
				local ok = true
				if pass == 1 and per_side[side] then ok = false end
				for _, other in ipairs(placed) do
					if other.d == c.d and math.abs(other.offset - c.offset) < 2 then
						ok = false
					end
				end
				if ok then
					placed[#placed + 1] = c
					per_side[side] = true
					local length = p.size == 3 and rng.int(3, 5) or rng.int(2, 4)
					fin(tree, c.x, c.z, c.d, length, rng.int(3, 5))
				end
			end
		end
		-- the limbs and their pads
		p.limbs = rng.int(4, 6)
		p.pads = {}
		local dirs = spread(rng, p.limbs)
		local cx, cz = lx, lz
		for index = 1, p.limbs do
			local radius = rng.int(2, 3)
			local reach = math.min(rng.int(4, 6), 6 - radius)
			local start = p.trunk_h - rng.int(0, 5)
			local rise = rng.int(1, 2)
			local ex = cx + round(dirs[index][1] * reach)
			local ez = cz + round(dirs[index][2] * reach)
			local ey = start + rise
			limb(tree, cx, start, cz, ex, ey, ez, 0.6)
			pad(tree, rng, ex, ey + 1, ez, radius, 1, rng.int(0, 3), 0.3)
			fingers(tree, rng, ex, ey, ez, radius - 1, 3)
			p.pads[#p.pads + 1] = radius
		end
		-- the crown over the leader
		p.top_pad = rng.int(3, 4)
		put(tree, cx, p.trunk_h + 1, cz, "branch")
		pad(tree, rng, cx, p.trunk_h + 2, cz, p.top_pad, 1, rng.int(0, 3), 0.25)
		fingers(tree, rng, cx, p.trunk_h + 1, cz, p.top_pad - 1, 4)
		-- one or two low limbs with a small pad, where the schematic of today
		-- carries its leaf collars
		p.low_limbs = rng.int(0, 2)
		for _ = 1, p.low_limbs do
			local y = rng.int(math.max(top2 - 3, 6), top2)
			local d = CARDINAL[rng.int(1, 4)]
			local sx = d[1] > 0 and x2 + 2 or (d[1] < 0 and x2 - 1 or x2 + rng.int(0, 1))
			local sz = d[2] > 0 and z2 + 2 or (d[2] < 0 and z2 - 1 or z2 + rng.int(0, 1))
			local length = rng.int(2, 3)
			local ex, ez = sx + d[1] * length, sz + d[2] * length
			limb(tree, sx, y, sz, ex, y + 1, ez, 0.5)
			pad(tree, rng, ex, y + 2, ez, 2, 0, rng.int(0, 3), 0.3)
			fingers(tree, rng, ex, y + 1, ez, 1, 2)
		end
	end,
}

-- The broadleaf (apple, the meadow tree): a short log trunk forking at 3..5
-- into two to four limbs that rise and spread, each ending in a round crown
-- cluster, with a cluster over the fork; one in four is an old tree on a
-- round 2 x 2 trunk with a small flare. Apples hang under the crown.
M.SPECIES.apple = {
	id = "apple", wood = "oak", decay_radius = 3,
	bounds = {x1 = -6, x2 = 7, y1 = 1, y2 = 13, z1 = -6, z2 = 7},
	build = function(tree, rng)
		local p = tree.params
		p.size = rng.chance(0.25) and 2 or 1
		p.trunk_h = p.size == 2 and rng.int(3, 5) or rng.int(3, 4)
		trunk_section(tree, p.size, 0, 0, 1, p.trunk_h)
		local cx, cz = 0, 0
		if p.size == 2 then
			cx, cz = rng.int(0, 1), rng.int(0, 1)
			put(tree, cx, p.trunk_h + 1, cz, "trunk")
			p.roots = rng.int(2, 4)
			local first = rng.int(0, 3)
			for index = 0, p.roots - 1 do
				local d = CARDINAL[(first + index) % 4 + 1]
				local fx = d[1] > 0 and 2 or (d[1] < 0 and -1 or rng.int(0, 1))
				local fz = d[2] > 0 and 2 or (d[2] < 0 and -1 or rng.int(0, 1))
				fin(tree, fx, fz, d, rng.int(1, 2), 2)
			end
		else
			p.roots = rng.int(0, 2)
			local first = rng.int(0, 3)
			for index = 0, p.roots - 1 do
				local d = CARDINAL[(first + index) % 4 + 1]
				fin(tree, d[1], d[2], d, 1, 1)
			end
		end
		local fork = p.trunk_h + (p.size == 2 and 1 or 0)
		p.limbs = p.size == 2 and rng.int(3, 4) or rng.int(2, 3)
		p.clusters = {}
		local dirs = spread(rng, p.limbs)
		local tint = rng.int(0, 3)
		for index = 1, p.limbs do
			local radius = p.size == 2 and rng.int(2, 3) or 2
			local reach = math.min(rng.int(1, 3), 6 - radius)
			local rise = rng.int(2, 3)
			local ex = cx + round(dirs[index][1] * reach)
			local ez = cz + round(dirs[index][2] * reach)
			local ey = fork + rise
			limb(tree, cx, fork, cz, ex, ey, ez, 0.7)
			put(tree, ex, ey + 1, ez, "twig")
			pad(tree, rng, ex, ey + 1, ez, radius, 2,
				rng.chance(0.7) and tint or (tint + 1) % 4, 0.3)
			p.clusters[#p.clusters + 1] = radius
		end
		local crown = p.size == 2 and 3 or rng.int(2, 3)
		put(tree, cx, fork + 1, cz, "branch")
		put(tree, cx, fork + 2, cz, "twig")
		pad(tree, rng, cx, fork + 3, cz, crown, 2, tint, 0.3)
		p.crown = crown
	end,
	-- apples on the underside of the crown
	finish = function(tree, rng)
		local keys = {}
		for key, cell in pairs(tree.cells) do
			if cell.kind == "leaves" then keys[#keys + 1] = key end
		end
		table.sort(keys)
		local fruit = 0
		for _, key in ipairs(keys) do
			local cell = tree.cells[key]
			if not get(tree, cell.x, cell.y - 1, cell.z) and rng.chance(0.08) then
				tree.cells[key] = {x = cell.x, y = cell.y, z = cell.z, kind = "fruit",
					param2 = 0}
				fruit = fruit + 1
			end
		end
		tree.params.fruit = fruit
	end,
}

M.SPECIES_ORDER = {"jungle", "kapok", "apple"}
local SALT = {jungle = 11, kapok = 23, apple = 37}

-- The corner param2 rule lives with the shapes; the generator only needs it.
function M.set_corner_rule(fn)
	M.corner_param2 = fn
end

-- One tree. `seed` is an integer 0 .. 2^31 - 1.
function M.build(species_id, seed)
	local spec = M.SPECIES[species_id]
	assert(spec, "unknown tree species " .. tostring(species_id))
	assert(type(seed) == "number" and seed % 1 == 0 and seed >= 0 and
		seed < 2147483648, "tree seed must be an integer 0 .. 2^31 - 1")
	assert(M.corner_param2, "generator needs the corner param2 rule")
	local rng = new_rng(seed, SALT[species_id])
	local tree = new_tree(spec, seed)
	spec.build(tree, rng)
	tree.pruned = prune(tree, spec.decay_radius)
	if spec.finish then spec.finish(tree, rng) end
	-- the sorted cell list: y, then z, then x
	local keys = {}
	for key in pairs(tree.cells) do keys[#keys + 1] = key end
	table.sort(keys)
	local list, counts = {}, {}
	for index = 1, #keys do
		local cell = tree.cells[keys[index]]
		list[index] = cell
		counts[cell.kind] = (counts[cell.kind] or 0) + 1
	end
	tree.list, tree.counts = list, counts
	tree.wood = spec.wood
	tree.decay_radius = spec.decay_radius
	return tree
end

-- A Luanti schematic table for one tree: size = the species' bounding box,
-- air cells with probability 0 so placement keeps what stands there, and
-- the root at `offset` (add it to the placement position to put the ground
-- node under the trunk). `names` maps a cell kind to a node name.
function M.to_schematic(tree, names)
	local b = tree.bounds
	local sx, sy, sz = b.x2 - b.x1 + 1, b.y2 - b.y1 + 1, b.z2 - b.z1 + 1
	local data = {}
	for index = 1, sx * sy * sz do data[index] = {name = "air", prob = 0} end
	for _, cell in ipairs(tree.list) do
		local index = ((cell.z - b.z1) * sy + (cell.y - b.y1)) * sx +
			(cell.x - b.x1) + 1
		data[index] = {name = names[cell.kind], prob = 254,
			param2 = cell.param2, force_place = false}
	end
	return {size = {x = sx, y = sy, z = sz}, data = data},
		{x = b.x1, y = b.y1, z = b.z1}
end

return M
