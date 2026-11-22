-- Round 85 WORLD: the arena "Breach Road" on one seed, measured on the real
-- world plan (world_assembly.lua as main builds it, LuaJIT, no engine; the
-- capitals stood in by squares: the network roads are routed before the
-- capital planner, so the middle road is the game's).
--
--   luajit tools/r85_world/site.lua <repo> <seed> <outdir> [half]
--
-- Writes into <outdir>:
--   site.tsv     the site, its datum, reach, the search's stats, the numbers
--                of the site and of the centre (0, 0) as a site (offset,
--                relief and earth under the hull, the largest blend step,
--                water columns, the road's crossing of z = 0) and the
--                checks (footprint dry and flat, the road through both
--                mouths at the datum, the blend's grade, the zone border)
--   centre.tsv   every column within <half> (default 320) of (0, 0): x, z,
--                natural y, final y, zone index, water code, road code
--                (0 none, 1 surface, 2 other road column), whether the
--                arena graded it (0 no, 1 hull, 2 blend)
--   roads.tsv    every road centreline point (id, kind, a, b, x, z, y)
-- Prints one line "OK <seed> ..." or "FAIL <seed> <what>"; exits non-zero on
-- a failed check.
local repo, seed, out = arg[1], arg[2], arg[3]
local HALF = tonumber(arg[4] or 320)
assert(repo and seed and out, "usage: site.lua <repo> <seed> <outdir> [half]")
_G.core = _G.core or {}
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local t0 = os.clock()
local A = dofile(dir .. "/world_assembly.lua")(dir, sha)
-- R85_WORLD_P="KEY=value,..." overrides breach_site.lua's parameters (tuning)
for key, value in (os.getenv("R85_WORLD_P") or ""):gmatch("([%w_]+)=([%d%.]+)") do
	A.breach.P[key] = tonumber(value)
end
-- every finalist the search measured (R85_WORLD_TRACE=1: printed)
local search = A.breach.search
A.breach.search = function(q)
	if os.getenv("R85_WORLD_TRACE") then
		q.trace = function(x, z, score, earth, reach, detour, face)
			print(("finalist %d,%d score %.2f earth %.2f reach %.1f detour %.0f face %.2f"):format(x,
				z, score, earth, reach, detour, face))
		end
	end
	return search(q)
end
local W = A.world(seed, nil, {protection = A.square_cities(120), keep_placement_session = true})
-- R85_WORLD_ROAD_P="KEY=value,..." overrides road_layout.lua's parameters
for key, value in (os.getenv("R85_WORLD_ROAD_P") or ""):gmatch("([%w_]+)=([%d%.]+)") do
	W.roads.module.P[key] = tonumber(value)
end
local source = W.place()
local t_place = os.clock() - t0
local site = source.breach
local L = A.breach.layout
local hs = W.horizontal_factory({source = source, schemas = A.schemas, canonical = A.canonical,
	deterministic = A.deterministic, raw_sha256 = sha}).new(seed)
local hh = W.height_factory({source = source, canonical = A.canonical,
	deterministic = A.deterministic, raw_sha256 = sha, horizontal_session = hs,
	terrain_field = A.terrain_field}).new_runtime(seed)
local t_world = os.clock() - t0
local nat = W.placement_session.height
local zi = {}
for i, z in ipairs(A.source.zones) do zi[z.id] = i end
local function zone_of(x, z)
	local class, _, owner = hs.classification_values_at(x, z)
	if class ~= "land" then return 0 end
	return type(owner) == "number" and owner or zi[owner] or 0
end
local WCODE = {river = 2, lake = 1}
local function water_code(x, z)
	local class = hs.classification_values_at(x, z)
	if class ~= "land" then return 9 end
	local kind = hh.inland_water_at(x, z)
	return kind and (WCODE[kind] or 3) or 0
end
local profile = A.breach.profile(site, nat.natural_height_at)

local failures = {}
local function check(ok, what) if not ok then failures[#failures + 1] = what end end

-- The footprint (the hull, levelled): flat at the datum, dry, both zones.
local hull_cols, hull_wet, hull_off, zones_seen = 0, 0, 0, {}
local lo, hi = math.huge, -math.huge
for lz = -L.HALF_Z, L.HALF_Z do
	for lx = -L.HALF_X, L.HALF_X do
		if L.in_hull(lx, lz) then
			local x, z = site.x + lx, site.z + lz
			hull_cols = hull_cols + 1
			if water_code(x, z) ~= 0 then hull_wet = hull_wet + 1 end
			if hh.terrain_height_at(x, z) ~= site.y and
					hh.road_column_at(x, z) ~= "surface" then
				hull_off = hull_off + 1
			end
			local n = nat.natural_height_at(x, z)
			lo, hi = min(lo, n), max(hi, n)
			zones_seen[zone_of(x, z)] = true
		end
	end
end
check(hull_wet == 0, "water in the footprint: " .. hull_wet)
check(hull_off == 0, "footprint columns off the datum: " .. hull_off)

-- The blend: the arena adds at most LIMIT (`breach_site.lua`) to the
-- natural grade over a 4-node baseline, in x and z, across the zone border
-- too, on the columns it reaches; no water where it grades.
local G = A.breach.P.GRADE
local reach = site.reach
local worst, worst_at, border_pairs, blend_wet, graded = 0, "", 0, 0, 0
local steepest_final, steepest_nat = 0, 0
local function final_at(x, z) return hh.terrain_height_at(x, z) end
-- (pairs from every column, the hull's included: the step across the
-- hull's edge counts on all four sides)
for lz = -L.HALF_Z - reach - 8, L.HALF_Z + reach + 4 do
	for lx = -L.HALF_X - reach - 8, L.HALF_X + reach + 4 do
		local x, z = site.x + lx, site.z + lz
		local d = L.hull_project(lx, lz)
		do
			local n0, f0 = nat.natural_height_at(x, z), final_at(x, z)
			-- the columns the arena reaches (another fitting's may lie near)
			local a0 = A.breach.ground(profile, x, z, n0, nat.natural_height_at) ~= nil
			if a0 and n0 ~= f0 and d > 0 then
				graded = graded + 1
				if water_code(x, z) ~= 0 then blend_wet = blend_wet + 1 end
			end
			for _, o in ipairs({{4, 0}, {0, 4}}) do
				local x2, z2 = x + o[1], z + o[2]
				local n1, f1 = nat.natural_height_at(x2, z2), final_at(x2, z2)
				if a0 or A.breach.ground(profile, x2, z2, n1, nat.natural_height_at) ~= nil then
					-- road columns follow their own profile (cut and fill)
					if hh.road_column_at(x, z) == nil and hh.road_column_at(x2, z2) == nil then
						local excess = (abs(f1 - f0) - abs(n1 - n0)) / 4
						if excess > worst then
							worst, worst_at = excess, ("%d,%d"):format(x, z)
						end
						steepest_final = max(steepest_final, abs(f1 - f0) / 4)
						steepest_nat = max(steepest_nat, abs(n1 - n0) / 4)
						if zone_of(x, z) ~= zone_of(x2, z2) then border_pairs = border_pairs + 1 end
					end
				end
			end
		end
	end
end
check(worst <= A.breach.P.LIMIT, ("blend grade excess %.2f at %s"):format(worst, worst_at))
check(blend_wet == 0, "water in the blend: " .. blend_wet)

-- The road: the inner road straight at the datum between the mouths, a leg
-- from each mouth to its capital, the mouths road surface at the datum.
local roads_module = dofile(dir .. "/road_layout.lua")
local layout = roads_module.deserialize(hh.road_layout_text())
local inner, legs = nil, {}
local world = L.world(site)
for _, r in pairs(layout.roads) do
	if r.a == "breach_south" and r.b == "breach_north" then inner = r end
	if r.a == "breach_north" or (r.a == "breach_south" and r.b ~= "breach_north") then
		legs[r.a] = r
	end
end
check(inner ~= nil, "no inner road")
if inner then
	local ok = abs(inner.X[1] - world.road.x) < 1e-9 and abs(inner.Z[1] - world.road.min_z) < 1e-9 and
		abs(inner.X[#inner.X] - world.road.x) < 1e-9 and abs(inner.Z[#inner.Z] - world.road.max_z) < 1e-9
	for i = 1, #inner.X do
		if abs(inner.X[i] - world.road.x) > 1e-9 or inner.R[i] ~= site.y then ok = false end
	end
	check(ok, "the inner road is not straight at the datum")
end
for _, m in ipairs(world.mouths) do
	local leg = legs["breach_" .. m.id]
	check(leg ~= nil, "no leg from the " .. m.id .. " mouth")
	if leg then
		-- (the road's lateral wiggle, tapered at its ends, leaves a hundredth)
		check(abs(leg.X[1] - m.x) < 0.25 and abs(leg.Z[1] - m.z) < 0.25 and leg.R[1] == site.y,
			"the " .. m.id .. " leg does not start on its mouth at the datum")
		check(leg.b:match("^anchor_") ~= nil, "the " .. m.id .. " leg ends at " .. tostring(leg.b))
	end
	check(hh.road_column_at(m.x, m.z) == "surface" and final_at(m.x, m.z) == site.y,
		"the " .. m.id .. " mouth is no road surface at the datum")
end

-- The middle road's crossing of z = 0 (the x nearest 0 of its points there).
local crossing
for _, r in pairs(layout.roads) do
	if r.kind == "primary" and (r.a:match("^breach_") or r.b:match("^breach_")) then
		for i = 2, #r.Z do
			if (r.Z[i - 1] <= 0) ~= (r.Z[i] <= 0) then
				if not crossing or abs(r.X[i]) < abs(crossing) then crossing = r.X[i] end
			end
		end
	end
end

-- The centre (0, 0) as if it were the site: what the search saved.
local function measure(cx, cz)
	local values, wet, zone_ok = {}, 0, true
	for lz = -L.HALF_Z, L.HALF_Z, 2 do
		for lx = -L.HALF_X, L.HALF_X, 2 do
			if L.in_hull(lx, lz) then
				values[#values + 1] = nat.natural_height_at(cx + lx, cz + lz)
				if water_code(cx + lx, cz + lz) ~= 0 then wet = wet + 1 end
			end
		end
	end
	table.sort(values)
	local datum = values[floor((#values + 1) / 2)]
	local earth = 0
	for _, v in ipairs(values) do earth = earth + abs(v - datum) end
	local p = A.breach.profile({x = cx, z = cz, y = datum}, nat.natural_height_at)
	local dmax = 0
	for _, d in ipairs(p.delta) do dmax = max(dmax, abs(d)) end
	return {datum = datum, relief = values[#values] - values[1], earth = earth / #values,
		reach = p.reach, step = dmax, wet = wet * 4, zone = zone_ok,
		face = A.breach.face(p, nat.natural_height_at)}
end
local chosen, centre = measure(site.x, site.z), measure(0, 0)
-- R85_WORLD_OLD="x,z": an earlier site measured the same way (comparisons)
local old_x, old_z = (os.getenv("R85_WORLD_OLD") or ""):match("^(%-?%d+),(%-?%d+)$")
local old = old_x and measure(tonumber(old_x), tonumber(old_z))

-- The pictures' raster.
local f = assert(io.open(out .. "/centre.tsv", "w"))
for z = -HALF, HALF do
	local buf = {}
	for x = -HALF, HALF do
		local road = hh.road_column_at(x, z)
		local d = L.hull_project(x - site.x, z - site.z)
		local g = d == 0 and 1 or (A.breach.ground(profile, x, z, 0, nat.natural_height_at) and 2 or 0)
		buf[#buf + 1] = x .. "\t" .. z .. "\t" .. nat.natural_height_at(x, z) .. "\t" ..
			final_at(x, z) .. "\t" .. zone_of(x, z) .. "\t" .. water_code(x, z) .. "\t" ..
			(road == "surface" and 1 or road and 2 or 0) .. "\t" .. g
	end
	f:write(table.concat(buf, "\n"), "\n")
end
f:close()
f = assert(io.open(out .. "/roads.tsv", "w"))
local ids = {}
for id in pairs(layout.roads) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
	local r = layout.roads[id]
	for i = 1, #r.X do
		f:write(r.id, "\t", r.kind, "\t", r.a, "\t", r.b, "\t", ("%.2f\t%.2f\t%.2f"):format(r.X[i],
			r.Z[i], r.R[i]), "\n")
	end
end
f:close()

local zones = {}
for k in pairs(zones_seen) do zones[#zones + 1] = k end
table.sort(zones)
local st = W.placement_stats.breach
f = assert(io.open(out .. "/site.tsv", "w"))
local function row(k, v) f:write(k, "\t", tostring(v), "\n") end
row("seed", seed)
row("x", site.x) row("z", site.z) row("datum", site.y) row("reach", site.reach)
row("offset", ("%.1f"):format(math.sqrt(site.x * site.x + site.z * site.z)))
row("zones", table.concat(zones, ","))
row("search_seconds", ("%.3f"):format(st.seconds))
row("search_candidates", st.candidates) row("search_finalists", st.finalists)
row("search_wet", tostring(st.wet or false))
row("search_fallback", tostring(st.fallback or false))
row("search_need", ("%.1f"):format(st.need or 0))
row("score", ("%.3f"):format(st.score or -1))
row("site_detour", ("%.0f"):format(st.detour)) row("centre_detour", ("%.0f"):format(st.centre_detour))
for _, pair in ipairs({{"site", chosen}, {"centre", centre}, {"old", old}}) do
	local name, m = pair[1], pair[2]
	if m then
	row(name .. "_relief", m.relief) row(name .. "_earth", ("%.2f"):format(m.earth))
	row(name .. "_step", ("%.1f"):format(m.step)) row(name .. "_reach", ("%.1f"):format(m.reach))
	row(name .. "_wet", m.wet) row(name .. "_datum", m.datum)
	row(name .. "_face", ("%.2f"):format(m.face))
	end
end
row("hull_columns", hull_cols) row("graded_blend_columns", graded)
row("grade_excess_max", ("%.2f"):format(worst))
row("grade_final_max", ("%.2f"):format(steepest_final))
row("grade_natural_max", ("%.2f"):format(steepest_nat))
row("border_pairs", border_pairs)
row("road_crossing_x", crossing and ("%.1f"):format(crossing) or "none")
row("place_seconds", ("%.1f"):format(t_place)) row("world_seconds", ("%.1f"):format(t_world))
row("failures", #failures == 0 and "none" or table.concat(failures, "; "))
f:close()
if #failures > 0 then
	print("FAIL", seed, table.concat(failures, "; "))
	error("seed " .. seed .. ": checks failed", 0)
end
print("OK", seed, ("site %d,%d datum %d reach %d excess %.2f crossing %s place %.1f s world %.1f s")
	:format(site.x, site.z, site.y, site.reach, worst, tostring(crossing), t_place, t_world))
