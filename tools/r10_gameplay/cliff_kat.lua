-- Source-faithful focused coverage for the vendored mobs_redo cliff predicate.
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
	probe.calls = probe.calls + 1
	if probe.cover_y and pos.y == probe.cover_y then
		return {name = probe.cover_node}
	end
	if pos.y ~= probe.support_y then return {name = "air"} end
	return {name = probe.node}
end
local function is_node_dangerous(_, name)
	return probe.dangerous[name] == true
end
]] .. source:sub(first, last + 4) .. [[
return mob_class.is_at_cliff
]]))

	local probe = {node = "test:stone", dangerous = {},
		blocker = {x = 0, y = -1, z = 1}, calls = 0}
	local support_y, cover_y
	local core = {
		registered_nodes = {
			air = {walkable = false},
			["test:stone"] = {walkable = true},
			["test:water"] = {walkable = false, liquidtype = "source"},
			["test:spikes"] = {walkable = true},
		},
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
		cover_y, probe.cover_y = nil, nil
		support_y = flat
		probe.support_y = support_y
		assert(is_at_cliff(mob) == false, label .. " flat support rejected")
		support_y = flat - 1
		probe.support_y = support_y
		assert(is_at_cliff(mob) == false, label .. " one-node descent refused")
		support_y = flat - 2
		probe.support_y = support_y
		assert(is_at_cliff(mob) == true, label .. " two-node descent accepted")
		support_y = flat - 3
		probe.support_y = support_y
		assert(is_at_cliff(mob) == true, label .. " deep descent accepted")
	end
	check_boundary(10.5, 10, "positive half")
	check_boundary(-10.5, -11, "negative half")
	check_boundary(0.5, 0, "zero crossing")
	check_boundary(10.5001, 10, "positive clearance")
	check_boundary(10.4999, 10, "negative clearance")
	-- The engine's LOS stops at every non-air node.  A harmless plant in the
	-- forward column must be skipped so the real walkable support below it can
	-- authorize the same chase that bare ground does.
	mob.state, mob.fear_height = "attack", 6
	mob.object.get_pos = function() return {x = 4, y = 11.5, z = -3} end
	cover_y, support_y = 11, 10
	probe.cover_y, probe.support_y = cover_y, support_y
	probe.cover_node = "test:grass"
	core.registered_nodes["test:grass"] = {walkable = false}
	probe.calls = 0
	assert(is_at_cliff(mob) == false, "harmless vegetation blocked combat chase")
	assert(probe.calls >= 2, "vegetation was not skipped to inspect real support")
	-- Vegetation alone does not manufacture support over a deep drop.
	support_y = 3
	probe.support_y = support_y
	assert(is_at_cliff(mob) == true, "unsupported vegetation hid a combat cliff")
	-- Exact negative-half endpoints are inclusive: the support at -1 remains
	-- reachable below vegetation at 1.
	mob.object.get_pos = function() return {x = 4, y = 1.5, z = -3} end
	mob.fear_height = 1
	cover_y, support_y = 1, -1
	probe.cover_y, probe.support_y = cover_y, support_y
	assert(is_at_cliff(mob) == false,
		"negative exact-half endpoint support was excluded")
	cover_y, probe.cover_y = nil, nil
	-- Continue predicate coverage from the negative signed contact.
	mob.state, mob.fear_height = "walk", 0
	mob.object.get_pos = function() return {x = 4, y = -9.5, z = -3} end
	support_y, probe.node = -12, "test:water"
	probe.support_y = support_y
	assert(is_at_cliff(mob) == true, "non-walkable blocker accepted as support")
	-- A liquid above solid support stays unsafe; vegetation skipping must not
	-- introduce a new wading rule.
	cover_y, support_y = -11, -12
	probe.cover_y, probe.cover_node, probe.support_y = cover_y,
		"test:water", support_y
	probe.node = "test:stone"
	assert(is_at_cliff(mob) == true, "liquid over solid support became safe")
	cover_y, probe.cover_y = nil, nil
	probe.node = "test:missing"
	probe.support_y = support_y
	assert(is_at_cliff(mob) == true, "unregistered blocker accepted or dereferenced")
	probe.node, probe.dangerous["test:spikes"] = "test:spikes", true
	assert(is_at_cliff(mob) == true, "dangerous support accepted")
	probe.dangerous["test:spikes"] = nil
	local before = probe.calls
	mob.fly = true
	assert(is_at_cliff(mob) == nil and probe.calls == before,
		"flight unexpectedly used ambient cliff probe")
	mob.fly, mob.state = false, "attack"
	assert(is_at_cliff(mob) == nil and probe.calls == before,
		"fear-zero combat unexpectedly used ambient cliff probe")
	mob.state, mob.fear_height, probe.node, support_y = "attack", 3, "test:stone", -13
	probe.support_y = support_y
	assert(is_at_cliff(mob) == false,
		"authored non-ambient fear height changed")
	return "r10/cliff\tflat=pass\tone=pass\ttwo=refused\tsigned-half=pass\tvegetation-chase=pass\tnonwalkable=pass\tmissing=pass\tdanger=pass\texceptions=pass\n"
end
