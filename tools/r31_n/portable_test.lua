-- Round 31 Lane N portable test (LuaJIT): the faction filter for NPC
-- services and map markers (pvp-plan.md ruling 13, round31-plan.md lane N).
--
--   luajit tools/r31_n/portable_test.lua [repo]
--
-- Loads the REAL grug_factions/service.lua, grug_mobs/start_villagers.lua,
-- grug_traders/vendors.lua and trade.lua, grug_quests registry/state/labels/npc and
-- grug_map atlas/providers on a fake engine. Checks:
--   S  the service refusal table: every villager service role (innkeeper,
--      Riding Trainer, Shipwright, Housing Steward, profession trainer), the
--      quest giver, the three vendor kinds and the race vendor's own rule,
--      for an own-faction and an enemy player; one refusal line, at most one
--      per player every two seconds; a plain resident still answers anyone;
--      a factionless NPC serves everyone;
--   G  guards, royal guards and kings give no quests: their entity files
--      define no right-click, and a quest NPC may stand only on a quest
--      socket;
--   F  quest NPC factions: settlement race, or a new giver's own race (the
--      spy); a quest whose turn-in NPC is of another faction is refused at
--      load;
--   M  map markers: each player gets the own faction's quest givers,
--      services and innkeepers; no king or dragon markers (baked into the
--      base image for everyone since Round 44); a factionless viewer no NPC
--      markers; markers carry the NPC's faction;
--      in one zone both factions keep their own markers (the spy case); the
--      quest markers are asked once per build (one marker_states call) and
--      an enemy giver never shows even with a state in marker_states;
--   T  the NPC tags' quest marker: an enemy observer gets none.
-- Prints "R31 N PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy
local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

-- ---------------------------------------------------------------------------
-- Fake engine
-- ---------------------------------------------------------------------------
local chat, shown, opened = {}, {}, {}
local us, gametime = 1000000, 100
local loaded, players = {}, {}
core = {
	registered_entities = {["grug_mobs:king_human"] = {description = "King"},
		["grug_mobs:king_orc"] = {description = "Warchief"}},
	registered_items = {},
	get_us_time = function() return us end,
	get_gametime = function() return gametime end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
	show_formspec = function(name, formname) shown[#shown + 1] = name .. " " .. formname end,
	close_formspec = function() end,
	formspec_escape = function(text) return text end,
	colorize = function(color, text) return text end,
	get_player_by_name = function(name) return players[name] end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name)
		if name == "grug_mapgen" then return repo .. "/mods/MAPGEN/grug_mapgen" end
		return repo .. "/mods/PLAYER/" .. name
	end,
	serialize = function(value) return value end,
	deserialize = function() return nil end,
	log = function() end,
	add_entity = function() return nil end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
end})
vector = {distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end}

local function new_player(name, faction, race)
	local meta = {}
	local p = {name = name, faction = faction, race = race, pos = {x = 0, y = 10, z = 0}}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return 20 end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return 0 end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function p:get_inventory()
		return {get_list = function() return {} end, get_stack = function() return nil end}
	end
	players[name] = p
	return p
end

-- ---------------------------------------------------------------------------
-- The game around the files under test
-- ---------------------------------------------------------------------------
grug_factions = {
	get_faction = function(player) return player.faction end,
	display_name = function(id)
		return id and ({accord = "The Accord", throng = "The Throng"})[id] or nil
	end,
}
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
local RACES = {human = {name = "Human", faction = "accord"}, dwarf = {name = "Dwarf", faction = "accord"},
	elf = {name = "Elf", faction = "accord"}, orc = {name = "Orc", faction = "throng"},
	troll = {name = "Troll", faction = "throng"}, undead = {name = "Undead", faction = "throng"}}
grug_classes = {registered_races = RACES, get_race = function(player) return player.race end}

-- Settlements: an Accord start, a Throng capital, and two posts in one zone,
-- one per faction (the same-zone case).
local SETTLEMENTS = {
	{key = "dawnmere", race_id = "human", anchor = {x = 0, y = 10, z = -2500}},
	{key = "gor_drazhak", race_id = "orc", anchor = {x = 0, y = 10, z = 2500}},
	{key = "watch_post", race_id = "human", anchor = {x = 100, y = 10, z = 0}},
	{key = "ramp_post", race_id = "orc", anchor = {x = 160, y = 10, z = 0}},
}
local function at(settlement, dx, role, extra)
	local row = {id = role .. dx, role = role, pos = {x = settlement.anchor.x + dx, y = 10,
		z = settlement.anchor.z}}
	for k, v in pairs(extra or {}) do row[k] = v end
	return row
end
local SOCKETS = {
	dawnmere = {at(SETTLEMENTS[1], 1, "quest"), at(SETTLEMENTS[1], 2, "trainer", {profession = "tailor"}),
		at(SETTLEMENTS[1], 3, "housing_manager"), at(SETTLEMENTS[1], 4, "riding_trainer"),
		at(SETTLEMENTS[1], 5, "king"), at(SETTLEMENTS[1], 6, "guard_post")},
	gor_drazhak = {at(SETTLEMENTS[2], 1, "quest"), at(SETTLEMENTS[2], 2, "trainer", {profession = "tailor"}),
		at(SETTLEMENTS[2], 5, "king")},
	watch_post = {at(SETTLEMENTS[3], 1, "quest"), at(SETTLEMENTS[3], 2, "quest")},
	ramp_post = {at(SETTLEMENTS[4], 1, "quest")},
}
grug_core = {
	faction_ids = {"accord", "throng"},
	factions = {accord = {name = "Accord"}, throng = {name = "Throng"}},
	start_identities = function()
		local list = {}
		for _, race in ipairs({"human", "dwarf", "elf", "orc", "troll", "undead"}) do
			list[#list + 1] = {race_id = race, faction_id = RACES[race].faction}
		end
		return list
	end,
	settlement_socket_settlements = function() return deep_copy(SETTLEMENTS) end,
	settlement_sockets_at = function(key) return deep_copy(SOCKETS[key] or {}) end,
	capital_anchor = function() return {x = 9000, y = 0, z = 9000} end,
	register_tag_visibility = function(fn) grug_core.tag_visibility = fn end,
	feed_item = function() end,
	feed = function() end,
	-- vendors.lua's capital services (Round 33) take over gate residents.
	assign_service_socket = function() end,
}
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")

-- grug_mobs: what start_villagers.lua and vendors.lua call at load.
local mob_defs = {}
mobs = {register_mob = function(_, name, def) mob_defs[name] = def end}
grug_mobs = {noncombatant = function(def) return def end, face_yaw = function() end,
	start_npc_claim = function() end, set_plain_tag = function() end,
	register_start_socket_role = function() end, register_start_npc_restyle = function() end,
	register_on_eligible_kill = function() end, register_participant_drop_hook = function() end,
	dragon_map_markers = function()
		return {{id = "dragon:ice", name = "Ice Dragon", pos = {x = -3000, y = 50, z = 0}},
			{id = "dragon:storm", name = "Storm Dragon", pos = {x = 3000, y = 50, z = 0}}}
	end}
-- The services a villager hands the click to (each records its call).
local function opener(label) return function() opened[#opened + 1] = label end end
grug_home = {open_innkeeper = opener("innkeeper")}
grug_mounts = {open_trainer = opener("mounts")}
grug_housing = {open_manager = opener("steward")}
grug_jobs = {open_trainer = opener("trainer"), PROFESSIONS = {tailor = {name = "Tailoring"}},
	trainer_teaches = function(p) return p ~= "cooking" end} -- Round 45 (lane ST)
dofile(repo .. "/mods/ENTITIES/grug_mobs/start_villagers.lua")

grug_traders = {PROFESSION_BRACKETS = {}}
dofile(repo .. "/mods/ENTITIES/grug_traders/vendors.lua")
dofile(repo .. "/mods/ENTITIES/grug_traders/trade.lua")

grug_inventory = {BAG_COUNT = 0}
grug_xp = {get_level = function() return 10 end, quest_reward = function() return 10 end,
	add_xp = function() end, register_on_level_change = function() end}
grug_money = {format = function(c) return c .. "c" end}
grug_zones = {id_at = function() return "z" end}
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "npc"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests
Q.register_npc("elder", {settlement = "dawnmere", socket = "quest1", title = "Elian Reed"})
Q.register_npc("warlord", {settlement = "gor_drazhak", socket = "quest1", title = "Gara Stonevoice"})
Q.register_npc("watch", {settlement = "watch_post", socket = "quest1", title = "Jon Vale"})
-- The spy: a Throng giver standing in an Accord post (a new giver's race).
Q.register_npc("spy", {settlement = "watch_post", socket = "quest2", title = "Kesh Shade", race = "orc"})
Q.register_npc("ramp", {settlement = "ramp_post", socket = "quest1", title = "Brakka Jarward"})
local function quest(id, npc, turnin)
	Q.register_quest(id, {title = id, description = id, npc = npc, turnin_npc = turnin,
		rewards = {weight = 1}, objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, count = 1}}})
end
core.registered_entities["grug_mobs:boar"] = {description = "Boar"}
for _, npc in ipairs({"elder", "warlord", "watch", "spy", "ramp"}) do quest(npc .. "_q", npc) end
Q.resolve_npc_factions()
Q.validate_registry()

grug_home.get = function() return nil end
grug_home.locations = function()
	return {{id = "dawnmere", label = "Dawnmere", faction = "accord", pos = {x = 7, y = 10, z = -2500}},
		{id = "sunscar", label = "Sunscar", faction = "throng", pos = {x = 7, y = 10, z = 2400}}}
end
grug_home.known_waypoints = function() return {} end
grug_parties = {view = function() return nil end}
grug_map = {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")}
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
for _, fn in ipairs(loaded) do fn() end

local ann = new_player("ann", "accord", "human")   -- Accord, human
local dag = new_player("dag", "accord", "dwarf")   -- Accord, dwarf
local org = new_player("org", "throng", "orc")     -- Throng, orc
local new = new_player("new", nil, nil)            -- in character creation

-- ---------------------------------------------------------------------------
-- S: the service refusal table
-- ---------------------------------------------------------------------------
local function said() return chat[#chat] end
local function click(def, fields, player)
	local self = {object = {get_pos = function() return {x = 0, y = 10, z = 0} end}}
	for k, v in pairs(fields) do self[k] = v end
	local before_chat, before_open = #chat, #opened
	us = us + 3000000 -- past the refusal's rate limit
	gametime = gametime + 3 -- past the residents' answer cooldown
	def.on_rightclick(self, player)
	return opened[before_open + 1], #chat > before_chat and said() or nil
end
local HUMAN = mob_defs["grug_mobs:villager_human"]
local ORC = mob_defs["grug_mobs:villager_orc"]
check(HUMAN and ORC and mob_defs["grug_mobs:elder_human"], "S villager and elder entities registered")
local SERVICES = {
	{"innkeeper", {_grug_socket_role = "innkeeper", _grug_npc_tag = "Innkeeper"}, "innkeeper"},
	{"Riding Trainer", {_grug_socket_role = "riding_trainer", _grug_npc_tag = "Riding Trainer"}, "mounts"},
	{"Shipwright", {_grug_socket_role = "shipwright", _grug_npc_tag = "Shipwright"}, "mounts"},
	{"Housing Steward", {_grug_socket_role = "housing_manager", _grug_npc_tag = "Housing Steward"}, "steward"},
	{"profession trainer", {_grug_socket_role = "trainer", _grug_profession = "tailor",
		_grug_npc_tag = "Tailoring Trainer"}, "trainer"},
}
for _, row in ipairs(SERVICES) do
	local label, fields, expected = row[1], row[2], row[3]
	local service, line = click(HUMAN, fields, ann)
	check(service == expected and line == nil, "S " .. label .. ": serves its own faction")
	service, line = click(HUMAN, fields, org)
	eq(service, nil, "S " .. label .. ": the enemy gets no service")
	eq(line, "org: <" .. fields._grug_npc_tag .. "> I serve only The Accord.",
		"S " .. label .. ": one refusal line")
	service, line = click(ORC, fields, ann)
	eq(line, "ann: <" .. fields._grug_npc_tag .. "> I serve only The Throng.",
		"S " .. label .. " (Throng): the refusal names its faction")
	service = click(HUMAN, fields, new)
	eq(service, nil, "S " .. label .. ": a player without a faction is not served")
end
do -- A plain resident is no service: it still answers anyone.
	local service, line = click(HUMAN, {_grug_npc_tag = "Farmer", _grug_npc_race = "human"}, org)
	check(service == nil and line and line:find("<Farmer>", 1, true) and
		not line:find("I serve only", 1, true), "S a plain resident answers the enemy")
end
do -- Rate limit: a held button says the line once per two seconds.
	local self = {_grug_socket_role = "innkeeper", _grug_npc_tag = "Innkeeper"}
	us = us + 3000000
	local before = #chat
	for _ = 1, 5 do HUMAN.on_rightclick(self, org) end
	eq(#chat - before, 1, "S five quick clicks say the refusal once")
	us = us + 2100000
	HUMAN.on_rightclick(self, org)
	eq(#chat - before, 2, "S ...and again after two seconds")
end
check(grug_factions.serves(nil, org) and grug_factions.serves(nil, new),
	"S an NPC without a faction serves everyone")

-- The quest giver (the elder's right-click goes through grug_quests.open_npc).
local ELDER = mob_defs["grug_mobs:elder_human"]
local function elder(id_socket, settlement)
	return {_grug_start = settlement, _grug_socket = id_socket, _grug_npc_tag = "Elder",
		object = {is_valid = function() return true end,
			get_pos = function() return {x = 0, y = 10, z = 0} end}}
end
do
	local before = #shown
	us = us + 3000000
	ELDER.on_rightclick(elder("quest1", "dawnmere"), ann)
	eq(#shown - before, 1, "S quest giver: own faction gets the dialogue")
	before = #shown
	ELDER.on_rightclick(elder("quest1", "dawnmere"), org)
	eq(#shown - before, 0, "S quest giver: the enemy gets no dialogue")
	eq(said(), "org: <Elian Reed> I serve only The Accord.", "S quest giver: the refusal line")
	us = us + 3000000
	ELDER.on_rightclick(elder("quest2", "watch_post"), ann)
	eq(said(), "ann: <Kesh Shade> I serve only The Throng.", "S the spy refuses the Accord in its post")
	before = #shown
	ELDER.on_rightclick(elder("quest2", "watch_post"), org)
	eq(#shown - before, 1, "S the spy serves the Throng")
end

-- Vendors: a Quartermaster, a race vendor and a profession vendor.
local V = grug_traders.vendors
local function trade(entity, player, settlement)
	local vendor = V[entity]
	return grug_traders.can_trade(player, vendor, grug_traders.vendor_faction(vendor, settlement))
end
check(trade("grug_traders:vendor_general_accord", ann), "S Quartermaster serves its faction")
local ok, message = trade("grug_traders:vendor_general_accord", org)
check(not ok and message == "<Accord Quartermaster> I serve only The Accord.",
	"S Quartermaster refuses the enemy with the line: " .. tostring(message))
ok, message = trade("grug_traders:vendor_race_orc", ann)
check(not ok and message:find("I serve only The Throng.", 1, true),
	"S race vendor refuses the enemy with the line: " .. tostring(message))
ok, message = trade("grug_traders:vendor_race_human", dag)
check(not ok and message:find("trades only with Human", 1, true),
	"S race vendor keeps its race rule for its own faction: " .. tostring(message))
check(trade("grug_traders:vendor_race_human", ann), "S race vendor serves its race")
check(trade("grug_traders:vendor_butcher", ann, "dawnmere") and
	trade("grug_traders:vendor_butcher", org, "gor_drazhak"),
	"S profession vendor serves the faction of its settlement")
ok, message = trade("grug_traders:vendor_butcher", org, "dawnmere")
check(not ok and message == "<Butcher> I serve only The Accord.",
	"S profession vendor refuses the enemy: " .. tostring(message))
check(trade("grug_traders:vendor_butcher", org, nil),
	"S a profession vendor outside a settlement has no faction and serves everyone")
do -- The vendor's right-click: the shared line, once per two seconds.
	local def = mob_defs["grug_traders:vendor_general_accord"]
	local self = {object = {get_pos = function() return {x = 0, y = 10, z = 0} end}}
	us = us + 3000000
	local before = #chat
	for _ = 1, 5 do def.on_rightclick(self, org) end
	eq(#chat - before, 1, "S five quick clicks at an enemy vendor say the refusal once")
	eq(said(), "org: <Accord Quartermaster> I serve only The Accord.", "S the vendor's line")
	us = us + 2100000
	def.on_rightclick(self, org)
	eq(#chat - before, 2, "S ...and again after two seconds")
end

-- ---------------------------------------------------------------------------
-- G: guards, royal guards and kings give no quests
-- ---------------------------------------------------------------------------
for _, path in ipairs({"mods/ENTITIES/grug_mobs/guard.lua", "mods/ENTITIES/grug_mobs/bosses.lua",
		"mods/ENTITIES/grug_mobs/land_guard.lua"}) do
	check(not read(path):find("on_rightclick", 1, true), "G no right-click in " .. path)
end
do
	Q.register_npc("guard_giver", {settlement = "dawnmere", socket = "guard_post6", title = "Guard"})
	Q.resolve_npc_factions()
	local ok_guard = pcall(Q.validate_registry)
	check(not ok_guard, "G a quest NPC on a guard socket is refused at load")
	Q.registered_npcs.guard_giver = nil
	Q.npc_by_socket["dawnmere/guard_post6"] = nil
end

-- ---------------------------------------------------------------------------
-- F: quest NPC factions
-- ---------------------------------------------------------------------------
eq(Q.registered_npcs.elder.faction, "accord", "F settlement race decides (Accord)")
eq(Q.registered_npcs.warlord.faction, "throng", "F settlement race decides (Throng)")
eq(Q.registered_npcs.spy.faction, "throng", "F a new giver's own race decides")
do
	quest("cross", "elder", "warlord")
	local ok_cross, err = pcall(Q.validate_registry)
	check(not ok_cross and tostring(err):find("another faction", 1, true),
		"F a turn-in NPC of the other faction is refused: " .. tostring(err))
	Q.registered_quests.cross = nil
	Q.quests_by_npc.elder.cross, Q.quests_by_npc.warlord.cross = nil, nil
	check(pcall(Q.validate_registry), "F the registry is valid again")
end

-- ---------------------------------------------------------------------------
-- M: map markers
-- ---------------------------------------------------------------------------
local atlas = grug_map.atlas
local function markers(player, only)
	local by_id, kinds = {}, {}
	for _, marker in ipairs(atlas.collect_markers(player, only)) do
		by_id[marker.id] = marker
		kinds[marker.kind] = (kinds[marker.kind] or 0) + 1
	end
	return by_id, kinds
end
local calls = 0
local real_states = Q.marker_states
Q.marker_states = function(player)
	calls = calls + 1
	return real_states(player)
end
for _, case in ipairs({{ann, "accord", "throng"}, {org, "throng", "accord"}}) do
	local player, own, enemy = case[1], case[2], case[3]
	calls = 0
	local m, kinds = markers(player)
	eq(calls, 1, "M " .. own .. ": one marker_states call per build")
	local own_giver = own == "accord" and "quest:elder" or "quest:warlord"
	local enemy_giver = own == "accord" and "quest:warlord" or "quest:elder"
	check(m[own_giver] and m[own_giver].faction == own, "M " .. own .. ": own quest giver with its faction")
	check(m[enemy_giver] == nil, "M " .. own .. ": no enemy quest giver")
	check(not m["service:dawnmere/king5"] and not m["service:gor_drazhak/king5"] and
		not kinds.boss, "M " .. own .. ": no king markers (baked, Round 44)")
	check(not m["service:dragon:ice"] and not m["service:dragon:storm"],
		"M " .. own .. ": no dragon markers (baked, Round 44)")
	local trainer = own == "accord" and "service:dawnmere/trainer2" or "service:gor_drazhak/trainer2"
	local foreign = own == "accord" and "service:gor_drazhak/trainer2" or "service:dawnmere/trainer2"
	check(m[trainer] and m[trainer].faction == own and m[foreign] == nil,
		"M " .. own .. ": own trainers only")
	eq(kinds.steward, own == "accord" and 1 or nil, "M " .. own .. ": steward only for its faction")
	eq(kinds.innkeeper, 1, "M " .. own .. ": own innkeepers only")
	local inn = m["home:" .. (own == "accord" and "dawnmere" or "sunscar")]
	check(inn and inn.faction == own, "M " .. own .. ": the innkeeper carries its faction")
	-- The same zone: the Accord post and the Throng post with the spy.
	if own == "accord" then
		check(m["quest:watch"] and not m["quest:spy"] and not m["quest:ramp"],
			"M same zone: the Accord sees its post, not the spy or the Throng post")
	else
		check(m["quest:spy"] and m["quest:ramp"] and not m["quest:watch"],
			"M same zone: the Throng sees the spy and its post, not the Accord post")
	end
	-- The minimap's providers follow the same rule.
	local mini = markers(player, {quest = true, service = true, home = true, waypoint = true})
	check(mini[own_giver] and not mini[enemy_giver] and not mini[foreign],
		"M " .. own .. ": the minimap's set is filtered too")
	-- An enemy giver with a state in marker_states still shows nothing.
	local states = real_states(player)
	check(states[enemy_giver:sub(7)] ~= nil, "M " .. own .. ": marker_states knows the enemy giver")
end
do
	local m, kinds = markers(new)
	check(kinds.quest == nil and kinds.trainer == nil and kinds.innkeeper == nil and
		kinds.boss == nil and m["service:dawnmere/king5"] == nil,
		"M a factionless viewer sees no NPC markers")
end
Q.marker_states = real_states

-- ---------------------------------------------------------------------------
-- T: the quest marker over the NPC
-- ---------------------------------------------------------------------------
do
	local made = 0
	core.add_entity = function()
		made = made + 1
		local child = {observers = nil}
		function child:is_valid() return true end
		function child:set_attach() end
		function child:set_properties() end
		function child:set_observers(set) self.observers = set end
		function child:remove() end
		return child
	end
	local parent = {}
	local entity = elder("quest1", "gor_drazhak")
	function parent:get_luaentity() return entity end
	function parent:get_pos() return {x = 0, y = 10, z = 2500} end
	entity.object = {is_valid = function() return true end}
	grug_core.tag_visibility(parent, {ann = true}, false)
	eq(made, 0, "T an enemy observer alone gets no quest marker")
	grug_core.tag_visibility(parent, {ann = true, org = true}, false)
	eq(made, 1, "T the own faction's observer gets it")
end

if #failures == 0 then
	print("R31 N PORTABLE PASS checks=" .. checks)
else
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R31 N PORTABLE FAIL %d/%d"):format(#failures, checks))
end
