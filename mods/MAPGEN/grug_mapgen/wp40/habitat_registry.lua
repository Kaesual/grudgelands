-- Pure plant-habitat vocabulary shared by initial mapgen and runtime renewal.
-- It reads no engine global and owns the renewable/excluded source boundary.
local M = {}

local EXCLUDED = {rock_salt = true, salt_crust = true}

function M.is_renewable(key)
	return type(key) == "string" and not EXCLUDED[key]
end

function M.initial_denominator(key, denominator)
	assert(type(denominator) == "number" and denominator > 0)
	return M.is_renewable(key) and denominator * 2 or denominator
end

-- Expected natural plants per eligible column (or cave-floor node) of one
-- resource source: the writer settles one in `initial_denominator` eligible
-- candidates (world_content.lua hash test, r7_p9g.lua cell budget).
function M.natural_probability(key, denominator)
	return 1 / M.initial_denominator(key, denominator)
end

-- VEGETATION AND ALTITUDE (Round 23 Phase 2, user rulings 2026-09-28;
-- world_zones.md §7.6). One pure rule, read by the mapgen planner
-- (r6_planner.lua: decoration eligibility and budget), the surface selector
-- (r6_content.lua: snow) and runtime renewal (vegetation_density.lua), so
-- the three can never disagree. Every value is a function of (x, z) plus the
-- column's planned terrain height, logical biome and zone: no neighbour
-- column is read. Integer fixed point throughout (ONE = 1.0), identical in
-- LuaJIT and PUC 5.1.
--
-- Decoration classes (`M.decoration_class`):
--   tree        every tree template: thins linearly from the tree start to
--               zero at the tree line, times the forest field (groves and
--               clearings, mean 1) and the dense-forest factor;
--   last_tree   the crags snowy pine: like a tree, but it keeps its full
--               density until LAST_TREE_ONSET above the tree start, so it is
--               the last tree in the band;
--   shrub       the biome's own shrub (ruling 4): 1 below the tree start,
--               rising to SHRUB_PEAK at the tree line, held for SHRUB_HOLD,
--               then down to zero at the tree line + SHRUB_REACH;
--   shrub_band  the same shrub where the biome has none of its own: zero
--               below the tree start, then the shrub curve;
--   cover       ground cover, reeds, dry shrubs of other biomes and the
--               blueberry bush: 1 up to the snow line, 0 above it.
-- A column with snow (cap or dust) hosts no decoration; the planner reads
-- that from the selected surface, renewal from `snow_class`.
local V = {
	ONE = 4096,
	TREE_START = 160, TREE_LINE = 220, SNOW_LINE = 280,
	-- The patchy snow-dust band below the snow line.
	SNOW_BAND = 20, SNOW_PATCH_PERIOD = 10,
	SHRUB_PEAK = 3, SHRUB_HOLD = 20, SHRUB_REACH = 40,
	LAST_TREE_ONSET = 30,
	-- Tree and snow lines shift together by a smooth field of at most
	-- +-JITTER nodes (tongues and bays instead of contour lines).
	JITTER = 15, JITTER_SCALE = 54, JITTER_PERIOD = 80, JITTER_DETAIL = 20,
	WARM_OFFSET = 40,
	-- Forest field: groves (the grove period) broken by clearings (the
	-- clearing period), rescaled per zone so every zone's mean is about ONE:
	-- the raw field is averaged over each zone's land on a fixed grid of
	-- NORMAL_STEP (the same grid in every environment), and the zone scales
	-- are interpolated bilinearly from a SCALE_STEP lattice.
	GROVE_PERIOD = 224, CLEARING_PERIOD = 64, CLEARING_DETAIL = 20,
	GROVE_BASE = 160, GROVE_SPAN = 672,
	CLEARING_LOW = 250, CLEARING_RAMP = 80,
	SCALE_STEP = 64,
	NORMAL_STEP = 16, NORMAL_MIN_X = -3736, NORMAL_MAX_X = 3736,
	NORMAL_MIN_Z = -3336, NORMAL_MAX_Z = 3336,
	-- Densest factor a class can reach, in whole multiples of the catalog
	-- density: the planner's budget multiplier and thinning denominator.
	CLASS_MAX = {tree = 5, last_tree = 5, shrub = 3, shrub_band = 3, cover = 1},
}
V.DENSE = {grug_deep_forest = 3, grug_deep_jungle = 3} -- times 1/2: x1.5
V.WARM_BIOMES = {grug_deep_jungle = true, grug_jungle_edge = true,
	grug_jungle_fringe = true, grug_savanna = true, grug_badlands = true,
	grug_badlands_east = true}
V.WARM_ZONES = {front_skyglass_canopy = true}
M.VEGETATION = V

local ROW_CLASS = {
	crags_snowy_pine = "last_tree",
	meadows_bush = "shrub", pine_hills_pine_bush = "shrub",
	savanna_acacia_bush = "shrub", blight_dry_shrub = "shrub",
	crags_pine_bush = "shrub_band", deep_forest_bush = "shrub_band",
	elf_forest_bush = "shrub_band", bone_forest_dry_shrub = "shrub_band",
	swamp_papyrus = "cover", pine_hills_blueberry_bush = "cover",
}
-- The altitude class of one R6 decoration row (r7_r6_manifest.lua).
function M.decoration_class(row)
	assert(type(row) == "table" and type(row.id) == "string")
	return ROW_CLASS[row.id] or (row.kind == "template" and "tree" or "cover")
end
-- Whether an R6 decoration row also grows in the bare band round a start
-- town or a capital (Round 36 W3): the one-node simple rows (grass, ferns,
-- dry grass, junglegrass, dry shrubs, bone piles; a class-3 simple row would
-- stand 2-4 nodes tall). Trees, bushes and the reeds stay out of the band.
-- The planner, the writer and renewal read the band through the "cover"
-- exclusion purpose (simple_map.lua) for these rows only.
function M.band_cover(row)
	assert(type(row) == "table" and type(row.id) == "string")
	return row.kind == "simple" and row.settlement_class ~= 3
end

-- The rule for one world seed. `land_zone_at(x, z)` (the planner source's
-- horizontal zone of a land column, nil elsewhere) is needed only by the
-- forest field; a rule built without it answers lines and snow only.
function M.vegetation_rule(full_seed, land_zone_at)
	assert(type(full_seed) == "string" and full_seed ~= "")
	assert(land_zone_at == nil or type(land_zone_at) == "function")
	local floor, min, max = math.floor, math.min, math.max
	local ONE = V.ONE
	local phase = 0
	for index = 1, #full_seed do
		phase = (phase * 131 + string.byte(full_seed, index)) % 65521
	end
	-- The integer lattice noise of r6_content.lua (value 0..1023), with
	-- salts of its own.
	local function lattice(x, z, salt)
		local value = (x * 374761 + z * 668265 + phase * 69069 + salt) % 16777213
		value = (value * value) % 16777213
		return floor(((value * 48271) % 16777213) * 1024 / 16777213)
	end
	local function weight(offset, period)
		local t = floor(offset * 1024 / period)
		return floor(t * t * (3072 - 2 * t) / 1048576)
	end
	local function lerp(a, b, t) return a + floor((b - a) * t / 1024) end
	local function noise(x, z, period, salt)
		local ix, iz = floor(x / period), floor(z / period)
		local tx, tz = weight(x - ix * period, period),
			weight(z - iz * period, period)
		return lerp(lerp(lattice(ix, iz, salt), lattice(ix + 1, iz, salt), tx),
			lerp(lattice(ix, iz + 1, salt), lattice(ix + 1, iz + 1, salt), tx), tz)
	end
	local SALT_JITTER, SALT_DETAIL = 40960001, 45613327
	local SALT_GROVE, SALT_CLEARING, SALT_SNOW = 61247111, 23456789, 34567891
	local SALT_CLEARING_DETAIL = 52174633

	local rule = {}
	-- Warm biomes and the Skyglass cloud forest raise every line.
	function rule.offset(biome, zone)
		return (V.WARM_BIOMES[biome] or V.WARM_ZONES[zone]) and V.WARM_OFFSET or 0
	end
	function rule.jitter(x, z)
		local m = floor((3 * noise(x, z, V.JITTER_PERIOD, SALT_JITTER) +
			noise(x, z, V.JITTER_DETAIL, SALT_DETAIL)) / 4)
		local j = floor(((m - 512) * V.JITTER_SCALE + 512) / 1024)
		return max(-V.JITTER, min(V.JITTER, j))
	end
	-- Tree start, tree line and snow line of a column.
	function rule.lines(x, z, biome, zone)
		local shift = rule.offset(biome, zone) + rule.jitter(x, z)
		return V.TREE_START + shift, V.TREE_LINE + shift, V.SNOW_LINE + shift
	end
	-- The raw forest field in ONE units: groves times the open share.
	local function raw_forest(x, z)
		local grove = floor((noise(x, z, V.GROVE_PERIOD, SALT_GROVE) + V.GROVE_BASE) *
			ONE / V.GROVE_SPAN)
		local b = floor((3 * noise(x, z, V.CLEARING_PERIOD, SALT_CLEARING) +
			noise(x, z, V.CLEARING_DETAIL, SALT_CLEARING_DETAIL)) / 4)
		local open = max(0, min(ONE, floor((b - V.CLEARING_LOW) * ONE / V.CLEARING_RAMP)))
		return floor(grove * open / ONE)
	end
	-- Per-zone normalisation: samples and summed raw field of each zone's
	-- land on the fixed grid; the world total serves a zone the grid misses.
	local zone_count, zone_sum, world_count, world_sum = {}, {}, 0, 0
	if land_zone_at then
		for z = V.NORMAL_MIN_Z, V.NORMAL_MAX_Z, V.NORMAL_STEP do
			for x = V.NORMAL_MIN_X, V.NORMAL_MAX_X, V.NORMAL_STEP do
				local zone = land_zone_at(x, z)
				if zone ~= nil then
					local value = raw_forest(x, z)
					zone_count[zone] = (zone_count[zone] or 0) + 1
					zone_sum[zone] = (zone_sum[zone] or 0) + value
					world_count, world_sum = world_count + 1, world_sum + value
				end
			end
		end
		assert(world_sum > 0, "forest field normalisation found no land")
	end
	-- The zone scales (fixed point, SCALE_ONE = 1.0) on a coarse lattice of
	-- SCALE_STEP nodes: each lattice point carries the scale of the zone that
	-- owns it (the world scale on water). Interpolating between lattice
	-- points spreads a zone-border step over one lattice cell.
	local SCALE_ONE, STEP = 65536, V.SCALE_STEP
	local LX0, LX1 = floor(V.NORMAL_MIN_X / STEP), floor(V.NORMAL_MAX_X / STEP) + 1
	local LZ0, LZ1 = floor(V.NORMAL_MIN_Z / STEP), floor(V.NORMAL_MAX_Z / STEP) + 1
	local lattice_scale = {}
	if land_zone_at then
		local world_scale = floor(SCALE_ONE * ONE * world_count / world_sum)
		for iz = LZ0, LZ1 do
			for ix = LX0, LX1 do
				local zone = land_zone_at(ix * STEP, iz * STEP)
				local count, sum = zone_count[zone], zone_sum[zone]
				lattice_scale[(iz - LZ0) * (LX1 - LX0 + 1) + (ix - LX0) + 1] =
					(count and sum > 0) and floor(SCALE_ONE * ONE * count / sum) or
						world_scale
			end
		end
	end
	local function scale_at(ix, iz)
		ix, iz = max(LX0, min(LX1, ix)), max(LZ0, min(LZ1, iz))
		return lattice_scale[(iz - LZ0) * (LX1 - LX0 + 1) + (ix - LX0) + 1]
	end
	-- The forest field of a column in ONE units: the raw field times the
	-- bilinearly interpolated zone scale, so each zone's mean over its land
	-- is about ONE and no zone border shows a step.
	-- The interpolated zone scale times STEP * STEP (SCALE_ONE units).
	local function scale_sum(x, z)
		local ix, iz = floor(x / STEP), floor(z / STEP)
		local tx, tz = x - ix * STEP, z - iz * STEP
		return scale_at(ix, iz) * (STEP - tx) * (STEP - tz) +
			scale_at(ix + 1, iz) * tx * (STEP - tz) +
			scale_at(ix, iz + 1) * (STEP - tx) * tz +
			scale_at(ix + 1, iz + 1) * tx * tz
	end
	function rule.forest(x, z)
		assert(land_zone_at, "the forest field needs the zone source")
		return floor(raw_forest(x, z) * scale_sum(x, z) / (SCALE_ONE * STEP * STEP))
	end
	-- The interpolated zone scale at a column (1.0 = no rescaling; fixtures).
	function rule.forest_scale(x, z)
		assert(land_zone_at, "the forest field needs the zone source")
		return scale_sum(x, z) / (SCALE_ONE * STEP * STEP)
	end
	-- The grid's per-zone samples (fixtures and receipts).
	function rule.forest_normalisation()
		local result = {}
		for zone, count in pairs(zone_count) do
			result[zone] = {count = count, sum = zone_sum[zone]}
		end
		return result, world_count, world_sum
	end
	local LOWEST_LINE = V.TREE_START - V.JITTER
	-- Factors of the five classes at one column, in ONE units:
	-- tree, last_tree, shrub, shrub_band, cover.
	function rule.factors(x, z, terrain_y, biome, zone)
		local forest = rule.forest(x, z)
		local dense = V.DENSE[biome]
		local tree_forest = dense and floor(forest * dense / 2) or forest
		local tree_max = V.CLASS_MAX.tree * ONE
		if tree_forest > tree_max then tree_forest = tree_max end
		if terrain_y < LOWEST_LINE then
			return tree_forest, min(forest, tree_max), ONE, 0, ONE
		end
		local start, line, snow = rule.lines(x, z, biome, zone)
		local band = line - start
		local tree, last, shrub, shrub_band = tree_forest, min(forest, tree_max), ONE, 0
		if terrain_y >= start then
			if terrain_y >= line then
				tree, last = 0, 0
			else
				tree = floor(tree_forest * (line - terrain_y) / band)
				local onset = start + V.LAST_TREE_ONSET
				if terrain_y >= onset then
					last = floor(last * (line - terrain_y) / (line - onset))
				end
			end
			local peak = V.SHRUB_PEAK * ONE
			if terrain_y < line then
				local rise = floor(peak * (terrain_y - start) / band)
				shrub_band = rise
				shrub = ONE + floor((peak - ONE) * (terrain_y - start) / band)
			elseif terrain_y < line + V.SHRUB_HOLD then
				shrub, shrub_band = peak, peak
			elseif terrain_y < line + V.SHRUB_REACH then
				local fall = floor(peak * (line + V.SHRUB_REACH - terrain_y) /
					(V.SHRUB_REACH - V.SHRUB_HOLD))
				shrub, shrub_band = fall, fall
			else
				shrub, shrub_band = 0, 0
			end
		end
		return tree, last, shrub, shrub_band, terrain_y >= snow and 0 or ONE
	end
	local CLASS_INDEX = {tree = 1, last_tree = 2, shrub = 3, shrub_band = 4,
		cover = 5}
	rule.ONE = ONE
	rule.decoration_class = M.decoration_class
	rule.band_cover = M.band_cover
	-- Position of a class in `factors`, and its densest factor in whole
	-- multiples of the catalog density.
	function rule.class_index(class)
		return assert(CLASS_INDEX[class], "unknown vegetation class")
	end
	function rule.class_max(class)
		return assert(V.CLASS_MAX[class], "unknown vegetation class")
	end
	function rule.factor(class, x, z, terrain_y, biome, zone)
		local index = assert(CLASS_INDEX[class], "unknown vegetation class")
		return (select(index, rule.factors(x, z, terrain_y, biome, zone)))
	end
	-- 0 no snow, 1 snow dust in the patchy band below the snow line, 2 the
	-- snow cap (snowblock top with snow dust) at and above it. The surface
	-- selector keeps steep rock faces, shores and towns bare.
	local LOWEST_SNOW = V.SNOW_LINE - V.JITTER - V.SNOW_BAND
	function rule.snow_class(x, z, terrain_y, biome, zone)
		if terrain_y < LOWEST_SNOW then return 0 end
		local _, _, snow = rule.lines(x, z, biome, zone)
		if terrain_y >= snow then return 2 end
		local depth = snow - terrain_y
		if depth > V.SNOW_BAND then return 0 end
		-- Patchy: the covered share rises from 0 at the band's foot to all
		-- at the line; a fine field decides which columns.
		-- (A single octave spans 0..1023 widely: its 3rd..97th percentiles
		-- are about 100..924, the range the threshold sweeps.)
		local patch = noise(x, z, V.SNOW_PATCH_PERIOD, SALT_SNOW)
		return (patch - 100) * V.SNOW_BAND < (V.SNOW_BAND - depth) * 824 and 1 or 0
	end
	return rule
end

-- Density multiplier (a plain number, 1 = catalog density) of one
-- decoration class at a site; `values` holds x, z, terrain_y, biome and
-- zone. Runtime renewal applies it per species (vegetation_density.lua).
function M.vegetation_factor(rule, class, values)
	return rule.factor(class, values.x, values.z, values.terrain_y,
		values.biome, values.zone) / V.ONE
end

local function set(values)
	local result = {}
	for index = 1, #(values or {}) do result[values[index]] = true end
	return result
end

function M.compile_world(row)
	local compiled = {key = row.key, node = row.node, kind = "world", row = row,
		zones = set(row.zones), hosts = {}, shore = row.shore or "none"}
	for biome, values in pairs(row.hosts) do
		compiled.hosts[biome == "any" and "*" or biome] = set(values)
	end
	return compiled
end

function M.compile_p9g(row)
	local compiled = {key = row.key, node = row.source_node, kind = "p9g",
		row = row, zones = set(row.zones), hosts = {},
		shore = row.shore_predicate or "none",
		shore_classes = set(row.shore_water_classes)}
	for index = 1, #row.hosts do
		local host = row.hosts[index]
		local biome = compiled.hosts[host.biome] or {}
		local support = biome[host.support] or {}
		support[host.zone or "*"] = true
		biome[host.support] = support
		compiled.hosts[host.biome] = biome
	end
	return compiled
end

-- Support node names a compiled source accepts in one logical biome and zone
-- (the eligible ground renewal counts), sorted; empty when none.
function M.host_names(source, biome, zone)
	local result = {}
	if source.kind == "world" then
		local supports = source.row.mode == "cave" and source.hosts.stone or
			source.hosts[biome] or source.hosts["*"]
		for name in pairs(supports or {}) do result[#result + 1] = name end
	else
		for name, zones in pairs(source.hosts[biome] or {}) do
			if zones[zone] or zones["*"] then result[#result + 1] = name end
		end
	end
	table.sort(result)
	return result
end

-- The writer's geographic predicate for one candidate site. `values`:
--   mode      "surface" (open ground at the planned surface or on
--             player-made ground) or "cave" (at least two below the planned
--             terrain surface, world_content.lua cave rows);
--   y         the plant position; level the zone's surface mob level
--             (surface rows band by level, world_content.lua), zone, biome
--             (the planner's logical biome) and support (node name below).
-- Shore predicates need neighbouring columns and are answered by the caller
-- (vegetation_density.lua), exactly as the writers do.
function M.habitat_matches(source, values)
	local row = source.row
	if source.kind == "world" then
		if row.mode == "cave" then
			if values.mode ~= "cave" or values.y < row.min or values.y > row.max then
				return false
			end
			local supports = source.hosts.stone
			return supports ~= nil and supports[values.support] == true
		end
		if values.mode ~= "surface" or type(values.level) ~= "number" or
				values.level < row.min or values.level > row.max or
				(#row.zones > 0 and not source.zones[values.zone]) then
			return false
		end
		local supports = source.hosts[values.biome] or source.hosts["*"]
		return supports ~= nil and supports[values.support] == true
	end
	if values.mode ~= "surface" or not source.zones[values.zone] then return false end
	local biome = source.hosts[values.biome]
	local zones = biome and biome[values.support]
	return zones ~= nil and (zones[values.zone] or zones["*"]) == true
end

return M
