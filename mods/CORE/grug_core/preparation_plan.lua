-- Immutable mapchunk traversal. Coordinates are nodes; geometry is mapblocks.
local M = {}
-- Source extent encloses continents, frontier and islands. Add 20 mapblocks
-- of water on every side, then round outward on the actual engine grid.
local OCEAN_MARGIN = 20 * 16
M.bounds = {x_min = -3600 - OCEAN_MARGIN, x_max = 3600 + OCEAN_MARGIN,
	z_min = -3200 - OCEAN_MARGIN, z_max = 3200 + OCEAN_MARGIN,
	-- Below shallow seabeds; mountain maximum 360 + detail 16 + water 1,
	-- plus 80 nodes of surface-loading headroom, rounded outward below.
	y_min = -100, y_max = 360 + 16 + 1 + 80}
local axes = {"x", "y", "z"}
local function key(p) return p.x .. ":" .. p.y .. ":" .. p.z end
M.key = key
local function align(value, blocks)
	local origin = -math.floor(blocks / 2) * 16
	return math.floor((value - origin) / (blocks * 16)) * blocks * 16 + origin
end
function M.new(mode, geometry, identities, bounds)
	assert(mode == "full" or mode == "starts", "Invalid preparation mode")
	local plan = {mode = mode, geometry = {}, order = "z-y-x", cursor = 0}
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
		plan.bounds = envelope({x=b.x_min,y=b.y_min,z=b.z_min},
			{x=b.x_max,y=b.y_max,z=b.z_max})
		local total = 1
		for _, axis in ipairs(axes) do
			total = total * ((plan.bounds.max[axis] - plan.bounds.min[axis]) /
				(geometry[axis] * 16) + 1)
		end
		plan.total = total
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
		local rest = index - 1
		for _, axis in ipairs(axes) do
			local step = plan.geometry[axis] * 16
			local count = (plan.bounds.max[axis] - plan.bounds.min[axis]) / step + 1
			lo[axis] = plan.bounds.min[axis] + (rest % count) * step
			rest = math.floor(rest / count)
		end
	end
	local hi = {}
	for _, axis in ipairs(axes) do hi[axis] = lo[axis] + plan.geometry[axis]*16 - 1 end
	return lo, hi
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
