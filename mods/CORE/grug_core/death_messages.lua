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
	-- the ice water of a dragon arena (grug_mobs boss_dragons.lua)
	cold = {
		"%s went through the ice.",
		"%s found the dragon's water too cold.",
	},
	-- leaving a dragon's arena during its fight (grug_mobs boss_dragons.lua)
	wrath = {
		"%s fled the dragon's wrath and burned for it.",
		"%s left the dragon's fight and paid for it.",
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
	fled = {
		"%s fled the fight and fell.",
		"%s turned tail mid-fight and fell.",
	},
	fallback = {
		"%s met an untimely end.",
		"%s will need another try.",
	},
}

-- The custom_type of a logout death (pvp-plan ruling 9): grug_pvp announces
-- it with this reason when the player leaves in PvP combat and applies the
-- death with it at the next join, which therefore broadcasts nothing.
grug_core.LOGOUT_DEATH_CUSTOM_TYPE = "grug_core:logout_death"

-- Shown for an entity that has no readable name of its own.
local GENERIC_ACTOR = "a hostile creature"

-- A display name, never an entity's technical "mod:name" (mobs_redo falls back
-- to the registered name when a definition has no description).
local function readable(text)
	return type(text) == "string" and text ~= "" and
		not text:find("^[%w_]+:[%w_]+$") and text or nil
end

-- The object a hit is credited to. A projectile that carries its shooter
-- (`_grug_source`, stamped by grug_mobs.stamp_arrow_damage and the dragon
-- breath) resolves to that shooter while it still exists; a projectile whose
-- shooter is gone (dead or unloaded) resolves to nil. Anything else is its
-- own source. Death messages and boss-encounter death counting both use it.
function grug_core.damage_source(object)
	local entity = object and not object:is_player() and object:get_luaentity()
	local shooter = entity and entity._grug_source
	if not shooter then
		return object
	end
	if shooter:is_player() or shooter:get_luaentity() then
		return shooter
	end
	return nil
end

local function actor_name(object)
	if not object then
		return nil, nil
	end
	local source = grug_core.damage_source(object)
	if source and source:is_player() then
		return source:get_player_name(), "player"
	end
	local shooter = source and source:get_luaentity()
	local entity = object:get_luaentity()
	if shooter or entity then
		-- The shooter's name; with the shooter gone, the projectile's own
		-- readable label ("an arrow", "a fireball").
		return readable(shooter and shooter.description) or
			readable(entity and entity._grug_projectile_label) or
			GENERIC_ACTOR, "mob"
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
	elseif reason and reason.custom_type == "grug_mobs:ice_water" then
		category = "cold"
	elseif reason and reason.custom_type == "grug_mobs:dragon_wrath" then
		category = "wrath"
	elseif reason and reason.custom_type == grug_core.LOGOUT_DEATH_CUSTOM_TYPE then
		category = "fled"
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
	if reason and reason.custom_type == grug_core.LOGOUT_DEATH_CUSTOM_TYPE then
		return
	end
	local _, message = grug_core.death_message(player:get_player_name(), reason)
	core.chat_send_all(message)
	grug_sounds.play("player_death", player)
end)
