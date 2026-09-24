-- Bounded plot collars and straight entrance connections. Plot/socket bases
-- stay fixed; approaches meet the unchanged final street profile.
local M = {COLLAR = 8, MAX_APPROACH = 24}
local function inside(p, x, z)
	return x >= p.min_x and x <= p.max_x and z >= p.min_z and z <= p.max_z
end
function M.path_height(p, z)
	local t = math.max(0, math.min(1, (p.min_z - z) / (p.min_z - p.road_z)))
	return math.floor(p.y + ((p.road_y or p.y) - p.y) * t + 0.5)
end
function M.new(plots, runs)
	local buckets = {}
	local function key(x, z) return math.floor(x / 32) .. ":" .. math.floor(z / 32) end
	for _, p in ipairs(plots) do
		local best
		-- Current plot compositions publish their public entrance on the north
		-- edge. Connect only that clear, authored aisle, never through a house.
		for _, run in ipairs(runs) do
			if run.junctions and run.axis == "x" and p.entry_x >= run.from and
					p.entry_x <= run.to and run.at < p.min_z and
					p.min_z - run.at <= M.MAX_APPROACH and
					(not best or run.at > best.at) then best = run end
		end
		if best then
			p.road_axis, p.road_z, p.road_id = best.at, best.at + 2, best.id
		else
			p.road_z = p.min_z - M.COLLAR
		end
		p.outer_min_x, p.outer_max_x = p.min_x - M.COLLAR, p.max_x + M.COLLAR
		p.outer_min_z = math.min(p.min_z - M.COLLAR, p.road_z or p.min_z)
		p.outer_max_z = p.max_z + M.COLLAR
		for z = math.floor(p.outer_min_z / 32), math.floor(p.outer_max_z / 32) do
			for x = math.floor(p.outer_min_x / 32), math.floor(p.outer_max_x / 32) do
				local k = x .. ":" .. z
				local bucket = buckets[k] or {}
				bucket[#bucket + 1] = p
				buckets[k] = bucket
			end
		end
	end
	local function surface(x, z, natural)
		local candidates = buckets[key(x, z)]
		if not candidates then return natural end
		for _, p in ipairs(candidates) do if inside(p, x, z) then return natural end end
		local chosen, target, nearest, is_access
		for _, p in ipairs(candidates) do
			local distance = math.max(p.min_x - x, x - p.max_x, p.min_z - z, z - p.max_z, 0)
			local access = p.road_z and not p.unreachable and math.abs(x - p.entry_x) <= 1 and
				z >= p.road_z and z < p.min_z
			if access or distance <= M.COLLAR then
				local delta = math.max(0, distance - 1)
				local value = math.max(p.y - delta, math.min(natural, p.y + delta))
				if access then
					value = M.path_height(p, z)
				end
				if not chosen or (access and not is_access) or
					(access == is_access and distance < nearest) then
					chosen, target, nearest, is_access = p, value, distance, access
				end
			end
		end
		if chosen then
			for _, run in ipairs(runs) do
				if run.junctions then
					local along = run.axis == "x" and x or z
					local across = math.abs((run.axis == "x" and z or x) - run.at)
					if along >= run.from and along <= run.to and
							(across <= 2 or (across <= 3 and not is_access)) then
						return natural
					end
					for _, joint in ipairs(run.junctions) do
						if joint.min_x and x >= joint.min_x and x <= joint.max_x and
								z >= joint.min_z and z <= joint.max_z then return natural end
					end
				end
			end
		end
		return target or natural, chosen, is_access
	end
	return {surface = surface, plots = plots}
end
return M
