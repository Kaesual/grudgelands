-- Crystal Shard: ranged middle/deep cave family.

grug_mobs.register_simple_arrow("grug_mobs:crystal_shard_entity", {
	texture = "default_mese_crystal_fragment.png", velocity = 8,
	size = {x = 0.3, y = 0.3}, glow = 6, lifetime = 5,
})

local shard = {
	description = "Crystal Shard", clock = "any", type = "monster",
	_grug_tier = "normal", _grug_spawn_domains = {"underground"},
	attack_type = "dogshoot", attack_players = true, group_attack = false,
	reach = 3, pathfinding = 1, walk_velocity = 1.5, run_velocity = 4.6,
	jump = true, jump_height = 8, stepheight = 2.1, fear_height = 6,
	view_range = 16, dogshoot_switch = 1,
	dogshoot_count_max = 8, dogshoot_count2_max = 2,
	arrow = "grug_mobs:crystal_shard_entity",
	arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 1.6, shoot_offset = 0.75,
	visual = "mesh", mesh = "grug_mobs_crystal_shard.b3d", glow = 5,
	textures = {{"grug_mobs_crystal_shard.png"}},
	visual_size = {x = 10, y = 10},
	collisionbox = {-0.6, -0.5, -0.6, 0.6, 1.8, 0.6},
	makes_footstep_sound = false,
	animation = {
		stand_start = 60, stand_end = 83, stand_speed = 18,
		walk_start = 10, walk_end = 41, walk_speed = 20,
		run_start = 10, run_end = 41, run_speed = 30,
		shoot_start = 100, shoot_end = 113, shoot_speed = 18,
		punch_start = 175, punch_end = 189, punch_speed = 18,
		die_start = 125, die_end = 141, die_speed = 25, die_loop = false,
	},
	drops = {
		{name = "grug_materials:emberglass_shard", chance = 1, min = 1, max = 2},
		{name = "grug_materials:emberglass", chance = 6, min = 1, max = 1},
	},
	water_damage = 1, lava_damage = 1, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:crystal_shard", shard)
mobs:spawn({name = "grug_mobs:crystal_shard",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 2600, active_object_count = 2,
	min_height = -700, max_height = -300})
