-- Bounded plot collars and the straight approach of a capital plot to its
-- street (Round 22 capital planner). The planner turns every plot so its
-- entry (the middle of its local -z edge) faces its street and keeps the gap
-- to the street short (`wp40/capital_planner.lua`, APPROACH_MAX); this module
-- shapes the ground round a plot and paves that gap, in the plot's OWN frame:
-- a world column is turned back into plot-local coordinates first, so the
-- rules below read "in front of the entry" as local -z whatever the turn.
--
--   * the collar: within COLLAR nodes of the plot box the ground eases toward
--     the plot's base height by one node per node (no cliff at a plot edge);
--   * the approach: a three-wide path from the entry straight out to the
--     street, its height interpolated from the plot's base to the street
--     surface, a stair where it rises.
-- Plot and socket bases stay fixed; the street profile is never touched (the
-- caller skips street columns).
local M = {COLLAR = 8, MAX_APPROACH = 12}

-- plot-local (x, z) -> world offset for a plot turned `t` quarter turns: local
-- +z to world +x and local +x to world -z per turn (wp13/parts.lua)
local function rot(x, z, t)
	t = t % 4
	if t == 0 then return x, z end
	if t == 1 then return z + 0, 0 - x end
	if t == 2 then return 0 - x, 0 - z end
	return 0 - z, x + 0
end
M.rot = rot

function M.path_height(p, lz)
	local t = math.max(0, math.min(1, (p.min_z - lz) / (p.min_z - p.road_z)))
	return math.floor(p.y + ((p.road_y or p.y) - p.y) * t + 0.5)
end

-- `plots`: {state, y (base), x, z (world origin), turns, min_x, max_x, min_z,
-- max_z (the local plot box), entry_x (local), road_len (path length in nodes
-- from the box edge to the street, nil without a street), road_y}
function M.new(plots)
	local buckets = {}
	local function key(x, z) return math.floor(x / 32) .. ":" .. math.floor(z / 32) end
	for _, p in ipairs(plots) do
		if p.road_len then
			p.road_z = p.min_z - p.road_len
		else
			p.road_z = p.min_z - M.COLLAR
		end
		-- the world box of the collar and the path
		local lx0, lx1 = p.min_x - M.COLLAR, p.max_x + M.COLLAR
		local lz0, lz1 = math.min(p.min_z - M.COLLAR, p.road_z), p.max_z + M.COLLAR
		local ax, az = rot(lx0, lz0, p.turns)
		local bx, bz = rot(lx1, lz1, p.turns)
		p.wx0, p.wx1 = p.x + math.min(ax, bx), p.x + math.max(ax, bx)
		p.wz0, p.wz1 = p.z + math.min(az, bz), p.z + math.max(az, bz)
		for z = math.floor(p.wz0 / 32), math.floor(p.wz1 / 32) do
			for x = math.floor(p.wx0 / 32), math.floor(p.wx1 / 32) do
				local k = x .. ":" .. z
				local bucket = buckets[k] or {}
				bucket[#bucket + 1] = p
				buckets[k] = bucket
			end
		end
	end
	-- target top of a world column, the chosen plot and whether it is on the
	-- approach path; nil record: no plot shapes this column
	local function surface(x, z, natural)
		local candidates = buckets[key(x, z)]
		if not candidates then return natural end
		local chosen, target, nearest, is_access, clx, clz
		for _, p in ipairs(candidates) do
			if x >= p.wx0 and x <= p.wx1 and z >= p.wz0 and z <= p.wz1 then
				local lx, lz = rot(x - p.x, z - p.z, (4 - p.turns) % 4)
				if lx >= p.min_x and lx <= p.max_x and lz >= p.min_z and lz <= p.max_z then
					return natural
				end
				local distance = math.max(p.min_x - lx, lx - p.max_x, p.min_z - lz, lz - p.max_z, 0)
				local access = p.road_len ~= nil and math.abs(lx - p.entry_x) <= 1 and
					lz >= p.road_z and lz < p.min_z
				if access or distance <= M.COLLAR then
					local delta = math.max(0, distance - 1)
					local value = math.max(p.y - delta, math.min(natural, p.y + delta))
					if access then value = M.path_height(p, lz) end
					if not chosen or (access and not is_access) or
						(access == is_access and distance < nearest) then
						chosen, target, nearest, is_access, clx, clz =
							p, value, distance, access, lx, lz
					end
				end
			end
		end
		return target or natural, chosen, is_access, clx, clz
	end
	return {surface = surface, plots = plots}
end
return M
