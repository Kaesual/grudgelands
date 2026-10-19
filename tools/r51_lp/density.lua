-- Round 51 lane LP: the land plants on real chunks, and the mapgen time of
-- the same chunks, through the seed fleet's harness (tools/seed_fleet/
-- runtime.lua: the real planner and writer against a fake VoxelManip). Run it
-- on this checkout and on one before the lane to compare (numbers are
-- comparisons, never targets):
--
--   luajit tools/r51_lp/density.lua REPO [SEED] [PER]   (SEED 12345, PER 3)
--
-- REPO is the checkout whose mapgen runs. Chunks: per region the surface
-- chunks of the first PER 80 x 80 columns on a coarse grid that are dry land
-- of the region's biomes at their centre and four quarter points (jungle,
-- elf forest, crags and pine hills, badlands, swamp), and for the warm beach
-- the first PER whose centre is a warm biome's land with the sea or a lake at
-- a quarter point (no dragon channel). Prints per chunk its plan and write seconds and
-- the land plant nodes it holds, then per region the totals and the dry-land
-- columns, and the CPU seconds of the world's tree templates.
local repo = assert(arg and arg[1], "usage: density.lua REPO [SEED] [PER]")
local seed = arg[2] or "12345"
local PER = tonumber(arg[3] or "3")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session

local REGIONS = {
	{"jungle", {grug_deep_jungle = true, grug_jungle_fringe = true, grug_jungle_edge = true}},
	{"elves", {grug_elf_forest = true, grug_deep_forest = true}},
	{"crags", {grug_crags = true, grug_pine_hills = true}},
	{"orc", {grug_badlands = true, grug_badlands_east = true}},
	{"swamp", {grug_swamp = true}},
	{"beach", {grug_deep_jungle = true, grug_jungle_fringe = true, grug_jungle_edge = true,
		grug_savanna = true, grug_badlands = true, grug_badlands_east = true}, true},
}
-- The nodes counted, by plant.
local PLANTS = {
	{"liana", {"grug_trees:liana", "grug_trees:liana_strand"}},
	{"liana_end", {"grug_trees:liana"}},
	{"flower", {"grug_nodes:flower_ruby_fan", "grug_nodes:flower_ember_star",
		"grug_nodes:flower_violet_fan", "grug_nodes:flower_blush_star",
		"grug_nodes:flower_lilac_bells", "grug_nodes:flower_cream_cups"}},
	{"fern", {"default:fern_1", "default:fern_2", "default:fern_3"}},
	{"jungle_bush", {"grug_nodes:jungle_bush_leaves"}},
	{"withered_bush", {"grug_nodes:withered_bush_leaves"}},
	{"lichen", {"grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b"}},
	{"alpine", {"grug_nodes:alpine_cushion", "grug_nodes:alpine_windshrub"}},
	{"papyrus", {"default:papyrus"}},
	{"marram", {"default:marram_grass_1", "default:marram_grass_2", "default:marram_grass_3"}},
	{"bush_stem", {"default:bush_stem", "default:acacia_bush_stem"}},
}
local PLANT_OF = {}
for _, plant in ipairs(PLANTS) do
	for _, name in ipairs(plant[2]) do
		PLANT_OF[name] = PLANT_OF[name] or {}
		PLANT_OF[name][#PLANT_OF[name] + 1] = plant[1]
	end
end

local chunks = {}
for _, region in ipairs(REGIONS) do
	local label, biomes, shore = region[1], region[2], region[3]
	local found = 0
	for z = -3200, 3120, 160 do
		for x = -3600, 3520, 160 do
			if found >= PER then break end
			local ox, oz = R.origin(x), R.origin(z)
			local cx, cz = ox + 40, oz + 40
			if biomes[zones.biome_at(cx, cz) or ""] and zones.water_class_at(cx, cz) == "land" then
				local ok, wet = true, false
				for _, p in ipairs({{20, 20}, {60, 20}, {20, 60}, {60, 60}}) do
					local px, pz = ox + p[1], oz + p[2]
					local land = zones.water_class_at(px, pz) == "land"
					if land and not biomes[zones.biome_at(px, pz) or ""] then ok = false end
					-- the sea or a lake, not a dragon island's channel (the
					-- islands' coast claim keeps their shores bare)
					local class = zones.water_class_at(px, pz)
					if class == "immutable_dragon_channel" then ok = false end
					if not land then wet = true end
					if not shore and not land then ok = false end
				end
				if ok and (not shore or wet) then
					found = found + 1
					chunks[#chunks + 1] = {label, label .. "#" .. found, ox,
						R.origin(R.ground_at(cx, cz)), oz}
				end
			end
		end
	end
end

local totals, seconds, columns = {}, {}, {}
for _, chunk in ipairs(chunks) do
	local region, label = chunk[1], chunk[2]
	local minp = {x = chunk[3], y = chunk[4], z = chunk[5]}
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local vm = R.new_vm(minp)
	local t1 = os.clock()
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	local t2 = os.clock()
	local result = R.built.writer.apply(vm, minp, maxp, plan, generation)
	local t3 = os.clock()
	local data = vm.written.data or vm.native.data
	local counts = {}
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local index = (z - minp.z + 16) * 12544 + (y - minp.y + 16) * 112 +
					(x - minp.x + 16) + 1
				local name = R.fake.get_name_from_content_id(data[index])
				for _, plant in ipairs(PLANT_OF[name] or {}) do
					counts[plant] = (counts[plant] or 0) + 1
				end
			end
		end
	end
	local dry = 0
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			if zones.water_class_at(x, z) == "land" then dry = dry + 1 end
		end
	end
	local parts = {}
	totals[region] = totals[region] or {}
	for _, plant in ipairs(PLANTS) do
		local n = counts[plant[1]] or 0
		parts[#parts + 1] = plant[1] .. "=" .. n
		totals[region][plant[1]] = (totals[region][plant[1]] or 0) + n
	end
	seconds[region] = (seconds[region] or 0) + (t3 - t1)
	columns[region] = (columns[region] or 0) + dry
	print(("chunk %s minp=%d,%d,%d result=%s plan=%.3f write=%.3f dry=%d %s"):format(label,
		minp.x, minp.y, minp.z, tostring(result), t2 - t1, t3 - t2, dry, table.concat(parts, " ")))
end
local all = 0
for _, region in ipairs(REGIONS) do
	local label = region[1]
	local parts = {}
	for _, plant in ipairs(PLANTS) do
		parts[#parts + 1] = plant[1] .. "=" .. ((totals[label] or {})[plant[1]] or 0)
	end
	all = all + (seconds[label] or 0)
	print(("region %s seconds=%.3f dry=%d %s"):format(label, seconds[label] or 0,
		columns[label] or 0, table.concat(parts, " ")))
end
print(("total seconds=%.3f chunks=%d template_seconds=%.3f"):format(all, #chunks,
	R.built.template_seconds or -1))
