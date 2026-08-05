-- Boar: aggressive daytime mob of the starter zones (WoW memory: the
-- first quest mobs). Weak, but combative.

wob_mobs.register_mob("wob_mobs:boar", {
	description = "Boar",
	type = "monster",
	_wob_xp_reward = 15,

	hp_min = 8,
	hp_max = 12,
	armor = 100,
	damage = 2,
	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	run_velocity = 3.4,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 4,
	view_range = 10,

	visual = "mesh",
	mesh = "wob_mobs_boar.b3d",
	textures = {
		{"wob_mobs_boar.png^[multiply:#9a7a5a", "wob_mobs_blank.png"},
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
		{name = "wob_mobs:boar_tusk", chance = 2, min = 1, max = 2},
		{name = "mobs:leather", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
})

-- Spawns anywhere on grass for now; territory/tier gating comes with
-- WP2/WP6 via mobs:spawn_abm_check.
mobs:spawn({
	name = "wob_mobs:boar",
	nodes = {"default:dirt_with_grass"},
	min_light = 10,
	interval = 30,
	chance = 6000,
	active_object_count = 2,
	min_height = 0,
	max_height = 300,
})
