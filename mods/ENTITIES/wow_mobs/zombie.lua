-- Zombie: Nacht-Mob der Startzonen. Zaeher und staerker als das
-- Wildschwein, verbrennt bei Tageslicht.

wow_mobs.register_mob("wow_mobs:zombie", {
	description = "Zombie",
	type = "monster",
	_wow_xp_reward = 35,

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
	mesh = "wow_mobs_zombie.b3d",
	textures = {{"wow_mobs_zombie.png"}},
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
		{name = "wow_mobs:zombie_flesh", chance = 1, min = 1, max = 2},
		{name = "default:steel_ingot", chance = 10, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- Verbrennt tagsueber an der Oberflaeche (klassisches Nacht-Mob-Gefuehl).
	light_damage = 2,
	light_damage_min = 14,
	light_damage_max = 15,
})

-- Nachts auf Wiese und Stein (Oberflaeche); Territoriums-Gating folgt WP2/WP6.
mobs:spawn({
	name = "wow_mobs:zombie",
	nodes = {"default:dirt_with_grass", "default:stone"},
	max_light = 7,
	day_toggle = false,
	interval = 30,
	chance = 6000,
	active_object_count = 2,
	min_height = 0,
	max_height = 300,
})
