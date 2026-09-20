-- Real source geometry, including negative owner edges and overlapping claims.
return function(repo)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(dir .. "/source/simple_map.lua")
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local horizontal = dofile(dir .. "/simple_map.lua")({source = source,
		schemas = dofile(dir .. "/schemas.lua"), canonical = dofile(dir .. "/canonical.lua"),
		deterministic = dofile(dir .. "/deterministic.lua"), raw_sha256 = common.new_sha256(),
	}).new("4151598227737528026")
	local profiles, checked = {}, 0
	for _, profile in ipairs(source.anchor_profiles) do profiles[profile.id] = profile end
	for _, anchor in ipairs(source.anchors) do
		local profile = profiles[anchor.template_id]
		local width = profile.building_core_width or profile.fitting_width
		if anchor.slot_id == "start" or anchor.slot_id == "capital" then width = width + 20 end
		local half = width / 2
		for _, offset in ipairs({{-half, -half}, {half - 1, half - 1}, {0, 0}}) do
			local x, z = anchor.position.x + offset[1], anchor.position.z + offset[2]
			assert(horizontal.static_exclusion_values_at(x, z, "cave"), anchor.id .. " lost functional ground")
			assert(horizontal.static_exclusion_values_at(x, z), "claim footprint shrank")
			checked = checked + 1
		end
	end
	for _, p in ipairs({{-71, -2458}, {-72, -2458}, {-70, -2458}}) do
		local _, id = horizontal.static_exclusion_values_at(p[1], p[2])
		assert(id == "exclude:anchor:anchor_002:01", "reported blend witness changed")
		assert(horizontal.static_exclusion_values_at(p[1], p[2], "cave") == nil,
			"reported natural column remains excluded")
	end
	-- An overlapping route must answer even when its enclosing blend is skipped.
	local routes = 0
	for _, route in ipairs(source.routes) do
		for _, point in ipairs(route.centreline) do
			assert(horizontal.static_exclusion_values_at(point.x, point.z, "cave"),
				"route footprint lost exclusion")
			routes = routes + 1
		end
	end
	assert(not pcall(horizontal.static_exclusion_values_at, 0, 0, "unknown"))
	return "r10/cave_boundaries\t" .. checked .. "\t" .. routes .. "\tthree_reported_columns=natural\n"
end
