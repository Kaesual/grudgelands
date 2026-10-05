-- Per-world atlas base image (Round 22 D24, world_map.md).
--
-- Coast, zone borders and (from Round 22 Phase 4) roads differ per world
-- seed, so the base cannot ship as a pre-rendered texture. The server renders
-- it once from the public world authority (grug_zones), caches it in the world
-- directory and announces it as startup media. Markers and labels stay a
-- separate formspec layer (page.lua); nothing here knows about them.
--
-- Only pure public queries are used (water_class_at, id_at, get,
-- terrain_height_at) plus the river centrelines grug_mapgen publishes: no
-- chunk is generated, loaded or read.
--
-- The image is sent as TILES of at most TILE x TILE pixels (Round 27): the
-- minimap builds its round window with `[combine` from the at most four
-- tiles it overlaps, so the client never copies the whole base per window
-- (`[combine` copies each source image once, imagesource.cpp). The Map tab
-- shows every tile combined into one texture. The minimap always shows a
-- normal-size base (user ruling 2026-10-06): at high quality the render
-- also sends a normal-size copy of its own image, scaled down in the same
-- pass, as `grug_map_mini_*` tiles. Nothing else is sent, so the download
-- is the tiles alone.

local M = {}

-- This file's own source enters the cache key, so any palette or drawing
-- change re-renders cached bases without a manual version bump.
local SOURCE_PATH = core.get_modpath(core.get_current_modname()) .. "/base.lua"
local WORLD = core.get_worldpath()
local CACHE_KEY = WORLD .. "/grug_map_base.key"
M.TILE = 512
M.MASK = "grug_map_minimap_mask.png"
-- Map quality (Round 27 rulings 1-3): a server setting for the Map tab's
-- image. Both are 9:8 like the atlas bounds. Normal is the Round 22 image,
-- about 6.67 nodes per pixel; high is 2 nodes per pixel and stays below 4096
-- px per edge (some GPUs hold no larger texture). `minimap` names the size
-- the minimap's base has when it is not the Map tab's own (user ruling
-- 2026-10-06: the minimap shows normal quality on every server).
--
-- Relief samples terrain_height_at on one fixed grid per quality, the same
-- on every server (Round 22 D29: hardware never changes what is produced).
-- Normal keeps the Round 22 step of 8 nodes (about one map pixel); high
-- samples every 4 nodes (two map pixels), which the bilinear interpolation
-- below keeps smooth. The steps are part of this file's source and therefore
-- of the cache key, so changing one re-renders cached bases.
M.QUALITY = {
	normal = {width = 1080, height = 960, relief_step = 8},
	high = {width = 3600, height = 3200, relief_step = 4, minimap = "normal"},
}
M.DEFAULT_QUALITY = "normal"
-- Shown if rendering fails: plain sea, so the markers stay usable.
local FALLBACK_TEXTURE = "[fill:90x80:#1c3a52"

local function rgb(r, g, b) return {r, g, b} end

local WATER = {
	deep_ocean = rgb(28, 58, 82),
	immutable_dragon_channel = rgb(22, 46, 66),
	coastal_shelf = rgb(48, 92, 118),
	planned_water = rgb(62, 118, 152),
}
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
local RIVER_COLOR = pack(rgb(62, 118, 152))
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

local function sea(class)
	return class == "deep_ocean" or class == "immutable_dragon_channel" or
		class == "coastal_shelf"
end

-- The render size and relief step of `quality` ("normal" or "high"; any
-- other value is normal), and `minimap` {quality, width, height} when the
-- minimap's base is a scaled-down copy (nil: the minimap shows this base).
-- `override` replaces fields: offline tools render crops of a view at their
-- own size, or try other RELIEF values.
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

local function render(zones, view, spec)
	local WIDTH, HEIGHT, R = spec.width, spec.height, spec.relief
	local started = core.get_us_time()
	local scale_x = (view.max_x - view.min_x) / WIDTH
	local scale_z = (view.max_z - view.min_z) / HEIGHT
	-- Pass 1: one water class and owning zone id per pixel centre.
	local water, owner, seen = {}, {}, {}
	for j = 0, HEIGHT - 1 do
		local z = math.floor(view.max_z - (j + 0.5) * scale_z)
		for i = 0, WIDTH - 1 do
			local x = math.floor(view.min_x + (i + 0.5) * scale_x)
			local class = zones.water_class_at(x, z)
			local index = j * WIDTH + i + 1
			local id = false
			if class ~= "deep_ocean" and class ~= "immutable_dragon_channel" then
				id = zones.id_at(x, z) or false
				if id then seen[id] = true end
			end
			water[index], owner[index] = class, id
		end
	end
	local classified = core.get_us_time()
	local colors = palette(zones, seen)
	local relief = relief_grid(zones, view, spec.relief_step, R)
	local shaded = core.get_us_time()

	-- Pass 2: land takes its zone colour, tinted toward stone with height,
	-- times the hillshade; a contour line darkens it further. A land pixel
	-- next to open water is coast; a land pixel whose right or lower
	-- neighbour belongs to another zone is a border line.
	local pixels, water_colors = {}, {}
	for class, color in pairs(WATER) do water_colors[class] = pack(color) end
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
		local left
		for i = 0, WIDTH - 1 do
			local index = j * WIDTH + i + 1
			local class = water[index]
			local fx = (i + 0.5) * scale_x / relief.step
			local h = bilinear(relief, relief.height, fx, fz)
			if class ~= "land" then
				pixels[index] = water_colors[class] or water_colors.deep_ocean
			elseif (i > 0 and sea(water[index - 1])) or
					(i < WIDTH - 1 and sea(water[index + 1])) or
					(j > 0 and sea(water[index - WIDTH])) or
					(j < HEIGHT - 1 and sea(water[index + WIDTH])) then
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

	local tiles = M.tiles(WIDTH, HEIGHT)
	local total = encode_tiles(pixels, WIDTH, tiles)
	local encoded = core.get_us_time()
	-- The minimap's normal-size copy, from these pixels (no second sampling).
	local mini, mini_total = spec.minimap, 0
	local mini_tiles
	if mini then
		mini_tiles = M.tiles(mini.width, mini.height, M.MINI_PREFIX)
		mini_total = encode_tiles(M.downscale(pixels, WIDTH, HEIGHT,
			mini.width, mini.height), mini.width, mini_tiles)
	end
	local finished = core.get_us_time()
	core.log("action", ("[grug_map] rendered world map base %dx%d (%s) in %.2f s " ..
		"(zones/water %.2f s, relief step %d %.2f s, colour+encode %.2f s, " ..
		"%d tiles, %d bytes; minimap copy %s %.2f s, %d bytes)"):
		format(WIDTH, HEIGHT, spec.quality, (finished - started) / 1e6,
		(classified - started) / 1e6,
		relief.step,
		(shaded - classified) / 1e6, (encoded - shaded) / 1e6, #tiles, total,
		mini and (mini.width .. "x" .. mini.height) or "none",
		(finished - encoded) / 1e6, mini_total))
	return tiles, mini_tiles
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

local function prepare(view)
	assert(grug_core.zone_authority_installed(), "world authority is not installed")
	local zones = grug_zones
	local spec = M.spec(M.quality())
	local tiles = M.tiles(spec.width, spec.height)
	local mini = spec.minimap
	local mini_tiles = mini and M.tiles(mini.width, mini.height, M.MINI_PREFIX)
	-- The quality and the minimap copy's size enter the key (ruling 3), so
	-- switching either re-renders both.
	local key = core.sha256(spec.quality .. "\n" .. M.TILE .. "\n" ..
		(mini and (mini.width .. "x" .. mini.height) or "-") .. "\n" ..
		cache_key(zones, view))
	local current = read_file(CACHE_KEY) == key
	for _, list in ipairs({tiles, mini_tiles or {}}) do
		for _, tile in ipairs(list) do
			current = current and read_file(WORLD .. "/" .. tile.name) ~= nil
		end
	end
	if current then
		core.log("action", "[grug_map] world map base cache is current")
		for _, tile in ipairs(tiles) do M.add_media(tile.name) end
		for _, tile in ipairs(mini_tiles or {}) do M.add_media(tile.name) end
	else
		local rendered, rendered_mini = render(zones, view, spec)
		for _, tile in ipairs(rendered) do M.add_media(tile.name, tile.png) end
		for _, tile in ipairs(rendered_mini or {}) do M.add_media(tile.name, tile.png) end
		assert(core.safe_file_write(CACHE_KEY, key), "cannot write " .. CACHE_KEY)
	end
	local result = {quality = spec.quality, width = spec.width, height = spec.height,
		tiles = tiles,
		texture = M.combined_texture(spec.width, spec.height, tiles)}
	result.minimap = mini and {quality = mini.quality, width = mini.width,
		height = mini.height, tiles = mini_tiles} or result
	return result
end

-- Load-time entry point. Returns the base: {quality, width, height, tiles,
-- texture, minimap} with `texture` what the Map tab shows and `minimap` the
-- base the minimap shows ({quality, width, height, tiles}: the normal-size
-- copy at high quality, the base itself at normal), or
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
