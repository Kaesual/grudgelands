-- Disposable engine probe (Round 67 lane SOCIAL): the Social tab and the
-- invitation box, for screenshots. Never shipped: tools/r67_social/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) follows
-- tools/r62_bags's probe.
--
-- One real player (an Accord Human Warrior) and FAKES other online players
-- the list reads (ObjectRef stand-ins with the faction, class, race and XP
-- in their meta, added to core.get_connected_players while the tab is built
-- and to grug_parties.is_online); their invite buttons follow a fixed pattern
-- (grug_parties.can_invite wrapped for them). Pending invitations, the
-- invitation box and the party are stand-ins too (grug_parties.pending,
-- newest_invitation and view wrapped), since a fake cannot invite. Shots:
-- the tab with two invitations and the list at the top, the list scrolled
-- to the end, the tab in a party, and the HUD box with the window closed.

local P = "[r67social] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r67social_settle") or "") or 3
local PAGE = grug_parties.PAGE

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r67social_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The stand-ins: names of up to 20 characters, both factions, every class
-- and race.
local NAMES = {"Aldric", "brannoc", "Celwyn", "Dorrik_Stonehand", "elowen", "Fenn",
	"Gorza", "Hruk", "Isolde", "jarl", "Kethra", "Lorn", "Mirabel_the_Patient", "Nox",
	"Orrin", "Pell", "Quilla", "Rask", "Sable", "Toma", "Ulf", "Vesna", "Wren", "Xarg",
	"Yeva", "Zoltan", "Ash", "Bryn", "Cora", "Dain", "Edda", "Falk"}
local ACCORD, THRONG = {"human", "dwarf", "elf"}, {"orc", "troll", "undead"}
local CLASSES = {"warrior", "mage", "priest", "scout"}
local fakes, fake_by_name = {}, {}
for index, name in ipairs(NAMES) do
	local accord = index % 3 ~= 0
	local fields = {
		["grug_factions:faction"] = accord and "accord" or "throng",
		["grug_classes:class"] = CLASSES[index % 4 + 1],
		["grug_classes:race"] = (accord and ACCORD or THRONG)[index % 3 + 1],
		["grug_xp:xp"] = tostring(grug_xp.xp_for_level(1 + (index * 7) % 60)),
	}
	local meta = {get_string = function(_, key) return fields[key] or "" end,
		get_int = function(_, key) return tonumber(fields[key]) or 0 end}
	local fake = {get_player_name = function() return name end,
		get_meta = function() return meta end, is_player = function() return true end}
	fakes[#fakes + 1], fake_by_name[name] = fake, {index = index, accord = accord}
end
-- Only the Social tab's builds see the stand-ins (show below): every other
-- reader of the connected players would call ObjectRef methods they lack.
local connected = core.get_connected_players
local function with_fakes()
	local list = connected()
	for _, fake in ipairs(fakes) do list[#list + 1] = fake end
	return list
end
local is_online, can_invite = grug_parties.is_online, grug_parties.can_invite
function grug_parties.is_online(name) return fake_by_name[name] ~= nil or is_online(name) end
local in_party = false
function grug_parties.can_invite(inviter, recipient)
	local fake = fake_by_name[recipient]
	if not fake then return can_invite(inviter, recipient) end
	-- Every fifth is in a party, has invitations off or is invited already.
	return fake.accord and fake.index % 5 ~= 0 and not in_party
end
local pending = grug_parties.pending
function grug_parties.pending(player)
	if in_party then return {} end
	return {{inviter = "brannoc", level = 15, expires_in = 87, party = {members = {1, 2, 3}}},
		{inviter = "Isolde", level = 22, expires_in = 41}, {inviter = "Wren", level = 9, expires_in = 112}}
end
local newest = grug_parties.newest_invitation
function grug_parties.newest_invitation(player)
	if in_party then return newest(player) end
	return {inviter = "Wren", seconds = 112, more = 2}
end
local view = grug_parties.view
function grug_parties.view(player)
	if not in_party or (type(player) == "string" and player or player:get_player_name()) ~= NAME then
		return view(player)
	end
	return {leader = NAME, members = {
		{name = NAME, online = true, level = 30, hp = 20, hp_max = 20, class = "warrior"},
		{name = "Celwyn", online = true, level = 28, hp = 11, hp_max = 18, class = "priest"},
		{name = "Fenn", online = true, level = 31, hp = 17, hp_max = 17, class = "mage"},
		{name = "Kethra", online = false, level = 26}}}
end

local function show(player, scroll, party)
	in_party = party
	local context = sfinv.get_or_create_context(player)
	core.get_connected_players = with_fakes
	sfinv.set_page(player, PAGE)
	context.grug_social_scroll = scroll
	local formspec = sfinv.get_formspec(player, context)
	core.get_connected_players = connected
	log(("list: %d rows, scroll %d of %s, formspec %d bytes"):format(
		select(2, formspec:gsub("label%[0%.65,", "")), context.grug_social_scroll,
		formspec:match("scrollbaroptions%[min=0;max=(%d+);") or "none", #formspec))
	core.show_formspec(NAME, "r67social:social", formspec)
end

local SHOTS = {
	{name = "S1_social_top", run = function(player) show(player, 0, false) end},
	-- Beyond the maximum on purpose: the list clamps it to the end.
	{name = "S2_social_end", run = function(player) show(player, 10000, false) end},
	{name = "S3_social_party", run = function(player) show(player, 0, true) end},
	{name = "S4_hud_box", run = function(player)
		in_party = false
		core.close_formspec(NAME, "r67social:social")
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
