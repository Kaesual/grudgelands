-- Round 37 lane MG portable fixture (LuaJIT):
--
--   luajit tools/r37_mg/portable_test.lua REPO
--
-- 1. MGT-02, the decoration halo: on the real runtime of seed 1
--    (tools/seed_fleet/runtime.lua) a chunk's plan holds exactly its own
--    5 x 5 cells in z-then-x order, every candidate roots in its own cell, and
--    the writer writes the same bytes from that plan as from the plan the
--    former 2-cell halo made (the chunk's own rows with the eight neighbours'
--    rows round them, 9 x 9 cells, as the old planner copied them).
-- 2. MGT-01: the three transaction wrappers (R6 planner, writer, R5 adapter)
--    keep the failure's traceback, once, naming the failing module.
-- Prints "R37 MG PORTABLE PASS checks=<n>" or raises.
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
	print("ok   " .. label)
end

local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, "1")
local session, writer = R.built.session, R.built.writer
local STRIDE = 14

-- The rows of every cell of a plan, by "cx,cz", copied.
local function cell_rows(plan)
	local out = {}
	for cell = 1, plan.candidate_cell_count do
		local base = (cell - 1) * 4
		local rows = {}
		for candidate = plan.candidate_cell_values[base + 3],
				plan.candidate_cell_values[base + 4] - 1 do
			for k = 1, STRIDE do
				rows[#rows + 1] = plan.candidate_values[(candidate - 1) * STRIDE + k]
			end
		end
		out[plan.candidate_cell_values[base + 1] .. "," ..
			plan.candidate_cell_values[base + 2]] = rows
	end
	return out
end

-- 1. The halo. A Dawnmere forest chunk with many decoration candidates.
do
	local x, z = 0, 1850
	local minp = {x = R.origin(x), y = R.origin(R.ground_at(x, z)), z = R.origin(z)}
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local around = {}
	for dz = -1, 1 do
		for dx = -1, 1 do
			if dx ~= 0 or dz ~= 0 then
				local p = {x = minp.x + 80 * dx, y = minp.y, z = minp.z + 80 * dz}
				for key, rows in pairs(cell_rows(session.plan_slice(p,
						{x = p.x + 79, y = p.y + 79, z = p.z + 79}))) do
					around[key] = rows
				end
			end
		end
	end
	local plan, generation = session.plan_slice(minp, maxp)
	local fx, fz = math.floor(minp.x / 16), math.floor(minp.z / 16)
	local own, in_cell, outside = true, true, 0
	check(plan.candidate_cell_count == 25, "the plan holds 25 cells (" ..
		plan.candidate_cell_count .. ")")
	for cell = 1, plan.candidate_cell_count do
		local base = (cell - 1) * 4
		local cx, cz = plan.candidate_cell_values[base + 1], plan.candidate_cell_values[base + 2]
		if cx ~= fx + (cell - 1) % 5 or cz ~= fz + math.floor((cell - 1) / 5) then own = false end
		for candidate = plan.candidate_cell_values[base + 3],
				plan.candidate_cell_values[base + 4] - 1 do
			local cb = (candidate - 1) * STRIDE
			local rx, rz = plan.candidate_values[cb + 4], plan.candidate_values[cb + 6]
			if math.floor(rx / 16) ~= cx or math.floor(rz / 16) ~= cz then in_cell = false end
			if rx < minp.x or rx > maxp.x or rz < minp.z or rz > maxp.z then
				outside = outside + 1
			end
		end
	end
	check(own, "the cells are the chunk's own, z then x")
	check(in_cell and outside == 0, "every candidate roots in its own cell, inside the owner")
	-- The former halo plan: the 9 x 9 cells round the owner in z-then-x
	-- order, the owner's rows from this plan, the others from the neighbours.
	local mine = cell_rows(plan)
	local cells, values, cell_count, count = {}, {}, 0, 0
	for cz = fz - 2, fz + 6 do
		for cx = fx - 2, fx + 6 do
			local rows = assert(mine[cx .. "," .. cz] or around[cx .. "," .. cz],
				"cell " .. cx .. "," .. cz)
			cell_count = cell_count + 1
			cells[#cells + 1], cells[#cells + 2] = cx, cz
			cells[#cells + 1] = count + 1
			for k = 1, #rows do values[#values + 1] = rows[k] end
			count = count + #rows / STRIDE
			cells[#cells + 1] = count + 1
		end
	end
	check(count > plan.candidate_count, ("the halo plan has more candidates (%d > %d)")
		:format(count, plan.candidate_count))
	-- (the writer binds the plan object itself, so its arrays are swapped in
	-- place for the write and put back after)
	local kept = {plan.candidate_cell_values, plan.candidate_cell_count,
		plan.candidate_values, plan.candidate_count}
	plan.candidate_cell_values, plan.candidate_cell_count = cells, cell_count
	plan.candidate_values, plan.candidate_count = values, count
	local vm = R.new_vm(minp)
	local ok, halo_result = pcall(writer.apply, vm, minp, maxp, plan, generation)
	plan.candidate_cell_values, plan.candidate_cell_count = kept[1], kept[2]
	plan.candidate_values, plan.candidate_count = kept[3], kept[4]
	if not ok then error(halo_result, 0) end
	local halo_hash = R.written_hash(vm)
	plan, generation = session.plan_slice(minp, maxp)
	vm = R.new_vm(minp)
	local result = writer.apply(vm, minp, maxp, plan, generation)
	check(result == halo_result and R.written_hash(vm) == halo_hash,
		"the writer writes the same chunk with and without the halo (" .. result .. ", " ..
		halo_hash .. ")")
end

-- 2. Tracebacks.
local function one_traceback(message, code, module)
	local _, count = tostring(message):gsub("stack traceback:", "")
	return tostring(message):sub(1, #code) == code and count == 1 and
		tostring(message):find(module, 1, true) ~= nil
end
do
	local x, z = 0, 1850
	local minp = {x = R.origin(x), y = R.origin(R.ground_at(x, z)), z = R.origin(z)}
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	-- writer: a VoxelManip without update_liquids
	local plan, generation = session.plan_slice(minp, maxp)
	local vm = R.new_vm(minp)
	vm.update_liquids = nil
	local ok, message = pcall(writer.apply, vm, minp, maxp, plan, generation)
	check(not ok and one_traceback(message, "fail_vm_contract", "r6_settlement.lua"),
		"writer failure keeps one traceback")
	-- the R5 adapter inside the writer: a heightmap outside the chunk
	plan, generation = session.plan_slice(minp, maxp)
	vm = R.new_vm(minp)
	R.fake.get_mapgen_object("heightmap")[1] = maxp.y + 1
	ok, message = pcall(writer.apply, vm, minp, maxp, plan, generation)
	check(not ok and one_traceback(message, "fail_native_heightmap", "map_adapter.lua"),
		"nested adapter failure keeps one traceback")
end
do
	-- the R6 planner: its R5 planner fails inside plan_slice (the column
	-- source of main's authority build, the R6 content over the Round 23
	-- harness's synthetic contract)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local B = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
	local source = R.main.build_authority(
		dofile(wp40 .. "/r7_native.lua").identities()).planner_source
	local planner = dofile(wp40 .. "/r6_planner.lua").new_runtime({
		full_seed_string = "1", planner_source = source,
		r5_planner = {plan_slice = function() error("r37 probe: R5 planner failed", 0) end},
		horizontal = source, content = B.content(), hash = dofile(wp40 .. "/r6_hash.lua")(B.sha),
		source = dofile(wp40 .. "/source/simple_map.lua"), construction_identity = {value = false},
		counting_allocator = dofile(wp40 .. "/counting_allocator.lua").new(
			"grug_wp40_r6_planner_allocator_v1"),
	})
	local ok, message = pcall(planner.plan_slice, planner, {x = -32, y = -32, z = -32},
		{x = 47, y = 47, z = 47})
	check(not ok and one_traceback(message, "r37 probe: R5 planner failed", "r6_planner.lua"),
		"planner failure keeps one traceback")
end

print("R37 MG PORTABLE PASS checks=" .. checks)
