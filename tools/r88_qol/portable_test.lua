-- Round 88 lane QOL portable test (docs/planning/round88-plan.md §2.1-§2.4,
-- §3 "Prepared mixtures"). Loads the REAL grug_jobs registry.lua and
-- state.lua with init.lua's level hook, grug_map settlement_icons.lua,
-- grug_core movement.lua and grug_alchemy effects.lua under small stubs, and
-- checks:
--   P  professions (ruling 4): a saturated profession advances on the
--      level-up and at the join (grug_xp's hook, old_level nil), with the
--      message, the tier sound once and the next tier's Basic unlock; one
--      tier per saturation (the next count starts at 0), every saturated
--      profession at once, nothing for an unsaturated, unlearned or T6 one
--      or below the band; a craft that saturates advances at once where the
--      band allows it, otherwise names the level;
--   M  the map (ruling 1): no PvP layer, fortresses, war camps and the camps
--      under construction under Places, a war camp's tooltip word names the
--      mining camp, the minimap asks no pvp provider;
--   S  the Swiftness Draught (ruling 3): +30 % for 5 s through the real
--      aggregator, with Sprint clamped at 1.5; the item and status texts;
--   C  Sprint's cooldown 180 s;
--   X  the mixtures (§3): aliases of the glass bottle, no registration.
--
-- Usage (repo root): luajit tools/r88_qol/portable_test.lua [REPO]

local repo = arg[1] or "."
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
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- ---------------------------------------------------------------------------
-- Stubs shared by the loaded files.
-- ---------------------------------------------------------------------------
local chat, sounds, unlocks, refreshes, hooks = {}, {}, {}, 0, {}
local now = 0
_G.core = {
	registered_items = {},
	get_item_group = function() return 0 end,
	get_all_craft_recipes = function() return nil end,
	chat_send_player = function(name, text)
		chat[name] = chat[name] or {}
		chat[name][#chat[name] + 1] = text
	end,
	log = function() end,
	is_player = function(player) return type(player) == "table" and player.is_player ~= nil end,
	after = function() end,
	get_us_time = function() return now * 1e6 end,
	get_player_by_name = function() return nil end,
	register_on_mods_loaded = function() end,
	register_on_dieplayer = function() end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
	register_globalstep = function() end,
}
local levels = {}
_G.grug_xp = {
	get_level = function(player) return levels[player:get_player_name()] or 1 end,
	register_on_level_change = function(fn) hooks[#hooks + 1] = fn end,
}
_G.grug_sounds = {play = function(name, player)
	sounds[#sounds + 1] = name .. "@" .. player:get_player_name()
end}
_G.grug_inventory = {refresh = function() end}
_G.grug_core = {mono_time = function() return now end}

_G.grug_jobs = {}
dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
local J = grug_jobs
J.unlock_basic_tiers = function(player, profession, from, to, quiet)
	unlocks[#unlocks + 1] = ("%s:%s:%d-%d%s"):format(player:get_player_name(), profession,
		from, to, quiet and ":quiet" or "")
	return 1
end
J.refresh_crafting_page = function() refreshes = refreshes + 1 end
-- init.lua's level hook as it ships (the rest of init.lua loads the whole
-- mod): from its registration to the end of the file.
do
	local source = read("mods/PLAYER/grug_jobs/init.lua")
	local start = source:find("grug_xp.register_on_level_change(", 1, true)
	check(start ~= nil, "P init.lua registers a level hook")
	if start then assert(loadstring(source:sub(start), "init.lua hook"))() end
end
eq(#hooks, 1, "P one level hook")
local function level_hook(player, old_level, new_level)
	levels[player:get_player_name()] = new_level
	for _, fn in ipairs(hooks) do fn(player, old_level, new_level) end
end

local function new_player(name, level)
	local store = {}
	local meta = {}
	function meta:get_string(key) return store[key] or "" end
	function meta:set_string(key, value) store[key] = value end
	function meta:get_int(key) return tonumber(store[key]) or 0 end
	function meta:set_int(key, value) store[key] = value end
	local physics = {speed = 1, jump = 1}
	local player = {store = store, physics = physics}
	function player.get_meta() return meta end
	function player.get_player_name() return name end
	function player.is_player() return true end
	function player.get_hp() return 20 end
	function player.set_physics_override(_, override)
		for key, value in pairs(override) do physics[key] = value end
	end
	function player.get_physics_override() return physics end
	levels[name] = level
	return player
end
local function last_chat(name) local list = chat[name] or {} return list[#list] end
local function count_sounds(entry)
	local n = 0
	for _, value in ipairs(sounds) do if value == entry then n = n + 1 end end
	return n
end

-- ---------------------------------------------------------------------------
-- P. Professions advance on the level-up and at the join.
-- ---------------------------------------------------------------------------
do
	-- Level change: Cooking saturated at T1, held by level 10.
	local cook = new_player("cook", 10)
	J.learn(cook, "cooking", true)
	cook.store["grug_jobs:crafts:cooking"] = 10
	level_hook(cook, nil, 10)
	eq(J.profession_level(cook, "cooking"), 1, "P level 10 (join): T1 stays, the band holds it")
	eq(count_sounds("profession_tier@cook"), 0, "P ...no tier sound")
	unlocks, refreshes = {}, 0
	level_hook(cook, 10, 11)
	eq(J.profession_level(cook, "cooking"), 2, "P level 11: Cooking advances without a craft")
	eq(J.crafts_in_tier(cook, "cooking"), 0, "P ...the T2 count starts at 0")
	eq(last_chat("cook"), "Cooking advanced to tier 2.", "P ...the craft advance's message")
	eq(count_sounds("profession_tier@cook"), 1, "P ...the tier sound")
	eq(table.concat(unlocks, ","), "cook:cooking:2-2", "P ...the T2 Basic recipes, not quiet")
	eq(refreshes, 1, "P ...an open Crafting tab resent")
	level_hook(cook, 11, 12)
	eq(J.profession_level(cook, "cooking"), 2, "P level 12: nothing more (T2 not saturated)")
	eq(count_sounds("profession_tier@cook"), 1, "P ...no further sound")

	-- Join: a character saturated before 0.88.0 (or offline at its level-up),
	-- two professions at once, one tier each although the band allows more.
	local smith = new_player("smith", 35)
	J.learn(smith, "weaponsmith", true)
	J.learn(smith, "goldsmith", true)
	J.learn(smith, "alchemist", true)
	smith.store["grug_jobs:level:weaponsmith"] = 2
	smith.store["grug_jobs:crafts:weaponsmith"] = 15
	smith.store["grug_jobs:crafts:alchemist"] = 10
	smith.store["grug_jobs:crafts:goldsmith"] = 9
	unlocks, refreshes = {}, 0
	level_hook(smith, nil, 35)
	eq(J.profession_level(smith, "weaponsmith"), 3, "P join: the saturated Weaponsmith T2 -> T3")
	eq(J.profession_level(smith, "alchemist"), 2, "P join: the saturated Alchemy T1 -> T2")
	eq(J.profession_level(smith, "goldsmith"), 1, "P join: 9/10 Goldsmith stays")
	eq(J.crafts_in_tier(smith, "goldsmith"), 9, "P ...its count kept")
	eq(count_sounds("profession_tier@smith"), 1, "P join: the tier sound once for both")
	eq(table.concat(unlocks, ","), "smith:alchemist:2-2,smith:weaponsmith:3-3",
		"P join: each one's next Basic tier (secondaries first, as the overview)")
	eq(#chat.smith, 2, "P join: one message per advance")
	level_hook(smith, 35, 36)
	eq(J.profession_level(smith, "weaponsmith"), 3, "P one tier per saturation: T3 starts at 0")

	-- Nothing: unlearned (stale meta), T6, below the band.
	local other = new_player("other", 60)
	other.store["grug_jobs:level:tailor"] = 2
	other.store["grug_jobs:crafts:tailor"] = 99
	J.learn(other, "armorsmith", true)
	other.store["grug_jobs:level:armorsmith"] = 6
	other.store["grug_jobs:crafts:armorsmith"] = 99
	level_hook(other, nil, 60)
	eq(J.has(other, "tailor"), false, "P an unlearned profession stays unlearned")
	eq(J.profession_level(other, "armorsmith"), 6, "P T6 stays T6")
	eq(count_sounds("profession_tier@other"), 0, "P ...nothing advanced")
	eq(J.advance_professions(other), 0, "P advance_professions counts none")

	-- The craft path: saturating where the band allows advances at once;
	-- below the band the message names the level.
	local crafter = new_player("crafter", 15)
	J.learn(crafter, "cooking", true)
	crafter.store["grug_jobs:crafts:cooking"] = 9
	local advanced, level = J.record_craft(crafter, "cooking", 1, 1)
	check(advanced and level == 2, "P a saturating craft at level 15 advances at once")
	local capped = new_player("capped", 5)
	J.learn(capped, "cooking", true)
	advanced = J.record_craft(capped, "cooking", 1, 12)
	eq(advanced, false, "P a saturating job at level 5 does not advance")
	eq(last_chat("capped"), "Cooking tier progress is complete; tier 2 comes at character level 11.",
		"P ...the message names the level, no further craft")
	level_hook(capped, 5, 11)
	eq(J.profession_level(capped, "cooking"), 2, "P ...and the level-up advances it")
	local overview = read("mods/PLAYER/grug_jobs/overview.lua")
	check(overview:find('"Capped by your level: tier %d comes at level %d."', 1, true) ~= nil and
		not overview:find("once more", 1, true), "P the cap note names the level")
end

-- ---------------------------------------------------------------------------
-- M. The map: the PvP layer's places under Places.
-- ---------------------------------------------------------------------------
do
	local icons = dofile(repo .. "/mods/PLAYER/grug_map/settlement_icons.lua")
	for _, slot in ipairs({"pvp_fortress", "pvp_accord_low", "pvp_throng_high", "camp_construction"}) do
		eq(icons.layer(slot), "pois", "M " .. slot .. " under Places")
	end
	for kind, layer in pairs(icons.LAYER) do
		check(layer ~= "pvp", "M no kind on a PvP layer (" .. kind .. ")")
	end
	eq(icons.poi_word("pvp_accord_low"), "War camp and mining camp", "M a war camp is a mining camp too")
	eq(icons.poi_word("pvp_throng_high"), "War camp and mining camp", "M ...both factions, both bands")
	eq(icons.poi_word("pvp_fortress"), nil, "M a fortress keeps its name alone")
	eq(icons.poi_word("camp_construction"), nil, "M a camp under construction keeps its name alone")
	eq(icons.poi_word("mining_camp"), "Mining camp", "M a guild mining camp unchanged")
	eq(icons.marker("pvp_accord_low"), "war_camp_accord", "M the war camp's icon unchanged")
	local layers = read("mods/PLAYER/grug_map/layers.lua")
	local list = layers:match("L%.LIST = (%b{})")
	local ids = {}
	for id in (list or ""):gmatch('id = "(%a+)"') do ids[#ids + 1] = id end
	eq(table.concat(ids, ","), "quests,bosses,trainers,towns,pois,zones,none",
		"M the layer buttons without PvP (a stale session value falls back: BY_ID has no pvp)")
	check(not layers:find("rows.pvp", 1, true) and layers:find("rows.poi[#rows.poi + 1] = {id = breach.id",
		1, true) ~= nil, "M the arena is a Places row")
	local minimap = read("mods/PLAYER/grug_map/minimap.lua")
	local providers = minimap:match("local PROVIDERS = (%b{})") or ""
	check(providers ~= "" and not providers:find("pvp", 1, true), "M the minimap asks no pvp provider")
end

-- ---------------------------------------------------------------------------
-- S. The Swiftness Draught through the real aggregator.
-- ---------------------------------------------------------------------------
do
	local statuses = {}
	grug_core.set_status = function(_, name, def) statuses[name] = def end
	grug_core.feed = function() end
	grug_core.can_use_item_level = function() return true end
	dofile(repo .. "/mods/CORE/grug_core/movement.lua")
	_G.grug_traders = {potion_cooldown_left = function() return 0 end,
		start_potion_cooldown = function() end}
	_G.grug_alchemy = {}
	dofile(repo .. "/mods/ITEMS/grug_alchemy/effects.lua")
	local runner = new_player("runner", 20)
	local stack = {take_item = function() end}
	grug_alchemy.utility_use("swiftness", 5)(stack, runner)
	local state = grug_core.get_move_state(runner)
	check(math.abs(state.speed - 1.3) < 1e-9, "S the draught: +30 % (" .. state.speed .. ")")
	check(math.abs(runner.physics.speed - 1.3) < 1e-9, "S ...written to the physics override")
	eq(statuses.alchemy_swiftness and statuses.alchemy_swiftness.duration, 5, "S ...for 5 s")
	grug_core.set_move_modifier(runner, "scout_sprint", {speed = 0.50}, 10)
	eq(grug_core.get_move_state(runner).speed, 1.5, "S with Sprint: 1 + 0.5 + 0.3 clamped at 1.5")
	now = now + 5
	eq(grug_core.get_move_state(runner).speed, 1.5, "S after 5 s: Sprint alone, 1.5")
	now = now + 5
	eq(grug_core.get_move_state(runner).speed, 1, "S after 10 s: the base")
	local recipes = read("mods/ITEMS/grug_alchemy/recipes.lua")
	check(recipes:find('duration = 5, text = "+30% movement speed for 5 seconds"', 1, true) ~= nil,
		"S the item text")
	check(read("mods/CORE/grug_core/status_icons.lua"):find(
		'alchemy_swiftness = def("buff", "Swiftness Draught", "+30% movement speed"', 1, true) ~= nil,
		"S the status icon's text")
end

-- ---------------------------------------------------------------------------
-- C. Sprint's cooldown; X. the mixtures.
-- ---------------------------------------------------------------------------
do
	local scout = read("mods/PLAYER/grug_abilities/scout.lua")
	eq(tonumber(scout:match('id = "sprint".-cooldown = (%d+)')), 180, "C Sprint's cooldown")
	local recipes = read("mods/ITEMS/grug_alchemy/recipes.lua")
	check(recipes:find('core.register_alias("grug_alchemy:mixture_" .. catalog[index].id, VIAL)',
		1, true) ~= nil and recipes:find('local VIAL = "vessels:glass_bottle"', 1, true) ~= nil,
		"X every mixture id is an alias of the glass bottle")
	check(not recipes:find("Mixture\\n", 1, true) and not recipes:find("grug_potion_mixture", 1, true),
		"X no mixture item is registered")
end

print(("R88 QOL PORTABLE %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
	checks, failures))
assert(failures == 0, "R88 QOL portable test failed")
