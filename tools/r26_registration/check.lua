-- Round 26 Lane R portable check (LuaJIT): registration cleanup.
--
--   tools/r26_registration/check.sh   (runs: luajit check.lua REPO FILE_LIST)
--
-- 1. Loads the real default tool sources, grug_materials and grug_nodes
--    through the Round 24 mining harness (tools/r24_mining/fixture.lua, which
--    also runs the grug_materials startup audit) and checks the one tool
--    namespace (ruling 14): 24 canonical `grug_materials:` picks, axes and
--    shovels with their tier groups, no tier tool anywhere else, the twelve
--    `default:` names as aliases only, and the recipes/fuel rows the move
--    re-registers.
-- 2. Loads the vendored mobs_redo crafts.lua under a stub and checks that the
--    eight utility items (ruling 13) are neither registered nor referenced by
--    a recipe or fuel row.
-- 3. Scans every shipped Lua file for the retired names: no old `default:`
--    tool name outside the vendored registration and the alias loop, no
--    removed mobs utility outside mobs_redo's own api.lua string compares,
--    and only canonical `grug_materials:` tool names.
-- 4. Reads the Basics recipe catalog (grug_jobs/basics_routes.lua): no
--    silver-sandstone or mobs-utility route, and the six Wood/Stone tool
--    routes match the recipes tools.lua registers, key for key.
-- 5. Loads the real spawn roster (tools/r24_density_xp/roster.lua) and checks
--    the WP37 remainder (ruling 15): the two surface critters at chance 2933
--    (2200 / 0.75: 0.75 x density, chance is 1-in-N), aoc unchanged, the two
--    cave critters still at 2200.
-- Prints "R26 REGISTRATION CHECK PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: tools/r26_registration/check.sh")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local FAMILIES = {"pick", "axe", "shovel"}
local GRADES = {"wood", "stone", "bronze", "iron", "steel", "silversteel",
	"embersteel", "abyssal_steel"}
local VENDORED = {wood = true, stone = true, bronze = true, steel = true}
local TIER_OF = {wood = 1, stone = 1, bronze = 1, iron = 2, steel = 3,
	silversteel = 4, embersteel = 5, abyssal_steel = 6}
local REMOVED_MOBS = {"mobs:nametag", "mobs:net", "mobs:lasso", "mobs:shears",
	"mobs:protector", "mobs:protector2", "mobs:mob_repellent", "mobs:saddle"}

-- ---------------------------------------------------------------------------
-- 1. The tool namespace, through the real registrations.
-- ---------------------------------------------------------------------------
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local M = grug_materials

local canonical = {}
for _, family in ipairs(FAMILIES) do
	for _, grade in ipairs(GRADES) do
		local name = "grug_materials:" .. family .. "_" .. grade
		canonical[name] = true
		local def = H.tools[name]
		check(def ~= nil and def.type == "tool", name .. " is a registered tool")
		check(def.groups["grug_" .. family .. "_tier"] == TIER_OF[grade],
			name .. " tier group")
		check(def.groups[family == "pick" and "pickaxe" or family] == 1,
			name .. " family group")
		check(def.groups.grug_gathering_tool == 1 and def._grug_tool_uses,
			name .. " passed the lifetime pass")
		if VENDORED[grade] then
			local old = "default:" .. family .. "_" .. grade
			check(rawget(H.items, old) == nil, old .. " is not registered")
			check(H.aliases[old] == name and M.TOOL_ALIASES[old] == name,
				old .. " is an alias of " .. name)
		end
	end
end
local alias_count = 0
for old, new in pairs(M.TOOL_ALIASES) do
	alias_count = alias_count + 1
	check(canonical[new] and old:match("^default:"), "alias row " .. old)
end
check(alias_count == 12, "twelve tool aliases")
-- Nothing with a tier group or a pick/axe/shovel family group outside the
-- namespace, and no tool at all left in `default:`.
local tier_tools = 0
for name, def in pairs(H.items) do
	local groups = def.groups or {}
	if groups.grug_pick_tier or groups.grug_axe_tier or groups.grug_shovel_tier or
			(def.type == "tool" and (groups.pickaxe or groups.axe or groups.shovel)) then
		tier_tools = tier_tools + 1
		check(canonical[name], "tier tool inside grug_materials: " .. name)
	end
	check(not (def.type == "tool" and name:match("^default:")),
		"no default: tool remains: " .. name)
end
check(tier_tools == 24, "exactly 24 tier tools (" .. tier_tools .. ")")
-- The cloned grades keep their vendored identity (image, sound, flammable).
check(H.items["grug_materials:pick_wood"].inventory_image ==
	"default_tool_woodpick.png", "wood pick keeps its sprite")
check(H.items["grug_materials:axe_wood"].groups.flammable == 2,
	"wood axe stays flammable")
check(H.items["grug_materials:shovel_steel"].wield_image == "",
	"cloned shovel wield image cleared")

-- Recipes: nothing names an old tool; Wood/Stone recipes and wood fuel exist
-- under the canonical names with default's shapes and burn times.
local by_output, fuel = {}, {}
local function names_in(recipe, out)
	if type(recipe) == "string" then out[#out + 1] = recipe
	elseif type(recipe) == "table" then
		for _, value in ipairs(recipe) do names_in(value, out) end
	end
	return out
end
for _, craft in ipairs(H.crafts()) do
	if craft.type == "fuel" then
		fuel[craft.recipe] = craft.burntime
	else
		by_output[craft.output] = by_output[craft.output] or {}
		table.insert(by_output[craft.output], craft)
	end
	for _, name in ipairs(names_in(craft.recipe, {craft.output or ""})) do
		check(not name:match("^default:[a-z]+_[a-z_]+$") or not
			M.TOOL_ALIASES[name], "recipe names no alias: " .. name)
	end
end
for _, grade in ipairs({"wood", "stone"}) do
	for _, family in ipairs(FAMILIES) do
		local list = by_output["grug_materials:" .. family .. "_" .. grade]
		check(list and #list == 1, family .. "_" .. grade .. " has one recipe")
	end
end
check(fuel["grug_materials:pick_wood"] == 6 and fuel["grug_materials:shovel_wood"] == 4 and
	fuel["grug_materials:axe_wood"] == 6, "wooden tools burn as before")
for old in pairs(M.TOOL_ALIASES) do
	check(fuel[old] == nil and by_output[old] == nil, "no recipe row for " .. old)
end

-- ---------------------------------------------------------------------------
-- 2. mobs_redo crafts.lua without the utility items.
-- ---------------------------------------------------------------------------
do
	local registered, crafts = {}, {}
	local noop = function() end
	local permissive = {__index = function() return noop end}
	local saved = {}
	for _, key in ipairs({"core", "minetest", "mobs", "default"}) do
		saved[key] = rawget(_G, key)
	end
	local stub = setmetatable({
		registered_items = registered,
		get_translator = function() return function(s) return s end end,
		formspec_escape = function(s) return s end,
		get_modpath = function(name) return name == "default" and "x" or nil end,
		register_craftitem = function(name, def) registered[name:gsub("^:", "")] = def end,
		register_tool = function(name, def) registered[name:gsub("^:", "")] = def end,
		register_node = function(name, def) registered[name:gsub("^:", "")] = def end,
		register_craft = function(def) crafts[#crafts + 1] = def end,
	}, permissive)
	_G.core, _G.minetest = stub, stub
	_G.mobs = setmetatable({}, permissive)
	_G.default = setmetatable({register_fence = function(name, def)
		registered[name] = def
	end}, permissive)
	assert(loadfile(repo .. "/mods/ENTITIES/mobs/crafts.lua"))()
	for key, value in pairs(saved) do rawset(_G, key, value) end

	for _, name in ipairs(REMOVED_MOBS) do
		check(registered[name] == nil, name .. " is not registered")
	end
	for _, name in ipairs({"mobs:leather", "mobs:meat_raw", "mobs:meat",
			"mobs:fence_top", "mobs:meatblock", "mobs:mob_reset_stick"}) do
		check(registered[name] ~= nil, name .. " stays registered")
	end
	local removed = {}
	for _, name in ipairs(REMOVED_MOBS) do removed[name] = true end
	for _, craft in ipairs(crafts) do
		for _, name in ipairs(names_in(craft.recipe, {tostring(craft.output or "")})) do
			check(not removed[name:match("^(%S+)")], "mobs recipe names " .. name)
		end
	end
end

-- ---------------------------------------------------------------------------
-- 3. Shipped sources: retired names.
-- ---------------------------------------------------------------------------
-- The file list comes from check.sh (`find mods -name '*.lua'`), so this
-- file needs no process spawning.
local function lua_files()
	local list = {}
	local listing = assert(io.open(assert(arg[2], "usage: check.sh"), "r"))
	for line in listing:lines() do list[#list + 1] = line end
	listing:close()
	return list
end
local removed_mobs = {}
for _, name in ipairs(REMOVED_MOBS) do removed_mobs[name] = true end
local files = lua_files()
check(#files > 400, "found the shipped Lua files (" .. #files .. ")")
local canonical_hits = 0
for _, path in ipairs(files) do
	local source = assert(io.open(repo .. "/" .. path)):read("*a")
	for name in source:gmatch("[\"']([%w_]+:[%w_]+)[\"']") do
		if M.TOOL_ALIASES[name] then
			check(path == "mods/BASE/default/tools.lua",
				path .. " names the retired " .. name)
		end
		if removed_mobs[name] then
			-- api.lua: upstream wielded-name compares, never reached;
			-- content_curation.lua: the audit's list of names that must stay
			-- unregistered.
			check(path == "mods/ENTITIES/mobs/api.lua" or
				path == "mods/ITEMS/grug_materials/content_curation.lua",
				path .. " names the removed " .. name)
		end
		local family = name:match("^grug_materials:(%a+)_")
		if (family == "pick" or family == "axe" or family == "shovel") and
				name:sub(-1) ~= "_" then -- a prefix to concatenate is no name
			check(canonical[name], path .. " names a canonical tool: " .. name)
			canonical_hits = canonical_hits + 1
		end
	end
end
check(canonical_hits > 0, "canonical tool names are referenced")

-- ---------------------------------------------------------------------------
-- 4. The Basics catalog.
-- ---------------------------------------------------------------------------
local routes = dofile(repo .. "/mods/PLAYER/grug_jobs/basics_routes.lua")
local catalog = {}
for _, route in ipairs(routes) do
	local names = {route.output}
	for _, input in ipairs(route.inputs) do names[#names + 1] = input end
	for _, name in ipairs(names) do
		check(not name:find("silver_sand", 1, true), "catalog silver route " .. route.output)
		check(not removed_mobs[name], "catalog mobs utility " .. name)
		check(not M.TOOL_ALIASES[name], "catalog old tool name " .. name)
	end
	catalog[route.output] = catalog[route.output] or {}
	table.insert(catalog[route.output], route)
end
-- The Wood/Stone rows must be exactly what tools.lua registers: the catalog's
-- width and flattened slots are the engine's view of those shaped recipes.
for _, grade in ipairs({"wood", "stone"}) do
	for _, family in ipairs(FAMILIES) do
		local output = "grug_materials:" .. family .. "_" .. grade
		local craft = by_output[output][1]
		local width, slots = 0, {}
		for _, row in ipairs(craft.recipe) do
			if #row > width then width = #row end
		end
		for r, row in ipairs(craft.recipe) do
			for c = 1, width do slots[(r - 1) * width + c] = row[c] or "" end
		end
		while slots[#slots] == "" do slots[#slots] = nil end
		local rows = catalog[output]
		check(rows and #rows == 1, output .. " has one catalog row")
		local route = rows[1]
		check(route.width == width and table.concat(route.inputs, "|") ==
			table.concat(slots, "|") and route.starter == true,
			output .. " catalog row matches the registered recipe")
	end
end
for _, family in ipairs(FAMILIES) do
	for _, grade in ipairs(GRADES) do
		check(catalog["grug_materials:" .. family .. "_" .. grade],
			family .. "_" .. grade .. " is in the Basics catalog")
	end
end

-- ---------------------------------------------------------------------------
-- 5. The two surface critters take x0.75; the cave critters do not.
-- ---------------------------------------------------------------------------
local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
check(#roster.failed == 0, "roster loads: " .. table.concat(roster.failed, "; "))
local expected = {["grug_mobs:bone_weevil"] = {2933, 2}, ["grug_mobs:bog_fowl"] = {2933, 1},
	["grug_mobs:cave_bat"] = {2200, 1}, ["grug_mobs:cave_crawler"] = {2200, 1}}
local seen = {}
for index, row in ipairs(roster.raw_rows) do
	local want = expected[row.name]
	if want then
		seen[row.name] = (seen[row.name] or 0) + 1
		check(row.chance == want[1], row.name .. " raw chance " .. tostring(row.chance))
		-- Critters are neither budgeted nor ambient-scaled: the prepared row
		-- keeps the authored chance and cap.
		check(roster.rows[index].chance == want[1] and
			roster.rows[index].active_object_count == row.active_object_count,
			row.name .. " prepared row unchanged")
	end
end
for name, want in pairs(expected) do
	check(seen[name] == want[2], name .. " row count")
end
for _, row in ipairs(roster.raw_rows) do
	if row.name == "grug_mobs:bone_weevil" or row.name == "grug_mobs:bog_fowl" then
		check(row.active_object_count == 2, row.name .. " aoc stays 2")
	end
end

print(("tools %d (%d aliases), shipped Lua files %d, catalog routes %d"):format(
	tier_tools, alias_count, #files, #routes))
print("R26 REGISTRATION CHECK PASS checks=" .. checks)
