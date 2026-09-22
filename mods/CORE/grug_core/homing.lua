-- Runtime-only target locks shared by player and non-player missiles.
local generations = setmetatable({}, {__mode = "k"})
function grug_core.invalidate_combat_identity(object)
	generations[object] = (generations[object] or 0) + 1
end
core.register_on_joinplayer(grug_core.invalidate_combat_identity)
core.register_on_dieplayer(grug_core.invalidate_combat_identity)
core.register_on_respawnplayer(grug_core.invalidate_combat_identity)
core.register_on_leaveplayer(grug_core.invalidate_combat_identity)

local function identity(object)
	if not object or not object:get_pos() then return nil end
	if object:is_player() then
		if object:get_hp() <= 0 or core.get_player_by_name(object:get_player_name()) ~= object then
			return nil
		end
		return true
	end
	local entity = object:get_luaentity()
	if not entity or (entity.health or 0) <= 0 or (entity.temp and entity.temp.grug_evading) then return nil end
	return entity
end

local function target_center(object, pos)
	local props = object:get_properties()
	local box = props and (props.collisionbox or props.selectionbox)
	if not box then return pos end
	return vector.offset(pos, (box[1] + box[4]) / 2,
		(box[2] + box[5]) / 2, (box[3] + box[6]) / 2)
end

function grug_core.homing_lock(owner, target, origin, speed)
	local source, victim = identity(owner), identity(target)
	if not source or not victim or not origin or not speed or speed <= 0 then return nil end
	return {owner = owner, target = target, source = source, victim = victim,
		owner_generation = generations[owner] or 0,
		target_generation = generations[target] or 0,
		previous = vector.new(target:get_pos()), age = 0,
		duration = math.max(0.05, math.min(2, vector.distance(origin, target:get_pos()) / speed))}
end

-- Returns current destination and arrival; nil means cancellation. No ray,
-- range check or new acquisition is permitted after a lock exists.
function grug_core.homing_step(lock, dtime)
	if not lock or identity(lock.owner) ~= lock.source or identity(lock.target) ~= lock.victim
			or (generations[lock.owner] or 0) ~= lock.owner_generation
			or (generations[lock.target] or 0) ~= lock.target_generation then return nil end
	local pos = lock.target:get_pos()
	local velocity = lock.target:get_velocity() or vector.new(0, 0, 0)
	local speed = vector.length(velocity)
	-- Attached players report their own speed as zero. The engine-owned
	-- current attachment supplies the movement of a live mount/controller.
	local parent = lock.target:get_attach()
	if parent and parent:get_pos() then
		local parent_velocity = parent:get_velocity()
		if parent_velocity then speed = math.max(speed, vector.length(parent_velocity)) end
	end
	local elapsed = math.max(0, dtime or 0)
	-- Catch external/admin teleports as well as the explicit game teleport seam.
	-- Velocity and elapsed time permit ordinary fast movement, including mounts.
	if vector.distance(pos, lock.previous) > math.max(8, speed * elapsed * 2 + 2) then
		return nil
	end
	lock.previous = vector.new(pos)
	lock.age = lock.age + elapsed
	return target_center(lock.target, pos), lock.age >= lock.duration
end

-- Actors lock their current target only after range and terrain LOS succeed.
function grug_core.actor_projectile_lock(owner, target, origin, speed, range)
	if not target or not target:get_pos() or vector.distance(origin, target:get_pos()) > range then return nil end
	local destination = target_center(target, target:get_pos())
	for pointed in core.raycast(origin, destination, false, false) do
		if pointed.type == "node" then
			local node = core.get_node_or_nil(pointed.under)
			local def = node and core.registered_nodes[node.name]
			if not def or def.walkable then return nil end
		end
	end
	return grug_core.homing_lock(owner, target, origin, speed)
end
