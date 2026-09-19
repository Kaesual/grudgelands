-- Glowwing: hostile underground flier. A table-valued fly_in deliberately
-- excludes it from the surface flier near-ground nudge.

local glowwing = {
	description = "Glowwing", clock = "any", type = "monster",
	_grug_tier = "normal", _grug_spawn_domains = {"underground"},
	attack_type = "dogfight", attack_players = true, group_attack = true,
	reach = 2, fly = true, fly_in = {"air"}, physical = false,
	walk_velocity = 4, run_velocity = 6, jump = false, fear_height = 0,
	view_range = 12,
	visual = "mesh", mesh = "grug_mobs_glowwing.b3d", glow = 6,
	textures = {{"grug_mobs_glowwing.png^[colorize:#73e8ff:65"}},
	visual_size = {x = 1.5, y = 1.5},
	collisionbox = {-0.15, -0.01, -0.15, 0.15, 0.3, 0.15},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 100,
		walk_start = 100, walk_end = 200, walk_speed = 150,
		run_start = 100, run_end = 200, run_speed = 200,
		fly_start = 100, fly_end = 200, fly_speed = 200,
		punch_start = 100, punch_end = 200, punch_speed = 220,
		die_start = 200, die_end = 300, die_speed = 50, die_loop = false,
	},
	drops = {{name = "grug_mobs:venom_gland", chance = 5, min = 1, max = 1}},
	water_damage = 4, lava_damage = 4, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:glowwing", glowwing)
mobs:spawn({name = "grug_mobs:glowwing",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 2400, active_object_count = 3,
	min_height = -500, max_height = -300})
