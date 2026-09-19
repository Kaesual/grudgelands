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

	-- A closed 50-voxel native pocket touches the immutable owner's x=-16
	-- edge.  The old clipped proof box mistook that artificial boundary for
	-- continuation; the complete target +/-12 box cannot be proved here.
	local edge_data, edge_param2 = baseline("closed")
	local edge_count = 0
	local function edge_air(x, y, z)
		if edge_data[cave_index(x, y, z)] ~= 0 then edge_count = edge_count + 1 end
		edge_data[cave_index(x, y, z)] = 0
	end
	for z = -2, 2 do for y = -5, -4 do for x = -16, -13 do
		edge_air(x, y, z)
	end end end
	for y = -3, 3 do edge_air(-16, y, 0) end
	for x = -15, -13 do edge_air(x, -3, 0) end
	check(edge_count == 50, "owner-edge pocket population differs")
	local edge_cave = {kind = "hillside", zone_id = "zone", mouth_x = 0,
		mouth_y = 7, mouth_z = 0, direction_x = -1, direction_z = 0,
		length = 17, radius = 2, minimum_y = -14, search_radius = 0,
		maximum_depth = 10}
	local edge_voxels, edge_reason = settlement.r8_plan_cave(
		cave_context(edge_data, edge_param2), edge_cave)
	check(not settlement.r8_cave_proof_box_inside(min_x, min_y, min_z,
		max_x, max_y, max_z, -16, 3, 0),
		"owner-edge target received a complete proof box")
	check(edge_voxels == nil and edge_reason == "no_continuing_component",
		"owner-edge closed native pocket was accepted")

	-- The independent comparison covers every structurally valid target, even
	-- when the native proof rejected the candidate.  An extra carve in a later
	-- possible lumen is therefore separate from the accepted exact lumen.
	local volume = dofile(root ..
		"/tools/r8_map_a/engine_probe/volume.lua")()
	local volume_candidate = {kind = "sinkhole", mouth_x = 0, mouth_y = 7,
		mouth_z = 0, maximum_depth = 10}
	local target_a, target_b = {0, 3, 0}, {6, 3, 0}
	local possible_count, baseline_solids = volume.capture(volume_candidate,
		{target_a, target_b}, function() return "default:stone" end)
	local expected_positions = volume.lumen(volume_candidate, target_a)
	local expected_count = 0
	for _ in pairs(expected_positions) do
		expected_count = expected_count + 1
	end
	local alternative_positions = volume.lumen(volume_candidate, target_b)
	local alternative_count = 0
	for _ in pairs(alternative_positions) do
		alternative_count = alternative_count + 1
	end
	local proof_volume = {eligible = true, target = target_a,
		voxel_count = expected_count, valid_targets = {target_a, target_b},
		connected_targets = {{target = target_a, voxel_count = expected_count}},
		possible_voxels = possible_count, baseline_solids = baseline_solids}
	local carved, connected, unexpected, unexpected_voxels = volume.inspect(
		volume_candidate, proof_volume, function(x, y, z)
			return expected_positions[volume.key(x, y, z)] and "air" or "default:stone"
		end)
	check(carved and connected and not unexpected and unexpected_voxels == 0,
		"exact baseline-backed lumen was not recognized")
	local partial_key = next(expected_positions)
	local partial_carved, _, partial_unexpected, partial_voxels = volume.inspect(
		volume_candidate, proof_volume, function(x, y, z)
			return volume.key(x, y, z) == partial_key and "air" or "default:stone"
		end)
	check(not partial_carved and partial_unexpected and partial_voxels > 0,
		"partial lumen was hidden")
	local _, _, extra, extra_voxels = volume.inspect(volume_candidate,
		proof_volume, function() return "air" end)
	check(extra and extra_voxels > 0,
		"unexpected carve outside accepted lumen was hidden")
	local dual_proof = {eligible = true, target = target_a,
		voxel_count = expected_count, valid_targets = {target_a, target_b},
		connected_targets = {
			{target = target_a, voxel_count = expected_count},
			{target = target_b, voxel_count = alternative_count},
		}, possible_voxels = possible_count, baseline_solids = baseline_solids}
	local dual_carved, _, dual_unexpected, dual_voxels = volume.inspect(
		volume_candidate, dual_proof, function(x, y, z)
			local position_key = volume.key(x, y, z)
			return (expected_positions[position_key] or
				alternative_positions[position_key]) and "air" or "default:stone"
		end)
	check(not dual_carved and dual_unexpected and dual_voxels > 0,
		"two alternatives of one candidate were hidden")
	local rejected_proof = {eligible = false, valid_targets = {target_a},
		possible_voxels = 0, baseline_solids = {}}
	rejected_proof.possible_voxels, rejected_proof.baseline_solids = volume.capture(
		volume_candidate, rejected_proof.valid_targets,
		function() return "default:stone" end)
	local rejected_carved, _, rejected_unexpected = volume.inspect(volume_candidate,
		rejected_proof, function() return "air" end)
	check(not rejected_carved and rejected_unexpected,
		"rejected candidate carve was hidden")

	return table.concat({"schema\tgrug_r8_map_a_writer_kat_v2",
		"surface\tsea=1/fresh_lip=2/wet_sand=1",
		"strata\twritten=" .. written .. "/floor_clipped=" .. clipped ..
			"/native_gravel=preserved",
		"caves\tconnected=" .. #voxels .. "/closed=rejected/sky=rejected/" ..
			"edge_pocket=rejected/" ..
			"component=" .. proof[4],
		"checker\texact=connected/partial=" .. partial_voxels ..
			"/dual=" .. dual_voxels .. "/unexpected=" .. extra_voxels ..
			"/rejected=detected"}, "\n") .. "\n"
end
