-- Runtime-only gathering authorization. Placement consumes catalog.lua and
-- never loads this module in the mapgen environment.

return function(dependencies)
	if type(dependencies) ~= "table" or type(dependencies.core) ~= "table" then
		error("grug_gathering: harvest dependencies differ", 0)
	end
	local engine = dependencies.core
	local authorizer
	local feedback_at = {}
	local FEEDBACK_INTERVAL_US = 1500000
	local VALID_HERBS = {
		["grug_gathering:gravemoss"] = 1,
		["grug_gathering:dragonweed"] = 2,
		["grug_gathering:crimson_lotus"] = 3,
		["grug_cooking:ember_moss"] = 5,
	}
	local VALID_DENIALS = {
		no_alchemist = true,
		book_group_locked = true,
	}

	local function player_name(player)
		if player and type(player.is_player) == "function" and player:is_player() and
				type(player.get_player_name) == "function" then
			return player:get_player_name()
		end
		return ""
	end

	local function herb_decision(player, herb_key, required_group)
		if VALID_HERBS[herb_key] ~= required_group then
			error("grug_gathering: invalid healing-herb request", 0)
		end
		if not authorizer then
			return false, "profession_unavailable"
		end
		local ok, allowed, reason = pcall(authorizer, player, herb_key,
			required_group)
		if not ok or type(allowed) ~= "boolean" then
			return false, "profession_unavailable"
		end
		if allowed == true then
			if reason == nil then return true, nil end
			return false, "profession_unavailable"
		end
		if VALID_DENIALS[reason] then return false, reason end
		return false, "profession_unavailable"
	end

	local function decision(pos, player, row)
		if type(row) ~= "table" then
			error("grug_gathering: harvest row missing", 0)
		end
		if row.placement_class == "new_p9g_source" then
			if row.harvest_kind == "healing_herb" then
				return herb_decision(player, row.raw_item, row.required_group)
			end
			return true, nil
		end
		error("grug_gathering: unsupported harvest class", 0)
	end

	local function failure_message(reason, row)
		if reason == "no_alchemist" then
			return "Requires the Alchemy profession."
		elseif reason == "book_group_locked" then
			return "Requires Alchemy book group T" .. row.required_group .. "."
		elseif reason == "profession_unavailable" then
			return "Profession service unavailable."
		end
		return nil
	end

	local function emit_failure(player, reason, row)
		local name = player_name(player)
		if name == "" then return end
		local now = engine.get_us_time()
		local key = name .. "\0" .. reason
		if feedback_at[key] and now - feedback_at[key] < FEEDBACK_INTERVAL_US then
			return
		end
		local message = failure_message(reason, row)
		if message then
			feedback_at[key] = now
			engine.chat_send_player(name, message)
		end
	end

	local module = {}

	function module.register_herb_authorizer(callback)
		if type(callback) ~= "function" then
			error("grug_gathering.register_herb_authorizer expects a function", 0)
		end
		if authorizer ~= nil then
			error("grug_gathering herb authorizer is already registered", 0)
		end
		authorizer = callback
	end

	function module.decision(pos, player, row)
		return decision(pos, player, row)
	end

	function module.can_dig(row)
		return function(pos, player)
			local allowed, reason = decision(pos, player, row)
			if not allowed then emit_failure(player, reason, row) end
			return allowed
		end
	end

	function module.clear_player(player)
		local name = player_name(player)
		if name == "" then return end
		local prefix = name .. "\0"
		for key in pairs(feedback_at) do
			if key:sub(1, #prefix) == prefix then feedback_at[key] = nil end
		end
	end

	return module
end
