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
	{0, -3700, "ring south"}, {3741, 0, "old edge + 1"}, {0, -3341, "old edge - 1"},
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

-- The whole ring, coarsely: deep ocean everywhere, never the -23 floor.
local ring = 0
for z = W.min_z, W.max_z, 64 do
	for x = W.min_x, W.max_x, 64 do
		if x < -3740 or x > 3740 or z < -3340 or z > 3340 then
			ring = ring + 1
			if S.water_class_at(x, z) ~= "deep_ocean" or S.id_at(x, z) ~= nil or
					S.terrain_height_at(x, z) == -23 then
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
print(("R51 TERRAIN PASS checks=%d"):format(checks))
