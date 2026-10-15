-- Round 49 lane JIT portable fixture (LuaJIT):
--
--   luajit tools/r49_jit/portable_test.lua REPO
--
-- The R5 adapter's one-pass resolve (wp40/map_adapter.lua) on the real
-- runtime of seed 12345 (tools/seed_fleet/runtime.lua), its fake VoxelManip's
-- ground moved off the planned terrain so the adapter cuts and fills many
-- voxels:
-- 1. The runtime adapter (the trusted classifier and its per-(CID, param2)
--    memo) and the validating adapter (the classifier's checked tuples, no
--    memo) write the same bytes, return the same result and count the same
--    modified voxels and dirty columns on surface and fill-floor chunks, also
--    with flowing water of every level in the chunk.
-- 2. The memo hides no failure: an out-of-range param2 under a run, on a
--    content id the memo already holds, still fails in the classifier.
-- The byte identity against the two-pass adapter before Round 49 is shown by
-- tools/r49_jit/fleet_digest.sh on both trees, not here.
-- Prints "R49 JIT PORTABLE PASS checks=<n>" or raises.
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
	print("ok   " .. label)
end

local SEED = "12345"
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, SEED)
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"

-- v7's stand-in ground up to about 13 nodes off the plan (the plan reads the
-- planner's own column source, not this table field).
do
	local zones = R.built.zones_session
	local terrain_height_at = zones.terrain_height_at
	zones.terrain_height_at = function(x, z)
		return terrain_height_at(x, z) +
			math.floor(10 * math.sin(x * 0.05) * math.cos(z * 0.04) + 3)
	end
end

-- Two R5 instances over the shared world assembly, as the runtime builds
-- them: the runtime one (trusted classifier) and the validating one.
local A = dofile(wp40 .. "/world_assembly.lua")(wp40, R.sha)
local W = A.world(SEED, {placement = R.main.placement_layout_text(),
	water = R.main.water_layout_text(), road = R.main.road_layout_text(),
	capital = R.main.capital_layout_text()})
W.capitals()
local r5 = dofile(wp40 .. "/r5.lua")({zones_factory = A.zones_factory,
	planner_factory = dofile(wp40 .. "/planner.lua"),
	adapter_factory = dofile(wp40 .. "/map_adapter.lua"),
	manifest_module = dofile(wp40 .. "/mapgen_manifest.lua"),
	allocator_factory = dofile(wp40 .. "/counting_allocator.lua"),
	source = W.place(), schemas = A.schemas, canonical = A.canonical,
	deterministic = A.deterministic, index128 = A.index128,
	horizontal_factory = W.horizontal_factory, height_factory = W.height_factory,
	terrain_field = A.terrain_field, raw_sha256 = R.sha})
local production = R.built.content.production
local manifest_values = dofile(wp40 .. "/r7_r6_manifest.lua")().r5_manifest_values
local _, _, runtime_planner, runtime_adapter = r5.new_runtime(SEED, 1,
	manifest_values, production.r5, R.built.mapgen_context,
	production.classify_runtime)
local _, _, checked_planner, checked_adapter = r5.new(SEED, 1, manifest_values,
	production.r5, R.built.mapgen_context)

local fake = R.fake
local flowing = fake.get_content_id("default:water_flowing")
local stone = fake.get_content_id("default:stone")
local air = fake.CONTENT_AIR

-- The emerged-area index of a position (the harness's 112^3 volume).
local function index_at(minp, x, y, z)
	return (z - minp.z + 16) * 12544 + (y - minp.y + 16) * 112 + (x - minp.x + 16) + 1
end

-- One apply on a fresh fake VoxelManip (edit(vm) may change its native
-- bytes first): the result, the written bytes' hash and the metric deltas.
local function apply(planner, adapter, minp, edit)
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local plan, generation = planner:plan_slice(minp, maxp)
	local vm = R.new_vm(minp)
	if edit then edit(vm, plan) end
	local before = adapter:metrics()
	local result = adapter:apply(vm, minp, maxp, plan, generation, "engine_fixture",
		"outer_transaction")
	local after = adapter:metrics()
	local delta = {}
	for _, key in ipairs({"modified_voxels", "content_dirty_columns",
			"param2_dirty_columns", "light_dirty_columns", "liquid_dirty_columns"}) do
		delta[#delta + 1] = after[key] - before[key]
	end
	return result, R.written_hash(vm), table.concat(delta, ","), delta[1]
end

-- Flowing water of every level in the air of the chunk's upper half.
local function flowing_water(minp)
	return function(vm)
		local placed = 0
		for z = minp.z + 2, minp.z + 77, 5 do
			for x = minp.x + 2, minp.x + 77, 5 do
				for y = minp.y + 79, minp.y + 40, -1 do
					local index = index_at(minp, x, y, z)
					if vm.native.data[index] == air then
						vm.native.data[index] = flowing
						vm.native.param2[index] = placed % 16
						placed = placed + 1
						break
					end
				end
			end
		end
	end
end

-- 1. The two adapters agree.
local CHUNKS = {
	{"surface S1", {x = 368, y = -32, z = -2352}},
	{"surface S2", {x = 368, y = 48, z = -2352}},
	{"fill floor B", {x = 368, y = -112, z = -2352}},
	{"surface S2 of column B", {x = 528, y = 48, z = -2192}},
	{"surface S1 with flowing water", {x = 368, y = -32, z = -2352}, true},
}
local modified_total = 0
for _, case in ipairs(CHUNKS) do
	local label, minp = case[1], case[2]
	local edit = case[3] and flowing_water(minp) or nil
	local result_a, hash_a, metrics_a, modified = apply(runtime_planner,
		runtime_adapter, minp, edit)
	local result_b, hash_b, metrics_b = apply(checked_planner, checked_adapter, minp,
		edit)
	modified_total = modified_total + modified
	check(result_a == result_b and hash_a == hash_b and metrics_a == metrics_b,
		("%s: runtime and validating adapter agree (%s, %s, modified/dirty %s)")
			:format(label, tostring(result_a), hash_a, metrics_a))
end
check(modified_total > 20000, "the moved ground makes the adapter write (" ..
	modified_total .. " voxels)")

-- 2. A bad param2 still fails in the classifier.
do
	local minp = CHUNKS[1][2]
	local ok, err = pcall(apply, runtime_planner, runtime_adapter, minp,
		function(vm, plan)
			-- the lowest voxel of the first planned column's first run
			for column = 1, 6400 do
				local first = plan.column_start[column]
				if first < plan.column_start[column + 1] then
					local x = minp.x + (column - 1) % 80
					local z = minp.z + math.floor((column - 1) / 80)
					local index = index_at(minp, x, plan.run_values[(first - 1) * 9 + 1], z)
					vm.native.data[index] = stone
					vm.native.param2[index] = 300
					return
				end
			end
		end)
	check(not ok and tostring(err):find("runtime classified param2", 1, true) ~= nil,
		"an out-of-range param2 on a memoised CID fails in the classifier (" ..
			tostring(err):match("^[^\n]*") .. ")")
end

print("R49 JIT PORTABLE PASS checks=" .. checks)
