-- Round 85 lane WORLD portable test (LuaJIT): the arena "Breach Road" as a
-- rule of world generation (`wp40/breach_layout.lua`, `wp40/breach_site.lua`,
-- the placement's site line, the levelling in `height.lua`, the middle road
-- through both mouths in `road_layout.lua`).
--
--   luajit tools/r85_world/portable_test.lua [REPO]
--
-- L  the layout: the footprint polygon (its column count pinned, point
--    symmetric), its bounds 99 x 91, the hull its convex hull holding every
--    footprint column, the hull's projection (0 inside, continuous outside),
--    both halls mirrored with the waystone, arrival and muster inside the
--    room's columns, the site line round-trips, `world` in world nodes.
-- S  the search on constructed natural worlds (no engine): a flat world
--    takes (0, 0); a lake at the centre is avoided with its margin; on a
--    tilted plane the datum is the hull's lower median; a hill at the centre
--    with flat ground beside it takes the flat ground; a world wet
--    everywhere still answers, flagged wet; the same answer twice.
-- G  the ground on a constructed rough slope: the hull at the datum, the
--    blend meeting it within a node at the hull, nil beyond the reach, and
--    the levelling adding at most GRADE + 0.25 to the grade (4-node
--    baseline, both axes).
-- W  the real world of seed 12345 (world_assembly.lua as main builds it,
--    the capitals stood in by squares): the placement text's last line is
--    the site, parsed back by the layout and refused when missing; the hull
--    is dry and at the datum (a road surface column at the road's level);
--    the inner road straight at the datum, a leg from each mouth to its
--    capital starting on the mouth at the datum; a world built from main's
--    placement and water texts (emerge's way) levels the same ground.
-- Prints "R85 WORLD PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local L = dofile(dir .. "/breach_layout.lua")
local B = dofile(dir .. "/breach_site.lua")(L)

-- L
do
	local count, outside_hull = 0, 0
	local minx, maxx, minz, maxz = 0, 0, 0, 0
	for lz = -60, 60 do
		for lx = -60, 60 do
			if L.inside(lx, lz) then
				count = count + 1
				minx, maxx = min(minx, lx), max(maxx, lx)
				minz, maxz = min(minz, lz), max(maxz, lz)
				if not L.in_hull(lx, lz) then outside_hull = outside_hull + 1 end
			end
			-- the polygon is point-symmetric (the west wing turned 180 degrees)
			check(L.inside(lx, lz) == L.inside(-lx, -lz), "L point symmetry " .. lx .. "," .. lz)
		end
	end
	check(count == 6907, "L the footprint holds 6907 columns (" .. count .. ")")
	check(minx == -49 and maxx == 49 and minz == -45 and maxz == 45, "L the footprint is 99 x 91")
	check(outside_hull == 0, "L the hull holds the footprint")
	-- convex, counter-clockwise, every polygon vertex inside or on it
	local n = #L.HULL
	for i = 1, n do
		local a, b, c = L.HULL[i], L.HULL[i % n + 1], L.HULL[(i + 1) % n + 1]
		check((b[1] - a[1]) * (c[2] - b[2]) - (b[2] - a[2]) * (c[1] - b[1]) > 0, "L hull convex at " .. i)
	end
	for _, p in ipairs(L.POLYGON) do check(L.in_hull(p[1], p[2]), "L polygon vertex in the hull") end
	check(L.hull_project(0, 0) == 0 and L.hull_project(49, 0) == 0, "L projection 0 inside and on")
	local d, s = L.hull_project(59, 0)
	check(abs(d - 10) < 1e-9 and s > 0 and s < L.PERIMETER, "L projection outside the east edge")
	-- continuous outside: neighbouring columns differ by at most one node of
	-- distance and their nearest points by a little arc
	local worst = 0
	for lz = -80, 80, 3 do
		for lx = -90, 90, 3 do
			local d1 = L.hull_project(lx, lz)
			local d2 = L.hull_project(lx + 1, lz)
			worst = max(worst, abs(d1 - d2))
		end
	end
	check(worst <= 1 + 1e-9, "L the distance is 1-Lipschitz")
	local px, pz = L.hull_point(0)
	check(px == L.HULL[1][1] and pz == L.HULL[1][2], "L the arc starts at the first vertex")
	for _, faction in ipairs({"accord", "throng"}) do
		local h = L.HALLS[faction]
		for _, key in ipairs({"waystone", "arrival", "muster"}) do
			local p = h[key]
			check(p.x >= h.interior.min.x and p.x <= h.interior.max.x and p.z >= h.interior.min.z and
				p.z <= h.interior.max.z and p.y == h.floor_y + 1, "L " .. faction .. " " .. key .. " in the room")
			check(L.inside(p.x, p.z), "L " .. faction .. " " .. key .. " on the footprint")
		end
	end
	check(L.HALLS.accord.waystone.x == 38 and L.HALLS.throng.waystone.x == -38 and
		L.HALLS.accord.interior.min.x == 31 and L.HALLS.throng.interior.max.x == -31,
		"L the Accord's hall east, the Throng's west, mirrored")
	local site = {x = -72, z = 8, y = 55, reach = 29}
	local line = L.format(site)
	check(line == "breach -72 8 55 29", "L the site line")
	local back = L.parse(line)
	check(back.x == -72 and back.z == 8 and back.y == 55 and back.reach == 29, "L the line parses")
	check(L.parse("breach 1 2 3") == nil and L.parse("anchor_001 1 2 3") == nil, "L a bad line is refused")
	check(L.from_placement("P2 0\n" .. line .. "\n").x == -72, "L the site of a placement text")
	check(not pcall(L.from_placement, "P2 0\n"), "L a text without the line is refused")
	local w = L.world(site)
	check(w.datum == 55 and w.footprint.min.x == -121 and w.footprint.max.z == 53 and
		w.protected.min.y == 45 and w.protected.max.y == 55 + L.BOX_ABOVE and
		w.fringe.min.x == -121 - 29, "L the world boxes")
	check(w.mouths[1].id == "north" and w.mouths[1].z == 53 and w.mouths[2].z == -37 and
		w.road.min_z == -37 and w.road.max_z == 53 and w.road.x == -72, "L the mouths and the road")
	check(w.halls.accord.waystone.x == -34 and w.halls.accord.waystone.y == 62 and
		w.halls.throng.interior.min.y == 62, "L the halls in world nodes")
	check(w.inside(-72, 8) and not w.inside(-72 + 49, 8 + 45), "L world columns")
end

-- S: constructed natural worlds
local ZONES = {front_broken_causeway = 35, front_shattered_line = 36}
local function query(height, wet)
	return {
		natural_at = function(x, z) return floor(height(x, z)) end,
		wet = function(x, z) return wet and wet(x, z) or false end,
		zone_at = function(x, z) return x < 0 and 35 or 36 end,
		zone_number = function(id) return ZONES[id] end,
	}
end
do
	local site, stats = B.search(query(function() return 50 end))
	check(site.x == 0 and site.z == 0 and site.y == 50 and not stats.wet, "S a flat world takes (0, 0)")
	check(site.reach == B.P.WIDTH_MIN, "S ... with the narrowest blend")
	local lake = function(x, z) return x * x + z * z < 30 * 30 end
	site = B.search(query(function() return 50 end, lake))
	local d = L.hull_project(0 - site.x, 0 - site.z)
	check(d > 30 + B.P.DRY - 1, "S a lake at the centre is avoided (" .. site.x .. "," .. site.z .. ")")
	site = B.search(query(function(x) return 40 + x * 0.25 end))
	local values = {}
	for lz = -45, 45, 4 do
		for lx = -49, 49, 4 do
			if L.in_hull(lx, lz) then values[#values + 1] = floor(40 + (site.x + lx) * 0.25) end
		end
	end
	table.sort(values)
	check(site.y == values[floor((#values + 1) / 2)], "S the datum is the hull's lower median")
	local hill = function(x, z)
		local r2 = x * x + z * z
		return 40 + 60 * math.exp(-r2 / (60 * 60))
	end
	site = B.search(query(hill))
	check(math.sqrt(site.x * site.x + site.z * site.z) > 80, "S a hill at the centre: the flat beside it")
	local again = B.search(query(hill))
	check(again.x == site.x and again.z == site.z and again.y == site.y and again.reach == site.reach,
		"S the same answer twice")
	site, stats = B.search(query(function() return 50 end, function() return true end))
	check(site and stats.wet == true, "S a world wet everywhere answers, flagged")
end

-- G: the ground on a rough slope
do
	local function natural(x, z)
		return floor(60 + x * 0.3 - z * 0.15 + 4 * math.sin(x * 0.13) * math.cos(z * 0.11))
	end
	local site = {x = 0, z = 0, y = 60}
	local profile = B.profile(site, natural)
	local function ground(x, z)
		local v = B.ground(profile, x, z, natural(x, z), natural)
		return v or natural(x, z)
	end
	local worst, edge, beyond = 0, 0, true
	local r = math.ceil(profile.reach)
	for lz = -45 - r - 6, 45 + r + 6 do
		for lx = -49 - r - 6, 49 + r + 6 do
			local d = L.hull_project(lx, lz)
			if d == 0 then
				check(ground(lx, lz) == 60, "G the hull at the datum")
			else
				if d <= 1.5 then edge = max(edge, abs(ground(lx, lz) - 60)) end
				if d >= profile.reach and B.ground(profile, lx, lz, 0, natural) ~= nil then beyond = false end
				for _, o in ipairs({{4, 0}, {0, 4}}) do
					local x2, z2 = lx + o[1], lz + o[2]
					local excess = (abs(ground(x2, z2) - ground(lx, lz)) -
						abs(natural(x2, z2) - natural(lx, lz))) / 4
					worst = max(worst, excess)
				end
			end
		end
	end
	check(edge <= 2, "G the blend meets the datum at the hull (" .. edge .. ")")
	check(beyond, "G nothing beyond the reach")
	check(worst <= B.P.GRADE + 0.25, ("G the levelling adds at most %.2f to the grade (%.2f)")
		:format(B.P.GRADE + 0.25, worst))
end

-- W: the real world of one seed
do
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local A = dofile(dir .. "/world_assembly.lua")(dir, sha)
	local SEED = "12345"
	local W = A.world(SEED, nil, {protection = A.square_cities(120)})
	local source = W.place()
	local text = W.placement_text
	local site = source.breach
	check(text:match("\n(breach [^\n]+)\n$") == L.format(site), "W the text's last line is the site")
	check(text:match("^P2 %d+\n") ~= nil, "W the text's header")
	local parsed = L.from_placement(text)
	check(parsed.x == site.x and parsed.z == site.z and parsed.y == site.y and parsed.reach == site.reach,
		"W the layout reads the site from the text")
	check(not pcall(A.placement.parse, text:gsub("breach [^\n]+\n$", ""), A.source),
		"W a text without the site is refused")
	check(site.x * site.x + site.z * site.z <= B.P.WINDOW * B.P.WINDOW, "W the site in the window")
	local hs = W.horizontal_factory({source = source, schemas = A.schemas, canonical = A.canonical,
		deterministic = A.deterministic, raw_sha256 = sha}).new(SEED)
	local hh = W.height_factory({source = source, canonical = A.canonical,
		deterministic = A.deterministic, raw_sha256 = sha, horizontal_session = hs,
		terrain_field = A.terrain_field}).new_runtime(SEED)
	local world = L.world(site)
	local flat, dry = true, true
	for lz = -45, 45 do
		for lx = -49, 49 do
			if L.in_hull(lx, lz) then
				local x, z = site.x + lx, site.z + lz
				if hh.terrain_height_at(x, z) ~= site.y then flat = false end
				if hh.inland_water_at(x, z) ~= nil or hs.classification_values_at(x, z) ~= "land" then
					dry = false
				end
			end
		end
	end
	check(flat, "W the hull at the datum")
	check(dry, "W the hull dry land")
	local layout = dofile(dir .. "/road_layout.lua").deserialize(hh.road_layout_text())
	local inner, legs = nil, {}
	for _, r in pairs(layout.roads) do
		if r.a == "breach_south" and r.b == "breach_north" then inner = r
		elseif r.a == "breach_south" or r.a == "breach_north" then legs[r.a] = r end
	end
	check(inner and #inner.X == 91, "W the inner road, mouth to mouth")
	local straight = true
	for i = 1, #inner.X do
		if inner.X[i] ~= site.x or inner.Z[i] ~= site.z - 45 + i - 1 or inner.R[i] ~= site.y then
			straight = false
		end
	end
	check(straight, "W the inner road straight at the datum")
	local capital = {}
	for _, a in ipairs(source.anchors) do
		if a.slot_id == "capital" then capital[source.zones[a.zone_numeric_id].id] = a.id end
	end
	for _, m in ipairs(world.mouths) do
		local leg = legs["breach_" .. m.id]
		check(leg ~= nil, "W a leg from the " .. m.id .. " mouth")
		check(abs(leg.X[1] - m.x) < 0.25 and leg.Z[1] == m.z and leg.R[1] == site.y,
			"W the " .. m.id .. " leg starts on its mouth at the datum")
		local held = true
		for i = 1, 20 do if abs(leg.X[i] - m.x) > 0.25 then held = false end end
		check(held, "W the " .. m.id .. " leg leaves straight along the axis (" ..
			table.concat({leg.X[1], leg.X[8], leg.X[16]}, " ") .. ")")
		check(leg.b == capital[m.id == "north" and "kragmar_gor_drazhak" or "elandor_highcourt"],
			"W the " .. m.id .. " leg reaches its capital")
		check(hh.road_column_at(m.x, m.z) == "surface" and hh.terrain_height_at(m.x, m.z) == site.y,
			"W the " .. m.id .. " mouth is road at the datum")
	end
	-- emerge's way: a world from main's placement and water texts
	local W2 = A.world(SEED, {placement = text, water = hh.water_layout_text()},
		{roads = false, protection = A.square_cities(120)})
	local source2 = W2.place()
	check(source2.breach.x == site.x and source2.breach.y == site.y, "W the parsed world's site")
	local hs2 = W2.horizontal_factory({source = source2, schemas = A.schemas, canonical = A.canonical,
		deterministic = A.deterministic, raw_sha256 = sha}).new(SEED)
	local hh2 = W2.height_factory({source = source2, canonical = A.canonical,
		deterministic = A.deterministic, raw_sha256 = sha, horizontal_session = hs2,
		terrain_field = A.terrain_field}).new_runtime(SEED)
	local same, compared = true, 0
	local r = site.reach + 4
	for lz = -45 - r, 45 + r, 3 do
		for lx = -49 - r, 49 + r, 3 do
			local x, z = site.x + lx, site.z + lz
			if hh.road_column_at(x, z) == nil then
				compared = compared + 1
				if hh.terrain_height_at(x, z) ~= hh2.terrain_height_at(x, z) then same = false end
			end
		end
	end
	check(same and compared > 1000, "W emerge levels the same ground (" .. compared .. " columns)")
end

print(("R85 WORLD PORTABLE PASS checks=%d"):format(checks))
