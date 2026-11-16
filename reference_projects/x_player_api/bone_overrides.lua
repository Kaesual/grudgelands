-- x_player_api/bone_overrides.lua
-- Dedicated module to handle the network throttle state and logic for bone attachments.

x_player_api = x_player_api or player_api

---@class BoneOverridePayload
---@field vec Vector3 Transformation vector
---@field absolute boolean Absolute vs relative transformation flag
---@field interpolation number Client-side interpolation duration in seconds

---@class BoneOverrideEntry
---@field rotation BoneOverridePayload Rotation payload
---@field position? BoneOverridePayload Translation payload

---@class CachedBoneState
---@field position Vector3 Local position offset vector {x, y, z} in GLB space
---@field rotation Vector3 Local rotation vector in radians {x, y, z} in GLB space
---@field b3d_position Vector3 Compensated local position offset vector for B3D space
---@field b3d_rotation Vector3 Compensated local rotation vector for B3D space
---@field override_glb BoneOverrideEntry Pre-allocated payload container for GLB proxy
---@field override_b3d BoneOverrideEntry Pre-allocated payload container for B3D proxy

---Cached bone transformations for network throttling and dual-format routing
---@type table<string, table<string, CachedBoneState>>
x_player_api.bone_caches = {}

---Set a bone position and rotation override with network throttling and dual-format parity
---Applies pitch, yaw, and roll rotation to visual proxy entities.
---Automatically compensates for Blitz3D exporter bone coordinate inversions (negated rotation axes
---and reflected X/Z position) so GLB and B3D visual proxies maintain identical orientation in-game.
---Optionally accepts an explicit B3D rotation payload for bones with complex dual-rig kinematics
---(e.g. Arm_Left bow aim).
---Throttles Head and Arm bone updates below 0.08 radians (~4.5 degrees) to optimize multiplayer bandwidth.
---@param player ObjectRef Target player
---@param bone string Target bone name (e.g. "Head", "Arm_Right", "Arm_Left")
---@param position Vector3|nil Local bone translation offset (omitted if nil to preserve bone rest position)
---@param rotation Vector3 Local bone rotation in radians
---@param force? boolean Optional flag to bypass angular delta throttling
---@param interpolation? number Optional interpolation duration in seconds (default: 0.1)
---@param absolute? boolean Optional flag indicating whether rotation/position is absolute (default: true)
---@param b3d_rotation? Vector3 Optional explicit B3D rotation override vector in radians
function x_player_api.set_bone_override(player, bone, position, rotation, force, interpolation, absolute, b3d_rotation)
	if not player or not player.is_player or not player:is_player() then return end
	local name = player:get_player_name()
	local is_pure_b3d = x_player_api.is_pure_native_b3d_active(player)
	local proxies = not is_pure_b3d and x_player_api.get_visual_proxies(player)

	if not is_pure_b3d and not proxies then return end

	local p_cache = x_player_api.bone_caches[name]
	if not p_cache then
		p_cache = {}
		x_player_api.bone_caches[name] = p_cache
	end

	local cache = p_cache[bone]
	if not cache then
		local rot_glb = {x = 0, y = 0, z = 0}
		local rot_b3d = {x = 0, y = 0, z = 0}
		local pos_glb = {x = 0, y = 0, z = 0}
		local pos_b3d = {x = 0, y = 0, z = 0}
		cache = {
			position = pos_glb,
			rotation = rot_glb,
			b3d_position = pos_b3d,
			b3d_rotation = rot_b3d,
			override_glb = {
				rotation = {
					vec = rot_glb,
					absolute = true,
					interpolation = 0.1,
				},
			},
			override_b3d = {
				rotation = {
					vec = rot_b3d,
					absolute = true,
					interpolation = 0.1,
				},
			},
		}
		p_cache[bone] = cache
	end

	local rot_x = rotation and rotation.x or 0
	local rot_y = rotation and rotation.y or 0
	local rot_z = rotation and rotation.z or 0

	-- Throttle pitch tracking for "Head", "Arm_Right", "Arm_Left" bones using
	-- ~0.08 radian (~4.5 degree) delta unless force is true
	if (bone == "Head" or bone == "Arm_Right" or bone == "Arm_Left") and not force then
		local pitch_delta = math.abs(cache.rotation.x - rot_x)
		local yaw_delta = math.abs(cache.rotation.y - rot_y)
		local roll_delta = math.abs(cache.rotation.z - rot_z)

		if pitch_delta < 0.08 and yaw_delta < 0.08 and roll_delta < 0.08 then
			return -- Skip sending packet to proxies
		end
	end

	local is_abs = (absolute == nil) or (absolute == true)
	local interp = interpolation or 0.1

	-- Mutate cache vectors in-place to avoid Lua table allocations on hot loop
	local cr = cache.rotation
	cr.x, cr.y, cr.z = rot_x, rot_y, rot_z

	-- In B3D bone coordinate space, the Blitz3D exporter's transformation matrix
	-- (BONE_TRANS_MATRIX) combined with left-handed skeletal orientation inverts
	-- local bone rotation axes for symmetric single-axis rotations: X' = -X, Y' = -Y, Z' = -Z.
	-- For complex dual-arm interactions (e.g. Arm_Left locking onto the bow grip),
	-- an explicit b3d_rotation payload or dedicated inverse kinematics mapping is used
	-- to prevent the left arm from rotating outward to the side of the body.
	local b3d_cr = cache.b3d_rotation
	if b3d_rotation then
		b3d_cr.x = b3d_rotation.x or 0
		b3d_cr.y = b3d_rotation.y or 0
		b3d_cr.z = b3d_rotation.z or 0
	elseif bone == "Arm_Left" and not is_abs and (rot_y ~= 0 or rot_z ~= 0) then
		if rot_x >= 0 then
			local p = rot_x / 0.50
			local p2 = p * p
			b3d_cr.x = 0.50 * p2 - 1.45 * p
			b3d_cr.y = 0.95 * p2 + 0.25 * p
			b3d_cr.z = -0.60 * p
		else
			local p = rot_x / 0.78
			b3d_cr.x = -0.90 * p
			local y_val = 0.65 * p
			if y_val < -0.28 then y_val = -0.28 end
			b3d_cr.y = y_val
			b3d_cr.z = 0.15 * p
		end
	else
		b3d_cr.x = -rot_x
		b3d_cr.y = -rot_y
		b3d_cr.z = -rot_z
	end

	local ov_glb = cache.override_glb
	local ov_b3d = cache.override_b3d
	ov_glb.rotation.absolute = is_abs
	ov_glb.rotation.interpolation = interp
	ov_b3d.rotation.absolute = is_abs
	ov_b3d.rotation.interpolation = interp

	if position then
		local pos_x = position.x or 0
		local pos_y = position.y or 0
		local pos_z = position.z or 0

		local cp = cache.position
		cp.x, cp.y, cp.z = pos_x, pos_y, pos_z

		local b3d_cp = cache.b3d_position
		b3d_cp.x = -pos_x
		b3d_cp.y = pos_y
		b3d_cp.z = -pos_z

		if not ov_glb.position then
			ov_glb.position = { vec = cp, absolute = is_abs, interpolation = interp }
			ov_b3d.position = { vec = b3d_cp, absolute = is_abs, interpolation = interp }
		else
			ov_glb.position.absolute = is_abs
			ov_glb.position.interpolation = interp
			ov_b3d.position.absolute = is_abs
			ov_b3d.position.interpolation = interp
		end
	else
		local cp = cache.position
		cp.x, cp.y, cp.z = 0, 0, 0
		local b3d_cp = cache.b3d_position
		b3d_cp.x, b3d_cp.y, b3d_cp.z = 0, 0, 0
		ov_glb.position = nil
		ov_b3d.position = nil
	end

	if is_pure_b3d then
		if player.set_bone_override then
			player:set_bone_override(bone, ov_b3d)
		end
		return
	end

	if proxies.glb and proxies.glb:is_valid() then
		proxies.glb:set_bone_override(bone, ov_glb)
	end
	if proxies.b3d and proxies.b3d:is_valid() then
		proxies.b3d:set_bone_override(bone, ov_b3d)
	end
end

---Get the active bone override state for a player
---@nodiscard
---@param player ObjectRef Target player
---@param bone string Target bone name
---@return CachedBoneState|nil override Cached bone state or nil
function x_player_api.get_bone_override(player, bone)
	if not player or not player.is_player or not player:is_player() then return nil end
	local name = player:get_player_name()
	local p_cache = x_player_api.bone_caches[name]
	return p_cache and p_cache[bone]
end

-- Metatable wrapping for set_bone_override is consolidated idempotently in
-- x_player_api.wrap_player_metatable within proxies.lua

core.register_on_leaveplayer(function(player)
	if player then
		x_player_api.bone_caches[player:get_player_name()] = nil
	end
end)

core.register_on_respawnplayer(function(player)
	if player then
		x_player_api.bone_caches[player:get_player_name()] = nil
	end
end)
