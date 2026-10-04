-- Round 33 lane C2 portable test (profession restructure, round33-plan.md
-- §2.7, §2.8). Loads the REAL files under small stubs and checks:
--   A. the roster: six primaries, Cooking and Alchemy secondary; a character
--      learns two primaries plus both secondaries, a third primary is
--      refused, a secondary cannot be unlearned; the Professions tab lists
--      all four inside the page; the crafting page has one fixed book slot
--      per secondary below the primaries, then Basics;
--   B. progression counting (registry.lua + state.lua): an end product
--      counts, a material, a station (`progress = false`) and an automatic
--      finish do not, a station operation does; the usual tier advance;
--   C. the shipped recipe set (tools/r30_p4/recipe_corpus.lua, dumped from
--      the engine): stations, settings, cut gems, bolt bundles, ornament
--      components and every furnace or brewing finish count nothing; potion
--      mixtures, dishes, bags, trinkets and spellbooks count; every
--      profession can still reach its band cap (a counting recipe or an
--      enchant operation at each of T1..T5);
--   D. the storage unpack (cut-gem blocks) passes the registry's collision
--      check, any other universal route to a profession output still fails;
--   E. removed things are absent: no removed id, API or data file in any
--      shipped Lua or JSON file, nothing removed in the recipe corpus, the
--      material registry, the gathering catalog or the WP43 projection.
--
-- Usage (repo root): luajit tools/r33_c2/portable_test.lua [REPO]

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
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
	local file = assert(io.open(repo .. "/" .. path, "r"), "cannot read " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

-- Engine stubs shared by the grug_jobs files.
local items = {}
local engine_recipes = {}
local messages = {}
_G.core = {
	registered_items = items,
	get_item_group = function(name, group)
		local def = items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_all_craft_recipes = function(output) return engine_recipes[output] end,
	chat_send_player = function(_, text) messages[#messages + 1] = text end,
	formspec_escape = function(text)
		return (tostring(text):gsub("[%[%];,\\]", "\\%0"))
	end,
	log = function() end,
	register_on_mods_loaded = function() end,
	register_on_player_receive_fields = function() end,
	register_on_leaveplayer = function() end,
}
local character_level = 5
_G.grug_xp = {get_level = function() return character_level end}
_G.grug_inventory = {refresh = function() end, refresh_character_tab = function() end}
_G.sfinv = {override_page = function() end}

local function load_jobs()
	_G.grug_jobs = {}
	dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
	return grug_jobs
end

local function make_player(name)
	local meta = {}
	local store = {}
	function meta:get_string(key) return store[key] or "" end
	function meta:set_string(key, value) store[key] = value end
	function meta:get_int(key) return tonumber(store[key]) or 0 end
	function meta:set_int(key, value) store[key] = value end
	return {get_meta = function() return meta end,
		get_player_name = function() return name end}
end

-- ---------------------------------------------------------------------------
-- A. Roster, learning, the Professions tab and the book slots.
-- ---------------------------------------------------------------------------
local jobs = load_jobs()
dofile(repo .. "/mods/PLAYER/grug_jobs/character_tab.lua")
dofile(repo .. "/mods/PLAYER/grug_jobs/ui.lua")

eq(#jobs.PRIMARY_PROFESSIONS, 6, "six primaries")
local primaries = table.concat(jobs.PRIMARY_PROFESSIONS, ",")
eq(primaries, "weaponsmith,armorsmith,tailor,leatherworker,woodcarver,goldsmith",
	"the six primaries")
eq(table.concat(jobs.SECONDARY_PROFESSIONS, ","), "cooking,alchemist",
	"Cooking and Alchemy are the secondaries")
eq(jobs.PROFESSIONS.alchemist.class, "secondary", "Alchemy is secondary")
eq(jobs.PROFESSIONS.alchemist.name, "Alchemy", "Alchemy's name")
for key, definition in pairs(jobs.PROFESSIONS) do
	local listed = false
	for _, list in ipairs({jobs.PRIMARY_PROFESSIONS, jobs.SECONDARY_PROFESSIONS}) do
		for _, name in ipairs(list) do
			if name == key then
				listed = true
				check((list == jobs.PRIMARY_PROFESSIONS) == (definition.class == "primary"),
					key .. " is listed under its class")
			end
		end
	end
	check(listed, key .. " is listed")
end

local fresh = make_player("fresh")
local fresh_page = jobs.crafting_page_content(fresh)
check(fresh_page:find("grug_jobs_book_alchemist", 1, true) ~= nil,
	"an Alchemy book slot exists before learning")
check(fresh_page:find("Alchemy — learn at a trainer", 1, true) ~= nil,
	"the empty Alchemy slot says where to learn it")

local crafter = make_player("crafter")
check(jobs.learn(crafter, "weaponsmith"), "first primary")
check(jobs.learn(crafter, "goldsmith"), "second primary")
check(jobs.learn(crafter, "cooking"), "Cooking beside two primaries")
check(jobs.learn(crafter, "alchemist"), "Alchemy beside two primaries and Cooking")
for _, profession in ipairs({"weaponsmith", "goldsmith", "cooking", "alchemist"}) do
	check(jobs.has(crafter, profession), "knows " .. profession)
	eq(jobs.profession_level(crafter, profession), 1, profession .. " starts at tier 1")
end
eq(jobs.primary_at(crafter, 1), "weaponsmith", "slot 1")
eq(jobs.primary_at(crafter, 2), "goldsmith", "slot 2")
check(not jobs.learn(crafter, "tailor"), "a third primary is refused")
check(not jobs.has(crafter, "tailor"), "the refused primary is not known")
check(not jobs.unlearn(crafter, "alchemist"), "Alchemy cannot be unlearned")
check(jobs.has(crafter, "alchemist"), "Alchemy stays known")

local overview = jobs.profession_overview(crafter)
eq(#overview, 4, "four rows on the Professions tab")
eq(overview[3] and overview[3].name, "Cooking", "Cooking after the primaries")
eq(overview[4] and overview[4].name, "Alchemy", "Alchemy last")
local tab = jobs.professions_formspec(overview)
local lowest = 0
for y in tab:gmatch("label%[0%.2,([%d%.]+);") do lowest = math.max(lowest, tonumber(y)) end
check(lowest > 0 and lowest <= 6.4, "the tab's rows end inside the page (" .. lowest .. ")")

local page = jobs.crafting_page_content(crafter)
local slots = {}
for y, field in page:gmatch("image_button%[0%.10,([%d%.]+);0%.82,0%.82;[^;]*;([%w_]+);%]") do
	slots[#slots + 1] = field .. "@" .. y
end
eq(table.concat(slots, " "), "grug_jobs_book_primary_1@0.55 grug_jobs_book_primary_2@1.48 " ..
	"grug_jobs_book_cooking@2.41 grug_jobs_book_alchemist@3.34 grug_jobs_book_general@4.27",
	"book slots: two primaries, Cooking, Alchemy, Basics")
check(page:find("tooltip[grug_jobs_book_alchemist;Alchemy recipe book]", 1, true) ~= nil,
	"the learned Alchemy slot opens its book")

-- ---------------------------------------------------------------------------
-- B. Progression counting.
-- ---------------------------------------------------------------------------
jobs = load_jobs()
for _, name in ipairs({"t:ore", "t:bar", "t:fine", "t:gear", "t:mix", "t:node"}) do
	items[name] = {groups = {}}
end
jobs.register_ingredient_tier("t:ore", 1)
jobs.register_ingredient_tier("t:bar", 1)
local product = jobs.register_recipe({profession = "weaponsmith", tier = 1,
	station = "grid", inputs = {{"t:ore", "t:ore"}}, output = "t:gear", hint = "x"})
local material = jobs.register_recipe({profession = "weaponsmith", tier = 1,
	station = "grid", inputs = {{"t:ore"}}, output = "t:bar", material = true, hint = "x"})
local station = jobs.register_recipe({profession = "weaponsmith", tier = 1,
	station = "grid", inputs = {{"t:ore", "t:ore", "t:ore"}}, output = "t:node",
	progress = false, hint = "x"})
local finish = jobs.register_recipe({profession = "weaponsmith", tier = 1,
	station = "furnace", inputs = {"t:bar"}, output = "t:fine", hint = "x"})
eq(product.progress, true, "an end product counts")
eq(material.progress, false, "a material does not count")
eq(station.progress, false, "a station does not count")
eq(finish.progress, false, "an automatic finish does not count")
check(not pcall(jobs.register_recipe, {profession = "weaponsmith", tier = 1,
	station = "grid", inputs = {{"t:ore", "t:bar"}}, output = "t:mix",
	progress = "yes", hint = "x"}), "a non-boolean progress flag is refused")

local smith = make_player("smith")
jobs.learn(smith, "weaponsmith")
local function crafts() return jobs.crafts_in_tier(smith, "weaponsmith") end
jobs.award_progress(smith, product)
eq(crafts(), 1, "the end product awarded one craft")
jobs.award_progress(smith, material)
jobs.award_progress(smith, station)
jobs.award_progress(smith, finish)
eq(crafts(), 1, "material, station and finish awarded nothing")
local operation = {profession = "weaponsmith", tier = 1, progress = true}
jobs.award_progress(smith, operation)
eq(crafts(), 2, "a station operation awards one craft")
jobs.award_progress(smith, {profession = "weaponsmith", tier = 1})
eq(crafts(), 2, "an unflagged recipe awards nothing")
character_level = 11
for _ = 1, 8 do jobs.award_progress(smith, product) end
eq(jobs.profession_level(smith, "weaponsmith"), 2, "ten counted crafts open tier 2")
character_level = 5
check(read("mods/PLAYER/grug_jobs/station_operations.lua"):find("recipe.progress = true", 1, true),
	"every station operation is flagged as progress")
for _, path in ipairs({"mods/PLAYER/grug_jobs/stations.lua",
		"mods/PLAYER/grug_jobs/workspaces.lua"}) do
	local text = read(path)
	check(text:find("award_progress(player, recipe)", 1, true) ~= nil,
		path .. " awards progress through award_progress")
	check(text:find("record_craft", 1, true) == nil, path .. " never records directly")
end

-- ---------------------------------------------------------------------------
-- C. The shipped recipe set and the band caps.
-- ---------------------------------------------------------------------------
local corpus = dofile(repo .. "/tools/r30_p4/recipe_corpus.lua")
local STATION_OUTPUTS = {["grug_jobs:forge"] = true, ["grug_jobs:tanning_rack"] = true,
	["grug_jobs:tailor_bench"] = true, ["grug_jobs:carving_bench"] = true,
	["grug_jobs:jewellers_bench"] = true, ["grug_brewing:brewing_stand"] = true}
local function intermediate(name)
	return name:find("^grug_artisans:setting_") or name:find("^grug_materials:cut_") or
		name:find("_bolt_bundle$")
end
local function end_product(name)
	return name:find("^grug_alchemy:mixture_") or name:find("^grug_cooking:") or
		name:find("^grug_inventory:bag_") or name:find("^grug_gear:spellbook_") or
		name:find("^grug_gear:[%w_]+_t%d$")
end
local counting = {}
for _, recipe in ipairs(corpus.recipes) do
	local name, label = recipe.output_name, recipe.profession .. " " .. recipe.output_name
	check(type(recipe.progress) == "boolean", label .. " carries its progress flag")
	if STATION_OUTPUTS[name] then
		eq(recipe.progress, false, label .. ": a station does not count")
	elseif recipe.station == "furnace" or recipe.station == "brewing_stand" then
		eq(recipe.progress, false, label .. ": an automatic finish does not count")
	elseif intermediate(name) then
		eq(recipe.progress, false, label .. ": an intermediate does not count")
	elseif end_product(name) then
		eq(recipe.progress, true, label .. ": an end product counts")
	else
		check(false, label .. " is neither a station, an intermediate nor an end product")
	end
	if recipe.progress then
		counting[recipe.profession] = counting[recipe.profession] or {}
		counting[recipe.profession][recipe.tier] = true
	end
end
-- Enchant operations (grug_professions/enchants.lua, grug_artisans/enchants.lua)
-- exist at every tier of enchants.json for the six primaries.
local enchant_tiers = {}
for tier in read("mods/ITEMS/grug_professions/data/enchants.json"):gmatch('"tier":%s*(%d)') do
	enchant_tiers[tonumber(tier)] = true
end
for _, profession in ipairs({"weaponsmith", "armorsmith", "leatherworker", "tailor",
		"woodcarver", "goldsmith"}) do
	counting[profession] = counting[profession] or {}
	for tier in pairs(enchant_tiers) do counting[profession][tier] = true end
end
for profession in pairs(jobs.PROFESSIONS) do
	for tier = 1, 5 do
		check(counting[profession] and counting[profession][tier],
			profession .. " has a counting craft at T" .. tier .. " (band cap reachable)")
	end
end

-- ---------------------------------------------------------------------------
-- D. The cut-gem storage unpack and the collision check.
-- ---------------------------------------------------------------------------
jobs = load_jobs()
for _, name in ipairs({"g:raw", "g:cut", "g:block", "g:other"}) do
	items[name] = {groups = {}}
end
jobs.register_ingredient_tier("g:raw", 1)
jobs.register_ingredient_tier("g:cut", 1)
jobs.register_recipe({profession = "goldsmith", tier = 1, station = "jewellers_bench",
	inputs = {{"g:raw"}}, output = "g:cut", material = true, hint = "x"})
local nine = {}
for index = 1, 9 do nine[index] = "g:cut" end
engine_recipes["g:block"] = {{method = "normal", items = nine, output = "g:block"}}
engine_recipes["g:cut"] = {{method = "normal", items = {"g:block"}, output = "g:cut 9"}}
check(pcall(jobs.validate_recipe_collisions), "a storage unpack is no second route")
engine_recipes["g:cut"][2] = {method = "normal", items = {"g:other"}, output = "g:cut"}
check(not pcall(jobs.validate_recipe_collisions),
	"any other universal route to a profession output still fails")
engine_recipes = {}

-- ---------------------------------------------------------------------------
-- E. Removed things are absent.
-- ---------------------------------------------------------------------------
local CULTURAL = {"sunwax", "runeslate", "moonresin", "red_ochre", "spirit_resin",
	"gravesalt"}
local removed = {"grug_professions:weapon_grip_", "grug_weapon_grip", "grug_reagent",
	"register_reagents", "reagents.json", "grug_apothecary", "apothecary_bonus",
	"warding_draught", "register_drop_hook", "run_drop_hooks", "CULTURAL_MATERIALS",
	"cultural_sources", "cultural_registrations", "r6_cultural_slot",
	"grug_cultural_source", "tool_tier_for_stack", "First Aid", "bandage"}
for _, key in ipairs(CULTURAL) do
	removed[#removed + 1] = "grug_materials:" .. key .. "\""
	removed[#removed + 1] = "grug_gathering:" .. key .. "_source"
end
local pipe = assert(io.popen("cd '" .. repo .. "' && find mods -type f " ..
	"\\( -name '*.lua' -o -name '*.json' \\) | sort"))
local scanned = 0
for path in pipe:lines() do
	scanned = scanned + 1
	local text = read(path)
	for _, needle in ipairs(removed) do
		check(text:find(needle, 1, true) == nil, path .. " names removed " .. needle)
	end
end
pipe:close()
check(scanned > 500, "every shipped Lua and JSON file was scanned (" .. scanned .. ")")
check(io.open(repo .. "/mods/ITEMS/grug_professions/reagents.lua") == nil,
	"the reagent loader is gone")
check(io.open(repo .. "/mods/CORE/grug_core/textures/grug_status_warding_draught.png") == nil,
	"the Warding Draught icon is gone")

for _, recipe in ipairs(corpus.recipes) do
	local names = {recipe.output_name}
	local function collect(value)
		if type(value) == "string" then names[#names + 1] = value
		elseif type(value) == "table" then for _, child in pairs(value) do collect(child) end end
	end
	collect(recipe.inputs)
	for _, name in ipairs(names) do
		check(not name:find("weapon_grip", 1, true), recipe.output_name .. " uses no grip")
		for _, key in ipairs(CULTURAL) do
			check(name ~= "grug_materials:" .. key, recipe.output_name .. " uses no " .. key)
		end
	end
end

local env = setmetatable({grug_materials = {},
	core = {get_modpath = function() return nil end}}, {__index = _G})
local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
setfenv(chunk, env)
chunk()
local M = env.grug_materials
eq(M.CULTURAL_MATERIALS, nil, "no cultural material table")
local races = 0
for race, row in pairs(M.RACE_REGIONS) do
	races = races + 1
	eq(row.cultural, nil, race .. " region has no cultural material")
	check(M.SIGNATURE_WOODS[row.signature_wood] ~= nil, race .. " keeps its signature wood")
end
eq(races, 6, "six race regions")

local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
eq(catalog.cultural_sources, nil, "the gathering catalog has no cultural sources")
local manifest = catalog.manifest()
eq(manifest.population.r6_cultural_slot, nil, "no cultural slot in the population")
check(not manifest.canonical_bytes:find("cultural", 1, true),
	"the catalog bytes name no cultural row")
for _, row in ipairs(catalog.p9g_sources()) do
	for _, key in ipairs(CULTURAL) do
		check(row.key ~= key, "P9G has no " .. key)
	end
end

local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
for _, name in ipairs({"tier_at", "stratum_node_for", "level_for_tier", "natural_groups",
		"resource", "resource_for_node", "resource_node", "processed",
		"build_pick_capabilities", "pick_tier_for_stack", "is_natural_node",
		"required_pick_tier", "mining_decision", "resource_ore_description",
		"register_on_harvest", "emit_mining_failure", "node_dig_wrapper"}) do
	if type(M[name]) ~= "function" then M[name] = function() end end
end
M.PICK_PROFILES = M.PICK_PROFILES or {}
local projection = handoff.project(M)
eq(projection.cultural_materials, nil, "the WP43 projection has no cultural rows")

local summary = ("R33 C2 PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures)
print(summary)
if failures > 0 then os.exit(1) end
