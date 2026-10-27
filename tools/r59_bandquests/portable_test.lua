-- Round 59 lane BANDQUESTS portable test (LuaJIT): the band 11-20's six
-- shipped quest files on the Round 57 quest foundation (round59-plan.md §2,
-- §2a, §4 BANDQUESTS; quests.md "The band 11-20"), with the REAL grug_gear
-- and grug_quality for the reward stacks:
--   A. the files: all six reworked, the quests each zone offers (shared
--      variants and local quests), every shared quest in its first
--      variant's file with one variant per zone, given by that zone's
--      steward or local; the Round 58 guild report and camp hunt kept;
--   B. free play: no story quest but the guild reports, nothing required
--      but a level, no quest of the band followed by another; the band's
--      first quests (min level 9-10) require nothing;
--   C. the departures: the six ids, a travel quest from the zone's captive
--      (Mournfen: its scout) to the capital's envoy at 19, requiring nothing;
--   D. the witness and the perpetrator local (K14): the travel to the
--      zone's captive and the named leader's kill are local quests of their
--      own zone; the kill objectives name few mobs per zone;
--   E. no reward is a requested item;
--   F. the reward pattern per zone: the early potion choice, two armor
--      choices on two slots (one per armor class, one enchant: a prefix,
--      then a suffix), the perpetrator's weapon choice (one per weapon
--      line, prefix and suffix); every enchant in its pool, every stack at
--      the quest's reward level (item level 11-20) with its enchants;
--   G. the use places: every place resolves (a town place: a quest_place
--      socket of the zone's bandit camp, built from its blueprint; a recipe
--      place of the zone's spawn file), every object a kind of
--      use_objects.json.
-- Offering and taking the shipped quests through the real grug_quests (a
-- shared quest taken or done in one zone is not offered in another) is
-- tools/r28_q0's section 5, which loads every shipped file.
--
--   luajit tools/r59_bandquests/portable_test.lua [REPO]
-- Prints "R59 BANDQUESTS PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
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
local function read_json(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end
function table.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = table.copy(child) end
	return out
end

------------------------------------------------------------------------------
-- Engine stub (tools/r57_startquests'): the real grug_gear and grug_quality.
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

-- Item groups and descriptions of everything else: the engine dump.
local existing = read_json("docs/planning/round28/items/existing.json")
local function in_group(item, group)
	local row = existing.items[item]
	return row ~= nil and (row.groups or {})[group] ~= nil and row.groups[group] > 0
end

------------------------------------------------------------------------------
-- A. The files.
------------------------------------------------------------------------------
local ZONES = {
	{"elandor_copperfell_foothills", "dwarf", "copperfell", "accord", "foreman_nog"},
	{"elandor_goldmead_vale", "human", "goldmead", "accord", "requisitioner_hobb"},
	{"elandor_starbough_vale", "elf", "starbough", "accord", "snarekeeper_vetch"},
	{"kragmar_mournfen", "undead", "mournfen", "throng", "reed_counter_silt"},
	{"kragmar_redtusk_savanna", "orc", "redtusk", "throng", "water_broker_korr"},
	{"kragmar_raincall_basin", "troll", "raincall", "throng", "tithe_keeper_vek"},
}
local BAND, RACE, TOWN = {}, {}, {}
for _, row in ipairs(ZONES) do BAND[row[1]], RACE[row[1]], TOWN[row[1]] = true, row[2], row[3] end
-- Round 58's quests in these files, kept as shipped (miners_guild.md §11).
local GUILD = {guild_t2_report_accord = true, guild_t2_report_throng = true, camp_hunt_t2 = true}
local DIR = "mods/PLAYER/grug_quests/data/zones/"
local files, by_id, offered = {}, {}, {}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	local data = read_json(DIR .. zone .. ".quests.json")
	files[zone] = data
	check(data and data.reworked == true, zone .. ": marked reworked")
	offered[zone] = {}
end
local function steward(zone) return "r14_" .. RACE[zone] .. "_steward" end
local function npc_local(zone) return "r15_" .. RACE[zone] .. "_local" end
local function scout(zone) return "r14_" .. RACE[zone] .. "_scout" end
local function captive(zone) return "r14_" .. RACE[zone] .. "_captive" end
local function foreman(zone) return "r58_foreman_mining_camp_" .. zone:match("^%a+_(.+)$") end
-- The quests a zone offers: its local quests and the variants of the shared
-- ones given there, wherever they live (the guild report: its variant there).
local shared_count, local_count = 0, 0
local SHARED_ZONES = {
	band_repairs = {"elandor_copperfell_foothills", "elandor_goldmead_vale", "elandor_starbough_vale",
		"kragmar_mournfen", "kragmar_redtusk_savanna", "kragmar_raincall_basin"},
	band_load_record = {"elandor_copperfell_foothills", "elandor_goldmead_vale"},
	band_held_supplies = {"kragmar_redtusk_savanna", "kragmar_raincall_basin"},
}
local SHARED_GIVER = {band_repairs = npc_local, band_load_record = steward, band_held_supplies = steward}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	for _, quest in ipairs(files[zone].quests) do
		by_id[quest.id] = {quest = quest, file = zone}
		if quest.variants then
			if not GUILD[quest.id] then
				shared_count = shared_count + 1
				eq(quest.variants[1].zone, zone, quest.id .. ": lives in its first variant's file")
				local want = SHARED_ZONES[quest.id]
				check(want ~= nil, quest.id .. ": a shared quest of the band (repairs, load record, held supplies)")
				eq(#quest.variants, want and #want or -1, quest.id .. ": one variant per zone that gives it")
				for index, variant in ipairs(quest.variants) do
					eq(variant.zone, want and want[index], quest.id .. ": variant " .. index .. "'s zone")
					local giver = SHARED_GIVER[quest.id]
					check(#variant.givers == 1 and giver and variant.givers[1] == giver(variant.zone),
						quest.id .. ": given in " .. variant.zone .. " by its zone's own NPC")
				end
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
eq(shared_count, 3, "three shared quests of the band (repairs, load record, held supplies)")
eq(local_count, 56, "56 local quests")
for _, row in ipairs(ZONES) do
	eq(#offered[row[1]], 13, row[1] .. ": quests offered (the guild report and the camp hunt among them)")
end
-- The Round 58 quests stay: the camp hunt given by every band zone's
-- foreman, the report of the zone's faction.
do
	local hunt = by_id.camp_hunt_t2 and by_id.camp_hunt_t2.quest
	if check(hunt ~= nil, "camp_hunt_t2 ships in a band file") then
		check(not hunt.story and #(hunt.requires or {}) == 0, "camp_hunt_t2 is free play")
		local seen = {}
		for _, variant in ipairs(hunt.variants) do seen[variant.zone] = variant.givers[1] end
		for _, row in ipairs(ZONES) do eq(seen[row[1]], foreman(row[1]), row[1] .. ": its foreman's camp hunt") end
	end
	for _, row in ipairs(ZONES) do
		local report = "guild_t2_report_" .. row[4]
		local found
		for _, quest in ipairs(offered[row[1]]) do found = found or quest.id == report end
		check(found, row[1] .. ": offers " .. report)
	end
end

-- Every quest file, for the follow-ups across files.
local all_quests = {}
do
	local handle = io.popen('ls "' .. ROOT .. '/' .. DIR .. '"')
	for name in handle:lines() do
		local data = read_json(DIR .. name)
		for _, quest in ipairs(data and data.quests or {}) do
			all_quests[#all_quests + 1] = {quest = quest, file = name}
		end
	end
	handle:close()
end
local followers = {}
for _, row in ipairs(all_quests) do
	for _, id in ipairs(row.quest.requires or {}) do
		followers[id] = followers[id] or {}
		table.insert(followers[id], row.quest.id)
	end
end

------------------------------------------------------------------------------
-- B. Free play.
------------------------------------------------------------------------------
for id, entry in pairs(by_id) do
	local quest = entry.quest
	if id:find("^guild_t2_report_") then
		check(quest.story == true, id .. ": the guild report stays a story quest")
	else
		check(not quest.story, id .. ": free play, no story quest")
		eq(#(quest.requires or {}), 0, id .. ": requires nothing but a level")
		eq(#(followers[id] or {}), 0, id .. ": no quest follows it")
		check(quest.level >= 11 and quest.level <= 20 and opens(quest) <= quest.level,
			id .. ": reward level within the band (" .. tostring(quest.level) .. ")")
	end
end
-- The band's first quests: a level-11 character finds quests at once.
for _, row in ipairs(ZONES) do
	local first = 99
	for _, quest in ipairs(offered[row[1]]) do
		if opens(quest) < first then first = opens(quest) end
	end
	check(first >= 9 and first <= 10, row[1] .. ": its first quests open at level 9-10 (" .. first .. ")")
end

------------------------------------------------------------------------------
-- C. The departures.
------------------------------------------------------------------------------
for _, row in ipairs(ZONES) do
	local zone, race = row[1], row[2]
	local id = row[3] .. "_departure"
	local entry = by_id[id]
	if check(entry ~= nil and entry.file == zone, id .. ": the departure id stays in its zone") then
		local quest = entry.quest
		local objective = quest.objectives[1]
		eq(#quest.objectives, 1, id .. ": one objective")
		check(objective.type == "talk" and objective.npc == "r20_" .. race .. "_capital_envoy" and
			quest.turnin == objective.npc, id .. ": a travel quest to the capital's envoy")
		eq(quest.giver, race == "undead" and scout(zone) or captive(zone), id .. ": given by the zone's witness side")
		eq(opens(quest), 17, id .. ": free from 17 (Round 65: its level 19 - 2)")
		eq(#(quest.requires or {}), 0, id .. ": requires nothing")
	end
end

------------------------------------------------------------------------------
-- D. The witness and the perpetrator stay local (K14); few mob names.
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
for _, row in ipairs(ZONES) do
	local zone, leader = row[1], row[5]
	local witness, perpetrator, kill_names = {}, {}, {}
	for _, quest in ipairs(offered[zone]) do
		for index, objective in ipairs(quest.objectives) do
			if objective.type == "talk" and objective.npc == captive(zone) then
				witness[#witness + 1] = quest
			elseif objective.type == "kill" then
				local roles = objective.roles
				for _, variant in ipairs(quest.variants or {}) do
					if variant.zone == zone and variant.objectives and variant.objectives[index] and
							variant.objectives[index].roles then
						roles = variant.objectives[index].roles
					end
				end
				for _, role in ipairs(roles) do
					if role == leader then perpetrator[#perpetrator + 1] = quest end
					for name in pairs(names_of(zone, role)) do kill_names[name] = true end
				end
			end
		end
	end
	eq(#witness, 1, zone .. ": one witness quest")
	check(witness[1] and not witness[1].variants and witness[1].giver == scout(zone),
		zone .. ": the witness quest is local, from the scout")
	eq(#perpetrator, 1, zone .. ": one quest against the named perpetrator")
	local p = perpetrator[1]
	check(p and not p.variants and p.giver == captive(zone), zone .. ": the perpetrator quest is local, the captive's")
	local count = 0
	for _ in pairs(kill_names) do count = count + 1 end
	check(count <= 3, zone .. ": at most three mob names in its kill objectives (" .. count .. ")")
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
local HEALING, MANA = "grug_alchemy:potion_healing_t2", "grug_alchemy:potion_mana_t2"
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
-- Each choice is made as the turn-in makes it: at the quest's reward level
-- with the author's enchants.
local function stacks_ok(id, quest)
	for index, choice in ipairs(quest.rewards.choices) do
		local label = ("%s choice %d (%s)"):format(id, index, choice.item)
		check(choice.item:find("_iron$") or choice.item:find("_woven$") or choice.item:find("_cured$"),
			label .. ": a tier-2 piece")
		local ok, reason = grug_items.check_affixes(choice.item, choice.affixes or {})
		check(ok, label .. ": enchants in the pool: " .. tostring(reason))
		local stack = ok and grug_items.make_stack(choice.item, quest.level, choice.affixes)
		if stack then
			eq(stack:get_meta():get_int("grug_ilvl"), quest.level, label .. ": item level = reward level")
			eq(#grug_items.get_affixes(stack), #choice.affixes, label .. ": its enchants")
			eq(stack:get_meta():get_int("grug_quality"), 1 + #choice.affixes, label .. ": its quality")
			eq(grug_items.enchant_tier(quest.level), 2, label .. ": enchant tier 2")
		end
	end
end
local slots_by_faction = {accord = {}, throng = {}}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	local potions, armor, weapons = {}, {}, {}
	for _, quest in ipairs(offered[zone]) do
		local choices = quest.rewards.choices
		if choices and not GUILD[quest.id] then
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
		check(p.level <= 12 and opens(p) <= 10, zone .. ": the potion choice is early (" .. p.id .. ")")
		eq(#p.rewards.choices, 2, zone .. ": two potion entries")
		local set = {}
		for _, choice in ipairs(p.rewards.choices) do set[choice.item .. " " .. (choice.count or 1)] = true end
		check(set[HEALING .. " 2"] and set[MANA .. " 2"], zone .. ": 2 Healing Potion II or 2 Mana Potion II")
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
				eq(#(choice.affixes or {}), 1, quest.id .. ": one enchant on " .. choice.item)
				eq((choice.affixes or {{}})[1].channel, index == 1 and "prefix" or "suffix",
					quest.id .. ": " .. (index == 1 and "a prefix" or "a suffix") .. " on " .. choice.item)
			end
			check(classes[1] and classes[2] and classes[3], quest.id .. ": cloth, leather and metal")
			slots[index] = slot
			if slot then slots_by_faction[row[4]][slot] = true end
			stacks_ok(quest.id, quest)
		end
		check(slots[1] and slots[1] ~= slots[2], zone .. ": the two armor choices are two slots")
	end
	eq(#weapons, 1, zone .. ": one weapon choice")
	local w = weapons[1]
	if w then
		eq(w.level, 19, zone .. ": the weapon choice at the zone's end (level 19)")
		local kills_leader = false
		for _, objective in ipairs(w.objectives) do
			for _, role in ipairs(objective.roles or {}) do kills_leader = kills_leader or role == row[5] end
		end
		check(kills_leader, zone .. ": the weapon is the perpetrator's")
		local lines = {}
		for _, choice in ipairs(w.rewards.choices) do
			local line = line_of(choice.item)
			check(line and not lines[line], w.id .. ": one weapon per line (" .. choice.item .. ")")
			if line then lines[line] = true end
			local channels = {}
			for _, affix in ipairs(choice.affixes or {}) do channels[affix.channel] = true end
			check(channels.prefix and channels.suffix, w.id .. ": prefix and suffix on " .. choice.item)
		end
		eq(#w.rewards.choices, 3, w.id .. ": three entries (Priest and Mage share)")
		stacks_ok(w.id, w)
	end
end
-- Each faction's three zones give all four armor slots.
for faction, slots in pairs(slots_by_faction) do
	check(slots.head and slots.chest and slots.legs and slots.feet, faction .. ": all four armor slots in the band")
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
					eq(key, TOWN[variant.zone] .. "_bandit_camp", id .. ": " .. variant.zone .. "'s place is its bandit camp")
					local found = places.sockets(ROOT, {key})[key]
					local role
					for _, socket in ipairs(found and found.sockets or {}) do
						if socket.id == socket_id then role = socket.role end
					end
					eq(role, "quest_place", id .. ": " .. place .. " is a quest_place socket")
				else
					local recipe = read_json("mods/ENTITIES/grug_mobs/data/zones/" .. variant.zone .. ".spawns.json").recipe
					local found
					for _, row in ipairs(recipe.places or {}) do found = found or row.id == place end
					check(found, id .. ": " .. place .. " is a quest place of " .. variant.zone .. "'s recipe")
				end
			end
		end
	end
end
eq(uses, 6, "one use at a place in each band zone")

if failures > 0 then
	error(("R59 BANDQUESTS PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R59 BANDQUESTS PORTABLE PASS checks=%d"):format(checks))
