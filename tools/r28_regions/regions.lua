-- Round 28 Lane S1: the spawn regions of zones for one seed, without the
-- engine (LuaJIT), for the review images.
--
--   luajit tools/r28_regions/regions.lua <repo> <seed> <out_dir> <zone> [<zone> ...]
--
-- Builds the analytic world of the seed once with
-- tools/r28_zone_atlas/world.lua (as main builds it), then per zone parses
-- its recipe from the SHIPPED data file
-- mods/ENTITIES/grug_mobs/data/zones/<zone>.spawns.json against the shipped
-- sub-type catalogue, and runs the game's own spawn_regions_core.lua with
-- the game's own query adapter (core.queries). So the map drawn is the map
-- the game builds for that seed. A zone that fails is reported and skipped;
-- the exit status is then 1. (Memory numbers of later zones in one process
-- run on a planner cache the earlier zones warmed.)
--
-- Writes <out_dir>/<zone>_<seed>.json (frame, cells, regions, kinds, camps,
-- leaders, roads, places, stats, describe phrases) and <zone>_<seed>.bin
-- (the base raster every RASTER nodes, row-major from the frame's south-west
-- corner, z outer: u8 water 1 land / 2 sea / 3 river or lake, u8 owner 1 =
-- this zone, i16 LE terrain height). render.py draws them.
local repo, seed, out_dir = arg[1], arg[2], arg[3]
local zone_list = {}
for i = 4, #arg do zone_list[#zone_list + 1] = arg[i] end
assert(repo and seed and out_dir and #zone_list > 0,
	"usage: regions.lua <repo> <seed> <out_dir> <zone> [<zone> ...]")
local RASTER = 4
local MARGIN = 64

local t0 = os.clock()
local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
local world_seconds = os.clock() - t0
local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local S = W.session

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- The catalogue (levels, leader flags, display names).
local catalogue = {}
do
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
	if not data[1] then data = data.subtypes end
	for _, row in ipairs(data) do catalogue[row.role] = row end
end

-- The settlement roster: place names, POI names, the start town's elder.
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local labels = {}
for _, row in ipairs(settlement.roster) do
	if row.anchor_id then labels[row.anchor_id] = row.label end
end
local q = core.queries({zones = S, column_values_at = W.planner_source.column_values_at,
	road_polylines = W.wp40.road_polylines, source = W.source})

local function render_zone(zone)
	local function display(role)
		local row = catalogue[role]
		if not row then return role end
		return row.display_by_zone and row.display_by_zone[zone] or row.display
	end

	local record = S.get(zone)
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json"))
	assert(data.recipe, zone .. " has no recipe")
	local recipe = core.parse_recipe(zone, data.recipe, {
		band = {record.level_min, record.level_max},
		role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
		leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
		pois = function(id) return core.zone_pois(W.source, id, labels) end,
	})
	-- Retained memory of the map: after full collections on both sides. The
	-- planner's own bounded column cache, which the queries also warm, is part
	-- of the measured difference (as it would be in the game).
	collectgarbage()
	collectgarbage()
	local kib0 = collectgarbage("count")
	local t1 = os.clock()
	local map = core.build(zone, q, recipe)
	local build_seconds = os.clock() - t1
	collectgarbage()
	collectgarbage()
	local build_kib = collectgarbage("count") - kib0
	-- The map's own size: two more maps, the older one measured by freeing it
	-- (nothing else runs between the two counts, so the planner's cache cannot
	-- move; the newer one keeps whatever the last call left on the stack).
	local spare = {core.build(zone, q, recipe)}
	spare[2] = core.build(zone, q, recipe)
	collectgarbage()
	collectgarbage()
	local kib_with = collectgarbage("count")
	spare[1] = nil
	collectgarbage()
	collectgarbage()
	local map_kib = kib_with - collectgarbage("count")
	spare = nil

	-- Places: the settlement roster's names at their fitted anchors.
	local places, by_ref = {}, {}
	for _, row in ipairs(settlement.roster) do
		local a = S.anchor(row.zone_id, row.slot)
		if a then
			local p = {key = row.key, anchor_id = row.anchor_id, slot = row.slot,
				zone = row.zone_id, name = row.label, x = a.x, z = a.z}
			by_ref[row.key], by_ref[row.anchor_id] = p, p
			if row.zone_id == zone then places[#places + 1] = p end
		end
	end

	-- The start town's quest giver (the elder, socket hall_quest), placed as
	-- main places it: the prepared blueprint's sockets on the fitted anchor.
	-- The "of" phrases name the first `from` anchor (none for a border entry).
	local from_ref = recipe.from and recipe.from.anchors and recipe.from.anchors[1]
	local from_place = from_ref and by_ref[from_ref]
	for _, p in pairs(by_ref) do
		if from_ref and p.zone == zone and p.slot == from_ref then from_place = p end
	end
	local elder
	do
		for _, profile in ipairs(settlement.roster) do
			if profile.zone_id == zone and profile.slot == "start" then
				local options = {full_seed = seed, raw_sha256 = W.sha}
				local src = dofile(wp40 .. "/" .. profile.blueprint_file)(options, profile)
				if type(src) == "function" then src = src(options) end
				local prepared = settlement.prepare(profile, src, W.sha, nil)
				local anchor = S.anchor(zone, profile.slot)
				for _, socket in ipairs(settlement.sockets(prepared, anchor)) do
					if socket.id == "hall_quest" then
						elder = {x = anchor.x + socket.x, z = anchor.z + socket.z,
							name = "the elder (hall_quest)"}
					end
				end
			end
		end
	end

	-- Frame: the zone's land cells plus a margin, on the raster grid.
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, c in ipairs(map.order) do
		x0, x1 = math.min(x0, c.i * core.CELL), math.max(x1, c.i * core.CELL + core.CELL)
		z0, z1 = math.min(z0, c.j * core.CELL), math.max(z1, c.j * core.CELL + core.CELL)
	end
	x0, z0 = math.floor((x0 - MARGIN) / RASTER) * RASTER, math.floor((z0 - MARGIN) / RASTER) * RASTER
	x1, z1 = math.ceil((x1 + MARGIN) / RASTER) * RASTER, math.ceil((z1 + MARGIN) / RASTER) * RASTER
	local cols, rows = (x1 - x0) / RASTER, (z1 - z0) / RASTER
	local t2 = os.clock()
	local bin = assert(io.open(("%s/%s_%s.bin"):format(out_dir, zone, seed), "wb"))
	local char = string.char
	local WATER = {land = 1, sea = 2, inland = 3}
	for r = 0, rows - 1 do
		local z = z0 + r * RASTER + RASTER / 2
		local buf = {}
		for c = 0, cols - 1 do
			local x = x0 + c * RASTER + RASTER / 2
			local w = WATER[q.water_at(x, z)] or 2
			local own = q.zone_at(x, z) == zone and 1 or 0
			local h = S.terrain_height_at(x, z)
			if h < -32768 then h = -32768 elseif h > 32767 then h = 32767 end
			local u = h % 65536
			buf[#buf + 1] = char(w, own, u % 256, math.floor(u / 256))
		end
		bin:write(table.concat(buf))
	end
	bin:close()
	local raster_seconds = os.clock() - t2

	-- Directions (describe) for the camp, the leaders and every kind.
	local function phrases(target)
		local out = {}
		local a = from_place and core.describe(map, target, "of", from_place)
		local b = elder and core.describe(map, target, "from", elder)
		local c = core.describe(map, target, "zone", nil, record.display_name)
		out.of = a and {phrase = a.phrase, dir = a.dir, distance = a.distance, key = a.phrase_key}
		out.from_giver = b and {phrase = b.phrase, dir = b.dir, distance = b.distance, key = b.phrase_key}
		out.zone = c and {phrase = c.phrase, dir = c.dir, distance = c.distance, key = c.phrase_key}
		return out
	end

	-- The JSON document.
	local doc = {seed = seed, zone = zone, zone_name = record.display_name,
		band = {record.level_min, record.level_max}, cell = core.CELL,
		frame = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, step = RASTER, cols = cols, rows = rows},
		seconds = {world = world_seconds, regions = build_seconds, raster = raster_seconds},
		build_kib = build_kib, map_kib = map_kib, heights = map.heights,
		smoothed_cells = map.smoothed_cells,
		from = from_place and {x = from_place.x, z = from_place.z, name = from_place.name},
		to = recipe.to and recipe.to.border or {}, to_core = recipe.to and recipe.to.core,
		from_border = recipe.from and recipe.from.border, giver = elder, places = places, cells = {}, regions = {}, kinds = {}, belts = {},
		camps = {}, leaders = {}, roads = {}, phrases = {}, patches = {},
		stats = core.stats(map), thresholds = {
			shore_share = core.SHORE_SHARE, bank_share = core.BANK_SHARE,
			high_slope = core.HIGH_SLOPE, high_rank = core.HIGH_RANK,
			high_above = core.HIGH_ABOVE, min_cells = core.MIN_CELLS,
			min_strip = core.MIN_STRIP, max_cells = core.MAX_CELLS,
			split_target = core.SPLIT_TARGET, camp_road_min = core.CAMP_ROAD_MIN,
			camp_slope = core.CAMP_SLOPE, near = core.NEAR, heart = core.HEART}}
	local TYPE_CODE = {}
	for i, t in ipairs(core.TYPES) do TYPE_CODE[t] = i end
	for _, c in ipairs(map.order) do
		doc.cells[#doc.cells + 1] = {c.i, c.j, c.region.id, c.belt, TYPE_CODE[c.type]}
	end
	local function roster_rows(unit, roster)
		local out = {}
		for _, row in ipairs(roster.list) do
			local range = unit.levels_by_role[row.role]
			out[#out + 1] = {role = row.role, name = display(row.role), weight = row.weight,
				levels = {range[1], range[2]}}
		end
		return out
	end
	for b, belt in ipairs(recipe.belts) do
		doc.belts[b] = {id = belt.id, levels = belt.levels, share = belt.share,
			max_from = belt.max_from}
	end
	for _, kind in ipairs(recipe.kinds) do
		doc.kinds[#doc.kinds + 1] = {id = kind.id, name = kind.name, type = kind.type,
			belt = kind.belt.index, density = kind.density, levels = kind.levels,
			day = roster_rows(kind, kind.rosters.day), night = roster_rows(kind, kind.rosters.night),
			inherits = kind.inherits, phrases = phrases(kind.id)}
	end
	for _, r in ipairs(map.regions) do
		doc.regions[#doc.regions + 1] = {id = r.id, kind = r.kind.id, belt = r.belt,
			size = r.size, x = r.x, z = r.z, level = r.level, camp = r.camp and true or nil}
	end
	for _, unit in ipairs(map.camps) do
		local camp = unit.camp
		doc.camps[#doc.camps + 1] = {id = camp.id, name = camp.name, x = unit.x, z = unit.z,
			slots = camp.slots, respawn = camp.respawn, levels = unit.levels,
			roster = roster_rows(unit, camp.roster), score = unit.score,
			road = unit.cell.road, phrases = phrases(camp.id),
			poi = unit.site and unit.site.name, belt = unit.belt.id,
			poi_belt = unit.poi_belt and unit.poi_belt.id}
	end
	for _, l in ipairs(map.leaders) do
		doc.leaders[#doc.leaders + 1] = {role = l.role, name = display(l.role), x = l.x,
			z = l.z, level = l.level, respawn = l.respawn, phrases = phrases(l.role),
			fallback = l.fallback}
	end
	for _, line in ipairs(W.wp40.road_polylines) do
		local pts, inside = {}, false
		for _, p in ipairs(line.points) do
			pts[#pts + 1] = {p.x, p.z}
			if p.x >= x0 and p.x <= x1 and p.z >= z0 and p.z <= z1 then inside = true end
		end
		if inside then doc.roads[#doc.roads + 1] = {kind = line.kind, points = pts} end
	end
	-- Patches: for every kind with several regions, the direction of each patch
	-- from the giver, against the direction describe uses (the largest patch).
	if elder then
		for _, kind in ipairs(recipe.kinds) do
			local list = map.by_kind[kind.id] or {}
			if #list > 1 then
				local chosen = core.describe(map, kind.id, "from", elder)
				local rows = {}
				local differ, differ_cells, cells = 0, 0, 0
				for _, r in ipairs(list) do
					local dx, dz = r.x - elder.x, r.z - elder.z
					local dir = math.sqrt(dx * dx + dz * dz) < core.NEAR and "nearby" or
						core.compass(elder.x, elder.z, r.x, r.z)
					local same = dir == (chosen.dir or "nearby")
					if not same then
						differ = differ + 1
						differ_cells = differ_cells + r.size
					end
					cells = cells + r.size
					rows[#rows + 1] = {region = r.id, size = r.size, dir = dir}
				end
				doc.patches[#doc.patches + 1] = {kind = kind.id, chosen = chosen.dir or "nearby",
					regions = rows, differ = differ, differ_share = differ_cells / cells}
			end
		end
	end
	-- The three phrases the coordinator asked for: the camp and the leader.
	for _, unit in ipairs(doc.camps) do doc.phrases[unit.id] = unit.phrases end
	for _, l in ipairs(doc.leaders) do doc.phrases[l.role] = l.phrases end

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
	local f = assert(io.open(("%s/%s_%s.json"):format(out_dir, zone, seed), "w"))
	f:write(table.concat(out))
	f:close()
	io.stderr:write(("%s seed %s: world %.1f s, regions %.2f s (%.0f KiB), raster %.1f s, " ..
		"%d cells, %d regions, %d problems, %d warnings\n"):format(zone, seed, world_seconds,
		build_seconds, build_kib, raster_seconds, #map.order, #map.regions, #map.problems,
		#map.warnings))
end

local failed = 0
for _, zone in ipairs(zone_list) do
	local ok, err = pcall(render_zone, zone)
	if not ok then
		failed = failed + 1
		io.stderr:write(("%s seed %s FAILED: %s\n"):format(zone, seed, tostring(err)))
	end
end
if failed > 0 then
	error(failed .. " zone(s) failed for seed " .. seed, 0)
end
