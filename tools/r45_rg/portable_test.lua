-- Round 45 lane RG portable test (LuaJIT): the recipe registry
-- (round45-plan.md §3, §4.2; ui-crafting-rework-plan.md §2.23, §2.30-2.36,
-- §4.1).
--
--   luajit tools/r45_rg/portable_test.lua [REPO]
--
-- Loads the REAL grug_jobs registry.lua, basic_recipes.lua, state.lua,
-- station_nodes.lua (its station recipes) and craft_list.lua, the REAL
-- grug_professions (init, smiths, leatherworker, tailor, base_recipes) and
-- grug_artisans (init, woodcarver, goldsmith) under a stub engine, and the
-- base commit's engine catalog tools/r45_rg/corpus_base.lua. Checks:
--   R  the record shape (exactly the plan's fields) and the queries by id,
--      area (tier, then the output's description, then id) and output;
--      ingredient_list; the refusals (unknown area, a station that is not
--      the profession's, XP in Basic, a duplicate id, a higher-tier
--      ingredient, no ingredient of the recipe's tier, an ingredient listed
--      twice, a bad count); a Basic record's tier is inferred after load;
--   C  the conversion: every grid route of the base catalog has its record
--      with the same output, count and ingredients (counted from the slots;
--      the dye tokens resolved to their one item) -- in Basic, in the
--      gear's profession or in the profession that registered it -- except
--      the dropped written-book copy and the Cooking and Alchemy routes
--      (tools/r28_b5_prof and tools/r33_c5); no Basic record lacks a route;
--      the old profession registry's bench recipes keep their ingredients;
--      basic_recipes.lua is current with its generator (--check);
--   G  gear in its profession (spec §2.23, §2.34): every weapon, armour piece
--      and offhand of the catalog is a record of the family's owner, at the
--      tier of its bracket, with the owner's station and 3 s; arrows, tools,
--      rods, sticks and the hoe stay Basic; trinkets are the Goldsmith's;
--   D  durations (spec §2.30) and stations (§2.27): Basic 1 s without a
--      station or XP, gear 3 s, bags 3 s with XP, intermediates 1 s without
--      XP, station nodes 1 s without XP or a station; every profession
--      record needs its profession's station except the station nodes; no
--      record carries a mastery band;
--   K  the craft list: a join shrinks an empty 9-slot list to 0, keeps a
--      list that still holds a stack, leaves a size-0 list alone;
--   X  removed: no shipped file names a removed function, file or the
--      craft grid; outside the furnaces, the vendored fuel and cooking
--      queries, the price module's cooking reader and the curation clears,
--      nothing reads the engine's craft recipes.
-- Prints "R45 RG PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
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
	local handle = assert(io.open(repo .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function refused(fn, label)
	local ok = pcall(fn)
	return check(not ok, label)
end

local corpus = dofile(repo .. "/tools/r45_rg/corpus_base.lua")

------------------------------------------------------------------------------
-- Stub engine.
------------------------------------------------------------------------------
local registered = {}
local function group_of(name, group)
	local def = registered[name]
	return def and def.groups and def.groups[group] or 0
end
local loaded = {}
local engine_crafts = {}
local MODS = {grug_jobs = "mods/PLAYER/grug_jobs",
	grug_professions = "mods/ITEMS/grug_professions",
	grug_artisans = "mods/ITEMS/grug_artisans"}
local current_mod
_G.core = {
	registered_items = registered,
	registered_nodes = registered,
	get_item_group = group_of,
	get_modpath = function(name) return repo .. "/" .. MODS[name] end,
	get_current_modname = function() return current_mod end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_on_joinplayer = function(fn) loaded.join = fn end,
	register_on_leaveplayer = function() end,
	register_on_player_receive_fields = function() end,
	register_globalstep = function() end,
	register_lbm = function() end,
	register_craft = function(def) engine_crafts[#engine_crafts + 1] = def end,
	register_craftitem = function(name, def)
		def.groups = def.groups or {}
		registered[name] = def
	end,
	register_node = function(name, def)
		name = name:gsub("^:", "")
		def.groups = def.groups or {}
		registered[name] = def
	end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do registered[name][key] = value end
	end,
	log = function() end,
	chat_send_player = function() end,
	formspec_escape = function(text) return text end,
}
_G.ItemStack = function(value)
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
	return {get_name = function() return name end,
		get_count = function() return tonumber(count) or 1 end}
end
_G.default = setmetatable({}, {__index = function() return function() return {} end end})
_G.grug_core = {settlement_socket_settlements = function() return {} end}
_G.grug_xp = {get_level = function() return 60 end}
_G.grug_sounds = {play = function() end}
_G.grug_inventory = {refresh = function() end}
_G.sfinv = {override_page = function() end}

-- Every item a catalog names, with the groups the base catalog dumped.
for token, members in pairs(corpus.groups) do
	local group = token:match("^group:([%w_]+)$")
	for _, name in ipairs(members) do
		if not name:match("^grug_artisans:") then
			registered[name] = registered[name] or {groups = {}}
			if group then registered[name].groups[group] = 1 end
		end
	end
end
-- grug_artisans registers its own items and refuses a second registration.
local function ensure(name)
	if name ~= "" and not name:match("^group:") and not name:match("^grug_artisans:") and
			not registered[name] then
		registered[name] = {groups = {}}
	end
end
for _, route in ipairs(corpus.engine) do
	ensure(route.output)
	for _, item in ipairs(route.items) do ensure(item) end
end
for _, row in ipairs(corpus.registry) do
	ensure(row.output_name)
	for _, item in ipairs(row.flat_inputs or {}) do ensure(item) end
end
for output, gear in pairs(corpus.gear) do
	registered[output]._grug_bracket = gear.bracket
end

------------------------------------------------------------------------------
-- R: the registry under test, first with synthetic records.
------------------------------------------------------------------------------
_G.grug_jobs = {}
current_mod = "grug_jobs"
dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
local J = grug_jobs

local list = J.ingredient_list({{"a:x", "group:wood", ""}, {"a:x", "", "a:y"}})
eq(#list, 3, "R ingredient_list: three distinct tokens")
check(list[1].item == "a:x" and list[1].n == 2 and list[2].group == "wood" and
	list[2].n == 1 and list[3].item == "a:y", "R ingredient_list counts in first-seen order")

J.register_ingredient_tier("t:bar1", 1)
J.register_ingredient_tier("t:bar2", 2)
local synthetic = J.register_recipe({area = "weaponsmith", tier = 1, output = "t:sword",
	ingredients = {{item = "t:bar1", n = 2}, {group = "stick", n = 1}}, time = 3,
	station = "forge"})
local keys = {}
for key in pairs(synthetic) do keys[#keys + 1] = key end
table.sort(keys)
eq(table.concat(keys, ","), "area,count,id,ingredients,output,profession,progress," ..
	"station,tier,time", "R a record has exactly the plan's fields")
eq(synthetic.id, "t:sword|group:stick*1+t:bar1*2", "R the default id: output and sorted ingredients")
check(synthetic.profession == "weaponsmith" and synthetic.count == 1 and
	synthetic.progress == true, "R defaults: the area's profession, one item, XP")
eq(J.recipe(synthetic.id), synthetic, "R recipe(id)")
eq(J.recipes_for_output("t:sword")[1], synthetic, "R recipes_for_output")
eq(J.recipes_for_output(ItemStack("t:sword 3"))[1], synthetic, "R recipes_for_output takes a stack")
eq(J.recipes_in_area("weaponsmith")[1], synthetic, "R recipes_in_area")
local function bad(fields)
	local def = {area = "weaponsmith", tier = 1, output = "t:bad", time = 3,
		ingredients = {{item = "t:bar1", n = 1}}}
	for key, value in pairs(fields) do
		if value == "nil" then def[key] = nil else def[key] = value end
	end
	return function() J.register_recipe(def) end
end
refused(bad({area = "grid"}), "R an unknown area is refused")
refused(bad({station = "tailor_bench"}), "R another profession's station is refused")
refused(bad({tier = "nil"}), "R a profession recipe without a tier is refused")
refused(bad({time = "nil"}), "R a profession recipe without a time is refused")
refused(bad({area = "basic", tier = "nil", progress = true}), "R Basic gives no XP")
refused(bad({area = "basic", tier = "nil", station = "forge"}), "R Basic needs no station")
refused(bad({profession = "armorsmith"}), "R a profession other than the area's is refused")
refused(bad({output = "t:sword", ingredients = {{item = "t:bar1", n = 2},
	{group = "stick", n = 1}}}), "R a duplicate id is refused")
refused(bad({ingredients = {{item = "t:bar2", n = 1}}}), "R a higher-tier ingredient is refused")
refused(bad({ingredients = {{group = "stick", n = 1}}}),
	"R a recipe without an ingredient of its tier is refused")
refused(bad({ingredients = {{item = "t:bar1", n = 1}, {item = "t:bar1", n = 1}}}),
	"R an ingredient listed twice is refused")
refused(bad({ingredients = {{item = "t:bar1", n = 0}}}), "R a count below one is refused")
refused(bad({ingredients = {{item = "t:bar1", group = "wood", n = 1}}}),
	"R an entry with both item and group is refused")
refused(bad({count = 1.5}), "R a fractional output count is refused")
refused(bad({material = true}), "R a material whose output is no ingredient of its tier is refused")
check(pcall(bad({area = "basic", tier = "nil", time = "nil", output = "t:plank"})),
	"R a Basic record takes the Basic time")
eq(J.recipes_for_output("t:plank")[1].time, 1, "R ...of 1 s")

------------------------------------------------------------------------------
-- The real catalogs.
------------------------------------------------------------------------------
-- A fresh registry: the synthetic one's load callbacks go with it.
for index = #loaded, 1, -1 do loaded[index] = nil end
_G.grug_jobs = {}
J = nil
dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
J = grug_jobs
J.register_basic_catalog(dofile(repo .. "/mods/PLAYER/grug_jobs/basic_recipes.lua"))
dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
-- station_nodes.lua: the station recipes (workspaces.lua is not needed here).
local real_dofile = dofile
dofile = function(path)
	if path:match("/workspaces%.lua$") then return {} end
	if path:match("/station_visuals%.lua$") then return {} end
	return real_dofile(path)
end
real_dofile(repo .. "/mods/PLAYER/grug_jobs/station_nodes.lua").install_jobs(J)

-- grug_professions and grug_artisans under stubs; their station operations
-- (enchants, upgrades) are not this lane's: enchants.lua only yields the
-- family owners it declares.
local loot = {}
for object in read("mods/ENTITIES/grug_mobs/data/items.json"):gmatch("%b{}") do
	local id = object:match('"id"%s*:%s*"([^"]+)"')
	local tier = tonumber(object:match('"tier"%s*:%s*(%d+)'))
	if id and tier and object:match('"kind"%s*:%s*"signature"') then loot[id] = tier end
end
_G.grug_mobs = {loot_item_tiers = loot}
_G.grug_traders = {register_all_vendor_stock = function() end}
_G.grug_gear = {}
do
	local text = read("mods/ITEMS/grug_gear/init.lua")
	grug_gear.MATERIALS = assert(loadstring("return " ..
		text:match("grug_gear%.MATERIALS = (%b{})")))()
	grug_gear.BRACKET_TINT = {"#1", "#2", "#3", "#4", "#5", "#6"}
	grug_gear.trinket_item = function(identity, tier)
		return "grug_gear:" .. identity .. "_t" .. tier
	end
end
-- The base engine's family of every gear output; trinkets are the Goldsmith's.
_G.grug_items = {
	family_for = function(stack)
		local name = stack:get_name()
		if corpus.gear[name] then return corpus.gear[name].family end
		if name:match("^grug_gear:[%w_]+_t%d$") then return "trinket" end
		return nil
	end,
	mastery_band = function() return 1 end,
}
do
	local env = setmetatable({grug_materials = {},
		core = {get_modpath = function() return nil end}}, {__index = _G})
	local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
	setfenv(chunk, env)
	chunk()
	_G.grug_materials = env.grug_materials
	grug_materials.register_on_harvest = function() end
end
local owners_text = read("mods/ITEMS/grug_professions/enchants.lua")
local owners = assert(loadstring("return " ..
	owners_text:match("P%.FAMILY_OWNERS = (%b{})")))()
dofile = function(path)
	if path:match("/station_operations%.lua$") then return end
	if path:match("grug_professions/enchants%.lua$") then
		grug_professions.FAMILY_OWNERS = owners
		return
	end
	if path:match("grug_artisans/enchants%.lua$") then return end
	return real_dofile(path)
end
current_mod = "grug_professions"
real_dofile(repo .. "/mods/ITEMS/grug_professions/init.lua")
current_mod = "grug_artisans"
real_dofile(repo .. "/mods/ITEMS/grug_artisans/init.lua")
dofile = real_dofile
for _, fn in ipairs(loaded) do fn() end
for _, def in ipairs(engine_crafts) do
	check(def.type == "cooking" or def.type == "fuel",
		"the catalogs register no grid craft (" .. tostring(def.output) .. ")")
end

------------------------------------------------------------------------------
-- C: the conversion.
------------------------------------------------------------------------------
local function signature_of(tokens)
	local counts = {}
	for _, token in ipairs(tokens) do
		if token ~= "" then counts[token] = (counts[token] or 0) + 1 end
	end
	local keys = {}
	for token, n in pairs(counts) do keys[#keys + 1] = token .. "*" .. n end
	table.sort(keys)
	return table.concat(keys, "+")
end
local function record_signature(recipe)
	local keys = {}
	for _, entry in ipairs(recipe.ingredients) do
		keys[#keys + 1] = J.ingredient_token(entry) .. "*" .. entry.n
	end
	table.sort(keys)
	return table.concat(keys, "+")
end
local function resolve(token)
	if token:match("^group:.+,") then return corpus.groups[token][1] end
	return token
end
-- The routes this fixture does not load: Cooking and Alchemy.
local function elsewhere(output)
	return output:match("^grug_cooking:") or output:match("^grug_alchemy:") or
		output == "grug_brewing:brewing_stand"
end
local by_key, matched = {}, {}
for _, recipe in ipairs(J.recipes) do
	by_key[recipe.output .. "|" .. record_signature(recipe) .. "|" .. recipe.count] = recipe
end
local converted, routes, dropped = 0, 0, 0
for _, route in ipairs(corpus.engine) do
	if route.output ~= "" and not elsewhere(route.output) then
		routes = routes + 1
		if route.output == "default:book_written" then
			dropped = dropped + 1
			eq(#J.recipes_for_output(route.output), 0, "C the written-book copy is dropped")
		else
			local tokens = {}
			for index, token in ipairs(route.items) do tokens[index] = resolve(token) end
			local key = route.output .. "|" .. signature_of(tokens) .. "|" .. route.count
			local recipe = by_key[key]
			if check(recipe ~= nil, "C " .. key .. " has its record") then
				converted = converted + 1
				matched[recipe] = true
				local gear = corpus.gear[route.output]
				if gear then
					eq(recipe.profession, grug_professions.family_owner(gear.family),
						"C gear " .. route.output .. " belongs to its family's owner")
				end
			end
		end
	end
end
print(("conversion: %d grid routes of the base catalog, %d converted, %d dropped"):format(
	routes, converted, dropped))
for _, recipe in ipairs(J.recipes_in_area("basic")) do
	check(matched[recipe], "C Basic " .. recipe.id .. " comes from a grid route")
end
-- The old registry's bench recipes (tailor, tanning rack, jeweller's bench).
for _, row in ipairs(corpus.registry) do
	if row.station ~= "grid" and row.station ~= "furnace" and
			row.station ~= "brewing_stand" then
		local key = row.output_name .. "|" .. signature_of(row.flat_inputs) .. "|1"
		local recipe = by_key[key]
		if check(recipe ~= nil, "C bench recipe " .. key .. " has its record") then
			check(recipe.profession == row.profession and recipe.tier == row.tier and
				recipe.station == row.station,
				"C " .. row.output_name .. " keeps its profession, tier and station")
		end
	end
end
do
	local saved = arg
	_G.arg = {repo, "--check"}
	local ok, message = pcall(dofile, repo .. "/tools/r45_rg/gen_basic_recipes.lua")
	_G.arg = saved
	check(ok, "C basic_recipes.lua is current with its generator (" .. tostring(message) .. ")")
end

------------------------------------------------------------------------------
-- G: gear in its profession.
------------------------------------------------------------------------------
local gear_records = 0
for output, gear in pairs(corpus.gear) do
	local list_for = J.recipes_for_output(output)
	check(#list_for > 0, "G " .. output .. " has a recipe")
	for _, recipe in ipairs(list_for) do
		gear_records = gear_records + 1
		local owner = grug_professions.family_owner(gear.family)
		check(recipe.area == owner and recipe.tier == gear.bracket and
			recipe.station == J.PROFESSION_STATIONS[owner] and recipe.time == 3 and
			recipe.progress == true,
			("G %s: %s T%d at the %s, 3 s, XP (got %s T%s %s %ss)"):format(output,
				tostring(owner), gear.bracket, tostring(J.PROFESSION_STATIONS[owner]),
				recipe.area, tostring(recipe.tier), tostring(recipe.station), recipe.time))
	end
end
eq(gear_records, 132, "G 132 gear records (138 grid routes, the mirrored bows merged)")
for _, output in ipairs({"grug_gear:arrow", "grug_materials:pick_bronze",
		"grug_materials:axe_steel", "grug_professions:metal_rod_iron", "default:stick",
		"grug_farming:hoe", "grug_professions:bolt_patch", "grug_mobs:light_leather",
		"grug_artisans:seasoned_wood", "grug_professions:thread"}) do
	local list_for = J.recipes_for_output(output)
	check(#list_for > 0, "G " .. output .. " has a recipe")
	for _, recipe in ipairs(list_for) do
		eq(recipe.area, "basic", "G " .. output .. " stays Basic")
	end
end
local trinkets = 0
for _, recipe in ipairs(J.recipes_in_area("goldsmith")) do
	if recipe.output:match("_t%d$") then
		trinkets = trinkets + 1
		check(recipe.time == 3 and recipe.progress and recipe.station == "jewellers_bench",
			"G trinket " .. recipe.output .. " is Goldsmith gear at the bench")
	end
end
eq(trinkets, 36, "G 36 trinkets")
for _, area in ipairs({"basic", "cooking", "alchemist"}) do
	for _, recipe in ipairs(J.recipes_in_area(area)) do
		check(not corpus.gear[recipe.output], "G no gear in " .. area .. ": " .. recipe.output)
	end
end

------------------------------------------------------------------------------
-- D: durations and stations.
------------------------------------------------------------------------------
local STATION_NODES = {["grug_jobs:forge"] = true, ["grug_jobs:tanning_rack"] = true,
	["grug_jobs:tailor_bench"] = true, ["grug_jobs:carving_bench"] = true,
	["grug_jobs:jewellers_bench"] = true}
local seen_areas = {}
for _, recipe in ipairs(J.recipes) do
	seen_areas[recipe.area] = true
	local label = "D " .. recipe.id
	check(recipe.mastery_required == nil, label .. " has no mastery band")
	if recipe.area == "basic" then
		check(recipe.time == 1 and recipe.station == nil and recipe.progress == false and
			recipe.profession == nil, label .. ": Basic, 1 s, no station, no XP")
		check(type(recipe.tier) == "number", label .. " has its inferred tier")
	elseif STATION_NODES[recipe.output] then
		check(recipe.time == 1 and recipe.station == nil and recipe.progress == false and
			recipe.tier == 3, label .. ": a station node, T3, 1 s, no station, no XP")
	else
		eq(recipe.station, J.PROFESSION_STATIONS[recipe.area], label .. " needs its station")
		local bag = recipe.output:match("^grug_inventory:bag_")
		local material = (recipe.output:match("^grug_artisans:setting_") or
			recipe.output:match("^grug_materials:cut_") or
			recipe.output:match("_bolt_bundle$")) and true
		if material then
			check(recipe.time == 1 and recipe.progress == false, label .. ": an intermediate, 1 s, no XP")
		elseif bag then
			check(recipe.time == 3 and recipe.progress == true, label .. ": a bag, 3 s, XP")
		else
			check(recipe.time == 3 and recipe.progress == true, label .. ": gear, 3 s, XP")
		end
	end
end
for _, area in ipairs({"basic", "weaponsmith", "armorsmith", "tailor", "leatherworker",
		"woodcarver", "goldsmith"}) do
	check(seen_areas[area], "D the " .. area .. " area has recipes")
end
-- The area order: tier, then the description, then id.
local ordered = J.recipes_in_area("basic")
local in_order = true
for index = 2, #ordered do
	if ordered[index - 1].tier > ordered[index].tier then in_order = false end
end
check(in_order, "D the Basic area is ordered by tier")
eq(J.recipes_for_output("grug_materials:pick_steel")[1].tier, 3,
	"D a Basic steel pick takes its bar's tier")

------------------------------------------------------------------------------
-- K: the craft list at a join.
------------------------------------------------------------------------------
do
	dofile(repo .. "/mods/PLAYER/grug_jobs/craft_list.lua")
	local join = assert(loaded.join, "craft_list.lua registers a join callback")
	local function player(size, empty)
		local inv = {size = size}
		function inv:get_size() return self.size end
		function inv:is_empty() return empty end
		function inv:set_size(_, value) self.size = value end
		return {get_inventory = function() return inv end}, inv
	end
	local p, inv = player(9, true)
	join(p)
	eq(inv.size, 0, "K an empty craft list shrinks to 0")
	p, inv = player(9, false)
	join(p)
	eq(inv.size, 9, "K a craft list that holds a stack keeps its size")
	p, inv = player(0, true)
	inv.set_size = function() error("set again") end
	check(pcall(join, p), "K a size-0 list is left alone")
end

------------------------------------------------------------------------------
-- X: removed things.
------------------------------------------------------------------------------
do
	local REMOVED = {"recipe_for_craft", "open_book", "station_book_button",
		"refresh_open_book", "book_records", "book_formspec", "discovery_seen",
		"mark_seen", "recipe_discovered", "_scan_discovery", "basics_presentation",
		"basics_routes", "validate_recipe_collisions", "register_station(",
		"station_handler", "recipe_progress_unlocked", "automatic_take_sound",
		"_shaped_inputs_match", "_inputs_match", "mastery_required",
		"grug_jobs.close_to_origin"}
	-- The vendored default and sfinv keep their crafting-grid page and form;
	-- grug_jobs overrides the page (ui.lua) and no grug_ file draws the grid.
	local GRID = {"craftpreview", "list[current_player;craft"}
	-- The file list comes from find(1), as in tools/r44_pp (a tool, not game
	-- code: check_lua's sweep 5 names the io.popen).
	local pipe = assert(io.popen("cd '" .. repo .. "' && find mods -name '*.lua' | sort"))
	local files = 0
	local readers = {}
	for path in pipe:lines() do
		files = files + 1
		local text = read(path)
		for _, needle in ipairs(REMOVED) do
			check(not text:find(needle, 1, true), path .. " names removed " .. needle)
		end
		if not path:match("^mods/BASE/") then
			for _, needle in ipairs(GRID) do
				check(not text:find(needle, 1, true), path .. " draws the craft grid: " .. needle)
			end
		end
		if text:find("get_all_craft_recipes", 1, true) then readers[#readers + 1] = path end
		check(not text:find('method = "normal"', 1, true) and
			not text:find('method="normal"', 1, true),
			path .. " asks the engine for no grid recipe")
	end
	pipe:close()
	check(files > 400, "every shipped Lua file was scanned (" .. files .. ")")
	eq(table.concat(readers, " "), "mods/ENTITIES/grug_traders/prices.lua " ..
		"mods/ITEMS/grug_materials/content_curation.lua",
		"only the price module (cooking) and the curation clears list engine recipes")
	for _, path in ipairs({"stations.lua", "discovery.lua", "basics_routes.lua",
			"basics_presentation.lua"}) do
		check(io.open(repo .. "/mods/PLAYER/grug_jobs/" .. path) == nil,
			"grug_jobs/" .. path .. " is gone")
	end
end

print(("R45 RG PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("R45 RG PORTABLE FAIL", 0) end
