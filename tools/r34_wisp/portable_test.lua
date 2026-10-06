-- Round 34: the Wisp's blink never lands in a liquid (a swimming target must
-- not pull it under water); air and plants stay valid landing nodes.
-- luajit tools/r34_wisp/portable_test.lua [repo]
local repo = arg[1] or "."

local nodes = {}
local moved
core = {
	registered_nodes = {
		air = {walkable = false},
		["default:grass_1"] = {walkable = false},
		["default:water_source"] = {walkable = false, liquidtype = "source"},
		["default:water_flowing"] = {walkable = false, liquidtype = "flowing"},
		["default:stone"] = {walkable = true},
	},
	get_node_or_nil = function(pos)
		return {name = nodes[pos.y >= 1 and "upper" or "lower"] or "air"}
	end,
	get_objects_inside_radius = function() return {} end,
	is_player = function() return false end,
}
grug_core = {invalidate_combat_identity = function() end,
	particles = dofile(repo .. "/tools/r40_pm/helper_stub.lua")(repo)} -- Round 40 PM
local defs = {}
grug_mobs = {
	register_mob = function(name, def) defs[name] = def end,
	camp_swarm = function() end,
	stalker = function() end,
	slow_player = function() end,
	atlas_textures = function(texture) return texture end,
}
mobs = {spawn = function() end, register_arrow = function() end}
dofile(repo .. "/mods/ENTITIES/grug_mobs/night_families.lua")
local wisp = assert(defs["grug_mobs:wisp"], "wisp registered")

-- The wisp stands at y 0 and its target 10 nodes away; the blink lands 2.5
-- nodes ahead, checking the landing node (y 0) and the one above (y 1).
local function blink(lower, upper)
	nodes.lower, nodes.upper, moved = lower, upper, nil
	local self = {state = "attack", temp = {grug_wisp_blink = 5},
		object = {
			get_pos = function() return {x = 0, y = 0, z = 0} end,
			set_pos = function(_, pos) moved = pos end,
		},
		attack = {get_pos = function() return {x = 10, y = 0, z = 0} end},
	}
	wisp.do_custom(self, 0)
	return moved ~= nil
end

local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL: " .. label, 0) end
end
check(blink("air", "air"), "blinks into air")
check(blink("default:grass_1", "air"), "blinks into grass")
check(not blink("default:water_source", "air"), "no blink into water")
check(not blink("air", "default:water_source"), "no blink with water above")
check(not blink("default:water_flowing", "default:water_flowing"), "no blink into flowing water")
check(not blink("default:stone", "air"), "no blink into stone")
print(("R34 WISP PORTABLE PASS checks=%d"):format(checks))
