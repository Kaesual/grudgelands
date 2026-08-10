-- Focused plain-Lua-5.1 real-code test for WP39's shared combat ray.

local repo = arg[1] or "."
local ray_hits = {}
local ray_calls = 0

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
function vector.multiply(a, n)
	return {x = a.x * n, y = a.y * n, z = a.z * n}
end
function vector.distance(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end
function vector.normalize(a)
	local length = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
	if length == 0 then
		return {x = 0, y = 0, z = 0}
	end
	return {x = a.x / length, y = a.y / length, z = a.z / length}
end

local factions = {attacker = "accord", ally = "accord", enemy = "throng"}
core = {
	registered_nodes = {
		stone = {walkable = true},
		grass = {walkable = false},
	},
	get_node_or_nil = function(pos)
		return {name = pos.name}
	end,
	raycast = function()
		ray_calls = ray_calls + 1
		local index = 0
		return function()
			index = index + 1
			return ray_hits[index]
		end
	end,
}
grug_core = {
	get_player_faction = function(name)
		return factions[name]
	end,
}

local function player(name, pos)
	local obj = {name = name, pos = pos or {x = 0, y = 0, z = 0}, hp = 20}
	function obj:get_pos() return self.pos end
	function obj:get_properties() return {eye_height = 1.625} end
	function obj:get_eye_offset() return {x = 10, y = 5, z = 20} end
	function obj:get_look_dir() return {x = 0, y = 0, z = 1} end
	function obj:get_look_horizontal() return 0 end
	function obj:get_player_name() return self.name end
	function obj:is_player() return true end
	function obj:get_hp() return self.hp end
	function obj:get_luaentity() return nil end
	return obj
end

local function mob(name, faction, health)
	local ent = {name = name, _cmi_is_mob = true,
		_grug_faction = faction, health = health or 20}
	local obj = {pos = {x = 0, y = 2, z = 3}, ent = ent}
	function obj:get_pos() return self.pos end
	function obj:is_player() return false end
	function obj:get_luaentity() return self.ent end
	return obj
end

local attacker = player("attacker")
local hostile = mob("grug_mobs:boar", "throng", 20)
local friendly = mob("grug_mobs:guard", "accord", 20)
local dead = mob("grug_mobs:dead", "throng", 0)
local item = mob("__builtin:item", nil, 20)
item.ent._cmi_is_mob = nil

dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")

-- Eye offset is local X/Z rotated with yaw and scaled from tenths of a node.
local eye = grug_core.combat_eye_pos(attacker)
assert(math.abs(eye.x - 1) < 0.000001)
assert(math.abs(eye.y - 2.125) < 0.000001)
assert(math.abs(eye.z - 2) < 0.000001)

local function point(ref, distance)
	return {type = "object", ref = ref,
		intersection_point = {x = eye.x, y = eye.y, z = eye.z + distance}}
end

-- Self is skipped inside the same ray; the first hostile selection box wins.
ray_hits = {point(attacker, 0), point(hostile, 2)}
local before = ray_calls
local result = grug_core.combat_ray(attacker, 4)
assert(ray_calls == before + 1)
assert(result.status == "target" and result.reason == "hostile")
assert(result.target == hostile and result.blocker == nil)
assert(result.object_kind == "mob" and result.alive == true)
assert(math.abs(vector.distance(result.origin, result.destination) - 4) < 0.000001)

-- Engine RaycastSort biases objects ahead of nodes by BS^2. The helper must
-- exhaust the same iterator and restore physical intersection order.
ray_hits = {point(hostile, 3), {type = "node", under = {name = "stone"},
	intersection_point = {x = eye.x, y = eye.y, z = eye.z + 2}}}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "node" and result.node == "stone")

ray_hits = {point(hostile, 1), {type = "node", under = {name = "stone"},
	intersection_point = {x = eye.x, y = eye.y, z = eye.z + 2}}}
result = grug_core.combat_ray(attacker, 4)
assert(result.status == "target" and result.target == hostile)

ray_hits = {point(hostile, 2), {type = "node", under = {name = "stone"},
	intersection_point = {x = eye.x, y = eye.y, z = eye.z + 2}}}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "node" and result.node == "stone")

ray_hits = {point(friendly, 2), point(hostile, 3)}
result = grug_core.combat_ray(attacker, 4)
assert(result.status == "aim_miss" and result.reason == "friendly")
assert(result.blocker == friendly)

ray_hits = {{type = "node", under = {name = "stone"},
	intersection_point = {x = eye.x, y = eye.y, z = eye.z + 1}}}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "node" and result.node == "stone")

-- A non-walkable pointed node does not become combat geometry.
ray_hits = {{type = "node", under = {name = "grass"}}, point(hostile, 2)}
result = grug_core.combat_ray(attacker, 4)
assert(result.status == "target" and result.target == hostile)

ray_hits = {}
result = grug_core.combat_ray(attacker, 4)
assert(result.status == "aim_miss" and result.reason == "empty")

ray_hits = {point(dead, 2)}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "dead" and result.alive == false)

ray_hits = {point(item, 2)}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "object" and result.object_kind == "object")

-- Defensive distinction for an engine/mock intersection beyond the endpoint.
ray_hits = {point(hostile, 4.1)}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "out_of_range" and result.status == "aim_miss")

local ally_player = player("ally", {x = 0, y = 0, z = 2})
ray_hits = {point(ally_player, 2)}
result = grug_core.combat_ray(attacker, 4)
assert(result.reason == "friendly" and result.object_kind == "player")

local enemy_player = player("enemy", {x = 0, y = 0, z = 2})
ray_hits = {point(enemy_player, 2)}
result = grug_core.combat_ray(attacker, 4)
assert(result.status == "target" and result.relation == "hostile")

print("combat_aim_test: ok")
