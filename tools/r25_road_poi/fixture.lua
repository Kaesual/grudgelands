-- Round 25 Lane E portable fixture (LuaJIT): road and POI protection
-- (rulings 15-17) without an engine.
--
--   luajit tools/r25_road_poi/fixture.lua "$PWD" [seed ...]
--
-- 1. Synthetic roads of every class, serialized and read back through the
--    real road module, checked against the real road sampler: sideways
--    exactly half width + 3 in and + 4 out, +-5 around the sampler's surface
--    node in and +-6 out (flat and sloped), round segment ends, an L joint
--    in the middle of a registered run and on a run boundary, and a bridge
--    run (bridge exactly where the sampler gives the bridge material).
-- 2. Per seed (default: both standard seeds), the real road layout and the
--    real POI, village and camp blueprints:
--    a. every settlement box: derivation (blueprint cell bounds on the fitted
--       anchor, 10 below the placement height, 10 above the highest node),
--       its category and its six faces in/out;
--    b. the candidate-grid answer equals a brute-force oracle over every
--       segment and box at random world points, at points around the roads
--       (across and beyond the corridor, around the surface) and around the
--       boxes;
--    c. the node the road writer lays at a surface column (planner
--       road_column_at, as road_writer.lua reads it) lies in the corridor, and
--       the corridor answers "bridge" exactly where the writer takes the
--       bridge material;
--    d. grug_core installed for real (zone_authority.lua with the real zones
--       session, consumer payload and this protection; protection.lua):
--       world_protected_for_faction for both factions, core.is_protected,
--       and the hint reasons and texts.
-- Prints per-seed figures and "R25 ROAD POI FIXTURE PASS checks=<n>", or
-- raises on the first failure.
local repo = assert(arg[1], "usage: fixture.lua <repo> [seed ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"4242424242", "10536739806879207652"} end

local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local roads = dofile(dir .. "/road_layout.lua")
local index128 = dofile(dir .. "/index128.lua")
local wp = dofile(dir .. "/world_protection.lua")
local floor, abs, sqrt = math.floor, math.abs, math.sqrt
local HALF = roads.P.HALF
local Q = roads.P.Q

-- ---------------------------------------------------------------------------
-- 1. Synthetic roads
-- ---------------------------------------------------------------------------
-- A road through the real serializer: points {x, z}, profile in 1/Q nodes.
local function synthetic(kind, points, rq, cls)
	local X, Z = {}, {}
	for i = 1, #points do X[i], Z[i] = points[i][1], points[i][2] end
	local road = {id = 1, kind = kind, X = X, Z = Z, RQ = rq, cls = cls,
		a = "a", b = "b"}
	return roads.serialize({roads = {road}})
end

local function build(text, chunk)
	return wp.new(index128, {chunk = chunk,
		corridors = wp.road_corridors(roads, text)}), roads.sampler(roads.deserialize(text))
end

local function surface_of(sampler, x, z)
	local kind, road_y, _, _, _, extra = sampler.column(x, z, -100, nil)
	if kind ~= "surface" then return nil end
	return floor(road_y), extra
end

for _, kind in ipairs({"primary", "secondary", "trail"}) do
	local hw = HALF[kind]
	local edge = floor(hw) + 3      -- the last protected column off the centre
	check(2 * edge + 1 == ({primary = 13, secondary = 11, trail = 9})[kind],
		kind .. " protected width")
	-- Straight along +x at z = 50: flat y = 10 for x 0..20, then 1/4 per node.
	local points, rq, cls = {}, {}, {}
	for i = 0, 40 do
		points[#points + 1] = {i, 50}
		rq[#rq + 1] = 10 * Q + (i > 20 and (i - 20) * Q / 4 or 0)
		cls[#cls + 1] = "G"
	end
	local P, S = build(synthetic(kind, points, rq, cls))
	for _, x in ipairs({2, 10, 19, 21, 27, 33, 38}) do
		local s = surface_of(S, x, 50)
		check(s ~= nil, kind .. " sampler surface at x=" .. x)
		for side = -1, 1, 2 do
			local z_in, z_out = 50 + side * edge, 50 + side * (edge + 1)
			local s_in = surface_of(S, x, 50) -- the centre column's surface
			check(P.kind_at(x, s_in, z_in) == "road", kind .. " +3 in at x=" .. x)
			check(P.kind_at(x, s_in, z_out) == nil, kind .. " +4 out at x=" .. x)
		end
		-- every surface column across the road: +-5 in, +-6 out
		for dz = -floor(hw), floor(hw) do
			local sc = surface_of(S, x, 50 + dz)
			check(sc ~= nil, kind .. " surface column dz=" .. dz)
			check(P.kind_at(x, sc + 5, 50 + dz) == "road" and
				P.kind_at(x, sc - 5, 50 + dz) == "road", kind .. " +-5 in at x=" .. x)
			check(P.kind_at(x, sc + 6, 50 + dz) == nil and
				P.kind_at(x, sc - 6, 50 + dz) == nil, kind .. " +-6 out at x=" .. x)
		end
		check(s == 10 + (x > 20 and floor(floor(2 * (x - 20) / 4 + 0.5) / 2) or 0),
			kind .. " surface follows the profile at x=" .. x)
	end
	-- Segment ends: round caps of radius half width + 3 round both ends.
	local s0 = surface_of(S, 0, 50)
	check(P.kind_at(-edge, s0, 50) == "road", kind .. " start cap in")
	check(P.kind_at(-edge - 1, s0, 50) == nil, kind .. " start cap out")
	local s40 = surface_of(S, 40, 50)
	check(P.kind_at(40 + edge, s40, 50) == "road", kind .. " end cap in")
	check(P.kind_at(40 + edge + 1, s40, 50) == nil, kind .. " end cap out")
	-- the corner of the cap is round: the diagonal reach
	local diagonal = floor((hw + 3) / sqrt(2))
	check(P.kind_at(-diagonal, s0, 50 - diagonal) == "road", kind .. " cap diagonal in")
	check(P.kind_at(-diagonal - 1, s0, 50 - diagonal - 1) == nil, kind ..
		" cap diagonal out")
	check(P.kind_at(-edge, s0 + 5, 50) == "road" and P.kind_at(-edge, s0 + 6, 50) == nil,
		kind .. " cap vertical")

	-- An L joint at point 21 (x = 20, z = 0): in the middle of a run (chunk 16)
	-- and on a run boundary (chunk 20), and with one segment per run.
	local lp, lq, lc = {}, {}, {}
	for i = 0, 20 do lp[#lp + 1] = {i, 0}; lq[#lq + 1] = 5 * Q; lc[#lc + 1] = "G" end
	for i = 1, 20 do lp[#lp + 1] = {20, i}; lq[#lq + 1] = 5 * Q; lc[#lc + 1] = "G" end
	local text = synthetic(kind, lp, lq, lc)
	for _, chunk in ipairs({1, 16, 20}) do
		local J = build(text, chunk)
		local label = kind .. " joint chunk " .. chunk
		check(J.kind_at(20 + edge, 5, 0) == "road", label .. " outside +x in")
		check(J.kind_at(20 + edge + 1, 5, 0) == nil, label .. " outside +x out")
		check(J.kind_at(20, 5, -edge) == "road", label .. " outside -z in")
		check(J.kind_at(20, 5, -edge - 1) == nil, label .. " outside -z out")
		check(J.kind_at(20 + diagonal, 5, -diagonal) == "road", label .. " corner in")
		check(J.kind_at(20 + diagonal + 1, 5, -diagonal - 1) == nil, label ..
			" corner out")
		check(J.kind_at(20 - edge - 1, 5, edge + 1) == nil, label .. " inside out")
		check(J.kind_at(20 - edge, 5, edge) == "road", label .. " inside in")
		check(J.kind_at(20, 10, 0) == "road" and J.kind_at(20, 11, 0) == nil,
			label .. " vertical at the joint")
		-- along both legs the edge columns are exact (on the inside of the
		-- bend only where the other leg is out of reach)
		for i = 1, 19 do
			check(J.kind_at(i, 5, edge) == "road" and J.kind_at(i, 5, -edge) == "road" and
				J.kind_at(i, 5, -edge - 1) == nil, label .. " leg 1 edge at x=" .. i)
			check(J.kind_at(20 + edge, 5, i) == "road" and J.kind_at(20 - edge, 5, i) == "road" and
				J.kind_at(20 + edge + 1, 5, i) == nil, label .. " leg 2 edge at z=" .. i)
			if i <= 20 - edge - 1 then
				check(J.kind_at(i, 5, edge + 1) == nil, label .. " leg 1 inside out at x=" .. i)
			end
			if i >= edge + 1 then
				check(J.kind_at(20 - edge - 1, 5, i) == nil, label .. " leg 2 inside out at z=" .. i)
			end
		end
	end
end

-- A bridge: ground, a raised run over water ("B"), ground; the deck rises.
do
	local points, rq, cls = {}, {}, {}
	for i = 0, 40 do
		points[#points + 1] = {i, -30}
		local lift = (i >= 14 and i <= 26) and 3 or
			((i == 13 or i == 27) and 2 or ((i == 12 or i == 28) and 1 or 0))
		rq[#rq + 1] = (8 + lift) * Q
		cls[#cls + 1] = (i >= 16 and i <= 24) and "B" or "G"
	end
	-- the deck rises 1 node per point (the serializer's profile step is
	-- below 2 nodes)
	local P, S = build(synthetic("secondary", points, rq, cls))
	local bridges, plain = 0, 0
	for x = 0, 40 do
		for dz = -2, 2 do
			local s, extra = surface_of(S, x, -30 + dz)
			local want = extra.bridge and "bridge" or "road"
			check(P.kind_at(x, s, -30 + dz) == want, "bridge kind matches the sampler at x=" ..
				x .. " dz=" .. dz)
			check(P.kind_at(x, s + 5, -30 + dz) == want and P.kind_at(x, s - 5, -30 + dz) == want,
				"bridge +-5 at x=" .. x)
			if want == "bridge" then bridges = bridges + 1 else plain = plain + 1 end
		end
	end
	check(bridges > 0 and plain > 0, "bridge run and plain road both present")
	-- the landings (BRIDGE_LAND ground points each side) belong to the bridge
	check(P.kind_at(14, 11, -30) == "bridge" and P.kind_at(26, 11, -30) == "bridge",
		"bridge landings")
	check(P.kind_at(12, 8, -30) == "road" and P.kind_at(28, 8, -30) == "road",
		"road beyond the landings")
	check(P.kind_at(20, 11, -30 + 5) == "bridge" and P.kind_at(20, 11, -30 + 6) == nil,
		"bridge sideways reach")
end
print("synthetic roads: ok")

-- ---------------------------------------------------------------------------
-- 2. Real worlds
-- ---------------------------------------------------------------------------
local EXPECTED_KIND = {village = "village", outpost = "poi", bandit_home = "camp",
	bandit_frontier = "camp", mine = "poi", mirefolk = "camp", clash = "poi",
	dragon = "poi", apex_mine = "poi", rare_route = "poi"}

-- Deterministic pseudo-random numbers (no math.random state shared).
local function rng(seed_value)
	local state = seed_value % 2147483647
	if state <= 0 then state = state + 2147483646 end
	return function(n)
		state = (state * 48271) % 2147483647
		return state % n
	end
end

local function run_seed(seed)
	local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
	local P = W.protection
	local m = P.metrics
	print(("seed %s: world %.1f s, blueprints %.2f s; protection built in %.4f s, " ..
		"%.0f KiB; %d corridors, %d segments, %d runs, %d boxes, %d records, %d cells, " ..
		"%d references, max %d per cell; road text %d bytes"):format(seed,
		W.seconds.world, W.seconds.blueprints, W.seconds.protection, W.memory_kib,
		m.corridors, m.segments, m.runs, m.boxes, m.records, m.populated_cells,
		m.candidate_references, m.maximum_candidates, #W.road_text))
	check(m.boxes == 88, "88 settlement boxes")

	-- The oracle: every box, then every segment of every road.
	local corridors = wp.road_corridors(W.roads, W.road_text)
	local boxes = wp.settlement_boxes(W.rows)
	local function oracle(x, y, z)
		for _, b in ipairs(boxes) do
			if x >= b.min_x and x <= b.max_x and z >= b.min_z and z <= b.max_z and
					y >= b.min_y and y <= b.max_y then return b.kind, {[b.kind] = true} end
		end
		-- each road: its nearest centreline point (first in segment order)
		local kinds, any = {}, nil
		for _, c in ipairs(corridors) do
			local X, Z, R, reach = c.X, c.Z, c.R, c.half_width + c.side
			local best, bi, bu = math.huge, nil, nil
			for i = 1, #X - 1 do
				local ax, az = X[i], Z[i]
				local vx, vz = X[i + 1] - ax, Z[i + 1] - az
				local l2 = vx * vx + vz * vz
				local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				local dx, dz = x - ax - u * vx, z - az - u * vz
				local d2 = dx * dx + dz * dz
				if d2 < best then best, bi, bu = d2, i, u end
			end
			if best <= reach * reach then
				local s = wp.surface_node(R[bi], R[bi + 1], bu)
				if abs(y - s) <= c.vertical then
					local k = c.special[bu < 0.5 and bi or bi + 1] and "bridge" or "road"
					kinds[k] = true
					any = k
				end
			end
		end
		return any, kinds
	end
	local function agree(x, y, z, label)
		local got = P.kind_at(x, y, z)
		local want, kinds = oracle(x, y, z)
		check((got == nil) == (want == nil) and (got == nil or kinds[got]),
			label .. (" at %d,%d,%d: %s vs %s"):format(x, y, z, tostring(got), tostring(want)))
		return got
	end

	-- a. Settlement boxes.
	local boxes_only = wp.new(index128, {boxes = boxes})
	local by_kind = {}
	for index, row in ipairs(W.rows) do
		local b = boxes[index]
		local want = EXPECTED_KIND[row.template_id]
		check(b.kind == want, row.key .. " category " .. tostring(b.kind))
		by_kind[b.kind] = (by_kind[b.kind] or 0) + 1
		local a, bb = row.anchor, row.bounds
		check(b.min_x == a.x + bb.min.x and b.max_x == a.x + bb.max.x and
			b.min_z == a.z + bb.min.z and b.max_z == a.z + bb.max.z and
			b.min_y == a.y - 10 and b.max_y == a.y + bb.max.y + 10 and bb.min.y == 0,
			row.key .. " box derivation")
		-- the blueprint's cells fill the anchor profile's building core square
		local core = W.source.anchor_profiles
		local width
		for _, p in ipairs(core) do
			if p.id == row.template_id then width = p.building_core_width end
		end
		check(bb.max.x - bb.min.x + 1 == width and bb.max.z - bb.min.z + 1 == width and
			bb.min.x == -width / 2 and bb.min.z == -width / 2,
			row.key .. " cell bounds are the building core square")
		local mx, my, mz = floor((b.min_x + b.max_x) / 2), floor((b.min_y + b.max_y) / 2),
			floor((b.min_z + b.max_z) / 2)
		for _, p in ipairs({{b.min_x, my, mz}, {b.max_x, my, mz}, {mx, my, b.min_z},
				{mx, my, b.max_z}, {mx, b.min_y, mz}, {mx, b.max_y, mz},
				{b.min_x, b.min_y, b.min_z}, {b.max_x, b.max_y, b.max_z}}) do
			check(boxes_only.kind_at(p[1], p[2], p[3]) == b.kind, row.key .. " face in")
			check(P.kind_at(p[1], p[2], p[3]) == b.kind, row.key .. " face in (full index)")
		end
		for _, p in ipairs({{b.min_x - 1, my, mz}, {b.max_x + 1, my, mz},
				{mx, my, b.min_z - 1}, {mx, my, b.max_z + 1}, {mx, b.min_y - 1, mz},
				{mx, b.max_y + 1, mz}}) do
			check(boxes_only.kind_at(p[1], p[2], p[3]) == nil, row.key .. " face out")
			agree(p[1], p[2], p[3], row.key .. " face out (full index)")
		end
	end
	print(("  boxes: %d village, %d camp, %d poi"):format(by_kind.village or 0,
		by_kind.camp or 0, by_kind.poi or 0))
	check(by_kind.village == 12 and by_kind.camp == 16 and by_kind.poi == 60,
		"box categories")

	-- b. Candidate grid against the oracle.
	local random = rng(tonumber(seed:sub(-9)) or 1)
	local S = W.session
	local hits = 0
	for _ = 1, 1500 do
		local x, z = -3740 + random(7481), -3340 + random(6681)
		local y = S.terrain_height_at(x, z) - 8 + random(17)
		if agree(x, y, z, "random point") then hits = hits + 1 end
	end
	local near_hits, near = 0, 0
	for _, c in ipairs(corridors) do
		local n = #c.X
		for _ = 1, 40 do
			local i = 1 + random(n)
			if i > n then i = n end
			local reach = floor(c.half_width + c.side) + 3
			local x = floor(c.X[i] + 0.5) - reach + random(2 * reach + 1)
			local z = floor(c.Z[i] + 0.5) - reach + random(2 * reach + 1)
			local s = wp.surface_node(c.R[i], c.R[i], 0)
			-- mostly around the surface, every fourth far above or below it
			-- (the per-run surface band early-out)
			local y = random(4) == 0 and s - 40 + random(81) or s - 8 + random(17)
			near = near + 1
			if agree(x, y, z, "near " .. c.id) then near_hits = near_hits + 1 end
		end
	end
	for _, b in ipairs(boxes) do
		for _ = 1, 10 do
			local x = b.min_x - 4 + random(b.max_x - b.min_x + 9)
			local z = b.min_z - 4 + random(b.max_z - b.min_z + 9)
			local y = b.min_y - 3 + random(b.max_y - b.min_y + 7)
			agree(x, y, z, "near box")
		end
	end
	print(("  oracle: 1500 random points (%d protected), %d road points (%d " ..
		"protected), %d box points"):format(hits, near, near_hits, 10 * #boxes))

	-- c. The node the writer lays at every sampled surface column.
	local planner = W.planner_source
	local columns, moved, bridge_columns, max_shift = 0, 0, 0, 0
	for _, c in ipairs(corridors) do
		local X, Z = c.X, c.Z
		for i = 1, #X, 6 do
			local cx, cz = floor(X[i] + 0.5), floor(Z[i] + 0.5)
			for dx = -1, 1 do
				for dz = -1, 1 do
					local x, z = cx + dx * 2, cz + dz * 2
					local kind, road_y, terrain_y, class, _, bridge =
						planner.road_column_at(x, z)
					if kind == "surface" then
						columns = columns + 1
						local top = floor(road_y)
						-- road_writer.lua: decks and bridges at the road height,
						-- every other class on the terrain top
						local node = (class == "deck" or class == "bridge") and top or terrain_y
						if node ~= top then moved = moved + 1 end
						if abs(node - top) > max_shift then max_shift = abs(node - top) end
						local got = P.kind_at(x, node, z)
						check(got ~= nil, ("writer surface node protected at %d,%d,%d (%s)"):format(
							x, node, z, tostring(class)))
						local want_bridge = bridge == true
						if want_bridge then bridge_columns = bridge_columns + 1 end
						if got == "road" or got == "bridge" then
							-- the kind at the sampler's own surface node, where no
							-- other corridor may answer first
							local _, kinds = oracle(x, top, z)
							check(kinds[want_bridge and "bridge" or "road"] == true,
								("bridge flag at %d,%d"):format(x, z))
						end
					end
				end
			end
		end
	end
	print(("  writer: %d surface columns, %d laid off the sampler's node (max %d), " ..
		"%d bridge columns"):format(columns, moved, max_shift, bridge_columns))
	check(columns > 1000, "enough surface columns sampled")

	-- d. grug_core for real.
	local common = W.common
	local sha_hex = function(bytes) return common.hex(W.sha(bytes)) end
	local factions = {}
	_G.core = {
		sha256 = sha_hex,
		is_protected = function() return false end,
		check_player_privs = function() return false end,
		log = function() end,
	}
	_G.grug_zones = nil
	_G.grug_core = {get_player_faction = function(name) return factions[name] end}
	assert(loadfile(repo .. "/mods/CORE/grug_core/zone_authority.lua"))()
	assert(loadfile(repo .. "/mods/CORE/grug_core/protection.lua"))()
	local payload = dofile(dir .. "/r7_consumer_payload.lua")(W.source, sha_hex)
	check(not pcall(grug_core.prepare_zone_authority, S, payload),
		"authority refuses a missing world protection")
	check(grug_core.world_protected_for_faction({x = 0, y = 0, z = 0}, "accord") == true,
		"fail closed before installation")
	grug_core.install_zone_authority(S, payload, P)
	factions.a, factions.t, factions.n = "accord", "throng", nil
	-- A road column in Accord and one in Throng home territory, a bridge, a
	-- column just beyond a corridor, one box per category, a start town.
	local found = {}
	for _, c in ipairs(corridors) do
		for i = 1, #c.X, 5 do
			local x, z = floor(c.X[i] + 0.5), floor(c.Z[i] + 0.5)
			local y = wp.surface_node(c.R[i], c.R[i], 0)
			local k = P.kind_at(x, y, z)
			local rule = grug_zones.territory_rule_at({x = x, y = y, z = z})
			if (k == "road" or k == "bridge") and rule ~= "hard_protected" then
				local key = k .. ":" .. rule
				if not found[key] then found[key] = {x = x, y = y, z = z} end
			end
		end
	end
	local function hint(pos, name) return grug_core.protection_hint(pos, name) end
	local tested = 0
	for key, pos in pairs(found) do
		local k = key:match("^(%a+):")
		local text = k == "bridge" and "Bridge – protected" or "Road – protected"
		for _, name in ipairs({"a", "t"}) do
			check(core.is_protected(pos, name), key .. " protected for " .. name)
			check(grug_core.world_protected_for_faction(pos, factions[name]),
				key .. " world protection for " .. name)
			check(grug_core.world_feature_at(pos) == k, key .. " feature")
			check(hint(pos, name) == text, key .. " hint for " .. name .. ": " ..
				tostring(hint(pos, name)))
		end
		check(hint(pos, "n") == "Protected – choose a faction first", key .. " no faction")
		check(core.is_protected(pos, ""), key .. " empty actor")
		-- fractional positions round like the zone session
		check(grug_core.world_feature_at({x = pos.x + 0.4, y = pos.y - 0.4, z = pos.z}) == k,
			key .. " rounding")
		tested = tested + 1
	end
	check(found["road:accord_home"] and found["road:throng_home"],
		"roads in both home territories")
	-- Beside a home road: open to the home faction exactly outside the corridor.
	do
		local pos = found["road:accord_home"]
		local y = pos.y
		local x = pos.x
		for dz = 1, 30 do
			local p = {x = x, y = y, z = pos.z + dz}
			if P.kind_at(p.x, p.y, p.z) == nil and
					grug_zones.territory_rule_at(p) == "accord_home" then
				check(not core.is_protected(p, "a"), "beside the road: open to accord")
				check(hint(p, "a") == nil, "beside the road: no hint for accord")
				check(hint(p, "t") == "Accord home territory – protected",
					"beside the road: throng sees the territory")
				tested = tested + 1
				break
			end
		end
	end
	local per_kind = {}
	for index, b in ipairs(boxes) do
		if not per_kind[b.kind] then
			per_kind[b.kind] = true
			local p = {x = b.min_x, y = b.max_y, z = b.max_z}
			local text = ({village = "Village – protected", camp = "Camp – protected",
				poi = "Point of interest – protected"})[b.kind]
			for _, name in ipairs({"a", "t"}) do
				check(core.is_protected(p, name), W.rows[index].key .. " protected for " .. name)
				local got = hint(p, name)
				-- a box on hard-protected ground (an exact landmark column) names
				-- the landmark first
				check(got == text or got == "Landmark – protected",
					W.rows[index].key .. " hint " .. tostring(got))
			end
			tested = tested + 1
		end
	end
	-- A start town keeps its own (town) protection and hint.
	local start = grug_core.start_anchor("accord", "human")
	check(hint(start, "a") == "Town – protected", "start town hint")

	-- Dragon ground effects (grug_core.ground_effect_protected): the zone rule
	-- without the road and POI layer, so a dragon's arena core stays open to
	-- its scorch and rime; towns and the other faction's home stay closed.
	local dragons = 0
	for index, row in ipairs(W.rows) do
		if row.template_id == "dragon" then
			local b = boxes[index]
			for _, p in ipairs({{x = row.anchor.x + 3, y = row.anchor.y + 1, z = row.anchor.z - 5},
					{x = b.min_x, y = b.min_y, z = b.max_z}, {x = b.max_x, y = b.max_y, z = b.min_z}}) do
				local rule = grug_zones.territory_rule_at(p)
				check(grug_core.world_feature_at(p) == "poi", row.key .. " core is a POI")
				check(grug_core.world_protected_for_faction(p, "accord"), row.key ..
					" players refused in the core")
				check(rule == "contested_land", row.key .. " arena is contested")
				check(grug_core.ground_effect_protected(p, "a") == false and
					grug_core.ground_effect_protected(p, "t") == false,
					row.key .. " dragon effects allowed in the core")
				check(grug_core.ground_effect_protected(p, "n") == true and
					grug_core.ground_effect_protected(p, "") == true,
					row.key .. " no faction or no actor: closed")
				dragons = dragons + 1
			end
		end
	end
	check(dragons == 6, "both dragon arenas checked")
	check(grug_core.ground_effect_protected(start, "a") and
		grug_core.ground_effect_protected(start, "t"), "start town closed to dragon effects")
	do
		local pos = found["road:accord_home"]
		check(grug_core.ground_effect_protected(pos, "a") == false,
			"home road open to effects for its faction (as before the road layer)")
		check(grug_core.ground_effect_protected(pos, "t") == true,
			"home road closed to effects for the other faction")
	end
	-- world_protected_for_faction = zone rule OR road/POI layer, everywhere.
	for key, pos in pairs(found) do
		for _, f in ipairs({"accord", "throng"}) do
			check(grug_core.world_protected_for_faction(pos, f) ==
				(grug_core.zone_protected_for_faction(pos, f) or
					grug_core.world_feature_at(pos) ~= nil), key .. " OR for " .. f)
		end
	end

	-- Claim distance query (ruling 27): x/z rectangles against the cores
	-- widened by a margin, against a brute-force scan.
	local function brute_in(x0, z0, x1, z1, margin)
		for _, b in ipairs(boxes) do
			if b.min_x - margin <= x1 and b.max_x + margin >= x0 and
					b.min_z - margin <= z1 and b.max_z + margin >= z0 then return true end
		end
		return false
	end
	local claim_hits = 0
	for _, b in ipairs(boxes) do
		local mz = floor((b.min_z + b.max_z) / 2)
		-- a 101 x 101 square whose west edge lies 16 / 17 east of the core
		for _, gap in ipairs({16, 17}) do
			local x0 = b.max_x + gap
			local got, kind = grug_core.world_feature_boxes_in(x0, mz - 50, x0 + 100, mz + 50, 16)
			check(got == brute_in(x0, mz - 50, x0 + 100, mz + 50, 16), "claim query east")
			if gap == 16 then check(got == true and kind ~= nil, "claim query touches at 16") end
		end
		local z1 = b.min_z - 17
		check(grug_core.world_feature_boxes_in(b.min_x, z1 - 100, b.min_x + 100, z1, 16) ==
			brute_in(b.min_x, z1 - 100, b.min_x + 100, z1, 16), "claim query south")
	end
	for _ = 1, 2000 do
		local x0, z0 = -3740 + random(7381), -3340 + random(6581)
		local got = grug_core.world_feature_boxes_in(x0, z0, x0 + 100, z0 + 100, 16)
		check(got == brute_in(x0, z0, x0 + 100, z0 + 100, 16), "claim query random")
		if got then claim_hits = claim_hits + 1 end
	end
	print(("  dragons: %d arena core points open to effects; claim query: 2000 random " ..
		"squares, %d touch a core (+16)"):format(dragons, claim_hits))
	local cases = {}
	for key in pairs(found) do cases[#cases + 1] = key end
	table.sort(cases)
	check(found["bridge:accord_home"] or found["bridge:throng_home"] or
		found["bridge:contested_land"], "a bridge outside the towns")
	print(("  grug_core: cases %s; %d hint scenarios"):format(
		table.concat(cases, ", "), tested))
	_G.grug_zones = nil
	_G.grug_core = nil
end

for _, seed in ipairs(seeds) do run_seed(seed) end
print(("R25 ROAD POI FIXTURE PASS checks=%d"):format(checks))
