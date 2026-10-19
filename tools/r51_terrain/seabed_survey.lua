-- Round 51 TERRAIN T3: what grows on the seabed (measured shares for the
-- report; rough targets, not gates).
--
--   luajit tools/r51_terrain/seabed_survey.lua REPO SEED [CHUNKS]
--
-- Builds the real runtime of SEED (tools/seed_fleet/runtime.lua), picks
-- CHUNKS (default 12) mapchunks per water class whose centre column has that
-- class (the shelf: belt water within 80 nodes of the coast, the old shelf;
-- the belt beyond; bays; channels; the open sea), spread over the world,
-- plans and writes each through the real writer against the fake
-- VoxelManip and reads back the bed node of every water column: coral, kelp,
-- seagrass or bare. Prints per class the share of seabed columns (2-20 deep)
-- under each, and for kelp the share standing deeper than 12 (where daylight
-- is nearly gone) and its depth range.
local repo, seed, per_class = arg[1], arg[2], tonumber(arg[3] or "12")
assert(repo and seed, "usage: seabed_survey.lua REPO SEED [CHUNKS]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local W = source.world_bounds

local function class_of(x, z)
	local class, _, _, distance = S.water_query_at(x, z)
	if class == "belt" and distance < 80 then return "shelf" end
	return class
end
local CLASSES = {"shelf", "belt", "bay", "channel", "open_sea"}
local candidates = {}
for _, class in ipairs(CLASSES) do candidates[class] = {} end
for z = W.min_z + 40, W.max_z - 120, 80 do
	for x = W.min_x + 40, W.max_x - 120, 80 do
		local ox, oz = R.origin(x), R.origin(z)
		local class = class_of(ox + 40, oz + 40)
		if candidates[class] then
			local list = candidates[class]
			list[#list + 1] = {ox, oz}
		end
	end
end

local fake = R.fake
local function kind_of(name)
	if name:find("^default:coral_") then return "coral" end
	if name == "default:sand_with_kelp" then return "kelp" end
	if name:find("^grug_mapgen:seagrass_") then return "seagrass" end
	return "bare"
end
print(("seed %s"):format(seed))
for _, class in ipairs(CLASSES) do
	local list = candidates[class]
	local counts = {coral = 0, kelp = 0, seagrass = 0, bare = 0}
	local columns, kelp_deep, kelp_lo, kelp_hi = 0, 0, math.huge, -math.huge
	local picked = 0
	local step = math.max(1, math.floor(#list / per_class))
	for index = 1, #list, step do
		if picked >= per_class then break end
		picked = picked + 1
		local ox, oz = list[index][1], list[index][2]
		local minp = {x = ox, y = -32, z = oz}
		local maxp = {x = ox + 79, y = 47, z = oz + 79}
		local vm = R.new_vm(minp)
		local plan, generation = R.built.session.plan_slice(minp, maxp)
		R.built.writer.apply(vm, minp, maxp, plan, generation)
		local data = vm.written.data or vm.native.data
		for z = oz, oz + 79 do
			for x = ox, ox + 79 do
				local got, _, _, _, depth = S.water_query_at(x, z)
				if got and got ~= "lake" and got ~= "river" and class_of(x, z) == class and
						depth >= 2 and depth <= 20 then
					local y = 1 - depth
					if y >= -32 then
						local i = (z - oz + 16) * 12544 + (y - minp.y + 16) * 112 + (x - ox + 16) + 1
						local kind = kind_of(fake.get_name_from_content_id(data[i]))
						counts[kind] = counts[kind] + 1
						columns = columns + 1
						if kind == "kelp" then
							if depth > 12 then kelp_deep = kelp_deep + 1 end
							if depth < kelp_lo then kelp_lo = depth end
							if depth > kelp_hi then kelp_hi = depth end
						end
					end
				end
			end
		end
	end
	local function share(n) return 100 * n / math.max(1, columns) end
	print(("%-8s %2d chunks, %6d seabed columns 2-20 deep: coral %.1f %%, kelp %.1f %%, " ..
		"seagrass %.1f %%, bare %.1f %%; kelp deeper than 12: %.0f %% of the kelp (depth %s..%s)")
		:format(class, picked, columns, share(counts.coral), share(counts.kelp),
		share(counts.seagrass), share(counts.bare),
		100 * kelp_deep / math.max(1, counts.kelp), tostring(kelp_lo), tostring(kelp_hi)))
end
