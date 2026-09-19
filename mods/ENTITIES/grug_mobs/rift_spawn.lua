-- Rift Spawn: two-second visual fuse, entity damage only. The custom burst is
-- terminal because mobs_redo promotes a zero node radius near water or inside
-- protection and its fallback boom would otherwise punch nearby objects again.

local RIFT_RADIUS = 3.5

local function reset_fuse(self)
	self.v_start = false
	self.timer = 0
	self.blinktimer = 0
	self.blinkstatus = false
	self.object:set_texture_mod("")
	self.object:set_properties({glow = self.glow})
end

local function valid_burst_target(self, pos)
	local target = self.attack
	local target_pos = target and target:get_pos()
	if not target or not core.is_player(target) or not target_pos or
			target:get_hp() <= 0 or
			(mobs.is_invisible and mobs:is_invisible(self,
				target:get_player_name())) then
		self:stop_attack()
		return false
	end
	local dx = target_pos.x - pos.x
	local dy = target_pos.y - pos.y
	local dz = target_pos.z - pos.z
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	local mob_eye = {x = pos.x, y = pos.y + 0.5, z = pos.z}
	local target_eye = {x = target_pos.x, y = target_pos.y + 0.5,
		z = target_pos.z}
	if distance > self.reach or
			self:line_of_sight(mob_eye, target_eye) ~= true then
		reset_fuse(self)
		return false
	end
	return true
end

local function burst_due(self, dtime)
	if not self.v_start or self._grug_rift_burst then return end
	-- mobs_redo advances this timer once in on_step and once in its explode
	-- state after do_custom returns. Predict that same due boundary here.
	if (self.timer or 0) + dtime * 2 <= (self.explosion_timer or 2) then return end
	local pos = self.object and self.object:get_pos()
	if not pos then return false end
	if not valid_burst_target(self, pos) then return false end
	self._grug_rift_burst = true
	for _, object in ipairs(core.get_objects_inside_radius(pos, RIFT_RADIUS)) do
		local ent = object:get_luaentity()
		if object ~= self.object and (core.is_player(object) or
				(ent and ent._cmi_is_mob)) then
			object:punch(self.object, 1.0, {
				full_punch_interval = 1.0,
				damage_groups = {fleshy = self.damage or 1},
			}, pos)
		end
	end
	core.add_particlespawner({
		amount = 32, time = 0.25,
		pos = {min = vector.offset(pos, -0.5, 0, -0.5),
			max = vector.offset(pos, 0.5, 1.5, 0.5)},
		vel = {min = {x = -3, y = 0, z = -3}, max = {x = 3, y = 5, z = 3}},
		exptime = {min = 0.3, max = 0.8}, size = {min = 2, max = 5},
		texture = "mobs_tnt_smoke.png^[colorize:#6d36b5:70", glow = 5,
	})
	core.sound_play(self.sounds.explode, {
		pos = pos,
		max_hear_distance = self.sounds.distance or 32,
	}, true)
	self.object:remove()
	return false
end

local rift = {
	description = "Rift Spawn", clock = "night", type = "monster",
	_grug_tier = "normal", attack_type = "explode", attack_players = true,
	group_attack = false, reach = 3, pathfinding = 1,
	walk_velocity = 1.5, run_velocity = 4.6, jump = true, jump_height = 4,
	stepheight = 1.1, fear_height = 6, view_range = 14,
	explosion_radius = 0, explosion_damage_radius = 0,
	explosion_timer = 2, allow_fuse_reset = true, stop_to_explode = true,
	sounds = {fuse = "default_cool_lava", explode = "default_item_smoke"},
	do_custom = burst_due,
	visual = "mesh", mesh = "grug_mobs_rift_spawn.b3d", glow = 3,
	textures = {{"grug_mobs_rift_spawn.png", "grug_mobs_blank.png"}},
	visual_size = {x = 2, y = 2},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.69, 0.3},
	makes_footstep_sound = false,
	animation = {
		stand_start = 0, stand_end = 23, stand_speed = 30,
		walk_start = 24, walk_end = 49, walk_speed = 30,
		run_start = 24, run_end = 49, run_speed = 60,
		fuse_start = 49, fuse_end = 80, fuse_speed = 30,
	},
	drops = {{name = "grug_mobs:slime_gel", chance = 2, min = 1, max = 1}},
	water_damage = 0, lava_damage = 4, light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:rift_spawn", rift)
mobs:spawn({name = "grug_mobs:rift_spawn",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 30, chance = 5000, active_object_count = 2,
	min_height = -31000, max_height = -1000})
mobs:spawn({name = "grug_mobs:rift_spawn",
	nodes = {"default:gravel", "default:snowblock",
		"grug_nodes:dirt_with_bone_litter", "default:dirt_with_rainforest_litter",
		"grug_nodes:dirt_with_canopy_litter"},
	interval = 30, chance = 6000, active_object_count = 1,
	min_height = 0, max_height = 300})
