-- Focused regression for the real mobs_redo ground-support predicate and its
-- dogfight chase consumer.
return function(root)
	local file = assert(io.open(root .. "/mods/ENTITIES/mobs/api.lua", "rb"))
	local source = file:read("*a")
	file:close()
	local first = assert(source:find("local function has_safe_support", 1, true))
	local last = assert(source:find("\nend\n\n-- check for nodes", first, true))
	local chunk = assert(loadstring([[
local mob_class, sin, cos = {}, math.sin, math.cos
local floor, ceil = math.floor, math.ceil
local function get_node(pos)
	local name = world[pos.y] or "air"
	return {name = name, loaded = name ~= "ignore"}
end
local function is_node_dangerous(_, name) return name == "test:spikes" end
]] .. source:sub(first, last + 4) .. [[
return mob_class.is_at_cliff
]]))

	local world = {}
	local core = {registered_nodes = {
		air = {walkable = false},
		["test:grass"] = {walkable = false},
		["test:stone"] = {walkable = true},
		["test:water"] = {walkable = false, liquidtype = "source"},
		["test:spikes"] = {walkable = true},
		ignore = {walkable = false},
	}}
	local environment = {core = core, world = world, math = math,
		type = type, pairs = pairs, ipairs = ipairs, tonumber = tonumber,
		tostring = tostring, assert = assert, error = error}
	environment._G = environment
	setfenv(chunk, environment)
	local is_at_cliff = chunk()
	local mob = {state = "attack", fear_height = 6, fly = false,
		reach_ext = 0, run_velocity = 4.6, walk_velocity = 1,
		path = {stuck = false}, order = "", animation = nil,
		object = {
			get_yaw = function() return 0 end,
			get_properties = function()
				return {collisionbox = {-0.45, -0.01, -0.45, 0.45, 0.86, 0.45}}
			end,
			get_pos = function() return {x = 0, y = 10.51, z = 0} end,
		},
		set_velocity = function(self, velocity) self.recorded_velocity = velocity end,
		set_animation = function(self, animation) self.recorded_animation = animation end,
	}

	local chase_guard = assert(source:find("if self.at_cliff or pad < 0.2 then",
		1, true))
	local chase_end = assert(source:find("\n\t\t\telse -- rnd: if inside reach range",
		chase_guard, true))
	local chase_chunk = assert(loadstring("return function(self, pad, dist)\n" ..
		source:sub(chase_guard, chase_end - 1) .. "\nend"))
	setfenv(chase_chunk, environment)
	local chase = chase_chunk()
	local function pursuit_velocity()
		mob.at_cliff = is_at_cliff(mob)
		mob.recorded_velocity = nil
		chase(mob, 1, 10)
		return mob.recorded_velocity
	end

	world[11], world[10] = "test:grass", "test:stone"
	assert(pursuit_velocity() == 4.6,
		"vegetation over solid ground stopped ranged-hit pursuit")
	world[10] = nil
	assert(pursuit_velocity() == 0,
		"unsupported vegetation did not stop pursuit at a cliff")
	world[10] = "test:stone"
	world[11] = "test:water"
	assert(pursuit_velocity() == 0,
		"liquid over solid ground was accepted as pursuit support")
	world[11] = "ignore"
	assert(pursuit_velocity() == 0,
		"unloaded ground was accepted as pursuit support")

	return "r11/vegetation-chase\tplant=run\tcliff=stop\tliquid=stop\tignore=stop\n"
end
