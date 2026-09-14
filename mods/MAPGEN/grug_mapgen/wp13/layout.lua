-- WP13 pad layout: ground, paving, path routing and planting.
--
-- The pad is authored in local coordinates around the settlement spawn, with
-- y = 0 the ground node the whole settlement stands on. The caller fits y = 0
-- to the fitted start terrain before projecting the cells.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	-- Deterministic pad ground: coniferous litter over dirt, with sparse
	-- grass and bare patches so the open ground never reads as one texture.
	function M.ground(buf, palette, radius)
		buf:fill(-radius, -1, -radius, radius, -1, radius, palette.node("subsoil"))
		buf:fill(-radius, 0, -radius, radius, 0, radius, palette.node("ground"))
		for z = -radius + 2, radius - 2, 7 do
			for x = -radius + 2, radius - 2, 9 do
				if (x + z) % 4 == 0 then
					buf:fill(x - 1, 0, z - 1, x + 1, 0, z + 1,
						palette.node("ground_patch"))
				elseif (x - z) % 5 == 0 then
					buf:fill(x - 1, 0, z - 1, x + 1, 0, z + 1,
						palette.node("ground_bare"))
				end
			end
		end
	end

	-- Pave a rectangle and clear the headroom above it.
	function M.pave(buf, palette, x1, z1, x2, z2, role, height)
		local name = palette.node(role or "path")
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				buf:put(x, 0, z, name)
			end
		end
		buf:clear(math.min(x1, x2), 1, math.min(z1, z2),
			math.max(x1, x2), height or 3, math.max(z1, z2))
	end

	-- An L shaped path of the given width from (ax, az) to (bx, bz): first
	-- along z, then along x.
	function M.path(buf, palette, ax, az, bx, bz, width, role)
		local half = math.floor(((width or 3) - 1) / 2)
		M.pave(buf, palette, ax - half, math.min(az, bz), ax + half,
			math.max(az, bz), role or "path")
		M.pave(buf, palette, math.min(ax, bx), bz - half, math.max(ax, bx),
			bz + half, role or "path")
	end

	-- Is this ground cell free for a prop?
	function M.free(buf, x, z, height)
		local below = buf:at(x, 0, z)
		if below == nil or below.name == "air" then return false end
		for y = 1, height or 3 do
			local cell = buf:at(x, y, z)
			if cell ~= nil and cell.name ~= "air" then return false end
		end
		return true
	end

	function M.free_area(buf, x1, z1, x2, z2, height)
		for z = z1, z2 do
			for x = x1, x2 do
				if not M.free(buf, x, z, height) then return false end
			end
		end
		return true
	end

	-- Lamp posts down both sides of a north running street. `outdoors` is the
	-- caller's test for "not inside a building": an empty room is free ground
	-- with headroom, but a street lamp does not belong in it.
	function M.street_lamps(buf, palette, x, z1, z2, spacing, outdoors)
		local planted = 0
		for z = z1, z2, spacing do
			for _, side in ipairs({-1, 1}) do
				local lx = x + side * 3
				if outdoors(lx, z) and M.free(buf, lx, z, 3) then
					dressing.path_light(buf, palette, lx, z)
					planted = planted + 1
				end
			end
		end
		return planted
	end

	-- Only natural soil may be planted; paving and building floors are not.
	function M.natural(buf, x, z)
		local below = buf:at(x, 0, z)
		return below ~= nil and below.name:find("dirt") ~= nil
	end

	-- A stem also keeps one node of soil all round, so no pine grows with
	-- its trunk against a wall or a kerb.
	function M.natural_area(buf, x1, z1, x2, z2)
		for z = z1, z2 do
			for x = x1, x2 do
				if not M.natural(buf, x, z) then return false end
			end
		end
		return true
	end

	-- Pine clumps on the open ground, skipping anything already built.
	function M.plant_pines(buf, palette, spots)
		local planted = 0
		for _, spot in ipairs(spots) do
			local x, z, height = spot[1], spot[2], spot[3] or 6
			if M.natural(buf, x, z) and
					M.free_area(buf, x - 2, z - 2, x + 2, z + 2, height + 1) then
				dressing.tree(buf, palette, x, z, height)
				planted = planted + 1
			end
		end
		return planted
	end

	-- The pine wood the settlement stands in: a deterministic scatter over
	-- the whole pad that only takes root where nothing was built.
	function M.plant_wood(buf, palette, radius, step)
		local planted = 0
		for z = -radius + 3, radius - 3, step do
			for x = -radius + 3, radius - 3, step do
				local hash = (x * 73 + z * 151 + x * z) % 97
				local tx = x + hash % 5 - 2
				local tz = z + math.floor(hash / 5) % 5 - 2
				local height = 5 + hash % 4
				if hash % 7 < 5 and
						tx >= -radius + 3 and tx <= radius - 3 and
						tz >= -radius + 3 and tz <= radius - 3 and
						M.natural_area(buf, tx - 1, tz - 1, tx + 1, tz + 1) and
						M.free_area(buf, tx - 2, tz - 2, tx + 2, tz + 2,
							height + 2) then
					dressing.tree(buf, palette, tx, tz, height)
					planted = planted + 1
				end
			end
		end
		return planted
	end

	return M
end

return loader
