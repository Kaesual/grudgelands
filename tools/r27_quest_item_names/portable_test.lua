-- Round 27 Lane Q portable test: quest texts show an item's name, never its
-- tooltip. Loads the REAL grug_core helper and the REAL grug_quests files
-- (registry, state, NPC dialogue, every content file, quest log, HUD tracker)
-- under a minimal `core` stub, then renders every registered quest through
-- the real formatting code.
--
-- Every item a quest requires or rewards is registered here with a hostile
-- tooltip-shaped description: translation markup, colour escapes and the stat
-- lines the game's mods append ("Restores 5 HP instantly.", "Damage: 4", ...).
-- The real registered descriptions are audited by the engine probe
-- (tools/r27_quest_item_names/run.sh).
--
-- Usage (repo root): luajit tools/r27_quest_item_names/portable_test.lua [ROOT]
--   ROOT (default ".") is the tree whose mods/ are loaded; the helper file is
--   always this checkout's mods/CORE/grug_core/item_names.lua.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local failed_labels = {}
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if #failed_labels < 40 then failed_labels[#failed_labels + 1] = label end
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local ESC = string.char(27)
-- The engine's English resolution (no translation files): translation markup
-- resolves to its source text, other escapes (colours) are preserved.
local function engine_translate(_, text)
	return (text:gsub(ESC .. "%(T@[^)]*%)", ""):gsub(ESC .. "[EF]", ""))
end
local formspec_escapes = {["\\"] = "\\\\", ["["] = "\\[", ["]"] = "\\]", [";"] = "\\;",
	[","] = "\\,", ["$"] = "\\$"}
local serial, shown = {}, {}
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	get_translated_string = engine_translate,
	formspec_escape = function(text) return (text:gsub("[\\%[%];,$]", formspec_escapes)) end,
	colorize = function(color, text) return text end,
	serialize = function(value) serial[#serial + 1] = deep_copy(value); return tostring(#serial) end,
	deserialize = function(text) return deep_copy(serial[tonumber(text)]) end,
	show_formspec = function(name, formname, form) shown[#shown + 1] = {name = name, formname = formname, form = form} end,
	close_formspec = function() end,
	get_connected_players = function() return {} end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	log = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {distance = function(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end}

-- ItemStack double. get_description mirrors the engine: the whole tooltip.
function ItemStack(item)
	local name, count = tostring(item):match("^(%S*)%s*(%d*)")
	count = tonumber(count) or (name == "" and 0 or 1)
	local stack = {}
	function stack:get_name() return name end
	function stack:get_count() return count end
	function stack:is_empty() return name == "" or count == 0 end
	function stack:get_description()
		local def = core.registered_items[name]
		return def and def.description or name
	end
	return stack
end

------------------------------------------------------------------------------
-- 1. The helper itself.
------------------------------------------------------------------------------
grug_core = {register_tag_visibility = function() end,
	-- grug_quests/npcs.lua: both PvP fortresses are bound, so their quest
	-- givers register (Round 31; the shipped quest files name them).
	settlement_socket_anchor = function(key) return key:match("^pvp_fortress_") and {x = 0, z = 0} or nil end,
	hud_layout = {side_text_width = function() return 38 end},
	settlement_sockets_at = function() return {} end}
dofile("mods/CORE/grug_core/item_names.lua")
local name_of = grug_core.item_name

local STAT_PATTERNS = {"%%", "HP/", "%f[%a]HP%f[%A]", "Regenerat", "Restores", "Damage",
	"Durability", "Requires level", "Usable by", "^%s*Level", "Mana", "%d+ uses", "Grants ",
	"Cannot eat", "Tier ", "Quality"}
local function stat_hit(text)
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		for _, pattern in ipairs(STAT_PATTERNS) do
			if line:find(pattern) then return pattern .. " in " .. ("%q"):format(line) end
		end
	end
	return nil
end
local function one_clean_line(text)
	return type(text) == "string" and text ~= "" and not text:find("\n", 1, true) and
		not text:find(ESC, 1, true) and stat_hit(text) == nil
end

local STATS = "\nRestores 5 HP instantly.\nRegenerates 2% of maximum HP every 5 s for 10 min." ..
	"\n" .. ESC .. "(c@#ffcc00)Damage: 4\nDurability: 131 uses\nUsable by: Warrior, Rogue\nRequires level 4"
core.registered_items["t:meat"] = {description = ESC .. "(T@mobs)Raw Meat" .. ESC .. "E" .. STATS}
core.registered_items["t:whole"] = {description = ESC .. "(T@mobs)Cooked Meat" .. STATS .. ESC .. "E"}
core.registered_items["t:colour"] = {description = ESC .. "(c@#ff0000)Red Pick" .. ESC .. "(c@#ffffff)" .. STATS}
core.registered_items["t:short"] = {short_description = "Stone Pick", description = "Stone Pickaxe" .. STATS}
core.registered_items["t:short_esc"] = {short_description = ESC .. "(T@x)Axe" .. ESC .. "E",
	description = "Long Axe" .. STATS}
core.registered_items["t:blank_short"] = {short_description = "", description = "  Wood Axe  " .. STATS}
core.registered_items["t:args"] = {description = ESC .. "(T@x)" .. ESC .. "F" .. ESC ..
	"(T@x)Oak" .. ESC .. "E" .. ESC .. "E Planks" .. ESC .. "E" .. STATS}
core.registered_items["t:empty"] = {description = ""}
core.registered_items["t:stat_first"] = {description = "\nRestores 5 HP"}
core.registered_aliases["t:alias"] = "t:meat"
local unit = {
	{"t:meat", "Raw Meat"}, {"t:whole", "Cooked Meat"}, {"t:colour", "Red Pick"},
	{"t:short", "Stone Pick"}, {"t:short_esc", "Axe"}, {"t:blank_short", "Wood Axe"},
	{"t:args", "Oak Planks"}, {"t:empty", "t:empty"}, {"t:stat_first", "t:stat_first"},
	{"t:alias", "Raw Meat"}, {"t:unknown", "t:unknown"}, {"t:meat 5", "Raw Meat"},
}
for pass = 1, 2 do
	-- Pass 2: without the engine resolver (the pure-Lua fallback).
	core.get_translated_string = pass == 1 and engine_translate or nil
	for _, row in ipairs(unit) do
		eq(name_of(row[1]), row[2], ("pass %d name of %s"):format(pass, row[1]))
	end
	eq(name_of(ItemStack("t:meat 3")), "Raw Meat", "pass " .. pass .. " ItemStack")
	eq(grug_core.plain_text(ESC .. "(c@#fff)A" .. ESC .. "(b@#000)B" .. ESC), "AB",
		"pass " .. pass .. " colour and stray escapes stripped")
end
core.get_translated_string = engine_translate

------------------------------------------------------------------------------
-- 2. The real quest definitions.
------------------------------------------------------------------------------
local faction, race = "accord", "human"
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
grug_factions = {get_faction = function() return faction end, same_faction = function() return false end,
	display_name = function(id) return "The " .. id end}
-- Round 31: which NPCs serve whom (the real rule on the fake faction table).
dofile("mods/PLAYER/grug_factions/service.lua")
grug_classes = {get_race = function() return race end}
grug_xp = {get_level = function() return 60 end, quest_reward = function(_, weight) return weight end,
	register_on_level_change = function() end}
-- Quest texts fill their placeholders (labels.lua); a stand-in region map
-- names every kind or camp, quest place and clash site (Round 36) by its id
-- and every direction "nearby" (this test reads item names).
grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end,
	-- Round 38: kill objectives select names (labels.lua Q.target_names);
	-- this stand-in map selects none, so labels read the entity.
	names = dofile(ROOT .. "/tools/r38_b1/names_stub.lua").of(ROOT, {}),
	spawn_regions = {leader = function() return nil end,
		get_area = function(_, id) return {name = id, levels_by_role = {}} end,
		zone_area_ids = function() return {} end,
		zone_place = function(zone, id) return {zone = zone, id = id, name = id} end,
		clash_site = function(key)
			return key:match("^r20_anchor_%d+$") and {key = key, zone = "front", name = key} or nil
		end,
		describe = function() return {phrase = "nearby"} end, LEADER_RANGE = 48}}
grug_money = {format = function(copper) return copper .. " copper" end}
grug_zones = {get = function(zone) return {display_name = zone} end}
-- The quest content is the per-zone quest files (Round 28 Lane B4), read by
-- the real loader.
local json = dofile("tools/r28_b4_quests/json.lua")
core.get_modpath = function() return ROOT .. "/mods/PLAYER/grug_quests" end
core.get_current_modname = function() return "grug_quests" end
core.parse_json = function(text) return (json.decode(text)) end
core.get_dir_list = function(path)
	local handle, out = io.popen('ls "' .. path .. '"'), {}
	for line in handle:lines() do out[#out + 1] = line end
	handle:close()
	return out
end
local pages = {}
sfinv = {register_page = function(name, def) pages[name] = def end,
	make_formspec = function(_, _, content) return content end,
	get_page = function() return "" end, pages = pages, pages_unordered = {}}
grug_quests = {}
local Q = grug_quests
for _, file in ipairs({"registry", "state", "labels", "npc", "npcs", "use", "validate", "loader",
		"hud"}) do
	dofile(ROOT .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
-- The quest log is the map window's quest box since Round 44
-- (grug_map/quest_box.lua); this stands in for the old Quests tab's page.
local quest_box = dofile(ROOT .. "/mods/PLAYER/grug_map/quest_box.lua")
pages["grug_quests:quests"] = {get = function(_, p, context)
	return quest_box.content({quest_selected = context.grug_quest_selected}, grug_quests.journal(p),
		{x = 13.4, y = 1.05, w = 7, h = 10.7})
end}


-- No shipped quest rewards items yet; one fixture quest exercises the reward
-- path of the real dialogue and quest log with a food and a tool.
Q.register_npc("fixture_giver", {settlement = "fixture", socket = "quest", title = "Fixture Giver"})
Q.register_quest("zz_fixture_rewards", {title = "Fixture Rewards", description = "Fixture.",
	npc = "fixture_giver", objectives = {{type = "item", item = "grug_materials:pick_stone", count = 1}},
	rewards = {weight = 1, copper = 1, items = {"mobs:meat_raw 3", "grug_materials:axe_wood"}}})

local ids, used_items, item_quests = {}, {}, {}
local function use(item, id)
	if not used_items[item] then used_items[item] = true; item_quests[#item_quests + 1] = item end
end
for id, def in pairs(Q.registered_quests) do
	ids[#ids + 1] = id
	for _, objective in ipairs(def.objectives) do
		if objective.type == "item" and objective.item then use(objective.item, id) end
		for _, mob in ipairs(objective.mobs or {}) do
			core.registered_entities[mob] = core.registered_entities[mob] or {}
		end
	end
	for _, item in ipairs(def.rewards.items) do use(ItemStack(item):get_name(), id) end
end
table.sort(ids)
table.sort(item_quests)

-- Hostile tooltip per quest item; the expected name is the first title-cased
-- line. Shapes rotate: escape around the name only, escape around the whole
-- tooltip, colour-prefixed name, and a short_description.
local expected = {}
for index, item in ipairs(item_quests) do
	local base = (item:match("[^:]+$") or item):gsub("_", " "):gsub("(%a)([%w']*)",
		function(a, b) return a:upper() .. b end)
	local shape = index % 4
	local def
	if shape == 0 then
		def = {description = ESC .. "(T@m)" .. base .. ESC .. "E" .. STATS}
	elseif shape == 1 then
		def = {description = ESC .. "(T@m)" .. base .. STATS .. ESC .. "E"}
	elseif shape == 2 then
		def = {description = ESC .. "(c@#a0a0ff)" .. base .. STATS}
	else
		def = {short_description = base, description = base .. " (long form)" .. STATS}
	end
	core.registered_items[item] = def
	expected[item] = base
end
for _, item in ipairs(item_quests) do
	for pass = 1, 2 do
		core.get_translated_string = pass == 1 and engine_translate or nil
		local got = name_of(item)
		check(one_clean_line(got), "helper one clean line for " .. item .. ": " .. ("%q"):format(got))
		eq(got, expected[item], "helper name for " .. item)
	end
end
core.get_translated_string = engine_translate

------------------------------------------------------------------------------
-- 3. Every quest through the real formatting code.
------------------------------------------------------------------------------
local meta_store, held = {}, {}
local player = {}
function player:get_player_name() return "fixture" end
function player:is_player() return true end
function player:get_hp() return 20 end
function player:get_pos() return {x = 0, y = 0, z = 0} end
function player:get_meta()
	return {get_string = function(_, k) return meta_store[k] or "" end,
		set_string = function(_, k, v) meta_store[k] = v end}
end
function player:get_inventory()
	return {get_list = function(_, list)
		if list ~= "main" then return {} end
		local stacks = {}
		for name, count in pairs(held) do stacks[#stacks + 1] = ItemStack(name .. " " .. count) end
		return stacks
	end, get_stack = function() return ItemStack("") end}
end
local function set_state(state) meta_store["grug_quests:state"] = core.serialize(state) end
local function entity_for(npc)
	local def = Q.registered_npcs[npc]
	return {_grug_start = def.settlement, _grug_socket = def.socket, object = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 0, z = 0} end}}
end
local function unescape(text) return (text:gsub("\\(.)", "%1")) end
-- The payload of the first element starting with `prefix`, up to the next
-- unescaped "]".
local function element(form, prefix, from)
	local start = form:find(prefix, from or 1, true)
	if not start then return nil end
	local i, out = start + #prefix, {}
	while i <= #form do
		local c = form:sub(i, i)
		if c == "\\" then out[#out + 1] = form:sub(i, i + 1); i = i + 2
		elseif c == "]" then break
		else out[#out + 1] = c; i = i + 1 end
	end
	return unescape(table.concat(out)), i
end
local function lines_of(text)
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
	return out
end

local examples, embedded = {}, {}
local function record(kind, text)
	if not examples[kind] then examples[kind] = text end
end
local stats_in_descriptions = 0
for _, id in ipairs(ids) do
	local def = Q.registered_quests[id]
	-- Hand-written quest text: no embedded stats.
	local hit = stat_hit(def.description) or stat_hit(def.title)
	for _, objective in ipairs(def.objectives) do
		hit = hit or (objective.description and stat_hit(objective.description))
	end
	if hit then stats_in_descriptions = stats_in_descriptions + 1; embedded[#embedded + 1] = id .. ": " .. hit end
	check(not hit, "hand-written text free of stats: " .. id .. " " .. tostring(hit))

	-- Quest-offer dialogue (npc.lua), prerequisites met, quest not yet active.
	local completed = {}
	for _, prior in ipairs(def.prerequisites) do completed[prior] = true end
	set_state({active = {}, completed = completed, tracked = {}, hud = true})
	local rows = Q.npc_quests(player, def.npc)
	local selected
	for index, row in ipairs(rows) do if row.id == id then selected = index end end
	if check(selected ~= nil, "offer listed by giver: " .. id) then
		shown = {}
		check(Q.open_npc(player, entity_for(def.npc), selected), "dialogue opens: " .. id)
		local detail = shown[1] and element(shown[1].form, "textarea[7.8,0.9;7.8,6;;;")
		if check(detail ~= nil, "dialogue detail present: " .. id) then
			check(stat_hit(detail) == nil, "dialogue free of stats: " .. id .. " " .. tostring(stat_hit(detail)))
			check(not detail:find(ESC, 1, true), "dialogue free of escapes: " .. id)
			-- Description lines, a blank line, a repeatable's cooldown line, one
			-- line per objective, a blank line, the reward line and one line per
			-- reward item.
			local cooldown = def.repeatable and 1 or 0
			local want = #lines_of(def.description) + 1 + cooldown + #def.objectives + 1 + 1 + #def.rewards.items
			eq(#lines_of(detail), want, "dialogue line count (one line per item): " .. id)
			local detail_lines = lines_of(detail)
			local first = #lines_of(def.description) + 2 + cooldown
			for index, objective in ipairs(def.objectives) do
				local line = detail_lines[first + index - 1] or ""
				if objective.type == "item" and objective.item then
					if not objective.description then
						eq(line, "Bring " .. expected[objective.item] .. " × " .. objective.count,
							"dialogue objective line: " .. id)
					end
					record("dialogue objective", line)
				end
			end
			for index, item in ipairs(def.rewards.items) do
				local stack = ItemStack(item)
				local line = detail_lines[first + #def.objectives + 1 + index] or ""
				eq(line, expected[stack:get_name()] .. " × " .. stack:get_count(), "dialogue reward line: " .. id)
				record("dialogue reward", line)
			end
		end
	end

	-- Quest log (grug_map/quest_box.lua since Round 44) and HUD tracker
	-- (hud.lua), quest active.
	set_state({active = {[id] = {}}, completed = completed, tracked = {id}, hud = true})
	local form = pages["grug_quests:quests"].get(nil, player, {grug_quest_selected = id})
	-- One text field (Round 32): description, an empty line, one line per
	-- objective, an empty line, the reward line.
	local detail_at = form:find("textarea%[[%d.,;]+;;;")
	local detail = detail_at and element(form, ";;;", detail_at)
	if check(detail ~= nil, "quest log text field present: " .. id) then
		local detail_lines = lines_of(detail)
		local count = #detail_lines
		local rewards = detail_lines[count]
		local first = count - 1 - #def.objectives
		eq(detail_lines[count - 1], "", "quest log empty line before the rewards: " .. id)
		eq(detail_lines[first - 1], "", "quest log empty line before the objectives: " .. id)
		check(rewards:sub(1, 9) == "Rewards: ", "quest log reward line last: " .. id)
		for index, objective in ipairs(def.objectives) do
			local line = detail_lines[first + index - 1] or ""
			check(one_clean_line(line), "quest log objective clean: " .. id .. " " .. ("%q"):format(line))
			if objective.type == "item" and objective.item then
				eq(line, ("Bring %s: 0/%d"):format(expected[objective.item], objective.count),
					"quest log objective line: " .. id)
				record("quest log objective", line)
			end
		end
		check(one_clean_line(rewards), "quest log rewards one clean line: " .. id .. " " .. ("%q"):format(rewards))
		if #def.rewards.items > 0 then record("quest log rewards", rewards) end
	end
	-- The HUD's one compact line (quests.md): "0/4 Bring Iron Bar" for one
	-- objective, "Iron Bar 0/4, Coal Lump 0/4" for several, "Repeatable: "
	-- first. Checked where every objective names one exact item.
	local hud_want
	for index, objective in ipairs(def.objectives) do
		if objective.type ~= "item" or not objective.item then hud_want = nil; break end
		local name = expected[objective.item]
		hud_want = #def.objectives == 1 and ("0/%d Bring %s"):format(objective.count, name) or
			(index > 1 and hud_want .. ", " or "") .. ("%s 0/%d"):format(name, objective.count)
	end
	if hud_want and def.repeatable then hud_want = "Repeatable: " .. hud_want end
	local journal = Q.journal(player)
	for _, width in ipairs({38, 400}) do
		local text = Q.hud_text(journal, nil)
		local line = Q.hud_line(journal.quests[1], width)
		check(one_clean_line(line) and one_clean_line(text), "HUD line clean: " .. id .. " " .. ("%q"):format(line))
		if width == 400 and hud_want then
			eq(line, hud_want, "HUD objective line: " .. id)
			record("HUD tracker", line)
		end
	end
end

print(("%d quests, %d quest items/rewards, %d hand-written texts with stats"):format(
	#ids, #item_quests, stats_in_descriptions))
for _, line in ipairs(embedded) do print("EMBEDDED " .. line) end
for _, kind in ipairs({"dialogue objective", "dialogue reward", "quest log objective",
		"quest log rewards", "HUD tracker"}) do
	print(("example %-20s %s"):format(kind .. ":", ("%q"):format(tostring(examples[kind]))))
end
for _, label in ipairs(failed_labels) do print("FAIL " .. label) end
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error(failures .. " failure(s)", 0) end
