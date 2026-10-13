-- Round 47 lane AN portable fixture (LuaJIT): Anthracite (round47-plan.md
-- §3, §4.6; rulings 8-13 and 17).
--
--   luajit tools/r47_an/portable_test.lua REPO
--
-- Runs the shipped files against small engine stubs:
--   A. the ore: the Anthracite resource row (harvest tier 2, its own node
--      and item, not in the coal group) and its registered node (level of
--      its tier, drop); the WP40 rows: no Coal below T2, Anthracite from T2
--      and never rarer than Iron from T3 down;
--   B. Steel = Iron Bar + Anthracite and nothing else (no Coal, no
--      Charcoal), every alloy 10 s as a bar, and the startup audit passing
--      (and failing when Anthracite joins the coal group);
--   C. furnace fuel: Coal and Charcoal 80 s, Anthracite 120 s, wood 15 s;
--   D. the Claim Stone (ruling 12): the cap in time (99 lumps' worth),
--      Anthracite 1.5 lumps, a piece only when its whole time fits, lumps
--      as before, existing paid_until values read unchanged, the pick-up
--      refund in Charcoal;
--   E. the Anthracite torch: floor, wall and ceiling nodes, light 14,
--      torch = 1, drops, flood, placement; its Basic recipe row;
--   F. the enchant inputs: T2 Coal inputs are group:coal, T3 Anthracite,
--      and a group token counts as registered when a member exists.
-- Prints "R47 AN PORTABLE PASS checks=<n>" or raises.
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if ok then print("ok   " .. label) else failures = failures + 1; print("FAIL " .. label) end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", want " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- ---------------------------------------------------------------------------
-- Engine stubs
-- ---------------------------------------------------------------------------
local stack_mt = {}
stack_mt.__index = stack_mt
function ItemStack(value)
	if type(value) == "table" then return value end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)$")
	return setmetatable({name = name or "", count = tonumber(count) or
		((name or "") ~= "" and 1 or 0)}, stack_mt)
end
function stack_mt:get_name() return self.name end
function stack_mt:get_count() return self.count end
function stack_mt:is_empty() return self.name == "" or self.count <= 0 end
function stack_mt:set_name(name) self.name = name end

local groups_of = {} -- item -> groups
local nodes, items, crafts, loaded_callbacks = {}, {}, {}, {}
local added_items = {}
core = {
	registered_nodes = nodes, registered_items = items,
	get_modpath = function(mod)
		if mod == "grug_housing" then return repo .. "/mods/PLAYER/grug_housing" end
		return nil
	end,
	log = function() end,
	register_node = function(name, def)
		def.name = name
		nodes[name], items[name] = def, def
		groups_of[name] = def.groups or {}
	end,
	register_craftitem = function(name, def)
		def.name = name
		items[name] = def
		groups_of[name] = def.groups or {}
	end,
	register_craft = function(def) crafts[#crafts + 1] = def end,
	register_on_mods_loaded = function(fn) loaded_callbacks[#loaded_callbacks + 1] = fn end,
	get_item_group = function(name, group)
		return (groups_of[name] or {})[group] or 0
	end,
	get_craft_result = function(input)
		local name = input.items[1]:get_name()
		for _, craft in ipairs(crafts) do
			if craft.type == "cooking" and craft.recipe == name then
				return {time = craft.cooktime, item = ItemStack(craft.output)}
			end
		end
		return {time = 0, item = ItemStack("")}
	end,
	add_item = function(pos, stack) added_items[#added_items + 1] = ItemStack(stack) end,
	get_node = function() return {name = "default:stone"} end,
	get_node_or_nil = function() return nil end,
	load_area = function() end,
	dir_to_wallmounted = function(dir)
		if dir.y > 0 then return 0 elseif dir.y < 0 then return 1 end
		return 2
	end,
}
vector = {subtract = function(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end}
table.copy = table.copy or function(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end
default = {
	node_sound_stone_defaults = function() return {} end,
	node_sound_wood_defaults = function() return {} end,
	node_sound_metal_defaults = function() return {} end,
	node_sound_glass_defaults = function() return {} end,
	register_mesepost = function() end,
	LIGHT_MAX = 14,
}
-- default's coal lump and a tree, as the vendored mod registers them.
core.register_craftitem("default:coal_lump", {description = "Coal Lump",
	groups = {coal = 1, flammable = 1}})
core.register_node("default:tree", {description = "Apple Tree", groups = {tree = 1}})

-- ---------------------------------------------------------------------------
-- A. The ore
-- ---------------------------------------------------------------------------
grug_materials = {}
dofile(repo .. "/mods/ITEMS/grug_materials/registry.lua")
-- ores.lua names one helper of mining.lua.
grug_materials.resource_ore_description = function(resource)
	return resource.name .. " Ore\nRequires a T" .. resource.harvest_tier .. " pick"
end
dofile(repo .. "/mods/ITEMS/grug_materials/ores.lua")
local M = grug_materials
local anthracite = M.RESOURCE_BY_KEY.anthracite
check(anthracite ~= nil, "A Anthracite is a resource row")
eq(anthracite.harvest_tier, 2, "A Anthracite needs the Iron pick (harvest tier 2)")
eq(anthracite.raw_item, "grug_materials:anthracite", "A the item")
eq(anthracite.natural_node, "grug_materials:stone_with_anthracite", "A the ore node")
local ore = nodes[anthracite.natural_node]
check(ore ~= nil, "A the ore node is registered")
eq(ore and ore.groups.grug_resource, 2, "A ore resource tier 2")
eq(ore and ore.groups.level, M.level_for_tier(2), "A ore level is its tier's level")
eq(ore and ore.groups.grug_natural, 1, "A ore is natural")
eq(ore and ore.drop, "grug_materials:anthracite", "A ore drops Anthracite")
check(items["grug_materials:anthracite"] ~= nil, "A the item is registered")
eq(core.get_item_group("grug_materials:anthracite", "coal"), 0,
	"A Anthracite is not in the coal group (ruling 9)")
eq(M.RESOURCE_BY_KEY.coal.harvest_tier, 1, "A Coal stays any pick")

local rows = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua")().resources
local denominators = {}
for _, row in ipairs(rows) do denominators[row.key] = row.denominators end
local coal, anth, iron = denominators.coal, denominators.anthracite, denominators.iron
eq(coal[1], 64, "A Coal T1 64")
eq(coal[2], 128, "A Coal T2 128")
for tier = 3, 6 do eq(coal[tier], false, "A no Coal in T" .. tier .. " (below y -300)") end
eq(anth[1], false, "A no Anthracite in T1")
eq(anth[2], 256, "A Anthracite T2 256")
eq(anth[3], 96, "A Anthracite T3 96")
for tier = 4, 6 do eq(anth[tier], 128, "A Anthracite T" .. tier .. " 128") end
for tier = 3, 6 do
	check(anth[tier] <= iron[tier], "A T" .. tier .. ": Anthracite (1/" .. anth[tier] ..
		") never rarer than Iron (1/" .. iron[tier] .. ")")
end

-- ---------------------------------------------------------------------------
-- B. Steel and the alloy times
-- ---------------------------------------------------------------------------
-- The recipe registry for the audit: the Basic catalog, as registry.lua
-- registers it.
local basic = dofile(repo .. "/mods/PLAYER/grug_jobs/basic_recipes.lua").recipes
grug_jobs = {recipes_for_output = function(output)
	local out = {}
	for _, row in ipairs(basic) do
		if row.output == output then
			out[#out + 1] = {area = "basic", count = row.count, ingredients = row.ingredients}
		end
	end
	return out
end}
-- Every name the audit asks about counts as registered (the engine's
-- registration is not under test here).
setmetatable(items, {__index = function(_, name)
	if type(name) == "string" and name:match("^[%w_]+:[%w_]+$") then return {} end
end})
grug_smelting = {}
dofile(repo .. "/mods/ITEMS/grug_smelting/alloys.lua")
grug_smelting.NODE = "grug_smelting:dual_furnace" -- node.lua's name
dofile(repo .. "/mods/ITEMS/grug_smelting/recipes.lua")
local S = grug_smelting
local steel = S.recipe_for("grug_materials:steel_bar")
check(steel ~= nil, "B Steel is an alloy")
eq(steel and steel.inputs[1], "grug_materials:iron_bar", "B Steel input 1: Iron Bar")
eq(steel and steel.inputs[2], "grug_materials:anthracite", "B Steel input 2: Anthracite")
eq(S.match("grug_materials:anthracite", "grug_materials:iron_bar"), steel,
	"B Anthracite + Iron Bar in either order")
eq(S.match("grug_materials:iron_bar", "default:coal_lump"), nil, "B no Coal Steel")
eq(S.match("grug_materials:iron_bar", "grug_smelting:charcoal"), nil, "B no Charcoal Steel")
eq(S.match("grug_materials:iron_bar", ""), nil, "B a lone Iron Bar makes nothing")
eq(#S.RECIPES, 5, "B five alloys")
for _, recipe in ipairs(S.RECIPES) do
	eq(recipe.time, 10, "B " .. recipe.output .. " takes 10 s (ruling 17)")
end
for _, craft in ipairs(crafts) do
	if craft.type == "cooking" then eq(craft.cooktime, 10, "B cooking " .. craft.output .. " 10 s") end
end
eq(core.get_item_group("grug_smelting:charcoal", "coal"), 1, "B Charcoal stays in the coal group")
local audit_ok, audit_err = pcall(loaded_callbacks[#loaded_callbacks])
check(audit_ok, "B the smelting startup audit passes (" .. tostring(audit_err) .. ")")
groups_of["grug_materials:anthracite"] = {coal = 1}
local bad_ok, bad_err = pcall(loaded_callbacks[#loaded_callbacks])
check(not bad_ok and tostring(bad_err):find("Anthracite is in the coal group", 1, true),
	"B the audit fails when Anthracite joins the coal group")
groups_of["grug_materials:anthracite"] = {}

-- ---------------------------------------------------------------------------
-- C. Furnace fuel
-- ---------------------------------------------------------------------------
local automatic = dofile(repo .. "/mods/PLAYER/grug_jobs/automatic.lua")
for _, station in ipairs({"furnace", "dual_furnace"}) do
	eq(automatic.fuel_time(station, ItemStack("default:coal_lump")), 80, "C " .. station .. " Coal 80 s")
	eq(automatic.fuel_time(station, ItemStack("grug_smelting:charcoal")), 80,
		"C " .. station .. " Charcoal 80 s")
	eq(automatic.fuel_time(station, ItemStack("grug_materials:anthracite")), 120,
		"C " .. station .. " Anthracite 120 s (ruling 11)")
	eq(automatic.fuel_time(station, ItemStack("default:tree")), 15, "C " .. station .. " a log 15 s")
	eq(automatic.fuel_time(station, ItemStack("default:coalblock")), 0, "C " .. station .. " no Coal Block")
end

-- ---------------------------------------------------------------------------
-- D. The Claim Stone
-- ---------------------------------------------------------------------------
local data = {}
local storage = {
	get_string = function(key) return data[key] or "" end,
	set_string = function(key, value) data[key] = value ~= "" and value or nil end,
	keys = function()
		local keys = {}
		for key in pairs(data) do keys[#keys + 1] = key end
		return keys
	end,
}
local clock = 1800000000
local factory = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
local L = 26160
-- A claim as an earlier version saved it: activated long ago, 50 lumps left.
data["next_id"] = "2"
data["claim:1"] = table.concat({"v2", "owner", 0, 10, 0, clock - 100000, clock - 90000,
	clock + 50 * L, clock - 90000, ""}, "|")
data["player:owner"] = "v2|placed|1"
local model = factory({storage = storage, now = function() return clock end})
model.load()
local claim = model.claim_by_id(1)
check(claim ~= nil and model.is_active(claim), "D an existing claim loads active")
eq(model.remaining_seconds(claim), 50 * L, "D its paid_until reads unchanged")
eq(model.FUEL_CAP_SECONDS, 99 * L, "D the cap is 99 lumps' worth of time")
local A = L * 3 / 2
eq(model.fuel_room(claim), 49, "D lumps: room 49 (as before)")
eq(model.fuel_room(claim, A), 32, "D Anthracite: room 32 whole pieces (49 lumps / 1.5)")
eq(model.add_fuel(claim, 40, A), 32, "D 40 Anthracite: 32 go in")
eq(model.remaining_seconds(claim), 50 * L + 32 * A, "D 32 pieces add 48 lumps' worth")
eq(model.fuel_room(claim, A), 0, "D one lump's worth left: no whole Anthracite fits")
eq(model.add_fuel(claim, 1, A), 0, "D the fit refusal: Anthracite does not go in")
eq(model.fuel_room(claim), 1, "D but one lump still fits")
eq(model.add_fuel(claim, 3), 1, "D one lump goes in")
eq(model.remaining_seconds(claim), model.FUEL_CAP_SECONDS, "D full at the cap")
eq(model.add_fuel(claim, 1), 0, "D full: no lump")
clock = clock + L / 2
eq(model.fuel_room(claim), 0, "D half a lump burnt: still no lump room (as before)")
clock = clock + A - L / 2
eq(model.fuel_room(claim, A), 1, "D 1.5 lumps burnt: one Anthracite fits")
eq(model.refund_lumps(claim), 97, "D refund: whole lumps of the remaining time")

-- The housing api: fuel kinds, per-item seconds, pick-up refund.
grug_housing = {}
grug_core = {map_reset = {clear = function() end}}
local given = {}
grug_inventory = {
	fits = function() return true end,
	give = function(_, stack) given[#given + 1] = ItemStack(stack) return ItemStack("") end,
}
-- The api's own storage holds a claim as an earlier version saved it: 10
-- lumps and 100 s left (wall clock).
local now = os.time()
local api_store = {
	next_id = "2",
	["claim:1"] = table.concat({"v2", "owner", 0, 10, 0, now - 100000, now - 90000,
		now + 10 * L + 100, now - 90000, ""}, "|"),
	["player:owner"] = "v2|placed|1",
}
core.get_mod_storage = function()
	return {get_string = function(_, key) return api_store[key] or "" end,
		set_string = function(_, key, value) api_store[key] = value ~= "" and value or nil end,
		get_keys = function() local keys = {} for key in pairs(api_store) do keys[#keys + 1] = key end
			return keys end}
end
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
local H = grug_housing
check(H.is_fuel("grug_materials:anthracite") and H.is_fuel("default:coal_lump") and
	H.is_fuel("grug_smelting:charcoal") and not H.is_fuel("default:coalblock"),
	"D fuel kinds: Coal, Charcoal, Anthracite; no Coal Block")
eq(H.fuel_seconds("grug_materials:anthracite"), 39240, "D Anthracite burns 10 h 54 min")
eq(H.fuel_seconds("default:coal_lump"), L, "D a lump 7 h 16 min")
eq(H.fuel_seconds("default:coalblock"), 0, "D a Coal Block burns nothing")
eq(H.FUEL_CAP_SECONDS, 99 * L, "D the api publishes the cap")
local live = H.model.claim_by_id(1)
check(live ~= nil and H.is_active(live), "D the saved claim loads through the api")
local room = H.fuel_room_seconds(live)
check(room >= 89 * L - 101 and room <= 89 * L - 99, "D room in seconds: 89 lumps' worth")
eq(H.add_fuel(live, 100, "grug_materials:anthracite"), 59,
	"D api: 59 whole Anthracite fit after 10 lumps")
eq(H.add_fuel(live, 5, "grug_materials:anthracite"), 0, "D api: the next one does not fit")
eq(H.add_fuel(live, 5, "default:coal_lump"), 0, "D api: nor a lump (98.5 lumps' worth)")
-- Pick-up: the remaining time comes back as whole Charcoal lumps.
items["grug_smelting:charcoal"] = {}
local player = {is_player = function() return true end,
	get_player_name = function() return "owner" end,
	get_pos = function() return {x = 0, y = 11, z = 0} end}
local ok, message = H.pick_up(player)
check(ok, "D pick-up allowed (" .. tostring(message) .. ")")
local refund
for _, stack in ipairs(given) do
	if stack:get_name() == "grug_smelting:charcoal" then refund = stack:get_count() end
end
eq(refund, 98, "D refund: 98 Charcoal for 98.5 lumps' worth")

-- ---------------------------------------------------------------------------
-- E. The Anthracite torch
-- ---------------------------------------------------------------------------
dofile(repo .. "/mods/ITEMS/grug_materials/torch.lua")
local T = M.ANTHRACITE_TORCH
local floor, wall, ceiling = nodes[T.floor], nodes[T.wall], nodes[T.ceiling]
check(floor and wall and ceiling, "E three torch nodes")
for label, def in pairs({floor = floor, wall = wall, ceiling = ceiling}) do
	eq(def.light_source, 14, "E " .. label .. " light 14")
	eq(def.groups.torch, 1, "E " .. label .. " torch = 1")
	eq(def.groups.attached_node, 1, "E " .. label .. " attached")
	eq(def.groups.dig_immediate, 3, "E " .. label .. " digs at once")
	eq(def.drop, T.floor, "E " .. label .. " drops the torch")
	eq(def.paramtype2, "wallmounted", "E " .. label .. " wallmounted")
	eq(def.walkable, false, "E " .. label .. " not walkable")
	eq(def.floodable, true, "E " .. label .. " floodable")
	added_items = {}
	eq(def.on_flood({x = 0, y = 0, z = 0}, {name = def.name}, {name = "default:water_flowing"}),
		false, "E " .. label .. " a flood removes it")
	eq(added_items[1] and added_items[1]:get_name(), T.floor, "E " .. label .. " a flood drops the torch")
end
eq(floor.mesh, "torch_floor.obj", "E floor mesh")
eq(wall.mesh, "torch_wall.obj", "E wall mesh")
eq(ceiling.mesh, "torch_ceiling.obj", "E ceiling mesh")
eq(wall.groups.not_in_creative_inventory, 1, "E the wall form is hidden")
eq(floor.description, "Anthracite Torch", "E the name")
check(T.light > 12, "E brighter than the Coal torch (12)")
-- Placement: the vendored rule picks the form by the pointed face.
local placed
core.item_place = function(stack, placer, pointed, wdir)
	placed = {name = stack:get_name(), wdir = wdir}
	return stack
end
local function place(under, above)
	local stack = floor.on_place(ItemStack(T.floor), nil, {under = under, above = above})
	return placed.name, stack:get_name()
end
local name, back = place({x = 0, y = 0, z = 0}, {x = 0, y = 1, z = 0})
eq(name, T.floor, "E on the floor: the floor form")
eq(back, T.floor, "E the stack keeps the torch name")
eq((place({x = 0, y = 1, z = 0}, {x = 0, y = 0, z = 0})), T.ceiling, "E under a ceiling: the ceiling form")
eq((place({x = 1, y = 0, z = 0}, {x = 0, y = 0, z = 0})), T.wall, "E on a wall: the wall form")
-- The Basic recipe row.
local torch_rows = 0
for _, row in ipairs(basic) do
	if row.output == T.floor then
		torch_rows = torch_rows + 1
		eq(row.count, 10, "E 10 torches per craft")
		eq(#row.ingredients, 2, "E two ingredients")
		eq(row.ingredients[1].item, "grug_materials:anthracite", "E 1 Anthracite")
		eq(row.ingredients[1].n, 1, "E one Anthracite")
		eq(row.ingredients[2].group, "stick", "E 1 stick")
	end
	for _, entry in ipairs(row.ingredients) do
		if row.output == "default:torch" then
			check(entry.item ~= "grug_materials:anthracite", "E the Coal torch takes no Anthracite")
		end
	end
end
eq(torch_rows, 1, "E one Anthracite torch recipe")
check(read("tools/r45_rg/edits.lua"):find("grug_materials:anthracite_torch", 1, true) ~= nil,
	"E the row comes from the generator's edits")

-- ---------------------------------------------------------------------------
-- F. Enchant inputs
-- ---------------------------------------------------------------------------
local text = read("mods/ITEMS/grug_professions/data/enchants.json")
local function family_inputs(tier)
	local block = text:match('"tier": ' .. tier .. ',.-"family_input": (%b{})')
	local out = {}
	for key, value in block:gmatch('"([%w_]+)": "([^"]+)"') do out[key] = value end
	return out
end
local t2, t3 = family_inputs(2), family_inputs(3)
eq(t2.metal_armor, "group:coal", "F T2 metal armor: group:coal (Charcoal works)")
eq(t3.sword, "grug_materials:anthracite", "F T3 sword: Anthracite")
eq(t3.metal_armor, "grug_materials:anthracite", "F T3 metal armor: Anthracite")
check(not text:find("default:coal_lump", 1, true), "F no enchant names the Coal Lump")
-- grug_jobs.token_registered (registry.lua), copied by its bytes.
local source = read("mods/PLAYER/grug_jobs/registry.lua")
local fn_text = source:match("(function grug_jobs%.token_registered.-\nend)")
check(fn_text ~= nil, "F token_registered exists")
setmetatable(items, nil)
local loader = loadstring(fn_text)
loader()
check(grug_jobs.token_registered("group:coal"), "F group:coal has a member")
check(not grug_jobs.token_registered("group:no_such_group"), "F an empty group is refused")
check(grug_jobs.token_registered("default:coal_lump"), "F an item counts")
check(not grug_jobs.token_registered("mod:missing"), "F an unknown item is refused")

print(("R47 AN PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error(failures .. " failures", 0) end
