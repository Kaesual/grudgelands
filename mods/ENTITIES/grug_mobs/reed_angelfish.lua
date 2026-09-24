-- One low-density freshwater critter. The water-class authority prevents
-- player-built pools and sea water from becoming spawn habitat; the physical
-- checks additionally require a natural sand bed and two source-water nodes.

local function in_natural_freshwater(pos)
	if grug_zones.water_class_at(pos.x, pos.z) ~= "planned_water" then return false end
	if core.get_node(pos).name ~= "default:water_source" then return false end
	return core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name ==
		"default:water_source"
end

grug_mobs.register_mob("grug_mobs:reed_angelfish", {
	description = "Reed Angelfish",
	clock = "any",
	type = "animal",
	passive = true,
	runaway = false,
	_grug_tier = "critter",
	_grug_xp_reward = 0,
	_grug_no_quality_loot = true,
	_grug_spawn_check = in_natural_freshwater,

	fly = true,
	fly_in = "default:water_source",
	floats = true,
	jump = false,
	fear_height = 0,
	walk_velocity = 1.1,
	run_velocity = 1.5,
	view_range = 5,

	visual = "mesh",
	mesh = "grug_mobs_reed_angelfish.b3d",
	textures = {{"grug_mobs_reed_angelfish.png"}},
	visual_size = {x = 10, y = 10},
	collisionbox = {-0.15, -0.15, -0.15, 0.15, 0.15, 0.15},
	selectionbox = {-0.22, -0.2, -0.22, 0.22, 0.25, 0.22},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 20, stand_speed = 20,
		walk_start = 1, walk_end = 20, walk_speed = 20,
		run_start = 1, run_end = 20, run_speed = 28,
	},

	drops = {},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
})

mobs:spawn({
	name = "grug_mobs:reed_angelfish",
	nodes = {"default:water_source"},
	neighbors = {"default:sand"},
	interval = 30,
	chance = 4000,
	active_object_count = 2,
	min_height = -30,
	max_height = 80,
})
