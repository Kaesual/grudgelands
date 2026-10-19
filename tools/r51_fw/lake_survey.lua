-- Round 51 follow-up FW: what grows in the wild land lakes (the user's item
-- 8), as the real writer lays it (tools/seed_fleet/runtime.lua, the fake
-- VoxelManip). Comparisons, not targets.
--
--   luajit tools/r51_fw/lake_survey.lua REPO SEED [CHUNKS]
--
-- Scans the world every 16 nodes for lake columns (the water query's
-- "lake", the swamp's pools left out: they keep their Round 47 look), takes
-- the CHUNKS (default 12) mapchunks holding the most of them, writes each
-- and reads back every lake column whose surface lies in it: its depth, the
-- bed node, the waterweed on the bed and a waterlily on the surface. Prints
-- per depth band the columns, the bed materials and the plants, the lilies
-- within two columns of the shore, the plants of every authored lake
-- (water_authored.lua: the capitals' lakes are lane FT's) and, where the
-- runtime's vegetation authority knows the lakes (`seabed` answering a lily
-- or weed), whether it names exactly the plants the writer grew (the
-- renewal's rule).
local repo, seed, wanted = arg[1], arg[2], tonumber(arg[3] or "12")
assert(repo and seed, "usage: lake_survey.lua REPO SEED [CHUNKS]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local W = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").world_bounds
local floor = math.floor

local function lake(x, z)
	local class, _, _, _, depth = S.water_query_at(x, z)
	if class ~= "lake" or S.biome_at(x, z) == "grug_swamp" then return nil end
	return depth
end
local by_chunk, keys = {}, {}
for z = W.min_z, W.max_z, 16 do
	for x = W.min_x, W.max_x, 16 do
		local depth = lake(x, z)
		if depth then
			local surface = S.terrain_height_at(x, z) + depth
			local key = R.origin(x) .. "," .. R.origin(surface) .. "," .. R.origin(z)
			if not by_chunk[key] then by_chunk[key] = 0; keys[#keys + 1] = key end
			by_chunk[key] = by_chunk[key] + 1
		end
	end
end
table.sort(keys, function(a, b)
	if by_chunk[a] ~= by_chunk[b] then return by_chunk[a] > by_chunk[b] end
	return a < b
end)
print(("seed %s: %d chunks hold wild lake water (16-node scan); the %d fullest written")
	:format(seed, #keys, math.min(wanted, #keys)))

local fake = R.fake
local native = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_native.lua")
local authority = R.main.build_authority(native.identities())
local vegetation, source = authority.vegetation, authority.planner_source
local agree, writer_only, renewal_only = 0, 0, 0
local authored = {}
local BANDS = {{1, 1}, {2, 6}, {7, 12}, {13, 999}}
local stats = {}
for b = 1, #BANDS do stats[b] = {columns = 0, beds = {}, weed = 0, lily = 0} end
local shore_columns, shore_lilies = 0, 0
for k = 1, math.min(wanted, #keys) do
	local ox, oy, oz = keys[k]:match("^(-?%d+),(-?%d+),(-?%d+)$")
	ox, oy, oz = tonumber(ox), tonumber(oy), tonumber(oz)
	local minp = {x = ox, y = oy, z = oz}
	local maxp = {x = ox + 79, y = oy + 79, z = oz + 79}
	local vm = R.new_vm(minp)
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data or vm.native.data
	local function name_at(x, y, z)
		return fake.get_name_from_content_id(data[(z - oz + 16) * 12544 + (y - oy + 16) * 112 +
			(x - ox + 16) + 1])
	end
	for z = oz, oz + 79 do
		for x = ox, ox + 79 do
			local depth = lake(x, z)
			local bed = depth and S.terrain_height_at(x, z)
			if depth and bed + depth + 1 <= maxp.y and bed >= minp.y then
				local surface = bed + depth
				local band
				for b = 1, #BANDS do
					if depth >= BANDS[b][1] and depth <= BANDS[b][2] then band = b end
				end
				local s = stats[band]
				s.columns = s.columns + 1
				local bed_name = name_at(x, bed, z)
				s.beds[bed_name] = (s.beds[bed_name] or 0) + 1
				if bed_name == "grug_mapgen:freshwater_waterweed" then s.weed = s.weed + 1 end
				local lily = name_at(x, surface + 1, z) == "grug_mapgen:freshwater_waterlily"
				if lily then s.lily = s.lily + 1 end
				local weed = bed_name == "grug_mapgen:freshwater_waterweed"
				local id = select(8, source.column_values_at(x, z))
				if type(id) == "string" and id:sub(1, 5) == "lake:" and not id:match("^lake:%d+$") then
					local a = authored[id] or {columns = 0, plants = 0}
					authored[id] = a
					a.columns = a.columns + 1
					if lily or weed then a.plants = a.plants + 1 end
				end
				if vegetation.seabed then
					local want = vegetation.seabed(x, z)
					-- the renewal places a weed only on a plain sand bed
					if want == "grug_mapgen:freshwater_waterweed" and not weed and
							bed_name ~= "default:sand" then
						want = nil
					end
					local got = lily and "grug_mapgen:freshwater_waterlily" or
						(weed and "grug_mapgen:freshwater_waterweed") or nil
					if want == got then agree = agree + 1
					elseif got and not want then writer_only = writer_only + 1
					elseif want and not got then renewal_only = renewal_only + 1
					else writer_only, renewal_only = writer_only + 1, renewal_only + 1 end
				end
				local near = false
				for dz = -2, 2 do
					for dx = -2, 2 do
						if not near and S.water_query_at(x + dx, z + dz) == nil then near = true end
					end
				end
				if near then
					shore_columns = shore_columns + 1
					if lily then shore_lilies = shore_lilies + 1 end
				end
			end
		end
	end
end
for b = 1, #BANDS do
	local s = stats[b]
	local beds = {}
	for name, n in pairs(s.beds) do beds[#beds + 1] = {name, n} end
	table.sort(beds, function(p, q) return p[2] > q[2] or (p[2] == q[2] and p[1] < q[1]) end)
	local parts = {}
	for i = 1, math.min(4, #beds) do
		parts[#parts + 1] = ("%s %.0f%%"):format(beds[i][1]:gsub("^.*:", ""),
			100 * beds[i][2] / math.max(1, s.columns))
	end
	print(("depth %2d-%-3d %6d columns: waterweed %d (1/%.0f), waterlily %d (1/%.0f); beds %s")
		:format(BANDS[b][1], BANDS[b][2], s.columns, s.weed, s.columns / math.max(1, s.weed),
		s.lily, s.columns / math.max(1, s.lily), table.concat(parts, ", ")))
end
print(("within 2 of the shore: %d columns, %d lilies (1/%.0f)"):format(shore_columns,
	shore_lilies, shore_columns / math.max(1, shore_lilies)))
local ids = {}
for id in pairs(authored) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
	print(("authored %s: %d columns, %d with a plant"):format(id, authored[id].columns,
		authored[id].plants))
end
print(("writer and renewal rule: %d columns agree, %d grown by the writer only, " ..
	"%d named by the renewal only (on a sand bed or open surface)"):format(agree, writer_only, renewal_only))
