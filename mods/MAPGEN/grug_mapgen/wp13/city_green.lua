-- Capital greening (Round 47, the user: "green the capitals' open grass
-- between the district plots"; the rule of `layout.green`): small groups of
-- the race's generated trees on the city ground no composition owns -- the
-- grass inside the wall between the core, the placed district plots, the
-- streets and the squares.
--
-- It rides on the city edge overlay (`r7_settlement.lua`), the one part of a
-- capital that is already a pure function of a column's final ground, water
-- and road surface and of this world's capital layout, and that the R7
-- writer asks per mapchunk: so a mapchunk writes exactly its own cells of
-- every tree, whichever order the chunks generate in (the edge's seam rule),
-- and the trees stand inside the capital's protected ground.
--
-- THE RULE.
--   * Slots: a GREEN_STEP lattice over the city in anchor-local columns, each
--     point jittered by a hash, carries 1 to 5 slots at the offsets of
--     `layout.green` (a single or a small stand). Every slot has a priority
--     (a hash of its position).
--   * A slot is VIABLE with the first candidate shape that fits: the town
--     pool's tree of a hash, else the narrowest pool trees in every turn
--     (`dressing.lua`'s pool rule). A shape fits when every cell's column
--     lies inside the city, WALL_CLEAR or more from the wall line (so no
--     crown touches a wall, gatehouse or turret), outside the civic core, the
--     placed plots with their collar and approach, and the squares
--     (with a margin of KEEP: what holds the NPC sockets, doors, stations,
--     waypoints and every map marker; a leaf may lean over a plot's collar,
--     never over the plot), the trunk's foot
--     stands on dry land that is no road, with every foot column at the
--     trunk's own ground; no wood is inside the ground, in water or over a
--     road below head height. A leaf there is left out (at most half).
--   * Between slots, by priority and only one neighbour deep (so the
--     decision is local to the chunks it touches): a viable slot is dropped
--     when a higher-priority viable slot's stem lies within SPACING or its
--     wood shares a cell with that slot's wood; a leaf is left out where any
--     viable neighbour has wood or a higher-priority one a leaf (crowns
--     interleave and merge, a leaf never replaces wood).
--   * Roots: a run where every cell's column has its ground at the foot.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.
local function loader(directory)
	local palettes = dofile(directory .. "/palette.lua")
	local parts = dofile(directory .. "/parts.lua")
	local plot_approach = dofile(directory .. "/plot_approach.lua")
	local wp40 = directory .. "/../wp40"
	local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max

	local M = {}
	M.SPECIES = {human = "apple", dwarf = "pine", elf = "silverwood", undead = "gravewood",
		orc = "acacia", troll = "jungle"}
	local GREEN_STEP, SPACING, KEEP, WALL_CLEAR = 11, 4, 4, 12
	local GROUP = {{0, 0}, {4, 1}, {-3, 3}, {1, -4}, {-4, -2}}
	local POOL, ATTEMPTS, SMALLEST = 24, 2, 8
	local CORE_HALF = 49
	M.REACH = 8 -- a tree's cells lie within 8 of its stem (tree_templates.lua)

	local trees_module
	local function trees()
		if not trees_module then
			trees_module = dofile(wp40 .. "/tree_templates.lua")(dofile(wp40 .. "/treegen.lua"))
		end
		return trees_module
	end

	-- The node names one race's city trees write (the overlay palette).
	function M.names(race)
		local p = palettes.new(race)
		local log, leaves = p.node("tree_log"), p.node("tree_leaves")
		local list = {log, leaves}
		for _, row in ipairs(trees().SPECIES) do
			if row.trunk == log then
				list[#list + 1] = row.quarter
				list[#list + 1] = row.base
				list[#list + 1] = row.branch
				list[#list + 1] = row.twig
				if row.fruit and row.key == M.SPECIES[race] then list[#list + 1] = row.fruit end
				break
			end
		end
		return list
	end

	local function hash(a, b, c)
		local h = ((a + 4096) * 73856093 + (b + 4096) * 19349663 + (c or 0) * 83492791) % 2147483647
		h = (h * 48271) % 2147483647
		return (h * 48271) % 2147483647
	end

	local function turn(x, z, turns)
		for _ = 1, turns do x, z = z, -x end
		return x, z
	end

	-- opts: race, anchor {x, z}, layout (the deserialized capital layout),
	-- plots {{min_x, max_x, min_z, max_z, turns}} (world rects of the placed
	-- plots), column(x, z) -> ground, water, road (world columns).
	function M.new(opts)
		local race, anchor, layout, column = opts.race, opts.anchor, opts.layout, opts.column
		local species = M.SPECIES[race]
		local palette = palettes.new(race)
		local log, leaves = palette.node("tree_log"), palette.node("tree_leaves")
		local T = trees()
		local own = T.BY_KEY[species]
		local wood_row
		for _, row in ipairs(T.SPECIES) do
			if row.trunk == log then wood_row = row break end
		end
		local function name_of(name)
			if name == own.trunk then return log
			elseif name == own.quarter then return wood_row.quarter
			elseif name == own.base then return wood_row.base
			elseif name == own.branch then return wood_row.branch
			elseif name == own.twig then return wood_row.twig
			elseif name == own.leaves then return leaves end
			return name
		end
		-- the pool: {cells, runs, area}, and the narrowest first
		local pool, smallest = {}, {}
		for k = 1, POOL do
			local cells, tree = T.tree(species, ((k * 7919 + 104729) % 2147483646) - 1)
			local body, by_key = {}, {}
			for _, cell in ipairs(cells) do
				if cell.root then by_key[cell.x .. "," .. cell.y .. "," .. cell.z] = cell
				else body[#body + 1] = cell end
			end
			local runs = {}
			for _, run in ipairs(tree.root_runs) do
				local list = {parent = run.parent}
				for r = run.first, run.last do
					local at = tree.roots[r]
					list[#list + 1] = by_key[at[1] .. "," .. at[2] .. "," .. at[3]]
				end
				runs[#runs + 1] = list
			end
			pool[k] = {cells = body, runs = runs, area = tree.width * tree.depth}
			smallest[k] = k
		end
		table.sort(smallest, function(a, b)
			if pool[a].area ~= pool[b].area then return pool[a].area < pool[b].area end
			return a < b
		end)

		-- the wall line: inside (even-odd) and the distance to it
		local W = layout.wall
		local pts, n = W.pts, #W.pts
		local rows, buckets = {}, {}
		for i = 1, n do
			local a, b = pts[i], pts[i % n + 1]
			for r = floor(min(a[2], b[2]) / 4), floor(max(a[2], b[2]) / 4) do
				rows[r] = rows[r] or {}
				rows[r][#rows[r] + 1] = i
			end
			for bz = floor((min(a[2], b[2]) - WALL_CLEAR) / 16),
					floor((max(a[2], b[2]) + WALL_CLEAR) / 16) do
				for bx = floor((min(a[1], b[1]) - WALL_CLEAR) / 16),
						floor((max(a[1], b[1]) + WALL_CLEAR) / 16) do
					local key = bz * 65536 + bx
					buckets[key] = buckets[key] or {}
					buckets[key][#buckets[key] + 1] = i
				end
			end
		end
		local function inside_city(lx, lz)
			local l, c = rows[floor(lz / 4)], false
			if not l then return false end
			for _, i in ipairs(l) do
				local a, b = pts[i], pts[i % n + 1]
				if (a[2] > lz) ~= (b[2] > lz) and
						lx < a[1] + (lz - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) then
					c = not c
				end
			end
			return c
		end
		local function near_wall(lx, lz)
			local l = buckets[floor(lz / 16) * 65536 + floor(lx / 16)]
			for _, i in ipairs(l or {}) do
				local a, b = pts[i], pts[i % n + 1]
				local vx, vz = b[1] - a[1], b[2] - a[2]
				local l2 = vx * vx + vz * vz
				local u = l2 > 0 and ((lx - a[1]) * vx + (lz - a[2]) * vz) / l2 or 0
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				local dx, dz = lx - a[1] - u * vx, lz - a[2] - u * vz
				if sqrt(dx * dx + dz * dz) < WALL_CLEAR then return true end
			end
			return false
		end
		-- the plots with their collar and approach, the squares
		-- a stem and its wood keep clear of a plot's collar and approach; a
		-- leaf only of the plot itself (a crown may lean over a collar's grass)
		local boxes, plot_boxes = {}, {}
		for _, rect in ipairs(opts.plots or {}) do
			local fx, fz = plot_approach.rot(0, -1, rect.turns or 0)
			local c, a = plot_approach.COLLAR + 1, plot_approach.MAX_APPROACH
			boxes[#boxes + 1] = {rect.min_x - c - (fx < 0 and a or 0),
				rect.max_x + c + (fx > 0 and a or 0),
				rect.min_z - c - (fz < 0 and a or 0), rect.max_z + c + (fz > 0 and a or 0)}
			plot_boxes[#plot_boxes + 1] = {rect.min_x - 2, rect.max_x + 2,
				rect.min_z - 2, rect.max_z + 2}
		end
		local squares = layout.squares or {}

		local clear_memo, leaf_memo, column_memo = {}, {}, {}
		local function col(x, z)
			local key = z * 131072 + x
			local c = column_memo[key]
			if not c then
				local ground, water, road = column(x, z)
				c = {ground, water, road}
				column_memo[key] = c
			end
			return c[1], c[2], c[3]
		end
		local function in_boxes(list, x, z)
			for _, b in ipairs(list) do
				if x >= b[1] and x <= b[2] and z >= b[3] and z <= b[4] then return true end
			end
			return false
		end
		-- open city ground for a leaf: the city, clear of the wall, the core,
		-- the plots themselves and the squares
		local function leaf_clear(x, z)
			local key = z * 131072 + x
			local v = leaf_memo[key]
			if v ~= nil then return v end
			local lx, lz = x - anchor.x, z - anchor.z
			v = inside_city(lx, lz) and not near_wall(lx, lz) and
				not (abs(lx) <= CORE_HALF + KEEP and abs(lz) <= CORE_HALF + KEEP) and
				not in_boxes(plot_boxes, x, z)
			if v then
				for _, s in ipairs(squares) do
					local dx, dz = lx - s.x, lz - s.z
					local r = s.r + KEEP
					if dx * dx + dz * dz <= r * r then v = false break end
				end
			end
			leaf_memo[key] = v
			return v
		end
		-- ... and for a stem or wood also clear of every collar and approach
		local function clear(x, z)
			local key = z * 131072 + x
			local v = clear_memo[key]
			if v ~= nil then return v end
			v = leaf_clear(x, z) and not in_boxes(boxes, x, z)
			clear_memo[key] = v
			return v
		end

		-- One candidate shape at a stem: its writes {x, y, z, cell, turns,
		-- wood}, or nil.
		local function fit(entry, turns, sx, sz)
			local base, water0, road0 = col(sx, sz)
			if water0 or road0 then return nil end
			local writes, skipped, leaf_count = {}, 0, 0
			for _, cell in ipairs(entry.cells) do
				local cx, cz = turn(cell.x, cell.z, turns)
				local x, z = sx + cx, sz + cz
				local y = base + 1 + cell.y
				local wood = cell.flag ~= T.LEAF
				local ok
				if wood then ok = clear(x, z) else ok = leaf_clear(x, z) end
				local ground, water, road
				if ok then ground, water, road = col(x, z) end
				if wood then
					if not ok or y <= ground or (water and y <= water) or
							(road and y <= ground + 3) or (cell.y == 0 and ground ~= base) then
						return nil
					end
				else
					leaf_count = leaf_count + 1
					if not ok or y <= ground or (water and y <= water) or
							(road and y <= ground + 3) then
						skipped = skipped + 1
						ok = false
					end
				end
				if ok then writes[#writes + 1] = {x, y, z, cell, turns, wood} end
			end
			if skipped * 2 > leaf_count then return nil end
			local kept = {}
			for index, run in ipairs(entry.runs) do
				local ok = run.parent == 0 or kept[run.parent] == true
				for _, cell in ipairs(ok and run or {}) do
					local cx, cz = turn(cell.x, cell.z, turns)
					local x, z = sx + cx, sz + cz
					local ground, water, road = col(x, z)
					if not clear(x, z) or ground ~= base or water or road then
						ok = false
						break
					end
				end
				kept[index] = ok
				if ok then
					for _, cell in ipairs(run) do
						local cx, cz = turn(cell.x, cell.z, turns)
						writes[#writes + 1] = {sx + cx, base + 1 + cell.y, sz + cz, cell, turns, true}
					end
				end
			end
			return writes
		end

		-- slots per lattice point; viability memo by slot key
		local function ckey(x, y, z) return (z * 2048 + (y + 1024)) * 131072 + x end
		local viable_memo = {}
		local function slot_at(gx, gz, member)
			local h = hash(gx, gz)
			local cx = gx + h % 5 - 2
			local cz = gz + floor(h / 5) % 5 - 2
			local size = 1 + floor(h / 25) % 5
			if member > size then return nil end
			return cx + GROUP[member][1], cz + GROUP[member][2]
		end
		local function viable(sx, sz)
			local key = sz * 131072 + sx
			local v = viable_memo[key]
			if v ~= nil then return v end
			v = false
			if clear(sx, sz) then
				local h = hash(sx, sz, 7)
				local order = {}
				for a = 0, ATTEMPTS - 1 do
					order[#order + 1] = {(h + a) % POOL + 1, floor(h / POOL + a) % 4}
				end
				for r = 1, SMALLEST do
					for t = 0, 3 do order[#order + 1] = {smallest[r], t} end
				end
				for _, o in ipairs(order) do
					local writes = fit(pool[o[1]], o[2], sx, sz)
					if writes then
						local cells = {}
						for _, w in ipairs(writes) do
							cells[ckey(w[1], w[2], w[3])] = w[6] and 2 or 1
						end
						v = {x = sx, z = sz, writes = writes, cells = cells, priority = hash(sx, sz, 3)}
						break
					end
				end
			end
			viable_memo[key] = v
			return v
		end
		-- The viable slots whose stems lie in the world rectangle.
		local function slots_in(x0, x1, z0, z1)
			local list = {}
			local lx0, lx1 = x0 - anchor.x - 6, x1 - anchor.x + 6
			local lz0, lz1 = z0 - anchor.z - 6, z1 - anchor.z + 6
			for gz = floor(lz0 / GREEN_STEP) * GREEN_STEP, lz1, GREEN_STEP do
				for gx = floor(lx0 / GREEN_STEP) * GREEN_STEP, lx1, GREEN_STEP do
					for member = 1, #GROUP do
						local sx, sz = slot_at(gx, gz, member)
						if not sx then break end
						sx, sz = sx + anchor.x, sz + anchor.z
						if sx >= x0 and sx <= x1 and sz >= z0 and sz <= z1 then
							local v = viable(sx, sz)
							if v then list[#list + 1] = v end
						end
					end
				end
			end
			return list
		end

		local green = {}
		-- Every tree cell inside the world box, as {x, y, z, name, param2}.
		function green.cells(box)
			local out = {}
			local R = M.REACH
			local mine = slots_in(box.min_x - R, box.max_x + R, box.min_z - R, box.max_z + R)
			if #mine == 0 then return out end
			local around = slots_in(box.min_x - 3 * R, box.max_x + 3 * R,
				box.min_z - 3 * R, box.max_z + 3 * R)
			for _, s in ipairs(mine) do
				local neighbours = {}
				local dropped = false
				for _, o in ipairs(around) do
					if o ~= s and abs(o.x - s.x) <= 2 * R and abs(o.z - s.z) <= 2 * R then
						neighbours[#neighbours + 1] = o
						local higher = o.priority > s.priority or
							(o.priority == s.priority and (o.x < s.x or (o.x == s.x and o.z < s.z)))
						o.higher = higher
						if higher and abs(o.x - s.x) < SPACING and abs(o.z - s.z) < SPACING then
							dropped = true
						end
					end
				end
				if not dropped then
					for _, w in ipairs(s.writes) do
						if w[6] then
							for _, o in ipairs(neighbours) do
								if o.higher and o.cells[ckey(w[1], w[2], w[3])] == 2 then
									dropped = true
									break
								end
							end
							if dropped then break end
						end
					end
				end
				if not dropped then
					for _, w in ipairs(s.writes) do
						local x, y, z = w[1], w[2], w[3]
						if x >= box.min_x and x <= box.max_x and z >= box.min_z and z <= box.max_z then
							local write = true
							if not w[6] then
								local k = ckey(x, y, z)
								for _, o in ipairs(neighbours) do
									local c = o.cells[k]
									if c == 2 or (c == 1 and o.higher) then write = false break end
								end
							end
							if write then
								local cell = w[4]
								local name = name_of(cell.name)
								if name == own.fruit and wood_row.fruit ~= own.fruit then name = leaves end
								out[#out + 1] = {x = x, y = y, z = z, name = name,
									param2 = parts.rotate_param2(cell.param2,
										parts.param2_kind(name), w[5])}
							end
						end
					end
				end
			end
			return out
		end
		-- The trees whose stems lie in the world rectangle and are planted
		-- (for the counts of tools/r47_tc).
		function green.count(x0, x1, z0, z1)
			local n_planted = 0
			for _, s in ipairs(slots_in(x0, x1, z0, z1)) do
				local cells = green.cells({min_x = s.x, max_x = s.x, min_z = s.z, max_z = s.z})
				if #cells > 0 then n_planted = n_planted + 1 end
			end
			return n_planted
		end
		return green
	end
	return M
end

return loader
