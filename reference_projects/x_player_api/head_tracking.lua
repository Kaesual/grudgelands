-- x_player_api/head_tracking.lua
-- Natural and smooth head bone look direction tracking subsystem for Luanti.
-- Provides biomechanically clamped pitch and attached yaw orientation with
-- exponential temporal smoothing, angular deadband filtering, and idle sleep states.

x_player_api = x_player_api or player_api

---@class HeadTrackingConfig
---@field enable boolean Global subsystem activation toggle
---@field enable_arm_tracking boolean Whether dual-arm pitch tracking is active (default: true)
---@field smooth_speed number Exponential decay rate in 1/seconds for head interpolation
---@field body_turn_speed number Rate at which virtual body catches up to look direction
---@field pitch_up_max number Maximum looking up limit in radians
---@field pitch_down_max number Maximum looking down limit in radians
---@field fly_pitch_offset number Baseline upward pitch offset when flying in radians (default: -75 deg)
---@field fly_pitch_up_max number Maximum upward pitch in flight in radians (default: 85 deg)
---@field fly_pitch_down_max number Maximum downward pitch in flight in radians (default: 10 deg)
---@field swim_pitch_offset number Baseline upward pitch offset when swimming in radians (default: -75 deg)
---@field swim_pitch_up_max number Maximum upward pitch when swimming in radians (default: 85 deg)
---@field swim_pitch_down_max number Maximum downward pitch when swimming in radians (default: 10 deg)
---@field arm_pitch_up_max number Maximum upward pitch for arms in radians
---@field arm_pitch_down_max number Maximum downward pitch for arms in radians
---@field arm_idle_weight number Subtle pitch weight applied to arms during idle/movement (default: 0.35)
---@field arm_action_weight number Pitch weight applied during mining and melee attacks (default: 0.85)
---@field arm_aim_weight number Pitch weight applied during bow and ranged aiming (default: 1.0)
---@field yaw_limit_attached number Clamped horizontal rotation limit when attached in radians
---@field yaw_limit_free number Clamped horizontal rotation lead when free in radians
---@field deadband number Minimum angular rotation delta in radians to trigger a network packet
---@field settle_threshold number Convergence threshold in radians to enter sleep state
---@field interpolation number Bone override client interpolation duration in seconds

---@class PlayerHeadState
---@field current Vector3 Current smoothed head bone rotation vector {x, y, z} in radians
---@field target Vector3 Target head bone rotation vector {x, y, z} in radians
---@field last_sent Vector3 Last head rotation successfully dispatched over network {x, y, z}
---@field arm_current_r Vector3 Current smoothed right arm bone rotation vector {x, y, z} in radians
---@field arm_current_l Vector3 Current smoothed left arm bone rotation vector {x, y, z} in radians
---@field arm_current_l_b3d Vector3 Current smoothed left arm bone rotation vector in B3D space
---@field arm_target_r Vector3 Target right arm bone rotation vector {x, y, z} in radians
---@field arm_target_l Vector3 Target left arm bone rotation vector {x, y, z} in radians
---@field arm_target_l_b3d Vector3 Target left arm bone rotation vector in B3D space
---@field arm_last_sent_r Vector3 Last right arm rotation successfully dispatched over network {x, y, z}
---@field arm_last_sent_l Vector3 Last left arm rotation successfully dispatched over network {x, y, z}
---@field arm_last_sent_l_b3d Vector3 Last left arm rotation successfully dispatched in B3D space
---@field sleeping boolean Whether orientation is settled in idle quiescence
---@field enabled boolean Per-player tracking activation flag
---@field weight number Current blending weight multiplier between 0.0 and 1.0
---@field virtual_body_yaw number|nil Smoothed body orientation for free-standing turn lead

---@class HeadTrackingContext
---@field look_vertical number Raw vertical look pitch in radians
---@field look_horizontal number Raw horizontal look yaw in radians
---@field is_attached boolean Whether player is attached to a vehicle or entity
---@field attach_parent ObjectRef|nil Parent entity if attached
---@field weight number Target posture weight multiplier

---@alias HeadTrackingModifier fun(player: ObjectRef, state: PlayerSemanticState, ctx: HeadTrackingContext):
---| Vector3?, number?

---@class HeadTrackingSubsystem
---@field config HeadTrackingConfig Global configuration settings
---@field states table<string, PlayerHeadState> Per-player tracking state mapping
---@field modifiers table<string, HeadTrackingModifier> Registered custom look modifiers
local head_tracking = {}
x_player_api.head_tracking = head_tracking

---@type HeadTrackingConfig
head_tracking.config = {
	enable = true,
	enable_arm_tracking = true,
	smooth_speed = 14.0,
	body_turn_speed = 8.0,
	pitch_up_max = math.rad(75.0),
	pitch_down_max = math.rad(70.0),
	fly_pitch_offset = -math.rad(75.0),
	fly_pitch_up_max = math.rad(85.0),
	fly_pitch_down_max = math.rad(10.0),
	swim_pitch_offset = -math.rad(75.0),
	swim_pitch_up_max = math.rad(85.0),
	swim_pitch_down_max = math.rad(10.0),
	arm_pitch_up_max = math.rad(75.0),
	arm_pitch_down_max = math.rad(70.0),
	arm_idle_weight = 0.35,
	arm_action_weight = 0.85,
	arm_aim_weight = 1.0,
	yaw_limit_attached = math.rad(75.0),
	yaw_limit_free = math.rad(35.0),
	deadband = 0.05,
	settle_threshold = 0.005,
	interpolation = 0.1,
}

local setting_enable = core.settings:get_bool("x_player_api.enable_head_tracking")
if setting_enable ~= nil then
	head_tracking.config.enable = setting_enable
end

---@type table<string, PlayerHeadState>
head_tracking.states = {}
local states = head_tracking.states

---@type table<string, HeadTrackingModifier>
head_tracking.modifiers = {}

---Initialize a clean, pre-allocated head tracking state table for a player
---@param name string Player name
---@param player ObjectRef? Optional player reference for initial body orientation
---@return PlayerHeadState
local function init_player_state(name, player)
	local init_yaw = 0
	if player then
		init_yaw = player:get_look_horizontal()
	end
	local state = {
		current = {x = 0, y = 0, z = 0},
		target = {x = 0, y = 0, z = 0},
		last_sent = {x = 0, y = 0, z = 0},
		arm_current_r = {x = 0, y = 0, z = 0},
		arm_current_l = {x = 0, y = 0, z = 0},
		arm_current_l_b3d = {x = 0, y = 0, z = 0},
		arm_target_r = {x = 0, y = 0, z = 0},
		arm_target_l = {x = 0, y = 0, z = 0},
		arm_target_l_b3d = {x = 0, y = 0, z = 0},
		arm_last_sent_r = {x = 0, y = 0, z = 0},
		arm_last_sent_l = {x = 0, y = 0, z = 0},
		arm_last_sent_l_b3d = {x = 0, y = 0, z = 0},
		sleeping = true,
		enabled = true,
		weight = 1.0,
		virtual_body_yaw = init_yaw,
	}
	states[name] = state
	return state
end

---Get or initialize player head tracking state
---@param player ObjectRef Target player
---@return PlayerHeadState? state
local function get_or_create_state(player)
	if not player or not player.get_player_name then return nil end
	local name = player:get_player_name()
	if name == "" then return nil end
	local state = states[name]
	if not state then
		state = init_player_state(name, player)
	end
	return state
end

---Calculate raw target angles and anatomical clamps based on camera orientation and attachments
---@param player ObjectRef Target player
---@param cfg HeadTrackingConfig Configuration table
---@param target Vector3 Pre-allocated target vector to mutate in-place
---@param ctx HeadTrackingContext Context table to populate
---@param pstate PlayerHeadState Current player tracking state
---@param dtime number Delta time in seconds
---@param semantic_state? PlayerSemanticState Active player semantic state
local function evaluate_target_angles(player, cfg, target, ctx, pstate, dtime, semantic_state)
	local look_vert = player:get_look_vertical()
	local look_horiz = player:get_look_horizontal()
	ctx.look_vertical = look_vert
	ctx.look_horizontal = look_horiz

	-- Luanti look vertical is negative when looking up, positive when looking down.
	-- In Luanti character models, local head bone pitch rotates up on -X and down on +X.
	local is_fly = semantic_state and (semantic_state.locomotion == "fly")
	local is_swim = semantic_state and (semantic_state.locomotion == "swim")
	local target_pitch = look_vert

	if is_fly or is_swim then
		local offset = is_swim and (cfg.swim_pitch_offset or -math.rad(75.0))
			or (cfg.fly_pitch_offset or -math.rad(75.0))
		target_pitch = offset + look_vert * 0.75
		local up_max = is_swim and (cfg.swim_pitch_up_max or math.rad(85.0))
			or (cfg.fly_pitch_up_max or math.rad(85.0))
		local down_max = is_swim and (cfg.swim_pitch_down_max or math.rad(10.0))
			or (cfg.fly_pitch_down_max or math.rad(10.0))
		if target_pitch < -up_max then
			target_pitch = -up_max
		elseif target_pitch > down_max then
			target_pitch = down_max
		end
	else
		if target_pitch < -cfg.pitch_up_max then
			target_pitch = -cfg.pitch_up_max
		elseif target_pitch > cfg.pitch_down_max then
			target_pitch = cfg.pitch_down_max
		end
	end

	local target_yaw, target_roll
	local attach_parent, _, _, attach_rot = player:get_attach()
	if attach_parent then
		ctx.is_attached = true
		ctx.attach_parent = attach_parent
		local parent_yaw = (attach_parent.get_yaw and attach_parent:get_yaw()) or 0
		if attach_rot and attach_rot.y then
			parent_yaw = parent_yaw + math.rad(attach_rot.y)
		end
		local diff = look_horiz - parent_yaw
		-- Normalize angle difference to [-pi, pi]
		diff = (diff + math.pi) % (2 * math.pi) - math.pi
		local limit = cfg.yaw_limit_attached
		if diff > limit then
			diff = limit
		elseif diff < -limit then
			diff = -limit
		end
		-- In Luanti character models, bone rotates left on -Y and right on +Y
		target_yaw = -diff
		target_roll = -target_yaw * 0.08
		pstate.virtual_body_yaw = look_horiz
	else
		ctx.is_attached = false
		ctx.attach_parent = nil
		-- Free-standing horizontal gaze leading & body turn lag
		if not pstate.virtual_body_yaw then
			pstate.virtual_body_yaw = look_horiz
		end
		local diff = (look_horiz - pstate.virtual_body_yaw + math.pi) % (2 * math.pi) - math.pi
		local body_speed = cfg.body_turn_speed or 8.0
		local turn_factor = 1.0 - math.exp(-body_speed * (dtime or 0.05))
		if turn_factor > 1.0 then turn_factor = 1.0 end
		if turn_factor < 0.0 then turn_factor = 0.0 end
		pstate.virtual_body_yaw = (pstate.virtual_body_yaw + diff * turn_factor) % (2 * math.pi)

		-- Head leads the turn by up to yaw_limit_free (~35 deg), smoothly centering when turn ends
		local free_limit = cfg.yaw_limit_free or math.rad(35.0)
		local yaw_lead = diff * (1.0 - turn_factor * 0.5)
		if yaw_lead > free_limit then
			yaw_lead = free_limit
		elseif yaw_lead < -free_limit then
			yaw_lead = -free_limit
		end
		-- In Luanti character models, bone rotates left on -Y and right on +Y
		target_yaw = -yaw_lead
		target_roll = -target_yaw * 0.08
	end

	target.x = target_pitch
	target.y = target_yaw
	target.z = target_roll
end

---Evaluate posture-based tracking weights and suppression rules
---@param player ObjectRef Target player
---@param semantic_state PlayerSemanticState|nil Current high-level semantic locomotion state
---@return number weight Blending factor between 0.0 and 1.0
local function evaluate_posture_weight(player, semantic_state)
	if player:get_hp() <= 0 then
		return 0.0
	end

	if not semantic_state then
		return 1.0
	end

	local loco = semantic_state.locomotion
	if loco == "lay" or loco == "freeze" or loco == "bow" then
		return 0.0
	end

	if semantic_state.action == "hurt" then
		return 0.5
	end

	if loco == "slide" then
		return 0.7
	end

	return 1.0
end

-- Reusable context table to prevent garbage collection allocations in per-step loop
local active_ctx = {
	look_vertical = 0,
	look_horizontal = 0,
	is_attached = false,
	attach_parent = nil,
	weight = 1.0,
}

---Step head tracking simulation and network dispatch for a player
---Evaluates camera look pitch and yaw, applies posture weights and anatomical limits,
---smooths rotations with exponential decay, and dispatches throttled bone overrides.
---@param player ObjectRef Target player
---@param dtime number Delta time in seconds since last server step
---@param semantic_state? PlayerSemanticState Active player semantic state
function x_player_api.step_head_tracking(player, dtime, semantic_state)
	local cfg = head_tracking.config
	if not cfg.enable then return end

	local pstate = get_or_create_state(player)
	if not pstate or not pstate.enabled then return end

	local target = pstate.target
	local current = pstate.current
	local last_sent = pstate.last_sent

	-- 1. Evaluate target orientation and biomechanical clamps
	evaluate_target_angles(player, cfg, target, active_ctx, pstate, dtime, semantic_state)

	-- 2. Evaluate posture and state-based suppression
	local posture_weight = evaluate_posture_weight(player, semantic_state)
	active_ctx.weight = posture_weight

	-- 3. Execute extensible modifiers (Open/Closed Principle)
	if next(head_tracking.modifiers) then
		for _, mod_func in pairs(head_tracking.modifiers) do
			local custom_rot, weight_mult = mod_func(player, semantic_state, active_ctx)
			if custom_rot then
				if custom_rot.x then target.x = custom_rot.x end
				if custom_rot.y then target.y = custom_rot.y end
				if custom_rot.z then target.z = custom_rot.z end
			end
			if weight_mult then
				posture_weight = posture_weight * weight_mult
			end
		end
	end

	pstate.weight = posture_weight

	-- Apply posture weight scaling towards resting bind pose
	target.x = target.x * posture_weight
	target.y = target.y * posture_weight
	target.z = target.z * posture_weight

	-- 4. Evaluate dual-arm pitch tracking
	local arm_target_r = pstate.arm_target_r
	local arm_target_l = pstate.arm_target_l
	local arm_target_l_b3d = pstate.arm_target_l_b3d
	if cfg.enable_arm_tracking then
		local raw_arm_pitch = active_ctx.look_vertical
		if raw_arm_pitch < -cfg.arm_pitch_up_max then
			raw_arm_pitch = -cfg.arm_pitch_up_max
		elseif raw_arm_pitch > cfg.arm_pitch_down_max then
			raw_arm_pitch = cfg.arm_pitch_down_max
		end

		local is_bow = semantic_state and (
			semantic_state.aiming_bow
			or semantic_state.shooting_bow
			or semantic_state.action == "bow_aim"
			or semantic_state.action == "bow_shoot"
		)
		local is_mining_or_attacking = semantic_state and (
			semantic_state.action == "mine"
			or semantic_state.action == "walk_mine"
			or semantic_state.action == "attack_slash"
			or semantic_state.action == "attack_thrust"
		)
		local is_block = semantic_state and (semantic_state.action == "block")

		if is_bow then
			local w_r = cfg.arm_aim_weight * posture_weight
			arm_target_r.x = raw_arm_pitch * w_r
			arm_target_r.y = 0
			arm_target_r.z = 0

			-- Compensate Arm_Left oblique bone axis so both hands stay locked to the bow grip
			if raw_arm_pitch >= 0 then
				-- GLB space: maintain forward reach and draw inward across chest to lock onto bow
				arm_target_l.x = raw_arm_pitch * 0.50 * posture_weight
				arm_target_l.y = raw_arm_pitch * 0.26 * posture_weight
				arm_target_l.z = -raw_arm_pitch * 0.08 * posture_weight

				-- B3D space: compensate left-handed bone orientation and B3D keyframe base pose (75, 35, 30).
				-- In B3D, positive Y draws the left arm inward across the chest to lock onto the bow grip;
				-- negative X pitches the arm downward matching Arm_Right.
				local p = raw_arm_pitch
				local p2 = p * p
				arm_target_l_b3d.x = (0.50 * p2 - 1.45 * p) * posture_weight
				arm_target_l_b3d.y = (0.95 * p2 + 0.25 * p) * posture_weight
				arm_target_l_b3d.z = (-0.60 * p) * posture_weight
			else
				-- GLB space: coordinate upward elevation
				arm_target_l.x = raw_arm_pitch * 0.78 * posture_weight
				arm_target_l.y = -raw_arm_pitch * 0.20 * posture_weight
				arm_target_l.z = raw_arm_pitch * 0.65 * posture_weight

				-- B3D space: coordinate upward elevation (-0.90 * p elevates upward since p < 0).
				-- Clamp negative yaw at -0.28 rad so left arm does not over-rotate inward.
				local p = raw_arm_pitch
				arm_target_l_b3d.x = (-0.90 * p) * posture_weight
				local y_val = 0.65 * p
				if y_val < -0.28 then y_val = -0.28 end
				arm_target_l_b3d.y = y_val * posture_weight
				arm_target_l_b3d.z = (0.15 * p) * posture_weight
			end
		elseif is_mining_or_attacking then
			local w_r = cfg.arm_action_weight * posture_weight
			local w_l = (cfg.arm_idle_weight * 0.5) * posture_weight
			arm_target_r.x = raw_arm_pitch * w_r
			arm_target_r.y = 0
			arm_target_r.z = 0
			arm_target_l.x = raw_arm_pitch * w_l
			arm_target_l.y = 0
			arm_target_l.z = 0
			arm_target_l_b3d.x = -raw_arm_pitch * w_l
			arm_target_l_b3d.y = 0
			arm_target_l_b3d.z = 0
		elseif is_block then
			local w_r = (cfg.arm_idle_weight * 0.5) * posture_weight
			local w_l = cfg.arm_action_weight * posture_weight
			arm_target_r.x = raw_arm_pitch * w_r
			arm_target_r.y = 0
			arm_target_r.z = 0
			arm_target_l.x = raw_arm_pitch * w_l
			arm_target_l.y = 0
			arm_target_l.z = 0
			arm_target_l_b3d.x = -raw_arm_pitch * w_l
			arm_target_l_b3d.y = 0
			arm_target_l_b3d.z = 0
		else
			local w_r = cfg.arm_idle_weight * posture_weight
			local w_l = cfg.arm_idle_weight * posture_weight
			arm_target_r.x = raw_arm_pitch * w_r
			arm_target_r.y = 0
			arm_target_r.z = 0
			arm_target_l.x = raw_arm_pitch * w_l
			arm_target_l.y = 0
			arm_target_l.z = 0
			arm_target_l_b3d.x = -raw_arm_pitch * w_l
			arm_target_l_b3d.y = 0
			arm_target_l_b3d.z = 0
		end
	else
		arm_target_r.x = 0; arm_target_r.y = 0; arm_target_r.z = 0
		arm_target_l.x = 0; arm_target_l.y = 0; arm_target_l.z = 0
		arm_target_l_b3d.x = 0; arm_target_l_b3d.y = 0; arm_target_l_b3d.z = 0
	end

	-- 5. Quiescence / Idle Sleep check
	if pstate.sleeping then
		local delta_x = math.abs(target.x - last_sent.x)
		local delta_y = math.abs(target.y - last_sent.y)
		local delta_z = math.abs(target.z - last_sent.z)
		local delta_ar = math.abs(arm_target_r.x - pstate.arm_last_sent_r.x)
		local delta_al = math.abs(arm_target_l.x - pstate.arm_last_sent_l.x)
			+ math.abs(arm_target_l.y - pstate.arm_last_sent_l.y)
			+ math.abs(arm_target_l.z - pstate.arm_last_sent_l.z)
		local delta_al_b3d = math.abs(arm_target_l_b3d.x - pstate.arm_last_sent_l_b3d.x)
			+ math.abs(arm_target_l_b3d.y - pstate.arm_last_sent_l_b3d.y)
			+ math.abs(arm_target_l_b3d.z - pstate.arm_last_sent_l_b3d.z)
		if delta_x < cfg.deadband and delta_y < cfg.deadband and delta_z < cfg.deadband
			and delta_ar < cfg.deadband and delta_al < cfg.deadband
			and delta_al_b3d < cfg.deadband then
			return
		end
		-- Wake up from sleep when camera movement or arm targets exceed deadband
		pstate.sleeping = false
	end

	-- 6. Exponential decay temporal smoothing
	local smooth_factor = 1.0 - math.exp(-cfg.smooth_speed * dtime)
	if smooth_factor > 1.0 then smooth_factor = 1.0 end
	if smooth_factor < 0.0 then smooth_factor = 0.0 end

	current.x = current.x + (target.x - current.x) * smooth_factor

	-- Shortest arc interpolation for yaw
	local yaw_diff = (target.y - current.y + math.pi) % (2 * math.pi) - math.pi
	current.y = current.y + yaw_diff * smooth_factor

	current.z = current.z + (target.z - current.z) * smooth_factor

	local arm_current_r = pstate.arm_current_r
	local arm_current_l = pstate.arm_current_l
	arm_current_r.x = arm_current_r.x + (arm_target_r.x - arm_current_r.x) * smooth_factor
	arm_current_r.y = arm_current_r.y + (arm_target_r.y - arm_current_r.y) * smooth_factor
	arm_current_r.z = arm_current_r.z + (arm_target_r.z - arm_current_r.z) * smooth_factor

	arm_current_l.x = arm_current_l.x + (arm_target_l.x - arm_current_l.x) * smooth_factor
	arm_current_l.y = arm_current_l.y + (arm_target_l.y - arm_current_l.y) * smooth_factor
	arm_current_l.z = arm_current_l.z + (arm_target_l.z - arm_current_l.z) * smooth_factor

	local arm_current_l_b3d = pstate.arm_current_l_b3d
	arm_current_l_b3d.x = arm_current_l_b3d.x + (arm_target_l_b3d.x - arm_current_l_b3d.x) * smooth_factor
	arm_current_l_b3d.y = arm_current_l_b3d.y + (arm_target_l_b3d.y - arm_current_l_b3d.y) * smooth_factor
	arm_current_l_b3d.z = arm_current_l_b3d.z + (arm_target_l_b3d.z - arm_current_l_b3d.z) * smooth_factor

	-- 7. Check convergence to target for quiescence transition
	local conv_x = math.abs(current.x - target.x)
	local conv_y = math.abs(current.y - target.y)
	local conv_z = math.abs(current.z - target.z)
	local is_head_converged = (conv_x < cfg.settle_threshold and conv_y < cfg.settle_threshold
		and conv_z < cfg.settle_threshold)

	if is_head_converged then
		current.x = target.x
		current.y = target.y
		current.z = target.z
	end

	local conv_ar = math.abs(arm_current_r.x - arm_target_r.x)
	local conv_al = math.abs(arm_current_l.x - arm_target_l.x)
		+ math.abs(arm_current_l.y - arm_target_l.y)
		+ math.abs(arm_current_l.z - arm_target_l.z)
	local conv_al_b3d = math.abs(arm_current_l_b3d.x - arm_target_l_b3d.x)
		+ math.abs(arm_current_l_b3d.y - arm_target_l_b3d.y)
		+ math.abs(arm_current_l_b3d.z - arm_target_l_b3d.z)
	local is_arm_converged = (conv_ar < cfg.settle_threshold and conv_al < cfg.settle_threshold
		and conv_al_b3d < cfg.settle_threshold)

	if is_arm_converged then
		arm_current_r.x = arm_target_r.x
		arm_current_r.y = arm_target_r.y
		arm_current_r.z = arm_target_r.z
		arm_current_l.x = arm_target_l.x
		arm_current_l.y = arm_target_l.y
		arm_current_l.z = arm_target_l.z
		arm_current_l_b3d.x = arm_target_l_b3d.x
		arm_current_l_b3d.y = arm_target_l_b3d.y
		arm_current_l_b3d.z = arm_target_l_b3d.z
	end

	-- 8. Throttled dispatch to bone override pipeline with client interpolation
	local send_dx = math.abs(current.x - last_sent.x)
	local send_dy = math.abs(current.y - last_sent.y)
	local send_dz = math.abs(current.z - last_sent.z)

	if is_head_converged then
		if send_dx > 0.001 or send_dy > 0.001 or send_dz > 0.001 then
			x_player_api.set_bone_override(player, "Head", nil, current, true, cfg.interpolation, true)
			last_sent.x = current.x
			last_sent.y = current.y
			last_sent.z = current.z
		end
	elseif send_dx >= cfg.deadband or send_dy >= cfg.deadband or send_dz >= cfg.deadband then
		x_player_api.set_bone_override(player, "Head", nil, current, true, cfg.interpolation, true)
		last_sent.x = current.x
		last_sent.y = current.y
		last_sent.z = current.z
	end

	local arms_active = cfg.enable_arm_tracking
		or (pstate.arm_last_sent_r.x ~= 0 or pstate.arm_last_sent_l.x ~= 0
			or pstate.arm_last_sent_l.y ~= 0 or pstate.arm_last_sent_l.z ~= 0
			or pstate.arm_last_sent_l_b3d.x ~= 0 or pstate.arm_last_sent_l_b3d.y ~= 0
			or pstate.arm_last_sent_l_b3d.z ~= 0)
	if arms_active then
		local send_ar = math.abs(arm_current_r.x - pstate.arm_last_sent_r.x)
			+ math.abs(arm_current_r.y - pstate.arm_last_sent_r.y)
			+ math.abs(arm_current_r.z - pstate.arm_last_sent_r.z)
		local send_al = math.abs(arm_current_l.x - pstate.arm_last_sent_l.x)
			+ math.abs(arm_current_l.y - pstate.arm_last_sent_l.y)
			+ math.abs(arm_current_l.z - pstate.arm_last_sent_l.z)
			+ math.abs(arm_current_l_b3d.x - pstate.arm_last_sent_l_b3d.x)
			+ math.abs(arm_current_l_b3d.y - pstate.arm_last_sent_l_b3d.y)
			+ math.abs(arm_current_l_b3d.z - pstate.arm_last_sent_l_b3d.z)

		if is_arm_converged then
			if send_ar > 0.001 or send_al > 0.001 then
				x_player_api.set_bone_override(player, "Arm_Right", nil, arm_current_r, true, cfg.interpolation, false)
				x_player_api.set_bone_override(player, "Arm_Left", nil, arm_current_l, true, cfg.interpolation,
					false, arm_current_l_b3d)
				pstate.arm_last_sent_r.x = arm_current_r.x
				pstate.arm_last_sent_r.y = arm_current_r.y
				pstate.arm_last_sent_r.z = arm_current_r.z
				pstate.arm_last_sent_l.x = arm_current_l.x
				pstate.arm_last_sent_l.y = arm_current_l.y
				pstate.arm_last_sent_l.z = arm_current_l.z
				pstate.arm_last_sent_l_b3d.x = arm_current_l_b3d.x
				pstate.arm_last_sent_l_b3d.y = arm_current_l_b3d.y
				pstate.arm_last_sent_l_b3d.z = arm_current_l_b3d.z
			end
		elseif send_ar >= cfg.deadband or send_al >= cfg.deadband then
			x_player_api.set_bone_override(player, "Arm_Right", nil, arm_current_r, true, cfg.interpolation, false)
			x_player_api.set_bone_override(player, "Arm_Left", nil, arm_current_l, true, cfg.interpolation,
				false, arm_current_l_b3d)
			pstate.arm_last_sent_r.x = arm_current_r.x
			pstate.arm_last_sent_r.y = arm_current_r.y
			pstate.arm_last_sent_r.z = arm_current_r.z
			pstate.arm_last_sent_l.x = arm_current_l.x
			pstate.arm_last_sent_l.y = arm_current_l.y
			pstate.arm_last_sent_l.z = arm_current_l.z
			pstate.arm_last_sent_l_b3d.x = arm_current_l_b3d.x
			pstate.arm_last_sent_l_b3d.y = arm_current_l_b3d.y
			pstate.arm_last_sent_l_b3d.z = arm_current_l_b3d.z
		end
	end

	if is_head_converged and is_arm_converged then
		pstate.sleeping = true
	end
end
head_tracking.step_player = x_player_api.step_head_tracking

---Enable or disable head and arm tracking for a specific player
---Resets bones to bind pose immediately if disabled.
---@param player ObjectRef Target player
---@param enabled boolean Activation flag
function x_player_api.set_head_tracking_enabled(player, enabled)
	local pstate = get_or_create_state(player)
	if pstate then
		pstate.enabled = not not enabled
		if not pstate.enabled then
			x_player_api.reset_head_tracking(player)
		end
	end
end
head_tracking.set_enabled = x_player_api.set_head_tracking_enabled

---Check whether head and arm tracking is active for a player
---@nodiscard
---@param player ObjectRef Target player
---@return boolean enabled Whether tracking is currently active for this player
function x_player_api.is_head_tracking_enabled(player)
	local pstate = get_or_create_state(player)
	return (pstate ~= nil) and pstate.enabled and head_tracking.config.enable
end
head_tracking.is_enabled = x_player_api.is_head_tracking_enabled

---Reset head and arm rotations to bind pose (0, 0, 0) and sleep state
---Dispatches immediate bone overrides to restore the default animation bind pose.
---@param player ObjectRef Target player
function x_player_api.reset_head_tracking(player)
	local pstate = get_or_create_state(player)
	if not pstate then return end

	pstate.current.x = 0
	pstate.current.y = 0
	pstate.current.z = 0
	pstate.target.x = 0
	pstate.target.y = 0
	pstate.target.z = 0
	pstate.last_sent.x = 0
	pstate.last_sent.y = 0
	pstate.last_sent.z = 0

	pstate.arm_current_r.x = 0; pstate.arm_current_r.y = 0; pstate.arm_current_r.z = 0
	pstate.arm_current_l.x = 0; pstate.arm_current_l.y = 0; pstate.arm_current_l.z = 0
	pstate.arm_current_l_b3d.x = 0; pstate.arm_current_l_b3d.y = 0; pstate.arm_current_l_b3d.z = 0
	pstate.arm_target_r.x = 0; pstate.arm_target_r.y = 0; pstate.arm_target_r.z = 0
	pstate.arm_target_l.x = 0; pstate.arm_target_l.y = 0; pstate.arm_target_l.z = 0
	pstate.arm_target_l_b3d.x = 0; pstate.arm_target_l_b3d.y = 0; pstate.arm_target_l_b3d.z = 0
	pstate.arm_last_sent_r.x = 0; pstate.arm_last_sent_r.y = 0; pstate.arm_last_sent_r.z = 0
	pstate.arm_last_sent_l.x = 0; pstate.arm_last_sent_l.y = 0; pstate.arm_last_sent_l.z = 0
	pstate.arm_last_sent_l_b3d.x = 0; pstate.arm_last_sent_l_b3d.y = 0; pstate.arm_last_sent_l_b3d.z = 0

	pstate.sleeping = true
	pstate.virtual_body_yaw = (player and player:get_look_horizontal()) or 0

	local interp = head_tracking.config.interpolation
	x_player_api.set_bone_override(player, "Head", nil, pstate.current, true, interp, true)
	x_player_api.set_bone_override(player, "Arm_Right", nil, pstate.arm_current_r, true, interp, false)
	x_player_api.set_bone_override(player, "Arm_Left", nil, pstate.arm_current_l, true, interp,
		false, pstate.arm_current_l_b3d)
end
head_tracking.reset = x_player_api.reset_head_tracking

---Immediately re-sends current smoothed head and arm bone overrides to all proxies (e.g. on model/format toggle)
---@param player ObjectRef Target player
function x_player_api.refresh_head_tracking(player)
	local pstate = get_or_create_state(player)
	if not pstate or not pstate.enabled then return end
	local interp = head_tracking.config.interpolation
	x_player_api.set_bone_override(player, "Head", nil, pstate.current, true, interp, true)
	if head_tracking.config.enable_arm_tracking then
		x_player_api.set_bone_override(player, "Arm_Right", nil, pstate.arm_current_r, true, interp, false)
		x_player_api.set_bone_override(player, "Arm_Left", nil, pstate.arm_current_l, true, interp,
			false, pstate.arm_current_l_b3d)
	end
	pstate.sleeping = false
end
head_tracking.refresh = x_player_api.refresh_head_tracking

---Get the current smoothed head rotation vector for a player
---@nodiscard
---@param player ObjectRef Target player
---@return Vector3? rotation Smoothed head rotation vector {x, y, z} in radians, or nil if player invalid
function x_player_api.get_head_rotation(player)
	local pstate = get_or_create_state(player)
	return pstate and pstate.current
end
head_tracking.get_head_rotation = x_player_api.get_head_rotation

---Get the current smoothed arm rotation vectors for a player
---@nodiscard
---@param player ObjectRef Target player
---@return Vector3? right_arm Smoothed rotation vector for Arm_Right in radians
---@return Vector3? left_arm Smoothed rotation vector for Arm_Left in radians
function x_player_api.get_head_tracking_arm_rotations(player)
	local pstate = get_or_create_state(player)
	if not pstate then return nil, nil end
	return pstate.arm_current_r, pstate.arm_current_l
end
head_tracking.get_arm_rotations = x_player_api.get_head_tracking_arm_rotations

---Get the current smoothed arm rotation vectors for a player (alias)
---@nodiscard
---@param player ObjectRef Target player
---@return Vector3? right_arm Smoothed rotation vector for Arm_Right in radians
---@return Vector3? left_arm Smoothed rotation vector for Arm_Left in radians
function x_player_api.get_arm_rotations(player)
	return x_player_api.get_head_tracking_arm_rotations(player)
end

---Get the current smoothed arm rotation vectors for B3D space
---@nodiscard
---@param player ObjectRef Target player
---@return Vector3? right_arm Smoothed rotation vector for Arm_Right in B3D space
---@return Vector3? left_arm Smoothed rotation vector for Arm_Left in B3D space
function x_player_api.get_head_tracking_arm_rotations_b3d(player)
	local pstate = get_or_create_state(player)
	if not pstate then return nil, nil end
	return {x = -pstate.arm_current_r.x, y = -pstate.arm_current_r.y, z = -pstate.arm_current_r.z},
		pstate.arm_current_l_b3d
end
head_tracking.get_arm_rotations_b3d = x_player_api.get_head_tracking_arm_rotations_b3d

---Register a custom head tracking modifier callback (Open/Closed Principle)
---Allows external mods to dynamically adjust target rotation angles and posture weight.
---@param name string Unique modifier identifier
---@param func HeadTrackingModifier Callback function receiving (player, semantic_state, ctx)
function x_player_api.register_head_tracking_modifier(name, func)
	head_tracking.modifiers[name] = func
end
head_tracking.register_modifier = x_player_api.register_head_tracking_modifier

---Unregister a custom head tracking modifier
---@param name string Modifier identifier to remove
function x_player_api.unregister_head_tracking_modifier(name)
	head_tracking.modifiers[name] = nil
end
head_tracking.unregister_modifier = x_player_api.unregister_head_tracking_modifier

---Purge tracking state on player disconnect
---@param player_name string Player name
function head_tracking.cleanup(player_name)
	states[player_name] = nil
end

--------------------------------------------------------------------------------
-- Lifecycle Registrations
--------------------------------------------------------------------------------

core.register_on_joinplayer(function(player)
	if player and player.get_player_name then
		init_player_state(player:get_player_name(), player)
	end
end)

core.register_on_leaveplayer(function(player)
	if player and player.get_player_name then
		head_tracking.cleanup(player:get_player_name())
	end
end)

core.register_on_respawnplayer(function(player)
	if player then
		head_tracking.reset(player)
	end
end)
