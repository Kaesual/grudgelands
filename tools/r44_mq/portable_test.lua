-- Round 44 lane MQ portable test: the map and quest window, extended by
-- Round 47 lane ML (the marker layers). Loads the REAL grug_keys/init.lua
-- and grug_map's atlas.lua, providers.lua, page.lua, window.lua (with
-- targets.lua, quest_box.lua, layers.lua, zone_labels.lua, bake.lua and
-- settlement_icons.lua) under a minimal `core` stub and checks:
--   K  the key helper: a callback per key on the rising edge only (not
--      while held, not on release, not on a player's first step), zoom and
--      aux1 apart, one control read per player per step; zoom_fov 72 on
--      joining;
--   S  the window size: FRACTION of max_formspec_size, the fixed fallback
--      without it, the floor; the layout inside the window (9:8 map, the
--      quest column at least 6.5 wide, scrollbars beside the map);
--   O  (Round 47 lane ML; Round 44's fixed overlay before) one marker layer
--      at a time (layers.lua): every layer draws its own markers and none
--      of another's; Quests the own givers by state (locked ones too),
--      Trainers the own trainers (two thirds size at 1x and 2x) and
--      services, Towns both factions' settlements and the own innkeepers,
--      home and waystones, Bosses the kings, the dragon once beside its
--      arena, the rift boss and the rare den with their levels, POIs and
--      PvP both factions' places, Zones a box and a two-line label per
--      zone, None only the arrows; every marker's tooltip, topmost first,
--      the party arrow with the member's name in every layer and mode;
--      quest mode: the targets with their objectives' lines and the
--      hand-in NPC, nothing of the layer, no button highlighted; the
--      buttons in the work package's order, the active one highlighted;
--   T  the quest target index (role -> regions, area -> regions, leaders)
--      and the targets: crosshairs (leaders, talk NPCs, use places) before
--      rings, at most five rings, the nearest the player, a kill objective
--      without an area only in the quest's zone, finished objectives and
--      item objectives without a mark; in the form rings under the
--      crosshair, sized by the region, tinted and semi-transparent;
--   R  the refresh rule: an event sends at once, a second one inside a
--      second is owed and goes out when the second is over (one trailing
--      send), a scrollbar event alone sends nothing, alone nothing is sent
--      without an event, in a party at most every 2 s (Round 47 ruling 8;
--      5 s before) and only when a
--      member moved, a replaced window gets nothing, a send that crossed a
--      close works again after the window's next event, a scrollbar move
--      holds every send for 0.5 s; the sends per minute
--      alone and in a party are printed (comparisons, not targets);
--   B  the pass budget: many windows in parties opened together get at most
--      two pass sends and eight party checks per pass, longest waiting
--      first, none starves;
--   Q  the quest boxes: the list with its count, Quest HUD, Track on HUD,
--      Abandon with its confirmation, the text (description unwrapped,
--      objectives, rewards), the ready line, the empty log; the Quests tab
--      is gone (TAB_ORDER, grug_quests/init.lua);
--   Z  zoom 1-2-4-8 with the view centre kept (once the player scrolled)
--      and scroll values clamped; the Map tab opens the window and goes
--      back to the homepage;
--   M  (0.45.1) the soft lock through the window's events: zoom from 1x
--      centres on the player, the player's scrolling breaks the lock, 1x
--      restores it; the map's scrollbar is focused (set before it) so the
--      inventory key closes the window; a click on the selected quest sends;
--   L  (Round 47) the layer buttons: one row at 1920x1080 and 2560x1440,
--      two at 1035x696 and 1280x720, as wide as the map, under its
--      scrollbar, the quest column at its Round 44 place, the map at
--      1035x696 at its size; a click picks a layer in one send, the active
--      one sends nothing, any layer button deselects the quest (list, text
--      box, Abandon), a quest leaving the log falls back to the layer, the
--      layer survives an opening but not leaving the game; the static rows
--      built once;
--   ZL (Round 47) zone_labels.lua: the band text, the text metrics from the
--      window information, the box and the label inside it, the placement
--      (poles of inaccessibility, nudged off names), the overlap count; the
--      start's placement and its one grid sampling;
--   I  (Round 47) the layer icons are the baked art's byte copies with a
--      LICENSE-media row, every row's texture ships, the world map's baked
--      layer has names and no icons, the minimap's the whole layer.
-- Usage (repo root): luajit tools/r44_mq/portable_test.lua [repo]
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
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. ("%q"):format(part) .. ")")
end
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) <= (eps or 1e-6) end
local function read(path)
	local file = io.open(repo .. "/" .. path, "rb")
	local text = file and file:read("*a") or ""
	if file then file:close() end
	return text
end
local function count(text, pattern)
	local n = 0
	for _ in text:gmatch(pattern) do n = n + 1 end
	return n
end

local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"))
end

-- ---------------------------------------------------------------------------
-- The engine stub
-- ---------------------------------------------------------------------------
local clock_us = 0
local steps, on_join, on_leave, on_loaded, on_fields, after_calls = {}, {}, {}, {}, {}, {}
local shown, shows = {}, {}
local window_info = {}
local players = {}
local function make_player(name, pos, faction)
	local p = {name = name, pos = pos, faction = faction, bits = 0, reads = 0, hp = 20,
		meta = {}, props = {}}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y or 10, z = self.pos.z} end
	function p:get_look_horizontal() return 0 end
	function p:get_hp() return self.hp end
	function p:get_player_control_bits() self.reads = self.reads + 1; return self.bits end
	function p:set_properties(props) for k, v in pairs(props) do self.props[k] = v end end
	function p:get_meta()
		local meta, store = {}, self.meta
		function meta:get_string(key) return store[key] or "" end
		function meta:set_string(key, value) store[key] = value ~= "" and value or nil end
		return meta
	end
	return p
end

rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	register_on_mods_loaded = function(fn) on_loaded[#on_loaded + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function(fn) on_join[#on_join + 1] = fn end,
	register_on_leaveplayer = function(fn) on_leave[#on_leave + 1] = fn end,
	register_on_dieplayer = function() end,
	register_on_player_receive_fields = function(fn) on_fields[#on_fields + 1] = fn end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list
	end,
	get_player_by_name = function(name) return players[name] end,
	get_us_time = function() return clock_us end,
	get_player_window_information = function(name) return window_info[name] end,
	formspec_escape = fs_escape,
	show_formspec = function(name, formname, form)
		shows[#shows + 1] = {name = name, formname = formname, form = form}
		shown[name] = form ~= "" and formname or nil
	end,
	close_formspec = function(name, formname)
		if shown[name] == formname then shown[name] = nil end
	end,
	explode_textlist_event = function(value)
		local kind, index = tostring(value):match("^(%u+):(%d+)$")
		return {type = kind or "INV", index = tonumber(index) or 0}
	end,
	log = function() end,
	after = function(_, fn, ...) after_calls[#after_calls + 1] = {fn = fn, args = {...}} end,
	colorize = function(_, text) return text end,
	-- Round 47: the Bosses layer reads the bosses' names and fixed levels.
	registered_entities = {
		["grug_mobs:king_human"] = {description = "King of Highcourt", _grug_fixed_level = 65},
		["grug_mobs:king_orc"] = {description = "Dur Gash King", _grug_fixed_level = 65},
		["grug_mobs:ice_dragon"] = {description = "Rimewing", _grug_fixed_level = 70},
		["grug_mobs:rift_boss"] = {description = "Vharos the Torn", _grug_fixed_level = 60},
	},
})
rawset(_G, "minetest", core)
rawset(_G, "default", {node_formspec = {shown_form = function(name) return shown[name] end}})

-- ---------------------------------------------------------------------------
-- K: the key helper
-- ---------------------------------------------------------------------------
dofile(repo .. "/mods/PLAYER/grug_keys/init.lua")
local key_step = steps[#steps]
do
	local pressed = {}
	grug_keys.register_on_press("zoom", function(p) pressed[#pressed + 1] = "zoom:" .. p.name end)
	grug_keys.register_on_press("aux1", function(p) pressed[#pressed + 1] = "aux1:" .. p.name end)
	local ok = pcall(grug_keys.register_on_press, "jump", function() end)
	check(not ok, "K an unknown key is refused")
	local a = make_player("anna", {x = 0, z = 0}, "accord")
	players.anna = a
	for _, fn in ipairs(on_join) do fn(a) end
	eq(a.props.zoom_fov, 72, "K zoom_fov 72 on joining")
	a.bits = 512 -- zoom held while joining
	key_step(0.05)
	eq(#pressed, 0, "K the first step only records the keys")
	a.bits = 0
	key_step(0.05)
	a.bits = 512
	key_step(0.05)
	eq(table.concat(pressed, ","), "zoom:anna", "K zoom's rising edge")
	key_step(0.05); key_step(0.05)
	eq(#pressed, 1, "K a held key does not fire again")
	a.bits = 0
	key_step(0.05)
	eq(#pressed, 1, "K the release does not fire")
	a.bits = 32 + 1 + 16 -- aux1 with up and jump
	key_step(0.05)
	eq(pressed[2], "aux1:anna", "K aux1's rising edge, other keys ignored")
	a.bits = 32 + 512
	key_step(0.05)
	eq(pressed[3], "zoom:anna", "K zoom rising while aux1 is held")
	eq(#pressed, 3, "K aux1 held does not fire")
	local reads = a.reads
	key_step(0.05)
	eq(a.reads - reads, 1, "K one control read per player per step")
	local rising = grug_keys.rising(0, 32 + 512)
	eq(table.concat(rising, ","), "zoom,aux1", "K rising() reports both keys")
	eq(#grug_keys.rising(512, 512), 0, "K rising() is empty for a held key")
	for _, fn in ipairs(on_leave) do fn(a) end
	a.bits = 512
	key_step(0.05)
	eq(#pressed, 3, "K after leaving and rejoining the first step only records")
	players.anna = nil
end

-- ---------------------------------------------------------------------------
-- The game stubs for grug_map
-- ---------------------------------------------------------------------------
local journals = {}
local function journal_of(p)
	return journals[p.name] or {quests = {}, tracked = {}, hud_enabled = true}
end
local quest_calls = {}
local markers_changed = {}
-- Round 47: the Quests layer's giver states (grug_quests.marker_states).
local giver_states = {}
local registered_quests = {
	q_kill = {id = "q_kill", level = 4, zone = "dawnmere", npc = "elder", turnin_npc = "elder",
		objectives = {
			{type = "kill", mobs = {"grug_mobs:bandit"}, area = "dawnmere/bandit_camp", count = 7},
			{type = "kill", mobs = {"grug_mobs:crumb"}, count = 1},
		}},
	q_wolf = {id = "q_wolf", level = 3, zone = "dawnmere", npc = "elder", turnin_npc = "elder",
		objectives = {{type = "kill", mobs = {"grug_mobs:wolf"}, count = 5}}},
	q_talk = {id = "q_talk", level = 2, zone = "dawnmere", npc = "elder", turnin_npc = "smith",
		objectives = {{type = "talk", npc = "smith", count = 1}}},
	q_use = {id = "q_use", level = 5, zone = "dawnmere", npc = "smith", turnin_npc = "smith",
		objectives = {{type = "use", place = "dawnmere/old_well", count = 1},
			{type = "item", item = "default:apple", count = 3}}},
	q_enemy = {id = "q_enemy", level = 5, zone = "kezamba", npc = "warlord", turnin_npc = "warlord",
		objectives = {{type = "item", item = "default:apple", count = 1}}},
	-- A PvP garrison camp in the other faction's land, and the rift boss.
	q_camp = {id = "q_camp", level = 30, zone = "front_x", npc = "elder", turnin_npc = "elder",
		objectives = {{type = "kill", mobs = {"grug_mobs:captain_throng"},
			area = "front_x/pvp_camp_x_throng_low", count = 1}}},
	q_rift = {id = "q_rift", level = 40, zone = "dawnmere", npc = "elder", turnin_npc = "elder",
		objectives = {{type = "kill", mobs = {"grug_mobs:rift_boss"}, count = 1}}},
}
rawset(_G, "grug_quests", {
	registered_quests = registered_quests,
	registered_npcs = {elder = {title = "Elder Maren"}, smith = {title = "Smith Doran"},
		warlord = {title = "Warlord Gash"}},
	journal = function(p) return journal_of(p) end,
	register_on_markers_changed = function(fn) markers_changed[#markers_changed + 1] = fn end,
	marker_states = function() return giver_states, 1 end,
	use_place_xz = function(ref) return ref == "dawnmere/old_well" and {x = 300, z = -100} or nil end,
	list_entry = function(title, status, repeatable)
		return "#" .. status .. fs_escape(title .. (repeatable and " (R)" or ""))
	end,
	status_tooltip = function() return "legend" end,
	objective_action = function(o) return (o.type == "kill" and "Defeat " or "Bring ") .. (o.what or "x") end,
	objective_levels_text = function() return "" end,
	set_hud_enabled = function(p, on)
		quest_calls[#quest_calls + 1] = "hud " .. tostring(on)
		journal_of(p).hud_enabled = on
		for _, fn in ipairs(markers_changed) do fn(p) end
	end,
	set_tracked = function(p, id, on)
		quest_calls[#quest_calls + 1] = "track " .. id .. " " .. tostring(on)
		if on and id == "q_full" then return false, "You track ten quests already." end
		local j = journal_of(p)
		if on then j.tracked[#j.tracked + 1] = id else
			for i = #j.tracked, 1, -1 do if j.tracked[i] == id then table.remove(j.tracked, i) end end
		end
		for _, fn in ipairs(markers_changed) do fn(p) end
		return true
	end,
	abandon = function(p, id)
		quest_calls[#quest_calls + 1] = "abandon " .. id
		local j = journal_of(p)
		for i = #j.quests, 1, -1 do if j.quests[i].id == id then table.remove(j.quests, i) end end
		for _, fn in ipairs(markers_changed) do fn(p) end
	end,
})

-- Two factions' settlements: Highcourt (accord) and Gor Drazhak (throng),
-- each with a trainer, a riding trainer, the Steward, a Crownbinder and the
-- quest NPCs' sockets. Round 47: their slots and names for the layers, and
-- one place of every other kind (camps, mines, a clash site, a rare den, the
-- PvP places, a dragon arena beside its dragon and one far from it).
local settlements = {
	{key = "highcourt", race_id = "human", anchor = {x = 100, y = 10, z = 100}, slot = "capital",
		display_name = "Highcourt"},
	{key = "pvp_camp_x_throng_low", race_id = "orc", anchor = {x = -900, y = 10, z = 700},
		slot = "pvp_throng_low", display_name = "Front Throng Low Camp"},
	{key = "gor_drazhak", race_id = "orc", anchor = {x = -2000, y = 10, z = 1500}, slot = "capital",
		display_name = "Gor Drazhak"},
	{key = "dawnmere", race_id = "human", anchor = {x = 20, y = 10, z = -300}, slot = "start",
		display_name = "Dawnmere"},
	{key = "r20_051", race_id = "orc", anchor = {x = -1700, y = 10, z = 1300}, slot = "village_1",
		display_name = "Speargrass Wellhold"},
	{key = "r20_052", race_id = "human", anchor = {x = 300, y = 10, z = 200}, slot = "outpost_1",
		display_name = "Oakspan Tollhouse"},
	{key = "r20_053", race_id = "human", anchor = {x = 520, y = 10, z = 520}, slot = "bandit_1",
		display_name = "Coalbrand Yard"},
	{key = "r20_054", race_id = "troll", anchor = {x = 700, y = 10, z = -700}, slot = "mirefolk",
		display_name = "Mire Hollow"},
	{key = "r20_055", race_id = "human", anchor = {x = 800, y = 10, z = 100}, slot = "mine",
		display_name = "Bridgechalk Dig"},
	{key = "r20_056", race_id = "dwarf", anchor = {x = -3100, y = 10, z = 300}, slot = "apex_mine",
		display_name = "Wyrmglass Fault Camp"},
	{key = "r20_057", race_id = "human", anchor = {x = -1500, y = 10, z = 900}, slot = "clash_1",
		display_name = "Ashen Wheelbreak"},
	{key = "r20_058", race_id = "human", anchor = {x = 400, y = 10, z = -500}, slot = "rare_grimtusk",
		display_name = "Grimtusk's Rooting"},
	{key = "pvp_fortress_accord", race_id = "human", anchor = {x = -400, y = 10, z = -900},
		slot = "pvp_fortress", display_name = "Ashenward Bastion"},
	{key = "r20_059", race_id = "dwarf", anchor = {x = -3250, y = 10, z = -30}, slot = "dragon",
		display_name = "Wyrmglass Dragonspire"},
	{key = "r20_060", race_id = "troll", anchor = {x = 3250, y = 10, z = -30}, slot = "dragon",
		display_name = "Stormscale Dragonroost"},
}
local sockets = {
	highcourt = {
		{id = "t1", role = "trainer", profession = "tailor", pos = {x = 120, y = 10, z = 110}},
		-- Round 46 (lane RP): the mender on the Cooking socket has a marker.
		{id = "mender", role = "trainer", profession = "cooking", pos = {x = 125, y = 10, z = 115}},
		{id = "ride", role = "riding_trainer", pos = {x = 130, y = 10, z = 90}},
		{id = "steward", role = "housing_manager", pos = {x = 140, y = 10, z = 95}},
		{id = "crown", role = "crownbinder", pos = {x = 150, y = 10, z = 95}},
		{id = "q_elder", role = "quest", pos = {x = 160, y = 10, z = 120}},
		{id = "q_smith", role = "quest", pos = {x = 170, y = 10, z = 130}},
		{id = "throne", role = "king", pos = {x = 100, y = 12, z = 132}},
	},
	gor_drazhak = {
		{id = "t1", role = "trainer", profession = "alchemist", pos = {x = -2010, y = 10, z = 1510}},
		{id = "mender", role = "trainer", profession = "cooking", pos = {x = -2015, y = 10, z = 1505}},
		{id = "q_war", role = "quest", pos = {x = -2020, y = 10, z = 1520}},
	},
}
grug_quests.registered_npcs.elder.settlement, grug_quests.registered_npcs.elder.socket = "highcourt", "q_elder"
grug_quests.registered_npcs.elder.faction = "accord"
grug_quests.registered_npcs.smith.settlement, grug_quests.registered_npcs.smith.socket = "highcourt", "q_smith"
grug_quests.registered_npcs.smith.faction = "accord"
grug_quests.registered_npcs.warlord.settlement, grug_quests.registered_npcs.warlord.socket = "gor_drazhak", "q_war"
grug_quests.registered_npcs.warlord.faction = "throng"

rawset(_G, "grug_core", {
	settlement_socket_settlements = function() return settlements end,
	settlement_sockets_at = function(key) return sockets[key] or {} end,
	zone_authority_installed = function() return true end,
	faction_ids = {"accord", "throng"},
	start_identities = function()
		return {{race_id = "human", faction_id = "accord"}, {race_id = "orc", faction_id = "throng"}}
	end,
	item_name = function(stack) return stack.name end,
	mob_level_at = function(pos) return pos.x == 400 and 12 or 30 end,
})
rawset(_G, "grug_factions", {get_faction = function(p) return p.faction end})
rawset(_G, "grug_jobs", {PROFESSIONS = {tailor = {name = "Tailor"}, alchemist = {name = "Alchemist"},
	cooking = {name = "Cooking"}}, MENDER_TITLE = "Grudge-Free Repairs",
	trainer_teaches = function(p) return p ~= "cooking" end}) -- Round 45 (lane ST)
rawset(_G, "grug_money", {format = function(c) return c .. "c" end})
-- Round 47: the zone queries the Zones layer samples. Land west of x 0 is
-- Dawnmere, east of it Kezamba, inside a 2400-node square; the rest is sea.
local zone_records = {
	dawnmere = {display_name = "Dawnmere Fields", numeric_id = 1, level_min = 1, level_max = 10},
	kezamba = {display_name = "kezamba", numeric_id = 2, level_min = 60, level_max = 60},
}
local zone_samples = 0
rawset(_G, "grug_zones", {
	at = function() return {display_name = "Dawnmere Fields"} end,
	get = function(id) return zone_records[id] or {display_name = id} end,
	water_class_at = function(x, z)
		zone_samples = zone_samples + 1
		return (math.abs(x) < 1200 and math.abs(z) < 1200) and "land" or "deep_ocean"
	end,
	id_at = function(x) return x < 0 and "dawnmere" or "kezamba" end,
})
local homes = {}
rawset(_G, "grug_home", {
	get = function(p) return homes[p.name] end,
	locations = function()
		return {{id = "inn_hc", label = "Highcourt", pos = {x = 110, z = 80}, faction = "accord"},
			{id = "inn_dm", label = "Dawnmere", pos = {x = 20, z = -300}, faction = "accord"},
			{id = "inn_gd", label = "Gor Drazhak", pos = {x = -1990, z = 1490}, faction = "throng"}}
	end,
	known_waypoints = function(p)
		return p.faction == "accord" and {{id = "ws_hc", label = "Highcourt", pos = {x = 105, z = 60}}} or {}
	end,
	claim_waypoint = function() return nil end,
})
local parties = {}
rawset(_G, "grug_parties", {
	in_party = function(p) return parties[p.name] ~= nil end,
	view = function(p)
		local members = parties[p.name]
		if not members then return nil end
		local rows = {}
		for _, name in ipairs(members) do rows[#rows + 1] = {name = name, online = players[name] ~= nil} end
		return {members = rows}
	end,
})

-- The region maps: two zones with recipes. Dawnmere has a bandit camp (two
-- regions), seven wolf meadows and a leader; Kezamba wolves too.
local function region(kind, x, z, size) return {kind = kind, x = x, z = z, size = size} end
local bandit_camp = {id = "bandit_camp", roles = {bandit = true, bandit_archer = true}}
local meadow = {id = "meadow", roles = {wolf = true, boar = true}}
local jungle = {id = "jungle", roles = {wolf = true}}
local maps = {
	dawnmere = {regions = {region(bandit_camp, 500, 500, 9), region(bandit_camp, 900, 900, 4),
		region(meadow, 200, 0, 30), region(meadow, 400, 0, 12), region(meadow, 600, 0, 12),
		region(meadow, 800, 0, 2), region(meadow, 1000, 0, 50), region(meadow, -300, 0, 6),
		region(meadow, 0, 1200, 16)}},
	kezamba = {regions = {region(jungle, 50, 50, 20)}},
}
rawset(_G, "grug_mobs", {
	dragon_map_markers = function()
		return {{id = "dragon:wyrmglass", name = "The Rimewing", pos = {x = -3260, y = 30, z = -40},
			entity = "grug_mobs:ice_dragon"}}
	end,
	rift_rules = {SITE = "r20_anchor_077"},
	spawn_regions = {
		place = function(key) return key == "r20_anchor_077" and {x = -1500, z = 900, name = "Tombroad"} or nil end,
		core = {CELL = 32},
		zone_ids = function() return {"dawnmere", "kezamba", "nowhere"} end,
		zone_has_recipe = function(zone) return maps[zone] ~= nil end,
		map = function(zone) return maps[zone] end,
		leader_roles = function() return {"crumb", "ghost_king"} end,
		leader_pos = function(role) return role == "crumb" and {x = 520, y = 12, z = 480} or nil end,
	},
})

-- sfinv: pages, contexts and the set_page/get_page flow the Map tab uses.
local pages, contexts, inv_forms = {}, {}, {}
local suspended = {}
rawset(_G, "sfinv", {
	register_page = function(name, def) def.name = name; pages[name] = def end,
	contexts = contexts,
	inventory_suspended = function(p) return suspended[p.name] == true end,
	get_homepage_name = function() return "grug_inventory:inventory" end,
	get_or_create_context = function(p)
		contexts[p.name] = contexts[p.name] or {page = "grug_inventory:inventory"}
		return contexts[p.name]
	end,
	get_page = function(p) return (contexts[p.name] or {}).page or "grug_inventory:inventory" end,
	set_page = function(p, name)
		local context = sfinv.get_or_create_context(p)
		context.page = name
		local page = pages[name]
		if page and page.on_enter then page:on_enter(p, context) end
		inv_forms[#inv_forms + 1] = {name = p.name, page = name}
	end,
	get_formspec = function(p, context) return "inventory:" .. context.page end,
	make_formspec = function(_, _, content) return content end,
})
rawset(_G, "grug_inventory", {UI = {width = 10.4, height = 11.1}})
do -- the shared selection style, as grug_inventory/ui.lua ships it
	local source = read("mods/PLAYER/grug_inventory/ui.lua")
	local body = source:match("\n(function grug_inventory%.selected_button_style.-\nend)\n")
	assert(body, "grug_inventory.selected_button_style not found")
	assert(loadstring(body))()
end

rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
local minimap_on = {}
grug_map.minimap = {available = function() return true end,
	enabled = function(p) return minimap_on[p.name] ~= false end,
	set_enabled = function(p, on) minimap_on[p.name] = on end}
grug_map.atlas.set_base_texture("grug_map_base.png")
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
-- location.lua's zone provider, as a stand-in: the window must not draw it.
grug_map.atlas.register_marker_provider("zone", function()
	return {{id = "dawnmere", label = "Dawnmere", position = {x = 0, z = 0}, kind = "zone",
		texture = "grug_map_zone.png"}}
end)
dofile(repo .. "/mods/PLAYER/grug_map/page.lua")
local W = dofile(repo .. "/mods/PLAYER/grug_map/window.lua")
for _, fn in ipairs(on_loaded) do fn() end
local window_step = steps[#steps]
local field_handler = on_fields[#on_fields]

-- ---------------------------------------------------------------------------
-- S: the window size and layout
-- ---------------------------------------------------------------------------
do
	local w, h = W.window_size({max_formspec_size = {x = 1920 / 72, y = 1080 / 72}})
	check(near(w, 22.66, 0.011) and near(h, 12.75, 0.011), ("S 85 %% of 26.67x15 (%.2fx%.2f)"):format(w, h))
	w, h = W.window_size(nil)
	check(w == 20 and h == 12, "S fallback without window information")
	w, h = W.window_size({size = {x = 800, y = 600}})
	check(w == 20 and h == 12, "S fallback without max_formspec_size")
	w, h = W.window_size({max_formspec_size = {x = 12, y = 8}})
	check(w == 16 and h == 10, "S the floor 16x10")
	w, h = W.window_size({max_formspec_size = {x = 20, y = 15}}) -- 4:3
	check(near(w, 17, 0.011) and near(h, 12.75, 0.011), "S 4:3 screen")
	-- 1280x720 at GUI scale 1: the fixed image size (0.5555 in, 53.3 px)
	-- wins over 720/15, so max_formspec_size is 24 x 13.5.
	w, h = W.window_size({max_formspec_size = {x = 1280 / (0.5555 * 96), y = 720 / (0.5555 * 96)}})
	check(near(w, 20.4, 0.011) and near(h, 11.47, 0.011), ("S 720p (%.2fx%.2f)"):format(w, h))
	for _, size in ipairs({{22.66, 12.75}, {20, 12}, {16, 10}, {17, 12.75}, {30, 16}, {20.4, 11.47}}) do
		local L = W.layout(size[1], size[2])
		local label = ("S layout %.2fx%.2f"):format(size[1], size[2])
		check(near(L.map_w / L.map_h, 9 / 8, 1e-9), label .. ": map 9:8")
		check(L.column.w >= 6.5 - 1e-9, label .. ": quest column at least 6.5 wide")
		check(L.column.x > L.map_x + L.map_w + 0.3, label .. ": column right of the map's scrollbar")
		check(L.column.x + L.column.w <= size[1] + 1e-9 and L.column.y + L.column.h <= size[2] + 1e-9,
			label .. ": column inside the window")
		check(L.map_y + L.map_h + 0.35 <= size[2] - 0.2 + 1e-9, label .. ": map and scrollbar inside")
		-- Round 47: two button rows take 1.45 units at the 16x10 floor (GUI
		-- scale 1.5 on 1080p), so the map there is 7.76 wide (8.35 before).
		check(L.map_w > 7.5, label .. (": map at least 7.5 wide (%.2f)"):format(L.map_w))
	end
	local L = W.layout(22.66, 12.75)
	print(("R44 MQ window 1920x1080 (GUI scale 1): 22.66x12.75, map %.2fx%.2f, column %.2f"):format(
		L.map_w, L.map_h, L.column.w))
end

-- ---------------------------------------------------------------------------
-- O: the overlay per faction and quest state
-- ---------------------------------------------------------------------------
local function quest_row(id, ready, objectives)
	local def = registered_quests[id]
	local rows = {}
	for i, o in ipairs(def.objectives) do
		local p = objectives and objectives[i] or 0
		rows[i] = {type = o.type, count = p, required = o.count, what = id .. i}
	end
	return {id = id, title = "Title " .. id, description = "About " .. id, objectives = rows,
		ready = ready, npc = def.turnin_npc, repeatable = false, travel = id == "q_talk",
		rewards = {copper = 12, items = {}}, reward_xp = 40}
end

local accord = make_player("ann", {x = 450, z = 450}, "accord")
local throng = make_player("tor", {x = -2000, z = 1500}, "throng")
players.ann, players.tor = accord, throng
homes.ann = {id = "inn_hc"}
journals.ann = {quests = {quest_row("q_kill", false, {3, 0}), quest_row("q_wolf", true, {5}),
	quest_row("q_talk", true), quest_row("q_use", false, {0, 3}), quest_row("q_enemy", false)},
	tracked = {"q_kill"}, hud_enabled = true}
journals.tor = {quests = {quest_row("q_enemy", false)}, tracked = {}, hud_enabled = false}

local function images(form)
	local list = {}
	for x, y, w, h, texture in form:gmatch("image%[([%d.%-]+),([%d.%-]+);([%d.]+),([%d.]+);([^%]]+)%]") do
		list[#list + 1] = {x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h),
			texture = texture}
	end
	return list
end
local function find_image(list, texture)
	for _, image in ipairs(list) do
		if image.texture == texture then return image end
	end
end
local function map_part(form)
	return form:match("scroll_container%[.-scroll_container_end%[%]scroll_container_end%[%]") or ""
end

-- Round 47 (lane ML): one marker layer at a time. A layer's state as the
-- window shows it.
local function layer_form(p, layer, zoom, info)
	local state = W.new_state()
	state.layer, state.zoom = layer, zoom or 1
	local form = W.formspec(p, state, info)
	return map_part(form), state, form
end
local function textures_of(map)
	local set = {}
	for _, image in ipairs(images(map)) do set[image.texture] = (set[image.texture] or 0) + 1 end
	return set
end
-- The markers each layer owns (by texture): none of them in another layer.
local OWN = {
	quests = {"grug_map_quest_available.png", "grug_map_quest_locked.png"},
	bosses = {"grug_map_king.png", "grug_map_dragon.png", "grug_map_rare_den.png", "grug_map_clash.png"},
	trainers = {"grug_map_trainer_tailor.png", "grug_mounts_icon_human.png",
		"grug_map_housing_steward.png", "grug_map_crownbinder.png", "grug_map_repair.png"},
	towns = {"grug_map_capital.png", "grug_map_start.png", "grug_map_village.png",
		"grug_map_outpost.png", "grug_map_home.png", "grug_map_innkeeper.png", "grug_map_waypoint.png"},
	pois = {"grug_map_bandit.png", "grug_map_mirefolk.png", "grug_map_mine.png"},
	pvp = {"grug_map_fortress.png", "grug_map_war_camp.png"},
}
-- (the rift boss in Bosses uses the clash site's icon; POIs has the clash
-- site itself: both are checked by tooltip below)

do
	giver_states.elder, giver_states.smith, giver_states.warlord = "available", "locked", "ready"
	local state = W.new_state()
	eq(state.layer, "quests", "O a new session starts on the Quests layer (§3 default)")
	-- One layer only: every layer shows its own markers and none of the
	-- others'; the base image and the player's arrow in every one.
	for _, layer in ipairs(grug_map.layers.LIST) do
		local map = layer_form(accord, layer.id)
		local set = textures_of(map)
		check(set["grug_map_base.png"] == 1, "O " .. layer.id .. ": the base image")
		check(set["grug_map_heading_gold_00.png"] == 1, "O " .. layer.id .. ": the player's arrow")
		for other, list in pairs(OWN) do
			for _, texture in ipairs(list) do
				if other == layer.id then
					check(set[texture] ~= nil, "O " .. layer.id .. " draws " .. texture)
				elseif not (texture == "grug_map_clash.png" and (layer.id == "pois" or
						layer.id == "bosses")) then
					check(set[texture] == nil, "O " .. layer.id .. " draws no " .. texture)
				end
			end
		end
		eq(count(map, "image_button%["), 0, "O " .. layer.id .. ": no image buttons on the map")
		eq(count(map, "[^_]button%["), 0, "O " .. layer.id .. ": no buttons on the map")
	end
	-- Quests: the own faction's givers by state, the NPC's name as tooltip.
	local map = layer_form(accord, "quests")
	has(map, ";Elder Maren]", "O Quests: the giver's name as tooltip")
	has(map, ";Smith Doran]", "O Quests: a locked giver is shown (§8 default) with its name")
	lacks(map, "Warlord Gash", "O Quests: no giver of the other faction")
	lacks(map, "grug_map_quest_ready.png", "O Quests: the other faction's ready giver is not drawn")
	eq(count(map, "tooltip%["), 2, "O Quests: one tooltip per marker")
	giver_states.elder = "ready"
	eq(count(layer_form(accord, "quests"), "grug_map_quest_ready%.png"), 1, "O Quests: ready is gold")
	giver_states.elder = "active"
	eq(count(layer_form(accord, "quests"), "grug_map_quest_active%.png"), 1, "O Quests: active is silver")
	has(layer_form(throng, "quests"), ";Warlord Gash]", "O Quests: the other side sees its own giver")
	-- Trainers & traders: the own faction's, two thirds at 1x and 2x.
	map = layer_form(accord, "trainers")
	local trainer = find_image(images(map), "grug_map_trainer_tailor.png")
	check(trainer and near(trainer.w, 0.23), "O Trainers: two thirds size at 1x")
	trainer = find_image(images(layer_form(accord, "trainers", 2)), "grug_map_trainer_tailor.png")
	check(trainer and near(trainer.w, 0.23), "O Trainers: two thirds at 2x")
	trainer = find_image(images(layer_form(accord, "trainers", 4)), "grug_map_trainer_tailor.png")
	check(trainer and near(trainer.w, 0.34), "O Trainers: full size at 4x")
	for _, text in ipairs({"Tailor Trainer", "Riding Trainer", "Housing Steward", "Crownbinder",
			"Grudge-Free Repairs"}) do
		has(map, ";" .. text .. "]", "O Trainers: tooltip " .. text)
	end
	lacks(map, "grug_map_trainer_alchemist.png", "O Trainers: none of the other faction")
	local tmap = layer_form(throng, "trainers")
	check(tmap:find("grug_map_trainer_alchemist.png", 1, true) and
		not tmap:find("grug_map_trainer_tailor.png", 1, true), "O Trainers: the throng sees its own")
	-- Towns & travel: both factions' settlements, the own innkeepers and
	-- travel.
	map = layer_form(accord, "towns")
	local set = textures_of(map)
	eq(set["grug_map_capital.png"], 2, "O Towns: both factions' capitals (ruling 5)")
	has(map, ";Gor Drazhak]", "O Towns: the other faction's capital by name")
	has(map, ";Speargrass Wellhold]", "O Towns: the other faction's village")
	has(map, ";Oakspan Tollhouse]", "O Towns: an outpost")
	eq(set["grug_map_innkeeper.png"], 1, "O Towns: the other own innkeeper (the home has its icon)")
	has(map, ";Dawnmere Innkeeper]", "O Towns: an innkeeper's tooltip")
	has(map, ";Your home: Highcourt Innkeeper]", "O Towns: the home's tooltip")
	has(map, ";Highcourt Waystone]", "O Towns: a discovered waystone")
	lacks(map, "Gor Drazhak Innkeeper", "O Towns: no innkeeper of the other faction")
	set = textures_of(layer_form(throng, "towns"))
	check(set["grug_map_capital.png"] == 2 and set["grug_map_innkeeper.png"] == 1 and
		not set["grug_map_waypoint.png"] and not set["grug_map_home.png"],
		"O Towns: the throng sees both capitals, its innkeeper, no waystone undiscovered")
	-- Bosses: kings, the dragon once, the rift boss, the rare den; levels.
	map = layer_form(accord, "bosses")
	set = textures_of(map)
	has(map, ";King of Highcourt (level 65)]", "O Bosses: the king with his level")
	has(map, ";The Rimewing (level 70)]", "O Bosses: the dragon with its level")
	eq(set["grug_map_dragon.png"], 2, "O Bosses: the dragon, and the arena far from it (SAME_PLACE)")
	has(map, ";Stormscale Dragonroost]", "O Bosses: the arena without its dragon keeps its marker")
	lacks(map, "Wyrmglass Dragonspire", "O Bosses: the arena beside its dragon is one icon")
	has(map, ";Vharos the Torn (level 60)]", "O Bosses: the rift boss at his site")
	has(map, ";Grimtusk's Rooting\nRare den\\, level 12]", "O Bosses: the rare den with its level")
	-- POIs and PvP, both factions, kind and name.
	map = layer_form(accord, "pois")
	for _, text in ipairs({"Bandit camp: Coalbrand Yard", "Mirefolk camp: Mire Hollow",
			"Mine: Bridgechalk Dig", "Gem camp: Wyrmglass Fault Camp", "Clash site: Ashen Wheelbreak"}) do
		has(map, ";" .. text .. "]", "O POIs: " .. text)
	end
	map = layer_form(throng, "pvp")
	has(map, ";Ashenward Bastion]", "O PvP: the other faction's fortress")
	has(map, ";Front Throng Low Camp]", "O PvP: a war camp")
	-- Zones: a box and a two-line label per zone, no icons or tooltips.
	map = layer_form(accord, "zones")
	eq(count(map, "box%["), 2, "O Zones: a box per zone")
	has(map, "Dawnmere Fields\nLevels 1–10]", "O Zones: name and level band")
	has(map, "kezamba\nLevel 60]", "O Zones: a single-level band")
	eq(count(map, "tooltip%["), 0, "O Zones: no tooltips")
	local zbox = map:find("box%[")
	local zlabel = map:find("label%[[^%]]*Dawnmere Fields")
	check(zbox and zlabel and zbox < zlabel, "O Zones: the box before (under) its label")
	-- None: only the arrows.
	map = layer_form(accord, "none")
	eq(#images(map), 2, "O None: the base and the arrow only")
	-- A party member: a cyan arrow with the name, in every layer and mode;
	-- tooltips topmost first (the client takes the first rect).
	local bea = make_player("bea", {x = 600, z = 600}, "accord")
	players.bea = bea
	parties.ann, parties.bea = {"ann", "bea"}, {"ann", "bea"}
	for _, layer in ipairs(grug_map.layers.LIST) do
		map = layer_form(accord, layer.id)
		check(map:find("grug_map_heading_cyan_00.png", 1, true) and map:find(";bea]", 1, true),
			"O " .. layer.id .. ": the party arrow with the member's name")
		local gold = map:find("grug_map_heading_gold", 1, true)
		local cyan = map:find("grug_map_heading_cyan", 1, true)
		local first_image = map:find("[^_]image%[[^%]]*grug_map_quest_") or 0
		check(gold and cyan and cyan < gold and first_image < cyan, "O " .. layer.id ..
			": order markers, party, player")
		local tip = map:find("tooltip%[")
		check(not tip or tip > gold, "O " .. layer.id .. ": tooltips after every image")
		check(not tip or map:find("tooltip%[[^%]]*;bea%]") == tip,
			"O " .. layer.id .. ": the party arrow's tooltip first")
	end
	local state_q = W.new_state()
	state_q.quest_selected = "q_enemy"
	map = map_part(W.formspec(accord, state_q, nil))
	check(map:find(";bea]", 1, true) ~= nil, "O quest mode: the party arrow with its name")
	-- Tooltips in reverse draw order: of two overlapping icons the one
	-- drawn later (on top) has the earlier tooltip.
	map = layer_form(accord, "towns")
	local drawn, tipped = {}, {}
	for _, image in ipairs(images(map)) do
		if not image.texture:find("heading", 1, true) then drawn[#drawn + 1] = image.texture end
	end
	for text in map:gmatch("tooltip%[[^;]*;[^;]*;([^%]]*)%]") do tipped[#tipped + 1] = text end
	-- (bake.KINDS: war camps, outposts, villages, ... starts, capitals)
	eq(tipped[#tipped], "Oakspan Tollhouse", "O the bottom marker's tooltip last (the outpost, drawn first)")
	check(drawn[2] == "grug_map_outpost.png" and drawn[#drawn - 1] == "grug_map_home.png",
		"O the outpost drawn first above the base, the NPCs and travel above the towns")
	eq(tipped[2], "Highcourt Waystone", "O the topmost marker's tooltip right after the party arrow's")
	parties.ann, parties.bea, players.bea = nil, nil, nil
	giver_states.elder, giver_states.smith, giver_states.warlord = nil, nil, nil
end

-- Quest mode (ruling 2, §3): the selected quest's targets with their
-- objective lines and its hand-in NPC, nothing of the layer; no layer
-- button highlighted.
do
	giver_states.elder, giver_states.smith = "available", "available"
	local state = W.new_state()
	state.layer = "towns"
	state.quest_selected = "q_kill"
	local form = W.formspec(accord, state, nil)
	local map = map_part(form)
	local set = textures_of(map)
	check(set["grug_map_crosshair.png"] == 1 and set["grug_map_quest_active.png"] == 1,
		"Quest mode: the crosshair and the hand-in NPC (silver, in progress)")
	check(not set["grug_map_capital.png"] and not set["grug_map_quest_available.png"],
		"Quest mode: nothing of the layer or the Quests layer")
	has(map, ";Elder Maren]", "Quest mode: the hand-in NPC's name")
	has(map, ";Defeat q_kill1: 3/7]", "Quest mode: a ring's tooltip is its objective's line")
	has(map, ";Defeat q_kill2: 0/1]", "Quest mode: the crosshair's tooltip")
	eq(count(form, "bgcolor=#8a682f"), 0, "Quest mode: no layer button highlighted")
	-- Two objectives on one crosshair share it, one line each.
	journals.ann.quests[#journals.ann.quests + 1] = {id = "q_two", title = "Two", description = "",
		objectives = {{type = "kill", count = 0, required = 1, what = "crumb"},
			{type = "kill", count = 0, required = 2, what = "crumb again"}},
		ready = false, npc = "smith", rewards = {copper = 0, items = {}}, reward_xp = 0}
	registered_quests.q_two = {id = "q_two", level = 4, zone = "dawnmere", npc = "smith",
		turnin_npc = "smith", objectives = {{type = "kill", mobs = {"grug_mobs:crumb"}, count = 1},
			{type = "kill", mobs = {"grug_mobs:crumb"}, count = 2}}}
	state.quest_selected = "q_two"
	map = map_part(W.formspec(accord, state, nil))
	eq(count(map, "grug_map_crosshair%.png"), 1, "Quest mode: one crosshair for both")
	has(map, ";Defeat crumb: 0/1\nDefeat crumb again: 0/2]", "Quest mode: both lines on it")
	table.remove(journals.ann.quests)
	registered_quests.q_two = nil
	-- Outside quest mode the active layer's button is highlighted.
	state.quest_selected = nil
	form = W.formspec(accord, state, nil)
	has(form, "style[grug_map_layer_towns;bgcolor=#8a682f", "O the active layer's button highlighted")
	eq(count(form, "bgcolor=#8a682f"), 1, "O exactly one button highlighted")
	for _, layer in ipairs(grug_map.layers.LIST) do
		has(form, ";grug_map_layer_" .. layer.id .. ";" .. layer.label .. "]", "O button " .. layer.label)
		has(form, "tooltip[grug_map_layer_" .. layer.id .. ";" .. fs_escape(layer.title) .. "]",
			"O button tooltip " .. layer.title)
	end
	local labels = {}
	for _, layer in ipairs(grug_map.layers.LIST) do labels[#labels + 1] = layer.label end
	eq(table.concat(labels, ","), "Quests,Bosses,Trainers,Towns,POIs,PvP,Zones,None",
		"O button order as in the work package's table (§8 default)")
	giver_states.elder, giver_states.smith = nil, nil
end

-- ---------------------------------------------------------------------------
-- T: the quest target index and the targets
-- ---------------------------------------------------------------------------
local targets = dofile(repo .. "/mods/PLAYER/grug_map/targets.lua")
do
	local index = grug_map.quest_targets.index()
	local stats = grug_map.quest_targets.stats()
	eq(stats.entries, 10, "T index: every region once")
	eq(#(index.roles.wolf or {}), 8, "T index: wolf in seven meadows and the jungle")
	eq(#(index.roles.bandit or {}), 2, "T index: bandits in both camp regions")
	eq(#(index.areas["dawnmere/bandit_camp"] or {}), 2, "T index: the camp area")
	check(index.leaders.crumb and index.leaders.crumb.x == 520, "T index: the leader's spot")
	check(index.leaders.ghost_king == nil, "T index: a leader without a spot is left out")
	print(("R44 MQ target index (fixture): %d roles, %d regions, %d areas, %d leaders"):format(
		stats.roles, stats.entries, stats.areas, stats.leaders))

	local lookup = {npc = function(id) return id == "smith" and {x = 170, z = 130} or nil end,
		place = function(ref) return ref == "dawnmere/old_well" and {x = 300, z = -100} or nil end}
	local function rows(def, counts)
		local list = {}
		for i, o in ipairs(def.objectives) do list[i] = {count = counts[i] or 0, required = o.count} end
		return list
	end
	-- Kill seven bandits and their leader: the crosshair, then the camp rings.
	local found = targets.targets(index, registered_quests.q_kill, rows(registered_quests.q_kill, {}),
		{x = 450, z = 450}, lookup)
	eq(#found.crosshairs, 1, "T the leader's crosshair")
	check(found.crosshairs[1].x == 520 and found.crosshairs[1].z == 480, "T at the leader's spot")
	eq(#found.rings, 2, "T both camp regions")
	check(found.rings[1].x == 500, "T nearest ring first")
	-- Bandits done: only the leader.
	found = targets.targets(index, registered_quests.q_kill, rows(registered_quests.q_kill, {7, 0}),
		{x = 450, z = 450}, lookup)
	check(#found.crosshairs == 1 and #found.rings == 0, "T a finished objective marks nothing")
	-- Wolves without an area: the quest zone's meadows only, five nearest.
	found = targets.targets(index, registered_quests.q_wolf, rows(registered_quests.q_wolf, {}),
		{x = 0, z = 0}, lookup)
	eq(#found.rings, 5, "T at most five rings")
	local xs = {}
	for _, ring in ipairs(found.rings) do xs[#xs + 1] = ring.x .. "," .. ring.z end
	eq(table.concat(xs, " "), "200,0 -300,0 400,0 600,0 800,0", "T the five nearest the player")
	for _, ring in ipairs(found.rings) do
		check(ring.x ~= 50, "T no ring outside the quest's zone")
	end
	-- Talk: the NPC; use: the place; item: nothing.
	found = targets.targets(index, registered_quests.q_talk, rows(registered_quests.q_talk, {1}),
		{x = 0, z = 0}, lookup)
	check(#found.crosshairs == 1 and found.crosshairs[1].x == 170, "T a talk NPC stays marked")
	found = targets.targets(index, registered_quests.q_use, rows(registered_quests.q_use, {0, 0}),
		{x = 0, z = 0}, lookup)
	check(#found.crosshairs == 1 and found.crosshairs[1].x == 300 and #found.rings == 0,
		"T a use place, no mark for the item objective")
	found = targets.targets(index, registered_quests.q_enemy, rows(registered_quests.q_enemy, {}),
		{x = 0, z = 0}, lookup)
	check(#found.crosshairs == 0 and #found.rings == 0, "T an item quest marks nothing")
	check(near(targets.ring_radius(9, 32), math.sqrt(9 * 1024 / math.pi)), "T ring radius from size")
	-- A garrison camp (no recipe region) and the rift boss (no region, a
	-- place of his own): a crosshair, in the other faction's land too.
	local lk = W.target_lookup
	found = targets.targets(index, registered_quests.q_camp, rows(registered_quests.q_camp, {}),
		{x = 0, z = 0}, lk)
	check(#found.crosshairs == 1 and found.crosshairs[1].x == -900 and found.crosshairs[1].z == 700
		and #found.rings == 0, "T a garrison camp's kill: a crosshair at the camp")
	found = targets.targets(index, registered_quests.q_rift, rows(registered_quests.q_rift, {}),
		{x = 0, z = 0}, lk)
	check(#found.crosshairs == 1 and found.crosshairs[1].x == -1500, "T the rift boss at his site")
	found = targets.targets(index, registered_quests.q_wolf, rows(registered_quests.q_wolf, {}),
		{x = 0, z = 0}, lk)
	check(#found.crosshairs == 0, "T a role with regions gets no role crosshair")
	-- Two objectives at one spot (a talk NPC who is also the use place):
	-- one crosshair.
	local same = {zone = "dawnmere", objectives = {{type = "talk", npc = "smith", count = 1},
		{type = "kill", mobs = {"grug_mobs:crumb"}, count = 1},
		{type = "kill", mobs = {"grug_mobs:crumb"}, count = 1}}}
	found = targets.targets(index, same, nil, {x = 0, z = 0}, lookup)
	eq(#found.crosshairs, 2, "T one crosshair per spot (the leader twice: once)")
	-- Round 47: each target names the objectives it marks (the tooltips).
	eq(table.concat(found.crosshairs[1].objectives, ","), "1", "T the talk crosshair marks objective 1")
	eq(table.concat(found.crosshairs[2].objectives, ","), "2,3", "T the shared crosshair marks both")
	found = targets.targets(index, registered_quests.q_kill, rows(registered_quests.q_kill, {}),
		{x = 450, z = 450}, lookup)
	check(found.rings[1].objectives[1] == 1 and #found.rings[1].objectives == 1 and
		found.crosshairs[1].objectives[1] == 2, "T the camp rings mark objective 1, the leader 2")

	-- In the form: rings under the crosshair, tinted and semi-transparent,
	-- sized by the region (at least RING_MIN).
	local state = W.new_state()
	state.quest_selected = "q_kill"
	local map = map_part(W.formspec(accord, state, nil))
	local ring_pos = map:find("grug_map_ring.png", 1, true)
	local cross_pos = map:find("grug_map_crosshair.png", 1, true)
	check(ring_pos and cross_pos and ring_pos < cross_pos, "T rings drawn under the crosshair")
	has(map, "grug_map_ring.png^\\[multiply:#ff8c1a^\\[opacity:190", "T ring tinted and semi-transparent")
	eq(state.target_count, 3, "T one crosshair and two rings drawn")
	local ring_sizes = {}
	for w in map:gmatch("image%[[%d.%-]+,[%d.%-]+;([%d.]+),[%d.]+;grug_map_ring") do
		ring_sizes[#ring_sizes + 1] = tonumber(w)
	end
	check(#ring_sizes == 2 and ring_sizes[1] >= 0.7 - 1e-9 and ring_sizes[2] >= 0.7 - 1e-9,
		"T rings at least the minimum size (0.7)")
	state.zoom = 8
	map = map_part(W.formspec(accord, state, nil))
	local big = tonumber(map:match("image%[[%d.%-]+,[%d.%-]+;([%d.]+),[%d.]+;grug_map_ring"))
	local L = W.layout(20, 12)
	local expect = 2 * targets.ring_radius(9, 32) * L.map_w * 8 / 7200
	check(big and near(big, expect, 0.002), ("T ring scales with the region and zoom (%.3f vs %.3f)"):format(
		big or -1, expect))
end

-- ---------------------------------------------------------------------------
-- R: the refresh rule
-- ---------------------------------------------------------------------------
local function sends_to(name, from)
	local n = 0
	for i = from or 1, #shows do
		if shows[i].name == name and shows[i].formname == W.FORMNAME then n = n + 1 end
	end
	return n
end
local function advance(seconds)
	local target = clock_us + math.floor(seconds * 1e6 + 0.5)
	while clock_us < target do
		clock_us = math.min(target, clock_us + 50000)
		window_step(0.05)
	end
end
local function fields(p, f) return field_handler(p, W.FORMNAME, f) end
do
	clock_us = 10e6
	shows = {}
	check(W.open(accord), "R the window opens")
	eq(sends_to("ann"), 1, "R the open sends at once")
	eq(shown.ann, W.FORMNAME, "R it is the shown form")
	has(shows[1].form, "size[20.00,12.00]padding[0,0]",
		"R fallback size without window information, no padding (max_formspec_size has none)")
	-- A zoom click inside the first second: owed, sent when the second ends.
	advance(0.3)
	fields(accord, {grug_map_zoom_in = "+", grug_map_scroll_x = "VAL:0", grug_map_scroll_y = "VAL:0"})
	eq(sends_to("ann"), 1, "R an event inside the gap is owed")
	fields(accord, {grug_map_zoom_in = "+", grug_map_scroll_x = "VAL:0", grug_map_scroll_y = "VAL:0"})
	advance(0.5)
	eq(sends_to("ann"), 1, "R still owed before the second is over")
	advance(0.3)
	eq(sends_to("ann"), 2, "R one trailing send for both clicks")
	has(shows[#shows].form, "label[1.75,0.55;4x]", "R the trailing send shows the latest state")
	-- A click after the gap: at once.
	advance(2)
	fields(accord, {grug_map_zoom_out = "-", grug_map_scroll_x = "VAL:1500", grug_map_scroll_y = "VAL:1500"})
	eq(sends_to("ann"), 3, "R an event after the gap sends at once")
	-- Scrollbar events alone: nothing.
	advance(2)
	local before = sends_to("ann")
	for i = 1, 10 do
		fields(accord, {grug_map_scroll_x = "CHG:" .. (100 * i), grug_map_scroll_y = "VAL:20"})
	end
	advance(3)
	eq(sends_to("ann"), before, "R scrollbar events send nothing")
	eq(W.sessions.ann.scroll_x, 1000, "R the scroll position is kept (clamped to 2x)")
	-- Alone and still: nothing for a minute.
	before = sends_to("ann")
	advance(60)
	local alone = sends_to("ann") - before
	eq(alone, 0, "R alone: no send without an event")
	-- Alone and walking: still nothing.
	for _ = 1, 60 do
		accord.pos = {x = accord.pos.x + 7, z = accord.pos.z}
		advance(1)
	end
	eq(sends_to("ann") - before, 0, "R alone and walking: no send")
	-- In a party with a walking member: at most every 2 s (Round 47 ruling
	-- 8; every 5 s before, about 12 sends a minute).
	local bea = make_player("bea", {x = 600, z = 600}, "accord")
	players.bea = bea
	parties.ann, parties.bea = {"ann", "bea"}, {"ann", "bea"}
	before = sends_to("ann")
	local start = clock_us
	local last, min_gap = nil, math.huge
	for _ = 1, 600 do
		bea.pos = {x = bea.pos.x + 0.7, z = bea.pos.z}
		local n = #shows
		advance(0.1)
		for i = n + 1, #shows do
			if shows[i].name == "ann" then
				if last then min_gap = math.min(min_gap, clock_us - last) end
				last = clock_us
			end
		end
	end
	local party_moving = sends_to("ann") - before
	check(party_moving >= 28 and party_moving <= 30, "R party moving: about 30 sends a minute (" ..
		party_moving .. ")")
	check(min_gap >= 2e6 - 1, "R party sends at least 2 s apart")
	-- In a party, standing still: nothing (after the check that sends the
	-- last step).
	advance(2.1)
	before = sends_to("ann")
	advance(60)
	local party_still = sends_to("ann") - before
	eq(party_still, 0, "R party standing still: no send")
	print(("R44 MQ sends per minute (fixture, 0.05 s steps): alone still %d, alone walking 0, " ..
		"party with a walking member %d, party still %d"):format(alone, party_moving, party_still))
	-- A quest change while the window is open: one send (throttled).
	before = sends_to("ann")
	for _, fn in ipairs(markers_changed) do fn(accord) end
	for _, fn in ipairs(markers_changed) do fn(accord) end
	eq(sends_to("ann") - before, 1, "R a quest change sends once at once")
	advance(1.1)
	eq(sends_to("ann") - before, 2, "R the second change trails")
	-- Replaced by another form: nothing more, not even in a party.
	core.show_formspec("ann", "grug_quests:npc", "size[1,1]")
	before = sends_to("ann")
	for _, fn in ipairs(markers_changed) do fn(accord) end
	advance(20)
	eq(sends_to("ann") - before, 0, "R a replaced window is never sent again")
	parties.ann, parties.bea, players.bea = nil, nil, nil
	-- Quit: closed, and a fresh open starts at 1x.
	W.open(accord)
	shown.ann = nil -- the default handler clears it on quit
	fields(accord, {quit = "true"})
	before = sends_to("ann")
	for _, fn in ipairs(markers_changed) do fn(accord) end
	eq(sends_to("ann") - before, 0, "R closed: nothing sent")
	-- A send that crosses a close: the client shows the window again, then
	-- the old instance's quit arrives. The next event of the window marks
	-- it open; clicks and pass sends work again.
	W.open(accord)
	advance(2)
	for _, fn in ipairs(markers_changed) do fn(accord) end -- a send on its way
	shown.ann = nil -- node_formspec clears it on the crossing quit
	fields(accord, {quit = "true"})
	check(not W.is_open("ann"), "R after the crossing quit the server thinks it closed")
	advance(2)
	before = sends_to("ann")
	fields(accord, {grug_map_zoom_in = "+", grug_map_scroll_x = "VAL:0", grug_map_scroll_y = "VAL:0"})
	check(W.is_open("ann"), "R an event of the window marks it open again")
	eq(sends_to("ann") - before, 1, "R the click is answered")
	for _, fn in ipairs(markers_changed) do fn(accord) end
	advance(1.1)
	eq(sends_to("ann") - before, 2, "R owed sends go out again")
	-- Another form shown since: an event of the stale window does not
	-- reopen it over that form.
	core.show_formspec("ann", "grug_quests:npc", "size[1,1]")
	fields(accord, {grug_map_zoom_in = "+"})
	before = sends_to("ann")
	for _, fn in ipairs(markers_changed) do fn(accord) end
	advance(2)
	eq(sends_to("ann") - before, 0, "R a stale event does not pop the window over another form")
	shown.ann = nil
	fields(accord, {quit = "true"})
	-- (A) "Back to inventory", then Esc on the inventory (its quit clears
	-- node_formspec's record): the window stays closed.
	local function nothing_after(label)
		local n = sends_to("ann")
		for _, fn in ipairs(markers_changed) do fn(accord) end
		local bea2 = make_player("bea2", {x = 600, z = 600}, "accord")
		players.bea2 = bea2
		parties.ann, parties.bea2 = {"ann", "bea2"}, {"ann", "bea2"}
		for _ = 1, 30 do bea2.pos = {x = bea2.pos.x + 9, z = bea2.pos.z}; advance(0.5) end
		parties.ann, parties.bea2, players.bea2 = nil, nil, nil
		eq(sends_to("ann") - n, 0, label)
	end
	W.open(accord)
	advance(2)
	fields(accord, {grug_map_back = "Back to inventory"})
	eq(shows[#shows].formname, "", "R Back to inventory shows the inventory")
	shown.ann = nil -- the inventory's quit
	nothing_after("R (A) back, then Esc: the map never pops up again")
	-- (B) Death with the map open: the death screen replaces it; its quit
	-- on respawn clears the record; the map stays closed.
	W.open(accord)
	advance(2)
	core.show_formspec("ann", "__builtin:death", "size[1,1]")
	shown.ann = nil -- the death screen's quit on respawn
	nothing_after("R (B) death and respawn: the map never pops up again")
	-- Another form shown and quit while the map was open: closed.
	W.open(accord)
	advance(2)
	core.show_formspec("ann", "grug_parties:invite", "size[1,1]")
	shown.ann = nil
	nothing_after("R another form's quit: the map stays closed")
	-- A close of every form: closed.
	W.open(accord)
	advance(2)
	core.close_formspec("ann", "")
	core.show_formspec("ann", "", "")
	shown.ann = nil
	nothing_after("R closing every form: the map stays closed")
	-- The crossing close still works after all that.
	W.open(accord)
	advance(2)
	for _, fn in ipairs(markers_changed) do fn(accord) end
	shown.ann = nil
	fields(accord, {quit = "true"})
	advance(2)
	before = sends_to("ann")
	fields(accord, {grug_map_zoom_out = "-"})
	eq(sends_to("ann") - before, 1, "R the crossing close still answers the next click")
	shown.ann = nil
	fields(accord, {quit = "true"})
	-- The scroll pause: a scrollbar move holds every send for 0.5 s; a
	-- quest change owed meanwhile goes out once the pause is over.
	W.open(accord)
	advance(2)
	before = sends_to("ann")
	fields(accord, {grug_map_scroll_x = "CHG:0", grug_map_scroll_y = "VAL:0"})
	for _, fn in ipairs(markers_changed) do fn(accord) end
	advance(0.4)
	eq(sends_to("ann") - before, 0, "R no send within 0.5 s of a scrollbar move")
	fields(accord, {grug_map_scroll_x = "CHG:0", grug_map_scroll_y = "VAL:0"}) -- still dragging
	advance(0.4)
	eq(sends_to("ann") - before, 0, "R the pause restarts with every move")
	advance(0.2)
	eq(sends_to("ann") - before, 1, "R the owed send goes out after the pause")
	-- In a party: the 2 s check (5 s before Round 47) waits for the pause too.
	local cara = make_player("cara", {x = 600, z = 600}, "accord")
	players.cara = cara
	parties.ann, parties.cara = {"ann", "cara"}, {"ann", "cara"}
	advance(1.8)
	cara.pos = {x = 900, z = 900}
	before = sends_to("ann")
	local held = clock_us
	for _ = 1, 10 do -- dragging for 2 s across the party check
		fields(accord, {grug_map_scroll_x = "CHG:0", grug_map_scroll_y = "VAL:0"})
		advance(0.2)
	end
	eq(sends_to("ann") - before, 0, "R the party check waits while the scrollbar moves")
	advance(0.6)
	eq(sends_to("ann") - before, 1, "R ...and sends once it is still")
	check(clock_us - held >= 2e6, "R (the drag lasted past the 2 s check)")
	parties.ann, parties.cara, players.cara = nil, nil, nil
	shown.ann = nil
	fields(accord, {quit = "true"})
	-- Opens are refused while the inventory belongs to character creation
	-- and while dead.
	suspended.ann = true
	check(not W.open(accord), "R no open during character creation")
	suspended.ann = nil
	accord.hp = 0
	check(not W.open(accord), "R no open while dead")
	accord.hp = 20
	-- Z opens it.
	accord.bits = 0
	key_step(0.05)
	before = sends_to("ann")
	accord.bits = 512
	key_step(0.05)
	eq(sends_to("ann") - before, 1, "R Z opens the window")
	accord.bits = 0
	key_step(0.05)
	-- The window size from the player's window information.
	window_info.ann = {max_formspec_size = {x = 1920 / 72, y = 1080 / 72}}
	advance(2)
	fields(accord, {grug_map_zoom_in = "+"})
	has(shows[#shows].form, "size[22.66,12.75]", "R the size from max_formspec_size")
end

-- ---------------------------------------------------------------------------
-- B: the pass budget (the Round 32 F4 rule, AGENTS.md "Performance"):
-- many windows in parties, opened in the same step, walking
-- ---------------------------------------------------------------------------
local function budget_run(n, seconds)
	local list = {}
	for i = 1, n do
		local name = ("w%02d"):format(i)
		local p = make_player(name, {x = -3000 + i * 40, z = 2000}, "accord")
		players[name] = p
		list[i] = p
	end
	for i = 1, n, 2 do
		local a, b = list[i].name, list[i + 1].name
		parties[a], parties[b] = {a, b}, {a, b}
	end
	shows = {}
	for _, p in ipairs(list) do W.open(p) end
	local checks_now, most_checks, most_builds = 0, 0, 0
	local real = W.party_signature
	W.party_signature = function(...) checks_now = checks_now + 1; return real(...) end
	local times = {}
	for _ = 1, math.floor(seconds / 0.1 + 0.5) do
		-- 10 nodes a second (riding): an arrow cell (about 13 nodes at 1x)
		-- per 2 s check, so every check finds a move (Round 47: 0.5 before,
		-- with the 5 s check)
		for _, p in ipairs(list) do p.pos = {x = p.pos.x + 1, z = p.pos.z} end
		local before = #shows
		checks_now = 0
		clock_us = clock_us + 100000
		window_step(0.1)
		-- a send reads the signature once itself; count the pass's checks
		local built = #shows - before
		most_builds = math.max(most_builds, built)
		most_checks = math.max(most_checks, checks_now - built)
		for i = before + 1, #shows do
			local name = shows[i].name
			times[name] = times[name] or {}
			table.insert(times[name], clock_us)
		end
	end
	W.party_signature = real
	local least, most, fewest = math.huge, 0, math.huge
	for _, p in ipairs(list) do
		local t = times[p.name] or {}
		fewest = math.min(fewest, #t)
		for i = 2, #t do
			least = math.min(least, t[i] - t[i - 1])
			most = math.max(most, t[i] - t[i - 1])
		end
	end
	for _, p in ipairs(list) do
		for _, fn in ipairs(on_leave) do fn(p) end
		players[p.name], parties[p.name] = nil, nil
	end
	return {builds = most_builds, checks = most_checks, least = least / 1e6, most = most / 1e6,
		fewest = fewest, list = list}
end
do
	local r = budget_run(12, 60)
	check(r.builds <= 2, "B 12 windows: at most two pass sends per pass (" .. r.builds .. ")")
	check(r.checks <= 8, "B 12 windows: at most eight party checks per pass (" .. r.checks .. ")")
	-- Round 47: the party check every 2 s (5 s before: about 12 a minute).
	check(r.least >= 2 - 1e-6, ("B 12 windows: party sends at least 2 s apart (%.2f)"):format(r.least))
	check(r.most <= 2.3 + 1e-6, ("B 12 windows: none waits much past 2 s (%.2f)"):format(r.most))
	check(r.fewest >= 27, "B 12 windows: each about 30 sends a minute (" .. r.fewest .. ")")
	r = budget_run(60, 60)
	check(r.builds <= 2 and r.checks <= 8, ("B 60 windows: the budget holds (%d sends, %d checks)")
		:format(r.builds, r.checks))
	check(r.fewest >= 3, ("B 60 windows: none starves (fewest %d sends, longest gap %.1f s)")
		:format(r.fewest, r.most))
	print(("R44 MQ 60 party windows walking (fixture): fewest %d sends a minute, gaps %.1f-%.1f s"):format(
		r.fewest, r.least, r.most))
	-- Gone players get nothing more.
	local before = #shows
	advance(10)
	eq(#shows, before, "B windows of players who left get nothing more")
end

-- ---------------------------------------------------------------------------
-- Q: the quest boxes
-- ---------------------------------------------------------------------------
do
	advance(2)
	local state = W.sessions.ann
	-- Nothing is preselected (the user, 2026-10-08): no targets, no text,
	-- no Track or Abandon until a click; every opening starts so.
	W.open(accord)
	local form = shows[#shows].form
	check(state.quest_selected == nil, "Q no quest preselected")
	has(form, ";grug_quest_list;#active* Title q_kill,#ready", "Q the list")
	check(form:match(";grug_quest_list;[^%]]*;0;false%]") ~= nil, "Q the list shows no selection")
	has(form, "Select a quest to read it and to see its targets on the map.", "Q the hint")
	lacks(form, "grug_quest_abandon", "Q no Abandon without a selection")
	lacks(form, "grug_quest_track", "Q no Track on HUD without a selection")
	eq(count(map_part(form), "grug_map_ring") + count(map_part(form), "crosshair"), 0,
		"Q no targets without a selection")
	state.quest_selected = "q_kill"
	form = W.formspec(accord, state, nil)
	has(form, "Active quests: 5/20", "Q the active count")
	has(form, "checkbox[", "Q checkboxes")
	has(form, ";grug_quest_hud;Quest HUD;true]", "Q the Quest HUD switch")
	has(form, "textlist[", "Q the list")
	has(form, ";grug_quest_list;#active* Title q_kill,#ready", "Q tracked quest starred, status colour")
	has(form, ";grug_quest_track;Track on HUD;true]", "Q Track on HUD for the selected quest")
	has(form, ";grug_quest_abandon;Abandon]", "Q Abandon")
	has(form, fs_escape("About q_kill\n\nDefeat q_kill1: 3/7\nDefeat q_kill2: 0/1\n\nRewards: 40 XP, 12c"),
		"Q description, objectives and rewards in one text, unwrapped")
	has(form, "Level 4 · Dawnmere Fields", "Q the level and zone line")
	lacks(form, "Ready to return", "Q no ready line while in progress")
	-- The list selects; the targets follow.
	advance(2)
	fields(accord, {grug_quest_list = "CHG:2"})
	eq(state.quest_selected, "q_wolf", "Q a list click selects")
	form = shows[#shows].form
	has(form, "Ready to return to Elder Maren.", "Q the ready line")
	check(count(map_part(form), "grug_map_ring") == 0 and count(map_part(form), "crosshair") == 0,
		"Q a finished kill quest marks nothing")
	advance(2)
	fields(accord, {grug_quest_list = "CHG:1"})
	form = shows[#shows].form
	check(count(map_part(form), "grug_map_ring") == 2 and count(map_part(form), "crosshair") == 1,
		"Q the selection's targets follow the list (the camp rings and the leader)")
	advance(2)
	fields(accord, {grug_quest_list = "CHG:2"})
	-- Track, HUD, abandon with confirmation.
	advance(2)
	quest_calls = {}
	fields(accord, {grug_quest_track = "true"})
	eq(quest_calls[1], "track q_wolf true", "Q Track on HUD")
	advance(2)
	fields(accord, {grug_quest_hud = "false"})
	eq(quest_calls[2], "hud false", "Q Quest HUD")
	advance(2)
	local n = #shows
	fields(accord, {grug_quest_abandon = "Abandon"})
	eq(#shows, n + 1, "Q Abandon asks (one send)")
	form = shows[#shows].form
	has(form, ";grug_quest_confirm;Confirm abandon]", "Q the confirmation")
	has(form, ";grug_quest_cancel;Cancel]", "Q cancel")
	lacks(form, "Track on HUD", "Q the confirmation takes the row alone")
	advance(2)
	fields(accord, {grug_quest_cancel = "Cancel"})
	lacks(shows[#shows].form, "Confirm abandon", "Q cancel hides it")
	advance(2)
	fields(accord, {grug_quest_abandon = "Abandon"})
	advance(2)
	n = #shows
	fields(accord, {grug_quest_confirm = "Confirm abandon"})
	eq(quest_calls[#quest_calls], "abandon q_wolf", "Q confirm abandons")
	eq(#shows, n + 1, "Q abandon sends once (the quest change while handling is folded in)")
	has(shows[#shows].form, "Active quests: 4/20", "Q the list follows")
	-- An empty log.
	local empty = make_player("eve", {x = 0, z = 0}, "accord")
	form = W.formspec(empty, W.new_state(), nil)
	has(form, "Your quest log is empty. Talk to a quest giver to begin.", "Q the empty log")
	has(form, "Active quests: 0/20", "Q zero quests")
	-- The Quests tab is gone.
	local tabs = read("mods/PLAYER/grug_inventory/ui.lua"):match("grug_inventory%.TAB_ORDER = (%b{})") or ""
	lacks(tabs, "grug_quests:quests", "Q no Quests tab in TAB_ORDER")
	has(tabs, "grug_map:atlas", "Q the Map tab stays")
	lacks(read("mods/PLAYER/grug_quests/init.lua"), "ui.lua", "Q grug_quests loads no tab")
	check(read("mods/PLAYER/grug_quests/ui.lua") == "", "Q grug_quests/ui.lua is gone")
end

-- ---------------------------------------------------------------------------
-- Z: zoom and the Map tab
-- ---------------------------------------------------------------------------
do
	advance(2)
	local state = W.sessions.ann
	state.zoom, state.scroll_x, state.scroll_y = 1, 0, 0
	local levels = {}
	for _ = 1, 4 do
		advance(1.1)
		fields(accord, {grug_map_zoom_in = "+"})
		levels[#levels + 1] = state.zoom
	end
	eq(table.concat(levels, ","), "2,4,8,8", "Z zoom steps")
	local form = W.formspec(accord, state, nil)
	has(form, "scrollbaroptions[min=0;max=7000;", "Z scroll range at 8x")
	has(form, "thumbsize=875;", "Z thumb at 8x")
	has(form, "scrollbaroptions[min=0;max=1000;smallstep=10;largestep=100;thumbsize=1;arrows=default]",
		"Z scrollbar options reset after the map's scrollbars")
	local base_w = tonumber(form:match("image%[0,0;([%d.]+),[%d.]+;grug_map_base%.png%]"))
	check(near(base_w, W.layout(20, 12).map_w * 8, 0.002), "Z base image 8x wide")
	advance(1.1)
	fields(accord, {grug_map_scroll_x = "CHG:99999", grug_map_scroll_y = "VAL:3500"})
	eq(state.scroll_x, 7000, "Z scroll clamps to 7000")
	advance(1.1)
	fields(accord, {grug_map_zoom_out = "-", grug_map_scroll_x = "VAL:7000", grug_map_scroll_y = "VAL:3500"})
	check(state.zoom == 4 and near((state.scroll_y + 500) / 4, (3500 + 500) / 8, 1) and
		state.scroll_x == 3000, "Z zoom out keeps the centre")
	has(shows[#shows].form, ";grug_map_scroll_x;3000]", "Z the scroll position is echoed")
	-- The minimap switch lives in the window.
	advance(1.1)
	fields(accord, {grug_map_minimap = "false"})
	eq(minimap_on.ann, false, "Z the minimap switch")
	has(shows[#shows].form, ";grug_map_minimap;Show minimap;false]", "Z the switch shows its state")
	-- No minimap on this server: a note instead of the switch.
	local available = grug_map.minimap.available
	grug_map.minimap.available = function() return false end
	form = W.formspec(accord, state, nil)
	has(form, "No minimap available", "Z the note without a minimap")
	lacks(form, "grug_map_minimap;", "Z no switch without a minimap")
	grug_map.minimap.available = available
	lacks(form, "hypertext[", "Z no region-name text (baked)")
	-- Back to inventory: the homepage in the inventory window.
	advance(1.1)
	local n = #shows
	fields(accord, {grug_map_back = "Back to inventory"})
	check(shows[n + 1] and shows[n + 1].formname == "" and
		shows[n + 1].form == "inventory:grug_inventory:inventory", "Z Back to inventory")
	-- The Map tab: opens the window, then the homepage on the next step.
	local page = pages["grug_map:atlas"]
	check(page and page.title == "Map & Quests", "Z the Map tab exists (\"Map & Quests\" since 0.45.1)")
	shows, after_calls = {}, {}
	sfinv.set_page(accord, "grug_map:atlas")
	eq(sends_to("ann"), 1, "Z the Map tab opens the window")
	eq(#after_calls, 1, "Z the homepage follows on the next step")
	after_calls[1].fn(unpack(after_calls[1].args))
	eq(sfinv.get_page(accord), "grug_inventory:inventory", "Z the inventory is back on its homepage")
	has(page:get(accord, contexts.ann), "grug_map_open", "Z the tab's own page offers the button")
	shows = {}
	page:on_player_receive_fields(accord, contexts.ann, {grug_map_open = "x"})
	eq(sends_to("ann"), 1, "Z its button opens the window")
	-- Every window form is well formed: brackets balance outside escapes.
	local form2 = shows[#shows].form
	local depth, bad, i = 0, false, 1
	while i <= #form2 do
		local c = form2:sub(i, i)
		if c == "\\" then i = i + 1
		elseif c == "[" then depth = depth + 1; if depth > 1 then bad = true end
		elseif c == "]" then depth = depth - 1; if depth < 0 then bad = true end end
		i = i + 1
	end
	check(not bad and depth == 0, "Z the window's brackets balance")
	has(form2, "formspec_version[6]", "Z formspec version 6")
	print(("R44 MQ window bytes (fixture stubs, fallback size): %d"):format(#form2))
end

-- ---------------------------------------------------------------------------
-- M (0.45.1 lane MZ): the soft lock through the window's events (the pure
-- rules: tools/r451_mz) and the focus that lets the inventory key close it
-- ---------------------------------------------------------------------------
do
	local atlas = grug_map.atlas
	advance(2)
	shows = {}
	check(W.open(accord), "M the window opens")
	local state = W.sessions.ann
	check(state.follow and state.zoom == 1, "M every opening starts at 1x with the lock")
	local form = shows[#shows].form
	local focus = form:find("set_focus[grug_map_scroll_x;true]", 1, true)
	local bar = form:find("scrollbar%[[^%]]*;grug_map_scroll_x;")
	check(focus and bar and focus < bar, "M the map's scrollbar is focused, set before it")
	eq(count(form, "set_focus%["), 1, "M one focus only")
	advance(2)
	fields(accord, {grug_map_zoom_in = "+", grug_map_scroll_x = "VAL:0", grug_map_scroll_y = "VAL:0"})
	local x, y = atlas.centre_scroll(atlas.view(), accord:get_pos(), 2)
	check(state.zoom == 2 and state.scroll_x == x and state.scroll_y == y and x > 0 and y > 0,
		"M zoom in from 1x centres on the player")
	has(shows[#shows].form, (";grug_map_scroll_x;%d]"):format(x), "M the form shows that view")
	advance(2)
	local before = sends_to("ann")
	fields(accord, {grug_map_scroll_x = "CHG:" .. (x + 100), grug_map_scroll_y = "VAL:" .. y})
	check(not state.follow and state.scroll_x == x + 100, "M the player's scrolling breaks the lock")
	advance(2)
	eq(sends_to("ann") - before, 0, "M scrolling still sends nothing")
	fields(accord, {grug_map_zoom_in = "+", grug_map_scroll_x = "VAL:" .. (x + 100),
		grug_map_scroll_y = "VAL:" .. y})
	check(state.zoom == 4 and state.scroll_x == atlas.zoom_scroll(x + 100, 2, 4) and
		state.scroll_y == atlas.zoom_scroll(y, 2, 4), "M the next zoom keeps the view's centre")
	advance(2)
	fields(accord, {grug_map_zoom_out = "-"})
	advance(2)
	fields(accord, {grug_map_zoom_out = "-"})
	check(state.zoom == 1 and state.follow, "M back at 1x restores the lock")
	-- A click on the already selected quest sends as well: the clicked list
	-- would keep the focus and eat the inventory key.
	advance(2)
	fields(accord, {grug_quest_list = "CHG:1"})
	check(state.quest_selected ~= nil, "M a quest is selected")
	advance(2)
	before = sends_to("ann")
	fields(accord, {grug_quest_list = "CHG:1"})
	eq(sends_to("ann") - before, 1, "M a click on the selected row sends the window")
end

-- ---------------------------------------------------------------------------
-- L (Round 47 lane ML): the layer buttons' layout, layer switching through
-- the window's events, the quest deselection, the zone labels, the icons
-- and the baked layer
-- ---------------------------------------------------------------------------
do
	-- The layout: one row at 1920x1080, two at the user's 1035x696 (and at
	-- 720p), the header and the quest column where Round 44 put them.
	local function round44_column(w, h)
		local map_y = 0.25 + 0.6 + 0.2
		local column = math.max(6.5, w * 0.3)
		local map_w = math.min(w - 0.5 - 0.35 - 0.3 - column, (h - map_y - 0.25 - 0.35) * 9 / 8)
		local x = 0.25 + map_w + 0.35 + 0.3
		return x, w - 0.25 - x, map_w
	end
	local sizes = {
		{"1920x1080", 1920, 1080, 72, 1},
		{"1035x696", 1035, 696, 0.5555 * 96, 2},
		{"1280x720", 1280, 720, 0.5555 * 96, 2},
		{"2560x1440", 2560, 1440, 96, 1},
	}
	for _, size in ipairs(sizes) do
		local info = {size = {x = size[2], y = size[3]},
			max_formspec_size = {x = size[2] / size[4], y = size[3] / size[4]}, real_gui_scaling = 1}
		local w, h = W.window_size(info)
		local L = W.layout(w, h)
		local b = L.buttons
		local label = "L layout " .. size[1]
		eq(b.rows, size[5], label .. ": button rows")
		check(b.w >= W.BUTTON_MIN - 1e-9, label .. (": buttons at least %.2f wide (%.2f)"):format(
			W.BUTTON_MIN, b.w))
		check(near(b.per_row * b.w + (b.per_row - 1) * b.gap, L.map_w, 1e-6), label ..
			": the buttons as wide as the map")
		check(b.y >= L.map_y + L.map_h + 0.35 - 1e-9, label .. ": the buttons under the scrollbar")
		check(b.y + b.rows * b.h + (b.rows - 1) * b.gap <= h - 0.25 + 1e-9, label ..
			": the buttons inside the window")
		local cx, cw, old_w = round44_column(w, h)
		check(near(L.column.x, cx, 1e-9) and near(L.column.w, cw, 1e-9), label ..
			": the quest column keeps its place and size (ruling 10)")
		print(("R47 ML layout %s: window %.2fx%.2f, map %.2fx%.2f (Round 44: %.2f wide), " ..
			"%d button row(s) of %.2f, spare %.2f"):format(size[1], w, h, L.map_w, L.map_h, old_w,
			b.rows, b.w, h - 0.25 - (b.y + b.rows * b.h + (b.rows - 1) * b.gap)))
		if size[1] == "1035x696" then
			check(near(L.map_w, old_w, 1e-9), label .. ": the map keeps its size (spare height)")
		end
	end

	-- Switching through the window's events.
	advance(2)
	shows = {}
	W.open(accord)
	local state = W.sessions.ann
	eq(state.layer, "quests", "L the window opens on Quests")
	advance(2)
	local before = sends_to("ann")
	fields(accord, {grug_map_layer_towns = "Towns"})
	eq(state.layer, "towns", "L a button picks its layer")
	eq(sends_to("ann") - before, 1, "L a layer click sends once")
	has(shows[#shows].form, "style[grug_map_layer_towns;bgcolor=#8a682f", "L the new layer highlighted")
	check(map_part(shows[#shows].form):find("grug_map_capital.png", 1, true) ~= nil, "L its markers shown")
	advance(2)
	before = sends_to("ann")
	fields(accord, {grug_map_layer_towns = "Towns"})
	eq(sends_to("ann") - before, 0, "L the active layer's button changes nothing")
	-- A quest selection is its own mode; a layer button deselects it.
	advance(2)
	fields(accord, {grug_quest_list = "CHG:1"})
	eq(state.quest_selected, "q_kill", "L a quest selected")
	local form = shows[#shows].form
	check(not map_part(form):find("grug_map_capital.png", 1, true), "L quest mode hides the layer")
	eq(count(form, "bgcolor=#8a682f"), 0, "L no button highlighted in quest mode")
	state.quest_abandon = "q_kill"
	advance(2)
	before = sends_to("ann")
	fields(accord, {grug_map_layer_pois = "POIs"})
	check(state.quest_selected == nil and state.quest_abandon == nil, "L a layer click deselects the quest")
	eq(state.layer, "pois", "L ...and shows that layer")
	eq(sends_to("ann") - before, 1, "L ...in one send")
	form = shows[#shows].form
	check(form:match(";grug_quest_list;[^%]]*;0;false%]") ~= nil, "L the list back to no selection")
	has(form, "Select a quest to read it and to see its targets on the map.", "L the text box's hint")
	lacks(form, "grug_quest_abandon", "L Abandon acts on no quest")
	check(map_part(form):find("grug_map_bandit.png", 1, true) ~= nil and
		count(map_part(form), "crosshair") == 0, "L the layer, no targets")
	-- The active layer's button in quest mode deselects too.
	advance(2)
	fields(accord, {grug_quest_list = "CHG:1"})
	advance(2)
	fields(accord, {grug_map_layer_pois = "POIs"})
	check(state.quest_selected == nil, "L the last layer's button deselects as well")
	-- A selected quest that leaves the log: back to the last layer.
	advance(2)
	fields(accord, {grug_quest_list = "CHG:4"})
	local id = state.quest_selected
	check(id ~= nil, "L a quest selected again")
	local saved = journals.ann.quests
	local kept = {}
	for _, row in ipairs(saved) do if row.id ~= id then kept[#kept + 1] = row end end
	journals.ann.quests = kept
	form = W.formspec(accord, state, nil)
	check(state.quest_selected == nil and map_part(form):find("grug_map_bandit.png", 1, true) ~= nil,
		"L a quest that left the log: the last chosen layer")
	journals.ann.quests = saved
	-- The layer is kept between openings (session only, §8 default), the
	-- quest selection is not.
	fields(accord, {grug_quest_list = "CHG:1"})
	shown.ann = nil
	fields(accord, {quit = "true"})
	advance(2)
	W.open(accord)
	check(state.layer == "pois" and state.quest_selected == nil,
		"L a new opening keeps the layer, without a quest")
	for _, fn in ipairs(on_leave) do fn(accord) end
	W.open(accord)
	eq(W.sessions.ann.layer, "quests", "L after leaving the game: Quests again")
	shown.ann = nil
	fields(accord, {quit = "true"})
	-- The static layers are built once at start: the providers return the
	-- same rows on every call.
	local rows = grug_map.layers.rows
	check(#rows.settlement == 5 and #rows.poi == 5 and #rows.pvp == 2 and #rows.boss == 5,
		("L the static rows (%d towns, %d POIs, %d PvP, %d bosses)"):format(#rows.settlement,
			#rows.poi, #rows.pvp, #rows.boss))
end

-- ---------------------------------------------------------------------------
-- ZL: the zone labels (zone_labels.lua) and the start's placement
-- ---------------------------------------------------------------------------
do
	local Z = grug_map.layers.zone_labels
	eq(Z.band({level_min = 1, level_max = 10}), "Levels 1–10", "ZL a level band")
	eq(Z.band({level_min = 60, level_max = 60}), "Level 60", "ZL a single level")
	eq(Z.band({}), "", "ZL no band")
	local m = Z.metrics({size = {x = 1920, y = 1080}, max_formspec_size = {x = 1920 / 72, y = 15},
		real_gui_scaling = 1})
	check(near(m.char, 16 * 0.52 / 72) and near(m.line, 16 * 1.2 / 72), "ZL metrics at 72 px per unit")
	local m2 = Z.metrics({size = {x = 1035, y = 696}, max_formspec_size = {x = 1035 / 53.33, y = 696 / 53.33},
		real_gui_scaling = 1})
	check(m2.char > m.char, "ZL text is wider in units on a smaller screen")
	local fallback = Z.metrics(nil)
	check(near(fallback.char, m.char), "ZL the fallback is 1080p at GUI scale 1")
	local box = Z.box("Dawnmere Fields", "Levels 1–10", m)
	check(near(box.w, 15 * m.char + 2 * Z.PAD_X) and near(box.h, 0.5 + m.line + 2 * Z.PAD_Y),
		"ZL the box fits the longer line (the en dash counts once) and two lines")
	local list = {}
	Z.elements(list, 5, 5, "Dawnmere Fields", "Levels 1–10", m, fs_escape)
	local bx, by, bw, bh = list[1]:match("^box%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);")
	local lx, ly = list[2]:match("^label%[([%d.]+),([%d.]+);")
	check(near(tonumber(bx) + tonumber(bw) / 2, 5, 0.002) and near(tonumber(by) + tonumber(bh) / 2, 5, 0.002),
		"ZL the box centred on the label point")
	check(tonumber(lx) > tonumber(bx) and near(tonumber(ly), tonumber(by) + Z.PAD_Y + m.line / 2, 0.002),
		"ZL the first line inside the box (label[] centres a line on its y)")
	-- Placement on a toy grid: a 10x6 zone "a" left, a 4x6 zone "b" right,
	-- water around; the poles of inaccessibility, nudged off an obstacle.
	local nx, nz = 16, 8
	local cells = {}
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			local id = false
			if gz >= 1 and gz <= 6 then
				if gx >= 1 and gx <= 10 then id = "a" elseif gx >= 11 and gx <= 14 then id = "b" end
			end
			cells[gz * nx + gx + 1] = id
		end
	end
	local grid = {nx = nx, nz = nz, step = 10, min_x = 0, max_z = 80, cells = cells}
	local depth = Z.depths(grid)
	check(depth[1] == 0 and depth[3 * nx + 5 + 1] > depth[1 * nx + 1 + 1], "ZL depth grows inland")
	local points = Z.place(grid, {{id = "a", rx = 5, rz = 5}, {id = "b", rx = 5, rz = 5}}, {})
	check(points.a and points.b and points.a.x < 110 and points.b.x > 110, "ZL one label per zone in it")
	local blocked = Z.place(grid, {{id = "a", rx = 5, rz = 5}},
		{{x = points.a.x, z = points.a.z, rx = 10, rz = 10, soft = true}})
	check(blocked.a.x ~= points.a.x or blocked.a.z ~= points.a.z, "ZL nudged off a region name")
	local p1, p2 = Z.overlaps({{x = 0, z = 0, rx = 5, rz = 5}, {x = 8, z = 0, rx = 5, rz = 5},
		{x = 50, z = 0, rx = 5, rz = 5}}, {{x = 50, z = 3, rx = 2, rz = 2}})
	check(p1 == 1 and p2 == 1, "ZL overlaps counted (one pair, one over a name)")
	-- The start's placement: the fixture's two zones, each labelled on its
	-- own land, the grid sampled once.
	local zones = grug_map.layers.zones
	eq(#zones, 2, "ZL a label per zone with land")
	check(zones[1].id == "dawnmere" and zones[1].x < 0 and zones[2].id == "kezamba" and zones[2].x > 0,
		"ZL in zone order, each on its own land")
	local stats = grug_map.layers.zone_stats
	check(stats and stats.zones == 2, "ZL the placement's figures")
	eq(zone_samples, 225 * 200, "ZL the grid sampled once at start (32 nodes, 225x200)")
end

-- ---------------------------------------------------------------------------
-- I: the layer icons and the baked layer (Round 47 ruling 4)
-- ---------------------------------------------------------------------------
do
	local licence = read("mods/PLAYER/grug_map/LICENSE-media.md")
	local B = dofile(repo .. "/mods/PLAYER/grug_map/bake.lua")
	for _, kind in ipairs(B.KINDS) do
		local shipped = read("mods/PLAYER/grug_map/textures/grug_map_" .. kind .. ".png")
		local art = read("mods/PLAYER/grug_map/art/baked_" .. kind .. ".png")
		check(shipped ~= "" and shipped == art, "I grug_map_" .. kind .. ".png is the baked art's copy")
	end
	has(licence, "textures/grug_map_{start,capital,village,outpost,fortress,war_camp,bandit,mirefolk," ..
		"mine,clash,rare_den,king,dragon}.png", "I the icons' LICENSE-media row")
	-- Every texture a layer row names ships.
	for name, list in pairs(grug_map.layers.rows) do
		for _, row in ipairs(list) do
			check(read("mods/PLAYER/grug_map/textures/" .. row.texture) ~= "", "I " .. name .. " " ..
				row.id .. ": " .. row.texture .. " ships")
		end
	end
	local layer = {items = {{kind = "village", x = 0, z = 0}}, labels = B.REGION_LABELS}
	local world = B.world_layer(layer)
	check(#world.items == 0 and world.labels == B.REGION_LABELS, "I the world map's layer: names, no icons")
	local base = read("mods/PLAYER/grug_map/base.lua")
	check(base:find("bake.draw(pixels, WIDTH, HEIGHT, view, bake.world_layer(layer)", 1, true) and
		base:find("bake.draw(mini_pixels, mini.width, mini.height, view, layer, layer.art", 1, true),
		"I base.lua: the world images get the names only, the minimap the whole layer")
end

if failures > 0 then
	error(("R44 MQ PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
print(("R44 MQ PORTABLE PASS checks=%d"):format(checks))
