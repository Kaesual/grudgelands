-- Ember Wisp: ranged deep-cave retint of the shipped Wisp. A table-valued
-- fly_in keeps the surface-only near-ground bias out of underground flight.

grug_mobs.register_simple_arrow("grug_mobs:ember_entity", {
	texture = "mobs_tnt_smoke.png^[colorize:#ff5a1e:170", velocity = 10,
	size = {x = 0.6, y = 0.6}, glow = 10, tail = true,
	tail_texture = "mobs_tnt_smoke.png^[colorize:#ff5a1e:170", lifetime = 5,
})

local wisp = {
	description = "Ember Wisp", clock = "any", type = "monster",
	_grug_tier = "normal", _grug_spawn_domains = {"underground"},
	attack_type = "dogshoot", attack_players = true, group_attack = false,
	reach = 2, fly = true, fly_in = {"air"}, physical = false,
	walk_velocity = 2.5, run_velocity = 4.6, jump = false, fear_height = 0,
	view_range = 16, dogshoot_switch = 1,
	dogshoot_count_max = 8, dogshoot_count2_max = 2,
	arrow = "grug_mobs:ember_entity", arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2, shoot_offset = 0.8,
	visual = "mesh", mesh = "grug_mobs_wisp.b3d", glow = 8,
	textures = {{"default_tool_steelsword.png",
		"grug_mobs_wisp.png^[colorize:#ff5a1e:140"}},
	visual_size = {x = 1.25, y = 1.25},
	collisionbox = {-0.2, 0.2, -0.2, 0.2, 1, 0.2},
	makes_footstep_sound = false,
	animation = {
		stand_start = 40, stand_end = 80, stand_speed = 25,
		walk_start = 1, walk_end = 40, walk_speed = 25,
		run_start = 1, run_end = 40, run_speed = 50,
		fly_start = 1, fly_end = 40, fly_speed = 50,
		shoot_start = 1, shoot_end = 40, shoot_speed = 60,
		punch_start = 1, punch_end = 40, punch_speed = 60,
	},
	drops = {{name = "grug_materials:emberglass", chance = 4, min = 1, max = 1}},
	water_damage = 6, lava_damage = 0, fire_damage = 0, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:ember_wisp", wisp)
mobs:spawn({name = "grug_mobs:ember_wisp",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 2400, active_object_count = 3,
	min_height = -31000, max_height = -700})
