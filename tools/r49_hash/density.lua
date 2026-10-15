-- Round 49 lane HASH: decoration, tree and gathering-source density per
-- chunk through the seed fleet's harness (tools/seed_fleet/runtime.lua: the
-- real planner and writer against a fake VoxelManip), so a checkout before
-- and after a placement change can be compared kind by kind.
--
--   luajit tools/r49_hash/density.lua REPO [SEED]   (SEED default 12345)
--
-- REPO is the checkout whose mapgen and harness run (this script can count
-- an older checkout). The chunks: the mgprof corpus's two surface chunks of
-- column A (seed 12345 only) and, per listed biome, the surface chunks of the
-- first PER_BIOME 80 x 80 columns on a coarse grid whose centre and four
-- quarter points are dry land of that biome. Prints, per chunk, the planned
-- decoration candidates rooted in it per row ("candidates <chunk> <row>
-- <n>") and every node name the written chunk holds with its count ("count
-- <chunk> <name> <n>"); compare two runs with
-- tools/r49_hash/density_compare.py.
local repo = assert(arg and arg[1], "usage: density.lua REPO [SEED]")
local seed = arg[2] or "12345"
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local BIOMES = {"grug_meadows", "grug_deep_forest", "grug_elf_forest", "grug_deep_jungle",
	"grug_savanna", "grug_swamp", "grug_bone_forest"}

local chunks = {}
if seed == "12345" then
	chunks[#chunks + 1] = {"A_S1", 368, -32, -2352}
	chunks[#chunks + 1] = {"A_S2", 368, 48, -2352}
end
local PER_BIOME = 4
local found = {}
for z = -3200, 3120, 160 do
	for x = -3600, 3520, 160 do
		local ox, oz = R.origin(x), R.origin(z)
		local biome = zones.biome_at(ox + 40, oz + 40)
		if biome and (found[biome] or 0) < PER_BIOME then
			local same = true
			for _, p in ipairs({{20, 20}, {60, 20}, {20, 60}, {60, 60}, {40, 40}}) do
				local px, pz = ox + p[1], oz + p[2]
				if zones.biome_at(px, pz) ~= biome or zones.water_class_at(px, pz) ~= "land" then
					same = false
					break
				end
			end
			if same then
				for _, wanted in ipairs(BIOMES) do
					if wanted == biome then
						found[biome] = (found[biome] or 0) + 1
						chunks[#chunks + 1] = {biome .. "#" .. found[biome], ox,
							R.origin(R.ground_at(ox + 40, oz + 40)), oz}
					end
				end
			end
		end
	end
end

-- The planner's candidate row width in this checkout (14 before Round 49
-- lane HASH, 7 after) and its decoration rows in catalog order.
local planner_file = assert(io.open(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua"))
local STRIDE = tonumber(planner_file:read("*a"):match("local CANDIDATE_STRIDE = (%d+)"))
planner_file:close()
local decorations = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua")()
	.decorations

for _, chunk in ipairs(chunks) do
	local label, minp = chunk[1], {x = chunk[2], y = chunk[3], z = chunk[4]}
	local vm = R.new_vm(minp)
	local plan, generation = R.built.session.plan_slice(minp,
		{x = minp.x + 79, y = minp.y + 79, z = minp.z + 79})
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local planned = {}
	for candidate = 1, plan.candidate_count do
		local base = (candidate - 1) * STRIDE
		local v = plan.candidate_values
		if v[base + 4] >= minp.x and v[base + 4] <= maxp.x and v[base + 5] >= minp.y and
				v[base + 5] <= maxp.y and v[base + 6] >= minp.z and v[base + 6] <= maxp.z then
			local id = decorations[v[base + 2]].id
			planned[id] = (planned[id] or 0) + 1
		end
	end
	local result = R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data or vm.native.data
	local counts = {}
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local index = (z - minp.z + 16) * 12544 + (y - minp.y + 16) * 112 +
					(x - minp.x + 16) + 1
				local name = R.fake.get_name_from_content_id(data[index])
				counts[name] = (counts[name] or 0) + 1
			end
		end
	end
	print(("chunk %s minp=%d,%d,%d result=%s"):format(label, minp.x, minp.y, minp.z,
		tostring(result)))
	local ids = {}
	for id in pairs(planned) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		print(("candidates %s %s %d"):format(label, id, planned[id]))
	end
	local names = {}
	for name in pairs(counts) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		print(("count %s %s %d"):format(label, name, counts[name]))
	end
end
