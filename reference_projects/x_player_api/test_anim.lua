-- x_player_api test animations module
-- Provides debug and test chat commands and sequence playback for player animations.

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

local S = core.get_translator(core.get_current_modname())

local CANONICAL_SHOWCASE_ORDER = {
	-- Locomotion & Postures (Track 0)
	"stand", "walk", "sprint", "crouch", "crouch_walk", "slide",
	"jump", "fall", "swim", "climb", "fly", "hover", "sit", "lay", "bow",
	-- Actions & Combat (Track 1)
	"mine", "walk_mine", "block", "attack_slash", "attack_thrust",
	"eat", "walk_eat", "bow_aim", "walk_bow_aim", "bow_shoot", "hurt", "equip",
	-- Gestures (Track 1)
	"wave", "point", "cheer"
}

---@type table<string, {anim_list: string[], duration: number, cancelled: boolean}>
local anim_test_sessions = {}

---Stop any active animation test showcase and restore player animations
---@param name string Player name
---@param quiet? boolean Suppress user chat notification
function x_player_api.stop_anim_test(name, quiet)
	local session = anim_test_sessions[name]
	if session then
		session.cancelled = true
		anim_test_sessions[name] = nil
	end
	local states = x_player_api.controls.player_states
	local pstate = states and states[name]
	if pstate then
		pstate.test_anim = nil
		pstate.test_anim_is_action = nil
	end
	local player = core.get_player_by_name(name)
	if player then
		x_player_api.play_action(player, nil, true, true)
		x_player_api.set_animation(player, "stand", nil, true, false, false)
		if x_player_api.step_b3d_animation then
			local anim_data = x_player_api.get_animation(player)
			local def_model = x_player_api.get_default_model() or "character.glb"
			local model_name = anim_data and anim_data.model or def_model
			local model = x_player_api.registered_models[model_name]
				or x_player_api.registered_models[def_model]
			if model then
				local state = x_player_api.get_player_state and x_player_api.get_player_state(player) or {}
				x_player_api.step_b3d_animation(player, state, model, model.animation_speed or 30)
			end
		end
	end
	if not quiet and player then
		core.chat_send_player(name, core.colorize("#FFAA00",
			S("[x_player_api] Animation showcase stopped. Restored normal player animations.")))
	end
end

---Step to next animation in active test session
---@param name string Player name
---@param session {anim_list: string[], duration: number, cancelled: boolean} Active test session table
---@param idx integer Current animation index in session anim_list
local function step_anim_test(name, session, idx)
	if session.cancelled then
		return
	end
	local player = core.get_player_by_name(name)
	if not player or player:get_hp() <= 0 then
		x_player_api.stop_anim_test(name, true)
		return
	end

	local anim_list = session.anim_list
	local duration = session.duration

	if idx > #anim_list then
		core.chat_send_player(name, core.colorize("#00FF88",
			S("[x_player_api] Animation showcase completed! Successfully tested all @1 animations.", #anim_list)))
		x_player_api.stop_anim_test(name, true)
		return
	end

	local anim_name = anim_list[idx]
	local states = x_player_api.controls.player_states
	local pstate = states and states[name]
	if not pstate then
		x_player_api.stop_anim_test(name, true)
		return
	end

	local anim_data = x_player_api.get_animation(player)
	local def_model = x_player_api.get_default_model() or "character.glb"
	local model_name = anim_data and anim_data.model or def_model
	local model = x_player_api.registered_models[model_name]
		or x_player_api.registered_models[def_model]
		or x_player_api.registered_models["character.glb"]
	local anim_def = model and ((model.animations_glb and model.animations_glb[anim_name])
		or (model.animations and model.animations[anim_name])) or {}
	local is_action = anim_def.is_action == true

	pstate.test_anim = anim_name
	pstate.test_anim_is_action = is_action

	-- Immediate animation application
	local speed = model and model.animation_speed or 30
	local loop = anim_def and anim_def.loop ~= false
	if is_action then
		x_player_api.play_action(player, anim_name, true, true)
		x_player_api.set_animation(player, "stand", speed, true, true, false)
		if x_player_api.step_b3d_animation then
			local state = x_player_api.get_player_state and x_player_api.get_player_state(player) or {}
			state.test_anim = anim_name
			x_player_api.step_b3d_animation(player, state, model, speed)
		end
		if anim_name == "eat" then
			local time_now = core.get_us_time() * 0.000001
			pstate.eat_until = time_now + duration
			pstate.eat_action = "eat"
			if x_player_api.spawn_eat_particles then
				x_player_api.spawn_eat_particles(player, nil, duration)
			end
		end
		-- If true one-shot combat action (e.g. hurt, bow_shoot), schedule clean repeating triggers
		-- Sustained postures (block, bow_aim) and continuous actions (eat, mine, attack_*, emotes) never retrigger
		local is_sustained = (anim_name == "block" or anim_name == "bow_aim" or anim_name == "eat"
			or anim_name == "mine" or anim_name:find("^walk_") or anim_name == "wave"
			or anim_name == "point" or anim_name == "cheer" or anim_name:find("^attack_"))
		local is_oneshot = not is_sustained and ((anim_def.loop == false)
			or (model and model.animations and model.animations[anim_name] and model.animations[anim_name].loop == false))
		if is_oneshot and duration > 0.8 then
			local repeat_interval = 0.8
			local repeat_count = math.floor(duration / repeat_interval)
			for r = 1, repeat_count do
				local trigger_delay = r * repeat_interval
				if trigger_delay < duration - 0.15 then
					core.after(trigger_delay, function()
						if not session.cancelled and pstate.test_anim == anim_name then
							local p = core.get_player_by_name(name)
							if p and p:get_hp() > 0 then
								x_player_api.play_action(p, anim_name, true, true)
								if x_player_api.step_b3d_animation then
									pstate.retrigger_b3d = true
									local state = x_player_api.get_player_state and x_player_api.get_player_state(p) or {}
									state.test_anim = anim_name
									x_player_api.step_b3d_animation(p, state, model, speed)
								end
							end
						end
					end)
				end
			end
		end
	else
		if anim_name == "walk_bow_aim" then
			x_player_api.play_action(player, "bow_aim", true, true)
			x_player_api.set_animation(player, "walk", speed, loop, true, false)
		elseif anim_name == "walk_eat" then
			x_player_api.play_action(player, "eat", true, true)
			x_player_api.set_animation(player, "walk", speed, loop, true, false)
		elseif anim_name == "walk_mine" and not (model and model.animations_glb and model.animations_glb.walk_mine) then
			x_player_api.play_action(player, "mine", true, true)
			x_player_api.set_animation(player, "walk", speed, loop, true, false)
		else
			x_player_api.play_action(player, nil, true, true)
			x_player_api.set_animation(player, anim_name, speed, loop, true, false)
		end
		if x_player_api.step_b3d_animation then
			local state = x_player_api.get_player_state and x_player_api.get_player_state(player) or {}
			state.test_anim = anim_name
			x_player_api.step_b3d_animation(player, state, model, speed)
		end
		if anim_name == "eat" or anim_name == "walk_eat" then
			local time_now = core.get_us_time() * 0.000001
			pstate.eat_until = time_now + duration
			pstate.eat_action = "eat"
			if x_player_api.spawn_eat_particles then
				x_player_api.spawn_eat_particles(player, nil, duration)
			end
		end
	end

	-- Announce in private chat message to the admin
	local track_label = is_action and S("Action Track (Track 1)") or S("Locomotion Track (Track 0)")
	local loop_label = (anim_def.loop ~= false) and S("Looping") or S("One-shot (repeating)")
	local msg = core.colorize("#00FFFF", string.format("[x_player_api] [%d/%d] ", idx, #anim_list))
		.. core.colorize("#FFFF00", string.format(">> %s <<", anim_name))
		.. core.colorize("#DDDDDD", string.format(" | %s | %s | %.1fs", track_label, loop_label, duration))
	core.chat_send_player(name, msg)

	-- Schedule next animation step
	core.after(duration, function()
		if not session.cancelled then
			step_anim_test(name, session, idx + 1)
		end
	end)
end

---Start an animation showcase or single animation test for player
---@param player ObjectRef Target player
---@param duration? number Duration per animation in seconds (default: 4.0)
---@param specific_anim? string Optional specific animation identifier to test
---@return boolean success Whether test was started
---@return string? error_message Error message on failure
function x_player_api.start_anim_test(player, duration, specific_anim)
	local name = player:get_player_name()
	x_player_api.stop_anim_test(name, true)

	local anim_data = x_player_api.get_animation(player)
	local def_model = x_player_api.get_default_model() or "character.glb"
	local model_name = anim_data and anim_data.model or def_model
	local model = x_player_api.registered_models[model_name]
		or x_player_api.registered_models[def_model]
		or x_player_api.registered_models["character.glb"]
		or x_player_api.registered_models["character.b3d"]

	if not model or not model.animations then
		return false, S("No animations registered for current player model (@1)", tostring(model_name))
	end

	local anim_list = {}
	if specific_anim then
		if not model.animations[specific_anim] then
			return false, S("Animation '@1' not found on model @2", specific_anim, model_name)
		end
		table.insert(anim_list, specific_anim)
	else
		local seen = {}
		for _, a in ipairs(CANONICAL_SHOWCASE_ORDER) do
			if model.animations[a] then
				table.insert(anim_list, a)
				seen[a] = true
			end
		end
		for a, _ in pairs(model.animations) do
			if not seen[a] and type(a) == "string" then
				table.insert(anim_list, a)
			end
		end
	end

	duration = math.max(1.0, duration or 4.0)
	local session = {
		anim_list = anim_list,
		duration = duration,
		cancelled = false,
	}
	anim_test_sessions[name] = session

	if specific_anim then
		local start_msg = S(
			"[x_player_api] Testing single animation '@1' for @2s. Type /test_anim stop to cancel.",
			specific_anim, string.format("%.1f", duration))
		core.chat_send_player(name, core.colorize("#00FF88", start_msg))
	else
		local start_msg = S(
			"[x_player_api] Starting animation slideshow: @1 animations, @2s each. Type /test_anim stop to cancel.",
			#anim_list, string.format("%.1f", duration))
		core.chat_send_player(name, core.colorize("#00FF88", start_msg))
	end

	step_anim_test(name, session, 1)
	return true
end

core.register_chatcommand("test_anim", {
	params = S("[duration|anim_name|stop|list] [duration]"),
	description = S("Admin animation test suite & slideshow. Displays all animations in private chat and on character."),
	privs = {server = true},
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("Player not found.")
		end

		param = param and (param.trim and param:trim() or param:match("^%s*(.-)%s*$")) or ""
		local args = {}
		for w in param:gmatch("%S+") do
			table.insert(args, w)
		end

		local first = args[1]
		if first == "stop" or first == "cancel" or first == "reset" then
			x_player_api.stop_anim_test(name, false)
			return true
		end

		if first == "list" then
			local anim_data = x_player_api.get_animation(player)
			local def_model = x_player_api.get_default_model() or "character.glb"
			local model_name = anim_data and anim_data.model or def_model
			local model = x_player_api.registered_models[model_name]
				or x_player_api.registered_models[def_model]
				or x_player_api.registered_models["character.glb"]
				or x_player_api.registered_models["character.b3d"]
			if not model or not model.animations then
				return false, S("No animations found for model.")
			end
			local list = {}
			for a, _ in pairs(model.animations) do
				table.insert(list, a)
			end
			table.sort(list)
			core.chat_send_player(name, core.colorize("#00FFFF",
					S("[x_player_api] Registered animations for @1 (@2): ", model_name, #list))
				.. table.concat(list, ", "))
			return true
		end

		local duration = tonumber(first)
		local specific_anim = nil

		if not duration and first and first ~= "" then
			specific_anim = first
			duration = tonumber(args[2]) or 4.0
		else
			duration = duration or 4.0
		end

		local success, msg = x_player_api.start_anim_test(player, duration, specific_anim)
		if not success then
			return false, msg
		end
		return true
	end,
})

-- Aliases for convenience
core.register_chatcommand("anim_test", {
	params = S("[duration|anim_name|stop|list] [duration]"),
	description = S("Alias for /test_anim"),
	privs = {server = true},
	func = function(name, param)
		return core.chatcommands["test_anim"].func(name, param)
	end,
})

-- Cleanup on leave
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	x_player_api.stop_anim_test(name, true)
end)

-- Cancel active test animation on player death
core.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	x_player_api.stop_anim_test(name, true)
end)
