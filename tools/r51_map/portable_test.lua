-- Round 51 lane MAP portable test (LuaJIT): the sea coloured by depth, the
-- larger atlas and the map qualities (sea plan rulings S1-S3).
--
--   luajit tools/r51_map/portable_test.lua [repo]
--
-- Loads the REAL grug_map atlas.lua, base.lua (its render exposed as
-- tools/r27_minimap/render_base.lua does), minimap_view.lua and the world's
-- query bounds (source/simple_map.lua) on a fake engine. Checks:
--   A  atlas geometry: +-4050 x +-3600 (9:8) inside the world's query
--      bounds, with the relief grid's last samples inside them too;
--      world -> screen at the corners, the centre and the edges and back;
--      `contains` at the edge and one node beyond; centring at the corners
--      clamps; the minimap's base pixel round trip at the new edges and its
--      per-cell geometry the same as before (6.67 nodes per pixel, 66 px
--      window, 2 px cells);
--   Q  qualities: normal 1215 x 1080 and high 3600 x 3200, both 9:8 like
--      the atlas, 6.67 and 2.25 nodes per pixel, under 4096 px; the minimap
--      copy at normal size; the tile counts; layers.lua reads the normal
--      width from base.lua;
--   C  colour on a synthetic world (the real render): a lake keeps the lake
--      blue; bay, belt and channel water by depth from light at the
--      waterline to the middle blue and a little deeper; the open sea dark;
--      the edge between them soft and monotone; a belt pocket inside the
--      open sea and an open-sea speck inside the belt fade into their
--      surroundings (no speck); bay and belt shores get the coast line, lake
--      shores not; the water query is asked for planned water only;
--   K  cache key: a second start reads the cache; other atlas bounds and
--      another size re-render.
-- Prints "R51 MAP PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function read(path)
	local file = assert(io.open(path, "rb"), "cannot read " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

-- fake engine with a virtual world folder (section K)
local WORLD = "/virtual-world-r51-map"
local files, media, encoded, settings = {}, {}, {}, {}
local real_open = io.open
io.open = function(path, mode)
	if path:sub(1, #WORLD) == WORLD then
		local data = files[path]
		if not data then return nil end
		return {read = function() return data end, close = function() end}
	end
	return real_open(path, mode)
end
rawset(_G, "core", {
	get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
	get_current_modname = function() return "grug_map" end,
	get_worldpath = function() return WORLD end,
	get_us_time = function() return 0 end,
	log = function() end,
	settings = {get = function(_, key) return settings[key] end},
	sha256 = function(text)
		local h = 0
		for i = 1, #text do h = (h * 31 + text:byte(i)) % 2147483647 end
		return tostring(h) .. ":" .. #text
	end,
	get_mapgen_setting = function() return "42" end,
	encode_png = function(w, h, data)
		encoded[#encoded + 1] = {w = w, h = h, data = data}
		return "#" .. #encoded
	end,
	safe_file_write = function(path, data) files[path] = data return true end,
	dynamic_add_media = function(def)
		media[#media + 1] = def.filename
		files[def.filepath] = files[def.filepath] or "?"
		return true
	end,
	get_dir_list = function() return {} end,
})

local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local text = read(repo .. "/mods/PLAYER/grug_map/base.lua")
text = text:gsub("\nreturn M%s*$", "\nM._render = render\nreturn M\n")
local B = assert(loadstring(text, "@base.lua"))()
assert(B._render, "render not exposed")
local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")

-- ---------------------------------------------------------------------------
-- A  atlas geometry
-- ---------------------------------------------------------------------------
local view = atlas.view()
check(view.min_x == -4050 and view.max_x == 4050 and view.min_z == -3600 and
	view.max_z == 3600, "A atlas +-4050 x +-3600")
check((view.max_x - view.min_x) * 8 == (view.max_z - view.min_z) * 9, "A atlas 9:8")
local wb = source.world_bounds
check(view.min_x >= wb.min_x and view.max_x <= wb.max_x and view.min_z >= wb.min_z and
	view.max_z <= wb.max_z, "A atlas inside the world's query bounds")
for _, quality in ipairs({"normal", "high"}) do
	-- relief_grid samples min_x + gx * step for gx < ceil(width / step) + 1
	local step = B.QUALITY[quality].relief_step
	local last_x = view.min_x + math.ceil((view.max_x - view.min_x) / step) * step
	local last_z = view.max_z - math.ceil((view.max_z - view.min_z) / step) * step
	check(last_x <= wb.max_x and last_z >= wb.min_z,
		"A " .. quality .. " relief samples stay inside the world's query bounds")
end
local W, H = 1215, 1080
local corners = {
	{{x = view.min_x, z = view.max_z}, 0, 0},
	{{x = view.max_x, z = view.max_z}, W, 0},
	{{x = view.min_x, z = view.min_z}, 0, H},
	{{x = view.max_x, z = view.min_z}, W, H},
	{{x = 0, z = 0}, W / 2, H / 2},
	{{x = view.min_x, z = 0}, 0, H / 2},
	{{x = 0, z = view.min_z}, W / 2, H},
}
local trips = true
for _, row in ipairs(corners) do
	local sx, sy = atlas.world_to_screen(view, row[1], 0, 0, W, H)
	trips = trips and sx ~= nil and near(sx, row[2]) and near(sy, row[3])
	-- and back
	local x = view.min_x + sx / W * (view.max_x - view.min_x)
	local z = view.max_z - sy / H * (view.max_z - view.min_z)
	trips = trips and near(x, row[1].x) and near(z, row[1].z)
end
check(trips, "A world -> screen at the corners, the centre and the edges, and back")
check(atlas.contains(view, {x = 4050, z = -3600}) and atlas.contains(view, {x = -4050, z = 3600}) and
	not atlas.contains(view, {x = 4051, z = 0}) and not atlas.contains(view, {x = 0, z = -3601}) and
	atlas.world_to_screen(view, {x = -4051, z = 0}, 0, 0, W, H) == nil,
	"A contains the edge, not one node beyond")
local sx0, sy0 = atlas.centre_scroll(view, {x = view.min_x, z = view.max_z}, 4)
local sx1, sy1 = atlas.centre_scroll(view, {x = view.max_x, z = view.min_z}, 4)
check(sx0 == 0 and sy0 == 0 and sx1 == atlas.scroll_limit(4) and sy1 == atlas.scroll_limit(4),
	"A centring on the far corners clamps to the scroll range")
local v = V.new({quality = "normal", width = W, height = H, tiles = {}}, view)
local old = V.new({quality = "normal", width = 1080, height = 960, tiles = {}},
	{min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200})
check(near(v.npp, 8100 / 1215) and near(v.npp, old.npp) and v.crop == 66 and v.crop == old.crop and
	v.grid == old.grid and v.texture == old.texture, "A minimap: the same scale, window and cells")
local px0, py0 = V.base_pixel(v, view.min_x, view.max_z)
local px1, py1 = V.base_pixel(v, view.max_x, view.min_z)
local cx, cy = V.cell(v, view.max_x - 0.01, view.min_z + 0.01)
check(near(px0, 0) and near(py0, 0) and near(px1, W) and near(py1, H) and
	-- 1215 is odd: the last cell column is half a cell (the sea disc beyond)
	cx == math.floor((W - 0.01) / v.grid) and cy == H / v.grid - 1,
	"A minimap base pixels at the new edges")

-- ---------------------------------------------------------------------------
-- Q  qualities
-- ---------------------------------------------------------------------------
local normal, high = B.spec("normal"), B.spec("high")
check(normal.width == 1215 and normal.height == 1080, "Q normal 1215 x 1080")
check(high.width == 3600 and high.height == 3200, "Q high 3600 x 3200")
for _, spec in ipairs({normal, high}) do
	check(spec.width * 8 == spec.height * 9 and spec.width < 4096 and spec.height < 4096,
		"Q " .. spec.quality .. " 9:8 and under 4096 px")
end
check(near((view.max_x - view.min_x) / normal.width, 20 / 3) and
	near((view.max_z - view.min_z) / normal.height, 20 / 3), "Q normal 6.67 nodes per pixel")
check(near((view.max_x - view.min_x) / high.width, 2.25) and
	near((view.max_z - view.min_z) / high.height, 2.25), "Q high 2.25 nodes per pixel")
check(normal.minimap.width == 1215 and normal.minimap.height == 1080 and
	high.minimap.width == 1215 and high.minimap.height == 1080, "Q the minimap copy at normal size")
check(#B.tiles(1215, 1080) == 9 and #B.tiles(3600, 3200) == 56, "Q tiles 9 / 56")
local layers = read(repo .. "/mods/PLAYER/grug_map/layers.lua")
check(layers:find("grug_map.base.QUALITY.normal.width", 1, true) ~= nil and
	not layers:find("/ 1080 *", 1, true), "Q layers.lua reads the normal width from base.lua")
check(B.OPEN_SEA_HEX == ("#%02x%02x%02x"):format(unpack(B.SEA.open)) and
	read(repo .. "/mods/PLAYER/grug_map/minimap.lua"):find('"^[multiply:" .. grug_map.base.OPEN_SEA_HEX', 1,
	true) ~= nil, "Q the minimap's sea disc is the open sea's colour")

-- ---------------------------------------------------------------------------
-- C  colour on a synthetic world
-- ---------------------------------------------------------------------------
local SEA = B.SEA
local function unpack_rgb(p) return {math.floor(p / 65536), math.floor(p / 256) % 256, p % 256} end
local function packed(c) return (c[1] * 256 + c[2]) * 256 + c[3] end
check(B.sea_color(0, 0) == packed(SEA.light) and B.sea_color(-3, 0) == packed(SEA.light),
	"C depth 0 (and above the floor) is light")
check(B.sea_color(SEA.middle_depth, 0) == packed(SEA.middle), "C middle from middle_depth")
check(B.sea_color(SEA.deep_depth, 0) == packed(SEA.middle_deep) and
	B.sea_color(60, 0) == packed(SEA.middle_deep), "C middle_deep from deep_depth on")
check(B.sea_color(5, 1) == packed(SEA.open) and B.sea_color(40, 1) == packed(SEA.open),
	"C an open share of 1 is the open sea")
local function luminance(p)
	local c = unpack_rgb(p)
	return c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
end
local monotone = true
for d = 0, 40 do
	monotone = monotone and luminance(B.sea_color(d + 1, 0)) <= luminance(B.sea_color(d, 0))
end
check(monotone, "C deeper water is never lighter")

-- The world: 1600 x 800 nodes at 6.67 nodes per pixel. Land west of
-- x -500 (with a lake inlet north, z > 100, and a bay inlet south, z < -100,
-- reaching to x -560); planned water -500..-300 (a lake north of z 0, a bay
-- south); belt -300..100 with a channel strip z >= 250 and an open-sea speck
-- (radius 12) at (-100, -200); open sea from x 100 with a belt pocket
-- (radius 12) at (500, 200). The floor falls 1 node per 25 east of x -500.
local VIEW = {min_x = -800, max_x = 800, min_z = -400, max_z = 400}
local function disc(x, z, cx0, cz0, r) return (x - cx0) * (x - cx0) + (z - cz0) * (z - cz0) <= r * r end
local function class_at(x, z)
	if x < -560 then return "land" end
	if x < -500 then
		if z > 100 or z < -100 then return "planned_water" end
		return "land"
	end
	if x < -300 then return "planned_water" end
	if x < 100 then
		if disc(x, z, -100, -200, 12) then return "deep_ocean" end
		return z >= 250 and "immutable_dragon_channel" or "coastal_shelf"
	end
	if disc(x, z, 500, 200, 12) then return "coastal_shelf" end
	return "deep_ocean"
end
local queried = {}
local zones = {
	water_class_at = class_at,
	id_at = function(x, z)
		local class = class_at(x, z)
		if class == "deep_ocean" or class == "immutable_dragon_channel" then return nil end
		return "home"
	end,
	get = function(id)
		return {id = id, numeric_id = 1, race_region = "human", level_min = 1, pvp_rule = "peaceful"}
	end,
	terrain_height_at = function(x)
		if x < -500 then return 20 end
		return 1 - (x + 500) / 25
	end,
	water_query_at = function(x, z)
		local class = class_at(x, z)
		queried[class] = (queried[class] or 0) + 1
		if class ~= "planned_water" then return nil end
		return z > 0 and "lake" or "bay"
	end,
}
local CW, CH = 240, 120
local spec = {quality = "normal", width = CW, height = CH, relief_step = 8, relief = B.RELIEF}
encoded = {}
local tiles = B._render(zones, VIEW, spec, nil, nil)
check(#tiles == 1 and #encoded == 1 and encoded[1].w == CW, "C one tile rendered")
local data = encoded[1].data
local scale = (VIEW.max_x - VIEW.min_x) / CW
local function pixel_at(x, z)
	local i = math.floor((x - VIEW.min_x) / scale)
	local j = math.floor((VIEW.max_z - z) / scale)
	local o = (j * CW + i) * 4
	return (data:byte(o + 1) * 256 + data:byte(o + 2)) * 256 + data:byte(o + 3), i, j
end
-- the depth the render reads at a pixel's centre (bilinear of a linear floor
-- is exact)
local function depth_of(i) return (VIEW.min_x + (i + 0.5) * scale + 500) / 25 end
local LAKE = packed({62, 118, 152})
local lake_px = pixel_at(-400, 200)
local bay_px, bay_i = pixel_at(-400, -200)
check(lake_px == LAKE, "C a lake keeps the lake blue")
check(bay_px == B.sea_color(depth_of(bay_i), 0) and bay_px ~= LAKE, "C a bay is sea by depth")
local shallow = pixel_at(-495, -200)
check(luminance(shallow) > luminance(B.sea_color(4, 0)), "C the waterline is light")
local belt_px, belt_i = pixel_at(-150, 0)
check(belt_px == B.sea_color(depth_of(belt_i), 0), "C belt water by depth, no open share far off")
local chan_px, chan_i = pixel_at(-150, 330)
check(chan_px == B.sea_color(depth_of(chan_i), 0) and chan_i == belt_i and chan_px == belt_px,
	"C channel water as belt water of the same depth")
check(pixel_at(700, -300) == packed(SEA.open), "C the open sea far off is the open colour")
-- the soft edge along z = -330 (away from the speck and the pocket)
local row, soft = {}, true
for x = -50, 260, 5 do row[#row + 1] = pixel_at(x, -330) end
for k = 2, #row do soft = soft and luminance(row[k]) <= luminance(row[k - 1]) + 0.5 end
local at_edge = pixel_at(100, -330)
local belt_edge_colour = B.sea_color(depth_of(math.floor((100 - VIEW.min_x) / scale)), 0)
check(soft and at_edge ~= packed(SEA.open) and luminance(at_edge) < luminance(belt_edge_colour) and
	luminance(at_edge) > luminance(packed(SEA.open)), "C the edge to the open sea is soft and monotone")
check(pixel_at(-40, -330) == B.sea_color(depth_of(math.floor((-40 - VIEW.min_x) / scale)), 0) and
	pixel_at(240, -330) == packed(SEA.open), "C the soft edge is about 100 nodes wide, no more")
-- pockets fade into their surroundings
local function share_toward_open(p, i)
	local mid, op = unpack_rgb(B.sea_color(depth_of(i), 0)), SEA.open
	local c = unpack_rgb(p)
	return (mid[2] - c[2]) / (mid[2] - op[2])
end
local pocket, pocket_i = pixel_at(500, 200)
check(share_toward_open(pocket, pocket_i) > 0.85, "C a belt pocket in the open sea reads as open sea")
local speck, speck_i = pixel_at(-100, -200)
check(share_toward_open(speck, speck_i) < 0.15, "C an open-sea speck in the belt reads as belt")
-- coast lines
local COAST = packed({88, 72, 50})
check(pixel_at(-565, -200) == COAST or pixel_at(-570, -200) == COAST, "C a bay shore is coast")
check(pixel_at(-565, 200) ~= COAST and pixel_at(-570, 200) ~= COAST, "C a lake shore is no coast")
check(pixel_at(-503, 0) == COAST, "C a bay's head on land is coast")
check(queried.planned_water and queried.planned_water > 0 and not queried.coastal_shelf and
	not queried.deep_ocean and not queried.land and not queried.immutable_dragon_channel,
	"C the water query is asked for planned water only")

-- ---------------------------------------------------------------------------
-- K  cache key
-- ---------------------------------------------------------------------------
rawset(_G, "grug_core", {
	zone_authority_installed = function() return true end,
	start_identities = function() return {} end,
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
rawset(_G, "grug_zones", {
	water_class_at = function(x) return x < 3000 and "land" or "deep_ocean" end,
	id_at = function() return "home" end,
	get = zones.get,
	terrain_height_at = function(x, z) return (x + z) % 50 end,
	water_query_at = function() return nil end,
})
B.QUALITY.normal.width, B.QUALITY.normal.height = 135, 120
B.QUALITY.normal.relief_step = 400
settings.grug_map_quality = "normal"
encoded = {}
B.install(view)
local first = #encoded
encoded = {}
B.install(view)
check(first > 0 and #encoded == 0, "K a second start reads the cache")
encoded = {}
B.install({min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200})
check(#encoded > 0, "K other atlas bounds re-render")
encoded = {}
B.install(view)
check(#encoded > 0, "K and back again re-renders")
B.QUALITY.normal.width, B.QUALITY.normal.height = 108, 96
encoded = {}
B.install(view)
check(#encoded > 0, "K another size re-renders")

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R51 MAP PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R51 MAP PORTABLE PASS checks=%d"):format(checks))
