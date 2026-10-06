-- Round 38 lane B1 portable test (LuaJIT): the quest-name guarantee
-- (round38-mob-names-plan.md §2.1): a kill counts by the name the mob shows.
--
--   luajit tools/r38_b1/portable_test.lua [REPO]
--
--   N  the names (the REAL grug_mobs names.lua over a fixture names map, and
--      the shipped data/names.json loads clean): a mob's name by its source,
--      zone and level; one name reused in two zones; a relevel across bands
--      renames; a base entity named by level band in "world"; a garrison
--      guard by its post, a town guard by its entity; a captain keeps his
--      own name; the name survives an unload (plain fields only) and the
--      zone is the spawn's, not where the mob stands later; levels.lua and
--      start_npcs.lua apply it.
--   S  the Stillgrave playtest (hunt_01 boars, hunt_02 rats, 2026-10-06):
--      the REAL grug_quests registry, state and labels over the shipped
--      names and the shipped Stillgrave recipe: the label is the slot name;
--      a rat of another kind of the zone under the same name counts (the
--      Round 37 bug); a mob of another name (the L3-4 pigs, which carry
--      their own accepted name since lane B2, a zombie of the area, a Kapok
--      pig) does not; never past the count.
--   G  garrisons: a picket quest's guards and captain read the names the
--      mobs show on this world (the camp's race); a town guard and another
--      camp's captain count nothing; quest drops roll by name.
--   K  the kill path: credit cost per kill (a comparison, not a target).
-- Prints "R38 B1 PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
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
local function read(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[deep_copy(k)] = deep_copy(v) end
	return out
end
table.copy = deep_copy
local function serialize(value)
	if type(value) == "table" then
		local keys, parts = {}, {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k]) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local MOBS = repo .. "/mods/ENTITIES/grug_mobs"
local STILL, KAPOK = "kragmar_stillgrave_hollow", "kragmar_kapok_cradle"
core = {
	get_modpath = function(name) return name == "grug_quests" and repo .. "/mods/PLAYER/grug_quests" or MOBS end,
	get_current_modname = function() return "grug_mobs" end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = serialize,
	deserialize = function(text) return text ~= "" and assert(loadstring("return " .. text))() or nil end,
	registered_entities = {}, registered_items = {},
	log = function() end,
	register_on_leaveplayer = function() end,
	get_player_by_name = function() return nil end,
}
-- Zones by x: west Stillgrave, east the Kapok Cradle.
grug_zones = {id_at = function(x) return x < 0 and STILL or KAPOK end,
	get = function(zone) return {display_name = zone} end}
grug_mobs = {register_on_eligible_kill = function() end,
	register_participant_drop_hook = function(fn) grug_mobs.drop_hook = fn end}

------------------------------------------------------------------------------
-- N: names
------------------------------------------------------------------------------
dofile(MOBS .. "/names.lua")
local shipped = grug_mobs.names
check(shipped.lookup("small_boar", STILL, 2) ~= nil, "N the shipped names.json loads")
-- The accepted names of the Stillgrave start slots (Round 38 lane B2).
local PIGLET, SHOAT = shipped.lookup("small_boar", STILL, 2), shipped.lookup("small_boar", STILL, 3)
local RAT_1, RAT_3 = shipped.lookup("large_rat", STILL, 2), shipped.lookup("large_rat", STILL, 3)
local NC = shipped.core
local index, errors = NC.build({
	["zone_a/small_boar/L1-2"] = "Forest Piglet",
	["zone_a/small_boar/L3-4"] = "Forest Pig",
	["zone_b/small_boar/L1-2"] = "Forest Piglet",
	["world/cave_bat/L1-10"] = "Cave Bat",
	["world/cave_bat/L11-60"] = "Cave Hunter",
	["zone_f/camp_x.guard/L41-43"] = "Ford Skirmisher",
	["world/guard_throng/L20-60"] = "Throng Guard",
	["zone_a/rare.grimtusk/L12-19"] = "Grimtusk",
})
eq(#errors, 0, "N the fixture map builds")
local _, overlap = NC.build({["z/a/L1-3"] = "A", ["z/a/L3-4"] = "B", ["z/a/L5-6"] = "B", ["bad"] = "C"})
eq(#overlap, 2, "N a malformed key and two names overlapping in level are errors")
local fixture = NC.api(index)
shipped.lookup = fixture.lookup -- names.lua resolves through the published lookup
local function mob(name, fields, x)
	local ent = {name = "grug_mobs:" .. name, description = "registered " .. name,
		object = {get_pos = function() return {x = x or -5, y = 0, z = 0} end}}
	for k, v in pairs(fields or {}) do ent[k] = v end
	return ent
end
local pig = mob("small_boar", {_grug_area = "zone_a/fields", _grug_spawn_level = 2})
check(grug_mobs.apply_name(pig), "N a named slot renames the mob")
eq(pig.description, "Forest Piglet", "N name by zone and the spawn level")
eq(pig.temp.grug_display, "Forest Piglet", "N ...kept for the per-step guard")
pig._grug_level = 4
grug_mobs.apply_name(pig)
eq(pig.description, "Forest Pig", "N a relevel into the next band renames")
local far = mob("small_boar", {_grug_area = "zone_b/meadow", _grug_level = 1})
grug_mobs.apply_name(far)
eq(far.description, "Forest Piglet", "N one name reused in another zone")
eq(shipped.name_of(mob("small_boar", {_grug_area = "zone_a/fields"})), nil,
	"N no level yet and two names in the zone: no name until the level")
local bat = mob("cave_bat", {_grug_level = 5})
grug_mobs.apply_name(bat)
eq(bat.description, "Cave Bat", "N a base entity by level band in world")
bat._grug_level = 30
grug_mobs.apply_name(bat)
eq(bat.description, "Cave Hunter", "N ...and its next band")
local post = mob("guard_throng", {_grug_name_key = "camp_x.guard", _grug_area = "zone_f/camp_x", _grug_level = 42})
grug_mobs.apply_name(post)
eq(post.description, "Ford Skirmisher", "N a garrison guard by its post")
local town = mob("guard_throng", {_grug_level = 55})
grug_mobs.apply_name(town)
eq(town.description, "Throng Guard", "N a town guard by its entity")
local captain = mob("captain_throng", {_grug_name_key = "camp_x.captain-orc", _grug_area = "zone_f/camp_x",
	description = "Captain Vrakk", _grug_level = 43})
check(not grug_mobs.apply_name(captain) and captain.description == "Captain Vrakk",
	"N a captain keeps his pvp_names.json name")
local rare = mob("boar", {_grug_name_key = "rare.grimtusk", _grug_level = 30})
grug_mobs.apply_name(rare)
eq(rare.description, "Grimtusk", "N a rare by its key, outside its slot's levels: the nearest")
local unnamed = mob("villager_human", {description = "Villager"})
check(not grug_mobs.apply_name(unnamed) and unnamed.description == "Villager",
	"N a source the file does not name keeps its description")
-- Unload and reload: plain fields only (mobs_redo clean_staticdata), now far
-- away in another zone: the spawn zone and level decide.
do
	local untagged = mob("small_boar", {_grug_level = 1}, -5)
	shipped.name_of(untagged)
	eq(untagged._grug_variant_zone, STILL, "N an untagged mob reads its first position's zone, persisted")
	local saved = {}
	for k, v in pairs(pig) do
		if type(v) ~= "function" and k ~= "temp" and k ~= "object" then saved[k] = deep_copy(v) end
	end
	local back = mob("small_boar", saved, 500)
	back.description = "registered small_boar"
	grug_mobs.apply_name(back)
	eq(back.description, "Forest Pig", "N the name survives an unload, wherever the mob stands")
end
do
	local levels = read(MOBS .. "/levels.lua")
	local _, in_levels = levels:gsub("grug_mobs%.apply_name%(", "")
	eq(in_levels, 2, "N levels.lua names a mob once per activation and on every relevel")
	check(read(MOBS .. "/start_npcs.lua"):find("grug_mobs.apply_name(entity)", 1, true) ~= nil,
		"N a garrison post is named at placement")
	check(read(MOBS .. "/init.lua"):find('dofile(modpath .. "/names.lua")', 1, true) ~= nil,
		"N init.lua loads names.lua")
end
shipped.lookup = function(source, zone, level) return NC.lookup(shipped.index, source, zone, level) end

------------------------------------------------------------------------------
-- The quest side: the REAL registry, state and labels over the shipped
-- names, the shipped Stillgrave recipe and the real PvP garrison rules.
------------------------------------------------------------------------------
local CORE = dofile(MOBS .. "/spawn_regions_core.lua")
local catalogue = {}
for _, row in ipairs(json.decode(read(MOBS .. "/data/subtypes.json"))) do
	catalogue[row.role] = row
	core.registered_entities["grug_mobs:" .. row.role] = {description = row.display}
end
local recipes, leaders = {}, {}
for _, zone in ipairs({STILL, KAPOK}) do
	recipes[zone] = CORE.parse_recipe(zone, json.decode(read(MOBS .. "/data/zones/" .. zone ..
		".spawns.json")).recipe, {
		band = {1, 10},
		pois = function() return {} end,
		role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
		leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
	})
	for _, leader in ipairs(recipes[zone].leaders) do
		leaders[leader.role] = {zone = zone, level = leader.level}
	end
end
grug_mobs.spawn_regions = {
	get_area = function(zone, id)
		local r = recipes[zone]
		return r and (r.kind_by_id[id] or r.camp_by_id[id]) or nil
	end,
	zone_area_ids = function(zone)
		local out = {}
		for _, kind in ipairs(recipes[zone] and recipes[zone].kinds or {}) do out[#out + 1] = kind.id end
		for _, camp in ipairs(recipes[zone] and recipes[zone].camps or {}) do out[#out + 1] = camp.id end
		return out
	end,
	leader = function(role) return leaders[role] end,
}
local CATALOG = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua")
grug_mobs.pvp_garrison = dofile(MOBS .. "/pvp_garrison.lua").new(CATALOG,
	json.decode(read(MOBS .. "/data/pvp_names.json")))
local RACE = {}
grug_core = {
	plain_text = function(text) return text end,
	feed_item = function() end,
	settlement_socket_settlements = function()
		local out = {}
		for _, row in ipairs(CATALOG.rows) do
			if row.kind ~= "pvp_fortress" then
				RACE[row.key] = RACE[row.key] or CATALOG.FACTION_RACES[row.faction][#CATALOG.FACTION_RACES[row.faction]]
				out[#out + 1] = {key = row.key, race_id = RACE[row.key]}
			end
		end
		return out
	end,
}
grug_xp = {get_level = function() return 60 end, register_on_level_change = function() end}
grug_factions = {same_faction = function(_, object) return object and object.own == true end}
grug_sounds = {play = function() end}
grug_inventory = {BAG_COUNT = 0}
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests
Q.register_npc("giver", {settlement = "s", socket = "q", title = "Giver"})

-- A quest built as the loader builds it (loader.lua definition): the roles
-- and area select the names (labels.lua), the kill counts by them.
local function quest(id, roles, area, zone, count)
	local mobs = {}
	for i, role in ipairs(roles) do mobs[i] = "grug_mobs:" .. role end
	local names = Q.target_names(mobs, area, zone)
	Q.register_quest(id, {title = id, description = id, npc = "giver", rewards = {weight = 1},
		objectives = {{type = "kill", mobs = mobs, area = area, names = names, name_set = Q.name_set(names),
			count = count}}})
	return Q.registered_quests[id]
end
local meta = {}
local player = {get_player_name = function() return "ann" end,
	get_meta = function() return {get_string = function(_, k) return meta[k] or "" end,
		set_string = function(_, k, v) meta[k] = v end} end}
local function take(...)
	local active = {}
	for _, id in ipairs({...}) do active[id] = {} end
	meta["grug_quests:state"] = serialize({active = active, completed = {}, tracked = {}, hud = true})
end
local function count(id)
	return (core.deserialize(meta["grug_quests:state"]).active[id] or {})[1] or 0
end
-- A mob as the game names it (names.lua), spawned in a recipe area at a level.
local function spawned(role, area, level, x)
	local ent = mob(role, {_grug_area = area, _grug_level = level,
		description = catalogue[role] and catalogue[role].display}, x)
	grug_mobs.apply_name(ent)
	return ent
end
local function kill(ent) Q.credit_kill(player, ent, {x = 0, y = 0, z = 0}) end

------------------------------------------------------------------------------
-- S: the Stillgrave playtest
------------------------------------------------------------------------------
local hunt1 = quest("stillgrave_hunt_01", {"small_boar"}, STILL .. "/dead_furrows", STILL, 8)
local hunt2 = quest("stillgrave_hunt_02", {"large_rat"}, STILL .. "/dead_furrows", STILL, 8)
eq(Q.objective_subject(hunt1.objectives[1]), PIGLET, "S hunt_01's label is its slot's name")
eq(Q.objective_subject(hunt2.objectives[1]), RAT_1, "S hunt_02's label is its slot's name")
check(PIGLET ~= SHOAT and RAT_1 == RAT_3, "S the accepted names: the L3-4 pigs have their own name, " ..
	"the rats one name over L1-4")
take("stillgrave_hunt_01", "stillgrave_hunt_02")
kill(spawned("small_boar", STILL .. "/dead_furrows", 2))
eq(count("stillgrave_hunt_01"), 1, "S a pig of the furrows counts")
local ash_pig = spawned("small_boar", STILL .. "/ashfields", 3)
eq(ash_pig.description, SHOAT, "S an Ashfields pig shows the L3-4 name")
kill(ash_pig)
eq(count("stillgrave_hunt_01"), 1, "S ...and, another name, does not count")
kill(spawned("large_rat", STILL .. "/dead_furrows", 1))
eq(count("stillgrave_hunt_02"), 1, "S a rat of the furrows counts")
kill(spawned("large_rat", STILL .. "/ashfields", 4))
eq(count("stillgrave_hunt_02"), 2, "S a rat of the Ashfields under the same name counts (the playtest bug)")
eq(count("stillgrave_hunt_01"), 1, "S ...and not for the pigs")
kill(spawned("braindead_zombie", STILL .. "/ashfields", 3))
eq(count("stillgrave_hunt_01") .. "/" .. count("stillgrave_hunt_02"), "1/2", "S a zombie counts for neither")
local kapok = spawned("small_boar", KAPOK .. "/yam_beds", 2, 50)
eq(kapok.description, shipped.lookup("small_boar", KAPOK, 2), "S a Kapok pig shows its zone's name")
check(kapok.description ~= PIGLET, "S ...another name than Stillgrave's")
kill(kapok)
eq(count("stillgrave_hunt_01"), 1, "S ...and does not count for Stillgrave's pigs")
for _ = 1, 9 do kill(spawned("small_boar", STILL .. "/dead_furrows", 1)) end
eq(count("stillgrave_hunt_01"), 8, "S never past the count")

------------------------------------------------------------------------------
-- G: garrisons
------------------------------------------------------------------------------
local LOW = "pvp_camp_broken_causeway_throng_low"
local CAMP = "front_broken_causeway/" .. LOW
local picket = quest("picket_guards", {"guard_throng"}, CAMP, "elandor_ashenward_march", 2)
local boss = quest("picket_captain", {"captain_throng"}, CAMP, "elandor_ashenward_march", 1)
local guard_name = shipped.lookup(LOW .. ".guard", nil, nil)
check(guard_name ~= nil and guard_name ~= "Throng Guard", "G the picket's guards have their own name")
eq(Q.objective_subject(picket.objectives[1]), guard_name, "G the guards' label is their post's name")
local captain_name = grug_mobs.pvp_garrison.captain_name(LOW, RACE[LOW])
eq(Q.objective_subject(boss.objectives[1]), captain_name, "G the captain's label is his name on this world")
take("picket_guards", "picket_captain")
local function garrison_mob(entity, key, post, level)
	local ent = mob(entity, {_grug_name_key = key .. "." .. post, _grug_area = "front_broken_causeway/" .. key,
		_grug_level = level})
	if post:find("^captain") then
		ent.description = grug_mobs.pvp_garrison.captain_name(key, RACE[key])
	end
	grug_mobs.apply_name(ent)
	return ent
end
local town_guard = mob("guard_throng", {_grug_level = 50, description = "Throng Guard"})
grug_mobs.apply_name(town_guard)
eq(town_guard.description, "Throng Guard", "G a town guard shows the faction guard's name")
kill(town_guard)
eq(count("picket_guards"), 0, "G a town guard counts nothing for the picket")
kill(garrison_mob("guard_throng", "pvp_camp_broken_causeway_throng_high", "guard", 49))
eq(count("picket_guards"), 0, "G the war camp's guard counts nothing")
kill(garrison_mob("guard_throng", LOW, "guard", 42))
eq(count("picket_guards"), 1, "G the picket's guard counts")
local high = "pvp_camp_broken_causeway_throng_high"
kill(garrison_mob("captain_throng", high, "captain-" .. RACE[high], 50))
eq(count("picket_captain"), 0, "G another camp's captain counts nothing")
kill(garrison_mob("captain_throng", LOW, "captain-" .. RACE[LOW], 43))
eq(count("picket_captain"), 1, "G the camp's captain counts")
local own = garrison_mob("guard_throng", LOW, "guard", 42)
own.object.own = true
kill(own)
eq(count("picket_guards"), 1, "G an own-faction kill credits nothing")
-- Quest drops roll by name: the captain's orders.
Q.register_quest("orders", {title = "orders", description = "orders", npc = "giver", rewards = {weight = 1},
	objectives = {{type = "item", item = "grug_mobs:throng_captains_orders", count = 1}},
	quest_drops = (function()
		local names = Q.target_names({"grug_mobs:captain_throng"}, CAMP, "elandor_ashenward_march")
		return {{item = "grug_mobs:throng_captains_orders", chance = 1, mobs = {"grug_mobs:captain_throng"},
			area = CAMP, names = names, name_set = Q.name_set(names)}}
	end)()})
check(Q.quest_drop_names[captain_name] == true, "G a quest drop is indexed by its name")
check(not Q.quest_drop_names[grug_mobs.pvp_garrison.captain_name(high, RACE[high])],
	"G ...and only by its own camp's captain")

------------------------------------------------------------------------------
-- K: the kill path's cost (a comparison, not a target)
------------------------------------------------------------------------------
do
	local ids = {}
	for i = 1, 20 do
		ids[i] = "k" .. i
		quest(ids[i], {"small_boar", "large_rat"}, STILL .. "/ashfields", STILL, 1000000)
	end
	take(unpack(ids))
	local zombie = spawned("braindead_zombie", STILL .. "/ashfields", 3)
	local boar = spawned("small_boar", STILL .. "/ashfields", 3)
	local n = 20000
	local t0 = os.clock()
	for _ = 1, n do kill(zombie) end
	local miss = (os.clock() - t0) / n * 1e6
	t0 = os.clock()
	for _ = 1, n do kill(boar) end
	local hit = (os.clock() - t0) / n * 1e6
	print(("kill path: 20 active quests of two roles each, %.2f us per kill that credits nothing, " ..
		"%.2f us per kill that credits all 20 (LuaJIT, stubbed state)"):format(miss, hit))
	eq(count("k20"), n, "K every same-named kill counted")
end

if #failures == 0 then
	print("R38 B1 PORTABLE PASS checks=" .. checks)
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R38 B1 PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
