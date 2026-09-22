-- Bog Witch. The pinned witch mesh is intentionally not used: its keyed
-- range omits the advertised shoot/death clips. This retint uses the shipped
-- skeleton humanoid, whose real keyed ranges include shoot 70..90 and die
-- 160..170; the third material slot visibly carries the hex bottle.

local function hex_hit(self, object)
	local damage = self._grug_damage or grug_mobs.scale_attack_damage(1)
	object:punch(self.object, 1.0, {
		full_punch_interval = 1.0, damage_groups = {fleshy = damage},
	}, nil)
	if core.is_player(object) then
		if math.random(2) == 1 then
			grug_mobs.poison_player(object, 2, 2, 1)
		else
			grug_mobs.slow_player(object, 4, 0.7)
		end
	end
	local pos = object:get_pos()
	if pos then
		core.add_particlespawner({
			amount = 16, time = 0.25,
			pos = {min = vector.offset(pos, -0.4, 0, -0.4),
				max = vector.offset(pos, 0.4, 1.4, 0.4)},
			exptime = {min = 0.2, max = 0.6}, size = {min = 1, max = 2.5},
			texture = "default_item_smoke.png^[multiply:#7b2fa3", glow = 5,
		})
	end
end

grug_mobs.register_homing_arrow("grug_mobs:hex_bottle", {
	visual = "sprite", visual_size = {x = 0.5, y = 0.5},
	textures = {"vessels_glass_bottle.png^[colorize:#7b2fa3:120"},
	velocity = 8, glow = 4, lifetime = 5,
	hit_player = hex_hit, hit_mob = hex_hit,
	hit_node = function(self, pos, node) end,
})

local witch = {
	description = "Bog Witch", clock = "night", type = "monster",
	_grug_tier = "normal", attack_type = "dogshoot", attack_players = true,
	group_attack = false, reach = 3, pathfinding = 1,
	walk_velocity = 1.5, run_velocity = 4.0, jump = true, jump_height = 4,
	stepheight = 1.1, fear_height = 6, view_range = 16,
	dogshoot_switch = 1, dogshoot_count_max = 8, dogshoot_count2_max = 2,
	arrow = "grug_mobs:hex_bottle", arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5, shoot_offset = 1.5,
	visual = "mesh", mesh = "grug_mobs_skeleton.b3d",
	textures = {{"grug_mobs_blank.png",
		"grug_mobs_skeleton.png^[colorize:#5f8b4c:110",
		"vessels_glass_bottle.png^[colorize:#7b2fa3:120"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.98, 0.3},
	makes_footstep_sound = true,
	animation = {
		stand_start = 1, stand_end = 40, stand_speed = 15,
		walk_start = 40, walk_end = 60, walk_speed = 15,
		run_start = 40, run_end = 60, run_speed = 30,
		shoot_start = 70, shoot_end = 90, shoot_speed = 20,
		punch_start = 70, punch_end = 90, punch_speed = 20,
		die_start = 160, die_end = 170, die_speed = 15, die_loop = false,
	},
	drops = {
		{name = "grug_mobs:venom_sac", chance = 3, min = 1, max = 1},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 2},
	},
	water_damage = 0, lava_damage = 4, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:bog_witch", witch)
mobs:spawn({name = "grug_mobs:bog_witch",
	nodes = {"grug_nodes:mud", "grug_nodes:dirt_with_bone_litter",
		"default:dirt_with_rainforest_litter", "grug_nodes:dirt_with_canopy_litter"},
	interval = 20, chance = 2400, active_object_count = 3,
	min_height = 0, max_height = 300})
