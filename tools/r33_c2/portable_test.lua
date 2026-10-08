-- Round 33 lane C2 portable test (profession restructure, round33-plan.md
-- §2.7, §2.8). Loads the REAL files under small stubs and checks:
--   A. the roster: six primaries, Cooking and Alchemy secondary; a character
--      learns two primaries plus both secondaries, a third primary is
--      refused, a secondary cannot be unlearned; the Professions tab lists
--      all four inside the page (Round 45: the book slots went with the
--      recipe books);
--   B. progression counting (registry.lua + state.lua): an end product
--      counts, a material and a station (`progress = false`) do not, a
--      station operation does; the usual tier advance;
--   C. retired in Round 45: the shipped recipe set's progress flags and the
--      band caps are tools/r45_rg's (the real catalogs, not an engine dump);
--   D. retired in Round 45: the registry has no collision check (a craft
--      names its recipe);
--   E. removed things are absent: no removed id, API or data file in any
--      shipped Lua or JSON file (the recipe catalogs included), the
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
_G.grug_inventory = {refresh = function() end, refresh_character_tab = function() end,
	wrap_text = function(text) return text end}
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
-- The Character page's mode area (Round 44, real coordinates).
local area = {x = 0.4, y = 1.25, w = 7.5, h = 7.8}
local tab = jobs.professions_formspec(overview, area)
local lowest = 0
for y in tab:gmatch("label%[0%.40,([%d%.]+);") do lowest = math.max(lowest, tonumber(y)) end
check(lowest > 0 and lowest <= area.y + area.h - 0.25,
	"the tab's rows end inside the mode area (" .. lowest .. ")")


-- ---------------------------------------------------------------------------
-- B. Progression counting.
-- ---------------------------------------------------------------------------
jobs = load_jobs()
for _, name in ipairs({"t:ore", "t:bar", "t:fine", "t:gear", "t:mix", "t:node"}) do
	items[name] = {groups = {}}
end
jobs.register_ingredient_tier("t:ore", 1)
jobs.register_ingredient_tier("t:bar", 1)
local product = jobs.register_recipe({area = "weaponsmith", tier = 1, time = 3,
	ingredients = {{item = "t:ore", n = 2}}, output = "t:gear"})
local material = jobs.register_recipe({area = "weaponsmith", tier = 1, time = 1,
	ingredients = {{item = "t:ore", n = 1}}, output = "t:bar", material = true})
local station = jobs.register_recipe({area = "weaponsmith", tier = 1, time = 1,
	ingredients = {{item = "t:ore", n = 3}}, output = "t:node", progress = false})
eq(product.progress, true, "an end product counts")
eq(material.progress, false, "a material does not count")
eq(station.progress, false, "a station does not count")
check(not pcall(jobs.register_recipe, {area = "weaponsmith", tier = 1, time = 1,
	ingredients = {{item = "t:ore", n = 1}, {item = "t:bar", n = 1}}, output = "t:mix",
	progress = "yes"}), "a non-boolean progress flag is refused")

local smith = make_player("smith")
jobs.learn(smith, "weaponsmith")
local function crafts() return jobs.crafts_in_tier(smith, "weaponsmith") end
jobs.award_progress(smith, product)
eq(crafts(), 1, "the end product awarded one craft")
jobs.award_progress(smith, material)
jobs.award_progress(smith, station)
eq(crafts(), 1, "material and station awarded nothing")
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
check(read("mods/PLAYER/grug_jobs/workspaces.lua"):find("record_craft", 1, true) == nil,
	"the station dialogs never record directly")

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
