-- Land Guard: solitary T6 elite. The elite tier supplies its telegraphed slam.

local guard = {
	description = "Land Guard", clock = "any", type = "monster",
	_grug_tier = "elite", _grug_spawn_domains = {"underground"},
	attack_type = "dogfight", attack_players = true, group_attack = false,
	reach = 3, pathfinding = 1, walk_velocity = 1.5, run_velocity = 4.6,
	jump = true, jump_height = 4, stepheight = 1.1, fear_height = 8,
	view_range = 14,
	visual = "mesh", mesh = "grug_mobs_dungeon_master.b3d", glow = 2,
	textures = {{"grug_mobs_land_guard.png"},
		{"grug_mobs_land_guard2.png"}, {"grug_mobs_land_guard3.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -1.01, -0.5, 0.5, 1.6, 0.5},
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 19, stand_speed = 15,
		walk_start = 20, walk_end = 35, walk_speed = 15,
		run_start = 20, run_end = 35, run_speed = 40,
		punch_start = 36, punch_end = 48, punch_speed = 20,
	},
	drops = {
		{name = "grug_mobs:heavy_leather", chance = 2, min = 1, max = 2},
		{name = "grug_materials:rough_diamond", chance = 4, min = 1, max = 1},
	},
	water_damage = 0, lava_damage = 6, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:land_guard", guard)
mobs:spawn({name = "grug_mobs:land_guard",
	nodes = {"group:grug_stratum"}, max_light = 5,
	interval = 30, chance = 9000, active_object_count = 1,
	min_height = -31000, max_height = -1000})
