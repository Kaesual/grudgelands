-- Round 31 Lane Q portable test (LuaJIT): the PvP POI quests
-- (round31-plan.md §1 Q, pvp-plan rulings 13-15 and 23, §5 lane Q).
--
--   luajit tools/r31_q/portable_test.lua [REPO]
--
--   C  credit: the REAL grug_quests (registry, state, labels, validate,
--      loader) over tools/r31_q/fixture: an Accord quest to kill Throng
--      Guards and the Throng Captain of one Battlegrounds camp counts a kill
--      only of that role carrying that camp's area tag (`_grug_area`, lane
--      G's "<zone>/<settlement key>"): not another camp's, not an untagged
--      town guard, not the other faction's garrison, never past the count;
--   V  the load checks on that fixture: clean as written; a quest naming its
--      own faction's camp (E-garrison-faction), a garrison role the camp has
--      not (E-role-not-in-area), a guard without an area (E-not-a-mob) and a
--      quest level the camp's band does not fit (E-level-fit) are refused;
--      the objective's level range is the camp's (lane Q0's display);
--   P  placeholders on a PvP POI: {name:...} is the POI's label (bare or
--      zone-qualified, a wrong zone refused), {dir_from_giver:...} and
--      {zone_area:...} point at the camp's anchor (spawn_regions_core's
--      describe on the anchor);
--   S  the shipped fortress quests (the two fortress zones' files): per
--      faction one quest per enemy Battlegrounds camp (8), each killing that
--      camp's guards (its garrison size) and its captain, area-limited to
--      that camp, at a reward level its band fits, given and turned in by a
--      fortress quest giver, a solo quest; 3-5 ordinary fortress quests; every quest of
--      the fortress givers from level 40; no objective names a player.
-- Prints "R31 Q PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg[1] or "."
local function path(p) return repo .. "/" .. p end
local json = dofile(path("tools/r28_b4_quests/json.lua"))

local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

local function read_json(p)
	local handle = assert(io.open(p, "rb"))
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end

------------------------------------------------------------------------------
-- Engine and game surface (only what grug_quests touches here).
------------------------------------------------------------------------------
function ItemStack(item)
	local stack = {}
	function stack:get_name() return type(item) == "string" and item or "" end
	function stack:get_count() return 0 end
	function stack:is_empty() return true end
	return stack
end

local mod_paths = {grug_quests = path("tools/r31_q/fixture/grug_quests"),
	grug_mapgen = path("mods/MAPGEN/grug_mapgen"), grug_mobs = path("mods/ENTITIES/grug_mobs")}
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	get_modpath = function(name) return mod_paths[name] end,
	get_current_modname = function() return "grug_quests" end,
	get_dir_list = function(dir)
		local handle = io.popen('ls "' .. dir .. '" 2>/dev/null')
		local out = {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = function(value) return value end,
	deserialize = function(value) return value ~= "" and deep_copy(value) or nil end,
	get_item_group = function() return 0 end,
	get_us_time = function() return 0 end,
	formspec_escape = function(text) return text end,
	log = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {distance = function() return 1 end}

-- The PvP POIs where the game has them: the catalogue rows on their source
-- anchors (r7_settlement.lua's roster), the fortress registered as its seat
-- race, its three quest sockets at the anchor.
local ROSTER = dofile(path("mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")).roster
local places = {}
for _, row in ipairs(ROSTER) do
	places[row.key] = {x = row.x, z = row.z, name = row.label}
	places[row.anchor_id] = places[row.key]
end
local CATALOG = dofile(path("mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua"))
local SEAT = CATALOG.SEAT_RACE
local function fortress_sockets(key)
	local p = places[key]
	if not p or not key:match("^pvp_fortress_") then return {} end
	local out = {}
	for _, role in ipairs({"warmaster", "drillmaster", "outrider"}) do
		out[#out + 1] = {id = "quest_" .. role, role = "quest", pos = {x = p.x, y = 10, z = p.z}}
	end
	return out
end
grug_core = {register_tag_visibility = function() end,
	settlement_socket_anchor = function(key) return places[key] end,
	settlement_sockets_at = fortress_sockets,
	settlement_socket_settlements = function()
		return {{key = "pvp_fortress_accord", race_id = SEAT.accord},
			{key = "pvp_fortress_throng", race_id = SEAT.throng}}
	end,
	opposing_faction = function(f) return f == "accord" and "throng" or "accord" end,
	feed_item = function() end,
	hud_layout = {side_text_width = function() return 38 end, QUEST_WRAP = 38, anchors = {quest_list = {}}}}
dofile(path("mods/CORE/grug_core/item_names.lua"))
grug_xp = {get_level = function() return 45 end, register_on_level_change = function() end,
	quest_reward = function(level, weight) return weight * level end, add_xp = function() end}
grug_money = {MAX = 1000000, get = function() return 0 end, add = function() end,
	format = function(copper) return copper .. "c" end}
local PLAYER_FACTION = "accord"
grug_factions = {get_faction = function() return PLAYER_FACTION end,
	display_name = function(id) return "The " .. id end,
	-- grug_factions.same_faction: both have a faction and it is the same.
	same_faction = function(_, object) return object._faction ~= nil and object._faction == PLAYER_FACTION end}
dofile(path("mods/PLAYER/grug_factions/service.lua"))
grug_classes = {registered_races = {human = {faction = "accord"}, dwarf = {faction = "accord"},
	elf = {faction = "accord"}, orc = {faction = "throng"}, troll = {faction = "throng"},
	undead = {faction = "throng"}}}
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
sfinv = {register_page = function() end, make_formspec = function(_, _, c) return c end,
	get_page = function() return "" end, pages = {}, pages_unordered = {}}

local BANDS = {}
local MAP_SOURCE = dofile(path("mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"))
for _, row in ipairs(MAP_SOURCE.zones) do
	BANDS[row.id] = {level_min = row.level_min, level_max = row.level_max, display_name = row.display_name}
end
grug_zones = {get = function(zone) return BANDS[zone] end, id_at = function() return "elandor_ashenward_march" end}

-- grug_mobs: the real PvP garrison rules over lane S's catalogue and the
-- Astra names; spawn regions without any recipe (the fixture names only
-- garrisons); directions through the real spawn_regions_core.describe on a
-- small map of the camp's zone, as SR.describe calls it.
local CORE = dofile(path("mods/ENTITIES/grug_mobs/spawn_regions_core.lua"))
local garrison = dofile(path("mods/ENTITIES/grug_mobs/pvp_garrison.lua")).new(CATALOG,
	read_json(path("mods/ENTITIES/grug_mobs/data/pvp_names.json")))
local function zone_map(zone)
	-- A square of land cells around the zone record's centre, so "zone" mode
	-- has a frame (zone_frame: centroid and half extent).
	local cx, cz = 0, 0
	for _, row in ipairs(MAP_SOURCE.zones) do
		if row.id == zone then cx, cz = row.hub.x, row.hub.z end
	end
	local order = {}
	for i = -10, 10 do
		for j = -10, 10 do order[#order + 1] = {x = cx + i * 64, z = cz + j * 64} end
	end
	return {zone = zone, leaders = {}, camps = {}, by_kind = {}, order = order}
end
local described = {}
grug_mobs = {
	register_on_eligible_kill = function() end,
	register_participant_drop_hook = function() end,
	disposition = function() return nil end, -- guards and captains have none
	pvp_garrison = garrison,
	spawn_regions = {
		get_area = function() return nil end,
		area_roles = function() return nil end,
		zone_area_ids = function() return {} end,
		leader = function() return nil end,
		place = function(ref) return places[ref] end,
		-- Round 36: no quest place or clash site in this fixture.
		zone_place = function() return nil end,
		clash_site = function() return nil end,
		describe = function(zone, target, mode, ref)
			described[#described + 1] = {zone = zone, target = target, mode = mode}
			local where = mode == "of" and places[ref] or ref
			return CORE.describe(zone_map(zone), target, mode, where, BANDS[zone].display_name)
		end,
	},
}
for _, f in ipairs({"accord", "throng"}) do
	for _, kind in ipairs({"guard", "captain", "general", "bodyguard"}) do
		core.registered_entities["grug_mobs:" .. kind .. "_" .. f] = {
			description = (f == "accord" and "Accord " or "Throng ") .. kind:gsub("^%l", string.upper)}
	end
end

grug_quests = {}
local base = path("mods/PLAYER/grug_quests/")
for _, file in ipairs({"registry", "state", "labels", "npc", "npcs", "validate", "loader"}) do
	dofile(base .. file .. ".lua")
end
local Q = grug_quests
Q.resolve_npc_factions()
local loaded, load_err = pcall(Q.validate_quest_data)
check(loaded, "fixture: the load-time world checks pass: " .. tostring(load_err))
eq(Q.registered_npcs.r31_accord_outrider.faction, "accord", "fortress giver serves its seat race's faction")
eq(Q.registered_npcs.r31_throng_warmaster.faction, "throng", "Throng fortress giver serves the Throng")

------------------------------------------------------------------------------
-- C: credit for guard and captain kills by area.
------------------------------------------------------------------------------
local CAMP = "front_broken_causeway/pvp_camp_broken_causeway_throng_low"
eq(garrison.area("pvp_camp_broken_causeway_throng_low"), CAMP, "lane G's area tag is the quest's area")
local meta = {}
local player = {}
function player:get_player_name() return "ann" end
function player:get_meta()
	return {get_string = function(_, k) return meta[k] or "" end, set_string = function(_, k, v) meta[k] = v end}
end
function player:get_inventory() return {get_list = function() return {} end} end
check(Q.accept(player, "q31_picket"), "accept the camp quest")
local function counters() return Q.journal(player).quests[1].objectives end
local function kill(name, area, faction)
	Q.credit_kill(player, {name = "grug_mobs:" .. name, _grug_area = area, object = {_faction = faction}})
	local rows = counters()
	return rows[1].count .. "/" .. rows[2].count
end
eq(kill("guard_throng", nil, "throng"), "0/0", "an untagged Throng guard (a town's) counts nothing")
eq(kill("guard_throng", "front_broken_causeway/pvp_camp_broken_causeway_throng_high", "throng"), "0/0",
	"a guard of the zone's other camp counts nothing")
eq(kill("guard_throng", "front_shattered_line/pvp_camp_shattered_line_throng_low", "throng"), "0/0",
	"a guard of another zone's picket counts nothing")
eq(kill("guard_accord", "front_broken_causeway/pvp_camp_broken_causeway_accord_low", "accord"), "0/0",
	"an own-faction guard counts nothing")
eq(kill("guard_throng", CAMP, "throng"), "1/0", "a guard of the camp counts")
eq(kill("captain_throng", "front_broken_causeway/pvp_camp_broken_causeway_throng_high", "throng"), "1/0",
	"another camp's captain counts nothing")
eq(kill("captain_throng", CAMP, "throng"), "1/1", "the camp's captain counts")
eq(kill("guard_throng", CAMP, "throng"), "2/1", "a second guard counts")
eq(kill("guard_throng", CAMP, "throng"), "2/1", "no count past the objective")
eq(Q.status(player, "q31_picket"), "ready", "the quest is ready to turn in")

------------------------------------------------------------------------------
-- V: the load checks.
------------------------------------------------------------------------------
local levels = Q.registered_quests.q31_picket.objectives
eq(levels[1].levels and levels[1].levels[1] .. "-" .. levels[1].levels[2], "41-43",
	"guards show the camp's band (Broken Causeway low camp 41-43)")
eq(levels[2].levels and levels[2].levels[1] .. "-" .. levels[2].levels[2], "43-43",
	"the captain shows the band's top")
local function picket(files)
	for _, file in ipairs(files) do
		for _, quest in ipairs(file.data.quests or {}) do
			if quest.id == "q31_picket" then return quest end
		end
	end
end
for _, case in ipairs({
	{"own faction's camp", "E-garrison-faction", function(q)
		q.objectives[1].roles = {"guard_accord"}
		q.objectives[1].area = "front_broken_causeway/pvp_camp_broken_causeway_accord_low"
	end},
	{"role the garrison has not", "E-role-not-in-area", function(q) q.objectives[2].roles = {"general_throng"} end},
	{"guard without an area", "E-not-a-mob", function(q) q.objectives[1].area = nil end},
	{"camp band misfits the level", "E-level-fit", function(q) q.level = 52 end},
	{"unknown PvP POI in the text", "E-placeholder-target", function(q) q.text = q.text .. " {name:pvp_camp_nowhere}" end},
	{"POI qualified with the wrong zone", "E-placeholder-target", function(q)
		q.text = q.text .. " {name:front_shattered_line/pvp_camp_broken_causeway_throng_low}"
	end},
}) do
	local files = deep_copy(Q.quest_files)
	case[3](picket(files))
	local ok, err = pcall(Q.validate_quest_data, files)
	check(not ok and tostring(err):find("[" .. case[2] .. "]", 1, true) ~= nil,
		case[1] .. ": " .. case[2] .. " expected, got: " .. tostring(err))
end
-- The other faction may name the same camp: a Throng giver's quest on an
-- Accord camp is clean (the world checks read the giver's faction).
do
	local files = deep_copy(Q.quest_files)
	local q = picket(files)
	q.giver, q.turnin = "r31_throng_outrider", "r31_throng_outrider"
	q.objectives[1].roles = {"guard_accord"}
	q.objectives[2].roles = {"captain_accord"}
	q.objectives[1].area = "front_broken_causeway/pvp_camp_broken_causeway_accord_low"
	q.objectives[2].area = q.objectives[1].area
	local ok, err = pcall(Q.validate_quest_data, files)
	check(ok, "a Throng quest on an Accord camp is clean: " .. tostring(err))
end

------------------------------------------------------------------------------
-- P: placeholders on a PvP POI.
------------------------------------------------------------------------------
local def = Q.registered_quests.q31_picket
eq(def.title, "Group: Pull Up the Causeway Throng Picket", "title {name:<camp key>} is the camp's label")
local target = Q.placeholder_target("elandor_ashenward_march", "pvp_camp_broken_causeway_throng_low")
eq(target and target.what, "poi", "a camp key is a PvP POI target from any zone")
eq(target and target.zone, "front_broken_causeway", "the POI's own zone")
check(Q.placeholder_target("front_shattered_line", "front_shattered_line/pvp_camp_broken_causeway_throng_low") == nil,
	"a POI qualified with another zone is no target")
for key in pairs(described) do described[key] = nil end -- the quest log filled it already (C)
local text = Q.quest_text(def, true)
local giver, camp = places.pvp_fortress_accord, places.pvp_camp_broken_causeway_throng_low
local dir = CORE.compass(giver.x, giver.z, camp.x, camp.z)
check(text:find("The picket stands " .. dir .. " from here.", 1, true) ~= nil,
	"{dir_from_giver:...} points from the fortress giver at the camp's anchor (" .. dir .. "): " .. text)
check(text:find("The Causeway Throng Picket, which lies in the ", 1, true) ~= nil,
	"{name:zone/key} and {zone_area:...} read the camp: " .. text)
local poi_described = 0
for _, row in ipairs(described) do
	if type(row.target) == "table" and row.target.x == camp.x and row.target.z == camp.z and
			row.zone == "front_broken_causeway" then
		poi_described = poi_described + 1
	end
end
eq(poi_described, 2, "both directions were described at the camp's anchor in its zone")
local log_text = Q.quest_text(def, false)
check(log_text:find(" of Ashenward Bastion.", 1, true) ~= nil,
	"in the quest log \"from here\" reads from the giver's fortress: " .. log_text)
-- spawn_regions_core: a place target is its {x, z}; ids keep their meaning.
local t = CORE.target_of({leaders = {}, camps = {}, by_kind = {}}, {x = 5, z = 7})
check(t and t.x == 5 and t.z == 7 and t.what == "place", "target_of takes a place as {x, z}")
check(CORE.target_of({leaders = {}, camps = {}, by_kind = {}}, "pvp_camp_x") == nil, "an unknown id stays nil")

------------------------------------------------------------------------------
-- S: the shipped fortress quests.
------------------------------------------------------------------------------
local SHIP = path("mods/PLAYER/grug_quests/data/zones/")
local FORT = {accord = "elandor_ashenward_march", throng = "kragmar_bannerbreak_mesa"}
local GARRISON_SIZE = {low = 4, high = 5} -- the camp blueprints' guard posts (lane S)
for faction, zone in pairs(FORT) do
	local enemy = faction == "accord" and "throng" or "accord"
	local givers = {}
	for _, role in ipairs({"warmaster", "drillmaster", "outrider"}) do givers["r31_" .. faction .. "_" .. role] = true end
	local quests = {}
	for _, name in ipairs({zone .. ".quests.json", zone .. ".front.quests.json"}) do
		for _, quest in ipairs(read_json(SHIP .. name).quests) do quests[#quests + 1] = quest end
	end
	local camps, ordinary, entry = {}, 0, 0
	for _, quest in ipairs(quests) do
		-- The Round 31 set lives on the line `front`; the Warmaster's second
		-- line holds the Round 36 main line (its own fixtures).
		local fortress = (givers[quest.giver] or givers[quest.turnin]) and quest.line == "front"
		if fortress then
			check(quest.min_level >= 40, quest.id .. ": a PvP quest starts at 40 or later (ruling 15)")
			if not givers[quest.giver] then entry = entry + 1 end
			local area = quest.objectives[1].area
			local key = area and area:match("/(pvp_camp_.+)$")
			if key then
				local row = garrison.poi(key)
				check(not camps[key], quest.id .. ": one quest per camp")
				camps[key] = true
				eq(row.faction, enemy, quest.id .. ": the camp is the other faction's")
				eq(#quest.objectives, 2, quest.id .. ": guards and captain")
				local band = BANDS[row.zone_id]
				local roles = garrison.area_roles(key, {band.level_min, band.level_max})
				local guards, captain = quest.objectives[1], quest.objectives[2]
				eq(guards.roles[1], "guard_" .. enemy, quest.id .. ": the guards")
				eq(guards.count, GARRISON_SIZE[row.band], quest.id .. ": the camp's guards")
				eq(captain.roles[1], "captain_" .. enemy, quest.id .. ": the captain")
				eq(captain.count, 1, quest.id .. ": one captain")
				eq(captain.area, area, quest.id .. ": both in the camp")
				check(roles["guard_" .. enemy][1] >= quest.level - 3 and roles["captain_" .. enemy][2] <= quest.level + 3,
					quest.id .. ": the camp's band fits the reward level")
				-- Solo quests (user, round31-plan §6 item 16): no Group flag or prefix.
				check(quest.group == nil and quest.optional == nil and not quest.title:match("^Group: "),
					quest.id .. ": a solo quest")
				check(quest.turnin == quest.giver, quest.id .. ": turned in where given")
			elseif givers[quest.giver] then
				ordinary = ordinary + 1
			end
		end
		for _, objective in ipairs(quest.objectives) do
			for _, role in ipairs(objective.roles or {}) do
				check(not role:match("player"), quest.id .. ": never a player target (ruling 14)")
			end
		end
	end
	local n = 0
	for _ in pairs(camps) do n = n + 1 end
	eq(n, 8, faction .. ": one quest per enemy Battlegrounds camp")
	check(ordinary >= 3 and ordinary <= 5, faction .. ": 3-5 ordinary fortress quests (" .. ordinary .. ")")
	check(entry >= 1, faction .. ": an entry quest leads to the fortress from elsewhere")
	print(("%s: %d camp quests, %d ordinary fortress quests, %d entry quest(s)"):format(faction, n, ordinary, entry))
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	print(("%d checks, %d failures"):format(checks, #failures))
	os.exit(1)
end
print("R31 Q PORTABLE PASS checks=" .. checks)
