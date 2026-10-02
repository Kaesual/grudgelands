-- Round 28 Lane B4 portable test (quest system; rulings 29, 39-42, the per-zone
-- quest files). Loads the REAL grug_quests files under a minimal `core` stub
-- and checks:
--   1. the fixture files (fixture/grug_quests): dependency-order loading,
--      roles to entities, areas, groups, quest drops, repeatables, a front
--      file and a new giver at a free quest socket;
--   2. play through a player stand-in: every objective kind, area credit by
--      the mob's tag, leader kills, the compact HUD line, travel credit on
--      accept ("Travel to"), quest drops per eligible participant, repeatable
--      cooldown and labels, weight rewards;
--   3. load-time validation: one designer mistake per case, each refused with
--      a message naming the file and the quest.
--
-- The shipped quest files are checked by tools/r28_q0/portable_test.lua
-- section 5 (the real loader over the shipped recipes, catalogue, item
-- registry and settlement places), tools/r28_regions/quest_targets.py (every
-- target on every seed) and the engine probe's boot (run.sh).
--
-- Usage (repo root): luajit tools/r28_b4_quests/portable_test.lua
local json = dofile("tools/r28_b4_quests/json.lua")
local FIXTURE = "tools/r28_b4_quests/fixture"

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

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local MAX_STACK = 99
function ItemStack(item)
	local name, count = "", 0
	if type(item) == "table" and item.get_name then
		name, count = item:get_name(), item:get_count()
	elseif type(item) == "string" then
		local n, c = item:match("^(%S*)%s*(%d*)")
		name, count = n, tonumber(c) or (n == "" and 0 or 1)
	end
	local stack = {}
	function stack:get_name() return count > 0 and name or "" end
	function stack:get_count() return name ~= "" and count or 0 end
	function stack:is_empty() return name == "" or count <= 0 end
	function stack:take_item(n)
		n = math.min(n or 1, count)
		count = count - n
		if count == 0 then name = "" end
		return ItemStack(name .. " " .. n)
	end
	function stack:add_item(other)
		other = ItemStack(other)
		if other:is_empty() then return other end
		if self:is_empty() then name, count = other:get_name(), 0 end
		if name ~= other:get_name() then return other end
		local room = MAX_STACK - count
		local move = math.min(room, other:get_count())
		count = count + move
		return ItemStack(other:get_name() .. " " .. (other:get_count() - move))
	end
	function stack:equals(other)
		return self:get_name() == other:get_name() and self:get_count() == other:get_count()
	end
	function stack:to_string() return self:is_empty() and "" or (name .. " " .. count) end
	function stack:get_description() return name end
	return stack
end

local mod_paths = {}
local current_mod = "grug_quests"
local dropped, fed_items, fed_lines, shown = {}, {}, {}, {}
local serial = {}
local players = {}
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	get_us_time = function() return 0 end,
	get_modpath = function(name) return mod_paths[name] end,
	get_current_modname = function() return current_mod end,
	get_dir_list = function(path)
		local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
		local out = {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = function(value) serial[#serial + 1] = deep_copy(value); return tostring(#serial) end,
	deserialize = function(text) return deep_copy(serial[tonumber(text)]) end,
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_player_by_name = function(name) return players[name] end,
	add_item = function(pos, stack) dropped[#dropped + 1] = ItemStack(stack):to_string() end,
	formspec_escape = function(text) return text end,
	show_formspec = function(_, _, form) shown[#shown + 1] = form end,
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

------------------------------------------------------------------------------
-- Game surface.
------------------------------------------------------------------------------
local ESC = string.char(27)
grug_core = {register_tag_visibility = function() end,
	hud_layout = {side_text_width = function() return 400 end, QUEST_WRAP = 400,
		anchors = {quest_list = {}}},
	feed_item = function(player, stack, count)
		fed_items[#fed_items + 1] = player:get_player_name() .. " " .. ItemStack(stack):get_name() .. " " .. count
	end,
	feed = function(_, kind, text) fed_lines[#fed_lines + 1] = kind .. ": " .. text end}
dofile("mods/CORE/grug_core/item_names.lua")
local level_of = {}
local granted_xp, quest_reward_calls = {}, {}
grug_xp = {
	get_level = function(player) return level_of[player:get_player_name()] or 1 end,
	quest_reward = function(level, weight)
		quest_reward_calls[#quest_reward_calls + 1] = level .. "x" .. weight
		return math.floor(weight * (25 + 5 * level) + 0.5)
	end,
	add_xp = function(player, amount, source)
		granted_xp[#granted_xp + 1] = player:get_player_name() .. " " .. amount .. " " .. source
	end,
}
local purse = {}
grug_money = {MAX = 1000000, format = function(copper) return copper .. " copper" end,
	get = function(player) return purse[player:get_player_name()] or 0 end,
	add = function(player, copper) purse[player:get_player_name()] = (purse[player:get_player_name()] or 0) + copper end}
grug_factions = {get_faction = function() return "accord" end, same_faction = function() return false end}
grug_classes = {get_race = function() return "human" end}
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
local zone_at = {}
grug_zones = {id_at = function(x, z) return zone_at[x .. "," .. z] or "elandor_dawnmere_fields" end,
	-- Level bands (Lane Q0's base-mob ranges) of the fixture's recipe zones.
	get = function(zone)
		local band = ({elandor_dawnmere_fields = {1, 10}, front_shattered_line = {41, 50}})[zone]
		return band and {level_min = band[1], level_max = band[2]} or nil
	end}
local pages = {}
sfinv = {register_page = function(name, def) pages[name] = def end,
	make_formspec = function(_, _, content) return content end,
	get_page = function() return "" end, set_page = function() end,
	pages = pages, pages_unordered = {}}

-- grug_mobs seams (S1 spawn regions, B2 participant drop hook) as stubs over the
-- fixture spawn files.
local spawn_files = {}
local function spawns(zone)
	if spawn_files[zone] == nil then
		local handle = io.open(FIXTURE .. "/grug_mobs/data/zones/" .. zone .. ".spawns.json")
		spawn_files[zone] = handle and json.decode(handle:read("*a")) or false
		if handle then handle:close() end
	end
	return spawn_files[zone] or nil
end
local drop_hooks = {}
local DISPOSITION = {small_boar = "neutral", large_rat = "aggressive", confused_bandit = "aggressive",
	confused_bandit_chief = "aggressive", wild_turkey = "critter", boar = "neutral",
	front_ghoul = "aggressive", guard_throng = false, fox = "aggressive"}
grug_mobs = {
	register_on_eligible_kill = function() end,
	register_participant_drop_hook = function(fn) drop_hooks[#drop_hooks + 1] = fn end,
	disposition = function(name)
		local d = DISPOSITION[name:match("^grug_mobs:(.+)$") or name]
		return d or nil
	end,
	-- The spawn_regions seams (Lane S1) over the fixture recipes, parsed by the
	-- real spawn_regions_core.lua: an area is a kind or a camp.
	spawn_regions = (function()
		local regions_core = dofile("mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
		local BANDS = {elandor_dawnmere_fields = {1, 10}, front_shattered_line = {41, 50}}
		local parsed = {}
		local function recipe(zone)
			if parsed[zone] == nil then
				local data = spawns(zone)
				parsed[zone] = data and data.recipe and
					regions_core.parse_recipe(zone, data.recipe, {band = BANDS[zone] or {1, 60}}) or false
			end
			return parsed[zone] or nil
		end
		local seams = {}
		function seams.get_area(zone, id)
			local r = recipe(zone)
			return r and (r.kind_by_id[id] or r.camp_by_id[id]) or nil
		end
		function seams.area_roles(zone, id)
			local unit = seams.get_area(zone, id)
			if not unit then return nil end
			local set = {}
			for role in pairs(unit.roles) do set[role] = true end
			return set
		end
		function seams.zone_area_ids(zone)
			local r, out = recipe(zone), {}
			for _, kind in ipairs(r and r.kinds or {}) do out[#out + 1] = kind.id end
			for _, camp in ipairs(r and r.camps or {}) do out[#out + 1] = camp.id end
			return out
		end
		function seams.leader(role)
			for _, zone in ipairs({"elandor_dawnmere_fields", "front_shattered_line"}) do
				for _, row in ipairs((recipe(zone) or {leaders = {}}).leaders) do
					if row.role == role then return {zone = zone, level = row.level, respawn = row.respawn} end
				end
			end
		end
		return seams
	end)(),
}
for role in pairs(DISPOSITION) do
	core.registered_entities["grug_mobs:" .. role] = {description = role:gsub("_", " "):gsub("(%a)([%w']*)",
		function(a, b) return a:upper() .. b end)}
end
core.registered_entities["grug_mobs:small_boar"].description = ESC .. "(T@grug_mobs)Small Boar" .. ESC .. "E"
for _, item in ipairs({"grug_materials:axe_wood", "grug_materials:pick_wood", "grug_mobs:ledger_page",
		"mobs:meat_raw", "default:cobble"}) do
	core.registered_items[item] = {description = item:match(":(.+)$"):gsub("_", " ")}
end
core.registered_items["grug_materials:axe_wood"].description = "Wood Axe"
core.registered_items["grug_materials:pick_wood"].description = "Wood Pickaxe"
core.registered_items["grug_mobs:ledger_page"].description = "Ledger Page"
core.registered_items["default:tree"] = {description = "Apple Tree", groups = {tree = 1}}
core.registered_items["default:pine_tree"] = {description = "Pine Tree", groups = {tree = 1}}

-- Settlement sockets: every registered NPC's socket, plus Highcourt's free
-- quest socket.
local settlements = {}
local function settlement_registry()
	local by_key, order = {}, {}
	local function add(key, socket, x, z)
		if not by_key[key] then
			by_key[key] = {key = key, race_id = "human", anchor = {x = x or 0, y = 0, z = z or 0}, sockets = {}}
			order[#order + 1] = by_key[key]
		end
		table.insert(by_key[key].sockets, {id = socket, role = "quest", pos = {x = 0, y = 0, z = 0}})
	end
	add("highcourt", "lore_shrine/lore_shrine_quest", 0, -1500)
	for _, npc in pairs(grug_quests.registered_npcs) do add(npc.settlement, npc.socket) end
	zone_at["0,-1500"] = "elandor_highcourt"
	settlements = {by_key = by_key, order = order}
end
grug_core.settlement_socket_settlements = function() return settlements.order end
grug_core.settlement_sockets_at = function(key) return settlements.by_key[key].sockets end

-- Load grug_quests from `root` (its data/zones are the quest files).
local function load_quests(root, mobs_root)
	grug_quests = {}
	mod_paths.grug_quests, mod_paths.grug_mobs = root, mobs_root or root
	drop_hooks = {}
	local base = "mods/PLAYER/grug_quests/"
	for _, file in ipairs({"registry", "state", "labels", "npc", "npcs"}) do dofile(base .. file .. ".lua") end
	settlement_registry()
	for _, file in ipairs({"validate", "loader", "ui", "hud"}) do dofile(base .. file .. ".lua") end
	return grug_quests
end

------------------------------------------------------------------------------
-- 1. The fixture files.
------------------------------------------------------------------------------
local Q = load_quests(FIXTURE .. "/grug_quests", FIXTURE .. "/grug_mobs")
local ok, err = pcall(Q.validate_quest_data)
check(ok, "fixture passes the world checks: " .. tostring(err))
ok, err = pcall(Q.validate_registry)
check(ok, "fixture passes the registry checks: " .. tostring(err))
local hunt2 = Q.registered_quests.fx_hunt_02
has(hunt2.description, "Complete: Crop Thieves", "prerequisite registered first (listed after its dependant)")
eq(Q.registered_quests.fx_hunt_01.objectives[1].mobs[1], "grug_mobs:small_boar", "roles become entity names")
eq(Q.registered_quests.fx_kitchen_bounty.objectives[1].area, "elandor_dawnmere_fields/home_fields_night",
	"a bare area means the file's zone")
eq(Q.registered_quests.fx_tools_02.objectives[1].group, "tree", "group objective without its prefix")
eq(Q.registered_quests.fx_front_01.npc, "r20_human_capital_envoy", "front file quest registered")
eq(Q.registered_quests.fx_front_01.zone, "elandor_highcourt", "front quest belongs to its host zone")
local keeper = Q.registered_npcs.fx_lore_keeper
check(keeper and keeper.settlement == "highcourt" and keeper.socket == "lore_shrine/lore_shrine_quest",
	"new giver bound to the free quest socket of the hub's settlement")
eq(keeper and keeper.title, "Odran Lorekeep", "new giver's name")
eq(keeper and keeper.race, "dwarf", "new giver's race")
eq(Q.npc_by_socket["highcourt/lore_shrine/lore_shrine_quest"], "fx_lore_keeper", "socket index")
eq(#drop_hooks, 1, "quest drops registered on the participant drop hook")

------------------------------------------------------------------------------
-- 2. Play.
------------------------------------------------------------------------------
local function make_player(name, level)
	local meta, lists = {}, {main = {}}
	for i = 1, 8 do lists.main[i] = ItemStack("") end
	local player = {}
	function player:get_player_name() return name end
	function player:is_player() return true end
	function player:get_hp() return 20 end
	function player:get_pos() return {x = 1, y = 2, z = 3} end
	function player:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	local inv = {}
	function inv:get_list(list) return lists[list] end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack); return true end
	function inv:add_item(list, stack)
		local rest = ItemStack(stack)
		for pass = 1, 2 do
			for _, slot in ipairs(lists[list]) do
				if (pass == 1) ~= slot:is_empty() then rest = slot:add_item(rest) end
			end
		end
		return rest
	end
	function player:get_inventory() return inv end
	function player:give(item) return inv:add_item("main", item) end
	function player:count(item)
		local n = 0
		for _, slot in ipairs(lists.main) do if slot:get_name() == item then n = n + slot:get_count() end end
		return n
	end
	players[name] = player
	level_of[name] = level
	return player
end
local function journal_row(player, id)
	for _, row in ipairs(Q.journal(player).quests) do if row.id == id then return row end end
end
local function npc_entity(npc)
	local def = Q.registered_npcs[npc]
	return {_grug_start = def.settlement, _grug_socket = def.socket, object = {
		is_valid = function() return true end, get_pos = function() return {x = 1, y = 2, z = 3} end}}
end
local function dialogue(player, npc, id)
	for index, row in ipairs(Q.npc_quests(player, npc)) do
		if row.id == id then
			shown = {}
			Q.open_npc(player, npc_entity(npc), index)
			return shown[1] or ""
		end
	end
	return ""
end
local function mob(role, area, leader)
	return {name = "grug_mobs:" .. role, _grug_area = area, _grug_leader = leader, object = {}}
end
local AT = {x = 0, y = 0, z = 0}

local ann = make_player("ann", 1)
-- Multi-objective item quest: one compact HUD line, one line per objective.
check(Q.accept(ann, "fx_tools_01"), "accept First Tools")
local row = journal_row(ann, "fx_tools_01")
eq(Q.hud_line(row, 400), "Wood Axe 0/1, Wood Pickaxe 0/1", "compact HUD line (ruling 41)")
local form = dialogue(ann, "r14_human_elder", "fx_tools_01")
has(form, "Bring Wood Axe × 1\nBring Wood Pickaxe × 1", "dialogue: one line per objective")
has(form, "Rewards: " .. (2 * 30) .. " XP", "dialogue shows the weight reward (2 KE at level 1)")
local log = pages["grug_quests:quests"].get(nil, ann, {grug_quest_selected = "fx_tools_01"})
has(log, "Bring Wood Axe: 0/1\nBring Wood Pickaxe: 0/1", "quest log: one line per objective")
ann:give("grug_materials:axe_wood")
eq(Q.hud_line(journal_row(ann, "fx_tools_01"), 400), "Wood Axe 1/1, Wood Pickaxe 0/1", "first item counted")
ann:give("grug_materials:pick_wood")
eq(Q.status(ann, "fx_tools_01"), "ready", "both items held")
check(Q.turn_in(ann, "fx_tools_01"), "turn in First Tools")
eq(ann:count("grug_materials:axe_wood") + ann:count("grug_materials:pick_wood"), 0, "both items taken")
eq(granted_xp[#granted_xp], "ann 60 quest", "weight 2 at level 1 = 2 x M(1)")
eq(quest_reward_calls[#quest_reward_calls], "1x2", "grug_xp.quest_reward(level, weight)")
eq(purse.ann, 5, "copper paid")

-- Group objective: logs of two trees count together, turn-in takes five.
check(Q.accept(ann, "fx_tools_02"), "accept Logs of Any Tree")
ann:give("default:tree 3")
ann:give("default:pine_tree 4")
eq(Q.hud_line(journal_row(ann, "fx_tools_02"), 400), "Return to Elian Reed", "group counts every member")
row = journal_row(ann, "fx_tools_02")
eq(Q.hud_line({objectives = row.objectives}, 400), "5/5 Bring Any Tree", "group objective line")
check(Q.turn_in(ann, "fx_tools_02"), "turn in logs")
eq(ann:count("default:tree") + ann:count("default:pine_tree"), 2, "exactly five logs taken")

-- Kill objective limited to an area: credit by the mob's area tag.
check(Q.accept(ann, "fx_hunt_01"), "accept Crop Thieves")
Q.credit_kill(ann, mob("small_boar", "elandor_dawnmere_fields/fallback"), AT)
eq(journal_row(ann, "fx_hunt_01").objectives[1].count, 0, "a small boar of another area does not count")
Q.credit_kill(ann, mob("large_rat", "elandor_dawnmere_fields/home_fields_day"), AT)
eq(journal_row(ann, "fx_hunt_01").objectives[1].count, 0, "another role in the area does not count")
for _ = 1, 3 do Q.credit_kill(ann, mob("small_boar", "elandor_dawnmere_fields/home_fields_day"), AT) end
eq(journal_row(ann, "fx_hunt_01").objectives[1].count, 3, "small boars of the area count")
eq(Q.hud_line(journal_row(ann, "fx_hunt_01"), 400), "Return to Elian Reed", "ready line")
check(Q.turn_in(ann, "fx_hunt_01"), "turn in Crop Thieves")

-- min_level gates accepting; level sets the reward.
eq(Q.status(ann, "fx_hunt_02"), "locked", "min_level 8 refuses a level-1 player")
level_of.ann = 8
check(Q.accept(ann, "fx_hunt_02"), "accept The Chief at level 8")
Q.credit_kill(ann, mob("confused_bandit_chief", nil, true), AT)
eq(Q.status(ann, "fx_hunt_02"), "ready", "a leader kill counts without an area")
check(Q.turn_in(ann, "fx_hunt_02"), "turn in The Chief")
eq(granted_xp[#granted_xp], "ann " .. (6 * 75) .. " quest", "reward at the quest level (10), not the player's")
eq(fed_items[#fed_items], "ann grug_materials:axe_wood 1", "reward item fed")
eq(ann:count("grug_materials:axe_wood"), 1, "reward item delivered")

-- Travel quest: credited on accept, the destination shows "?" at once.
level_of.ann = 10
check(Q.accept(ann, "fx_travel"), "accept The Road to Highcourt")
row = journal_row(ann, "fx_travel")
check(row.ready and row.travel, "travel quest ready on accept (ruling 39)")
eq(Q.hud_line(row, 400), "Travel to Mariel Waybook", "HUD: Travel to <NPC>")
eq(Q.marker_states(ann).r20_human_capital_envoy, "ready", "destination marker at once")
eq(Q.marker_states(ann).r14_human_elder ~= "ready", true, "giver shows no turn-in")
log = pages["grug_quests:quests"].get(nil, ann, {grug_quest_selected = "fx_travel"})
has(log, "Travel to Mariel Waybook.", "quest log: travel")
has(dialogue(ann, "r20_human_capital_envoy", "fx_travel"), "turnin;Complete", "turn-in at the destination")
check(Q.turn_in(ann, "fx_travel"), "travel turn-in")

-- Quest drops: rolled per eligible participant who has the quest.
local bob, cid = make_player("bob", 10), make_player("cid", 10)
level_of.ann = 10
check(Q.accept(ann, "fx_pantry_01"), "ann accepts the ledger quest")
check(Q.accept(bob, "fx_pantry_01"), "bob accepts the ledger quest")
local random = math.random
local rolls = {}
math.random = function(n) rolls[#rolls + 1] = n; return 1 end
fed_items = {}
drop_hooks[1](mob("confused_bandit", "elandor_dawnmere_fields/border_bandits"), {"ann", "bob", "cid"}, AT)
eq(#rolls, 2, "one roll per participant with the quest (cid has none)")
eq(rolls[1], 2, "roll 1 in chance")
eq(ann:count("grug_mobs:ledger_page") .. "/" .. bob:count("grug_mobs:ledger_page") .. "/" ..
	cid:count("grug_mobs:ledger_page"), "1/1/0", "each eligible participant gets their own page")
eq(#fed_items, 2, "a feed line per page")
rolls = {}
drop_hooks[1](mob("confused_bandit", "elandor_dawnmere_fields/fallback"), {"ann"}, AT)
eq(#rolls, 0, "a bandit of another area drops no page")
drop_hooks[1](mob("small_boar", "elandor_dawnmere_fields/border_bandits"), {"ann"}, AT)
eq(#rolls, 0, "another role drops no page")
math.random = function(n) rolls[#rolls + 1] = n; return 2 end
drop_hooks[1](mob("confused_bandit", "elandor_dawnmere_fields/border_bandits"), {"ann"}, AT)
eq(ann:count("grug_mobs:ledger_page"), 1, "a failed roll gives nothing")
math.random = function(n) rolls[#rolls + 1] = n; return 1 end
drop_hooks[1](mob("confused_bandit", "elandor_dawnmere_fields/border_bandits"), {"ann"}, AT)
eq(ann:count("grug_mobs:ledger_page"), 2, "second page")
rolls = {}
drop_hooks[1](mob("confused_bandit", "elandor_dawnmere_fields/border_bandits"), {"ann"}, AT)
eq(#rolls, 0, "no roll once the player holds what the quest needs")
-- A full inventory: the page drops at the player's feet.
for i = 1, 8 do bob:get_inventory():set_stack("main", i, ItemStack("default:cobble 99")) end
dropped = {}
drop_hooks[1](mob("confused_bandit", "elandor_dawnmere_fields/border_bandits"), {"bob"}, AT)
eq(dropped[1], "grug_mobs:ledger_page 1", "full inventory: dropped at the feet")
math.random = random
check(Q.turn_in(ann, "fx_pantry_01"), "ann turns in the pages")

-- Repeatable: cooldown from turn-in, labels, first completion for prerequisites.
local clock = 1000
Q.clock = function() return clock end
form = dialogue(ann, "r20_human_start_cook", "fx_kitchen_bounty")
has(form, "Rats in the Larder [Repeatable] (available)", "dialogue list labels Repeatable")
has(form, "Repeatable (every 30 min)", "dialogue detail labels the cooldown")
check(Q.accept(ann, "fx_kitchen_bounty"), "accept the bounty")
row = journal_row(ann, "fx_kitchen_bounty")
eq(Q.hud_line(row, 400), "Repeatable: 0/2 Defeat Large Rat", "HUD labels Repeatable")
log = pages["grug_quests:quests"].get(nil, ann, {grug_quest_selected = "fx_kitchen_bounty"})
has(log, "Rats in the Larder [Repeatable]", "quest log list labels Repeatable")
has(log, "Rats in the Larder (Repeatable)", "quest log title labels Repeatable")
for _ = 1, 2 do Q.credit_kill(ann, mob("large_rat", "elandor_dawnmere_fields/home_fields_night"), AT) end
check(Q.turn_in(ann, "fx_kitchen_bounty"), "turn in the bounty")
local status, reason = Q.status(ann, "fx_kitchen_bounty")
eq(status, "locked", "cooldown after turn-in")
eq(reason, "Repeatable again in 30 min.", "cooldown reason")
eq(Q.status(ann, "fx_kitchen_after"), "available", "first completion counts for prerequisites")
clock = clock + 1799
eq(Q.status(ann, "fx_kitchen_bounty"), "locked", "still cooling down")
clock = clock + 1
eq(Q.status(ann, "fx_kitchen_bounty"), "available", "available again after the cooldown")
check(Q.accept(ann, "fx_kitchen_bounty"), "accept the bounty again")
Q.credit_kill(ann, mob("large_rat", "elandor_dawnmere_fields/home_fields_night"), AT)
eq(journal_row(ann, "fx_kitchen_bounty").objectives[1].count, 1, "a repeat starts from zero")
eq(Q.status(ann, "fx_kitchen_after"), "available", "dependant stays available during a repeat")

-- An area-less kill counts the role wherever it falls (there is no zone filter).
check(Q.accept(ann, "fx_boar_hunt"), "accept the area-less hunt")
zone_at["5,5"] = "elandor_goldmead_vale"
Q.credit_kill(ann, mob("boar"), {x = 5, y = 0, z = 5})
eq(journal_row(ann, "fx_boar_hunt").objectives[1].count, 1, "a kill in another zone counts")
Q.credit_kill(ann, mob("boar"), AT)
check(Q.turn_in(ann, "fx_boar_hunt"), "turn in the area-less hunt")
eq(granted_xp[#granted_xp], "ann 30 quest", "weight 1 at level 1 = M(1)")

-- A group objective overlapping an exact-item objective (review case): the
-- readiness shown and the items taken use one allocation, exact items first.
Q.register_quest("fx_overlap_a", {title = "Overlap A", description = "A.", npc = "r14_human_elder",
	objectives = {{type = "item", group = "tree", count = 5}, {type = "item", item = "default:tree", count = 5}},
	rewards = {weight = 1}})
Q.register_quest("fx_overlap_b", {title = "Overlap B", description = "B.", npc = "r14_human_elder",
	objectives = {{type = "item", group = "tree", count = 5}, {type = "item", item = "default:pine_tree", count = 5}},
	rewards = {weight = 1}})
local function overlap(id, first, second)
	local p = make_player("ov_" .. id, 60)
	p:give(first)
	p:give(second)
	check(Q.accept(p, id), "accept " .. id)
	eq(Q.status(p, id), "ready", id .. ": five apple and five pine logs satisfy both objectives")
	check(Q.turn_in(p, id), id .. ": the turn-in takes what progress counted")
	eq(p:count("default:tree") + p:count("default:pine_tree"), 0, id .. ": all ten logs taken")
	local q = make_player("ov2_" .. id, 60)
	q:give(first)
	check(Q.accept(q, id), "accept " .. id .. " with five logs")
	eq(Q.status(q, id), "active", id .. ": five logs do not satisfy both")
	local ok2 = Q.turn_in(q, id)
	eq(ok2, false, id .. ": no turn-in that progress calls incomplete")
	eq(q:count(first:match("^%S+")), 5, id .. ": nothing taken")
end
overlap("fx_overlap_a", "default:tree 5", "default:pine_tree 5")
overlap("fx_overlap_b", "default:pine_tree 5", "default:tree 5")
-- Persisted talk counters never matter: a travel quest is complete from the start.
local tim = make_player("tim", 10)
serial[#serial + 1] = {active = {fx_travel = {}}, completed = {}, tracked = {}, hud = true}
tim:get_meta():set_string("grug_quests:state", tostring(#serial))
eq(Q.status(tim, "fx_travel"), "ready", "travel quest with empty persisted counters is ready")
-- The drop hook ends at once for mobs no quest drop names.
math.random = function() error("no roll expected") end
drop_hooks[1](mob("small_boar", "elandor_dawnmere_fields/home_fields_day"), {"ann", "bob"}, AT)
check(not Q.quest_drop_mobs["grug_mobs:small_boar"] and Q.quest_drop_mobs["grug_mobs:confused_bandit"],
	"quest-drop mob set")
math.random = random

-- The new giver's quest goes through its dialogue.
level_of.ann = 20
has(dialogue(ann, "fx_lore_keeper", "fx_lore_01"), "Stones for the Shrine", "new giver offers its quest")

------------------------------------------------------------------------------
-- 3. Load-time validation.
------------------------------------------------------------------------------
local V = Q.validate
local function read(name)
	local handle = assert(io.open(FIXTURE .. "/grug_quests/data/zones/" .. name))
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end
local base_files = {
	{name = "elandor_dawnmere_fields.quests.json", zone = "elandor_dawnmere_fields", front = false,
		data = read("elandor_dawnmere_fields.quests.json")},
	{name = "elandor_highcourt.quests.json", zone = "elandor_highcourt", front = false,
		data = read("elandor_highcourt.quests.json")},
	{name = "elandor_highcourt.front.quests.json", zone = "elandor_highcourt", front = true,
		data = read("elandor_highcourt.front.quests.json")},
}
local npcs_before = {}
for id, def in pairs(Q.registered_npcs) do if id ~= "fx_lore_keeper" then npcs_before[id] = def end end
local loader_world
do
	-- The production world view over the stub seams (loader.lua's own), via
	-- a reload that keeps it reachable.
	local captured
	local real_world = V.world
	V.world = function(f, w) captured = w; return real_world(f, w) end
	Q.validate_quest_data()
	V.world = real_world
	loader_world = captured
end
check(loader_world ~= nil, "loader world view captured")
eq(#V.structure(deep_copy(base_files), npcs_before), 0, "fixture structure is clean")
eq(#V.world(deep_copy(base_files), loader_world), 0, "fixture world checks are clean")

local function quest_of(files, id)
	for _, file in ipairs(files) do
		for _, quest in ipairs(file.data.quests) do if quest.id == id then return quest, file end end
	end
end
-- Lane S1: a kill objective in a recipe zone whose targets the recipe never
-- spawns is a warning (W-recipe-target), not an error.
do
	local function about(warnings, id)
		local n = 0
		for _, w in ipairs(warnings) do
			if w:find("quest " .. id .. ":", 1, true) and w:find("W-recipe-target", 1, true) then n = n + 1 end
		end
		return n
	end
	-- The fixture's area-less hunt names a base role (boar) in the recipe
	-- zone: exactly the case the warning is for.
	local _, warnings = V.world(deep_copy(base_files), loader_world)
	eq(#warnings, 1, "fixture quests: one recipe-target warning")
	eq(about(warnings, "fx_boar_hunt"), 1, "the base-role hunt is warned about")
	local files = deep_copy(base_files)
	quest_of(files, "fx_hunt_01").objectives[1] = {type = "kill", roles = {"boar"}, count = 3}
	local errors
	errors, warnings = V.world(files, loader_world)
	eq(#errors, 0, "a base role only: no error")
	eq(about(warnings, "fx_hunt_01"), 1, "a base role only: W-recipe-target")
	quest_of(files, "fx_hunt_01").objectives[1].roles = {"boar", "small_boar"}
	_, warnings = V.world(files, loader_world)
	eq(about(warnings, "fx_hunt_01"), 0, "with the zone's sub-type: no warning")
	quest_of(files, "fx_hunt_01").objectives[1].roles = {"confused_bandit_chief"}
	quest_of(files, "fx_hunt_01").level = 9
	_, warnings = V.world(files, loader_world)
	eq(about(warnings, "fx_hunt_01"), 0, "the zone's leader counts as spawned")
	-- A leader of another zone (a front file names the front's leaders from
	-- its host zone): it stands at its own spot, so it counts as spawned too.
	local elsewhere = setmetatable({leader = function(role)
		local row = loader_world.leader(role)
		return row and {zone = "front_shattered_line", level = row.level, respawn = row.respawn}
	end}, {__index = loader_world})
	_, warnings = V.world(files, elsewhere)
	eq(about(warnings, "fx_hunt_01"), 0, "another zone's leader counts as spawned")
end
local cases = {
	{"critter as a kill target", "E-critter-target", "fx_hunt_01", function(f)
		quest_of(f, "fx_hunt_01").objectives[1] = {type = "kill", roles = {"wild_turkey"}, count = 3}
	end},
	{"role not in the area", "E-role-not-in-area", "fx_hunt_01", function(f)
		quest_of(f, "fx_hunt_01").objectives[1].roles = {"large_rat"}
		quest_of(f, "fx_hunt_01").objectives[1].area = "elandor_dawnmere_fields/home_fields_day"
	end},
	{"unknown area", "E-unknown-area", "fx_hunt_01", function(f)
		quest_of(f, "fx_hunt_01").objectives[1].area = "elandor_dawnmere_fields/nowhere"
	end},
	{"level outside the slack", "E-level-fit", "fx_hunt_01", function(f)
		quest_of(f, "fx_hunt_01").level = 7
	end},
	{"zone areas decide the level of an area-less target", "E-level-fit", "fx_boar_hunt", function(f)
		quest_of(f, "fx_boar_hunt").objectives[1] = {type = "kill", roles = {"confused_bandit"}, count = 2}
	end},
	{"leader with an area", "E-leader-area", "fx_hunt_02", function(f)
		quest_of(f, "fx_hunt_02").objectives[1].area = "elandor_dawnmere_fields/border_bandits"
	end},
	{"leader level vs quest level", "E-level-fit", "fx_hunt_02", function(f)
		quest_of(f, "fx_hunt_02").level = 4
	end},
	{"quest drop without its item objective", "E-quest-drop-pair", "fx_pantry_01", function(f)
		quest_of(f, "fx_pantry_01").quest_drops[1].item = "mobs:meat_raw"
	end},
	{"quest drop source is a critter", "E-critter-target", "fx_pantry_01", function(f)
		quest_of(f, "fx_pantry_01").quest_drops[1].roles = {"wild_turkey"}
		quest_of(f, "fx_pantry_01").quest_drops[1].area = nil
	end},
	{"three givers in a hub", "E-givers", "hub dawnmere", function(f)
		table.insert(f[1].data.hubs[1].givers, {npc = "r14_human_scout", lines = {"x"}})
	end},
	{"three lines for a giver", "E-lines", "giver r14_human_elder", function(f)
		f[1].data.hubs[1].givers[1].lines = {"hunt", "tools", "extra"}
	end},
	{"a giver in two hubs", "E-giver-twice", "giver r14_human_elder", function(f)
		table.insert(f[2].data.hubs[1].givers, 1, {npc = "r14_human_elder", lines = {"x"}})
		table.remove(f[2].data.hubs[1].givers, 2)
	end},
	{"line not declared by the giver", "E-line", "fx_tools_01", function(f)
		quest_of(f, "fx_tools_01").line = "pantry"
	end},
	{"giver of another zone", "E-giver-not-hub", "fx_lore_01", function(f)
		quest_of(f, "fx_lore_01").giver = "r14_human_elder"
	end},
	{"host file uses line front", "E-front-line", "fx_lore_01", function(f)
		f[2].data.hubs[1].givers[2].lines = {"lore", "front"}
		quest_of(f, "fx_lore_01").line = "front"
	end},
	{"front file quest on another line", "E-front-line", "fx_front_01", function(f)
		quest_of(f, "fx_front_01").line = "civic"
	end},
	{"front giver without a front line", "E-line", "fx_front_01", function(f)
		f[2].data.hubs[1].givers[1].lines = {"civic"}
	end},
	{"talk with another objective", "E-talk-only", "fx_travel", function(f)
		table.insert(quest_of(f, "fx_travel").objectives, {type = "item", item = "mobs:meat_raw", count = 1})
	end},
	{"travel turn-in elsewhere", "E-talk-turnin", "fx_travel", function(f)
		quest_of(f, "fx_travel").turnin = "r14_human_elder"
	end},
	{"item and group together", "E-objective", "fx_tools_02", function(f)
		quest_of(f, "fx_tools_02").objectives[1].item = "default:tree"
	end},
	{"unknown item group", "E-unknown-group", "fx_tools_02", function(f)
		quest_of(f, "fx_tools_02").objectives[1].group = "group:no_such_group"
	end},
	{"unknown item", "E-unknown-item", "fx_tools_01", function(f)
		quest_of(f, "fx_tools_01").objectives[1].item = "grug_materials:no_such_item"
	end},
	{"unknown prerequisite", "E-unknown-requires", "fx_hunt_02", function(f)
		quest_of(f, "fx_hunt_02").requires = {"fx_missing"}
	end},
	{"prerequisite cycle", "E-cycle", "fx_hunt_01", function(f)
		quest_of(f, "fx_hunt_01").requires = {"fx_travel"}
	end},
	{"repeatable without cooldown", "E-repeatable", "fx_kitchen_bounty", function(f)
		quest_of(f, "fx_kitchen_bounty").repeatable = {cooldown = 0}
	end},
	{"rewards without weight", "E-required", "fx_tools_01", function(f)
		quest_of(f, "fx_tools_01").rewards = {copper = 5}
	end},
	{"duplicate quest id", "E-duplicate", "quest fx_hunt_01: also in", function(f)
		quest_of(f, "fx_lore_01").id = "fx_hunt_01"
	end},
	{"new giver reusing a registered id", "E-new-giver", "giver r20_human_start_cook", function(f)
		f[2].data.hubs[1].givers[2].npc = "r20_human_start_cook"
	end},
	{"zone field differs from the file name", "E-zone-mismatch", "zone", function(f)
		f[1].data.zone = "elandor_goldmead_vale"
	end},
	{"guard as a designed kill role", "E-not-a-mob", "fx_hunt_01", function(f)
		quest_of(f, "fx_hunt_01").objectives[1] = {type = "kill", roles = {"guard_throng"}, count = 1}
	end},
	-- Fields the game does not read are refused (Round 30: the retired
	-- `mobs`, `zone`, fixed `xp` and `faction`/`race` gates among them).
	{"entity names instead of roles", "E-unknown-key", "fx_boar_hunt: objective 1", function(f)
		quest_of(f, "fx_boar_hunt").objectives[1] = {type = "kill", mobs = {"grug_mobs:boar"}, count = 2}
	end},
	{"a zone filter on a kill", "E-unknown-key", "fx_boar_hunt: objective 1", function(f)
		quest_of(f, "fx_boar_hunt").objectives[1].zone = "elandor_dawnmere_fields"
	end},
	{"fixed reward XP", "E-unknown-key", "fx_boar_hunt: rewards", function(f)
		quest_of(f, "fx_boar_hunt").rewards.xp = 50
	end},
	{"a faction gate", "E-unknown-key", "quest fx_boar_hunt", function(f)
		quest_of(f, "fx_boar_hunt").faction = "accord"
	end},
	{"a race gate", "E-unknown-key", "quest fx_boar_hunt", function(f)
		quest_of(f, "fx_boar_hunt").race = "human"
	end},
	{"an unknown quest-drop field", "E-unknown-key", "fx_pantry_01: quest drop 1", function(f)
		quest_of(f, "fx_pantry_01").quest_drops[1].mobs = {"grug_mobs:boar"}
	end},
	{"a kill without roles", "E-objective", "fx_boar_hunt: objective 1", function(f)
		quest_of(f, "fx_boar_hunt").objectives[1].roles = nil
	end},
}
for _, case in ipairs(cases) do
	local name, code, where, mutate = case[1], case[2], case[3], case[4]
	local mutated = deep_copy(base_files)
	mutate(mutated)
	local found = V.structure(mutated, npcs_before)
	if #found == 0 then found = V.world(mutated, loader_world) end
	if code == nil then
		eq(#found, 0, name .. ": accepted (" .. table.concat(found, " | ") .. ")")
	else
		local hit
		for _, message in ipairs(found) do
			if message:find("[" .. code .. "]", 1, true) then hit = message end
		end
		if check(hit ~= nil, name .. ": " .. code .. " expected, got: " .. table.concat(found, " | ")) then
			check(hit:find("zones/", 1, true) == 1 and hit:find(where, 1, true) ~= nil,
				name .. ": message names the file and " .. where .. ": " .. hit)
		end
	end
end
-- A new giver of an unknown race: a logged warning, not an error (as validate.py).
do
	local warnings = {}
	local log_fn = core.log
	core.log = function(level, text) if level == "warning" then warnings[#warnings + 1] = text end end
	local mutated = deep_copy(base_files)
	mutated[2].data.hubs[1].givers[2].new.race = "gnome"
	eq(#V.structure(mutated, npcs_before), 0, "unknown new-giver race is no error")
	core.log = log_fn
	check(warnings[1] and warnings[1]:find("race gnome", 1, true) and warnings[1]:find("W-new-giver", 1, true)
		and warnings[1]:find("zones/elandor_highcourt.quests.json", 1, true), "unknown race logged: " .. tostring(warnings[1]))
end
-- The loader stops the load with every finding listed.
local broken = deep_copy(base_files)
quest_of(broken, "fx_hunt_01").objectives[1] = {type = "kill", roles = {"wild_turkey"}, count = 3}
local raised = select(2, pcall(function()
	local found = V.world(broken, loader_world)
	if #found > 0 then error("[grug_quests] quest data errors:\n  " .. table.concat(found, "\n  "), 0) end
end))
has(raised, "zones/elandor_dawnmere_fields.quests.json: quest fx_hunt_01: objective 1: critter wild_turkey",
	"load error names file, quest and objective")

print(("example messages: %s"):format(raised:match("\n  ([^\n]+)") or ""))
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print("R28 B4 QUESTS PORTABLE PASS checks=" .. checks)
