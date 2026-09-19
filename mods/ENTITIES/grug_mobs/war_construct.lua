-- War Construct: 24-hour front elite. The central elite tier owns its
-- combat multipliers, gold tint, scale and two-second slam telegraph.

local construct = {
	description = "War Construct", clock = "any", type = "monster",
	_grug_tier = "elite", attack_type = "dogfight", attack_players = true,
	group_attack = false, reach = 3, pathfinding = 1,
	walk_velocity = 1.5, run_velocity = 4.6, jump = true, jump_height = 4,
	stepheight = 1.1, fear_height = 6, view_range = 14,
	visual = "mesh", mesh = "grug_mobs_war_construct.b3d",
	textures = {{"grug_mobs_war_construct.png"}},
	visual_size = {x = 3, y = 3},
	collisionbox = {-0.7, -0.01, -0.7, 0.7, 2.69, 0.7},
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 0, stand_speed = 15,
		walk_start = 0, walk_end = 40, walk_speed = 15,
		run_start = 40, run_end = 80, run_speed = 25,
		punch_start = 80, punch_end = 90, punch_speed = 15,
	},
	drops = {
		{name = "grug_mobs:stone_core", chance = 1, min = 1, max = 1},
		{name = "grug_materials:iron_bar", chance = 1, min = 2, max = 4},
	},
	water_damage = 0, lava_damage = 4, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:war_construct", construct)
mobs:spawn({name = "grug_mobs:war_construct",
	nodes = {"grug_nodes:mud", "grug_nodes:mesa_clay",
		"default:dry_dirt_with_dry_grass", "default:stone"},
	interval = 30, chance = 7000, active_object_count = 1,
	min_height = 0, max_height = 300})
