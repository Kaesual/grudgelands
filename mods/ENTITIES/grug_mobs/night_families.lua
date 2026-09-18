-- Round 8 package 4: distinct level 11+ night casts. Level-derived combat
-- stats remain exclusively owned by levels.lua.

local function ground(def)
	def.type = "monster"
	def.clock = "night"
	def.reach = def.reach or 3
	def.attack_players = true
	def.pathfinding = 1
	def.walk_velocity = def.walk_velocity or 1.5
	def.run_velocity = def.run_velocity or 4.6
	def.jump = def.jump ~= false
	def.jump_height = def.jump_height or 4
	def.stepheight = def.stepheight or 1.1
	def.fear_height = def.fear_height or 6
	def.water_damage = def.water_damage or 0
	def.lava_damage = def.lava_damage or 4
	def.light_damage = def.light_damage or 0
	return def
end

local goblin_animation = {
	stand_start = 1, stand_end = 79, stand_speed = 30,
	walk_start = 168, walk_end = 187, walk_speed = 40,
	run_start = 168, run_end = 187, run_speed = 60,
	punch_start = 200, punch_end = 219, punch_speed = 60,
	-- The goblin mesh has no separate shot clip; its real attack range is
	-- explicitly reused so Slinger projectiles never appear from a static pose.
	shoot_start = 200, shoot_end = 219, shoot_speed = 60,
}

local function goblin_def(description, texture, ranged)
	local def = ground({
		description = description,
		attack_type = ranged and "dogshoot" or "dogfight",
		group_attack = true, _grug_no_leash = true,
		view_range = ranged and 16 or 12,
		visual = "mesh", mesh = "grug_mobs_goblin.b3d",
		textures = {{texture}}, visual_size = {x = 1, y = 1},
		collisionbox = {-0.25, -0.01, -0.25, 0.25, 0.9, 0.25},
		makes_footstep_sound = true, animation = goblin_animation,
		drops = {
			{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
			{name = ranged and "grug_mobs:arrow" or "grug_mobs:stolen_purse",
				chance = ranged and 3 or 8, min = 1, max = 1},
		},
	})
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

grug_mobs.register_mob("grug_mobs:goblin_raider",
	goblin_def("Goblin Raider", "grug_mobs_goblin_raider.png", false))
grug_mobs.register_mob("grug_mobs:goblin_slinger",
	goblin_def("Goblin Slinger", "grug_mobs_goblin_slinger.png", true))

local goblin_hound = ground({
	description = "Goblin Raider Hound", attack_type = "dogfight",
	group_attack = true, _grug_no_leash = true, view_range = 15,
	visual = "mesh", mesh = "grug_mobs_goblin_hound.b3d",
	textures = {{"grug_mobs_goblin_hound.png"}}, visual_size = {x = 1, y = 1},
	collisionbox = {-0.45, -0.01, -0.45, 0.45, 0.85, 0.45},
	makes_footstep_sound = true,
	animation = {
		stand_start = 1, stand_end = 60, stand_speed = 60,
		walk_start = 70, walk_end = 90, walk_speed = 60,
		run_start = 130, run_end = 140, run_speed = 60,
		punch_start = 130, punch_end = 140, punch_speed = 60,
	},
	drops = {{name = "mobs:meat_raw", chance = 1, min = 1, max = 1}},
})
grug_mobs.camp_swarm(goblin_hound, {range = 16})
grug_mobs.register_mob("grug_mobs:goblin_hound", goblin_hound)

for _, name in ipairs({"goblin_raider", "goblin_slinger", "goblin_hound"}) do
	mobs:spawn({
		name = "grug_mobs:" .. name,
		nodes = {"default:dirt_with_coniferous_litter", "default:gravel",
			"default:snowblock", "default:dry_dirt_with_dry_grass",
			"grug_nodes:mesa_clay"},
		interval = 20, chance = 2400,
		active_object_count = name == "goblin_raider" and 2 or 1,
		min_height = 0, max_height = 200,
	})
end

local snow_leopard = ground({
	description = "Snow Leopard", attack_type = "dogfight",
	group_attack = false, view_range = 12,
	visual = "mesh", mesh = "grug_mobs_panther.b3d",
	textures = {grug_mobs.atlas_textures("grug_mobs_snow_leopard.png", 17)},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	makes_footstep_sound = false,
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 50,
		walk_start = 100, walk_end = 200, walk_speed = 140,
		run_start = 100, run_end = 200, run_speed = 200,
		punch_start = 250, punch_end = 350, punch_speed = 140,
	},
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:sleek_pelt", chance = 4, min = 1, max = 1},
	},
})
grug_mobs.stalker(snow_leopard, {})
grug_mobs.register_mob("grug_mobs:snow_leopard", snow_leopard)
mobs:spawn({name = "grug_mobs:snow_leopard",
	nodes = {"default:gravel", "default:snowblock"},
	interval = 20, chance = 2100, active_object_count = 3,
	min_height = 0, max_height = 200})

local function open_node(pos)
	local node = core.get_node_or_nil(pos)
	if not node then return false end
	local def = core.registered_nodes[node.name]
	return not def or not def.walkable
end

local wisp = {
	description = "Wisp", clock = "night", type = "monster",
	attack_type = "dogfight", attack_players = true, group_attack = false,
	reach = 2, view_range = 14, fly = true, fly_in = "air", physical = false,
	walk_velocity = 2.5, run_velocity = 4.6, jump = false, fear_height = 0,
	visual = "mesh", mesh = "grug_mobs_wisp.b3d",
	textures = {{"default_tool_steelsword.png", "grug_mobs_wisp.png"}},
	visual_size = {x = 1.25, y = 1.25},
	collisionbox = {-0.2, 0.2, -0.2, 0.2, 1, 0.2},
	makes_footstep_sound = false,
	animation = {
		stand_start = 40, stand_end = 80, stand_speed = 25,
		walk_start = 1, walk_end = 40, walk_speed = 25,
		run_start = 1, run_end = 40, run_speed = 50,
		punch_start = 1, punch_end = 40, punch_speed = 60,
	},
	drops = {}, water_damage = 0, lava_damage = 4, light_damage = 0,
	do_custom = function(self, dtime)
		self.temp = self.temp or {}
		self.temp.grug_wisp_blink = (self.temp.grug_wisp_blink or 0) + dtime
		if self.temp.grug_wisp_blink < 4 or self.state ~= "attack" then return end
		local pos = self.object and self.object:get_pos()
		local target = self.attack and self.attack:get_pos()
		if not pos or not target then return end
		local dx, dy, dz = target.x - pos.x, target.y - pos.y, target.z - pos.z
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		if length <= 3 then return end
		local step = math.min(2.5, length - 2)
		local dest = {x = pos.x + dx * step / length,
			y = pos.y + dy * step / length, z = pos.z + dz * step / length}
		if open_node(dest) and open_node({x = dest.x, y = dest.y + 1, z = dest.z}) then
			self.object:set_pos(dest)
			self.temp.grug_wisp_blink = 0
		end
	end,
}
grug_mobs.register_mob("grug_mobs:wisp", wisp)
mobs:spawn({name = "grug_mobs:wisp",
	nodes = {"grug_nodes:mud", "grug_nodes:dirt_with_silver_litter",
		"grug_nodes:dirt_with_forest_litter", "grug_nodes:dirt_with_bone_litter",
		"default:dirt_with_rainforest_litter", "grug_nodes:dirt_with_canopy_litter"},
	interval = 20, chance = 2200, active_object_count = 3,
	min_height = 0, max_height = 200})

local function treant_def(description, tint)
	return ground({
		description = description, attack_type = "dogfight",
		group_attack = false, view_range = 12,
		visual = "mesh", mesh = "grug_mobs_treant.b3d",
		textures = {{"grug_mobs_treant.png^[multiply:" .. tint}},
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, -1, -0.3, 0.3, 0.75, 0.3},
		makes_footstep_sound = true,
		animation = {
			stand_start = 1, stand_end = 24, stand_speed = 15,
			walk_start = 25, walk_end = 47, walk_speed = 15,
			run_start = 48, run_end = 62, run_speed = 35,
			punch_start = 48, punch_end = 62, punch_speed = 35,
		},
		drops = {
			{name = "default:stick", chance = 1, min = 1, max = 2},
			{name = "default:apple", chance = 4, min = 1, max = 1},
		},
		do_custom = function(self, dtime)
			self.temp = self.temp or {}
			self.temp.grug_root_aura = (self.temp.grug_root_aura or 0) + dtime
			if self.temp.grug_root_aura < 1 then return end
			self.temp.grug_root_aura = self.temp.grug_root_aura - 1
			local pos = self.object and self.object:get_pos()
			if not pos then return end
			local objects = core.get_objects_inside_radius(pos, 3)
			for i = 1, #objects do
				if core.is_player(objects[i]) then
					grug_mobs.slow_player(objects[i], 1.2, 0.7)
				end
			end
		end,
	})
end

grug_mobs.register_mob("grug_mobs:ashen_treant",
	treant_def("Ashen Treant", "#6d5140"))
mobs:spawn({name = "grug_mobs:ashen_treant",
	nodes = {"grug_nodes:dirt_with_forest_litter"}, interval = 20, chance = 2600,
	active_object_count = 2, min_height = 0, max_height = 200})

grug_mobs.register_mob("grug_mobs:gravewood_treant",
	treant_def("Gravewood Treant", "#c2bba8"))
mobs:spawn({name = "grug_mobs:gravewood_treant",
	nodes = {"grug_nodes:dirt_with_bone_litter"}, interval = 20, chance = 2600,
	active_object_count = 2, min_height = 0, max_height = 200})
