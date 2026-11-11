-- Round 76 lane CLAN portable test (LuaJIT): clans, the /c clan chat and the
-- /p party chat.
--
--   luajit tools/r76_clan/portable_test.lua [repo]
--
-- Loads the REAL grug_parties/init.lua (its ui.lua and hud.lua skipped) and
-- the REAL grug_clans/init.lua (its social.lua skipped) on a fake engine
-- with a clock, core.after, mod storage, chat and the join, leave and
-- shutdown hooks; factions,
-- levels and classes are stubs. Checks:
--   F  forming by invite and accept: the inviter leads, no one-member clan,
--      the invitation line, pending rows, a duplicate invite, the joined line;
--   L  the 100 limit, at the invite and again at the accept;
--   R  every role permission (invite, kick, promote, demote, make leader) for
--      every pair of roles in both directions and on oneself, can_* and the
--      action alike (a refusal changes nothing); each allowed action once,
--      with its line; a demoted captain's and a kicked or leaving member's
--      sent invitations go, a leader who hands over keeps its;
--   S  succession: the first captain in join order, else the first member;
--   D  dissolving at one member by leave, by kick and by a faction change;
--   X  a faction change in a larger clan, at the event and at a join;
--   I  invitations: other faction, offline, a member holds none, expiry
--      after 120 s (and its change event), one per second per sender, ten
--      pending per recipient, the switch off and on (party invitations still
--      arrive);
--   O  an offline kick, last_online at logout and shutdown, offline level
--      and class in the view;
--   P  persistence through a save and a fresh module load from the stored
--      string; validation at load (broken entries dropped with a log line,
--      a second leader made captain, a missing leader succeeded, unreadable
--      storage kept aside);
--   C  /c and /p: shout, recipients (online members only, the sender
--      included), colours and prefixes, the server log, the one-line answers
--      without a group or text;
--   E  presence lines to the other online members only, at login, logout and
--      a timeout;
--   G  a party and a clan are independent.

local repo = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end

--
-- Fake engine
--

local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local parts, keys = {}, {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local us, wall = 1000000, 1700000000
os.time = function() return wall end -- luacheck: ignore
local current_mod = "grug_parties"
local stores, steps, jobs, hooks, commands, logs = {}, {}, {}, {}, {}, {}
local players, joined, chats = {}, {}, {}
local function hook(kind)
	return function(fn) hooks[#hooks + 1] = {kind = kind, mod = current_mod, fn = fn} end
end
local function run_hooks(kind, ...)
	for _, entry in ipairs(hooks) do
		if entry.kind == kind then entry.fn(...) end
	end
end
core = {
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function()
		local store = stores[current_mod] or {}
		stores[current_mod] = store
		return {get_string = function(_, key) return store[key] or "" end,
			set_string = function(_, key, value) store[key] = value end}
	end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local fn = loadstring(text)
		if not fn then return nil end
		local ok, value = pcall(fn)
		return ok and value or nil
	end,
	get_us_time = function() return us end,
	after = function(delay, fn, ...)
		jobs[#jobs + 1] = {at = us + delay * 1000000, fn = fn, args = {...}}
	end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = hook("join"),
	register_on_leaveplayer = hook("leave"),
	register_on_shutdown = hook("shutdown"),
	register_chatcommand = function(name, def) commands[name] = def end,
	get_player_by_name = function(name) return joined[name] and players[name] or nil end,
	chat_send_player = function(name, text)
		chats[name] = chats[name] or {}
		chats[name][#chats[name] + 1] = text
	end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
}
minetest = core

local function run_jobs()
	local ran = true
	while ran do
		ran = false
		table.sort(jobs, function(a, b) return a.at < b.at end)
		for index, job in ipairs(jobs) do
			if job.at <= us then
				table.remove(jobs, index)
				job.fn(unpack(job.args))
				ran = true
				break
			end
		end
	end
end
-- Advances both clocks by `seconds` in 0.5 s server steps.
local function advance(seconds)
	local t = 0
	while t < seconds - 1e-9 do
		t = t + 0.5
		us, wall = us + 500000, wall + 0.5
		for _, fn in ipairs(steps) do fn(0.5) end
		run_jobs()
	end
end

local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:set_int(key, value) self.fields[key] = value ~= 0 and tostring(value) or nil end

local function make_player(name, faction, level, class)
	local p = {name = name, faction = faction, level = level or 10, class = class or "warrior",
		meta = setmetatable({fields = {}}, Meta)}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_meta() return self.meta end
	function p:get_hp() return 20 end
	function p:get_properties() return {hp_max = 20} end
	players[name] = p
	return p
end
local function join(p)
	joined[p.name] = true
	run_hooks("join", p)
end
local function leave(p, timed_out)
	run_hooks("leave", p, timed_out)
	joined[p.name] = nil
end
local function player(name, faction, level, class)
	local p = make_player(name, faction or "accord", level, class)
	join(p)
	return p
end

-- Chat: the lines a player got since the last look.
local function heard(name)
	local list = chats[name] or {}
	chats[name] = nil
	return list
end
local function forget_chat() chats = {} end
local function got(name, text, label)
	local list = chats[name] or {}
	for _, line in ipairs(list) do
		if line == text then return check(true, label) end
	end
	return check(false, label .. " (" .. name .. " missing " .. ("%q"):format(text) ..
		"; has " .. ("%q"):format(table.concat(list, " | ")) .. ")")
end
local function nothing(name, label)
	return eq(#(chats[name] or {}), 0, label .. ": " .. name .. " heard nothing")
end
local GREEN, BLUE = "#7ee081", "#6fb6ff"
local function clan_line(text) return core.colorize(GREEN, "[Clan] " .. text) end
local function party_line(text) return core.colorize(BLUE, "[Party] " .. text) end

--
-- Neighbours and the two mods
--

grug_factions = {
	get_faction = function(p) return p.faction end,
	register_on_faction_chosen = hook("faction"),
}
grug_xp = {
	get_level = function(p) return p and p.level or 1 end,
	register_on_level_change = hook("level"),
}
grug_classes = {
	get_class = function(p) return p.class end,
	register_on_class_chosen = hook("class"),
	register_on_race_chosen = hook("race"),
}
local real_dofile = dofile
dofile = function(path) -- luacheck: ignore
	if path:match("grug_parties/ui%.lua$") or path:match("grug_parties/hud%.lua$") then return end
	-- The Social tab's clan card (Round 76 lane SOCIAL) is tools/r76_social's.
	if path:match("grug_clans/social%.lua$") then return end
	return real_dofile(path)
end
real_dofile(repo .. "/mods/PLAYER/grug_parties/init.lua")

local events = {}
local function load_clans()
	for i = #hooks, 1, -1 do
		if hooks[i].mod == "grug_clans" then table.remove(hooks, i) end
	end
	current_mod = "grug_clans"
	grug_clans = nil
	real_dofile(repo .. "/mods/PLAYER/grug_clans/init.lua")
	current_mod = "test"
	grug_clans.register_on_change(function(names, reason)
		local list = {}
		for name in pairs(names) do list[#list + 1] = name end
		table.sort(list)
		events[#events + 1] = reason .. ":" .. table.concat(list, ",")
	end)
end
load_clans()
local C = grug_clans
local function saw(event, label)
	for _, e in ipairs(events) do
		if e == event then return check(true, label) end
	end
	return check(false, label .. " (missing event " .. event .. "; got " .. table.concat(events, " | ") .. ")")
end
local function names(view)
	local out = {}
	for _, row in ipairs(view and view.members or {}) do out[#out + 1] = row.name .. "=" .. row.role end
	return table.concat(out, ",")
end
-- Invite and accept, one second apart.
local function recruit(inviter, ...)
	for _, recipient in ipairs({...}) do
		advance(1)
		local ok, message = C.invite(inviter, recipient.name)
		check(ok and message == "Invitation sent.", "recruit: " .. inviter.name .. " invites " ..
			recipient.name .. " (" .. tostring(message) .. ")")
		ok, message = C.accept(recipient, inviter.name)
		check(ok, "recruit: " .. recipient.name .. " accepts (" .. tostring(message) .. ")")
	end
end

--
-- F: forming
--

local amy, ben, cat = player("amy"), player("ben"), player("cat")
local tom = player("tom", "throng")
check(not C.in_clan(amy) and C.view(amy) == nil, "F no clan before an accept")
check(C.can_invite(amy, ben), "F a player without a clan may invite one without a clan")
forget_chat()
local ok, message = C.invite(amy, "ben")
check(ok and message == "Invitation sent.", "F invite sent")
got("ben", "amy has invited you to join their clan. Open the Social tab to answer.",
	"F one plain invitation line naming the inviter")
nothing("amy", "F the inviter gets no chat line")
saw("invitation:amy,ben", "F the invite tells both")
check(not C.in_clan(amy), "F no one-member clan after the invite")
local rows = C.pending(ben)
eq(#rows, 1, "F one pending row")
eq(rows[1] and rows[1].inviter, "amy", "F pending inviter")
eq(rows[1] and rows[1].expires_in, 120, "F expires in 120 s")
eq(rows[1] and rows[1].clan_size, 0, "F clan_size 0 without a clan")
eq(rows[1] and rows[1].level, 10, "F the inviter's level")
check(not C.can_invite(amy, ben), "F no second invite while one is pending")
ok, message = C.invite(amy, "ben")
check(ok and message == "Invitation already pending.", "F a duplicate invite is a no-op")
forget_chat()
events = {}
ok, message = C.accept(ben, "amy")
check(ok and message == "Joined the clan.", "F accept")
local view = C.view(ben)
eq(view and view.leader, "amy", "F the inviter leads")
eq(names(view), "amy=leader,ben=member", "F two members in join order")
eq(view and view.faction, "accord", "F the clan's faction")
check(C.in_clan(amy) and C.in_clan("ben") and C.same_clan(amy, "ben"), "F in_clan and same_clan")
check(not C.same_clan(amy, cat) and not C.same_clan(cat, tom), "F same_clan false outside")
eq(C.role_of("amy"), "leader", "F role_of leader")
eq(C.role_of(ben), "member", "F role_of member")
eq(C.role_of(cat), nil, "F role_of outside")
got("amy", clan_line("ben joined the clan."), "F joined line to the leader")
got("ben", clan_line("ben joined the clan."), "F joined line to the new member")
nothing("cat", "F outsiders hear nothing")
eq(#C.pending(ben), 0, "F a member holds no invitations")
saw("membership:amy,ben", "F the accept tells the clan")
check(not C.can_invite(cat, amy), "F a clan member cannot be invited")
ok, message = C.invite(cat, "amy")
eq(message, "That player already belongs to a clan.", "F invite of a member refused")

--
-- I: invitation rules
--

ok, message = C.invite(amy, "tom")
eq(message, "Clan members must belong to the same faction.", "I other faction refused")
check(not C.can_invite(amy, tom) and not C.can_invite(tom, cat), "I no Clan button across factions")
local ghost = make_player("ghost", "accord")
ok, message = C.invite(amy, "ghost")
eq(message, "Both players must be online.", "I offline target refused")
check(not C.can_invite(amy, ghost), "I no Clan button for an offline player")
ok, message = C.invite(ben, "cat")
eq(message, "Only the clan leader and captains may invite.", "I a member may not invite")
check(not C.can_invite(ben, cat), "I no Clan button for a member")
ok, message = C.invite(cat, "cat")
eq(message, "You cannot invite yourself.", "I not oneself")
-- One per second per sender.
local dan, eve = player("dan"), player("eve")
advance(1)
check((C.invite(amy, "cat")), "I first invite")
ok, message = C.invite(amy, "dan")
eq(message, "Wait one second between invitations.", "I second invite inside the second refused")
advance(1)
check((C.invite(amy, "dan")), "I after one second it goes")
-- Expiry: 120 s, then the timer tells both.
advance(118)
eq(#C.pending(cat), 1, "I still pending at 119 s")
events = {}
advance(2)
eq(#C.pending(cat), 0, "I expired after 120 s")
saw("invitation:amy,cat", "I the expiry tells recipient and inviter")
ok, message = C.accept(cat, "amy")
eq(message, "Invitation expired or unavailable.", "I an expired invitation cannot be accepted")
check(C.can_invite(amy, cat), "I the Clan button comes back after expiry")
advance(2) -- dan's expires too
-- Ten pending per recipient.
local senders = {}
for i = 1, 11 do senders[i] = player(("s%02d"):format(i)) end
for i = 1, 10 do check((C.invite(senders[i], "eve")), "I invite " .. i .. " of 10") end
ok, message = C.invite(senders[11], "eve")
eq(message, "That player has too many pending clan invitations.", "I the eleventh refused")
eq(#C.pending(eve), 10, "I ten pending")
-- Decline.
ok = C.decline(eve, "s01")
check(ok and #C.pending(eve) == 9, "I decline")
check(C.can_invite(senders[1], eve), "I the decliner's Clan button comes back")
-- The switch: off clears and refuses, party invitations still arrive.
events = {}
ok, message = C.set_invitations_enabled(eve, false)
check(ok and message == "Clan invitations disabled.", "I switch off")
eq(eve.meta.fields["grug_clans:invites_off"], "1", "I switch saved in player meta")
check(not C.invitations_enabled(eve), "I invitations_enabled false")
eq(#C.pending(eve), 0, "I switch off clears pending")
saw("preferences:eve", "I switch tells the Social tab")
ok, message = C.invite(senders[11], "eve")
eq(message, "That player has disabled clan invitations.", "I refused while off")
check(not C.can_invite(senders[11], eve), "I no Clan button while off")
check((grug_parties.invite(senders[11], "eve")), "I a party invitation still arrives")
check(grug_parties.invitations_enabled(eve), "I the party switch is untouched")
check(C.set_invitations_enabled(eve, true) and C.invitations_enabled(eve), "I switch on")
eq(eve.meta.fields["grug_clans:invites_off"], nil, "I on is the default (no key)")
advance(1)
check((C.invite(senders[11], "eve")), "I invites arrive again")
advance(121)
-- A leaving player's invitations go, sent and held.
advance(1)
check((C.invite(senders[2], "eve")), "I invite before a leave")
leave(senders[2])
eq(#C.pending(eve), 0, "I the inviter's leave drops its invitations")
join(senders[2])

--
-- L: the 100 limit
--

local big = {}
for i = 1, 101 do big[i] = player(("p%03d"):format(i)) end
for i = 2, 98 do recruit(big[1], big[i]) end
eq(#C.view(big[1]).members, 98, "L 98 members")
recruit(big[1], big[99])
advance(1)
check((C.invite(big[1], "p100")), "L invite at 99")
advance(1)
check((C.invite(big[1], "p101")), "L a second invite at 99")
check((C.accept(big[100], "p001")), "L the hundredth joins")
eq(#C.view(big[1]).members, 100, "L 100 members")
ok, message = C.accept(big[101], "p001")
eq(message, "The clan is full.", "L the accept checks the limit again")
advance(1)
ok, message = C.invite(big[1], "cat")
eq(message, "The clan is full.", "L a full clan cannot invite")
check(not C.can_invite(big[1], cat), "L no Clan button for a full clan")
for i = 1, 101 do leave(big[i]) end

--
-- R: every role permission
--

-- A fresh clan: leader, two captains, two members, and an outsider.
local function fresh(prefix)
	local l, c1, c2, m1, m2 = player(prefix .. "l"), player(prefix .. "c1"), player(prefix .. "c2"),
		player(prefix .. "m1"), player(prefix .. "m2")
	recruit(l, c1, c2, m1, m2)
	check(C.promote(l, c1.name) and C.promote(l, c2.name), "R setup captains")
	return {leader = l, captain = c1, captain2 = c2, member = m1, member2 = m2}
end
local function roles_of(set)
	local out = {}
	for _, key in ipairs({"leader", "captain", "captain2", "member", "member2"}) do
		out[#out + 1] = key .. "=" .. tostring(C.role_of(set[key]))
	end
	return table.concat(out, ",")
end
local set = fresh("r")
local outsider = player("rout")
local ROLE_KEYS = {"leader", "captain", "member"}
local function target_of(viewer_role, target_role)
	return target_role == viewer_role and set[target_role .. "2"] or set[target_role]
end
local allowed = {
	kick = {leader = {captain = true, member = true}, captain = {member = true}},
	promote = {leader = {member = true}},
	demote = {leader = {captain = true}},
	transfer = {leader = {captain = true, member = true}},
}
local actions = {kick = C.kick, promote = C.promote, demote = C.demote, transfer = C.transfer_leader}
local can = {kick = C.can_kick, promote = C.can_promote, demote = C.can_demote, transfer = C.can_transfer}
local before = roles_of(set)
for action, rule in pairs(allowed) do
	for _, viewer_role in ipairs(ROLE_KEYS) do
		local viewer = set[viewer_role]
		check(not can[action](viewer, viewer.name), "R " .. action .. " never oneself (" .. viewer_role .. ")")
		check(not actions[action](viewer, viewer.name), "R " .. action .. " refuses oneself (" .. viewer_role .. ")")
		for _, target_role in ipairs(ROLE_KEYS) do
			local target = target_of(viewer_role, target_role)
			if target then
				local want = (rule[viewer_role] or {})[target_role] == true
				local label = "R " .. action .. " " .. viewer_role .. " -> " .. target_role
				eq(can[action](viewer, target.name), want, label)
				eq(can[action](viewer.name, target.name), want, label .. " (by name)")
				if not want then
					check(not actions[action](viewer, target.name), label .. ": the action refuses")
				end
			end
		end
		check(not can[action](viewer, outsider.name), "R " .. action .. " never an outsider")
	end
end
eq(roles_of(set), before, "R refusals changed nothing")
eq(#C.view(set.leader).members, 5, "R refusals removed no one")
check(C.can_invite(set.leader, outsider), "R the leader invites")
check(C.can_invite(set.captain, outsider), "R a captain invites")
check(not C.can_invite(set.member, outsider), "R a member does not invite")
-- The allowed actions once each, with their lines.
forget_chat()
ok, message = C.kick(set.captain, set.member2.name)
check(ok and message == "Member removed.", "R a captain kicks a member")
got(set.member2.name, clan_line("rm2 was removed from the clan by rc1."), "R the kicked hears it")
got(set.leader.name, clan_line("rm2 was removed from the clan by rc1."), "R the clan hears it")
check(not C.in_clan(set.member2), "R kicked out")
forget_chat()
ok, message = C.promote(set.leader, set.member.name)
check(ok and message == "Made captain.", "R the leader promotes")
got(set.captain.name, clan_line("rm1 is now a captain."), "R promoted line")
-- A demoted captain's sent invitations go.
advance(1)
check((C.invite(set.captain2, outsider.name)), "R a captain's invitation")
forget_chat()
events = {}
ok, message = C.demote(set.leader, set.captain2.name)
check(ok and message == "Made member.", "R the leader demotes")
got(set.member.name, clan_line("rc2 is now a member."), "R demoted line")
eq(#C.pending(outsider), 0, "R the demoted captain's invitations go")
saw("invitation:rout", "R the recipient is told")
saw("role:rc1,rc2,rl,rm1", "R a role change tells the clan")
-- Make leader: the old leader becomes a captain and keeps its invitations.
advance(1)
check((C.invite(set.leader, outsider.name)), "R the leader's invitation")
forget_chat()
ok, message = C.transfer_leader(set.leader, set.captain2.name)
check(ok and message == "Leadership transferred.", "R the leader hands over to a member")
eq(C.role_of(set.leader), "captain", "R the old leader becomes a captain")
eq(C.role_of(set.captain2), "leader", "R the new leader")
eq(C.view(set.leader).leader, "rc2", "R view leader")
got(set.member.name, clan_line("rc2 now leads the clan."), "R new leader line")
eq(#C.pending(outsider), 1, "R the old leader (a captain) keeps its invitations")
-- The new leader kicks a captain; the old leader kicks no one any more.
check(not C.can_kick(set.leader, set.captain2.name), "R the old leader cannot kick the leader")
ok = C.kick(set.captain2, set.leader.name)
check(ok and not C.in_clan(set.leader), "R the leader kicks a captain")
eq(#C.pending(outsider), 0, "R a kicked member's invitations go")
-- A leaving member's invitations go too.
advance(1)
check((C.invite(set.member, outsider.name)), "R a captain invites before leaving")
ok, message = C.leave(set.member)
check(ok and message == "Left the clan.", "R leave")
eq(#C.pending(outsider), 0, "R a leaving member's invitations go")

--
-- S: succession in join order
--

local sl, sm1, sc1, sm2, sc2 = player("sl"), player("sm1"), player("sc1"), player("sm2"), player("sc2")
recruit(sl, sm1, sc1, sm2, sc2)
check(C.promote(sl, "sc1") and C.promote(sl, "sc2"), "S captains")
forget_chat()
C.leave(sl)
eq(C.role_of(sc1), "leader", "S the first captain in join order leads (not the earlier member)")
got("sm1", clan_line("sc1 now leads the clan."), "S new leader line")
C.leave(sc1)
eq(C.role_of(sc2), "leader", "S then the next captain")
C.leave(sc2)
eq(C.role_of(sm1), "leader", "S without a captain the first member in join order")
eq(names(C.view(sm2)), "sm1=leader,sm2=member", "S the rest")

--
-- D: dissolving at one member
--

forget_chat()
ok = C.leave(sm2)
check(ok and not C.in_clan(sm1) and not C.in_clan(sm2), "D by leave: both clanless")
got("sm1", clan_line("The clan has been dissolved."), "D dissolved line to the last")
got("sm2", clan_line("The clan has been dissolved."), "D dissolved line to the leaver")
local da, db = player("da"), player("db")
recruit(da, db)
ok = C.kick(da, "db")
check(ok and not C.in_clan(da) and not C.in_clan(db), "D by kick")
recruit(da, db)
db.faction = "throng"
forget_chat()
run_hooks("faction", db, "throng")
check(not C.in_clan(da) and not C.in_clan(db), "D by a faction change")
got("da", clan_line("db left the clan (changed faction)."), "D the faction line")
got("da", clan_line("The clan has been dissolved."), "D dissolved after the faction change")
local leftover = {}
for _, clan in pairs(core.deserialize(stores.grug_clans.clans).clans) do
	for _, member in ipairs(clan.members) do
		if ({sm1 = 1, sm2 = 1, da = 1, db = 1})[member.name] then leftover[#leftover + 1] = member.name end
	end
end
eq(table.concat(leftover, ","), "", "D no dissolved clan stays stored")
db.faction = "accord"

--
-- X: a faction change in a larger clan, live and at a join
--

local xa, xb, xc = player("xa"), player("xb"), player("xc")
recruit(xa, xb, xc)
xc.faction = "throng"
run_hooks("faction", xc, "throng")
eq(names(C.view(xa)), "xa=leader,xb=member", "X the changer goes, the clan stays")
xc.faction = "accord"
recruit(xa, xc)
leave(xc)
xc.faction = "throng"
forget_chat()
join(xc)
check(not C.in_clan(xc), "X a faction changed while offline goes at the join")
got("xb", clan_line("xc left the clan (changed faction)."), "X its line")
for _, line in ipairs(chats.xb or {}) do
	check(line ~= clan_line("xc came online."), "X no presence line for a removed member")
end

--
-- E: presence lines
--

forget_chat()
leave(xb)
got("xa", clan_line("xb went offline."), "E logout line to the others")
nothing("xb", "E not to the leaver")
nothing("xc", "E not to outsiders")
events = {}
join(xb)
got("xa", clan_line("xb came online."), "E login line to the others")
nothing("xb", "E not to the one logging in")
saw("presence:xa,xb", "E presence tells the clan")
forget_chat()
leave(xb, true)
got("xa", clan_line("xb went offline."), "E a timeout counts as leaving")
join(xb)

--
-- O: offline kick, last_online, offline level and class
--

local oa, ob, oc = player("oa", nil, 20, "mage"), player("ob", nil, 30, "priest"), player("oc")
recruit(oa, ob, oc)
local t_leave = wall
ob.level = 31
leave(ob)
ob.level, ob.class = 99, "scout" -- unseen while offline
local row
for _, r in ipairs(C.view(oa).members) do if r.name == "ob" then row = r end end
check(row and row.online == false, "O offline row")
eq(row and row.last_online, t_leave, "O last_online is the logout time")
eq(row and row.level, 31, "O the last known level")
eq(row and row.class, "priest", "O the last known class")
for _, r in ipairs(C.view(oa).members) do
	if r.name == "oa" then
		check(r.online and r.level == 20 and r.class == "mage", "O an online row is live")
	end
end
ok = C.kick(oa, "ob")
check(ok and not C.in_clan("ob"), "O an offline member can be kicked")
join(ob)
advance(10)
local t_shutdown = wall
run_hooks("shutdown")
local stored = core.deserialize(stores.grug_clans.clans)
local shut
for _, clan in pairs(stored.clans) do
	for _, member in ipairs(clan.members) do
		if member.name == "oc" then shut = member.last_online end
	end
end
eq(shut, t_shutdown, "O shutdown stamps the online members")

--
-- P: persistence and validation
--

local before_views = {}
for _, who in ipairs({"amy", "xa", "oa", "rc2"}) do before_views[who] = serialize(C.view(who)) end
advance(1)
check((C.invite(amy, "cat")), "P a pending invitation before the reload")
load_clans()
C = grug_clans
for who, text in pairs(before_views) do
	eq(serialize(C.view(who)), text, "P " .. who .. "'s clan survives a reload")
end
eq(#C.pending(cat), 0, "P invitations are session state")
eq(C.role_of("rc2"), "leader", "P roles survive")
-- A new clan after the reload takes a fresh id.
advance(1)
local na, nb = player("na"), player("nb")
recruit(na, nb)
check(C.view(na).id ~= C.view(amy).id and C.view(na).id ~= C.view(xa).id, "P a fresh id")
-- Validation: broken entries dropped with a log line, never a crash.
stores.grug_clans.clans = core.serialize({next_id = "x", clans = {
	["1"] = {faction = "accord", members = {
		{name = "v1", role = "leader", level = 5}, {name = "v2", role = "leader", level = 6},
		{name = "v3", role = "boss", level = 7}}},
	["2"] = {faction = "accord", members = {
		{name = "v2", role = "member", level = 6}, {name = "w1", role = "member", level = 1.5},
		{name = "w2", role = "member", level = 3}, {name = "w3", role = "captain", level = 3},
		{name = "w4", role = "member", level = 3}}},
	["3"] = {faction = "accord", members = {{name = "y1", role = "leader", level = 2}}},
	["4"] = "broken",
	[5] = {faction = "accord", members = {}},
}})
logs = {}
ok = pcall(load_clans)
check(ok, "P a broken store loads without a crash")
C = grug_clans
eq(names(C.view("v1")), "v1=leader,v2=captain", "P a second leader becomes a captain, a bad role goes")
eq(names(C.view("w2")), "w2=member,w3=leader,w4=member",
	"P a clan without a leader gets the first captain, join order kept")
eq(C.in_clan("w1"), false, "P a member with a broken level goes")
eq(C.same_clan("v2", "w2"), false, "P a duplicate member stays in its first clan only")
eq(C.in_clan("y1"), false, "P a one-member clan goes")
local warnings = 0
for _, line in ipairs(logs) do if line:match("^warning: %[grug_clans%]") then warnings = warnings + 1 end end
check(warnings >= 5, "P each drop logs a warning (" .. warnings .. ")")
advance(1)
local fa, fb = player("fa"), player("fb")
recruit(fa, fb)
eq(C.view(fa).id, "3", "P next_id recovers past the highest stored id")
stores.grug_clans.clans = "return {"
logs = {}
ok = pcall(load_clans)
C = grug_clans
check(ok and not C.in_clan("fa"), "P unreadable storage: empty, no crash")
eq(stores.grug_clans.clans_unreadable, "return {", "P the unreadable text is kept aside")
check(logs[1] and logs[1]:match("^error:"), "P an error line")

--
-- C: /c and /p
--

local ga, gb, gc, gd = player("ga"), player("gb"), player("gc"), player("gd")
recruit(ga, gb, gd)
leave(gd)
eq(commands.c and commands.c.privs and commands.c.privs.shout, true, "C /c needs shout")
eq(commands.p and commands.p.privs and commands.p.privs.shout, true, "C /p needs shout")
forget_chat()
logs = {}
ok, message = commands.c.func("gb", "  hello clan  ")
check(ok == true and message == nil, "C /c answers nothing on success")
got("ga", clan_line("gb: hello clan"), "C /c reaches an online member in green")
got("gb", clan_line("gb: hello clan"), "C the sender sees its own line")
nothing("gc", "C /c not to outsiders")
nothing("gd", "C /c not to offline members")
eq(logs[#logs], "action: Clan chat from gb to clan " .. C.view(ga).id .. ": hello clan", "C /c logged at action")
ok, message = commands.c.func("gc", "hi")
check(ok == false and message == "You are not in a clan.", "C /c without a clan: one plain line")
ok, message = commands.c.func("gb", "   ")
check(ok == false and message == "Write a message after /c.", "C /c without text: one plain line")
-- /p.
advance(1)
check((grug_parties.invite(ga, "gc")) and (grug_parties.accept(gc, "ga")), "C a party ga + gc")
forget_chat()
logs = {}
ok, message = commands.p.func("gc", "to the party")
check(ok == true and message == nil, "C /p answers nothing on success")
got("ga", party_line("gc: to the party"), "C /p reaches a member in blue")
got("gc", party_line("gc: to the party"), "C the sender sees its own /p line")
nothing("gb", "C /p not to clan mates outside the party")
eq(logs[#logs], "action: Party chat from gc to party " .. grug_parties.view(ga).id ..
	": to the party", "C /p logged at action")
ok, message = commands.p.func("gb", "hi")
check(ok == false and message == "You are not in a party.", "C /p without a party: one plain line")
ok, message = commands.p.func("ga", "")
check(ok == false and message == "Write a message after /p.", "C /p without text: one plain line")
leave(gc)
forget_chat()
commands.p.func("ga", "anyone")
nothing("gc", "C /p not to offline party members")
join(gc)

--
-- G: a party and a clan are independent
--

check(grug_parties.view(ga) and C.view(ga), "G ga is in a party and a clan")
check(not C.in_clan(gc) and grug_parties.in_party(gb) == false, "G the two groups differ")
local h1 = player("h1")
local h2 = player("h2")
recruit(h1, h2)
advance(1)
check((grug_parties.invite(ga, "h1")) and (grug_parties.accept(h1, "ga")),
	"G a party holds players of different clans")
grug_parties.leave(ga)
check(C.view(ga) and #C.view(ga).members == 3, "G leaving the party keeps the clan")
C.leave(h1)
check(grug_parties.view(gc) ~= nil, "G leaving a clan keeps the party")
eq(#C.pending(gc) + #grug_parties.pending(gc), 0, "G nothing pending")

if failures > 0 then
	error(("R76 CLAN PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R76 CLAN PORTABLE PASS checks=" .. checks)
