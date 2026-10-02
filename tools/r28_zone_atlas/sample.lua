-- Round 28 Lane C0 (zone facts atlas): sample the analytic world of one seed
-- on a regular grid, without the engine (LuaJIT).
--
--   luajit tools/r28_zone_atlas/sample.lua <repo> <seed> <out_dir> <step> <band> <bands>
--
-- The world is built by tools/r28_zone_atlas/world.lua exactly as main builds
-- it (zones session with the R7 overlay, roads, capital layouts). Rows of the
-- grid (x from -3600, z from -3200, every <step> nodes) are split into <bands>
-- contiguous blocks; this process samples block <band> (0-based), so several
-- processes can share the work. Each column is 8 bytes in
-- <out_dir>/grid_<band>.bin, row-major (z outer, x inner):
--   u8 zone numeric id (0 = no owner), u8 water class (WATER below; 6 =
--   planned water that is a river or lake, 3 = the rest: bay water),
--   i16 LE terrain height, u8 surface mob level (0 = none),
--   u8 coast/bank material (0 none, 1 sand, 2 gravel, 3 stone; land only),
--   u8 biome index (BIOMES below, 0 = none), u8 hard protection at the
--   surface (0 none, 1 town = start town or capital city, 2 landmark column).
-- Band 0 also writes <out_dir>/meta.json: zones, neighbours, anchors (with
-- fitted y), roads (every 2nd centreline point), rivers, capital layouts
-- (world coordinates) and the grid header.
local repo, seed, out_dir, step, band, bands = arg[1], arg[2], arg[3],
	tonumber(arg[4]), tonumber(arg[5]), tonumber(arg[6])
assert(repo and seed and out_dir and step and band and bands,
	"usage: sample.lua <repo> <seed> <out_dir> <step> <band> <bands>")

local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local t0 = os.clock()
local W = dofile(here .. "/world.lua")(repo, seed)
local build_seconds = os.clock() - t0
local S, H = W.session, W.height
local zone_bands = dofile(repo .. "/mods/CORE/grug_core/zone_bands.lua")

local MIN_X, MIN_Z, MAX_X, MAX_Z = -3600, -3200, 3600, 3200
local cols = math.floor((MAX_X - MIN_X) / step)
local rows = math.floor((MAX_Z - MIN_Z) / step)
local WATER = {deep_ocean = 1, coastal_shelf = 2, planned_water = 3, land = 4,
	immutable_dragon_channel = 5}
local COAST = {sand = 1, gravel = 2, stone = 3}
local BIOMES = {"grug_badlands", "grug_badlands_east", "grug_beach", "grug_blight",
	"grug_bone_forest", "grug_crags", "grug_crags_snowy", "grug_deep_forest",
	"grug_deep_jungle", "grug_elf_forest", "grug_jungle_edge", "grug_jungle_fringe",
	"grug_meadows", "grug_pine_hills", "grug_savanna", "grug_swamp"}
local biome_index = {}
for i, id in ipairs(BIOMES) do biome_index[id] = i end
local zone_numeric = {}
for _, zone in ipairs(W.source.zones) do zone_numeric[zone.id] = zone.numeric_id end

-- JSON writer for plain tables (arrays when t[1] ~= nil or empty-marked).
local function json(value, out)
	local kind = type(value)
	if kind == "table" then
		if value[1] ~= nil or next(value) == nil then
			out[#out + 1] = "["
			for i = 1, #value do
				if i > 1 then out[#out + 1] = "," end
				json(value[i], out)
			end
			out[#out + 1] = "]"
		else
			local keys = {}
			for k in pairs(value) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			out[#out + 1] = "{"
			for i, k in ipairs(keys) do
				if i > 1 then out[#out + 1] = "," end
				out[#out + 1] = ("%q:"):format(k)
				local v = value[k]
				if v == nil then v = value[tonumber(k)] end
				json(v, out)
			end
			out[#out + 1] = "}"
		end
	elseif kind == "number" then
		if value % 1 == 0 then out[#out + 1] = ("%d"):format(value)
		else out[#out + 1] = ("%.2f"):format(value) end
	elseif kind == "string" then
		out[#out + 1] = '"' .. value:gsub('[%c"\\]', function(c)
			return ("\\u%04x"):format(c:byte()) end) .. '"'
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	else
		out[#out + 1] = "null"
	end
end

local first = math.floor(rows * band / bands)
local last = math.floor(rows * (band + 1) / bands) - 1
local t1 = os.clock()
local file = assert(io.open(("%s/grid_%d.bin"):format(out_dir, band), "wb"))
local char, floor = string.char, math.floor
for r = first, last do
	local z = MIN_Z + r * step
	local buf = {}
	for c = 0, cols - 1 do
		local x = MIN_X + c * step
		local wc = S.water_class_at(x, z)
		local zone = 0
		local h, level, coast, biome, prot = 0, 0, 0, 0, 0
		local code = WATER[wc] or 0
		-- planned water split: bay water (sea inlets) keeps 3, a river or
		-- lake column (the height session's inland water) becomes 6
		if wc == "planned_water" and H.inland_water_at(x, z) ~= nil then code = 6 end
		if wc ~= "deep_ocean" and wc ~= "immutable_dragon_channel" then
			local id = S.id_at(x, z)
			zone = id and zone_numeric[id] or 0
			h = S.terrain_height_at(x, z)
			level = S.surface_mob_level_at(x, z) or 0
			local b = S.biome_at(x, z)
			biome = b and biome_index[b] or 0
			if wc == "land" then
				coast = COAST[H.coast_material_at(x, z) or ""] or 0
				local kind = S.hard_protection_kind_at({x = x, y = h + 1, z = z})
				prot = kind == "town" and 1 or kind == "landmark" and 2 or 0
			end
		else
			h = -23
		end
		if h < -32768 then h = -32768 elseif h > 32767 then h = 32767 end
		local u = h % 65536
		buf[#buf + 1] = char(zone, code, u % 256, floor(u / 256), level, coast, biome, prot)
	end
	file:write(table.concat(buf))
end
file:close()
local sample_seconds = os.clock() - t1

if band == 0 then
	local meta = {seed = seed, step = step, min_x = MIN_X, min_z = MIN_Z,
		cols = cols, rows = rows, biomes = BIOMES,
		water_codes = {"deep_ocean", "coastal_shelf", "bay_water", "land",
			"immutable_dragon_channel", "inland_water"},
		zones = {}, anchors = {}, roads = {}, rivers = {}, capitals = {}, lakes = {},
		start_town = {pad_low = 64, pad_high = 63, band = 12}}
	for _, zone in ipairs(W.source.zones) do
		-- The gameplay band, as grug_zones serves it (zone_bands.lua).
		local z = zone_bands.apply(S.get(zone.id))
		local biomes = {}
		for i, b in ipairs(z.biomes) do biomes[i] = {id = b.id, share = b.share} end
		meta.zones[#meta.zones + 1] = {numeric_id = z.numeric_id, id = z.id,
			display_name = z.display_name, race_region = z.race_region,
			faction = z.faction or "contested", territory_rule = z.territory_rule,
			pvp_rule = z.pvp_rule, level_min = z.level_min, level_max = z.level_max,
			relief = z.primary_relief_id, hub = {x = z.hub.x, z = z.hub.z},
			macro_region = z.macro_region, biomes = biomes,
			civic_no_hostiles = z.civic_no_hostiles,
			neighbors = S.neighbors(zone.id)}
	end
	local labels = {}
	for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r20_poi_catalog.lua")) do
		labels[("anchor_%03d"):format(row.number)] = row.label
	end
	for _, authored in ipairs(W.source.anchors) do
		local zone = W.source.zones[authored.zone_numeric_id]
		local a = S.anchor(zone.id, authored.slot_id)
		meta.anchors[#meta.anchors + 1] = {id = authored.id, numeric_id = authored.numeric_id,
			zone_id = zone.id, slot = authored.slot_id, kind = authored.template_id,
			x = a.x, y = a.y, z = a.z, label = labels[authored.id]}
	end
	local ids = {}
	for id in pairs(W.road_layout.roads) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local road = W.road_layout.roads[id]
		local pts, n = {}, #road.X
		for i = 1, n, 2 do pts[#pts + 1] = {floor(road.X[i] + 0.5), floor(road.Z[i] + 0.5)} end
		if (n - 1) % 2 ~= 0 then pts[#pts + 1] = {floor(road.X[n] + 0.5), floor(road.Z[n] + 0.5)} end
		meta.roads[#meta.roads + 1] = {id = id, kind = road.kind, a = road.a, b = road.b,
			parent = road.parent, half_width = road.hw, points = pts}
	end
	for _, line in ipairs(W.wp40.river_polylines) do
		local pts = {}
		for _, p in ipairs(line.points or line) do pts[#pts + 1] = {floor(p.x + 0.5), floor(p.z + 0.5)} end
		meta.rivers[#meta.rivers + 1] = {kind = line.kind, points = pts}
	end
	for id, entry in pairs(W.layouts) do
		local L = entry.layout
		local ax, az = L.anchor.x, L.anchor.z
		local gates, plots, wall = {}, {}, {}
		for c = 1, 4 do
			local g = L.gates[c]
			gates[#gates + 1] = {name = g.name, x = floor(ax + g.x + 0.5), z = floor(az + g.z + 0.5), y = g.y}
		end
		for _, p in ipairs(L.plots) do
			plots[#plots + 1] = {id = p.id, x = ax + p.x, z = az + p.z, y = p.y}
		end
		for i = 1, #L.wall.pts, 4 do
			wall[#wall + 1] = {floor(ax + L.wall.pts[i][1] + 0.5), floor(az + L.wall.pts[i][2] + 0.5)}
		end
		-- the protected city's bounding box, scanned every 2 nodes
		local shape = W.capital_shapes[id]
		local bx0, bz0, bx1, bz1, count = math.huge, math.huge, -math.huge, -math.huge, 0
		for dz = -270, 270, 2 do
			for dx = -270, 270, 2 do
				if shape.member(ax + dx, az + dz) then
					count = count + 1
					if ax + dx < bx0 then bx0 = ax + dx end
					if ax + dx > bx1 then bx1 = ax + dx end
					if az + dz < bz0 then bz0 = az + dz end
					if az + dz > bz1 then bz1 = az + dz end
				end
			end
		end
		meta.capitals[#meta.capitals + 1] = {anchor_id = id, kind = L.kind, x = ax, z = az,
			gates = gates, plots = plots, wall = wall,
			city_box = {min_x = bx0, min_z = bz0, max_x = bx1, max_z = bz1},
			city_area = count * 4}
	end
	table.sort(meta.capitals, function(a, b) return a.anchor_id < b.anchor_id end)
	for _, row in ipairs(W.authored_water) do
		meta.lakes[#meta.lakes + 1] = {id = row.id, min_x = row.min_x, max_x = row.max_x,
			min_z = row.min_z, max_z = row.max_z, anchor = row.anchor, river = row.river}
	end
	meta.seconds = {build = build_seconds, band0_sample = sample_seconds}
	local out = {}
	json(meta, out)
	local f = assert(io.open(out_dir .. "/meta.json", "w"))
	f:write(table.concat(out))
	f:close()
end
io.stderr:write(("band %d/%d rows %d..%d: build %.1f s, sample %.1f s (CPU)\n"):format(
	band, bands, first, last, build_seconds, sample_seconds))
