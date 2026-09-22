local atlas = grug_map.atlas

local function player_marker(player, kind)
	local name = player:get_player_name()
	return {id = name, label = name, detail = name,
		kind = kind, position = player:get_pos(), heading = player:get_look_horizontal()}
end

atlas.register_marker_provider("player", function(player)
	return {player_marker(player, "player")}
end)

atlas.register_marker_provider("party", function(player)
	local result = {}
	local group = grug_parties.view(player)
	for _, member in ipairs(group and group.members or {}) do
		if member.name ~= player:get_player_name() then
			local other = core.get_player_by_name(member.name)
			if other then result[#result + 1] = player_marker(other, "party") end
		end
	end
	return result
end)

local givers, services = {}, {}

-- Authored sockets exist before terrain is emerged. The atlas never loads a
-- mapblock or searches live entities just to find a service or quest giver.
core.register_on_mods_loaded(function()
	local sockets = {}
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(settlement.key)) do
			local id = settlement.key .. "/" .. socket.id
			sockets[id] = socket.pos
			local label, texture, kind
			if socket.role == "trainer" then
				local profession = assert(grug_jobs.PROFESSIONS[socket.profession])
				label, texture = profession.name .. " Trainer", "grug_jobs_book.png"
				kind = "trainer"
			elseif socket.role == "riding_trainer" then
				label, texture = "Riding Trainer", "grug_mounts_icon_" .. settlement.race_id .. ".png"
				kind = "trainer"
			elseif socket.role == "king" then
				local def = assert(core.registered_entities["grug_mobs:king_" .. settlement.race_id])
				label, texture = def.description, "grug_mobs_item_fallen_crown.png"
				kind = "boss"
			end
			if label and socket.spawn ~= false then
				services[#services + 1] = {id = id, label = label, position = socket.pos,
					kind = kind, texture = texture}
			end
		end
	end
	for _, dragon in ipairs(grug_mobs.dragon_map_markers()) do
		services[#services + 1] = {id = dragon.id, label = dragon.name,
			position = dragon.pos, kind = "boss", texture = "grug_mobs_item_fallen_crown.png"}
	end
	for id, npc in pairs(grug_quests.registered_npcs) do
		local position = assert(sockets[npc.settlement .. "/" .. npc.socket],
			"[grug_map] quest giver socket missing: " .. id)
		givers[#givers + 1] = {id = id, title = npc.title, position = position}
	end
	table.sort(givers, function(a, b) return a.id < b.id end)
end)

atlas.register_marker_provider("service", function() return services end)

atlas.register_marker_provider("quest", function(player)
	local result = {}
	for _, giver in ipairs(givers) do
		local state = grug_quests.marker_state(player, giver.id)
		if state then
			result[#result + 1] = {id = giver.id, label = giver.title,
				position = giver.position, kind = "quest", status = state}
		end
	end
	return result
end)
