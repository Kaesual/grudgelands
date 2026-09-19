-- Lava Flan: deep fire-resistant melee family.

local flan = {
	description = "Lava Flan", clock = "any", type = "monster",
	_grug_tier = "normal", _grug_spawn_domains = {"underground"},
	attack_type = "dogfight", attack_players = true, group_attack = true,
	reach = 3, pathfinding = 1, walk_velocity = 1, run_velocity = 3.4,
	jump = true, jump_height = 4, stepheight = 1.1, fear_height = 6,
	view_range = 10, floats = 1,
	visual = "mesh", mesh = "grug_mobs_lava_flan.b3d", glow = 10,
	textures = {{"grug_mobs_lava_flan.png"},
		{"grug_mobs_lava_flan2.png"}, {"grug_mobs_lava_flan3.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 1.2, 0.5},
	makes_footstep_sound = false,
	animation = {
		stand_start = 0, stand_end = 8, stand_speed = 15,
		walk_start = 10, walk_end = 18, walk_speed = 15,
		run_start = 20, run_end = 28, run_speed = 30,
		punch_start = 20, punch_end = 28, punch_speed = 30,
	},
	drops = {
		{name = "grug_materials:emberglass", chance = 5, min = 1, max = 1},
		{name = "grug_mobs:slime_gel", chance = 2, min = 1, max = 1},
	},
	water_damage = 8, lava_damage = 0, fire_damage = 0, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:lava_flan", flan)
mobs:spawn({name = "grug_mobs:lava_flan",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 2200, active_object_count = 3,
	min_height = -31000, max_height = -700})
