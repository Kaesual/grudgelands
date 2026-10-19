-- WP13 exterior dressing: the props that fill the space between plots.
--
-- Everything here writes straight into the pad buffer in pad-local
-- coordinates, where y = 0 is the ground node and y = 1 the first walkable
-- course. Light producing props append to the caller's light list so the
-- blueprint can publish every light cell as a landmark.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- A straight run of fence posts.
	function M.fence_line(buf, palette, x1, z1, x2, z2)
		local name = palette.node("fence")
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				buf:put(x, 1, z, name)
			end
		end
	end

	-- A low masonry wall; `walls:cobble` is a connected nodebox, so it joins
	-- its neighbours at render time with no param2 and no update callback.
	function M.low_wall_line(buf, palette, x1, z1, x2, z2)
		local name = palette.node("low_wall")
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				buf:put(x, 1, z, name)
			end
		end
	end

	-- Stacked timber: two courses of logs under a sawn plank cap.
	function M.wood_pile(buf, palette, x, z, len, axis)
		for step = 0, len - 1 do
			local cx = axis == "z" and x or x + step
			local cz = axis == "z" and z + step or z
			buf:put(cx, 1, cz, palette.node("tree_log"))
			buf:put(cx, 2, cz, palette.node("tree_log"))
			buf:put(cx, 3, cz, palette.node("roof_slab"))
		end
	end

	-- A bench looking along `face`.
	function M.bench(buf, palette, x, z, face, len, axis)
		for step = 0, (len or 2) - 1 do
			local cx = (axis == "z") and x or x + step
			local cz = (axis == "z") and z + step or z
			parts.seat(buf, palette, cx, 1, cz, face)
		end
	end

	-- A raised planter: a masonry kerb around soil, planted with pad flora.
	function M.planter(buf, palette, x1, z1, x2, z2)
		for z = z1, z2 do
			for x = x1, x2 do
				if x == x1 or x == x2 or z == z1 or z == z2 then
					buf:put(x, 1, z, palette.node("planter"))
				else
					buf:put(x, 1, z, palette.node("planter_soil"))
					local role = ((x + z) % 3 == 0) and "fern" or "grass_tuft"
					local name = palette.node(role)
					buf:put(x, 2, z, name, parts.place_param2(name))
				end
			end
		end
	end

	-- A lamp post: a short log standard carrying a torch.
	function M.path_light(buf, palette, x, z, lights)
		buf:put(x, 1, z, palette.node("post"))
		buf:put(x, 2, z, palette.node("post"))
		parts.floor_torch(buf, palette, x, 3, z)
		if lights then lights[#lights + 1] = {x = x, y = 3, z = z} end
	end

	-- A lantern standard: a tall post with a cross arm, and the palette's
	-- hanging lamp under the arm. A race without `light_hanging` gets the
	-- ordinary path light instead, so the standard is never a dark post.
	function M.lantern_post(buf, palette, x, z, lights)
		if palette.maybe("light_hanging") == nil then
			return M.path_light(buf, palette, x, z, lights)
		end
		for y = 1, 5 do buf:put(x, y, z, palette.node("post")) end
		buf:put(x + 1, 5, z, palette.node("beam"))
		parts.hanging_light(buf, palette, x + 1, 4, z)
		if lights then lights[#lights + 1] = {x = x + 1, y = 4, z = z} end
	end

	-- A wayside lantern pillar: a masonry plinth, four corner posts, a band
	-- of glazing round a timber core, and the palette's glowing block behind
	-- the lower panes. Three by three, four courses; it is the one piece of
	-- the settlement whose windows are glazed on more than one face, so the
	-- panes of its upper band settle on the CONNECTED pane node rather than
	-- the flat one (`parts.resolve_panes`).
	--
	-- Degrades to a plain lamp post for a race with no `light_beacon`.
	function M.lantern_pillar(buf, palette, x, z, lights)
		if palette.maybe("light_beacon") == nil then
			return M.path_light(buf, palette, x, z, lights)
		end
		buf:fill(x - 1, 1, z - 1, x + 1, 1, z + 1, palette.node("plaza_edge"))
		for y = 2, 3 do
			for _, corner in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
				buf:put(x + corner[1], y, z + corner[2], palette.node("post"))
			end
			parts.pane(buf, palette, x, y, z - 1, "x")
			parts.pane(buf, palette, x, y, z + 1, "x")
			parts.pane(buf, palette, x - 1, y, z, "z")
			parts.pane(buf, palette, x + 1, y, z, "z")
		end
		parts.beacon(buf, palette, x, 2, z)
		if lights then lights[#lights + 1] = {x = x, y = 2, z = z} end
		buf:put(x, 3, z, palette.node("post"))
		buf:fill(x - 1, 4, z - 1, x + 1, 4, z + 1, palette.node("roof_slab"))
	end

	-- A crate stack: a barrel with a wool bale on top.
	function M.crates(buf, palette, x, z, face)
		buf:put(x, 1, z, palette.node("storage"), (face + 2) % 4)
		buf:put(x, 2, z, palette.node("rug"))
	end

	-- A dry draw well: masonry kerb, gravel shaft, timber frame and a lamp.
	function M.well(buf, palette, x, z, lights)
		for dz = -1, 1 do
			for dx = -1, 1 do
				if dx == 0 and dz == 0 then
					buf:put(x, 0, z, palette.node("rubble"))
					buf:clear(x, 1, z, x, 2, z)
				else
					buf:put(x + dx, 1, z + dz, palette.node("low_wall"))
				end
			end
		end
		for _, corner in ipairs({{-1, -1}, {1, 1}}) do
			buf:put(x + corner[1], 2, z + corner[2], palette.node("post"))
			buf:put(x + corner[1], 3, z + corner[2], palette.node("post"))
		end
		buf:fill(x - 1, 4, z - 1, x + 1, 4, z + 1, palette.node("roof_slab"))
		parts.wall_torch(buf, palette, x - 1, 3, z, 0, 0, -1)
		if lights then lights[#lights + 1] = {x = x - 1, y = 3, z = z} end
	end

	-- A market stall: four corner posts under a plank canopy, with a trestle
	-- counter and a crate of goods beneath it.
	function M.stall(buf, palette, x, z, face)
		for _, corner in ipairs({{0, 0}, {2, 0}, {0, 2}, {2, 2}}) do
			for y = 1, 3 do
				buf:put(x + corner[1], y, z + corner[2], palette.node("post"))
			end
		end
		buf:fill(x - 1, 4, z - 1, x + 3, 4, z + 3, palette.node("roof_slab"))
		for step = 0, 2 do
			buf:put(x + step, 1, z + 1, palette.node("table_leg"))
			buf:put(x + step, 2, z + 1, palette.node("table_top"))
		end
		buf:put(x + 1, 1, z, palette.node("storage"), (face + 2) % 4)
		buf:put(x + 1, 1, z + 2, palette.node("rug"))
	end

	-- A TRESTLE COUNTER: the shopfront of a profession house (playtest round
	-- 3). `M.stall` is the market square's four-poster booth with a canopy,
	-- which needs five nodes by five and overhangs them; a counter is the
	-- three or four nodes of trestle a butcher, a baker or a smith serves over
	-- and it stands in the two-node ring a plot leaves round its building.
	-- Waist high on purpose: the sockets contract's `stall` activity is "a
	-- counter (any solid node at waist height)", and waist height from a
	-- socket standing beside it is the socket's own feet course.
	function M.counter(buf, palette, x, z, len, axis)
		for step = 0, (len or 3) - 1 do
			local cx = (axis == "z") and x or x + step
			local cz = (axis == "z") and z + step or z
			buf:put(cx, 1, cz, palette.node("table_leg"))
			buf:put(cx, 2, cz, palette.node("table_top"))
		end
	end

	-- An inlaid band of a second paving material, one node wide.
	function M.inlay(buf, palette, x1, z1, x2, z2, role)
		local name = palette.node(role or "plaza_edge")
		for z = z1, z2 do
			for x = x1, x2 do
				if x == x1 or x == x2 or z == z1 or z == z2 then
					buf:put(x, 0, z, name)
				end
			end
		end
	end

	-- The waystone (Round 29, WP17): the travel node at the centre of every
	-- waypoint pad, six capitals and six starts. `grug_mapgen/world_nodes.lua`
	-- registers it before the settlement content is resolved; grug_home owns
	-- what a right-click does. It stands IN the waypoint socket's cell.
	M.WAYSTONE = "grug_mapgen:waystone"

	-- The mailbox (Round 48, mail plan ruling 1) stands on the same pad, so
	-- every pad that gets a waystone gets one and no other settlement does.
	-- One offset from the stone for all twelve pads: off the pad's cross arms
	-- (the ways to the stone stay free), not beside the stone (the arrival
	-- sides stay free), within reach of the waypoint socket (grug_mail names
	-- the mailbox after that settlement); facedir 1 turns its front to -x,
	-- toward the stone. A capital that cannot take it passes its own.
	M.MAILBOX = "grug_mapgen:mailbox"
	M.MAILBOX_OFFSET = {x = 2, z = 1, facedir = 1}

	function M.waystone(buf, x, z, mailbox)
		buf:put(x, 1, z, M.WAYSTONE)
		local m = mailbox or M.MAILBOX_OFFSET
		local mx, mz = x + m.x, z + m.z
		-- Open pad ground: nothing stands on the cell or hangs over it.
		local ground = buf:at(mx, 0, mz)
		local open = ground ~= nil and ground.name ~= "air"
		for y = 1, 2 do
			local cell = buf:at(mx, y, mz)
			if cell ~= nil and cell.name ~= "air" then open = false end
		end
		if not open then
			error("wp13: mailbox cell " .. mx .. "," .. mz .. " is not open pad ground", 0)
		end
		buf:put(mx, 1, mz, M.MAILBOX, m.facedir)
	end

	-- A start's waypoint pad: the capitals' pad (a signature-stone cross and
	-- the diamond round it, drawn into the ground course) at reach 3, the
	-- diamond's inside paved with the lane material, the waystone at the
	-- centre. Every cell must be open ground with headroom: a pad written
	-- over a prop or a wall is an authoring error, so it raises.
	function M.waypoint_pad(buf, palette, cx, cz, label)
		local REACH = 3
		local stone, path = palette.node("signature"), palette.node("path")
		for dz = -REACH, REACH do
			for dx = -REACH, REACH do
				local d = math.abs(dx) + math.abs(dz)
				if d <= REACH then
					local x, z = cx + dx, cz + dz
					local ground = buf:at(x, 0, z)
					local open = ground ~= nil and ground.name ~= "air"
					for y = 1, 3 do
						local cell = buf:at(x, y, z)
						if cell ~= nil and cell.name ~= "air" then open = false end
					end
					if not open then
						error("wp13 " .. label .. ": waypoint pad cell " .. x .. "," ..
							z .. " is not open ground", 0)
					end
					buf:put(x, 0, z, (dx == 0 or dz == 0 or d == REACH) and
						stone or path)
				end
			end
		end
		M.waystone(buf, cx, cz)
	end

	-- A notice post: a log standard with a sawn board.
	function M.signpost(buf, palette, x, z)
		buf:put(x, 1, z, palette.node("post"))
		buf:put(x, 2, z, palette.node("post"))
		buf:put(x, 3, z, palette.node("roof_slab"))
	end

	-- TREES (Round 47 lane TC, ruling 3; groves follow-up): every town tree
	-- is the seeded generator's (wp40/treegen.lua through
	-- wp40/tree_templates.lua), so a town's trees match the wild ones. The
	-- routine names the species (a pine, an apple, an aspen-like column, an
	-- acacia, a gravewood, a jungle tree, a kapok) and the palette names the
	-- wood: its `tree_log` picks the shape nodes of that wood and
	-- `tree_leaves` the foliage, so a palette of another wood still grows the
	-- routine's shape. Apples hang only on apple wood.
	--
	-- THE TOWN POOL: per species TREE_POOL trees of fixed town seeds (the
	-- same in every world and on every start, as every composition is),
	-- each in four quarter turns. A spot first tries TREE_ATTEMPTS pool
	-- entries chosen by a hash of its pad-local position, then, where room
	-- is tight, the TREE_SMALLEST narrowest entries (by footprint) in every
	-- turn, at the spot and one node beside it.
	--
	-- A candidate fits when every wood cell (trunk, limb, twig) stands over
	-- the composition's own ground (a ground cell at y = 0 under its column,
	-- the rule `layout.free` uses), below `top` (21 by default: a start's and
	-- a capital plot's authorized volume end at 24, and a plot clears two
	-- courses above its tallest cell; 40 for the kapok of a capital core),
	-- the trunk's foot on wild soil (never on a path or paving), and no wood
	-- cell on a built cell (one neither absent nor air) other than another
	-- town tree's leaf. A leaf off the ground, above the top or on a built
	-- cell is left out (a leaf never replaces anything; two crowns merge,
	-- the first leaf stays). So trees interleave their crowns, never their
	-- wood. A candidate is good when it leaves out at most a quarter of its
	-- leaves; the first good one is written, else the fitting one that
	-- leaves out the fewest, if that is at most half. Nothing fits: no tree,
	-- and the routine returns false (true when it planted). Roots test the
	-- pad's ground like the world's, run by run (wild soil under the column
	-- at the foot, none at the foot's level, a free cell).
	--
	-- `height` is the caller's old stem length and no longer read: the
	-- generator decides a tree's height.
	local TREE_POOL = 24
	local TREE_ATTEMPTS = 4
	local TREE_SMALLEST = 8
	local TREE_TOP = 21
	-- Two town trees' stems keep this many nodes apart (Chebyshev, strictly
	-- less refuses); a composition may set `buf.tree_spacing` lower (the
	-- capitals' dense groves: 3).
	local TREE_SPACING = 5
	local tree_module
	local function tree_templates()
		if not tree_module then
			local wp40 = directory .. "/../wp40"
			tree_module = dofile(wp40 .. "/tree_templates.lua")(
				dofile(wp40 .. "/treegen.lua"))
		end
		return tree_module
	end
	local SPECIES_SALT = {apple = 1, jungle = 2, kapok = 3, acacia = 4, pine = 5,
		aspen = 6, silverwood = 7, gravewood = 8}
	local function tree_seed(species, x, z, attempt)
		return ((x + 4096) * 73856093 + (z + 4096) * 19349663 +
			attempt * 83492791 + SPECIES_SALT[species] * 15485863) % 2147483646 - 1
	end

	-- The species' town pool: {cells (no roots), runs, area}, and the pool
	-- indices from the smallest footprint up.
	local pools = {}
	local function pool_of(species)
		local pool = pools[species]
		if pool then return pool end
		local trees = tree_templates()
		pool = {entries = {}, smallest = {}}
		for k = 1, TREE_POOL do
			local cells, tree = trees.tree(species, tree_seed(species, 0, 0, k))
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
			pool.entries[k] = {cells = body, runs = runs,
				area = tree.width * tree.depth, seed = k}
			pool.smallest[k] = k
		end
		table.sort(pool.smallest, function(a, b)
			local ea, eb = pool.entries[a], pool.entries[b]
			if ea.area ~= eb.area then return ea.area < eb.area end
			return a < b
		end)
		pools[species] = pool
		return pool
	end

	local function turn(x, z, turns)
		for _ = 1, turns do x, z = z, -x end
		return x, z
	end

	function M.grown(buf, palette, species, x, z, top)
		local trees = tree_templates()
		top = top or TREE_TOP
		local log, leaves = palette.node("tree_log"), palette.node("tree_leaves")
		-- the palette's wood: the species row whose trunk the palette logs are
		local wood
		for _, row in ipairs(trees.SPECIES) do
			if row.trunk == log then wood = row break end
		end
		if not wood then error("wp13 dressing: no tree wood for " .. log, 0) end
		local own = trees.BY_KEY[species]
		local function name_of(name)
			if name == own.trunk then return log
			elseif name == own.quarter then return wood.quarter
			elseif name == own.base then return wood.base
			elseif name == own.branch then return wood.branch
			elseif name == own.twig then return wood.twig
			elseif name == own.leaves then return leaves
			elseif name == own.fruit and wood.fruit ~= own.fruit then return leaves
			end
			return name
		end
		buf.grown_leaves = buf.grown_leaves or {}
		buf.grown_stems = buf.grown_stems or {}
		local grown_leaves = buf.grown_leaves
		local spacing = buf.tree_spacing or TREE_SPACING
		for _, stem in ipairs(buf.grown_stems) do
			if math.abs(stem[1] - x) < spacing and math.abs(stem[2] - z) < spacing then
				return false
			end
		end
		local function soil(bx, by, bz)
			local cell = buf:at(bx, by, bz)
			return cell ~= nil and parts.wild_soil(cell.name)
		end
		-- One candidate: the cells to write, the leaves left out and the
		-- leaves, or nil when its wood does not fit.
		local function try(entry, turns, sx, sz)
			local writes, skipped, leaf_count = {}, 0, 0
			for _, cell in ipairs(entry.cells) do
				local cx, cz = turn(cell.x, cell.z, turns)
				local bx, by, bz = sx + cx, cell.y + 1, sz + cz
				local ground = buf:at(bx, 0, bz)
				local at = buf:at(bx, by, bz)
				local built = at ~= nil and at.name ~= "air"
				if cell.flag == trees.LEAF then
					leaf_count = leaf_count + 1
					if ground == nil or ground.name == "air" or by > top or built then
						skipped = skipped + 1
					else
						writes[#writes + 1] = {bx, by, bz, cell, turns}
					end
				else
					if ground == nil or ground.name == "air" or by > top or
							(cell.y == 0 and not parts.wild_soil(ground.name)) or
							(built and not grown_leaves[bx .. ":" .. by .. ":" .. bz]) then
						return nil
					end
					writes[#writes + 1] = {bx, by, bz, cell, turns}
				end
			end
			-- roots, run by run, a fork only with its parent run
			local kept = {}
			for index, run in ipairs(entry.runs) do
				local ok = run.parent == 0 or kept[run.parent] == true
				for _, cell in ipairs(ok and run or {}) do
					local cx, cz = turn(cell.x, cell.z, turns)
					local bx, by, bz = sx + cx, cell.y + 1, sz + cz
					local at = buf:at(bx, by, bz)
					if not soil(bx, 0, bz) or soil(bx, 1, bz) or
							(at ~= nil and at.name ~= "air") then
						ok = false
						break
					end
				end
				kept[index] = ok
				if ok then
					for _, cell in ipairs(run) do
						local cx, cz = turn(cell.x, cell.z, turns)
						writes[#writes + 1] = {sx + cx, cell.y + 1, sz + cz, cell, turns}
					end
				end
			end
			return writes, skipped, leaf_count
		end
		local pool = pool_of(species)
		local hash = tree_seed(species, x, z, 0) + 1
		local candidates = {}
		for attempt = 0, TREE_ATTEMPTS - 1 do
			candidates[#candidates + 1] = {(hash + attempt) % TREE_POOL + 1,
				(math.floor(hash / TREE_POOL) + attempt) % 4, 0, 0}
		end
		for _, offset in ipairs({{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			for rank = 1, TREE_SMALLEST do
				for turns = 0, 3 do
					candidates[#candidates + 1] = {pool.smallest[rank], turns,
						offset[1], offset[2]}
				end
			end
		end
		local best, best_skipped
		for _, candidate in ipairs(candidates) do
			local writes, skipped, leaf_count = try(pool.entries[candidate[1]],
				candidate[2], x + candidate[3], z + candidate[4])
			if writes then
				if skipped * 4 <= leaf_count then best = writes break end
				if skipped * 2 <= leaf_count and (not best or skipped < best_skipped) then
					best, best_skipped = writes, skipped
				end
			end
		end
		if not best then return false end
		buf.grown_stems[#buf.grown_stems + 1] = {x, z}
		-- Every write is recorded with what it replaced, so a tree a later
		-- write cuts goes out whole (parts.lua `Buffer:cells`).
		buf.grown_trees = buf.grown_trees or {}
		buf.grown_wood = buf.grown_wood or {}
		local tree = {writes = {}, species = species, x = x, z = z}
		buf.grown_trees[#buf.grown_trees + 1] = tree
		local id = #buf.grown_trees
		buf.writing_tree = true
		for _, write in ipairs(best) do
			local bx, by, bz, cell, turns = write[1], write[2], write[3], write[4], write[5]
			local name = name_of(cell.name)
			local param2 = parts.rotate_param2(cell.param2, parts.param2_kind(name), turns)
			local key = bx .. ":" .. by .. ":" .. bz
			local old = buf:at(bx, by, bz)
			tree.writes[#tree.writes + 1] = {key = key, name = name,
				prev_name = old and old.name, prev_param2 = old and old.param2,
				wood = cell.flag ~= trees.LEAF}
			buf:put(bx, by, bz, name, param2)
			grown_leaves[key] = cell.flag == trees.LEAF and true or nil
			buf.grown_wood[key] = cell.flag ~= trees.LEAF and id or nil
		end
		buf.writing_tree = nil
		return true
	end

	-- The routines the settlements call, one per species.
	function M.tree(buf, palette, x, z) return M.grown(buf, palette, "pine", x, z) end
	function M.broadleaf(buf, palette, x, z) return M.grown(buf, palette, "apple", x, z) end
	function M.columnar(buf, palette, x, z)
		local species = palette.node("tree_log") == "default:aspen_tree" and "aspen" or
			"silverwood"
		return M.grown(buf, palette, species, x, z)
	end
	function M.acacia(buf, palette, x, z) return M.grown(buf, palette, "acacia", x, z) end
	function M.gravewood(buf, palette, x, z) return M.grown(buf, palette, "gravewood", x, z) end
	function M.jungle_tree(buf, palette, x, z) return M.grown(buf, palette, "jungle", x, z) end
	-- The kapok: a capital core's authorized volume reaches 40 (the default
	-- here), a start's 24 (`top`).
	function M.emergent(buf, palette, x, z, _, top)
		return M.grown(buf, palette, "kapok", x, z, top or 40)
	end


	-- A raised terrace: a masonry podium `height` nodes tall with a flight of
	-- steps up its `side` ("z-", "z+", "x-" or "x+"), three treads wide and
	-- centred on that side. The podium top is the caller's building pad, so
	-- a building stamped at y = height stands on it with its own apron.
	function M.terrace(buf, palette, x1, z1, x2, z2, height, side)
		buf:fill(x1, 1, z1, x2, height, z2, palette.node("plaza"))
		buf:clear(x1, height + 1, z1, x2, height + 4, z2)
		local along_x = (side == "z-" or side == "z+")
		local centre = along_x and math.floor((x1 + x2) / 2)
			or math.floor((z1 + z2) / 2)
		local face, edge
		if side == "z-" then face, edge = 0, z1
		elseif side == "z+" then face, edge = 2, z2
		elseif side == "x-" then face, edge = 1, x1
		else face, edge = 3, x2 end
		local outward = (side == "z-" or side == "x-") and -1 or 1
		for tread = 1, height - 1 do
			local step = edge + outward * (height - tread)
			for offset = -1, 1 do
				local sx = along_x and (centre + offset) or step
				local sz = along_x and step or (centre + offset)
				for y = 1, tread - 1 do
					buf:put(sx, y, sz, palette.node("plaza"))
				end
				parts.stair(buf, sx, tread, sz, palette.node("roof_stair"), face)
			end
		end
	end

	-- A hedgerow: a woody stem course with a leafy crown above it, so a field
	-- boundary reads as a hedge and not as a green wall. Degrades to nothing
	-- when the palette carries no hedge.
	function M.hedge_line(buf, palette, x1, z1, x2, z2, height)
		local leaves = palette.maybe("hedge")
		if leaves == nil then return 0 end
		local stem = palette.maybe("hedge_stem") or leaves
		local top = height or 2
		local planted = 0
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				buf:put(x, 1, z, stem)
				for y = 2, top do
					buf:put(x, y, z, leaves)
				end
				planted = planted + 1
			end
		end
		return planted
	end

	-- A tilled field: bare furrows with a planted row between every pair, and
	-- a headland of open soil all round so the fence has somewhere to stand.
	-- Both courses of a field are the SAME node when the race binds
	-- `crop_soil`. The first version ploughed the bare furrows out of
	-- `ground_patch` and bedded the planted rows in `planter_soil`, which for
	-- the human palette are `default:dirt` and `default:dirt_with_grass`: the
	-- bare rows are the one and only nodename default's "Grass spread" ABM
	-- acts on, so every lit furrow turned into the grass beside it and the
	-- hamlet's fields became lawn -- a defect no construction-time fixture
	-- can see, because the blueprint it checks is still correct. A race that
	-- binds `crop_soil` gets a node that ABM cannot reach; the stripe the two
	-- materials used to draw is carried by the crop rows themselves.
	function M.crop_rows(buf, palette, x1, z1, x2, z2, axis)
		local tilled = palette.maybe("crop_soil")
		local furrow = tilled or palette.node("ground_patch")
		local soil = tilled or palette.node("planter_soil")
		local crop = palette.maybe("crop")
		local rows = 0
		for z = z1, z2 do
			for x = x1, x2 do
				local along = (axis == "z") and x or z
				local planted = (along - ((axis == "z") and x1 or z1)) % 2 == 1
				buf:put(x, 0, z, planted and soil or furrow)
				buf:clear(x, 1, z, x, 2, z)
				if planted and crop then
					buf:put(x, 1, z, crop)
					rows = rows + 1
				end
			end
		end
		return rows
	end

	-- A stack of straw bales.
	function M.bale_stack(buf, palette, x, z, height)
		local bale = palette.maybe("bale")
		if bale == nil then return false end
		for y = 1, height do buf:put(x, y, z, bale) end
		return true
	end

	-- A hand cart: two log bearers, a wheel leaning on the outer face of each,
	-- and the barrel the cart carries riding on the far bearer. Returns false
	-- when a wheel or the barrel could not be placed, so a caller can refuse
	-- to keep half a cart instead of losing the rest silently.
	function M.handcart(buf, palette, x, z, axis)
		local log = palette.node("tree_log")
		local ax = (axis == "x") and 1 or 0
		local az = (axis == "x") and 0 or 1
		for step = 0, 1 do
			buf:put(x + ax * step, 1, z + az * step, log)
		end
		-- The wheels hang on the outer face of the bearers, which are logs and
		-- therefore opaque full cubes.
		local whole = true
		for step = 0, 1 do
			local wx, wz = x + ax * step - az, z + az * step - ax
			if not parts.wall_prop(buf, palette, "wheel", wx, 1, wz, az, 0, ax) then
				whole = false
			end
		end
		-- The barrel rides ON the far bearer, at `(x + ax, z + az)`. The
		-- diagonal `(x + ax + az, z + az + ax)` is `(x + 1, z + 1)` on BOTH
		-- axes, which is a cell off the cart, so the barrel floated there.
		-- Guarded the way `parts.wall_prop` guards its props: the bearer under
		-- it must be solid and the cell itself must be free.
		local bx, bz = x + ax, z + az
		local above = buf:at(bx, 2, bz)
		if parts.solid_at(buf, bx, 1, bz) and
				(above == nil or above.name == "air") then
			buf:put(bx, 2, bz, palette.node("storage"), 0)
		else
			whole = false
		end
		return whole
	end

	-- Stepping stones laid over open ground, one node wide.
	function M.stepping_line(buf, palette, x1, z1, x2, z2)
		local name = palette.maybe("stepping")
		if name == nil then return 0 end
		local laid = 0
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				local below = buf:at(x, 0, z)
				local here = buf:at(x, 1, z)
				if below and below.name ~= "air" and
						(here == nil or here.name == "air") then
					buf:put(x, 1, z, name, (x + z) % 4)
					laid = laid + 1
				end
			end
		end
		return laid
	end

	-- A flower bed: the same masonry kerb as `planter`, sown with pot plants
	-- instead of tufts where the palette has them.
	function M.flower_bed(buf, palette, x1, z1, x2, z2)
		local first = palette.maybe("flower")
		local second = palette.maybe("flower_alt") or first
		for z = z1, z2 do
			for x = x1, x2 do
				if x == x1 or x == x2 or z == z1 or z == z2 then
					buf:put(x, 1, z, palette.node("planter"))
				else
					buf:put(x, 1, z, palette.node("planter_soil"))
					if first then
						buf:put(x, 2, z, ((x + z) % 2 == 0) and first or second)
					else
						buf:put(x, 2, z, palette.node("grass_tuft"))
					end
				end
			end
		end
	end

	-- ONE PLANT, ON THE GROUND, WHERE SOMEBODY CAN REACH IT.
	--
	-- A raised bed is a kerb of masonry round soil, and the sockets contract
	-- (section 8.1, 2026-09-15) says a work socket's feature search stops at
	-- the first solid node on its own course -- so a gardener standing outside
	-- a bed looks at brick, and the flowers two cells further in do not count.
	-- That is the right rule (a feature behind a wall is not a feature) and the
	-- answer is not to weaken it but to put the plant where the hands are: this
	-- breaks the kerb at one cell and grows something there instead.
	--
	-- Returns the node it wrote, so a caller can say which cell the socket is
	-- for.
	function M.plant(buf, palette, x, z)
		local name = palette.maybe("flower") or palette.maybe("crop") or
			palette.node("grass_tuft")
		buf:put(x, 1, z, name, parts.place_param2(name))
		return name
	end

	-- The gravestone blocks (Round 51 lane LK, land plan ruling 12; the land
	-- viewer's "town graveyard"): every town's graves, the wild graveyards'
	-- too. They drop cobblestone.
	M.GRAVESTONE = "grug_nodes:gravestone_stele"
	M.GRAVESTONE_CROSS = "grug_nodes:gravestone_cross"

	-- A grave: a flagstone laid in the ground with a gravestone on it, its
	-- face to the front (-z) of the composition. `tall` crowns the stone
	-- with the cross, which is what the older half of a burial ground
	-- looks like next to the newer.
	function M.grave(buf, palette, x, z, tall)
		buf:put(x, 0, z, palette.node("path"))
		buf:put(x, 1, z, M.GRAVESTONE, 0)
		if tall then buf:put(x, 2, z, M.GRAVESTONE_CROSS, 0) end
	end

	-- The skeleton set (Round 51 lane LK, land plan rulings 8-9): what lies
	-- where a town's flora or a lair puts bones. Mostly the scattered long
	-- bones (`grug_nodes:bone_pile`, the set's piece under the old name) and
	-- splinters, now and then a skull, a ribcage or an animal's skull or
	-- spine; the piece and its quarter turn come from a hash of the cell,
	-- so neighbours differ. Returns the node and its param2.
	local BONE_PIECES = {"grug_nodes:skull_human", "grug_nodes:ribcage_human",
		"grug_nodes:skull_horned", "grug_nodes:spine_animal",
		"grug_nodes:bones_fragments", "grug_nodes:bones_fragments"}
	M.BONES = "grug_nodes:bone_pile"
	function M.bone_piece(x, z)
		local hash = (x * 113 + z * 197 + x * z * 5 + 4099) % 16
		local turn = (x * 7 + z * 13 + 1024) % 4
		if hash == 2 then
			return BONE_PIECES[3 + (x + z + 1024) % 2], turn
		elseif hash < 2 then
			return BONE_PIECES[hash + 1], turn
		elseif hash < 5 then
			return BONE_PIECES[5], turn
		end
		return M.BONES, turn
	end
	-- Put the palette's undergrowth at (x, y, z); where that is the bone
	-- pile, a piece of the skeleton set instead.
	function M.undergrowth_at(buf, palette, x, y, z)
		local name = palette.node("undergrowth")
		if name == M.BONES then
			local piece, turn = M.bone_piece(x, z)
			buf:put(x, y, z, piece, turn)
		else
			buf:put(x, y, z, name)
		end
	end

	-- A burial ground: rows of graves two nodes apart, with the odd plot
	-- left open and a bone pile or a dry shrub where one has sunk. Returns
	-- the number of markers set.
	function M.graveyard(buf, palette, x1, z1, x2, z2)
		local set = 0
		for z = z1, z2, 2 do
			for x = x1, x2, 2 do
				local hash = (x * 29 + z * 61) % 11
				local below = buf:at(x, 0, z)
				local above = buf:at(x, 1, z)
				if below and below.name ~= "air" and
						(above == nil or above.name == "air") and hash ~= 3 then
					if hash == 7 then
						M.undergrowth_at(buf, palette, x, 1, z)
					else
						M.grave(buf, palette, x, z, hash % 4 == 0)
						set = set + 1
					end
				end
			end
		end
		return set
	end

	-- A POND: the town water of playtest round 3, dug into the plot's own
	-- ground course and LINED on five sides, so it is a pond and not a leak.
	--
	-- The plot under it has already laid `ground` at y = 0 and `subsoil` at
	-- y = -1 over its whole rectangle; everything below that is untouched
	-- terrain, and on a terraced envelope "untouched terrain" is not a promise
	-- of solid rock at a given depth. So the basin writes its own floor and its
	-- own walls rather than trusting the ground: the ring one node outside the
	-- water is carried down as subsoil, and the floor under it is subsoil too.
	-- The water then stands three courses deep with its surface flush with the
	-- grass, which is what a pond in a meadow looks like.
	--
	-- THE SHAPE IS AN OCTAGON, not the rectangle it is given. A rectangular
	-- basin with square corners reads as a tank; cutting the four corners back
	-- by a few cells is the cheapest thing that makes a body of water read as a
	-- pond, and it costs nothing but the cells it does not write. The cut is a
	-- quarter of the shorter side, capped at three, so a small garden pool and a
	-- village pond get the same silhouette at their own sizes.
	--
	-- The liner follows the SHAPE and not the rectangle: every column that is
	-- not water but touches water on one of its eight neighbours is carried
	-- down, which is what keeps the cut corners lined too.
	--
	-- Returns the number of water cells, or 0 when the palette binds no water.
	function M.pond(buf, palette, x1, z1, x2, z2, depth)
		local water = palette.maybe("water")
		if water == nil then return 0 end
		depth = depth or 3
		local subsoil = palette.node("subsoil")
		local shore = palette.maybe("ground_bare") or subsoil
		local floor = -depth
		local cut = math.floor(math.min(x2 - x1 + 1, z2 - z1 + 1) / 4)
		if cut > 3 then cut = 3 end
		local function wet(x, z)
			if x < x1 or x > x2 or z < z1 or z > z2 then return false end
			local ex = math.min(x - x1, x2 - x)
			local ez = math.min(z - z1, z2 - z)
			return ex + ez >= cut
		end
		for z = z1 - 1, z2 + 1 do
			for x = x1 - 1, x2 + 1 do
				if wet(x, z) then
					buf:put(x, floor - 1, z, subsoil)
				else
					local touches = false
					for dz = -1, 1 do
						for dx = -1, 1 do
							if wet(x + dx, z + dz) then touches = true end
						end
					end
					if touches then
						for y = -1, floor - 1, -1 do
							buf:put(x, y, z, subsoil)
						end
						buf:put(x, 0, z, shore)
					end
				end
			end
		end
		local filled = 0
		for z = z1, z2 do
			for x = x1, x2 do
				if wet(x, z) then
					for y = floor, 0 do
						buf:put(x, y, z, water)
						filled = filled + 1
					end
				end
			end
		end
		return filled
	end

	-- A cobweb in a corner nobody sweeps. `grug_decor:xdecor_cobweb` is a
	-- free plantlike with no `attached_node` group and no paramtype2, so it
	-- needs neither support nor an orientation -- unlike the ivy below.
	-- Returns false and writes nothing when the cell is taken or the palette
	-- carries no cobweb.
	function M.cobweb(buf, palette, x, y, z)
		local name = palette.maybe("cobweb")
		if name == nil then return false end
		local here = buf:at(x, y, z)
		if here ~= nil and here.name ~= "air" then return false end
		buf:put(x, y, z, name)
		return true
	end

	-- Ivy climbing the inner face of a standing wall. It is a wallmounted
	-- `signlike`, so `parts.wall_prop` places it and refuses any face that is
	-- not an opaque full node.
	function M.ivy(buf, palette, x, y, z, dx, dz)
		return parts.wall_prop(buf, palette, "ivy", x, y, z, dx, 0, dz)
	end

	-- A heap of fallen masonry, one to three courses.
	function M.rubble_heap(buf, palette, x, z, height)
		local name = palette.node("rubble")
		for y = 1, height do buf:put(x, y, z, name) end
	end

	-- The blight's own ground cover.
	--
	-- `M.undergrowth` below cannot serve here, and not only because a blight
	-- basin wants different proportions: its selector `(7x + 11z) % density`
	-- and its role test `(x + z) % 4` are not independent -- 7x + 11z is
	-- 3(x + z) modulo 4 -- so at density 4 every cell it picks takes the
	-- `undergrowth` branch and the `grass_tuft` branch is never reached. In a
	-- pine wood or a meadow that shows up as a slightly monotonous flora; in
	-- the Hollow it carpeted the whole pad with bone piles. The two existing
	-- settlements are byte-frozen, so that routine is left exactly as it is
	-- and the Hollow scatters its own.
	--
	-- One hash, three bands: `bones` cells in `modulus` get a bone pile,
	-- the next `shrubs` a dead shrub, the rest nothing. Only unbuilt soil is
	-- sown. Returns the two populations.
	function M.blight_flora(buf, palette, x1, z1, x2, z2, modulus, bones, shrubs)
		local bone = palette.node("undergrowth")
		local shrub = palette.node("grass_tuft")
		local sown_bones, sown_shrubs = 0, 0
		for z = z1, z2 do
			for x = x1, x2 do
				local hash = (x * 89 + z * 151 + x * z * 7) % modulus
				local name
				if hash < bones then name = bone
				elseif hash < bones + shrubs then name = shrub end
				if name then
					local below = buf:at(x, 0, z)
					local above = buf:at(x, 1, z)
					if below and parts.wild_soil(below.name) and
							(above == nil or above.name == "air") then
						if name == bone then M.undergrowth_at(buf, palette, x, 1, z)
						else buf:put(x, 1, z, name) end
						if name == bone then sown_bones = sown_bones + 1
						else sown_shrubs = sown_shrubs + 1 end
					end
				end
			end
		end
		return sown_bones, sown_shrubs
	end

	-- A totem post: stacked logs banded with the palette's accent stone under
	-- a carved cap. The gate of a troll village is two of these and nothing
	-- else, so the post has to read as made rather than grown.
	function M.totem(buf, palette, x, z, height)
		local log = palette.node("post")
		local accent = palette.node("plaza_edge")
		for y = 1, height do
			buf:put(x, y, z, (y % 3 == 0) and accent or log)
		end
		buf:put(x, height + 1, z, palette.node("roof_slab"))
	end

	-- A drying rack: two posts carrying a beam, with rope lines hanging off
	-- it. Degrades to the bare frame when the palette has no rope.
	function M.drying_rack(buf, palette, x, z, len, axis)
		local ax = (axis == "x") and 1 or 0
		local az = 1 - ax
		for y = 1, 3 do
			buf:put(x, y, z, palette.node("post"))
			buf:put(x + ax * (len - 1), y, z + az * (len - 1),
				palette.node("post"))
		end
		for step = 0, len - 1 do
			buf:put(x + ax * step, 4, z + az * step, palette.node("beam"))
		end
		local rope = palette.maybe("rope")
		if rope == nil then return 0 end
		local hung = 0
		for step = 1, len - 2 do
			if step % 2 == 1 then
				for y = 2, 3 do
					buf:put(x + ax * step, y, z + az * step, rope)
					hung = hung + 1
				end
			end
		end
		return hung
	end

	-- Rope falling from the underside of a deck, as far as the first
	-- obstruction or `length` cells, whichever comes first. The cell above
	-- must be a solid node: a rope tied to nothing is a rope in mid air.
	function M.rope_fall(buf, palette, x, y, z, length)
		local rope = palette.maybe("rope")
		if rope == nil or not parts.solid_at(buf, x, y + 1, z) then return 0 end
		local hung = 0
		for step = 0, length - 1 do
			local cell = buf:at(x, y - step, z)
			if cell ~= nil and cell.name ~= "air" then break end
			buf:put(x, y - step, z, rope)
			hung = hung + 1
		end
		return hung
	end

	-- A lantern hung under a solid node. The palette's `lantern` must be in
	-- `group:attached_node = 4` -- rating 4 is "always attach to ceiling"
	-- (reference_projects/luanti/builtin/game/falling.lua:391-399) -- so the
	-- support test looks UP. Rating 3, which the troll palette bound first,
	-- is the opposite: "always attach to floor", and every lantern hung here
	-- would have been dropped as an item on the first node update near it.
	function M.lantern(buf, palette, x, y, z)
		local name = palette.maybe("lantern")
		if name == nil or not parts.solid_at(buf, x, y + 1, z) then
			return false
		end
		local here = buf:at(x, y, z)
		if here ~= nil and here.name ~= "air" then return false end
		buf:put(x, y, z, name)
		return true
	end

	-- A raised plank walkway at height `y`, three cells wide, running `len`
	-- cells along `axis` from (x, z), with railings down both flanks and log
	-- piers under it every third cell. The two end cells of each flank stay
	-- open so the walk can step on and off the bridge.
	--
	-- `pier(x, z)` may refuse a pier: a bridge that flies over the five-wide
	-- main route has to clear it, and a post in the middle of the road is
	-- exactly what the route invariant forbids.
	function M.walkway(buf, palette, x, z, len, axis, y, pier)
		local ax = (axis == "x") and 1 or 0
		local az = 1 - ax
		local deck = palette.node("path")
		local rail = palette.node("railing")
		local post = palette.node("post")
		for step = 0, len - 1 do
			for side = -1, 1 do
				local cx = x + ax * step + az * side
				local cz = z + az * step + ax * side
				buf:clear(cx, y, cz, cx, y + 3, cz)
				buf:put(cx, y, cz, deck)
				if side ~= 0 and step > 1 and step < len - 2 then
					buf:put(cx, y + 1, cz, rail)
				end
			end
			local cx, cz = x + ax * step, z + az * step
			if step % 3 == 0 and (pier == nil or pier(cx, cz)) then
				for py = 1, y - 1 do
					local cell = buf:at(cx, py, cz)
					if cell == nil or cell.name == "air" then
						buf:put(cx, py, cz, post)
					end
				end
			end
		end
	end

	-- A free-standing flight up to a deck. (x, z) is the deck's own edge
	-- cell and (ax, az) the direction of ascent, so the highest tread lands
	-- immediately before the deck and the lowest on the pad.
	function M.stair_up(buf, palette, x, z, top, axis, sign)
		local ax = (axis == "x") and sign or 0
		local az = (axis == "z") and sign or 0
		local tread = palette.node("roof_stair")
		local face = parts.step_facedir(ax, az)
		for run = 1, top - 1 do
			local back = top - run
			local cx, cz = x - ax * back, z - az * back
			buf:clear(cx, run, cz, cx, run + 3, cz)
			for y = 1, run - 1 do
				buf:put(cx, y, cz, palette.node("post"))
			end
			parts.stair(buf, cx, run, cz, tread, face)
		end
	end

	-- Basin flora: clumps of undergrowth, fern and tuft on the open litter.
	--
	-- `M.undergrowth` below scatters one plant per cell on a modulo test, and
	-- on a 127-node jungle floor that lays a diagonal lattice which reads as
	-- green stripes from above -- which is exactly what the first Kapok
	-- overview showed. This seeds clump CENTRES on a coarse lattice and fills
	-- a small ragged blob around each, so the floor reads as vegetation and
	-- not as a pattern.
	function M.basin_flora(buf, palette, x1, z1, x2, z2)
		local planted = 0
		for z = z1 + 2, z2 - 2, 3 do
			for x = x1 + 2, x2 - 2, 3 do
				local hash = (x * 131 + z * 197 + x * z * 7) % 61
				if hash < 34 then
					local reach = (hash % 5 == 0) and 2 or 1
					local role = (hash % 3 == 0) and "undergrowth"
						or ((hash % 3 == 1) and "fern" or "grass_tuft")
					local name = palette.node(role)
					for dz = -reach, reach do
						for dx = -reach, reach do
							if math.abs(dx) + math.abs(dz) <= reach and
									(hash + dx * 3 + dz * 5) % 4 ~= 0 then
								local cx, cz = x + dx, z + dz
								local below = buf:at(cx, 0, cz)
								local above = buf:at(cx, 1, cz)
								if below ~= nil and parts.wild_soil(below.name) and
										(above == nil or above.name == "air") then
									buf:put(cx, 1, cz, name)
									planted = planted + 1
								end
							end
						end
					end
				end
			end
		end
		return planted
	end

	-- A parapet on a finished flat roof deck: a continuous breastwork course
	-- on the wall line with merlons standing one course above it every
	-- `step` cells. The deck under it is already a slab, so the breastwork
	-- lands on a bearing all the way round, and the crenels between the
	-- merlons are what a fighting platform is looked over.
	--
	-- `y` is the course the breastwork STANDS ON, one above the deck slab
	-- `roofs.flat_deck` laid, so the deck stays continuous underneath it.
	-- `caps`, when given, collects the position of every merlon this ring
	-- raised. The return value is the ring's own cell count, which is NOT the
	-- merlon population -- the first version published it as one, and the
	-- composition cuts parts of two rings away afterwards, so the number in
	-- the landmark was neither the merlons nor the merlons that survived.
	-- A caller that wants the population counts the caps that are still there
	-- once the clears are done.
	function M.parapet(buf, palette, x1, z1, x2, z2, y, step, caps)
		local wall = palette.node("low_wall")
		local merlon = palette.node("wall_accent")
		step = step or 2
		local placed = 0
		for z = z1, z2 do
			for x = x1, x2 do
				if x == x1 or x == x2 or z == z1 or z == z2 then
					buf:put(x, y, z, wall)
					if (x + z) % step == 0 then
						buf:put(x, y + 1, z, merlon)
						if caps then
							caps[#caps + 1] = {x = x, y = y + 1, z = z}
						end
					end
					placed = placed + 1
				end
			end
		end
		return placed
	end

	-- An external stair run climbing `steps` courses beside a wall, from the
	-- ground course upward along `axis`. Each tread is a stair node on a
	-- solid riser, so the whole flight is walkable and reads as masonry
	-- rather than as a ladder.
	function M.outer_stair(buf, palette, x, z, steps, axis, face)
		local riser = palette.node("wall_accent")
		local tread = palette.node("roof_stair")
		local ax = (axis == "x") and 1 or 0
		local az = (axis == "x") and 0 or 1
		for step = 0, steps - 1 do
			local sx, sz = x + ax * step, z + az * step
			for y = 1, step do
				buf:put(sx, y, sz, riser)
			end
			parts.stair(buf, sx, step + 1, sz, tread, face)
		end
		return steps
	end

	-- A stake palisade: a run of logs with a sharpened crest. The point is an
	-- outer stair, whose single raised quarter is exactly a stake cut to a
	-- point, and the quarter alternates along the run so the crest reads as
	-- hewn timber and not as a moulding.
	-- A stake's point is sharpened wood, not masonry. The first version
	-- capped every stake with `roof_stair_outer`, which in the orc palette is
	-- `stairs:stair_outer_desert_stonebrick`: a stone point balanced on a log.
	-- A palette that names `stake_cap` gets the timber point it asks for and
	-- one that does not falls back to its roof family, so the role stays
	-- optional.
	function M.palisade(buf, palette, x1, z1, x2, z2, height)
		local log = palette.node("tree_log")
		local point = palette.maybe("stake_cap") or
			palette.node("roof_stair_outer")
		local top = height or 4
		local stakes = 0
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				for y = 1, top do buf:put(x, y, z, log) end
				buf:put(x, top + 1, z, point, (x + z) % 4)
				stakes = stakes + 1
			end
		end
		return stakes
	end

	-- A siege earthwork: a bank of subsoil with a beaten crest, thrown up
	-- around the camp. `height` is the crest course; the bank's sides are its
	-- own material, so it reads as dug earth rather than as a wall.
	function M.berm(buf, palette, x1, z1, x2, z2, height)
		local earth = palette.node("subsoil")
		local crest = palette.node("ground_bare")
		local raised = 0
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				for y = 1, height - 1 do buf:put(x, y, z, earth) end
				buf:put(x, height, z, crest)
				raised = raised + 1
			end
		end
		return raised
	end

	-- One terrace of a rock shelf: the foot of a mesa, filled solid to
	-- `height` in the palette's own masonry and capped with its own ground,
	-- so the top of the bluff reads as the same country carried up and its
	-- faces as bare rock. Stacking a few, each stepped back from the last,
	-- gives an eroded bluff instead of a wall, and nothing grows on it,
	-- because every column below the cap is rock and no planting rule will
	-- take it.
	function M.rock_terrace(buf, palette, x1, z1, x2, z2, height)
		local rock = palette.node("foundation")
		local scree = palette.node("ground")
		local cells = 0
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				for y = 1, height - 1 do buf:put(x, y, z, rock) end
				buf:put(x, height, z, scree)
				cells = cells + 1
			end
		end
		return cells
	end

	-- A war standard: a log pole carrying a cloth block and a torch above it,
	-- so the camp's banners are also its beacons. Nothing here is a spawner
	-- node: the cloth is `wool`, the light an ordinary torch.
	-- No `lights` parameter: this settlement's light landmarks are read off
	-- the finished cell list by node name, so a second, hand-kept list would
	-- be a second source of truth for the same fact. Both callers passed
	-- nothing and the parameter was dead.
	function M.standard(buf, palette, x, z, height)
		local pole = palette.node("post")
		for y = 1, height do buf:put(x, y, z, pole) end
		buf:put(x, height + 1, z, palette.node("rug_accent"))
		parts.floor_torch(buf, palette, x, height + 2, z)
	end

	-- A drill post: a sunk log with a cross beam and a straw head, which is
	-- what a training yard is full of.
	function M.drill_post(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local top = height or 3
		for y = 1, top do buf:put(x, y, z, log) end
		local head = palette.maybe("bale") or palette.node("rug")
		buf:put(x, top + 1, z, head)
		return true
	end

	-- A loaded wagon: two log bearers, a load between them and a wheel
	-- leaning on each bearer. Degrades to the bare bearers when the palette
	-- carries neither a load nor a wheel.
	function M.wagon(buf, palette, x, z, axis)
		local log = palette.node("tree_log")
		local ax = (axis == "x") and 1 or 0
		local az = (axis == "x") and 0 or 1
		for step = 0, 2 do
			buf:put(x + ax * step, 1, z + az * step, log)
		end
		local load = palette.maybe("cargo")
		local whole = true
		for step = 0, 2 do
			local wx, wz = x + ax * step - az, z + az * step - ax
			if not parts.wall_prop(buf, palette, "wheel", wx, 1, wz,
					az, 0, ax) then
				whole = false
			end
			if load then
				-- The load rides ON its bearer, never beside it, and only
				-- into a free cell, so a wagon that shares a cell with
				-- something else is refused rather than half built.
				local lx, lz = x + ax * step, z + az * step
				local above = buf:at(lx, 2, lz)
				if above == nil or above.name == "air" then
					buf:put(lx, 2, lz, load, parts.step_facedir(az, ax))
				else
					whole = false
				end
			end
		end
		return whole
	end

	-- Scattered ground cover on a rectangle of open ground: one plant per
	-- cell the selector picks, either the palette's bushy `undergrowth` or
	-- its finer `grass_tuft`, and only on unbuilt soil with air above it.
	--
	-- The selector and the role test MUST be independent, and the first
	-- version's were not. It picked on `(7x + 11z) % density` and chose the
	-- role on `(x + z) % 4`, and `7x + 11z` IS `3(x + z)` modulo 4: at
	-- density 4 every picked cell satisfied the role test as well, so
	-- `grass_tuft` was unreachable and Dawnmere's green came out carpeted in
	-- bushes. Densities 5 and 6 escaped by being coprime to 4, which is luck,
	-- not design. Both tests now read two different offsets into
	-- `parts.position_hash`, whose two LCG rounds leave neither derivable
	-- from the other. The WP13 library KAT (retired in Round 22)
	-- asserted that every start emits both of its ground-cover nodes.
	function M.undergrowth(buf, palette, x1, z1, x2, z2, density)
		local planted_bush, planted_tuft = 0, 0
		for z = z1, z2 do
			for x = x1, x2 do
				if parts.position_hash(x, z) % density == 0 then
					local below = buf:at(x, 0, z)
					local above = buf:at(x, 1, z)
					local free = (above == nil or above.name == "air")
					if below and free and parts.wild_soil(below.name) then
						local bush =
							parts.position_hash(x + 977, z + 383) % 3 == 0
						local name = palette.node(bush and "undergrowth" or
							"grass_tuft")
						if bush then M.undergrowth_at(buf, palette, x, 1, z)
						else buf:put(x, 1, z, name, parts.place_param2(name)) end
						if bush then planted_bush = planted_bush + 1
						else planted_tuft = planted_tuft + 1 end
					end
				end
			end
		end
		return planted_bush, planted_tuft
	end

	-- Hearthpine Vale's ground cover, and nothing else's.
	--
	-- The Vale's blueprint identity SHA-256 is part of the frozen R7 mapgen
	-- manifest from the first WP13 increment, and every piece of engine
	-- evidence recorded since is taken against those bytes. The degenerate
	-- selector above is therefore not a bug that can be fixed HERE: at
	-- density 5 it does produce both roles, and re-picking its cells would
	-- move the Vale's identity for no visual gain. This routine is the
	-- original, kept verbatim and called from exactly one place.
	--
	-- No new settlement may call it. `M.undergrowth` is the one every other
	-- start uses, and the WP13 library KAT (retired in Round 22) checked that
	-- this one has a single caller.
	function M.vale_undergrowth(buf, palette, x1, z1, x2, z2, density)
		for z = z1, z2 do
			for x = x1, x2 do
				if (x * 7 + z * 11) % density == 0 then
					local below = buf:at(x, 0, z)
					local above = buf:at(x, 1, z)
					local free = (above == nil or above.name == "air")
					if below and free and parts.wild_soil(below.name) then
						local role = ((x + z) % 4 == 0) and "undergrowth" or
							"grass_tuft"
						local name = palette.node(role)
						buf:put(x, 1, z, name, parts.place_param2(name))
					end
				end
			end
		end
	end

	return M
end

return loader
