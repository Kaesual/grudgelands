-- x_player_api/legacy_b3d.lua
-- Dedicated module for B3D single-timeline legacy model animation evaluation.
-- Completely decoupled from modern glTF multi-track animation pathways.
-- Evaluates animation state directly from input controls and hand item without hold timers.

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

---Safe trigger forwarder for backwards compatibility
---@deprecated Use x_player_api.trigger_player_action directly
function x_player_api.trigger_b3d_action(player, action, duration)
	if x_player_api.trigger_player_action then
		x_player_api.trigger_player_action(player, action, duration)
	end
end

---Evaluate and resolve the single-timeline animation specifically for B3D models
---Pure input/state-driven evaluation for single-timeline models
---@nodiscard
---@param player ObjectRef Target player
---@param state PlayerSemanticState Semantic player state evaluated by controls module
---@param model table Active model definition
---@return string chosen_anim Evaluated single-timeline animation identifier
function x_player_api.evaluate_b3d_animation(player, state, model)
	local anims = model.animations or {}
	local loco = state.locomotion or "stand"

	-- Death and vehicle attachment
	if player:get_hp() <= 0 then
		return "lay"
	end
	local name = player:get_player_name()
	local is_attached = x_player_api.player_attached[name] or (player:get_attach() ~= nil)
	if is_attached then
		return loco
	end

	-- Check test_anim showcase override if active
	local pstate = x_player_api.controls and x_player_api.controls.player_states[name]
	local test_anim = state.test_anim or (pstate and pstate.test_anim)
	if test_anim then
		if anims[test_anim] then
			return test_anim
		elseif anims[loco] then
			return loco
		else
			return "stand"
		end
	end

	-- Determine active action directly from state and controls
	local action = state.action
	if not action then
		local controls = (pstate and pstate.controls) or player:get_player_control()
		local item_info = (pstate and pstate.item_info)
		if not item_info and x_player_api.controls and x_player_api.controls.classify_item then
			item_info = x_player_api.controls.classify_item(player:get_wielded_item():get_name())
		end
		if (controls.LMB or controls.dig) and not (item_info and item_info.is_food) then
			action = (item_info and item_info.weapon_action) or "mine"
		elseif (controls.RMB or controls.place)
			and not (item_info and (item_info.is_shield or item_info.is_bow or item_info.is_food)) then
			action = (item_info and item_info.alt_action) or "mine"
		end
	end

	-- Resolve single-timeline animation priority
	if action then
		if state.moving then
			-- Moving while acting: use baked composite (walk_mine, walk_eat, etc.) if available
			if anims["walk_" .. action] then
				return "walk_" .. action
			elseif (action == "mine" or action:sub(1, 7) == "attack_" or action == "eat") and anims.walk_mine then
				return "walk_mine"
			elseif anims[action] then
				return action
			elseif anims[loco] then
				return loco
			else
				return "walk"
			end
		else
			-- Stationary while acting
			if anims[action] then
				return action
			elseif anims[loco] then
				return loco
			else
				return "stand"
			end
		end
	end

	-- No action active: return primary locomotion
	if anims[loco] then
		return loco
	elseif state.moving then
		return "walk"
	else
		return "stand"
	end
end

---Step and resolve single-timeline animations specifically for B3D models
---Directly drives B3D visual proxy and native player skeletal bones concurrently for all observers
---@param player ObjectRef Target player
---@param state PlayerSemanticState Semantic player state evaluated by controls module
---@param model table Active model definition
---@param animation_speed_mod number Calculated animation playback speed
function x_player_api.step_b3d_animation(player, state, model, animation_speed_mod)
	local chosen_anim = x_player_api.evaluate_b3d_animation(player, state, model)
	chosen_anim = x_player_api.animation_aliases[chosen_anim] or chosen_anim
	local anims = model.animations or {}
	local a_def = anims[chosen_anim] or anims.stand
	if not a_def or not a_def.x or not a_def.y then
		return
	end

	local name = player:get_player_name()
	local pdata = (x_player_api.get_player_data and x_player_api.get_player_data(player))
		or (x_player_api._players and x_player_api._players[name])
		or x_player_api.get_animation(player)
	if not pdata then return end

	local pstate = x_player_api.controls and x_player_api.controls.player_states[name]
	local cycle_count = pstate and pstate.lmb_cycle_count

	local loop = true
	if a_def.loop ~= nil then loop = a_def.loop end

	local base_fps = model.animation_speed or 30
	local speed_b3d = (animation_speed_mod <= 2.0 and (animation_speed_mod * base_fps) or animation_speed_mod)
		* (a_def.speed or 1.0)
	if animation_speed_mod == 0 then
		loop = false
	end

	local force_retrigger = false
	if cycle_count and pdata.last_b3d_cycle ~= cycle_count then
		pdata.last_b3d_cycle = cycle_count
		-- Only retrigger discrete, non-looping combat attacks (e.g. attack_slash, attack_thrust)
		-- Continuous actions (eat, block, bow_aim, equip) and looping actions (mine, walk_mine)
		-- must NEVER be forcefully reset by cycle_count.
		if not loop and (chosen_anim == "attack_slash" or chosen_anim == "attack_thrust"
				or chosen_anim:sub(1, 7) == "attack_") then
			force_retrigger = true
		end
	end
	if pstate and pstate.retrigger_b3d then
		pstate.retrigger_b3d = nil
		force_retrigger = true
	end

	-- Blend time: B3D single-timeline models default to 0 blend to eliminate
	-- sluggish input latency, limb drag-down on gestures, and attachment matrix artifacts.
	local blend = a_def.blend or 0
	if force_retrigger and pdata.animation_b3d == chosen_anim then
		blend = 0
	end

	-- Dedicated B3D cache check to avoid redundant network updates
	if pdata.animation_b3d == chosen_anim
		and pdata.animation_b3d_speed == speed_b3d
		and pdata.animation_b3d_loop == loop
		and not force_retrigger
	then
		return
	end

	pdata.animation_b3d = chosen_anim
	pdata.animation_b3d_speed = speed_b3d
	pdata.animation_b3d_loop = loop

	local active_format = x_player_api.get_model_format and x_player_api.get_model_format()
	if active_format == "b3d" or not model.is_multitrack then
		pdata.animation = chosen_anim
		pdata.animation_speed = speed_b3d
		pdata.animation_loop = loop
	end

	local is_pure_native = x_player_api.is_pure_native_b3d_active(player)

	if is_pure_native then
		-- In pure native B3D mode: manage local animation prediction vs extended animations
		local is_standard_local = (chosen_anim == "stand" or chosen_anim == "walk"
			or chosen_anim == "mine" or chosen_anim == "walk_mine") and not a_def.override_local

		if is_standard_local then
			if pdata.local_anim_silenced then
				local anims_all = model.animations or {}
				local stand = anims_all.stand and {x = anims_all.stand.x, y = anims_all.stand.y} or {x = 0, y = 0}
				local walk = anims_all.walk and {x = anims_all.walk.x, y = anims_all.walk.y} or {x = 0, y = 0}
				local mine = anims_all.mine and {x = anims_all.mine.x, y = anims_all.mine.y} or {x = 0, y = 0}
				local walk_mine = anims_all.walk_mine and {x = anims_all.walk_mine.x, y = anims_all.walk_mine.y} or {x = 0, y = 0}
				player:set_local_animation(stand, walk, mine, walk_mine, model.animation_speed or 30)
				pdata.local_anim_silenced = false
			end
		else
			if not pdata.local_anim_silenced then
				player:set_local_animation({x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, 0)
				pdata.local_anim_silenced = true
			end
		end

		-- Synchronize server animation to player ObjectRef (drives remote observers and local fallback)
		player:set_animation(a_def, speed_b3d, blend, loop)
	else
		-- Apply directly to B3D visual proxy
		local proxies = x_player_api.get_visual_proxies(player)
		if proxies and proxies.b3d and proxies.b3d:is_valid() then
			proxies.b3d:set_animation(a_def, speed_b3d, blend, loop)
		end

		-- Synchronize skeletal bone animation on native player ObjectRef
		player:set_animation(a_def, speed_b3d, blend, loop)
	end
end
