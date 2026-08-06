grug_factions = {}

local META_FACTION = "grug_factions:faction"
local META_KIT = "grug_factions:kit_given"
local FORMNAME = "grug_factions:select"

-- Starter kit per faction; granted exactly once.
local starter_kits = {
	accord = {"default:sword_stone", "default:torch 10", "default:apple 10"},
	throng = {"default:sword_stone", "default:torch 10", "default:apple 10"},
}

--
-- API
--

-- A player's faction id, or nil while none has been chosen yet. Validated
-- against the registry (like get_class/get_race): an id from an old save
-- that no longer exists counts as unset instead of nil-crashing callers.
function grug_factions.get_faction(player)
	local id = player:get_meta():get_string(META_FACTION)
	if grug_core.factions[id] then
		return id
	end
	return nil
end

function grug_factions.get_faction_def(player)
	local id = grug_factions.get_faction(player)
	return id and grug_core.factions[id] or nil
end

-- Faction resolver for grug_core (protection rules); only online players can
-- be resolved, everyone else counts as factionless.
function grug_core.get_player_faction(name)
	local player = core.get_player_by_name(name or "")
	return player and grug_factions.get_faction(player) or nil
end

-- Faction of an arbitrary object: players via meta, mobs via the entity
-- field _grug_faction (set by grug_mobs).
function grug_factions.get_object_faction(obj)
	if not obj then
		return nil
	end
	if obj:is_player() then
		return grug_factions.get_faction(obj)
	end
	local ent = obj:get_luaentity()
	return ent and ent._grug_faction or nil
end

function grug_factions.same_faction(obj_a, obj_b)
	local a = grug_factions.get_object_faction(obj_a)
	local b = grug_factions.get_object_faction(obj_b)
	return a ~= nil and a == b
end

-- Hostile are only objects that BOTH have a faction and differ. Factionless
-- ones (neutral mobs) manage their behavior themselves.
function grug_factions.hostile(obj_a, obj_b)
	local a = grug_factions.get_object_faction(obj_a)
	local b = grug_factions.get_object_faction(obj_b)
	return a ~= nil and b ~= nil and a ~= b
end

local faction_chosen_callbacks = {}

-- func(player, faction_id) — called after the player picked a faction in
-- the selection dialog (NOT on admin /faction sets). grug_classes chains
-- the race/class creation steps here.
function grug_factions.register_on_faction_chosen(func)
	table.insert(faction_chosen_callbacks, func)
end

function grug_factions.set_faction(player, id)
	local def = grug_core.factions[id]
	if not def then
		return false
	end
	player:get_meta():set_string(META_FACTION, id)
	player:set_nametag_attributes({color = def.color})

	local meta = player:get_meta()
	if meta:get_int(META_KIT) == 0 then
		meta:set_int(META_KIT, 1)
		local inv = player:get_inventory()
		for _, item in ipairs(starter_kits[id] or {}) do
			inv:add_item("main", item)
		end
	end
	return true
end

-- Teleports (async, after emerge) to the faction camp. The platform height
-- is decided during generation of the camp chunks, so the spawn position is
-- re-read AFTER the emerge completes.
function grug_factions.teleport_to_spawn(player)
	local id = grug_factions.get_faction(player)
	if not id then
		return
	end
	local spawn = grug_core.get_spawn_pos(id)
	local name = player:get_player_name()
	core.emerge_area(
		vector.offset(spawn, -16, -24, -16),
		vector.offset(spawn, 16, 80, 16),
		function(_, _, remaining)
			if remaining > 0 then
				return
			end
			local p = core.get_player_by_name(name)
			if p then
				p:set_pos(grug_core.find_surface(grug_core.get_spawn_pos(id)))
			end
		end)
end

--
-- Faction selection UI
--

local function selection_formspec()
	return table.concat({
		"formspec_version[4]",
		"size[8.6,4.6]",
		"label[0.5,0.7;", core.formspec_escape("Choose your faction!"), "]",
		"label[0.5,1.3;", core.formspec_escape("This decision is final."), "]",
		"style[choose_accord;bgcolor=", grug_core.factions.accord.color, "]",
		"style[choose_throng;bgcolor=", grug_core.factions.throng.color, "]",
		"button[0.5,2.1;3.6,1.6;choose_accord;The Accord]",
		"button[4.5,2.1;3.6,1.6;choose_throng;The Throng]",
	})
end

local function show_selection(player)
	core.show_formspec(player:get_player_name(), FORMNAME, selection_formspec())
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	if grug_factions.get_faction(player) then
		return true
	end

	local chosen
	if fields.choose_accord then
		chosen = "accord"
	elseif fields.choose_throng then
		chosen = "throng"
	end

	if not chosen then
		-- Closed without choosing: show again (choosing is mandatory).
		local name = player:get_player_name()
		core.after(1, function()
			local p = core.get_player_by_name(name)
			if p and not grug_factions.get_faction(p) then
				show_selection(p)
			end
		end)
		return true
	end

	grug_factions.set_faction(player, chosen)
	grug_factions.teleport_to_spawn(player)
	core.close_formspec(player:get_player_name(), FORMNAME)
	local def = grug_core.factions[chosen]
	core.chat_send_player(player:get_player_name(),
		core.colorize(def.color, "Welcome to the " .. def.name .. "!"))
	for _, func in ipairs(faction_chosen_callbacks) do
		func(player, chosen)
	end
	return true
end)

core.register_on_joinplayer(function(player)
	local def = grug_factions.get_faction_def(player)
	if def then
		player:set_nametag_attributes({color = def.color})
	else
		local name = player:get_player_name()
		core.after(1, function()
			local p = core.get_player_by_name(name)
			if p and not grug_factions.get_faction(p) then
				show_selection(p)
			end
		end)
	end
end)

-- Always respawn at the own faction camp.
core.register_on_respawnplayer(function(player)
	local id = grug_factions.get_faction(player)
	if not id then
		return
	end
	player:set_pos(grug_core.get_spawn_pos(id))
	grug_factions.teleport_to_spawn(player)
	return true
end)

-- Prevent friendly fire within the own faction.
core.register_on_punchplayer(function(player, hitter)
	if hitter and hitter:is_player() and
			grug_factions.same_faction(player, hitter) then
		return true
	end
end)

--
-- Admin/info command
--

core.register_chatcommand("faction", {
	params = "[<player>] [throng|accord]",
	description = "Show a player's faction or (as admin) set it",
	func = function(name, param)
		local target_name, faction_id = param:match("^(%S+)%s+(%S+)$")
		-- Single token: a faction id means "set my own faction".
		if not target_name and grug_core.factions[param] then
			target_name, faction_id = name, param
		end
		target_name = target_name or (param ~= "" and param) or name

		local target = core.get_player_by_name(target_name)
		if not target then
			return false, "Player '" .. target_name .. "' is not online."
		end

		if faction_id then
			if not core.check_player_privs(name, {server = true}) then
				return false, "You need the 'server' privilege for this."
			end
			if not grug_factions.set_faction(target, faction_id) then
				return false, "Unknown faction: " .. faction_id
			end
			grug_factions.teleport_to_spawn(target)
			return true, target_name .. " now belongs to the " .. faction_id .. " faction."
		end

		local id = grug_factions.get_faction(target)
		if not id then
			return true, target_name .. " has not chosen a faction yet."
		end
		return true, target_name .. " belongs to the " .. grug_core.factions[id].name .. " faction."
	end,
})
