-- Round 60 lane CAPITALS portable fixture (LuaJIT): the six capital quest
-- files reworked (quests.md "The capitals"), chapter 1 kept, chapter 2's
-- T3, the Alchemy quest and the story's two foremen.
--
--   luajit tools/r60_capitals/portable_test.lua [REPO]
--
-- S. The files: build_structure.py wrote the structure that ships (its
--    --check compares everything but the texts), and chapter 1 is as Round
--    59 wrote it (tools/r59_storyquests/build_structure.py --check); the six
--    files flagged `reworked`; the hubs (the envoy on `envoy` and `front`,
--    the cook on `provisions` and `dispatch`, the leader alone on `guild`);
--    every quest but the story quests free (it requires nothing); the
--    envoy ids and their `front` lines kept; the kept ids T3 names
--    (`nhal_veyr_vigil_03`, Hush alone; `nhal_veyr_vigil_04` requires
--    nothing); T3 (`story_throng_04`): story, Ossa to Iven at 29, its
--    prerequisites (T2a `story_throng_03`, `ossuary_rubbings_03`,
--    `nhal_veyr_vigil_03`) and one use at the public register; the Alchemy
--    quest: one shared quest of the six envoys on `envoy` at 19-20 with no
--    prerequisite, asking for an Elixir of Precision I, which no quest
--    rewards; no Mire Carp quest in a capital file (Varda gives the band's
--    fish quest `band_mire_carp` on her provisions line).
-- I. The Alchemy quest's ingredients: Precision I is Sunleaf + Boar Tusk +
--    a Glass Bottle (grug_alchemy recipes.lua tier 1); Sunleaf grows in all
--    six start zones and needs no profession (grug_gathering catalog.lua);
--    the boars' band-1 drop is the Boar Tusk, and every start zone hunts its
--    boars by day (`start_boars`, a variant per start town).
-- P. T3's town place: a `quest_place` socket of Nhal Veyr's Miner's Guild
--    plot, which every world builds (tools/r59_qsys3/socket_places.lua); in
--    the plot as the mapgen builds it the socket's cell and the one above
--    are air over a walkable node, off the gate path's columns, and no door
--    and no other socket lies within 2 nodes.
-- B. The real loader over seed 42's settlement sockets and the real spawn
--    recipes, names and items: the load-time world checks pass; the
--    foremen of Frostbarrow Shelf's and Ossuary Reach's camps are titled
--    Brodd Deeppeg and Rellis Shalemark, every other one Foreman; the
--    Alchemy quest at each envoy of the player's faction at its level with
--    nothing done (locked a level below, never at the other faction's),
--    turned in only at the envoy it was taken from; the shared quests at
--    their givers with nothing done; T3 hidden at Ossa until its
--    prerequisites are done, then offered at 29, its use at the public
--    register (named after Nhal Veyr), ready only at Iven after the use.
-- W. On seed 42's own chunks (tools/seed_fleet's runtime: the real plan and
--    writer): the public register's cell holds air over walkable ground.
-- V. tools/r28_design/validate.py --game: 0 errors.
-- Prints "R60 CAPITALS PORTABLE PASS checks=<n>" or raises.

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy

local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
local ZONES = repo .. "/mods/PLAYER/grug_quests/data/zones"
local function read_file(path)
	local handle = io.open(path, "r")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
local function read_json(path)
	local text = read_file(path)
	return text and json.decode(text) or nil
end
-- A LuaJIT tool outside the engine sandbox: check_lua's sweep 5 names the
-- io.popen, as in tools/r59_storyquests.
local function list_dir(path)
	local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
	local out = {}
	for line in handle:lines() do out[#out + 1] = line end
	handle:close()
	return out
end
local function run(command)
	local handle = io.popen(command .. " 2>&1")
	local text = handle:read("*a")
	handle:close()
	return text
end

local FACTIONS = {"accord", "throng"}
local ORDER = {accord = {"highcourt", "dur_brannoc", "lethariel"},
	throng = {"gor_drazhak", "kezamba", "nhal_veyr"}}
local CAPITAL = {
	highcourt = {zone = "elandor_highcourt", race = "human"},
	dur_brannoc = {zone = "elandor_dur_brannoc", race = "dwarf"},
	lethariel = {zone = "elandor_lethariel", race = "elf"},
	gor_drazhak = {zone = "kragmar_gor_drazhak", race = "orc"},
	kezamba = {zone = "kragmar_kezamba", race = "troll"},
	nhal_veyr = {zone = "kragmar_nhal_veyr", race = "undead"},
}
local RACE_FACTION = {human = "accord", dwarf = "accord", elf = "accord",
	undead = "throng", orc = "throng", troll = "throng"}
local function envoy(capital) return "r20_" .. CAPITAL[capital].race .. "_capital_envoy" end
local function cook(capital) return "r20_" .. CAPITAL[capital].race .. "_capital_cook" end
local function leader(capital) return "r58_guild_leader_" .. capital end
local CHAPTER1 = {story_accord_01 = true, story_accord_02 = true, story_throng_01 = true, story_throng_02 = true}
local T3, T3_PLACE = "story_throng_04", "socket:nhal_veyr/miners_guild/miners_guild_public_register"
local ALCHEMY, PRECISION = "capital_precision", "grug_alchemy:elixir_precision_t1"
-- The shared quests and the capitals whose givers give them.
local SHARED = {
	capital_torches = {giver = envoy, line = "envoy",
		capitals = {"highcourt", "dur_brannoc", "lethariel", "gor_drazhak", "kezamba", "nhal_veyr"}},
	capital_night_dead = {giver = envoy, line = "envoy",
		capitals = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr"}},
	capital_precision = {giver = envoy, line = "envoy",
		capitals = {"highcourt", "dur_brannoc", "lethariel", "gor_drazhak", "kezamba", "nhal_veyr"}},
	capital_raw_meat = {giver = cook, line = "provisions",
		capitals = {"lethariel", "gor_drazhak", "kezamba", "nhal_veyr"}},
}
-- Round 61 BANDQUESTS: chapter 3's two foremen (round61-plan.md §2a point 4).
local TITLES = {mining_camp_frostbarrow_shelf = "Brodd Deeppeg", mining_camp_ossuary_reach = "Rellis Shalemark",
	mining_camp_ashenward_march = "Audra Wainholt", mining_camp_bannerbreak_mesa = "Greda Stonehaul"}

------------------------------------------------------------------------------
-- S. The files.
------------------------------------------------------------------------------
local quests, file_of, file_data = {}, {}, {}
for _, name in ipairs(list_dir(ZONES)) do
	local zone = name:match("^(.+)%.quests%.json$")
	if zone and not name:find("%.front%.quests%.json$") then
		local data = read_json(ZONES .. "/" .. name)
		file_data[zone] = data
		for _, q in ipairs(data.quests or {}) do
			quests[q.id] = q
			file_of[q.id] = zone
		end
	end
end
do
	local out = run("python3 " .. repo .. "/tools/r60_capitals/build_structure.py --check")
	check(out:find("6 files, 0 differ", 1, true) ~= nil, "S build_structure.py wrote what ships: " .. out)
	out = run("python3 " .. repo .. "/tools/r59_storyquests/build_structure.py --check")
	check(out:find("0 of 6 capital files differ", 1, true) ~= nil, "S chapter 1 is as Round 59 wrote it: " .. out)
end
local capital_of_zone = {}
for capital, c in pairs(CAPITAL) do capital_of_zone[c.zone] = capital end
for capital, c in pairs(CAPITAL) do
	local data = file_data[c.zone]
	if check(data ~= nil, "S the file of " .. capital) then
		eq(data.reworked, true, "S " .. c.zone .. " is reworked")
		local lines_of, hub_of = {}, {}
		for _, hub in ipairs(data.hubs) do
			for _, giver in ipairs(hub.givers) do
				lines_of[giver.npc] = table.concat(giver.lines, ",")
				hub_of[giver.npc] = hub
			end
		end
		eq(#data.hubs, 2, "S " .. capital .. " has its two hubs")
		eq(lines_of[envoy(capital)], "envoy,front", "S " .. capital .. "'s envoy keeps the lines envoy and front")
		eq(lines_of[cook(capital)], "provisions,dispatch", "S " .. capital .. "'s cook has provisions and dispatch")
		eq(lines_of[leader(capital)], "guild", "S " .. capital .. "'s leader keeps the line guild")
		eq(#(hub_of[leader(capital)] or {givers = {}}).givers, 1, "S " .. capital .. "'s leader stands alone")
		for _, q in ipairs(data.quests) do
			if not q.story then
				eq(#(q.requires or {}), 0, "S " .. q.id .. " is free play (it requires nothing)")
			else
				check(CHAPTER1[q.id] or q.id == T3, "S " .. q.id .. " is one of the capitals' story quests")
			end
			for _, o in ipairs(q.objectives) do
				check(o.item ~= "grug_fishing:mire_carp", "S " .. q.id .. " asks for no Mire Carp (BANDQUESTS' quest)")
			end
		end
		-- The front file still talks to the envoy on its front line.
		local front = read_json(ZONES .. "/" .. c.zone .. ".front.quests.json")
		if check(front ~= nil, "S " .. capital .. "'s front file") then
			for _, q in ipairs(front.quests or {}) do
				eq(q.line, "front", "S " .. q.id .. " on the front line")
			end
		end
	end
end
-- Chapter 1 and the kept ids.
for id in pairs(CHAPTER1) do
	if check(quests[id] ~= nil, "S chapter 1's " .. id .. " ships") then
		eq(quests[id].story, true, "S " .. id .. " is a story quest")
	end
end
eq(table.concat(quests.story_accord_02.requires, ","), "story_accord_01", "S A2 requires A1")
eq(table.concat(quests.story_throng_02.requires, ","), "story_throng_01", "S T2 requires T1")
do
	local hush = quests.nhal_veyr_vigil_03
	if check(hush ~= nil, "S nhal_veyr_vigil_03 keeps its id") then
		eq(file_of[hush.id], "kragmar_nhal_veyr", "S the Hush quest lives in Nhal Veyr")
		eq(hush.giver, envoy("nhal_veyr"), "S Ossa gives the Hush quest")
		eq(#hush.objectives, 1, "S the Hush quest is Hush alone")
		eq(table.concat(hush.objectives[1].roles or {}, ","), "mortuary_clerk_hush", "S ... Mortuary Clerk Hush")
		eq(hush.story, nil, "S the Hush quest is free play")
	end
	local vaska = quests.nhal_veyr_vigil_04
	if check(vaska ~= nil, "S nhal_veyr_vigil_04 keeps its id") then
		eq(#(vaska.requires or {}), 0, "S nhal_veyr_vigil_04 requires nothing")
	end
	-- Only T3 follows the Hush quest (its one Throng follow-up).
	local followers = {}
	for id, q in pairs(quests) do
		for _, r in ipairs(q.requires or {}) do
			if r == "nhal_veyr_vigil_03" then followers[#followers + 1] = id end
		end
	end
	eq(table.concat(followers, ","), T3, "S T3 is the Hush quest's one follow-up")
end
-- T2a (lane BANDQUESTS, Ossuary Reach), which requires T2.
local t2a = "story_throng_03"
if check(quests[t2a] ~= nil, "S T2a ships") then
	eq(table.concat(quests[t2a].requires or {}, ","), "story_throng_02", "S T2a requires T2")
end
-- Varda's Mire Carp is the band's fish quest's variant on her provisions line.
do
	local fish, varda = quests.band_mire_carp, nil
	for _, v in ipairs(fish and fish.variants or {}) do
		for _, giver in ipairs(v.givers or {}) do
			if giver == cook("dur_brannoc") then varda = v end
		end
	end
	check(varda ~= nil and varda.zone == "elandor_dur_brannoc", "S Varda gives band_mire_carp in Dur Brannoc")
	eq(fish and fish.line, "provisions", "S ... on her provisions line")
end
do
	local q = quests[T3]
	if check(q ~= nil, "S T3 ships") then
		eq(file_of[T3], "kragmar_nhal_veyr", "S T3 lives in Nhal Veyr")
		eq(q.story, true, "S T3 is a story quest")
		eq(q.giver, envoy("nhal_veyr"), "S T3 is given by Ossa")
		eq(q.turnin, leader("nhal_veyr"), "S T3 is turned in at Iven")
		eq(q.line, "envoy", "S T3 is on Ossa's envoy line")
		eq(q.min_level, 29, "S T3 opens at 29")
		local want = {[t2a] = true, ossuary_rubbings_03 = true, nhal_veyr_vigil_03 = true}
		local n = 0
		for _, r in ipairs(q.requires or {}) do
			n = n + 1
			check(want[r], "S T3 requires " .. r .. " (expected " .. t2a .. ", ossuary_rubbings_03, nhal_veyr_vigil_03)")
		end
		eq(n, 3, "S T3 has three prerequisites")
		check(quests.ossuary_rubbings_03 ~= nil, "S ossuary_rubbings_03 ships (BANDQUESTS keeps the id)")
		eq(#q.objectives, 1, "S T3 has one objective")
		local o = q.objectives[1] or {}
		eq(o.type, "use", "S T3 is a use quest")
		eq(o.place, T3_PLACE, "S T3's place is the public register")
		eq(o.object, "claim_notice", "S T3's object")
	end
end
-- The shared quests.
for id, spec in pairs(SHARED) do
	local q = quests[id]
	if check(q ~= nil, "S " .. id .. " ships") then
		eq(file_of[id], CAPITAL[spec.capitals[1]].zone, "S " .. id .. " lives in its first variant's file")
		eq(q.line, spec.line, "S " .. id .. " line")
		eq(#(q.requires or {}), 0, "S " .. id .. " requires nothing")
		eq(#q.variants, #spec.capitals, "S " .. id .. " has a variant per capital")
		for index, capital in ipairs(spec.capitals) do
			local v = q.variants[index] or {}
			eq(v.zone, CAPITAL[capital].zone, "S " .. id .. " variant " .. index)
			eq(table.concat(v.givers or {}, ","), spec.giver(capital), "S " .. id .. " given in " .. capital)
			eq(v.turnins, nil, "S " .. id .. " turned in where it is given in " .. capital)
		end
	end
end
do
	local q = quests[ALCHEMY]
	if q then
		check(q.min_level >= 19 and q.min_level <= 20, "S the Alchemy quest opens at 19-20 (" .. q.min_level .. ")")
		eq(#q.objectives, 1, "S the Alchemy quest has one objective")
		eq(q.objectives[1].type, "item", "S ... an item")
		eq(q.objectives[1].item, PRECISION, "S ... an Elixir of Precision I")
		eq(q.objectives[1].count, 1, "S ... one")
	end
	-- Never a reward before (plan §2 point 6): no quest rewards the elixir.
	for qid, other in pairs(quests) do
		local rewards = other.rewards or {}
		for _, row in ipairs(rewards.items or {}) do
			check(row.item ~= PRECISION, "S " .. qid .. " rewards no Elixir of Precision I")
		end
		for _, row in ipairs(rewards.choices or {}) do
			check(row.item ~= PRECISION, "S " .. qid .. " offers no Elixir of Precision I")
		end
	end
end

------------------------------------------------------------------------------
-- I. The Alchemy quest's ingredients.
------------------------------------------------------------------------------
do
	local recipes = read_file(repo .. "/mods/ITEMS/grug_alchemy/recipes.lua")
	local tier1 = recipes:match("local RECIPES = {%s*(%b{})")
	check(tier1 and tier1:find('precision = {G .. "sunleaf", M .. "boar_tusk"}', 1, true) ~= nil,
		"I Precision I is Sunleaf + Boar Tusk (recipes.lua tier 1)")
	check(recipes:find("inputs = {inputs[1], inputs[2], VIAL}", 1, true) ~= nil, "I ... and a Glass Bottle")
	local catalog = read_file(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local row = catalog:match('p9g%("wp33_sunleaf_source_v1"(.-)%)%,%s*\n%s*p9g')
	if check(row ~= nil, "I the Sunleaf row of the gathering catalogue") then
		for _, zone in ipairs({"elandor_dawnmere_fields", "elandor_hearthpine_vale", "elandor_silverleaf_glades",
				"kragmar_sunscar_flats", "kragmar_kapok_cradle", "kragmar_stillgrave_hollow"}) do
			check(row:find('"' .. zone .. '"', 1, true) ~= nil, "I Sunleaf grows in " .. zone)
		end
		check(row:find('"none", "spice"', 1, true) ~= nil, "I Sunleaf needs no profession")
	end
	local drops = read_json(repo .. "/mods/ENTITIES/grug_mobs/data/drops.json")
	local tusk = false
	for _, family in ipairs(drops) do
		if family.family == "boar" then
			for _, d in ipairs(family.bands["1"] or {}) do
				if d.item == "grug_mobs:boar_tusk" then tusk = true end
			end
		end
	end
	check(tusk, "I the boars' band-1 drop is the Boar Tusk")
	local boars = quests.start_boars
	if check(boars ~= nil, "I start_boars ships") then
		eq(#boars.variants, 6, "I every start town hunts its boars by day")
	end
end

------------------------------------------------------------------------------
-- P. T3's town place in its plot.
------------------------------------------------------------------------------
local places_tool = dofile(repo .. "/tools/r59_qsys3/socket_places.lua")
local found = places_tool.sockets(repo, {"nhal_veyr"})
local registry_nodes = read_json(repo .. "/tools/building_templates/nodes.json")
local function walkable(name)
	local def = registry_nodes.nodes[registry_nodes.aliases[name] or name]
	return def and def.walkable ~= false
end
rawset(_G, "core", rawget(_G, "core") or {})
do
	local id = "miners_guild/miners_guild_public_register"
	local socket
	for _, row in ipairs(found.nhal_veyr.sockets) do
		if row.id == id then socket = row end
	end
	if check(socket ~= nil, "P Nhal Veyr has the socket " .. id) then
		eq(socket.role, "quest_place", "P " .. id .. " is a quest place")
		eq(socket.required, true, "P " .. id .. " stands in a plot every world builds")
		local kit = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_capital_blueprint.lua").kit("nhal_veyr")
		local built
		for _, plot in ipairs(kit.plots) do
			if plot.id == "miners_guild" then built = plot.build() end
		end
		local cells = {}
		for _, cell in ipairs(built.cells) do cells[cell.x .. "," .. cell.y .. "," .. cell.z] = cell.name end
		local function at(x, y, z) return cells[x .. "," .. y .. "," .. z] end
		local own
		for _, row in ipairs(built.landmarks.sockets) do
			if "miners_guild/" .. row.id == id then own = row end
		end
		local x, y, z = own.x, own.y or 1, own.z
		eq(at(x, y, z), "air", "P " .. id .. " its cell is air")
		eq(at(x, y + 1, z), "air", "P " .. id .. " the cell above is air")
		check(at(x, y - 1, z) ~= nil and walkable(at(x, y - 1, z)), "P " .. id .. " stands on walkable ground: " ..
			tostring(at(x, y - 1, z)))
		-- Off the gate path's columns (x -1..1 from the street edge in; the
		-- forecourt is paved with the path's node, so the columns decide).
		check(math.abs(x) > 2, "P " .. id .. " is clear of the gate path's columns")
		for _, door in ipairs(built.landmarks.doors or {}) do
			check(math.abs(door.x - x) > 2 or math.abs(door.z - z) > 2, "P " .. id .. " is no doorstep")
		end
		for _, row in ipairs(built.landmarks.sockets) do
			if row ~= own then
				check(math.abs(row.x - x) > 2 or math.abs(row.z - z) > 2, "P " .. id .. " is clear of the socket " .. row.id)
			end
		end
	end
end

------------------------------------------------------------------------------
-- B. The real loader on seed 42.
------------------------------------------------------------------------------
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local RT = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, "42")
local socket_rows = RT.main.settlement_sockets(RT.built)
local layout = RT.main.placement_layout_text()
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local catalog = dofile(wp40 .. "/r58_camp_catalog.lua")
local camps = dofile(wp40 .. "/r58_camps.lua").index(layout, {raw_sha256 = common.new_sha256(), full_seed = "42"})
local source = dofile(wp40 .. "/source/simple_map.lua")
local zone_by_id = {}
for _, zone in ipairs(source.zones) do zone_by_id[zone.id] = zone end

-- A small engine under the quest code (tools/r59_storyquests' harness).
local warnings = {}
local paths = {grug_quests = repo .. "/mods/PLAYER/grug_quests", grug_mobs = repo .. "/mods/ENTITIES/grug_mobs",
	grug_mapgen = repo .. "/mods/MAPGEN/grug_mapgen"}
local serial = {}
_G.core = setmetatable({
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	get_modpath = function(name) return paths[name] end,
	get_current_modname = function() return "grug_quests" end,
	get_dir_list = function(path) return list_dir(path) end,
	parse_json = function(text) return (json.decode(text)) end,
	log = function(level, message) warnings[#warnings + 1] = level .. ": " .. message end,
	dir_to_yaw = function(d) return math.atan2(-d.x, d.z) end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	settings = {get = function() return nil end, get_bool = function() return nil end},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
_G.vector = {distance = function() return 0 end,
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end}
_G.ItemStack = function(item)
	local name, n = tostring(item or ""):match("^(%S*)%s*(%d*)")
	return {get_name = function() return name end, get_count = function() return tonumber(n) or 1 end,
		is_empty = function() return name == "" end}
end
local saved_grug_core = rawget(_G, "grug_core")
_G.grug_core = {register_tag_visibility = function() end, register_level_overlay = function() end,
	hud_layout = {side_text_width = function() return 38 end},
	opposing_faction = function(f) return f == "accord" and "throng" or "accord" end}
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
for _, row in ipairs(socket_rows) do
	grug_core.register_settlement_sockets(row.key, row.race, row.anchor, row.sockets, row.label, row.slot)
end
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
_G.grug_zones = {get = function(id) return zone_by_id[id] end, id_at = function() return nil end,
	anchor = function() return {x = 0, z = 0} end}
_G.grug_mapgen = {mining_camps = camps}
_G.grug_classes = {registered_races = {}, get_race = function() return "human" end}
for race, faction in pairs(RACE_FACTION) do grug_classes.registered_races[race] = {faction = faction} end
local player_faction, player_level = "accord", 60
_G.grug_factions = {get_faction = function() return player_faction end,
	display_name = function(id) return "The " .. id end}
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
_G.grug_xp = {get_level = function() return player_level end, register_on_level_change = function() end,
	quest_reward = function(level, weight) return math.floor(weight * level) end}
_G.grug_money = {MAX = 1000000, format = function(c) return c .. "c" end, get = function() return 0 end}
_G.grug_inventory = {BAG_COUNT = 0, HOTBAR_STORE = "hotbar_store", wrap_text = function(text) return text end}
_G.grug_items = {check_affixes = function() return true end}
_G.grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end,
	disposition = function() return nil end}
dofile(repo .. "/tools/r28_b1/load_spawn_areas.lua")(repo)
grug_mobs.names = dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo)
grug_mobs.pvp_garrison = dofile(paths.grug_mobs .. "/pvp_garrison.lua").new(
	dofile(wp40 .. "/r31_pvp_catalog.lua"), read_json(paths.grug_mobs .. "/data/pvp_names.json"), catalog)
do
	local existing = read_json(repo .. "/docs/planning/round28/items/existing.json")
	for name, row in pairs(existing.items) do
		core.registered_items[name] = {description = row.description, groups = row.groups}
	end
	for name, target in pairs(existing.aliases) do core.registered_aliases[name] = target end
	for name, row in pairs(existing.entities) do
		core.registered_entities[name] = {description = row.description, _grug_disposition = row.disposition}
	end
	for _, row in ipairs(read_json(paths.grug_mobs .. "/data/items.json")) do
		core.registered_items[row.id] = {description = row.name}
	end
	for _, row in ipairs(read_json(paths.grug_mobs .. "/data/subtypes.json")) do
		core.registered_entities["grug_mobs:" .. row.role] = {description = row.display,
			_grug_disposition = row.disposition}
	end
	local garrison = grug_mobs.pvp_garrison
	for _, faction in ipairs(FACTIONS) do
		for _, entity in ipairs({garrison.guard_entity(faction), garrison.captain_entity(faction),
				garrison.general_entity(faction), garrison.bodyguard_entity(faction)}) do
			core.registered_entities[entity] = core.registered_entities[entity] or {description = entity}
		end
	end
end
_G.grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "npcs", "use", "validate", "loader"}) do
	dofile(paths.grug_quests .. "/" .. file .. ".lua")
end
local Q = grug_quests
Q.resolve_npc_factions()
check(pcall(Q.bind_role_givers), "B the foreman roles bind")
do
	local ok, err = pcall(Q.validate_quest_data)
	check(ok, "B the load-time world checks pass: " .. tostring(err))
	ok, err = pcall(Q.validate_registry)
	check(ok, "B the registry checks pass: " .. tostring(err))
end

-- The foremen's titles.
do
	local foremen = 0
	for _, camp in ipairs(camps.camps) do
		local npc = Q.registered_npcs["r58_foreman_" .. camp.id]
		if check(npc ~= nil, "B the foreman of " .. camp.id .. " registered") then
			foremen = foremen + 1
			eq(npc.title, TITLES[camp.id] or "Foreman", "B the foreman of " .. camp.id .. " titled")
		end
	end
	eq(foremen, 36, "B 36 foremen")
	for id in pairs(TITLES) do
		check(Q.registered_npcs["r58_foreman_" .. id] ~= nil, "B the story's foreman of " .. id .. " exists")
	end
end

local meta = {}
local player = {}
function player:get_player_name() return "cap" end
function player:is_player() return true end
function player:get_hp() return 20 end
function player:get_pos() return {x = 0, y = 0, z = 0} end
function player:get_meta()
	return {get_string = function(_, k) return meta[k] or "" end, set_string = function(_, k, v) meta[k] = v end}
end
function player:get_inventory()
	return {get_list = function() return {} end, get_stack = function() return ItemStack("") end}
end
local function set_state(completed, active)
	meta["grug_quests:state"] = core.serialize({active = active or {}, completed = completed or {}, tracked = {},
		hud = true})
end
local function offers(npc)
	local row = Q.registered_npcs[npc]
	if not row or not grug_factions.serves(row.faction, player) then return {} end
	local out = {}
	for _, entry in ipairs(Q.npc_quests(player, npc)) do out[entry.id] = entry.status end
	return out
end
local all_capitals = {}
for _, faction in ipairs(FACTIONS) do
	for _, capital in ipairs(ORDER[faction]) do all_capitals[#all_capitals + 1] = capital end
end

-- The shared quests at their givers with nothing done (the player's
-- faction only), and the Alchemy quest at its level: locked a level below,
-- turned in only at the envoy it was taken from.
for id, spec in pairs(SHARED) do
	local def = Q.registered_quests[id]
	if check(def ~= nil, "B " .. id .. " registered") then
		local giving = {}
		for _, capital in ipairs(spec.capitals) do giving[capital] = true end
		for _, faction in ipairs(FACTIONS) do
			player_faction = faction
			for _, level in ipairs({def.min_level - 1, def.min_level}) do
				player_level = level
				set_state()
				for _, capital in ipairs(all_capitals) do
					local mine = giving[capital] and RACE_FACTION[CAPITAL[capital].race] == faction
					local want = mine and (level == def.min_level and "available" or "locked") or nil
					eq(offers(spec.giver(capital))[id], want, ("B %s at %d from %s's giver (%s)"):format(id, level,
						capital, faction))
				end
			end
		end
	end
end
do
	for _, faction in ipairs(FACTIONS) do
		player_faction, player_level = faction, 20
		for _, capital in ipairs(ORDER[faction]) do
			set_state()
			check(Q.accept(player, ALCHEMY, envoy(capital)), "B the Alchemy quest accepted at " .. capital)
			for _, other in ipairs(ORDER[faction]) do
				local status = offers(envoy(other))[ALCHEMY]
				if other == capital then
					eq(status, "active", "B the Alchemy quest from " .. capital .. " is active at its envoy")
				else
					eq(status, nil, ("B the Alchemy quest from %s is not listed at %s's envoy"):format(capital, other))
				end
			end
			local npc
			for _, entry in ipairs(Q.journal(player).quests) do
				if entry.id == ALCHEMY then npc = entry.npc end
			end
			eq(npc, envoy(capital), "B the Alchemy quest from " .. capital .. " returns to its envoy")
		end
	end
end

-- T3: hidden at Ossa until its prerequisites are done; then at 29.
do
	player_faction = "throng"
	local ossa, iven = envoy("nhal_veyr"), leader("nhal_veyr")
	local all = {[t2a] = true, ossuary_rubbings_03 = true, nhal_veyr_vigil_03 = true}
	for missing in pairs(all) do
		local done = {}
		for id in pairs(all) do if id ~= missing then done[id] = true end end
		player_level = 29
		set_state(done)
		eq(offers(ossa)[T3], nil, "B T3 hidden at Ossa without " .. missing)
	end
	player_level = 28
	set_state(all)
	eq(offers(ossa)[T3], "locked", "B T3 locked at 28 with its prerequisites done")
	player_level = 29
	set_state(all)
	eq(offers(ossa)[T3], "available", "B T3 offered at Ossa at 29")
	player_faction = "accord"
	eq(offers(ossa)[T3], nil, "B T3 is never offered to The Accord")
	player_faction = "throng"
	check(Q.accept(player, T3, ossa), "B T3 accepted at Ossa")
	local needs = Q.use_needs(player)
	eq(#needs, 1, "B T3 needs one use")
	local need = needs[1] or {}
	eq(need.place, T3_PLACE, "B T3's use is at the public register")
	eq(need.object, "claim_notice", "B T3's object")
	local place, reason = Q.use_place(T3_PLACE)
	if check(place ~= nil, "B " .. T3_PLACE .. " resolves: " .. tostring(reason)) then
		eq(place.name, "Nhal Veyr", "B the public register is named after Nhal Veyr")
		eq(place.town, true, "B ... a town place")
	end
	eq(offers(iven)[T3], "active", "B T3 not ready before the use")
	check(Q.credit_use(player, Q.use_key(need)), "B T3's use credits")
	eq(offers(iven)[T3], "ready", "B T3 is ready at Iven after the use")
	eq(offers(ossa)[T3], nil, "B T3 is not turned in at Ossa")
end

------------------------------------------------------------------------------
-- W. Seed 42's chunk at the public register.
------------------------------------------------------------------------------
do
	local place = Q.use_place(T3_PLACE)
	if place then
		local p = place.pos
		local minp = {x = RT.origin(p.x), y = RT.origin(p.y), z = RT.origin(p.z)}
		local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
		local vm = RT.new_vm(minp)
		local plan, generation = RT.built.session.plan_slice(minp, maxp)
		RT.built.writer.apply(vm, minp, maxp, plan, generation)
		local data = vm.written.data or vm.native.data
		local function name_at(x, y, z)
			local i = (z - (minp.z - 16)) * 12544 + (y - (minp.y - 16)) * 112 + (x - (minp.x - 16)) + 1
			return RT.fake.get_name_from_content_id(data[i])
		end
		local below, cell, above = name_at(p.x, p.y - 1, p.z), name_at(p.x, p.y, p.z), name_at(p.x, p.y + 1, p.z)
		eq(cell, "air", "W " .. T3_PLACE .. " cell at " .. p.x .. "," .. p.y .. "," .. p.z)
		eq(above, "air", "W " .. T3_PLACE .. " headroom")
		local def = RT.fake.registered_nodes[below]
		check(def and def.walkable ~= false and def.liquidtype ~= "source", "W " .. T3_PLACE ..
			" stands on walkable ground: " .. tostring(below))
	end
end

------------------------------------------------------------------------------
-- V. The design validator.
------------------------------------------------------------------------------
do
	local out = run("python3 " .. repo .. "/tools/r28_design/validate.py --game")
	check(out:find("validate: 0 error(s)", 1, true) ~= nil, "V validate.py --game: 0 errors: " ..
		(out:match("validate: [^\n]*") or out))
end
_G.grug_core = saved_grug_core or _G.grug_core

if failures > 0 then
	error(("R60 CAPITALS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
end
print(("R60 CAPITALS PORTABLE PASS checks=%d"):format(checks))
