-- Synthetic native-stone cliff for a before/after render (Round 24 B2),
-- LuaJIT: luajit tools/r24_fill/native_cliff.lua "$PWD" OUT_DIR
-- Runs the production strata pass and layer pass of wp40/r6_settlement.lua on
-- a 64 x 48 owner whose rock is native stone up to the surface: a plateau at
-- y ~112 breaking to ground at y ~42 along a wavy edge, pine-hills biome.
-- Steep columns (a drop of 6+ to a cardinal neighbour) get the rock-face
-- surface of Round 22 (stone top and filler); others grass over 4 dirt. One
-- coal node in 64 native stone voxels stands in for the resource pass.
-- Writes before.tsv (strata only: what main produces there) and after.tsv.
local repo = assert(arg[1], "repository path required")
local out = assert(arg[2], "output directory required")
local S = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua")
local floor = math.floor
local AIR, STONE, DIRT, GRASS, COAL = 0, 1, 2, 3, 4
local names = {[AIR] = "air", [STONE] = "default:stone", [DIRT] = "default:dirt",
	[GRASS] = "default:dirt_with_coniferous_litter", [COAL] = "default:stone_with_coal"}
local ids = {}
for cid, name in pairs(names) do ids[name] = cid end
local function cid_of(name)
	if not ids[name] then
		local cid = 100
		while names[cid] do cid = cid + 1 end
		names[cid], ids[name] = name, cid
	end
	return ids[name]
end
local box = {min_x = 0, max_x = 63, min_y = 0, max_y = 127, min_z = 0, max_z = 47}
local ex, ey = 64, 128
local function index_at(x, y, z)
	return (z - box.min_z) * ex * ey + (y - box.min_y) * ex + (x - box.min_x) + 1
end
local function edge(z) return 26 + floor(4 * math.sin(z / 7)) end
local function terrain(x, z)
	local e = edge(z)
	if x < e then return 112 + (x * 3 + z) % 3 end
	if x < e + 2 then return 112 - (x - e + 1) * 22 end
	return 42 + (x + z) % 2
end
local function steep(x, z)
	local t = terrain(x, z)
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		local nx, nz = x + d[1], z + d[2]
		if nx >= 0 and nx <= 63 and nz >= 0 and nz <= 47 and t - terrain(nx, nz) >= 6 then
			return true
		end
	end
	return false
end
local original, final, intent = {}, {}, {}
local seed = 99
for z = 0, 47 do
	for x = 0, 63 do
		local t, st = terrain(x, z), steep(x, z)
		for y = 0, 127 do
			local i = index_at(x, y, z)
			local c = y < t and STONE or AIR
			if c == STONE then
				seed = (seed * 1103515245 + 12345) % 2147483648
				if floor(seed / 65536) % 64 == 0 then c = COAL end
			end
			original[i], final[i], intent[i] = c, c, 0
			if y == t then final[i], intent[i] = st and STONE or GRASS, 1
			elseif y < t and y >= t - 4 then final[i], intent[i] = st and STONE or DIRT, 2 end
		end
	end
end
local function column_values_at(x, z)
	return "land", nil, "stormvault", "grug_pine_hills", nil, terrain(x, z)
end
local info = {}
local writes = 0
local function write(x, y, z, ref)
	final[index_at(x, y, z)], intent[index_at(x, y, z)] = ref, 2
	writes = writes + 1
end
local function dump(path)
	local file = assert(io.open(path, "w"))
	for z = 0, 47 do
		for y = 0, 127 do
			for x = 0, 63 do
				local c = final[index_at(x, y, z)]
				if c ~= AIR then file:write(x, "\t", y, "\t", z, "\t", names[c], "\t0\n") end
			end
		end
	end
	file:close()
end
S.r8_apply_strata({min_x = 0, min_y = 0, min_z = 0, max_x = 63, max_y = 127, max_z = 47,
	floor_y = -37, original_data = original, stone_cid = STONE, index_at = index_at,
	column_info = info, column_values_at = column_values_at,
	static_exclusion_values_at = function() return nil end,
	select_surface = function(_, x, z) return {filler_depth = 4, steep = steep(x, z)} end,
	strata = S.r8_strata_new("10536739806879207652", {zones = {{id = "stormvault",
		primary_relief_id = "mountain"}}}),
	content_ref = cid_of,
	fill_stone_at = function() return false end, write = write})
dump(out .. "/before.tsv")
local bands = writes
S.r24_apply_fill_layers({min_x = 0, min_y = 0, min_z = 0, max_x = 63, max_y = 127,
	max_z = 47, floor_y = -37, index_at = index_at, column_info = info,
	column_values_at = column_values_at, original_data = original, final_data = final,
	intent_opcode = intent, stone_cid = STONE,
	layers = S.r24_fill_layers_new("10536739806879207652"),
	fill_stone_at = function() return false end, content_ref = cid_of, write = write})
dump(out .. "/after.tsv")
print(("native cliff: %d band voxels, %d layer/nest voxels"):format(bands, writes - bands))
