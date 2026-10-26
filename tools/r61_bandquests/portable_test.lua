-- Round 61 lane BANDQUESTS portable test (LuaJIT): the band 31-40's six
-- shipped quest files on the Round 57 quest foundation (round61-plan.md §2,
-- §2a, §3, §4 BANDQUESTS; quests.md "The band 31-40"), with the REAL
-- grug_gear and grug_quality for the reward stacks, the REAL
-- grug_mobs/subtypes.lua for the Runner's Packet and the REAL
-- grug_housing/soulbound.lua for its guard:
--   A. the files: all six reworked, the quests each zone offers, every
--      shared quest in its first variant's file with one variant per zone
--      that gives it; the Round 58 guild quests kept;
--   B. free play and the story: a free quest requires nothing; only the
--      story quests chain (A4 -> A5 -> A6 with Scrip's quest and the raid,
--      T3 -> T4 -> T5 with Rattle's quest and the raid); no free quest of
--      the band is followed by another but Scrip's, Rattle's and the raid's;
--      every zone's first quests open at 30; the levels lie in the band;
--   C. the kept ids with their objectives (Rattle's asks only for Rattle);
--      the travels and departures free; the departures at 40;
--   D. the main line (41-60) of the two contested base files: the same ids,
--      objectives, levels, requires, lines and home, marked story;
--   E. the optional group quests: one per zone, free, standalone (requiring
--      nothing, required by nothing), a trinket choice, no weapon;
--   F. few mob names per zone; no zone quest hunts a camp hunt's role;
--   G. no reward is a requested item;
--   H. the reward pattern per zone (the early potion choice at min >= 31 and
--      the Runner's Packet's, two armor choices on two slots with one
--      enchant, the weapon on a solo quest), each faction's six distinct
--      armor quests give every slot, Potion IV only on quests from 31;
--   I. the use places: every town place a quest_place socket of the named
--      settlement, every recipe place one of the zone's spawn file, every
--      object a kind of use_objects.json (storm_vessel with its own picked
--      art since Round 61 STORYART);
--   J. the line plan: the hosts' shared line `border`;
--   K. the Runner's Packet: a quest item of items.json, registered
--      soulbound, refused by a chest and the trash, lost when dropped; its
--      quest drop from the bandit archers with an area per variant;
--   L. the leaders: Rattle at 35, the four dropped normal leaders gone from
--      the spawn files, subtypes.json and names.json; the two foremen's
--      titles;
--   M. build_structure.py --check: the files' structure is the script's.
-- Offering and taking the shipped quests through the real grug_quests (a
-- shared quest done in one zone is offered in no other; A5 only after A4
-- and Scrip) is tools/r28_q0's section 5; the foremen's chapter-3 quests
-- through the real loader and camps are tools/r58_guildquests'.
--
--   luajit tools/r61_bandquests/portable_test.lua [REPO]
-- Prints "R61 BANDQUESTS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function sorted_join(list)
	local copy = table.copy(list or {})
	table.sort(copy)
	return table.concat(copy, ",")
end

------------------------------------------------------------------------------
-- Engine stub (tools/r60_bandquests'): the real grug_gear and grug_quality.
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
-- zone, faction, short name, weapon quest (solo), group quest
local ZONES = {
	{"elandor_stormvault_heights", "accord", "stormvault", "stormvault_survey_stand", "stormvault_sighting_05"},
	{"elandor_ashenward_march", "accord", "ashenward", "ashenward_rations_03", "ashenward_hedge_04"},
	{"elandor_glassroot_wilds", "accord", "glassroot", "glassroot_carrier_path", "glassroot_canopy_05"},
	{"kragmar_blackwind_rise", "throng", "blackwind", "blackwind_recovery_rest", "blackwind_arch_group"},
	{"kragmar_bannerbreak_mesa", "throng", "bannerbreak", "bannerbreak_ramp_03", "bannerbreak_standard_group"},
	{"kragmar_thunderroot_wilds", "throng", "thunderroot", "thunderroot_storm_vessel", "thunderroot_rainchar_group"},
}
local BAND, FACTION, ZONE_OF = {}, {}, {}
for _, row in ipairs(ZONES) do BAND[row[1]], FACTION[row[1]], ZONE_OF[row[3]] = true, row[2], row[1] end
-- Round 58's quests in these files, kept as shipped (miners_guild.md §11).
local GUILD = {guild_t4_report_accord = true, guild_t4_report_throng = true, camp_hunt_t4 = true,
	camp_hunt_t4_night = true, camp_site_raid = true}
-- The main line (Round 36) in the two contested base files: id = its
-- requires, as shipped (r36_qa, r36_qt own the rest).
local MAIN = {
	accord_main_impounded = "", accord_main_standard = "accord_main_accounts", accord_main_orders = "lasthedge_front_04",
	accord_main_audit = "accord_main_orders", accord_main_roll = "accord_main_audit",
	accord_main_stonegrudge = "accord_main_orders", accord_main_collector = "accord_main_tally",
	accord_main_final = "accord_main_collector",
	throng_main_01 = "", throng_main_03 = "throng_main_02", throng_main_04 = "bb_front_torn_05",
	throng_main_05 = "throng_main_04", throng_main_greyvow = "throng_main_05", throng_main_06 = "throng_main_05",
	throng_main_finale = "throng_main_07",
}
local STORY = {
	story_accord_05 = "ashenward_rations_03,story_accord_04", story_accord_06 = "camp_site_raid,story_accord_05",
	story_throng_05 = "bannerbreak_ramp_03,story_throng_04", story_throng_06 = "camp_site_raid,story_throng_05",
}
local NPC = {borin = "r20_anchor_027_host", alna = "r20_anchor_028_host", toren = "r20_anchor_031_host",
	nella = "r20_anchor_032_host", faeris = "r20_anchor_036_host", vaska = "r20_anchor_039_host",
	orrel = "r20_anchor_040_host", drek = "r20_anchor_043_host", yarra = "r20_anchor_044_host",
	rumela = "r20_anchor_048_host"}
local function foreman(short) return "r58_foreman_mining_camp_" .. ZONE_OF[short]:match("^[^_]+_(.+)$") end
-- The shared quests: their variants' zones and givers, in order.
local SHARED = {
	border_meal = {{"ashenward", "toren"}, {"bannerbreak", "drek"}},
	border_melons = {{"glassroot", "faeris"}, {"thunderroot", "rumela"}},
	border_stores = {{"glassroot", "faeris"}, {"blackwind", "orrel"}, {"thunderroot", "rumela"}},
	border_packets = {{"stormvault", "alna"}, {"ashenward", "nella"}, {"glassroot", "faeris"},
		{"blackwind", "orrel"}, {"bannerbreak", "yarra"}, {"thunderroot", "rumela"}},
	border_reserve = {{"ashenward", "nella"}, {"bannerbreak", "yarra"}},
}
-- A6 and T5: a variant per band foreman of the faction.
local CLOSERS = {story_accord_06 = {{"stormvault", "ashenward", "glassroot"}, "nella"},
	story_throng_06 = {{"blackwind", "bannerbreak", "thunderroot"}, "yarra"}}
local DIR = "mods/PLAYER/grug_quests/data/zones/"
local files, by_id, offered = {}, {}, {}
for _, row in ipairs(ZONES) do
	local data = read_json(DIR .. row[1] .. ".quests.json")
	files[row[1]] = data
	check(data and data.reworked == true, row[1] .. ": marked reworked")
	offered[row[1]] = {}
end
local shared_count, local_count = 0, 0
-- Round 62: the shared front quests (41-60) homed in these base files are
-- the front's (tools/r62_frontquests checks them), like the main line: no
-- band section counts them.
local FRONT_SHARED = {}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	for _, quest in ipairs(files[zone].quests) do
		if quest.level > 40 and not MAIN[quest.id] then
			check(FRONT_SHARED[quest.id] == nil and quest.variants ~= nil and quest.line == "border",
				quest.id .. ": a shared front quest on the hosts' line")
			FRONT_SHARED[quest.id] = zone
		end
	end
end
for _, row in ipairs(ZONES) do
	local zone = row[1]
	for _, quest in ipairs(files[zone].quests) do
		if FRONT_SHARED[quest.id] then
			-- the front's, above
		else
			check(by_id[quest.id] == nil, quest.id .. ": one id, one quest")
			by_id[quest.id] = {quest = quest, file = zone}
			if quest.variants then
				local want = SHARED[quest.id]
				if want then
					shared_count = shared_count + 1
					eq(quest.variants[1].zone, zone, quest.id .. ": lives in its first variant's file")
					eq(#quest.variants, #want, quest.id .. ": one variant per zone that gives it")
					for index, variant in ipairs(quest.variants) do
						local expect = want[index] or {}
						eq(variant.zone, ZONE_OF[expect[1]], quest.id .. ": variant " .. index .. "'s zone")
						check(#variant.givers == 1 and variant.givers[1] == NPC[expect[2]],
							quest.id .. ": given in " .. tostring(expect[1]) .. " by " .. tostring(expect[2]))
					end
				elseif CLOSERS[quest.id] then
					local spec = CLOSERS[quest.id]
					eq(#quest.variants, 3, quest.id .. ": three foremen give it")
					for index, variant in ipairs(quest.variants) do
						local short = spec[1][index]
						eq(variant.zone, ZONE_OF[short], quest.id .. ": variant " .. index .. "'s zone")
						eq(table.concat(variant.givers, ","), foreman(short), quest.id .. ": given by " .. short .. "'s foreman")
						eq(table.concat(variant.turnins or {}, ","), NPC[spec[2]], quest.id .. ": turned in at " .. spec[2])
					end
					eq(quest.variants[1].zone, zone, quest.id .. ": lives in its first variant's file")
				else
					check(GUILD[quest.id], quest.id .. ": a quest with variants is a shared, a closing or a guild one")
				end
				for _, variant in ipairs(quest.variants) do
					if BAND[variant.zone] then table.insert(offered[variant.zone], quest) end
				end
			elseif not MAIN[quest.id] then
				-- (the main line is the front's, section D)
				local_count = local_count + 1
				table.insert(offered[zone], quest)
			end
		end
	end
end
eq(shared_count, 5, "five shared quests (meal, melons, stores, packets, reserve)")
for id in pairs(GUILD) do check(by_id[id] ~= nil, id .. ": the guild quest stays in its home file") end
for id in pairs(STORY) do check(by_id[id] ~= nil, id .. ": chapter 3's step ships") end
-- The guild reports and camp hunts list a band variant in every zone.
for _, row in ipairs(ZONES) do
	local report = "guild_t4_report_" .. row[2]
	local found, hunt, raid = false, false, false
	for _, quest in ipairs(offered[row[1]]) do
		found = found or quest.id == report
		hunt = hunt or quest.id:find("^camp_hunt_t4") ~= nil
		raid = raid or quest.id == "camp_site_raid"
	end
	check(found, row[1] .. ": offers " .. report)
	check(hunt, row[1] .. ": offers its camp hunt")
	check(raid, row[1] .. ": offers the camp raid")
end

-- Every quest file, for the follow-ups across files.
local followers, all_ids = {}, {}
do
	local handle = io.popen('ls "' .. ROOT .. '/' .. DIR .. '"')
	for name in handle:lines() do
		local data = read_json(DIR .. name)
		for _, quest in ipairs(data and data.quests or {}) do
			all_ids[quest.id] = (all_ids[quest.id] or 0) + 1
			for _, id in ipairs(quest.requires or {}) do
				followers[id] = followers[id] or {}
				table.insert(followers[id], quest.id)
			end
		end
	end
	handle:close()
end
for id in pairs(by_id) do eq(all_ids[id], 1, id .. ": its id is the game's one quest of that id (done once)") end

------------------------------------------------------------------------------
-- B. Free play and the story.
------------------------------------------------------------------------------
-- The follow-ups the band's quests may have (the free quests' one per
-- faction, the story chain): Scrip's and Rattle's free quests and the raid
-- carry chapter 3 (round61-plan.md §2a point 5).
local ALLOWED_FOLLOWERS = {ashenward_rations_03 = "story_accord_05", bannerbreak_ramp_03 = "story_throng_05",
	camp_site_raid = "story_accord_06,story_throng_06", story_accord_05 = "story_accord_06",
	story_throng_05 = "story_throng_06"}
for id, entry in pairs(by_id) do
	local quest = entry.quest
	local follow = sorted_join(followers[id])
	if MAIN[id] then
		-- section D
	elseif GUILD[id] then
		check(id:find("^guild_") == nil or quest.story == true, id .. ": the guild report stays a story quest")
		if id ~= "camp_site_raid" and not id:find("^guild_") then
			eq(follow, "", id .. ": no follow-up")
		end
		if id == "camp_site_raid" then
			eq(follow, ALLOWED_FOLLOWERS[id], "camp_site_raid: its follow-ups are A6 and T5, one per faction")
		end
	elseif STORY[id] then
		eq(quest.story, true, id .. ": a story quest")
		eq(sorted_join(quest.requires), STORY[id], id .. ": its story prerequisites")
		eq(follow, ALLOWED_FOLLOWERS[id] or "", id .. ": its follow-ups")
	else
		check(not quest.story, id .. ": free play")
		eq(#(quest.requires or {}), 0, id .. ": requires nothing but a level")
		eq(follow, ALLOWED_FOLLOWERS[id] or "", id .. ": its one follow-up at most (" .. follow .. ")")
	end
	if not GUILD[id] and not MAIN[id] then
		check(quest.level >= 31 and quest.level <= 40 and quest.min_level >= 30 and quest.min_level <= quest.level,
			id .. ": levels within the band (" .. tostring(quest.min_level) .. "/" .. tostring(quest.level) .. ")")
	end
end
-- The chain across files: A4 (Frostbarrow Shelf) and T3 (Nhal Veyr) are
-- followed by A5 and T4 alone.
eq(sorted_join(followers.story_accord_04), "story_accord_05", "A4's one follow-up is A5")
eq(sorted_join(followers.story_throng_04), "story_throng_05", "T3's one follow-up is T4")
-- Chapter 3's givers, places, turn-ins and levels (draft §5, the check).
do
	local a5, t4 = by_id.story_accord_05, by_id.story_throng_05
	local a6, t5 = by_id.story_accord_06, by_id.story_throng_06
	if check(a5 and t4 and a6 and t5, "chapter 3's four steps ship") then
		eq(a5.file, "elandor_ashenward_march", "A5 lives in Ashenward March")
		eq(a5.quest.giver .. ">" .. a5.quest.turnin, NPC.toren .. ">" .. foreman("ashenward"),
			"A5: Toren to the Ashenward camp's foreman")
		eq(a5.quest.objectives[1].object .. "@" .. a5.quest.objectives[1].place, "dispatch_record@broken_load",
			"A5: the transport record at the broken load")
		eq(a5.quest.min_level, 34, "A5 at 34")
		eq(t4.file, "kragmar_bannerbreak_mesa", "T4 lives in Bannerbreak Mesa")
		eq(t4.quest.giver .. ">" .. t4.quest.turnin, NPC.drek .. ">" .. foreman("bannerbreak"),
			"T4: Drek to the Bannerbreak camp's foreman")
		eq(t4.quest.objectives[1].object .. "@" .. t4.quest.objectives[1].place, "witness_record@scattered_load",
			"T4: the handover record at the scattered load")
		eq(t4.quest.min_level, 35, "T4 at 35")
		eq(a6.quest.min_level, 39, "A6 at 39")
		eq(t5.quest.min_level, 40, "T5 at 40 (K1 A)")
		for _, entry in ipairs({a6, t5}) do
			eq(#entry.quest.objectives, 1, entry.quest.id .. ": one objective")
			eq(entry.quest.objectives[1].type, "talk", entry.quest.id .. ": a pure travel (K5 A)")
			eq(entry.quest.line, "guild", entry.quest.id .. ": on the foremen's guild line")
		end
		eq(a6.quest.objectives[1].npc, NPC.nella, "A6 travels to Nella")
		eq(t5.quest.objectives[1].npc, NPC.yarra, "T5 travels to Yarra")
		-- The free prerequisites open below their story step (Rattle at or below T4).
		check(by_id.ashenward_rations_03.quest.min_level <= a5.quest.min_level, "Scrip's quest opens before A5")
		check(by_id.bannerbreak_ramp_03.quest.min_level <= t4.quest.min_level and
			by_id.bannerbreak_ramp_03.quest.level <= 35, "Rattle's quest opens at or below T4, rewards at 35 at most")
		check(by_id.camp_site_raid.quest.min_level <= a6.quest.min_level, "the raid opens before A6")
	end
end
-- Every zone's first quests: a level-30/31 character finds quests at once.
for _, row in ipairs(ZONES) do
	local first = 99
	for _, quest in ipairs(offered[row[1]]) do
		if not quest.story and #(quest.requires or {}) == 0 and quest.min_level < first then first = quest.min_level end
	end
	eq(first, 30, row[1] .. ": its first quests open at level 30")
end

------------------------------------------------------------------------------
-- C. The kept ids.
------------------------------------------------------------------------------
local KEPT = {
	-- the cross-lane ids (round61-plan.md §2 point 2): Scrip, Rattle (only
	-- Rattle now), A Soldier's Due
	ashenward_rations_03 = "kill:quartermaster_scrip", bannerbreak_ramp_03 = "kill:provisioner_rattle",
	bannerbreak_standard_04 = "kill:unrelenting_husk",
	-- the errands whose objectives stayed
	stormvault_passes_03 = "item:grug_materials:silversteel_bar", stormvault_sighting_04 = "item:grug_materials:emberglass",
	-- the group quests
	stormvault_sighting_05 = "kill:split_seam_warden", ashenward_hedge_04 = "kill:red_receipt_marshal",
	glassroot_canopy_05 = "kill:canopy_knuckle", blackwind_arch_group = "kill:hollowbell_treant",
	bannerbreak_standard_group = "kill:banner_eater", thunderroot_rainchar_group = "kill:storm_bottle_witch",
	-- the travels and departures
	stormvault_road_ashenward = "talk:" .. NPC.toren, stormvault_road_archshadow = "talk:" .. NPC.alna,
	ashenward_road_stormvault = "talk:" .. NPC.borin, ashenward_road_glassroot = "talk:" .. NPC.faeris,
	ashenward_road_last_hedge = "talk:" .. NPC.nella, glassroot_road_ashenward = "talk:" .. NPC.toren,
	glassroot_road_front = "talk:" .. NPC.nella, blackwind_ashes_03 = "talk:" .. NPC.drek,
	blackwind_ashes_04 = "talk:" .. NPC.orrel, bannerbreak_ramp_02 = "talk:" .. NPC.yarra,
	bannerbreak_standard_02 = "talk:" .. NPC.rumela, thunderroot_storm_03 = "talk:" .. NPC.vaska,
	thunderroot_rainchar_04 = "talk:" .. NPC.yarra,
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
		eq(#entry.quest.objectives, 1, id .. ": one objective")
	end
end
-- The departures at 40 (round61-plan.md §2 point 7): every zone ends at a
-- host with front work from 40 (Nella, Drek, Yarra) or carries it itself.
local DEPARTURES = {stormvault_road_last_hedge = NPC.nella, glassroot_road_front = NPC.nella,
	blackwind_road_red_ramp = NPC.drek, thunderroot_rainchar_04 = NPC.yarra}
for id, npc in pairs(DEPARTURES) do
	local q = by_id[id] and by_id[id].quest
	if check(q ~= nil, id .. ": the departure ships") then
		eq(q.min_level, 40, id .. ": free from 40")
		eq(q.objectives[1].npc, npc, id .. ": to a host with front work at 40")
	end
end

------------------------------------------------------------------------------
-- D. The main line: kept, marked story.
------------------------------------------------------------------------------
for id, requires in pairs(MAIN) do
	local entry = by_id[id]
	if check(entry ~= nil, id .. ": the main-line step ships") then
		local quest = entry.quest
		eq(quest.story, true, id .. ": marked story")
		eq(sorted_join(quest.requires), requires, id .. ": its requires as shipped")
		eq(entry.file, id:find("^accord") and "elandor_ashenward_march" or "kragmar_bannerbreak_mesa", id .. ": its home")
		eq(quest.line, id:find("^accord") and "main" or "oaths", id .. ": the Warmaster's second line")
		check(quest.level >= 41, id .. ": a 41-60 step")
		check(not quest.title:find("^%[PH%]"), id .. ": its shipped title stays")
	end
end

------------------------------------------------------------------------------
-- E. The optional group quests (round61-plan.md §2 point 8).
------------------------------------------------------------------------------
local TRINKET = "^grug_gear:[%w_]+_t4$"
for _, row in ipairs(ZONES) do
	local groups = {}
	for _, quest in ipairs(offered[row[1]]) do
		if quest.group then groups[#groups + 1] = quest.id end
	end
	eq(table.concat(groups, ","), row[5], row[1] .. ": one optional group quest")
	local q = by_id[row[5]] and by_id[row[5]].quest
	if q then
		check(not q.story and #(q.requires or {}) == 0, q.id .. ": free, requires nothing")
		eq(#(followers[q.id] or {}), 0, q.id .. ": required by nothing")
		check(q.min_level >= 38 and q.level == 39, q.id .. ": at ~39")
		local choices = q.rewards.choices or {}
		check(#choices >= 2, q.id .. ": a choice as its extra")
		for _, choice in ipairs(choices) do
			check(choice.item:find(TRINKET) ~= nil, q.id .. ": a tier-4 trinket (" .. choice.item .. ")")
			eq(#(choice.affixes or {}), 0, q.id .. ": no enchant (no weapon, no budget)")
		end
	end
end

------------------------------------------------------------------------------
-- F. Few mobs per zone (by role); no zone quest hunts a camp hunt's role.
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
local HUNTS = {}
for _, id in ipairs({"camp_hunt_t4", "camp_hunt_t4_night"}) do
	for _, variant in ipairs(by_id[id].quest.variants) do
		HUNTS[variant.zone] = (variant.objectives or {})[1] and variant.objectives[1].roles[1]
	end
end
for _, row in ipairs(ZONES) do
	local zone, roles, kills, all = row[1], {}, 0, 0
	for _, quest in ipairs(offered[zone]) do
		local variant = variant_of(quest, zone)
		for index, objective in ipairs(quest.objectives) do
			all = all + 1
			local own = variant and variant.objectives and variant.objectives[index]
			local area = own and own.area or objective.area
			if objective.type == "kill" and not (area and area:find("/camp_site_")) then
				kills = kills + 1
				for _, role in ipairs(own and own.roles or objective.roles) do
					check(next(names_of(zone, role)) ~= nil, zone .. ": " .. role .. " has a name there")
					roles[role] = true
					if not GUILD[quest.id] then
						check(role ~= HUNTS[zone], zone .. ": " .. quest.id .. " hunts no camp hunt's role")
					end
				end
			elseif objective.type == "kill" then
				kills = kills + 1
			end
		end
		local drops = variant and variant.quest_drops or quest.quest_drops
		for _, drop in ipairs(drops or {}) do
			for _, role in ipairs(drop.roles) do roles[role] = true end
		end
	end
	local count = 0
	for _ in pairs(roles) do count = count + 1 end
	check(count >= 3 and count <= 5, zone .. ": three to five mobs besides the raid's garrison (" .. count .. ")")
	-- About a third (the check §3); Bannerbreak, with Rattle and A Soldier's
	-- Due, stays the most combat-heavy zone (draft §4.7).
	check(kills / all <= 0.45, zone .. ": about a third of the objectives kill (" .. kills .. " of " .. all .. ")")
end

------------------------------------------------------------------------------
-- G. No reward is a requested item.
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
-- H. The reward pattern per zone.
------------------------------------------------------------------------------
local HEALING, MANA = "grug_alchemy:potion_healing_t4", "grug_alchemy:potion_mana_t4"
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
		check(choice.item:find("_silversteel$") or choice.item:find("_silkweave$") or choice.item:find("_scaled$"),
			label .. ": a tier-4 piece")
		local ok, reason = grug_items.check_affixes(choice.item, choice.affixes or {})
		check(ok, label .. ": enchants in the pool: " .. tostring(reason))
		local stack = ok and grug_items.make_stack(choice.item, quest.level, choice.affixes)
		if stack then
			eq(stack:get_meta():get_int("grug_ilvl"), quest.level, label .. ": item level = reward level")
			eq(#grug_items.get_affixes(stack), #choice.affixes, label .. ": its enchants")
			eq(grug_items.enchant_tier(quest.level), 4, label .. ": enchant tier 4")
		end
	end
end
-- Potion IV is usable from 31 (grug_alchemy TIER_LEVELS).
for id, entry in pairs(by_id) do
	for _, choice in ipairs(entry.quest.rewards.choices or {}) do
		if choice.item == HEALING or choice.item == MANA then
			check(entry.quest.min_level >= 31, id .. ": Potion IV only from min level 31")
		end
	end
end
local armor_quests = {accord = {}, throng = {}}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	local potions, armor, weapons = {}, {}, {}
	for _, quest in ipairs(offered[zone]) do
		local choices = quest.rewards.choices
		if choices and not GUILD[quest.id] and not quest.story and not quest.group then
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
	-- The early potion choice (from 31) and the Runner's Packet's, given in
	-- all six zones (no armor there: the reward budget).
	local early = {}
	for _, quest in ipairs(potions) do
		if quest.id ~= "border_packets" then early[#early + 1] = quest end
	end
	eq(#potions, 2, zone .. ": the early potion choice and the Packet's")
	eq(#early, 1, zone .. ": one early potion choice")
	local p = early[1]
	if p then
		check(p.min_level == 31, zone .. ": the potion choice is early, from 31 (" .. p.id .. ")")
		local set = {}
		for _, choice in ipairs(p.rewards.choices) do set[choice.item .. " " .. (choice.count or 1)] = true end
		check(#p.rewards.choices == 2 and set[HEALING .. " 2"] and set[MANA .. " 2"],
			zone .. ": 2 Healing Potion IV or 2 Mana Potion IV")
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
			slots[index] = slot
			armor_quests[row[2]][quest.id] = slot
			stacks_ok(quest.id, quest)
		end
		check(slots[1] and slots[1] ~= slots[2], zone .. ": the two armor choices are two slots")
	end
	eq(#weapons, 1, zone .. ": one weapon choice")
	local w = weapons[1]
	if w then
		eq(w.id, row[4], zone .. ": the weapon on the zone's solo quest")
		check(not w.group and not w.variants, w.id .. ": a local solo quest")
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
-- A player takes a shared quest once: each faction's distinct armor quests
-- over its three zones are six pieces, every slot at least once
-- (round61-plan.md §2 point 4).
local SLOTS = {accord = {head = 2, legs = 2, chest = 1, feet = 1}, throng = {head = 1, legs = 2, chest = 2, feet = 1}}
for faction, quests in pairs(armor_quests) do
	local slots, count = {}, 0
	for _, slot in pairs(quests) do slots[slot] = (slots[slot] or 0) + 1; count = count + 1 end
	eq(count, 6, faction .. ": six distinct armor quests over its three zones")
	for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
		eq(slots[slot], SLOTS[faction][slot], faction .. ": the " .. slot .. " slot (at least once)")
	end
end

------------------------------------------------------------------------------
-- I. The use places.
------------------------------------------------------------------------------
local objects = read_json("mods/PLAYER/grug_quests/data/use_objects.json")
local places = dofile(ROOT .. "/tools/r59_qsys3/socket_places.lua")
local uses = 0
for id, entry in pairs(by_id) do
	local quest = entry.quest
	for index, objective in ipairs(quest.objectives) do
		if objective.type == "use" and not MAIN[id] then
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
					for _, row in ipairs(recipe.places or {}) do
						if row.id == place_id then found = row end
					end
					check(found and found.at.pick == "farthest_from_roads",
						id .. ": " .. place .. " is a quest place of " .. zone .. "'s recipe")
				end
			end
		end
	end
end
eq(uses, 10, "ten uses at a place, a shared quest's per variant (A5, T4, the four solo places, the reserve " ..
	"twice, the lantern, the reading cord)")
-- The six new recipe places (draft §6), each in its kind of the belt.
local NEW_PLACES = {
	{"elandor_ashenward_march", "broken_load", "wheelbreak"}, {"kragmar_bannerbreak_mesa", "scattered_load", "warplains"},
	{"elandor_stormvault_heights", "survey_stand", "highcrags"}, {"elandor_glassroot_wilds", "carrier_path", "canopy"},
	{"kragmar_blackwind_rise", "recovery_rest", "deadmarch"}, {"kragmar_thunderroot_wilds", "storm_store", "stormglades"},
}
for _, row in ipairs(NEW_PLACES) do
	local recipe = read_json("mods/ENTITIES/grug_mobs/data/zones/" .. row[1] .. ".spawns.json").recipe
	local found
	for _, place in ipairs(recipe.places or {}) do
		if place.id == row[2] then found = place end
	end
	check(found and found.at.kind == row[3], row[1] .. ": the place " .. row[2] .. " in the " .. row[3])
end
local vessel = objects.storm_vessel
if check(vessel ~= nil, "use_objects: the new kind storm_vessel") then
	-- Round 61 STORYART: the user's picked art replaced the placeholder look.
	eq(vessel.texture, "grug_quests_obj_storm_vessel.png", "storm_vessel: its own picked art")
	check(io.open(ROOT .. "/mods/PLAYER/grug_quests/textures/" .. vessel.texture) ~= nil,
		"storm_vessel: its texture file ships")
end

------------------------------------------------------------------------------
-- J. The line plan (draft §10): the hosts' shared line.
------------------------------------------------------------------------------
local LINES = {
	[NPC.borin] = "passes,front", [NPC.alna] = "border,front", [NPC.toren] = "border,front",
	[NPC.nella] = "border,front", [NPC.faeris] = "border,canopy", [NPC.vaska] = "ashes,front",
	[NPC.orrel] = "border,front", [NPC.drek] = "border,front", [NPC.yarra] = "border,front",
	[NPC.rumela] = "border,rainchar",
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
for id in pairs(SHARED) do eq(by_id[id].quest.line, "border", id .. ": on the shared line") end

------------------------------------------------------------------------------
-- K. The Runner's Packet.
------------------------------------------------------------------------------
local PACKET = "grug_mobs:runners_packet"
local CAMPS = {elandor_stormvault_heights = "slatehook", elandor_ashenward_march = "coalbrand_yard",
	elandor_glassroot_wilds = "rootsnare", kragmar_blackwind_rise = "pallcloth_den",
	kragmar_bannerbreak_mesa = "sunderstrap_camp", kragmar_thunderroot_wilds = "rainchar_camp"}
do
	local row
	for _, item in ipairs(read_json("mods/ENTITIES/grug_mobs/data/items.json")) do
		if item.id == PACKET then row = item end
	end
	check(row and row.kind == "quest", "the Packet is a quest item of items.json")
	eq(read_file("mods/ENTITIES/grug_mobs/data/items.json"),
		read_file("docs/planning/round28/design/catalog/items.json"), "the design catalogue mirrors items.json")
	local q = by_id.border_packets and by_id.border_packets.quest
	if check(q ~= nil, "the Packet quest ships") then
		eq(#q.objectives, 1, "border_packets: one objective, no kill count")
		check(q.objectives[1].type == "item" and q.objectives[1].item == PACKET and q.objectives[1].count == 1,
			"border_packets: asks for the Packet")
		local drop = (q.quest_drops or {})[1]
		check(drop and drop.item == PACKET and drop.roles[1] == "entrenched_bandit_archer",
			"border_packets: drops from the bandit archers")
		for index, variant in ipairs(q.variants) do
			local own = index == 1 and drop or (variant.quest_drops or {})[1]
			eq(own and own.area, variant.zone .. "/" .. tostring(CAMPS[variant.zone]),
				"border_packets: " .. variant.zone .. "'s drop limited to its bandit camp")
		end
	end
end
-- The real subtypes.lua registers the Packet soulbound (its stub: tools/r60_bandquests').
do
	local saved = {core = core, grug_mobs = grug_mobs}
	local items = {}
	core = {
		registered_items = items, registered_entities = {},
		get_modpath = function() return modpaths.grug_mobs end,
		get_current_modname = function() return "grug_mobs" end,
		-- The mod's real textures/ listing: item_image() prefers an item's own icon.
		get_dir_list = function(path)
			local list, handle = {}, io.popen('ls "' .. path .. '"')
			for entry in handle:lines() do list[#list + 1] = entry end
			handle:close()
			return list
		end,
		parse_json = function(text) return (json.decode(text)) end,
		register_craftitem = function(name, def) items[name] = def end,
		register_on_mods_loaded = function() end,
		colorize = function(_, text) return text end,
	}
	grug_zones = {id_at = function() return "elandor_stormvault_heights" end}
	grug_mobs = {
		LEADER = {size = 1.15, hp = 1.5},
		copy_base_def = function() return {attack_type = "dogfight", textures = {{"blank.png", "base.png"}}} end,
		disposition = function() return "aggressive" end,
		register_disposition = function() end,
		register_mob = function() end,
		set_base_texture = function() end,
	}
	dofile(modpaths.grug_mobs .. "/subtypes.lua")
	local def = items[PACKET]
	if check(def ~= nil, PACKET .. " registers") then
		eq((def.groups or {}).grug_soulbound, 1, PACKET .. " is soulbound")
		check(type(def.on_drop) == "function", PACKET .. " has its own drop")
		-- Round 61 STORYART: the user's picked icon replaced the quest kind's placeholder.
		eq(def.inventory_image, "grug_mobs_runners_packet.png", PACKET .. ": its own picked icon")
		registered[PACKET] = def
		local dropper = {is_player = function() return true end, get_player_name = function() return "ann" end}
		fed = {}
		local rest = def.on_drop(ItemStack(PACKET), dropper, {x = 0, y = 0, z = 0})
		check(rest and rest:is_empty(), "a dropped Packet is gone, nothing lands on the ground")
		check(fed[1] and fed[1]:find("^notice: Runner's Packet is lost") ~= nil, "the feed says so (" .. tostring(fed[1]) .. ")")
	end
	-- The dropped leaders are no sub-types any more; Rattle stands at 35.
	for _, role in ipairs({"bolt_chewer", "basket_biter", "grave_broker_mute", "bottle_keeper_zek"}) do
		check(items["grug_mobs:" .. role] == nil, role .. ": no item of that name")
	end
	core, grug_mobs = saved.core, saved.grug_mobs
end
-- The soulbound guard (grug_housing/soulbound.lua) refuses the Packet
-- outside the carried lists: a chest, the craft grid, the trash.
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
		get_meta = function() return {get_inventory = function() return {get_stack = function() return ItemStack(PACKET) end} end} end,
	})
	grug_housing = {}
	dofile(ROOT .. "/mods/PLAYER/grug_housing/soulbound.lua")
	local packet = ItemStack(PACKET)
	eq(allow(nil, "put", nil, {listname = "grug_bag1_content", stack = packet}), nil, "the Packet goes into a bag")
	eq(allow(nil, "put", nil, {listname = "craft", stack = packet}), 0, "the craft grid refuses it")
	eq(nodes["default:chest"].allow_metadata_inventory_put(nil, "main", 1, packet, nil), 0, "a chest refuses it")
	core.create_detached_inventory("trash", {})
	eq(detached_callbacks and detached_callbacks.allow_put(nil, "main", 1, packet, nil), 0, "the trash refuses it")
	core = saved
end

------------------------------------------------------------------------------
-- L. The leaders and the foremen's titles.
------------------------------------------------------------------------------
local subtypes = {}
for _, row in ipairs(read_json("mods/ENTITIES/grug_mobs/data/subtypes.json")) do subtypes[row.role] = row end
local rattle = subtypes.provisioner_rattle
check(rattle and rattle.levels[1] == 35 and rattle.levels[2] == 35, "Rattle stands at 35 (T4 at 35 never waits on him)")
eq(names["kragmar_bannerbreak_mesa/provisioner_rattle/L35-35"], "Provisioner Rattle", "names.json: Rattle at 35")
local DROPPED = {bolt_chewer = "elandor_stormvault_heights", basket_biter = "elandor_glassroot_wilds",
	grave_broker_mute = "kragmar_blackwind_rise", bottle_keeper_zek = "kragmar_thunderroot_wilds"}
for role, zone in pairs(DROPPED) do
	check(subtypes[role] == nil, role .. ": its subtypes.json row is gone")
	check(next(names_of(zone, role)) == nil, role .. ": its names.json row is gone")
	for _, leader in ipairs(read_json("mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json").recipe.leaders) do
		check(leader.role ~= role, role .. ": no longer a leader of " .. zone)
	end
end
do
	local text = read_file("mods/PLAYER/grug_quests/npcs.lua") or ""
	local titles = {}
	for camp, title in text:gmatch('{camp = "([%w_]+)", title = "([^"]+)"}') do titles[camp] = title end
	eq(titles.mining_camp_ashenward_march, "Audra Wainholt", "the Ashenward foreman's title (K12 A)")
	eq(titles.mining_camp_bannerbreak_mesa, "Greda Stonehaul", "the Bannerbreak foreman's title (K13 A)")
end

------------------------------------------------------------------------------
-- M. The generator's structure check.
------------------------------------------------------------------------------
do
	local handle = io.popen("cd '" .. ROOT .. "' && python3 tools/r61_bandquests/build_structure.py --check 2>&1")
	local out = handle:read("*a")
	handle:close()
	check(out:find("build_structure: 6 files, 0 differ", 1, true) ~= nil, "build_structure.py --check: " .. out)
end

for _, row in ipairs(ZONES) do
	print(("%s: %d quests offered"):format(row[1], #offered[row[1]]))
end
if failures > 0 then
	error(("R61 BANDQUESTS PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R61 BANDQUESTS PORTABLE PASS checks=%d local=%d shared=%d"):format(checks, local_count, shared_count))
