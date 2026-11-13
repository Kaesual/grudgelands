-- Clans (Round 76, docs/design/clans.md): a second, purely social kind of
-- party. No name, no HUD and no effect in the game; up to 100 players of one
-- faction with the roles Leader (exactly one), Captain and Member, the "Clan
-- invitations" switch and the /c clan chat with presence and membership
-- lines. The rules live only here: the Social tab asks the can_* functions
-- and calls the actions, which answer ok, message.
--
-- Storage: one serialized table under "clans", {next_id, clans = {[id] =
-- {faction, members = {{name, role, level, class, last_online}, ...}}}}.
-- Members are in join order (succession reads it); the leader is the member
-- whose role is "leader". `level` and `class` are the last known ones (an
-- offline row shows them), `last_online` the os.time() of the last logout
-- (or of the last login, joining or shutdown, whichever came last). The
-- name -> clan index is derived at load. Invitations are session state, as
-- for parties: only online players, 120 s, one per second per sender, ten
-- pending per recipient, and a clan member holds none.

grug_clans = {}
local storage = core.get_mod_storage()
local MAX_MEMBERS, MAX_PENDING, INVITE_SECONDS = 100, 10, 120
local INVITES = "grug_clans:invites_off"
local COLOR = "#7ee081"
local ROLES = {leader = true, captain = true, member = true}
grug_clans.MAX_MEMBERS, grug_clans.COLOR = MAX_MEMBERS, COLOR

local function load_state()
	local saved = storage:get_string("clans")
	if saved == "" then return {next_id = 0, clans = {}} end
	local state = core.deserialize(saved)
	if type(state) == "table" and type(state.clans) == "table" then return state end
	-- Never a crash at load; the unreadable text stays for an administrator.
	core.log("error", "[grug_clans] Unreadable clan storage, kept as clans_unreadable; starting empty")
	storage:set_string("clans_unreadable", saved)
	return {next_id = 0, clans = {}}
end
local state = load_state()
local membership, incoming, last_send, callbacks = {}, {}, {}, {}

-- Validation at load: a broken member or clan is dropped with a log line, a
-- clan left with fewer than two members goes, a second leader becomes a
-- captain and a clan without one gets its successor (below).
local function valid_member(member)
	return type(member) == "table" and type(member.name) == "string" and ROLES[member.role]
		and type(member.level) == "number" and member.level >= 1 and member.level % 1 == 0
		and (member.class == nil or type(member.class) == "string")
		and (member.last_online == nil or type(member.last_online) == "number")
end
local function successor(clan)
	for _, member in ipairs(clan.members) do
		if member.role == "captain" then return member end
	end
	return clan.members[1]
end
do
	local ids, highest = {}, 0
	for id in pairs(state.clans) do ids[#ids + 1] = id end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
	for _, id in ipairs(ids) do
		local clan, kept, seen = state.clans[id], {}, {}
		if type(id) ~= "string" or type(clan) ~= "table" or type(clan.faction) ~= "string"
				or type(clan.members) ~= "table" then
			core.log("warning", "[grug_clans] Dropped invalid stored clan " .. tostring(id))
			state.clans[id] = nil
		else
			local leader
			for _, member in ipairs(clan.members) do
				if valid_member(member) and not membership[member.name] and not seen[member.name] then
					seen[member.name] = true
					kept[#kept + 1] = member
					if member.role == "leader" then
						if leader then member.role = "captain" else leader = member end
					end
				else
					core.log("warning", "[grug_clans] Dropped an invalid or duplicate member of stored clan " .. id)
				end
			end
			if #kept < 2 then
				core.log("warning", "[grug_clans] Dropped stored clan " .. id .. " with fewer than two members")
				state.clans[id] = nil
			else
				clan.members = kept
				if not leader then successor(clan).role = "leader" end
				for _, member in ipairs(kept) do membership[member.name] = id end
				highest = math.max(highest, tonumber(id) or 0)
			end
		end
	end
	if type(state.next_id) ~= "number" or state.next_id < highest then state.next_id = highest end
end

local function persist()
	storage:set_string("clans", core.serialize(state))
end
local function now()
	return core.get_us_time() / 1000000
end
local function name_of(player)
	return type(player) == "string" and player or player:get_player_name()
end
-- Online as the parties count it: joined and not leaving.
local function online(name)
	if not grug_parties.is_online(name) then return nil end
	return core.get_player_by_name(name)
end
local function actor(player)
	if not player or type(player) == "string" or not player:is_player() then return nil end
	local name = player:get_player_name()
	return online(name) and name or nil
end
local function clan_of(name)
	local id = membership[name]
	return id and state.clans[id], id
end
local function record_of(clan, name)
	for index, member in ipairs(clan.members) do
		if member.name == name then return member, index end
	end
end
local function members_of(clan, names)
	names = names or {}
	if clan then
		for _, member in ipairs(clan.members) do names[member.name] = true end
	end
	return names
end
-- The last known level and class of an online member, and the time.
local function stamp(member, player)
	member.level = grug_xp.get_level(player)
	member.class = grug_classes.get_class(player)
	member.last_online = os.time()
end

-- One clan chat line, "[Clan] text" in the clan's green, to `name`.
local function say(name, text)
	core.chat_send_player(name, core.colorize(COLOR, "[Clan] " .. text))
end
-- One line to the online members of `clan`, skipping `except`.
local function announce(clan, text, except)
	for _, member in ipairs(clan.members) do
		if member.name ~= except and grug_parties.is_online(member.name) then say(member.name, text) end
	end
end

-- callback(names, reason): `names` (a set, read only) are the players whose
-- clan card or pending invitations changed. Reasons: "membership" (a join,
-- leave, kick, change of faction or a dissolved clan), "role" (promote,
-- demote, new leader), "invitation", "presence" (a login or logout),
-- "preferences" (the switch), "level", "class". "membership", "role",
-- "presence" and "preferences" may also change the Clan buttons and marks in
-- every viewer's Online Players list.
function grug_clans.register_on_change(callback)
	assert(type(callback) == "function")
	callbacks[#callbacks + 1] = callback
end
local function emit(names, reason)
	-- Pending invitation rows show the inviter's clan.
	if reason == "membership" or reason == "role" or reason == "level" or reason == "class" then
		for recipient, list in pairs(incoming) do
			for inviter in pairs(list) do
				if names[inviter] then names[recipient] = true end
			end
		end
	end
	if not next(names) then return end
	for _, callback in ipairs(callbacks) do callback(names, reason) end
end

--
-- Invitations
--

-- Drops the invitations `name` sent (it can no longer invite); collects their
-- recipients into `names`.
local function clear_sent(name, names)
	names = names or {}
	for recipient, list in pairs(incoming) do
		if list[name] then
			list[name], names[recipient] = nil, true
			if not next(list) then incoming[recipient] = nil end
		end
	end
	return names
end
-- Drops the invitations `name` holds; collects their inviters into `names`.
local function clear_incoming(name, names)
	names = names or {}
	for inviter in pairs(incoming[name] or {}) do names[inviter] = true end
	incoming[name] = nil
	return names
end
-- The invitation from `inviter` to `recipient` while it lasts. An expired
-- one counts as gone; its timer (invite) removes it and tells both.
local function live(recipient, inviter)
	local list = incoming[recipient]
	return list and list[inviter] and list[inviter] > now()
end
local function expire(recipient, inviter, expiry)
	local list = incoming[recipient]
	if list and list[inviter] == expiry then
		list[inviter] = nil
		if not next(list) then incoming[recipient] = nil end
		emit({[recipient] = true, [inviter] = true}, "invitation")
	end
end

function grug_clans.invitations_enabled(player)
	return player:get_meta():get_int(INVITES) == 0
end
function grug_clans.set_invitations_enabled(player, enabled)
	local name = actor(player)
	if not name or type(enabled) ~= "boolean" then return false, "Invalid player or preference." end
	player:get_meta():set_int(INVITES, enabled and 0 or 1)
	if not enabled then emit(clear_incoming(name, {[name] = true}), "invitation") end
	emit({[name] = true}, "preferences")
	return true, enabled and "Clan invitations enabled." or "Clan invitations disabled."
end

local function eligible(inviter, recipient)
	local sender, target = online(inviter), online(recipient)
	if not sender or not target then return false, "Both players must be online." end
	if inviter == recipient then return false, "You cannot invite yourself." end
	if membership[recipient] then return false, "That player already belongs to a clan." end
	if not grug_clans.invitations_enabled(target) then
		return false, "That player has disabled clan invitations."
	end
	local faction = grug_factions.get_faction(sender)
	if not faction or faction ~= grug_factions.get_faction(target) then
		return false, "Clan members must belong to the same faction."
	end
	local clan = clan_of(inviter)
	if clan then
		if record_of(clan, inviter).role == "member" then
			return false, "Only the clan leader and captains may invite."
		end
		if clan.faction ~= faction then return false, "Your faction no longer matches the clan." end
		if #clan.members >= MAX_MEMBERS then return false, "The clan is full." end
	end
	return true, faction
end
-- Whether `inviter` may invite `recipient` now (the Social tab's Clan
-- button): eligible and not already invited by them. invite decides again.
function grug_clans.can_invite(inviter, recipient)
	if not inviter or not recipient then return false end
	inviter, recipient = name_of(inviter), name_of(recipient)
	if live(recipient, inviter) then return false end
	return (eligible(inviter, recipient))
end
function grug_clans.invite(player, recipient)
	local name = actor(player)
	if not name or type(recipient) ~= "string" then return false, "Invalid invitation." end
	local ok, message = eligible(name, recipient)
	if not ok then return false, message end
	if live(recipient, name) then return true, "Invitation already pending." end
	local time = now()
	if last_send[name] and time - last_send[name] < 1 then
		return false, "Wait one second between invitations."
	end
	local list, count = incoming[recipient] or {}, 0
	for _, expiry in pairs(list) do
		if expiry > time then count = count + 1 end
	end
	if count >= MAX_PENDING then return false, "That player has too many pending clan invitations." end
	local expiry = time + INVITE_SECONDS
	last_send[name], list[name], incoming[recipient] = time, expiry, list
	core.after(INVITE_SECONDS, expire, recipient, name, expiry)
	core.chat_send_player(recipient, name .. " has invited you to join their clan. " ..
		"Open the Social tab to answer.")
	emit({[recipient] = true, [name] = true}, "invitation")
	return true, "Invitation sent."
end
-- The pending clan invitations of `player`, sorted by inviter:
-- {inviter, expires_in (seconds, rounded up), level (the inviter's),
-- clan_size (members of the inviter's clan, 0 without one)}.
function grug_clans.pending(player)
	local name, time = name_of(player), now()
	local result = {}
	for inviter, expiry in pairs(incoming[name] or {}) do
		if expiry > time then
			local sender, clan = online(inviter), clan_of(inviter)
			result[#result + 1] = {inviter = inviter, expires_in = math.ceil(expiry - time),
				level = sender and grug_xp.get_level(sender) or nil,
				clan_size = clan and #clan.members or 0}
		end
	end
	table.sort(result, function(a, b) return a.inviter < b.inviter end)
	return result
end
function grug_clans.accept(player, inviter)
	local name = actor(player)
	if not name or type(inviter) ~= "string" then return false, "Invalid invitation." end
	if not live(name, inviter) then return false, "Invitation expired or unavailable." end
	local ok, faction = eligible(inviter, name)
	if not ok then return false, faction end
	local clan, id = clan_of(inviter)
	if not clan then
		local leader = {name = inviter, role = "leader"}
		stamp(leader, online(inviter))
		state.next_id = state.next_id + 1
		id = tostring(state.next_id)
		clan = {faction = faction, members = {leader}}
		state.clans[id], membership[inviter] = clan, id
	end
	local member = {name = name, role = "member"}
	stamp(member, player)
	clan.members[#clan.members + 1] = member
	membership[name] = id
	-- A clan member holds no invitations: the joining player's and, when the
	-- clan forms, the inviter's go. The joining player is a member and can no
	-- longer invite: the invitations it sent go too. The inviter, who leads or
	-- captains, keeps the ones it sent.
	local changed = clear_incoming(name)
	clear_incoming(inviter, changed)
	clear_sent(name, changed)
	persist()
	announce(clan, name .. " joined the clan.")
	emit(changed, "invitation")
	emit(members_of(clan), "membership")
	return true, "Joined the clan."
end
function grug_clans.decline(player, inviter)
	local name = actor(player)
	if not name or type(inviter) ~= "string" then return false, "Invalid invitation." end
	if not live(name, inviter) then return false, "Invitation expired or unavailable." end
	incoming[name][inviter] = nil
	if not next(incoming[name]) then incoming[name] = nil end
	-- The inviter's Clan button for this player comes back.
	emit({[name] = true, [inviter] = true}, "invitation")
	return true, "Invitation declined."
end

--
-- Membership and roles
--

-- The one place a member goes (leave, kick, a change of faction): `line`
-- goes to the online members first, the leaving one included. The
-- invitations it sent go with it. With one member left the clan dissolves;
-- without its leader the first captain, else the first member, in join
-- order, leads. Returns the names to tell.
local function remove_member(name, line)
	local clan, id = clan_of(name)
	if not clan then return nil end
	local names = members_of(clan)
	announce(clan, line)
	local record, index = record_of(clan, name)
	table.remove(clan.members, index)
	membership[name] = nil
	if #clan.members == 1 then
		local last = clan.members[1].name
		membership[last], state.clans[id] = nil, nil
		for _, member in ipairs({name, last}) do
			if grug_parties.is_online(member) then say(member, "The clan has been dissolved.") end
		end
	elseif record.role == "leader" then
		local heir = successor(clan)
		heir.role = "leader"
		announce(clan, heir.name .. " now leads the clan.")
	end
	persist()
	emit(clear_sent(name), "invitation")
	return names
end
function grug_clans.leave(player)
	local name = actor(player)
	if not name then return false, "Player must be online." end
	if not membership[name] then return false, "You do not belong to a clan." end
	emit(remove_member(name, name .. " left the clan."), "membership")
	return true, "Left the clan."
end

-- The clan and both records when `viewer` and `target` are two members of
-- one clan, else nil.
local function pair(viewer, target)
	if not viewer or type(target) ~= "string" then return nil end
	viewer = name_of(viewer)
	if viewer == target then return nil end
	local clan, id = clan_of(viewer)
	if not clan or membership[target] ~= id then return nil end
	return clan, record_of(clan, viewer), (record_of(clan, target))
end
-- The rules of Round 76 ruling 6, for the Social tab's buttons; the actions
-- below ask them again. Offline targets count like online ones.
function grug_clans.can_kick(viewer, target)
	local clan, own, other = pair(viewer, target)
	return clan ~= nil and (own.role == "leader" or own.role == "captain" and other.role == "member")
end
function grug_clans.can_promote(viewer, target)
	local clan, own, other = pair(viewer, target)
	return clan ~= nil and own.role == "leader" and other.role == "member"
end
function grug_clans.can_demote(viewer, target)
	local clan, own, other = pair(viewer, target)
	return clan ~= nil and own.role == "leader" and other.role == "captain"
end
function grug_clans.can_transfer(viewer, target)
	local clan, own = pair(viewer, target)
	return clan ~= nil and own.role == "leader"
end
-- An online actor and the rule: the clan, both records and the actor's
-- name, or nil and the refusal.
local function act(player, target, rule, refusal)
	local name = actor(player)
	if not name then return nil, "Player must be online." end
	if not pair(name, target) then return nil, "Choose another member of your clan." end
	if not rule(name, target) then return nil, refusal end
	local clan, own, other = pair(name, target)
	return clan, own, other, name
end
function grug_clans.kick(player, target)
	local clan, own, _, name = act(player, target, grug_clans.can_kick,
		"You may not remove that member.")
	if not clan then return false, own end
	emit(remove_member(target, target .. " was removed from the clan by " .. name .. "."), "membership")
	return true, "Member removed."
end
function grug_clans.promote(player, target)
	local clan, own, other = act(player, target, grug_clans.can_promote,
		"Only the clan leader makes members captains.")
	if not clan then return false, own end
	other.role = "captain"
	persist()
	announce(clan, target .. " is now a captain.")
	emit(members_of(clan), "role")
	return true, "Made captain."
end
function grug_clans.demote(player, target)
	local clan, own, other = act(player, target, grug_clans.can_demote,
		"Only the clan leader makes captains members.")
	if not clan then return false, own end
	other.role = "member"
	persist()
	announce(clan, target .. " is now a member.")
	-- A member may not invite: the invitations it sent as a captain go.
	emit(clear_sent(target), "invitation")
	emit(members_of(clan), "role")
	return true, "Made member."
end
-- The old leader becomes a captain and so keeps the invitations it sent.
function grug_clans.transfer_leader(player, target)
	local clan, own, other = act(player, target, grug_clans.can_transfer,
		"Only the clan leader may hand over the lead.")
	if not clan then return false, own end
	own.role, other.role = "captain", "leader"
	persist()
	announce(clan, target .. " now leads the clan.")
	emit(members_of(clan), "role")
	return true, "Leadership transferred."
end

--
-- Queries
--

function grug_clans.in_clan(player)
	return membership[name_of(player)] ~= nil
end
function grug_clans.same_clan(a, b)
	local id = membership[name_of(a)]
	return id ~= nil and id == membership[name_of(b)]
end
-- "leader", "captain", "member" or nil.
function grug_clans.role_of(player)
	local clan = clan_of(name_of(player))
	local record = clan and record_of(clan, name_of(player))
	return record and record.role
end
-- nil, or {id, leader, faction, members = {{name, role, online, level,
-- class, last_online}}} in join order; an online member's level and class
-- are live, an offline member's the last known.
function grug_clans.view(player)
	local clan, id = clan_of(name_of(player))
	if not clan then return nil end
	local view = {id = id, faction = clan.faction, members = {}}
	for _, member in ipairs(clan.members) do
		local present = online(member.name)
		local level, class = member.level, member.class
		if present then level, class = grug_xp.get_level(present), grug_classes.get_class(present) end
		view.members[#view.members + 1] = {name = member.name, role = member.role,
			online = present ~= nil, level = level, class = class, last_online = member.last_online}
		if member.role == "leader" then view.leader = member.name end
	end
	return view
end

--
-- Chat and presence
--

-- /c <text>: the clan chat (Round 76 ruling 9), in green to the online
-- members; the sender sees its own line. Needs shout like public chat (and
-- Luanti's /msg, builtin/game/chat.lua); logged like /msg.
core.register_chatcommand("c", {
	params = "<message>",
	description = "Send a message to your clan",
	privs = {shout = true},
	func = function(name, param)
		local clan, id = clan_of(name)
		if not clan then return false, "You are not in a clan." end
		local text = param:match("^%s*(.-)%s*$")
		if text == "" then return false, "Write a message after /c." end
		core.log("action", "Clan chat from " .. name .. " to clan " .. id .. ": " .. text)
		announce(clan, name .. ": " .. text)
		return true
	end,
})

local function faction_changed(player)
	local name = player:get_player_name()
	local clan = clan_of(name)
	if clan and clan.faction ~= grug_factions.get_faction(player) then
		emit(remove_member(name, name .. " left the clan (changed faction)."), "membership")
	end
end
grug_factions.register_on_faction_chosen(faction_changed)
-- grug_parties' hooks run first (a dependency): the player counts as online
-- at its join and as gone at its leave.
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local clan = clan_of(name)
	if not clan then return end
	stamp(record_of(clan, name), player)
	persist()
	faction_changed(player)
	clan = clan_of(name)
	if clan then
		announce(clan, name .. " came online.", name)
		emit(members_of(clan), "presence")
	end
end)
-- A timeout or a kick by the server counts as leaving.
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	last_send[name] = nil
	local changed = clear_sent(name, clear_incoming(name, {[name] = true}))
	emit(changed, "invitation")
	local clan = clan_of(name)
	if not clan then return end
	stamp(record_of(clan, name), player)
	persist()
	announce(clan, name .. " went offline.", name)
	emit(members_of(clan), "presence")
end)
-- At shutdown the engine runs this before it kicks the players
-- (src/server.cpp, Server::~Server); their leave hooks come from the
-- connection afterwards, if at all, so the time is taken here.
core.register_on_shutdown(function()
	local any = false
	for name, id in pairs(membership) do
		local player = online(name)
		if player then
			stamp(record_of(state.clans[id], name), player)
			any = true
		end
	end
	if any then persist() end
end)
grug_xp.register_on_level_change(function(player)
	local name = player:get_player_name()
	emit(members_of(clan_of(name), {[name] = true}), "level")
end)
grug_classes.register_on_class_chosen(function(player)
	local name = player:get_player_name()
	emit(members_of(clan_of(name), {[name] = true}), "class")
end)

-- The Social tab's clan card and the clan parts of its Online Players rows
-- (Round 76 lane SOCIAL), installed into grug_parties/ui.lua.
dofile(core.get_modpath(core.get_current_modname()) .. "/social.lua")
