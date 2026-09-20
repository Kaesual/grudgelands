-- LuaJIT-only bounded live zones -> R5 planner construction regression.
-- No VM, population, seed fleet, or engine world is created.
return function(repo)
	assert(rawget(_G, "jit"), "run the live-construction fixture with LuaJIT")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40/"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local planner_factory = dofile(wp40 .. "planner.lua")
	local planner_module, constructor_args
	local r5 = dofile(wp40 .. "r5.lua")({
		zones_factory = dofile(wp40 .. "zones.lua"),
		planner_factory = function(allocator)
			planner_module = planner_factory(allocator)
			return {new = function(...)
				constructor_args = {...}
				return planner_module.new(...)
			end}
		end,
		-- The failure happens at the real planner boundary, before the VM
		-- adapter. Keep that unrelated engine-only consumer outside this KAT.
		adapter_factory = function()
			return {new = function() return {} end}
		end,
		manifest_module = dofile(wp40 .. "mapgen_manifest.lua"),
		allocator_factory = dofile(wp40 .. "counting_allocator.lua"),
		source = dofile(wp40 .. "source/simple_map.lua"),
		schemas = dofile(wp40 .. "schemas.lua"),
		canonical = dofile(wp40 .. "canonical.lua"),
		deterministic = dofile(wp40 .. "deterministic.lua"),
		index128 = dofile(wp40 .. "index128.lua"),
		horizontal_factory = dofile(wp40 .. "simple_map.lua"),
		height_factory = dofile(wp40 .. "height.lua"),
		coupled_grade = dofile(wp40 .. "coupled_grade.lua")(),
		raw_sha256 = common.new_sha256(),
	})
	local manifest = dofile(wp40 .. "r7_r6_manifest.lua")().r5_manifest_values
	local _, source, planner = r5.new_runtime("0", 1, manifest, {}, {})
	local minp = {x = 0, y = 40, z = -1500}
	local maxp = {x = 0, y = 48, z = -1500}
	local plan = planner:plan_slice(minp, maxp)
	assert(plan.run_count > 0 and plan.column_start[2] == plan.run_count + 1,
		"live planner did not produce the one-column slice")
	local fields = {"static_exclusion_values_at", "housing_mask_id_at",
		"functional_surface_values_at", "hard_row_at"}
	source.static_exclusion_values_at(0, -1500)
	source.housing_mask_id_at(0, -1500)
	source.functional_surface_values_at(0, -1500)
	assert(source.hard_row_at(0, 44, -1500),
		"ecology bridge lost the authored hard foundation")
	local function refuses(fragment)
		local ok, err = pcall(planner_module.new, unpack(constructor_args))
		assert(not ok and tostring(err):find(fragment, 1, true),
			"planner source rejection differs: " .. tostring(err))
	end
	for _, name in ipairs(fields) do
		local method = source[name]
		assert(type(method) == "function", "ecology bridge missing " .. name)
		source[name] = nil
		refuses("planner source is missing field " .. name)
		source[name] = false
		refuses("planner source API differs")
		source[name] = method
	end
	source.unexpected_ecology_field = function() end
	refuses("planner source has unexpected field unexpected_ecology_field")
	source.unexpected_ecology_field = nil
	return "r11_planner_source\tlive_constructor\tone_column\tfour_required_methods\tPASS\n"
end
