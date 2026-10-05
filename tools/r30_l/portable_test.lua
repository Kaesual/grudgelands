-- Round 30 Lane L portable test (LuaJIT): the dragon-island landings, a
-- wooden pier and a sand beach at each of the four boat landings
-- (`source.island_landings`, boats.md §7).
--
--   luajit tools/r30_l/portable_test.lua [REPO] [SEED ...]
--
-- Per SEED (default 42 7 2026 1234 314159) the real zones.lua / height.lua
-- session with the inland water layout (no roads: the islands have none) is
-- built, and for every landing:
--   1. the shore point exists: a land column whose next column toward the
--      mainland is sea;
--   2. the beach: at least BEACH_MIN columns within 12 nodes along the shore
--      and 11 inland are dry land at y 1..3, none of them above y 3, and the
--      coast material there is sand;
--   3. the pier: `road_writer.lua` dresses the landing with a stub context
--      over the planner's real column tuple, once as one box and once split
--      into two boxes across the pier (the same nodes either way); the deck
--      is 2 wide at y 2 over every water column 1..10 out, in the zone's
--      planks; every post row (10, 7, 4, 1 out) stands on the floor (no
--      water left under a post), its side posts carry a fence at y 3; the
--      deck's land end reaches the beach's water line; no pier column lies
--      in the dragon channel;
--   4. walking: from the pier head, stepping at most one node up or down
--      between 4-neighbours over the deck and dry land (no swimming), the
--      back of the beach (ground y 3) is reached.
-- For the report it prints per landing the beach size, the water depth at
-- the pier head and the highest ground reached by walking within 40 nodes.
-- Prints "R30 L PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local seeds = {}
for i = 2, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"42", "7", "2026", "1234", "314159"} end
local BEACH_MIN = 150
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local function build(seed)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	-- the shared world assembly, the capitals' protected cities stood in by
	-- squares (as r25 world.lua), no roads
	local A = dofile(dir .. "/world_assembly.lua")(dir, common.new_sha256())
	local W = A.world(seed, nil, {roads = false, protection = A.square_cities(120)})
	local held = {}
	local height_factory = W.height_factory
	W.height_factory = function(deps)
		local module = height_factory(deps)
		local new_runtime = module.new_runtime
		module.new_runtime = function(s)
			local session = new_runtime(s)
			held.height = session
			return session
		end
		module.new = module.new_runtime
		return module
	end
	local session, planner_source = W.zones().new_with_planner_source_runtime(seed, 1)
	return session, planner_source, held.height, A.source
end

-- road_writer.lua under a stub engine: content ids are the node names.
local stub = {registered_nodes = setmetatable({}, {__index = function() return {} end}),
	get_content_id = function(name) return name end,
	get_name_from_content_id = function(c) return c end, CONTENT_AIR = "air"}
local WOOD = {dwarf = {"default:pine_wood", "default:pine_tree", "default:fence_pine_wood"},
	troll = {"default:junglewood", "default:jungletree", "default:fence_junglewood"}}

local function dress(writer, planner_source, boxes)
	local nodes = {}
	for _, box in ipairs(boxes) do
		writer.dress({min_x = box[1], max_x = box[2], min_z = box[3], max_z = box[4],
			min_y = -48, max_y = 48,
			column_values_at = planner_source.column_values_at,
			road_column_at = function() return nil end,
			settled_at = function() return "air" end,
			write_road = function(x, y, z, c)
				local key = x .. "," .. y .. "," .. z
				assert(nodes[key] == nil, "pier node written twice at " .. key)
				nodes[key] = c
			end})
	end
	return nodes
end

for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	local S, PS, H, source = build(seed)
	local writer = dofile(dir .. "/road_writer.lua")(stub, source)
	local function sea(x, z)
		local wc, _, _, _, _, _, _, river = PS.column_values_at(x, z)
		return wc ~= "land" and river == nil
	end
	local function ground(x, z) return (select(6, PS.column_values_at(x, z))) end
	for _, landing in ipairs(source.island_landings) do
		local label = landing.id .. ", seed " .. seed
		local race = source.zones[landing.zone_numeric_id].race_region
		local wood = WOOD[race]
		check(wood ~= nil, "island race has a wood: " .. label)
		-- 1. shore point
		local sx, sz, ux, uz = H.island_landing_site(landing.id)
		check(sx ~= nil, "shore point found: " .. label)
		check(not sea(sx, sz) and sea(sx + ux, sz + uz), "shore point on the water line: " .. label)
		local vx, vz = -uz, ux
		local function at(a, b) return sx + a * ux + b * vx, sz + a * uz + b * vz end

		-- 2. beach
		local beach, high = 0, 0
		for b = -12, 12 do
			for a = -11, 0 do
				local x, z = at(a, b)
				if not sea(x, z) and S.water_class_at(x, z) == "land" then
					local y = ground(x, z)
					if y >= 1 and y <= 3 then
						beach = beach + 1
						check(PS.coast_material_at(x, z) == "sand",
							("beach column %d,%d is sand: %s"):format(x, z, label))
					end
				end
			end
		end
		-- the middle: on every line across |b| <= 6 the first 8 land columns
		-- from the water (the coast may run at a slant)
		for b = -6, 6 do
			local first
			for a = 12, -20, -1 do
				local x, z = at(a, b)
				if not first and not sea(x, z) then first = a end
			end
			for a = first, first - 7, -1 do
				local x, z = at(a, b)
				if ground(x, z) > 3 then high = high + 1 end
			end
		end
		check(beach >= BEACH_MIN, ("beach has %d >= %d columns: %s"):format(beach, BEACH_MIN, label))
		check(high == 0, ("no ground above y 3 in the beach's middle (%d): %s"):format(high, label))

		-- 3. pier, as one box and split across the pier
		local x0, z0 = at(-4, -4)
		local x1, z1 = at(14, 6)
		local bx0, bx1 = math.min(x0, x1), math.max(x0, x1)
		local bz0, bz1 = math.min(z0, z1), math.max(z0, z1)
		local mx, mz = at(5, 0)
		local one = dress(writer, PS, {{bx0, bx1, bz0, bz1}})
		local split
		if ux ~= 0 then
			split = dress(writer, PS, {{bx0, mx, bz0, bz1}, {mx + 1, bx1, bz0, bz1}})
		else
			split = dress(writer, PS, {{bx0, bx1, bz0, mz}, {bx0, bx1, mz + 1, bz1}})
		end
		local n_one, n_split = 0, 0
		for key, c in pairs(one) do
			n_one = n_one + 1
			check(split[key] == c, "split boxes write the same pier node " .. key .. ": " .. label)
		end
		for _ in pairs(split) do n_split = n_split + 1 end
		check(n_one == n_split and n_one > 0, "pier written, same in split boxes: " .. label)
		local function node(x, y, z) return one[x .. "," .. y .. "," .. z] end
		for a = 1, 10 do
			for b = -1, 2 do
				local x, z = at(a, b)
				if sea(x, z) and b >= 0 and b <= 1 then
					check(node(x, 2, z) == wood[1], ("deck at %d out, %d across: %s"):format(a, b, label))
				end
				-- the dragon channel stays untouched (world_zones.md §7.4)
				check(S.water_class_at(x, z) ~= "immutable_dragon_channel",
					("pier column %d,%d outside the dragon channel: %s"):format(x, z, label))
			end
		end
		for _, a in ipairs({10, 7, 4, 1}) do
			for b = -1, 2 do
				local x, z = at(a, b)
				if sea(x, z) then
					local top = (b == -1 or b == 2) and 2 or 1
					for y = ground(x, z) + 1, top do
						check(node(x, y, z) == wood[2], ("post down to the floor at %d,%d,%d: %s")
							:format(x, y, z, label))
					end
					if top == 2 then
						check(node(x, 3, z) == wood[3], ("fence on the side post at %d out: %s"):format(a, label))
					end
				end
			end
		end
		-- the deck's land end on the water line
		local rx, rz = at(0, 0)
		check(node(rx, 2, rz) == wood[1] or ground(rx, rz) >= 2, "deck reaches the beach: " .. label)

		-- 4. walking from the pier head (stand height: deck 3, dry land ground + 1)
		local function stand(x, z)
			if node(x, 2, z) == wood[1] then return 3 end
			if sea(x, z) or S.water_class_at(x, z) ~= "land" then return nil end
			return ground(x, z) + 1
		end
		local hx, hz = at(10, 0)
		local start = hx .. "," .. hz
		local seen, queue, head = {[start] = true}, {{hx, hz}}, 1
		local reached_top, max_stand = false, 3
		while head <= #queue do
			local x, z = queue[head][1], queue[head][2]
			head = head + 1
			local h = stand(x, z)
			if h == 4 and math.abs((x - sx) * vx + (z - sz) * vz) <= 12 then reached_top = true end
			if h > max_stand then max_stand = h end
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local nx, nz = x + d[1], z + d[2]
				local key = nx .. "," .. nz
				if not seen[key] and math.abs(nx - sx) <= 40 and math.abs(nz - sz) <= 40 then
					local nh = stand(nx, nz)
					if nh and math.abs(nh - h) <= 1 then
						seen[key] = true
						queue[#queue + 1] = {nx, nz}
					end
				end
			end
		end
		check(reached_top, "walk from the pier head to the back of the beach: " .. label)
		print(("  %s: shore %d,%d, beach %d columns, pier head water %d deep, walk reaches %d columns up to y %d")
			:format(label, sx, sz, beach, 1 - ground(hx, hz), #queue, max_stand - 1))
	end
	print(("  seed %s done (%.1f s)"):format(seed, os.clock() - t0))
end
print(("R30 L PORTABLE PASS checks=%d"):format(checks))
