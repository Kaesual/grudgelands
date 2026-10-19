-- Round 51 lane WRECK: the shipwrecks of the R7 successor settle (sea plan
-- §5a and ruling 20, tools/r51_wreck/DESIGN.md). It runs right after the
-- swamp pass, before P9G and the world content, so the seabed growth sees
-- the wrecks and grows round them.
--
-- The placement is a pure function of the world: the world is cut into
-- 256 x 256-node cells, and a cell holds at most one wreck. A cell rolls
-- whether it tries (CHANCE), which shape (hull, bow, stern or debris) and
-- which quarter turn, then tests PROBES hashed spots and takes the
-- shallowest that passes:
--   * every column of the turned footprint is bay or belt water, protected
--     (24 nodes or more off the coast, ruling 8; never a channel, a lake, a
--     river or the open sea), and outside every settlement, POI or other
--     claim exclusion that is not plain water or coast;
--   * the seabed under the footprint varies by at most one node, and the
--     water over its lowest column is at least the shape's height over the
--     sand plus one (the wreck stays under the surface; only a mast may
--     break it) and at most MAX_DEPTH (below that the seabed is nearly black
--     by day);
--   * a ring MARGIN nodes round the footprint (every 4 nodes) is bay, belt
--     or open-sea water, outside the same exclusions: the shore, piers,
--     towns and POIs stay clear by footprint + 16.
-- The shape's `seabed` layer sits on the lowest sand column of the
-- footprint; the layers below it lie in the sand. Every chunk writes the
-- part of each wreck inside its own owner (no owner clipping): plain nodes
-- through `write_road`, as the road, arena and swamp passes write, and only
-- over water or the natural seabed (sand, gravel, stone, clay, dirt);
-- anything else keeps what it has. A shape's "." cells are not in its data,
-- so the water inside a hull and the sand under it stay.
--
--   local wreck = dofile(wp40 .. "/wreck_writer.lua")
--   wreck.layout(shapes, deps)        the pure placement (tests, tools)
--   wreck.config(core_api, shapes)    the successor's configuration: .new(deps)
local M = {}

M.CELL = 256            -- one wreck at most per cell
M.INSET = 16            -- the footprint lies this far inside its cell
M.PROBES = 16           -- hashed spots tried per cell
M.CHANCE = 50           -- percent of cells that try
M.MARGIN = 16           -- the clear ring round the footprint
M.MAX_DEPTH = 14        -- the deepest water over the footprint's lowest column
-- Shape weights (hull, bow, stern, debris), out of their sum.
M.WEIGHTS = {3, 2, 2, 3}

local SEA = {bay = true, belt = true}
local RING = {bay = true, belt = true, open_sea = true}

-- The shape data (wreck_shapes.lua) turned once into four quarter turns:
-- per turn the footprint's size, its columns and its cells (dx, layer, dz,
-- node index, param2). A log's facedir along x (12) and along z (4) swap
-- on an odd turn; upright logs, planks and the leveled mast keep param2.
local function turned(shapes)
	local out = {}
	for s, shape in ipairs(shapes.shapes) do
		local sx, sz = shape.size.x, shape.size.z
		local log_index
		for i, name in ipairs(shapes.names) do
			if name == "grug_nodes:wreck_log" then log_index = i end
		end
		out[s] = {key = shape.key, seabed = shape.seabed,
			height = shape.size.y - shape.seabed, turns = {}}
		for r = 0, 3 do
			local w, d = sx, sz
			if r % 2 == 1 then w, d = sz, sx end
			local cells, columns, seen = {}, {}, {}
			local c = shape.cells
			for i = 1, #c, 5 do
				local x, y, z, n, p2 = c[i], c[i + 1], c[i + 2], c[i + 3], c[i + 4]
				local tx, tz
				if r == 0 then tx, tz = x, z
				elseif r == 1 then tx, tz = sz - 1 - z, x
				elseif r == 2 then tx, tz = sx - 1 - x, sz - 1 - z
				else tx, tz = z, sx - 1 - x end
				if n == log_index and r % 2 == 1 then
					if p2 == 12 then p2 = 4 elseif p2 == 4 then p2 = 12 end
				end
				cells[#cells + 1] = {tx, y, tz, n, p2}
				local key = tx * 4096 + tz
				if not seen[key] then
					seen[key] = true
					columns[#columns + 1] = {tx, tz}
				end
			end
			out[s].turns[r] = {w = w, d = d, cells = cells, columns = columns}
		end
	end
	return out
end

-- `deps`: seed (the world's seed string), water_query(x, z) (the zone
-- authority's water query: class, zone, level, distance, depth, protected),
-- ground_at(x, z) (the seabed's top node), excluded(x, z) (true inside a
-- claim exclusion that is not plain water or coast), water_level.
function M.layout(shapes, deps)
	local SHAPES = turned(shapes)
	local phase = 0
	for i = 1, #deps.seed do phase = (phase * 131 + string.byte(deps.seed, i)) % 2147483629 end
	local function hash(a, b, c)
		local v = (a * 73856093 + b * 19349663 + c * 83492791 + phase) % 2147483647
		v = (v * 48271) % 2147483647
		v = ((v + a * 2654435) * 48271) % 2147483647
		return (v * 48271) % 2147483647
	end
	local total = 0
	for _, w in ipairs(M.WEIGHTS) do total = total + w end
	local query, ground_at, excluded = deps.water_query, deps.ground_at, deps.excluded
	local water_level = deps.water_level

	local function fits(s, t, ax, az)
		local shape, turn = SHAPES[s], SHAPES[s].turns[t]
		local base, top = math.huge, -math.huge
		for _, col in ipairs(turn.columns) do
			local x, z = ax + col[1], az + col[2]
			local class, _, _, _, _, protected = query(x, z)
			if not SEA[class] or not protected or excluded(x, z) then return nil end
			local g = ground_at(x, z)
			if g < base then base = g end
			if g > top then top = g end
			if top - base > 1 then return nil end
		end
		local depth = water_level - base
		if depth < shape.height + 1 or depth > M.MAX_DEPTH then return nil end
		local x0, x1 = ax - M.MARGIN, ax + turn.w - 1 + M.MARGIN
		local z0, z1 = az - M.MARGIN, az + turn.d - 1 + M.MARGIN
		local function ring(x, z)
			return RING[(query(x, z))] and not excluded(x, z)
		end
		for x = x0, x1, 4 do
			if not ring(x, z0) or not ring(x, z1) then return nil end
		end
		for z = z0, z1, 4 do
			if not ring(x0, z) or not ring(x1, z) then return nil end
		end
		return base
	end

	local layout = {}
	local cache = {}
	-- The wreck of cell (cx, cz), or false: {shape, turn, x, z (the footprint's
	-- low corner), y (the lowest seabed node), w, d, key}.
	function layout.site(cx, cz)
		local key = cx * 65536 + cz
		local site = cache[key]
		if site ~= nil then return site end
		site = false
		if hash(cx, cz, 1) % 100 < M.CHANCE then
			local roll, s = hash(cx, cz, 2) % total, 1
			while roll >= M.WEIGHTS[s] do roll = roll - M.WEIGHTS[s]; s = s + 1 end
			local t = hash(cx, cz, 3) % 4
			local turn = SHAPES[s].turns[t]
			local span_x = M.CELL - 2 * M.INSET - turn.w + 1
			local span_z = M.CELL - 2 * M.INSET - turn.d + 1
			-- of the spots that pass, the shallowest (the first on a tie): the
			-- wreck is easier to see and its mast nearer the surface
			for k = 1, M.PROBES do
				local ax = cx * M.CELL + M.INSET + hash(cx, cz, 10 + 2 * k) % span_x
				local az = cz * M.CELL + M.INSET + hash(cx, cz, 11 + 2 * k) % span_z
				-- a cheap first look at the footprint's middle
				local class, _, _, _, depth, protected = query(ax + math.floor(turn.w / 2),
					az + math.floor(turn.d / 2))
				if SEA[class] and protected and depth and depth >= SHAPES[s].height and
						depth <= M.MAX_DEPTH + 1 and (not site or water_level - depth > site.y) then
					local base = fits(s, t, ax, az)
					if base and (not site or base > site.y) then
						site = {shape = s, turn = t, x = ax, z = az, y = base, w = turn.w,
							d = turn.d, key = SHAPES[s].key}
					end
				end
			end
		end
		cache[key] = site
		return site
	end
	-- Every wreck whose footprint meets the rectangle.
	function layout.sites_in(min_x, max_x, min_z, max_z)
		local out = {}
		for cz = math.floor(min_z / M.CELL), math.floor(max_z / M.CELL) do
			for cx = math.floor(min_x / M.CELL), math.floor(max_x / M.CELL) do
				local site = layout.site(cx, cz)
				if site and site.x <= max_x and site.x + site.w - 1 >= min_x and
						site.z <= max_z and site.z + site.d - 1 >= min_z then
					out[#out + 1] = site
				end
			end
		end
		return out
	end
	-- A site's cells in world coordinates: calls fn(x, y, z, node index, param2).
	function layout.cells(site, fn)
		local shape = SHAPES[site.shape]
		local cells = shape.turns[site.turn].cells
		for i = 1, #cells do
			local c = cells[i]
			fn(site.x + c[1], site.y + 1 + c[2] - shape.seabed, site.z + c[3], c[4], c[5])
		end
	end
	layout.shapes = SHAPES
	return layout
end

-- The successor's configuration. `shapes`: wreck_shapes.lua's table.
function M.config(core_api, shapes)
	local function fail(message) error("WP40 wreck writer: " .. message, 0) end
	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" or type(shapes) ~= "table" or
			type(shapes.names) ~= "table" or type(shapes.shapes) ~= "table" then
		fail("construction seam differs")
	end
	local function cid(name)
		if not core_api.registered_nodes[name] then fail("node missing: " .. name) end
		return core_api.get_content_id(name)
	end
	local CID = {}
	for i, name in ipairs(shapes.names) do CID[i] = cid(name) end
	-- What a wreck cell may replace: the sea's water and the natural seabed.
	local REPLACE = {}
	for _, name in ipairs({"default:water_source", "default:sand", "default:gravel",
			"default:stone", "default:clay", "default:dirt", "default:silver_sand",
			"default:desert_sand", "default:sandstone"}) do
		REPLACE[cid(name)] = true
	end

	local config = {}
	-- `dependencies`: the successor's (full_seed_string, zones_session,
	-- planner_source, horizontal, source).
	function config.new(dependencies)
		local zones = dependencies.zones_session
		local planner = dependencies.planner_source
		local horizontal = dependencies.horizontal
		local source = dependencies.source
		if type(zones) ~= "table" or type(zones.water_query_at) ~= "function" or
				type(planner) ~= "table" or type(planner.column_values_at) ~= "function" or
				type(horizontal) ~= "table" or
				type(horizontal.lowest_exclusion_value_at) ~= "function" or
				type(source) ~= "table" then
			fail("dependency seam differs")
		end
		-- The claim exclusions that are not plain water or coast: towns,
		-- capitals, their envelopes, POIs, active cores, underground
		-- reservations.
		local kind_of, flagged = {}, {}
		for _, recipe in ipairs(source.claim_exclusion_recipes or {}) do
			kind_of[recipe.id] = recipe.kind
		end
		for _, row in ipairs(source.claim_exclusions or {}) do
			local kind = kind_of[row.recipe_id]
			if kind ~= "planned_water" and kind ~= "coast" then flagged[row.id] = 1 end
		end
		local layout = M.layout(shapes, {
			seed = dependencies.full_seed_string,
			water_query = zones.water_query_at,
			ground_at = function(x, z) return (select(6, planner.column_values_at(x, z))) end,
			excluded = function(x, z)
				return horizontal.lowest_exclusion_value_at(x, z, flagged) ~= nil
			end,
			water_level = 1,
		})
		-- Tools (tools/r51_wreck/count.lua) read the layout of a runtime they
		-- build through this harness hook; a game never sets it.
		local writer = {sites = 0, cells = 0}
		local hook = rawget(_G, "GRUG_WRECK_LAYOUT_HOOK")
		if hook then hook(layout, writer) end
		function writer.dress(context)
			if type(context.write_road) ~= "function" then return 0 end
			local inside, settled, write = context.inside_owner, context.settled_at,
				context.write_road
			local count = 0
			local sites = layout.sites_in(context.min_x, context.max_x, context.min_z,
				context.max_z)
			for _, site in ipairs(sites) do
				local shape = layout.shapes[site.shape]
				local low = site.y + 1 - shape.seabed
				if low <= context.max_y and low + shape.height + shape.seabed - 1 >= context.min_y then
					writer.sites = writer.sites + 1
					layout.cells(site, function(x, y, z, n, param2)
						if inside(x, y, z) and REPLACE[(settled(x, y, z))] then
							write(x, y, z, CID[n], param2)
							count = count + 1
						end
					end)
				end
			end
			writer.cells = writer.cells + count
			return count
		end
		writer.layout = layout
		return writer
	end
	return config
end

return M
