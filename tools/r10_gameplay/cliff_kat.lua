-- Source-faithful focused coverage for the vendored mobs_redo cliff predicate.
return function(root)
	local file = assert(io.open(root .. "/mods/ENTITIES/mobs/api.lua", "rb"))
	local source = file:read("*a")
	file:close()
	local first = assert(source:find("function mob_class:is_at_cliff()", 1, true))
	local last = assert(source:find("\nend\n\n-- check for nodes", first, true))
	local chunk = assert(loadstring([[
local mob_class, sin, cos = {}, math.sin, math.cos
local function node_ok(pos) return {name = probe.node, pos = pos} end
local function is_node_dangerous() return probe.dangerous end
]] .. source:sub(first, last + 4) .. [[
return mob_class.is_at_cliff
]]))

	local probe = {node = "test:stone", dangerous = false, free_fall = false,
		blocker = {x = 0, y = -1, z = 1}, calls = 0}
	local core = {
		registered_nodes = {
			["test:stone"] = {walkable = true},
			["test:water"] = {walkable = false},
			["test:spikes"] = {walkable = true},
		},
		line_of_sight = function(first_pos, last_pos)
			probe.calls = probe.calls + 1
			probe.first, probe.last = first_pos, last_pos
			return probe.free_fall, probe.blocker
		end,
	}
	local environment = {core = core, probe = probe, math = math,
		type = type, pairs = pairs, ipairs = ipairs, tonumber = tonumber,
		tostring = tostring, assert = assert, error = error}
	environment._G = environment
	setfenv(chunk, environment)
	local is_at_cliff = chunk()
	local mob = {
		state = "walk", fear_height = 0, fly = false,
		object = {
			get_yaw = function() return 0 end,
			get_properties = function()
				return {collisionbox = {-0.4, -1, -0.4, 0.4, 1, 0.4}}
			end,
			get_pos = function() return {x = 4, y = 10, z = -3} end,
		},
	}

	assert(is_at_cliff(mob) == false, "walkable one-node support rejected")
	assert(probe.calls == 1 and probe.first.y == 9 and probe.last.y == 7 and
		probe.first.x == 4 and probe.first.z == -2.1,
		"ambient two-node forward probe endpoints differ")
	probe.free_fall = true
	assert(is_at_cliff(mob) == true, "deep all-air drop accepted")
	probe.free_fall, probe.node = false, "test:water"
	assert(is_at_cliff(mob) == true, "non-walkable blocker accepted as support")
	probe.node = "test:missing"
	assert(is_at_cliff(mob) == true, "unregistered blocker accepted or dereferenced")
	probe.node, probe.dangerous = "test:spikes", true
	assert(is_at_cliff(mob) == true, "dangerous support accepted")
	probe.dangerous = false
	local before = probe.calls
	mob.fly = true
	assert(is_at_cliff(mob) == nil and probe.calls == before,
		"flight unexpectedly used ambient cliff probe")
	mob.fly, mob.state = false, "attack"
	assert(is_at_cliff(mob) == nil and probe.calls == before,
		"fear-zero combat unexpectedly used ambient cliff probe")
	mob.state, mob.fear_height, probe.node = "attack", 3, "test:stone"
	assert(is_at_cliff(mob) == false and probe.last.y == 6,
		"authored non-ambient fear height changed")
	return "r10/cliff\twalkable=pass\tdeep=pass\tnonwalkable=pass\tmissing=pass\tdanger=pass\texceptions=pass\n"
end
