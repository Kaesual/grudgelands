-- Round 57 lane DYES portable test (LuaJIT): every dye and every coloured
-- wool reachable from what anyone gathers (the user's ruling 29).
--
--   luajit tools/r57_dyes/portable_test.lua [REPO]
--
-- Loads the REAL grug_jobs registry and Basic catalog under a stub engine.
-- Checks:
--   N  the four new rows: Bone -> 2 White, Sunleaf -> 2 Yellow, Apple ->
--      2 Red, Marshbloom -> 2 Cyan (Basic, one raw item each);
--   U  their raws are gathered by everyone: Sunleaf and Marshbloom have a
--      world source (grug_gathering catalog) and are no Alchemy herb
--      (grug_gathering/harvest.lua VALID_HERBS); Bone drops from the zombie
--      family from band 1 (grug_mobs drops.json); Apple grows on the apple
--      trees (grug_mapgen tree templates);
--   R  reachability: from Coal, Blueberries, the four raws and White Wool
--      (the base wool vendors sell; no mob drops wool), the dye and wool
--      recipes make all 15 dyes and all 15 wools;
--   O  nothing else changed: the dye rows are exactly the six plain sources
--      and the 19 vendored mixes, and the catalog has 246 rows (ALLOY's 235,
--      these four and Round 67's container tiers, +8 -1).
-- Prints "R57 DYES PORTABLE PASS checks=<n>" or the failures.

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

_G.core = {
	registered_items = {},
	get_item_group = function() return 0 end,
	register_on_mods_loaded = function() end,
	log = function() end,
}
_G.grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
local catalog = dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_recipes.lua")
grug_jobs.register_basic_catalog(catalog)
local J = grug_jobs

local COLOURS = {"white", "grey", "dark_grey", "black", "violet", "blue", "cyan",
	"dark_green", "green", "yellow", "brown", "orange", "red", "magenta", "pink"}

------------------------------------------------------------------------------
-- N: the new rows.
------------------------------------------------------------------------------
local NEW = {
	{"dye:white", "grug_mobs:bone"},
	{"dye:yellow", "grug_gathering:sunleaf"},
	{"dye:red", "default:apple"},
	{"dye:cyan", "grug_gathering:marshbloom"},
}
for _, row in ipairs(NEW) do
	local found
	for _, recipe in ipairs(J.recipes_for_output(row[1])) do
		if #recipe.ingredients == 1 and recipe.ingredients[1].item == row[2] then found = recipe end
	end
	if check(found ~= nil, "N " .. row[2] .. " makes " .. row[1]) then
		eq(found.area, "basic", "N " .. row[1] .. " from " .. row[2] .. " is Basic")
		eq(found.count, 2, "N " .. row[1] .. " makes 2")
		eq(found.ingredients[1].n, 1, "N from one " .. row[2])
	end
end

------------------------------------------------------------------------------
-- U: the raws are gathered by everyone.
------------------------------------------------------------------------------
local gathering = read("mods/ITEMS/grug_gathering/catalog.lua")
local harvest = read("mods/ITEMS/grug_gathering/harvest.lua")
local herbs = harvest:match("VALID_HERBS = (%b{})")
check(herbs ~= nil, "U harvest.lua lists the Alchemy herbs")
for _, key in ipairs({"sunleaf", "marshbloom"}) do
	local row = gathering:match('p9g%("wp33_' .. key .. '_source_v1".-%)%,\n')
	if check(row ~= nil, "U " .. key .. " has a world source") then
		check(not row:find('"healing_herb"', 1, true), "U " .. key .. " is no healing herb")
	end
	check(herbs and not herbs:find('grug_gathering:' .. key, 1, true), "U " .. key .. " needs no Alchemy")
end
local drops = read("mods/ENTITIES/grug_mobs/data/drops.json")
local zombie = drops:match('"family": "zombie".-"leader_bonus"')
check(zombie ~= nil and zombie:match('"1": %[.-%]') ~= nil, "U the zombie family drops in band 1")
check(drops:match('"family": "zombie".-"leader_bonus": %[%s*{%s*"item": "grug_mobs:bone"') ~= nil,
	"U zombie leaders drop Bone")
check(read("mods/MAPGEN/grug_mapgen/wp40/tree_templates.lua"):find('fruit = "default:apple"', 1, true) ~= nil,
	"U apple trees carry Apples")

------------------------------------------------------------------------------
-- R: reachability.
------------------------------------------------------------------------------
local have = {["default:coal_lump"] = true, ["default:blueberries"] = true,
	["wool:white"] = true}
for _, row in ipairs(NEW) do have[row[2]] = true end
local function has_group(group)
	for name in pairs(have) do
		if group == "coal" and name == "default:coal_lump" then return true end
		if group == "wool" and name:match("^wool:") then return true end
	end
	return false
end
local changed = true
while changed do
	changed = false
	for _, recipe in ipairs(J.recipes) do
		if not have[recipe.output] and recipe.output:match("^dye:") or
				not have[recipe.output] and recipe.output:match("^wool:") then
			local ok = true
			for _, entry in ipairs(recipe.ingredients) do
				if entry.item and not have[entry.item] then ok = false end
				if entry.group and not has_group(entry.group) then ok = false end
			end
			if ok then have[recipe.output] = true changed = true end
		end
	end
end
for _, colour in ipairs(COLOURS) do
	check(have["dye:" .. colour], "R " .. colour .. " dye is reachable")
	check(have["wool:" .. colour], "R " .. colour .. " wool is reachable")
end

------------------------------------------------------------------------------
-- O: nothing else changed.
------------------------------------------------------------------------------
local WANTED = {
	["dye:black|group:coal*1"] = 4, ["dye:violet|default:blueberries*1"] = 2,
	["dye:white|grug_mobs:bone*1"] = 2, ["dye:yellow|grug_gathering:sunleaf*1"] = 2,
	["dye:red|default:apple*1"] = 2, ["dye:cyan|grug_gathering:marshbloom*1"] = 2,
}
-- The vendored mixes (BASE/dye/init.lua dye_recipes), 2 of the result each.
for a, b, out in read("mods/BASE/dye/init.lua"):gmatch('{"(%a[%a_]*)", "(%a[%a_]*)", "(%a[%a_]*)"}') do
	local keys = {"dye:" .. a .. "*1", "dye:" .. b .. "*1"}
	table.sort(keys)
	WANTED["dye:" .. out .. "|" .. table.concat(keys, "+")] = 2
end
local wanted_count, seen = 0, 0
for _ in pairs(WANTED) do wanted_count = wanted_count + 1 end
eq(wanted_count, 25, "O six plain sources and 19 mixes")
for _, recipe in ipairs(J.recipes) do
	if recipe.output:match("^dye:") then
		seen = seen + 1
		local tokens = {}
		for _, entry in ipairs(recipe.ingredients) do
			tokens[#tokens + 1] = (entry.item or ("group:" .. entry.group)) .. "*" .. entry.n
		end
		table.sort(tokens)
		local key = recipe.output .. "|" .. table.concat(tokens, "+")
		eq(WANTED[key], recipe.count, "O dye row " .. key)
	end
end
eq(seen, 25, "O 25 dye rows")
-- Round 67 CONTAINERS: +8 container tier rows, -1 chest + Iron Bar row.
eq(#catalog.recipes, 246, "O the catalog has 246 rows")

if failures > 0 then
	error(("R57 DYES PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 DYES PORTABLE PASS checks=%d"):format(checks))
