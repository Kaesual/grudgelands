-- Round 8 zero-asset families. Every visual is a scale or runtime texture
-- modifier over media already listed in LICENSE-media.md; no new media file
-- enters the game in this package.

local function common_ground(def)
	def.pathfinding = 1
	def.jump = true
	def.jump_height = 4
	def.stepheight = 1.1
	def.fear_height = 6
	def.water_damage = 0
	def.lava_damage = 4
	def.light_damage = 0
	return def
end

-- Poacher: the camp archer turned into a roaming night family. The visual
-- composer is deliberately removed so the dark runtime skin remains visible.
local poacher = grug_mobs.bandit_def("Poacher")
poacher.clock = "night"
poacher._grug_leash_range = nil
poacher._grug_visual = nil
poacher._grug_spawn_check = function(pos)
	if grug_zones.id_at(pos.x, pos.z) == "elandor_silverleaf_glades" then
		return grug_zones.mob_level_at(pos) >= 7
	end
	return true
end
poacher.textures = {{"grug_mobs_bandit_2.png^[multiply:#6b5948"}}
poacher.attack_type = "dogshoot"
poacher.arrow = "grug_mobs:arrow_entity"
poacher.arrow_override = grug_mobs.stamp_arrow_damage
poacher.shoot_interval = 2.5
poacher.shoot_offset = 1.3
poacher.dogshoot_switch = 1
poacher.dogshoot_count_max = 10
poacher.dogshoot_count2_max = 3
poacher.walk_velocity = 4.0
poacher.run_velocity = 4.0
poacher.view_range = 16
local poacher_drops = poacher.drops
poacher.drops = function(pos)
	local drops = poacher_drops(pos)
	drops[#drops + 1] = {
		name = "grug_mobs:arrow", chance = 3, min = 1, max = 1,
	}
	return drops
end
grug_mobs.register_mob("grug_mobs:poacher", poacher)

mobs:spawn({
	name = "grug_mobs:poacher",
	nodes = {
		"default:dirt_with_grass",
		"grug_nodes:dirt_with_forest_litter",
		"grug_nodes:dirt_with_silver_litter",
	},
	interval = 20, chance = 2200, active_object_count = 3,
	min_height = 0, max_height = 200,
})

-- Frost Stray: Skeleton Archer numbers and projectile, cold-blue bones.
local frost_stray = common_ground({
	description = "Frost Stray",
	clock = "night",
	type = "monster",
	reach = 3,
	attack_type = "dogshoot",
	attack_players = true,
	group_attack = true,
	arrow = "grug_mobs:arrow_entity",
	arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5,
	shoot_offset = 1.5,
	dogshoot_switch = 1,
	dogshoot_count_max = 10,
	dogshoot_count2_max = 3,
	walk_velocity = 4.0,
	run_velocity = 4.0,
	view_range = 16,
	visual = "mesh",
	mesh = "grug_mobs_skeleton.b3d",
	textures = {{
		"grug_mobs_blank.png",
		"grug_mobs_skeleton.png^[multiply:#a8d8ef",
		"grug_mobs_blank.png",
	}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.98, 0.3},
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 40, stand_speed = 15,
		walk_start = 40, walk_end = 60, walk_speed = 15,
		run_start = 40, run_end = 60, run_speed = 30,
		shoot_start = 70, shoot_end = 90, shoot_speed = 15,
		punch_start = 70, punch_end = 90, punch_speed = 15,
	},
	drops = {
		{name = "grug_mobs:bone", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:arrow", chance = 3, min = 1, max = 1},
	},
})
grug_mobs.register_mob("grug_mobs:frost_stray", frost_stray)

mobs:spawn({
	name = "grug_mobs:frost_stray",
	nodes = {"default:gravel", "default:snowblock"},
	interval = 20, chance = 2400, active_object_count = 3,
	min_height = 0, max_height = 300,
})

-- Sun-Dried Husk: the desert Zombie; it keeps the relentless chase but does
-- not burn in sunlight because its family exists only in the night cast.
local husk = common_ground({
	description = "Sun-Dried Husk",
	clock = "night",
	type = "monster",
	_grug_min_level = 3,
	_grug_no_leash = true,
	_grug_spawn_check = function(pos)
		if grug_zones.id_at(pos.x, pos.z) == "kragmar_sunscar_flats" then
			return grug_zones.mob_level_at(pos) >= 7
		end
		return true
	end,
	reach = 3,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	walk_velocity = 1,
	run_velocity = 4.6,
	view_range = 14,
	visual = "mesh",
	mesh = "grug_mobs_zombie.b3d",
	textures = {{
		"grug_mobs_blank.png",
		"grug_mobs_zombie.png^[multiply:#c99b55",
	}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.89, 0.3},
	makes_footstep_sound = true,
	animation = {
		stand_start = 40, stand_end = 49, stand_speed = 2,
		walk_start = 0, walk_end = 39, walk_speed = 25,
		run_start = 0, run_end = 39, run_speed = 50,
		punch_start = 50, punch_end = 59, punch_speed = 20,
	},
	drops = {
		{name = "grug_mobs:zombie_flesh", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
		{name = "grug_materials:iron_bar", chance = 10, min = 1, max = 1},
	},
})
grug_mobs.register_mob("grug_mobs:sun_dried_husk", husk)

mobs:spawn({
	name = "grug_mobs:sun_dried_husk",
	nodes = {"default:dry_dirt_with_dry_grass", "grug_nodes:mesa_clay"},
	interval = 20, chance = 2000, active_object_count = 4,
	min_height = 0, max_height = 200,
})

-- Song Bird: the gull chassis in a bright forest tint, fixed critter tier.
local song_bird = {
	description = "Song Bird",
	clock = "day",
	type = "animal",
	passive = true,
	runaway = true,
	_grug_tier = "critter",
	fly = true,
	fly_in = "air",
	jump = false,
	fear_height = 0,
	walk_velocity = 1.5,
	run_velocity = 3.4,
	stepheight = 1.1,
	view_range = 8,
	visual = "mesh",
	mesh = "grug_mobs_gull.b3d",
	textures = {{"grug_mobs_gull.png^[multiply:#78aee8"}},
	visual_size = {x = 8, y = 8},
	collisionbox = {-0.16, 0, -0.16, 0.16, 0.32, 0.16},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		walk_start = 110, walk_end = 130, walk_speed = 40,
		run_start = 140, run_end = 160, run_speed = 50,
		fly_start = 140, fly_end = 160, fly_speed = 40,
	},
	drops = {{name = "mobs:meat_raw", chance = 1, min = 1, max = 1}},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}
grug_mobs.register_mob("grug_mobs:song_bird", song_bird)

mobs:spawn({
	name = "grug_mobs:song_bird",
	nodes = {"grug_nodes:dirt_with_silver_litter"},
	interval = 20, chance = 2200, active_object_count = 2,
	min_height = 0, max_height = 200,
})

-- Spiderling: half-size cave spider with a weaker web.
local spiderling = common_ground({
	description = "Spiderling",
	clock = "any",
	type = "monster",
	_grug_spawn_domains = {"underground"},
	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	walk_velocity = 1,
	run_velocity = 4.6,
	view_range = 10,
	visual = "mesh",
	mesh = "grug_mobs_spider.b3d",
	textures = {{"grug_mobs_spider.png^[multiply:#786b63"}},
	visual_size = {x = 0.75, y = 0.75},
	collisionbox = {-0.525, -0.375, -0.525, 0.525, 0, 0.525},
	makes_footstep_sound = false,
	animation = {
		speed_normal = 15,
		stand_start = 0, stand_end = 0,
		walk_start = 1, walk_end = 21,
		run_start = 1, run_end = 21, run_speed = 30,
		punch_start = 25, punch_end = 45, punch_speed = 30,
	},
	drops = {
		{name = "grug_mobs:spider_silk", chance = 2, min = 1, max = 1},
	},
})
grug_mobs.melee_rider(spiderling, function(_, target)
	grug_mobs.slow_player(target, 2, 0.8)
end)
grug_mobs.register_mob("grug_mobs:spiderling", spiderling)

mobs:spawn({
	name = "grug_mobs:spiderling",
	nodes = {"default:stone", "group:grug_stratum"},
	max_light = 5,
	interval = 20, chance = 2400, active_object_count = 3,
	min_height = -100, max_height = -40,
})

-- Blood Bat: hostile cave-bat tint and swarm dive.
local blood_bat = {
	description = "Blood Bat",
	clock = "any",
	type = "monster",
	_grug_spawn_domains = {"underground"},
	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	fly = true,
	fly_in = "air",
	jump = false,
	fear_height = 0,
	walk_velocity = 1.5,
	run_velocity = 4.6,
	stepheight = 1.1,
	view_range = 12,
	visual = "mesh",
	mesh = "grug_mobs_cave_bat.b3d",
	textures = {{"grug_mobs_cave_bat.png^[multiply:#8f2635"}},
	visual_size = {x = 1.25, y = 1.25},
	collisionbox = {-0.31, -0.01, -0.31, 0.31, 1.11, 0.31},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 40, stand_speed = 80,
		walk_start = 1, walk_end = 40, walk_speed = 80,
		run_start = 1, run_end = 40, run_speed = 80,
		fly_start = 1, fly_end = 40, fly_speed = 80,
		punch_start = 1, punch_end = 40, punch_speed = 100,
	},
	drops = {{name = "mobs:meat_raw", chance = 1, min = 1, max = 1}},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}
grug_mobs.register_mob("grug_mobs:blood_bat", blood_bat)

mobs:spawn({
	name = "grug_mobs:blood_bat",
	nodes = {"default:stone", "group:grug_stratum"},
	max_light = 5,
	interval = 20, chance = 2200, active_object_count = 4,
	min_height = -300, max_height = -101,
})

-- Stone Mite: deep hostile crawler swarm.
local stone_mite = common_ground({
	description = "Stone Mite",
	clock = "any",
	type = "monster",
	_grug_spawn_domains = {"underground"},
	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	walk_velocity = 1.5,
	run_velocity = 4.6,
	view_range = 10,
	visual = "mesh",
	mesh = "grug_mobs_cave_crawler.b3d",
	textures = {{"grug_mobs_cave_crawler.png^[multiply:#77736b"}},
	visual_size = {x = 4, y = 4},
	collisionbox = {-0.53, -0.01, -0.53, 0.53, 0.59, 0.53},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 20, stand_speed = 15,
		walk_start = 1, walk_end = 20, walk_speed = 25,
		run_start = 1, run_end = 20, run_speed = 50,
		punch_start = 1, punch_end = 20, punch_speed = 60,
	},
	drops = {{name = "grug_mobs:stone_core", chance = 8, min = 1, max = 1}},
})
grug_mobs.register_mob("grug_mobs:stone_mite", stone_mite)

mobs:spawn({
	name = "grug_mobs:stone_mite",
	nodes = {"group:grug_stratum"},
	max_light = 5,
	interval = 20, chance = 2000, active_object_count = 5,
	min_height = -31000, max_height = -700,
})
