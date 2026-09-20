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

	local probe = {node = "test:stone", dangerous = false,
		blocker = {x = 0, y = -1, z = 1}, calls = 0}
	local support_y
	-- Pinned numeric.h floatToInt: exact halves round away from zero.  The
	-- vertical-only walk models the inclusive endpoint behavior relevant to
	-- this probe; X/Z stay inside the same forward column.
	local function float_to_int(value)
		if value > 0 then return math.floor(value + 0.5) end
		return math.ceil(value - 0.5)
	end
	local core = {
		registered_nodes = {
			["test:stone"] = {walkable = true},
			["test:water"] = {walkable = false},
			["test:spikes"] = {walkable = true},
		},
		line_of_sight = function(first_pos, last_pos)
			probe.calls = probe.calls + 1
			probe.first, probe.last = first_pos, last_pos
			local first_y = float_to_int(first_pos.y)
			local last_y = float_to_int(last_pos.y)
			local step = first_y <= last_y and 1 or -1
			for y = first_y, last_y, step do
				if y == support_y then
					probe.blocker = {x = float_to_int(first_pos.x), y = y,
						z = float_to_int(first_pos.z)}
					return false, probe.blocker
				end
			end
			return true
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
			get_pos = function() return {x = 4, y = 11.5, z = -3} end,
		},
	}

	local function check_boundary(feet, flat, label)
		mob.object.get_pos = function() return {x = 4, y = feet + 1, z = -3} end
		support_y = flat
		assert(is_at_cliff(mob) == false, label .. " flat support rejected")
		support_y = flat - 1
		assert(is_at_cliff(mob) == false, label .. " one-node descent refused")
		support_y = flat - 2
		assert(is_at_cliff(mob) == true, label .. " two-node descent accepted")
		support_y = flat - 3
		assert(is_at_cliff(mob) == true, label .. " deep descent accepted")
	end
	check_boundary(10.5, 10, "positive half")
	assert(probe.first.y == 10.5 and probe.last.y == 9 and
		probe.first.x == 4 and probe.first.z == -2.1,
		"ambient one-and-a-half-node forward probe endpoints differ")
	check_boundary(-10.5, -11, "negative half")
	check_boundary(0.5, 0, "zero crossing")
	check_boundary(10.5001, 10, "positive clearance")
	check_boundary(10.4999, 10, "negative clearance")
	-- Continue predicate coverage from the negative signed contact.
	mob.object.get_pos = function() return {x = 4, y = -9.5, z = -3} end
	support_y, probe.node = -12, "test:water"
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
	mob.state, mob.fear_height, probe.node, support_y = "attack", 3, "test:stone", -13
	assert(is_at_cliff(mob) == false and probe.last.y == -13.5,
		"authored non-ambient fear height changed")
	return "r10/cliff\tflat=pass\tone=pass\ttwo=refused\tsigned-half=pass\tnonwalkable=pass\tmissing=pass\tdanger=pass\texceptions=pass\n"
end
