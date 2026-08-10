-- Focused plain-Lua-5.1 real-code test for grug_projectiles.

local repo = arg[1] or "."
local ray_hits = {}
local ray_calls = 0
local ray_segments = {}
local entities = {}
local callbacks = {join = {}, respawn = {}, die = {}, leave = {}}
local online = {}
local serialized = {}
local serial = 0
local logs = {}
local debug_enabled_calls = 0
local debug_due_calls = 0
local debug_log_calls = 0
local fail_add_entity = false

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then
		return {x = x.x, y = x.y, z = x.z}
	end
	return {x = x, y = y, z = z}
end
function vector.add(a, b)
	return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end
function vector.subtract(a, b)
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
end
function vector.multiply(a, n)
	return {x = a.x * n, y = a.y * n, z = a.z * n}
end
function vector.distance(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end
function vector.length(a)
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end
function vector.normalize(a)
	local length = vector.length(a)
	if length == 0 then
		return {x = 0, y = 0, z = 0}
	end
	return {x = a.x / length, y = a.y / length, z = a.z / length}
end

local registered_entity
core = {
	registered_nodes = {
		stone = {walkable = true},
		grass = {walkable = false},
	},
	get_current_modname = function() return "grug_projectiles" end,
	get_modpath = function()
		return repo .. "/mods/ENTITIES/grug_projectiles"
	end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_respawnplayer = function(fn)
		callbacks.respawn[#callbacks.respawn + 1] = fn
	end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_entity = function(_, def) registered_entity = def end,
	get_player_by_name = function(name) return online[name] end,
	get_node_or_nil = function(pos)
		return pos and pos.name and {name = pos.name} or nil
	end,
	raycast = function(origin, destination)
		ray_calls = ray_calls + 1
		ray_segments[#ray_segments + 1] = {
			origin = vector.new(origin), destination = vector.new(destination),
		}
		local hits = ray_hits
		ray_hits = {}
		local index = 0
		return function()
			index = index + 1
			return hits[index]
		end
	end,
	serialize = function(value)
		serial = serial + 1
		local key = "payload:" .. serial
		serialized[key] = value
		return key
	end,
	deserialize = function(value) return serialized[value] end,
	log = function(level, message)
		logs[#logs + 1] = {level = level, message = message}
	end,
}

function core.add_entity(pos, _, staticdata)
	if fail_add_entity then
		return nil
	end
	local object = {
		pos = vector.new(pos), velocity = vector.new(0, 0, 0),
		acceleration = vector.new(0, 0, 0), removed = false,
	}
	local instance = {object = object}
	function object:get_pos()
		return not self.removed and self.pos or nil
	end
	function object:set_velocity(value) self.velocity = vector.new(value) end
	function object:set_acceleration(value) self.acceleration = vector.new(value) end
	function object:set_properties(value) self.properties = value end
	function object:is_player() return false end
	function object:get_luaentity() return instance end
	function object:remove()
		if self.removed then return end
		self.removed = true
		registered_entity.on_deactivate(instance, true)
	end
	entities[#entities + 1] = instance
	registered_entity.on_activate(instance, staticdata, 0)
	return not object.removed and object or nil
end

grug_core = {
	combat_debug_enabled = function()
		debug_enabled_calls = debug_enabled_calls + 1
		return false
	end,
	combat_debug_due = function()
		debug_due_calls = debug_due_calls + 1
		error("disabled projectile debug reached due gate")
	end,
	combat_debug_log = function()
		debug_log_calls = debug_log_calls + 1
		error("disabled projectile debug logged")
	end,
}

local function object_faction(obj)
	if obj:is_player() then return obj.faction end
	local ent = obj:get_luaentity()
	return ent and ent._grug_faction or nil
end

grug_factions = {
	hostile = function(a, b)
		local af, bf = object_faction(a), object_faction(b)
		return af ~= nil and bf ~= nil and af ~= bf
	end,
	same_faction = function(a, b)
		local af, bf = object_faction(a), object_faction(b)
		return af ~= nil and af == bf
	end,
}

local function player(name, faction)
	local obj = {name = name, faction = faction, hp = 20,
		pos = {x = 0, y = 0, z = 0}}
	function obj:is_player() return true end
	function obj:get_player_name() return self.name end
	function obj:get_hp() return self.hp end
	function obj:get_pos() return self.pos end
	function obj:get_luaentity() return nil end
	return obj
end

local function mob(name, faction, health, pos)
	local ent = {name = name, _cmi_is_mob = true,
		_grug_faction = faction, health = health or 20}
	local obj = {ent = ent, pos = pos or {x = 0, y = 0, z = 2}, removed = false}
	function obj:is_player() return false end
	function obj:get_pos() return not self.removed and self.pos or nil end
	function obj:get_luaentity() return self.ent end
	function obj:remove() self.removed = true; self.ent.health = 0 end
	return obj
end

local function plain_entity(name, pos)
	local ent = {name = name}
	local obj = {ent = ent, pos = pos or {x = 0, y = 0, z = 2}}
	function obj:is_player() return false end
	function obj:get_pos() return self.pos end
	function obj:get_luaentity() return self.ent end
	return obj
end

local function point(obj, distance)
	return {type = "object", ref = obj,
		intersection_point = {x = distance, y = 0, z = 0}}
end

local function node(name, distance)
	return {type = "node", under = {name = name},
		intersection_point = {x = distance, y = 0, z = 0}}
end

local function run_callbacks(list, obj)
	for _, callback in ipairs(list) do callback(obj) end
end

dofile(repo .. "/mods/ENTITIES/grug_projectiles/init.lua")
assert(registered_entity and registered_entity.initial_properties.static_save == false)
assert(registered_entity.initial_properties.physical == false)
assert(registered_entity.initial_properties.collide_with_objects == false)
assert(registered_entity.initial_properties.pointable == false)

local owner = player("owner", "accord")
online.owner = owner
run_callbacks(callbacks.join, owner)
local hostile = mob("test:hostile", "throng", 20, {x = 3, y = 0, z = 0})
local ally = mob("test:ally", "accord", 20, {x = 1, y = 0, z = 0})
local drop = plain_entity("__builtin:item", {x = 1.5, y = 0, z = 0})
local nonattackable = plain_entity("test:decoration", {x = 1.7, y = 0, z = 0})
local dead = mob("test:dead", "throng", 0, {x = 1.8, y = 0, z = 0})
dead.ent.health = 0
local factionless = player("neutral", nil)
factionless.pos = {x = 1.9, y = 0, z = 0}
local invalid = plain_entity("test:gone")
invalid.pos = nil
local projectile = plain_entity("grug_projectiles:projectile")

local function trace(hits)
	ray_hits = hits
	local before = ray_calls
	local result = grug_projectiles.trace_segment(owner, projectile,
		{x = 0, y = 0, z = 0}, {x = 4, y = 0, z = 0})
	assert(ray_calls == before + 1)
	return result
end

-- RaycastSort may yield the object behind a wall first; physical distance and
-- node-first tie ordering are authoritative.
local result = trace({point(hostile, 3), node("stone", 2)})
assert(result.kind == "node" and result.distance == 2)
result = trace({point(hostile, 1), node("stone", 2)})
assert(result.kind == "object" and result.target == hostile)
result = trace({point(hostile, 2), node("stone", 2)})
assert(result.kind == "node")

-- Transparent objects never body-block the later hostile.
result = trace({point(owner, 0), point(projectile, 0), point(ally, 0.5),
	point(drop, 1), point(nonattackable, 1.2), point(dead, 1.4),
	point(factionless, 1.6), point(invalid, 1.8), point(hostile, 3)})
assert(result.kind == "object" and result.target == hostile)
result = trace({node("grass", 1), point(hostile, 2)})
assert(result.kind == "object" and result.target == hostile)
result = trace({point(hostile, 3), node("stone", 2)})
assert(result.kind == "node")

local hit_count = 0
local last_damage
grug_projectiles.register("test", {
	speed = 20, max_distance = 20, lifetime = 2,
	on_hit = function(_, _, data)
		hit_count = hit_count + 1
		last_damage = data.damage
	end,
})

local function spawn(id, params)
	params = params or {}
	params.owner = params.owner or owner
	params.origin = params.origin or {x = 0, y = 0, z = 0}
	params.direction = params.direction or {x = 1, y = 0, z = 0}
	local before = #entities
	assert(grug_projectiles.spawn(id, params) == true)
	assert(#entities == before + 1)
	return entities[#entities]
end

local function step(instance, pos, dtime, hits)
	instance.object.pos = vector.new(pos)
	ray_hits = hits or {}
	local before = ray_calls
	registered_entity.on_step(instance, dtime)
	return ray_calls - before
end

-- dtime overshoot is clamped to 20 m. A target exactly at that endpoint wins
-- before range expiry and settles once with the snapshotted payload.
local shot = spawn("test", {data = {damage = 17}})
local endpoint_target = mob("test:endpoint", "throng", 20,
	{x = 20, y = 0, z = 0})
assert(step(shot, {x = 25, y = 0, z = 0}, 1.25,
	{point(endpoint_target, 20)}) == 1)
assert(ray_segments[#ray_segments].destination.x == 20)
assert(hit_count == 1 and last_damage == 17 and shot.object.removed)
registered_entity.on_step(shot, 0.1)
registered_entity.on_deactivate(shot, true)
assert(hit_count == 1)

-- Empty-space overshoot removes at range and never scans beyond 20 m.
shot = spawn("test", {data = {damage = 99}})
assert(step(shot, {x = 25, y = 0, z = 0}, 1.25, {}) == 1)
assert(ray_segments[#ray_segments].destination.x == 20)
assert(shot.object.removed and hit_count == 1)

grug_projectiles.register("short", {
	speed = 10, max_distance = 100, lifetime = 1,
	on_hit = function() hit_count = hit_count + 1 end,
})

-- Exact lifetime equality removes in this step, after sweeping its endpoint.
shot = spawn("short")
assert(step(shot, {x = 10, y = 0, z = 0}, 1, {}) == 1)
assert(ray_segments[#ray_segments].destination.x == 10 and shot.object.removed)

-- An earlier lifetime boundary clamps a large movement chord proportionally.
shot = spawn("short", {lifetime = 0.4})
assert(step(shot, {x = 25, y = 0, z = 0}, 1, {}) == 1)
assert(math.abs(ray_segments[#ray_segments].destination.x - 10) < 0.000001)
assert(shot.object.removed)

-- A stalled projectile expires without manufacturing a zero-length ray.
shot = spawn("short")
local before_zero = ray_calls
assert(step(shot, {x = 0, y = 0, z = 0}, 1, {}) == 0)
assert(ray_calls == before_zero and shot.object.removed)

-- Node collision is terminal; a later hostile cannot be hit.
shot = spawn("test")
assert(step(shot, {x = 4, y = 0, z = 0}, 0.2,
	{point(hostile, 3), node("stone", 2)}) == 1)
assert(shot.object.removed and hit_count == 1)

-- Named Fireball collision matrix on the real foundation. These use a
-- separate consumer counter so they cannot hide exactly-once failures above.
local matrix = {air=false, ally=false, wall=false, max_range=false,
	moving_target=false}
local matrix_hits = 0
local matrix_target
grug_projectiles.register("matrix", {
	speed = 20, max_distance = 20, lifetime = 2,
	on_hit = function(_, target)
		matrix_hits = matrix_hits + 1
		matrix_target = target
	end,
})

-- Air/max-range miss: one bounded 20 m sweep, no hit, terminal cleanup.
shot = spawn("matrix")
assert(step(shot, {x=25,y=0,z=0}, 1.25, {}) == 1)
assert(shot.object.removed and matrix_hits == 0)
assert(ray_segments[#ray_segments].destination.x == 20)
matrix.air, matrix.max_range = true, true

-- Ally transparency: the ally selection box does not consume the flight;
-- the hostile behind it is the one terminal object.
shot = spawn("matrix")
assert(step(shot, {x=4,y=0,z=0}, 0.2,
	{point(ally, 1), point(hostile, 3)}) == 1)
assert(shot.object.removed and matrix_hits == 1 and matrix_target == hostile)
matrix.ally = true

-- Wall: physical node distance wins over RaycastSort's hostile-object bias.
shot = spawn("matrix")
assert(step(shot, {x=4,y=0,z=0}, 0.2,
	{point(hostile, 3), node("stone", 2)}) == 1)
assert(shot.object.removed and matrix_hits == 1)
matrix.wall = true

-- Moving target: the projectile keeps its original +X velocity. A target
-- absent from the first sweep can move into the next current chord and be hit;
-- there is no target memory or homing update between steps.
local moving = mob("test:moving", "throng", 20, {x=5,y=0,z=0})
shot = spawn("matrix")
assert(shot.object.velocity.x == 20 and shot.object.velocity.y == 0
	and shot.object.velocity.z == 0)
assert(step(shot, {x=2,y=0,z=0}, 0.1, {}) == 1)
moving.pos = {x=3.5,y=0,z=0}
assert(step(shot, {x=4,y=0,z=0}, 0.1, {point(moving, 3.5)}) == 1)
assert(shot.object.removed and matrix_hits == 2 and matrix_target == moving)
matrix.moving_target = true

for name, covered in pairs(matrix) do
	assert(covered, "missing projectile matrix case: " .. name)
end

-- Owner leave/death/session replacement all remove before any collision ray.
shot = spawn("test")
run_callbacks(callbacks.leave, owner)
online.owner = nil
assert(step(shot, {x = 1, y = 0, z = 0}, 0.05, {}) == 0)
assert(shot.object.removed)

owner = player("owner", "accord")
online.owner = owner
run_callbacks(callbacks.join, owner)
shot = spawn("test")
owner.hp = 0
run_callbacks(callbacks.die, owner)
assert(step(shot, {x = 1, y = 0, z = 0}, 0.05, {}) == 0)
assert(shot.object.removed)

owner = player("owner", "accord")
online.owner = owner
run_callbacks(callbacks.join, owner)
shot = spawn("test")
local old_owner = owner
run_callbacks(callbacks.leave, old_owner)
owner = player("owner", "accord")
online.owner = owner
run_callbacks(callbacks.join, owner)
assert(step(shot, {x = 1, y = 0, z = 0}, 0.05, {}) == 0)
assert(shot.object.removed)

-- Consumer callbacks may synchronously remove the target or raise. Settlement
-- is marked first; later step/deactivate calls never replay either callback.
local removal_hits = 0
grug_projectiles.register("remove_target", {
	speed = 20, max_distance = 20, lifetime = 2,
	on_hit = function(_, target)
		removal_hits = removal_hits + 1
		target:remove()
	end,
})
shot = spawn("remove_target")
local disposable = mob("test:disposable", "throng", 20,
	{x = 2, y = 0, z = 0})
assert(step(shot, {x = 3, y = 0, z = 0}, 0.15,
	{point(disposable, 2)}) == 1)
assert(removal_hits == 1 and disposable.removed and shot.object.removed)
registered_entity.on_step(shot, 1)
registered_entity.on_deactivate(shot, true)
assert(removal_hits == 1)

local error_hits = 0
grug_projectiles.register("callback_error", {
	speed = 20, max_distance = 20, lifetime = 2,
	on_hit = function()
		error_hits = error_hits + 1
		error("intentional callback failure")
	end,
})
shot = spawn("callback_error")
assert(step(shot, {x = 3, y = 0, z = 0}, 0.15,
	{point(hostile, 2)}) == 1)
assert(error_hits == 1 and shot.object.removed)
registered_entity.on_step(shot, 1)
registered_entity.on_deactivate(shot, true)
assert(error_hits == 1)
assert(logs[#logs].level == "error"
	and logs[#logs].message:find("intentional callback failure", 1, true))

-- External unload/deactivation has no settlement effect.
shot = spawn("test")
registered_entity.on_deactivate(shot, false)
step(shot, {x = 3, y = 0, z = 0}, 0.15, {point(hostile, 2)})
assert(hit_count == 1)

-- add_entity failure is a clean spawn refusal. Disabled diagnostics reached
-- exactly their cheap enabled lookup, never due/log. Also keep detail-string
-- construction out of every debug_event callsite (the helper owns it).
fail_add_entity = true
assert(grug_projectiles.spawn("test", {
	owner = owner, origin = {x = 0, y = 0, z = 0},
	direction = {x = 1, y = 0, z = 0}, data = {},
}) == false)
fail_add_entity = false
assert(debug_enabled_calls > 0 and debug_due_calls == 0 and debug_log_calls == 0)
for line in io.lines(repo .. "/mods/ENTITIES/grug_projectiles/init.lua") do
	if line:find("debug_event%(") and not line:find("local function") then
		assert(not line:find("%.%."), "debug detail formatted before enabled gate")
	end
end

print("projectile_test: ok")
