-- Round 85 MASK fixture: the claim mask (grug_housing/claim_mask.lua) on a
-- small constructed plan against brute-force references, its two
-- world-folder files read back (claim_mask_store.lua), the fingerprints, the
-- column rule against the 0.84.1 registry's (frozen in tools/r85_claimcap),
-- and the region map's cell grid
-- (grug_mobs/spawn_regions_cache.lua cell_frame / cell_region).
--
--   luajit tools/r85_mask/portable_test.lua <repo>
local repo = assert(arg[1], "usage: portable_test.lua <repo>")
local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
local floor, max, min = math.floor, math.max, math.min

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end

-- A stand-in sha256: the fixture compares digests with each other only.
local function sha256(bytes)
	local h1, h2 = 5381, 52711
	for k = 1, #bytes do
		local b = bytes:byte(k)
		h1 = (h1 * 33 + b) % 4294967296
		h2 = (h2 * 31 + b * 7) % 4294967296
	end
	return ("%08x%08x%08x%08x"):format(h1, h2, (h1 * 7 + h2) % 4294967296, #bytes % 4294967296)
end

--
-- 1. Chunk arithmetic against the engine's (chunksize 5: floor((floor(x / 16)
--    + 2) / 5)), negative coordinates and the edges included
--
for x = -1000, 1000 do
	local engine = floor((floor(x / 16) + 2) / 5)
	if CM.chunk_of(x) ~= engine then check(false, "chunk_of " .. x) break end
end
check(CM.chunk_of(-32) == 0 and CM.chunk_of(-33) == -1 and CM.chunk_of(47) == 0 and
	CM.chunk_of(48) == 1, "chunk edges")
do
	local x0, z0, x1, z1 = CM.chunk_bounds(-1, -2)
	check(x0 == -112 and x1 == -33 and z0 == -192 and z1 == -113, "chunk bounds negative")
	x0, z0, x1, z1 = CM.chunk_bounds(0, 0)
	check(x0 == -32 and x1 == 47 and z0 == -32 and z1 == 47, "chunk bounds 0")
end

--
-- 2. The road corridor's exact column rule
--
local function brute_segment(ax, az, bx, bz, reach, x0, z0, x1, z1)
	for z = z0, z1 do
		for x = x0, x1 do
			local vx, vz = bx - ax, bz - az
			local l2 = vx * vx + vz * vz
			local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
			if u < 0 then u = 0 elseif u > 1 then u = 1 end
			local dx, dz = x - ax - u * vx, z - az - u * vz
			if dx * dx + dz * dz <= reach * reach then return true end
		end
	end
	return false
end
-- a near miss: 2.5 from the edge x = 47, its columns 2.55 away
check(CM.segment_hits_columns(49.5, 10.5, 60, 10.5, 2.52, -32, -32, 47, 47) == false,
	"road near miss")
check(CM.segment_hits_columns(49.5, 10.5, 60, 10.5, 2.56, -32, -32, 47, 47) == true,
	"road near hit")
do
	local rng = 7
	local function rand()
		rng = (rng * 1103515245 + 12345) % 2147483648
		return rng / 2147483648
	end
	local bad = 0
	for _ = 1, 400 do
		local ax, az = -60 + 160 * rand(), -60 + 160 * rand()
		local bx, bz = ax + 30 * (rand() - 0.5), az + 30 * (rand() - 0.5)
		local reach = 1 + 4 * rand()
		if CM.segment_hits_columns(ax, az, bx, bz, reach, -32, -32, 47, 47) ~=
				brute_segment(ax, az, bx, bz, reach, -32, -32, 47, 47) then
			bad = bad + 1
		end
	end
	check(bad == 0, "road rule against brute force (" .. bad .. " of 400 differ)")
end

--
-- 3. A constructed plan
--
local ZONES = {
	acc_low = {id = "acc_low", faction = "accord", level_min = 1, level_max = 10,
		territory_rule = "accord_home"},
	acc_claim = {id = "acc_claim", faction = "accord", level_min = 11, level_max = 20,
		territory_rule = "accord_home"},
	acc_cap = {id = "acc_cap", faction = "accord", level_min = 20, level_max = 30,
		civic_no_hostiles = true, territory_rule = "accord_home"},
	contested = {id = "contested", level_min = 31, level_max = 40,
		territory_rule = "contested_land"},
	thr_claim = {id = "thr_claim", faction = "throng", level_min = 21, level_max = 30,
		territory_rule = "throng_home"},
}
local ZONE_LIST = {ZONES.acc_low, ZONES.acc_claim, ZONES.acc_cap, ZONES.contested,
	ZONES.thr_claim}
local function zone_of(x, z)
	if z >= 208 then return ZONES.thr_claim end
	if x < -192 then return ZONES.acc_low end
	if x < 128 then return ZONES.acc_claim end
	if x < 288 then return ZONES.acc_cap end
	return ZONES.contested
end
-- the capital's protected city: a square around (208, -100), half 30
local CITY = {id = "cap", anchor = {x = 208, z = -100}, rows = {}}
for lz = -30, 30 do CITY.rows[lz] = {-30, 30} end
-- a row whose only interval the band's rounding left empty ([7, 6]: columns
-- 215 and 214 of chunk 3, row z 10 of chunk row 0): it holds no column, so
-- chunk (3, 0) is no wall chunk and (2, 1) keeps its ground
CITY.rows[110] = {7, 6}
local function city_member(x, z)
	return x >= 178 and x <= 238 and z >= -130 and z <= -70
end
local LANDMARK = {x = 60, z = 20}
local function water_of(x, z)
	if x == 20 and z == -150 then return "coastal_shelf" end -- a one-column enclave
	if x >= -100 and x <= -90 and z >= -100 and z <= -60 then return "planned_water" end
	if x >= -170 and x <= -165 and z >= 150 and z <= 160 then return "planned_water" end
	return "land"
end
local function territory_of(x, z)
	if city_member(x, z) or (x == LANDMARK.x and z == LANDMARK.z) then
		return "hard_protected"
	end
	if x >= -170 and x <= -165 and z >= 150 and z <= 160 then return "immutable" end
	return zone_of(x, z).territory_rule
end
local BOXES = {{kind = "site", id = "village", min_x = -260, max_x = -240, min_z = 300,
	max_z = 320}}
local world = {bounds = {min_x = -400, max_x = 400, min_z = -400, max_z = 400},
	zones = ZONE_LIST}
local asked = {water = 0, zone = 0, territory = 0}
function world.water_at(x, z) asked.water = asked.water + 1 return water_of(x, z) end
function world.zone_at(x, z) asked.zone = asked.zone + 1 return zone_of(x, z) end
function world.territory_at(x, z) asked.territory = asked.territory + 1 return territory_of(x, z) end
function world.height_at(x, z) return floor(x / 3) + floor(z / 5) end
function world.feature_in(x0, z0, x1, z1, margin)
	for _, b in ipairs(BOXES) do
		if b.min_x - margin <= x1 and b.max_x + margin >= x0 and b.min_z - margin <= z1 and
				b.max_z + margin >= z0 then
			return b.kind, b.id
		end
	end
	local a0, c0, a1, c1 = x0 - margin, z0 - margin, x1 + margin, z1 + margin
	if LANDMARK.x >= a0 and LANDMARK.x <= a1 and LANDMARK.z >= c0 and LANDMARK.z <= c1 then
		return "landmark", "functional:1"
	end
	if 178 <= a1 and 238 >= a0 and -130 <= c1 and -70 >= c0 then return "town", "hard:cap" end
	return nil
end
world.roads = {
	-- straight: its columns are z 248..253, so chunk row 3 only
	{id = "road:00001", X = {-400, 0, 400}, Z = {250.3, 250.3, 250.3}, R = {5, 5, 5}, reach = 3},
	-- a near miss of chunk (-1, -1) at its edge x = -33, a hit of (0, -1)
	{id = "road:00002", X = {-30.5, 0}, Z = {-60.5, -60.5}, R = {5, 5}, reach = 2.52},
}
world.cities = {CITY}
local spawn = CM.new_spawn()
-- region maps of two zones: a camp, a quest kind (negative cells), a kind
-- that is no quest kind, a tie cell held by two zones' kinds
local function region(kind_id, quest, camp)
	return {kind = {id = kind_id, quest_target = quest}, camp = camp}
end
local CLAIM_CELLS = {}
for j = -4, -1 do for i = -4, -1 do CLAIM_CELLS[#CLAIM_CELLS + 1] = {i, j, "meadow"} end end
CLAIM_CELLS[#CLAIM_CELLS + 1] = {-3, 3, "camp"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {1, 5, "plain"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {2, 5, "plain"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {3, 5, "meadow"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {4, 0, "meadow"} -- the tie cell
local CAP_CELLS = {{4, 0, "commons"}, {5, 0, "commons"}, {5, 1, "commons"}}
local function each(cells)
	return function(fn)
		for _, c in ipairs(cells) do
			if c[3] == "camp" then
				fn(c[1], c[2], region("bandits", nil, {id = "bandits"}))
			else
				fn(c[1], c[2], region(c[3], c[3] ~= "plain"))
			end
		end
	end
end
-- the leader's square reaches chunk (-1, -4) by one column (x -144 .. -112);
-- the place's square (z -225 .. -193) misses chunk (-1, -2) by one
CM.add_zone_spawn(spawn, "acc_claim", each(CLAIM_CELLS), {{x = -128, z = -300}},
	{{x = -80, z = -209}}, CM.zone_allowed("accord", ZONES.acc_claim))
CM.add_zone_spawn(spawn, "acc_cap", each(CAP_CELLS), {}, {}, CM.zone_allowed("accord",
	ZONES.acc_cap))
CM.add_zone_spawn(spawn, "acc_low", each({{-9, -9, "foxes"}}), {}, {},
	CM.zone_allowed("accord", ZONES.acc_low))
CM.add_rare_route(spawn, {{x = 30, z = 360}, {x = 300, z = 300}, {x = -300, z = 300}})
world.spawn = spawn
check(CM.zone_allowed("accord", ZONES.acc_cap) and CM.zone_allowed("accord", ZONES.acc_claim) and
	not CM.zone_allowed("accord", ZONES.acc_low) and not CM.zone_allowed("throng", ZONES.acc_claim) and
	CM.zone_allowed("throng", ZONES.thr_claim) and not CM.zone_allowed("accord", ZONES.contested),
	"zone_allowed")

local scans = {}
local mask = CM.build(world, scans)

-- The brute-force reference: every rule on every column.
local function ref_problem(f, x, z)
	if x < -400 or x > 400 or z < -400 or z > 400 then return "sea" end
	local zone = zone_of(x, z)
	return CM.column_problem(f, water_of(x, z), zone, territory_of(x, z))
end
local wall = {}
for cz = -6, 6 do
	for cx = -6, 6 do
		local x0, z0, x1, z1 = CM.chunk_bounds(cx, cz)
		for z = z0, z1 do
			for x = x0, x1 do
				if city_member(x, z) then wall[cx .. "," .. cz] = true end
			end
		end
	end
end
local mism, ground_n = 0, {accord = 0, throng = 0}
for cz = mask.range.min_cz, mask.range.max_cz do
	for cx = mask.range.min_cx, mask.range.max_cx do
		local x0, z0, x1, z1 = CM.chunk_bounds(cx, cz)
		for _, f in ipairs(CM.FACTIONS) do
			local ok, cap = true, false
			for z = z0, z1 do
				for x = x0, x1 do
					local p, c = ref_problem(f, x, z)
					if p then ok = false break end
					if c then cap = true end
				end
				if not ok then break end
			end
			if ok and world.feature_in(x0, z0, x1, z1, 16) then ok = false end
			if ok then
				for _, road in ipairs(world.roads) do
					for i = 1, #road.X - 1 do
						if brute_segment(road.X[i], road.Z[i], road.X[i + 1], road.Z[i + 1], road.reach,
								x0, z0, x1, z1) then
							ok = false
						end
					end
				end
			end
			if ok then
				for k = 1, #spawn.camp_cells, 2 do
					local i, j = spawn.camp_cells[k], spawn.camp_cells[k + 1]
					if 32 * i <= x1 and 32 * i + 31 >= x0 and 32 * j <= z1 and 32 * j + 31 >= z0 then
						ok = false
					end
				end
				for _, p in ipairs(spawn.points) do
					if p.x + 16 >= x0 and p.x - 16 <= x1 and p.z + 16 >= z0 and p.z - 16 <= z1 then
						ok = false
					end
				end
			end
			if ok and cap then
				for dz = -1, 1 do
					for dx = -1, 1 do
						if wall[(cx + dx) .. "," .. (cz + dz)] then ok = false end
					end
				end
			end
			local got = mask.ground(f, cx, cz)
			if got ~= ok then
				mism = mism + 1
				print("  differs: " .. f .. " " .. cx .. "," .. cz .. " reference " .. tostring(ok))
			end
			if ok then ground_n[f] = ground_n[f] + 1 end
		end
	end
end
check(mism == 0, "mask against the brute-force reference (" .. mism .. " chunks differ)")
check(#mask.list("accord") == ground_n.accord and #mask.list("throng") == ground_n.throng and
	ground_n.accord > 10 and ground_n.throng >= 4, "mask lists (" .. ground_n.accord .. " / " ..
	ground_n.throng .. ")")

-- The reasons, one per rule.
local function reason(f, cx, cz)
	local ok, why = mask.ground(f, cx, cz)
	return ok and "ground" or why
end
local expect = {
	{"accord", 0, -2, "shelf"},        -- the one-column enclave the lattice misses
	{"accord", -1, -1, "ground"},       -- the lake and the near-miss road
	{"accord", 0, -1, "road"},
	{"accord", 0, 1, "ground"},
	{"throng", 0, 3, "road"},
	{"accord", 0, 0, "landmark"},
	{"accord", 1, 0, "landmark"},
	{"accord", -2, 2, "deep_water"},    -- protected bay water
	{"accord", -1, 1, "camp"},
	{"accord", -1, -4, "leader"},
	{"accord", -1, -3, "place"},
	{"accord", -1, -2, "ground"},       -- the place's square misses by one
	{"accord", 2, -2, "town"},          -- a wall chunk: the city itself
	{"accord", 2, 0, "capital_ring"},
	{"accord", 2, -3, "capital_ring"},
	{"accord", 2, 1, "ground"},         -- capital ground two chunks out
	{"accord", 3, 2, "ground"},
	{"accord", 1, -2, "ground"},        -- beside the city, no capital ground
	{"accord", 4, 0, "high_level"},
	{"accord", -4, 0, "low_level"},
	{"accord", 0, 3, "enemy"},
	{"throng", 0, 0, "enemy"},
	{"throng", 0, 4, "rare"},
	{"throng", -3, 4, "site"},
	{"throng", -1, 4, "ground"},
	{"accord", 5, 0, "sea"},            -- partly outside the world plan
	{"accord", 9, 9, "sea"},            -- wholly outside
	{"accord", -5, -1, "low_level"},    -- partly outside, its centre inside
}
for _, e in ipairs(expect) do
	local got = reason(e[1], e[2], e[3])
	check(got == e[4], ("reason %s %d,%d: %s, expected %s"):format(e[1], e[2], e[3], got, e[4]))
end
check(select(2, mask.ground("nobody", 0, 0)) == "no_faction", "unknown faction")
do
	local got = {}
	for _, c in ipairs(mask.wall_chunks) do got[#got + 1] = c[1] .. "," .. c[2] end
	check(table.concat(got, " ") == "2,-2 3,-2 2,-1 3,-1",
		"wall chunks, an empty city interval marks none (" .. table.concat(got, " ") .. ")")
end

-- ground_in: the claim-ground chunks meeting a rectangle, row order
do
	local got = mask.ground_in("accord", 100, 50, 300, 250)
	local want = {}
	for _, c in ipairs(mask.list("accord")) do
		local x0, z0, x1, z1 = CM.chunk_bounds(c[1], c[2])
		if x1 >= 100 and x0 <= 300 and z1 >= 50 and z0 <= 250 then want[#want + 1] = c end
	end
	local same = #got == #want and #got > 0
	for n = 1, #got do
		same = same and got[n][1] == want[n][1] and got[n][2] == want[n][2]
	end
	check(same, "ground_in")
	local list = mask.list("accord")
	local sorted = true
	for n = 2, #list do
		local a, b = list[n - 1], list[n]
		if a[2] > b[2] or (a[2] == b[2] and a[1] >= b[1]) then sorted = false end
	end
	check(sorted, "list row order")
end

-- The scans: kept answers spare every column on the second build.
do
	local before = asked.water + asked.zone + asked.territory
	local again = CM.build(world, scans)
	local lattice_only = asked.water + asked.zone + asked.territory - before
	check(again.new_scans == 0 and mask.new_scans > 0, "second build makes no scan")
	check(lattice_only <= 121 * 25 * 3, "second build asks only the lattice (" ..
		lattice_only .. " answers)")
	local same = #again.list("accord") == #mask.list("accord") and
		#again.list("throng") == #mask.list("throng")
	check(same, "second build, same mask")
	-- the shortcut: a land column's territory is never asked in a scan
	check(asked.territory < asked.zone / 2, "the scan asks the territory of water columns only")
end

--
-- 4. The quota's ground
--
do
	local k = mask.kind_by_id["acc_claim/meadow"]
	check(k and k.cells == 18 and k.ground == 18 * 1024 and k.limit == 9 * 1024,
		"kind ground and limit")
	check(mask.kind_by_id["acc_claim/plain"] == nil and mask.kind_by_id["acc_low/foxes"] == nil and
		mask.kind_by_id["acc_claim/bandits"] == nil, "only quest kinds of claim zones")
	check(#mask.kinds == 2 and mask.kinds[1].id == "acc_cap/commons" and
		mask.kinds[2].id == "acc_claim/meadow", "kinds sorted by id")
	-- brute force: per column, every kind holding its cell
	local cellset = {}
	for _, c in ipairs(CLAIM_CELLS) do
		if c[3] == "meadow" then cellset[c[1] .. "," .. c[2]] = {"acc_claim/meadow"} end
	end
	for _, c in ipairs(CAP_CELLS) do
		local key = c[1] .. "," .. c[2]
		cellset[key] = cellset[key] or {}
		table.insert(cellset[key], "acc_cap/commons")
	end
	local bad = 0
	for cz = -6, 6 do
		for cx = -6, 6 do
			local x0, z0, x1, z1 = CM.chunk_bounds(cx, cz)
			local want = {}
			for z = z0, z1 do
				for x = x0, x1 do
					for _, id in ipairs(cellset[floor(x / 32) .. "," .. floor(z / 32)] or {}) do
						want[id] = (want[id] or 0) + 1
					end
				end
			end
			local got = {}
			for _, row in ipairs(mask.kind_columns(cx, cz)) do got[row[1]] = row[2] end
			for _, id in ipairs({"acc_claim/meadow", "acc_cap/commons"}) do
				if (want[id] or 0) ~= (got[id] or 0) then bad = bad + 1 end
			end
		end
	end
	check(bad == 0, "kind columns against brute force (" .. bad .. " differ)")
	-- chunk (-1, -1) lies inside the negative meadow cells (x, z -128 .. -1)
	local cols = {}
	for _, row in ipairs(mask.kind_columns(-1, -1)) do cols[row[1]] = row[2] end
	check(cols["acc_claim/meadow"] == 6400, "negative cells counted")
	-- chunk (2, 0) (x 128 .. 207, z -32 .. 47): the tie cell (4, 0) counts for
	-- both kinds; commons also holds (5, 0) and half of (5, 1) (z 32 .. 47)
	local tie = {}
	for _, row in ipairs(mask.kind_columns(2, 0)) do tie[row[1]] = row[2] end
	check(tie["acc_claim/meadow"] == 1024 and tie["acc_cap/commons"] == 2560,
		"tie cell in both kinds, a cell cut by the chunk edge")
	-- quota_refusal: the first kind whose taken columns would pass its limit
	check(mask.quota_refusal(-1, -1, {}) == nil, "quota free")
	check(mask.quota_refusal(-1, -1, {["acc_claim/meadow"] = 9 * 1024 - 6400}) == nil,
		"quota exactly at the limit")
	check(mask.quota_refusal(-1, -1, {["acc_claim/meadow"] = 9 * 1024 - 6399}) ==
		"acc_claim/meadow", "quota over the limit")
	-- commons' limit is 1536 columns, so chunk (2, 0) alone passes it
	check(mask.quota_refusal(2, 0, {}) == "acc_cap/commons", "quota, a small kind")
	check(#mask.kind_columns(2, 2) == 0, "a chunk without quest ground")
	local taken = mask.add_taken({}, 2, 0, 1)
	mask.add_taken(taken, -1, -1, 1)
	check(taken["acc_claim/meadow"] == 1024 + 6400 and taken["acc_cap/commons"] == 2560,
		"add_taken")
	mask.add_taken(taken, 2, 0, -1)
	mask.add_taken(taken, -1, -1, -1)
	check(next(taken) == nil, "add_taken back to nothing")
end

--
-- 5. The fingerprints
--
local rows = CM.fingerprints(mask, world, sha256)
check(#rows == ground_n.accord + ground_n.throng, "one fingerprint row per claim-ground chunk")
do
	local again = CM.fingerprints(mask, world, sha256)
	local same = true
	for n = 1, #rows do
		for k = 1, 8 do same = same and rows[n][k] == again[n][k] end
	end
	check(same, "fingerprints deterministic")
	-- one lattice point inside chunk (2, 1) (x0 = 128, z0 = 48: point 128 + 40,
	-- 48 + 40) raised by one node: only that chunk's height digest changes
	local h0 = world.height_at
	world.height_at = function(x, z) return h0(x, z) + ((x == 168 and z == 88) and 1 or 0) end
	local changed = CM.fingerprints(mask, world, sha256)
	world.height_at = h0
	local diff = {}
	for n = 1, #rows do
		for k = 4, 8 do
			if rows[n][k] ~= changed[n][k] then diff[#diff + 1] = rows[n][2] .. "," .. rows[n][3] .. ":" .. k end
		end
	end
	check(#diff == 1 and diff[1] == "2,1:4", "a height change moves one digest (" ..
		table.concat(diff, " ") .. ")")
	-- a road moved by half a node near chunk (-1, -1) changes its roads digest
	local old = world.roads[2].Z[1]
	world.roads[2].Z[1] = old + 0.5
	local moved = CM.fingerprints(mask, world, sha256)
	world.roads[2].Z[1] = old
	local hit = false
	for n = 1, #rows do
		if rows[n][1] == "accord" and rows[n][2] == -1 and rows[n][3] == -1 then
			hit = rows[n][7] ~= moved[n][7] and rows[n][4] == moved[n][4]
		end
	end
	check(hit, "a moved road changes the roads digest")
end

--
-- 6. The two files read back
--
do
	local files = {}
	local store = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask_store.lua")({
		sha256 = sha256,
		read = function(path) return files[path] end,
		write = function(path, bytes) files[path] = bytes return true end})
	local header = {{"game", "0.85.0"}, {"seed", "-12345"}, {"map_reset", "3"},
		{"chunk", 80}, {"origin", -32}}
	check(store.store_snapshot("/w", header, rows), "snapshot stored")
	local back = store.load_snapshot("/w")
	local same = back and #back.rows == #rows and back.header.seed == "-12345" and
		back.header.map_reset == "3" and back.names[1] == "game"
	for n = 1, #rows do
		for k = 1, 8 do same = same and back.rows[n][k] == rows[n][k] end
	end
	check(same, "snapshot read back")
	local bytes = files["/w/grug_claim_mask.txt"]
	check(bytes:sub(1, 19) == "grug_claim_mask_v1\n", "snapshot first line")
	files["/w/grug_claim_mask.txt"] = bytes:gsub("seed=%-12345", "seed=-12346")
	check(store.load_snapshot("/w") == nil, "an edited snapshot does not decode")
	files["/w/grug_claim_mask.txt"] = bytes:sub(1, #bytes - 10)
	check(store.load_snapshot("/w") == nil, "a truncated snapshot does not decode")
	check(select(2, store.load_snapshot("/none")) == "no file", "no snapshot")
	local key = {{"seed", "-12345"}, {"builder", "abc"}}
	check(store.store_cache("/w", key, scans), "cache stored")
	local got = store.load_cache("/w", key)
	local n_in, n_out = 0, 0
	for k, s in pairs(scans) do
		n_in = n_in + 1
		if got and got[k] and got[k].code == s.code and got[k].cap == s.cap then n_out = n_out + 1 end
	end
	check(n_in > 0 and n_in == n_out, "cache read back")
	local none, why, damaged = store.load_cache("/w", {{"seed", "-12345"}, {"builder", "abd"}})
	check(none == nil and why == "builder differs" and damaged == false, "cache of another key")
	local cbytes = files["/w/grug_claim_ground.txt"]
	files["/w/grug_claim_ground.txt"] = cbytes:gsub(" ok ", " xx ", 1)
	none, why, damaged = store.load_cache("/w", key)
	check(none == nil and damaged == true, "an edited cache does not decode")
	-- a cache that decodes but is another format's
	files["/w/grug_claim_ground.txt"] = "grug_claim_ground_v0\n"
	local head = files["/w/grug_claim_ground.txt"]
	files["/w/grug_claim_ground.txt"] = head .. "end " .. sha256(head) .. "\n"
	none, why, damaged = store.load_cache("/w", key)
	check(none == nil and damaged == false, "a cache of another format")
end

--
-- 7. The column rule against the registry's (capital zones aside)
--
do
	local store = {}
	-- Round 85 CORE: the game's registry has no column rule any more (the mask
	-- is it); the 0.84.1 rule is kept frozen for this comparison.
	local HM = dofile(repo .. "/tools/r85_claimcap/registry_084.lua")({
		storage = {get_string = function(k) return store[k] or "" end,
			set_string = function(k, v) store[k] = v ~= "" and v or nil end,
			keys = function() return {} end},
		now = function() return 1000 end})
	local bad = 0
	for _, water in ipairs({"land", "planned_water", "coastal_shelf", "deep_ocean",
			"immutable_dragon_channel"}) do
		for _, zone in ipairs({ZONES.acc_low, ZONES.acc_claim, ZONES.acc_cap, ZONES.contested,
				ZONES.thr_claim, false}) do
			for _, territory in ipairs({"accord_home", "throng_home", "hard_protected",
					"immutable", "contested_land"}) do
				for _, f in ipairs({"accord", "throng"}) do
					local mine = CM.column_problem(f, water, zone or nil, territory)
					local theirs = HM.column_problem(f, water, zone or nil, territory)
					if theirs == "capital_zone" then
						-- ruling 6: the faction's capital zones are admitted
						if mine == "capital_zone" then bad = bad + 1 end
					elseif mine ~= theirs then
						bad = bad + 1
					end
				end
			end
		end
	end
	check(bad == 0, "column rule matches the registry's (" .. bad .. " differ)")
	local p, cap = CM.column_problem("accord", "land", ZONES.acc_cap, "accord_home")
	check(p == nil and cap == true, "a capital-zone column is claim ground, marked")
end

--
-- 8. The region map's cell grid (spawn_regions_cache.lua)
--
do
	local CACHE = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_cache.lua")({
		sha256 = sha256, read = function() return nil end, write = function() return true end,
		cell = 32})
	local kind = {id = "meadow", levels = {11, 13}, quest_target = true}
	local camp = {id = "bandits", levels = {12, 14}, tag = "z/bandits", rosters = {},
		levels_by_role = {}, site = "generate"}
	local recipe = {belts = {{levels = {11, 14}}}, kind_by_id = {meadow = kind},
		camp_by_id = {bandits = camp}, leaders = {}, place_by_id = {}}
	local regions = {{id = 1, kind = kind, belt = 1, x = -40, z = -40, size = 3},
		{id = 2, kind = camp, belt = 1, x = 70, z = 6, size = 1}}
	local u = {id = "bandits", x = 70, z = 6, region = regions[2], score = 1, slope = 0}
	regions[2].camp = u
	local order = {{i = -2, j = -2, region = regions[1]}, {i = -1, j = -2, region = regions[1]},
		{i = -2, j = -1, region = regions[1]}, {i = 2, j = 0, region = regions[2]}}
	local full = {order = order, regions = regions, camps = {u}, leaders = {}, places = {},
		problems = {}, warnings = {}}
	local map = assert(CACHE.rehydrate("z", CACHE.compact(full), recipe))
	local seen = {}
	local f = map.cell_frame
	for j = f.j0, f.j0 + f.h - 1 do
		for i = f.i0, f.i0 + f.w - 1 do
			local r = map.cell_region(i, j)
			if r then seen[#seen + 1] = i .. "," .. j .. ":" .. r.kind.id .. (r.camp and "+camp" or "") end
		end
	end
	check(table.concat(seen, " ") ==
		"-2,-2:meadow -1,-2:meadow -2,-1:meadow 2,0:bandits+camp", "cell grid of a compact map (" ..
		table.concat(seen, " ") .. ")")
	check(map.cell_region(-1, -1) == nil and map.cell_region(9, 9) == nil, "no cell off the grid")
	-- the mask reads it as add_zone_spawn's input
	local sp = CM.new_spawn()
	CM.add_zone_spawn(sp, "z", function(fn)
		for j = f.j0, f.j0 + f.h - 1 do
			for i = f.i0, f.i0 + f.w - 1 do
				local r = map.cell_region(i, j)
				if r then fn(i, j, r) end
			end
		end
	end, {}, {}, true)
	check(#sp.camp_cells == 2 and sp.camp_cells[1] == 2 and #sp.kinds == 1 and
		sp.kinds[1].id == "z/meadow" and #sp.kinds[1].cells == 6, "spawn input from the grid")
end

--
-- 9. The engine glue (grug_housing/mask.lua) on a fake engine: a recipe zone
--    without its region map fails the mask closed; a failed snapshot leaves
--    the mask in use, is reported, and the next start writes it
--
do
	local files, logs, severe = {}, {}, {}
	local height_fails, missing_map = false, nil
	local FAKE = "/fake/grug_mapgen/wp40/"
	local stubs = {
		["source/simple_map.lua"] = {world_bounds = world.bounds, zones = {{id = "acc_low"},
			{id = "acc_claim"}, {id = "acc_cap"}, {id = "contested"}, {id = "thr_claim"}}},
		["world_protection.lua"] = {road_corridors = function() return {} end},
		["road_layout.lua"] = {},
		["r7_native.lua"] = {identities = function()
			return {noise_digest = "noise", native_digest = "native"}
		end},
	}
	local env = setmetatable({}, {__index = _G})
	env.dofile = function(path)
		if path:sub(1, #FAKE) == FAKE then return assert(stubs[path:sub(#FAKE + 1)], path) end
		return dofile(path)
	end
	env.io = {open = function(path, mode)
		if path:sub(1, 11) == "/fakeworld/" then
			local text = files[path]
			if not text then return nil end
			return {read = function() return text end, close = function() end}
		end
		return io.open(path, mode)
	end}
	local mods_loaded
	env.core = {
		get_modpath = function(name)
			if name == "grug_mapgen" then return "/fake/grug_mapgen" end
			if name == "grug_housing" then return repo .. "/mods/PLAYER/grug_housing" end
			if name == "grug_core" then return repo .. "/mods/CORE/grug_core" end
			error("no mod " .. name)
		end,
		sha256 = sha256,
		safe_file_write = function(path, bytes) files[path] = bytes return true end,
		get_worldpath = function() return "/fakeworld" end,
		get_us_time = function() return os.clock() * 1e6 end,
		get_mapgen_setting = function() return "1" end,
		log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
		register_on_mods_loaded = function(fn) mods_loaded = fn end,
	}
	env.grug_zones = {
		get = function(id) return ZONES[id] end,
		water_class_at = water_of,
		id_at = function(x, z) return zone_of(x, z).id end,
		territory_rule_at = function(p) return territory_of(p.x, p.z) end,
		terrain_height_at = function(x, z)
			if height_fails then error("height query failed", 0) end
			return world.height_at(x, z)
		end,
		hard_footprint_in = function() return nil end,
	}
	env.grug_core = {
		world_feature_boxes_in = function() return false end,
		rare_route = function() return nil end,
		map_reset = {applied = 0},
		world_version = {game = "0.85.0"},
		severe = {report = function(source, summary, details, key)
			severe[#severe + 1] = {key = key, text = summary .. ": " .. tostring(details)}
		end},
	}
	env.grug_mapgen = {wp40 = {road_layout_text = "", capital_protection = {},
		world_key = {seed = "1", source = "s", settings = "x", interpreter = "j"}}}
	local zone_cells = {acc_claim = CLAIM_CELLS, acc_cap = CAP_CELLS}
	env.grug_mobs = {registered_rares = {}, spawn_regions = {
		zone_ids = function() return {"acc_cap", "acc_claim"} end,
		map = function(id)
			if id == missing_map then return nil end
			return {leaders = {}, places = {}}
		end,
		each_cell = function(id, fn) each(zone_cells[id])(fn) return true end,
	}}
	local function boot()
		logs, severe = {}, {}
		env.grug_housing = {}
		local chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_housing/mask.lua"))
		setfenv(chunk, env)
		chunk()
		mods_loaded()
		return env.grug_housing.mask
	end
	local SNAP = "/fakeworld/grug_claim_mask.txt"

	-- a healthy first start
	local m = boot()
	check(m ~= nil and #severe == 0 and files[SNAP] ~= nil and
		files["/fakeworld/grug_claim_ground.txt"] ~= nil, "glue: a healthy start")
	check(m and #m.kinds == 2, "glue: the quota's kinds from the region maps")

	-- a recipe zone without its map: the mask stays nil, reported as severe
	files = {}
	missing_map = "acc_cap"
	m = boot()
	missing_map = nil
	check(m == nil and #severe == 1 and severe[1].key == "claim_mask" and
		severe[1].text:find("acc_cap", 1, true) ~= nil and files[SNAP] == nil and
		files["/fakeworld/grug_road_chunks.txt"] ~= nil,
		"glue: a missing region map fails the mask closed (" ..
		tostring(severe[1] and severe[1].text) .. ")")

	-- a failed snapshot: the mask in use, reported, nothing written
	files = {}
	height_fails = true
	m = boot()
	height_fails = false
	check(m ~= nil and #m.list("accord") > 0, "glue: a failed snapshot leaves the mask in use")
	check(#severe == 1 and severe[1].key == "claim_mask_snapshot" and
		severe[1].text:find("next start", 1, true) ~= nil and
		severe[1].text:find("height query failed", 1, true) ~= nil,
		"glue: a failed snapshot is reported (" .. tostring(severe[1] and severe[1].text) .. ")")
	check(files[SNAP] == nil and files["/fakeworld/grug_claim_ground.txt"] ~= nil,
		"glue: no snapshot written, the scan cache kept")
	-- the next start writes it; the one after keeps it
	m = boot()
	local written = files[SNAP]
	check(m ~= nil and #severe == 0 and written ~= nil, "glue: the next start writes the snapshot")
	m = boot()
	local kept = false
	for _, line in ipairs(logs) do
		if line:find("is kept", 1, true) then kept = true end
	end
	check(m ~= nil and kept and files[SNAP] == written, "glue: a later start keeps it")

	-- A failed atomic replacement preserves the last map until a retry succeeds.
	local road_file = "/fakeworld/grug_road_chunks.txt"
	local original = assert(files[road_file])
	local write = env.core.safe_file_write
	env.core.safe_file_write = function(path, bytes)
		if path == road_file then return false end
		return write(path, bytes)
	end
	env.grug_core.map_reset.applied = 1
	m = boot()
	check(m and #severe == 1 and severe[1].key == "road_chunk_snapshot" and
		files[road_file] == original, "road capture failure preserves the old map and housing")
	env.core.safe_file_write = write
	m = boot()
	local ref = dofile(repo .. "/mods/PLAYER/grug_housing/road_reference.lua")(CM)
	local record = assert(ref.decode(files[road_file], sha256))
	check(m and #severe == 0 and record.map_reset == 1 and record.previous_reset == 0,
		"road reference retries the reset after a write failure")

end

print(("r85_mask: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("r85_mask FAIL %d of %d"):format(failures, checks), 0) end
