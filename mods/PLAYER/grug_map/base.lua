-- Per-world atlas base image (Round 22 D24, world_map.md).
--
-- Coast, zone borders and (from Round 22 Phase 4) roads differ per world
-- seed, so the base cannot ship as a pre-rendered texture. The server renders
-- it once from the public world authority (grug_zones), caches it in the world
-- directory and announces it as startup media. Markers and labels stay a
-- separate formspec layer (page.lua); nothing here knows about them.
--
-- Only pure public queries are used (water_class_at, id_at, get,
-- terrain_height_at): no chunk is generated, loaded or read.

local M = {}

-- This file's own source enters the cache key, so any palette or drawing
-- change re-renders cached bases without a manual version bump.
local SOURCE_PATH = core.get_modpath(core.get_current_modname()) .. "/base.lua"
local MEDIA_NAME = "grug_map_base.png"
local CACHE_PNG = core.get_worldpath() .. "/grug_map_base.png"
local CACHE_KEY = core.get_worldpath() .. "/grug_map_base.key"
-- 9:8 like the atlas bounds; 6.67 nodes per pixel.
local WIDTH, HEIGHT = 1080, 960
-- Relief samples terrain_height_at on one fixed grid, the same on every
-- server (Round 22 D29: hardware never changes what is produced). 8 nodes is
-- about one map pixel (6.67 nodes); measured 2026-09-25 on seed
-- 15140735923413111218 at ~22 s for the 901x801 grid (~24 s for the whole
-- base; 16 nodes would be ~6 s), paid once per world because the image is
-- cached. The step is part of this file's source and
-- therefore of the cache key, so changing it re-renders cached bases.
local RELIEF_STEP = 8
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

-- PHASE 4 HOOK (roads). Round 22 Phase 3 switches roads off, so the base has
-- none. When the Phase 4 road overlay exposes its routed network through a
-- public seam, return it here as a list of
-- {kind = "road" or "trail", points = {{x = , z = }, ...}}. render() strokes it
-- onto the base with canvas.polyline and cache_key() folds it into the cache
-- key, so a changed network re-renders the base.
local function road_polylines()
	return {}
end

local ROAD_STYLE = {road = {color = pack(rgb(112, 84, 52)), radius = 1},
	trail = {color = pack(rgb(132, 104, 70)), radius = 0}}

-- World-coordinate drawing surface over the packed pixel array, for overlays
-- such as the Phase 4 roads.
local function new_canvas(view, pixels)
	local canvas = {}
	local sx = WIDTH / (view.max_x - view.min_x)
	local sz = HEIGHT / (view.max_z - view.min_z)
	function canvas.plot(x, z, color, radius)
		local px = math.floor((x - view.min_x) * sx)
		local py = math.floor((view.max_z - z) * sz)
		for j = py - radius, py + radius do
			for i = px - radius, px + radius do
				if i >= 0 and i < WIDTH and j >= 0 and j < HEIGHT then
					pixels[j * WIDTH + i + 1] = color
				end
			end
		end
	end
	function canvas.polyline(points, color, radius)
		for index = 2, #points do
			local a, b = points[index - 1], points[index]
			local steps = math.max(1, math.ceil(math.max(
				math.abs(b.x - a.x) * sx, math.abs(b.z - a.z) * sz)))
			for step = 0, steps do
				local t = step / steps
				canvas.plot(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t,
					color, radius)
			end
		end
	end
	return canvas
end

-- Hillshade factor grid on the fixed relief step.
local function relief_grid(zones, view)
	local step = RELIEF_STEP
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
	-- falling toward +z faces it. Central differences; row gz grows southward.
	local shade = {}
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			local west = heights[gz * nx + math.max(gx - 1, 0) + 1]
			local east = heights[gz * nx + math.min(gx + 1, nx - 1) + 1]
			local north = heights[math.max(gz - 1, 0) * nx + gx + 1]
			local south = heights[math.min(gz + 1, nz - 1) * nx + gx + 1]
			local value = 1 + 1.2 * (east - west - north + south) / (2 * step)
			shade[gz * nx + gx + 1] = math.max(0.8, math.min(1.14, value))
		end
	end
	return {shade = shade, nx = nx, nz = nz, step = step}
end

-- Bilinear hillshade at fractional grid position (fx, fz).
local function relief_at(relief, fx, fz)
	local ix = math.min(math.floor(fx), relief.nx - 2)
	local iz = math.min(math.floor(fz), relief.nz - 2)
	local tx, tz = fx - ix, fz - iz
	local nx, shade = relief.nx, relief.shade
	local top = iz * nx + ix + 1
	local a, b = shade[top], shade[top + 1]
	local c, d = shade[top + nx], shade[top + nx + 1]
	return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz
end

local function sea(class)
	return class == "deep_ocean" or class == "immutable_dragon_channel" or
		class == "coastal_shelf"
end

local function render(zones, view)
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
	local relief = relief_grid(zones, view)
	local shaded = core.get_us_time()

	-- Pass 2: land takes its zone colour times the hillshade; a land pixel
	-- next to open water is coast; a land pixel whose right or lower neighbour
	-- belongs to another zone is a border line.
	local pixels, water_colors = {}, {}
	for class, color in pairs(WATER) do water_colors[class] = pack(color) end
	local coast = pack(COAST)
	for j = 0, HEIGHT - 1 do
		local fz = (j + 0.5) * scale_z / relief.step
		for i = 0, WIDTH - 1 do
			local index = j * WIDTH + i + 1
			local class = water[index]
			if class ~= "land" then
				pixels[index] = water_colors[class] or water_colors.deep_ocean
			elseif (i > 0 and sea(water[index - 1])) or
					(i < WIDTH - 1 and sea(water[index + 1])) or
					(j > 0 and sea(water[index - WIDTH])) or
					(j < HEIGHT - 1 and sea(water[index + WIDTH])) then
				pixels[index] = coast
			else
				local id = owner[index]
				local factor = relief_at(relief, (i + 0.5) * scale_x / relief.step, fz)
				local right = i < WIDTH - 1 and owner[index + 1]
				local below = j < HEIGHT - 1 and owner[index + WIDTH]
				if (right and right ~= id) or (below and below ~= id) then
					factor = factor * BORDER_SHADE
				end
				pixels[index] = pack(colors[id] or NEUTRAL, factor)
			end
		end
	end

	local roads = road_polylines()
	if #roads > 0 then
		local canvas = new_canvas(view, pixels)
		for _, road in ipairs(roads) do
			local style = ROAD_STYLE[road.kind] or ROAD_STYLE.road
			canvas.polyline(road.points, style.color, style.radius)
		end
	end

	-- Encode: one memoised 4-byte RGBA string per distinct colour.
	local char, bytes_of, rows = string.char, {}, {}
	for j = 0, HEIGHT - 1 do
		local row = {}
		for i = 1, WIDTH do
			local packed = pixels[j * WIDTH + i]
			local bytes = bytes_of[packed]
			if not bytes then
				bytes = char(math.floor(packed / 65536),
					math.floor(packed / 256) % 256, packed % 256, 255)
				bytes_of[packed] = bytes
			end
			row[i] = bytes
		end
		rows[j + 1] = table.concat(row)
	end
	local png = core.encode_png(WIDTH, HEIGHT, table.concat(rows), 9)
	local finished = core.get_us_time()
	core.log("action", ("[grug_map] rendered world map base %dx%d in %.2f s " ..
		"(zones/water %.2f s, relief step %d %.2f s, colour+encode %.2f s, %d bytes)"):
		format(WIDTH, HEIGHT, (finished - started) / 1e6,
		(classified - started) / 1e6,
		relief.step,
		(shaded - classified) / 1e6, (finished - shaded) / 1e6, #png))
	return png
end

-- Re-render only when this key changes: this file's source, world seed,
-- the generator identity when grug_mapgen publishes one, a cheap fingerprint
-- of public query results and the road network (none until Phase 4).
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

local function prepare(view)
	assert(grug_core.zone_authority_installed(), "world authority is not installed")
	local zones = grug_zones
	local key = cache_key(zones, view)
	if read_file(CACHE_KEY) == key and read_file(CACHE_PNG) then
		core.log("action", "[grug_map] world map base cache is current")
	else
		local png = render(zones, view)
		assert(core.safe_file_write(CACHE_PNG, png), "cannot write " .. CACHE_PNG)
		assert(core.safe_file_write(CACHE_KEY, key), "cannot write " .. CACHE_KEY)
	end
	assert(core.dynamic_add_media({filename = MEDIA_NAME, filepath = CACHE_PNG}),
		"dynamic_add_media refused " .. CACHE_PNG)
	return MEDIA_NAME
end

-- Load-time entry point; returns the texture name the atlas shows. Startup
-- media must be announced while mods load (dynamic_add_media without a
-- callback), so init.lua calls this; grug_mapgen has installed the world
-- authority by then.
function M.install(view)
	local ok, result = pcall(prepare, view)
	if ok then return result end
	core.log("error", "[grug_map] world map base unavailable: " .. tostring(result))
	return FALLBACK_TEXTURE
end

return M
