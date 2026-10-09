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
-- Ruling 13 (Round 31): a player sees only the NPC markers of the own
-- faction. Each marker carries its NPC's `faction`; the lists per viewer
-- faction are built once below, so a marker build only picks one (the key
-- "" is a player without a faction: none). The kings and the dragons are
-- baked into the base image for everyone since Round 44 (bake.lua).
local givers_for, services_for, giver_by_id = {}, {}, {}
local function visible(row, faction)
	return row.faction == nil or row.faction == faction
end
-- Trainer icons per profession (Round 44, spec ruling 15) replace the book;
-- Riding keeps the mount icon.
function grug_map.trainer_icon(profession)
	return "grug_map_trainer_" .. profession .. ".png"
end
grug_map.marker_visible = visible
local function split(rows)
	local result = {}
	for _, faction in ipairs({"", unpack(grug_core.faction_ids)}) do
		local list = {}
		for _, row in ipairs(rows) do
			if visible(row, faction) then list[#list + 1] = row end
		end
		result[faction] = list
	end
	return result
end
local function faction_of(player) return grug_factions.get_faction(player) or "" end

-- Authored sockets exist before terrain is emerged. The atlas never loads a
-- mapblock or searches live entities just to find a service or quest giver.
core.register_on_mods_loaded(function()
	local sockets, faction_of_race = {}, {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		local faction = faction_of_race[settlement.race_id]
		for _, socket in ipairs(grug_core.settlement_sockets_at(settlement.key)) do
			local id = settlement.key .. "/" .. socket.id
			sockets[id] = socket.pos
			local label, texture, kind
			-- A trainer socket of a profession no trainer teaches (Round 45:
			-- Cooking) holds a mender: no marker (no repairer has an icon).
			if socket.role == "trainer" and grug_jobs.trainer_teaches(socket.profession) then
				local profession = assert(grug_jobs.PROFESSIONS[socket.profession])
				label = profession.name .. " Trainer"
				texture = grug_map.trainer_icon(socket.profession)
				kind = "trainer"
			elseif socket.role == "riding_trainer" then
				label, texture = "Riding Trainer", "grug_mounts_icon_" .. settlement.race_id .. ".png"
				kind = "trainer"
			elseif socket.role == "housing_manager" then
				label, texture = "Housing Steward", "grug_map_housing_steward.png"
				kind = "steward"
			-- The capital services of Round 33 (grug_traders/vendors.lua),
			-- marked like the Steward (Round 34 ruling 5).
			elseif socket.role == "crownbinder" then
				label, texture = "Crownbinder", "grug_map_crownbinder.png"
				kind = "service"
			elseif socket.role == "culture_vendor" then
				label, texture = "Decor Merchant", "grug_map_decor_merchant.png"
				kind = "service"
			end
			if label and socket.spawn ~= false then
				services[#services + 1] = {id = id, label = label, position = socket.pos,
					kind = kind, texture = texture, faction = faction}
			end
		end
	end
	for id, npc in pairs(grug_quests.registered_npcs) do
		local position = assert(sockets[npc.settlement .. "/" .. npc.socket],
			"[grug_map] quest giver socket missing: " .. id)
		givers[#givers + 1] = {id = id, title = npc.title, position = position,
			faction = npc.faction}
	end
	table.sort(givers, function(a, b) return a.id < b.id end)
	for _, giver in ipairs(givers) do giver_by_id[giver.id] = giver end
	givers_for, services_for = split(givers), split(services)
end)

-- A quest NPC's marker row {id, title, position, faction} (every quest NPC,
-- givers and talk destinations), or nil: the map window's question marks
-- and quest targets (Round 44). Read-only.
function grug_map.quest_npc(id)
	return giver_by_id[id]
end

atlas.register_marker_provider("service", function(player)
	return services_for[faction_of(player)] or {}
end)

-- One grug_quests.marker_states call for all givers (Round 30, perf review
-- #1); only the own faction's givers are asked (ruling 13).
atlas.register_marker_provider("quest", function(player)
	local result, states = {}, grug_quests.marker_states(player)
	for _, giver in ipairs(givers_for[faction_of(player)] or {}) do
		local state = states[giver.id]
		if state then
			result[#result + 1] = {id = giver.id, label = giver.title,
				position = giver.position, kind = "quest", status = state,
				faction = giver.faction}
		end
	end
	return result
end)

-- Home registry positions are resolved at server load; markers never emerge land.
-- Only the own faction's innkeepers (ruling 13, Round 31).
atlas.register_marker_provider("home", function(player)
 local selected = grug_home.get(player)
 local result, faction = {}, faction_of(player)
 for _, row in ipairs(grug_home.locations()) do
  local chosen = selected and selected.id == row.id
  if visible(row, faction) then
   result[#result + 1] = {id=row.id, label=row.label .. " Innkeeper",
    detail=row.label .. (chosen and " — Your home / Innkeeper" or " — Innkeeper"),
    position=row.pos, kind=chosen and "home" or "innkeeper", faction=row.faction}
  end
 end
 -- A Claim Stone travel home (grug_home claim_home.lua) is marked at its stone.
 if selected and selected.claim then
  result[#result + 1] = {id=selected.id, label="Your Claim Stone",
   detail="Claim Stone — Your home", position=selected.pos, kind="home",
   faction=selected.faction}
 end
 return result
end)

-- Discovered waystones of the player's own network (Round 29, WP17);
-- undiscovered ones are not shown, and a marker never unlocks travel. The
-- owner's activated Claim Stone is a waypoint too (Round 45 PT9), marked
-- here unless it is the travel home, which the home marker already shows.
atlas.register_marker_provider("waypoint", function(player)
 local result = {}
 for _, row in ipairs(grug_home.known_waypoints(player)) do
  result[#result + 1] = {id=row.id, label=row.label .. " Waystone",
   position=row.pos, kind="waypoint", texture="grug_map_waypoint.png",
   faction=grug_factions.get_faction(player)}
 end
 local claim, home = grug_home.claim_waypoint(player), grug_home.get(player)
 if claim and not (home and home.id == claim.id) then
  result[#result + 1] = {id=claim.id, label=claim.label, position=claim.pos,
   kind="waypoint", texture="grug_map_waypoint.png", faction=claim.faction}
 end
 return result
end)
