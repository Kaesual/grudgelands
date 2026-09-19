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

	-- Select at most one complete option per candidate whose union equals the
	-- complete observed solid-to-air change set.  A shared voxel is therefore
	-- excused only by an option belonging to another candidate that the same
	-- exact audit actually selected; alternatives of one candidate can never
	-- excuse each other.
	function module.audit(records)
		local actual, actual_count, first_actual = {}, 0, nil
		local coverers = {}
		for record_index = 1, #records do
			local record = records[record_index]
			for position_key in pairs(record.actual) do
				if not actual[position_key] then
					actual[position_key], actual_count = true, actual_count + 1
					if not first_actual or position_key < first_actual then
						first_actual = position_key
					end
				end
			end
			for option_index = 1, #record.options do
				local option = record.options[option_index]
				for position_key in pairs(option.changes) do
					local rows = coverers[position_key]
					if not rows then rows = {}; coverers[position_key] = rows end
					rows[#rows + 1] = option
				end
			end
		end

		local chosen, covered, covered_count = {}, {}, 0
		local solution
		local function choose_uncovered()
			local selected, selected_rows
			for position_key in pairs(actual) do
				if not covered[position_key] then
					local usable = {}
					for _, option in ipairs(coverers[position_key] or {}) do
						if not chosen[option.candidate_id] then
							usable[#usable + 1] = option
						end
					end
					if #usable == 0 then return position_key, usable end
					if not selected_rows or #usable < #selected_rows then
						selected, selected_rows = position_key, usable
					end
				end
			end
			return selected, selected_rows
		end
		local function search()
			if covered_count == actual_count then
				solution = {}
				for candidate_id, option in pairs(chosen) do
					solution[candidate_id] = option
				end
				return true
			end
			local _, options = choose_uncovered()
			if not options or #options == 0 then return false end
			table.sort(options, function(left, right)
				if left.change_count ~= right.change_count then
					return left.change_count > right.change_count
				end
				return left.candidate_id < right.candidate_id
			end)
			for _, option in ipairs(options) do
				local added = {}
				chosen[option.candidate_id] = option
				for position_key in pairs(option.changes) do
					-- A prepared complete option may contain only observed changes.
					if not actual[position_key] then
						chosen[option.candidate_id] = nil
						return false
					end
					if not covered[position_key] then
						covered[position_key] = true
						covered_count = covered_count + 1
						added[#added + 1] = position_key
					end
				end
				if search() then return true end
				for index = 1, #added do
					covered[added[index]] = nil
					covered_count = covered_count - 1
				end
				chosen[option.candidate_id] = nil
			end
			return false
		end

		if actual_count == 0 then solution = {} else search() end
		if solution then
			local accepted_count = 0
			for _ in pairs(solution) do accepted_count = accepted_count + 1 end
			return {accepted = solution, accepted_count = accepted_count,
				unexpected_candidates = 0, unexpected_voxels = 0}
		end
		local unexpected_records = {}
		local unexpected_candidates = 0
		for record_index = 1, #records do
			local record = records[record_index]
			if record.actual_count > 0 then
				unexpected_records[record.id] = record.actual_count
				unexpected_candidates = unexpected_candidates + 1
			end
		end
		return {accepted = {}, accepted_count = 0,
			unexpected_candidates = unexpected_candidates,
			unexpected_voxels = actual_count, unexpected_records = unexpected_records,
			first_unexpected = first_actual}
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
