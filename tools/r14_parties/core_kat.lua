-- Bounded production-core fixture; run with LuaJIT during development.
local root = arg[1] or "."
local checks = 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end
local function serialize(value)
	if type(value) == "string" then return string.format("%q", value) end
	if type(value) ~= "table" then return tostring(value) end
	local keys, rows = {}, {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, key in ipairs(keys) do rows[#rows + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key]) end
	return "{" .. table.concat(rows, ",") .. "}"
end
local data, players, meta, time = {}, {}, {}, 0
local joins, leaves, steps, factions, notifications, changes, env
local function boot()
	joins, leaves, steps, factions, notifications, changes = {}, {}, {}, {}, {}, {}
	local core = {
		get_current_modname = function() return "grug_parties" end,
		get_modpath = function() return root .. "/mods/PLAYER/grug_parties" end,
		get_mod_storage = function() return {
			get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value end,
		} end,
		serialize = function(value) return "return " .. serialize(value) end,
		deserialize = function(value) local chunk = assert(loadstring(value)); setfenv(chunk, {}); return chunk() end,
		get_us_time = function() return time * 1000000 end,
		get_player_by_name = function(name) return players[name] end,
		chat_send_player = function(name, text) notifications[#notifications + 1] = name .. text end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
	}
	env = setmetatable({core = core,
		-- UI/HUD callbacks have their own production-module fixture.
		dofile = function(path)
			assert(path == root .. "/mods/PLAYER/grug_parties/ui.lua" or
				path == root .. "/mods/PLAYER/grug_parties/hud.lua")
		end, grug_factions = {
		get_faction = function(player) return player.faction end,
		register_on_faction_chosen = function(fn) factions[#factions + 1] = fn end,
	}}, {__index = _G})
	local chunk = assert(loadfile(root .. "/mods/PLAYER/grug_parties/init.lua"))
	setfenv(chunk, env); chunk()
	env.grug_parties.register_on_change(function(name, reason)
		changes[#changes + 1] = name .. ":" .. reason
	end)
	return env.grug_parties
end
local function join(name, faction)
	meta[name] = meta[name] or {}
	local player = {faction = faction or "accord", hp = 75}
	function player:is_player() return true end
	function player:get_player_name() return name end
	function player:get_hp() return self.hp end
	function player:get_properties() return {hp_max = 100} end
	function player:get_meta() return {
		get_int = function(_, key) return meta[name][key] or 0 end,
		set_int = function(_, key, value) meta[name][key] = value end,
	} end
	players[name] = player
	for _, fn in ipairs(joins) do fn(player) end
	return player
end
local function logout(player)
	-- Engine may still resolve the leaving ObjectRef during the callback.
	for _, fn in ipairs(leaves) do fn(player) end
	players[player:get_player_name()] = nil
end
local function advance(seconds)
	time = time + seconds
	for _, fn in ipairs(steps) do fn(seconds) end
end
local api = boot()
local a, b, c, d = join("A"), join("B"), join("C"), join("D", "throng")
check(api.hud_enabled(a) and api.invitations_enabled(a), "defaults")
check(not api.view(a), "no singleton")
check(not api.invite(a, "A"), "self invite")
check(not api.invite(a, "D"), "faction refusal")
check(not api.invite("A", "B"), "mutations need player")
check(api.invite(a, "B"), "first invitation")
check(api.invite(a, "B") and #notifications == 1, "duplicate no notification")
check(not api.invite(a, "C"), "one second rate")
advance(1)
check(api.invite(a, "C"), "second invitation")
check(api.accept(b, "A"), "create party")
check(not api.accept(b, "A"), "duplicate accept")
check(api.leave(b) and not api.view(a), "two member dissolve")
check(api.accept(c, "A"), "inviter bound invite survives dissolve")
check(api.view(a).leader == "A" and #api.view(c).members == 2, "recreated party")
local copy = api.view(a); copy.members[1].name = "corrupt"; copy.leader = "corrupt"
check(api.view(a).leader == "A" and api.view(a).members[1].name == "A", "view copies")
advance(1); check(api.invite(a, "B"), "invite third")
check(api.accept(b, "A"), "third joins")
check(not api.kick(b, "C") and not api.transfer_leader(b, "C"), "leader authorization")
check(not api.invite(b, "D"), "member cannot invite")
logout(c)
local view = api.view(a)
check(not view.members[2].online and view.members[2].hp == nil, "offline HP absent")
check(api.leave(a) and api.view(b).leader == "C", "earliest offline successor")
c = join("C")
check(api.transfer_leader(c, "B"), "explicit leadership")
logout(b)
check(api.view(c).leader == "B", "logout retains leadership")
players = {}; api = boot(); c = join("C")
check(api.view(c).leader == "B" and #api.view(c).members == 2, "restart preserves offline leader")
check(#api.pending(c) == 0, "restart loses invitations")
b = join("B"); a = join("A"); d = join("D", "throng")
check(api.kick(b, "C") and not api.view(b), "kick dissolves two")
check(api.invite(a, "C"), "pending before optout")
check(api.set_invitations_enabled(c, false), "disable invitations")
check(#api.pending(c) == 0 and not api.accept(c, "A"), "optout removes pending")
advance(1); check(not api.invite(a, "C"), "optout refuses sends")
check(api.set_invitations_enabled(c, true), "enable invitations")
check(api.invite(a, "C"), "send again")
check(api.decline(c, "A") and #api.pending(c) == 0, "decline removes")
advance(1); check(api.invite(a, "C"), "expiry invite")
advance(120); check(not api.accept(c, "A"), "exact deadline expires")
check(#api.pending(c) == 0, "expiry pruned")
check(api.invite(a, "C"), "disconnect invite")
logout(a); a = join("A")
check(not api.accept(c, "A"), "inviter logout expires invites")
check(not api.invite(a, "C"), "reconnect does not bypass sender rate")
advance(1); check(api.invite(a, "C"), "recipient disconnect invite")
logout(c); c = join("C")
check(not api.accept(c, "A"), "recipient logout expires invites")
advance(1); check(api.invite(a, "C"), "stale authority invite")
check(api.invite(b, "A") and api.accept(a, "B"), "inviter joins another leader")
check(not api.accept(c, "A"), "ordinary member stale invite refused")
check(api.transfer_leader(b, "A") and api.accept(c, "A"), "current leader accepts old invite")
check(api.set_hud_enabled(c, false), "disable HUD")
logout(c); c = join("C")
check(not api.hud_enabled(c), "HUD preference persists")
c.faction = "throng"
for _, fn in ipairs(factions) do fn(c, "throng") end
check(not api.view(c) and #api.view(a).members == 2, "faction switch removes member")
check(api.leave(b), "clear party for capacity case")
local recipients = {}
for i = 1, 10 do
	recipients[i] = join("R" .. i)
	advance(1); check(api.invite(a, "R" .. i), "capacity pending " .. i)
end
for i = 1, 8 do check(api.accept(recipients[i], "A"), "fill " .. i) end
check(#api.view(a).members == 9, "one remaining slot")
check(api.accept(recipients[9], "A"), "first final slot")
check(not api.accept(recipients[10], "A") and #api.view(a).members == 10, "second final slot refused")
local target = join("Queue")
for i = 1, 11 do
	local sender = join("Sender" .. i)
	local ok = api.invite(sender, "Queue")
	check(ok == (i <= 10), "incoming cap " .. i)
end
check(#api.pending(target) == 10, "ten incoming")
local snapshot = api.pending(target); snapshot[1].inviter = "corrupt"
check(api.pending(target)[1].inviter ~= "corrupt", "pending copied")
check(api.set_invitations_enabled(target, false) and #api.pending(target) == 0, "clear full queue")
-- No outgoing invite can authorize a changed faction, even without its callback.
local x, y = join("X"), join("Y")
check(api.invite(x, "Y"), "faction revalidation invite")
y.faction = "throng"
check(not api.accept(y, "X"), "accept faction revalidation")
check(api.transfer_leader(a, "R1"), "transfer full party")
check(not api.kick(a, "R2"), "old leader cannot kick")
check(api.kick(recipients[1], "R2"), "new leader can kick")
check(#api.view(a).members == 9, "kick membership")
print("party-core checks=" .. checks)
print("party-core state=" .. data.parties)
