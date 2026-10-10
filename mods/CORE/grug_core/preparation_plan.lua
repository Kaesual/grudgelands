-- Immutable mapchunk traversal. Coordinates are nodes; geometry is mapblocks.
local M = {}
-- Source extent encloses continents, frontier and islands. Add 20 mapblocks
-- of water on every side, then round outward on the actual engine grid.
local OCEAN_MARGIN = 20 * 16
M.bounds = {x_min = -3600 - OCEAN_MARGIN, x_max = 3600 + OCEAN_MARGIN,
	z_min = -3200 - OCEAN_MARGIN, z_max = 3200 + OCEAN_MARGIN}
-- Full mode prepares, per horizontal tile, every mapchunk a player walking,
-- swimming or riding a flying mount can make the engine generate
-- (docs/design/world_preparation.md, "Full-column extent").
--
-- Generate reach. RemoteClient::GetNextBlocks (src/server/clientiface.cpp at
-- the reference pin) centres its Chebyshev block shells on the block of the
-- player's base position predicted one block (16 nodes) ahead along the
-- velocity, and generates shells up to `max_block_generate_distance` (zoom is
-- off: creative_mode is disabled, so adjustDist keeps the distance). Blocks
-- within distance + 1 of the player's own block can therefore be generated:
-- (distance + 1) * 16 nodes, 176 at the default 10. block(y + 176) is exactly
-- block(y) + 11, so the node offset rounded outward to blocks and chunks is
-- exact, not an approximation.
--
-- Flight: the mount entity is clamped to the ceiling each step; its rider sits
-- at most 3.71 nodes above it (grug_mounts catalog seat offsets; its camera at
-- most 4.35), the eye is 1.625 above the feet and one server step of climb can
-- overshoot the clamp by about one node. Eight nodes cover that.
M.FLIGHT_HEADROOM = 8
-- Standing: feet one node above the highest solid node plus a 1.25-node jump.
M.STAND_HEADROOM = 3
local horizontal = {"x", "z"}
local axes = {"x", "y", "z"}
local function key(p) return p.x .. ":" .. p.y .. ":" .. p.z end
M.key = key
local function align(value, blocks)
	local origin = -math.floor(blocks / 2) * 16
	return math.floor((value - origin) / (blocks * 16)) * blocks * 16 + origin
end
M.align = align
local function integer(value, minimum, message)
	assert(type(value) == "number" and value % 1 == 0 and value >= minimum, message)
	return value
end
-- options (full mode): generate_distance = the effective
-- max_block_generate_distance, flight_ceiling = the mount ceiling y, and an
-- optional bounds override {x_min, x_max, z_min, z_max}.
function M.new(mode, geometry, identities, options)
	assert(mode == "full" or mode == "starts", "Invalid preparation mode")
	options = options or {}
	local plan = {mode = mode, geometry = {},
		order = mode == "full" and "z-x-column-v2" or "z-y-x", cursor = 0}
	for _, axis in ipairs(axes) do
		plan.geometry[axis] = integer(geometry[axis], 1,
			"Invalid preparation chunk geometry")
	end
	local function envelope(lo, hi)
		local row = {min = {}, max = {}}
		for _, axis in ipairs(axes) do
			row.min[axis] = align(lo[axis], geometry[axis])
			row.max[axis] = align(hi[axis], geometry[axis])
		end
		return row
	end
	assert(#identities == 6, "Preparation requires six start identities")
	if mode == "full" then
		local distance = integer(options.generate_distance, 0,
			"Invalid preparation generate distance")
		local ceiling = integer(options.flight_ceiling, -30000,
			"Invalid preparation flight ceiling")
		-- Blocks the engine may generate around a player's block (see above),
		-- as nodes, and the neighbourhood in tiles: a player standing in any tile
		-- within `window` tiles can have this tile's blocks generated.
		plan.reach = (distance + 1) * 16
		plan.air_top = ceiling + M.FLIGHT_HEADROOM
		plan.window, plan.counts = {}, {}
		local b = options.bounds or M.bounds
		plan.bounds = {min = {}, max = {}}
		local total = 1
		for _, axis in ipairs(horizontal) do
			plan.bounds.min[axis] = align(b[axis .. "_min"], geometry[axis])
			plan.bounds.max[axis] = align(b[axis .. "_max"], geometry[axis])
			plan.counts[axis] = (plan.bounds.max[axis] - plan.bounds.min[axis]) /
				(geometry[axis] * 16) + 1
			plan.window[axis] = math.ceil((distance + 1) / geometry[axis])
			total = total * plan.counts[axis]
		end
		plan.total, plan.starts = total, {}
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
-- Horizontal tile of a 1-based index: x varies fastest (z/x order).
local function tile_of(plan, index)
	local i = index - 1
	local tx = i % plan.counts.x
	local tz = (i - tx) / plan.counts.x
	return tx, tz, plan.bounds.min.x + tx * plan.geometry.x * 16,
		plan.bounds.min.z + tz * plan.geometry.z * 16
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
-- Surface statistics run ahead of selection: a tile's column needs the
-- extremes of its whole neighbourhood window, so the scanner walks tiles in
-- the same z/x order and keeps only the rows a pending window can still read.
-- It is ephemeral and restarts from the head's window after a restart.
function M.scanner(plan, index)
	assert(plan.mode == "full")
	local _, tz = tile_of(plan, index)
	local first_row = math.max(0, tz - plan.window.z)
	return {next = first_row * plan.counts.x + 1, stats = {}, kept_row = first_row}
end
-- Scan at most `budget` surface columns. A tile's statistic is the lowest and
-- highest surface/content height of its columns plus the decoded content
-- reach around it, and of the fitted boxes over it.
function M.scan(plan, scanner, source, budget)
	for _ = 1, budget do
		local tile = scanner.tile
		if not tile then
			if scanner.next > plan.total then return end
			local _, _, x, z = tile_of(plan, scanner.next)
			local lo = {x = x, z = z}
			local hi = {x = x + plan.geometry.x*16 - 1, z = z + plan.geometry.z*16 - 1}
			local radius, bottom, top = source.tile_bounds(lo, hi)
			assert(type(radius) == "number" and radius >= 1 and radius % 1 == 0,
				"Invalid preparation content reach")
			tile = {index = scanner.next, low = bottom, high = top,
				x_min = lo.x - radius, x_max = hi.x + radius, z_max = hi.z + radius,
				next_x = lo.x - radius, next_z = lo.z - radius}
			scanner.tile = tile
		end
		local low, high = source.column_bounds(tile.next_x, tile.next_z)
		assert(type(low) == "number" and type(high) == "number" and low <= high and
			low % 1 == 0 and high % 1 == 0, "Invalid preparation surface height")
		tile.low, tile.high = math.min(tile.low, low), math.max(tile.high, high)
		tile.next_x = tile.next_x + 1
		if tile.next_x > tile.x_max then
			tile.next_x, tile.next_z = tile.x_min, tile.next_z + 1
		end
		if tile.next_z > tile.z_max then
			scanner.stats[tile.index] = {low = tile.low, high = tile.high}
			scanner.tile, scanner.next = nil, scanner.next + 1
		end
	end
end
-- Resolve the next tile's Y range once its whole window has been scanned.
-- Bottom: the window's lowest surface minus the reach. Top: the higher of the
-- flight ceiling and the window's highest content (plus standing headroom),
-- plus the reach. Start readiness envelopes over the tile still apply.
function M.select(plan, scanner)
	assert(plan.mode == "full" and not plan.selection and plan.cursor < plan.total)
	local index = plan.cursor + 1
	local tx, tz, x, z = tile_of(plan, index)
	local nx, nz = plan.counts.x, plan.counts.z
	local wx, wz = plan.window.x, plan.window.z
	local z_last = math.min(nz - 1, tz + wz)
	if scanner.next <= z_last * nx + math.min(nx - 1, tx + wx) + 1 then return false end
	local low, high = math.huge, -math.huge
	for row = math.max(0, tz - wz), z_last do
		for column = math.max(0, tx - wx), math.min(nx - 1, tx + wx) do
			local stat = assert(scanner.stats[row * nx + column + 1],
				"Preparation window statistic missing")
			low, high = math.min(low, stat.low), math.max(high, stat.high)
		end
	end
	while scanner.kept_row < tz - wz do
		for column = 0, nx - 1 do scanner.stats[scanner.kept_row * nx + column + 1] = nil end
		scanner.kept_row = scanner.kept_row + 1
	end
	local bottom = low - plan.reach
	local top = math.max(high + M.STAND_HEADROOM, plan.air_top) + plan.reach
	local x_max, z_max = x + plan.geometry.x*16 - 1, z + plan.geometry.z*16 - 1
	for _, row in ipairs(plan.starts) do
		if x <= row.max.x and x_max >= row.min.x and z <= row.max.z and z_max >= row.min.z then
			bottom = math.min(bottom, row.min.y)
			top = math.max(top, row.max.y + plan.geometry.y*16 - 1)
		end
	end
	plan.selection = {index=index,x=x,z=z,inner=0,
		y_min=align(bottom,plan.geometry.y),y_max=align(top,plan.geometry.y)}
	return true
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
