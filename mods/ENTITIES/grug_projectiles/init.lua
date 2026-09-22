-- Server-authoritative homing projectiles (docs/design/combat_stats.md §2).

grug_projectiles = {}

local ENTITY_NAME = "grug_projectiles:projectile"
local definitions = {}
local sessions = {} -- player name -> runtime identity
local next_session = 0
local active_counts = {} -- session -> projectile id -> count
local active_tokens = {} -- token -> {session, projectile_id}
local session_tokens = {} -- session -> token -> true
local next_active_token = 0
local ARROW_MESH_YAW_OFFSET = -math.pi / 2

local function release_active(token)
	local rec = token and active_tokens[token]
	if not rec then
		return
	end
	active_tokens[token] = nil
	local tokens = session_tokens[rec.session]
	if tokens then
		tokens[token] = nil
	end
	local counts = active_counts[rec.session]
	if counts then
		counts[rec.projectile_id] = math.max(0,
			(counts[rec.projectile_id] or 0) - 1)
	end
end

local function clear_active_session(session)
	local tokens = session and session_tokens[session]
	if tokens then
		for token in pairs(tokens) do
			active_tokens[token] = nil
		end
	end
	session_tokens[session] = nil
	active_counts[session] = nil
end

local function clear_session(player)
	local name = player:get_player_name()
	local session = sessions[name]
	sessions[name] = nil
	if session then
		clear_active_session(session)
	end
end

local function new_session(player)
	-- Respawn replaces the combat identity even if a foreign callback skipped
	-- the ordinary death edge. Old same-name projectiles can never consume the
	-- new session's limit.
	clear_session(player)
	next_session = next_session + 1
	sessions[player:get_player_name()] = next_session
end

core.register_on_joinplayer(new_session)
core.register_on_respawnplayer(new_session)

core.register_on_dieplayer(clear_session)
core.register_on_leaveplayer(clear_session)

local function reserve_active(session, projectile_id, limit)
	if not limit then
		return nil, true
	end
	local counts = active_counts[session]
	if not counts then
		counts = {}
		active_counts[session] = counts
	end
	if (counts[projectile_id] or 0) >= limit then
		return nil, false
	end
	next_active_token = next_active_token + 1
	local token = next_active_token
	counts[projectile_id] = (counts[projectile_id] or 0) + 1
	active_tokens[token] = {session = session, projectile_id = projectile_id}
	local tokens = session_tokens[session]
	if not tokens then
		tokens = {}
		session_tokens[session] = tokens
	end
	tokens[token] = true
	return token, true
end

local function serializable_copy(value, seen)
	local kind = type(value)
	if kind == "nil" or kind == "boolean" or kind == "number"
			or kind == "string" then
		return value, true
	end
	if kind ~= "table" or seen[value] then
		return nil, false
	end
	seen[value] = true
	local copy = {}
	for key, child in pairs(value) do
		local key_kind = type(key)
		if key_kind ~= "number" and key_kind ~= "string" then
			seen[value] = nil
			return nil, false
		end
		local child_copy, ok = serializable_copy(child, seen)
		if not ok then
			seen[value] = nil
			return nil, false
		end
		copy[key] = child_copy
	end
	seen[value] = nil
	return copy, true
end

local function debug_event(owner_name, event, projectile_id, value_a, value_b)
	-- The disabled path is one enabled-table lookup. The rate-key and event
	-- literals are pre-existing strings; all formatting stays behind both
	-- gates.
	if not grug_core.combat_debug_enabled(owner_name) then
		return
	end
	if not grug_core.combat_debug_due(owner_name,
			"projectile:lifecycle", 0.05) then
		return
	end
	local detail
	if event == "spawn" then
		detail = "speed=" .. tostring(value_a) ..
			" max_distance=" .. tostring(value_b)
	elseif event == "hit" or event == "range" then
		detail = "distance=" .. tostring(value_a)
	elseif event == "node" then
		detail = "node=" .. tostring(value_a) ..
			" distance=" .. tostring(value_b)
	elseif event == "lifetime" then
		detail = "age=" .. tostring(value_a)
	else
		detail = tostring(value_a or "")
	end
	grug_core.combat_debug_log(owner_name, "projectile_" .. event,
		"id=" .. tostring(projectile_id) .. " " .. detail)
end

function grug_projectiles.register(id, def)
	assert(type(id) == "string" and id ~= "", "projectile needs an id")
	assert(type(def) == "table" and type(def.on_hit) == "function",
		"projectile needs an on_hit callback")
	assert(not definitions[id], "projectile already registered: " .. id)
	assert(type(def.speed) == "number" and def.speed > 0,
		"projectile speed must be positive")
	assert(type(def.max_distance) == "number" and def.max_distance > 0,
		"projectile max_distance must be positive")
	assert(def.active_limit == nil or (type(def.active_limit) == "number"
		and def.active_limit > 0 and def.active_limit % 1 == 0),
		"projectile active_limit must be a positive integer")
	assert(def.orient_to_velocity == nil or
		type(def.orient_to_velocity) == "boolean",
		"projectile orient_to_velocity must be a boolean")
	definitions[id] = def
end

-- Match the imported mesh's proven VoxeLibre orientation: Luanti's yaw plus
-- this -pi/2 mesh offset, with vertical velocity carried by entity roll.
local function orient_to_velocity(object, velocity)
	local length = vector.length(velocity)
	if length <= 0 then return end
	local direction = vector.multiply(velocity, 1 / length)
	object:set_rotation(vector.new(
		0,
		core.dir_to_yaw(direction) + ARROW_MESH_YAW_OFFSET,
		math.asin(math.max(-1, math.min(1, direction.y)))
	))
end

-- params = {owner=PlayerRef, origin=vector, direction=vector, data=table,
--           speed=number?, max_distance=number?}. The ephemeral lock retains
-- exact runtime identities; only initialization data passes through serialization.
local function spawn_one(id, params)
	local def = definitions[id]
	local owner = params and params.owner
	if not def or not owner or not owner:is_player() or owner:get_hp() <= 0 then
		return false
	end
	local owner_name = owner:get_player_name()
	local owner_session = sessions[owner_name]
	if not owner_session or core.get_player_by_name(owner_name) ~= owner then
		return false
	end
	local origin = params.origin and vector.new(params.origin)
	local direction = params.direction and vector.normalize(params.direction)
	if not origin or not direction or vector.length(direction) <= 0 then
		return false
	end
	local data, serializable = serializable_copy(params.data or {}, {})
	if not serializable then
		core.log("error", "[grug_projectiles] rejected non-serializable " ..
			"projectile data for " .. id)
		return false
	end
	local speed = params.speed or def.speed
	local max_distance = params.max_distance or def.max_distance
	if type(speed) ~= "number" or speed <= 0
			or type(max_distance) ~= "number" or max_distance <= 0 then
		return false
	end
	local ray = grug_core.combat_ray(owner, max_distance)
	if not ray or ray.status ~= "target" then return false end
	if not ray.target:is_player() and grug_mobs.is_noncombatant(ray.target:get_luaentity()) then
		return false
	end
	local lock = grug_core.homing_lock(owner, ray.target, origin, speed)
	if not lock then return false end
	-- Reserve before add_entity so a modified client cannot interleave a ninth
	-- spawn. The opaque token makes every failure/deactivation release
	-- idempotent, including add_entity returning nil after on_activate removed.
	local active_token, active = reserve_active(owner_session, id,
		def.active_limit)
	if not active then
		return false
	end
	local payload = {
		projectile_id = id,
		owner_name = owner_name,
		owner_session = owner_session,
		max_distance = max_distance,
		data = data,
		active_token = active_token,
		attacker_level = grug_core.get_player_level(owner),
	}
	local object = core.add_entity(origin, ENTITY_NAME, core.serialize(payload))
	if not object then
		release_active(active_token)
		return false
	end
	object:get_luaentity()._grug_lock = lock
	local velocity = vector.multiply(direction, speed)
	local ok = pcall(object.set_velocity, object, velocity)
	if ok and def.orient_to_velocity then
		ok = pcall(orient_to_velocity, object, velocity)
	end
	if not ok then
		release_active(active_token)
		object:remove()
		return false
	end
	debug_event(owner_name, "spawn", id, speed, max_distance)
	return object
end

function grug_projectiles.spawn(id, params)
	return spawn_one(id, params) and true or false
end

local function release_projectile(self)
	local token = self._grug_active_token
	self._grug_active_token = nil
	release_active(token)
end

-- Spawn a complete multi-projectile action, then commit its external cost.
-- No entity can step until this synchronous call returns. If any spawn or the
-- commit fails, every already-created sibling is marked settled, releases its
-- active token exactly once, and is removed without invoking an on_hit.
function grug_projectiles.spawn_batch(id, launches, commit)
	if type(launches) ~= "table" or #launches < 1 or
			(commit ~= nil and type(commit) ~= "function") then
		return false
	end
	local objects = {}
	local function rollback()
		for index = 1, #objects do
			local object = objects[index]
			local entity = object and object:get_luaentity()
			if entity and not entity._grug_settled then
				entity._grug_settled = true
				release_projectile(entity)
			end
			if object and object:get_pos() then object:remove() end
		end
	end
	for index = 1, #launches do
		local object = spawn_one(id, launches[index])
		if not object then
			rollback()
			return false
		end
		objects[#objects + 1] = object
	end
	if commit then
		local ok, accepted = pcall(commit)
		if not ok or accepted ~= true then
			rollback()
			if not ok then
				core.log("error", "[grug_projectiles] batch commit failed for " ..
					tostring(id) .. ": " .. tostring(accepted))
			end
			return false
		end
	end
	return true
end

local function remove_projectile(self, event, value_a, value_b)
	if self._grug_settled then
		return
	end
	self._grug_settled = true
	release_projectile(self)
	debug_event(self._grug_owner_name, event, self._grug_projectile_id,
		value_a, value_b)
	self.object:remove()
end

local function settle_hit(self, owner, hit, def)
	if self._grug_settled then
		return
	end
	-- Settle before any consumer callback. A lethal damage callback may remove
	-- the target synchronously; nothing below reads it afterwards.
	self._grug_settled = true
	release_projectile(self)
	debug_event(self._grug_owner_name, "hit", self._grug_projectile_id,
		self._grug_travelled + hit.distance)
	local ok, err = pcall(def.on_hit, owner, hit.target,
		self._grug_data, hit.point, self._grug_attacker_level)
	if not ok then
		core.log("error", "[grug_projectiles] hit callback failed for " ..
			tostring(self._grug_projectile_id) .. ": " .. tostring(err))
	end
	self.object:remove()
end

core.register_entity(ENTITY_NAME, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		is_visible = false,
		visual = "sprite",
		selectionbox = {0, 0, 0, 0, 0, 0},
		collisionbox = {0, 0, 0, 0, 0, 0},
	},

	on_activate = function(self, staticdata)
		local payload = core.deserialize(staticdata)
		self._grug_active_token = type(payload) == "table"
			and payload.active_token or nil
		local def = type(payload) == "table"
			and definitions[payload.projectile_id] or nil
		if not def or type(payload.owner_name) ~= "string"
				or type(payload.owner_session) ~= "number"
				or type(payload.attacker_level) ~= "number"
				or type(payload.max_distance) ~= "number"
				or type(payload.data) ~= "table" then
			self._grug_settled = true
			release_projectile(self)
			self.object:remove()
			return
		end
		self._grug_projectile_id = payload.projectile_id
		self._grug_owner_name = payload.owner_name
		self._grug_owner_session = payload.owner_session
		self._grug_max_distance = payload.max_distance
		self._grug_data = payload.data
		self._grug_attacker_level = math.max(1,
			tonumber(payload.attacker_level) or 1)
		self._grug_travelled = 0
		self._grug_settled = false
		if def.properties then
			self.object:set_properties(def.properties)
		end
	end,

	on_step = function(self, dtime)
		if self._grug_settled then
			return
		end
		local def = definitions[self._grug_projectile_id]
		local owner = core.get_player_by_name(self._grug_owner_name or "")
		if not def or not owner or owner:get_hp() <= 0
				or sessions[self._grug_owner_name] ~= self._grug_owner_session then
			remove_projectile(self, "owner_lost", "owner/session invalid")
			return
		end
		local destination, arrived = grug_core.homing_step(self._grug_lock, dtime)
		if not destination then
			remove_projectile(self, "target_lost", "combat identity invalid")
			return
		end
		local current = self.object:get_pos()
		if not current then return end
		if arrived then
			settle_hit(self, owner, {target = self._grug_lock.target,
				point = destination, distance = vector.distance(current, destination)}, def)
			return
		end
		local remaining = math.max(0.01, self._grug_lock.duration - self._grug_lock.age)
		local velocity = vector.multiply(vector.subtract(destination, current), 1 / remaining)
		self.object:set_velocity(velocity)
		if def.orient_to_velocity then orient_to_velocity(self.object, velocity) end
	end,

	-- Deactivation is cleanup only. Settlement always happens in on_step and
	-- is marked before callbacks/removal, so unload/remove cannot apply a hit.
	on_deactivate = function(self)
		self._grug_settled = true
		release_projectile(self)
	end,
})
