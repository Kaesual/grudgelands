-- Round 71 lane UI portable test (LuaJIT): the Expedition Registrar (the warning's
-- lines in the box and on the tab: tools/r67_social; the role change: tools/r451_nq).
--   A  the socket: the real registry takes the role on all six clerk sockets, and
--      only there; the resolver gives the capital's villager;
--   D  the dialog's rows on the REAL runs.lua, the real catalogue and the real
--      toolkit: the dropdowns offer only levels the creator may enter, a tier and then
--      a level inside it (Round 71 RANGE: only tiers with a level on offer, each
--      naming its ore and gem, the player's own level first), one row per
--      member warns and stops nobody, a member who is not the leader cannot
--      create, a run shows Enter, a refusal shows runs.lua's text, a level below
--      the entry level is refused at Enter;
--   N  the notices: the feed, never chat, to the owner's online members; a line of
--      its own for each end and each forced way out, none for a player's own way;
--   I  the invitation warning: only while the player owns an Expedition alone;
--   L  the location line and the map's bounds: the box's name, an arrow at the edge,
--      a minimap off the map holds no tile and places party members.
-- Prints "R71 UI PORTABLE PASS checks=<n>".
local repo = arg[1] or "."
local _
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function has(text, needle, label) check(text:find(needle, 1, true) ~= nil, label) end
local function hasnt(text, needle, label) check(text:find(needle, 1, true) == nil, label) end

-- ---- A fake engine ------------------------------------------------------------
local receivers, shown, closed, chat, feed, afters, huds = {}, {}, {}, {}, {}, {}, {}
local online = {}
_G.vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	distance = function(a, b)
		return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
	end,
}
_G.core = {
	get_current_modname = function() return "grug_expeditions" end,
	get_modpath = function(name)
		if name == "grug_mapgen" then return repo .. "/mods/MAPGEN/grug_mapgen" end
		return repo .. "/mods/PLAYER/" .. name
	end,
	formspec_escape = function(text) return (text:gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(color, text) return "<" .. color .. ">" .. text end,
	log = function() end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name, text} end,
	show_formspec = function(name, formname, spec) shown[name] = {form = formname, spec = spec} end,
	close_formspec = function(name) closed[name] = true end,
	register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_joinplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_mods_loaded = function() end,
	get_connected_players = function()
		local list = {}
		for _, player in pairs(online) do list[#list + 1] = player end
		return list
	end,
	get_player_by_name = function(name) return online[name] end,
	get_player_window_information = function() return nil end,
	dir_to_yaw = function() return 0 end,
	after = function(seconds, fn) afters[#afters + 1] = {seconds, fn} end,
}

local parties = {}
local party_change, member_left
_G.grug_parties = {register_on_change = function(fn) party_change = fn end,
	register_on_member_left = function(fn) member_left = fn end,
	view = function(player)
		local name = type(player) == "string" and player or player:get_player_name()
		return parties[name]
	end}
local levels = {}
_G.grug_xp = {get_level = function(player)
	return levels[type(player) == "string" and player or player:get_player_name()]
end}
_G.grug_factions = {serves = function(faction, player) return player.faction == faction end}
_G.grug_sounds = {play = function() end}
-- The resources' names from the shipped registry's own lines.
local resource_names = {}
do
	local file = assert(io.open(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
	for name, node in file:read("*a"):gmatch('name = "([^"]+)",%s*natural_node = "([^"]+)"') do
		resource_names[node] = {name = name}
	end
	file:close()
end
_G.grug_materials = {resource_for_node = function(node) return resource_names[node] end}
local trip, teleported
_G.grug_home = {
	register_on_teleport = function(fn) teleported = fn end,
	cancel = function() end,
	respawn = function() end,
	travel = function(_, row) trip = row; return true end,
	waystone_pos = function() return {x = 0, y = 0, z = 0} end,
	location = function(id)
		return ({highcourt = {faction = "accord"}, gor_drazhak = {faction = "throng"}})[id]
	end,
}
local in_combat = {}
_G.grug_core = {
	in_combat = function(player) return in_combat[player:get_player_name()] == true end,
	feed = function(player, kind, text, key)
		feed[#feed + 1] = {name = player:get_player_name(), kind = kind, text = text, key = key}
		return true
	end,
	ui_window = nil,
}
-- The real toolkit, without the viewport code: frame and text growth are its.
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_rows.lua")
local UI = grug_core.ui
UI.text_growth = function() return 1 end
UI.frame = function(w, h) return ("formspec_version[6]size[%g,%g]"):format(w, h) end

-- The real registry, with the capitals' clerk sockets and one lookalike.
local assigned, resolved = {}, nil
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local services = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/capital_services.lua")
local capitals = {}
for key in pairs(services.PLOTS) do capitals[#capitals + 1] = key end
table.sort(capitals)
check(#capitals == 6, "A six capitals")
for _, key in ipairs(capitals) do
	grug_core.register_settlement_sockets(key, "human", {x = 0, y = 10, z = 0}, {
		{id = "miners_guild/miners_guild_clerk", role = "idle", x = 1, y = 1, z = 1, dir = {x = 1, z = 0},
			tags = {"work"}},
		{id = "miners_guild/miners_guild_sorter", role = "idle", x = 2, y = 1, z = 1, dir = {x = 1, z = 0},
			tags = {"work"}},
	})
end
_G.grug_mobs = {register_start_socket_role = function(role, resolver)
	assigned[#assigned + 1] = role
	resolved = resolver
end}

-- The real runs on the real catalogue; a preparation that only queues.
local catalogue = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")
-- Two rows a dialog may offer; the catalogue ships only the hidden test row so far.
local LIST = {
	{id = "test_vault", name = "Test Vault", level = 20, max_level = 29, max_players = 3,
		template = "test_vault"},
	{id = "other", name = "The Other, Deep Vault", level = 60, max_level = 69, max_players = 4,
		template = "test_vault"},
	{id = "wide", name = "Wide Vault", level = 20, max_level = 69, max_players = 3,
		template = "test_vault"},
}
local real_definition = catalogue.definition
catalogue.definition = function(id)
	return (id == "other" and LIST[2]) or (id == "wide" and LIST[3]) or real_definition(id)
end
local queue = {}
local preparation = {
	init = function() end,
	cancel = function() end,
	enqueue = function(run, _, finish) queue[#queue + 1] = {run = run, finish = finish} end,
	status = function(run)
		for index, row in ipairs(queue) do
			if row.run == run then return {waiting = index - 1} end
		end
	end,
}
_G.grug_expeditions = {templates = {test_vault = {
	places = {arrival = {x = 1, y = 1, z = 1}}, encounters = {}}}}
local M = grug_expeditions
assert(loadfile(repo .. "/mods/PLAYER/grug_expeditions/runs.lua"))(catalogue, preparation)
M.list = function() return LIST end
local enter_hook
M.register_on_enter = function(fn) enter_hook = fn end
dofile(repo .. "/mods/PLAYER/grug_expeditions/registrar.lua")
local R = M.registrar

-- ---- A. The socket ------------------------------------------------------------
for _, key in ipairs(capitals) do
	local roles = {}
	for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do roles[socket.id] = socket.role end
	check(roles["miners_guild/miners_guild_clerk"] == "expedition_registrar", "A the role in " .. key)
	check(roles["miners_guild/miners_guild_sorter"] == "idle", "A only the clerk in " .. key)
end
check(assigned[1] == "expedition_registrar" and #assigned == 1, "A one resolver")
check(resolved(nil, {race_id = "orc"}) == "grug_mobs:villager_orc", "A the capital's villager")
check(not pcall(grug_core.assign_service_socket, "highcourt", "miners_guild/miners_guild_clerk",
	"expedition_registrar"), "A the socket is taken once")

-- ---- The players --------------------------------------------------------------
local function player(name, level, faction)
	levels[name] = level
	local row = {name = name, faction = faction or "accord", hp = 20,
		pos = {x = 0, y = 0, z = 0},
		is_player = function() return true end,
		is_valid = function() return true end,
		get_player_name = function(self) return self.name end,
		get_meta = function() return {set_string = function() end} end, -- the saved capital
		get_hp = function(self) return self.hp end,
		get_pos = function(self) return self.pos end,
		hud_add = function(_, def) huds[#huds + 1] = def; return #huds end,
		hud_remove = function(_, id) huds[id] = false end,
	}
	online[name] = row
	return row
end
local function npc(capital)
	return {_grug_socket_role = "expedition_registrar", _grug_start = capital or "highcourt",
		object = {get_pos = function() return {x = 1, y = 0, z = 1} end}}
end
local function press(who, fields)
	for _, fn in ipairs(receivers) do fn(who, R.FORMNAME, fields) end
	return shown[who.name] and shown[who.name].spec
end
local function open(who, capital)
	shown[who.name] = nil
	local ok = M.open_registrar(who, npc(capital))
	return ok, shown[who.name] and shown[who.name].spec
end
local function party(leader, ...)
	local view = {id = leader, leader = leader, members = {}}
	for _, name in ipairs({leader, ...}) do
		view.members[#view.members + 1] = {name = name, level = levels[name],
			online = online[name] ~= nil}
		parties[name] = view
	end
	return view
end
local function dropdown_items(spec, field)
	return spec:match("dropdown%[[^;]*;[^;]*;" .. (field or "level") .. ";(.-[^\\]);%d+;true%]")
end
local function dropdown_index(spec, field)
	return tonumber(spec:match("dropdown%[[^;]*;[^;]*;" .. field .. ";.-[^\\];(%d+);true%]"))
end

-- ---- D. The dialog ------------------------------------------------------------
-- Solo, level 19: the level 20 Expedition offers +0 and +1 only (entry level - 2).
local solo = player("Solo", 19)
local ok, spec = open(solo)
check(ok, "D opens for its faction")
has(spec, "Expedition Registrar", "D the title")
has(spec, "Test Vault", "D the list")
has(spec, "The Other\\, Deep Vault", "D a name is escaped")
has(spec, "Levels 20-29\\, up to 3 players", "D the row's levels and places")
local items = dropdown_items(spec)
check(items == "Level 20,Level 21", "D only the levels it may enter: " .. tostring(items))
check(dropdown_items(spec, "tier") == "T2 (20-29): Gold\\, Jade", "D one tier, its ore and gem: " ..
	tostring(dropdown_items(spec, "tier")))
has(spec, ";open;", "D a solo player may open it")
hasnt(spec, "WHO CAN ENTER", "D no rows without a party")
-- The other row: nothing on offer, can_create's own text, no button.
spec = press(solo, {expeditions_row_2 = "x"})
hasnt(spec, "level;", "D no dropdown without a level")
has(spec, "This level of the Expedition needs level 58.", "D can_create's text")
hasnt(spec, ";open;", "D no button then")
spec = press(solo, {expeditions_row_1 = "x"})
-- A dropdown change is kept, a forged index is not, a repeat sends nothing.
spec = press(solo, {level = "2"})
has(spec, ";2;true]", "D the choice is kept")
shown.Solo = nil
press(solo, {level = "2"})
check(shown.Solo == nil, "D the same value sends nothing")
press(solo, {level = "9"})
check(shown.Solo == nil, "D an index the window did not show is ignored")

-- Two steps over a wide range (Round 71 RANGE): a tier, then a level inside it.
do
	local sixty = player("Sixty", 60)
	open(sixty)
	local wide = press(sixty, {expeditions_row_3 = "x"})
	has(wide, "Levels 20-69\\, up to 3 players", "D the wide row")
	check(dropdown_items(wide, "tier") == "T2 (20-29): Gold\\, Jade,T3 (30-39): Silver\\, Garnet," ..
		"T4 (40-49): Emberglass\\, Sapphire,T5 (50-59): Abyssal Crystal\\, Ruby," ..
		"T6 (60-69): Abyssal Crystal\\, Diamond", "D every tier at 60: " .. tostring(dropdown_items(wide, "tier")))
	check(dropdown_index(wide, "tier") == 5 and dropdown_items(wide) ==
		"Level 60,Level 61,Level 62,Level 63,Level 64,Level 65,Level 66,Level 67,Level 68,Level 69",
		"D the own level's tier first, all ten of T6")
	check(dropdown_index(wide, "level") == 1, "D at the own level")
	-- A new tier shows its levels and takes its first; the level field still names the old list.
	wide = press(sixty, {tier = "4", level = "1"})
	check(dropdown_index(wide, "tier") == 4 and dropdown_index(wide, "level") == 1, "D T5 at its first")
	check(dropdown_items(wide):match("^Level 50,.*,Level 59$") ~= nil, "D T5's ten levels")
	wide = press(sixty, {tier = "4", level = "10"})
	check(dropdown_index(wide, "level") == 10, "D a level inside the tier")
	shown.Sixty = nil
	press(sixty, {tier = "9", level = "10"})
	check(shown.Sixty == nil, "D a tier the window did not show is ignored")
	wide = press(sixty, {tier = "5", level = "3"})
	check(dropdown_index(wide, "tier") == 5 and dropdown_index(wide, "level") == 1,
		"D a tier change ignores the stale level")
	press(sixty, {tier = "4", level = "1"})
	press(sixty, {tier = "4", level = "10"})
	local made = M.create(sixty, "wide", R.sessions.Sixty.bonus)
	check(made and made.level == 59, "D the chosen level is what opens")
	table.remove(queue) -- the fake preparation keeps a cancelled run
	M.end_run(made, "released")
	-- Only tiers with a level on offer: 29 creates up to 31.
	local late = player("Late", 29)
	open(late)
	wide = press(late, {expeditions_row_3 = "x"})
	check(dropdown_items(wide, "tier") == "T2 (20-29): Gold\\, Jade,T3 (30-39): Silver\\, Garnet",
		"D two tiers at 29: " .. tostring(dropdown_items(wide, "tier")))
	check(dropdown_index(wide, "tier") == 1 and dropdown_index(wide, "level") == 10, "D at 29 itself")
	wide = press(late, {tier = "2", level = "10"})
	check(dropdown_items(wide) == "Level 30,Level 31", "D T3 only to 31")
	online.Sixty, online.Late = nil, nil
	R.sessions.Sixty, R.sessions.Late = nil, nil
end

-- A leader sees every member and may go on regardless.
local lead, low, far = player("Lead", 20), player("Low", 19), player("Far", 25)
levels.Gone = 30
party("Lead", "Low", "Far", "Gone")
_, spec = open(lead)
check(dropdown_items(spec) == "Level 20,Level 21,Level 22", "D the leader's own levels")
has(spec, "WHO CAN ENTER", "D the rows")
has(spec, "Low", "D a member's row")
has(spec, "Can enter", "D an eligible row")
has(spec, "(offline)", "D an offline member")
hasnt(spec, "Not everyone", "D no warning at +0")
spec = press(lead, {level = "3"})
has(spec, "Needs level 20.", "D the row says why")
has(spec, "Not everyone in your party can enter", "D the warning")
has(spec, ";open;", "D the warning stops nobody")
-- A member cannot.
_, spec = open(low)
hasnt(spec, ";open;", "D no button for a member")
has(spec, "Only your party leader can open an Expedition.", "D can_create's text for a member")
press(low, {open = "x"})
check(M.run_of(low) == nil, "D a forged click creates nothing")
has(shown.Low.spec, "Only your party leader", "D ...and shows the refusal")

-- ---- N. The notices -----------------------------------------------------------
feed, chat = {}, {}
spec = press(lead, {open = "x"})
local run = M.run_of(lead)
check(run and run.level == 22 and run.bonus == 2, "N the chosen level is created")
check(#feed == 3, "N the online members are told, got " .. #feed)
check(feed[1].text == "Your Expedition is being prepared...", "N the text: " .. feed[1].text)
check(feed[1].key == "expedition", "N one line per player")
has(spec, "Your Expedition is being prepared...", "D the window says so")
hasnt(spec, ";enter;", "D nobody enters before it is ready")
has(spec, "Level 22\\, 0 of 3 places taken", "D the run's line")

-- A second party waits behind: the queue shows, in the feed and the window.
local second = player("Second", 25)
parties.Second = nil
feed = {}
open(second)
spec = press(second, {open = "x"})
check(#feed == 1 and feed[1].text == "Your Expedition is being prepared... 1 ahead in the queue.",
	"N the queue: " .. tostring(feed[1] and feed[1].text))
has(spec, "1 ahead in the queue", "D the window's queue")

-- Ready: the owner's online members, the window moves on, the one behind moves up.
feed = {}
open(lead)
table.remove(queue, 1).finish(true)
check(run.state == "ready", "N ready")
local told = {}
for _, row in ipairs(feed) do told[row.name] = row.text end
check(told.Lead == "Your Expedition is ready: Test Vault, level 22." and told.Low and told.Far,
	"N the ready notice")
check(told.Second == nil and told.Solo == nil, "N nobody else")
has(shown.Lead.spec, ";enter;", "D Enter appears by itself")
hasnt(shown.Second.spec, "ahead in the queue", "D the queue moved up")
check(#chat == 0, "N never chat")

-- ---- D. Enter -----------------------------------------------------------------
-- Level 22 needs 20: Low is refused at Enter with the reason, the row said it.
_, spec = open(low)
has(spec, ";enter;", "D a member with a run sees Enter")
has(spec, "Needs level 20.", "D ...and its row")
spec = press(low, {enter = "x"})
has(spec, "This Expedition needs level 20.", "D the refusal at Enter")
check(trip == nil, "D no trip")
-- Combat is can_enter's too.
open(far)
in_combat.Far = true
spec = press(far, {enter = "x"})
has(spec, "Cannot travel in combat.", "D can_enter's text")
in_combat.Far = nil
-- Entered through the registrar's capital.
closed.Far = nil
press(far, {enter = "x"})
check(trip ~= nil and closed.Far and R.sessions.Far == nil, "D the trip starts and the window goes")
-- The capital of the registrar: run.origins is written on arrival.
local arrival_at = {x = 1, y = 1, z = 1}
grug_home.safe_arrival = function() return arrival_at end
trip.arrival()
check(run.origins.Far == "highcourt", "D the way back leads to this capital")

-- Another registrar, another faction, far away, dead.
local enemy = player("Enemy", 30, "throng")
check(open(enemy) == false, "D the other faction gets no window")
check(open(enemy, "gor_drazhak") == true, "D its own does")
solo.pos = {x = 50, y = 0, z = 0}
check(open(solo) == false, "D out of reach")
solo.pos = {x = 0, y = 0, z = 0}
solo.hp = 0
check(open(solo) == false, "D a dead player")
solo.hp = 20
open(solo)
solo.pos = {x = 50, y = 0, z = 0}
closed.Solo = nil
press(solo, {level = "1"})
check(closed.Solo and R.sessions.Solo == nil, "D walking away closes it")
solo.pos = {x = 0, y = 0, z = 0}

-- The end of a run: who it touches, and the window goes back.
feed = {}
open(lead)
M.end_run(run, "released")
told = {}
for _, row in ipairs(feed) do told[row.name] = row.text end
check(told.Lead == "Your Expedition has ended." and told.Low and told.Far, "N the end")
check(told.Solo == nil, "N not a stranger")
hasnt(shown.Lead.spec, ";enter;", "D the window goes back to the list")
has(shown.Lead.spec, "EXPEDITIONS", "D ...with the list")
feed = {}
M.end_run(M.run_of(second), "failed")
check(feed[1].text == "Your Expedition could not be prepared. Try again soon.", "N a failed run")
check(#chat == 0, "N never chat at the end either")

-- Each reason a player meets, in its own words.
do
	local ana, bea = player("Ana", 20), player("Bea", 20)
	local function ready(who)
		local new_run = assert(M.create(who, "test_vault", 0))
		queue[#queue].finish(true)
		queue[#queue] = nil
		feed = {}
		return new_run
	end
	local function step_in(who, into)
		into.entered[who.name] = true
		who.pos = into.places.arrival
		teleported(who)
		check(M.run_inside(who) == into, "N " .. who.name .. " stands inside")
		feed = {}
	end
	local function line(key)
		for _, row in ipairs(feed) do
			if row.key == key then return row.name .. ": " .. row.text end
		end
	end

	-- Ten minutes with nobody inside: the clock's own call.
	local empty = ready(ana)
	afters[#afters][2]()
	check(empty.state == "ended" and #feed == 1, "N the empty run, one line")
	check(line("expedition") == "Ana: Your Expedition has ended: nobody was inside for 10 minutes.",
		"N empty: " .. tostring(line("expedition")))

	-- The solo owner, inside, joins a foreign party.
	local joined = ready(ana)
	step_in(ana, joined)
	parties.Ana = {id = "foreign", leader = "Bea", members = {}}
	party_change("Ana", "membership")
	parties.Ana = nil
	check(joined.state == "ended" and #feed == 2, "N joined a party, two lines")
	check(line("expedition") == "Ana: You joined a party, so your Expedition has ended.",
		"N joined_party: " .. tostring(line("expedition")))
	check(line("expedition_left") == "Ana: You are on your way back.",
		"N ended, on leaving: " .. tostring(line("expedition_left")))

	-- A member inside leaves the party; the run goes on and only they hear of it.
	party("Ana", "Bea")
	local shared = ready(ana)
	step_in(bea, shared)
	step_in(ana, shared)
	parties.Bea = nil
	member_left("Bea", "Ana", nil)
	check(shared.state ~= "ended" and #feed == 1, "N the leaver alone is told")
	check(line("expedition_left") == "Bea: You are no longer in the party, so you left its Expedition.",
		"N expelled: " .. tostring(line("expedition_left")))

	-- A player's own way out says nothing.
	feed = {}
	ana.pos = {x = 0, y = 0, z = 0}
	teleported(ana)
	check(M.run_inside(ana) == nil and #feed == 0, "N the waystone needs no line")
	parties.Ana = nil
	M.end_run(shared, "released")
	check(#chat == 0, "N none of it in chat")
end

-- With nothing on offer the window stands.
M.list = function() return {} end
_, spec = open(solo)
has(spec, "no Expedition to offer", "D an empty list")
hasnt(spec, "dropdown", "D ...and nothing to choose")
M.list = function() return LIST end

-- The arrival's black screen goes by itself.
local entered = M.create(solo, "test_vault", 0)
huds, afters = {}, {}
enter_hook(entered, "Solo")
check(huds[1] and huds[1].text == "[fill:1x1:#000000" and huds[1].scale.x == -100, "D the black screen")
check(afters[1] and afters[1][1] == 1, "D ...for a second")
afters[1][2]()
check(huds[1] == false, "D ...and gone")

-- ---- I. The invitation warning ------------------------------------------------
-- Real parts of grug_parties' ui.lua are tested by tools/r67_social; here the rule.
_G.sfinv = {register_page = function() end, contexts = {}, handle_scroll = function() end}
grug_parties.register_on_roster_change = function() end
grug_parties.register_on_change = function() end
dofile(repo .. "/mods/PLAYER/grug_parties/ui.lua")
local warning = grug_parties.invitation_warning
check(warning("Solo") == "Accepting ends your Expedition.", "I a solo owner")
check(warning("Stranger") == nil, "I nobody else")
parties.Solo = party("Solo", "Friend")
check(warning("Solo") == nil, "I not when the party owns nothing")
parties.Solo, parties.Friend = nil, nil
M.end_run(entered, "released")
check(warning("Solo") == nil, "I not after the run")

-- ---- L. Off the map -----------------------------------------------------------
local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local view = {min_x = -4050, max_x = 4050, min_z = -3600, max_z = 3600}
local inside = {x = 100, z = 200}
check(atlas.on_map(view, inside) == inside, "L a position on the map stays")
local edge = atlas.on_map(view, {x = 8100, z = -1500})
check(atlas.contains(view, edge) and edge.x == 3850 and edge.z == -1500, "L east of the map")
check(atlas.world_to_screen(view, edge, 0, 0, 900, 800) ~= nil, "L ...drawn")
check(atlas.world_to_screen(view, {x = 8100, z = -1500}, 0, 0, 900, 800) == nil, "L other markers stay off")
local corner = atlas.on_map(view, {x = 11000, z = 5000})
check(corner.x == 3850 and corner.z == 3400, "L past a corner")

local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
local tiles = {{name = "tile.png", x = 0, y = 0, w = 600, h = 600},
	{name = "tile2.png", x = 600, y = 0, w = 600, h = 600}}
local mini = V.new({quality = "normal", width = 1200, height = 1067, tiles = tiles}, view)
local box = {size = 270, center_x = 1770, center_y = 150, hud = 1, gui = 1, width = 1920, height = 1080}
local frame = V.frame(mini, box)
local x, z = 8200, -1500
local cx, cy = V.cell(mini, x, z)
local ox, oy = V.origin(mini, cx, cy)
local texture = V.texture(mini, ox, oy, "mask.png")
check(texture == ("[combine:%dx%d^[mask:mask.png"):format(mini.combined, mini.combined),
	"L off the map no tile: the sea disc shows, got " .. texture)
local px, py = V.base_pixel(mini, x, z)
local mx, my = V.map_corner(mini, frame, cx, cy, px, py)
local sx, sy, distance = V.place(mini, frame, ox, oy, mx, my, x + 12, z)
check(distance < frame.hole, "L a member in the box is inside the hole")
check(sx > frame.arrow_x and math.abs(sy - frame.arrow_y) < 2, "L ...to the east")
sx, sy, distance = V.place(mini, frame, ox, oy, mx, my, 100, -1500)
check(distance > frame.hole, "L a member on the map is a rim arrow")
local rx = V.rim(frame, sx - frame.center_x, sy - frame.center_y)
check(rx < frame.center_x, "L ...west of the player")

print("R71 UI PORTABLE PASS checks=" .. checks)
