player_api = {}

-- Player animation blending
-- GRUG PATCH: every switch blends over 0.12 s (Round 40 ruling 14: a pose's
-- arms would otherwise jump). Luanti 5.17 blends a B3D's bones
-- (irr/src/SkinnedMesh.cpp, SkinnedMesh::animateMesh); upstream's "broken in
-- Irrlicht, leave at 0" note predates that.
local animation_blend = 0.12

player_api.registered_models = {}

-- Local for speed.
local models = player_api.registered_models

local function collisionbox_equals(collisionbox, other_collisionbox)
	if collisionbox == other_collisionbox then
		return true
	end
	for index = 1, 6 do
		if collisionbox[index] ~= other_collisionbox[index] then
			return false
		end
	end
	return true
end

function player_api.register_model(name, def)
	models[name] = def
	def.visual_size = def.visual_size or {x = 1, y = 1}
	def.collisionbox = def.collisionbox or {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}
	def.stepheight = def.stepheight or 0.6
	def.eye_height = def.eye_height or 1.47

	-- Sort animations into property classes:
	-- Animations with same properties have the same _equals value
	for animation_name, animation in pairs(def.animations) do
		animation.eye_height = animation.eye_height or def.eye_height
		animation.collisionbox = animation.collisionbox or def.collisionbox
		animation.override_local = animation.override_local or false

		for _, other_animation in pairs(def.animations) do
			if other_animation._equals then
				if collisionbox_equals(animation.collisionbox, other_animation.collisionbox)
						and animation.eye_height == other_animation.eye_height then
					animation._equals = other_animation._equals
					break
				end
			end
		end
		animation._equals = animation._equals or animation_name
	end
end

-- Player stats and animations
-- model, textures, animation
local players = {}
player_api.player_attached = {}

local function get_player_data(player)
	return assert(players[player:get_player_name()])
end

function player_api.get_animation(player)
	return get_player_data(player)
end

-- Called when a player's appearance needs to be updated
function player_api.set_model(player, model_name)
	local player_data = get_player_data(player)
	if player_data.model == model_name then
		return
	end
	-- Update data
	player_data.model = model_name
	-- Clear animation data as the model has changed
	-- (required for setting the `stand` animation not to be a no-op)
	player_data.animation, player_data.animation_speed, player_data.animation_loop = nil, nil, nil

	local model = models[model_name]
	if model then
		player:set_properties({
			mesh = model_name,
			textures = player_data.textures or model.textures,
			visual = "mesh",
			visual_size = model.visual_size,
			stepheight = model.stepheight
		})
		-- sets local_animation, collisionbox & eye_height
		player_api.set_animation(player, "stand")
	else
		player:set_properties({
			textures = {"player.png", "player_back.png"},
			visual = "upright_sprite",
			visual_size = {x = 1, y = 2},
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.75, 0.3},
			stepheight = 0.6,
			eye_height = 1.625,
		})
	end
end

function player_api.get_textures(player)
	local player_data = get_player_data(player)
	local model = models[player_data.model]
	return assert(player_data.textures or (model and model.textures))
end

function player_api.set_textures(player, textures)
	local player_data = get_player_data(player)
	local model = models[player_data.model]
	local new_textures = assert(textures or (model and model.textures))
	player_data.textures = new_textures
	player:set_properties({textures = new_textures})
end

function player_api.set_texture(player, index, texture)
	local textures = table.copy(player_api.get_textures(player))
	textures[index] = texture
	player_api.set_textures(player, textures)
end

-- GRUG PATCH: the frame offset into `anim` the player's current animation has
-- reached, from when and where it started and its speed (seconds of the
-- server's clock, so a comparison with the client's playback, not a replica).
local function frame_offset(player_data, anim, now)
	local offset = player_data.grug_offset + (now - player_data.grug_started) / 1e6
		* player_data.animation_speed
	local length = anim.y - anim.x
	if not player_data.animation_loop then
		return math.max(0, math.min(offset, length))
	end
	return length > 0 and offset % length or 0
end

-- GRUG PATCH: `restart` plays the animation from its first frame even when it
-- is already playing (a one-shot fired again). Two animations sharing a
-- `_grug_phase` group continue each other's frame offset instead of starting
-- over: the walk cycle across walk, walk_mine and the pose clips' walking
-- twins, a one-shot across its standing and walking twin (grug_visuals).
function player_api.set_animation(player, anim_name, speed, loop, restart)
	local player_data = get_player_data(player)
	local model = models[player_data.model]
	if not (model and model.animations[anim_name]) then
		return
	end
	speed = speed or model.animation_speed
	if loop == nil then
		loop = true
	end
	if not restart
		and player_data.animation == anim_name
		and player_data.animation_speed == speed
		and player_data.animation_loop == loop
	then
		return
	end
	local previous_anim = model.animations[player_data.animation] or {}
	local anim = model.animations[anim_name]
	local now = core.get_us_time()
	local offset = 0
	if not restart and anim._grug_phase
			and anim._grug_phase == previous_anim._grug_phase then
		offset = math.min(frame_offset(player_data, previous_anim, now), anim.y - anim.x)
	end
	player_data.grug_started, player_data.grug_offset = now, offset
	player_data.animation = anim_name
	player_data.animation_speed = speed
	player_data.animation_loop = loop
	-- If necessary change the local animation (only seen by the client of *that* player)
	-- `override_local` <=> suspend local animations while this one is active
	-- (this is basically a hack, proper engine feature needed...)
	if anim.override_local ~= previous_anim.override_local then
		if anim.override_local then
			local none = {x=0, y=0}
			player:set_local_animation(none, none, none, none, 1)
		else
			local a = model.animations -- (not specific to the animation being set)
			player:set_local_animation(
				a.stand, a.walk, a.mine, a.walk_mine,
				model.animation_speed or 30
			)
		end
	end
	-- Set the animation seen by everyone else
	if offset > 0 then
		-- GRUG PATCH: start inside the range (Luanti 5.17 play_animation; track 1
		-- is the one set_animation drives).
		player:play_animation(1, {min_frame = anim.x, max_frame = anim.y,
			start_frame = anim.x + offset, speed = speed, blend = animation_blend,
			loop = loop})
	else
		player:set_animation(anim, speed, animation_blend, loop)
	end
	-- Update related properties if they changed
	if anim._equals ~= previous_anim._equals then
		player:set_properties({
			collisionbox = anim.collisionbox,
			eye_height = anim.eye_height
		})
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	players[name] = {}
	player_api.player_attached[name] = false
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	players[name] = nil
	player_api.player_attached[name] = nil
end)

-- Localize for better performance.
local player_set_animation = player_api.set_animation
local player_attached = player_api.player_attached
-- GRUG PATCH: let server-owned held actions suppress the generic mine pose
-- without adding a second animation globalstep or coupling this vendor mod to
-- a specific Grudgelands ability.
local control_animation_overrides = {}

function player_api.register_control_animation_override(callback)
	assert(type(callback) == "function", "animation override needs a callback")
	control_animation_overrides[#control_animation_overrides + 1] = callback
end

-- GRUG PATCH: an override answers the animation and optionally `loop` (false
-- plays it once) and `restart` (replay it from the start although it runs).
local function control_animation_override(player, controls)
	for index = 1, #control_animation_overrides do
		local animation, loop, restart =
			control_animation_overrides[index](player, controls)
		if animation then return animation, loop, restart end
	end
end

-- Prevent knockback for attached players
local old_calculate_knockback = minetest.calculate_knockback
function minetest.calculate_knockback(player, ...)
	if player_attached[player:get_player_name()] then
		return 0
	end
	return old_calculate_knockback(player, ...)
end

-- Check each player and apply animations
function player_api.globalstep()
	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local player_data = players[name]
		local model = player_data and models[player_data.model]
		if model and not player_attached[name] then
			local controls = player:get_player_control()
			local animation_speed_mod = model.animation_speed or 30

			-- Determine if the player is sneaking, and reduce animation speed if so
			if controls.sneak then
				animation_speed_mod = animation_speed_mod / 2
			end

			-- Apply animations based on what the player is doing
			if player:get_hp() == 0 then
				player_set_animation(player, "lay")
			else
				local override, loop, restart = control_animation_override(player, controls)
				if override then
					player_set_animation(player, override, animation_speed_mod, loop, restart)
				elseif controls.up or controls.down or controls.left or controls.right then
					if controls.LMB or controls.RMB then
						player_set_animation(player, "walk_mine", animation_speed_mod)
					else
						player_set_animation(player, "walk", animation_speed_mod)
					end
				elseif controls.LMB or controls.RMB then
					player_set_animation(player, "mine", animation_speed_mod)
				else
					player_set_animation(player, "stand", animation_speed_mod)
				end
			end
		end
	end
end

-- Mods can modify the globalstep by overriding player_api.globalstep
minetest.register_globalstep(function(...)
	player_api.globalstep(...)
end)

-- GRUG PATCH: current callers use initialized online players; no legacy wrappers.
