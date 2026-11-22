-- Round 86 lane ROADS: what a change of the road cut moves on one seed
-- (the merge gate on production's seed). Builds the seed's real world plan
-- (the seed fleet's runtime) from REPO and writes into OUT:
--   layouts.txt   sha256 of the water, road, capital and placement layout
--                 texts, the prepared handover and the settlement sockets
--                 (as the seed fleet's digest mode), and of every zone's
--                 spawn region map (camps, leaders, quest places, cells;
--                 built as the game builds them, `spawn_regions_core.lua`)
--   raster.tsv    every column within SIDE_MAX + 3 of a road's edge: x, z,
--                 final ground, road kind ("-" off the roads), overlay
--                 exclusion ("-" none)
--   chunks.txt    per chunk listed in AT (the chunk columns holding these
--                 x,z columns, every 80-node layer from the lowest to the
--                 highest final ground within 48 of them): the written
--                 nodes' hash and the owner's decoration candidates (x y z
--                 per candidate, sorted)
--
--   luajit tools/r86_roads/digest.lua REPO SEED OUT ["x,z x,z ..."]
-- tools/r86_roads/compare.py BEFORE AFTER lists what moved.
local repo, seed, out, at_list = arg[1], arg[2], arg[3], arg[4] or ""
assert(repo and seed and out, "usage: digest.lua REPO SEED OUT [\"x,z ...\"]")
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local R = dofile(here .. "/../seed_fleet/runtime.lua")(repo, seed)
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local RL = dofile(wp40 .. "/road_layout.lua")
local floor = math.floor
local function hex(bytes)
	return (R.sha(bytes):gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
-- (a table met again, a cycle or a shared row, is written as "@": the
-- region maps link cells and regions both ways)
local function canonical(value, parts, seen)
	local kind = type(value)
	seen = seen or {}
	if kind == "table" and seen[value] then
		parts[#parts + 1] = "@"
	elseif kind == "table" then
		seen[value] = true
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		parts[#parts + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, parts, seen)
			parts[#parts + 1] = "="
			canonical(value[key], parts, seen)
			parts[#parts + 1] = ";"
		end
		parts[#parts + 1] = "}"
	elseif kind == "number" then
		parts[#parts + 1] = ("%.17g"):format(value)
	elseif kind == "string" then
		parts[#parts + 1] = ("%q"):format(value)
	elseif kind == "boolean" then
		parts[#parts + 1] = tostring(value)
	else
		parts[#parts + 1] = kind
	end
	return parts
end

local main, q, zones = R.main, R.planner_source, R.built.zones_session
local f = assert(io.open(out .. "/layouts.txt", "w"))
f:write("layout water ", hex(main.water_layout_text()), "\n")
f:write("layout roads ", hex(main.road_layout_text()), "\n")
f:write("layout capitals ", hex(main.capital_layout_text()), "\n")
f:write("layout placement ", hex(main.placement_layout_text()), "\n")
f:write("layout handover ", hex(table.concat(canonical(main.prepared_handover(), {}))), "\n")
f:write("layout sockets ", hex(table.concat(canonical(main.settlement_sockets(R.built), {}))), "\n")
-- the spawn region maps (as tools/seed_fleet/seed.lua quest_places builds them)
do
	local SOURCE = dofile(wp40 .. "/source/simple_map.lua")
	local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local function read(path)
		local file = assert(io.open(path, "rb"))
		local text = file:read("*a")
		file:close()
		return text
	end
	local catalogue = {}
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
	for _, row in ipairs(data[1] and data or data.subtypes) do catalogue[row.role] = row end
	local labels = {}
	for _, row in ipairs(dofile(wp40 .. "/r7_settlement.lua").roster) do
		if row.anchor_id then labels[row.anchor_id] = row.label end
	end
	local L = dofile(wp40 .. "/breach_layout.lua")
	local queries = core.queries({zones = zones, column_values_at = q.column_values_at,
		road_polylines = main.road_polylines(), source = SOURCE,
		reserved = core.reserved_of(L.world(L.from_placement(main.placement_layout_text())))})
	for _, row in ipairs(SOURCE.zones) do
		local path = repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. row.id .. ".spawns.json"
		local file = io.open(path, "rb")
		local spawns = file and json.parse(file:read("*a"))
		if file then file:close() end
		if spawns and spawns.recipe then
			local record = zones.get(row.id)
			local recipe = core.parse_recipe(row.id, spawns.recipe, {
				band = {record.level_min, record.level_max},
				role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
				leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
				pois = function(id) return core.zone_pois(SOURCE, id, labels) end,
			})
			local map = core.build(row.id, queries, recipe)
			f:write("region ", row.id, " ", hex(table.concat(canonical(map, {}))), "\n")
			-- per top-level field, and the spots, for compare.py's listing
			local keys = {}
			for key in pairs(map) do keys[#keys + 1] = key end
			table.sort(keys)
			for _, key in ipairs(keys) do
				f:write("field ", row.id, ".", key, " ", hex(table.concat(canonical(map[key], {}))), "\n")
			end
			for _, kind in ipairs({"camps", "leaders", "places"}) do
				for _, s in ipairs(map[kind] or {}) do
					f:write("spot ", row.id, ".", kind, ".", tostring(s.id or s.role), "@",
						tostring(s.x), ",", tostring(s.z), " ", "1\n")
				end
			end
		end
	end
end
f:close()

-- the raster round the roads
local layout = RL.deserialize(main.road_layout_text())
local sampler = RL.sampler(layout)
local SIDE, PAD = RL.P.SIDE_MAX, RL.P.SIDE_MAX + 3
local tiles, order = {}, {}
for _, r in ipairs(layout.roads) do
	local reach = r.hw + PAD + 1
	for i = 1, #r.X do
		for tz = floor((r.Z[i] - reach) / 16), floor((r.Z[i] + reach) / 16) do
			for tx = floor((r.X[i] - reach) / 16), floor((r.X[i] + reach) / 16) do
				local k = tz * 65536 + tx
				if not tiles[k] then
					tiles[k] = true
					order[#order + 1] = {tx, tz}
				end
			end
		end
	end
end
table.sort(order, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]) end)
f = assert(io.open(out .. "/raster.tsv", "w"))
local rows = 0
for _, t in ipairs(order) do
	for z = t[2] * 16, t[2] * 16 + 15 do
		for x = t[1] * 16, t[1] * 16 + 15 do
			if sampler.near(x, z, PAD) then
				local kind = q.road_column_at(x, z)
				f:write(x, "\t", z, "\t", zones.terrain_height_at(x, z), "\t", kind or "-", "\t",
					q.overlay_exclusion_at(x, z) or "-", "\n")
				rows = rows + 1
			end
		end
	end
end
f:close()

-- the chunks at the listed columns
f = assert(io.open(out .. "/chunks.txt", "w"))
local done = {}
for x, z in at_list:gmatch("(%-?%d+),(%-?%d+)") do
	x, z = tonumber(x), tonumber(z)
	local lo, hi = math.huge, -math.huge
	for dz = -48, 48, 4 do
		for dx = -48, 48, 4 do
			local y = zones.terrain_height_at(x + dx, z + dz)
			if y < lo then lo = y end
			if y > hi then hi = y end
		end
	end
	for cz = R.origin(z - 48), R.origin(z + 48), 80 do
		for cx = R.origin(x - 48), R.origin(x + 48), 80 do
			for cy = R.origin(lo), R.origin(hi), 80 do
				local key = cx .. "," .. cy .. "," .. cz
				if not done[key] then
					done[key] = true
					local result = R.chunk({x = cx, y = cy, z = cz})
					local cand, rowsc = {}, {}
					for v in result.candidates:gmatch("[^,]+") do cand[#cand + 1] = v end
					for i = 1, #cand, 7 do
						rowsc[#rowsc + 1] = cand[i + 3] .. ":" .. cand[i + 4] .. ":" .. cand[i + 5]
					end
					table.sort(rowsc)
					f:write("chunk ", key, " nodes=", result.data_hash, " candidates=",
						table.concat(rowsc, ";"), "\n")
				end
			end
		end
	end
end
f:close()
print(("digest %s: raster %d columns, %d chunks"):format(seed, rows, (function()
	local n = 0
	for _ in pairs(done) do n = n + 1 end
	return n
end)()))
