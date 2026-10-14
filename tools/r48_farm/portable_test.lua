-- Round 48 lane FARM portable test (plant-growth-plan.md §6; round48-plan.md
-- §4.4). Loads the REAL files under a small fake engine:
--   L  grug_farming/init.lua with default.plant_lit (default/functions.lua):
--      a crop in the dark does not advance, a light resumes it with its
--      progress kept, darkness pauses it again; light 7 pauses, light 8
--      grows (measured as at noon); Cave Cap, Mushroom and Ember Moss grow at
--      light 0; a stale timer in the dark credits nothing.
--   C  Melon and Mushroom plant, grow, regrow to stage 2 on a right-click
--      harvest; seeds and spores; 18 crop families; no Salt Crust crop, seed
--      or seed recipe; the Basic catalog's seed rows (grug_jobs).
--   S  the salt pan: placement (stone, sand, dirt; not on a liquid, not
--      without protection), filling in the dark, pausing without water with
--      the progress kept, the scrape, the drops, the recipe row and the
--      plain (metadata-free) Water Bucket it consumes.
--   R  renewal: both salts renewable, their initial density unchanged, a
--      renewal step places each in a fixture habitat below its target.
--   P  papyrus and cactus (default/functions.lua): ground, water, plant
--      light 8 at noon, the terrain guard, param2 >= 4, the height cap, the
--      ABM neighbours; cactus dig_up and the large cactus seedling
--      (default/nodes.lua).
--   T  saplings (default/trees.lua): natural light only.
--   W  the wild crop sources' stage-4 look and the art plan's file names
--      (grug_gathering/presentation.lua); the wild Salt Crust source.
--   X  tooltips: one added line per item, also after a second pass.
-- Usage (repo root): luajit tools/r48_farm/portable_test.lua [REPO]
local repo = arg[1] or "."
local real_dofile = dofile

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

local function noop() end
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local function P(x, y, z) return {x = x, y = y, z = z} end
local function permissive(t)
	return setmetatable(t, {__index = function() return noop end})
end

------------------------------------------------------------------------------
-- The fake engine: nodes, light (noon value per position), metadata, timers.
------------------------------------------------------------------------------
local W = {nodes = {}, light = {}, natural = {}, metas = {}, timers = {},
	protected = {}, guarded = {}, given = {}, dug = {}, abms = {}, loaded = {}}
local registered_nodes, registered_items = {}, {}

local function new_meta()
	local store = {}
	return {
		get_float = function(_, k) return tonumber(store[k]) or 0 end,
		set_float = function(_, k, v) store[k] = v end,
		get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v) store[k] = v end,
		get_keys = function()
			local keys = {}
			for k in pairs(store) do keys[#keys + 1] = k end
			return keys
		end,
	}
end
local function new_timer()
	local t = {timeout = 0, elapsed = 0, started = false}
	function t:start(timeout) self.timeout, self.elapsed, self.started = timeout, 0, true end
	function t:set(timeout, elapsed) self.timeout, self.elapsed, self.started = timeout, elapsed, true end
	function t:stop() self.started, self.timeout = false, 0 end
	function t:is_started() return self.started end
	function t:get_elapsed() return self.elapsed end
	function t:get_timeout() return self.started and self.timeout or 0 end
	return t
end

-- ItemStack with metadata (the bucket writes some).
local stack_mt = {}
stack_mt.__index = stack_mt
function ItemStack(value)
	if type(value) == "table" and getmetatable(value) == stack_mt then
		local copy = ItemStack(value.name .. " " .. value.count)
		return copy
	end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
	local self = setmetatable({name = name or "", count = tonumber(count) or
		((name or "") == "" and 0 or 1), meta = new_meta()}, stack_mt)
	return self
end
function stack_mt:get_name() return self.name end
function stack_mt:get_count() return self.count end
function stack_mt:is_empty() return self.name == "" or self.count == 0 end
function stack_mt:get_meta() return self.meta end
function stack_mt:get_definition() return {} end
function stack_mt:take_item(n)
	n = n or 1
	self.count = self.count - n
	if self.count <= 0 then self.name, self.count = "", 0 end
end

local mods_loaded = {}
local C = permissive({
	registered_nodes = registered_nodes, registered_items = registered_items,
	registered_tools = {},
	settings = permissive({get_bool = function(_, _, value) return value end,
		get = function() return nil end}),
	get_modpath = function(name)
		local dirs = {grug_farming = "/mods/ITEMS/grug_farming",
			grug_gathering = "/mods/ITEMS/grug_gathering",
			default = "/mods/BASE/default", grug_mapgen = "/mods/MAPGEN/grug_mapgen"}
		return repo .. assert(dirs[name], name)
	end,
	get_current_modname = function() return "grug_farming" end,
	get_translator = function() return function(text) return text end end,
	register_node = function(name, def)
		def.name = name
		-- The engine's defaults (builtin/game/register.lua).
		if def.walkable == nil then def.walkable = true end
		if def.buildable_to == nil then def.buildable_to = false end
		if def.liquidtype == nil then def.liquidtype = "none" end
		registered_nodes[name], registered_items[name] = def, def
	end,
	register_craftitem = function(name, def)
		def.name = name
		registered_items[name] = def
	end,
	override_item = function(name, fields)
		local def = assert(registered_items[name], "override of a missing item " .. name)
		for k, v in pairs(fields) do def[k] = v end
	end,
	register_abm = function(def) W.abms[def.label] = def end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	get_item_group = function(name, group)
		local def = registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_node = function(pos) return {name = W.nodes[key(pos)] and W.nodes[key(pos)].name or "air",
		param2 = W.nodes[key(pos)] and W.nodes[key(pos)].param2 or 0} end,
	set_node = function(pos, node)
		W.nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
		W.metas[key(pos)], W.timers[key(pos)] = nil, nil
		local def = registered_nodes[node.name]
		if def and def.on_construct then def.on_construct(pos) end
		return true
	end,
	swap_node = function(pos, node)
		W.nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
	end,
	remove_node = function(pos) W.nodes[key(pos)] = nil end,
	get_meta = function(pos)
		local k = key(pos)
		W.metas[k] = W.metas[k] or new_meta()
		return W.metas[k]
	end,
	get_node_timer = function(pos)
		local k = key(pos)
		W.timers[k] = W.timers[k] or new_timer()
		return W.timers[k]
	end,
	-- Light as at noon: the larger of daylight and artificial light. The
	-- light code must ask for noon.
	get_node_light = function(pos, timeofday)
		assert(timeofday == 0.5, "plant light is measured as at noon")
		return W.light[key(pos)] or 0
	end,
	get_natural_light = function(pos, timeofday)
		assert(timeofday == 0.5, "natural light is measured as at noon")
		return W.natural[key(pos)] or 0
	end,
	find_node_near = function(pos, radius, names)
		assert(names[1] == "group:water")
		for x = pos.x - radius, pos.x + radius do
			for y = pos.y - radius, pos.y + radius do
				for z = pos.z - radius, pos.z + radius do
					local node = W.nodes[x .. "," .. y .. "," .. z]
					if node and core.get_item_group(node.name, "water") > 0 then
						return P(x, y, z)
					end
				end
			end
		end
	end,
	is_protected = function(pos) return W.protected[key(pos)] == true end,
	record_protection_violation = function() W.violations = (W.violations or 0) + 1 end,
	is_creative_enabled = function() return false end,
	node_dig = function(pos, node)
		W.dug[#W.dug + 1] = key(pos)
		W.nodes[key(pos)] = nil
		return true
	end,
	handle_node_drops = function(_, drops)
		for _, drop in ipairs(drops) do W.given[#W.given + 1] = drop end
	end,
})
C.get_node_or_nil = C.get_node
C.pos_to_string = key
core, minetest = C, C
vector = {offset = function(pos, x, y, z) return P(pos.x + x, pos.y + y, pos.z + z) end}

local function light_at(pos, value) W.light[key(pos)] = value end
local function set(pos, name, param2) W.nodes[key(pos)] = {name = name, param2 = param2 or 0} end
local function name_at(pos) return C.get_node(pos).name end
local function fire(pos, elapsed)
	-- The engine removes an expired timer before it calls on_timer.
	local timer = C.get_node_timer(pos)
	timer.started = false
	local def = registered_nodes[name_at(pos)]
	if def.on_timer(pos, elapsed) then timer:start(timer.timeout ~= 0 and timer.timeout or 15) end
end

-- Ground, water and the terrain guard (grug_core.world_alterable).
C.register_node("air", {buildable_to = true, groups = {}})
C.register_node("default:water_source", {liquidtype = "source", buildable_to = true,
	groups = {water = 3}})
C.register_node("default:stone", {walkable = true, groups = {cracky = 3}})
C.register_node("grug_nodes:mud", {walkable = true, groups = {crumbly = 3, soil = 1, mud = 1}})
C.register_node("grug_nodes:mesa_clay", {walkable = true, groups = {crumbly = 2}})
C.register_node("default:glass", {walkable = true, groups = {cracky = 3}})
grug_core = {world_alterable = function(pos) return not W.guarded[key(pos)] end}
grug_core.node_rightclick = nil
real_dofile(repo .. "/mods/CORE/grug_core/node_rightclick.lua")

-- The vendored default files (the patched growth code).
default = {LIGHT_MAX = 14, get_translator = function(text) return text end}
real_dofile(repo .. "/mods/BASE/default/functions.lua")
real_dofile(repo .. "/mods/BASE/default/trees.lua")
real_dofile(repo .. "/mods/BASE/default/nodes.lua")
-- default/nodes.lua registers sand, dirt, papyrus, cactus and the saplings.
check(registered_nodes["default:cactus"] and registered_nodes["default:papyrus"],
	"setup: default/nodes.lua registered cactus and papyrus")

------------------------------------------------------------------------------
-- The real Cooking plant list (grug_cooking/init.lua in a permissive sandbox).
------------------------------------------------------------------------------
local cooking_items = {}
do
	local sandbox_items = setmetatable({}, {__index = function(t, name)
		return {name = name, groups = {}, description = name}
	end})
	local saved = core
	core = permissive({registered_items = sandbox_items,
		register_craftitem = function(name, def) cooking_items[name] = def end})
	grug_food = {register_item = function() return true end}
	grug_jobs = permissive({DURATIONS = {}, STARTER_PROFESSIONS = {},
		ingredient_list = function() return {} end})
	grug_classes = permissive({})
	real_dofile(repo .. "/mods/ITEMS/grug_cooking/init.lua")
	core = saved
end
local PLANTS = grug_cooking.PLANTS
for _, row in ipairs(PLANTS) do C.register_craftitem(row.item, cooking_items[row.item]) end
local salt_row
for _, row in ipairs(PLANTS) do if row.name == "salt_crust" then salt_row = row end end
eq(salt_row and salt_row.crop, false, "C Salt Crust is a Cooking item without a crop")
-- The gathering items the farm and the tooltips use (grug_gathering's).
for _, name in ipairs({"potato", "corn", "melon", "mushroom", "wild_cocoa", "rock_salt",
		"sunleaf", "marshbloom", "stormkelp", "gravemoss", "dragonweed", "crimson_lotus"}) do
	C.register_craftitem("grug_gathering:" .. name, {description = name:gsub("^%l", string.upper) ..
		"\nFood line", inventory_image = "g_" .. name .. ".png"})
end
C.register_craftitem("grug_materials:embersteel_bar", {description = "Embersteel Bar"})

------------------------------------------------------------------------------
-- grug_farming.
------------------------------------------------------------------------------
grug_inventory = {give = function(player, stack)
	W.given[#W.given + 1] = type(stack) == "string" and stack or stack:get_name()
	return ItemStack("")
end}
local soil_callbacks
grug_nodes = {bind_crop_soil_callbacks = function(callbacks) soil_callbacks = callbacks end,
	crop_visual = real_dofile(repo .. "/mods/ITEMS/grug_nodes/crop_visual.lua")}
grug_mapgen = {wp40 = {planner_source = {}, vegetation = {
	natural_vegetation = function() return {} end,
	woody_species = function() return {} end}}}
grug_materials = {TIERS = {}}
grug_core.natural_renewal_allowed = function() return true end
grug_core.combat_eye_pos = function(player) return player:get_pos() end
real_dofile(repo .. "/mods/ITEMS/grug_farming/init.lua")
for _, name in ipairs({grug_farming.SOIL_DRY, grug_farming.SOIL_WET}) do
	C.register_node(name, {walkable = true, groups = {soil = 2, grug_crop_soil = 1},
		on_construct = function(pos) return soil_callbacks.on_construct(pos) end,
		on_timer = function(pos, elapsed) return soil_callbacks.on_timer(pos, elapsed) end})
end
local SOIL, WET = grug_farming.SOIL_DRY, grug_farming.SOIL_WET

local player = {
	is_player = function() return true end,
	get_player_name = function() return "farmer" end,
	get_player_control = function() return {} end,
	get_pos = function() return P(0, 0, 0) end,
}
local function plant(seed_item, soil_pos)
	local stack = ItemStack(seed_item .. " 5")
	registered_items[seed_item].on_place(stack, player,
		{type = "node", under = soil_pos, above = P(soil_pos.x, soil_pos.y + 1, soil_pos.z)})
	return P(soil_pos.x, soil_pos.y + 1, soil_pos.z)
end
local function fire_soil(pos) fire(pos, 15) end
local function field(x)
	local soil = P(x, 0, 0)
	set(P(x, 0, 2), "default:water_source")
	C.set_node(soil, {name = SOIL})
	fire_soil(soil)
	return soil
end

-- L: the light rule.
do
	local soil = field(0)
	eq(name_at(soil), WET, "L soil next to water is wet")
	local crop = plant("grug_farming:seed_carrot", soil)
	eq(name_at(crop), "grug_farming:carrot_1", "L carrot planted")
	check(not C.get_node_timer(crop):is_started(), "L a carrot planted in the dark does not start")
	fire_soil(soil)
	check(not C.get_node_timer(crop):is_started(), "L the soil check keeps it paused in the dark")
	light_at(crop, 7)
	fire_soil(soil)
	check(not C.get_node_timer(crop):is_started(), "L light 7 pauses")
	light_at(crop, 8)
	fire_soil(soil)
	check(C.get_node_timer(crop):is_started(), "L light 8 grows")
	eq(C.get_node_timer(crop).elapsed, 0, "L it starts at its kept progress (0)")
	C.get_node_timer(crop).elapsed = 120
	light_at(crop, 0)
	fire_soil(soil)
	check(not C.get_node_timer(crop):is_started(), "L removing the light pauses again")
	eq(C.get_meta(crop):get_float("wet_progress"), 120, "L the partial progress is kept")
	light_at(crop, 12)
	fire_soil(soil)
	check(C.get_node_timer(crop):is_started() and C.get_node_timer(crop).elapsed == 120,
		"L a placed light resumes the crop at its progress")
	-- A stale timer that fires in the dark credits nothing and stays off.
	light_at(crop, 0)
	fire(crop, 400)
	eq(name_at(crop), "grug_farming:carrot_1", "L a stale timer in the dark advances nothing")
	check(not C.get_node_timer(crop):is_started(), "L and does not restart")
	light_at(crop, 8)
	fire(crop, 200)
	eq(name_at(crop), "grug_farming:carrot_2", "L in light a full stage advances")
	-- Light-exempt crops grow at light 0.
	for index, crop_key in ipairs({"cave_cap", "mushroom", "ember_moss"}) do
		local exempt_soil = field(10 * index)
		local spore = "grug_farming:seed_" .. crop_key
		local exempt = plant(spore, exempt_soil)
		check(C.get_node_timer(exempt):is_started(), "L " .. crop_key .. " starts at light 0")
		fire(exempt, 200)
		eq(name_at(exempt), "grug_farming:" .. crop_key .. "_2", "L " .. crop_key .. " grows at light 0")
		fire_soil(exempt_soil)
		check(C.get_node_timer(exempt):is_started(), "L " .. crop_key .. " is not paused by darkness")
	end
	-- Dryness still pauses a light-exempt crop.
	W.nodes["30,0,2"] = nil
	fire_soil(P(30, 0, 0))
	check(not C.get_node_timer(P(30, 1, 0)):is_started(), "L dryness still pauses an exempt crop")
end

-- C: the crop population, Melon and Mushroom, seeds and spores.
do
	eq(#grug_farming.CROPS, 18, "C 18 crop families")
	for _, fn in ipairs(mods_loaded) do fn() end -- population check and tooltips
	check(registered_items["grug_farming:seed_salt_crust"] == nil, "C no Salt Crust seeds")
	check(registered_nodes["grug_farming:salt_crust_1"] == nil, "C no Salt Crust crop")
	eq(registered_items["grug_farming:seed_melon"].description:match("^[^\n]+"),
		"Melon Seeds", "C Melon Seeds")
	for _, spore in ipairs({"mushroom", "cave_cap", "ember_moss"}) do
		local text = registered_items["grug_farming:seed_" .. spore].description:match("^[^\n]+")
		check(text:match(" Spores$") ~= nil, "C " .. spore .. " seeds are spores (" .. text .. ")")
	end
	eq(registered_items["grug_farming:seed_carrot"].description:match("^[^\n]+"),
		"Carrot Seeds", "C ordinary crops keep Seeds")
	eq(registered_items["grug_farming:seed_mushroom"].inventory_image,
		"grug_farming_mushroom_spores.png", "C Mushroom Spores icon (art plan name)")
	eq(registered_items["grug_farming:seed_melon"].inventory_image,
		"grug_farming_melon_seeds.png", "C Melon Seeds icon (art plan name)")
	eq(registered_items["grug_farming:seed_cassava"].inventory_image,
		"grug_farming_seed_cassava.png", "C Cassava Seeds icon (art plan name)")
	-- Melon (needs light) and Mushroom (exempt): plant, grow, regrow harvest.
	for index, crop_key in ipairs({"melon", "mushroom"}) do
		local soil = field(100 + 10 * index)
		local crop = plant("grug_farming:seed_" .. crop_key, soil)
		light_at(crop, 8)
		fire_soil(soil)
		for _ = 1, 3 do fire(crop, 200) end
		eq(name_at(crop), "grug_farming:" .. crop_key .. "_4", "C " .. crop_key .. " grows to stage 4")
		W.given = {}
		registered_nodes[name_at(crop)].on_rightclick(crop, C.get_node(crop), player,
			ItemStack(""))
		eq(name_at(crop), "grug_farming:" .. crop_key .. "_2", "C " .. crop_key .. " regrows to stage 2")
		eq(W.given[1], "grug_gathering:" .. crop_key, "C the harvest gives the " .. crop_key)
	end
	-- The Basic catalog (generated by tools/r45_rg): two seeds per harvest
	-- item for every crop, nothing for salt.
	local catalog = real_dofile(repo .. "/mods/PLAYER/grug_jobs/basic_recipes.lua")
	local by_output = {}
	for _, row in ipairs(catalog.recipes) do by_output[row.output] = row end
	for _, row in ipairs(grug_farming.CROPS) do
		local recipe = by_output[row.seed]
		check(recipe and recipe.count == 2 and #recipe.ingredients == 1 and
			recipe.ingredients[1].item == row.harvest_item and recipe.ingredients[1].n == 1,
			"C Basic: 1 " .. row.harvest_item .. " makes 2 " .. row.seed)
	end
	check(by_output["grug_farming:seed_salt_crust"] == nil, "C no Salt Crust seed recipe")
end

-- S: the salt pan.
do
	local pan = registered_items["grug_farming:salt_pan"]
	check(pan and pan.inventory_image == "grug_farming_salt_pan.png", "S the Salt Pan item")
	local function place_on(support, x, protected)
		local ground = P(x, 50, 0)
		set(ground, support)
		local above = P(x, 51, 0)
		W.protected[key(above)] = protected
		local stack = ItemStack("grug_farming:salt_pan")
		pan.on_place(stack, player, {type = "node", under = ground, above = above})
		return above, stack
	end
	for index, support in ipairs({"default:stone", "default:sand", "default:dirt"}) do
		local pos, stack = place_on(support, 200 + 10 * index)
		eq(name_at(pos), "grug_farming:salt_pan_1", "S placeable on " .. support)
		eq(stack:get_count(), 0, "S placing takes the pan from the stack")
	end
	local wet = place_on("default:water_source", 240)
	eq(name_at(wet), "air", "S not placeable on a liquid")
	local refused = place_on("default:stone", 250, true)
	eq(name_at(refused), "air", "S not placeable without protection")
	-- Filling: no light anywhere, water within 3.
	local pos = place_on("default:stone", 260)
	set(P(263, 50, 0), "default:water_source")
	check(C.get_node_timer(pos):is_started(), "S the pan's timer runs once placed")
	fire(pos, 150)
	eq(name_at(pos), "grug_farming:salt_pan_1", "S 150 s: still stage 1")
	fire(pos, 100)
	eq(name_at(pos), "grug_farming:salt_pan_2", "S fills in the dark (stage 2 after 250 s)")
	W.nodes["263,50,0"] = nil
	fire(pos, 500)
	eq(name_at(pos), "grug_farming:salt_pan_2", "S without water it pauses")
	eq(C.get_meta(pos):get_float("grug_salt_progress"), 50, "S and keeps its progress")
	check(C.get_node_timer(pos):is_started(), "S and keeps checking")
	set(P(260, 50, 3), "default:water_source")
	fire(pos, 600)
	eq(name_at(pos), "grug_farming:salt_pan_4", "S water back: it fills up")
	check(not C.get_node_timer(pos):is_started(), "S a full pan stops its timer")
	W.given = {}
	registered_nodes["grug_farming:salt_pan_2"].on_rightclick(pos, {name = "grug_farming:salt_pan_2"},
		player, ItemStack(""))
	eq(#W.given, 0, "S a pan that is not full gives nothing")
	registered_nodes[name_at(pos)].on_rightclick(pos, C.get_node(pos), player, ItemStack(""))
	eq(W.given[1], "grug_cooking:salt_crust", "S a full pan gives one Salt Crust")
	eq(#W.given, 1, "S exactly one")
	eq(name_at(pos), "grug_farming:salt_pan_1", "S and goes back to stage 1")
	check(C.get_node_timer(pos):is_started(), "S and fills again")
	eq(registered_nodes["grug_farming:salt_pan_1"].drop, "grug_farming:salt_pan",
		"S digging returns the pan")
	local full_drop = registered_nodes["grug_farming:salt_pan_4"].drop
	check(type(full_drop) == "table" and full_drop.items[1].items[1] == "grug_farming:salt_pan" and
		full_drop.items[2].items[1] == "grug_cooking:salt_crust",
		"S digging a full pan returns the pan and its crust")
	eq(registered_nodes["grug_farming:salt_pan_1"].buildable_to, false, "S a pan is not overbuilt")
	eq(registered_nodes["grug_farming:salt_pan_1"].floodable, false, "S nor flooded")
	eq(registered_nodes["grug_farming:salt_pan_3"].drawtype, "nodebox", "S the basin look")
	-- The recipe: 3 Embersteel Bars, 1 Water Bucket, 1 Salt Crust, nothing back.
	local catalog = real_dofile(repo .. "/mods/PLAYER/grug_jobs/basic_recipes.lua")
	local recipe
	for _, row in ipairs(catalog.recipes) do
		if row.output == "grug_farming:salt_pan" then recipe = row end
	end
	local wanted = {["grug_materials:embersteel_bar"] = 3, ["grug_farming:water_bucket"] = 1,
		["grug_cooking:salt_crust"] = 1}
	local matched = recipe and recipe.count == 1 and #recipe.ingredients == 3
	for _, entry in ipairs(recipe and recipe.ingredients or {}) do
		matched = matched and wanted[entry.item] == entry.n
	end
	check(matched, "S Basic: 3 Embersteel Bars + Water Bucket + Salt Crust -> 1 Salt Pan")
	check(recipe and recipe.replacements == nil, "S the recipe returns nothing (no replacements)")
	-- The Water Bucket filled at ordinary water is a plain stack (only stacks
	-- without metadata count as ingredients, grug_jobs.is_ingredient_stack).
	local empty = registered_items["grug_farming:empty_iron_bucket"]
	local water = P(300, 50, 0)
	set(water, "default:water_source")
	player.get_wielded_item = function() return ItemStack("grug_farming:empty_iron_bucket") end
	player.get_pos = function() return P(301, 51, 0) end
	local filled = empty.on_place(ItemStack("grug_farming:empty_iron_bucket"), player,
		{type = "node", under = water, above = P(300, 51, 0)})
	eq(filled:get_name(), "grug_farming:water_bucket", "S the bucket fills at water")
	eq(#filled:get_meta():get_keys(), 0, "S a Water Bucket of ordinary water has no metadata")
	C.register_node("default:river_water_source", {liquidtype = "source", buildable_to = true,
		groups = {water = 3}})
	set(water, "default:river_water_source")
	local river = empty.on_place(ItemStack("grug_farming:empty_iron_bucket"), player,
		{type = "node", under = water, above = P(300, 51, 0)})
	eq(river:get_meta():get_string("water_family"), "river", "S river water keeps its family")
	-- Pouring: a plain bucket pours ordinary water, an old 0.47 bucket too.
	local full = registered_items["grug_farming:water_bucket"]
	local target = P(310, 50, 0)
	set(target, "default:stone")
	player.get_pos = function() return P(310, 52, 0) end
	full.on_place(filled, player, {type = "node", under = target, above = P(310, 51, 0)})
	eq(name_at(P(310, 51, 0)), "default:water_source", "S a plain bucket pours ordinary water")
	local old = ItemStack("grug_farming:water_bucket")
	old:get_meta():set_string("water_family", "ordinary")
	full.on_place(old, player, {type = "node", under = target, above = P(311, 51, 0)})
end

-- R: salt renewal.
do
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local habitat = real_dofile(wp40 .. "/habitat_registry.lua")
	check(habitat.is_renewable("rock_salt") and habitat.is_renewable("salt_crust"),
		"R both salts are renewable")
	eq(habitat.initial_denominator("rock_salt", 1024), 1024, "R Rock Salt initial density unchanged")
	eq(habitat.initial_denominator("salt_crust", 512), 512, "R Salt Crust initial density unchanged")
	eq(habitat.initial_denominator("corn", 256), 512, "R other renewable rows stay at half density")
	local world = real_dofile(wp40 .. "/world_content_catalog.lua")
	local gathering = real_dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	-- Fixture habitat: x < 0 the badlands of The Shattered Line (mesa clay,
	-- level 46), x >= 0 a Gravesalt beach (sand) with sea at x = 10.
	local function column_values_at(x, z)
		if x >= 10 then return "coastal_shelf", 1, "front_gravesalt_escarpment", "grug_beach",
			"human", -5, 0, nil end
		if x < 0 then
			return "land", 1, "front_shattered_line", "grug_badlands", "orc", 20
		end
		return "land", 1, "front_gravesalt_escarpment", "grug_beach", "human", 20
	end
	local SUPPORTS = {"default:sand", "grug_nodes:mesa_clay"}
	local density = real_dofile(wp40 .. "/vegetation_density.lua")({
		habitat = habitat, vegetation_rule = habitat.vegetation_rule("1048",
			function(x) return x < 0 and "front_shattered_line" or "front_gravesalt_escarpment" end),
		world_plants = world.plants, p9g_rows = gathering.p9g_sources(),
		decorations = {}, decoration_cover = function() return 0 end,
		support_names = SUPPORTS, template_records = {},
		column_values_at = column_values_at,
		overlay_exclusion_at = function() return nil end,
		surface_mob_level_at = function() return 46 end,
		static_exclusion_values_at = function() return nil end,
		surface_cave_run_at = function() return nil end,
		primary_relief_at = function() return "plains" end,
	})
	local GROUND = 20
	local sparse = {}
	local function ground_name(x, y, z)
		local value = sparse[key(P(x, y, z))]
		if value then return value end
		if x >= 10 then return y <= 0 and "default:water_source" or "air" end
		if y < GROUND then return "default:stone" end
		if y == GROUND then return x < 0 and "grug_nodes:mesa_clay" or "default:sand" end
		return "air"
	end
	local function set_of(names)
		local result = {}
		for _, name in ipairs(names) do result[name] = true end
		return result
	end
	local seed = 4848
	local api = {
		density = density,
		planner = {column_values_at = column_values_at, hard_row_at = function() return nil end},
		get_node_or_nil = function(pos) return {name = ground_name(pos.x, pos.y, pos.z)} end,
		set_node = function(pos, node) sparse[key(pos)] = node.name end,
		get_natural_light = function(pos) return pos.y > GROUND and 15 or 0 end,
		get_item_group = function() return 0 end,
		find_nodes_in_area = function(minp, maxp, names)
			local wanted, list = set_of(names), {}
			for x = minp.x, maxp.x do for z = minp.z, maxp.z do for y = minp.y, maxp.y do
				if wanted[ground_name(x, y, z)] then list[#list + 1] = P(x, y, z) end
			end end end
			return list
		end,
		find_nodes_in_area_under_air = function(minp, maxp, names)
			local wanted, list = set_of(names), {}
			for x = minp.x, maxp.x do for z = minp.z, maxp.z do for y = minp.y, maxp.y do
				if wanted[ground_name(x, y, z)] and ground_name(x, y + 1, z) == "air" then
					list[#list + 1] = P(x, y, z)
				end
			end end end
			return list
		end,
		natural_ground_alterable = function() return true end,
		random = function()
			seed = (seed * 16807) % 2147483647
			return seed / 2147483647
		end,
		trees = false, non_natural = {},
	}
	local renewal = real_dofile(repo .. "/mods/ITEMS/grug_farming/renewal.lua")(api)
	local far = {P(500, GROUND + 1, 500)}
	local function categories_at(x, support)
		local list = density.categories(x, GROUND + 1, 0, support, 15) or {}
		local keys = {}
		for _, category in ipairs(list) do keys[category.key] = category end
		return keys
	end
	local crust = categories_at(-20, "grug_nodes:mesa_clay").salt_crust
	check(crust and math.abs(crust.p - 1 / 512) < 1e-12,
		"R Salt Crust habitat on mesa clay in The Shattered Line at its full rate 1/512")
	local rock = categories_at(9, "default:sand").rock_salt
	check(rock and math.abs(rock.p - 1 / 1024) < 1e-12,
		"R Rock Salt on a Gravesalt shore (salt_cardinal) at its full rate 1/1024")
	check(categories_at(0, "default:sand").rock_salt == nil, "R Rock Salt needs the shore")
	-- A rare row's natural count in a counting box is a fraction: the patch
	-- holds one plant in that fraction of patches (renewal.lua
	-- patch_fraction). Try spots along z, one per patch, a few rolls each.
	local function renew(x, node)
		for patch = 0, 99 do
			local z = patch * 64
			for _ = 1, 8 do
				local result, placed = renewal.evaluate(P(x, GROUND, z), far,
					{left = renewal.constants.VOLUME_BUDGET}, 0, "resource")
				if result == "placed" and placed == node then return true end
				if result == "placed" then sparse[key(P(x, GROUND + 1, z))] = nil end
				if result ~= "placed" and result ~= "roll" then break end
			end
		end
		return false
	end
	check(renew(-20, "grug_mapgen:salt_crust_source"),
		"R a renewal step places Salt Crust below its target")
	check(renew(9, "grug_gathering:rock_salt_source"),
		"R a renewal step places Rock Salt below its target")
	local dark = {density.categories(-20, GROUND + 1, 0, "grug_nodes:mesa_clay", 9)}
	eq(dark[2], "dark", "R below natural light 10 at noon nothing renews")
end

-- P: papyrus and cactus.
do
	local grow_papyrus, grow_cactus = W.abms["Grow papyrus"], W.abms["Grow cactus"]
	check(grow_papyrus and grow_cactus, "P both growth ABMs are registered")
	local function has(list, value)
		for _, item in ipairs(list) do if item == value then return true end end
		return false
	end
	check(has(grow_papyrus.neighbors, "group:soil") and has(grow_papyrus.neighbors, "group:sand"),
		"P the papyrus ABM looks at soil and sand")
	check(has(grow_cactus.neighbors, "group:sand") and has(grow_cactus.neighbors, "grug_nodes:mesa_clay"),
		"P the cactus ABM looks at sand and mesa clay")
	local function stand(x, ground, plant_name, light, water, param2)
		set(P(x, 70, 0), ground)
		set(P(x, 71, 0), plant_name, param2)
		if water then set(P(x + 2, 70, 0), "default:water_source") end
		light_at(P(x, 72, 0), light)
		return P(x, 71, 0)
	end
	local function grows(abm, pos)
		local before = name_at(P(pos.x, pos.y + 1, pos.z))
		abm.action(P(pos.x, pos.y, pos.z), C.get_node(pos))
		return before == "air" and name_at(P(pos.x, pos.y + 1, pos.z)) ~= "air"
	end
	check(grows(grow_papyrus, stand(400, "grug_nodes:mud", "default:papyrus", 8, true)),
		"P papyrus grows on mud next to water at plant light 8")
	check(grows(grow_papyrus, stand(410, "default:sand", "default:papyrus", 8, true)),
		"P papyrus grows on sand next to water")
	check(not grows(grow_papyrus, stand(420, "grug_nodes:mud", "default:papyrus", 7, true)),
		"P papyrus does not grow at light 7")
	check(not grows(grow_papyrus, stand(430, "grug_nodes:mud", "default:papyrus", 14, false)),
		"P papyrus does not grow without water")
	check(not grows(grow_papyrus, stand(440, "default:stone", "default:papyrus", 14, true)),
		"P papyrus does not grow on stone")
	local guarded = stand(450, "grug_nodes:mud", "default:papyrus", 14, true)
	W.guarded[key(P(450, 72, 0))] = true
	check(not grows(grow_papyrus, guarded), "P papyrus does not grow where the terrain guard refuses")
	check(grows(grow_cactus, stand(460, "default:sand", "default:cactus", 8)),
		"P cactus grows on sand at plant light 8")
	check(grows(grow_cactus, stand(470, "grug_nodes:mesa_clay", "default:cactus", 8)),
		"P cactus grows on mesa clay")
	check(not grows(grow_cactus, stand(480, "default:dirt", "default:cactus", 14)),
		"P cactus does not grow on dirt")
	check(not grows(grow_cactus, stand(490, "default:sand", "default:cactus", 7)),
		"P cactus does not grow at light 7")
	check(not grows(grow_cactus, stand(500, "default:sand", "default:cactus", 14, false, 4)),
		"P a cactus piece with param2 >= 4 does not grow")
	local guarded_cactus = stand(510, "default:sand", "default:cactus", 14)
	W.guarded[key(P(510, 72, 0))] = true
	check(not grows(grow_cactus, guarded_cactus), "P cactus does not grow in a town or POI")
	-- Height cap 4.
	set(P(520, 70, 0), "default:sand")
	for y = 71, 74 do set(P(520, y, 0), "default:cactus") end
	light_at(P(520, 75, 0), 15)
	grow_cactus.action(P(520, 71, 0), C.get_node(P(520, 71, 0)))
	eq(name_at(P(520, 75, 0)), "air", "P a cactus of four pieces stops")
	-- Cactus dig_up: digging a piece takes every piece above it.
	set(P(530, 70, 0), "default:sand")
	for y = 71, 74 do set(P(530, y, 0), "default:cactus") end
	W.dug = {}
	local digger = {is_player = function() return true end}
	W.nodes["530,72,0"] = nil
	registered_nodes["default:cactus"].after_dig_node(P(530, 72, 0), {name = "default:cactus"},
		nil, digger)
	check(#W.dug == 2 and W.dug[1] == "530,73,0" and W.dug[2] == "530,74,0",
		"P digging a cactus piece digs the pieces above (" .. table.concat(W.dug, " ") .. ")")
	eq(name_at(P(530, 71, 0)), "default:cactus", "P the bottom piece stays")
	-- The large cactus seedling: mesa clay counts, plant light 8 at noon.
	local seedling = registered_nodes["default:large_cactus_seedling"]
	local grown = {}
	local saved_grow = default.grow_large_cactus
	default.grow_large_cactus = function(pos) grown[#grown + 1] = key(pos) end
	set(P(540, 70, 0), "grug_nodes:mesa_clay")
	set(P(540, 71, 0), "default:large_cactus_seedling")
	light_at(P(540, 71, 0), 7)
	seedling.on_timer(P(540, 71, 0))
	eq(#grown, 0, "P the seedling waits at light 7")
	light_at(P(540, 71, 0), 8)
	seedling.on_timer(P(540, 71, 0))
	eq(grown[1], "540,71,0", "P the seedling grows on mesa clay at plant light 8")
	set(P(550, 70, 0), "default:dirt")
	set(P(550, 71, 0), "default:large_cactus_seedling")
	seedling.on_timer(P(550, 71, 0))
	eq(name_at(P(550, 71, 0)), "air", "P the seedling dies on dirt")
	default.grow_large_cactus = saved_grow
end

-- T: saplings by natural light only.
do
	set(P(600, 80, 0), "default:dirt")
	local pos = P(600, 81, 0)
	light_at(pos, 14) -- an Anthracite torch beside it
	W.natural[key(pos)] = 0
	check(not default.can_grow(pos), "T a sapling under an Anthracite torch without sky does not grow")
	W.natural[key(pos)] = 15 -- under glass: sunlight passes
	check(default.can_grow(pos), "T a sapling under glass grows")
	W.natural[key(pos)] = 12
	check(not default.can_grow(pos), "T natural light 12 is not enough")
end

-- W: the wild looks (grug_gathering/presentation.lua), the wild Salt Crust.
do
	local catalog = real_dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	for _, row in ipairs(catalog.p9g_sources()) do
		C.register_node(row.source_node, {drawtype = "plantlike", tiles = {row.image},
			inventory_image = row.image, drop = row.raw_item, visual_scale = 1.0,
			buildable_to = false, walkable = false, groups = {}})
	end
	real_dofile(repo .. "/mods/ITEMS/grug_gathering/presentation.lua")
	for _, crop_key in ipairs({"potato", "corn", "melon", "mushroom"}) do
		local source = registered_nodes["grug_gathering:" .. crop_key .. "_source"]
		eq(source.tiles[1], "grug_farming_" .. crop_key .. "_4.png",
			"W wild " .. crop_key .. " wears its stage-4 crop look")
		eq(source.visual_scale, 1.15, "W wild " .. crop_key .. " at the wild crops' scale")
		eq(source.buildable_to, false, "W wild " .. crop_key .. " keeps its source rules")
		eq(source.drop, "grug_gathering:" .. crop_key, "W wild " .. crop_key .. " drops only its item")
	end
	eq(registered_items["grug_gathering:potato"].inventory_image, "g_potato.png",
		"W Potato keeps its item icon")
	for _, item_key in ipairs({"melon", "mushroom", "sunleaf", "gravemoss", "wild_cocoa"}) do
		eq(registered_items["grug_gathering:" .. item_key].inventory_image,
			"grug_gathering_" .. item_key .. ".png", "W " .. item_key .. " item icon (art plan name)")
	end
	for _, item_key in ipairs({"sunleaf", "gravemoss", "wild_cocoa"}) do
		eq(registered_nodes["grug_gathering:" .. item_key .. "_source"].tiles[1],
			"grug_gathering_" .. item_key .. "_plant.png", "W " .. item_key .. " world sprite")
	end
	-- Every wired file exists (placeholders until the art pick).
	local files = {"grug_farming_salt_pan.png", "grug_farming_seed_cassava.png",
		"grug_farming_melon_seeds.png", "grug_farming_mushroom_spores.png"}
	for stage = 1, 4 do
		files[#files + 1] = "grug_farming_melon_" .. stage .. ".png"
		files[#files + 1] = "grug_farming_mushroom_" .. stage .. ".png"
	end
	for _, file in ipairs(files) do
		local handle = io.open(repo .. "/mods/ITEMS/grug_farming/textures/" .. file, "rb")
		check(handle ~= nil, "W texture " .. file .. " exists")
		if handle then handle:close() end
	end
	for _, item_key in ipairs({"melon", "mushroom", "sunleaf", "gravemoss", "wild_cocoa",
			"sunleaf_plant", "gravemoss_plant", "wild_cocoa_plant"}) do
		local file = "grug_gathering_" .. item_key .. ".png"
		local handle = io.open(repo .. "/mods/ITEMS/grug_gathering/textures/" .. file, "rb")
		check(handle ~= nil, "W texture " .. file .. " exists")
		if handle then handle:close() end
	end
	-- The wild crops and the wild Salt Crust source (grug_mapgen/world_nodes.lua).
	local engine = permissive({register_node = function(name, def) registered_nodes[name] = def end})
	real_dofile(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")(engine,
		repo .. "/mods/MAPGEN/grug_mapgen", grug_nodes, {source_can_dig = function() return noop end})
	local salt = registered_nodes["grug_mapgen:salt_crust_source"]
	check(salt and salt.drawtype == "nodebox" and salt.drop == "grug_cooking:salt_crust",
		"W the wild Salt Crust source still registers (basin look, drops its item)")
	eq(registered_nodes["grug_mapgen:carrot_source"].drop, "grug_cooking:carrot",
		"W a wild crop source drops only its item")
end

-- X: tooltips.
do
	local names = grug_farming.apply_plant_tooltips()
	local before = {}
	for _, name in ipairs(names) do before[name] = registered_items[name].description end
	grug_farming.apply_plant_tooltips()
	local stable = true
	for _, name in ipairs(names) do
		if registered_items[name].description ~= before[name] then stable = false end
	end
	check(stable, "X a second pass changes nothing")
	local function lines(name)
		local text = registered_items[name].description
		local count = 0
		for _ in text:gmatch("[^\n]+") do count = count + 1 end
		return count, text:match("([^\n]+)$")
	end
	local cases = {
		{"grug_cooking:carrot", 3, "Craft into seeds. Grows on wet farm soil in light."},
		{"grug_farming:seed_carrot", 2, "Plant on farm soil near water. Needs daylight or torchlight."},
		{"grug_gathering:mushroom", 3, "Craft into spores. Grows on wet farm soil, even in the dark."},
		{"grug_farming:seed_mushroom", 2, "Plant on farm soil near water. Grows even in the dark."},
		{"default:papyrus", 2, "Grows on dirt, mud or sand near water. Leave the bottom stalk to regrow."},
		{"default:cactus", 2, "Grows on sand or mesa clay. Leave the bottom piece to regrow."},
		{"default:sapling", 2, "Needs open sky or glass to grow."},
		{"grug_cooking:salt_crust", 2, "Scraped from a salt pan or found in the wild."},
		{"grug_farming:salt_pan", 2, "Place on any ground near water. Collects salt crust."},
		{"grug_gathering:sunleaf", 3, "Found in the wild only."},
		{"grug_gathering:rock_salt", 3, "Found in the wild only."},
		{"grug_gathering:gravemoss", 3, "Gathered in the wild by alchemists."},
	}
	-- The fixture's Cooking items carry no food lines (grug_food is stubbed):
	-- carrot and the gathering items have one, the others none.
	registered_items["grug_cooking:carrot"].description = "Carrot\nFood line"
	grug_farming.apply_plant_tooltips()
	for _, case in ipairs(cases) do
		local count, last = lines(case[1])
		eq(last, case[3], "X " .. case[1] .. " ends with its line")
		eq(count, case[2], "X " .. case[1] .. " has exactly one added line")
	end
end

print(checks .. " checks, " .. failures .. " failures")
if failures > 0 then error("R48 FARM PORTABLE FAIL", 0) end
print("R48 FARM PORTABLE PASS checks=" .. checks)
