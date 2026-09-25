-- WP40 vertical model, Round 22 (world_zones.md §7.6).
--
-- One globally queryable surface: the natural float field of
-- `terrain_field.lua`, floored to a node y, with the anchor fittings (starts,
-- capitals, villages, outposts, camps, mines, dragons ...) and the shore rule
-- on top. The coast takes its shape from the field alone; only its near-water
-- material is derived here (world_zones.md §7.4, plan D27). Inland water
-- (Round 22 Phase 5, plan D38-D40): rivers and lakes from `water_layout.lua`
-- carve the natural height and carry their own water surfaces; authored lakes
-- (civic water) sit on the fitted terrain. Roads are rebuilt in Phase 4.
--
-- Every query is a pure function of (seed, x, z). Heights are memoised per
-- 80x80 mapchunk block, so planning and the writer read one memo per chunk.

-- Seed/session-local FIFO over the horizontal classification. Numeric keys,
-- explicit tuple length so nil holes survive.
local function new_classification_cache(classify, limit)
	local by_x, slots, cursor = {}, {}, 1
	local function tuple(...) return {n = select("#", ...), ...} end
	return function(x, z)
		local row = by_x[x]
		local entry = row and row[z]
		if entry then return unpack(entry.value, 1, entry.value.n) end
		local value = tuple(classify(x, z))
		local old = slots[cursor]
		if old then
			local old_row = by_x[old.x]
			old_row[old.z] = nil
			if next(old_row) == nil then by_x[old.x] = nil end
		end
		row = by_x[x]
		if not row then row = {} by_x[x] = row end
		entry = {x = x, z = z, value = value}
		row[z], slots[cursor] = entry, entry
		cursor = cursor % limit + 1
		return unpack(value, 1, value.n)
	end
end

local function height_factory(dependencies)
	if type(dependencies) ~= "table" then
		error("WP40 height dependencies missing", 0)
	end
	local source = assert(dependencies.source, "WP40 height source missing")
	local deterministic = assert(dependencies.deterministic,
		"WP40 height deterministic dependency missing")
	local horizontal = assert(dependencies.horizontal_session,
		"WP40 height horizontal session missing")
	local terrain_field = assert(dependencies.terrain_field,
		"WP40 height terrain field missing")
	-- Inland water (plan D37/D38): `module` is `water_layout.lua` bound to its
	-- data; `text` the serialized layout main handed over (emerge), else nil
	-- and the session builds it (main, offline tools). The table is shared by
	-- every session of one environment and keeps the built sampler, so a
	-- second session of the same seed does not rebuild. `authored` lists the
	-- authored lakes (see `resolve_authored_lakes`).
	local water_dependency = assert(dependencies.water,
		"WP40 height water layout missing")
	local water_module = assert(water_dependency.module,
		"WP40 height water module missing")

	local WATER_LEVEL = 1
	-- Same query bounds as zones.lua; outside them the world is deep sea.
	local MIN_X, MAX_X, MIN_Z, MAX_Z = -3740, 3740, -3340, 3340
	local OUTSIDE_FLOOR = WATER_LEVEL - 24
	local FEATURE_CELL = 128
	-- Boat water floor (y) and the landing approach radius / ramp in nodes.
	local BOAT_FLOOR_Y, BOAT_APPROACH, BOAT_RAMP = WATER_LEVEL - 9, 100, 24
	-- Memo blocks are mapchunks: 80 nodes, offset by -32 like the engine's.
	local BLOCK, BLOCK_OFFSET, BLOCK_LIMIT = 80, 32, 48
	-- Column classes of the vertical model.
	local LAND, SEA, BAY = 1, 2, 3
	-- POI collar (plan D33): shortest and longest collar in nodes, and how far
	-- a smooth noise stretches or shrinks it around the core (share).
	local POI_BLEND_MIN, POI_BLEND_MAX, POI_EDGE_JITTER = 6, 28, 0.25

	local floor, ceil, abs, max, min, sqrt, exp = math.floor, math.ceil,
		math.abs, math.max, math.min, math.sqrt, math.exp
	local round_ratio = deterministic.round_ratio
	local floor_div = deterministic.floor_div

	local function fail(message)
		error("WP40 height: " .. message, 0)
	end
	local function coordinate(value, label)
		if type(value) ~= "number" or value % 1 ~= 0 then
			fail(label .. " is not an integer coordinate")
		end
	end
	local function clamp(value, minimum, maximum)
		if value < minimum then return minimum end
		if value > maximum then return maximum end
		return value
	end
	-- 1 inside, 0 beyond `width`, a smootherstep between.
	local function weight_at(outside, width)
		if outside <= 0 then return 1 end
		if outside >= width then return 0 end
		local t = outside / width
		return 1 - t * t * t * (t * (t * 6 - 15) + 10)
	end
	local function lerp_node(a, b, weight)
		return floor(a + (b - a) * weight + 0.5)
	end
	local function deep_copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[key] = deep_copy(child) end
		return result
	end
	local function lower_median(values)
		if #values == 0 then return nil end
		table.sort(values)
		return values[floor((#values + 1) / 2)]
	end
	local function in_half_open_square(x, z, center, width)
		local half = width / 2
		return x >= center.x - half and x <= center.x + half - 1 and
			z >= center.z - half and z <= center.z + half - 1
	end
	local function half_open_square_excess(x, z, center, width)
		local half = width / 2
		local dx = max(center.x - half - x, x - (center.x + half - 1), 0)
		local dz = max(center.z - half - z, z - (center.z + half - 1), 0)
		return max(dx, dz)
	end
	-- True distance from (x, z) to the half-open square, 0 inside.
	local function square_distance(x, z, center, width)
		local half = width / 2
		local dx = max(center.x - half - x, x - (center.x + half - 1), 0)
		local dz = max(center.z - half - z, z - (center.z + half - 1), 0)
		if dx == 0 then return dz end
		if dz == 0 then return dx end
		return sqrt(dx * dx + dz * dz)
	end
	local function add_bucket(grid, record, min_x, max_x, min_z, max_z)
		for iz = floor_div(min_z, FEATURE_CELL), floor_div(max_z, FEATURE_CELL) do
			local row = grid[iz]
			if not row then row = {} grid[iz] = row end
			for ix = floor_div(min_x, FEATURE_CELL), floor_div(max_x, FEATURE_CELL) do
				local bucket = row[ix]
				if not bucket then bucket = {} row[ix] = bucket end
				bucket[#bucket + 1] = record
			end
		end
	end
	local function bucket_at(grid, x, z)
		local row = grid[floor_div(z, FEATURE_CELL)]
		return row and row[floor_div(x, FEATURE_CELL)] or nil
	end

	-- Start pad reference: the lower median of 9x9 natural samples, clamped
	-- into every sample's cut/fill interval where that is feasible.
	local function start_reference_value(natural_values, max_cut, max_fill,
			minimum_y)
		local feasible_lower, feasible_upper = -math.huge, math.huge
		local values = {}
		for index = 1, #natural_values do
			local natural = natural_values[index]
			values[index] = natural
			feasible_lower = max(feasible_lower, natural - max_cut)
			feasible_upper = min(feasible_upper, natural + max_fill)
		end
		local preferred = lower_median(values)
		local lower = max(feasible_lower, minimum_y)
		if lower <= feasible_upper then return clamp(preferred, lower, feasible_upper) end
		return max(preferred, minimum_y)
	end

	-- Capital civic reference: the natural centre clamped into the civic
	-- core's cut/fill interval, or its midpoint when that interval is empty.
	local function capital_reference_value(center_natural, feasible_lower,
			feasible_upper, water_min_y)
		local reference
		if feasible_lower <= feasible_upper then
			reference = clamp(center_natural, feasible_lower, feasible_upper)
		else
			reference = round_ratio(feasible_lower + feasible_upper, 2)
		end
		if water_min_y and reference < water_min_y then reference = water_min_y end
		return reference
	end

	-- Capital terraces (settlements.md): round-half-up bins, so every bin is
	-- exactly `step` wide, and the walkable band between two terraces is the
	-- middle of the terraced field's erosion and dilation over a Chebyshev disc
	-- of `step - 1`.
	local function terrace_bin(value, step)
		return floor_div(2 * value + step, 2 * step)
	end
	local CAPITAL_BAND_RADIUS = {[2] = 1, [3] = 2, [4] = 3}
	local function capital_terrace_value(incoming, reference, step,
			civic_outside, max_cut, max_fill, banded)
		local shaped = banded
		if civic_outside == 0 then
			shaped = reference
		elseif civic_outside < 32 then
			shaped = lerp_node(banded, reference, weight_at(civic_outside, 32))
		end
		if civic_outside > 0 then
			shaped = clamp(shaped, incoming - max_cut, incoming + max_fill)
		end
		return shaped
	end

	local module = {}

	local function construct(full_seed_string)
		deterministic.validate_seed(full_seed_string)
		local classified = new_classification_cache(
			horizontal.classification_values_at, 65536)

		-- Column classes. Bays (planned water) and the open sea carry water at
		-- WATER_LEVEL. Inland water (rivers, lakes) stays class LAND: its
		-- surfaces come from the water layout per column, and its banks follow
		-- the inland shore rule, not the sea's.
		local function column_class(x, z)
			local water_class, _, owner = classified(x, z)
			if water_class == "land" then return LAND, owner end
			if water_class == "planned_water" then return BAY, owner end
			return SEA, owner
		end

		local field = terrain_field.new(full_seed_string, {
			zones = source.zones, anchors = source.anchors,
			anchor_profiles = source.anchor_profiles,
			zone_at = function(x, z)
				local class, owner = column_class(x, z)
				return class == LAND and owner or nil
			end,
			land_at = function(x, z) return (column_class(x, z)) == LAND end,
		})
		local edge_noise = terrain_field.simplex(full_seed_string, "start_edge")
		local poi_edge_noise = terrain_field.simplex(full_seed_string, "poi_edge")

		-----------------------------------------------------------------------
		-- Inland water layout (plan D38): built once from the natural field in
		-- main and handed to emerge as text (D37). Both environments sample the
		-- deserialized text, so they agree exactly.
		-----------------------------------------------------------------------
		local WP = water_module.P
		local function water_inputs()
			local land_at = function(x, z) return (column_class(x, z)) == LAND end
			local profiles = {}
			for index = 1, #source.anchor_profiles do
				local row = source.anchor_profiles[index]
				profiles[row.id] = row
			end
			local keepouts, pois = {}, {}
			for index = 1, #source.anchors do
				local a = source.anchors[index]
				local x, z = a.position.x, a.position.z
				if a.slot_id == "start" or a.slot_id == "capital" then
					local start = a.slot_id == "start"
					local e = {x = x, z = z, id = a.id,
						r = start and WP.start_keepout or WP.capital_keepout,
						edge = start and WP.start_keepout_edge or WP.capital_keepout_edge}
					-- A capital's keep-out covers its whole built area: the
					-- farthest corner of its core, plots and fill lots (from the
					-- prepared blueprints) plus a margin; the noise edge only
					-- grows it.
					local reach = not start and water_dependency.capital_reach and
						water_dependency.capital_reach[a.id]
					if reach then
						e.r = max(e.r, reach + WP.capital_keepout_margin)
					end
					-- the lowest natural ground inside the disc (lake rule)
					local g, r = math.huge, e.r * (1 + e.edge)
					for dz = -r, r, 16 do
						for dx = -r, r, 16 do
							if dx * dx + dz * dz <= r * r and land_at(x + dx, z + dz) then
								g = min(g, field.height_at(x + dx, z + dz, true))
							end
						end
					end
					e.ground = g < math.huge and g or nil
					keepouts[#keepouts + 1] = e
				else
					local core = profiles[a.template_id].building_core_width
					-- the lowest natural ground under the core (+4)
					local g, half = math.huge, core / 2 + 4
					for dz = -half, half, 4 do
						for dx = -half, half, 4 do
							if land_at(x + dx, z + dz) then
								g = min(g, field.height_at(x + dx, z + dz, true))
							end
						end
					end
					pois[#pois + 1] = {x = x, z = z, r = core * 0.75, id = a.id,
						ground = g < math.huge and g or nil}
				end
			end
			-- Wetland zones and the water landmarks keep their shallow
			-- depressions as ponds at the spill level.
			local marsh = {}
			for _, id in ipairs(WP.marsh_landmarks) do marsh[id] = true end
			local lms = {}
			for _, l in ipairs(field.landmarks) do
				if marsh[l.id] then lms[#lms + 1] = l end
			end
			local function breach_at(x, z)
				for index = 1, #lms do
					local l = lms[index]
					local dx, dz = x - l.x, z - l.z
					local u = dx * l.ca + dz * l.sa
					local v = -dx * l.sa + dz * l.ca
					if u > l.L then u = u - l.L elseif u < -l.L then u = u + l.L else u = 0 end
					if u * u + v * v <= (l.R + WP.marsh_pad) ^ 2 then return 0, 1 end
				end
				local class, owner = column_class(x, z)
				if class == LAND and owner and
						source.zones[owner].primary_relief_id == WP.marsh_relief then
					return 0, 1
				end
				return nil
			end
			return {field = field, land_at = land_at, simplex = terrain_field.simplex,
				keepouts = keepouts, pois = pois, breach_at = breach_at}
		end
		local water_cache = water_dependency.cache
		if not water_cache or water_cache.seed ~= full_seed_string then
			local text, grid, stats = water_dependency.text, nil, nil
			if text == nil then
				local layout = water_module.build(full_seed_string, water_inputs())
				text, grid, stats = water_module.serialize(layout), layout.grid,
					layout.stats
			end
			water_cache = {seed = full_seed_string, text = text, grid = grid,
				stats = stats, sampler = water_module.sampler(
					water_module.deserialize(text), full_seed_string,
					terrain_field.simplex)}
			water_dependency.cache = water_cache
		end
		local water = water_cache.sampler
		local water_seg_river = water.seg_river
		-- Sealed inland water ids (the planner's column tuple): "river:<n>" is
		-- written as river water, "lake:<n>" as ordinary water (zones.lua gives
		-- a lake's step-face columns river water).
		local river_names, lake_names = {}, {}
		for id in ipairs(water.rivers) do river_names[id] = "river:" .. id end
		for id in ipairs(water.lakes) do lake_names[id] = "lake:" .. id end

		-- Authored lakes (civic water, Moonfall; Round 22 Phase 5 lane W2b).
		-- They are not part of the drainage layout, so no keep-out applies to
		-- them, and they sit on the FITTED terrain (a capital or start core is
		-- graded first). One row:
		--   id        unique text; the column's water id is "lake:<id>"
		--   min_x, min_z, max_x, max_z   bounds of every column it touches
		--   indicator function(x, z) -> m in 0..1, a pure function: wet where
		--             m >= 0.5 and the ground lies below the level, bank fill
		--             to the level where m >= rim (default water LAKE_RIM)
		--   level     absolute surface y, or nil with
		--   anchor, level_offset   the surface relative to that anchor's fitted
		--             reference y (resolved once per session), or
		--   shore_level, level_offset   the lowest fitted ground on the lake's
		--             bank ring (0.4 <= m < 0.5, stride 2), resolved on first use
		--   depth     optional carved bed: inside m >= 0.5 the ground is lowered
		--             to at most level - 1 - (depth - 1) * smoothstep(0.5, 0.9, m)
		--   bed_step  optional: that carve is rounded to steps of this many nodes
		--   bank      optional shore envelope {up, down} in nodes per node of the
		--             distance proxy d = (0.5 - m) * LAKE_PROXY: dry ground is cut
		--             to at most level + up * d and raised to at least
		--             level - down * (d - rim band), faded out towards the
		--             indicator's support edge, so shores become banks and low
		--             rims natural dams instead of walls and one-column dikes
		--   bank_weight optional function(x, z) -> 0..1 scaling that envelope
		--             (0 keeps the ground, e.g. a civic core)
		-- Ordinary water (`default:water_source`), sealed like every inland water.
		local authored, authored_grid = {}, {}
		for index, row in ipairs(water_dependency.authored or {}) do
			local sources = (row.level ~= nil and 1 or 0) +
				(row.anchor ~= nil and 1 or 0) + (row.shore_level and 1 or 0)
			if type(row.id) ~= "string" or row.id == "" or
					type(row.indicator) ~= "function" or
					type(row.min_x) ~= "number" or type(row.max_x) ~= "number" or
					type(row.min_z) ~= "number" or type(row.max_z) ~= "number" or
					sources ~= 1 or (row.bank ~= nil and type(row.bank) ~= "table") then
				fail("authored lake row differs at " .. index)
			end
			local e = {name = "lake:" .. row.id, row = row, indicator = row.indicator,
				min_x = row.min_x, max_x = row.max_x, min_z = row.min_z,
				max_z = row.max_z, level = row.level, depth = row.depth,
				bed_step = row.bed_step, bank = row.bank,
				bank_weight = row.bank_weight,
				rim = row.rim or WP.LAKE_RIM}
			authored[#authored + 1] = e
			-- one node wider, so a column beside the lake knows it is near
			add_bucket(authored_grid, e, e.min_x - 1, e.max_x + 1, e.min_z - 1,
				e.max_z + 1)
		end
		local function authored_near(x, z)
			return #authored > 0 and bucket_at(authored_grid, x, z) ~= nil
		end
		-- Settlement plots (district plots and fill lots, `r7_settlement.
		-- plot_rects`) with the audit's two-node margin: an authored lake's
		-- signed distance is capped at (distance to the plot - PLOT_KEEP), so
		-- its shore, rim band and bank envelope stay off every plot, and the
		-- envelope also fades out between PLOT_CLEAR and PLOT_FADE. A plot keeps
		-- the ground its blueprint was measured on.
		local PLOT_MARGIN, PLOT_KEEP, PLOT_CLEAR, PLOT_FADE, PLOT_REACH = 2, 8, 3, 10, 40
		local plot_grid, plot_count = {}, 0
		for _, r in ipairs(water_dependency.plot_rects or {}) do
			local e = {min_x = r.min_x - PLOT_MARGIN, max_x = r.max_x + PLOT_MARGIN,
				min_z = r.min_z - PLOT_MARGIN, max_z = r.max_z + PLOT_MARGIN}
			add_bucket(plot_grid, e, e.min_x - PLOT_REACH, e.max_x + PLOT_REACH,
				e.min_z - PLOT_REACH, e.max_z + PLOT_REACH)
			plot_count = plot_count + 1
		end
		-- Distance to the nearest plot (margin included), capped at PLOT_REACH.
		local function plot_distance(x, z)
			local list = plot_count > 0 and bucket_at(plot_grid, x, z)
			if not list then return PLOT_REACH end
			local best = PLOT_REACH
			for index = 1, #list do
				local e = list[index]
				local dx = max(e.min_x - x, x - e.max_x, 0)
				local dz = max(e.min_z - z, z - e.max_z, 0)
				if dx < best and dz < best then
					local d = sqrt(dx * dx + dz * dz)
					if d < best then best = d end
				end
			end
			return best
		end

		-----------------------------------------------------------------------
		-- Boat water: the dragon channels, the boat paths and the approach
		-- water around the island landings keep at least nine nodes of water
		-- (boats.md), away from the shore. The shapes are joined by a smooth
		-- minimum of their distances and the edge is moved by noise, and the
		-- floor fades in over the first BOAT_SHORE nodes off the coast, so no
		-- straight trench wall shows in the shallows (seam rules 1-4). Water
		-- columns only; outside the shapes the floor ramps back to the field's
		-- sea floor over BOAT_RAMP nodes.
		-----------------------------------------------------------------------
		local BOAT_SMOOTH, BOAT_JITTER, BOAT_SHORE = 16, 12, 48
		local boat_segments, boat_discs, boat_boxes = {}, {}, {}
		for _, path in ipairs(source.boat_paths or {}) do
			local line = path.centreline
			for index = 1, #line - 1 do
				local a, b = line[index], line[index + 1]
				boat_segments[#boat_segments + 1] = {ax = a.x, az = a.z,
					vx = b.x - a.x, vz = b.z - a.z,
					radius = (path.width or 96) / 2 + 16}
			end
		end
		for _, landing in ipairs(source.island_landings or {}) do
			boat_discs[#boat_discs + 1] = {x = landing.position.x,
				z = landing.position.z, radius = BOAT_APPROACH}
		end
		for _, channel in ipairs(source.channels or {}) do
			local box = {min_x = math.huge, max_x = -math.huge,
				min_z = math.huge, max_z = -math.huge}
			for _, point in ipairs(channel.polygon or {}) do
				box.min_x, box.max_x = min(box.min_x, point.x), max(box.max_x, point.x)
				box.min_z, box.max_z = min(box.min_z, point.z), max(box.max_z, point.z)
			end
			if box.min_x <= box.max_x then boat_boxes[#boat_boxes + 1] = box end
		end
		local boat_noise = terrain_field.simplex(full_seed_string, "boat_edge")
		local boat_distances = {}
		local function boat_floor_at(x, z)
			-- The distances are collected first; the smooth minimum only runs
			-- when a shape is near.
			local nearest, count = math.huge, 0
			local ds = boat_distances
			for index = 1, #boat_segments do
				local g = boat_segments[index]
				local ox, oz = x - g.ax, z - g.az
				local length2 = g.vx * g.vx + g.vz * g.vz
				local t = length2 > 0 and (ox * g.vx + oz * g.vz) / length2 or 0
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
				local ex, ez = ox - t * g.vx, oz - t * g.vz
				local d = sqrt(ex * ex + ez * ez) - g.radius
				count = count + 1 ds[count] = d
				if d < nearest then nearest = d end
			end
			for index = 1, #boat_discs do
				local disc = boat_discs[index]
				local dx, dz = x - disc.x, z - disc.z
				local d = sqrt(dx * dx + dz * dz) - disc.radius
				count = count + 1 ds[count] = d
				if d < nearest then nearest = d end
			end
			for index = 1, #boat_boxes do
				local box = boat_boxes[index]
				local dx = max(box.min_x - x, x - box.max_x, 0)
				local dz = max(box.min_z - z, z - box.max_z, 0)
				local d = sqrt(dx * dx + dz * dz)
				count = count + 1 ds[count] = d
				if d < nearest then nearest = d end
			end
			if nearest >= BOAT_RAMP + BOAT_JITTER then return nil end
			local sum = 0
			for index = 1, count do sum = sum + exp((nearest - ds[index]) / BOAT_SMOOTH) end
			local excess = nearest - BOAT_SMOOTH * math.log(sum) +
				BOAT_JITTER * boat_noise(x / 48, z / 48)
			if excess >= BOAT_RAMP then return nil end
			local weight = 1
			if excess > 0 then
				local t = excess / BOAT_RAMP
				weight = 1 - t * t * (3 - 2 * t)
			end
			local sd = field.coast_signed(x, z)
			local shore = (-sd - 8) / (BOAT_SHORE - 8)
			if shore <= 0 then return nil end
			if shore < 1 then weight = weight * shore * shore * (3 - 2 * shore) end
			return floor(WATER_LEVEL - 1 + (BOAT_FLOOR_Y - WATER_LEVEL + 1) * weight)
		end

		-----------------------------------------------------------------------
		-- Per-chunk memo. One block per mapchunk column, filled lazily per
		-- column; FIFO eviction keeps BLOCK_LIMIT blocks per session.
		-----------------------------------------------------------------------
		local blocks, block_ring, block_cursor = {}, {}, 1
		local memo_hits, memo_misses, block_builds = 0, 0, 0
		local function block_for(x, z)
			local bx = floor_div(x + BLOCK_OFFSET, BLOCK)
			local bz = floor_div(z + BLOCK_OFFSET, BLOCK)
			local key = bx * 1048576 + bz
			local block = blocks[key]
			if block then return block, bx, bz end
			-- natural stage: natural (carved) y, its inland water (nwater,
			-- nkind "river" or "lake", nid) and the bank inputs of a column near
			-- water (bank_d, bank_y, near); fitted stage: terrain before the
			-- shore rule (pre, pkind, pfeature) and the water that stays wet
			-- on it (water, wkind, wid); final stage: terrain ... feature.
			block = {key = key, class = {}, owner = {}, natural = {},
				nwater = {}, nkind = {}, nid = {}, bank_d = {}, bank_y = {},
				near = {}, pre = {}, pkind = {}, pfeature = {}, water = {},
				wkind = {}, wid = {},
				terrain = {}, kind = {}, surface = {}, feature = {}}
			local old = block_ring[block_cursor]
			if old then blocks[old.key] = nil end
			block_ring[block_cursor] = block
			block_cursor = block_cursor % BLOCK_LIMIT + 1
			blocks[key] = block
			block_builds = block_builds + 1
			return block, bx, bz
		end
		-- Returns the memo block and this column's slot with the class and
		-- owner filled. The natural height is filled on first demand only:
		-- coast scans classify far more columns than they ever grade.
		local function column(x, z)
			local block, bx, bz = block_for(x, z)
			local slot = (z + BLOCK_OFFSET - bz * BLOCK) * BLOCK +
				(x + BLOCK_OFFSET - bx * BLOCK) + 1
			if block.class[slot] == nil then
				local class, owner = column_class(x, z)
				block.class[slot] = class
				block.owner[slot] = owner or false
			end
			return block, slot
		end
		local function natural_height_at(x, z)
			local block, slot = column(x, z)
			local natural = block.natural[slot]
			if natural == nil then
				memo_misses = memo_misses + 1
				local land = block.class[slot] == LAND
				if land then
					-- Rivers and lakes carve the natural float field before it
					-- is floored (so the terrain stays an integer node y).
					local h, water_y, kind, id, bank_d, bank_y =
						water.column(x, z, field.height_at(x, z, true))
					natural = floor(h)
					if water_y then
						block.nwater[slot], block.nkind[slot] = water_y, kind
						block.nid[slot] = kind == "river" and
							river_names[water_seg_river[id]] or lake_names[id]
					else
						block.nwater[slot] = false
					end
					block.bank_d[slot], block.bank_y[slot] = bank_d or false,
						bank_y or false
					block.near[slot] = bank_d ~= nil or authored_near(x, z)
				else
					natural = floor(field.height_at(x, z, false))
					local deep_y = boat_floor_at(x, z)
					if deep_y ~= nil and deep_y < natural then natural = deep_y end
				end
				block.natural[slot] = natural
			else
				memo_hits = memo_hits + 1
			end
			return natural
		end
		local function class_owner_at(x, z)
			local block, slot = column(x, z)
			return block.class[slot], block.owner[slot] or nil
		end

		-----------------------------------------------------------------------
		-- Anchor fittings. Starts and capitals sit in the field's calm bowls
		-- (damping keyed to the anchor), so their cores fit the cut/fill limits
		-- of their profile. Every other anchor (a POI) takes its height from the
		-- terrain under its building core and flattens only that core, with a
		-- short collar that follows the core (plan D33).
		-----------------------------------------------------------------------
		local anchor_profile_by_id = {}
		for index = 1, #source.anchor_profiles do
			local row = source.anchor_profiles[index]
			anchor_profile_by_id[row.id] = row
		end
		local anchor_by_id, fittings = {}, {}
		local grids = {start = {}, capital = {}, selected = {}}
		for anchor_index = 1, #source.anchors do
			local anchor = source.anchors[anchor_index]
			anchor_by_id[anchor.id] = anchor
			local selected = horizontal.selected_anchor_by_id(anchor.id) or {
				x = anchor.position.x, z = anchor.position.z,
				selection_mode = anchor.placement_mode == "authored_fixed" and
					"authored_fixed" or "frozen_layout",
				approved_candidate_index = anchor.approved_candidate_index}
			local profile = anchor_profile_by_id[anchor.template_id]
			if not profile then fail("anchor profile reference differs") end
			local is_capital = anchor.slot_id == "capital"
			local is_start = anchor.slot_id == "start"
			local zone = anchor.zone_numeric_id
			local fitting = {numeric_id = anchor_index, id = anchor.id,
				anchor = anchor, profile = profile,
				center = {x = selected.x, z = selected.z},
				selection_mode = selected.selection_mode,
				approved_candidate_index = selected.approved_candidate_index,
				zone_numeric_id = zone, is_capital = is_capital, is_start = is_start}
			if is_start then
				local natural_values = {}
				for sample_z = 0, 8 do
					local offset_z = -64 + floor(sample_z * 127 / 8)
					for sample_x = 0, 8 do
						local offset_x = -64 + floor(sample_x * 127 / 8)
						natural_values[#natural_values + 1] = natural_height_at(
							selected.x + offset_x, selected.z + offset_z)
					end
				end
				fitting.reference_y = start_reference_value(natural_values,
					profile.max_cut, profile.max_fill, WATER_LEVEL + 1)
			elseif is_capital then
				local civic_half = profile.civic_width / 2
				local feasible_lower, feasible_upper, water_floor
				for z = selected.z - civic_half, selected.z + civic_half - 1 do
					for x = selected.x - civic_half, selected.x + civic_half - 1 do
						local class, owner = class_owner_at(x, z)
						if owner == zone and class == LAND then
							local natural = natural_height_at(x, z)
							feasible_lower = max(feasible_lower or -math.huge,
								natural - profile.max_cut)
							feasible_upper = min(feasible_upper or math.huge,
								natural + profile.max_fill)
						elseif owner == zone and class == BAY then
							water_floor = WATER_LEVEL + 1
						end
					end
				end
				local center_natural = natural_height_at(selected.x, selected.z)
				if feasible_lower == nil then
					feasible_lower, feasible_upper = center_natural, center_natural
				end
				fitting.reference_y = capital_reference_value(center_natural,
					feasible_lower, feasible_upper, water_floor)
				fitting.core_range = feasible_upper - feasible_lower
			else
				-- POIs sit in the terrain (plan D33): the core's height is the
				-- lower median of the natural ground under it, and only the
				-- building core is flat.
				local core_half = profile.building_core_width / 2
				local natural_values = {}
				local water_lower
				for z = selected.z - core_half, selected.z + core_half - 1 do
					for x = selected.x - core_half, selected.x + core_half - 1 do
						local class, owner = class_owner_at(x, z)
						if owner == zone and class == LAND then
							natural_values[#natural_values + 1] = natural_height_at(x, z)
						elseif owner == zone and class == BAY then
							water_lower = WATER_LEVEL + 1
						end
					end
				end
				local reference = lower_median(natural_values) or water_lower or
					natural_height_at(selected.x, selected.z)
				reference = max(reference, WATER_LEVEL + 1)
				-- The step at the core's edge sets the collar: short on level
				-- ground, longer on a slope, never beyond POI_BLEND_MAX.
				local step = 0
				for offset = -core_half - 1, core_half do
					local ring = {
						{selected.x + offset, selected.z - core_half - 1},
						{selected.x + offset, selected.z + core_half},
						{selected.x - core_half - 1, selected.z + offset},
						{selected.x + core_half, selected.z + offset}}
					for side = 1, 4 do
						local x, z = ring[side][1], ring[side][2]
						local class, owner = class_owner_at(x, z)
						if owner == zone and class == LAND then
							step = max(step, abs(natural_height_at(x, z) - reference))
						end
					end
				end
				fitting.reference_y = reference
				fitting.blend = clamp(POI_BLEND_MIN + step, POI_BLEND_MIN, POI_BLEND_MAX)
			end
			fittings[anchor_index] = fitting
			local class = is_start and "start" or is_capital and "capital" or "selected"
			local envelope_half = profile.blend_width / 2
			if fitting.blend then
				envelope_half = profile.building_core_width / 2 +
					ceil(fitting.blend / (1 - POI_EDGE_JITTER)) + 1
			end
			add_bucket(grids[class], fitting,
				selected.x - envelope_half, selected.x + envelope_half,
				selected.z - envelope_half, selected.z + envelope_half)
		end

		-- Authored lake levels relative to an anchor's fitted reference.
		for index = 1, #authored do
			local e = authored[index]
			if e.level == nil and not e.row.shore_level then
				local fitted
				for anchor_index = 1, #fittings do
					if fittings[anchor_index].id == e.row.anchor then
						fitted = fittings[anchor_index]
					end
				end
				if not fitted then fail("authored lake anchor differs: " .. e.name) end
				e.level = fitted.reference_y + (e.row.level_offset or 0)
			end
			if (e.level ~= nil or not e.row.shore_level) and
					(type(e.level) ~= "number" or e.level % 1 ~= 0) then
				fail("authored lake level differs: " .. e.name)
			end
		end

		-- Soft start pad edge: the flat square grows outward by 0..6 nodes along
		-- a smooth noise outline and the ramp gives the same amount up, so the
		-- pad itself and the outer envelope edge stay put.
		local function start_edge_offset(x, z)
			local value = edge_noise(x / 24, z / 24)
			return clamp(floor((value + 1) * 3.5), 0, 6)
		end

		-- The capital band reads the natural relief of its neighbours as a
		-- shape, shifted by the centre column's own grade.
		local function band_value(x, z, incoming, reference, step)
			local radius = CAPITAL_BAND_RADIUS[step] or 1
			local datum = reference - incoming + natural_height_at(x, z)
			local centre = reference + step * terrace_bin(natural_height_at(x, z) -
				datum, step)
			local erosion, dilation = centre, centre
			for dz = -radius, radius do
				local az = dz < 0 and -dz or dz
				for dx = -radius, radius do
					local ax = dx < 0 and -dx or dx
					local distance = ax > az and ax or az
					local terrace = reference + step * terrace_bin(
						natural_height_at(x + dx, z + dz) - datum, step)
					local offset = terrace - centre
					if offset <= step and offset >= -step then
						local low, high = terrace + distance, terrace - distance
						if low < erosion then erosion = low end
						if high > dilation then dilation = high end
					end
				end
			end
			return floor_div(erosion + dilation + 1, 2)
		end

		local function fitting_grade_at(grid, x, z, incoming, owner, class)
			local candidates = bucket_at(grid, x, z)
			if not candidates then return nil end
			for index = 1, #candidates do
				local fitting = candidates[index]
				if owner == fitting.zone_numeric_id then
					local profile = fitting.profile
					if class == BAY and not fitting.is_capital and
							not fitting.is_start and
							in_half_open_square(x, z, fitting.center,
								profile.building_core_width) then
						return max(fitting.reference_y, WATER_LEVEL + 1), fitting, true
					elseif class == LAND and fitting.blend then
						-- A POI: the flat building core, then a collar that
						-- follows the core's outline (true distance, so round
						-- corners), its width varied smoothly around the core.
						local outside = square_distance(x, z, fitting.center,
							profile.building_core_width)
						if outside == 0 then return fitting.reference_y, fitting, false end
						local blend = fitting.blend
						local edge = outside * (1 + POI_EDGE_JITTER *
							poi_edge_noise(x / 40, z / 40))
						if edge < blend then
							return lerp_node(incoming, fitting.reference_y,
								weight_at(edge, blend)), fitting, false
						end
					elseif class == LAND then
						local envelope_half = profile.blend_width / 2
						local grade_width = (fitting.is_capital or fitting.is_start) and
							profile.fitting_width or profile.building_core_width
						local outside = half_open_square_excess(x, z, fitting.center,
							grade_width)
						local span = envelope_half - grade_width / 2
						if fitting.is_start then
							local offset = start_edge_offset(x, z)
							outside = max(0, outside - offset)
							span = span - offset
						end
						if outside < span then
							local weight = weight_at(outside, span)
							if fitting.is_capital then
								local step = profile.terrace_step
								local civic_outside = half_open_square_excess(x, z,
									fitting.center, profile.civic_width)
								local shaped = capital_terrace_value(incoming,
									fitting.reference_y, step, civic_outside,
									profile.max_cut, profile.max_fill,
									band_value(x, z, incoming, fitting.reference_y, step))
								return lerp_node(incoming, shaped, weight), fitting, false
							end
							return lerp_node(incoming, fitting.reference_y, weight),
								fitting, false
						end
					end
				end
			end
			return nil
		end

		-----------------------------------------------------------------------
		-- Composition, memoised per column.
		-----------------------------------------------------------------------
		-- Water columns: the field's sea floor, or an anchor platform in a bay.
		local function compose_water(x, z, class, owner, incoming)
			if class == BAY then
				local value, fitting = fitting_grade_at(grids.selected, x, z,
					incoming, owner, class)
				if value ~= nil then
					return value, "anchor_platform", value, fitting.id
				end
			end
			return incoming, nil, nil, nil
		end

		-- Anchor fittings of a land column: terrain y, functional kind, feature.
		local function fit_land(x, z, owner, incoming)
			local terrain_y, kind, feature_id = incoming, nil, nil
			local value, fitting = fitting_grade_at(grids.selected, x, z,
				terrain_y, owner, LAND)
			if value ~= nil then terrain_y, kind, feature_id = value, "land_grade", fitting.id end
			value, fitting = fitting_grade_at(grids.capital, x, z, terrain_y, owner, LAND)
			if value ~= nil then terrain_y, kind, feature_id = value, "land_grade", fitting.id end
			value, fitting = fitting_grade_at(grids.start, x, z, terrain_y, owner, LAND)
			if value ~= nil then terrain_y, kind, feature_id = value, "land_grade", fitting.id end
			return terrain_y, kind, feature_id
		end

		-- Authored lakes on the fitted terrain: an optional carved bed, the
		-- water where the indicator reaches 0.5 and the ground lies below the
		-- level, the bank fill on the rim and the optional shore envelope.
		local function smoothstep(a, b, v)
			local t = (v - a) / (b - a)
			if t <= 0 then return 0 elseif t >= 1 then return 1 end
			return t * t * (3 - 2 * t)
		end
		-- The shore envelope fades out between these distance proxies (the
		-- support edge m = 0 lies at 0.5 * LAKE_PROXY), so it never ends in a
		-- step along the indicator's outline.
		local BANK_FADE0, BANK_FADE1 = 0.3 * WP.LAKE_PROXY, 0.5 * WP.LAKE_PROXY
		-- A `shore_level` lake's surface: the lowest fitted ground on its bank
		-- ring (natural water columns left out), resolved on the first query
		-- that needs it. A pure function of the seed, so every session agrees.
		local function resolve_shore_level(e)
			local low
			for z = e.min_z, e.max_z, 2 do
				for x = e.min_x, e.max_x, 2 do
					local m = e.indicator(x, z)
					if type(m) == "number" and m >= 0.4 and m < 0.5 and
							class_owner_at(x, z) == LAND then
						local natural = natural_height_at(x, z)
						local block, slot = column(x, z)
						if not block.nwater[slot] then
							local y = fit_land(x, z, block.owner[slot] or nil, natural)
							if low == nil or y < low then low = y end
						end
					end
				end
			end
			if low == nil then fail("authored lake has no bank: " .. e.name) end
			e.level = low + (e.row.level_offset or 0)
			return e.level
		end
		-- Also returns the bank inputs of the nearest authored lake (the same
		-- indicator distance proxy as a natural lake), for the bank material.
		-- A column wet in one lake takes that lake's bed and water and no bank
		-- of another; on dry ground every lake's envelope cuts first and the
		-- raises (the rim band hard, containment-critical) win.
		local indicator_scratch = {}
		local function authored_at(x, z, terrain_y, water_y, kind, id)
			local list = bucket_at(authored_grid, x, z)
			if not list then return terrain_y, water_y, kind, id end
			local bank_d, bank_y, wet, wet_m, plot_d
			local ms = indicator_scratch
			for index = 1, #list do
				local e = list[index]
				local m = 0
				if x >= e.min_x and x <= e.max_x and z >= e.min_z and z <= e.max_z then
					m = e.indicator(x, z)
					if type(m) ~= "number" then m = 0 end
				end
				if m > 0 then
					if plot_d == nil then plot_d = plot_distance(x, z) end
					if plot_d < PLOT_REACH then
						local cap = 0.5 + (plot_d - PLOT_KEEP) / WP.LAKE_PROXY
						if m > cap then m = cap < 0 and 0 or cap end
					end
				end
				ms[index] = m
				if m > 0 then
					local level = e.level or resolve_shore_level(e)
					local d = (0.5 - m) * WP.LAKE_PROXY
					if d < 0 then d = 0 end
					if bank_d == nil or d < bank_d then bank_d, bank_y = d, level end
					if m >= 0.5 and (wet_m == nil or m > wet_m) then wet, wet_m = e, m end
				end
			end
			if wet then
				local level = wet.level
				if wet.depth then
					local carve = (wet.depth - 1) * smoothstep(0.5, 0.9, wet_m)
					if wet.bed_step then
						carve = floor(carve / wet.bed_step + 0.5) * wet.bed_step
					end
					local bed = floor(level - 1 - carve)
					if bed < terrain_y then terrain_y = bed end
				end
				if terrain_y < level then
					return terrain_y, level, "lake", wet.name, bank_d, bank_y, true
				end
				return terrain_y, water_y, kind, id, bank_d, bank_y
			end
			if water_y ~= nil then return terrain_y, water_y, kind, id, bank_d, bank_y end
			local hard, raise, cut
			for index = 1, #list do
				local m = ms[index]
				if m > 0 then
					local e = list[index]
					local level = e.level
					local d = (0.5 - m) * WP.LAKE_PROXY
					if d < 0 then d = 0 end
					if m >= e.rim and (hard == nil or level > hard) then hard = level end
					local bank = e.bank
					if bank then
						local w = (1 - smoothstep(BANK_FADE0, BANK_FADE1, d)) *
							smoothstep(PLOT_CLEAR, PLOT_FADE, plot_d)
						if w > 0 and e.bank_weight then w = w * e.bank_weight(x, z) end
						if w > 0 then
							if bank.up then
								local high = level + bank.up * d
								if terrain_y > high then
									local v = terrain_y - (terrain_y - high) * w
									if cut == nil or v < cut then cut = v end
								end
							end
							if bank.down then
								local flat = (0.5 - e.rim) * WP.LAKE_PROXY
								local low = level - bank.down * max(0, d - flat)
								if terrain_y < low then
									local v = terrain_y + (low - terrain_y) * w
									if raise == nil or v > raise then raise = v end
								end
							end
						end
					end
				end
			end
			if cut or raise then
				local y = terrain_y
				if cut and cut < y then y = cut end
				if raise and raise > y then y = raise end
				terrain_y = floor(y + 0.5)
			end
			if hard and terrain_y < hard then terrain_y = hard end
			return terrain_y, water_y, kind, id, bank_d, bank_y
		end

		-- Fitted stage of a land column (memoised): the terrain after the
		-- anchor fittings and authored lakes, before the shore rule, and the
		-- inland water that stays wet on it. A fitting that lifts a wet column
		-- to its water surface makes it dry ground.
		local function land_values_at(x, z)
			local block, slot = column(x, z)
			if block.pre[slot] == nil then
				local natural = natural_height_at(x, z)
				local terrain_y, kind, feature_id = fit_land(x, z,
					block.owner[slot] or nil, natural)
				local water_y = block.nwater[slot] or nil
				local water_kind, water_id
				if water_y then
					if terrain_y < water_y then
						water_kind, water_id = block.nkind[slot], block.nid[slot]
					else
						water_y = nil
					end
				end
				if #authored > 0 then
					local bank_d, bank_y, lake_wet
					terrain_y, water_y, water_kind, water_id, bank_d, bank_y, lake_wet =
						authored_at(x, z, terrain_y, water_y, water_kind, water_id)
					if bank_d and (not block.bank_d[slot] or bank_d < block.bank_d[slot]) then
						block.bank_d[slot], block.bank_y[slot] = bank_d, bank_y
					end
					-- A lake column is water, not the graded ground of a start
					-- or capital: a functional grade would clear its water.
					if lake_wet then kind, feature_id = nil, nil end
				end
				block.pre[slot], block.pkind[slot], block.pfeature[slot] =
					terrain_y, kind or false, feature_id or false
				block.water[slot], block.wkind[slot], block.wid[slot] =
					water_y or false, water_kind or false, water_id or false
			end
			return block, slot
		end

		-- The shore rule: a dry column that touches exposed water takes that
		-- water surface as its own top (world_zones.md §7.4). The field's sea
		-- floor is always below WATER_LEVEL, so only a bay platform can cover
		-- sea water. Beside inland water the neighbour's surface counts; at a
		-- river step two surfaces touch one bank and the HIGHER one decides
		-- (stale-rule D3, as INTEGRATION.md's fallback): nothing spills over
		-- the bank corner and the step face stays a water-water contact inside
		-- the channel. Letting the lower reach decide spilled renewable lake
		-- water over a flat shore in the engine check (Round 22 Phase 5 W2a).
		-- (true lets the lower reach decide instead: the bank then sits at the
		-- lower water and the upper water may spill sideways over it.)
		local STEP_BANK_LOWER = false
		local direction_x, direction_z = {1, -1, 0, 0}, {0, 0, 1, -1}
		local function exposed_shore_at(x, z, near)
			local shore_y
			for direction = 1, 4 do
				local nx, nz = x + direction_x[direction], z + direction_z[direction]
				local class, owner = class_owner_at(nx, nz)
				local y
				if class == SEA then
					y = WATER_LEVEL
				elseif class == BAY then
					local platform = fitting_grade_at(grids.selected, nx, nz,
						WATER_LEVEL - 1, owner, class)
					if platform == nil or platform < WATER_LEVEL then y = WATER_LEVEL end
				elseif near then
					local block, slot = land_values_at(nx, nz)
					y = block.water[slot] or nil
				end
				if y and (shore_y == nil or (STEP_BANK_LOWER and y < shore_y) or
						(not STEP_BANK_LOWER and y > shore_y)) then
					shore_y = y
				end
			end
			return shore_y
		end

		-- Final terrain y, functional kind, functional y, feature id.
		local function final_values_at(x, z)
			local block, slot = column(x, z)
			local terrain_y = block.terrain[slot]
			if terrain_y == nil then
				local class, owner = block.class[slot], block.owner[slot] or nil
				local kind, surface_y, feature_id
				if class == LAND then
					land_values_at(x, z)
					terrain_y = block.pre[slot]
					kind, feature_id = block.pkind[slot] or nil, block.pfeature[slot] or nil
					if not block.water[slot] then
						local shore_y = exposed_shore_at(x, z, block.near[slot])
						if shore_y ~= nil then terrain_y = shore_y end
					end
					surface_y = kind and terrain_y or nil
				else
					terrain_y, kind, surface_y, feature_id = compose_water(x, z, class,
						owner, natural_height_at(x, z))
				end
				block.terrain[slot] = terrain_y
				block.kind[slot] = kind or false
				block.surface[slot] = surface_y or false
				block.feature[slot] = feature_id or false
				return terrain_y, kind, surface_y, feature_id
			end
			return terrain_y, block.kind[slot] or nil, block.surface[slot] or nil,
				block.feature[slot] or nil
		end

		local function outside(x, z)
			return x < MIN_X or x > MAX_X or z < MIN_Z or z > MAX_Z
		end
		local function final_terrain_height_at(x, z)
			coordinate(x, "terrain query x") coordinate(z, "terrain query z")
			if outside(x, z) then return OUTSIDE_FLOOR end
			return (final_values_at(x, z))
		end
		local function final_functional_values_at(x, z)
			coordinate(x, "functional query x") coordinate(z, "functional query z")
			if outside(x, z) then return nil, nil, nil, nil end
			local _, kind, surface_y, feature_id = final_values_at(x, z)
			if kind == nil then return nil, nil, nil, nil end
			return kind, surface_y, feature_id, nil
		end
		-- The water surface y of a water column: the sea level for sea and bay
		-- columns, the inland surface of a wet river or lake column, else nil.
		local function final_water_surface_at(x, z)
			coordinate(x, "water query x") coordinate(z, "water query z")
			if outside(x, z) then return WATER_LEVEL end
			if class_owner_at(x, z) ~= LAND then return WATER_LEVEL end
			local block, slot = land_values_at(x, z)
			return block.water[slot] or nil
		end
		-- "river" or "lake" and the sealed water id of a wet inland column. A
		-- cold column is only computed where the layout says water may lie, so
		-- scattered queries (the world map, spawn checks) stay cheap.
		local function inland_water_at(x, z)
			if outside(x, z) or class_owner_at(x, z) ~= LAND then return nil end
			local block, slot = column(x, z)
			if block.pre[slot] == nil and not water.maybe_wet(x, z) and
					not authored_near(x, z) then
				return nil
			end
			land_values_at(x, z)
			if not block.water[slot] then return nil end
			return block.wkind[slot], block.wid[slot], block.water[slot]
		end

		-----------------------------------------------------------------------
		-- Near-water material (world_zones.md §7.4, plan D27). The coast has no
		-- geometric profile; the rule only reads the final terrain. Low, gentle
		-- ground near water is sand with sparse gravel; steep ground at the
		-- water and cliff edges are gravel or stone; mountain land never gets
		-- sand (its border with other zones is dithered, not a line). Every
		-- threshold is jittered at two noise scales, so material edges follow
		-- the terrain and never run straight. `bank_material` takes
		-- the water surface and the distance to that water as inputs, so lake
		-- and river banks (Phase 5) can reuse it; the sea coast passes the sea
		-- level and the field's true coast distance.
		-----------------------------------------------------------------------
		local shore_noise = terrain_field.simplex(full_seed_string, "shore_material")
		-- Reach of sand and of rock from the water (nodes), the highest sand and
		-- rock above the water surface, the gentle slope limit and the slope
		-- where gravel turns to stone (nodes per node).
		local SAND_REACH, ROCK_REACH, SHORE_JITTER = 40, 24, 16
		local SAND_TOP, ROCK_TOP = 4, 9
		local GENTLE_SLOPE, STONE_SLOPE = 0.5, 1.25
		-- A water column counts at the water surface, so the shore line
		-- itself does not read as a slope.
		local function bank_surface_y(x, z, water_y)
			if outside(x, z) or class_owner_at(x, z) ~= LAND then return water_y end
			local block, slot = land_values_at(x, z)
			if block.water[slot] then return block.water[slot] end
			return (final_values_at(x, z))
		end
		-- "sand", "gravel", "stone" or nil for the dry column (x, z) of zone
		-- `owner` at `distance` nodes from water whose surface is `water_y`.
		-- Mountain character near a zone border: the owner is read at a point
		-- moved up to MOUNTAIN_JITTER nodes by noise, so the sand/rock switch
		-- dithers along an irregular band instead of following the border
		-- line. A moved point off dry land keeps the column's own owner, so
		-- the dragon islands stay rock to their shores.
		local MOUNTAIN_JITTER = 48
		local function mountain_owner_at(x, z, owner)
			local jx = x + floor(MOUNTAIN_JITTER * shore_noise(x / 64 - 57.3, z / 64 + 12.9))
			local jz = z + floor(MOUNTAIN_JITTER * shore_noise(x / 64 + 44.1, z / 64 - 81.7))
			if not outside(jx, jz) then
				local class, jittered = class_owner_at(jx, jz)
				if class == LAND and jittered then owner = jittered end
			end
			return source.zones[owner].primary_relief_id == "mountain"
		end
		local function bank_material(x, z, owner, water_y, distance)
			if distance > SAND_REACH + SHORE_JITTER then return nil end
			local rise = final_values_at(x, z) - water_y
			if rise > SAND_TOP + 4 and distance > ROCK_REACH + 8 then return nil end
			local broad = shore_noise(x / 96, z / 96)
			local fine = shore_noise(x / 9 + 311.7, z / 9 - 97.1)
			local slope = max(
				abs(bank_surface_y(x + 2, z, water_y) - bank_surface_y(x - 2, z, water_y)),
				abs(bank_surface_y(x, z + 2, water_y) - bank_surface_y(x, z - 2, water_y))) / 4
			local mountain = mountain_owner_at(x, z, owner)
			local steep = slope > GENTLE_SLOPE + 0.2 * fine
			if not mountain and not steep and
					distance <= SAND_REACH + SHORE_JITTER * broad and
					rise <= SAND_TOP + 2.5 * broad + 1.5 * fine then
				if fine > 0.55 and broad < -0.2 then return "gravel" end
				return "sand"
			end
			if not (mountain or steep) or distance > ROCK_REACH + 8 * broad then
				return nil
			end
			local cliff = slope > STONE_SLOPE + 0.5 * fine
			if rise <= ROCK_TOP + 3 * broad + fine then
				if cliff or (mountain and broad + 0.5 * fine > 0) then return "stone" end
				return "gravel"
			end
			return cliff and "stone" or nil
		end
		local function dry_owner_at(x, z)
			if outside(x, z) then return nil end
			local class, owner = class_owner_at(x, z)
			if class ~= LAND then return nil end
			return owner
		end
		local function coast_material_at(x, z)
			coordinate(x, "coast query x") coordinate(z, "coast query z")
			local owner = dry_owner_at(x, z)
			if owner == nil then return nil end
			local material = bank_material(x, z, owner, WATER_LEVEL,
				field.coast_signed(x, z))
			if material == nil then
				-- River and lake banks: the same rule with the nearest inland
				-- water's surface and (scaled) distance.
				local block, slot = land_values_at(x, z)
				local distance = block.bank_d[slot]
				if distance and not block.water[slot] then
					material = bank_material(x, z, owner, block.bank_y[slot],
						distance * WP.bank_distance_scale)
				end
			end
			return material
		end
		local function bank_material_at(x, z, water_y, distance)
			coordinate(x, "bank query x") coordinate(z, "bank query z")
			if type(water_y) ~= "number" or type(distance) ~= "number" then
				fail("bank material query needs a water y and a distance")
			end
			local owner = dry_owner_at(x, z)
			if owner == nil then return nil end
			return bank_material(x, z, owner, water_y, distance)
		end

		-----------------------------------------------------------------------
		-- Published records.
		-----------------------------------------------------------------------
		local anchor_records = {}
		for anchor_index = 1, #fittings do
			local fitting = fittings[anchor_index]
			local anchor = fitting.anchor
			local kind, surface_y, feature_id = final_functional_values_at(
				fitting.center.x, fitting.center.z)
			anchor_records[anchor_index] = {id = anchor.id, numeric_id = anchor_index,
				zone_numeric_id = anchor.zone_numeric_id, slot_id = anchor.slot_id,
				template_id = anchor.template_id,
				selection_mode = fitting.selection_mode,
				approved_candidate_index = fitting.approved_candidate_index,
				x = fitting.center.x,
				y = surface_y or final_terrain_height_at(fitting.center.x,
					fitting.center.z),
				z = fitting.center.z,
				platform_kind = kind == "anchor_platform" and kind or nil,
				functional_feature_id = feature_id,
				reference_y = fitting.reference_y}
		end

		local recipe_by_id = {}
		for index = 1, #(source.hard_protection_recipes or {}) do
			local recipe = source.hard_protection_recipes[index]
			recipe_by_id[recipe.id] = recipe
		end
		local hard_records = {}
		for hard_index = 1, #(source.hard_protection or {}) do
			local record = deep_copy(source.hard_protection[hard_index])
			local recipe = recipe_by_id[record.recipe_id]
			if not recipe then fail("hard-protection recipe missing") end
			record.y_min = recipe.y_min
			record.upward_unbounded = recipe.upward_unbounded
			record.y_policy_id = recipe.y_policy_id
			if record.center then
				local _, surface_y = final_functional_values_at(record.center.x,
					record.center.z)
				record.surface_y = surface_y or final_terrain_height_at(
					record.center.x, record.center.z)
			end
			hard_records[hard_index] = record
		end

		local session = {field = field}
		function session.terrain_height_at(x, z)
			return final_terrain_height_at(x, z)
		end
		-- The water surface y of a water column (sea, bay, river, lake), nil on
		-- dry land.
		function session.water_surface_at(x, z)
			return final_water_surface_at(x, z)
		end
		-- Inland water by column (plan D37): a wet river or lake column returns
		-- its kind ("river" or "lake"), its sealed water id ("river:<n>",
		-- "lake:<n>") and its surface y; every other column nil. The planner
		-- seals the bed and banks of every such column and writes ordinary
		-- water for lakes, river water for rivers and for a lake's step faces.
		function session.inland_water_at(x, z)
			coordinate(x, "inland water query x") coordinate(z, "inland water query z")
			return inland_water_at(x, z)
		end
		-- True when a wet river or lake column may lie in the rectangle: a
		-- bucket lookup, so the planner's bed/bank seal scans run only there.
		function session.river_water_in(min_x, min_z, max_x, max_z)
			if water.water_in(min_x, min_z, max_x, max_z) then return true end
			for index = 1, #authored do
				local e = authored[index]
				if min_x <= e.max_x and max_x >= e.min_x and min_z <= e.max_z and
						max_z >= e.min_z then
					return true
				end
			end
			return false
		end
		-- The serialized water layout (the ipc_set payload main hands emerge).
		function session.water_layout_text()
			return water_cache.text
		end
		-- The coarse natural field the water layout was drained on (16-node
		-- grid; `height[k]`/`land[k]` at k = iz * nx + ix, 0-based, x = x0 +
		-- ix * cell): shared with Phase 4 road routing (stale-rule H5). Only in
		-- the environment that built the layout (main); nil in emerge.
		function session.water_coarse_grid()
			return water_cache.grid
		end
		-- Layout construction statistics (main only) and the sampler (tools).
		function session.water_layout_stats()
			return water_cache.stats
		end
		function session.water_sampler()
			return water
		end
		-- "sand", "gravel", "stone" or nil for a dry column near the sea, a
		-- river or a lake.
		function session.coast_material_at(x, z)
			return coast_material_at(x, z)
		end
		-- The same rule for any water body: its surface y and the column's
		-- distance to it (the Phase 5 lake and river bank hook).
		function session.bank_material_at(x, z, water_y, distance)
			return bank_material_at(x, z, water_y, distance)
		end
		-- Soft landmark fields exclude nothing (plan D13, Round 22 Phase 3).
		function session.landmark_excluded_at()
			return false
		end
		function session.functional_surface_values_at(x, z)
			return final_functional_values_at(x, z)
		end
		-- Steps between reaches (world_zones.md §7.4): a wet inland column with
		-- a cardinal wet neighbour whose surface is lower is a step face, a
		-- water-water contact inside the channel. Two step types, by the drop
		-- to the lowest such neighbour: "rapid" (up to rapid_max nodes) and
		-- "fall". Returns kind, nil (no interface), upper y, lower y, nil, nil;
		-- nil for every other column. Content may dress falls; the planner
		-- only validates them (the water is written per column).
		function session.hydrology_transition_values_at(x, z)
			coordinate(x, "transition query x") coordinate(z, "transition query z")
			if outside(x, z) or class_owner_at(x, z) ~= LAND then return nil end
			local block, slot = land_values_at(x, z)
			local upper = block.water[slot]
			if not upper then return nil end
			local lower
			for direction = 1, 4 do
				local nx, nz = x + direction_x[direction], z + direction_z[direction]
				if not outside(nx, nz) and class_owner_at(nx, nz) == LAND then
					local nb, ns = land_values_at(nx, nz)
					local y = nb.water[ns]
					if y and y < upper and (lower == nil or y < lower) then lower = y end
				end
			end
			if lower == nil then return nil end
			return upper - lower <= WP.rapid_max and "rapid" or "fall", nil, upper,
				lower, nil, nil
		end
		-- The natural (pre-fitting) surface, for tools and fit reports.
		function session.natural_height_at(x, z)
			coordinate(x, "natural query x") coordinate(z, "natural query z")
			if outside(x, z) then return OUTSIDE_FLOOR end
			return natural_height_at(x, z)
		end
		function session.selected_anchor_3d_by_id(anchor_id)
			if type(anchor_id) ~= "string" then return nil end
			local anchor = anchor_by_id[anchor_id]
			if not anchor then return nil end
			for index = 1, #fittings do
				if fittings[index].anchor == anchor then
					return deep_copy(anchor_records[index])
				end
			end
			return nil
		end
		function session.hard_protection_volumes()
			return deep_copy(hard_records)
		end
		function session.metrics()
			return {query_lattice_constructions = 0, memo_hits = memo_hits,
				memo_misses = memo_misses, memo_blocks = block_builds}
		end
		return session
	end

	function module.new_runtime(full_seed_string)
		return construct(full_seed_string)
	end
	module.new = module.new_runtime
	return module
end

return height_factory
