-- Round 8 apex encounters: the two fixed island dragons and one royal group
-- on each capital's authored throne sockets.  None has an ambient spawn row.

local storage = core.get_mod_storage()
local RESPAWN_DRAGON = 30 * 60
local LOOT_LOCKOUT = 24 * 60 * 60
local LEDGER_RANGE = 60
local DEATH_GRACE = 60

local ledgers = {}

local RACES = {
	dwarf = {name = "King of Dur Brannoc", faction = "accord",
		kit = "shatter", weapon = "greataxe"},
	human = {name = "King of Highcourt", faction = "accord",
		kit = "rally", weapon = "sword"},
	elf = {name = "King of Lethariel", faction = "accord",
		kit = "volley", weapon = "staff"},
	undead = {name = "King of Nhal Veyr", faction = "throng",
		kit = "bone_call", weapon = "staff"},
	orc = {name = "King of Gor Drazhak", faction = "throng",
		kit = "cleave", weapon = "greataxe"},
	troll = {name = "King of Kezamba", faction = "throng",
		kit = "regrowth", weapon = "staff"},
}

local DRAGONS = {
	wyrmglass = {
		name = "The Wyrmglass Ice Dragon",
		entity = "grug_mobs:ice_dragon",
		x = -3260, z = -40,
	},
	stormscale = {
		name = "The Stormscale Jungle Wyvern",
		entity = "grug_mobs:jungle_wyvern",
		x = 3260, z = -40,
	},
}

local function player_enemy_of(player, faction)
	local own = grug_core.get_player_faction(player:get_player_name())
	return own ~= nil and (not faction or own == grug_core.opposing_faction(faction))
end

local function ledger(id)
	local row = ledgers[id]
	if not row then
		row = {players = {}, deaths = {}}
		ledgers[id] = row
	end
	return row
end

local function boss_faction(id)
	local race = id and id:match("^king:(.+)$")
	return race and RACES[race] and RACES[race].faction or nil
end

local function participant(id, player)
	if not id or not player_enemy_of(player, boss_faction(id)) then return end
	ledger(id).players[player:get_player_name()] = true
end

grug_core.register_on_player_hit_mob(function(player, mob)
	if mob and mob._grug_boss_id then participant(mob._grug_boss_id, player) end
end)

grug_core.register_on_effective_heal(function(healer, target)
	local target_name = target:get_player_name()
	for id, row in pairs(ledgers) do
		if row.players[target_name] then participant(id, healer) end
	end
end)

grug_core.register_on_effective_absorb(function(source, target)
	local target_name = target:get_player_name()
	for id, row in pairs(ledgers) do
		if row.players[target_name] then participant(id, source) end
	end
end)

local function encounter_death(player, reason)
	local killer = reason and reason.object
	if not killer then return false end
	if core.is_player(killer) then
		local victim_faction = grug_core.get_player_faction(
			player:get_player_name())
		return player_enemy_of(killer, victim_faction)
	end
	local ent = killer:get_luaentity()
	return ent and (ent._grug_boss_id or ent._grug_royal_summon) ~= nil
end

core.register_on_dieplayer(function(player, reason)
	if not encounter_death(player, reason) then return end
	local name = player:get_player_name()
	local now = os.time()
	for _, row in pairs(ledgers) do
		if row.players[name] then row.deaths[name] = now end
	end
end)

local function crown_stack(race)
	local stack = ItemStack("grug_mobs:fallen_crown")
	local meta = stack:get_meta()
	meta:set_string("grug_defeated_race", race)
	meta:set_string("description", "Fallen Crown (" ..
		(RACES[race] and RACES[race].name or race) .. ")")
	return stack
end

local function pending_key()
	return "grug_mobs:pending_boss_loot"
end

local function give_or_queue(player, stack)
	local inv = player:get_inventory()
	local leftover = inv:add_item("main", stack)
	if leftover:is_empty() then return end
	local meta = player:get_meta()
	local pending = core.deserialize(meta:get_string(pending_key())) or {}
	pending[#pending + 1] = leftover:to_string()
	meta:set_string(pending_key(), core.serialize(pending))
	core.chat_send_player(player:get_player_name(),
		"Boss loot is waiting for free inventory space.")
end

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	local pending = core.deserialize(meta:get_string(pending_key())) or {}
	if #pending == 0 then return end
	local keep = {}
	for index = 1, #pending do
		local leftover = player:get_inventory():add_item("main", ItemStack(pending[index]))
		if not leftover:is_empty() then keep[#keep + 1] = leftover:to_string() end
	end
	meta:set_string(pending_key(), #keep > 0 and core.serialize(keep) or "")
end)

local function lockout_key(id)
	return "grug_boss_lockout:" .. id
end

local function settle_boss(id, self, race)
	local row = ledgers[id]
	local pos = self.object and self.object:get_pos()
	if not row or not pos then
		ledgers[id] = nil
		return
	end
	local now = os.time()
	for name in pairs(row.players) do
		local player = core.get_player_by_name(name)
		local death_ok = row.deaths[name] and now - row.deaths[name] <= DEATH_GRACE
		local near = false
		if player and player:get_hp() > 0 then
			local p = player:get_pos()
			local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
			near = dx * dx + dy * dy + dz * dz <= LEDGER_RANGE * LEDGER_RANGE
		end
		if player and (near or death_ok) then
			local meta = player:get_meta()
			local key = lockout_key(id)
			if meta:get_int(key) <= now then
				if race then
					give_or_queue(player, crown_stack(race))
				else
					give_or_queue(player, ItemStack("grug_mobs:scaled_hide 4"))
				end
				meta:set_int(key, now + LOOT_LOCKOUT)
			end
		end
	end
	ledgers[id] = nil
end

function grug_mobs.boss_attempt_reset(id)
	if id then ledgers[id] = nil end
end

function grug_mobs.boss_leash_reset(self)
	if self and self._grug_royal_race then
		-- The king alone owns the five-NPC encounter. A guard may individually
		-- leash, heal and resume following, but must never clear participation
		-- or recreate the retinue underneath a live king attempt.
		if self._grug_royal_king and grug_mobs.royal_encounter_reset then
			grug_mobs.royal_encounter_reset(self)
		end
		return
	elseif self and self._grug_boss_id then
		grug_mobs.boss_attempt_reset(self._grug_boss_id)
	end
end

core.register_craftitem("grug_mobs:fallen_crown", {
	description = "Fallen Crown",
	inventory_image = "grug_mobs_item_fallen_crown.png",
	stack_max = 1,
	groups = {grug_rare_trophy = 1},
})

grug_mobs.register_simple_arrow("grug_mobs:ice_breath", {
	texture = "grug_mobs_rock.png^[colorize:#8ee8ff:210",
	velocity = 22, size = {x = 1.4, y = 1.4}, glow = 10,
	tail = true, tail_texture = "grug_mobs_rock.png^[colorize:#b8f4ff:220",
	lifetime = 2,
})
grug_mobs.register_simple_arrow("grug_mobs:storm_breath", {
	texture = "grug_mobs_rock.png^[colorize:#72e890:210",
	velocity = 22, size = {x = 1.4, y = 1.4}, glow = 8,
	tail = true, tail_texture = "grug_mobs_rock.png^[colorize:#a0f2aa:220",
	lifetime = 2,
})

local function shoot(self, target, arrow, offset_angle)
	local from = self.object:get_pos()
	local to = target and target:get_pos()
	if not from or not to then return end
	from = {x = from.x, y = from.y + 2.2, z = from.z}
	to = {x = to.x, y = to.y + 1, z = to.z}
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	if offset_angle and offset_angle ~= 0 then
		local c, s = math.cos(offset_angle), math.sin(offset_angle)
		dx, dz = dx * c - dz * s, dx * s + dz * c
	end
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length <= 0 then return end
	local object = core.add_entity(from, arrow)
	local ent = object and object:get_luaentity()
	if not ent then return end
	ent._grug_damage = self.damage
	ent.owner_id = tostring(self.object)
	local velocity = ent.velocity or 16
	object:set_velocity({x = dx * velocity / length,
		y = dy * velocity / length, z = dz * velocity / length})
end

local function hit_players(self, radius, multiplier, cone, knockback, faction)
	local pos = self.object:get_pos()
	if not pos then return end
	local facing
	if cone then facing = core.yaw_to_dir(self.object:get_yaw() or 0) end
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius)) do
		if core.is_player(object) and object:get_hp() > 0 and
				(not faction or player_enemy_of(object, faction)) then
			local target = object:get_pos()
			local dx, dz = target.x - pos.x, target.z - pos.z
			local length = math.sqrt(dx * dx + dz * dz)
			local inside = not cone or length <= 0 or
				(dx * facing.x + dz * facing.z) / length >= 0.5
			if inside then
				object:punch(self.object, 1, {full_punch_interval = 1,
					damage_groups = {fleshy = self.damage * multiplier}}, nil)
				if knockback and length > 0 then
					object:add_velocity({x = dx * knockback / length, y = 4,
						z = dz * knockback / length})
				end
			end
		end
	end
end

local function dragon_tick(self, dtime, arrow)
	self.temp = self.temp or {}
	local cast = self.temp.grug_boss_cast
	if cast then
		self:set_velocity(0)
		cast.left = cast.left - dtime
		if cast.left <= 0 then
			if cast.kind == "slam" then
				hit_players(self, 7, 3, false, 7)
			else
				shoot(self, cast.target, arrow, 0)
			end
			self.temp.grug_boss_cast = nil
			self.temp.grug_boss_cooldown = 5
		end
		return
	end
	self.temp.grug_boss_cooldown = math.max(0,
		(self.temp.grug_boss_cooldown or 2) - dtime)
	local target = self.attack
	local pos = self.object:get_pos()
	local target_pos = target and target:get_pos()
	if target_pos and self.temp.grug_boss_cooldown <= 0 then
		local dx, dz = target_pos.x - pos.x, target_pos.z - pos.z
		local near = dx * dx + dz * dz <= 49
		self.temp.grug_boss_cast = {kind = near and "slam" or "breath",
			target = target, left = 2}
		self:set_animation(near and "punch" or "shoot", true)
		self:set_velocity(0)
	end
	self.temp.grug_perch_clock = (self.temp.grug_perch_clock or 0) + dtime
	if not target and self.temp.grug_perch_clock >= 15 and self._grug_perches then
		self.temp.grug_perch_clock = 0
		self.temp.grug_perch = (self.temp.grug_perch or 1) % 3 + 1
		grug_mobs.place_on_ground(self.object,
			self._grug_perches[self.temp.grug_perch])
	end
end

local function dragon_def(id, opts)
	return {
		description = opts.description,
		clock = "any", type = "monster",
		_grug_fixed_level = 60, _grug_tier = "boss",
		_grug_leash_range = 36,
		attack_type = "dogfight", attack_players = true,
		pathfinding = 1, reach = 5, group_attack = false,
		walk_velocity = 0, run_velocity = 0,
		jump = false, fear_height = 0, view_range = 32,
		visual = "mesh", mesh = opts.mesh, textures = {opts.textures},
		visual_size = opts.size, collisionbox = opts.box,
		makes_footstep_sound = true, fall_damage = false,
		animation = opts.animation,
		drops = {}, water_damage = 0, lava_damage = 0, light_damage = 0,
		after_activate = function(self)
			self._grug_boss_id = "dragon:" .. id
			storage:set_string("boss:dragon:" .. id .. ":alive", "1")
		end,
		do_custom = function(self, dtime)
			self._grug_boss_id = "dragon:" .. id
			dragon_tick(self, dtime, opts.arrow)
		end,
		on_die = function(self)
			settle_boss("dragon:" .. id, self, nil)
			storage:set_string("boss:dragon:" .. id .. ":alive", "")
			storage:set_string("boss:dragon:" .. id .. ":due",
				tostring(os.time() + RESPAWN_DRAGON))
			storage:set_string("boss:dragon:" .. id .. ":warned", "")
		end,
	}
end

grug_mobs.register_mob("grug_mobs:ice_dragon", dragon_def("wyrmglass", {
	description = "Wyrmglass Ice Dragon", mesh = "grug_mobs_ice_dragon.b3d",
	textures = {"grug_mobs_ice_dragon.png^grug_mobs_dragon_shading.png"},
	size = {x = 4, y = 4}, box = {-1.5, 0, -1.5, 1.5, 4, 1.5},
	arrow = "grug_mobs:ice_breath",
	animation = {
		stand_start = 1, stand_end = 59, stand_speed = 20,
		walk_start = 211, walk_end = 249, walk_speed = 20,
		run_start = 211, run_end = 249, run_speed = 30,
		punch_start = 121, punch_end = 159, punch_speed = 20,
		shoot_start = 61, shoot_end = 119, shoot_speed = 20,
		die_start = 571, die_end = 579, die_speed = 20,
	},
}))

grug_mobs.register_mob("grug_mobs:jungle_wyvern", dragon_def("stormscale", {
	description = "Stormscale Jungle Wyvern",
	mesh = "grug_mobs_jungle_wyvern.b3d",
	textures = {"grug_mobs_jungle_wyvern.png"},
	size = {x = 4, y = 4}, box = {-1.2, 0, -1.2, 1.2, 3.2, 1.2},
	arrow = "grug_mobs:storm_breath",
	animation = {
		stand_start = 1, stand_end = 59, stand_speed = 20,
		walk_start = 91, walk_end = 119, walk_speed = 20,
		run_start = 181, run_end = 209, run_speed = 30,
		punch_start = 61, punch_end = 89, punch_speed = 20,
		shoot_start = 241, shoot_end = 279, shoot_speed = 20,
		die_start = 281, die_end = 299, die_speed = 20,
	},
}))

local function royal_objects(id, radius, pos)
	local result = {}
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_boss_id == id then result[#result + 1] = ent end
	end
	return result
end

local function royal_signature(self, race, target, start_health)
	local kit = RACES[race].kit
	local faction = RACES[race].faction
	if kit == "shatter" then
		hit_players(self, 6, 3, false, 8, faction)
	elseif kit == "rally" then
		local pos = self.object:get_pos()
		local offsets = {{x = -3, z = 2}, {x = 3, z = 2},
			{x = -3, z = 5}, {x = 3, z = 5}}
		local guard_index = 0
		for _, ent in ipairs(royal_objects(self._grug_boss_id, 50, pos)) do
			if ent.name:find("grug_mobs:royal_guard_", 1, true) then
				guard_index = guard_index + 1
				ent.health = math.min(ent.hp_max or ent.health,
					ent.health + math.floor((ent.hp_max or ent.health) * 0.2))
				ent.old_health = ent.health
				local offset = offsets[guard_index]
				if offset then
					grug_mobs.place_on_ground(ent.object, {x = pos.x + offset.x,
						y = pos.y, z = pos.z + offset.z})
				end
			end
		end
	elseif kit == "volley" then
		shoot(self, target, "grug_mobs:arrow_entity", -0.16)
		shoot(self, target, "grug_mobs:arrow_entity", 0)
		shoot(self, target, "grug_mobs:arrow_entity", 0.16)
	elseif kit == "bone_call" then
		local pos = self.object:get_pos()
		for _, dx in ipairs({-2, 2}) do
			local object = core.add_entity({x = pos.x + dx, y = pos.y,
				z = pos.z + 2}, "grug_mobs:skeleton_raider")
			local ent = object and object:get_luaentity()
			if ent then ent._grug_royal_summon = self._grug_boss_id end
		end
	elseif kit == "cleave" then
		hit_players(self, 6, 3, true, 0, faction)
	elseif kit == "regrowth" and self.health >= start_health then
		self.health = math.min(self.hp_max or self.health,
			self.health + math.floor((self.hp_max or self.health) * 0.2))
		self.old_health = self.health
	end
end

local function king_tick(self, dtime, race)
	self._grug_boss_id = "king:" .. race
	self._grug_royal_race = race
	self._grug_royal_king = true
	self.temp = self.temp or {}
	if self._grug_start and not self.temp.grug_socket_claimed then
		self.temp.grug_socket_claimed = true
		if not grug_mobs.start_npc_claim(self) then return false end
	end
	if self.temp.grug_evading then
		if not self.temp.grug_royal_reset then
			self.temp.grug_royal_reset = true
			grug_mobs.royal_encounter_reset(self)
		end
	else
		self.temp.grug_royal_reset = nil
	end
	local cast = self.temp.grug_royal_cast
	if cast then
		self:set_velocity(0)
		cast.left = cast.left - dtime
		if cast.left <= 0 then
			royal_signature(self, race, cast.target, cast.health)
			self.temp.grug_royal_cast = nil
			self.temp.grug_royal_cooldown = 8
		end
		return
	end
	self.temp.grug_royal_cooldown = math.max(0,
		(self.temp.grug_royal_cooldown or 4) - dtime)
	if self.attack and self.attack:get_pos() and self.temp.grug_royal_cooldown <= 0 then
		self.temp.grug_royal_cast = {target = self.attack, left = 2,
			health = self.health}
		self:set_animation(RACES[race].kit == "volley" and "shoot" or "punch", true)
		self:set_velocity(0)
	end
end

local function king_def(race, row)
	local ranged = row.kit == "volley" or row.kit == "bone_call" or
		row.kit == "regrowth"
	return {
		description = row.name, clock = "any", type = "npc",
		_grug_faction = row.faction, _grug_fixed_level = 65,
		_grug_tier = "elite", _grug_leash_range = 30,
		attack_type = ranged and "dogshoot" or "dogfight",
		attack_players = true, attack_monsters = false, attack_npcs = false,
		group_attack = true, pathfinding = 1, reach = 3,
		arrow = row.kit == "volley" and "grug_mobs:arrow_entity" or
			(ranged and "grug_mobs:rock_entity" or nil),
		arrow_override = ranged and grug_mobs.stamp_arrow_damage or nil,
		shoot_interval = 3, shoot_offset = 1.5,
		walk_velocity = 1.2, run_velocity = 4.6,
		jump = true, jump_height = 4, stepheight = 1.1, fear_height = 4,
		view_range = 18, owner = "",
		visual = "mesh", mesh = "character.b3d",
		textures = {{"grug_mobs_royal_" .. race .. ".png"}},
		_grug_visual = function(self)
			return {skin = "grug_mobs_royal_" .. race .. ".png",
				level = self._grug_level, weapon_family = row.weapon}
		end,
		-- Elite visuals multiply by 1.6; this base makes the authored final
		-- royal stature exactly 1.15 rather than silently growing to 1.84.
		visual_size = {x = 0.71875, y = 0.71875},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
		animation = {
			stand_start = 0, stand_end = 79, stand_speed = 30,
			walk_start = 168, walk_end = 187, walk_speed = 30,
			run_start = 168, run_end = 187, run_speed = 45,
			punch_start = 189, punch_end = 198, punch_speed = 30,
			shoot_start = 189, shoot_end = 198, shoot_speed = 30,
		},
		drops = {}, water_damage = 0, lava_damage = 4, light_damage = 0,
		do_custom = function(self, dtime) return king_tick(self, dtime, race) end,
		on_die = function(self)
			settle_boss("king:" .. race, self, race)
			local pos = self.object and self.object:get_pos()
			if pos then
				for _, object in ipairs(core.get_objects_inside_radius(pos, 80)) do
					local ent = object:get_luaentity()
					if ent and (ent._grug_royal_summon == self._grug_boss_id) then
						object:remove()
					end
				end
			end
			grug_mobs.royal_king_died(self)
		end,
	}
end

local ROYAL_FOLLOW_DISTANCE = 5
local ROYAL_PATH_FAILURE = 20

local function royal_guard_base_tick(base_tick, self, dtime)
	-- Royal socket fields identify and claim the authored guard slot, but the
	-- ordinary start-guard tick would also steer this guard back to that slot.
	-- The king is the only live home target for the encounter, so keep the
	-- identity fields while hiding them from start_post_tick.
	local post_x, post_z, post_yaw = self._grug_post_x, self._grug_post_z,
		self._grug_post_yaw
	self._grug_post_x, self._grug_post_z, self._grug_post_yaw = nil, nil, nil
	local result = base_tick(self, dtime)
	self._grug_post_x, self._grug_post_z, self._grug_post_yaw =
		post_x, post_z, post_yaw
	return result
end

local function royal_guard_drop_attack(self)
	if not self.attack then return end
	if type(self.stop_attack) == "function" then
		self:stop_attack()
	else
		self.attack = nil
		self.state = "stand"
	end
end

local function royal_guard_tick(base_tick, self, dtime)
	self._grug_boss_id = "king:" .. self._grug_royal_race
	local result = royal_guard_base_tick(base_tick, self, dtime)
	if result == false then return false end
	if not self.object then return end
	self.temp = self.temp or {}
	self.temp.grug_royal_follow = (self.temp.grug_royal_follow or 0) + dtime
	if self.temp.grug_royal_follow < 1 then
		-- Returning false is the mobs_redo ownership boundary: while follow is
		-- active, on_step must not run do_states or general_attack after this
		-- callback and overwrite the kingward movement with an enemy chase.
		if self.temp.grug_royal_follow_active then
			royal_guard_drop_attack(self)
			return false
		end
		return
	end
	local elapsed = self.temp.grug_royal_follow
	self.temp.grug_royal_follow = 0
	local pos = self.object:get_pos()
	for _, ent in ipairs(royal_objects(self._grug_boss_id, 80, pos)) do
		if ent.name:find("grug_mobs:king_", 1, true) then
			local king_pos = ent.object:get_pos()
			self._grug_home = {x = king_pos.x, y = king_pos.y, z = king_pos.z}
			local dx, dz = king_pos.x - pos.x, king_pos.z - pos.z
			if dx * dx + dz * dz <=
					ROYAL_FOLLOW_DISTANCE * ROYAL_FOLLOW_DISTANCE then
				self.temp.grug_royal_follow_active = nil
				self.temp.grug_royal_path_attempted = nil
				grug_mobs.stall_clear(self)
				return
			end
			self.temp.grug_royal_follow_active = true
			royal_guard_drop_attack(self)
			local stalled = grug_mobs.stall_clock(self, king_pos.x, king_pos.z,
				pos, elapsed)
			if stalled >= ROYAL_PATH_FAILURE then
				if not self.temp.grug_royal_path_attempted then
					self.temp.grug_royal_path_attempted = true
					if grug_mobs.path_nudge(self, king_pos.x, king_pos.z, pos) then
						return false
					end
				end
				-- Unlike ambient patrol snaps, this is encounter correction, not
				-- travel: the guard must rejoin the authoritative king even while
				-- watched, and never moves the king in response to its own failure.
				grug_mobs.place_on_ground(self.object, king_pos)
				grug_mobs.stall_clear(self)
				self.temp.grug_royal_follow_active = nil
				self.temp.grug_royal_path_attempted = nil
				return false
			end
			self.temp.grug_royal_path_attempted = nil
			grug_mobs.walk_toward(self, king_pos.x, king_pos.z, pos)
			return false
		end
	end
	self.temp.grug_royal_follow_active = nil
	self.temp.grug_royal_path_attempted = nil
	grug_mobs.stall_clear(self)
end

for race, row in pairs(RACES) do
	local race_id, race_row = race, row
	grug_mobs.register_mob("grug_mobs:king_" .. race_id,
		king_def(race_id, race_row))
	local guard = grug_mobs.guard_definition(row.faction,
		row.name .. " Royal Guard", "grug_mobs_royal_" .. race_id .. ".png")
	local base_tick = guard.do_custom
	guard._grug_fixed_level = 60
	guard._grug_tier = "elite"
	-- Only the king owns an encounter leash/reset. Royal guards return to the
	-- king through royal_guard_tick and never acquire an independent chase
	-- anchor or reset the five-NPC group.
	guard._grug_no_leash = true
	guard._grug_leash_range = nil
	guard._grug_visual = function(self)
		return {skin = "grug_mobs_royal_" .. race_id .. ".png",
			level = self._grug_level, weapon_family = "sword"}
	end
	guard.textures = {{"grug_mobs_royal_" .. race_id .. ".png"}}
	guard.do_custom = function(self, dtime)
		self._grug_royal_race = self._grug_royal_race or race_id
		return royal_guard_tick(base_tick, self, dtime)
	end
	guard.on_die = function(self) grug_mobs.royal_guard_died(self) end
	grug_mobs.register_mob("grug_mobs:royal_guard_" .. race_id, guard)
end

local function dragon_pos(row, dx, dz)
	local x, z = row.x + (dx or 0), row.z + (dz or 0)
	return {x = x, y = grug_zones.terrain_height_at(x, z) + 1, z = z}
end

local function spawn_dragon(id, row)
	local pos = dragon_pos(row)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "ignore" then return false end
	local object = core.add_entity(pos, row.entity)
	local ent = object and object:get_luaentity()
	if not ent then return false end
	ent._grug_boss_id = "dragon:" .. id
	ent._grug_perches = {
		dragon_pos(row, 0, 0), dragon_pos(row, 18, 8),
		dragon_pos(row, -15, 12),
	}
	ent._grug_home = ent._grug_perches[1]
	storage:set_string("boss:dragon:" .. id .. ":alive", "1")
	storage:set_string("boss:dragon:" .. id .. ":due", "")
	return true
end

function grug_mobs.boss_spawn_due(id)
	local row = DRAGONS[id]
	if not row then return false end
	return spawn_dragon(id, row)
end

local function dragon_lair_loaded(row)
	local pos = dragon_pos(row)
	local node = core.get_node_or_nil(pos)
	return node and node.name ~= "ignore", pos
end

local function warn_dragon(id, row, now, due, pos)
	-- The warning is local to the contested objective. If nobody has the lair
	-- loaded when the base timer expires, `due` is moved forward here so the
	-- next activation receives the full authored minute instead of an instant
	-- respawn.
	local final_due = math.max(due, now + 60)
	storage:set_string("boss:dragon:" .. id .. ":due", tostring(final_due))
	storage:set_string("boss:dragon:" .. id .. ":warned", "1")
	for _, player in ipairs(core.get_connected_players()) do
		local player_pos = player:get_pos()
		if player_pos then
			local dx, dy, dz = player_pos.x - pos.x, player_pos.y - pos.y,
				player_pos.z - pos.z
			if dx * dx + dy * dy + dz * dz <= 160 * 160 then
				core.chat_send_player(player:get_player_name(),
					row.name .. " returns in 60 seconds.")
			end
		end
	end
	core.sound_play("mobs_spell", {pos = pos, gain = 1.0,
		max_hear_distance = 160}, true)
	core.add_particlespawner({
		amount = 180, time = 8,
		pos = {min = {x = pos.x - 5, y = pos.y, z = pos.z - 5},
			max = {x = pos.x + 5, y = pos.y + 12, z = pos.z + 5}},
		vel = {min = {x = -1, y = 2, z = -1},
			max = {x = 1, y = 6, z = 1}},
		exptime = {min = 1, max = 3}, size = {min = 4, max = 9},
		texture = "default_item_smoke.png^[colorize:#ffd24a:220",
		glow = 12,
	})
end

local boss_clock = 0
core.register_globalstep(function(dtime)
	boss_clock = boss_clock + dtime
	if boss_clock < 10 then return end
	boss_clock = boss_clock - 10
	local now = os.time()
	for id, row in pairs(DRAGONS) do
		if storage:get_string("boss:dragon:" .. id .. ":alive") ~= "1" then
			local due = tonumber(storage:get_string("boss:dragon:" .. id .. ":due")) or 0
			local warned = storage:get_string("boss:dragon:" .. id .. ":warned") == "1"
			local loaded, pos = dragon_lair_loaded(row)
			if loaded and due == 0 and spawn_dragon(id, row) then
				-- First creation is not a respawn and carries no return warning.
			elseif loaded and not warned and due - now <= 60 then
				warn_dragon(id, row, now, due, pos)
			elseif loaded and warned and due <= now and spawn_dragon(id, row) then
				core.chat_send_all(row.name .. " has returned.")
				storage:set_string("boss:dragon:" .. id .. ":warned", "")
			end
		end
	end
end)
