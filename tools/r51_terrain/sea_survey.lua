-- Round 51 TERRAIN T2: a survey of the sea's shape on one seed (numbers for
-- the report; comparisons, not targets).
--
--   luajit tools/r51_terrain/sea_survey.lua REPO SEED
--
-- Builds the real runtime of SEED from REPO (tools/seed_fleet/runtime.lua)
-- and prints:
--   * bay rims: per bay, the open-sea columns within 32 nodes of the bay's
--     water and within 128 nodes of land (the rim; the open sea the bay's
--     mouth opens onto lies farther out), every 4 nodes. Works on a checkout
--     before T2 too (the "before" count); everything below needs T2's water
--     query and is skipped without it.
--   * the belt's width: the coast distance of the open-sea columns bordering
--     the belt or a bay (every 8 nodes), as percentiles;
--   * the depth profile: the median depth of belt and bay water by coast
--     distance;
--   * the wreck band: belt and bay seabed 8-14 nodes deep in protected water
--     (km2 in all and per owning zone), and the seabed brightness: the share
--     of the belt's seabed at most 12 deep;
--   * protection: water columns by class, protected or not;
--   * the channels: depth of channel water 24+ off the coast (min, max, share
--     at 9-11), the depth along each boat path, and a boat's path from the
--     mainland end to the island landing over water at least 9 deep.
local repo, seed = arg[1], arg[2]
assert(repo and seed, "usage: sea_survey.lua REPO SEED")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local W = source.world_bounds
local floor, abs, sqrt = math.floor, math.abs, math.sqrt
print(("seed %s"):format(seed))

-- Bay rims.
for _, bay in ipairs(source.bays) do
	local xs, zs = {}, {}
	for _, p in ipairs(bay.centreline) do xs[#xs + 1], zs[#zs + 1] = p.x, p.z end
	local cx = (math.min(unpack(xs)) + math.max(unpack(xs))) / 2
	local sign = bay.deep_ocean_side == "min_z" and -1 or 1
	local specks, bay_columns = 0, 0
	local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}
	local function near(x, z, wanted, reach, step)
		for d = step, reach, step do
			for _, o in ipairs(DIRS) do
				if S.water_class_at(x + o[1] * d, z + o[2] * d) == wanted then return true end
			end
		end
		return false
	end
	for z = 1800, 3300, 4 do
		for x = floor(cx) - 1100, floor(cx) + 1100, 4 do
			local wz = sign * z
			local class = S.water_class_at(x, wz)
			if class == "planned_water" and S.water_query_at and
					S.water_query_at(x, wz) == "bay" then
				bay_columns = bay_columns + 1
			end
			if class == "deep_ocean" and near(x, wz, "planned_water", 32, 8) and
					near(x, wz, "land", 128, 16) then
				specks = specks + 1
			end
		end
	end
	print(("bay %-18s rim open-sea columns (every 4 nodes): %d%s"):format(bay.id, specks,
		S.water_query_at and (", bay columns %d"):format(bay_columns) or ""))
end
if not S.water_query_at then
	print("(no water query: a checkout before T2; the rest is skipped)")
	return
end

-- One pass over the world every 8 nodes.
local STEP = 8
local edge, profile, protected = {}, {}, {}
local band_total, band_by_zone, belt_floor, belt_lit = 0, {}, 0, 0
local function percentile(list, p)
	if #list == 0 then return 0 end
	return list[math.max(1, math.min(#list, floor(#list * p + 0.5)))]
end
for z = W.min_z, W.max_z, STEP do
	for x = W.min_x, W.max_x, STEP do
		local class, zone, _, distance, depth, prot = S.water_query_at(x, z)
		if class and class ~= "lake" and class ~= "river" then
			local key = class .. (prot and " protected" or " shore")
			protected[key] = (protected[key] or 0) + 1
			if class == "open_sea" then
				for _, o in ipairs({{STEP, 0}, {-STEP, 0}, {0, STEP}, {0, -STEP}}) do
					local c2 = S.water_query_at(x + o[1], z + o[2])
					if c2 == "belt" or c2 == "bay" then
						edge[#edge + 1] = distance
						break
					end
				end
			elseif class == "belt" or class == "bay" then
				local bucket = floor(distance / 25)
				local list = profile[bucket] or {}
				list[#list + 1] = depth
				profile[bucket] = list
				if prot and depth >= 8 and depth <= 14 then
					band_total = band_total + 1
					band_by_zone[zone] = (band_by_zone[zone] or 0) + 1
				end
				if class == "belt" then
					belt_floor = belt_floor + 1
					if depth <= 12 then belt_lit = belt_lit + 1 end
				end
			end
		end
	end
end
table.sort(edge)
print(("belt width (coast distance where the open sea begins): n %d, p5 %.0f, p25 %.0f, " ..
	"median %.0f, p75 %.0f, p95 %.0f"):format(#edge, percentile(edge, 0.05),
	percentile(edge, 0.25), percentile(edge, 0.5), percentile(edge, 0.75), percentile(edge, 0.95)))
local parts = {}
for bucket = 0, 20 do
	local list = profile[bucket]
	if list then
		table.sort(list)
		parts[#parts + 1] = ("%d-%d:%d"):format(bucket * 25, bucket * 25 + 25, percentile(list, 0.5))
	end
end
print("belt and bay median depth by coast distance: " .. table.concat(parts, " "))
local km2 = STEP * STEP / 1e6
local zones_list = {}
for zone, n in pairs(band_by_zone) do zones_list[#zones_list + 1] = {zone, n} end
table.sort(zones_list, function(a, b) return a[2] > b[2] end)
local zparts = {}
for index, row in ipairs(zones_list) do
	if index <= 40 then zparts[#zparts + 1] = ("%s %.2f"):format(row[1], row[2] * km2) end
end
print(("wreck band (protected belt and bay seabed 8-14 deep): %.1f km2 in %d zones; " ..
	"per zone km2: %s"):format(band_total * km2, #zones_list, table.concat(zparts, ", ")))
print(("belt seabed at most 12 deep: %.0f %%"):format(100 * belt_lit / math.max(1, belt_floor)))
local keys = {}
for key in pairs(protected) do keys[#keys + 1] = key end
table.sort(keys)
local pparts = {}
for _, key in ipairs(keys) do pparts[#pparts + 1] = ("%s %d"):format(key, protected[key]) end
print("water columns (every 8 nodes): " .. table.concat(pparts, ", "))

-- The channels.
for _, channel in ipairs(source.channels) do
	local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(channel.polygon) do
		min_x, max_x = math.min(min_x, p.x), math.max(max_x, p.x)
		min_z, max_z = math.min(min_z, p.z), math.max(max_z, p.z)
	end
	local lo, hi, n, in_band = math.huge, -math.huge, 0, 0
	for z = min_z - 120, max_z + 120, 2 do
		for x = min_x - 120, max_x + 120, 2 do
			local class, _, _, distance, depth = S.water_query_at(x, z)
			if class == "channel" and distance >= 24 then
				n = n + 1
				if depth < lo then lo = depth end
				if depth > hi then hi = depth end
				if depth >= 9 and depth <= 11 then in_band = in_band + 1 end
			end
		end
	end
	print(("channel %s: %d columns 24+ off the coast (every 2 nodes), depth %d..%d, " ..
		"%.1f %% at 9-11"):format(channel.id, n, lo, hi, 100 * in_band / math.max(1, n)))
end
-- A boat's way over each boat path: from the first column of the path 48
-- or more nodes off the mainland's coast to the last such column before the
-- island landing (closer in, the shore's shallows are the boat floor's fade,
-- `height.lua` BOAT_SHORE), a 4-connected search over water 9 or more deep.
for _, path in ipairs(source.boat_paths) do
	local line = path.centreline
	local a, b = line[1], line[#line]
	local steps = floor(sqrt((b.x - a.x) * (b.x - a.x) + (b.z - a.z) * (b.z - a.z)))
	local first, last, lo, hi
	for i = 0, steps do
		local x = floor(a.x + (b.x - a.x) * i / steps + 0.5)
		local z = floor(a.z + (b.z - a.z) * i / steps + 0.5)
		local class, _, _, distance, depth = S.water_query_at(x, z)
		if class and distance and distance >= 48 then
			first = first or {x, z}
			last = {x, z}
			if not lo or depth < lo then lo = depth end
			if not hi or depth > hi then hi = depth end
		end
	end
	local reached = false
	if first then
		local min_x, max_x = math.min(a.x, b.x) - 160, math.max(a.x, b.x) + 160
		local min_z, max_z = math.min(a.z, b.z) - 200, math.max(a.z, b.z) + 200
		local seen, queue, head = {}, {first}, 1
		local function key(x, z) return (z - min_z) * 100000 + (x - min_x) end
		seen[key(first[1], first[2])] = true
		while head <= #queue do
			local p = queue[head]
			head = head + 1
			if p[1] == last[1] and p[2] == last[2] then reached = true break end
			for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local x, z = p[1] + o[1], p[2] + o[2]
				if x >= min_x and x <= max_x and z >= min_z and z <= max_z and
						not seen[key(x, z)] then
					seen[key(x, z)] = true
					local class, _, _, _, depth = S.water_query_at(x, z)
					if class and depth >= 9 then queue[#queue + 1] = {x, z} end
				end
			end
		end
	end
	print(("boat path %s: depth along the line 48+ off the coast %s..%s; a boat passes " ..
		"end to end over water 9+ deep: %s"):format(path.id, tostring(lo), tostring(hi),
		reached and "yes" or "NO"))
end
