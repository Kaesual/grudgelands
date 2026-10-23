-- Round 57 lane ALLOY portable test (LuaJIT): the flat alloy and wood
-- chains and the missing recipe sources (the user's rulings of 2026-10-23).
--
--   luajit tools/r57_alloy/portable_test.lua [REPO]
--
-- Loads the REAL grug_jobs registry and Basic catalog and the REAL
-- grug_smelting alloys and recipes under a stub engine. Checks:
--   A  the five alloys, in order: Bronze = Copper + Tin, Steel = Iron Bar +
--      Anthracite, Silversteel, Embersteel and Abyssal Steel = Steel Bar +
--      Silver Bar, Emberglass, Abyssal Crystal; either slot order; the old
--      pairs (Silversteel + Emberglass, Embersteel + Abyssal Crystal) match
--      nothing; no alloy takes another alloy above Steel;
--   W  the six wood grades: one Basic recipe each, Seasoned 2 planks, every
--      other grade 2 planks + 1 of its tier's ingredient (Iron Bar,
--      Anthracite, Silver Bar, Emberglass, Abyssal Crystal), no grade from
--      another grade;
--   B  Steel Bars: one Basic recipe, 6 Steel Bars -> 16, and the Steel Bar
--      Door and Trapdoor still take them;
--   D  the dye decision: nothing makes White or Yellow Dye, and only dye
--      mixes and recoloured wool take them (no profession recipe, enchant,
--      upgrade or other data names a dye);
--   I  the item ids: the bar ids in grug_materials, the six grade keys in
--      grug_artisans/woodcarver.lua and the Steel Bars pane in xpanes;
--   C  the chain depth (tools/r57_chains): Silversteel, Embersteel and
--      Abyssal Steel are depth 3 (lump, Iron Bar, Steel, alloy), every grade
--      depth 2 (log, planks, grade).
-- Prints "R57 ALLOY PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local checks, failures = 0, 0
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
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The stub engine (as tools/r57_chains/portable_test.lua's R part).
local registered, crafts = {}, {}
_G.core = {
	registered_items = registered,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_modpath = function() return ROOT .. "/mods/ITEMS/grug_smelting" end,
	get_current_modname = function() return "grug_smelting" end,
	register_on_mods_loaded = function() end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_craft = function(def) crafts[#crafts + 1] = def end,
	log = function() end,
}
_G.grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
grug_jobs.register_basic_catalog(dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_recipes.lua"))
_G.grug_materials = {PROCESSED_MATERIALS = {}, RESOURCES = {}}
_G.grug_smelting = {}
dofile(ROOT .. "/mods/ITEMS/grug_smelting/alloys.lua")
dofile(ROOT .. "/mods/ITEMS/grug_smelting/recipes.lua")
local J, S = grug_jobs, grug_smelting

local M = "grug_materials:"
local function bar(key) return M .. key .. "_bar" end

------------------------------------------------------------------------------
-- A: the alloys.
------------------------------------------------------------------------------
local ALLOYS = {
	{bar("bronze"), bar("copper"), bar("tin")},
	{bar("steel"), bar("iron"), M .. "anthracite"},
	{bar("silversteel"), bar("steel"), bar("silver")},
	{bar("embersteel"), bar("steel"), M .. "emberglass"},
	{bar("abyssal_steel"), bar("steel"), M .. "abyssal_crystal"},
}
eq(#S.RECIPES, #ALLOYS, "A five alloys")
for index, row in ipairs(ALLOYS) do
	local recipe = S.RECIPES[index]
	if check(recipe ~= nil, "A alloy " .. index .. " is registered") then
		eq(recipe.output, row[1], "A alloy " .. index .. " output")
		eq(recipe.inputs[1] .. "+" .. recipe.inputs[2], row[2] .. "+" .. row[3],
			"A " .. row[1] .. " inputs")
		check(S.match(row[2], row[3]) == recipe and S.match(row[3], row[2]) == recipe,
			"A " .. row[1] .. " matches in either slot order")
		eq(S.recipe_for(row[1]), recipe, "A " .. row[1] .. " is its output's recipe")
	end
end
eq(S.match(bar("silversteel"), M .. "emberglass"), nil, "A Silversteel + Emberglass makes nothing")
eq(S.match(bar("embersteel"), M .. "abyssal_crystal"), nil,
	"A Embersteel + Abyssal Crystal makes nothing")
local above_steel = {[bar("silversteel")] = true, [bar("embersteel")] = true,
	[bar("abyssal_steel")] = true}
for _, recipe in ipairs(S.RECIPES) do
	for _, input in ipairs(recipe.inputs) do
		check(not above_steel[input], "A " .. recipe.output .. " takes no alloy above Steel (" ..
			input .. ")")
	end
end

------------------------------------------------------------------------------
-- W: the wood grades.
------------------------------------------------------------------------------
local GRADES = {
	{"seasoned", nil},
	{"polished", bar("iron")},
	{"hardened", M .. "anthracite"},
	{"inlaid", bar("silver")},
	{"lacquered", M .. "emberglass"},
	{"heartwood", M .. "abyssal_crystal"},
}
local grade_ids = {}
for _, row in ipairs(GRADES) do grade_ids["grug_artisans:" .. row[1] .. "_wood"] = true end
for tier, row in ipairs(GRADES) do
	local output = "grug_artisans:" .. row[1] .. "_wood"
	local list = J.recipes_for_output(output)
	if eq(#list, 1, "W " .. output .. " has one recipe") then
		local recipe = list[1]
		eq(recipe.area, "basic", "W " .. output .. " is Basic")
		eq(recipe.count, 1, "W " .. output .. " makes one")
		local wood, other, others = 0, nil, 0
		for _, entry in ipairs(recipe.ingredients) do
			if entry.group == "wood" then wood = wood + entry.n
			else
				others = others + 1
				other = entry
				check(not grade_ids[entry.item or ""],
					"W " .. output .. " takes no wood grade (" .. tostring(entry.item) .. ")")
			end
		end
		eq(wood, 2, "W " .. output .. " takes 2 planks")
		if row[2] == nil then
			eq(others, 0, "W T" .. tier .. " " .. output .. " is planks only")
		elseif eq(others, 1, "W T" .. tier .. " " .. output .. " takes one tier ingredient") then
			eq(other.item, row[2], "W " .. output .. " ingredient")
			eq(other.n, 1, "W " .. output .. " takes one unit")
		end
	end
end

------------------------------------------------------------------------------
-- B: Steel Bars.
------------------------------------------------------------------------------
local bars_list = J.recipes_for_output("xpanes:bar_flat")
if eq(#bars_list, 1, "B Steel Bars have one recipe") then
	local recipe = bars_list[1]
	eq(recipe.area, "basic", "B Steel Bars are Basic")
	eq(recipe.count, 16, "B 16 Steel Bars")
	eq(#recipe.ingredients, 1, "B one ingredient")
	eq(recipe.ingredients[1].item, bar("steel"), "B from Steel Bars")
	eq(recipe.ingredients[1].n, 6, "B six of them")
end
for _, output in ipairs({"xpanes:door_steel_bar", "xpanes:trapdoor_steel_bar"}) do
	local list = J.recipes_for_output(output)
	check(#list == 1 and list[1].ingredients[1].item == "xpanes:bar_flat",
		"B " .. output .. " takes Steel Bars")
end

------------------------------------------------------------------------------
-- D: White and Yellow Dye stay without a source (nothing beyond decor needs
-- them).
------------------------------------------------------------------------------
for _, dye in ipairs({"dye:white", "dye:yellow"}) do
	eq(#J.recipes_for_output(dye), 0, "D nothing makes " .. dye)
	for _, recipe in ipairs(J.recipes) do
		for _, entry in ipairs(recipe.ingredients) do
			if entry.item == dye then
				check(recipe.area == "basic" and
					(recipe.output:match("^dye:") or recipe.output:match("^wool:")) ~= nil,
					"D " .. dye .. " feeds only dye mixes and wool (" .. recipe.id .. ")")
			end
		end
	end
end
for _, path in ipairs({"mods/ITEMS/grug_professions/data/enchants.json",
		"mods/ITEMS/grug_professions/data/upgrades.json"}) do
	check(not read(path):find("dye:", 1, true), "D " .. path .. " names no dye")
end

------------------------------------------------------------------------------
-- I: the item ids stay.
------------------------------------------------------------------------------
local registry = read("mods/ITEMS/grug_materials/registry.lua")
for _, key in ipairs({"steel", "silversteel", "embersteel", "abyssal_steel"}) do
	check(registry:find('"' .. key .. '"', 1, true) ~= nil,
		"I grug_materials still declares the " .. key .. " row")
end
local woodcarver = read("mods/ITEMS/grug_artisans/woodcarver.lua")
local keys = {}
for key in woodcarver:gmatch('{key = "(%a+)", name = ') do keys[#keys + 1] = key end
eq(table.concat(keys, ","), "seasoned,polished,hardened,inlaid,lacquered,heartwood",
	"I the six grade keys")
check(woodcarver:find('C .. row.key .. "_wood"', 1, true) ~= nil, "I the grade ids are <key>_wood")
check(read("mods/BASE/xpanes/init.lua"):find('xpanes.register_pane("bar", {', 1, true) ~= nil,
	"I the Steel Bars pane is still xpanes:bar(_flat)")

------------------------------------------------------------------------------
-- C: the chain depth.
------------------------------------------------------------------------------
local chains = dofile(ROOT .. "/tools/r57_chains/chains.lua")
local steps_from_dump = dofile(ROOT .. "/tools/r57_chains/steps.lua")
local furnace = {}
for _, def in ipairs(crafts) do
	if def.type == "cooking" then
		local name, count = def.output:match("^(%S+)%s*(%d*)$")
		furnace[#furnace + 1] = {output = name, count = tonumber(count) or 1, input = def.recipe}
	end
end
-- Only the furnace's lump smelts are needed; the charcoal's group:tree input
-- gets one member like the planks.
local input = steps_from_dump({registry = J.recipes, furnace = furnace, alloys = S.RECIPES,
	groups = {["group:wood"] = {"default:wood"}, ["group:tree"] = {"default:tree"}},
	aliases = {}})
local real = chains.analyse(input.steps, input.members)
local function depth(item)
	local info = real.items[item]
	return info and info.depth
end
for _, key in ipairs({"silversteel", "embersteel", "abyssal_steel"}) do
	eq(depth(bar(key)), 3, "C " .. key .. " bar is depth 3")
end
for _, row in ipairs(GRADES) do
	eq(depth("grug_artisans:" .. row[1] .. "_wood"), 2, "C " .. row[1] .. " wood is depth 2")
end

if failures > 0 then
	error(("R57 ALLOY PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 ALLOY PORTABLE PASS checks=%d"):format(checks))
