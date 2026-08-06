-- Zombie: night mob of the starter zones. Tougher and stronger than the
-- boar, burns in daylight.

grug_mobs.register_mob("grug_mobs:zombie", {
	description = "Zombie",
	type = "monster",
	_grug_xp_reward = 35,
	_grug_spawn_zones = {"borderland", "starter", "midlands"},
	-- Undead race passive (world.md §7): ignored at night unless provoked.
	_grug_night_truce_perk = "zombie_night_truce",

	hp_min = 16,
	hp_max = 22,
	armor = 90,
	damage = 4,
	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	run_velocity = 2.6,
	jump = true,
	stepheight = 1.1,
	fear_height = 4,
	view_range = 14,

	visual = "mesh",
	mesh = "grug_mobs_zombie.b3d",
	textures = {{"grug_mobs_zombie.png"}},
	visual_size = {x = 3, y = 3},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.89, 0.3},
	makes_footstep_sound = true,

	animation = {
		stand_start = 40, stand_end = 49, stand_speed = 2,
		walk_start = 0, walk_end = 39, walk_speed = 25,
		run_start = 0, run_end = 39, run_speed = 50,
		punch_start = 50, punch_end = 59, punch_speed = 20,
	},

	drops = {
		{name = "grug_mobs:zombie_flesh", chance = 1, min = 1, max = 2},
		{name = "default:steel_ingot", chance = 10, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- Burns on the surface during the day (classic night-mob feel).
	light_damage = 2,
	light_damage_min = 14,
	light_damage_max = 15,
})

-- At night on every race-region surface plus exposed stone (whitelist
-- matches biomes.lua — see the boar note); zone-gated like the boar.
mobs:spawn({
	name = "grug_mobs:zombie",
	nodes = {
		"default:dirt_with_grass",
		"default:dirt_with_coniferous_litter",
		"default:dirt_with_rainforest_litter",
		"default:dry_dirt_with_dry_grass",
		"default:dirt",
		"default:stone",
	},
	max_light = 7,
	day_toggle = false,
	interval = 30,
	chance = 3000,
	active_object_count = 3,
	min_height = 0,
	max_height = 300,
})
