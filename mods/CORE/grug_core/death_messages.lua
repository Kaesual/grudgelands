-- One short public chat line for every player death. Selection is a pure
-- function so the engine callback is only responsible for broadcasting it.

local TEMPLATES = {
	fall = {
		"%s discovered that gravity keeps grudges.",
		"%s took the express route down.",
	},
	drown = {
		"%s forgot the breathing part of swimming.",
		"%s stayed underwater one breath too long.",
	},
	node_damage = {
		"%s got far too familiar with fire.",
		"%s found the hot side of the world.",
	},
	suffocation = {
		"%s suffocated where no one should fit.",
		"%s was suffocated by solid ground.",
	},
	mob = {
		"%s was defeated by %s.",
		"%s picked the wrong fight with %s.",
	},
	player = {
		"%s was bested by %s.",
		"%s lost a grudge match to %s.",
	},
	fallback = {
		"%s met an untimely end.",
		"%s will need another try.",
	},
}

local function actor_name(object)
	if not object then
		return nil, nil
	end
	if object:is_player() then
		return object:get_player_name(), "player"
	end
	local entity = object:get_luaentity()
	if entity then
		return entity.description or entity.name or "a hostile creature", "mob"
	end
	return nil, nil
end

local function template_index(name, category, count)
	local total = 0
	local key = name .. ":" .. category
	for index = 1, #key do
		total = total + string.byte(key, index)
	end
	return total % count + 1
end

-- Returns both the stable category and the rendered line. The category is a
-- public diagnostic/test seam; chat receives only the line.
function grug_core.death_message(player_name, reason)
	local category = "fallback"
	local actor
	local reason_type = reason and reason.type
	if reason and reason.custom_type == "grug_core:suffocation" then
		category = "suffocation"
	elseif reason_type == "fall" then
		category = "fall"
	elseif reason_type == "drown" then
		category = "drown"
	elseif reason_type == "node_damage" then
		category = "node_damage"
	elseif reason_type == "punch" then
		local actor_kind
		actor, actor_kind = actor_name(reason.object)
		if actor_kind then
			category = actor_kind
		end
	end
	local choices = TEMPLATES[category]
	local template = choices[template_index(player_name, category, #choices)]
	if actor then
		return category, template:format(player_name, actor)
	end
	return category, template:format(player_name)
end

core.register_on_dieplayer(function(player, reason)
	local _, message = grug_core.death_message(player:get_player_name(), reason)
	core.chat_send_all(message)
end)
