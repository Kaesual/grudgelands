wob_factions = {}

local META_FACTION = "wob_factions:faction"
local META_KIT = "wob_factions:kit_given"
local FORMNAME = "wob_factions:select"

-- Starterkit je Fraktion; wird genau einmal vergeben.
local starter_kits = {
	alliance = {"default:sword_stone", "default:torch 10", "default:apple 10"},
	horde = {"default:sword_stone", "default:torch 10", "default:apple 10"},
}

--
-- API
--

-- Fraktions-ID eines Spielers oder nil, solange noch keine gewaehlt wurde.
function wob_factions.get_faction(player)
	local id = player:get_meta():get_string(META_FACTION)
	if id == "" then
		return nil
	end
	return id
end

function wob_factions.get_faction_def(player)
	local id = wob_factions.get_faction(player)
	return id and wob_core.factions[id] or nil
end

-- Fraktion eines beliebigen Objekts: Spieler ueber Meta, Mobs ueber das
-- Entity-Feld _wob_faction (wird von wob_mobs gesetzt).
function wob_factions.get_object_faction(obj)
	if not obj then
		return nil
	end
	if obj:is_player() then
		return wob_factions.get_faction(obj)
	end
	local ent = obj:get_luaentity()
	return ent and ent._wob_faction or nil
end

function wob_factions.same_faction(obj_a, obj_b)
	local a = wob_factions.get_object_faction(obj_a)
	local b = wob_factions.get_object_faction(obj_b)
	return a ~= nil and a == b
end

-- Feindselig sind nur Objekte, die BEIDE eine Fraktion haben und sich
-- unterscheiden. Fraktionslose (neutrale Mobs) regeln ihr Verhalten selbst.
function wob_factions.hostile(obj_a, obj_b)
	local a = wob_factions.get_object_faction(obj_a)
	local b = wob_factions.get_object_faction(obj_b)
	return a ~= nil and b ~= nil and a ~= b
end

function wob_factions.set_faction(player, id)
	local def = wob_core.factions[id]
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

-- Teleportiert (asynchron, nach Emerge) zum Fraktionslager.
function wob_factions.teleport_to_spawn(player)
	local def = wob_factions.get_faction_def(player)
	if not def then
		return
	end
	local spawn = def.spawn
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
				p:set_pos(wob_core.find_surface(spawn))
			end
		end)
end

--
-- Fraktionswahl-UI
--

local function selection_formspec()
	return table.concat({
		"formspec_version[4]",
		"size[8.6,4.6]",
		"label[0.5,0.7;", core.formspec_escape("Wähle deine Fraktion!"), "]",
		"label[0.5,1.3;", core.formspec_escape("Diese Entscheidung ist endgültig."), "]",
		"style[choose_alliance;bgcolor=", wob_core.factions.alliance.color, "]",
		"style[choose_horde;bgcolor=", wob_core.factions.horde.color, "]",
		"button[0.5,2.1;3.6,1.6;choose_alliance;Allianz]",
		"button[4.5,2.1;3.6,1.6;choose_horde;Horde]",
	})
end

local function show_selection(player)
	core.show_formspec(player:get_player_name(), FORMNAME, selection_formspec())
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	if wob_factions.get_faction(player) then
		return true
	end

	local chosen
	if fields.choose_alliance then
		chosen = "alliance"
	elseif fields.choose_horde then
		chosen = "horde"
	end

	if not chosen then
		-- Ohne Wahl geschlossen: erneut anzeigen (Wahl ist Pflicht).
		local name = player:get_player_name()
		core.after(1, function()
			local p = core.get_player_by_name(name)
			if p and not wob_factions.get_faction(p) then
				show_selection(p)
			end
		end)
		return true
	end

	wob_factions.set_faction(player, chosen)
	wob_factions.teleport_to_spawn(player)
	core.close_formspec(player:get_player_name(), FORMNAME)
	local def = wob_core.factions[chosen]
	core.chat_send_player(player:get_player_name(),
		core.colorize(def.color, "Willkommen bei der " .. def.name .. "!"))
	return true
end)

core.register_on_joinplayer(function(player)
	local def = wob_factions.get_faction_def(player)
	if def then
		player:set_nametag_attributes({color = def.color})
	else
		local name = player:get_player_name()
		core.after(1, function()
			local p = core.get_player_by_name(name)
			if p and not wob_factions.get_faction(p) then
				show_selection(p)
			end
		end)
	end
end)

-- Respawn immer im eigenen Fraktionslager.
core.register_on_respawnplayer(function(player)
	local def = wob_factions.get_faction_def(player)
	if not def then
		return
	end
	player:set_pos(def.spawn)
	wob_factions.teleport_to_spawn(player)
	return true
end)

-- Friendly Fire innerhalb der eigenen Fraktion unterbinden.
core.register_on_punchplayer(function(player, hitter)
	if hitter and hitter:is_player() and
			wob_factions.same_faction(player, hitter) then
		return true
	end
end)

--
-- Admin-/Info-Kommando
--

core.register_chatcommand("faction", {
	params = "[<spieler>] [horde|alliance]",
	description = "Fraktion anzeigen oder (als Admin) setzen",
	func = function(name, param)
		local target_name, faction_id = param:match("^(%S+)%s+(%S+)$")
		target_name = target_name or (param ~= "" and param) or name

		local target = core.get_player_by_name(target_name)
		if not target then
			return false, "Spieler '" .. target_name .. "' ist nicht online."
		end

		if faction_id then
			if not core.check_player_privs(name, {server = true}) then
				return false, "Dafür brauchst du das 'server'-Privileg."
			end
			if not wob_factions.set_faction(target, faction_id) then
				return false, "Unbekannte Fraktion: " .. faction_id
			end
			wob_factions.teleport_to_spawn(target)
			return true, target_name .. " gehört jetzt zur Fraktion " .. faction_id .. "."
		end

		local id = wob_factions.get_faction(target)
		if not id then
			return true, target_name .. " hat noch keine Fraktion gewählt."
		end
		return true, target_name .. " gehört zur Fraktion " .. wob_core.factions[id].name .. "."
	end,
})
