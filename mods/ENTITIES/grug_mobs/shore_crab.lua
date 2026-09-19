-- Shore Crab and its high-level elite beach variant, the Reef Lurker.

local function beach_band(low, high)
	return function(pos)
		local level = grug_zones.mob_level_at(pos)
		return level and level >= low and level <= high or false
	end
end

local function crab_def(description, tier, spawn_check, drop_scale)
	local def = {
		description = description, clock = "any", type = "animal",
		_grug_tier = tier, _grug_spawn_check = spawn_check,
		attack_type = "dogfight", group_attack = false, reach = 3,
		pathfinding = 1, walk_velocity = 1.5, run_velocity = 3.4,
		jump = false, jump_height = 0, stepheight = 1, fear_height = 2,
		view_range = 8, floats = 0,
		visual = "mesh", mesh = "grug_mobs_shore_crab.b3d",
		textures = {{"grug_mobs_shore_crab.png"}},
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.4, -0.01, -0.4, 0.4, 0.4, 0.4},
		makes_footstep_sound = false,
		animation = {
			stand_start = 1, stand_end = 100, stand_speed = 50,
			walk_start = 100, walk_end = 200, walk_speed = 75,
			run_start = 100, run_end = 200, run_speed = 100,
			punch_start = 200, punch_end = 400, punch_speed = 100,
			die_start = 200, die_end = 300, die_speed = 50, die_loop = false,
		},
		drops = {
			{name = "mobs:meat_raw", chance = 1, min = drop_scale,
				max = drop_scale * 2},
			{name = "grug_mobs:scaled_hide", chance = 2, min = drop_scale,
				max = drop_scale},
		},
		water_damage = 0, lava_damage = 4, light_damage = 0,
	}
	grug_mobs.passive_prey(def)
	return def
end

grug_mobs.register_mob("grug_mobs:shore_crab",
	crab_def("Shore Crab", "normal", beach_band(1, 5), 1))
grug_mobs.register_mob("grug_mobs:reef_lurker",
	crab_def("Reef Lurker", "elite", beach_band(45, 60), 3))

mobs:spawn({name = "grug_mobs:shore_crab", nodes = {"default:sand"},
	interval = 20, chance = 1650, active_object_count = 3,
	min_height = 0, max_height = 20})
mobs:spawn({name = "grug_mobs:reef_lurker", nodes = {"default:sand"},
	interval = 30, chance = 6000, active_object_count = 1,
	min_height = 0, max_height = 20})
