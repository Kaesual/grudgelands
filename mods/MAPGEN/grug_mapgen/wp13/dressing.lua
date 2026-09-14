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

	-- A notice post: a log standard with a sawn board.
	function M.signpost(buf, palette, x, z)
		buf:put(x, 1, z, palette.node("post"))
		buf:put(x, 2, z, palette.node("post"))
		buf:put(x, 3, z, palette.node("roof_slab"))
	end

	-- A pine: a bare trunk carrying a layered, tapering crown.
	--
	-- The proportions are those of the vendored pine schematics
	-- (mods/BASE/default/schematics/pine_tree.mts and small_pine.mts): the
	-- crown occupies only the top four or five courses, the widest ring is
	-- two nodes out and sits at the bottom of the crown, and everything
	-- below that is clear stem. The previous version started its crown three
	-- nodes above the ground on a five node stem, which read as a shrub from
	-- every camera angle.
	--
	-- `height` is the trunk: the lowest needle sits at `height - 4`, so a
	-- nine node stem shows five clear logs and an eleven node stem seven.
	-- The crown is cut with a parity notch per layer, so neighbouring trees
	-- of the same height are not the same silhouette.
	function M.tree(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local needles = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		-- reach per crown layer, from the widest ring up to the tip
		local LAYERS = {
			{offset = -4, reach = 2, notch = true},
			{offset = -3, reach = 2, notch = false},
			{offset = -2, reach = 1, notch = false},
			{offset = -1, reach = 1, notch = true},
			{offset = 0, reach = 1, notch = false},
		}
		for index = 1, #LAYERS do
			local layer = LAYERS[index]
			local y = height + layer.offset
			if y >= 2 then
				local reach = layer.reach
				for dz = -reach, reach do
					for dx = -reach, reach do
						local span = math.abs(dx) + math.abs(dz)
						local corner = math.abs(dx) == reach and
							math.abs(dz) == reach
						local skip = corner or
							(layer.notch and span == reach and
								(x + z + dx + dz) % 2 == 1)
						if span <= reach and not skip and
								not (dx == 0 and dz == 0) then
							buf:put(x + dx, y, z + dz, needles)
						end
					end
				end
			end
		end
		buf:put(x, height + 1, z, needles)
	end

	-- A broadleaf tree on the proportions of the vendored apple tree
	-- (mods/BASE/default/schematics/apple_tree.mts, decoded: 7 x 8 x 7, four
	-- clear trunk logs, then four crown courses). `height` is the trunk, so a
	-- four log stem shows the whole stem below the lowest leaf and a six log
	-- stem an orchard standard.
	--
	-- The crown is four diamonds clipped to the 7 x 7 box, widest at the
	-- bottom, exactly as the schematic: |dx| + |dz| <= 4 (capped at reach 3),
	-- then <= 3, then <= 3 capped at reach 2, then the plus. Two branch logs
	-- sit inside the lowest crown course, which is what gives the schematic
	-- its silhouette; a parity notch keeps neighbouring crowns distinct.
	function M.broadleaf(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local leaves = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		local LAYERS = {
			{offset = 1, span = 4, reach = 3, notch = true},
			{offset = 2, span = 3, reach = 3, notch = false},
			{offset = 3, span = 3, reach = 2, notch = false},
			{offset = 4, span = 1, reach = 1, notch = false},
		}
		for index = 1, #LAYERS do
			local layer = LAYERS[index]
			local y = height + layer.offset
			for dz = -layer.reach, layer.reach do
				for dx = -layer.reach, layer.reach do
					local span = math.abs(dx) + math.abs(dz)
					local skip = layer.notch and span == layer.span and
						(x + z + dx + dz) % 2 == 1
					if span <= layer.span and not skip and
							not (dx == 0 and dz == 0) then
						buf:put(x + dx, y, z + dz, leaves)
					end
				end
			end
			buf:put(x, y, z, leaves)
		end
		-- Branch logs in the lowest crown course, as the schematic has them.
		for _, branch in ipairs({{-1, 0}, {1, 1}}) do
			buf:put(x + branch[1], height + 1, z + branch[2], log)
		end
	end

	-- A columnar tree on the proportions of the vendored aspen, course for
	-- course. `mods/BASE/default/schematics/aspen_tree.mts` decodes (5 x 14 x
	-- 5, trunk at its centre column) to:
	--
	--     y 0-5   trunk only, six clear logs
	--     y 6     3 x 3 leaf ring round the trunk
	--     y 7     full 5 x 5 leaf square round the trunk
	--     y 8     3 x 3      y 9  5 x 5      y 10 3 x 3     y 11 5 x 5
	--     y 12    3 x 3, and its CENTRE is a leaf: the trunk stopped at 11
	--     y 13    one leaf, alone, two courses above the last log
	--
	-- Silverwood IS that schematic with the aspen nodes replaced
	-- (`grug_trees.silverwood_replacements`), so this is the silhouette the
	-- surrounding elf forest actually grows and an authored grove matches it.
	--
	-- Two things were wrong with the first version and the review caught
	-- both. The top leaf sat at `height + 1`, one course short, on top of the
	-- last crown course instead of clear above it. And the wide courses
	-- carried a parity notch -- every other edge cell dropped, keyed on the
	-- stem's position -- meant to keep neighbouring stems from sharing a
	-- silhouette. It took 868 leaf cells out of the corpus and left each of
	-- them with no leaf, log or anything else across any of its six faces:
	-- the crowns were lace. The aspen's own alternation of 3 x 3 and 5 x 5
	-- already breaks the outline, and the stem heights already vary, so the
	-- notch bought nothing the schematic was not doing better.
	--
	-- Leaf decay: default registers aspen leaves with radius 3, and no leaf
	-- here is further than 2 from the trunk in x/z and 2 above the last log,
	-- so every one of them stays inside the radius of its own stem.
	--
	-- `height` is the trunk: a twelve log stem reproduces the schematic
	-- exactly, and a shorter one keeps the six clear logs and loses crown
	-- courses from the bottom, never from the top.
	function M.columnar(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local leaves = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		-- Reach per crown course, counted down from the top log: 1 is the
		-- 3 x 3 ring, 2 the full 5 x 5 square.
		local LAYERS = {
			{offset = -5, reach = 1}, {offset = -4, reach = 2},
			{offset = -3, reach = 1}, {offset = -2, reach = 2},
			{offset = -1, reach = 1}, {offset = 0, reach = 2},
			{offset = 1, reach = 1},
		}
		for index = 1, #LAYERS do
			local layer = LAYERS[index]
			local y = height + layer.offset
			if y >= 2 then
				for dz = -layer.reach, layer.reach do
					for dx = -layer.reach, layer.reach do
						if dx ~= 0 or dz ~= 0 then
							buf:put(x + dx, y, z + dz, leaves)
						elseif y > height then
							-- The last crown course stands above the stem, so
							-- its centre is a leaf, not the log that is not
							-- there.
							buf:put(x, y, z, leaves)
						end
					end
				end
			end
		end
		buf:put(x, height + 2, z, leaves)
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

	-- A savanna acacia on the proportions of the vendored schematic
	-- (mods/BASE/default/schematics/acacia_tree.mts, decoded: 9 x 9 x 9, five
	-- clear trunk logs, then two branch arms climbing diagonally to opposite
	-- corners and a flat two-course umbrella over them). That flat crown on a
	-- long bare stem is the whole silhouette of the dry flats, and it is the
	-- opposite of both the conifer and the apple standard: nothing tapers,
	-- and the widest part is the very top.
	--
	-- `height` is the trunk, so the lowest leaf sits at `height + 1` and the
	-- stem is clear all the way. The branch arms are logs inside the crown,
	-- exactly as the schematic has them; a parity notch on the outermost ring
	-- keeps neighbouring crowns from being the same shape.
	function M.acacia(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local leaves = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		-- Two arms, each climbing one node out and one node up, as the
		-- schematic's branches do.
		local arm = ((x + z) % 2 == 0) and 1 or -1
		for step = 1, 2 do
			buf:put(x + arm * step, height - 2 + step, z + arm * step, log)
			buf:put(x - arm * step, height - 2 + step, z - arm * step, log)
		end
		local LAYERS = {
			{offset = 1, span = 4, reach = 3, notch = true},
			{offset = 2, span = 3, reach = 2, notch = false},
		}
		for index = 1, #LAYERS do
			local layer = LAYERS[index]
			local y = height + layer.offset
			for dz = -layer.reach, layer.reach do
				for dx = -layer.reach, layer.reach do
					local span = math.abs(dx) + math.abs(dz)
					local skip = layer.notch and span == layer.span and
						(x + z + dx + dz) % 2 == 1
					if span <= layer.span and not skip then
						buf:put(x + dx, y, z + dz, leaves)
					end
				end
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
	function M.crop_rows(buf, palette, x1, z1, x2, z2, axis)
		local furrow = palette.node("ground_patch")
		local soil = palette.node("planter_soil")
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

	-- A gravewood: the bent, mostly bare dead tree of the blight basin.
	--
	-- The proportions are decoded from the mod's own assets
	-- (`mods/ITEMS/grug_trees/schematics/grug_gravewood_small.mts`, 7 x 7 x 7,
	-- and `grug_gravewood_tall.mts`, 7 x 9 x 7): three clear stem logs, the
	-- first fork on the fourth course, bent branch runs that reach two or
	-- three nodes out while rising one, and only four to six grey leaf
	-- remnants in the whole crown -- a tenth of what a pine or an apple
	-- carries. Nothing here is a broad canopy.
	--
	-- The one deliberate difference from the assets is that the stem carries
	-- on to its own tip and ends in a leaf remnant. The schematics let the
	-- trunk stop in mid-air under a fork, and the settlement tree invariant
	-- (every leaf rooted on an unbroken stem that starts on the ground) is
	-- worth more than that detail, which the branch runs give back anyway.
	--
	-- `height` is the stem. Three of the four arms are taken, chosen by
	-- position, so neighbouring gravewoods are not the same silhouette.
	local GRAVEWOOD_ARMS = {
		{dx = 1, dz = 0, lift = -3, reach = 3},
		{dx = -1, dz = 0, lift = -2, reach = 2},
		{dx = 0, dz = 1, lift = -1, reach = 2},
		{dx = 0, dz = -1, lift = -2, reach = 3},
	}

	function M.gravewood(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local leaves = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		buf:put(x, height + 1, z, leaves)
		local skip = (x * 37 + z * 53) % 4 + 1
		for index = 1, #GRAVEWOOD_ARMS do
			local arm = GRAVEWOOD_ARMS[index]
			if index ~= skip then
				local tip_y = height + arm.lift
				for step = 1, arm.reach do
					tip_y = height + arm.lift + math.floor(step / 2)
					buf:put(x + arm.dx * step, tip_y, z + arm.dz * step, log)
				end
				buf:put(x + arm.dx * arm.reach, tip_y + 1,
					z + arm.dz * arm.reach, leaves)
			end
		end
	end

	-- A grave: a flagstone laid in the blight with an upright marker on it.
	-- `tall` stacks a second course, which is what the older half of a
	-- burial ground looks like next to the newer.
	function M.grave(buf, palette, x, z, tall)
		buf:put(x, 0, z, palette.node("path"))
		buf:put(x, 1, z, palette.node("low_wall"))
		if tall then buf:put(x, 2, z, palette.node("low_wall")) end
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
						buf:put(x, 1, z, palette.node("undergrowth"))
					else
						M.grave(buf, palette, x, z, hash % 4 == 0)
						set = set + 1
					end
				end
			end
		end
		return set
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
					if below and below.name:find("dirt") and
							(above == nil or above.name == "air") then
						buf:put(x, 1, z, name)
						if name == bone then sown_bones = sown_bones + 1
						else sown_shrubs = sown_shrubs + 1 end
					end
				end
			end
		end
		return sown_bones, sown_shrubs
	end

	-- A jungle tree on the proportions of the vendored schematic
	-- (mods/BASE/default/schematics/jungle_tree.mts, decoded: 5 x 17 x 5).
	-- What makes that tree recognisable is not its crown but its silhouette:
	-- a plus-shaped buttress root three courses high, then a bare single-log
	-- trunk for two thirds of its height, four small leaf spurs on alternating
	-- diagonals, and only then a flat crown in the top three courses -- two
	-- full 5 x 5 leaf slabs and a 3 x 3 cap. A pine's tapering cone and an
	-- oak's round ball are both wrong for it.
	--
	-- `height` is the trunk: the crown occupies `height + 1` to `height + 3`.
	function M.jungle_tree(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local leaves = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		-- The buttress: the four orthogonal neighbours, three courses high.
		for _, step in ipairs({{0, -1}, {-1, 0}, {1, 0}, {0, 1}}) do
			for y = 1, 3 do
				buf:put(x + step[1], y, z + step[2], log)
			end
		end
		-- Four leaf spurs, one per diagonal, climbing the bare trunk. The
		-- starting diagonal comes off the position, so two neighbouring trees
		-- of the same height do not carry the same branches.
		local DIAGONAL = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}
		for index = 1, 4 do
			local spur = DIAGONAL[(index + x + z) % 4 + 1]
			local y = height - 6 + index
			if y >= 5 then
				for dz = 0, 2 do
					for dx = 0, 2 do
						if dx + dz > 0 then
							buf:put(x + spur[1] * dx, y, z + spur[2] * dz, leaves)
						end
					end
				end
				buf:put(x + spur[1], y, z + spur[2], log)
			end
		end
		-- The crown: two full slabs and a cap, the schematic's own shape.
		for _, offset in ipairs({1, 2}) do
			for dz = -2, 2 do
				for dx = -2, 2 do
					buf:put(x + dx, height + offset, z + dz, leaves)
				end
			end
		end
		for dz = -1, 1 do
			for dx = -1, 1 do
				buf:put(x + dx, height + 3, z + dz, leaves)
			end
		end
	end

	-- An emergent kapok, on the proportions of
	-- mods/BASE/default/schematics/emergent_jungle_tree.mts (7 x 37 x 7): a
	-- buttressed base five cells across, a solid three-by-three trunk, leaf
	-- collars where the branches leave it, and a seven-cell crown that stands
	-- clear of everything else. The schematic is thirty-seven courses tall
	-- and the authorized blueprint volume is twenty-seven, so the trunk is
	-- shortened and nothing else is: the proportions of base, collar and
	-- crown are the schematic's.
	--
	-- `height` is the top trunk course; the crown reaches `height + 4`.
	function M.emergent(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local leaves = palette.node("tree_leaves")
		for y = 1, height do
			for dz = -1, 1 do
				for dx = -1, 1 do
					buf:put(x + dx, y, z + dz, log)
				end
			end
		end
		-- The buttress: the arms of a five-cell plus, four courses high.
		for y = 1, 4 do
			for _, step in ipairs({{0, -2}, {-2, 0}, {2, 0}, {0, 2}}) do
				buf:put(x + step[1], y, z + step[2], log)
			end
		end
		-- Two leaf collars on the bare trunk, where a branch whorl leaves it.
		for _, offset in ipairs({8, 4}) do
			local y = height - offset
			if y >= 6 then
				for dz = -2, 2 do
					for dx = -2, 2 do
						if math.abs(dx) == 2 or math.abs(dz) == 2 then
							buf:put(x + dx, y, z + dz, leaves)
						end
					end
				end
			end
		end
		-- The crown: hollow shoulders, a solid course, a cap.
		local LAYERS = {{1, 4, 3}, {2, 4, 3}, {3, 6, 3}, {4, 3, 2}}
		for _, layer in ipairs(LAYERS) do
			local y = height + layer[1]
			for dz = -layer[3], layer[3] do
				for dx = -layer[3], layer[3] do
					if math.abs(dx) + math.abs(dz) <= layer[2] then
						buf:put(x + dx, y, z + dz, leaves)
					end
				end
			end
		end
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
								if below ~= nil and below.name:find("dirt") and
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
	-- from the other. `tools/wp13/library_kat.lua` asserts that every start
	-- emits both of its ground-cover nodes.
	function M.undergrowth(buf, palette, x1, z1, x2, z2, density)
		local planted_bush, planted_tuft = 0, 0
		for z = z1, z2 do
			for x = x1, x2 do
				if parts.position_hash(x, z) % density == 0 then
					local below = buf:at(x, 0, z)
					local above = buf:at(x, 1, z)
					local free = (above == nil or above.name == "air")
					if below and free and below.name:find("dirt") then
						local bush =
							parts.position_hash(x + 977, z + 383) % 3 == 0
						local name = palette.node(bush and "undergrowth" or
							"grass_tuft")
						buf:put(x, 1, z, name, parts.place_param2(name))
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
	-- start uses, and `tools/wp13/library_kat.lua` checks that this one has a
	-- single caller.
	function M.vale_undergrowth(buf, palette, x1, z1, x2, z2, density)
		for z = z1, z2 do
			for x = x1, x2 do
				if (x * 7 + z * 11) % density == 0 then
					local below = buf:at(x, 0, z)
					local above = buf:at(x, 1, z)
					local free = (above == nil or above.name == "air")
					if below and free and below.name:find("dirt") then
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
