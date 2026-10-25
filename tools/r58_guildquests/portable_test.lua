-- Round 58 lane GUILDQUESTS portable fixture (LuaJIT): the Miner's Guild's
-- quests in the shipped quest files (miners_guild.md §11, quests.md "The
-- Miner's Guild's quests").
--
--   luajit tools/r58_guildquests/portable_test.lua [REPO]
--
-- S. The files: build_structure.py writes what ships; one quest id per tier
--    and resource (two per tier T2-T6) with two faction variants that list
--    the foreman roles of their tier and deeper; one story follow-up per
--    tier and faction that requires both gather quests and travels to the
--    leader of its giver zone's race region; one camp hunt per camp (a
--    shared quest per camp band and clock) on a role the zone's own quests
--    do not hunt (Lorindor excepted), 8 by day or 3 after dark, with a
--    choice of materials; the raid on each camp under construction (four
--    guards and the captain) from the own T4 foreman; no repeatable quest,
--    no kill objective in the depth (every kill area is a surface kind or a
--    camp site's garrison), no reputation, no fixed item; free play: only
--    the follow-ups require anything.
-- B. The real loader over seed 42's settlement sockets (tools/seed_fleet:
--    the camps' and capitals' blueprints as the world registers them),
--    the real camp index, the real spawn recipes, names and garrisons, and
--    the engine dump's items: the files pass the load-time world checks and
--    the registry checks; the foreman roles bind; a tier-k gather quest is
--    offered at every own camp of tier >= k and nowhere else (and never by
--    the other faction's foremen); the follow-up only after both gather
--    quests, at the camps of its tier and deeper, turned in only at its
--    variant's leader (also the hand-in NPC of the journal: a role quest's
--    is the foreman it was taken from); each camp's hunt and each T4
--    foreman's raid at that foreman.
-- V. tools/r28_design/validate.py --game: 0 errors.
-- Prints "R58 GUILDQUESTS PORTABLE PASS checks=<n>" or raises.

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

local TIERS = {2, 3, 4, 5, 6}
local FACTIONS = {"accord", "throng"}
local CAPITAL_RACE = {highcourt = "human", dur_brannoc = "dwarf", lethariel = "elf",
	nhal_veyr = "undead", gor_drazhak = "orc", kezamba = "troll"}
local RACE_FACTION = {human = "accord", dwarf = "accord", elf = "accord",
	undead = "throng", orc = "throng", troll = "throng"}
local ACROSS = {dwarf = "undead", undead = "dwarf", human = "orc", orc = "human", elf = "troll", troll = "elf"}
local CAPITAL_OF = {}
for capital, race in pairs(CAPITAL_RACE) do CAPITAL_OF[race] = capital end

local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local zone_by_id = {}
for _, zone in ipairs(source.zones) do zone_by_id[zone.id] = zone end
local catalog = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r58_camp_catalog.lua")

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
			if q.id:find("^guild_") or q.id:find("^camp_") then
				quests[q.id] = q
				file_of[q.id] = zone
			end
		end
	end
end
-- The script's quests ship, each in its home file, with the camps' hubs.
-- (Since the texts landed the files differ from its output by their texts,
-- and since Round 59 by the T2 camp hunt's target, which it would pick anew
-- from the band 11-20's new quests; before Round 59 this check passed "10
-- differ" by containing "0 differ".) The S rows below check the rest.
do
	local out = run("python3 " .. repo .. "/tools/r58_guildquests/build_structure.py --check --ids")
	check(out:match("build_structure: %d+ files, 0 differ %(ids%)") ~= nil,
		"S build_structure.py's quest and hub ids ship: " .. out)
end
local count = 0
for _ in pairs(quests) do count = count + 1 end
eq(count, 30, "S 30 guild quests (10 gather, 10 follow-ups, 9 hunts, 1 raid)")

-- The guild files: zones of their own (grug_guild's GUILDS ids), reworked.
local guild_catalog = dofile(repo .. "/mods/PLAYER/grug_guild/catalog.lua")
local GUILD_ZONE = {accord = guild_catalog.GUILDS.accord.id, throng = guild_catalog.GUILDS.throng.id}
for _, faction in ipairs(FACTIONS) do
	local data = file_data[GUILD_ZONE[faction]]
	if check(data ~= nil, "S the guild file of " .. faction) then
		eq(data.reworked, true, "S " .. GUILD_ZONE[faction] .. " is reworked")
		eq(zone_by_id[GUILD_ZONE[faction]], nil, "S " .. GUILD_ZONE[faction] .. " is no map zone")
		eq(#(data.hubs or {}), 0, "S " .. GUILD_ZONE[faction] .. " has no hub")
	end
end

-- Gather quests: one id per tier and resource, two faction variants.
local gathers = {}
for id, q in pairs(quests) do
	local tier = tonumber(id:match("^guild_t(%d)_") or "")
	if tier and not id:find("_report_") then
		gathers[tier] = gathers[tier] or {}
		table.insert(gathers[tier], id)
		eq(file_of[id], GUILD_ZONE.accord, "S " .. id .. " lives in the Charter's file")
		eq(#q.variants, 2, "S " .. id .. " has two variants")
		for index, faction in ipairs(FACTIONS) do
			local variant = q.variants[index] or {}
			eq(variant.zone, GUILD_ZONE[faction], "S " .. id .. " variant " .. index .. " is " .. faction .. "'s")
			local roles = {}
			for _, row in ipairs(variant.givers or {}) do
				check(type(row) == "table" and row.faction == faction, "S " .. id .. " a " .. faction .. " role row")
				roles[#roles + 1] = type(row) == "table" and row.role or tostring(row)
			end
			local want = {}
			for k = tier, 6 do want[#want + 1] = "foreman_t" .. k end
			eq(table.concat(roles, ","), table.concat(want, ","), "S " .. id .. " " .. faction .. " roles")
			eq(variant.turnins, nil, "S " .. id .. " is turned in where it is given")
			check(type(variant.text) == "string" and variant.text:find(faction == "accord" and
				"The Charter of Stone" or "The Oathdelvers", 1, true) ~= nil, "S " .. id .. " " .. faction ..
				" text names its guild")
		end
		eq(#q.objectives, 1, "S " .. id .. " one objective")
		eq(q.objectives[1].type, "item", "S " .. id .. " an item objective")
		eq(q.min_level, (tier - 1) * 10 + 1, "S " .. id .. " min level of its tier")
		check(q.story ~= true and #(q.requires or {}) == 0, "S " .. id .. " is free play")
	end
end
for _, tier in ipairs(TIERS) do
	eq(#(gathers[tier] or {}), 2, "S tier " .. tier .. " has two gather quests")
	table.sort(gathers[tier] or {})
end
eq(gathers[1], nil, "S no T1 gather quest")

-- The follow-ups: per tier and faction, story, both gathers required, a
-- travel quest to the giver zone's race region's leader.
local camps_static = {} -- zone -> faction -> {tier, ids}
for _, row in ipairs(catalog.mining) do
	local tier = catalog.tier_of(zone_by_id[row.zone_id].level_min)
	camps_static[#camps_static + 1] = {id = row.key, zone = row.zone_id, faction = row.faction, tier = tier}
end
for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua").rows) do
	if row.kind ~= "pvp_fortress" then
		camps_static[#camps_static + 1] = {id = row.key, zone = row.zone_id, faction = row.faction,
			tier = catalog.tier_of(zone_by_id[row.zone_id].level_min)}
	end
end
eq(#camps_static, 36, "S 36 camps with a lift")
local function leader_for(zone, faction)
	local race = zone_by_id[zone].race_region
	if RACE_FACTION[race] ~= faction then race = ACROSS[race] end
	return "r58_guild_leader_" .. CAPITAL_OF[race]
end
for _, tier in ipairs(TIERS) do
	for _, faction in ipairs(FACTIONS) do
		local id = ("guild_t%d_report_%s"):format(tier, faction)
		local q = quests[id]
		if check(q ~= nil, "S " .. id .. " ships") then
			eq(q.story, true, "S " .. id .. " is a story quest")
			local req = copy(q.requires or {})
			table.sort(req)
			eq(table.concat(req, ","), table.concat(gathers[tier], ","), "S " .. id .. " requires both gathers")
			eq(#q.objectives, 1, "S " .. id .. " one objective")
			eq(q.objectives[1].type, "talk", "S " .. id .. " a travel quest")
			local want, seen = {}, {}
			for _, camp in ipairs(camps_static) do
				if camp.faction == faction and camp.tier >= tier then
					want[camp.zone] = want[camp.zone] or {}
					table.insert(want[camp.zone], "r58_foreman_" .. camp.id)
				end
			end
			for _, variant in ipairs(q.variants) do
				local zone = variant.zone
				seen[zone] = true
				local expect = want[zone] or {}
				table.sort(expect)
				local got = copy(variant.givers)
				table.sort(got)
				eq(table.concat(got, ","), table.concat(expect, ","), "S " .. id .. " " .. zone .. " givers")
				local leader = leader_for(zone, faction)
				eq((variant.objectives or {{}})[1].npc or q.objectives[1].npc, leader,
					"S " .. id .. " " .. zone .. " talks to " .. leader)
				eq(table.concat(variant.turnins or {}, ","), leader, "S " .. id .. " " .. zone .. " turned in there")
				check(type(variant.completion) == "string", "S " .. id .. " " .. zone .. " a completion text")
			end
			for zone in pairs(want) do check(seen[zone], "S " .. id .. " a variant for " .. zone) end
		end
	end
end

-- The camp hunts: every camp's foreman gives exactly one, and only one
-- shared hunt per band (the camps of a band in one quest).
local hunt_of, hunts = {}, 0
for id, q in pairs(quests) do
	if id:find("^camp_hunt_") then
		hunts = hunts + 1
		check(q.story ~= true and #(q.requires or {}) == 0, "S " .. id .. " is free play")
		for _, variant in ipairs(q.variants) do
			for _, npc in ipairs(variant.givers) do
				check(hunt_of[npc] == nil, "S " .. npc .. " gives one hunt")
				hunt_of[npc] = id
			end
			local objective = (variant.objectives or {{}})[1]
			local area = objective.area or q.objectives[1].area
			eq(area and area:match("^([^/]+)/"), variant.zone, "S " .. id .. " " .. variant.zone .. " hunts in its zone")
		end
		eq(q.objectives[1].type, "kill", "S " .. id .. " a kill objective")
	end
end
eq(hunts, 9, "S 9 camp hunts (T2, T3, T4, the war camps' two bands of T5 and T6, and T3's and T4's night hunts)")
-- A hunt never repeats a role the zone's own quests already hunt (their
-- kill objectives in the zone's and the front files), but in Lorindor,
-- whose quests hunt every role by its camp; a night hunt's target spawns
-- only at night in its area and asks a third of the day count.
do
	local hunted = {}
	for _, name in ipairs(list_dir(ZONES)) do
		local data = name:find("%.quests%.json$") and read_json(ZONES .. "/" .. name)
		for _, q in ipairs(data and data.quests or {}) do
			if not (q.id:find("^guild_") or q.id:find("^camp_")) then
				for _, variant in ipairs(q.variants or {{zone = data.zone}}) do
					for index, objective in ipairs(q.objectives) do
						if objective.type == "kill" then
							local own = (variant.objectives or {})[index] or {}
							local area = own.area or objective.area
							local zone = area and area:match("^([^/]+)/") or variant.zone
							hunted[zone] = hunted[zone] or {}
							for _, role in ipairs(own.roles or objective.roles) do hunted[zone][role] = true end
						end
					end
				end
			end
		end
	end
	local repeats = {}
	for id, q in pairs(quests) do
		if id:find("^camp_hunt_") then
			local night = id:find("_night$") ~= nil
			eq(q.objectives[1].count, night and 3 or 8, "S " .. id .. " count")
			for _, variant in ipairs(q.variants) do
				local objective = (variant.objectives or {{}})[1]
				local role = (objective.roles or q.objectives[1].roles)[1]
				if (hunted[variant.zone] or {})[role] then repeats[#repeats + 1] = variant.zone .. "/" .. role end
				local zone, kind_id = (objective.area or q.objectives[1].area):match("^([^/]+)/(.+)$")
				local spawns = read_json(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json")
				local by_day = false
				for _, belt in ipairs(spawns.recipe.belts) do
					for _, kind in pairs(belt.kinds) do
						if kind.id == kind_id then
							local day = kind.day == "open" and belt.kinds.open.day or kind.day
							for _, row in ipairs(type(day) == "table" and day or {}) do
								by_day = by_day or row.role == role
							end
						end
					end
				end
				eq(by_day, not night, "S " .. id .. " " .. variant.zone .. " " .. role .. (night and
					" spawns only at night" or " spawns by day"))
			end
		end
	end
	table.sort(repeats)
	-- Round 60: Lorindor's stag hunt (lorindor_cutting_opt_01) went with the band 21-30's rework.
	eq(table.concat(repeats, ","), "", "S the hunts repeat no zone quest's role")
end
for _, camp in ipairs(camps_static) do
	check(hunt_of["r58_foreman_" .. camp.id] ~= nil, "S " .. camp.id .. " has a hunt")
end

-- The raid: each camp under construction, from its zone's own T4 foreman.
do
	local q = quests.camp_site_raid
	if check(q ~= nil, "S the raid ships") then
		eq(#q.variants, #catalog.construction, "S the raid has a variant per camp under construction")
		for _, site in ipairs(catalog.construction) do
			local found
			for _, variant in ipairs(q.variants) do
				if variant.zone == site.zone_id then found = variant end
			end
			if check(found ~= nil, "S the raid in " .. site.zone_id) then
				local own
				for _, camp in ipairs(camps_static) do
					if camp.zone == site.zone_id and camp.tier == 4 then own = camp end
				end
				check(own ~= nil and own.faction ~= site.faction, "S " .. site.key .. " lies by an enemy T4 camp")
				eq(table.concat(found.givers, ","), own and "r58_foreman_" .. own.id, "S " .. site.key .. " giver")
				-- Its four guards and its captain, as a war camp's raid.
				local guards, captain = (found.objectives or {})[1] or {}, (found.objectives or {})[2] or {}
				for _, objective in ipairs({guards, captain}) do
					eq(objective.area, site.zone_id .. "/" .. site.key, "S " .. site.key .. " its garrison")
				end
				eq((guards.roles or {})[1], "guard_" .. site.faction, "S " .. site.key .. " its guards")
				eq((captain.roles or {})[1], "captain_" .. site.faction, "S " .. site.key .. " its captain")
				eq(q.objectives[1].count, 4, "S " .. site.key .. " four guards")
				eq(q.objectives[2].count, 1, "S " .. site.key .. " one captain")
			end
		end
	end
end

-- Every guild quest: no repeatable, XP and copper only, no kill in the
-- depth (a kill area is a recipe kind of the surface or a camp site).
for id, q in pairs(quests) do
	eq(q.repeatable, nil, "S " .. id .. " is not repeatable")
	-- XP and the formula's copper; a hunt also a choice of 2-3 materials
	-- of no vendor's shelf (no gear, no enchants); no reputation anywhere.
	local rewards = q.rewards or {}
	check(rewards.items == nil and rewards.copper == nil,
		"S " .. id .. " rewards XP and the formula's copper (no reputation, no fixed item)")
	if id:find("^camp_hunt_") then
		local choices = rewards.choices or {}
		check(#choices >= 2 and #choices <= 3, "S " .. id .. " a choice of 2-3 materials")
		for _, choice in ipairs(choices) do
			check(choice.affixes == nil and (choice.item:find("^grug_mobs:") or choice.item:find("_bar$")) ~= nil,
				"S " .. id .. " " .. choice.item .. " is a hunted material or a bar")
		end
	else
		eq(rewards.choices, nil, "S " .. id .. " no choice")
	end
	for _, variant in ipairs(q.variants) do
		for index, objective in ipairs(q.objectives) do
			if objective.type == "kill" then
				local area = (variant.objectives or {})[index] and variant.objectives[index].area or objective.area
				local zone, area_id = (area or ""):match("^([^/]+)/(.+)$")
				local spawns = zone and read_json(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json")
				local surface = false
				for _, belt in ipairs(spawns and spawns.recipe.belts or {}) do
					for _, kind in pairs(belt.kinds) do surface = surface or kind.id == area_id end
				end
				check(surface or (area_id or ""):find("^camp_site_") ~= nil,
					"S " .. id .. " " .. variant.zone .. " kills on the surface: " .. tostring(area))
			end
		end
	end
end
-- The camp zones' files keep their rework state: unflagged until their
-- rework (their chains stay), but the band 11-20's six, reworked in Round 59,
-- the band 21-30's eight, reworked in Round 60, and the band 31-40's six,
-- reworked in Round 61 (every camp zone now).
local BAND = {elandor_copperfell_foothills = 59, elandor_goldmead_vale = 59, elandor_starbough_vale = 59,
	kragmar_mournfen = 59, kragmar_redtusk_savanna = 59, kragmar_raincall_basin = 59,
	elandor_frostbarrow_shelf = 60, elandor_whitebridge_shire = 60, elandor_lorindor = 60,
	elandor_moonfall_wood = 60, kragmar_ossuary_reach = 60, kragmar_speargrass_reach = 60,
	kragmar_whispering_reedlands = 60, kragmar_totemwater_reach = 60,
	elandor_stormvault_heights = 61, elandor_ashenward_march = 61, elandor_glassroot_wilds = 61,
	kragmar_blackwind_rise = 61, kragmar_bannerbreak_mesa = 61, kragmar_thunderroot_wilds = 61}
for _, row in ipairs(catalog.mining) do
	eq(file_data[row.zone_id] and file_data[row.zone_id].reworked, BAND[row.zone_id] and true or nil,
		"S " .. row.zone_id .. (BAND[row.zone_id] and " is reworked (Round " .. BAND[row.zone_id] .. ")" or
			" keeps no rework flag"))
end

------------------------------------------------------------------------------
-- B. The real loader on seed 42.
------------------------------------------------------------------------------
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local RT = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, "42")
local socket_rows = RT.main.settlement_sockets(RT.built)
local layout = RT.main.placement_layout_text()
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local camps = dofile(wp40 .. "/r58_camps.lua").index(layout, {raw_sha256 = common.new_sha256(), full_seed = "42"})

-- A small engine under the quest code (tools/r56_questmap/model.lua's).
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
-- The registrations (tools/r28_q0 register_real): the engine dump's items,
-- aliases and entities, grug_mobs' sub-types and loot, the garrisons'.
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
check(pcall(Q.bind_role_givers), "B the foreman roles bind (one variant per NPC)")
do
	local ok, err = pcall(Q.validate_quest_data)
	check(ok, "B the load-time world checks pass: " .. tostring(err))
	ok, err = pcall(Q.validate_registry)
	check(ok, "B the registry checks pass: " .. tostring(err))
end

-- A player of one faction and level with a quest state.
local meta = {}
local player = {}
function player:get_player_name() return "gq" end
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
-- What `npc` offers this player: quest id -> status (nil when the NPC
-- refuses the player's faction, as the dialog does).
local function offers(npc)
	local row = Q.registered_npcs[npc]
	if not grug_factions.serves(row.faction, player) then return {} end
	local out = {}
	for _, entry in ipairs(Q.npc_quests(player, npc)) do out[entry.id] = entry.status end
	return out
end

eq(#camps.camps, 36, "B seed 42 has 36 camps with a lift")
local foremen = {}
for _, camp in ipairs(camps.camps) do
	local id = "r58_foreman_" .. camp.id
	if check(Q.registered_npcs[id] ~= nil, "B " .. id .. " registered") then
		foremen[#foremen + 1] = {id = id, camp = camp}
	end
end
-- Gather quests at every own camp of tier >= k, nowhere else.
for _, faction in ipairs(FACTIONS) do
	player_faction, player_level = faction, 60
	set_state()
	for _, row in ipairs(foremen) do
		local offered = offers(row.id)
		for _, tier in ipairs(TIERS) do
			for _, id in ipairs(gathers[tier]) do
				local want = row.camp.faction == faction and row.camp.tier >= tier
				eq(offered[id] == "available", want, ("B %s (%s, T%d) offers %s to the %s"):format(row.id,
					row.camp.faction, row.camp.tier, id, faction))
			end
			-- Locked for the follow-up's prerequisites: not listed.
			eq(offered[("guild_t%d_report_%s"):format(tier, faction)], nil,
				"B " .. row.id .. " lists no T" .. tier .. " follow-up before the gathers")
		end
	end
	-- Under the tier's level the gather quest is listed locked.
	player_level = 11
	for _, row in ipairs(foremen) do
		if row.camp.faction == faction and row.camp.tier == 6 then
			local offered = offers(row.id)
			eq(offered.guild_t2_iron, "available", "B a level-11 player is offered T2 at " .. row.id)
			eq(offered.guild_t6_crystal, "locked", "B a level-11 player sees T6 locked at " .. row.id)
		end
	end
	for capital in pairs(CAPITAL_RACE) do
		local offered = offers("r58_guild_leader_" .. capital)
		-- Round 59: a leader gives chapter 1's second story quest, hidden
		-- until the first is done; it gives no guild quest.
		eq(next(offered), nil, "B the leader of " .. capital .. " lists nothing before chapter 1's " ..
			"first quest (no guild quest of its own)")
	end
end

-- The follow-up: only after both gathers; at the camps of its tier and
-- deeper; turned in only at its variant's leader.
for _, faction in ipairs(FACTIONS) do
	player_faction, player_level = faction, 60
	for _, tier in ipairs(TIERS) do
		local report = ("guild_t%d_report_%s"):format(tier, faction)
		local one = {[gathers[tier][1]] = true}
		set_state(one)
		local listed = 0
		for _, row in ipairs(foremen) do
			if offers(row.id)[report] then listed = listed + 1 end
		end
		eq(listed, 0, "B " .. report .. " after one gather quest: offered nowhere")
		local both = {[gathers[tier][1]] = true, [gathers[tier][2]] = true}
		set_state(both)
		for _, row in ipairs(foremen) do
			local want = row.camp.faction == faction and row.camp.tier >= tier
			eq(offers(row.id)[report] == "available", want, ("B %s (%s, T%d) offers %s after both"):format(
				row.id, row.camp.faction, row.camp.tier, report))
		end
		-- Take it at one camp of each zone and turn it in.
		local def = Q.registered_quests[report]
		for _, row in ipairs(foremen) do
			if def.giver_variant[row.id] then
				set_state(both)
				check(Q.accept(player, report, row.id), "B " .. report .. " accepted at " .. row.id)
				local leader = leader_for(row.camp.zone_id, faction)
				for capital in pairs(CAPITAL_RACE) do
					local npc = "r58_guild_leader_" .. capital
					local status = offers(npc)[report]
					if npc == leader then
						eq(status, "ready", "B " .. report .. " from " .. row.id .. " is turned in at " .. npc)
					else
						eq(status, nil, "B " .. report .. " from " .. row.id .. " is not turned in at " .. npc)
					end
				end
			end
		end
	end
end

-- The hand-in marker (journal row npc, Q.turnin_for): a role quest returns
-- to the foreman it was taken from, a follow-up to its leader.
for _, faction in ipairs(FACTIONS) do
	player_faction, player_level = faction, 60
	for _, row in ipairs(foremen) do
		if row.camp.faction == faction and (row.camp.tier == 2 or row.camp.tier == 5) then
			set_state()
			check(Q.accept(player, "guild_t2_iron", row.id), "B guild_t2_iron accepted at " .. row.id)
			local npc
			for _, entry in ipairs(Q.journal(player).quests) do
				if entry.id == "guild_t2_iron" then npc = entry.npc end
			end
			eq(npc, row.id, "B guild_t2_iron taken at " .. row.id .. " returns there")
		end
	end
	local report = "guild_t2_report_" .. faction
	for _, row in ipairs(foremen) do
		if row.camp.faction == faction and row.camp.tier == 5 then
			set_state({[gathers[2][1]] = true, [gathers[2][2]] = true})
			check(Q.accept(player, report, row.id), "B " .. report .. " accepted at " .. row.id)
			local npc
			for _, entry in ipairs(Q.journal(player).quests) do
				if entry.id == report then npc = entry.npc end
			end
			eq(npc, leader_for(row.camp.zone_id, faction), "B " .. report .. " from " .. row.id .. " returns to its leader")
		end
	end
end

-- Each camp's hunt and each T4 foreman's raid at that foreman.
player_level = 60
for _, row in ipairs(foremen) do
	player_faction = row.camp.faction
	set_state()
	local offered = offers(row.id)
	local hunt = hunt_of[row.id]
	eq(offered[hunt or "?"], "available", "B " .. row.id .. " offers its hunt " .. tostring(hunt))
	local hunts_here = 0
	for id in pairs(offered) do
		if id:find("^camp_hunt_") then hunts_here = hunts_here + 1 end
	end
	eq(hunts_here, 1, "B " .. row.id .. " offers one hunt")
	local has_site = false
	for _, site in ipairs(camps.under_construction) do has_site = has_site or site.zone_id == row.camp.zone_id end
	eq(offered.camp_site_raid == "available", row.camp.tier == 4 and has_site,
		"B " .. row.id .. " offers the raid only at a T4 camp by a camp under construction")
	-- All of a camp's quests at once: every one of them is available.
	local all_open = true
	for _, status in pairs(offered) do all_open = all_open and status == "available" end
	check(all_open, "B " .. row.id .. " offers all its quests at once")
end
-- The raid's guards and captain are named on this world (the captain by his
-- camp's race, the guards by their names slot).
for _, variant in ipairs(Q.registered_quests.camp_site_raid.variants) do
	for index, what in ipairs({"guards", "captain"}) do
		local names = variant.objectives[index].names -- per role, its names
		check(type(names) == "table" and #names == 1 and #names[1] == 1 and type(names[1][1]) == "string",
			"B the raid in " .. variant.zone .. " counts its " .. what .. " by one name")
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

if failures > 0 then
	error(("R58 GUILDQUESTS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
end
print(("R58 GUILDQUESTS PORTABLE PASS checks=%d"):format(checks))
