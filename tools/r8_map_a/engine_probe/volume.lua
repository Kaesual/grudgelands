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

	-- Capture one candidate's immutable comparison input and every complete
	-- native-connected lumen that could explain its observed solid-to-air
	-- changes.  Options retain candidate_id so one candidate can authorize at
	-- most one alternative in the global audit.
	function module.prepare(id, candidate, proof, node_name, comparison_solids)
		local positions, count = possible(candidate, proof.valid_targets or {})
		assert(count == proof.possible_voxels,
			"R8-MAP-A possible writer volume differs")
		local solid_rows = comparison_solids or proof.baseline_solids or {}
		local baseline_solid, actual, actual_count = {}, {}, 0
		for index = 1, #solid_rows do
			local position_key = solid_rows[index]
			assert(positions[position_key],
				"R8-MAP-A baseline solid escaped possible volume")
			baseline_solid[position_key] = true
			local x, y, z = parse_key(position_key)
			if node_name(x, y, z) == "air" then
				actual[position_key], actual_count = true, actual_count + 1
			end
		end

		local connected = proof.connected_targets or {}
		if proof.eligible and #connected == 0 then
			connected = {{target = proof.target, voxel_count = proof.voxel_count}}
		end
		local options, signatures = {}, {}
		for option_index = 1, #connected do
			local source = connected[option_index]
			local expected = lumen(candidate, source.target)
			local expected_count, expected_air = 0, true
			local changes, change_rows = {}, {}
			for position_key, row in pairs(expected) do
				expected_count = expected_count + 1
				if node_name(row[1], row[2], row[3]) ~= "air" then
					expected_air = false
				end
				if baseline_solid[position_key] then
					changes[position_key] = true
					change_rows[#change_rows + 1] = position_key
				end
			end
			assert(expected_count == source.voxel_count,
				"R8-MAP-A expected lumen volume differs")
			table.sort(change_rows)
			local signature = table.concat(change_rows, "\n")
			if expected_air and #change_rows > 0 and not signatures[signature] then
				signatures[signature] = true
				options[#options + 1] = {candidate_id = id,
					target = source.target, changes = changes,
					change_count = #change_rows}
			end
		end
		return {id = id, actual = actual, actual_count = actual_count,
			options = options}
	end

	-- Select at most one complete option per candidate.  A selected candidate's
	-- actual changes must equal that option plus voxels owned by other selected
	-- candidates.  The best valid assignment minimizes unexplained changes, then
	-- minimizes owners; alternatives of one candidate can never excuse each
	-- other.
	function module.audit(records)
		local actual, actual_count, first_actual = {}, 0, nil
		local active, record_by_id = {}, {}
		for record_index = 1, #records do
			local record = records[record_index]
			record_by_id[record.id] = record
			for position_key in pairs(record.actual) do
				if not actual[position_key] then
					actual[position_key], actual_count = true, actual_count + 1
					if not first_actual or position_key < first_actual then
						first_actual = position_key
					end
				end
			end
			if record.actual_count > 0 and #record.options > 0 then
				active[#active + 1] = record
			end
		end

		local chosen, best, best_unexpected, best_count = {}, nil, nil, nil
		local function evaluate()
			local owners, selected_count = {}, 0
			for candidate_id, option in pairs(chosen) do
				selected_count = selected_count + 1
				for position_key in pairs(option.changes) do
					assert(actual[position_key],
						"R8-MAP-A complete option escaped observed changes")
					local rows = owners[position_key]
					if not rows then rows = {}; owners[position_key] = rows end
					rows[candidate_id] = true
				end
			end
			for candidate_id, option in pairs(chosen) do
				for position_key in pairs(record_by_id[candidate_id].actual) do
					if not option.changes[position_key] then
						local other = false
						for owner_id in pairs(owners[position_key] or {}) do
							if owner_id ~= candidate_id then other = true end
						end
						if not other then return end
					end
				end
			end
			local unexpected = 0
			for position_key in pairs(actual) do
				if not owners[position_key] then unexpected = unexpected + 1 end
			end
			if best_unexpected == nil or unexpected < best_unexpected or
					(unexpected == best_unexpected and selected_count < best_count) then
				best, best_unexpected, best_count = {}, unexpected, selected_count
				for candidate_id, option in pairs(chosen) do best[candidate_id] = option end
			end
		end
		local function search(index)
			local record = active[index]
			if not record then evaluate(); return end
			for option_index = 1, #record.options do
				chosen[record.id] = record.options[option_index]
				search(index + 1)
			end
			chosen[record.id] = nil
			search(index + 1)
		end
		search(1)

		local explained, accepted_explained = {}, {}
		for _, option in pairs(best or {}) do
			for position_key in pairs(option.changes) do
				explained[position_key], accepted_explained[position_key] = true, true
			end
		end
		-- A rejected transaction is still compared with its closest complete
		-- lumen so the unexpected-voxel count is the set difference, not the
		-- entire malformed transaction.  Its lumen never becomes an accepted
		-- owner and therefore cannot excuse another candidate.
		for record_index = 1, #records do
			local record = records[record_index]
			if not (best or {})[record.id] and record.actual_count > 0 then
				local closest, closest_extra
				for option_index = 1, #record.options do
					local option, extra = record.options[option_index], 0
					for position_key in pairs(record.actual) do
						if not option.changes[position_key] and
								not accepted_explained[position_key] then
							extra = extra + 1
						end
					end
					if closest_extra == nil or extra < closest_extra then
						closest, closest_extra = option, extra
					end
				end
				if closest then
					for position_key in pairs(closest.changes) do
						explained[position_key] = true
					end
				end
			end
		end
		local unexpected_records, unexpected_candidates, first_unexpected = {}, 0, nil
		local record_order = {}
		for record_index = 1, #records do record_order[record_index] = records[record_index] end
		table.sort(record_order, function(left, right) return left.id < right.id end)
		for position_key in pairs(actual) do
			if not explained[position_key] then
				if not first_unexpected or position_key < first_unexpected then
					first_unexpected = position_key
				end
				for record_index = 1, #record_order do
					local record = record_order[record_index]
					if record.actual[position_key] then
						unexpected_records[record.id] =
							(unexpected_records[record.id] or 0) + 1
						break
					end
				end
			end
		end
		for _ in pairs(unexpected_records) do
			unexpected_candidates = unexpected_candidates + 1
		end
		local final_unexpected = 0
		for position_key in pairs(actual) do
			if not explained[position_key] then final_unexpected = final_unexpected + 1 end
		end
		return {accepted = best or {}, accepted_count = best_count or 0,
			unexpected_candidates = unexpected_candidates,
			unexpected_voxels = final_unexpected,
			unexpected_records = unexpected_records,
			first_unexpected = first_unexpected or first_actual,
			uncovered_by_any = final_unexpected}
	end

	-- Single-candidate convenience used by the portable mutation KAT.  The
	-- engine uses prepare + one global audit so legitimate cross-candidate
	-- overlaps retain their accepting candidate owner.
	function module.inspect(candidate, proof, node_name, comparison_solids)
		local id = "fixture"
		local record = module.prepare(id, candidate, proof, node_name,
			comparison_solids)
		local audited = module.audit({record})
		local accepted = audited.accepted_count > 0
		return accepted, accepted, audited.unexpected_voxels > 0,
			audited.unexpected_voxels, audited.first_unexpected
	end

	return module
end
