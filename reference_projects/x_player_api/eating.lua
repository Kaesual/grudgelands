-- x_player_api eating animation and particle effects module
-- Handles eating triggers, consumable registry, particle spawner creation, and item_eat callbacks.

---@class ConsumableDefinition
---@field action? string Action animation name (e.g. "eat", "drink", defaults to "eat")
---@field duration? number Action duration in seconds (defaults to 1.2)
---@field particle_type? string Particle generator identifier ("crumbs", "liquid_drops", "none")
---@field sound? string Sound name to play upon consumption

---@alias ParticleGeneratorFunc fun(player: ObjectRef, item_name: string?, duration: number?): integer?

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

local enable_eating = core.settings:get_bool("x_player_api.enable_eating", true)

---Whether eating animations, sounds, and particle simulations are enabled
---@type boolean
x_player_api.enable_eating = enable_eating

---Set whether eating animations, sounds, and particle simulations are enabled
---@param enabled boolean Whether eating simulation should be active
function x_player_api.set_eating_enabled(enabled)
	x_player_api.enable_eating = (enabled == true)
end

---@type table<string, ConsumableDefinition>
x_player_api.registered_consumables = x_player_api.registered_consumables or {}

---@type table<string, ParticleGeneratorFunc>
x_player_api.registered_particle_generators = x_player_api.registered_particle_generators or {}

---@type table<string, ConsumableDefinition>
local consumables = x_player_api.registered_consumables
---@type table<string, ParticleGeneratorFunc>
local generators = x_player_api.registered_particle_generators

local GRAVITY_ACC = {x = 0, y = -9.81, z = 0}

---Calculate mouth 3D position projected forward along player gaze
---@nodiscard
---@param player ObjectRef Target player
---@return Vector3|nil center Mouth center coordinates
---@return number dir_x Normalized look direction X
---@return number dir_z Normalized look direction Z
function x_player_api.get_mouth_position(player)
	local pos = player:get_pos()
	if not pos then
		return nil, 0, 0
	end

	local yaw = player:get_look_horizontal() or 0
	local dir_x = -math.sin(yaw)
	local dir_z = math.cos(yaw)

	local props = player:get_properties()
	local eye_height = (props and props.eye_height) or 1.47
	local mouth_y = pos.y + eye_height - 0.15
	local forward_dist = 0.28
	local mouth_center = vector.new(
		pos.x + dir_x * forward_dist,
		mouth_y,
		pos.z + dir_z * forward_dist
	)
	return mouth_center, dir_x, dir_z
end

---Calculate player-local velocity for attached particle spawners with Galilean relativity
---Projects player 3D world velocity (including mount/vehicle motion) into the player's local reference frame
---and offsets it with base ejection scatter.
---@nodiscard
---@param player ObjectRef Target player
---@param base_minvel Vector3 Base local ejection min velocity (forward +Z, scatter +-X, drop -Y)
---@param base_maxvel Vector3 Base local ejection max velocity
---@return Vector3 minvel Local synchronized minimum velocity
---@return Vector3 maxvel Local synchronized maximum velocity
function x_player_api.get_synchronized_particle_velocity(player, base_minvel, base_maxvel)
	local pvel = player:get_velocity() or vector.new(0, 0, 0)

	-- Inherit mount/vehicle velocity if attached to an entity
	local parent = player:get_attach()
	if parent then
		local parent_vel = parent:get_velocity()
		if parent_vel then
			pvel = vector.new(
				pvel.x + (parent_vel.x or 0),
				pvel.y + (parent_vel.y or 0),
				pvel.z + (parent_vel.z or 0)
			)
		end
	end

	local yaw = player:get_look_horizontal() or 0

	local sin_yaw = math.sin(yaw)
	local cos_yaw = math.cos(yaw)

	-- Attached particle spawners inherit player orientation, so velocity is player-local
	-- Local +Z is forward, local +X is lateral right, local +Y is vertical
	local local_fwd_vel = -sin_yaw * pvel.x + cos_yaw * pvel.z
	local local_right_vel = cos_yaw * pvel.x + sin_yaw * pvel.z

	local minvel = vector.new(
		local_right_vel + base_minvel.x,
		pvel.y + base_minvel.y,
		local_fwd_vel + base_minvel.z
	)
	local maxvel = vector.new(
		local_right_vel + base_maxvel.x,
		pvel.y + base_maxvel.y,
		local_fwd_vel + base_maxvel.z
	)
	return minvel, maxvel
end

---Calculate player-local gaze-oriented bounding box for particle spawner emission
---@nodiscard
---@param player ObjectRef Target player
---@param half_w number Half-width lateral spread
---@param half_h number Half-height vertical spread
---@param forward_dist number Forward gaze projection distance
---@param half_depth number Half-depth longitudinal spread
---@return Vector3 minpos Local bounding box min
---@return Vector3 maxpos Local bounding box max
local function get_local_mouth_bounds(player, half_w, half_h, forward_dist, half_depth)
	local props = player and player:get_properties()
	local eye_height = (props and props.eye_height) or 1.47
	local mouth_y = eye_height - 0.18

	local minpos = vector.new(
		-half_w,
		mouth_y - half_h,
		forward_dist - half_depth
	)
	local maxpos = vector.new(
		half_w,
		mouth_y + half_h,
		forward_dist + half_depth
	)
	return minpos, maxpos
end

---Register a custom particle generator for consumables or action triggers
---@param type_name string Identifier (e.g. "crumbs", "liquid_drops", "none")
---@param generator ParticleGeneratorFunc Generator function returning particle spawner ID
function x_player_api.register_particle_generator(type_name, generator)
	generators[type_name] = generator
end

local DEFAULT_CONSUMABLE = {action = "eat", duration = 1.34, particle_type = "crumbs"}
---@type table<string, ConsumableDefinition> Memoized consumable definition cache
local CONSUMABLE_CACHE = {}
local CRUMB_POOLS = {}

local engine_eat_funcs = setmetatable({}, {__mode = "k"})
local orig_item_eat = core.item_eat
if orig_item_eat then
	function core.item_eat(...)
		local fn = orig_item_eat(...)
		if type(fn) == "function" then
			engine_eat_funcs[fn] = true
		end
		return fn
	end
end

local orig_do_item_eat = core.do_item_eat
if orig_do_item_eat then
	function core.do_item_eat(hp_change, replace_with_item, itemstack, user, pointed_thing)
		local pre_name = (itemstack and not itemstack:is_empty()) and itemstack:get_name() or nil
		local res = orig_do_item_eat(hp_change, replace_with_item, itemstack, user, pointed_thing)
		if res and user and user:is_player() and pre_name then
			x_player_api.trigger_eat(user, nil, pre_name)
		end
		return res
	end
end

---Clear internal consumable definition cache
function x_player_api.clear_consumable_cache()
	CONSUMABLE_CACHE = {}
	CRUMB_POOLS = {}
end

---Register an item or group as a consumable with specific action, sound, and particle effects
---@param item_or_group string e.g. "x_farming:bread", "group:food", "potions:healing"
---@param def ConsumableDefinition Consumable configuration definition
function x_player_api.register_consumable(item_or_group, def)
	consumables[item_or_group] = {
		action = def.action or "eat",
		duration = def.duration or 1.34,
		particle_type = def.particle_type or "crumbs",
		sound = def.sound,
	}
	x_player_api.clear_consumable_cache()
	x_player_api.clear_item_cache()
end

---Resolve consumable definition for an item name from explicit registrations or item groups
---@nodiscard
---@param item_name string? Target item technical name
---@return ConsumableDefinition def Resolved consumable definition
function x_player_api.get_consumable_definition(item_name)
	if not item_name or item_name == "" then
		return DEFAULT_CONSUMABLE
	end

	local cached = CONSUMABLE_CACHE[item_name]
	if cached then
		return cached
	end

	local resolved

	-- Direct item match
	if consumables[item_name] then
		resolved = consumables[item_name]
	end

	-- Group matches
	if not resolved then
		local idef = core.registered_items[item_name]
		if idef and idef.groups then
			for g, v in pairs(idef.groups) do
				if v > 0 and consumables["group:" .. g] then
					resolved = consumables["group:" .. g]
					break
				end
			end
		end
	end

	-- Direct item group check
	if not resolved then
		for key, cdef in pairs(consumables) do
			if key:sub(1, 6) == "group:" then
				local group = key:sub(7)
				if core.get_item_group(item_name, group) > 0 then
					resolved = cdef
					break
				end
			end
		end
	end

	-- Automatic default heuristic for beverages / liquid items
	if not resolved then
		local is_drink = (core.get_item_group(item_name, "drink") > 0)
			or (core.get_item_group(item_name, "potion") > 0)
			or (core.get_item_group(item_name, "bottle") > 0)
			or (item_name:find("potion", 1, true) ~= nil)
			or (item_name:find("bottle", 1, true) ~= nil)
			or (item_name:find("drink", 1, true) ~= nil)
		if is_drink then
			resolved = {
				action = "eat",
				duration = 1.34,
				particle_type = "liquid_drops",
				sound = "x_player_api_drink",
			}
		else
			resolved = DEFAULT_CONSUMABLE
		end
	end

	CONSUMABLE_CACHE[item_name] = resolved
	return resolved
end

---Check if an item name represents an edible or consumable item
---@nodiscard
---@param item_name string? Target item technical name
---@return boolean is_consumable True if item is explicitly or heuristically consumable
function x_player_api.is_consumable(item_name)
	if not item_name or item_name == "" then
		return false
	end
	if consumables[item_name] ~= nil then
		return true
	end

	local idef = core.registered_items[item_name]
	if idef then
		-- Luanti engine item_eat closure in on_use
		if idef.on_use and engine_eat_funcs[idef.on_use] then
			return true
		end

		-- Luanti standard food and drink groups
		local groups = idef.groups
		if groups then
			for g, v in pairs(groups) do
				if v > 0 then
					if g == "food" or g == "eatable" or g == "drink"
						or g:sub(1, 5) == "food_" or g:sub(1, 6) == "drink_" then
						return true
					end
					if consumables["group:" .. g] ~= nil then
						return true
					end
				end
			end
		end

		-- Standard item definition sound conventions
		if idef.sound and (idef.sound.eat or idef.sound.drink or idef.sound == "eat") then
			return true
		end
	end

	-- Direct group check fallback for items registered without idef.groups table
	if core.get_item_group(item_name, "food") > 0
		or core.get_item_group(item_name, "eatable") > 0
		or core.get_item_group(item_name, "drink") > 0 then
		return true
	end

	for key in pairs(consumables) do
		if key:sub(1, 6) == "group:" then
			local group = key:sub(7)
			if core.get_item_group(item_name, group) > 0 then
				return true
			end
		end
	end

	local lname = item_name:lower()
	if lname:sub(1, 5) == "food_" or lname:find("potion", 1, true)
			or lname:find("bottle", 1, true) or lname:find("drink", 1, true) then
		return true
	end

	return false
end

-- Built-in Generator: Crumb particles (node-sampled or 4x4 sliced texture)
x_player_api.register_particle_generator("crumbs", function(player, item_name, duration)
	if not player or not player:is_player() then
		return nil
	end

	if not item_name or item_name == "" then
		local wielded = player:get_wielded_item()
		if wielded and not wielded:is_empty() then
			item_name = wielded:get_name()
		end
	end
	if not item_name or item_name == "" then
		local name = player:get_player_name()
		local states = x_player_api.controls.player_states
		local pstate = states and states[name]
		if pstate and pstate.eat_item_name and pstate.eat_item_name ~= "" then
			item_name = pstate.eat_item_name
		elseif pstate and pstate.wield_name and pstate.wield_name ~= "" then
			item_name = pstate.wield_name
		end
	end

	local is_node = item_name and (core.registered_nodes[item_name] ~= nil)
	local texture_name = item_name and x_player_api.get_item_texture(item_name)
	if not is_node and not texture_name then
		texture_name = "x_player_api_bubble.png"
	end

	local minpos, maxpos = get_local_mouth_bounds(player, 0.06, 0.04, 0.42, 0.05)

	-- Base local ejection: forward spray (+Z), lateral scatter (+-X), downward gravity arc (-Y)
	local base_minvel = vector.new(-0.25, -0.60, 0.35)
	local base_maxvel = vector.new( 0.25, -0.10, 0.75)
	local minvel, maxvel = x_player_api.get_synchronized_particle_velocity(player, base_minvel, base_maxvel)

	-- Gravitational acceleration pulling crumbs to ground
	local minacc = GRAVITY_ACC
	local maxacc = GRAVITY_ACC

	local spawner_time = duration or 0.25
	local particle_count = math.max(6, math.floor(spawner_time * 24))

	local spawner_def = {
		amount = particle_count,
		time = spawner_time,
		attached = player,

		-- Modern range vector fields
		pos = {min = minpos, max = maxpos},
		vel = {min = minvel, max = maxvel},
		acc = {min = minacc, max = maxacc},
		exptime = {min = 0.85, max = 1.45},
		size = {min = 0.6, max = 1.6},

		-- Legacy fallbacks for older clients
		minpos = minpos,
		maxpos = maxpos,
		minvel = minvel,
		maxvel = maxvel,
		minacc = minacc,
		maxacc = maxacc,
		minexptime = 0.85,
		maxexptime = 1.45,
		minsize = 0.6,
		maxsize = 1.6,

		collisiondetection = true,
		collision_removal = true,
		object_collision = false,
	}

	if is_node then
		spawner_def.node = {name = item_name, param2 = 0}
	else
		-- Slice non-node item texture into a 4x4 grid of crumb fragments to simulate node dig particles
		local crumb_pool = CRUMB_POOLS[texture_name]
		if not crumb_pool then
			crumb_pool = {}
			for y = 0, 3 do
				for x = 0, 3 do
					crumb_pool[#crumb_pool + 1] = {
						name = string.format("%s^[sheet:4x4:%d,%d", texture_name, x, y),
						blend = "clip",
					}
				end
			end
			CRUMB_POOLS[texture_name] = crumb_pool
		end
		spawner_def.texpool = crumb_pool
		spawner_def.texture = string.format("%s^[sheet:4x4:1,1", texture_name)
	end

	return core.add_particlespawner(spawner_def)
end)

-- Built-in Generator: Liquid drops (for potions and drinks)
x_player_api.register_particle_generator("liquid_drops", function(player, item_name, duration)
	if not player or not player:is_player() then
		return nil
	end

	if not item_name or item_name == "" then
		local wielded = player:get_wielded_item()
		if wielded and not wielded:is_empty() then
			item_name = wielded:get_name()
		end
	end
	if not item_name or item_name == "" then
		local name = player:get_player_name()
		local states = x_player_api.controls.player_states
		local pstate = states and states[name]
		if pstate and pstate.eat_item_name and pstate.eat_item_name ~= "" then
			item_name = pstate.eat_item_name
		elseif pstate and pstate.wield_name and pstate.wield_name ~= "" then
			item_name = pstate.wield_name
		end
	end

	local texture_name = item_name and x_player_api.get_item_texture(item_name)
	local particle_tex = texture_name or "x_player_api_bubble.png"

	local minpos, maxpos = get_local_mouth_bounds(player, 0.04, 0.02, 0.38, 0.04)

	local base_minvel = vector.new(-0.10, -1.20, 0.25)
	local base_maxvel = vector.new( 0.10, -0.40, 0.55)
	local minvel, maxvel = x_player_api.get_synchronized_particle_velocity(player, base_minvel, base_maxvel)

	local minacc = GRAVITY_ACC
	local maxacc = GRAVITY_ACC

	local spawner_time = duration or 0.25
	local particle_count = math.max(4, math.floor(spawner_time * 16))

	local spawner_def = {
		amount = particle_count,
		time = spawner_time,
		attached = player,
		pos = {min = minpos, max = maxpos},
		vel = {min = minvel, max = maxvel},
		acc = {min = minacc, max = maxacc},
		exptime = {min = 0.65, max = 1.10},
		size = {min = 0.5, max = 1.1},

		minpos = minpos,
		maxpos = maxpos,
		minvel = minvel,
		maxvel = maxvel,
		minacc = minacc,
		maxacc = maxacc,
		minexptime = 0.65,
		maxexptime = 1.10,
		minsize = 0.5,
		maxsize = 1.1,

		texture = particle_tex,
		texpool = {particle_tex},

		collisiondetection = true,
		collision_removal = true,
		object_collision = false,
	}

	return core.add_particlespawner(spawner_def)
end)

-- Built-in Generator: No particles
x_player_api.register_particle_generator("none", function()
	return nil
end)

---Spawn eating crumbs or liquid particlespawner with modern definition fields and micro-burst synchronization
---@param player ObjectRef Target player
---@param item_name string? Consumed item name
---@param duration number? Particle effect duration in seconds
---@param particle_type string? Optional generator type override
---@return integer|nil spawner_id Particle spawner identifier of initial burst
function x_player_api.spawn_eat_particles(player, item_name, duration, particle_type)
	if not x_player_api.enable_eating then
		return nil
	end
	if not player or not player:is_player() then
		return nil
	end

	if not item_name or item_name == "" then
		local name = player:get_player_name()
		local states = x_player_api.controls.player_states
		local pstate = states and states[name]
		if pstate and pstate.eat_item_name and pstate.eat_item_name ~= "" then
			item_name = pstate.eat_item_name
		end
	end

	if not particle_type then
		local cdef = x_player_api.get_consumable_definition(item_name)
		particle_type = cdef.particle_type or "crumbs"
	end

	local generator = generators[particle_type] or generators.crumbs
	if not generator then
		return nil
	end

	local total_duration = duration or 0.25
	local burst_interval = 0.25
	local initial_burst = math.min(total_duration, burst_interval)
	local spawner_id = generator(player, item_name, initial_burst)

	-- If duration exceeds single burst, schedule successive micro-bursts to track dynamic movement
	if total_duration > burst_interval then
		local num_bursts = math.ceil(total_duration / burst_interval)
		local name = player:get_player_name()

		for b = 2, num_bursts do
			local delay = (b - 1) * burst_interval
			local burst_time = math.min(burst_interval, total_duration - delay)
			if burst_time > 0.05 then
				core.after(delay, function()
					local p = core.get_player_by_name(name)
					if not p or not p:is_player() or p:get_hp() <= 0 then
						return
					end

					local ctrl = x_player_api.controls
					local states = ctrl and ctrl.player_states
					local pstate = states and states[name]
					local time_now = core.get_us_time() * 0.000001

					-- Stop emitting if eating finished or was interrupted
					if pstate and pstate.eat_until and (pstate.eat_until + 0.1) < time_now then
						return
					end

					generator(p, item_name, burst_time)
				end)
			end
		end
	end

	return spawner_id
end

---Trigger eating or drinking animation externally
---@param player ObjectRef Target player
---@param duration number? Action duration in seconds
---@param item_name string? Consumed item name
function x_player_api.trigger_eat(player, duration, item_name)
	if not x_player_api.enable_eating then
		return
	end
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	local ctrl = x_player_api.controls
	local states = ctrl and ctrl.player_states
	local pstate = states and states[name]
	if not pstate then return end

	local cdef = x_player_api.get_consumable_definition(item_name)
	local act_duration = duration or cdef.duration or 1.34
	local action_name = cdef.action or "eat"

	local time_now = core.get_us_time() * 0.000001
	local is_already_eating = (pstate.eat_action == action_name)
		and (pstate.eat_until ~= nil and pstate.eat_until > time_now)

	pstate.eat_until = math.max(pstate.eat_until or 0, time_now + act_duration)
	pstate.eat_action = action_name
	pstate.eat_item_name = item_name or pstate.eat_item_name
	pstate.eat_particle_type = cdef.particle_type or "crumbs"

	if not is_already_eating then
		x_player_api.play_action(player, action_name, true)
	end

	-- Play custom sound if configured
	if cdef.sound then
		local pos = player:get_pos()
		if pos then
			core.sound_play(cdef.sound, {pos = pos, gain = 0.8}, true)
		end
	end

	pstate.last_chew_particle_time = time_now
	-- Spawn eating crumbs or liquid particles
	x_player_api.spawn_eat_particles(player, item_name, act_duration, cdef.particle_type)
end

---Cancel active eating animation, clear state, and stop particle emitters
---@param player ObjectRef Target player
---@return boolean was_eating Whether player was actively eating
function x_player_api.cancel_eat(player)
	if not player or not player.is_player or not player:is_player() then return false end
	local name = player:get_player_name()
	local ctrl = x_player_api.controls
	local states = ctrl and ctrl.player_states
	local pstate = states and states[name]
	if not pstate then return false end

	local time_now = core.get_us_time() * 0.000001
	local was_eating = (pstate.eat_until ~= nil and pstate.eat_until > time_now) or false
	pstate.eat_until = 0
	pstate.eat_action = nil
	pstate.eat_item_name = nil
	pstate.eat_particle_type = nil
	pstate.last_chew_particle_time = 0

	if pstate.semantic_state then
		pstate.semantic_state.eating = false
	end

	local pdata = x_player_api.get_animation(player)
	if pdata and pdata.action == "eat" then
		x_player_api.play_action(player, nil)
	end

	return was_eating
end

-- Trigger eat animation when player consumes food/drink item
core.register_on_item_eat(function(...)
	if not x_player_api.enable_eating then
		return
	end
	local itemstack = select(3, ...)
	local user = select(4, ...)
	if user and user:is_player() then
		local iname = (itemstack and not itemstack:is_empty()) and itemstack:get_name() or nil
		if not iname or iname == "" then
			local wielded = user:get_wielded_item()
			if wielded and not wielded:is_empty() then
				iname = wielded:get_name()
			end
		end
		if not iname or iname == "" then
			local name = user:get_player_name()
			local states = x_player_api.controls.player_states
			local pstate = states and states[name]
			if pstate and pstate.wield_name and pstate.wield_name ~= "" then
				iname = pstate.wield_name
			end
		end
		x_player_api.trigger_eat(user, nil, iname)
	end
end)

-- Cancel eating cleanly on player death
core.register_on_dieplayer(function(player)
	x_player_api.cancel_eat(player)
end)
