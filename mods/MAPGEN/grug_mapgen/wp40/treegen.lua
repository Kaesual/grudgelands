-- Round 47 lane TB: the seeded tree generator, a 1:1 Lua port of
-- tools/r46_tree/concept/treegen.js (the approved concept; DESIGN.md next to
-- it holds the growth concept per species and "Porting to Lua").
--
-- Pure Lua 5.1 / LuaJIT, no engine calls and no globals: the main and the
-- mapgen environment both `dofile` it and get the API table.
--
-- generate(species, seed, is_ground) returns one tree as data, the same as
-- the JS: `nodes`, a list sorted by position of {x, y, z, kind, rot}, and
-- `roots`, the {x, y, z} of the root cells among them (in the order they
-- were placed), plus count / wood / shapes / height / width / depth / min /
-- max / facts for the viewer. y = 0 is the first node above the ground; the
-- trunk axis stands at x = 0, z = 0 (a 1 x 1 or 3 x 3 trunk is centred on
-- cell 0, a 2 x 2 trunk on the corner between cells -1 and 0). Kinds (names
-- as data, mapped to node names by the caller): trunk (the plain log cube),
-- quarter (the faceted trunk piece), base (the limb base), branch, twig
-- (connected node boxes), leaves, fruit. `rot` is the facedir param2: for a
-- quarter the corner it rounds (0..3), for trunk / base / branch / twig the
-- axis its bark grain runs along (0 = y, 4 = z, 12 = x); leaves and fruit 0.
-- is_ground(x, y, z) in tree coordinates says whether that cell is ground
-- (the foot stands on y = -1); nil means flat ground (y < 0). Only roots ask
-- it, after all their random numbers are drawn, so the rest of the tree is
-- the same on any ground.
--
-- Seeds: the start state is salt x 48271^(seed + 1) mod 2^31 - 1 and 48271
-- is a primitive root of that prime, so the exponent has period 2^31 - 2.
-- The integer seeds -1 .. 2147483644 give 2147483646 different start
-- states; seed s and s + 2147483646 give the same tree (2147483645 the tree
-- of -1, 2147483646 that of 0); every seed below -1 gives the tree of -1
-- (the power loop never runs). Seeds are integers: a fraction is not
-- rejected but makes no sense, +inf never returns, NaN gives the tree of -1.
-- Up to 2^53 every integer is exact; above it seed + 1 rounds like the JS.
--
-- The port keeps the JS line by line: integer arithmetic on doubles below
-- 2^53 (idiv = floor of the quotient), every `%` has a non-negative left
-- operand (JS and Lua agree there), cells in an explicit insertion list, the
-- result sorted by a unique integer key. JS arrays are 0-based: indices are
-- shifted by one here (axes stay 0..2 and index arrays as [axis + 1]).

local floor = math.floor
local insert = table.insert
local remove = table.remove
local sort = table.sort

local MODULUS = 2147483647

local function idiv(a, b) return floor(a / b) end
local function iabs(a) if a < 0 then return -a end return a end
local function imin(a, b) if a < b then return a end return b end
local function imax(a, b) if a > b then return a end return b end

-- ---------------------------------------------------------------- random

-- a * b mod 2^31 - 1 with every product below 2^47.
local function mulmod(a, b)
	local high, low = idiv(b, 65536), b % 65536
	return ((a * high) % MODULUS * 65536 + a * low) % MODULUS
end

local function powmod(base, exponent)
	local result = 1
	while exponent > 0 do
		if exponent % 2 == 1 then result = mulmod(result, base) end
		base = mulmod(base, base)
		exponent = idiv(exponent, 2)
	end
	return result
end

local function rng_next(rng)
	rng.state = (rng.state * 16807) % MODULUS
	return rng.state
end

-- Park-Miller minimal standard generator (16807). The start state is the
-- species salt times 48271^(seed + 1), so neighbouring seeds start at
-- unrelated points of the sequence.
local function new_rng(seed, salt)
	local rng = {state = mulmod((salt * 104729) % (MODULUS - 1) + 1,
		powmod(48271, seed + 1))}
	for _ = 1, 4 do rng_next(rng) end
	return rng
end

-- An integer in [low, high], both ends included.
local function rint(rng, low, high)
	return low + rng_next(rng) % (high - low + 1)
end

-- True with `percent` in 100.
local function chance(rng, percent)
	return rng_next(rng) % 100 < percent
end

-- A position hash in [0, 99] for leaf-edge roughness: the same cell gives
-- the same answer for every cluster that covers it.
local function hash100(salt, x, y, z)
	local h = ((x + 1000) * 7919 + (y + 1000) * 104729 + (z + 1000) * 1299709 +
		salt * 15485863) % MODULUS
	h = (h * 48271) % MODULUS
	h = (h * 48271) % MODULUS
	return h % 100
end

-- ----------------------------------------------------------- directions

-- Sixteen compass directions as integer (dx, dz) of length ~16: k * 22.5
-- degrees from +x towards +z.
local DIR16 = {
	{16, 0}, {15, 6}, {11, 11}, {6, 15}, {0, 16}, {-6, 15}, {-11, 11}, {-15, 6},
	{-16, 0}, {-15, -6}, {-11, -11}, {-6, -15}, {0, -16}, {6, -15}, {11, -11}, {15, -6},
}

local function dir_x(k) return DIR16[((k % 16) + 16) % 16 + 1][1] end
local function dir_z(k) return DIR16[((k % 16) + 16) % 16 + 1][2] end

-- A point `d16` sixteenths from (x16, z16) along direction k.
local function off_x(x16, k, d16) return x16 + idiv(dir_x(k) * d16, 16) end
local function off_z(z16, k, d16) return z16 + idiv(dir_z(k) * d16, 16) end

-- The cell holding a p16 coordinate, and the centre of a cell in p16.
local function cell_of(v16) return idiv(v16, 16) end
local function mid(c) return c * 16 + 8 end

-- The cardinal step (dx, dz) of direction index 0..3 (DIR16 index 4 d),
-- read as CARD[d + 1].
local CARD = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}

-- ---------------------------------------------------------------- cells

local RANK = {leaves = 1, fruit = 2, twig = 3, branch = 4, base = 5, trunk = 6, quarter = 6}
local WOOD = {trunk = true, quarter = true, base = true, branch = true, twig = true}

local function key(x, y, z) return ((y + 64) * 256 + (x + 128)) * 256 + (z + 128) end

local function new_tree(species, seed, is_ground)
	return {species = species, seed = seed, cells = {}, order = {}, stem_list = {}, stem_set = {},
		clusters = {}, path = {}, facts = {}, roots = {}, is_ground = is_ground}
end

-- The flat ground of the viewer: everything below the tree's foot.
local function flat_ground(_, y, _) return y < 0 end

local function get_cell(t, x, y, z) return t.cells[key(x, y, z)] end

local function is_wood(t, x, y, z)
	local c = t.cells[key(x, y, z)]
	return c ~= nil and WOOD[c.kind] == true
end

local function put_cell(t, x, y, z, kind, rot)
	local k = key(x, y, z)
	local c = t.cells[k]
	if c == nil then
		t.cells[k] = {x = x, y = y, z = z, kind = kind, rot = rot}
		t.order[#t.order + 1] = k
		return
	end
	-- JS compares with undefined (false) for a dropped ('gone') cell
	local rank = RANK[c.kind]
	if rank ~= nil and RANK[kind] > rank then c.kind = kind; c.rot = rot end
end

-- A cell of the stem itself (trunk layers, leader): limbs look for
-- their starting cell among these.
local function stem_cell(t, x, y, z, kind, rot)
	local k = key(x, y, z)
	local known = t.cells[k] ~= nil
	put_cell(t, x, y, z, kind, rot)
	if not known then t.stem_list[#t.stem_list + 1] = k; t.stem_set[k] = true end
end

-- facedir of a quarter piece whose inner corner (the trunk axis) lies
-- towards (sx, sz), each -1 or 1 (shapes: inner corner +x +z at 0).
local function quarter_rot(sx, sz)
	if sx > 0 then if sz > 0 then return 0 end return 1 end
	if sz < 0 then return 2 end
	return 3
end

-- ---------------------------------------------------------------- trunk

-- One trunk layer of width w around the axis (ax2, az2) given in half
-- nodes: cell c has its centre at 2c + 1. Odd widths have an odd axis.
local function trunk_layer(t, y, ax2, az2, w)
	local x0, z0 = idiv(ax2 - w, 2), idiv(az2 - w, 2)
	for i = 0, w - 1 do
		for j = 0, w - 1 do
			local x, z = x0 + i, z0 + j
			local edge_x, edge_z = (i == 0 or i == w - 1), (j == 0 or j == w - 1)
			if w >= 2 and edge_x and edge_z then
				stem_cell(t, x, y, z, "quarter",
					quarter_rot(i == 0 and 1 or -1, j == 0 and 1 or -1))
			else
				stem_cell(t, x, y, z, "trunk", 0)
			end
		end
	end
end

-- A 1 x 1 trunk column from (x, y0, z) up to y1 inclusive.
local function column(t, x, y0, y1, z, kind)
	for y = y0, y1 do stem_cell(t, x, y, z, kind, 0) end
end

-- ----------------------------------------------------------------- limbs

-- Kind of step `i` (1-based) of an n-step limb whose first `cubes` steps
-- are logs and whose first `thick` percent are branch, the rest twig.
local function step_kind(i, n, cubes, thick)
	if i <= cubes then return "trunk" end
	if i * 100 <= n * thick then return "branch" end
	return "twig"
end

local AXIS_ROT = {12, 0, 4}  -- grain along x, y, z (axis 0, 1, 2)

local NEIGHBOURS = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}

-- May a limb step into (x, y, z) coming from (px, py, pz)? Yes when the
-- cell is already wood (limbs merge) or none of its other face
-- neighbours is wood.
local function clean_step(t, x, y, z, px, py, pz)
	if is_wood(t, x, y, z) then return true end
	for i = 1, 6 do
		local nb = NEIGHBOURS[i]
		local nx, ny, nz = x + nb[1], y + nb[2], z + nb[3]
		if not (nx == px and ny == py and nz == pz) and is_wood(t, nx, ny, nz) then
			return false
		end
	end
	return true
end

-- Grow a limb from the wood cell (x, y, z) to the cell (tx, ty, tz) as a
-- staircase of face-connected cells. With `prefer` OUT_FIRST the first
-- step is level (the limb leaves its parent sideways). Each step advances
-- the axis that lags most behind the straight line (integer cross-
-- multiplication), so the staircase follows the line; on a tie the order in
-- `prefer` wins (0 = x, 1 = y, 2 = z). A step that would touch other wood
-- sideways (and so fuse into a ladder, connected boxes join every face
-- neighbour) takes another lagging axis instead when one is free. Returns
-- the end cell {x, y, z}; t.path keeps the cells of the last limb.
local function limb(t, x, y, z, tx, ty, tz, cubes, thick, prefer)
	if ty < 1 then ty = imin(1, y) end        -- never into the ground
	local d = {tx - x, ty - y, tz - z}
	local a = {iabs(d[1]), iabs(d[2]), iabs(d[3])}
	local s = {d[1] < 0 and -1 or 1, d[2] < 0 and -1 or 1, d[3] < 0 and -1 or 1}
	local m = {0, 0, 0}
	local n = a[1] + a[2] + a[3]
	local p = {x, y, z}
	t.path = {}
	for i = 1, n do
		-- candidate axes, most lagging first
		local cand = {}
		for q = 1, 3 do
			local ax = prefer[q]
			-- a limb leaving its parent sideways takes a level first step
			local level = i == 1 and prefer[1] ~= 1 and (m[1] < a[1] or m[3] < a[3])
			if m[ax + 1] < a[ax + 1] and not (level and ax == 1) then
				local at = #cand
				while at > 0 do
					local other = cand[at]
					-- is ax more behind than other? (2m+1)/a smaller
					if (2 * m[ax + 1] + 1) * a[other + 1] < (2 * m[other + 1] + 1) * a[ax + 1] then
						at = at - 1
					else
						break
					end
				end
				insert(cand, at + 1, ax)
			end
		end
		local pick = cand[1]
		for c = 1, #cand do
			local axc = cand[c]
			local np = {p[1], p[2], p[3]}
			np[axc + 1] = np[axc + 1] + s[axc + 1]
			if clean_step(t, np[1], np[2], np[3], p[1], p[2], p[3]) then
				pick = axc
				break
			end
		end
		p[pick + 1] = p[pick + 1] + s[pick + 1]
		m[pick + 1] = m[pick + 1] + 1
		put_cell(t, p[1], p[2], p[3], step_kind(i, n, cubes, thick), AXIS_ROT[pick + 1])
		t.path[#t.path + 1] = {p[1], p[2], p[3]}
	end
	return p
end

local OUT_FIRST = {0, 2, 1}   -- leave sideways, then rise
local UP_FIRST = {1, 0, 2}

-- --------------------------------------------------------------- leaves

-- A leaf cluster: an ellipsoid centred at (x16, y16, z16) with radii in
-- sixteenths. `floor_y` (in nodes, relative to the centre cell) cuts it off
-- below, for flat-bottomed pads; -99 keeps the whole ellipsoid.
local function cluster(t, x16, y16, z16, rx, ry, rz, floor_y)
	t.clusters[#t.clusters + 1] = {x = x16, y = y16, z = z16, rx = rx, ry = ry, rz = rz, floor = floor_y}
end

-- Leaves farther than `reach` (in the engine's cube search) from every
-- wood cell would decay: drop them. A leaf with no leaf or wood face
-- neighbour floats: drop it too.
local function prune_leaves(t, reach)
	local dist = {}
	local frontier = {}
	for i = 1, #t.order do
		local c = t.cells[t.order[i]]
		if WOOD[c.kind] == true then
			dist[t.order[i]] = 0
			frontier[#frontier + 1] = c
		end
	end
	for step = 1, reach do
		local next_list = {}
		for f = 1, #frontier do
			local fc = frontier[f]
			for dx = -1, 1 do
				for dy = -1, 1 do
					for dz = -1, 1 do
						local nk = key(fc.x + dx, fc.y + dy, fc.z + dz)
						if dist[nk] == nil then
							dist[nk] = step
							next_list[#next_list + 1] = {x = fc.x + dx, y = fc.y + dy, z = fc.z + dz}
						end
					end
				end
			end
		end
		frontier = next_list
	end
	for j = 1, #t.order do
		local lc = t.cells[t.order[j]]
		if lc.kind == "leaves" and dist[t.order[j]] == nil then
			lc.kind = "gone"
		end
	end
	for j2 = 1, #t.order do
		local c2 = t.cells[t.order[j2]]
		if c2.kind == "leaves" then
			local held = false
			for n = 1, 6 do
				local nbd = NEIGHBOURS[n]
				local nb = get_cell(t, c2.x + nbd[1], c2.y + nbd[2], c2.z + nbd[3])
				if nb ~= nil and nb.kind ~= "gone" then held = true end
			end
			if not held then c2.kind = "gone" end
		end
	end
end

-- Fill the clusters: a cell is leaves when its centre lies inside one;
-- cells in the outer band of every cluster covering them (depth above
-- `edge` percent) are dropped where the position hash is below `rough`.
-- Then drop leaves out of the leaf decay reach of wood, and loose ones.
local function fill_leaves(t, edge, rough, salt, reach)
	local depth = {}
	local list = {}
	for ci = 1, #t.clusters do
		local k = t.clusters[ci]
		local rx2, ry2, rz2 = k.rx * k.rx, k.ry * k.ry, k.rz * k.rz
		local whole = rx2 * ry2 * rz2
		local cx, cy, cz = cell_of(k.x), cell_of(k.y), cell_of(k.z)
		local ex, ey, ez = idiv(k.rx, 16) + 1, idiv(k.ry, 16) + 1, idiv(k.rz, 16) + 1
		for y = cy - ey, cy + ey do
			if y - cy >= k.floor and y >= 0 then
				for x = cx - ex, cx + ex do
					for z = cz - ez, cz + ez do
						local dx, dy, dz = mid(x) - k.x, mid(y) - k.y, mid(z) - k.z
						local v = dx * dx * ry2 * rz2 + dy * dy * rx2 * rz2 + dz * dz * rx2 * ry2
						if v <= whole and x >= -8 and x <= 7 and z >= -8 and z <= 7 then
							local q = idiv(v * 100, whole)
							local kk = key(x, y, z)
							if depth[kk] == nil then
								depth[kk] = q
								list[#list + 1] = kk
							elseif q < depth[kk] then
								depth[kk] = q
							end
						end
					end
				end
			end
		end
	end
	for li = 1, #list do
		local kk2 = list[li]
		local y2 = idiv(kk2, 65536) - 64
		local x2 = idiv(kk2 % 65536, 256) - 128
		local z2 = (kk2 % 256) - 128
		if depth[kk2] <= edge or hash100(salt, x2, y2, z2) >= rough then
			if get_cell(t, x2, y2, z2) == nil then
				put_cell(t, x2, y2, z2, "leaves", 0)
			end
		end
	end
	prune_leaves(t, reach)
end

-- Hang `count` fruit on the crown: leaves with open air below, picked
-- in key order by the generator.
local function hang_fruit(t, rng, count)
	local cand = {}
	for i = 1, #t.order do
		local c = t.cells[t.order[i]]
		if c.kind == "leaves" then
			local below = get_cell(t, c.x, c.y - 1, c.z)
			if below == nil or below.kind == "gone" then cand[#cand + 1] = t.order[i] end
		end
	end
	sort(cand)
	local n = 0
	while n < count and #cand > 0 do
		local at = rint(rng, 0, #cand - 1)
		t.cells[cand[at + 1]].kind = "fruit"
		remove(cand, at + 1)
		n = n + 1
	end
end

-- ---------------------------------------------------------------- finish

-- Limb bases: where a limb leaves the trunk sideways, its first cell is
-- the thicker base piece, whose level arms reach half a node into the
-- trunk cell and so close the gap to a slanted trunk face. A branch or a
-- lying log beside a stem log or quarter becomes a base; so does a twig
-- beside a quarter (it would leave a gap); a twig beside a log meets its
-- flat face and stays.
local function limb_bases(t)
	local turn = {}
	for i = 1, #t.order do
		local k = t.order[i]
		local c = t.cells[k]
		if t.stem_set[k] ~= true and (c.kind == "branch" or c.kind == "twig" or c.kind == "trunk") then
			for n = 1, 6 do
				local d = NEIGHBOURS[n]
				local nk = key(c.x + d[1], c.y, c.z + d[3])
				local nb = t.cells[nk]
				if d[2] == 0 and nb ~= nil and t.stem_set[nk] == true and
						(nb.kind == "quarter" or (nb.kind == "trunk" and c.kind ~= "twig")) then
					turn[#turn + 1] = c
					break
				end
			end
		end
	end
	for j = 1, #turn do turn[j].kind = "base" end
end

local function finish(t)
	local keyed = {}
	local count = {trunk = 0, quarter = 0, base = 0, branch = 0, twig = 0, leaves = 0, fruit = 0}
	local min_x, max_x, min_z, max_z, max_y = 999, -999, 999, -999, -999
	for i = 1, #t.order do
		local c = t.cells[t.order[i]]
		if c.kind ~= "gone" then
			keyed[#keyed + 1] = {k = t.order[i], x = c.x, y = c.y, z = c.z, kind = c.kind, rot = c.rot}
			count[c.kind] = count[c.kind] + 1
			min_x = imin(min_x, c.x); max_x = imax(max_x, c.x)
			min_z = imin(min_z, c.z); max_z = imax(max_z, c.z)
			max_y = imax(max_y, c.y)
		end
	end
	sort(keyed, function(a, b) return a.k < b.k end)
	local nodes = {}
	for j = 1, #keyed do
		local nd = keyed[j]
		nodes[j] = {x = nd.x, y = nd.y, z = nd.z, kind = nd.kind, rot = nd.rot}
	end
	return {
		species = t.species, seed = t.seed, nodes = nodes, count = count,
		wood = count.trunk + count.quarter + count.base + count.branch + count.twig,
		shapes = count.quarter + count.base + count.branch + count.twig,
		height = max_y + 1, width = max_x - min_x + 1, depth = max_z - min_z + 1,
		min = {min_x, 0, min_z}, max = {max_x, max_y, max_z}, facts = t.facts, roots = t.roots,
	}
end

-- ================================================================ species

-- The stem cell of layer y that lies furthest towards direction k: the
-- cell a limb growing that way leaves from ({x, z}, or nil).
local function trunk_edge(t, y, k)
	local best, best_dot = nil, -999999
	for i = 1, #t.stem_list do
		local c = t.cells[t.stem_list[i]]
		if c.y == y and WOOD[c.kind] == true then
			local dot = dir_x(k) * c.x + dir_z(k) * c.z
			if dot > best_dot then best_dot = dot; best = {c.x, c.z} end
		end
	end
	return best
end

-- The first stem cell of layer y.
local function stem_at(t, y)
	for i = 1, #t.stem_list do
		local c = t.cells[t.stem_list[i]]
		if c.y == y then return {c.x, c.z} end
	end
	return nil
end

-- APPLE: a short stout bole that opens into a ball. Three or four
-- scaffold limbs leave the top of the bole sideways and climb outwards
-- at about 45 degrees to the crown's rim, each in one upright plane (a
-- cardinal direction: a limb between two would zigzag in three axes).
-- At the rim each limb forks: one twig curves back up and in towards
-- the top of the ball, one runs sideways along the rim. The crown is a
-- round core with a cluster on every twig end: round, lumpy where the
-- twigs end.
local function apple(t, rng)
	local w = chance(rng, 40) and 2 or 1
	local bole = w == 2 and rint(rng, 3, 4) or rint(rng, 3, 5)
	for y = 0, bole - 1 do
		if w == 2 then trunk_layer(t, y, 0, 0, 2) else stem_cell(t, 0, y, 0, "trunk", 0) end
	end
	local top = bole - 1
	local rx = rint(rng, 60, 74)              -- crown radius, 3.75..4.6 nodes
	local ry = rint(rng, 46, 54)              -- crown half height
	local ax16 = w == 2 and 0 or 8            -- trunk axis in p16
	local lean = chance(rng, 45) and rint(rng, 0, 3) or -1
	local cx, cz = ax16, ax16
	if lean >= 0 then cx = cx + CARD[lean + 1][1] * 12; cz = cz + CARD[lean + 1][2] * 12 end
	local cy = bole * 16 + ry - 12
	cluster(t, cx, cy, cz, rx, ry, rx, -99)
	local limbs = w == 2 and 4 or rint(rng, 3, 4)
	local c0 = rint(rng, 0, 3)
	local skip = rint(rng, 0, 3)
	for i = 0, 3 do
		if limbs == 4 or i ~= skip then
			local d = ((c0 + i) % 4) * 4
			-- a 2 x 2 bole: each limb leaves from the quarter beside it,
			-- so the four turn like a pinwheel
			local st = trunk_edge(t, top, d + (w == 2 and 2 or 0))
			local reach = idiv(rx * rint(rng, 64, 80), 100)
			local e1 = limb(t, st[1], top, st[2], cell_of(off_x(cx, d, reach)), cell_of(cy + rint(rng, -6, 6)),
				cell_of(off_z(cz, d, reach)), 0, 70, OUT_FIRST)
			local path = t.path
			cluster(t, mid(e1[1]), mid(e1[2]) + 2, mid(e1[3]), rint(rng, 30, 38), rint(rng, 26, 30),
				rint(rng, 30, 38), -99)
			-- the fork: up and in, and sideways along the rim
			local ur = idiv(rx * rint(rng, 50, 70), 100)
			local e2 = limb(t, e1[1], e1[2], e1[3], cell_of(off_x(cx, d, ur)),
				cell_of(cy + idiv(ry * rint(rng, 55, 75), 100)), cell_of(off_z(cz, d, ur)), 0, 0, UP_FIRST)
			cluster(t, mid(e2[1]), mid(e2[2]), mid(e2[3]), rint(rng, 26, 32), rint(rng, 24, 28),
				rint(rng, 26, 32), -99)
			if #path >= 3 then
				local mp = path[idiv(#path * 2, 3) + 1]
				local side = d + (chance(rng, 50) and 3 or -3)
				local sr = idiv(rx * rint(rng, 70, 85), 100)
				local e3 = limb(t, mp[1], mp[2], mp[3], cell_of(off_x(cx, side, sr)), mp[2] + 1,
					cell_of(off_z(cz, side, sr)), 0, 0, OUT_FIRST)
				cluster(t, mid(e3[1]), mid(e3[2]), mid(e3[3]), rint(rng, 24, 30), rint(rng, 22, 26),
					rint(rng, 24, 30), -99)
			end
		end
	end
	limb_bases(t)
	fill_leaves(t, 62, 38, rint(rng, 1, 99999), 3)
	hang_fruit(t, rng, rint(rng, 3, 7))
	t.facts = {trunk = w .. "x" .. w, bole = bole, limbs = limbs,
		crown = (idiv(rx * 2, 16) + 1) .. " wide",
		lean = lean >= 0 and ({"+x", "+z", "-x", "-z"})[lean + 1] or "none"}
end

-- JUNGLE: a tall stem that wanders, sheds its lower limbs and carries
-- its crown as separate clumps at the ends of rising limbs.
local function jungle(t, rng)
	local h = rint(rng, 12, 15)              -- total height target
	local top = h - 4                        -- last trunk layer
	local w = chance(rng, 30) and 2 or 1
	local wide = w == 2 and top + 1 or 0     -- a 2 x 2 stem stays straight
	local x, z = 0, 0
	-- the stem wanders: one side-step low, often a second one higher up
	-- that turns back or aside, so the stem swings round its foot
	-- instead of leaning away
	local k1 = imax(wide + 1, rint(rng, 3, idiv(top, 2) - 1))
	local k2 = imax(k1 + 4, rint(rng, idiv(top, 2) + 2, top - 2))
	local d1 = rint(rng, 0, 3)
	local d2 = (d1 + rint(rng, 1, 3)) % 4
	local kinks = 1
	if w == 2 then
		kinks = 0
	elseif chance(rng, 60) and k2 <= top - 1 then
		kinks = 2
	end
	for y = 0, top do
		if (kinks >= 1 and y == k1) or (kinks == 2 and y == k2) then
			-- the 1 x 1 stem steps aside: for one layer it stands on
			-- two logs, a knee
			local d = y == k1 and d1 or d2
			stem_cell(t, x + CARD[d + 1][1], y - 1, z + CARD[d + 1][2], "trunk", 0)
			x = x + CARD[d + 1][1]; z = z + CARD[d + 1][2]
		end
		if y < wide then
			trunk_layer(t, y, 0, 0, 2)
		else
			stem_cell(t, x, y, z, "trunk", 0)
		end
	end
	local limbs = rint(rng, 3, 5)
	local a0 = rint(rng, 0, 15)
	local ly = top - 1
	local low = idiv(top * 55, 100)
	local made = 0
	local i = 0
	while i < limbs and ly >= low do
		local az = a0 + i * rint(rng, 5, 7)
		local st = trunk_edge(t, ly, az)
		local reach = rint(rng, 38, 58)
		local rise = rint(rng, 16, 36)
		local e = limb(t, st[1], ly, st[2], cell_of(off_x(mid(st[1]), az, reach)), ly + cell_of(rise + 8),
			cell_of(off_z(mid(st[2]), az, reach)), 0, 50, OUT_FIRST)
		local crx = rint(rng, 34, 42)
		if chance(rng, 40) then
			-- the limb forks into two twigs, a clump on each
			for f = -1, 1, 2 do
				local fa = az + 3 * f
				local fend = limb(t, e[1], e[2], e[3], e[1] + cell_of(dir_x(fa) * 2 + 8),
					e[2] + 1, e[3] + cell_of(dir_z(fa) * 2 + 8), 0, 0, OUT_FIRST)
				cluster(t, mid(fend[1]), mid(fend[2]) + 10, mid(fend[3]), crx - 6, rint(rng, 26, 30), crx - 6, -99)
			end
		else
			cluster(t, mid(e[1]), mid(e[2]) + 10, mid(e[3]), crx, rint(rng, 28, 34), crx, -99)
		end
		made = made + 1
		ly = ly - rint(rng, 2, 3)
		i = i + 1
	end
	-- the leader ends in the highest clump
	local lead = rint(rng, 1, 2)
	local lx16, lz16 = mid(x), mid(z)
	if w == 2 then
		for y = top + 1, top + lead do trunk_layer(t, y, 0, 0, 2) end
		lx16 = 0; lz16 = 0
	else
		column(t, x, top + 1, top + lead, z, "branch")
	end
	cluster(t, lx16, mid(top + lead) + 8, lz16, rint(rng, 40, 48), rint(rng, 30, 36),
		rint(rng, 40, 48), -99)
	-- small clumps low on the stem where a dormant bud broke out
	local buds = rint(rng, 0, 2)
	for _ = 1, buds do
		local by = rint(rng, 3, idiv(top, 2))
		local bd = rint(rng, 0, 3)
		local bc = trunk_edge(t, by, bd * 4)
		if bc ~= nil then
			local bx, bz = bc[1] + CARD[bd + 1][1], bc[2] + CARD[bd + 1][2]
			if get_cell(t, bx, by, bz) == nil and clean_step(t, bx, by, bz, bc[1], by, bc[2]) then
				put_cell(t, bx, by, bz, "twig", CARD[bd + 1][1] ~= 0 and 12 or 4)
				cluster(t, mid(bx + CARD[bd + 1][1]), mid(by) + 6, mid(bz + CARD[bd + 1][2]), 22, 18, 22, 0)
			end
		end
	end
	limb_bases(t)
	fill_leaves(t, 58, 45, rint(rng, 1, 99999), 3)
	t.facts = {trunk = w .. "x" .. w .. " wandering", kinks = kinks, clumps = made + 1}
end

-- KAPOK: the emergent giant. A long clear column, 3 x 3 or 2 x 2; a
-- 3 x 3 steps in to the 2 x 2 leader only inside the crown, just above
-- where the big limbs leave, so the ledge hides among them. Then a broad
-- high crown on wide, gently rising limbs.
local function kapok(t, rng)
	local h = rint(rng, 22, 27)
	local w = chance(rng, 60) and 3 or 2
	local base = idiv(h * 60, 100) + rint(rng, -1, 1)   -- crown base
	local ax2 = w == 3 and 1 or 0
	local az2 = ax2
	local narrow = base + 1                   -- 3x3 -> 2x2, inside the crown
	local lean = rint(rng, 0, 3)
	local top = h - 4
	for y = 0, top do
		if w == 3 and y == narrow then
			local c1, c2 = CARD[lean + 1], CARD[(lean + 1) % 4 + 1]
			ax2 = ax2 + (c1[1] + c2[1] < 0 and -1 or 1)
			az2 = az2 + (c1[2] + c2[2] < 0 and -1 or 1)
		end
		-- above the crown base the 2 x 2 column goes on as the leader
		trunk_layer(t, y, ax2, az2, (w == 3 and y < narrow) and 3 or 2)
	end
	local cx16, cz16 = ax2 * 8, az2 * 8
	local n1 = rint(rng, 4, 6)
	local a0 = rint(rng, 0, 15)
	for i = 0, n1 - 1 do
		local az = a0 + idiv(16 * i, n1) + rint(rng, -1, 1)
		local sy = base - (i % 2)
		local st = trunk_edge(t, sy, az)
		local reach = rint(rng, 54, 70)
		local rise = rint(rng, 24, 56)
		local e = limb(t, st[1], sy, st[2], cell_of(off_x(cx16, az, reach)), sy + cell_of(rise + 8),
			cell_of(off_z(cz16, az, reach)), 0, 70, OUT_FIRST)
		if chance(rng, 50) and #t.path >= 4 then
			-- a clump hangs under the middle of the limb
			local hp = t.path[idiv(#t.path, 2) + 1]
			cluster(t, mid(hp[1]), mid(hp[2]), mid(hp[3]), rint(rng, 26, 32), rint(rng, 22, 26),
				rint(rng, 26, 32), -2)
		end
		for f = -1, 1, 2 do
			local fa = az + 3 * f
			local fend = limb(t, e[1], e[2], e[3], e[1] + cell_of(dir_x(fa) + 8),
				e[2] + 1, e[3] + cell_of(dir_z(fa) + 8), 0, 0, UP_FIRST)
			cluster(t, mid(fend[1]), mid(fend[2]) + 10, mid(fend[3]), rint(rng, 36, 42),
				rint(rng, 24, 28), rint(rng, 36, 42), -2)
		end
	end
	-- a second, shorter tier between the first tier's limbs
	local n2 = rint(rng, 2, 4)
	local y2 = base + rint(rng, 3, 4)
	for j = 0, n2 - 1 do
		local bz = a0 + idiv(8, n1) + idiv(16 * j, n2) + rint(rng, -1, 1)
		local r2 = rint(rng, 32, 48)
		local s2 = trunk_edge(t, y2, bz)
		local e2 = limb(t, s2[1], y2, s2[2], cell_of(off_x(cx16, bz, r2 + 8)), y2 + rint(rng, 1, 2),
			cell_of(off_z(cz16, bz, r2 + 8)), 0, 50, OUT_FIRST)
		cluster(t, mid(e2[1]), mid(e2[2]) + 10, mid(e2[3]), rint(rng, 36, 44), rint(rng, 24, 28),
			rint(rng, 36, 44), -2)
	end
	-- the dome that joins the clumps, and the top
	cluster(t, cx16, mid(base + 5), cz16, rint(rng, 60, 72), rint(rng, 44, 52), rint(rng, 60, 72), -2)
	cluster(t, cx16, mid(top) + 6, cz16, rint(rng, 44, 52), rint(rng, 28, 32), rint(rng, 44, 52), -1)
	limb_bases(t)
	fill_leaves(t, 60, 40, rint(rng, 1, 99999), 3)
	t.facts = {trunk = w .. "x" .. w .. (w == 3 and " to 2x2" or ""), crownBase = base, limbs = n1 + n2}
end

-- ACACIA: a short trunk that forks into a wide V of thick limbs; every
-- limb end climbs to one common level and spreads into a flat pad: the
-- pads merge into an umbrella.
local function acacia(t, rng)
	local h = rint(rng, 2, 4)
	for y = 0, h - 1 do stem_cell(t, 0, y, 0, "trunk", 0) end
	local limbs = chance(rng, 50) and 2 or 3
	local a0 = rint(rng, 0, 15)
	local tips = {}
	local top = 0
	for i = 0, limbs - 1 do
		local az
		if limbs == 2 then
			az = a0 + i * rint(rng, 6, 8)
		else
			az = a0 + idiv(16 * i, 3) + rint(rng, -1, 1)
		end
		local reach = rint(rng, 46, 64)
		local rise = rint(rng, 30, 44)
		local e = limb(t, 0, h - 1, 0, cell_of(off_x(8, az, reach)), h - 1 + cell_of(rise + 8),
			cell_of(off_z(8, az, reach)), 0, 80, UP_FIRST)
		tips[#tips + 1] = {e[1], e[2], e[3], az}
		top = imax(top, e[2])
	end
	local level = top + 1
	local pads = {}
	for j = 1, #tips do
		local tp = tips[j]
		-- twigs climb from the limb end to the canopy level
		local up = limb(t, tp[1], tp[2], tp[3], tp[1], level - 1, tp[3], 0, 0, UP_FIRST)
		if chance(rng, 55) then
			for f = -1, 1, 2 do
				local fa = tp[4] + 3 * f
				local fe = limb(t, up[1], up[2], up[3], up[1] + cell_of(dir_x(fa) * 2 + 8), up[2],
					up[3] + cell_of(dir_z(fa) * 2 + 8), 0, 0, OUT_FIRST)
				pads[#pads + 1] = fe
			end
		else
			pads[#pads + 1] = up
		end
	end
	for p = 1, #pads do
		local r = rint(rng, 42, 52)
		cluster(t, mid(pads[p][1]), mid(level), mid(pads[p][3]), r, rint(rng, 20, 24), r, -1)
	end
	limb_bases(t)
	fill_leaves(t, 55, 40, rint(rng, 1, 99999), 3)
	t.facts = {trunk = "1x1, " .. h .. " high", fork = limbs .. " limbs", canopy = "at " .. level}
end

-- PINE: a straight stem that thins from log to branch to twig, with a
-- whorl of short twigs every two (sometimes three) nodes; every whorl
-- carries a needle skirt, wide below, narrow above: a layered cone.
local function pine(t, rng)
	local h = rint(rng, 12, 17)
	local bole = rint(rng, 2, 4)
	local apex = h - 1
	local thick = idiv(h * 55, 100)
	column(t, 0, 0, thick, 0, "trunk")
	column(t, 0, thick + 1, apex - 2, 0, "branch")
	column(t, 0, apex - 1, apex - 1, 0, "twig")
	local rbase = rint(rng, 50, 62)
	local turn = rint(rng, 0, 1)
	local y = bole
	local whorls = 0
	while y <= apex - 3 do
		local r = idiv(rbase * (apex + 1 - y), apex + 1 - bole)
		local len = cell_of(r) - 1
		local diag = (whorls + turn) % 2
		local i = 0
		while i < 4 and len >= 1 do
			local az = i * 4 + diag * 2
			limb(t, 0, y, 0, cell_of(off_x(8, az, len * 16)), y, cell_of(off_z(8, az, len * 16)), 0, 0, OUT_FIRST)
			i = i + 1
		end
		cluster(t, 8, mid(y), 8, r, 22, r, 0)
		whorls = whorls + 1
		y = y + (chance(rng, 15) and 3 or 2)
	end
	cluster(t, 8, mid(apex - 1), 8, 18, 30, 18, -1)
	put_cell(t, 0, apex, 0, "leaves", 0)
	limb_bases(t)
	fill_leaves(t, 70, 22, rint(rng, 1, 99999), 3)
	t.facts = {trunk = "1x1 tapering", whorls = whorls, base = (idiv(rbase * 2, 16) + 1) .. " wide"}
end

-- ASPEN: a slender pale stem, a long bare bole, then a narrow tall oval
-- crown on short twigs that spiral up the leader.
local function aspen(t, rng)
	local h = rint(rng, 11, 15)
	local bole = rint(rng, 4, 6)
	local apex = h - 1
	local bend = chance(rng, 40) and rint(rng, 0, 3) or -1
	local bend_y = bole + idiv((apex - bole) * 2, 3)
	column(t, 0, 0, bole + 1, 0, "trunk")
	local x, z = 0, 0
	for y = bole + 2, apex - 1 do
		if y == bend_y and bend >= 0 then
			stem_cell(t, x + CARD[bend + 1][1], y - 1, z + CARD[bend + 1][2], "branch", 0)
			x = x + CARD[bend + 1][1]; z = z + CARD[bend + 1][2]
		end
		stem_cell(t, x, y, z, y >= apex - 2 and "twig" or "branch", 0)
	end
	local rx = rint(rng, 42, 52)
	local cy = idiv((bole + 1 + apex + 1) * 16, 2)
	local ry = (apex + 1 - bole) * 8 + 2
	cluster(t, 8 + x * 8, cy, 8 + z * 8, rx, ry, rx, -99)
	local az = rint(rng, 0, 15)
	local y2 = bole + 1
	while y2 <= apex - 2 do
		local len = rint(rng, 1, 2)
		local c = stem_at(t, y2)
		local e = limb(t, c[1], y2, c[2], cell_of(off_x(mid(c[1]), az, len * 16)), y2 + rint(rng, 0, 1),
			cell_of(off_z(mid(c[2]), az, len * 16)), 0, 0, OUT_FIRST)
		cluster(t, mid(e[1]), mid(e[2]) + 4, mid(e[3]), rint(rng, 20, 26), rint(rng, 18, 24),
			rint(rng, 20, 26), -99)
		az = az + 5
		y2 = y2 + rint(rng, 1, 2)
	end
	limb_bases(t)
	fill_leaves(t, 60, 35, rint(rng, 1, 99999), 3)
	t.facts = {trunk = "1x1 slender", bole = bole, crown = (idiv(rx * 2, 16) + 1) .. " wide"}
end

-- SILVERWOOD: tall and elegant. A long clear slender bole (taller in
-- old trees), then a few limbs that step out once and rise parallel to the
-- leader; each carries a slim leaf column, together a flame.
local function silverwood(t, rng)
	local old = chance(rng, 35)
	local h = old and rint(rng, 19, 22) or rint(rng, 15, 18)
	local bole = rint(rng, 6, 8)
	local apex = h - 1
	local x, z = 0, 0
	column(t, x, 0, bole + 2, z, "trunk")
	column(t, x, bole + 3, apex - 3, z, "branch")
	column(t, x, apex - 2, apex - 1, z, "twig")
	local limbs = old and rint(rng, 4, 5) or rint(rng, 3, 4)
	local a0 = rint(rng, 0, 15)
	for i = 0, limbs - 1 do
		local az = a0 + idiv(16 * i, limbs) + rint(rng, -1, 1)
		local sy = bole + (i % 3)
		local so = rint(rng, 32, 44)
		local e1 = limb(t, x, sy, z, cell_of(off_x(mid(x), az, so)), sy + 1, cell_of(off_z(mid(z), az, so)),
			0, 100, OUT_FIRST)
		local lt = apex - rint(rng, 3, 5)
		local e2 = limb(t, e1[1], e1[2], e1[3], e1[1], lt, e1[3], 0, 45, UP_FIRST)
		-- the column reaches 2-3 below where the limb turns upright
		local rr = rint(rng, 28, 36)
		cluster(t, mid(e2[1]), idiv((e1[2] + lt + 2) * 16, 2) - 12, mid(e2[3]), rr,
			(lt - e1[2]) * 8 + 34, rr, -99)
	end
	cluster(t, mid(x), idiv((bole + 2 + apex + 1) * 16, 2), mid(z), rint(rng, 30, 36),
		(apex - bole) * 8 + 8, rint(rng, 30, 36), -99)
	limb_bases(t)
	fill_leaves(t, 62, 32, rint(rng, 1, 99999), 3)
	t.facts = {trunk = "1x1", age = old and "old" or "young", bole = bole, limbs = limbs}
end

-- GRAVEWOOD: a dead tree. The stem bends one way as it climbs, a few
-- bare limbs reach out level or rising and end in two-pronged claws, a
-- quarter hooked up, a few drooping; a few grey tufts.
local function gravewood(t, rng)
	local h = rint(rng, 6, 10)
	local top = h - 2
	local lean = rint(rng, 0, 3)
	local k1 = rint(rng, 2, 3)
	local k2 = chance(rng, 55) and rint(rng, k1 + 2, imax(k1 + 2, top - 1)) or -1
	local d2 = lean
	if not chance(rng, 60) then d2 = (lean + (chance(rng, 50) and 1 or 3)) % 4 end
	local x, z = 0, 0
	for y = 0, top do
		if y == k1 or y == k2 then
			local d = y == k1 and lean or d2
			stem_cell(t, x + CARD[d + 1][1], y - 1, z + CARD[d + 1][2], "trunk", 0)
			x = x + CARD[d + 1][1]; z = z + CARD[d + 1][2]
		end
		stem_cell(t, x, y, z, "trunk", 0)
	end
	-- a broken stub or a small fork at the top
	local sa = rint(rng, 0, 15)
	limb(t, x, top, z, x + cell_of(dir_x(sa) + 8), top + 1, z + cell_of(dir_z(sa) + 8), 0, 50, UP_FIRST)
	local limbs = rint(rng, 3, 5)
	local a0 = lean * 4 + 8 + rint(rng, -2, 2)   -- the limbs balance the lean
	local tips = {}
	for i = 0, limbs - 1 do
		local az = a0 + idiv(16 * i, limbs) + rint(rng, -1, 1)
		local ly = rint(rng, idiv(h * 45, 100), top)
		local c = trunk_edge(t, ly, az)
		local reach = rint(rng, 44, 70)
		local rise = rint(rng, -4, 16)
		local e = limb(t, c[1], ly, c[2], cell_of(off_x(mid(c[1]), az, reach)), ly + cell_of(rise + 8),
			cell_of(off_z(mid(c[2]), az, reach)), 0, 55, OUT_FIRST)
		local tip_end = rint(rng, 0, 19)     -- 25 % hooked, 15 % drooping
		local prong = rint(rng, 0, 1)
		if tip_end < 5 then
			e = limb(t, e[1], e[2], e[3], e[1], e[2] + 1, e[3], 0, 0, UP_FIRST)
			prong = 1
		elseif tip_end < 8 then
			e = limb(t, e[1], e[2], e[3], e[1] + cell_of(dir_x(az) + 8), e[2] - 1,
				e[3] + cell_of(dir_z(az) + 8), 0, 0, OUT_FIRST)
			prong = -1
		end
		-- the claw: two prongs
		for f = -1, 1, 2 do
			local fa = az + 3 * f
			limb(t, e[1], e[2], e[3], e[1] + cell_of(dir_x(fa) + 8), e[2] + prong,
				e[3] + cell_of(dir_z(fa) + 8), 0, 0, OUT_FIRST)
		end
		tips[#tips + 1] = e
	end
	local tufts = rint(rng, 1, 4)
	local j = 0
	while j < tufts and j < #tips do
		local tp = tips[rint(rng, 0, #tips - 1) + 1]
		cluster(t, mid(tp[1]), mid(tp[2]) + 8, mid(tp[3]), rint(rng, 18, 26), rint(rng, 14, 18),
			rint(rng, 18, 26), -1)
		j = j + 1
	end
	limb_bases(t)
	fill_leaves(t, 50, 40, rint(rng, 1, 99999), 3)
	t.facts = {trunk = "1x1 bent", limbs = limbs, tufts = tufts}
end

-- ================================================================ table

local SPECIES = {
	apple = {salt = 1, grow = apple},
	jungle = {salt = 2, grow = jungle},
	kapok = {salt = 3, grow = kapok},
	acacia = {salt = 4, grow = acacia},
	pine = {salt = 5, grow = pine},
	aspen = {salt = 6, grow = aspen},
	silverwood = {salt = 7, grow = silverwood},
	gravewood = {salt = 8, grow = gravewood},
}
local ORDER = {"apple", "jungle", "kapok", "acacia", "pine", "aspen", "silverwood", "gravewood"}

-- ================================================================ roots

-- Roots: pieces at the foot of a thick trunk, built from the existing
-- pieces. A root leaves the trunk at height h (0, 2 or 3), one cell out:
-- limb bases from there straight down beside the trunk to the ground (a
-- buttress rib fused to the trunk, each base joining it sideways), then
-- on along the ground (a branch, a twig at the end) as a flare; a fork
-- adds a toe twig sideways where the flare leaves the rib. Only the base
-- and the twig join the ground, and only through their bottom; a branch
-- never does.
--
-- Every root cell needs ground right under its column at the trunk's
-- foot level (is_ground(x, -1, z)) and none at the root's own level
-- (is_ground(x, 0, z) false), the cells must be free and touch no other
-- wood than the trunk (rib) and the root itself; else that root (or
-- fork) is left out. Roots draw their numbers from their own random
-- stream, all before any ground test, so the rest of the tree is the
-- same on any terrain.
--
-- Per species: apple rarely and only 2 x 2, one cell (a base at the
-- foot); jungle only 2 x 2, a bit more often, 2 out, a third of them
-- starting 2 up; kapok always, mostly from 2-3 up, 2-3 out, often forked.
-- high: percent for h = 0, 2 (the rest 3).
local ROOTS = {
	apple = {pct = 25, min = 1, max = 2, reach = {1, 1}, high = {100, 0}, fork = 0},
	jungle = {pct = 45, min = 1, max = 3, reach = {2, 2}, high = {65, 35}, fork = 0},
	kapok = {pct = 100, min = 0, max = 0, reach = {2, 3}, high = {20, 45}, fork = 55},
}

-- The stem cells of layer y that lie furthest out on side d (CARD index
-- 0..3), as {x, z}.
local function side_cells(t, y, d)
	local best, cells = -999, {}
	local card = CARD[d + 1]
	for i = 1, #t.stem_list do
		local c = t.cells[t.stem_list[i]]
		if c.y == y and (c.kind == "quarter" or c.kind == "trunk") then
			local dot = card[1] * c.x + card[2] * c.z
			if dot > best then
				best = dot; cells = {{c.x, c.z}}
			elseif dot == best then
				cells[#cells + 1] = {c.x, c.z}
			end
		end
	end
	return cells
end

-- A root cell c = {x, y, z, kind, rot}: ground under its column at the
-- foot level, none at the root's level, free, and touching no wood but
-- its predecessor p = {x, y, z, ...} (and the trunk, for a rib base).
local function root_cell_ok(t, c, p)
	local x, y, z = c[1], c[2], c[3]
	if not t.is_ground(x, -1, z) or t.is_ground(x, 0, z) or get_cell(t, x, y, z) ~= nil then return false end
	for i = 1, 6 do
		local nbd = NEIGHBOURS[i]
		local nx, ny, nz = x + nbd[1], y + nbd[2], z + nbd[3]
		local nk = key(nx, ny, nz)
		if not (nx == p[1] and ny == p[2] and nz == p[3]) and is_wood(t, nx, ny, nz) and
				not (c[4] == "base" and t.stem_set[nk] == true) then
			return false
		end
	end
	return true
end

-- Place a list of cells {x, y, z, kind, rot} after `from` if every one
-- passes the ground and space test.
local function place_run(t, from, run)
	local p = from
	for i = 1, #run do
		if not root_cell_ok(t, run[i], p) then return false end
		p = run[i]
	end
	for j = 1, #run do
		local r = run[j]
		put_cell(t, r[1], r[2], r[3], r[4], r[5])
		t.roots[#t.roots + 1] = {r[1], r[2], r[3]}
	end
	return true
end

-- One root from stem cell a {x, z} on side d: a base one out at height
-- h, bases straight down beside the trunk to the ground, then on along
-- the ground to `reach` out (branch..., twig). `fork` (+1 / -1 / 0) adds a
-- toe twig to one side of the first ground cell beyond the rib.
local function root_run(t, a, d, h, reach, fork)
	local dx, dz = CARD[d + 1][1], CARD[d + 1][2]
	local hrot = dx ~= 0 and 12 or 4
	local run = {}
	for y = h, 0, -1 do
		run[#run + 1] = {a[1] + dx, y, a[2] + dz, "base", y == h and hrot or 0}
	end
	for out = 2, reach do
		run[#run + 1] = {a[1] + dx * out, 0, a[2] + dz * out, out == reach and "twig" or "branch", hrot}
	end
	if not place_run(t, {a[1], h, a[2]}, run) then return false end
	if fork ~= 0 and reach >= 2 then
		local c = run[h + 2]
		place_run(t, c, {{c[1] - dz * fork, 0, c[3] + dx * fork, "twig", dx ~= 0 and 4 or 12}})
	end
	return true
end

local function roots(t, seed)
	local plan = ROOTS[t.species]
	if plan == nil then return end
	local rng = new_rng(seed, 1000 + SPECIES[t.species].salt)
	local thick = #side_cells(t, 0, 0) >= 2
	local go = chance(rng, plan.pct)
	local s0 = rint(rng, 0, 3)
	local count = rint(rng, plan.min, plan.max)
	-- what each side would get: {anchor index, reach, fork side or 0, h}
	local wish = {}
	for _ = 0, 3 do
		local n = plan.max == 0 and rint(rng, 1, 2) or 0   -- kapok: per side
		local list = {}
		for _ = 0, 1 do
			local hp = rint(rng, 0, 99)
			local anchor = rint(rng, 0, 2)
			local reach = rint(rng, plan.reach[1], plan.reach[2])
			local fork = 0
			if chance(rng, plan.fork) then fork = chance(rng, 50) and 1 or -1 end
			local h = 3
			if hp < plan.high[1] then
				h = 0
			elseif hp < plan.high[1] + plan.high[2] then
				h = 2
			end
			list[#list + 1] = {anchor, reach, fork, h}
		end
		wish[#wish + 1] = {n = n, list = list}
	end
	if not go or not thick then return end
	local made = 0
	for i = 0, 3 do
		local side = (s0 + i) % 4
		local want
		if plan.max == 0 then
			want = wish[side + 1].n
		else
			want = (i < count and (count < 3 or i < 3)) and 1 or 0
		end
		if plan.max ~= 0 and count == 2 and i == 1 then want = 0 end   -- two roots: opposite sides
		if plan.max ~= 0 and count == 2 and i == 2 then want = 1 end
		for r = 0, want - 1 do
			local w = wish[side + 1].list[r + 1]
			local cells = side_cells(t, w[4], side)
			if #cells > 0 then
				-- two roots on one side leave from its two ends
				local at
				if want == 2 then
					at = r == 0 and 0 or #cells - 1
				else
					at = w[1] % #cells
				end
				if root_run(t, cells[at + 1], side, w[4], w[2], w[3]) then made = made + 1 end
			end
		end
	end
	t.facts.roots = made
end

-- The Shapes view's root study: a w x w trunk 5 high on the given ground
-- with one root tried on each side (from the side's middle cell), each
-- side's root given as {h, reach, fork} in specs[d + 1] (nil: none).
local function root_study(is_ground, w, specs)
	local t = new_tree("kapok", 0, is_ground)
	local ax = w == 2 and 0 or 1
	for y = 0, 4 do trunk_layer(t, y, ax, ax, w) end
	for d = 0, 3 do
		local sp = specs[d + 1]
		if sp then
			local cells = side_cells(t, sp[1], d)
			root_run(t, cells[idiv(#cells, 2) + 1], d, sp[1], sp[2], sp[3])
		end
	end
	return finish(t)
end

-- is_ground(x, y, z) in tree coordinates says whether that cell is ground
-- (the tree's foot stands on y = -1); the default is flat ground.
local function generate(species, seed, is_ground)
	local row = SPECIES[species]
	if row == nil then error("treegen: unknown species " .. tostring(species), 2) end
	local t = new_tree(species, seed, is_ground or flat_ground)
	local rng = new_rng(seed, row.salt)
	row.grow(t, rng)
	roots(t, seed)
	return finish(t)
end

return {
	generate = generate, root_study = root_study, ORDER = ORDER, WOOD = WOOD, ROOTS = ROOTS,
	quarter_rot = quarter_rot, new_rng = new_rng, rint = rint,
}
