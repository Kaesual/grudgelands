-- Oerkki: short-blink melee in the middle cave bands.

local function open_node(pos)
	local node = core.get_node_or_nil(pos)
	if not node then return false end
	local def = core.registered_nodes[node.name]
	return not def or not def.walkable
end

local oerkki = {
	description = "Oerkki", clock = "any", type = "monster",
	_grug_tier = "normal", _grug_spawn_domains = {"underground"},
	attack_type = "dogfight", attack_players = true, group_attack = false,
	reach = 3, pathfinding = 1, walk_velocity = 1.5, run_velocity = 4.6,
	jump = true, jump_height = 4, stepheight = 1.1, fear_height = 6,
	view_range = 12,
	visual = "mesh", mesh = "grug_mobs_oerkki.b3d", glow = 4,
	textures = {{"grug_mobs_oerkki.png"}, {"grug_mobs_oerkki4.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.35, -1, -0.35, 0.35, 0.85, 0.35},
	makes_footstep_sound = false,
	animation = {
		stand_start = 0, stand_end = 23, stand_speed = 15,
		walk_start = 24, walk_end = 36, walk_speed = 15,
		run_start = 37, run_end = 49, run_speed = 30,
		punch_start = 37, punch_end = 49, punch_speed = 30,
	},
	drops = {
		{name = "grug_materials:quartz", chance = 2, min = 1, max = 1},
		{name = "grug_materials:silver_lump", chance = 5, min = 1, max = 1},
	},
	water_damage = 2, lava_damage = 4, light_damage = 0,
	do_custom = function(self, dtime)
		self.temp = self.temp or {}
		self.temp.grug_oerkki_blink = (self.temp.grug_oerkki_blink or 0) + dtime
		if self.temp.grug_oerkki_blink < 5 or self.state ~= "attack" then return end
		local pos = self.object and self.object:get_pos()
		local target = self.attack and self.attack:get_pos()
		if not pos or not target then return end
		local dx, dy, dz = target.x - pos.x, target.y - pos.y, target.z - pos.z
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		if length <= 3 then return end
		local step = math.min(3, length - 2)
		local dest = {x = pos.x + dx * step / length,
			y = pos.y + dy * step / length, z = pos.z + dz * step / length}
		if open_node(dest) and open_node({x = dest.x, y = dest.y + 1, z = dest.z}) then
			grug_core.invalidate_combat_identity(self.object)
			self.object:set_pos(dest)
			self.temp.grug_oerkki_blink = 0
			core.add_particlespawner({
				amount = 12, time = 0.2,
				pos = {min = vector.offset(dest, -0.4, 0, -0.4),
					max = vector.offset(dest, 0.4, 1.4, 0.4)},
				exptime = {min = 0.2, max = 0.5}, size = {min = 1, max = 2},
				texture = "default_item_smoke.png^[multiply:#7030a0", glow = 4,
			})
		end
	end,
}

grug_mobs.register_mob("grug_mobs:oerkki", oerkki)
mobs:spawn({name = "grug_mobs:oerkki",
	nodes = {"default:stone", "group:grug_stratum"}, max_light = 5,
	interval = 20, chance = 2500, active_object_count = 3,
	min_height = -700, max_height = -300})
