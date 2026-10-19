-- Round 51 TERRAIN T1 portable fixture (LuaJIT): the larger world (sea plan
-- ruling 2, round plan §2 T1).
--
--   luajit tools/r51_terrain/portable_test.lua REPO [SEED]
--
-- A. The bounds agree in every place that encodes one: the world's query
--    bounds (`source/simple_map.lua` world_bounds) are the target, the
--    protection index (`world_protection.lua` M.BOUNDS) has the same, the
--    terrain field's grids cover them with a margin and keep the 32-node
--    lattice of before (no grid point moves), the full world preparation
--    (`grug_core/preparation_plan.lua`) covers them, and no file that read
--    the old +-3740 x +-3340 still holds it as a literal (the planners read
--    the shared bounds; the seed fleet's corner is the bounds' corner). The
--    land's extent (`source.extent`) and the inland-water grid stay as they
--    were: they cover the land, which did not move.
-- B. On the real runtime of one seed (default 12345): a column just inside
--    the new bounds, in the new ring (between the old and the new bounds,
--    (+-4100, 0) and (0, +-3700) among them) and just outside reads as open
--    sea in every zones query: deep ocean, no zone, biome, faction, level or
--    PvP rule, immutable territory at the surface and deep below, no hard
--    footprint, no road or settlement protection; the terrain inside the
--    bounds is the field's sea floor, outside it the flat floor y -23. A
--    coarse scan of the whole ring finds deep ocean only, and chunks in the
--    ring and across the new edge plan and write.
-- C. T2, the sea's shape: the water query's shape and one column of each
--    class; no open sea at the rim of a bay; the belt carries its zone and
--    ends 250-350 off the coast; the channels are their island's, at most 11
--    deep and 9+ from 48 off the coast, and a boat passes each boat path;
--    bay, belt and channel water is protected from 24 nodes off the coast
--    (at the surface, the seabed and deep below), the shore and inland water
--    are not; Stormkelp's shore ground stays open.
-- The comparison that no land moved is tools/r51_terrain/compare.lua (too
-- slow for a fixture: one runtime and about 250,000 columns per seed and
-- checkout).
-- Prints "R51 TERRAIN PASS checks=<n>" or raises.
local repo, seed = arg[1], arg[2] or "12345"
assert(repo, "usage: portable_test.lua REPO [SEED]")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(got, want, label)
	check(got == want, label .. " (got " .. tostring(got) .. ", want " ..
		tostring(want) .. ")")
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"), path)
	local bytes = file:read("*a")
	file:close()
	return bytes
end

-- ---------------------------------------------------------------------------
-- A. The bounds agree
-- ---------------------------------------------------------------------------
local source = dofile(wp40 .. "/source/simple_map.lua")
local W = source.world_bounds
-- The target (round plan §2 T1: 450 nodes more in x and 400 in z than
-- +-3740 x +-3340).
check(W.min_x == -4190 and W.max_x == 4190 and W.min_z == -3740 and W.max_z == 3740,
	"A the world bounds are +-4190 x +-3740")
local E = source.extent
check(E.min_x == -3600 and E.max_x == 3600 and E.min_z == -3200 and E.max_z == 3200,
	"A the land's extent stays +-3600 x +-3200")
local check_rect = source.zone_field.check
check(check_rect.min_x == E.min_x and check_rect.max_x == E.max_x and
	check_rect.min_z == E.min_z and check_rect.max_z == E.max_z,
	"A the zone field's construction check covers the land's extent")

local wp = dofile(wp40 .. "/world_protection.lua")
for _, key in ipairs({"min_x", "max_x", "min_z", "max_z"}) do
	eq(wp.BOUNDS[key], W[key], "A world protection " .. key)
end

local terrain = dofile(wp40 .. "/terrain_data.lua")
local V = terrain.params
local cell, coast = V.blend_cell, V.coast_cell
eq(cell % coast, 0, "A the coast cell divides the character cell")
-- Two cells beyond the bounds: the cubic B-spline's support of the last
-- column inside them.
check(V.grid_min_x <= W.min_x - 2 * cell and V.grid_max_x >= W.max_x + 2 * cell and
	V.grid_min_z <= W.min_z - 2 * cell and V.grid_max_z >= W.max_z + 2 * cell,
	"A the terrain grids cover the bounds and the spline's support")
check(V.grid_min_x == -V.grid_max_x and V.grid_min_z == -V.grid_max_z,
	"A the terrain grids are symmetric")
-- The lattice of before (+-3808 x +-3424): grown by whole cells only.
eq((V.grid_min_x - -3808) % cell, 0, "A the x lattice keeps its points")
eq((V.grid_min_z - -3424) % cell, 0, "A the z lattice keeps its points")
eq(V.grid_min_x, -4288, "A the x grid grew by 15 cells")
eq(V.grid_min_z, -3840, "A the z grid grew by 13 cells")
-- The inland-water drainage grid covers the land, which did not move.
local water = terrain.water
check(water.GX0 <= E.min_x and water.GX1 >= E.max_x and water.GZ0 <= E.min_z and
	water.GZ1 >= E.max_z, "A the drainage grid covers the land's extent")

local plan = dofile(repo .. "/mods/CORE/grug_core/preparation_plan.lua")
local P = plan.bounds
check(P.x_min <= W.min_x and P.x_max >= W.max_x and P.z_min <= W.min_z and
	P.z_max >= W.max_z, "A the full preparation covers the world bounds")
check(P.x_min == -4370 and P.x_max == 4370 and P.z_min == -3920 and P.z_max == 3920,
	"A the full preparation is the map's +-4050 x +-3600 plus 320")

-- No old literal is left where a bound was hard-coded; the planners read
-- the shared bounds.
local FILES = {
	"mods/MAPGEN/grug_mapgen/wp40/zones.lua",
	"mods/MAPGEN/grug_mapgen/wp40/height.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/world_protection.lua",
	"mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua",
	"mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua",
	"mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua",
	"mods/MAPGEN/grug_mapgen/wp40/terrain_data.lua",
	"mods/CORE/grug_core/preparation_plan.lua",
	"tools/seed_fleet/seed.lua",
}
-- (The old x bound 3740 is the new z bound, so it counts only in an x role.)
local OLD_LITERALS = {"3340", "3808", "3424", "x = -3740", "x >= -3740", "-3740, 3740"}
for _, path in ipairs(FILES) do
	local bytes = read(path):gsub("%-%-[^\n]*", "")
	for _, literal in ipairs(OLD_LITERALS) do
		check(not bytes:find(literal, 1, true),
			"A no old bound literal " .. literal .. " in " .. path)
	end
end
for _, path in ipairs({"zones.lua", "height.lua", "simple_map.lua", "r6_planner.lua",
		"r6_settlement.lua", "r7_p9g.lua"}) do
	check(read("mods/MAPGEN/grug_mapgen/wp40/" .. path):find("world_bounds", 1, true),
		"A " .. path .. " reads the shared world bounds")
end
check(read("tools/seed_fleet/seed.lua"):find("world_bounds", 1, true),
	"A the seed fleet's corner is the world bounds' corner")

-- ---------------------------------------------------------------------------
-- B. The new ring on the real runtime
-- ---------------------------------------------------------------------------
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local index = wp.new(dofile(wp40 .. "/index128.lua"), {
	corridors = wp.road_corridors(R.main.road_module(), R.main.road_layout_text())})

local function open_sea(x, z, inside, label)
	label = label .. (" (%d, %d)"):format(x, z)
	eq(S.water_class_at(x, z), "deep_ocean", "B water class " .. label)
	eq(S.id_at(x, z), nil, "B no zone " .. label)
	eq(S.biome_at(x, z), nil, "B no biome " .. label)
	eq(S.race_region_at(x, z), nil, "B no race region " .. label)
	eq(S.surface_mob_level_at(x, z), nil, "B no surface level " .. label)
	local h = S.terrain_height_at(x, z)
	if inside then
		check(h <= -2 and h >= -40, "B the sea floor of the field " .. label ..
			" (got " .. tostring(h) .. ")")
	else
		eq(h, -23, "B the flat floor outside " .. label)
	end
	for _, y in ipairs({h + 1, 1, -600}) do
		local p = {x = x, y = y, z = z}
		local at = label .. " y " .. y
		eq(S.territory_rule_at(p), "immutable", "B immutable " .. at)
		eq(S.pvp_rule_at(p), nil, "B no PvP rule " .. at)
		eq(S.mob_level_at(p), nil, "B no mob level " .. at)
		eq(S.guard_level_at(p), nil, "B no guard level " .. at)
		eq(S.faction_at(p), nil, "B no faction " .. at)
		eq(S.hard_protection_kind_at(p), nil, "B no hard protection " .. at)
		eq(S.at(p), nil, "B no zone record " .. at)
		eq(index.kind_at(x, y, z), nil, "B no road or settlement protection " .. at)
	end
	eq(S.hard_footprint_in(x - 16, z - 16, x + 16, z + 16), nil,
		"B no hard footprint near " .. label)
end

for _, c in ipairs({
	{4100, 0, "ring east"}, {-4100, 0, "ring west"}, {0, 3700, "ring north"},
	{0, -3700, "ring south"},
	{W.max_x, 0, "inside the new east bound"}, {W.min_x, 0, "inside the new west bound"},
	{0, W.max_z, "inside the new north bound"}, {0, W.min_z, "inside the new south bound"},
	{W.max_x, W.max_z, "inside the new corner"}, {W.min_x, W.min_z, "inside the new corner"},
}) do
	open_sea(c[1], c[2], true, c[3])
end
for _, c in ipairs({
	{W.max_x + 1, 0, "outside east"}, {W.min_x - 1, 0, "outside west"},
	{0, W.max_z + 1, "outside north"}, {0, W.min_z - 1, "outside south"},
	{W.max_x + 1, W.max_z + 1, "outside the corner"},
}) do
	open_sea(c[1], c[2], false, c[3])
end

-- The whole ring, coarsely: water everywhere; open sea
-- wherever the coast is farther than the belt reaches (T2: the belt, at most
-- 350 nodes off the coast, may reach into the ring).
local ring = 0
for z = W.min_z, W.max_z, 64 do
	for x = W.min_x, W.max_x, 64 do
		if x < -3740 or x > 3740 or z < -3340 or z > 3340 then
			ring = ring + 1
			local class, _, _, distance = S.water_query_at(x, z)
			if class == nil or
					(distance > 350 and (class ~= "open_sea" or S.id_at(x, z) ~= nil)) then
				check(false, ("B the ring is open sea at (%d, %d)"):format(x, z))
			end
		end
	end
end
check(ring > 2000, "B the ring scan covered the ring")

-- Chunks in the ring, across the new edges and at the new corner plan and
-- write (no grid or array is read past its end).
local chunks = 0
for _, c in ipairs({{4100, 0}, {0, -3700}, {W.max_x, 0}, {W.min_x, 0}, {0, W.max_z},
		{W.max_x, W.min_z}, {W.min_x, W.max_z}}) do
	local minp = {x = R.origin(c[1]), y = R.origin(1), z = R.origin(c[2])}
	local ok, result = pcall(R.chunk, minp)
	check(ok, ("B the chunk at %d, %d, %d writes: %s"):format(minp.x, minp.y, minp.z,
		tostring(result)))
	chunks = chunks + 1
end

print(("  seed %s: %d ring columns scanned, %d chunks written"):format(seed, ring, chunks))

-- ---------------------------------------------------------------------------
-- C. T2: the sea's shape (sea plan rulings 4-6, 8)
-- ---------------------------------------------------------------------------
local Q = S.water_query_at
check(type(Q) == "function", "C the zones session has the water query")
local PROTECTED = source.water.protected_distance
eq(PROTECTED, 24, "C protected water starts 24 nodes off the coast")
local zone_by_id = {}
for _, zone in ipairs(source.zones) do zone_by_id[zone.id] = zone end

-- C1. One column of each class (scanned every 16 nodes), the query's shape.
local found, dry = {}, nil
local wanted = {lake = true, river = true, bay = true, belt = true, channel = true,
	open_sea = true}
for z = W.min_z, W.max_z, 16 do
	for x = W.min_x, W.max_x, 16 do
		local class = Q(x, z)
		if class == nil then
			dry = dry or {x, z}
		elseif wanted[class] and not found[class] then
			found[class] = {x, z}
		end
	end
end
for class in pairs(wanted) do check(found[class] ~= nil, "C1 a column of class " .. class) end
check(dry ~= nil and select("#", Q(dry[1], dry[2])) == 1, "C1 dry land answers nil alone")
for class, c in pairs(found) do
	local got, zone, level, distance, depth, protected = Q(c[1], c[2])
	local at = (" (%s at %d, %d)"):format(class, c[1], c[2])
	eq(got, class, "C1 class" .. at)
	if class == "lake" or class == "river" then
		-- the inland distance only on request (its ring search is not cheap)
		eq(distance, nil, "C1 no inland distance unasked" .. at)
		distance = select(4, Q(c[1], c[2], true))
	end
	check(type(distance) == "number" and distance >= 0, "C1 distance" .. at)
	check(type(depth) == "number" and depth >= 1, "C1 depth" .. at)
	check(type(protected) == "boolean", "C1 protected flag" .. at)
	if class == "open_sea" then
		check(zone == nil and level == nil and protected == true, "C1 open sea: no zone" .. at)
	else
		check(zone_by_id[zone] ~= nil and type(level) == "number", "C1 zone and level" .. at)
		eq(zone, S.id_at(c[1], c[2]), "C1 the zone is the column's" .. at)
	end
	if class == "lake" or class == "river" then
		eq(protected, false, "C1 inland water is never protected" .. at)
		check(S.territory_rule_at({x = c[1], y = 0, z = c[2]}) ~= "immutable",
			"C1 inland water stays alterable" .. at)
	end
end

-- A swamp pool (the planner's pools, not the height's inland water) reads as
-- a lake: a swamp column whose horizontal class is land and whose query is
-- "lake", 1-2 deep.
local swamp
for z = W.min_z, W.max_z, 64 do
	for x = W.min_x, W.max_x, 64 do
		if not swamp and S.biome_at(x, z) == "grug_swamp" and Q(x, z) == nil then swamp = {x, z} end
	end
end
check(swamp ~= nil, "C1 a swamp column")
local pool
for z = swamp[2] - 200, swamp[2] + 200, 2 do
	for x = swamp[1] - 200, swamp[1] + 200, 2 do
		if not pool and S.water_class_at(x, z) == "land" and Q(x, z) == "lake" then pool = {x, z} end
	end
end
check(pool ~= nil, "C1 a swamp pool reads as a lake")
if pool then
	local _, _, _, distance, depth, protected = Q(pool[1], pool[2], true)
	check(depth >= 1 and depth <= 2 and distance >= 1 and protected == false,
		("C1 the pool at %d, %d: depth %d, distance %.1f"):format(pool[1], pool[2], depth, distance))
end

-- C2. Bay rims (ruling 4): no open sea within 32 nodes of a bay's water and
-- within 128 nodes of land (the rim); the mouth opens on the open sea farther
-- out.
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}
local function near(x, z, wanted_class, reach, step)
	for d = step, reach, step do
		for _, o in ipairs(DIRS) do
			if S.water_class_at(x + o[1] * d, z + o[2] * d) == wanted_class then return true end
		end
	end
	return false
end
local rim_columns = 0
for _, bay in ipairs(source.bays) do
	local cx = bay.centreline[1].x
	local sign = bay.deep_ocean_side == "min_z" and -1 or 1
	for zz = 1800, 3300, 8 do
		for x = cx - 1100, cx + 1100, 8 do
			local z = sign * zz
			if S.water_class_at(x, z) == "deep_ocean" then
				rim_columns = rim_columns + 1
				check(not (near(x, z, "planned_water", 32, 8) and near(x, z, "land", 128, 16)),
					("C2 no open sea at the rim of %s (%d, %d)"):format(bay.id, x, z))
			end
		end
	end
end

-- C3. The belt (ruling 5): its zone's id, level, faction and PvP rule; the
-- open sea begins 250-350 nodes off the coast.
local belt_columns, edge_columns = 0, 0
for z = W.min_z, W.max_z, 16 do
	for x = W.min_x, W.max_x, 16 do
		local class, zone, level, distance = Q(x, z)
		if class == "belt" then
			belt_columns = belt_columns + 1
			check(distance < 350, ("C3 the belt lies within 350 of the coast (%d, %d: %.0f)")
				:format(x, z, distance))
			if belt_columns % 97 == 1 then
				local p = {x = x, y = 1, z = z}
				local record = zone_by_id[zone]
				eq(S.mob_level_at(p), level, "C3 the belt's mob level is its zone's")
				eq(S.pvp_rule_at(p), record.pvp_rule, "C3 the belt's PvP rule is its zone's")
				eq(S.faction_at(p) or false, record.faction or false,
					"C3 the belt's faction is its zone's")
			end
		elseif class == "open_sea" then
			for _, o in ipairs({{16, 0}, {-16, 0}, {0, 16}, {0, -16}}) do
				if Q(x + o[1], z + o[2]) == "belt" then
					edge_columns = edge_columns + 1
					check(distance >= 250 - 16 and distance <= 350 + 16,
						("C3 the open sea begins 250-350 off the coast (%d, %d: %.0f)")
						:format(x, z, distance))
					break
				end
			end
		end
	end
end
check(belt_columns > 1000 and edge_columns > 100, "C3 the belt scan found the belt and its edge")

-- C4. The channels (ruling 6): the island's zone and level; no deeper than
-- 11; 9 or more deep from 48 nodes off the coast; a boat passes each boat
-- path over water 9 or more deep (a 2-node lattice search between the path's
-- first and last column 48+ off the coast).
for _, channel in ipairs(source.channels) do
	local island = source.zones[channel.zone_numeric_id]
	local b = {min_x = math.huge, max_x = -math.huge, min_z = math.huge, max_z = -math.huge}
	for _, p in ipairs(channel.polygon) do
		b.min_x, b.max_x = math.min(b.min_x, p.x), math.max(b.max_x, p.x)
		b.min_z, b.max_z = math.min(b.min_z, p.z), math.max(b.max_z, p.z)
	end
	local n = 0
	for z = b.min_z - 120, b.max_z + 120, 4 do
		for x = b.min_x - 120, b.max_x + 120, 4 do
			local class, zone, level, distance, depth = Q(x, z)
			if class == "channel" then
				n = n + 1
				local at = (" (%s at %d, %d: depth %d, %.0f off)"):format(channel.id, x, z,
					depth, distance)
				eq(zone, island.id, "C4 the channel is its island's" .. at)
				eq(level, island.level_max, "C4 the channel has its island's level" .. at)
				check(depth <= 11, "C4 a channel is at most 11 deep" .. at)
				if distance >= 48 then check(depth >= 9, "C4 9+ deep 48 off the coast" .. at) end
			end
		end
	end
	check(n > 1000, "C4 the channel " .. channel.id .. " was found")
end
for _, path in ipairs(source.boat_paths) do
	local a, b = path.centreline[1], path.centreline[#path.centreline]
	local steps = math.floor(math.abs(b.x - a.x) + math.abs(b.z - a.z))
	local first, last
	for i = 0, steps do
		local x = math.floor((a.x + (b.x - a.x) * i / steps) / 2 + 0.5) * 2
		local z = math.floor((a.z + (b.z - a.z) * i / steps) / 2 + 0.5) * 2
		local class, _, _, distance = Q(x, z)
		if class and distance and distance >= 48 then first = first or {x, z} last = {x, z} end
	end
	check(first ~= nil, "C4 the boat path " .. path.id .. " crosses open water")
	local min_x, max_x = math.min(a.x, b.x) - 160, math.max(a.x, b.x) + 160
	local min_z, max_z = math.min(a.z, b.z) - 200, math.max(a.z, b.z) + 200
	local seen, queue, head, reached = {[first[1] .. "," .. first[2]] = true}, {first}, 1, false
	while head <= #queue do
		local p = queue[head]
		head = head + 1
		if p[1] == last[1] and p[2] == last[2] then reached = true break end
		for _, o in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}}) do
			local x, z = p[1] + o[1], p[2] + o[2]
			local key = x .. "," .. z
			if x >= min_x and x <= max_x and z >= min_z and z <= max_z and not seen[key] then
				seen[key] = true
				local class, _, _, _, depth = Q(x, z)
				if class and depth >= 9 then queue[#queue + 1] = {x, z} end
			end
		end
	end
	check(reached, "C4 a boat passes " .. path.id .. " over water 9+ deep")
end

-- C5. Protected water (ruling 8) at 23, 24 and 25 nodes off the coast for
-- bay, belt and channel water: the surface, the seabed and deep below.
-- (Searched every 2 nodes round the first bay and the first channel, whose
-- island's shore also holds belt water, until each probe is found.)
local probes, missing = {}, 9
local windows = {}
do
	local bay = source.bays[1]
	local sign = bay.deep_ocean_side == "min_z" and -1 or 1
	local cx = bay.centreline[1].x
	windows[1] = {cx - 1100, math.min(sign * 1900, sign * 3000),
		cx + 1100, math.max(sign * 1900, sign * 3000)}
	local b = {math.huge, math.huge, -math.huge, -math.huge}
	for _, p in ipairs(source.channels[1].polygon) do
		b[1], b[2] = math.min(b[1], p.x - 200), math.min(b[2], p.z - 200)
		b[3], b[4] = math.max(b[3], p.x + 200), math.max(b[4], p.z + 200)
	end
	windows[2] = b
end
for _, w in ipairs(windows) do
	for z = w[2], w[4], 2 do
		if missing == 0 then break end
		for x = w[1], w[3], 2 do
			local class, _, _, distance = Q(x, z)
			if class == "bay" or class == "belt" or class == "channel" then
				local band = math.floor(distance)
				if band >= 23 and band <= 25 then
					local key = class .. band
					if not probes[key] then
						probes[key] = {class, band, x, z}
						missing = missing - 1
					end
				end
			end
		end
	end
end
for _, class in ipairs({"bay", "belt", "channel"}) do
	for band = 23, 25 do
		local probe = probes[class .. band]
		check(probe ~= nil, ("C5 a %s column %d nodes off the coast"):format(class, band))
		local x, z = probe[3], probe[4]
		local _, zone, _, _, _, protected = Q(x, z)
		local floor_y = S.terrain_height_at(x, z)
		eq(protected, band >= 24, ("C5 %s %d off: protected flag"):format(class, band))
		local record = zone_by_id[zone]
		local faction = record.territory_rule == "throng_home" and "throng" or "accord"
		for _, y in ipairs({1, floor_y, floor_y - 1, -600}) do
			local p = {x = x, y = y, z = z}
			local at = (" (%s %d off at %d, %d, y %d)"):format(class, band, x, z, y)
			if band >= 24 then
				eq(S.territory_rule_at(p), "immutable", "C5 immutable" .. at)
				eq(S.compatibility.world_protected_for_faction(p, "accord"), true,
					"C5 protected for The Accord" .. at)
				eq(S.compatibility.world_protected_for_faction(p, "throng"), true,
					"C5 protected for The Throng" .. at)
			else
				check(S.territory_rule_at(p) ~= "immutable", "C5 the shore stays alterable" .. at)
				if y > -501 then
					eq(S.compatibility.world_protected_for_faction(p, faction), false,
						"C5 the shore is open to its zone's faction" .. at)
				end
			end
		end
	end
end

-- C6. Stormkelp (sea plan §6.2) is a dry shore plant: its hosts are land
-- surfaces beside water, never water columns, so protected water does not
-- touch it; a shore column of one of its zones beside protected water stays
-- open to both factions.
local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
local stormkelp
for _, row in ipairs(catalog.p9g_sources()) do
	if row.key == "stormkelp" then stormkelp = row end
end
check(stormkelp ~= nil and stormkelp.shore_predicate == "dry_cardinal",
	"C6 Stormkelp grows on dry shore ground")
local shore
for z = -800, 800, 4 do
	for x = -2800, -1600, 4 do
		if not shore and Q(x, z) == nil and S.id_at(x, z) == "front_gravesalt_escarpment" then
			for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local near_class = Q(x + 4 * o[1], z + 4 * o[2])
				local _, _, _, _, _, protected = Q(x + 40 * o[1], z + 40 * o[2])
				if near_class and protected then shore = {x, z} end
			end
		end
	end
end
check(shore ~= nil, "C6 a Gravesalt shore column beside protected water")
if shore then
	local p = {x = shore[1], y = S.terrain_height_at(shore[1], shore[2]) + 1, z = shore[2]}
	eq(S.territory_rule_at(p), "contested_land", "C6 the shore is contested ground")
	eq(S.compatibility.world_protected_for_faction(p, "accord"), false,
		"C6 The Accord may harvest on the shore")
	eq(S.compatibility.world_protected_for_faction(p, "throng"), false,
		"C6 The Throng may harvest on the shore")
end
print(("  T2: %d belt and %d belt-edge columns, %d open-sea columns near bays checked")
	:format(belt_columns, edge_columns, rim_columns))
print(("R51 TERRAIN PASS checks=%d"):format(checks))
