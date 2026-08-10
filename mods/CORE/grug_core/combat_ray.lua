-- Shared server-side combat aim (classes.md §2b, combat_stats.md §2).
--
-- One caller request creates exactly one engine Raycast. The returned record is
-- both the combat decision and the diagnostic record; combatdebug must inspect
-- it rather than running a second ray. Raycasts use the engine's selection
-- boxes, so the intersection point -- not an entity's centre -- owns range.

local EYE_OFFSET_SCALE = 0.1
local RANGE_EPSILON = 0.001
local DISTANCE_TIE_EPSILON = 0.000001

-- First-person interaction starts at the camera head. Eye offsets are stored
-- in tenths of a node: the engine's own pointed-face helper applies
-- `eye_offset_first / 10` (builtin/common/misc_helpers.lua:754-774), while
-- Camera::update rotates its local X/Z offset with player yaw
-- (src/client/camera.cpp:318-381). View bobbing is client-only and cannot be
-- reproduced by the server. The server also does not receive a freely chosen
-- current third-person mode, so current server look aim consistently uses the
-- first-person interaction eye.
function grug_core.combat_eye_pos(player)
	local pos = player and player:get_pos()
	if not pos then
		return nil
	end
	local props = player:get_properties() or {}
	local first = player:get_eye_offset()
	first = first or vector.new(0, 0, 0)
	local look = player:get_look_dir()
	local flat = look and math.sqrt(look.x * look.x + look.z * look.z) or 0
	local forward_x, forward_z
	if flat > 0 then
		forward_x = look.x / flat
		forward_z = look.z / flat
	else
		local yaw = player:get_look_horizontal()
		forward_x = -math.sin(yaw)
		forward_z = math.cos(yaw)
	end
	local right_x = forward_z
	local right_z = -forward_x
	return vector.new(
		pos.x + (first.x * right_x + first.z * forward_x) * EYE_OFFSET_SCALE,
		pos.y + (props.eye_height or 1.5) + first.y * EYE_OFFSET_SCALE,
		pos.z + (first.x * right_z + first.z * forward_z) * EYE_OFFSET_SCALE)
end

local function intersection_distance(origin, pointed, ref)
	local point = pointed.intersection_point
	if not point and ref then
		point = ref:get_pos()
	end
	return point and vector.distance(origin, point) or nil
end

local function player_relation(player, target)
	local own = grug_core.get_player_faction(player:get_player_name())
	local other = grug_core.get_player_faction(target:get_player_name())
	if own and other then
		return own == other and "friendly" or "hostile"
	end
	return "neutral"
end

local function classify_object(player, origin, range, pointed)
	local target = pointed.ref
	local distance = intersection_distance(origin, pointed, target)
	local result = {
		status = "aim_miss",
		reason = "object",
		pointed = pointed,
		target = target,
		blocker = target,
		distance = distance,
		object_kind = "object",
		alive = false,
		relation = "neutral",
	}
	if distance and distance > range + RANGE_EPSILON then
		result.reason = "out_of_range"
		return result
	end
	if not target or not target:get_pos() then
		return result
	end
	if target:is_player() then
		result.object_kind = "player"
		result.alive = target:get_hp() > 0
		result.relation = target == player and "self"
			or player_relation(player, target)
	elseif target:get_luaentity() then
		local ent = target:get_luaentity()
		if ent._cmi_is_mob then
			result.object_kind = "mob"
			result.alive = (ent.health or 0) > 0
			local own = grug_core.get_player_faction(player:get_player_name())
			result.relation = ent._grug_faction and own == ent._grug_faction
				and "friendly" or "hostile"
		end
	end
	if result.relation == "self" then
		result.reason = "self"
	elseif not result.alive and result.object_kind ~= "object" then
		result.reason = "dead"
	elseif result.relation == "friendly" then
		result.reason = "friendly"
	elseif result.relation == "hostile" and result.alive then
		result.status = "target"
		result.reason = "hostile"
		result.blocker = nil
	end
	return result
end

local function nearer_terminal(candidate, candidate_is_node, best,
		best_is_node)
	if not best then
		return true
	end
	-- RaycastSort deliberately gives objects a BS^2 preference over nodes
	-- (src/raycast.cpp:11-41), so iterator order is not line-of-sight order.
	-- Raycast hit records do carry the exact selection-box intersection point;
	-- compare that physical distance instead. Missing points are impossible for
	-- engine Raycast hits, but treating one as infinitely far fails closed.
	local candidate_distance = candidate.distance or math.huge
	local best_distance = best.distance or math.huge
	if candidate_distance < best_distance - DISTANCE_TIE_EPSILON then
		return true
	end
	return math.abs(candidate_distance - best_distance) <=
		DISTANCE_TIE_EPSILON and candidate_is_node and not best_is_node
end

-- Returns one structured result:
--   status = "target" | "aim_miss"
--   reason = hostile | friendly | dead | object | node | empty |
--            out_of_range | invalid
-- plus origin/destination/range/direction and the exact pointed/target/blocker.
function grug_core.combat_ray(player, range, opts)
	opts = opts or {}
	local origin = opts.origin or grug_core.combat_eye_pos(player)
	local direction = opts.direction or (player and player:get_look_dir())
	if not origin or type(range) ~= "number" or range <= 0 or not direction then
		return {status = "aim_miss", reason = "invalid", range = range}
	end
	direction = vector.normalize(direction)
	local destination = vector.add(origin, vector.multiply(direction, range))
	local base = {
		status = "aim_miss",
		reason = "empty",
		origin = origin,
		destination = destination,
		direction = direction,
		range = range,
	}
	local best
	local best_is_node = false
	for pointed in core.raycast(origin, destination, true,
			opts.liquids == true, opts.pointabilities) do
		if pointed.type == "object" and pointed.ref == player then
			-- The eye begins inside the player's own selection box. Self is not a
			-- combat blocker; keep advancing this same ray.
		elseif pointed.type == "node" then
			local node = pointed.under and core.get_node_or_nil(pointed.under)
			local def = node and core.registered_nodes[node.name]
			if def and def.walkable then
				local candidate = {
					status = "aim_miss",
					reason = "node",
					pointed = pointed,
					blocker = pointed.under,
					node = node.name,
					distance = intersection_distance(origin, pointed),
				}
				if nearer_terminal(candidate, true, best, best_is_node) then
					best = candidate
					best_is_node = true
				end
			end
		elseif pointed.type == "object" then
			local object_result = classify_object(player, origin, range, pointed)
			if nearer_terminal(object_result, false, best, best_is_node) then
				best = object_result
				best_is_node = false
			end
		end
	end
	if best then
		for key, value in pairs(base) do
			if best[key] == nil then
				best[key] = value
			end
		end
		return best
	end
	return base
end
