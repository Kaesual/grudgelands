-- Round 62 lane FRONTQUESTS portable test (LuaJIT): the front 41-60 on the
-- Round 57 quest foundation (round62-plan.md §2, §2a, §3, §4 FRONTQUESTS;
-- quests.md "The front 41-60"), text-agnostic, with the REAL grug_gear and
-- grug_quality for the reward stacks:
--   A. all 48 quest files are reworked;
--   B. the spine (r36_qa's 17 and r36_qt's 14 steps) is story and chained
--      only on itself, the join at 41 free, Huskell before Chirr (K12 A);
--      the war commanders' optional branches;
--   C. every other quest of reward level 41-60 is free: it requires nothing
--      but its one allowed predecessor (the fortress raids' second camp,
--      the island bounty pairs), has at most one follow-up per faction;
--   D. the group quests: below 51 standalone, optional, never a key reward;
--   E. the shared front quests: ten, each once, on the hosts' line `border`,
--      in its first variant's base file, one variant per giver;
--   F. the departures (Dorrin, Thorga, Eriath, Vaska, Ossa, Borin, Nalo):
--      free travels to a giver with work at once;
--   G. the island pairs: the Accord's two and the Throng's one (another
--      mob), coin only; the island uses free;
--   H. the rewards per faction and band (T5 41-50, T6 51-60): six armor
--      quests with one enchant (every slot), three weapon quests with two
--      (solo), three trinket choices, a potion choice from the band's first
--      level on; the final turn-ins one weapon choice; the budget per zone
--      and band; the stacks at the reward level with the band's enchant
--      tier;
--   I. the places: every use place resolves (the eight new recipe places in
--      their kinds, the free clash sites, the town places' quest_place
--      sockets), no text names West Trench Mouth;
--   J. names and kills: 3-6 mob names per front zone and faction besides the
--      camp hunts and garrisons, no front quest hunts a camp hunt's role,
--      the free front at about a quarter kill;
--   K. the line plan; new ids never start with camp_ or guild_;
--   L. build_structure.py --check: the files' structure is the script's.
-- Offering and taking the shipped quests through the real loader is
-- tools/r28_q0's section 5 (the load-time checks pass); the spine's places,
-- tags and hand-offs are tools/r36_qa's and tools/r36_qt's.
--
--   luajit tools/r62_frontquests/portable_test.lua [REPO]
-- Prints "R62 FRONTQUESTS PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local ROOT = arg and arg[1] or "."
-- The level a quest opens at (Round 65 ruling 3: its level - 2, at least 1;
-- grug_quests.acceptance_level). The quest files name no minimum level.
local function opens(q) return math.max(1, q.level - 2) end
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
local function count_of(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

------------------------------------------------------------------------------
-- Engine stub (tools/r61_bandquests'): the real grug_gear and grug_quality.
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function() return function() end end})
end
local modpaths = {grug_gear = ROOT .. "/mods/ITEMS/grug_gear", grug_quality = ROOT .. "/mods/ITEMS/grug_quality"}
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
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end,
	pool_percent_amount = function() return 42 end})
grug_mobs = permissive({register_kill_loot_hook = function() end, register_boss_reward_hook = function() end,
	subtype = function() return nil end, pvp_garrison = {pvp_kind = function() return nil end}})
grug_inventory = permissive({})
grug_xp = permissive({get_level = function() return 60 end})
local function new_meta()
	local store = {}
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
local function new_stack(name, count)
	local meta = new_meta()
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
	if type(value) == "table" then return new_stack(value:get_name(), value:get_count()) end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)$")
	return new_stack(name, tonumber(count))
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

------------------------------------------------------------------------------
-- The quest files.
------------------------------------------------------------------------------
local DIR = "mods/PLAYER/grug_quests/data/zones/"
local by_id, file_of, zone_of, all_files, followers, hubs = {}, {}, {}, {}, {}, {}
do
	local handle = io.popen('ls "' .. ROOT .. '/' .. DIR .. '"')
	for name in handle:lines() do
		if name:find("%.json$") then
			local data = read_json(DIR .. name)
			all_files[#all_files + 1] = {name = name, data = data}
			for _, hub in ipairs(data.hubs or {}) do
				for _, giver in ipairs(hub.givers) do hubs[giver.npc] = table.concat(giver.lines, ",") end
			end
			for _, quest in ipairs(data.quests) do
				check(by_id[quest.id] == nil, quest.id .. ": one id, one quest in all files")
				by_id[quest.id], file_of[quest.id], zone_of[quest.id] = quest, name, data.zone
				for _, id in ipairs(quest.requires or {}) do
					followers[id] = followers[id] or {}
					table.insert(followers[id], quest.id)
				end
			end
		end
	end
	handle:close()
end

------------------------------------------------------------------------------
-- A. All 48 files flagged.
------------------------------------------------------------------------------
eq(#all_files, 48, "A the 48 quest files")
for _, file in ipairs(all_files) do
	eq(file.data.reworked, true, "A " .. file.name .. " is reworked")
end
local FRONT_FILES = {"elandor_ashenward_march", "elandor_stormvault_heights", "elandor_lethariel",
	"elandor_dur_brannoc", "elandor_highcourt", "kragmar_bannerbreak_mesa", "kragmar_blackwind_rise",
	"kragmar_kezamba", "kragmar_gor_drazhak", "kragmar_nhal_veyr"}
for _, zone in ipairs(FRONT_FILES) do
	local data = read_json(DIR .. zone .. ".front.quests.json")
	for key in pairs(data) do
		check(key == "zone" or key == "reworked" or key == "quests" or key == "notes",
			"A " .. zone .. ".front: a front file holds zone, the flag and quests (" .. key .. ")")
	end
	for _, quest in ipairs(data.quests) do eq(quest.line, "front", "A " .. quest.id .. ": on its giver's front line") end
end

------------------------------------------------------------------------------
-- B. The spine.
------------------------------------------------------------------------------
-- {id, requires} in play order (r36_qa SPINE, r36_qt CHAPTERS).
local SPINE = {
	accord = {
		{"accord_main_impounded", ""}, {"cinderline_front_05", "accord_main_impounded"},
		{"cinderline_front_04", "cinderline_front_05"}, {"archshadow_front_02", "cinderline_front_04"},
		{"archshadow_front_03", "archshadow_front_02"}, {"accord_main_accounts", "archshadow_front_03"},
		{"accord_main_standard", "accord_main_accounts"}, {"lasthedge_front_04", "accord_main_standard"},
		{"accord_main_orders", "lasthedge_front_04"}, {"accord_main_audit", "accord_main_orders"},
		{"accord_main_roll", "accord_main_audit"}, {"splitbolt_front_08", "accord_main_roll"},
		{"splitbolt_front_06", "splitbolt_front_08"}, {"lethariel_front_04", "splitbolt_front_06"},
		{"accord_main_tally", "lethariel_front_04"}, {"accord_main_collector", "accord_main_tally"},
		{"accord_main_final", "accord_main_collector"},
	},
	throng = {
		{"throng_main_01", ""}, {"bb_front_ramp_04", "throng_main_01"}, {"bb_front_ramp_05", "bb_front_ramp_04"},
		{"throng_main_02", "bb_front_ramp_05"}, {"throng_main_03", "throng_main_02"},
		{"bb_front_torn_05", "throng_main_03"}, {"throng_main_04", "bb_front_torn_05"},
		{"throng_main_05", "throng_main_04"}, {"throng_main_06", "throng_main_05"},
		{"bw_front_ashveil_04", "throng_main_06"}, {"kz_front_04", "bw_front_ashveil_04"},
		{"throng_main_07", "bw_front_ashveil_04,kz_front_04"}, {"throng_main_finale", "throng_main_07"},
		{"throng_main_final", "throng_main_finale"},
	},
}
local BRANCHES = {accord_main_stonegrudge = "accord_main_orders", throng_main_greyvow = "throng_main_05"}
local IN_SPINE = {}
for faction, steps in pairs(SPINE) do
	for _, row in ipairs(steps) do IN_SPINE[row[1]] = faction end
end
eq(count_of(IN_SPINE), 31, "B 31 spine steps")
for _, steps in pairs(SPINE) do
	for _, row in ipairs(steps) do
		local quest = by_id[row[1]]
		if check(quest ~= nil, "B " .. row[1] .. " ships") then
			eq(quest.story, true, "B " .. row[1] .. " is story")
			eq(sorted_join(quest.requires), row[2], "B " .. row[1] .. " requires only spine steps")
			check(type(quest.completion) == "string" and #quest.completion > 0, "B " .. row[1] .. " has a completion")
			check(not quest.title:find("^%[PH%]"), "B " .. row[1] .. ": its shipped title stays")
		end
	end
end
for id, requires in pairs(BRANCHES) do
	local quest = by_id[id]
	check(quest and quest.story == true and quest.optional == true and quest.group == true,
		"B " .. id .. ": an optional story branch")
	eq(quest and sorted_join(quest.requires), requires, "B " .. id .. ": after its spine step")
end
for _, id in ipairs({"accord_main_impounded", "throng_main_01"}) do
	eq(opens(by_id[id]), 40, "B " .. id .. ": the join at 40 (Round 65: level 42 - 2)")
	eq(#by_id[id].requires, 0, "B " .. id .. ": requires nothing (round62-plan.md §2a point 2)")
end
-- Nothing outside the spine and the branches is story at 41-60 but the
-- guild reports (Round 58).
for id, quest in pairs(by_id) do
	if quest.level >= 41 and quest.story and not IN_SPINE[id] and not BRANCHES[id] then
		check(id:find("^guild_t[56]_report_") ~= nil, "B " .. id .. ": no other story quest at 41-60")
	end
end
-- The spine's followers are spine steps, the branches, or nothing.
for id in pairs(IN_SPINE) do
	for _, follower in ipairs(followers[id] or {}) do
		check(IN_SPINE[follower] or BRANCHES[follower], "B " .. id .. " is followed only on the spine (" .. follower .. ")")
	end
end

------------------------------------------------------------------------------
-- C. Free play at 41-60.
------------------------------------------------------------------------------
-- The allowed predecessor of a free quest: the fortress raids' second camp
-- and the island bounty pairs (round62-plan.md §2 point 1, §2a point 4).
local ALLOWED = {
	ashenward_bastion_picket_shattered = "ashenward_bastion_picket_broken",
	ashenward_bastion_warcamp_shattered = "ashenward_bastion_warcamp_broken",
	ashenward_bastion_picket_gravesalt = "ashenward_bastion_picket_skyglass",
	ashenward_bastion_warcamp_gravesalt = "ashenward_bastion_warcamp_skyglass",
	bannerbreak_warhold_picket_broken = "bannerbreak_warhold_picket_shattered",
	bannerbreak_warhold_warcamp_broken = "bannerbreak_warhold_warcamp_shattered",
	bannerbreak_warhold_picket_skyglass = "bannerbreak_warhold_picket_gravesalt",
	bannerbreak_warhold_warcamp_skyglass = "bannerbreak_warhold_warcamp_gravesalt",
	durbrannoc_front_02 = "durbrannoc_front_01", highcourt_front_02 = "highcourt_front_01",
	gordrazhak_last_offering = "gordrazhak_krait_bounty",
}
local FREE = {}
for id, quest in pairs(by_id) do
	if quest.level >= 41 and not quest.story and not id:find("^camp_") and not id:find("^guild_") then
		FREE[id] = quest
		eq(sorted_join(quest.requires), ALLOWED[id] or "", "C " .. id .. ": free, a level only")
		-- Round 65: opens at its level - 2, so from 39.
		check(opens(quest) >= 39 and opens(quest) <= quest.level, "C " .. id .. ": its levels")
	end
end
for id in pairs(FREE) do
	local list = followers[id] or {}
	check(#list <= 1, "C " .. id .. ": at most one follow-up (" .. sorted_join(list) .. ")")
	for _, follower in ipairs(list) do
		eq(ALLOWED[follower], id, "C " .. id .. ": its follow-up " .. follower .. " is an allowed pair")
	end
end

------------------------------------------------------------------------------
-- D. The group quests.
------------------------------------------------------------------------------
local function enchants_of(quest)
	local most = 0
	for _, choice in ipairs(quest.rewards.choices or {}) do most = math.max(most, #(choice.affixes or {})) end
	for _, row in ipairs(quest.rewards.items or {}) do most = math.max(most, #(row.affixes or {})) end
	return most
end
local GROUP_50 = {front_engine_nine = "siege_engine_nine", front_last_toll = "last_toll_construct"}
local below = 0
for id, quest in pairs(by_id) do
	if quest.group and quest.level >= 41 then
		check(quest.title:find("Party: ", 1, true) ~= nil, "D " .. id .. ": a Party: title")
		if quest.level <= 50 then
			below = below + 1
			check(GROUP_50[id] ~= nil, "D " .. id .. ": one of the two group quests below 51")
			eq(#(quest.requires or {}), 0, "D " .. id .. ": standalone, requires nothing")
			eq(#(followers[id] or {}), 0, "D " .. id .. ": required by nothing")
			eq(quest.optional, true, "D " .. id .. ": optional")
			eq(enchants_of(quest), 0, "D " .. id .. ": no key reward (a plain trinket choice)")
			eq(quest.objectives[1].roles[1], GROUP_50[id], "D " .. id .. ": its elite")
		elseif not IN_SPINE[id] then
			check(quest.optional == true and #(followers[id] or {}) == 0, "D " .. id .. ": optional, nothing needs it")
		end
	end
end
eq(below, 2, "D two group quests below 51 (Engine Nine, Last-Toll), each shared by both factions")
for _, id in ipairs({"lasthedge_front_05", "archshadow_front_04", "bb_front_torn_06", "bw_front_hollow_03"}) do
	eq(by_id[id], nil, "D " .. id .. ": folded into the shared group quest")
end

------------------------------------------------------------------------------
-- E. The shared front quests.
------------------------------------------------------------------------------
local NPC = {borin = "r20_anchor_027_host", alna = "r20_anchor_028_host", toren = "r20_anchor_031_host",
	nella = "r20_anchor_032_host", vaska = "r20_anchor_039_host", orrel = "r20_anchor_040_host",
	drek = "r20_anchor_043_host", yarra = "r20_anchor_044_host", mariel = "r20_human_capital_envoy",
	dorrin = "r20_dwarf_capital_envoy", eriath = "r20_elf_capital_envoy", thorga = "r20_orc_capital_envoy",
	nalo = "r20_troll_capital_envoy", ossa = "r20_undead_capital_envoy"}
local HOME = {toren = "elandor_ashenward_march", nella = "elandor_ashenward_march", alna = "elandor_stormvault_heights",
	drek = "kragmar_bannerbreak_mesa", yarra = "kragmar_bannerbreak_mesa", orrel = "kragmar_blackwind_rise"}
local SHARED = {
	front_potatoes = {"toren", "drek"}, front_return_light = {"toren", "drek"}, front_ford_salvage = {"toren", "drek"},
	front_relief_count = {"nella", "yarra"}, front_salt_stores = {"nella", "yarra"}, front_old_wire = {"nella", "yarra"},
	front_engine_nine = {"nella", "yarra"}, front_stormkelp = {"alna", "orrel"}, front_last_toll = {"alna", "orrel"},
	front_beyond_line = {"nella", "alna", "yarra"},
}
for id, givers in pairs(SHARED) do
	local quest = by_id[id]
	if check(quest ~= nil, "E " .. id .. " ships") then
		eq(file_of[id], HOME[givers[1]] .. ".quests.json", "E " .. id .. ": in its first variant's base file")
		eq(quest.line, "border", "E " .. id .. ": on the hosts' line")
		eq(#quest.variants, #givers, "E " .. id .. ": one variant per giver")
		for index, variant in ipairs(quest.variants) do
			eq(variant.zone, HOME[givers[index]], "E " .. id .. ": variant " .. index .. "'s zone")
			eq(table.concat(variant.givers, ","), NPC[givers[index]], "E " .. id .. ": variant " .. index .. "'s giver")
		end
		check(quest.level >= 41 and quest.level <= 50, "E " .. id .. ": at 41-50")
	end
end
local shared_count = 0
for id, quest in pairs(by_id) do
	if quest.level >= 41 and quest.variants and not id:find("^camp_") and not id:find("^guild_") then
		shared_count = shared_count + 1
		check(SHARED[id] ~= nil, "E " .. id .. ": a shared front quest of the draft")
	end
end
eq(shared_count, 10, "E ten shared front quests (F1-F10)")
-- F10: Nella and Alna to Borin, Yarra to Nalo.
do
	local quest = by_id.front_beyond_line
	local want = {NPC.borin, NPC.borin, NPC.nalo}
	for index, variant in ipairs(quest and quest.variants or {}) do
		local npc = variant.objectives and variant.objectives[1].npc or quest.objectives[1].npc
		eq(npc, want[index], "E front_beyond_line: variant " .. index .. " travels on")
		eq(table.concat(variant.turnins or {}, ","), want[index], "E front_beyond_line: variant " .. index .. "'s turn-in")
	end
end

------------------------------------------------------------------------------
-- F. The departures.
------------------------------------------------------------------------------
local DEPARTURES = {archshadow_road_dorrin = "dorrin", bb_ramp_road_thorga = "thorga",
	splitbolt_road_eriath = "eriath", hollow_road_ashveil = "vaska", ashveil_road_ossa = "ossa"}
local function work_at(npc, level)
	-- a free quest the destination gives at once on arrival
	for id, quest in pairs(FREE) do
		local gives = quest.giver == npc
		for _, variant in ipairs(quest.variants or {}) do
			for _, giver in ipairs(variant.givers) do gives = gives or giver == npc end
		end
		if gives and #(quest.requires or {}) == 0 and opens(quest) <= level + 1 and
				quest.objectives[1].type ~= "talk" then
			return id
		end
	end
end
for id, who in pairs(DEPARTURES) do
	local quest = by_id[id]
	if check(quest ~= nil, "F " .. id .. " ships") then
		eq(#quest.objectives, 1, "F " .. id .. ": one objective")
		eq(quest.objectives[1].npc, NPC[who], "F " .. id .. ": a travel to " .. who)
		eq(quest.turnin, NPC[who], "F " .. id .. ": turned in there")
		eq(#quest.requires, 0, "F " .. id .. ": requires nothing")
		check(work_at(NPC[who], opens(quest)) ~= nil, "F " .. who .. " has free work at once (" .. id .. ")")
	end
end
check(work_at(NPC.borin, 50) ~= nil and work_at(NPC.nalo, 50) ~= nil, "F Borin and Nalo have work at 50 (F10)")
-- Eriath's Skyglass work opens at 51 (round62-plan.md §2 point 6).
check(work_at(NPC.eriath, 50) ~= nil, "F Eriath's work opens at 51")

------------------------------------------------------------------------------
-- G. The island pairs.
------------------------------------------------------------------------------
local PAIRS = {
	{"durbrannoc_front_01", "durbrannoc_front_02", "accord", "crown_crag_eagle", "rime_bell_warden"},
	{"highcourt_front_01", "highcourt_front_02", "accord", "last_watch_zombie", "last_offering_ape"},
	{"gordrazhak_krait_bounty", "gordrazhak_last_offering", "throng", "glass_fang_serpent", "last_offering_ape"},
}
for _, row in ipairs(PAIRS) do
	local bounty, elite = by_id[row[1]], by_id[row[2]]
	if check(bounty and elite, "G " .. row[1] .. " and " .. row[2] .. " ship") then
		eq(bounty.objectives[1].roles[1], row[4], "G " .. row[1] .. ": its hunt")
		eq(elite.objectives[1].roles[1], row[5], "G " .. row[2] .. ": its elite")
		check(bounty.optional and bounty.title:find("Optional: ", 1, true), "G " .. row[1] .. ": optional")
		check(elite.group and elite.optional, "G " .. row[2] .. ": an optional group quest")
		for _, quest in ipairs({bounty, elite}) do
			eq(quest.rewards.weight, 0, "G " .. quest.id .. ": coin, no leveling")
			check((quest.rewards.copper or 0) > 0, "G " .. quest.id .. ": a coin bounty")
			eq(opens(quest), 58, "G " .. quest.id .. ": at 60, open from 58 (Round 65)")
		end
	end
end
-- The Throng's hunt is another mob than the Accord's (plan review I2), and
-- shows as Krait on Stormscale Summit (the check).
local names = read_json("mods/ENTITIES/grug_mobs/data/names.json").names
eq(names["front_stormscale_summit/glass_fang_serpent/L60-60"], "Krait", "G the Throng's bounty reads Krait")
for _, id in ipairs({"accord_main_island_cairn", "accord_main_island_wreck", "throng_main_island_cairn",
		"throng_main_island_wreck"}) do
	local quest = by_id[id]
	check(quest and quest.optional == true and #quest.requires == 0 and quest.rewards.weight == 0,
		"G " .. id .. ": an optional island use, free from 60")
end

------------------------------------------------------------------------------
-- H. The rewards per faction and band.
------------------------------------------------------------------------------
local CAPITAL = {elandor_dur_brannoc = true, elandor_highcourt = true, elandor_lethariel = true,
	kragmar_gor_drazhak = true, kragmar_kezamba = true, kragmar_nhal_veyr = true}
local FACTION_OF_ZONE = {elandor_ashenward_march = "accord", elandor_stormvault_heights = "accord",
	elandor_dur_brannoc = "accord", elandor_highcourt = "accord", elandor_lethariel = "accord",
	kragmar_bannerbreak_mesa = "throng", kragmar_blackwind_rise = "throng", kragmar_gor_drazhak = "throng",
	kragmar_kezamba = "throng", kragmar_nhal_veyr = "throng"}
local function zones_of(id, quest)
	local out = {}
	for _, variant in ipairs(quest.variants or {}) do out[#out + 1] = variant.zone end
	if #out == 0 then out[1] = zone_of[id] end
	return out
end
local function slot_of(item)
	local groups = (registered[item] or {}).groups or {}
	for _, slot in ipairs({"head", "chest", "legs", "feet"}) do
		if (groups["grug_equip_" .. slot] or 0) > 0 then return slot end
	end
end
local TIER_WORDS = {[5] = {"embersteel", "silk", "sleek", "_t5"}, [6] = {"abyssal_steel", "stormweave", "nightscale", "_t6"}}
local function of_tier(item, tier)
	for _, word in ipairs(TIER_WORDS[tier]) do
		if item:find(word, 1, true) then return true end
	end
	return false
end
-- pattern[faction][band] = {armor = {id = slot}, weapons = {}, trinkets = {}, potions = {}}
local pattern = {accord = {[5] = {}, [6] = {}}, throng = {[5] = {}, [6] = {}}}
for _, f in pairs(pattern) do
	for _, b in pairs(f) do b.armor, b.weapons, b.trinkets, b.potions = {}, {}, {}, {} end
end
local budget = {}
for id, quest in pairs(by_id) do
	local choices = quest.rewards.choices
	if quest.level >= 41 and choices and not id:find("^camp_") then
		local tier = quest.level <= 50 and 5 or 6
		local enchants = enchants_of(quest)
		local factions = {}
		for _, zone in ipairs(zones_of(id, quest)) do
			if FACTION_OF_ZONE[zone] then factions[FACTION_OF_ZONE[zone]] = true end
			if enchants > 0 and not CAPITAL[zone] then
				local key = zone .. "/" .. tier
				budget[key] = budget[key] or {[1] = {}, [2] = {}}
				table.insert(budget[key][enchants], id)
			end
		end
		for index, choice in ipairs(choices) do
			local label = ("H %s choice %d (%s)"):format(id, index, choice.item)
			check(of_tier(choice.item, tier), label .. ": tier " .. tier .. " at reward level " .. quest.level)
			if choice.affixes and #choice.affixes > 0 then
				local ok, reason = grug_items.check_affixes(choice.item, choice.affixes)
				check(ok, label .. ": enchants in the pool: " .. tostring(reason))
				local stack = ok and grug_items.make_stack(choice.item, quest.level, choice.affixes)
				if stack then
					eq(stack:get_meta():get_int("grug_ilvl"), quest.level, label .. ": item level = reward level")
					eq(grug_items.enchant_tier(quest.level), tier, label .. ": enchant tier " .. tier)
				end
			end
		end
		local first = choices[1].item
		for faction in pairs(factions) do
			local row = pattern[faction][tier]
			if first:find("^grug_alchemy:potion_") then
				row.potions[#row.potions + 1] = id
				-- Round 65: such a quest opens two levels below its reward level.
				check(quest.level >= (tier == 5 and 41 or 51), "H " .. id .. ": Potion " .. (tier == 5 and "V" or "VI") ..
					" from its tier's first reward level")
			elseif enchants == 1 then
				local slot = slot_of(first)
				row.armor[id] = slot
				eq(#choices, 3, "H " .. id .. ": cloth, leather, metal")
				for _, choice in ipairs(choices) do eq(slot_of(choice.item), slot, "H " .. id .. ": one slot") end
			elseif enchants == 2 then
				row.weapons[#row.weapons + 1] = id
				check(not quest.group, "H " .. id .. ": the weapon on a solo quest")
				eq(#choices, 3, "H " .. id .. ": one weapon per line")
			elseif first:find("^grug_gear:.+_t[56]$") then
				row.trinkets[#row.trinkets + 1] = id
			end
		end
	end
end
for faction, bands in pairs(pattern) do
	for tier, row in pairs(bands) do
		local label = ("H %s %d-%d: "):format(faction, tier * 10 - 9, tier * 10)
		local slots = {}
		for _, slot in pairs(row.armor) do slots[slot] = true end
		eq(count_of(row.armor), 6, label .. "six armor quests with one enchant")
		for _, slot in ipairs({"head", "chest", "legs", "feet"}) do check(slots[slot], label .. "the " .. slot .. " slot") end
		eq(#row.weapons, 3, label .. "three weapon quests")
		eq(#row.trinkets, 3, label .. "three trinket choices")
		check(#row.potions >= 1, label .. "a potion choice")
	end
end
for key, rows in pairs(budget) do
	check(#rows[1] <= 2, "H " .. key .. ": at most two one-enchant rewards (" .. table.concat(rows[1], ",") .. ")")
	check(#rows[2] <= 1, "H " .. key .. ": at most one two-enchant reward (" .. table.concat(rows[2], ",") .. ")")
end
for _, id in ipairs({"accord_main_final", "throng_main_final"}) do
	local quest = by_id[id]
	eq(enchants_of(quest), 2, "H " .. id .. ": one key reward, the weapon choice")
end

------------------------------------------------------------------------------
-- I. The places.
------------------------------------------------------------------------------
local objects = read_json("mods/PLAYER/grug_quests/data/use_objects.json")
local socket_places = dofile(ROOT .. "/tools/r59_qsys3/socket_places.lua")
local clash = {}
for _, row in ipairs(dofile(ROOT .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua").roster) do
	if row.art and row.art.kind == "clash" then clash[row.key] = row.zone_id end
end
local recipes = {}
local function recipe(zone)
	if recipes[zone] == nil then
		local data = read_json("mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json")
		recipes[zone] = data and data.recipe or false
	end
	return recipes[zone]
end
local function place_ok(ref, zone)
	if clash[ref] then return true end
	local key, socket_id = socket_places.parse_ref(ref)
	if key then
		local found = socket_places.sockets(ROOT, {key})[key]
		for _, socket in ipairs(found and found.sockets or {}) do
			if socket.id == socket_id then return socket.role == "quest_place" end
		end
		return false
	end
	local pzone, pid = ref:match("^([^/]+)/(.+)$")
	pzone, pid = pzone or zone, pid or ref
	local rec = recipe(pzone)
	for _, row in ipairs(rec and rec.places or {}) do
		if row.id == pid then return row.at.pick == "farthest_from_roads" end
	end
	return false
end
local uses = 0
for id, quest in pairs(by_id) do
	if quest.level >= 41 then
		for index, objective in ipairs(quest.objectives) do
			if objective.type == "use" then
				check(objects[objective.object] ~= nil, "I " .. id .. ": the kind " .. tostring(objective.object))
				for _, variant in ipairs(quest.variants or {{zone = zone_of[id]}}) do
					uses = uses + 1
					local own = variant.objectives and variant.objectives[index] and variant.objectives[index].place
					check(place_ok(own or objective.place, variant.zone), "I " .. id .. ": " ..
						tostring(own or objective.place) .. " resolves")
				end
			end
		end
		local text = (quest.title or "") .. " " .. (quest.text or "") .. " " .. (quest.completion or "")
		for _, variant in ipairs(quest.variants or {}) do text = text .. " " .. (variant.text or "") end
		check(not text:find("West Trench Mouth", 1, true) and not text:find("{name:r20_anchor_081}", 1, true),
			"I " .. id .. ": no text names West Trench Mouth")
	end
end
local NEW_PLACES = {
	{"front_broken_causeway", "return_stand", "floodmeadows"}, {"front_broken_causeway", "crossing_stand", "wraithwood"},
	{"front_shattered_line", "relief_rest", "approaches"}, {"front_gravesalt_escarpment", "shoring_check", "saltflats"},
	{"front_gravesalt_escarpment", "work_laydown", "blight_terraces"},
	{"front_gravesalt_escarpment", "recovery_post", "tombwood"},
	{"front_skyglass_canopy", "carrier_clearing", "clearings"}, {"front_skyglass_canopy", "receiving_stand", "rootways"},
}
for _, row in ipairs(NEW_PLACES) do
	local found
	for _, place in ipairs(recipe(row[1]).places or {}) do
		if place.id == row[2] then found = place end
	end
	check(found and found.at.kind == row[3], "I " .. row[1] .. ": the place " .. row[2] .. " in the " .. row[3])
	local used = false
	for _, quest in pairs(by_id) do
		for index, objective in ipairs(quest.objectives) do
			local refs = {objective.place}
			for _, variant in ipairs(quest.variants or {}) do
				refs[#refs + 1] = variant.objectives and variant.objectives[index] and variant.objectives[index].place
			end
			for _, ref in ipairs(refs) do used = used or ref == row[1] .. "/" .. row[2] end
		end
	end
	check(used, "I " .. row[1] .. "/" .. row[2] .. " is used")
end
-- The free clash sites 076, 079, 080, 083, 085 and Stormvault's free held load.
for _, ref in ipairs({"r20_anchor_076", "r20_anchor_079", "r20_anchor_080", "r20_anchor_083", "r20_anchor_085",
		"socket:mining_camp_stormvault_heights/held_load"}) do
	local used = false
	for _, quest in pairs(by_id) do
		for _, objective in ipairs(quest.objectives) do used = used or objective.place == ref end
	end
	check(used, "I " .. ref .. " is used")
end
eq(count_of(objects) - 1, 21, "I no new object kind (K10 A)")
check(uses > 0, "I the uses were read (" .. uses .. ")")

------------------------------------------------------------------------------
-- J. Names and kills.
------------------------------------------------------------------------------
local FRONT_ZONES = {"front_broken_causeway", "front_shattered_line", "front_gravesalt_escarpment",
	"front_skyglass_canopy"}
local LEADER_ZONE = {}
for _, zone in ipairs(FRONT_ZONES) do
	for _, leader in ipairs(recipe(zone).leaders or {}) do LEADER_ZONE[leader.role] = zone end
end
-- The camp hunts' roles (r58_guildquests ~251-273): no other front quest
-- hunts them.
local HUNTS = {}
for _, id in ipairs({"camp_hunt_t5_low", "camp_hunt_t5_high", "camp_hunt_t6_low", "camp_hunt_t6_high"}) do
	HUNTS[by_id[id].objectives[1].roles[1]] = true
end
local function names_of(zone, role)
	local out = {}
	for slot, name in pairs(names) do
		local z, r = slot:match("^([^/]+)/([^/]+)/")
		if z == zone and r == role then out[name] = true end
	end
	return out
end
local mobs = {}
local free_kills, free_all = {accord = 0, throng = 0}, {accord = 0, throng = 0}
for id, quest in pairs(by_id) do
	if quest.level >= 41 and not id:find("^camp_") and not id:find("^guild_") then
		local factions = {}
		for _, zone in ipairs(zones_of(id, quest)) do
			if FACTION_OF_ZONE[zone] then factions[FACTION_OF_ZONE[zone]] = true end
		end
		local function count_roles(roles, area)
			local zone = area and area:match("^([^/]+)/") or LEADER_ZONE[roles[1]]
			for _, role in ipairs(roles) do
				check(not HUNTS[role], "J " .. id .. " hunts no camp hunt's role (" .. role .. ")")
				if zone and not role:find("^guard_") and not role:find("^captain_") and not role:find("^commander_") then
					for faction in pairs(factions) do
						local key = zone .. "/" .. faction
						mobs[key] = mobs[key] or {}
						for name in pairs(names_of(zone, role)) do mobs[key][name] = true end
					end
				end
			end
		end
		for _, objective in ipairs(quest.objectives) do
			if objective.roles then count_roles(objective.roles, objective.area) end
			for faction in pairs(factions) do
				-- the free front: the fortress quests stay as Round 31 shipped them (K13 A)
				if FREE[id] and not id:find("^ashenward_bastion_") and not id:find("^bannerbreak_warhold_") then
					free_all[faction] = free_all[faction] + 1
					if objective.type == "kill" then free_kills[faction] = free_kills[faction] + 1 end
				end
			end
		end
		for _, drop in ipairs(quest.quest_drops or {}) do count_roles(drop.roles, drop.area) end
	end
end
for _, zone in ipairs(FRONT_ZONES) do
	for _, faction in ipairs({"accord", "throng"}) do
		local key = zone .. "/" .. faction
		local n = count_of(mobs[key] or {})
		check(n >= 3 and n <= 6, "J " .. key .. ": three to six mob names besides the camp hunts and garrisons (" .. n .. ")")
	end
end
for faction, all in pairs(free_all) do
	local share = free_kills[faction] / all
	check(share <= 0.3, ("J %s: the free front about a quarter kill (%d of %d)"):format(faction, free_kills[faction], all))
end

------------------------------------------------------------------------------
-- K. The line plan and the ids.
------------------------------------------------------------------------------
local LINES = {[NPC.borin] = "passes,front", [NPC.alna] = "border,front", [NPC.toren] = "border,front",
	[NPC.nella] = "border,front", [NPC.vaska] = "ashes,front", [NPC.orrel] = "border,front",
	[NPC.drek] = "border,front", [NPC.yarra] = "border,front", [NPC.mariel] = "envoy,front",
	[NPC.dorrin] = "envoy,front", [NPC.eriath] = "envoy,front", [NPC.thorga] = "envoy,front",
	[NPC.nalo] = "envoy,front", [NPC.ossa] = "envoy,front"}
for npc, want in pairs(LINES) do eq(hubs[npc], want, "K " .. npc .. ": its lines") end
for id, quest in pairs(by_id) do
	if quest.level >= 41 and (quest.notes or ""):find("^Round 62 FRONTQUESTS") and not quest.title:find("^Optional") then
		check(not id:find("^camp_") and not id:find("^guild_"), "K " .. id .. ": a new id never starts with camp_/guild_")
	end
end

------------------------------------------------------------------------------
-- L. The generator's structure check.
------------------------------------------------------------------------------
do
	local handle = io.popen("cd '" .. ROOT .. "' && python3 tools/r62_frontquests/build_structure.py --check 2>&1")
	local out = handle:read("*a")
	handle:close()
	check(out:find("build_structure: 18 files, 0 differ", 1, true) ~= nil, "L build_structure.py --check: " .. out)
end

for _, zone in ipairs(FRONT_ZONES) do
	for _, faction in ipairs({"accord", "throng"}) do
		local list = {}
		for name in pairs(mobs[zone .. "/" .. faction] or {}) do list[#list + 1] = name end
		table.sort(list)
		print(("%s %s: %d names (%s)"):format(zone, faction, #list, table.concat(list, ", ")))
	end
end
for faction, all in pairs(free_all) do
	print(("%s free front: %d of %d objectives kill"):format(faction, free_kills[faction], all))
end
if failures > 0 then
	error(("R62 FRONTQUESTS PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R62 FRONTQUESTS PORTABLE PASS checks=%d"):format(checks))
