-- Round 29 Lane Q1 portable test: placeholders in quest titles and texts,
-- the compass-word rule and quest copper. Loads the REAL grug_quests files
-- under a minimal `core` stub (the harness of tools/r28_q0) and checks:
--   1. the parts: placeholder syntax, compass words (whole words only, any
--      case and hyphenation), the sentence-start capital, quest copper;
--   2. the fixture file: titles filled at load ({name:...} also in another
--      quest's requirements), texts filled on first display through the real
--      spawn_regions_core.describe over a small region map (giver, named
--      place, zone), each phrase once per quest and form (cached); "from
--      here" only in the giver's dialogue, elsewhere from the giver's
--      settlement; copper computed when omitted;
--   3. a target without a phrase on this world falls back to the zone or the
--      place, without a direction;
--   4. load-time validation: one mistake per case, refused with its code;
--      "from here" on an open kind is a warning;
--   5. the shipped quest files carry no fixed compass word.
--
-- Usage (repo root): luajit tools/r29_q1/portable_test.lua
local json = dofile("tools/r28_b4_quests/json.lua")
local FIXTURE = "tools/r29_q1/fixture"
-- The Q0 fixture's spawn recipe and catalogue: Dawnmere with the open kinds
-- home_fields, woods and borderlands, the bandit camp and its chief.
local MOBS = "tools/r28_q0/fixture/grug_mobs"

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
		label .. " (missing " .. ("%q"):format(part) .. " in " .. ("%q"):format(tostring(text)) .. ")")
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

local function read_json(path)
	local handle = io.open(path)
	if not handle then return nil end
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end

------------------------------------------------------------------------------
-- Engine and game surface (only what grug_quests touches here).
------------------------------------------------------------------------------
function ItemStack(item)
	local name, count = "", 0
	if type(item) == "string" then
		local n, c = item:match("^(%S*)%s*(%d*)")
		name, count = n, tonumber(c) or (n == "" and 0 or 1)
	end
	local stack = {}
	function stack:get_name() return count > 0 and name or "" end
	function stack:get_count() return name ~= "" and count or 0 end
	function stack:is_empty() return name == "" or count <= 0 end
	return stack
end

local mod_paths, shown, pages, logged = {}, {}, {}, {}
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	get_modpath = function(name) return mod_paths[name] end,
	get_current_modname = function() return "grug_quests" end,
	get_dir_list = function(path)
		local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
		local out = {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = function(value) return value end,
	deserialize = function(value) return value ~= "" and deep_copy(value) or nil end,
	get_item_group = function() return 0 end,
	formspec_escape = function(text) return text end,
	show_formspec = function(_, _, form) shown[#shown + 1] = form end,
	log = function(level, message) logged[#logged + 1] = level .. ": " .. message end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {distance = function() return 1 end}
-- The two givers' quest sockets (sockets exist before any terrain).
local SOCKETS = {dawnmere = {{id = "hall_quest", role = "quest", pos = {x = 0, y = 40, z = -2550}},
	{id = "quest_cook", role = "quest", pos = {x = 120, y = 40, z = -2560}}}}
grug_core = {register_tag_visibility = function() end,
	hud_layout = {side_text_width = function() return 38 end},
	settlement_sockets_at = function(key) return deep_copy(SOCKETS[key] or {}) end}
dofile("mods/CORE/grug_core/item_names.lua")
grug_xp = {get_level = function() return 60 end, register_on_level_change = function() end,
	quest_reward = function(level, weight) return weight * 10 * level end}
grug_money = {format = function(copper) return copper .. " copper" end}
grug_factions = {get_faction = function() return "accord" end,
	display_name = function(id) return "The " .. id end}
-- Round 31: which NPCs serve whom (the real rule on the fake faction table).
dofile("mods/PLAYER/grug_factions/service.lua")
grug_classes = {get_race = function() return "human" end}
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
sfinv = {register_page = function(name, def) pages[name] = def end,
	make_formspec = function(_, _, content) return content end, get_page = function() return "" end,
	pages = pages, pages_unordered = {}}

------------------------------------------------------------------------------
-- grug_mobs.spawn_regions over the Q0 recipe, parsed by the real core, and a
-- small region map for describe: Dawnmere's land around (0, -2550), each
-- kind's largest patch, the camp and the chief at fixed spots.
------------------------------------------------------------------------------
local CORE = dofile("mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local catalogue = {}
for _, row in ipairs(read_json(MOBS .. "/data/subtypes.json")) do catalogue[row.role] = row end
-- The leader's display name in its zone (catalogue display_by_zone).
catalogue.confused_bandit_chief.display = "Confused Bandit Chief"
catalogue.confused_bandit_chief.display_by_zone = {elandor_dawnmere_fields = "Chief Crumb"}
local recipe = CORE.parse_recipe("elandor_dawnmere_fields",
	read_json(MOBS .. "/data/zones/elandor_dawnmere_fields.spawns.json").recipe, {
		band = {1, 10},
		pois = function() return {} end,
		role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
		leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
	})
local leaders = {}
for _, leader in ipairs(recipe.leaders) do
	leaders[leader.role] = {zone = "elandor_dawnmere_fields", level = leader.level, respawn = leader.respawn}
end
local map = {zone = "elandor_dawnmere_fields", order = {},
	leaders = {{role = "confused_bandit_chief", x = 260, z = -2320}},
	camps = {{id = "bandit_camp", x = 250, z = -2330}},
	by_kind = {
		home_fields = {{x = 300, z = -2700, size = 3}, {x = 0, z = -2500, size = 10}},
		woods = {{x = -250, z = -2400, size = 8}},
		borderlands = {{x = 200, z = -2350, size = 6}},
	}}
for x = -400, 400, 32 do
	for z = -2800, -2300, 32 do map.order[#map.order + 1] = {x = x, z = z} end
end
local PLACES = {highcourt = {x = 0, z = -1500, name = "Highcourt"}, dawnmere = {x = 0, z = -2550, name = "Dawnmere"}}
local describe_calls, describe_broken = 0, false
local regions = {
	get_area = function(zone, id)
		return zone == "elandor_dawnmere_fields" and (recipe.kind_by_id[id] or recipe.camp_by_id[id]) or nil
	end,
	area_roles = function(_, id)
		local unit = recipe.kind_by_id[id] or recipe.camp_by_id[id]
		return unit and deep_copy(unit.roles) or nil
	end,
	zone_area_ids = function(zone)
		local out = {}
		if zone ~= "elandor_dawnmere_fields" then return out end
		for _, kind in ipairs(recipe.kinds) do out[#out + 1] = kind.id end
		for _, camp in ipairs(recipe.camps) do out[#out + 1] = camp.id end
		return out
	end,
	leader = function(role) return leaders[role] end,
	place = function(ref) return PLACES[ref] end,
	describe = function(zone, target, mode, ref)
		describe_calls = describe_calls + 1
		if describe_broken then return nil, "no region map" end
		if mode == "of" then ref = PLACES[ref] end
		return CORE.describe(map, target, mode, ref, "Dawnmere Fields")
	end,
}
grug_mobs = {
	register_on_eligible_kill = function() end,
	register_participant_drop_hook = function() end,
	disposition = function(name) return name == "grug_mobs:wild_turkey" and "critter" or "aggressive" end,
	subtype = function(role) return catalogue[role] end,
	spawn_regions = regions,
}
grug_zones = {get = function(zone)
	if zone == "elandor_dawnmere_fields" then
		return {level_min = 1, level_max = 10, display_name = "Dawnmere Fields"}
	end
end}
for role in pairs(catalogue) do core.registered_entities["grug_mobs:" .. role] = {description = role} end
core.registered_items["default:cobble"] = {description = "Cobblestone"}

local BASE = "mods/PLAYER/grug_quests/"
local function load_quests(quest_root)
	grug_quests = {}
	mod_paths.grug_quests, mod_paths.grug_mobs = quest_root, MOBS
	for _, file in ipairs({"registry", "state", "labels", "npc", "npcs", "validate", "loader", "ui", "hud"}) do
		dofile(BASE .. file .. ".lua")
	end
	return grug_quests
end

------------------------------------------------------------------------------
-- 1. The parts.
------------------------------------------------------------------------------
grug_quests = {}
dofile(BASE .. "registry.lua")
dofile(BASE .. "labels.lua")
local P = grug_quests.placeholders
local function scan(text)
	local found, errors = P.scan(text)
	local kinds = {}
	for _, p in ipairs(found) do kinds[#kinds + 1] = p.kind .. "(" .. table.concat(p.args, ",") .. ")" end
	return table.concat(kinds, " "), #errors
end
local kinds, errors = scan("Go {dir_from_giver:bandit_camp}, past {dir_of:highcourt:elandor_whitebridge_shire/woods}" ..
	" and {zone_area:woods} to {name:confused_bandit_chief}.")
eq(kinds, "dir_from_giver(bandit_camp) dir_of(highcourt,elandor_whitebridge_shire/woods) zone_area(woods) " ..
	"name(confused_bandit_chief)", "the four placeholders and their arguments")
eq(errors, 0, "a well-formed text has no syntax error")
for _, bad in ipairs({"{direction:woods}", "{name}", "{name:a:b}", "{dir_of:woods}", "{name:Woods}",
		"{name:woods", "name:woods}", "{name:{woods}}", "{}", "{dir_of:zone/place:woods}"}) do
	local _, n = scan("Text " .. bad .. " here.")
	check(n > 0, "syntax error found in " .. bad)
end
local function compass(text) return table.concat(P.compass_words(text), ",") end
eq(compass("Head north, then South-East, the southeastern ford, Westward and north's fence; NORTHWEST."),
	"north,South,East,southeastern,Westward,north,NORTHWEST", "compass words in any case and hyphenation")
eq(compass("the northbound road, the southernmost farm, Easterners, a westerner, Northmost"),
	"northbound,southernmost,Easterners,westerner,Northmost", "the -bound, -most and -erner(s) forms")
eq(compass("Northfold, Westbrook, Eastmarch, Southwatch, beast, Easter, Westerling"), "",
	"names and words that only contain a compass word pass")
eq(compass("Wolves roam {dir_from_giver:woods}; {zone_area:woods} too."), "", "placeholders are not checked as words")
local filled = P.fill("{zone_area:x} lies there. Then {zone_area:x}! {zone_area:x}? \"{zone_area:x}\" and\n{zone_area:x}",
	function() return "in the east" end)
eq(filled, "In the east lies there. Then in the east! In the east? \"in the east\" and\nIn the east",
	"a fill that starts the text or a sentence starts with a capital")
eq(P.fill("Keep {name:x} as written.", function() return nil end), "Keep {name:x} as written.",
	"an unresolved placeholder stays as written")
eq(grug_quests.quest_copper(2, 3), 6, "T1 3-KE hunt: 6c (economy plan section 4)")
eq(grug_quests.quest_copper(25, 5), 64, "T3 5-KE task: 64c")
eq(grug_quests.quest_copper(45, 3), 240, "T5 3-KE task: 240c")
eq(grug_quests.quest_copper(60, 3), 600, "T6 3-KE task: 6s")
eq(grug_quests.quest_copper(10, 2.25), 5, "4.5c rounds half up (level 10 is T1)")
eq(grug_quests.quest_copper(11, 1), 5, "level 11 is T2: 0.08 x 65 = 5.2c")
eq(grug_quests.quest_copper(1, 0.1), 1, "at least 1c for a weight above 0")
eq(grug_quests.quest_copper(60, 0), 0, "weight 0: no copper")

------------------------------------------------------------------------------
-- 2. The fixture file.
------------------------------------------------------------------------------
local Q = load_quests(FIXTURE .. "/grug_quests")
local ok, err = pcall(Q.validate_quest_data)
check(ok, "fixture passes the world checks: " .. tostring(err))
eq(describe_calls, 0, "loading builds no direction (no region map at load)")
local camp, chief = Q.registered_quests.q1_camp, Q.registered_quests.q1_chief
eq(camp.title, "Raid on the Bandit Camp", "{name:camp} in a title, filled at load")
eq(chief.title, "Chief Crumb", "{name:leader}: the leader's display name in its zone")
has(chief.description, "Complete: Raid on the Bandit Camp", "requirements list the filled title")
eq(camp.rewards.copper, 8, "copper omitted: 0.08 x 25 x 4 = 8c")
eq(chief.rewards.copper, 7, "copper written: kept")
eq(Q.registered_quests.q1_lost.rewards.copper, 5, "copper omitted: 4.5c rounds up to 5c")
eq(Q.registered_quests.q1_stones.rewards.copper, 13, "copper omitted at level 11 (T2): 13c")

local function phrase(target, mode, ref)
	return CORE.describe(map, target, mode, mode == "of" and PLACES[ref] or ref, "Dawnmere Fields").phrase
end
local elder = SOCKETS.dawnmere[1].pos
local camp_text = Q.quest_text(camp, true)
eq(phrase("bandit_camp", "from", elder), "northeast from here", "the camp lies northeast of the elder")
has(camp_text, "Bandits hold a camp northeast from here. Drive them out.", "{dir_from_giver:camp}")
local chief_text = Q.quest_text(chief, true)
local from_chief = phrase("confused_bandit_chief", "from", elder)
has(chief_text, from_chief:sub(1, 1):upper() .. from_chief:sub(2) .. " stands Chief Crumb.",
	"{dir_from_giver:leader} at the start of the text, capitalised")
has(chief_text, "The woods lie " .. phrase("woods", "zone") .. ", the borderlands " ..
	phrase("borderlands", "of", "highcourt") .. ".", "{zone_area:kind} and {dir_of:place:kind}")
eq(phrase("borderlands", "of", "highcourt"), "south of Highcourt", "the borderlands lie south of Highcourt")
eq(phrase("woods", "zone"), "in the northwest of Dawnmere Fields", "the woods in the zone's northwest")
has(chief_text, "\n\nRequirements: Minimum level: 9; Complete: Raid on the Bandit Camp.",
	"the requirements follow the filled text")
local lost_text = Q.quest_text(Q.registered_quests.q1_lost, true)
has(lost_text, "Boars raid in the heart of Dawnmere Fields. Look near Dawnmere as well.",
	"a kind's largest patch: the heart of the zone, near the start")
eq(phrase("home_fields", "of", "dawnmere"), "near Dawnmere", "near a place within 80 nodes")
eq(Q.quest_text(Q.registered_quests.q1_stones), Q.registered_quests.q1_stones.description,
	"a text without placeholders is the description")
local calls = describe_calls
eq(calls, 6, "one describe per direction placeholder")
Q.quest_text(camp, true); Q.quest_text(chief, true); Q.quest_text(Q.registered_quests.q1_lost, true)
eq(describe_calls, calls, "a second display reads the cache")
-- Away from the giver (quest log, another NPC) "from here" would be false:
-- it reads from the giver's settlement.
eq(phrase("bandit_camp", "of", "dawnmere"), "northeast of Dawnmere", "the camp lies northeast of Dawnmere")
has(Q.quest_text(camp), "Bandits hold a camp northeast of Dawnmere. Drive them out.",
	"{dir_from_giver:camp} away from the giver")
local of_chief = phrase("confused_bandit_chief", "of", "dawnmere")
has(Q.quest_text(chief), of_chief:sub(1, 1):upper() .. of_chief:sub(2) .. " stands Chief Crumb.",
	"{dir_from_giver:leader} away from the giver, capitalised")
check(not Q.quest_text(chief):find("from here", 1, true), "no \"from here\" away from the giver")
calls = describe_calls
Q.quest_text(camp); Q.quest_text(chief)
eq(describe_calls, calls, "the form away from the giver is cached too")

-- The dialogue and the quest log show the filled text and title.
local meta, main = {}, {}
for i = 1, 8 do main[i] = ItemStack("") end
local player = {}
function player:get_player_name() return "ann" end
function player:is_player() return true end
function player:get_hp() return 20 end
function player:get_pos() return {x = 0, y = 0, z = 0} end
function player:get_meta()
	return {get_string = function(_, k) return meta[k] or "" end, set_string = function(_, k, v) meta[k] = v end}
end
function player:get_inventory()
	return {get_list = function(_, list) return list == "main" and main or nil end}
end
local entity = {_grug_start = "dawnmere", _grug_socket = "hall_quest", object = {
	is_valid = function() return true end, get_pos = function() return {x = 0, y = 0, z = 0} end}}
shown = {}
Q.open_npc(player, entity, 1)
has(shown[1], "Raid on the Bandit Camp (available)", "offer list: the filled title")
has(shown[1], "Bandits hold a camp northeast from here.", "offer dialogue: the filled text")
has(shown[1], "Rewards: 360 XP, 8 copper", "offer dialogue: the computed copper")
check(Q.accept(player, "q1_camp"), "accept q1_camp")
local log = pages["grug_quests:quests"].get(nil, player, {grug_quest_selected = "q1_camp"})
has(log, "Raid on the Bandit Camp", "quest log: the filled title")
has(log, "Bandits hold a camp northeast of Dawnmere.", "quest log: the filled text, from the giver's settlement")
check(not log:find("{", 1, true), "quest log: no placeholder left")

------------------------------------------------------------------------------
-- 3. No phrase on this world: the zone or the place, without a direction.
------------------------------------------------------------------------------
Q = load_quests(FIXTURE .. "/grug_quests")
describe_broken, logged = true, {}
eq(Q.quest_text(Q.registered_quests.q1_camp):match("^[^\n]*"), "Bandits hold a camp in Dawnmere Fields. Drive them out.",
	"from here without a phrase: the zone")
has(Q.quest_text(Q.registered_quests.q1_chief), ", the borderlands around Highcourt.", "of a place without a phrase: around it")
eq(Q.quest_text(Q.registered_quests.q1_camp, true):match("^[^\n]*"), "Bandits hold a camp in Dawnmere Fields. Drive them out.",
	"from here at the giver without a phrase: the zone")
check(#logged > 0 and logged[1]:find("has no direction on this world", 1, true) ~= nil, "the fallback is logged")
describe_broken = false

------------------------------------------------------------------------------
-- 4. Load-time validation.
------------------------------------------------------------------------------
local base = read_json(FIXTURE .. "/grug_quests/data/zones/elandor_dawnmere_fields.quests.json")
local function quest(data, id)
	for _, row in ipairs(data.quests) do if row.id == id then return row end end
end
-- Runs the structure and world checks on one changed copy; returns the
-- error text and the warnings.
local function findings(change)
	local data = deep_copy(base)
	change(data)
	local files = {{name = "elandor_dawnmere_fields.quests.json", zone = "elandor_dawnmere_fields", data = data}}
	local V = Q.validate
	local errors = V.structure(files, Q.registered_npcs)
	local warnings = {}
	if #errors == 0 then
		local world_errors
		world_errors, warnings = V.world(files, {
			entity = function(name) return core.registered_entities[name] end,
			disposition = function(name) return grug_mobs.disposition(name) end,
			role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
			leader = function(role) return leaders[role] end,
			zone_band = function() return {1, 10} end,
			area = function(_, id)
				local unit = regions.get_area("elandor_dawnmere_fields", id)
				return unit and {levels = unit.levels, levels_by_role = unit.levels_by_role,
					roles = regions.area_roles(nil, id)}
			end,
			zone_areas = function() return {} end,
			item = function(name) return core.registered_items[name] ~= nil end,
			group = function() return true end,
			placeholder_target = Q.placeholder_target,
			place = function(ref) return regions.place(ref) end,
		})
		errors = world_errors
	end
	return table.concat(errors, "\n"), table.concat(warnings, "\n")
end
local clean, clean_warnings = findings(function() end)
eq(clean, "", "the fixture as shipped: no error")
eq(clean_warnings, "", "the fixture as shipped: no warning")
for _, case in ipairs({
	{"E-placeholder-target", "unknown target", function(d) quest(d, "q1_camp").text = "Camp {dir_from_giver:castle}. Go." end},
	{"E-placeholder-target", "target of another zone without its kind",
		function(d) quest(d, "q1_camp").text = "{zone_area:elandor_goldmead_vale/woods}. Go." end},
	{"E-placeholder-target", "unknown name in a title", function(d) quest(d, "q1_camp").title = "The {name:castle}" end},
	{"E-placeholder-place", "unknown place", function(d) quest(d, "q1_camp").text = "{dir_of:rivendell:woods}. Go." end},
	{"E-placeholder]", "direction in a title", function(d) quest(d, "q1_camp").title = "Camp {dir_from_giver:bandit_camp}" end},
	{"E-placeholder]", "unknown placeholder", function(d) quest(d, "q1_camp").text = "Go {where:bandit_camp}. Now." end},
	{"E-placeholder]", "unmatched brace", function(d) quest(d, "q1_camp").text = "Go {name:bandit_camp. Now." end},
	{"E-compass", "compass word in a text", function(d) quest(d, "q1_camp").text = "Bandits camp to the north-east. Go." end},
	{"E-compass", "compass word in a title", function(d) quest(d, "q1_camp").title = "The Southern Camp" end},
	{"E-compass", "a -bound compass word", function(d) quest(d, "q1_camp").text = "Take the northbound road. Go." end},
}) do
	local found = findings(case[3])
	has(found, "[" .. case[1]:gsub("%]$", "") .. "]", case[2] .. " is refused")
	has(found, "quest q1_camp", case[2] .. ": the message names the quest")
end
local _, spread = findings(function(d) quest(d, "q1_lost").text = "Boars raid {dir_from_giver:home_fields}. Go." end)
has(spread, "[W-placeholder-spread]", "from here on an open kind is a warning")
eq((findings(function(d) quest(d, "q1_lost").text = "Boars raid {dir_from_giver:home_fields}. Go." end)), "",
	"... and not an error")
local placeholder_errors = findings(function(d) quest(d, "q1_camp").text = "{dir_of:dawnmere:bandit_camp} it is. Go." end)
eq(placeholder_errors, "", "a place by settlement key")

------------------------------------------------------------------------------
-- 5. The shipped quest files: no fixed compass word.
------------------------------------------------------------------------------
local shipped, quests_seen = {}, 0
for _, name in ipairs(core.get_dir_list("mods/PLAYER/grug_quests/data/zones")) do
	for _, row in ipairs(read_json("mods/PLAYER/grug_quests/data/zones/" .. name).quests or {}) do
		quests_seen = quests_seen + 1
		for _, key in ipairs({"title", "text"}) do
			for _, word in ipairs(P.compass_words(row[key])) do shipped[#shipped + 1] = row.id .. ": " .. word end
		end
	end
end
check(quests_seen >= 240, "the shipped quests were read (" .. quests_seen .. ")")
eq(table.concat(shipped, ", "), "", "no shipped quest text carries a fixed compass word")

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print(("R29 Q1 PORTABLE PASS checks=%d"):format(checks))
