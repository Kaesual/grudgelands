-- Round 51 follow-up FW portable fixture (LuaJIT): the water plants (the
-- user's GUI feedback items 1, 2 and 8; followup plan §2 "FW").
--
--   luajit tools/r51_fw/portable_test.lua REPO [SEED]
--
-- A. The soft edges (wp40/seabed.lua, pure): seagrass and kelp fill falls
--    toward the edge of their meadows and single tufts stand beyond it,
--    measured by distance from the outline T3 cut at (the noise threshold
--    of before); nothing grows far outside; the three seagrass variants
--    stay mixed in cores and edges; a coral patch keeps its ellipse and
--    gains a sparse rim and loose pieces, across its cell's side too.
-- B. The wild lakes' rule (pure): lilies only 1-3 deep, weed only 3-10 deep
--    and under the surface, one plant per column, both in clusters with
--    soft edges.
-- C. Generator and regrowth agree (the real runtime of SEED, default
--    12345, the real writer on a fake VoxelManip): in a belt chunk every
--    seagrass and kelp bed the writer grew is the plant, variant and height
--    the vegetation authority names (the renewal's rule), and it names none
--    on a bare sand bed; the same in a lake chunk for the waterlily and the
--    waterweed; the capital's lake (Lethariel, lane FT's) stays bare.
-- D. Lake regrowth (grug_farming/renewal.lua, real file, the runtime's own
--    authority): a missing lily comes back on the surface, a missing weed
--    on its sand bed at its height; an occupied surface, a bed without
--    water and a refused permission do not.
-- E. The animation (followup plan §3 B): the three seagrass variants, the
--    freshwater waterweed and default kelp (grug_nodes' override) have one
--    special tile animated as vertical frames 16 x 16 over 3.2 s, waving 0,
--    an inventory image of the first frame; the strips are the picked art
--    (byte-identical to tools/r51_sea/anim), 16 x 128.
-- Prints "R51 FW PASS checks=<n>" or raises.
local repo = assert(arg[1], "usage: portable_test.lua REPO [SEED]")
local seed = arg[2] or "12345"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local file = assert(io.open(path, "rb"), "missing " .. path)
	local data = file:read("*a")
	file:close()
	return data
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local floor = math.floor

-- ---------------------------------------------------------------------------
-- A. Soft edges
-- ---------------------------------------------------------------------------
local rule = dofile(wp40 .. "/seabed.lua")("fw-fixture")
local SIZE, DEPTH = 384, 6
local grid, variants = {}, {}
local function index(x, z) return z * SIZE + x + 1 end
for z = 0, SIZE - 1 do
	for x = 0, SIZE - 1 do
		local kind, variant = rule.at(x, z, DEPTH)
		grid[index(x, z)] = kind or false
		variants[index(x, z)] = variant
	end
end
-- the fill by signed distance (8-neighbour steps) from the old outline
local function profile(kind, period, salt, threshold)
	local inside, dist, queue = {}, {}, {}
	for z = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			inside[index(x, z)] = rule.reef_noise(x, z, period, salt) > threshold
		end
	end
	for z = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			local i = index(x, z)
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local xx, zz = x + d[1], z + d[2]
				if not dist[i] and xx >= 0 and zz >= 0 and xx < SIZE and zz < SIZE and
						inside[index(xx, zz)] ~= inside[i] then
					dist[i] = 1
					queue[#queue + 1] = {x, z}
				end
			end
		end
	end
	local head = 1
	while head <= #queue do
		local x, z = queue[head][1], queue[head][2]
		head = head + 1
		local d0 = dist[index(x, z)]
		if d0 < 12 then
			for dz = -1, 1 do
				for dx = -1, 1 do
					local xx, zz = x + dx, z + dz
					if xx >= 0 and zz >= 0 and xx < SIZE and zz < SIZE then
						local j = index(xx, zz)
						if not dist[j] and inside[j] == inside[index(x, z)] then
							dist[j] = d0 + 1
							queue[#queue + 1] = {xx, zz}
						end
					end
				end
			end
		end
	end
	local grown, columns = {}, {}
	for i = 1, SIZE * SIZE do
		local d = dist[i]
		if d then
			local signed = inside[i] and d or -d
			columns[signed] = (columns[signed] or 0) + 1
			if grid[i] == kind then grown[signed] = (grown[signed] or 0) + 1 end
		end
	end
	return function(d) return (grown[d] or 0) / math.max(1, columns[d] or 0) end
end
local sg = profile("seagrass", 20, 151, 480)
check(sg(6) > 0.5, "A seagrass cores stay full (two in three less kelp and coral)")
check(sg(6) > sg(2) and sg(2) > sg(1) and sg(1) > sg(-1) and sg(-1) > sg(-3),
	"A seagrass fill falls toward the edge and beyond")
check(sg(-1) > 0.1 and sg(-3) > 0.01 and sg(-5) > 0, "A seagrass tufts beyond the old outline")
local kp = profile("kelp", 24, 131, 600)
check(kp(6) > 0.12 and kp(6) > kp(1) and kp(1) > kp(-2) and kp(-2) > 0,
	"A kelp fill falls toward the edge, single stalks beyond")
-- nothing below the tuft band of the noise (far outside a meadow)
local stray = 0
for z = 0, SIZE - 1 do
	for x = 0, SIZE - 1 do
		local kind = grid[index(x, z)]
		if kind == "seagrass" and rule.reef_noise(x, z, 20, 151) < rule.SEAGRASS_FADE.tuft or
				kind == "kelp" and rule.reef_noise(x, z, 24, 131) < rule.KELP_FADE.tuft then
			stray = stray + 1
		end
	end
end
check(stray == 0, "A no seagrass or kelp far outside its meadow")
-- the variants stay mixed in a meadow's core and at its edge
local core_variants, edge_variants = {}, {}
for z = 1, SIZE - 2 do
	for x = 1, SIZE - 2 do
		local i = index(x, z)
		if grid[i] == "seagrass" then
			local n = 0
			for dz = -1, 1 do
				for dx = -1, 1 do
					if (dx ~= 0 or dz ~= 0) and grid[index(x + dx, z + dz)] == "seagrass" then n = n + 1 end
				end
			end
			local into = n >= 4 and core_variants or edge_variants
			into[variants[i]] = (into[variants[i]] or 0) + 1
		end
	end
end
for v = 1, 3 do
	check((core_variants[v] or 0) > 0 and (edge_variants[v] or 0) > 0,
		"A seagrass variant " .. v .. " in cores and at edges")
end
-- coral: ellipse, rim and loose pieces of each patch cell, also beyond its
-- cell's side
local rings, reached_across = {{0, 0}, {0, 0}, {0, 0}}, 0
for cz = 0, 23 do
	for cx = 0, 23 do
		local h = rule.reef_hash
		if h(cx, cz, 101) % 4 == 0 then
			local px = cx * 16 + 3 + h(cx, cz, 103) % 10
			local pz = cz * 16 + 3 + h(cx, cz, 107) % 10
			local swapped = h(cx, cz, 109) % 2 == 1
			local size = h(cx, cz, 111) % 2 == 0 and 15 or 26
			for z = pz - 10, pz + 10 do
				for x = px - 10, px + 10 do
					local dx, dz = x - px, z - pz
					local long, short = swapped and dz or dx, swapped and dx or dz
					local q = long * long + 2 * short * short
					local ring = q <= size and 1 or (q <= 2 * size and 2 or (q <= 3 * size and 3 or nil))
					if ring then
						local coral = rule.at(x, z, DEPTH) == "patch"
						rings[ring][1] = rings[ring][1] + 1
						if coral then
							rings[ring][2] = rings[ring][2] + 1
							if floor(x / 16) ~= cx or floor(z / 16) ~= cz then
								reached_across = reached_across + 1
							end
						end
					end
				end
			end
		end
	end
end
local function share(r) return rings[r][2] / math.max(1, rings[r][1]) end
check(share(1) > 0.7, "A a coral patch's ellipse stays four in five")
check(share(2) > 0.15 and share(2) < 0.45, "A a sparse coral rim")
check(share(3) > 0.02 and share(3) < 0.15, "A loose coral pieces round the rim")
check(reached_across > 0, "A a patch reaches across its cell's side")
check(rule.at(5, 5, 1) == nil and rule.at(5, 5, 21) == nil, "A the depths stay 2-20")

-- ---------------------------------------------------------------------------
-- B. The wild lakes' rule
-- ---------------------------------------------------------------------------
local lily_seen, weed_seen = 0, 0
for depth = 0, 14 do
	for z = 0, 199 do
		for x = 0, 199 do
			local kind, value = rule.lake_at(x, z, depth)
			if kind == "lily" then
				lily_seen = lily_seen + 1
				check(depth >= 1 and depth <= 3 and value >= 0 and value <= 3,
					"B lilies 1-3 deep, rotation 0-3")
			elseif kind == "weed" then
				weed_seen = weed_seen + 1
				check(depth >= 3 and depth <= 10 and value >= 1 and value <= 4 and value <= depth - 1,
					"B weed 3-10 deep, 1-4 tall, under the surface")
			else
				check(kind == nil, "B only lilies and weed")
			end
		end
	end
end
check(lily_seen > 0 and weed_seen > 0, "B both grow")
-- clusters with soft edges: the lilies' fill by their own noise
local lily_core, lily_edge, lily_columns_core, lily_columns_edge = 0, 0, 0, 0
for z = 0, 399 do
	for x = 0, 399 do
		local n = rule.reef_noise(x, z, 10, 241)
		local lily = rule.lake_at(x, z, 2) == "lily"
		if n >= rule.LILY_FADE.core then
			lily_columns_core = lily_columns_core + 1
			if lily then lily_core = lily_core + 1 end
		elseif n >= rule.LILY_FADE.edge then
			lily_columns_edge = lily_columns_edge + 1
			if lily then lily_edge = lily_edge + 1 end
		end
	end
end
check(lily_core / lily_columns_core > lily_edge / lily_columns_edge and lily_edge > 0,
	"B lily clusters thin out at their edges")

-- ---------------------------------------------------------------------------
-- C. Generator and regrowth agree
-- ---------------------------------------------------------------------------
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local fake = R.fake
local native = dofile(wp40 .. "/r7_native.lua")
local authority = R.main.build_authority(native.identities())
local vegetation = authority.vegetation
local seed_rule = dofile(wp40 .. "/seabed.lua")(R.built.full_seed)
local function write_chunk(ox, oy, oz)
	local minp = {x = ox, y = oy, z = oz}
	local maxp = {x = ox + 79, y = oy + 79, z = oz + 79}
	local vm = R.new_vm(minp)
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data or vm.native.data
	local param2 = vm.written.param2 or vm.native.param2
	return function(x, y, z)
		local i = (z - oz + 16) * 12544 + (y - oy + 16) * 112 + (x - ox + 16) + 1
		return fake.get_name_from_content_id(data[i]), param2[i]
	end
end
-- the belt off the Dawnmere coast (seed 12345; another seed: the first belt
-- chunk found shallow)
local bx, bz = 256, -2928
if seed ~= "12345" then
	for z = -3600, 3600, 80 do
		for x = -4000, 4000, 80 do
			local class, _, _, _, depth = S.water_query_at(x, z)
			if bx == 256 and class == "belt" and depth >= 4 and depth <= 8 then bx, bz = x, z end
		end
	end
end
do
	local ox, oz = R.origin(bx), R.origin(bz)
	local at = write_chunk(ox, -32, oz)
	local grown, agreed, bare_sand = 0, 0, 0
	for z = oz, oz + 79 do
		for x = ox, ox + 79 do
			local class, _, _, _, depth = S.water_query_at(x, z)
			if class == "belt" or class == "bay" or class == "channel" then
				local y = 1 - depth
				if y >= -32 then
					local name, p2 = at(x, y, z)
					local want, want_p2, want_y = vegetation.seabed(x, z)
					local plant = name == "default:sand_with_kelp" or name:find("^grug_mapgen:seagrass_")
					-- kelp inside a coral patch stays as generated (T3, a backlog note)
					if plant and seed_rule.at(x, z, depth) == "patch" then plant = false end
					if plant then
						grown = grown + 1
						check(want == name and want_p2 == p2 and want_y == y,
							("C the authority names the writer's %s at %d,%d"):format(name, x, z))
						agreed = agreed + 1
					elseif name == "default:sand" and seed_rule.at(x, z, depth) ~= "patch" then
						bare_sand = bare_sand + 1
						-- (a wreck over the bed blocks the plant: the renewal
						-- needs the water column too)
						local open = true
						for wy = y + 1, y + (want_p2 and want_p2 > 0 and want_p2 / 16 or 1) do
							if at(x, wy, z) ~= "default:water_source" then open = false end
						end
						check(want == nil or not open,
							("C nothing regrows on bare sand at %d,%d"):format(x, z))
					end
				end
			end
		end
	end
	check(grown > 100 and bare_sand > 100, "C the belt chunk grows and keeps bare sand")
	print(("  C belt chunk %d,%d: %d plants agree, %d bare sand beds"):format(ox, oz, agreed, bare_sand))
end
-- a mesa lake (seed 12345: the chunk with the most lake water) and the
-- Lethariel crown lake
local function lake_chunk(ox, oy, oz, label, expect_plants)
	local at = write_chunk(ox, oy, oz)
	local lilies, weeds, columns = 0, 0, 0
	for z = oz, oz + 79 do
		for x = ox, ox + 79 do
			local class, _, _, _, depth = S.water_query_at(x, z)
			local bed = class == "lake" and S.terrain_height_at(x, z)
			if bed and bed >= oy and bed + depth + 1 <= oy + 79 and S.biome_at(x, z) ~= "grug_swamp" then
				columns = columns + 1
				local surface = bed + depth
				local bed_name, bed_p2 = at(x, bed, z)
				local top = at(x, surface + 1, z)
				local want, want_p2, want_y, _, on_surface = vegetation.seabed(x, z)
				if top == "grug_mapgen:freshwater_waterlily" then
					lilies = lilies + 1
					check(want == top and on_surface and want_y == surface + 1,
						("C %s: the authority names the lily at %d,%d"):format(label, x, z))
				elseif bed_name == "grug_mapgen:freshwater_waterweed" then
					weeds = weeds + 1
					check(want == bed_name and want_p2 == bed_p2 and want_y == bed,
						("C %s: the authority names the weed at %d,%d"):format(label, x, z))
				elseif bed_name == "default:sand" then
					check(want == nil or (want == "grug_mapgen:freshwater_waterlily" and top ~= "air"),
						("C %s: nothing regrows on a bare lake column at %d,%d"):format(label, x, z))
				end
			end
		end
	end
	if expect_plants then
		check(lilies > 10 and weeds > 10, "C " .. label .. ": lilies and weed grow")
	else
		check(columns > 0 and lilies == 0 and weeds == 0, "C " .. label .. " stays bare")
	end
	print(("  C %s: %d lake columns, %d lilies, %d weed"):format(label, columns, lilies, weeds))
end
if seed == "12345" then
	lake_chunk(-192, 48, 928, "mesa lake", true)
	-- Lethariel's crown lake: the capital's own exclusion keeps it to lane FT
	local lx, lz = 1824, -1392
	local ly = S.terrain_height_at(lx, lz) + select(5, S.water_query_at(lx, lz))
	lake_chunk(R.origin(lx), R.origin(ly), R.origin(lz), "Lethariel crown lake", false)
end

-- ---------------------------------------------------------------------------
-- D. Lake regrowth through the real renewal
-- ---------------------------------------------------------------------------
do
	local lily, weed
	for z = 928, 1007 do
		for x = -192, -113 do
			local node, p2, y, water_y, on_surface = vegetation.seabed(x, z)
			if node == "grug_mapgen:freshwater_waterlily" and not lily then
				lily = {x = x, z = z, y = y, water_y = water_y, p2 = p2, surface = on_surface}
			elseif node == "grug_mapgen:freshwater_waterweed" and not weed then
				weed = {x = x, z = z, y = y, water_y = water_y, p2 = p2}
			end
		end
	end
	check(lily and weed and lily.surface, "D the authority knows a lily and a weed column")
	local map, placed = {}, nil
	local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
	local allowed = true
	local api = {
		get_node_or_nil = function(pos) return map[key(pos)] end,
		set_node = function(pos, n) placed = {pos = pos, node = n}; map[key(pos)] = n end,
		get_natural_light = function() return 15 end,
		find_nodes_in_area = function() return {} end,
		find_nodes_in_area_under_air = function() return {} end,
		get_item_group = function() return 0 end,
		density = vegetation, planner = authority.planner_source,
		natural_ground_alterable = function() return allowed end,
		water_plant_alterable = function() return allowed end,
		random = function() return 0.99 end, trees = false, non_natural = {},
	}
	local renewal = dofile(repo .. "/mods/ITEMS/grug_farming/renewal.lua")(api)
	local function lake_column(c)
		map, placed = {}, nil
		map[key({x = c.x, y = S.terrain_height_at(c.x, c.z), z = c.z})] = {name = "default:sand"}
		for y = S.terrain_height_at(c.x, c.z) + 1, c.water_y do
			map[key({x = c.x, y = y, z = c.z})] = {name = "default:water_source"}
		end
		map[key({x = c.x, y = c.water_y + 1, z = c.z})] = {name = "air"}
	end
	local function far(c) return {{x = c.x + 500, y = c.water_y, z = c.z}} end
	lake_column(lily)
	check(renewal.evaluate_seabed(lily.x, lily.z, far(lily), {left = 1000}, 0) == "placed" and
		placed.node.name == "grug_mapgen:freshwater_waterlily" and placed.pos.y == lily.water_y + 1 and
		placed.node.param2 == lily.p2, "D a lily regrows on the surface, turned as generated")
	lake_column(lily)
	map[key({x = lily.x, y = lily.water_y + 1, z = lily.z})] = {name = "grug_mapgen:freshwater_waterlily"}
	check(renewal.evaluate_seabed(lily.x, lily.z, far(lily), {left = 1000}, 0) == "occupied",
		"D a lily already there stays")
	lake_column(lily)
	map[key({x = lily.x, y = lily.water_y, z = lily.z})] = {name = "air"}
	check(renewal.evaluate_seabed(lily.x, lily.z, far(lily), {left = 1000}, 0) == "no_water",
		"D a lily only over source water")
	lake_column(weed)
	check(renewal.evaluate_seabed(weed.x, weed.z, far(weed), {left = 1000}, 0) == "placed" and
		placed.node.name == "grug_mapgen:freshwater_waterweed" and placed.pos.y == weed.y and
		placed.node.param2 == weed.p2, "D a weed regrows on its sand bed at its height")
	lake_column(weed)
	map[key({x = weed.x, y = weed.y + 1, z = weed.z})] = {name = "air"}
	check(renewal.evaluate_seabed(weed.x, weed.z, far(weed), {left = 1000}, 0) == "no_water",
		"D a weed only under water")
	lake_column(weed)
	allowed = false
	check(renewal.evaluate_seabed(weed.x, weed.z, far(weed), {left = 1000}, 0) == "protected",
		"D a refused permission keeps the bed bare")
	allowed = true
	check(renewal.evaluate_seabed(weed.x, weed.z, {{x = weed.x + 5, y = weed.y, z = weed.z}},
		{left = 1000}, 0) == "near_player", "D never next to a player")
end

-- ---------------------------------------------------------------------------
-- E. The animation
-- ---------------------------------------------------------------------------
local function png_size(path)
	local data = read(path)
	check(data:sub(1, 8) == "\137PNG\r\n\26\n", "E " .. path .. " is a PNG")
	local function u32(at)
		local a, b, c, d = data:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end
local STRIPS = {
	{"grug_mapgen:seagrass_1", "mods/MAPGEN/grug_mapgen/textures/grug_mapgen_seagrass_1_anim.png",
		"seagrass_1_anim.png"},
	{"grug_mapgen:seagrass_2", "mods/MAPGEN/grug_mapgen/textures/grug_mapgen_seagrass_2_anim.png",
		"seagrass_2_anim.png"},
	{"grug_mapgen:seagrass_3", "mods/MAPGEN/grug_mapgen/textures/grug_mapgen_seagrass_3_anim.png",
		"seagrass_3_anim.png"},
	{"default:sand_with_kelp", "mods/ITEMS/grug_nodes/textures/grug_nodes_kelp_anim.png",
		"kelp_anim.png"},
	{"grug_mapgen:freshwater_waterweed", "mods/ITEMS/grug_nodes/textures/grug_nodes_kelp_anim.png",
		"kelp_anim.png"},
}
for _, s in ipairs(STRIPS) do
	local def = fake.registered_nodes[s[1]]
	check(def ~= nil and def.drawtype == "plantlike_rooted", "E " .. s[1] .. " registered, rooted")
	check(def.waving == 0, "E " .. s[1] .. " waving 0")
	local tile = def.special_tiles and def.special_tiles[1]
	local image = s[2]:match("[^/]+$")
	check(type(tile) == "table" and tile.name:sub(1, #image) == image and tile.tileable_vertical,
		"E " .. s[1] .. " special tile is its strip")
	local a = tile.animation
	check(type(a) == "table" and a.type == "vertical_frames" and a.aspect_w == 16 and
		a.aspect_h == 16 and a.length == 3.2, "E " .. s[1] .. " vertical frames 16 x 16, 3.2 s")
	check(def.inventory_image == tile.name .. "^[verticalframe:8:0",
		"E " .. s[1] .. " inventory image is the first frame")
	local w, h = png_size(repo .. "/" .. s[2])
	check(w == 16 and h == 128, "E " .. s[2] .. " is 16 x 128 (eight frames)")
	check(read(repo .. "/" .. s[2]) == read(repo .. "/tools/r51_sea/anim/" .. s[3]),
		"E " .. s[2] .. " is the picked strip")
end
print(("R51 FW PASS checks=%d"):format(checks))
