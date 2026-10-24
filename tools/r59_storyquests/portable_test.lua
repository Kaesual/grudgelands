-- Round 59 lane STORYQUESTS portable fixture (LuaJIT): chapter 1's story
-- quests in the six capitals (quests.md "Chapter 1 in the capitals").
--
--   luajit tools/r59_storyquests/portable_test.lua [REPO]
--
-- S. The files: build_structure.py wrote the structure that ships (its
--    --check compares everything but the texts, which are BANDTEXT's, each a
--    real text with no "[PH]" left); the four story quests
--    (A1 story_accord_01, A2 story_accord_02, T1 story_throng_01, T2
--    story_throng_02) live in their first variant's capital file (Highcourt,
--    Gor Drazhak); A1/T1 at 19 with no prerequisite, a travel quest from
--    each capital's envoy to the guild leader of the same capital; A2/T2 at
--    20 requiring A1/T1, given and turned in by each capital's leader, one
--    use objective with the same object and label everywhere and only the
--    place per variant, the capital's town place; the six capital files
--    unflagged; each envoy on the lines `envoy` and `front`, each leader the
--    one giver of a hub of its own capital; the band departures still travel
--    to the envoys.
-- P. The six town places: each a `quest_place` socket of a service plot
--    every world builds (tools/r59_qsys3/socket_places.lua); in the plot as
--    the mapgen builds it the socket's cell and the one above are air over
--    a walkable node that is not the path's, and no door, no other socket
--    and no cell of the doorstep path lies within 2 nodes.
-- B. The real loader over seed 42's settlement sockets (the capitals'
--    blueprints as the world registers them) and the real spawn recipes,
--    names and items: the load-time world checks pass; A1/T1 offered at 19
--    by the faction's three envoys with nothing done (locked at 18, never by
--    the other faction's), accepted at an envoy it is ready only at that
--    capital's leader; A2/T2 hidden at the leaders until A1/T1 is done, then
--    offered by the faction's three leaders, its place this capital's town
--    place (named after the capital), ready after the use and turned in only
--    there; the guild reports still turn in at the leaders.
-- W. On seed 42's own chunks (tools/seed_fleet's runtime: the real plan and
--    writer): each town place's cell holds air over walkable ground, as the
--    quest object needs (use.lua town_stand).
-- V. tools/r28_design/validate.py --game: 0 errors.
-- Prints "R59 STORYQUESTS PORTABLE PASS checks=<n>" or raises.

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
local function read_json(path)
	local handle = io.open(path, "r")
	if not handle then return nil end
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end
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
	highcourt = {zone = "elandor_highcourt", race = "human", label = "Highcourt",
		plot = "market_store", socket = "market_store_dispatch_yard"},
	dur_brannoc = {zone = "elandor_dur_brannoc", race = "dwarf", label = "Dur Brannoc",
		plot = "forge_ore_yard", socket = "forge_ore_yard_loading_apron"},
	lethariel = {zone = "elandor_lethariel", race = "elf", label = "Lethariel",
		plot = "market_bowyer", socket = "market_bowyer_timber_check"},
	gor_drazhak = {zone = "kragmar_gor_drazhak", race = "orc", label = "Gor Drazhak",
		plot = "warren_cook_court", socket = "warren_cook_court_water_depot"},
	kezamba = {zone = "kragmar_kezamba", race = "troll", label = "Kezamba",
		plot = "shore_store", socket = "shore_store_witness_landing"},
	nhal_veyr = {zone = "kragmar_nhal_veyr", race = "undead", label = "Nhal Veyr",
		plot = "homes_mourners_hall", socket = "homes_mourners_hall_receiving_court"},
}
local RACE_FACTION = {human = "accord", dwarf = "accord", elf = "accord",
	undead = "throng", orc = "throng", troll = "throng"}
local OBJECT = {accord = {"dispatch_record", "Secure the dispatch record"},
	throng = {"witness_record", "Secure the witness record"}}
-- The band departures (BANDQUESTS' files; the ids stay): zone -> the
-- capital whose envoy they travel to.
local DEPARTURES = {copperfell_departure = "dur_brannoc", goldmead_departure = "highcourt",
	starbough_departure = "lethariel", mournfen_departure = "nhal_veyr",
	redtusk_departure = "gor_drazhak", raincall_departure = "kezamba"}
local function envoy(capital) return "r20_" .. CAPITAL[capital].race .. "_capital_envoy" end
local function leader(capital) return "r58_guild_leader_" .. capital end
-- A real text (Round 59 BANDTEXT's): a non-empty string with no placeholder
-- mark left.
local function real_text(value)
	return type(value) == "string" and value:find("%S") ~= nil and value:find("[PH]", 1, true) == nil
end
local function ref(capital)
	local c = CAPITAL[capital]
	return ("socket:%s/%s/%s"):format(capital, c.plot, c.socket)
end

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
	local out = run("python3 " .. repo .. "/tools/r59_storyquests/build_structure.py --check")
	check(out:find("0 of 6 capital files differ", 1, true) ~= nil, "S build_structure.py wrote what ships: " .. out)
end
for capital, c in pairs(CAPITAL) do
	local data = file_data[c.zone]
	if check(data ~= nil, "S the file of " .. capital) then
		-- Round 60 CAPITALS flagged the six files reworked (chapter 1 kept).
		eq(data.reworked, true, "S " .. c.zone .. " is reworked (Round 60)")
		local lines_of, hub_of = {}, {}
		for _, hub in ipairs(data.hubs) do
			for _, giver in ipairs(hub.givers) do
				lines_of[giver.npc] = table.concat(giver.lines, ",")
				hub_of[giver.npc] = hub
			end
		end
		eq(lines_of[envoy(capital)], "envoy,front", "S " .. capital .. "'s envoy has the lines envoy and front")
		local hub = hub_of[leader(capital)]
		if check(hub ~= nil, "S " .. capital .. "'s leader is a hub giver") then
			eq(hub.anchor, "zone", "S " .. capital .. "'s leader hub is anchored at its zone (as the foremen's)")
			eq(#hub.givers, 1, "S " .. capital .. "'s leader hub has one giver")
			eq(lines_of[leader(capital)], "guild", "S " .. capital .. "'s leader has the line guild")
		end
		for _, q in ipairs(data.quests) do
			if q.giver == envoy(capital) then
				eq(q.line, "envoy", "S " .. q.id .. " is on the envoy's renamed line")
			end
		end
	end
end
for _, faction in ipairs(FACTIONS) do
	local first = ORDER[faction][1]
	local one, two = quests["story_" .. faction .. "_01"], quests["story_" .. faction .. "_02"]
	if check(one ~= nil and two ~= nil, "S the " .. faction .. " story quests ship") then
		for _, q in ipairs({one, two}) do
			eq(file_of[q.id], CAPITAL[first].zone, "S " .. q.id .. " lives in its first variant's file")
			eq(q.story, true, "S " .. q.id .. " is a story quest")
			eq(#q.variants, 3, "S " .. q.id .. " has a variant per capital")
			eq(#q.objectives, 1, "S " .. q.id .. " has one objective")
			check(real_text(q.title) and real_text(q.text), "S " .. q.id .. " has a real title and text")
			check(q.completion == nil or real_text(q.completion), "S " .. q.id .. " a real completion text or none")
			check(q.rewards.choices == nil or #q.rewards.choices >= 2, "S " .. q.id .. " a real choice or none")
		end
		eq(one.min_level, 19, "S " .. one.id .. " opens at 19")
		eq(#(one.requires or {}), 0, "S " .. one.id .. " requires nothing")
		eq(one.line, "envoy", "S " .. one.id .. " is on the envoys' common line")
		eq(one.objectives[1].type, "talk", "S " .. one.id .. " is a travel quest")
		eq(two.min_level, 20, "S " .. two.id .. " opens at 20")
		eq(table.concat(two.requires or {}, ","), one.id, "S " .. two.id .. " requires " .. one.id)
		eq(two.line, "guild", "S " .. two.id .. " is on the leaders' line")
		local use = two.objectives[1]
		eq(use.type, "use", "S " .. two.id .. " is a use quest")
		eq(use.object, OBJECT[faction][1], "S " .. two.id .. " object")
		eq(use.label, OBJECT[faction][2], "S " .. two.id .. " label")
		for index, capital in ipairs(ORDER[faction]) do
			local v1, v2 = one.variants[index], two.variants[index]
			eq(v1.zone, CAPITAL[capital].zone, "S " .. one.id .. " variant " .. index)
			eq(table.concat(v1.givers, ","), envoy(capital), "S " .. one.id .. " given by " .. capital .. "'s envoy")
			eq(table.concat(v1.turnins or {}, ","), leader(capital), "S " .. one.id .. " turned in at " .. capital .. "'s leader")
			eq(((v1.objectives or {})[1] or {}).npc, leader(capital), "S " .. one.id .. " talks to " .. capital .. "'s leader")
			eq(v2.zone, CAPITAL[capital].zone, "S " .. two.id .. " variant " .. index)
			eq(table.concat(v2.givers, ","), leader(capital), "S " .. two.id .. " given by " .. capital .. "'s leader")
			eq(table.concat(v2.turnins or {}, ","), leader(capital), "S " .. two.id .. " turned in at " .. capital .. "'s leader")
			local o = (v2.objectives or {})[1] or {}
			eq(o.place, ref(capital), "S " .. two.id .. " " .. capital .. " place")
			check(o.object == nil and o.label == nil, "S " .. two.id .. " " .. capital .. " changes only the place")
			for _, v in ipairs({v1, v2}) do
				-- The structure gives every variant a text and a completion.
				check(real_text(v.text) and real_text(v.completion), "S " .. capital .. " variant texts are real")
			end
		end
	end
end
for id, capital in pairs(DEPARTURES) do
	local q = quests[id]
	if check(q ~= nil, "S " .. id .. " keeps its id") then
		eq(q.turnin, envoy(capital), "S " .. id .. " still leads to " .. capital .. "'s envoy")
	end
end

------------------------------------------------------------------------------
-- P. The six town places in their plots.
------------------------------------------------------------------------------
local places_tool = dofile(repo .. "/tools/r59_qsys3/socket_places.lua")
local capitals = {}
for capital in pairs(CAPITAL) do capitals[#capitals + 1] = capital end
table.sort(capitals)
local found = places_tool.sockets(repo, capitals)
local registry_nodes = read_json(repo .. "/tools/building_templates/nodes.json")
local function walkable(name)
	local def = registry_nodes.nodes[registry_nodes.aliases[name] or name]
	return def and def.walkable ~= false
end
rawset(_G, "core", rawget(_G, "core") or {})
for _, capital in ipairs(capitals) do
	local c = CAPITAL[capital]
	local id = c.plot .. "/" .. c.socket
	local socket
	for _, row in ipairs(found[capital].sockets) do
		if row.id == id then socket = row end
	end
	if check(socket ~= nil, "P " .. capital .. " has the socket " .. id) then
		eq(socket.role, "quest_place", "P " .. id .. " is a quest place")
		eq(socket.required, true, "P " .. id .. " stands in a plot every world builds")
		local kit = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_capital_blueprint.lua").kit(capital)
		local built
		for _, plot in ipairs(kit.plots) do
			if plot.id == c.plot then built = plot.build() end
		end
		local cells, path = {}, nil
		for _, cell in ipairs(built.cells) do cells[cell.x .. "," .. cell.y .. "," .. cell.z] = cell.name end
		local function at(x, y, z) return cells[x .. "," .. y .. "," .. z] end
		local own
		for _, row in ipairs(built.landmarks.sockets) do
			if c.plot .. "/" .. row.id == id then own = row end
		end
		local x, y, z = own.x, own.y or 1, own.z
		eq(at(x, y, z), "air", "P " .. id .. " its cell is air")
		eq(at(x, y + 1, z), "air", "P " .. id .. " the cell above is air")
		check(at(x, y - 1, z) ~= nil and walkable(at(x, y - 1, z)), "P " .. id .. " stands on walkable ground: " ..
			tostring(at(x, y - 1, z)))
		-- The doorstep path (the plot's path node in its gate columns, x
		-- -1..1, from the street edge in) is 2 nodes away or more, and the
		-- spot itself is not paved with it.
		path = at(0, 0, built.landmarks.plot.min.z + 1)
		check(at(x, y - 1, z) ~= path, "P " .. id .. " is not on the path node " .. tostring(path))
		for dz = -2, 2 do
			for dx = -2, 2 do
				check(math.abs(x + dx) > 1 or at(x + dx, y - 1, z + dz) ~= path,
					("P %s: no doorstep path cell at %+d,%+d"):format(id, dx, dz))
			end
		end
		for _, door in ipairs(built.landmarks.doors or {}) do
			check(math.abs(door.x - x) > 2 or math.abs(door.z - z) > 2, "P " .. id .. " is no doorstep")
		end
		for _, row in ipairs(built.landmarks.sockets) do
			if row ~= own then
				check(math.abs(row.x - x) > 2 or math.abs(row.z - z) > 2,
					"P " .. id .. " is clear of the socket " .. row.id)
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

-- A small engine under the quest code (tools/r58_guildquests' harness).
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

local meta = {}
local player = {}
function player:get_player_name() return "sq" end
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

for _, capital in ipairs(all_capitals) do
	check(Q.registered_npcs[envoy(capital)] ~= nil, "B " .. envoy(capital) .. " registered")
	check(Q.registered_npcs[leader(capital)] ~= nil, "B " .. leader(capital) .. " registered")
	local place, reason = Q.use_place(ref(capital))
	if check(place ~= nil, "B " .. ref(capital) .. " resolves: " .. tostring(reason)) then
		eq(place.name, CAPITAL[capital].label, "B " .. ref(capital) .. " is named after its capital")
		eq(place.town, true, "B " .. ref(capital) .. " is a town place")
	end
end

for _, faction in ipairs(FACTIONS) do
	local one, two = "story_" .. faction .. "_01", "story_" .. faction .. "_02"
	player_faction = faction
	-- A1/T1: every envoy of the faction at 19 with nothing done; locked at
	-- 18; no envoy of the other faction.
	for _, level in ipairs({18, 19}) do
		player_level = level
		set_state()
		for _, capital in ipairs(all_capitals) do
			local mine = RACE_FACTION[CAPITAL[capital].race] == faction
			local want = mine and (level == 19 and "available" or "locked") or nil
			eq(offers(envoy(capital))[one], want, ("B %s at %d from %s's envoy"):format(one, level, capital))
			eq(offers(leader(capital))[two], nil, ("B %s hidden at %s's leader before %s"):format(two, capital, one))
		end
	end
	player_level = 19
	for _, capital in ipairs(ORDER[faction]) do
		set_state()
		check(Q.accept(player, one, envoy(capital)), "B " .. one .. " accepted at " .. capital)
		for _, other in ipairs(ORDER[faction]) do
			eq(offers(leader(other))[one], other == capital and "ready" or nil,
				("B %s from %s is turned in at %s's leader"):format(one, capital, other))
		end
		local npc
		for _, entry in ipairs(Q.journal(player).quests) do
			if entry.id == one then npc = entry.npc end
		end
		eq(npc, leader(capital), "B " .. one .. " from " .. capital .. " returns to its leader")
	end
	-- A2/T2 after A1/T1: every leader of the faction, its own town place.
	player_level = 20
	for _, capital in ipairs(ORDER[faction]) do
		set_state({[one] = true})
		for _, other in ipairs(all_capitals) do
			local mine = RACE_FACTION[CAPITAL[other].race] == faction
			eq(offers(leader(other))[two], mine and "available" or nil,
				("B %s at %s's leader after %s"):format(two, other, one))
		end
		check(Q.accept(player, two, leader(capital)), "B " .. two .. " accepted at " .. capital)
		local needs = Q.use_needs(player)
		eq(#needs, 1, "B " .. two .. " from " .. capital .. " needs one use")
		local need = needs[1] or {}
		eq(need.place, ref(capital), "B " .. two .. " from " .. capital .. " uses its own town place")
		eq(need.object, OBJECT[faction][1], "B " .. two .. " object")
		eq(offers(leader(capital))[two], "active", "B " .. two .. " not ready before the use")
		check(Q.credit_use(player, Q.use_key(need)), "B " .. two .. " the use credits")
		for _, other in ipairs(ORDER[faction]) do
			eq(offers(leader(other))[two], other == capital and "ready" or nil,
				("B %s from %s is turned in at %s's leader"):format(two, capital, other))
		end
	end
end
-- The guild reports keep turning in at the leaders.
for _, faction in ipairs(FACTIONS) do
	player_faction, player_level = faction, 20
	local report = "guild_t2_report_" .. faction
	local def = Q.registered_quests[report]
	local done = {}
	for _, id in ipairs(def.prerequisites) do done[id] = true end
	for npc in pairs(def.giver_variant) do
		set_state(done)
		check(Q.accept(player, report, npc), "B " .. report .. " accepted at " .. npc)
		local ready = 0
		for _, capital in ipairs(all_capitals) do
			if offers(leader(capital))[report] == "ready" then ready = ready + 1 end
		end
		eq(ready, 1, "B " .. report .. " from " .. npc .. " is ready at one leader")
	end
end

------------------------------------------------------------------------------
-- W. Seed 42's chunks at the six town places.
------------------------------------------------------------------------------
for _, capital in ipairs(all_capitals) do
	local place = Q.use_place(ref(capital))
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
		eq(cell, "air", "W " .. ref(capital) .. " cell at " .. p.x .. "," .. p.y .. "," .. p.z)
		eq(above, "air", "W " .. ref(capital) .. " headroom")
		local def = RT.fake.registered_nodes[below]
		check(def and def.walkable ~= false and def.liquidtype ~= "source", "W " .. ref(capital) ..
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
	error(("R59 STORYQUESTS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
end
print(("R59 STORYQUESTS PORTABLE PASS checks=%d"):format(checks))
