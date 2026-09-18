-- Engine cave-mouth probe with an independent writer-disabled baseline.
-- cases.lua is revision-bound; baseline.lua is emitted by the disabled run and
-- copied beside this file for the carved-world comparison.

grug_r8_map_a_engine_probe = {}

local modpath = core.get_modpath(core.get_current_modname())
local cases = dofile(modpath .. "/cases.lua")
local engine_seed = core.get_mapgen_setting("seed")
assert(cases.schema == "grug_r8_map_a_engine_cases_v2" and
	cases.seed == engine_seed, "R8-MAP-A engine cases differ")
local baseline_mode = core.settings:get_bool(
	"grug_mapgen_r8_cave_writer_disabled", false)
local baseline
if not baseline_mode then
	baseline = dofile(modpath .. "/baseline.lua")
	assert(baseline.schema == "grug_r8_map_a_native_baseline_v1" and
		baseline.seed == engine_seed and baseline.revision == cases.revision,
		"R8-MAP-A native baseline differs")
end

local COMPONENT_RADIUS, COMPONENT_MINIMUM = 12, 24
local directions = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
	{0, 0, 1}, {0, 0, -1}}

local function chunk_origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

local function key(x, y, z)
	return x .. "/" .. y .. "/" .. z
end

local function candidate_key(region, candidate)
	return table.concat({region.id, candidate.cell_x, candidate.cell_z,
		candidate.mouth_x, candidate.mouth_y, candidate.mouth_z}, "/")
end

local function excluded_lookup(candidate)
	local result = {}
	for index = 1, #(candidate.excluded or {}) do
		result[candidate.excluded[index]] = true
	end
	return result
end

local function writer_column_allowed(candidate, excluded, x, z)
	return grug_zones.water_class_at(x, z) == "land" and
		grug_zones.id_at(x, z) == candidate.zone_id and
		not excluded[(x - candidate.mouth_x) .. "/" ..
			(z - candidate.mouth_z)]
end

local function cave_round(numerator, denominator)
	if numerator < 0 then
		return -math.floor((-numerator * 2 + denominator) / (denominator * 2))
	end
	return math.floor((numerator * 2 + denominator) / (denominator * 2))
end

local function node_class(x, y, z)
	local name = core.get_node({x = x, y = y, z = z}).name
	if name == "air" then return "air" end
	local definition = core.registered_nodes[name] or {}
	local groups = definition.groups or {}
	if definition.liquidtype and definition.liquidtype ~= "none" then return "liquid" end
	if groups.ore and groups.ore > 0 or groups.grug_resource and
			groups.grug_resource > 0 or name:find(":stone_with_", 1, true) or
			name:find(":slate_with_", 1, true) or
			name:find(":basalt_with_", 1, true) or
			name:find(":granite_with_", 1, true) or
			name:find(":emberrock_with_", 1, true) or
			name:find(":abyssal_rock_with_", 1, true) then
		return "ore"
	end
	if groups.tree and groups.tree > 0 or groups.leaves and groups.leaves > 0 or
			groups.flora and groups.flora > 0 or groups.attached_node and
			groups.attached_node > 0 then
		return "natural"
	end
	if groups.stone and groups.stone > 0 or groups.soil and groups.soil > 0 or
			groups.sand and groups.sand > 0 or groups.grug_stratum and
			groups.grug_stratum > 0 or name == "default:gravel" or
			name == "default:clay" or name == "default:mossycobble" then
		return "natural"
	end
	return "foreign"
end

local function lumen_for(candidate, target_x, target_y, target_z, excluded)
	local voxels, seen, valid, invalid = {}, {}, true, nil
	local min_x, min_y, min_z = candidate.owner_min_x, candidate.owner_min_y,
		candidate.owner_min_z
	local max_x, max_y, max_z = min_x + 79, min_y + 79, min_z + 79
	local function offer(x, y, z)
		local position_key = key(x, y, z)
		if seen[position_key] then return end
		seen[position_key] = true
		local terrain_y = grug_zones.terrain_height_at(x, z)
		local dx, dz = x - candidate.mouth_x, z - candidate.mouth_z
		if x < min_x or x > max_x or y < min_y or y > max_y or z < min_z or
				z > max_z then
			valid, invalid = false, "owner:" .. key(x, y, z)
			return
		elseif not writer_column_allowed(candidate, excluded, x, z) then
			valid, invalid = false, "excluded:" .. key(x, y, z)
			return
		elseif y > terrain_y and not (dx * dx + dz * dz <= 4 and
				y <= candidate.mouth_y + 1) then
			valid = false
			invalid = "terrain:" .. key(x, y, z)
			return
		end
		local class = node_class(x, y, z)
		if class ~= "air" and class ~= "natural" then
			valid = false
			invalid = class .. ":" .. core.get_node({x = x, y = y, z = z}).name ..
				":" .. key(x, y, z)
			return
		end
		voxels[#voxels + 1] = {x, y, z}
	end
	if candidate.kind == "sinkhole" then
		local steps = candidate.mouth_y + 1 - target_y
		for step = 0, steps do
			local y = candidate.mouth_y + 1 - step
			local center_x = candidate.mouth_x + cave_round(
				(target_x - candidate.mouth_x) * step, steps)
			local center_z = candidate.mouth_z + cave_round(
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
			local center_x = candidate.mouth_x + cave_round(
				(target_x - candidate.mouth_x) * step, candidate.length - 1)
			local center_y = candidate.mouth_y + 1 + cave_round(
				(target_y - candidate.mouth_y - 1) * step, candidate.length - 1)
			local center_z = candidate.mouth_z + cave_round(
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
	return valid and voxels or nil, seen, invalid
end

local function component_proof(candidate, target, lumen)
	local owner_max_x, owner_max_y, owner_max_z = candidate.owner_min_x + 79,
		candidate.owner_min_y + 79, candidate.owner_min_z + 79
	local min_x = math.max(candidate.owner_min_x, target[1] - COMPONENT_RADIUS)
	local max_x = math.min(owner_max_x, target[1] + COMPONENT_RADIUS)
	local min_y = math.max(candidate.owner_min_y, target[2] - COMPONENT_RADIUS)
	local max_y = math.min(owner_max_y, target[2] + COMPONENT_RADIUS)
	local min_z = math.max(candidate.owner_min_z, target[3] - COMPONENT_RADIUS)
	local max_z = math.min(owner_max_z, target[3] + COMPONENT_RADIUS)
	local surface_cache = {}
	local function baseline_surface(x, z)
		local column_key = x .. "/" .. z
		if surface_cache[column_key] ~= nil then
			return surface_cache[column_key] ~= false and surface_cache[column_key] or nil
		end
		for y = owner_max_y, candidate.owner_min_y, -1 do
			local class = node_class(x, y, z)
			if class ~= "air" and class ~= "liquid" then
				surface_cache[column_key] = y
				return y
			end
		end
		surface_cache[column_key] = false
		return nil
	end
	local queue, seen, head = {{target[1], target[2], target[3]}},
		{[key(target[1], target[2], target[3])] = true}, 1
	local outside, touches_sky, continues = 0, false, false
	while queue[head] do
		local row = queue[head]
		head = head + 1
		local surface = baseline_surface(row[1], row[3])
		if surface == nil or row[2] > surface then touches_sky = true end
		if not lumen[key(row[1], row[2], row[3])] then outside = outside + 1 end
		if row[1] == min_x or row[1] == max_x or row[2] == min_y or
				row[2] == max_y or row[3] == min_z or row[3] == max_z then
			continues = true
		end
		for index = 1, #directions do
			local delta = directions[index]
			local x, y, z = row[1] + delta[1], row[2] + delta[2],
				row[3] + delta[3]
			local position_key = key(x, y, z)
			if not seen[position_key] and x >= min_x and x <= max_x and
					y >= min_y and y <= max_y and z >= min_z and z <= max_z and
					node_class(x, y, z) == "air" then
				seen[position_key] = true
				queue[#queue + 1] = {x, y, z}
			end
		end
	end
	return continues and not touches_sky and outside >= COMPONENT_MINIMUM,
		outside, #queue, touches_sky
end

local function baseline_plan(candidate)
	if candidate.minimum_y < candidate.owner_min_y then
		return {eligible = false, reason = "outside_owner"}
	end
	local excluded = excluded_lookup(candidate)
	local search_x = candidate.kind == "hillside" and candidate.mouth_x +
		candidate.direction_x * (candidate.length - 1) or candidate.mouth_x
	local search_z = candidate.kind == "hillside" and candidate.mouth_z +
		candidate.direction_z * (candidate.length - 1) or candidate.mouth_z
	local radius = candidate.search_radius or candidate.radius
	local targets = {}
	for radius_squared = 0, radius * radius do
		if #targets >= 64 then break end
		for dz = -radius, radius do
			if #targets >= 64 then break end
			for dx = -radius, radius do
			if dx * dx + dz * dz == radius_squared then
				local x, z = search_x + dx, search_z + dz
				if x >= candidate.owner_min_x and x <= candidate.owner_min_x + 79 and
						z >= candidate.owner_min_z and z <= candidate.owner_min_z + 79 and
						writer_column_allowed(candidate, excluded, x, z) then
					local roof = 0
					local ceiling = math.min(candidate.mouth_y,
						grug_zones.terrain_height_at(x, z))
					for depth = 1, candidate.maximum_depth do
						local y = ceiling - depth
						local class = node_class(x, y, z)
						if class == "air" and roof >= 3 then
							targets[#targets + 1] = {x, y, z}
							break
						elseif class == "natural" then roof = roof + 1
						elseif class ~= "air" then roof = 0 end
					end
				end
			end
			end
		end
	end
	local valid_lumens, component_rejections, first_invalid = 0, 0, nil
	for target_index = 1, #targets do
		local target = targets[target_index]
		local voxels, lumen, invalid = lumen_for(candidate, target[1], target[2],
			target[3], excluded)
		if invalid and not first_invalid then first_invalid = invalid end
		if voxels then
			valid_lumens = valid_lumens + 1
			local connected, outside, component, sky =
				component_proof(candidate, target, lumen)
			if connected then
				return {eligible = true, target = target, voxel_count = #voxels,
					outside = outside, component = component, sky = sky}
			end
			component_rejections = component_rejections + 1
		end
	end
	local air_targets = #targets
	local reason = air_targets == 0 and "no_air_target" or
		valid_lumens == 0 and "no_valid_lumen" or "component_rejected"
	return {eligible = false, reason = reason, air_targets = air_targets,
		valid_lumens = valid_lumens, component_rejections = component_rejections,
		first_invalid = first_invalid}
end

local function carved_against_baseline(candidate, proof)
	if not proof or not proof.eligible then return false, false, 0 end
	local voxels = lumen_for(candidate, proof.target[1], proof.target[2],
		proof.target[3], excluded_lookup(candidate))
	if not voxels or #voxels ~= proof.voxel_count then return false, false, 0 end
	local air = 0
	for index = 1, #voxels do
		local row = voxels[index]
		if core.get_node({x = row[1], y = row[2], z = row[3]}).name ~= "air" then
			return false, false, air
		end
		air = air + 1
	end
	return true, true, air
end

local work, totals, results = {}, {}, {}
for region_index = 1, #cases.regions do
	local region = cases.regions[region_index]
	totals[region.id] = {candidates = #region.candidates, carved = 0,
		connected = 0, eligible = 0, reasons = {}}
	for candidate_index = 1, #region.candidates do
		work[#work + 1] = {region = region, candidate = region.candidates[candidate_index]}
	end
end

local current = 0
local function finish()
	if baseline_mode then
		local payload = {schema = "grug_r8_map_a_native_baseline_v1",
			revision = cases.revision, seed = engine_seed, results = results}
		local path = core.get_worldpath() .. "/r8_map_a_baseline.lua"
		assert(core.safe_file_write(path, core.serialize(payload)),
			"R8-MAP-A baseline write failed")
		core.log("action", "GRUG_R8_MAP_A_BASELINE_FILE\t" .. path)
	end
	for region_index = 1, #cases.regions do
		local region = cases.regions[region_index]
		local total = totals[region.id]
		core.log("action", table.concat({"GRUG_R8_MAP_A",
			baseline_mode and "baseline" or "after", cases.revision, engine_seed,
			region.id, total.candidates, total.carved, total.connected,
			total.eligible}, "\t"))
		local reason_rows = {}
		for reason, count in pairs(total.reasons) do
			reason_rows[#reason_rows + 1] = reason .. "=" .. count
		end
		table.sort(reason_rows)
		if #reason_rows > 0 then
			core.log("action", "GRUG_R8_MAP_A_REASONS\t" .. region.id .. "\t" ..
				table.concat(reason_rows, ","))
		end
	end
	core.request_shutdown("R8-MAP-A cave measurement complete", false, 0.1)
end

local function next_candidate()
	current = current + 1
	local item = work[current]
	if not item then finish() return end
	local candidate = item.candidate
	local last_x = candidate.mouth_x + candidate.direction_x *
		(candidate.length - 1)
	local last_z = candidate.mouth_z + candidate.direction_z *
		(candidate.length - 1)
	local minp = {x = chunk_origin(math.min(candidate.mouth_x, last_x) -
		(candidate.search_radius or candidate.radius)),
		y = chunk_origin(candidate.minimum_y),
		z = chunk_origin(math.min(candidate.mouth_z, last_z) -
		(candidate.search_radius or candidate.radius))}
	local maxp = {x = chunk_origin(math.max(candidate.mouth_x, last_x) +
		(candidate.search_radius or candidate.radius)) + 79,
		y = chunk_origin(candidate.mouth_y + COMPONENT_RADIUS) + 79,
		z = chunk_origin(math.max(candidate.mouth_z, last_z) +
		(candidate.search_radius or candidate.radius)) + 79}
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		local row_key = candidate_key(item.region, candidate)
		local total = totals[item.region.id]
		if baseline_mode then
			local proof = baseline_plan(candidate)
			results[row_key] = proof
			if proof.eligible then total.eligible = total.eligible + 1 end
			if not proof.eligible then
				total.reasons[proof.reason] = (total.reasons[proof.reason] or 0) + 1
			end
		else
			local proof = baseline.results[row_key]
			assert(proof, "R8-MAP-A candidate absent from baseline: " .. row_key)
			if proof.eligible then total.eligible = total.eligible + 1 end
			local carved, connected = carved_against_baseline(candidate, proof)
			if carved then total.carved = total.carved + 1 end
			if connected then total.connected = total.connected + 1 end
		end
		core.after(0, next_candidate)
	end)
end

core.register_on_mods_loaded(function()
	core.after(0, next_candidate)
	core.after(1800, function()
		core.request_shutdown("R8-MAP-A cave measurement timeout", false, 1)
	end)
end)
