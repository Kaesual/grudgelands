-- WP40 vertical model, Round 22 (world_zones.md §7.6).
--
-- One globally queryable surface: the natural float field of
-- `terrain_field.lua`, floored to a node y, with the anchor fittings (starts,
-- capitals, villages, outposts, camps, mines, dragons ...) and the sea shore
-- rule on top. The coast takes its shape from the field alone; only its
-- near-water material is derived here (world_zones.md §7.4, plan D27). Roads and inland water are switched off until
-- their Phase 4/5 rebuild (user ruling "variant (a)"): no route, junction,
-- bank or hydrology grading runs here, and inland planned water is dry land.
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

	local floor, abs, max, min, sqrt = math.floor, math.abs, math.max,
		math.min, math.sqrt
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

		-- Inland planned water (rivers, lakes) is dry land until Phase 5; bays
		-- and the open sea stay water at WATER_LEVEL.
		local function column_class(x, z)
			local water_class, _, owner, bay_id, hydrology_id = classified(x, z)
			if water_class == "land" then return LAND, owner end
			if water_class == "planned_water" then
				if bay_id == nil and hydrology_id ~= nil then return LAND, owner end
				return BAY, owner
			end
			return SEA, owner
		end

		local field = terrain_field.new(full_seed_string, {
			zones = source.zones, anchors = source.anchors,
			zone_at = function(x, z)
				local class, owner = column_class(x, z)
				return class == LAND and owner or nil
			end,
			land_at = function(x, z) return (column_class(x, z)) == LAND end,
		})
		local edge_noise = terrain_field.simplex(full_seed_string, "start_edge")

		-----------------------------------------------------------------------
		-- Boat water: the dragon channels, the boat paths and the approach
		-- water around the island landings keep at least nine nodes of water
		-- (boats.md). Outside the corridors the floor ramps back to the
		-- field's sea floor over BOAT_RAMP nodes.
		-----------------------------------------------------------------------
		local boat_segments, boat_discs = {}, {}
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
		local function boat_floor_at(x, z)
			local water_class = classified(x, z)
			if water_class == "immutable_dragon_channel" then return BOAT_FLOOR_Y end
			local excess = BOAT_RAMP
			for index = 1, #boat_segments do
				local g = boat_segments[index]
				local ox, oz = x - g.ax, z - g.az
				local length2 = g.vx * g.vx + g.vz * g.vz
				local t = length2 > 0 and (ox * g.vx + oz * g.vz) / length2 or 0
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
				local ex, ez = ox - t * g.vx, oz - t * g.vz
				local d = sqrt(ex * ex + ez * ez) - g.radius
				if d < excess then excess = d end
			end
			for index = 1, #boat_discs do
				local disc = boat_discs[index]
				local dx, dz = x - disc.x, z - disc.z
				local d = sqrt(dx * dx + dz * dz) - disc.radius
				if d < excess then excess = d end
			end
			if excess >= BOAT_RAMP then return nil end
			if excess <= 0 then return BOAT_FLOOR_Y end
			return floor(BOAT_FLOOR_Y + (WATER_LEVEL - 1 - BOAT_FLOOR_Y) * excess / BOAT_RAMP)
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
			block = {key = key, class = {}, owner = {}, natural = {},
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
				natural = floor(field.height_at(x, z, land))
				if not land then
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
		local function water_surface_for(class)
			if class == LAND then return nil end
			return WATER_LEVEL
		end

		-----------------------------------------------------------------------
		-- Anchor fittings. Starts and capitals sit in the field's calm bowls
		-- (damping keyed to the anchor), so their cores fit the cut/fill limits
		-- of their profile; every other anchor flattens a compact building core.
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
				local core_half = profile.building_core_width / 2
				local natural_values = {}
				local feasible_lower, feasible_upper, water_lower
				for z = selected.z - core_half, selected.z + core_half - 1 do
					for x = selected.x - core_half, selected.x + core_half - 1 do
						local class, owner = class_owner_at(x, z)
						if owner == zone and class == LAND then
							local natural = natural_height_at(x, z)
							natural_values[#natural_values + 1] = natural
							feasible_lower = max(feasible_lower or -math.huge,
								natural - profile.max_cut)
							feasible_upper = min(feasible_upper or math.huge,
								natural + profile.max_fill)
						elseif owner == zone and class == BAY then
							water_lower = WATER_LEVEL + 1
						end
					end
				end
				local preferred = lower_median(natural_values) or water_lower or
					natural_height_at(selected.x, selected.z)
				if feasible_lower ~= nil and feasible_lower <= feasible_upper then
					fitting.reference_y = clamp(preferred, feasible_lower, feasible_upper)
				elseif feasible_lower ~= nil then
					fitting.reference_y = round_ratio(feasible_lower + feasible_upper, 2)
				else
					fitting.reference_y = preferred
				end
				if water_lower ~= nil then
					fitting.reference_y = max(fitting.reference_y, water_lower)
				end
			end
			fittings[anchor_index] = fitting
			local class = is_start and "start" or is_capital and "capital" or "selected"
			local envelope_half = profile.blend_width / 2
			add_bucket(grids[class], fitting,
				selected.x - envelope_half, selected.x + envelope_half,
				selected.z - envelope_half, selected.z + envelope_half)
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

		-- The sea shore rule: a dry column that touches exposed water takes
		-- that water surface as its own top.
		local direction_x, direction_z = {1, -1, 0, 0}, {0, 0, 1, -1}
		-- The field's sea floor is always below WATER_LEVEL, so only a bay
		-- platform can cover the water.
		local function exposed_shore_at(x, z)
			for direction = 1, 4 do
				local nx, nz = x + direction_x[direction], z + direction_z[direction]
				local class, owner = class_owner_at(nx, nz)
				if class == SEA then return WATER_LEVEL end
				if class == BAY then
					local platform = fitting_grade_at(grids.selected, nx, nz,
						WATER_LEVEL - 1, owner, class)
					if platform == nil or platform < WATER_LEVEL then return WATER_LEVEL end
				end
			end
			return nil
		end

		local function compose_land(x, z, owner, incoming)
			local terrain_y, kind, feature_id = incoming, nil, nil
			local value, fitting = fitting_grade_at(grids.selected, x, z,
				terrain_y, owner, LAND)
			if value ~= nil then terrain_y, kind, feature_id = value, "land_grade", fitting.id end
			value, fitting = fitting_grade_at(grids.capital, x, z, terrain_y, owner, LAND)
			if value ~= nil then terrain_y, kind, feature_id = value, "land_grade", fitting.id end
			value, fitting = fitting_grade_at(grids.start, x, z, terrain_y, owner, LAND)
			if value ~= nil then terrain_y, kind, feature_id = value, "land_grade", fitting.id end
			local shore_y = exposed_shore_at(x, z)
			if shore_y ~= nil then terrain_y = shore_y end
			return terrain_y, kind, kind and terrain_y or nil, feature_id
		end

		-- Final terrain y, functional kind, functional y, feature id.
		local function final_values_at(x, z)
			local block, slot = column(x, z)
			local terrain_y = block.terrain[slot]
			if terrain_y == nil then
				local class, owner = block.class[slot], block.owner[slot] or nil
				local natural = natural_height_at(x, z)
				local kind, surface_y, feature_id
				if class == LAND then
					terrain_y, kind, surface_y, feature_id = compose_land(x, z, owner,
						natural)
				else
					terrain_y, kind, surface_y, feature_id = compose_water(x, z, class,
						owner, natural)
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
		local function final_water_surface_at(x, z)
			coordinate(x, "water query x") coordinate(z, "water query z")
			if outside(x, z) then return WATER_LEVEL end
			return water_surface_for((class_owner_at(x, z)))
		end

		-----------------------------------------------------------------------
		-- Near-water material (world_zones.md §7.4, plan D27). The coast has no
		-- geometric profile; the rule only reads the final terrain. Low, gentle
		-- ground near water is sand with sparse gravel; steep ground at the
		-- water and cliff edges are gravel or stone; mountain land never gets
		-- sand. Every threshold is jittered at two noise scales, so material
		-- edges follow the terrain and never run straight. `bank_material` takes
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
			return (final_values_at(x, z))
		end
		-- "sand", "gravel", "stone" or nil for the dry column (x, z) of zone
		-- `owner` at `distance` nodes from water whose surface is `water_y`.
		local function bank_material(x, z, owner, water_y, distance)
			if distance > SAND_REACH + SHORE_JITTER then return nil end
			local rise = final_values_at(x, z) - water_y
			if rise > SAND_TOP + 4 and distance > ROCK_REACH + 8 then return nil end
			local broad = shore_noise(x / 96, z / 96)
			local fine = shore_noise(x / 9 + 311.7, z / 9 - 97.1)
			local slope = max(
				abs(bank_surface_y(x + 2, z, water_y) - bank_surface_y(x - 2, z, water_y)),
				abs(bank_surface_y(x, z + 2, water_y) - bank_surface_y(x, z - 2, water_y))) / 4
			local mountain = source.zones[owner].primary_relief_id == "mountain"
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
			return bank_material(x, z, owner, WATER_LEVEL, field.coast_signed(x, z))
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
		function session.water_surface_at(x, z)
			return final_water_surface_at(x, z)
		end
		-- "sand", "gravel", "stone" or nil for a dry column near the sea.
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
		-- Inland water transitions are off until Phase 5.
		function session.hydrology_transition_values_at(x, z)
			coordinate(x, "transition query x") coordinate(z, "transition query z")
			return nil, nil, nil, nil, nil, nil
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
