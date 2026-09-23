grug_parties = {}
local storage = core.get_mod_storage()
local saved = storage:get_string("parties")
local state = saved == "" and {next_id = 0, groups = {}} or core.deserialize(saved)
assert(type(state) == "table" and type(state.groups) == "table"
	and type(state.next_id) == "number", "[grug_parties] Invalid party storage")
local membership, incoming, last_send, connected = {}, {}, {}, {}
local callbacks = {}
local INVITES = "grug_parties:invites_off"
local HUD = "grug_parties:hud_off"
local HEALTH_COLORS = "grug_parties:health_colors"
local HEALTH_COLOR_MODES = {all_green = true, by_class = true}

-- Membership order is canonical join order; the lookup is always derived.
for id, group in pairs(state.groups) do
	assert(type(group.members) == "table" and #group.members >= 2
		and #group.members <= 10 and type(group.faction) == "string",
		"[grug_parties] Invalid stored group")
	local leader_found = false
	for _, name in ipairs(group.members) do
		assert(type(name) == "string" and not membership[name],
			"[grug_parties] Duplicate/invalid stored member")
		membership[name] = id
		leader_found = leader_found or name == group.leader
	end
	assert(leader_found, "[grug_parties] Missing stored leader")
end
local function persist()
	storage:set_string("parties", core.serialize(state))
end
local function now()
	return core.get_us_time() / 1000000
end
local function name_of(player)
	return type(player) == "string" and player or player:get_player_name()
end
local function online(name)
	if not connected[name] then return nil end
	return core.get_player_by_name(name)
end
local function actor(player)
	if not player or type(player) == "string" or not player:is_player() then return nil end
	local name = player:get_player_name()
	return online(name) and name or nil
end
local function group_of(name)
	local id = membership[name]
	return id and state.groups[id], id
end
local function emit(names, reason)
	-- Existing invitation rows show the inviter's current party context.
	if reason == "membership" or reason == "leadership" then
		local observers = {}
		for recipient, list in pairs(incoming) do
			for inviter in pairs(list) do
				if names[inviter] then observers[recipient] = true end
			end
		end
		for name in pairs(observers) do names[name] = true end
	end
	for name in pairs(names) do
		for _, callback in ipairs(callbacks) do callback(name, reason) end
	end
end
local function affected(group, extra)
	local names = {}
	if extra then names[extra] = true end
	if group then
		for _, name in ipairs(group.members) do names[name] = true end
	end
	return names
end
local function prune(name, time)
	local list = incoming[name]
	local changed = false
	if list then
		for inviter, expiry in pairs(list) do
			if expiry <= time then list[inviter], changed = nil, true end
		end
		if not next(list) then incoming[name] = nil end
	end
	return changed
end
local function clear_invitations(name)
	local changed = {[name] = true}
	incoming[name] = nil
	for recipient, list in pairs(incoming) do
		if list[name] then
			list[name], changed[recipient] = nil, true
			if not next(list) then incoming[recipient] = nil end
		end
	end
	return changed
end
local function remove_member(name)
	local group, id = group_of(name)
	if not group then return nil end
	local changed = affected(group)
	for i, member in ipairs(group.members) do
		if member == name then table.remove(group.members, i); break end
	end
	membership[name] = nil
	if #group.members == 1 then
		membership[group.members[1]] = nil
		state.groups[id] = nil
	elseif group.leader == name then
		group.leader = group.members[1]
	end
	persist()
	return changed
end
function grug_parties.register_on_change(callback)
	assert(type(callback) == "function")
	callbacks[#callbacks + 1] = callback
end
function grug_parties.view(player)
	local group, id = group_of(name_of(player))
	if not group then return nil end
	local view = {id = id, leader = group.leader, faction = group.faction, members = {}}
	for _, name in ipairs(group.members) do
		local member = online(name)
		local row = {name = name, online = member ~= nil}
		if member then
			row.hp = member:get_hp()
			row.hp_max = member:get_properties().hp_max
			row.class = grug_classes and grug_classes.get_class(member) or nil
		end
		view.members[#view.members + 1] = row
	end
	return view
end
function grug_parties.pending(player)
	local name, time = name_of(player), now()
	prune(name, time)
	local result = {}
	for inviter, expiry in pairs(incoming[name] or {}) do
		result[#result + 1] = {inviter = inviter, expires_in = math.ceil(expiry - time),
			party = grug_parties.view(inviter)}
	end
	table.sort(result, function(a, b) return a.inviter < b.inviter end)
	return result
end
function grug_parties.invitations_enabled(player)
	return player:get_meta():get_int(INVITES) == 0
end
function grug_parties.hud_enabled(player)
	return player:get_meta():get_int(HUD) == 0
end
function grug_parties.health_color_mode(player)
	local mode = player:get_meta():get_string(HEALTH_COLORS)
	return HEALTH_COLOR_MODES[mode] and mode or "by_class"
end
function grug_parties.set_invitations_enabled(player, enabled)
	local name = actor(player)
	if not name or type(enabled) ~= "boolean" then return false, "Invalid player or preference." end
	player:get_meta():set_int(INVITES, enabled and 0 or 1)
	if not enabled then incoming[name] = nil end
	emit({[name] = true}, "preferences")
	return true, enabled and "Invitations enabled." or "Invitations disabled."
end
function grug_parties.set_hud_enabled(player, enabled)
	local name = actor(player)
	if not name or type(enabled) ~= "boolean" then return false, "Invalid player or preference." end
	player:get_meta():set_int(HUD, enabled and 0 or 1)
	emit({[name] = true}, "preferences")
	return true, enabled and "Party HUD enabled." or "Party HUD disabled."
end
function grug_parties.set_health_color_mode(player, mode)
	local name = actor(player)
	if not name or not HEALTH_COLOR_MODES[mode] then
		return false, "Invalid player or health color preference."
	end
	if grug_parties.health_color_mode(player) == mode then
		return true, "Health colors unchanged."
	end
	player:get_meta():set_string(HEALTH_COLORS, mode)
	emit({[name] = true}, "preferences")
	return true, mode == "by_class" and "Class health colors enabled."
		or "All-green health colors enabled."
end
local function eligible(inviter, recipient)
	local sender, target = online(inviter), online(recipient)
	if not sender or not target then return false, "Both players must be online." end
	if inviter == recipient then return false, "You cannot invite yourself." end
	if membership[recipient] then return false, "That player already belongs to a party." end
	if not grug_parties.invitations_enabled(target) then return false, "That player has disabled invitations." end
	local faction = grug_factions.get_faction(sender)
	if not faction or faction ~= grug_factions.get_faction(target) then
		return false, "Party members must belong to the same faction."
	end
	local group = group_of(inviter)
	if group then
		if group.leader ~= inviter then return false, "Only the party leader may invite." end
		if group.faction ~= faction then return false, "Your faction no longer matches the party." end
		if #group.members >= 10 then return false, "The party is full." end
	end
	return true, faction
end
function grug_parties.invite(player, recipient)
	local name = actor(player)
	if not name or type(recipient) ~= "string" then return false, "Invalid invitation." end
	local ok, message = eligible(name, recipient)
	if not ok then return false, message end
	local time = now()
	prune(recipient, time)
	local list = incoming[recipient] or {}
	if list[name] then return true, "Invitation already pending." end
	if last_send[name] and time - last_send[name] < 1 then return false, "Wait one second between invitations." end
	local count = 0
	for _ in pairs(list) do count = count + 1 end
	if count >= 10 then return false, "That player has too many pending invitations." end
	last_send[name] = time
	list[name] = time + 120
	incoming[recipient] = list
	core.chat_send_player(recipient, name .. " invited you to a party. Open Group to respond.")
	emit({[recipient] = true}, "invitation")
	return true, "Invitation sent."
end
function grug_parties.accept(player, inviter)
	local name = actor(player)
	if not name or type(inviter) ~= "string" then return false, "Invalid invitation." end
	prune(name, now())
	if not incoming[name] or not incoming[name][inviter] then return false, "Invitation expired or unavailable." end
	local ok, faction = eligible(inviter, name)
	if not ok then return false, faction end
	local group, id = group_of(inviter)
	if not group then
		state.next_id = state.next_id + 1
		id = tostring(state.next_id)
		group = {leader = inviter, faction = faction, members = {inviter}}
		state.groups[id], membership[inviter] = group, id
	end
	group.members[#group.members + 1] = name
	membership[name] = id
	incoming[name] = nil
	persist()
	emit(affected(group), "membership")
	return true, "Joined the party."
end
function grug_parties.decline(player, inviter)
	local name = actor(player)
	if not name or type(inviter) ~= "string" then return false, "Invalid invitation." end
	prune(name, now())
	local list = incoming[name]
	if not list or not list[inviter] then return false, "Invitation expired or unavailable." end
	list[inviter] = nil
	if not next(list) then incoming[name] = nil end
	emit({[name] = true}, "invitation")
	return true, "Invitation declined."
end
function grug_parties.leave(player)
	local name = actor(player)
	if not name then return false, "Player must be online." end
	local changed = remove_member(name)
	if not changed then return false, "You do not belong to a party." end
	emit(changed, "membership")
	return true, "Left the party."
end
local function leader_target(player, target)
	local name = actor(player)
	local group, id
	if name then group, id = group_of(name) end
	if not group or group.leader ~= name then return nil, "Only the party leader may do that." end
	if type(target) ~= "string" or target == name or membership[target] ~= id then
		return nil, "Choose another member of your party."
	end
	return group
end
function grug_parties.kick(player, target)
	local group, message = leader_target(player, target)
	if not group then return false, message end
	local changed = remove_member(target)
	emit(changed, "membership")
	return true, "Member removed."
end
function grug_parties.transfer_leader(player, target)
	local group, message = leader_target(player, target)
	if not group then return false, message end
	group.leader = target
	persist()
	emit(affected(group), "leadership")
	return true, "Leadership transferred."
end
local function faction_changed(player)
	local name = player:get_player_name()
	local group = group_of(name)
	if group and group.faction ~= grug_factions.get_faction(player) then
		local changed = remove_member(name)
		emit(changed, "membership")
	end
end
grug_factions.register_on_faction_chosen(faction_changed)
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	connected[name] = true
	faction_changed(player)
	emit(affected(group_of(name), name), "presence")
end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	connected[name] = nil
	local changed = clear_invitations(name)
	local group = group_of(name)
	for member in pairs(affected(group)) do changed[member] = true end
	emit(changed, "presence")
end)
if grug_classes then
	grug_classes.register_on_class_chosen(function(player)
		local group = group_of(player:get_player_name())
		if group then emit(affected(group), "class") end
	end)
end
local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 1 then return end
	elapsed = 0
	local time, changed = now(), {}
	for name, sent in pairs(last_send) do
		if time - sent >= 1 then last_send[name] = nil end
	end
	for name in pairs(incoming) do
		if prune(name, time) then changed[name] = true end
	end
	emit(changed, "invitation")
end)

local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/ui.lua")
dofile(path .. "/hud.lua")
