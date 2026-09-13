-- LuaJIT development fixture for natural-terrain start fitting.

local repo = assert(arg[1], "repository root required")
if arg[2] ~= nil then error("terrain fixture argument population differs", 0) end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()

local seeds = {"0", "1", "42", "8675309", "531802985935182545"}
for seed_index = 1, #seeds do
	local seed = seeds[seed_index]
	local horizontal = horizontal_factory({source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic,
		raw_sha256 = raw_sha256}).new(seed)
	local height = height_factory({source = source, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256,
		horizontal_session = horizontal, coupled_grade = coupled_grade}).new_runtime(seed)
	local starts = height.quality_start_fitting_records()
	assert(#starts == 6, "start fitting population differs")
	local junctions = height.quality_junction_records()
	local junction_by_constraint = {}
	for junction_index = 1, #junctions do
		local junction = junctions[junction_index]
		if junction.constraint_kind == "start_fitting" then
			junction_by_constraint[junction.constraint_id] = junction
		end
	end
	for start_index = 1, #starts do
		local start = starts[start_index]
		assert(start.sample_count == 81 and
			start.reference_y >= 2 and
			start.fit_sample_cost <= start.old_sample_cost,
			"start sample fitting differs at " .. start.id)
		if start.feasible_lower_y <= start.feasible_upper_y and
				start.feasible_upper_y >= 2 then
			assert(start.limit_excess == 0 and
				start.reference_y >= math.max(2, start.feasible_lower_y) and
				start.reference_y <= start.feasible_upper_y,
				"feasible start did not preserve cut/fill cap at " .. start.id)
		end
		local anchor = assert(height.selected_anchor_3d_by_id(start.id))
		assert(anchor.y == start.reference_y and
			height.terrain_height_at(start.x, start.z) == start.reference_y,
			"start spawn surface differs at " .. start.id)
		for dz = -1, 1 do
			for dx = -1, 1 do
				assert(height.terrain_height_at(start.x + dx, start.z + dz) ==
					start.reference_y, "start spawn pad is not flat at " .. start.id)
			end
		end
		local junction = assert(junction_by_constraint[start.id],
			"start road junction missing at " .. start.id)
		assert(junction.target_y == start.reference_y and #junction.uses > 0,
			"start road endpoint differs at " .. start.id)
		for use_index = 1, #junction.uses do
			assert(junction.uses[use_index].final_y == start.reference_y,
				"graded road endpoint differs at " .. start.id)
		end
		io.write(table.concat({"start", seed, start.id, start.reference_y,
			start.preferred_y, start.feasible_lower_y, start.feasible_upper_y,
			start.limit_excess, start.old_reference_y, start.old_sample_cost,
			start.fit_sample_cost}, "\t"), "\n")
	end
end
