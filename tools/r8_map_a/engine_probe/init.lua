-- Disposable engine probe. Candidate tables are generated from the exact
-- revision before the run and copied beside this file as cases.lua.

grug_r8_map_a_engine_probe = {}

local modpath = core.get_modpath(core.get_current_modname())
local cases = dofile(modpath .. "/cases.lua")
local engine_seed = core.get_mapgen_setting("seed")
assert(cases.schema == "grug_r8_map_a_engine_cases_v1" and
	cases.seed == engine_seed, "R8-MAP-A engine cases differ")

local function chunk_origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

local function key(x, y, z)
	return x .. "/" .. y .. "/" .. z
end

local function possible_voxels(candidate)
	local result = {}
	if candidate.kind == "sinkhole" then
		for y = candidate.mouth_y + 1,
				candidate.mouth_y - candidate.maximum_depth, -1 do
			local depth = candidate.mouth_y + 1 - y
			local radius = depth <= 2 and 2 or 1
			for dx = -radius, radius do
				for dz = -radius, radius do
					if dx * dx + dz * dz <= radius * radius then
						result[key(candidate.mouth_x + dx, y,
							candidate.mouth_z + dz)] = true
					end
				end
			end
		end
	else
		for step = 0, candidate.length - 1 do
			local x = candidate.mouth_x + candidate.direction_x * step
			local z = candidate.mouth_z + candidate.direction_z * step
			-- The before path descends one per four nodes. The after writer may
			-- descend farther; this superset covers its whole bounded connection.
			for y = candidate.mouth_y + 3,
					candidate.mouth_y - candidate.maximum_depth - candidate.radius do
				for side = -candidate.radius, candidate.radius do
					local sx = x - candidate.direction_z * side
					local sz = z + candidate.direction_x * side
					result[key(sx, y, sz)] = true
				end
			end
		end
	end
	return result
end

local directions = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
	{0, 0, 1}, {0, 0, -1}}

local function inspect_sinkhole(candidate)
	if core.get_node({x = candidate.mouth_x, y = candidate.mouth_y,
			z = candidate.mouth_z}).name ~= "air" then return false, false, 0 end
	local signature = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for index = 1, #signature do
		local delta = signature[index]
		if core.get_node({x = candidate.mouth_x + delta[1], y = candidate.mouth_y,
				z = candidate.mouth_z + delta[2]}).name ~= "air" then
			return false, false, 0
		end
	end
	local reach = (candidate.search_radius or 8) + 12
	local queue = {{candidate.mouth_x, candidate.mouth_y, candidate.mouth_z}}
	local seen = {[key(candidate.mouth_x, candidate.mouth_y,
		candidate.mouth_z)] = true}
	local depth_counts, head, visited = {}, 1, 0
	while queue[head] and visited < 30000 do
		local row = queue[head]
		head, visited = head + 1, visited + 1
		if row[2] <= candidate.mouth_y - 4 then
			depth_counts[row[2]] = (depth_counts[row[2]] or 0) + 1
		end
		for direction = 1, #directions do
			local delta = directions[direction]
			local x, y, z = row[1] + delta[1], row[2] + delta[2],
				row[3] + delta[3]
			local position_key = key(x, y, z)
			if not seen[position_key] and math.abs(x - candidate.mouth_x) <= reach and
					math.abs(z - candidate.mouth_z) <= reach and
					y >= candidate.mouth_y - candidate.maximum_depth - 4 and
					y <= candidate.mouth_y + 1 then
				seen[position_key] = true
				local dx, dz = x - candidate.mouth_x, z - candidate.mouth_z
			local below_ground = y <= grug_zones.terrain_height_at(x, z)
				local within_mouth = dx * dx + dz * dz <= 9
			if (below_ground or within_mouth or y <= candidate.mouth_y - 3) and
						core.get_node({x = x, y = y, z = z}).name == "air" then
					queue[#queue + 1] = {x, y, z}
				end
			end
		end
	end
	local connected = false
	local maximum_plane = 0
	for _, count in pairs(depth_counts) do
		if count > maximum_plane then maximum_plane = count end
		-- A radius-1 authored shaft has exactly five air nodes on one y plane.
		-- A sixth node is therefore outside the authored shaft and proves that
		-- the engine result opens into native cave air, including a narrow cave.
		if count >= 6 then connected = true break end
	end
	return true, connected, visited, maximum_plane
end

local function inspect(candidate)
	if candidate.kind == "sinkhole" then return inspect_sinkhole(candidate) end
	local mouth = core.get_node({x = candidate.mouth_x, y = candidate.mouth_y,
		z = candidate.mouth_z})
	if mouth.name ~= "air" then return false, false, 0 end
	local possible = possible_voxels(candidate)
	local queue = {{candidate.mouth_x, candidate.mouth_y, candidate.mouth_z}}
	local seen = {[key(candidate.mouth_x, candidate.mouth_y,
		candidate.mouth_z)] = true}
	local head, visited, connected = 1, 0, false
	while queue[head] and visited < 20000 do
		local row = queue[head]
		head, visited = head + 1, visited + 1
		for direction = 1, #directions do
			local delta = directions[direction]
			local x, y, z = row[1] + delta[1], row[2] + delta[2],
				row[3] + delta[3]
			local position_key = key(x, y, z)
			if not seen[position_key] then
				seen[position_key] = true
				if core.get_node({x = x, y = y, z = z}).name == "air" then
					if possible[position_key] then
						queue[#queue + 1] = {x, y, z}
					elseif y <= candidate.mouth_y - 4 and
							y <= grug_zones.terrain_height_at(x, z) - 3 then
						connected = true
					end
				end
			end
		end
	end
	return true, connected, visited
end

local function native_air_near(candidate)
	local radius = candidate.search_radius or candidate.radius
	for dz = -radius, radius do
		for dx = -radius, radius do
			if dx * dx + dz * dz <= radius * radius then
				local x, z = candidate.mouth_x + dx, candidate.mouth_z + dz
				local ceiling = math.min(candidate.mouth_y,
					grug_zones.terrain_height_at(x, z)) - 3
				for y = ceiling, candidate.mouth_y - candidate.maximum_depth, -1 do
					if core.get_node({x = x, y = y, z = z}).name == "air" then
						return true
					end
				end
			end
		end
	end
	return false
end

local work = {}
for region_index = 1, #cases.regions do
	local region = cases.regions[region_index]
	for candidate_index = 1, #region.candidates do
		work[#work + 1] = {region = region, candidate = region.candidates[candidate_index]}
	end
end
local totals = {}
for region_index = 1, #cases.regions do
	totals[cases.regions[region_index].id] = {candidates =
		#cases.regions[region_index].candidates, carved = 0, connected = 0,
		native_near = 0}
end

local current = 0
local function next_candidate()
	current = current + 1
	local item = work[current]
	if not item then
		for region_index = 1, #cases.regions do
			local region = cases.regions[region_index]
			local total = totals[region.id]
			core.log("action", table.concat({"GRUG_R8_MAP_A", cases.revision,
				engine_seed, region.id, total.candidates, total.carved,
				total.connected, total.native_near,
				total.first_connected or "none",
				total.first_disconnected or "none"}, "\t"))
		end
		core.request_shutdown("R8-MAP-A cave measurement complete", false, 0.1)
		return
	end
	local candidate = item.candidate
	local last_x = candidate.mouth_x + candidate.direction_x *
		(candidate.length - 1)
	local last_z = candidate.mouth_z + candidate.direction_z *
		(candidate.length - 1)
	local minp = {x = chunk_origin(math.min(candidate.mouth_x, last_x) -
		candidate.radius), y = chunk_origin(candidate.minimum_y),
		z = chunk_origin(math.min(candidate.mouth_z, last_z) - candidate.radius)}
	local maxp = {x = chunk_origin(math.max(candidate.mouth_x, last_x) +
		candidate.radius) + 79,
		y = chunk_origin(candidate.mouth_y + 3) + 79,
		z = chunk_origin(math.max(candidate.mouth_z, last_z) +
		candidate.radius) + 79}
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		local carved, connected, visited, maximum_plane = inspect(candidate)
		local total = totals[item.region.id]
		if carved then total.carved = total.carved + 1 end
		if connected then
			total.connected = total.connected + 1
			if not total.first_connected then
				total.first_connected = table.concat({candidate.kind,
					candidate.mouth_x, candidate.mouth_y, candidate.mouth_z}, "/")
			end
		end
		if carved and not connected and not total.first_disconnected then
			total.first_disconnected = table.concat({candidate.kind,
				candidate.mouth_x, candidate.mouth_y, candidate.mouth_z, visited,
				maximum_plane or 0}, "/")
		end
		if native_air_near(candidate) then total.native_near = total.native_near + 1 end
		core.after(0, next_candidate)
	end)
end

core.register_on_mods_loaded(function()
	core.after(0, next_candidate)
	core.after(900, function()
		core.request_shutdown("R8-MAP-A cave measurement timeout", false, 1)
	end)
end)
