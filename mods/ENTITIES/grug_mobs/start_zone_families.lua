-- Round 8 package 3: the six start-zone identity families and their first
-- outward routes. Level, HP, damage, armor and XP stay owned by levels.lua.

local function ground_defaults(def)
	def.reach = def.reach or 3
	def.attack_type = def.attack_type or "dogfight"
	def.walk_velocity = def.walk_velocity or 1.5
	def.run_velocity = def.run_velocity or 4.6
	def.jump = def.jump ~= false
	def.jump_height = def.jump_height or 4
	def.stepheight = def.stepheight or 1.1
	def.fear_height = def.fear_height or 6
	if def.pathfinding == nil then def.pathfinding = 1 end
	def.water_damage = def.water_damage or 0
	def.lava_damage = def.lava_damage or 4
	def.light_damage = def.light_damage or 0
	return def
end

local function start_band(min_level)
	return function(pos)
		local zone = grug_zones.id_at(pos.x, pos.z)
		if zone == "elandor_hearthpine_vale" or
				zone == "elandor_dawnmere_fields" or
				zone == "elandor_silverleaf_glades" or
				zone == "kragmar_stillgrave_hollow" or
				zone == "kragmar_sunscar_flats" or
				zone == "kragmar_kapok_cradle" then
			return grug_zones.mob_level_at(pos) >= min_level
		end
		return true
	end
end

local fox = ground_defaults({
	description = "Fox", clock = "day", type = "monster",
	attack_players = true, group_attack = false, view_range = 12,
	_grug_spawn_check = start_band(4),
	visual = "mesh", mesh = "grug_mobs_fox.b3d",
	textures = {{"grug_mobs_fox.png"}},
	visual_size = {x = 10, y = 10},
	collisionbox = {-0.35, -0.01, -0.35, 0.35, 0.5, 0.35},
	makes_footstep_sound = true,
	animation = {
		stand_start = 1, stand_end = 39, stand_speed = 10,
		walk_start = 41, walk_end = 59, walk_speed = 25,
		run_start = 41, run_end = 59, run_speed = 40,
		punch_start = 41, punch_end = 59, punch_speed = 45,
	},
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:fang", chance = 3, min = 1, max = 1},
	},
})
grug_mobs.melee_rider(fox, function(self, target)
	local now = grug_core.mono_time()
	self.temp = self.temp or {}
	if (self.temp.grug_fox_retreat_until or 0) > now then return end
	local from = target:get_pos()
	local pos = self.object and self.object:get_pos()
	if not from or not pos then return end
	self.temp.grug_fox_retreat_until = now + 4
	local dx, dz = pos.x - from.x, pos.z - from.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length > 0 then
		self.object:set_velocity({x = dx * 6 / length, y = 1,
			z = dz * 6 / length})
	end
end)
grug_mobs.register_mob("grug_mobs:fox", fox)
mobs:spawn({
	name = "grug_mobs:fox",
	nodes = {"default:dirt_with_grass", "default:dirt_with_coniferous_litter",
		"grug_nodes:dirt_with_silver_litter"},
	interval = 20, chance = 1900, active_object_count = 3,
	min_height = 0, max_height = 600,
})

local ibex = ground_defaults({
	description = "Ibex", clock = "day", type = "animal",
	attack_players = false, attack_npcs = false, group_attack = false,
	view_range = 14, _grug_spawn_check = start_band(4),
	visual = "mesh", mesh = "grug_mobs_ibex.b3d",
	textures = {{"grug_mobs_ibex.png"}}, visual_size = {x = 1, y = 1},
	-- Bound the visible body and horns; keep the locomotion collision footprint.
	selectionbox = {-0.43, -0.02, -0.72, 0.43, 1.80, 0.97, rotate = true},
	collisionbox = {-0.4, -0.01, -0.4, 0.4, 0.5, 0.4},
	makes_footstep_sound = true,
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 25,
		stand1_start = 100, stand1_end = 200, stand1_speed = 25,
		walk_start = 200, walk_end = 300, walk_speed = 50,
		run_start = 200, run_end = 300, run_speed = 80,
		punch_start = 300, punch_end = 400, punch_speed = 60,
	},
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 2, max = 2},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
	},
})
grug_mobs.passive_prey(ibex)
grug_mobs.register_mob("grug_mobs:ibex", ibex)
mobs:spawn({
	name = "grug_mobs:ibex",
	nodes = {"default:dirt_with_coniferous_litter", "default:gravel",
		"default:snowblock"},
	interval = 20, chance = 1900, active_object_count = 3,
	min_height = 0, max_height = 600,
})

local function critter(description, mesh, texture, size, box, animation)
	return ground_defaults({
		description = description, clock = "day", type = "animal",
		passive = true, runaway = true, attack_players = false,
		_grug_tier = "critter", pathfinding = false, fear_height = 3,
		run_velocity = 3.4, view_range = 9,
		visual = "mesh", mesh = mesh, textures = {{texture}},
		visual_size = size, collisionbox = box, makes_footstep_sound = true,
		animation = animation,
		drops = {{name = "mobs:meat_raw", chance = 1, min = 1, max = 1}},
	})
end

local turkey = critter("Wild Turkey", "grug_mobs_wild_turkey.b3d",
	"grug_mobs_wild_turkey.png", {x = 10, y = 10},
	{-0.3, -0.01, -0.3, 0.3, 0.6, 0.3}, {
		stand_start = 1, stand_end = 1,
		walk_start = 10, walk_end = 30, walk_speed = 25,
		run_start = 40, run_end = 60, run_speed = 40,
	})
grug_mobs.register_mob("grug_mobs:wild_turkey", turkey)
mobs:spawn({name = "grug_mobs:wild_turkey",
	nodes = {"default:dirt_with_grass"}, interval = 20, chance = 2100,
	active_object_count = 2, min_height = 0, max_height = 600})

local runner = critter("Plains Runner", "grug_mobs_plains_runner.b3d",
	"grug_mobs_plains_runner.png", {x = 1, y = 1},
	{-0.4, -0.01, -0.3, 0.4, 0.8, 0.4}, {
		stand_start = 1, stand_end = 100, stand_speed = 25,
		walk_start = 100, walk_end = 200, walk_speed = 55,
		run_start = 100, run_end = 200, run_speed = 90,
	})
grug_mobs.register_mob("grug_mobs:plains_runner", runner)
mobs:spawn({name = "grug_mobs:plains_runner",
	nodes = {"default:dry_dirt_with_dry_grass"}, interval = 20, chance = 2100,
	active_object_count = 2, min_height = 0, max_height = 600})

local tapir = ground_defaults({
	description = "Tapir", clock = "day", type = "animal",
	attack_players = false, attack_npcs = false, view_range = 12,
	_grug_spawn_check = start_band(4),
	visual = "mesh", mesh = "grug_mobs_tapir.b3d",
	textures = {{"grug_mobs_tapir.png"}}, visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	makes_footstep_sound = true,
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 25,
		stand1_start = 100, stand1_end = 200, stand1_speed = 25,
		walk_start = 200, walk_end = 300, walk_speed = 50,
		run_start = 200, run_end = 300, run_speed = 80,
		punch_start = 300, punch_end = 400, punch_speed = 60,
	},
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 2, max = 2},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
	},
})
grug_mobs.passive_prey(tapir)
grug_mobs.register_mob("grug_mobs:tapir", tapir)
mobs:spawn({name = "grug_mobs:tapir",
	nodes = {"default:dirt_with_rainforest_litter",
		"grug_nodes:dirt_with_canopy_litter"}, interval = 20, chance = 1900,
	active_object_count = 3, min_height = 0, max_height = 600})

local rat = ground_defaults({
	description = "Giant Rat", clock = "night", type = "monster",
	attack_players = true, group_attack = true, view_range = 10,
	visual = "mesh", mesh = "grug_mobs_giant_rat.b3d",
	textures = {{"grug_mobs_giant_rat.png"}}, visual_size = {x = 1.6, y = 1.6},
	collisionbox = {-0.64, -0.01, -0.64, 0.64, 0.96, 0.64},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		walk_start = 100, walk_end = 200, walk_speed = 55,
		run_start = 100, run_end = 200, run_speed = 90,
		punch_start = 250, punch_end = 350, punch_speed = 70,
	},
	drops = {{name = "mobs:meat_raw", chance = 1, min = 1, max = 1}},
})
grug_mobs.camp_swarm(rat, {range = 12})
grug_mobs.register_mob("grug_mobs:giant_rat", rat)
mobs:spawn({name = "grug_mobs:giant_rat",
	nodes = {"default:dirt_with_grass", "default:dirt_with_coniferous_litter",
		"grug_nodes:dirt_with_silver_litter", "grug_nodes:blight_dirt",
		"default:dry_dirt_with_dry_grass", "default:dirt_with_rainforest_litter"},
	interval = 20, chance = 1600, active_object_count = 4,
	min_height = 0, max_height = 600})
mobs:spawn({name = "grug_mobs:giant_rat",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 1800, active_object_count = 4,
	min_height = -300, max_height = -40})

local function poison_family(description, mesh, texture, size, box, animation,
		spawn_check)
	local def = ground_defaults({
		description = description, clock = "night", type = "monster",
		attack_players = true, group_attack = false, view_range = 10,
		_grug_spawn_check = spawn_check,
		visual = "mesh", mesh = mesh, textures = {{texture}},
		visual_size = size, collisionbox = box, makes_footstep_sound = false,
		animation = animation,
		drops = {
			{name = "grug_mobs:scaled_hide", chance = 2, min = 1, max = 1},
			{name = "grug_mobs:venom_sac", chance = 3, min = 1, max = 1},
		},
	})
	grug_mobs.melee_rider(def, function(_, target)
		grug_mobs.poison_player(target, 3, 2, 1)
	end)
	return def
end

local scorpion = poison_family("Scorpion", "grug_mobs_scorpion.b3d",
	"grug_mobs_scorpion.png", {x = 1, y = 1},
	{-0.4, -0.01, -0.4, 0.4, 0.5, 0.4}, {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		walk_start = 100, walk_end = 200, walk_speed = 55,
		run_start = 100, run_end = 200, run_speed = 90,
		punch_start = 200, punch_end = 300, punch_speed = 70,
	}, start_band(4))
grug_mobs.register_mob("grug_mobs:scorpion", scorpion)
mobs:spawn({name = "grug_mobs:scorpion",
	nodes = {"default:dry_dirt_with_dry_grass", "grug_nodes:mesa_clay"},
	interval = 20, chance = 1800, active_object_count = 4,
	min_height = 0, max_height = 600})

local viper = poison_family("Viper", "grug_mobs_viper.b3d",
	"grug_mobs_viper.png", {x = 0.6, y = 0.6},
	{-0.3, -0.01, -0.3, 0.3, 0.8, 0.3}, {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		stand1_start = 100, stand1_end = 200, stand1_speed = 30,
		walk_start = 300, walk_end = 420, walk_speed = 60,
		run_start = 300, run_end = 420, run_speed = 90,
		punch_start = 200, punch_end = 300, punch_speed = 70,
	}, start_band(4))
grug_mobs.register_mob("grug_mobs:viper", viper)
mobs:spawn({name = "grug_mobs:viper",
	nodes = {"default:dirt_with_rainforest_litter"},
	interval = 20, chance = 1800, active_object_count = 4,
	min_height = 0, max_height = 600})
