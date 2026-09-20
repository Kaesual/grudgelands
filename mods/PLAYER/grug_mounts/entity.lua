local ENTITY_NAME = "grug_mounts:mount"
local VISUAL_NAME = "grug_mounts:mount_visual"
local STATUS_ID = "mount"
local WARNING_INTERVAL = 1
local WARNING_DISTANCES = {1, 2, 4, 8, 16, 32, 48}
local WARNING_DIRECTIONS = {}
for index = 0, 15 do
	local angle = index * math.pi / 8
	WARNING_DIRECTIONS[#WARNING_DIRECTIONS + 1] = {
		x = math.cos(angle), z = math.sin(angle),
	}
end
local active = {}
local activating_players = {}

grug_mounts.active = active

local function valid_player(player)
	return player and player.is_player and player:is_player()
end

function grug_mounts.is_mounted(player)
	return valid_player(player) and active[player:get_player_name()] ~= nil
end

local function position_node(pos)
	return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5)}
end

local function zero_player_velocity(player)
	local velocity = player:get_velocity()
	if velocity then
		player:add_velocity({x = -velocity.x, y = -velocity.y, z = -velocity.z})
	end
end

local function free_dismount_pos(pos)
	local offsets = {
		{x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0},
		{x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1},
		{x = 1, y = 1, z = 0}, {x = -1, y = 1, z = 0},
		{x = 0, y = 1, z = 1}, {x = 0, y = 1, z = -1},
	}
	for _, offset in ipairs(offsets) do
		local candidate = vector.add(pos, offset)
		local node = core.get_node_or_nil(position_node(candidate))
		local definition = node and core.registered_nodes[node.name]
		if definition and not definition.walkable and definition.liquidtype == "none" then
			candidate.y = candidate.y + 0.5
			return candidate
		end
	end
	return pos
end

local function remove_warning(player, record)
	if record and record.hud_id and valid_player(player) then
		player:hud_remove(record.hud_id)
	end
	if record then
		record.hud_id = nil
		record.warning_kind = nil
	end
end

local function restore_player(player, skip_animation)
	local name = player:get_player_name()
	player_api.player_attached[name] = false
	player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
	if not skip_animation then
		player_api.set_animation(player, "stand", 30)
	end
	if core.global_exists("grug_visuals") then
		grug_visuals.apply(player)
	else
		player:set_properties({visual_size = {x = 1, y = 1}})
	end
end

function grug_mounts.dismount(player, reason, hard, skip_animation)
	if not valid_player(player) then return false end
	local name = player:get_player_name()
	local record = active[name]
	if not record then return false end
	local object = record.object
	local pos = object and object:is_valid() and object:get_pos() or player:get_pos()
	active[name] = nil
	grug_core.clear_status(player, STATUS_ID)
	remove_warning(player, record)
	if object and object:is_valid() then
		local entity = object:get_luaentity()
		if entity then
			entity._grug_removing = true
			entity.driver = nil
			entity._grug_rider = nil
		end
	end
	player:set_detach()
	restore_player(player, skip_animation)
	if hard then
		if pos then player:set_pos(pos) end
		zero_player_velocity(player)
		core.after(0, function(player_name)
			local current = core.get_player_by_name(player_name)
			if current then zero_player_velocity(current) end
		end, name)
	elseif pos then
		player:set_pos(free_dismount_pos(pos))
	end
	if object and object:is_valid() then object:remove() end
	if record.visual and record.visual:is_valid() then record.visual:remove() end
	if reason and reason ~= "manual" then
		core.chat_send_player(name, reason)
	end
	return true
end

function grug_mounts.flight_state(player, pos)
	local water = grug_zones.water_class_at(pos.x, pos.z)
	if water ~= "land" and water ~= "planned_water" then
		return false, "ocean"
	end
	local faction = grug_factions.get_faction(player)
	if faction ~= "accord" and faction ~= "throng" then
		return false, "enemy"
	end
	-- Zone ownership is horizontal.  Altitude is handled independently by the
	-- underground takeoff and y=600 ceiling rules below.
	local zone = grug_zones.at(pos)
	local territory = zone and zone.territory_rule
	if territory == "holy_grounds" or territory == faction .. "_home" then
		return true, nil
	end
	return false, "enemy"
end

function grug_mounts.warning_state(player, pos)
	local sample = {x = pos.x, y = pos.y, z = pos.z}
	for _, distance in ipairs(WARNING_DISTANCES) do
		for _, direction in ipairs(WARNING_DIRECTIONS) do
			sample.x = pos.x + direction.x * distance
			sample.z = pos.z + direction.z * distance
			local legal, kind = grug_mounts.flight_state(player, sample)
			if not legal then return kind end
		end
	end
	return nil
end

local function warning_text(kind)
	if kind == "ocean" then
		return "Flight boundary: ocean within 48 nodes"
	end
	return "Flight boundary: restricted territory within 48 nodes"
end

local function update_warning(player, record, kind)
	if not kind then
		remove_warning(player, record)
		return
	end
	local text = warning_text(kind)
	if not record.hud_id then
		record.hud_id = player:hud_add({
			hud_elem_type = "text",
			position = {x = 0.5, y = 0.14},
			offset = {x = 0, y = 0},
			alignment = {x = 0, y = 0},
			number = 0xffbf35,
			text = text,
			z_index = 80,
		})
	elseif record.warning_kind ~= kind then
		player:hud_change(record.hud_id, "text", text)
	end
	if record.warning_kind ~= kind then
		core.chat_send_player(player:get_player_name(), text .. ". Crossing dismounts immediately.")
	end
	record.warning_kind = kind
end

local function set_animation(self, name)
	if self._grug_animation == name then return end
	local clip = self._grug_model.animation[name]
	local record = active[self._grug_owner]
	local visual = record and record.visual
	if visual and visual:is_valid() then
		visual:set_animation({x = clip[1], y = clip[2]}, clip[3], 0, true)
	end
	self._grug_animation = name
end

local function angle_delta(a, b)
	local delta = (a - b) % (math.pi * 2)
	if delta > math.pi then delta = delta - math.pi * 2 end
	return delta
end

-- The physical controller owns translation only. A player attached with zero
-- relative rotation keeps a stale rendered body yaw on the client even though
-- controller velocity already follows the camera. Put the requested yaw on the
-- rider attachment itself; the visible mount is the rider's child so both turn
-- together, while that child remains automatically hidden in first person.
local function orient_rider(self, player, yaw)
	if self._grug_attach_yaw and
			math.abs(angle_delta(yaw, self._grug_attach_yaw)) < math.rad(0.5) then
		return
	end
	local model = self._grug_model
	local seat = model.attach_y * model.visual_size.y
	-- Free CAO yaw is negated by content_cao before scene rotation; attachment
	-- rotation is applied directly, so matching the same visible yaw needs -deg.
	player:set_attach(self.object, "", {x = 0, y = seat, z = 0},
		{x = 0, y = -math.deg(yaw), z = 0})
	self._grug_attach_yaw = yaw
end

local function land_step(self, control, yaw, dtime)
	local tier = grug_mounts.TIERS[self._grug_tier]
	local velocity = self.object:get_velocity() or {x = 0, y = 0, z = 0}
	local direction = 0
	if control.up then direction = 1 elseif control.down then direction = -0.35 end
	local target = tier.speed * direction
	local rate = tier.speed * 5 * dtime
	local horizontal = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
	local signed = horizontal
	if direction < 0 then signed = -horizontal end
	if signed < target then signed = math.min(target, signed + rate)
	elseif signed > target then signed = math.max(target, signed - rate) end
	if direction == 0 then signed = 0 end
	local y_velocity = velocity.y
	if control.jump and math.abs(y_velocity) < 0.05 then
		local pos = self.object:get_pos()
		local foot = pos and position_node({x = pos.x,
			y = pos.y + self._grug_model.collisionbox[2] - 0.1, z = pos.z})
		local node = foot and core.get_node_or_nil(foot)
		local definition = node and core.registered_nodes[node.name]
		if definition and definition.walkable then y_velocity = 6.5 end
	end
	self.object:set_yaw(0)
	self.object:set_velocity({x = -math.sin(yaw) * signed, y = y_velocity,
		z = math.cos(yaw) * signed})
	self.object:set_acceleration({x = 0, y = -9.81, z = 0})
	set_animation(self, direction == 0 and "stand" or "move")
end

local function flight_step(self, control, yaw)
	local tier = grug_mounts.TIERS[self._grug_tier]
	local direction = 0
	if control.up then direction = 1 elseif control.down then direction = -0.35 end
	local vertical = 0
	if control.jump then vertical = tier.speed * 0.6
	elseif control.sneak then vertical = -tier.speed * 0.6 end
	local pos = self.object:get_pos()
	if pos.y >= grug_mounts.FLIGHT_CEILING and vertical > 0 then vertical = 0 end
	if pos.y > grug_mounts.FLIGHT_CEILING then
		pos.y = grug_mounts.FLIGHT_CEILING
		self.object:set_pos(pos)
	end
	self.object:set_yaw(0)
	self.object:set_acceleration({x = 0, y = 0, z = 0})
	self.object:set_velocity({x = -math.sin(yaw) * tier.speed * direction,
		y = vertical, z = math.cos(yaw) * tier.speed * direction})
	set_animation(self, direction == 0 and vertical == 0 and "stand" or "move")
end

local entity_definition = {
	initial_properties = {
		physical = true,
		collide_with_objects = false,
		pointable = true,
		visual = "sprite",
		textures = {"grug_mobs_blank.png"},
		-- Attachment children inherit the parent's visual transform. Keep the
		-- invisible controller at neutral scale so the rider is never shrunk.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.7, -0.01, -0.7, 0.7, 1.59, 0.7},
		selectionbox = {-0.7, -0.01, -0.7, 0.7, 3.06, 0.7},
		static_save = false,
		hp_max = 100000,
	},

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "")
		if type(data) ~= "table" or type(data.owner) ~= "string" or
				type(data.tier) ~= "number" then
			self.object:remove()
			return
		end
		local tier = grug_mounts.TIERS[data.tier]
		local player = core.get_player_by_name(data.owner) or activating_players[data.owner]
		local model = valid_player(player) and grug_mounts.model_for(player, data.tier)
		if not tier or not model then self.object:remove() return end
		self._grug_owner = data.owner
		self._grug_tier = data.tier
		self._grug_model = model
		self.object:set_armor_groups({immortal = 1})
		self.object:set_properties({
			collisionbox = model.collisionbox,
			selectionbox = model.selectionbox,
			stepheight = tier.mode == "land" and 1.01 or 0,
		})
	end,

	get_staticdata = function()
		return ""
	end,

	on_step = function(self, dtime)
		local player = self.driver
		if not valid_player(player) then
			if not self._grug_removing then self.object:remove() end
			return
		end
		if player:get_attach() ~= self.object then
			local record = active[self._grug_owner]
			if record and record.object == self.object then
				grug_mounts.dismount(player, nil, true)
			elseif not self._grug_removing then
				self.object:remove()
			end
			return
		end
		local record = active[self._grug_owner]
		if not record or record.object ~= self.object then self.object:remove() return end
		local pos = self.object:get_pos()
		local tier = grug_mounts.TIERS[self._grug_tier]
		if tier.mode == "flight" then
			local legal = grug_mounts.flight_state(player, pos)
			if not legal then
				grug_mounts.dismount(player,
					"You crossed the flight boundary and were dismounted.", true)
				return
			end
			record.warning_elapsed = (record.warning_elapsed or 0) + dtime
			if record.warning_elapsed >= WARNING_INTERVAL then
				record.warning_elapsed = 0
				update_warning(player, record, grug_mounts.warning_state(player, pos))
			end
		end
		local control = player:get_player_control()
		local yaw = player:get_look_horizontal() or self.object:get_yaw() or 0
		orient_rider(self, player, yaw)
		if tier.mode == "flight" then flight_step(self, control, yaw)
		else land_step(self, control, yaw, dtime) end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		local player = self._grug_rider
		if valid_player(player) and player:get_attach() == self.object then
			local wear = player:punch(puncher, time_from_last_punch,
				tool_capabilities, dir)
			-- PlayerRef:punch returns the wear earned by this nested hit. Re-fetch
			-- after the call because callbacks may have changed the wielded stack.
			if type(wear) == "number" and wear > 0 and valid_player(puncher) then
				local stack = puncher:get_wielded_item()
				if stack and not stack:is_empty() then
					stack:add_wear(wear)
					puncher:set_wielded_item(stack)
				end
			end
		end
	end,

	on_death = function(self)
		local player = self.driver
		if valid_player(player) then grug_mounts.dismount(player, nil, false) end
	end,

	on_rightclick = function(self, clicker)
		if clicker == self.driver then grug_mounts.dismount(clicker, "manual", false) end
	end,

	on_deactivate = function(self)
		if self._grug_removing then return end
		local player = self.driver
		if valid_player(player) then grug_mounts.dismount(player, nil, false) end
	end,
}

core.register_entity(ENTITY_NAME, entity_definition)
grug_mounts.entity_definition = entity_definition

local visual_definition = {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		visual = "mesh", mesh = "grug_mounts_horse.b3d",
		textures = {"grug_mobs_blank.png"},
	},
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "")
		local player = type(data) == "table" and
			core.get_player_by_name(data.owner or "")
		local model = valid_player(player) and grug_mounts.model_for(player, data.tier)
		if not model then self.object:remove() return end
		local rider_size = (player:get_properties() or {}).visual_size or {x = 1, y = 1}
		local seat = model.attach_y * model.visual_size.y
		self.object:set_properties({mesh = model.mesh, textures = model.textures,
			visual_size = {x = model.visual_size.x / rider_size.x,
				y = model.visual_size.y / rider_size.y}})
		self.object:set_attach(player, "", {x = 0, y = -seat / rider_size.y, z = 0},
			{x = 0, y = 0, z = 0}, false)
	end,
	get_staticdata = function() return "" end,
}
core.register_entity(VISUAL_NAME, visual_definition)
grug_mounts.visual_definition = visual_definition

local function attach(player, object, model, skip_animation)
	local name = player:get_player_name()
	player_api.player_attached[name] = true
	local seat = model.attach_y * model.visual_size.y
	player:set_attach(object, "", {x = 0, y = seat, z = 0},
		{x = 0, y = -math.deg(player:get_look_horizontal() or 0), z = 0})
	player:set_eye_offset({x = 0, y = model.eye_y, z = 0}, {x = 0, y = 0, z = 0})
	if not skip_animation then player_api.set_animation(player, "sit", 30) end
end

function grug_mounts.spawn_entity(player, tier_id, pos, skip_animation)
	local tier = grug_mounts.TIERS[tier_id]
	local model = grug_mounts.model_for(player, tier_id)
	if not tier or not model then return false, "Mount appearance is unavailable." end
	local name = player:get_player_name()
	activating_players[name] = player
	local object = core.add_entity(pos, ENTITY_NAME,
		core.serialize({owner = name, tier = tier_id}))
	activating_players[name] = nil
	if not object then return false, "The mount could not be summoned here." end
	local entity = object:get_luaentity()
	if not entity then object:remove() return false, "The mount failed to activate." end
	entity.driver = player
	entity._grug_rider = player
	active[name] = {object = object, tier = tier_id, flying = tier.mode == "flight",
		model = model}
	attach(player, object, model, skip_animation)
	local visual = core.add_entity(pos, VISUAL_NAME,
		core.serialize({owner = name, tier = tier_id}))
	if not visual then
		grug_mounts.dismount(player, nil, false)
		return false, "The mount appearance failed to activate."
	end
	active[name].visual = visual
	set_animation(entity, "stand")
	local bonus = math.floor((tier.speed / 4 - 1) * 100 + 0.5)
	grug_core.set_status(player, STATUS_ID, {
		label = ("T%d Mount, +%d%% Speed"):format(tier_id, bonus),
		kind = "buff", untimed = true,
	})
	return true
end

function grug_mounts.mount(player, tier_id)
	if grug_core.in_combat(player) then return false, "You cannot mount while in combat." end
	local tier = grug_mounts.TIERS[tier_id]
	local pos = player:get_pos()
	if not tier or not pos then return false, "The mount cannot be summoned." end
	if tier.mode == "flight" then
		local legal = grug_mounts.flight_state(player, pos)
		if not legal then return false, "Flying mounts are forbidden here." end
		local surface = grug_zones.terrain_height_at(pos.x, pos.z)
		if type(surface) ~= "number" or pos.y < surface then
			return false, "Flying mounts cannot take off underground."
		end
		if pos.y > grug_mounts.FLIGHT_CEILING then
			return false, "The flight ceiling is y = 600."
		end
	end
	return grug_mounts.spawn_entity(player, tier_id, pos)
end

function grug_mounts.toggle(player, tier_id)
	if active[player:get_player_name()] then
		return grug_mounts.dismount(player, "manual", false)
	end
	local ok, message = grug_mounts.mount(player, tier_id)
	if not ok and message then core.chat_send_player(player:get_player_name(), message) end
	return ok, message
end

core.register_on_player_hpchange(function(player, hp_change)
	if hp_change < 0 and active[player:get_player_name()] then
		grug_mounts.dismount(player, nil, false)
	end
end, false)

core.register_on_dieplayer(function(player)
	grug_mounts.dismount(player, nil, true)
end)

core.register_on_leaveplayer(function(player)
	grug_mounts.dismount(player, nil, true)
end)

core.register_on_shutdown(function()
	local names = {}
	for name in pairs(active) do names[#names + 1] = name end
	for _, name in ipairs(names) do
		local player = core.get_player_by_name(name)
		if player then grug_mounts.dismount(player, nil, true) end
	end
end)

grug_classes.register_on_race_chosen(function(player)
	if active[player:get_player_name()] then grug_mounts.dismount(player, nil, true) end
end)

grug_factions.register_on_faction_chosen(function(player)
	if active[player:get_player_name()] then grug_mounts.dismount(player, nil, true) end
end)
