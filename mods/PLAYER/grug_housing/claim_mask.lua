-- The claim mask (Round 85 lane MASK; docs/design/housing.md §1-§2, Round 85
-- plan rulings 6, 14-16 and 20, housing rework concept §2.1): which map
-- chunks are claim ground for each faction, the rule that refuses every other
-- chunk, and per chunk the node columns of each quest-named mob kind's ground
-- for the placement quota. Pure: every world query is injected, so the game
-- (mask.lua) and the tools (tools/r85_mask) run these bytes. Plain Lua 5.1,
-- no globals, deterministic (no pairs order reaches a result).
--
-- A CHUNK is the engine's map chunk column (chunksize 5): cx = floor((x + 32)
-- / 80) for a node coordinate x, nodes 80 cx - 32 .. 80 cx + 47, the same in
-- z. A chunk is claim ground for a faction as a whole or not at all (ruling
-- 14). The rules, in the order that names the refusal:
--   1. the column rule on a lattice of 25 columns (every 16 nodes, the centre
--      first): every column on the faction's own ground (`column_problem`:
--      its seven level 11-30 zones and its three capital zones, no coastal
--      shelf, sea or protected deep water, no town or landmark column);
--   2. "site", "town" or "landmark": no settlement core (POI, village, camp)
--      and no hard footprint (capital city, start town, landmark column)
--      within MARGIN nodes (the placement check's feature_in);
--   3. "road": no protected road column (the corridor: half width + 1, x/z);
--   4. "camp": no 32 x 32 cell of a camp's spawn region; "leader", "place",
--      "rare": no leader spot, quest place or named rare's route point within
--      SPOT nodes (x and z);
--   5. the column rule on every column (the edge ring first);
--   6. "capital_ring": a chunk with ground in a capital zone has no chunk
--      that holds a column of a capital's protected city among its eight
--      neighbours.
-- The column rule's problem codes are the registry's (registry.lua
-- MESSAGES). Rule 5 is the expensive one (every column, about 3 us each): it
-- runs only for a chunk that passed 1-4, and its answers are kept per chunk
-- (`scans`, cached in the world folder by mask.lua), so a later start with
-- the same world plan asks no column.
--
-- THE QUOTA (ruling 16): a quest-named kind (a recipe kind with
-- quest_target) of a zone that can hold claim ground has as its ground the
-- 32 x 32 cells of all its regions, GROUND_PER_CELL columns each; a chunk
-- takes the columns of those cells inside it. A placement is refused when the
-- columns taken by every placed claim (drafts and expired ones included)
-- would exceed the kind's limit, half its ground. Ground that is never claim
-- ground counts as free. The mask only answers; the caller keeps the taken
-- columns (`quota_refusal`).
--
--   local CM = dofile(".../claim_mask.lua")
--   local mask = CM.build(world, scans)
--   mask.ground(faction, cx, cz)          -> true, or false and a reason id
--   mask.list(faction)                    -> {{cx, cz}, ...} every claim-ground
--                                            chunk, row order (cz, then cx)
--   mask.ground_in(faction, min_x, min_z, max_x, max_z) -> the claim-ground
--                                            chunks meeting the rectangle, row order
--   mask.kind_columns(cx, cz)             -> {{id, columns}, ...} any chunk
--   mask.kinds, mask.kind_by_id[id]       -> {id, zone, cells, ground, limit}
--   mask.quota_refusal(cx, cz, taken)     -> nil, or the first kind id whose
--                                            limit the chunk would exceed
--                                            (taken: kind id -> columns)
--   mask.add_taken(taken, cx, cz, sign)   -> taken with a placed claim's chunk
--                                            added (sign 1) or taken back (-1)
--
-- The reason ids: the column rule's "shelf", "sea", "enemy", "low_level",
-- "high_level", "not_home", "town", "deep_water" (registry.lua MESSAGES);
-- feature_in's "site", "town", "landmark"; "road", "camp", "leader",
-- "place", "rare", "capital_ring"; "no_faction" for an unknown faction. A
-- chunk outside the world plan answers "sea".
--
-- `world` (every coordinate a node coordinate):
--   bounds              {min_x, max_x, min_z, max_z}: the world plan's inclusive
--                       bounds; a column outside answers "sea"
--   zones               every zone record {id, faction, level_min, level_max,
--                       civic_no_hostiles, territory_rule}
--   water_at(x, z)      the placement world's water class ("land",
--                       "planned_water", "coastal_shelf", "deep_ocean", ...)
--   zone_at(x, z)       the owning zone record or nil
--   territory_at(x, z)  the territory rule at the world top
--   feature_in(min_x, min_z, max_x, max_z, margin) -> kind, id or nil
--   roads               {{id, X, Z, R, reach}, ...}: every road corridor's
--                       centreline points and its reach (half width + side)
--   cities              {{id, anchor = {x, z}, rows = {[lz] = {a1, b1, ...}}}}:
--                       every capital's protected city (capital_protection.lua
--                       shape: per anchor-relative row its x intervals;
--                       one rounded inward past itself, a > b, is empty)
--   spawn               CM.new_spawn() filled by CM.add_zone_spawn and
--                       CM.add_rare_route
--   height_at(x, z)     the planner's terrain height (fingerprints only)
-- `scans` (optional): the kept answers of rule 5, key CM.scan_key(cx, cz,
-- faction) -> {code = "ok" or a problem code, cap = boolean}; the build adds
-- the scans it makes to it (mask.new_scans counts them).
local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt

local M = {}

M.FORMAT = "grug_claim_mask_v1"
M.CHUNK = 80          -- nodes per chunk side (chunksize 5 x 16)
M.ORIGIN = -32        -- the first node of chunk 0
M.MARGIN = 16         -- rule 2: today's settlement margin (registry SETTLEMENT_MARGIN)
M.SPOT = 16           -- rule 4: around a leader, quest place or rare route point
M.CELL = 32           -- the spawn regions' cell side (spawn_regions_core CELL)
M.GROUND_PER_CELL = M.CELL * M.CELL
M.RING = 1            -- rule 6: whole chunks between a claim and the city
M.LATTICE = {8, 24, 40, 56, 72}  -- rule 1: chunk-relative offsets
M.ZONE_LEVEL_MIN = 11 -- the registry's zone band
M.ZONE_LEVEL_MAX = 30
M.FACTIONS = {"accord", "throng"}
-- Fingerprints (the stored data, docs/technical/claim-mask-format.md): a
-- STEP lattice over the chunk and a STRIP of nodes beyond each edge.
M.STRIP = 8
M.STEP = 4
M.DIGEST_HEX = 16

local CHUNK, ORIGIN = M.CHUNK, M.ORIGIN

local function fail(message)
	error("claim mask: " .. message, 0)
end

function M.chunk_of(v)
	return floor((v - ORIGIN) / CHUNK)
end

-- The inclusive node bounds of chunk (cx, cz): min_x, min_z, max_x, max_z.
function M.chunk_bounds(cx, cz)
	local x0, z0 = CHUNK * cx + ORIGIN, CHUNK * cz + ORIGIN
	return x0, z0, x0 + CHUNK - 1, z0 + CHUNK - 1
end

function M.scan_key(cx, cz, faction)
	return cx .. " " .. cz .. " " .. faction
end

-- Rules 1 and 5 for one column: the problem code for `faction`, or nil. The
-- registry's zone_problem (registry.lua) with the faction's capital zones
-- admitted (ruling 6). `capital` (second value) is true for a column of a
-- capital zone.
function M.column_problem(faction, water, zone, territory)
	if water == "coastal_shelf" then return "shelf" end
	if water ~= "land" and water ~= "planned_water" then return "sea" end
	if not zone then return "sea" end
	if zone.faction and zone.faction ~= faction then return "enemy" end
	if zone.level_min < M.ZONE_LEVEL_MIN then return "low_level" end
	if zone.level_max > M.ZONE_LEVEL_MAX then return "high_level" end
	local home = faction .. "_home"
	if zone.territory_rule ~= home then return "not_home" end
	if territory == "hard_protected" then return "town" end
	if territory == "immutable" then
		return water == "planned_water" and "deep_water" or "sea"
	end
	if territory ~= home then return "not_home" end
	return nil, zone.civic_no_hostiles == true
end

-- Whether a zone can hold claim ground for the faction (its seven level 11-30
-- zones and its three capital zones).
function M.zone_allowed(faction, zone)
	return M.column_problem(faction, "land", zone, faction .. "_home") == nil
end

--
-- Spawn content (rule 4 and the quota)
--

function M.new_spawn()
	return {camp_cells = {}, points = {}, kinds = {}}
end

-- One zone's region map: `each_cell(fn)` calls fn(i, j, region) for every
-- land cell (spawn_regions.lua SR.each_cell); a region has `kind` (its
-- recipe kind or camp, with `id` and `quest_target`) and `camp` (a camp
-- region's camp, else nil). `leaders` and `places`: the map's lists ({x, z}).
-- `quota`: true when the zone's quest-named kinds join the quota (a zone that
-- can hold claim ground).
function M.add_zone_spawn(spawn, zone_id, each_cell, leaders, places, quota)
	local kinds = {}
	each_cell(function(i, j, region)
		local cells = spawn.camp_cells
		if region.camp then
			cells[#cells + 1] = i
			cells[#cells + 1] = j
		elseif quota and region.kind and region.kind.quest_target then
			local id = zone_id .. "/" .. region.kind.id
			local kind = kinds[id]
			if not kind then
				kind = {id = id, zone = zone_id, cells = {}}
				kinds[id] = kind
				spawn.kinds[#spawn.kinds + 1] = kind
			end
			kind.cells[#kind.cells + 1] = i
			kind.cells[#kind.cells + 1] = j
		end
	end)
	for _, l in ipairs(leaders or {}) do
		spawn.points[#spawn.points + 1] = {x = l.x, z = l.z, kind = "leader"}
	end
	for _, p in ipairs(places or {}) do
		spawn.points[#spawn.points + 1] = {x = p.x, z = p.z, kind = "place"}
	end
end

-- A named rare's route: its points ({x, z}; grug_core.rare_route).
function M.add_rare_route(spawn, route)
	for _, p in ipairs(route) do
		spawn.points[#spawn.points + 1] = {x = p.x, z = p.z, kind = "rare"}
	end
end

--
-- Geometry
--

-- The squared distance of point (px, pz) from segment a-b.
local function point_segment_d2(px, pz, ax, az, bx, bz)
	local vx, vz = bx - ax, bz - az
	local l2 = vx * vx + vz * vz
	local u = l2 > 0 and ((px - ax) * vx + (pz - az) * vz) / l2 or 0
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	local dx, dz = px - ax - u * vx, pz - az - u * vz
	return dx * dx + dz * dz
end

local function point_rect_d2(px, pz, x0, z0, x1, z1)
	local dx = px < x0 and x0 - px or (px > x1 and px - x1 or 0)
	local dz = pz < z0 and z0 - pz or (pz > z1 and pz - z1 or 0)
	return dx * dx + dz * dz
end

-- Whether segments p1-p2 and q1-q2 meet (closed).
local function cross(ax, az, bx, bz, cx, cz)
	return (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
end
local function segments_meet(ax, az, bx, bz, cx, cz, dx, dz)
	local d1, d2 = cross(cx, cz, dx, dz, ax, az), cross(cx, cz, dx, dz, bx, bz)
	local d3, d4 = cross(ax, az, bx, bz, cx, cz), cross(ax, az, bx, bz, dx, dz)
	if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and
			((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)) then
		return true
	end
	return false -- touching cases are covered by the distance terms (zero)
end

-- The squared distance between segment a-b and the rectangle (continuous).
local function segment_rect_d2(ax, az, bx, bz, x0, z0, x1, z1)
	if (ax >= x0 and ax <= x1 and az >= z0 and az <= z1) or
			(bx >= x0 and bx <= x1 and bz >= z0 and bz <= z1) then
		return 0
	end
	local corners = {x0, z0, x1, z0, x1, z1, x0, z1}
	for k = 1, 8, 2 do
		local n = k + 2 > 8 and 1 or k + 2
		if segments_meet(ax, az, bx, bz, corners[k], corners[k + 1], corners[n],
				corners[n + 1]) then
			return 0
		end
	end
	local best = min(point_rect_d2(ax, az, x0, z0, x1, z1),
		point_rect_d2(bx, bz, x0, z0, x1, z1))
	for k = 1, 8, 2 do
		best = min(best, point_segment_d2(corners[k], corners[k + 1], ax, az, bx, bz))
	end
	return best
end

local HALF_DIAGONAL = sqrt(0.5)

-- Whether a node column of the inclusive rectangle lies within `reach` of
-- segment a-b: the road corridor's x/z rule (world_protection.lua kind_at
-- without its vertical band). Exact: every point of the rectangle is within
-- sqrt(0.5) of one of its columns, so only a near miss scans columns.
local function segment_hits_columns(ax, az, bx, bz, reach, x0, z0, x1, z1)
	local d2 = segment_rect_d2(ax, az, bx, bz, x0, z0, x1, z1)
	local r2 = reach * reach
	if d2 > r2 then return false end
	local d = sqrt(d2)
	if d + HALF_DIAGONAL <= reach then return true end
	local xa = max(x0, floor(min(ax, bx) - reach))
	local xb = min(x1, floor(max(ax, bx) + reach) + 1)
	local za = max(z0, floor(min(az, bz) - reach))
	local zb = min(z1, floor(max(az, bz) + reach) + 1)
	for z = za, zb do
		for x = xa, xb do
			if point_segment_d2(x, z, ax, az, bx, bz) <= r2 then return true end
		end
	end
	return false
end
M.segment_hits_columns = segment_hits_columns

--
-- The build
--

-- A chunk's (or a cell's) number key; |cx|, |cz| and |i|, |j| stay far
-- below KEY_HALF inside the mapgen limit.
local KEY_HALF, KEY_SPAN = 8192, 16384
local function key_of(cx, cz)
	return (cz + KEY_HALF) * KEY_SPAN + cx + KEY_HALF
end

-- The chunks of a set {key -> true}, row order (cz, then cx).
local function chunk_rows(set)
	local list = {}
	for key in pairs(set) do
		list[#list + 1] = {key % KEY_SPAN - KEY_HALF, floor(key / KEY_SPAN) - KEY_HALF}
	end
	table.sort(list, function(a, b)
		if a[2] ~= b[2] then return a[2] < b[2] end
		return a[1] < b[1]
	end)
	return list
end

function M.build(world, scans)
	if type(world) ~= "table" or type(world.bounds) ~= "table" or
			type(world.zones) ~= "table" or type(world.water_at) ~= "function" or
			type(world.zone_at) ~= "function" or type(world.territory_at) ~= "function" or
			type(world.feature_in) ~= "function" or type(world.roads) ~= "table" or
			type(world.cities) ~= "table" or type(world.spawn) ~= "table" then
		fail("world seam differs")
	end
	scans = scans or {}
	local B = world.bounds
	local BX0, BX1, BZ0, BZ1 = B.min_x, B.max_x, B.min_z, B.max_z
	local water_at, zone_at, territory_at = world.water_at, world.zone_at,
		world.territory_at
	local FACTIONS = M.FACTIONS
	local mask = {new_scans = 0, stats = {}}

	-- The three column answers (a column outside the world plan is sea).
	local function answers(x, z)
		if x < BX0 or x > BX1 or z < BZ0 or z > BZ1 then return "deep_ocean", nil, nil end
		local water, zone = water_at(x, z), zone_at(x, z)
		return water, zone, zone and territory_at(x, z) or nil
	end
	local column_problem = M.column_problem
	-- Rule 5's column, after rule 2 passed: the chunk holds no hard footprint
	-- column (feature_in is exact over the chunk widened by MARGIN), and dry
	-- land is never protected water, so the territory of a "land" column at
	-- the world top is its zone's own rule (zones.lua territory_rule_at); the
	-- territory is asked only for a water column, about a quarter less work.
	local function scan_problem(faction, x, z)
		if x < BX0 or x > BX1 or z < BZ0 or z > BZ1 then return "sea" end
		local water, zone = water_at(x, z), zone_at(x, z)
		local territory
		if zone then
			if water == "land" then
				territory = zone.territory_rule
			else
				territory = territory_at(x, z)
			end
		end
		return column_problem(faction, water, zone, territory)
	end

	-- reasons[faction][key] for every chunk that is no claim ground of the
	-- faction within the world's chunk range; ground[faction][key] = true
	local reasons, ground = {}, {}
	for _, f in ipairs(FACTIONS) do reasons[f], ground[f] = {}, {} end
	local CX0, CX1 = M.chunk_of(BX0), M.chunk_of(BX1)
	local CZ0, CZ1 = M.chunk_of(BZ0), M.chunk_of(BZ1)
	mask.range = {min_cx = CX0, max_cx = CX1, min_cz = CZ0, max_cz = CZ1}

	-- Rule 1 over every chunk. A column is on the ground of at most one
	-- faction (the zones are each one faction's), so once both have a
	-- problem the chunk is done.
	local candidates = {} -- {cx, cz, faction}, row order
	local LAT = M.LATTICE
	local lattice = {{40, 40}}
	for _, b in ipairs(LAT) do
		for _, a in ipairs(LAT) do
			if a ~= 40 or b ~= 40 then lattice[#lattice + 1] = {a, b} end
		end
	end
	local sampled = 0
	for cz = CZ0, CZ1 do
		for cx = CX0, CX1 do
			local x0, z0 = M.chunk_bounds(cx, cz)
			local key = key_of(cx, cz)
			local open = {}
			local left = #FACTIONS
			for _, f in ipairs(FACTIONS) do open[f] = true end
			for n = 1, #lattice do
				local water, zone, territory = answers(x0 + lattice[n][1], z0 + lattice[n][2])
				sampled = sampled + 1
				for _, f in ipairs(FACTIONS) do
					if open[f] then
						local problem = column_problem(f, water, zone, territory)
						if problem then
							reasons[f][key] = problem
							open[f] = false
							left = left - 1
						end
					end
				end
				if left == 0 then break end
			end
			for _, f in ipairs(FACTIONS) do
				if open[f] then candidates[#candidates + 1] = {cx, cz, f} end
			end
		end
	end
	mask.stats.sampled_columns = sampled
	mask.stats.candidates = #candidates

	-- Rule 3: the chunks a road corridor holds a column of (x/z).
	local road_chunks = {}
	for _, road in ipairs(world.roads) do
		local X, Z, reach = road.X, road.Z, road.reach
		for i = 1, #X - 1 do
			local ax, az, bx, bz = X[i], Z[i], X[i + 1], Z[i + 1]
			for cz = M.chunk_of(floor(min(az, bz) - reach)), M.chunk_of(floor(max(az, bz) + reach) + 1) do
				for cx = M.chunk_of(floor(min(ax, bx) - reach)), M.chunk_of(floor(max(ax, bx) + reach) + 1) do
					local key = key_of(cx, cz)
					if not road_chunks[key] then
						local x0, z0, x1, z1 = M.chunk_bounds(cx, cz)
						if segment_hits_columns(ax, az, bx, bz, reach, x0, z0, x1, z1) then
							road_chunks[key] = true
						end
					end
				end
			end
		end
	end

	-- Rule 4: camp cells, and the points with their SPOT square.
	local spawn = world.spawn
	local spot_chunks = {}
	-- the first rule in the order camp, leader, place, rare names a chunk
	local SPOT_ORDER = {camp = 1, leader = 2, place = 3, rare = 4}
	local function mark(key, why)
		local now = spot_chunks[key]
		if not SPOT_ORDER[why] then fail("unknown spawn point kind " .. tostring(why)) end
		if not now or SPOT_ORDER[why] < SPOT_ORDER[now] then spot_chunks[key] = why end
	end
	local function mark_rect(x0, z0, x1, z1, why)
		for cz = M.chunk_of(z0), M.chunk_of(z1) do
			for cx = M.chunk_of(x0), M.chunk_of(x1) do mark(key_of(cx, cz), why) end
		end
	end
	local CELL = M.CELL
	for k = 1, #spawn.camp_cells, 2 do
		local i, j = spawn.camp_cells[k], spawn.camp_cells[k + 1]
		mark_rect(CELL * i, CELL * j, CELL * i + CELL - 1, CELL * j + CELL - 1, "camp")
	end
	local SPOT = M.SPOT
	for _, p in ipairs(spawn.points) do
		mark_rect(p.x - SPOT, p.z - SPOT, p.x + SPOT, p.z + SPOT, p.kind)
	end

	-- Rule 6: the chunks that hold a column of a protected city.
	local wall_chunks = {}
	for _, city in ipairs(world.cities) do
		local ax, az = city.anchor.x, city.anchor.z
		for lz, row in pairs(city.rows) do
			local cz = M.chunk_of(az + lz)
			for i = 1, #row, 2 do
				-- an interval the shape rounds inward past itself ([7, 6])
				-- holds no column and marks no chunk
				if row[i] <= row[i + 1] then
					for cx = M.chunk_of(ax + row[i]), M.chunk_of(ax + row[i + 1]) do
						wall_chunks[key_of(cx, cz)] = true
					end
				end
			end
		end
	end
	local function near_wall(cx, cz)
		for dz = -M.RING, M.RING do
			for dx = -M.RING, M.RING do
				if wall_chunks[key_of(cx + dx, cz + dz)] then return true end
			end
		end
		return false
	end

	-- Rule 5's column order: the edge ring, then the inner rows.
	local order_x, order_z = {}, {}
	do
		local function add(a, b)
			order_x[#order_x + 1], order_z[#order_z + 1] = a, b
		end
		for d = 0, CHUNK - 1 do add(d, 0) add(d, CHUNK - 1) end
		for d = 1, CHUNK - 2 do add(0, d) add(CHUNK - 1, d) end
		for b = 1, CHUNK - 2 do
			for a = 1, CHUNK - 2 do add(a, b) end
		end
	end
	local function full_scan(faction, cx, cz)
		local x0, z0 = M.chunk_bounds(cx, cz)
		local cap = false
		for n = 1, #order_x do
			local problem, capital = scan_problem(faction, x0 + order_x[n], z0 + order_z[n])
			if problem then return problem, false end
			if capital then cap = true end
		end
		return "ok", cap
	end

	local scanned = 0
	for _, c in ipairs(candidates) do
		local cx, cz, f = c[1], c[2], c[3]
		local key = key_of(cx, cz)
		local x0, z0, x1, z1 = M.chunk_bounds(cx, cz)
		local reason
		local kind = world.feature_in(x0, z0, x1, z1, M.MARGIN)
		if kind then
			reason = kind
		elseif road_chunks[key] then
			reason = "road"
		elseif spot_chunks[key] then
			reason = spot_chunks[key]
		else
			local skey = M.scan_key(cx, cz, f)
			local known = scans[skey]
			if not known then
				local code, cap = full_scan(f, cx, cz)
				known = {code = code, cap = cap}
				scans[skey] = known
				mask.new_scans = mask.new_scans + 1
			end
			scanned = scanned + 1
			if known.code ~= "ok" then
				reason = known.code
			elseif known.cap and near_wall(cx, cz) then
				reason = "capital_ring"
			end
		end
		if reason then
			reasons[f][key] = reason
		else
			ground[f][key] = true
		end
	end
	mask.stats.scanned = scanned

	local lists = {}
	for _, f in ipairs(FACTIONS) do
		lists[f] = chunk_rows(ground[f])
		mask.stats[f] = #lists[f]
	end

	function mask.ground(faction, cx, cz)
		if not ground[faction] then return false, "no_faction" end
		local key = key_of(cx, cz)
		if ground[faction][key] then return true end
		return false, reasons[faction][key] or "sea"
	end
	function mask.list(faction)
		return lists[faction] or {}
	end
	function mask.ground_in(faction, min_x, min_z, max_x, max_z)
		local out = {}
		local set = ground[faction]
		if not set then return out end
		for cz = M.chunk_of(min_z), M.chunk_of(max_z) do
			for cx = M.chunk_of(min_x), M.chunk_of(max_x) do
				if set[key_of(cx, cz)] then out[#out + 1] = {cx, cz} end
			end
		end
		return out
	end

	-- The quota's kinds: sorted by id, cells indexed by cell.
	local kinds, kind_by_id, cell_kind = {}, {}, {}
	for _, k in ipairs(spawn.kinds) do kinds[#kinds + 1] = k end
	table.sort(kinds, function(a, b) return a.id < b.id end)
	for index, k in ipairs(kinds) do
		local n = #k.cells / 2
		local entry = {index = index, id = k.id, zone = k.zone, cells = n,
			ground = n * M.GROUND_PER_CELL, limit = n * M.GROUND_PER_CELL / 2}
		kinds[index] = entry
		kind_by_id[k.id] = entry
		-- A cell on a zone border may be a land cell of both zones (a tie
		-- goes to the zone that builds, spawn_regions_core.lua step 1): it
		-- counts for each kind that holds it.
		for c = 1, #k.cells, 2 do
			local ckey = key_of(k.cells[c], k.cells[c + 1])
			local list = cell_kind[ckey]
			if not list then
				list = {}
				cell_kind[ckey] = list
			end
			list[#list + 1] = entry
		end
	end
	mask.kinds, mask.kind_by_id = kinds, kind_by_id

	function mask.kind_columns(cx, cz)
		local x0, z0, x1, z1 = M.chunk_bounds(cx, cz)
		local by = {}
		for j = floor(z0 / CELL), floor(z1 / CELL) do
			local h = min(z1, CELL * j + CELL - 1) - max(z0, CELL * j) + 1
			for i = floor(x0 / CELL), floor(x1 / CELL) do
				local list = cell_kind[key_of(i, j)]
				if list then
					local w = min(x1, CELL * i + CELL - 1) - max(x0, CELL * i) + 1
					for _, entry in ipairs(list) do
						by[entry.index] = (by[entry.index] or 0) + w * h
					end
				end
			end
		end
		local out = {}
		for index = 1, #kinds do
			if by[index] then out[#out + 1] = {kinds[index].id, by[index]} end
		end
		return out
	end

	function mask.quota_refusal(cx, cz, taken)
		for _, row in ipairs(mask.kind_columns(cx, cz)) do
			if (taken[row[1]] or 0) + row[2] > kind_by_id[row[1]].limit then return row[1] end
		end
		return nil
	end

	-- Adds (sign 1) or takes back (sign -1) a placed claim's chunk to the
	-- taken columns {kind id -> columns}.
	function mask.add_taken(taken, cx, cz, sign)
		for _, row in ipairs(mask.kind_columns(cx, cz)) do
			local v = (taken[row[1]] or 0) + (sign or 1) * row[2]
			taken[row[1]] = v ~= 0 and v or nil
		end
		return taken
	end

	mask.wall_chunks = chunk_rows(wall_chunks)
	return mask
end

--
-- Fingerprints (the stored data at a reset; docs/technical/claim-mask-format.md)
--

local function round2(v)
	return ("%.2f"):format(v)
end

-- Per claim-ground chunk of each faction, the digests of what decides its
-- generation, each over the chunk and STRIP nodes beyond its edges:
--   height  the planner's terrain height on the STEP lattice
--   water   the water class on the lattice
--   zone    the owning zone's id on the lattice
--   roads   every road segment that comes within its reach of the area:
--           its road id and centreline points (x, z, surface y)
--   places  the settlement core or hard footprint feature_in names within
--           MARGIN of the area, and every camp cell, leader, quest place and
--           rare route point whose rule-4 square meets the area
-- Rows {faction, cx, cz, height, water, zone, roads, places} in faction then
-- row order; `sha256(bytes)` gives lowercase hex, cut to DIGEST_HEX.
function M.fingerprints(mask, world, sha256)
	if type(world.height_at) ~= "function" then fail("height seam differs") end
	local S, STEP, H = M.STRIP, M.STEP, M.DIGEST_HEX
	local CELL, SPOT = M.CELL, M.SPOT
	local function digest(parts)
		return sha256(table.concat(parts, "\n")):sub(1, H)
	end
	-- the chunks to fingerprint, and per chunk the road segments, camp cells
	-- and points near enough to matter (in input order)
	local wanted = {}
	for _, f in ipairs(M.FACTIONS) do
		for _, c in ipairs(mask.list(f)) do wanted[key_of(c[1], c[2])] = {} end
	end
	local function bucket(x0, z0, x1, z1, item)
		for cz = M.chunk_of(z0 - S), M.chunk_of(z1 + S) do
			for cx = M.chunk_of(x0 - S), M.chunk_of(x1 + S) do
				local list = wanted[key_of(cx, cz)]
				if list then list[#list + 1] = item end
			end
		end
	end
	for _, road in ipairs(world.roads) do
		local X, Z, reach = road.X, road.Z, road.reach
		for i = 1, #X - 1 do
			bucket(floor(min(X[i], X[i + 1]) - reach), floor(min(Z[i], Z[i + 1]) - reach),
				floor(max(X[i], X[i + 1]) + reach) + 1, floor(max(Z[i], Z[i + 1]) + reach) + 1,
				{road = road, i = i})
		end
	end
	local spawn = world.spawn
	for k = 1, #spawn.camp_cells, 2 do
		local i, j = spawn.camp_cells[k], spawn.camp_cells[k + 1]
		bucket(CELL * i, CELL * j, CELL * i + CELL - 1, CELL * j + CELL - 1,
			{text = "camp " .. i .. " " .. j, x0 = CELL * i, z0 = CELL * j,
				x1 = CELL * i + CELL - 1, z1 = CELL * j + CELL - 1})
	end
	for _, p in ipairs(spawn.points) do
		bucket(p.x - SPOT, p.z - SPOT, p.x + SPOT, p.z + SPOT,
			{text = p.kind .. " " .. p.x .. " " .. p.z, x0 = p.x - SPOT, z0 = p.z - SPOT,
				x1 = p.x + SPOT, z1 = p.z + SPOT})
	end
	local rows = {}
	for _, f in ipairs(M.FACTIONS) do
		for _, c in ipairs(mask.list(f)) do
			local cx, cz = c[1], c[2]
			local x0, z0, x1, z1 = M.chunk_bounds(cx, cz)
			local ax0, az0, ax1, az1 = x0 - S, z0 - S, x1 + S, z1 + S
			local hs, ws, zs = {}, {}, {}
			for z = az0, az1, STEP do
				for x = ax0, ax1, STEP do
					hs[#hs + 1] = tostring(world.height_at(x, z))
					ws[#ws + 1] = tostring(world.water_at(x, z))
					local zone = world.zone_at(x, z)
					zs[#zs + 1] = zone and zone.id or "-"
				end
			end
			local rs, ps = {}, {}
			local kind, id = world.feature_in(ax0, az0, ax1, az1, M.MARGIN)
			for _, item in ipairs(wanted[key_of(cx, cz)]) do
				local road = item.road
				if road then
					local X, Z, R, i = road.X, road.Z, road.R, item.i
					if segment_rect_d2(X[i], Z[i], X[i + 1], Z[i + 1], ax0, az0, ax1, az1) <=
							road.reach * road.reach then
						rs[#rs + 1] = road.id .. " " .. round2(X[i]) .. " " .. round2(Z[i]) .. " " ..
							round2(R[i]) .. " " .. round2(X[i + 1]) .. " " .. round2(Z[i + 1]) ..
							" " .. round2(R[i + 1])
					end
				elseif item.x1 >= ax0 and item.x0 <= ax1 and item.z1 >= az0 and item.z0 <= az1 then
					ps[#ps + 1] = item.text
				end
			end
			table.sort(ps)
			table.insert(ps, 1, "feature " .. tostring(kind or "-") .. " " .. tostring(id or "-"))
			rows[#rows + 1] = {f, cx, cz, digest(hs), digest(ws), digest(zs), digest(rs),
				digest(ps)}
		end
	end
	return rows
end

return M
