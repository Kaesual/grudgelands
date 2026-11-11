-- Disposable engine probe (Round 76 lane SOCIAL): the Social tab in four
-- cards, for screenshots. Never shipped: tools/r76_social/capture.sh stages
-- it through tools/luanti_headless.sh and connects one real client. The
-- driver (character creation, SHOT / ack handshake) and the stand-in
-- players follow tools/r67_social's probe.
--
-- One real player (an Accord Human Warrior) and FAKE other online players
-- (ObjectRef stand-ins with faction, class, race and XP in their meta, added
-- to core.get_connected_players while the tab is built and to
-- grug_parties.is_online). A fake cannot accept an invitation, so the party,
-- the clan and the pending invitations are stand-ins too: grug_parties.view,
-- pending and can_invite and grug_clans.view, pending, same_clan, in_clan,
-- role_of, can_invite and the can_* of the buttons are wrapped for the
-- shots, the can_* with the rules of Round 76 ruling 6 on the fake clan.
-- The clan card and the rows are the real code (grug_clans/social.lua,
-- grug_parties/ui.lua). Shots: no party and no clan; in a party and a clan
-- of 23 as leader, as captain and as member (offline members with ages);
-- the pending clan invitations; the list scrolled to the end as leader;
-- the offline tab's page 2 (fix round 1).

local P = "[r76social] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r76social_settle") or "") or 3
local PAGE = grug_parties.PAGE

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r76social_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The stand-ins (tools/r67_social's): both factions, every class and race.
local NAMES = {"Aldric", "brannoc", "Celwyn", "Dorrik_Stonehand", "elowen", "Fenn",
	"Gorza", "Hruk", "Isolde", "jarl", "Kethra", "Lorn", "Mirabel_the_Patient", "Nox",
	"Orrin", "Pell", "Quilla", "Rask", "Sable", "Toma", "Ulf", "Vesna", "Wren", "Xarg",
	"Yeva", "Zoltan", "Ash", "Bryn", "Cora", "Dain", "Edda", "Falk"}
local ACCORD, THRONG = {"human", "dwarf", "elf"}, {"orc", "troll", "undead"}
local CLASSES = {"warrior", "mage", "priest", "scout"}
local fakes, fake_by_name, fake_objects = {}, {}, {}
for index, name in ipairs(NAMES) do
	local accord = index % 3 ~= 0
	local level = 1 + (index * 7) % 60
	local fields = {
		["grug_factions:faction"] = accord and "accord" or "throng",
		["grug_classes:class"] = CLASSES[index % 4 + 1],
		["grug_classes:race"] = (accord and ACCORD or THRONG)[index % 3 + 1],
		["grug_xp:xp"] = tostring(grug_xp.xp_for_level(level)),
	}
	local meta = {get_string = function(_, key) return fields[key] or "" end,
		get_int = function(_, key) return tonumber(fields[key]) or 0 end}
	local fake = {get_player_name = function() return name end,
		get_meta = function() return meta end, is_player = function() return true end}
	fakes[#fakes + 1] = fake
	fake_objects[name] = fake
	fake_by_name[name] = {index = index, accord = accord, level = level, class = CLASSES[index % 4 + 1]}
end
local connected, by_name = core.get_connected_players, core.get_player_by_name
-- During a build the stand-ins are players by name too (their class and
-- race icons in the party and clan rows read them).
local function fake_or_player(name) return fake_objects[name] or by_name(name) end
local function with_fakes()
	local list = connected()
	for _, fake in ipairs(fakes) do list[#list + 1] = fake end
	return list
end

-- The scene of the current shot.
local scene = {party = false, clan = nil, party_pending = {}, clan_pending = {}}

-- The fake clan: grugcap, eight online Accord stand-ins and fourteen
-- offline members with their logout ages in seconds.
local ONLINE_MATES = {"Aldric", "brannoc", "Dorrik_Stonehand", "elowen", "Gorza", "Hruk",
	"jarl", "Kethra"}
local OFFLINE = {{"Varn", 180}, {"Hollis", 2400}, {"Sefa", 7200}, {"Dunmore", 18000},
	{"Rook", 90000}, {"Asha", 180000}, {"Merrow", 260000}, {"Tamsin", 520000},
	{"Odo", 780000}, {"Brakka", 1040000}, {"Ilvren", 1730000}, {"Quill", 2680000},
	{"Lisbeth", 3900000}, {"Kestrel_of_the_Vale", 5200000}}
local OFFLINE_CLASSES = {"warrior", "mage", "priest", "scout"}
-- roles: the name -> role of everyone but grugcap's members.
local function make_clan(own_role, roles)
	local members, now = {}, os.time()
	members[1] = {name = NAME, role = own_role, online = true, level = 30, class = "warrior",
		last_online = now}
	for _, name in ipairs(ONLINE_MATES) do
		local fake = fake_by_name[name]
		members[#members + 1] = {name = name, role = roles[name] or "member", online = true,
			level = fake.level, class = fake.class, last_online = now}
	end
	for index, entry in ipairs(OFFLINE) do
		members[#members + 1] = {name = entry[1], role = roles[entry[1]] or "member", online = false,
			level = 5 + (index * 11) % 55, class = OFFLINE_CLASSES[index % 4 + 1],
			last_online = now - entry[2]}
	end
	local by_name, leader = {}, nil
	for _, member in ipairs(members) do
		by_name[member.name] = member
		if member.role == "leader" then leader = member.name end
	end
	return {id = "1", leader = leader, faction = "accord", members = members, by_name = by_name}
end

local function name_of(player) return type(player) == "string" and player or player:get_player_name() end
local function record(name) return scene.clan and scene.clan.by_name[name] end

local is_online, party_can_invite = grug_parties.is_online, grug_parties.can_invite
function grug_parties.is_online(name) return fake_by_name[name] ~= nil or is_online(name) end
function grug_parties.can_invite(inviter, recipient)
	local fake = fake_by_name[recipient]
	if not fake then return party_can_invite(inviter, recipient) end
	-- Every fifth is in a party, has invitations off or is invited already;
	-- the two in grugcap's party never.
	return fake.accord and fake.index % 5 ~= 0 and
		not (scene.party and (recipient == "Aldric" or recipient == "Hruk"))
end
local party_pending = grug_parties.pending
function grug_parties.pending(player)
	if name_of(player) ~= NAME then return party_pending(player) end
	return scene.party and {} or scene.party_pending
end
local party_view = grug_parties.view
function grug_parties.view(player)
	if not scene.party or name_of(player) ~= NAME then return party_view(player) end
	local members = {
		{name = NAME, online = true, level = 30, hp = 20, hp_max = 20, class = "warrior"},
		{name = "Aldric", online = true, level = 8, hp = 11, hp_max = 18, class = "mage"},
		{name = "Hruk", online = true, level = 57, hp = 17, hp_max = 17, class = "warrior"},
		{name = "Toma", online = false, level = 21}}
	if scene.party == "big" then
		-- Seven members: the list scrolls (fix round 1).
		table.insert(members, 4, {name = "Kethra", online = true, level = 18, hp = 6, hp_max = 16, class = "priest"})
		table.insert(members, 5, {name = "jarl", online = true, level = 11, hp = 14, hp_max = 14, class = "scout"})
		table.insert(members, 6, {name = "Gorza", online = true, level = 50, hp = 2, hp_max = 20, class = "warrior"})
	end
	return {leader = NAME, members = members}
end

function grug_clans.view(player)
	if not record(name_of(player)) then return nil end
	local view = {id = scene.clan.id, leader = scene.clan.leader, faction = "accord", members = {}}
	for index, member in ipairs(scene.clan.members) do
		view.members[index] = {name = member.name, role = member.role, online = member.online,
			level = member.level, class = member.class, last_online = member.last_online}
	end
	return view
end
function grug_clans.in_clan(player) return record(name_of(player)) ~= nil end
function grug_clans.same_clan(a, b) return record(name_of(a)) ~= nil and record(name_of(b)) ~= nil end
function grug_clans.role_of(player)
	local member = record(name_of(player))
	return member and member.role
end
function grug_clans.pending(player)
	if name_of(player) ~= NAME or scene.clan then return {} end
	return scene.clan_pending
end
function grug_clans.can_invite(inviter, recipient)
	local fake, own = fake_by_name[recipient], record(name_of(inviter))
	if not fake or record(recipient) then return false end
	if own and own.role == "member" then return false end
	-- Every fourth is in another clan or has clan invitations off.
	return fake.accord and fake.index % 4 ~= 0
end
-- Ruling 6 on the fake clan.
local function pair(viewer, target)
	local own, other = record(name_of(viewer)), record(target)
	if not own or not other or own == other then return nil end
	return own, other
end
function grug_clans.can_kick(viewer, target)
	local own, other = pair(viewer, target)
	return own ~= nil and (own.role == "leader" or own.role == "captain" and other.role == "member")
end
function grug_clans.can_promote(viewer, target)
	local own, other = pair(viewer, target)
	return own ~= nil and own.role == "leader" and other.role == "member"
end
function grug_clans.can_demote(viewer, target)
	local own, other = pair(viewer, target)
	return own ~= nil and own.role == "leader" and other.role == "captain"
end
function grug_clans.can_transfer(viewer, target)
	local own = pair(viewer, target)
	return own ~= nil and own.role == "leader"
end

local function show(player, opts)
	scene.party = opts.party or false
	scene.clan = opts.role and make_clan(opts.role, opts.roles or {}) or nil
	scene.party_pending = opts.party_pending or {}
	scene.clan_pending = opts.clan_pending or {}
	local context = sfinv.get_or_create_context(player)
	core.get_connected_players, core.get_player_by_name = with_fakes, fake_or_player
	sfinv.set_page(player, PAGE)
	context.grug_social_scroll = opts.scroll or 0
	context.grug_clan_member = opts.select
	context.grug_clan_notice = opts.notice
	context.grug_clan_tab, context.grug_clan_page = opts.tab or "online", opts.page or 1
	context.grug_party_member = opts.party_select
	context.grug_party_notice = opts.party_notice
	local formspec = sfinv.get_formspec(player, context)
	core.get_connected_players, core.get_player_by_name = connected, by_name
	log(("view: %d list rows, clan buttons %d, party buttons %d, marks %d, formspec %d bytes"):format(
		select(2, formspec:gsub("label%[1%.0,", "")), select(2, formspec:gsub(";Clan%]", "")),
		select(2, formspec:gsub(";Party%]", "")), select(2, formspec:gsub("grug_clans_mark%.png", "")),
		#formspec))
	core.show_formspec(NAME, "r76social:social", formspec)
end

local SHOTS = {
	{name = "S1_no_party_no_clan", run = function(player) show(player, {}) end},
	{name = "S2_leader_party_clan", run = function(player)
		show(player, {party = "big", role = "leader", roles = {Aldric = "captain", Varn = "captain",
			Rook = "captain"}, select = "elowen", party_select = "Aldric"})
	end},
	{name = "S3_captain", run = function(player)
		show(player, {role = "captain", roles = {Dorrik_Stonehand = "leader", Aldric = "captain"},
			select = "brannoc", notice = "Success: Invitation sent.",
			party_notice = "Refused: That player already belongs to a party.",
			party_pending = {{inviter = "Pell", level = 36, expires_in = 74, party = {members = {1, 2}}}}})
	end},
	{name = "S4_member", run = function(player)
		show(player, {party = true, role = "member", roles = {Dorrik_Stonehand = "leader",
			Aldric = "captain", Sefa = "captain"}, select = "Aldric"})
	end},
	{name = "S5_clan_invitations", run = function(player)
		show(player, {clan_pending = {
			{inviter = "Mirabel_the_Patient", level = 32, expires_in = 97, clan_size = 23},
			{inviter = "Nox", level = 39, expires_in = 41, clan_size = 0},
			{inviter = "Pell", level = 36, expires_in = 112, clan_size = 7}}})
	end},
	-- Beyond the maximum on purpose: the list clamps it to the end.
	{name = "S6_leader_list_end", run = function(player)
		show(player, {party = true, role = "leader", roles = {Aldric = "captain"}, scroll = 10000,
			select = "jarl"})
	end},
	{name = "S7_leader_offline_page2", run = function(player)
		show(player, {party = true, role = "leader", roles = {Aldric = "captain", Rook = "captain"},
			tab = "offline", page = 2, select = "Brakka"})
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		for _, name in ipairs({"Celwyn", "Gorza", "Ulf"}) do
			grug_parties.toggle_favorite(player, name)
		end
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			shot.run(player)
			log("ran " .. shot.name)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
