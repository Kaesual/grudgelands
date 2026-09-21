local atlas = grug_map.atlas

local function player_marker(player, kind)
	local name = player:get_player_name()
	return {id = name, label = name, detail = name .. (kind == "player" and " (you)" or " (party)"),
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

local givers = {}
local priority = {ready = 1, available = 2, active = 3, locked = 4}
local labels = {ready = "Ready to turn in", available = "Quest available",
	active = "Quest in progress", locked = "Requirements not met"}

-- Authored sockets exist before terrain is emerged; the atlas never loads a
-- mapblock or searches live entities just to find a quest giver.
core.register_on_mods_loaded(function()
	local sockets = {}
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(settlement.key)) do
			sockets[settlement.key .. "/" .. socket.id] = socket.pos
		end
	end
	for id, npc in pairs(grug_quests.registered_npcs) do
		local position = assert(sockets[npc.settlement .. "/" .. npc.socket],
			"[grug_map] quest giver socket missing: " .. id)
		givers[#givers + 1] = {id = id, title = npc.title, position = position,
			settlement = npc.settlement}
	end
	table.sort(givers, function(a, b) return a.id < b.id end)
end)

atlas.register_marker_provider("quest", function(player)
	local groups, result = {}, {}
	for _, giver in ipairs(givers) do
		local state = grug_quests.marker_state(player, giver.id)
		if state then
			-- Nearby NPCs share a legible settlement marker instead of covering
			-- each other's buttons; every relevant giver remains in its tooltip.
			local group = groups[giver.settlement]
			if not group then
				group = {id = giver.settlement, kind = "quest", status = state,
					position = giver.position, lines = {}}
				groups[giver.settlement] = group
				result[#result + 1] = group
			end
			if priority[state] < priority[group.status] then
				group.status, group.position = state, giver.position
			end
			group.lines[#group.lines + 1] = giver.title .. ": " .. labels[state]
		end
	end
	for _, group in ipairs(result) do
		group.label = labels[group.status]
		group.detail = table.concat(group.lines, "\n")
		group.lines = nil
	end
	return result
end)
