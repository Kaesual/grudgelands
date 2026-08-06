-- Zombie: night mob of the safe core, inner ring and war coast. Tougher
-- and stronger than the boar, burns in daylight.

grug_mobs.register_mob("grug_mobs:zombie", {
	description = "Zombie",
	type = "monster",
	_grug_spawn_zones = {"core", "inner", "war_coast"},
	-- HP/damage/XP and armor come from the level engine (levels.lua); the
	-- floor keeps the zombie above the boar even in the safe core.
	_grug_min_level = 3,
	-- Undead race passive (world.md §7): ignored at night unless provoked.
	_grug_night_truce_perk = "zombie_night_truce",
	-- Behavior verb (combat_stats.md §3): "zombies never leash" — once
	-- pulled it follows forever, never resets its threat and never heals up.
	-- Running away does not work; you have to lose it or kill it.
	_grug_no_leash = true,

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	-- Aggressive-mob speed (combat_stats.md §3), a notch under the boar's
	-- 4.4 but still above the player's 4.0.
	run_velocity = 4.2,
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

-- At night on the six settled biome tops (whitelist matches biomes.lua —
-- see the boar note); zone-gated like the boar. Bare stone is gone from the
-- list: no land biome has a stone surface any more.
mobs:spawn({
	name = "grug_mobs:zombie",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"grug_nodes:blight_dirt", -- grug_blight
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
	},
	max_light = 7,
	day_toggle = false,
	interval = 30,
	chance = 3000,
	active_object_count = 3,
	min_height = 0,
	max_height = 300,
})
