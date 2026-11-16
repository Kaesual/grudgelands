-- x_player_api equip sound management module
-- Provides declarative equip sound registry, pitch randomization, and audio playback.

---@class EquipSoundDefinition
---@field sound string|table Sound name string or SimpleSoundSpec table
---@field gain? number Playback gain/volume (default: 0.18)
---@field pitch? number Playback pitch multiplier (default: 1.0)
---@field pitch_variance? number Pitch randomization variance range +/- (default: 0.06, set 0 to disable)
---@field max_hear_distance? number Maximum hearing distance (default: 16)

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

---Whether declarative item equip sound effects are enabled
x_player_api.enable_equip_sound = core.settings:get_bool("x_player_api.enable_equip_sound", true)

local math_random = math.random

---@type table<string, EquipSoundDefinition|false> Memoized equip sound resolution cache
local EQUIP_SOUND_CACHE = {}

---Clear internal equip sound resolution cache
function x_player_api.clear_equip_sound_cache()
	EQUIP_SOUND_CACHE = {}
end

---@type table<string, EquipSoundDefinition|string|boolean>
x_player_api.registered_equip_sounds = x_player_api.registered_equip_sounds or {
	["group:sword"] = {sound = "x_player_api_draw_blade", gain = 0.18},
	["group:blade"] = {sound = "x_player_api_draw_blade", gain = 0.18},
	["group:saber"] = {sound = "x_player_api_draw_blade", gain = 0.18},
	["group:bow"] = {sound = "x_player_api_draw_bow", gain = 0.15},
	["group:tool"] = {sound = "x_player_api_draw_tool", gain = 0.15},
	["group:pickaxe"] = {sound = "x_player_api_draw_tool", gain = 0.15},
	["group:axe"] = {sound = "x_player_api_draw_tool", gain = 0.15},
	["group:shovel"] = {sound = "x_player_api_draw_tool", gain = 0.15},
}
local equip_sounds = x_player_api.registered_equip_sounds

---Register or override an equip sound for an item name or group
---@param item_or_group string Item name or group filter (e.g. "group:sword", "default:sword_steel")
---@param def string|EquipSoundDefinition|boolean Sound name, definition table, or false to suppress sound
function x_player_api.register_equip_sound(item_or_group, def)
	if type(def) == "string" then
		equip_sounds[item_or_group] = {sound = def}
	elseif type(def) == "table" or def == false then
		equip_sounds[item_or_group] = def
	end
	x_player_api.clear_equip_sound_cache()
end

---Get registered or inferred equip sound definition for an item
---Resolution precedence:
---  - Direct item match in registry
---  - Item definition `_equip_sound` field
---  - Group matches in registry (`group:...`)
---@nodiscard
---@param item_name string Item technical name
---@return EquipSoundDefinition|nil equip_sound Registered sound definition, or nil if none/suppressed
function x_player_api.get_equip_sound(item_name)
	if not item_name or item_name == "" then
		return nil
	end

	local cached = EQUIP_SOUND_CACHE[item_name]
	if cached ~= nil then
		return cached or nil
	end

	local result = equip_sounds[item_name]
	if result == false or result == "" then
		EQUIP_SOUND_CACHE[item_name] = false
		return nil
	elseif type(result) == "string" then
		result = {sound = result}
	elseif type(result) ~= "table" then
		result = nil
	end

	if not result and core.registered_items[item_name] then
		local idef = core.registered_items[item_name]
		if idef._equip_sound ~= nil then
			if idef._equip_sound == false or idef._equip_sound == "" then
				EQUIP_SOUND_CACHE[item_name] = false
				return nil
			elseif type(idef._equip_sound) == "string" then
				result = {sound = idef._equip_sound}
			elseif type(idef._equip_sound) == "table" then
				result = idef._equip_sound
			end
		end
	end

	if not result then
		for pattern, sound_def in pairs(equip_sounds) do
			if pattern:sub(1, 6) == "group:" then
				local group = pattern:sub(7)
				if core.get_item_group(item_name, group) > 0 then
					if sound_def == false then
						EQUIP_SOUND_CACHE[item_name] = false
						return nil
					elseif type(sound_def) == "string" then
						result = {sound = sound_def}
					elseif type(sound_def) == "table" then
						result = sound_def
					end
					break
				end
			end
		end
	end

	EQUIP_SOUND_CACHE[item_name] = result or false
	return result
end

---Play the equip sound for an item if configured
---@param player ObjectRef Target player
---@param item_name string Item technical name
---@return boolean success Whether a sound was played
function x_player_api.play_equip_sound(player, item_name)
	if x_player_api.enable_equip_sound == false then
		return false
	end
	if not item_name or item_name == "" then
		return false
	end

	local sdef = x_player_api.get_equip_sound(item_name)
	if not sdef or not sdef.sound or sdef.sound == "" then
		return false
	end

	local pos = player:get_pos()
	if not pos then
		return false
	end

	local base_pitch = sdef.pitch or 1.0
	local variance = (sdef.pitch_variance ~= nil) and sdef.pitch_variance or 0.06
	local pitch = base_pitch
	if variance > 0 then
		pitch = base_pitch + (math_random() * 2 - 1) * variance
	end

	core.sound_play(sdef.sound, {
		pos = pos,
		gain = sdef.gain or 0.18,
		pitch = pitch,
		max_hear_distance = sdef.max_hear_distance or 16,
	}, true)
	return true
end

---Trigger the weapon equip montage on a player if the active model supports it, and play equip sound
---@param player ObjectRef Target player
---@param item_name? string Item name being equipped (optional, resolved from wield item if omitted)
---@return boolean success Whether equip animation was started
function x_player_api.trigger_equip(player, item_name)
	if not player or not player.is_player or not player:is_player() then return false end
	if not item_name then
		local wield_stack = player:get_wielded_item()
		item_name = (wield_stack and wield_stack:get_name()) or ""
	end

	if item_name ~= "" then
		x_player_api.play_equip_sound(player, item_name)
	end

	local mdef = x_player_api.get_model(player)
	local has_equip = mdef and ((mdef.animations and mdef.animations.equip)
		or (mdef.animations_glb and mdef.animations_glb.equip))
	if not has_equip then
		return false
	end
	x_player_api.play_action(player, "equip", true)
	local name = player:get_player_name()
	local states = x_player_api.controls.player_states
	local pstate = states and states[name]
	if pstate then
		local time_now = core.get_us_time() * 0.000001
		pstate.equip_until = time_now + 0.33
	end
	local wield_data = x_player_api.wield_entities and x_player_api.wield_entities[name]
	if wield_data then
		wield_data.last_wield_name = item_name
	end
	return true
end
