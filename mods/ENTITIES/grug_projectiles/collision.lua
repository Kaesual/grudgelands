-- Swept projectile collision. Raycast's iterator order is not physical order:
-- objects receive a one-node priority bonus over nodes
-- (reference_projects/luanti/src/raycast.cpp:11-41). Scan the complete
-- iterator and compare the actual intersection points instead.

local DISTANCE_EPSILON = 0.000001

local function hit_distance(origin, pointed)
	local point = pointed.intersection_point
	if not point and pointed.type == "object" and pointed.ref then
		point = pointed.ref:get_pos()
	elseif not point and pointed.type == "node" then
		point = pointed.under
	end
	return point and vector.distance(origin, point) or nil, point
end

local function attackable_object(owner, projectile, obj)
	if not obj or obj == owner or obj == projectile or not obj:get_pos() then
		return false
	end
	if obj:is_player() then
		-- Factionless players are neutral, not hostile. They neither take the
		-- hit nor body-block it.
		return obj:get_hp() > 0 and grug_factions.hostile(owner, obj)
	end
	local ent = obj:get_luaentity()
	if not ent or ent.name == "__builtin:item" or not ent._cmi_is_mob
			or (ent.health or 0) <= 0 then
		return false
	end
	-- Factionless mobs remain attackable, matching direct ability targeting.
	return not grug_factions.same_faction(owner, obj)
end

local function nearer(candidate, best)
	if not best or candidate.distance < best.distance - DISTANCE_EPSILON then
		return true
	end
	-- At a physical tie world geometry wins. This reverses RaycastSort's
	-- object priority and prevents a target touching a wall from being hit
	-- through that wall.
	return math.abs(candidate.distance - best.distance) <= DISTANCE_EPSILON
		and candidate.kind == "node" and best.kind ~= "node"
end

-- Runs exactly one engine ray and returns the nearest physical terminal hit.
-- Allies, drops and non-attackable objects are transparent to projectiles.
function grug_projectiles.trace_segment(owner, projectile, origin, destination)
	local segment_length = vector.distance(origin, destination)
	local best
	for pointed in core.raycast(origin, destination, true, false) do
		local candidate
		if pointed.type == "node" then
			local node = pointed.under and core.get_node_or_nil(pointed.under)
			local node_def = node and core.registered_nodes[node.name]
			-- Unknown geometry is treated as solid. A ray hit means the engine
			-- considered the node pointable; failing open here would permit a
			-- projectile through a temporarily unavailable definition.
			if not node_def or node_def.walkable then
				local distance, point = hit_distance(origin, pointed)
				candidate = distance and {
					kind = "node",
					distance = distance,
					point = point,
					pointed = pointed,
					node = node and node.name or "unknown",
				} or nil
			end
		elseif pointed.type == "object"
				and attackable_object(owner, projectile, pointed.ref) then
			local distance, point = hit_distance(origin, pointed)
			candidate = distance and {
				kind = "object",
				distance = distance,
				point = point,
				pointed = pointed,
				target = pointed.ref,
			} or nil
		end
		if candidate and candidate.distance <= segment_length + DISTANCE_EPSILON
				and nearer(candidate, best) then
			best = candidate
		end
	end
	return best
end
