-- Round 29 lane M-res portable test (economy plan §6, apex_sockets removal).
-- Loads the REAL files under minimal stubs and checks:
--   1. the material registry: six gems, one per tier, harvest tier = tier,
--      every gem with cut and block form; no grades, no per-race gem columns;
--      one gem density (1 per 512 host nodes);
--   2. the mapgen rows (r7_r6_manifest.lua): each gem only in its own tier
--      band at 512, first tier = harvest tier; the Diamond deep multipliers
--      as arithmetic (host nodes per gem at -1500...-1999 and below -2000);
--   3. the WP43 projection (wp43_handoff.lua): no grade table, the gem density;
--   4. the real R6 content module accepts the rows and refuses a gem moved
--      out of its band or a different gem density;
--   5. the Goldsmith (goldsmith.lua under stubs): every cut at its mining
--      tier, trinket gems by recipe tier, the bonus yield only for gems;
--   6. enchants.json: every gem input at or below the enchant tier, and the
--      families that used a gem before Round 29 still use one;
--   7. the map source: no apex sockets, no exact-column hard recipe, the 12
--      start and capital hard footprints only, no region_resources table.
--
-- Usage (repo root): luajit tools/r29_mres/portable_test.lua [REPO]

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

local GEMS = {"citrine", "jade", "garnet", "sapphire", "ruby", "diamond"}

-- 1. Registry -----------------------------------------------------------------
local function load_registry()
	local env = setmetatable({grug_materials = {},
		core = {get_modpath = function() return nil end}}, {__index = _G})
	local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
	setfenv(chunk, env)
	chunk()
	return env.grug_materials
end
local M = load_registry()
local gem_by_tier, gem_count = {}, 0
for _, resource in ipairs(M.RESOURCES) do
	check(resource.scope == nil and resource.grade == nil,
		resource.key .. " has no scope or grade")
	if resource.gem then
		gem_count = gem_count + 1
		gem_by_tier[resource.harvest_tier] = resource
		check(resource.cut_item ~= nil and resource.block_node ~= nil,
			resource.key .. " has cut and block forms")
	end
end
eq(gem_count, 6, "gem count")
for tier = 1, 6 do
	eq(gem_by_tier[tier] and gem_by_tier[tier].key, GEMS[tier], "gem of tier " .. tier)
end
eq(M.RESOURCE_BY_KEY.quartz.gem, nil, "Quartz is no gem")
eq(M.RESOURCE_BY_KEY.quartz.harvest_tier, 1, "Quartz stays T1")
eq(M.GEM_GRADES, nil, "no gem grades")
for race, row in pairs(M.RACE_REGIONS) do
	check(row.g1 == nil and row.g2 == nil, race .. " region has no gem columns")
	check(row.cultural ~= nil and row.signature_wood ~= nil,
		race .. " region keeps culture and wood")
end
eq(M.DENSITY.g1, nil, "no G1 density")
eq(M.DENSITY.g2, nil, "no G2 density")
eq(M.DENSITY.gem and M.DENSITY.gem.host_nodes_per_ore, 512, "gem density")

-- 2. Mapgen rows ----------------------------------------------------------------
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local row_by_key = {}
for _, row in ipairs(manifest.resources) do
	row_by_key[row.key] = row
	eq(row.scope, nil, row.key .. " mapgen row has no scope")
end
for tier, key in ipairs(GEMS) do
	local row = row_by_key[key]
	if check(row ~= nil, key .. " mapgen row") then
		eq(row.first_tier, tier, key .. " first tier")
		for band = 1, 6 do
			eq(row.denominators[band], band == tier and 512 or false,
				key .. " denominator in band " .. band)
		end
	end
end
-- Diamond in the deep bands: the row's multiplier on its 512 host nodes.
local diamond = row_by_key.diamond
local deep_1500 = 512 * diamond.deep_1500_1999_denominator /
	diamond.deep_1500_1999_numerator
local deep_2000 = 512 * diamond.deep_2000_floor_denominator /
	diamond.deep_2000_floor_numerator
check(math.abs(deep_1500 - 409.6) < 1e-9, "Diamond -1500...-1999: one per 409.6")
check(math.abs(deep_2000 - 1024 / 3) < 1e-9, "Diamond below -2000: one per 341.3")
for tier = 1, 5 do
	-- Only Diamond's band (T6, below -1000) reaches the deep bands.
	check(M.TIERS[tier].y_min > -1500, GEMS[tier] .. " band ends above -1500")
end

-- 3. WP43 projection ---------------------------------------------------------
local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
local stubs = {"tier_at", "stratum_node_for", "level_for_tier", "natural_groups",
	"resource", "resource_for_node", "resource_node", "processed",
	"build_pick_capabilities", "pick_tier_for_stack", "is_natural_node",
	"required_pick_tier", "mining_decision", "resource_ore_description",
	"register_on_harvest", "emit_mining_failure", "node_dig_wrapper"}
for _, name in ipairs(stubs) do
	if type(M[name]) ~= "function" then M[name] = function() end end
end
M.PICK_PROFILES = M.PICK_PROFILES or {}
local projection = handoff.project(M)
eq(projection.gem_grades, nil, "projection has no gem grades")
eq(projection.density.gem.host_nodes_per_ore, 512, "projected gem density")
eq(projection.density.g2, nil, "projection has no G2 density")

-- 4. The real R6 content module -----------------------------------------------
local B = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
check(pcall(B.content), "R6 content accepts the gem rows")
local function content_fails(mutate, restore, label)
	mutate()
	local ok, err = pcall(B.content)
	restore()
	check(not ok and tostring(err):find("resource", 1, true) ~= nil,
		label .. " (got " .. (ok and "no error" or tostring(err)) .. ")")
end
local jade
for _, row in ipairs(B.manifest.resources) do
	if row.key == "jade" then jade = row end
end
content_fails(function() jade.denominators[3] = 512 end,
	function() jade.denominators[3] = false end, "a gem outside its band is refused")
content_fails(function() B.projection.density.gem.host_nodes_per_ore = 256 end,
	function() B.projection.density.gem.host_nodes_per_ore = 512 end,
	"a different gem density is refused")
check(pcall(B.content), "R6 content accepts the restored rows")

-- 5. Goldsmith -----------------------------------------------------------------
local recipes, ingredient_tiers, harvest_callbacks = {}, {}, {}
local A = {}
function A.register_ingredient(item, tier)
	check(ingredient_tiers[item] == nil or ingredient_tiers[item] == tier,
		item .. " keeps one ingredient tier")
	ingredient_tiers[item] = tier
end
function A.register_recipe(profession, definition)
	recipes[#recipes + 1] = definition
end
function A.register_item(name) return name end
local env = setmetatable({
	grug_artisans = A,
	grug_materials = {RESOURCES = M.RESOURCES,
		register_on_harvest = function(fn) harvest_callbacks[#harvest_callbacks + 1] = fn end},
	grug_gear = {trinket_item = function(key, tier) return "trinket:" .. key .. ":" .. tier end},
	grug_jobs = {has = function() return true end},
	grug_items = {mastery_band = function() return 1 end},
	core = {add_item = function() end},
}, {__index = _G})
local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_artisans/goldsmith.lua"))
setfenv(chunk, env)
chunk()
local cuts, trinket_gems = {}, {}
for _, recipe in ipairs(recipes) do
	local output = recipe.output
	if output:match("^grug_materials:cut_") then
		cuts[output] = recipe.tier
	elseif output:match("^trinket:manawell:") then
		local gems = {}
		for _, row in ipairs(recipe.inputs) do
			for _, item in ipairs(row) do
				local key = item:match("^grug_materials:cut_(.+)$")
				if key then gems[#gems + 1] = key end
			end
		end
		trinket_gems[recipe.tier] = table.concat(gems, ",")
	end
end
for _, resource in ipairs(M.RESOURCES) do
	if resource.cut_item then
		eq(cuts[resource.cut_item], resource.harvest_tier, resource.key .. " cuts at its tier")
		eq(ingredient_tiers[resource.raw_item], resource.harvest_tier,
			resource.key .. " raw ingredient tier")
	end
end
local EXPECTED_TRINKET = {"quartz", "jade", "garnet", "sapphire", "ruby,sapphire",
	"diamond,ruby,sapphire"}
for tier = 1, 6 do
	eq(trinket_gems[tier], EXPECTED_TRINKET[tier], "T" .. tier .. " trinket gems")
end
local function bonus(resource)
	local player = {is_player = function() return true end,
		get_inventory = function() return {add_item = function() return nil end} end}
	return env.grug_artisans.settle_goldsmith_bonus({resource = resource,
		raw_item = resource.raw_item, digger = player}, 1)
end
eq(bonus(M.RESOURCE_BY_KEY.diamond), true, "Goldsmith bonus on a gem")
eq(bonus(M.RESOURCE_BY_KEY.citrine), true, "Goldsmith bonus on the T1 gem")
eq(bonus(M.RESOURCE_BY_KEY.quartz), false, "no Goldsmith bonus on Quartz")

-- 6. enchants.json ----------------------------------------------------------------
local gem_tier = {}
for tier, key in ipairs(GEMS) do gem_tier["grug_materials:rough_" .. key] = tier end
local enchant_gems, tier = {}, nil
for line in read("mods/ITEMS/grug_professions/data/enchants.json"):gmatch("[^\n]+") do
	local value = line:match('"tier": (%d+)')
	if value then tier = tonumber(value) enchant_gems[tier] = {} end
	local family, item = line:match('"([%w_]+)": "(grug_materials:rough_[%w_]+)"')
	if family then
		enchant_gems[tier][family] = item
		check(gem_tier[item] ~= nil and gem_tier[item] <= tier,
			("T%d %s gem %s at or below the enchant tier"):format(tier, family, item))
	end
end
-- The families that used a gem before Round 29 (economy plan §6.2).
local GEM_FAMILIES = {
	[2] = {"dagger", "bow", "caster_weapon", "spellbook", "trinket"},
	[3] = {"dagger", "leather_armor", "cloth_armor", "bow", "caster_weapon",
		"spellbook", "trinket"},
	[4] = {"dagger", "shield", "leather_armor", "cloth_armor", "bow",
		"caster_weapon", "spellbook", "trinket"},
	[5] = {"dagger", "shield", "spellbook", "trinket"},
	[6] = {"dagger", "shield", "trinket"},
}
for t, families in pairs(GEM_FAMILIES) do
	for _, family in ipairs(families) do
		check(enchant_gems[t] and enchant_gems[t][family] ~= nil,
			("T%d %s keeps a gem"):format(t, family))
	end
end
eq(read("mods/ITEMS/grug_professions/data/enchants.json"),
	read("docs/planning/round28/design/catalog/enchants.json"),
	"shipped enchants.json equals the catalogue copy")

-- 7. Map source -------------------------------------------------------------------
local source = dofile(wp40 .. "/source/simple_map.lua")
eq(source.apex_sockets, nil, "no apex sockets")
eq(source.region_resources, nil, "no region_resources")
for _, recipe in ipairs(source.hard_protection_recipes) do
	check(recipe.shape ~= "exact_column", "no exact-column hard recipe " .. recipe.id)
end
eq(#source.hard_protection, 12, "hard footprints are the six starts and six capitals")
for _, hard in ipairs(source.hard_protection) do
	check(hard.recipe_id == "hard_capital_city_v1" or hard.recipe_id == "hard_start_town_v1",
		hard.id .. " is a start or capital")
end

print(("R29 M-RES PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error(failures .. " failures", 0) end
