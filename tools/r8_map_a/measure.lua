-- LuaJIT-only fixed-layout census for the R8-MAP-A report.

return function(root)
	local offline = dofile(root .. "/tools/wp40/r6/offline.lua")(root)
	local loaded = offline.new_evidence("0", false)
	local planner, horizontal = loaded.planner_source, loaded.horizontal
	local select_surface = loaded.content.new_surface_selector("0", {
		column_values_at = planner.column_values_at,
		coast_profile_at = function() return nil end,
	})
	local after_select_surface = loaded.content.new_surface_selector("0", planner)
	local source = offline.source
	local sand = {}
	local runs, relief = {}, {}
	local strata_points = {}
	for index = 1, #source.zones do
		sand[source.zones[index].id] = {before_near = 0, before_away = 0,
			after_near = 0, after_away = 0, samples = 0}
		strata_points[index] = {}
	end
	local function consider_strata_point(zone_numeric, x, z)
		local points = strata_points[zone_numeric]
		local score = math.abs(x * 73856093 + z * 19349663) % 2147483647
		local point = {x = x, z = z, score = score}
		local inserted = false
		for index = 1, #points do
			if score < points[index].score then
				table.insert(points, index, point)
				inserted = true
				break
			end
		end
		if not inserted then points[#points + 1] = point end
		if #points > 6 then points[7] = nil end
	end
	for z = -3340, 3340, 8 do
		for x = -3740, 3740, 8 do
			local water_class, zone_numeric, _, biome, _, terrain_y, water_y,
				_, _, functional_kind, _, _, _, transition_kind, _, _, _, _, _, hard =
					planner.column_values_at(x, z)
			if water_class == "land" and zone_numeric then
				local zone_id = source.zones[zone_numeric].id
				local row = sand[zone_id]
				row.samples = row.samples + 1
				local profile, distance, width, freshwater, run_key, _, relief_profile =
					planner.coast_profile_at(x, z)
				local surface = select_surface(biome, x, z, water_y, terrain_y)
				local surface_name = surface and (biome == "grug_beach" and
					surface.shore or surface.top)
				local before = surface_name == "default:sand"
				local after_surface = after_select_surface(biome, x, z, water_y, terrain_y)
				local after_name = after_surface and (biome == "grug_beach" and
					after_surface.shore or after_surface.top)
				local after = after_name == "default:sand"
				local near = profile ~= nil
				if before then
					if near then row.before_near = row.before_near + 1
					else row.before_away = row.before_away + 1 end
				end
				if after then
					if near then row.after_near = row.after_near + 1
					else row.after_away = row.after_away + 1 end
				end
				if run_key and runs[run_key] then
					assert(runs[run_key].profile == profile and
						runs[run_key].freshwater == freshwater and
						runs[run_key].relief == relief_profile,
						"shore run changed profile/class: " .. run_key)
				elseif run_key then
					runs[run_key] = {profile = profile, freshwater = freshwater,
						relief = relief_profile, zone_numeric = zone_numeric}
					local rr = relief[relief_profile] or
						{beach = 0, bluff = 0, cliff = 0, terraced_cliff = 0, total = 0}
					relief[relief_profile] = rr
					rr[profile], rr.total = rr[profile] + 1, rr.total + 1
				end
				if water_y == nil and functional_kind == nil and
						transition_kind == nil and not hard and
						horizontal.static_exclusion_values_at(x, z) == nil and
						horizontal.housing_mask_id_at(x, z) == nil then
					consider_strata_point(zone_numeric, x, z)
				end
			end
		end
	end
	local sea = {beach = 0, bluff = 0, cliff = 0, terraced_cliff = 0, total = 0}
	local fresh = {beach = 0, bluff = 0, total = 0}
	local zone_runs = {}
	for index = 1, #source.zones do
		zone_runs[index] = {beach = 0, bluff = 0, cliff = 0,
			terraced_cliff = 0, total = 0}
	end
	for _, row in pairs(runs) do
		local target = row.freshwater and fresh or sea
		target[row.profile], target.total = target[row.profile] + 1, target.total + 1
		local zr = zone_runs[row.zone_numeric]
		zr[row.profile], zr.total = zr[row.profile] + 1, zr.total + 1
	end

	local candidates = {}
	for index = 1, #source.zones do candidates[source.zones[index].id] = 0 end
	local cx0, cz0 = planner.surface_cave_cell_at(-3740, -3340)
	local cx1, cz1 = planner.surface_cave_cell_at(3740, 3340)
	local candidate_total, hills, sinks = 0, 0, 0
	for cz = cz0, cz1 do for cx = cx0, cx1 do
		local record = planner.surface_cave_candidate_at_cell(cx, cz)
		if record then
			candidate_total = candidate_total + 1
			candidates[record.zone_id] = (candidates[record.zone_id] or 0) + 1
			if record.kind == "hillside" then hills = hills + 1 else sinks = sinks + 1 end
		end
	end end

	local strata_rule = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua").r8_strata_new("0", source)
	local eligible_zones, skipped_zones = {}, {}
	for index = 1, #source.zones do
		if #strata_points[index] > 0 then
			eligible_zones[#eligible_zones + 1] = index
		else
			skipped_zones[#skipped_zones + 1] = source.zones[index].id
		end
	end
	assert(#eligible_zones > 0, "fixed layout has no strata-eligible zones")
	local strata_min, strata_clips, strata_zones = 99, 0, {}
	local strata_hits = {}
	for sample = 1, 200 do
		local eligible_index = (sample - 1) % #eligible_zones + 1
		local wanted = eligible_zones[eligible_index]
		local zone = source.zones[wanted]
		local round = math.floor((sample - 1) / #eligible_zones)
		local points = strata_points[wanted]
		local point = points[round % #points + 1]
		local found_x, found_z = point.x, point.z
		local _, _, _, biome, _, terrain_y, water_y =
			planner.column_values_at(found_x, found_z)
		local surface = after_select_surface(biome, found_x, found_z, water_y, terrain_y)
		local materials = {}
		for depth = surface.filler_depth + 1, 40 do
			local material = strata_rule.material_at(zone.id, biome,
				surface.filler_depth, found_x, found_z, depth)
			if terrain_y - depth < -37 then
				strata_clips = strata_clips + 1
			elseif material and material ~= "default:stone" and
					material ~= "default:dirt" then
				materials[material] = true
				strata_hits[material] = (strata_hits[material] or 0) + 1
			end
		end
		local count = 0
		for _ in pairs(materials) do count = count + 1 end
		assert(count >= 2, "fixed-layout shaft lacks two materials for " .. zone.id)
		strata_min = math.min(strata_min, count)
		strata_zones[wanted] = true
	end
	local strata_zone_count = 0
	for _ in pairs(strata_zones) do strata_zone_count = strata_zone_count + 1 end

	local out = {"schema\tgrug_r8_map_a_measure_v1",
		"sampling\tsurface_grid=8/cardinal_near_water=16/seed=0",
		"profile_overall\tsea\t" .. table.concat({sea.total, sea.beach, sea.bluff,
			sea.cliff, sea.terraced_cliff}, "\t"),
		"profile_overall\tfresh\t" .. table.concat({fresh.total, fresh.beach,
			fresh.bluff, 0, 0}, "\t")}
	local relief_keys = {}
	for key in pairs(relief) do relief_keys[#relief_keys + 1] = key end
	table.sort(relief_keys)
	for _, key in ipairs(relief_keys) do
		local row = relief[key]
		out[#out + 1] = "profile_relief\t" .. key .. "\t" .. table.concat({row.total,
			row.beach, row.bluff, row.cliff, row.terraced_cliff}, "\t")
	end
	for index = 1, #source.zones do
		local zone = source.zones[index]
		local row = sand[zone.id]
		out[#out + 1] = "sand\t" .. zone.id .. "\t" .. table.concat({row.samples,
			row.before_near, row.before_away, row.after_near, row.after_away}, "\t")
		local zr = zone_runs[index]
		out[#out + 1] = "shore_runs\t" .. zone.id .. "\t" .. table.concat({zr.total,
			zr.beach, zr.bluff, zr.cliff, zr.terraced_cliff}, "\t")
	end
	out[#out + 1] = "mouths\t" .. table.concat({candidate_total, hills, sinks}, "\t")
	for index = 1, #source.zones do
		local zone = source.zones[index]
		out[#out + 1] = "mouth_zone\t" .. zone.id .. "\t" .. candidates[zone.id]
	end
	local material_names = {}
	for name in pairs(strata_hits) do material_names[#material_names + 1] = name end
	table.sort(material_names)
	out[#out + 1] = "strata\t" .. table.concat({200, strata_zone_count,
		strata_min, strata_clips}, "\t")
	for index = 1, #skipped_zones do
		out[#out + 1] = "strata_skipped_zone\t" .. skipped_zones[index] ..
			"\tno ordinary eligible column"
	end
	for index = 1, #material_names do
		local name = material_names[index]
		out[#out + 1] = "strata_material\t" .. name .. "\t" .. strata_hits[name]
	end
	return table.concat(out, "\n") .. "\n"
end
