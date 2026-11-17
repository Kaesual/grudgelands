-- Speargrass Tiger: daytime savanna stalker.

local tiger = {
	description = "Speargrass Tiger", clock = "day", type = "monster",
	_grug_voice = "feline",
	_grug_tier = "normal", attack_type = "dogfight", attack_players = true,
	group_attack = false, reach = 3, pathfinding = 1,
	walk_velocity = 2, run_velocity = 4.6, jump = true, jump_height = 6,
	stepheight = 2, fear_height = 6, view_range = 14,
	visual = "mesh", mesh = "grug_mobs_speargrass_tiger.b3d",
	textures = {{"grug_mobs_speargrass_tiger.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	-- Rotated selection box = measured mesh bounds (Round 28, tools/r28_a3).
	selectionbox = {-0.5, -0.05, -1.7, 0.5, 1.4, 1.05, rotate = true},
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 100, stand_speed = 50,
		walk_start = 100, walk_end = 200, walk_speed = 100,
		run_start = 100, run_end = 200, run_speed = 160,
		punch_start = 200, punch_end = 300, punch_speed = 120,
		die_start = 200, die_end = 300, die_speed = 50, die_loop = false,
	},
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:heavy_leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:sleek_pelt", chance = 4, min = 1, max = 1},
	},
	water_damage = 0, lava_damage = 4, light_damage = 0,
}

grug_mobs.stalker(tiger, {})
grug_mobs.register_mob("grug_mobs:speargrass_tiger", tiger)
