-- x_player_api emotes management module
-- Provides social emote and posture registry, playback, and chatcommands.

---@class EmoteDefinition
---@field is_posture boolean|nil Whether this emote is a posture (handled via locomotion layer, cancelled on movement)
---@field duration number|nil Default duration in seconds (-1 for continuous/infinite)
---@field description string|nil Chatcommand description
---@field msg string|nil Chatcommand response message

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

local S = core.get_translator(core.get_current_modname())

-- Default emote duration (in seconds)
local DEFAULT_EMOTE_DURATION = 2.0
local enable_emote_chatcommands = core.settings:get_bool("x_player_api.enable_emote_chatcommands", true)

---@type table<string, EmoteDefinition>
x_player_api.registered_emotes = x_player_api.registered_emotes or {}
local registered_emotes = x_player_api.registered_emotes

---Register a player emote
---@param name string Emote animation / command name
---@param def EmoteDefinition Emote definition
function x_player_api.register_emote(name, def)
	registered_emotes[name] = def
	if def.description and enable_emote_chatcommands then
		local reg_cmds = core.registered_chatcommands
		if not (reg_cmds and reg_cmds[name]) then
			core.register_chatcommand(name, {
				description = def.description,
				func = function(player_name)
					local player = core.get_player_by_name(player_name)
					if not player then return false, S("Player not found") end
					local states = x_player_api.controls.player_states
					local pstate = states and states[player_name]
					if def.is_posture and pstate and pstate.active_emote == name then
						x_player_api.stop_emote(player)
						return true, S("Standing up")
					end
					local duration = def.duration or (def.is_posture and -1 or DEFAULT_EMOTE_DURATION)
					x_player_api.play_emote(player, name, duration)
					return true, def.msg or S("Playing gesture: @1", name)
				end,
			})
		end
	end
end

---Play a gesture or posture emote
---@param player ObjectRef
---@param emote_name string
---@param duration number|nil
function x_player_api.play_emote(player, emote_name, duration)
	if not player or not player.is_player or not player:is_player() then return end
	if player:get_hp() <= 0 then return end
	local name = player:get_player_name()
	local states = x_player_api.controls.player_states
	local pstate = states and states[name]
	if not pstate then return end
	local def = registered_emotes[emote_name]
	duration = duration or (def and def.duration) or DEFAULT_EMOTE_DURATION
	local time_now = core.get_us_time() * 0.000001
	pstate.active_emote = emote_name
	pstate.emote_until = (duration == -1) and -1 or (time_now + duration)

	-- Full-body postures (sit, lay, bow, etc.) are handled strictly via the locomotion layer
	local is_posture = (def and def.is_posture) or (emote_name == "sit" or emote_name == "lay" or emote_name == "bow")
	if not is_posture then
		x_player_api.play_action(player, emote_name, true)
	end
end

---Stop any active gesture or posture emote
---@param player ObjectRef
function x_player_api.stop_emote(player)
	if not player or not player.is_player or not player:is_player() then return end
	local name = player:get_player_name()
	local states = x_player_api.controls.player_states
	local pstate = states and states[name]
	if not pstate then return end
	if pstate.active_emote then
		x_player_api.play_action(player, nil)
	end
	pstate.active_emote = nil
	pstate.emote_until = 0
end

-- Register standard gestures and postures via Emote Registry
x_player_api.register_emote("wave", {
	is_posture = false,
	duration = DEFAULT_EMOTE_DURATION,
	description = S("Perform the wave gesture"),
	msg = S("Playing gesture: wave"),
})
x_player_api.register_emote("point", {
	is_posture = false,
	duration = DEFAULT_EMOTE_DURATION,
	description = S("Perform the point gesture"),
	msg = S("Playing gesture: point"),
})
x_player_api.register_emote("cheer", {
	is_posture = false,
	duration = DEFAULT_EMOTE_DURATION,
	description = S("Perform the cheer gesture"),
	msg = S("Playing gesture: cheer"),
})
x_player_api.register_emote("bow", {
	is_posture = true,
	duration = 2.0,
	description = S("Perform a courtly bow (single graceful bow)"),
	msg = S("Bowing respectfully"),
})
x_player_api.register_emote("sit", {
	is_posture = true,
	duration = -1,
	description = S("Sit down on the ground (move to stand up)"),
	msg = S("Sitting down (move to stand up)"),
})
x_player_api.register_emote("lay", {
	is_posture = true,
	duration = -1,
	description = S("Lie down on the ground (move to stand up)"),
	msg = S("Lying down (move to stand up)"),
})
