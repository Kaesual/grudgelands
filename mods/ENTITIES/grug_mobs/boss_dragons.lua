-- Round 9 dragon encounter chassis: runtime ground/flight switching, authored
-- attacks, temporary ground effects and boss-bound whelps.

local TUNING = {
	walk = 5.2,
	run = 6.5,
	fly = 8,
	whelp_fly = 9.5,
	dive = 18,
	view = 48,
	leash = 64,
	takeoff_distance = 12,
	landing_distance = 9,
	vertical_tolerance = 8,
	breath_windup = 1.25,
	breath_cooldown = 6,
	lightning_windup = 1.5,
	lightning_cooldown = 8,
	dive_windup = 1,
	dive_cooldown = 6,
	gust_cooldown = 12,
	gust_radius = 5,
	gust_slow = 2,
	enrage_fraction = 0.5,
	enrage_cooldown_factor = 0.7,
	whelp_level = 20,
	trail_particles = 18,
}
grug_mobs.DRAGON_TUNING = TUNING

local RIME = "grug_mobs:dragon_rime"
local SCORCH = "grug_mobs:dragon_scorch"
local EFFECT_DURATION = {rime = 8, scorch = 6}
local effect_node = {rime = RIME, scorch = SCORCH}

local hostile_player = function(player)
	return player and core.is_player(player) and player:get_hp() > 0
end

local function effect_timeout(pos, name)
	local node = core.get_node_or_nil(pos)
	if node and node.name == name then
		core.set_node(pos, {name = "air"})
	end
	return false
end

core.register_node(RIME, {
	description = "Dragon Rime",
	drawtype = "nodebox",
	tiles = {"default_ice.png^[colorize:#b8f4ff:80"},
	use_texture_alpha = "blend",
	paramtype = "light",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	sunlight_propagates = true,
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.45, 0.5}},
	groups = {not_in_creative_inventory = 1},
	drop = "",
	on_timer = function(pos) return effect_timeout(pos, RIME) end,
})

core.register_node(SCORCH, {
	description = "Dragon Scorch",
	drawtype = "nodebox",
	tiles = {"default_lava.png^[colorize:#4a1600:90"},
	use_texture_alpha = "blend",
	paramtype = "light",
	light_source = 5,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	sunlight_propagates = true,
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.45, 0.5}},
	groups = {not_in_creative_inventory = 1},
	drop = "",
	on_timer = function(pos) return effect_timeout(pos, SCORCH) end,
})

local function rounded_column(pos, y)
	return {
		x = math.floor(pos.x + 0.5),
		y = y,
		z = math.floor(pos.z + 0.5),
	}
end

local function protected_for_actor(pos, actor_name)
	if not actor_name or actor_name == "" then return true end
	local faction = grug_core.get_player_faction(actor_name)
	if grug_core.world_protected_for_faction(pos, faction) then return true end
	return core.is_protected(pos, actor_name)
end

local function find_effect_pos(impact)
	local top = math.floor(impact.y + 0.1) + 1
	for y = top, top - 4, -1 do
		local pos = rounded_column(impact, y)
		local node = core.get_node_or_nil(pos)
		local below = core.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		local def = node and core.registered_nodes[node.name]
		local below_def = below and core.registered_nodes[below.name]
		if node and def and below and below_def and
				(node.name == "air" or def.buildable_to) and below_def.walkable then
			return pos, node.name
		end
	end
end

local function effect_burst(pos, kind)
	local ice = kind == "rime"
	core.add_particlespawner({
		amount = 36,
		time = 0.25,
		pos = {min = {x = pos.x - 1, y = pos.y, z = pos.z - 1},
			max = {x = pos.x + 1, y = pos.y + 0.5, z = pos.z + 1}},
		vel = {min = {x = -1, y = 0.2, z = -1},
			max = {x = 1, y = 1.5, z = 1}},
		exptime = {min = 0.4, max = 1.2},
		size = {min = 1.5, max = 3.5},
		texture = ice and "default_snow.png^[colorize:#8ee8ff:120" or
			"default_item_smoke.png^[colorize:#ff5a20:210",
		glow = ice and 8 or 10,
	})
end

local function place_ground_effect(kind, impact, actor_name)
	local name = effect_node[kind]
	if not name or not impact then return false end
	local pos, previous = find_effect_pos(impact)
	if not pos or protected_for_actor(pos, actor_name) then return false end
	if previous == name then
		core.get_node_timer(pos):start(EFFECT_DURATION[kind])
		return true
	end
	if previous == RIME or previous == SCORCH then return false end
	core.set_node(pos, {name = name})
	core.get_node_timer(pos):start(EFFECT_DURATION[kind])
	effect_burst(pos, kind)
	return true
end
grug_mobs.place_dragon_ground_effect = place_ground_effect

local effect_clock = 0
local scorch_clock = 0
local function effect_node_at_feet(pos)
	local feet = vector.round(pos)
	local node = core.get_node_or_nil(feet)
	if node and node.name == "air" then
		feet.y = feet.y - 1
		node = core.get_node_or_nil(feet)
	end
	return node
end

core.register_globalstep(function(dtime)
	effect_clock = effect_clock + dtime
	scorch_clock = scorch_clock + dtime
	if effect_clock < 0.25 then return end
	local do_scorch = scorch_clock >= 1
	-- A delayed server step is one sample, never a damage backlog replay.
	effect_clock = 0
	if do_scorch then scorch_clock = 0 end
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos and player:get_hp() > 0 then
			local node = effect_node_at_feet(pos)
			if node and node.name == RIME then
				grug_mobs.slow_player(player, 0.5, 0.6)
			elseif do_scorch and node and node.name == SCORCH then
				grug_core.mark_in_combat(player)
				player:set_hp(math.max(0, player:get_hp() - 2), {
					type = "node_damage", node = SCORCH,
				})
			end
		end
	end
end)

local function projectile_hit(self, player)
	if not hostile_player(player) then return end
	local source = self._grug_source or self.object
	player:punch(source, 1, {
		full_punch_interval = 1,
		damage_groups = {fleshy = (self._grug_damage or 1) * 1.5},
	}, nil)
	place_ground_effect(self._grug_effect, player:get_pos(), self._grug_actor_name)
end

local function projectile_node(self, pos)
	place_ground_effect(self._grug_effect, pos, self._grug_actor_name)
end

local function projectile_trail(self, dtime)
	self._grug_trail_count = self._grug_trail_count or 0
	self._grug_trail_left = (self._grug_trail_left or 0) - dtime
	if self._grug_trail_count >= TUNING.trail_particles or
			self._grug_trail_left > 0 then return end
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	self._grug_trail_count = self._grug_trail_count + 1
	self._grug_trail_left = 0.08
	core.add_particle({
		pos = pos,
		velocity = {x = 0, y = 0, z = 0},
		expirationtime = 0.35,
		size = 4,
		texture = self._grug_effect == "rime" and
			"grug_mobs_rock.png^[colorize:#b8f4ff:220" or
			"grug_mobs_rock.png^[colorize:#ff7338:220",
		glow = 10,
	})
end

local function register_breath_arrow(name, texture, effect)
	mobs:register_arrow(name, {
		visual = "sprite",
		visual_size = {x = 1.4, y = 1.4},
		textures = {texture},
		velocity = 22,
		glow = 10,
		lifetime = 2,
		hit_player = projectile_hit,
		hit_mob = function() end,
		hit_node = projectile_node,
		do_custom = projectile_trail,
		on_activate = function(self)
			self._grug_effect = effect
		end,
	})
end

register_breath_arrow("grug_mobs:ice_breath",
	"grug_mobs_rock.png^[colorize:#8ee8ff:210", "rime")
register_breath_arrow("grug_mobs:storm_breath",
	"grug_mobs_rock.png^[colorize:#ff7338:210", "scorch")

local function distance(a, b)
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz),
		math.sqrt(dx * dx + dz * dz), math.abs(dy)
end

local function target_position(target)
	if not target or not core.is_player(target) or target:get_hp() <= 0 then
		return nil
	end
	return target:get_pos()
end

local function valid_target(self, target)
	local pos = self.object and self.object:get_pos()
	local target_pos = target_position(target)
	if not pos or not target_pos or not hostile_player(target) then return nil end
	local dist, horizontal, vertical = distance(pos, target_pos)
	if dist > TUNING.view or vertical > TUNING.vertical_tolerance then return nil end
	return target_pos, horizontal
end

local function hostile_players(pos, radius)
	local result = {}
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local target_pos = target_position(object)
		if target_pos and hostile_player(object) and
				math.abs(target_pos.y - pos.y) <= TUNING.vertical_tolerance then
			result[#result + 1] = object
		end
	end
	return result
end

local function stop_object(self)
	if self.object then
		self.object:set_velocity({x = 0, y = 0, z = 0})
	end
end

local function set_flight(self, enabled)
	self.fly = enabled
	if not self.object then return end
	if enabled then
		self.object:set_acceleration({x = 0, y = 0, z = 0})
		if self.set_animation then self:set_animation("fly", true) end
	else
		self.object:set_acceleration({x = 0, y = self.fall_speed or -9.81, z = 0})
	end
end

local function flight_speed(self, wanted, base)
	if (self._grug_root_left or 0) > 0 then return 0 end
	local current = self.run_velocity or base
	local factor = base > 0 and current / base or 1
	return wanted * math.max(0, math.min(1.5, factor))
end

local function steer(self, destination, wanted, base)
	local pos = self.object and self.object:get_pos()
	if not pos or not destination then return end
	local dx, dy, dz = destination.x - pos.x, destination.y - pos.y,
		destination.z - pos.z
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length <= 0 then return end
	if self.yaw_to_pos then self:yaw_to_pos(destination, 0, 4) end
	local speed = flight_speed(self, wanted, base)
	self.object:set_velocity({
		x = dx * speed / length,
		y = dy * speed / length,
		z = dz * speed / length,
	})
	if self.set_animation then self:set_animation("fly", true) end
end

local function grounded(self, moveresult)
	if moveresult and moveresult.touching_ground then return true end
	local pos = self.object and self.object:get_pos()
	if not pos then return false end
	local below = rounded_column(pos, math.floor(pos.y - 0.1))
	local node = core.get_node_or_nil(below)
	local def = node and core.registered_nodes[node.name]
	return def and def.walkable == true or false
end

local function cooldown(self, seconds)
	return seconds * (self._grug_enraged and TUNING.enrage_cooldown_factor or 1)
end

local function burst(pos, amount, texture, glow, radius, height, time)
	radius = radius or 3
	height = height or 4
	core.add_particlespawner({
		amount = amount,
		time = time or 0.5,
		pos = {min = {x = pos.x - radius, y = pos.y, z = pos.z - radius},
			max = {x = pos.x + radius, y = pos.y + height, z = pos.z + radius}},
		vel = {min = {x = -3, y = 0.5, z = -3},
			max = {x = 3, y = 5, z = 3}},
		exptime = {min = 0.4, max = 1.6},
		size = {min = 2, max = 6},
		texture = texture,
		glow = glow or 0,
	})
end

local function shoot_breath(self, action, opts)
	local from = self.object and self.object:get_pos()
	local to = action.snapshot
	if not from or not to then return end
	from = {x = from.x, y = from.y + opts.eye_height, z = from.z}
	to = {x = to.x, y = to.y + 1, z = to.z}
	for _, degrees in ipairs({-15, 0, 15}) do
		local angle = degrees * math.pi / 180
		local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
		local c, s = math.cos(angle), math.sin(angle)
		dx, dz = dx * c - dz * s, dx * s + dz * c
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		if length > 0 then
			local object = core.add_entity(from, opts.arrow)
			local ent = object and object:get_luaentity()
			if ent then
				ent._grug_damage = self.damage
				ent._grug_source = self.object
				ent._grug_actor_name = action.actor_name
				ent._grug_effect = opts.effect
				ent.owner_id = tostring(self.object)
				object:set_velocity({x = dx * 22 / length,
					y = dy * 22 / length, z = dz * 22 / length})
			end
		end
	end
	burst(from, 54, opts.effect == "rime" and
		"default_snow.png^[colorize:#8ee8ff:120" or
		"default_item_smoke.png^[colorize:#ff7338:210", 10, 2, 3, 0.35)
end

local function lightning_ring(pos)
	for index = 0, 31 do
		local angle = index * math.pi * 2 / 32
		core.add_particle({
			pos = {x = pos.x + math.cos(angle) * 2, y = pos.y + 0.1,
				z = pos.z + math.sin(angle) * 2},
			velocity = {x = 0, y = 0, z = 0},
			expirationtime = TUNING.lightning_windup,
			size = 3,
			texture = "grug_mobs_rock.png^[colorize:#fff27a:230",
			glow = 12,
		})
	end
end

local function lightning_impact(self, snapshot)
	for _, player in ipairs(hostile_players(snapshot, 2)) do
		local pos = player:get_pos()
		local _, horizontal = distance(snapshot, pos)
		if horizontal <= 2 then
			player:punch(self.object, 1, {full_punch_interval = 1,
				damage_groups = {fleshy = self.damage * 2}}, nil)
		end
	end
	burst(snapshot, 96, "grug_mobs_rock.png^[colorize:#fff27a:230", 14,
		2, 8, 0.25)
end

local function slam_knockback(player, origin)
	local target = player:get_pos()
	local dx, dz = target.x - origin.x, target.z - origin.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length > 0 then
		player:add_velocity({x = dx * 7 / length, y = 7 * 0.4,
			z = dz * 7 / length})
	end
end

local function gust(self)
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	for _, player in ipairs(hostile_players(pos, TUNING.gust_radius)) do
		slam_knockback(player, pos)
		grug_mobs.slow_player(player, TUNING.gust_slow, 0.6)
	end
	burst(pos, 96, "default_item_smoke.png^[colorize:#d8eef4:150", 3,
		5, 3, 0.4)
end

local function remove_whelps(self)
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	for _, object in ipairs(core.get_objects_inside_radius(pos, 160)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_boss_summon == self._grug_boss_id then
			object:remove()
		end
	end
end
grug_mobs.remove_dragon_whelps = remove_whelps

local function spawn_whelps(self, opts)
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	local count = 0
	for _, object in ipairs(core.get_objects_inside_radius(pos, 120)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_boss_summon == self._grug_boss_id then
			count = count + 1
		end
	end
	for index = count + 1, 2 do
		local side = index == 1 and -1 or 1
		local object = core.add_entity({x = pos.x + side * 5, y = pos.y + 1,
			z = pos.z + 2}, opts.whelp)
		local ent = object and object:get_luaentity()
		if ent then ent._grug_boss_summon = self._grug_boss_id end
	end
end

local function enrage(self, state, opts)
	if self._grug_enraged or not self.hp_max or self.hp_max <= 0 or
			(self.health or self.hp_max) > self.hp_max * TUNING.enrage_fraction then
		return
	end
	self._grug_enraged = true
	state.primary = (state.primary or 0) * TUNING.enrage_cooldown_factor
	state.gust = (state.gust or 0) * TUNING.enrage_cooldown_factor
	self.object:set_properties({glow = 8})
	local pos = self.object:get_pos()
	for _, player in ipairs(core.get_connected_players()) do
		local p = player:get_pos()
		if p and distance(pos, p) <= TUNING.view then
			core.chat_send_player(player:get_player_name(),
				opts.description .. " roars and becomes enraged!")
		end
	end
	burst(pos, 180, "default_item_smoke.png^[colorize:#ff341f:210", 12,
		7, 10, 0.8)
	spawn_whelps(self, opts)
end

local function begin_action(self, state, kind, target, target_pos, left)
	state.action = {
		kind = kind,
		target = target,
		snapshot = {x = target_pos.x, y = target_pos.y, z = target_pos.z},
		actor_name = target:get_player_name(),
		left = left,
	}
	stop_object(self)
	if self.set_animation then
		self:set_animation(kind == "breath" and "shoot" or "punch", true)
	end
end

local function begin_lightning(self, state, target, target_pos)
	begin_action(self, state, "lightning", target, target_pos,
		TUNING.lightning_windup)
	lightning_ring(target_pos)
end

local function begin_dive(self, state, target, target_pos)
	begin_action(self, state, "dive_warn", target, target_pos,
		TUNING.dive_windup)
	set_flight(self, true)
	local pos = self.object:get_pos()
	burst(pos, 80, "default_item_smoke.png^[colorize:#ffd24a:190", 10,
		5, 4, TUNING.dive_windup)
end

local function finish_dive(self, state)
	local pos = self.object and self.object:get_pos()
	if pos then
		for _, player in ipairs(hostile_players(pos, 7)) do
			player:punch(self.object, 1, {full_punch_interval = 1,
				damage_groups = {fleshy = self.damage * 3}}, nil)
			slam_knockback(player, pos)
		end
		burst(pos, 120, "default_item_smoke.png^[colorize:#ffd24a:190", 8,
			7, 5, 0.3)
	end
	state.action = nil
	state.mode = "landing"
	state.primary = cooldown(self, TUNING.dive_cooldown)
	set_flight(self, false)
end

local function cancel_action(self, state)
	state.action = nil
	state.mode = "landing"
	stop_object(self)
	set_flight(self, false)
end

function grug_mobs.cancel_dragon_action(self)
	local state = self and self.temp and self.temp.grug_dragon
	if state then cancel_action(self, state) end
	if self then
		self._grug_enraged = nil
		if self.object then self.object:set_properties({glow = 0}) end
		remove_whelps(self)
	end
end

local function tick_action(self, state, dtime, moveresult, opts)
	local action = state.action
	if not action then return false end
	if self.attack ~= action.target then
		cancel_action(self, state)
		return true
	end
	local target_pos = valid_target(self, action.target)
	if not target_pos then
		cancel_action(self, state)
		return true
	end
	if action.kind == "dive" then
		action.left = action.left - dtime
		local pos = self.object:get_pos()
		local dist = distance(pos, action.snapshot)
		if (moveresult and moveresult.collides) or dist <= 2.5 or action.left <= 0 then
			finish_dive(self, state)
		end
		return true
	end
	stop_object(self)
	action.left = action.left - dtime
	if action.left > 0 then return true end
	if action.kind == "dive_warn" then
		action.kind = "dive"
		action.left = 2.5
		set_flight(self, true)
		steer(self, action.snapshot, TUNING.dive, TUNING.run)
	elseif action.kind == "breath" then
		shoot_breath(self, action, opts)
		state.action = nil
		state.primary = cooldown(self, TUNING.breath_cooldown)
	elseif action.kind == "lightning" then
		lightning_impact(self, action.snapshot)
		state.action = nil
		state.primary = cooldown(self, TUNING.lightning_cooldown)
	end
	return true
end

local function start_primary(self, state, target, target_pos, opts, airborne)
	if airborne then
		begin_dive(self, state, target, target_pos)
	elseif opts.lightning and state.lightning_next then
		state.lightning_next = false
		begin_lightning(self, state, target, target_pos)
	else
		state.lightning_next = opts.lightning and true or false
		begin_action(self, state, "breath", target, target_pos,
			TUNING.breath_windup)
	end
end

local function perch_tick(self, state, dtime, moveresult)
	state.acquire = (state.acquire or 0) + dtime
	if state.acquire >= 1 then
		state.acquire = 0
		-- do_custom owns every targetless rest/walk step and therefore bypasses
		-- mobs_redo's later acquisition pass. Reuse that same bounded method
		-- before any rest-route early return.
		if self.general_attack then self:general_attack() end
		if self.attack then return false end
	end
	local destination = state.rest_destination
	if destination then
		local pos = self.object and self.object:get_pos()
		if not pos then return false end
		local _, horizontal = distance(pos, destination)
		if horizontal <= 1.5 then
			stop_object(self)
			state.rest_destination = nil
			state.perch = 0
			if self.set_animation then self:set_animation("stand", true) end
			return false
		end
		-- A blocked route is not repaired with a teleport. Rest in place and let
		-- the ordinary cadence choose another authored destination.
		local blocked = false
		for _, collision in ipairs(moveresult and moveresult.collisions or {}) do
			if collision.axis == "x" or collision.axis == "z" then
				blocked = true
				break
			end
		end
		if blocked or self.at_cliff then
			stop_object(self)
			state.rest_destination = nil
			state.perch = 0
			return false
		end
		if self.yaw_to_pos then self:yaw_to_pos(destination, 0, 4) end
		self:set_velocity(self.walk_velocity)
		if self.set_animation then self:set_animation("walk", true) end
		return false
	end
	state.perch = (state.perch or 0) + dtime
	if state.perch < 15 or not self._grug_perches or #self._grug_perches < 2 then
		stop_object(self)
		return false
	end
	state.perch = 0
	state.perch_index = (state.perch_index or 1) % #self._grug_perches + 1
	state.rest_destination = self._grug_perches[state.perch_index]
	return false
end

local function dragon_tick(self, dtime, moveresult, opts)
	self.temp = self.temp or {}
	local state = self.temp.grug_dragon
	if not state then
		state = {mode = self.fly and "air" or "ground", primary = 2,
			gust = TUNING.gust_cooldown}
		self.temp.grug_dragon = state
	end
	self._grug_chase_range = TUNING.leash + 4
	if self._grug_enraged then self.object:set_properties({glow = 8}) end
	enrage(self, state, opts)
	state.primary = math.max(0, (state.primary or 0) - dtime)
	state.gust = math.max(0, (state.gust or 0) - dtime)
	if tick_action(self, state, dtime, moveresult, opts) then return false end

	local target = self.attack
	local target_pos, horizontal = valid_target(self, target)
	if not target_pos then
		if target and self.stop_attack then self:stop_attack() end
		if state.mode ~= "ground" then
			set_flight(self, false)
			if grounded(self, moveresult) then
				state.mode = "ground"
				if self.set_animation then self:set_animation("stand", true) end
			else
				state.mode = "landing"
			end
			return false
		end
		return perch_tick(self, state, dtime, moveresult)
	end
	state.perch = 0
	state.rest_destination = nil
	if state.gust <= 0 then
		gust(self)
		state.gust = cooldown(self, TUNING.gust_cooldown)
	end
	if state.mode == "landing" then
		set_flight(self, false)
		if grounded(self, moveresult) then
			state.mode = "ground"
			if self.set_animation then self:set_animation("stand", true) end
			return
		end
		return false
	end
	if state.mode == "ground" then
		set_flight(self, false)
		local pos = self.object:get_pos()
		local visible = core.line_of_sight(
			{x = pos.x, y = pos.y + opts.eye_height, z = pos.z},
			{x = target_pos.x, y = target_pos.y + 1, z = target_pos.z})
		if horizontal > TUNING.takeoff_distance or not visible then
			state.mode = "air"
			set_flight(self, true)
			burst(pos, 48, "default_item_smoke.png^[colorize:#d8eef4:130", 3,
				4, 3, 0.4)
			steer(self, {x = target_pos.x, y = target_pos.y + 6,
				z = target_pos.z}, TUNING.fly, TUNING.run)
			return false
		end
		if state.primary <= 0 then
			start_primary(self, state, target, target_pos, opts, false)
			return false
		end
		return
	end
	set_flight(self, true)
	if state.primary <= 0 and horizontal <= 18 then
		start_primary(self, state, target, target_pos, opts, true)
		return false
	end
	if horizontal <= TUNING.landing_distance then
		state.mode = "landing"
		set_flight(self, false)
		return false
	end
	steer(self, {x = target_pos.x, y = target_pos.y + 6, z = target_pos.z},
		TUNING.fly, TUNING.run)
	return false
end

local function whelp_tick(self, dtime, moveresult)
	self.temp = self.temp or {}
	local state = self.temp.grug_whelp
	if not state then
		state = {mode = self.fly and "air" or "ground"}
		self.temp.grug_whelp = state
	end
	local target_pos, horizontal = valid_target(self, self.attack)
	if not target_pos then
		if state.mode ~= "ground" then
			state.mode = "landing"
			set_flight(self, false)
			return false
		end
		return
	end
	if state.mode == "landing" then
		set_flight(self, false)
		if grounded(self, moveresult) then state.mode = "ground" return end
		return false
	end
	if state.mode == "ground" and horizontal > TUNING.takeoff_distance then
		state.mode = "air"
		set_flight(self, true)
	end
	if state.mode == "air" then
		if horizontal <= TUNING.landing_distance then
			state.mode = "landing"
			set_flight(self, false)
		else
			steer(self, {x = target_pos.x, y = target_pos.y + 3,
				z = target_pos.z}, TUNING.whelp_fly, TUNING.run)
		end
		return false
	end
end

local function whelp_def(opts)
	return {
		description = opts.description .. " Whelp",
		clock = "any", type = "monster",
		_grug_fixed_level = TUNING.whelp_level, _grug_tier = "normal",
		attack_type = "dogfight", attack_players = true,
		attack_monsters = false, attack_animals = false, attack_npcs = false,
		pathfinding = 1, reach = 3, group_attack = false,
		walk_velocity = TUNING.walk, run_velocity = TUNING.run,
		fly = false, fly_in = "air", keep_flying = true,
		jump = true, jump_height = 4, stepheight = 1.1, fear_height = 0,
		view_range = TUNING.view,
		visual = "mesh", mesh = opts.mesh, textures = {opts.textures},
		visual_size = opts.whelp_size, collisionbox = opts.whelp_box,
		makes_footstep_sound = true, fall_damage = false,
		animation = opts.animation,
		drops = {}, water_damage = 0, lava_damage = 0, light_damage = 0,
		do_custom = whelp_tick,
	}
end

local function dragon_def(id, opts, callbacks)
	return {
		description = opts.description,
		clock = "any", type = "monster",
		_grug_fixed_level = 60, _grug_tier = "boss",
		_grug_leash_range = TUNING.leash,
		attack_type = "dogfight", attack_players = true,
		attack_monsters = false, attack_animals = false, attack_npcs = false,
		pathfinding = 1, reach = 6, group_attack = false,
		walk_velocity = TUNING.walk, run_velocity = TUNING.run,
		fly = false, fly_in = "air", keep_flying = true,
		jump = true, jump_height = 4, stepheight = 1.1, fear_height = 0,
		view_range = TUNING.view,
		visual = "mesh", mesh = opts.mesh, textures = {opts.textures},
		visual_size = opts.size, collisionbox = opts.box,
		makes_footstep_sound = true, fall_damage = false,
		animation = opts.animation,
		drops = {}, water_damage = 0, lava_damage = 0, light_damage = 0,
		after_activate = function(self)
			self._grug_boss_id = "dragon:" .. id
			callbacks.storage:set_string("boss:dragon:" .. id .. ":alive", "1")
		end,
		do_custom = function(self, dtime, moveresult)
			self._grug_boss_id = "dragon:" .. id
			return dragon_tick(self, dtime, moveresult, opts)
		end,
		on_die = function(self)
			remove_whelps(self)
			callbacks.settle("dragon:" .. id, self, nil)
			callbacks.storage:set_string("boss:dragon:" .. id .. ":alive", "")
			callbacks.storage:set_string("boss:dragon:" .. id .. ":due",
				tostring(os.time() + callbacks.respawn))
			callbacks.storage:set_string("boss:dragon:" .. id .. ":warned", "")
		end,
	}
end

function grug_mobs.register_dragon_bosses(callbacks)
	hostile_player = function(player)
		return player and core.is_player(player) and player:get_hp() > 0 and
			not core.check_player_privs(player:get_player_name(), "peaceful_player") and
			callbacks.player_enemy_of(player, nil)
	end
	local ice = {
		description = "Wyrmglass Ice Dragon",
		mesh = "grug_mobs_ice_dragon.b3d",
		textures = {"grug_mobs_ice_dragon.png^grug_mobs_dragon_shading.png"},
		size = {x = 8, y = 8}, box = {-3, 0, -3, 3, 8, 3},
		whelp_size = {x = 2.66, y = 2.66},
		whelp_box = {-1, 0, -1, 1, 2.66, 1},
		arrow = "grug_mobs:ice_breath", effect = "rime",
		whelp = "grug_mobs:ice_whelp", eye_height = 5,
		animation = {
			stand_start = 1, stand_end = 59, stand_speed = 20,
			walk_start = 211, walk_end = 249, walk_speed = 20,
			run_start = 211, run_end = 249, run_speed = 30,
			fly_start = 161, fly_end = 209, fly_speed = 30,
			punch_start = 121, punch_end = 159, punch_speed = 20,
			shoot_start = 61, shoot_end = 119, shoot_speed = 20,
			die_start = 571, die_end = 579, die_speed = 20,
		},
	}
	local storm = {
		description = "Stormscale Jungle Wyvern",
		mesh = "grug_mobs_jungle_wyvern.b3d",
		textures = {"grug_mobs_jungle_wyvern.png"},
		size = {x = 8, y = 8}, box = {-2.4, 0, -2.4, 2.4, 6.4, 2.4},
		whelp_size = {x = 2.66, y = 2.66},
		whelp_box = {-0.8, 0, -0.8, 0.8, 2.13, 0.8},
		arrow = "grug_mobs:storm_breath", effect = "scorch",
		whelp = "grug_mobs:storm_whelp", eye_height = 4,
		lightning = true,
		animation = {
			stand_start = 1, stand_end = 59, stand_speed = 20,
			walk_start = 91, walk_end = 119, walk_speed = 20,
			run_start = 181, run_end = 209, run_speed = 30,
			fly_start = 121, fly_end = 179, fly_speed = 30,
			punch_start = 61, punch_end = 89, punch_speed = 20,
			shoot_start = 241, shoot_end = 279, shoot_speed = 20,
			die_start = 281, die_end = 299, die_speed = 20,
		},
	}
	grug_mobs.register_mob("grug_mobs:ice_whelp", whelp_def(ice))
	grug_mobs.register_mob("grug_mobs:storm_whelp", whelp_def(storm))
	grug_mobs.register_mob("grug_mobs:ice_dragon",
		dragon_def("wyrmglass", ice, callbacks))
	grug_mobs.register_mob("grug_mobs:jungle_wyvern",
		dragon_def("stormscale", storm, callbacks))
end
