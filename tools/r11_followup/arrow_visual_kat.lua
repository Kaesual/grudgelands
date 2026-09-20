-- Focused LuaJIT KAT for the Round 11 arrow mesh and held-draw animation seam.

local repo = arg[1] or "."

local function close(a, b)
	return math.abs(a - b) < 0.000001
end

-- Exercise the actual vendored player_api animation selector.
local join_callbacks = {}
local leave_callbacks = {}
local globalsteps = {}
local connected = {}
minetest = {
	register_on_joinplayer = function(fn) join_callbacks[#join_callbacks + 1] = fn end,
	register_on_leaveplayer = function(fn) leave_callbacks[#leave_callbacks + 1] = fn end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	get_connected_players = function() return connected end,
	calculate_knockback = function() return 1 end,
}

local actor = {controls = {LMB = true}, hp = 20, animations = {}}
function actor:get_player_name() return "archer" end
function actor:get_player_control() return self.controls end
function actor:get_hp() return self.hp end
function actor:set_properties() end
function actor:set_local_animation() end
function actor:set_animation(animation)
	self.animations[#self.animations + 1] = animation
end

dofile(repo .. "/mods/BASE/player_api/api.lua")
player_api.register_model("test.b3d", {
	animation_speed = 30,
	animations = {
		stand = {x = 0, y = 1}, walk = {x = 2, y = 3},
		mine = {x = 4, y = 5}, walk_mine = {x = 6, y = 7},
		lay = {x = 8, y = 9},
	},
})
for _, callback in ipairs(join_callbacks) do callback(actor) end
player_api.set_model(actor, "test.b3d")
connected[1] = actor
local drawing = false
player_api.register_control_animation_override(function(player, controls)
	if player ~= actor or not drawing then return end
	return (controls.up or controls.down or controls.left or controls.right)
		and "walk" or "stand"
end)
globalsteps[1](0.05)
assert(player_api.get_animation(actor).animation == "mine")
drawing = true
globalsteps[1](0.05)
assert(player_api.get_animation(actor).animation == "stand")
actor.controls.up = true
globalsteps[1](0.05)
assert(player_api.get_animation(actor).animation == "walk")
drawing = false
globalsteps[1](0.05)
assert(player_api.get_animation(actor).animation == "walk_mine")

-- Exercise the actual projectile foundation and its velocity orientation.
vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
function vector.add(a, b) return {x = a.x+b.x, y = a.y+b.y, z = a.z+b.z} end
function vector.subtract(a, b) return {x = a.x-b.x, y = a.y-b.y, z = a.z-b.z} end
function vector.multiply(a, n) return {x = a.x*n, y = a.y*n, z = a.z*n} end
function vector.length(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end
function vector.normalize(a)
	local length = vector.length(a)
	return length > 0 and vector.multiply(a, 1/length) or {x=0,y=0,z=0}
end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end

local callbacks = {join = {}}
local registered_entity
local payloads = {}
local payload_index = 0
local online = {}
core = {
	registered_nodes = {},
	get_current_modname = function() return "grug_projectiles" end,
	get_modpath = function() return repo .. "/mods/ENTITIES/grug_projectiles" end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join+1] = fn end,
	register_on_respawnplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_entity = function(_, def) registered_entity = def end,
	register_on_mods_loaded = function() end,
	register_globalstep = function() end,
	get_player_by_name = function(name) return online[name] end,
	get_node_or_nil = function() return nil end,
	raycast = function() return function() end end,
	serialize = function(value)
		payload_index = payload_index + 1
		payloads[payload_index] = value
		return payload_index
	end,
	deserialize = function(index) return payloads[index] end,
	-- Pinned Luanti builtin/common/item_s.lua:153-155.
	dir_to_yaw = function(direction) return -math.atan2(direction.x, direction.z) end,
	log = function() end,
}
grug_core = {
	get_player_level = function() return 1 end,
	combat_debug_enabled = function() return false end,
}
grug_factions = {hostile = function() return false end, same_faction = function() return false end}
grug_mobs = {is_noncombatant = function() return false end}

function core.add_entity(pos, _, staticdata)
	local object = {
		pos = vector.new(pos), velocity = vector.new(0,0,0),
		rotation = nil, removed = false,
	}
	local entity = {object = object}
	function object:get_pos() return not self.removed and self.pos or nil end
	function object:get_velocity() return self.velocity end
	function object:set_velocity(value) self.velocity = vector.new(value) end
	function object:set_acceleration(value) self.acceleration = vector.new(value) end
	function object:set_rotation(value) self.rotation = vector.new(value) end
	function object:set_properties(value) self.properties = value end
	function object:get_luaentity() return entity end
	function object:remove() self.removed = true end
	registered_entity.on_activate(entity, staticdata)
	return object
end

dofile(repo .. "/mods/ENTITIES/grug_projectiles/init.lua")
local owner = {name = "archer", hp = 20}
function owner:is_player() return true end
function owner:get_player_name() return self.name end
function owner:get_hp() return self.hp end
online.archer = owner
for _, callback in ipairs(callbacks.join) do callback(owner) end

grug_projectiles.register("visual", {
	speed = 40, max_distance = 25, lifetime = 8,
	orient_to_velocity = true,
	properties = {
		visual = "mesh", mesh = "grug_projectiles_arrow.obj",
		textures = {"grug_projectiles_arrow.png"},
	},
	on_hit = function() end,
})
-- Retrieve the live projectile through a small add_entity wrapper probe.
local original_add = core.add_entity
local spawned
core.add_entity = function(...)
	spawned = original_add(...)
	return spawned
end
assert(grug_projectiles.spawn("visual", {
	owner = owner, origin = {x=0,y=0,z=0}, direction = {x=1,y=0,z=0},
	acceleration = {x=0,y=-9.81,z=0},
}))
assert(spawned.properties.visual == "mesh")
assert(spawned.properties.mesh == "grug_projectiles_arrow.obj")
assert(spawned.properties.textures[1] == "grug_projectiles_arrow.png")
assert(close(spawned.rotation.y, -math.pi) and close(spawned.rotation.z, 0))
spawned.velocity = {x=30,y=-10,z=0}
spawned.pos = {x=1,y=-0.1,z=0}
registered_entity.on_step(spawned:get_luaentity(), 0.05)
assert(spawned.rotation.z < 0, "gravity-adjusted velocity did not pitch arrow down")
assert(close(spawned.rotation.z, math.asin(-10/math.sqrt(1000))))

local scout_file = assert(io.open(repo ..
	"/mods/PLAYER/grug_abilities/scout.lua", "rb"))
local scout_source = scout_file:read("*a")
scout_file:close()
assert(scout_source:find("orient_to_velocity = true", 1, true))
assert(scout_source:find('mesh = "grug_projectiles_arrow.obj"', 1, true))
assert(scout_source:find('textures = {"grug_projectiles_arrow.png"}', 1, true))
assert(scout_source:find("visual_size = {x = -1, y = 1}", 1, true),
	"VoxeLibre mesh reflection was not preserved")

print("r11_arrow_visual PASS mesh=arrow orientation=launch+gravity actor=stand+walk")
