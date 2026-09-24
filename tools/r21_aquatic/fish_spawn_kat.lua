local repo = assert(arg[1], "repository root required")
local nodes = {}
core = {
	get_node = function(pos) return {name = nodes[pos.y] or "air"} end,
}
grug_zones = {water_class_at = function() return "planned_water" end}
local captured
grug_mobs = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/disposition.lua")
grug_mobs.register_mob = function(name, def)
	grug_mobs.apply_disposition(name, def)
	captured = def
end
mobs = {spawn = function() end}
dofile(repo .. "/mods/ENTITIES/grug_mobs/reed_angelfish.lua")
assert(captured and captured._grug_spawn_check, "fish spawn callback absent")
assert(captured._grug_disposition == "critter" and captured.passive == true,
	"fish must register as a passive critter")
nodes[0], nodes[1] = "default:water_source", "air"
assert(not captured._grug_spawn_check({x = 0, y = 0, z = 0}), "surface candidate allowed")
nodes[1] = "default:water_source"
assert(captured._grug_spawn_check({x = 0, y = 0, z = 0}), "submerged candidate rejected")
grug_zones.water_class_at = function() return "coastal_shelf" end
assert(not captured._grug_spawn_check({x = 0, y = 0, z = 0}), "sea candidate allowed")
print("r21_aquatic_fish_spawn_kat\tpass")
