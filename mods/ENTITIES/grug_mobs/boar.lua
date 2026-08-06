-- Boar: aggressive daytime mob of the safe core and inner ring (WoW
-- memory: the first quest mobs). Weak, but combative.

grug_mobs.register_mob("grug_mobs:boar", {
	description = "Boar",
	type = "monster",
	_grug_spawn_zones = {"core", "inner"},
	-- HP/damage/XP and armor come from the level engine (levels.lua):
	-- core/inner ring means level 1-10, i.e. 20-65 HP, 2-6 damage.

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	-- Aggressive-mob speed (combat_stats.md §3): faster than the player's
	-- 4.0, so running away is a decision, not a reflex.
	run_velocity = 4.4,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 4,
	view_range = 10,

	visual = "mesh",
	mesh = "grug_mobs_boar.b3d",
	textures = {
		{"grug_mobs_boar.png^[multiply:#9a7a5a", "grug_mobs_blank.png"},
	},
	visual_size = {x = 2.5, y = 2.5},
	collisionbox = {-0.45, -0.01, -0.45, 0.45, 0.86, 0.45},
	makes_footstep_sound = true,

	animation = {
		stand_start = 0, stand_end = 0,
		walk_start = 0, walk_end = 40, walk_speed = 60,
		run_start = 0, run_end = 40, run_speed = 90,
		punch_start = 0, punch_end = 40, punch_speed = 90,
	},

	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:boar_tusk", chance = 2, min = 1, max = 2},
		{name = "mobs:leather", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
})

-- Spawns on the signature top nodes of all six SETTLED biomes (biomes.lua,
-- docs/design/biomes_mobs.md §4: the whitelist IS the biome gating), so
-- every low-level area of both continents has day mobs. The zone gating
-- above keeps boars in the core and inner ring, out of the higher-level
-- outer ring and coasts.
mobs:spawn({
	name = "grug_mobs:boar",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"grug_nodes:blight_dirt", -- grug_blight
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
	},
	min_light = 10,
	interval = 30,
	chance = 2000,
	active_object_count = 4,
	min_height = 0,
	max_height = 300,
})
