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
					buf:put(x, 2, z, palette.node(role))
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

	-- A lantern hung under a solid node. `xdecor_lantern` is in
	-- `group:attached_node = 3`, which is the engine's "attached to the node
	-- ABOVE", so the support test looks up, not down.
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

	-- Scattered undergrowth on a rectangle of open ground.
	function M.undergrowth(buf, palette, x1, z1, x2, z2, density)
		for z = z1, z2 do
			for x = x1, x2 do
				if (x * 7 + z * 11) % density == 0 then
					local below = buf:at(x, 0, z)
					local above = buf:at(x, 1, z)
					local free = (above == nil or above.name == "air")
					if below and free and below.name:find("dirt") then
						local role = ((x + z) % 4 == 0) and "undergrowth" or
							"grass_tuft"
						buf:put(x, 1, z, palette.node(role))
					end
				end
			end
		end
	end

	return M
end

return loader
