-- Shared server-side combat aim (classes.md §2b, combat_stats.md §2).
--
-- One caller request creates exactly one aiming ray (grug_core.aim_raycast).
-- The returned record is both the combat decision and the diagnostic record;
-- combatdebug must inspect it rather than running a second ray. Rays use the
-- selection boxes, so the intersection point -- not an entity's centre --
-- owns range.

local EYE_OFFSET_SCALE = 0.1
local RANGE_EPSILON = 0.001
local DISTANCE_TIE_EPSILON = 0.000001

-- Rotated selection boxes (upstream workaround, see
-- docs/technical/upstream-workarounds.md): since Luanti 5.12 the SERVER's
-- raycast turns a `rotate = true` selection box by its degree rotation read
-- as radians (src/serverenvironment.cpp getSelectedActiveObjects passes
-- UnitSAO::getTotalRotation(), degrees, to boxLineCollision, which wants
-- radians): every yaw but 0 turns the box wrongly, beyond ±90° it is tipped
-- over, and the ray misses the upper body of tall, narrow mobs (and a long
-- one from the side) that the client points at. The client is right.
-- grug_core.aim_raycast keeps the engine's nodes and every other object and
-- tests rotated boxes here, turned exactly as the client turns them:
-- ClientEnvironment::getSelectedActiveObjects uses the scene node's rotation,
-- which GenericCAO::updateNodePos builds as setPitchYawRoll(-rotation)
-- (src/util/numeric.cpp setPitchYawRollRad; Irrlicht row vectors, so a box
-- point p is drawn at p * M). get_rotation() is that rotation in radians
-- (pitch and roll included); mobs set no automatic yaw (automatic_rotate
-- only spins a dying, unpointable mob).
-- Candidates: the engine's own rule, the objects in the ray's box widened by
-- 5 nodes (getSelectedActiveObjects). Pieces of the ray would not be
-- narrower for the usual near-level ray: their widened boxes overlap.
local AIM_MARGIN = 5

-- The box a rotated-box object starts from, or nil when its box is not
-- rotated: a mobs_redo mob keeps its live box in `base_selbox` (scale_mob
-- writes it), any other entity its registered one. Read without
-- get_properties(), so most candidates cost no property table.
local function rotated_hint(ent)
	local box = ent.base_selbox
	if box == nil then
		local props = ent.initial_properties
		box = props and props.selectionbox
	end
	return box ~= nil and box.rotate and box or nil
end

local function is_rotated_object(ref)
	local ent = ref and ref.get_luaentity and ref:get_luaentity()
	return ent ~= nil and rotated_hint(ent) ~= nil
end

-- The engine's pointability of an object: its `pointable` property unless
-- the ray's pointabilities name the entity, else one of its armour groups
-- (Pointabilities::matchObject / matchGroups: true before false before
-- "blocking").
local function pointable(obj, ent, props, pointabilities)
	local rules = pointabilities and pointabilities.objects
	if rules then
		local own = rules[ent.name]
		if own ~= nil then
			return own ~= false
		end
		local groups, found = obj:get_armor_groups(), nil
		for key, value in pairs(rules) do
			if key:sub(1, 6) == "group:" and (groups[key:sub(7)] or 0) > 0 then
				if value == true then
					return true
				elseif value == false or found == nil then
					found = value
				end
			end
		end
		if found ~= nil then
			return found ~= false
		end
	end
	return props.pointable ~= false
end

-- Where the segment start + t * dir (t in [0, 1]) enters `box` (six numbers,
-- relative to the object; a start inside counts at t = 0, as in the engine's
-- boxLineCollision): t and the entry face's axis (1..3) and sign, or nil.
local function enter_box(box, sx, sy, sz, dx, dy, dz)
	local s, d = {sx, sy, sz}, {dx, dy, dz}
	local t0, t1, axis, sign = 0, 1, 0, 0
	for i = 1, 3 do
		local lo, hi = box[i], box[i + 3]
		if d[i] == 0 then
			if s[i] < lo or s[i] > hi then
				return nil
			end
		else
			local a, b = (lo - s[i]) / d[i], (hi - s[i]) / d[i]
			if a > b then
				a, b = b, a
			end
			if a > t0 then
				t0, axis, sign = a, i, d[i] > 0 and -1 or 1
			end
			if b < t1 then
				t1 = b
			end
			if t0 > t1 then
				return nil
			end
		end
	end
	return t0, axis, sign
end

-- The client's box rotation matrix M (entries 0-2, 4-6, 8-10 as
-- setPitchYawRollRad writes them) for an object rotation in radians.
local function box_matrix(rot)
	local a1, a2, a3 = -rot.z, -rot.x, -rot.y
	local c1, s1 = math.cos(a1), math.sin(a1)
	local c2, s2 = math.cos(a2), math.sin(a2)
	local c3, s3 = math.cos(a3), math.sin(a3)
	return {
		s1 * s2 * s3 + c1 * c3, s1 * c2, s1 * s2 * c3 - c1 * s3,
		c1 * s2 * s3 - s1 * c3, c1 * c2, c1 * s2 * c3 + s1 * s3,
		c2 * s3, -s2, c2 * c3,
	}
end

-- The hit of the segment origin -> origin + dir on an object's selection
-- box at `pos`, turned by `rot` (radians; nil for an unturned box): a
-- pointed thing like the engine's (type, ref, intersection_point,
-- intersection_normal, box_id) plus its distance, or nil.
local function box_hit(box, pos, rot, origin, dir, ref)
	local sx, sy, sz = origin.x - pos.x, origin.y - pos.y, origin.z - pos.z
	local dx, dy, dz = dir.x, dir.y, dir.z
	local m
	if rot and (rot.x ~= 0 or rot.y ~= 0 or rot.z ~= 0) then
		-- Into the box's frame: p * M^T (M is a rotation).
		m = box_matrix(rot)
		sx, sy, sz = sx * m[1] + sy * m[2] + sz * m[3],
			sx * m[4] + sy * m[5] + sz * m[6],
			sx * m[7] + sy * m[8] + sz * m[9]
		dx, dy, dz = dir.x * m[1] + dir.y * m[2] + dir.z * m[3],
			dir.x * m[4] + dir.y * m[5] + dir.z * m[6],
			dir.x * m[7] + dir.y * m[8] + dir.z * m[9]
	end
	local t, axis, sign = enter_box(box, sx, sy, sz, dx, dy, dz)
	if not t then
		return nil
	end
	local n = {0, 0, 0}
	if axis > 0 then
		n[axis] = sign
	end
	local normal = vector.new(n[1], n[2], n[3])
	if m then
		-- Back to the world: p * M.
		normal = vector.new(n[1] * m[1] + n[2] * m[4] + n[3] * m[7],
			n[1] * m[2] + n[2] * m[5] + n[3] * m[8],
			n[1] * m[3] + n[2] * m[6] + n[3] * m[9])
	end
	return {
		type = "object",
		ref = ref,
		intersection_point = vector.new(origin.x + dir.x * t,
			origin.y + dir.y * t, origin.z + dir.z * t),
		intersection_normal = normal,
		box_id = 0,
	}, t * vector.length(dir)
end

-- Every rotated-box object the segment hits, nearest first, each with its
-- distance in `_distance`. Cheap rejections come first: no luaentity, no
-- rotated box, farther from the segment than the box reaches; only the rest
-- read their live properties.
local function rotated_hits(origin, destination, pointabilities)
	local dir = vector.subtract(destination, origin)
	local length = vector.length(dir)
	if length == 0 then
		return nil
	end
	local minp = vector.new(math.min(origin.x, destination.x) - AIM_MARGIN,
		math.min(origin.y, destination.y) - AIM_MARGIN,
		math.min(origin.z, destination.z) - AIM_MARGIN)
	local maxp = vector.new(math.max(origin.x, destination.x) + AIM_MARGIN,
		math.max(origin.y, destination.y) + AIM_MARGIN,
		math.max(origin.z, destination.z) + AIM_MARGIN)
	local hits
	for _, obj in ipairs(core.get_objects_in_area(minp, maxp)) do
		local ent = obj:get_luaentity()
		local hint = ent and rotated_hint(ent)
		local pos = hint and obj:get_pos()
		if pos then
			-- Turning keeps every box point within sqrt(reach2) of the object.
			local reach2 = 0
			for i = 1, 3 do
				local e = math.max(math.abs(hint[i]), math.abs(hint[i + 3]))
				reach2 = reach2 + e * e
			end
			local rx, ry, rz = pos.x - origin.x, pos.y - origin.y, pos.z - origin.z
			local t = math.max(0, math.min(1,
				(rx * dir.x + ry * dir.y + rz * dir.z) / (length * length)))
			local cx, cy, cz = rx - dir.x * t, ry - dir.y * t, rz - dir.z * t
			if cx * cx + cy * cy + cz * cz <= reach2 then
				local props = obj:get_properties()
				local box = props.selectionbox
				if props.is_visible ~= false and box and
						pointable(obj, ent, props, pointabilities) then
					local hit, distance = box_hit(box, pos,
						box.rotate and obj:get_rotation() or nil, origin, dir, obj)
					if hit then
						hit._distance = distance
						hits = hits or {}
						hits[#hits + 1] = hit
					end
				end
			end
		end
	end
	if hits and #hits > 1 then
		table.sort(hits, function(p, q) return p._distance < q._distance end)
	end
	return hits
end

-- The aiming ray of every server-side aim (the combat ray, the hold-to-cast
-- ray, skill targets, the target frame, right-click interaction): an
-- iterator over pointed things like core.raycast(origin, destination, true,
-- liquids, pointabilities), with rotated-box objects tested here instead of
-- by the engine (see the top of this file). Order follows the engine's
-- (nearest first, an object preferred by one node squared over a node, its
-- RaycastSort); the rotated hits slot in by their distance, so a wall in
-- front still comes first.
function grug_core.aim_raycast(origin, destination, liquids, pointabilities)
	local ray = core.raycast(origin, destination, true, liquids == true,
		pointabilities)
	local extra = rotated_hits(origin, destination, pointabilities)
	local index = 1
	local pending
	local function engine_next()
		while true do
			local pointed = ray()
			if not pointed or pointed.type ~= "object" or
					not is_rotated_object(pointed.ref) then
				return pointed
			end
		end
	end
	return function()
		local own = extra and extra[index]
		if not own then
			if pending then
				local pointed = pending
				pending = nil
				return pointed
			end
			return engine_next()
		end
		pending = pending or engine_next()
		if pending then
			local point = pending.intersection_point
			local d = point and vector.distance(origin, point) or 0
			local mine = own._distance * own._distance
			if pending.type ~= "object" then
				mine = mine - 1
			end
			if d * d <= mine then
				local pointed = pending
				pending = nil
				return pointed
			end
		end
		index = index + 1
		return own
	end
end

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

local function rider_proxy(target)
	local entity = target and target.get_luaentity and target:get_luaentity()
	local rider = entity and entity._grug_rider
	if rider and rider.is_player and rider:is_player() and rider:get_hp() > 0 and
			rider:get_attach() == target then
		return rider
	end
	return target
end

local function classify_object(player, origin, range, pointed)
	local target = rider_proxy(pointed.ref)
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
		-- An enemy player either of the pair is not flagged for (pvp-plan
		-- ruling 5) is no target: a blocker with a neutral crosshair, like a
		-- service NPC. The gate is grug_pvp's (combat.lua, the PvP seam).
		if result.relation == "hostile" and grug_core.pvp_can_harm and
				not grug_core.pvp_can_harm(player, target) then
			result.relation = "protected"
		end
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
	elseif result.relation == "protected" then
		result.reason = "protected"
	elseif result.relation == "hostile" and result.alive then
		result.status = "target"
		result.reason = "hostile"
		result.blocker = nil
	end
	return result
end

local function is_drop(ref)
	local entity = ref and ref:get_luaentity()
	return entity ~= nil and entity.name == "__builtin:item"
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
--   reason = hostile | friendly | protected | dead | object | node | empty |
--            out_of_range | invalid
-- (`protected`: an enemy player outside PvP, relation "protected" too)
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
	for pointed in grug_core.aim_raycast(origin, destination,
			opts.liquids == true, opts.pointabilities) do
		if pointed.type == "object" and pointed.ref == player then
			-- The eye begins inside the player's own selection box. Self is not a
			-- combat blocker; keep advancing this same ray.
		elseif pointed.type == "object" and is_drop(pointed.ref) then
			-- Dropped loot never hides a hostile behind it (Round 28): the ray
			-- passes through it like the player's own body.
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
