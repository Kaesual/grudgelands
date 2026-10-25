-- Round 60 lane BANDQUESTS portable test (LuaJIT): the band 21-30's eight
-- shipped quest files on the Round 57 quest foundation (round60-plan.md §2,
-- §2a, §3, §4 BANDQUESTS; quests.md "The band 21-30"), with the REAL
-- grug_gear and grug_quality for the reward stacks, the REAL
-- grug_mobs/subtypes.lua for the quest items and the REAL
-- grug_housing/soulbound.lua for their guard:
--   A. the files: all eight reworked, the quests each zone offers, every
--      shared quest in its first variant's file with one variant per zone
--      that gives it; the Round 58 guild quests kept;
--   B. free play and the story: a free quest requires nothing; only
--      chapter 2's story quests chain (A3 after A2, A4 after A3 and Nib's
--      free quest, T2a after T2); no free quest of the band is followed by
--      another but Nib's by A4; the band's first quests (min 20) require
--      nothing; the levels lie in the band;
--   C. the kept ids (the three cross-lane ids, the departures, the travels,
--      the leaders' kills) with their objectives; the departures free;
--   D. few mob names per zone (at most three);
--   E. no reward is a requested item;
--   F. the reward pattern per zone (the early potion choice, two armor
--      choices on two slots with one enchant, the leader's weapon choice),
--      each faction's four zones give every armor slot at least twice, no
--      shared quest rewards equipment;
--   G. the use places: every town place a quest_place socket of the named
--      settlement (built from its blueprint), every recipe place one of
--      the zone's spawn file, every object a kind of use_objects.json;
--   H. the line plan: the givers' lines as the chapter check planned;
--   I. the Dispatch Folio: a quest item of items.json, registered soulbound
--      with the Captain's Orders, refused by a chest and the trash, lost
--      when dropped; Nib's quest drops it every kill (chance 1);
--   J. build_structure.py --check: the files' structure is the script's.
-- Offering and taking the shipped quests through the real grug_quests (a
-- shared quest done in one zone is offered in no other; A4 only after A3 and
-- Nib) is tools/r28_q0's section 5; the full-inventory rule of the quest
-- drop (no roll while it would not fit) is tools/r28_b4_quests'.
--
--   luajit tools/r60_bandquests/portable_test.lua [REPO]
-- Prints "R60 BANDQUESTS PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local ROOT = arg and arg[1] or "."
local json = dofile(ROOT .. "/tools/r28_b4_quests/json.lua")
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
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read_file(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
local function read_json(path)
	local text = read_file(path)
	return text and json.decode(text) or nil
end
function table.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = table.copy(child) end
	return out
end

------------------------------------------------------------------------------
-- Engine stub (tools/r59_bandquests'): the real grug_gear and grug_quality.
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function() return function() end end})
end
local modpaths = {grug_gear = ROOT .. "/mods/ITEMS/grug_gear", grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
	grug_mobs = ROOT .. "/mods/ENTITIES/grug_mobs"}
local current_mod = "grug_gear"
local serial = {}
core = permissive({
	register_on_mods_loaded = function() end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do registered[name][key] = value end
	end,
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	serialize = function(value) serial[#serial + 1] = table.copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and table.copy(serial[index]) or nil
	end,
	get_us_time = function() return 1 end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
})
local fed = {}
grug_core = permissive({level_scale = function() return 1 end,
	feed = function(_, kind, text) fed[#fed + 1] = kind .. ": " .. text end})
grug_classes = permissive({get_melee_bonus = function() return 0 end,
	pool_percent_amount = function() return 42 end})
grug_mobs = permissive({register_kill_loot_hook = function() end, register_boss_reward_hook = function() end,
	subtype = function() return nil end, pvp_garrison = {pvp_kind = function() return nil end}})
grug_inventory = permissive({})
grug_xp = permissive({get_level = function() return 60 end})
local function new_meta(fields)
	local store = {}
	for key, value in pairs(fields or {}) do store[key] = value end
	local meta = {fields = store}
	function meta:get_string(key) return store[key] or "" end
	function meta:set_string(key, value)
		if value == "" then store[key] = nil else store[key] = value end
	end
	function meta:get_int(key) return math.floor(tonumber(store[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
local function new_stack(name, fields, count)
	local meta = new_meta(fields)
	count = count or (name == "" and 0 or 1)
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" or count == 0 end
	function stack:get_count() return count end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return 0 end
	function stack:get_short_description() return (registered[name] or {}).short_description end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	return stack
end
ItemStack = function(value)
	if type(value) == "table" then
		return new_stack(value:get_name(), value:get_meta().fields, value:get_count())
	end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)$")
	return new_stack(name, nil, tonumber(count))
end
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	local function step() state = (state * 48271) % 2147483647 end
	step(); step(); step()
	return {next = function(_, low, high)
		step()
		return low + state % (high - low + 1)
	end}
end
dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
grug_jobs = {PROFESSIONS = {}, station_info = function(station) return {id = station} end,
	_flatten_inputs = function() return {} end, ingredient_list = function() return {} end}
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")

-- Item groups of everything else: the engine dump.
local existing = read_json("docs/planning/round28/items/existing.json")
local function in_group(item, group)
	local row = existing.items[item]
	return row ~= nil and (row.groups or {})[group] ~= nil and row.groups[group] > 0
end

------------------------------------------------------------------------------
-- A. The files.
------------------------------------------------------------------------------
-- zone, faction, named leader (the weapon's kill), weapon level
local ZONES = {
	{"elandor_frostbarrow_shelf", "accord", "powder_counter_nib", 29},
	{"elandor_whitebridge_shire", "accord", "ferryman_murk", 29},
	{"elandor_lorindor", "accord", "pearl_counter_iss", 29},
	{"elandor_moonfall_wood", "accord", "snarewarden_bracken", 29},
	{"kragmar_ossuary_reach", "throng", "marrow_archivist", 28},
	{"kragmar_speargrass_reach", "throng", "banner_broker_rakk", 29},
	{"kragmar_whispering_reedlands", "throng", "tollkeeper_ush", 29},
	{"kragmar_totemwater_reach", "throng", "reed_maw_crocodile", 29},
}
local BAND, FACTION = {}, {}
for _, row in ipairs(ZONES) do BAND[row[1]], FACTION[row[1]] = true, row[2] end
-- Round 58's quests in these files, kept as shipped (miners_guild.md §11).
local GUILD = {guild_t3_report_accord = true, guild_t3_report_throng = true, camp_hunt_t3 = true,
	camp_hunt_t3_night = true}
local STORY = {story_accord_03 = {"story_accord_02"}, story_accord_04 = {"frostbarrow_cutting_04", "story_accord_03"},
	story_throng_03 = {"story_throng_02"}}
local NPC = {kelda = "r20_anchor_061_host", halen = "r20_anchor_062_host", saevin = "r20_anchor_063_host",
	neris = "r20_anchor_064_host", gorren = "r20_anchor_065_host", zali = "r20_anchor_066_host",
	hedra = "r20_anchor_026_host", orya = "r20_anchor_034_host", lethen = "r20_anchor_035_host",
	tokai = "r20_anchor_047_host", merren = "r20_anchor_016_host", brakka = "r20_anchor_022_host",
	varda = "r20_dwarf_capital_cook", mereth = "r20_anchor_038_host",
	rellis = "r58_foreman_mining_camp_ossuary_reach", brodd = "r58_foreman_mining_camp_frostbarrow_shelf"}
-- The shared quests: their variants' zones and givers, in order.
local SHARED = {
	band_steel = {{"elandor_frostbarrow_shelf", "kelda"}, {"elandor_whitebridge_shire", "halen"},
		{"elandor_lorindor", "saevin"}, {"kragmar_ossuary_reach", "neris"}, {"kragmar_speargrass_reach", "gorren"},
		{"kragmar_whispering_reedlands", "zali"}},
	band_shore_pinchers = {{"elandor_frostbarrow_shelf", "hedra"}, {"elandor_lorindor", "orya"},
		{"elandor_moonfall_wood", "lethen"}, {"kragmar_totemwater_reach", "tokai"}},
	band_snares = {{"elandor_lorindor", "orya"}, {"elandor_moonfall_wood", "lethen"}},
	band_corn = {{"elandor_whitebridge_shire", "merren"}, {"kragmar_speargrass_reach", "brakka"}},
	band_planks = {{"elandor_moonfall_wood", "lethen"}, {"kragmar_totemwater_reach", "tokai"}},
	band_mire_carp = {{"kragmar_totemwater_reach", "tokai"}, {"elandor_dur_brannoc", "varda"}},
}
local DIR = "mods/PLAYER/grug_quests/data/zones/"
local files, by_id, offered = {}, {}, {}
for _, row in ipairs(ZONES) do
	local data = read_json(DIR .. row[1] .. ".quests.json")
	files[row[1]] = data
	check(data and data.reworked == true, row[1] .. ": marked reworked")
	offered[row[1]] = {}
end
local shared_count, local_count = 0, 0
for _, row in ipairs(ZONES) do
	local zone = row[1]
	for _, quest in ipairs(files[zone].quests) do
		by_id[quest.id] = {quest = quest, file = zone}
		if quest.variants then
			local want = SHARED[quest.id]
			if want then
				shared_count = shared_count + 1
				eq(quest.variants[1].zone, zone, quest.id .. ": lives in its first variant's file")
				eq(#quest.variants, #want, quest.id .. ": one variant per zone that gives it")
				for index, variant in ipairs(quest.variants) do
					local expect = want[index] or {}
					eq(variant.zone, expect[1], quest.id .. ": variant " .. index .. "'s zone")
					check(#variant.givers == 1 and variant.givers[1] == NPC[expect[2]],
						quest.id .. ": given in " .. tostring(expect[1]) .. " by " .. tostring(expect[2]))
				end
			elseif not GUILD[quest.id] then
				local_count = local_count + 1
				eq(quest.id, "ossuary_rubbings_03", quest.id .. ": the one local quest with variants")
			end
			for _, variant in ipairs(quest.variants) do
				if BAND[variant.zone] then table.insert(offered[variant.zone], quest) end
			end
		else
			local_count = local_count + 1
			table.insert(offered[zone], quest)
		end
	end
end
eq(shared_count, 6, "six shared quests (steel, shore, snares, corn, planks, fish)")
-- The guild reports and camp hunts homed elsewhere still list a band variant.
for _, row in ipairs(ZONES) do
	local report = "guild_t3_report_" .. row[2]
	local found, hunt = false, false
	for _, quest in ipairs(offered[row[1]]) do
		found = found or quest.id == report
		hunt = hunt or quest.id:find("^camp_hunt_t3") ~= nil
	end
	check(found, row[1] .. ": offers " .. report)
	check(hunt, row[1] .. ": offers its camp hunt")
end

-- Every quest file, for the follow-ups across files.
local followers = {}
do
	local handle = io.popen('ls "' .. ROOT .. '/' .. DIR .. '"')
	for name in handle:lines() do
		local data = read_json(DIR .. name)
		for _, quest in ipairs(data and data.quests or {}) do
			for _, id in ipairs(quest.requires or {}) do
				followers[id] = followers[id] or {}
				table.insert(followers[id], quest.id)
			end
		end
	end
	handle:close()
end

------------------------------------------------------------------------------
-- B. Free play and the story.
------------------------------------------------------------------------------
-- Round 60 CAPITALS (merged after this lane): T3 (story_throng_04, Nhal
-- Veyr) follows T2a and takes ossuary_rubbings_03's one Throng slot.
-- Round 61 BANDQUESTS: chapter 3's A5 (story_accord_05, Ashenward March)
-- follows A4.
local ALLOWED_FOLLOWERS = {frostbarrow_cutting_04 = "story_accord_04", story_accord_03 = "story_accord_04",
	story_throng_03 = "story_throng_04", ossuary_rubbings_03 = "story_throng_04", story_accord_04 = "story_accord_05"}
for id, entry in pairs(by_id) do
	local quest = entry.quest
	local follow = table.concat(followers[id] or {}, ",")
	if GUILD[id] then
		check(id:find("^guild_") == nil or quest.story == true, id .. ": the guild report stays a story quest")
	elseif STORY[id] then
		eq(quest.story, true, id .. ": a story quest")
		local req = table.copy(quest.requires or {})
		table.sort(req)
		eq(table.concat(req, ","), table.concat(STORY[id], ","), id .. ": its story prerequisites")
		eq(follow, ALLOWED_FOLLOWERS[id] or "", id .. ": its follow-ups in the band files")
	else
		check(not quest.story, id .. ": free play")
		eq(#(quest.requires or {}), 0, id .. ": requires nothing but a level")
		eq(follow, ALLOWED_FOLLOWERS[id] or "", id .. ": its one follow-up at most (" .. follow .. ")")
	end
	if not GUILD[id] then
		check(quest.level >= 21 and quest.level <= 30 and quest.min_level >= 20 and quest.min_level <= quest.level,
			id .. ": levels within the band (" .. tostring(quest.min_level) .. "/" .. tostring(quest.level) .. ")")
	end
end
-- A3, A4 and T2a: givers, places and turn-ins of chapter 2 (draft §5).
do
	local a3, a4, t2a = by_id.story_accord_03, by_id.story_accord_04, by_id.story_throng_03
	if check(a3 and a4 and t2a, "chapter 2's three band steps ship") then
		eq(a3.quest.giver .. ">" .. a3.quest.turnin, NPC.brodd .. ">" .. NPC.kelda, "A3: Brodd to Kelda")
		eq(#a3.quest.objectives, 2, "A3: two uses")
		local kinds = {}
		for _, objective in ipairs(a3.quest.objectives) do
			eq(objective.place, "socket:mining_camp_frostbarrow_shelf/held_load", "A3: at the held load")
			kinds[#kinds + 1] = objective.object
		end
		table.sort(kinds)
		eq(table.concat(kinds, ","), "dispatch_record,held_supplies", "A3: the record and the load")
		eq(a3.quest.level, 25, "A3 at 24 (reward level 25)")
		eq(a4.quest.giver .. ">" .. a4.quest.turnin, NPC.kelda .. ">r58_guild_leader_dur_brannoc",
			"A4: Kelda to Hadrin")
		eq(a4.quest.min_level, 29, "A4 at 29")
		eq(t2a.quest.giver .. ">" .. t2a.quest.turnin, NPC.rellis .. ">" .. NPC.mereth, "T2a: Rellis to Mereth")
		eq(t2a.quest.objectives[1].object .. "@" .. t2a.quest.objectives[1].place, "witness_record@claim_rest",
			"T2a: the witness record at the claim rest")
	end
end
-- The band's first quests: a level-21 character finds quests at once.
for _, row in ipairs(ZONES) do
	local first = 99
	for _, quest in ipairs(offered[row[1]]) do
		if not quest.story and #(quest.requires or {}) == 0 and quest.min_level < first then first = quest.min_level end
	end
	eq(first, 20, row[1] .. ": its first quests open at level 20")
end

------------------------------------------------------------------------------
-- C. The kept ids.
------------------------------------------------------------------------------
local KEPT = {
	-- the cross-lane ids (round60-plan.md §3)
	frostbarrow_cutting_04 = "kill:powder_counter_nib", ossuary_rubbings_03 = "talk:r20_anchor_064_host",
	-- the departures
	frostbarrow_departure = "talk:r20_anchor_027_host", whitebridge_materials_02 = "talk:r20_anchor_027_host",
	lorindor_berries_04 = "talk:r20_anchor_031_host", moonfall_snares_04 = "talk:r20_anchor_036_host",
	ossuary_dig_04 = "talk:r20_anchor_039_host", speargrass_watch_03 = "talk:r20_anchor_039_host",
	whispering_front_bannerbreak = "talk:r20_anchor_044_host", totemwater_front_bannerbreak = "talk:r20_anchor_044_host",
	-- the travels
	frostbarrow_sleds_hedra = "talk:r20_anchor_026_host", frostbarrow_sleds_02 = "talk:r20_anchor_061_host",
	whitebridge_journey_lorindor = "talk:r20_anchor_018_host", whitebridge_journey_dur_brannoc = "talk:r20_dwarf_capital_envoy",
	whitebridge_journey_frostbarrow = "talk:r20_anchor_014_host", lorindor_journeys_01 = "talk:r20_human_capital_envoy",
	lorindor_journeys_02 = "talk:r20_anchor_016_host", lorindor_cutting_02 = "talk:r20_anchor_061_host",
	ossuary_names_02 = "talk:r20_anchor_038_host", speargrass_journeys_01 = "talk:r20_undead_capital_envoy",
	whispering_journey_speargrass = "talk:r20_anchor_022_host", whispering_journey_ossuary = "talk:r20_anchor_020_host",
	-- kills and an item whose objectives stayed
	whitebridge_baskets_03 = "kill:basket_poacher_thorn", whitebridge_river_02 = "kill:ferryman_murk",
	moonfall_snares_03 = "kill:snarewarden_bracken", whispering_voice_02 = "kill:tollkeeper_ush",
	totemwater_knots_04 = "kill:reed_maw_crocodile", ossuary_names_01 = "kill:briarpack_wolf",
	whispering_cut_01 = "kill:reed_crocodile", speargrass_yard_02 = "item:grug_mobs:shearing_cat_claw",
}
local function objective_key(objective)
	if objective.type == "kill" then return "kill:" .. table.concat(objective.roles, ",") end
	if objective.type == "talk" then return "talk:" .. objective.npc end
	if objective.type == "item" then return "item:" .. tostring(objective.item or objective.group) end
	return objective.type
end
for id, want in pairs(KEPT) do
	local entry = by_id[id]
	if check(entry ~= nil, id .. ": the kept id ships") then
		eq(objective_key(entry.quest.objectives[1]), want, id .. ": its first objective stays")
		if want:find("^talk:") then
			eq(#entry.quest.objectives, 1, id .. ": a travel quest, one objective")
		end
	end
end
-- ossuary_rubbings_03: Mereth's, Rellis a second giver; its Throng follow-up
-- slot belongs to lane CAPITALS' T3.
do
	local q = by_id.ossuary_rubbings_03 and by_id.ossuary_rubbings_03.quest
	if check(q and q.variants and #q.variants == 1, "ossuary_rubbings_03: one variant") then
		local givers = table.copy(q.variants[1].givers)
		table.sort(givers)
		eq(table.concat(givers, ","), NPC.mereth .. "," .. NPC.rellis, "ossuary_rubbings_03: Mereth and Rellis give it")
		eq(table.concat(q.variants[1].turnins or {}, ","), NPC.neris, "ossuary_rubbings_03: turned in at Neris")
	end
	eq(table.concat(followers.ossuary_rubbings_03 or {}, ","), "story_throng_04",
		"ossuary_rubbings_03: its one Throng follow-up is CAPITALS' T3")
end

------------------------------------------------------------------------------
-- D. Few mobs per zone (by role: a role's name may differ by belt).
------------------------------------------------------------------------------
local names = read_json("mods/ENTITIES/grug_mobs/data/names.json").names
local function names_of(zone, role)
	local out = {}
	for slot, name in pairs(names) do
		local z, r = slot:match("^([^/]+)/([^/]+)/")
		if z == zone and r == role then out[name] = true end
	end
	return out
end
local function variant_of(quest, zone)
	for _, variant in ipairs(quest.variants or {}) do
		if variant.zone == zone then return variant end
	end
end
for _, row in ipairs(ZONES) do
	local zone, kill_roles, kills, all = row[1], {}, 0, 0
	for _, quest in ipairs(offered[zone]) do
		local variant = variant_of(quest, zone)
		for index, objective in ipairs(quest.objectives) do
			all = all + 1
			if objective.type == "kill" then
				kills = kills + 1
				local own = variant and variant.objectives and variant.objectives[index]
				for _, role in ipairs(own and own.roles or objective.roles) do
					check(next(names_of(zone, role)) ~= nil, zone .. ": " .. role .. " has a name there")
					kill_roles[role] = true
				end
			end
		end
	end
	local count = 0
	for _ in pairs(kill_roles) do count = count + 1 end
	check(count >= 2 and count <= 3, zone .. ": two or three mobs in its kill objectives (" .. count .. ")")
	check(kills <= 3, zone .. ": at most three kill objectives (" .. kills .. " of " .. all .. ")")
end

------------------------------------------------------------------------------
-- E. No reward is a requested item.
------------------------------------------------------------------------------
for id, entry in pairs(by_id) do
	local quest, rewarded = entry.quest, {}
	for _, row in ipairs(quest.rewards.items or {}) do rewarded[#rewarded + 1] = row.item end
	for _, row in ipairs(quest.rewards.choices or {}) do rewarded[#rewarded + 1] = row.item end
	for _, objective in ipairs(quest.objectives) do
		if objective.type == "item" then
			for _, item in ipairs(rewarded) do
				check(item ~= objective.item and not (objective.group and in_group(item, objective.group)),
					id .. ": the reward " .. item .. " is not what it asks for")
			end
		end
	end
end

------------------------------------------------------------------------------
-- F. The reward pattern per zone.
------------------------------------------------------------------------------
local HEALING, MANA = "grug_alchemy:potion_healing_t3", "grug_alchemy:potion_mana_t3"
local function slot_of(item)
	local groups = (registered[item] or {}).groups or {}
	for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
		if (groups["grug_equip_" .. slot] or 0) > 0 then return slot end
	end
end
local function line_of(item)
	local family = grug_gear.weapon_family(ItemStack(item))
	if family == "staff" or family == "wand" then return "caster" end
	if family == "bow" then return "scout" end
	if family == "sword" or family == "greataxe" then return "warrior" end
end
local function stacks_ok(id, quest)
	for index, choice in ipairs(quest.rewards.choices) do
		local label = ("%s choice %d (%s)"):format(id, index, choice.item)
		check(choice.item:find("_steel$") or choice.item:find("_heavy$"), label .. ": a tier-3 piece")
		local ok, reason = grug_items.check_affixes(choice.item, choice.affixes or {})
		check(ok, label .. ": enchants in the pool: " .. tostring(reason))
		local stack = ok and grug_items.make_stack(choice.item, quest.level, choice.affixes)
		if stack then
			eq(stack:get_meta():get_int("grug_ilvl"), quest.level, label .. ": item level = reward level")
			eq(#grug_items.get_affixes(stack), #choice.affixes, label .. ": its enchants")
			eq(grug_items.enchant_tier(quest.level), 3, label .. ": enchant tier 3")
		end
	end
end
for id in pairs(SHARED) do
	local quest = by_id[id] and by_id[id].quest
	for _, choice in ipairs(quest and quest.rewards.choices or {}) do
		eq(#(choice.affixes or {}), 0, id .. ": a shared quest rewards no equipment (" .. choice.item .. ")")
	end
end
local slots_by_faction = {accord = {}, throng = {}}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	local potions, armor, weapons = {}, {}, {}
	for _, quest in ipairs(offered[zone]) do
		local choices = quest.rewards.choices
		if choices and not GUILD[quest.id] and not quest.story then
			local enchants = #(choices[1].affixes or {})
			if choices[1].item == HEALING or choices[1].item == MANA then
				potions[#potions + 1] = quest
			elseif enchants == 1 then
				armor[#armor + 1] = quest
			elseif enchants == 2 then
				weapons[#weapons + 1] = quest
			end
		end
	end
	eq(#potions, 1, zone .. ": one potion choice")
	local p = potions[1]
	if p then
		check(p.min_level == 20 and p.level >= 21, zone .. ": the potion choice is early, at reward level 21+ (" ..
			p.id .. ")")
		local set = {}
		for _, choice in ipairs(p.rewards.choices) do set[choice.item .. " " .. (choice.count or 1)] = true end
		check(#p.rewards.choices == 2 and set[HEALING .. " 2"] and set[MANA .. " 2"],
			zone .. ": 2 Healing Potion III or 2 Mana Potion III")
	end
	eq(#armor, 2, zone .. ": two armor choices with one enchant")
	table.sort(armor, function(a, b) return a.level < b.level end)
	if #armor == 2 then
		check(armor[1].level < armor[2].level, zone .. ": the two armor choices at two levels")
		local slots = {}
		for index, quest in ipairs(armor) do
			local classes, slot = {}, nil
			eq(#quest.rewards.choices, 3, quest.id .. ": three entries")
			for _, choice in ipairs(quest.rewards.choices) do
				local rank = ((registered[choice.item] or {}).groups or {}).grug_armor_class
				if rank then classes[rank] = true end
				slot = slot or slot_of(choice.item)
				eq(slot_of(choice.item), slot, quest.id .. ": one slot")
				eq((choice.affixes or {{}})[1].channel, index == 1 and "prefix" or "suffix",
					quest.id .. ": " .. (index == 1 and "a prefix" or "a suffix") .. " on " .. choice.item)
			end
			check(classes[1] and classes[2] and classes[3], quest.id .. ": cloth, leather and metal")
			check(not quest.variants, quest.id .. ": a local quest")
			slots[index] = slot
			if slot then
				local seen = slots_by_faction[row[2]]
				seen[slot] = (seen[slot] or 0) + 1
			end
			stacks_ok(quest.id, quest)
		end
		check(slots[1] and slots[1] ~= slots[2], zone .. ": the two armor choices are two slots")
	end
	eq(#weapons, 1, zone .. ": one weapon choice")
	local w = weapons[1]
	if w then
		eq(w.level, row[4], zone .. ": the weapon choice at the zone's end")
		local kills_leader = false
		for _, objective in ipairs(w.objectives) do
			for _, role in ipairs(objective.roles or {}) do kills_leader = kills_leader or role == row[3] end
		end
		check(kills_leader, zone .. ": the weapon is the named leader's")
		local lines = {}
		for _, choice in ipairs(w.rewards.choices) do
			local line = line_of(choice.item)
			check(line and not lines[line], w.id .. ": one weapon per line (" .. choice.item .. ")")
			if line then lines[line] = true end
			local channels = {}
			for _, affix in ipairs(choice.affixes or {}) do channels[affix.channel] = true end
			check(channels.prefix and channels.suffix, w.id .. ": prefix and suffix on " .. choice.item)
		end
		stacks_ok(w.id, w)
	end
end
for faction, slots in pairs(slots_by_faction) do
	for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
		check((slots[slot] or 0) >= 2, faction .. ": the " .. slot .. " slot at least twice (" ..
			tostring(slots[slot]) .. ")")
	end
end

------------------------------------------------------------------------------
-- G. The use places.
------------------------------------------------------------------------------
local objects = read_json("mods/PLAYER/grug_quests/data/use_objects.json")
local places = dofile(ROOT .. "/tools/r59_qsys3/socket_places.lua")
local uses = 0
for id, entry in pairs(by_id) do
	local quest = entry.quest
	for index, objective in ipairs(quest.objectives) do
		if objective.type == "use" then
			check(objects[objective.object] ~= nil, id .. ": object " .. tostring(objective.object) .. " is a kind")
			local rows = quest.variants or {{zone = entry.file}}
			for _, variant in ipairs(rows) do
				uses = uses + 1
				local own = variant.objectives and variant.objectives[index] and variant.objectives[index].place
				local place = own or objective.place
				local key, socket_id = places.parse_ref(place)
				if key then
					local found = places.sockets(ROOT, {key})[key]
					eq(found and found.zone_id, variant.zone, id .. ": " .. place .. " stands in " .. variant.zone)
					local role
					for _, socket in ipairs(found and found.sockets or {}) do
						if socket.id == socket_id then role = socket.role end
					end
					eq(role, "quest_place", id .. ": " .. place .. " is a quest_place socket")
				else
					local zone, place_id = place:match("^([^/]+)/(.+)$")
					zone, place_id = zone or variant.zone, place_id or place
					eq(zone, variant.zone, id .. ": " .. place .. " is a place of its own zone")
					local recipe = read_json("mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json").recipe
					local found
					for _, row in ipairs(recipe.places or {}) do found = found or row.id == place_id end
					check(found, id .. ": " .. place .. " is a quest place of " .. zone .. "'s recipe")
				end
			end
		end
	end
end
eq(uses, 11, "eleven uses at a place, a shared quest's per variant (A3's two, the signal, the basket check, " ..
	"two snare grounds, the sighting post, T2a, the banners, the seized stores, the reading cord)")
for _, kind in ipairs({"signal_lantern", "sighting_frame", "reading_knots", "claim_notice"}) do
	check(objects[kind] ~= nil, "use_objects: the new kind " .. kind)
end

------------------------------------------------------------------------------
-- H. The line plan (the chapter check).
------------------------------------------------------------------------------
local LINES = {
	r20_anchor_026_host = "watch,shore", r20_anchor_034_host = "wardenry,shore", r20_anchor_035_host = "stars,shore",
	r20_anchor_047_host = "shore,provisions", r20_anchor_038_host = "rubbings,camp",
	r20_anchor_061_host = "cutting,steel", r20_anchor_062_host = "materials,steel", r20_anchor_063_host = "cutting,steel",
	r20_anchor_064_host = "dig,steel", r20_anchor_065_host = "yard,steel", r20_anchor_066_host = "cut,steel",
}
local lines_of = {}
for _, row in ipairs(ZONES) do
	for _, hub in ipairs(files[row[1]].hubs) do
		for _, giver in ipairs(hub.givers) do
			lines_of[giver.npc] = table.concat(giver.lines, ",")
			check(#giver.lines <= 2, giver.npc .. ": at most two lines")
		end
	end
end
for npc, want in pairs(LINES) do eq(lines_of[npc], want, npc .. ": its lines") end
eq(by_id.band_mire_carp and by_id.band_mire_carp.quest.line, "provisions", "the fish rides on Tokai's and Varda's provisions")

------------------------------------------------------------------------------
-- I. The Dispatch Folio and the quest items' guard.
------------------------------------------------------------------------------
local FOLIO = "grug_mobs:dispatch_folio"
do
	local row
	for _, item in ipairs(read_json("mods/ENTITIES/grug_mobs/data/items.json")) do
		if item.id == FOLIO then row = item end
	end
	check(row and row.kind == "quest", "the Folio is a quest item of items.json")
	eq(read_file("mods/ENTITIES/grug_mobs/data/items.json"),
		read_file("docs/planning/round28/design/catalog/items.json"), "the design catalogue mirrors items.json")
	local nib = by_id.frostbarrow_cutting_04 and by_id.frostbarrow_cutting_04.quest
	local drop = nib and (nib.quest_drops or {})[1]
	check(drop and drop.item == FOLIO and drop.chance == 1 and drop.roles[1] == "powder_counter_nib",
		"Nib drops the Folio every kill while needed")
	local pairs_with = false
	for _, objective in ipairs(nib and nib.objectives or {}) do
		pairs_with = pairs_with or (objective.type == "item" and objective.item == FOLIO and objective.count == 1)
	end
	check(pairs_with, "Nib's quest asks for the one Folio")
end
-- The real subtypes.lua registers the quest items (its stub: tools/r36_q0's).
do
	local saved = {core = core, grug_mobs = grug_mobs}
	local items = {}
	core = {
		registered_items = items, registered_entities = {},
		get_modpath = function() return modpaths.grug_mobs end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function() return {} end,
		parse_json = function(text) return (json.decode(text)) end,
		register_craftitem = function(name, def) items[name] = def end,
		register_on_mods_loaded = function() end,
		colorize = function(_, text) return text end,
	}
	grug_zones = {id_at = function() return "elandor_frostbarrow_shelf" end}
	grug_mobs = {
		LEADER = {size = 1.15, hp = 1.5},
		copy_base_def = function() return {attack_type = "dogfight", textures = {{"blank.png", "base.png"}}} end,
		disposition = function() return "aggressive" end,
		register_disposition = function() end,
		register_mob = function() end,
		set_base_texture = function() end,
	}
	dofile(modpaths.grug_mobs .. "/subtypes.lua")
	for _, id in ipairs({FOLIO, "grug_mobs:accord_captains_orders", "grug_mobs:throng_captains_orders"}) do
		local def = items[id]
		if check(def ~= nil, id .. " registers") then
			eq((def.groups or {}).grug_soulbound, 1, id .. " is soulbound")
			check(type(def.on_drop) == "function", id .. " has its own drop")
			registered[id] = def
		end
	end
	local signature = items["grug_mobs:etched_bone"]
	check(signature and (signature.groups or {}).grug_soulbound == nil, "a signature item stays tradable")
	-- Dropping one destroys it, with a feed notice.
	local dropper = {is_player = function() return true end, get_player_name = function() return "ann" end}
	fed = {}
	local def = items[FOLIO]
	local rest = def and def.on_drop(ItemStack(FOLIO), dropper, {x = 0, y = 0, z = 0})
	check(rest and rest:is_empty(), "a dropped Folio is gone, nothing lands on the ground")
	check(fed[1] and fed[1]:find("^notice: Dispatch Folio is lost") ~= nil, "the feed says so (" .. tostring(fed[1]) .. ")")
	core, grug_mobs = saved.core, saved.grug_mobs
end
-- The soulbound guard (grug_housing/soulbound.lua) refuses the Folio
-- outside the carried lists: a chest, a station, the trash.
do
	local saved = core
	local allow, detached_callbacks, nodes = nil, nil, {["default:chest"] = {}}
	core = permissive({
		get_item_group = saved.get_item_group,
		register_allow_player_inventory_action = function(fn) allow = fn end,
		registered_nodes = nodes,
		override_item = function(name, fields) for k, v in pairs(fields) do nodes[name][k] = v end end,
		create_detached_inventory = function(_, callbacks) detached_callbacks = callbacks end,
		register_on_mods_loaded = function(fn) fn() end,
		detached_inventories = {},
		get_meta = function() return {get_inventory = function() return {get_stack = function() return ItemStack(FOLIO) end} end} end,
	})
	grug_housing = {}
	dofile(ROOT .. "/mods/PLAYER/grug_housing/soulbound.lua")
	local folio = ItemStack(FOLIO)
	eq(allow(nil, "put", nil, {listname = "grug_bag1_content", stack = folio}), nil, "the Folio goes into a bag")
	eq(allow(nil, "put", nil, {listname = "craft", stack = folio}), 0, "the craft grid refuses it")
	eq(nodes["default:chest"].allow_metadata_inventory_put(nil, "main", 1, folio, nil), 0, "a chest refuses it")
	core.create_detached_inventory("trash", {})
	eq(detached_callbacks and detached_callbacks.allow_put(nil, "main", 1, folio, nil), 0, "the trash refuses it")
	core = saved
end

------------------------------------------------------------------------------
-- J. The generator's structure check.
------------------------------------------------------------------------------
do
	local handle = io.popen("cd '" .. ROOT .. "' && python3 tools/r60_bandquests/build_structure.py --check 2>&1")
	local out = handle:read("*a")
	handle:close()
	check(out:find("build_structure: 8 files, 0 differ", 1, true) ~= nil, "build_structure.py --check: " .. out)
end

for _, row in ipairs(ZONES) do
	print(("%s: %d quests offered"):format(row[1], #offered[row[1]]))
end
if failures > 0 then
	error(("R60 BANDQUESTS PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R60 BANDQUESTS PORTABLE PASS checks=%d local=%d shared=%d"):format(checks, local_count, shared_count))
