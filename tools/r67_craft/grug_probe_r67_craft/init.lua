-- Disposable engine probe (Round 67 lane CRAFT: the migration step 0.67.0 end
-- to end). Never shipped: tools/r67_craft/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.66.1 game for the setup boot and
-- under this checkout's game after the tool. It asserts nothing: it writes
-- what the game saw to <world>/r43_it_obs.json (Round 43 IT's file names:
-- e2e.py boots through tools/r43_it/it.py) and e2e.py checks it.
--   each join   first of all join callbacks (before grug_core's migration
--               runner): the lists and the job keys as loaded; in a "setup"
--               phase the character is then built (below); 3 s after the
--               join the same as the game left them, the character's Claim
--               Stone entries (grug_housing.recovered) with their packed
--               contents, and its mailbox's attachments;
--   then        once every character the plan names has left again, it
--               writes the file and shuts the server down.
-- The setup (0.66.1): smith gets rods in main, on the other hotbar and in
-- the crafting overflow, a finished running job and a waiting one that took
-- rods (the recipes with a rod handle, written as jobs.lua stores them), a
-- letter with rods, and three Claim Stone entries (a rod stack, a packed
-- chest the game has not cleaned with rods in its item meta, a cleaned one
-- with rods in its content key); sleeper (offline afterwards) gets rods in
-- main.

local P = "[r67_craft_probe] "
local world = core.get_worldpath()
local wv = grug_core.world_version
local ROD = "grug_professions:metal_rod_"
local STORE = "grug_hotbar_store"
local OUT = "grug_craft_out"
local LISTS = {"main", STORE, OUT}

local function log(msg) core.log("action", P .. msg) end

local function read(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local plan = core.parse_json(read(world .. "/r43_it_plan.json") or "") or {}
local expected = plan.joins or {}
local phase = plan.phase or "?"
local setup = phase:match("^setup") ~= nil

local obs = {phase = phase, game = wv.game,
	load = {new_world = wv.new_world, from = wv.from}, joins = {}, leaves = 0}
core.register_on_mods_loaded(function()
	obs.rods_registered = core.registered_items[ROD .. "iron"] ~= nil
end)

local function lists_of(player)
	local inv = player:get_inventory()
	local out = {}
	for _, list in ipairs(LISTS) do
		local items = {}
		for index = 1, inv:get_size(list) do
			items[index] = inv:get_stack(list, index):to_string()
		end
		out[list] = items
	end
	return out
end

local function state(player)
	local meta = player:get_meta()
	return {lists = lists_of(player), job = meta:get_string("grug_jobs:job"),
		queue = meta:get_string("grug_jobs:queue")}
end

-- What the game holds for the character outside the inventory.
local function stores(name)
	local out = {recovered = {}, packed = {}, letters = {}}
	local storage = grug_housing.storage
	for _, entry in ipairs(grug_housing.recovered.entries(name)) do
		local stack = entry.stack
		local row = {key = entry.key, item = stack:to_string(), name = stack:get_name()}
		local ref = stack:get_meta():get_string("ref")
		if ref ~= "" then out.packed[ref] = storage:get_string(ref) end
		local lists = stack:get_meta():get_string("lists")
		if lists ~= "" then row.lists = lists end
		out.recovered[#out.recovered + 1] = row
	end
	for _, letter in ipairs(grug_mail.store.box(name).letters or {}) do
		out.letters[#out.letters + 1] = {subject = letter.subject, items = letter.items or {}}
	end
	return out
end

-- The recipe of `output` whose ingredients name a rod (0.66.1).
local function rod_recipe(output)
	for _, recipe in ipairs(grug_jobs.recipes_for_output(output)) do
		for _, entry in ipairs(recipe.ingredients) do
			if (entry.item or ""):find(ROD, 1, true) then return recipe.id end
		end
	end
	error("no rod recipe of " .. output)
end

local function build(player)
	local name = player:get_player_name()
	local inv = player:get_inventory()
	if name == "sleeper" then
		inv:set_stack("main", 9, ItemStack(ROD .. "bronze 3"))
		return {}
	end
	inv:set_stack("main", 9, ItemStack(ROD .. "iron 5"))
	inv:set_stack("main", 10, ItemStack(ROD .. "abyssal_steel 1"))
	if inv:get_size(STORE) < 8 then inv:set_size(STORE, 8) end
	inv:set_stack(STORE, 2, ItemStack(ROD .. "steel 2"))
	if inv:get_size(OUT) < 4 then inv:set_size(OUT, 4) end
	inv:set_stack(OUT, 1, ItemStack(ROD .. "embersteel 4"))
	local now = os.time()
	local meta = player:get_meta()
	meta:set_string("grug_jobs:job", core.serialize({kind = "recipe",
		recipe = rod_recipe("grug_gear:sword_iron"), quantity = 1,
		consumed = {"grug_materials:iron_bar 2", ROD .. "iron 1"},
		start = now - 20, finish = now - 17}))
	meta:set_string("grug_jobs:queue", core.serialize({{kind = "recipe",
		recipe = rod_recipe("grug_gear:dagger_steel"), quantity = 1,
		consumed = {"grug_materials:steel_bar 1", ROD .. "steel 3"}, duration = 3, id = 1}}))
	assert(grug_mail.send_system(name, "npc", "Probe", "Rods", "Rods for the step.",
		{ROD .. "silversteel 5", "default:apple 2"}))
	local storage = grug_housing.storage
	local packed = grug_housing.packed
	storage:set_string("recovered:" .. name .. ":1:1", ROD .. "iron 9")
	storage:set_string("recovered:" .. name .. ":1:2", packed.make("default:chest",
		{main = {"", ROD .. "embersteel 7", "default:apple 3"}}, 1):to_string())
	local content = {main = {[1] = ROD .. "bronze 1", [5] = "default:torch 10"}}
	local ref = "packed:" .. name .. ":1:3"
	storage:set_string(ref, core.serialize(content))
	storage:set_string("recovered:" .. name .. ":1:3",
		packed.make_ref("default:chest", ref, 1, content):to_string())
	return {}
end

local function on_join(player)
	local name = player:get_player_name()
	local entry = {name = name, loaded = state(player)}
	obs.joins[#obs.joins + 1] = entry
	log("joined " .. name)
	if setup then
		core.after(0.5, function()
			local current = core.get_player_by_name(name)
			if not current then return end
			local ok, result = pcall(build, current)
			entry.built_ok = ok
			entry.build = ok and result or {error = tostring(result)}
			log("built " .. name .. (ok and "" or (": " .. tostring(result))))
		end)
	end
	core.after(3, function()
		local current = core.get_player_by_name(name)
		if current then
			entry.settled = state(current)
			local ok, result = pcall(stores, name)
			entry.stores = ok and result or {error = tostring(result)}
		end
	end)
end
-- First of all join callbacks, before grug_core's migration runner.
local joins = core.registered_on_joinplayers
local count = #joins
core.register_on_joinplayer(on_join)
assert(#joins == count + 1)
core.register_on_mods_loaded(function()
	table.insert(joins, 1, table.remove(joins, count + 1))
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r67 craft probe done") end)
end

core.register_on_leaveplayer(function(player)
	obs.leaves = obs.leaves + 1
	log("left " .. player:get_player_name())
	if obs.leaves >= #expected then
		core.after(1, finish, "every planned character left")
	end
end)

core.after(0, function()
	if #expected == 0 then core.after(3, finish, "no joins planned") end
	core.after(200, finish, "timeout: not every planned character joined and left")
end)
