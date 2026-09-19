-- Pure reconstruction and comparison of every structurally valid lumen a
-- candidate could write.  The baseline supplies target coordinates and native
-- solid positions; the authored-world pass never derives either from its own
-- modified nodes.

return function()
	local function key(x, y, z)
		return x .. "/" .. y .. "/" .. z
	end

	local function parse_key(value)
		local x, y, z = value:match("^(-?%d+)/(-?%d+)/(-?%d+)$")
		assert(x and y and z, "R8-MAP-A volume coordinate differs")
		return tonumber(x), tonumber(y), tonumber(z)
	end

	local function rounded(numerator, denominator)
		if numerator < 0 then
			return -math.floor((-numerator * 2 + denominator) / (denominator * 2))
		end
		return math.floor((numerator * 2 + denominator) / (denominator * 2))
	end

	local function lumen(candidate, target)
		local result = {}
		local function offer(x, y, z)
			local position_key = key(x, y, z)
			if not result[position_key] then result[position_key] = {x, y, z} end
		end
		local target_x, target_y, target_z = target[1], target[2], target[3]
		if candidate.kind == "sinkhole" then
			local steps = candidate.mouth_y + 1 - target_y
			for step = 0, steps do
				local y = candidate.mouth_y + 1 - step
				local center_x = candidate.mouth_x + rounded(
					(target_x - candidate.mouth_x) * step, steps)
				local center_z = candidate.mouth_z + rounded(
					(target_z - candidate.mouth_z) * step, steps)
				local radius = step <= 2 and 2 or 1
				for dx = -radius, radius do for dz = -radius, radius do
					if dx * dx + dz * dz <= radius * radius then
						offer(center_x + dx, y, center_z + dz)
					end
				end end
			end
		else
			for step = 0, candidate.length - 1 do
				local center_x = candidate.mouth_x + rounded(
					(target_x - candidate.mouth_x) * step, candidate.length - 1)
				local center_y = candidate.mouth_y + 1 + rounded(
					(target_y - candidate.mouth_y - 1) * step,
					candidate.length - 1)
				local center_z = candidate.mouth_z + rounded(
					(target_z - candidate.mouth_z) * step, candidate.length - 1)
				for side = -candidate.radius, candidate.radius do
					local absolute_side = math.abs(side)
					local half = absolute_side == 0 and candidate.radius or
						(absolute_side < candidate.radius and candidate.radius - 1 or 0)
					for dy = -half, half do
						offer(center_x - candidate.direction_z * side,
							center_y + dy, center_z + candidate.direction_x * side)
					end
				end
			end
		end
		return result
	end

	local function possible(candidate, targets)
		local result, count = {}, 0
		for target_index = 1, #targets do
			for position_key, row in pairs(lumen(candidate, targets[target_index])) do
				if not result[position_key] then
					result[position_key], count = row, count + 1
				end
			end
		end
		return result, count
	end

	local module = {key = key, lumen = lumen, possible = possible}

	function module.capture(candidate, targets, node_name)
		local positions, count = possible(candidate, targets)
		local solids = {}
		for position_key, row in pairs(positions) do
			if node_name(row[1], row[2], row[3]) ~= "air" then
				solids[#solids + 1] = position_key
			end
		end
		table.sort(solids)
		return count, solids
	end

	function module.inspect(candidate, proof, node_name, globally_expected,
			comparison_solids)
		local positions, count = possible(candidate, proof.valid_targets or {})
		assert(count == proof.possible_voxels,
			"R8-MAP-A possible writer volume differs")
		local solid_rows = comparison_solids or proof.baseline_solids or {}
		local options = proof.connected_targets or {}
		if proof.eligible and #options == 0 then
			options = {{target = proof.target, voxel_count = proof.voxel_count}}
		end
		local best_unexpected, best_first
		for option_index = 1, #options do
			local option = options[option_index]
			local expected = lumen(candidate, option.target)
			local expected_count, expected_air = 0, true
			for _, row in pairs(expected) do
				expected_count = expected_count + 1
				if node_name(row[1], row[2], row[3]) ~= "air" then
					expected_air = false
				end
			end
			assert(expected_count == option.voxel_count,
				"R8-MAP-A expected lumen volume differs")
			local expected_changes, unexpected_voxels, first_unexpected = 0, 0, nil
			for index = 1, #solid_rows do
				local position_key = solid_rows[index]
				assert(positions[position_key],
					"R8-MAP-A baseline solid escaped possible volume")
				local x, y, z = parse_key(position_key)
				if node_name(x, y, z) == "air" then
					if expected[position_key] then
						expected_changes = expected_changes + 1
					elseif globally_expected and globally_expected[position_key] then
						-- Candidate volumes may overlap.  A voxel independently
						-- authorized by another baseline proof is not an extra carve.
					else
						unexpected_voxels = unexpected_voxels + 1
						if not first_unexpected then first_unexpected = position_key end
					end
				end
			end
			if expected_air and expected_changes > 0 and unexpected_voxels == 0 then
				return true, true, false, 0, nil
			end
			if best_unexpected == nil or unexpected_voxels < best_unexpected then
				best_unexpected, best_first = unexpected_voxels, first_unexpected
			end
		end
		if best_unexpected == nil then
			best_unexpected = 0
			for index = 1, #solid_rows do
				local position_key = solid_rows[index]
				local x, y, z = parse_key(position_key)
				if node_name(x, y, z) == "air" and not
						(globally_expected and globally_expected[position_key]) then
					best_unexpected = best_unexpected + 1
					if not best_first then best_first = position_key end
				end
			end
		end
		return false, false, best_unexpected > 0, best_unexpected, best_first
	end

	return module
end
