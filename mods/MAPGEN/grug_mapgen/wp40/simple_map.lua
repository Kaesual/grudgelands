-- Round 22 horizontal world session (world_zones.md §2, §7.1-7.5, §13): zone
-- ownership, coast and water classes, levels by zone, geometric neighbours,
-- housing masks and static claim exclusions. Pure: it registers no engine
-- hooks and writes no map. Zone borders and the coastline come from
-- `zone_field.lua` and vary per world seed (D24).
--
-- Usage: dofile("simple_map.lua")(zone_field_module) is the factory the zone
-- authority calls with {source, schemas, canonical, deterministic, raw_sha256}.

return function(zone_field)
	if type(zone_field) ~= "table" or type(zone_field.new_checked) ~= "function" then
		error("WP40 simple map: zone field module missing", 0)
	end

	-- One checked zone field and one set of per-world tables per seed, shared by
	-- every horizontal session of this Lua environment (they are immutable).
	local world_cache = {}

	return function(dependencies)
		if type(dependencies) ~= "table" then
			error("WP40 simple map dependencies missing", 0)
		end
		local source = assert(dependencies.source, "WP40 simple map source missing")
		local schemas = assert(dependencies.schemas, "WP40 simple map schemas missing")
		local canonical = assert(dependencies.canonical,
			"WP40 simple map canonical dependency missing")
		local deterministic = assert(dependencies.deterministic,
			"WP40 simple map deterministic dependency missing")
		local raw_sha256 = assert(dependencies.raw_sha256,
			"WP40 simple map SHA-256 dependency missing")
		local Q = 65536
		local floor, abs, max, min = math.floor, math.abs, math.max, math.min
		-- WP13 playtest round 1 (2026-09-15): hard protection restricts BUILDING,
		-- not growing, so vegetation may enter a start's ten-node protection
		-- apron with a jagged inner edge `1 + offset(x, z)` nodes outside the
		-- 128-node build envelope (one seed-derived value-noise lattice per
		-- start). Zero excess is refused unconditionally.
		local START_APRON_AMPLITUDE = 5
		local START_APRON_PERIOD = 16
		local START_APRON_DOMAIN = "start-apron-vegetation-v1"
		-- Query bounds of the horizontal world; outside is open sea.
		local QUERY_BOUNDS = {min_x = -3740, max_x = 3740, min_z = -3340, max_z = 3340}
		local params = assert(source.zone_field, "WP40 simple map zone field params missing")
		local zones = source.zones

		local function fail(message)
			error("WP40 simple map: " .. message, 0)
		end

		local function in_rectangle(x, z, row, expansion)
			expansion = expansion or 0
			return x >= row.min_x - expansion and x <= row.max_x + expansion and
				z >= row.min_z - expansion and z <= row.max_z + expansion
		end

		local function in_centered_half_open_square(x, z, center, total_width, expansion)
			expansion = expansion or 0
			local width = total_width + 2 * expansion
			local x2, z2 = 2 * x, 2 * z
			return x2 >= 2 * center.x - width and x2 < 2 * center.x + width and
				z2 >= 2 * center.z - width and z2 < 2 * center.z + width
		end

		-- How far a column lies OUTSIDE a centred half-open square of even width:
		-- 0 inside it, 1 on the first ring around it, and so on.
		local function half_open_square_excess(x, z, center, total_width)
			local half = total_width / 2
			local min_x, max_x = center.x - half, center.x + half - 1
			local min_z, max_z = center.z - half, center.z + half - 1
			return max(0, min_x - x, x - max_x, min_z - z, z - max_z)
		end

		local function point_on_segment(x, z, a, b)
			local cross = (x - a.x) * (b.z - a.z) - (z - a.z) * (b.x - a.x)
			if cross ~= 0 then return false end
			return x >= min(a.x, b.x) and x <= max(a.x, b.x) and
				z >= min(a.z, b.z) and z <= max(a.z, b.z)
		end

		local function in_polygon(x, z, points)
			local inside = false
			local previous = points[#points]
			for index = 1, #points do
				local current = points[index]
				if point_on_segment(x, z, previous, current) then return true end
				if (current.z > z) ~= (previous.z > z) then
					local orientation = (previous.x - current.x) * (z - current.z) -
						(previous.z - current.z) * (x - current.x)
					if (previous.z > current.z and orientation > 0) or
							(previous.z < current.z and orientation < 0) then
						inside = not inside
					end
				end
				previous = current
			end
			return inside
		end

		local function segment_within_radius(x, z, a, b, radius)
			local vx, vz = b.x - a.x, b.z - a.z
			local wx, wz = x - a.x, z - a.z
			local length_squared = vx * vx + vz * vz
			if length_squared == 0 then return wx * wx + wz * wz <= radius * radius end
			local dot = wx * vx + wz * vz
			if dot <= 0 then return wx * wx + wz * wz <= radius * radius end
			if dot >= length_squared then
				local dx, dz = x - b.x, z - b.z
				return dx * dx + dz * dz <= radius * radius
			end
			local cross = wx * vz - wz * vx
			return cross * cross <= radius * radius * length_squared
		end

		local function expanded_polygon_member(x, z, points, radius)
			if in_polygon(x, z, points) then return true end
			local previous = points[#points]
			for index = 1, #points do
				local current = points[index]
				if segment_within_radius(x, z, previous, current, radius) then
					return true
				end
				previous = current
			end
			return false
		end

		-- Tapered centreline body (civic water).
		local function tapered_member(row, x, z)
			local points = row.centreline
			for index = 1, #points do
				local p = points[index]
				local dx, dz = x - p.x, z - p.z
				if dx * dx + dz * dz <= p.half_width * p.half_width then return true end
			end
			for index = 1, #points - 1 do
				local a, b = points[index], points[index + 1]
				local vx, vz = b.x - a.x, b.z - a.z
				local length_squared = vx * vx + vz * vz
				local wx, wz = x - a.x, z - a.z
				local dot = wx * vx + wz * vz
				if dot >= 0 and dot <= length_squared and length_squared > 0 then
					local half_width = a.half_width +
						(b.half_width - a.half_width) * dot / length_squared
					local cross = wx * vz - wz * vx
					if cross * cross <= half_width * half_width * length_squared then
						return true
					end
				end
			end
			return false
		end

		local function centreline_bounds(row)
			local bounds = {min_x = math.huge, max_x = -math.huge,
				min_z = math.huge, max_z = -math.huge}
			for index = 1, #row.centreline do
				local p = row.centreline[index]
				local half = p.half_width or 0
				bounds.min_x = min(bounds.min_x, p.x - half)
				bounds.max_x = max(bounds.max_x, p.x + half)
				bounds.min_z = min(bounds.min_z, p.z - half)
				bounds.max_z = max(bounds.max_z, p.z + half)
			end
			return bounds
		end

		local function polygon_bounds(points)
			local bounds = {min_x = math.huge, max_x = -math.huge,
				min_z = math.huge, max_z = -math.huge}
			for index = 1, #points do
				local p = points[index]
				bounds.min_x = min(bounds.min_x, p.x)
				bounds.max_x = max(bounds.max_x, p.x)
				bounds.min_z = min(bounds.min_z, p.z)
				bounds.max_z = max(bounds.max_z, p.z)
			end
			return bounds
		end

		local function is_island_region(region)
			return region == "wyrmglass_island" or region == "stormscale_island"
		end

		-- Fixed start/capital cores (world_zones.md §7.1): the first twelve
		-- anchors. They no longer force ownership; the zone field keeps the
		-- fitting footprint in its zone, and the core only scopes civic water.
		local fixed_cores = {}
		for index = 1, 12 do
			local anchor = source.anchors[index]
			local dims = anchor.slot_id == "start" and source.start_core or source.capital_core
			local half_x, half_z = dims.width_x / 2, dims.width_z / 2
			fixed_cores[#fixed_cores + 1] = {zone = anchor.zone_numeric_id,
				min_x = anchor.position.x - half_x, max_x = anchor.position.x + half_x,
				min_z = anchor.position.z - half_z, max_z = anchor.position.z + half_z}
		end
		local function fixed_core_member(x, z, zone)
			for index = 1, #fixed_cores do
				local core = fixed_cores[index]
				if core.zone == zone and x >= core.min_x and x < core.max_x and
						z >= core.min_z and z < core.max_z then
					return true, core
				end
			end
			return false
		end

		-- Civic water: the only inland water left until Round 22 Phase 5 (water
		-- v2). It is the authored civic hydrology inside a start or capital core.
		local hydrology_depth = {}
		for _, profile in ipairs(source.hydrology_profiles or {}) do
			hydrology_depth[profile.id] = profile.depth
		end
		local civic_by_zone = {}
		for _, row in ipairs(source.hydrology or {}) do
			local zone = row.civic_core_zone_numeric_id
			if zone and (hydrology_depth[row.profile_id] or 0) > 0 then
				local list = civic_by_zone[zone]
				if not list then list = {} civic_by_zone[zone] = list end
				list[#list + 1] = {row = row, bounds = centreline_bounds(row)}
			end
		end
		local function civic_water_at(x, z, zone)
			local list = civic_by_zone[zone]
			if not list then return nil end
			local inside = fixed_core_member(x, z, zone)
			if not inside then return nil end
			for index = 1, #list do
				local entry = list[index]
				if in_rectangle(x, z, entry.bounds, 0) and tapered_member(entry.row, x, z) then
					return entry.row
				end
			end
			return nil
		end

		local channel_bounds = {}
		for _, row in ipairs(source.channels) do channel_bounds[row] = polygon_bounds(row.polygon) end
		local function channel_at(x, z)
			for index = 1, #source.channels do
				local row = source.channels[index]
				if in_rectangle(x, z, channel_bounds[row], 0) and in_polygon(x, z, row.polygon) then
					return row
				end
			end
			return nil
		end

		local bay_by_id = {}
		for _, row in ipairs(source.bays) do bay_by_id[row.id] = row end
		local function bay_mouth_is_deep_ocean(bay, warped_z)
			if bay.deep_ocean_side == "min_z" then return warped_z <= bay.deep_ocean_cut_z end
			return warped_z >= bay.deep_ocean_cut_z
		end

		local shelf_width = source.shelf_width

		-- Level by zone (world_zones.md §2, D20): the published range rises in
		-- three sub-ranges by cumulative integer thirds from the home-facing side
		-- toward the front. Progress is measured along z across the zone's own
		-- extent in this world; the Battlegrounds rise from both sides toward the
		-- middle of their extent, and the dragon islands are flat.
		local function band_ranges(level_min, level_max)
			local count = level_max - level_min + 1
			if count == 1 then
				return {{level_min, level_max}, {level_min, level_max}, {level_min, level_max}}
			elseif count == 2 then
				-- Integer thirds of two levels leave an empty first band.
				return {{level_min, level_min}, {level_min, level_max}, {level_max, level_max}}
			end
			local cut1 = floor(count / 3)
			local cut2 = floor(count * 2 / 3)
			return {
				{level_min, level_min + cut1 - 1},
				{level_min + cut1, level_min + cut2 - 1},
				{level_min + cut2, level_max},
			}
		end
		local function level_from_progress(ranges, t)
			if t < 0 then t = 0 elseif t > 1 then t = 1 end
			local scaled = t * 3
			local band = scaled < 1 and 1 or (scaled < 2 and 2 or 3)
			local range = ranges[band]
			local count = range[2] - range[1] + 1
			local step = floor((scaled - (band - 1)) * count)
			if step >= count then step = count - 1 end
			return range[1] + step
		end

		-- Per-world tables from one raster of the finished zone field: gameplay
		-- neighbours (D14) and each zone's z extent for the level field.
		local function build_world_tables(field)
			local step = params.neighbor_grid
			local c = params.check
			local W = floor((c.max_x - c.min_x) / step) + 1
			local H = floor((c.max_z - c.min_z) / step) + 1
			local sample = field.sample
			local previous_row = {}
			local pair_edges = {}
			local z_values = {}
			for j = 0, H - 1 do
				local z = c.min_z + j * step
				local row = {}
				local left = 0
				for i = 0, W - 1 do
					local n = sample(c.min_x + i * step, z)
					row[i] = n
					if n ~= 0 then
						local list = z_values[n]
						if not list then list = {} z_values[n] = list end
						list[#list + 1] = z
						if left ~= 0 and left ~= n then
							local a, b = min(left, n), max(left, n)
							local key = a * 64 + b
							pair_edges[key] = (pair_edges[key] or 0) + 1
						end
						local below = previous_row[i]
						if below and below ~= 0 and below ~= n then
							local a, b = min(below, n), max(below, n)
							local key = a * 64 + b
							pair_edges[key] = (pair_edges[key] or 0) + 1
						end
					end
					left = n
				end
				previous_row = row
			end
			local neighbors = {}
			for index = 1, #zones do neighbors[index] = {} end
			local pair_count = 0
			for key, edges in pairs(pair_edges) do
				if edges * step >= params.neighbor_min_border then
					local a, b = floor(key / 64), key % 64
					local list_a, list_b = neighbors[a], neighbors[b]
					list_a[#list_a + 1] = zones[b].id
					list_b[#list_b + 1] = zones[a].id
					pair_count = pair_count + 1
				end
			end
			for index = 1, #zones do table.sort(neighbors[index]) end
			local levels = {}
			for index, zone in ipairs(zones) do
				local profile = {ranges = band_ranges(zone.level_min, zone.level_max)}
				local list = z_values[index]
				local lo, hi
				if list and #list >= 8 then
					table.sort(list)
					lo = list[floor(#list * 0.02) + 1]
					hi = list[floor(#list * 0.98) + 1] or list[#list]
				end
				if not lo or hi - lo < 64 then
					lo, hi = zone.hub.z - 250, zone.hub.z + 250
				end
				profile.lo, profile.hi = lo, hi
				if zone.level_min == zone.level_max or is_island_region(zone.macro_region) then
					profile.flat = zone.level_max
				elseif zone.macro_region == "elandor_mainland" then
					profile.mode = "north"
				elseif zone.macro_region == "kragmar_mainland" then
					profile.mode = "south"
				else
					profile.mode = "middle"
				end
				levels[index] = profile
			end
			return {neighbors = neighbors, neighbor_pairs = pair_count, levels = levels}
		end

		local module = {}

		function module.new(full_seed_string)
			if type(full_seed_string) ~= "string" or full_seed_string == "" then
				fail("full seed string differs")
			end
			local hash = deterministic.new_hash(canonical, raw_sha256,
				schemas.simple_map, full_seed_string)
			local world = world_cache[full_seed_string]
			if not world then
				local field = zone_field.new_checked(full_seed_string, source, params)
				world = build_world_tables(field)
				world.field = field
				world_cache[full_seed_string] = world
				local check = field.check
				local log = type(core) == "table" and core.log or nil
				local message = ("[grug_mapgen] zone field: warp scale %.1f after %d " ..
					"tries (%.2f s), %d neighbour pairs"):format(check.scale, #check.tries,
					check.seconds, world.neighbor_pairs)
				if log then
					log(check.scale < 1 and "warning" or "action", message)
					if check.scale < 1 then
						for _, try in ipairs(check.tries) do
							if not try.ok then
								log("warning", ("[grug_mapgen] zone field scale %.1f failed: %s")
									:format(try.scale, table.concat(try.fails, "; ")))
							end
						end
					end
				end
			end
			local field = world.field
			local field_sample = field.sample
			-- One-entry memo: a column's classification and its biome lookup
			-- usually follow each other and share one field sample.
			local last_x, last_z, last_1, last_2, last_3, last_4, last_5
			local function sample(x, z)
				if x ~= last_x or z ~= last_z then
					last_1, last_2, last_3, last_4, last_5 = field_sample(x, z)
					last_x, last_z = x, z
				end
				return last_1, last_2, last_3, last_4, last_5
			end
			local neighbors = world.neighbors
			local levels = world.levels

			local function classification_values_at(x, z)
				local zone, coast, owner = sample(x, z)
				if zone ~= 0 then
					local macro_region = zones[zone].macro_region
					local civic = civic_water_at(x, z, zone)
					if civic then
						return "planned_water", macro_region, zone, nil, civic.id, nil, true, true
					end
					return "land", macro_region, zone, nil, nil, nil,
						(fixed_core_member(x, z, zone)), false
				end
				if coast > -shelf_width * 8 then
					local bay_index, _, warped_z = field.bay_at(x, z)
					if bay_index then
						local bay = source.bays[bay_index]
						if bay_mouth_is_deep_ocean(bay, warped_z) then return "deep_ocean" end
						return "planned_water", zones[owner].macro_region, owner, bay.id
					end
				end
				local channel = channel_at(x, z)
				if channel then
					return "immutable_dragon_channel", nil, nil, nil, nil, channel.id
				end
				if coast > -shelf_width and owner and owner ~= 0 then
					return "coastal_shelf", zones[owner].macro_region, owner
				end
				return "deep_ocean"
			end

			local function zone_level_at(x, z, owner)
				local profile = levels[owner]
				if not profile then return nil end
				if profile.flat then return profile.flat end
				local t
				if profile.mode == "north" then
					t = (z - profile.lo) / (profile.hi - profile.lo)
				elseif profile.mode == "south" then
					t = (profile.hi - z) / (profile.hi - profile.lo)
				else
					local half = (profile.hi - profile.lo) / 2
					t = 1 - abs(z - (profile.lo + half)) / half
				end
				return level_from_progress(profile.ranges, t)
			end

			-- Static claim exclusions (world_zones.md §7.4-7.5): anchor blend
			-- envelopes, active hard cores, civic water, bay water, and the dragon
			-- island/channel coast. Roads and ingress corridors are gone (D9) and
			-- ordinary inland water waits for Phase 5.
			local exclusion_source_by_id = {}
			for _, collection in ipairs({source.anchors, source.hydrology or {},
					source.bays, source.islands, source.channels, source.hard_protection}) do
				for index = 1, #collection do
					exclusion_source_by_id[collection[index].id] = collection[index]
				end
			end
			local hard_recipe_by_id = {}
			for _, row in ipairs(source.hard_protection_recipes) do hard_recipe_by_id[row.id] = row end
			local profile_by_id = {}
			for _, row in ipairs(source.anchor_profiles) do profile_by_id[row.id] = row end
			local island_zone_by_id = {}
			for _, row in ipairs(source.islands) do island_zone_by_id[row.id] = row.zone_numeric_id end
			local BAY_REACH = 450  -- warp + coast noise reach of a bay body (nodes)
			local POI_VEGETATION_MARGIN = 4  -- bare ground around a POI core (nodes)
			local shapes = {}
			for index = 1, #source.claim_exclusions do
				local exclusion = source.claim_exclusions[index]
				local record = exclusion_source_by_id[exclusion.source_id]
				local shape = {numeric_id = index, id = exclusion.id, record = record}
				local recipe = exclusion.recipe_id
				if recipe == "exclude_anchor_blend_v1" then
					shape.kind = "square" shape.center = exclusion.center
					shape.total_width = exclusion.total_width
					local profile = profile_by_id[record.template_id]
					shape.cave_core_width = profile.building_core_width or profile.fitting_width
					-- A start's or capital's blend envelope is terrain, not settlement
					-- ground: a "vegetation" query skips it (its hard core still answers).
					shape.anchor_blend = record.slot_id == "start" or record.slot_id == "capital"
					-- A POI's ground is its building core; its collar is natural
					-- terrain (plan D33), so vegetation grows up to a small margin
					-- around the core instead of stopping at the old blend square.
					if not shape.anchor_blend and profile.building_core_width then
						shape.vegetation_width = profile.building_core_width +
							2 * POI_VEGETATION_MARGIN
					end
				elseif recipe == "exclude_planned_water_v1" and bay_by_id[exclusion.source_id] then
					local b = centreline_bounds(record)
					shape.kind = "bay"
					shape.bounds = {min_x = b.min_x - BAY_REACH, max_x = b.max_x + BAY_REACH,
						min_z = b.min_z - BAY_REACH, max_z = b.max_z + BAY_REACH}
				elseif recipe == "exclude_planned_water_v1" and record and
						record.civic_core_zone_numeric_id and civic_by_zone[record.zone_numeric_id] then
					shape.kind = "civic_water"
					shape.bounds = centreline_bounds(record)
				elseif recipe == "exclude_coast_v1" and island_zone_by_id[exclusion.source_id] then
					local zone = zones[island_zone_by_id[exclusion.source_id]]
					local env = params.island_envelope
					local reach = exclusion.projection_width + 16
					shape.kind = "island_coast" shape.zone = zone.numeric_id
					shape.expansion = exclusion.projection_width
					shape.cave_dry_coast = true
					shape.bounds = {min_x = zone.hub.x - env.half_x - reach,
						max_x = zone.hub.x + env.half_x + reach,
						min_z = zone.hub.z - env.half_z - reach,
						max_z = zone.hub.z + env.half_z + reach}
				elseif recipe == "exclude_coast_v1" then
					shape.kind = "polygon" shape.polygon = record.polygon
					shape.expansion = exclusion.projection_width
					shape.cave_dry_coast = true
					local b = polygon_bounds(record.polygon)
					local e = shape.expansion
					shape.bounds = {min_x = b.min_x - e, max_x = b.max_x + e,
						min_z = b.min_z - e, max_z = b.max_z + e}
				elseif recipe == "exclude_active_core_v1" then
					local hard_recipe = hard_recipe_by_id[record.recipe_id]
					if hard_recipe.shape ~= "polyline_corridor" then
						if record.recipe_id == "hard_start_core_v1" then
							local anchor = exclusion_source_by_id[record.source_anchor_id]
							local envelope = profile_by_id[anchor.template_id].fitting_width
							local apron = (hard_recipe.total_width - envelope) / 2
							if envelope % 2 ~= 0 or apron % 1 ~= 0 or
									apron < START_APRON_AMPLITUDE + 1 then
								fail("start apron cannot carry a jittered treeline")
							end
							shape.start_apron_envelope = envelope
						end
						shape.kind = "square" shape.center = record.center
						shape.total_width = hard_recipe.total_width or 1
					end
				end
				if shape.kind == "square" then
					local half = floor((shape.total_width + 1) / 2)
					shape.bounds = {min_x = shape.center.x - half, max_x = shape.center.x + half,
						min_z = shape.center.z - half, max_z = shape.center.z + half}
				end
				if shape.kind then shapes[#shapes + 1] = shape end
			end
			local exclusion_grid = {}
			local exclusion_cell = 128
			for _, shape in ipairs(shapes) do
				local b = shape.bounds
				for cell_z = floor(b.min_z / exclusion_cell), floor(b.max_z / exclusion_cell) do
					local row = exclusion_grid[cell_z]
					if not row then row = {} exclusion_grid[cell_z] = row end
					for cell_x = floor(b.min_x / exclusion_cell), floor(b.max_x / exclusion_cell) do
						local values = row[cell_x]
						if not values then values = {} row[cell_x] = values end
						values[#values + 1] = shape
					end
				end
			end

			-- The jagged inner treeline of a start's protection apron. One lattice
			-- per start, memoised per corner on demand.
			local apron_lattices = {}
			local function apron_corner(cache, id, ix, iz)
				local row = cache[iz]
				if not row then row = {} cache[iz] = row end
				local value = row[ix]
				if value == nil then
					value = hash.signed_noise(START_APRON_DOMAIN, id, {ix, iz}, 0, 0)
					row[ix] = value
				end
				return value
			end
			local function apron_offset(shape, x, z)
				local cache = apron_lattices[shape.id]
				if not cache then cache = {} apron_lattices[shape.id] = cache end
				local ix = deterministic.floor_div(x, START_APRON_PERIOD)
				local iz = deterministic.floor_div(z, START_APRON_PERIOD)
				local tx = deterministic.smootherstep(deterministic.qfrom_ratio(
					x - ix * START_APRON_PERIOD, START_APRON_PERIOD))
				local tz = deterministic.smootherstep(deterministic.qfrom_ratio(
					z - iz * START_APRON_PERIOD, START_APRON_PERIOD))
				local value = deterministic.qlerp(
					deterministic.qlerp(apron_corner(cache, shape.id, ix, iz),
						apron_corner(cache, shape.id, ix + 1, iz), tx),
					deterministic.qlerp(apron_corner(cache, shape.id, ix, iz + 1),
						apron_corner(cache, shape.id, ix + 1, iz + 1), tx), tz)
				return deterministic.round_ratio(
					(deterministic.clamp(value, -Q, Q) + Q) * START_APRON_AMPLITUDE, 2 * Q)
			end
			local function start_apron_vegetation(shape, x, z)
				local excess = half_open_square_excess(x, z, shape.center,
					shape.start_apron_envelope)
				if excess == 0 then return false end
				return excess >= 1 + apron_offset(shape, x, z)
			end

			local function shape_member(shape, x, z)
				local kind = shape.kind
				if kind == "square" then
					return in_centered_half_open_square(x, z, shape.center, shape.total_width, 0)
				elseif kind == "civic_water" then
					return (civic_water_at(x, z, shape.record.zone_numeric_id)) == shape.record
				elseif kind == "bay" then
					return select(4, classification_values_at(x, z)) == shape.record.id
				elseif kind == "island_coast" then
					local _, coast, owner = sample(x, z)
					return owner == shape.zone and coast > -shape.expansion
				elseif kind == "polygon" then
					return expanded_polygon_member(x, z, shape.polygon, shape.expansion)
				end
				return false
			end

			local function static_exclusion_values_at(x, z, purpose)
				local grid_row = exclusion_grid[floor(z / exclusion_cell)]
				local candidates = grid_row and grid_row[floor(x / exclusion_cell)] or nil
				if not candidates then return nil end
				for index = 1, #candidates do
					local shape = candidates[index]
					if purpose == "cave" and shape.cave_core_width and
							not in_centered_half_open_square(x, z, shape.center,
								shape.cave_core_width, 0) then
						-- Terrain fitting is not occupied ground; keep checking the
						-- overlapping hard cores and water/coast shapes.
					elseif purpose == "cave" and shape.cave_dry_coast and
							classification_values_at(x, z) == "land" then
						-- Island/channel coast claims do not occupy their dry interior.
					elseif shape.anchor_blend and purpose == "vegetation" then
						-- Skipped: the remaining shapes in this bucket still answer.
					elseif purpose == "vegetation" and shape.vegetation_width and
							not in_centered_half_open_square(x, z, shape.center,
								shape.vegetation_width, 0) then
						-- Skipped the same way: outside a POI's core and margin.
					elseif shape.start_apron_envelope and purpose == "vegetation" and
							in_rectangle(x, z, shape.bounds, 0) and
							in_centered_half_open_square(x, z, shape.center,
								shape.total_width, 0) and
							start_apron_vegetation(shape, x, z) then
						-- Skipped the same way: vegetation may enter the apron.
					elseif in_rectangle(x, z, shape.bounds, 0) and shape_member(shape, x, z) then
						return shape.numeric_id, shape.id
					end
				end
				return nil
			end

			-- Housing masks (world_zones.md §7.5, world.md §5): the ten authored
			-- areas follow the new zones; the four coastal areas take their exact
			-- shape from the finished coast inside their authored window.
			local coastal_depth = params.coastal_housing_depth
			local masks, mask_by_id = {}, {}
			for _, row in ipairs(source.housing_masks) do
				local entry = {row = row, id = row.id, zone = row.zone_numeric_id,
					window = row.coastal_window,
					bounds = row.coastal_window or polygon_bounds(row.polygon)}
				masks[#masks + 1] = entry
				mask_by_id[row.id] = entry
			end
			local function mask_member(entry, x, z)
				if not in_rectangle(x, z, entry.bounds, 0) then return false end
				if entry.window then
					local zone, coast = sample(x, z)
					return zone == entry.zone and coast > 0 and coast < coastal_depth
				end
				if not in_polygon(x, z, entry.row.polygon) then return false end
				local _, _, owner = sample(x, z)
				return owner == entry.zone
			end
			local function housing_mask_at(x, z)
				for index = 1, #masks do
					if mask_member(masks[index], x, z) then return masks[index] end
				end
				return nil
			end
			local function housing_point_valid_for_mask(entry, x, z)
				if not mask_member(entry, x, z) then return false end
				local water_class, _, zone = classification_values_at(x, z)
				return water_class == "land" and zone == entry.zone and
					static_exclusion_values_at(x, z) == nil
			end

			local anchor_by_id = {}
			for index = 1, #source.anchors do anchor_by_id[source.anchors[index].id] = source.anchors[index] end
			local zone_index_by_id = {}
			for index, row in ipairs(zones) do zone_index_by_id[row.id] = index end

			local session = {}

			function session.classification_values_at(x, z)
				return classification_values_at(x, z)
			end

			function session.classification_at(x, z)
				local water_class, macro_region, zone_numeric_id, bay_id, hydrology_id,
					channel_id, fixed, civic_water = classification_values_at(x, z)
				return {water_class = water_class, macro_region = macro_region,
					zone_numeric_id = zone_numeric_id, bay_id = bay_id,
					hydrology_id = hydrology_id, channel_id = channel_id,
					fixed = fixed or nil, civic_water = civic_water or nil}
			end

			function session.id_at(x, z)
				local _, _, zone = classification_values_at(x, z)
				return zone and zones[zone].id or nil
			end

			function session.land_at(x, z)
				return (classification_values_at(x, z)) == "land"
			end

			function session.water_class_at(x, z)
				return (classification_values_at(x, z))
			end

			function session.macro_region_at(x, z)
				local _, macro_region = classification_values_at(x, z)
				return macro_region
			end

			-- Approximate signed distance to the coast in nodes (+ = land).
			function session.coast_signed_at(x, z)
				return field.coast_signed(x, z)
			end

			-- Owning zone, second-nearest zone and the warped-space distance to
			-- their border (nodes), for region blending. Land only.
			function session.zone_detail_at(x, z)
				local zone, _, _, border, second = sample(x, z)
				if zone == 0 then return nil end
				return zones[zone].id, second ~= 0 and zones[second] and zones[second].id or nil,
					border
			end

			-- Palette zone and biome-patch lookup point of a land column: the
			-- biome dither of world_zones.md §7.3. Nil over the sea.
			local dither_band = params.biome_dither.band
			function session.biome_lookup_at(x, z)
				local zone, _, _, border = sample(x, z)
				if zone == 0 then return nil end
				local qx, qz = field.dither_point(x, z)
				if border < dither_band then
					local _, _, other = sample(qx, qz)
					if other and other ~= 0 then zone = other end
				end
				return zone, qx, qz
			end

			-- True within `radius` nodes of land (on the field's coast distance).
			function session.expanded_land_at(x, z, radius)
				return field.coast_signed(x, z) > -radius
			end

			function session.warp_at(x, z)
				local warped_x, warped_z = field.warp_at(x, z)
				return {x = warped_x, z = warped_z}
			end

			-- Query bounds of the horizontal world (the pre-Round-22 height stack
			-- reads them from here).
			function session.warp_proof()
				return {min_x = QUERY_BOUNDS.min_x, max_x = QUERY_BOUNDS.max_x,
					min_z = QUERY_BOUNDS.min_z, max_z = QUERY_BOUNDS.max_z}
			end

			-- Surface level of the owning zone (D20), without the start band.
			function session.zone_level_at(x, z, owner)
				return zone_level_at(x, z, owner)
			end

			-- Geometric land neighbours (D14), computed once per world.
			function session.neighbors(zone_id)
				local index = type(zone_id) == "number" and zone_id or zone_index_by_id[zone_id]
				local list = index and neighbors[index]
				if not list then return {} end
				local result = {}
				for i = 1, #list do result[i] = list[i] end
				return result
			end

			function session.zone_field_check()
				local check = field.check
				return {scale = check.scale, tries = #check.tries, seconds = check.seconds}
			end

			-- `purpose`: nil is the territory rule (every exclusion answers);
			-- "vegetation" skips the start/capital blend envelopes and the part of a
			-- start's hard square past its jittered apron treeline; "cave" skips
			-- terrain fitting outside building cores and dry island interiors.
			function session.static_exclusion_values_at(x, z, purpose)
				if purpose ~= nil and purpose ~= "vegetation" and purpose ~= "cave" then
					fail("static exclusion purpose differs")
				end
				if not in_rectangle(x, z, QUERY_BOUNDS, 0) then return nil end
				return static_exclusion_values_at(x, z, purpose)
			end

			function session.selected_anchor_2d(zone_id, slot_id)
				local match
				for index = 1, #source.anchors do
					local row = source.anchors[index]
					local zone = zones[row.zone_numeric_id]
					if (zone_id == zone.id or zone_id == row.zone_numeric_id) and
							row.slot_id == slot_id then
						if match then fail("anchor slot query is ambiguous") end
						match = row
					end
				end
				if not match then return nil end
				return {x = match.position.x, z = match.position.z, anchor_id = match.id,
					selection_mode = match.placement_mode == "authored_fixed" and
						"authored_fixed" or "frozen_layout",
					approved_candidate_index = match.approved_candidate_index}
			end

			function session.selected_anchor_by_id(anchor_id)
				local row = anchor_by_id[anchor_id]
				if not row then return nil end
				return session.selected_anchor_2d(zones[row.zone_numeric_id].id, row.slot_id)
			end

			function session.housing_mask_id_at(x, z)
				local entry = housing_mask_at(x, z)
				return entry and entry.id or nil
			end

			function session.housing_point_valid_for_mask(mask_id, x, z)
				local entry = mask_by_id[mask_id]
				return entry ~= nil and housing_point_valid_for_mask(entry, x, z)
			end

			-- True when the complete 101 by 101 reservation centred here passes
			-- every static exclusion inside one housing mask.
			function session.housing_eligible_at(x, z)
				local entry = housing_mask_at(x, z)
				if not entry then return false end
				local radius = source.housing_policy.reservation_radius
				for dz = -radius, radius do
					for dx = -radius, radius do
						if not housing_point_valid_for_mask(entry, x + dx, z + dz) then
							return false
						end
					end
				end
				return true
			end

			-- Retired with the Round 22 hydrology cut: no lake-edge variation.
			function session.hydrology_edge_at()
				return 0, 0
			end

			return session
		end

		return module
	end
end
