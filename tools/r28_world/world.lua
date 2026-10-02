-- Round 28 Lane W1: the spawn levels of the whole mainland for one seed,
-- without the engine (LuaJIT), for the world view images.
--
--   luajit tools/r28_world/world.lua <repo> <seed> <out_dir> [<zones_dir>]
--
-- Builds the analytic world of the seed once (tools/r28_zone_atlas/world.lua,
-- as main builds it), then the region map of every mainland zone with the
-- game's own spawn_regions_core.lua and query adapter, as
-- tools/r28_regions/regions.lua does for single zones. Each zone's recipe is
-- read from <zones_dir>/<zone>.spawns.json when that file exists (a
-- proposal: tools/r28_world/border_rule.py --out), else from the shipped
-- mods/ENTITIES/grug_mobs/data/zones/<zone>.spawns.json. The two dragon
-- islands are left out (one belt, L60, no land border).
--
-- Writes <out_dir>/world_<seed>.json (frame, zones with their belts and
-- cells, places, border edges classified by tools/r28_world/borders.lua) and
-- world_<seed>.bin (the base raster every RASTER nodes, row-major from the
-- frame's south-west corner, z outer: u8 water 1 land / 2 sea / 3 river or
-- lake, u8 zone index + 1 into the JSON's zone list, 0 = none). A zone
-- without a recipe, or whose recipe fails, keeps cells from the raster (the
-- plurality owner of each cell's 4 x 4 samples, land when at least half are
-- land) without levels; render.py draws them grey.
local repo, seed, out_dir, zones_dir = arg[1], arg[2], arg[3], arg[4]
assert(repo and seed and out_dir, "usage: world.lua <repo> <seed> <out_dir> [<zones_dir>]")
local RASTER = 8   -- the spawn-region sample pitch: one raster sample per region sample
local MARGIN = 96
local SCAN = 64

local t0 = os.clock()
local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
local world_seconds = os.clock() - t0
local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local borders = dofile(repo .. "/tools/r28_world/borders.lua")
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local zone_bands = dofile(repo .. "/mods/CORE/grug_core/zone_bands.lua")
local S = W.session
local CELL, SUB = core.CELL, core.SUB

local function read(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local catalogue = {}
do
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
	if not data[1] then data = data.subtypes end
	for _, row in ipairs(data) do catalogue[row.role] = row end
end
_G.core = _G.core or {}
local settlement = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
local labels = {}
for _, row in ipairs(settlement.roster) do
	if row.anchor_id then labels[row.anchor_id] = row.label end
end
local q = core.queries({zones = S, column_values_at = W.planner_source.column_values_at,
	road_polylines = W.wp40.road_polylines, source = W.source})

-- The mainland zones, in source order.
local zones, index = {}, {}
for _, row in ipairs(W.source.zones) do
	local record = zone_bands.apply(S.get(row.id))
	if not record.macro_region:match("_island$") then
		zones[#zones + 1] = {id = row.id, name = record.display_name, faction = record.faction,
			race = record.race_region, band = {record.level_min, record.level_max}, cells = {}}
		index[row.id] = #zones
	end
end

-- Frame: the mainland zones' land on a coarse scan, plus a margin.
local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
for x = -4096, 4096, SCAN do
	for z = -4096, 4096, SCAN do
		local id = q.zone_at(x, z)
		if id and index[id] and q.water_at(x, z) == "land" then
			x0, x1 = math.min(x0, x), math.max(x1, x)
			z0, z1 = math.min(z0, z), math.max(z1, z)
		end
	end
end
x0, z0 = math.floor((x0 - MARGIN) / CELL) * CELL, math.floor((z0 - MARGIN) / CELL) * CELL
x1, z1 = math.ceil((x1 + MARGIN) / CELL) * CELL, math.ceil((z1 + MARGIN) / CELL) * CELL
local cols, rows = (x1 - x0) / RASTER, (z1 - z0) / RASTER

-- The raster (the samples sit where the region builder samples: 8 s + 4).
local t1 = os.clock()
local WATER = {land = 1, sea = 2, inland = 3}
local r_water, r_zone = {}, {}
do
	local bin = assert(io.open(("%s/world_%s.bin"):format(out_dir, seed), "wb"))
	local char = string.char
	for r = 0, rows - 1 do
		local z = z0 + r * RASTER + RASTER / 2
		local buf = {}
		for c = 0, cols - 1 do
			local x = x0 + c * RASTER + RASTER / 2
			local w = WATER[q.water_at(x, z)] or 2
			local id = q.zone_at(x, z)
			local zi = id and index[id] or 0
			local k = r * cols + c
			r_water[k], r_zone[k] = w, zi
			buf[#buf + 1] = char(w, zi)
		end
		bin:write(table.concat(buf))
	end
	bin:close()
end
local raster_seconds = os.clock() - t1

-- Raster cells of a zone (no recipe, or its recipe failed).
local function raster_cells(zi)
	local out = {}
	for cj = 0, rows / SUB - 1 do
		for ci = 0, cols / SUB - 1 do
			local counts, land = {}, 0
			for b = 0, SUB - 1 do
				for a = 0, SUB - 1 do
					local k = (cj * SUB + b) * cols + ci * SUB + a
					local o = r_zone[k]
					counts[o] = (counts[o] or 0) + 1
					if r_water[k] == 1 then land = land + 1 end
				end
			end
			local best, best_n = 0, 0
			for o = 1, #zones do
				if (counts[o] or 0) > best_n then best, best_n = o, counts[o] end
			end
			if best == zi and land >= SUB * SUB / 2 then
				out[#out + 1] = {x0 / CELL + ci, z0 / CELL + cj}
			end
		end
	end
	return out
end

local function display(zone, role)
	local row = catalogue[role]
	if not row then return role end
	return row.display_by_zone and row.display_by_zone[zone] or row.display
end

-- Every zone's map.
local t2 = os.clock()
local failed = 0
for zi, zone in ipairs(zones) do
	local own = zones_dir and ("%s/%s.spawns.json"):format(zones_dir, zone.id)
	local path = own and read(own) and own or
		("%s/mods/ENTITIES/grug_mobs/data/zones/%s.spawns.json"):format(repo, zone.id)
	zone.source = path == own and "proposal/" .. zone.id .. ".spawns.json" or
		path:sub(#repo + 2)
	local data = json.parse(assert(read(path), path))
	if data.recipe then
		local ok, err = pcall(function()
			local recipe = core.parse_recipe(zone.id, data.recipe, {
				band = zone.band,
				role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
				leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
				pois = function(id) return core.zone_pois(W.source, id, labels) end,
			})
			local map = core.build(zone.id, q, recipe)
			zone.recipe = true
			zone.from = data.recipe.from
			zone.to = data.recipe.to
			zone.belts = {}
			for b, belt in ipairs(recipe.belts) do
				zone.belts[b] = {id = belt.id, levels = belt.levels}
			end
			zone.problems, zone.warnings = map.problems, map.warnings
			for _, c in ipairs(map.order) do
				local lv = recipe.belts[c.region.belt].levels
				zone.cells[#zone.cells + 1] = {c.i, c.j, lv[1], lv[2], c.region.belt, c.region.id}
			end
			zone.regions = {}
			for _, r in ipairs(map.regions) do
				local lv = recipe.belts[r.belt].levels
				zone.regions[#zone.regions + 1] = {id = r.id, belt = r.belt, size = r.size,
					x = r.x, z = r.z, levels = {lv[1], lv[2]}}
			end
			zone.leaders = {}
			for _, l in ipairs(map.leaders) do
				zone.leaders[#zone.leaders + 1] = {role = l.role, name = display(zone.id, l.role),
					x = l.x, z = l.z, level = l.level}
			end
		end)
		if not ok then
			failed = failed + 1
			zone.error = tostring(err)
			zone.recipe, zone.belts, zone.regions, zone.cells = nil, nil, nil, {}
			io.stderr:write(("%s seed %s FAILED: %s\n"):format(zone.id, seed, zone.error))
		end
	end
	if not zone.recipe then
		zone.cells = raster_cells(zi)
	end
end
local regions_seconds = os.clock() - t2

-- Places: the capitals and start towns at their fitted anchors.
local places = {}
for _, row in ipairs(settlement.roster) do
	if (row.slot == "capital" or row.slot == "start") and index[row.zone_id] then
		local a = S.anchor(row.zone_id, row.slot)
		if a then
			places[#places + 1] = {zone = row.zone_id, slot = row.slot, name = row.label,
				x = a.x, z = a.z}
		end
	end
end

local edges, duplicates = borders.edges(zones)
local doc = {seed = seed, proposal = zones_dir ~= nil, cell = CELL,
	frame = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, step = RASTER, cols = cols, rows = rows},
	seconds = {world = world_seconds, raster = raster_seconds, regions = regions_seconds},
	zones = {}, places = places, edges = {}, duplicates = duplicates,
	thresholds = {fit = borders.FIT, step = borders.STEP}}
for _, zone in ipairs(zones) do
	doc.zones[#doc.zones + 1] = zone
end
for _, e in ipairs(edges) do
	doc.edges[#doc.edges + 1] = {e.i, e.j, e.side, e.a, e.b, e.a_lo or false, e.a_hi or false,
		e.b_lo or false, e.b_hi or false, e.gap or false, e.band_gap, e.class}
end

-- A small JSON writer (sorted keys, arrays when t[1] ~= nil or empty).
local function encode(value, out)
	local kind = type(value)
	if kind == "table" then
		if value[1] ~= nil or next(value) == nil then
			out[#out + 1] = "["
			for i = 1, #value do
				if i > 1 then out[#out + 1] = "," end
				encode(value[i], out)
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
				encode(value[k], out)
			end
			out[#out + 1] = "}"
		end
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			out[#out + 1] = "null"
		elseif value % 1 == 0 then
			out[#out + 1] = ("%d"):format(value)
		else
			out[#out + 1] = ("%.4f"):format(value)
		end
	elseif kind == "string" then
		out[#out + 1] = '"' .. value:gsub('[%c"\\]', function(ch)
			return ("\\u%04x"):format(ch:byte()) end) .. '"'
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	else
		out[#out + 1] = "null"
	end
end
local out = {}
encode(doc, out)
local f = assert(io.open(("%s/world_%s.json"):format(out_dir, seed), "w"))
f:write(table.concat(out))
f:close()
local totals = borders.totals(edges, CELL)
io.stderr:write(("world seed %s: world %.1f s, raster %.1f s (%d x %d), regions %.1f s, " ..
	"%d zones (%d failed), %d border edges: fit %d, step %d, jump %d, forced %d, none %d nodes\n"):format(
	seed, world_seconds, raster_seconds, cols, rows, regions_seconds, #zones, failed, #edges,
	totals.fit, totals.step, totals.jump, totals.forced, totals.none))
if failed > 0 then
	error(failed .. " zone(s) failed for seed " .. seed, 0)
end
