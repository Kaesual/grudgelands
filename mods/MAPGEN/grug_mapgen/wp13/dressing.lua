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

	-- A crate stack: chests with a wool bale on top.
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

	-- A pine with a continuous trunk and a tapering needle crown. Taller
	-- stems carry a deeper crown, so a stand of them is not one silhouette
	-- repeated.
	function M.tree(buf, palette, x, z, height)
		local log = palette.node("tree_log")
		local needles = palette.node("tree_leaves")
		for y = 1, height do buf:put(x, y, z, log) end
		local depth = height >= 7 and 4 or 3
		for step = 0, depth - 1 do
			local y = height - depth + step
			local reach = 2 - math.floor(step * 2 / depth)
			for dz = -reach, reach do
				for dx = -reach, reach do
					local span = math.abs(dx) + math.abs(dz)
					if span <= reach + (step % 2) and not (dx == 0 and dz == 0) then
						buf:put(x + dx, y, z + dz, needles)
					end
				end
			end
		end
		buf:put(x, height + 1, z, needles)
		for _, offset in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			buf:put(x + offset[1], height, z + offset[2], needles)
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
