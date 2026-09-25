-- Shore Crab and its high-level elite beach variant, the Reef Lurker.
--
-- Both live on sandy shore near water (Round 22 D36): the host is dry
-- `default:sand` at y 0..20 with water within NEAR_WATER nodes, so the
-- coast's wide sand band and inland sand stay crab-free. The level split is
-- spawn_policy.lua's: the Shore Crab below level 45, the Reef Lurker 45-60,
-- so every sandy sea shore carries one of the pair.

local NEAR_WATER = 6

local function near_water(pos)
	return core.find_node_near(pos, NEAR_WATER, "group:water") ~= nil
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
	crab_def("Shore Crab", "normal", near_water, 1))
grug_mobs.register_mob("grug_mobs:reef_lurker",
	crab_def("Reef Lurker", "elite", near_water, 3))

-- The near-water strip is about a quarter of the coast's sand (measured), so
-- both chances are a quarter of their former all-sand values to keep the
-- attempt rate.
mobs:spawn({name = "grug_mobs:shore_crab", nodes = {"default:sand"},
	interval = 20, chance = 400, active_object_count = 3,
	min_height = 0, max_height = 20})
mobs:spawn({name = "grug_mobs:reef_lurker", nodes = {"default:sand"},
	interval = 30, chance = 1500, active_object_count = 1,
	min_height = 0, max_height = 20})
