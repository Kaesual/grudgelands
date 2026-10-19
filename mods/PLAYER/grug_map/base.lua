-- Per-world atlas base image (Round 22 D24, world_map.md).
--
-- Coast, zone borders and (from Round 22 Phase 4) roads differ per world
-- seed, so the base cannot ship as a pre-rendered texture. The server renders
-- it once from the public world authority (grug_zones), caches it in the world
-- directory and announces it as startup media. Since Round 44 the region
-- names and the settlement, point-of-interest and boss icons are baked into
-- it (bake.lua): the map window's image carries the names (since Round 47 no
-- icons: the window shows those places in its marker layers, layers.lua),
-- the minimap's its own small icons and no names. Every other marker stays
-- a separate layer (window.lua, minimap.lua).
--
-- Only pure public queries are used (water_class_at, id_at, get,
-- terrain_height_at, and water_query_at for planned water) plus the river centrelines grug_mapgen publishes and the
-- settlement, king and dragon registries: no chunk is generated, loaded or
-- read.
--
-- The image is sent as TILES of at most TILE x TILE pixels (Round 27): the
-- minimap builds its round window with `[combine` from the at most four
-- tiles it overlaps, so the client never copies the whole base per window
-- (`[combine` copies each source image once, imagesource.cpp). The Map tab
-- shows every tile combined into one texture. The minimap always shows a
-- normal-size base (user ruling 2026-10-06), its own variant since Round 44:
-- the render copies its terrain (at high quality scaled down in the same
-- pass) before anything is baked, bakes the small icons into the copy and
-- sends it as `grug_map_mini_*` tiles. Since 0.50.2 the render also makes
-- one transparent overlay per faction at the minimap base's size, red where
-- that faction's Claim Stone may not reach (`grug_map_claim_*` tiles,
-- claim_overlay below); the minimap shows it while a stone is held. Nothing
-- else is sent, so the download is the tiles alone.

local M = {}

-- This file's own source enters the cache key, so any palette or drawing
-- change re-renders cached bases without a manual version bump; so do the
-- baked layer's (bake.lua, the layout) and its art and font versions.
local MODPATH = core.get_modpath(core.get_current_modname())
local SOURCE_PATH = MODPATH .. "/base.lua"
local BAKE_PATH = MODPATH .. "/bake.lua"
local bake = dofile(BAKE_PATH)
local icons = dofile(MODPATH .. "/settlement_icons.lua")
local WORLD = core.get_worldpath()
local CACHE_KEY = WORLD .. "/grug_map_base.key"
M.TILE = 512
M.MASK = "grug_map_minimap_mask.png"
-- Map quality (Round 27 rulings 1-3, Round 51 S3): a server setting for the
-- Map tab's image. Both are 9:8 like the atlas bounds (atlas.lua, +-4050 x
-- +-3600 since Round 51). Normal is about 6.67 nodes per pixel as since
-- Round 22 (1215 x 1080 since the atlas grew); high keeps its pixel count,
-- 2.25 nodes per pixel, and stays below 4096 px per edge (some GPUs hold no
-- larger texture). `minimap` names the size the minimap's base has when it
-- is not the Map tab's own (user ruling 2026-10-06: the minimap shows normal
-- quality on every server).
--
-- Relief samples terrain_height_at on one fixed grid per quality, the same
-- on every server (Round 22 D29: hardware never changes what is produced).
-- Normal keeps the Round 22 step of 8 nodes (about one map pixel); high
-- samples every 4 nodes (about two map pixels), which the bilinear
-- interpolation below keeps smooth. The steps are part of this file's source
-- and therefore of the cache key, so changing one re-renders cached bases.
M.QUALITY = {
	normal = {width = 1215, height = 1080, relief_step = 8, minimap = "normal"},
	high = {width = 3600, height = 3200, relief_step = 4, minimap = "normal"},
}
M.DEFAULT_QUALITY = "normal"
-- The open sea's colour (SEA.open below) as "#rrggbb": the fallback image
-- and the minimap's sea disc beyond the base (minimap.lua).
M.OPEN_SEA_HEX = "#102336"
-- Shown if rendering fails: plain sea, so the markers stay usable.
local FALLBACK_TEXTURE = "[fill:90x80:" .. M.OPEN_SEA_HEX

local function rgb(r, g, b) return {r, g, b} end

-- Lakes and rivers (planned water that is no bay) keep the lake blue.
local LAKE = rgb(62, 118, 152)
-- The sea by depth (Round 51 ruling S1; docs/design/world_map.md "Sea"):
-- bay, belt and channel water is `light` at the waterline, `middle` from
-- `middle_depth` nodes of water on and shades a little further toward
-- `middle_deep` down to `deep_depth`; the open sea is `open`, clearly darker.
-- The depth is sea level (y 1) minus the relief grid's bilinear floor
-- height (the water query's own depth, terrain_height_at, sampled once).
-- The edge between the open sea and the rest is soft: the open sea's share
-- of the pixels in cells of `edge_step` nodes, box-blurred twice by
-- `edge_radius` cells and read bilinearly per pixel, blends the two colours
-- (an edge about 100 nodes wide); a pocket of one class inside the other a
-- few dozen nodes across fades into its surroundings instead of a speck.
local SEA = {
	light = rgb(66, 122, 146), middle = rgb(48, 92, 118), middle_deep = rgb(36, 72, 98),
	open = rgb(16, 35, 54),
	middle_depth = 8, deep_depth = 32, edge_step = 16, edge_radius = 2,
}
M.SEA = SEA
-- The water classes of pass 1 (water_class_at) that are sea: the coast line
-- runs along them and along bays (planned water the water query calls "bay").
local SEA_CLASS = {deep_ocean = true, immutable_dragon_channel = true, coastal_shelf = true}
local COAST = rgb(88, 72, 50)
local REGION = {
	dwarf = rgb(178, 176, 158),
	human = rgb(198, 194, 128),
	elf = rgb(162, 196, 164),
	undead = rgb(168, 158, 170),
	orc = rgb(208, 170, 112),
	troll = rgb(134, 178, 116),
}
local NEUTRAL = rgb(186, 172, 132)
local CONTESTED = rgb(150, 108, 88)
local DRAGON = rgb(128, 106, 150)
-- Lightness offsets that tell neighbouring zones of one region apart.
local ZONE_SHIFT = {0, 13, -11, 7, -6, 17, -15, 3}
local BORDER_SHADE = 0.62

-- Relief (Round 27 ruling 4): hillshading, contour lines and an elevation
-- tint, tuned on images of the user's world (seed 3464175725660475642: land
-- median y 70, 90th percentile 189, highest 488; median slope 0.25 nodes per
-- node). Heights are node y; sea level is 1.
local RELIEF = {
	-- Lambert shading, light from the north-west (map top-left) at
	-- `altitude` degrees; slopes are exaggerated `exaggeration` times. A flat
	-- pixel keeps factor 1; the result is clamped to [shade_min, shade_max].
	altitude = 45, exaggeration = 1.2, shade_min = 0.7, shade_max = 1.18,
	-- A thin darker line where the height crosses a multiple of `contour`
	-- nodes; every `index`-node line a little darker. Where lines would come
	-- closer than `min_gap` pixels, only the index lines are drawn, and none
	-- where even those would.
	contour = 16, index = 64, min_gap = 3,
	contour_shade = 0.9, index_shade = 0.82,
	-- High ground blends toward a light stone colour: nothing below
	-- `tint_low`, `tint_max` at `tint_high` and above. Kept light so the
	-- race-region hues still read on the mountains.
	tint_low = 60, tint_high = 320, tint_max = 0.3, stone = rgb(214, 208, 196),
}
M.RELIEF = RELIEF

local function pack(color, factor)
	factor = factor or 1
	local packed = 0
	for channel = 1, 3 do
		local value = math.floor(color[channel] * factor + 0.5)
		packed = packed * 256 + math.max(0, math.min(255, value))
	end
	return packed
end

-- Zone palette: race-region hue, contested zones pulled toward a dusty red,
-- the level-60 dragon islands violet, and a small lightness step per zone.
local function palette(zones, seen)
	local by_region = {}
	for id in pairs(seen) do
		local record = assert(zones.get(id), "unknown zone " .. id)
		local region = record.race_region or "?"
		by_region[region] = by_region[region] or {}
		table.insert(by_region[region], record)
	end
	local colors = {}
	for _, list in pairs(by_region) do
		table.sort(list, function(a, b) return a.numeric_id < b.numeric_id end)
		for index, record in ipairs(list) do
			local base = REGION[record.race_region] or NEUTRAL
			if record.level_min == 60 then
				base = DRAGON
			elseif record.pvp_rule == "contested" then
				local t = 0.45
				base = rgb(base[1] + (CONTESTED[1] - base[1]) * t,
					base[2] + (CONTESTED[2] - base[2]) * t,
					base[3] + (CONTESTED[3] - base[3]) * t)
			end
			local shift = ZONE_SHIFT[(index - 1) % #ZONE_SHIFT + 1]
			colors[record.id] = rgb(base[1] + shift, base[2] + shift, base[3] + shift)
		end
	end
	return colors
end

-- Roads (Round 22 Phase 4): the routed network as
-- {kind = "road" or "trail", points = {{x = , z = }, ...}} rows from the
-- mapgen loader. render() strokes it onto the base with canvas.polyline and
-- cache_key() folds it into the cache key, so a changed network re-renders
-- the base.
local function road_polylines()
	local mapgen = rawget(_G, "grug_mapgen")
	local wp40 = type(mapgen) == "table" and mapgen.wp40
	local roads = type(wp40) == "table" and wp40.road_polylines
	return type(roads) == "table" and roads or {}
end

local ROAD_STYLE = {road = {color = pack(rgb(112, 84, 52)), radius = 1},
	trail = {color = pack(rgb(132, 104, 70)), radius = 0}}

-- Rivers (Round 22 Phase 5). Lakes are `planned_water` columns and show in
-- the per-pixel pass; rivers are about 7-30 nodes wide, a few map pixels at
-- most, so they are stroked from the water layout's centrelines, as
-- {points = {{x =, z =, w =}, ...}} rows (w = target water width in nodes).
local function river_polylines()
	local mapgen = rawget(_G, "grug_mapgen")
	local wp40 = type(mapgen) == "table" and mapgen.wp40
	local rivers = type(wp40) == "table" and wp40.river_polylines
	return type(rivers) == "table" and rivers or {}
end
local function water_layout_text()
	local mapgen = rawget(_G, "grug_mapgen")
	local wp40 = type(mapgen) == "table" and mapgen.wp40
	local text = type(wp40) == "table" and wp40.water_layout_text
	return type(text) == "string" and text or ""
end
local RIVER_COLOR = pack(LAKE)
-- A river this wide or wider is stroked three pixels wide (radius 1), a
-- narrower one one pixel; one pixel is about 7 nodes. (The Phase 5b water
-- widths are about 1.6x the Phase 5 channel widths this threshold was set
-- for, so the same rivers keep the wide stroke.)
local RIVER_WIDE = 18

-- World-coordinate drawing surface over the packed pixel array, for overlays
-- such as the Phase 4 roads.
local function new_canvas(view, pixels, WIDTH, HEIGHT)
	local canvas = {}
	local sx = WIDTH / (view.max_x - view.min_x)
	local sz = HEIGHT / (view.max_z - view.min_z)
	-- `only`, if given, is a per-pixel predicate: other pixels stay as they are.
	function canvas.plot(x, z, color, radius, only)
		local px = math.floor((x - view.min_x) * sx)
		local py = math.floor((view.max_z - z) * sz)
		for j = py - radius, py + radius do
			for i = px - radius, px + radius do
				if i >= 0 and i < WIDTH and j >= 0 and j < HEIGHT then
					local index = j * WIDTH + i + 1
					if not only or only(index) then pixels[index] = color end
				end
			end
		end
	end
	-- `radius` is a number or a function(a, b, t) of the segment's two points.
	function canvas.polyline(points, color, radius, only)
		for index = 2, #points do
			local a, b = points[index - 1], points[index]
			local steps = math.max(1, math.ceil(math.max(
				math.abs(b.x - a.x) * sx, math.abs(b.z - a.z) * sz)))
			for step = 0, steps do
				local t = step / steps
				canvas.plot(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t,
					color, type(radius) == "function" and radius(a, b, t) or radius,
					only)
			end
		end
	end
	return canvas
end

-- Height and hillshade grids on the fixed relief step.
local function relief_grid(zones, view, step, R)
	local nx = math.ceil((view.max_x - view.min_x) / step) + 1
	local nz = math.ceil((view.max_z - view.min_z) / step) + 1
	local heights = {}
	for gz = 0, nz - 1 do
		local z = view.max_z - gz * step
		for gx = 0, nx - 1 do
			heights[gz * nx + gx + 1] =
				zones.terrain_height_at(view.min_x + gx * step, z)
		end
	end
	-- Light from the north-west (map top-left): a slope rising toward +x or
	-- toward the south (row gz grows southward) faces it. Central differences
	-- give the gradient; Lambert's cosine against the light, divided by the
	-- flat value, is the factor.
	local altitude = math.rad(R.altitude)
	local flat = math.sin(altitude)
	local side = math.cos(altitude) / math.sqrt(2)
	local k = R.exaggeration / (2 * step)
	local lo, hi = R.shade_min, R.shade_max
	local shade = {}
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			local west = heights[gz * nx + math.max(gx - 1, 0) + 1]
			local east = heights[gz * nx + math.min(gx + 1, nx - 1) + 1]
			local north = heights[math.max(gz - 1, 0) * nx + gx + 1]
			local south = heights[math.min(gz + 1, nz - 1) * nx + gx + 1]
			local ge, gs = (east - west) * k, (south - north) * k
			local value = (flat + side * (ge + gs)) /
				math.sqrt(1 + ge * ge + gs * gs) / flat
			shade[gz * nx + gx + 1] = math.max(lo, math.min(hi, value))
		end
	end
	return {height = heights, shade = shade, nx = nx, nz = nz, step = step}
end

-- Bilinear value of `field` (relief.height or relief.shade) at fractional
-- grid position (fx, fz).
local function bilinear(relief, field, fx, fz)
	local ix = math.min(math.floor(fx), relief.nx - 2)
	local iz = math.min(math.floor(fz), relief.nz - 2)
	local tx, tz = fx - ix, fz - iz
	local nx = relief.nx
	local top = iz * nx + ix + 1
	local a, b = field[top], field[top + 1]
	local c, d = field[top + nx], field[top + nx + 1]
	return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz
end

-- `grid` ({nx, nz} and values 1..nx * nz, row by row) box-blurred by
-- `radius` cells along x, then along z; cells beyond an edge repeat the edge
-- cell. Pure.
local function box_blur(grid, nx, nz, radius)
	local out, span = {}, 2 * radius + 1
	local function clamp(v, hi) return v < 0 and 0 or (v > hi and hi or v) end
	for gz = 0, nz - 1 do
		local row = gz * nx + 1
		for gx = 0, nx - 1 do
			local sum = 0
			for k = -radius, radius do sum = sum + grid[row + clamp(gx + k, nx - 1)] end
			out[row + gx] = sum / span
		end
	end
	local result = {}
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			local sum = 0
			for k = -radius, radius do sum = sum + out[clamp(gz + k, nz - 1) * nx + gx + 1] end
			result[gz * nx + gx + 1] = sum / span
		end
	end
	return result
end

-- The colour of sea water `depth` nodes deep whose open-sea share is
-- `open` (0..1), packed (SEA above).
local function sea_color(depth, open)
	local a, b, t
	local md = SEA.middle_depth
	if depth < md then
		a, b, t = SEA.light, SEA.middle, depth > 0 and depth / md or 0
	else
		a, b, t = SEA.middle, SEA.middle_deep, (depth - md) / (SEA.deep_depth - md)
		if t > 1 then t = 1 end
	end
	local c, o = SEA.open, open
	local packed = 0
	for channel = 1, 3 do
		local v = a[channel] + (b[channel] - a[channel]) * t
		v = v + (c[channel] - v) * o
		packed = packed * 256 + math.floor(v + 0.5)
	end
	return packed
end
M.sea_color = sea_color

-- The render size and relief step of `quality` ("normal" or "high"; any
-- other value is normal), and `minimap` {quality, width, height}: the size
-- of the minimap's own copy (nil for a crop). `override` replaces fields:
-- offline tools render crops of a view at their own size, or try other
-- RELIEF values.
function M.spec(quality, override)
	if not M.QUALITY[quality] then quality = M.DEFAULT_QUALITY end
	local base = M.QUALITY[quality]
	local mini = base.minimap and M.QUALITY[base.minimap]
	local spec = {quality = quality, width = base.width, height = base.height,
		relief_step = base.relief_step, relief = RELIEF,
		minimap = mini and {quality = base.minimap, width = mini.width,
			height = mini.height} or nil}
	for key, value in pairs(override or {}) do spec[key] = value end
	-- A crop at its own size is no world base: no minimap copy.
	if override and (override.width or override.height) then spec.minimap = nil end
	return spec
end

-- `pixels` (packed RGB, `width` x `height`) scaled down to `w` x `h`: each
-- source pixel goes to the target pixel its centre lies in, and a target
-- pixel is the rounded mean of its sources. Every target pixel gets at least
-- one source while w <= width and h <= height. Pure.
function M.downscale(pixels, width, height, w, h)
	local floor = math.floor
	local column = {}
	for i = 0, width - 1 do column[i] = floor((i + 0.5) * w / width) end
	local out, r, g, b, n = {}, {}, {}, {}, {}
	local source = 0
	for j = 0, h - 1 do
		for i = 0, w - 1 do r[i], g[i], b[i], n[i] = 0, 0, 0, 0 end
		while source < height and floor((source + 0.5) * h / height) == j do
			local first = source * width + 1
			for i = 0, width - 1 do
				local packed, t = pixels[first + i], column[i]
				r[t] = r[t] + floor(packed / 65536)
				g[t] = g[t] + floor(packed / 256) % 256
				b[t] = b[t] + packed % 256
				n[t] = n[t] + 1
			end
			source = source + 1
		end
		local row = j * w + 1
		for i = 0, w - 1 do
			local count = n[i]
			out[row + i] = (floor(r[i] / count + 0.5) * 256 +
				floor(g[i] / count + 0.5)) * 256 + floor(b[i] / count + 0.5)
		end
	end
	return out
end

-- Encodes `tiles` of the `width`-wide packed image as PNGs (tile.png) with
-- one memoised 4-byte RGBA string per distinct colour; returns their bytes.
local function encode_tiles(pixels, width, tiles)
	local char, bytes_of, total = string.char, {}, 0
	for _, tile in ipairs(tiles) do
		local rows = {}
		for j = tile.y, tile.y + tile.h - 1 do
			local row, first = {}, j * width + tile.x
			for i = 1, tile.w do
				local packed = pixels[first + i]
				local bytes = bytes_of[packed]
				if not bytes then
					bytes = char(math.floor(packed / 65536),
						math.floor(packed / 256) % 256, packed % 256, 255)
					bytes_of[packed] = bytes
				end
				row[i] = bytes
			end
			rows[#rows + 1] = table.concat(row)
		end
		tile.png = core.encode_png(tile.w, tile.h, table.concat(rows), 9)
		total = total + #tile.png
	end
	return total
end

-- The Claim Stone preview (fix 0.50.2, docs/design/housing.md §2): per
-- faction a transparent image at the minimap base's size, red where the
-- faction's claim may not reach. The column part comes from pass 1's arrays
-- (no second zone sampling): a pixel is red when the column rule
-- (`claim.problem`, grug_housing.column_problem) refuses its centre column,
-- the territory asked only where the zone itself is eligible; at high
-- quality a minimap pixel is red when ANY render pixel whose centre lies in
-- it is red, never averaged; then every red pixel is widened by one pixel.
-- The settlement part comes on top, rounded outward: a pixel is red when
-- `claim.feature_in` (the placement check's own query) finds a settlement
-- core or hard footprint within the margin of a column the pixel touches,
-- asked over a quadtree of CLAIM_BLOCK blocks so only the few blocks near a
-- settlement are split down to pixels. So a claim square that touches no red
-- passes the zone and settlement checks; one that only touches red may pass
-- too (the coordinator default "Conservative red").
-- `claim`: {factions, problem, territory_at, feature_in, margin}.
M.CLAIM_PREFIX = "grug_map_claim"
-- RGBA, about 45 % opaque; the minimap draws the claims in the same red.
M.CLAIM_RED = {220, 40, 40, 115}
local CLAIM_RED = string.char(unpack(M.CLAIM_RED))
local CLAIM_CLEAR = string.char(0, 0, 0, 0)
local CLAIM_BLOCK = 64

-- The settlement part as {[pixel index] = true} over the w x h minimap
-- base, and the number of queries asked.
local function claim_features(view, w, h, claim)
	local floor = math.floor
	local npp_x = (view.max_x - view.min_x) / w
	local npp_z = (view.max_z - view.min_z) / h
	-- the columns a pixel span touches (a node covers its column +- 0.5),
	-- with up to one column more on each side
	local function x_lo(i) return floor(view.min_x + i * npp_x - 0.5) end
	local function x_hi(i) return floor(view.min_x + (i + 1) * npp_x + 0.5) end
	local function z_lo(j) return floor(view.max_z - (j + 1) * npp_z - 0.5) end
	local function z_hi(j) return floor(view.max_z - j * npp_z + 0.5) end
	local red, feature_in, margin, asked = {}, claim.feature_in, claim.margin, 0
	local function visit(i0, j0, size)
		local i1, j1 = math.min(i0 + size, w) - 1, math.min(j0 + size, h) - 1
		if i0 > i1 or j0 > j1 then return end
		asked = asked + 1
		if not feature_in(x_lo(i0), z_lo(j1), x_hi(i1), z_hi(j0), margin) then return end
		if size == 1 then
			red[j0 * w + i0 + 1] = true
			return
		end
		local half = size / 2
		visit(i0, j0, half)
		visit(i0 + half, j0, half)
		visit(i0, j0 + half, half)
		visit(i0 + half, j0 + half, half)
	end
	for j = 0, h - 1, CLAIM_BLOCK do
		for i = 0, w - 1, CLAIM_BLOCK do visit(i, j, CLAIM_BLOCK) end
	end
	return red, asked
end

-- The overlays from pass 1's `water` and `owner` arrays: {[faction] = tiles
-- with png} and the counts for the log.
local function claim_overlay(zones, view, spec, water, owner, claim)
	local WIDTH, HEIGHT = spec.width, spec.height
	local w, h = spec.minimap.width, spec.minimap.height
	local floor = math.floor
	local scale_x = (view.max_x - view.min_x) / WIDTH
	local scale_z = (view.max_z - view.min_z) / HEIGHT
	-- the minimap pixel each render pixel's centre lies in (as M.downscale)
	local column, row_of = {}, {}
	for i = 0, WIDTH - 1 do column[i] = floor((i + 0.5) * w / WIDTH) end
	for j = 0, HEIGHT - 1 do row_of[j] = floor((j + 0.5) * h / HEIGHT) end
	-- The zone part per water class and zone id: the faction whose claim may
	-- cover such a column as far as its zone goes, or false. At most one:
	-- the zone's territory rule is one faction's home.
	local factions, problem, territory_at = claim.factions, claim.problem, claim.territory_at
	local eligible, records = {}, {}
	local function zone_faction(class, id)
		local by_id = eligible[class]
		if not by_id then
			by_id = {}
			eligible[class] = by_id
		end
		local known = by_id[id]
		if known == nil then
			known = false
			if id and records[id] == nil then records[id] = zones.get(id) or false end
			local zone = id and records[id] or nil
			for _, faction in ipairs(factions) do
				if not problem(faction, class, zone, false) then
					known = faction
					break
				end
			end
			by_id[id] = known
		end
		return known
	end
	-- Per minimap pixel: the faction every render pixel in it so far allows,
	-- or false once two disagree or one allows none.
	local allowed, asked = {}, 0
	for j = 0, HEIGHT - 1 do
		local z = floor(view.max_z - (j + 0.5) * scale_z)
		local first = row_of[j] * w + 1
		for i = 0, WIDTH - 1 do
			local index = j * WIDTH + i + 1
			local class, id = water[index], owner[index]
			local faction = zone_faction(class, id)
			if faction then
				asked = asked + 1
				if problem(faction, class, records[id] or nil,
						territory_at(floor(view.min_x + (i + 0.5) * scale_x), z)) then
					faction = false
				end
			end
			local target = first + column[i]
			local was = allowed[target]
			if was == nil then
				allowed[target] = faction
			elseif was ~= faction then
				allowed[target] = false
			end
		end
	end
	local features, feature_queries = claim_features(view, w, h, claim)
	local result = {}
	for _, faction in ipairs(factions) do
		-- widened by one pixel: a pixel stays clear only when it and its
		-- eight neighbours allow the faction (outside the base never does)
		local across = {}
		for j = 0, h - 1 do
			local row = j * w + 1
			for i = 0, w - 1 do
				across[row + i] = i > 0 and i < w - 1 and allowed[row + i - 1] == faction and
					allowed[row + i] == faction and allowed[row + i + 1] == faction
			end
		end
		local tiles = M.tiles(w, h, M.CLAIM_PREFIX .. "_" .. faction)
		for _, tile in ipairs(tiles) do
			local rows = {}
			for j = tile.y, tile.y + tile.h - 1 do
				local line = {}
				for i = tile.x, tile.x + tile.w - 1 do
					local index = j * w + i + 1
					local clear = j > 0 and j < h - 1 and across[index - w] and across[index] and
						across[index + w] and not features[index]
					line[#line + 1] = clear and CLAIM_CLEAR or CLAIM_RED
				end
				rows[#rows + 1] = table.concat(line)
			end
			tile.png = core.encode_png(tile.w, tile.h, table.concat(rows), 9)
		end
		result[faction] = tiles
	end
	return result, asked, feature_queries
end

-- `layer` ({items, labels, art}, baked_layer below) is baked into both
-- images, the world map's its names only (Round 47); nil (offline crops)
-- bakes nothing. `claim` (claim_overlay; nil: none) adds the Claim Stone
-- overlays at the minimap copy's size.
local function render(zones, view, spec, layer, claim)
	local WIDTH, HEIGHT, R = spec.width, spec.height, spec.relief
	local started = core.get_us_time()
	local scale_x = (view.max_x - view.min_x) / WIDTH
	local scale_z = (view.max_z - view.min_z) / HEIGHT
	-- Pass 1: one water class and owning zone id per pixel centre; for
	-- planned water the water query tells a bay from a lake or river
	-- (`bay`, sparse), and every pixel counts toward its edge cell's open-sea
	-- share (SEA).
	local edge_step = SEA.edge_step
	local gnx = math.max(2, math.ceil((view.max_x - view.min_x) / edge_step))
	local gnz = math.max(2, math.ceil((view.max_z - view.min_z) / edge_step))
	local cell_x, cell_z, open_count, all_count = {}, {}, {}, {}
	for i = 0, WIDTH - 1 do
		cell_x[i] = math.min(gnx - 1, math.floor((i + 0.5) * scale_x / edge_step))
	end
	for j = 0, HEIGHT - 1 do
		cell_z[j] = math.min(gnz - 1, math.floor((j + 0.5) * scale_z / edge_step))
	end
	for cell = 1, gnx * gnz do open_count[cell], all_count[cell] = 0, 0 end
	local water_query = zones.water_query_at
	local water, owner, seen, bay = {}, {}, {}, {}
	for j = 0, HEIGHT - 1 do
		local z = math.floor(view.max_z - (j + 0.5) * scale_z)
		local cell_row = cell_z[j] * gnx + 1
		for i = 0, WIDTH - 1 do
			local x = math.floor(view.min_x + (i + 0.5) * scale_x)
			local class = zones.water_class_at(x, z)
			local index = j * WIDTH + i + 1
			local id = false
			if class ~= "deep_ocean" and class ~= "immutable_dragon_channel" then
				id = zones.id_at(x, z) or false
				if id then seen[id] = true end
			end
			if class == "planned_water" and water_query(x, z) == "bay" then bay[index] = true end
			local cell = cell_row + cell_x[i]
			all_count[cell] = all_count[cell] + 1
			if class == "deep_ocean" then open_count[cell] = open_count[cell] + 1 end
			water[index], owner[index] = class, id
		end
	end
	local classified = core.get_us_time()
	local colors = palette(zones, seen)
	local relief = relief_grid(zones, view, spec.relief_step, R)
	-- The open-sea share per edge cell, blurred twice (a soft edge).
	local open = {}
	for cell = 1, gnx * gnz do
		open[cell] = all_count[cell] > 0 and open_count[cell] / all_count[cell] or 1
	end
	open = box_blur(box_blur(open, gnx, gnz, SEA.edge_radius), gnx, gnz, SEA.edge_radius)
	local edge = {nx = gnx, nz = gnz}
	local shaded = core.get_us_time()

	-- Pass 2: sea and bay water take their colour by depth and open-sea
	-- share (SEA), lakes the lake blue; land takes its zone colour, tinted
	-- toward stone with height, times the hillshade; a contour line darkens
	-- it further. A land pixel next to sea or bay water is coast; a land
	-- pixel whose right or lower neighbour belongs to another zone is a
	-- border line.
	local pixels = {}
	local lake = pack(LAKE)
	local function sea(index) return SEA_CLASS[water[index]] or bay[index] end
	local coast = pack(COAST)
	local stone, tint_low = R.stone, R.tint_low
	local tint_span, tint_max = R.tint_high - R.tint_low, R.tint_max
	local contour, index_step = R.contour, R.index
	-- Height change per pixel above which lines would crowd closer than
	-- min_gap pixels.
	local crowded, too_crowded = contour / R.min_gap, index_step / R.min_gap
	local floor, abs = math.floor, math.abs
	local above = {}
	for j = 0, HEIGHT - 1 do
		local fz = (j + 0.5) * scale_z / relief.step
		local ez = math.max(0, math.min(gnz - 1, (j + 0.5) * scale_z / edge_step - 0.5))
		local left
		for i = 0, WIDTH - 1 do
			local index = j * WIDTH + i + 1
			local class = water[index]
			local fx = (i + 0.5) * scale_x / relief.step
			local h = bilinear(relief, relief.height, fx, fz)
			if class ~= "land" then
				if class == "planned_water" and not bay[index] then
					pixels[index] = lake
				else
					local ex = math.max(0, math.min(gnx - 1, (i + 0.5) * scale_x / edge_step - 0.5))
					pixels[index] = sea_color(1 - h, bilinear(edge, open, ex, ez))
				end
			elseif (i > 0 and sea(index - 1)) or
					(i < WIDTH - 1 and sea(index + 1)) or
					(j > 0 and sea(index - WIDTH)) or
					(j < HEIGHT - 1 and sea(index + WIDTH)) then
				pixels[index] = coast
			else
				local id = owner[index]
				local factor = bilinear(relief, relief.shade, fx, fz)
				local right = i < WIDTH - 1 and owner[index + 1]
				local below = j < HEIGHT - 1 and owner[index + WIDTH]
				if (right and right ~= id) or (below and below ~= id) then
					factor = factor * BORDER_SHADE
				end
				-- A contour runs between this pixel and its left or upper
				-- neighbour when they lie in different height bands.
				local up = above[i]
				if left and up then
					local change = math.max(abs(h - left), abs(h - up))
					if change <= too_crowded then
						local band = floor(h / index_step)
						if band ~= floor(left / index_step) or
								band ~= floor(up / index_step) then
							factor = factor * R.index_shade
						elseif change <= crowded then
							band = floor(h / contour)
							if band ~= floor(left / contour) or
									band ~= floor(up / contour) then
								factor = factor * R.contour_shade
							end
						end
					end
				end
				local color = colors[id] or NEUTRAL
				local t = (h - tint_low) / tint_span
				if t > 0 then
					t = (t < 1 and t or 1) * tint_max
					color = rgb(color[1] + (stone[1] - color[1]) * t,
						color[2] + (stone[2] - color[2]) * t,
						color[3] + (stone[3] - color[3]) * t)
				end
				pixels[index] = pack(color, factor)
			end
			above[i], left = h, h
		end
	end

	-- Rivers go on land only (their mouths and lake reaches are water
	-- pixels already), under the roads. The stroke is about the river's own
	-- width (radius 0 is one pixel), at least three pixels from RIVER_WIDE.
	local canvas = new_canvas(view, pixels, WIDTH, HEIGHT)
	local function on_land(index) return water[index] == "land" end
	local function river_radius(a, b, t)
		local w = a.w + (b.w - a.w) * t
		local radius = floor((w / scale_x - 1) / 2 + 0.5)
		if w >= RIVER_WIDE and radius < 1 then radius = 1 end
		return math.max(0, radius)
	end
	for _, river in ipairs(river_polylines()) do
		canvas.polyline(river.points, RIVER_COLOR, river_radius, on_land)
	end

	local roads = road_polylines()
	if #roads > 0 then
		for _, road in ipairs(roads) do
			local style = ROAD_STYLE[road.kind] or ROAD_STYLE.road
			canvas.polyline(road.points, style.color, style.radius)
		end
	end

	-- The minimap's normal-size copy, from these pixels before anything is
	-- baked (no second sampling): the same pixels at normal, scaled down at
	-- high.
	local coloured = core.get_us_time()
	local mini, mini_pixels = spec.minimap, nil
	if mini and mini.width == WIDTH and mini.height == HEIGHT then
		mini_pixels = {}
		for index = 1, WIDTH * HEIGHT do mini_pixels[index] = pixels[index] end
	elseif mini then
		mini_pixels = M.downscale(pixels, WIDTH, HEIGHT, mini.width, mini.height)
	end
	local copied = core.get_us_time()
	local baked = {icons = 0, names = 0, icon_overlaps = 0, name_overlaps = 0}
	if layer then
		baked = bake.draw(pixels, WIDTH, HEIGHT, view, bake.world_layer(layer), layer.art,
			bake.SCALE[spec.quality] or bake.SCALE.normal, true, "")
	end
	local tiles = M.tiles(WIDTH, HEIGHT)
	local total = encode_tiles(pixels, WIDTH, tiles)
	local encoded = core.get_us_time()
	local mini_total, mini_tiles, mini_icons = 0, nil, 0
	if mini then
		if layer then
			mini_icons = bake.draw(mini_pixels, mini.width, mini.height, view, layer, layer.art,
				bake.SCALE.mini, false, "_mini").icons
		end
		mini_tiles = M.tiles(mini.width, mini.height, M.MINI_PREFIX)
		mini_total = encode_tiles(mini_pixels, mini.width, mini_tiles)
	end
	local finished = core.get_us_time()
	-- A failed overlay costs only the claim preview (plan §4): the base
	-- and the minimap stay, and `overlays` stays nil.
	local overlays
	if claim and mini then
		local ok, result, territories, features = pcall(claim_overlay, zones, view, spec,
			water, owner, claim)
		if ok then
			overlays = result
			local bytes = 0
			for _, tiles in pairs(overlays) do
				for _, tile in ipairs(tiles) do bytes = bytes + #tile.png end
			end
			core.log("action", ("[grug_map] rendered the Claim Stone overlays %dx%d in " ..
				"%.2f s (%d territory and %d settlement queries, %d bytes)"):format(mini.width,
				mini.height, (core.get_us_time() - finished) / 1e6, territories, features, bytes))
		else
			core.log("error", "[grug_map] Claim Stone overlays not rendered, the minimap " ..
				"has no claim preview: " .. tostring(result))
		end
	end
	core.log("action", ("[grug_map] rendered world map base %dx%d (%s) in %.2f s " ..
		"(zones/water %.2f s, relief step %d %.2f s, colour %.2f s, bake+encode %.2f s, " ..
		"%d tiles, %d bytes; minimap copy %s %.2f s, %d bytes, %d icons; baked %d icons " ..
		"(%d overlapping pairs) and %d names (%d over an icon))"):
		format(WIDTH, HEIGHT, spec.quality, (finished - started) / 1e6,
		(classified - started) / 1e6,
		relief.step,
		(shaded - classified) / 1e6, (coloured - shaded) / 1e6,
		(encoded - copied) / 1e6, #tiles, total,
		mini and (mini.width .. "x" .. mini.height) or "none",
		(copied - coloured + finished - encoded) / 1e6, mini_total, mini_icons,
		baked.icons, baked.icon_overlaps, baked.names, baked.name_overlaps))
	return tiles, mini_tiles, overlays
end

-- The tiles of a width x height base, row by row: {name, col, row, x, y, w,
-- h} with x/y the tile's top-left base pixel. Edge tiles are smaller. Their
-- names start with `prefix` (default the Map tab's base).
M.BASE_PREFIX = "grug_map_base"
M.MINI_PREFIX = "grug_map_mini"
function M.tiles(width, height, prefix)
	prefix = prefix or M.BASE_PREFIX
	local result = {}
	for row = 0, math.ceil(height / M.TILE) - 1 do
		for col = 0, math.ceil(width / M.TILE) - 1 do
			local x, y = col * M.TILE, row * M.TILE
			result[#result + 1] = {name = ("%s_%d_%d.png"):format(prefix, col, row),
				col = col, row = row, x = x, y = y,
				w = math.min(M.TILE, width - x), h = math.min(M.TILE, height - y)}
		end
	end
	return result
end

-- The whole base as one texture (the Map tab): every tile combined.
function M.combined_texture(width, height, tiles)
	local parts = {("[combine:%dx%d"):format(width, height)}
	for _, tile in ipairs(tiles) do
		parts[#parts + 1] = ("%d,%d=%s"):format(tile.x, tile.y, tile.name)
	end
	return table.concat(parts, ":")
end

-- The minimap's round mask (ruling 6): a white disc with an anti-aliased
-- edge on a `size` x `size` transparent square, as a PNG. `[mask` keeps the
-- map where its alpha is set. The disc is inset by `inset` pixels so its edge
-- lies under the minimap's ring.
function M.mask_png(size, inset)
	local r = size / 2 - inset
	local c = size / 2
	local char, rows = string.char, {}
	local levels = {}
	for alpha = 0, 16 do
		levels[alpha] = char(255, 255, 255, math.floor(alpha * 255 / 16 + 0.5))
	end
	for j = 0, size - 1 do
		local row = {}
		for i = 0, size - 1 do
			-- 4 x 4 samples per pixel
			local hits = 0
			for sj = 0, 3 do
				local dy = j + (sj + 0.5) / 4 - c
				for si = 0, 3 do
					local dx = i + (si + 0.5) / 4 - c
					if dx * dx + dy * dy <= r * r then hits = hits + 1 end
				end
			end
			row[i + 1] = levels[hits]
		end
		rows[j + 1] = table.concat(row)
	end
	return core.encode_png(size, size, table.concat(rows), 9)
end

-- Re-render only when this key changes: this file's source, world seed,
-- the generator identity when grug_mapgen publishes one, a cheap fingerprint
-- of public query results, the inland water layout and the road network
-- (none until Phase 4).
local function cache_key(zones, view)
	local file = assert(io.open(SOURCE_PATH, "rb"), "cannot read " .. SOURCE_PATH)
	local source_bytes = file:read("*a")
	file:close()
	local parts = {core.sha256(source_bytes),
		tostring(core.get_mapgen_setting("seed"))}
	local mapgen = rawget(_G, "grug_mapgen")
	local wp40 = type(mapgen) == "table" and mapgen.wp40
	if type(wp40) == "table" then
		local source = wp40.preparation_source
		parts[#parts + 1] = tostring(type(source) == "table" and source.identity
			or wp40.manifest_sha256)
	end
	for gz = 0, 31 do
		local z = view.min_z + math.floor((view.max_z - view.min_z) * (gz + 0.37) / 32)
		for gx = 0, 35 do
			local x = view.min_x + math.floor((view.max_x - view.min_x) * (gx + 0.61) / 36)
			parts[#parts + 1] = zones.water_class_at(x, z) .. ":" ..
				tostring(zones.id_at(x, z))
		end
	end
	for _, row in ipairs(grug_core.start_identities()) do
		local capital = grug_core.capital_anchor(row.faction_id, row.race_id)
		for _, anchor in ipairs({row.anchor, capital}) do
			parts[#parts + 1] = tostring(zones.terrain_height_at(anchor.x, anchor.z))
		end
	end
	parts[#parts + 1] = core.sha256(water_layout_text())
	for _, road in ipairs(road_polylines()) do
		parts[#parts + 1] = tostring(road.kind)
		for _, point in ipairs(road.points) do
			parts[#parts + 1] = point.x .. "," .. point.z
		end
	end
	return core.sha256(table.concat(parts, "\n"))
end

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local data = file:read("*a")
	file:close()
	return data
end

-- The baked layer of this world (Round 44): every registered settlement by
-- its slot's kind (settlement_icons.lua), the kings at their sockets and the
-- dragons at their arenas, the region names, the art, and the versions its
-- part of the cache key names.
local function baked_layer()
	local art = dofile(MODPATH .. "/baked_art.lua")
	local settlements, kings, unknown_slots = {}, {}, {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local kind = icons.kind(row.slot)
		if not kind then unknown_slots[#unknown_slots + 1] = tostring(row.slot) end
		settlements[#settlements + 1] = {kind = kind, x = row.anchor.x, z = row.anchor.z}
		for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
			if socket.role == "king" and socket.spawn ~= false then
				kings[#kings + 1] = {x = socket.pos.x, z = socket.pos.z}
			end
		end
	end
	local dragons = {}
	for _, dragon in ipairs(grug_mobs.dragon_map_markers()) do
		dragons[#dragons + 1] = {x = dragon.pos.x, z = dragon.pos.z}
	end
	if #unknown_slots > 0 then
		core.log("warning", "[grug_map] settlements without a map icon kind: " ..
			table.concat(unknown_slots, ", "))
	end
	local items = bake.items(settlements, kings, dragons)
	return {items = items, labels = bake.REGION_LABELS, art = art,
		versions = {layout = core.sha256(assert(read_file(BAKE_PATH), "cannot read " .. BAKE_PATH)),
			art = art.art_version, font = art.font_version}}
end

-- The server's map quality (`grug_map_quality` in minetest.conf); an
-- unknown value warns and falls back to normal.
function M.quality()
	local value = core.settings:get("grug_map_quality")
	if value == nil or value == "" then return M.DEFAULT_QUALITY end
	if not M.QUALITY[value] then
		core.log("warning", "[grug_map] unknown grug_map_quality '" .. value ..
			"', using " .. M.DEFAULT_QUALITY)
		return M.DEFAULT_QUALITY
	end
	return value
end

-- Writes `data` to the world folder as `name` and announces it as startup
-- media.
function M.add_media(name, data)
	local path = WORLD .. "/" .. name
	if data then
		assert(core.safe_file_write(path, data), "cannot write " .. path)
	end
	assert(core.dynamic_add_media({filename = name, filepath = path}),
		"dynamic_add_media refused " .. path)
end

-- Deletes the world-map tiles in the world folder that the current quality
-- does not use (Round 41 ruling 7): after high -> normal the extra base
-- tiles would otherwise stay (since Round 44 both qualities send the
-- minimap's own copy under the same six names; since 0.50.2 the Claim Stone
-- overlays too). Only names of the tile patterns this file writes are
-- touched; `lists` are the tile lists in use. Logs the count; a failed
-- delete is a warning.
local function remove_stale_tiles(lists)
	local used = {}
	for _, list in ipairs(lists) do
		for _, tile in ipairs(list) do used[tile.name] = true end
	end
	local patterns = {"^" .. M.BASE_PREFIX .. "_%d+_%d+%.png$",
		"^" .. M.MINI_PREFIX .. "_%d+_%d+%.png$",
		"^" .. M.CLAIM_PREFIX .. "_%a+_%d+_%d+%.png$"}
	local removed = 0
	for _, name in ipairs(core.get_dir_list(WORLD, false) or {}) do
		local stale = false
		for _, pattern in ipairs(patterns) do stale = stale or name:find(pattern) ~= nil end
		if not used[name] and stale then
			local ok, err = os.remove(WORLD .. "/" .. name)
			if ok then
				removed = removed + 1
			else
				core.log("warning", "[grug_map] cannot remove stale world map tile " ..
					name .. ": " .. tostring(err))
			end
		end
	end
	core.log("action", "[grug_map] removed " .. removed .. " stale world map tiles")
end

-- The Claim Stone rules for the overlays (claim_overlay): grug_housing's
-- column rule, its world queries (placement_world, what validate asks) and
-- its settlement distance, never a copy; with the text that enters the cache
-- key: the rule's own source (registry.lua), its world queries' source
-- (api.lua: territory_at and the feature_in composition) and the digest of
-- the whole mapgen tree grug_mapgen publishes, which holds the settlement
-- cores' margins and the landmark columns (the fitted cores and footprints
-- are in the world identity already). Nil (no overlays) when grug_housing or a
-- part of its world is missing.
local function claim_rules()
	local housing = rawget(_G, "grug_housing")
	local world = type(housing) == "table" and housing.placement_world
	if type(world) ~= "table" or type(housing.column_problem) ~= "function" then return nil end
	local mapgen = rawget(_G, "grug_mapgen")
	local wp40 = type(mapgen) == "table" and mapgen.wp40
	local world_key = type(wp40) == "table" and wp40.world_key
	local registry = read_file(core.get_modpath("grug_housing") .. "/registry.lua")
	local api = read_file(core.get_modpath("grug_housing") .. "/api.lua")
	if not registry or not api then return nil end
	local factions = {}
	for _, faction in ipairs(grug_core.faction_ids) do factions[#factions + 1] = faction end
	return {factions = factions, problem = housing.column_problem,
		territory_at = world.territory_at, feature_in = world.feature_in,
		margin = housing.SETTLEMENT_MARGIN,
		key = table.concat(factions, ",") .. "\n" .. housing.SETTLEMENT_MARGIN .. "\n" ..
			core.sha256(registry) .. "\n" .. core.sha256(api) .. "\n" ..
			tostring(type(world_key) == "table" and world_key.source)}
end

local function prepare(view)
	assert(grug_core.zone_authority_installed(), "world authority is not installed")
	local zones = grug_zones
	local spec = M.spec(M.quality())
	local tiles = M.tiles(spec.width, spec.height)
	local mini = spec.minimap
	local mini_tiles = mini and M.tiles(mini.width, mini.height, M.MINI_PREFIX)
	local layer = baked_layer()
	local claim = mini and claim_rules()
	if mini and not claim then
		core.log("warning", "[grug_map] no Claim Stone rules: the minimap has no claim preview")
	end
	local claim_tiles = {}
	for _, faction in ipairs(claim and claim.factions or {}) do
		claim_tiles[faction] = M.tiles(mini.width, mini.height, M.CLAIM_PREFIX .. "_" .. faction)
	end
	-- The quality, its size, the atlas bounds (Round 51) and the minimap
	-- copy's size enter the key (ruling 3), so switching either re-renders
	-- both and a cache of an older size rebuilds; so does the baked layer (Round 44:
	-- its layout, art and font versions and every icon's kind and place) and
	-- the Claim Stone rules (0.50.2).
	local base_key = spec.quality .. "\n" .. spec.width .. "x" .. spec.height .. "\n" ..
		view.min_x .. "," .. view.min_z .. "," .. view.max_x .. "," .. view.max_z .. "\n" ..
		M.TILE .. "\n" ..
		(mini and (mini.width .. "x" .. mini.height) or "-") .. "\n" ..
		cache_key(zones, view) .. "\n" .. core.sha256(bake.key_text(layer.versions, layer.items))
	-- The key and the tile lists in use, with the overlays or (claim nil)
	-- without them.
	local key, lists
	local function with_claim()
		key = core.sha256(base_key .. "\n" .. (claim and core.sha256(claim.key) or "-"))
		lists = {tiles, mini_tiles or {}}
		for _, faction in ipairs(claim and claim.factions or {}) do
			lists[#lists + 1] = claim_tiles[faction]
		end
	end
	with_claim()
	local current = read_file(CACHE_KEY) == key
	for _, list in ipairs(lists) do
		for _, tile in ipairs(list) do
			current = current and read_file(WORLD .. "/" .. tile.name) ~= nil
		end
	end
	if current then
		core.log("action", "[grug_map] world map base cache is current")
		for _, list in ipairs(lists) do
			for _, tile in ipairs(list) do M.add_media(tile.name) end
		end
	else
		local rendered, rendered_mini, overlays = render(zones, view, spec, layer, claim)
		if claim and not overlays then
			-- the overlays failed: cache and announce the base without them
			-- (the next start tries again under the full key)
			claim = nil
			with_claim()
		end
		-- Tile names are shared across qualities: the old key goes before
		-- the first tile is overwritten and the new one is written last, so
		-- a crash in between renders again at the next start (ruling 7).
		assert(core.safe_file_write(CACHE_KEY, ""), "cannot write " .. CACHE_KEY)
		for _, tile in ipairs(rendered) do M.add_media(tile.name, tile.png) end
		for _, tile in ipairs(rendered_mini or {}) do M.add_media(tile.name, tile.png) end
		for _, faction in ipairs(claim and claim.factions or {}) do
			for _, tile in ipairs(overlays[faction]) do M.add_media(tile.name, tile.png) end
		end
		assert(core.safe_file_write(CACHE_KEY, key), "cannot write " .. CACHE_KEY)
	end
	-- Never stops the load: the base is announced already.
	local ok, err = pcall(remove_stale_tiles, lists)
	if not ok then
		core.log("warning", "[grug_map] stale world map tiles not removed: " .. tostring(err))
	end
	local result = {quality = spec.quality, width = spec.width, height = spec.height,
		tiles = tiles,
		texture = M.combined_texture(spec.width, spec.height, tiles)}
	-- `claim`: the Claim Stone overlays' tiles by faction (nil without them).
	result.minimap = mini and {quality = mini.quality, width = mini.width,
		height = mini.height, tiles = mini_tiles, claim = claim and claim_tiles or nil} or result
	return result
end

-- Load-time entry point. Returns the base: {quality, width, height, tiles,
-- texture, minimap} with `texture` what the Map tab shows and `minimap` the
-- base the minimap shows ({quality, width, height, tiles, claim}: its own
-- normal-size variant with the small icons and no names, and the Claim
-- Stone overlays' tiles by faction), or
-- {texture = fallback} without tiles if the base is unavailable. Startup
-- media must be announced while mods load (dynamic_add_media without a
-- callback), so init.lua calls this; grug_mapgen has installed the world
-- authority by then.
function M.install(view)
	local ok, result = pcall(prepare, view)
	if ok then return result end
	core.log("error", "[grug_map] world map base unavailable: " .. tostring(result))
	return {texture = FALLBACK_TEXTURE}
end

return M
