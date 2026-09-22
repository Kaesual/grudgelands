-- Immutable mapchunk traversal. Coordinates are nodes; geometry is mapblocks.
local M = {}
-- Source extent encloses continents, frontier and islands. Add 20 mapblocks
-- of water on every side, then round outward on the actual engine grid.
local OCEAN_MARGIN = 20 * 16
M.bounds = {x_min = -3600 - OCEAN_MARGIN, x_max = 3600 + OCEAN_MARGIN,
	z_min = -3200 - OCEAN_MARGIN, z_max = 3200 + OCEAN_MARGIN}
local horizontal = {"x", "z"}
local axes = {"x", "y", "z"}
local function key(p) return p.x .. ":" .. p.y .. ":" .. p.z end
M.key = key
local function align(value, blocks)
	local origin = -math.floor(blocks / 2) * 16
	return math.floor((value - origin) / (blocks * 16)) * blocks * 16 + origin
end
function M.new(mode, geometry, identities, bounds)
	assert(mode == "full" or mode == "starts", "Invalid preparation mode")
	local plan = {mode = mode, geometry = {},
		order = mode == "full" and "z-x-local-y-v1" or "z-y-x", cursor = 0}
	for _, axis in ipairs(axes) do
		local value = geometry[axis]
		assert(type(value) == "number" and value >= 1 and value % 1 == 0,
			"Invalid preparation chunk geometry")
		plan.geometry[axis] = value
	end
	local function envelope(lo, hi)
		local row = {min = {}, max = {}}
		for _, axis in ipairs(axes) do
			row.min[axis] = align(lo[axis], geometry[axis])
			row.max[axis] = align(hi[axis], geometry[axis])
		end
		return row
	end
	if mode == "full" then
		local b = bounds or M.bounds
		plan.bounds = {min = {}, max = {}}
		local total = 1
		for _, axis in ipairs(horizontal) do
			plan.bounds.min[axis] = align(b[axis .. "_min"], geometry[axis])
			plan.bounds.max[axis] = align(b[axis .. "_max"], geometry[axis])
			total = total * ((plan.bounds.max[axis] - plan.bounds.min[axis]) /
				(geometry[axis] * 16) + 1)
		end
		plan.total, plan.starts = total, {}
		assert(#identities == 6, "Preparation requires six start identities")
		for _, identity in ipairs(identities) do
			local a = identity.anchor
			local row = envelope({x=a.x-64,y=a.y+1-24,z=a.z-64},
				{x=a.x+63,y=a.y+1+80,z=a.z+63})
			assert(row.min.x >= plan.bounds.min.x and row.max.x <= plan.bounds.max.x and
				row.min.z >= plan.bounds.min.z and row.max.z <= plan.bounds.max.z,
				"Full preparation bounds omit a start envelope")
			plan.starts[#plan.starts+1] = row
		end
	else
		assert(#identities == 6, "Preparation requires six start identities")
		local seen, chunks = {}, {}
		for _, identity in ipairs(identities) do
			local a = identity.anchor
			local row = envelope({x=a.x-64,y=a.y+1-24,z=a.z-64},
				{x=a.x+63,y=a.y+1+80,z=a.z+63})
			for z = row.min.z, row.max.z, geometry.z * 16 do
				for y = row.min.y, row.max.y, geometry.y * 16 do
					for x = row.min.x, row.max.x, geometry.x * 16 do
						local p = {x=x,y=y,z=z}
						if not seen[key(p)] then
							seen[key(p)] = true; chunks[#chunks+1] = p
						end
					end
				end
			end
		end
		table.sort(chunks, function(a,b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		plan.chunks, plan.total = chunks, #chunks
	end
	return plan
end
function M.unit(plan, index)
	assert(index >= 1 and index <= plan.total and index % 1 == 0)
	local lo = {}
	if plan.mode == "starts" then
		for _, axis in ipairs(axes) do lo[axis] = plan.chunks[index][axis] end
	else
		local tile = assert(plan.selection, "Surface tile has not been resolved")
		assert(tile.index == index, "Surface selection belongs to another tile")
		lo.x, lo.z = tile.x, tile.z
		lo.y = tile.y_min + tile.inner * plan.geometry.y * 16
	end
	local hi = {}
	for _, axis in ipairs(axes) do hi[axis] = lo[axis] + plan.geometry[axis]*16 - 1 end
	return lo, hi
end
-- Resolve only this tile; callers bound calls to scan() across server steps.
function M.begin(plan, source)
	assert(plan.mode == "full" and plan.cursor < plan.total)
	local rest, lo, hi = plan.cursor, {}, {}
	for _, axis in ipairs(horizontal) do
		local step = plan.geometry[axis] * 16
		local count = (plan.bounds.max[axis] - plan.bounds.min[axis]) / step + 1
		lo[axis] = plan.bounds.min[axis] + (rest % count) * step
		hi[axis] = lo[axis] + step - 1
		rest = math.floor(rest / count)
	end
	local radius, bottom, top = source.tile_bounds(lo, hi)
	assert(type(radius) == "number" and radius >= 1 and radius % 1 == 0,
		"Invalid preparation content reach")
	for _, row in ipairs(plan.starts) do
		if lo.x <= row.max.x and hi.x >= row.min.x and
				lo.z <= row.max.z and hi.z >= row.min.z then
			bottom = math.min(bottom, row.min.y)
			top = math.max(top, row.max.y + plan.geometry.y*16 - 1)
		end
	end
	return {index=plan.cursor+1,x=lo.x,z=lo.z,inner=0,
		x_min=lo.x-radius,x_max=hi.x+radius,z_min=lo.z-radius,z_max=hi.z+radius,
		next_x=lo.x-radius,next_z=lo.z-radius,bottom=bottom,top=top}
end
function M.scan(plan, scan, source, budget)
	for _ = 1, budget do
		local low, high = source.column_bounds(scan.next_x, scan.next_z)
		assert(type(low) == "number" and type(high) == "number" and low <= high and
			low % 1 == 0 and high % 1 == 0, "Invalid preparation surface height")
		scan.bottom, scan.top = math.min(scan.bottom, low), math.max(scan.top, high)
		scan.next_x = scan.next_x + 1
		if scan.next_x > scan.x_max then
			scan.next_x, scan.next_z = scan.x_min, scan.next_z + 1
		end
		if scan.next_z > scan.z_max then
			plan.selection = {index=scan.index,x=scan.x,z=scan.z,inner=0,
				y_min=align(scan.bottom,plan.geometry.y),
				y_max=align(scan.top,plan.geometry.y)}
			return true
		end
	end
	return false
end
function M.complete(plan)
	if plan.mode == "full" then
		local tile = assert(plan.selection)
		tile.inner = tile.inner + 1
		if tile.y_min + tile.inner*plan.geometry.y*16 <= tile.y_max then return false end
		plan.selection = nil
	end
	plan.cursor = plan.cursor + 1
	return true
end
function M.expected(lo, hi)
	local set, total = {}, 0
	for z = lo.z/16, (hi.z+1)/16-1 do
		for y = lo.y/16, (hi.y+1)/16-1 do
			for x = lo.x/16, (hi.x+1)/16-1 do
				set[key({x=x,y=y,z=z})] = true; total = total + 1
			end
		end
	end
	return set, total
end
return M
