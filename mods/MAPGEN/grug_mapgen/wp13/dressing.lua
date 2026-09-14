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
					buf:put(x, 2, z, name, parts.plant_param2(name))
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

	-- A parapet on a finished flat roof deck: a continuous breastwork course
	-- on the wall line with merlons standing one course above it every
	-- `step` cells. The deck under it is already a slab, so the breastwork
	-- lands on a bearing all the way round, and the crenels between the
	-- merlons are what a fighting platform is looked over.
	--
	-- `y` is the course the breastwork STANDS ON, one above the deck slab
	-- `roofs.flat_deck` laid, so the deck stays continuous underneath it.
	function M.parapet(buf, palette, x1, z1, x2, z2, y, step)
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
	function M.palisade(buf, palette, x1, z1, x2, z2, height)
		local log = palette.node("tree_log")
		local point = palette.node("roof_stair_outer")
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
	function M.standard(buf, palette, x, z, height, lights)
		local pole = palette.node("post")
		for y = 1, height do buf:put(x, y, z, pole) end
		buf:put(x, height + 1, z, palette.node("rug_accent"))
		parts.floor_torch(buf, palette, x, height + 2, z)
		if lights then lights[#lights + 1] = {x = x, y = height + 2, z = z} end
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
						local name = palette.node(role)
						buf:put(x, 1, z, name, parts.plant_param2(name))
					end
				end
			end
		end
	end

	return M
end

return loader
