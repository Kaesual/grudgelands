-- Portable immutable-CID KAT for the R8-MAP-A production writer seams.

return function(root)
	local function check(condition, message)
		if not condition then error("R8-MAP-A writer KAT: " .. message, 0) end
	end
	local settlement = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua")
	local _, _, surface_rules = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_content.lua")

	-- The exact post-change selector gates used by production: dry freshwater
	-- sand stops at two nodes, while ordinary wet beds retain their sand patch.
	check(surface_rules.coast_profile_applies("beach", 7, 8, false),
		"sea beach band is absent")
	check(not surface_rules.coast_profile_applies("beach", 3, 8, true),
		"freshwater sand lip exceeds two nodes")
	local ordinary_wet = surface_rules.wet_bed_names("grug_meadows", "default:dirt")
	local swamp_wet = surface_rules.wet_bed_names("grug_swamp", "grug_nodes:mud")
	check(ordinary_wet[2] == "default:sand" and
		swamp_wet[2] == "grug_nodes:mud", "wet-bed sand selector differs")

	-- Immutable strata input.  A two-node native gravel-ore blob lies directly
	-- under a synthetic lens and must survive; native stone at the next lens and
	-- exactly y=-37 changes, while the matching y=-38 lens is clipped.
	local stone_cid, gravel_cid = 10, 11
	local original, writes = {}, {}
	local function strata_index(_, y) return y + 46 end
	for y = -45, 5 do original[strata_index(0, y, 0)] = stone_cid end
	original[strata_index(0, -10, 0)] = gravel_cid
	original[strata_index(0, -11, 0)] = gravel_cid
	local written, clipped = settlement.r8_apply_strata({
		min_x = 0, max_x = 0, min_y = -45, max_y = 5, min_z = 0, max_z = 0,
		floor_y = -37, original_data = original, stone_cid = stone_cid,
		gravel_cid = gravel_cid, index_at = strata_index,
		column_values_at = function()
			return "land", 1, "zone", "grug_meadows", nil, 0, nil, nil, nil,
				nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
		end,
		static_exclusion_values_at = function() return nil end,
		housing_excluded_at = function() return false end,
		select_surface = function() return {filler_depth = 3} end,
		strata = {material_at = function(_, _, _, _, _, depth)
			if depth == 10 or depth == 11 or depth == 12 or
					depth == 37 or depth == 38 then return "default:clay" end
		end},
		content_ref = function(name) return name == "default:clay" and 7 or nil end,
		write = function(x, y, z, ref) writes[x .. "/" .. y .. "/" .. z] = ref end,
	})
	check(written == 2 and clipped == 3, "strata write/clip counts differ")
	check(writes["0/-10/0"] == nil and writes["0/-11/0"] == nil,
		"native gravel ore was overwritten")
	check(writes["0/-12/0"] == 7 and writes["0/-37/0"] == 7 and
		writes["0/-38/0"] == nil, "strata floor boundary differs")

	local min_x, max_x, min_y, max_y, min_z, max_z = -16, 16, -16, 20, -16, 16
	local sx, sy = max_x - min_x + 1, max_y - min_y + 1
	local function cave_index(x, y, z)
		return (z - min_z) * sx * sy + (y - min_y) * sx + (x - min_x) + 1
	end
	local function baseline(kind)
		local data, param2 = {}, {}
		for z = min_z, max_z do for y = min_y, max_y do for x = min_x, max_x do
			local index = cave_index(x, y, z)
			data[index], param2[index] = y > 10 and 0 or stone_cid, 0
		end end end
		if kind == "closed" then
			for z = -1, 1 do for y = 5, 6 do for x = -1, 1 do
				data[cave_index(x, y, z)] = 0
			end end end
		else
			for z = -1, 1 do for x = 0, 12 do
				data[cave_index(x, 6, z)] = 0
			end end
			if kind == "sky" then
				for y = 7, 10 do data[cave_index(12, y, 0)] = 0 end
			end
		end
		return data, param2
	end
	local cave = {kind = "sinkhole", zone_id = "zone", mouth_x = 0,
		mouth_y = 10, mouth_z = 0, direction_x = 0, direction_z = 0,
		length = 1, radius = 2, minimum_y = -14, search_radius = 0,
		maximum_depth = 10}
	local function cave_context(data, param2)
		return {min_x = min_x, max_x = max_x, min_y = min_y, max_y = max_y,
			min_z = min_z, max_z = max_z, original_data = data,
			original_param2 = param2, index_at = cave_index,
			classify = function(cid)
				if cid == 0 then return 1 end
				if cid == gravel_cid then return 5 end
				return 6
			end,
			column_values_at = function()
				return "land", 1, "zone", "grug_meadows", nil, 10, nil, nil, nil,
					nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
			end,
			static_exclusion_values_at = function() return nil end,
			housing_excluded_at = function() return false end}
	end
	local connected_data, connected_param2 = baseline("connected")
	local voxels, reason, proof = settlement.r8_plan_cave(
		cave_context(connected_data, connected_param2), cave)
	check(voxels and reason == "connected" and proof[4] >=
		settlement.r8_cave_component_minimum, "continuing native cave was rejected")
	local closed_data, closed_param2 = baseline("closed")
	local closed_voxels, closed_reason = settlement.r8_plan_cave(
		cave_context(closed_data, closed_param2), cave)
	check(closed_voxels == nil and closed_reason == "no_continuing_component",
		"closed native pocket was accepted")
	local sky_data, sky_param2 = baseline("sky")
	local sky_voxels, sky_reason = settlement.r8_plan_cave(
		cave_context(sky_data, sky_param2), cave)
	check(sky_voxels == nil and sky_reason == "no_continuing_component",
		"native sky bridge was accepted")

	return table.concat({"schema\tgrug_r8_map_a_writer_kat_v1",
		"surface\tsea=1/fresh_lip=2/wet_sand=1",
		"strata\twritten=" .. written .. "/floor_clipped=" .. clipped ..
			"/native_gravel=preserved",
		"caves\tconnected=" .. #voxels .. "/closed=rejected/sky=rejected/" ..
			"component=" .. proof[4]}, "\n") .. "\n"
end
