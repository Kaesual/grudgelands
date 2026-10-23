-- Round 57 lane STARTQUESTS portable test (LuaJIT): the six start zones'
-- shipped quest files on the Round 57 quest foundation (round57-plan.md §2
-- rulings 9-12 and 15-18, §4 STARTQUESTS; quests.md "The start zones"),
-- with the REAL grug_gear and grug_quality for the reward stacks:
--   A. the files: all six reworked, the quests each zone offers (shared
--      variants and local quests), every shared quest in its first
--      variant's file with one variant per zone, given by that zone's elder
--      or cook;
--   B. free play: no story quest, nothing but a level required, only the
--      six departures follow a quest (their zone's finale), each quest
--      followed by at most one;
--   C. the boar and rat quests offered at once (level 1) in every zone, the
--      rats a night-only target of about a third of the boars' count;
--   D. no reward is a requested item (the tool swaps are gone), no quest
--      asks for a starter tool;
--   E. the reward pattern per zone: the early potion choice, the level-5
--      and level-7/8 armor choices on two slots (one per armor class, one
--      enchant), the finale's weapon choice (one per weapon line, prefix and
--      suffix); every enchant in its pool, every stack at the quest's reward
--      level with its enchants;
--   F. the six departure ids and the level-11 quests that require them.
-- Offering and taking the shipped quests through the real grug_quests (a
-- shared quest taken or done in one town is not offered in another) is
-- tools/r28_q0's section 5, which loads every shipped file.
--
--   luajit tools/r57_startquests/portable_test.lua [REPO]
-- Prints "R57 STARTQUESTS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
-- Engine stub (tools/r57_qsys/quality_test.lua's): the real grug_gear and
-- grug_quality.
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
	{"elandor_dawnmere_fields", "human"}, {"elandor_hearthpine_vale", "dwarf"},
	{"elandor_silverleaf_glades", "elf"}, {"kragmar_sunscar_flats", "orc"},
	{"kragmar_kapok_cradle", "troll"}, {"kragmar_stillgrave_hollow", "undead"},
}
local START, RACE = {}, {}
for _, row in ipairs(ZONES) do START[row[1]], RACE[row[1]] = true, row[2] end
local DIR = "mods/PLAYER/grug_quests/data/zones/"
local files, by_id, offered = {}, {}, {}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	local data = read_json(DIR .. zone .. ".quests.json")
	files[zone] = data
	check(data and data.reworked == true, zone .. ": marked reworked")
	offered[zone] = {}
end
-- The quests a zone offers: its local quests and the variants of the shared
-- ones given there, wherever they live.
local shared_count, local_count = 0, 0
for _, row in ipairs(ZONES) do
	local zone = row[1]
	for _, quest in ipairs(files[zone].quests) do
		by_id[quest.id] = {quest = quest, file = zone}
		if quest.variants then
			shared_count = shared_count + 1
			eq(quest.variants[1].zone, zone, quest.id .. ": lives in its first variant's file")
			local seen = {}
			for _, variant in ipairs(quest.variants) do
				check(START[variant.zone] and not seen[variant.zone], quest.id .. ": one variant per start zone")
				seen[variant.zone] = true
				local giver = variant.givers and variant.givers[1]
				local race = RACE[variant.zone]
				check(#variant.givers == 1 and (giver == "r14_" .. race .. "_elder" or
					giver == "r20_" .. race .. "_start_cook"), quest.id .. ": given by its zone's elder or cook")
				table.insert(offered[variant.zone], quest)
			end
		else
			local_count = local_count + 1
			table.insert(offered[zone], quest)
		end
	end
end
eq(shared_count, 12, "twelve shared quests")
eq(local_count, 18, "18 local quests (the finale and the departure per zone, the hunts no other zone shares, Dawnmere's errand)")
for _, row in ipairs(ZONES) do
	local want = row[1] == "elandor_dawnmere_fields" and 12 or 13
	eq(#offered[row[1]], want, row[1] .. ": quests offered")
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
local finales = {}
for id, entry in pairs(by_id) do
	local quest = entry.quest
	check(not quest.story, id .. ": free play, no story quest")
	local requires = quest.requires or {}
	if id:match("_departure$") then
		eq(#requires, 1, id .. ": follows one quest")
		local finale = requires[1] and by_id[requires[1]]
		check(finale and finale.file == entry.file, id .. ": follows its own zone's quest")
		if finale then finales[entry.file] = finale.quest end
	else
		eq(#requires, 0, id .. ": requires nothing but a level")
		-- Only the finale has a follow-up among the start files.
		local start_followers = 0
		for _, follower in ipairs(followers[id] or {}) do
			if by_id[follower] then start_followers = start_followers + 1 end
		end
		check(start_followers <= 1, id .. ": at most one follow-up")
	end
end
for _, row in ipairs(ZONES) do check(finales[row[1]] ~= nil, row[1] .. ": the departure follows the finale") end

------------------------------------------------------------------------------
-- C. The boar and rat quests at once, counts by spawn phase.
------------------------------------------------------------------------------
local recipes = {}
local function kind(zone, id)
	recipes[zone] = recipes[zone] or read_json("mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json")
	for _, belt in ipairs(recipes[zone].recipe.belts) do
		for _, unit in pairs(belt.kinds) do
			if unit.id == id then return unit end
		end
	end
end
local function roster_has(list, role)
	for _, row in ipairs(type(list) == "table" and list or {}) do
		if row.role == role then return true end
	end
	return false
end
local function variant_area(quest, variant, index)
	local own = variant.objectives and variant.objectives[index] and variant.objectives[index].area
	local area = own or quest.objectives[index].area
	return area:match("^[^/]+/(.+)$") or area
end
local boars, rats = by_id.start_boars and by_id.start_boars.quest, by_id.start_rats and by_id.start_rats.quest
check(boars and rats, "the shared boar and rat quests exist")
if boars and rats then
	eq(boars.min_level, 1, "the boars are offered at level 1")
	eq(rats.min_level, 1, "the rats are offered at level 1, with the boars")
	eq(#boars.variants, 6, "the boars in every start zone")
	eq(#rats.variants, 6, "the rats in every start zone")
	local share = rats.objectives[1].count / boars.objectives[1].count
	check(share >= 0.2 and share <= 0.5, ("the rats ask about a third of the boars (%d of %d)")
		:format(rats.objectives[1].count, boars.objectives[1].count))
	for _, variant in ipairs(boars.variants) do
		local unit = kind(variant.zone, variant_area(boars, variant, 1))
		check(unit and roster_has(unit.day, "small_boar"), variant.zone .. ": the boars spawn by day there")
	end
	for _, variant in ipairs(rats.variants) do
		local unit = kind(variant.zone, variant_area(rats, variant, 1))
		check(unit and roster_has(unit.night, "large_rat") and not roster_has(unit.day, "large_rat"),
			variant.zone .. ": the rats spawn only at night there")
	end
end

------------------------------------------------------------------------------
-- D. No reward is a requested item.
------------------------------------------------------------------------------
local TOOLS = {["grug_materials:axe_wood"] = true, ["grug_materials:pick_wood"] = true,
	["grug_materials:axe_stone"] = true, ["grug_materials:pick_stone"] = true}
for id, entry in pairs(by_id) do
	local quest, rewarded = entry.quest, {}
	for _, row in ipairs(quest.rewards.items or {}) do rewarded[#rewarded + 1] = row.item end
	for _, row in ipairs(quest.rewards.choices or {}) do rewarded[#rewarded + 1] = row.item end
	for _, objective in ipairs(quest.objectives) do
		if objective.type == "item" then
			check(not TOOLS[objective.item or ""], id .. ": asks for no starter tool")
			for _, item in ipairs(rewarded) do
				check(item ~= objective.item and not (objective.group and in_group(item, objective.group)),
					id .. ": the reward " .. item .. " is not what it asks for")
			end
		end
	end
end

------------------------------------------------------------------------------
-- E. The reward pattern per zone.
------------------------------------------------------------------------------
local HEALING, MANA = "grug_alchemy:potion_healing_t1", "grug_alchemy:potion_mana_t1"
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
		local ok, reason = grug_items.check_affixes(choice.item, choice.affixes or {})
		check(ok, label .. ": enchants in the pool: " .. tostring(reason))
		local stack = ok and grug_items.make_stack(choice.item, quest.level, choice.affixes)
		if stack then
			eq(stack:get_meta():get_int("grug_ilvl"), quest.level, label .. ": item level = reward level")
			eq(#grug_items.get_affixes(stack), #choice.affixes, label .. ": its enchants")
			eq(stack:get_meta():get_int("grug_quality"), 1 + #choice.affixes, label .. ": its quality")
		end
	end
end
local table_rows = {}
for _, row in ipairs(ZONES) do
	local zone = row[1]
	local potions, armor, weapons = {}, {}, {}
	for _, quest in ipairs(offered[zone]) do
		local choices = quest.rewards.choices
		if choices then
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
		check(p.level <= 3, zone .. ": the potion choice is early (" .. p.id .. ")")
		eq(#p.rewards.choices, 2, zone .. ": two potion entries")
		local set = {}
		for _, choice in ipairs(p.rewards.choices) do set[choice.item .. " " .. (choice.count or 1)] = true end
		check(set[HEALING .. " 2"] and set[MANA .. " 2"], zone .. ": 2 Healing Potion I or 2 Mana Potion I")
	end
	eq(#armor, 2, zone .. ": two armor choices with one enchant")
	table.sort(armor, function(a, b) return a.level < b.level end)
	if #armor == 2 then
		eq(armor[1].level, 5, zone .. ": the first armor choice at level 5")
		check(armor[2].level == 7 or armor[2].level == 8, zone .. ": the second at level 7 or 8")
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
			end
			check(classes[1] and classes[2] and classes[3], quest.id .. ": cloth, leather and metal")
			slots[index] = slot
			stacks_ok(quest.id, quest)
			table_rows[#table_rows + 1] = ("%s %s L%d %s"):format(zone, quest.id, quest.level, tostring(slot))
		end
		check(slots[1] and slots[1] ~= slots[2], zone .. ": the two armor choices are two slots")
	end
	eq(#weapons, 1, zone .. ": one weapon choice")
	local w = weapons[1]
	if w then
		check(w.level == 9 or w.level == 10, zone .. ": the weapon choice at level 9 or 10")
		eq(w.id, finales[zone] and finales[zone].id, zone .. ": the weapon is the finale's")
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

------------------------------------------------------------------------------
-- F. The departures and their level-11 dependants.
------------------------------------------------------------------------------
local dependants = 0
for _, row in ipairs(ZONES) do
	local town = row[1]:match("^%a+_(%a+)")
	local id = town .. "_departure"
	local entry = by_id[id]
	check(entry ~= nil, id .. ": the departure id stays")
	if entry then
		local objective = entry.quest.objectives[1]
		check(#entry.quest.objectives == 1 and objective.type == "talk" and objective.npc == entry.quest.turnin,
			id .. ": a travel quest to the next zone's giver")
		for _, follower in ipairs(followers[id] or {}) do
			check(not by_id[follower], id .. ": followed by a level-11 quest only (" .. follower .. ")")
			dependants = dependants + 1
		end
	end
end
eq(dependants, 10, "the ten level-11 quests that require a departure")

if failures > 0 then
	error(("R57 STARTQUESTS PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R57 STARTQUESTS PORTABLE PASS checks=%d"):format(checks))
