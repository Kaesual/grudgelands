-- Dungeon Master: classic ranged fireball family in the deep middle bands.

grug_mobs.register_simple_arrow("grug_mobs:dungeon_fireball", {
	texture = "fire_basic_flame.png", velocity = 7,
	size = {x = 1, y = 1}, glow = 8, tail = true,
	tail_texture = "fire_basic_flame.png", lifetime = 6,
})

local master = {
	description = "Dungeon Master", clock = "any", type = "monster",
	_grug_tier = "normal", _grug_spawn_domains = {"underground"},
	attack_type = "dogshoot", attack_players = true, group_attack = false,
	reach = 3, pathfinding = 1, walk_velocity = 1.5, run_velocity = 4.6,
	jump = true, jump_height = 4, stepheight = 1.1, fear_height = 6,
	view_range = 16, dogshoot_switch = 1,
	dogshoot_count_max = 10, dogshoot_count2_max = 3,
	arrow = "grug_mobs:dungeon_fireball",
	arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.2, shoot_offset = 1.4,
	visual = "mesh", mesh = "grug_mobs_dungeon_master.b3d", glow = 2,
	textures = {{"grug_mobs_dungeon_master.png"},
		{"grug_mobs_dungeon_master2.png"}, {"grug_mobs_dungeon_master4.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -1, -0.5, 0.5, 1.6, 0.5},
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 19, stand_speed = 15,
		walk_start = 20, walk_end = 35, walk_speed = 15,
		run_start = 20, run_end = 35, run_speed = 40,
		punch_start = 36, punch_end = 48, punch_speed = 20,
		shoot_start = 36, shoot_end = 48, shoot_speed = 20,
	},
	drops = {
		{name = "grug_materials:emberglass_shard", chance = 2, min = 1, max = 2},
		{name = "grug_materials:rough_diamond", chance = 8, min = 1, max = 1},
	},
	water_damage = 1, lava_damage = 1, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:dungeon_master", master)
mobs:spawn({name = "grug_mobs:dungeon_master",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 3200, active_object_count = 2,
	min_height = -1000, max_height = -500})
