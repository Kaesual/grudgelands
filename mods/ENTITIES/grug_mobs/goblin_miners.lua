-- Underground Goblin Miners. They reuse the cleared package-4 goblin port;
-- no new media or sound enters the game here.

local animation = {
	stand_start = 1, stand_end = 79, stand_speed = 30,
	walk_start = 168, walk_end = 187, walk_speed = 40,
	run_start = 168, run_end = 187, run_speed = 60,
	punch_start = 200, punch_end = 219, punch_speed = 60,
	shoot_start = 200, shoot_end = 219, shoot_speed = 60,
}

local function miner_def(description, texture, ranged)
	local def = {
		description = description, clock = "any", type = "monster",
		_grug_tier = "normal", _grug_spawn_domains = {"underground"},
		attack_type = ranged and "dogshoot" or "dogfight",
		attack_players = true, group_attack = true,
		reach = 3, pathfinding = 1, walk_velocity = 1.5,
		run_velocity = 4.6, jump = true, jump_height = 4,
		stepheight = 1.1, fear_height = 6,
		view_range = ranged and 16 or 12,
		visual = "mesh", mesh = "grug_mobs_goblin.b3d",
		textures = {{texture}}, visual_size = {x = 1, y = 1},
		collisionbox = {-0.25, -0.01, -0.25, 0.25, 0.9, 0.25},
		makes_footstep_sound = true, animation = animation,
		drops = {
			{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
			{name = ranged and "grug_mobs:arrow" or "grug_mobs:stolen_purse",
				chance = ranged and 3 or 8, min = 1, max = 1},
		},
		water_damage = 0, lava_damage = 4, light_damage = 0,
	}
	if ranged then
		def.arrow = "grug_mobs:rock_entity"
		def.arrow_override = grug_mobs.stamp_arrow_damage
		def.shoot_interval = 2.5
		def.shoot_offset = 1
		def.dogshoot_switch = 1
		def.dogshoot_count_max = 8
		def.dogshoot_count2_max = 2
	end
	grug_mobs.camp_swarm(def, {range = 16})
	return def
end

grug_mobs.register_mob("grug_mobs:goblin_miner",
	miner_def("Goblin Miner", "grug_mobs_goblin_raider.png", false))
grug_mobs.register_mob("grug_mobs:goblin_miner_slinger",
	miner_def("Goblin Miner Slinger", "grug_mobs_goblin_slinger.png", true))

for _, row in ipairs({
	{name = "goblin_miner", chance = 2200, aoc = 3},
	{name = "goblin_miner_slinger", chance = 2600, aoc = 2},
}) do
	mobs:spawn({
		name = "grug_mobs:" .. row.name,
		nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
		interval = 20, chance = row.chance, active_object_count = row.aoc,
		min_height = -300, max_height = -100,
	})
end
